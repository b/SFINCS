#!/bin/sh
set -e

if ! command -v nvfortran >/dev/null 2>&1; then
    echo "ERROR: nvfortran not found on \$PATH." >&2
    echo "Install the NVIDIA HPC SDK, or build inside the dev container via" >&2
    echo "  source/build_scripts/run_gpu_container.sh source/build_scripts/build_cuda.sh" >&2
    exit 1
fi

SOURCE_DIR=$(cd "$(dirname "$0")/.." && pwd)
REPO_ROOT=$(cd "$SOURCE_DIR/.." && pwd)
PREFIX=${SFINCS_PREFIX:-"$SOURCE_DIR/install_cuda"}

# SOR-69 Phase 5 — canonical-on-device regression guard. Run before
# any CUDA build to catch per-step host<->device bridges that would
# silently regress the SOR-65/66/67/68 PCIe gains. The guard scans
# the three per-step `_gpu.cuf` files (momentum / continuity /
# boundaries) for `call bridge_in_*` / `call bridge_out_*` calls and
# bare `<name>[_h] = <name>[_h]` shadow assignments, and exits
# non-zero on any line not on the allowlist
# (scripts/per-step-bridge-allowlist.txt). See
# docs/gpu_canonical_on_device.md for the invariant.
echo "--- canonical-on-device regression guard ---"
"$REPO_ROOT/scripts/check-no-per-step-bridges.sh"

cd "$SOURCE_DIR"

autoreconf -ivf
./autogen.sh

./configure --enable-cuda \
    FC=nvfortran F77=nvfortran \
    FCFLAGS="-O3 -fast -DSIZEOF_PTRDIFF_T=999" \
    --disable-shared \
    --prefix="$PREFIX" \
    "$@"

# Single-threaded by design — Automake does not encode Fortran .mod dependencies.
make
make install
