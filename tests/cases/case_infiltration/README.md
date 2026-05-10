# case_infiltration

A small, fully self-contained SFINCS test case that exercises the infiltration
code path on the regular-grid mesh. The mesh, bathymetry, mask, and
single-harmonic M2 boundary tide are identical to `case_regular` (50x50 cells
at 100 m, flat shelf at -10 m on the western half ramping linearly up to +5 m
at the eastern edge); the case adds a zero-rate `precipfile = sfincs.prcp`
to satisfy SFINCS's gate that infiltration only initializes when
`precip = .true.`, and `qinf = 5.0` mm/hr to activate the spatially-uniform
constant infiltration variant (`inftype = 'con'`). Observed water-level
changes therefore come from the boundary tide minus infiltration losses on
wet cells, isolating the infiltration update in the time loop without
introducing any rainfall forcing. All input files are vendored as ASCII and
the case completes in a few seconds on the dev box.
