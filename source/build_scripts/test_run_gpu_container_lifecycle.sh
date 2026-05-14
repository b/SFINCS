#!/bin/bash
# Integration test for source/build_scripts/run_gpu_container.sh.
#
# Verifies the GPU dev container started by the wrapper is reaped under:
#   1) SIGTERM to the invoking process
#   2) SIGINT  to the invoking process
#   3) Clean exit (--rm path)
#
# In every case, no container with the wrapper's session-scoped label
# may remain in `docker ps -a` after the wrapper returns.
#
# Requires Docker with --gpus all available and the sfincs-build-gpu
# image present locally; the test SKIPs (exit 0) otherwise so it can
# be wired into a developer test sweep on non-GPU hosts without false
# failures. Run on the GPU dev box for real coverage.
set -u
# Enable job control so async children run in their own process group
# and inherit SIGINT with default disposition. Non-interactive bash
# without job control sets SIGINT to SIG_IGN on backgrounded children
# (to keep them alive past a terminal Ctrl-C), and an inherited SIG_IGN
# cannot be overridden by `trap` in the child — so the wrapper's INT
# trap would never fire. `set -m` mirrors the realistic case where a
# user runs the wrapper from an interactive shell, where SIGINT to the
# foreground process group runs the trap.
set -m

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
WRAPPER="$SCRIPT_DIR/run_gpu_container.sh"
IMAGE=${SFINCS_GPU_IMAGE:-sfincs-build-gpu:latest}
LABEL_KEY="sfincs.run-gpu-container"

if [ ! -x "$WRAPPER" ]; then
    echo "FAIL: $WRAPPER not found or not executable"
    exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
    echo "SKIP: docker not on PATH"
    exit 0
fi
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "SKIP: image $IMAGE not present locally"
    exit 0
fi

FAILED=0

wait_for_container_present() {
    local wrapper_pid=$1
    local timeout=$2
    local elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        if [ -n "$(docker ps -q --filter "label=${LABEL_KEY}=${wrapper_pid}" 2>/dev/null)" ]; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    return 1
}

wait_for_process_gone() {
    local pid=$1
    local timeout=$2
    local elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        if ! kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    return 1
}

assert_no_container_left() {
    local label=$1
    local timeout=$2
    local elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        local remaining
        remaining=$(docker ps -aq --filter "label=$label" 2>/dev/null | wc -l)
        if [ "$remaining" -eq 0 ]; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    echo "    leftover containers for label=$label:"
    docker ps -a --filter "label=$label"
    return 1
}

reap_remaining() {
    local label=$1
    local ids
    ids=$(docker ps -aq --filter "label=$label" 2>/dev/null)
    if [ -n "$ids" ]; then
        # shellcheck disable=SC2086
        docker rm -f $ids >/dev/null 2>&1 || true
    fi
}

run_signal_case() {
    local signame=$1
    echo "==> Test: ${signame} delivery cleans up container"

    "$WRAPPER" sleep 600 </dev/null >/dev/null 2>&1 &
    local wrapper_pid=$!

    if ! wait_for_container_present "$wrapper_pid" 45; then
        echo "FAIL: container with label ${LABEL_KEY}=${wrapper_pid} never appeared within 45s"
        kill -KILL "$wrapper_pid" 2>/dev/null || true
        wait "$wrapper_pid" 2>/dev/null || true
        reap_remaining "${LABEL_KEY}=${wrapper_pid}"
        return 1
    fi

    kill -"$signame" "$wrapper_pid"
    if ! wait_for_process_gone "$wrapper_pid" 30; then
        echo "FAIL: wrapper PID $wrapper_pid did not exit within 30s after ${signame}"
        kill -KILL "$wrapper_pid" 2>/dev/null || true
        wait "$wrapper_pid" 2>/dev/null || true
        reap_remaining "${LABEL_KEY}=${wrapper_pid}"
        return 1
    fi
    wait "$wrapper_pid" 2>/dev/null || true

    if ! assert_no_container_left "${LABEL_KEY}=${wrapper_pid}" 20; then
        echo "FAIL: ${signame} case left a container behind"
        reap_remaining "${LABEL_KEY}=${wrapper_pid}"
        return 1
    fi
    echo "    OK: ${signame} case clean"
    return 0
}

run_clean_exit_case() {
    echo "==> Test: clean exit (--rm path) leaves no container"

    "$WRAPPER" true </dev/null >/dev/null 2>&1 &
    local wrapper_pid=$!

    if ! wait_for_process_gone "$wrapper_pid" 90; then
        echo "FAIL: wrapper PID $wrapper_pid did not exit within 90s on clean run"
        kill -KILL "$wrapper_pid" 2>/dev/null || true
        wait "$wrapper_pid" 2>/dev/null || true
        reap_remaining "${LABEL_KEY}=${wrapper_pid}"
        return 1
    fi
    wait "$wrapper_pid" 2>/dev/null || true

    if ! assert_no_container_left "${LABEL_KEY}=${wrapper_pid}" 20; then
        echo "FAIL: clean-exit case left a container behind"
        reap_remaining "${LABEL_KEY}=${wrapper_pid}"
        return 1
    fi
    echo "    OK: clean-exit case clean"
    return 0
}

run_signal_case TERM || FAILED=1
run_signal_case INT  || FAILED=1
run_clean_exit_case  || FAILED=1

if [ "$FAILED" -eq 0 ]; then
    echo "PASS: all run_gpu_container.sh lifecycle cases"
    exit 0
fi
echo "FAIL: at least one run_gpu_container.sh lifecycle case leaked a container"
exit 1
