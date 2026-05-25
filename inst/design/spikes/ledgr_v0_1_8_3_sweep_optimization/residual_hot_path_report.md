# v0.1.8.3 Residual Hot-Path Report

**Status:** Pending final post-change measurement; LDG-2409 checkpoint recorded.

This report is the evidence handoff from v0.1.8.3 to the next optimization
decision. It should answer:

- which workload improved;
- which workload regressed, if any;
- whether typed memory events and single-pass summary reconstruction moved the
  expected post-candidate reconstruction bottleneck;
- whether fold-context churn remains the next measured bottleneck;
- whether v0.1.8.6 Fast Context B1/B2 should remain the next optimization
  slice, be skipped, or be replaced by a different measured target.

## LDG-2409 Checkpoint

After LDG-2408/LDG-2409, the checkpoint measurement on commit `806ef00`
showed mixed workload results:

- reference `sweep_precomputed`: 45.490s baseline -> 43.235s checkpoint
  median, about 5.0% faster;
- reference `sweep_plain`: 45.585s baseline -> 47.835s checkpoint median,
  about 4.9% slower;
- persistent `sweep_plain`: 4.415s baseline -> 4.255s checkpoint median,
  about 3.6% faster;
- persistent `run_loop`: 9.420s baseline -> 10.420s checkpoint median,
  about 10.6% slower.

The profile confirms that `ledgr_features_wide()` is no longer a top frame, but
helper churn remains dominant: `ledgr_update_pulse_context_helpers()` sampled
at 26.3% and `ledgr_attach_feature_helpers()` at 20.3%. The retained
long-form `ctx$feature_table` data-frame contract also remains visible through
`data.frame` and related frames.

Decision: land Fast Context B1 before typed memory events. LDG-2414 must
recheck the committed-run loop regression after B1/B2 because the projection
setup cost is material on repeated single-candidate `ledgr_run()` workloads.
