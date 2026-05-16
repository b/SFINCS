# SOR-64 Phase 0 — canonical-on-device PCIe baseline

Case: `case_prod_compound_snapwave` at `gpu_n2` (2 MPI ranks, 2 GPUs).  
Hardware: 2x NVIDIA RTX A6000.  
Container: `sfincs-build-gpu:latest` (NVHPC 25.9, HPC-X 2.24 CUDA-aware).  
Capture: `tests/perf/phase0-baseline-20260516/run_phase0_profile.sh`; analysis: `analyze_phase0.py`.  
NSight Systems window: 59.3 s steady-state (target 60 s; 20 s startup delay skipped).  
Profiled rank: rank 0 (`phase0_rank0.nsys-rep`). The 2-rank domain decomposition is symmetric, so rank 0's per-step bridge_in_*/bridge_out_* H<->D inventory is representative of both ranks; rank 1 ran bare so the `halo_*` ranges still see real inter-rank traffic.

## Phase 0 is pure measurement

No behaviour change. The four per-step GPU routines (`compute_fluxes`, `compute_water_levels_regular/_subgrid`, `update_boundary_fluxes`) and the four `sfincs_lib.F90` halo helpers are wrapped in named NVTX push/pop ranges via the `sfincs_nvtx` helper (NVHPC `nvtx` shim, linked through `-lnvhpcwrapnvtx`). On CPU the ranges are a strict no-op (`.cuf`-only module; the `sfincs_lib.F90` calls are `#ifdef USE_CUDA`).

> AC naming note: AC #1 names the boundary routine `update_boundary_conditions`, but the copy-IN (lines ~335-337) / kernel / copy-OUT (lines ~358-363) the issue Notes cite by line number live in `update_boundary_fluxes` (`update_boundary_conditions` is the host MPI_Bcast feeder, no H<->D block). Both routines are annotated: `bnd_fluxes_*` carries the per-step H<->D traffic; `bnd_conditions` carries the host/MPI feeder so the profile separates them cleanly.

## Per-NVTX-range H<->D byte attribution (rank 0, 14227 steps in window)

| NVTX range | Source (HEAD) — block | Dir | H2D total | D2H total | H2D/step | D2H/step |
|---|---|---|---|---|---|---|
| `mom_fluxes_copyin` | `sfincs_momentum_gpu.cuf:~134-136` — compute_fluxes copy-IN: bridge_in_cell_real8(zs), bridge_in_edge_real4(uv) | H2D | 11,864.46 MB | 0.00 MB | 833.9 kB | 0.0 kB |
| `mom_fluxes_kernel` | `sfincs_momentum_gpu.cuf:~140-170` — compute_fluxes: q0/uv0 seed, min_dt seed, k_compute_fluxes | device | 0.06 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `mom_fluxes_copyout` | `sfincs_momentum_gpu.cuf:~179-191` — compute_fluxes copy-OUT: bridge_out q/q0/uv/uv0/kfuv, min_dt, ts-analysis | D2H | 0.00 MB | 25,464.65 MB | 0.0 kB | 1,789.9 kB |
| `mom_combined_uv_kernel` | `sfincs_momentum_gpu.cuf:~228-231` — compute_combined_uv: k_combined_uv | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `mom_combined_uv_copyout` | `sfincs_momentum_gpu.cuf:~243-245` — compute_combined_uv tail bridge-out: q, uv (tail-only) | D2H | 0.00 MB | 108.47 MB | 0.0 kB | 7.6 kB |
| `cont_regular_copyin` | `sfincs_continuity_gpu.cuf:~161-167` — compute_water_levels_regular copy-IN: zs, q, qext?, zsmax? | H2D | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `cont_regular_kernel` | `sfincs_continuity_gpu.cuf:~170-185` — compute_water_levels_regular: discharge + k_regular_main | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `cont_regular_copyout` | `sfincs_continuity_gpu.cuf:~188-220` — compute_water_levels_regular copy-OUT: zs, zsm?, zsmax? | D2H | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `cont_subgrid_copyin` | `sfincs_continuity_gpu.cuf:~310-316` — compute_water_levels_subgrid copy-IN: zs, q, qext?, zsmax? | H2D | 14,826.41 MB | 0.00 MB | 1,042.1 kB | 0.0 kB |
| `cont_subgrid_kernel` | `sfincs_continuity_gpu.cuf:~318-336` — compute_water_levels_subgrid: discharge + k_subgrid_main | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `cont_subgrid_copyout` | `sfincs_continuity_gpu.cuf:~339-377` — compute_water_levels_subgrid copy-OUT: zs, z_volume, zs0?, zsderv?, storage?, zsm?, zsmax? | D2H | 0.00 MB | 26,657.53 MB | 0.0 kB | 1,873.7 kB |
| `bnd_conditions` | `sfincs_boundaries_gpu.cuf:~131-233` — update_boundary_conditions: host MPI_Bcast + zsb/zsb0/zs fan (AC-named routine; no H<->D) | host/MPI | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `bnd_fluxes_copyin` | `sfincs_boundaries_gpu.cuf:~335-338` — update_boundary_fluxes copy-IN: bridge_in zs, zsb=zsb_h, zsb0=zsb0_h | H2D | 5,953.91 MB | 0.00 MB | 418.5 kB | 0.0 kB |
| `bnd_fluxes_kernel` | `sfincs_boundaries_gpu.cuf:~342-350` — update_boundary_fluxes: k_update_boundary_fluxes | device | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `bnd_fluxes_copyout` | `sfincs_boundaries_gpu.cuf:~358-385` — update_boundary_fluxes copy-OUT: zs, q, uv, uvmean, zsb, zsb0, zsmax? | D2H | 0.00 MB | 20,914.02 MB | 0.0 kB | 1,470.0 kB |
| `halo_q_uv` | `sfincs_lib.F90:~681` — halo_exchange_q_uv (inter-rank edge q/uv halo) | halo | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `halo_zs` | `sfincs_lib.F90:~702` — halo_exchange_zs (inter-rank cell zs halo) | halo | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `halo_zsderv` | `sfincs_lib.F90:~712` — halo_exchange_zsderv (inter-rank zsderv halo) | halo | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `halo_z_volume` | `sfincs_lib.F90:~727` — halo_exchange_z_volume (inter-rank z_volume halo) | halo | 0.00 MB | 0.00 MB | 0.0 kB | 0.0 kB |
| `(unattributed)` | (outside annotated ranges: one-time init / output gather / snapwave) | ? | 21.06 MB | 39.91 MB | 1.5 kB | 2.8 kB |

## Totals over the window

- Steps (compute_fluxes calls): **14227**
- Attributed **H2D total 32,665.90 MB** -> **2,296.0 kB/step**
- Attributed **D2H total 73,184.58 MB** -> **5,144.1 kB/step**
- **Total H<->D per step: 7,440.1 kB** (2,296.0 kB H2D + 5,144.1 kB D2H)
- Sustained from nsys attributed bytes / 59.3s: H2D **551 MB/s**, D2H **1,235 MB/s**
- Non-PCIe context (not host<->device): device-to-device 11,989.72 MB, peer-to-peer 104.83 MB over the window.

## Sustained PCIe + GPU occupancy (nvidia-smi dmon)

| GPU | sm% min-max | PCIe Rx MB/s min-max | PCIe Tx MB/s min-max |
|---|---|---|---|
| 0 | 0-20 | 0-1065 | 0-2427 |
| 1 | 0-18 | 0-1039 | 0-2382 |

Rank-0 sfincs %CPU (in-container top): min 0, max 101, mean 99.

## Bandwidth-arithmetic closure vs SOR-52 / PR #100

SOR-52 (`tests/perf/FINDINGS.md`) measured, per GPU on this exact case/config, a PCIe **Tx 2160-2477 MB/s** + **Rx 966-1085 MB/s** envelope via nvidia-smi dmon. nsys attributes the per-step memcpy bytes to source blocks; nvidia-smi PCIe counters are the independent ground truth.

Direction mapping: GPU PCIe **Tx** = device->host = our **D2H**; GPU PCIe **Rx** = host->device = our **H2D**.

- nsys D2H 1,235 MB/s vs nvidia-smi Tx: SOR-52 2160-2477, this run 0-2427 MB/s.
- nsys H2D 551 MB/s vs nvidia-smi Rx: SOR-52 966-1085, this run 0-1065 MB/s.

The nvidia-smi PCIe counters also include the SnapWave `dtwave` exchange, meteo updates, the periodic output gather, and any MPI host-staging — none of which are inside the four annotated per-step routines. The gap between the nsys per-step attributed rate and the sustained nvidia-smi counter is exactly that unannotated residual, and quantifying it per source block is what Phases 1-5 are measured against.

