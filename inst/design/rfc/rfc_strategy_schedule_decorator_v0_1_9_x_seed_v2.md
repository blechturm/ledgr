# RFC Seed v2: Strategy Scheduling And Held-Pulse Skipping

**Status:** Seed v2, written 2026-10-25. Supersedes seed v1 (2026-06-12) in
full; v1 remains a historical record. Not binding. Two product choices (D1,
D2) are carried to RFC stage 6; decision synthesis by Codex follows their
resolution.
**Author:** Claude (seed v1 author). Response by Codex (2026-10-25); response
review by Claude (2026-10-25, `RESPONSE_ACCEPTED_AFTER_PATCHES`).
**Reviewed tree:** `1cd4e0c9` on `v0.2.2`. Every line anchor is read from that
tree.
**Inputs:** the seed v1, the Type 2 response, the response review, the
accepted fold-phase synthesis, the WS53 closeout ("Scheduler result and
telemetry decision"), the research strategy UX brief, the portfolio-method
exercises (Momento case), macro plan WS6, LFB-035 in the ledgr-research
feedback register, and the code named in Section 2.

> This RFC uses "first implementation" and "v1" as shorthand for the first
> implementation of the strategy scheduler; ledgr's roadmap has no scheduler
> v1 milestone. Post-v1 work lives in named follow-up RFCs at their own
> roadmap windows.

## 1. What Changed Since Seed v1

Seed v1 proposed an ordinary wrapper around `function(ctx, params)` that
receives `ctx` on every pulse and emits hold-shaped targets on non-decision
pulses. Three facts retire that architecture:

1. P2 builds the public frames and `ctx` before the callback
   (`R/fold-engine.R:650-760`) and validates, risk-adjusts and traces the
   returned targets after it (`:811-971`). A wrapper sits between those blocks
   and skips only the inner call, roughly one second of the 14.17 seconds
   measured on held pulses (derived by subtraction from the WS53 totals; not
   measured).
2. A closure wrapper over an inner strategy is refused by preflight as tier 3,
   and its deparsed source omits the inner strategy, so two different inner
   strategies share one source hash (response review, Section 2 probes).
3. The function registry keys on body, formals and variable captures only
   (`R/determinism.R:119-170`); function-valued captures are invisible to it.
   That is LFB-035, a shipped defect outside this RFC, and it rules out any
   design that identifies the inner strategy through closure capture.

Seed v2 keeps v1's user-facing intent (scheduling outside the callback,
identity-bearing, sweepable, drop-in everywhere a strategy goes) and replaces
the mechanism: a classed function carrying an inspectable declaration,
compiled once before the fold into verdicts read by index, gating P2 and P3
inside the one existing fold.

## 2. Evidence Base

Code read at `1cd4e0c9`: `R/execution-spec.R`, `R/backtest-config.R`,
`R/experiment.R`, `R/backtest-runner.R`, `R/fold-engine.R`,
`R/fold-phase-contract.R`, `R/run-resume.R`, `R/sweep.R`, `R/walk-forward.R`,
`R/walk-forward-folds.R`, `R/walk-forward-identity.R`,
`R/availability-provider.R`, `R/availability-policy.R`,
`R/availability-facts.R`, `R/run-snapshot.R`, `R/corporate-action-settlement.R`,
`R/strategy-preflight.R`, `R/strategy-provenance.R`, `R/strategy-fn.R`,
`R/strategy-extract.R`, `R/determinism.R`, `R/signal-strategy.R`,
`R/config-hash.R`, `R/db-schema-current.R`, `R/experiment-store-schema.R`.

Measured input (WS53 closeout): on the H1 changing-membership workload,
7,213 pulses, 345 monthly decision pulses and 6,868 held pulses. Context,
callback and target work on held pulses totals 14.17 seconds, 22.6 percent of
the 62.65-second every-pulse diagnostic arm. That is a lower bound on the
decision work a scheduler may avoid and no authority to skip settlement,
valuation, fills, state, diagnostics or commit. The share is of the diagnostic
arm, not of the public-run wall (60.99 s profile; one-worker medians 58.42 to
75.36 s).

Two read-only probes (response review, Section 2) established the preflight
refusal, the provenance collapse and the registry collision. A third base-R
probe for this seed established that a function carrying a class and an
attribute keeps `is.function()`, `formals()`, `body()` and
`codetools::findGlobals()` identical to the bare function, survives
`serialize()`, is callable unchanged, and deparses as
`structure(function(...) ..., class = ..., ledgr_schedule = ...)`. Provenance
capture must therefore strip attributes before deparsing (Section 7).

No prerequisite spike is needed. Every claim below is settled by the tree or
by those probes; the one open empirical question, how much of the 14.17
seconds the skip recovers end to end, is the ticket cut's paired clock.

## 3. Problem Statement

A periodic strategy today hand-rolls its own guard. The two shipped idioms
disagree:

- the H1 bench strategy keeps the last decision month in `state_prev` and
  decides on its first pulse because the state is empty
  (`dev/bench/v0_2_2_real_data_scale/fixture.R:97-98`);
- the taught minimum-variance article reads two sessions of history and holds
  while both share a month, so a mid-month start waits
  (`vignettes/minimum-variance.qmd:212-222`), the "dummy two-session history
  read" the macro plan names for removal (`macro_plan.md:1228`).

Both pay P2 on every pulse. Neither is identity-bearing, sweepable or visible
to the engine. The engine cannot skip work it does not know is unnecessary.

## 4. Public Surface (Illustrative; Names Are Spec-Cut)

```r
strategy <- portfolio_strategy |>
  ledgr_strategy_schedule(ledgr_schedule_month_end())

exp <- ledgr_experiment(snapshot, strategy, features = ..., cost_model = ...)
bt  <- ledgr_run(exp, params = list(lookback = 120L))
```

- `ledgr_strategy_schedule(strategy, schedule)` is the decorator. It returns
  the supplied function itself with class
  `c("ledgr_scheduled_strategy", "function")` and the declaration in an
  attribute. No closure is created; the function body is the user's.
- Rule constructors are small declarations in the shape of the timing model
  (`R/cost-model.R:172-182`: `type_id`, `version`, `args`): the first menu is
  `ledgr_schedule_month_start()`, `ledgr_schedule_month_end()`,
  `ledgr_schedule_week_start()`, `ledgr_schedule_quarter_start()`,
  `ledgr_schedule_year_start()` and `ledgr_schedule_dates(dates)`. Each carries
  a schedule-rule version.
- Variable schedules use ordinary strategy-grid parameters:
  `ledgr_strategy_schedule(strategy, ledgr_schedule_from_param("rebalance"))`
  with `ledgr_strategy_grid(rebalance = c("month_start", "quarter_start"))`.
  The grid value is a character scalar naming a menu rule; compilation
  resolves it from `strategy_params` and refuses an unknown name before
  execution. `ledgr_param()` is not involved: it resolves only through the
  six-constructor feature registry (`R/feature-parameters.R:290-299`) and is
  refused elsewhere (`:63-69`).
- No `function(ctx)` predicate and no axis-function escape hatch in the first
  implementation. Explicit dates cover custom calendars.

Naming. Rule R1 of the accepted naming synthesis binds family-first
`ledgr_<family>_<action>` names and a closed verb-first allowlist. The UX
brief's illustration `ledgr_on_schedule(ledgr_month_end())` would need an
allowlist amendment for both names; `ledgr_strategy_schedule()` and the
`ledgr_schedule_*` constructors conform as written. The seed recommends the
conforming names; the synthesis fixes them.

Drop-in. Every existing gate a strategy passes still passes: experiment
validation checks `is.function()` and the `(ctx, params)` formals
(`R/experiment.R:464-485`); the sweep reads the signature from the function
(`R/sweep.R:1686`) and passes it to the spec (`:1698-1701`); walk-forward
builds one `ledgr_config()` per fold from `exp$strategy`
(`R/walk-forward.R:404-437`); promotion calls `ledgr_run()` with the candidate
parameters. Attributes survive serialization to workers and the registry.

Disclosure. `print.ledgr_experiment()`, `ledgr_experiment_plan()` and
`print.ledgr_run_info()` gain one schedule line; run info additionally shows
the decision and scheduled-skip counts (Section 9).

## 5. Semantics Of A Scheduled Strategy

### 5.1 Declaration, compilation and the mask

The declaration is extracted at `ledgr_config()` time by `ledgr_strategy_spec()`
(`R/backtest-config.R:34-50`) into a config field, absent when the strategy is
unscheduled. The function registered and source-captured is the inner function
with attributes stripped, so the registry key and `strategy_source_hash` are
the inner strategy's. The declaration never travels through the registry; the
run path compiles from the config, the sweep path from `attr(exp$strategy,
"ledgr_schedule")` at candidate setup. Two scheduled strategies with the same
inner and different schedules therefore share one registry entry by design,
since the executable is the same, and differ in config identity.

One compiler serves both execution-spec call sites (`R/backtest-runner.R:1309`;
`R/sweep.R:1698`), either inside `ledgr_execution_spec()` or as one helper both
call; the spec-cut fixes which. Inputs: the declaration, `strategy_params`,
the parent session axis and the run's `pulses_posix`. Output: one logical
vector aligned to `pulses_posix`, plus the decision and skip counts. The spec
gains one slot holding that vector or `NULL`; its validator checks alignment
and no missing values. `NULL` means every pulse is a decision pulse and must
reproduce today's behavior byte for byte.

The mask is a deterministic intermediate: recomputed on every invocation,
including resume, from the stored declaration and the same axis; never
persisted as an artifact; never an identity input. It is a plain logical
vector prepared once and read by index in the envelope loop
(`R/fold-engine.R:1843`), per the optimization coding style.

### 5.2 Period rules on the parent session axis

The parent axis is the snapshot's declared open sessions in `session_close`
order, the same table every run and fold calendar is cut from
(`R/availability-provider.R:380-404`; `R/walk-forward-folds.R:796-806`).
Period membership is read from `session_date` (`R/db-schema-current.R:284-291`)
by integer arithmetic, never from observed bars or locale-dependent formatting:
month index `year * 12 + month`, quarter index `year * 4 + (month - 1) %/% 3`,
year index `year`, week index `(as.integer(date) - 4) %/% 7`, which starts
weeks on Monday.

- `*_start`: the session is the first of its period on the parent axis, that
  is, the predecessor session has a different period index. The first session
  of the parent axis counts as a period start.
- `*_end`: the successor session on the parent axis exists and has a different
  period index. The last declared session is never a period end; a run whose
  final pulse is that session records no decision there and the count
  discloses it.
- `dates`: each requested date snaps forward to the first declared open
  session at or after it. A date beyond the last declared session, or before
  the first, refuses before execution with a classed condition.
- Run and fold windows slice the parent verdicts by pulse position. A window
  that starts mid-period sees the true verdicts of its pulses; its first pulse
  is a decision pulse only if it is a true period start (D1 governs the
  alternative). Fold boundaries manufacture no period starts.

One pulse per session is asserted, not designed around. The pulse is `"EOD"`
by construction (`R/backtest-config.R:198`), the availability calendar emits
one pulse per open session row (`R/availability-provider.R:395-404`), and the
facts loader refuses duplicate session dates within a venue
(`R/availability-facts.R:732`). The compiler refuses a parent axis with a
duplicated `session_date` or a run pulse that matches no session. No
within-session selector is designed and no intraday execution is claimed
(`inst/design/contracts.md:2589-2592`).

Worked example. Parent axis sessions 2024-01-29, 01-30, 01-31, 02-01, 02-02,
02-29, 03-01 (gaps elided). `month_start` verdicts: 01-29 TRUE only if it is
the first session of the axis, else FALSE; 02-01 TRUE; 03-01 TRUE.
`month_end`: 01-31 TRUE; 02-29 TRUE; 03-01 TRUE only if a session with a
different month follows on the axis. A fold whose test window starts 02-02
has verdicts FALSE, ..., TRUE (02-29) and does not decide on 02-02 under the
true-boundary rule.

### 5.3 Dense mode: refusal, not window-relative edges

Dense runs cut their calendar from the distinct bar timestamps inside the
window (`R/run-snapshot.R:142-160`; `R/backtest-runner.R:1461-1511`). There is
no predecessor before the window, no declared successor after it, and no
`session_date`. Seed v2 chooses refusal: a scheduled strategy on an experiment
without a declared session axis refuses at experiment construction with a
classed condition, in the family of the existing
`ledgr_availability_sessions_required` check (`R/availability-policy.R:234-238`).

Reasons, in order: period edges on observed bars cannot be evaluated honestly
(`month_start` at the first window pulse and `month_end` at the last would be
window artifacts, the false boundaries F7 names); dense is frozen by
release-line decision and scheduled for removal by the execution-core
consolidation, so dense scheduler semantics would be throwaway and would need
their own parity evidence; and the refusal is a missing-input check, not a mode
branch: the compiler has no notion of execution mode and refuses an absent
axis, while the experiment-level check mirrors an existing capability check.
When consolidation gives bars-only snapshots a declared session axis, the
refusal lifts by itself. Rejected alternative: window-relative dense edges,
because they bind semantics the next release deletes and make the first and
last pulse of every dense window lie about period membership.

Consequence: parity evidence between dense and availability execution is
scoped to what both axes express, which is the no-schedule case. The
no-schedule byte-identity ladder runs in both modes; scheduler semantics are
exercised on the availability path only.

### 5.4 One fold, one pulse model

The accepted five-stage fold is unchanged in shape. On a scheduled skip:

- **P1 always runs** (`R/fold-engine.R:272-628`): corporate-action postings,
  dispositions, terminals, valuation ageing, freeze entry and exit, the
  equity fact, the history bar packet and lazy view. Its cost is not scheduler
  scope.
- **P2 is skipped** (`:630-985`): no frame slicing, no `ctx`, no helper
  refresh, no callback, no target validation, no risk, no per-ID decision
  trace.
- **P3 is skipped** (`:987-1223`): there is no new target to plan. The
  envelope supplies an empty plan whose `expected_final_cash` is the current
  fold cash after P1, built per pulse in constant time.
- **P4 always runs** (`:1225-1347`) with that empty plan, because it binds the
  next pulse's corporate-action entitlement quantities to current positions on
  every pulse (`:1246`; `R/corporate-action-settlement.R:460-471`). No fills
  are applied.
- **P5 always runs** (`:1349-1512`): flush, `last_executed` unchanged, cash
  reconciliation against the empty plan (trivially equal), the reconciliation
  row (Section 5.6), the carried strategy-state write, `processed`, telemetry,
  checkpoint and interrupt controls.

No fill pends between pulses: a fill is planned in P3 against the next
declared session and booked in P4 of the same pulse with that execution time
(`R/availability-economics.R:391`; `R/fold-engine.R:1283-1340`). The only
cross-pulse economic work is corporate-action binding in P4 and the P1
postings, and both run on skipped pulses.

The envelope reads the verdict after P1 by index. On FALSE it records the skip
segment (Section 5.5), carries a null decision and the empty plan into P4 and
P5, and continues. Stop results are unchanged; a skip produces none. No new
orchestration path, no second fold, no mode branch.

### 5.5 A skip is not `ctx$hold()`

`ctx$hold()` means the callback ran and chose current holdings: it runs target
validation, the risk chain, the per-ID decision trace and may carry a strategy
intent note and a state update (`:811-971`). A scheduled skip means the
strategy was not invoked. The two are distinct in diagnostics and state:

- the skip records one pulse-level decision segment, `n = 1`, stage
  `decision`, outcome `recorded`, reason token `scheduled_skip`, following the
  one-row `empty_public_domain` shape (`:833-838`). No per-ID decision rows
  are written, which is consistent with "one decision trace row per invoked
  axis ID" (`contracts.md:1220-1221`);
- no target is fabricated and no new internal result class is added; the
  envelope's null decision and empty plan are the carrier;
- strategy-owned state advances only when the strategy runs and returns an
  update. On a skip the carried state is written again unchanged, because
  that row is the persistent resume cursor (`R/run-resume.R:31`, `:53`); the
  resumed invocation reads the latest row before its start (`R/backtest-runner.R:1512-1536`).

The token extends a closed vocabulary (`contracts.md:1137-1143`), which is a
contract amendment and a schema bump (Section 8).

### 5.6 The reconciliation row stays

On the availability path P5 writes one `affordability_reconciled` row per
pulse (`:1388-1444`) comparing recorded cash with the plan's virtual cash and
reporting intended, post-risk and actual gross exposure. Seed v2 keeps that
row on skipped pulses: cash reconciles trivially against the empty plan, and
intended and post-risk exposure equal actual held exposure at decision marks.
Reasons: the per-pulse evidence ladder keeps one shape for every processed
pulse, so continuity checks and readers need no skip-aware branch; the row is
the only pulse-level witness that P5 ran on a skip; and its `canonical_json`
cost is below the WS53 five-percent gate. Rejected alternative: omit the row,
which would save well under one percent and make the evidence shape depend on
the schedule.

### 5.7 Resume, windows, sweep, walk-forward, promotion

- Resume: `start_idx` comes from the last `strategy_state` row
  (`R/run-resume.R:31-53`), which skips keep writing; the mask is recompiled
  from the stored declaration and the same axis, so verdicts are identical by
  construction. No decorator cursor exists to restore.
- Run and sweep windows, walk-forward folds: each window is a run or candidate
  on the same snapshot, so its verdicts are a slice of the parent axis. Carry
  between folds is unaffected; the schedule decides when, carry decides from
  what.
- Sweep: candidates on one experiment share the declaration; a parameterized
  schedule resolves per candidate from `params`.
- Promotion: `ledgr_promote()` calls `ledgr_run()` with the candidate's
  parameters, so the promoted run compiles the same verdicts; the promotion
  context records the schedule identity with the candidate identity.

### 5.8 Momento and later optimization

The scheduler decides when the strategy is invoked. Momento's separate signal
and execution weekdays stay an acceptance case (the exercises' routing table):
a normal decision followed by next-open execution already separates decision
and fill time; retaining a target for release on another weekday, pending
orders or a second execution clock belong to execution and order policy, not
to this scheduler.

Historical event-to-event batching is a later internal optimization. It may
exist only under the same pulse-level oracle, after proving identical P1 to P5
results, ordering, diagnostics, interrupts and resume. It is not a public
`fast = TRUE` option and not a second engine. P1's per-pulse equity fact
(`:583`) and valuation ageing are the facts any accelerator must reproduce.

## 6. Identity

- The schedule declaration (type, rule version, arguments, parameter
  reference) enters the config as one field, absent when unscheduled. Config
  identity hashes the whole config minus a fixed exclusion list
  (`R/config-hash.R:1-50`), so the field enters run identity automatically and
  an unscheduled config hashes exactly as today.
- The resolved parameter value is already inside `strategy_params`, hence
  inside `strategy_params_hash` and every candidate identity.
- Sweep and walk-forward candidate identity add the declaration hash beside
  `strategy_hash` (`R/walk-forward-identity.R:35-68`; `R/sweep.R:398-425`),
  with the corresponding candidate-schema version bump. Promotion identity
  follows the candidate.
- `strategy_hash` and `strategy_source_hash` remain the inner strategy's:
  computed on the attribute-stripped function, so the same inner under two
  schedules has one source hash and two config identities.
- The mask enters no identity; a later internal optimization that preserves
  pulse-level results changes no identity.

## 7. Provenance And Preflight

- `run_provenance` gains `schedule_json` (the canonical declaration, including
  the resolved rule and its version) and `schedule_hash`; both `NULL` for
  unscheduled runs. `strategy_source`, `strategy_source_hash` and
  `strategy_source_capture_method` keep their meaning for the inner function.
- Capture strips attributes before `ledgr_deparse_one()`
  (`R/strategy-provenance.R:59-60`; `R/determinism.R:48`); otherwise the source
  would read `structure(function(...), class = ..., ledgr_schedule = ...)`
  and the sweep's `strategy_hash` (`R/sweep.R:398-399`) would mix inner and
  schedule identity.
- Recovery: `ledgr_run_strategy()` re-hashes the stored source and returns the
  function (`R/strategy-extract.R:151-185`); for a scheduled run it re-attaches
  the stored declaration so the recovered value is drop-in.
- Preflight runs on the inner function and its tier passes through unchanged
  (`R/strategy-preflight.R:81-105`). The declaration adds no unresolved symbol,
  no capture and no tier. The `ledgr_signal_strategy_wrapper` attribute bypass
  (`:87`) is not reused; it exists because that wrapper is a closure, which
  this design is not.
- LFB-035 is consumed as a constraint, not absorbed: no captured inner
  function, explicit inner identity in registry and provenance, explicit
  schedule identity in config. The general fingerprint repair for
  function-valued captures and the `ledgr_signal_strategy()` collision belong
  to the defect ticket.

## 8. Contract, Schema, Documentation And Evidence Consequences

Bound at synthesis acceptance, implemented by the ticket cut; nothing here
edits the contracts now.

Contract amendments (`inst/design/contracts.md`):

- Execution Contract, Fold Core And Output Handlers: the skip path (P2 and P3
  absent, P4 with an empty plan, P5 with a null decision).
- Execution And Feature Identity: schedule declaration and rule version as
  identity inputs; the mask excluded.
- Strategy Preflight: inner-function preflight and tier pass-through.
- Availability Contract, Activation And Session Calendar: a schedule requires
  the declared session axis.
- Context Planes And Strategy State: "An empty Daxis still invokes the
  strategy" (`:1032`) gains the qualifier that a scheduled skip invokes
  nothing.
- Affordability And Reason Codes: the `scheduled_skip` row in the closed
  table (`:1137-1143`).
- Persistence Contract, Fold Evidence And Early Exit and Completion And
  Resume Evidence: one pulse-level skip row; a state row on every processed
  pulse including skips.
- Strategy Contract, Supported Strategy Surface and Provenance And Recovery:
  the scheduled strategy class; the new provenance fields; recovery
  re-attaching the declaration.
- Result Contract, read surfaces: the two counts in run information.
- Documentation Contract: the decorator is the taught scheduling idiom.

Stored-format changes, one bump of `ledgr_experiment_store_schema_version`
(`R/experiment-store-schema.R:1`, 123 to 124): `run_provenance` columns
`schedule_json` and `schedule_hash`; `run_telemetry` columns
`decision_pulse_count` and `scheduled_skip_count` beside `pulse_count`
(`R/db-schema-current.R:106-112`); the `scheduled_skip` token. Candidate
identity payloads for sweep and walk-forward bump their own schema versions.
Older stores refuse through the existing current-store gate; no migration, no
legacy reader. The schema golden-rows fixture changes with the product change
and the ticket evidence states that reason.

Documentation: `strategy-authoring-tools.qmd` teaches the decorator and
retires hand-rolled guards; `minimum-variance.qmd` drops the two-session
history read when the article rewrite the macro plan already schedules runs;
`research-workflow.qmd` and `causal-history.qmd` replace guard examples;
`reproducibility.qmd` and `experiment-store.qmd` document the provenance and
telemetry fields; the pkgdown reference index gains the new exports; `NEWS`
records the schema bump. Vignettes execute, so the decorator is exercised in
the rendered articles.

Evidence the ticket cut must register (Section 10).

## 9. Counts And Disclosure

Decision and scheduled-skip counts are computed once from the compiled mask
over the whole run calendar at finalization and written to `run_telemetry`;
they are never inferred from diagnostic rows, which exist only on the
availability path. `print.ledgr_run_info()` shows them with the schedule
line. A run with zero decision pulses is loud in that line and is subject to
D2. Whether sweep result rows also carry the counts is a spec-cut question.

## 10. Acceptance Evidence For The Ticket Cut

The cut registers at least:

- counters proving zero P2 frame, context, history-helper and strategy calls
  on scheduled skips;
- a counter proving zero P3 target-planning calls on scheduled skips;
- P1, P4 and P5 counters proving those stages run on every processed pulse;
- a corporate-action entitlement bound in P4 on a skipped decision pulse and
  posted correctly at the next pulse;
- corporate-action cash, disposition and terminal postings in P1 on skipped
  pulses;
- a stateful strategy proving strategy state changes only on decision pulses
  while a `strategy_state` row exists for every processed pulse, and a
  resume from a skipped pulse reproducing the uninterrupted run;
- the diagnostic distinction between a scheduled skip (one `scheduled_skip`
  row, no per-ID rows) and an explicit hold (per-ID `decision_recorded`
  rows);
- run, sweep, run-window, sweep-window, walk-forward, promotion and resume
  parity for one scheduled strategy;
- parent-axis cases: first session of the axis, last session of the axis,
  partial first period under the resolved D1, a fold boundary inside a
  period, an explicit date between sessions, an explicit date beyond the
  axis (refusal), a period-end rule at the last declared session;
- schedule identity, provenance and preflight mutations: two otherwise equal
  candidates with different schedules differ in identity; the same inner
  under two schedules shares `strategy_source_hash`; a tier-3 inner is
  refused through the decorator exactly as bare; recovery returns a scheduled
  function;
- the no-schedule byte-identity ladder against the pre-scheduler tree on both
  execution modes, over result surfaces and diagnostic rows;
- a structural detector that fails if schedule evaluation moves into P2 or
  the pulse loop performs any per-pulse calendar computation, and that
  asserts the mask is one logical vector prepared once;
- a paired H1 clock against the manual-guard arm on the current workload,
  three alternating pairs, reporting end-to-end wall time and the recovered
  share of the measured 14.17 seconds, with identical fills, equity, state
  and diagnostics from the first common true boundary;
- no pending-fill witness, because no such cross-pulse state exists; and
- dense and availability parity only for the no-schedule case.

The ticket cut binds the materiality threshold after the implementation is
measurable; this seed does not turn the lower bound into a promised speedup.

## 11. Maintainer Decisions Carried To Stage 6

These two choices are not resolvable from existing authority or evidence.
Seed v2 recommends and does not bind.

**D1. Partial first period.** A run or fold begins inside an already-started
period.

- Option A: wait for the next real declared boundary.
- Option B: decide on the first executable pulse.

Consequences. A flat opening under A holds cash until the next boundary, and
the run-info count discloses it; under B it invests on the first pulse. A
carry-forward fold under A rebalances only at true boundaries, so the chain is
one continuous schedule; under B every fold rebalances at its first pulse, the
false-start artifact the response's F7 names, unless folds are exempted, which
reintroduces per-window semantics. The H1 benchmark guard behaves as B,
because its `state_prev` is empty on the first pulse; the minimum-variance
article behaves as A, because it reads the predecessor session. Under A the
paired H1 clock starts on a true boundary or compares from the first common
boundary.

Recommendation: Option A, with opening allocation left to opening policy and
performance comparison beginning at a common true boundary.

**D2. Zero decision pulses.** A resolved schedule yields no decision pulse in
the executable range.

- Option A: refuse before execution only a run with no decision pulse and no
  opening or carried positions, while allowing and disclosing legitimate
  carry-forward folds and runs that hold positions.
- Option B: always allow the run and disclose zero decisions in run
  information.

Why not an unconditional refusal: a quarterly schedule inside a two-month
test window with carried positions is a legitimate hold-through fold; refusing
it would abort the walk-forward chain. Under A a flat run that can never trade
is refused as a misconfiguration; under B it runs flat and the count is the
only signal.

Recommendation: Option A.

## 12. Rejected Alternatives

- Opaque closure wrapper (seed v1): refused by preflight as tier 3, collapses
  inner provenance, cannot skip P2, and belongs to the LFB-035 collision class.
- Mutable closure state as the calendar memory (seed v1 option A): resets on
  resume; no cursor exists to restore.
- Schedule facts on `ctx` (seed v1 option C): grows the strategy-visible
  surface for one feature and still requires P2.
- Strings instead of rule constructors: no rule-version carrier and less
  inspectable.
- `function(ctx)` predicates: require P2 and conflate scheduling with strategy
  logic; a later decision-gate surface may compose with a schedule.
- Axis-function escape hatch: compile-time evaluable, but adds preflight and
  identity surface for no first-implementation need; explicit dates suffice.
- Extending `ledgr_param()` to schedules: a cross-surface change to a
  feature-only resolver; ordinary grid parameters already carry identity.
- A new internal no-decision result class: a reason token and a null decision
  carry the distinction.
- Treating a skip as `ctx$hold()`: fabricates a callback result and per-ID
  decision rows for a strategy that did not run.
- Skipping P4: `bind_boundary` is per-pulse work.
- Omitting the P5 state write on skips: it is the resume cursor.
- Omitting the reconciliation row on skips: saves under one percent and makes
  the evidence shape schedule-dependent.
- Persisting the mask: a deterministic derivative of identity-bearing inputs.
- Window-relative dense edges: dishonest period edges for a frozen mode
  scheduled for removal.
- Inferring counts from diagnostics: availability-only and skip-shaped.
- Event-to-event stepping or `fast = TRUE` now: a second semantic mode until
  proven under the pulse oracle.
- Absorbing Momento's execution weekday: order policy, not invocation timing.
- Unconditional zero-decision refusal: rejects legitimate carried folds (D2).
- Forcing a first decision by default: manufactures fold starts (D1).

## 13. Open Questions Promoted To Spec-Cut

- Exact exported names, tested against naming rule R1: decorator, rule
  constructors, the parameterized form.
- The first menu: whether `year_start` and the `_end` variants of week and
  quarter ship.
- Whether the compiler lives inside `ledgr_execution_spec()` or in one helper
  both call sites invoke; the spec slot's name.
- Exact column names for the provenance and telemetry fields; whether sweep
  result rows carry the counts; the candidate-schema version numbers.
- The skip row's `instrument_id` placeholder and `detail_json` content.
- Print formats for experiment, plan and run info.
- Which article sections change in the same cut and which wait for the
  scheduled minimum-variance rewrite.
- The paired clock's start alignment under the resolved D1.
- The exact classed condition names for the dense refusal, the unknown rule
  name, the date beyond the axis and the duplicated session date.

## 14. Future Obligations Recorded

- Portfolio-construction RFC: the weight-strategy wrapper and rebalance bands
  consume this scheduler; they do not redefine it.
- Execution and order-policy RFC: delayed target release, pending orders and a
  distinct execution weekday; Momento is the acceptance case.
- A later decision-gate RFC, only on evidence: `function(ctx)` gates composing
  with a compiled schedule, outside the held-pulse performance claim.
- Historical accelerator: internal event-to-event batching under the pulse
  oracle, with its own evidence, after the scheduler ships.
- Execution-core consolidation: when bars-only snapshots gain a declared
  session axis, the dense refusal lifts; no scheduler work is needed.
- LFB-035 defect ticket: fingerprint function-valued captures and repair the
  `ledgr_signal_strategy()` collision; outside this RFC.
- Horizon: promotion of observed custom date vectors into menu rules.

## 15. Cycle State And Next Stage

Stages run: seed v1 (Claude, 2026-06-12), Type 2 response (Codex,
2026-10-25), response review (Claude, 2026-10-25), this seed v2 (Claude).
Research input skipped: the corpus and the WS53 measurement cover it. No
spike.

Next: maintainer decisions D1 and D2 (stage 6), recorded in
`rfc_strategy_schedule_decorator_v0_1_9_x_maintainer_decisions.md` or in
place here with a revision note. Then decision synthesis by Codex, the author
who did not write this seed. Then a Type 1 final review by an author of
neither seed v2 nor the synthesis.

## Revision History

- 2026-10-25 - Seed v2 written from the response and response review.
  Incorporates the review's nine patches: P4 runs on every pulse (5.4); no
  pending fills (5.4); the P5 state write is the resume cursor (5.5); the
  skip token extends a closed vocabulary (5.5, 8); one pulse per session and
  no intraday design (5.2); classed-function representation (4, 5.1);
  diagnostic-arm denominator (2); dense parity scoped to the no-schedule case
  (5.3); zero-decision behavior escalated as D2 (11).
