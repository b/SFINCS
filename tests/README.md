# SFINCS validation harness

This directory hosts a developer-only validation harness that compares CPU
SFINCS output against the GPU port. It is the first thing to run after a
non-trivial change to either build, before opening a PR.

## Purpose

`tests/run_validation.sh` builds the CPU and GPU SFINCS binaries, then runs
each of the three test cases under `tests/cases/` in three configurations —
the CPU baseline, GPU under `mpirun -n 1`, and GPU under `mpirun -n 2` — and
diffs each GPU run's `zsmax` against the CPU baseline using
`tests/scripts/diff_zsmax.py`. The harness gates each (case × GPU rank
count) pair on `max(|zsmax_gpu - zsmax_cpu|) / max(zsmax_cpu) < 1e-4` after
24 simulated hours, producing six PASS/FAIL/ERROR verdicts in total.
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

The harness exits 0 iff all six (case × GPU rank count) pairs report
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
- **Performance benchmarking** — wall-time and throughput are not measured
  or compared; only `zsmax` correctness is.
- **Non-hydrostatic, bathtub, or SnapWave-on-GPU configurations** — none
  of the three cases enable these, so the harness does not validate
  them. They remain CPU-only paths.
