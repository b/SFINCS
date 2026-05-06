# case_regular

A small, fully self-contained SFINCS test case that exercises the regular-grid
code path (no subgrid, no quadtree, no spiderweb, no infiltration, no
discharges, no structures) under a single-harmonic M2 tide imposed on the
western boundary. The grid is 50x50 cells at 100 m spacing, the bathymetry is
a flat shelf at -10 m on the western half ramping linearly up to +5 m at the
eastern edge (so the tide reliably wets and dries the shore), and the run
integrates 24 simulated hours. All input files are vendored as ASCII and the
case completes in a few seconds on the dev box, making it suitable as the
fast smoke layer of the GPU validation harness.
