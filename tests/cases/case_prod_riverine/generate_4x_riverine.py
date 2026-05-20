#!/usr/bin/env python3
"""4x-cell-count refinement for case_prod_riverine.

Doubles NMAX and MMAX (so the cell count is 4x) and halves DX and DY,
keeping the physical footprint at 20 km x 20 km. The bathymetry shape
(east-west ramp + y=10 000 m river trough + deterministic noise), the
mask layout (western column open boundary), the M2+M4+sea-level tide
forcing on the boundary, the upstream stepped hydrograph, the weir
polyline, the SCS-CN retention raster, and the precipitation pulse
are all preserved — only the grid is refined. The refined case is
written into a 4x/ subdirectory passed on argv:

    generate_4x_riverine.py tests/cases/case_prod_riverine/4x/

Re-running cleanly overwrites the destination (idempotent — the case
uses fixed RNG seeds, so the binary output is bit-stable across runs).

Importing and monkey-patching the case's generate.py keeps the
bathymetry / forcing math one source of truth; the constants we
override are NMAX, MMAX, DX, DY only. Physical-space parameters
(channel half-width, CN-zone x-bounds, source/weir/boundary coords,
time window) are inherited as-is so the physical setup at 4x matches
1x exactly — just resolved on a finer grid.

Pattern mirrors tests/perf/perf-scaling-sweep-20260519-post-sor1019/
generate_4x_regular_tide.py.
"""

import importlib.util
import os
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
CASE_GEN = HERE / "generate.py"
CASE_INP = HERE / "sfincs.inp"


def load_generator():
    spec = importlib.util.spec_from_file_location("riverine_gen", CASE_GEN)
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
        print("usage: generate_4x_riverine.py <out_dir>", file=sys.stderr)
        sys.exit(2)
    out_dir = Path(sys.argv[1]).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    gen = load_generator()

    # Monkey-patch only the grid constants. Physical-space parameters
    # (channel half_width, CN-zone x-bounds, src/weir/bnd coords, time
    # window) are inherited so the physical setup at 4x is identical
    # to 1x — only the grid resolution doubles in each axis.
    gen.MMAX = gen.MMAX * 2          # 400 -> 800
    gen.NMAX = gen.NMAX * 2          # 400 -> 800
    gen.DX = gen.DX / 2.0            # 50.0 -> 25.0
    gen.DY = gen.DY / 2.0            # 50.0 -> 25.0

    zb = gen.build_bathymetry()
    msk = gen.build_mask()
    scs = gen.build_scs(msk)

    n_steps = int(np.ceil(gen.SIM_LEN_S / gen.BND_DT_S)) + 1
    times_s = np.arange(n_steps, dtype=np.float64) * gen.BND_DT_S
    z_bnd = gen.build_bzs(times_s)

    gen.write_grid_ascii(out_dir / "sfincs.dep", zb, "{:.4f}")
    gen.write_grid_ascii(out_dir / "sfincs.msk", msk, "{:d}")
    gen.write_bnd(out_dir / "sfincs.bnd")
    gen.write_bzs(out_dir / "sfincs.bzs", times_s, z_bnd)
    gen.write_src(out_dir / "sfincs.src")
    gen.write_dis(out_dir / "sfincs.dis")
    gen.write_weir(out_dir / "sfincs.weir")
    gen.write_scs(out_dir / "sfincs.scs", scs)
    gen.write_prcp(out_dir / "sfincs.prcp")

    rewrite_inp(CASE_INP, out_dir / "sfincs.inp", gen.MMAX, gen.NMAX, gen.DX, gen.DY)

    n_active = int((msk > 0).sum())
    print(f"grid             : {gen.NMAX} rows x {gen.MMAX} cols at {gen.DX:g} m")
    print(f"active z points  : {n_active}")
    print(f"bzs samples      : {len(times_s)} over {gen.SIM_LEN_S/3600:.1f} h")
    print(f"scs raster size  : {scs.size} x float32 = {scs.nbytes} bytes")
    print(f"written to       : {out_dir}")


if __name__ == "__main__":
    main()
