#!/bin/bash
# SOR-1018 — profile the per-step CUDA-MPI halo-exchange / device-sync
# overhead on gpu_n2 that SOR-1017's scaling sweep
# (tests/perf/perf-scaling-sweep-20260519/SUMMARY.md) identified as
# per-step (the unaccounted gap U(L) grows linearly with step count,
# ~0.10-0.17 ms / step, NOT a fixed startup cost).
#
# Runs case_prod_regular_tide (the issue's named exemplar — 37 % of
# gpu_n2 4d wall is unaccounted) at gpu_n2 (mpirun -n 2 inside the
# sfincs-build-gpu container) under `nsys profile` with CUDA + NVTX +
# MPI tracing, one report per rank. Then runs `nsys stats` to extract:
#
#   * nvtx_pushpop_sum  — the named per-step spans: halo_q_uv /
#     halo_zs / halo_zsderv / halo_z_volume / snapwave_update
#     (pushed in sfincs_lib.F90's time loop around the four
#     halo_exchange_* calls + the SnapWave coupling step)
#   * cuda_api_sum      — cudaDeviceSynchronize count + total/avg
#     (10 per step on gpu_n2: 4 in halo_exchange_q_uv, 2 each in
#     halo_exchange_zs / _zsderv / _z_volume)
#   * mpi_event_sum     — MPI_Allreduce (the per-step global-dt
#     reduction at sfincs_lib.F90:450) / MPI_Isend / MPI_Irecv /
#     MPI_Waitall count + total/avg
#   * cuda_gpu_kern_sum — kernel-side context (how much GPU time the
#     halo gather/scatter !$cuf kernels actually consume vs. the
#     host-side sync/MPI wrapping them)
#
# Each table, divided by the step count parsed from sfincs.log, gives
# the per-call per-step cost breakdown the FINDINGS.md AC asks for.
#
# Usage (from repo root):
#
#     tests/perf/halo-exchange-profile-20260519/run_halo_profile.sh
#     tests/perf/halo-exchange-profile-20260519/run_halo_profile.sh --length 4d
#     tests/perf/halo-exchange-profile-20260519/run_halo_profile.sh --skip-build
#     tests/perf/halo-exchange-profile-20260519/run_halo_profile.sh --case case_prod_riverine
#
# Build cost: ~10-15 min GPU container build (skip with --skip-build
# once source/install_cuda/bin/sfincs exists). Profile cost: the 24h
# regular_tide cell is ~10 s wall; nsys tracing + post-processing adds
# ~1-3 min. Well under the AC's <10 min budget.

set -uo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
OUT_DIR=$(cd "$(dirname "$0")" && pwd)

GPU_BIN_HOST=$REPO_ROOT/source/install_cuda/bin/sfincs
GPU_WRAPPER=$REPO_ROOT/source/build_scripts/run_gpu_container.sh

CASE_NAME=case_prod_regular_tide
LENGTH=24h
SKIP_BUILD=0
NRANKS=2

while [ $# -gt 0 ]; do
    case "$1" in
        --case)   CASE_NAME=$2; shift ;;
        --length) LENGTH=$2; shift ;;
        --skip-build) SKIP_BUILD=1 ;;
        --nranks) NRANKS=$2; shift ;;
        -h|--help) sed -n '2,46p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done

CASE_DIR=$REPO_ROOT/tests/cases/$CASE_NAME
RUN_DIR=$OUT_DIR/${CASE_NAME}__${LENGTH}__gpu_n${NRANKS}

LOG=$OUT_DIR/run.stdout
exec > >(tee -a "$LOG") 2>&1
echo "=== SOR-1018 halo-exchange profile — start $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo "case=$CASE_NAME length=$LENGTH config=gpu_n${NRANKS}"

# --- Environment fingerprint ------------------------------------------------

GPU_MODEL=$(nvidia-smi -L 2>/dev/null | head -1 | sed -E 's/^GPU [0-9]+: //; s/ \(UUID:.*//')
NGPU=$(nvidia-smi -L 2>/dev/null | wc -l)
HEAD_REV=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)
cat > "$OUT_DIR/capture_env.txt" <<EOF
SOR-1018 halo-exchange-profile capture environment
==================================================
host GPU         : $GPU_MODEL  x$NGPU
container image  : sfincs-build-gpu:latest
HEAD             : $HEAD_REV ($(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown))
captured-at      : $(date -u +%Y-%m-%dT%H:%M:%SZ)
nsys (container) : $(timeout 60 docker run --rm --entrypoint bash "${SFINCS_GPU_IMAGE:-sfincs-build-gpu:latest}" -c 'nsys --version' 2>/dev/null | tail -1)
case             : $CASE_NAME
length           : $LENGTH
config           : gpu_n${NRANKS}
EOF

# --- Helpers ----------------------------------------------------------------

host_to_container() {
    local p=$1
    case "$p" in
        "$REPO_ROOT") echo "/work" ;;
        "$REPO_ROOT"/*) echo "/work${p#"$REPO_ROOT"}" ;;
        *) echo "host_to_container: '$p' outside REPO_ROOT" >&2; exit 1 ;;
    esac
}

tstop_for() {
    case "$1" in
        1h)  echo "20200101 010000" ;;
        6h)  echo "20200101 060000" ;;
        24h) echo "20200102 000000" ;;
        4d)  echo "20200105 000000" ;;
        *) echo "tstop_for: unknown length '$1'" >&2; exit 3 ;;
    esac
}

sim_seconds_for() {
    case "$1" in
        1h)  echo 3600    ;;
        6h)  echo 21600   ;;
        24h) echo 86400   ;;
        4d)  echo 345600  ;;
        *) echo 0 ;;
    esac
}

stage_case() {
    local case_dir=$1 run_dir=$2
    mkdir -p "$run_dir"
    find "$run_dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    local entry base
    for entry in "$case_dir"/*; do
        [ -e "$entry" ] || continue
        base=$(basename "$entry")
        case "$base" in
            README.md|fetch.sh|generate.py) ;;
            sfincs.inp) cp -- "$entry" "$run_dir/$base" ;;
            *) ln -srf -- "$entry" "$run_dir/$base" ;;
        esac
    done
}

rewrite_tstop() {
    local run_dir=$1 tstop=$2
    awk -v ts="$tstop" '
        $1 == "tstop" { sub(/=.*/, "= " ts); }
        { print }
    ' "$run_dir/sfincs.inp" > "$run_dir/sfincs.inp.new"
    mv "$run_dir/sfincs.inp.new" "$run_dir/sfincs.inp"
}

# step_count = round( sim_seconds / avg_dt ) + 1, same estimator the
# SOR-1017 sweep uses (sfincs_lib.F90:945 dtavg = dtavg/(nt-1)).
parse_step_count() {
    local log=$1 sim_seconds=$2
    awk -v sim="$sim_seconds" '
        /Average time step/ {
            s=$0; p=index(s, ":"); if (p>0) s=substr(s,p+1)
            if (match(s, /[0-9]+[.][0-9]+/)) dt=substr(s,RSTART,RLENGTH)+0
        }
        END { if (dt>0) printf "%d", (sim/dt)+1; else print "" }
    ' "$log"
}

# --- Build ------------------------------------------------------------------

if [ "$SKIP_BUILD" -ne 1 ] || [ ! -x "$GPU_BIN_HOST" ]; then
    echo "=== building GPU (nvfortran) at $REPO_ROOT ==="
    for sub in src third_party_open; do
        find "$REPO_ROOT/source/$sub" -type f \
            \( -name '*.mod' -o -name '*.o' -o -name '*.lo' \
               -o -name '*.a' -o -name '*.la' \) -delete 2>/dev/null || true
    done
    ( cd "$REPO_ROOT"
      source/build_scripts/run_gpu_container.sh source/build_scripts/build_cuda.sh )
fi
[ -x "$GPU_BIN_HOST" ] || { echo "ERROR: $GPU_BIN_HOST not built" >&2; exit 3; }

# --- Profile ----------------------------------------------------------------

stage_case "$CASE_DIR" "$RUN_DIR"
rewrite_tstop "$RUN_DIR" "$(tstop_for "$LENGTH")"

CONTAINER_RUN_DIR=$(host_to_container "$RUN_DIR")
CONTAINER_BIN=/work/source/install_cuda/bin/sfincs
REPORT_BASE=$CONTAINER_RUN_DIR/nsys_report_rank
rm -f "$RUN_DIR"/nsys_report_rank*.nsys-rep "$RUN_DIR"/nsys_report_rank*.sqlite

echo "--- [gpu_n${NRANKS}] $CASE_NAME $LENGTH under nsys profile ---"
wall_start=$(date +%s)
# Per-rank nsys: each MPI rank execs its own nsys, writing
# nsys_report_rank<RANK>.nsys-rep. --sample=none/--cpuctxsw=none keep
# the trace bounded for a ~34 k-step run while still capturing every
# CUDA API call (cudaDeviceSynchronize), every MPI event, and the
# NVTX push/pop ranges. --mpi-impl=openmpi pins nsys's MPI ABI to
# HPC-X's OpenMPI.
set +e
"$GPU_WRAPPER" \
    mpirun --allow-run-as-root --wdir "$CONTAINER_RUN_DIR" -n "$NRANKS" \
    nsys profile \
        --trace=cuda,nvtx,mpi \
        --mpi-impl=openmpi \
        --sample=none --cpuctxsw=none \
        --force-overwrite=true \
        -o "${REPORT_BASE}%q{OMPI_COMM_WORLD_RANK}" \
        "$CONTAINER_BIN" \
    > "$RUN_DIR/sfincs.stdout" 2>&1
rc=$?
set -e
wall_end=$(date +%s)
echo "    rc=$rc wall=$((wall_end - wall_start))s"

if [ ! -f "$RUN_DIR/sfincs.log" ]; then
    echo "ERROR: $RUN_DIR/sfincs.log absent — run failed; see sfincs.stdout" >&2
    exit 4
fi

SIM_SECONDS=$(sim_seconds_for "$LENGTH")
STEP_COUNT=$(parse_step_count "$RUN_DIR/sfincs.log" "$SIM_SECONDS")
echo "step_count=$STEP_COUNT (sim_seconds=$SIM_SECONDS)"
echo "$STEP_COUNT" > "$RUN_DIR/step_count.txt"

# --- Extract stats ----------------------------------------------------------

# nsys stats runs inside the container (the host nsys is a different
# minor version; keep the toolchain consistent with the capture).
for REP in "$RUN_DIR"/nsys_report_rank*.nsys-rep; do
    [ -e "$REP" ] || { echo "ERROR: no nsys report produced" >&2; exit 5; }
    BASE=$(basename "$REP" .nsys-rep)
    CREP=$CONTAINER_RUN_DIR/$(basename "$REP")
    echo "--- nsys stats for $BASE ---"
    for REPORT in nvtx_pushpop_sum cuda_api_sum mpi_event_sum cuda_gpu_kern_sum mpi_msg_size_sum; do
        "$GPU_WRAPPER" \
            nsys stats --report "$REPORT" --format csv \
            --force-export=true \
            -o "$CONTAINER_RUN_DIR/${BASE}__${REPORT}" \
            "$CREP" > /dev/null 2>&1 || \
            echo "  (warn: $REPORT extraction failed for $BASE)"
    done
done

echo
echo "=== SOR-1018 halo-exchange profile — complete $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo "artifacts under: $RUN_DIR"
ls -1 "$RUN_DIR" 2>/dev/null | sed 's/^/  /'
