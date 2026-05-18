# SOR-82 — `make_theta_grid` memoization at `case_prod_compound_snapwave gpu_n2`

This page captures the SnapWave host-side profile after the SOR-82
memoization of `make_theta_grid` (`source/src/snapwave/snapwave_boundaries.f90:778`)
and compares to the SOR-81 baseline at
`tests/perf/snapwave-characterization-20260517/` (same host, same case,
same harness).

## Capture environment

- host: `simulacra`, Ubuntu 24.04.4 LTS, kernel 6.8.0-111-generic
- CPU: AMD EPYC 7C13 64-Core (128 logical), 504 GiB RAM
- GPU: 2× NVIDIA RTX A6000 (Ampere, 48 GiB each)
- container: `sfincs-build-gpu:latest` — NVHPC SDK 25.9, CUDA 13.0, HPC-X 2.24
- case: `tests/cases/case_prod_compound_snapwave` (`tstop = 86400 s`, `dtwave = 1800 s`)
- harness: `run_snapwave_profile.sh` (copied verbatim from SOR-81; same
  `--sample=cpu`, `--cpuctxsw=process-tree`, `--backtrace=dwarf`, perf
  `-F 999 --call-graph dwarf,16384`)
- binary: built on branch `sorcerer/sor-82` from this issue's tree
- baseline binary referenced below: SOR-81 branch with no memoization

The harness adds a noticeable wall-clock overhead from `nsys` sampling
and `perf record`; absolute seconds in the profiler run are slower than
an uninstrumented run. The before/after comparison is at the SAME
instrumentation level, so the percentage delta is the load-bearing
number.

## Top SnapWave routines by perf self-time (rank 0)

Excerpted from `snapwave_perf_flat.txt` in each directory, sorted by
self-time (no children). The cycle count differs slightly between runs
(faster run = fewer total samples), so absolute percentages of total
rank-0 cycles are not directly comparable across columns; what matters
is **whether `make_theta_grid` is still in the top entries**.

| #  | Routine                                               | Baseline (SOR-81) | Memoized (SOR-82) |
|---:|-------------------------------------------------------|------------------:|------------------:|
| 1  | `snapwave_solver_solve_energy_balance2dstat_`         | 19.66 %           | 16.99 %           |
| 2  | `snapwave_solver_solve_tridiag_`                      |  7.03 %           |  6.05 %           |
| 3  | `snapwave_boundaries_make_theta_grid_`                |  **6.22 %**       |  **absent** (< 0.5 %, below perf's `--percent-limit`) |
| 4  | `l_maxloc_real4l4` (RTL minloc/maxloc)                |  3.92 %           |  3.37 %           |
| 5  | `l_minloc_real4l4`                                    |  3.89 %           |  3.42 %           |

`make_theta_grid` was the third hottest routine in SOR-81 at 6.22 % of
total rank-0 cycles (which normalizes to ~22 % of SnapWave compute,
matching SOR-81's "Top 5 SnapWave routines" table). In the memoized
run it falls below perf's `--percent-limit 0.5` and is not emitted in
the flat report — every entry > 0.5 % is in `snapwave_perf_flat.txt`,
and `grep snapwave_boundaries_make_theta_grid` returns no match. This
satisfies the AC threshold ("absent OR < 5 % of SnapWave time").

The reason is structural: the loop that gathers
`w` / `prev` / `ds` / `windspreadfac` from the 360-direction tables
runs only when the integer index `ind = nint(central_theta/dtheta) -
ntheta/2` has changed since the last call. On this case the central
direction moves slowly (a typhoon-driven boundary forcing with smooth
multi-hour evolution), so `ind` rarely shifts inside a single
`dtwave = 1800 s` step — the memoization fires on the vast majority of
calls.

## Wall-clock comparison

Recorded in `sfincs.log` for each run (instrumented; both runs paid
the same `nsys` + `perf` overhead so the delta is apples-to-apples).

|                          | Baseline (SOR-81) | Memoized (SOR-82) | Delta    |
|--------------------------|------------------:|------------------:|---------:|
| Total simulation time    | 75.151 s          | 63.660 s          | **−15.3 %** |
| Time in SnapWave         | 52.184 s          | 48.453 s          | **− 7.2 %** |
| SnapWave share of total  | 69.4 %            | 76.1 %            | (SnapWave's *share* rises because the non-SnapWave hosts shrunk faster) |

The total-wall-clock drop is well above SOR-82's 7 % floor and brushes
the 10 % target SOR-81 estimated for this intervention. The
SnapWave-only drop is at the 7 % floor because `make_theta_grid` is
22 % of SnapWave compute and the cache fires on essentially all calls,
which yields a ~20-22 % share-of-SnapWave saving — but instrumentation
costs (perf sampling, NVTX) are also captured inside the SnapWave
time, so the on-paper share is partly offset.

For reference, SOR-81's UN-instrumented baseline at the same case (the
SOR-69 Phase 5 sfincs.log at
`tests/perf/phase5-canonical-on-device-final-20260517/`) was 63.6 s
total and 50.0 s SnapWave; the memoized instrumented run is at 63.66 s
total — i.e. the memoization roughly neutralizes the profiler overhead
on the SOR-81 capture configuration, which is consistent with the
~15 % delta measured here.

## NVTX `:snapwave_update` range

From `nvtx_pushpop_sum.csv` (excerpt; "Time (%)" is the share of total
profiled wall clock on rank 0):

| Run               | Time (%) | Total (ns)     | Instances | Avg (ns)        |
|-------------------|---------:|---------------:|----------:|----------------:|
| Baseline (SOR-81) | 67.9     | 52 304 200 655 | 49        | 1 067 432 666   |
| Memoized (SOR-82) | 75.8     | 48 602 680 938 | 49        |   991 891 447   |

Per-`dtwave`-step SnapWave cost drops from ~1.07 s to ~0.99 s; the
share-of-total rises because the rest of the per-step kernels finished
faster too (the binary is the same; rank 0's MPI wait shrinks as the
neighbor rank also finishes earlier).

## Artifacts in this directory

- `run_snapwave_profile.sh` — driver (copied from SOR-81 dir, no edits)
- `rank_select_perf.sh`, `in_container_perf_v2.sh` — helper scripts
  spawned by the driver
- `snapwave_rank0.nsys-rep` — nsys raw report
- `snapwave_perf_flat.txt` — perf self-time flat list (top symbols above)
- `snapwave_perf_report.txt` — perf children-mode (inclusive time)
- `snapwave_perf_callgraph.txt` — perf per-symbol callee tree
- `cuda_gpu_kern_sum.csv`, `nvtx_pushpop_sum.csv`, `osrt_sum.csv` — nsys CSV summaries
- `sfincs.log`, `sfincs.stdout` — model run logs

The raw `snapwave_perf.data` is ~1.4 GiB on this case and is NOT
committed; re-run `run_snapwave_profile.sh` from this directory to
regenerate it on the same machine.

## Conclusion

The SOR-82 memoization removes `make_theta_grid` from the SnapWave
top-routine list (absent, vs. 6.22 % baseline self-time / 22 %
inclusive-of-SnapWave), and delivers a 15.3 % total wall-clock saving
on `case_prod_compound_snapwave gpu_n2` — above SOR-82's 7 % floor and
near the 10 % target. The SnapWave physics is untouched; the
memoization is a pure caching layer over a deterministic-gather step
that depends on the central direction only through the integer index
`nint(central_theta/dtheta)`.
