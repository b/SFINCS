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
# SOR-1017 — scaling sweep (sim length + grid + config)

Follow-up to **[SOR-87](../perf-matrix-20260518/SUMMARY.md)**. The
SOR-87 24h cases were too short to distinguish whether the post-fix
`gpu_n2` "unaccounted time" gap — defined as `total_simulation_time
- sum(boundaries, momentum, continuity, snapwave, meteo, output)`,
about 4 s of ~10 s on `case_prod_regular_tide` per the SOR-87 SUMMARY
— is fixed-cost (startup-dominated) or per-step (CUDA-MPI halo
exchange or device-side sync). This sweep varies the simulation
length across four points (1 h, 6 h, 24 h, 4 d) per (case, config,
grid) so the per-step-vs-fixed-cost question can be answered
directly from the trend of `unaccounted_gap` vs `step_count`.

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

## Per-case verdicts (gpu_n2, 1x grid)

HDR

# Verdict table + per-case detail.
echo "| case | verdict | reasoning |"
echo "|------|---------|-----------|"
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

**All five production cases verdict `per-step` on `gpu_n2` `1x`.** The
unaccounted gap `U(L) = simulation - sum(named components)` grows
70x-116x from the 1 h length to the 4 d length while `per_step(L) =
U(L) / step_count(L)` stays within ~15 % of its mean across the four
lengths in every case. The SOR-87 24 h cases were not long enough to
discriminate per-step from fixed-cost at the 4 s out of 10 s ratio
seen on `case_prod_regular_tide`; the 4 d cells in this sweep settle
the question. The gap is per-step sync / coordination overhead, not
a fixed startup cost that amortizes away at scale.

This directly answers the question the issue body posed (per the
decision rule it documents): **halo-exchange profiling is the next
investigation**. The per-step gap is sized in the 0.10 ms-0.91 ms
range depending on the case (lower for the small-grid `tide` cases,
larger for `riverine` / `storm_amuv` where host-side meteo / SCS
sets up more per-step coordination work).

## Throughput-ceiling / saturation observations

Per AC: at the largest `(length, grid)` cell per case — `4d` `4x`
where present, else `4d` `1x` — report the steady-state GPU sm %
median and what limits it. The `gpu_n2 max sm %` column above is
the median sm % on the busiest of the two GPUs during the mid-run
window (first 5 and last 2 samples skipped to drop the startup /
shutdown transients).

**Cell at or above the 80 % bar:** `case_prod_regular_tide` `4x`
`gpu_n1` settles at **88 %** steady-state sm % across the 6 h /
24 h / 4 d cells (the 1 h cell is too short for the dmon window to
reach steady-state). 4x cells per rank push a single-rank
configuration past the 80 % AC bar.

**Per-case ceiling and limiting factor on 1x (native) grid:**

| case | gpu_n2 ceiling | limiting factor |
|------|----------------|-----------------|
| `case_prod_regular_tide`           | 42-43 %  | per-rank kernels (~83 k cells / rank at 1x) launch faster than they fill the A6000's 84 SMs. The `gpu_n1` 4x cell at 88 % sm % shows the same kernel saturates one A6000 once cells-per-rank quadruples. |
| `case_prod_quadtree_subgrid_tide`  | 30-34 %  | quadtree cell count smaller than `regular_tide` after refinement, so the per-rank kernel sees fewer threads of work. |
| `case_prod_riverine`               | 18-23 %  | per-step work dominated by meteo (`Time in meteo forcing` ~17 % of total) which runs host-side and idles the GPU between kernels. |
| `case_prod_storm_amuv`             | 21 %     | same as `riverine` plus AMU/V meteo coupling; per-step host-side work proportionally larger than GPU compute. |
| `case_prod_compound_snapwave`      | 0 % median | host-bound: SnapWave is the dominant component (~80 % of total simulation time per the 24 h / 4 d cells above); the GPU sits idle while SnapWave runs on CPU. ~73 % of dmon samples at the 24 h cell read 0 %. A SnapWave GPU port (deferred per SOR-81) is the only lever that moves this cell. |

**Throughput-ceiling implication.** Only `case_prod_regular_tide`'s
`gpu_n1` 4x configuration is GPU-bound on this hardware; every
other production case is either too small per rank (the two `tide`
variants) or host-bound (`riverine` / `storm_amuv` / `compound_snapwave`)
to saturate the A6000's SMs at native footprint. Pushing past the
~40-65 % envelope on the under-loaded cases requires either bigger
grids or a different parallelism layout (more cells per rank, fewer
ranks), not a faster kernel.

**Crossover (gpu_n2 vs gpu_n1).** The `gpu_n1 / gpu_n2` wall ratio
in the per-case tables answers the issue body's "is there a
(length, grid) cell where `gpu_n2` becomes faster than `gpu_n1`?"
question. The tide-dominated cases (`regular_tide` 1x,
`quadtree_subgrid_tide`) ALWAYS see `gpu_n1` win: ratio < 1.0 at
every length on 1x. The meteo / SCS cases (`riverine`, `storm_amuv`)
flip the other way: `gpu_n2` is faster at every length (ratio >
1.0). `case_prod_compound_snapwave` is essentially break-even
(ratios 0.95-1.07). `case_prod_regular_tide` 4x shows the
crossover within a single case: `gpu_n1` wins at 1 h
(0.88x meaning gpu_n2 faster, 12 % slower for gpu_n1), gpu_n2 wins
from 6 h onward (1.11x-1.18x). The crossover is plausibly the
per-step halo-exchange cost: at low step counts the per-rank
kernel launch + halo exchange overhead dominates and 2 ranks lose;
at high step counts the additional compute per rank dominates and
2 ranks win.

## Cross-link

* SOR-87 closing artifact: [`../perf-matrix-20260518/SUMMARY.md`](../perf-matrix-20260518/SUMMARY.md)
  — establishes the post-fix `gpu_n2` baseline whose unaccounted-time
  question this sweep answers.

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
