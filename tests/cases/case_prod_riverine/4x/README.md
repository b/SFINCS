# case_prod_riverine — 4x grid refinement

A 4x-cell-count refinement of the parent
[`case_prod_riverine`](../README.md) case. The 1x mesh is 400 × 400 cells
at `dx = dy = 50` m; this 4x variant doubles `mmax` / `nmax` to 800 each
and halves `dx` / `dy` to 25 m, keeping the physical footprint at
20 km × 20 km. Active z points rise from 160 000 to 640 000 (4×).

Every physical-space parameter (channel half-width, CN-zone x-bounds,
source / weir / boundary coordinates, time window, forcing amplitudes)
is inherited from the parent case unchanged — only the grid resolution
differs. This isolates resolution as the independent axis along which
the perf-scaling sweep traverses the case.

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

The riverine generator is purely analytical (no DEM ingest, no upstream
raster read — see `generate.py`'s `build_bathymetry()` / `build_scs()`),
so the HydroMT-SFINCS package itself is not exercised at runtime for
this case. The pin is recorded here so the preprocessing environment
remains the single source of truth across all 4x cases.

## Source data

The 4x dir is fully derived from the parent case's `generate.py`
module-level constants. There are no external inputs:

- **Grid constants** monkey-patched by `generate_4x_riverine.py`:
  - `MMAX = 800` (was 400)
  - `NMAX = 800` (was 400)
  - `DX = 25.0` (was 50.0)
  - `DY = 25.0` (was 50.0)
- **Inherited as-is** from `generate.py`: `X0`, `Y0`, `ROTATION`,
  `BND_Y_M`, M2 / M4 tide amplitudes and periods, `SEA_LEVEL_M`,
  `BND_DT_S`, source / discharge coordinates, hydrograph values,
  weir polyline + crest + Cd, CN zones, precipitation pulse, the time
  window (`T_REF_STR` / `T_START_STR` / `T_STOP_STR` / `SIM_LEN_S`),
  and the fixed RNG seeds (`20260509` for bathymetry roughness,
  `20260510` for boundary phase offsets).

Both seeds are honoured by the refined run, so the 4x bathymetry's
±5 cm roughness and the 4x boundary phase offsets are deterministic
across re-runs.

## Regenerate

From the SFINCS repo root:

```bash
tests/cases/preprocessing/.venv/bin/python \
    tests/cases/case_prod_riverine/generate_4x_riverine.py \
    tests/cases/case_prod_riverine/4x/
```

The generator is idempotent — re-running on the existing 4x dir
overwrites every output file byte-for-byte identically. The output
directory is created if absent.

Bootstrap the preprocessing venv with
[`tests/cases/preprocessing/setup.sh`](../../preprocessing/README.md)
if it is not yet present.

## Files

| File | Description |
| --- | --- |
| `sfincs.inp` | Run configuration: `mmax = nmax = 800`, `dx = dy = 25`, `tstart = 20200101 000000`, `tstop = 20200102 000000`. All other settings inherited from the 1x case. |
| `sfincs.dep` | ASCII bathymetry, 800 × 800 cells. |
| `sfincs.msk` | ASCII mask, 800 × 800; west column = open boundary (`kcs = 2`), interior `kcs = 1`. |
| `sfincs.bnd` | Three boundary support points at x = 0, y ∈ {2 500, 10 000, 17 500} m (unchanged from 1x). |
| `sfincs.bzs` | M2 + M4 + sea-level boundary water-level time series, 49 samples over 24 h (unchanged from 1x). |
| `sfincs.src` | One source point at (19 725, 10 000) m (unchanged from 1x). |
| `sfincs.dis` | Stepped hydrograph (unchanged from 1x). |
| `sfincs.weir` | Weir polyline crossing the river midway (unchanged from 1x). |
| `sfincs.scs` | SCS Curve Number method-A retention raster, 640 000 × float32 (4× the 1x raster). |
| `sfincs.prcp` | Uniform precipitation pulse (unchanged from 1x). |
