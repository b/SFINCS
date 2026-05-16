# case_prod_regular_tide

A production-scale SFINCS test case that exercises the regular-grid code
path under a multi-component tidal water-level boundary. The mesh is a
500 x 500 regular grid at 50 m spacing (25 km x 25 km footprint) with a
linear west-to-east bathymetry ramp from -10 m to +5 m plus a single 2D
Gaussian dip (-2 m at the centre, sigma = 50 cells) so the field is not
perfectly linear. The boundary forcing on the western column is the sum
of three components — M2 (period 12.4206 h, amplitude 1.0 m), M4
(period 6.2103 h, amplitude 0.25 m), and a +0.3 m mean sea-level
constant — applied identically at two bnd support points spanning the
boundary, sampled every 600 s over a 24-hour simulation window. No
subgrid, no quadtree, no meteo, no infiltration, no structures, no
discharges, no wavemakers, no SnapWave: this case isolates the bare
regular-grid + tide-boundary path at a scale where per-step kernel work
dominates GPU launch overhead, so `tests/run_benchmarks.sh` can report
a meaningful CPU-vs-GPU speedup ratio.

## Case shape

- **Mesh.** 500 x 500 regular grid, dx = dy = 50 m, x0 = y0 = 0,
  rotation = 0. Total cells = 250 000. Mask: western column (m = 1)
  marked 2 (water-level boundary), eastern column (m = MMAX) marked 0
  (dry land strip), interior (2 <= m <= MMAX - 1) marked 1 (active).
  Active (msk > 0) cells = 249 500.
- **Active wet cells (CPU baseline, msk > 0 and zb < 0).** 168 083
  cells reported by `generate.py` and verified post-run from the CPU
  baseline (see `tests/runs/case_prod_regular_tide/cpu/sfincs.log`).
  This sits comfortably above the 100 000-cell production-scale bar
  the issue mandates.
- **Bathymetry.** zb(m, n) = (-10 + 15 (m - 1) / (MMAX - 1)) plus a
  Gaussian dip of amplitude -2 m at (m, n) = (MMAX/2, NMAX/2) with
  sigma = 50 cells. Range: roughly -12 m at the centre to +5 m at the
  eastern edge.
- **Boundary support points.** Two points along the western edge:
  (x, y) = (0, 0) and (0, (NMAX - 1) * dy) = (0, 24 950). Both are
  forced by the same bzs time series, so all msk = 2 cells receive
  identical forcing after spatial interpolation.
- **Forcing.** zs(t) = 1.0 cos(2 pi t / 44 714.16) +
  0.25 cos(2 pi t / 22 357.08) + 0.3, sampled every 600 s from t = 0
  to t = 86 400 s (145 samples).
- **Simulation window.** tref = tstart = 2020-01-01 00:00:00,
  tstop = 2020-01-02 00:00:00, dtmax = 60 s, alpha = 0.5. The adaptive
  CFL step settles around dt ~ 2-3 s for c = sqrt(g * h) ~ 10 m/s and
  dx = 50 m, yielding well over 10 000 integration steps over the
  24-hour window.
- **Integration step count (CPU baseline).** Verified post-run from
  the timestep lines in `tests/runs/case_prod_regular_tide/cpu/sfincs.log`.

## Coverage axes

This case ticks the following boxes from the test-suite coverage
matrix:

- **Geometry.** Regular grid at production resolution (250 k total
  cells, ~ 168 k active wet cells).
- **Boundaries.** Multi-component tide: M2 + M4 + a mean sea-level
  constant. Three superposed harmonics are the explicit production-tier
  forcing requirement.
- **Subgrid / meteo / infiltration / structures / discharges /
  wavemakers / SnapWave.** None. Those subsystems are exercised by
  other cases in the suite (`case_production` for subgrid + meteo +
  structures + infiltration, the per-feature isolation cases for the
  rest, `case_snapwave` for SnapWave). This case deliberately leaves
  them off so the regular-grid path is the only thing the
  benchmark-and-validation harness measures.

## Provenance / license

All input files in this directory are **synthetic, generated from this
repository's `generate.py` script under the same GPL-3.0 license that
covers SFINCS itself.** No vendored fixtures, no fetched archives. The
script is deterministic: re-running `python3 generate.py` from this
directory produces byte-identical `sfincs.dep`, `sfincs.msk`,
`sfincs.bnd`, and `sfincs.bzs` artifacts. The generator takes no
parameters and reads no environment variables; the dimensions, mask
layout, bathymetry shape, and tidal forcing constants are all
hard-coded constants at the top of `generate.py`.

The HydroMT-SFINCS test fixtures (the user maintains a local checkout
at `../hydromt_sfincs`) were considered for vendoring but their
largest fixture (`tests/data/sfincs_test`, 84 x 36 = 3 024 cells) is
two orders of magnitude below the production-scale cell-count bar this
case targets, so a synthetic generator is the right sourcing option
per the issue's preference list.

## Running

The case is invoked by both the GPU-vs-CPU validation harness
(`tests/run_validation.sh`) and the CPU-vs-GPU benchmark harness
(`tests/run_benchmarks.sh`) via the `tests/cases/*/` glob — no harness
edits are required to pick up the case. The SFINCS executable reads
`sfincs.inp` from the current working directory, so each harness `cd`s
into a per-run directory under `tests/runs/` or `tests/runs_bench/`
after staging these inputs.

## Benchmark row (this dev box, this branch)

### Benchmark refresh (clean box, 2026-05-16, SOR-901)

`tests/run_benchmarks.sh` run on a quiet box (no concurrent CPU
competitors, all 128 CPU threads via SOR-894's
`OMP_NUM_THREADS=$(nproc)`) — verbatim `tests/runs_bench/summary.json`
rows for this case:

```json
{
  "case": "case_prod_regular_tide",
  "config": "cpu",
  "wall_clock_seconds": 41.67,
  "peak_memory_mb": 113.77,
  "max_abs_diff_zsmax": null,
  "max_zsmax_ref": null,
  "ratio_vs_ref": null,
  "verdict": "PASS",
  "speedup_vs_cpu": null,
  "cpu_threads": 128
},
{
  "case": "case_prod_regular_tide",
  "config": "gpu_kieee",
  "wall_clock_seconds": 200.65,
  "peak_memory_mb": 28.0,
  "max_abs_diff_zsmax": 1.9073486328125e-06,
  "max_zsmax_ref": 2.0601131916046143,
  "ratio_vs_ref": 9.258465217277083e-07,
  "verdict": "PASS",
  "speedup_vs_cpu": 0.208,
  "cpu_threads": null
},
{
  "case": "case_prod_regular_tide",
  "config": "gpu_fastmath",
  "wall_clock_seconds": 180.61,
  "peak_memory_mb": 29.0,
  "max_abs_diff_zsmax": 1.9073486328125e-06,
  "max_zsmax_ref": 2.0601131916046143,
  "ratio_vs_ref": 9.258465217277083e-07,
  "verdict": "PASS",
  "speedup_vs_cpu": 0.231,
  "cpu_threads": null
},
{
  "case": "case_prod_regular_tide",
  "config": "gpu_n2_kieee",
  "wall_clock_seconds": 140.58,
  "peak_memory_mb": 28.0,
  "max_abs_diff_zsmax": 1.9073486328125e-06,
  "max_zsmax_ref": 2.0601131916046143,
  "ratio_vs_ref": 9.258465217277083e-07,
  "verdict": "PASS",
  "speedup_vs_cpu": 0.296,
  "cpu_threads": null
},
{
  "case": "case_prod_regular_tide",
  "config": "gpu_n2_fastmath",
  "wall_clock_seconds": 139.49,
  "peak_memory_mb": 28.0,
  "max_abs_diff_zsmax": 1.9073486328125e-06,
  "max_zsmax_ref": 2.0601131916046143,
  "ratio_vs_ref": 9.258465217277083e-07,
  "verdict": "PASS",
  "speedup_vs_cpu": 0.299,
  "cpu_threads": null
}
```

All five rows clear the 1e-3 ratio gate (ratio ~ 9.3e-7, six orders of
magnitude inside threshold). Against the 128-thread CPU baseline the
GPU configs now measure `speedup_vs_cpu` ≈ 0.21× (single-GPU) and
≈ 0.30× (dual-GPU): on a fully-loaded 64-physical-core CPU, the
GPU paths trail the CPU on this case. The prior "12.3× / 12.4×" banner
quoted in the SOR-885 PR description is a CPU-contamination artifact
(see OLD section below); the honest GPU/CPU ratio against a fair CPU
baseline is well below parity here. The correctness diff is unchanged
between OLD and NEW — only the CPU denominator moved.

### OLD bench numbers (2026-05-09 contaminated; see SOR-901 for context)

Originally captured against a single-threaded CPU baseline
(`OMP_NUM_THREADS=1`, pre-SOR-894) on a box where two orphaned
`cargo test` binaries were pegging ~64 cores each for ~62 hours
continuously (see SOR-901's BODY for the forensic detail). Both
factors inflated the apparent GPU speedup:

```json
{
  "case": "case_prod_regular_tide",
  "config": "cpu",
  "wall_clock_seconds": 1441.7,
  "peak_memory_mb": 111.82,
  "max_abs_diff_zsmax": null,
  "max_zsmax_ref": null,
  "ratio_vs_ref": null,
  "verdict": "PASS",
  "speedup_vs_cpu": null
},
{
  "case": "case_prod_regular_tide",
  "config": "gpu_kieee",
  "wall_clock_seconds": 116.99,
  "peak_memory_mb": 29.0,
  "max_abs_diff_zsmax": 1.9073486328125e-06,
  "max_zsmax_ref": 2.0601131916046143,
  "ratio_vs_ref": 9.258465217277083e-07,
  "verdict": "PASS",
  "speedup_vs_cpu": 12.323
},
{
  "case": "case_prod_regular_tide",
  "config": "gpu_fastmath",
  "wall_clock_seconds": 115.88,
  "peak_memory_mb": 28.0,
  "max_abs_diff_zsmax": 1.9073486328125e-06,
  "max_zsmax_ref": 2.0601131916046143,
  "ratio_vs_ref": 9.258465217277083e-07,
  "verdict": "PASS",
  "speedup_vs_cpu": 12.441
}
```

The "12.323x and 12.441x" banner the SOR-885 commit message and PR
description quoted reflects those contaminated numbers; the
2026-05-16 refresh above supersedes them as the authoritative figures
for this case on this dev box.

## Validation row (this dev box, this branch)

The implementer's `tests/run_validation.sh --skip-build --skip-fetch`
run on the dev box (2x NVIDIA RTX A6000, branch sorcerer/sor-885)
produced the following verdicts for this case at the strict 1e-4 ratio
threshold against the CPU baseline:

```
case                       config   verdict  ratio_vs_cpu
case_prod_regular_tide     cpu      PASS     (baseline)
case_prod_regular_tide     gpu_n1   PASS     9.258465217277083e-07   (108x under 1e-4)
case_prod_regular_tide     gpu_n2   FAIL     1.8147893437709999      (~18 000x over 1e-4)
```

The `cpu` and single-rank `gpu_n1` runs agree with each other to
~ 1e-6 (six orders of magnitude inside the 1e-4 gate). The two-rank
`gpu_n2` run diverges massively (max_abs_diff = 3.51 m on a max
zsmax of 1.93 m, ratio = 1.81).

### Linked blocker — SOR-846

The `gpu_n2` failure replicates the **project-wide SOR-846 defect**:
[Shrink Phase-4 device shadows + renumber connectivity to local
indices](https://linear.app/etherpilot/issue/SOR-846/shrink-phase-4-device-shadows-renumber-connectivity-to-local-indices).
The same defect is referenced verbatim in the SOR-882 commit message
("gpu_n2 is independently blocked on SOR-846 (gather_to_rank0_real4
rank-1-drop)"), in the SOR-845 commit message ("Until SOR-846 lands,
n=2 GPU runs cannot satisfy the 1e-4 numerical tolerance"), and in
the REPLAN issues filed by every prior `tests/cases/<name>` coverage
issue that hit the same wall (SOR-876 for `case_meteo`, SOR-879 for
`case_infiltration`, SOR-890 for `case_structures`, SOR-891 for
`case_discharges`).

Cross-case evidence from the same `tests/run_validation.sh` run that
produced the table above:

```
case                       gpu_n2 verdict   gpu_n2 ratio_vs_cpu
case_prod_regular_tide     FAIL              1.815
case_production            FAIL              2.203
case_quadtree_tide         FAIL             14.206
case_regular               FAIL              0.925
case_snapwave              FAIL              0.930
```

Every existing case fails `gpu_n2` at this branch HEAD with the same
qualitative shape — `max_abs_diff` ~ `max(zs_ref)`, consistent with
"approximately one rank's contribution is dropped from the final
gather". This is *not* a new failure introduced by
`case_prod_regular_tide`; it is the pre-existing project-wide gate
that SOR-846 will flip from FAIL → PASS for every regular-grid
(and `case_regular`-style) gpu_n2 run once it merges.

### What happens when SOR-846 merges

`case_prod_regular_tide`'s `gpu_n2` row is expected to flip from FAIL
to PASS automatically — the case has no n=2-specific sensitivities
beyond what SOR-846 already fixes (per its AC #11, which mandates
`case_regular`/`case_quadtree_tide`/`case_production` PASS the full
1e-4 matrix once SOR-846 lands). Re-running
`tests/run_validation.sh --skip-build` against this case directory
on a tree that includes SOR-846 should produce three PASSes; if it
does not, this README's linked blocker is wrong and the divergence
needs separate diagnosis.
