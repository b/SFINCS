"""Unit tests for tests/perf/analyze/compare.render_rank_count_recommendation.

Runs against the committed perf-scaling-sweep-20260519-post-sor1019
fixture and asserts the table's content matches the patterns described
in SOR-1033's evidence table (per-case best rank-count config).
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from tests.perf.analyze import compare  # noqa: E402

SWEEP_POST = ROOT / "tests/perf/perf-scaling-sweep-20260519-post-sor1019"


class RenderRankCountRecommendationTest(unittest.TestCase):
    def test_section_header_and_columns(self) -> None:
        md = compare.render_rank_count_recommendation(SWEEP_POST)
        self.assertIn("### GPU rank-count recommendation", md)
        # Header row of the markdown table.
        self.assertIn(
            "| case | grid | length | best | best wall (s) | next | next wall (s) | "
            "Δ vs next (s) | Δ vs next (%) | single-GPU SM% |",
            md,
        )

    def test_riverine_storm_best_is_gpu_n2(self) -> None:
        """Per issue evidence: riverine + storm_amuv best config = gpu_n2 at 1x."""
        md = compare.render_rank_count_recommendation(SWEEP_POST)
        # The row format pins case+grid first; find the riverine 1x row and assert "gpu_n2".
        for needle in ("`case_prod_riverine` | 1x", "`case_prod_storm_amuv` | 1x"):
            rows = [line for line in md.splitlines() if needle in line]
            self.assertEqual(len(rows), 1, f"expected one row for {needle}, got {len(rows)}")
            self.assertIn("gpu_n2", rows[0])

    def test_regular_tide_quadtree_best_is_gpu_n1(self) -> None:
        """Per issue evidence: regular_tide + quadtree_subgrid_tide best config = gpu_n1 at 1x."""
        md = compare.render_rank_count_recommendation(SWEEP_POST)
        for needle in (
            "`case_prod_regular_tide` | 1x",
            "`case_prod_quadtree_subgrid_tide` | 1x",
        ):
            rows = [line for line in md.splitlines() if needle in line]
            self.assertEqual(len(rows), 1)
            # ``best`` column is the fourth — make sure it's gpu_n1, not gpu_n2.
            parts = [p.strip() for p in rows[0].split("|")]
            # parts[0]="" parts[1]="`case…`" parts[2]="1x" parts[3]="4d" parts[4]="gpu_n1"
            self.assertEqual(parts[4], "gpu_n1",
                             f"{needle}: best column = {parts[4]!r}, want gpu_n1")

    def test_regular_tide_4x_best_is_gpu_n2(self) -> None:
        """Per issue evidence: regular_tide 4x best config = gpu_n2."""
        md = compare.render_rank_count_recommendation(SWEEP_POST)
        rows = [line for line in md.splitlines() if "`case_prod_regular_tide` | 4x" in line]
        self.assertEqual(len(rows), 1)
        parts = [p.strip() for p in rows[0].split("|")]
        self.assertEqual(parts[4], "gpu_n2")


if __name__ == "__main__":
    unittest.main()
