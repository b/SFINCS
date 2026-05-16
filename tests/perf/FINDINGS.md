# SOR-52 perf characterization findings

Case: `case_prod_compound_snapwave` at `gpu_n2` (2 MPI ranks, 2 GPUs).
Hardware: 2× NVIDIA RTX A6000.
Container: `sfincs-build-gpu:latest` (NVHPC 25.9, HPC-X 2.24).
Simulated time window: 6 h (`tstart = 20200101 000000` → `tstop = 20200101 060000`).
Capture script: `tests/perf/run_perf.sh`.

## Result summary

| Variant   | wall (s) | SFINCS total (s) | dt avg (s) | GPU sm % (typ) | PCIe Tx (MB/s) | PCIe Rx (MB/s) | sfincs_map.nc max abs diff vs post-fix |
| --------- | -------- | ---------------- | ---------- | -------------- | -------------- | -------------- | -------------------------------------- |
| pre-fix   | 35.28    | 33.71            | 3.002      | 14 – 19        | 2 200 – 2 500  | 1 000 – 1 100  | 0.0 (bit-exact)                        |
| post-fix  | 35.57    | 34.04            | 3.002      | 17 – 19        | 2 400 – 2 500  | 1 000 – 1 100  | reference                              |

Per-variant raw artifacts:

* `tests/perf/<variant>/sfincs.log`        — SFINCS log including startup banner and timing summary
* `tests/perf/<variant>/sfincs.stdout`     — MPI launcher stdout, including the rank-0 `CUDA-aware MPI: yes/no` line
* `tests/perf/<variant>/nvidia_smi_dmon.txt` — GPU 0 utilization + PCIe Rx/Tx sampled at 2 s
* `tests/perf/<variant>/time.txt`          — host-side `/usr/bin/time -v` (wall + RSS; CPU% is the docker client, not the in-container ranks)
* `tests/perf/<variant>/variant_probe.txt` — `which mpirun` + `ompi_info` parameter dump for the variant

The two `sfincs_map.nc` outputs are intentionally NOT committed (8 MB of
binary). The bit-exact diff verdict is recorded below; future
characterizations should re-run `run_perf.sh` and re-diff.

## Numerical correctness preservation

The pre-fix and post-fix `sfincs_map.nc` files compare bit-exact under
`tests/scripts/diff_zsmax.py`:

```
RESULT case=pre-fix max_abs_diff=0.0 max_zsmax_ref=0.9975454807281494 ratio=0.0 threshold=1e-06 verdict=PASS
```

This is expected: the bytes on the MPI wire are `real*8 → MPI_DOUBLE_PRECISION
→ real*8` whether routed via GPUDirect / cuda_copy or via host staging.

## Why pre-fix vs post-fix numbers match in this container

The issue body assumed two distinct OpenMPI installations under NVHPC 25.9:
a CUDA-aware HPC-X 2.24 under `comm_libs/13.0/hpcx/hpcx-2.24/`, and a
non-CUDA-aware OpenMPI under `comm_libs/mpi/`. In the actual
`sfincs-build-gpu:latest` image both `mpirun` paths resolve to the same
HPC-X 2.24 process:

1. `comm_libs/mpi` is a **symlink** to `comm_libs/hpcx`. The "default"
   `mpirun` at `comm_libs/mpi/bin/mpirun` is a 319 KB wrapper that
   internally execs the full HPC-X mpirun at
   `comm_libs/13.0/hpcx/hpcx-2.24/ompi/bin/.bin/mpirun`. Verified via
   `ps --forest` during the pre-fix run, which shows the
   `comm_libs/mpi/bin/mpirun` → `comm_libs/13.0/hpcx/latest/ompi/bin/mpirun`
   → `comm_libs/13.0/hpcx/hpcx-2.24/ompi/bin/.bin/mpirun` chain.
2. The SFINCS GPU binary is dynamically linked with `DT_RUNPATH` pointing
   at `comm_libs/13.0/hpcx/hpcx-2.24/ompi/lib`. There is no second
   `libmpi.so.40` anywhere in the image (`find / -name 'libmpi.so*'`
   returns only the HPC-X copy), so the dynamic loader resolves
   `libmpi.so.40` to HPC-X regardless of `LD_LIBRARY_PATH`.
3. The pre-fix variant additionally passes
   `--mca opal_cuda_support 0 --mca mpi_cuda_support 0` to disable the
   CUDA-aware runtime path at the OMPI layer (closest in-container
   proxy for "non-CUDA-aware MPI"). `MPIX_Query_cuda_support` still
   reports `1` because it reflects build-time support, not the runtime
   toggle; the rank-0 `CUDA-aware MPI: yes (MPIX_Query_cuda_support=1)`
   log line appears in both variants.

Net result: this container has effectively one MPI stack, and the
SFINCS binary's link recipe makes the choice non-runtime-overridable.
The PATH/LD_LIBRARY_PATH layering and `MPIX_Query` warning shipped in
this issue are still load-bearing **as defense-in-depth**:

* When (not if) NVHPC's container layout changes — e.g. NVHPC 26.x
  re-introduces a separate non-CUDA-aware MPI under `comm_libs/mpi`,
  or a downstream image rebuilds SFINCS against system OpenMPI — the
  wrapper / Dockerfile fix prevents silent regression.
* When an operator builds SFINCS outside this container (custom
  cluster module, manual cmake / autotools, a different MPI
  implementation) the `MPIX_Query` rank-0 line gives a one-line
  status; a multi-rank GPU run that prints
  `WARNING: MPI is not CUDA-aware` is immediately diagnosable as the
  failure mode described in the issue body.

## Why the GPU utilization sits at ~17 – 19 % even in post-fix

The AC's expected post-fix profile is "GPU 75 – 90 %, PCIe near zero
except at SnapWave / output cadence". The measured profile is GPU
14 – 19 % with sustained ~2 GB/s PCIe Rx + ~1 GB/s Tx. The dominant
cost is SnapWave (43 % of total runtime per `sfincs.log`):
`Time in SnapWave : 13.95 s` vs `momentum 5.50 s + continuity 4.76 s`
combined. SnapWave runs CPU-side and bridges arrays in/out of device
memory at every SnapWave update cadence (`dtwave = 1800 s`), which is
where the steady-state PCIe traffic comes from. That is on the
out-of-scope list for SOR-52 ("The SnapWave bridge H↔D copies that
happen at the SnapWave update cadence are correct and intentional;
SnapWave runs CPU-side"), so this fix neither targets nor changes it.

## Concurrent-run caveat (capture-time orphan)

During the pre-fix capture the host had an orphaned `sfincs` container
from a 03:36 invocation still attached to both GPUs:

```
3691466  ...  sfincs (rank 0, idle)         GPU 0, 292 MiB
3691467  99%CPU 5h43m sfincs (rank 1, hot)  GPU 1, 292 MiB
```

That orphan is a textbook instance of the symptom described in the
issue body — one rank pegged at 100 % single-thread CPU, the other
idle — running for hours on a stale validation invocation. It was
left untouched (cross-session cleanup is out of scope here) but its
ambient ~600 MiB of GPU memory and intermittent SM contention may
slightly bias the pre-fix / post-fix dmon numbers upward (more PCIe
noise) and the wall clock downward (the orphan was MPI-idle, not
GPU-busy, during the capture window). Repeating the capture with a
clean host would not be expected to change the qualitative
finding that both variants behave identically.

## Repro

```sh
source/build_scripts/run_gpu_container.sh source/build_scripts/build_cuda.sh
tests/perf/run_perf.sh pre-fix
tests/perf/run_perf.sh post-fix
python3 tests/scripts/diff_zsmax.py \
    --reference tests/perf/post-fix/sfincs_map.nc \
    --candidate tests/perf/pre-fix/sfincs_map.nc \
    --threshold 1e-6
```
