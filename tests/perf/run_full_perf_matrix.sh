#!/bin/bash
# tests/perf/run_full_perf_matrix.sh — single-script orchestrator.
#
# Runs the full perf scaling matrix capture (delegating to the
# existing run_perf_scaling.sh harness) and then renders the
# tests/perf/analyze/ default plot set + a copy of the explore.ipynb
# notebook into the same output directory. Single command from repo
# root produces a self-contained results directory.
#
# Usage (from repo root):
#
#     bash tests/perf/run_full_perf_matrix.sh
#     OUT_DIR=tests/perf/perf-full-20260601 bash tests/perf/run_full_perf_matrix.sh
#     PRIOR_SWEEP=tests/perf/perf-scaling-sweep-20260519-post-sor1019 \
#         bash tests/perf/run_full_perf_matrix.sh
#     bash tests/perf/run_full_perf_matrix.sh --skip-build --case case_prod_regular_tide --length 1h
#
# Output layout:
#
#     <OUT_DIR>/
#       run_perf_scaling.sh             # copy of the template runner
#       capture_env.txt                 # host fingerprint
#       run.stdout                      # orchestration log
#       <case>__<grid>__<length>__<config>/{sfincs.inp,log,stdout,timings.txt,nvidia_smi_dmon.txt}
#       plots/
#         wall_vs_length.png
#         per_step_vs_length.png
#         gpu_vs_cpu_speedup.png
#         component_breakdown.png
#         gpu_utilization.png
#         (+ *_compare.png when PRIOR_SWEEP is set)
#       explore.ipynb                   # notebook prepopulated to read this sweep
#
# Env knobs:
#
#     OUT_DIR        Output directory (default: tests/perf/perf-full-<YYYYMMDD>)
#     PRIOR_SWEEP    Optional prior sweep directory for comparison plots
#     PYTHON         Python interpreter to run the analyze layer
#                    (default: python3)
#     RUNNER_SRC     Override path to run_perf_scaling.sh to copy
#                    (default: most recent tests/perf/perf-scaling-sweep-*/run_perf_scaling.sh)
#
# Any remaining args are passed through to the inner run_perf_scaling.sh.

set -uo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
PERF_DIR=$REPO_ROOT/tests/perf
PY=${PYTHON:-python3}

# Pick template runner — the most recently-modified sweep dir's runner.
if [ -z "${RUNNER_SRC:-}" ]; then
    RUNNER_SRC=$(ls -td "$PERF_DIR"/perf-scaling-sweep-*/run_perf_scaling.sh 2>/dev/null | head -1)
fi
if [ -z "${RUNNER_SRC:-}" ] || [ ! -f "$RUNNER_SRC" ]; then
    echo "ERROR: no run_perf_scaling.sh template found under $PERF_DIR/perf-scaling-sweep-*/" >&2
    echo "       set RUNNER_SRC=<path> to override" >&2
    exit 1
fi

OUT_DIR=${OUT_DIR:-$PERF_DIR/perf-full-$(date -u +%Y%m%d)}
mkdir -p "$OUT_DIR"

# The inner run_perf_scaling.sh computes REPO_ROOT as "$(dirname "$0")/../../.."
# from its installed path — so OUT_DIR MUST be a directory at depth
# REPO_ROOT/<a>/<b>/<OUT_DIR>, i.e. exactly two levels below REPO_ROOT.
# The canonical placement is tests/perf/<sweep_dir>. Refuse anything else
# to avoid silent miscompiled paths when a user picks /tmp or similar.
OUT_DIR_ABS=$(cd "$OUT_DIR" && pwd)
EXPECTED_PARENT=$(cd "$OUT_DIR_ABS/../../.." && pwd)
if [ "$EXPECTED_PARENT" != "$REPO_ROOT" ]; then
    echo "ERROR: OUT_DIR must live at <REPO_ROOT>/tests/perf/<sweep_dir>." >&2
    echo "       OUT_DIR=$OUT_DIR resolves to parent=$EXPECTED_PARENT," >&2
    echo "       expected REPO_ROOT=$REPO_ROOT." >&2
    exit 2
fi

echo "=== run_full_perf_matrix — start $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo "  REPO_ROOT:  $REPO_ROOT"
echo "  OUT_DIR:    $OUT_DIR"
echo "  RUNNER_SRC: $RUNNER_SRC"
echo "  PRIOR:      ${PRIOR_SWEEP:-<none>}"
echo "  passthrough args: $*"

cp -f "$RUNNER_SRC" "$OUT_DIR/run_perf_scaling.sh"
chmod +x "$OUT_DIR/run_perf_scaling.sh"

# generate_4x_regular_tide.py is required by the 4x branch.
GEN_4X=$(dirname "$RUNNER_SRC")/generate_4x_regular_tide.py
if [ -f "$GEN_4X" ]; then
    cp -f "$GEN_4X" "$OUT_DIR/generate_4x_regular_tide.py"
fi

# Run the capture harness. The template runner writes into its own
# dirname; we copied it into OUT_DIR so it lands here.
bash "$OUT_DIR/run_perf_scaling.sh" "$@"
RC=$?
if [ $RC -ne 0 ]; then
    echo "WARNING: run_perf_scaling.sh exited $RC; continuing into analyze layer"
fi

# Render the default plot set.
PRIOR_ARGS=()
if [ -n "${PRIOR_SWEEP:-}" ]; then
    PRIOR_ARGS=(--prior "$PRIOR_SWEEP")
fi
(
    cd "$REPO_ROOT"
    "$PY" -m tests.perf.analyze.plot --sweep "$OUT_DIR" "${PRIOR_ARGS[@]}"
)

# Drop a copy of the notebook into OUT_DIR. The notebook auto-detects
# SWEEP_DIR via its own directory or env override; we also write a
# small marker file so the operator can see at-a-glance which sweep
# the notebook is keyed to.
cp -f "$PERF_DIR/analyze/explore.ipynb" "$OUT_DIR/explore.ipynb"

# Per-sweep README — short pointer for operators that find the
# directory later without context.
cat > "$OUT_DIR/README.md" <<EOF
# Perf sweep $(basename "$OUT_DIR")

Captured by \`tests/perf/run_full_perf_matrix.sh\` on $(date -u +%Y-%m-%dT%H:%M:%SZ).

## Files

* \`capture_env.txt\` — host CPU / GPU / container image / HEAD.
* \`run.stdout\` — orchestration log.
* \`<case>__<grid>__<length>__<config>/\` — per-cell artifacts.
* \`plots/\` — default plot set (PNGs).
* \`explore.ipynb\` — Jupyter notebook for interactive exploration.

## Re-rendering plots

\`\`\`
cd $REPO_ROOT
$PY -m tests.perf.analyze.plot --sweep $OUT_DIR
\`\`\`

## Opening the notebook

\`\`\`
cd $REPO_ROOT
$PY -m jupyter lab tests/perf/analyze/explore.ipynb
\`\`\`

The notebook's default \`SWEEP_DIR\` points at the latest
\`perf-scaling-sweep-*\` directory. Set the \`SWEEP_DIR\` env var
to this directory's absolute path to point it here:

\`\`\`
SWEEP_DIR=$OUT_DIR $PY -m jupyter lab tests/perf/analyze/explore.ipynb
\`\`\`
EOF

echo "=== run_full_perf_matrix — complete $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo "  out_dir:  $OUT_DIR"
echo "  plots:    $OUT_DIR/plots/"
echo "  notebook: $OUT_DIR/explore.ipynb"
