#!/bin/bash
# Render the SOR-87 SUMMARY.md from per-(case, config, rev) timings.txt
# files produced by run_perf_matrix.sh. Pure post-processor — no
# SFINCS invocation. Re-runnable.
#
# Output: SUMMARY.md (alongside this script). Reads:
#   * <case>__<config>__<rev>/timings.txt for every (case, config, rev)
#   * capture_env.txt for host fingerprint
#   * run.stdout for orchestration log reference
#
# Speedup-table policy (SOR-87 AC, load-bearing):
#   * Every speedup ratio cites BOTH numerator and denominator full
#     config names (e.g. "gpu_n2 post vs cpu_n128 post").
#   * Only fair comparisons are emitted as numeric ratios:
#       - same config pre vs post  (refactor's own speedup)
#       - cross-config at matched parallelism, with the asymmetry noted
#         in the row when ranks don't match (which they don't here:
#         cpu_n128 is 1 process * 128 threads; gpu_n2 is 2 processes
#         on 2 GPUs).
#   * Bare "60x" / "10x" claims are forbidden.

set -euo pipefail

OUT_DIR=$(cd "$(dirname "$0")" && pwd)
SUMMARY=$OUT_DIR/SUMMARY.md

CASES=(
    case_prod_regular_tide
    case_prod_quadtree_subgrid_tide
    case_prod_riverine
    case_prod_storm_amuv
    case_prod_compound_snapwave
)
CONFIGS=(cpu_n128 gpu_n1 gpu_n2)
REVS=(pre post)

# Pull a single named timing value from <case>__<config>__<rev>/timings.txt;
# echoes the raw number or empty string if missing.
get_t() {
    local case_name=$1 cfg=$2 rev=$3 key=$4
    local f=$OUT_DIR/${case_name}__${cfg}__${rev}/timings.txt
    [ -f "$f" ] || { echo ""; return; }
    awk -v k="$key" '$1==k {print $2; exit}' "$f"
}

# Format a wall-clock value; "—" for missing.
fmt() {
    local v=$1
    if [ -z "$v" ]; then echo "—"; else printf '%s s' "$v"; fi
}

# Compute a speedup ratio (denom / num); empty if either is missing.
ratio() {
    local denom=$1 num=$2
    [ -z "$denom" ] || [ -z "$num" ] && { echo ""; return; }
    awk -v d="$denom" -v n="$num" 'BEGIN{ if (n+0==0) print ""; else printf "%.2fx", d/n }'
}

# Header.
{
cat <<'HDR'
# SOR-87 — CPU-vs-GPU performance matrix

Closing artifact for the SOR-65 → SOR-86 program of work (canonical
on-device + SnapWave memoization). Quantifies the wall-clock effect
of that program across the production case set, and pairs every GPU
number with a matched-parallelism CPU baseline so the speedup claims
are defensible.

## Methodology

Captured by `run_perf_matrix.sh` in this directory; orchestration log
in `run.stdout`; host fingerprint in `capture_env.txt`. Each cell
below is one run per `(case, config, revision)` — no per-cell
averaging — but every speedup ratio is reported alongside the full
config-pair label so the comparison is unambiguous. Run-to-run wall
clock variance on the host CPU is significant for cases where the
per-thread work is small (e.g. `case_meteo`'s 2500-cell grid showed
6x variance across three back-to-back `cpu_n128` runs); the
production cases below have substantially more cells per thread and
were each run once.

* **Configurations:**
  * `cpu_n128` — gfortran/OpenMP CPU build, `OMP_NUM_THREADS=128`,
    `OMP_PROC_BIND=true`, single process. SFINCS's CPU build supports
    OpenMP only — MPI calls in `source/src/sfincs_lib.F90` are gated
    on `USE_CUDA`, so the SOR-87 AC's "`mpirun -n $(nproc)` (or
    equivalent — count host's available cores via `nproc`/`lscpu` at
    run time)" clause is satisfied via OpenMP. `nproc` on this host
    is 128 (64 physical cores + SMT).
  * `gpu_n1` — CUDA build, `mpirun -n 1` inside
    `sfincs-build-gpu:latest`.
  * `gpu_n2` — CUDA build, `mpirun -n 2` inside
    `sfincs-build-gpu:latest`.
* **Revisions:**
  * `post` — current `sorcerer/sor-87` HEAD, with the cumulative
    SOR-65 (zs canonical) → SOR-66 (q/uv canonical) → SOR-67
    (aux arrays canonical) → SOR-68 (feature-boundary bridges) →
    SOR-82 (SnapWave `make_theta_grid` memoization) work landed.
  * `pre` — commit `d1b84c1` (the Phase-0 NVTX-annotated commit
    that immediately precedes SOR-65 Phase 1 zs-device-canonical
    refactor at `9c3e69c`). Same pattern as SOR-69's
    `/tmp/sfincs-pre-phase1-baseline` sibling worktree
    (`tests/perf/phase5-canonical-on-device-final-20260517/`
    `run_byte_identical_check.sh`).

## Wall-clock matrix (per case, per config, per revision)

HDR

# Per-case wall-clock rows.
for case_name in "${CASES[@]}"; do
    echo "### \`$case_name\`"
    echo
    echo "| config   | pre wall | post wall | post / pre (this config's speedup from refactor) |"
    echo "|----------|----------|-----------|--------------------------------------------------|"
    for cfg in "${CONFIGS[@]}"; do
        pre_w=$(get_t "$case_name" "$cfg" pre total)
        post_w=$(get_t "$case_name" "$cfg" post total)
        r=$(ratio "$pre_w" "$post_w")
        # The same-config pre/post ratio carries its own label.
        if [ -n "$r" ]; then
            r_label="\`${cfg} pre\` ${pre_w} s ÷ \`${cfg} post\` ${post_w} s = ${r}"
        else
            r_label="—"
        fi
        echo "| \`$cfg\` | $(fmt "$pre_w") | $(fmt "$post_w") | $r_label |"
    done
    echo
done

cat <<'XGAP'
## Cross-config speedup (post-fix only) — matched-parallelism caveats

The CPU-vs-GPU speedup column reports `cpu_n128 post / gpu_nM post`
for `M ∈ {1, 2}`. The parallelism mapping is **not matched**:
`cpu_n128` is 1 process × 128 OpenMP threads (on 64 physical cores +
SMT); `gpu_n1` is 1 rank on 1 RTX A6000; `gpu_n2` is 2 ranks on
2 RTX A6000s. The fair-comparison frame is therefore "best CPU
configuration on this host vs best (or each) GPU configuration on
this host", NOT "single thread vs single rank". The 128:1 / 128:2
process-count asymmetry is called out explicitly per SOR-87 AC.

XGAP

echo "| case | \`cpu_n128 post\` wall | \`gpu_n1 post\` wall | \`gpu_n1 post\` vs \`cpu_n128 post\` | \`gpu_n2 post\` wall | \`gpu_n2 post\` vs \`cpu_n128 post\` |"
echo "|------|----------------------|--------------------|----------------------------------|--------------------|----------------------------------|"
for case_name in "${CASES[@]}"; do
    c=$(get_t "$case_name" cpu_n128 post total)
    g1=$(get_t "$case_name" gpu_n1 post total)
    g2=$(get_t "$case_name" gpu_n2 post total)
    r1=$(ratio "$c" "$g1")
    r2=$(ratio "$c" "$g2")
    r1_label=${r1:-—}
    r2_label=${r2:-—}
    # Stamp the ratio's full config-pair label inline.
    [ -n "$r1" ] && r1_label="\`cpu_n128 post\` $c s ÷ \`gpu_n1 post\` $g1 s = $r1"
    [ -n "$r2" ] && r2_label="\`cpu_n128 post\` $c s ÷ \`gpu_n2 post\` $g2 s = $r2"
    echo "| \`$case_name\` | $(fmt "$c") | $(fmt "$g1") | $r1_label | $(fmt "$g2") | $r2_label |"
done

cat <<'BREAK'

## Per-component breakdown (post-fix, `gpu_n2` configuration)

Per SOR-87 AC: per-component breakdown from `sfincs.log`'s timing
summary for at least one post-fix run per case. Below uses `gpu_n2`
post-fix (the multi-rank GPU production configuration). Absolute
seconds and (component / total) fraction. The "—" entries are
components that don't appear in that case's log (e.g. SnapWave
only runs in `case_prod_compound_snapwave`).

| case | total | boundaries | momentum | continuity | snapwave | meteo | output |
|------|-------|------------|----------|------------|----------|-------|--------|
BREAK
for case_name in "${CASES[@]}"; do
    tot=$(get_t "$case_name" gpu_n2 post total)
    fmt_comp() {
        local k=$1
        local v
        v=$(get_t "$case_name" gpu_n2 post "$k")
        if [ -z "$v" ]; then
            echo "—"
        elif [ -n "$tot" ] && awk -v t="$tot" 'BEGIN{exit !(t+0>0)}'; then
            local pct
            pct=$(awk -v v="$v" -v t="$tot" 'BEGIN{ if (t+0==0) {print "—"} else { printf "%.1f%%", 100*v/t } }')
            printf '%s s (%s)' "$v" "$pct"
        else
            printf '%s s' "$v"
        fi
    }
    bnd=$(fmt_comp boundaries)
    mom=$(fmt_comp momentum)
    cont=$(fmt_comp continuity)
    snap=$(fmt_comp snapwave)
    met=$(fmt_comp meteo)
    out=$(fmt_comp output)
    echo "| \`$case_name\` | $(fmt "$tot") | $bnd | $mom | $cont | $snap | $met | $out |"
done

cat <<'TAIL'

## Artifacts

Per-(case, config, revision) under `<case>__<config>__<rev>/`:

* `sfincs.log` — SFINCS log (timing summary)
* `sfincs.stdout` — mpirun / OMP stdout
* `nvidia_smi_dmon.txt` — GPU 0+1 utilization snapshot (gpu_* runs only)
* `timings.txt` — parsed numbers consumed by this SUMMARY

Top-level:

* `run_perf_matrix.sh` — capture harness
* `build_summary.sh` — this SUMMARY generator
* `run.stdout` — orchestration log
* `capture_env.txt` — host CPU / GPU / nproc fingerprint
TAIL
} > "$SUMMARY"

echo "wrote $SUMMARY"
ls -la "$SUMMARY"
