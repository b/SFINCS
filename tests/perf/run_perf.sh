#!/bin/bash
# SOR-52 perf characterization harness.
#
# Captures a fixed-window perf snapshot of a SFINCS case at gpu_n2 under
# one of three MPI variants:
#
#   pre-fix              — default-PATH mpirun (comm_libs/mpi/bin/mpirun)
#                          + --mca opal_cuda_support 0 / mpi_cuda_support 0.
#                          In NVHPC 25.9 comm_libs/mpi is a symlink to
#                          comm_libs/hpcx so this resolves to the same
#                          HPC-X libmpi the post-fix variant uses; the
#                          MCA toggles only disable OPAL-layer CUDA
#                          detection. UCX still routes device pointers
#                          via its own cuda_copy/cuda_ipc/gdr_copy
#                          transports, so this variant is effectively
#                          equivalent to post-fix in this container.
#   post-fix             — HPC-X 2.24 mpirun on PATH (CUDA-aware OpenMPI
#                          + UCX + sharp + hcoll). Default for the
#                          source/build_scripts/run_gpu_container.sh
#                          wrapper.
#   force-non-cuda-aware — HPC-X mpirun on PATH but with UCX configured
#                          to drop all CUDA transports
#                          (UCX_TLS=tcp,sm,self UCX_MEMTYPE_CACHE=n) and
#                          OPAL CUDA off. With no CUDA-aware transport
#                          available, MPI_Isend dereferences SFINCS's
#                          device pointers as host memory and the rank-0
#                          process SIGSEGVs inside uct_mm_ep_am_short
#                          on the first halo exchange. This variant
#                          exists to demonstrate empirically that the
#                          SFINCS GPU binary in this container hard-
#                          requires CUDA-aware MPI — there is no
#                          "slow but working" non-CUDA-aware data path
#                          to compare wall clock against; the binary
#                          either runs (CUDA-aware) or crashes (not).
#
# Each variant captures:
#   * sfincs.log                  — SFINCS log including timing summary
#   * sfincs.stdout               — MPI launcher stdout + the rank-0
#                                   "CUDA-aware MPI: yes/no" line
#   * nvidia_smi_dmon.txt         — GPU 0 sm% / mem% / Rx-PCIe / Tx-PCIe
#                                   sampled at NVIDIA_SMI_INTERVAL_S
#   * rank0_top.txt               — rank-0 sfincs %CPU sampled by top -b
#                                   *inside* the container so the value
#                                   reflects the SFINCS rank, not the
#                                   docker CLI client process
#   * variant_probe.txt           — which mpirun + ompi_info CUDA support
#
# Runs go through `docker run` directly (NOT through
# source/build_scripts/run_gpu_container.sh) so we can set per-variant
# PATH / LD_LIBRARY_PATH / OPAL_PREFIX / UCX_TLS without the wrapper's
# HPC-X defaults overriding them.
#
# Run from the repo root:
#
#     tests/perf/run_perf.sh pre-fix
#     tests/perf/run_perf.sh post-fix
#     tests/perf/run_perf.sh force-non-cuda-aware     # expected: SIGSEGV
#
# Requires: built source/install_cuda/bin/sfincs, case data under
# tests/cases/case_prod_compound_snapwave, the sfincs-build-gpu:latest
# image, and ≥1 GPU visible to docker.

set -euo pipefail

VARIANT=${1:-}
case "$VARIANT" in
    pre-fix|post-fix|force-non-cuda-aware) ;;
    *) echo "usage: $0 pre-fix|post-fix|force-non-cuda-aware" >&2; exit 2 ;;
esac

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
IMAGE=${SFINCS_GPU_IMAGE:-sfincs-build-gpu:latest}
CASE_NAME=case_prod_compound_snapwave
CASE_DIR=$REPO_ROOT/tests/cases/$CASE_NAME
OUT_DIR=$REPO_ROOT/tests/perf/$VARIANT
RUN_DIR=$OUT_DIR/run

# Bound simulated time so the bench fits a single implementer cycle.
# 6 h at the case's dt_avg of ~3 s gives ~7 200 steps, enough wall
# clock (~30 s) to fill dozens of dmon / top sample rows.
TSTOP_OVERRIDE="20200101 060000"
NVIDIA_SMI_INTERVAL_S=2
TOP_INTERVAL_S=1
NRANKS=2

echo "=== SOR-52 perf characterization: $VARIANT ==="
echo "case      : $CASE_NAME"
echo "tstop     : $TSTOP_OVERRIDE (6 h simulated)"
echo "out_dir   : $OUT_DIR"

mkdir -p "$RUN_DIR"
find "$RUN_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +

for entry in "$CASE_DIR"/*; do
    base=$(basename "$entry")
    case "$base" in
        README.md|fetch.sh|generate.py) ;;
        sfincs.inp) cp -- "$entry" "$RUN_DIR/$base" ;;
        *) ln -srf -- "$entry" "$RUN_DIR/$base" ;;
    esac
done
sed -i "s/^tstop.*/tstop             = ${TSTOP_OVERRIDE}/" "$RUN_DIR/sfincs.inp"

# Container paths for the run directory and binary.
case "$RUN_DIR" in
    "$REPO_ROOT"/*) CONTAINER_RUN_DIR="/work${RUN_DIR#$REPO_ROOT}" ;;
    *) echo "RUN_DIR is outside REPO_ROOT" >&2; exit 1 ;;
esac
GPU_BIN=/work/source/install_cuda/bin/sfincs

# Per-variant MPI tree + UCX overrides.
HPCX_ROOT=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/comm_libs/13.0/hpcx/hpcx-2.24
DEFAULT_MPI=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/comm_libs/mpi
NVHPC_COMPILERS=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/compilers
NVHPC_MATH=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/math_libs
NVHPC_CUDA=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/cuda

MCA_FLAGS=""
EXTRA_ENV_FLAGS=()

case "$VARIANT" in
    pre-fix)
        MPIRUN=$DEFAULT_MPI/bin/mpirun
        CONTAINER_PATH="$DEFAULT_MPI/bin:$NVHPC_COMPILERS/bin:$NVHPC_CUDA/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        CONTAINER_LDPATH="$DEFAULT_MPI/lib:$NVHPC_COMPILERS/lib:$NVHPC_MATH/lib64:$NVHPC_CUDA/lib64"
        CONTAINER_OPAL_PREFIX=$DEFAULT_MPI
        MCA_FLAGS="--mca opal_cuda_support 0 --mca mpi_cuda_support 0"
        ;;
    post-fix)
        MPIRUN=$HPCX_ROOT/ompi/bin/mpirun
        CONTAINER_PATH="$HPCX_ROOT/ompi/bin:$HPCX_ROOT/ucx/bin:$NVHPC_COMPILERS/bin:$NVHPC_CUDA/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        CONTAINER_LDPATH="$HPCX_ROOT/ompi/lib:$HPCX_ROOT/ucx/lib:$HPCX_ROOT/sharp/lib:$HPCX_ROOT/hcoll/lib:$NVHPC_COMPILERS/lib:$NVHPC_MATH/lib64:$NVHPC_CUDA/lib64"
        CONTAINER_OPAL_PREFIX=$HPCX_ROOT/ompi
        ;;
    force-non-cuda-aware)
        MPIRUN=$HPCX_ROOT/ompi/bin/mpirun
        CONTAINER_PATH="$HPCX_ROOT/ompi/bin:$HPCX_ROOT/ucx/bin:$NVHPC_COMPILERS/bin:$NVHPC_CUDA/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        CONTAINER_LDPATH="$HPCX_ROOT/ompi/lib:$HPCX_ROOT/ucx/lib:$HPCX_ROOT/sharp/lib:$HPCX_ROOT/hcoll/lib:$NVHPC_COMPILERS/lib:$NVHPC_MATH/lib64:$NVHPC_CUDA/lib64"
        CONTAINER_OPAL_PREFIX=$HPCX_ROOT/ompi
        MCA_FLAGS="--mca opal_cuda_support 0"
        # UCX_TLS=tcp,sm,self drops cuda_copy / cuda_ipc / gdr_copy
        # transports; UCX_MEMTYPE_CACHE=n disables the address →
        # memtype cache so UCX cannot detect device pointers via the
        # cache. With both off, MPI_Isend(device_ptr, ...) routes
        # through shared-memory dereference and the rank-0 process
        # SIGSEGVs on the first halo exchange.
        EXTRA_ENV_FLAGS=(
            -e "UCX_TLS=tcp,sm,self"
            -e "UCX_MEMTYPE_CACHE=n"
        )
        ;;
esac

# Confirm CUDA-aware status for the variant up front.
echo "--- variant probe ---"
docker run --rm --init \
    --gpus all --ipc=host \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    -e OPAL_PREFIX="$CONTAINER_OPAL_PREFIX" \
    -e PATH="$CONTAINER_PATH" \
    -e LD_LIBRARY_PATH="$CONTAINER_LDPATH" \
    -v "$REPO_ROOT":/work \
    -w /work \
    "$IMAGE" \
    sh -c "which mpirun && ompi_info --param mpi all --level 9 | grep -E 'opal_built_with_cuda_support|opal_cuda_support'" \
    | tee "$OUT_DIR/variant_probe.txt" || true

CONTAINER_NAME="sfincs-perf-${VARIANT}-$$-$(date +%s 2>/dev/null || echo 0)"
echo "--- starting nvidia-smi dmon (interval=${NVIDIA_SMI_INTERVAL_S}s, GPU 0) ---"
nvidia-smi dmon -d "$NVIDIA_SMI_INTERVAL_S" -s utm -i 0 \
    > "$OUT_DIR/nvidia_smi_dmon.txt" 2>&1 &
NVSMI_PID=$!
cleanup() {
    kill -TERM "$NVSMI_PID" 2>/dev/null || true
    docker kill "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

# In-container launcher: starts mpirun in the background, waits for the
# rank-0 sfincs PID to appear, samples its %CPU with top -b -p <pid>
# until the run completes, then waits for the run and propagates the
# exit code. Sampling top inside the container is the only way to read
# the SFINCS rank's CPU% accurately — /usr/bin/time around the docker
# CLI client reports 0 % because docker run is just an RPC frontend.
IN_CONTAINER_SCRIPT="$OUT_DIR/in_container_run.sh"
cat > "$IN_CONTAINER_SCRIPT" <<'IN_CONTAINER_EOF'
#!/bin/bash
# Inside the container. Stdout/stderr is captured by docker run.
set -uo pipefail
NRANKS="$1"; shift
TOP_INTERVAL_S="$1"; shift
GPU_BIN="$1"; shift
RANK0_TOP_OUT="$1"; shift
# Remaining args are mpirun MCA flags + binary args.

# Background mpirun; tee its stdout into the host stdout (captured by
# docker run > sfincs.stdout 2>&1).
mpirun --allow-run-as-root "$@" -n "$NRANKS" "$GPU_BIN" &
MPIRUN_PID=$!

# Wait for the rank-0 sfincs to register. Match by exact process name
# (`pgrep -x sfincs`) so the bash launcher whose command line contains
# the sfincs path doesn't itself match. On a single-node run the lowest
# PID is rank 0 in launch order.
SFINCS_BASENAME=$(basename "$GPU_BIN")
RANK0_PID=""
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    sleep 0.5
    RANK0_PID=$(pgrep -x "$SFINCS_BASENAME" 2>/dev/null | sort -n | head -1 || true)
    if [ -n "$RANK0_PID" ]; then
        break
    fi
done

if [ -z "$RANK0_PID" ]; then
    echo "WARNING: did not see a rank-0 sfincs PID within 5 s; CPU% sampling skipped." >&2
else
    echo "rank-0 sfincs PID: $RANK0_PID" >&2
    # top -b -d N -p PID: batch-mode, interval N seconds, only target PID.
    # Output streams to the bind-mounted host file. top exits on its own
    # when -p PID is no longer alive; the SIGTERM below is the belt-and-
    # braces for the case where the wait above returned before top noticed
    # the rank exited.
    top -b -d "$TOP_INTERVAL_S" -p "$RANK0_PID" > "$RANK0_TOP_OUT" 2>&1 &
    TOP_PID=$!
fi

wait "$MPIRUN_PID"
RC=$?

# Stop top sampling if it's still running.
if [ -n "${TOP_PID:-}" ]; then
    kill -TERM "$TOP_PID" 2>/dev/null || true
    wait "$TOP_PID" 2>/dev/null || true
fi

exit "$RC"
IN_CONTAINER_EOF
chmod +x "$IN_CONTAINER_SCRIPT"

# Container path of the rank-0 top output and the launcher script.
RANK0_TOP_OUT_CONTAINER="/work${OUT_DIR#$REPO_ROOT}/rank0_top.txt"
IN_CONTAINER_SCRIPT_CONTAINER="/work${IN_CONTAINER_SCRIPT#$REPO_ROOT}"

WALL_START=$(date +%s)
echo "--- launching sfincs ($VARIANT, $NRANKS ranks, mpirun=$MPIRUN) ---"
set +e
docker run --rm --init \
    --name "$CONTAINER_NAME" \
    --gpus all --ipc=host \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    -e OPAL_PREFIX="$CONTAINER_OPAL_PREFIX" \
    -e PATH="$CONTAINER_PATH" \
    -e LD_LIBRARY_PATH="$CONTAINER_LDPATH" \
    "${EXTRA_ENV_FLAGS[@]}" \
    -v "$REPO_ROOT":/work \
    -w "$CONTAINER_RUN_DIR" \
    "$IMAGE" \
    bash "$IN_CONTAINER_SCRIPT_CONTAINER" \
        "$NRANKS" \
        "$TOP_INTERVAL_S" \
        "$GPU_BIN" \
        "$RANK0_TOP_OUT_CONTAINER" \
        $MCA_FLAGS \
    > "$OUT_DIR/sfincs.stdout" 2>&1
SFINCS_RC=$?
set -e
WALL_END=$(date +%s)
WALL_ELAPSED=$((WALL_END - WALL_START))

kill -TERM "$NVSMI_PID" 2>/dev/null || true
wait "$NVSMI_PID" 2>/dev/null || true

cp -f "$RUN_DIR/sfincs.log" "$OUT_DIR/sfincs.log" 2>/dev/null || true
cp -f "$RUN_DIR/sfincs_map.nc" "$OUT_DIR/sfincs_map.nc" 2>/dev/null || true

# Clean up the in_container_run.sh helper (kept on disk during the run
# so docker could exec it from the bind mount, but not part of the
# committed artifact set).
rm -f "$IN_CONTAINER_SCRIPT"

echo "--- $VARIANT complete: rc=$SFINCS_RC wall=${WALL_ELAPSED}s ---"
echo "    sfincs.log:   $OUT_DIR/sfincs.log"
echo "    dmon log:     $OUT_DIR/nvidia_smi_dmon.txt"
echo "    rank0 top:    $OUT_DIR/rank0_top.txt"

# Summarize key signals so the reviewer can read FINDINGS.md straight off.
echo ""
echo "  GPU sm% samples (uniq -c):"
awk 'NR>2 && $2 ~ /^[0-9]+$/ {print $2}' "$OUT_DIR/nvidia_smi_dmon.txt" 2>/dev/null \
    | sort -n | uniq -c | head -20
echo "  PCIe Rx MB/s (uniq -c, top 10):"
awk 'NR>2 && $8 ~ /^[0-9]+$/ {print $8}' "$OUT_DIR/nvidia_smi_dmon.txt" 2>/dev/null \
    | sort -n | uniq -c | tail -10
echo "  PCIe Tx MB/s (uniq -c, top 10):"
awk 'NR>2 && $9 ~ /^[0-9]+$/ {print $9}' "$OUT_DIR/nvidia_smi_dmon.txt" 2>/dev/null \
    | sort -n | uniq -c | tail -10
echo "  rank-0 %CPU samples (uniq -c, sorted):"
awk '/^[[:space:]]*[0-9]+/ && NF>=9 {print $9}' "$OUT_DIR/rank0_top.txt" 2>/dev/null \
    | sort -n | uniq -c | head -20

if [ -f "$OUT_DIR/sfincs.log" ]; then
    echo "  sfincs.log timing:"
    grep -E "Total time|Time in|Average time step|simulation finished" "$OUT_DIR/sfincs.log" \
        | head -12
fi

exit "$SFINCS_RC"
