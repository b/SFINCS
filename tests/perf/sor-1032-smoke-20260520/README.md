# Perf sweep sor-1032-smoke-20260520

Captured by `tests/perf/run_full_perf_matrix.sh` on 2026-05-20T04:41:18Z.

## Files

* `capture_env.txt` — host CPU / GPU / container image / HEAD.
* `run.stdout` — orchestration log.
* `<case>__<grid>__<length>__<config>/` — per-cell artifacts.
* `plots/` — default plot set (PNGs).
* `explore.ipynb` — Jupyter notebook for interactive exploration.

## Re-rendering plots

```
cd /home/b/development/github/Deltares/SFINCS/.sorcerer/worktrees/SOR-1032/b-SFINCS
python3 -m tests.perf.analyze.plot --sweep tests/perf/sor-1032-smoke-20260520
```

## Opening the notebook

```
cd /home/b/development/github/Deltares/SFINCS/.sorcerer/worktrees/SOR-1032/b-SFINCS
python3 -m jupyter lab tests/perf/analyze/explore.ipynb
```

The notebook's default `SWEEP_DIR` points at the latest
`perf-scaling-sweep-*` directory. Set the `SWEEP_DIR` env var
to this directory's absolute path to point it here:

```
SWEEP_DIR=tests/perf/sor-1032-smoke-20260520 python3 -m jupyter lab tests/perf/analyze/explore.ipynb
```
