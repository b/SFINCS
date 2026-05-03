#!/bin/sh
set -e

if ! command -v nvfortran >/dev/null 2>&1; then
    echo "ERROR: nvfortran not found on \$PATH." >&2
    echo "Install the NVIDIA HPC SDK, or build inside the dev container via" >&2
    echo "  source/build_scripts/run_gpu_container.sh source/build_scripts/build_cuda.sh" >&2
    exit 1
fi

SOURCE_DIR=$(cd "$(dirname "$0")/.." && pwd)
PREFIX=${SFINCS_PREFIX:-"$SOURCE_DIR/install_cuda"}

cd "$SOURCE_DIR"

autoreconf -ivf
./autogen.sh

./configure --enable-cuda \
    FC=nvfortran F77=nvfortran \
    FCFLAGS="-O3 -fast -DSIZEOF_PTRDIFF_T=999" \
    --disable-shared \
    --prefix="$PREFIX"

# Single-threaded by design — Automake does not encode Fortran .mod dependencies.
make
make install
