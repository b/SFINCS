#!/bin/bash
# Regression test for the dtwave runtime advisory.
#
# Stages tests/cases/case_snapwave (a SnapWave-enabled smoke case shipping
# dtwave = 1800 s in its sfincs.inp) into a temp dir, neutralises the time
# loop by setting tstop = tstart so the run completes in seconds, invokes
# the CPU SFINCS binary, and greps the captured stdout for the one-line
# advisory that SFINCS emits whenever sfincs.inp overrides dtwave below
# the SFINCS code default of 3600 s.
#
# This is a diagnostic-surface test only: it gates on the presence of the
# advisory line, not on simulation output. The negative path (dtwave equal
# to the code default emits no advisory) is also verified.
#
# Run from the repository root, after building the CPU binary via
# source/build_scripts/build_gfortran_cpu.sh:
#
#     tests/scripts/test_dtwave_advisory.sh

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CPU_BIN=${SFINCS_CPU_BIN:-$REPO_ROOT/source/install_cpu/bin/sfincs}
CASE_DIR=$REPO_ROOT/tests/cases/case_snapwave
ADVISORY_GREP='dtwave=1800.0 s is below the SFINCS default 3600 s'

if [ ! -x "$CPU_BIN" ]; then
    echo "test_dtwave_advisory: CPU binary not found at $CPU_BIN" >&2
    echo "                      build via source/build_scripts/build_gfortran_cpu.sh," >&2
    echo "                      or set SFINCS_CPU_BIN=<path>." >&2
    exit 2
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

stage_case() {
    local dst=$1
    local dtwave_value=$2
    mkdir -p "$dst"
    cp -a "$CASE_DIR"/. "$dst"/
    # Short-circuit the time loop (sfincs_lib.F90 do while (t < t1)).
    sed -i 's/^tstop *=.*/tstop             = 20200101 000000/' "$dst/sfincs.inp"
    sed -i "s/^dtwave *=.*/dtwave            = ${dtwave_value}/" "$dst/sfincs.inp"
}

run_sfincs() {
    local dir=$1
    (cd "$dir" && "$CPU_BIN") > "$dir/stdout.log" 2> "$dir/stderr.log" || true
}

# Positive case: dtwave = 1800 s (below the 3600 s code default).
POS=$WORK/dtwave_1800
stage_case "$POS" 1800.0
run_sfincs "$POS"

if grep -F "$ADVISORY_GREP" "$POS/stdout.log" > /dev/null; then
    echo "PASS: advisory present for dtwave=1800.0"
else
    echo "FAIL: advisory missing for dtwave=1800.0" >&2
    echo "----- stdout tail ($POS) -----" >&2
    tail -40 "$POS/stdout.log" >&2
    exit 1
fi

# Negative case: dtwave = 3600 s (matches the SFINCS code default).
NEG=$WORK/dtwave_3600
stage_case "$NEG" 3600.0
run_sfincs "$NEG"

if grep -F 'below the SFINCS default 3600' "$NEG/stdout.log" > /dev/null; then
    echo "FAIL: advisory unexpectedly emitted for dtwave=3600.0" >&2
    echo "----- stdout tail ($NEG) -----" >&2
    tail -40 "$NEG/stdout.log" >&2
    exit 1
fi

echo "PASS: no advisory for dtwave=3600.0"
echo "OVERALL: PASS"
