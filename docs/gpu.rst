GPU build
=========

This page describes how to build, run, tune and troubleshoot the SFINCS
GPU implementation. The GPU path is **functional and validated today**:
every case under ``tests/cases/`` runs to completion on the GPU at both
single-rank (``gpu_n1``) and dual-rank (``gpu_n2``) configurations, and
the per-pair verdicts are tracked in
``tests/perf/phase5-canonical-on-device-final-20260517/validation_verdicts.txt``.

If you previously read the "Docker GPU version … is not fully functional"
line in :doc:`developments`, that note pre-dates the canonical-on-device
refactor and no longer reflects the current state of ``main``.

Overview
--------

The GPU build of SFINCS runs the per-step shallow-water solver — the
momentum, continuity and boundary-conditions kernels — on the device
in CUDA Fortran. The host shadows of the SFINCS state arrays (``zs``,
``q``, ``q0``, ``uv``, ``uv0``, ``kfuv``, ``zsmax``, ``zsm``,
``z_volume``, …) are refreshed only at three sync points: the
output-cadence flush, the SnapWave coupling step (``dtwave``), and the
feature-boundary flush/pull bracket around wavemaker / nonhydrostatic /
BMI host code. This invariant — described in detail in the
:doc:`gpu_canonical_on_device` reference — eliminates the per-step
host↔device PCIe traffic that earlier OpenACC GPU builds incurred.

SnapWave coupling itself remains host-side; see
`Current limitations`_ for the rationale and the in-flight
SnapWave-host-side improvement track.

On the development workstation
(2× NVIDIA RTX A6000 Ampere, ``sfincs-build-gpu:latest`` container,
NVHPC 25.9 / CUDA 13.0 / HPC-X 2.24 CUDA-aware OpenMPI), a 24-hour
simulation of ``case_prod_compound_snapwave`` at ``gpu_n2`` runs in
~64 s wall clock with SnapWave consuming ~50 s of that total (78 %).
The corresponding pre-refactor baseline was ~120 s, a ~45 % reduction;
the per-step inner-loop PCIe transfer collapsed from ~7.4 MB/step to
~3.5 kB/step (a ~99 % reduction in steady-state PCIe traffic). The
underlying measurements are in
``tests/perf/phase5-canonical-on-device-final-20260517/SUMMARY.md``.

Prerequisites
-------------

The GPU path is **Docker-only** today; it relies on the
``sfincs-build-gpu:latest`` container described in
``source/build_scripts/Dockerfile_gpu``. The container ships NVIDIA
HPC SDK 25.9, the CUDA 13.0 toolkit, HPC-X 2.24's CUDA-aware OpenMPI
build, and the GNU autotools/netcdf headers needed to build SFINCS
from source against ``nvfortran``.

On the host you need:

* **NVIDIA driver** new enough for CUDA 13.0 (driver ≥ 580.x; check
  ``nvidia-smi`` and confirm "CUDA Version" in the header is ≥ 13.0).
  The container's runtime checks the driver, not the host's CUDA
  toolkit, so no host-side CUDA install is required.
* **Docker Engine** (or compatible container runtime). The build
  scripts use ``docker build`` / ``docker run``; a podman or
  containerd-direct path is not exercised.
* **NVIDIA Container Toolkit** — the ``--gpus all`` flag that
  ``source/build_scripts/run_gpu_container.sh`` passes to
  ``docker run`` is implemented by ``nvidia-container-toolkit``.
  Without it, ``docker run --gpus all`` fails with
  ``could not select device driver "" with capabilities: [[gpu]]``.

There is no Singularity-equivalent path for the GPU build today. If
you need to run SFINCS under Singularity, see :doc:`singularity` for
the CPU container path.

Building the GPU container
--------------------------

Build the dev container image once per host. From the repository
root::

    docker build -f source/build_scripts/Dockerfile_gpu \
        -t sfincs-build-gpu:latest source/build_scripts

This produces the ``sfincs-build-gpu:latest`` image (~14 GB,
dominated by the NVHPC SDK layer). Confirm with::

    docker images sfincs-build-gpu

Then build the GPU SFINCS binary inside the container::

    source/build_scripts/run_gpu_container.sh \
        source/build_scripts/build_cuda.sh

``run_gpu_container.sh`` mounts the repository at ``/work`` inside
the container, maps the host UID/GID (so build artifacts aren't
root-owned), passes ``--gpus all``, and prepends the HPC-X 2.24
CUDA-aware MPI environment to ``PATH`` / ``LD_LIBRARY_PATH`` (the
non-CUDA-aware OpenMPI at ``comm_libs/mpi`` would otherwise silently
stage every device-pointer ``MPI_Isend`` through pinned host memory,
saturating one CPU thread and stalling the GPU). ``build_cuda.sh``
runs the canonical-on-device regression guard
(``scripts/check-no-per-step-bridges.sh``), then ``autoreconf`` /
``./configure --enable-cuda`` / ``make`` / ``make install`` inside
the container. The autotools build is single-threaded by design —
Automake does not encode Fortran ``.mod`` dependencies, so ``make -j``
fails non-deterministically.

The resulting binary is on the host at
``source/install_cuda/bin/sfincs``.

Common build failures:

* **Network blocks during ``docker build``.** The base image pulls
  the NVHPC SDK from ``nvcr.io/nvidia/nvhpc`` (~14 GB). If your
  network blocks this registry, pre-pull on an unblocked machine
  with ``docker pull nvcr.io/nvidia/nvhpc:25.9-devel-cuda13.0-ubuntu24.04``
  and ``docker save | docker load`` across.
* **``ERROR: nvfortran not found on $PATH``** from ``build_cuda.sh``
  on the host. This script is intended to run **inside** the
  container; the wrapper ``run_gpu_container.sh`` does this for you.
  If you invoked it on the host directly, switch to the wrapper.
* **``Cannot open module file 'sfincs_data.mod'``** during ``make``.
  You ran ``make -j``; the build does not honor parallel make. Rerun
  the single-threaded form (``build_cuda.sh`` already enforces this).
* **``Corrupt or Old Module file``** during ``make``. A ``.mod`` from
  a different Fortran compiler (gfortran vs nvfortran) is mixed into
  the build tree. Wipe stale Fortran build artifacts under
  ``source/src`` and ``source/third_party_open`` (``find … -name
  '*.mod' -o -name '*.o' -o -name '*.a' -delete``) and rebuild;
  ``tests/run_validation.sh`` does this automatically via
  ``wipe_build_artifacts``.

Running a GPU simulation
------------------------

Two paths are supported today.

Via the validation harness
~~~~~~~~~~~~~~~~~~~~~~~~~~

``tests/run_validation.sh`` is the cross-config (CPU vs GPU) harness
for the in-tree test cases. To run a single case end-to-end, pass
``--skip`` with every other case name (the harness defaults to
running every case under ``tests/cases/``)::

    bash tests/run_validation.sh --skip-fetch \
        --skip case_discharges,case_infiltration,case_meteo,...

The harness builds the CPU binary (``source/install_cpu/bin/sfincs``,
gfortran + OpenMP, deterministic with ``OMP_NUM_THREADS=1``) and the
GPU binary (``source/install_cuda/bin/sfincs`` inside the container),
runs each non-skipped case in three configurations — CPU baseline,
GPU at ``mpirun -n 1`` (``gpu_n1``), GPU at ``mpirun -n 2``
(``gpu_n2``) — and diffs each GPU run's ``zsmax`` against the CPU
baseline using ``tests/scripts/diff_zsmax.py`` at the global ratio
threshold of ``1e-4`` (with per-pair overrides in
``THRESHOLD_OVERRIDE``; see `Tuning knobs`_). ``--skip-build`` reuses
existing binaries, ``--skip-fetch`` skips per-case ``fetch.sh``
downloads.

The harness writes per-(case, config) run directories under
``tests/runs/<case>/<config>/``. Each contains the staged case
inputs, ``sfincs.log``, and the standard SFINCS outputs
(``sfincs_map.nc``, ``sfincs_his.nc``, etc.). The harness prints a
PASS/FAIL/SKIPPED summary at the end and exits 0 iff every
non-SKIPPED pair is PASS.

The ``gpu_n1`` / ``gpu_n2`` config names denote the MPI rank count:
``gpu_n1`` is a single rank, single GPU (deterministic — no
cross-partition halo exchange); ``gpu_n2`` is two ranks, two GPUs
(uses the SOR-62 cross-rank halo path in
``source/src/sfincs_partition.cuf``).

Bare manual invocation
~~~~~~~~~~~~~~~~~~~~~~

To wire SFINCS into your own pipeline, the underlying invocation
inside the container is::

    docker run --rm --gpus all \
        -v $PWD/case:/work/case \
        -w /work/case \
        sfincs-build-gpu:latest \
        mpirun --allow-run-as-root -n 2 \
        /work/source/install_cuda/bin/sfincs

assuming the host repository is also mounted at ``/work`` so that the
prebuilt ``source/install_cuda/bin/sfincs`` is visible inside the
container. In practice
``source/build_scripts/run_gpu_container.sh`` handles the
docker-run flags (UID/GID mapping, ``--gpus all``, HPC-X PATH /
``LD_LIBRARY_PATH``, lifecycle cleanup), so the more typical
invocation is::

    source/build_scripts/run_gpu_container.sh \
        mpirun --allow-run-as-root -n 2 \
        /work/source/install_cuda/bin/sfincs

with the case staged so that ``sfincs.inp`` lives in the current
working directory (the wrapper sets the container ``WORKDIR`` to
``/work``, the host repository root). If you want SFINCS to read
``sfincs.inp`` from a different directory inside the container, pass
``--wdir`` to ``mpirun`` (see ``run_gpu()`` in
``tests/run_validation.sh`` for the pattern).

Worked example: ``case_prod_regular_tide`` at ``gpu_n2``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``tests/cases/case_prod_regular_tide`` is a 500×500 regular-grid
case with 50 m cells, ``tstop = 86400`` s (24 simulated hours),
hourly map output (``dtmapout = 3600``) and a single boundary file
(``sfincs.bzs``). It is one of the production-shaped cases in the
validation matrix; on the development workstation it runs to PASS at
both ``gpu_n1`` and ``gpu_n2`` (see
``tests/perf/phase5-canonical-on-device-final-20260517/validation_verdicts.txt``).

To run only this case end-to-end via the harness::

    bash tests/run_validation.sh --skip-fetch --skip \
        case_discharges,case_infiltration,case_meteo,case_nonhydro_smoke,case_prod_compound_snapwave,case_prod_quadtree_subgrid_tide,case_prod_riverine,case_prod_storm_amuv,case_production,case_quadtree_tide,case_regular,case_snapwave,case_structures,case_wavemaker

After the build, the harness runs the CPU baseline followed by the
two GPU configs, diffs ``zsmax`` between each GPU run and the CPU
baseline, and prints::

    === Validation summary ===
    case                             config   verdict  reason
    ----                             ------   -------  ------
    case_prod_regular_tide           gpu_n1   PASS
    case_prod_regular_tide           gpu_n2   PASS

The per-run outputs are at
``tests/runs/case_prod_regular_tide/gpu_n2/`` (and the matching
``cpu/`` / ``gpu_n1/`` siblings); the main output netCDF is
``sfincs_map.nc`` and the simulation log is ``sfincs.log``.

Tuning knobs
------------

``dtwave``
~~~~~~~~~~

For cases that run with ``snapwave = 1``, ``dtwave`` is the single
highest-leverage performance knob today: SnapWave runs ``tstop /
dtwave`` times over the simulation window and each call is a
non-trivial host-side solve (~1.07 s on the development workstation
for ``case_prod_compound_snapwave``; SnapWave consumes ~78 % of
total wall clock at ``dtwave = 1800`` s). Doubling ``dtwave`` from
1800 s to the SFINCS code default of 3600 s cuts total wall clock by
roughly 40 % for that case. The full wall-clock impact table and the
per-case guidance ("fast-moving systems may need 1800 s or finer";
"slow-moving compound-flood systems tolerate 3600 s or larger") live
under :doc:`waves`'s "Choosing ``dtwave``" section. For GPU cases
in particular, ``dtwave`` is the canonical "make SnapWave cheaper"
lever — there is no GPU-side SnapWave port today (see
`Current limitations`_).

``THRESHOLD_OVERRIDE``
~~~~~~~~~~~~~~~~~~~~~~

The validation harness's zsmax-ratio gate is ``1e-4`` globally
(``THRESHOLD`` in ``tests/run_validation.sh``). A small number of
production-shaped cases exhibit inherent multi-rank floating-point
non-associativity in the cross-partition wet/dry front propagation
in ``k_compute_fluxes``, which is latched permanently by the
``zsmax`` running max and produces a ratio in the ~1e-4 envelope
that exceeds the global gate. For these cases the harness consults
the ``THRESHOLD_OVERRIDE`` associative array (declared at the top of
``tests/run_validation.sh``) keyed by ``"<case>:<config>"`` — pairs
not in the map fall back to the global threshold. Each existing
override entry has a written diagnosis comment in
``tests/run_validation.sh`` and a deeper write-up in
``docs/diagnostics/multirank-partition-precision-drift.md``; values
sit at ``5e-4`` today (roughly ~5× the freshly-measured residual).

When you add a new GPU case to ``tests/cases/`` and the validation
matrix flags it as a FAIL at the ``1e-4`` global gate, the question
is whether the residual is **inherent** (kernel-level FP
non-associativity on a wet/dry front, latched by ``zsmax``) or a
**real regression** (a bug in your changes). A per-step
CPU↔GPU bisect or a comparison against an older known-good GPU
build is the correct diagnostic path; only after the inherent-FP
diagnosis is recorded should a new override entry be added, with the
freshly-measured ratio and ~5× margin in the comment.

Multi-rank: ``gpu_n1`` vs ``gpu_n2``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``gpu_n2`` (two ranks, two GPUs) is faster than ``gpu_n1`` for cases
large enough that per-step kernel work dominates the per-step MPI
halo exchange overhead; ``gpu_n1`` (one rank, one GPU) is faster for
small cases where MPI launch + halo + ``MPI_Allreduce`` overhead
overshadows the kernel speedup from a second GPU. The crossover is
case-specific and not predictable a priori — when in doubt, run both
configs through the validation harness and pick the faster one.
``gpu_n1`` has a second advantage: it is fully deterministic because
``mpi_size == 1`` short-circuits the cross-rank halo path, so the
multi-rank FP non-associativity envelope (which ``gpu_n2`` is
subject to) does not apply.

The canonical-on-device invariant
---------------------------------

The per-step inner loop in the CUDA build is **canonical on
device**: the device shadows of the SFINCS state arrays hold the
authoritative values across the per-step path; the host shadows are
refreshed only at three sync points (output flush, SnapWave coupling
step, and the feature-boundary flush/pull bracket around
wavemaker / nonhydrostatic / BMI host code). Per-step
``bridge_in_*`` / ``bridge_out_*`` calls in the three per-step
``_gpu.cuf`` files — or bare Fortran whole-array assignments between
a device array and its ``_h`` host shadow in those files — are a
**regression** and are blocked by
``scripts/check-no-per-step-bridges.sh``, which
``source/build_scripts/build_cuda.sh`` runs before every CUDA build.

If you are modifying GPU code, read :doc:`gpu_canonical_on_device`
for the full invariant, the three sync-point definitions, and the
allowlist (``scripts/per-step-bridge-allowlist.txt``) for legitimate
retained per-step bridges. New allowlist entries require a written
justification against the three sync points.

Troubleshooting
---------------

* ``docker: Error response from daemon: could not select device
  driver "" with capabilities: [[gpu]]`` — the NVIDIA Container
  Toolkit is not installed (or the docker daemon was not restarted
  after installing it). Install
  ``nvidia-container-toolkit`` per the NVIDIA documentation, then
  ``systemctl restart docker`` (or your runtime's equivalent).

* ``CUDA driver version is insufficient for CUDA runtime version`` —
  the host NVIDIA driver is older than what CUDA 13.0 (the toolkit
  baked into ``sfincs-build-gpu:latest``) requires. Upgrade the
  host NVIDIA driver to a release that supports CUDA 13.0 (check
  ``nvidia-smi`` and confirm the header line lists "CUDA Version:
  13.x"); no host CUDA toolkit install is required.

* ``mpirun: command not found`` inside the container — the image
  build did not complete, or you are running a stripped image that
  does not include the NVHPC ``comm_libs`` tree. Rebuild via
  ``docker build -f source/build_scripts/Dockerfile_gpu …``.

* ``cudaSetDevice failed: out of memory`` (or any other
  ``cudaErrorMemoryAllocation``) — a sibling GPU process is holding
  the device. Check with ``nvidia-smi`` inside or outside the
  container; the wrapper script ``run_gpu_container.sh`` includes a
  lifecycle trap that forcibly removes its container on SIGTERM /
  exit, but an orphaned container from an earlier session can still
  pin the device. ``docker ps --filter label=sfincs.run-gpu-container``
  finds any wrapper-labelled containers still running.

* ``CUDA-aware MPI not detected — check container PATH`` from
  ``tests/run_validation.sh`` — the harness ran ``ompi_info`` inside
  the container and did not see
  ``opal_built_with_cuda_support=true`` /
  ``opal_cuda_support=true``. This means the container's ``PATH``
  resolved to the non-CUDA-aware OpenMPI at ``comm_libs/mpi/bin``
  instead of HPC-X 2.24 at ``comm_libs/13.0/hpcx/hpcx-2.24/ompi``.
  ``run_gpu_container.sh`` and ``Dockerfile_gpu`` both set the
  HPC-X paths; if you are invoking ``docker run`` directly, mirror
  the ``-e PATH=...`` and ``-e LD_LIBRARY_PATH=...`` lines from
  ``source/build_scripts/run_gpu_container.sh``.

* ``Corrupt or Old Module file`` during a rebuild after switching
  compilers — see the same entry under `Building the GPU container`_.

* ``error = 1`` in the GPU run's ``sfincs.log`` after a successful
  build — the simulation tripped a stability or input-validation
  check. Inspect the surrounding lines in ``sfincs.log`` (the same
  log SFINCS writes on CPU); the GPU build does not have
  GPU-specific error codes, so the diagnosis path is identical to
  the CPU one.

Current limitations
-------------------

* **SnapWave coupling is host-side.** SnapWave consumes the majority
  of wall clock on snapwave-coupled cases (~78 % on
  ``case_prod_compound_snapwave gpu_n2``). The host-side
  characterization in
  ``tests/perf/snapwave-characterization-20260517/SUMMARY.md``
  identified two non-port interventions — ``make_theta_grid``
  memoization and a per-case ``dtwave`` review — that together cover
  the majority of the realisable speedup at a fraction of a
  SnapWave-GPU port's cost. The host-side improvements are the
  active track; a SnapWave-GPU port is not on the current roadmap.

* **No GPU path for the non-CUDA Fortran solvers.** Earlier OpenACC
  GPU builds are no longer produced; the only GPU path today is the
  CUDA Fortran ``--enable-cuda`` build described above.

* **No Singularity-equivalent GPU build.** The GPU path is
  Docker-only. The CPU Singularity path described in
  :doc:`singularity` does not have a GPU counterpart.

* **No pre-built GPU image on Docker Hub.** The ``deltares/sfincs-cpu``
  image on Docker Hub is the CPU-only release; the
  ``sfincs-build-gpu:latest`` image is a development image built
  locally from ``source/build_scripts/Dockerfile_gpu``.
