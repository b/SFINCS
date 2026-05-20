#!/bin/bash
# tests/perf/run_perf_scaling.sh — canonical perf-scaling-sweep harness.
#
# Captures a per-cell wall-time / SFINCS-component / GPU-utilization
# matrix across four axes:
#
#   * case      — five production cases (see CASES_DEFAULT).
#   * grid      — 1x always; 4x for cases whose generator supports
#                 it (currently case_prod_regular_tide only).
#   * length    — simulation length (tstop - tstart) at 1h / 6h /
#                 24h / 4d.
#   * config    — execution shape:
#
#                   cpu_n1   cpu_n2   cpu_n4   cpu_n8
#                   cpu_n16  cpu_n32  cpu_n64  cpu_n128
#                   gpu_n1   gpu_n2
#
#                 cpu_n<k> sets OMP_NUM_THREADS=k, OMP_PROC_BIND=true
#                 and reuses the same single-process CPU binary.
#                 SFINCS's CPU build is OpenMP-only (no MPI on the
#                 CPU path) — the per-process OMP_NUM_THREADS is the
#                 only knob.
#
# This script is intended to be COPIED into a per-sweep output
# directory by ``tests/perf/run_full_perf_matrix.sh`` and invoked from
# there; OUT_DIR is the dir containing the script. REPO_ROOT is
# discovered via ``git rev-parse``, so the canonical copy can also
# be invoked in-place (cells will then land under tests/perf/).
#
# --- Skip-by-projection (cost control) ------------------------------
#
# cpu_n<k> at small k is expensive: cpu_n1 vs cpu_n128 on a long case
# is ~128x the wall (the OpenMP build scales close-to-perfectly for
# large k on this code). Without a budget, a full matrix capture at
# the smallest thread counts would dwarf the rest of the sweep.
#
# The harness measures the cpu_n128 wall first for every
# (case, grid, length) tuple, then projects each smaller cpu_n<k>'s
# wall as ``cpu_n128_wall × 128/k``. Cells whose projection exceeds
# ``PERF_MAX_CELL_WALL_MIN`` minutes (default 30) are SKIPPED:
#
#   * no SFINCS run for that cell.
#   * a ``timings.txt`` is still written, carrying
#     ``skipped_estimated_wall <minutes>`` so the analysis layer
#     can plot a marker at the projected position.
#
# Override the threshold per-invocation:
#
#     PERF_MAX_CELL_WALL_MIN=60 bash tests/perf/run_perf_scaling.sh
#
# --- Output layout (under OUT_DIR) ----------------------------------
#
#     capture_env.txt
#     run.stdout
#     <case>__<grid>__<length>__<config>/
#       sfincs.inp                — length-modified (and grid-refined) input
#       sfincs.log                — SFINCS internal timing summary (run cells)
#       sfincs.stdout             — mpirun / OMP stdout (run cells)
#       nvidia_smi_dmon.txt       — GPU dmon snapshot (gpu_* cells)
#       timings.txt               — parsed numbers consumed by analyze layer
#
# --- Args -----------------------------------------------------------
#
#     --case <name>     Restrict to this case (repeatable).
#     --length <tag>    Restrict to this length (repeatable).
#     --config <cfg>    Restrict to this config (repeatable; e.g. cpu_n8).
#     --skip-build      Reuse existing source/install_cpu + source/install_cuda binaries.
#     --drop-4d         Drop the 4d length entirely.
#     --drop-4d-cpu     Drop only the cpu_* cells at 4d (gpu cells stay).
#     --no-4x           Skip the 4x grid axis.
#     --max-cell-min N  Equivalent to PERF_MAX_CELL_WALL_MIN=N.
#

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# REPO_ROOT discovery: prefer git rev-parse (robust); fall back to the
# legacy three-levels-up assumption for installs that include .git
# trimming. Failure to find REPO_ROOT is fatal — refuse rather than
# producing garbled paths.
if REPO_ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null); then
    :
else
    REPO_ROOT=$(cd "$SCRIPT_DIR/../../.." && pwd)
fi
if [ ! -d "$REPO_ROOT/source" ]; then
    echo "ERROR: could not locate REPO_ROOT from $SCRIPT_DIR; cd somewhere under the SFINCS checkout first" >&2
    exit 1
fi

OUT_DIR=$SCRIPT_DIR

CPU_BIN=$REPO_ROOT/source/install_cpu/bin/sfincs
GPU_BIN_HOST=$REPO_ROOT/source/install_cuda/bin/sfincs
GPU_WRAPPER=$REPO_ROOT/source/build_scripts/run_gpu_container.sh

# Production case set.
CASES_DEFAULT=(
    case_prod_regular_tide
    case_prod_quadtree_subgrid_tide
    case_prod_riverine
    case_prod_storm_amuv
    case_prod_compound_snapwave
)

# Length axis.
LENGTHS_DEFAULT=(1h 6h 24h 4d)

# CPU thread-count axis. cpu_n128 is the host-saturating run; the
# smaller k values capture the OpenMP scaling curve.
CPU_THREAD_COUNTS_DEFAULT=(1 2 4 8 16 32 64 128)

# GPU configs run unconditionally — they're cheap and not gated by
# the thread-count budget.
GPU_CONFIGS_DEFAULT=(gpu_n1 gpu_n2)

# Grids the harness understands. 4x only for the simple regular-grid
# case (others would need refined auxiliary forcing).
GRIDS_1X_ONLY=(
    case_prod_quadtree_subgrid_tide
    case_prod_riverine
    case_prod_storm_amuv
    case_prod_compound_snapwave
)

# --- Argument parsing -------------------------------------------------------

SELECTED_CASES=()
SELECTED_LENGTHS=()
SELECTED_CONFIGS=()
SKIP_BUILD=0
DROP_4D=0
DROP_4D_CPU=0
NO_4X=0
while [ $# -gt 0 ]; do
    case "$1" in
        --case) SELECTED_CASES+=("$2"); shift ;;
        --length) SELECTED_LENGTHS+=("$2"); shift ;;
        --config) SELECTED_CONFIGS+=("$2"); shift ;;
        --skip-build) SKIP_BUILD=1 ;;
        --drop-4d) DROP_4D=1 ;;
        --drop-4d-cpu) DROP_4D_CPU=1 ;;
        --no-4x) NO_4X=1 ;;
        --max-cell-min) PERF_MAX_CELL_WALL_MIN=$2; shift ;;
        -h|--help) sed -n '2,75p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done

PERF_MAX_CELL_WALL_MIN=${PERF_MAX_CELL_WALL_MIN:-30}

if [ ${#SELECTED_CASES[@]} -eq 0 ]; then
    CASES=("${CASES_DEFAULT[@]}")
else
    CASES=("${SELECTED_CASES[@]}")
fi
if [ ${#SELECTED_LENGTHS[@]} -eq 0 ]; then
    LENGTHS=("${LENGTHS_DEFAULT[@]}")
else
    LENGTHS=("${SELECTED_LENGTHS[@]}")
fi
if [ "$DROP_4D" -eq 1 ]; then
    NEW_LENGTHS=()
    for L in "${LENGTHS[@]}"; do
        [ "$L" = "4d" ] && continue
        NEW_LENGTHS+=("$L")
    done
    LENGTHS=("${NEW_LENGTHS[@]}")
fi

# Build the CPU configs list — selectable but defaulting to the full
# thread-count axis. Each entry is "cpu_n<k>".
CPU_CONFIGS=()
for k in "${CPU_THREAD_COUNTS_DEFAULT[@]}"; do
    CPU_CONFIGS+=("cpu_n${k}")
done

# Apply --config filter to BOTH cpu_* and gpu_* lists.
if [ ${#SELECTED_CONFIGS[@]} -gt 0 ]; then
    FILTERED_CPU=()
    for cfg in "${CPU_CONFIGS[@]}"; do
        for sel in "${SELECTED_CONFIGS[@]}"; do
            [ "$cfg" = "$sel" ] && FILTERED_CPU+=("$cfg") && break
        done
    done
    CPU_CONFIGS=("${FILTERED_CPU[@]}")
    FILTERED_GPU=()
    for cfg in "${GPU_CONFIGS_DEFAULT[@]}"; do
        for sel in "${SELECTED_CONFIGS[@]}"; do
            [ "$cfg" = "$sel" ] && FILTERED_GPU+=("$cfg") && break
        done
    done
    GPU_CONFIGS=("${FILTERED_GPU[@]}")
else
    GPU_CONFIGS=("${GPU_CONFIGS_DEFAULT[@]}")
fi

# --- Environment fingerprint ------------------------------------------------

NPROC=$(nproc)
HOST_CPU=$(lscpu | awk -F: '/^Model name/ {gsub(/^ +/, "", $2); print $2; exit}')
PHYSICAL_CORES=$(lscpu | awk -F: '/^Core\(s\) per socket/ {gsub(/^ +/, "", $2); cps=$2} /^Socket\(s\)/ {gsub(/^ +/, "", $2); s=$2} END {print s*cps}')
GPU_MODEL=$(nvidia-smi -L 2>/dev/null | head -1 | sed -E 's/^GPU [0-9]+: //; s/ \(UUID:.*//')
NGPU=$(nvidia-smi -L 2>/dev/null | wc -l)
HEAD_REV=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)

cat > "$OUT_DIR/capture_env.txt" <<EOF
SFINCS perf-scaling-sweep capture environment
=============================================
host CPU         : $HOST_CPU
physical cores   : $PHYSICAL_CORES
logical CPUs     : $NPROC  (nproc; SMT counts both threads)
host GPU         : $GPU_MODEL  x$NGPU
container image  : sfincs-build-gpu:latest
HEAD             : $HEAD_REV ($(git -C "$REPO_ROOT" rev-parse HEAD))
captured-at      : $(date -u +%Y-%m-%dT%H:%M:%SZ)
PERF_MAX_CELL_WALL_MIN : $PERF_MAX_CELL_WALL_MIN  (per-cell projection budget)

CPU thread-count axis rationale
-------------------------------
SFINCS's CPU build supports OpenMP (-fopenmp) and not MPI; MPI calls
in source/src/sfincs_lib.F90 are gated on USE_CUDA. Each cpu_n<k>
runs the same single-process CPU binary with OMP_NUM_THREADS=k and
OMP_PROC_BIND=true. cpu_n128 = OMP_NUM_THREADS=$NPROC, single process.

Cells whose projected wall (cpu_n128 measured wall × 128 / k) exceeds
PERF_MAX_CELL_WALL_MIN minutes are skipped — timings.txt for the
skipped cell carries a "skipped_estimated_wall <minutes>" annotation
so the analysis layer can plot a marker at the projected position.
EOF

LOG=$OUT_DIR/run.stdout
exec > >(tee -a "$LOG") 2>&1
echo "=== perf-scaling sweep — start $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo "cases       : ${CASES[*]}"
echo "lengths     : ${LENGTHS[*]}"
echo "cpu configs : ${CPU_CONFIGS[*]:-<none>}"
echo "gpu configs : ${GPU_CONFIGS[*]:-<none>}"
echo "no-4x       : $NO_4X"
echo "nproc       : $NPROC"
echo "max cell wall : ${PERF_MAX_CELL_WALL_MIN} min  (skip cpu_n<k> when projected wall > threshold)"

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

# 4x-cell-count refinement of case_prod_regular_tide. Looks for
# generate_4x_regular_tide.py alongside this script (placed there by
# the orchestrator).
refine_regular_tide_4x() {
    local run_dir=$1
    if [ ! -f "$OUT_DIR/generate_4x_regular_tide.py" ]; then
        echo "ERROR: $OUT_DIR/generate_4x_regular_tide.py not present; cannot refine 4x" >&2
        exit 4
    fi
    python3 "$OUT_DIR/generate_4x_regular_tide.py" "$run_dir"
}

extract_timings() {
    local log=$1 out=$2 sim_seconds=$3
    local re='[0-9]+[.][0-9]+'
    pull() {
        local pattern=$1
        awk -v re="$re" -v pat="$pattern" '
            $0 ~ pat {
                s = $0
                p = index(s, ":")
                if (p > 0) s = substr(s, p+1)
                if (match(s, re)) { print substr(s, RSTART, RLENGTH); exit }
            }
        ' "$log"
    }
    local total simulation t_input t_bnd t_mom t_cont t_snap t_meteo t_out avgdt
    total=$(pull '^[[:space:]]*Total time[[:space:]]*:')
    simulation=$(pull '^[[:space:]]*Total simulation time[[:space:]]*:')
    t_input=$(pull '^[[:space:]]*Time in input[[:space:]]*:')
    t_bnd=$(pull '^[[:space:]]*Time in boundaries[[:space:]]*:')
    t_mom=$(pull '^[[:space:]]*Time in momentum[[:space:]]*:')
    t_cont=$(pull '^[[:space:]]*Time in continuity[[:space:]]*:')
    t_snap=$(pull '^[[:space:]]*Time in SnapWave[[:space:]]*:')
    t_meteo=$(pull '^[[:space:]]*Time in meteo forcing[[:space:]]*:')
    t_out=$(pull '^[[:space:]]*Time in output[[:space:]]*:')
    avgdt=$(pull '^[[:space:]]*Average time step')

    local sum_named
    sum_named=$(awk -v a="$t_bnd" -v b="$t_mom" -v c="$t_cont" \
                    -v d="$t_snap" -v e="$t_meteo" -v f="$t_out" \
        'BEGIN { s=0; for (k=1;k<=6;k++) { v=(k==1?a:(k==2?b:(k==3?c:(k==4?d:(k==5?e:f))))); if (v != "") s += v+0 } printf "%.3f", s }')
    local unaccounted
    unaccounted=$(awk -v sim="$simulation" -v sn="$sum_named" \
        'BEGIN { if (sim == "" || sn == "") print ""; else printf "%.3f", sim-sn }')
    local steps
    steps=$(awk -v sim="$sim_seconds" -v dt="$avgdt" \
        'BEGIN { if (dt == "" || dt+0 == 0) print ""; else printf "%d", (sim/dt)+1 }')

    {
        echo "total ${total}"
        echo "simulation ${simulation}"
        echo "input ${t_input}"
        echo "boundaries ${t_bnd}"
        echo "momentum ${t_mom}"
        echo "continuity ${t_cont}"
        echo "snapwave ${t_snap}"
        echo "meteo ${t_meteo}"
        echo "output ${t_out}"
        echo "avg_dt ${avgdt}"
        echo "sum_named ${sum_named}"
        echo "unaccounted ${unaccounted}"
        echo "step_count ${steps}"
        echo "sim_seconds ${sim_seconds}"
    } > "$out"
}

sim_seconds_for() {
    case "$1" in
        1h)  echo 3600    ;;
        6h)  echo 21600   ;;
        24h) echo 86400   ;;
        4d)  echo 345600  ;;
        *) echo "0" ;;
    esac
}

# Write a "skipped cell" timings.txt with the projected wall in minutes.
# The cell dir is created so the analysis layer can find it and emit
# a placeholder row in the DataFrame.
write_skipped_timings() {
    local cell_dir=$1 projected_min=$2 sim_seconds=$3
    mkdir -p "$cell_dir"
    {
        echo "skipped_estimated_wall ${projected_min}"
        echo "sim_seconds ${sim_seconds}"
    } > "$cell_dir/timings.txt"
}

# --- Build steps ------------------------------------------------------------

build_cpu() {
    echo "=== building CPU (gfortran/OpenMP) at $REPO_ROOT ==="
    for sub in src third_party_open; do
        find "$REPO_ROOT/source/$sub" -type f \
            \( -name '*.mod' -o -name '*.o' -o -name '*.lo' \
               -o -name '*.a' -o -name '*.la' \) -delete 2>/dev/null || true
    done
    (
        cd "$REPO_ROOT/source"
        autoreconf -ivf
        ./autogen.sh
        ./configure FC=gfortran \
            FCFLAGS="-fopenmp -O3 -fallow-argument-mismatch -w" \
            FFLAGS="-fopenmp -O3 -fallow-argument-mismatch -w" \
            --disable-shared \
            --prefix="$PWD/install_cpu"
        make
        make install
    )
}

build_gpu() {
    echo "=== building GPU (nvfortran) at $REPO_ROOT ==="
    for sub in src third_party_open; do
        find "$REPO_ROOT/source/$sub" -type f \
            \( -name '*.mod' -o -name '*.o' -o -name '*.lo' \
               -o -name '*.a' -o -name '*.la' \) -delete 2>/dev/null || true
    done
    (
        cd "$REPO_ROOT"
        source/build_scripts/run_gpu_container.sh source/build_scripts/build_cuda.sh
    )
}

needs_cpu=0
needs_gpu=0
for cfg in "${CPU_CONFIGS[@]}"; do needs_cpu=1; break; done
for cfg in "${GPU_CONFIGS[@]}"; do needs_gpu=1; break; done

ensure_builds() {
    if [ "$needs_cpu" -eq 1 ]; then
        if [ "$SKIP_BUILD" -ne 1 ] || [ ! -x "$CPU_BIN" ]; then
            build_cpu
        fi
        [ -x "$CPU_BIN" ] || { echo "ERROR: $CPU_BIN not built" >&2; exit 3; }
    fi
    if [ "$needs_gpu" -eq 1 ]; then
        if [ "$SKIP_BUILD" -ne 1 ] || [ ! -x "$GPU_BIN_HOST" ]; then
            build_gpu
        fi
        [ -x "$GPU_BIN_HOST" ] || { echo "ERROR: $GPU_BIN_HOST not built" >&2; exit 3; }
    fi
}

# --- Run steps --------------------------------------------------------------

# run_cpu_cell ... ; CPU_CELL_WALL is set to the measured wall seconds
# (or "" on failure). Caller uses it for cpu_n<k> projection.
CPU_CELL_WALL=""

run_cpu_cell() {
    local case_name=$1 case_dir=$2 length=$3 grid=$4 nthreads=$5
    local cfg=cpu_n${nthreads}
    local run_dir=$OUT_DIR/${case_name}__${grid}__${length}__${cfg}
    stage_case "$case_dir" "$run_dir"
    if [ "$grid" = "4x" ]; then refine_regular_tide_4x "$run_dir"; fi
    rewrite_tstop "$run_dir" "$(tstop_for "$length")"
    echo "--- [${cfg}] $case_name $grid $length ---"
    local wall_start wall_end rc
    wall_start=$(date +%s)
    set +e
    (
        cd "$run_dir"
        OMP_NUM_THREADS=$nthreads OMP_DYNAMIC=false OMP_PROC_BIND=true \
            "$CPU_BIN" >sfincs.log 2>sfincs.stdout
    )
    rc=$?
    set -e
    wall_end=$(date +%s)
    local wall=$((wall_end - wall_start))
    echo "    rc=$rc wall=${wall}s log=$run_dir/sfincs.log"
    extract_timings "$run_dir/sfincs.log" "$run_dir/timings.txt" "$(sim_seconds_for "$length")"
    CPU_CELL_WALL=$wall
}

run_gpu_cell() {
    local case_name=$1 case_dir=$2 length=$3 grid=$4 nranks=$5
    local cfg=gpu_n${nranks}
    local run_dir=$OUT_DIR/${case_name}__${grid}__${length}__${cfg}
    stage_case "$case_dir" "$run_dir"
    if [ "$grid" = "4x" ]; then refine_regular_tide_4x "$run_dir"; fi
    rewrite_tstop "$run_dir" "$(tstop_for "$length")"
    local container_run_dir
    container_run_dir=$(host_to_container "$run_dir")
    local container_bin=/work/source/install_cuda/bin/sfincs
    echo "--- [$cfg] $case_name $grid $length ---"
    local wall_start wall_end rc
    wall_start=$(date +%s)
    nvidia-smi dmon -i 0,1 -d 1 -c 1000000 \
        -s u 2>&1 > "$run_dir/nvidia_smi_dmon.txt" &
    local dmon_pid=$!
    set +e
    "$GPU_WRAPPER" \
        mpirun --allow-run-as-root --wdir "$container_run_dir" \
        -n "$nranks" "$container_bin" \
        >"$run_dir/sfincs.stdout" 2>&1
    rc=$?
    set -e
    kill "$dmon_pid" 2>/dev/null || true
    wait "$dmon_pid" 2>/dev/null || true
    wall_end=$(date +%s)
    echo "    rc=$rc wall=$((wall_end - wall_start))s log=$run_dir/sfincs.log"
    extract_timings "$run_dir/sfincs.log" "$run_dir/timings.txt" "$(sim_seconds_for "$length")"
}

case_does_4x() {
    local case_name=$1
    [ "$NO_4X" -eq 1 ] && return 1
    local skip
    for skip in "${GRIDS_1X_ONLY[@]}"; do
        [ "$case_name" = "$skip" ] && return 1
    done
    return 0
}

# --- Main -------------------------------------------------------------------

ensure_builds

# Capture full sweep stats for budget summary.
TOTAL_CELLS_RUN=0
TOTAL_CELLS_SKIPPED=0
SWEEP_T0=$(date +%s)

for case_name in "${CASES[@]}"; do
    case_dir=$REPO_ROOT/tests/cases/$case_name
    if [ ! -f "$case_dir/sfincs.inp" ]; then
        echo "SKIP $case_name — no sfincs.inp (input not fetched?)"
        continue
    fi
    GRIDS=(1x)
    if case_does_4x "$case_name"; then GRIDS=(1x 4x); fi
    echo
    echo "===== case: $case_name (grids: ${GRIDS[*]}) ====="
    for grid in "${GRIDS[@]}"; do
        for length in "${LENGTHS[@]}"; do
            # CPU cells. cpu_n${NPROC} (==cpu_n128) runs first and
            # establishes the baseline used for projecting smaller-k
            # cells. The other cpu_n<k> are evaluated against the
            # PERF_MAX_CELL_WALL_MIN budget.
            BASELINE_WALL=""
            # First pass: cpu_n${NPROC} if requested.
            for cpu_cfg in "${CPU_CONFIGS[@]}"; do
                k=${cpu_cfg#cpu_n}
                if [ "$k" -ne "$NPROC" ]; then continue; fi
                if [ "$DROP_4D_CPU" -eq 1 ] && [ "$length" = "4d" ]; then
                    echo "--- [skip $cpu_cfg] $case_name $grid 4d (per --drop-4d-cpu) ---"
                    write_skipped_timings \
                        "$OUT_DIR/${case_name}__${grid}__${length}__${cpu_cfg}" \
                        "" "$(sim_seconds_for "$length")"
                    TOTAL_CELLS_SKIPPED=$((TOTAL_CELLS_SKIPPED+1))
                    continue
                fi
                run_cpu_cell "$case_name" "$case_dir" "$length" "$grid" "$k"
                BASELINE_WALL=$CPU_CELL_WALL
                TOTAL_CELLS_RUN=$((TOTAL_CELLS_RUN+1))
            done
            # Second pass: cpu_n<k> for k != NPROC, projection-gated.
            for cpu_cfg in "${CPU_CONFIGS[@]}"; do
                k=${cpu_cfg#cpu_n}
                if [ "$k" -eq "$NPROC" ]; then continue; fi
                if [ "$k" -gt "$NPROC" ]; then
                    echo "--- [skip $cpu_cfg] $case_name $grid $length (k=$k > NPROC=$NPROC) ---"
                    write_skipped_timings \
                        "$OUT_DIR/${case_name}__${grid}__${length}__${cpu_cfg}" \
                        "" "$(sim_seconds_for "$length")"
                    TOTAL_CELLS_SKIPPED=$((TOTAL_CELLS_SKIPPED+1))
                    continue
                fi
                if [ -z "$BASELINE_WALL" ] || [ "$BASELINE_WALL" = "0" ]; then
                    # No baseline measured — skip with empty projection.
                    echo "--- [skip $cpu_cfg] $case_name $grid $length (no cpu_n${NPROC} baseline) ---"
                    write_skipped_timings \
                        "$OUT_DIR/${case_name}__${grid}__${length}__${cpu_cfg}" \
                        "" "$(sim_seconds_for "$length")"
                    TOTAL_CELLS_SKIPPED=$((TOTAL_CELLS_SKIPPED+1))
                    continue
                fi
                projected_min=$(awk -v w="$BASELINE_WALL" -v n="$NPROC" -v k="$k" \
                    'BEGIN { printf "%.2f", (w * n / k) / 60.0 }')
                budget=$PERF_MAX_CELL_WALL_MIN
                over=$(awk -v p="$projected_min" -v b="$budget" \
                    'BEGIN { print (p+0 > b+0) ? 1 : 0 }')
                if [ "$over" = "1" ]; then
                    echo "--- [skip $cpu_cfg] $case_name $grid $length (projected ${projected_min} min > ${budget} min budget) ---"
                    write_skipped_timings \
                        "$OUT_DIR/${case_name}__${grid}__${length}__${cpu_cfg}" \
                        "$projected_min" "$(sim_seconds_for "$length")"
                    TOTAL_CELLS_SKIPPED=$((TOTAL_CELLS_SKIPPED+1))
                else
                    run_cpu_cell "$case_name" "$case_dir" "$length" "$grid" "$k"
                    TOTAL_CELLS_RUN=$((TOTAL_CELLS_RUN+1))
                fi
            done
            # GPU cells.
            for gpu_cfg in "${GPU_CONFIGS[@]}"; do
                nranks=${gpu_cfg#gpu_n}
                run_gpu_cell "$case_name" "$case_dir" "$length" "$grid" "$nranks"
                TOTAL_CELLS_RUN=$((TOTAL_CELLS_RUN+1))
            done
        done
    done
done

SWEEP_T1=$(date +%s)
echo
echo "=== perf-scaling sweep — complete $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo "    cells run     : $TOTAL_CELLS_RUN"
echo "    cells skipped : $TOTAL_CELLS_SKIPPED"
echo "    total wall    : $((SWEEP_T1 - SWEEP_T0)) s"
