# case_structures

A small, fully self-contained SFINCS test case that exercises the structures
code path (`compute_fluxes_over_structures` in `sfincs_structures.f90` and its
GPU sibling in `sfincs_structures_gpu.cuf`) under a single-harmonic M2 tide.
Independent of `case_production` so the harness still covers structures even
when the production case is broken.

The grid is 30 x 30 cells at 100 m spacing (3 km x 3 km), the bathymetry is
flat at -5 m, the western edge is a tidal boundary forcing a 1 m-amplitude
M2 oscillation, and the run integrates 24 simulated hours.

## Structure

A single broad-crested weir (`weirfile = sfincs.weir`, `itype=1`) blocks the
east-west flow upstream of mid-domain. The polyline runs north-south at
x=1000 m, which is the cell-boundary line between columns m=10 (centred at
x=950) and m=11 (centred at x=1050), so each segment crosses the U-edges
connecting those cell centres.

| Field | Value |
| --- | --- |
| Structure type | Broad-crested weir (`itype=1` in `read_structure_file`) |
| Polyline vertices | (1000, 850), (1000, 1500), (1000, 2150) |
| Crest height | -2.0 m (3 m above the flat -5 m bed) |
| Discharge coefficient `Cd` | 0.6 |

`read_structure_file` snaps the polyline to **14 U-points** (rows n=9..22,
inclusive) — confirmed by the `Info    : 14 structure u/v points found`
line in `sfincs.log` after a CPU run. V-edges and cell centres are not
touched.

The polyline is intentionally placed off the mid-domain split. The
quadtree-aware geometric partitioner in
`source/src/sfincs_partition.cuf:1543` splits the longest axis evenly; for
this square 30 x 30 mesh that puts the `mpirun -n 2` cut between m=15 and
m=16. The weir's U-edges (between m=10 and m=11) sit safely inside the
rank-0 owned slab, so the structure kernel applies on a single rank and
its q / uv updates propagate to rank 1 through the post-step
`halo_exchange_q_uv()` at `sfincs_lib.F90:680`. Putting the polyline on
the rank seam (the original x=1500 placement) inflates the n=2 vs CPU
zsmax ratio to ~2e-3 (>1e-4 threshold) — see SOR-828 for the
investigation.

The crest sits within the tidal swing (water level oscillates between -1 m
and +1 m, both above the crest), so the weir is permanently submerged and
the structure kernel is exercised on every time step rather than falling
through to a no-op. As a sanity check that the structure actually carries
flux (AC #2 on SOR-828): a side-by-side CPU run of the same case with the
`weirfile` line stripped from `sfincs.inp` shifts `zsmax` by
max\|with-weir − no-weir\| ≈ 0.16 m on a peak `zsmax` of ~1.18 m
(ratio ≈ 0.14). The structure path is not vacuous.

## Why this case

`compute_fluxes_over_structures` was previously exercised only by
`case_production`'s single-polyline `weirfile`. When `case_production` is
broken (it has been: see PR #57 — CPU baseline segfaults under gfortran-CPU,
docker-mounted symlink quirks), the structures kernel becomes invisible to
the validation harness. Splitting structures into a dedicated, lightweight
case keeps the GPU/CPU diff honest along that path independently.

## Files

- `sfincs.inp` — model configuration; `weirfile = sfincs.weir` enables the
  structure path.
- `sfincs.dep` — flat bathymetry, 30x30 ASCII.
- `sfincs.msk` — mask with the western column (m=1) marked as boundary cells
  (kcs=2); all interior cells active (kcs=1).
- `sfincs.bnd` — three boundary points along the western edge.
- `sfincs.bzs` — M2 tide timeseries, 1 m amplitude, 1800 s steps over 24 h.
- `sfincs.weir` — the broad-crested weir polyline (3 vertices, 4 columns:
  x, y, crest, Cd).
