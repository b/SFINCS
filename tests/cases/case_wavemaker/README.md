# case_wavemaker

A small, fully self-contained SFINCS test case that exercises the
**wavemaker** code path so the GPU validation harness diffs the
wavemaker bridge and kernel. None of the other cases set
`wavemaker_wvmfile`, so the `wavemaker = .true.` gate at
`source/src/sfincs_lib.F90:210,282,645` is otherwise false for every
harness run; `update_wavemaker_fluxes` (CPU sibling
`source/src/sfincs_wavemaker.f90`, GPU kernel
`source/src/sfincs_wavemaker_gpu.cuf`) is never traversed by the
existing validation matrix.

## Configuration

- **Mesh** — regular 50 x 50 grid at 100 m spacing, x0 = y0 = 0,
  rotation 0°. Domain spans 0..5000 m in each direction.
- **Bathymetry** — flat at -10 m everywhere (always wet); cartesian
  coordinates.
- **Mask layout** — uniform `mask = 1` (active SFINCS interior)
  everywhere; no `mask = 2` water-level boundary, no `mask = 3` outflow.
  The wavemaker polyline supplies the only forcing.
- **Wavemaker polyline** — one short vertical line `wvm01` at
  `x = 350 m`, running from `y = 4500 m` to `y = 500 m`. Cells
  intersected by the polyline (column m=4 of the regular grid) are
  flagged `kcs = 4` and the associated uv-faces `kcuv = 4` by
  `initialize_wavemakers` and become wavemaker forcing points; the
  wavemaker boundary condition (weakly-reflective, applied at those
  uv-faces) launches free-surface anomalies that propagate into the
  basin and reflect off the closed outer boundaries.
- **Wavemaker forcing** — monochromatic IG signal selected by
  `wavemaker_signal = mon` (the `wmsigstr(1:3) == 'mon'` branch in
  `sfincs_input.f90:623`), with `wavemaker_hig = 1` (IG waves on) and
  `wavemaker_hinc = 0` (incident waves off). The closed-form
  monochromatic update at `sfincs_wavemaker.f90:208-212` and the
  matching GPU branch at `sfincs_wavemaker_gpu.cuf:221-223` apply
  `zwav_ig = 0.5 * sin(2*pi*t / Tp_ig)` deterministically (no random
  phases used), so CPU and GPU agree to bit-precision-level drift.
  Hm0_ig = 0.5 m and Tp_ig = 60 s, held constant over the 24 h run at
  the two forcing points.
- **Run** — 24 simulated hours, `outputformat = net`,
  `inputformat = asc`.

## Files

- `sfincs.inp` — run configuration, including the four
  `wavemaker_*file` keywords pointing at the polyline and forcing
  series, plus `wavemaker_signal`, `wavemaker_hig`, `wavemaker_hinc`.
- `sfincs.dep` — 50 x 50 ASCII depth grid, all -10.0 m.
- `sfincs.msk` — 50 x 50 ASCII mask grid, all 1's.
- `sfincs.wvm` — wavemaker polyline definition (one polyline `wvm01`,
  two endpoints).
- `sfincs.wfp` — wavemaker forcing-point locations (two points along
  the polyline).
- `sfincs.whi` — Hm0_ig time series at the two forcing points
  (constant 0.5 m).
- `sfincs.wti` — Tp_ig time series at the two forcing points
  (constant 60 s).

The case is invoked by `tests/run_validation.sh`; SFINCS reads
`sfincs.inp` from its current working directory, so the harness `cd`s
into a per-run directory after staging these inputs. All input files
are hand-authored under this repo's GPL-3.0; no upstream provenance.
