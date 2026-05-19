"""Mechanically regenerate SUMMARY.md sections from sweep directories.

Two sections are produced:

1. ``Delta vs prior baseline`` (the existing hand-curated table):

       | case | metric | pre-fix | post-fix | Δ (abs) | Δ (%) |
       |------|--------|---------|----------|---------|-------|

   By default compares the ``1x gpu_n2 4d`` cell per case (the cell the
   SOR-1020 SUMMARY.md focuses on); ``--grid``, ``--config``,
   ``--length`` override.

2. ``GPU rank-count recommendation`` — per (case, grid), the best
   rank-count config by wall time at the longest available length,
   the wall delta versus the next-best rank config, and the single-
   GPU SM% of the recommended config. Pass ``--rank-recommendation``
   to append it, or ``--rank-only`` to emit just that section
   (no ``--prior`` needed).

CLI:

    python -m tests.perf.analyze.compare --prior <dir> --current <dir>
    python -m tests.perf.analyze.compare --prior <dir> --current <dir> \\
        --rank-recommendation > delta.md
    python -m tests.perf.analyze.compare --current <dir> --rank-only
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


GPU_RANK_CONFIGS = ("gpu_n1", "gpu_n2")  # mirror plot.GPU_RANK_CONFIGS


def render_rank_count_recommendation(
    sweep: str,
    grids: tuple[str, ...] | None = None,
    cases: tuple[str, ...] | None = None,
) -> str:
    """Build the per-(case, grid) GPU rank-count recommendation section.

    Walks every (case, grid) cell present in the sweep, picks the best
    rank-count config by wall time at the longest available length, and
    reports the wall delta versus the next-best config plus the single-
    GPU SM% of the recommended config.
    """
    df = load.load_sweep(sweep)
    if df.empty:
        return "### GPU rank-count recommendation\n\n_(no data)_\n"

    if cases is None:
        present = set(df["case"].dropna().unique())
        cases = tuple(c for c in DEFAULT_CASE_ORDER if c in present)
    if grids is None:
        grids_present = sorted(set(df["grid"].dropna().unique()))
        grids = tuple(g for g in ("1x", "4x") if g in grids_present)

    lines: list[str] = []
    lines.append("### GPU rank-count recommendation")
    lines.append("")
    lines.append(
        "Per (case, grid): best rank-count config by wall time at the "
        "longest length available, with the wall-time delta versus the "
        "next-best rank config and the single-GPU (gpu_n1) SM% at the "
        "same cell. ``Δ vs next`` is negative when the best config "
        "saves time."
    )
    lines.append("")
    lines.append(
        "| case | grid | length | best | best wall (s) | next | next wall (s) | "
        "Δ vs next (s) | Δ vs next (%) | single-GPU SM% |"
    )
    lines.append(
        "|------|------|--------|------|---------------|------|---------------|"
        "---------------|---------------|----------------|"
    )

    for case in cases:
        for grid in grids:
            row = _rank_count_row(df, case, grid)
            if row is not None:
                lines.append(row)

    return "\n".join(lines) + "\n"


def _rank_count_row(df: pd.DataFrame, case: str, grid: str) -> str | None:
    """Return one markdown table row for (case, grid), or None if no data."""
    sub = df[
        (df["case"] == case)
        & (df["grid"] == grid)
        & (df["config"].isin(GPU_RANK_CONFIGS))
    ]
    if sub.empty:
        return None
    # Longest length among gpu_n* cells for this (case, grid).
    length_order = {"1h": 0, "6h": 1, "24h": 2, "4d": 3}
    present_lens = [L for L in sub["length"].dropna().unique() if L in length_order]
    if not present_lens:
        return None
    longest = max(present_lens, key=length_order.get)
    cell = sub[sub["length"] == longest]

    walls: dict[str, float] = {}
    sm: dict[str, float] = {}
    for cfg in GPU_RANK_CONFIGS:
        row = cell[cell["config"] == cfg]
        if row.empty:
            continue
        wall = row.iloc[0]["wall"]
        if wall == wall:
            walls[cfg] = float(wall)
        sm_val = row.iloc[0]["gpu_sm_p50"]
        sm[cfg] = float(sm_val) if sm_val == sm_val else float("nan")
    if not walls:
        return None

    ranked = sorted(walls.items(), key=lambda kv: kv[1])
    best_cfg, best_wall = ranked[0]
    if len(ranked) >= 2:
        next_cfg, next_wall = ranked[1]
        delta_abs = best_wall - next_wall
        delta_pct = (delta_abs / next_wall * 100.0) if next_wall else float("nan")
        delta_abs_s = f"{delta_abs:+.3f}"
        delta_pct_s = f"{delta_pct:+.1f}%" if delta_pct == delta_pct else "—"
        next_cfg_s = next_cfg
        next_wall_s = f"{next_wall:.3f}"
    else:
        next_cfg_s = "—"
        next_wall_s = "—"
        delta_abs_s = "—"
        delta_pct_s = "—"

    sm_single = sm.get("gpu_n1", float("nan"))
    sm_s = f"{sm_single:.0f}%" if sm_single == sm_single else "—"

    return (
        f"| `{case}` | {grid} | {longest} | {best_cfg} | "
        f"{best_wall:.3f} | {next_cfg_s} | {next_wall_s} | "
        f"{delta_abs_s} | {delta_pct_s} | {sm_s} |"
    )


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
    p.add_argument("--prior", help="Prior sweep directory (omit when only "
                                   "rendering --rank-recommendation).")
    p.add_argument("--current", required=True, help="Current sweep directory.")
    p.add_argument("--grid", default="1x")
    p.add_argument("--length", default="4d")
    p.add_argument("--config", default="gpu_n2")
    p.add_argument(
        "--rank-recommendation",
        action="store_true",
        help="Append the GPU rank-count recommendation section to the output.",
    )
    p.add_argument(
        "--rank-only",
        action="store_true",
        help="Emit only the GPU rank-count recommendation section "
             "(--prior is not required).",
    )
    p.add_argument("--out", default=None,
                   help="Write to this path (default: stdout).")
    args = p.parse_args(argv)

    parts: list[str] = []
    if not args.rank_only:
        if not args.prior:
            p.error("--prior is required unless --rank-only is set")
        parts.append(render_delta_table(
            prior_sweep=args.prior,
            current_sweep=args.current,
            grid=args.grid,
            length=args.length,
            config=args.config,
        ))
    if args.rank_only or args.rank_recommendation:
        if parts:
            parts.append("")
        parts.append(render_rank_count_recommendation(args.current))

    md = "\n".join(parts)

    if args.out is None:
        sys.stdout.write(md)
    else:
        Path(args.out).write_text(md)
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
