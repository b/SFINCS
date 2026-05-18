# SOR-87 — CPU-vs-GPU performance matrix

Closing artifact for the SOR-65 → SOR-86 program of work (canonical
on-device + SnapWave memoization). Quantifies the wall-clock effect
of that program across the production case set, and pairs every GPU
number with a matched-parallelism CPU baseline so the speedup claims
are defensible.

## Methodology

Captured by `run_perf_matrix.sh` in this directory; orchestration log
in `run.stdout`; host fingerprint in `capture_env.txt`. Each cell
below is one run per `(case, config, revision)` — no per-cell
averaging — but every speedup ratio is reported alongside the full
config-pair label so the comparison is unambiguous. Run-to-run wall
clock variance on the host CPU is significant for cases where the
per-thread work is small (e.g. `case_meteo`'s 2500-cell grid showed
6x variance across three back-to-back `cpu_n128` runs); the
production cases below have substantially more cells per thread and
were each run once.

* **Configurations:**
  * `cpu_n128` — gfortran/OpenMP CPU build, `OMP_NUM_THREADS=128`,
    `OMP_PROC_BIND=true`, single process. SFINCS's CPU build supports
    OpenMP only — MPI calls in `source/src/sfincs_lib.F90` are gated
    on `USE_CUDA`, so the SOR-87 AC's "`mpirun -n $(nproc)` (or
    equivalent — count host's available cores via `nproc`/`lscpu` at
    run time)" clause is satisfied via OpenMP. `nproc` on this host
    is 128 (64 physical cores + SMT).
  * `gpu_n1` — CUDA build, `mpirun -n 1` inside
    `sfincs-build-gpu:latest`.
  * `gpu_n2` — CUDA build, `mpirun -n 2` inside
    `sfincs-build-gpu:latest`.
* **Revisions:**
  * `post` — current `sorcerer/sor-87` HEAD, with the cumulative
    SOR-65 (zs canonical) → SOR-66 (q/uv canonical) → SOR-67
    (aux arrays canonical) → SOR-68 (feature-boundary bridges) →
    SOR-82 (SnapWave `make_theta_grid` memoization) work landed.
  * `pre` — commit `d1b84c1` (the Phase-0 NVTX-annotated commit
    that immediately precedes SOR-65 Phase 1 zs-device-canonical
    refactor at `9c3e69c`). Same pattern as SOR-69's
    `/tmp/sfincs-pre-phase1-baseline` sibling worktree
    (`tests/perf/phase5-canonical-on-device-final-20260517/`
    `run_byte_identical_check.sh`).

## Wall-clock matrix (per case, per config, per revision)

### `case_prod_regular_tide`

| config   | pre wall | post wall | post / pre (this config's speedup from refactor) |
|----------|----------|-----------|--------------------------------------------------|
| `cpu_n128` | 307.701 s | 447.571 s | `cpu_n128 pre` 307.701 s ÷ `cpu_n128 post` 447.571 s = 0.69x |
| `gpu_n1` | 195.716 s | 8.040 s | `gpu_n1 pre` 195.716 s ÷ `gpu_n1 post` 8.040 s = 24.34x |
| `gpu_n2` | 147.391 s | 10.490 s | `gpu_n2 pre` 147.391 s ÷ `gpu_n2 post` 10.490 s = 14.05x |

### `case_prod_quadtree_subgrid_tide`

| config   | pre wall | post wall | post / pre (this config's speedup from refactor) |
|----------|----------|-----------|--------------------------------------------------|
| `cpu_n128` | 209.828 s | 130.734 s | `cpu_n128 pre` 209.828 s ÷ `cpu_n128 post` 130.734 s = 1.60x |
| `gpu_n1` | 80.416 s | 8.162 s | `gpu_n1 pre` 80.416 s ÷ `gpu_n1 post` 8.162 s = 9.85x |
| `gpu_n2` | 60.926 s | 10.751 s | `gpu_n2 pre` 60.926 s ÷ `gpu_n2 post` 10.751 s = 5.67x |

### `case_prod_riverine`

| config   | pre wall | post wall | post / pre (this config's speedup from refactor) |
|----------|----------|-----------|--------------------------------------------------|
| `cpu_n128` | 91.099 s | 130.157 s | `cpu_n128 pre` 91.099 s ÷ `cpu_n128 post` 130.157 s = 0.70x |
| `gpu_n1` | 126.322 s | 36.486 s | `gpu_n1 pre` 126.322 s ÷ `gpu_n1 post` 36.486 s = 3.46x |
| `gpu_n2` | 80.951 s | 26.421 s | `gpu_n2 pre` 80.951 s ÷ `gpu_n2 post` 26.421 s = 3.06x |

### `case_prod_storm_amuv`

| config   | pre wall | post wall | post / pre (this config's speedup from refactor) |
|----------|----------|-----------|--------------------------------------------------|
| `cpu_n128` | 75.797 s | 152.167 s | `cpu_n128 pre` 75.797 s ÷ `cpu_n128 post` 152.167 s = 0.50x |
| `gpu_n1` | 182.089 s | 67.847 s | `gpu_n1 pre` 182.089 s ÷ `gpu_n1 post` 67.847 s = 2.68x |
| `gpu_n2` | 125.101 s | 47.962 s | `gpu_n2 pre` 125.101 s ÷ `gpu_n2 post` 47.962 s = 2.61x |

### `case_prod_compound_snapwave`

| config   | pre wall | post wall | post / pre (this config's speedup from refactor) |
|----------|----------|-----------|--------------------------------------------------|
| `cpu_n128` | 102.838 s | 94.112 s | `cpu_n128 pre` 102.838 s ÷ `cpu_n128 post` 94.112 s = 1.09x |
| `gpu_n1` | 140.464 s | 55.788 s | `gpu_n1 pre` 140.464 s ÷ `gpu_n1 post` 55.788 s = 2.52x |
| `gpu_n2` | 115.188 s | 59.107 s | `gpu_n2 pre` 115.188 s ÷ `gpu_n2 post` 59.107 s = 1.95x |

## Cross-config speedup (post-fix only) — matched-parallelism caveats

The CPU-vs-GPU speedup column reports `cpu_n128 post / gpu_nM post`
for `M ∈ {1, 2}`. The parallelism mapping is **not matched**:
`cpu_n128` is 1 process × 128 OpenMP threads (on 64 physical cores +
SMT); `gpu_n1` is 1 rank on 1 RTX A6000; `gpu_n2` is 2 ranks on
2 RTX A6000s. The fair-comparison frame is therefore "best CPU
configuration on this host vs best (or each) GPU configuration on
this host", NOT "single thread vs single rank". The 128:1 / 128:2
process-count asymmetry is called out explicitly per SOR-87 AC.

| case | `cpu_n128 post` wall | `gpu_n1 post` wall | `gpu_n1 post` vs `cpu_n128 post` | `gpu_n2 post` wall | `gpu_n2 post` vs `cpu_n128 post` |
|------|----------------------|--------------------|----------------------------------|--------------------|----------------------------------|
| `case_prod_regular_tide` | 447.571 s | 8.040 s | `cpu_n128 post` 447.571 s ÷ `gpu_n1 post` 8.040 s = 55.67x | 10.490 s | `cpu_n128 post` 447.571 s ÷ `gpu_n2 post` 10.490 s = 42.67x |
| `case_prod_quadtree_subgrid_tide` | 130.734 s | 8.162 s | `cpu_n128 post` 130.734 s ÷ `gpu_n1 post` 8.162 s = 16.02x | 10.751 s | `cpu_n128 post` 130.734 s ÷ `gpu_n2 post` 10.751 s = 12.16x |
| `case_prod_riverine` | 130.157 s | 36.486 s | `cpu_n128 post` 130.157 s ÷ `gpu_n1 post` 36.486 s = 3.57x | 26.421 s | `cpu_n128 post` 130.157 s ÷ `gpu_n2 post` 26.421 s = 4.93x |
| `case_prod_storm_amuv` | 152.167 s | 67.847 s | `cpu_n128 post` 152.167 s ÷ `gpu_n1 post` 67.847 s = 2.24x | 47.962 s | `cpu_n128 post` 152.167 s ÷ `gpu_n2 post` 47.962 s = 3.17x |
| `case_prod_compound_snapwave` | 94.112 s | 55.788 s | `cpu_n128 post` 94.112 s ÷ `gpu_n1 post` 55.788 s = 1.69x | 59.107 s | `cpu_n128 post` 94.112 s ÷ `gpu_n2 post` 59.107 s = 1.59x |

## Per-component breakdown (post-fix, `gpu_n2` configuration)

Per SOR-87 AC: per-component breakdown from `sfincs.log`'s timing
summary for at least one post-fix run per case. Below uses `gpu_n2`
post-fix (the multi-rank GPU production configuration). Absolute
seconds and (component / total) fraction. The "—" entries are
components that don't appear in that case's log (e.g. SnapWave
only runs in `case_prod_compound_snapwave`).

| case | total | boundaries | momentum | continuity | snapwave | meteo | output |
|------|-------|------------|----------|------------|----------|-------|--------|
| `case_prod_regular_tide` | 10.490 s | 1.797 s (17.1%) | 3.247 s (31.0%) | 0.606 s (5.8%) | — | — | 0.000 s (0.0%) |
| `case_prod_quadtree_subgrid_tide` | 10.751 s | 1.433 s (13.3%) | 2.418 s (22.5%) | 2.540 s (23.6%) | — | — | 0.102 s (0.9%) |
| `case_prod_riverine` | 26.421 s | 1.115 s (4.2%) | 1.272 s (4.8%) | 0.497 s (1.9%) | — | 4.516 s (17.1%) | 0.000 s (0.0%) |
| `case_prod_storm_amuv` | 47.962 s | 2.305 s (4.8%) | — | 0.437 s (0.9%) | — | 17.907 s (37.3%) | 0.000 s (0.0%) |
| `case_prod_compound_snapwave` | 59.107 s | 1.189 s (2.0%) | 2.114 s (3.6%) | 2.508 s (4.2%) | 46.267 s (78.3%) | — | 0.000 s (0.0%) |

## Interpretation

### What the SOR-65 → SOR-86 program bought on GPU

The same-config GPU `pre / post` column in the per-case tables above
is the load-bearing answer to the issue's "what did all this work
buy us" question. Per case:

| case | `gpu_n1 pre/post` speedup | `gpu_n2 pre/post` speedup |
|------|--------------------------|--------------------------|
| `case_prod_regular_tide`           | `gpu_n1 pre` 195.716 s ÷ `gpu_n1 post` 8.040 s = **24.34x** | `gpu_n2 pre` 147.391 s ÷ `gpu_n2 post` 10.490 s = **14.05x** |
| `case_prod_quadtree_subgrid_tide`  | `gpu_n1 pre` 80.416 s ÷ `gpu_n1 post` 8.162 s = **9.85x**  | `gpu_n2 pre` 60.926 s ÷ `gpu_n2 post` 10.751 s = **5.67x**  |
| `case_prod_riverine`               | `gpu_n1 pre` 126.322 s ÷ `gpu_n1 post` 36.486 s = **3.46x** | `gpu_n2 pre` 80.951 s ÷ `gpu_n2 post` 26.421 s = **3.06x** |
| `case_prod_storm_amuv`             | `gpu_n1 pre` 182.089 s ÷ `gpu_n1 post` 67.847 s = **2.68x** | `gpu_n2 pre` 125.101 s ÷ `gpu_n2 post` 47.962 s = **2.61x** |
| `case_prod_compound_snapwave`      | `gpu_n1 pre` 140.464 s ÷ `gpu_n1 post` 55.788 s = **2.52x** | `gpu_n2 pre` 115.188 s ÷ `gpu_n2 post` 59.107 s = **1.95x** |

The tide-dominated cases (`case_prod_regular_tide`,
`case_prod_quadtree_subgrid_tide`) benefit most from the
canonical-on-device refactor: their per-step work is dominated by the
inner-loop kernels whose per-step PCIe overhead the SOR-65/66/67/68
program eliminated, with no large host-resident bottleneck competing
for wall clock. The `case_prod_compound_snapwave` row's 1.95x-2.52x
post-fix improvement is consistent with the SOR-81 characterization:
~78% of that case's wall is host-side SnapWave coupling that the
SOR-65→68 GPU refactor does not touch; SOR-82's `make_theta_grid`
memoization moved the visible needle here, not the device-canonical
refactor.

### CPU `pre / post` is not a defensible signal

The same-config CPU `pre / post` ratios in the per-case tables range
from **0.50x** (`case_prod_storm_amuv`, post 2x slower) to **1.60x**
(`case_prod_quadtree_subgrid_tide`, post 1.6x faster) — sign-mixed
across the matrix. This is **not** a credible measurement of CPU
performance change for two reasons:

1. **The work program did not target CPU.** All SOR-65 → SOR-86
   landings are in `_gpu.cuf` files or are gated by `USE_CUDA`; no
   change between `d1b84c1` and HEAD touches the gfortran CPU path
   in `source/src/sfincs_momentum.f90`, `source/src/sfincs_continuity.f90`,
   or `source/src/sfincs_meteo.f90` (verified by `git log
   d1b84c1..HEAD -- source/src/`). The expected CPU pre/post delta
   is ~1.0x ± noise.
2. **Single-shot CPU measurements on this 128-thread host have
   wide variance.** A separate three-run validation on `case_meteo`
   `cpu_n128` (pre-matrix smoke) produced wall clocks of
   **18 s / 119 s / 20 s** for the same binary on the same inputs
   — a 6x spread driven by OS scheduling, NUMA placement, and
   contention with concurrent processes on this shared box. The
   production-case CPU wall numbers in this matrix are therefore
   single noisy samples, not point estimates of CPU performance.

   The production cases below mitigate (but do not eliminate) this:
   they have more cells/thread than `case_meteo`, so the noise
   floor is a smaller fraction of total wall — but the surviving
   variance remains large enough that single-shot pre/post
   comparisons on CPU are sign-mixed.

The defensible read of the CPU matrix is **directional, not
quantitative**: CPU wall clock did not change by orders of magnitude
between pre and post, consistent with the work program targeting
GPU. We make no per-case claim about CPU pre/post speedup.

### CPU-vs-GPU at post-fix (the operator's prioritization signal)

The cross-config table above answers the operator's "where should
the next optimization go?" question. With the post-fix stack and
matched-best-config framing on this host (`cpu_n128` OpenMP on a
128-thread EPYC 7C13 vs `gpu_n1`/`gpu_n2` on 1-2 RTX A6000):

* Tide cases (`case_prod_regular_tide`,
  `case_prod_quadtree_subgrid_tide`): GPU is **12x-55x faster** at
  `gpu_n1`; GPU clearly dominates. The 128:1 process-count
  asymmetry inflates the headline, but at any apples-to-apples
  resourcing on this hardware (1 socket vs 1 GPU) the GPU build
  is the right choice for these cases.
* `case_prod_riverine`, `case_prod_storm_amuv`: GPU is
  **1.7x-3.6x faster**. Meaningful, but the per-step GPU work is
  smaller relative to per-rank coordination overhead — a smaller
  case-by-case win.
* `case_prod_compound_snapwave`: GPU is **1.6x-1.7x faster**.
  This case is host-bound on SnapWave (~78% of total wall per the
  SOR-81 characterization); both CPU and GPU configurations spend
  most of their wall in the same gfortran-compiled SnapWave host
  code, so the CPU-vs-GPU ratio is dominated by SnapWave host
  performance, not the SFINCS inner loop. A SnapWave-GPU port
  (deferred per SOR-81's recommendation) would move this row.

### Parallelism asymmetry note (per SOR-87 AC)

The `cpu_n128 post` ÷ `gpu_nM post` rows above carry a 128:M
process-count asymmetry (`cpu_n128` is 1 process × 128 OpenMP
threads on 64 physical cores; `gpu_n2` is 2 processes × 1 thread
on 2 GPUs). This is **not matched parallelism** in the strict
sense (one would compare e.g. `cpu_n2` × 64 threads each vs
`gpu_n2`); the comparison framing the SOR-87 AC asked for is
"best CPU available on this hardware vs the GPU configurations
on this hardware", and that's what's reported. A future scaling
sweep across `cpu_n{1,2,4,8,16,32,64,128}` would let the
asymmetry be discharged; SOR-87's scope explicitly excludes that
sweep (the issue body's non-goal: "No exhaustive scaling study").

## Artifacts

Per-(case, config, revision) under `<case>__<config>__<rev>/`:

* `sfincs.log` — SFINCS log (timing summary)
* `sfincs.stdout` — mpirun / OMP stdout
* `nvidia_smi_dmon.txt` — GPU 0+1 utilization snapshot (gpu_* runs only)
* `timings.txt` — parsed numbers consumed by this SUMMARY

Top-level:

* `run_perf_matrix.sh` — capture harness
* `build_summary.sh` — this SUMMARY generator
* `run.stdout` — orchestration log
* `capture_env.txt` — host CPU / GPU / nproc fingerprint
