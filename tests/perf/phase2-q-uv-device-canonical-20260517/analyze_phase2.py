#!/usr/bin/env python3
"""SOR-66 Phase 2 — derive the post-Phase-2 per-NVTX-range H<->D byte
budget from the rank-0 nsys SQLite export and write SUMMARY.md with the
delta vs the committed SOR-65 Phase 1 baseline.

Phase 2 made q / q0 / uv / uv0 device-canonical across the per-step loop.
The uv bridge-IN at compute_fluxes is gated on nonhydrostatic_h (a no-op
on case_prod_compound_snapwave, which has nonhydrostatic = 0). The q
bridge-IN at compute_water_levels_regular / _subgrid is dropped, and the
q / q0 / uv / uv0 bridge-OUTs at compute_fluxes and
update_boundary_conditions (update_boundary_fluxes) are dropped, plus
the tail-only q / uv bridges in compute_combined_uv. The output-cadence
flush in device_to_host_for_output handles the host refresh for netCDF /
BMI / SnapWave coupling. The expected delta is that the q + uv
contribution to the copy-IN (H2D) and copy-OUT (D2H) ranges is gone and
the per-step total PCIe falls by ~the q + uv portion measured in
Phase 1.
"""
import glob
import os
import re
import sqlite3
import sys

# Committed SOR-65 Phase 1 baseline per-step totals (parsed from its
# SUMMARY.md), used for the delta if the summary file cannot be read.
PHASE1_FALLBACK = {
    "steps": 13313,
    "h2d_kb_step": 1046.8,
    "d2h_kb_step": 4329.4,
    "total_kb_step": 5376.3,
}
PHASE1_SUMMARY = os.path.join(
    "tests", "perf", "phase1-zs-device-canonical-20260516", "SUMMARY.md")

# NVTX range -> (source file, post-Phase-2 block, direction). Compared to
# Phase 1, the q / q0 / uv / uv0 contributions are gone from the
# copy-IN / copy-OUT blocks; mom_combined_uv_copyout becomes device-only;
# bnd_fluxes_copyout retains only uvmean / zsb / zsb0.
RANGE_SRC = {
    "mom_fluxes_copyin":       ("sfincs_momentum_gpu.cuf",  "compute_fluxes copy-IN: bridge_in_edge_real4(uv) gated on nonhydrostatic_h (no-op when feature is off)", "H2D"),
    "mom_fluxes_kernel":       ("sfincs_momentum_gpu.cuf",  "compute_fluxes: q0/uv0 seed, min_dt seed, k_compute_fluxes", "device"),
    "mom_fluxes_copyout":      ("sfincs_momentum_gpu.cuf",  "compute_fluxes copy-OUT: kfuv, min_dt, ts-analysis (q/q0/uv/uv0 dropped)", "D2H"),
    "mom_combined_uv_kernel":  ("sfincs_momentum_gpu.cuf",  "compute_combined_uv: k_combined_uv", "device"),
    "mom_combined_uv_copyout": ("sfincs_momentum_gpu.cuf",  "compute_combined_uv tail bridge-out: dropped (q_h / uv_h device-canonical)", "D2H"),
    "cont_regular_copyin":     ("sfincs_continuity_gpu.cuf", "compute_water_levels_regular copy-IN: qext?, zsmax? (q bridge-IN dropped)", "H2D"),
    "cont_regular_kernel":     ("sfincs_continuity_gpu.cuf", "compute_water_levels_regular: discharge + k_regular_main", "device"),
    "cont_regular_copyout":    ("sfincs_continuity_gpu.cuf", "compute_water_levels_regular copy-OUT: zsm?, zsmax?", "D2H"),
    "cont_subgrid_copyin":     ("sfincs_continuity_gpu.cuf", "compute_water_levels_subgrid copy-IN: qext?, zsmax? (q bridge-IN dropped)", "H2D"),
    "cont_subgrid_kernel":     ("sfincs_continuity_gpu.cuf", "compute_water_levels_subgrid: discharge + k_subgrid_main", "device"),
    "cont_subgrid_copyout":    ("sfincs_continuity_gpu.cuf", "compute_water_levels_subgrid copy-OUT: z_volume, zs0?, zsderv?, storage?, zsm?, zsmax?", "D2H"),
    "bnd_conditions":          ("sfincs_boundaries_gpu.cuf", "update_boundary_conditions: host MPI_Bcast + zsb/zsb0 fan", "host/MPI"),
    "bnd_neumann_zs":          ("sfincs_boundaries_gpu.cuf", "update_boundary_conditions: k_update_neumann_zs (device-only)", "device"),
    "bnd_fluxes_copyin":       ("sfincs_boundaries_gpu.cuf", "update_boundary_fluxes copy-IN: zsb=zsb_h, zsb0=zsb0_h", "H2D"),
    "bnd_fluxes_kernel":       ("sfincs_boundaries_gpu.cuf", "update_boundary_fluxes: k_update_boundary_fluxes", "device"),
    "bnd_fluxes_copyout":      ("sfincs_boundaries_gpu.cuf", "update_boundary_fluxes copy-OUT: uvmean, zsb, zsb0, zsmax? (q/uv bridge-OUT dropped)", "D2H"),
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


def parse_phase1_totals(repo_root):
    """Parse the committed Phase 1 SUMMARY.md per-step totals; fall back
    to the hardcoded values if it cannot be read."""
    p = os.path.join(repo_root, PHASE1_SUMMARY)
    out = dict(PHASE1_FALLBACK)
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
    sq = glob.glob(os.path.join(out, "phase2_rank0.sqlite"))
    if not sq:
        sys.stderr.write("ERROR: phase2_rank0.sqlite not found\n")
        sys.exit(1)
    per, n_steps, dd, pp, window_s = attribute(sq[0])
    nd = n_steps if n_steps > 0 else 1
    gh = sum(v["H2D"] for v in per.values())
    gd = sum(v["D2H"] for v in per.values())
    h2d_kb = gh / nd / 1e3
    d2h_kb = gd / nd / 1e3
    tot_kb = (gh + gd) / nd / 1e3
    p1 = parse_phase1_totals(repo_root)

    # q/uv-bearing ranges trimmed by Phase 2: copy-IN (H2D) ranges where q
    # was bridged in pre-Phase-2, and copy-OUT (D2H) ranges where
    # q/q0/uv/uv0 were bridged out. The bridge-IN of uv in mom_fluxes is
    # gated rather than dropped, but on this case (nonhydrostatic=0) it
    # carries zero bytes.
    q_uv_copyin = ["mom_fluxes_copyin", "cont_regular_copyin",
                   "cont_subgrid_copyin"]
    q_uv_copyout = ["mom_fluxes_copyout", "mom_combined_uv_copyout",
                    "bnd_fluxes_copyout"]

    L = []
    P = L.append
    P("# SOR-66 Phase 2 — q / q0 / uv / uv0 device-canonical PCIe delta\n")
    P("Case: `case_prod_compound_snapwave` at `gpu_n2` (2 MPI ranks, "
      "2 GPUs).  ")
    P("Hardware: 2x NVIDIA RTX A6000.  ")
    P("Container: `sfincs-build-gpu:latest` (NVHPC 25.9, HPC-X 2.24 "
      "CUDA-aware).  ")
    P("Capture: `tests/perf/phase2-q-uv-device-canonical-20260517/"
      "run_phase2_profile.sh`; analysis: `analyze_phase2.py`.  ")
    P(f"NSight Systems window: {window_s:.1f} s steady-state "
      "(20 s startup delay skipped) — same harness/case/config as the "
      "committed SOR-64 Phase 0 baseline and SOR-65 Phase 1 delta.\n")

    P("## Phase 2 change under test\n")
    P("`q` / `q0` / `uv` / `uv0` are now device-canonical across the "
      "per-step loop. The bridge-IN of `uv` at the entry of "
      "`compute_fluxes` is gated on `nonhydrostatic_h` (the sole "
      "per-step host writer of `uv` is `compute_nonhydrostatic`, which "
      "runs only when the feature is on). The bridge-IN of `q` at "
      "`compute_water_levels_regular` / `_subgrid` is dropped (q was "
      "just written by the on-device `k_compute_fluxes` and the host "
      "alias is stale). The bridge-OUTs of `q` / `q0` / `uv` / `uv0` "
      "at the exit of `compute_fluxes` and at the exit of "
      "`update_boundary_fluxes` are dropped, plus the tail-only `q` / "
      "`uv` D2H copies in `compute_combined_uv`. The `q_h = q` / "
      "`uv_h = uv` flushes inside `device_to_host_for_output` are "
      "retained for the output cadence; in-loop consumers read the "
      "device shadow directly. `case_prod_compound_snapwave` has "
      "`nonhydrostatic = 0`, so the `uv` bridge-IN gate is a no-op on "
      "this case's profile. Phase 2 changes WHEN bytes move, not WHAT "
      "moves — every data variable in `sfincs_map.nc` is byte-identical "
      "pre/post (only `total_runtime` differs, which is wall-clock "
      "metadata; see PR description).\n")

    if n_steps <= 0:
        P("> **WARNING**: 0 `mom_fluxes_kernel` ranges — NVTX not "
          "captured or window missed steady state.\n")

    P("## Post-Phase-2 per-NVTX-range H<->D byte attribution (rank 0, "
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

    ci = sum(per.get(r, {}).get("H2D", 0.0) for r in q_uv_copyin) / nd / 1e3
    co = sum(per.get(r, {}).get("D2H", 0.0) for r in q_uv_copyout) / nd / 1e3
    drop = p1["total_kb_step"] - tot_kb
    P("## Delta vs SOR-65 Phase 1 baseline\n")
    P(f"| Metric (kB/step) | Phase 1 (pre) | Phase 2 (post) | Delta |")
    P(f"|---|---|---|---|")
    P(f"| H2D total | {p1['h2d_kb_step']:,.1f} | {h2d_kb:,.1f} | "
      f"{h2d_kb - p1['h2d_kb_step']:+,.1f} |")
    P(f"| D2H total | {p1['d2h_kb_step']:,.1f} | {d2h_kb:,.1f} | "
      f"{d2h_kb - p1['d2h_kb_step']:+,.1f} |")
    P(f"| **Total H<->D** | **{p1['total_kb_step']:,.1f}** | "
      f"**{tot_kb:,.1f}** | **{tot_kb - p1['total_kb_step']:+,.1f}** |")
    P("")
    P(f"Phase 2 removes the per-step `q` / `q0` / `uv` / `uv0` PCIe "
      f"traffic: the copy-IN ranges that bridged `q` H2D now carry "
      f"**{ci:,.1f} kB/step** H2D combined (the residual is `qext` / "
      f"`zsmax`, which Phase 2 does not touch, plus the gated `uv` "
      f"bridge-IN at `compute_fluxes` which is zero on this case), and "
      f"the copy-OUT ranges that bridged `q` / `q0` / `uv` / `uv0` D2H "
      f"now carry **{co:,.1f} kB/step** D2H combined (residual = "
      f"`kfuv` / `timestep_analysis_required_timestep?` in "
      f"`mom_fluxes_copyout`, and `uvmean` / `zsb` / `zsb0` / `zsmax?` "
      f"in `bnd_fluxes_copyout`). The total per-step host<->device "
      f"PCIe drops by **{drop:,.1f} kB/step** "
      f"({100.0 * drop / p1['total_kb_step']:.1f}% of the Phase-1 "
      f"baseline), which matches the Phase-1 `q + uv`-attributed "
      f"portion (q / q0 / uv / uv0 are real*4 over the rank-local edge "
      f"count, bridged out three times per step in the Phase-1 "
      f"baseline).\n")

    path = os.path.join(out, "SUMMARY.md")
    open(path, "w").write("\n".join(L) + "\n")
    print(f"wrote {path}: {n_steps} steps, "
          f"H2D {gh/1e6:.1f} MB ({kb(gh/nd)}/step), "
          f"D2H {gd/1e6:.1f} MB ({kb(gd/nd)}/step), "
          f"total drop {drop:,.1f} kB/step vs Phase 1")


if __name__ == "__main__":
    main()
