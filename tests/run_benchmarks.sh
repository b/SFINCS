#!/bin/sh
# CPU vs GPU-IEEE-strict vs GPU-fast-math benchmark harness for SFINCS.
#
# Builds three configurations into separate prefixes:
#   * cpu          — gfortran CPU baseline, all OpenMP cores by default
#                    (override with BENCH_CPU_THREADS=N for repeatable
#                    cross-host numbers; that path also pins threads via
#                    OMP_PROC_BIND=close)
#   * gpu_kieee    — nvfortran CUDA, default -Kieee (matches CPU FP)
#   * gpu_fastmath — nvfortran CUDA, --enable-fast-math (drops -Kieee)
#
# Runs every test case under tests/cases/ once per build (one run per
# (case, build) pair) under tests/runs_bench/<case>/<config>/, captures
# wall time + peak resident memory via /usr/bin/time -v, and diffs each
# GPU run's zsmax against the CPU baseline. Prints a summary table on
# stdout and writes a machine-readable tests/runs_bench/summary.json.
#
# Each GPU configuration is run twice; only the second timing is recorded
# so first-run JIT / driver init / page-cache costs do not pollute the
# steady-state measurement. GPU runs are pinned to GPU 0 via
# CUDA_VISIBLE_DEVICES=0.
#
# Exit code: 0 iff every (case, build) run completed without error AND
# every GPU run's max(|gpu - cpu|) / max(cpu) < 1e-3 (loose threshold;
# the validation harness gates on the strict 1e-4). Otherwise 1.
#
# Dev-only — not invoked from CI. Numbers are dev-box-specific and not
# comparable across machines or across SFINCS versions.
#
# Run from the repo root:
#
#     tests/run_benchmarks.sh                  # full build + fetch + run
#     tests/run_benchmarks.sh --skip-build     # reuse existing binaries
#     tests/run_benchmarks.sh --skip-fetch     # skip per-case ./fetch.sh

set -e

# --- Repository layout ------------------------------------------------------

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
TESTS_DIR=$REPO_ROOT/tests
CASES_DIR=$TESTS_DIR/cases
RUNS_DIR=$TESTS_DIR/runs_bench
DIFF_TOOL=$TESTS_DIR/scripts/diff_zsmax.py
GPU_WRAPPER=$REPO_ROOT/source/build_scripts/run_gpu_container.sh
CPU_BIN=$REPO_ROOT/source/install_cpu/bin/sfincs
GPU_BIN_KIEEE=$REPO_ROOT/source/install_cuda_kieee/bin/sfincs
GPU_BIN_FASTMATH=$REPO_ROOT/source/install_cuda_fastmath/bin/sfincs
GPU_BIN_KIEEE_CONTAINER=/work/source/install_cuda_kieee/bin/sfincs
GPU_BIN_FASTMATH_CONTAINER=/work/source/install_cuda_fastmath/bin/sfincs
THRESHOLD=1e-3

TAB=$(printf '\t')

# --- Argument parsing -------------------------------------------------------

SKIP_BUILD=0
SKIP_FETCH=0
for arg in "$@"; do
    case "$arg" in
        --skip-build) SKIP_BUILD=1 ;;
        --skip-fetch) SKIP_FETCH=1 ;;
        -h|--help)
            sed -n '2,36p' "$0"
            exit 0
            ;;
        *)
            echo "unknown argument: $arg" >&2
            exit 2
            ;;
    esac
done

# CPU baseline thread count. Default = all cores via nproc so the
# `speedup_vs_cpu` numbers reflect the comparison an operator expects
# ("1 GPU vs the CPU's full throughput"). BENCH_CPU_THREADS=N pins to a
# specific count for cross-host reproducibility and additionally exports
# OMP_PROC_BIND=close for thread-pinning stability.
if [ -n "${BENCH_CPU_THREADS:-}" ]; then
    CPU_THREADS=$BENCH_CPU_THREADS
    CPU_OMP_PROC_BIND=close
else
    CPU_THREADS=$(nproc)
    CPU_OMP_PROC_BIND=
fi

# --- Helpers ----------------------------------------------------------------

# Map an absolute host path under REPO_ROOT to its container path under /work.
host_to_container() {
    host_path=$1
    case "$host_path" in
        "$REPO_ROOT") echo "/work" ;;
        "$REPO_ROOT"/*) echo "/work${host_path#"$REPO_ROOT"}" ;;
        *)
            echo "host_to_container: '$host_path' is outside REPO_ROOT '$REPO_ROOT'" >&2
            return 1
            ;;
    esac
}

# Stage case inputs into a clean run directory. sfincs.inp is copied (so
# it can be edited per-run if a tstop override is needed); other files
# are symlinked. README.md and fetch.sh are skipped — same skip list as
# tests/run_validation.sh.
populate_run_dir() {
    case_dir=$1
    run_dir=$2
    mkdir -p "$run_dir"
    find "$run_dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
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

# Parse `Elapsed (wall clock) time` from /usr/bin/time -v output to
# seconds. The value field is one of: h:mm:ss, m:ss.fraction.
parse_wall_seconds() {
    [ -f "$1" ] || { echo null; return; }
    val=$(awk '
        /Elapsed \(wall clock\) time/ {
            t = $NF
            n = split(t, parts, ":")
            if (n == 3) { printf "%.3f\n", parts[1] * 3600 + parts[2] * 60 + parts[3]; exit }
            else if (n == 2) { printf "%.3f\n", parts[1] * 60 + parts[2]; exit }
        }
    ' "$1")
    [ -n "$val" ] && printf '%s\n' "$val" || echo null
}

# Parse `Maximum resident set size (kbytes)` from /usr/bin/time -v
# output to MB. NOTE: for GPU runs this captures the host-side docker
# client process, not the in-container sfincs RSS — useful as a coarse
# overhead indicator only. Use nvidia-smi for actual GPU memory.
parse_peak_mem_mb() {
    [ -f "$1" ] || { echo null; return; }
    val=$(awk '
        /Maximum resident set size \(kbytes\)/ {
            printf "%.2f\n", $NF / 1024.0
            exit
        }
    ' "$1")
    [ -n "$val" ] && printf '%s\n' "$val" || echo null
}

# Assert the container's mpirun resolves to the CUDA-aware HPC-X build.
# Mirrors tests/run_validation.sh's check; see that file for the
# rationale and the HPC-X-specific output-shape note. Default container
# PATH selects a non-CUDA-aware mpirun that silently stages every
# device-pointer Isend through pinned host memory, saturating one CPU
# thread and stalling the GPU.
assert_cuda_aware_mpi() {
    set +e
    out=$("$GPU_WRAPPER" sh -c \
        "ompi_info --param mpi all --level 9 | grep -E 'opal_built_with_cuda_support|opal_cuda_support'" \
        2>&1)
    rc=$?
    set -e
    if [ "$rc" -ne 0 ]; then
        echo "CUDA-aware MPI not detected — check container PATH" >&2
        echo "ompi_info invocation failed with rc=$rc; output follows:" >&2
        printf '%s\n' "$out" >&2
        exit 1
    fi
    built_ok=$(printf '%s\n' "$out" \
        | awk '/opal_built_with_cuda_support/ && /current value: "true"/ {n++} END {print n+0}')
    cuda_ok=$(printf '%s\n' "$out" \
        | awk '/opal_cuda_support/ && /current value: "true"/ {n++} END {print n+0}')
    if [ "$built_ok" -lt 1 ] || [ "$cuda_ok" -lt 1 ]; then
        echo "CUDA-aware MPI not detected — check container PATH" >&2
        echo "expected opal_built_with_cuda_support=true and opal_cuda_support=true; got:" >&2
        printf '%s\n' "$out" >&2
        exit 1
    fi
    echo "    CUDA-aware MPI: opal_built_with_cuda_support=true, opal_cuda_support=true"
}

# Inspect a completed run; return 0 if it produced a usable sfincs_map.nc
# with no `error = 1` STOP, otherwise return 1.
check_run() {
    run_dir=$1
    [ -f "$run_dir/sfincs.log" ] || return 1
    grep -q "error = 1" "$run_dir/sfincs.log" && return 1
    [ -f "$run_dir/sfincs_map.nc" ] || return 1
    return 0
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

build_gpu_kieee() {
    echo "=== Building GPU IEEE-strict (-Kieee) ==="
    wipe_build_artifacts
    SFINCS_PREFIX=/work/source/install_cuda_kieee \
        "$GPU_WRAPPER" source/build_scripts/build_cuda.sh
}

build_gpu_fastmath() {
    echo "=== Building GPU fast-math (--enable-fast-math) ==="
    wipe_build_artifacts
    SFINCS_PREFIX=/work/source/install_cuda_fastmath \
        "$GPU_WRAPPER" source/build_scripts/build_cuda.sh --enable-fast-math
}

# --- Run steps --------------------------------------------------------------

# Run the CPU binary in tests/runs_bench/<case>/cpu/ at the harness-wide
# CPU_THREADS count (all cores by default; BENCH_CPU_THREADS overrides).
# Diverges from tests/run_validation.sh on purpose: validation pins to a
# single thread for FP determinism, benchmarking measures throughput.
run_cpu() {
    case_name=$1
    case_dir=$2
    run_dir=$RUNS_DIR/$case_name/cpu
    populate_run_dir "$case_dir" "$run_dir"
    echo "--- Running CPU ($CPU_THREADS threads): $case_name ---"
    rc=0
    (
        cd "$run_dir"
        export OMP_NUM_THREADS=$CPU_THREADS
        if [ -n "$CPU_OMP_PROC_BIND" ]; then
            export OMP_PROC_BIND=$CPU_OMP_PROC_BIND
        fi
        /usr/bin/time -v -o time.txt "$CPU_BIN" >sfincs.log 2>&1
    ) || rc=$?
    echo "    cpu exit=$rc log=$run_dir/sfincs.log"
}

# Run a GPU binary in tests/runs_bench/<case>/<config>/. Runs twice; the
# first run pays JIT / page-cache costs that are not representative of
# steady-state. The directory is re-populated between runs so the timed
# invocation always reads fresh inputs.
run_gpu() {
    case_name=$1
    case_dir=$2
    config=$3
    bin_container=$4
    run_dir=$RUNS_DIR/$case_name/$config
    container_run_dir=$(host_to_container "$run_dir")

    populate_run_dir "$case_dir" "$run_dir"
    echo "--- Warmup GPU $config: $case_name ---"
    set +e
    (
        cd "$run_dir"
        "$GPU_WRAPPER" \
            mpirun --allow-run-as-root --wdir "$container_run_dir" \
                -x CUDA_VISIBLE_DEVICES=0 \
                -n 1 "$bin_container" \
            >sfincs_warmup.log 2>&1
    )
    set -e

    populate_run_dir "$case_dir" "$run_dir"
    echo "--- Timed GPU $config: $case_name ---"
    rc=0
    (
        cd "$run_dir"
        /usr/bin/time -v -o time.txt \
            "$GPU_WRAPPER" \
                mpirun --allow-run-as-root --wdir "$container_run_dir" \
                    -x CUDA_VISIBLE_DEVICES=0 \
                    -n 1 "$bin_container" \
            >sfincs.log 2>&1
    ) || rc=$?
    echo "    $config exit=$rc log=$run_dir/sfincs.log"
}

# Diff a GPU run against the CPU baseline. Echoes the diff tool's stdout
# and sets diff_rc / max_abs_diff / max_zsmax_ref / ratio in the caller's
# scope (POSIX sh has no return values; we use globals).
run_diff() {
    ref=$1
    cand=$2
    diff_rc=0
    max_abs_diff=null
    max_zsmax_ref=null
    ratio=null
    set +e
    diff_out=$(python3 "$DIFF_TOOL" \
        --reference "$ref" \
        --candidate "$cand" \
        --threshold "$THRESHOLD" 2>&1)
    diff_rc=$?
    set -e
    printf '%s\n' "$diff_out"
    result_line=$(printf '%s\n' "$diff_out" | grep '^RESULT ' | tail -n1)
    if [ -n "$result_line" ]; then
        max_abs_diff=$(printf '%s\n' "$result_line" | sed -n 's/.*max_abs_diff=\([^ ]*\).*/\1/p')
        max_zsmax_ref=$(printf '%s\n' "$result_line" | sed -n 's/.*max_zsmax_ref=\([^ ]*\).*/\1/p')
        ratio=$(printf '%s\n' "$result_line" | sed -n 's/.*ratio=\([^ ]*\).*/\1/p')
    fi
}

# --- Build phase ------------------------------------------------------------

if [ "$SKIP_BUILD" -ne 1 ]; then
    build_cpu
    build_gpu_kieee
    build_gpu_fastmath
else
    echo "=== Skipping build (--skip-build) ==="
fi

for binpath in "$CPU_BIN" "$GPU_BIN_KIEEE" "$GPU_BIN_FASTMATH"; do
    if [ ! -x "$binpath" ]; then
        echo "missing required binary: $binpath" >&2
        exit 1
    fi
done

echo "=== Verifying CUDA-aware MPI ==="
assert_cuda_aware_mpi

# --- Discover cases ---------------------------------------------------------

CASES_FILE=$(mktemp)
trap 'rm -f "$CASES_FILE"' EXIT
for d in "$CASES_DIR"/*/; do
    [ -d "$d" ] || continue
    basename "${d%/}"
done >"$CASES_FILE"

if [ ! -s "$CASES_FILE" ]; then
    echo "no cases found in $CASES_DIR" >&2
    exit 2
fi

mkdir -p "$RUNS_DIR"

# Per-row TSV staging file (consumed by the summary phase).
ROWS=$RUNS_DIR/.rows.tsv
: >"$ROWS"

# --- Run phase --------------------------------------------------------------

while IFS= read -r case_name; do
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
        echo "    no sfincs.inp in $case_dir — marking all configs ERROR"
        for cfg in cpu gpu_kieee gpu_fastmath; do
            if [ "$cfg" = cpu ]; then row_threads=$CPU_THREADS; else row_threads=null; fi
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$case_name" "$cfg" "null" "null" "null" "null" "null" "ERROR" "null" "$row_threads" \
                >>"$ROWS"
        done
        continue
    fi

    # CPU baseline first — its wall-time is needed to compute speedups.
    run_cpu "$case_name" "$case_dir"
    cpu_run_dir=$RUNS_DIR/$case_name/cpu
    cpu_wall=null
    cpu_peak=null
    cpu_verdict=ERROR
    if check_run "$cpu_run_dir"; then
        cpu_wall=$(parse_wall_seconds "$cpu_run_dir/time.txt")
        cpu_peak=$(parse_peak_mem_mb "$cpu_run_dir/time.txt")
        cpu_verdict=PASS
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$case_name" "cpu" "$cpu_wall" "$cpu_peak" "null" "null" "null" "$cpu_verdict" "null" "$CPU_THREADS" \
        >>"$ROWS"

    for cfg in gpu_kieee gpu_fastmath; do
        case "$cfg" in
            gpu_kieee) bin=$GPU_BIN_KIEEE_CONTAINER ;;
            gpu_fastmath) bin=$GPU_BIN_FASTMATH_CONTAINER ;;
        esac
        run_gpu "$case_name" "$case_dir" "$cfg" "$bin"
        gpu_run_dir=$RUNS_DIR/$case_name/$cfg
        gpu_wall=null
        gpu_peak=null
        max_abs_diff=null
        max_zsmax_ref=null
        ratio=null
        speedup=null
        verdict=ERROR

        if check_run "$gpu_run_dir"; then
            gpu_wall=$(parse_wall_seconds "$gpu_run_dir/time.txt")
            gpu_peak=$(parse_peak_mem_mb "$gpu_run_dir/time.txt")
            if [ "$cpu_verdict" = PASS ]; then
                run_diff "$cpu_run_dir/sfincs_map.nc" "$gpu_run_dir/sfincs_map.nc"
                case "$diff_rc" in
                    0) verdict=PASS ;;
                    1) verdict=FAIL ;;
                    *) verdict=ERROR ;;
                esac
                if [ "$cpu_wall" != null ] && [ "$gpu_wall" != null ]; then
                    speedup=$(awk -v c="$cpu_wall" -v g="$gpu_wall" \
                        'BEGIN { if (g > 0) printf "%.3f\n", c/g; else print "null" }')
                fi
            fi
        fi
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$case_name" "$cfg" "$gpu_wall" "$gpu_peak" "$max_abs_diff" "$max_zsmax_ref" "$ratio" "$verdict" "$speedup" "null" \
            >>"$ROWS"
    done
done <"$CASES_FILE"

# --- Summary phase ----------------------------------------------------------

echo
echo "=== Benchmark summary ==="

overall=0
# r_max_abs / r_max_zs are emitted into summary.json but not into the
# stdout BENCH-SUMMARY line — same row, two consumers, different columns.
while IFS="$TAB" read -r r_case r_config r_wall r_peak r_max_abs r_max_zs r_ratio r_verdict r_speedup r_threads; do
    : "$r_peak" "$r_max_abs" "$r_max_zs"
    printf 'BENCH-SUMMARY case=%s config=%s wall=%s speedup=%s ratio=%s verdict=%s cpu_threads=%s\n' \
        "$r_case" "$r_config" "$r_wall" "$r_speedup" "$r_ratio" "$r_verdict" "$r_threads"
    if [ "$r_verdict" != PASS ]; then
        overall=1
    fi
done <"$ROWS"

echo
printf '%-32s %-14s %-12s %-12s %-12s %-10s %-10s %s\n' \
    "case" "config" "wall_sec" "peak_mb" "ratio" "speedup" "threads" "verdict"
printf '%-32s %-14s %-12s %-12s %-12s %-10s %-10s %s\n' \
    "----" "------" "--------" "-------" "-----" "-------" "-------" "-------"
while IFS="$TAB" read -r r_case r_config r_wall r_peak r_max_abs r_max_zs r_ratio r_verdict r_speedup r_threads; do
    : "$r_max_abs" "$r_max_zs"
    printf '%-32s %-14s %-12s %-12s %-12s %-10s %-10s %s\n' \
        "$r_case" "$r_config" "$r_wall" "$r_peak" "$r_ratio" "$r_speedup" "$r_threads" "$r_verdict"
done <"$ROWS"

# Build summary.json from the TSV.
python3 - "$ROWS" "$RUNS_DIR/summary.json" <<'PY'
import json
import math
import sys

rows_path, json_path = sys.argv[1], sys.argv[2]
keys = [
    "case", "config", "wall_clock_seconds", "peak_memory_mb",
    "max_abs_diff_zsmax", "max_zsmax_ref", "ratio_vs_ref", "verdict",
    "speedup_vs_cpu", "cpu_threads",
]
numeric = {
    "wall_clock_seconds", "peak_memory_mb", "max_abs_diff_zsmax",
    "max_zsmax_ref", "ratio_vs_ref", "speedup_vs_cpu",
}
integer = {"cpu_threads"}


def parse_value(key, raw):
    if raw == "null" or raw == "":
        return None
    if key in integer:
        try:
            return int(raw)
        except ValueError:
            return None
    if key in numeric:
        try:
            v = float(raw)
        except ValueError:
            return None
        return None if math.isnan(v) else v
    return raw


rows = []
with open(rows_path) as f:
    for line in f:
        line = line.rstrip("\n")
        if not line:
            continue
        parts = line.split("\t")
        rows.append({k: parse_value(k, v) for k, v in zip(keys, parts)})

with open(json_path, "w") as f:
    json.dump({"rows": rows}, f, indent=2)
    f.write("\n")
PY

echo
echo "Wrote $RUNS_DIR/summary.json"
if [ "$overall" -eq 0 ]; then
    echo "OVERALL: PASS"
    exit 0
else
    echo "OVERALL: FAIL"
    exit 1
fi
