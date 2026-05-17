# case_nonhydro_smoke

A minimal self-contained SFINCS test case that enables the non-hydrostatic
solver (`nonh = 1`) and exercises the SOR-68 Phase 4 flush/pull bridges
around `compute_nonhydrostatic` in `source/src/sfincs_lib.F90`. None of
the other cases set `nonh`, so the `nonhydrostatic = .true.` gate is
otherwise false for every harness run; the bridge bundle
`bundle_for_nonhydrostatic` (and `compute_nonhydrostatic` itself) is
never traversed by the existing validation matrix.

## Configuration

- **Mesh** — regular 10 x 3 grid at 100 m spacing (dx = dy = 100 m),
  x0 = y0 = 0, rotation 0°. Domain spans 0..1000 m in x, 0..300 m in y.
- **Bathymetry** — flat at -2 m everywhere.
- **Mask layout** — only row `n = 2` is active (1D channel); `n = 1`
  and `n = 3` are `kcs = 0` (inactive padding); within row 2,
  `m = 1` and `m = 10` are `kcs = 2` (water-level boundary), `m = 2..9`
  are `kcs = 1` (active SFINCS interior). The single-row layout
  guarantees every active cell has at least one `kcs = 0` neighbor,
  so the `mask_nonh` loop at `source/src/sfincs_domain.f90:1318` never
  accesses the unallocated `quadtree_nonh_mask` array on the regular
  (non-quadtree) input path — `nrows = 0` after init, and
  `compute_nonhydrostatic` is a no-op solve over an empty matrix.
  That is sufficient to exercise the Phase 4 flush/pull bridges at the
  feature boundary every step (the predicate `if (nonhydrostatic)` is
  true) while keeping the case CPU/GPU bit-identical: the bridges
  copy zs/q/uv/kfuv D2H and back, and the empty-matrix
  `compute_nonhydrostatic` produces no host-side state mutation.
- **Boundary** — two water-level points: `(0, 150) m` held at constant
  zs = 0.10 m, `(1000, 150) m` held at constant zs = 0.00 m. The
  imposed gradient drives a hydraulic adjustment along the channel.
- **Run** — 60 s simulated, `dtmapout = 30 s`, `outputformat = net`,
  `inputformat = asc`.

## Files

- `sfincs.inp` — run configuration, including `nonh = 1` and the
  four ASCII forcing-file keywords. Uses default `nh_*` keywords
  (no `nh_tstop` override, so the non-hydrostatic pressure step
  runs for the full simulation).
- `sfincs.dep` — 10 x 3 ASCII depth grid, all -2.0 m.
- `sfincs.msk` — 10 x 3 ASCII mask grid, `0` outside row 2, `2 1...1 2`
  in row 2.
- `sfincs.bnd` — two boundary points (channel ends).
- `sfincs.bzs` — constant water-level time series for the two boundary
  points (0.10 m and 0.00 m).

The case is invoked by `tests/run_validation.sh` (the harness loops
over every `tests/cases/case_*/` directory); SFINCS reads `sfincs.inp`
from its current working directory, so the harness `cd`s into a
per-run directory after staging these inputs. All input files are
hand-authored under this repo's GPL-3.0; no upstream provenance.
