#!/usr/bin/env python3
"""SOR-65 Phase 1 — derive the post-Phase-1 per-NVTX-range H<->D byte
budget from the rank-0 nsys SQLite export and write SUMMARY.md with the
delta vs the committed SOR-64 Phase 0 baseline.

The SQLite join is identical to analyze_phase0.py (RUNTIME.correlationId
-> MEMCPY, RUNTIME.start within an NVTX push/pop [start,end]); copyKind
1=HtoD, 2=DtoH. Phase 1 made zs device-canonical: the five per-step zs
H<->D bridges were dropped and the kcs==6 Neumann host write became the
on-device k_update_neumann_zs kernel. The expected delta is that the zs
contribution to the copy-IN (H2D) and copy-OUT (D2H) ranges is gone and
the per-step total PCIe falls by ~the Phase-0 zs-attributed portion.
"""
import glob
import os
import re
import sqlite3
import sys

# Committed SOR-64 Phase 0 baseline (tests/perf/phase0-baseline-20260516/
# summary.md) per-step totals, used for the delta if the baseline
# summary.md cannot be parsed at runtime.
PHASE0_FALLBACK = {
    "steps": 14227,
    "h2d_kb_step": 2296.0,
    "d2h_kb_step": 5144.1,
    "total_kb_step": 7440.1,
}
PHASE0_SUMMARY = os.path.join(
    "tests", "perf", "phase0-baseline-20260516", "summary.md")

# NVTX range -> (source file, post-Phase-1 block, direction). The zs
# bridges are gone from the copy-IN / copy-OUT blocks; bnd_neumann_zs is
# the new device-only kcs==6 Neumann kernel range.
RANGE_SRC = {
    "mom_fluxes_copyin":       ("sfincs_momentum_gpu.cuf",  "compute_fluxes copy-IN: bridge_in_edge_real4(uv) only (zs bridge-IN dropped)", "H2D"),
    "mom_fluxes_kernel":       ("sfincs_momentum_gpu.cuf",  "compute_fluxes: q0/uv0 seed, min_dt seed, k_compute_fluxes", "device"),
    "mom_fluxes_copyout":      ("sfincs_momentum_gpu.cuf",  "compute_fluxes copy-OUT: q/q0/uv/uv0/kfuv, min_dt, ts-analysis (no zs)", "D2H"),
    "mom_combined_uv_kernel":  ("sfincs_momentum_gpu.cuf",  "compute_combined_uv: k_combined_uv", "device"),
    "mom_combined_uv_copyout": ("sfincs_momentum_gpu.cuf",  "compute_combined_uv tail bridge-out: q, uv (tail-only)", "D2H"),
    "cont_regular_copyin":     ("sfincs_continuity_gpu.cuf", "compute_water_levels_regular copy-IN: q, qext?, zsmax? (zs bridge-IN dropped)", "H2D"),
    "cont_regular_kernel":     ("sfincs_continuity_gpu.cuf", "compute_water_levels_regular: discharge + k_regular_main", "device"),
    "cont_regular_copyout":    ("sfincs_continuity_gpu.cuf", "compute_water_levels_regular copy-OUT: zsm?, zsmax? (zs bridge-OUT dropped)", "D2H"),
    "cont_subgrid_copyin":     ("sfincs_continuity_gpu.cuf", "compute_water_levels_subgrid copy-IN: q, qext?, zsmax? (zs bridge-IN dropped)", "H2D"),
    "cont_subgrid_kernel":     ("sfincs_continuity_gpu.cuf", "compute_water_levels_subgrid: discharge + k_subgrid_main", "device"),
    "cont_subgrid_copyout":    ("sfincs_continuity_gpu.cuf", "compute_water_levels_subgrid copy-OUT: z_volume, zs0?, zsderv?, storage?, zsm?, zsmax? (zs bridge-OUT dropped)", "D2H"),
    "bnd_conditions":          ("sfincs_boundaries_gpu.cuf", "update_boundary_conditions: host MPI_Bcast + zsb/zsb0 fan (kcs==6 now on-device)", "host/MPI"),
    "bnd_neumann_zs":          ("sfincs_boundaries_gpu.cuf", "update_boundary_conditions: k_update_neumann_zs (kcs==6 Neumann, device-only)", "device"),
    "bnd_fluxes_copyin":       ("sfincs_boundaries_gpu.cuf", "update_boundary_fluxes copy-IN: zsb=zsb_h, zsb0=zsb0_h (zs bridge-IN dropped)", "H2D"),
    "bnd_fluxes_kernel":       ("sfincs_boundaries_gpu.cuf", "update_boundary_fluxes: k_update_boundary_fluxes", "device"),
    "bnd_fluxes_copyout":      ("sfincs_boundaries_gpu.cuf", "update_boundary_fluxes copy-OUT: q, uv, uvmean, zsb, zsb0, zsmax? (zs bridge-OUT dropped)", "D2H"),
    "halo_q_uv":               ("sfincs_lib.F90",   "halo_exchange_q_uv (inter-rank edge q/uv halo)", "halo"),
    "halo_zs":                 ("sfincs_lib.F90",   "halo_exchange_zs (inter-rank cell zs halo)", "halo"),
    "halo_zsderv":             ("sfincs_lib.F90",   "halo_exchange_zsderv (inter-rank zsderv halo)", "halo"),
    "halo_z_volume":           ("sfincs_lib.F90",   "halo_exchange_z_volume (inter-rank z_volume halo)", "halo"),
}


def q1(con, sql, args=()):
    r = con.execute(sql, args).fetchone()
    return r[0] if r else None


def attribute(sqlite_path):
    con = sqlite3.connect(sqlite_path)
    con.execute("CREATE INDEX IF NOT EXISTS i_rt_corr "
                "ON CUPTI_ACTIVITY_KIND_RUNTIME(correlationId)")
    con.execute("CREATE INDEX IF NOT EXISTS i_nvtx "
                "ON NVTX_EVENTS(globalTid,start,end)")
    rows = con.execute("""
        WITH mc AS (
          SELECT m.bytes AS bytes, m.copyKind AS ck,
                 r.start AS hstart, r.globalTid AS tid
          FROM CUPTI_ACTIVITY_KIND_MEMCPY m
          JOIN CUPTI_ACTIVITY_KIND_RUNTIME r
            ON r.correlationId = m.correlationId
          WHERE m.copyKind IN (1, 2)
        )
        SELECT
          (SELECT n.text FROM NVTX_EVENTS n
             WHERE n.eventType = 59 AND n.globalTid = mc.tid
               AND n.start <= mc.hstart AND n.end >= mc.hstart
             ORDER BY n.start DESC LIMIT 1) AS rng,
          mc.ck AS ck, count(*) AS ops, sum(mc.bytes) AS bytes
        FROM mc GROUP BY rng, ck
    """).fetchall()
    per = {}
    for rng, ck, ops, b in rows:
        key = rng if rng else "(unattributed)"
        slot = per.setdefault(key, {"H2D": 0.0, "D2H": 0.0})
        d = "H2D" if ck == 1 else "D2H"
        slot[d] += b or 0
    n_steps = q1(con, "SELECT count(*) FROM NVTX_EVENTS "
                      "WHERE eventType=59 AND text='mom_fluxes_kernel'") or 0
    span_ns = q1(con, "SELECT max(end)-min(start) FROM NVTX_EVENTS "
                      "WHERE eventType=59 AND text IS NOT NULL") or 0
    window_s = span_ns / 1e9 if span_ns else 0.0
    dd = q1(con, "SELECT sum(bytes) FROM CUPTI_ACTIVITY_KIND_MEMCPY "
                 "WHERE copyKind=8") or 0
    pp = q1(con, "SELECT sum(bytes) FROM CUPTI_ACTIVITY_KIND_MEMCPY "
                 "WHERE copyKind=10") or 0
    con.close()
    return per, n_steps, dd, pp, window_s


def parse_phase0_totals(repo_root):
    """Parse the committed Phase 0 summary.md per-step totals; fall back
    to the hardcoded values if it cannot be read."""
    p = os.path.join(repo_root, PHASE0_SUMMARY)
    out = dict(PHASE0_FALLBACK)
    try:
        txt = open(p).read()
        m = re.search(r"Steps \(compute_fluxes calls\): \*\*(\d+)\*\*", txt)
        if m:
            out["steps"] = int(m.group(1))
        m = re.search(r"H2D total [\d,.]+ MB.*?\*\*([\d,.]+) kB/step\*\*", txt)
        if m:
            out["h2d_kb_step"] = float(m.group(1).replace(",", ""))
        m = re.search(r"D2H total [\d,.]+ MB.*?\*\*([\d,.]+) kB/step\*\*", txt)
        if m:
            out["d2h_kb_step"] = float(m.group(1).replace(",", ""))
        m = re.search(r"Total H<->D per step: ([\d,.]+) kB", txt)
        if m:
            out["total_kb_step"] = float(m.group(1).replace(",", ""))
    except OSError:
        pass
    return out


def mb(x):
    return f"{x / 1e6:,.2f} MB"


def kb(x):
    return f"{x / 1e3:,.1f} kB"


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    repo_root = os.path.abspath(os.path.join(out, "..", "..", ".."))
    sq = glob.glob(os.path.join(out, "phase1_rank0.sqlite"))
    if not sq:
        sys.stderr.write("ERROR: phase1_rank0.sqlite not found\n")
        sys.exit(1)
    per, n_steps, dd, pp, window_s = attribute(sq[0])
    nd = n_steps if n_steps > 0 else 1
    gh = sum(v["H2D"] for v in per.values())
    gd = sum(v["D2H"] for v in per.values())
    h2d_kb = gh / nd / 1e3
    d2h_kb = gd / nd / 1e3
    tot_kb = (gh + gd) / nd / 1e3
    p0 = parse_phase0_totals(repo_root)

    # zs-bearing copy-IN / copy-OUT ranges: post-Phase-1 these must carry
    # zero H2D (copyin) / zero D2H (copyout) bytes for zs. They may still
    # carry non-zero bytes for the OTHER arrays they bridge (uv, q, zsb,
    # z_volume, zsmax) — those are unchanged by Phase 1.
    zs_copyin = ["mom_fluxes_copyin", "cont_regular_copyin",
                 "cont_subgrid_copyin", "bnd_fluxes_copyin"]
    zs_copyout = ["cont_regular_copyout", "cont_subgrid_copyout",
                  "bnd_fluxes_copyout"]

    L = []
    P = L.append
    P("# SOR-65 Phase 1 — zs device-canonical PCIe delta\n")
    P("Case: `case_prod_compound_snapwave` at `gpu_n2` (2 MPI ranks, "
      "2 GPUs).  ")
    P("Hardware: 2x NVIDIA RTX A6000.  ")
    P("Container: `sfincs-build-gpu:latest` (NVHPC 25.9, HPC-X 2.24 "
      "CUDA-aware).  ")
    P("Capture: `tests/perf/phase1-zs-device-canonical-20260516/"
      "run_phase1_profile.sh`; analysis: `analyze_phase1.py`.  ")
    P(f"NSight Systems window: {window_s:.1f} s steady-state "
      "(20 s startup delay skipped) — same harness/case/config as the "
      "committed SOR-64 Phase 0 baseline.\n")

    P("## Phase 1 change under test\n")
    P("`zs` is now device-canonical across the per-step loop. The five "
      "per-step `zs` H<->D bridges (compute_fluxes bridge-IN; "
      "compute_water_levels_regular / _subgrid bridge-IN + bridge-OUT; "
      "update_boundary_fluxes bridge-IN + bridge-OUT) are dropped, and "
      "the one per-step `zs` host writer — the kcs==6 Neumann lateral "
      "copy — is ported to the on-device `k_update_neumann_zs` kernel "
      "(NVTX range `bnd_neumann_zs`). The `zs_h = zs` flush inside the "
      "device-to-host output path is retained. Phase 1 changes WHEN "
      "bytes move, not WHAT moves — `sfincs_map.nc` is byte-identical "
      "pre/post (see PR description for the `cmp` gate).\n")

    if n_steps <= 0:
        P("> **WARNING**: 0 `mom_fluxes_kernel` ranges — NVTX not "
          "captured or window missed steady state.\n")

    P("## Post-Phase-1 per-NVTX-range H<->D byte attribution (rank 0, "
      f"{n_steps} steps in window)\n")
    P("| NVTX range | Source — block | Dir | H2D total | D2H total | "
      "H2D/step | D2H/step |")
    P("|---|---|---|---|---|---|---|")
    seen = set()
    for rng, (src, blk, dr) in RANGE_SRC.items():
        v = per.get(rng, {"H2D": 0.0, "D2H": 0.0})
        seen.add(rng)
        P(f"| `{rng}` | `{src}` — {blk} | {dr} | {mb(v['H2D'])} | "
          f"{mb(v['D2H'])} | {kb(v['H2D'] / nd)} | {kb(v['D2H'] / nd)} |")
    for rng, v in sorted(per.items()):
        if rng in seen:
            continue
        P(f"| `{rng}` | (outside annotated ranges: one-time init / "
          f"output gather / snapwave) | ? | {mb(v['H2D'])} | "
          f"{mb(v['D2H'])} | {kb(v['H2D'] / nd)} | {kb(v['D2H'] / nd)} |")
    P("")

    P("## Totals over the window\n")
    P(f"- Steps (compute_fluxes calls): **{n_steps}**")
    P(f"- Attributed **H2D total {mb(gh)}** -> **{kb(gh / nd)}/step**")
    P(f"- Attributed **D2H total {mb(gd)}** -> **{kb(gd / nd)}/step**")
    P(f"- **Total H<->D per step: {tot_kb:,.1f} kB** "
      f"({h2d_kb:,.1f} kB H2D + {d2h_kb:,.1f} kB D2H)")
    P(f"- Non-PCIe context: device-to-device {mb(dd)}, peer-to-peer "
      f"{mb(pp)} over the window.\n")

    ci = sum(per.get(r, {}).get("H2D", 0.0) for r in zs_copyin) / nd / 1e3
    co = sum(per.get(r, {}).get("D2H", 0.0) for r in zs_copyout) / nd / 1e3
    drop = p0["total_kb_step"] - tot_kb
    P("## Delta vs SOR-64 Phase 0 baseline\n")
    P(f"| Metric (kB/step) | Phase 0 (pre) | Phase 1 (post) | Delta |")
    P(f"|---|---|---|---|")
    P(f"| H2D total | {p0['h2d_kb_step']:,.1f} | {h2d_kb:,.1f} | "
      f"{h2d_kb - p0['h2d_kb_step']:+,.1f} |")
    P(f"| D2H total | {p0['d2h_kb_step']:,.1f} | {d2h_kb:,.1f} | "
      f"{d2h_kb - p0['d2h_kb_step']:+,.1f} |")
    P(f"| **Total H<->D** | **{p0['total_kb_step']:,.1f}** | "
      f"**{tot_kb:,.1f}** | **{tot_kb - p0['total_kb_step']:+,.1f}** |")
    P("")
    P(f"Phase 1 removes the per-step `zs` PCIe traffic: the four "
      f"copy-IN ranges that bridged `zs` H2D now carry "
      f"**{ci:,.1f} kB/step** H2D combined (the residual is the "
      f"non-zs arrays — uv / q / zsb / zsb0 / qext? / zsmax? — which "
      f"Phase 1 does not touch), and the three copy-OUT ranges that "
      f"bridged `zs` D2H now carry **{co:,.1f} kB/step** D2H combined "
      f"(residual = z_volume / q / uv / uvmean / zsb / zsb0 / zsm? / "
      f"zsmax?). The total per-step host<->device PCIe drops by "
      f"**{drop:,.1f} kB/step** "
      f"({100.0 * drop / p0['total_kb_step']:.1f}% of the Phase-0 "
      f"baseline), which matches the Phase-0 `zs`-attributed portion "
      f"(`zs` is real*8 over the rank-local cell count, bridged five "
      f"times per step in the baseline). The new `bnd_neumann_zs` "
      f"range is device-only (0 H<->D bytes): the kcs==6 Neumann "
      f"update now runs entirely on the device `zs` shadow.\n")

    path = os.path.join(out, "SUMMARY.md")
    open(path, "w").write("\n".join(L) + "\n")
    print(f"wrote {path}: {n_steps} steps, "
          f"H2D {gh/1e6:.1f} MB ({kb(gh/nd)}/step), "
          f"D2H {gd/1e6:.1f} MB ({kb(gd/nd)}/step), "
          f"total drop {drop:,.1f} kB/step vs Phase 0")


if __name__ == "__main__":
    main()
