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
  step_count, gpu_sm_p50, gpu_sm_p95, U_L, per_step, cell_dir`

  Handles both the SOR-1017+ scaling-sweep directory layout
  (`<case>__<grid>__<length>__<config>/`) and the earlier SOR-87
  perf-matrix layout (`<case>__<config>__<pre|post>/`).

* `plot.py` — renders six default PNG plots into
  `<sweep_dir>/plots/`:

  1. `wall_vs_length.png`           — wall time vs simulation length per case.
  2. `per_step_vs_length.png`       — per-step `U(L)/step_count` (ms).
  3. `gpu_vs_cpu_speedup.png`       — `cpu_n128 / gpu_n2` speedup.
  4. `component_breakdown.png`      — stacked named components at
     `1x gpu_n2 4d`.
  5. `gpu_utilization.png`          — GPU sm % (`p50` line + `p95` envelope).
  6. `gpu_saturation_vs_rank.png`   — per-case wall bars at the longest
     length, colored green/red by whether adding ranks helped or hurt,
     with a single-GPU SM% overlay and an `UNDERLOADED` annotation on
     subplots whose single-GPU SM% is below the configured threshold
     (default 30%). Identifies cases where adding GPUs makes things
     worse at a glance.

  CLI:

  ```
  python -m tests.perf.analyze.plot --sweep tests/perf/perf-scaling-sweep-20260519
  python -m tests.perf.analyze.plot --sweep <current> --prior <baseline>
  ```

  When `--prior` (or env `PRIOR_SWEEP`) is supplied, paired
  `*_compare.png` plots are produced in the same `plots/` directory.

* `compare.py` — mechanical regen of SUMMARY.md sections:
  - `Delta vs <prior> baseline` table.
  - `GPU rank-count recommendation` table — per (case, grid), the best
    rank-count config by wall, the delta vs the next-best, and the
    single-GPU SM% at the same cell.

  ```
  python -m tests.perf.analyze.compare \
      --prior tests/perf/perf-scaling-sweep-20260519 \
      --current tests/perf/perf-scaling-sweep-20260519-post-sor1019 \
      --rank-recommendation > delta.md

  # Or just the rank-count section (no --prior needed):
  python -m tests.perf.analyze.compare \
      --current tests/perf/perf-scaling-sweep-20260519-post-sor1019 \
      --rank-only
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
default plots and a populated notebook.
