# Minimal CPU non-hydrostatic smoke case

Init-only regression smoke for SOR-78 (`col_idx = 0` write into the still-
unallocated module-level `col_idx` in `initialize_nonhydrostatic`). Pre-fix,
any input with `nonh = 1` SIGSEGVs inside `__memset` before `initialize_
nonhydrostatic()` returns; this case exercises that init path on the smallest
viable regular grid and verifies the run reaches the time-loop
`compute_nonhydrostatic` call at `source/src/sfincs_lib.F90` line 671.

| field         | value                                                           |
|---------------|-----------------------------------------------------------------|
| grid          | regular 10×3 cells (m × n), dx = dy = 100 m, no rotation        |
| domain        | 0 ≤ x ≤ 1000 m, 0 ≤ y ≤ 300 m                                   |
| bathymetry    | flat, zb = −2.0 m                                               |
| mask          | only row n = 2 is active (1D channel); m = 1 and m = 10 are     |
|               | kcs = 2 (water-level boundary), m = 2..9 are kcs = 1            |
| boundary      | two bnd points: (0, 150) m and (1000, 150) m; both held at      |
|               | constant zs (0.10 m at left, 0.00 m at right) for the run       |
| time          | tref = tstart = 2020-01-01 00:00:00; tstop = +60 s              |
| dtmapout      | 30 s                                                            |
| nonh          | 1 (non-hydrostatic solver enabled, default `nh_*` keywords)     |

The single active row plus two-row inactive padding (n = 1 and n = 3 are
kcs = 0) guarantees every active cell has at least one neighbour that is not
kcs = 1, so the `mask_nonh` loop in `sfincs_domain.f90` never accesses the
unallocated `quadtree_nonh_mask` array on the regular-grid (non-quadtree)
path. `initialize_nonhydrostatic()` therefore runs with `nrows = 0` — that
is sufficient to surface the pre-fix `col_idx = 0` SIGSEGV (the buggy write
targets the module-level allocatable regardless of `nrows`), and is the
minimum needed to exercise the fixed path end-to-end. Non-hydrostatic is
CPU-only (not GPU-ported), so this smoke is intentionally CPU-only — no
GPU/CPU diff harness is needed.

Inputs are ASCII (`inputformat = asc`) and committed in this directory; no
generator step is needed at run time.

## Usage

Driver: `source/build_scripts/run_smoke_nonhydrostatic.sh`.
See that script's `--help` output for build/run options.
