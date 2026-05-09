#!/usr/bin/env python3
"""Tests for diff_zsmax.py.

Exercises every acceptance criterion from SOR-744 plus the FillValue-aware
comparison from SOR-845. Designed to run with the project's standard
`python3 -m unittest` invocation; no external test runner required.
Synthetic netCDF files are produced inside a temp dir using xarray.
"""

import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest

import numpy as np
import netCDF4 as nc


SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "diff_zsmax.py")

# Match SFINCS's source/src/sfincs_ncoutput.F90 FILL_VALUE = -99999.0
FILL_VALUE = -99999.0

RESULT_RE = re.compile(
    r"^RESULT case=(?P<case>\S+) ref=(?P<ref>\S+) cand=(?P<cand>\S+) "
    r"max_abs_diff=(?P<diff>\S+) max_zsmax_ref=(?P<refmax>\S+) "
    r"ratio=(?P<ratio>\S+) threshold=(?P<threshold>\S+) verdict=(?P<verdict>PASS|FAIL|ERROR)$"
)


def write_zsmax(path, values, var="zsmax", fill=FILL_VALUE):
    """Write a SFINCS-style zsmax netCDF: float32 with `_FillValue` set, mirroring
    sfincs_ncoutput.F90 (FILL_VALUE = -99999.0). Uses netCDF4 directly with
    auto-mask disabled so any NaN values pass through to the file as-is
    (xarray's encoder converts NaN -> fill, which would defeat the
    NaN-in-valid-cell error path)."""
    arr = np.asarray(values, dtype=np.float32)
    ds = nc.Dataset(path, "w")
    try:
        ds.createDimension("y", arr.shape[0])
        ds.createDimension("x", arr.shape[1])
        kwargs = {}
        if fill is not None:
            kwargs["fill_value"] = np.float32(fill)
        v = ds.createVariable(var, "f4", ("y", "x"), **kwargs)
        v.set_auto_mask(False)
        v[:] = arr
    finally:
        ds.close()


def run_script(*args, env=None):
    proc = subprocess.run(
        [sys.executable, SCRIPT, *args],
        capture_output=True,
        text=True,
        env=env,
    )
    return proc


def parse_result(stdout):
    lines = [ln for ln in stdout.splitlines() if ln.startswith("RESULT ")]
    if not lines:
        raise AssertionError(f"no RESULT line in stdout:\n{stdout}")
    if len(lines) > 1:
        raise AssertionError(f"multiple RESULT lines in stdout:\n{stdout}")
    m = RESULT_RE.match(lines[0])
    if not m:
        raise AssertionError(f"RESULT line did not match expected schema: {lines[0]}")
    return m.groupdict()


class DiffZsmaxTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp(prefix="diff_zsmax_test_")

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def case_dir(self, name):
        d = os.path.join(self.tmp, name)
        os.makedirs(d, exist_ok=True)
        return d

    def test_script_has_shebang_and_is_executable(self):
        with open(SCRIPT, "rb") as f:
            first = f.readline()
        self.assertEqual(first.rstrip(), b"#!/usr/bin/env python3")
        mode = os.stat(SCRIPT).st_mode
        self.assertTrue(mode & stat.S_IXUSR, "script must be executable by owner")

    def test_pass_when_identical_with_tight_threshold(self):
        cd = self.case_dir("case_pass_n1")
        ref = os.path.join(cd, "ref_map.nc")
        cand = os.path.join(cd, "cand_map.nc")
        write_zsmax(ref, [[0.5, 1.0], [2.0, 3.0]])
        shutil.copyfile(ref, cand)
        proc = run_script("--reference", ref, "--candidate", cand, "--threshold", "1e-6")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        r = parse_result(proc.stdout)
        self.assertEqual(r["verdict"], "PASS")
        self.assertEqual(float(r["diff"]), 0.0)
        self.assertEqual(float(r["ratio"]), 0.0)
        self.assertEqual(r["case"], "case_pass_n1")
        self.assertEqual(r["ref"], ref)
        self.assertEqual(r["cand"], cand)

    def test_fail_when_ratio_at_or_above_threshold(self):
        cd = self.case_dir("case_fail_n1")
        ref = os.path.join(cd, "ref_map.nc")
        cand = os.path.join(cd, "cand_map.nc")
        write_zsmax(ref, [[1.0, 2.0], [3.0, 4.0]])  # max = 4
        write_zsmax(cand, [[1.0, 2.0], [3.0, 4.04]])  # diff = 0.04, ratio = 0.01
        proc = run_script("--reference", ref, "--candidate", cand, "--threshold", "1e-3")
        self.assertEqual(proc.returncode, 1)
        r = parse_result(proc.stdout)
        self.assertEqual(r["verdict"], "FAIL")
        self.assertAlmostEqual(float(r["ratio"]), 0.01, places=5)

    def test_strict_inequality_at_threshold_is_fail(self):
        cd = self.case_dir("case_boundary")
        ref = os.path.join(cd, "ref_map.nc")
        cand = os.path.join(cd, "cand_map.nc")
        # Use exactly representable values: ratio = 1.0 / 1.0 = 1.0, threshold = 1.0.
        write_zsmax(ref, [[1.0]])
        write_zsmax(cand, [[2.0]])
        proc = run_script("--reference", ref, "--candidate", cand, "--threshold", "1.0")
        self.assertEqual(proc.returncode, 1, "ratio == threshold must be FAIL (strict <)")
        r = parse_result(proc.stdout)
        self.assertEqual(r["verdict"], "FAIL")
        self.assertEqual(float(r["ratio"]), 1.0)

    def test_missing_reference_file_is_error(self):
        cd = self.case_dir("case_missing_ref")
        cand = os.path.join(cd, "cand_map.nc")
        write_zsmax(cand, [[1.0]])
        proc = run_script(
            "--reference", os.path.join(cd, "does_not_exist.nc"),
            "--candidate", cand,
            "--threshold", "1e-3",
        )
        self.assertEqual(proc.returncode, 2)
        self.assertTrue(proc.stderr.startswith("ERROR: "), proc.stderr)
        r = parse_result(proc.stdout)
        self.assertEqual(r["verdict"], "ERROR")

    def test_missing_candidate_file_is_error(self):
        cd = self.case_dir("case_missing_cand")
        ref = os.path.join(cd, "ref_map.nc")
        write_zsmax(ref, [[1.0]])
        proc = run_script(
            "--reference", ref,
            "--candidate", os.path.join(cd, "does_not_exist.nc"),
            "--threshold", "1e-3",
        )
        self.assertEqual(proc.returncode, 2)
        self.assertTrue(proc.stderr.startswith("ERROR: "), proc.stderr)

    def test_missing_zsmax_variable_is_error(self):
        cd = self.case_dir("case_missing_var")
        ref = os.path.join(cd, "ref_map.nc")
        cand = os.path.join(cd, "cand_map.nc")
        write_zsmax(ref, [[1.0]], var="not_zsmax")
        write_zsmax(cand, [[1.0]], var="not_zsmax")
        proc = run_script("--reference", ref, "--candidate", cand, "--threshold", "1e-3")
        self.assertEqual(proc.returncode, 2)
        self.assertIn("zsmax", proc.stderr)

    def test_custom_zsmax_var_name(self):
        cd = self.case_dir("case_custom_var")
        ref = os.path.join(cd, "ref_map.nc")
        cand = os.path.join(cd, "cand_map.nc")
        write_zsmax(ref, [[1.0, 2.0]], var="zsmax_alt")
        shutil.copyfile(ref, cand)
        proc = run_script(
            "--reference", ref, "--candidate", cand,
            "--threshold", "1e-6", "--zsmax-var", "zsmax_alt",
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        r = parse_result(proc.stdout)
        self.assertEqual(r["verdict"], "PASS")

    def test_shape_mismatch_is_error_with_shapes_in_message(self):
        cd = self.case_dir("case_shape_mismatch")
        ref = os.path.join(cd, "ref_map.nc")
        cand = os.path.join(cd, "cand_map.nc")
        write_zsmax(ref, [[1.0, 2.0], [3.0, 4.0]])  # (2, 2)
        write_zsmax(cand, [[1.0, 2.0, 3.0]])  # (1, 3)
        proc = run_script("--reference", ref, "--candidate", cand, "--threshold", "1e-3")
        self.assertEqual(proc.returncode, 2)
        self.assertIn("(2, 2)", proc.stderr)
        self.assertIn("(1, 3)", proc.stderr)

    def test_nan_in_reference_is_error(self):
        # NaN in a non-FillValue cell is still a hard error: SFINCS encodes
        # masked-out cells as -99999, so a NaN that survives masking is a real
        # bug rather than a legitimate dry-cell marker.
        cd = self.case_dir("case_nan_ref")
        ref = os.path.join(cd, "ref_map.nc")
        cand = os.path.join(cd, "cand_map.nc")
        write_zsmax(ref, [[1.0, np.nan], [3.0, 4.0]])
        write_zsmax(cand, [[1.0, 2.0], [3.0, 4.0]])
        proc = run_script("--reference", ref, "--candidate", cand, "--threshold", "1e-3")
        self.assertEqual(proc.returncode, 2)
        self.assertIn("NaN", proc.stderr)

    def test_nan_in_candidate_is_error(self):
        cd = self.case_dir("case_nan_cand")
        ref = os.path.join(cd, "ref_map.nc")
        cand = os.path.join(cd, "cand_map.nc")
        write_zsmax(ref, [[1.0, 2.0], [3.0, 4.0]])
        write_zsmax(cand, [[1.0, np.nan], [3.0, 4.0]])
        proc = run_script("--reference", ref, "--candidate", cand, "--threshold", "1e-3")
        self.assertEqual(proc.returncode, 2)
        self.assertIn("NaN", proc.stderr)

    def test_zero_max_zsmax_ref_is_error_with_exact_message(self):
        cd = self.case_dir("case_zero_max")
        ref = os.path.join(cd, "ref_map.nc")
        cand = os.path.join(cd, "cand_map.nc")
        write_zsmax(ref, [[0.0, 0.0], [0.0, 0.0]])
        write_zsmax(cand, [[0.0, 0.0], [0.0, 0.0]])
        proc = run_script("--reference", ref, "--candidate", cand, "--threshold", "1e-3")
        self.assertEqual(proc.returncode, 2)
        self.assertIn(
            "ERROR: max(zsmax_ref) is non-positive — case produces no positive zsmax, cannot normalize",
            proc.stderr,
        )

    def test_negative_max_zsmax_ref_is_error(self):
        cd = self.case_dir("case_neg_max")
        ref = os.path.join(cd, "ref_map.nc")
        cand = os.path.join(cd, "cand_map.nc")
        write_zsmax(ref, [[-1.0, -2.0], [-3.0, -4.0]])
        write_zsmax(cand, [[-1.0, -2.0], [-3.0, -4.0]])
        proc = run_script("--reference", ref, "--candidate", cand, "--threshold", "1e-3")
        self.assertEqual(proc.returncode, 2)
        self.assertIn("non-positive", proc.stderr)

    def test_result_line_emitted_on_error(self):
        cd = self.case_dir("case_error_emits_result_n2")
        cand = os.path.join(cd, "cand_map.nc")
        write_zsmax(cand, [[1.0]])
        proc = run_script(
            "--reference", os.path.join(cd, "missing.nc"),
            "--candidate", cand,
            "--threshold", "1e-3",
        )
        self.assertEqual(proc.returncode, 2)
        r = parse_result(proc.stdout)
        self.assertEqual(r["verdict"], "ERROR")
        self.assertEqual(r["case"], "case_error_emits_result_n2")
        self.assertEqual(r["threshold"], "0.001")

    def test_threshold_argument_required(self):
        cd = self.case_dir("case_no_threshold")
        ref = os.path.join(cd, "ref_map.nc")
        cand = os.path.join(cd, "cand_map.nc")
        write_zsmax(ref, [[1.0]])
        write_zsmax(cand, [[1.0]])
        proc = run_script("--reference", ref, "--candidate", cand)
        self.assertNotEqual(proc.returncode, 0)

    # --- FillValue-aware comparison (SOR-845) -------------------------------

    def test_fillvalue_cells_excluded_from_diff_when_either_side_masked(self):
        # FillValue on either side flags the cell as masked-out for the diff.
        # Ref has FillValue at [0,1]; candidate has a real value there but
        # it must not affect the diff because the ref considers that cell
        # masked.
        cd = self.case_dir("case_fillvalue_excluded")
        ref = os.path.join(cd, "ref_map.nc")
        cand = os.path.join(cd, "cand_map.nc")
        write_zsmax(ref, [[1.0, FILL_VALUE], [3.0, 4.0]])
        write_zsmax(cand, [[1.0, 5.0],        [3.0, 4.0]])
        proc = run_script("--reference", ref, "--candidate", cand, "--threshold", "1e-6")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        r = parse_result(proc.stdout)
        self.assertEqual(r["verdict"], "PASS")
        self.assertEqual(float(r["diff"]), 0.0)
        self.assertEqual(float(r["refmax"]), 4.0)

    def test_fillvalue_only_on_candidate_side_also_masks(self):
        cd = self.case_dir("case_fillvalue_cand_only")
        ref = os.path.join(cd, "ref_map.nc")
        cand = os.path.join(cd, "cand_map.nc")
        write_zsmax(ref, [[1.0, 7.0], [3.0, 4.0]])
        write_zsmax(cand, [[1.0, FILL_VALUE], [3.0, 4.0]])
        proc = run_script("--reference", ref, "--candidate", cand, "--threshold", "1e-6")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        r = parse_result(proc.stdout)
        self.assertEqual(r["verdict"], "PASS")

    def test_all_cells_fillvalue_is_error_no_valid_cells(self):
        cd = self.case_dir("case_all_fill")
        ref = os.path.join(cd, "ref_map.nc")
        cand = os.path.join(cd, "cand_map.nc")
        write_zsmax(ref, [[FILL_VALUE, FILL_VALUE]])
        write_zsmax(cand, [[FILL_VALUE, FILL_VALUE]])
        proc = run_script("--reference", ref, "--candidate", cand, "--threshold", "1e-3")
        self.assertEqual(proc.returncode, 2)
        self.assertIn("no valid", proc.stderr)
        r = parse_result(proc.stdout)
        self.assertEqual(r["verdict"], "ERROR")

    def test_diff_only_over_valid_cells(self):
        # Mismatched FillValue patterns: ref dry where cand wet at [0,1] and
        # vice versa at [1,0]. Both should be excluded; the remaining valid
        # cells [0,0] and [1,1] are identical, so the diff is zero.
        cd = self.case_dir("case_mixed_fill")
        ref = os.path.join(cd, "ref_map.nc")
        cand = os.path.join(cd, "cand_map.nc")
        write_zsmax(ref, [[1.0, FILL_VALUE], [9.0,        4.0]])
        write_zsmax(cand, [[1.0, 9.0],       [FILL_VALUE, 4.0]])
        proc = run_script("--reference", ref, "--candidate", cand, "--threshold", "1e-6")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        r = parse_result(proc.stdout)
        self.assertEqual(r["verdict"], "PASS")
        self.assertEqual(float(r["diff"]), 0.0)


if __name__ == "__main__":
    unittest.main()
