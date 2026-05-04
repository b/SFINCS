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

HPCX=/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/comm_libs/13.0/hpcx/hpcx-2.24/ompi

exec docker run --rm $TTY_FLAG \
    --gpus all \
    --ipc=host \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    -e OPAL_PREFIX="$HPCX" \
    -e PATH="$HPCX/bin:/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/compilers/bin:/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    -e LD_LIBRARY_PATH="$HPCX/lib:/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/compilers/lib:/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/math_libs/lib64:/opt/nvidia/hpc_sdk/Linux_x86_64/25.9/cuda/lib64" \
    -v "$REPO_ROOT":/work \
    -w /work \
    "$IMAGE" "$@"
