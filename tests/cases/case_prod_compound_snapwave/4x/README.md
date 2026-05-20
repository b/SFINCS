# case_prod_compound_snapwave — 4x grid refinement

A 4x-cell-count refinement of the parent
[`case_prod_compound_snapwave`](../README.md) case — the heaviest
production case (3-level quadtree + subgrid + the SFINCS-SnapWave
coupling, run under simultaneous tide + wave boundaries). The 1x
quadtree mesh is built on a 130 × 130 base grid at `dx = dy = 200` m;
this 4x variant doubles the base grid to 260 × 260 and halves the base
`dx` to 100 m, keeping the physical footprint (26 km × 26 km) and the
3-level refinement / two nested rectangle geometry inherited from the
parent generator. Active quadtree cells rise from 102 880 to 405 832
(≈ 3.94×), and both the subgrid lookup and the SnapWave wave-grid
coupling share that refined SFINCS computational mesh.

Every physical-space parameter is inherited from the parent case:
analytical bathymetry (`synth_bathymetry`), refinement polygon shape
(`build_refinement_polygons`), the SFINCS tidal boundary forcing
(M2 + M4 + 0.20 m sea-level on the western open boundary), and the
SnapWave wave-spectrum forcing (storm-event Hs/Tp time series on the
same western edge) are unchanged — only the base grid resolution
differs, isolating resolution as the independent axis along which the
perf-scaling sweep traverses the case.

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

The parent `generate.py` calls into HydroMT-SFINCS for the quadtree
mesh build (`build_quadtree_xugrid`) and the subgrid table build
(`build_subgrid_table_quadtree`), so unlike the analytical-numpy cases
(riverine, storm_amuv) the pinned HydroMT-SFINCS package IS exercised at
refinement time. Bumping the pin requires re-cutting this directory; see
[`tests/cases/preprocessing/README.md`](../../preprocessing/README.md)
for the bump procedure.

## Source data — fully synthetic, no external DEM

The 4x dir is fully derived from analytical primitives in the parent
`generate.py`. There are no external inputs:

- **Bathymetry**: `synth_bathymetry(x, y, mmax_m)` — a linear
  west → east sea → shore gradient (−10 m offshore at the western
  edge → +5 m onshore at the eastern edge) plus 20 cm pixel-scale
  ripples (`0.20 * sin(2π x / 600) * cos(2π y / 600)`). Evaluated on
  an axis-aligned DEM at refined pixel resolution (`dx / 2^(L-1) / 20`
  per level) for the subgrid build, and analytically per quadtree cell
  centre for the `z` field on `sfincs.nc`.
- **Refinement geometry**: `build_refinement_polygons` — two concentric
  axis-aligned rectangles centred on the grid centre. The outer
  rectangle covers the central ≈ 80 % of the footprint and refines
  L1 → L2; the inner rectangle covers the central ≈ 50 % and adds
  L2 → L3 (`refinement_level = 2`). Geometry is purely synthetic; no
  imported shapefile.
- **Mask layout**: western 2-base-cell band (`xc < x0 + 2 dx`) is open
  boundary (`mask = 2`), interior is active (`mask = 1`). The same
  western band is painted on the SnapWave mask (`snapwave_mask = 2`) so
  the tide and the wave boundaries are simultaneously active over the
  same boundary cells. The refined mesh carries 520 open-boundary cells
  on each of the SFINCS and SnapWave masks.
- **SFINCS open-boundary forcing**: M2 (12.4206 h, 0.60 m amplitude) +
  M4 (6.2103 h, 0.15 m amplitude with +0.6 rad phase) + 0.20 m
  sea-level constant, sampled every 30 min for 24 h, applied identically
  at two `sfincs.bnd` points on the western edge
  (`x = 50` m, `y ∈ {6500, 19500}` m).
- **SnapWave wave-spectrum forcing**: a storm-event Hs profile ramped
  1.0 m → 4.0 m over 0–12 h, held at 4.0 m through 18 h, decayed back to
  1.0 m by 24 h; Tp tracking Hs (`6 s + 1.5 × Hs`, clipped 6–12 s); mean
  wave direction 270° (westward incoming, nautical convention);
  directional spreading 25°. Sampled every 30 min for 24 h, identical at
  the same two western-edge support points
  (`snapwave.bnd` = `sfincs.bnd`).
- **Grid constants** passed by `generate_4x_compound_snapwave.py`:
  - `--nmax 260` (was 130)
  - `--mmax 260` (was 130)
  - `--dx 100.0` (was 200.0)

The parent generator deterministically rebuilds the mesh / subgrid /
forcing from the constants above, so re-running the 4x wrapper
overwrites the directory byte-for-byte identically (no RNG).

## Regenerate

From the SFINCS repo root:

```bash
tests/cases/preprocessing/.venv/bin/python \
    tests/cases/case_prod_compound_snapwave/generate_4x_compound_snapwave.py
```

An optional positional argument overrides the default output directory
(default: `tests/cases/case_prod_compound_snapwave/4x/`):

```bash
tests/cases/preprocessing/.venv/bin/python \
    tests/cases/case_prod_compound_snapwave/generate_4x_compound_snapwave.py \
    path/to/alt_out/
```

The generator is idempotent — re-running on the existing 4x dir
overwrites every generated file. Build time on this dev box is
≈ 2.5 minutes (HydroMT-SFINCS subgrid construction is the dominant
cost). Bootstrap the preprocessing venv with
[`tests/cases/preprocessing/setup.sh`](../../preprocessing/README.md)
if it is not yet present (operators running from a git worktree must
pass `HYDROMT_SFINCS_DIR=/path/to/hydromt_sfincs`, since the
auto-detected sibling path assumes the canonical checkout layout).

## Files

| File | Description |
| --- | --- |
| `sfincs.inp` | Run configuration — copied verbatim from the 1x parent case. No `mmax` / `nmax` / `dx` / `dy` lines (the quadtree mesh is loaded from `qtrfile = sfincs.nc`); `tref` / `tstart` / `tstop` / `qtrfile` / `sbgfile` / `bndfile` / `bzsfile` / `dtwave` and the SnapWave flags (`snapwave = 1`, `snapwave_bndfile` / `snapwave_bhsfile` / `snapwave_btpfile` / `snapwave_bwdfile` / `snapwave_bdsfile`) all match 1x. |
| `sfincs.nc` | Quadtree mesh NetCDF (zlib `complevel=4`) — 405 832 cells across 3 refinement levels (L1: 23 500; L2: 107 756; L3: 274 576); carries `z`, `mask`, `snapwave_mask`, per-cell `n` / `m` / `level`, and the `mu` / `md` / `nu` / `nd` connectivity entries. |
| `sfincs_subgrid.nc` | Subgrid lookup table (zlib `complevel=4`) — `np = 405 832` cells × `levels = 10`, with `npuv = 812 088` U/V points. |
| `sfincs.bnd` | Two SFINCS open-boundary support points at the centre of the leftmost base column, `x = 50` m, `y ∈ {6500, 19500}` m. |
| `sfincs.bzs` | Boundary water-level time series — 49 samples spanning 24 h, identical M2 + M4 + sea-level signal at both `bnd` points. |
| `snapwave.bnd` | Two SnapWave wave-spectrum boundary support points, identical to `sfincs.bnd`. |
| `snapwave.bhs` | SnapWave Hs storm-event time series — 49 samples, identical at both support points. |
| `snapwave.btp` | SnapWave Tp time series — 49 samples (tracks Hs, clipped 6–12 s). |
| `snapwave.bwd` | SnapWave mean wave direction — steady 270° at both support points. |
| `snapwave.bds` | SnapWave directional spreading — steady 25° at both support points. |
