# case_snapwave

A small, fully self-contained SFINCS test case that exercises the
**SFINCS-SnapWave** coupling so the GPU validation harness diffs the
SnapWave code path. None of the other three cases set `snapwave = 1`,
so kernel changes to `sfincs_snapwave_gpu.cuf` or to the coupling layer
in `source/src/sfincs_snapwave.f90` are otherwise invisible to the harness.

## Configuration

- **Mesh** — uniform 30 x 30 quadtree at 200 m spacing, single refinement
  level (i.e., a regular grid wrapped in the netCDF quadtree format the
  SnapWave coupling requires). The mesh is vendored as `sfincs.nc` and
  carries a `snapwave_mask` variable so SnapWave can read its boundary
  layout from the same file. Bathymetry is a flat shelf at -10 m
  everywhere; cartesian coordinates (`crsgeo = 0`).
- **Mask layout** — interior cells `mask = 1` (active SFINCS) and
  `snapwave_mask = 1` (active SnapWave). The western column (`m = 1`)
  carries `mask = 2` (SFINCS water-level boundary) and `snapwave_mask = 2`
  (SnapWave wave boundary).
- **SFINCS forcing** — single-harmonic M2 tide (period 12.4206 h, amplitude
  0.5 m) applied identically at the two `sfincs.bnd` support points along
  the western edge, sampled every 30 minutes for 24 h. Drives the zsmax
  signal that the harness diffs.
- **SnapWave forcing** — one boundary support point (`snapwave.bnd`) at
  the middle of the western edge, monochromatic conditions held constant
  over the 24 h run: `Hs = 1.5 m`, `Tp = 8 s`, mean direction 270°
  (incoming from the west, nautical convention), directional spreading
  20°. The cadence is set by `dtwave = 1800 s` in `sfincs.inp`.
- **Run** — 24 simulated hours, `outputformat = net`, `inputformat = bin`
  (the quadtree netCDF reader is selected by the `.nc` qtrfile suffix).

## Files

- `sfincs.inp` — run configuration, including the `snapwave = 1` switch
  and the `snapwave_*file` keywords pointing at the SnapWave forcing files.
- `sfincs.nc` — quadtree mesh in netCDF/UFGrid format with `mask`,
  `snapwave_mask`, and the per-cell `n/m/level/mu/mu1/mu2/md/md1/md2/...`
  neighbor-encoding variables the SFINCS reader expects.
- `sfincs.bnd`, `sfincs.bzs` — water-level boundary support points and
  M2 tide time series.
- `snapwave.bnd` — single SnapWave boundary support point.
- `snapwave.bhs`, `snapwave.btp`, `snapwave.bwd`, `snapwave.bds` — Hs,
  Tp, mean direction, and directional-spreading time series at that
  single point (constant values, monochromatic forcing).

The case is invoked by `tests/run_validation.sh`; SFINCS reads
`sfincs.inp` from its current working directory, so the harness `cd`s
into a per-run directory after staging these inputs.
