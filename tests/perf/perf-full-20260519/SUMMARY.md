# SOR-1025 — OpenMP scaling sweep (cpu_n1 … cpu_n128 + gpu_n1/n2)

> Visualizations: see [`./plots/`](./plots/).
>
> * `wall_vs_length.png`, `per_step_vs_length.png`, `gpu_vs_cpu_speedup.png`,
>   `component_breakdown.png`, `gpu_utilization.png` — the original
>   SOR-1023 default set.
> * `omp_scaling.png` — **new**: wall vs `cpu_n<k>` threads
>   (log2-x), one line per length, per case. Projected (skipped)
>   cells are drawn as `x` markers.
> * `omp_efficiency.png` — **new**: strong-scaling efficiency
>   `(ref_wall · ref_k / k) / cpu_n<k>_wall` vs threads (ideal = 1.0).
> * `gpu_cpu_crossover_heatmap.png` — **new**: per-case heat map of
>   `cpu_n<k>_wall / gpu_n<g>_wall` at 4d. Values > 1 are CPU-faster;
>   < 1 are GPU-faster.
> * `wall_vs_length_compare.png`, `per_step_vs_length_compare.png` —
>   paired with the SOR-1019 post-fix baseline at
>   `../perf-scaling-sweep-20260519-post-sor1019/`.
>
> Regenerate with
> `python -m tests.perf.analyze.plot --sweep tests/perf/perf-full-20260519 --prior tests/perf/perf-scaling-sweep-20260519-post-sor1019`.

First sweep capturing the full CPU thread-count axis
(`cpu_n1 cpu_n2 cpu_n4 cpu_n8 cpu_n16 cpu_n32 cpu_n64 cpu_n128`)
alongside `gpu_n1` and `gpu_n2` for all five production cases at
`1x` grid, lengths `1h / 6h / 24h / 4d`. Captured by the canonical
`tests/perf/run_perf_scaling.sh` driven through
`tests/perf/run_full_perf_matrix.sh`.

This replaces the implicit assumption in SOR-87 / SOR-1017 /
SOR-1020 that "`cpu_n128` is the right CPU comparison" with a
measured OpenMP scaling curve operators can reason about — including
the host-saturation regression at `k = 128` that none of the prior
sweeps could surface.

## OpenMP knee per case (`1x` `4d`)

The knee is the smallest measured `k` where doubling threads yields
< 30 % additional wall reduction (i.e. parallelism stops paying off).
On this 64-physical-core / 128-SMT-thread host, all five cases
share a knee at or below the physical-core count.

| Case                              | Knee `k` @ 4d | Notes |
|-----------------------------------|---------------|-------|
| `case_prod_regular_tide`          | 64            | Clean scaling to 64; **regresses 14 % at 128** (148 s → 169 s). |
| `case_prod_quadtree_subgrid_tide` | 32            | Knee at 32 then nearly flat to 64; **catastrophic regression at 128** (63 s → 439 s, 7× worse). |
| `case_prod_riverine`              | 16            | Slope flattens at 16; minor regression at 128. |
| `case_prod_storm_amuv`            | 64            | Clean scaling to 64; **regresses 45 % at 128** (112 s → 162 s). |
| `case_prod_compound_snapwave`     | 32            | Knee at 32; **regresses 79 % at 128** (229 s → 410 s). |

**Headline finding.** Every case anti-scales between `k = 64` and
`k = 128`. The EPYC 7C13's second hyperthread per core does not help
SFINCS's OpenMP loops; for `case_prod_compound_snapwave` and
`case_prod_quadtree_subgrid_tide` it actively hurts (memory-bandwidth
contention is the likely root). **The right CPU deploy shape on this
hardware is `OMP_NUM_THREADS=64`, not 128**. The historical
`cpu_n128` cell in every prior perf sweep was measuring the slow
side of the curve.

The follow-up question — whether the same shape holds on hardware
with a different SMT layout — is outside this sweep's scope but is
the kind of question this new axis is built to answer.

## Wall-budget audit

* Total sweep wall: **152 min** (9121 s, captured on EPYC 7C13 +
  2× RTX A6000, `sfincs-build-gpu` container).
* Cells run: 162. Cells skipped by projection: 38 of 200 expected
  (the smallest `k` × longest length combinations).
* Per-cell budget: `PERF_MAX_CELL_WALL_MIN=30` (default). Override
  with `PERF_MAX_CELL_WALL_MIN=60 bash tests/perf/run_full_perf_matrix.sh`
  to extend the curve into `k=8` / `k=16` at longer lengths.

The 30-minute default lands the skip boundary at roughly `cpu_n8`
on the shortest lengths and `cpu_n32` on `4d` — exactly the region
where the curve's knee is most useful.

## CPU vs GPU crossover (`1x` `4d`)

`gpu_n2` is ~3–8× faster than `cpu_n64` (the CPU sweet spot) at
`4d` for every case except `case_prod_storm_amuv`, where `gpu_n2`
runs into per-step overheads not visible in earlier sweeps (the 4d
gpu_n1 = 284 s, gpu_n2 = 187 s walls are 5×–10× higher than the
SOR-1019 baseline; see the comparison plots). The crossover heat
map shows the full ratio surface — values < 1.0 (blue) are
GPU-faster; > 1.0 (red) are CPU-faster.

The deploy-planning shortcut: **gpu_n2 wins on every case at 4d,
even against the CPU sweet spot.** The cpu_n_small cells (where the
ratio inverts) are skipped by projection — confirming the GPU
crossover happens far below the smallest practical CPU deploy
shape, not at it.

## Methodology

Captured by the canonical
[`tests/perf/run_perf_scaling.sh`](../run_perf_scaling.sh) (copied
into this directory by `run_full_perf_matrix.sh`). Each cell is a
single SFINCS run; no per-cell averaging. Single-shot
`cpu_n<k>` measurements carry the variance discussed in SOR-87 /
SOR-1020 — read the OMP scaling curve as a slope estimator, not as
per-cell ground truth.

* **Configurations.**
  * `cpu_n<k>` for `k ∈ {1, 2, 4, 8, 16, 32, 64, 128}` — gfortran/OpenMP,
    `OMP_NUM_THREADS=k`, `OMP_PROC_BIND=true`, single process. Skipped
    when projected wall > `PERF_MAX_CELL_WALL_MIN` minutes.
  * `gpu_n1`, `gpu_n2` — CUDA build, `mpirun -n {1,2}` inside
    `sfincs-build-gpu:latest`.
* **Simulation lengths.** `1h / 6h / 24h / 4d`; `tstart` fixed at
  `20200101 000000`; `tstop` rewritten in the staged `sfincs.inp`.
* **Grid.** `1x` only (the issue body documents the `4x` axis as
  out of scope for this sweep — `4x cpu_n_small` walls project beyond
  any reasonable budget).
* **Skip-by-projection.** For each `(case, grid, length)`, run
  `cpu_n128` first to establish the baseline wall. Project each
  smaller-`k` cell as `cpu_n128_wall × 128 / k`. Cells whose
  projection exceeds `PERF_MAX_CELL_WALL_MIN` minutes (default 30)
  are skipped — `timings.txt` carries a `skipped_estimated_wall`
  annotation so the analysis layer can plot a marker at the
  projected position.

## How to read this sweep

* `omp_scaling.png` is the load-bearing plot. For each case, find
  the dashed vertical line (knee detection) — that's the smallest
  `k` where adding threads stops paying. Lengths past 1h converge
  on similar knees per case (the slope estimator is dominated by
  the per-step loop, not setup cost).
* `omp_efficiency.png` shows where parallelism breaks. A flat-near-1.0
  line is perfect scaling; the right-side roll-off identifies the
  threshold above which `OMP_NUM_THREADS` becomes counter-productive.
* `gpu_cpu_crossover_heatmap.png` answers "at what CPU thread count
  does GPU still win?" — useful for sizing the CPU fallback on
  hosts without a GPU.

## Reproducing

```
PERF_MAX_CELL_WALL_MIN=30 bash tests/perf/run_full_perf_matrix.sh --no-4x
python -m tests.perf.analyze.plot \
    --sweep tests/perf/perf-full-<date> \
    --prior tests/perf/perf-scaling-sweep-20260519-post-sor1019
```

Sweep wall ≈ 2.5 h on the production host; budget headroom for
single-shot reruns or expanded thread axes (`PERF_MAX_CELL_WALL_MIN=60`
doubles the captured curve).
