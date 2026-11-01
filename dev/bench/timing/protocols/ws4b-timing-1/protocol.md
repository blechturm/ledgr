# Protocol ws4b-timing-1

This is the descriptive post-unification milestone owned by LDG-3170 and
LDG-3178. It uses the shared timing harness unchanged and sources the frozen
WS4a workloads by reference. Six cells cross the two execution clocks
(`bar_native` and `declared_sessions`) with no-fill, sparse-rebalance and wide
all-fill work. Each cell uses three alternating before/after pairs.

The timed boundaries and economic controls are exactly those in
`../ws4a-timing-1/protocol.md`. The names `dense` and `availability` occur only
in the inherited workload arguments needed to run an older comparison arm;
they do not name current product modes.

Two comparisons are recorded separately:

- `v0.2.2` to the candidate is the macro-rule-16 release reference;
- `b5622f09` to the candidate attributes the WS4b consolidation.

The 1.10 values are disposition triggers, not correctness gates. A failed
cell or a non-zero checker exit must be explained in the WS4b milestone record
and must not be hidden by changing an oracle, fixture, repetition count or
threshold. Phase attribution uses the package's existing fold-stage telemetry;
this protocol deliberately adds no second timer inside the fold.

Run with `dev/bench/timing/runner.R`, then reproduce with
`dev/bench/timing/check.R` as documented by the shared harness.
