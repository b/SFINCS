#!/bin/bash
# SOR-87 — CPU-vs-GPU performance matrix with full-cores CPU baseline.
#
# Runs each production case under three configurations:
#   * cpu_nN  — gfortran/OpenMP CPU build, OMP_NUM_THREADS=N
#               where N = $(nproc) at run time. Single process.
#               SFINCS's CPU build supports OpenMP only (MPI calls in
#               source/src/ are gated on USE_CUDA in
#               source/src/sfincs_lib.F90), so the "MPI with N ranks"
#               wording of SOR-87 AC is satisfied via OpenMP — the
#               AC's "(or equivalent — count host's available cores
#               via nproc/lscpu at run time)" clause grants this
#               substitution. The intent — fair-comparison CPU
#               baseline at full-hardware parallelism — is met.
#   * gpu_n1  — CUDA build, mpirun -n 1 inside sfincs-build-gpu container.
#   * gpu_n2  — CUDA build, mpirun -n 2 inside sfincs-build-gpu container.
#
# Each (case, config) is run twice, once against the "post-fix" build
# (this branch, with the full SOR-65..SOR-86 canonical-on-device +
# SnapWave memoization stack landed) and once against a "pre-fix"
# build at commit d1b84c1 (the Phase-0 NVTX-annotated commit that
# immediately precedes SOR-65 Phase 1 zs-device-canonical refactor),
# reusing SOR-69's /tmp/sfincs-pre-phase1-baseline sibling-worktree
# pattern (see tests/perf/phase5-canonical-on-device-final-20260517/
# run_byte_identical_check.sh).
#
# Captured per (case, config, rev) into
# tests/perf/perf-matrix-20260518/<case>__<config>__<rev>/:
#   * sfincs.log              — SFINCS run log incl. timing summary
#   * sfincs.stdout           — mpirun / OMP stdout
#   * nvidia_smi_dmon.txt     — GPU dmon snapshot (gpu_* only)
#   * wall_seconds.txt        — wall clock from sfincs.log "Total time"
#
# Top-level outputs:
#   * SUMMARY.md              — pre/post wall + speedup matrix
#   * capture_env.txt         — host CPU / GPU / nproc / commit metadata
#   * run.stdout              — orchestration log
#
# Usage (from repo root, AFTER pre-fix GPU binary at
# /tmp/sfincs-pre-phase1-baseline/source/install_cuda/bin/sfincs has
# been built — by SOR-69's run_byte_identical_check.sh — or the
# script will build it lazily):
#
#     tests/perf/perf-matrix-20260518/run_perf_matrix.sh         # full matrix
#     tests/perf/perf-matrix-20260518/run_perf_matrix.sh --case case_meteo  # one case
#     tests/perf/perf-matrix-20260518/run_perf_matrix.sh --skip-build       # reuse cached binaries
#     tests/perf/perf-matrix-20260518/run_perf_matrix.sh --post-only        # skip pre-fix
#
# Build cost: ~5-10 min CPU + ~10-15 min GPU per build; per-case run
# cost depends on case size (~30 s for case_meteo up to a few minutes
# for case_prod_compound_snapwave).

set -uo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
OUT_DIR=$(cd "$(dirname "$0")" && pwd)
PRE_PHASE1_COMMIT=d1b84c1
PRE_TREE=${SFINCS_PHASE5_BASELINE_WORKTREE:-/tmp/sfincs-pre-phase1-baseline}

CPU_BIN_POST=$REPO_ROOT/source/install_cpu/bin/sfincs
GPU_BIN_POST_HOST=$REPO_ROOT/source/install_cuda/bin/sfincs
CPU_BIN_PRE=$PRE_TREE/source/install_cpu/bin/sfincs
GPU_BIN_PRE_HOST=$PRE_TREE/source/install_cuda/bin/sfincs

GPU_WRAPPER=$REPO_ROOT/source/build_scripts/run_gpu_container.sh

# Production case set per SOR-87 BODY. Implementer judgment: include
# only the prod_* set; smaller cases were called out as "optional" in
# the issue body. Single-shape AC ("the production case set from
# tests/run_validation.sh") is honored.
CASES_DEFAULT=(
    case_prod_regular_tide
    case_prod_quadtree_subgrid_tide
    case_prod_riverine
    case_prod_storm_amuv
    case_prod_compound_snapwave
)

# --- Argument parsing -------------------------------------------------------

SELECTED_CASES=()
SKIP_BUILD=0
POST_ONLY=0
while [ $# -gt 0 ]; do
    case "$1" in
        --case) SELECTED_CASES+=("$2"); shift ;;
        --skip-build) SKIP_BUILD=1 ;;
        --post-only) POST_ONLY=1 ;;
        -h|--help) sed -n '2,50p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done
if [ ${#SELECTED_CASES[@]} -eq 0 ]; then
    CASES=("${CASES_DEFAULT[@]}")
else
    CASES=("${SELECTED_CASES[@]}")
fi

# --- Environment fingerprint ------------------------------------------------

NPROC=$(nproc)
HOST_CPU=$(lscpu | awk -F: '/^Model name/ {gsub(/^ +/, "", $2); print $2; exit}')
PHYSICAL_CORES=$(lscpu | awk -F: '/^Core\(s\) per socket/ {gsub(/^ +/, "", $2); cps=$2} /^Socket\(s\)/ {gsub(/^ +/, "", $2); s=$2} END {print s*cps}')
GPU_MODEL=$(nvidia-smi -L 2>/dev/null | head -1 | sed -E 's/^GPU [0-9]+: //; s/ \(UUID:.*//')
NGPU=$(nvidia-smi -L 2>/dev/null | wc -l)
POST_REV=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)

cat > "$OUT_DIR/capture_env.txt" <<EOF
SOR-87 perf matrix capture environment
======================================
host CPU         : $HOST_CPU
physical cores   : $PHYSICAL_CORES
logical CPUs     : $NPROC  (nproc; SMT counts both threads)
host GPU         : $GPU_MODEL  x$NGPU
container image  : sfincs-build-gpu:latest
post-fix HEAD    : $POST_REV ($(git -C "$REPO_ROOT" rev-parse HEAD))
pre-fix commit   : $PRE_PHASE1_COMMIT (Phase-0 NVTX-annotated; pre SOR-65 zs-device-canonical)
pre-fix worktree : $PRE_TREE
captured-at      : $(date -u +%Y-%m-%dT%H:%M:%SZ)

cpu_n${NPROC} mapping rationale
------------------------------
SFINCS's CPU build supports OpenMP (-fopenmp) and not MPI; MPI calls
in source/src/sfincs_lib.F90 are gated on USE_CUDA (only the CUDA
build links mpifort, per source/configure.ac). The SOR-87 AC reads
"mpirun -n \$(nproc) (or equivalent — count host's available cores
via nproc/lscpu at run time)"; the equivalent for SFINCS's CPU build
is OMP_NUM_THREADS=\$(nproc). cpu_n$NPROC below means
OMP_NUM_THREADS=$NPROC, single process. The "fair-comparison at full
parallelism" intent is preserved.
EOF

LOG=$OUT_DIR/run.stdout
exec > >(tee -a "$LOG") 2>&1
echo "=== SOR-87 perf matrix — start $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo "cases: ${CASES[*]}"
echo "nproc: $NPROC  (cpu_n$NPROC)"

# --- Helpers ----------------------------------------------------------------

host_to_container() {
    local p=$1
    case "$p" in
        "$REPO_ROOT") echo "/work" ;;
        "$REPO_ROOT"/*) echo "/work${p#"$REPO_ROOT"}" ;;
        *) echo "host_to_container: '$p' outside REPO_ROOT" >&2; exit 1 ;;
    esac
}

# Stage a case dir into a clean run dir; copy sfincs.inp (may be edited
# per-run if needed); symlink the rest. README.md / fetch.sh / generate.py
# are skipped.
stage_case() {
    local case_dir=$1 run_dir=$2
    mkdir -p "$run_dir"
    find "$run_dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    local entry base
    for entry in "$case_dir"/*; do
        [ -e "$entry" ] || continue
        base=$(basename "$entry")
        case "$base" in
            README.md|fetch.sh|generate.py) ;;
            sfincs.inp) cp -- "$entry" "$run_dir/$base" ;;
            *) ln -srf -- "$entry" "$run_dir/$base" ;;
        esac
    done
}

# Same as stage_case but copies all files (not symlinks). Needed when
# the run dir is inside a sibling worktree whose docker mount differs
# from the symlink target's host path.
stage_case_copy() {
    local case_dir=$1 run_dir=$2
    mkdir -p "$run_dir"
    find "$run_dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    local entry base
    for entry in "$case_dir"/*; do
        [ -e "$entry" ] || continue
        base=$(basename "$entry")
        case "$base" in
            README.md|fetch.sh|generate.py) ;;
            *) cp -L -- "$entry" "$run_dir/$base" ;;
        esac
    done
}

# Extract total wall and per-component timings from sfincs.log into a
# small whitespace-delimited file consumed by the SUMMARY generator.
# Component lines look like " Time in boundaries     :      0.702 ( 17.7%)";
# pull the first decimal number that follows the ":" so the extractor
# doesn't index by field count (which differs between the two-line
# "Total time : XX.XXX" rows and the multi-component "Time in X : VAL ( P%)"
# rows). The Total / Simulation rows use the same regex.
extract_timings() {
    local log=$1 out=$2
    local re='[0-9]+[.][0-9]+'
    pull() {
        local pattern=$1
        awk -v re="$re" -v pat="$pattern" '
            $0 ~ pat {
                # Trim everything up to and including the first ":".
                s = $0
                p = index(s, ":")
                if (p > 0) s = substr(s, p+1)
                if (match(s, re)) {
                    print substr(s, RSTART, RLENGTH)
                    found = 1
                    exit
                }
            }
            END { if (!found) print "" }
        ' "$log"
    }
    {
        echo "total $(pull '^[[:space:]]*Total time[[:space:]]*:')"
        echo "simulation $(pull '^[[:space:]]*Total simulation time[[:space:]]*:')"
        echo "input $(pull '^[[:space:]]*Time in input[[:space:]]*:')"
        echo "boundaries $(pull '^[[:space:]]*Time in boundaries[[:space:]]*:')"
        echo "momentum $(pull '^[[:space:]]*Time in momentum[[:space:]]*:')"
        echo "continuity $(pull '^[[:space:]]*Time in continuity[[:space:]]*:')"
        echo "snapwave $(pull '^[[:space:]]*Time in SnapWave[[:space:]]*:')"
        echo "meteo $(pull '^[[:space:]]*Time in meteo forcing[[:space:]]*:')"
        echo "output $(pull '^[[:space:]]*Time in output[[:space:]]*:')"
        echo "avg_dt $(pull '^[[:space:]]*Average time step')"
    } > "$out"
}

# --- Build steps ------------------------------------------------------------

build_cpu_at() {
    local tree=$1 label=$2
    echo "=== [$label] building CPU (gfortran/OpenMP) at $tree ==="
    # Wipe stale .mod / .o so the gfortran build doesn't trip on
    # nvfortran .mod files from a prior CUDA build in the same tree.
    for sub in src third_party_open; do
        find "$tree/source/$sub" -type f \
            \( -name '*.mod' -o -name '*.o' -o -name '*.lo' \
               -o -name '*.a' -o -name '*.la' \) -delete 2>/dev/null || true
    done
    (
        cd "$tree/source"
        autoreconf -ivf
        ./autogen.sh
        ./configure FC=gfortran \
            FCFLAGS="-fopenmp -O3 -fallow-argument-mismatch -w" \
            FFLAGS="-fopenmp -O3 -fallow-argument-mismatch -w" \
            --disable-shared \
            --prefix="$PWD/install_cpu"
        make
        make install
    )
}

build_gpu_at() {
    local tree=$1 label=$2
    echo "=== [$label] building GPU (nvfortran) at $tree ==="
    for sub in src third_party_open; do
        find "$tree/source/$sub" -type f \
            \( -name '*.mod' -o -name '*.o' -o -name '*.lo' \
               -o -name '*.a' -o -name '*.la' \) -delete 2>/dev/null || true
    done
    (
        cd "$tree"
        source/build_scripts/run_gpu_container.sh source/build_scripts/build_cuda.sh
    )
}

ensure_post_builds() {
    if [ "$SKIP_BUILD" -ne 1 ] || [ ! -x "$CPU_BIN_POST" ]; then
        build_cpu_at "$REPO_ROOT" post
    fi
    if [ "$SKIP_BUILD" -ne 1 ] || [ ! -x "$GPU_BIN_POST_HOST" ]; then
        build_gpu_at "$REPO_ROOT" post
    fi
    [ -x "$CPU_BIN_POST" ] || { echo "ERROR: $CPU_BIN_POST not built" >&2; exit 3; }
    [ -x "$GPU_BIN_POST_HOST" ] || { echo "ERROR: $GPU_BIN_POST_HOST not built" >&2; exit 3; }
}

ensure_pre_builds() {
    [ "$POST_ONLY" -eq 1 ] && return 0
    if [ ! -d "$PRE_TREE" ]; then
        echo "=== creating pre-fix worktree at $PRE_TREE for $PRE_PHASE1_COMMIT ==="
        git -C "$REPO_ROOT" worktree add --detach "$PRE_TREE" "$PRE_PHASE1_COMMIT"
    fi
    if [ ! -x "$CPU_BIN_PRE" ]; then
        build_cpu_at "$PRE_TREE" pre
    fi
    if [ ! -x "$GPU_BIN_PRE_HOST" ]; then
        build_gpu_at "$PRE_TREE" pre
    fi
    [ -x "$CPU_BIN_PRE" ] || { echo "ERROR: $CPU_BIN_PRE not built" >&2; exit 4; }
    [ -x "$GPU_BIN_PRE_HOST" ] || { echo "ERROR: $GPU_BIN_PRE_HOST not built" >&2; exit 4; }
}

# --- Run steps --------------------------------------------------------------

run_cpu_one() {
    local case_name=$1 case_dir=$2 cpu_bin=$3 rev=$4
    local run_dir=$OUT_DIR/${case_name}__cpu_n${NPROC}__${rev}
    stage_case "$case_dir" "$run_dir"
    echo "--- [$rev] cpu_n$NPROC $case_name ---"
    local wall_start wall_end rc
    wall_start=$(date +%s)
    set +e
    (
        cd "$run_dir"
        OMP_NUM_THREADS=$NPROC OMP_DYNAMIC=false OMP_PROC_BIND=true \
            "$cpu_bin" >sfincs.log 2>sfincs.stdout
    )
    rc=$?
    set -e
    wall_end=$(date +%s)
    echo "    rc=$rc wall=$((wall_end - wall_start))s log=$run_dir/sfincs.log"
    extract_timings "$run_dir/sfincs.log" "$run_dir/timings.txt"
}

run_gpu_one() {
    local case_name=$1 case_dir=$2 nranks=$3 rev=$4
    local cfg=gpu_n$nranks
    local run_dir=$OUT_DIR/${case_name}__${cfg}__${rev}
    # The container mounts $REPO_ROOT at /work, so the run dir under
    # tests/perf/perf-matrix-... is reachable for the post-fix run via
    # symlinks. For the pre-fix run we use the GPU binary at PRE_TREE
    # but a run dir under this repo; the container also has PRE_TREE
    # mounted because we bind it as /work via PRE_TREE's own wrapper.
    if [ "$rev" = "pre" ]; then
        # Run inside PRE_TREE's container using its wrapper so /work
        # points at PRE_TREE. Stage case data INTO PRE_TREE so symlinks
        # don't escape the mount.
        local pre_run_dir=$PRE_TREE/tests/perf/perf-matrix-20260518/${case_name}__${cfg}__pre
        stage_case_copy "$case_dir" "$pre_run_dir"
        local container_run_dir=/work/tests/perf/perf-matrix-20260518/${case_name}__${cfg}__pre
        local container_bin=/work/source/install_cuda/bin/sfincs
        echo "--- [pre] gpu_n$nranks $case_name ---"
        local wall_start wall_end rc
        wall_start=$(date +%s)
        # Capture nvidia-smi dmon in background, against host nvidia-smi.
        nvidia-smi dmon -i 0,1 -d 1 -c 1000000 \
            -s u 2>&1 > "$pre_run_dir/nvidia_smi_dmon.txt" &
        local dmon_pid=$!
        set +e
        "$PRE_TREE/source/build_scripts/run_gpu_container.sh" \
            mpirun --allow-run-as-root --wdir "$container_run_dir" \
            -n "$nranks" "$container_bin" \
            >"$pre_run_dir/sfincs.stdout" 2>&1
        rc=$?
        set -e
        kill "$dmon_pid" 2>/dev/null || true
        wait "$dmon_pid" 2>/dev/null || true
        wall_end=$(date +%s)
        mkdir -p "$run_dir"
        cp -f "$pre_run_dir/sfincs.log" "$run_dir/sfincs.log" 2>/dev/null || true
        cp -f "$pre_run_dir/sfincs.stdout" "$run_dir/sfincs.stdout" 2>/dev/null || true
        cp -f "$pre_run_dir/nvidia_smi_dmon.txt" "$run_dir/nvidia_smi_dmon.txt" 2>/dev/null || true
        echo "    rc=$rc wall=$((wall_end - wall_start))s log=$run_dir/sfincs.log"
        extract_timings "$run_dir/sfincs.log" "$run_dir/timings.txt"
        # Tidy: the pre-tree staged copy lives only to provide a valid
        # mount-rooted CWD; the canonical artifacts are now in $run_dir.
        rm -rf "$pre_run_dir"
    else
        stage_case "$case_dir" "$run_dir"
        local container_run_dir
        container_run_dir=$(host_to_container "$run_dir")
        local container_bin=/work/source/install_cuda/bin/sfincs
        echo "--- [post] gpu_n$nranks $case_name ---"
        local wall_start wall_end rc
        wall_start=$(date +%s)
        nvidia-smi dmon -i 0,1 -d 1 -c 1000000 \
            -s u 2>&1 > "$run_dir/nvidia_smi_dmon.txt" &
        local dmon_pid=$!
        set +e
        "$GPU_WRAPPER" \
            mpirun --allow-run-as-root --wdir "$container_run_dir" \
            -n "$nranks" "$container_bin" \
            >"$run_dir/sfincs.stdout" 2>&1
        rc=$?
        set -e
        kill "$dmon_pid" 2>/dev/null || true
        wait "$dmon_pid" 2>/dev/null || true
        wall_end=$(date +%s)
        echo "    rc=$rc wall=$((wall_end - wall_start))s log=$run_dir/sfincs.log"
        extract_timings "$run_dir/sfincs.log" "$run_dir/timings.txt"
    fi
}

# --- Main -------------------------------------------------------------------

ensure_post_builds
ensure_pre_builds

REVS=(post)
[ "$POST_ONLY" -ne 1 ] && REVS=(post pre)

for case_name in "${CASES[@]}"; do
    case_dir=$REPO_ROOT/tests/cases/$case_name
    if [ ! -f "$case_dir/sfincs.inp" ]; then
        echo "SKIP $case_name — no sfincs.inp (input not fetched?)"
        continue
    fi
    echo
    echo "===== case: $case_name ====="
    for rev in "${REVS[@]}"; do
        case "$rev" in
            post) cpu_bin=$CPU_BIN_POST ;;
            pre)  cpu_bin=$CPU_BIN_PRE ;;
        esac
        run_cpu_one "$case_name" "$case_dir" "$cpu_bin" "$rev"
        run_gpu_one "$case_name" "$case_dir" 1 "$rev"
        run_gpu_one "$case_name" "$case_dir" 2 "$rev"
    done
done

echo
echo "=== SOR-87 perf matrix — complete $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
