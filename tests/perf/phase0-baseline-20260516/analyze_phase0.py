#!/usr/bin/env python3
"""SOR-64 Phase 0 — derive the per-NVTX-range H<->D byte budget from the
rank-0 nsys SQLite export and write summary.md.

Why a SQLite join (not `nsys stats`): the `:nvtx-name` modifier on the
nsys stats reports projects NVTX ranges onto *kernels* only, never onto
memory operations, so per-range *byte* attribution is impossible from
the stats CSVs. Instead we join, in the rank-0 .sqlite export
(produced by run_phase0_profile.sh):

  CUPTI_ACTIVITY_KIND_MEMCPY (bytes, copyKind, correlationId)
    -> CUPTI_ACTIVITY_KIND_RUNTIME (correlationId, host start, tid)
    -> NVTX_EVENTS (eventType=59 push/pop, text, [start,end], tid)

The cudaMemcpy host API call (RUNTIME) is issued from the host thread
inside the bridge_in_*/bridge_out_* helper, hence inside the enclosing
NVTX push/pop range; RUNTIME.start within NVTX [start,end] on the same
globalTid attributes the memcpy's bytes to that range. copyKind 1=HtoD,
2=DtoH (3..13 are array/D2D/P2P/UVM — not host<->device PCIe).

bytes-per-step = total range bytes in the window / number of
compute_fluxes calls in the window; the latter is the count of NVTX
ranges named 'mom_fluxes_kernel' (compute_fluxes runs exactly once per
SFINCS time step).
"""
import glob
import os
import re
import sqlite3
import sys

# SOR-52 / PR #100 per-GPU PCIe envelope (tests/perf/FINDINGS.md,
# nvidia-smi dmon, same case/config). Tx = GPU->host, Rx = host->GPU.
SOR52_TX_MBPS = (2160.0, 2477.0)
SOR52_RX_MBPS = (966.0, 1085.0)
WINDOW_S = 60.0

# NVTX range -> (source file, cited block on HEAD, direction).
RANGE_SRC = {
    "mom_fluxes_copyin":       ("sfincs_momentum_gpu.cuf:~134-136",  "compute_fluxes copy-IN: bridge_in_cell_real8(zs), bridge_in_edge_real4(uv)", "H2D"),
    "mom_fluxes_kernel":       ("sfincs_momentum_gpu.cuf:~140-170",  "compute_fluxes: q0/uv0 seed, min_dt seed, k_compute_fluxes", "device"),
    "mom_fluxes_copyout":      ("sfincs_momentum_gpu.cuf:~179-191",  "compute_fluxes copy-OUT: bridge_out q/q0/uv/uv0/kfuv, min_dt, ts-analysis", "D2H"),
    "mom_combined_uv_kernel":  ("sfincs_momentum_gpu.cuf:~228-231",  "compute_combined_uv: k_combined_uv", "device"),
    "mom_combined_uv_copyout": ("sfincs_momentum_gpu.cuf:~243-245",  "compute_combined_uv tail bridge-out: q, uv (tail-only)", "D2H"),
    "cont_regular_copyin":     ("sfincs_continuity_gpu.cuf:~161-167", "compute_water_levels_regular copy-IN: zs, q, qext?, zsmax?", "H2D"),
    "cont_regular_kernel":     ("sfincs_continuity_gpu.cuf:~170-185", "compute_water_levels_regular: discharge + k_regular_main", "device"),
    "cont_regular_copyout":    ("sfincs_continuity_gpu.cuf:~188-220", "compute_water_levels_regular copy-OUT: zs, zsm?, zsmax?", "D2H"),
    "cont_subgrid_copyin":     ("sfincs_continuity_gpu.cuf:~310-316", "compute_water_levels_subgrid copy-IN: zs, q, qext?, zsmax?", "H2D"),
    "cont_subgrid_kernel":     ("sfincs_continuity_gpu.cuf:~318-336", "compute_water_levels_subgrid: discharge + k_subgrid_main", "device"),
    "cont_subgrid_copyout":    ("sfincs_continuity_gpu.cuf:~339-377", "compute_water_levels_subgrid copy-OUT: zs, z_volume, zs0?, zsderv?, storage?, zsm?, zsmax?", "D2H"),
    "bnd_conditions":          ("sfincs_boundaries_gpu.cuf:~131-233", "update_boundary_conditions: host MPI_Bcast + zsb/zsb0/zs fan (AC-named routine; no H<->D)", "host/MPI"),
    "bnd_fluxes_copyin":       ("sfincs_boundaries_gpu.cuf:~335-338", "update_boundary_fluxes copy-IN: bridge_in zs, zsb=zsb_h, zsb0=zsb0_h", "H2D"),
    "bnd_fluxes_kernel":       ("sfincs_boundaries_gpu.cuf:~342-350", "update_boundary_fluxes: k_update_boundary_fluxes", "device"),
    "bnd_fluxes_copyout":      ("sfincs_boundaries_gpu.cuf:~358-385", "update_boundary_fluxes copy-OUT: zs, q, uv, uvmean, zsb, zsb0, zsmax?", "D2H"),
    "halo_q_uv":               ("sfincs_lib.F90:~681",   "halo_exchange_q_uv (inter-rank edge q/uv halo)", "halo"),
    "halo_zs":                 ("sfincs_lib.F90:~702",   "halo_exchange_zs (inter-rank cell zs halo)", "halo"),
    "halo_zsderv":             ("sfincs_lib.F90:~712",   "halo_exchange_zsderv (inter-rank zsderv halo)", "halo"),
    "halo_z_volume":           ("sfincs_lib.F90:~727",   "halo_exchange_z_volume (inter-rank z_volume halo)", "halo"),
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
        slot = per.setdefault(key, {"H2D": 0.0, "D2H": 0.0,
                                    "H2D_ops": 0, "D2H_ops": 0})
        d = "H2D" if ck == 1 else "D2H"
        slot[d] += b or 0
        slot[d + "_ops"] += ops or 0
    # step count = # of compute_fluxes (one mom_fluxes_kernel per step)
    n_steps = q1(con, "SELECT count(*) FROM NVTX_EVENTS "
                      "WHERE eventType=59 AND text='mom_fluxes_kernel'") or 0
    # actual captured window (ns) = span of the per-step NVTX ranges,
    # so the sustained MB/s is honest regardless of the real duration
    # (= NSYS_DURATION_S for the committed run, shorter for a smoke).
    span_ns = q1(con, "SELECT max(end)-min(start) FROM NVTX_EVENTS "
                      "WHERE eventType=59 AND text IS NOT NULL") or 0
    window_s = span_ns / 1e9 if span_ns else 0.0
    inst = dict(con.execute(
        "SELECT text, count(*) FROM NVTX_EVENTS "
        "WHERE eventType=59 AND text IS NOT NULL GROUP BY text").fetchall())
    # device-side / non-PCIe traffic, for context
    dd = q1(con, "SELECT sum(bytes) FROM CUPTI_ACTIVITY_KIND_MEMCPY "
                 "WHERE copyKind=8") or 0
    pp = q1(con, "SELECT sum(bytes) FROM CUPTI_ACTIVITY_KIND_MEMCPY "
                 "WHERE copyKind=10") or 0
    con.close()
    return per, n_steps, inst, dd, pp, window_s


def parse_dmon(path):
    if not os.path.exists(path):
        return {}
    # `nvidia-smi dmon -s utm` columns:
    #   gpu sm mem enc dec jpg ofa rxpci txpci fb bar1 ccpm
    #   0   1  2   3   4   5   6   7     8     9  10   11
    per = {}
    for line in open(path):
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        f = s.split()
        if len(f) < 9 or not f[0].isdigit():
            continue
        try:
            sm, rx, tx = float(f[1]), float(f[7]), float(f[8])
        except ValueError:
            continue
        d = per.setdefault(f[0], {"sm": [], "rx": [], "tx": []})
        d["sm"].append(sm)
        d["rx"].append(rx)
        d["tx"].append(tx)
    return {g: {k: (min(v), max(v)) for k, v in d.items() if v}
            for g, d in per.items()}


def parse_top(path):
    if not os.path.exists(path):
        return None
    cpu = []
    for line in open(path):
        f = line.split()
        if len(f) >= 9 and re.match(r"^\d+$", f[0]):
            try:
                cpu.append(float(f[8]))
            except ValueError:
                pass
    return (min(cpu), max(cpu), sum(cpu) / len(cpu)) if cpu else None


def parse_timing(path):
    if not os.path.exists(path):
        return []
    keys = ("Total time", "Time in", "Average time step",
            "simulation finished", "number of time steps", "tot. time")
    out = [ln.rstrip() for ln in open(path, errors="replace")
           if any(k.lower() in ln.lower() for k in keys)]
    return out[:16]


def mb(x):
    return f"{x / 1e6:,.2f} MB"


def kb(x):
    return f"{x / 1e3:,.1f} kB"


def span(dmon, key):
    if not dmon:
        return "n/a"
    lo = min(d.get(key, (0, 0))[0] for d in dmon.values())
    hi = max(d.get(key, (0, 0))[1] for d in dmon.values())
    return f"{lo:.0f}-{hi:.0f}"


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    sq = glob.glob(os.path.join(out, "phase0_rank0.sqlite"))
    if not sq:
        sys.stderr.write("ERROR: phase0_rank0.sqlite not found\n")
        sys.exit(1)
    per, n_steps, inst, dd, pp, window_s = attribute(sq[0])
    if window_s <= 0:
        window_s = WINDOW_S
    dmon = parse_dmon(os.path.join(out, "nvidia_smi_dmon.txt"))
    top = parse_top(os.path.join(out, "rank0_top.txt"))
    timing = parse_timing(os.path.join(out, "sfincs.log"))
    reps = sorted(os.path.basename(r)
                  for r in glob.glob(os.path.join(out, "phase0_rank0.nsys-rep")))

    nd = n_steps if n_steps > 0 else 1
    gh = sum(v["H2D"] for v in per.values())
    gd = sum(v["D2H"] for v in per.values())

    L = []
    P = L.append
    P("# SOR-64 Phase 0 — canonical-on-device PCIe baseline\n")
    P("Case: `case_prod_compound_snapwave` at `gpu_n2` (2 MPI ranks, "
      "2 GPUs).  ")
    P("Hardware: 2x NVIDIA RTX A6000.  ")
    P("Container: `sfincs-build-gpu:latest` (NVHPC 25.9, HPC-X 2.24 "
      "CUDA-aware).  ")
    P("Capture: `tests/perf/phase0-baseline-20260516/"
      "run_phase0_profile.sh`; analysis: `analyze_phase0.py`.  ")
    P(f"NSight Systems window: {window_s:.1f} s steady-state "
      f"(target {WINDOW_S:.0f} s; 20 s startup delay skipped).  ")
    P("Profiled rank: rank 0 (`" + ", ".join(reps) + "`). The 2-rank "
      "domain decomposition is symmetric, so rank 0's per-step "
      "bridge_in_*/bridge_out_* H<->D inventory is representative of "
      "both ranks; rank 1 ran bare so the `halo_*` ranges still see "
      "real inter-rank traffic.\n")

    P("## Phase 0 is pure measurement\n")
    P("No behaviour change. The four per-step GPU routines "
      "(`compute_fluxes`, `compute_water_levels_regular/_subgrid`, "
      "`update_boundary_fluxes`) and the four `sfincs_lib.F90` halo "
      "helpers are wrapped in named NVTX push/pop ranges via the "
      "`sfincs_nvtx` helper (NVHPC `nvtx` shim, linked through "
      "`-lnvhpcwrapnvtx`). On CPU the ranges are a strict no-op "
      "(`.cuf`-only module; the `sfincs_lib.F90` calls are "
      "`#ifdef USE_CUDA`).\n")
    P("> AC naming note: AC #1 names the boundary routine "
      "`update_boundary_conditions`, but the copy-IN (lines ~335-337) "
      "/ kernel / copy-OUT (lines ~358-363) the issue Notes cite by "
      "line number live in `update_boundary_fluxes` "
      "(`update_boundary_conditions` is the host MPI_Bcast feeder, no "
      "H<->D block). Both routines are annotated: `bnd_fluxes_*` "
      "carries the per-step H<->D traffic; `bnd_conditions` carries "
      "the host/MPI feeder so the profile separates them cleanly.\n")

    if n_steps <= 0:
        P("> **WARNING**: 0 `mom_fluxes_kernel` ranges in the window — "
          "NVTX not captured or window missed steady state. Per-step "
          "columns unreliable.\n")

    P("## Per-NVTX-range H<->D byte attribution (rank 0, "
      f"{n_steps} steps in window)\n")
    P("| NVTX range | Source (HEAD) — block | Dir | H2D total | "
      "D2H total | H2D/step | D2H/step |")
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
    P(f"- Attributed **H2D total {mb(gh)}** -> "
      f"**{kb(gh / nd)}/step**")
    P(f"- Attributed **D2H total {mb(gd)}** -> "
      f"**{kb(gd / nd)}/step**")
    P(f"- **Total H<->D per step: {kb((gh + gd) / nd)}** "
      f"({kb(gh / nd)} H2D + {kb(gd / nd)} D2H)")
    P(f"- Sustained from nsys attributed bytes / {window_s:.1f}s: "
      f"H2D **{gh / window_s / 1e6:,.0f} MB/s**, "
      f"D2H **{gd / window_s / 1e6:,.0f} MB/s**")
    P(f"- Non-PCIe context (not host<->device): device-to-device "
      f"{mb(dd)}, peer-to-peer {mb(pp)} over the window.\n")

    P("## Sustained PCIe + GPU occupancy (nvidia-smi dmon)\n")
    if dmon:
        P("| GPU | sm% min-max | PCIe Rx MB/s min-max | "
          "PCIe Tx MB/s min-max |")
        P("|---|---|---|---|")
        for g in sorted(dmon):
            d = dmon[g]
            P(f"| {g} | {span({g: d}, 'sm')} | "
              f"{span({g: d}, 'rx')} | {span({g: d}, 'tx')} |")
        P("")
    else:
        P("_no parseable dmon rows_\n")
    if top:
        P(f"Rank-0 sfincs %CPU (in-container top): min {top[0]:.0f}, "
          f"max {top[1]:.0f}, mean {top[2]:.0f}.\n")

    P("## Bandwidth-arithmetic closure vs SOR-52 / PR #100\n")
    P(f"SOR-52 (`tests/perf/FINDINGS.md`) measured, per GPU on this "
      f"exact case/config, a PCIe **Tx "
      f"{SOR52_TX_MBPS[0]:.0f}-{SOR52_TX_MBPS[1]:.0f} MB/s** + **Rx "
      f"{SOR52_RX_MBPS[0]:.0f}-{SOR52_RX_MBPS[1]:.0f} MB/s** envelope "
      f"via nvidia-smi dmon. nsys attributes the per-step memcpy bytes "
      f"to source blocks; nvidia-smi PCIe counters are the independent "
      f"ground truth.\n")
    P("Direction mapping: GPU PCIe **Tx** = device->host = our "
      "**D2H**; GPU PCIe **Rx** = host->device = our **H2D**.\n")
    P(f"- nsys D2H {gd / window_s / 1e6:,.0f} MB/s vs nvidia-smi Tx: "
      f"SOR-52 {SOR52_TX_MBPS[0]:.0f}-{SOR52_TX_MBPS[1]:.0f}, this run "
      f"{span(dmon, 'tx')} MB/s.")
    P(f"- nsys H2D {gh / window_s / 1e6:,.0f} MB/s vs nvidia-smi Rx: "
      f"SOR-52 {SOR52_RX_MBPS[0]:.0f}-{SOR52_RX_MBPS[1]:.0f}, this run "
      f"{span(dmon, 'rx')} MB/s.\n")
    P("The nvidia-smi PCIe counters also include the SnapWave `dtwave` "
      "exchange, meteo updates, the periodic output gather, and any "
      "MPI host-staging — none of which are inside the four annotated "
      "per-step routines. The gap between the nsys per-step attributed "
      "rate and the sustained nvidia-smi counter is exactly that "
      "unannotated residual, and quantifying it per source block is "
      "what Phases 1-5 are measured against.\n")

    if timing:
        P("## SFINCS timing (sfincs.log)\n```")
        for t in timing:
            P(t)
        P("```")

    path = os.path.join(out, "summary.md")
    open(path, "w").write("\n".join(L) + "\n")
    print(f"wrote {path}: {n_steps} steps, "
          f"H2D {gh/1e6:.1f} MB ({kb(gh/nd)}/step), "
          f"D2H {gd/1e6:.1f} MB ({kb(gd/nd)}/step)")


if __name__ == "__main__":
    main()
