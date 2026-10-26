# Decision Synthesis: Strategy Scheduling And Held-Pulse Skipping

**Status:** Accepted by the maintainer on 2026-10-26; implementation
obligations open.
**Date:** 2026-10-25.
**Author:** Codex, who did not write seed v2.
**Reviewed tree:** `1cd4e0c9` on `v0.2.2`.
**Question:** What scheduling contract should ledgr bind for periodic strategy
decisions while preserving one pulse-wise execution model?

This synthesis weighs seed v2 against the Type 2 response, the response review
and the maintainer decisions. It is accepted authority for the implementation
cut.

> This RFC uses "first implementation" and "v1" as shorthand for the first
> implementation of the strategy scheduler; ledgr's roadmap has no scheduler
> v1 milestone. Later work lives in named RFCs at its own roadmap window.

## 1. Inputs And Disposition

Read in order:

- seed v1;
- the Type 2 response;
- the response review;
- seed v2;
- the maintainer decisions for partial periods and zero-decision runs;
- the accepted fold-phase synthesis;
- the WS53 scheduler measurement;
- the Research Strategy UX Brief and Momento application case; and
- the cited execution, calendar, identity, provenance and resume code at
  `1cd4e0c9`.

**Disposition:** adopt seed v2's architecture with one correction required by
the accepted partial-period decision. A parent axis's first session does not
count as a period start merely because it has no predecessor. Without a
predecessor, the transition is unproved and the verdict is not due. This
replaces seed v2 Section 5.2's opposite sentence and worked-example clause.

Everything else material survives: a classed function declaration, one
pre-fold compiler, a prepared verdict vector, P2 and P3 skipped when not due,
P1/P4/P5 retained, explicit schedule identity and provenance, session-axis
calendar rules, dense refusal and no event-to-event accelerator in the first
implementation.

No prerequisite spike is required. The implementation cut owns the paired H1
clock.

## 2. Bound Public Model

Scheduling remains outside the strategy callback:

```r
strategy <- portfolio_strategy |>
  ledgr_strategy_schedule(ledgr_schedule_month_end())
```

The first public family is:

- `ledgr_strategy_schedule(strategy, schedule)`;
- `ledgr_schedule_month_start()`;
- `ledgr_schedule_month_end()`;
- `ledgr_schedule_week_start()`;
- `ledgr_schedule_quarter_start()`;
- `ledgr_schedule_year_start()`;
- `ledgr_schedule_dates(dates)`; and
- a parameter-reference constructor whose exact conforming name is resolved
  at spec cut.

The family is deliberately small. Week-end, quarter-end, arbitrary calendar
functions and data-dependent gates require evidence before joining it.

An unscheduled strategy means every executable pulse is a decision pulse and
must remain byte-identical to current behavior.

## 3. Decisions

### D1. Representation is a classed function, not a closure wrapper

`ledgr_strategy_schedule()` returns the supplied strategy function with a
scheduled-strategy class and an inspectable declaration attribute. It does not
create an outer closure.

This preserves the ordinary `(ctx, params)` surface and existing function
gates while making the schedule visible before the fold. Experiment and
candidate compilation extract the declaration. Preflight runs on the inner
function and passes its tier through unchanged.

The representation must not rely on function-valued closure capture. LFB-035
shows that current registry keys and source hashes omit such captures. The
general fingerprint repair remains a separate defect; this RFC avoids the
hazard by keeping the inner function directly identifiable.

### D2. One compiler prepares one verdict vector

One compiler serves both execution-spec construction sites. It accepts the
declaration, resolved strategy parameters, authoritative parent session axis
and executable pulse positions. It returns one logical vector aligned with
the executable pulses plus derived decision and skip counts.

The parent session axis is exactly the snapshot's declared rows whose
`status == "open"`, ordered by `session_close`. Predecessor and successor below
mean adjacent rows on that ordered open-session axis. Closed-session rows,
observed bars and run-window edges do not participate in period boundaries.

The vector is prepared once and read by index. It contains no missing value,
is never rebuilt inside the pulse loop and is not a data frame. `NULL` denotes
the unscheduled every-pulse case.

The compiled verdict is a deterministic intermediate. Resume recomputes it
from stored identity-bearing inputs. It is neither persisted nor independently
hashed.

### D3. Rules use declared sessions, not observed bars

Period membership comes from `session_date` on the authoritative expected
session axis. It does not come from bar presence, timestamp formatting, locale
or callback state.

Week periods start on Monday. Their locale-independent integer-date partition
is `(as.integer(session_date) - 4) %/% 7`, as specified by seed v2.

For a period-start rule, a session is due only when a predecessor exists and
belongs to a different period. For a period-end rule, a session is due only
when a successor exists and belongs to a different period.

Therefore:

- the first parent-axis session is not automatically a period start;
- the last parent-axis session is not automatically a period end;
- run and fold windows slice verdicts compiled from the parent axis;
- a window boundary never manufactures a calendar boundary; and
- a partial first period waits for the next proven boundary.

This is the accepted D1 decision. Immediate initialization belongs to opening
policy or an explicit-date schedule, not an invented calendar transition.

Explicit dates inside the closed parent-axis range snap forward to the first
declared open session on or after the requested date. A requested date outside
that range refuses before execution. Duplicate snapped sessions collapse to
one decision verdict.

### D4. The first implementation supports one pulse per session

The compiler asserts one executable pulse per declared open session. It
designs no within-session selector and makes no intraday-execution claim.

This avoids an EOD-specific hidden rule without prematurely designing the
future intraday surface. When ledgr later supports multiple pulses per session,
that work must decide the within-session boundary explicitly.

### D5. Scheduled strategies require a declared session axis

The current dense path has timestamps but no authoritative session predecessor
or successor outside its window. Scheduled strategies therefore refuse on a
snapshot without a declared session axis.

This is a missing-input refusal, not a second execution branch. Dense mode is
already frozen for later removal. Once the consolidated path supplies a
declared axis, the refusal disappears without separate scheduler semantics.

Dense and availability parity is required for the unscheduled byte-identity
case. Scheduled calendar behavior is tested on the declared-session path.

### D6. The schedule gates decision work inside the one fold

On a not-due pulse:

- P1 always runs: observation, corporate-action postings, dispositions,
  terminals, valuation, equity and prepared-history reading remain intact;
- P2 does not run: no public frame, context, callback, target validation,
  risk processing or per-instrument decision trace is constructed;
- P3 does not run: there is no new target to plan;
- P4 always runs with an empty plan, because it still binds the next pulse's
  corporate-action entitlement quantities; and
- P5 always runs: reconciliation, carried strategy-state persistence,
  processed count, telemetry, checkpoint and interrupt duties remain intact.

The envelope carries a null decision and an empty constant-time plan. It does
not fabricate a target and does not create a second fold.

There are no pending fills across pulses in the current model. The detecting
evidence therefore covers entitlement binding and P1 economic postings rather
than a nonexistent pending-fill state.

### D7. A scheduled skip differs from an explicit hold

An explicit hold means the callback ran. It may carry intent notes and state,
and it traverses validation, risk and decision tracing. A scheduled skip means
the callback and all of P2 were absent.

The skip produces:

- no public intent or target;
- no per-instrument decision rows;
- one pulse-level diagnostic segment with reason `scheduled_skip`;
- an unchanged strategy-state value persisted for that processed pulse; and
- the ordinary reconciliation row, using current cash and held exposure.

The reconciliation row remains because it preserves the per-pulse evidence
shape and proves P5 ran. Its measured cost must be reported, but the existing
evidence puts it below the materiality trigger.

`scheduled_skip` extends the closed reason-code vocabulary. Implementation
therefore amends the contract and bumps the current store format. Older stores
refuse under the pre-CRAN policy; no migration or fallback is added.

### D8. Strategy state and resume remain pulse-complete

Strategy-owned state changes only when P2 invokes the strategy and the result
contains an update. On a skip, the prior state is carried unchanged.

The carried value is still written on every processed pulse because the latest
strategy-state row is the persistent resume cursor. Removing that write is not
an optimization option. Resume recompiles the schedule and reproduces the
same verdict sequence without mutable decorator state.

### D9. Zero-decision behavior follows opening state

The accepted D2 rule is:

- refuse before the current run executes when the resolved schedule has no
  decision pulse and the run has neither opening nor carried positions;
- allow the run when opening or carried positions exist; and
- disclose zero decision pulses in run information.

An allowed zero-decision run still performs P1, P4 and P5 on every pulse. This
supports legitimate hold-through walk-forward folds while rejecting a flat
standalone run that can never trade.

The refusal is evaluated per executable run or fold after its opening or carry
state is known. It is not a blanket preflight over an entire walk-forward
session.

### D10. Parameterization uses ordinary strategy parameters

A schedule may refer to one named strategy-grid parameter. Candidate
compilation resolves that parameter to a known declarative rule before the
fold. Unknown, absent or non-scalar values refuse.

This does not extend the feature-specific `ledgr_param()` resolver. The
resolved value already participates in strategy-parameter identity; the
schedule declaration and rule version participate separately.

### D11. Identity and provenance separate strategy from schedule

The inner strategy retains its own registry key, source, source hash and
preflight tier. Attribute-stripped capture prevents the schedule wrapper from
changing the meaning of those fields.

The config and durable provenance separately record:

- canonical schedule declaration;
- resolved schedule rule;
- schedule rule version; and
- schedule hash.

Candidate, run, walk-forward and promotion identity change when schedule
semantics change. The compiled mask does not enter identity. A later internal
accelerator that produces identical pulse-level results also does not change
research identity.

This adds durable provenance fields and requires the same store-format bump as
the new diagnostic token.

### D12. Counts are derived once from compiled verdicts

Decision-pulse and scheduled-skip counts are computed at finalization from the
compiled verdict vector and stored in run telemetry or its current successor.
They are not inferred from availability-only diagnostic rows.

Experiment plan and run information disclose the schedule. Run information
discloses both counts, including zero. Exact print formatting and whether sweep
summary rows repeat the counts are spec-cut questions.

### D13. The scheduler owns invocation time only

Momento's separate signal and execution weekdays remain an acceptance case,
not first-implementation scope. Next-open execution already separates a
decision from its fill. Retaining a target until another configured weekday,
pending orders and delayed release belong to execution and order policy.

Historical event-to-event stepping is also excluded. A later internal
accelerator may batch intervals only after proving the same P1-through-P5
results, ordering, diagnostics, resume and interrupt behavior. There is no
public `fast = TRUE` and no second engine.

## 4. Contract And Stored-Format Consequences

The implementation cut amends the contracts for:

- the scheduled-strategy public surface and preflight pass-through;
- schedule identity, provenance and recovery;
- declared-session requirements and one-pulse-per-session refusal;
- the P2/P3 skip path with P1/P4/P5 preserved;
- the distinction between an empty decision axis, explicit hold and scheduled
  skip;
- the `scheduled_skip` reason token;
- per-processed-pulse carried state and reconciliation evidence;
- zero-decision refusal and disclosure; and
- decision and skip counts on result information.

One current store-format bump owns the new provenance, telemetry and diagnostic
vocabulary. Candidate identity formats also bump where their payload gains the
schedule declaration. No migration, old-format reader or missing-marker
fallback is permitted.

The affected version owners are explicit:

- `ledgr_saved_sweep_schema_version` moves from 5 to 6;
- sweep `provenance_version` moves from `ledgr_provenance_v1` to
  `ledgr_provenance_v2`;
- the candidate reproduction-key version moves from
  `ledgr_candidate_reproduction_key_v1` to
  `ledgr_candidate_reproduction_key_v2`;
- `ledgr_walk_forward_candidate_schema_version` and the corresponding
  inspection provenance move from `v1` to `v2`; and
- `ledgr_promotion_context_version` moves from `ledgr_promotion_v2` to
  `ledgr_promotion_v3`.

Each current-only reader refuses the superseded value. No compatibility reader
or missing-schedule fallback is added.

Documentation makes the decorator the taught scheduling idiom. The owning
implementation tickets replace hand-written guards in affected executable
articles, document schedule identity, provenance and decision/skip counts,
update the reference index and `NEWS`, and render the changed vignettes. The
spec cut assigns individual articles; it may not omit this documentation
surface.

## 5. Required Detecting Evidence

The ticket cut must register evidence that fails on at least these regressions:

- any public frame, context, public strategy-visible history-helper
  installation or call, or callback constructed on a scheduled skip, while
  explicitly permitting the P1 history-reader work bound by D6;
- any P3 target planning on a skip;
- P1, P4 or P5 omitted on a skip;
- entitlement binding omitted from P4;
- corporate-action cash, disposition or terminal posting omitted from P1;
- strategy state changed on a skip or its resume-cursor row omitted;
- a skip recorded as an explicit hold or per-instrument decision;
- reconciliation evidence missing on a skip;
- a run, sweep, window, walk-forward, promotion or resume compiling different
  verdicts for the same identity-bearing inputs;
- a fold boundary becoming a false period start;
- the first or last parent-axis session becoming a boundary without evidence;
- an explicit date outside the axis being accepted;
- a duplicated session date or multi-pulse session being silently accepted;
- a zero-decision flat run with neither opening nor carried positions entering
  the fold instead of refusing, or an otherwise identical zero-decision run
  with opening or carried positions failing to complete P1/P4/P5, retain its
  holdings and report zero decisions;
- an explicit date between open sessions failing to snap forward, two dates
  that snap to the same open session producing more than one verdict, or a
  date on either side of the bounded parent-axis range failing to refuse;
- an absent, unknown or non-scalar schedule parameter reaching the fold, or
  two valid grid values failing to produce their expected distinct verdicts
  and identities;
- persisted decision and skip counts differing from the compiled verdict
  counts, including interrupted/resumed and zero-decision runs;
- trusted strategy recovery failing to reattach the verified schedule
  declaration, or a parallel sweep worker failing to retain and compile that
  same declaration;
- a current-only reader accepting a superseded saved-sweep, sweep provenance
  or reproduction-key, walk-forward candidate, or promotion-context version;
- two schedules sharing candidate or run identity;
- the same inner strategy acquiring a different source hash only because of
  its schedule;
- a tier-3 inner strategy bypassing preflight;
- schedule evaluation moving into P2 or a growing calendar scan entering the
  pulse loop; and
- an unscheduled run changing any frozen result or diagnostic byte.

The integrated clock compares the engine schedule with the manual-guard arm
on the H1 workload in alternating pairs. It reports end-to-end wall time and
the recovered share of the measured 14.17 seconds from the 62.65-second
diagnostic arm. Both arms compare from a true shared boundary and require
identical economic results and carried strategy state. Diagnostic differences
are limited to the deliberately changed skip-versus-hold evidence.

The ticket cut binds the materiality threshold after the implementation is
measurable; the RFC does not promise recovery of the full lower bound.

## 6. Rejected Alternatives

- Opaque closure wrapper: too late to avoid P2, refused by preflight and unsafe
  under LFB-035.
- Mutable decorator cursor: not resume-safe.
- Schedule facts in `ctx`: requires P2 and expands the public context for an
  orchestration concern.
- Arbitrary `function(ctx)` or axis-function gates: additional identity and
  preflight surface without first-implementation evidence.
- Treat a skip as `ctx$hold()`: fabricates an invocation and decision rows.
- New public or internal intent type: a null decision and reason token suffice.
- Skip P4 or P5: loses entitlement binding or resume/commit duties.
- Omit the carried state or reconciliation row: breaks resume or the evidence
  shape for immaterial saving.
- Force the first window pulse to be due: violates accepted D1 and manufactures
  fold boundaries.
- Treat an unproved first parent-axis session as a period start: the same false
  boundary one level earlier.
- Unconditionally refuse zero decisions: rejects valid carried folds.
- Infer period boundaries from observed bars: confuses data absence with the
  calendar.
- Add window-relative dense rules: throwaway semantics for a frozen path.
- Persist the mask: freezes a deterministic intermediate without need.
- Extend `ledgr_param()` into scheduling: ordinary strategy parameters already
  supply the required candidate axis.
- Absorb delayed execution or event-to-event batching: separate policy and
  optimization questions.

## 7. Spec-Cut Questions

The implementation cut may choose, without another RFC:

- the exact conforming name of the parameter-reference constructor;
- whether week-end or quarter-end joins the first menu, provided the same
  successor rule applies;
- whether the compiler is inside `ledgr_execution_spec()` or one shared helper
  called by both construction sites;
- exact config, provenance, telemetry and spec-slot field names;
- exact field placement for the fixed saved-sweep, sweep provenance and
  reproduction-key, walk-forward candidate and promotion-context version
  bumps named in Section 4;
- skip-row placeholder and detail payload;
- print wording and whether sweep summaries repeat counts;
- exact classed condition names; and
- article ownership within the implementation cut.

These questions cannot change the bound semantics above.

## 8. Future Obligations

- LFB-035: repair function-valued capture fingerprinting and the existing
  `ledgr_signal_strategy()` collision in a separate defect ticket.
- Portfolio construction: weight-strategy wrappers and rebalance bands consume
  this scheduler rather than redefining it.
- Execution and order policy: delayed target release and distinct execution
  weekdays, using Momento as the acceptance case.
- Decision gates: data-dependent `function(ctx)` gates only after concrete
  evidence, outside the scheduler performance claim.
- Intraday scheduling: choose a within-session pulse boundary when first-class
  intraday execution enters scope.
- Historical acceleration: event-to-event batching under the pulse oracle with
  its own evidence.
- Execution-core consolidation: provide a declared session axis to the unified
  path so the current dense refusal can disappear.

## 9. Acceptance And Routing

After an independent Type 1 final review and maintainer acceptance:

1. update the scheduler pipeline row to `Obligations open` and point first to
   this synthesis and its final review;
2. add a decisions-bridge row for the pending contract and schema changes;
3. amend the current macro plan with the scheduler ticket-cut position;
4. cut implementation tickets only after the open spec-cut questions have
   named owners; and
5. retain LFB-035 as a separate defect owner rather than padding the scheduler
   workstream.

The maintainer accepted this synthesis on 2026-10-26. The pipeline row,
decisions bridge and macro-plan route now carry the implementation obligations.
Until implementation and contract consolidation, current every-pulse strategy
behavior remains the only shipped behavior.

## 10. Review State

The independent Type 1 final review returned `PASS_AFTER_PATCHES`; its focused
confirmation returned `PASS`. The maintainer accepted the patched synthesis on
2026-10-26. The next stage is the implementation ticket cut, after its owners
resolve the Section 7 spec-cut questions.

## 11. Revision History

- 2026-10-26 - Patched after the independent Type 1 final review
  (`PASS_AFTER_PATCHES`): defined the ordered declared-open-session axis and
  Monday weeks; completed the failure-sensitive evidence matrix; named the
  saved-sweep, sweep provenance/reproduction-key, walk-forward and promotion
  version bumps; and restored the documentation consequences. Focused Type 1
  confirmation due.
- 2026-10-26 - Focused Type 1 confirmation returned `PASS`; maintainer
  acceptance due.
- 2026-10-26 - Maintainer accepted the synthesis. Section 9 routing completed;
  implementation obligations open.

## 12. Amendment: Common Civil-Calendar Schedules

**Accepted:** 2026-10-26. **Authority:**
[focused amendment](rfc_strategy_schedule_common_calendar_amendment.md), after
its Type 2 `ACCEPT_AFTER_PATCHES` review and focused `PASS` confirmation.
**Owner:** Cut 22, Workstream 64, LDG-3115.

The accepted amendment adds two version-1 tagged declarations to the same
compiler and identity path: `ledgr_schedule_weekday(day)` and
`ledgr_schedule_month_day(day)`. Their anchors resolve forward only within the
same civil week or month. An anchor before the first parent-axis open session
is unproved and contributes no decision. The compiler retains the normalized
argument; `month_day` stores an integer; no current format or declaration
version changes.

| Parent section | Superseded statement | Accepted replacement |
| --- | --- | --- |
| Section 2 | The first public family contains eight names. | The public family contains those eight names plus `ledgr_schedule_weekday()` and `ledgr_schedule_month_day()`. |
| Section 3 | Compiler dispatch covers fixed boundaries, dates and fixed-rule parameters. | The same compiler also covers explicit period-local weekday and numbered-month-day anchors; no pulse-time calendar work is added. |
| Section 5 | Common calendar recurrence beyond the fixed family uses explicit dates. | Explicit dates remain the escape hatch, while the two common recurrence forms have typed declarations. Parameterized weekday/month-day values remain deferred. |

Every other decision in Sections 2 through 9 remains unchanged.
