# Synthetic smoke case — boundaries + discharges + structures

Integration smoke for sub-epic `gpu-boundaries-discharges-structures` (SOR-651).
Exercises all three of the per-step modules ported in this sub-epic in a single
SFINCS run, kept minimal so the CPU↔GPU `zs` diff is easy to interpret.

| field         | value                                                       |
|---------------|-------------------------------------------------------------|
| grid          | regular 50×50 cells, dx = dy = 100 m, no rotation           |
| domain        | 0 ≤ x ≤ 5000 m, 0 ≤ y ≤ 5000 m                              |
| bathymetry    | linear west→east slope, zb = −3.0 m at m=1 → +1.9 m at m=50 |
| mask          | west column (m=1) is kcs=2 (water-level boundary), rest = 1 |
| boundary      | one bnd point at (0, 2500) m; tide = 0.5·sin(2π·t/3600)     |
| discharge     | one src point at (2500, 2500); q = 5 m³/s constant          |
| structure     | one weir along x = 2500 m, crest = 0.30 m, Cd = 0.6         |
| time          | tref = tstart = 2020-01-01 00:00:00; tstop = +1 h           |
| dtmapout      | 300 s (13 snapshots including t=0)                          |

The weir sits between the boundary and the source so both forcings push water
through the structure, exercising the structures kernel under flow, while the
tide drives the boundaries kernel and the source drives the discharges kernel.

Inputs are ASCII (`inputformat = asc`) and committed in this directory; no
generator step is needed at run time.

## Usage

Driver: `source/build_scripts/run_smoke_boundaries_discharges_structures.sh`.
See that script's `--help` output for build/run/diff options.
