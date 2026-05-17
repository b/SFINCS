# SOR-65 Phase 1 — zs device-canonical PCIe delta

Case: `case_prod_compound_snapwave` at `gpu_n2` (2 MPI ranks, 2 GPUs).  
Hardware: 2x NVIDIA RTX A6000.  
Container: `sfincs-build-gpu:latest` (NVHPC 25.9, HPC-X 2.24 CUDA-aware).  
Capture: `tests/perf/phase1-zs-device-canonical-20260516/run_phase1_profile.sh`; analysis: `analyze_phase1.py`.  
NSight Systems window: 60.0 s steady-state (20 s startup delay skipped) — same harness/case/config as the committed SOR-64 Phase 0 baseline.

## Phase 1 change under test

`zs` is now device-canonical across the per-step loop. The five per-step `zs` H<->D bridges (compute_fluxes bridge-IN; compute_water_levels_regular / _subgrid bridge-IN + bridge-OUT; update_boundary_fluxes bridge-IN + bridge-OUT) are dropped, and the one per-step `zs` host writer — the kcs==6 Neumann lateral copy — is ported to the on-device `k_update_neumann_zs` kernel (NVTX range `bnd_neumann_zs`). The `zs_h = zs` flush inside the device-to-host output path is retained. Phase 1 changes WHEN bytes move, not WHAT moves — `sfincs_map.nc` is byte-identical pre/post (see PR description for the `cmp` gate).

## Post-Phase-1 per-NVTX-range H<->D byte attribution (rank 0, 13313 steps in window)

| NVTX range | Source — block | Dir | H2D total | D2H total | H2D/step | D2H/step |
|---|---|---|---|---|---|---|
| `mom_fluxes_copyin` | `sfincs_momentum_gpu.cuf` — compute_fluxes copy-IN: bridge_in_edge_real4(uv) only (zs bridge-IN dropped) | H2D | 5,558.92 MB | 0.00 MB | 417.6 kB | 0.0 kB |
| `mom_fluxes_kernel` | `sfincs_momentum_gpu.cuf` — compute_fluxes: q0/uv0 seed, min_dt seed, k_compute_fluxes | device | 0.05 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `mom_fluxes_copyout` | `sfincs_momentum_gpu.cuf` — compute_fluxes copy-OUT: q/q0/uv/uv0/kfuv, min_dt, ts-analysis (no zs) | D2H | 0.00 MB | 23,995.05 MB | 0.0 kB | 1,802.4 kB |
| `mom_combined_uv_kernel` | `sfincs_momentum_gpu.cuf` — compute_combined_uv: k_combined_uv | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `mom_combined_uv_copyout` | `sfincs_momentum_gpu.cuf` — compute_combined_uv tail bridge-out: q, uv (tail-only) | D2H | 0.00 MB | 101.50 MB | 0.0 kB | 7.6 kB |
| `cont_regular_copyin` | `sfincs_continuity_gpu.cuf` — compute_water_levels_regular copy-IN: q, qext?, zsmax? (zs bridge-IN dropped) | H2D | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `cont_regular_kernel` | `sfincs_continuity_gpu.cuf` — compute_water_levels_regular: discharge + k_regular_main | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `cont_regular_copyout` | `sfincs_continuity_gpu.cuf` — compute_water_levels_regular copy-OUT: zsm?, zsmax? (zs bridge-OUT dropped) | D2H | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `cont_subgrid_copyin` | `sfincs_continuity_gpu.cuf` — compute_water_levels_subgrid copy-IN: q, qext?, zsmax? (zs bridge-IN dropped) | H2D | 8,330.58 MB | 0.00 MB | 625.7 kB | 0.0 kB |
| `cont_subgrid_kernel` | `sfincs_continuity_gpu.cuf` — compute_water_levels_subgrid: discharge + k_subgrid_main | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `cont_subgrid_copyout` | `sfincs_continuity_gpu.cuf` — compute_water_levels_subgrid copy-OUT: z_volume, zs0?, zsderv?, storage?, zsm?, zsmax? (zs bridge-OUT dropped) | D2H | 0.00 MB | 19,401.00 MB | 0.0 kB | 1,457.3 kB |
| `bnd_conditions` | `sfincs_boundaries_gpu.cuf` — update_boundary_conditions: host MPI_Bcast + zsb/zsb0 fan (kcs==6 now on-device) | host/MPI | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `bnd_neumann_zs` | `sfincs_boundaries_gpu.cuf` — update_boundary_conditions: k_update_neumann_zs (kcs==6 Neumann, device-only) | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `bnd_fluxes_copyin` | `sfincs_boundaries_gpu.cuf` — update_boundary_fluxes copy-IN: zsb=zsb_h, zsb0=zsb0_h (zs bridge-IN dropped) | H2D | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `bnd_fluxes_kernel` | `sfincs_boundaries_gpu.cuf` — update_boundary_fluxes: k_update_boundary_fluxes | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `bnd_fluxes_copyout` | `sfincs_boundaries_gpu.cuf` — update_boundary_fluxes copy-OUT: q, uv, uvmean, zsb, zsb0, zsmax? (zs bridge-OUT dropped) | D2H | 0.00 MB | 14,104.01 MB | 0.0 kB | 1,059.4 kB |
| `halo_q_uv` | `sfincs_lib.F90` — halo_exchange_q_uv (inter-rank edge q/uv halo) | halo | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `halo_zs` | `sfincs_lib.F90` — halo_exchange_zs (inter-rank cell zs halo) | halo | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `halo_zsderv` | `sfincs_lib.F90` — halo_exchange_zsderv (inter-rank zsderv halo) | halo | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `halo_z_volume` | `sfincs_lib.F90` — halo_exchange_z_volume (inter-rank z_volume halo) | halo | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `(unattributed)` | (outside annotated ranges: one-time init / output gather / snapwave) | ? | 18.97 MB | 36.38 MB | 1.4 kB | 2.7 kB |
| `bnd_conditions_copyin` | (outside annotated ranges: one-time init / output gather / snapwave) | ? | 27.69 MB | 0.00 MB | 2.1 kB | 0.0 kB |

## Totals over the window

- Steps (compute_fluxes calls): **13313**
- Attributed **H2D total 13,936.22 MB** -> **1,046.8 kB/step**
- Attributed **D2H total 57,637.92 MB** -> **4,329.4 kB/step**
- **Total H<->D per step: 5,376.3 kB** (1,046.8 kB H2D + 4,329.4 kB D2H)
- Non-PCIe context: device-to-device 11,297.73 MB, peer-to-peer 176.38 MB over the window.

## Delta vs SOR-64 Phase 0 baseline

| Metric (kB/step) | Phase 0 (pre) | Phase 1 (post) | Delta |
|---|---|---|---|
| H2D total | 2,296.0 | 1,046.8 | -1,249.2 |
| D2H total | 5,144.1 | 4,329.4 | -814.7 |
| **Total H<->D** | **7,440.1** | **5,376.3** | **-2,063.8** |

Phase 1 removes the per-step `zs` PCIe traffic: the four copy-IN ranges that bridged `zs` H2D now carry **1,043.3 kB/step** H2D combined (the residual is the non-zs arrays — uv / q / zsb / zsb0 / qext? / zsmax? — which Phase 1 does not touch), and the three copy-OUT ranges that bridged `zs` D2H now carry **2,516.7 kB/step** D2H combined (residual = z_volume / q / uv / uvmean / zsb / zsb0 / zsm? / zsmax?). The total per-step host<->device PCIe drops by **2,063.8 kB/step** (27.7% of the Phase-0 baseline), which matches the Phase-0 `zs`-attributed portion (`zs` is real*8 over the rank-local cell count, bridged five times per step in the baseline). The new `bnd_neumann_zs` range is device-only (0 H<->D bytes): the kcs==6 Neumann update now runs entirely on the device `zs` shadow.

