#!/bin/bash
# SOR-1019 — pre-fix baseline capture for the post-continuity cell-halo
# coalescing. Runs the SAME measurement cells as run_verify.sh against
# the pre-stash HEAD (before this PR's source changes were applied), so
# the post-fix run_verify.sh can diff sfincs_map.nc byte-for-byte and
# compare timings against a captured baseline rather than against the
# committed SOR-1018 verify-4d artifacts (which do not include
# sfincs_map.nc, and do not cover the subgrid case at all).
#
# Workflow:
#   1. git stash push to revert the worktree to HEAD (pre-fix).
#   2. Build the GPU binary at pre-fix (run_gpu_container.sh build_cuda.sh).
#   3. Invoke this script. It writes to tests/perf/halo-exchange-cells-coalesce-20260519/prefix/.
#   4. git stash pop, rebuild, run run_verify.sh.

set -uo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
HARNESS_DIR=$(cd "$(dirname "$0")" && pwd)
OUT_DIR=$HARNESS_DIR/prefix
GPU_BIN_HOST=$REPO_ROOT/source/install_cuda/bin/sfincs
GPU_WRAPPER=$REPO_ROOT/source/build_scripts/run_gpu_container.sh

mkdir -p "$OUT_DIR"
LOG=$OUT_DIR/run.stdout
exec > >(tee "$LOG") 2>&1
echo "=== SOR-1019 baseline (pre-fix) — start $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo "HEAD: $(git -C "$REPO_ROOT" rev-parse --short HEAD) ($(git -C "$REPO_ROOT" log -1 --format=%s HEAD))"
[ -x "$GPU_BIN_HOST" ] || { echo "ERROR: $GPU_BIN_HOST not built" >&2; exit 3; }

host_to_container() {
    local p=$1
    case "$p" in
        "$REPO_ROOT") echo "/work" ;;
        "$REPO_ROOT"/*) echo "/work${p#"$REPO_ROOT"}" ;;
        *) echo "host_to_container: '$p' outside REPO_ROOT" >&2; exit 1 ;;
    esac
}
tstop_for() { case "$1" in
    1h) echo "20200101 010000";; 6h) echo "20200101 060000";;
    24h) echo "20200102 000000";; 4d) echo "20200105 000000";;
    *) exit 3;; esac; }
sim_seconds_for() { case "$1" in
    1h) echo 3600;; 6h) echo 21600;; 24h) echo 86400;; 4d) echo 345600;;
    *) echo 0;; esac; }

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
rewrite_tstop() {
    awk -v ts="$2" '$1=="tstop"{sub(/=.*/,"= " ts)} {print}' \
        "$1/sfincs.inp" > "$1/sfincs.inp.new"
    mv "$1/sfincs.inp.new" "$1/sfincs.inp"
}

extract_timings() {
    local log=$1 out=$2 sim_seconds=$3
    local re='[0-9]+[.][0-9]+'
    pull() { awk -v re="$re" -v pat="$1" '
        $0 ~ pat { s=$0; p=index(s,":"); if(p>0)s=substr(s,p+1)
                   if(match(s,re)){print substr(s,RSTART,RLENGTH); exit} }' "$log"; }
    local simulation t_bnd t_mom t_cont t_snap t_meteo t_out avgdt
    simulation=$(pull '^[[:space:]]*Total simulation time[[:space:]]*:')
    t_bnd=$(pull '^[[:space:]]*Time in boundaries[[:space:]]*:')
    t_mom=$(pull '^[[:space:]]*Time in momentum[[:space:]]*:')
    t_cont=$(pull '^[[:space:]]*Time in continuity[[:space:]]*:')
    t_snap=$(pull '^[[:space:]]*Time in SnapWave[[:space:]]*:')
    t_meteo=$(pull '^[[:space:]]*Time in meteo forcing[[:space:]]*:')
    t_out=$(pull '^[[:space:]]*Time in output[[:space:]]*:')
    avgdt=$(pull '^[[:space:]]*Average time step')
    local sum_named unaccounted steps
    sum_named=$(awk -v a="$t_bnd" -v b="$t_mom" -v c="$t_cont" -v d="$t_snap" \
        -v e="$t_meteo" -v f="$t_out" 'BEGIN{s=0;
        for(k=1;k<=6;k++){v=(k==1?a:(k==2?b:(k==3?c:(k==4?d:(k==5?e:f)))));
        if(v!="")s+=v+0} printf "%.3f",s}')
    unaccounted=$(awk -v sim="$simulation" -v sn="$sum_named" \
        'BEGIN{if(sim==""||sn=="")print "";else printf "%.3f",sim-sn}')
    steps=$(awk -v sim="$sim_seconds" -v dt="$avgdt" \
        'BEGIN{if(dt==""||dt+0==0)print "";else printf "%d",(sim/dt)+1}')
    local per_step
    per_step=$(awk -v u="$unaccounted" -v s="$steps" \
        'BEGIN{if(u==""||s==""||s+0==0)print "";else printf "%.4f",(u/s)*1000.0}')
    { echo "simulation $simulation"; echo "boundaries $t_bnd"
      echo "momentum $t_mom"; echo "continuity $t_cont"
      echo "snapwave $t_snap"; echo "meteo $t_meteo"; echo "output $t_out"
      echo "avg_dt $avgdt"; echo "sum_named $sum_named"
      echo "unaccounted $unaccounted"; echo "step_count $steps"
      echo "per_step_ms $per_step"; } > "$out"
}

run_gpu_cell() {
    local case_name=$1 length=$2 nranks=$3
    local case_dir=$REPO_ROOT/tests/cases/$case_name
    local run_dir=$OUT_DIR/${case_name}__${length}__gpu_n${nranks}
    stage_case "$case_dir" "$run_dir"
    rewrite_tstop "$run_dir" "$(tstop_for "$length")"
    local cdir; cdir=$(host_to_container "$run_dir")
    echo "--- [gpu_n${nranks}] $case_name $length ---"
    local t0 t1 rc
    t0=$(date +%s)
    set +e
    "$GPU_WRAPPER" mpirun --allow-run-as-root --wdir "$cdir" -n "$nranks" \
        /work/source/install_cuda/bin/sfincs \
        > "$run_dir/sfincs.stdout" 2>&1
    rc=$?
    set -e
    t1=$(date +%s)
    echo "    rc=$rc wall=$((t1-t0))s"
    extract_timings "$run_dir/sfincs.log" "$run_dir/timings.txt" \
        "$(sim_seconds_for "$length")"
    cat "$run_dir/timings.txt" | sed 's/^/    /'
}

for L in 1h 6h 24h 4d; do run_gpu_cell case_prod_regular_tide "$L" 2; done
run_gpu_cell case_prod_regular_tide 24h 1
run_gpu_cell case_prod_quadtree_subgrid_tide 24h 2
run_gpu_cell case_prod_quadtree_subgrid_tide 4d  2

echo
echo "=== SOR-1019 baseline (pre-fix) — complete $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
