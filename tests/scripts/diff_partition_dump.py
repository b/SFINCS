#!/usr/bin/env python3
"""Locate the first multi-rank precision divergence from SFINCS_DUMP_PARTITION_DIFF dumps.

Companion to the SOR-51 env-gated `dump_partition_diff` instrumentation in
`source/src/sfincs_partition.cuf`. That dump writes, every Nth step, one
`sfincs_partition_diff_rank<N>.csv` per rank with columns

    step,t,rank,space,kind,gidx,inc_nm,inc_nmu,array,value

for the per-step cross-partition state arrays (zs / z_volume / zsderv at
cells; q / uv at edges) sampled at owned + halo positions inside the
configured rank-boundary cell-index windows.

This script compares a single-rank gpu_n1 run against a two-rank gpu_n2
run. For each (step, space, gidx, array) it takes:

  * the gpu_n1 owned value (n1 is degenerate: one rank, every cell owned),
  * the gpu_n2 OWNING-rank owned value (the authoritative value: the rank
    that owns gidx computes it locally; the other rank only mirrors it
    into its halo),

and reports, per array, the EARLIEST step at which |n1 - n2| first
exceeds a noise floor, plus the single global smoking gun (the array that
diverges at the earliest step). That (array, step, gidx) pair localizes
the kernel producing rank-divergent output before the divergence
propagates downstream into zsmax.

Usage:

    diff_partition_dump.py --n1-dir tests/runs/<case>/gpu_n1 \\
                           --n2-dir tests/runs/<case>/gpu_n2 \\
                           [--floor 1e-9] [--top 20]

Exit code is always 0 on a well-formed comparison; this is a diagnostic
tool, not a pass/fail gate. Exit 2 on unrecoverable input problems.
"""

import argparse
import csv
import glob
import os
import sys
from collections import defaultdict


def _load_rank_csvs(run_dir):
    """Return {(step, space, gidx, array): {rank: {kind: value}}} for a run dir."""
    paths = sorted(glob.glob(os.path.join(run_dir, "sfincs_partition_diff_rank*.csv")))
    if not paths:
        raise FileNotFoundError(
            f"no sfincs_partition_diff_rank*.csv in {run_dir} "
            "(was SFINCS_DUMP_PARTITION_DIFF set for that run?)"
        )
    table = defaultdict(lambda: defaultdict(dict))
    for path in paths:
        with open(path, newline="") as fh:
            reader = csv.DictReader(fh)
            for row in reader:
                step = int(row["step"])
                space = row["space"]
                gidx = int(row["gidx"])
                array = row["array"]
                rank = int(row["rank"])
                kind = row["kind"]
                value = float(row["value"])
                table[(step, space, gidx, array)][rank][kind] = value
    return table


def _n1_value(per_rank):
    """gpu_n1: single rank, every sampled cell owned."""
    for _rank, by_kind in per_rank.items():
        if "owned" in by_kind:
            return by_kind["owned"]
    return None


def _n2_owned_value(per_rank):
    """gpu_n2: the owning rank's owned value (authoritative). The other
    rank carries the same gidx only as a halo mirror; we want the value
    the owning rank actually computed locally."""
    for _rank, by_kind in per_rank.items():
        if "owned" in by_kind:
            return by_kind["owned"]
    return None


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--n1-dir", required=True, help="gpu_n1 run dir (one rank)")
    parser.add_argument("--n2-dir", required=True, help="gpu_n2 run dir (two ranks)")
    parser.add_argument(
        "--floor", type=float, default=1e-9,
        help="noise floor; |n1-n2| strictly above this counts as divergence "
        "(default 1e-9)",
    )
    parser.add_argument(
        "--top", type=int, default=20,
        help="how many earliest per-(array) divergence rows to print "
        "(default 20)",
    )
    args = parser.parse_args(argv)

    try:
        n1 = _load_rank_csvs(args.n1_dir)
        n2 = _load_rank_csvs(args.n2_dir)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    # First-divergence step per array, and the worst row at that step.
    first_div = {}  # array -> (step, gidx, n1v, n2v, absdiff)
    per_array_max = defaultdict(float)
    common = 0

    for key, n1_per_rank in n1.items():
        if key not in n2:
            continue
        step, space, gidx, array = key
        a = _n1_value(n1_per_rank)
        b = _n2_owned_value(n2[key])
        if a is None or b is None:
            continue
        common += 1
        d = abs(a - b)
        if d > per_array_max[array]:
            per_array_max[array] = d
        if d > args.floor:
            cur = first_div.get(array)
            if cur is None or step < cur[0] or (step == cur[0] and d > cur[4]):
                first_div[array] = (step, gidx, a, b, d)

    if common == 0:
        print(
            "ERROR: no (step, space, gidx, array) keys common to the n1 and "
            "n2 dumps — check the dump period and cell-index windows matched "
            "across runs",
            file=sys.stderr,
        )
        return 2

    print(f"compared {common} common (step, space, gidx, array) samples")
    print(f"noise floor: {args.floor:g}")
    print()
    print("per-array max |gpu_n1 - gpu_n2| over all sampled steps:")
    for array in sorted(per_array_max):
        flag = "  <-- diverges" if per_array_max[array] > args.floor else ""
        print(f"  {array:10s} max_abs_diff={per_array_max[array]:.6e}{flag}")
    print()

    if not first_div:
        print(
            "RESULT smoking_gun=NONE — no array exceeds the noise floor at "
            "any sampled step; the multi-rank residual is below "
            f"{args.floor:g} in the sampled windows"
        )
        return 0

    print("first step each array's owning-rank value diverges from gpu_n1:")
    ordered = sorted(first_div.items(), key=lambda kv: (kv[1][0], -kv[1][4]))
    for array, (step, gidx, n1v, n2v, d) in ordered[: args.top]:
        print(
            f"  {array:10s} step={step:<7d} gidx={gidx:<8d} "
            f"n1={n1v:.10e} n2={n2v:.10e} |diff|={d:.6e}"
        )
    print()

    gun_array, (gun_step, gun_gidx, gun_n1, gun_n2, gun_d) = ordered[0]
    print(
        f"RESULT smoking_gun={gun_array} step={gun_step} gidx={gun_gidx} "
        f"n1={gun_n1:.10e} n2={gun_n2:.10e} abs_diff={gun_d:.6e} "
        f"floor={args.floor:g}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
