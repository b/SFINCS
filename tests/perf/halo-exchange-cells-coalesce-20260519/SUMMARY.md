# SOR-1019 — coalesced post-continuity cell halo exchange

One-line: the three sequential post-continuity cell-halo exchanges
(`halo_exchange_zs` + `halo_exchange_zsderv` + `halo_exchange_z_volume`,
all over identical cell descriptors) are collapsed into one combined
`halo_exchange_cells` exchange, mirroring the
**[SOR-1018](../halo-exchange-profile-20260519/FINDINGS.md)** pattern
that did the same for `halo_exchange_q_uv`. Per-step host-side
coordination on the cell side drops from 6 `cudaDeviceSynchronize` /
6 `MPI_Waitall` / 3 `Isend`-`Irecv` per neighbor to 2 / 2 / 1
respectively.

The originating per-step gap measurement that motivated the cell-side
coalescing comes from **[SOR-1017](../perf-scaling-sweep-20260519/SUMMARY.md)**'s
scaling sweep (which established the unaccounted gap `U(L)` is
per-step, NOT a fixed startup cost) and **SOR-1018**'s NVTX/MPI
profile (which split the per-step gap by named call and identified
the three cell exchanges as the second-largest contributor after
`halo_q_uv`).

See `FINDINGS.md` for the implementation summary, type-packing layout,
bit-exactness verification, measured deltas, and remaining-gap
analysis.

## Artifacts

| file | purpose |
|------|---------|
| `FINDINGS.md`  | implementation + bit-exactness + measured-delta detail |
| `run_baseline.sh` | pre-fix (HEAD-stashed) capture harness |
| `run_verify.sh`   | post-fix measurement + `sfincs_map.nc` bit-exact diff |
| `prefix/`         | pre-fix run dirs (sfincs.log, sfincs_map.nc, timings.txt per cell) |
| `postfix/`        | post-fix run dirs (same shape) |

Measurement cells (same shape as SOR-1018 verify-4d):

* `case_prod_regular_tide`           1x `gpu_n2` at 1h / 6h / 24h / 4d
  (non-subgrid coverage; `halo_exchange_z_volume` is early-return
  pre-fix here so the coalescing folds 2 arrays).
* `case_prod_regular_tide`           1x `gpu_n1`  at 24h
  (single-rank reference: `halo_n_neighbors == 0` so
  `halo_exchange_cells` is a no-op).
* `case_prod_quadtree_subgrid_tide`  1x `gpu_n2` at 24h and 4d
  (subgrid coverage; `halo_exchange_z_volume` is active pre-fix here
  so the coalescing folds 3 arrays — the load-bearing case the AC
  identifies as gaining more).
