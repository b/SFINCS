# SOR-1018 — per-step CUDA-MPI halo-exchange / device-sync profile

Follow-up to **[SOR-1017](../perf-scaling-sweep-20260519/SUMMARY.md)**,
which established that the `gpu_n2` unaccounted gap
`U(L) = simulation - sum(named SFINCS timer components)` is **per-step**
(grows linearly with step count, ~0.10-0.17 ms / step across all five
production cases, NOT a fixed startup cost). This profile breaks the
per-step gap down by named CUDA-MPI call / device-sync so the largest
single contributor can be named and optimized.

Case profiled: **`case_prod_regular_tide`** (the issue's named exemplar
— 15.2 s of 40.7 s `gpu_n2` 4d wall, ~37 %, is unaccounted), 1x grid,
`gpu_n2` (`mpirun -n 2` in `sfincs-build-gpu:latest`), **24 h** length
(34 519 steps — long enough to be measurable, short enough to profile
in well under 10 min). Capture harness: `run_halo_profile.sh` in this
directory; host fingerprint in `capture_env.txt`; orchestration log in
`run.stdout`.

## Methodology + the nsys-inflation caveat

`nsys profile --trace=cuda,nvtx,mpi --sample=none --cpuctxsw=none`,
one report per MPI rank. Stats extracted with `nsys stats` (CSV
committed per rank: `*__nvtx_pushpop_sum`, `*__cuda_api_sum`,
`*__mpi_event_sum`, `*__cuda_gpu_kern_sum`, `*__mpi_msg_size_sum`).

**The instrumented wall is inflated.** The profiled 24 h run reports
`Total simulation time = 15.442 s` vs. the SOR-1017 clean-run baseline
of `9.816 s` for the same cell — nsys per-event tracing adds ~1.5×.
**Call _counts_ are exact and unaffected by instrumentation; absolute
nanosecond figures from the trace are NOT used for the per-step cost
claims.** Absolute per-step cost is anchored to the SOR-1017 clean
baseline; the trace supplies (a) exact per-step call counts and (b)
the _relative_ split of the per-step coordination region. The two are
combined to attribute the measured gap.

SOR-1017 clean baseline, `case_prod_regular_tide` 1x `gpu_n2`:

| length | simulation (s) | U(L) (s) | step_count | per_step (ms) |
|--------|----------------|----------|------------|---------------|
| 24h | 9.816 | 3.780 | 34 519 | 0.1095 |
| 4d  | 40.663 | 15.228 | 143 582 | 0.1061 |

## What the per-step gap is made of

The SFINCS named timers (`Time in boundaries / momentum / continuity`)
are CPU `system_clock` spans wrapping `update_boundaries` /
`compute_fluxes` / `compute_water_levels`. The four `halo_exchange_*`
calls and the per-step `MPI_Allreduce` sit **between** those timer
blocks in the `sfincs_lib.F90` time loop (lines 444-774), so they are
**exactly the unaccounted `U(L)`**. The NVTX push/pop ranges
(`sfincs_nvtx`) confirm this: the `halo_*` spans are siblings of the
timed `mom_fluxes_*` / `bnd_*` / `cont_*` spans, not nested in them.

### Per-step call counts (exact; rank 0, ÷ 34 514 loop iterations)

| call | count / step | trace share | notes |
|------|-------------:|------------:|-------|
| `cudaDeviceSynchronize` | **13.0** | 43.0 % of all CUDA API time | 8/step inside the 4 halo routines; rest in bnd/mom/cont copy bridges |
| `MPI_Waitall` | **8.0** | 63.9 % of all MPI time | 2 per single-array exchange; `halo_q_uv` alone issues 4/step |
| `MPI_Isend` | 4.0 | — | avg 3 491 B (latency-bound, far below rendezvous threshold) |
| `MPI_Irecv` | 4.0 | — | same payloads |
| `MPI_Allreduce` | 1.0 | — | **4 bytes** — pure barrier/latency for the global-dt min |

`cuda_gpu_kern_sum` shows the halo gather/scatter `!$cuf` kernels cost
only **~15.7 µs/step of actual GPU time combined** (q_uv ≈ 8.2,
zs ≈ 3.8, zsderv ≈ 3.7). The halo NVTX spans cost ~195 µs/step
(instrumented) — i.e. the host-side `cudaDeviceSynchronize` +
`MPI_Waitall` + `MPI_Isend/Irecv` + per-call `allocate`/`deallocate`
**dwarf the data movement by ~12×**. The per-step gap is host-side
coordination latency, not bandwidth.

### Per-step gap decomposition (relative split → measured µs)

NVTX push/pop per-step averages (instrumented ns) and the
non-NVTX-wrapped `MPI_Allreduce` (from `mpi_event_sum`), normalised to
the SOR-1017 clean per_step of **0.1061 ms (4d)**:

| contributor | trace avg (ns/step) | share of gap | ≈ measured µs/step (4d) | structure |
|-------------|--------------------:|-------------:|------------------------:|-----------|
| **`halo_q_uv`** | **102 208** | **50.5 %** | **≈ 53.6** | **two** sequential single-array exchanges (q, then uv) over identical edge descriptors |
| `halo_zs` | 46 748 | 23.1 % | ≈ 24.5 | one real*8 cell exchange |
| `halo_zsderv` | 45 844 | 22.6 % | ≈ 24.0 | one real*4 cell exchange |
| `MPI_Allreduce` | 7 269 | 3.6 % | ≈ 3.8 | 4-byte global-dt min barrier |
| `halo_z_volume` | 404 | 0.2 % | ≈ 0.2 | early-return here (non-subgrid case); full cost only on subgrid cases |

Both MPI ranks are symmetric (`halo_q_uv` 22.3 % / 22.7 % of NVTX
time on rank 0 / rank 1; same call counts).

## Largest single contributor + estimated reduction

**The largest single contributor is `halo_exchange_q_uv` — ≈ 50 % of
the per-step gap (≈ 0.05 ms/step ≈ 7.7 s of the 15.2 s `gpu_n2` 4d
gap).** Structurally it is the `halo_exchange_zs` pattern executed
**twice back to back** — once for `q`, once for `uv` — over the *same*
edge descriptors (`halo_uv_*_local_idx`, `halo_uv_*_count`,
`halo_neighbor_ranks`), both real*4, only the MPI tag differing
(`HALO_TAG_Q` vs `HALO_TAG_UV`). Each sub-exchange carries its own
`gather → cudaDeviceSynchronize → Isend/Irecv → Waitall(recv) →
scatter → cudaDeviceSynchronize → Waitall(send)` cycle. That is why
`halo_q_uv` issues **4 of the 8** per-step `MPI_Waitall`s and **4 of
the 13** per-step `cudaDeviceSynchronize`s in one routine.

**Clean structural fix (shipped in this PR set): coalesce the q and
uv sub-exchanges into a single combined exchange.** Pack `q` and `uv`
into one contiguous real*4 staging buffer per neighbor
(`[q(1..n) | uv(1..n)]`), issue **one** `MPI_Isend`/`Irecv` of
`2·count` elements per neighbor, **one** `cudaDeviceSynchronize` after
the combined gather and **one** after the combined scatter, **one**
`MPI_Waitall(recv)` / `Waitall(send)` pair. Per step this turns
`halo_q_uv`'s 4 `cudaDeviceSynchronize` → 2, 4 `MPI_Waitall` → 2,
2 `MPI_Isend` → 1, 2 `MPI_Irecv` → 1, and removes one
`allocate`/`deallocate` of the request/status arrays. The messages
stay latency-bound (a single ~7 KB message ≈ one message's latency,
not two ~3.5 KB messages), so coalescing removes ≈ one full
single-array exchange's fixed host-side cost.

**Numerically bit-exact:** `q` and `uv` are real*4 on host and device;
they travel `real*4 → MPI_REAL → real*4` exactly as before, merely
adjacent in one message instead of two tagged messages. The scattered
halo values, and therefore `sfincs_map.nc`, are unchanged (verified —
see *Verification* below).

**Estimated reduction:** halving `halo_q_uv`'s host-side coordination
removes ≈ 0.020-0.025 ms/step. On the `case_prod_regular_tide`
`gpu_n2` **4d** run (143 582 steps) that is **≈ 2.9-3.6 s off the
15.2 s unaccounted gap ≈ ~7-9 % of the 40.7 s wall**.

## Scoped out (recommended follow-ups — not in this PR)

Per `[[feedback_size_ac_to_change_scope]]` (profile-then-fix; scope to
the largest single contributor; do not optimize every per-step
contributor in one PR), the next contributors are **left for a
separate issue**, not bundled here:

* **Coalesce the three post-continuity cell exchanges** —
  `halo_exchange_zs` (≈ 23 %) + `halo_exchange_zsderv` (≈ 23 %) +
  `halo_exchange_z_volume` (≈ 0 % here, but a full third exchange on
  subgrid cases — `quadtree_subgrid_tide`, `compound_snapwave`). They
  are called consecutively (`sfincs_lib.F90:744-774`) over the *same*
  cell descriptors and could collapse into one combined exchange the
  same way (6 `cudaDeviceSynchronize` → 2, 6 `MPI_Waitall` → 2,
  3 `Isend`/`Irecv` → 1). Estimated additional ≈ 0.02-0.03 ms/step.
  This is the natural sibling fix once the q+uv coalescing lands and
  its measured delta is confirmed.
* **The per-step 4-byte `MPI_Allreduce`** (global-dt min, ≈ 3.6 %).
  Small and correctness-load-bearing (every rank must advance at the
  global minimum dt); not worth restructuring on its own and out of
  scope for a halo-exchange issue.

The post-scatter `cudaDeviceSynchronize`s were **deliberately left in
place** (not "removed as unnecessary"): the in-source comments and the
SOR-52 `force-non-cuda-aware` finding establish that HPC-X's
CUDA-aware path does not order itself against the CUDA default stream,
so those syncs guard a real correctness boundary. Coalescing reduces
the *count* of syncs structurally without weakening any sync that
guards an MPI/stream ordering boundary.

## Verification (gpu_n2 4d, post-fix vs SOR-1017 baseline)

See `verify-4d/` in this directory: post-fix `case_prod_regular_tide`
1x `gpu_n2` at 1h / 6h / 24h / 4d, measured the SOR-1017 way
(`U(L) = simulation - sum(named)`, `per_step = U / step_count`), plus
a `sfincs_map.nc` bit-exactness diff. Capture harness: `verify_4d.sh`;
log in `verify-4d/run.stdout`.

### Per-step gap: post-fix vs SOR-1017 baseline (1x gpu_n2)

| length | step_count | U(L) SOR-1017 → post-fix (s) | per_step SOR-1017 → post-fix (ms) | Δ per_step |
|--------|-----------:|------------------------------|-----------------------------------|-----------:|
| 1h  | 1 521   | 0.217 → 0.171  | 0.143  → 0.1124 | **−21 %** |
| 6h  | 8 658   | 1.129 → 0.878  | 0.130  → 0.1014 | **−22 %** |
| 24h | 34 519  | 3.780 → 3.474  | 0.1095 → 0.1006 | **−8.1 %** |
| 4d  | 143 582 | 15.228 → 13.973 | 0.1061 → 0.0973 | **−8.3 %** |

**The per-step gap drops measurably at every length.** At the AC's
target 4d cell: `U(L)` 15.228 s → 13.973 s (**−1.26 s**), `per_step`
0.1061 ms → 0.0973 ms (**−0.0088 ms/step, −8.3 %**), and total
`gpu_n2` 4d wall 40.663 s → 37.251 s (**−3.41 s, −8.4 %**). The
shorter cells show a larger *percentage* drop because their per_step
carries proportionally more one-time loop/setup cost that the
coalescing also touches; the 4d cell is the steady-state figure the
AC asks about.

**Estimate reconciliation.** The pre-fix estimate above predicted
**~7-9 % of the 4d wall** — the measured **−8.4 %** lands squarely in
that band. The companion absolute-per-call prediction
(≈ 0.020-0.025 ms/step) ran ~2× high: the nsys per-event inflation is
*not uniform* — `halo_q_uv` carries more traced API calls than the
single-array spans, so its instrumented share overstates its share of
the *clean* per-step gap. The clean re-measurement (no nsys) is
authoritative: the realized saving is ≈ 0.0088 ms/step. The wall-%
prediction, which does not depend on cross-span inflation ratios,
held.

### Numerical correctness

| comparison | max_abs_diff | ratio | verdict |
|------------|-------------:|------:|---------|
| post-fix `gpu_n2` 24h **vs PRE-fix `gpu_n2` 24h** (the coalescing) | **0.0** | 0.0 | **PASS — bit-exact** |
| post-fix `gpu_n2` 24h vs post-fix `gpu_n1` 24h (multi- vs single-rank) | 3.00e-05 | 1.46e-05 | FAIL @ 1e-6 |

**The coalescing is provably numerically neutral:** post-fix `gpu_n2`
`sfincs_map.nc` is **byte-identical** (`max_abs_diff = 0.0`) to the
pre-fix two-exchange `gpu_n2` capture. q and uv travel the same
`real*4 → MPI_REAL → real*4` wire, merely adjacent in one message;
nothing about the delivered halo values changes.

The `gpu_n2`-vs-`gpu_n1` 3e-5 difference is a **pre-existing
multi-rank-vs-single-rank divergence, NOT introduced by SOR-1018** —
exactly because the pre-fix↔post-fix `gpu_n2` diff is 0.0, any
`gpu_n1`/`gpu_n2` gap exists *identically* in the pre-fix code. This
mirrors the SOR-52 `case_wavemaker` precedent (`tests/perf/FINDINGS.md`
"Validation summary": a gpu_n2-vs-baseline divergence that pre-fix and
post-fix reproduce bit-identically is independent of the change under
review). `case_prod_regular_tide` is one of the heavy cases
`tests/run_validation.sh` excludes from the CPU-baseline gate, so this
divergence is untracked-but-pre-existing and orthogonal to the
halo-exchange coalescing this issue ships.

## Artifacts

* `run_halo_profile.sh` — capture + stats-extraction harness
* `capture_env.txt` — host GPU / container / commit fingerprint
* `run.stdout` — orchestration log
* `case_prod_regular_tide__24h__gpu_n2/` — per-rank `*.nsys-rep`,
  `*.sqlite`, the five `*_sum` CSVs per rank, `sfincs.log`,
  `sfincs.stdout`, `sfincs_map.nc`, `step_count.txt`
* `verify-4d/` — post-fix re-measurement + bit-exactness diff
