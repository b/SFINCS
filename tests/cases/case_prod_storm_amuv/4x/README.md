# case_prod_storm_amuv — 4x grid refinement

A 4x-cell-count refinement of the parent
[`case_prod_storm_amuv`](../README.md) case. The 1x mesh is 400 × 400
cells at `dx = dy = 50` m; this 4x variant doubles `mmax` / `nmax` to
800 each and halves `dx` / `dy` to 25 m, keeping the physical footprint
at 20 km × 20 km. Active cells rise from 160 000 to 640 000 (4×).

Every physical-space parameter (boundary support points, M2 + M4 tide
amplitudes, storm-surge pulse, triangular precipitation pulse,
drifting tanh wind front in `amu`, meridional sinusoidal pattern in
`amv`, two-zone Green-Ampt soil rasters with wavy boundary, time
window) is inherited from the parent case unchanged — only the grid
resolution differs. This isolates resolution as the independent axis
along which the perf-scaling sweep traverses the case.

The wind grid (`sfincs.amu` / `sfincs.amv`) is an equidistant 41 × 41
meteo grid whose spacing is independent of the SFINCS mesh; with the
footprint preserved, the wind file is identical in shape (and value)
across 1x and 4x.

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
  M2 / M4 tide amplitudes and periods, storm-surge amplitude / centre /
  width, precipitation peak rate / centre / half-width, wind grid
  size (`WIND_NCOLS = WIND_NROWS = 41`) and wind time snapshots,
  wind-front kinematics, Green-Ampt zone parameters (`psi_sandy`,
  `psi_clay`, `sigma_sandy`, `sigma_clay`, `ks_sandy`, `ks_clay`)
  and the wavy zone boundary.

The generator is deterministic (no RNG seeds in this case), so the
4x output is bit-stable across re-runs.

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
if it is not yet present. (The storm_amuv generator only needs
`numpy`, so a system Python with NumPy installed works in a pinch.)

## Files

| File | Description |
| --- | --- |
| `sfincs.inp` | Run configuration: `mmax = nmax = 800`, `dx = dy = 25`, `tstart = 20200101 000000`, `tstop = 20200102 000000`. All other settings inherited from the 1x case. |
| `sfincs.dep` | ASCII bathymetry, 800 × 800 cells (west-to-east linear ramp from −8 m to +2 m). |
| `sfincs.msk` | ASCII mask, 800 × 800; west column = water-level boundary (`msk = 2`), interior `msk = 1`. |
| `sfincs.bnd` | Three boundary support points at x = 0, y ∈ {0, 10 000, 19 975} m. |
| `sfincs.bzs` | M2 + M4 + storm-surge boundary water-level time series, 49 samples over 24 h (unchanged from 1x). |
| `sfincs.prcp` | Triangular precipitation pulse, 49 samples (unchanged from 1x). |
| `sfincs.amu` | Delft3D-style equidistant-grid x-wind, 41 × 41 grid × 7 snapshots (identical to 1x — wind grid is footprint-anchored, not mesh-anchored). |
| `sfincs.amv` | Delft3D-style equidistant-grid y-wind, 41 × 41 grid × 7 snapshots (identical to 1x — see above). |
| `sfincs.psi` | Green-Ampt suction head [mm], binary float32 stream, 640 000 active cells × 4 B = 2 560 000 B. |
| `sfincs.sigma` | Green-Ampt max moisture deficit, binary float32 stream, 640 000 × 4 B = 2 560 000 B. |
| `sfincs.ks` | Green-Ampt saturated conductivity [mm/hr], binary float32 stream, 640 000 × 4 B = 2 560 000 B. |
