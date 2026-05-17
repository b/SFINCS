# SOR-67 Phase 3 — auxiliary per-step arrays device-canonical PCIe delta

Case: `case_prod_compound_snapwave` at `gpu_n2` (2 MPI ranks, 2 GPUs).  
Hardware: 2x NVIDIA RTX A6000.  
Container: `sfincs-build-gpu:latest` (NVHPC 25.9, HPC-X 2.24 CUDA-aware).  
Capture: `tests/perf/phase3-aux-arrays-device-canonical-20260517/run_phase3_profile.sh`; analysis: `analyze_phase3.py`.  
NSight Systems window: 46.0 s steady-state (20 s startup delay skipped) — same harness/case/config as the committed SOR-64 Phase 0 baseline and SOR-65 Phase 1 / SOR-66 Phase 2 deltas.

## Phase 3 change under test

The remaining auxiliary per-step arrays — `zsb`, `zsb0`, `uvmean`, `kfuv`, `zsm`, `maxzsm`, `zsmax`, `z_volume`, `zsderv` — are now device-canonical across the per-step loop. The Phase-3 changes:

  * `update_boundary_conditions` (`sfincs_boundaries_gpu.cuf`) replaces the bulk `zsb = zsb_h` / `zsb0 = zsb0_h` H2D pair with a sliced H2D over a precomputed kcs==2 boundary-point index list plus a small `k_scatter_kcs2_bnd` kernel — only the touched slice (the kcs==2 entries the host fan-out actually wrote) is transferred each step.
  * `update_boundary_fluxes` (`sfincs_boundaries_gpu.cuf`) drops the bulk `uvmean_h = uvmean` / `zsb_h = zsb` / `zsb0_h = zsb0` D2H copies plus the conditional `zsmax` bridge-OUT; none has a per-step host reader. `uvmean_h` is refreshed at output cadence by `device_to_host_for_output` (rank-0 plain D2H, suitable for the binary restart file). `zsmax_h` is refreshed at output cadence by the existing gather in `device_to_host_for_output`.
  * `compute_fluxes` (`sfincs_momentum_gpu.cuf`) drops the per-step `bridge_out_edge_int1(kfuv_h, kfuv)` D2H. `kfuv` has no per-step host reader in the validation matrix (`timestep_analysis_update` and `compute_nonhydrostatic` are feature-gated and not exercised).
  * `compute_water_levels_regular` / `_subgrid` (`sfincs_continuity_gpu.cuf`) drop the per-step bridge-OUTs of `zsm`, `maxzsm`, `zsmax`, `z_volume`, `zsderv`. The snapwave-gated `zsm` / `maxzsm` D2H moves to `update_wave_field` (`sfincs_snapwave_gpu.cuf`), which fires at `dtwave` cadence (1800 s in this case). `maxzsm` / `zsmax` / `z_volume` for output are refreshed at output cadence by the existing gathers in `device_to_host_for_output`. The per-step bridge-IN of `zsmax` is also dropped (the host shadow no longer tracks the device between gathers, so the H2D would clobber the accumulated running max). The dtmaxout reset cycle now uses a CUDA-aware device reset in `reset_max_arrays_device_after_output` called from `sfincs_lib.F90`'s USE_CUDA branch immediately after `write_output`, gated on the same `write_max .and. dtmaxout > 0` condition `write_output` uses for the host reset.

Phase 3 changes WHEN bytes move, not WHAT moves — every data variable in `sfincs_map.nc` is byte-identical pre/post (only `total_runtime` differs, which is wall-clock metadata).

## Post-Phase-3 per-NVTX-range H<->D byte attribution (rank 0, 20213 steps in window)

| NVTX range | Source — block | Dir | H2D total | D2H total | H2D/step | D2H/step |
|---|---|---|---|---|---|---|
| `mom_fluxes_copyin` | `sfincs_momentum_gpu.cuf` — compute_fluxes copy-IN: bridge_in_edge_real4(uv) gated on nonhydrostatic_h (no-op when feature is off) | H2D | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `mom_fluxes_kernel` | `sfincs_momentum_gpu.cuf` — compute_fluxes: q0/uv0 seed, min_dt seed, k_compute_fluxes | device | 0.08 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `mom_fluxes_copyout` | `sfincs_momentum_gpu.cuf` — compute_fluxes copy-OUT: min_dt, ts-analysis (kfuv dropped Phase 3; q/q0/uv/uv0 dropped Phase 2) | D2H | 0.00 MB | 0.08 MB | 0.0 kB | 0.0 kB |
| `mom_combined_uv_kernel` | `sfincs_momentum_gpu.cuf` — compute_combined_uv: k_combined_uv | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `mom_combined_uv_copyout` | `sfincs_momentum_gpu.cuf` — compute_combined_uv tail bridge-out: dropped (q_h / uv_h device-canonical) | D2H | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `cont_regular_copyin` | `sfincs_continuity_gpu.cuf` — compute_water_levels_regular copy-IN: qext? (zsmax bridge-IN dropped Phase 3; q dropped Phase 2) | H2D | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `cont_regular_kernel` | `sfincs_continuity_gpu.cuf` — compute_water_levels_regular: discharge + k_regular_main | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `cont_regular_copyout` | `sfincs_continuity_gpu.cuf` — compute_water_levels_regular copy-OUT: empty (zsm/maxzsm moved to dtwave snapwave step; zsmax dropped Phase 3) | D2H | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `cont_subgrid_copyin` | `sfincs_continuity_gpu.cuf` — compute_water_levels_subgrid copy-IN: qext? (zsmax bridge-IN dropped Phase 3; q dropped Phase 2) | H2D | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `cont_subgrid_kernel` | `sfincs_continuity_gpu.cuf` — compute_water_levels_subgrid: discharge + k_subgrid_main | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `cont_subgrid_copyout` | `sfincs_continuity_gpu.cuf` — compute_water_levels_subgrid copy-OUT: zs0?, storage? (z_volume / zsderv / zsm / maxzsm / zsmax dropped Phase 3) | D2H | 0.00 MB | 4,208.18 MB | 0.0 kB | 208.2 kB |
| `bnd_conditions` | `sfincs_boundaries_gpu.cuf` — update_boundary_conditions: host MPI_Bcast + kcs==2 fan | host/MPI | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `bnd_conditions_copyin` | `sfincs_boundaries_gpu.cuf` — update_boundary_conditions: sliced H2D of kcs==2 zsb/zsb0 entries + k_scatter_kcs2_bnd (Phase 3) | H2D | 42.04 MB | 0.00 MB | 2.1 kB | 0.0 kB |
| `bnd_neumann_zs` | `sfincs_boundaries_gpu.cuf` — update_boundary_conditions: k_update_neumann_zs (device-only) | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `bnd_river_zsb` | `sfincs_boundaries_gpu.cuf` — update_boundary_conditions: k_update_river_zsb (device-only) | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `bnd_apply_zs` | `sfincs_boundaries_gpu.cuf` — update_boundary_conditions: k_apply_boundary_zs (device-only) | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `bnd_fluxes_kernel` | `sfincs_boundaries_gpu.cuf` — update_boundary_fluxes: k_update_boundary_fluxes | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `bnd_fluxes_copyout` | `sfincs_boundaries_gpu.cuf` — update_boundary_fluxes copy-OUT: empty (uvmean / zsb / zsb0 / zsmax all dropped Phase 3) | D2H | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `halo_q_uv` | `sfincs_lib.F90` — halo_exchange_q_uv (inter-rank edge q/uv halo) | halo | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `halo_zs` | `sfincs_lib.F90` — halo_exchange_zs (inter-rank cell zs halo) | halo | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `halo_zsderv` | `sfincs_lib.F90` — halo_exchange_zsderv (inter-rank zsderv halo) | halo | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `halo_z_volume` | `sfincs_lib.F90` — halo_exchange_z_volume (inter-rank z_volume halo) | halo | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `(unattributed)` | (outside annotated ranges: one-time init / output gather / snapwave) | ? | 30.04 MB | 72.71 MB | 1.5 kB | 3.6 kB |

## Totals over the window

- Steps (compute_fluxes calls): **20213**
- Attributed **H2D total 72.16 MB** -> **3.6 kB/step**
- Attributed **D2H total 4,280.98 MB** -> **211.8 kB/step**
- **Total H<->D per step: 215.4 kB** (3.6 kB H2D + 211.8 kB D2H)
- Non-PCIe context: device-to-device 17,153.24 MB, peer-to-peer 267.78 MB over the window.

## Delta vs SOR-66 Phase 2 baseline

| Metric (kB/step) | Phase 2 (pre) | Phase 3 (post) | Delta |
|---|---|---|---|
| H2D total | 211.7 | 3.6 | -208.1 |
| D2H total | 1,776.0 | 211.8 | -1,564.2 |
| **Total H<->D** | **1,987.7** | **215.4** | **-1,772.3** |

Phase 3 removes the per-step auxiliary-array PCIe traffic. The copy-IN ranges that bridged auxiliaries H2D now carry **2.1 kB/step** H2D combined (the residual is `bnd_conditions_copyin`'s sliced kcs==2 H2D scatter — the touched slice mandated by the AC for the per-step CPU writer — plus `qext` in `cont_*_copyin` when BMI is on, which is not exercised here). The copy-OUT ranges that bridged auxiliaries D2H now carry **208.2 kB/step** D2H combined (`mom_fluxes_copyout` retains only `min_dt` and the optional `timestep_analysis_required_timestep`; `bnd_fluxes_copyout` is empty; `cont_*_copyout` retains only `zs0` / `storage` under their feature gates). The total per-step host<->device PCIe drops by **1,772.3 kB/step** (89.2% of the Phase-2 baseline).

The inner-loop steady-state PCIe is now dominated by the snapwave coupling (paid every `dtwave = 1800 s` in this case, i.e. ~1 in every ~30 steps at this case's `dt`) and the output gather (paid every `dtmapout = 86400 s`, i.e. exactly once over this 24-h simulation — outside the steady-state NSight window). The per-step path is approximately at its post-Phase-3 envelope: the only remaining per-step transfers are the sliced boundary H2D (kcs==2-sized), the small `mom_fluxes_copyout` (the `min_dt` int32 scalar), and the feature-gated tail in `cont_*_copyout`.

