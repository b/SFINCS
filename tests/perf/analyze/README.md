# tests/perf/analyze — perf-sweep analysis layer

Load, plot, and compare perf-sweep artifacts produced by
`tests/perf/perf-scaling-sweep-*/run_perf_scaling.sh`.

## Install

```
python3 -m venv .venv && .venv/bin/pip install -r tests/perf/analyze/requirements.txt
```

## Modules

* `load.py` — `load_sweep(sweep_dir)` returns a pandas DataFrame with
  one row per `(case, grid, length, config)` cell. Columns:

  `case, grid, length, config, variant, wall, total_simulation_time,
  boundaries, momentum, continuity, snapwave, meteo, output,
  step_count, gpu_sm_p50, gpu_sm_p95, U_L, per_step, skipped,
  skipped_estimated_wall, cell_dir`

  Handles both the SOR-1017+ scaling-sweep directory layout
  (`<case>__<grid>__<length>__<config>/`) and the earlier SOR-87
  perf-matrix layout (`<case>__<config>__<pre|post>/`).

  **Skipped cells (SOR-1025).** `run_perf_scaling.sh` writes a
  `timings.txt` with a `skipped_estimated_wall <minutes>` line when
  the per-cell projection exceeds `PERF_MAX_CELL_WALL_MIN` (no SFINCS
  run for that cell). `load_sweep` surfaces these as rows with
  `skipped=True`, `wall=NaN`, and `skipped_estimated_wall=<minutes>`
  — the row is present in the DataFrame, not silently dropped.
  Downstream plots draw an `x` marker at the projected position
  rather than treating the cell as missing data.

* `plot.py` — renders the default PNG plots into
  `<sweep_dir>/plots/`. The original five are always rendered; the
  SOR-1037 saturation plot needs ≥ 2 gpu_n\<k\> rank counts; the three
  SOR-1025 plots are rendered only when the sweep carries cpu_n\<k\>
  cells for at least two distinct k values.

  1. `wall_vs_length.png`             — wall time vs simulation length per case.
  2. `per_step_vs_length.png`         — per-step `U(L)/step_count` (ms).
  3. `gpu_vs_cpu_speedup.png`         — `cpu_n128 / gpu_n2` speedup.
  4. `component_breakdown.png`        — stacked named components at
     `1x gpu_n2 4d`.
  5. `gpu_utilization.png`            — GPU sm % (`p50` line + `p95` envelope).
  6. `gpu_saturation_vs_rank.png`     — per-(case, grid) wall-time bars
     at the longest length, coloured green (helpful) or red (hurtful)
     by the rank-count increment direction, with a single-GPU SM% (p50)
     overlay on the right Y axis. Annotates `UNDERLOADED` when the
     single-GPU SM% mean is below a configurable threshold (default
     30%). The threshold is a function parameter — tune it for noisier
     captures or different workloads.
  7. `omp_scaling.png`                — wall vs cpu_n\<k\> threads
     (log-x), one line per length, per case. Projected (skipped) cells
     render as `x` markers; the knee of the 4d curve is annotated
     with a dashed vertical line.
  8. `omp_efficiency.png`             — strong-scaling efficiency
     `(ref_wall · ref_k / k) / cpu_n<k>_wall` vs threads (perfect = 1.0).
     The reference is `cpu_n1` when measured; falls back to the
     smallest measured k otherwise.
  9. `gpu_cpu_crossover_heatmap.png`  — heat map per case of
     `cpu_n<k>_wall / gpu_n<g>_wall`. Values > 1 (red-ish) are
     CPU-faster; < 1 (blue-ish) are GPU-faster. Built from the
     longest measured length per case.

  CLI:

  ```
  python -m tests.perf.analyze.plot --sweep tests/perf/perf-scaling-sweep-20260519
  python -m tests.perf.analyze.plot --sweep <current> --prior <baseline>
  ```

  When `--prior` (or env `PRIOR_SWEEP`) is supplied, paired
  `*_compare.png` plots are produced in the same `plots/` directory.

* `compare.py` — mechanical regen of the SUMMARY.md
  `Delta vs <prior> baseline` table; also appends the `GPU rank-count
  recommendation` section (best gpu_n\<k\> per case/grid, wall-time
  delta vs next-best, SM% of recommended config).

  ```
  python -m tests.perf.analyze.compare \
      --prior tests/perf/perf-scaling-sweep-20260519 \
      --current tests/perf/perf-scaling-sweep-20260519-post-sor1019 \
      > delta.md
  # single-sweep, recommendation section only:
  python -m tests.perf.analyze.compare \
      --current tests/perf/perf-scaling-sweep-20260519-post-sor1019 \
      --gpu-rank-recommendation
  ```

* `explore.ipynb` — Jupyter notebook with the default plots and
  ipywidgets controls for ad-hoc filtering. Open with:

  ```
  .venv/bin/jupyter lab tests/perf/analyze/explore.ipynb
  ```

  or with classic Jupyter (`jupyter notebook`). The top cell defines
  `SWEEP_DIR` — set it to any past sweep directory.

## One-shot end-to-end

`tests/perf/run_full_perf_matrix.sh` runs the capture sweep AND the
analyze layer, producing a self-contained results directory with the
default plots and a populated notebook. The canonical sweep template
lives at `tests/perf/run_perf_scaling.sh`; the orchestrator copies it
into the per-sweep output directory before invocation.

## Cost control: `PERF_MAX_CELL_WALL_MIN`

The CPU thread-count axis (`cpu_n1` … `cpu_n128`) makes the full
matrix infeasible at the smallest thread counts on long runs:
`cpu_n1` on `case_prod_regular_tide 1x 4d` projects to ~15 hours. The
harness measures the `cpu_n128` baseline first for each
`(case, grid, length)` and projects each smaller-k wall as
`cpu_n128_wall × 128 / k`. Cells whose projection exceeds
`PERF_MAX_CELL_WALL_MIN` minutes (default 30) are skipped with a
`skipped_estimated_wall <minutes>` annotation in `timings.txt`.

Override the budget per-invocation:

```
PERF_MAX_CELL_WALL_MIN=60 bash tests/perf/run_full_perf_matrix.sh
# or directly on the inner runner:
bash tests/perf/<sweep_dir>/run_perf_scaling.sh --max-cell-min 60
```
