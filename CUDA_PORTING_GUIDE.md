# CUDA porting guide

Notes for SFINCS contributors maintaining the CUDA Fortran port under
`source/src/sfincs_*_gpu.cuf` plus the GPU-only orchestration in
`source/src/sfincs_partition.cuf`. Builds (CPU and CUDA) are documented in
`CLAUDE.md`. This file collects the GPU-only invariants that must be
preserved across changes; the kernels work because of them and break
silently when they are violated.

## Multi-rank halo machinery

The CUDA build supports `mpirun -n N` partitioning of the quadtree mesh.
`partition_and_localize()` runs once per simulation startup. After Phase 4
copies catalog arrays to the device in local-indexed form, Phase 5 (the
`build_halo_descriptors` routine in `source/src/sfincs_partition.cuf`)
constructs the per-neighbor edge and cell send/recv lists consumed at
runtime by `halo_exchange_zs`, `halo_exchange_q_uv`, and
`halo_exchange_zsderv`.

### Invariant 1 — per-element symmetry of edge send/recv lists

`halo_exchange_q_uv` is **purely positional**:

```
halo_send_buf_q(i, ridx) = q( halo_uv_send_local_idx(i, ridx) )
...
q( halo_uv_recv_local_idx(i, ridx) ) = halo_recv_buf_q(i, ridx)
```

For the exchange to deliver the right neighbor's value to the right local
edge, rank N's send slot `i` to neighbor M and rank M's recv slot `i` from
N **must refer to the same global iuv** (the global edge index `1..npuv_h`).
If they do not, the value M ships out of its send slot `i` lands on N at
the wrong local edge, corrupting `q` (and `uv` via the second exchange).

The cross-refinement transition path would violate this invariant under a
naive walk: a coarse-fine quadtree boundary has the coarse-owning rank
visiting one cell while the fine-owning rank visits two — so the slot
order of the two child edges across the refinement transition would be
symmetric ONLY when the fine cells happen to be globally numbered with
the lower-half cell before the upper-half cell. Quadtree refinement does
not guarantee that invariant, so the descriptor walk MUST be canonical
across ranks.

The in-tree walk in `build_halo_descriptors` therefore enumerates edges
in **canonical global-iuv ascending order** (`do iuv = 1, npuv_h`) on
both passes (count + fill), driven by `uv_index_z_nm` / `uv_index_z_nmu`
directly. Both ranks iterate the same iuv sequence and produce identical
per-slot orderings of the same iuv set. Cells touched by those edges are
discovered in the same canonical order so the cell halo descriptor
becomes symmetric for free. The same walk shape is used in
`build_local_index_maps` so its `is_halo_cell` / `is_halo_edge` sets
stay consistent with the descriptor.

**Do not regress the canonical iuv walk in `build_halo_descriptors`**.
Reintroducing an owned-cell × edge-slot walk (the pre-SOR-35 shape)
re-creates the cross-refinement asymmetry and corrupts halo q / uv at
every refinement transition that straddles the partition.

### Diagnostic guard — `SFINCS_DEBUG_HALO_DESC_CHECK`

`verify_halo_descriptor_symmetry()` is the runtime regression guard for
Invariant 1. It is called from `partition_and_localize` after
`build_halo_descriptors`, and it short-circuits when
`SFINCS_DEBUG_HALO_DESC_CHECK` is unset or zero (one `getenv` per
invocation, cost ≈ free in production runs).

When enabled (`SFINCS_DEBUG_HALO_DESC_CHECK=1`):

1. Each rank exchanges its per-neighbor send count against the peer's,
   aborting with `HALO_DIAG ABORT count mismatch` on the first mismatch.
2. Each rank pulls `halo_uv_send_local_idx` back to a host shadow and
   converts to global iuvs via `local_to_global_uv`.
3. Each rank ships its send-side global-iuv list to the matching
   neighbor and compares the received list against its own
   `halo_uv_recv_remote_idx` (which carries the global iuv expected
   at every recv slot).
4. The first per-slot mismatch emits

       HALO_DIAG ABORT slot mismatch: rank=<R> neighbor=<N> slot=<K> global_iuv_expected=<E> global_iuv_got=<G> nbr_slot=<NS>

   followed by `MPI_Abort` with exit code 9002.

Use this when modifying the halo discovery walk. It is a permanent
regression guard, not a debugging one-shot.

### Invariant 2 — cross-rank authority for `k_combined_uv`

Quadtree refinement transitions produce **combined-UV slots** in the
`q` / `uv` arrays at positions
`[npuv_h + 1 .. npuv_h + ncuv_h]` (host-side; on the device shadow these
sit at the cuv tail `[npuv_local + halo_edge_count + 1 .. + ncuv_h]`).
Each slot `icuv` represents the average of two **child edges**
`cuv_index_uv1(icuv)` and `cuv_index_uv2(icuv)` that face the coarse
cell on the coarse side of the refinement transition.

When the partition split lies between the two fine cells on the fine
side of such a transition, `cuv_index_uv1` and `cuv_index_uv2` have
**different edge owners** — the two fine cells live on different ranks
— and no single rank has both children in its OWNED slice.

The authority strategy is **strategy (c)** per SOR-35's body: every rank
runs `k_combined_uv` against its own halo-extended view of `q` and `uv`.
With Invariant 1 in place, `halo_exchange_q_uv` delivers IDENTICAL
values for the same global iuv on every rank, so each rank reads
consistent `q` / `uv` at every child edge — owned or halo — and
produces the same averaged value at every combined-UV slot. **No
broadcast or Allreduce is required.**

Strategies (a) (rank 0 broadcasts) and (b) (per-slot ownership rule)
were rejected: strategy (c) is the cheapest correct option because the
only per-step communication is the `halo_exchange_q_uv` that the rest
of the solver already needs. (a) and (b) would add a second MPI
round-trip after every `compute_fluxes` call.

Strategy (c) only works if the kernel runs AFTER `halo_exchange_q_uv`.
The pre-fix kernel ran inside `compute_fluxes` BEFORE
`halo_exchange_q_uv`, so the halo `q` it averaged was one step stale.
The fix moves the kernel out of `compute_fluxes` into a new public
subroutine `compute_combined_uv` invoked from `sfincs_lib.F90` AFTER
`halo_exchange_q_uv`.

`compute_combined_uv` refreshes the host alias for the combined-UV
TAIL of `q` / `uv` only via `bridge_out_edge_tail_real4`. A full
`bridge_out_edge_real4` would also rewrite the owned slice and risk
clobbering edits to host `q_h` / `uv_h` made by
`compute_fluxes_over_structures` or `compute_nonhydrostatic` between
`compute_fluxes` and the halo exchange.

For `mpi_size == 1` the kernel runs over every slot as in the single-
rank baseline, `halo_exchange_q_uv` is a no-op (`halo_uv_n_neighbors
== 0`), and `compute_combined_uv` reduces to the pre-fix in-line
kernel call. The single-rank code path is bit-identical to the
pre-fix code.

**Do not move `k_combined_uv` back into `compute_fluxes` without
preserving the post-halo-exchange invariant.** Any future change that
relocates the call must keep it AFTER the last write to `q` / `uv` (by
structures or non-hydrostatic) and AFTER the halo exchange so every
rank sees the same view of child edges.

## File reference

| File | Role |
|---|---|
| `source/src/sfincs_partition.cuf` | Partition + halo descriptors + halo exchange bodies + diagnostic helpers. `build_halo_descriptors`, `verify_halo_descriptor_symmetry`, `bridge_out_edge_tail_real4` are here. |
| `source/src/sfincs_data_device.cuf` | Device-side catalog: `q`, `uv`, `halo_uv_*_local_idx`, `halo_uv_*_remote_idx`. |
| `source/src/sfincs_momentum_gpu.cuf` | `compute_fluxes` (without the combined-UV call), `k_compute_fluxes`, `k_combined_uv`, `compute_combined_uv` (the post-halo-exchange wrapper). |
| `source/src/sfincs_lib.F90` | Call sites for `halo_exchange_q_uv` / `halo_exchange_zs` / `halo_exchange_zsderv` / `compute_combined_uv` inside the time loop (`#ifdef USE_CUDA`). |

## Other debug env-vars

* `SFINCS_DEBUG_HALO_DESC_CHECK=1` — run the descriptor-symmetry check
  at partition time (Invariant 1 above).
* `SFINCS_DEBUG_HALO_DUMP=N` — every Nth step, dump per-rank CSV rows
  of cell-rank arrays inside the case_production storm-surge hot-spot
  (Invariant for the older `zsderv` halo-exchange regression — see
  the block comment above `dump_halo_diagnostic` in
  `sfincs_partition.cuf` for the override boxes).
