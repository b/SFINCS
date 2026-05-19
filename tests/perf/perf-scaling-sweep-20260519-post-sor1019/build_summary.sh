#!/bin/bash
# Render SOR-1017 SUMMARY.md from per-cell timings.txt and
# nvidia_smi_dmon.txt files produced by run_perf_scaling.sh.
# Pure post-processor — no SFINCS invocation. Re-runnable.
#
# Output: SUMMARY.md (alongside this script). Reads:
#   * <case>__<grid>__<length>__<config>/timings.txt        (always)
#   * <case>__<grid>__<length>__<config>/nvidia_smi_dmon.txt (gpu_* only)
#   * capture_env.txt for host fingerprint
#
# Decision rule for per-case verdict (documented at top of analysis):
#   For each (case, grid, config) tuple with all four lengths present:
#     U(L) = unaccounted_gap (s) at length L
#     S(L) = step_count       at length L
#     per_step(L) = U(L) / S(L)
#
#     Verdict:
#       fixed-cost   — U(L) is approximately constant across lengths
#                      (max(U) - min(U)) < 0.5 * mean(U), AND
#                      per_step(L) shrinks at least 5x from 1h to 4d
#                      (i.e. it's not the load-bearing signal)
#       per-step     — per_step(L) is approximately constant across
#                      lengths (max(ps) - min(ps)) < 0.5 * mean(ps),
#                      AND U(L) grows at least 3x from 1h to 4d
#       inconclusive — neither tightness criterion is met (run-to-run
#                      noise too large to discriminate, or both signals
#                      partly explain the gap)
#
#   The verdict is computed for the gpu_n2 1x configuration (the one
#   that motivated the sweep) and reported per-case. Other configs are
#   tabulated for context but not verdict-bearing.

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
LENGTHS=(1h 6h 24h 4d)
CONFIGS=(cpu_n128 gpu_n1 gpu_n2)

# Pull a single named value from <case>__<grid>__<length>__<config>/timings.txt.
get_t() {
    local case_name=$1 grid=$2 length=$3 cfg=$4 key=$5
    local f=$OUT_DIR/${case_name}__${grid}__${length}__${cfg}/timings.txt
    [ -f "$f" ] || { echo ""; return; }
    awk -v k="$key" '$1==k {print $2; exit}' "$f"
}

# Compute steady-state sm % from nvidia_smi_dmon.txt. Skips the first
# 5 and last 2 samples per GPU (startup transient + tear-down), then
# reports median sm % across the kept window. Two header lines start
# with "#"; data rows are "<gpuIdx> <sm%> <mem%> ...".
gpu_steady_sm() {
    local f=$1
    [ -f "$f" ] || { echo ""; return; }
    awk '
        $1 !~ /^#/ && $2 ~ /^[0-9]+$/ {
            n[$1]++
            buf[$1, n[$1]] = $2
        }
        END {
            count = 0
            for (g = 0; g <= 7; g++) {
                if (!(g in n)) continue
                cnt = n[g]
                if (cnt < 8) continue   # too few samples to trust
                # Sort the middle window and pick the median
                lo = 5; hi = cnt - 2
                m = 0
                for (i = lo; i <= hi; i++) { m++; arr[m] = buf[g, i] }
                # bubble sort the small window
                for (i = 1; i <= m; i++) for (j = i+1; j <= m; j++) if (arr[j] < arr[i]) { t = arr[i]; arr[i] = arr[j]; arr[j] = t }
                med = arr[int((m+1)/2)]
                if (count > 0) printf "/"
                printf "g%d=%d%%", g, med
                count++
            }
            if (count == 0) print ""
        }
    ' "$f"
}

# Max sm% across all GPUs (single number for the "saturation" column).
gpu_max_sm() {
    local f=$1
    [ -f "$f" ] || { echo ""; return; }
    awk '
        $1 !~ /^#/ && $2 ~ /^[0-9]+$/ {
            n[$1]++; buf[$1, n[$1]] = $2
        }
        END {
            best = ""
            for (g = 0; g <= 7; g++) {
                if (!(g in n)) continue
                cnt = n[g]
                if (cnt < 8) continue
                lo = 5; hi = cnt - 2
                m = 0
                for (i = lo; i <= hi; i++) { m++; arr[m] = buf[g, i] }
                for (i = 1; i <= m; i++) for (j = i+1; j <= m; j++) if (arr[j] < arr[i]) { t = arr[i]; arr[i] = arr[j]; arr[j] = t }
                med = arr[int((m+1)/2)]
                if (best == "" || med + 0 > best + 0) best = med
            }
            print best
        }
    ' "$f"
}

fmt() { local v=$1; if [ -z "$v" ]; then echo "—"; else printf '%s' "$v"; fi; }

# Compute verdict for a (case, grid, config) tuple. Reads all four
# lengths' timings.txt; emits one of fixed-cost / per-step /
# inconclusive plus the four (U, S, per_step) tuples.
case_verdict() {
    local case_name=$1 grid=$2 cfg=$3
    local U_1h S_1h U_6h S_6h U_24h S_24h U_4d S_4d
    U_1h=$(get_t "$case_name" "$grid" 1h "$cfg" unaccounted); S_1h=$(get_t "$case_name" "$grid" 1h "$cfg" step_count)
    U_6h=$(get_t "$case_name" "$grid" 6h "$cfg" unaccounted); S_6h=$(get_t "$case_name" "$grid" 6h "$cfg" step_count)
    U_24h=$(get_t "$case_name" "$grid" 24h "$cfg" unaccounted); S_24h=$(get_t "$case_name" "$grid" 24h "$cfg" step_count)
    U_4d=$(get_t "$case_name" "$grid" 4d "$cfg" unaccounted); S_4d=$(get_t "$case_name" "$grid" 4d "$cfg" step_count)
    awk -v u1="$U_1h"  -v s1="$S_1h"  \
        -v u2="$U_6h"  -v s2="$S_6h"  \
        -v u3="$U_24h" -v s3="$S_24h" \
        -v u4="$U_4d"  -v s4="$S_4d"  '
        function bad(v) { return v == "" || v + 0 <= 0 }
        function abs(v) { return v < 0 ? -v : v }
        BEGIN {
            if (bad(u1) || bad(s1) || bad(u2) || bad(s2) || bad(u3) || bad(s3) || bad(u4) || bad(s4)) {
                print "unavailable\tone or more cells missing"
                exit
            }
            u_min = u1; u_max = u1
            for (v in arr) delete arr[v]
            arr[1] = u1; arr[2] = u2; arr[3] = u3; arr[4] = u4
            for (i = 1; i <= 4; i++) { if (arr[i] < u_min) u_min = arr[i]; if (arr[i] > u_max) u_max = arr[i] }
            u_mean = (u1 + u2 + u3 + u4) / 4.0

            ps1 = u1/s1; ps2 = u2/s2; ps3 = u3/s3; ps4 = u4/s4
            ps_min = ps1; ps_max = ps1
            arr2[1] = ps1; arr2[2] = ps2; arr2[3] = ps3; arr2[4] = ps4
            for (i = 1; i <= 4; i++) { if (arr2[i] < ps_min) ps_min = arr2[i]; if (arr2[i] > ps_max) ps_max = arr2[i] }
            ps_mean = (ps1 + ps2 + ps3 + ps4) / 4.0

            U_grows = (u4 / u1)        # ratio of 4d to 1h unaccounted
            PS_shrinks = (ps1 / ps4)   # ratio of 1h to 4d per-step

            # Fixed-cost criterion
            u_tight = ((u_max - u_min) < 0.5 * u_mean)
            ps_tight = ((ps_max - ps_min) < 0.5 * ps_mean)

            if (u_tight && PS_shrinks >= 5.0) {
                verdict = "fixed-cost"
                reason = "U(L) max-min " sprintf("%.2f", u_max - u_min) "s < 0.5 * mean " sprintf("%.2f", 0.5 * u_mean) "s; per_step(1h)/per_step(4d) = " sprintf("%.1fx", PS_shrinks)
            } else if (ps_tight && U_grows >= 3.0) {
                verdict = "per-step"
                reason = "per_step max-min " sprintf("%.4f", ps_max - ps_min) "s < 0.5 * mean " sprintf("%.4f", 0.5 * ps_mean) "s; U(4d)/U(1h) = " sprintf("%.1fx", U_grows)
            } else {
                verdict = "inconclusive"
                reason = "U max-min " sprintf("%.2f", u_max - u_min) "s vs 0.5 mean " sprintf("%.2f", 0.5 * u_mean) "s; per_step max-min " sprintf("%.4f", ps_max - ps_min) "s vs 0.5 mean " sprintf("%.4f", 0.5 * ps_mean) "s; U(4d)/U(1h)=" sprintf("%.1fx", U_grows) "; ps(1h)/ps(4d)=" sprintf("%.1fx", PS_shrinks)
            }
            printf "%s\t%s\t%.3f\t%d\t%.6f\t%.3f\t%d\t%.6f\t%.3f\t%d\t%.6f\t%.3f\t%d\t%.6f\n",
                verdict, reason,
                u1, s1, ps1, u2, s2, ps2, u3, s3, ps3, u4, s4, ps4
        }
    '
}

# --- Render the document ----------------------------------------------------

{
cat <<'HDR'
# SOR-1020 — scaling sweep re-run (post-SOR-1019)

Re-run of the [SOR-1017 scaling sweep](../perf-scaling-sweep-20260519/SUMMARY.md)
at a HEAD that includes both per-step halo-exchange coalescing fixes
([SOR-1018](../halo-exchange-profile-20260519/FINDINGS.md): q+uv;
[SOR-1019](../halo-exchange-cells-coalesce-20260519/SUMMARY.md):
zs+zsderv+z_volume cell halos). SOR-1017 verdicted all five
production cases as `per-step` on `gpu_n2 1x` — the unaccounted gap
`U(L) = total_simulation_time - sum(named components)` grew 70x-116x
from 1 h to 4 d while `per_step = U/step_count` stayed within
~15 % of its mean. SOR-1018 and SOR-1019 specifically target the
per-step CUDA-MPI halo exchange that profiling identified as the
dominant contributor. This sweep captures the same 5×4×3×(1-2)
matrix at the post-fix HEAD so the cumulative delta can be
quantified per case and the verdict re-evaluated.

The "delta vs SOR-1017 baseline" section below is mechanically
generated from `../perf-scaling-sweep-20260519/<case>__1x__4d__gpu_n2/timings.txt`
(pre-fix, HEAD `2137fc0`) against this directory's same cell
(post-fix, HEAD recorded in `capture_env.txt`).

## Decision rule (verdict per case)

For each `(case, grid, config)` tuple with all four lengths present,
compute at each length L:

```
U(L)         = simulation - (boundaries + momentum + continuity + snapwave + meteo + output)
step_count   = (tstop - tstart) / avg_dt + 1
per_step(L)  = U(L) / step_count(L)
```

Then:

* **`fixed-cost`** when `U(L)` is roughly constant
  (`max(U) - min(U) < 0.5 * mean(U)`) AND `per_step(1h) / per_step(4d) >= 5x`
  (i.e. the gap is amortized away as the step count grows).
* **`per-step`** when `per_step(L)` is roughly constant
  (`max(ps) - min(ps) < 0.5 * mean(ps)`) AND `U(4d) / U(1h) >= 3x`
  (i.e. the gap grows in step with the step count).
* **`inconclusive`** otherwise — run-to-run noise or a mix of the
  two regimes prevents a clean call.

The verdict is reported per case for the `gpu_n2` `1x` configuration
(the one the issue body identifies as carrying the unaccounted-time
question). The `cpu_n128`, `gpu_n1`, and `4x`-grid rows are tabulated
for context but are not verdict-bearing.

## Methodology

Captured by `run_perf_scaling.sh` in this directory; orchestration
log in `run.stdout`; host fingerprint in `capture_env.txt`. Each
cell below is one run per `(case, grid, length, config)` — no
per-cell averaging. The CPU caveats from SOR-87 apply (single-shot
`cpu_n128` wall has wide variance on this 128-thread host).

* **Configurations:**
  * `cpu_n128` — gfortran/OpenMP, `OMP_NUM_THREADS=128`,
    `OMP_PROC_BIND=true`, single process.
  * `gpu_n1` — CUDA build, `mpirun -n 1` inside `sfincs-build-gpu:latest`.
  * `gpu_n2` — CUDA build, `mpirun -n 2` inside `sfincs-build-gpu:latest`.
* **Simulation lengths:** 1 h, 6 h, 24 h, 4 d — `tstart` fixed at
  `20200101 000000`; `tstop` is rewritten in the staged `sfincs.inp`.
  SFINCS's adaptive timestepper (bounded by `dtmax=60.0` for these
  cases) decides the resulting step count at run time.
* **Grids:**
  * `1x` — native grid as shipped under `tests/cases/<case>/`.
  * `4x` — only for `case_prod_regular_tide`: `mmax`, `nmax` doubled
    (cell count 4x), `dx`, `dy` halved, bathymetry / mask / tide
    forcing regenerated by `generate_4x_regular_tide.py` (the case's
    own `generate.py` re-run with the refined dimensions). The four
    other cases ship with auxiliary forcing files (quadtree netcdf,
    subgrid lookup, on-grid SCS / meteo) whose refinement is out of
    scope for a perf-only harness; per-case skip rationale:
    * `case_prod_quadtree_subgrid_tide` — refining the computational
      mesh requires regenerating the precomputed quadtree netcdf
      (`sfincs.nc`) and its subgrid lookup (`sfincs_subgrid.nc`),
      which would require a full HydroMT-SFINCS preprocessing run.
    * `case_prod_riverine` — `sfincs.scs` is an on-comp-grid ASCII
      array; refining the grid requires re-running the SCS-CN
      preprocessing pipeline.
    * `case_prod_storm_amuv` — `sfincs.scs` / `sfincs.ks` /
      `sfincs.sigma` / `sfincs.psi` are on-comp-grid ASCII arrays
      with the same regen blocker.
    * `case_prod_compound_snapwave` — quadtree + subgrid + SnapWave
      grid coupling. Same regen blocker as `quadtree_subgrid_tide`.

## Delta vs SOR-1017 baseline (`1x gpu_n2 4d` cell)

Pre-fix numbers are from `../perf-scaling-sweep-20260519/` (HEAD
`2137fc0`, captured 2026-05-19T07:53:51Z, same hardware /
container image). Post-fix numbers from this directory's cells,
captured at the HEAD recorded in `capture_env.txt`. The `4d`
length is the highest step-count cell, so the per-step
contribution dominates the unaccounted gap and the cumulative
SOR-1018 + SOR-1019 coalescing savings are most visible.

| case | metric | pre-fix | post-fix | Δ (abs) | Δ (%) |
|------|--------|---------|----------|---------|-------|
HDR

BASELINE_DIR=$OUT_DIR/../perf-scaling-sweep-20260519

# Pull a key from the baseline directory's timings.txt for a cell.
get_baseline() {
    local case_name=$1 grid=$2 length=$3 cfg=$4 key=$5
    local f=$BASELINE_DIR/${case_name}__${grid}__${length}__${cfg}/timings.txt
    [ -f "$f" ] || { echo ""; return; }
    awk -v k="$key" '$1==k {print $2; exit}' "$f"
}

# Render a single delta row: case label is taken from the caller's
# loop variable.
delta_row() {
    local case_name=$1 metric=$2 pre=$3 post=$4 fmt_spec=$5
    local dabs="" dpct=""
    if [ -n "$pre" ] && [ -n "$post" ]; then
        dabs=$(awk -v a="$pre" -v b="$post" -v f="$fmt_spec" 'BEGIN { printf f, b-a }')
        dpct=$(awk -v a="$pre" -v b="$post" 'BEGIN { if (a+0==0) print ""; else printf "%+.1f%%", 100*(b-a)/a }')
    fi
    echo "| \`$case_name\` | $metric | $(fmt "$pre") | $(fmt "$post") | $(fmt "$dabs") | $(fmt "$dpct") |"
}

for case_name in "${CASES[@]}"; do
    pre_total=$(get_baseline "$case_name" 1x 4d gpu_n2 total)
    pre_sim=$(get_baseline "$case_name" 1x 4d gpu_n2 simulation)
    pre_U=$(get_baseline "$case_name" 1x 4d gpu_n2 unaccounted)
    pre_S=$(get_baseline "$case_name" 1x 4d gpu_n2 step_count)

    post_total=$(get_t "$case_name" 1x 4d gpu_n2 total)
    post_sim=$(get_t "$case_name" 1x 4d gpu_n2 simulation)
    post_U=$(get_t "$case_name" 1x 4d gpu_n2 unaccounted)
    post_S=$(get_t "$case_name" 1x 4d gpu_n2 step_count)

    pre_ps=""; post_ps=""
    if [ -n "$pre_U" ] && [ -n "$pre_S" ] && [ "$pre_S" -gt 0 ] 2>/dev/null; then
        pre_ps=$(awk -v u="$pre_U" -v s="$pre_S" 'BEGIN { printf "%.4f", 1000*u/s }')
    fi
    if [ -n "$post_U" ] && [ -n "$post_S" ] && [ "$post_S" -gt 0 ] 2>/dev/null; then
        post_ps=$(awk -v u="$post_U" -v s="$post_S" 'BEGIN { printf "%.4f", 1000*u/s }')
    fi

    delta_row "$case_name" "wall (s)"                  "$pre_total" "$post_total" "%+.3f"
    delta_row "$case_name" "total_simulation_time (s)" "$pre_sim"   "$post_sim"   "%+.3f"
    delta_row "$case_name" "U(L) unaccounted (s)"      "$pre_U"     "$post_U"     "%+.3f"
    delta_row "$case_name" "per_step (ms)"             "$pre_ps"    "$post_ps"    "%+.4f"
done
echo

cat <<'VHDR'
## Per-case verdicts re-evaluated post-fix (gpu_n2, 1x grid)

Same decision rule as SOR-1017 (above), now applied to this sweep's
post-fix data. A case that flips from `per-step` to `fixed-cost`
means the per-step coordination overhead has been amortized below
the discrimination threshold; a case that stays `per-step` means
residual per-step cost remains.

| case | verdict | reasoning |
|------|---------|-----------|
VHDR

for case_name in "${CASES[@]}"; do
    out=$(case_verdict "$case_name" 1x gpu_n2)
    verdict=$(printf '%s' "$out" | cut -f1)
    reason=$(printf '%s' "$out" | cut -f2)
    echo "| \`$case_name\` | **$(fmt "$verdict")** | $(fmt "$reason") |"
done
echo

# Per-case detail: per-length wall-clock matrix at 1x; per-length
# unaccounted-gap + step_count + per_step row at gpu_n2 1x.
for case_name in "${CASES[@]}"; do
    echo "### \`$case_name\`"
    echo
    GRIDS_LIST=(1x)
    if [ -d "$OUT_DIR/${case_name}__4x__1h__gpu_n2" ]; then GRIDS_LIST=(1x 4x); fi
    for grid in "${GRIDS_LIST[@]}"; do
        echo "**grid: \`$grid\`** — wall (s) per config per length:"
        echo
        echo "| length | cpu_n128 wall | gpu_n1 wall | gpu_n2 wall | gpu_n1 / gpu_n2 |"
        echo "|--------|---------------|-------------|-------------|------------------|"
        for L in "${LENGTHS[@]}"; do
            c=$(get_t "$case_name" "$grid" "$L" cpu_n128 total)
            g1=$(get_t "$case_name" "$grid" "$L" gpu_n1 total)
            g2=$(get_t "$case_name" "$grid" "$L" gpu_n2 total)
            r=""
            if [ -n "$g1" ] && [ -n "$g2" ]; then
                r=$(awk -v a="$g1" -v b="$g2" 'BEGIN { if (b+0==0) print ""; else printf "%.2fx", a/b }')
            fi
            echo "| $L | $(fmt "$c") | $(fmt "$g1") | $(fmt "$g2") | $(fmt "$r") |"
        done
        echo
        echo "**grid: \`$grid\`** — \`gpu_n2\` named components vs total simulation (s), unaccounted gap U(L), step count S(L), per-step U/S (ms):"
        echo
        echo "| length | simulation | boundaries | momentum | continuity | snapwave | meteo | output | U(L) | S(L) | per_step (ms) |"
        echo "|--------|------------|------------|----------|------------|----------|-------|--------|------|------|---------------|"
        for L in "${LENGTHS[@]}"; do
            sim=$(get_t "$case_name" "$grid" "$L" gpu_n2 simulation)
            bnd=$(get_t "$case_name" "$grid" "$L" gpu_n2 boundaries)
            mom=$(get_t "$case_name" "$grid" "$L" gpu_n2 momentum)
            cont=$(get_t "$case_name" "$grid" "$L" gpu_n2 continuity)
            snap=$(get_t "$case_name" "$grid" "$L" gpu_n2 snapwave)
            meteo=$(get_t "$case_name" "$grid" "$L" gpu_n2 meteo)
            outp=$(get_t "$case_name" "$grid" "$L" gpu_n2 output)
            U=$(get_t "$case_name" "$grid" "$L" gpu_n2 unaccounted)
            S=$(get_t "$case_name" "$grid" "$L" gpu_n2 step_count)
            ps=""
            if [ -n "$U" ] && [ -n "$S" ]; then
                ps=$(awk -v u="$U" -v s="$S" 'BEGIN { if (s+0==0) print ""; else printf "%.3f", 1000*u/s }')
            fi
            echo "| $L | $(fmt "$sim") | $(fmt "$bnd") | $(fmt "$mom") | $(fmt "$cont") | $(fmt "$snap") | $(fmt "$meteo") | $(fmt "$outp") | $(fmt "$U") | $(fmt "$S") | $(fmt "$ps") |"
        done
        echo
        echo "**grid: \`$grid\`** — GPU steady-state sm % (median across mid-run window, per GPU):"
        echo
        echo "| length | gpu_n1 sm % | gpu_n2 sm % | gpu_n2 max sm % |"
        echo "|--------|-------------|-------------|------------------|"
        for L in "${LENGTHS[@]}"; do
            sm1=$(gpu_steady_sm "$OUT_DIR/${case_name}__${grid}__${L}__gpu_n1/nvidia_smi_dmon.txt")
            sm2=$(gpu_steady_sm "$OUT_DIR/${case_name}__${grid}__${L}__gpu_n2/nvidia_smi_dmon.txt")
            sm2max=$(gpu_max_sm "$OUT_DIR/${case_name}__${grid}__${L}__gpu_n2/nvidia_smi_dmon.txt")
            sm2max_label=""
            [ -n "$sm2max" ] && sm2max_label="${sm2max}%"
            echo "| $L | $(fmt "$sm1") | $(fmt "$sm2") | $(fmt "$sm2max_label") |"
        done
        echo
    done
done

cat <<'INTERP'
## Synthesis

<!-- Hand-authored below from the post-fix numbers in the tables
     above. The synthesis describes (a) whether the per-step
     verdict held or flipped per case, (b) what the new largest
     contributor to U(L) is now that the halo-exchange path has
     been coalesced, and (c) any remaining hotspots that justify
     follow-up work. -->

## Cross-link

* **Baseline (pre-fix)** — [`../perf-scaling-sweep-20260519/SUMMARY.md`](../perf-scaling-sweep-20260519/SUMMARY.md)
  (SOR-1017): the matching scaling sweep at HEAD `2137fc0`,
  pre-SOR-1018 / pre-SOR-1019. The delta table above is computed
  per-case against the `1x__4d__gpu_n2` cell from this directory.
* **q + uv halo coalescing** — [`../halo-exchange-profile-20260519/FINDINGS.md`](../halo-exchange-profile-20260519/FINDINGS.md)
  (SOR-1018): per-step q+uv halo exchange coalesced into one MPI
  call, the first fix targeted by this re-run.
* **zs + zsderv + z_volume cell-halo coalescing** —
  [`../halo-exchange-cells-coalesce-20260519/SUMMARY.md`](../halo-exchange-cells-coalesce-20260519/SUMMARY.md)
  (SOR-1019): per-step zs / zsderv / z_volume cell-halo exchanges
  coalesced, the second fix.
* **SOR-87 perf-matrix** — [`../perf-matrix-20260518/SUMMARY.md`](../perf-matrix-20260518/SUMMARY.md)
  — origin of the gpu_n2 unaccounted-time question this entire
  chain answers.

## Artifacts

Per-(case, grid, length, config) under
`<case>__<grid>__<length>__<config>/`:

* `sfincs.inp` — length-modified (and 4x-refined where applicable) input
* `sfincs.log` — SFINCS log (timing summary)
* `sfincs.stdout` — mpirun / OMP stdout
* `nvidia_smi_dmon.txt` — GPU 0+1 utilization snapshot (gpu_* only)
* `timings.txt` — parsed numbers consumed by this SUMMARY

Top-level:

* `run_perf_scaling.sh` — capture harness
* `generate_4x_regular_tide.py` — 4x-grid refinement for regular_tide
* `build_summary.sh` — this SUMMARY generator
* `run.stdout` — orchestration log
* `capture_env.txt` — host CPU / GPU / nproc fingerprint
INTERP
} > "$SUMMARY"

echo "wrote $SUMMARY"
ls -la "$SUMMARY"
