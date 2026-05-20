# case_prod_storm_amuv — 4x grid refinement

A 4x-cell-count refinement of the parent
[`case_prod_storm_amuv`](../README.md) case. The 1x mesh is 400 × 400 cells
at `dx = dy = 50` m; this 4x variant doubles `mmax` / `nmax` to 800 each
and halves `dx` / `dy` to 25 m, keeping the physical footprint at
20 km × 20 km. Active z points rise from 160 000 to 640 000 (4×).

Every physical-space parameter (boundary support y-coordinates, M2 + M4
tide amplitudes and periods, storm-surge ramp, precipitation pulse, wind
front + meridional gradient, two-zone Green-Ampt soil layout, time
window) is inherited from the parent case unchanged — only the grid
resolution differs. This isolates resolution as the independent axis
along which the perf-scaling sweep traverses the case.

The wind grid (`sfincs.amu` / `sfincs.amv`) is 41 × 41 at 500 m spacing
for both 1x and 4x: the model footprint is unchanged, so the meteo grid
needs no refinement at this resolution step.

## Pinned HydroMT-SFINCS version

The 4x generator inherits the preprocessing environment pinned in
[`tests/cases/preprocessing`](../../preprocessing/README.md):

| Field | Value |
| --- | --- |
| Git SHA | `d8514d644f297b6b3982c249c3c233dfdf5076fb` |
| Date | 2026-04-22 |
| Subject | `Simplify linestring2gdf, drop elevation handling (#374)` |
| Upstream | https://github.com/Deltares/hydromt_sfincs |
| Package version | `2.0.0-rc2` |

The storm_amuv generator is purely analytical (no DEM ingest, no
upstream raster read — see `generate.py`'s `make_bathymetry()` /
`make_wind_u_fields()` / `make_green_ampt_rasters()`), so the
HydroMT-SFINCS package itself is not exercised at runtime for this
case. The pin is recorded here so the preprocessing environment
remains the single source of truth across all 4x cases.

## Source data

The 4x dir is fully derived from the parent case's `generate.py`
module-level constants. There are no external inputs:

- **Grid constants** monkey-patched by `generate_4x_storm_amuv.py`:
  - `MMAX = 800` (was 400)
  - `NMAX = 800` (was 400)
  - `DX = 25.0` (was 50.0)
  - `DY = 25.0` (was 50.0)
- **Inherited as-is** from `generate.py`: `X0`, `Y0`, `SIM_HOURS`,
  M2 / M4 tide amplitudes and periods, storm-surge amplitude / centre
  / sigma, precipitation peak rate / centre / half-width, wind
  grid dimensions (`WIND_NCOLS`, `WIND_NROWS`) and snapshot times
  (`WIND_TIMES_HOURS`), wind-field shape parameters (background ramp,
  tanh front transition, meridional sin amplitudes), and the two-zone
  Green-Ampt parameter values (`psi_sandy` / `psi_clay`,
  `sigma_sandy` / `sigma_clay`, `ks_sandy` / `ks_clay`) plus the wavy
  soil-boundary shape.

The generator contains no RNG, so the 4x output is bit-stable across
re-runs.

## Regenerate

From the SFINCS repo root:

```bash
tests/cases/preprocessing/.venv/bin/python \
    tests/cases/case_prod_storm_amuv/generate_4x_storm_amuv.py \
    tests/cases/case_prod_storm_amuv/4x/
```

The generator is idempotent — re-running on the existing 4x dir
overwrites every output file byte-for-byte identically. The output
directory is created if absent.

Bootstrap the preprocessing venv with
[`tests/cases/preprocessing/setup.sh`](../../preprocessing/README.md)
if it is not yet present. The script depends only on `numpy`, so the
system Python 3 also works if the preprocessing venv is unavailable.

## Files

| File | Description |
| --- | --- |
| `sfincs.inp` | Run configuration: `mmax = nmax = 800`, `dx = dy = 25`, `tstart = 20200101 000000`, `tstop = 20200102 000000`. All other settings inherited from the 1x case. |
| `sfincs.dep` | ASCII bathymetry, 800 × 800 cells. |
| `sfincs.msk` | ASCII mask, 800 × 800; west column = open boundary (`kcs = 2`), interior `kcs = 1`. |
| `sfincs.bnd` | Three boundary support points along the western edge (unchanged from 1x). |
| `sfincs.bzs` | M2 + M4 + storm-surge boundary water-level time series, 49 samples over 24 h (unchanged from 1x). |
| `sfincs.prcp` | Triangular precipitation pulse peaking at 12 h, 49 samples (unchanged from 1x). |
| `sfincs.amu` | Delft3D-style equidistant-grid x-wind, 41 × 41 × 7 (unchanged from 1x). |
| `sfincs.amv` | Delft3D-style equidistant-grid y-wind, 41 × 41 × 7 (unchanged from 1x). |
| `sfincs.psi` | Green-Ampt suction head [mm], binary float32 stream, 640 000 entries (~2.5 MB). |
| `sfincs.sigma` | Green-Ampt max moisture deficit [-], binary float32 stream, 640 000 entries (~2.5 MB). |
| `sfincs.ks` | Green-Ampt saturated conductivity [mm/hr], binary float32 stream, 640 000 entries (~2.5 MB). |
