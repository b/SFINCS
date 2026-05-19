#!/usr/bin/env python3
"""4x-cell-count refinement for case_prod_regular_tide.

Doubles NMAX and MMAX (so the cell count is 4x) and halves DX and DY,
keeping the physical footprint at 25 km x 25 km. The bathymetry shape
(west-east ramp + central Gaussian dip), the mask layout (western
column boundary, eastern column dry), and the M2+M4+SLR tide forcing
are all preserved — only the grid is refined. The refined case is
written into the run dir passed on argv, replacing whichever
1x-grid copies are already there (sfincs.dep / sfincs.msk / sfincs.bnd
/ sfincs.bzs / sfincs.inp).

Run dir is expected to already contain a writable sfincs.inp (from
stage_case in run_perf_scaling.sh). The script edits mmax / nmax /
dx / dy lines in place and rewrites the other artifacts.

Importing and monkey-patching the case's generate.py keeps the
bathymetry / forcing math one source of truth; the constants we
override are NMAX, MMAX, DX, DY only.
"""

import importlib.util
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
CASE_GEN = REPO_ROOT / "tests/cases/case_prod_regular_tide/generate.py"


def load_generator():
    spec = importlib.util.spec_from_file_location("regular_tide_gen", CASE_GEN)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def rewrite_inp(run_dir: Path, mmax: int, nmax: int, dx: float, dy: float) -> None:
    inp = run_dir / "sfincs.inp"
    text = inp.read_text().splitlines(keepends=True)
    out = []
    for line in text:
        key = line.strip().split("=", 1)[0].strip() if "=" in line else ""
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
    inp.write_text("".join(out))


def main():
    if len(sys.argv) != 2:
        print("usage: generate_4x_regular_tide.py <run_dir>", file=sys.stderr)
        sys.exit(2)
    run_dir = Path(sys.argv[1]).resolve()
    if not (run_dir / "sfincs.inp").is_file():
        print(f"ERROR: {run_dir}/sfincs.inp not found", file=sys.stderr)
        sys.exit(3)

    gen = load_generator()
    # Replace 1x symlinks (if any) with real, writable files about
    # to be overwritten. stage_case() symlinks dep/msk/bnd/bzs to the
    # 1x case dir; unlink them so the 4x writer doesn't follow the
    # symlink and corrupt the source-of-truth.
    for fname in ("sfincs.dep", "sfincs.msk", "sfincs.bnd", "sfincs.bzs"):
        f = run_dir / fname
        if f.is_symlink() or f.exists():
            f.unlink()

    nmax = gen.NMAX * 2
    mmax = gen.MMAX * 2
    dx = gen.DX / 2.0
    dy = gen.DY / 2.0
    # Monkey-patch and call main() with `here` redirected to the
    # run dir by chdir'ing — the generator writes to dirname(__file__)
    # which we cannot easily change, but it always uses os.path.dirname(
    # os.path.abspath(__file__)) which IS the source case dir. The
    # generator's main() builds paths via os.path.join(here, ...).
    # Easiest override: temporarily replace abspath so __file__ points
    # at our run_dir.
    gen.NMAX = nmax
    gen.MMAX = mmax
    gen.DX = dx
    gen.DY = dy
    # generate.py's main() does:
    #   here = os.path.dirname(os.path.abspath(__file__))
    # We can't trivially intercept __file__, but we can override
    # main() to write into run_dir directly. Reproduce its body here
    # against the patched constants — kept short and matches the
    # generator's structure exactly.
    import numpy as np

    NMAX, MMAX = gen.NMAX, gen.MMAX
    DX, DY = gen.DX, gen.DY
    X0, Y0 = gen.X0, gen.Y0
    BUMP_SIGMA_CELLS = gen.BUMP_SIGMA_CELLS * 2.0  # scales with NMAX/MMAX

    m = np.arange(1, MMAX + 1, dtype=np.float64)
    n = np.arange(1, NMAX + 1, dtype=np.float64)
    M, N = np.meshgrid(m, n, indexing="xy")

    ramp = gen.ZB_WEST + (gen.ZB_EAST - gen.ZB_WEST) * (M - 1.0) / (MMAX - 1.0)
    bump = gen.BUMP_AMP * np.exp(
        -((M - MMAX / 2.0) ** 2 + (N - NMAX / 2.0) ** 2)
        / (2.0 * BUMP_SIGMA_CELLS ** 2)
    )
    zb = (ramp + bump).astype(np.float64)

    msk = np.ones((NMAX, MMAX), dtype=np.int8)
    msk[:, 0] = 2
    msk[:, MMAX - 1] = 0

    bnd = [(X0, Y0), (X0, Y0 + (NMAX - 1) * DY)]

    t = np.arange(0.0, gen.T_END + 0.5 * gen.DT_BZS, gen.DT_BZS)
    zs = (
        gen.M2_AMP * np.cos(2.0 * np.pi * t / gen.M2_PERIOD)
        + gen.M4_AMP * np.cos(2.0 * np.pi * t / gen.M4_PERIOD)
        + gen.SLR
    )

    with open(run_dir / "sfincs.dep", "w") as f:
        for row in zb:
            f.write(" ".join(f"{v:9.4f}" for v in row) + "\n")
    with open(run_dir / "sfincs.msk", "w") as f:
        for row in msk:
            f.write(" ".join(str(int(v)) for v in row) + "\n")
    with open(run_dir / "sfincs.bnd", "w") as f:
        for x, y in bnd:
            f.write(f"{x:.1f} {y:.1f}\n")
    with open(run_dir / "sfincs.bzs", "w") as f:
        for ti, zsi in zip(t, zs):
            f.write(f"{ti:9.1f}  {zsi:8.4f}  {zsi:8.4f}\n")

    rewrite_inp(run_dir, mmax, nmax, dx, dy)

    n_active = int((msk > 0).sum())
    print(f"4x-refined case in {run_dir}: {MMAX}x{NMAX} cells, dx={DX} ({n_active} active)")


if __name__ == "__main__":
    main()
