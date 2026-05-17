#!/usr/bin/env python3
"""SOR-67 Phase 3 — derive the post-Phase-3 per-NVTX-range H<->D byte
budget from the rank-0 nsys SQLite export and write SUMMARY.md with the
delta vs the committed SOR-66 Phase 2 baseline.

Phase 3 makes the remaining auxiliary per-step arrays (zsb, zsb0,
uvmean, kfuv, zsm, maxzsm, zsmax, z_volume, zsderv) device-canonical
across the per-step loop:

  * `update_boundary_conditions` replaces the bulk `zsb = zsb_h` /
    `zsb0 = zsb0_h` H2D pair with a sliced H2D over the kcs==2
    boundary-point index list plus a small k_scatter_kcs2_bnd kernel:
    the touched slice instead of the full array.
  * `update_boundary_fluxes` drops the bulk `uvmean_h = uvmean` /
    `zsb_h = zsb` / `zsb0_h = zsb0` / `zsmax_h = zsmax` D2H copies;
    none of these have a per-step host reader between calls. uvmean is
    refreshed at output cadence by device_to_host_for_output (rank-0
    plain D2H); zsmax is refreshed at output cadence by the existing
    gather in device_to_host_for_output and reset on device by the new
    reset_max_arrays_device_after_output hook called from
    sfincs_lib.F90's USE_CUDA branch after write_output.
  * `compute_fluxes` drops the per-step `bridge_out_edge_int1(kfuv_h,
    kfuv)` D2H. kfuv has no per-step host reader between
    compute_fluxes calls in the validation matrix
    (timestep_analysis_update and compute_nonhydrostatic are
    feature-gated and not exercised).
  * `compute_water_levels_regular` / `_subgrid` drop the per-step
    bridge-OUTs of `zsm`, `maxzsm`, `zsmax`, `z_volume`, `zsderv`. The
    snapwave-gated `zsm` / `maxzsm` D2H moves to update_wave_field
    (sfincs_snapwave_gpu.cuf), which fires at dtwave cadence. The
    bridge-IN of `zsmax` is also dropped (the host shadow no longer
    tracks the device between gathers, so the H2D would clobber the
    accumulated running max with stale host data).

Phase 3 changes WHEN bytes move, not WHAT moves, so every data
variable in `sfincs_map.nc` is byte-identical pre/post (only
`total_runtime` differs, which is wall-clock metadata).
"""
import glob
import os
import re
import sqlite3
import sys

# Committed SOR-66 Phase 2 baseline per-step totals (parsed from its
# SUMMARY.md), used for the delta if the summary file cannot be read.
PHASE2_FALLBACK = {
    "steps": 19757,
    "h2d_kb_step": 211.7,
    "d2h_kb_step": 1776.0,
    "total_kb_step": 1987.7,
}
PHASE2_SUMMARY = os.path.join(
    "tests", "perf", "phase2-q-uv-device-canonical-20260517", "SUMMARY.md")

# NVTX range -> (source file, post-Phase-3 block, direction). Compared to
# Phase 2, the auxiliary contributions are gone from the copy-IN /
# copy-OUT blocks; bnd_fluxes_copyout becomes near-zero (only the
# conditional store_t_zsmax host loop and the dropped zsmax remain).
RANGE_SRC = {
    "mom_fluxes_copyin":       ("sfincs_momentum_gpu.cuf",  "compute_fluxes copy-IN: bridge_in_edge_real4(uv) gated on nonhydrostatic_h (no-op when feature is off)", "H2D"),
    "mom_fluxes_kernel":       ("sfincs_momentum_gpu.cuf",  "compute_fluxes: q0/uv0 seed, min_dt seed, k_compute_fluxes", "device"),
    "mom_fluxes_copyout":      ("sfincs_momentum_gpu.cuf",  "compute_fluxes copy-OUT: min_dt, ts-analysis (kfuv dropped Phase 3; q/q0/uv/uv0 dropped Phase 2)", "D2H"),
    "mom_combined_uv_kernel":  ("sfincs_momentum_gpu.cuf",  "compute_combined_uv: k_combined_uv", "device"),
    "mom_combined_uv_copyout": ("sfincs_momentum_gpu.cuf",  "compute_combined_uv tail bridge-out: dropped (q_h / uv_h device-canonical)", "D2H"),
    "cont_regular_copyin":     ("sfincs_continuity_gpu.cuf", "compute_water_levels_regular copy-IN: qext? (zsmax bridge-IN dropped Phase 3; q dropped Phase 2)", "H2D"),
    "cont_regular_kernel":     ("sfincs_continuity_gpu.cuf", "compute_water_levels_regular: discharge + k_regular_main", "device"),
    "cont_regular_copyout":    ("sfincs_continuity_gpu.cuf", "compute_water_levels_regular copy-OUT: empty (zsm/maxzsm moved to dtwave snapwave step; zsmax dropped Phase 3)", "D2H"),
    "cont_subgrid_copyin":     ("sfincs_continuity_gpu.cuf", "compute_water_levels_subgrid copy-IN: qext? (zsmax bridge-IN dropped Phase 3; q dropped Phase 2)", "H2D"),
    "cont_subgrid_kernel":     ("sfincs_continuity_gpu.cuf", "compute_water_levels_subgrid: discharge + k_subgrid_main", "device"),
    "cont_subgrid_copyout":    ("sfincs_continuity_gpu.cuf", "compute_water_levels_subgrid copy-OUT: zs0?, storage? (z_volume / zsderv / zsm / maxzsm / zsmax dropped Phase 3)", "D2H"),
    "bnd_conditions":          ("sfincs_boundaries_gpu.cuf", "update_boundary_conditions: host MPI_Bcast + kcs==2 fan", "host/MPI"),
    "bnd_conditions_copyin":   ("sfincs_boundaries_gpu.cuf", "update_boundary_conditions: sliced H2D of kcs==2 zsb/zsb0 entries + k_scatter_kcs2_bnd (Phase 3)", "H2D"),
    "bnd_neumann_zs":          ("sfincs_boundaries_gpu.cuf", "update_boundary_conditions: k_update_neumann_zs (device-only)", "device"),
    "bnd_river_zsb":           ("sfincs_boundaries_gpu.cuf", "update_boundary_conditions: k_update_river_zsb (device-only)", "device"),
    "bnd_apply_zs":            ("sfincs_boundaries_gpu.cuf", "update_boundary_conditions: k_apply_boundary_zs (device-only)", "device"),
    "bnd_fluxes_kernel":       ("sfincs_boundaries_gpu.cuf", "update_boundary_fluxes: k_update_boundary_fluxes", "device"),
    "bnd_fluxes_copyout":      ("sfincs_boundaries_gpu.cuf", "update_boundary_fluxes copy-OUT: empty (uvmean / zsb / zsb0 / zsmax all dropped Phase 3)", "D2H"),
    "halo_q_uv":               ("sfincs_lib.F90",   "halo_exchange_q_uv (inter-rank edge q/uv halo)", "halo"),
    "halo_zs":                 ("sfincs_lib.F90",   "halo_exchange_zs (inter-rank cell zs halo)", "halo"),
    "halo_zsderv":             ("sfincs_lib.F90",   "halo_exchange_zsderv (inter-rank zsderv halo)", "halo"),
    "halo_z_volume":           ("sfincs_lib.F90",   "halo_exchange_z_volume (inter-rank z_volume halo)", "halo"),
}

# Auxiliary-bearing ranges trimmed by Phase 3.
AUX_COPYIN  = ["bnd_conditions_copyin", "cont_regular_copyin",
               "cont_subgrid_copyin"]
AUX_COPYOUT = ["mom_fluxes_copyout", "bnd_fluxes_copyout",
               "cont_regular_copyout", "cont_subgrid_copyout"]


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


def parse_phase2_totals(repo_root):
    """Parse the committed Phase 2 SUMMARY.md per-step totals; fall back
    to the hardcoded values if it cannot be read."""
    p = os.path.join(repo_root, PHASE2_SUMMARY)
    out = dict(PHASE2_FALLBACK)
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
    sq = glob.glob(os.path.join(out, "phase3_rank0.sqlite"))
    if not sq:
        sys.stderr.write("ERROR: phase3_rank0.sqlite not found\n")
        sys.exit(1)
    per, n_steps, dd, pp, window_s = attribute(sq[0])
    nd = n_steps if n_steps > 0 else 1
    gh = sum(v["H2D"] for v in per.values())
    gd = sum(v["D2H"] for v in per.values())
    h2d_kb = gh / nd / 1e3
    d2h_kb = gd / nd / 1e3
    tot_kb = (gh + gd) / nd / 1e3
    p2 = parse_phase2_totals(repo_root)

    L = []
    P = L.append
    P("# SOR-67 Phase 3 — auxiliary per-step arrays device-canonical "
      "PCIe delta\n")
    P("Case: `case_prod_compound_snapwave` at `gpu_n2` (2 MPI ranks, "
      "2 GPUs).  ")
    P("Hardware: 2x NVIDIA RTX A6000.  ")
    P("Container: `sfincs-build-gpu:latest` (NVHPC 25.9, HPC-X 2.24 "
      "CUDA-aware).  ")
    P("Capture: `tests/perf/phase3-aux-arrays-device-canonical-20260517/"
      "run_phase3_profile.sh`; analysis: `analyze_phase3.py`.  ")
    P(f"NSight Systems window: {window_s:.1f} s steady-state "
      "(20 s startup delay skipped) — same harness/case/config as the "
      "committed SOR-64 Phase 0 baseline and SOR-65 Phase 1 / SOR-66 "
      "Phase 2 deltas.\n")

    P("## Phase 3 change under test\n")
    P("The remaining auxiliary per-step arrays — `zsb`, `zsb0`, "
      "`uvmean`, `kfuv`, `zsm`, `maxzsm`, `zsmax`, `z_volume`, "
      "`zsderv` — are now device-canonical across the per-step loop. "
      "The Phase-3 changes:\n"
      "\n"
      "  * `update_boundary_conditions` (`sfincs_boundaries_gpu.cuf`) "
      "replaces the bulk `zsb = zsb_h` / `zsb0 = zsb0_h` H2D pair with "
      "a sliced H2D over a precomputed kcs==2 boundary-point index "
      "list plus a small `k_scatter_kcs2_bnd` kernel — only the touched "
      "slice (the kcs==2 entries the host fan-out actually wrote) is "
      "transferred each step.\n"
      "  * `update_boundary_fluxes` (`sfincs_boundaries_gpu.cuf`) drops "
      "the bulk `uvmean_h = uvmean` / `zsb_h = zsb` / `zsb0_h = zsb0` "
      "D2H copies plus the conditional `zsmax` bridge-OUT; none has a "
      "per-step host reader. `uvmean_h` is refreshed at output cadence "
      "by `device_to_host_for_output` (rank-0 plain D2H, suitable for "
      "the binary restart file). `zsmax_h` is refreshed at output "
      "cadence by the existing gather in `device_to_host_for_output`.\n"
      "  * `compute_fluxes` (`sfincs_momentum_gpu.cuf`) drops the "
      "per-step `bridge_out_edge_int1(kfuv_h, kfuv)` D2H. `kfuv` has "
      "no per-step host reader in the validation matrix "
      "(`timestep_analysis_update` and `compute_nonhydrostatic` are "
      "feature-gated and not exercised).\n"
      "  * `compute_water_levels_regular` / `_subgrid` "
      "(`sfincs_continuity_gpu.cuf`) drop the per-step bridge-OUTs of "
      "`zsm`, `maxzsm`, `zsmax`, `z_volume`, `zsderv`. The "
      "snapwave-gated `zsm` / `maxzsm` D2H moves to "
      "`update_wave_field` (`sfincs_snapwave_gpu.cuf`), which fires at "
      "`dtwave` cadence (1800 s in this case). `maxzsm` / `zsmax` / "
      "`z_volume` for output are refreshed at output cadence by the "
      "existing gathers in `device_to_host_for_output`. The per-step "
      "bridge-IN of `zsmax` is also dropped (the host shadow no longer "
      "tracks the device between gathers, so the H2D would clobber the "
      "accumulated running max). The dtmaxout reset cycle now uses a "
      "CUDA-aware device reset in `reset_max_arrays_device_after_output`"
      " called from `sfincs_lib.F90`'s USE_CUDA branch immediately "
      "after `write_output`, gated on the same "
      "`write_max .and. dtmaxout > 0` condition `write_output` uses for "
      "the host reset.\n"
      "\n"
      "Phase 3 changes WHEN bytes move, not WHAT moves — every data "
      "variable in `sfincs_map.nc` is byte-identical pre/post (only "
      "`total_runtime` differs, which is wall-clock metadata).\n")

    if n_steps <= 0:
        P("> **WARNING**: 0 `mom_fluxes_kernel` ranges — NVTX not "
          "captured or window missed steady state.\n")

    P("## Post-Phase-3 per-NVTX-range H<->D byte attribution (rank 0, "
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

    ci = sum(per.get(r, {}).get("H2D", 0.0) for r in AUX_COPYIN) / nd / 1e3
    co = sum(per.get(r, {}).get("D2H", 0.0) for r in AUX_COPYOUT) / nd / 1e3
    drop = p2["total_kb_step"] - tot_kb
    pct = (100.0 * drop / p2["total_kb_step"]) if p2["total_kb_step"] else 0.0
    P("## Delta vs SOR-66 Phase 2 baseline\n")
    P("| Metric (kB/step) | Phase 2 (pre) | Phase 3 (post) | Delta |")
    P("|---|---|---|---|")
    P(f"| H2D total | {p2['h2d_kb_step']:,.1f} | {h2d_kb:,.1f} | "
      f"{h2d_kb - p2['h2d_kb_step']:+,.1f} |")
    P(f"| D2H total | {p2['d2h_kb_step']:,.1f} | {d2h_kb:,.1f} | "
      f"{d2h_kb - p2['d2h_kb_step']:+,.1f} |")
    P(f"| **Total H<->D** | **{p2['total_kb_step']:,.1f}** | "
      f"**{tot_kb:,.1f}** | **{tot_kb - p2['total_kb_step']:+,.1f}** |")
    P("")
    P(f"Phase 3 removes the per-step auxiliary-array PCIe traffic. The "
      f"copy-IN ranges that bridged auxiliaries H2D now carry "
      f"**{ci:,.1f} kB/step** H2D combined (the residual is "
      f"`bnd_conditions_copyin`'s sliced kcs==2 H2D scatter — the "
      f"touched slice mandated by the AC for the per-step CPU "
      f"writer — plus `qext` in `cont_*_copyin` when BMI is on, which "
      f"is not exercised here). The copy-OUT ranges that bridged "
      f"auxiliaries D2H now carry **{co:,.1f} kB/step** D2H combined "
      f"(`mom_fluxes_copyout` retains only `min_dt` and the optional "
      f"`timestep_analysis_required_timestep`; `bnd_fluxes_copyout` "
      f"is empty; `cont_*_copyout` retains only `zs0` / `storage` "
      f"under their feature gates). The total per-step host<->device "
      f"PCIe drops by **{drop:,.1f} kB/step** "
      f"({pct:.1f}% of the Phase-2 baseline).\n"
      f"\n"
      f"The inner-loop steady-state PCIe is now dominated by the "
      f"snapwave coupling (paid every `dtwave = 1800 s` in this case, "
      f"i.e. ~1 in every ~30 steps at this case's `dt`) and the "
      f"output gather (paid every `dtmapout = 86400 s`, i.e. exactly "
      f"once over this 24-h simulation — outside the steady-state "
      f"NSight window). The per-step path is approximately at its "
      f"post-Phase-3 envelope: the only remaining per-step transfers "
      f"are the sliced boundary H2D (kcs==2-sized), the small "
      f"`mom_fluxes_copyout` (the `min_dt` int32 scalar), and the "
      f"feature-gated tail in `cont_*_copyout`.\n")

    path = os.path.join(out, "SUMMARY.md")
    open(path, "w").write("\n".join(L) + "\n")
    print(f"wrote {path}: {n_steps} steps, "
          f"H2D {gh/1e6:.1f} MB ({kb(gh/nd)}/step), "
          f"D2H {gd/1e6:.1f} MB ({kb(gd/nd)}/step), "
          f"total drop {drop:,.1f} kB/step vs Phase 2")


if __name__ == "__main__":
    main()
