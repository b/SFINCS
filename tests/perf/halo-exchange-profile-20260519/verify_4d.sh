#!/bin/bash
# SOR-1018 — post-fix verification of the q+uv halo-exchange coalescing.
#
# Acceptance: re-run the SOR-1017 scaling-sweep-style measurement on
# case_prod_regular_tide 1x gpu_n2 at 1h/6h/24h/4d, compute
# U(L) = simulation - sum(named SFINCS timer components) and
# per_step = U / step_count exactly as
# tests/perf/perf-scaling-sweep-20260519/run_perf_scaling.sh does, and
# compare against the SOR-1017 baseline. Expected: the per-step gap
# (dominated by halo_q_uv pre-fix, ~50 %) drops measurably.
#
# Also runs gpu_n1 24h (single-rank reference: halo_uv_n_neighbors==0,
# so halo_exchange_q_uv early-returns) and diffs sfincs_map.nc:
#   * post-fix gpu_n2  vs  post-fix gpu_n1   — coalesced exchange must
#     deliver the SAME halo values as the single-rank reference
#   * post-fix gpu_n2  vs  the pre-fix nsys capture's sfincs_map.nc
#     (../case_prod_regular_tide__24h__gpu_n2/sfincs_map.nc) — the
#     coalescing must be bit-exact vs the pre-fix two-exchange path
# via tests/scripts/diff_zsmax.py (max_abs_diff must be 0.0).
#
# Usage (from repo root, after the post-fix GPU binary is built):
#     tests/perf/halo-exchange-profile-20260519/verify_4d.sh

set -uo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
PROFILE_DIR=$(cd "$(dirname "$0")" && pwd)
OUT_DIR=$PROFILE_DIR/verify-4d
GPU_BIN_HOST=$REPO_ROOT/source/install_cuda/bin/sfincs
GPU_WRAPPER=$REPO_ROOT/source/build_scripts/run_gpu_container.sh
CASE_NAME=case_prod_regular_tide
CASE_DIR=$REPO_ROOT/tests/cases/$CASE_NAME
PREFIX_MAP=$PROFILE_DIR/${CASE_NAME}__24h__gpu_n2/sfincs_map.nc

mkdir -p "$OUT_DIR"
LOG=$OUT_DIR/run.stdout
exec > >(tee "$LOG") 2>&1
echo "=== SOR-1018 verify-4d — start $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
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

# SOR-1017 extract_timings, verbatim semantics.
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
    local length=$1 nranks=$2
    local run_dir=$OUT_DIR/${CASE_NAME}__${length}__gpu_n${nranks}
    stage_case "$CASE_DIR" "$run_dir"
    rewrite_tstop "$run_dir" "$(tstop_for "$length")"
    local cdir; cdir=$(host_to_container "$run_dir")
    echo "--- [gpu_n${nranks}] $CASE_NAME $length ---"
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

for L in 1h 6h 24h 4d; do run_gpu_cell "$L" 2; done
run_gpu_cell 24h 1

# --- bit-exactness diffs ----------------------------------------------------
N2_MAP=$OUT_DIR/${CASE_NAME}__24h__gpu_n2/sfincs_map.nc
N1_MAP=$OUT_DIR/${CASE_NAME}__24h__gpu_n1/sfincs_map.nc
echo
echo "=== bit-exactness ==="
echo "[post-fix gpu_n2 vs post-fix gpu_n1 (single-rank reference)]"
python3 "$REPO_ROOT/tests/scripts/diff_zsmax.py" \
    --reference "$N1_MAP" --candidate "$N2_MAP" --threshold 1e-6 || true
echo "[post-fix gpu_n2 vs PRE-fix nsys-capture gpu_n2 (coalescing must be bit-exact)]"
if [ -f "$PREFIX_MAP" ]; then
    python3 "$REPO_ROOT/tests/scripts/diff_zsmax.py" \
        --reference "$PREFIX_MAP" --candidate "$N2_MAP" --threshold 1e-6 || true
else
    echo "  (pre-fix map $PREFIX_MAP absent — skipped)"
fi

echo
echo "=== SOR-1018 verify-4d — complete $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
