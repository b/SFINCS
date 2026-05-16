#!/bin/bash
# SOR-52 perf characterization harness.
#
# Captures a fixed-window perf snapshot of case_prod_compound_snapwave at
# gpu_n2 under two MPI variants: the non-CUDA-aware default OpenMPI at
# /opt/nvidia/hpc_sdk/Linux_x86_64/25.9/comm_libs/mpi/bin/mpirun (pre-fix
# baseline) and the CUDA-aware HPC-X 2.24 at
# /opt/nvidia/hpc_sdk/Linux_x86_64/25.9/comm_libs/13.0/hpcx/hpcx-2.24/ompi/bin/mpirun
# (post-fix). Each variant runs in its own directory, with `nvidia-smi
# dmon` capturing GPU utilization + PCIe transfer rates over the window,
# and /usr/bin/time -v capturing host-side wall + CPU%. The simulation
# wall clock is also written by SFINCS into sfincs.log.
#
# Runs go through `docker run` directly (NOT through
# source/build_scripts/run_gpu_container.sh) so we can set per-variant
# PATH / LD_LIBRARY_PATH / OPAL_PREFIX without the wrapper's HPC-X
# defaults overriding the pre-fix baseline. The wrapper itself hardcodes
# HPC-X paths and offers no escape hatch.
#
# Run from the repo root:
#
#     tests/perf/run_perf.sh pre-fix
#     tests/perf/run_perf.sh post-fix
#
# Requires: built source/install_cuda/bin/sfincs, case data under
# tests/cases/case_prod_compound_snapwave, the sfincs-build-gpu:latest
# image, and ≥1 GPU visible to docker.

set -euo pipefail

VARIANT=${1:-}
case "$VARIANT" in
    pre-fix|post-fix) ;;
    *) echo "usage: $0 pre-fix|post-fix" >&2; exit 2 ;;
esac

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
IMAGE=${SFINCS_GPU_IMAGE:-sfincs-build-gpu:latest}
CASE_NAME=case_prod_compound_snapwave
CASE_DIR=$REPO_ROOT/tests/cases/$CASE_NAME
OUT_DIR=$REPO_ROOT/tests/perf/$VARIANT
RUN_DIR=$OUT_DIR/run

# Bound simulated time so the bench fits a single implementer cycle.
# 6 h at the case's dt_avg of ~3 s gives ~7 200 steps, enough wall
# clock (1-2 min) to fill several dmon rows without dragging into
# tens of minutes.
TSTOP_OVERRIDE="20200101 060000"
NVIDIA_SMI_INTERVAL_S=2
NRANKS=2

echo "=== SOR-52 perf characterization: $VARIANT ==="
echo "case      : $CASE_NAME"
echo "tstop     : $TSTOP_OVERRIDE (15 min simulated)"
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

# Per-variant MPI tree.
HPCX_ROOT=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/comm_libs/13.0/hpcx/hpcx-2.24
DEFAULT_MPI=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/comm_libs/mpi
NVHPC_COMPILERS=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/compilers
NVHPC_MATH=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/math_libs
NVHPC_CUDA=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/cuda

# Note (SOR-52 finding): in NVHPC 25.9 there is effectively only one
# OpenMPI installed — HPC-X 2.24. The "default" mpirun at
# comm_libs/mpi/bin/mpirun is a 319 KB wrapper inside a symlink
# (comm_libs/mpi -> hpcx) that ultimately invokes the same HPC-X
# libmpi the explicit HPC-X path uses, and only one libmpi.so.40
# exists in the image (under hpcx-2.24). The SFINCS GPU binary's
# DT_RUNPATH also bakes in the HPC-X lib directory at link time, so
# the dynamic loader resolves libmpi to HPC-X regardless of which
# launcher binary started the process. The pre-fix variant therefore
# uses `--mca opal_cuda_support 0` to disable the CUDA-aware data
# path at the OMPI runtime layer (the closest in-container proxy for
# the "non-CUDA-aware MPI" the issue describes). MPIX_Query reports
# build-time support and will still answer yes; the actual transport
# behaviour is what changes.
MCA_FLAGS=""
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
esac

# Confirm CUDA-aware status for the variant up front (sanity check; the
# variant string is the source of truth for what we *expect*).
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

WALL_START=$(date +%s)
echo "--- launching sfincs ($VARIANT, $NRANKS ranks, mpirun=$MPIRUN) ---"
set +e
/usr/bin/time -v -o "$OUT_DIR/time.txt" \
    docker run --rm --init \
        --name "$CONTAINER_NAME" \
        --gpus all --ipc=host \
        --user "$(id -u):$(id -g)" \
        -e HOME=/tmp \
        -e OPAL_PREFIX="$CONTAINER_OPAL_PREFIX" \
        -e PATH="$CONTAINER_PATH" \
        -e LD_LIBRARY_PATH="$CONTAINER_LDPATH" \
        -v "$REPO_ROOT":/work \
        -w "$CONTAINER_RUN_DIR" \
        "$IMAGE" \
        "$MPIRUN" --allow-run-as-root $MCA_FLAGS -n "$NRANKS" "$GPU_BIN" \
        > "$OUT_DIR/sfincs.stdout" 2>&1
SFINCS_RC=$?
set -e
WALL_END=$(date +%s)
WALL_ELAPSED=$((WALL_END - WALL_START))

kill -TERM "$NVSMI_PID" 2>/dev/null || true
wait "$NVSMI_PID" 2>/dev/null || true

cp -f "$RUN_DIR/sfincs.log" "$OUT_DIR/sfincs.log" 2>/dev/null || true
cp -f "$RUN_DIR/sfincs_map.nc" "$OUT_DIR/sfincs_map.nc" 2>/dev/null || true

echo "--- $VARIANT complete: rc=$SFINCS_RC wall=${WALL_ELAPSED}s ---"
echo "    sfincs.log: $OUT_DIR/sfincs.log"
echo "    dmon log:   $OUT_DIR/nvidia_smi_dmon.txt"
echo "    time.txt:   $OUT_DIR/time.txt"

# Extract the SFINCS-reported simulation wall clock.
if [ -f "$OUT_DIR/sfincs.log" ]; then
    grep -E "Computation time|Total time|wall clock|Real time|simulation finished|elapsed" \
        "$OUT_DIR/sfincs.log" || true
fi

exit "$SFINCS_RC"
