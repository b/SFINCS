#!/bin/sh
set -e

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
IMAGE=${SFINCS_GPU_IMAGE:-sfincs-build-gpu:latest}

if [ "$#" -eq 0 ]; then
    set -- bash
fi

TTY_FLAG=
if [ -t 0 ]; then
    TTY_FLAG=-it
fi

exec docker run --rm $TTY_FLAG \
    --gpus all \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    -v "$REPO_ROOT":/work \
    -w /work \
    "$IMAGE" "$@"
