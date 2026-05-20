"""Load perf-sweep artifacts into a pandas DataFrame.

Walks a sweep directory and parses each per-cell ``timings.txt`` plus
``nvidia_smi_dmon.txt`` into a tidy DataFrame.

Supports two cell-directory naming conventions:

1. ``<case>__<grid>__<length>__<config>`` — used by the
   ``run_perf_scaling.sh`` harness (perf-scaling-sweep-* directories).
2. ``<case>__<config>__<variant>`` where variant is ``pre`` / ``post`` —
   used by the earlier SOR-87 perf-matrix-20260518 directory. Missing
   axes (grid / length / step_count) are filled with sensible defaults
   or NaN. ``length`` is inferred from the cell's ``sfincs.inp`` if
   present.

Public surface:

    load_sweep(sweep_dir: str | os.PathLike) -> pandas.DataFrame
    parse_timings(path: str | os.PathLike) -> dict
    parse_dmon(path: str | os.PathLike) -> tuple[float, float]
"""
from __future__ import annotations

import os
import re
import statistics
from pathlib import Path

import numpy as np
import pandas as pd


NAMED_COMPONENTS = (
    "boundaries",
    "momentum",
    "continuity",
    "snapwave",
    "meteo",
    "output",
)

# Stable column order — load_sweep guarantees these exist.
COLUMNS = (
    "case",
    "grid",
    "length",
    "config",
    "variant",
    "wall",
    "total_simulation_time",
    "boundaries",
    "momentum",
    "continuity",
    "snapwave",
    "meteo",
    "output",
    "step_count",
    "gpu_sm_p50",
    "gpu_sm_p95",
    "U_L",
    "per_step",
    "skipped",
    "skipped_estimated_wall",
    "cell_dir",
)


# ---------------------------------------------------------------------------
# timings.txt
# ---------------------------------------------------------------------------

def parse_timings(path: str | os.PathLike) -> dict:
    """Parse a per-cell timings.txt into a dict of floats / ints.

    The format is one ``key value`` pair per line. Empty values become
    NaN. Missing files return an empty dict.
    """
    out: dict[str, float | int] = {}
    p = Path(path)
    if not p.is_file():
        return out
    for line in p.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split(None, 1)
        key = parts[0]
        raw = parts[1].strip() if len(parts) > 1 else ""
        if raw == "":
            out[key] = float("nan")
            continue
        try:
            if key == "step_count" or key == "sim_seconds":
                out[key] = int(raw)
            else:
                out[key] = float(raw)
        except ValueError:
            out[key] = float("nan")
    return out


def is_skipped_cell(timings: dict) -> bool:
    """Return True if a parsed timings dict represents a skip-by-projection cell."""
    return "skipped_estimated_wall" in timings


# ---------------------------------------------------------------------------
# nvidia_smi_dmon.txt
# ---------------------------------------------------------------------------

def parse_dmon(path: str | os.PathLike) -> tuple[float, float]:
    """Return ``(p50, p95)`` of per-sample max-across-GPUs sm %.

    A run reports one sample row per GPU per tick; we collapse each
    tick to ``max(sm%)`` across the GPUs that produced a sample, then
    compute the 50th and 95th percentile across ticks. Skips the first
    five and last two samples per GPU to drop startup / tear-down
    transients (matches build_summary.sh's window).

    Missing files or too-few samples → (nan, nan).
    """
    p = Path(path)
    if not p.is_file():
        return (float("nan"), float("nan"))

    # gpu_idx -> list of sm%
    per_gpu: dict[int, list[int]] = {}
    for line in p.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        toks = line.split()
        if len(toks) < 2:
            continue
        try:
            g = int(toks[0])
            sm = int(toks[1])
        except ValueError:
            continue
        per_gpu.setdefault(g, []).append(sm)

    # Trim transients.
    trimmed: list[list[int]] = []
    for g, samples in per_gpu.items():
        if len(samples) < 8:
            continue
        trimmed.append(samples[5:-2])

    if not trimmed:
        return (float("nan"), float("nan"))

    # Per-tick max across GPUs. Tick count = min length across GPUs;
    # samples may differ if one GPU was queried more frequently.
    ticks = min(len(s) for s in trimmed)
    if ticks == 0:
        return (float("nan"), float("nan"))
    per_tick_max = [max(s[i] for s in trimmed) for i in range(ticks)]

    sorted_vals = sorted(per_tick_max)
    n = len(sorted_vals)
    p50 = sorted_vals[n // 2]
    p95_idx = max(0, min(n - 1, int(round(0.95 * (n - 1)))))
    p95 = sorted_vals[p95_idx]
    return (float(p50), float(p95))


# ---------------------------------------------------------------------------
# Directory layout discovery
# ---------------------------------------------------------------------------

_SCALING_RE = re.compile(
    r"^(?P<case>case_[A-Za-z0-9_]+?)"
    r"__(?P<grid>1x|4x)"
    r"__(?P<length>1h|6h|24h|4d)"
    r"__(?P<config>cpu_n\d+|gpu_n\d+)$"
)

_MATRIX_RE = re.compile(
    r"^(?P<case>case_[A-Za-z0-9_]+?)"
    r"__(?P<config>cpu_n\d+|gpu_n\d+)"
    r"__(?P<variant>pre|post)$"
)


def _classify_cell(name: str) -> dict | None:
    """Match a cell directory name against known layouts.

    Returns the parsed parts (case/grid/length/config/variant) or None
    if the name does not match a known layout.
    """
    m = _SCALING_RE.match(name)
    if m:
        return {
            "case": m.group("case"),
            "grid": m.group("grid"),
            "length": m.group("length"),
            "config": m.group("config"),
            "variant": None,
        }
    m = _MATRIX_RE.match(name)
    if m:
        return {
            "case": m.group("case"),
            "grid": "1x",
            "length": None,
            "config": m.group("config"),
            "variant": m.group("variant"),
        }
    return None


# ---------------------------------------------------------------------------
# sfincs.inp tstart/tstop -> simulated seconds + length tag
# ---------------------------------------------------------------------------

_LENGTH_LABELS = (
    (3600, "1h"),
    (21600, "6h"),
    (86400, "24h"),
    (345600, "4d"),
)


def _seconds_from_inp(inp_path: Path) -> int | None:
    """Return tstop - tstart in seconds from a sfincs.inp, or None."""
    if not inp_path.is_file():
        return None
    tstart_re = re.compile(r"^\s*tstart\s*=\s*(\d{8})\s+(\d{6})", re.M)
    tstop_re = re.compile(r"^\s*tstop\s*=\s*(\d{8})\s+(\d{6})", re.M)
    text = inp_path.read_text(errors="replace")
    ms = tstart_re.search(text)
    me = tstop_re.search(text)
    if not ms or not me:
        return None
    try:
        from datetime import datetime
        ts = datetime.strptime(ms.group(1) + ms.group(2), "%Y%m%d%H%M%S")
        te = datetime.strptime(me.group(1) + me.group(2), "%Y%m%d%H%M%S")
    except ValueError:
        return None
    return int((te - ts).total_seconds())


def _length_label_for(seconds: int | None) -> str | None:
    """Map a seconds count to a known length tag (1h/6h/24h/4d) if it matches."""
    if seconds is None:
        return None
    for s, tag in _LENGTH_LABELS:
        if seconds == s:
            return tag
    return None


# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------

def _row_for_cell(cell_dir: Path, parts: dict) -> dict:
    timings = parse_timings(cell_dir / "timings.txt")
    skipped = is_skipped_cell(timings)
    skipped_min = timings.get("skipped_estimated_wall", float("nan"))
    if skipped:
        # Skip-by-projection cell — no SFINCS run, no GPU dmon. wall
        # is None so the analysis layer can plot a marker at the
        # projected position rather than treat the cell as missing.
        p50 = float("nan")
        p95 = float("nan")
        wall = float("nan")
        sim = float("nan")
        step_count_val = timings.get("step_count", float("nan"))
        comps = {c: float("nan") for c in NAMED_COMPONENTS}
        u_l = float("nan")
        per_step = float("nan")
        length = parts.get("length")
        if length is None:
            seconds = _seconds_from_inp(cell_dir / "sfincs.inp")
            length = _length_label_for(seconds)
        return {
            "case": parts["case"],
            "grid": parts["grid"],
            "length": length,
            "config": parts["config"],
            "variant": parts["variant"],
            "wall": wall,
            "total_simulation_time": sim,
            "boundaries": comps["boundaries"],
            "momentum": comps["momentum"],
            "continuity": comps["continuity"],
            "snapwave": comps["snapwave"],
            "meteo": comps["meteo"],
            "output": comps["output"],
            "step_count": step_count_val,
            "gpu_sm_p50": p50,
            "gpu_sm_p95": p95,
            "U_L": u_l,
            "per_step": per_step,
            "skipped": True,
            "skipped_estimated_wall": skipped_min,
            "cell_dir": str(cell_dir),
        }

    p50, p95 = parse_dmon(cell_dir / "nvidia_smi_dmon.txt")

    # Wall is the total wall-clock SFINCS prints; total_simulation_time
    # is the per-step loop. The harness writes "total" and "simulation".
    wall = timings.get("total", float("nan"))
    sim = timings.get("simulation", float("nan"))

    # If length wasn't in the dir name, infer it from sfincs.inp.
    length = parts.get("length")
    if length is None:
        seconds = _seconds_from_inp(cell_dir / "sfincs.inp")
        length = _length_label_for(seconds)

    # step_count from timings.txt if present; otherwise NaN.
    step_count_val = timings.get("step_count", float("nan"))

    # Named components — coalesce missing into NaN. Sum_named must
    # ignore NaN entries to avoid contaminating U_L with NaN.
    comps = {c: timings.get(c, float("nan")) for c in NAMED_COMPONENTS}
    named_vals = [v for v in comps.values() if v == v]  # skip NaN
    sum_named = sum(named_vals) if named_vals else float("nan")

    if sim == sim and sum_named == sum_named:
        u_l = sim - sum_named
    else:
        u_l = float("nan")

    if u_l == u_l and step_count_val == step_count_val and step_count_val:
        per_step = u_l / float(step_count_val)
    else:
        per_step = float("nan")

    return {
        "case": parts["case"],
        "grid": parts["grid"],
        "length": length,
        "config": parts["config"],
        "variant": parts["variant"],
        "wall": wall,
        "total_simulation_time": sim,
        "boundaries": comps["boundaries"],
        "momentum": comps["momentum"],
        "continuity": comps["continuity"],
        "snapwave": comps["snapwave"],
        "meteo": comps["meteo"],
        "output": comps["output"],
        "step_count": step_count_val,
        "gpu_sm_p50": p50,
        "gpu_sm_p95": p95,
        "U_L": u_l,
        "per_step": per_step,
        "skipped": False,
        "skipped_estimated_wall": skipped_min,
        "cell_dir": str(cell_dir),
    }


def load_sweep(sweep_dir: str | os.PathLike) -> pd.DataFrame:
    """Walk a sweep directory and return a tidy DataFrame.

    Each row is one ``(case, grid, length, config[, variant])`` cell.
    Cells whose directory name does not match a known layout are
    silently skipped. The returned DataFrame is sorted by
    ``(case, grid, config, length)`` with a stable column order.
    """
    root = Path(sweep_dir)
    if not root.is_dir():
        raise FileNotFoundError(f"sweep dir does not exist: {root}")

    rows: list[dict] = []
    for child in sorted(root.iterdir()):
        if not child.is_dir():
            continue
        parts = _classify_cell(child.name)
        if parts is None:
            continue
        rows.append(_row_for_cell(child, parts))

    df = pd.DataFrame(rows, columns=list(COLUMNS))
    if df.empty:
        return df

    # Ordered categorical sort keys so 1h/6h/24h/4d/pre/post sort
    # intuitively rather than alphabetically.
    length_order = ["1h", "6h", "24h", "4d"]
    df["length_order"] = df["length"].apply(
        lambda v: length_order.index(v) if isinstance(v, str) and v in length_order else 999
    )
    df = df.sort_values(["case", "grid", "config", "length_order"], kind="stable")
    df = df.drop(columns=["length_order"]).reset_index(drop=True)
    return df


def sweep_label(sweep_dir: str | os.PathLike) -> str:
    """Return a short, human-scannable label for a sweep directory."""
    return Path(sweep_dir).name


def capture_env(sweep_dir: str | os.PathLike) -> str:
    """Return the contents of capture_env.txt, or '' if missing."""
    p = Path(sweep_dir) / "capture_env.txt"
    if not p.is_file():
        return ""
    return p.read_text()
