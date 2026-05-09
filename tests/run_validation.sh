#!/bin/bash
# CPU-vs-GPU validation harness for SFINCS.
#
# Builds the CPU and GPU binaries, runs each test case under tests/cases/
# in three configurations (CPU baseline, GPU mpirun -n 1, GPU mpirun -n 2),
# diffs the GPU runs' zsmax against the CPU baseline using
# tests/scripts/diff_zsmax.py, and prints a PASS/FAIL summary across every
# (case, gpu_run) pair.
#
# Exit code: 0 iff every pair is PASS, otherwise 1.
#
# Dev-only — not invoked from CI. Run from the repo root:
#
#     tests/run_validation.sh                  # full build + fetch + run
#     tests/run_validation.sh --skip-build     # reuse existing binaries
#     tests/run_validation.sh --skip-fetch     # skip per-case ./fetch.sh

set -euo pipefail

# --- Repository layout ------------------------------------------------------

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
TESTS_DIR=$REPO_ROOT/tests
CASES_DIR=$TESTS_DIR/cases
RUNS_DIR=$TESTS_DIR/runs
DIFF_TOOL=$TESTS_DIR/scripts/diff_zsmax.py
CPU_BIN=$REPO_ROOT/source/install_cpu/bin/sfincs
GPU_BIN_CONTAINER=/work/source/install_cuda/bin/sfincs
GPU_WRAPPER=$REPO_ROOT/source/build_scripts/run_gpu_container.sh
THRESHOLD=1e-4

# --- Argument parsing -------------------------------------------------------

SKIP_BUILD=0
SKIP_FETCH=0
for arg in "$@"; do
    case "$arg" in
        --skip-build) SKIP_BUILD=1 ;;
        --skip-fetch) SKIP_FETCH=1 ;;
        -h|--help)
            sed -n '2,17p' "$0"
            exit 0
            ;;
        *)
            echo "unknown argument: $arg" >&2
            exit 2
            ;;
    esac
done

# --- Helpers ----------------------------------------------------------------

# Map an absolute host path under REPO_ROOT to its container path under /work.
host_to_container() {
    local host_path=$1
    case "$host_path" in
        "$REPO_ROOT") echo "/work" ;;
        "$REPO_ROOT"/*) echo "/work${host_path#"$REPO_ROOT"}" ;;
        *)
            echo "host_to_container: '$host_path' is outside REPO_ROOT '$REPO_ROOT'" >&2
            return 1
            ;;
    esac
}

# Stage case inputs into a clean run directory. sfincs.inp is copied (so it
# can be edited per-run if a tstop override is needed); other files are
# symlinked to keep tests/runs/ small. README.md and fetch.sh are skipped.
populate_run_dir() {
    local case_dir=$1 run_dir=$2
    mkdir -p "$run_dir"
    find "$run_dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    local entry base
    for entry in "$case_dir"/*; do
        [ -e "$entry" ] || continue
        base=$(basename "$entry")
        case "$base" in
            README.md|fetch.sh) ;;
            sfincs.inp) cp -- "$entry" "$run_dir/$base" ;;
            *) ln -srf -- "$entry" "$run_dir/$base" ;;
        esac
    done
}

# --- Build steps ------------------------------------------------------------

# Wipe Fortran build artifacts under source/src and source/third_party_open
# so the next ./configure+make starts from a known-clean state. Necessary
# because (a) automake's `make clean` does not remove Fortran .mod files
# (Makefile.am does not list them in CLEANFILES) and (b) gfortran and
# nvfortran .mod formats are mutually unreadable, so a stale .mod from one
# compiler aborts the next build with "Corrupt or Old Module file". The
# install_* prefixes are deliberately preserved so --skip-build can reuse
# binaries from a prior successful run.
wipe_build_artifacts() {
    for sub in src third_party_open; do
        find "$REPO_ROOT/source/$sub" -type f \
            \( -name '*.mod' -o -name '*.o' -o -name '*.lo' \
               -o -name '*.a' -o -name '*.la' \) -delete
    done
}

build_cpu() {
    echo "=== Building CPU (gfortran, single-threaded) ==="
    wipe_build_artifacts
    (
        cd "$REPO_ROOT/source"
        autoreconf -ivf
        ./autogen.sh
        ./configure FC=gfortran \
            FCFLAGS="-fopenmp -O3 -fallow-argument-mismatch -w" \
            --disable-shared \
            --prefix="$PWD/install_cpu"
        make
        make install
    )
}

build_gpu() {
    echo "=== Building GPU (nvfortran in dev container, single-threaded) ==="
    wipe_build_artifacts
    "$GPU_WRAPPER" source/build_scripts/build_cuda.sh
}

# --- Run steps --------------------------------------------------------------

# Run the CPU binary in tests/runs/<case>/cpu/.
# OMP_NUM_THREADS=1 forces deterministic CPU output (validation cares about
# correctness, not threading-induced FP nondeterminism).
run_cpu() {
    local case_name=$1 case_dir=$2
    local run_dir=$RUNS_DIR/$case_name/cpu
    populate_run_dir "$case_dir" "$run_dir"
    echo "--- Running CPU: $case_name ---"
    set +e
    (
        cd "$run_dir"
        OMP_NUM_THREADS=1 "$CPU_BIN" >sfincs.log 2>&1
    )
    local rc=$?
    set -e
    echo "    cpu exit=$rc log=$run_dir/sfincs.log"
}

# Run the GPU binary at $nranks ranks in tests/runs/<case>/gpu_n<nranks>/.
# The wrapper sets container cwd to /work; we pass --wdir to mpirun so the
# sfincs processes start in the run directory and read sfincs.inp from there.
run_gpu() {
    local case_name=$1 case_dir=$2 nranks=$3
    local cfg=gpu_n$nranks
    local run_dir=$RUNS_DIR/$case_name/$cfg
    populate_run_dir "$case_dir" "$run_dir"
    local container_run_dir
    container_run_dir=$(host_to_container "$run_dir")
    echo "--- Running GPU n=$nranks: $case_name ---"
    set +e
    (
        cd "$run_dir"
        "$GPU_WRAPPER" \
            mpirun --allow-run-as-root --wdir "$container_run_dir" \
            -n "$nranks" "$GPU_BIN_CONTAINER" \
            >sfincs.log 2>&1
    )
    local rc=$?
    set -e
    echo "    $cfg exit=$rc log=$run_dir/sfincs.log"
}

# Inspect a completed run; return 0 if it produced a usable sfincs_map.nc
# with no `error = 1` STOP, otherwise record FAIL and return 1.
check_run() {
    local case_name=$1 cfg=$2
    local run_dir=$RUNS_DIR/$case_name/$cfg
    if [ ! -f "$run_dir/sfincs.log" ]; then
        echo "    $cfg FAIL: no sfincs.log"
        verdicts["$case_name:$cfg"]=FAIL
        return 1
    fi
    if grep -q "error = 1" "$run_dir/sfincs.log"; then
        echo "    $cfg FAIL: 'error = 1' in sfincs.log"
        verdicts["$case_name:$cfg"]=FAIL
        return 1
    fi
    if [ ! -f "$run_dir/sfincs_map.nc" ]; then
        echo "    $cfg FAIL: sfincs_map.nc not produced"
        verdicts["$case_name:$cfg"]=FAIL
        return 1
    fi
    return 0
}

# Diff a (case, gpu_run) pair against the CPU baseline. The diff tool prints
# its own RESULT line and exits 0=PASS / 1=FAIL / 2=ERROR.
run_diff() {
    local case_name=$1 cfg=$2
    local ref=$RUNS_DIR/$case_name/cpu/sfincs_map.nc
    local cand=$RUNS_DIR/$case_name/$cfg/sfincs_map.nc
    set +e
    python3 "$DIFF_TOOL" \
        --reference "$ref" \
        --candidate "$cand" \
        --threshold "$THRESHOLD"
    local rc=$?
    set -e
    case "$rc" in
        0) verdicts["$case_name:$cfg"]=PASS ;;
        1) verdicts["$case_name:$cfg"]=FAIL ;;
        *) verdicts["$case_name:$cfg"]=ERROR ;;
    esac
}

# --- Main -------------------------------------------------------------------

if [ "$SKIP_BUILD" -ne 1 ]; then
    build_cpu
    build_gpu
else
    echo "=== Skipping build (--skip-build) ==="
fi

CASES=()
for d in "$CASES_DIR"/*/; do
    [ -d "$d" ] || continue
    CASES+=("$(basename "${d%/}")")
done
if [ ${#CASES[@]} -eq 0 ]; then
    echo "no cases found in $CASES_DIR" >&2
    exit 2
fi

mkdir -p "$RUNS_DIR"
declare -A verdicts

for case_name in "${CASES[@]}"; do
    case_dir=$CASES_DIR/$case_name
    echo
    echo "=== Case: $case_name ==="

    if [ "$SKIP_FETCH" -ne 1 ] \
        && [ -x "$case_dir/fetch.sh" ] \
        && [ ! -f "$case_dir/sfincs.inp" ]; then
        echo "--- Fetching: $case_name ---"
        ( cd "$case_dir" && ./fetch.sh )
    fi

    if [ ! -f "$case_dir/sfincs.inp" ]; then
        echo "    no sfincs.inp in $case_dir — marking gpu_n1 and gpu_n2 FAIL"
        verdicts["$case_name:gpu_n1"]=FAIL
        verdicts["$case_name:gpu_n2"]=FAIL
        continue
    fi

    run_cpu "$case_name" "$case_dir"
    cpu_ok=0
    if [ -f "$RUNS_DIR/$case_name/cpu/sfincs_map.nc" ] \
        && ! grep -q "error = 1" "$RUNS_DIR/$case_name/cpu/sfincs.log"; then
        cpu_ok=1
    else
        echo "    cpu baseline unusable — gpu_n1/gpu_n2 will be marked FAIL"
    fi

    for n in 1 2; do
        cfg=gpu_n$n
        run_gpu "$case_name" "$case_dir" "$n"
        if ! check_run "$case_name" "$cfg"; then
            continue
        fi
        if [ "$cpu_ok" -ne 1 ]; then
            verdicts["$case_name:$cfg"]=FAIL
            continue
        fi
        run_diff "$case_name" "$cfg"
    done
done

echo
echo "=== Validation summary ==="
printf '%-32s %-8s %s\n' "case" "config" "verdict"
printf '%-32s %-8s %s\n' "----" "------" "-------"
overall=0
for case_name in "${CASES[@]}"; do
    for cfg in gpu_n1 gpu_n2; do
        v=${verdicts["$case_name:$cfg"]:-FAIL}
        printf '%-32s %-8s %s\n' "$case_name" "$cfg" "$v"
        if [ "$v" != PASS ]; then
            overall=1
        fi
    done
done

if [ "$overall" -eq 0 ]; then
    echo
    echo "OVERALL: PASS"
    exit 0
else
    echo
    echo "OVERALL: FAIL"
    exit 1
fi
