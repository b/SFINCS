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

Also exposes ``render_gpu_rank_recommendation`` — a single-sweep section
that mechanically reports the best ``gpu_n<k>`` config per (case, grid)
along with the wall-time delta vs the next-best config and the SM%
of the recommended config.

CLI:

    python -m tests.perf.analyze.compare --prior <dir> --current <dir>
    python -m tests.perf.analyze.compare --prior <dir> --current <dir> > delta.md
    python -m tests.perf.analyze.compare --current <dir> --gpu-rank-recommendation
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pandas as pd

from . import load
from . import plot as _plot

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


def render_gpu_rank_recommendation(
    sweep: str,
    sm_threshold_pct: float = 30.0,
) -> str:
    """Return the "GPU rank-count recommendation" markdown section.

    Per (case, grid) combo in the sweep where at least two
    ``gpu_n<k>`` configs are measured at the same length, lists:

    - best config (``gpu_n<k>`` with minimum wall time at that length)
    - wall-time delta vs the next-best config (seconds)
    - SM% of the recommended config (``gpu_sm_p50``)

    Cases flagged UNDERLOADED (single-GPU SM% < ``sm_threshold_pct``)
    are marked with an ``†`` and a footnote so the operator can see at
    a glance which recommendations come from an underloaded baseline.
    """
    df = load.load_sweep(sweep)
    entries = _plot.compute_gpu_saturation_panel(df, sm_threshold_pct=sm_threshold_pct)
    label = load.sweep_label(sweep)

    lines: list[str] = []
    lines.append(f"### GPU rank-count recommendation — `{label}`")
    lines.append("")
    if not entries:
        lines.append("_No (case, grid) combos with ≥ 2 gpu_n&lt;k&gt; configs._")
        return "\n".join(lines) + "\n"
    lines.append(
        f"Threshold for UNDERLOADED annotation: SM% < {sm_threshold_pct:.0f}."
    )
    lines.append("")
    lines.append(
        "| case | grid | length | best config | next-best | "
        "Δ wall (s) vs next-best | SM% of best |"
    )
    lines.append(
        "|------|------|--------|-------------|-----------|"
        "------------------------|-------------|"
    )
    for e in entries:
        underloaded_mark = " †" if e["underloaded"] else ""
        delta = e["delta_vs_next_best"]
        sm = e["best_sm"]
        sm_str = f"{sm:.0f}%" if sm == sm else "—"
        lines.append(
            f"| `{e['case']}` | {e['grid']} | {e['length']} | "
            f"**{e['best_config']}**{underloaded_mark} | {e['next_best_config']} | "
            f"{delta:+.2f} | {sm_str} |"
        )
    if any(e["underloaded"] for e in entries):
        lines.append("")
        lines.append(
            f"† UNDERLOADED — single-GPU SM% mean below the "
            f"{sm_threshold_pct:.0f}% threshold; adding ranks may add "
            "halo-exchange overhead without proportional compute payoff."
        )
    return "\n".join(lines) + "\n"


def _main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Mechanical SUMMARY.md delta table.")
    p.add_argument("--prior", default=None, help="Prior sweep directory.")
    p.add_argument("--current", required=True, help="Current sweep directory.")
    p.add_argument("--grid", default="1x")
    p.add_argument("--length", default="4d")
    p.add_argument("--config", default="gpu_n2")
    p.add_argument(
        "--gpu-rank-recommendation",
        action="store_true",
        help="Emit the GPU rank-count recommendation section for --current.",
    )
    p.add_argument(
        "--sm-threshold-pct",
        type=float,
        default=30.0,
        help="UNDERLOADED-annotation threshold for the GPU rank-count section.",
    )
    p.add_argument("--out", default=None,
                   help="Write to this path (default: stdout).")
    args = p.parse_args(argv)

    if args.gpu_rank_recommendation:
        md = render_gpu_rank_recommendation(
            sweep=args.current,
            sm_threshold_pct=args.sm_threshold_pct,
        )
    else:
        if not args.prior:
            p.error("--prior is required unless --gpu-rank-recommendation is set")
        md = render_delta_table(
            prior_sweep=args.prior,
            current_sweep=args.current,
            grid=args.grid,
            length=args.length,
            config=args.config,
        )
        # Append the GPU rank-count recommendation section so the
        # operator gets a one-shot SUMMARY refresh from a single
        # compare.py invocation; existing SUMMARY content above is
        # preserved by the operator's existing paste workflow.
        rec = render_gpu_rank_recommendation(
            sweep=args.current,
            sm_threshold_pct=args.sm_threshold_pct,
        )
        md = md + "\n" + rec

    if args.out is None:
        sys.stdout.write(md)
    else:
        Path(args.out).write_text(md)
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
