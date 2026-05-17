#!/bin/bash
# SOR-69 Phase 5 — canonical-on-device regression guard.
#
# Scans the three per-step `_gpu.cuf` files for any line that would
# re-introduce a per-step host<->device copy of canonical SFINCS state.
# Two idioms are flagged:
#
#   (a) `call bridge_in_*` / `call bridge_out_*` from
#       source/src/sfincs_partition.cuf (the dominant per-step bridge
#       pattern; used historically for cell-rank and edge-rank arrays).
#
#   (b) Bare Fortran whole-array assignment between a device array and
#       its `_h` host shadow. Regex: a line of the form
#           ^\s*<name>(_h)?\s*=\s*<name>(_h)?\s*$
#       where <name> is the same identifier on both sides (one side may
#       carry the optional `_h` suffix; the other carries the bare
#       device name). This catches the now-retired `zsb = zsb_h` /
#       `uvmean_h = uvmean` idiom that lived at
#       sfincs_boundaries_gpu.cuf lines 336-337 and 361-363 before
#       Phase 4. A regex that only flags (a) would miss half the
#       regression surface; we flag both.
#
# An allowlist file (scripts/per-step-bridge-allowlist.txt) names the
# legitimate retained per-step bridges by exact `file:line:line-text`.
# Any new offending line that is not on the allowlist makes the script
# exit non-zero. The allowlist is intentionally narrow: every entry
# must be either a gated feature-boundary path (e.g. `if (use_qext_h)
# call bridge_in_cell_real4(qext, qext_h)`) or an output-reset-cycle
# path that has no on-device equivalent. Adding new entries is a
# deliberate decision and should be reviewed against the
# canonical-on-device invariant in docs/gpu_canonical_on_device.md.
#
# Comment lines (Fortran `!`) are excluded automatically: the line
# under test must begin (after optional whitespace) with the actual
# offending idiom, not with `!`.
#
# Usage:
#   scripts/check-no-per-step-bridges.sh
#   scripts/check-no-per-step-bridges.sh --list-offenders   # diagnostic
#
# Exit codes:
#   0 — no off-allowlist offenders
#   1 — one or more off-allowlist offenders found
#   2 — invocation / setup error

set -uo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
ALLOWLIST=$REPO_ROOT/scripts/per-step-bridge-allowlist.txt

FILES=(
    "source/src/sfincs_momentum_gpu.cuf"
    "source/src/sfincs_continuity_gpu.cuf"
    "source/src/sfincs_boundaries_gpu.cuf"
)

LIST_MODE=0
case "${1:-}" in
    --list-offenders) LIST_MODE=1 ;;
    "")               ;;
    *) echo "usage: $0 [--list-offenders]" >&2; exit 2 ;;
esac

if [ ! -f "$ALLOWLIST" ]; then
    echo "ERROR: allowlist not found at $ALLOWLIST" >&2
    exit 2
fi

for f in "${FILES[@]}"; do
    if [ ! -f "$REPO_ROOT/$f" ]; then
        echo "ERROR: missing source file $f" >&2
        exit 2
    fi
done

# Build the allowlist key set (associative array of trimmed
# file:line:line-text entries). Entries are exact-match.
declare -A ALLOWLIST_KEYS
while IFS= read -r line; do
    case "$line" in
        ''|'#'*) continue ;;
    esac
    ALLOWLIST_KEYS["$line"]=1
done < "$ALLOWLIST"

# trim_line — strip leading/trailing whitespace from $1.
trim_line() {
    local s=$1
    # leading
    s="${s#"${s%%[![:space:]]*}"}"
    # trailing
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

OFFENDERS=()
OFFENDER_KEYS=()

scan_file() {
    local file=$1
    local lineno=0
    local text trimmed lhs rhs lhs_base rhs_base key

    local code

    while IFS= read -r text; do
        lineno=$((lineno + 1))

        # Strip Fortran end-of-line comments (`! ...`) before pattern
        # matching. A line that is wholly a comment becomes empty and is
        # ignored. This avoids flagging commented-out historical idioms
        # in the explanatory comment blocks above each bridge.
        code="${text%%!*}"

        # Idiom (a): per-step bridge_in_* / bridge_out_* call. Matches
        # both bare `call bridge_...` and inline-if-guarded
        # `if (predicate_h) call bridge_...` lines. The leading-context
        # pattern (`^` or any non-identifier character) prevents false
        # matches on hypothetical identifiers like `recall_bridge_in_x`.
        if [[ $code =~ (^|[^a-zA-Z0-9_])call[[:space:]]+bridge_(in|out)_[a-zA-Z0-9_]+ ]]; then
            trimmed=$(trim_line "$text")
            key="$file:$lineno:$trimmed"
            OFFENDERS+=("$key")
            continue
        fi

        # Idiom (b): bare whole-array shadow assignment.
        # ^\s*<name>(_h)?\s*=\s*<name>(_h)?\s*$ where the base names match.
        if [[ $text =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*$ ]]; then
            lhs="${BASH_REMATCH[1]}"
            rhs="${BASH_REMATCH[2]}"
            # Strip optional `_h` suffix from each side to derive the base.
            lhs_base="${lhs%_h}"
            rhs_base="${rhs%_h}"
            # Flag only when both sides reference the same base name
            # but differ (i.e. one side carries `_h`, the other does not).
            if [ "$lhs_base" = "$rhs_base" ] && [ "$lhs" != "$rhs" ]; then
                trimmed=$(trim_line "$text")
                key="$file:$lineno:$trimmed"
                OFFENDERS+=("$key")
            fi
        fi
    done < "$REPO_ROOT/$file"
}

for f in "${FILES[@]}"; do
    scan_file "$f"
done

UNAUTHORIZED=()
for key in "${OFFENDERS[@]}"; do
    if [ -z "${ALLOWLIST_KEYS[$key]:-}" ]; then
        UNAUTHORIZED+=("$key")
    fi
done

if [ "$LIST_MODE" -eq 1 ]; then
    echo "--- offenders detected (all, before allowlist filter) ---"
    for key in "${OFFENDERS[@]}"; do
        echo "$key"
    done
    echo "--- allowlisted (suppressed) ---"
    for key in "${OFFENDERS[@]}"; do
        if [ -n "${ALLOWLIST_KEYS[$key]:-}" ]; then
            echo "$key"
        fi
    done
    echo "--- unauthorized (regression) ---"
    for key in "${UNAUTHORIZED[@]}"; do
        echo "$key"
    done
fi

if [ "${#UNAUTHORIZED[@]}" -gt 0 ]; then
    if [ "$LIST_MODE" -eq 0 ]; then
        echo "FAIL: canonical-on-device regression — unauthorized per-step bridge(s):" >&2
        for key in "${UNAUTHORIZED[@]}"; do
            echo "  $key" >&2
        done
        echo "" >&2
        echo "Each line above re-introduces a per-step host<->device copy of canonical" >&2
        echo "SFINCS state, which the Phases 1-4 refactor (SOR-65/66/67/68) eliminated." >&2
        echo "Either revert the change OR (if the new bridge is a legitimate feature-" >&2
        echo "boundary / output-flush sync point) add the exact file:line:line-text to" >&2
        echo "$ALLOWLIST" >&2
        echo "and document the rationale in the PR description that introduces it." >&2
        echo "See docs/gpu_canonical_on_device.md for the canonical-on-device invariant." >&2
    fi
    exit 1
fi

if [ "$LIST_MODE" -eq 0 ]; then
    echo "OK: ${#OFFENDERS[@]} allowlisted per-step bridge(s); no unauthorized regressions."
fi
exit 0
