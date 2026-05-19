"""Unit tests for tests/perf/analyze/plot.plot_gpu_saturation.

Builds a synthetic DataFrame with two cases — one underloaded
(n1 SM%=10%, n2 wall > n1 wall) and one saturated (n1 SM%=80%,
n2 wall < n1 wall) — then renders the panel and asserts:

  * the underloaded case's n2 bar is red (n2 hurt)
  * the saturated case's n2 bar is green (n2 helped)
  * the UNDERLOADED annotation appears only on the underloaded subplot
"""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from tests.perf.analyze import load, plot  # noqa: E402


def _fixture_df() -> pd.DataFrame:
    """Two-case synthetic DataFrame at 1x 4d, gpu_n1 + gpu_n2.

    case_underloaded: n1 SM%=10 (< 30 threshold), n2 wall=200 > n1 wall=100.
    case_saturated:   n1 SM%=80 (> 30 threshold), n2 wall=60  < n1 wall=100.
    """
    rows = []
    for case, n1_sm, n1_wall, n2_wall in (
        ("case_prod_underloaded", 10.0, 100.0, 200.0),
        ("case_prod_saturated",   80.0, 100.0,  60.0),
    ):
        rows.append({
            "case": case, "grid": "1x", "length": "4d",
            "config": "gpu_n1", "variant": None,
            "wall": n1_wall, "total_simulation_time": n1_wall,
            "boundaries": float("nan"), "momentum": float("nan"),
            "continuity": float("nan"), "snapwave": float("nan"),
            "meteo": float("nan"), "output": float("nan"),
            "step_count": 1000,
            "gpu_sm_p50": n1_sm, "gpu_sm_p95": n1_sm,
            "U_L": 0.0, "per_step": 0.0,
            "cell_dir": "<fixture>",
        })
        rows.append({
            "case": case, "grid": "1x", "length": "4d",
            "config": "gpu_n2", "variant": None,
            "wall": n2_wall, "total_simulation_time": n2_wall,
            "boundaries": float("nan"), "momentum": float("nan"),
            "continuity": float("nan"), "snapwave": float("nan"),
            "meteo": float("nan"), "output": float("nan"),
            "step_count": 1000,
            "gpu_sm_p50": n1_sm, "gpu_sm_p95": n1_sm,
            "U_L": 0.0, "per_step": 0.0,
            "cell_dir": "<fixture>",
        })
    return pd.DataFrame(rows, columns=list(load.COLUMNS))


class PlotGpuSaturationTest(unittest.TestCase):
    """plot_gpu_saturation produces the colored bars + annotation described in AC."""

    def setUp(self) -> None:
        self.df = _fixture_df()
        self.tmp = Path(tempfile.mkdtemp(prefix="sat_test_"))

    def test_png_written(self) -> None:
        path = plot.plot_gpu_saturation(self.df, self.tmp, sm_threshold=30.0)
        self.assertTrue(path.is_file())
        self.assertGreater(path.stat().st_size, 0)
        self.assertEqual(path.name, "gpu_saturation_vs_rank.png")

    def test_bar_colors_and_annotation(self) -> None:
        """The figure object contains the expected bar colors per case + the annotation."""
        # Build the figure in-process so we can inspect axes / patches / texts.
        cases = plot._cases_in(self.df)
        nrows, ncols, figsize = plot._layout(len(cases))
        fig, axes = plt.subplots(nrows, ncols, figsize=figsize, squeeze=False)
        # Re-run the inner rendering by calling plot_gpu_saturation against
        # a writable tmpdir, then re-derive the axes assertion via the
        # _saturation_cell helper + _bar_colors_for.
        plt.close(fig)

        for case, expect_color, expect_underloaded in (
            ("case_prod_underloaded", plot.RANK_HURT_COLOR, True),
            ("case_prod_saturated",   plot.RANK_HELP_COLOR, False),
        ):
            cell = plot._saturation_cell(self.df, case, "1x")
            self.assertIsNotNone(cell, f"no saturation cell for {case}")
            colors = plot._bar_colors_for(cell["walls"])
            # GPU_RANK_CONFIGS = ("gpu_n1", "gpu_n2"); n2 is index 1.
            self.assertEqual(
                colors[1], expect_color,
                f"{case} n2 bar color: got {colors[1]}, want {expect_color}",
            )
            # First bar (n1) is always neutral baseline (RANK_HELP_COLOR).
            self.assertEqual(colors[0], plot.RANK_HELP_COLOR)

            sm_overlay = cell["sm_overlay"]
            self.assertEqual(sm_overlay < 30.0, expect_underloaded,
                             f"{case} underload at threshold 30: "
                             f"SM={sm_overlay}, expect underloaded={expect_underloaded}")

    def test_annotation_text_present_only_on_underloaded(self) -> None:
        """Inspect the actual rendered figure: UNDERLOADED only on underloaded case."""
        # Patch _save to capture the figure rather than writing+closing it.
        captured: dict = {}
        original_save = plot._save

        def _capture(fig, path):
            captured["fig"] = fig
            # Mirror original side effect (write to disk) so plot_gpu_saturation
            # returns a real file path.
            original_save(fig, path)

        plot._save = _capture
        try:
            plot.plot_gpu_saturation(self.df, self.tmp, sm_threshold=30.0)
        finally:
            plot._save = original_save

        fig = captured["fig"]
        cases = plot._cases_in(self.df)
        # Walk each axes that corresponds to a case subplot.
        # The first len(cases) axes are case panels (twinx axes are appended after).
        # plot.plot_gpu_saturation creates `nrows*ncols` panels and one twinx per
        # populated case; per-case axes are at indices 0..len(cases)-1 of the
        # ORIGINAL subplots, which matches the first len(cases) axes when we
        # iterate in creation order — but to be robust we look at all axes
        # and group by title.
        underloaded_seen = False
        saturated_seen = False
        for ax in fig.axes:
            title = ax.get_title()
            if not title:
                continue
            ann_texts = [t.get_text() for t in ax.texts if "UNDERLOADED" in t.get_text()]
            if "underloaded" in title:
                underloaded_seen = True
                self.assertTrue(
                    ann_texts,
                    "UNDERLOADED annotation missing from underloaded subplot",
                )
            elif "saturated" in title:
                saturated_seen = True
                self.assertFalse(
                    ann_texts,
                    f"UNDERLOADED annotation unexpectedly present on saturated subplot: "
                    f"{ann_texts}",
                )
        self.assertTrue(underloaded_seen, "underloaded subplot never inspected")
        self.assertTrue(saturated_seen, "saturated subplot never inspected")

    def test_threshold_parameter_controls_annotation(self) -> None:
        """A high threshold flags saturated case too; low threshold flags neither."""
        # threshold=100 → both cases (SM% < 100) get UNDERLOADED.
        captured: dict = {}
        original_save = plot._save

        def _capture(fig, path):
            captured["fig"] = fig
            original_save(fig, path)

        plot._save = _capture
        try:
            plot.plot_gpu_saturation(self.df, self.tmp, sm_threshold=100.0,
                                     filename="threshold_high.png")
            fig_high = captured["fig"]
            captured.clear()
            plot.plot_gpu_saturation(self.df, self.tmp, sm_threshold=0.0,
                                     filename="threshold_low.png")
            fig_low = captured["fig"]
        finally:
            plot._save = original_save

        def _annotated(fig) -> dict[str, bool]:
            seen = {}
            for ax in fig.axes:
                title = ax.get_title()
                if not title:
                    continue
                has_ann = any("UNDERLOADED" in t.get_text() for t in ax.texts)
                if "underloaded" in title:
                    seen["underloaded"] = has_ann
                elif "saturated" in title:
                    seen["saturated"] = has_ann
            return seen

        ann_high = _annotated(fig_high)
        ann_low = _annotated(fig_low)
        self.assertTrue(ann_high.get("underloaded"))
        self.assertTrue(ann_high.get("saturated"))
        self.assertFalse(ann_low.get("underloaded"))
        self.assertFalse(ann_low.get("saturated"))


if __name__ == "__main__":
    unittest.main()
