#!/usr/bin/env bash
# Bootstrap the HydroMT-SFINCS preprocessing venv used by the per-case 4x
# generators (tests/cases/case_prod_*/generate.py).
#
# Idempotent: re-running on an existing venv exits 0 quickly without
# rebuilding. To force a clean rebuild, delete .venv/ first.
#
# Usage (from any directory):
#   bash tests/cases/preprocessing/setup.sh
#
# After the script reports success, the venv's Python lives at:
#   tests/cases/preprocessing/.venv/bin/python
# which per-case generators invoke directly.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
venv_dir="${script_dir}/.venv"
requirements_file="${script_dir}/requirements.txt"

# The HydroMT-SFINCS source tree must be available as a sibling of the SFINCS
# repo root (i.e. ../hydromt_sfincs from the repo root, three levels up from
# this script). Operators running the script from a non-standard checkout
# (e.g. a git worktree) can override the auto-detected path with the
# HYDROMT_SFINCS_DIR env var.
if [[ -n "${HYDROMT_SFINCS_DIR:-}" ]]; then
    hydromt_sfincs_dir="${HYDROMT_SFINCS_DIR}"
else
    repo_root="$(cd "${script_dir}/../../.." && pwd)"
    hydromt_sfincs_dir="$(cd "${repo_root}/.." && pwd)/hydromt_sfincs"
fi

if [[ ! -d "${hydromt_sfincs_dir}" ]]; then
    echo "ERROR: HydroMT-SFINCS checkout not found at ${hydromt_sfincs_dir}" >&2
    echo "Clone it as a sibling of the SFINCS repo:" >&2
    echo "    git clone https://github.com/Deltares/hydromt_sfincs ${hydromt_sfincs_dir}" >&2
    echo "Or override with HYDROMT_SFINCS_DIR=/path/to/hydromt_sfincs $0" >&2
    exit 1
fi

python_bin="${PYTHON:-python3}"
if ! command -v "${python_bin}" >/dev/null 2>&1; then
    echo "ERROR: ${python_bin} not on PATH (override with PYTHON=...)" >&2
    exit 1
fi

if [[ ! -x "${venv_dir}/bin/python" ]]; then
    echo "[setup] creating venv at ${venv_dir}"
    "${python_bin}" -m venv "${venv_dir}"
else
    echo "[setup] reusing existing venv at ${venv_dir}"
fi

venv_python="${venv_dir}/bin/python"
venv_pip="${venv_dir}/bin/pip"

echo "[setup] upgrading pip/setuptools/wheel"
"${venv_python}" -m pip install --upgrade --quiet pip setuptools wheel

echo "[setup] installing pinned requirements from ${requirements_file}"
"${venv_pip}" install --quiet -r "${requirements_file}"

echo "[setup] installing editable hydromt_sfincs from ${hydromt_sfincs_dir}"
"${venv_pip}" install --quiet -e "${hydromt_sfincs_dir}"

echo "[setup] verifying import smoke"
"${venv_python}" - <<'PY'
import hydromt_sfincs  # noqa: F401
from hydromt_sfincs.components.quadtree.quadtree_builder import build_quadtree_xugrid  # noqa: F401
print(f"hydromt_sfincs {hydromt_sfincs.__version__} OK")
PY

echo "[setup] done — venv ready at ${venv_dir}"
echo "[setup] invoke per-case generators with: ${venv_python} <generator.py>"
