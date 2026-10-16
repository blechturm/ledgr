# Cut 16 cut review: causal history foundation

**Mode:** Type 1 cut review with independent input check.
**Reviewer:** Claude Opus, high effort, independent CLI session.
**Baseline:** `99a3b067`; draft uncommitted.
**Date:** 2026-10-16.
**Verdict:** `CHANGES_REQUIRED`, with one `NEEDS_TYPE_2` item.

The accepted architecture held. The draft adds no second reader, cache or
feature engine. The findings concern missing owners, contradictory acceptance
wording, detector independence and acceptance routing.

## Required findings

### R1. Retire all hydration seams

LDG-3064 omitted the stored `hydration_start_utc` fold column, the public
argument, the precompute `warmup_range` start and the
`ledgr_unsupported_hydration_start` and
`ledgr_precomputed_hydration_mismatch` conditions. Removing the stored column
requires a current-format bump and refusal of older stores. LTB/LCL-0197 must
be retired or rewritten for this exact v12 reason, beside the already named
LTB/LCL-0196 change.

### R2. Civil-time storage changes snapshot identity

LDG-3057 promised no snapshot-hash-rule change, but the current fact helper
drops an original `Date` after conversion to UTC midnight. V12 requires the
original civil value, resolved instant, venue zone and calendar identity.
The ticket must either prove those fields can be derived byte-identically or
bump the snapshot hash rule and current format. It must also own Date boundary
resolution for run, sweep, window and fold constructors.

### R3. Bind the public policy and its defaults

The cut had only an internal policy and called price carry optional. V12 binds
one public experiment-level policy with price-input carry enabled for five
expected sessions, output carry disabled with a mandatory finite age when
enabled, and `segment_limit = NULL`. Omitted and explicit defaults must be
identical, and LCL-0142/LCL-0274 must change only for this accepted behavior.

### R4. Complete the history-result and evidence contract

LDG-3062 omitted data/window starts, requested/available lookback, source
identity, before-window state, exact suffix behavior, known-but-inadmissible
explicit IDs, outside-axis refusal and the structural-completeness query.
LDG-3060, LDG-3062 and LDG-3066 also competed to define evidence. One ticket
must own the evidence vocabulary and the cut must name the completeness helper.

### R5. Narrow causality checks correctly

Exact sampled prefix invariance applies to every concrete definition,
including fn-only definitions. `fn(window_i)` versus
`series_fn(full_prefix)[i]` applies only to custom bounded definitions with
both functions. History-dependent pairs must not be refuted, and built-in
catalogue rows are certified in package tests rather than at runtime.

### R6. Preserve fold-stage ownership and complete substrate semantics

LDG-3059 contradicted the accepted fold synthesis by making P1 and P2 separate
readers. P1 is the sole reader; P2 adapts its values. Cursor services belong in
the WS38 service census and P3-P5 receive no history frame or substrate. The
ticket also omitted family-resolver reuse, four membership states, retained
winning fact/reason and separate family declaration/completeness.

### R7. Stage identity sensitivity with the introducing tickets

LDG-3058 cannot test declarations introduced only by LDG-3059, LDG-3060 and
LDG-3065. It owns the rule-4 frame and current inputs; each later ticket owns
its identity mutation. Final rule-4 fixtures are pinned only after WS43. The
treatment implementation version and declared-versus-assumed price basis are
also identity inputs.

### R8. Complete the correction-chain matrix

LDG-3057 omitted early-ending-successor refusal, sibling and unrelated
descendant competition, tied contradiction refusal and supersession before
precedence. Its `opposing overlap` phrase belonged to deferred lifetime-fact
work and must not enter this cut.

### R9. Carry the Section 10 owner map at cut time

The draft deferred ownership mapping to H6. Cut 16 must record the primary
owner of all eighteen v12 evidence groups now and distinguish contributors
and the routed WS7 consumer proof.

### R10. Route, do not execute, the WS7 consumer proof

V12 assigns the carried-share consumer proof to WS7 after H6. Cut 16 must
prove the field is reachable and durably hand WS7 its registered workload and
estimator-consequence obligation. It cannot wait for WS7 to close.

### R11. Distribute contract receivers

All 28 receiver edits were deferred to LDG-3070. V12 requires the implementing
ticket to rewrite its assigned group and remove its pending link. The cut must
carry an exact ticket-to-receiver map; the final teaching ticket verifies no
pending link remains. There is no live pipeline row to advance.

### R12. Add independent literal oracles

Several criteria only compared ledgr surfaces with each other. Frame, matrix,
scalar, entry-point and continuity fixtures need literal expected values,
timestamps and IDs. The continuity fixture must pin a last-pulse decision,
next-open fill and entitlement by value.

## Type 2 item

The accepted RFC requires availability-aware `ledgr_pulse_snapshot()` parity
under the same history policy and data start, but it does not say how the
standalone helper receives them. A public argument, an experiment handle or
another carrier is a maintainer decision. The reviewer did not choose.

**Maintainer disposition, 2026-10-16:** availability-aware pulse inspection is
external to strategy execution and derives from a `ledgr_experiment`, its
concrete parameters and cutoff. The experiment supplies snapshot, universe,
features, history policy, data start and opening state. Strategies never call
`ledgr_pulse_snapshot()` and continue to read history only through
`ctx |> ledgr_history_frame()`. The existing low-level snapshot-and-universe
form remains the dense inspection branch until execution-core consolidation.

## Should-fix items incorporated into the correction brief

- Make WS44 start only after both WS42 and WS43 are accepted.
- Resolve the LDG-3063/LDG-3067 precompute-file overlap with a dependency.
- Larger than two worker counts remain runnable but unmeasured.
- Pin baseline `99a3b067` and median-of-three in LDG-3069 acceptance.
- Cover anchored as well as rolling month folds and count one substrate build
  per walk-forward session.
- Bind exact empty wide, long and matrix shapes and matrix dimnames.
- Split the real-data record from contract/teaching closeout.
- Run an early aggregate-only segment census at LDG-3059.
- Add an early late-known numerical/mask oracle at LDG-3060.
- Pin corporate-action parent class and fields.
- Strengthen indicator-declaration contradictions and inactive-print rules.
- Correct stale register state, decisions owner, duplicate pending links and
  the ML pipeline source.

## Input and clean checks

H0, H1, WS39 and the spike closeouts are enough to cut. Nothing further must
be measured before implementation. Before H6 close, the cut still needs fresh
paired baseline/candidate records, both full aggregate Sharadar paths, the
post-substrate shared-memory trigger and logical-trace read peak.

The reviewer independently confirmed:

- `tickets.yml` parses, IDs are unique and dependencies resolve;
- `git diff --check` is clean apart from line-ending warnings;
- the documentation-contract suite passes;
- all 28 v12 receiver anchors carry a pending link;
- availability-only scope, one reader, the matrix adapter, history defaults,
  no carried returns/volatility, no carried-share threshold, estimator versus
  target separation, bounded `requires_bars`, per-segment restart, exact
  corporate-action clocks, helper deletion, the LTB-0196 reason, H6 gates,
  shared-memory trigger, aggregate-only private evidence and current-only
  compatibility policy all match v12.

Under M2 this finding-bearing review is retained here. A focused re-review is
required after the Type 1 patches and the maintainer's pulse-snapshot decision.
