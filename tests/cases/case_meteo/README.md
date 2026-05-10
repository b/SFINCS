# case_meteo

A small, fully self-contained SFINCS test case that exercises the meteo
code path via the `wndfile` (uniform-wind time series) sub-path. The
underlying mesh and tide are identical to `case_regular` (50x50 cells at
100 m spacing, flat shelf at -10 m on the western half ramping linearly
up to +5 m on the eastern shore, single-harmonic M2 tide on the western
boundary, 24-hour run); the only addition is a `wndfile` time series
that drives a constant wind for the full simulation.

## Meteo sub-path exercised

`wndfile` (uniform wind from time series). The branch is taken when
SFINCS prints the following line in the `Processes` block of the
captured `sfincs.log`:

```
Wind                 : yes
```

(emitted by `source/src/sfincs_lib.F90:254`, gated on the `wind` flag
that `source/src/sfincs_domain.f90:96` sets when `wndfile` is non-`none`).

Activating `wndfile` exercises:

- `read_meteo_data` time-series ingest in `sfincs_meteo_io.f90`
  (allocates `twnd`, `wndmag`, `wnddir` and computes the `cdval` lookup
  table).
- Per-step `update_wind_forcing_from_timeseries` in the GPU sibling
  `source/src/sfincs_meteo_gpu.cuf` — including the `k_wind_uniform`
  CUDA kernel and the device→host bridge-OUT for `tauwu`, `tauwv`,
  `windu`, `windv` (the path most recently audited under SOR-787).

This case explicitly does **not** activate the gridded-meteo (`meteo3d`)
path: with `wndfile` only, `meteo3d` stays `.false.`, so the
`update_meteo_forcing` `k_meteo_time_interp` kernel is dormant. Sibling
sub-paths (`spwfile` / `amufile`+`amvfile` / `amprfile` / `ampfile` /
`prcpfile` / `netspwfile` / etc.) are out of scope for this fixture and
can be added as separate `case_meteo_<subpath>` fixtures by future
issues.

## Synthetic forcing parameters

`sfincs.wnd` holds two time samples bracketing the run:

- t = 0 s and t = 86400 s
- wind speed = 10.0 m/s
- wind direction = 270° (nautical: blowing from the west toward the
  east, in the +x direction on this unrotated grid).

The constant wind speed and direction means the time-interpolation
inside `update_wind_forcing_from_timeseries` resolves to the same
`vmag`/`vdir` at every step, so the only step-to-step variability comes
from the boundary tide. The 10 m/s magnitude lands in the linear
portion of the SFINCS Cd lookup table and produces a non-trivial
surface stress (~3.3e-3 m²/s² on water) that pushes water against the
eastern ramp and modulates `zsmax` measurably above the tide-only
baseline.

## Validation harness usage

Picked up automatically by `tests/run_validation.sh` — no harness
changes are needed. The harness's `1e-4` relative threshold on `zsmax`
gates correctness against the CPU baseline.
