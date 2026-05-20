"""Unit tests for tests/perf/analyze/plot.py.

Sanity tests for the new (SOR-1025) plots: they must render without
errors against a synthesized cpu_n<k> sweep and they must NOT render
against a sweep that lacks the thread-count axis.
"""
from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

try:
    from tests.perf.analyze import load, plot  # noqa: E402
    HAS_MPL = True
except ImportError:
    HAS_MPL = False


@unittest.skipUnless(HAS_MPL, "matplotlib not installed in this env")
class NewPlotsRenderTest(unittest.TestCase):
    def _write_cell(self, cell_dir: Path, wall: float, sim_seconds: int, step_count: int) -> None:
        cell_dir.mkdir(parents=True, exist_ok=True)
        sim = wall * 0.97
        sn = sim * 0.85
        (cell_dir / "timings.txt").write_text(
            f"total {wall:.3f}\n"
            f"simulation {sim:.3f}\n"
            f"input 0.05\n"
            f"boundaries {sn*0.05:.3f}\n"
            f"momentum {sn*0.5:.3f}\n"
            f"continuity {sn*0.25:.3f}\n"
            f"snapwave \n"
            f"meteo {sn*0.15:.3f}\n"
            f"output {sn*0.05:.3f}\n"
            f"avg_dt 3.66\n"
            f"sum_named {sn:.3f}\n"
            f"unaccounted {sim-sn:.3f}\n"
            f"step_count {step_count}\n"
            f"sim_seconds {sim_seconds}\n"
        )

    def _write_skipped(self, cell_dir: Path, projected_min: float, sim_seconds: int) -> None:
        cell_dir.mkdir(parents=True, exist_ok=True)
        (cell_dir / "timings.txt").write_text(
            f"skipped_estimated_wall {projected_min:.2f}\n"
            f"sim_seconds {sim_seconds}\n"
        )

    def _build_sweep(self, sweep_dir: Path) -> None:
        case = "case_prod_regular_tide"
        for L, sec, steps in (("1h", 3600, 983), ("6h", 21600, 5900),
                              ("24h", 86400, 23600), ("4d", 345600, 94400)):
            base_wall = {"1h": 13.0, "6h": 37.0, "24h": 141.0, "4d": 419.0}[L]
            for k in (1, 2, 4, 8, 16, 32, 64, 128):
                projected_min = (base_wall * 128 / k) / 60.0
                cell = sweep_dir / f"{case}__1x__{L}__cpu_n{k}"
                if k != 128 and projected_min > 30:
                    self._write_skipped(cell, projected_min, sec)
                else:
                    wall = base_wall * (128 / k) ** (0.7 if k >= 32 else 1.0)
                    self._write_cell(cell, wall, sec, steps)
            for g in (1, 2):
                cell = sweep_dir / f"{case}__1x__{L}__gpu_n{g}"
                gw = base_wall / 8.0 / (1.0 if g == 1 else 1.6)
                self._write_cell(cell, gw, sec, steps)

    def test_new_plots_emit_three_pngs(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            sweep = Path(td) / "sweep"
            sweep.mkdir()
            self._build_sweep(sweep)
            out = Path(td) / "plots"
            paths = plot.render(str(sweep), out_dir=str(out))
            names = {p.name for p in paths}
            self.assertIn("omp_scaling.png", names)
            self.assertIn("omp_efficiency.png", names)
            self.assertIn("gpu_cpu_crossover_heatmap.png", names)
            for n in ("omp_scaling.png", "omp_efficiency.png",
                      "gpu_cpu_crossover_heatmap.png"):
                self.assertGreater((out / n).stat().st_size, 1000,
                                   f"{n} is suspiciously small")

    def test_legacy_sweep_omits_new_plots(self) -> None:
        legacy = ROOT / "tests/perf/perf-scaling-sweep-20260519-post-sor1019"
        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "plots"
            paths = plot.render(str(legacy), out_dir=str(out))
            names = {p.name for p in paths}
            # Legacy sweep only has cpu_n128 → no thread-count axis.
            self.assertNotIn("omp_scaling.png", names)
            self.assertNotIn("omp_efficiency.png", names)
            self.assertNotIn("gpu_cpu_crossover_heatmap.png", names)
            # Sanity: original five plots ARE still rendered.
            self.assertIn("wall_vs_length.png", names)
            self.assertIn("per_step_vs_length.png", names)


@unittest.skipUnless(HAS_MPL, "matplotlib not installed in this env")
class HelpersTest(unittest.TestCase):
    def test_cpu_thread_counts_extracts_k(self) -> None:
        import pandas as pd
        df = pd.DataFrame({"config": ["cpu_n1", "cpu_n2", "cpu_n128",
                                       "gpu_n1", "gpu_n2", "cpu_n4"]})
        self.assertEqual(plot._cpu_thread_counts(df), [1, 2, 4, 128])
        self.assertEqual(plot._gpu_rank_counts(df), [1, 2])


if __name__ == "__main__":
    unittest.main()
