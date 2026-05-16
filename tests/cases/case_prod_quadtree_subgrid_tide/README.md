# case_prod_quadtree_subgrid_tide

Production-scale SFINCS validation case combining a 3-level quadtree mesh
with subgrid topography under a multi-component (M2 + M4 + sea-level)
tidal boundary, 24 h window. The case is sized so that benchmark
wall-times are dominated by per-step kernel work, not GPU launch overhead
— the smaller cases (`case_regular`, `case_quadtree_tide`,
`case_production`, `case_snapwave`) all run in ≤ 15 s and report
`speedup_vs_cpu < 1×`. This case is the production-scale tier.

The mesh and subgrid NetCDF files are stored with zlib compression so
the in-tree size of `sfincs.nc + sfincs_subgrid.nc` combined is
≈ 3.5 MB — under the 5 MB in-tree budget — so the case ships its
inputs vendored alongside the harness, with no `fetch.sh` indirection.
SFINCS reads the compressed files transparently via netcdf-fortran;
verified end-to-end on this dev box.

## Provenance and license

All inputs are authored for this harness; there is no upstream fixture
that meets the ≥ 100 k effective cell bar. The single source of truth
is `generate.py` in this directory: it builds the quadtree mesh + the
subgrid tables + the boundary forcing deterministically from a small
parameter set (no RNG; no external DEM raster — bathymetry is
analytical), so the in-tree files can always be re-cut from this
script.

`generate.py` calls into the GPL-3.0 HydroMT-SFINCS quadtree-builder /
subgrid-builder (the user maintains a local checkout at
`../hydromt_sfincs`); the authored synthetic inputs are released
under this repo's GPL-3.0.

## Case characteristics

| Property | Value |
|---|---|
| Mesh type | Quadtree (`qtrfile = sfincs.nc`) |
| Total quadtree cells | 102880 |
| Active mask cells (mask > 0) | 102880 (102620 interior + 260 open-boundary; no inactive cells) |
| Cells per refinement level | L1: 5664; L2: 27520; L3: 69696 |
| Quadtree levels | 3 |
| Base grid | 130 × 130 cells at 200 m, no rotation |
| Coordinate reference | EPSG:32633 (UTM zone 33 N) |
| Bathymetry | analytical: −10 m offshore (west) → +5 m onshore (east) plus 0.20 m pixel-scale ripples |
| Subgrid tables | `sbgfile = sfincs_subgrid.nc`, 10 levels, 20 subgrid pixels per cell edge |
| Meteo / infiltration / structures / discharges / SnapWave | none (deliberately excluded — see below) |
| Boundary forcing | M2 (12.4206 h, 0.60 m) + M4 (6.2103 h, 0.15 m, +0.6 rad) + 0.20 m sea-level constant, 30 min sampling, applied identically at two `bndfile` points on the western edge |
| Integration window | 24 hours (`tstart = 20200101 000000`, `tstop = 20200102 000000`) |
| CPU baseline integration steps | ≈ 27970 (avg dt 3.089 s; well over the ≥ 10000 floor) |
| CPU baseline wall time | 587.8 s on this dev box (single-threaded, with another sorcerer cycle competing for CPU) |
| In-tree size (compressed) | 3.4 MB total (sfincs.nc 2.7 MB + sfincs_subgrid.nc 0.8 MB) |

## Coverage axes touched

- **Geometry:** quadtree at 3 refinement levels with > 100 k effective
  cells.
- **Subgrid:** yes (10 levels × 20 subgrid pixels per cell edge).
- **Boundaries:** tide M2 + M4 + sea-level on the western open
  boundary.
- **Meteo / infiltration / structures / discharges / SnapWave:** NONE.

The omitted features are excluded by design. Combining quadtree +
subgrid + spiderweb + structures + infiltration is the surface that
triggers SOR-882's `case_production` divergence; keeping this case to
quadtree + subgrid + tide ONLY makes the GPU agreement gate pass at
1e-4 without entanglement with that issue.

## Validation gate (`tests/run_validation.sh`)

The implementer's local `tests/run_validation.sh --skip-build --skip-fetch`
run on this dev box produced:

| Configuration | Verdict | Notes |
|---|---|---|
| `cpu` baseline | OK | 587.8 s wall; 27970+ steps; produces `sfincs_map.nc` |
| `gpu_n1` | **PASS** | `max_abs_diff = 7.15e-7`, `max_zsmax_ref = 0.986`, `ratio = 7.26e-7` < `1e-4` (verbatim from harness `RESULT` line) |
| `gpu_n2` | **FAIL** | `max_abs_diff = 1.39`, `ratio = 1.41` ≫ `1e-4` |

**`gpu_n2` blocker — SOR-846**
([Linear](https://linear.app/etherpilot/issue/SOR-846/shrink-phase-4-device-shadows-renumber-connectivity-to-local-indices)).
Every case in the harness fails `gpu_n2` on the same dev tree at this
commit (`case_regular`, `case_quadtree_tide`, `case_snapwave`, this
case) — the failure is harness-wide, not case-specific. SOR-846's
acceptance criteria explicitly include the `gpu_n2` PASS sweep across
all existing cases, so when SOR-846 lands this case's `gpu_n2`
verdict will become PASS along with the rest. The failure is therefore
not introduced by this case; it is the existing harness-wide
multi-rank divergence SOR-846 is designed to fix.

## Benchmark results (dev box)

### Benchmark refresh (clean box, 2026-05-16, SOR-901)

`tests/run_benchmarks.sh` run on a quiet box (no concurrent CPU
competitors, all 128 CPU threads via SOR-894's
`OMP_NUM_THREADS=$(nproc)`) — verbatim `tests/runs_bench/summary.json`
rows for this case:

```json
[
  {
    "case": "case_prod_quadtree_subgrid_tide",
    "config": "cpu",
    "wall_clock_seconds": 14.38,
    "peak_memory_mb": 130.82,
    "max_abs_diff_zsmax": null,
    "max_zsmax_ref": null,
    "ratio_vs_ref": null,
    "verdict": "PASS",
    "speedup_vs_cpu": null,
    "cpu_threads": 128
  },
  {
    "case": "case_prod_quadtree_subgrid_tide",
    "config": "gpu_kieee",
    "wall_clock_seconds": 80.92,
    "peak_memory_mb": 28.0,
    "max_abs_diff_zsmax": 7.152557373046875e-07,
    "max_zsmax_ref": 0.9857848882675171,
    "ratio_vs_ref": 7.255697929816359e-07,
    "verdict": "PASS",
    "speedup_vs_cpu": 0.178,
    "cpu_threads": null
  },
  {
    "case": "case_prod_quadtree_subgrid_tide",
    "config": "gpu_fastmath",
    "wall_clock_seconds": 79.23,
    "peak_memory_mb": 28.0,
    "max_abs_diff_zsmax": 7.152557373046875e-07,
    "max_zsmax_ref": 0.9857848882675171,
    "ratio_vs_ref": 7.255697929816359e-07,
    "verdict": "PASS",
    "speedup_vs_cpu": 0.181,
    "cpu_threads": null
  },
  {
    "case": "case_prod_quadtree_subgrid_tide",
    "config": "gpu_n2_kieee",
    "wall_clock_seconds": 57.78,
    "peak_memory_mb": 27.0,
    "max_abs_diff_zsmax": 6.4373016357421875e-06,
    "max_zsmax_ref": 0.9857848882675171,
    "ratio_vs_ref": 6.530128136834724e-06,
    "verdict": "PASS",
    "speedup_vs_cpu": 0.249,
    "cpu_threads": null
  },
  {
    "case": "case_prod_quadtree_subgrid_tide",
    "config": "gpu_n2_fastmath",
    "wall_clock_seconds": 60.12,
    "peak_memory_mb": 30.0,
    "max_abs_diff_zsmax": 6.4373016357421875e-06,
    "max_zsmax_ref": 0.9857848882675171,
    "ratio_vs_ref": 6.530128136834724e-06,
    "verdict": "PASS",
    "speedup_vs_cpu": 0.239,
    "cpu_threads": null
  }
]
```

All five rows clear the 1e-3 bench threshold (single-GPU
`ratio_vs_ref ≈ 7.3e-7`; dual-GPU `ratio_vs_ref ≈ 6.5e-6`, both far
below threshold). Against the 128-thread CPU baseline the GPU paths
now measure `speedup_vs_cpu` ≈ 0.18× (single-GPU) and ≈ 0.24×
(dual-GPU): on a fully-loaded 64-physical-core CPU, the GPU paths
trail the CPU on this case. The earlier "≈ 9.9×" banner from the
SOR-886 commit message and PR description is a CPU-contamination
artifact (see OLD section below); the honest ratio against a fair CPU
baseline is well below parity here, which the harness still PASSes
because the gate is correctness (`ratio_vs_ref < 1e-3`), not
throughput.

### OLD bench numbers (2026-05-09 contaminated; see SOR-901 for context)

Originally captured against a single-threaded CPU baseline
(`OMP_NUM_THREADS=1`, pre-SOR-894) on a box where two orphaned
`cargo test` binaries were pegging ~64 cores each for ~62 hours
continuously (see SOR-901's BODY for the forensic detail). Both
factors inflated the apparent GPU speedup:

```json
[
  {
    "case": "case_prod_quadtree_subgrid_tide",
    "config": "cpu",
    "wall_clock_seconds": 569.95,
    "peak_memory_mb": 130.82,
    "max_abs_diff_zsmax": null,
    "max_zsmax_ref": null,
    "ratio_vs_ref": null,
    "verdict": "PASS",
    "speedup_vs_cpu": null
  },
  {
    "case": "case_prod_quadtree_subgrid_tide",
    "config": "gpu_kieee",
    "wall_clock_seconds": 57.87,
    "peak_memory_mb": 29.0,
    "max_abs_diff_zsmax": 7.152557373046875e-07,
    "max_zsmax_ref": 0.9857848882675171,
    "ratio_vs_ref": 7.255697929816359e-07,
    "verdict": "PASS",
    "speedup_vs_cpu": 9.849
  },
  {
    "case": "case_prod_quadtree_subgrid_tide",
    "config": "gpu_fastmath",
    "wall_clock_seconds": 57.57,
    "peak_memory_mb": 28.0,
    "max_abs_diff_zsmax": 7.152557373046875e-07,
    "max_zsmax_ref": 0.9857848882675171,
    "ratio_vs_ref": 7.255697929816359e-07,
    "verdict": "PASS",
    "speedup_vs_cpu": 9.9
  }
]
```

The "≈ 9.9×" banner the SOR-886 commit message and PR description
quoted reflects those contaminated numbers; the 2026-05-16 refresh
above supersedes them as the authoritative figures for this case on
this dev box.

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
    tests/cases/case_prod_quadtree_subgrid_tide/generate.py \
    --out tests/cases/case_prod_quadtree_subgrid_tide
```

The generator finishes in ~2 minutes on this dev box for the default
130 × 130 base grid, producing the same files (deterministic — no
RNG).
