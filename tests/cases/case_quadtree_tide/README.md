# case_quadtree_tide

A small, self-contained SFINCS test case that exercises the quadtree-mesh
code path under a single semidiurnal tide, isolating quadtree refinement
from the other GPU-ported subsystems (no subgrid, no spiderweb meteo, no
infiltration, no structures, no SnapWave).

## Layout

- `sfincs.nc` — quadtree mesh file (the file SFINCS reads via `qtrfile`).
  Contains 4452 cells over a 23x63 base grid at 200 m spacing, rotated
  27 degrees, with three quadtree levels (one nested refinement region).
  Bathymetry ranges from -8.66 m to +10.72 m. Coordinates are EPSG:32633
  (WGS 84 / UTM zone 33N).
- `sfincs.bnd` — two boundary support points spanning the open boundary.
- `sfincs.bzs` — single semidiurnal M2 tide (period 12.4206 h, amplitude
  0.5 m), sampled every 30 minutes for 24 h, applied identically at both
  support points.
- `sfincs.inp` — 24-hour run, no subgrid / spiderweb / infiltration /
  structures / SnapWave; activates the quadtree path via `qtrfile`.

## Origin of `sfincs.nc`

The mesh file is vendored verbatim from the HydroMT-SFINCS test fixture
`tests/data/sfincs_test_quadtree/sfincs.nc`
(https://github.com/Deltares/hydromt_sfincs, GPL-3.0). The forcing files
(`sfincs.bnd`, `sfincs.bzs`) and the run configuration (`sfincs.inp`)
are written from scratch for this validation harness; they intentionally
do not match the upstream fixture, which couples subgrid + SnapWave and is
not what we want to validate here.

## Running

The case is invoked by the GPU-vs-CPU validation harness in `tests/`. The
SFINCS executable reads `sfincs.inp` from the current working directory,
so the harness `cd`s into a per-run directory after copying these inputs.
