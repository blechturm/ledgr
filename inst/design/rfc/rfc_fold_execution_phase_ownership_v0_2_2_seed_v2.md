# RFC Seed v2: Fold Execution Phases And State Ownership For v0.2.2

**Status:** Revised seed after Type 2 response; maintainer authority amendment
is required before synthesis.
**Date:** 2026-10-15.
**Author:** Codex, seed v1 author.
**Target:** a stable internal execution boundary for availability-history work
and the later compiled-execution-envelope RFC.
**Executable baseline:** `07f91bcfa9455d5eafa5ef4c1712f0ccd7b6fee3`.
**Response:** `rfc_fold_execution_phase_ownership_v0_2_2_response.md`.
**Budget:** within the 300-line seed limit.

## 1. Question And Revision

What semantic phases and ownership rules let ledgr extract the approximately
830-line pulse body of `ledgr_execute_fold()` without changing execution,
failure, persistence or callback behavior?

Seed v1's E plus P1-P5 order survives. Its ownership model does not. This
revision keeps pulse evidence alive through its last read, distinguishes
stateful services from fold state, puts strategy-state normalization back in
P5, gives stop control one owner, records the stale private fold return and
replaces the obsolete feature-table oracle with a public vector witness. No
new spike is needed.

## 2. Requested Authority Amendment

Cut 15 decision (11) binds eight phases. Two parts remain sound:

- public `ctx` and its frames are created and consumed locally with strategy
  execution; and
- canonical fills preserve lot transition, event write, accounting fact and
  cash/position mutation order.

The count and valuation placement must be superseded. Equity and valuation
marks are produced before the strategy (`R/fold-engine.R:769-795`), not in a
last valuation phase. A literal eight-phase extraction would reorder facts.

The requested amendment replaces the eight labels with E plus P1-P5 below and
requires LDG-3052 scope, LDG-3054 scope/acceptance and every eight-phase
detector to follow the accepted synthesis. The maintainer must record this
amendment before synthesis; this non-binding seed does not edit tickets.

## 3. Executable Baseline

Durable execution and sweep call one fold core with persistent and memory
handlers (`R/backtest-runner.R:1250-1263`; `R/sweep.R:1510-1534`). The fold
owns validation, prepared inputs, strategy and economics. Handlers own
transaction and materialization mechanics, but today also recompute fill
deltas for event rows.

The current pulse order is observable through callbacks, classed failures,
events, facts, diagnostics, state, interruption and rollback. Extraction must
preserve immediate-parent output and failure order, not merely final equity.

## 4. Proposed Semantic Taxonomy

The count follows semantic and atomic boundaries. It is private, non-identical
and not an identity input.

### E. Fold envelope

Validate and prepare the fold; initialize handler and stateful services; scope
and restore ambient RNG when a seed is supplied; run the handler transaction;
apply typed stage results; drive pulses; finalize evidence; map exceptions to
the existing diagnostic; and return the fold result. Unseeded strategies may
advance ambient RNG. Caller-owned outer RNG scopes remain unchanged.

### P1. Observe and settle

Select current inputs; post due corporate actions; observe availability and
valuation; apply supported dispositions and terminal outcomes; re-observe
after any position-changing settlement; update freeze/decision-axis state;
value pulse-start holdings; and conditionally emit equity evidence.

P1 stays broad because dispositions consume current marks and may require the
decision view to be derived again. Preserve three distinct write orders:

1. corporate-action cash appends its event, then mutates cash;
2. terminal disposition mutates a candidate state, appends, then installs it;
3. canonical fills retain the P4 order below.

P1 returns a typed decision packet containing axis identities and indices,
positions/equity, eligibility and valuation planes, and locators into prepared
bars/features. It returns no public context or frame. The packet remains live
until P5 because reconciliation reads its marks, source rows, membership and
context axis.

### P2. Decide

Reset pulse notes; materialize `ledgr_pulse_context` locally; invoke strategy;
wrap failures with the same context; validate targets; apply availability
target rules and risk; and return pre-risk targets, post-risk targets and the
raw user state update. `ctx`, `bars`, `feature_table` and `features_wide` die
when P2 returns. P2 does not normalize the state update.

### P3. Plan execution

Compute deltas; resolve mode-specific timing and costs; validate event kinds;
apply availability affordability; and return an immutable ordered plan plus
diagnostic segments. It mutates no economic state or handler buffer.

Dense and availability planning remain distinct. Dense keeps next-bar timing
and the final-bar warning (`R/fold-engine.R:114-200`); availability keeps its
declared opening, membership input and no-fill diagnostics.

### P4. Apply economic events atomically

Bind the next corporate-action boundary, then apply the ordered plan. For each
canonical fill preserve:

1. lot transition and installation;
2. handler fill-event write and event-sequence advance;
3. handler accounting-fact record when present; and
4. position and cash mutation.

The compiled batch keeps its separately accepted FILL-only ordering inside its
closed envelope. Unsupported kinds refuse before mutation. Extraction does
not reconcile that order with the canonical loop.

Handlers currently recompute cash/position deltas and the memory handler splits
fee legs. The first extraction preserves those byte-identical calculations and
routes their consolidation to output-handler/compiled-envelope work. It does
not falsely call current handlers economics-free.

### P5. Commit the pulse

Flush staged fills; reconcile availability cash and exposure using the P1
packet and both target vectors; normalize the raw strategy state update;
serialize and write or buffer strategy state; increment ordinary processed
state; record telemetry; flush due checkpoints; and apply cooperative
max-pulse/interrupt controls. Availability completion and final diagnostic
drain remain E finalization.

Only the cooperative option is pulse-granular. A signal interrupt can arrive
inside any stage; durable execution rolls back the invocation and rethrows,
while the memory handler has no transaction rollback.

## 5. Three State Classes

### Fold-owned mutable state

One authoritative owner holds cash, positions, lots, strategy state, event
sequence, control status, `equity_facts`, last-valued/executed times and the
current stop result. A fixed-name environment is permissible; no second
carrier or copied mutable aggregate is.

### Declared stateful run services

A service closure is allowed only when its mutating methods and calling stages
are enumerated. The initial census must include:

| Service | Mutating or state-sensitive calls | Owner |
| --- | --- | --- |
| valuation state | `advance` | P1 |
| availability provider | decision view; execution view/cursors | P1; P3 |
| corporate-action plan | `post`, `post_disposition`, quantity check; `bind_boundary` | P1; E/P4 |
| pulse notes/fast context | reset, helper writes, pulse index/read | P2 |
| diagnostic writer | stage segment append; drain | P1-P5; E |
| output handler | stage/write/flush/state/checkpoint/finalize | P1/P4/P5; E |

A call-site detector rejects a mutator from an undeclared stage. Stateful
services are not described as immutable inputs or hidden inside the carrier.

### Short-lived typed results

P1's packet lives through P5. P2's two target vectors live through P5 and its
raw state update through normalization. P3's plan is immutable through P4 and
its diagnostics through P5. Per-fill locals die after the final mutation.
Public frames never cross P2.

## 6. Stop And Return Semantics

P1, P2 or P3 may return one typed stop result: status, reason, affected
exposure, diagnostic segments and a declared processed-count effect. E alone
applies it, flushes the existing diagnostic boundary and breaks. Preserve the
current asymmetry: risk-mark and affordability stops count the pulse; P1
settlement/valuation/terminal stops do not.

The current inner `run_loop()` mutates local bindings, while the outer return
exposes the initial `state`, `state_prev` and `next_event_seq`. The runner
assigns them and never reads them; sweep ignores them. This revision proposes
deleting those three dead private return fields and their dead assignments,
not copying live scale-growing state merely to make an unused return truthful.
That deletion is an authorized internal cleanup only if synthesis accepts it;
it receives its own failure-sensitive consumer census.

## 7. Mode, History And Compilation Boundaries

Availability owns dynamic axes, valuation, terminal/freeze behavior,
affordability and reconciliation. Dense owns its fixed axis, fast context and
final-bar warning. Extraction adds no mode, branch or unification.

P1 is the sole reader of history-derived values and P2 the sole adapter of
those values to public context. History may supply prepared typed values or a
declared incremental stateful service; this RFC chooses neither.

P4 is a demonstrated candidate seam for compiled execution. The later
compiled-execution-envelope RFC may retain P4 alone or widen the seam to P3
plus P4. Canonical R remains the normative oracle. This RFC chooses no compiled
default, supported envelope or fallback.

## 8. Schema-120 Parity Oracle

Schema 120 deleted feature persistence. One obsolete query executed under two
tags now aborts the old 51-family recorder. Repair is a mechanical prerequisite
with this oracle:

1. the repaired recorder's family set equals the last accepted record's set
   minus `momentum_features` and `equal_weight_features` plus the new
   feature-hash family; byte differences against that pre-schema-120 record
   are enumerated and explained by the schema-120 and identity-rule-3
   transition, since `check_record.R` reports the added family as missing on
   the historical side;
2. a declared per-phase manifest makes the recorder fail when any required
   current family is absent; the derived count is reporting only;
3. a momentum-strategy recording wrapper hashes `ctx$vec$feature(id)` over
   `ctx$universe` at each pulse, preserving a feature-value oracle without the
   deleted table or `ctx$feature_table`; and
4. schema catalogue tests, not an empty compatibility table, prove the old
   persistence surface is absent.

The accepted schema-120 record becomes the parent baseline. Each extraction
commit compares the full manifest to its immediate parent.

## 9. Required Evidence

1. Inventory every read, write, service call and observable effect under E or
   exactly one P stage, including both stale/live state bindings.
2. Detect a second carrier, undeclared service mutator, retained frame, dead
   scratch read or duplicated inline phase body.
3. Compare context identity, errors and callback side effects in dense,
   availability and empty-axis pulses.
4. Fault-inject a delegating real handler at the Nth fill write and accounting
   fact in multi-fill pulses for both modes/handlers; also fail lot application
   before any write. Durable execution rolls back; memory produces no partial
   summary.
5. Prove uninterrupted equals interrupted/resumed and seeded caller RNG is
   restored on success, strategy error and interruption.
6. Pass the repaired manifest, focused entry-point/promotion/walk-forward
   witnesses and the existing paired clocks at each immediate-parent commit.

No new spike is required. Stage-call overhead is already governed by the 1.05
paired-clock gates.

## 10. Exclusions And Implementation Choices

This RFC does not implement phases, repair the recorder, unify modes, design
public history, retire context frames, optimize the fold, add/default compiled
execution, change persistence/identity or fix unrelated behavior.

Environment versus list-and-return, top-level functions versus nested
closures, frame-slicing details inside P2, detector mechanics, telemetry
sampling, diagnostic segment signatures and buffer chunk sizes remain
implementation choices subject to the accepted ownership rules.

## 11. Sequence

1. Maintainer accepts or changes the Section 2 authority amendment.
2. A different author writes synthesis against seed v2 and the response.
3. Type 1 final review verifies citations, decisions and routing.
4. Acceptance amends decision (11), LDG-3052-LDG-3054 and the RFC pipeline.
5. Repair the schema-120 oracle, then begin extraction.

This seed authorizes no production, recorder or ticket change.

## Revision Note

- 2026-10-15 - Two in-place final-review bug fixes, as `../rfc_cycle.md`
  permits: Section 4 P5 now increments ordinary processed state before
  telemetry and checkpoints, matching `R/fold-engine.R:1322-1347` (final
  review F8); Section 8 item 1 no longer claims a two-family-only comparison
  (final review F2). Patched by the synthesis author; the seed's architectural
  intent is unchanged. The Section 11 sequence is superseded by the synthesis.
- 2026-10-15 - Supersession pointers, not patches (focused re-review finding
  4): Section 6's deletion of the three fold return fields is superseded by
  synthesis Section 5.5 (live return, the one permitted repair under decision
  (7)); Section 9 item 4's accounting-fact injection for both handlers is
  superseded by synthesis Section 7 witness 4 (memory handler only, the only
  handler with the method). The seed text stands as the historical proposal.
