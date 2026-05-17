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
