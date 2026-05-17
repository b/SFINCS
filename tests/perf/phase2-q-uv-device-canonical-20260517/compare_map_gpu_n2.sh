#!/bin/bash
# SOR-66 Phase 2 — deterministic full-completion gpu_n2 run of
# case_prod_compound_snapwave, used for the byte-identical sfincs_map.nc
# pre/post gate (AC #7).
#
# Replicates tests/run_validation.sh's run_gpu() invocation exactly
# (run_gpu_container.sh -> mpirun --allow-run-as-root --wdir <run> -n 2
# /work/source/install_cuda/bin/sfincs), runs the case to completion (the
# unmodified 24 h sfincs.inp), and copies the resulting sfincs_map.nc to
# this directory as sfincs_map.<label>.nc.
#
# Usage (from repo root), run once per branch against the SAME container
# + SAME input, rebuilding source/install_cuda between the two:
#
#     tests/perf/phase2-q-uv-device-canonical-20260517/compare_map_gpu_n2.sh pre
#     tests/perf/phase2-q-uv-device-canonical-20260517/compare_map_gpu_n2.sh post
#     cmp tests/perf/phase2-q-uv-device-canonical-20260517/sfincs_map.pre.nc \
#         tests/perf/phase2-q-uv-device-canonical-20260517/sfincs_map.post.nc

set -euo pipefail

LABEL=${1:?usage: compare_map_gpu_n2.sh <pre|post>}
REPO_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
CASE_NAME=case_prod_compound_snapwave
CASE_DIR=$REPO_ROOT/tests/cases/$CASE_NAME
OUT_DIR=$REPO_ROOT/tests/perf/phase2-q-uv-device-canonical-20260517
RUN_DIR=$OUT_DIR/maprun_$LABEL
GPU_WRAPPER=$REPO_ROOT/source/build_scripts/run_gpu_container.sh
GPU_BIN_CONTAINER=/work/source/install_cuda/bin/sfincs

mkdir -p "$RUN_DIR"
find "$RUN_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
for entry in "$CASE_DIR"/*; do
    base=$(basename "$entry")
    case "$base" in
        README.md|fetch.sh|generate.py) ;;
        sfincs.inp) cp -- "$entry" "$RUN_DIR/$base" ;;
        *) ln -srf -- "$entry" "$RUN_DIR/$base" ;;
    esac
done

case "$RUN_DIR" in
    "$REPO_ROOT"/*) CONTAINER_RUN_DIR="/work${RUN_DIR#$REPO_ROOT}" ;;
    *) echo "RUN_DIR is outside REPO_ROOT" >&2; exit 1 ;;
esac

echo "=== SOR-66 Phase 2 map run: label=$LABEL ($CASE_NAME gpu_n2) ==="
( cd "$RUN_DIR"
  "$GPU_WRAPPER" mpirun --allow-run-as-root --wdir "$CONTAINER_RUN_DIR" \
      -n 2 "$GPU_BIN_CONTAINER" > "$RUN_DIR/sfincs.log" 2>&1 )
rc=$?
echo "--- run exit=$rc ---"

if [ ! -f "$RUN_DIR/sfincs_map.nc" ]; then
    echo "ERROR: $RUN_DIR/sfincs_map.nc not produced (see sfincs.log)" >&2
    tail -30 "$RUN_DIR/sfincs.log" >&2 || true
    exit 1
fi
if grep -q "error = 1" "$RUN_DIR/sfincs.log"; then
    echo "ERROR: 'error = 1' STOP in sfincs.log" >&2
    exit 1
fi

cp -f "$RUN_DIR/sfincs_map.nc" "$OUT_DIR/sfincs_map.$LABEL.nc"
cp -f "$RUN_DIR/sfincs.log"    "$OUT_DIR/sfincs.maprun_$LABEL.log"
rm -rf "$RUN_DIR"
echo "=== wrote $OUT_DIR/sfincs_map.$LABEL.nc ==="
