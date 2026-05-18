#!/bin/bash
# SOR-82 SnapWave make_theta_grid memoization re-characterization capture.
#
# Drop-in replacement for SOR-81's run_snapwave_profile.sh (under
# tests/perf/snapwave-characterization-20260517/) — same case, same
# container, same NSight + perf capture shape, but pointed at this
# directory for the post-memoization artifacts so the before/after
# top-5 SnapWave routines table and total wall clock can be compared
# side by side.
#
# Two complementary captures over the same case + binary:
#   1. NSight Systems profile of rank 0 with --sample=cpu so the SnapWave
#      call-stack hotpath is visible in addition to the NVTX timeline.
#   2. Linux perf record on rank 0 with --call-graph dwarf so the hot
#      loops resolve to function + line (tighter CPU sampling cadence
#      than nsys, complements the GPU-side view).
#
# Captured artifacts (committed under this directory):
#   * snapwave_rank0.nsys-rep   -- nsys raw report (rank 0, NVTX+CPU samples)
#   * nvtx_pushpop_sum.csv      -- nsys per-NVTX-range duration table
#   * cuda_gpu_kern_sum.csv     -- nsys GPU kernel summary (sanity)
#   * osrt_sum.csv              -- nsys OS-runtime call summary
#   * snapwave_perf.data        -- perf record raw data (rank 0)
#   * snapwave_perf_report.txt  -- perf report --stdio (children/inclusive)
#   * snapwave_perf_flat.txt    -- perf report --stdio --no-children (self)
#   * snapwave_perf_callgraph.txt -- perf report --stdio per-symbol callee tree
#   * sfincs.log                -- SFINCS log (timing summary, SnapWave per-call)
#   * sfincs.stdout             -- mpirun + nsys/perf stdout
#
# Requires: built source/install_cuda/bin/sfincs with the SOR-82
# make_theta_grid memoization patch applied, the sfincs-build-gpu:latest
# image, and 2 GPUs.

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
IMAGE=${SFINCS_GPU_IMAGE:-sfincs-build-gpu:latest}
CASE_NAME=case_prod_compound_snapwave
CASE_DIR=$REPO_ROOT/tests/cases/$CASE_NAME
OUT_DIR=$REPO_ROOT/tests/perf/snapwave-memoize-20260517
NSYS_RUN_DIR=$OUT_DIR/run_nsys
PERF_RUN_DIR=$OUT_DIR/run_perf

NRANKS=2

stage_case() {
    local stage_dir="$1"
    mkdir -p "$stage_dir"
    find "$stage_dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    for entry in "$CASE_DIR"/*; do
        base=$(basename "$entry")
        case "$base" in
            README.md|fetch.sh|generate.py) ;;
            sfincs.inp) cp -- "$entry" "$stage_dir/$base" ;;
            *) ln -srf -- "$entry" "$stage_dir/$base" ;;
        esac
    done
}

container_path_of() {
    local host_path="$1"
    case "$host_path" in
        "$REPO_ROOT"/*) printf '/work%s\n' "${host_path#$REPO_ROOT}" ;;
        *) echo "path $host_path is outside REPO_ROOT" >&2; exit 1 ;;
    esac
}

HPCX_ROOT=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/comm_libs/13.0/hpcx/hpcx-2.24
NVHPC_COMPILERS=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/compilers
NVHPC_MATH=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/math_libs
NVHPC_CUDA=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/cuda
CONTAINER_PATH="$HPCX_ROOT/ompi/bin:$HPCX_ROOT/ucx/bin:$NVHPC_COMPILERS/bin:$NVHPC_CUDA/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
CONTAINER_LDPATH="$HPCX_ROOT/ompi/lib:$HPCX_ROOT/ucx/lib:$HPCX_ROOT/sharp/lib:$HPCX_ROOT/hcoll/lib:$NVHPC_COMPILERS/lib:$NVHPC_MATH/lib64:$NVHPC_CUDA/lib64"
CONTAINER_OPAL_PREFIX=$HPCX_ROOT/ompi

GPU_BIN_HOST=$REPO_ROOT/source/install_cuda/bin/sfincs
[ -x "$GPU_BIN_HOST" ] || { echo "ERROR: $GPU_BIN_HOST not built" >&2; exit 1; }
GPU_BIN=/work/source/install_cuda/bin/sfincs

OUT_DIR_CONTAINER=$(container_path_of "$OUT_DIR")

# ----------------------------------------------------------------------
# Capture 1: NSight Systems with --sample=cpu
# ----------------------------------------------------------------------
echo "=== SOR-81 SnapWave characterization: nsys capture ==="
stage_case "$NSYS_RUN_DIR"
NSYS_RUN_CONTAINER=$(container_path_of "$NSYS_RUN_DIR")

NSYS_SCRIPT=$OUT_DIR/in_container_nsys.sh
cat > "$NSYS_SCRIPT" <<'EOF_NSYS'
#!/bin/bash
set -uo pipefail
NRANKS="$1"; shift
GPU_BIN="$1"; shift
OUT_CONTAINER="$1"; shift

NSYS=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/compilers/bin/nsys

RANK_WRAP="${OUT_CONTAINER}/rank_select_nsys.sh"
cat > "$RANK_WRAP" <<RANK_EOF
#!/bin/bash
R="\${OMPI_COMM_WORLD_RANK:-0}"
if [ "\$R" = "0" ]; then
  exec "$NSYS" profile \\
      --trace=cuda,nvtx,mpi,osrt --mpi-impl=openmpi \\
      --sample=cpu --cpuctxsw=process-tree \\
      --backtrace=dwarf --samples-per-backtrace=2 \\
      --kill=sigterm --force-overwrite=true \\
      --output="${OUT_CONTAINER}/snapwave_rank0" "$GPU_BIN"
else
  exec "$GPU_BIN"
fi
RANK_EOF
chmod +x "$RANK_WRAP"

mpirun --allow-run-as-root -n "$NRANKS" "$RANK_WRAP"
EOF_NSYS
chmod +x "$NSYS_SCRIPT"
NSYS_SCRIPT_CONTAINER=$(container_path_of "$NSYS_SCRIPT")

CONTAINER_NSYS="sfincs-sor81-nsys-$$-$(date +%s 2>/dev/null || echo 0)"
trap 'docker kill "$CONTAINER_NSYS" >/dev/null 2>&1 || true; docker rm -f "$CONTAINER_NSYS" >/dev/null 2>&1 || true' EXIT INT TERM

WALL_START=$(date +%s)
set +e
docker run --rm --init \
    --name "$CONTAINER_NSYS" \
    --gpus all --ipc=host \
    --user "$(id -u):$(id -g)" \
    --cap-add=SYS_ADMIN --cap-add=SYS_PTRACE \
    -e HOME=/tmp \
    -e OPAL_PREFIX="$CONTAINER_OPAL_PREFIX" \
    -e PATH="$CONTAINER_PATH" \
    -e LD_LIBRARY_PATH="$CONTAINER_LDPATH" \
    -v "$REPO_ROOT":/work \
    -w "$NSYS_RUN_CONTAINER" \
    "$IMAGE" \
    bash "$NSYS_SCRIPT_CONTAINER" \
        "$NRANKS" "$GPU_BIN" "$OUT_DIR_CONTAINER" \
    > "$OUT_DIR/sfincs.stdout" 2>&1
NSYS_RC=$?
set -e
WALL_END=$(date +%s)
echo "--- nsys run rc=$NSYS_RC wall=$((WALL_END - WALL_START))s ---"

cp -f "$NSYS_RUN_DIR/sfincs.log" "$OUT_DIR/sfincs.log" 2>/dev/null || true
rm -f "$NSYS_SCRIPT" "$OUT_DIR/rank_select_nsys.sh"

[ -f "$OUT_DIR/snapwave_rank0.nsys-rep" ] || { echo "ERROR: no nsys-rep" >&2; exit 1; }
ls -l "$OUT_DIR/snapwave_rank0.nsys-rep"

echo "--- nsys stats export ---"
docker run --rm --init \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    -e PATH="$CONTAINER_PATH" \
    -e LD_LIBRARY_PATH="$CONTAINER_LDPATH" \
    -v "$REPO_ROOT":/work \
    -w "$OUT_DIR_CONTAINER" \
    "$IMAGE" \
    bash -lc '
        set -e
        NSYS=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/compilers/bin/nsys
        REP=snapwave_rank0.nsys-rep
        "$NSYS" export --type sqlite --force-overwrite true \
            --output snapwave_rank0.sqlite "$REP"
        "$NSYS" stats --force-export=true --format csv \
            --report nvtx_pushpop_sum --output nvtx_pushpop_sum "$REP" || true
        "$NSYS" stats --force-export=true --format csv \
            --report cuda_gpu_kern_sum --output cuda_gpu_kern_sum "$REP" || true
        "$NSYS" stats --force-export=true --format csv \
            --report osrt_sum --output osrt_sum "$REP" || true
    ' >> "$OUT_DIR/sfincs.stdout" 2>&1 || \
    { echo "nsys stats failed (see sfincs.stdout)" >&2; }

# Move suffixed CSVs to canonical names.
for stem in nvtx_pushpop_sum cuda_gpu_kern_sum osrt_sum; do
    src="$OUT_DIR/${stem}_${stem}.csv"
    [ -f "$src" ] && mv -f "$src" "$OUT_DIR/${stem}.csv" || true
done
rm -f "$OUT_DIR/snapwave_rank0.sqlite"

trap - EXIT INT TERM

# ----------------------------------------------------------------------
# Capture 2: Linux perf record on rank 0
# ----------------------------------------------------------------------
echo "=== SOR-81 SnapWave characterization: perf capture ==="
stage_case "$PERF_RUN_DIR"
PERF_RUN_CONTAINER=$(container_path_of "$PERF_RUN_DIR")

PERF_SCRIPT=$OUT_DIR/in_container_perf.sh
cat > "$PERF_SCRIPT" <<'EOF_PERF'
#!/bin/bash
set -uo pipefail
NRANKS="$1"; shift
GPU_BIN="$1"; shift
OUT_CONTAINER="$1"; shift
PERF="$1"; shift

RANK_WRAP="${OUT_CONTAINER}/rank_select_perf.sh"
cat > "$RANK_WRAP" <<RANK_EOF
#!/bin/bash
R="\${OMPI_COMM_WORLD_RANK:-0}"
if [ "\$R" = "0" ]; then
  exec "$PERF" record -F 999 --call-graph dwarf,16384 \\
      -o "${OUT_CONTAINER}/snapwave_perf.data" \\
      -- "$GPU_BIN"
else
  exec "$GPU_BIN"
fi
RANK_EOF
chmod +x "$RANK_WRAP"

mpirun --allow-run-as-root -n "$NRANKS" "$RANK_WRAP"
EOF_PERF
chmod +x "$PERF_SCRIPT"
PERF_SCRIPT_CONTAINER=$(container_path_of "$PERF_SCRIPT")

# perf is not in the dev container; mount the host's linux-tools build
# directly so the in-container rank wrapper can exec it.
HOST_PERF=$(readlink -f /usr/bin/perf 2>/dev/null || echo /usr/bin/perf)
if [ "$HOST_PERF" = "/usr/bin/perf" ] && [ -x "/usr/lib/linux-tools/$(uname -r)/perf" ]; then
    HOST_PERF=$(readlink -f "/usr/lib/linux-tools/$(uname -r)/perf")
fi
[ -x "$HOST_PERF" ] || { echo "ERROR: host perf not found ($HOST_PERF)" >&2; exit 1; }
CONTAINER_PERF_BIN=/host_perf/perf

# The host perf links libunwind-x86_64.so.8 which is not present in the
# sfincs-build-gpu image (Dockerfile_gpu does not install libunwind8).
# Bind-mount the host's libunwind .so files into /host_perf/lib so the
# in-container perf can find them via LD_LIBRARY_PATH.
HOST_LIBDIR=/usr/lib/x86_64-linux-gnu
PERF_EXTRA_MOUNTS=()
for lib in libunwind.so.8 libunwind-x86_64.so.8 libunwind-ptrace.so.0 libunwind-coredump.so.0; do
    if [ -e "$HOST_LIBDIR/$lib" ]; then
        PERF_EXTRA_MOUNTS+=(-v "$HOST_LIBDIR/$lib:/host_perf/lib/$lib:ro")
    fi
done

CONTAINER_PERF="sfincs-sor81-perf-$$-$(date +%s 2>/dev/null || echo 0)"
trap 'docker kill "$CONTAINER_PERF" >/dev/null 2>&1 || true; docker rm -f "$CONTAINER_PERF" >/dev/null 2>&1 || true' EXIT INT TERM

WALL_START=$(date +%s)
set +e
docker run --rm --init \
    --name "$CONTAINER_PERF" \
    --gpus all --ipc=host \
    --user "$(id -u):$(id -g)" \
    --privileged \
    -e HOME=/tmp \
    -e OPAL_PREFIX="$CONTAINER_OPAL_PREFIX" \
    -e PATH="$CONTAINER_PATH" \
    -e LD_LIBRARY_PATH="/host_perf/lib:$CONTAINER_LDPATH" \
    -v "$REPO_ROOT":/work \
    -v "$HOST_PERF":"$CONTAINER_PERF_BIN":ro \
    "${PERF_EXTRA_MOUNTS[@]}" \
    -w "$PERF_RUN_CONTAINER" \
    "$IMAGE" \
    bash "$PERF_SCRIPT_CONTAINER" \
        "$NRANKS" "$GPU_BIN" "$OUT_DIR_CONTAINER" "$CONTAINER_PERF_BIN" \
    >> "$OUT_DIR/sfincs.stdout" 2>&1
PERF_RC=$?
set -e
WALL_END=$(date +%s)
echo "--- perf run rc=$PERF_RC wall=$((WALL_END - WALL_START))s ---"

rm -f "$PERF_SCRIPT" "$OUT_DIR/rank_select_perf.sh"

[ -f "$OUT_DIR/snapwave_perf.data" ] || { echo "ERROR: no perf.data" >&2; exit 1; }
ls -l "$OUT_DIR/snapwave_perf.data"

echo "--- perf report export (host-side, against in-container symbols) ---"
(
    cd "$OUT_DIR"
    "$HOST_PERF" report -i snapwave_perf.data --stdio --sort=overhead,symbol \
        --percent-limit 0.5 > snapwave_perf_report.txt 2>&1 || true
    "$HOST_PERF" report -i snapwave_perf.data --stdio --no-children \
        --sort=overhead,symbol --percent-limit 0.5 > snapwave_perf_flat.txt 2>&1 || true
    "$HOST_PERF" report -i snapwave_perf.data --stdio --no-children \
        -g graph,0.5,callee --percent-limit 1.0 > snapwave_perf_callgraph.txt 2>&1 || true
) >> "$OUT_DIR/sfincs.stdout" 2>&1 || \
    { echo "perf report failed (see sfincs.stdout)" >&2; }

# Cleanup stage dirs (artifacts already in OUT_DIR).
rm -rf "$NSYS_RUN_DIR" "$PERF_RUN_DIR"

trap - EXIT INT TERM

echo "=== SOR-81 SnapWave characterization capture complete ==="
ls -l "$OUT_DIR" | tail -20
