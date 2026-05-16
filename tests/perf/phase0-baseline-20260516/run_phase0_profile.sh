#!/bin/bash
# SOR-64 Phase 0 — canonical-on-device PCIe baseline capture.
#
# Captures a 60-second NSight Systems profile of
# `case_prod_compound_snapwave` at gpu_n2 (2 MPI ranks, 2 GPUs) with the
# Phase 0 NVTX range annotations active, then derives the per-step
# host<->device (PCIe) byte budget attributed to each annotated NVTX
# range and closes it against the SOR-52 / PR #100 measured PCIe
# envelope (2.4-2.5 GB/s Tx, 1.0-1.1 GB/s Rx).
#
# Per rank nsys is launched as the parent of each sfincs process
# (mpirun -n 2 nsys profile ...) so every rank gets its own .nsys-rep.
# `--delay=20` skips the startup / mesh-build / subgrid-table / SnapWave
# init transient so the 60 s collection window is steady-state per-step
# traffic; `--duration=60` bounds the window to exactly 60 wall seconds.
#
# Captured artifacts (committed under this directory):
#   * phase0_rank0.nsys-rep / phase0_rank1.nsys-rep — raw NSight reports
#   * nvtx_pushpop_sum.csv / cuda_gpu_sum_nvtx.csv /
#     cuda_gpu_mem_size_sum.csv — nsys stats exports (rank 0)
#   * nvidia_smi_dmon.txt   — GPU 0+1 sm% / Rx-PCIe / Tx-PCIe @ 2 s
#   * rank0_top.txt         — in-container rank-0 sfincs %CPU @ 1 s
#   * sfincs.stdout         — MPI launcher + nsys stdout
#   * sfincs.log            — SFINCS log (timing summary)
#   * summary.md            — the Phase 0 one-pager (written by
#                             analyze_phase0.py)
#
# Mirrors tests/perf/run_perf.sh's post-fix variant (CUDA-aware HPC-X
# 2.24 on PATH) so the PCIe numbers are directly comparable to the
# SOR-52 post-fix row in tests/perf/FINDINGS.md.
#
# Requires: built source/install_cuda/bin/sfincs, the
# sfincs-build-gpu:latest image, and 2 GPUs visible to docker.

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
IMAGE=${SFINCS_GPU_IMAGE:-sfincs-build-gpu:latest}
CASE_NAME=case_prod_compound_snapwave
CASE_DIR=$REPO_ROOT/tests/cases/$CASE_NAME
OUT_DIR=$REPO_ROOT/tests/perf/phase0-baseline-20260516
RUN_DIR=$OUT_DIR/run

NRANKS=2
# Steady-state window: skip the startup/mesh/subgrid/SnapWave-init
# transient (NSYS_DELAY_S) then collect exactly NSYS_DURATION_S. Both
# overridable via env for a fast pipeline smoke before the real 60 s run.
NSYS_DELAY_S=${NSYS_DELAY_S:-20}
NSYS_DURATION_S=${NSYS_DURATION_S:-60}
NVIDIA_SMI_INTERVAL_S=2
TOP_INTERVAL_S=1

echo "=== SOR-64 Phase 0 baseline capture ==="
echo "case     : $CASE_NAME"
echo "config   : gpu_n${NRANKS}"
echo "window   : ${NSYS_DURATION_S}s steady-state (after ${NSYS_DELAY_S}s delay)"
echo "out_dir  : $OUT_DIR"

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

case "$RUN_DIR" in
    "$REPO_ROOT"/*) CONTAINER_RUN_DIR="/work${RUN_DIR#$REPO_ROOT}" ;;
    *) echo "RUN_DIR is outside REPO_ROOT" >&2; exit 1 ;;
esac
GPU_BIN=/work/source/install_cuda/bin/sfincs

HPCX_ROOT=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/comm_libs/13.0/hpcx/hpcx-2.24
NVHPC_COMPILERS=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/compilers
NVHPC_MATH=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/math_libs
NVHPC_CUDA=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/cuda
CONTAINER_PATH="$HPCX_ROOT/ompi/bin:$HPCX_ROOT/ucx/bin:$NVHPC_COMPILERS/bin:$NVHPC_CUDA/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
CONTAINER_LDPATH="$HPCX_ROOT/ompi/lib:$HPCX_ROOT/ucx/lib:$HPCX_ROOT/sharp/lib:$HPCX_ROOT/hcoll/lib:$NVHPC_COMPILERS/lib:$NVHPC_MATH/lib64:$NVHPC_CUDA/lib64"
CONTAINER_OPAL_PREFIX=$HPCX_ROOT/ompi

CONTAINER_NAME="sfincs-phase0-$$-$(date +%s 2>/dev/null || echo 0)"
echo "--- starting nvidia-smi dmon (interval=${NVIDIA_SMI_INTERVAL_S}s, GPU 0,1) ---"
nvidia-smi dmon -d "$NVIDIA_SMI_INTERVAL_S" -s utm -i 0,1 \
    > "$OUT_DIR/nvidia_smi_dmon.txt" 2>&1 &
NVSMI_PID=$!
cleanup() {
    kill -TERM "$NVSMI_PID" 2>/dev/null || true
    docker kill "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

IN_CONTAINER_SCRIPT="$OUT_DIR/in_container_phase0.sh"
cat > "$IN_CONTAINER_SCRIPT" <<'IN_CONTAINER_EOF'
#!/bin/bash
set -uo pipefail
NRANKS="$1"; shift
TOP_INTERVAL_S="$1"; shift
GPU_BIN="$1"; shift
OUT_CONTAINER="$1"; shift
NSYS_DELAY_S="$1"; shift
NSYS_DURATION_S="$1"; shift

NSYS=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/compilers/bin/nsys

# gpu_n2 is a genuine 2-rank run (rank 1 participates so the halo_*
# NVTX ranges see real inter-rank traffic), but only rank 0 is wrapped
# in nsys. Profiling both ranks made nsys' --kill=sigterm on rank 0
# trip mpirun's abort-on-non-zero cascade, which SIGKILLed rank 1's
# nsys mid-report and truncated it. Rank 0 alone is fully
# representative: the 2-rank domain decomposition is symmetric, so the
# per-step bridge_in_* / bridge_out_* H<->D inventory is identical on
# both ranks. The rank-selector wrapper runs nsys only for rank 0 and
# the bare binary for rank 1.
RANK_WRAP="${OUT_CONTAINER}/rank_select.sh"
cat > "$RANK_WRAP" <<RANK_EOF
#!/bin/bash
R="\${OMPI_COMM_WORLD_RANK:-0}"
if [ "\$R" = "0" ]; then
  exec "$NSYS" profile \\
      --trace=cuda,nvtx,mpi --mpi-impl=openmpi \\
      --sample=none --cpuctxsw=none \\
      --delay="$NSYS_DELAY_S" --duration="$NSYS_DURATION_S" \\
      --kill=sigterm --force-overwrite=true \\
      --output="${OUT_CONTAINER}/phase0_rank0" "$GPU_BIN"
else
  exec "$GPU_BIN"
fi
RANK_EOF
chmod +x "$RANK_WRAP"

mpirun --allow-run-as-root -n "$NRANKS" "$RANK_WRAP" &
MPIRUN_PID=$!

SFINCS_BASENAME=$(basename "$GPU_BIN")
RANK0_PID=""
for _ in $(seq 1 40); do
    sleep 0.5
    RANK0_PID=$(pgrep -x "$SFINCS_BASENAME" 2>/dev/null | sort -n | head -1 || true)
    [ -n "$RANK0_PID" ] && break
done
if [ -z "$RANK0_PID" ]; then
    echo "WARNING: no rank-0 sfincs PID within 20 s; CPU% sampling skipped." >&2
else
    echo "rank-0 sfincs PID: $RANK0_PID" >&2
    top -b -d "$TOP_INTERVAL_S" -p "$RANK0_PID" > "${OUT_CONTAINER}/rank0_top.txt" 2>&1 &
    TOP_PID=$!
fi

wait "$MPIRUN_PID"
RC=$?
if [ -n "${TOP_PID:-}" ]; then
    kill -TERM "$TOP_PID" 2>/dev/null || true
    wait "$TOP_PID" 2>/dev/null || true
fi
exit "$RC"
IN_CONTAINER_EOF
chmod +x "$IN_CONTAINER_SCRIPT"

OUT_DIR_CONTAINER="/work${OUT_DIR#$REPO_ROOT}"
IN_CONTAINER_SCRIPT_CONTAINER="/work${IN_CONTAINER_SCRIPT#$REPO_ROOT}"

WALL_START=$(date +%s)
echo "--- launching nsys-wrapped sfincs ($NRANKS ranks, CUDA-aware HPC-X) ---"
set +e
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
    bash "$IN_CONTAINER_SCRIPT_CONTAINER" \
        "$NRANKS" \
        "$TOP_INTERVAL_S" \
        "$GPU_BIN" \
        "$OUT_DIR_CONTAINER" \
        "$NSYS_DELAY_S" \
        "$NSYS_DURATION_S" \
    > "$OUT_DIR/sfincs.stdout" 2>&1
SFINCS_RC=$?
set -e
WALL_END=$(date +%s)

kill -TERM "$NVSMI_PID" 2>/dev/null || true
wait "$NVSMI_PID" 2>/dev/null || true

cp -f "$RUN_DIR/sfincs.log" "$OUT_DIR/sfincs.log" 2>/dev/null || true
rm -f "$IN_CONTAINER_SCRIPT" "$OUT_DIR/rank_select.sh"

echo "--- run complete: rc=$SFINCS_RC wall=$((WALL_END - WALL_START))s ---"
ls -l "$OUT_DIR"/phase0_rank0.nsys-rep 2>/dev/null || echo "WARNING: no .nsys-rep produced"

# --- nsys export + supporting stats CSVs ---------------------------------
# nsys lives only in the container. The :nvtx-name modifier on the stats
# reports projects NVTX ranges onto *kernels* only, not memory ops, so
# per-NVTX-range BYTE attribution can't come from `nsys stats`; it is
# done by analyze_phase0.py via a SQLite join (RUNTIME.correlationId ->
# MEMCPY, RUNTIME.start within an NVTX push/pop [start,end]). Here we
# (1) export the rep to SQLite for that join and (2) keep two stats
# CSVs as human-readable cross-check artifacts:
#   nvtx_pushpop_sum     — per-range invocation counts (step count)
#   cuda_gpu_mem_size_sum — total HtoD/DtoH bytes (the join must sum to
#                           these within the unattributed-init residual)
echo "--- nsys export (sqlite) + stats CSVs (rank 0) ---"
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
        REP=phase0_rank0.nsys-rep
        "$NSYS" export --type sqlite --force-overwrite true \
            --output phase0_rank0.sqlite "$REP"
        "$NSYS" stats --force-export=true --format csv \
            --report nvtx_pushpop_sum --output nvtx_pushpop_sum "$REP"
        "$NSYS" stats --force-export=true --format csv \
            --report cuda_gpu_mem_size_sum --output cuda_gpu_mem_size_sum "$REP"
    ' > "$OUT_DIR/nsys_stats.stdout" 2>&1 || \
    { echo "nsys export/stats failed; see nsys_stats.stdout" >&2; }

# nsys stats appends _<report> to the --output base; drop the doubled
# suffix so the committed CSVs read cleanly.
[ -f "$OUT_DIR/nvtx_pushpop_sum_nvtx_pushpop_sum.csv" ] && \
    mv -f "$OUT_DIR/nvtx_pushpop_sum_nvtx_pushpop_sum.csv" \
          "$OUT_DIR/nvtx_pushpop_sum.csv"
[ -f "$OUT_DIR/cuda_gpu_mem_size_sum_cuda_gpu_mem_size_sum.csv" ] && \
    mv -f "$OUT_DIR/cuda_gpu_mem_size_sum_cuda_gpu_mem_size_sum.csv" \
          "$OUT_DIR/cuda_gpu_mem_size_sum.csv"

ls -l "$OUT_DIR"/phase0_rank0.sqlite "$OUT_DIR"/*.csv 2>/dev/null \
    || echo "WARNING: no sqlite / stats CSV produced"

# --- analysis + summary.md (host python3) ---------------------------------
if [ -f "$OUT_DIR/analyze_phase0.py" ]; then
    echo "--- writing summary.md ---"
    python3 "$OUT_DIR/analyze_phase0.py" "$OUT_DIR"
else
    echo "--- analyze_phase0.py absent; skipping summary.md (schema probe) ---"
fi

# --- prune bulky non-committed intermediates -----------------------------
# The .sqlite (hundreds of MB) is fully regenerable from the committed
# .nsys-rep via `nsys export --type sqlite`; the staged run/ dir holds
# only symlinks + a copied sfincs.inp. Neither is part of the committed
# artifact set; drop them so the directory is exactly what ships.
rm -rf "$RUN_DIR" "$OUT_DIR/phase0_rank0.sqlite"

echo "=== Phase 0 capture complete ==="
echo "    artifacts: $(ls "$OUT_DIR"/phase0_rank0.nsys-rep "$OUT_DIR"/summary.md 2>/dev/null | tr '\n' ' ')"
exit "$SFINCS_RC"
