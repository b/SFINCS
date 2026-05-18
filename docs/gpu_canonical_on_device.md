# Canonical-on-device invariant (GPU build)

In the CUDA Fortran build, the per-step inner loop is **canonical on
device**: the device shadows of the SFINCS state arrays (`zs`, `q`,
`q0`, `uv`, `uv0`, `kfuv`, `zsmax`, `zsm`, `maxzsm`, `z_volume`,
`zsderv`, `zsb`, `zsb0`, `uvmean`, the per-step auxiliary arrays in
`source/src/sfincs_data_device.cuf`) hold the authoritative values
across the entire per-step path through `compute_fluxes` /
`compute_water_levels_*` / `update_boundary_*`. Their host aliases
(`zs_h`, `q_h`, `uv_h`, etc.) are NOT refreshed every step. They are
refreshed at exactly three sync points:

1. **Output-cadence flush** — `device_to_host_for_output` in
   `source/src/sfincs_partition.cuf`. Invoked from `sfincs_lib.F90`
   immediately before each `write_output` call; refreshes every host
   shadow the netCDF / restart writers and host BMI getters read.
2. **SnapWave coupling boundary** — the `dtwave`-cadence
   `update_wave_field` entry point in
   `source/src/sfincs_snapwave_gpu.cuf` flushes the host shadows of
   the arrays SnapWave reads (`zs_h`, `zsm_h`, `maxzsm_h`, etc.) once
   per coupling step, NOT once per simulation step.
3. **Feature-boundary flush / pull** — the
   `flush_device_to_host_state(bundle)` and
   `pull_host_state_to_device(bundle)` helpers in
   `source/src/sfincs_partition.cuf` (added in SOR-68 / Phase 4)
   bracket every entry into wavemaker / nonhydrostatic / BMI host
   code with a flush before the call and a pull after, so each
   feature-boundary path sees a consistent host view and its host
   writes propagate back to the device.

Per-step `bridge_in_*` / `bridge_out_*` calls in the three per-step
files (`source/src/sfincs_momentum_gpu.cuf`,
`source/src/sfincs_continuity_gpu.cuf`,
`source/src/sfincs_boundaries_gpu.cuf`) — and bare Fortran whole-array
assignments between a device array and its `_h` host shadow in those
files — are a **regression**: they reintroduce the per-step host↔device
PCIe traffic the SOR-65/66/67/68 phases eliminated. The
`scripts/check-no-per-step-bridges.sh` guard scans the three files for
both idioms and exits non-zero on any line not in
`scripts/per-step-bridge-allowlist.txt`; new entries on the allowlist
require justification in the PR description that adds them, against the
three sync points above. See `tests/perf/` for the Phase-0 baseline
profile (`phase0-baseline-20260516/`) and the Phase-5 final-state
profile that quantify the per-step PCIe reduction this invariant buys.

Strict byte-identicality of every simulation-output variable across the
SOR-65 → SOR-68 refactor was verified on the deterministic single-rank
GPU path (`case_regular gpu_n1`) under
[`tests/perf/phase5-bytewise-deterministic-20260517/`](../tests/perf/phase5-bytewise-deterministic-20260517/SUMMARY.md):
`zs`, `h`, `zsmax`, `hmax`, `zb`, `msk`, `manning`, and the grid corner
coordinates all match bit-exactly between pre-Phase-1 and post-Phase-4.

The SnapWave host-side hot path on the same case is characterized in
`tests/perf/snapwave-characterization-20260517/` (SOR-81), which
identifies the top SnapWave routines and recommends two non-port
interventions over a SnapWave-GPU port.

The full CPU-vs-GPU wall-clock matrix across the production case set,
with pre-fix (`d1b84c1`) vs post-fix (post SOR-65 → SOR-86) numbers
and a matched-parallelism `cpu_n$(nproc)` baseline (OpenMP rather
than MPI — the CPU build is OpenMP-only because MPI in
`source/src/sfincs_lib.F90` is gated on `USE_CUDA`), is at
[`tests/perf/perf-matrix-20260518/SUMMARY.md`](../tests/perf/perf-matrix-20260518/SUMMARY.md)
(SOR-87). That file is the canonical post-program-of-work performance
reference; every speedup ratio there carries its full config-pair
label per AC.
