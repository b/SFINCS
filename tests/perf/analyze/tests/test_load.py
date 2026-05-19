"""Unit tests for tests/perf/analyze/load.py.

Runs against the committed sweep fixtures under tests/perf/. Verifies
column count + row count + a spot-check of one cell's per_step
against the corresponding SUMMARY.md value.
"""
from __future__ import annotations

import math
import unittest
from pathlib import Path

import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from tests.perf.analyze import load  # noqa: E402

SWEEP_POST = ROOT / "tests/perf/perf-scaling-sweep-20260519-post-sor1019"
SWEEP_PRE = ROOT / "tests/perf/perf-scaling-sweep-20260519"
MATRIX = ROOT / "tests/perf/perf-matrix-20260518"


class LoadSweepTest(unittest.TestCase):
    def test_columns_present(self) -> None:
        df = load.load_sweep(SWEEP_POST)
        for col in load.COLUMNS:
            self.assertIn(col, df.columns)
        self.assertEqual(len(df.columns), len(load.COLUMNS))

    def test_row_count_post(self) -> None:
        # 5 cases × (1x: 4 lengths × 3 configs) + 4x for regular_tide only:
        #   = 5 × 12 + 1 × 12 = 72
        df = load.load_sweep(SWEEP_POST)
        self.assertEqual(len(df), 72)

    def test_row_count_pre(self) -> None:
        df = load.load_sweep(SWEEP_PRE)
        # Pre-sweep: 66 cells (one config skipped — see directory listing).
        self.assertGreaterEqual(len(df), 60)
        self.assertLessEqual(len(df), 72)

    def test_per_step_spot_check_riverine(self) -> None:
        """SUMMARY.md says riverine 1x 24h gpu_n2 per_step = 0.746 ms."""
        df = load.load_sweep(SWEEP_POST)
        row = df[
            (df["case"] == "case_prod_riverine")
            & (df["grid"] == "1x")
            & (df["length"] == "24h")
            & (df["config"] == "gpu_n2")
        ]
        self.assertEqual(len(row), 1)
        per_step_ms = float(row.iloc[0]["per_step"]) * 1000.0
        self.assertAlmostEqual(per_step_ms, 0.746, places=2)

    def test_per_step_spot_check_regular_tide_4x(self) -> None:
        """SUMMARY.md says regular_tide 4x 24h gpu_n2 per_step = 0.097 ms."""
        df = load.load_sweep(SWEEP_POST)
        row = df[
            (df["case"] == "case_prod_regular_tide")
            & (df["grid"] == "4x")
            & (df["length"] == "24h")
            & (df["config"] == "gpu_n2")
        ]
        self.assertEqual(len(row), 1)
        per_step_ms = float(row.iloc[0]["per_step"]) * 1000.0
        self.assertAlmostEqual(per_step_ms, 0.097, places=2)

    def test_u_l_matches_summary(self) -> None:
        """U(L) for compound_snapwave 1x 4d gpu_n2 should be ~12.375 s."""
        df = load.load_sweep(SWEEP_POST)
        row = df[
            (df["case"] == "case_prod_compound_snapwave")
            & (df["grid"] == "1x")
            & (df["length"] == "4d")
            & (df["config"] == "gpu_n2")
        ]
        self.assertEqual(len(row), 1)
        u_l = float(row.iloc[0]["U_L"])
        self.assertAlmostEqual(u_l, 12.375, places=2)

    def test_matrix_layout_loads(self) -> None:
        """The older perf-matrix-20260518 layout should also load."""
        df = load.load_sweep(MATRIX)
        self.assertGreater(len(df), 0)
        # Variant column should be populated for matrix layout.
        self.assertTrue(set(df["variant"].dropna().unique()).issubset({"pre", "post"}))


class ParseTimingsTest(unittest.TestCase):
    def test_missing_file_returns_empty(self) -> None:
        self.assertEqual(load.parse_timings("/nonexistent/path"), {})

    def test_step_count_is_int(self) -> None:
        cell = SWEEP_POST / "case_prod_riverine__1x__24h__gpu_n2"
        d = load.parse_timings(cell / "timings.txt")
        self.assertIsInstance(d["step_count"], int)
        self.assertEqual(d["step_count"], 22690)


class ParseDmonTest(unittest.TestCase):
    def test_known_cell_returns_finite(self) -> None:
        cell = SWEEP_POST / "case_prod_riverine__1x__24h__gpu_n2"
        p50, p95 = load.parse_dmon(cell / "nvidia_smi_dmon.txt")
        self.assertTrue(math.isfinite(p50))
        self.assertTrue(math.isfinite(p95))
        # SUMMARY.md says steady-state for 24h was ~24%.
        self.assertGreaterEqual(p50, 15.0)
        self.assertLessEqual(p50, 35.0)


if __name__ == "__main__":
    unittest.main()
