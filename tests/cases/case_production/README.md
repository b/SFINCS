# case_production

A production-style SFINCS validation case for the GPU-vs-CPU validation
harness. The case is too large to vendor in-tree, so this directory
ships a `fetch.sh` script that downloads, verifies, and extracts the
archive on first run.

The case combines all five major SFINCS subsystems we want to exercise
together: subgrid topography, quadtree mesh refinement, spiderweb
tropical-cyclone meteo, spatially-varying infiltration, and weir-style
structures.

## Upstream

- **Archive URL.** <https://github.com/b/SFINCS/releases/download/case-production-v1/case_production.tar.gz>
- **Archive SHA256.** `5fff1bfd20940a3723f75e2c4c99de66d431e173f45556c7e3f3e86eefd7b6fc`
- **Release page.** <https://github.com/b/SFINCS/releases/tag/case-production-v1>

The release is hosted on the same fork that ships this validation
harness, alongside the source code that consumes it. Hosting on a fork
release (not a personal cloud bucket) gives a stable, license-compliant
URL that anyone with a GitHub account can audit.

## Provenance and license

The archive bundles three classes of files:

1. **Verbatim from HydroMT-SFINCS test fixtures**
   ([Deltares/hydromt_sfincs](https://github.com/Deltares/hydromt_sfincs),
   GPL-3.0):
   - `sfincs.nc` — quadtree mesh from
     `tests/data/sfincs_test_quadtree/sfincs.nc`.
   - `sfincs_subgrid.nc` — subgrid lookup tables from
     `tests/data/sfincs_test_quadtree/sfincs_subgrid.nc`.
   - `sfincs.bnd` — open-boundary support points from the same fixture.

2. **Authored for this harness:**
   - `sfincs.bzs` — synthetic 24 h water-level time series at the two
     boundary support points (semi-diurnal-style two-peak pattern,
     amplitude up to 1.0 m).
   - `sfincs.spw` — Delft3D-style ASCII spiderweb file containing a
     synthetic Holland-vortex tropical-cyclone wind/pressure pattern
     drifting east-to-west across the model footprint (12 radial bins,
     36 azimuthal bins, 200 km radius, 5 timesteps over 24 h).
   - `sfincs.qinf` — binary `qinffile` (4452 × float32, type `con`) at
     a uniform 5 mm/hr infiltration rate.
   - `sfincs.weir` — three-segment seawall structure (one weir polyline
     with three vertices, crest 4.0 m, discharge coefficient 0.6).
   - `sfincs.inp` — run configuration listing all five inputs and a
     24-hour integration window.

The HydroMT-SFINCS fixtures we vendor are GPL-3.0, matching this
repository's GPL-3.0 license; redistribution as part of this validation
harness is permitted under those terms. The synthetic forcing files
have no upstream — they are released under the same GPL-3.0 as the
rest of this repo.

## Case characteristics

| Property | Value |
|---|---|
| Mesh type | Quadtree (`qtrfile = sfincs.nc`) |
| Total quadtree cells | 4452 (active mask: 4226) |
| Quadtree levels | 3 |
| Base grid | 23 × 63 cells at 200 m, rotated 27° |
| Coordinate reference | EPSG:32633 (UTM zone 33 N) |
| Bathymetry range | −8.66 m to +10.72 m |
| Subgrid tables | `sbgfile = sfincs_subgrid.nc` |
| Meteo source | Synthetic Holland-vortex spiderweb (`spwfile`) |
| Spiderweb dimensions | 12 rows × 36 cols × 3 quantities, 200 km radius |
| Infiltration model | Constant spatially-varying (`inftype = con`, `qinffile = sfincs.qinf`) |
| Structures | One weir polyline, three vertices (`weirfile = sfincs.weir`) |
| Boundary forcing | 5-knot 24 h water-level time series at two points (`bndfile`/`bzsfile`) |
| Integration window | 24 hours (`tstart = 20100205 000000`, `tstop = 20100206 000000`) |

When the upstream archive's integration window changes, the harness
must override `tstart` / `tstop` to re-clamp it to 24 hours; today the
upstream window is exactly 24 hours so no override is needed.

## Usage

```sh
sh tests/cases/case_production/fetch.sh
```

After a successful run the directory contains a runnable `sfincs.inp`
plus all referenced inputs. Re-running the script with the case
already extracted exits 0 without re-downloading. The intermediate
archive is removed after extraction.

The case is invoked by the GPU-vs-CPU validation harness in `tests/`.
The SFINCS executable reads `sfincs.inp` from the current working
directory, so the harness `cd`s into a per-run directory after copying
these inputs.
