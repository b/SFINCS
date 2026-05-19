"""Render the default perf-sweep plot set as PNGs.

Six default plots, all five-subplot grids — one subplot per case in
the order ``case_prod_regular_tide / case_prod_quadtree_subgrid_tide /
case_prod_riverine / case_prod_storm_amuv / case_prod_compound_snapwave``:

1. ``wall_vs_length.png``           — wall time vs simulation length.
2. ``per_step_vs_length.png``       — per-step gap ``U(L)/step_count`` (ms).
3. ``gpu_vs_cpu_speedup.png``       — ``cpu_n128_wall / gpu_n2_wall``.
4. ``component_breakdown.png``      — stacked named components at
   ``1x gpu_n2 4d`` for each case.
5. ``gpu_utilization.png``          — gpu_sm_p50 + p95 envelope.
6. ``gpu_saturation_vs_rank.png``   — per-case wall bars vs rank
   count (gpu_n1, gpu_n2) at the longest available length, with a
   single-GPU SM% overlay and an ``UNDERLOADED`` annotation on
   subplots whose single-GPU SM% is below the configured threshold.
   Bar colors encode whether the next rank-count step helped (green)
   or hurt (red), so cases where adding GPUs makes things worse are
   visually obvious without reading axis values.

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
# GPU saturation vs rank count
# ---------------------------------------------------------------------------

# Bar colors keyed by the "n+1 vs n" wall delta direction.
RANK_HELP_COLOR = "#55A467"   # green — adding ranks reduced wall
RANK_HURT_COLOR = "#C44E52"   # red   — adding ranks increased wall
SM_OVERLAY_COLOR = "#444444"  # marker color for SM% overlay
UNDERLOAD_THRESHOLD_DEFAULT = 30.0
GPU_RANK_CONFIGS = ("gpu_n1", "gpu_n2")  # extend when gpu_n4 etc. land


def _longest_length_present(rows: pd.DataFrame) -> str | None:
    """Return the longest length tag (1h<6h<24h<4d) present in rows."""
    if rows.empty:
        return None
    have = set(rows["length"].dropna().unique())
    for L in reversed(LENGTHS):
        if L in have:
            return L
    return None


def _saturation_cell(df: pd.DataFrame, case: str, grid: str) -> dict | None:
    """Collect the per-rank wall/SM% values for one (case, grid) saturation panel.

    Returns ``None`` when there's no usable data (no gpu_n* cells at any
    shared length). Otherwise returns a dict with keys:

      length       — the longest length shared by at least one rank config
      walls        — {rank_config: wall_seconds}
      sm_p50       — {rank_config: gpu_sm_p50 at this cell (may be NaN)}
      best_config  — rank config with the lowest wall
      sm_overlay   — single-GPU (gpu_n1) SM% used for the UNDERLOADED check
    """
    sub = df[(df["case"] == case) & (df["grid"] == grid)
             & (df["config"].isin(GPU_RANK_CONFIGS))]
    if sub.empty:
        return None
    length = _longest_length_present(sub)
    if length is None:
        return None
    cell = sub[sub["length"] == length]
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
    best_config = min(walls, key=walls.get)
    sm_overlay = sm.get("gpu_n1", float("nan"))
    return {
        "length": length,
        "walls": walls,
        "sm_p50": sm,
        "best_config": best_config,
        "sm_overlay": sm_overlay,
    }


def _bar_colors_for(walls: dict[str, float]) -> list[str]:
    """Return bar colors per GPU_RANK_CONFIGS in order.

    n=1 is always neutral (baseline). For n>=2, color is green when the
    wall decreased vs n-1, red when it increased or stayed the same.
    Configs missing from ``walls`` get a neutral light-grey placeholder.
    """
    colors: list[str] = []
    for i, cfg in enumerate(GPU_RANK_CONFIGS):
        if cfg not in walls:
            colors.append("#cccccc")
            continue
        if i == 0:
            colors.append(RANK_HELP_COLOR)
            continue
        prev = GPU_RANK_CONFIGS[i - 1]
        if prev not in walls:
            colors.append(RANK_HELP_COLOR)
            continue
        colors.append(RANK_HELP_COLOR if walls[cfg] < walls[prev] else RANK_HURT_COLOR)
    return colors


def plot_gpu_saturation(
    df: pd.DataFrame,
    out_dir: str | os.PathLike,
    sm_threshold: float = UNDERLOAD_THRESHOLD_DEFAULT,
    grid: str = "1x",
    label: str | None = None,
    subtitle: str = "",
    filename: str = "gpu_saturation_vs_rank.png",
) -> Path:
    """Render the per-case GPU-saturation-vs-rank-count panel.

    Each subplot is one case. The left Y axis shows wall time (s) per
    rank count (one bar per GPU_RANK_CONFIGS entry) at the longest
    length available for that (case, grid). Bars are colored green
    when adding the rank reduced wall, red when it increased wall.
    The right Y axis overlays the single-GPU (gpu_n1) SM% as a marker.
    Subplots whose gpu_n1 SM% is below ``sm_threshold`` are annotated
    "UNDERLOADED — n2 adds overhead without compute payoff".

    Writes ``<out_dir>/<filename>`` and returns the path.
    """
    out_path = Path(out_dir) / filename
    cases = _cases_in(df)
    if not cases:
        # Nothing to plot — still write an empty placeholder so callers
        # can chain without worrying about whether the file exists.
        Path(out_dir).mkdir(parents=True, exist_ok=True)
        fig, ax = plt.subplots(figsize=(6, 3))
        ax.text(0.5, 0.5, "no cases in sweep", ha="center", va="center",
                transform=ax.transAxes)
        ax.axis("off")
        _save(fig, out_path)
        return out_path

    nrows, ncols, figsize = _layout(len(cases))
    fig, axes = plt.subplots(nrows, ncols, figsize=figsize, squeeze=False)
    flat = axes.flatten()

    x_positions = np.arange(len(GPU_RANK_CONFIGS))
    rank_ticks = [c.removeprefix("gpu_n") for c in GPU_RANK_CONFIGS]

    for i, case in enumerate(cases):
        ax = flat[i]
        cell = _saturation_cell(df, case, grid)
        if cell is None:
            ax.text(0.5, 0.5, f"{case}\n(no gpu_n* data at grid={grid})",
                    ha="center", va="center", transform=ax.transAxes, fontsize=8)
            ax.axis("off")
            continue

        walls = cell["walls"]
        sm_p50 = cell["sm_p50"]
        colors = _bar_colors_for(walls)

        heights = [walls.get(cfg, 0.0) for cfg in GPU_RANK_CONFIGS]
        # Mark missing configs with a hatch + lighter color so the
        # eye doesn't read a missing config as "zero wall".
        bar_container = ax.bar(
            x_positions, heights,
            color=colors,
            edgecolor="black", linewidth=0.7,
            width=0.5,
        )
        for cfg, bar in zip(GPU_RANK_CONFIGS, bar_container):
            if cfg not in walls:
                bar.set_hatch("//")
                bar.set_alpha(0.4)

        # Annotate each bar with its wall value.
        for cfg, bar in zip(GPU_RANK_CONFIGS, bar_container):
            if cfg not in walls:
                continue
            v = walls[cfg]
            ax.text(
                bar.get_x() + bar.get_width() / 2.0,
                v,
                f"{v:.1f}s",
                ha="center", va="bottom", fontsize=8,
            )

        ax.set_xticks(x_positions)
        ax.set_xticklabels(rank_ticks)
        ax.set_xlabel("rank count")
        ax.set_ylabel("wall time (s)")
        max_wall = max((v for v in walls.values()), default=1.0)
        ax.set_ylim(0, max_wall * 1.35 if max_wall > 0 else 1.0)
        ax.grid(True, axis="y", alpha=0.3)

        # Right-Y overlay: SM% per rank as a marker.
        ax_r = ax.twinx()
        ax_r.set_ylim(0, 100)
        ax_r.set_ylabel("single-GPU SM% (overlay)", fontsize=8)
        sm_xs, sm_ys = [], []
        for j, cfg in enumerate(GPU_RANK_CONFIGS):
            v = sm_p50.get(cfg, float("nan"))
            if v == v:
                sm_xs.append(x_positions[j])
                sm_ys.append(v)
        if sm_xs:
            ax_r.plot(sm_xs, sm_ys, marker="D", linestyle=":",
                      color=SM_OVERLAY_COLOR, label="SM%")
            for x, y in zip(sm_xs, sm_ys):
                ax_r.text(x, y + 2.0, f"{y:.0f}%", ha="center", va="bottom",
                          fontsize=7, color=SM_OVERLAY_COLOR)

        # UNDERLOADED annotation — based on single-GPU (gpu_n1) SM%.
        sm_overlay = cell["sm_overlay"]
        if sm_overlay == sm_overlay and sm_overlay < sm_threshold:
            ax.text(
                0.5, 0.92,
                f"UNDERLOADED — n2 adds overhead without compute payoff\n"
                f"(gpu_n1 SM%={sm_overlay:.0f}% < {sm_threshold:.0f}%)",
                transform=ax.transAxes,
                ha="center", va="top", fontsize=8,
                color=RANK_HURT_COLOR,
                bbox=dict(facecolor="#fff7f5", edgecolor=RANK_HURT_COLOR,
                          boxstyle="round,pad=0.3", linewidth=0.8),
            )

        best = cell["best_config"]
        case_label = case.replace("case_prod_", "")
        ax.set_title(
            f"{case_label}  (grid={grid}, length={cell['length']})\n"
            f"best config: {best}",
            fontsize=9,
        )

    for j in range(len(cases), nrows * ncols):
        flat[j].axis("off")

    title = "GPU saturation vs rank count"
    if label:
        title = f"{title} — {label}"
    _add_title(fig, title, subtitle)
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    _save(fig, out_path)
    return out_path


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

    p = plot_gpu_saturation(df, plots_dir, label=label, subtitle=subtitle)
    paths.append(p)

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
