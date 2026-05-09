# case_prod_riverine

A production-scale riverine flood case for the GPU-vs-CPU validation
and benchmark harnesses. The case stresses the per-step kernel work —
a 160 000-cell regular grid integrated over 24 simulated hours
(~22 700 adaptive-CFL time steps) — so that
`tests/runs_bench/summary.json` reports a speedup ratio dominated by
compute, not GPU launch overhead. It is the harness's first case that
simultaneously exercises:

- **Tidal water-level downstream boundary** (`bndfile` / `bzsfile`,
  M2 + M4 + sea-level on the western open boundary).
- **Mass-flux source upstream** (`srcfile` / `disfile`, a stepped
  hydrograph at the eastern end of the river channel).
- **SCS Curve Number method-A infiltration** (`inftype = cna`,
  `scsfile`) over a spatially-varying CN raster.
- **Weir-style structure** (`weirfile`, one polyline crossing the
  river midway between source and tide boundary, crest 1.0 m).
- **Time-varying precipitation** (`precipfile`, a moderate storm
  pulse — required to activate the infiltration code path).

This is the case that satisfies the request's "at least one case with
simultaneous boundary types" coverage axis (downstream tide bzs +
upstream sourcefile mass-flux running together over the same window).

## Configuration

| Property | Value |
|---|---|
| Mesh | Regular grid, 400 × 400 cells at 50 m spacing |
| Domain footprint | 20 km × 20 km (x ∈ [0, 20 000], y ∈ [0, 20 000]) |
| Coordinate reference | Projected (cartesian, no `epsg`); rotation 0 |
| Active z points | 160 000 (CPU baseline, every interior + west-edge cell) |
| Bathymetry | Synthetic east-to-west river valley: −3 m at west edge → +5 m at east edge, with a 200 m wide channel along y = 10 000 m incised up to 1.5 m below the slope, plus ±5 cm deterministic noise |
| Mask | Interior `kcs = 1`, west column `kcs = 2` (open water-level boundary) |
| Integration window | 24 hours (`tstart = 20200101 000000`, `tstop = 20200102 000000`) |
| Adaptive time step | `alpha = 0.5`, `dtmax = 60 s`; CPU baseline reports average dt ≈ 3.81 s → ~22 700 steps |
| Manning n | 0.024 |
| Boundary forcing | M2 + M4 + 0.05 m sea-level at three west-edge support points (y = 2 500, 10 000, 17 500 m), per-point phase offsets, sampled every 30 min |
| Discharge forcing | One source cell at (19 725, 10 000) m, stepped hydrograph: 5 m³/s baseflow → 50 m³/s peak hours 4.5–14 → recession back to 5 m³/s by hour 22 |
| Weir | One polyline at x = 10 000 m spanning y = 9 500..10 500 (4 vertices), crest 1.0 m, discharge coefficient 0.6 |
| Infiltration | SCS Curve Number method A; CN = 80 (default), 95 (impervious strip 3 000 ≤ x < 5 500), 65 (forested strip 12 000 ≤ x < 14 500); raster ships as `sfincs.scs` (binary float32, 160 000 values × 4 B = 625 KiB, in inches) |
| Precipitation | Uniform-in-space step pulse, 2 mm/hr from t = 2 h to t = 12 h, zero elsewhere |

## Coverage axes touched

Each axis from the harness coverage matrix that this case exercises:

- **Geometry — regular grid at production resolution.** 400 × 400 ≫
  the existing `case_regular`'s 50 × 50 / `case_wavemaker`'s 50 × 50,
  driving per-step work into the regime where GPU kernels amortize
  launch overhead.
- **Infiltration — SCS Curve Number method A** (`inftype = cna`),
  spatially-varying. The other harness cases use either no
  infiltration or constant `inftype = con`, so this is the first
  exercise of the binary `scsfile` reader and the inches-to-metres
  conversion in `source/src/sfincs_infiltration_io.f90`.
- **Structures — one weir polyline carrying flux.** Verified active:
  the CPU baseline's `zsmax` shows a hydraulic jump from ~0.45 m
  (downstream/west of weir) to ~1.23 m (upstream/east of weir) along
  the river-channel row, well above the 1.0 m crest, confirming that
  the peak hydrograph drives flux over the weir during the run.
- **Discharges — non-trivial source/drain time series.** Stepped
  hydrograph (NOT constant), peak-to-baseflow ratio 10×.
- **Boundaries — tide-driven downstream + mass-flux upstream
  simultaneously.** The downstream open boundary at the west edge is
  driven by M2 + M4 tide; the upstream source cell injects the
  hydrograph; both are active over the entire 24 h window.
- **Meteo — time-varying precipitation.** Required to activate the
  SCS-CN infiltration code path (rainfall-driven by definition);
  small spatially-uniform forcing.

Deliberately NOT exercised here:

- **No subgrid topography.** The combination of subgrid + structures +
  infiltration is what triggers `case_production`'s GPU divergence at
  the 4452-cell scale (tracked in SOR-882's wider scope); replicating
  that combination at 160 000 cells is more likely to regress the GPU
  agreement gate. `case_production` already exercises subgrid +
  structures + infiltration; this case stays bare-DEM to isolate the
  per-step compute speedup signal.
- **No quadtree, no spiderweb meteo, no SnapWave, no wavemakers.** Each
  is exercised by another case.

## Validation gate

`tests/run_validation.sh` (1e-4 relative threshold) on this dev box:

| Configuration | Verdict | `max(|gpu - cpu|) / max(zsmax_cpu)` |
|---|---|---|
| `cpu` | baseline | — |
| `gpu_n1` | **PASS** | 8.36 × 10⁻⁵ |
| `gpu_n2` | **FAIL** | 8.95 × 10⁻² |

The `gpu_n2` failure is the project-wide multi-rank GPU defect tracked
by [SOR-846 — Shrink Phase-4 device shadows + renumber connectivity to
local indices](https://linear.app/etherpilot/issue/SOR-846). Every
other case in the harness fails `gpu_n2` at the same scale (≈ 92 %
drift caused by `gather_to_rank0_real4` rank-1-drop) — see the
`OVERALL: FAIL` row in any current `tests/run_validation.sh` summary.
This case inherits the same failure mode by construction; it is not a
case-specific divergence and the case design is sound at `gpu_n1`
(8.36 × 10⁻⁵, ~1.2× under the 1e-4 strict gate). When SOR-846 lands
on `main`, the `gpu_n2` row will become PASS without any case edits.

## License and provenance

All input files in this directory are authored for this validation
harness, released under the same GPL-3.0 as the rest of the SFINCS
repository. No external archive is fetched (the case fits in-tree at
~2.1 MB total). The single source of truth is `generate.py`:

| File | Provenance |
|---|---|
| `generate.py` | Authored for this harness. Deterministic generator, fixed RNG seeds (`20260509`, `20260510`). |
| `sfincs.inp` | Authored for this harness. |
| `sfincs.dep` | Generated by `generate.py` from a fixed seed. |
| `sfincs.msk` | Generated by `generate.py` (deterministic, no seed). |
| `sfincs.bnd` | Generated by `generate.py`. |
| `sfincs.bzs` | Generated by `generate.py` from a fixed seed (per-point phase offsets). |
| `sfincs.src` | Generated by `generate.py`. |
| `sfincs.dis` | Generated by `generate.py`. |
| `sfincs.weir` | Generated by `generate.py`. |
| `sfincs.scs` | Generated by `generate.py`. Binary float32, 160 000 values, m-outer/n-inner active-cell ordering matching `source/src/sfincs_infiltration_io.f90` `cna`'s `read(500)qinffield`. |
| `sfincs.prcp` | Generated by `generate.py`. |

The file FORMATS for `sfincs.src` / `sfincs.dis` / `sfincs.weir` were
cross-checked against
[Deltares/hydromt_sfincs](https://github.com/Deltares/hydromt_sfincs)'s
`tests/data/sfincs_test/` fixtures (GPL-3.0). Only the format shape
was referenced — the actual numerical content is authored fresh here.

## Regenerating the inputs

The generated files are committed in-tree so the harness picks them
up directly via the `tests/cases/*/` glob. Re-running the generator
produces byte-identical output:

```sh
cd tests/cases/case_prod_riverine
python3 generate.py
```

Required: Python 3 with `numpy`. No SFINCS build needed.

## Bench summary row

The benchmark harness's `tests/runs_bench/summary.json` rows for this
case from the implementer's dev-box run, quoted verbatim:

```json
{
  "case": "case_prod_riverine",
  "config": "cpu",
  "wall_clock_seconds": 400.32,
  "peak_memory_mb": 96.76,
  "max_abs_diff_zsmax": null,
  "max_zsmax_ref": null,
  "ratio_vs_ref": null,
  "verdict": "PASS",
  "speedup_vs_cpu": null
}
{
  "case": "case_prod_riverine",
  "config": "gpu_kieee",
  "wall_clock_seconds": 108.32,
  "peak_memory_mb": 29.0,
  "max_abs_diff_zsmax": 0.0003515481948852539,
  "max_zsmax_ref": 4.207345962524414,
  "ratio_vs_ref": 8.355580882022937e-05,
  "verdict": "PASS",
  "speedup_vs_cpu": 3.696
}
{
  "case": "case_prod_riverine",
  "config": "gpu_fastmath",
  "wall_clock_seconds": 109.57,
  "peak_memory_mb": 28.0,
  "max_abs_diff_zsmax": 0.00040203332901000977,
  "max_zsmax_ref": 4.207345962524414,
  "ratio_vs_ref": 9.555509163995374e-05,
  "verdict": "PASS",
  "speedup_vs_cpu": 3.654
}
```

Both GPU configurations show **speedup ≈ 3.7×** over the
`OMP_NUM_THREADS=1` CPU baseline, dominated by per-step kernel work
on this dev box (the ratio is dev-box-specific; see `tests/README.md`
"Comparability caveat"). Both pass the bench's 1e-3 ratio gate, and
the IEEE-strict GPU also passes the validation harness's stricter
1e-4 gate at `gpu_n1`.
