#!/bin/bash
set -uo pipefail
NRANKS="$1"; shift
GPU_BIN="$1"; shift
OUT_CONTAINER="$1"; shift
HOST_UID="$1"; shift
HOST_GID="$1"; shift

# Install perf (linux-tools-generic provides /usr/lib/linux-tools/*/perf
# which has the right shared-lib closure inside this container's apt
# universe).
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null
apt-get install -y -qq --no-install-recommends linux-tools-generic >/dev/null
# Pick the freshest linux-tools perf installed.
PERF=$(ls /usr/lib/linux-tools-*/perf 2>/dev/null | tail -1)
[ -x "$PERF" ] || { echo "ERROR: no perf installed" >&2; exit 1; }
echo "Installed: $PERF version $($PERF --version 2>/dev/null || echo unknown)"

RANK_WRAP="${OUT_CONTAINER}/rank_select_perf.sh"
cat > "$RANK_WRAP" <<RANK_EOF
#!/bin/bash
R="\${OMPI_COMM_WORLD_RANK:-0}"
if [ "\$R" = "0" ]; then
  exec "$PERF" record -F 999 --call-graph dwarf,16384 \\
      -o "${OUT_CONTAINER}/snapwave_perf.data" \\
      -- "$GPU_BIN"
else
  exec "$GPU_BIN"
fi
RANK_EOF
chmod +x "$RANK_WRAP"

mpirun --allow-run-as-root -n "$NRANKS" "$RANK_WRAP"
RC=$?

# Now generate the perf-report .txt files while perf is still around;
# do it from inside the container so the same perf+symbols line up.
if [ -f "${OUT_CONTAINER}/snapwave_perf.data" ]; then
    cd "${OUT_CONTAINER}"
    "$PERF" report -i snapwave_perf.data --stdio --sort=overhead,symbol         --percent-limit 0.5 > snapwave_perf_report.txt 2>&1 || true
    "$PERF" report -i snapwave_perf.data --stdio --no-children         --sort=overhead,symbol --percent-limit 0.5 > snapwave_perf_flat.txt 2>&1 || true
    "$PERF" report -i snapwave_perf.data --stdio --no-children         -g graph,0.5,callee --percent-limit 1.0 > snapwave_perf_callgraph.txt 2>&1 || true
fi

# chown all output files to the host user.
chown -R "$HOST_UID:$HOST_GID" "${OUT_CONTAINER}" 2>/dev/null || true

exit $RC
