#!/bin/bash
# SOR-69 Phase 5 AC #2 — sfincs_map.nc byte-identical check
# (case_prod_compound_snapwave gpu_n2, pre-Phase-1 vs post-Phase-4).
#
# Produces a pre-Phase-1 baseline sfincs_map.nc on demand by building
# the binary at commit d1b84c1 (the Phase-0 NVTX-annotated commit that
# immediately precedes the Phase-1 zs-device-canonical refactor at
# 9c3e69c) in a sibling worktree, running case_prod_compound_snapwave
# at gpu_n2 to completion, and committing the resulting sfincs_map.nc
# as `pre_phase1_sfincs_map.nc` alongside this script. The post-Phase-4
# sfincs_map.nc is taken from the running validation matrix's output at
# tests/runs/case_prod_compound_snapwave/gpu_n2/sfincs_map.nc and is
# copied to `post_phase4_sfincs_map.nc` for reproducibility.
#
# The two files are then compared in three ways:
#   (1) `cmp -l` byte-by-byte diff — the literal "byte-identical" AC.
#   (2) `ncdump -h` header diff — to flag structural differences.
#   (3) `tests/scripts/diff_zsmax.py` — the same ratio check the
#       validation harness runs against the CPU baseline, here applied
#       to the pre-Phase-1 file as the "reference" instead.
#
# Outputs (committed under this directory):
#   * pre_phase1_sfincs_map.nc   — pre-Phase-1 baseline (build of d1b84c1)
#   * post_phase4_sfincs_map.nc  — post-Phase-4 (from validation matrix)
#   * byte_identical_check.log   — cmp / ncdump / diff_zsmax results
#
# Cost: ~30 min wall — one full CUDA build (~10 min) plus one
# case_prod_compound_snapwave gpu_n2 run (~10-20 min) in the sibling
# worktree. Skipped automatically if the pre-Phase-1 sfincs_map.nc is
# already present (the file is committed to the repo so reruns are
# read-only diffs).
#
# Usage (run AFTER the validation matrix completes, from the repo root):
#     tests/perf/phase5-canonical-on-device-final-20260517/run_byte_identical_check.sh

set -uo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
OUT_DIR=$REPO_ROOT/tests/perf/phase5-canonical-on-device-final-20260517
PRE_PHASE1_COMMIT=d1b84c1
PRE_BASELINE=$OUT_DIR/pre_phase1_sfincs_map.nc
POST_BASELINE=$OUT_DIR/post_phase4_sfincs_map.nc
LOG=$OUT_DIR/byte_identical_check.log

POST_PHASE4_SRC=$REPO_ROOT/tests/runs/case_prod_compound_snapwave/gpu_n2/sfincs_map.nc

if [ ! -f "$POST_PHASE4_SRC" ]; then
    echo "ERROR: post-Phase-4 sfincs_map.nc not at $POST_PHASE4_SRC" >&2
    echo "       Run tests/perf/run_phase5_validation.sh first." >&2
    exit 2
fi

cp -f "$POST_PHASE4_SRC" "$POST_BASELINE"
echo "[run_byte_identical_check] copied post-Phase-4 sfincs_map.nc -> $POST_BASELINE"

# Build / run the pre-Phase-1 baseline if not already cached.
if [ ! -f "$PRE_BASELINE" ]; then
    echo "[run_byte_identical_check] pre-Phase-1 baseline missing; reconstructing"
    # Place the baseline worktree outside the operator's .sorcerer/
    # space so sorcerer-managed worktrees aren't disturbed. /tmp is
    # ephemeral; the baseline sfincs_map.nc lives in this directory
    # once produced, so the worktree itself can be discarded after.
    WORKTREE_PATH=${SFINCS_PHASE5_BASELINE_WORKTREE:-/tmp/sfincs-pre-phase1-baseline}
    if [ ! -d "$WORKTREE_PATH" ]; then
        git -C "$REPO_ROOT" worktree add --detach "$WORKTREE_PATH" "$PRE_PHASE1_COMMIT"
    fi
    BASE_BIN=$WORKTREE_PATH/source/install_cuda/bin/sfincs
    if [ ! -x "$BASE_BIN" ]; then
        (
            cd "$WORKTREE_PATH"
            # Build CUDA in the dev container (uses run_gpu_container.sh
            # wrapper from the BASELINE commit, which is sufficient for
            # the pre-Phase-1 source).
            source/build_scripts/run_gpu_container.sh source/build_scripts/build_cuda.sh
        )
    else
        echo "[run_byte_identical_check] reusing cached baseline binary: $BASE_BIN"
    fi
    # Run case_prod_compound_snapwave at gpu_n2 in the baseline worktree.
    # Copy (not symlink) the case data: the docker container mounts
    # $WORKTREE_PATH at /work, and symlinks into the main repo's
    # tests/cases/ would point outside the mount.
    BASE_RUN_DIR=$WORKTREE_PATH/tests/runs/case_prod_compound_snapwave/gpu_n2
    mkdir -p "$BASE_RUN_DIR"
    find "$BASE_RUN_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    for entry in "$REPO_ROOT/tests/cases/case_prod_compound_snapwave"/*; do
        base=$(basename "$entry")
        case "$base" in
            README.md|fetch.sh|generate.py) ;;
            *) cp -- "$entry" "$BASE_RUN_DIR/$base" ;;
        esac
    done
    # Reuse the harness's GPU wrapper to invoke mpirun -n 2 inside the
    # container, with the binary path resolved inside the baseline
    # worktree.
    (
        cd "$WORKTREE_PATH"
        source/build_scripts/run_gpu_container.sh sh -c \
            "cd tests/runs/case_prod_compound_snapwave/gpu_n2 && \
             mpirun --allow-run-as-root -n 2 /work/source/install_cuda/bin/sfincs"
    )
    if [ ! -f "$BASE_RUN_DIR/sfincs_map.nc" ]; then
        echo "ERROR: pre-Phase-1 baseline run did not produce sfincs_map.nc" >&2
        exit 3
    fi
    cp -f "$BASE_RUN_DIR/sfincs_map.nc" "$PRE_BASELINE"
    echo "[run_byte_identical_check] pre-Phase-1 baseline captured: $PRE_BASELINE"
fi

echo "[run_byte_identical_check] running comparison ..."
{
    echo "=== SOR-69 Phase 5 AC #2 — byte-identical check ==="
    echo "pre-Phase-1 baseline: $PRE_BASELINE"
    echo "post-Phase-4 result : $POST_BASELINE"
    echo ""
    echo "--- size + sha256 ---"
    stat -c '%n  %s bytes' "$PRE_BASELINE" "$POST_BASELINE"
    sha256sum "$PRE_BASELINE" "$POST_BASELINE"
    echo ""
    echo "--- cmp byte-by-byte (first 10 diffs) ---"
    cmp -l -n 134217728 "$PRE_BASELINE" "$POST_BASELINE" | head -10 || true
    cmp -s "$PRE_BASELINE" "$POST_BASELINE"
    CMP_RC=$?
    if [ "$CMP_RC" -eq 0 ]; then
        echo "cmp: byte-identical (AC #2 strict — PASS)"
    else
        echo "cmp: NOT byte-identical (AC #2 strict — see ratio check below)"
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
    echo "--- diff_zsmax ratio check (pre as reference, 1e-4 threshold) ---"
    if command -v python3 >/dev/null 2>&1; then
        python3 "$REPO_ROOT/tests/scripts/diff_zsmax.py" \
            --reference "$PRE_BASELINE" --candidate "$POST_BASELINE" \
            --threshold 1e-4 \
            || true
    else
        echo "python3 not on PATH; skipping ratio check"
    fi
} | tee "$LOG"

echo ""
echo "[run_byte_identical_check] artifacts:"
ls -l "$PRE_BASELINE" "$POST_BASELINE" "$LOG"
