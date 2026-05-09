# case_discharges

A small, fully self-contained SFINCS test case that exercises the discharges
code path (point sources via `srcfile` + `disfile`) — the gap that prompted
this case is documented in SOR-820.

## Configuration

A 50x50 regular grid at 100 m spacing (5 km x 5 km), flat bathymetry at -10 m
across the whole domain, and a closed basin (every cell is active type 1; no
boundary cells, no `bndfile` / `bzsfile`, no tide). The closed basin isolates
the discharges path from boundary handling — the only source of momentum is
the point discharge — and ensures every cell is wet for the full run, so
`zsmax` carries no dry-cell `_FillValue` and the harness's `1e-4` ratio is
well-defined.

A single point source is placed at `(x, y) = (2500, 2500)` — the centre of
the domain — via `sfincs.src`. The source injects a constant 50 m^3/s for
the full 24-hour run via `sfincs.dis` (two time samples at t=0 s and
t=86400 s, both 50 m^3/s, so the linear interpolator in `update_discharges`
evaluates to a constant). 50 m^3/s for 24 h into a 5 km x 5 km basin
deposits ~17 cm of mean water-level rise, with locally higher `zsmax` near
the source — well above the diff tool's `max(zsmax_ref) > 0` precondition
and large enough that the harness's `1e-4` relative threshold is meaningful.

No subgrid, no quadtree, no spiderweb meteo, no infiltration, no
structures, no SnapWave, no drainage. Just the discharges path
(`nsrc_h > 0`).

## Files

- `sfincs.inp` — input keywords (50x50 grid, 24 h run, `srcfile` /
  `disfile` set, no boundary forcing).
- `sfincs.dep` — flat -10 m bathymetry (50x50 ASCII grid).
- `sfincs.msk` — mask: all 1 (active interior; no type-2 boundary cells).
- `sfincs.src` — one point source at `(2500.0, 2500.0)`.
- `sfincs.dis` — constant 50 m^3/s discharge from t=0 s to t=86400 s.
