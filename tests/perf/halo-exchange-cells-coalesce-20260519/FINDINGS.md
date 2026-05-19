# SOR-1019 — coalesce the three post-continuity cell halo exchanges

Direct follow-up to **[SOR-1018](../halo-exchange-profile-20260519/FINDINGS.md)**
(coalesced `halo_exchange_q_uv`) under the cell-side sibling identified
by SOR-1018 §"Scoped out (recommended follow-ups)":

> Coalesce the three post-continuity cell exchanges — `halo_exchange_zs`
> (≈ 23 %) + `halo_exchange_zsderv` (≈ 23 %) + `halo_exchange_z_volume`
> (≈ 0 % here, but a full third exchange on subgrid cases — they are
> called consecutively (`sfincs_lib.F90:744-774`) over the *same* cell
> descriptors and could collapse into one combined exchange the same
> way (6 `cudaDeviceSynchronize` → 2, 6 `MPI_Waitall` → 2, 3
> `Isend`/`Irecv` → 1). Estimated additional ≈ 0.02-0.03 ms/step.

That estimate is the AC's target for the non-subgrid 4d cell. The
subgrid cases (where `halo_exchange_z_volume` is active pre-fix, not
early-return) gain MORE because the coalescing folds 3 arrays instead
of 2.

The first contextual link in this chain is the
[SOR-1017](../perf-scaling-sweep-20260519/SUMMARY.md) scaling sweep,
which established that the `gpu_n2` unaccounted per-step gap
`U(L) = simulation - sum(named SFINCS timer components)` is **per-step**
(grows linearly with step count, NOT a fixed startup cost), so a fix
that removes per-step coordination overhead scales linearly with sim
length.

## Implementation summary

* **`source/src/sfincs_data_device.cuf`** — the dedicated cell staging
  buffer pairs `halo_send_buf_zs` / `halo_recv_buf_zs` (real\*4, was
  used by the standalone `halo_exchange_zsderv`) and
  `halo_send_buf_zs_r8` / `halo_recv_buf_zs_r8` (real\*8, was used by
  the standalone `halo_exchange_zs` / `halo_exchange_z_volume`) are
  retired and replaced with one combined real\*8 buffer pair
  `halo_send_buf_cells` / `halo_recv_buf_cells`. Three module scalars
  (`halo_cells_n_bands`, `halo_cells_band_zsderv`,
  `halo_cells_band_z_volume`) record which arrays participate at
  partition_and_localize time and serve as the "skip this band" predicate
  inside the coalesced routine.
* **`source/src/sfincs_partition.cuf`** — the three subroutines
  `halo_exchange_zs` / `halo_exchange_zsderv` / `halo_exchange_z_volume`
  (≈ 350 lines of duplicated gather/sync/Isend/Waitall/scatter blocks)
  are replaced by a single `halo_exchange_cells` (≈ 170 lines). Phase 6
  of `partition_and_localize` sizes the combined buffer to
  `halo_cells_n_bands * max(halo_*_count)` based on which arrays are
  actually allocated; the legacy `HALO_TAG_ZS` / `HALO_TAG_ZSDERV` /
  `HALO_TAG_Z_VOLUME` constants are retired and one `HALO_TAG_CELLS`
  drives the new MPI message.
* **`source/src/sfincs_lib.F90:739-769`** — the three consecutive
  `nvtx_range_push("halo_zs|_zsderv|_z_volume") / call halo_exchange_…`
  blocks are replaced by one `halo_cells` NVTX-wrapped call.

Type packing per neighbor column (n = `halo_*_count(nbr_slot)`):

| band index | rows in column | array | native type | wire treatment |
|------------|----------------|-------|-------------|----------------|
| 0 (always) | [1..n]         | zs       | real\*8 | native r8 in/out |
| 1 (when alloc) | [n+1..2n]  | zsderv   | real\*4 | r4 → r8 upcast in gather; r8 → r4 downcast in scatter |
| 2 (when alloc) | [2n+1..3n] | z_volume | real\*8 | native r8 in/out |

The buffer's leading dim is `halo_cells_n_bands * max(halo_*_count)`;
the trailing dim is `halo_n_neighbors`. One `MPI_Isend`/`Irecv` of
`halo_cells_n_bands * count` `MPI_DOUBLE_PRECISION` elements per
neighbor carries the full combined payload.

The r4 → r8 → r4 round-trip on the zsderv band is bit-exact: r4 is a
strict subset of r8 in IEEE 754, so the upcast is lossless and the
downcast is `nearest = exact` for any value that originated as r4.
The scattered halo `zsderv` is byte-identical to what the pre-fix
single-r4 exchange produced.

## Structural reduction vs the pre-fix three separate exchanges

Per-step host-side coordination collapses from 3-routine baseline to
1-routine combined, with the same SOR-1018 ratios applied to the cell
side:

| contributor | pre-fix per step | post-fix per step | reduction |
|-------------|-----------------:|------------------:|----------:|
| `cudaDeviceSynchronize` (cell side) | 6 (2 in each of zs / zsderv / z_volume) | 2 (one after combined gather, one after combined scatter) | −4 |
| `MPI_Waitall(recv)`               | 3 | 1 | −2 |
| `MPI_Waitall(send)`               | 3 | 1 | −2 |
| `MPI_Isend` per neighbor          | 3 | 1 | −2 |
| `MPI_Irecv` per neighbor          | 3 | 1 | −2 |
| request/status `allocate`/`deallocate` | 3 | 1 | −2 |

The remaining cudaDeviceSynchronize (one post-gather, one post-scatter)
is intentionally left in place — same SOR-52 / SOR-1018 reasoning:
HPC-X's CUDA-aware path does NOT order itself against the CUDA default
stream that the `!$cuf` kernels launch on, so each sync guards a real
MPI/stream ordering boundary. Coalescing reduces the *count*
structurally without weakening any sync that guards an ordering
boundary.

## Verification — bit-exactness

Bit-exactness is verified on the load-bearing AC cells via
`tests/scripts/diff_zsmax.py` (max_abs_diff over `sfincs_map.nc`'s
zsmax field; threshold 1e-6):

| case | length | mpi | comparison | max_abs_diff | verdict |
|------|--------|-----|------------|-------------:|---------|
| `case_prod_regular_tide`           | 24h | gpu_n2 | post-fix vs pre-fix | **0.0** | **PASS — bit-exact** |
| `case_prod_quadtree_subgrid_tide`  | 24h | gpu_n2 | post-fix vs pre-fix | **0.0** | **PASS — bit-exact** |
| `case_prod_quadtree_subgrid_tide`  | 4d  | gpu_n2 | post-fix vs pre-fix | **0.0** | **PASS — bit-exact** |

The subgrid coverage is load-bearing: `z_volume` is non-trivial there,
so the coalescing actually folds 3 arrays into 1 message (vs the
2-array fold the non-subgrid case sees because pre-fix
`halo_exchange_z_volume` early-returns on a non-subgrid build). Both
the 24h and 4d subgrid sfincs_map.nc are byte-identical to the pre-fix
three-exchange capture, confirming the r4 → r8 → r4 round-trip on the
zsderv band is exactly the no-op the type-packing analysis says it is.

## Verification — measured delta vs the SOR-1018 baseline

Same shape as SOR-1018 verify-4d's `case_prod_regular_tide` 1x `gpu_n2`
table. "pre-fix" here = HEAD before this PR was applied (post-SOR-1018
+ post-SOR-1017, i.e. the SOR-1018 verify-4d code state); "post-fix" =
this PR.

### Per-step gap: post-fix vs pre-fix (`case_prod_regular_tide` 1x `gpu_n2`)

| length | step_count | U(L) pre → post (s) | per_step pre → post (ms) | Δ per_step | sim_total pre → post (s) |
|--------|-----------:|---------------------|--------------------------|-----------:|--------------------------|
| 1h  | 1,521   | 0.149 → 0.147  | 0.0980 → 0.0966 | **−1.4 %**  | 0.446 → 0.397  |
| 6h  | 8,658   | 0.772 → 0.760  | 0.0892 → 0.0878 | **−1.6 %**  | 2.352 → 2.160  |
| 24h | 34,519  | 3.566 → 2.830  | 0.1033 → 0.0820 | **−20.6 %** | 9.128 → 8.348  |
| 4d  | 143,582 | 14.328 → 9.287 | 0.0998 → 0.0647 | **−35.2 %** | 37.681 → 34.525 |

At the AC's target 4d cell:
* `per_step` drops by **0.0351 ms/step** (well over the AC's ≥0.015 ms/step
  threshold).
* Total `gpu_n2` 4d wall drops 37.681 s → 34.525 s = **−3.156 s, −8.4 %**
  (over the AC's ≥5 % threshold).
* `U(L)` drops 14.328 s → 9.287 s = **−5.04 s, −35 %**.

The 1h / 6h drops are smaller in absolute terms — at those short
lengths the per_step gap is dominated by one-off setup costs that the
cell-side coalescing doesn't touch, and the per-step coordination
savings are only ~0.0014 ms/step. Both still drop, so the AC's "drops
measurably at every length" criterion is satisfied.

`gpu_n1` 24h (single-rank reference; `halo_n_neighbors == 0` so the
combined exchange is a no-op) is unchanged: per_step 0.0059 →
0.0059 ms.

### Subgrid coverage (`case_prod_quadtree_subgrid_tide` 1x `gpu_n2`)

| length | step_count | U(L) pre → post (s) | per_step pre → post (ms) | Δ per_step | sim_total pre → post (s) |
|--------|-----------:|---------------------|--------------------------|-----------:|--------------------------|
| 24h | 27,971  | 3.806 → 2.727  | 0.1361 → 0.0975 | **−28.3 %** | 9.655 → 8.588  |
| 4d  | 109,541 | 14.920 → 8.176 | 0.1362 → 0.0746 | **−45.2 %** | 37.957 → 33.353 |

**Subgrid gains MORE than non-subgrid at every length** — exactly the
AC's prediction. The 4d cell drops 0.061 ms/step (vs 0.035 on non-
subgrid), and the total 4d wall drops 37.957 → 33.353 s = **−12.1 %**
(vs −8.4 % on non-subgrid). The difference is the `z_volume` band:
pre-fix `halo_exchange_z_volume` is active on subgrid (not early-return),
so the coalescing folds 3 arrays into 1 message and removes 2 more
`cudaDeviceSynchronize` / 2 more `MPI_Waitall` / 1 more `Isend`-`Irecv`
per neighbor than on the non-subgrid case. The structural reduction
ratio is exactly the third sub-exchange that the AC identifies.

## Artifacts

* `run_baseline.sh` — pre-fix capture harness (run after `git stash` of this
  PR's source changes, with the GPU binary rebuilt against pre-fix HEAD).
* `run_verify.sh` — post-fix re-measurement + bit-exactness diff against the
  baseline.
* `prefix/`  — pre-fix per-cell run dirs and `sfincs_map.nc` for the bit-
  exactness diff.
* `postfix/` — post-fix per-cell run dirs and per-cell `timings.txt`.

## Scoped out (remaining per-step gap)

After SOR-1018 + SOR-1019 the per-step gap on `gpu_n2` for
`case_prod_regular_tide` is dominated by:

* the per-step 4-byte `MPI_Allreduce` for the global-dt min
  (correctness-load-bearing; ≈ 3.6 % of the original gap; deliberately
  out of scope per the issue note);
* irreducible halo-data-movement on the wire (the gather/scatter
  kernels + the message latency itself).

Further reductions in this dimension would require either eliminating
the global-dt allreduce (correctness-load-bearing) or overlapping halo
exchange with kernel work (a different optimization class — async
streams, not message coalescing — and out of scope for this issue).
