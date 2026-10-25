# Response Review: Strategy Scheduling And Held-Pulse Skipping

**Status:** Response review complete; disposition
`RESPONSE_ACCEPTED_AFTER_PATCHES`.
**Mode:** Type 2 response review (RFC cycle stage 4), by the original seed
author.
**Date:** 2026-10-25.
**Author:** Claude (seed v1 author; not the response author).
**Reviewed artifacts:** `rfc_strategy_schedule_decorator_v0_1_9_x_seed.md`
(Claude, 2026-06-12) and
`rfc_strategy_schedule_decorator_v0_1_9_x_response.md` (Codex, 2026-10-25),
against tree `1cd4e0c9` on `v0.2.2`. Every line anchor below is read from
that tree.
**Question (maintainer brief):** Does Codex's response correctly challenge the
scheduler seed against ledgr's current architecture and evidence, or does it
reject useful parts, introduce unnecessary machinery, misread the fold stages,
or leave important failure modes unresolved?

This review binds nothing. It tells seed v2 what to adopt, change and reject,
corrects citations, and names the two decisions that belong to the maintainer.

## 1. Overall Disposition

`RESPONSE_ACCEPTED_AFTER_PATCHES`.

The response's central correction stands, and the tree makes it stronger than
the response states. A `function(ctx, params)` wrapper cannot recover the
measured held-pulse cost because P2 builds the public frames and `ctx` before
the callback (`R/fold-engine.R:650-760`) and validates, risk-adjusts and traces
the returned targets after it (`:811-971`); the wrapper sits between those two
blocks and can skip only the inner call. By subtraction from the WS53 totals
(`t_ctx` 9.16 s; `t_target` 4.97 s, of which 4.64 s on held pulses), the inner
callback is roughly one second of the 14.17 seconds. That figure is derived,
not measured, and it says the seed v1 architecture recovers under a tenth of
the opportunity. A read-only probe (Section 2) adds that a closure wrapper over
an inner strategy is refused by preflight today as tier 3, so seed v1's
"returns an ordinary strategy" was never executable without a preflight bypass.

The response's architecture, a declarative schedule compiled before the fold
that gates P2 while P1 and P5 run every pulse, is the smallest design that
earns the measured cost and adds no second fold. Seed v2 should be written
from it with these patches:

1. **P4 is not empty work on a held pulse.** `bind_boundary(pulse_idx + 1L,
   positions)` runs in P4 on every pulse (`R/fold-engine.R:1246`;
   `R/corporate-action-settlement.R:460-471`), binding the next pulse's
   corporate-action entitlement quantities to current positions. Response
   Section 2.2 says P3 and P4 "may ... be bypassed by the existing envelope
   only where their work is empty"; P4's work is not empty. The envelope may
   skip P2 and P3; P4 runs with an empty plan.
2. **There are no pending fills across pulses.** A fill is planned in P3
   against the next declared session (`R/availability-economics.R:391`;
   `R/fold-engine.R:1020`) and booked in P4 of the same pulse with that
   execution time (`:1283-1340`). The "pending-fill witnesses" in response
   Section 6 name a state that does not exist. Replace them with witnesses for
   corporate-action binding (P4) and corporate-action, disposition and terminal
   postings (P1) on pulses where P2 is skipped.
3. **The P5 strategy-state write is the resume cursor.** The persistent resume
   path derives `start_idx` from `MAX(ts_utc)` over `strategy_state`
   (`R/run-resume.R:31`, `:53`); the availability commit writes the carried
   state on every pulse (`R/fold-engine.R:1450-1470`). The response is right
   that P5 runs every pulse; seed v2 must state this reason and must not list
   the per-pulse state write as a candidate omission.
4. **F4's diagnostic distinction extends a closed vocabulary.** The durable
   availability reason-code vocabulary is "closed for this schema"
   (`inst/design/contracts.md:1137`). One new decision token for a scheduled
   skip is a contract amendment and a schema bump at acceptance; the response
   does not say so.
5. **F6 exceeds current authority.** The pulse is `"EOD"` by construction
   (`R/backtest-config.R:198`); the availability calendar emits one pulse per
   open session row (`R/availability-provider.R:395-404`); the contracts refuse
   first-class intraday execution (`contracts.md:2589-2592`). Seed v2 derives
   period membership from `session_date` and asserts one pulse per session; it
   designs no within-session pulse selector.
6. **Bind the representation.** The response leaves the scheduled value's R
   shape open. A classed function carrying the declaration as attributes keeps
   every existing `is.function` and signature gate (`R/experiment.R:464-485`;
   `R/sweep.R:1686`; `R/strategy-fn.R:4-8`), survives the registry and
   serialization (probe), and matches the one existing wrapper precedent
   (`R/signal-strategy.R:160`; `R/strategy-preflight.R:87-105`).
7. **The 22.6 percent share is of the 62.65-second every-pulse diagnostic
   arm**, not the public-run wall (closeout, "Scheduler result and telemetry
   decision"; `macro_plan.md:402-403`). `macro_plan.md:759` carries the
   imprecise phrasing the response inherited.
8. **Section 6 and Section 5 item 3 conflict.** The evidence list requires
   dense and availability parity, while period-end rules are to be refused
   without a declared session calendar, which dense never has. Seed v2 scopes
   the parity evidence to rules both axes express, or decides dense behavior
   explicitly (Section 4, M5).
9. **Section 5 item 5 would refuse legitimate folds.** A pre-execution
   refusal of zero decision pulses rejects a carry-forward walk-forward fold
   whose test window holds no boundary of a quarterly schedule. The decision is
   escalated with a narrower recommendation (Section 7, D2).

None of these reopens the architecture. Two product choices remain for the
maintainer (Section 7). No spike is needed (Section 8).

## 2. Evidence And Probes

Read in the brief's order: `AGENTS.md`; `inst/design/rfc_cycle.md`; the seed;
the response; the accepted fold-phase synthesis; the WS53 closeout; the
research strategy UX brief; the portfolio-method exercises (Momento case);
macro plan WS6 and Section 7; `R/execution-spec.R`, `R/backtest-config.R`,
`R/experiment.R`, `R/backtest-runner.R`, `R/fold-engine.R`,
`R/feature-parameters.R`. Followed by call graph: `R/fold-phase-contract.R`,
`R/run-resume.R`, `R/sweep.R` (candidate spec), `R/walk-forward.R` (per-fold
config), `R/availability-provider.R` (calendars), `R/run-snapshot.R` (dense
calendar), `R/corporate-action-settlement.R` (`bind_boundary`),
`R/history-substrate.R` (fold reader), `R/strategy-provenance.R`,
`R/strategy-preflight.R`, `R/strategy-fn.R`, `R/determinism.R`,
`R/signal-strategy.R`, `R/db-schema-current.R` (`snapshot_sessions`), the
contracts' decision-trace and reason-code rules, the H1 bench strategy
(`dev/bench/v0_2_2_real_data_scale/fixture.R:97-98`, `run_record.R:185-186`)
and the taught guard in `vignettes/minimum-variance.qmd:212-222`.

Two read-only probes, R 4.6.1 with `pkgload::load_all()`, scripts kept in the
session scratchpad and not committed:

| Probe | Result |
| --- | --- |
| Closure wrapper `out <- function(ctx, params) inner(ctx, params)` with an attribute, around two different inner strategies | passes `ledgr_experiment_validate_strategy()` and `ledgr_strategy_signature()`; `ledgr_strategy_source_info()` returns identical source and identical hash for both; preflight tier `tier_3`, `allowed = FALSE`, reason "unresolved symbol(s): inner"; `ledgr_strategy_spec()` aborts with `ledgr_strategy_tier3`; `ledgr_register_strategy_fn()` returns the same key for both; the attribute survives the registry and `serialize()` |
| Two `ledgr_signal_strategy()` wrappers with different inner signal functions and default quantities | same registry key; after registering the second, `ledgr_get_strategy_fn(key)` returns the second; same `strategy_source_hash`; `codetools::findGlobals(merge = FALSE)` lists `fn` under `functions`, not `variables`, and the fingerprint hashes only `$variables` (`R/determinism.R:139`) |

The first probe settles M1 and confirms F2; the second establishes M2.

## 3. Finding-By-Finding Disposition

| Finding | Disposition | Grounds |
| --- | --- | --- |
| F1 Seed defers the optimization that justified reopening | ACCEPT | `ctx` is built at `R/fold-engine.R:650-760`, the callback runs at `:776`, validation, risk and the per-ID decision trace follow at `:811-971`, and the delta computation that `t_target` also covers is in P3 (`:1008-1015`). A wrapper skips only `:776`. Derived callback share on held pulses is about one second of 14.17. |
| F2 "Returns an ordinary strategy" is an implementation constraint | ACCEPT_WITH_CHANGE | Diagnosis holds and is understated: a plain closure wrapper is refused by preflight (probe) and its deparsed source omits the inner strategy (`R/strategy-provenance.R:59-60`; `R/determinism.R:48`). Change: bind the classed-function representation now (patch 6) rather than leaving it to synthesis; the inner strategy's source, tier and identity must be captured explicitly (M2, M7). |
| F3 A general `function(ctx)` predicate defeats the fast path | ACCEPT_WITH_CHANGE | Correct for `ctx` predicates. The criterion is not declarative versus function but evaluable on the axis before the fold: a function of session dates is compile-time vectorizable and identity-bearing. Seed v2 defers both hatches; explicit date vectors already cover custom calendars. Do not describe the deferral as "predicates require P2" in general. |
| F4 A fabricated hold target is not the right internal result | ACCEPT_WITH_CHANGE | The semantic distinction holds: an invoked hold runs validation, risk and the per-ID decision trace (`:811-971`), may carry `intent_reason` (`:811-822`) and a state update; a skip does none of that. Change: no new internal class. The envelope skips P2 and P3 and hands P4 and P5 a null decision and an empty plan; diagnostics record one one-row decision segment with a new token, following the `empty_public_domain` shape (`:833-838`). That token extends the closed vocabulary (patch 4). |
| F5 Stage behavior on a skipped pulse is underspecified | ACCEPT with patches 1-3 | P1 unchanged (`:272-628`). P2 and P3 absent. P4 runs with an empty plan because `bind_boundary` is per-pulse (`:1246`). P5 runs: flush, trivial reconciliation against current cash, carried state write (resume cursor), `processed`, telemetry, checkpoint, interrupt (`:1349-1512`). No pending fills exist. Open question: whether the `affordability_reconciled` row (`:1430`) is emitted on a skip; recommendation in Section 6. |
| F6 Calendar semantics not precise enough for intraday use | ACCEPT_WITH_CHANGE | Adopt `session_date` as the period-membership fact (`R/db-schema-current.R:284-291`). Reject the two-level session-then-pulse model and the intraday hedging (patch 5). The facts loader already refuses duplicate session dates within a venue (`R/availability-facts.R:732`); the compiler asserts one pulse per `session_date` across the run calendar and refuses otherwise. |
| F7 Fold and window boundaries need one global rule | ACCEPT | The parent axis exists: every fold's calendar is cut from the same `provider$sessions` table (`R/availability-provider.R:380-404`), and walk-forward builds one `ledgr_config()` per fold on the same snapshot (`R/walk-forward.R:404-437`). Reading first-pulse membership from the predecessor session removes the false fold start. Two edges to bind: the snapshot's first session has no predecessor (recommend: counts as a period start); the partial first period is a product choice (D1), on which the two shipped idioms disagree (M8). |
| F8 `month_end` requires declared future calendar knowledge | ACCEPT | Same knowledge the fold already consumes: `execution_opportunities_posix` must name the next declared session open for every pulse (`R/execution-spec.R:280-282`; `R/availability-provider.R:404-416`). Edge to bind: the last declared session has no successor (recommend: not a decision pulse; disclosed in the count). |
| F9 The sweepability claim is incorrect | ACCEPT | `ledgr_param()` resolves only through the six-constructor registry (`R/feature-parameters.R:290-299`, `:239-262`) and is refused elsewhere (`:63-69`). Route 1 is cheap: a schedule argument may name an ordinary strategy-grid parameter, resolved from `strategy_params` at spec build, which both spec call sites hold (`R/backtest-runner.R:1309`; `R/sweep.R:1698`). |
| F10 Identity covers semantics, not the mask | ACCEPT | Walk-forward identity consumes the strategy hash from config provenance (`R/walk-forward.R:438-480`; `R/walk-forward-identity.R:35-68`), so the schedule must enter that hash or a named identity component; the mask is recomputed. Decision and held counts are derived at finalization, not stored as a mask (M9). |
| F11 Momento two-clock case stays outside | ACCEPT | Decision time and execution time are already separated by next-open timing; retaining a target to another weekday is order policy. Record as an acceptance case, per the exercises' routing table. |
| F12 Event-to-event fast-forwarding is a later optimization | ACCEPT | P1 records an equity fact and advances valuation ageing on every pulse (`:583`, `:272-330`); any accelerator must reproduce those per-pulse facts. Nothing in this cycle designs it. |

## 4. Missed Architectural And Failure-Mode Findings

- **M1. Preflight refuses a closure wrapper.** `ledgr_strategy_preflight()`
  classifies a closure that calls a captured `inner` as tier 3 and
  `ledgr_strategy_spec()` aborts (probe). The only precedent bypass,
  `ledgr_signal_strategy()`, sets an attribute that short-circuits preflight to
  tier 2 with a note that the inner function must be inspected separately
  (`R/strategy-preflight.R:87-105`). Seed v2 must bind a preflight rule for
  scheduled strategies: the inner strategy is preflighted and its tier passes
  through; the declaration adds no tier and no unresolved symbol.
- **M2. Function-valued captures are outside the registry key and the source
  hash.** `ledgr_register_strategy_fn()` keys on body, formals and
  `findGlobals()$variables` (`R/determinism.R:119-170`); captured functions
  are not hashed, and `ledgr_strategy_source_info()` deparses only the outer
  body. Two `ledgr_signal_strategy()` wrappers with different signal functions
  and equal quantities share one key and one `strategy_source_hash`; the
  second registration overwrites the first, and a config built from the first
  executes the second in the same session (probe). This is a shipped latent
  defect independent of this RFC; it is recorded here and should be routed as
  a defect ticket by the maintainer. For the scheduler it decides a design
  constraint: inner-strategy identity must enter the registry key and the
  provenance explicitly, never through closure capture.
- **M3. Two execution-spec call sites.** The runner (`R/backtest-runner.R:1309`)
  and the sweep (`R/sweep.R:1698`) each build `ledgr_execution_spec()`;
  walk-forward routes through the runner. The schedule compiler needs one
  home, inside `ledgr_execution_spec()` or one helper both call, or a second
  path appears. The spec already carries `pulses_posix` and, on the
  availability path, `availability_provider$sessions`.
- **M4. Decision-trace contract wording.** "One decision trace row per
  invoked axis ID" (`contracts.md:1220-1221`) tolerates no per-ID rows on a
  skipped pulse, but "An empty Daxis still invokes the strategy"
  (`contracts.md:1032`) shows that today every processed pulse invokes the
  strategy. A scheduled skip is the first processed pulse without invocation;
  the Strategy and Context contract language must say so at acceptance, and the
  new token joins the closed table at `contracts.md:1137-1143`.
- **M5. The dense axis has no predecessor and no sessions.**
  `ledgr_run_snapshot_calendar()` reads only the window's bars
  (`R/run-snapshot.R:142-160`), so a dense run cannot know whether its first
  pulse starts a period and cannot see past its last pulse. Dense is frozen by
  release-line decision and a new mode branch is forbidden (`AGENTS.md`). Seed
  v2 should compile from the calendar object the runner already built,
  document that dense period edges are window-relative, and limit the parity
  evidence to mid-window decision pulses and the no-schedule byte ladder. A
  dense-only refusal is the alternative; either way the choice is resolvable
  from existing authority and needs no maintainer decision.
- **M6. P1 history work stays, and the saving may exceed the lower bound.**
  P1 reads the bar packet and the lazy history view every pulse
  (`R/fold-engine.R:282`, `:287`; `R/history-substrate.R:394-418`); the packet
  feeds P1 marks and P3 `next_bars`, so `t_feats` (14.95 s) is not scheduler
  scope. Conversely, skipping P2 removes the per-ID decision trace segment that
  the P5 block flush serializes (`:830-870`, `:1433-1444`), so the paired
  clock may recover more than 14.17 seconds. Seed v2 should state both bounds.
- **M7. Provenance fields change.** `strategy_source` and
  `strategy_source_hash` must be the inner strategy's, and the schedule
  declaration, its resolved value and rule version are separate provenance
  fields. That is a `run_provenance` schema change, permitted pre-CRAN with a
  version bump and a classed refusal of older stores; the response says
  "provenance work" without naming the stored-format consequence.
- **M8. The two shipped idioms disagree on the partial first period.** The H1
  bench strategy decides on its first pulse because `state_prev$month` is
  `NULL` (`fixture.R:97-98`; `run_record.R:185-186`); the taught
  minimum-variance article waits, reading two sessions of history and holding
  while both share a month (`vignettes/minimum-variance.qmd:212-222`), which
  the macro plan names as the "dummy two-session history read" the scheduler
  should remove (`macro_plan.md:1228`). The response's paired-clock evidence
  "where the semantics are meant to match" must name which idiom it matches.
  This feeds D1.
- **M9. Decision and held counts are mode-dependent.** Only the availability
  path writes decision traces; dense writes none. The seed v1 print surface
  (decision and held counts) should be computed from the compiled verdicts at
  finalization and recorded once in run info, not derived from diagnostics.

## 5. Corrections To Citations And Measured Claims

| Response text | Correction |
| --- | --- |
| Section 1: "22.6 percent of public-run wall" | 22.6 percent of the 62.65-second every-pulse diagnostic arm (closeout "Scheduler result and telemetry decision"; `macro_plan.md:402-403`). The public-path profile run was 60.99 s; one-worker medians were 58.42 to 75.36 s. `macro_plan.md:759` has the same imprecision. |
| Section 2.2: "P3 and P4 may ... be bypassed by the existing envelope only where their work is empty" | P4 binds the next pulse's corporate-action entitlements on every pulse (`R/fold-engine.R:1246`); it is never empty. P3 may be absent. |
| Section 2.2: P2 "is the stage the H1 measurement says can be absent" | `t_target` straddles P2 (`:971`) and P3's delta computation (`:1008-1015`); recovering the 4.64 s on held pulses requires P3 to be absent as well. |
| Section 3 F5: "already-due economic obligations are not cancelled by the schedule"; Section 6: "pending-fill witnesses" | No fill pends across pulses; the only cross-pulse economic work is corporate-action binding (P4) and corporate-action, disposition and terminal postings (P1). |
| Section 3 F5 and Section 4: P5 "strategy-state persistence" as a duty | It is also the resume cursor (`R/run-resume.R:31`, `:53`); the response's conclusion is right, its reason incomplete. |
| Section 3 F2: "Current experiment validation accepts an ordinary strategy function" | Correct and incomplete: preflight refuses a closure wrapper over an inner strategy (probe). |
| Section 3 F4: "The fold needs an internal typed no-decision result, such as `not_scheduled`" | A null decision plus a one-row decision segment suffices; the token, not a type, carries the distinction, and the token is a closed-vocabulary extension (`contracts.md:1137`). |
| Section 3 F6: session selection then pulse selection | Out of authority (`contracts.md:2589-2592`; `R/backtest-config.R:198`). |
| Section 6: "dense and availability-active parity" together with Section 5 item 3 | Mutually inconsistent for period-end rules; scope the evidence (M5). |

Response statements verified correct and worth keeping verbatim: the stage
census (P1 observe and settle; P2 frames, context, call, validation; P5
commit); `ledgr_strategy_spec()` recording source and provenance
(`R/backtest-config.R:34-50`); `ledgr_param()` being feature-only (F9); resume
recomputing verdicts from the same pulses (`R/run-resume.R:53`; the mask is
indexed by `pulse_idx` in the envelope loop at `R/fold-engine.R:1843`).

## 6. Recommendations For Seed v2

**Adopt from the response:**

- Declarative schedule compiled before the fold; P1 and P5 on every pulse; P2
  absent on a skip; one fold; no event-to-event stepping; no `fast = TRUE`.
- Period membership from the declared session axis (`session_date`); period
  ends only where the next declared session exists; explicit dates snap to
  declared sessions and refuse beyond the axis.
- Compile on the parent session axis and index by run pulse; recompute on
  resume; never persist the mask.
- Identity: declaration, resolved value and rule version enter candidate and
  run identity; inner source hash stays separately identifiable; a later
  internal optimization with identical pulse results must not change identity.
- Parameterization route 1: a schedule argument may name an ordinary
  strategy-grid parameter.
- Momento stays an acceptance case; delayed execution is order policy.
- The evidence list of response Section 6, with the pending-fill item replaced
  (patch 2) and the parity item scoped (patch 8).

**Change:**

- Representation: a classed function carrying the declaration as attributes
  (patch 6), with inner-strategy identity explicit in registry key and
  provenance (M2, M7) and a pass-through preflight rule (M1).
- No-decision path: null decision and empty plan handed to P4 and P5; one
  one-row decision segment with a new token; P4 runs every pulse (patch 1).
- Calendar scope: one pulse per session asserted, not designed around (patch
  5); dense edges window-relative or dense refused, chosen in seed v2 (M5).
- Compiler home: one helper reachable from both spec call sites (M3).
- Counts: computed at finalization from the compiled verdicts (M9).
- Period edges: snapshot's first session counts as a period start; its last
  session is not a period end (F7, F8 notes).
- Reconciliation row on a skipped pulse: emit it with held exposures and a
  trivially reconciled cash, so the per-pulse evidence ladder keeps its shape;
  the `canonical_json` cost of that row is below the gate. Seed v2 may argue
  the opposite; it must choose.

**Reject:**

- Any `function(ctx)` predicate in the first implementation (agreed with the
  response), and also any axis-function hatch; explicit date vectors cover v1.
- The within-session pulse selector and intraday hedging of F6.
- A new internal result class for the skip.
- Treating the P5 state write as an omission candidate.
- Pre-execution refusal of zero decision pulses as stated (see D2).

## 7. Maintainer Decisions

Only two choices cannot be settled from existing authority or evidence. Seed
v2 carries them with the recommendations below for RFC stage 6.

- **D1. Partial first period.** A run or fold whose first pulse falls inside a
  period: (a) wait for the next declared boundary, or (b) decide on the first
  pulse. Under (a) a flat run started mid-month holds cash until the next
  month start, and a carry-forward fold rebalances only at true boundaries;
  under (b) every carry fold rebalances at its first pulse, the false-start
  artifact F7 names, unless folds are exempted, which reintroduces per-window
  semantics. The shipped idioms split: the H1 bench guard does (b), the taught
  article does (a) (M8). Recommendation: (a), with opening allocation left to
  opening policy, and the paired H1 clock started on a period boundary or
  compared from the first common boundary.
- **D2. Zero decision pulses.** The response recommends a classed refusal
  before execution. That refuses a carry-forward fold whose window holds no
  boundary, which is a legitimate hold. Recommendation: refuse only a run with
  zero decision pulses and no opening or carried positions, since it can never
  trade; otherwise run and disclose the count. Alternative: never refuse, only
  disclose.

Resolvable without the maintainer, with the resolving authority: declarative
only (measured cost and `:650-760`); period ends need a declared calendar
(no-lookahead rule and the F8 precedent); one pulse per session (construction);
parameterization route 1 (design); names tested against the naming synthesis
and the UX brief's `ledgr_on_schedule(ledgr_month_end())` shape (design).

## 8. Spike

Not necessary. Every claim in this review was settled by reading the tree and
by two read-only probes under a minute each. The remaining empirical question,
how much of the 14.17 seconds a P2 and P3 skip recovers end to end on H1 with
identical fills, equity, state and diagnostics, is the ticket cut's paired
clock (response Section 6), not a design-stage unknown.

## 9. Next RFC Stage

Seed v2 by Claude:
`rfc_strategy_schedule_decorator_v0_1_9_x_seed_v2.md`, incorporating Sections
1, 4 and 6 and carrying D1 and D2 as maintainer decisions for stage 6. Then
decision synthesis by Codex (role rotation: the author who did not write v2),
and a Type 1 final review by an author of neither.

Record-only routing from this review: M2 (registry and provenance ignore
function-valued captures) is a shipped defect outside this RFC; the maintainer
decides whether to open a defect ticket. No ticket, contract, code or test is
changed by this review.

## Revision History

- 2026-10-25 - Response review written. Files changed: this file and the
  scheduler row of `README.md`.
