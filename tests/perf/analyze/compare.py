"""Mechanically regenerate the SUMMARY.md ``Delta vs prior baseline`` table.

Given two sweep directories, emit the markdown table format that's
currently hand-curated in SUMMARY.md:

    | case | metric | pre-fix | post-fix | Δ (abs) | Δ (%) |
    |------|--------|---------|----------|---------|-------|
    | <case> | wall (s) | ... | ... | ... | ... |
    | <case> | total_simulation_time (s) | ... | ... | ... | ... |
    | <case> | U(L) unaccounted (s) | ... | ... | ... | ... |
    | <case> | per_step (ms) | ... | ... | ... | ... |
    ...

By default compares the ``1x gpu_n2 4d`` cell per case (the cell the
SOR-1020 SUMMARY.md focuses on); ``--grid``, ``--config``, ``--length``
override.

CLI:

    python -m tests.perf.analyze.compare --prior <dir> --current <dir>
    python -m tests.perf.analyze.compare --prior <dir> --current <dir> > delta.md
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pandas as pd

from . import load

DEFAULT_CASE_ORDER = (
    "case_prod_regular_tide",
    "case_prod_quadtree_subgrid_tide",
    "case_prod_riverine",
    "case_prod_storm_amuv",
    "case_prod_compound_snapwave",
)

METRICS = (
    ("wall", "wall (s)", 1.0, 3),
    ("total_simulation_time", "total_simulation_time (s)", 1.0, 3),
    ("U_L", "U(L) unaccounted (s)", 1.0, 3),
    ("per_step", "per_step (ms)", 1000.0, 4),
)


def _select_cell(df: pd.DataFrame, case: str, grid: str, length: str, config: str):
    sub = df[
        (df["case"] == case)
        & (df["grid"] == grid)
        & (df["length"] == length)
        & (df["config"] == config)
    ]
    if sub.empty:
        return None
    return sub.iloc[0]


def _fmt(val: float, places: int) -> str:
    if val != val:  # NaN
        return "—"
    return f"{val:.{places}f}"


def _delta_row(case: str, metric_key: str, label: str, scale: float, places: int,
               pre: pd.Series, post: pd.Series) -> str:
    pv = pre[metric_key] if pre is not None else float("nan")
    cv = post[metric_key] if post is not None else float("nan")
    if pv != pv or cv != cv:
        return f"| `{case}` | {label} | {_fmt(pv*scale, places)} | {_fmt(cv*scale, places)} | — | — |"
    delta = (cv - pv) * scale
    pct = ((cv - pv) / pv * 100.0) if pv != 0 else float("nan")
    delta_s = f"{delta:+.{places}f}" if pv == pv and cv == cv else "—"
    pct_s = f"{pct:+.1f}%" if pct == pct else "—"
    return f"| `{case}` | {label} | {_fmt(pv*scale, places)} | {_fmt(cv*scale, places)} | {delta_s} | {pct_s} |"


def render_delta_table(
    prior_sweep: str,
    current_sweep: str,
    grid: str = "1x",
    length: str = "4d",
    config: str = "gpu_n2",
    cases: tuple[str, ...] | None = None,
) -> str:
    """Build the markdown delta table comparing two sweeps."""
    df_prior = load.load_sweep(prior_sweep)
    df_current = load.load_sweep(current_sweep)

    if cases is None:
        present = set(df_prior["case"].unique()) | set(df_current["case"].unique())
        cases = tuple(c for c in DEFAULT_CASE_ORDER if c in present)

    prior_label = load.sweep_label(prior_sweep)
    current_label = load.sweep_label(current_sweep)

    lines: list[str] = []
    lines.append(
        f"### Delta — current=`{current_label}` vs prior=`{prior_label}`"
        f"  ({grid} {config} {length})"
    )
    lines.append("")
    lines.append(f"| case | metric | {prior_label} | {current_label} | Δ (abs) | Δ (%) |")
    lines.append("|------|--------|---------|----------|---------|-------|")
    for case in cases:
        pre = _select_cell(df_prior, case, grid, length, config)
        post = _select_cell(df_current, case, grid, length, config)
        for metric_key, label, scale, places in METRICS:
            lines.append(_delta_row(case, metric_key, label, scale, places, pre, post))
    return "\n".join(lines) + "\n"


def _main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Mechanical SUMMARY.md delta table.")
    p.add_argument("--prior", required=True, help="Prior sweep directory.")
    p.add_argument("--current", required=True, help="Current sweep directory.")
    p.add_argument("--grid", default="1x")
    p.add_argument("--length", default="4d")
    p.add_argument("--config", default="gpu_n2")
    p.add_argument("--out", default=None,
                   help="Write to this path (default: stdout).")
    args = p.parse_args(argv)

    md = render_delta_table(
        prior_sweep=args.prior,
        current_sweep=args.current,
        grid=args.grid,
        length=args.length,
        config=args.config,
    )

    if args.out is None:
        sys.stdout.write(md)
    else:
        Path(args.out).write_text(md)
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
