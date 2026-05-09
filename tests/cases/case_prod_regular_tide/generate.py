#!/usr/bin/env python3
"""Deterministic generator for case_prod_regular_tide inputs.

Re-running this script produces byte-identical sfincs.dep / sfincs.msk /
sfincs.bnd / sfincs.bzs in the same directory. The generator takes no
parameters and reads no environment; the dimensions, bathymetry shape,
mask layout, and tidal forcing constants are all hard-coded below so the
case is reproducible from this file alone.

Layout:

  500 x 500 regular grid at 50 m spacing (25 km x 25 km footprint),
  origin at (x0, y0) = (0, 0), no rotation. Bathymetry is a linear
  west-to-east ramp from -10 m to +5 m with a single 2D Gaussian dip
  (-2 m at the centre, sigma = 50 cells) so the field is not perfectly
  linear. Mask: western column = 2 (water-level boundary), eastern
  column = 0 (dry land strip), interior = 1 (active). Boundary forcing
  is the sum of M2 (period 12.4206 h, amplitude 1.0 m), M4 (period
  6.2103 h, amplitude 0.25 m) and a +0.3 m mean sea-level constant,
  identical at both bnd support points, sampled every 600 s over 24 h.

The active wet-cell count is roughly 333 cols x 500 rows ~= 166 500
cells (the western 333 columns sit below MSL after the ramp + bump),
comfortably above the >= 100 000 production-scale bar.
"""

import os

import numpy as np


NMAX = 500          # rows (n direction)
MMAX = 500          # cols (m direction)
DX = 50.0
DY = 50.0
X0 = 0.0
Y0 = 0.0

ZB_WEST = -10.0
ZB_EAST = 5.0
BUMP_AMP = -2.0
BUMP_SIGMA_CELLS = 50.0

M2_PERIOD = 12.4206 * 3600.0   # 44 714.16 s
M4_PERIOD = 6.2103 * 3600.0    # 22 357.08 s
M2_AMP = 1.0
M4_AMP = 0.25
SLR = 0.3

DT_BZS = 600.0
T_END = 86400.0


def main():
    here = os.path.dirname(os.path.abspath(__file__))

    m = np.arange(1, MMAX + 1, dtype=np.float64)
    n = np.arange(1, NMAX + 1, dtype=np.float64)
    M, N = np.meshgrid(m, n, indexing="xy")  # shape (NMAX, MMAX)

    ramp = ZB_WEST + (ZB_EAST - ZB_WEST) * (M - 1.0) / (MMAX - 1.0)
    bump = BUMP_AMP * np.exp(
        -((M - MMAX / 2.0) ** 2 + (N - NMAX / 2.0) ** 2)
        / (2.0 * BUMP_SIGMA_CELLS ** 2)
    )
    zb = (ramp + bump).astype(np.float64)

    msk = np.ones((NMAX, MMAX), dtype=np.int8)
    msk[:, 0] = 2
    msk[:, MMAX - 1] = 0

    bnd = [
        (X0, Y0),
        (X0, Y0 + (NMAX - 1) * DY),
    ]

    t = np.arange(0.0, T_END + 0.5 * DT_BZS, DT_BZS)
    zs = (
        M2_AMP * np.cos(2.0 * np.pi * t / M2_PERIOD)
        + M4_AMP * np.cos(2.0 * np.pi * t / M4_PERIOD)
        + SLR
    )

    with open(os.path.join(here, "sfincs.dep"), "w") as f:
        for row in zb:
            f.write(" ".join(f"{v:9.4f}" for v in row) + "\n")

    with open(os.path.join(here, "sfincs.msk"), "w") as f:
        for row in msk:
            f.write(" ".join(str(int(v)) for v in row) + "\n")

    with open(os.path.join(here, "sfincs.bnd"), "w") as f:
        for x, y in bnd:
            f.write(f"{x:.1f} {y:.1f}\n")

    with open(os.path.join(here, "sfincs.bzs"), "w") as f:
        for ti, zsi in zip(t, zs):
            f.write(f"{ti:9.1f}  {zsi:8.4f}  {zsi:8.4f}\n")

    n_active = int(np.sum(msk > 0))
    n_wet = int(np.sum((msk > 0) & (zb < 0.0)))
    print(
        f"Wrote sfincs.dep ({MMAX} x {NMAX}), sfincs.msk, sfincs.bnd "
        f"({len(bnd)} pts), sfincs.bzs ({len(t)} samples)"
    )
    print(f"Active cells (msk > 0): {n_active}")
    print(f"Initial wet active cells (msk > 0 and zb < 0): {n_wet}")


if __name__ == "__main__":
    main()
