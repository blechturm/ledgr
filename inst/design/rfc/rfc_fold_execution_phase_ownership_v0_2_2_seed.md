# RFC Seed: Fold Execution Phases And State Ownership For v0.2.2

**Status:** Seed v1; non-binding. Input to an independent adversarial Type 2
response. It authorizes no implementation or ticket change.
**Date:** 2026-10-15.
**Author:** Codex. Per `../rfc_cycle.md`, the Type 2 response needs a different
author.
**Target:** a stable internal execution boundary for availability-history work
and the later compiled-execution-envelope RFC.
**Executable baseline:** accepted product commit
`07f91bcfa9455d5eafa5ef4c1712f0ccd7b6fee3` (schema 120, identity rule 3).
Commit `fbd05c56` changes planning authority only, not that executable baseline.
**Authority:** Execution, Availability, Strategy, Context and Result contracts;
Cut 15 and WS38 authority; the historical phase amendment; the accepted
accounting-core synthesis; and the compiled-availability accounting spike.
**Budget:** within the 300-line seed limit in `../spike_protocol.md` section 4.

## 1. Question And Necessity

What semantic phase and ownership contract should replace the approximately
830-line pulse body of `ledgr_execute_fold()` without changing behavior, and
which seam should later history preparation and compiled execution consume?

This needs an RFC, not a literal extraction. Two proposed splits conflict with
the executable contract:

- the public pulse context contains data frames, so a separate context builder
  cannot pass `ctx` while claiming typed-only phase boundaries
  (`R/fold-engine.R:803-897`; `../contracts.md:1516-1546`); and
- canonical accounting and event emission are interleaved per fill, so separate
  phases would reorder side effects and failures (`R/fold-engine.R:1183-1235`).

The 2026-10-15 clarification made the eight implementation labels coherent by
putting context materialization in strategy execution and the full fill
sequence in atomic application. This seed instead asks which boundaries are
semantic; eight is not a design objective.

## 2. Executable Baseline

There is one fold core and two production callers. Durable execution calls it
with the persistent handler (`R/backtest-runner.R:1250-1263`); sweep calls it
with the memory handler (`R/sweep.R:1510-1534`). This is the one-engine contract
(`../contracts.md:91-125`).

The fold owns run validation, seed scope and preparation
(`R/fold-engine.R:236-450`); pulse economics, strategy and control
(`R/fold-engine.R:527-1356`); and handler
transaction use, exception diagnostic, completion and return (`:1359-1425`).
Handlers own materialization, not economics. Persistent execution wraps the
loop in one transaction and rolls back before rethrowing interruption
(`R/backtest-runner.R:273-284`); both handlers stage a pulse before flush
(`R/backtest-runner.R:431-470`; `R/sweep.R:1967-2048`).

## 3. Proposed Semantic Taxonomy

Bind one fold envelope and five pulse stages. The count follows atomicity and
observable boundaries; it is neither public API nor an identity input.

### E. Fold envelope

Validate the execution specification, prepare immutable run-scoped inputs,
scope and restore caller RNG, initialize the handler, run its transaction,
drive pulses, finalize evidence, convert exceptions to the existing diagnostic,
and return the fold result. A supplied seed is installed once and prior
`.Random.seed` is restored on every exit (`R/fold-engine.R:269-285`). Phases do
not own or restore ambient RNG.

### P1. Observe and settle before decision

Select current inputs; apply due corporate actions and terminal dispositions;
resolve availability and valuation; update freezes and decision-axis state;
value pulse-start holdings; and emit the current equity fact. These operations
jointly establish the economic, point-in-time state visible to user code.
P1 may complete the run before user code only under today's terminal rules.

P1 returns a typed decision packet: pulse/time and decision-axis indices and
IDs, pulse-start positions, cash/equity, eligibility and valuation planes, and
locators into run-scoped bars/features. It returns no public context or frame.

### P2. Decide

Materialize `ledgr_pulse_context` locally, invoke strategy, wrap errors with the
same context, normalize and validate targets, apply availability target rules
and risk, and return typed targets plus a state update. `ctx`, `bars`,
`feature_table` and `features_wide` die when P2 returns. This preserves today's
public context pending its separately routed retirement RFC without putting a
frame in fold-owned state.

### P3. Plan execution

Compute deltas, resolve mode-specific timing and costs, validate economic-event
kinds, enforce availability affordability, and return an immutable ordered plan
plus diagnostic segments. Do not mutate cash, positions, lots, event sequence
or handler buffers.

Dense and availability remain distinct implementations inside P3. Dense keeps
next-bar timing and its final-bar warning (`R/fold-engine.R:112-180`);
availability keeps the next declared opening and no-fill diagnostics
(`R/availability-economics.R:388-475`; `../contracts.md:774-786`).

### P4. Apply economic events atomically

Bind the next corporate-action boundary, then apply the ordered plan. For each
canonical fill preserve this exact executable sequence:

1. call `ledgr_lot_apply_fill()` and install its lot state;
2. call `output_handler$write_fill_events()` and advance event sequence;
3. call handler-local `record_accounting_fact()` when present; then
4. mutate position and cash.

Do not split, reorder or vectorize that failure order
(`R/fold-engine.R:1147-1235`). The compiled spot-FIFO batch remains a supported
P4 implementation only for its closed envelope
(`R/fold-engine.R:1157-1181`); it authorizes
no second pulse engine or unsupported-kind fallback. Pre-decision dispositions
remain in P1 under their own atomic rule (`../contracts.md:250-271`).

### P5. Commit the pulse

Flush staged fills; perform availability post-fill reconciliation; serialize
strategy state; record telemetry; flush checkpoints; and then evaluate
max-pulse and explicit interruption controls (`R/fold-engine.R:1238-1362`).
Interruption remains observable only after a complete pulse. Availability
completion and final diagnostic drain remain E finalization
(`R/fold-engine.R:1364-1382`).

## 4. Ownership And Liveness

Bind one authoritative fold owner, not one object containing every dependency
and temporary value.

| Value family | Owner/lifetime | Boundary rule |
| --- | --- | --- |
| validated inputs, prepared matrices/indexes, provider, policies, strategy and services | E, read-only for fold | stable references or typed locators; never mutated by phases |
| cash, positions, lots, strategy state, event sequence and control state | fold owner, until return | one authoritative slot; mutation only in its owning stage |
| decision packet | P1 through P2 | typed primitives and locators; release after P2 |
| public `ctx` and frames | P2 for one invocation/error wrapper | never stored in fold state or returned across a phase boundary |
| targets and state update | P2 through P5 | targets feed P3; state update feeds P5 |
| plan and diagnostics | P3 through P5 | immutable after P3; handler rows are not the plan |
| per-fill transition locals | P4 for one fill | die after fact recording and state mutation |
| staged rows/materialized results | handler until flush/finalization | fold requests writes; never inspects or reinterprets storage |

A fixed-slot classed carrier is permissible only if it retains no dead pulse
values, copies no scale-growing vectors on scalar writes, and hides no second
state authority. The interface distinguishes fold-owned mutable state,
immutable services/prepared inputs, and short-lived typed results; calling all
three one carrier would obscure rather than enforce ownership.

## 5. Mode And Control Ownership

The shared loop has deliberate internal branches. Availability owns provider
decisions, dynamic axes, valuation, terminal/freeze behavior, affordability and
reconciliation; dense owns its fixed axis, fast context and final-bar warning.
Both reach the same strategy, target/risk, planning, atomic and handler
contracts. Cut 15 freezes dense while history targets availability
(`../ledgr_v0_2_2_spec_packet/macro_plan.md:651-661`): add no dense branch,
weaken no availability rule,
and create no history-specific loop or strategy boundary. Unification remains
a later RFC/cut.

- Handlers continue to own transaction mechanics; phases open no transaction.
- Resume reconstruction remains caller/setup work. The fold receives its start
  and reconstructed state and binds actions before the first resumed pulse
  (`R/fold-engine.R:491-525`; `R/backtest-runner.R:1225-1247`).
- Max-pulse/interruption checks remain after P5. Persistent interruption keeps
  rollback-and-rethrow behavior.
- RNG scope remains E-owned; `pulse_seed` is a deterministic P2 context field,
  not a hidden phase stream.
- Economics remain fold-owned. Handlers may stage, materialize, patch the fact
  for their just-written fill and summarize, but not recompute economics
  (`../contracts.md:255-260`).

## 6. Stable Downstream Seams

History preparation supplies P1 cutoff-causal typed primitives and locators.
P1 selects the decision slice; only P2 adapts it to public context. History
representation therefore stays outside strategy and accounting interfaces.

Compiled execution targets P4's closed ordered plan plus authoritative economic
state. It declares supported event kinds, fails before mutation on an
unsupported kind, and returns the state/event facts the handler consumes.
Compilation of P1-P3 or P5 is not implied. Canonical R remains the normative
oracle (`../contracts.md:273-287`).

## 7. Schema-120 Parity Oracle

Schema 120 deleted durable feature persistence and the `features` table. The
old scale recorder still queries it twice
(`dev/bench/v0_2_2_real_data_scale/run_record.R:136-150`), so the historical
"51-family ladder" aborts before baseline evidence exists.

Before implementation, a mechanical prerequisite must:

- remove exactly those two deleted-feature queries and families;
- preserve every surviving economic, state, diagnostic, entry-point and
  identity family;
- derive the current count from files compared, not preserve 51 aesthetically;
- run the per-family perturbation self-test; and
- use schema catalogue tests for absence of `features`, without an empty
  compatibility table or fake per-run family.

This is evidence tooling, not product compatibility, and this seed does not
perform it. The repaired accepted-tree record becomes the baseline. Each later
implementation compares its full current family set with its immediate parent;
focused witnesses cover context and condition identity, callback order,
rollback, interruption/resume, caller RNG, strategy state and both handlers.

## 8. Required Evidence Before Extraction

1. Map every pulse read, write and side effect to E or exactly one P stage.
2. Reject retained frames, second state authority, dead scratch reads and a
   duplicated inline phase body structurally.
3. Compare exact context shape/helpers/errors/side effects for dense,
   availability and empty-axis pulses.
4. Fault-inject around each P4 step to prove order under the transaction.
5. Prove equal semantic streams from durable and memory handlers; compare
   compiled accounting only on its declared intersection.
6. Prove uninterrupted equals interrupted/resumed and caller RNG restoration
   on success, strategy error and interruption.
7. Pass the repaired current schema-120 ladder plus focused entry-point,
   promotion and walk-forward witnesses before removing inline code.
8. Use paired clocks/allocation profiles as gates, not phase definitions.

## 9. Exclusions And Rejected Directions

This RFC does not implement phases, repair the recorder, change tickets, unify
execution modes, add/default a compiled kernel, design public history, optimize
the fold, retire context frames, change handlers/schema/identity, or repair a
behavior defect. Route defects to their owner with a vendor-neutral reproducer
where practical.

Rejected: eight phases because eight labels exist; one mutable bag; passing
`ctx` between phases; separating accounting from event emission; unifying modes
during extraction; retaining 51 with placeholders; and mixing optimization or
defect repair into movement. Each either contradicts current behavior or
destroys attribution against the immediate-parent oracle.

## 10. Questions For The Type 2 Response

1. Is P1 too broad, or does its breadth preserve one observation boundary?
2. Should E expose services as arguments, fixed fields or owned closures, and
   which makes hidden mutation and scale-growing copies easiest to detect?
3. Is the P3 plan closed enough for canonical and compiled P4 while actions
   and dispositions remain pre-decision?
4. Which fault injections prove atomicity without contracting private handler
   layout?
5. Would a new pulse-feature parity family improperly couple this work to the
   separately routed context-inspection design?
6. Is any observable boundary missing, or would another split be aesthetic?

## 11. Next Step

A different author writes an adversarial Type 2 response challenging the
framing, taxonomy, ownership, handler boundary, downstream seams and schema-120
oracle. No implementation, recorder repair, ticket cut or synthesis begins.
