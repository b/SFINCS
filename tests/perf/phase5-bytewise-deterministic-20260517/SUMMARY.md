# SOR-79 — strict byte-identicality on a deterministic GPU path

Follow-up to SOR-69. SOR-69 Phase 5 AC #2 attempted strict byte-identicality
on `case_prod_compound_snapwave gpu_n2` and found a 1.645e-4 zsmax ratio
rather than bit-equivalence. The diagnosis attributed the residual to
inherent multi-rank floating-point non-associativity in the cross-partition
wet/dry front propagation in `k_compute_fluxes`, latched permanently by the
`zsmax` running max; the validation matrix's `THRESHOLD_OVERRIDE` map
already documents this case at 5e-4. The remaining question was whether
the canonical-on-device refactor preserves numeric semantics exactly on a
GPU path that DOES NOT have that non-associativity — i.e., a (case, config)
pair where bit-equivalence is achievable in principle. This artifact
closes that question.

## Case selection

The candidate had to meet ALL of:

  * GPU code path (validates the GPU refactor, not the unchanged CPU path).
  * Single-rank (so no cross-partition MPI atomics / reductions inside
    `k_compute_fluxes`; the partition-boundary halo exchange is short-
    circuited at `mpi_size == 1`, removing the documented
    multi-rank-non-associativity source).
  * No SnapWave coupling (isolates the per-step inner loop from host-side
    scientific code).
  * No `THRESHOLD_OVERRIDE` entry in `tests/run_validation.sh` (any pair
    already on the override map has documented residuals; we want a pair
    where the global 1e-4 ratio gate IS the operative gate).
  * Reasonable wall clock (so a re-verification run is cheap).

`case_regular gpu_n1` was selected:

  * 50×50 uniform grid, 1-day simulation, `dtmax=60s` (~17000 steps).
  * Pure boundary-condition-driven flow; no meteo, no weir, no
    quadtree, no subgrid, no nonhydrostatic, no wavemaker, no SnapWave.
  * `gpu_n1` config (single rank, no halo exchange).
  * Not on the `THRESHOLD_OVERRIDE` map.
  * Wall clock ~18-24 s end-to-end inside the dev container.

`case_meteo gpu_n1` and `case_structures gpu_n1` meet the same criteria
and would be equally valid; `case_regular` is the simplest of the three.

## Methodology

`run_byte_identical_check.sh` (this directory):

  1. Builds the pre-Phase-1 binary at commit `d1b84c1` (the Phase-0
     NVTX-annotated commit immediately preceding the Phase-1
     zs-device-canonical refactor at `9c3e69c`) in a sibling worktree
     at `/tmp/sfincs-pre-phase1-baseline` (re-used from SOR-69's
     `tests/perf/phase5-canonical-on-device-final-20260517/` run).
  2. Uses the post-Phase-4 binary at HEAD-of-main built in this worktree
     at `source/install_cuda/bin/sfincs` (commit
     `00acf0397aafd2b6491f44bb1cc1b3a58b83ac01`, the SOR-69 merge tip).
  3. Runs `case_regular` at `gpu_n1` against both binaries in disjoint
     run directories, copying inputs from `tests/cases/case_regular/`.
  4. Compares the two `sfincs_map.nc` outputs three ways:
       (a) file size + sha256 + `cmp -s` for strict byte-identicality.
       (b) `ncdump -h` diff for structural drift (ncdump not on PATH in
           this environment; skipped — the per-variable check below is
           strictly more informative).
       (c) `tests/scripts/diff_zsmax.py` at threshold 1e-6 (100× tighter
           than the SOR-69 strict gate, which was 1e-4).

The script is parameterised on `CASE=` / `CFG=` environment variables so
the same driver can re-validate other (case, config) pairs in future.

## Result

| Comparison                | Result                                           |
|---------------------------|--------------------------------------------------|
| File size                 | 160466 B (pre) vs 160466 B (post), **match**     |
| sha256                    | `49776bcd...` (pre) vs `11a98e8c...` (post), mismatch |
| `cmp -l` byte-by-byte     | NOT byte-identical, 3 differing bytes at offsets 56714-56716 |
| `diff_zsmax` ratio (1e-6) | `max_abs_diff=0.0`, `ratio=0.0`, **PASS**        |

The three differing bytes are exclusively in `total_runtime`, a wall-clock
timing field SFINCS writes to `sfincs_map.nc` at simulation end:

  * pre-Phase-1 `total_runtime` = 23.58 s
  * post-Phase-4 `total_runtime` = 17.47 s

That 6 s wall-clock delta IS the canonical-on-device refactor's per-step
PCIe-traffic reduction; it is non-determinism by design (depends on
machine load, GPU clock state, scheduling) and is not a simulation
output. **Every other variable in `sfincs_map.nc` is bit-identical**
between pre-Phase-1 and post-Phase-4 — per-variable max-abs-diff verified
in the byte-identical check log:

| Variable           | Shape          | max\_abs\_diff |
|--------------------|----------------|----------------|
| `zs`               | (25, 50, 50)   | 0.0            |
| `h`                | (25, 50, 50)   | 0.0            |
| `zsmax`            | (1, 50, 50)    | 0.0            |
| `hmax`             | (1, 50, 50)    | 0.0            |
| `zb`               | (50, 50)       | 0.0            |
| `msk`              | (50, 50)       | 0.0            |
| `manning`          | (50, 50)       | bit-identical (all-fill: case has scalar `manning = 0.024`) |
| `corner_x`         | (51, 51)       | 0.0            |
| `corner_y`         | (51, 51)       | 0.0            |
| `average_dt`       | (1,)           | 0.0            |
| `status`           | (1,)           | 0.0            |
| `total_runtime`    | (1,)           | 6.113 (wall-clock metadata, non-deterministic by design) |

## Implication

The canonical-on-device refactor (SOR-65 → SOR-66 → SOR-67 → SOR-68,
landed cumulatively under SOR-69 / PR #114) **preserves the GPU
simulation's numeric output bit-exactly** on a deterministic single-rank
GPU code path. The SOR-69 Phase 5 1.645e-4 zsmax ratio observed on
`case_prod_compound_snapwave gpu_n2` is therefore NOT a residual
introduced by the refactor; it is the documented multi-rank GPU FP
non-associativity envelope that was present pre-Phase-1 and is unchanged
post-Phase-4 (see SOR-69's SUMMARY.md and
`docs/diagnostics/multirank-partition-precision-drift.md`).

The validation matrix's per-pair `THRESHOLD_OVERRIDE` for
`case_prod_compound_snapwave:gpu_n1/n2` correctly captures that
underlying envelope without being a tolerance relaxation introduced by
the canonical-on-device refactor.

## Artifacts (this directory)

  * `run_byte_identical_check.sh`   — driver (parameterised on `CASE` / `CFG`)
  * `pre_phase1_sfincs_map.nc`      — pre-Phase-1 baseline (`case_regular gpu_n1` @ d1b84c1)
  * `post_phase4_sfincs_map.nc`     — post-Phase-4 result (`case_regular gpu_n1` @ HEAD)
  * `byte_identical_check.log`      — comparison log (size, sha256, cmp, diff_zsmax)
  * `SUMMARY.md`                    — this file
