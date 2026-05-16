#!/bin/sh
set -e

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
IMAGE=${SFINCS_GPU_IMAGE:-sfincs-build-gpu:latest}

if [ "$#" -eq 0 ]; then
    set -- bash
fi

# Singleton-mode mpi_init under HPCX OMPI hangs in this container, so a
# bare invocation of the sfincs binary is automatically launched via
# `mpirun -n 1`. Explicit mpirun / build / shell commands pass through.
case "$1" in
    */sfincs|sfincs)
        set -- mpirun --allow-run-as-root -n 1 "$@"
        ;;
esac

TTY_FLAG=
if [ -t 0 ]; then
    TTY_FLAG=-it
fi

# HPC-X 2.24 (CUDA-aware OpenMPI + UCX + sharp + hcoll) ships under NVHPC
# 25.9 but is NOT on the container's default PATH; the default mpirun at
# comm_libs/mpi/bin/mpirun is a non-CUDA-aware OpenMPI build that silently
# stages every device-pointer MPI buffer through pinned host memory via
# UVA page faults, saturating one CPU thread and stalling the GPU on every
# halo exchange. Prepending HPC-X's ompi/ucx/sharp/hcoll paths puts the
# CUDA-aware mpirun first so MPI_Isend(device_ptr, ...) takes the
# GPUDirect / cuda_copy fast path.
HPCX_ROOT=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/comm_libs/13.0/hpcx/hpcx-2.24
HPCX=$HPCX_ROOT/ompi

# Container lifecycle is tied to this shell. Earlier versions of this
# script did `exec docker run --rm ...`, which left no shell behind to
# clean up — `--rm` only fires on container *exit*, so a deadlocked
# container that ignores SIGTERM (e.g. an MPI/CUDA child stuck in a
# kernel) was orphaned indefinitely once the invoking session died,
# pegging GPUs and a CPU core. We now launch docker run as a child,
# install a cleanup trap, and `wait` so the trap survives to fire.
CONTAINER_NAME="sfincs-build-gpu-$$-$(date +%s 2>/dev/null || echo 0)"
LIFECYCLE_LABEL="sfincs.run-gpu-container=$$"

cleanup() {
    # docker kill (SIGKILL) is intentional: a deadlocked container by
    # definition ignores SIGTERM, so docker stop / signal-forwarding
    # would not unstick it. docker rm -f is a belt-and-braces because
    # the --rm reaper only runs after a clean exit; if the container
    # raced past it (or was already gone) the second call is a no-op.
    docker kill "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

# --init installs tini as PID 1 inside the container so signals are
# reaped/forwarded properly; without it mpirun would be PID 1 and
# mishandle SIGTERM. --rm is retained so the clean-exit path still
# removes the container (the trap above only kicks in for the
# signal / hang paths). --label is a session-scoped key an external
# reaper can use to find and force-kill orphaned containers without
# touching the deterministic --name.
docker run --rm --init $TTY_FLAG \
    --name "$CONTAINER_NAME" \
    --label "$LIFECYCLE_LABEL" \
    --gpus all \
    --ipc=host \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    -e OPAL_PREFIX="$HPCX" \
    -e PATH="$HPCX/bin:$HPCX_ROOT/ucx/bin:/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/compilers/bin:/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    -e LD_LIBRARY_PATH="$HPCX/lib:$HPCX_ROOT/ucx/lib:$HPCX_ROOT/sharp/lib:$HPCX_ROOT/hcoll/lib:/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/compilers/lib:/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/math_libs/lib64:/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/cuda/lib64" \
    -e SFINCS_PREFIX="${SFINCS_PREFIX:-}" \
    -v "$REPO_ROOT":/work \
    -w /work \
    "$IMAGE" "$@" &
DOCKER_PID=$!

# `set -e` would abort us on a non-zero wait, which is the normal way
# of propagating the container's exit code; guard with an if so the
# wrapper's exit status mirrors `docker run`'s.
if wait "$DOCKER_PID"; then
    RC=0
else
    RC=$?
fi
exit $RC
