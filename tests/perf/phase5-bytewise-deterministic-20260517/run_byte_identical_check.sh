#!/bin/bash
# SOR-79 — strict byte-identical re-verification on a deterministic GPU path.
#
# SOR-69 Phase 5 AC #2 attempted strict byte-identicality on
# case_prod_compound_snapwave at gpu_n2 and found 1.645e-4 zsmax ratio
# rather than bit-equivalence. The diagnosis (in
# tests/perf/phase5-canonical-on-device-final-20260517/SUMMARY.md and
# in docs/diagnostics/multirank-partition-precision-drift.md) attributes
# the residual to inherent multi-rank floating-point non-associativity
# in the cross-partition wet/dry front propagation in k_compute_fluxes,
# latched permanently by the zsmax running max. The validation matrix's
# own THRESHOLD_OVERRIDE map already documents this case at 5e-4.
#
# This driver closes the remaining gap by re-running the experiment on a
# (case, config) pair where the GPU code path does NOT carry that
# non-associativity:
#
#   * Single-rank (gpu_n1): no MPI partition halo exchange, no
#     cross-partition atomics or reductions in k_compute_fluxes.
#   * No SnapWave coupling: avoids the host-side SnapWave path entirely.
#   * No quadtree / nonhydrostatic / wavemaker features beyond a bare
#     boundary-condition-driven flow.
#
# Per the SOR-79 issue body, the chosen pair is `case_regular gpu_n1`:
# a 50x50 uniform grid, one-day simulation, BC-driven only, no
# THRESHOLD_OVERRIDE in tests/run_validation.sh. The same selection
# criteria are met by case_meteo and case_structures; case_regular is
# the simplest of the three.
#
# The script:
#   1. Builds the pre-Phase-1 binary at commit d1b84c1 in a sibling
#      worktree (or reuses it if cached).
#   2. Uses the post-Phase-4 binary at HEAD-of-main built in this
#      worktree at source/install_cuda/bin/sfincs.
#   3. Runs the selected case at the selected config to completion on
#      both binaries, in disjoint run directories.
#   4. Compares the two sfincs_map.nc outputs three ways:
#        (a) file size, sha256, cmp -s          (strict byte-identicality)
#        (b) ncdump -h diff                     (structural diff)
#        (c) tests/scripts/diff_zsmax.py at 1e-6 threshold
#            (100x tighter than the SOR-69 strict gate; expected to PASS
#             trivially if (a) PASSes)
#
# Outputs (committed under this directory):
#   * pre_phase1_sfincs_map.nc   — pre-Phase-1 baseline (build of d1b84c1)
#   * post_phase4_sfincs_map.nc  — post-Phase-4 (this worktree)
#   * byte_identical_check.log   — cmp / ncdump / diff_zsmax results
#
# Usage (run from the repo root, after building post-Phase-4 via
# source/build_scripts/run_gpu_container.sh source/build_scripts/build_cuda.sh):
#
#     CASE=case_regular CFG=gpu_n1 \
#         tests/perf/phase5-bytewise-deterministic-20260517/run_byte_identical_check.sh

set -uo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
OUT_DIR=$REPO_ROOT/tests/perf/phase5-bytewise-deterministic-20260517

CASE=${CASE:-case_regular}
CFG=${CFG:-gpu_n1}
case "$CFG" in
    gpu_n1) NRANKS=1 ;;
    gpu_n2) NRANKS=2 ;;
    *) echo "ERROR: unsupported CFG=$CFG (need gpu_n1 or gpu_n2)" >&2; exit 2 ;;
esac

PRE_PHASE1_COMMIT=d1b84c1
PRE_BASELINE=$OUT_DIR/pre_phase1_sfincs_map.nc
POST_BASELINE=$OUT_DIR/post_phase4_sfincs_map.nc
LOG=$OUT_DIR/byte_identical_check.log

POST_BIN_HOST=$REPO_ROOT/source/install_cuda/bin/sfincs
POST_BIN_CONTAINER=/work/source/install_cuda/bin/sfincs
GPU_WRAPPER=$REPO_ROOT/source/build_scripts/run_gpu_container.sh

if [ ! -x "$POST_BIN_HOST" ]; then
    echo "ERROR: post-Phase-4 binary missing at $POST_BIN_HOST" >&2
    echo "       Build it via: $GPU_WRAPPER source/build_scripts/build_cuda.sh" >&2
    exit 2
fi

# Map a host abs path under REPO_ROOT to its container path under /work.
host_to_container() {
    local host_path=$1
    case "$host_path" in
        "$REPO_ROOT") echo "/work" ;;
        "$REPO_ROOT"/*) echo "/work${host_path#"$REPO_ROOT"}" ;;
        *) echo "host_to_container: $host_path outside REPO_ROOT" >&2; return 1 ;;
    esac
}

# Populate $run_dir from $case_dir, copying (not symlinking) so the
# baseline-worktree run can mount its own tree without symlinks pointing
# outside the container mount. README.md and fetch.sh are skipped.
populate_run_dir() {
    local case_dir=$1 run_dir=$2
    mkdir -p "$run_dir"
    find "$run_dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    local entry base
    for entry in "$case_dir"/*; do
        [ -e "$entry" ] || continue
        base=$(basename "$entry")
        case "$base" in
            README.md|fetch.sh|generate.py) ;;
            *) cp -- "$entry" "$run_dir/$base" ;;
        esac
    done
}

# --- Pre-Phase-1 baseline: build (if needed) + run ----------------------------

if [ ! -f "$PRE_BASELINE" ]; then
    echo "[run_byte_identical_check] pre-Phase-1 baseline missing; reconstructing"
    WORKTREE_PATH=${SFINCS_PHASE5_BASELINE_WORKTREE:-/tmp/sfincs-pre-phase1-baseline}
    if [ ! -d "$WORKTREE_PATH" ]; then
        git -C "$REPO_ROOT" worktree add --detach "$WORKTREE_PATH" "$PRE_PHASE1_COMMIT"
    fi
    BASE_BIN=$WORKTREE_PATH/source/install_cuda/bin/sfincs
    if [ ! -x "$BASE_BIN" ]; then
        (
            cd "$WORKTREE_PATH"
            source/build_scripts/run_gpu_container.sh source/build_scripts/build_cuda.sh
        )
    else
        echo "[run_byte_identical_check] reusing cached baseline binary: $BASE_BIN"
    fi
    BASE_CASE_DIR=$WORKTREE_PATH/tests/cases/$CASE
    if [ ! -d "$BASE_CASE_DIR" ]; then
        echo "ERROR: case $CASE missing in baseline worktree $WORKTREE_PATH" >&2
        exit 3
    fi
    BASE_RUN_DIR=$WORKTREE_PATH/tests/runs/$CASE/$CFG
    populate_run_dir "$BASE_CASE_DIR" "$BASE_RUN_DIR"
    (
        cd "$WORKTREE_PATH"
        # Reuse the baseline worktree's run_gpu_container.sh wrapper; the
        # baseline binary lives in this same worktree, so /work resolves
        # correctly inside the container.
        source/build_scripts/run_gpu_container.sh sh -c \
            "cd tests/runs/$CASE/$CFG && \
             mpirun --allow-run-as-root -n $NRANKS /work/source/install_cuda/bin/sfincs"
    )
    if [ ! -f "$BASE_RUN_DIR/sfincs_map.nc" ]; then
        echo "ERROR: pre-Phase-1 baseline run did not produce sfincs_map.nc" >&2
        exit 4
    fi
    cp -f "$BASE_RUN_DIR/sfincs_map.nc" "$PRE_BASELINE"
    echo "[run_byte_identical_check] pre-Phase-1 baseline captured: $PRE_BASELINE"
fi

# --- Post-Phase-4: run in this worktree --------------------------------------

if [ ! -f "$POST_BASELINE" ]; then
    POST_RUN_DIR=$REPO_ROOT/tests/runs/$CASE/$CFG
    populate_run_dir "$REPO_ROOT/tests/cases/$CASE" "$POST_RUN_DIR"
    container_run_dir=$(host_to_container "$POST_RUN_DIR")
    (
        cd "$POST_RUN_DIR"
        "$GPU_WRAPPER" \
            mpirun --allow-run-as-root --wdir "$container_run_dir" \
            -n "$NRANKS" "$POST_BIN_CONTAINER"
    )
    if [ ! -f "$POST_RUN_DIR/sfincs_map.nc" ]; then
        echo "ERROR: post-Phase-4 run did not produce sfincs_map.nc" >&2
        exit 5
    fi
    cp -f "$POST_RUN_DIR/sfincs_map.nc" "$POST_BASELINE"
    echo "[run_byte_identical_check] post-Phase-4 result captured: $POST_BASELINE"
fi

# --- Comparison --------------------------------------------------------------

echo "[run_byte_identical_check] running comparison ..."
{
    echo "=== SOR-79 — bytewise-deterministic byte-identical check ==="
    echo "case               : $CASE"
    echo "config             : $CFG (nranks=$NRANKS)"
    echo "pre-Phase-1 commit : $PRE_PHASE1_COMMIT"
    echo "post-Phase-4 commit: $(git -C "$REPO_ROOT" rev-parse HEAD)"
    echo "pre baseline       : $PRE_BASELINE"
    echo "post baseline      : $POST_BASELINE"
    echo ""
    echo "--- size + sha256 ---"
    stat -c '%n  %s bytes' "$PRE_BASELINE" "$POST_BASELINE"
    sha256sum "$PRE_BASELINE" "$POST_BASELINE"
    echo ""
    echo "--- cmp byte-by-byte (first 10 diffs) ---"
    cmp -l "$PRE_BASELINE" "$POST_BASELINE" | head -10 || true
    cmp -s "$PRE_BASELINE" "$POST_BASELINE"
    CMP_RC=$?
    if [ "$CMP_RC" -eq 0 ]; then
        echo "cmp: byte-identical (SOR-79 strict gate — PASS)"
    else
        echo "cmp: NOT byte-identical (SOR-79 strict gate — see 1e-6 ratio below)"
    fi
    echo ""
    echo "--- ncdump -h diff ---"
    if command -v ncdump >/dev/null 2>&1; then
        diff <(ncdump -h "$PRE_BASELINE" 2>&1) <(ncdump -h "$POST_BASELINE" 2>&1) \
            || echo "(ncdump headers differ; see above)"
    else
        echo "ncdump not on PATH; skipping header diff"
    fi
    echo ""
    echo "--- diff_zsmax ratio check (pre as reference, 1e-6 threshold) ---"
    if command -v python3 >/dev/null 2>&1; then
        python3 "$REPO_ROOT/tests/scripts/diff_zsmax.py" \
            --reference "$PRE_BASELINE" --candidate "$POST_BASELINE" \
            --threshold 1e-6 \
            || true
    else
        echo "python3 not on PATH; skipping ratio check"
    fi
} | tee "$LOG"

echo ""
echo "[run_byte_identical_check] artifacts:"
ls -l "$PRE_BASELINE" "$POST_BASELINE" "$LOG"
