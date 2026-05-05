#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
#
# GPU smoke validation for SOR-690: spiderweb + regular-meteo-grid spatial
# interpolation kernels.
#
# Builds CPU and GPU SFINCS binaries inside the GPU dev container (single
# nvfortran toolchain, the only difference is `--enable-cuda`), runs both
# against the synthetic case in
#   source/build_scripts/smoke/spiderweb_meteo/
# and reports max(|gpu - cpu|) / max(|cpu|) for the wind_u, wind_v, and
# surface_air_pressure fields. wind_u / wind_v are the host-side time
# interpolation of windu0/windu1 and windv0/windv1 (which the spiderweb
# kernel writes), and surface_air_pressure is the host-side time
# interpolation of patm0/patm1 (also written by the kernel) — so any
# divergence between CPU and GPU spatial interpolation is observable here.
#
# Both binaries are produced with the same compiler so the only path-
# difference is the .cuf kernels.
#
# Exits 0 if every per-field ratio is < TOL (default 1e-3), non-zero
# otherwise.
#
# Usage (from the repo root):
#   source/build_scripts/run_smoke_spiderweb_meteo.sh [--no-build] [--tol <f>]
#
# Options:
#   --no-build         Skip the CPU/GPU build steps; reuse existing binaries.
#   --tol <float>      Override the pass/fail tolerance (default 1e-3).
#   -h | --help        Print this usage and exit.

set -e

usage() {
    sed -n '1,/^$/p' "$0" | sed 's/^# \{0,1\}//' | head -n 32
}

NO_BUILD=0
TOL=1e-3
INNER=0

while [ $# -gt 0 ]; do
    case "$1" in
        --no-build)             NO_BUILD=1 ; shift ;;
        --tol)                  TOL="$2" ; shift 2 ;;
        --inner-build-and-run)  INNER=1 ; shift ;;
        -h|--help)              usage ; exit 0 ;;
        *) echo "Unknown argument: $1" >&2 ; usage ; exit 2 ;;
    esac
done

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SOURCE_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
SMOKE_DIR="$SCRIPT_DIR/smoke/spiderweb_meteo"
BUILD_ROOT="$SCRIPT_DIR/smoke/_build_spw"
RUN_ROOT="$SCRIPT_DIR/smoke/_run_spw"

CPU_PREFIX="$BUILD_ROOT/cpu/install"
GPU_PREFIX="$BUILD_ROOT/gpu/install"
CPU_BIN="$CPU_PREFIX/bin/sfincs"
GPU_BIN="$GPU_PREFIX/bin/sfincs"

CPU_RUN="$RUN_ROOT/cpu"
GPU_RUN="$RUN_ROOT/gpu"

if [ ! -d "$SMOKE_DIR" ]; then
    echo "ERROR: synthetic case not found at $SMOKE_DIR" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Inner mode: invoked inside the GPU container by the outer pass below.
# Builds both binaries, runs both against the synthetic case.
# ---------------------------------------------------------------------------
if [ "$INNER" = "1" ]; then

    if ! command -v nvfortran >/dev/null 2>&1; then
        echo "ERROR: --inner-build-and-run requires nvfortran on \$PATH." >&2
        exit 1
    fi

    configure_and_install() {
        prefix="$1"
        extra="$2"
        cd "$SOURCE_DIR"
        if [ -f Makefile ]; then
            make distclean >/dev/null 2>&1 || true
        fi
        autoreconf -ivf
        ./autogen.sh
        # shellcheck disable=SC2086
        ./configure $extra \
            FC=nvfortran F77=nvfortran \
            FCFLAGS="-O3 -fast -DSIZEOF_PTRDIFF_T=999" \
            --disable-shared \
            --prefix="$prefix"
        make
        make install
    }

    if [ "$NO_BUILD" = "0" ]; then
        echo "==> Building CPU binary (nvfortran, no --enable-cuda) → $CPU_PREFIX"
        rm -rf "$BUILD_ROOT/cpu"
        mkdir -p "$CPU_PREFIX"
        ( configure_and_install "$CPU_PREFIX" "" )

        echo "==> Building GPU binary (nvfortran, --enable-cuda) → $GPU_PREFIX"
        rm -rf "$BUILD_ROOT/gpu"
        mkdir -p "$GPU_PREFIX"
        ( configure_and_install "$GPU_PREFIX" "--enable-cuda" )
    fi

    if [ ! -x "$CPU_BIN" ]; then
        echo "ERROR: CPU binary missing at $CPU_BIN (run without --no-build)" >&2
        exit 1
    fi
    if [ ! -x "$GPU_BIN" ]; then
        echo "ERROR: GPU binary missing at $GPU_BIN (run without --no-build)" >&2
        exit 1
    fi

    prepare_run() {
        rundir="$1"
        rm -rf "$rundir"
        mkdir -p "$rundir"
        cp "$SMOKE_DIR"/sfincs.* "$rundir/"
    }

    run_sfincs() {
        bin="$1"
        rundir="$2"
        label="$3"
        cd "$rundir"
        mpi_wrap=""
        if command -v mpirun >/dev/null 2>&1; then
            mpi_wrap="mpirun --allow-run-as-root -n 1"
        fi
        OMP_NUM_THREADS=1
        export OMP_NUM_THREADS
        echo "==> Running $label binary in $rundir"
        start=$(date +%s.%N)
        # shellcheck disable=SC2086
        $mpi_wrap "$bin" >sfincs.stdout 2>sfincs.stderr
        end=$(date +%s.%N)
        awk -v s="$start" -v e="$end" 'BEGIN { printf "%.3f\n", e - s }' >sfincs.wallsec
        printf "    wall: %s s\n" "$(cat sfincs.wallsec)"
    }

    prepare_run "$CPU_RUN"
    prepare_run "$GPU_RUN"

    run_sfincs "$CPU_BIN" "$CPU_RUN" "CPU"
    run_sfincs "$GPU_BIN" "$GPU_RUN" "GPU"

    exit 0
fi

# ---------------------------------------------------------------------------
# Outer mode: invoked from the host. Delegates build+run to the GPU container
# and computes the diff locally with python3 + netCDF4.
# ---------------------------------------------------------------------------

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 not found on host." >&2
    exit 1
fi

if ! python3 -c 'import netCDF4, numpy' 2>/dev/null; then
    echo "ERROR: python3 needs the netCDF4 + numpy modules on the host." >&2
    echo "  e.g. apt install python3-netcdf4 python3-numpy" >&2
    exit 1
fi

INNER_ARGS="--inner-build-and-run"
if [ "$NO_BUILD" = "1" ]; then
    INNER_ARGS="$INNER_ARGS --no-build"
fi

echo "==> Delegating build+run to GPU container ($SCRIPT_DIR/run_gpu_container.sh)"
"$SCRIPT_DIR/run_gpu_container.sh" \
    "/work/source/build_scripts/$(basename "$0")" $INNER_ARGS

CPU_NC="$CPU_RUN/sfincs_map.nc"
GPU_NC="$GPU_RUN/sfincs_map.nc"

if [ ! -f "$CPU_NC" ] || [ ! -f "$GPU_NC" ]; then
    echo "ERROR: sfincs_map.nc missing in one of the run dirs:" >&2
    ls -la "$CPU_RUN" "$GPU_RUN" >&2
    exit 1
fi

# Compute max(|gpu - cpu|) / max(|cpu|) for each meteo field.
DIFF_OUT=$(python3 - "$CPU_NC" "$GPU_NC" "$TOL" <<'PY'
import sys
import numpy as np
from netCDF4 import Dataset

cpu_path, gpu_path, tol = sys.argv[1], sys.argv[2], float(sys.argv[3])

FIELDS = ['wind_u', 'wind_v', 'surface_air_pressure']

def load(p, name):
    with Dataset(p) as ds:
        return ds.variables[name][:]

worst = 0.0
all_pass = True
print(f"{'field':<28} {'shape':<20} {'max|cpu|':>12} {'max|diff|':>12} {'ratio':>12} {'pass':>6}")
for name in FIELDS:
    cpu = load(cpu_path, name)
    gpu = load(gpu_path, name)
    if cpu.shape != gpu.shape:
        print(f"FAIL shape mismatch {name} cpu={cpu.shape} gpu={gpu.shape}")
        sys.exit(2)
    cpu_mask = np.ma.getmaskarray(cpu)
    gpu_mask = np.ma.getmaskarray(gpu)
    combined = cpu_mask | gpu_mask
    cpu_d = np.array(np.ma.getdata(cpu), dtype=np.float64)
    gpu_d = np.array(np.ma.getdata(gpu), dtype=np.float64)
    cpu_m = np.ma.masked_array(cpu_d, mask=combined)
    gpu_m = np.ma.masked_array(gpu_d, mask=combined)
    diff = np.ma.abs(gpu_m - cpu_m)
    denom = float(np.ma.max(np.ma.abs(cpu_m)))
    maxd  = float(np.ma.max(diff))
    ratio = maxd / max(denom, 1e-12)
    worst = max(worst, ratio)
    field_pass = ratio < tol
    if not field_pass:
        all_pass = False
    print(f"{name:<28} {str(tuple(cpu.shape)):<20} {denom:>12.6e} {maxd:>12.6e} {ratio:>12.6e} {'PASS' if field_pass else 'FAIL':>6}")

print(f"worst ratio = {worst:.6e}  tol = {tol:.6e}")
sys.exit(0 if all_pass else 1)
PY
)
DIFF_RC=$?

echo "$DIFF_OUT"

CPU_WALL=$(cat "$CPU_RUN/sfincs.wallsec" 2>/dev/null || echo "?")
GPU_WALL=$(cat "$GPU_RUN/sfincs.wallsec" 2>/dev/null || echo "?")
echo "wall(CPU)   = ${CPU_WALL}s"
echo "wall(GPU)   = ${GPU_WALL}s"

if [ "$DIFF_RC" = "0" ]; then
    printf '\n==> PASS: every field below tol %s\n' "$TOL"
    exit 0
else
    printf '\n==> FAIL: at least one field exceeds tol %s\n' "$TOL" >&2
    exit 1
fi
