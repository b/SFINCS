#!/usr/bin/env python3
"""Compare zsmax between two SFINCS *_map.nc outputs and exit PASS/FAIL/ERROR.

Used by the GPU validation harness to gate one (case, gpu_run) pair against a
CPU baseline. Exit codes:

  0 = PASS  (max(|ref - cand|) / max(ref) < threshold, no NaN)
  1 = FAIL  (ratio >= threshold)
  2 = ERROR (file/variable missing, NaN, shape mismatch, non-positive ref max,
             or any other unrecoverable input problem)

Every invocation prints exactly one RESULT line on stdout that the harness
greps for PASS/FAIL counts. ERROR invocations also write a human-readable
explanation to stderr prefixed with "ERROR: ".
"""

import argparse
import math
import os
import sys

import numpy as np
import xarray as xr


def _emit_result(case, reference, candidate, max_abs_diff, max_zsmax_ref, ratio, threshold, verdict):
    print(
        f"RESULT case={case} ref={reference} cand={candidate} "
        f"max_abs_diff={max_abs_diff} max_zsmax_ref={max_zsmax_ref} "
        f"ratio={ratio} threshold={threshold} verdict={verdict}"
    )


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Compare zsmax between two SFINCS *_map.nc outputs.",
    )
    parser.add_argument("--reference", required=True, help="CPU baseline *_map.nc path")
    parser.add_argument("--candidate", required=True, help="GPU candidate *_map.nc path")
    parser.add_argument(
        "--threshold", required=True, type=float,
        help="Maximum allowable max(|ref - cand|) / max(ref); strict <.",
    )
    parser.add_argument("--zsmax-var", default="zsmax", help="Variable name (default: zsmax)")
    args = parser.parse_args(argv)

    case = os.path.basename(os.path.dirname(os.path.abspath(args.candidate)))
    nan = math.nan

    def error(msg):
        print(f"ERROR: {msg}", file=sys.stderr)
        _emit_result(case, args.reference, args.candidate, nan, nan, nan, args.threshold, "ERROR")
        return 2

    for path, role in ((args.reference, "reference"), (args.candidate, "candidate")):
        if not os.path.isfile(path):
            return error(f"{role} file not found: {path}")

    try:
        ref_ds = xr.open_dataset(args.reference)
    except Exception as exc:
        return error(f"failed to open reference {args.reference}: {exc}")
    try:
        cand_ds = xr.open_dataset(args.candidate)
    except Exception as exc:
        ref_ds.close()
        return error(f"failed to open candidate {args.candidate}: {exc}")

    try:
        if args.zsmax_var not in ref_ds.variables:
            return error(f"variable '{args.zsmax_var}' missing from reference {args.reference}")
        if args.zsmax_var not in cand_ds.variables:
            return error(f"variable '{args.zsmax_var}' missing from candidate {args.candidate}")

        ref_arr = ref_ds[args.zsmax_var]
        cand_arr = cand_ds[args.zsmax_var]

        if ref_arr.shape != cand_arr.shape:
            return error(
                f"shape mismatch: reference has shape {tuple(ref_arr.shape)}, "
                f"candidate has shape {tuple(cand_arr.shape)}"
            )

        if bool(np.isnan(ref_arr.values).any()):
            return error(f"NaN values present in reference {args.reference}")
        if bool(np.isnan(cand_arr.values).any()):
            return error(f"NaN values present in candidate {args.candidate}")

        max_zsmax_ref = float(ref_arr.max())
        if not (max_zsmax_ref > 0.0):
            return error("max(zsmax_ref) is non-positive — case produces no positive zsmax, cannot normalize")

        max_abs_diff = float(np.abs(ref_arr - cand_arr).max())
        ratio = max_abs_diff / max_zsmax_ref
    finally:
        ref_ds.close()
        cand_ds.close()

    if ratio < args.threshold:
        verdict, rc = "PASS", 0
    else:
        verdict, rc = "FAIL", 1

    _emit_result(case, args.reference, args.candidate, max_abs_diff, max_zsmax_ref, ratio, args.threshold, verdict)
    return rc


if __name__ == "__main__":
    sys.exit(main())
