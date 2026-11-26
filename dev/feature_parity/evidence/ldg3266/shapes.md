# LDG-3266: the seven optimization shapes over the changed preparation code

Stage 3 was dropped (LDG-3265). At the final commit, R/ is byte-identical to
the workstream-43 close (2dee0f98): `git diff --stat 2dee0f98 <final> -- R
tests NAMESPACE DESCRIPTION` is empty. No preparation code changed, so no
shape can have been introduced or removed by workstream 44, and none is
walked here.

The rejected stage-3 implementations stay in history (dc70fc0d, ffe19415,
b56eaee9). The walk that matters for a later direct path is recorded in
LDG-3265's evidence: the per-instrument admission work inside the instrument
loop was the measured regression. The pre-existing per-instrument mask
construction in `ledgr_history_feature_inputs()` (about 80 ms of a 570 ms
preparation on 500 x 1,260) is routed to the macro plan.
