# case_prod_storm_amuv

A production-scale SFINCS validation case that exercises the gridded
`amu` / `amv` wind components together with Green-Ampt infiltration on a
regular mesh large enough to make GPU launch overhead negligible against
per-step kernel work.

## Case shape

| Property | Value |
|---|---|
| Mesh type | Regular grid (`inputformat = asc`, no quadtree) |
| Mesh size | 400 x 400 cells at 50 m spacing (20 km x 20 km) |
| Active cells (`np`) | 160 000 (every cell with `msk > 0`) |
| Bathymetry | Linear west-to-east shelf, -8 m offshore to +2 m onshore |
| Boundary forcing | Western water-level boundary, 3 support points (M2 + M4 tide + slow Gaussian storm-surge ramp) |
| Meteo source | Gridded `amu` / `amv` wind components, drifting wind front + meridional sinusoidal gradient |
| Meteo grid | 41 x 41 at 500 m spacing, 7 snapshots over 24 h (covering the 20 km x 20 km model footprint) |
| Precipitation | Time-series file (`prcfile`), triangular pulse peaking at 12 h |
| Infiltration model | Green-Ampt (`infiltration_type = gai`) with `psifile` / `sigmafile` / `ksfile` |
| Soil pattern | Two-zone sandy/clayey split with a wavy boundary (sandy north, clayey south) |
| Integration window | 24 hours (`tref = tstart = 20200101 000000`, `tstop = 20200102 000000`) |

## Coverage axes

This case exercises the production-scale tier of the validation harness:

- **Geometry.** Regular grid at production resolution: 400 x 400 = 160 000
  active cells, well past the 100 000 wet-cell bar that case_production /
  case_regular were too small to clear.
- **Meteo.** Gridded `amu` / `amv` (i.e. the equidistant-grid wind-component
  path) with non-trivial spatial gradients in BOTH components: `amu` carries
  a tanh wind front that drifts north-to-south through the domain, plus a
  background west-to-east ramp; `amv` carries a constant southward bias plus
  a `sin(2 pi x / Lx)` pattern whose amplitude grows over the simulation. The
  spatial gradient is non-trivial at every snapshot — at no time is either
  component spatially uniform across the model footprint.
- **Infiltration.** Spatially-varying Green-Ampt (`gai`) with three soil
  rasters (`psi`, `sigma`, `ks`) split into a sandy/clayey two-zone pattern
  with a wavy boundary. SFINCS's binary auto-detection (see
  `source/src/sfincs_infiltration_io.f90` lines 120-126) selects `gai`
  whenever `psifile` is set with rainfall enabled; the `infiltration_type`
  setting in `sfincs.inp` is decorative for the binary path but is set
  explicitly to `gai` for clarity.
- **Boundary.** Tidal water-level (M2 + M4) plus a slow Gaussian storm-surge
  ramp at three western support points.
- **Not exercised here** (deliberate, to isolate the meteo + infiltration
  combination at scale): subgrid topography, quadtree refinement,
  structures, discharges, wavemakers, SnapWave coupling.

## Provenance and license

All inputs are authored for this harness; nothing is vendored from external
repositories. The only source of truth is `generate.py`, a deterministic
Python script (no RNG) that emits every file referenced by `sfincs.inp`
from a small, fixed parameter set:

| File | Format | Source |
|---|---|---|
| `sfincs.dep` | ASCII, 400 x 400 | generated |
| `sfincs.msk` | ASCII, 400 x 400 (msk = 2 on western column, msk = 1 elsewhere) | generated |
| `sfincs.bnd` | ASCII, 3 support points | generated |
| `sfincs.bzs` | ASCII, 49 timesteps x 3 support points | generated |
| `sfincs.prcp` | ASCII time-series, mm/hr, 49 timesteps | generated |
| `sfincs.amu` | ASCII Delft3D-style equidistant-grid meteo, 41 x 41 x 7 | generated |
| `sfincs.amv` | ASCII Delft3D-style equidistant-grid meteo, 41 x 41 x 7 | generated |
| `sfincs.psi` | binary float32 stream, np = 160 000 entries, suction head [mm] | generated |
| `sfincs.sigma` | binary float32 stream, np = 160 000 entries, max moisture deficit [-] | generated |
| `sfincs.ks` | binary float32 stream, np = 160 000 entries, sat. hydraulic conductivity [mm/hr] | generated |

The generated artifacts are checked in alongside the script so the case is
runnable straight from a fresh worktree without invoking the generator
first; re-running `python3 generate.py` from this directory regenerates
them in place. Total in-tree size: 3.54 MB (well under the 5 MB cap; see
`generate.py` output for the per-file breakdown).

License: same GPL-3.0 as the rest of this repository — no third-party
material is bundled.

## Note on the issue spec's file-name reference

The driving issue (`SOR-888`) names `f0file` / `fcfile` as the Green-Ampt
parameter rasters. Those keywords are actually for the **modified Horton**
infiltration model (`infiltration_type = hor`); the canonical Green-Ampt
inputs in SFINCS are `psifile` / `sigmafile` / `ksfile`, and only the
presence of `psifile` triggers the `gai` branch in
`source/src/sfincs_infiltration_io.f90`. This case follows the SFINCS
source: `psifile` / `sigmafile` / `ksfile`, with `infiltration_type = gai`
set explicitly.

## Usage

```sh
# Inputs already exist in-tree; the generator is the recipe, not a runtime
# step. Re-run only when adjusting parameters in generate.py.
python3 generate.py
```

The harnesses (`tests/run_validation.sh`, `tests/run_benchmarks.sh`) pick
this case up automatically via the `tests/cases/*/` glob.

## Validation gate

`tests/run_validation.sh` runs at the strict 1e-4 ratio threshold across
`cpu`, `gpu_n1`, and `gpu_n2`. On the implementer's dev box at
`origin/main` HEAD, both GPU configurations report FAIL on this case:

```
case_prod_storm_amuv  gpu_n1  ratio=1.391e-4   FAIL  max_abs_diff=3.90e-4 m  max_zsmax_ref=2.806 m
case_prod_storm_amuv  gpu_n2  ratio=9.516e-1   FAIL  max_abs_diff=1.194 m    max_zsmax_ref=1.255 m
```

Both gates are blocked on
[SOR-846 — Shrink Phase-4 device shadows + renumber connectivity to local indices](https://linear.app/etherpilot/issue/SOR-846/shrink-phase-4-device-shadows-renumber-connectivity-to-local-indices),
which is in Backlog at the time this case is being authored:

- **`gpu_n2`** — the catastrophic ~95% ratio is the
  `gather_to_rank0_real4` rank-1-drop / Phase-4 device-shadow shrink
  defect documented in SOR-846 AC #11. The same defect produces the
  same ratio shape (~0.93-0.95) for *every* case under
  `tests/cases/`, including `case_regular`, in the same harness run.
  The author of SOR-879 (the REPLAN of `case_infiltration` / SOR-826)
  confirmed the defect's reach: "every case (including the
  already-shipped `case_regular`) fails the n=2 gate by ~92% drift,
  not just my new infiltration case."
- **`gpu_n1`** — the smaller-but-still-over-threshold drift for this
  case at single-rank GPU is the per-step bridge-IN bulk-assignment
  drift on the meteo and infiltration kernel surfaces, also covered by
  SOR-846. The relevant kernel sites called out in SOR-846's AC #4 are
  `source/src/sfincs_meteo_gpu.cuf:123 — zs = zs_h` and
  `source/src/sfincs_infiltration_gpu.cuf:94 — zs = zs_h` — i.e., the
  amu/amv update path and the Green-Ampt update path that this case
  exercises. The drift accumulates over ~30 000 timesteps × 160 000
  active cells, pushing the ratio over the 1e-4 bar even with the
  per-step error at single-ulp scale.

When SOR-846 lands, this case's `gpu_n1` and `gpu_n2` gates are both
expected to PASS; the case is shipped now so it's part of the regression
matrix that will validate SOR-846 once it merges.

## Benchmark gate

`tests/run_benchmarks.sh` runs at the looser 1e-3 ratio threshold under
`mpirun -n 1` (so the SOR-846 n=2 defect is out of scope) and gates on
`speedup_vs_cpu > 1.0×` for both `gpu_kieee` and `gpu_fastmath`. On the
implementer's dev box (load avg ~250 from concurrent sessions; numbers
will be larger on a quieter box), the verbatim
`tests/runs_bench/summary.json` rows for this case are:

```json
{
  "case": "case_prod_storm_amuv",
  "config": "cpu",
  "wall_clock_seconds": 1129.16,
  "peak_memory_mb": 117.07,
  "max_abs_diff_zsmax": null,
  "max_zsmax_ref": null,
  "ratio_vs_ref": null,
  "verdict": "PASS",
  "speedup_vs_cpu": null
}
{
  "case": "case_prod_storm_amuv",
  "config": "gpu_kieee",
  "wall_clock_seconds": 116.47,
  "peak_memory_mb": 30.0,
  "max_abs_diff_zsmax": 0.00024187564849853516,
  "max_zsmax_ref": 2.806426525115967,
  "ratio_vs_ref": 8.618634634966629e-05,
  "verdict": "PASS",
  "speedup_vs_cpu": 9.695
}
{
  "case": "case_prod_storm_amuv",
  "config": "gpu_fastmath",
  "wall_clock_seconds": 114.32,
  "peak_memory_mb": 30.0,
  "max_abs_diff_zsmax": 0.0003902912139892578,
  "max_zsmax_ref": 2.806426525115967,
  "ratio_vs_ref": 0.00013907052634243837,
  "verdict": "PASS",
  "speedup_vs_cpu": 9.877
}
```

Both GPU configurations report `verdict: PASS` against the 1e-3
benchmark threshold and `speedup_vs_cpu > 1.0×` (~9.7× kieee, ~9.9×
fastmath), so the case satisfies the benchmark gate. The harness's
`OVERALL: PASS` (`benchmarks rc=0`) was confirmed on the same dev-box
run.

## CPU baseline characteristics

From the CPU baseline `sfincs.log`:

```
Number of active z points      :    160000
Number of active u/v points    :    319200
Total simulation time          :   1128.804 s
Average time step (s)          :      2.810
```

Active z-cells: 160 000 (well over the 100 000 wet-cell bar). Number of
integration timesteps: 86 400 s / 2.810 s ≈ 30 747 (well over the
10 000-step bar).


