# SOR-1032 — smoke matrix at 1h after enabling 4x on all production cases

Verifies that with the per-case 4x exclusion removed, all five production
cases run on both 1x and 4x grids at every cpu_n128 / gpu_n1 / gpu_n2
configuration without any cell skipped from the grid axis.

* HEAD             : fb3b986f (fb3b986fb88a2ece2972d4cf4e90ac1105446963)
* captured-at      : 2026-05-20T04:33:29Z
* cells run: 30 (expected: 5 cases × 2 grids × 1 length × 3 configs = 30)
* cells skipped: 0

## Per-case 1x / 4x rows @ 1h

Wall (s) per config; non-zero `total` and `total_simulation_time` for every
cell confirms AC3.

| case | grid | cpu_n128 wall | gpu_n1 wall | gpu_n2 wall | cpu_n128 sim | gpu_n1 sim | gpu_n2 sim |
|------|------|---------------|-------------|-------------|--------------|------------|------------|
| `case_prod_regular_tide` | `1x` | 2.751 | 0.616 | 0.807 | 2.609 | 0.344 | 0.389 |
| `case_prod_regular_tide` | `4x` | 17.054 | 2.423 | 2.529 | 16.511 | 1.786 | 1.407 |
| `case_prod_quadtree_subgrid_tide` | `1x` | 1.633 | 0.611 | 0.768 | 1.485 | 0.326 | 0.374 |
| `case_prod_quadtree_subgrid_tide` | `4x` | 7.553 | 2.620 | 2.526 | 6.987 | 1.799 | 1.504 |
| `case_prod_riverine` | `1x` | 1.150 | 1.737 | 1.474 | 1.053 | 1.506 | 1.091 |
| `case_prod_riverine` | `4x` | 9.048 | 11.146 | 8.421 | 8.688 | 10.651 | 7.663 |
| `case_prod_storm_amuv` | `1x` | 1.782 | 3.048 | 2.400 | 1.678 | 2.810 | 2.048 |
| `case_prod_storm_amuv` | `4x` | 14.509 | 20.512 | 13.884 | 14.141 | 20.000 | 13.115 |
| `case_prod_compound_snapwave` | `1x` | 4.731 | 5.202 | 5.424 | 3.527 | 3.247 | 3.328 |
| `case_prod_compound_snapwave` | `4x` | 26.111 | 19.522 | 19.419 | 21.325 | 12.123 | 11.802 |

## Notes

* `case_prod_regular_tide` 4x is refined at sweep time by
  `generate_4x_regular_tide.py` (no `tests/cases/case_prod_regular_tide/4x/`
  subdir on `main`); the other four cases stage from their committed
  `tests/cases/<case>/4x/` subdirs.
* This is the implementer-gate smoke window. A full `1h + 6h + 24h + 4d`
  sweep across the same matrix is the operator's eventual deliverable
  (not gated by this issue).
* Plots are under `plots/`; the analyze-layer DataFrame can be loaded
  with `tests.perf.analyze.load.load_sweep(<this dir>)`.
