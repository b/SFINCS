# SOR-66 Phase 2 — q / q0 / uv / uv0 device-canonical PCIe delta

Case: `case_prod_compound_snapwave` at `gpu_n2` (2 MPI ranks, 2 GPUs).  
Hardware: 2x NVIDIA RTX A6000.  
Container: `sfincs-build-gpu:latest` (NVHPC 25.9, HPC-X 2.24 CUDA-aware).  
Capture: `tests/perf/phase2-q-uv-device-canonical-20260517/run_phase2_profile.sh`; analysis: `analyze_phase2.py`.  
NSight Systems window: 58.1 s steady-state (20 s startup delay skipped) — same harness/case/config as the committed SOR-64 Phase 0 baseline and SOR-65 Phase 1 delta.

## Phase 2 change under test

`q` / `q0` / `uv` / `uv0` are now device-canonical across the per-step loop. The bridge-IN of `uv` at the entry of `compute_fluxes` is gated on `nonhydrostatic_h` (the sole per-step host writer of `uv` is `compute_nonhydrostatic`, which runs only when the feature is on). The bridge-IN of `q` at `compute_water_levels_regular` / `_subgrid` is dropped (q was just written by the on-device `k_compute_fluxes` and the host alias is stale). The bridge-OUTs of `q` / `q0` / `uv` / `uv0` at the exit of `compute_fluxes` and at the exit of `update_boundary_fluxes` are dropped, plus the tail-only `q` / `uv` D2H copies in `compute_combined_uv`. The `q_h = q` / `uv_h = uv` flushes inside `device_to_host_for_output` are retained for the output cadence; in-loop consumers read the device shadow directly. `case_prod_compound_snapwave` has `nonhydrostatic = 0`, so the `uv` bridge-IN gate is a no-op on this case's profile. Phase 2 changes WHEN bytes move, not WHAT moves — every data variable in `sfincs_map.nc` is byte-identical pre/post (only `total_runtime` differs, which is wall-clock metadata; see PR description).

## Post-Phase-2 per-NVTX-range H<->D byte attribution (rank 0, 19757 steps in window)

| NVTX range | Source — block | Dir | H2D total | D2H total | H2D/step | D2H/step |
|---|---|---|---|---|---|---|
| `mom_fluxes_copyin` | `sfincs_momentum_gpu.cuf` — compute_fluxes copy-IN: bridge_in_edge_real4(uv) gated on nonhydrostatic_h (no-op when feature is off) | H2D | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `mom_fluxes_kernel` | `sfincs_momentum_gpu.cuf` — compute_fluxes: q0/uv0 seed, min_dt seed, k_compute_fluxes | device | 0.08 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `mom_fluxes_copyout` | `sfincs_momentum_gpu.cuf` — compute_fluxes copy-OUT: kfuv, min_dt, ts-analysis (q/q0/uv/uv0 dropped) | D2H | 0.00 MB | 2,077.03 MB | 0.0 kB | 105.1 kB |
| `mom_combined_uv_kernel` | `sfincs_momentum_gpu.cuf` — compute_combined_uv: k_combined_uv | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `mom_combined_uv_copyout` | `sfincs_momentum_gpu.cuf` — compute_combined_uv tail bridge-out: dropped (q_h / uv_h device-canonical) | D2H | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `cont_regular_copyin` | `sfincs_continuity_gpu.cuf` — compute_water_levels_regular copy-IN: qext?, zsmax? (q bridge-IN dropped) | H2D | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `cont_regular_kernel` | `sfincs_continuity_gpu.cuf` — compute_water_levels_regular: discharge + k_regular_main | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `cont_regular_copyout` | `sfincs_continuity_gpu.cuf` — compute_water_levels_regular copy-OUT: zsm?, zsmax? | D2H | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `cont_subgrid_copyin` | `sfincs_continuity_gpu.cuf` — compute_water_levels_subgrid copy-IN: qext?, zsmax? (q bridge-IN dropped) | H2D | 4,113.25 MB | 0.00 MB | 208.2 kB | 0.0 kB |
| `cont_subgrid_kernel` | `sfincs_continuity_gpu.cuf` — compute_water_levels_subgrid: discharge + k_subgrid_main | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `cont_subgrid_copyout` | `sfincs_continuity_gpu.cuf` — compute_water_levels_subgrid copy-OUT: z_volume, zs0?, zsderv?, storage?, zsm?, zsmax? | D2H | 0.00 MB | 28,792.75 MB | 0.0 kB | 1,457.3 kB |
| `bnd_conditions` | `sfincs_boundaries_gpu.cuf` — update_boundary_conditions: host MPI_Bcast + zsb/zsb0 fan | host/MPI | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `bnd_neumann_zs` | `sfincs_boundaries_gpu.cuf` — update_boundary_conditions: k_update_neumann_zs (device-only) | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `bnd_fluxes_copyin` | `sfincs_boundaries_gpu.cuf` — update_boundary_fluxes copy-IN: zsb=zsb_h, zsb0=zsb0_h | H2D | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `bnd_fluxes_kernel` | `sfincs_boundaries_gpu.cuf` — update_boundary_fluxes: k_update_boundary_fluxes | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `bnd_fluxes_copyout` | `sfincs_boundaries_gpu.cuf` — update_boundary_fluxes copy-OUT: uvmean, zsb, zsb0, zsmax? (q/uv bridge-OUT dropped) | D2H | 0.00 MB | 4,164.62 MB | 0.0 kB | 210.8 kB |
| `halo_q_uv` | `sfincs_lib.F90` — halo_exchange_q_uv (inter-rank edge q/uv halo) | halo | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `halo_zs` | `sfincs_lib.F90` — halo_exchange_zs (inter-rank cell zs halo) | halo | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `halo_zsderv` | `sfincs_lib.F90` — halo_exchange_zsderv (inter-rank zsderv halo) | halo | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `halo_z_volume` | `sfincs_lib.F90` — halo_exchange_z_volume (inter-rank z_volume halo) | halo | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `(unattributed)` | (outside annotated ranges: one-time init / output gather / snapwave) | ? | 28.35 MB | 53.14 MB | 1.4 kB | 2.7 kB |
| `bnd_conditions_copyin` | (outside annotated ranges: one-time init / output gather / snapwave) | ? | 41.09 MB | 0.00 MB | 2.1 kB | 0.0 kB |

## Totals over the window

- Steps (compute_fluxes calls): **19757**
- Attributed **H2D total 4,182.78 MB** -> **211.7 kB/step**
- Attributed **D2H total 35,087.53 MB** -> **1,776.0 kB/step**
- **Total H<->D per step: 1,987.7 kB** (211.7 kB H2D + 1,776.0 kB D2H)
- Non-PCIe context: device-to-device 16,766.26 MB, peer-to-peer 261.74 MB over the window.

## Delta vs SOR-65 Phase 1 baseline

| Metric (kB/step) | Phase 1 (pre) | Phase 2 (post) | Delta |
|---|---|---|---|
| H2D total | 1,046.8 | 211.7 | -835.1 |
| D2H total | 4,329.4 | 1,776.0 | -2,553.4 |
| **Total H<->D** | **5,376.3** | **1,987.7** | **-3,388.6** |

Phase 2 removes the per-step `q` / `q0` / `uv` / `uv0` PCIe traffic: the copy-IN ranges that bridged `q` H2D now carry **208.2 kB/step** H2D combined (the residual is `qext` / `zsmax`, which Phase 2 does not touch, plus the gated `uv` bridge-IN at `compute_fluxes` which is zero on this case), and the copy-OUT ranges that bridged `q` / `q0` / `uv` / `uv0` D2H now carry **315.9 kB/step** D2H combined (residual = `kfuv` / `timestep_analysis_required_timestep?` in `mom_fluxes_copyout`, and `uvmean` / `zsb` / `zsb0` / `zsmax?` in `bnd_fluxes_copyout`). The total per-step host<->device PCIe drops by **3,388.6 kB/step** (63.0% of the Phase-1 baseline), which matches the Phase-1 `q + uv`-attributed portion (q / q0 / uv / uv0 are real*4 over the rank-local edge count, bridged out three times per step in the Phase-1 baseline).

