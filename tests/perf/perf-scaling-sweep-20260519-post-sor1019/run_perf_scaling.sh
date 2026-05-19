#!/bin/bash
# SOR-1020 — post-SOR-1019 re-run of the SOR-1017 scaling sweep.
#
# Same matrix as SOR-1017 (see tests/perf/perf-scaling-sweep-20260519/),
# but captured at a HEAD that includes the SOR-1018 (q+uv) and
# SOR-1019 (zs+zsderv+z_volume) per-step halo-exchange coalescing
# fixes. Output is consumed by build_summary.sh alongside this file
# to render the post-fix SUMMARY.md and, after manual editing, the
# delta-vs-SOR-1017-baseline section.
#
# Follow-up to SOR-87 (tests/perf/perf-matrix-20260518/). Same shape
# (CPU full-cores OpenMP vs gpu_n1 vs gpu_n2 in sfincs-build-gpu
# container) but extends along TWO new axes:
#
#   * simulation length: 1h, 6h, 24h, 4d (vary tstop; tstart fixed)
#   * grid: native (1x) for all 5 production cases; 4x cell-count
#     refinement for case_prod_regular_tide only — the four other
#     cases ship with auxiliary forcing files (quadtree netcdf,
#     subgrid lookup, gridded meteo, SCS infiltration grid) whose
#     refinement is out of scope for a perf-only harness. Skips
#     are documented in SUMMARY.md per AC.
#
# Goal: distinguish whether the post-fix gpu_n2 "unaccounted time"
# gap (total_simulation - sum_of_named_components) scales per-step
# or is a fixed setup cost. Per-cell timings.txt carries enough
# fields for build_summary.sh to compute unaccounted_gap and
# unaccounted_gap / step_count.
#
# This is post-fix only: no `pre` revision column (SOR-87 already
# closed the pre/post comparison).
#
# Captured per (case, length, config, grid) into
# tests/perf/perf-scaling-sweep-20260519/<case>__<grid>__<length>__<config>/:
#   * sfincs.inp              — the length-modified (and grid-refined) input
#   * sfincs.log              — SFINCS run log incl. timing summary
#   * sfincs.stdout           — mpirun / OMP stdout
#   * nvidia_smi_dmon.txt     — GPU dmon snapshot (gpu_* only)
#   * timings.txt             — parsed numbers consumed by SUMMARY
#
# Top-level outputs:
#   * SUMMARY.md              — per-case per-step-vs-fixed-cost verdict
#   * capture_env.txt         — host CPU / GPU / nproc / commit
#   * run.stdout              — orchestration log
#
# Usage (from repo root):
#
#     tests/perf/perf-scaling-sweep-20260519/run_perf_scaling.sh
#     tests/perf/perf-scaling-sweep-20260519/run_perf_scaling.sh --case case_prod_regular_tide
#     tests/perf/perf-scaling-sweep-20260519/run_perf_scaling.sh --length 1h --length 6h
#     tests/perf/perf-scaling-sweep-20260519/run_perf_scaling.sh --skip-build
#     tests/perf/perf-scaling-sweep-20260519/run_perf_scaling.sh --drop-4d
#     tests/perf/perf-scaling-sweep-20260519/run_perf_scaling.sh --no-4x
#
# Build cost: ~5-10 min CPU + ~10-15 min GPU container build.
# Run cost: dominated by cpu_n128 cells at 4d length (largest case
# ~30 min); GPU cells are <1 min each. Full sweep wall ≈ 2-3 h.

set -uo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
OUT_DIR=$(cd "$(dirname "$0")" && pwd)

CPU_BIN=$REPO_ROOT/source/install_cpu/bin/sfincs
GPU_BIN_HOST=$REPO_ROOT/source/install_cuda/bin/sfincs
GPU_WRAPPER=$REPO_ROOT/source/build_scripts/run_gpu_container.sh

# Production case set. Same five as SOR-87.
CASES_DEFAULT=(
    case_prod_regular_tide
    case_prod_quadtree_subgrid_tide
    case_prod_riverine
    case_prod_storm_amuv
    case_prod_compound_snapwave
)

# Length axis. tstart is held at 20200101 000000; tstop is rewritten
# in the staged sfincs.inp. SFINCS computes its own adaptive dt
# subject to dtmax in the input — the simulator handles the new
# tstop transparently.
LENGTHS_DEFAULT=(1h 6h 24h 4d)

CONFIGS=(cpu_n128 gpu_n1 gpu_n2)

# Grids the harness understands. 1x always; 4x only for the simple
# regular-grid case (others would need to regenerate auxiliary
# forcing files whose grids are coupled to the computational mesh).
GRIDS_1X_ONLY=(
    case_prod_quadtree_subgrid_tide  # qtrfile + sbgfile precomputed netcdf
    case_prod_riverine               # sfincs.scs is grid-shape ASCII; weir/src are point-based but scs would need refining
    case_prod_storm_amuv             # sfincs.scs / sfincs.ks etc. on comp grid
    case_prod_compound_snapwave      # quadtree + SnapWave grids
)

# --- Argument parsing -------------------------------------------------------

SELECTED_CASES=()
SELECTED_LENGTHS=()
SKIP_BUILD=0
DROP_4D=0
DROP_4D_CPU=0
NO_4X=0
while [ $# -gt 0 ]; do
    case "$1" in
        --case) SELECTED_CASES+=("$2"); shift ;;
        --length) SELECTED_LENGTHS+=("$2"); shift ;;
        --skip-build) SKIP_BUILD=1 ;;
        --drop-4d) DROP_4D=1 ;;
        --drop-4d-cpu) DROP_4D_CPU=1 ;;
        --no-4x) NO_4X=1 ;;
        -h|--help) sed -n '2,55p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done
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

# --- Environment fingerprint ------------------------------------------------

NPROC=$(nproc)
HOST_CPU=$(lscpu | awk -F: '/^Model name/ {gsub(/^ +/, "", $2); print $2; exit}')
PHYSICAL_CORES=$(lscpu | awk -F: '/^Core\(s\) per socket/ {gsub(/^ +/, "", $2); cps=$2} /^Socket\(s\)/ {gsub(/^ +/, "", $2); s=$2} END {print s*cps}')
GPU_MODEL=$(nvidia-smi -L 2>/dev/null | head -1 | sed -E 's/^GPU [0-9]+: //; s/ \(UUID:.*//')
NGPU=$(nvidia-smi -L 2>/dev/null | wc -l)
HEAD_REV=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)

cat > "$OUT_DIR/capture_env.txt" <<EOF
SOR-1020 post-SOR-1019 scaling-sweep capture environment
========================================================
host CPU         : $HOST_CPU
physical cores   : $PHYSICAL_CORES
logical CPUs     : $NPROC  (nproc; SMT counts both threads)
host GPU         : $GPU_MODEL  x$NGPU
container image  : sfincs-build-gpu:latest
HEAD             : $HEAD_REV ($(git -C "$REPO_ROOT" rev-parse HEAD))
captured-at      : $(date -u +%Y-%m-%dT%H:%M:%SZ)

cpu_n${NPROC} mapping rationale (inherited from SOR-87)
------------------------------
SFINCS's CPU build supports OpenMP (-fopenmp) and not MPI; MPI calls
in source/src/sfincs_lib.F90 are gated on USE_CUDA. cpu_n$NPROC =
OMP_NUM_THREADS=$NPROC, single process.
EOF

LOG=$OUT_DIR/run.stdout
exec > >(tee -a "$LOG") 2>&1
echo "=== SOR-1020 post-SOR-1019 scaling sweep — start $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo "cases  : ${CASES[*]}"
echo "lengths: ${LENGTHS[*]}"
echo "configs: ${CONFIGS[*]}"
echo "no-4x  : $NO_4X"
echo "nproc  : $NPROC  (cpu_n$NPROC)"

# --- Helpers ----------------------------------------------------------------

host_to_container() {
    local p=$1
    case "$p" in
        "$REPO_ROOT") echo "/work" ;;
        "$REPO_ROOT"/*) echo "/work${p#"$REPO_ROOT"}" ;;
        *) echo "host_to_container: '$p' outside REPO_ROOT" >&2; exit 1 ;;
    esac
}

# Translate a length label to a tstop string of the form
# "YYYYMMDD HHMMSS", paired with tstart = "20200101 000000".
tstop_for() {
    case "$1" in
        1h)  echo "20200101 010000" ;;
        6h)  echo "20200101 060000" ;;
        24h) echo "20200102 000000" ;;
        4d)  echo "20200105 000000" ;;
        *) echo "tstop_for: unknown length '$1'" >&2; exit 3 ;;
    esac
}

# Stage a case dir into a clean run dir, copy sfincs.inp (it will be
# rewritten for the chosen length), symlink the rest. README.md /
# fetch.sh / generate.py are skipped.
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

# Rewrite tstop in the staged sfincs.inp (already a writable copy
# courtesy of stage_case). Uses awk to keep the rest of the file
# byte-identical.
rewrite_tstop() {
    local run_dir=$1 tstop=$2
    awk -v ts="$tstop" '
        $1 == "tstop" { sub(/=.*/, "= " ts); }
        { print }
    ' "$run_dir/sfincs.inp" > "$run_dir/sfincs.inp.new"
    mv "$run_dir/sfincs.inp.new" "$run_dir/sfincs.inp"
}

# Generate a 4x-cell-count refined copy of case_prod_regular_tide
# into $1 (run dir). Doubles mmax/nmax, halves dx/dy, and re-runs
# the case's deterministic generator with the refined dimensions
# overridden via env. Only valid for case_prod_regular_tide whose
# generate.py exposes NMAX / MMAX / DX / DY at module scope; we
# rely on the wrapper script generate_4x_regular_tide.py that
# imports those constants, monkey-patches them, and re-runs main().
refine_regular_tide_4x() {
    local run_dir=$1
    python3 "$OUT_DIR/generate_4x_regular_tide.py" "$run_dir"
}

# Compute step count and unaccounted-gap from sfincs.log + a known
# (tstart, tstop) pair. SFINCS prints
#   Total time             :     XX.XXX
#   Total simulation time  :     XX.XXX
#   Time in input          :     XX.XXX
#   Time in boundaries     :     X.XXX ( PP.P%)
#   Time in momentum       :     X.XXX ( PP.P%)
#   Time in continuity     :     X.XXX ( PP.P%)
#   Time in SnapWave       :     X.XXX ( PP.P%)
#   Time in meteo forcing  :     X.XXX ( PP.P%)
#   Time in output         :     X.XXX ( PP.P%)
#   Average time step (s)  :     X.XXX
# Per Phase-5 source review (sfincs_lib.F90:945 dtavg = dtavg/(nt-1)),
# step_count = round( (tstop-tstart)/dtavg ) + 1, a one-step rounding
# error at worst.
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

    # Sum the named components — missing components are zero.
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

# Sim-seconds for each length label, used to derive step_count.
sim_seconds_for() {
    case "$1" in
        1h)  echo 3600    ;;
        6h)  echo 21600   ;;
        24h) echo 86400   ;;
        4d)  echo 345600  ;;
        *) echo "0" ;;
    esac
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
        # Serial — Automake does not encode Fortran .mod dependencies,
        # so -j parallelizes across modules and races on .mod files.
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

ensure_builds() {
    if [ "$SKIP_BUILD" -ne 1 ] || [ ! -x "$CPU_BIN" ]; then
        build_cpu
    fi
    if [ "$SKIP_BUILD" -ne 1 ] || [ ! -x "$GPU_BIN_HOST" ]; then
        build_gpu
    fi
    [ -x "$CPU_BIN" ] || { echo "ERROR: $CPU_BIN not built" >&2; exit 3; }
    [ -x "$GPU_BIN_HOST" ] || { echo "ERROR: $GPU_BIN_HOST not built" >&2; exit 3; }
}

# --- Run steps --------------------------------------------------------------

run_cpu_cell() {
    local case_name=$1 case_dir=$2 length=$3 grid=$4
    local run_dir=$OUT_DIR/${case_name}__${grid}__${length}__cpu_n${NPROC}
    stage_case "$case_dir" "$run_dir"
    if [ "$grid" = "4x" ]; then refine_regular_tide_4x "$run_dir"; fi
    rewrite_tstop "$run_dir" "$(tstop_for "$length")"
    echo "--- [cpu_n$NPROC] $case_name $grid $length ---"
    local wall_start wall_end rc
    wall_start=$(date +%s)
    set +e
    (
        cd "$run_dir"
        OMP_NUM_THREADS=$NPROC OMP_DYNAMIC=false OMP_PROC_BIND=true \
            "$CPU_BIN" >sfincs.log 2>sfincs.stdout
    )
    rc=$?
    set -e
    wall_end=$(date +%s)
    echo "    rc=$rc wall=$((wall_end - wall_start))s log=$run_dir/sfincs.log"
    extract_timings "$run_dir/sfincs.log" "$run_dir/timings.txt" "$(sim_seconds_for "$length")"
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
    # sfincs.log is written into the run_dir by SFINCS; if absent
    # (mpirun ran outside the workdir somehow) the timings.txt will
    # show empty fields and SUMMARY will treat the cell as missing.
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
            # --drop-4d-cpu skips the cpu_n128 cell at 4d only.
            # Rationale: 4d cpu_n128 cells dominate wall time (regular_tide
            # alone is ~30 min); GPU 4d cells are <60s so they stay.
            if [ "$DROP_4D_CPU" -eq 1 ] && [ "$length" = "4d" ]; then
                echo "--- [skip cpu_n$NPROC] $case_name $grid 4d (per --drop-4d-cpu) ---"
            else
                run_cpu_cell "$case_name" "$case_dir" "$length" "$grid"
            fi
            run_gpu_cell "$case_name" "$case_dir" "$length" "$grid" 1
            run_gpu_cell "$case_name" "$case_dir" "$length" "$grid" 2
        done
    done
done

echo
echo "=== SOR-1020 post-SOR-1019 scaling sweep — complete $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
