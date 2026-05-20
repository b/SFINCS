#!/usr/bin/env python3
"""4x-cell-count refinement for case_prod_compound_snapwave.

Doubles the quadtree base grid (130 -> 260 cells per axis) and halves
the base dx (200 m -> 100 m), keeping the physical footprint and the
3-level refinement / synthetic bathymetry / tidal boundary forcing /
SnapWave wave-spectrum forcing all inherited from the parent case. The
refined quadtree mesh ends up with ≈ 4x the active cell count of the 1x
case (≈ 103 k -> ≈ 411 k); the SnapWave wave grid shares the SFINCS
computational mesh, so it is refined in lockstep.

The case's existing ``generate.py`` already accepts ``--nmax`` /
``--mmax`` / ``--dx`` CLI args and calls into HydroMT-SFINCS, so this
wrapper is much thinner than the analytical-numpy 4x wrappers: it just
invokes ``generate.py`` with the refined arguments, then writes a
``sfincs.inp`` that matches the parent case's 1x file verbatim. The 1x
``sfincs.inp`` carries no ``mmax`` / ``nmax`` / ``dx`` / ``dy`` lines
(the quadtree mesh is loaded from ``qtrfile = sfincs.nc``), so no
per-axis rewriting is required — the refined mesh lives entirely in
``sfincs.nc``, and the tref / tstart / tstop / qtrfile / sbgfile /
bndfile / bzsfile / snapwave-* flags all carry over unchanged.

Usage (from the repo root):

    tests/cases/preprocessing/.venv/bin/python \
        tests/cases/case_prod_compound_snapwave/generate_4x_compound_snapwave.py

An optional positional argument overrides the default output directory
(``tests/cases/case_prod_compound_snapwave/4x/``):

    tests/cases/preprocessing/.venv/bin/python \
        tests/cases/case_prod_compound_snapwave/generate_4x_compound_snapwave.py \
        path/to/alt_out/

The script is idempotent: re-running on an existing 4x dir overwrites
every generated file deterministically (the parent generator uses no
RNG).

Pattern mirrors tests/cases/case_prod_quadtree_subgrid_tide/
generate_4x_quadtree_subgrid_tide.py.
"""

import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CASE_GEN = HERE / "generate.py"
ONE_X_INP = HERE / "sfincs.inp"

NMAX_4X = 260
MMAX_4X = 260
DX_4X = 100.0


def main():
    if len(sys.argv) > 2:
        print(
            "usage: generate_4x_compound_snapwave.py [out_dir]",
            file=sys.stderr,
        )
        sys.exit(2)
    out_dir = Path(sys.argv[1]).resolve() if len(sys.argv) == 2 else (HERE / "4x").resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    cmd = [
        sys.executable,
        str(CASE_GEN),
        "--nmax", str(NMAX_4X),
        "--mmax", str(MMAX_4X),
        "--dx", f"{DX_4X}",
        "--out", str(out_dir),
    ]
    print(f"invoking parent generator: {' '.join(cmd)}")
    subprocess.run(cmd, check=True)

    # The parent generate.py writes sfincs.nc / sfincs_subgrid.nc /
    # sfincs.bnd / sfincs.bzs / snapwave.{bnd,bhs,btp,bwd,bds} but no
    # sfincs.inp. Copy the 1x sfincs.inp verbatim — it carries
    # qtrfile/sbgfile/bndfile/bzsfile + the snapwave_* flags + tref /
    # tstart / tstop + dtwave, and has no grid-axis settings (the
    # quadtree mesh is loaded from qtrfile = sfincs.nc).
    dst_inp = out_dir / "sfincs.inp"
    shutil.copyfile(ONE_X_INP, dst_inp)
    print(f"wrote {dst_inp} (copied from {ONE_X_INP})")

    generated = [
        "sfincs.inp",
        "sfincs.nc",
        "sfincs_subgrid.nc",
        "sfincs.bnd",
        "sfincs.bzs",
        "snapwave.bnd",
        "snapwave.bhs",
        "snapwave.btp",
        "snapwave.bwd",
        "snapwave.bds",
    ]
    print("4x dir ready:")
    for name in generated:
        size = (out_dir / name).stat().st_size
        if size > 1e6:
            print(f"  {name:18s} {size / 1e6:8.2f} MB")
        else:
            print(f"  {name:18s} {size:8d} B")


if __name__ == "__main__":
    main()
