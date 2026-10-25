# Final Review: Strategy Scheduling And Held-Pulse Skipping

**Verdict:** `PASS_AFTER_PATCHES`.
**Mode:** Type 1 final review.
**Date:** 2026-10-26.
**Reviewer:** independent of the seed v2 and synthesis authors.
**Reviewed tree:** `1cd4e0c9` on `v0.2.2`, plus the uncommitted RFC-cycle
artifacts named in the review brief.

The accepted architecture is faithful, necessary and implementable in the one
existing fold. No finding requires Type 2. Four bounded synthesis patches are
required before acceptance and ticket cutting: make the parent axis explicitly
the ordered declared-open-session axis and bind Monday weeks; complete the
failure-sensitive evidence list; enumerate the affected versioned sweep,
walk-forward and promotion formats; and restore the documentation consequence
that seed v2 carried. These are corrections and completeness patches, not new
design choices.

## 1. Input Adequacy And Necessity

The inputs are the right inputs. The measured problem comes from the production
H1 workload, not a synthetic microbenchmark: 6,868 of 7,213 pulses were held,
and their context, callback and target work totalled 14.17 seconds. The correct
denominator is the 62.65-second every-pulse diagnostic arm, so 22.6 percent is
accurate in synthesis Sections 1 and 5. It is not 22.6 percent of the 60.99
second public-path profile. `macro_plan.md` Section 7 retains that older
imprecise phrase, but the synthesis does not repeat it.

The proposal does not duplicate a public capability. Current strategies can
hand-roll guards, but no public API exposes a declarative, identity-bearing
schedule before P2, and a callback guard cannot avoid public frame and context
construction. The ordinary strategy grid supplies candidate values, but it
does not resolve a schedule declaration automatically; D10 correctly assigns
that new validation and resolution step to candidate compilation rather than
claiming `ledgr_param()` already does it.

The fold-phase synthesis, current phase code, resume cursor, session provider,
identity code and stored readers are sufficient to cut tickets once the four
patches below are applied. No prerequisite spike or second fold is justified.

## 2. Fidelity Assessment, D1-D13

| Decision | Assessment | Verification |
| --- | --- | --- |
| D1, classed function | Faithful. | Matches seed v2 Sections 4, 5.1 and 7. `is.function()`, the `(ctx, params)` signature, calling and serialization all survive the class and declaration attribute. Attribute-stripped preflight, source capture and registration are required exactly as stated. The design avoids rather than repairs LFB-035. |
| D2, one compiler and verdict vector | Faithful. | There are exactly two production `ledgr_execution_spec()` construction sites, `R/backtest-runner.R:1309` and `R/sweep.R:1698`. One shared compiler can serve both. Recomputing rather than persisting the logical vector reuses snapshot/config identity guarantees. |
| D3, session rules | Faithful to accepted maintainer D1, but incomplete until F1 is patched. | The correction that an unproved first parent-axis session is not a period start is required verbatim by accepted maintainer D1 and properly overrides seed v2 Section 5.2. No other accepted authority conflicts. The synthesis must restore seed v2's `status == "open"` axis qualifier and Monday-week definition. |
| D4, one pulse per session | Faithful. | Current configs declare `pulse = "EOD"` (`R/backtest-config.R:198`), availability calendars emit one pulse per ordered open-session row (`R/availability-provider.R:395-404`), and duplicate session dates are refused (`R/availability-facts.R:731-733`). No intraday selector is smuggled in. |
| D5, declared-axis requirement | Faithful. | Dense calendars are derived only from bars inside the window (`R/run-snapshot.R:142-162`) and lack the predecessor/successor facts needed for the bound rules. A missing-axis refusal is consistent with the existing sessions-required capability gate and does not create a second execution mode. |
| D6, one-fold gate | Faithful and implementable. | P1 returns the post-settlement positions and valuation packet; P2 and P3 can be bypassed after P1; P4 can receive an empty accounting plan; P5 can use the P1 packet, fold state and zero timing values. This is one branch inside the existing envelope, not a second fold. |
| D7, skip versus hold | Faithful. | Current explicit holds traverse target validation, risk and per-ID decision tracing. A skip can instead append one pulse-level segment, retain the ordinary reconciliation row and create no public intent. `scheduled_skip` is a new member of the contract's closed reason vocabulary and therefore a stored-format change. |
| D8, state and resume | Faithful. | `R/run-resume.R:31-55` derives the next pulse from the latest `strategy_state` timestamp. `R/fold-engine.R:1449-1468` owns the state write. The scheduler must write the carried value even when that value is null, because the row timestamp is also the cursor. The compiled mask needs no persisted cursor. |
| D9, zero decisions | Exact representation of accepted maintainer D2. | It refuses only after the current run/fold's resolved verdicts and opening/carry positions are known, and permits position-carrying observation-only folds. This is implementable after opening/carry reconstruction and before entering the fold loop. F2 adds the missing detecting witnesses. |
| D10, ordinary strategy parameters | Faithful. | `ledgr_param()` is feature-constructor-specific. Ordinary `strategy_params` already enter candidate identity; the new work is the explicitly bound pre-fold lookup, menu validation and refusal of absent/unknown/non-scalar values. |
| D11, identity and provenance | Faithful in semantics; format routing is incomplete until F3 is patched. | Config/run, sweep candidate, walk-forward, promotion and resume can all carry declaration hash plus resolved value while retaining the inner source hash. The mask is correctly excluded. Current separate format/version owners must all be named. |
| D12, counts and disclosure | Faithful. | Computing from compiled verdicts avoids dependence on availability-only diagnostic rows. Ticket evidence must verify the persisted counts against the verdicts for the executable run/fold range and across resume; the bound semantic is that the counts come from verdicts, not traces. |
| D13, invocation time only | Faithful. | Momento's second execution weekday remains an execution/order-policy case. Current fills are planned and applied in one pulse; there is no pending-fill state to preserve. Event-to-event stepping remains a later optimization under the pulse oracle. |

## 3. Findings And Exact Smallest Patches

### F1 - High - The parent session axis and week boundary are underspecified

**File/section:**
`rfc_strategy_schedule_decorator_v0_1_9_x_synthesis.md`, D2-D4.

`snapshot_sessions` contains open and closed rows, while executable pulses are
built from `status == "open"` rows. D3 currently says only "authoritative
expected session axis." If implemented over every table row, a weekend or
holiday inside the new month can prevent the first executable open session
from being recognized as `month_start`, and similarly prevent the last open
session from being `month_end`. The public `week_start` rule is also ambiguous
because the synthesis dropped seed v2's Monday definition.

**Exact smallest patch:** in D2 or the first paragraph of D3, define the parent
axis as the snapshot's declared rows with `status == "open"`, ordered by
`session_close`; say that predecessor and successor mean adjacent rows on that
open-session axis. Add to D3: "Week periods start on Monday; the rule is the
locale-independent integer-date partition used by seed v2, equivalent to
`(as.integer(session_date) - 4) %/% 7`." In D4, change "declared session" to
"declared open session" where it describes the one-pulse assertion.

This restores accepted seed-v2 input; it makes no new product choice.

### F2 - Medium - Required evidence does not detect several bound decisions

**File/section:**
`rfc_strategy_schedule_decorator_v0_1_9_x_synthesis.md`, Section 5.

The existing list detects the phase gate and core identity properties, but it
does not fail on an implementation that ignores accepted D9, mishandles the
parameter resolver, reports wrong counts, loses the schedule during trusted
recovery, or omits the bound explicit-date behavior. Its "history helper"
wording can also be read to forbid P1's required `history_reader$bars()` and
`history_reader$view()` work.

**Exact smallest patch:** add bullets requiring:

- a zero-decision flat run with no opening/carried positions to refuse before
  fold execution, and otherwise identical zero-decision runs with opening and
  carried positions to complete P1/P4/P5, report zero decisions and retain
  their holdings;
- an explicit date between open sessions to snap forward, two dates snapping
  to the same open session to collapse to one verdict, and dates on both sides
  of the bounded parent-axis range to refuse;
- absent, unknown and non-scalar schedule-parameter values to refuse before
  the fold, while two valid grid values produce their expected distinct
  verdicts and identities;
- stored decision/skip counts to equal the compiled verdict counts, including
  interrupted/resumed and zero-decision cases;
- trusted strategy recovery to reattach the verified schedule declaration,
  and a parallel sweep worker to retain and compile the same declaration; and
- current-only readers to refuse the superseded saved-sweep, walk-forward and
  promotion-context versions named by F3.

Replace "history helper" in the first regression bullet with "public
strategy-visible history helper installation or call" and explicitly permit
the P1 history reader work bound by D6.

### F3 - Medium - The stored-format consequence omits existing version owners

**File/section:**
`rfc_strategy_schedule_decorator_v0_1_9_x_synthesis.md`, Sections 4 and 7.

The experiment-store bump covers the new provenance/telemetry columns and
reason token, and the synthesis generically says candidate formats bump. That
is not complete enough for the current tree. Schedule identity will also enter
the saved-sweep record/provenance and reproduction key, the walk-forward
candidate payload, and promotion's versioned `source_sweep`/`identity_check`
record. Those have separate current format owners:
`ledgr_saved_sweep_schema_version`, sweep `provenance_version` and candidate
reproduction-key version, `ledgr_walk_forward_candidate_schema_version`, and
`ledgr_promotion_context_version`.

**Exact smallest patch:** add one paragraph to Section 4 naming those four
format families and requiring each version to bump when its payload gains
schedule identity/provenance, with current-only readers refusing the former
value. Add their exact new version numbers to Section 7's spec-cut choices.
Do not add compatibility readers or missing-schedule fallbacks.

### F4 - Low - Binding documentation consequences were dropped

**File/section:**
`rfc_strategy_schedule_decorator_v0_1_9_x_synthesis.md`, Section 4.

Seed v2 Section 8 made the decorator the taught scheduling idiom and named the
affected authoring, workflow, reproducibility and store documentation. The
synthesis binds the public surface and disclosure but lists only contract and
format consequences. Leaving documentation entirely implicit is not faithful
enough for ticket ownership, especially because existing examples teach the
manual guard that this surface replaces.

**Exact smallest patch:** add a "Documentation" paragraph to Section 4 that
binds the decorator as the taught scheduling idiom, replaces hand-rolled guards
in the affected executable articles when their owning ticket lands, documents
schedule identity/provenance/count fields, updates the reference index and
NEWS, and requires the changed vignettes to execute. Article allocation may
remain a Section 7 spec-cut choice.

## 4. Code-Claim Verification

The following claims were checked directly against `1cd4e0c9`:

- P1 reads the history packet/view, posts corporate actions, dispositions and
  terminal outcomes, values holdings and records equity at
  `R/fold-engine.R:272-628`.
- P2 builds frames/context and calls/validates the strategy at
  `R/fold-engine.R:630-985`; P3 plans targets at `:987-1223`.
- P4 calls `bind_boundary(pulse_idx + 1L, ...)` before applying the plan at
  `R/fold-engine.R:1244-1253`. It cannot be dropped on a successful scheduled
  skip.
- P5 reconciles against `pulse_plan$expected_final_cash`, writes the
  reconciliation row, persists carried state, increments `processed`, samples
  telemetry and checkpoints at `R/fold-engine.R:1349-1511`.
- Resume reads `MAX(ts_utc)` from `strategy_state` and selects the next pulse at
  `R/run-resume.R:19-67`. A per-processed-pulse state row is therefore the
  resume cursor even when the strategy state value is null.
- Current fills do not pend across pulses: P3 creates the plan and P4 books it
  in the same pulse. The scheduler evidence correctly substitutes corporate-
  action boundary and P1 posting witnesses for the response's obsolete
  pending-fill witness.
- Availability calendars filter to open rows and order by `session_close` at
  `R/availability-provider.R:381-404`; session facts refuse duplicate dates at
  `R/availability-facts.R:731-733`. Dense calendars at
  `R/run-snapshot.R:142-162` have no declared outer predecessor/successor.
- Function/signature gates are `is.function()` plus `(ctx, params)` in
  `R/experiment.R:464-485` and `R/strategy-provenance.R:1-18`. Source capture
  currently deparses the supplied function, registry identity uses body,
  formals and variable captures, and the signal wrapper has a special preflight
  bypass. D1/D11 correctly require schedule-aware stripping and separate
  declaration identity rather than a new LFB-035-style closure.
- Config hashes consume the config except the fixed exclusions in
  `R/config-hash.R:1-50`; schedule fields therefore enter run identity. Sweep
  and walk-forward currently carry only strategy hash plus parameter and other
  identities, so D11 requires explicit schedule fields and F3's version bumps.
- `scheduled_skip` is not merely display text. The availability reason table is
  closed for the current schema, and durable diagnostics store reason tokens;
  the synthesis correctly requires a contract and store-format change.

One independent read-only base-R probe was run from `C:/tmp` with R 4.6.1. A
function given class `c("ledgr_scheduled_strategy", "function")` and a
`ledgr_schedule` list attribute remained callable, satisfied `is.function()`,
kept formals `ctx, params`, and survived `serialize()`/`unserialize()`
identically. `deparse()` included a `structure(function(...), class = ...,
ledgr_schedule = ...)` wrapper, confirming that attribute-stripped source
capture is necessary. No probe file was created and no repository file was
modified by the probe.

## 5. Maintainer Decisions

Both accepted decisions are represented exactly.

1. Maintainer D1 is synthesis D3: a partial first period waits for a proved
   boundary; fold/window starts manufacture none; and the first parent-axis
   session is not promoted without a predecessor. Opening policy or an
   explicit-date rule owns immediate initialization.
2. Maintainer D2 is synthesis D9: zero decisions refuse only when the current
   run/fold has neither opening nor carried positions; position-carrying runs
   remain valid and disclose zero. The check occurs after opening/carry state
   is known, not as a blanket walk-forward preflight.

## 6. Ticket-Cut Readiness And Next Step

The inputs are adequate for ticket cutting after the four patches and
maintainer acceptance. Before those patches, D3 can be implemented incorrectly
against closed calendar rows, D9 lacks a registered witness, and the current
format/documentation owners can be missed.

**Exact next step:** patch the synthesis in place with F1-F4 and a revision
note, then perform a focused Type 1 confirmation that the literal patches were
applied. If that confirmation passes, the maintainer may accept the synthesis,
update the RFC pipeline/decisions bridge/macro-plan position, and cut the
implementation workstream. Do not reopen Type 2, add a spike, absorb LFB-035,
or update shipped contracts before acceptance.

## 7. Review Change Record

This review created exactly one file:
`inst/design/rfc/rfc_strategy_schedule_decorator_v0_1_9_x_final_review.md`.
It changed no code, contract, ticket, seed, synthesis, RFC index, macro plan,
horizon or roadmap file.
