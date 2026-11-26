# LDG-3266: the seven optimization shapes over the changed preparation code

Stage 3 was dropped (LDG-3265). At the final commit, R/ is byte-identical to
the workstream-43 close (2dee0f98): `git diff --stat 2dee0f98 <final> -- R
tests NAMESPACE DESCRIPTION` is empty. No preparation code changed, so no
shape can have been introduced or removed by workstream 44, and none is
walked here.

The rejected stage-3 implementations stay in history (dc70fc0d, ffe19415,
b56eaee9). What the evidence supports (LDG-3265): the measured candidates
saved on the fully admitted and PIT cells and regressed on the custom-only
and zero-admission cells. Diagnostic probes
(`dev/bench/v0_2_3_cut24_feature/probes_ldg3265/`) point at per-instrument
admission work on the zero cells without establishing the cause; the cause
on the custom cells, which run no gate, is unexplained. The pre-existing
per-instrument mask construction in `ledgr_history_feature_inputs()` (about
80 to 100 ms of a preparation of about 0.6 s on 500 x 1,260, descriptive) is
routed to the macro plan.
