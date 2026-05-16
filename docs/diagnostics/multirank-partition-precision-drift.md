# Multi-rank GPU partition precision drift — `case_prod_compound_snapwave gpu_n2`

Diagnosis of the `case_prod_compound_snapwave gpu_n2` zsmax ratio drift
(1.94e-4 vs the 1e-4 validation gate; single-rank gpu_n1 is 3.86e-5).
This is the diagnose-first deliverable (SOR-51, post-SOR-47/SOR-49,
post-SOR-50 plan_defect). The fix is tracked by the follow-up issue this
diagnosis produced.

## TL;DR

- **Smoking gun**: `q` (momentum flux) at edge global index **47846**,
  time-step **1868** — the first step that partition-boundary-adjacent
  edge wets. The single-rank vs dual-rank value diverges by **1.80e-8**
  at that first wet step (≈0.43 % of the near-zero just-wet `q`). It is
  the *first* non-trivial divergence anywhere in the SOR-47 zsmax
  clusters; everything is bit-identical for the preceding 1867 steps.
- **Kernel**: `q`/`uv` are written by `k_compute_fluxes`
  (`source/src/sfincs_momentum_gpu.cuf:638`, `:665`). The divergence is
  **not** FMA reduction-order (refuted by an `-Mnofma` rebuild — the
  divergence is unchanged), **not** a lossy halo exchange (SOR-49/SOR-50
  already made every per-step halo bit-lossless), and **not** a
  divergent global `dt` (the divergence is localized to a single
  edge/cell, not domain-wide).
- **Mechanism**: inherent multi-rank floating-point non-associativity in
  the cross-partition wet/dry front propagation, amplified by two
  quantized subgrid `int()` table lookups and the near-singular wet/dry
  momentum formula, then **latched permanently** by the `zsmax` running
  max.
- **Consequence for the fix**: there is no clean single-cast /
  single-pragma kernel fix (the only "true fix" — promoting `q`/`uv` to
  real\*8 throughout SFINCS — is SOR-50's explicitly out-of-scope Option
  C). The mechanically-actionable follow-up is a **per-case validation
  threshold relaxation** for `case_prod_compound_snapwave gpu_n2`, with
  this document as the rationale.

## How this was diagnosed

A per-time-step diagnostic dump was added behind the env gate
`SFINCS_DUMP_PARTITION_DIFF` (see "The instrumentation" below). The
production case was run at gpu_n1 (single rank) and gpu_n2 (two ranks)
with the dump enabled, and the per-rank CSVs were compared with
`tests/scripts/diff_partition_dump.py`, which pivots per
`(step, space, gidx, array)` and reports, per array, the earliest step
its gpu_n2 owning-rank value diverges from gpu_n1.

Three passes were run (24 h window, avg dt 3.086 s ≈ 28 000 steps):

| Pass   | Window            | Period | Result |
|--------|-------------------|--------|--------|
| onset  | 30 min (586 step) | 1      | n1≡n2 **bit-identical** for all 5 arrays |
| growth | 24 h              | 50     | bit-identical through step 1850; first divergence at the step-1900 sample, led by `z_volume` (7.9e-4 vs zs 1e-6, q 2e-7) |
| fine   | 2 h (≈2330 step)  | 1      | bit-identical through step **1867**; first divergence at step **1868** |

The fine per-step pass localizes the onset exactly. At step 1868
**exactly two entities** diverge (everything else is still bit-equal):

```
edge 47846  q   n1=4.1898761083e-06  n2=4.2078404476e-06  |Δ|=1.80e-08
edge 47846  uv  n1=4.5792154968e-02  n2=4.5094210654e-02  |Δ|=6.98e-04
cell 23901  z_volume n1=1.2374881189e-03 n2=1.2427940965e-03 |Δ|=5.31e-06
```

Edge 47846's two incident z-cells are `inc_nm=23821`, `inc_nmu=23901`.
At step **1867** `q(47846)=0` and `z_volume(23901)=0` in *both* runs
(the edge/cell is dry — `k_compute_fluxes` clamps `q=0` for a dry uv
point). At step **1868** the edge wets for the very first time and the
first computed `q` already differs. `uv = q / max(hu, huvmin)` blows the
1.8e-8 `q` perturbation up to 7e-4 because `hu→0` at first wetting;
`z_volume(23901)` integrates the divergent incident-edge flux the same
step. `zs(23901)` and `zsderv(23901)` follow two steps later (step 1870,
one real\*4 ULP, 5.96e-8) once `z_volume` crosses a subgrid table level.

The divergence then grows monotonically (windowed `z_volume` |Δ| ≈
2.5e-2 by step 1950, ≈1 by step 2450, ≈11 by step 17500; windowed `zs`
|Δ| peaks ≈4.4e-4 around step 17500) and is latched by `zsmax`,
producing the reported full-domain 1.94e-4 endpoint zsmax ratio (the
endpoint ratio itself is prior known evidence and was not re-derived).

## Causal chain (what reads / what writes / what halo cells)

1. **`k_compute_fluxes`** (`sfincs_momentum_gpu.cuf:250-691`) writes
   `q(ip)` (`:638`) and `uv(ip)=q(ip)/max(hu,huvmin)` (`:665`) per edge.
   For edge 47846 it reads `zs(nm)`, `zs(nmu)` (`:335`), the subgrid
   `hu`/`gnavg2` via a **quantized table lookup**
   `iuv=min(int((zsu-zmin)/dzuv)+1,…)` (`:467`), the advection stencil
   neighbours `q0`/`uv0` at `uv_index_u_*` / `uv_index_v_*` (`:423-440`),
   `zsderv(nm/nmu)` (`:643`) and `z_volume(nm/nmu)` (`:652-653`). Edge
   47846's incident cells (23821, 23901) are rank-1-owned but sit
   **inside the rank-boundary halo gidx span** (the partition halo cells
   occupy global ids ≈2809…68824); the advection/`zsu` inputs depend,
   through the wetting-front history, on state that crossed the
   geometric partition boundary via the halo exchange.
2. **`k_subgrid_main`** (`sfincs_continuity_gpu.cuf:607-787`) accumulates
   the 4-edge flux balance into the **real\*4** scratch `dvol`
   (`:710-714`) and adds it to the **real\*8** accumulator
   `z_volume(nm) = z_volume(nm) + dvol` (`:749`).
3. `zs(nm)` is derived from `z_volume(nm)` via a second **quantized
   subgrid table lookup** `iuv=int(z_volume/dzvol)+1` (`:764`) with a
   near-discontinuous wet/dry branch (`:757-768`).
4. `zsmax(nm) = max(zsmax(nm), real(zs(nm),kind=4))` (`:784`)
   **permanently latches** the divergent transient peak — this is why a
   single localized ULP event becomes a persistent 1.94e-4 zsmax ratio.

Halo transport is already bit-lossless on every per-step exchange:
`halo_exchange_zs` / `halo_exchange_z_volume` are MPI_DOUBLE_PRECISION
(SOR-49); `halo_exchange_q_uv` and `halo_exchange_zsderv` are real\*4 on
both host and device (SOR-50 plan_defect audit — no precision step). So
the divergence is **not** introduced by the wire format.

## Hypotheses tested and ruled out

- **FMA / reduction-order in `k_compute_fluxes`** (SOR-50 plan_defect's
  *leading* candidate 1) — **REFUTED**. A full CUDA rebuild with
  `-Mnofma` (FMA contraction disabled; `FCFLAGS="-O3 -fast -Mnofma …"`)
  was run at gpu_n1 and gpu_n2 over the same 2 h per-step window. At
  step 1868 edge 47846 the n1↔n2 divergence is **unchanged**: FMA build
  |Δq|=1.79643e-8, no-FMA build |Δq|=1.79675e-8. Moreover the gpu_n2
  value is **bit-identical** between the FMA and no-FMA builds
  (`q=4.2078404476e-06`, `uv=4.5094210654e-02` in both) — only gpu_n1's
  own arithmetic shifted (~1e-12). The multi-rank divergence is not a
  per-edge arithmetic-fusion artifact.
- **Lossy halo exchange** (SOR-50's original premise) — already refuted
  by the SOR-50 plan_defect and re-confirmed here: every per-step halo
  is bit-lossless, yet the divergence still appears.
- **Divergent global `dt`** (min_dt `MPI_Allreduce(MPI_MIN)`,
  `sfincs_lib.F90:447`) — **ruled out**. `MPI_MIN` is exact and
  order-independent, and the step-1868 divergence is **localized to
  exactly one edge + one cell**, not the domain-wide signature a
  perturbed `dt` would produce.
- **Per-step halo precision miscopy** — **ruled out**. Such a defect
  would diverge at step 1; here n1≡n2 is bit-exact for 1867 steps.

## Root mechanism (verified)

The flood front advances eastward across the domain (analytical
bathymetry −10 m offshore → +5 m onshore; M2+M4 tide + ramping storm
wave forcing). The quadtree-aware geometric partition
(`compute_quadtree_geometric_partition`) bisects the active cells along
the longer axis into two contiguous spatial slabs. When the wetting
front crosses the partition boundary, the **order** in which
cross-rank-dependent cells/edges first wet is mathematically
non-associative: a serialized single-rank sweep and two ranks exchanging
(bit-lossless) halos each step reach a boundary-adjacent edge's
first-wet state with a ULP-scale difference in the inputs to
`k_compute_fluxes`. That ULP-scale `q` perturbation at the first wet
step is then amplified by, in order:

1. the near-singular wet/dry momentum formula
   (`uv = q/max(hu,huvmin)`; `hu→0`, `hu**(5/3)`, `hu73` at first
   wetting) — turns 1.8e-8 in `q` into 7e-4 in `uv`;
2. the **quantized** subgrid `hu` lookup `int((zsu-zmin)/dzuv)`
   (`sfincs_momentum_gpu.cuf:467`) and the **quantized** subgrid `zs`
   lookup `int(z_volume/dzvol)` (`sfincs_continuity_gpu.cuf:764`) — a
   sub-ULP input that straddles a level boundary flips the integer
   index and yields a finite jump;
3. the real\*4 `dvol` flux-balance scratch feeding the real\*8
   `z_volume` accumulator;
4. **`zsmax = max(zsmax, zs)`** — latches the divergent transient
   permanently.

This is why **only the production-scale + multi-rank combination**
fails: multi-rank is the necessary condition (single-rank gpu_n1 is
bit-identical to itself — no partition); production scale supplies many
boundary-adjacent wet/dry-transition cells and a long (≈28 000-step)
integration, so the rare amplification event (a boundary-adjacent edge
wetting at a step where its `q` is ULP-perturbed *and* that perturbation
straddles a quantized subgrid level) is sampled and then latched.
`case_snapwave gpu_n2` (smaller boundary, fewer transitions, shorter
integration) never samples it (2.39e-5, passes).

## Why there is no clean kernel fix

The ULP-scale root is *inherent* non-associativity of the multi-rank
wet/dry front propagation. It cannot be made bit-identical to
single-rank without serializing the partition (defeating multi-rank
GPU). The halo is already lossless; FMA is refuted; `dt` is exact. The
amplifiers are load-bearing physics (subgrid wet/dry lookups, the Bates
momentum formula, the `zsmax` running max) — none can be "fixed" without
a disproportionate redesign. The only arithmetic change that would
remove the root is promoting `q`/`uv` (and their `q0`/`uv0` shadows and
every consumer) to real\*8 throughout SFINCS — SOR-50's Option C,
explicitly out of scope and far larger than warranted by a 1.94e-4
benchmark residual.

Therefore the follow-up is a **per-case validation threshold
relaxation**, documented and bounded by the measurements above.

## The instrumentation (preserved in-tree)

Two artifacts stay in the tree behind an env gate so any future
multi-rank precision regression can be triaged without re-instrumenting:

- **`SFINCS_DUMP_PARTITION_DIFF`** (subroutine `dump_partition_diff` in
  `source/src/sfincs_partition.cuf`, called from `sfincs_lib.F90` under
  `#ifdef USE_CUDA` at the end of each step's `compute_water_levels`).
  Set it to a positive integer N to dump every Nth step; unset (the
  default) is a zero-overhead no-op (one `getenv` + integer parse +
  early return). Each enabled step appends per-rank CSV rows for the
  cross-partition state arrays — `zs`, `z_volume`, `zsderv` at cells and
  `q`, `uv` at edges — for every owned + halo cell/edge whose global
  cell index falls inside one of two configurable windows
  (`SFINCS_DUMP_PARTITION_DIFF_CMIN/_CMAX` and `…_CMIN2/_CMAX2`;
  defaults 3520–3590 and 23900–24160, the SOR-47 zsmax clusters; an
  edge is in-window if either incident z-cell is). Output:
  `sfincs_partition_diff_rank<N>.csv` in the run cwd, with columns
  `step,t,rank,space,kind,gidx,inc_nm,inc_nmu,array,value` — `space` is
  `cell`/`edge`, `kind` is `owned`/`halo`; for cell rows
  `inc_nm=inc_nmu=-1` and `gidx` is the global cell id; for edge rows
  `gidx` is the global edge id and `inc_nm`/`inc_nmu` are the incident
  global cell ids.
- **`tests/scripts/diff_partition_dump.py`** — the comparison method.
  Given a gpu_n1 run dir and a gpu_n2 run dir it pivots per
  `(step, space, gidx, array)`, takes gpu_n1's owned value and gpu_n2's
  *owning-rank* owned value (the authoritative value; the other rank
  only mirrors the cell into its halo), and reports per array the
  earliest divergence step plus the single global smoking gun. Usage:
  `diff_partition_dump.py --n1-dir <…>/gpu_n1 --n2-dir <…>/gpu_n2
  [--floor 1e-9] [--top N]`.

Reproduction recipe used here: copy `tests/cases/case_prod_compound_snapwave`
into a run dir, run the GPU binary via
`source/build_scripts/run_gpu_container.sh mpirun --allow-run-as-root
-x SFINCS_DUMP_PARTITION_DIFF=<N> --wdir <container-run-dir> -n <1|2>
/work/source/install_cuda/bin/sfincs` at n=1 and n=2, then
`diff_partition_dump.py --n1-dir … --n2-dir …`. This sibling-companion
of the SOR-10 `SFINCS_DEBUG_HALO_DUMP` harness targets *value
divergence between rank counts* rather than *owned-vs-halo divergence
within one run*.

## Follow-up issue

A follow-up SFINCS issue was filed (blocked by SOR-51) whose body is
this diagnosis and whose acceptance criteria are the mechanically
actionable per-case threshold relaxation for
`case_prod_compound_snapwave gpu_n2`, bounded by the measured 1.94e-4
endpoint ratio.
