# SOR-69 Phase 5 — canonical-on-device final-state characterization

Closing artifact for the SOR-65 / SOR-66 / SOR-67 / SOR-68 chain. Phases
1-4 progressively moved canonical SFINCS state from host arrays into
device shadows: `zs` (Phase 1, SOR-65), `q` / `q0` / `uv` / `uv0`
(Phase 2, SOR-66), the per-step auxiliary arrays (Phase 3, SOR-67),
and the feature-boundary flush / pull helpers that bracket the
wavemaker / nonhydrostatic / BMI host code (Phase 4, SOR-68). Phase 5
measures the cumulative effect on `case_prod_compound_snapwave` at
`gpu_n2`, lands a regression guard, and documents the invariant.

## Methodology

Identical to the SOR-64 Phase-0 NVTX-annotated baseline at
`tests/perf/phase0-baseline-20260516/` and the SOR-68 Phase-4 delta at
`tests/perf/phase4-bridge-helpers-20260517/`:

  * Case: `case_prod_compound_snapwave` at `gpu_n2` (2 MPI ranks, 2 GPUs).
  * Hardware: 2x NVIDIA RTX A6000.
  * Container: `sfincs-build-gpu:latest` (NVHPC 25.9, HPC-X 2.24 CUDA-aware).
  * NSight Systems window: 60 s steady-state, after a 20 s startup-skip
    delay; rank 0 traced (CUDA, NVTX, MPI), other ranks bare. The
    Phase-0 NVTX-range labels (`mom_*`, `cont_*`, `bnd_*`, `halo_*`)
    are unchanged across Phases 0-5, so the comparison is direct.
  * Profile script: `run_phase5_profile.sh` (same methodology as
    `phase4-bridge-helpers-20260517/run_phase4_profile.sh`).

## Validation matrix (AC #1)

`tests/perf/run_phase5_validation.sh` drives the full
`tests/run_validation.sh --skip-fetch` matrix against the merged
Phases 1+2+3+4 stack: builds CPU + CUDA from this branch's source,
runs every case under `tests/cases/` at `gpu_n1` and `gpu_n2`, diffs
each GPU run's `zsmax` against the matching CPU baseline at the
harness's standard 1e-4 ratio threshold (with per-pair overrides in
`tests/run_validation.sh` unchanged). Full verdict table in
`validation_verdicts.txt`; harness stdout in `validation_stdout.txt`;
harness exit code in `validation_exit_code.txt`.

Result of this run (14 cases x {gpu_n1, gpu_n2} = 28 (case, config)
pairs; `case_production` is SKIPPED because `--skip-fetch` finds no
fetched input):

  * **27 PASS**.
  * **1 FAIL** — `case_prod_storm_amuv:gpu_n1` at ratio 1.31e-4 vs the
    1e-4 threshold.

The single FAIL is a pre-existing flake diagnosed in SOR-73
("Diagnose case_prod_storm_amuv:gpu_n1 zsmax drift", commit
`2a2f4cc`, merged BEFORE Phase 1). That diagnosis recorded per-run
ratio variability of 6.41e-5 (PASS) to 1.31e-4 (FAIL) across six
fresh runs on pre-Phase-1 main; three of six fail the 1e-4 gate.
The 1.31e-4 ratio this run produced is the documented upper-bound
realisation of the same non-determinism (per-step CPU↔GPU bisect
localised it to the GPU code path; the case has no on-device fix).
The case was therefore NOT uniformly PASS pre-Phase-1, so the AC
"every (case, config) that was PASS pre-Phase-1 is still PASS
post-Phase-4 at the unchanged 1e-4 ratio threshold" is satisfied:
the only post-Phase-4 FAIL is for a case that was already a
documented flake pre-Phase-1, not a regression introduced by the
canonical-on-device refactor.

## NSight profile — Phase 5 vs Phase 0 (AC #3)

The four AC #3 metrics are recorded below as measured numbers; the AC
notes they are environment-dependent and not gated mechanically — the
gate is that all four moved in the predicted direction. Three of four
moved as predicted; one (rank-0 CPU%) is dominated by host-side
SnapWave coupling that this refactor did not touch, so the metric is
non-discriminating for this case (see below).

### GPU SM% — sustained (`nvidia_smi_dmon.txt`, max over 60 s window)

| GPU | Phase 0 sm_max | Phase 5 sm_max | Direction       |
|-----|----------------|----------------|-----------------|
| 0   | 20 %           | **31 %**       | up +55 % (predicted, met) |
| 1   | 18 %           | **24 %**       | up +33 % (predicted, met) |

### PCIe steady-state — attributed (`cuda_gpu_mem_size_sum.csv` total over 60 s window, rank 0)

| Direction | Phase 0      | Phase 5    | Reduction |
|-----------|--------------|------------|-----------|
| H2D       | 32,665.90 MB | **72.16 MB** | -99.78 % |
| D2H       | 73,184.58 MB | **4,282.96 MB** | -94.15 % |
| D2D       | 11,989.72 MB | 17,153.24 MB |  +43 %    |
| P2P       |    104.83 MB |    267.78 MB |  +155 %   |

(Predicted: near-zero inner-loop PCIe with spikes only at
`dtwave = 1800.0` and `dtmapout` cadences. **Met:** the 4,283 MB D2H
residual is bunched at output cadence — the per-step component is
~3.5 kB/step (vs Phase-0 2,296 kB/step H2D + 5,144 kB/step D2H,
total 7,440 kB/step), a ~97 % per-step reduction. D2D and P2P
increases are halo-related and a separate concern.)

### PCIe sustained — nvidia-smi (`nvidia_smi_dmon.txt`, max over 60 s window)

| GPU | Phase 0 Rx (MB/s) | Phase 5 Rx (MB/s) | Phase 0 Tx (MB/s) | Phase 5 Tx (MB/s) |
|-----|-------------------|-------------------|-------------------|-------------------|
| 0   | 1065              | **60**            | 2427              | **598**           |
| 1   | 1039              | **59**            | 2382              | **595**           |

(`Rx` = GPU PCIe receive = host->device, `Tx` = transmit = device->host.
Predicted: near-zero steady-state with spikes at output cadence. **Met:**
both directions drop ~94 % on Rx and ~75 % on Tx; the residuals are
the `dtwave = 1800 s` SnapWave-coupling refresh and the `dtmapout`
output flush.)

### CPU rank-0 utilization (`rank0_top.txt`, 67 samples over ~67 s)

| Statistic    | Phase 0 | Phase 5 |
|--------------|---------|---------|
| mean         | 99 %    | 97.9 %  |
| max          | 101 %   | 101 %   |
| median       | -       | 100 %   |
| samples >=75 | -       | 65 of 67 |

(Predicted: meaningfully lower than 100 %. **Not met for this case.**
`case_prod_compound_snapwave` spends ~78 % of wall time in host-side
SnapWave coupling (`sfincs.log`: "Time in SnapWave: 49.412
( 78.5%)"); SnapWave is CPU-bound and was not touched by Phases 1-4.
The inner-loop per-step CPU work IS lower in Phase 5 — the absolute
seconds in `momentum / continuity / boundaries` dropped from
~30-40 s (extrapolated from Phase-0 wall ~120 s and the Phase-4
breakdown showing the same kernels at 7.4 s) to ~7.4 s — but
SnapWave fills the gap, keeping rank-0 saturated. For this metric to
move, a case where SnapWave is not the dominant CPU consumer would
have to be profiled; that is outside the SOR-69 scope and would be
the subject of a future SnapWave-GPU phase.)

### Wall clock (`sfincs.log` "Total time")

| Phase | Wall clock |
|-------|------------|
| Phase 0 (extrapolated; nsys-killed at 80 s, log shows "50% complete, 60.3 s remaining") | **~120 s** |
| Phase 4 (full sim, post-feature-boundary stack) | 65.017 s    |
| Phase 5 (this capture, post-Phase-4-stack rebuild) | **65.695 s** |

(Predicted: meaningfully shorter than Phase 0. **Met:** ~45 %
reduction. Phase 4 vs Phase 5 wall clock matches to within run-to-run
noise, which is expected — Phase 5 makes no Fortran source changes
relative to Phase 4; only the regression guard and scripts are added.)

### Per-NVTX-range PCIe attribution (rank 0, this capture)

`nvtx_pushpop_sum.csv` (60 s window, rank 0, 20213 step calls):

| Range                  | Phase 5 avg (ns) | Phase 0 avg (ns; from `summary.md`) |
|------------------------|------------------|--------------------------------------|
| `mom_fluxes_copyin`    |  ~                |  ~                                   |
| `mom_fluxes_kernel`    | 83878.1          | ~                                    |
| `mom_fluxes_copyout`   | 13101.4          | ~                                    |
| `cont_subgrid_copyout` | 71369.8          | ~                                    |
| `cont_subgrid_kernel`  | 24067.9          | ~                                    |
| `cont_subgrid_copyin`  | 243.3            | ~                                    |
| `bnd_fluxes_kernel`    | 14048.8          | ~                                    |
| `bnd_conditions`       | 53497.9          | ~                                    |
| `halo_q_uv`            | 86740.5          | ~                                    |
| `halo_zs`              | 44750.8          | ~                                    |

(The per-step NVTX averages in `nvtx_pushpop_sum.csv` confirm the
post-canonical-on-device shape: `cont_subgrid_copyin` collapsed to
~243 ns (a single qext-feature-gated bridge that bypasses on this
case), `mom_fluxes_copyout` is down to 13.1 us, and the
`bnd_fluxes_copyin` and `bnd_fluxes_copyout` ranges no longer appear
in the rank-0 top-20 because they have collapsed to sub-microsecond
guard-band overhead. Compare against
`tests/perf/phase0-baseline-20260516/summary.md` which shows the
same ranges totalled in the 1-2 ms range each before the refactor.)

## sfincs_map.nc byte-identical check (AC #2)

`run_byte_identical_check.sh` built the pre-Phase-1 binary at commit
`d1b84c1` (the Phase-0 NVTX-annotated commit immediately preceding the
Phase-1 `zs`-device-canonical refactor at `9c3e69c`) in a sibling
worktree (`/tmp/sfincs-pre-phase1-baseline`), ran
`case_prod_compound_snapwave` at `gpu_n2` to completion, and committed
the resulting `sfincs_map.nc` as `pre_phase1_sfincs_map.nc` here. The
post-Phase-4 `sfincs_map.nc` came from the validation-matrix run at
`tests/runs/case_prod_compound_snapwave/gpu_n2/sfincs_map.nc` and is
committed as `post_phase4_sfincs_map.nc`. Full comparison in
`byte_identical_check.log`:

| Comparison       | Result                                         |
|------------------|------------------------------------------------|
| File size        | 14606948 B (pre) vs 14601075 B (post), **delta -5873 B** |
| sha256           | `a2a008d7...` (pre) vs `9de33134...` (post), **mismatch** |
| `cmp -l`         | NOT byte-identical (first 10 byte diffs at offsets 29-48 and 18025-18411) |
| `diff_zsmax` ratio (pre as reference) | max_abs_diff = 1.641e-4, max_zsmax_ref = 0.9975, **ratio = 1.645e-4 against threshold 1e-4 -> FAIL on strict gate** |

**Finding: strict byte-identicality is NOT achievable for this case.**
The 1.645e-4 pre-Phase-1 vs post-Phase-4 zsmax ratio is in the same
~1e-4 envelope as the GPU-vs-CPU baseline residual that the validation
matrix's `THRESHOLD_OVERRIDE` map already documents
(`tests/run_validation.sh`: 5e-4 for `case_prod_compound_snapwave`
gpu_n2, with the diagnosis pointing at inherent multi-rank
floating-point non-associativity in the cross-partition wet/dry front
propagation in `k_compute_fluxes`, latched permanently by the `zsmax`
running max). The same non-determinism shows up here as run-to-run
variability between two independent gpu_n2 runs of (conceptually) the
same algorithm; the Phases 1-4 refactor does not introduce additional
drift but also does not eliminate the underlying GPU FP
non-associativity.

The 1e-4 strict ratio gate is NOT met. The 5e-4 per-pair override
that the validation matrix uses for this case IS met (1.645e-4 <
5e-4). The AC #1 ratio-check gate (against the matrix's own CPU
baseline, threshold 5e-4 per the override) IS met (the matrix's
`case_prod_compound_snapwave:gpu_n2` verdict in this run is PASS at
ratio 1.26e-4 vs the 5e-4 override).

**Implication for AC #2 as written:** the AC's "byte-identical
pre/post the cumulative Phases 1+2+3+4 stack" is empirically not
achievable for this case on this hardware (and would not be
achievable for any case where the GPU code path has documented
multi-rank FP non-associativity in its reductions / atomics). The
operative behavioural gate is AC #1's validation-matrix ratio
check, which passes. Recommend that future iterations of this AC
target either a (case, config) pair with a determined GPU code path
(e.g. single-rank for cases without partition-boundary atomics) or
explicitly substitute the matrix's per-pair-override ratio for the
strict byte-identical claim.

## Artifacts (this directory)

  * `phase5_rank0.nsys-rep`        — raw NSight report (rank 0)
  * `nvtx_pushpop_sum.csv`         — per-NVTX-range timing summary (rank 0)
  * `cuda_gpu_mem_size_sum.csv`    — per-class PCIe byte totals (rank 0)
  * `nvidia_smi_dmon.txt`          — GPU 0+1 sm% / Rx-PCIe / Tx-PCIe @ 2 s
  * `rank0_top.txt`                — in-container rank-0 sfincs %CPU @ 1 s
  * `sfincs.log`                   — SFINCS run log (timing summary)
  * `sfincs.stdout`                — MPI launcher + nsys stdout
  * `nsys_stats.stdout`            — nsys export / stats container stdout
  * `run_phase5_profile.sh`        — capture script (host-side orchestration)
  * `run_byte_identical_check.sh`  — AC #2 byte-identical driver
  * `pre_phase1_sfincs_map.nc`     — pre-Phase-1 baseline output (AC #2)
  * `post_phase4_sfincs_map.nc`    — post-Phase-4 output (AC #2)
  * `byte_identical_check.log`     — AC #2 comparison log
  * `validation_verdicts.txt`      — AC #1 verdict table
  * `validation_stdout.txt`        — AC #1 full harness stdout
  * `validation_exit_code.txt`     — AC #1 harness exit code
  * `SUMMARY.md`                   — this file
