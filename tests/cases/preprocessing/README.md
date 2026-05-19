# HydroMT-SFINCS preprocessing environment

Pinned, reproducible Python environment used by the in-tree per-case
generators (`tests/cases/case_prod_*/generate.py`) that build quadtree
meshes, subgrid tables, and forcing files with [HydroMT-SFINCS].

## Layout

```
tests/cases/preprocessing/
├── requirements.txt   # full pip-freeze pins (transitive closure)
├── setup.sh           # idempotent bootstrap (creates .venv, installs deps)
├── .venv/             # created by setup.sh; gitignored
└── README.md
```

## Pinned HydroMT-SFINCS version

The venv installs HydroMT-SFINCS in editable mode from the sibling checkout
at `../hydromt_sfincs` (i.e. a sibling of the SFINCS repo root). The version
pinned for the current `requirements.txt` is:

| Field | Value |
| --- | --- |
| Git SHA | `d8514d644f297b6b3982c249c3c233dfdf5076fb` |
| Date | 2026-04-22 |
| Subject | `Simplify linestring2gdf, drop elevation handling (#374)` |
| Upstream | https://github.com/Deltares/hydromt_sfincs |
| Package version | `2.0.0-rc2` |

The sibling checkout location matches the layout already assumed by the
`generate.py` scripts (`Path(__file__).parents[3].parent / "hydromt_sfincs"`).
If the operator has cloned HydroMT-SFINCS elsewhere, override the location
with the `HYDROMT_SFINCS_DIR` env var when invoking `setup.sh`.

## Bootstrap

From any directory inside the repo:

```bash
bash tests/cases/preprocessing/setup.sh
```

The script:

1. Creates `tests/cases/preprocessing/.venv/` if it doesn't exist (reuses it
   on re-run).
2. Upgrades `pip`, `setuptools`, `wheel` inside the venv.
3. Installs `requirements.txt` (pinned transitive closure).
4. Installs `../hydromt_sfincs` in editable mode (`pip install -e`).
5. Runs the import-smoke command below; exits non-zero on failure.

Re-running on an already-populated venv is a no-op (re-uses the existing
venv, pip recognises the installed pins, the editable install is already
linked) and completes in seconds. To force a full rebuild, delete
`.venv/` first.

## Verifying the venv

Operators can re-run the import-smoke command directly:

```bash
tests/cases/preprocessing/.venv/bin/python -c \
  'import hydromt_sfincs; from hydromt_sfincs.components.quadtree.quadtree_builder import build_quadtree_xugrid'
```

Exit code 0 confirms the venv is usable for the per-case generators.

## Invoking the per-case generators

Per-case 4x generators in this plan (e.g.
`tests/cases/case_prod_quadtree_subgrid_tide/generate.py`,
`tests/cases/case_prod_compound_snapwave/generate.py`, plus the additional
generators landing in subsequent issues) call this venv's Python directly,
e.g.:

```bash
tests/cases/preprocessing/.venv/bin/python \
    tests/cases/case_prod_quadtree_subgrid_tide/generate.py \
    --out tests/cases/case_prod_quadtree_subgrid_tide
```

This replaces the ad-hoc `/tmp/sfincs-hydromt-venv/` path the earlier
docstrings reference.

## Bumping the pinned version

1. Update the sibling `../hydromt_sfincs` checkout (`git fetch && git checkout <new-sha>`).
2. Record the new SHA, date, and commit subject in the table above.
3. Delete the existing venv: `rm -rf tests/cases/preprocessing/.venv`.
4. Re-run `bash tests/cases/preprocessing/setup.sh` to rebuild against the new SHA.
5. Refresh `requirements.txt`:

   ```bash
   tests/cases/preprocessing/.venv/bin/pip freeze --exclude-editable \
     > tests/cases/preprocessing/requirements.txt.body
   ```

   Replace everything below the header block in `requirements.txt` with
   the new body (preserve the header comments — they document the policy).
6. Re-run every affected `generate.py` against the new venv to confirm no
   generator regresses; commit the refreshed `requirements.txt` and the
   new outputs together.

[HydroMT-SFINCS]: https://github.com/Deltares/hydromt_sfincs
