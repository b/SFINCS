# case_prod_compound_snapwave

Production-scale SFINCS compound-flooding validation case combining a
3-level quadtree mesh with subgrid topography and the SFINCS-SnapWave
coupling, run under **simultaneous tide + wave boundaries** — a
multi-component (M2 + M4 + sea-level) tide on the SFINCS open boundary
AND a storm-event Hs/Tp time series on the SnapWave wave-spectrum
boundary along the same western edge, 24 h window. Sized so benchmark
wall-times are dominated by per-step kernel work, not GPU launch
overhead.

The mesh and subgrid NetCDF files are stored with zlib compression so
the in-tree size of `sfincs.nc + sfincs_subgrid.nc` plus the in-tree
forcing files combined is ≈ 3.4 MB — under the 5 MB in-tree budget —
so the case ships its inputs vendored alongside the harness, with no
`fetch.sh` indirection. SFINCS reads the compressed files transparently
via netcdf-fortran; verified end-to-end on this dev box.

## Provenance and license

All inputs are authored for this harness; there is no upstream fixture
that meets the ≥ 100 k effective cell bar. The single source of truth
is `generate.py` in this directory: it builds the quadtree mesh + the
subgrid tables + the SFINCS tidal boundary forcing + the SnapWave
wave-spectrum forcing deterministically from a small parameter set (no
RNG; no external DEM raster — bathymetry is analytical), so the in-tree
files can always be re-cut from this script.

`generate.py` calls into the GPL-3.0 HydroMT-SFINCS quadtree-builder /
subgrid-builder (the user maintains a local checkout at
`../hydromt_sfincs`); the authored synthetic inputs are released under
this repo's GPL-3.0.

## Case characteristics

| Property | Value |
|---|---|
| Mesh type | Quadtree (`qtrfile = sfincs.nc`) |
| Total quadtree cells | 102880 |
| Active mask cells (`mask > 0`) | 102880 (102620 interior + 260 open-boundary; no inactive cells) |
| Active SnapWave cells (`snapwave_mask > 0`) | 102880 (102620 interior + 260 wave-spectrum boundary; same mask layout) |
| Cells per refinement level | L1: 5664; L2: 27520; L3: 69696 |
| Quadtree levels | 3 |
| Base grid | 130 × 130 cells at 200 m, no rotation |
| Coordinate reference | EPSG:32633 (UTM zone 33 N) |
| Bathymetry | analytical: −10 m offshore (west) → +5 m onshore (east) plus 0.20 m pixel-scale ripples |
| Subgrid tables | `sbgfile = sfincs_subgrid.nc`, 10 levels, 20 subgrid pixels per cell edge |
| SFINCS open-boundary forcing | M2 (12.4206 h, 0.60 m) + M4 (6.2103 h, 0.15 m, +0.6 rad) + 0.20 m sea-level constant, 30 min sampling, applied identically at two `sfincs.bnd` points on the western edge |
| SnapWave wave-spectrum forcing | Hs storm event ramped 1.0 m → 4.0 m over 0–12 h, held at 4.0 m through 18 h, decayed to 1.0 m by 24 h; Tp tracking Hs (6 s + 1.5 × Hs, clipped 6–12 s); mean wave direction 270° (westward incoming, nautical convention); directional spreading 25°; 30 min sampling at the same two western-edge support points |
| `dtwave` | 1800 s (the SnapWave solver fires every 30 min over the 24 h window — 49 invocations including endpoints) |
| Meteo / infiltration / structures / discharges / wavemakers | none (deliberately excluded — see below) |
| Integration window | 24 hours (`tstart = 20200101 000000`, `tstop = 20200102 000000`) |
| CPU baseline integration steps | ≈ 28000 (avg dt 3.086 s; well over the ≥ 10000 floor) |
| CPU baseline wall time | 290.2 s under `tests/run_validation.sh` (single-threaded), 284.8 s under `tests/run_benchmarks.sh BENCH_CPU_THREADS=1` (also single-threaded) on this dev box; see `## Benchmark results` for verbatim summary rows |
| In-tree size (compressed) | 3.4 MB total (sfincs.nc 2.7 MB + sfincs_subgrid.nc 0.8 MB + forcing files ≈ 0.01 MB) |

## Coverage axes touched

- **Geometry:** quadtree at 3 refinement levels with > 100 k effective
  cells.
- **Subgrid:** yes (10 levels × 20 subgrid pixels per cell edge).
- **SnapWave coupling:** yes (`snapwave = 1` with the full
  `snapwave_bnd / snapwave_bhs / snapwave_btp / snapwave_bwd /
  snapwave_bds` file family driving the wave-spectrum boundary).
- **Boundaries:** **simultaneous** tide M2 + M4 + sea-level on the SFINCS
  open boundary AND a storm-event Hs/Tp time series on the SnapWave
  wave-spectrum boundary — both active over the entire 24 h window
  along the same western edge. This is the second simultaneous-boundary
  instance in the production-scale tier (the first, tide + mass-flux,
  lives in `case_prod_riverine`).
- **Meteo / infiltration / structures / discharges / wavemakers:** NONE.

The omitted features are excluded by design. Combining quadtree +
subgrid + spiderweb + structures + infiltration is the surface that
triggers SOR-882's `case_production` divergence; keeping this case to
quadtree + subgrid + SnapWave + simultaneous tide+wave only avoids that
entanglement so the SnapWave + simultaneous-boundary coverage is not
gated on independently-tracked GPU divergence work.

## Validation gate (`tests/run_validation.sh`)

The implementer's local `tests/run_validation.sh --skip-build --skip-fetch`
run on this dev box produced the following verdicts for this case
(verbatim from the harness's `RESULT` lines + summary table):

| Configuration | Verdict | Notes |
|---|---|---|
| `cpu` baseline | OK | 290.2 s wall; ≈ 28000 steps (avg dt 3.086 s); produces `sfincs_map.nc` with `max(zsmax) = 0.998` over 87715 valid cells |
| `gpu_n1` | **PASS** | `max_abs_diff = 2.128e-5`, `max_zsmax_ref = 0.998`, `ratio = 2.133e-5` < `1e-4` (verbatim from harness `RESULT` line) |
| `gpu_n2` | **FAIL** (ERROR / segfault) | mpirun ranks segfault at the start of the simulation immediately after SnapWave initialization completes on both ranks; no `sfincs_map.nc` is produced |

**`gpu_n2` blocker — SOR-959**
([Linear](https://linear.app/etherpilot/issue/SOR-959/fix-multi-gpu-n-2-zsmax-output-gather-correctness-on-sparseqaudtree)).
SOR-959 is the umbrella issue for multi-GPU `n=2` correctness on
quadtree / large / SnapWave-coupled meshes; its acceptance criteria
list explicitly carves out the two SnapWave-coupled cases
(`case_snapwave` and **`case_prod_compound_snapwave`**) as out-of-scope
for SOR-959 itself and notes that "any pre-existing FAIL / ERROR / HUNG
on `gpu_n2` is acceptable and must be called out as out-of-scope in
the PR description". The segfault here matches that out-of-scope shape
exactly: SnapWave under `mpirun -n 2` is a known harness-wide gap that
SOR-959 acknowledges, calls out by name, and intentionally leaves for a
follow-on issue. The failure is therefore not introduced by this case;
the case ships with its `gpu_n2` verdict documented per SOR-959's
out-of-scope policy.

## Benchmark results (dev box)

The implementer's local `BENCH_CPU_THREADS=1 tests/run_benchmarks.sh --skip-build --skip-fetch`
run on this dev box (2× NVIDIA RTX A6000; single-threaded CPU baseline
for cross-host repeatability — matches the methodology used by the
sibling `case_prod_quadtree_subgrid_tide`; concurrent sorcerer sessions
were holding two stale `case_snapwave:gpu_n2` SFINCS processes on GPU
0 throughout the run) — verbatim `tests/runs_bench/summary.json` rows
for this case:

```json
[
  {
    "case": "case_prod_compound_snapwave",
    "config": "cpu",
    "wall_clock_seconds": 284.84,
    "peak_memory_mb": 374.4,
    "max_abs_diff_zsmax": null,
    "max_zsmax_ref": null,
    "ratio_vs_ref": null,
    "verdict": "PASS",
    "speedup_vs_cpu": null,
    "cpu_threads": 1
  },
  {
    "case": "case_prod_compound_snapwave",
    "config": "gpu_kieee",
    "wall_clock_seconds": 142.28,
    "peak_memory_mb": 27.0,
    "max_abs_diff_zsmax": 0.0001443624496459961,
    "max_zsmax_ref": 0.9975285530090332,
    "ratio_vs_ref": 0.00014472011774553065,
    "verdict": "PASS",
    "speedup_vs_cpu": 2.002,
    "cpu_threads": null
  },
  {
    "case": "case_prod_compound_snapwave",
    "config": "gpu_fastmath",
    "wall_clock_seconds": 134.26,
    "peak_memory_mb": 27.0,
    "max_abs_diff_zsmax": 0.0001443624496459961,
    "max_zsmax_ref": 0.9975285530090332,
    "ratio_vs_ref": 0.00014472011774553065,
    "verdict": "PASS",
    "speedup_vs_cpu": 2.122,
    "cpu_threads": null
  }
]
```

The bench harness ran with `BENCH_CPU_THREADS=1` (single-threaded CPU
baseline) for cross-host repeatability — matches the methodology the
sibling `case_prod_quadtree_subgrid_tide` README documents. Both GPU
configs measure `speedup_vs_cpu` > 1.0× (satisfying the production-scale
tier AC) AND `ratio_vs_ref` ≈ 1.45e-4 — well below the bench harness's
loose `1e-3` threshold. The bench number is larger than the validation
harness's `gpu_n1` ratio (2.13e-5) because the bench's `gpu_kieee` /
`gpu_fastmath` binaries live in `install_cuda_kieee` /
`install_cuda_fastmath` (separate nvfortran builds with bench-specific
flag combinations), distinct from the validation harness's
`install_cuda` binary; both binaries clear their respective gates.

Speedups are lower than the pure-quadtree sibling case
(2.0× vs ~2.9×) because the SnapWave solver itself runs on the host
even in the GPU build — Amdahl's law: ≈ 15% of the validation
harness's single-threaded CPU baseline wall is `Time in SnapWave`, which
the GPU build does not accelerate.

The harness's overall summary at the bottom of this same run reported
`OVERALL: PASS` across every `(case, config)` pair on this dev tree
(14 cases × 3 configs = 42 rows).

## Re-cutting the inputs

If the inputs ever need to be re-cut (mesh shape changes, forcing
shape changes, subgrid tables regenerated against an updated builder),
re-run the generator and overwrite the in-tree files. Both `sfincs.nc`
and `sfincs_subgrid.nc` are written with zlib compression
(`complevel=4`); the helper inside `generate.py` does this
automatically when called with `--out` pointed at this directory.

To re-cut locally (requires a Python environment with hydromt-sfincs
and its deps; the implementer used a pip venv at
`/tmp/sfincs-hydromt-venv` populated from the local
`../hydromt_sfincs` checkout):

```sh
/tmp/sfincs-hydromt-venv/bin/python3 \
    tests/cases/case_prod_compound_snapwave/generate.py \
    --out tests/cases/case_prod_compound_snapwave
```

The generator finishes in ~2 minutes on this dev box for the default
130 × 130 base grid, producing the same files (deterministic — no
RNG).
