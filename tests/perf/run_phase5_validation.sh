#!/bin/bash
# SOR-69 Phase 5 — full CPU-vs-GPU validation-matrix run on the merged
# Phases 1+2+3+4 stack.
#
# Builds CPU + CUDA from the current source tree, runs every case under
# tests/cases/ at gpu_n1 and gpu_n2, diffs each GPU run's zsmax against
# the matching CPU baseline at the harness's standard 1e-4 ratio
# threshold (with per-pair overrides in tests/run_validation.sh
# unchanged), and commits the resulting verdict table + the full run
# stdout to the Phase 5 artifact directory.
#
# Usage (run from the repo root):
#     tests/perf/run_phase5_validation.sh
#
# Outputs (under tests/perf/phase5-canonical-on-device-final-20260517/):
#   * validation_stdout.txt   — captured stdout/stderr of the harness
#   * validation_verdicts.txt — extracted `=== Validation summary ===` block
#   * validation_exit_code.txt — the harness's exit code (0 = all PASS)
#
# This script is the AC #1 driver for SOR-69 Phase 5 ("every (case,
# config) verdict that was PASS pre-Phase-1 is still PASS post-Phase-4
# at the unchanged 1e-4 ratio threshold"). The full harness sources its
# THRESHOLD_OVERRIDE map from tests/run_validation.sh unchanged; the AC
# allows per-case overrides documented there, only forbidding a
# tightening of the global threshold below 1e-4.

set -uo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT_DIR=$REPO_ROOT/tests/perf/phase5-canonical-on-device-final-20260517

if [ ! -d "$OUT_DIR" ]; then
    echo "ERROR: artifact directory $OUT_DIR not found" >&2
    exit 2
fi

STDOUT_LOG=$OUT_DIR/validation_stdout.txt
VERDICTS=$OUT_DIR/validation_verdicts.txt
EXITCODE_FILE=$OUT_DIR/validation_exit_code.txt

echo "=== SOR-69 Phase 5 validation matrix ==="
echo "out_dir: $OUT_DIR"
echo "harness: $REPO_ROOT/tests/run_validation.sh --skip-fetch"
echo ""

set +e
"$REPO_ROOT/tests/run_validation.sh" --skip-fetch 2>&1 | tee "$STDOUT_LOG"
RC=${PIPESTATUS[0]}
set -e

echo "$RC" > "$EXITCODE_FILE"

# Extract the verdict-table block (between `=== Validation summary ===`
# and the final `OVERALL: ...` line) for a compact summary the operator
# can cite in the PR description.
awk '
    /^=== Validation summary ===$/ { in_block = 1 }
    in_block { print }
    /^OVERALL: / { in_block = 0 }
' "$STDOUT_LOG" > "$VERDICTS"

echo
echo "--- artifacts written ---"
ls -l "$STDOUT_LOG" "$VERDICTS" "$EXITCODE_FILE"
echo
echo "harness exit code: $RC"
exit "$RC"
