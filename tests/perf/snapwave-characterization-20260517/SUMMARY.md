# SOR-81 — SnapWave characterization at `case_prod_compound_snapwave gpu_n2`

This page captures the SnapWave host-side hot path on the
`case_prod_compound_snapwave` case at the `gpu_n2` config (2 MPI ranks,
2× RTX A6000, CUDA-aware HPC-X 2.24), so the choice between the four
downstream paths can be made on evidence:

- (a) full SnapWave-GPU port — multi-month
- (b) partial port of the top-N hottest SnapWave routines
- (c) overlap-scheduling — CPU SnapWave concurrent with per-step GPU
  work
- (d) skip SnapWave-GPU entirely

The recommendation is at the bottom.

## Capture environment

Recorded verbatim in `capture_env.txt`; copy here for the reader:

- host: `simulacra`, Ubuntu 24.04.4 LTS, kernel 6.8.0-111-generic
- CPU: AMD EPYC 7C13 64-Core (128 logical), 504 GiB RAM
- GPU: 2× NVIDIA RTX A6000 (Ampere, 48 GiB each)
- container: `sfincs-build-gpu:latest` (id `3b572d24caec`, 14.3 GiB) —
  NVHPC SDK 25.9, CUDA 13.0, HPC-X 2.24, gfortran-noop (CUDA build is
  nvfortran)
- binary: `source/install_cuda/bin/sfincs` built on branch
  `sorcerer/sor-81` from commit `00acf03` plus the NVTX
  `snapwave_update` annotation added by this issue
- case: `tests/cases/case_prod_compound_snapwave` (`tstop = 86400 s`,
  `dtwave = 1800 s`)
- baseline wall clock for this binary + case at `gpu_n2`, without nsys /
  perf instrumentation (per SOR-69 Phase 5 sfincs.log at
  `tests/perf/phase5-canonical-on-device-final-20260517/sfincs.log`):
  `Total simulation time` 63.6 s, `Time in SnapWave` 50.0 s (78.6 %)

The numbers below are from this issue's instrumented runs, where the
nsys CPU sampling adds ~16 % wall-clock overhead and the perf
`--call-graph dwarf` recording adds a similar amount; absolute seconds
should be read as "with profiler attached", and only the fractional
breakdowns are directly comparable to baseline.

## NSight Systems profile + top-level NVTX

Driver: `run_snapwave_profile.sh` (this directory), same shape as the
SOR-69 Phase 5 harness in
`tests/perf/phase5-canonical-on-device-final-20260517/run_phase5_profile.sh`,
extended with `--sample=cpu`, `--cpuctxsw=process-tree`, and `--backtrace=dwarf`
so the SnapWave call stack is sampled in addition to the NVTX timeline.

Artifacts: `snapwave_rank0.nsys-rep` (raw report),
`nvtx_pushpop_sum.csv` (NVTX range table), `cuda_gpu_kern_sum.csv` (GPU
kernel summary), `osrt_sum.csv` (OS-runtime), `sfincs.log` (per-call
SnapWave timing).

Top entries in `nvtx_pushpop_sum.csv` (excerpt; "Time (%)" is of total
profiled wall clock on rank 0):

| Time (%) | Total (ns)   | Instances | Avg (ns)      | Range                 |
|---------:|-------------:|----------:|--------------:|-----------------------|
| 67.9     | 52 304 200 655 | 49      | 1 067 432 666 | `:snapwave_update`    |
| 5.2      |  4 015 027 958 | 27 995  |   143 419     | `:halo_q_uv`          |
| 5.1      |  3 914 895 187 | 27 995  |   139 842     | `:mom_fluxes_kernel`  |
| 4.1      |  3 184 917 039 | 27 995  |   113 767     | `:bnd_conditions`     |
| 2.6      |  1 973 139 662 | 27 995  |    70 481     | `:halo_zs`            |

The new `snapwave_update` range — wrapped around `update_wave_field` in
`source/src/sfincs_lib.F90:617` and visible as a sibling to the
`mom_fluxes_*` / `cont_subgrid_*` / `bnd_*` ranges from SOR-52/65/69 —
is **the single biggest span on rank 0**, with 49 instances of ~1.07 s
each (one per `dtwave = 1800 s` SnapWave-update cycle across the 24 h
simulation). All other per-step kernels combined come in at <25 % of
profiled wall clock.

## perf record on rank 0

Driver: same `run_snapwave_profile.sh`. Captures `perf record -F 999
--call-graph dwarf,16384` for the full simulation on the rank-0 SFINCS
process, mounting host `perf` into the container via apt-installed
`linux-tools-generic`. Artifacts in this directory:
`snapwave_perf_report.txt` (children-mode sorted by overhead),
`snapwave_perf_flat.txt` (self-time flat list),
`snapwave_perf_callgraph.txt` (per-symbol callee tree).

The raw `snapwave_perf.data` is ~1.0 GiB on this case and is NOT
committed; re-run `run_snapwave_profile.sh` from this directory to
regenerate it on the same machine. The three text reports above carry
every actionable signal the .data file carries for this
characterization.

## Top 5 SnapWave routines by inclusive wall-clock time

Percentages are read from the perf children-mode report (which
anchors at total rank-0 CPU cycles), then **normalized to the
`sfincs_snapwave_compute_snapwave_` parent** (which itself measures 28.66
% of total rank-0 cycles — the rest of rank-0 is MPI wait, GPU launch
wait, and the per-step CPU shim around the GPU kernels). The
`% of SnapWave` column is therefore the share of the SnapWave wall clock
(~50 s) the routine represents.

| # | Routine                                      | File:line                                       | Self % of SnapWave | Inclusive % of SnapWave | What it computes |
|--:|----------------------------------------------|-------------------------------------------------|--------------------:|------------------------:|------------------|
| 1 | `solve_energy_balance2Dstat`                 | `source/src/snapwave/snapwave_solver.f90:148`   | 66 %               | 66 %                    | Four-sweep upwind iterative directional-energy-balance solver on the unstructured wave grid; per-cell tridiagonal solve in θ, Baldock breaking, IG source-sink, optional wind input. The work-horse. |
| 2 | `update_boundary_conditions`                 | `source/src/snapwave/snapwave_boundaries.f90:471` | <1 %              | 28 %                    | Per-`dtwave`-step wrapper: pulls Hs/Tp/dir time series, rebuilds the θ grid around the mean wave/wind direction, regenerates spectra, calls `update_boundaries`. |
| 3 | `make_theta_grid` (both call sites combined) | `source/src/snapwave/snapwave_boundaries.f90:778` | 6 %              | 22 %                    | Reslices `w`, `prev`, `ds`, `windspreadfac` tables for the current mean direction by indexing into the pre-computed 360-direction `w360` / `prev360` / `ds360` arrays; an O(`ntheta * no_nodes`) gather across very wide indirection arrays. |
| 4 | `solve_tridiag`                              | `source/src/snapwave/snapwave_solver.f90:956`   | 7 %                | 11 %                    | Thomas-algorithm tridiagonal solve of an `ntheta`-by-`ntheta` system, called from inside `solve_energy_balance2Dstat`'s innermost cell loop on each iteration / sweep / wave kind (incident and IG). |
| 5 | `compute_herbers` (via `determine_ig_bc`)    | `source/src/snapwave/snapwave_infragravity.f90:117` | <1 %           | 7 %                     | Herbers (1995) bound-IG transformation at the wave boundary — Fourier-domain frequency-by-frequency bispectral transfer of incident-band variance to IG-band variance, with `interp.linear_interp_2d_real4` for grid lookups. |

`hpsort_eps_epw` (6 %) and `determine_infragravity_source_sink_term` (5
%) are sub-leading; full table in `snapwave_perf_flat.txt`.

### GPU-port suitability assessment, routine by routine

**1. `solve_energy_balance2Dstat` — 66 % of SnapWave; HARD.** This
is an upwind directed sweep over `no_nodes` (~102 880 cells in this
case) repeated for 4 sweep directions per iteration up to `niter`
iterations. Inside each cell, an O(`ntheta`) tridiagonal solve runs on
the directional wave-energy axis. The cross-cell data dependency is the
killer: `eeprev(itheta) = w(1, itheta, k)*ee(itheta, k1) + w(2, itheta,
k)*ee(itheta, k2)` reads `ee(:,k1)` and `ee(:,k2)` which are the
already-updated upwind cells in the SAME sweep. This is a marching
algorithm; the cells in one sweep are NOT independent. A GPU port
requires either (i) red-black / multi-coloured-graph scheduling, (ii)
level-set / wavefront scheduling along the sweep order, (iii) a
Jacobi-style reformulation that drops the upwind acceleration (more
iterations to converge), or (iv) a domain-decomposition variant.
`solve_tridiag` (top-5 #4) is naturally per-cell, so it can live inside
whatever parallelization scheme the outer loop chooses. **No ready-made
CUDA library covers this workload** — `cuSolver`'s `gtsv`/`gtsvBatched`
only handles the inner tridiagonal solve, not the marching sweep.
Per-call data size at this case (no_nodes = 102 880, ntheta typically
36, `ee` is real*4) is ~14 MiB for `ee` plus similar for `w`/`prev`/`ds`
tables — small enough that H↔D transfer is sub-millisecond per call,
but the *algorithm* is the bottleneck, not the data motion.

**2. `update_boundary_conditions` — 28 % of SnapWave; MOSTLY a host
control wrapper.** Its inclusive 28 % is almost entirely
`update_boundary_points` (boundary spectra rebuild) + `make_theta_grid`
(the θ-rotation work in row 3) + Herbers IG bc (row 5). The wrapper
itself is small; per-call cost dominates because *it runs on every
`dtwave` step* even though most of its inputs (mean wave direction,
boundary time series) change slowly. **Suitability**: low for direct
GPU port — the time-series interpolation + scalar averaging is small,
serial, and not data-parallel. High suitability for *amortization*: a
caching layer that recomputes the θ grid only when the mean direction
moves by ≥ ε would cut row 3's ~10–15 % directly.

**3. `make_theta_grid` (combined call sites) — 22 % of SnapWave;
MEDIUM.** The inner double loop (`do itheta`; `do k = 1, no_nodes`)
gathers from `w360`, `prev360`, `ds360`, `windspread360` into `w`,
`prev`, `ds`, `windspreadfac` via the integer index `i360(itheta)`.
This is a classic GPU-friendly gather: `O(ntheta * no_nodes)` ≈ 3.7 M
elements per call, perfectly parallel across `(itheta, k)`. **Strong
candidate for GPU offload** if SnapWave's other state were already on
device — but in isolation, the cost of staging `w360` (and friends) to
device per call would erase most of the gain. Pairs naturally with
amortization (row 2): if `make_theta_grid` only runs when needed, the
GPU port becomes irrelevant.

**4. `solve_tridiag` — 11 % of SnapWave; FRIENDLY in isolation, but
context-bound.** Thomas algorithm on a small (`ntheta`-sized, here 36)
tridiagonal. Trivially parallel across cells if you batch them. CUDA
has `cusparse<t>gtsvInterleavedBatch` / `gtsvStridedBatch` that handles
exactly this shape. The catch: `solve_tridiag` is called from INSIDE
`solve_energy_balance2Dstat`'s sequential per-cell loop, so it cannot
be GPU-batched without restructuring its caller — which puts us back at
the row-1 problem.

**5. `compute_herbers` — 7 % of SnapWave; SMALL DATA, not worth
porting.** Frequency-domain bispectral transfer, ~`nfreqs * nfreqs`
work per boundary point, with `interp_linear_interp_2d_real4` for
JONSWAP-gamma lookup tables. Per-call data size is small (boundary
points × frequencies — single-digit MiB) and the algorithm is mostly
double loops over frequency pairs, no obvious data-parallel structure
across boundaries (each boundary's call has different conditions). H↔D
amortization would dominate; not a sensible port target.

### Call pattern + cross-boundary data volume

`sfincs_snapwave_update_wave_field` (= the `:snapwave_update` NVTX
range) is called from `source/src/sfincs_lib.F90:617`, gated by
`snapwave .and. update_waves`. `update_waves` flips on once every
`dtwave` simulated seconds (sfincs_lib.F90:569-574), so for this case
(`dtwave = 1800 s`, `tstop = 86400 s`) SnapWave runs exactly 48 times
across a 24-h simulation. Across-boundary traffic per call:

- **In** (SFINCS → SnapWave): `zs`, optionally `windu` / `windv`, on the
  SFINCS active mask (~`np` ≈ 102 880 here). One real*4 each.
- **Out** (SnapWave → SFINCS): `snapwave_H`, `snapwave_H_ig`,
  `snapwave_Tp`, `snapwave_Tp_ig`, `snapwave_Fx`, `snapwave_Fy`,
  `snapwave_Dw`, `snapwave_Df`, `snapwave_Dwig`, `snapwave_Dfig`,
  `snapwave_cg`, `snapwave_beta`, `snapwave_srcig`,
  `snapwave_alphaig`. Then SFINCS writes `fwuv(npuv)`, `hm0`, `hm0_ig`,
  `sw_tp`, `sw_tp_ig`, plus optional `mean_wave_direction` and
  `wave_directional_spreading`.

Total transfer per call is in the tens of MiB — sub-millisecond at
PCIe Gen4 — i.e. boundary-transfer cost is *NEGLIGIBLE* compared to the
~1 s SnapWave compute.

## Overlap (per-step GPU concurrent with CPU SnapWave) — assessment

SnapWave reads CURRENT-step `zs` (`source/src/sfincs_snapwave.f90:79,83`)
and writes `fwuv` (`source/src/sfincs_snapwave.f90:225-231`), which
SFINCS's `compute_fluxes` then consumes in the momentum equation
(`source/src/sfincs_momentum.f90:587`,
`source/src/sfincs_momentum_gpu.cuf:634`).

The call site at `source/src/sfincs_lib.F90:613-631` shows SnapWave
runs synchronously between `update_discharges` and `compute_fluxes`,
serialized in the host loop. **Overlap is physically viable** — and is
already implicit in the scheme — because:

1. SnapWave already lags by one `dtwave` cycle: its solver iterates
   from `eeold = ee` of the previous call (`snapwave_solver.f90:537`),
   so it is a quasi-stationary update. Letting `fwuv` lag by one extra
   `dtwave` is in the same noise floor as `dtwave` itself.
2. The per-step GPU work uses ~15 s of wall clock across 27 995 steps
   (sfincs.log: momentum 2.1 s + continuity 2.4 s + boundaries 1.3 s +
   wind/output ~9 s for the meteo+output portion). Per `dtwave` window
   (~30 steps with `dt_avg = 3.1 s` from sfincs.log), per-step
   wall-clock is ~0.16 s. SnapWave compute per call is ~1.07 s.

The **maximum wall-clock saving from overlap is therefore bounded by
`min(SnapWave_per_call, per_step_per_window) × N_calls = min(1.07 s,
0.16 s) × 48 = 7.7 s** — about 12 % of total wall clock, hiding ~15 % of
SnapWave's cost. The arithmetic: per-step time is the *smaller* term,
so overlap CANNOT hide more than ~15 % of SnapWave, regardless of how
cleverly the scheduling is done. To get bigger overlap wins, you would
need to dramatically increase per-step wall clock per `dtwave` window
(e.g. raise `dtwave` so each window contains more steps — but that
also reduces the number of SnapWave calls, which directly helps the
denominator more than the numerator).

## `dtwave` coupling frequency — assessment

`dtwave` is declared in `source/src/sfincs_data.f90:88` and read in
`source/src/sfincs_input.f90:67` with a code default of `3600.0` s.
The test case at `tests/cases/case_prod_compound_snapwave/sfincs.inp:9`
overrides this to `1800.0` s.

**Physical justification.** The SnapWave docs in this repo
(`docs/waves.rst`, `docs/developments.rst`) describe the *integration*
of SnapWave (including the Leijnse et al. 2024 IG-balance work) but do
NOT document a recommended `dtwave` for compound-flood cases. The 1800
s value in the case is a HydroMT-SFINCS / setup-tool default, not a
physical lower bound. This is an open question that should be confirmed
with the science owner of the case; for now treat 1800 s as "what the
case ships with", not "what the physics requires".

**Wall-clock impact of raising `dtwave`.** SnapWave costs ~1.07 s
per call, and it is called `tstop / dtwave` times. For this 24-h case:

| `dtwave` | calls | SnapWave wall | total sim wall (est.) | δ vs 1800 s |
|---------:|------:|--------------:|----------------------:|------------:|
| 900 s    | 96   | ~103 s         | ~117 s                  | +85 % slower |
| **1800 s (current)** | **48** | **~51 s** | **~64 s** | **0** |
| 3600 s   | 24   | ~26 s          | ~39 s                   | −39 % faster |
| 5400 s   | 16   | ~17 s          | ~30 s                   | −53 % faster |
| 7200 s   | 12   | ~13 s          | ~26 s                   | −59 % faster |

(Per-step cost held at the measured 13 s. Linear scaling assumed for
SnapWave because solver work is well-conditioned per call.)

**Doubling `dtwave` to the code default (3600 s) would cut total wall
clock by ~40 %** at this case — *if* the science owner agrees the storm
forcing in this case is slow enough for a 1 h coupling cadence. For
storm-surge cases where the wave climate changes on 30-min scales
(e.g. landfall windows of a fast-moving hurricane), 1800 s may be the
right value or even too coarse. This is the highest-leverage knob
identified by this characterization, and it is purely a sfincs.inp
change with no code change.

## Recommendation

**(c) Overlap-scheduling is NOT the right next bet. (a) Full
SnapWave-GPU port is NOT the right next bet. Choose path (d) — defer
SnapWave-GPU work entirely — and instead invest in two non-port
interventions that this profile shows are larger wins for less effort:**

1. **Memoize `make_theta_grid`** so it only runs when the mean wave or
   wind direction has moved meaningfully (e.g. ≥ `dtheta / 2`). At
   ~22 % of SnapWave compute, this is the single biggest CPU-only win
   that does not change any SnapWave physics. Implementation cost: ~1
   day. Wall-clock saving on this case: ~10 % of total sim time.

2. **Make `dtwave` a per-case engineering decision (not a HydroMT
   default)** and document the trade-off: at `dtwave = 3600` s
   (already the SFINCS code default), this case's total wall clock
   drops by ~40 % without any code change. Default cases that don't
   need 1800 s should be migrated. Implementation cost: ~0.5 day plus
   science-owner sign-off per case.

**Why not (a) full SnapWave-GPU.** The dominant routine
(`solve_energy_balance2Dstat`, 66 % of SnapWave) is a directed marching
sweep with strict cell-to-cell data dependencies. A correct port
requires either inventing a new parallelization scheme (multi-coloring
/ wavefront / Jacobi) or accepting that the GPU version converges in
more iterations than the CPU version. Either path is a multi-month
engineering investment with real risk of regressing the science. SnapWave
is the dominant routine *for cases that use it*, but the cases that use
it use it ~48 times per 24-h sim — there is no kernel-fusion win to be
had, no batching across `dtwave` calls, no obvious gather/scatter that
would amortize the porting cost.

**Why not (b) partial port of top-N.** Of the top-5: row 4
(`solve_tridiag`) is locked inside row 1's serial loop; row 5
(`compute_herbers`) is too small; row 3 (`make_theta_grid`) is much
better attacked by memoization than by GPU offload (the latter
requires the rest of SnapWave state to live on device, which row 1
prevents). The only standalone port candidate is row 3 in isolation, and
that's strictly inferior to the memoization fix.

**Why not (c) overlap.** The overlap arithmetic above caps the maximum
saving at ~12 % of total wall clock (the smaller of per-step time and
SnapWave time per `dtwave` window). That win requires nontrivial
scheduler / async-runtime work and adds a permanent one-cycle lag in
the SnapWave→SFINCS coupling that needs science-owner sign-off. Not
worth the engineering for a 12 % ceiling.

**Why (d) + the two non-port interventions wins.** The two non-port
interventions together can cut total wall clock on this case by ~50 %
(10 % from `make_theta_grid` memoization, ~40 % from raising
`dtwave`), require no algorithmic invention, do not change SnapWave's
science, and ship in days rather than months. Once those land, SnapWave
is no longer the dominant bottleneck on this case, and the question of
"is a SnapWave-GPU port worth it?" can be re-asked against a different
profile.

## Fair-comparison baseline note

All numbers above are gpu_n2 vs gpu_n2 (same binary, same case, same
config — instrumented run vs uninstrumented run for fraction work, with
the un-instrumented baseline read from
`tests/perf/phase5-canonical-on-device-final-20260517/sfincs.log`).
**No** cross-config comparison is reported in this document.

A like-for-like N-core MPI CPU baseline (without GPU) was NOT captured
in this issue's window: the CPU build runtime estimate is in the tens of
minutes for this 24 h sim, and the comparison was not load-bearing for
the recommendation above. If a future characterization needs absolute
CPU-vs-GPU speedup framing it should add this baseline; the harness
shape from `run_snapwave_profile.sh` adapts cleanly.
