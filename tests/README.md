# SFINCS validation harness

This directory hosts a developer-only validation harness that compares CPU
SFINCS output against the GPU port. It is the first thing to run after a
non-trivial change to either build, before opening a PR.

## Purpose

`tests/run_validation.sh` builds the CPU and GPU SFINCS binaries, then runs
each test case under `tests/cases/` in three configurations — the CPU
baseline, GPU under `mpirun -n 1`, and GPU under `mpirun -n 2` — and diffs
each GPU run's `zsmax` against the CPU baseline using
`tests/scripts/diff_zsmax.py`. The harness gates each (case × GPU rank
count) pair on `max(|zsmax_gpu - zsmax_cpu|) / max(zsmax_cpu) < 1e-4` after
24 simulated hours, producing two PASS/FAIL/ERROR verdicts per case.
**Bit-exact agreement between CPU and GPU is explicitly NOT a goal**: the
two builds use different compilers (gfortran vs. nvfortran), different
floating-point reductions, and different parallel decompositions, so
small numerical drift is expected and tolerated up to the threshold.

## Prerequisites

The CPU build runs directly on the dev box; the GPU build runs inside a
container. The dev box needs:

- `gfortran`, `autoconf`, `automake`, `libtool`, `m4`, `pkg-config` —
  for the CPU autotools build.
- `libnetcdf-dev`, `libnetcdff-dev` — netCDF C and Fortran headers. Strictly
  optional: if `libnetcdff-dev` is absent the autotools build falls back to
  the bundled `third_party_open/netcdf/netcdf-fortran-4.6.1/`, but having
  the system package installed avoids surprises.
- Docker, with the `--gpus all` runtime configured (NVIDIA Container
  Toolkit installed and registered with the Docker daemon).
- The `sfincs-build-gpu:latest` image, built once from the Dockerfile at
  `source/build_scripts/Dockerfile_gpu` with:

  ```sh
  docker build -f source/build_scripts/Dockerfile_gpu \
      -t sfincs-build-gpu:latest source/build_scripts
  ```

  The Dockerfile contents are not duplicated here — read it for the
  package list and base image.
- `python3` on `$PATH` with `xarray` and `netcdf4` available for
  `diff_zsmax.py` (`pip install xarray netcdf4`).

## Hardware target

A workstation with **two NVIDIA GPUs visible to Docker**. The harness's
`mpirun -n 2` step launches two GPU ranks and pins each to a distinct
device, so a single-GPU host cannot complete the GPU-2-rank half of the
matrix.

## How to run

From the repository root:

```sh
tests/run_validation.sh
```

Optional flags:

- `--skip-build` — reuse the existing `source/install_cpu/bin/sfincs` and
  `source/install_cuda/bin/sfincs` binaries from a prior run. Useful when
  iterating on case inputs without touching Fortran.
- `--skip-fetch` — skip the per-case `fetch.sh` download step. Only
  affects `case_production`, which fetches its inputs on first run; the
  other two cases ship their inputs in-tree.
- `-h`, `--help` — print the harness's header comment.

The harness exits 0 iff every (case × GPU rank count) pair reports
PASS, otherwise 1.

## What each case covers

- **`case_regular`** — a 50 × 50 regular grid at 100 m spacing under a
  single-harmonic M2 tide, 24-hour run. Exercises the regular-grid path
  only: no subgrid, no quadtree, no spiderweb meteo, no infiltration, no
  structures. Fast smoke layer of the matrix.

- **`case_quadtree_tide`** — a 4452-cell quadtree mesh (three refinement
  levels over a 23 × 63 base grid at 200 m spacing, rotated 27°) under a
  single semidiurnal M2 tide, 24-hour run. Isolates the quadtree path
  from the rest: no subgrid, no spiderweb, no infiltration, no
  structures, no SnapWave.

- **`case_production`** — a production-style case combining subgrid
  topography, a quadtree mesh, a synthetic Holland-vortex spiderweb
  tropical-cyclone meteo, spatially-varying infiltration, and a weir-style
  structure, 24-hour run. Inputs are downloaded by
  `tests/cases/case_production/fetch.sh` on first run.

- **`case_snapwave`** — a 30 x 30 single-level quadtree mesh at 200 m
  spacing under a single-harmonic M2 tide, 24-hour run, with the
  SFINCS-SnapWave coupling enabled. The western column is both the
  SFINCS water-level boundary and the SnapWave wave boundary, fed by a
  single SnapWave support point with monochromatic wave conditions.
  Isolates the SnapWave coupling path; no subgrid, no spiderweb, no
  infiltration, no structures.

- **`case_wavemaker`** — a 50 × 50 regular grid at 100 m spacing with a
  single vertical wavemaker polyline injecting a monochromatic IG wave
  (Hm0 = 0.5 m, Tp = 60 s) into a flat-bottom closed basin, 24-hour run.
  Exercises the wavemaker code path (`update_wavemaker_fluxes` and the
  `sfincs_wavemaker_gpu.cuf` kernel) in isolation: no subgrid, no
  quadtree, no SnapWave coupling, no incident-wave forcing.

- **`case_prod_regular_tide`** — a 500 x 500 regular grid at 50 m
  spacing (~ 250 k total cells, ~ 168 k active wet cells) under a
  multi-component tidal water-level boundary (M2 + M4 + a +0.3 m mean
  sea-level constant), 24-hour run. Inputs are synthetic and
  re-generated deterministically from the case's `generate.py`. The
  production-scale tier of the matrix: large enough that per-step GPU
  kernel work dominates launch overhead, so the benchmark harness can
  report a meaningful CPU-vs-GPU speedup. Isolates the regular-grid +
  tide-boundary path: no subgrid, no quadtree, no meteo, no
  infiltration, no structures, no discharges, no wavemakers, no
  SnapWave.

- **`case_prod_riverine`** — a 400 × 400 regular grid at 50 m spacing
  (160 000 active z points, ~22 700 adaptive-CFL time steps over 24
  simulated hours), exercising **simultaneous boundary types**: a
  downstream tidal water-level boundary (M2 + M4 + sea-level on the
  west edge) and an upstream `srcfile`/`disfile` mass-flux source
  (stepped hydrograph) running together over the same window. Adds
  `inftype = cna` SCS Curve Number infiltration over a spatially-varying
  CN raster, time-varying precipitation, and one weir polyline carrying
  flux at the river midpoint. The harness's first production-scale tier
  case, sized to make `tests/runs_bench/summary.json`'s speedup ratio
  dominated by per-step compute rather than GPU launch overhead. No
  subgrid, no quadtree, no spiderweb, no SnapWave, no wavemakers.
  Inputs are generated in-tree by `case_prod_riverine/generate.py`
  from a fixed seed; no `fetch.sh`.

- **`case_prod_quadtree_subgrid_tide`** — a 102880-cell quadtree mesh
  (three refinement levels over a 130 × 130 base grid at 200 m spacing,
  no rotation) with subgrid topography under a multi-component
  M2 + M4 + sea-level tide, 24-hour run. Production-scale tier: sized
  so benchmark wall-times are dominated by per-step kernel work rather
  than GPU launch overhead. Inputs ship in-tree as zlib-compressed
  NetCDF (≈ 3.5 MB combined). No spiderweb, no infiltration, no
  structures, no SnapWave.

- **`case_prod_storm_amuv`** — a 400 × 400 regular grid at 50 m spacing
  (160 000 active cells) under gridded `amu` / `amv` wind components with a
  drifting wind front and a non-trivial meridional gradient, plus
  spatially-varying Green-Ampt infiltration (`infiltration_type = gai`,
  three soil rasters), tidal western boundary forcing, 24-hour run.
  Production-scale tier: large enough to amortise GPU launch overhead so
  `tests/run_benchmarks.sh` reports a measured speedup. Inputs are
  authored synthetically by the directory's `generate.py`.

## Where artifacts land

Each (case, configuration) pair stages its inputs into a clean directory
under `tests/runs/`:

```
tests/runs/<case>/cpu/        — CPU baseline run
tests/runs/<case>/gpu_n1/     — GPU run under mpirun -n 1
tests/runs/<case>/gpu_n2/     — GPU run under mpirun -n 2
```

Each contains `sfincs.log` (full stdout + stderr), `sfincs_map.nc` (the
output the diff tool reads), and the rest of SFINCS's NetCDF outputs.
`tests/runs/` is gitignored (`tests/.gitignore`), so artifacts are never
committed.

## Interpreting verdicts

Every GPU run feeds into `tests/scripts/diff_zsmax.py`, which prints a
single `RESULT ... verdict=...` line and exits with one of three codes:

- **PASS** — the diff tool found `max(|ref - cand|) / max(ref) < 1e-4`,
  `zsmax` had no NaN values in either run, and the run did not log
  `error = 1` (an internal SFINCS STOP). The (case, configuration) pair
  is considered correct.
- **FAIL** — the ratio is `>= 1e-4` with finite, well-shaped inputs. The
  GPU output drifted from the CPU baseline beyond what the threshold
  tolerates. Treat as a real divergence: investigate the GPU change that
  preceded the regression, compare per-cell diffs, and re-run rather than
  papering over with a wider threshold.
- **ERROR** — inputs were missing (no `sfincs_map.nc`), `zsmax` contained
  NaN, the two runs disagreed on shape, or `max(zsmax_ref) <= 0` (the
  case never produced a positive water level so the ratio is undefined).
  The harness also marks a configuration FAIL when the run itself failed
  to produce `sfincs_map.nc` or logged `error = 1` — those are setup
  failures distinct from numerical drift.

The summary table at the bottom of the run prints one line per (case,
configuration) pair plus an `OVERALL: PASS` or `OVERALL: FAIL` footer
controlling the exit code.

## Reproducibility note

The CPU runs are launched with `OMP_NUM_THREADS=1`. SFINCS's OpenMP
reductions are not associative under FP arithmetic, so the unconstrained
multi-threaded build produces slightly different output across re-runs
on the same machine. Pinning to a single thread suppresses that
non-determinism, so the harness's verdicts are reproducible: re-running
on the same machine against the same code yields the same PASS/FAIL
table. The GPU runs are similarly deterministic at fixed rank count.

## Updating the threshold

The `1e-4` threshold is hard-coded in `tests/run_validation.sh` (the
`THRESHOLD` variable near the top of the script) and is not exposed as a
flag. This is deliberate: the validation gate is a property of the GPU
port, not a per-invocation knob. If a relaxation is ever justified
(e.g., a new subsystem inherently produces wider drift), update both the
harness's `THRESHOLD` and the **Purpose** section of this README in the
same PR so the documented gate and the enforced gate stay in lockstep.

## Out of scope

The following are explicitly **not** covered by this harness:

- **Bit-exact CPU/GPU agreement** — see Purpose. The threshold tolerates
  small numerical drift by design.
- **Continuous integration** — the harness is dev-only. There is no GitHub
  Actions workflow, no TeamCity job, no automated runner that invokes
  `tests/run_validation.sh`.
- **Performance benchmarking** — `run_validation.sh` measures correctness
  only. A separate harness, `tests/run_benchmarks.sh`, measures wall-time
  and peak memory across the CPU, GPU IEEE-strict, and GPU fast-math
  builds; see the **Performance benchmarking** section below.
- **Non-hydrostatic and bathtub configurations** — none of the cases
  enable these, so the harness does not validate them. They remain
  CPU-only paths. (SnapWave is exercised by `case_snapwave`; the
  SnapWave solver itself runs on the host even in the GPU build, but
  the bridge that hands fields between SFINCS and SnapWave is GPU code
  the harness now diffs.)

## Performance benchmarking

`tests/run_benchmarks.sh` is the companion harness that measures
wall-time and peak resident memory across three SFINCS builds, on the
same three test cases the validation harness uses. Run from the repo
root:

```sh
tests/run_benchmarks.sh
```

It builds three configurations into separate prefixes:

- **`cpu`** — `source/install_cpu/bin/sfincs`, gfortran CPU baseline,
  `OMP_NUM_THREADS=1` for determinism.
- **`gpu_kieee`** — `source/install_cuda_kieee/bin/sfincs`, nvfortran with
  `-Kieee` (the default; matches CPU floating-point semantics).
- **`gpu_fastmath`** — `source/install_cuda_fastmath/bin/sfincs`,
  nvfortran with `--enable-fast-math` (drops `-Kieee`, permitting FMA
  contraction, denormal flushing, reciprocal approximations, and
  reassociation).

Each build's binary is run on every case under `tests/cases/` (one run
per `(case, build)` pair) under `tests/runs_bench/<case>/<config>/`,
wall-clock-timed via `/usr/bin/time -v`. Each GPU configuration is run
twice and only the second timing is recorded so first-run JIT / driver
init / page-cache costs do not pollute the steady-state measurement.
GPU runs are pinned to GPU 0 via `CUDA_VISIBLE_DEVICES=0`.

After all runs, each GPU run's `zsmax` is diffed against the CPU
baseline using `tests/scripts/diff_zsmax.py` against a loose threshold
of `1e-3`. The benchmark cares about **speedup**; the strict `1e-4`
correctness gate stays the validation harness's job. The fast-math
configuration is *expected* to drift from CPU at roughly the `1e-4`
level — that's the whole point of the comparison.

Output is two-fold:

- **Stdout.** A `BENCH-SUMMARY case=... config=... wall=... speedup=...
  ratio=... verdict=...` line per `(case, build)` pair (parseable via
  grep, in the spirit of `run_validation.sh`'s `RESULT case=...` line),
  followed by a fixed-width summary table.
- **`tests/runs_bench/summary.json`.** Machine-readable summary with one
  object per `(case, build)` pair containing: `case`, `config`,
  `wall_clock_seconds`, `peak_memory_mb`, `max_abs_diff_zsmax` (`null`
  for `cpu`), `max_zsmax_ref` (`null` for `cpu`), `ratio_vs_ref` (`null`
  for `cpu`), `verdict` (`PASS` / `FAIL` / `ERROR`), and
  `speedup_vs_cpu` (`null` for `cpu`, else `cpu_wall / config_wall`).

Exit code: 0 iff every `(case, build)` run completed without error AND
every GPU run's `ratio_vs_ref < 1e-3`. Otherwise 1.

Optional flags:

- `--skip-build` — reuse existing binaries from a prior run.
- `--skip-fetch` — skip per-case `fetch.sh` (only `case_production`
  fetches inputs).

Per-row detail (`sfincs.log`, `sfincs_map.nc`, `time.txt`) lands under
`tests/runs_bench/<case>/<config>/` for inspection.

### Quick smoke check

After all three binaries have been built once and `case_production`
inputs have been fetched, the cheapest way to re-confirm the bench
still passes end-to-end is:

```sh
tests/run_benchmarks.sh --skip-build --skip-fetch
```

This skips both the multi-minute autotools/nvfortran builds and the
`case_production` archive fetch, re-runs every `(case, config)` pair
against the existing `source/install_*/bin/sfincs` binaries, and
re-generates `tests/runs_bench/summary.json`. Exit code semantics are
unchanged (0 iff `OVERALL: PASS`).

### Memory measurement caveat

Peak memory is captured by `/usr/bin/time -v` on the host. For the CPU
build this is the sfincs process's resident set size. For GPU builds,
sfincs runs inside a container launched via `docker run`, so the host
RSS captured by `/usr/bin/time -v` is the docker client process — a
coarse host-side overhead indicator, not the in-container sfincs RSS or
the GPU's VRAM. For meaningful GPU memory measurements, observe with
`nvidia-smi` separately; that's out of scope for this harness.

### Comparability caveat

Wall-time numbers are dev-box-specific. They are not comparable across
machines, and they are not comparable across SFINCS versions (a kernel
rewrite can shift the steady-state cost in either direction). Treat
each invocation as a "what does the port buy on THIS box, TODAY"
snapshot — not a tracked metric. There is no continuous-benchmarking
runner, no historical store, no perf-regression alerting.
