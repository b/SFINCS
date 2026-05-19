"""Render the default perf-sweep plot set as PNGs.

Five default plots, all five-subplot grids — one subplot per case in
the order ``case_prod_regular_tide / case_prod_quadtree_subgrid_tide /
case_prod_riverine / case_prod_storm_amuv / case_prod_compound_snapwave``:

1. ``wall_vs_length.png``      — wall time vs simulation length.
2. ``per_step_vs_length.png``  — per-step gap ``U(L)/step_count`` (ms).
3. ``gpu_vs_cpu_speedup.png``  — ``cpu_n128_wall / gpu_n2_wall``.
4. ``component_breakdown.png`` — stacked named components at
   ``1x gpu_n2 4d`` for each case.
5. ``gpu_utilization.png``     — gpu_sm_p50 + p95 envelope.

When a comparison sweep is supplied (CLI ``--prior`` or env
``PRIOR_SWEEP``), each of the five also gets a paired "prior vs
current" PNG in the same directory (``*_compare.png``).

Defaults: outputs land in ``<sweep_dir>/plots/``. CLI:

    python -m tests.perf.analyze.plot --sweep <sweep_dir>
    python -m tests.perf.analyze.plot --sweep <sweep_dir> --prior <other>
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from . import load

DEFAULT_CASE_ORDER = (
    "case_prod_regular_tide",
    "case_prod_quadtree_subgrid_tide",
    "case_prod_riverine",
    "case_prod_storm_amuv",
    "case_prod_compound_snapwave",
)
LENGTHS = ("1h", "6h", "24h", "4d")
LENGTH_SECONDS = {"1h": 3600, "6h": 21600, "24h": 86400, "4d": 345600}

CONFIG_COLORS = {
    "cpu_n128": "#4C72B0",  # blue
    "gpu_n1": "#DD8452",    # orange
    "gpu_n2": "#55A467",    # green
}
CONFIG_LABEL = {"cpu_n128": "cpu_n128", "gpu_n1": "gpu_n1", "gpu_n2": "gpu_n2"}

COMPONENT_COLORS = {
    "boundaries": "#4C72B0",
    "momentum": "#DD8452",
    "continuity": "#55A467",
    "snapwave": "#C44E52",
    "meteo": "#8172B2",
    "output": "#937860",
    "U_L": "#CCB974",
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _cases_in(df: pd.DataFrame) -> tuple[str, ...]:
    """Return cases present in df, preserving DEFAULT_CASE_ORDER where possible."""
    present = set(df["case"].dropna().unique())
    ordered = [c for c in DEFAULT_CASE_ORDER if c in present]
    extras = sorted(present - set(ordered))
    return tuple(ordered + extras)


def _series(df: pd.DataFrame, case: str, grid: str, config: str, column: str):
    """Return (x_seconds_array, y_values_array) for plotting."""
    sub = df[(df["case"] == case) & (df["grid"] == grid) & (df["config"] == config)]
    sub = sub.dropna(subset=["length"])
    xs, ys = [], []
    for L in LENGTHS:
        rows = sub[sub["length"] == L]
        if rows.empty:
            continue
        val = rows.iloc[0][column]
        if val != val:  # NaN
            continue
        xs.append(LENGTH_SECONDS[L])
        ys.append(float(val))
    return np.array(xs), np.array(ys)


def _figure_subtitle(env_text: str) -> str:
    """One-line capture-environment summary for figure subtitle."""
    if not env_text:
        return ""
    cpu = gpu = head = ""
    for raw in env_text.splitlines():
        line = raw.strip()
        if line.startswith("host CPU"):
            cpu = line.split(":", 1)[1].strip()
        elif line.startswith("host GPU"):
            gpu = line.split(":", 1)[1].strip()
        elif line.startswith("HEAD"):
            head = line.split(":", 1)[1].strip()
    pieces = []
    if cpu:
        pieces.append(f"CPU={cpu}")
    if gpu:
        pieces.append(f"GPU={gpu}")
    if head:
        pieces.append(f"HEAD={head}")
    return "  |  ".join(pieces)


def _layout(n_cases: int) -> tuple[int, int, tuple[int, int]]:
    """Return (nrows, ncols, figsize) for a per-case subplot grid."""
    if n_cases <= 3:
        return 1, n_cases, (5 * n_cases, 4)
    if n_cases <= 6:
        return 2, 3, (15, 8)
    rows = (n_cases + 2) // 3
    return rows, 3, (15, 4 * rows)


def _add_title(fig, title: str, subtitle: str) -> None:
    if subtitle:
        fig.suptitle(title + "\n" + subtitle, fontsize=12, y=0.995)
    else:
        fig.suptitle(title, fontsize=12, y=0.995)


def _save(fig, path: Path) -> None:
    fig.tight_layout(rect=(0, 0, 1, 0.96))
    fig.savefig(path, dpi=120)
    plt.close(fig)


# ---------------------------------------------------------------------------
# Individual plot builders
# ---------------------------------------------------------------------------

def _plot_metric_per_case(
    df: pd.DataFrame,
    title: str,
    ylabel: str,
    column: str,
    subtitle: str,
    out_path: Path,
    yscale: str = "log",
    transform=None,
) -> None:
    """Per-case 5-subplot grid plotting ``column`` for each (config, grid)."""
    cases = _cases_in(df)
    if not cases:
        return
    nrows, ncols, figsize = _layout(len(cases))
    fig, axes = plt.subplots(nrows, ncols, figsize=figsize, squeeze=False)
    flat = axes.flatten()
    for i, case in enumerate(cases):
        ax = flat[i]
        for config in ("cpu_n128", "gpu_n1", "gpu_n2"):
            for grid, style in (("1x", "-"), ("4x", "--")):
                xs, ys = _series(df, case, grid, config, column)
                if len(xs) == 0:
                    continue
                ys_plot = transform(ys) if transform else ys
                label = f"{CONFIG_LABEL[config]} ({grid})"
                ax.plot(
                    xs, ys_plot,
                    marker="o", linestyle=style,
                    color=CONFIG_COLORS[config],
                    label=label,
                )
        ax.set_xscale("log")
        if yscale == "log":
            ax.set_yscale("log")
        ax.set_xticks([LENGTH_SECONDS[L] for L in LENGTHS])
        ax.set_xticklabels(LENGTHS)
        ax.set_xlabel("simulation length")
        ax.set_ylabel(ylabel)
        ax.set_title(case, fontsize=10)
        ax.grid(True, which="both", alpha=0.3)
        if i == 0:
            ax.legend(loc="best", fontsize=8)
    for j in range(len(cases), nrows * ncols):
        flat[j].axis("off")
    _add_title(fig, title, subtitle)
    _save(fig, out_path)


def plot_wall_vs_length(df: pd.DataFrame, label: str, subtitle: str, out_path: Path) -> None:
    _plot_metric_per_case(
        df,
        title=f"Wall time vs simulation length — {label}",
        ylabel="wall time (s)",
        column="wall",
        subtitle=subtitle,
        out_path=out_path,
        yscale="log",
    )


def plot_per_step_vs_length(df: pd.DataFrame, label: str, subtitle: str, out_path: Path) -> None:
    _plot_metric_per_case(
        df,
        title=f"Per-step unaccounted gap vs simulation length — {label}",
        ylabel="per_step = U(L)/step_count (ms)",
        column="per_step",
        subtitle=subtitle,
        out_path=out_path,
        yscale="linear",
        transform=lambda ys: ys * 1000.0,
    )


def plot_gpu_vs_cpu_speedup(df: pd.DataFrame, label: str, subtitle: str, out_path: Path) -> None:
    """y = cpu_n128_wall / gpu_n2_wall per case; crossover where line > 1."""
    cases = _cases_in(df)
    if not cases:
        return
    nrows, ncols, figsize = _layout(len(cases))
    fig, axes = plt.subplots(nrows, ncols, figsize=figsize, squeeze=False)
    flat = axes.flatten()
    for i, case in enumerate(cases):
        ax = flat[i]
        for grid, style in (("1x", "-"), ("4x", "--")):
            xs_cpu, ys_cpu = _series(df, case, grid, "cpu_n128", "wall")
            xs_gpu, ys_gpu = _series(df, case, grid, "gpu_n2", "wall")
            if len(xs_cpu) == 0 or len(xs_gpu) == 0:
                continue
            # Align by length
            cpu_map = dict(zip(xs_cpu.tolist(), ys_cpu.tolist()))
            gpu_map = dict(zip(xs_gpu.tolist(), ys_gpu.tolist()))
            shared = sorted(set(cpu_map) & set(gpu_map))
            if not shared:
                continue
            speedup = np.array([cpu_map[s] / gpu_map[s] if gpu_map[s] > 0 else np.nan for s in shared])
            ax.plot(
                shared, speedup,
                marker="o", linestyle=style,
                color="#000000",
                label=f"{grid} grid",
            )
        ax.axhline(1.0, color="red", linestyle=":", alpha=0.5)
        ax.set_xscale("log")
        ax.set_xticks([LENGTH_SECONDS[L] for L in LENGTHS])
        ax.set_xticklabels(LENGTHS)
        ax.set_xlabel("simulation length")
        ax.set_ylabel("speedup (cpu_n128 / gpu_n2)")
        ax.set_title(case, fontsize=10)
        ax.grid(True, which="both", alpha=0.3)
        if i == 0:
            ax.legend(loc="best", fontsize=8)
    for j in range(len(cases), nrows * ncols):
        flat[j].axis("off")
    _add_title(fig, f"GPU vs CPU speedup vs simulation length — {label}", subtitle)
    _save(fig, out_path)


def plot_component_breakdown(df: pd.DataFrame, label: str, subtitle: str, out_path: Path) -> None:
    """Stacked-bar named components at 1x gpu_n2 4d per case."""
    cases = _cases_in(df)
    if not cases:
        return
    keys = ("boundaries", "momentum", "continuity", "snapwave", "meteo", "output", "U_L")

    fig, ax = plt.subplots(figsize=(max(8, 1.6 * len(cases)), 5))
    x = np.arange(len(cases))
    bottoms = np.zeros(len(cases))
    for key in keys:
        vals = []
        for case in cases:
            row = df[
                (df["case"] == case)
                & (df["grid"] == "1x")
                & (df["length"] == "4d")
                & (df["config"] == "gpu_n2")
            ]
            if row.empty:
                vals.append(0.0)
                continue
            v = row.iloc[0][key]
            vals.append(0.0 if v != v else float(v))
        vals_arr = np.array(vals)
        ax.bar(
            x, vals_arr, bottom=bottoms,
            label=key,
            color=COMPONENT_COLORS[key],
            edgecolor="white", linewidth=0.5,
        )
        bottoms = bottoms + vals_arr
    ax.set_xticks(x)
    ax.set_xticklabels([c.replace("case_prod_", "") for c in cases], rotation=20, ha="right")
    ax.set_ylabel("time (s)")
    ax.set_title("Named-component breakdown at 1x gpu_n2 4d", fontsize=10)
    ax.legend(loc="best", fontsize=8)
    ax.grid(True, axis="y", alpha=0.3)
    _add_title(fig, f"Component breakdown — {label}", subtitle)
    _save(fig, out_path)


def plot_gpu_utilization(df: pd.DataFrame, label: str, subtitle: str, out_path: Path) -> None:
    """gpu_sm_p50 + p95 envelope vs simulation length, per case."""
    cases = _cases_in(df)
    if not cases:
        return
    nrows, ncols, figsize = _layout(len(cases))
    fig, axes = plt.subplots(nrows, ncols, figsize=figsize, squeeze=False)
    flat = axes.flatten()
    for i, case in enumerate(cases):
        ax = flat[i]
        for config in ("gpu_n1", "gpu_n2"):
            for grid, style in (("1x", "-"), ("4x", "--")):
                xs_p50, ys_p50 = _series(df, case, grid, config, "gpu_sm_p50")
                xs_p95, ys_p95 = _series(df, case, grid, config, "gpu_sm_p95")
                if len(xs_p50) == 0:
                    continue
                ax.plot(
                    xs_p50, ys_p50,
                    marker="o", linestyle=style,
                    color=CONFIG_COLORS[config],
                    label=f"{config} p50 ({grid})",
                )
                if len(xs_p95) == len(xs_p50):
                    ax.fill_between(
                        xs_p50, ys_p50, ys_p95,
                        color=CONFIG_COLORS[config], alpha=0.15,
                    )
        ax.set_xscale("log")
        ax.set_xticks([LENGTH_SECONDS[L] for L in LENGTHS])
        ax.set_xticklabels(LENGTHS)
        ax.set_ylim(0, 100)
        ax.set_xlabel("simulation length")
        ax.set_ylabel("GPU sm %")
        ax.set_title(case, fontsize=10)
        ax.grid(True, which="both", alpha=0.3)
        if i == 0:
            ax.legend(loc="best", fontsize=8)
    for j in range(len(cases), nrows * ncols):
        flat[j].axis("off")
    _add_title(fig, f"GPU utilization (sm %) — {label}", subtitle)
    _save(fig, out_path)


# ---------------------------------------------------------------------------
# Compare-prior overlays
# ---------------------------------------------------------------------------

def _compare_metric_per_case(
    df_cur: pd.DataFrame, df_prior: pd.DataFrame,
    label_cur: str, label_prior: str,
    title: str, ylabel: str, column: str,
    subtitle: str, out_path: Path,
    yscale: str = "log",
    transform=None,
) -> None:
    cases = sorted(set(_cases_in(df_cur)) | set(_cases_in(df_prior)),
                   key=lambda c: DEFAULT_CASE_ORDER.index(c) if c in DEFAULT_CASE_ORDER else 99)
    if not cases:
        return
    nrows, ncols, figsize = _layout(len(cases))
    fig, axes = plt.subplots(nrows, ncols, figsize=figsize, squeeze=False)
    flat = axes.flatten()
    for i, case in enumerate(cases):
        ax = flat[i]
        for tag, frame, line_alpha in (("current", df_cur, 1.0), ("prior", df_prior, 0.55)):
            for config in ("cpu_n128", "gpu_n1", "gpu_n2"):
                xs, ys = _series(frame, case, "1x", config, column)
                if len(xs) == 0:
                    continue
                ys_plot = transform(ys) if transform else ys
                ax.plot(
                    xs, ys_plot,
                    marker="o" if tag == "current" else "x",
                    linestyle="-" if tag == "current" else ":",
                    color=CONFIG_COLORS[config],
                    alpha=line_alpha,
                    label=f"{config} {tag}",
                )
        ax.set_xscale("log")
        if yscale == "log":
            ax.set_yscale("log")
        ax.set_xticks([LENGTH_SECONDS[L] for L in LENGTHS])
        ax.set_xticklabels(LENGTHS)
        ax.set_xlabel("simulation length")
        ax.set_ylabel(ylabel)
        ax.set_title(case, fontsize=10)
        ax.grid(True, which="both", alpha=0.3)
        if i == 0:
            ax.legend(loc="best", fontsize=7, ncol=2)
    for j in range(len(cases), nrows * ncols):
        flat[j].axis("off")
    _add_title(fig, f"{title} — current={label_cur} vs prior={label_prior}", subtitle)
    _save(fig, out_path)


# ---------------------------------------------------------------------------
# Top-level driver
# ---------------------------------------------------------------------------

def render(
    sweep_dir: str | os.PathLike,
    prior_sweep_dir: str | os.PathLike | None = None,
    out_dir: str | os.PathLike | None = None,
) -> list[Path]:
    """Render the default plot set for a sweep directory.

    Returns the list of PNG paths written.
    """
    sweep = Path(sweep_dir)
    df = load.load_sweep(sweep)
    label = load.sweep_label(sweep)
    subtitle = _figure_subtitle(load.capture_env(sweep))

    if out_dir is None:
        out_dir = sweep / "plots"
    plots_dir = Path(out_dir)
    plots_dir.mkdir(parents=True, exist_ok=True)

    paths: list[Path] = []

    p = plots_dir / "wall_vs_length.png"
    plot_wall_vs_length(df, label, subtitle, p); paths.append(p)

    p = plots_dir / "per_step_vs_length.png"
    plot_per_step_vs_length(df, label, subtitle, p); paths.append(p)

    p = plots_dir / "gpu_vs_cpu_speedup.png"
    plot_gpu_vs_cpu_speedup(df, label, subtitle, p); paths.append(p)

    p = plots_dir / "component_breakdown.png"
    plot_component_breakdown(df, label, subtitle, p); paths.append(p)

    p = plots_dir / "gpu_utilization.png"
    plot_gpu_utilization(df, label, subtitle, p); paths.append(p)

    if prior_sweep_dir is not None:
        prior = Path(prior_sweep_dir)
        df_prior = load.load_sweep(prior)
        label_prior = load.sweep_label(prior)

        p = plots_dir / "wall_vs_length_compare.png"
        _compare_metric_per_case(
            df, df_prior, label, label_prior,
            title="Wall time vs simulation length",
            ylabel="wall time (s)", column="wall",
            subtitle=subtitle, out_path=p, yscale="log",
        )
        paths.append(p)

        p = plots_dir / "per_step_vs_length_compare.png"
        _compare_metric_per_case(
            df, df_prior, label, label_prior,
            title="Per-step unaccounted gap vs simulation length",
            ylabel="per_step (ms)", column="per_step",
            subtitle=subtitle, out_path=p, yscale="linear",
            transform=lambda ys: ys * 1000.0,
        )
        paths.append(p)

    return paths


def _main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Render perf-sweep plots.")
    p.add_argument("--sweep", required=True, help="Sweep directory to plot.")
    p.add_argument(
        "--prior",
        default=os.environ.get("PRIOR_SWEEP"),
        help="Optional prior-sweep directory for paired comparison plots.",
    )
    p.add_argument(
        "--out",
        default=None,
        help="Output directory (default: <sweep>/plots).",
    )
    args = p.parse_args(argv)
    paths = render(args.sweep, args.prior, args.out)
    for path in paths:
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
