# SOR-68 Phase 4 — feature-boundary flush/pull bridge helpers PCIe delta

Profile captured 2026-05-17 against `case_prod_compound_snapwave:gpu_n2`
with the post-Phase-4 `source/install_cuda/bin/sfincs`. Identical
methodology to the Phase 3 capture
(`tests/perf/phase3-aux-arrays-device-canonical-20260517/`): 60 s
steady-state NSight window after a 20 s startup-skip delay, CUDA-aware
HPC-X 2.24 inside `sfincs-build-gpu:latest`, MPI ranks=2 with
`--gpus all`. The case has wavemaker / nonhydrostatic / BMI all OFF, so
the helper predicates `if (wavemaker) ... call flush_..._wavemaker`,
`if (nonhydrostatic) ... call flush_..._nonhydrostatic`, and the BMI
entry points are never entered in this run; only the per-step inner-
loop fast path executes. The expectation is byte-for-byte identical
PCIe to the Phase 3 baseline.

## Bulk byte totals (60 s steady-state window, rank 0)

| Op          | Phase 3 (MB) | Phase 4 (MB) | Δ                  |
|-------------|--------------|--------------|--------------------|
| D2D memcpy  |    17153.237 |    16902.893 | −250.344 (−1.46%)  |
| D2H memcpy  |     4280.979 |     4221.545 |  −59.434 (−1.39%)  |
| P2P memcpy  |      267.782 |      263.874 |   −3.908 (−1.46%)  |
| H2D memcpy  |       72.157 |       70.709 |   −1.448 (−2.01%)  |

The small (~1.5%) deltas are within natural per-run variance — the
60 s steady-state window captures a slightly different number of
inner-loop steps (Phase 4: 39836 D2D copies; Phase 3: 40426 D2D copies
— about 1.5% fewer steps, which matches the byte-count deltas across
all four classes). No new H2D / D2H bytes are introduced by the
helpers when all three feature predicates are false — the inner-loop
fast path is unchanged.

## Per-step NVTX averages (in_loop PCIe-relevant ranges, rank 0)

| Range                  | Phase 3 avg (ns) | Phase 4 avg (ns) | Δ      |
|------------------------|------------------|------------------|--------|
| bnd_conditions_copyin  |          33031.2 |          32908.5 | −0.37% |
| cont_subgrid_copyout   |          71563.3 |          70777.5 | −1.10% |
| mom_fluxes_copyout     |          13208.2 |          13064.2 | −1.09% |
| bnd_fluxes_copyout     |            237.7 |            222.2 | −6.52% |
| cont_subgrid_copyin    |            245.0 |            243.4 | −0.65% |
| mom_fluxes_copyin      |            211.3 |            226.8 | +7.34% |

All per-step PCIe ranges are within ±10% of the Phase 3 baseline, well
within the per-run NVTX variance seen across prior phases. None of the
flush/pull helper NVTX ranges appear in the table because the helpers
are guarded by feature predicates (`if (wavemaker)`,
`if (nonhydrostatic)`, `if (bmi)`) that are all false for this case.

## Conclusion

The Phase 4 bridge helpers add zero inner-loop PCIe cost on cases that
leave wavemaker / nonhydrostatic / BMI off, satisfying the AC
"the new helpers add zero cost when their feature predicate is false."

## Artifacts

- `phase4_rank0.nsys-rep` — raw NSight Systems report (rank 0)
- `nvtx_pushpop_sum.csv` — per-NVTX-range timing summary (rank 0)
- `cuda_gpu_mem_size_sum.csv` — per-class PCIe byte totals (rank 0)
- `nvidia_smi_dmon.txt` — GPU 0+1 sm% / Rx-PCIe / Tx-PCIe @ 2 s
- `rank0_top.txt` — rank-0 sfincs %CPU sampled at 1 s
- `sfincs.log` — SFINCS run log (timing summary)
- `sfincs.stdout` — MPI launcher + nsys stdout
- `nsys_stats.stdout` — nsys export / stats container stdout
- `run_phase4_profile.sh` — capture script (host-side orchestration)
