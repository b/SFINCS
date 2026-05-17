#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
#
# CPU smoke validation for SOR-78 (col_idx unallocated-write fix in
# initialize_nonhydrostatic).
#
# Builds the gfortran CPU SFINCS binary against the in-tree sources,
# runs it against the synthetic nonh = 1 case in
#   source/build_scripts/smoke/nonhydrostatic/
# and asserts that:
#   * the run exits 0 (no SIGSEGV inside __memset during init), and
#   * the captured stdout contains "Time in non-hydrostatic:", which is
#     only printed by sfincs_lib.F90 after the time loop completes and
#     therefore proves that initialize_nonhydrostatic() returned cleanly
#     and the time-loop call to compute_nonhydrostatic at line 671 was
#     reached at least once.
#
# Non-hydrostatic is CPU-only (not GPU-ported), so this smoke is
# intentionally CPU-only — no GPU/CPU diff harness is needed.
#
# Usage (from the repo root):
#   source/build_scripts/run_smoke_nonhydrostatic.sh [--no-build]
#
# Options:
#   --no-build         Skip the CPU build step; reuse the existing binary.
#   -h | --help        Print this usage and exit.

set -e

usage() {
    sed -n '1,/^$/p' "$0" | sed 's/^# \{0,1\}//' | head -n 30
}

NO_BUILD=0

while [ $# -gt 0 ]; do
    case "$1" in
        --no-build)             NO_BUILD=1 ; shift ;;
        -h|--help)              usage ; exit 0 ;;
        *) echo "Unknown argument: $1" >&2 ; usage ; exit 2 ;;
    esac
done

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SOURCE_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
SMOKE_DIR="$SCRIPT_DIR/smoke/nonhydrostatic"
BUILD_ROOT="$SCRIPT_DIR/smoke/_build"
RUN_ROOT="$SCRIPT_DIR/smoke/_run"

CPU_PREFIX="$BUILD_ROOT/cpu/install"
CPU_BIN="$CPU_PREFIX/bin/sfincs"

CPU_RUN="$RUN_ROOT/nonhydrostatic"

if [ ! -d "$SMOKE_DIR" ]; then
    echo "ERROR: synthetic case not found at $SMOKE_DIR" >&2
    exit 1
fi

if ! command -v gfortran >/dev/null 2>&1; then
    echo "ERROR: gfortran not found on \$PATH." >&2
    exit 1
fi

if [ "$NO_BUILD" = "0" ]; then
    echo "==> Building CPU binary (gfortran) -> $CPU_PREFIX"
    rm -rf "$BUILD_ROOT/cpu"
    mkdir -p "$CPU_PREFIX"
    (
        cd "$SOURCE_DIR"
        if [ -f Makefile ]; then
            make distclean >/dev/null 2>&1 || true
        fi
        autoreconf -ivf
        ./autogen.sh
        ./configure \
            FC=gfortran \
            FCFLAGS="-fopenmp -O3 -fallow-argument-mismatch -w" \
            FFLAGS="-fopenmp -O3 -fallow-argument-mismatch -w" \
            --disable-shared \
            --prefix="$CPU_PREFIX"
        make
        make install
    )
fi

if [ ! -x "$CPU_BIN" ]; then
    echo "ERROR: CPU binary missing at $CPU_BIN (run without --no-build)" >&2
    exit 1
fi

echo "==> Preparing run dir $CPU_RUN"
rm -rf "$CPU_RUN"
mkdir -p "$CPU_RUN"
cp "$SMOKE_DIR"/sfincs.* "$CPU_RUN/"

echo "==> Running CPU sfincs in $CPU_RUN"
(
    cd "$CPU_RUN"
    OMP_NUM_THREADS=1
    export OMP_NUM_THREADS
    start=$(date +%s.%N)
    "$CPU_BIN" >sfincs.stdout 2>sfincs.stderr
    end=$(date +%s.%N)
    awk -v s="$start" -v e="$end" 'BEGIN { printf "%.3f\n", e - s }' >sfincs.wallsec
    printf "    wall: %s s\n" "$(cat sfincs.wallsec)"
)

LOG="$CPU_RUN/sfincs.stdout"

if [ ! -f "$LOG" ]; then
    echo "ERROR: run log missing at $LOG" >&2
    exit 1
fi

# The "Time in non-hydrostatic:" line is printed by sfincs_lib.F90 only
# when (a) nonhydrostatic was .true., AND (b) finalize_output is reached
# after the time loop. Reaching finalize_output proves init returned
# without SIGSEGV and the time loop executed at least one step (which in
# turn calls compute_nonhydrostatic at sfincs_lib.F90:671 every step).
if grep -q "Time in non-hydrostatic:" "$LOG"; then
    printf '\n==> PASS: log evidences init returned and compute_nonhydrostatic was reached\n'
    grep -E "Non-hydrostatic|Time in non-hydrostatic:" "$LOG" | sed 's/^/    /'
    exit 0
else
    printf '\n==> FAIL: log does not contain "Time in non-hydrostatic:" — init may have crashed\n' >&2
    tail -40 "$LOG" >&2
    exit 1
fi
