# Type 2 Response: Strategy Scheduling And Held-Pulse Skipping

**Status:** Response complete; disposition `REVISE_SEED`.
**Mode:** Type 2 design response.
**Date:** 2026-10-25.
**Author:** Codex, responding to Claude's seed v1.
**Reviewed tree:** `1cd4e0c9` on `v0.2.2`.
**Question:** Does the staged schedule-decorator seed still describe the
smallest correct architecture now that ledgr has a five-stage fold, causal
history, measured held-pulse costs and a production trajectory?

This is a challenge artifact, not accepted design. It does not authorize code,
contracts or tickets.

## 1. Disposition

`REVISE_SEED`.

The user-facing idea survives: scheduling belongs outside the strategy
callback, should compose with an ordinary strategy, should be deterministic
and identity-bearing, and should work through run, sweep, walk-forward and
promotion. The measured H1 result also justifies doing the work. On the
registered 7,213-pulse workload, 6,868 non-decision pulses spend 14.17 seconds,
or 22.6 percent of public-run wall, in context construction, callback and
target work that a scheduler may avoid.

The seed's internal architecture does not survive. It predates the accepted
five-stage fold and still treats a decorator as an ordinary wrapper that
receives `ctx` and emits hold-shaped targets. That shape cannot recover the
measured cost: by the time the wrapper receives `ctx`, P2 has already built the
public frames and context. It also conflates two different events:

- the strategy was invoked and deliberately chose to hold; and
- the strategy was not scheduled and therefore was not invoked.

Seed v2 should retain the pipeable public UX while replacing the opaque
runtime wrapper with an inspectable strategy declaration compiled before the
fold. The compiled schedule should gate P2. P1 must still observe and settle
every pulse, and P5 must still finish the pulse. No second fold, no separate
"fast" semantics and no event-to-event jump are required for the first
implementation.

No prerequisite spike is needed. The current fold boundaries, measured H1
record and public-path probes are sufficient to write seed v2. A later
event-to-event accelerator would need its own evidence.

## 2. Evidence And Current Architecture

### 2.1 The cost is real and material

The WS53 closeout measures the opportunity rather than inferring it from a
microbenchmark. The representative run has 345 monthly decision pulses and
6,868 held pulses. Context, callback and target work on those held pulses costs
14.17 seconds. The record correctly calls that a lower bound: settlement,
valuation, fills, state handling, diagnostics and commit work cannot simply be
discarded.

That distinction matters. The scheduler is not permission to skip a pulse. It
is permission to skip the decision work on a pulse that is known not to be a
decision pulse.

### 2.2 The fold now supplies the correct seam

The accepted fold-phase synthesis and the implementation in
`R/fold-engine.R` divide one pulse into:

1. P1, observe and settle;
2. P2, build the public context and decide;
3. P3, plan execution;
4. P4, apply economic events; and
5. P5, commit the pulse.

P2 constructs the public frames and context and calls the strategy. That is
the stage the H1 measurement says can be absent on a non-decision pulse. P1
still owns market observation, corporate actions, dispositions, valuation and
equity. P5 still owns reconciliation, strategy-state persistence, telemetry,
checkpoint and interrupt duties. P3 and P4 may receive a typed no-decision
input or be bypassed by the existing envelope only where their work is empty;
the RFC must not invent a second orchestration path.

### 2.3 The public UX already points in the right direction

The Research Strategy UX Brief illustrates:

```r
strategy <- portfolio_strategy |>
  ledgr_on_schedule(ledgr_month_end())
```

That reads well and keeps scheduling outside research logic. The response does
not require those exact names, but seed v2 should test its proposal against
that shape. The important correction is that "pipeable" need not mean "an
opaque closure that learns the schedule after `ctx` exists."

## 3. Findings

### F1. The seed defers the very optimization that justified reopening it

Section 8 says the first implementation still receives `ctx` on held pulses
and leaves skipped context construction to a later optimization. That was
reasonable in June. It is no longer reasonable after H1 measured context,
callback and target work together and promoted the RFC specifically to remove
that cost.

An ordinary wrapper around `function(ctx, params)` can skip only the inner
callback. It cannot skip P2 frame slicing, context construction or wrapper
invocation. Seed v2 should make the schedule visible before P2 and treat
avoiding public-context construction on non-decision pulses as core scope.

### F2. "Returns an ordinary strategy" is an implementation constraint, not a UX requirement

Current experiment validation accepts an ordinary strategy function, and
`ledgr_strategy_spec()` records function source and provenance. That does not
mean the scheduled form must remain indistinguishable from a bare function
inside the engine.

The scheduled value may remain callable or function-like for authoring, but it
must be inspectable by experiment compilation. The compiler needs to recover:

- the inner strategy;
- the declarative schedule;
- the schedule rule version; and
- any resolved schedule parameter.

If it cannot do that without calling the wrapper at a pulse, the design cannot
meet its own performance goal. Seed v2 should specify the semantic declaration,
not prematurely bind whether R represents it as a classed function, a classed
object or another small constructor result.

### F3. A general `function(ctx)` predicate defeats the fast path

The proposed predicate escape hatch requires the public context whose
construction the scheduler is meant to avoid. It also turns a deterministic
calendar declaration into arbitrary strategy code with feature access, state
questions and provenance complexity.

These are two different concepts:

- a **schedule**, decidable from declared calendar and pulse primitives before
  P2; and
- a **decision gate**, evaluated from strategy-visible data after some or all
  of P2 exists.

Seed v2 should keep the first implementation declarative. A later decision-gate
surface may compose with a schedule, but it should not be called a zero-cost
schedule or used as evidence for held-pulse savings. If v2 retains a predicate,
it must state that the predicate path cannot skip context construction and is
outside the H1 performance claim. The smaller and clearer choice is to defer
it.

### F4. A fabricated hold target is not the right internal result

`ctx$hold()` means the callback ran and chose current holdings. It may carry
notes or state, participate in strategy diagnostics and trigger normal target
validation. "Not scheduled" means none of that happened.

The fold needs an internal typed no-decision result, such as
`not_scheduled`, rather than a manufactured target vector. It should preserve
current economic holdings without pretending the strategy emitted a target.
This distinction should appear in telemetry and diagnostics:

- decision pulse: P2 ran and produced a strategy result;
- scheduled skip: P2 did not run;
- explicit hold: P2 ran and the strategy chose no target change;
- warmup or other refusal: the existing typed reason applies.

This type is internal. The response does not propose another public intent
class.

### F5. The stage behavior on a skipped pulse is underspecified

The seed says "skip-callback" and then reasons from an emitted hold target.
That no longer maps cleanly onto the accepted stage boundaries. Seed v2 should
state the single-fold behavior explicitly:

- P1 always runs;
- the schedule verdict is available before P2;
- P2 is absent when not due;
- no new-target P3 planning is performed when not due;
- already-due economic obligations are not cancelled by the schedule;
- P4 remains available to apply any legitimate economic events; and
- P5 records and commits the pulse using a typed no-decision input.

This preserves production semantics. A live process still handles every
pulse; it merely avoids research-decision work when the declaration says no
decision is due.

### F6. The calendar semantics are not precise enough for intraday use

The seed describes rules against a "pulse calendar" and calls the menu EOD
clean. That risks baking daily assumptions into names such as `month_start`.
With multiple pulses in one venue session, "the first pulse whose month
differs" is not enough: it may select a time rather than a session boundary.

Seed v2 should derive period membership from the authoritative expected venue
session axis and then specify which pulse in the selected session is the
decision pulse. The schedule must not derive months from observed bars, local
wall-clock formatting or the accidental absence of a print.

This does not require full intraday execution in v0.2.2. It requires a rule
that does not make future intraday capability ambiguous. A suitable conceptual
split is:

- session selection: first or last expected session of a period; and
- pulse selection within that session: a declared boundary supported by the
  experiment's pulse axis.

Seed v2 may deliberately cut the first implementation to one pulse per
session, but then it must refuse an ambiguous multi-pulse axis rather than
silently choosing.

### F7. Fold and window boundaries need one global rule

A schedule recomputed independently inside every walk-forward window can turn
the first pulse of each fold into a false month start. Conversely, a run that
starts halfway through a month needs an explicit answer: wait until the next
declared boundary, or force a first decision at the run start.

The safer default is to compile the schedule on the authoritative parent
session axis and slice it to run or fold windows. Then a partial first period
does not become a new calendar period merely because scoring began. Whether an
opening allocation is separately permitted remains an opening-policy question,
not an implicit scheduler exception.

Seed v2 should bind or escalate this choice and test run, sweep and
walk-forward parity.

### F8. `month_end` requires declared future calendar knowledge

"Last observed pulse before the month changes" is unsafe in production: the
engine cannot infer a month end from a missing future print. A period-end rule
is valid only when the expected session calendar declares the next boundary.

This is not lookahead into market data. It is use of a declared venue calendar.
Seed v2 should say so and refuse period-end schedules when the necessary
calendar knowledge is unavailable. Explicit dates need equally precise
off-session behavior; "snap forward" must use expected sessions and refuse
beyond the declared axis.

### F9. The sweepability claim is incorrect as written

`ledgr_param()` currently parameterizes feature declarations. It is not a
generic placeholder that arbitrary constructors automatically resolve. The
seed's claim that a scheduled strategy can use `ledgr_param("rebalance")`
with "zero new sweep machinery" is therefore unsupported.

The existing strategy grid already carries ordinary strategy parameters, but
a schedule must be resolved before the fold and must participate in candidate
identity. Seed v2 should choose one explicit route:

- schedule values are ordinary named strategy-grid parameters consumed by the
  scheduled declaration; or
- schedule declarations gain a deliberately extended parameter resolver.

Either route requires validation, resolution and provenance work. Reusing a
surface may be desirable; claiming it happens automatically is not.

### F10. Identity must cover semantics, not a derived mask artifact

The identity-bearing inputs should include the schedule declaration, its
resolved value and a rule version. The inner strategy source remains separately
identifiable. The compiled decision mask is a deterministic derivative of
those inputs plus the authoritative session or pulse axis; it should be
recomputed, not frozen merely because it can be frozen.

Changing the schedule changes candidate and run identity. Changing only a
future internal execution optimization must not change research identity when
the pulse-level result is identical. This keeps a later historical
fast-forward implementation from becoming a second semantic mode.

### F11. The two-clock Momento case should not expand the first scheduler

Momento separates a signal weekday from an execution weekday. A normal ledgr
decision followed by next-open execution already separates decision and fill
time. Intentionally retaining a target until another configured weekday is a
different question: order lifecycle or execution policy.

Seed v2 should record the case and draw the boundary. The first scheduler owns
when the strategy is invoked. It should not silently add delayed target release,
pending orders or a second execution clock. The case becomes a future
obligation only if the existing timing and order model cannot express the
required behavior after the decision scheduler ships.

### F12. Event-to-event fast-forwarding is a later optimization, not a mode

For historical backtests, ledgr may eventually batch or vectorize stretches
between decision pulses. For paper or live operation, it will receive and
process pulses as they arrive. Those implementations may coexist only under
one pulse-level semantic oracle.

The first implementation should stay pulse-wise and gate P2. A later internal
accelerator may jump between the union of all economically relevant boundaries
only after proving it preserves P1 through P5 results, ordering, diagnostics,
interrupts and resume. It must not become a public `fast = TRUE` option or a
second fold.

## 4. Recommended Architecture For Seed v2 To Test

The smallest coherent architecture is:

```text
pipeable scheduled-strategy declaration
    -> experiment/candidate compilation
       - validate and resolve schedule
       - preserve inner strategy provenance
       - add schedule + rule version to identity
       - compile verdicts from the authoritative session/pulse axis
    -> the existing one-fold envelope
       P1 observe and settle                 always
       schedule verdict                      prepared O(1) lookup
       P2 construct ctx and decide           due pulses only
       P3 plan new target                    decision output only
       P4 apply economic events              when economic work is due
       P5 commit, diagnose and checkpoint    every processed pulse
```

The compiled verdict can be a boolean vector or equivalent indexed primitive.
It is prepared once and read by index. It is not a data frame, is not rebuilt
inside the pulse loop and is not an independent persisted research artifact.

The no-schedule case is semantically "every eligible pulse is a decision
pulse" and must reproduce current behavior exactly.

Strategy-owned state advances only when the strategy runs and returns an
update. Fold economic state advances normally on every pulse. Resume compiles
the same verdicts from the same declared inputs and axis; it does not restore a
mutable decorator cursor.

## 5. Decisions Seed v2 Must Put To The Maintainer

The response recommends answers but does not bind them.

1. **Declarative-only first implementation.** Recommend yes. Defer arbitrary
   `function(ctx)` gates because they erase the measured fast path and conflate
   scheduling with strategy logic.
2. **Partial first period.** Recommend no forced decision. Compile on the
   parent axis and wait for the next true boundary; opening positions remain an
   opening-policy concern.
3. **Period-end rules.** Recommend allow only with an authoritative expected
   session calendar; otherwise refuse before execution.
4. **Multiple intraday pulses per session.** Recommend either bind an explicit
   supported pulse boundary or refuse in the first implementation. Do not make
   daily formatting the hidden rule.
5. **Zero decision pulses.** Recommend a classed pre-execution refusal for a
   resolved schedule with no decision inside the executable range, unless an
   independently valid opening-only experiment is deliberately supported.
   Merely printing zero after an expensive flat run is too late.
6. **Parameterization.** Recommend ordinary candidate parameters resolved by
   experiment compilation rather than extending the feature-only meaning of
   `ledgr_param()` without an explicit cross-surface decision.
7. **Names.** Test the UX brief's `ledgr_on_schedule(ledgr_month_end())`
   family against the naming rules. Do not preserve
   `ledgr_strategy_schedule(..., rebalance = ...)` merely because it appears in
   the old seed.

## 6. Required Detecting Evidence

The revised seed should require a ticket cut to carry at least:

- callback, public-context, public-frame and history-helper counters proving
  zero calls on scheduled skips;
- a P3 new-target-planning counter proving no planning from a fabricated hold;
- P1 and P5 counters proving skipped decision pulses still observe, settle,
  diagnose and commit;
- a stateful strategy proving strategy state changes only on decision pulses;
- explicit-hold versus not-scheduled diagnostics proving the two are distinct;
- corporate-action cash, split, terminal, frozen-valuation and pending-fill
  witnesses on pulses where P2 is skipped;
- dense and availability-active parity;
- run, sweep, run-window, sweep-window, walk-forward, promotion and resume
  parity;
- first-partial-period, fold-boundary, off-session explicit-date and
  period-end-calendar cases;
- schedule identity and provenance mutations, including two otherwise equal
  candidates with different schedules;
- a no-schedule byte-identity ladder against the pre-scheduler tree;
- a paired H1 clock comparing the current manual guard with the engine-visible
  schedule, with identical fills, equity, state and diagnostics where the
  semantics are meant to match; and
- a structural detector preventing schedule evaluation from moving into P2 or
  becoming a growing per-pulse calendar scan.

The paired clock should report the recovered share of the measured 14.17
seconds as well as end-to-end wall time. The ticket cut may bind the exact
materiality threshold after the correction implementation is measurable; the
RFC should not turn the old lower bound into a promised speedup.

## 7. Rejected Alternatives

- **Keep the opaque wrapper and optimize later.** Rejected because it cannot
  avoid the measured P2 preparation cost.
- **Treat not-scheduled as `ctx$hold()`.** Rejected because it fabricates a
  callback result and collapses diagnostics and state semantics.
- **Allow arbitrary context predicates in the first scheduler.** Rejected as
  the default design because they require the context and do not satisfy the
  promoted performance claim.
- **Skip the whole pulse.** Rejected because settlement, valuation, economic
  events, diagnostics and commit remain due.
- **Add a historical fast mode beside a production pulse mode.** Rejected as a
  public distinction. One pulse semantics is the oracle; batching may later be
  an internal optimization.
- **Persist the decision mask.** Rejected absent contrary evidence because it
  is a deterministic intermediate derived from identity-bearing inputs.
- **Absorb delayed execution weekdays now.** Rejected because order timing and
  lifecycle are not the same decision as strategy invocation.

## 8. Scope For Seed v2

Seed v2 should redesign the proposal around the current fold and the measured
goal. It should cover:

- the public declaration and its inspectability;
- declarative schedule semantics over the authoritative axis;
- the P1/P2 gate and typed no-decision path through P5;
- identity, provenance, candidate resolution and resume;
- run, sweep, walk-forward and promotion behavior;
- diagnostics that distinguish skips from holds; and
- the detecting and performance evidence above.

It should not design:

- event-to-event batching;
- arbitrary data-dependent decision gates;
- delayed execution or pending-order policy;
- market-calendar acquisition;
- portfolio-construction helpers; or
- a second fold or execution engine.

## 9. Next RFC Stage

The original seed author or maintainer should review this response for factual
and framing errors. Claude should then write seed v2, preserving the public UX
direction while replacing the stale wrapper mechanism. The maintainer should
resolve the product choices in Section 5 before decision synthesis.

The expected next artifact is:

`rfc_strategy_schedule_decorator_v0_1_9_x_seed_v2.md`
