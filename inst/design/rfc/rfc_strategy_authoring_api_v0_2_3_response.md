# Strategy Authoring API: Type 2 Response To Seed v1

2026-10-28. Non-binding response to the maintainer's Type 2 brief.
Reviewed seed and promoted inputs at `94e985d6`; executed prototype at
`spike/strategy-grammar`, `5db564df`. The seed's input documents were read
before its proposal. This is an own-session response to work that includes
this agent's earlier benchmark, not an independent certification of it.

**Verdict: USABLE_AFTER_CHANGES.** The allocation vocabulary earns a place in
the first CRAN API, but the seed is not ready to freeze: unknown preservation
decisions and state updates still have meanings a reader cannot see.

Keep ordinary `(ctx, params)` functions, complete quantity targets, the
decision-time context, long-only unlevered execution and existing stored
state. Maintainer decisions 1 and 2 stand: require a capital base in their
specified cases; sell index leavers only by explicit instruction. The changes
below neither reopen those decisions nor choose cash-shortfall fill policy.

## Findings, ranked by damage to readability

### F1 — High: the state shorthand hides replacement and mixes result fields with state

Seed §4.3 says “Portfolio state travels in `...`” and presents the view as
editable vectors. It omits the brief's consequential warning that unread
asset fields disappear. Probe `state_projection` starts with `peak`,
`cooldown`, `entry_atr`, portfolio `hwm` and `regime`. Reading only `peak`
and returning the view produces only that asset field and drops both
portfolio fields from the update. This follows existing replacement
semantics; it is not a fold defect. The problem is disguising a complete
state declaration as a convenient partial read.

Probe `state_edit` also assigns `NaN` to cooldown: serialization removes it,
and the next view supplies the default `0`. A failed calculation becomes
permission to re-enter. Scalar `memory$cooldown <- 0` loses axis names and
fails; `memory$cooldown[] <- 0` is the necessary ordinary-R operation.
Probe `result_note` finds that `ledgr_strategy_result(targets,
intent_reason = "stop_checked")` stores a state field and emits **zero**
intent diagnostics. A reader cannot infer that from a general result helper.

**Reshape before adoption.** Retain the asset view, require a complete field
declaration and reject undeclared stored fields rather than silently erase
them. Keep explicit `NA` as forgetting; reject `NaN` and infinity. Replace
portfolio-state dots with an explicit named state object, and expose result
metadata as result arguments. Candidate spelling, requiring a follow-up probe:

```r
# Before: result-looking arguments actually become replacement state.
ledgr_strategy_result(targets, hwm = hwm, asset_state = memory)

# Proposed: a complete portfolio-state object, named before the return.
portfolio <- list(hwm = hwm, regime = regime)
ledgr_strategy_result(targets, state = portfolio, asset_state = memory,
                      intent_reason = "stop_checked")
```

One flat list of portfolio fields earns its place by making their role
visible. Define omitted state versus explicitly empty state; the current
helper cannot express raw `state_update = list()` with an argument-free
return. Do not hide the existing raw return. Unchanged serialization alone
does not establish helper equivalence for resume or sweeps.
Authority: [outputs](../contracts.md#contract-strategy-outputs),
[state replacement](../contracts.md#contract-availability-context-and-state).

### F2 — High: an unknown `keep` decision silently becomes a sale

The seed's §4.2 example `keep = is.na(signal)` is sound. The general set
arguments are less safe than that example. In `unknown_keep`, the book is
SPY=500, AGG=100, GLD=400. The following returns SPY=0:

```r
ledgr_target_rebalance2(numeric(), ctx,
  keep = c(SPY = NA, AGG = TRUE, GLD = TRUE))
```

With `SPY = TRUE`, it returns SPY=500. The full target is valid, so this is
not a missing-target violation. It is an unstated missing-*decision* policy:
`NA` in `keep` becomes FALSE, which means sell under rebalance.
**Require non-missing logical decisions in `keep` and `exit`; reject unknowns.**
Teach an explicit choice before the call, such as
`keep <- is.na(signal) | signal > threshold`. This needs no extra class or
switch. Missing observations may exist; whether to preserve them is a rule.
Authority: [decision axis](../contracts.md#contract-strategy-decision-axis).

### F3 — Medium: the two verbs earn their split, but “adjust” does not explain its units

Seed §4.1 should survive. The `verbs` probe makes the distinction concrete:
rebalance to SPY=10% returns SPY=291, AGG=0, GLD=0; adjust to the same weight
returns SPY=291, AGG=100, GLD=400. Adjust **sells** 209 SPY shares; it is not
an increment. `add_value = c(SPY = 500)` instead returns SPY=508.
Empty adjust preserves the book; empty rebalance clears its eligible part.

**Keep both names; make the named argument carry the unit and direction.**

```r
ledgr_target_adjust(ctx, weights = c(SPY = 0.1), capital_base = "total_equity")
ledgr_target_adjust(ctx, add_value = c(SPY = 500))
```

Teach these as “set SPY to ten percent; leave everything else” and “add
five hundred dollars of SPY; leave everything else.” Do not describe both as
adding exposure. A third verb or an `otherwise` switch would add a choice
without resolving a new rule. Rebalance replaces the **eligible** allocation;
it cannot promise exactly ten holdings without the paragraph's explicit
index-leaver exit. Preserve decision 2 and teach that exception alongside the
first stock recipe, not in advanced documentation.
Authority: [target semantics](../contracts.md#contract-availability-targets).

### F4 — Medium: moving the schedule helps syntax, not mixed-cadence rules

Adopt §4.4's experiment argument. Reject the implication that this completes
schedule design or proves a new representation. Probe `schedule` uses a
stop already breached on the opening pulse. Daily scheduling records 1,045
checks and sells on January 2; monthly scheduling records 47 checks and
sells on February 1. The argument gates the **entire decision callback**,
including stops and state updates. “Monthly allocation with daily stops”
cannot acquire its monthly clock by setting this argument.

Teach `schedule` as decision cadence in the first monthly example, ahead of
state. A mixed-cadence strategy must keep daily decisions and gate its
allocation within the callback; any public calendar predicate should reuse
the existing calendar semantics and needs a separate executable example.
Do not invent another scheduler or fill path in this RFC.

The monthly experiment still contains a `ledgr_scheduled_strategy`: the
flattening prototype installs the existing decorator internally. **Replace
the public wrapper, retain that working internal representation initially.**
Amend scheduler D1's public construction rule; a change in metadata ownership
is unnecessary for readability. If the synthesis also moves ownership, it
must specify and verify config identity, extraction, resume, sweep and
walk-forward propagation; fill parity is insufficient evidence for those.
Authority: [fold core](../contracts.md#contract-execution-fold-core),
[scheduler D1](rfc_strategy_schedule_decorator_v0_1_9_x_synthesis.md#d1-representation-is-a-classed-function-not-a-closure-wrapper).

### F5 — Medium: the capital rule is binding; the sizing vocabulary is still incomplete

Keep decision 1 exactly. Probe `capital` gives SPY=582 under total equity,
481 under remaining equity, and a classed error when the base is omitted,
with the same preserved gold. An explicit exit releases that holding from
this decision's reservation. Replace §4.1's undefined “exited-later” wording
with a formula: `remaining_equity = max(0, equity - reserved_value - additions)`.
Here `reserved_value` marks positions preserved outside the weighted set;
`additions` reserves separately requested additions once. This is a sizing
budget, not settled cash or a promise about proceeds at execution.

Specify `invest_fraction` as a multiplier of the named base. It does not cap
the entire portfolio when other positions are kept. Document how unpriced
weighted holdings affect reservation; do not let an implicit budget change
stand in for the mandatory base choice.

The seed also claims coverage of all sixteen examples while leaving
`fit_to_remaining` undecided and promising weights sum to at most one.
Turtle uses that argument. Probe `fit` rejects SPY weight 2 without it but
accepts it with a 98% cap and produces a marked target book below equity.
That demonstrates a mismatch between the seed and its evidence, not
permission to expose levered weights. **A decision-time cap belongs to
authoring if retained; keep weight validation strict.** Convert gross risk
requests to bounded allocations in a named sizing step before treating them
as weights. Its spelling and Turtle parity need proof; the current exception
must not silently become the public contract. Cash-shortfall fills remain
outside this RFC. Authority: [helper values](../contracts.md#contract-strategy-outputs).

### F6 — Medium: “plain R first” is not “one reader and no lists”

Seed §4.4 says reads stay `ctx$vec$feature("name")`. Probe `features` shows
that feeding this plane into `ledgr_select_top()` fails; the supported
`ledgr_signal_feature()` reader succeeds and carries STK04's ineligibility.
Teach both by purpose: raw aligned values for conditions; a named signal
with eligibility for ranking. Do not conceal the latter reader as machinery.

The same section's “Params are named vectors, not nested lists” overstates
its own input. The brief's example is correctly:

```r
params <- list(weights = c(SPY = 0.6, AGG = 0.4), band = 0.05)
```

Keep the heterogeneous parameter list; use vectors for homogeneous fields.
Named setup steps help when the name identifies an idea, such as a skipped
month. Naming every one-use constructor merely replaces nesting with lookup.
Evaluate the whole recipe, including feature declaration and cadence; do
not count moving words out of the callback as removing concepts.

### F7 — Low: narrow the claims to the experiment actually performed

The inputs support expressibility and selected fill equivalence, not novice
comprehension. bt still leads standard recipes; PMwR still has simpler scalar
setup; ledgr's distinction is explicit preservation. Those are informed
judgments, not measured reader scores. Remove §2's “equal or faster”
end-to-end claim: the closeout reports Connors at 1.07 times baseline.
The state timing had 300 IDs but only 30 stored entries; it is not evidence
for a densely populated wide state store. Remove the unsupported quantstrat
comparison from §7 or provide its own attributable evidence. None of these
changes needs another broad framework benchmark.

## Answers to the twelve seed questions

| # | Disposition and evidence boundary |
| --- | --- |
| 1 | **Maintainer decision.** Retain and disclose the existing cash=100000 opening default; keep cost choice explicit. The executed defaults variants show two fewer setup lines and identical fills, not a universally appropriate model. No universal nonzero cost is defensible either. Drop “zero flatters every result”: the measured comparison used identical zero costs and did not establish that claim. |
| 2 | **Keep the raw structured return public.** The output contract already permits it. It expresses complete state replacement, explicit empty state and `intent_reason`; the current helper does not cover them all. Teach the helper where it reduces work, without turning ordinary lists into a private escape hatch. See F1. |
| 3 | **Decision-time sizing here; fill allocation elsewhere.** Resolve F5's cap/weight-validation conflict before claiming Turtle coverage. Neither automatic weight normalization nor a levered target is an acceptable shortcut. |
| 4 | **Advisory early warning only.** An inspected opening pulse can expose an existing reservation; arbitrary callbacks, future signals and holdings prevent a general preflight guarantee. Keep the authoritative check at each decision, identify the reserved IDs/value in its error, and offer the two named bases. Do not run the strategy early against invented context or require a base everywhere. |
| 5 | **Keep the eligibility-bearing buy selection; ordinary holding masks suffice.** This is not a choice between two wholly plain sets: the existing selection already carries eligibility. Require strict mask validation per F2; another holding-set class has no demonstrated readability benefit. |
| 6 | **Holding value is quantity times the permitted decision valuation mark, with zero for unheld IDs.** It is currency exposure, without normalization. Current weights add denominator, cash, missing-mark and coverage policies; those belong to portfolio construction. A price-times-quantity accessor must not silently settle them. |
| 7 | **Defer the entry-price plane.** “Entry” needs an accounting definition across additions and partial exits, and ATR at entry remains strategy state. No probe here establishes the right definition. Route it to context/accounting design rather than claim that the plane removes Turtle state. |
| 8 | **Preserve axis IDs, eligibility and existing origin metadata; promise no general decision graph.** Literal feature names and explicit sizing arguments are useful inputs to later recording. Ordinary arithmetic and raw returns are not a guaranteed recording protocol. A future recorder must define operation/parent identity, parameters and decision provenance before promising explanations; do not burden today's author with registrations for it. |
| 9 | **Keep `ledgr_target_rebalance` and `ledgr_target_adjust`.** They are already target-family names. The actual F8 conflict is verb-first exports such as `ledgr_select_top`. Explicitly amend the allowlist for the chosen strategy helpers and reconcile `ledgr_passed_warmup`/`ledgr_align_weights`; current exports are not permission. Prefer the readable selection verbs over noun-heavy renaming. See [naming contract](../contracts.md#contract-public-name-shapes) and inventory H3. |
| 10 | **Separate-capital/state strategy trees are outside this release's authoring core.** Route capital reservation and combination to portfolio construction, with state ownership and cadence specified alongside it. Ordinary composition inside one callback remains useful; it does not establish independent subportfolio semantics. The seven-rule benchmark proves no equivalence to bt's trees. |
| 11 | **A direct reader is a reasonable small follow-up, not a CRAN prerequisite.** Failure of the extra view binding does not test `ctx$features$name`. Probe `features` also finds `ctx$features` is already a function, so this is a deliberate context-surface replacement. Any candidate must stay strict, lazy and eligibility-aware; keep the two working readers meanwhile. |
| 12 | **No evidence requires a storage change before CRAN.** Keep the list-per-ID contract. The measured view improves authoring and the tested read/write workload; it does not settle wide, dense state costs. Profile such a workload before a separate storage RFC, including versioning and resume identity. |

## Evidence, limits and requested revision

The new probe artifacts are on `spike/strategy-grammar` under
`dev/spikes/strategy-grammar/rfc_response/`: `probe.R`, `check.R`,
`probe_findings.md`, `inventory.md`, and `evidence/`. They are uncommitted;
this response is in the main worktree. Nine cases use the existing sealed
simulated snapshot and `pkgload::load_all()`. Target and feature observations
use public experiment-derived pulses. State-shape observations use the
documented snapshot pulse with explicit previous state; they are not a
resume test. Schedules and decision notes run through `ledgr_run()` and
native fills/diagnostics. Input identity and R/package versions are recorded
in `evidence/environment.txt`; there is no performance claim in this probe.

From `C:/Users/maxth/ledgr-wt/strategy-grammar`:

```powershell
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" dev/spikes/strategy-grammar/rfc_response/probe.R
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" dev/spikes/strategy-grammar/rfc_response/check.R
```

The checker reproduced all three recorded CSVs byte for byte and preserved
package/design scope. Removing the monthly schedule in a scratch run failed
the fill comparison as intended. These observations characterize defects as well as valid
behavior; reproducing them is not a public-API acceptance test. Existing
stage-3 and flattening parity remains prior evidence, not newly asserted
coverage of the seed. No product code or stored format was changed.

Revise the seed around the two useful target verbs, explicit state/result
roles, strict preservation decisions, and a schedule argument with its
existing internal compiler path. Resolve the bounded-sizing conflict and
correct the teaching/evidence claims before freezing the CRAN surface.
Keep feature-view sugar, recording, entry accounting, subportfolio trees and
storage redesign off that critical path. Review record: one own-session
Type 2 invocation; F1–F7 are proposed changes, awaiting maintainer disposition.
