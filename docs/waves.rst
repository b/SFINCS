Wave input
=======

Introduction 
----------------------

The input of waves as boundary conditions is still work in progress. Right now the following files should not be used:

bwvfile = ''

bhsfile = ''

btpfile = ''

cstfile = ''

Choosing ``dtwave``
-------------------

``dtwave`` controls how often SFINCS exchanges water levels and wave
forcing with the SnapWave solver (the "wave coupling cadence"). It is
the single highest-leverage performance knob for any case that runs
with ``snapwave = 1``: SnapWave runs ``tstop / dtwave`` times over the
simulation window, and each call is a non-trivial host-side solve.
Halving ``dtwave`` doubles the number of SnapWave calls; doubling it
halves them.

The SFINCS code default is ``dtwave = 3600.0`` s (one update per
simulated hour). The widely-used HydroMT-SFINCS setup tool, however,
ships a default of ``1800.0`` s for compound-flood templates. These are
two different defaults — neither is a physical lower bound on the
coupling cadence. The right value depends on how fast the wave climate
evolves over the case being simulated.

Wall-clock impact
~~~~~~~~~~~~~~~~~

The table below summarises the empirically measured trade-off for
``case_prod_compound_snapwave`` (24 simulated hours, ~1.07 s SnapWave
wall per call on the development workstation; numbers extracted from
``tests/perf/snapwave-characterization-20260517/SUMMARY.md``):

+----------------------+-------+----------------+----------------+-----------------+
| ``dtwave``           | calls | SnapWave wall  | total sim wall | δ vs 1800 s     |
+======================+=======+================+================+=================+
| 900 s                | 96    | ~103 s         | ~117 s         | +85 % slower    |
+----------------------+-------+----------------+----------------+-----------------+
| **1800 s** (HydroMT) | 48    | ~51 s          | ~64 s          | baseline        |
+----------------------+-------+----------------+----------------+-----------------+
| 3600 s (SFINCS dflt) | 24    | ~26 s          | ~39 s          | −39 % faster    |
+----------------------+-------+----------------+----------------+-----------------+
| 7200 s               | 12    | ~13 s          | ~26 s          | −59 % faster    |
+----------------------+-------+----------------+----------------+-----------------+

Doubling ``dtwave`` from 1800 s to the SFINCS code default of 3600 s
cuts total wall clock by roughly 40 % for this case without any code
change. The savings are linear in the number of SnapWave calls
avoided, so the same lever applies to any case that runs SnapWave.

Choosing a value
~~~~~~~~~~~~~~~~

``dtwave`` is a per-case engineering decision, not a one-size-fits-all
constant. Pick the cadence that matches how fast the wave climate
evolves in the storm being simulated:

* **Fast-moving systems** (e.g. landfall windows of a fast-moving
  hurricane, where wave height and direction shift on 30-minute
  scales) may genuinely need ``dtwave = 1800`` s or finer.
* **Slow-moving compound-flood systems** (e.g. a tropical cyclone
  stalling offshore, a multi-day storm event with slowly varying
  Hs/Tp/direction) typically tolerate ``dtwave = 3600`` s or larger
  without changing the simulated zsmax envelope meaningfully.

When in doubt, **consult the science owner of the case** before
raising ``dtwave`` above what the storm forcing requires. The model
will run with whatever value is in ``sfincs.inp``; SFINCS does not
auto-correct.

Runtime advisory
~~~~~~~~~~~~~~~~

When ``sfincs.inp`` sets ``dtwave`` below the SFINCS code default of
3600 s, SFINCS emits a one-line ``Info`` advisory at the top of the
log noting the override and pointing back to this section. The
advisory is informational only: the user-provided ``dtwave`` is always
honored.

References
~~~~~~~~~~

The wall-clock figures and the underlying physical-justification
discussion come from the SnapWave host-side characterization in
``tests/perf/snapwave-characterization-20260517/SUMMARY.md``, in
particular the section "``dtwave`` coupling frequency — assessment".

SnapWave directional-grid memoization
-------------------------------------

On every SnapWave coupling step the boundary update rebuilds a partial
directional grid (``theta``, ``w``, ``prev``, ``ds`` and the
direction-only part of ``windspreadfac``) by gathering from the
precomputed 360-direction tables in
``make_theta_grid`` (``source/src/snapwave/snapwave_boundaries.f90``).
That gather is a deterministic function of the central mean wave/wind
direction, and it enters the computation only through the integer index
``ind = nint(central_theta/dtheta) - ntheta/2``.

As of SOR-82 (the follow-up to SOR-81's host-side characterization,
``tests/perf/snapwave-characterization-20260517/SUMMARY.md``, which
measured ``make_theta_grid`` at ~22 % of SnapWave compute on
``case_prod_compound_snapwave gpu_n2``), the rebuild is memoized: when
``ind`` matches the value cached from the previous call the gather is
skipped, because the persistent module-level arrays already hold the
correct values. This is the discrete form of the SOR-82 spec's
``dtheta/2`` recompute threshold — two central directions produce the
same ``ind`` if and only if their difference is too small to move
``nint(central_theta/dtheta)`` by one, i.e. less than half a
``dtheta``-wide theta cell. When wind growth is enabled the wind block
still runs every call, because ``windspreadfac`` is then re-derived
from per-node ``u10dir`` and varies independently of the central
direction; the SnapWave physics and numerical scheme are unchanged.

The cache is invalidated at SnapWave initialisation in
``initialize_snapwave_domain``
(``source/src/snapwave/snapwave_domain.f90``) so that the first call
after model startup or restart always rebuilds and a fresh
``w``/``prev``/``ds`` allocation can never be paired with a prior run's
stale grid. The memoization is unconditional behaviour with no
configuration knob; to disable it for debugging, force the guard in
``make_theta_grid`` to always rebuild by removing the
``.not. (theta_grid_valid .and. ind == last_theta_ind)`` condition.

The post-memoization profile, including the before/after top-routine
table and the wall-clock comparison, is in
``tests/perf/snapwave-memoize-20260517/SUMMARY.md``.
