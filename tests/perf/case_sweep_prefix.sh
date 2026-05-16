#!/bin/bash
# SOR-52: pre-fix vs post-fix bit-equivalence sweep across the full
# tests/cases/ corpus at gpu_n2.
#
# tests/run_validation.sh exercises every test case at gpu_n1 and gpu_n2
# through the run_gpu_container.sh wrapper, which sets the HPC-X 2.24
# PATH (the post-fix variant). After tests/run_validation.sh completes
# the gpu_n2 outputs are in tests/runs/<case>/gpu_n2/sfincs_map.nc.
#
# This script re-runs every case at gpu_n2 under the pre-fix MPI
# variant (default-PATH mpirun at comm_libs/mpi/bin/mpirun +
# --mca opal_cuda_support 0) and diffs each pre-fix sfincs_map.nc
# against the corresponding post-fix sfincs_map.nc. The expected
# result for every case is max_abs_diff = 0.0 (bit-exact): the
# SFINCS GPU binary's DT_RUNPATH pins libmpi.so.40 to HPC-X
# regardless of which mpirun binary launches it, so the two
# variants execute the same MPI library in the same configuration
# (the --mca toggle only disables OPAL-layer detection, which UCX
# doesn't honour for its own cuda transports).
#
# Output:
#   * tests/runs/<case>/gpu_n2_prefix/  — pre-fix run dir per case
#   * tests/perf/case_sweep_prefix.log  — per-case diff table
#
# Run from the repo root AFTER tests/run_validation.sh has produced
# tests/runs/<case>/gpu_n2/sfincs_map.nc:
#
#     tests/perf/case_sweep_prefix.sh

set -uo pipefail   # not -e so a single case can fail without aborting the sweep

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
IMAGE=${SFINCS_GPU_IMAGE:-sfincs-build-gpu:latest}
CASES_DIR=$REPO_ROOT/tests/cases
RUNS_DIR=$REPO_ROOT/tests/runs
DIFF_TOOL=$REPO_ROOT/tests/scripts/diff_zsmax.py
GPU_BIN=/work/source/install_cuda/bin/sfincs
NRANKS=2
LOG=$REPO_ROOT/tests/perf/case_sweep_prefix.log

# Pre-fix MPI variant configuration (matches tests/perf/run_perf.sh pre-fix).
DEFAULT_MPI=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/comm_libs/mpi
NVHPC_COMPILERS=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/compilers
NVHPC_MATH=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/math_libs
NVHPC_CUDA=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/cuda
PREFIX_PATH="$DEFAULT_MPI/bin:$NVHPC_COMPILERS/bin:$NVHPC_CUDA/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
PREFIX_LDPATH="$DEFAULT_MPI/lib:$NVHPC_COMPILERS/lib:$NVHPC_MATH/lib64:$NVHPC_CUDA/lib64"
PREFIX_OPAL_PREFIX=$DEFAULT_MPI
PREFIX_MCA=("--mca" "opal_cuda_support" "0" "--mca" "mpi_cuda_support" "0")

: > "$LOG"
{
    echo "SOR-52 pre-fix vs post-fix case-sweep at gpu_n2"
    echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo
    printf '%-36s %-10s %-10s %-26s %s\n' \
        "case" "pre-fix" "post-fix" "pre-vs-post max_abs_diff" "verdict"
    printf '%-36s %-10s %-10s %-26s %s\n' \
        "----" "-------" "--------" "-------------------------" "-------"
} | tee -a "$LOG"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

for case_dir in "$CASES_DIR"/*/; do
    case_name=$(basename "${case_dir%/}")

    if [ ! -f "$case_dir/sfincs.inp" ]; then
        printf '%-36s %-10s %-10s %-26s %s\n' \
            "$case_name" "-" "-" "-" "SKIP (no sfincs.inp)" | tee -a "$LOG"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
    fi

    postfix_map=$RUNS_DIR/$case_name/gpu_n2/sfincs_map.nc
    if [ ! -f "$postfix_map" ]; then
        printf '%-36s %-10s %-10s %-26s %s\n' \
            "$case_name" "-" "MISSING" "-" "SKIP (no post-fix map)" | tee -a "$LOG"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
    fi

    run_dir=$RUNS_DIR/$case_name/gpu_n2_prefix
    rm -rf "$run_dir"
    mkdir -p "$run_dir"
    for entry in "$case_dir"/*; do
        [ -e "$entry" ] || continue
        base=$(basename "$entry")
        case "$base" in
            README.md|fetch.sh) ;;
            sfincs.inp) cp -- "$entry" "$run_dir/$base" ;;
            *) ln -srf -- "$entry" "$run_dir/$base" ;;
        esac
    done

    container_run_dir="/work${run_dir#$REPO_ROOT}"
    container_name="sfincs-sweep-prefix-${case_name}-$$"

    docker run --rm --init \
        --name "$container_name" \
        --gpus all --ipc=host \
        --user "$(id -u):$(id -g)" \
        -e HOME=/tmp \
        -e OPAL_PREFIX="$PREFIX_OPAL_PREFIX" \
        -e PATH="$PREFIX_PATH" \
        -e LD_LIBRARY_PATH="$PREFIX_LDPATH" \
        -v "$REPO_ROOT":/work \
        -w "$container_run_dir" \
        "$IMAGE" \
        "$DEFAULT_MPI/bin/mpirun" --allow-run-as-root "${PREFIX_MCA[@]}" \
        -n "$NRANKS" "$GPU_BIN" \
        > "$run_dir/sfincs.stdout" 2>&1
    prefix_rc=$?

    if [ "$prefix_rc" -ne 0 ]; then
        printf '%-36s %-10s %-10s %-26s %s\n' \
            "$case_name" "rc=$prefix_rc" "PASS" "-" "FAIL (pre-fix run)" \
            | tee -a "$LOG"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi

    prefix_map=$run_dir/sfincs_map.nc
    if [ ! -f "$prefix_map" ]; then
        printf '%-36s %-10s %-10s %-26s %s\n' \
            "$case_name" "no_map" "PASS" "-" "FAIL (no pre-fix map)" \
            | tee -a "$LOG"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi

    diff_out=$(python3 "$DIFF_TOOL" \
        --reference "$postfix_map" \
        --candidate "$prefix_map" \
        --threshold 1e-6 2>&1)
    diff_rc=$?
    max_abs_diff=$(printf '%s\n' "$diff_out" \
        | awk '/max_abs_diff=/ {for (i=1;i<=NF;i++) if ($i ~ /^max_abs_diff=/) print substr($i,14)}' \
        | head -1)
    [ -n "$max_abs_diff" ] || max_abs_diff="?"

    if [ "$diff_rc" -eq 0 ]; then
        verdict="PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        verdict="FAIL (diff)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    printf '%-36s %-10s %-10s %-26s %s\n' \
        "$case_name" "rc=0" "PASS" "$max_abs_diff" "$verdict" | tee -a "$LOG"
done

{
    echo
    echo "PASS=$PASS_COUNT FAIL=$FAIL_COUNT SKIP=$SKIP_COUNT"
} | tee -a "$LOG"

if [ "$FAIL_COUNT" -ne 0 ]; then
    exit 1
fi
exit 0
