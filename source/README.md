# Running SFINCS

You can run sfincs using the `sfincs` command. It assumes the input file are in the current working directory. This assumes the sfincs executable is in your path and the corresponding libraries are in the library path (the directory containing the libraries should be in the `LD_LIBRARY_PATH` variable in linux, in `DYLD_LIBRARY_PATH` under OSX).

``` shell
    $ sfincs
```

You can also run sfincs using a docker container. For docker we have two versions, the cpu version (compiled with gfortran) and the gpu version (compiled with the nvidia hpc sdk).

``` shell
    $ docker pull deltares/sfincs-cpu
    $ docker run -v$(pwd):/data deltares/sfincs-cpu
```

If you are on a cluster that supports singularity, you can start sfincs using the singularity run command.

``` shell
    $ singularity run -B$(pwd):/data --nv docker://deltares/sfincs-gpu
```

## CUDA-aware MPI in the GPU dev container

The `sfincs-build-gpu:latest` image (built from `source/build_scripts/Dockerfile_gpu`) is based on NVIDIA HPC SDK 25.9, whose `comm_libs/` tree carries a CUDA-aware HPC-X 2.24 OpenMPI build at `comm_libs/13.0/hpcx/hpcx-2.24/` and exposes a second mpirun at `comm_libs/mpi/bin/mpirun` (in NVHPC 25.9 the `comm_libs/mpi` path is a symlink wrapper that resolves to HPC-X, but downstream image rebuilds, custom clusters, or future NVHPC versions can re-introduce a separately-built non-CUDA-aware OpenMPI under that path). The image's `ENV PATH` / `ENV LD_LIBRARY_PATH` / `ENV OPAL_PREFIX` and the `source/build_scripts/run_gpu_container.sh` wrapper both prepend the HPC-X paths so multi-rank GPU runs always resolve to the CUDA-aware mpirun. **Always launch GPU runs through `run_gpu_container.sh`** (or set the same env on a bare `docker run`); the SFINCS GPU binary passes device pointers directly to `MPI_Isend` on every halo exchange (see `source/src/sfincs_partition.cuf` `halo_exchange_q_uv` / `halo_exchange_cells`), so an MPI without CUDA-aware transports does not silently stage them — it SIGSEGVs at the first halo exchange inside `MPI_Isend → uct_mm_ep_am_short` with `invalid permissions for mapped object` (reproducible via `tests/perf/run_perf.sh force-non-cuda-aware`; see `tests/perf/FINDINGS.md`). SFINCS prints `CUDA-aware MPI: yes` on rank 0 at startup when CUDA-aware MPI is detected; a `WARNING: MPI is not CUDA-aware` line on a multi-rank GPU run means the PATH is wrong and the run is about to crash. The validation and benchmark harnesses (`tests/run_validation.sh`, `tests/run_benchmarks.sh`) also probe `ompi_info` before launching simulations and refuse to proceed if `opal_built_with_cuda_support` is not `true`.

# Building the linux version

Make sure you have the following tools installed:
- compiler (gnu fortran or intel for CPU only, nvidia HPC SDK for GPU version)
- autotools (autoconf, automake, libtool, m4, make, also collectively available as build-essentials in many linux distributions)

This is a short summary of the installation and building procedure. See the general INSTALL file for detailed instructions.

To prepare the source code directory for building you need to run autoreconf once like this:

```
    $ autoreconf -vif
```

At this point you should be able to build the software. Please consult `./configure --help` for extra options, such as compiler selection (`FC=gfortran`) and the install location (`--prefix`). If you want to use openmp and openacc the options are checked against the corresponding C compiler. So if you change the compiler make sure you also spcify the corresponding C compiler (for example CC=gcc FC=gfortran or CC=nvc FC=nvfortran). You might need to pass `--with-pic` or `--disable-shared` on certain platforms.

```
    $ ./configure
    $ make
```

This should give you an sfincs executable in the src directory and a libsfincs.la that you can link to.
To install it into your system you can use make install.

```
    $ make install
```

See the [autobook](https://www.sourceware.org/autobook/autobook/autobook_toc.html) for documentation on the build system.
