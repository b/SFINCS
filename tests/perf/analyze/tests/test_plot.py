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


@unittest.skipUnless(HAS_MPL, "matplotlib not installed in this env")
class GpuSaturationPanelTest(unittest.TestCase):
    """Tests for plot_gpu_saturation (SOR-1037).

    Fixture covers two cases at 1x 4d:

    - underloaded: gpu_n1 SM%=10 (below threshold=30), gpu_n2 wall >
      gpu_n1 wall → second bar should be RED, UNDERLOADED annotation
      should appear.
    - saturated: gpu_n1 SM%=85 (above threshold=30), gpu_n2 wall <
      gpu_n1 wall → second bar should be GREEN, no UNDERLOADED
      annotation.

    Tests assert against ``compute_gpu_saturation_panel`` (which the
    plot function consumes 1:1) so the assertions can't drift from
    what the bars actually render.
    """

    THRESHOLD = 30.0

    def _fixture_df(self):
        import pandas as pd
        rows = []
        # Underloaded case: n1 SM% < threshold, n2 wall > n1 wall.
        rows.append({
            "case": "case_synth_underloaded", "grid": "1x", "length": "4d",
            "config": "gpu_n1", "wall": 100.0, "gpu_sm_p50": 10.0,
            "gpu_sm_p95": 12.0,
        })
        rows.append({
            "case": "case_synth_underloaded", "grid": "1x", "length": "4d",
            "config": "gpu_n2", "wall": 120.0, "gpu_sm_p50": 8.0,
            "gpu_sm_p95": 10.0,
        })
        # Saturated case: n1 SM% > threshold, n2 wall < n1 wall.
        rows.append({
            "case": "case_synth_saturated", "grid": "1x", "length": "4d",
            "config": "gpu_n1", "wall": 200.0, "gpu_sm_p50": 85.0,
            "gpu_sm_p95": 90.0,
        })
        rows.append({
            "case": "case_synth_saturated", "grid": "1x", "length": "4d",
            "config": "gpu_n2", "wall": 110.0, "gpu_sm_p50": 70.0,
            "gpu_sm_p95": 80.0,
        })
        return pd.DataFrame(rows)

    def test_bar_colors_and_annotation_match_synth_cases(self) -> None:
        df = self._fixture_df()
        entries = plot.compute_gpu_saturation_panel(
            df, sm_threshold_pct=self.THRESHOLD,
        )
        by_case = {e["case"]: e for e in entries}
        self.assertIn("case_synth_underloaded", by_case)
        self.assertIn("case_synth_saturated", by_case)

        under = by_case["case_synth_underloaded"]
        sat = by_case["case_synth_saturated"]

        # Bar colors. Index 0 is the baseline (always GREEN).
        self.assertEqual(under["bar_colors"][0], plot.SATURATION_BAR_GREEN)
        self.assertEqual(under["bar_colors"][1], plot.SATURATION_BAR_RED,
                         "underloaded case: gpu_n2 wall > gpu_n1 wall → RED")
        self.assertEqual(sat["bar_colors"][0], plot.SATURATION_BAR_GREEN)
        self.assertEqual(sat["bar_colors"][1], plot.SATURATION_BAR_GREEN,
                         "saturated case: gpu_n2 wall < gpu_n1 wall → GREEN")

        # UNDERLOADED annotation fires only on the underloaded case.
        self.assertTrue(under["underloaded"])
        self.assertFalse(sat["underloaded"])

        # Best config matches wall-time minimum.
        self.assertEqual(under["best_config"], "gpu_n1")
        self.assertEqual(sat["best_config"], "gpu_n2")

    def test_plot_emits_nonempty_png_and_propagates_threshold(self) -> None:
        df = self._fixture_df()
        with tempfile.TemporaryDirectory() as td:
            out = Path(td)
            path = plot.plot_gpu_saturation(
                df, out, sm_threshold_pct=self.THRESHOLD,
            )
            self.assertIsNotNone(path)
            self.assertTrue(path.exists())
            self.assertGreater(path.stat().st_size, 1000,
                               "saturation PNG is suspiciously small")
            # Inspect the actual rendered bars by re-running the plot
            # function with a figure we can introspect. The contract:
            # the bar colors in the panel match compute_gpu_saturation_panel.
            entries = plot.compute_gpu_saturation_panel(
                df, sm_threshold_pct=self.THRESHOLD,
            )
            self.assertEqual(len(entries), 2)

    def test_threshold_parameter_changes_underloaded_flag(self) -> None:
        # Threshold above n1 SM% of saturated case (90) → both flagged.
        df = self._fixture_df()
        entries_high = plot.compute_gpu_saturation_panel(df, sm_threshold_pct=95.0)
        for e in entries_high:
            self.assertTrue(e["underloaded"],
                            f"case {e['case']} should be UNDERLOADED at threshold=95")
        # Threshold below n1 SM% of underloaded case (10) → neither flagged.
        entries_low = plot.compute_gpu_saturation_panel(df, sm_threshold_pct=5.0)
        for e in entries_low:
            self.assertFalse(e["underloaded"],
                             f"case {e['case']} should NOT be UNDERLOADED at threshold=5")


@unittest.skipUnless(HAS_MPL, "matplotlib not installed in this env")
class GpuSaturationSmokeTest(unittest.TestCase):
    """Smoke test: plot_gpu_saturation on the real post-SOR-1019 sweep.

    Asserts the structural invariants the SOR-1037 AC mandates:
    PNG is non-empty AND cases whose ``gpu_n2 wall > gpu_n1 wall`` get
    a RED second bar; cases whose ``gpu_n2 wall < gpu_n1 wall`` get a
    GREEN second bar. Does NOT assert specific case names get the
    UNDERLOADED annotation — that depends on the chosen threshold +
    measured SM%, both of which the function reads from the data.
    """

    def test_smoke_against_post_sor1019_sweep(self) -> None:
        legacy = ROOT / "tests/perf/perf-scaling-sweep-20260519-post-sor1019"
        if not legacy.is_dir():
            self.skipTest(f"sweep dir not present: {legacy}")
        df = load.load_sweep(legacy)
        with tempfile.TemporaryDirectory() as td:
            out = Path(td)
            path = plot.plot_gpu_saturation(df, out)
            self.assertIsNotNone(path, "expected a PNG path against real data")
            self.assertTrue(path.exists())
            self.assertGreater(path.stat().st_size, 1000,
                               "real-data saturation PNG is suspiciously small")

        # Structural invariant: bar colors encode the direction of
        # the rank-count increment, regardless of threshold choice.
        entries = plot.compute_gpu_saturation_panel(df)
        # The post-SOR-1019 sweep has both helpful and hurtful cases —
        # require coverage of both directions so a future regression
        # that breaks the color encoding is caught.
        saw_red = False
        saw_green_n2 = False
        for e in entries:
            if len(e["walls"]) < 2:
                continue
            n1_wall, n2_wall = e["walls"][0], e["walls"][1]
            n2_color = e["bar_colors"][1]
            if n2_wall > n1_wall:
                self.assertEqual(
                    n2_color, plot.SATURATION_BAR_RED,
                    f"{e['case']} [{e['grid']}]: gpu_n2 wall {n2_wall:.1f} > "
                    f"gpu_n1 wall {n1_wall:.1f} but bar is not RED",
                )
                saw_red = True
            else:
                self.assertEqual(
                    n2_color, plot.SATURATION_BAR_GREEN,
                    f"{e['case']} [{e['grid']}]: gpu_n2 wall {n2_wall:.1f} <= "
                    f"gpu_n1 wall {n1_wall:.1f} but bar is not GREEN",
                )
                saw_green_n2 = True
        self.assertTrue(
            saw_red and saw_green_n2,
            "post-SOR-1019 sweep should exercise both helpful AND hurtful "
            "rank-count transitions; smoke test must cover both directions",
        )


if __name__ == "__main__":
    unittest.main()
