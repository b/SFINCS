#!/usr/bin/env python3
"""4x-cell-count refinement for case_prod_storm_amuv.

Doubles NMAX and MMAX (so the cell count is 4x) and halves DX and DY,
keeping the physical footprint at 20 km x 20 km. The bathymetry ramp
(west deep / east shallow), the mask layout (msk=2 western column,
msk=1 interior), the M2+M4+storm-surge boundary forcing, the
triangular precipitation pulse, the drifting tanh wind front in amu,
the meridional sinusoidal pattern in amv, and the two-zone Green-Ampt
soil rasters (psi / sigma / ks) are all preserved — only the SFINCS
grid is refined. Active cell count rises from 160 000 to 640 000.

The refined case is written into the output directory passed on argv:

    generate_4x_storm_amuv.py tests/cases/case_prod_storm_amuv/4x/

Re-running cleanly overwrites the destination (idempotent — the case
generator is purely analytical, so the output is bit-stable across
re-runs).

Importing and monkey-patching the case's generate.py keeps the
bathymetry / forcing math one source of truth; the constants we
override are NMAX, MMAX, DX, DY only. The wind grid spacing
(WIND_DX / WIND_DY = (MMAX * DX) / (WIND_NCOLS - 1)) is frozen at
module-load time using the 1x constants; since MMAX * DX and
NMAX * DY are footprint-invariant under the refinement, the wind
grid resolution is identical at 1x and 4x — the AC for this issue
calls this out explicitly.

Pattern mirrors tests/perf/perf-scaling-sweep-20260519-post-sor1019/
generate_4x_regular_tide.py and tests/cases/case_prod_riverine/
generate_4x_riverine.py.
"""

import importlib.util
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CASE_GEN = HERE / "generate.py"
CASE_INP = HERE / "sfincs.inp"


def load_generator():
    spec = importlib.util.spec_from_file_location("storm_amuv_gen", CASE_GEN)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def rewrite_inp(src_inp: Path, dst_inp: Path, mmax: int, nmax: int, dx: float, dy: float) -> None:
    """Copy src_inp to dst_inp, replacing only mmax/nmax/dx/dy lines."""
    text = src_inp.read_text().splitlines(keepends=True)
    out = []
    for line in text:
        key = line.split("=", 1)[0].strip() if "=" in line else ""
        if key == "mmax":
            out.append(f"mmax              = {mmax}\n")
        elif key == "nmax":
            out.append(f"nmax              = {nmax}\n")
        elif key == "dx":
            out.append(f"dx                = {dx:.1f}\n")
        elif key == "dy":
            out.append(f"dy                = {dy:.1f}\n")
        else:
            out.append(line)
    dst_inp.write_text("".join(out))


def main():
    if len(sys.argv) != 2:
        print("usage: generate_4x_storm_amuv.py <out_dir>", file=sys.stderr)
        sys.exit(2)
    out_dir = Path(sys.argv[1]).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    gen = load_generator()

    # Monkey-patch only the grid constants. Physical-space parameters
    # (X0/Y0, time window, tide amplitudes, surge profile, precip pulse,
    # wind front kinematics, Green-Ampt zone parameters) are inherited
    # so the physical setup at 4x is identical to 1x — only the grid
    # resolution doubles in each axis.
    gen.MMAX = gen.MMAX * 2          # 400 -> 800
    gen.NMAX = gen.NMAX * 2          # 400 -> 800
    gen.DX = gen.DX / 2.0            # 50.0 -> 25.0
    gen.DY = gen.DY / 2.0            # 50.0 -> 25.0

    z = gen.make_bathymetry()
    msk = gen.make_mask()

    gen.write_dep(out_dir / "sfincs.dep", z)
    gen.write_msk(out_dir / "sfincs.msk", msk)

    bnd = gen.make_boundary_points()
    gen.write_bnd(out_dir / "sfincs.bnd", bnd)
    bzs_t, bzs_zs = gen.make_boundary_timeseries()
    gen.write_bzs(out_dir / "sfincs.bzs", bzs_t, bzs_zs, ncols=len(bnd))

    prcp_t, prcp_rate = gen.make_precip_timeseries()
    gen.write_prcp(out_dir / "sfincs.prcp", prcp_t, prcp_rate)

    u_fields = gen.make_wind_u_fields()
    v_fields = gen.make_wind_v_fields()
    gen.write_amuv(out_dir / "sfincs.amu", u_fields, "x_wind", "m s-1")
    gen.write_amuv(out_dir / "sfincs.amv", v_fields, "y_wind", "m s-1")

    psi, sigma, ks = gen.make_green_ampt_rasters(msk)
    gen.write_binary_stream(out_dir / "sfincs.psi", psi, msk)
    gen.write_binary_stream(out_dir / "sfincs.sigma", sigma, msk)
    gen.write_binary_stream(out_dir / "sfincs.ks", ks, msk)

    rewrite_inp(CASE_INP, out_dir / "sfincs.inp", gen.MMAX, gen.NMAX, gen.DX, gen.DY)

    n_active = int((msk > 0).sum())
    print(f"grid             : {gen.NMAX} rows x {gen.MMAX} cols at {gen.DX:g} m")
    print(f"active cells     : {n_active}")
    print(f"bzs samples      : {len(bzs_t)} over {gen.SIM_HOURS:.1f} h")
    print(f"binary stream    : {n_active} x float32 = {n_active * 4} bytes each (psi/sigma/ks)")
    print(f"written to       : {out_dir}")


if __name__ == "__main__":
    main()
