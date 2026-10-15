# Type 2 Response: Fold Execution Phases And State Ownership

**Status:** REVISE_SEED. No spike is required.
**Date:** 2026-10-15.
**Author:** Claude, independent response-stage reviewer; supplied by the
maintainer for the RFC record.
**Reviewed artifact:** `rfc_fold_execution_phase_ownership_v0_2_2_seed.md`.
**Executable baseline:** `07f91bcfa9455d5eafa5ef4c1712f0ccd7b6fee3`.

## 1. Disposition

The five-stage taxonomy is closer to executable order than the eight labels it
replaces. The seed's ordering claims hold, but its ownership model does not.
It shortens the decision packet too aggressively, calls mutable services
read-only, omits stale fold-return fields and silently contradicts Cut 15
decision (11). These are design defects that seed v2 can correct from current
code. No empirical unknown requires a spike.

## 2. Required Revisions

### R1. Name the authority supersession

Cut 15 decision (11), LDG-3052 and LDG-3054 bind eight phases. The seed is
right to reject that count, but it cannot supersede accepted authority
silently. The accepted clarification's local-context rule and canonical
per-fill order stand. The count and the placement of valuation do not: equity
and valuation marks are produced before strategy execution, so a literal
last valuation phase would reorder the equity fact. The maintainer must record
the amendment before synthesis and the later ticket rewrite must name every
affected field.

### R2. Correct pulse-value liveness

The decision packet lives through the pulse. `valuation$source_row`,
`valuation$mark`, `availability_view$member` and `context_ids` are read after
P2. P2 must return both pre-risk and post-risk targets and the raw strategy
state update. P5 owns state-update normalization and serialization because
normalization currently follows fills and reconciliation.

### R3. Admit stateful run services

Valuation state, the corporate-action plan, the prepared availability
provider, the diagnostic writer, fast-context feature state and pulse notes
all mutate. They are neither immutable services nor the main fold carrier.
Seed v2 needs a third state class: a named stateful service whose mutating
methods and permitted calling stages are declared and checked by a call-site
census.

### R4. Resolve the stale fold return

Assignments inside `run_loop()` are local, while the outer function returns
the pre-loop `state`, `state_prev_mem` and `event_seq`. Durable execution
assigns those values and never reads them; sweep reads none. Seed v2 must name
the defect and choose either to drop the three dead return fields or return
live values behind a witness. It cannot call either change a literal move.

### R5. Give stop control one owner

P1, P2 and P3 can stop a run, while P5 owns ordinary processed/full-run
control. Define one typed stop result that a single orchestrator applies.
Preserve today's asymmetry: P2 risk-mark and P3 affordability stops increment
`processed`; the P1 stops do not.

### R6. Correct the handler claim

Handlers currently recompute fill cash and position deltas, and the memory
handler splits fee legs. Seed v2 must name that duplicate. It may propose one
P4 computation consumed by row builders, or preserve the duplicate during
extraction and route it as debt. It may not claim handlers are already free of
economic arithmetic.

### R7. Narrow downstream placement

History may arrive as prepared values or an incremental service. Bind only
that P1 is its sole reader and P2 its sole public-context adapter. P4 is a
candidate compiled seam proven by LDG-2992; the compiled-envelope RFC may
widen that seam to P3 plus P4.

### R8. State why P1 remains broad

Dispositions and terminals consume valuation marks and can force the decision
view to be observed again. Splitting settlement from observation would either
repeat or conceal that dependency. P1 also contains three existing write
orders which must remain distinct: corporate-action cash appends then mutates;
terminal disposition mutates a candidate copy then appends and installs; fills
use the canonical lot/write/fact/mutate order.

### R9. Put state normalization in P5

`ledgr_fold_asset_state_normalize(result$state_update)` runs after fills and
reconciliation and can abort with `ledgr_invalid_strategy_state`. Moving it to
P2 changes observable failure order. P2 returns the raw update; P5 normalizes,
serializes and records it.

### R10. Qualify mode and handler effects

Only availability appends the fold-owned `equity_facts` list. A handler may
also receive `record_equity_fact`; durable dense execution does not and later
replays equity. Strategy state is written live or buffered in memory. Add
`equity_facts` and these conditional effects to the ownership model.

### R11. Qualify interruption

Only the cooperative option is checked after a complete pulse. A signal
interrupt may arrive anywhere; durable execution rolls back the invocation,
whereas the memory handler has no transaction rollback.

### R12. Qualify RNG restoration

The fold restores caller RNG when a seed is supplied. Unseeded strategies may
advance ambient RNG. Durable and sweep callers add outer scopes; the seed must
not claim unconditional fold restoration.

### R13. Repair the schema-120 oracle precisely

One query under two run tags produces `momentum_features` and
`equal_weight_features`. The repaired recorder compared with the old record
must show exactly those two families missing and no others. A declared
per-phase family manifest, not a derived count alone, detects accidental
loss. Preserve a feature-value oracle through a recording wrapper which hashes
`ctx$vec$feature(id)` over `ctx$universe` per pulse; do not restore the deleted
table or couple the oracle to `ctx$feature_table`.

## 3. Verified Source Claims

The response confirmed one fold core and two callers; pre-strategy corporate
actions and terminal resolution; context, callback, target and risk order;
separate dense and availability planners; canonical per-fill
lot/write/fact/mutate order; flush, reconciliation, state, telemetry,
checkpoint and control order; durable transaction rollback; caller-prepared
resume state; RNG-independent `pulse_seed`; and the FILL-only compiled batch
boundary. The dense-planner citation should be `R/fold-engine.R:114-200`.

The compiled batch mutates before its batch append inside its declared
envelope. The canonical per-fill ordering claim therefore applies only to the
canonical R fill loop.

## 4. Decisions Seed v2 Must Propose

1. The requested decision (11) supersession and ticket rewrite.
2. E plus P1-P5, with P1 re-observation and preserved write orders.
3. Correct liveness and P5 state-update normalization.
4. Fold-owned state, declared stateful services and short-lived results.
5. One typed stop result and preserved processed-count asymmetry.
6. A disposition for the stale private return fields.
7. A disposition for handler delta recomputation.
8. The current schema-120 oracle and feature-vector witness.
9. Narrow history and compiled seams.

Environment versus list-and-return, function-per-stage versus nested closures,
frame-slicing location inside P2, detector mechanics, telemetry placement,
segment helper signatures and buffer chunk sizes remain implementation choices.

## 5. Required Evidence

Fault injection around P4 should use a delegating real handler which throws on
the Nth fill write or accounting-fact call in a multi-fill pulse, for both
handlers and both modes. Durable execution must roll back the invocation and
record the existing exception diagnostic; the memory candidate must fail
without a partial summary. An invalid fill must fail in lot application before
any write. Existing rollback tests are the base.

No new spike is required. Stage-call overhead remains covered by the existing
paired-clock gates. Codex should write seed v2; the maintainer must record the
decision (11) amendment before synthesis opens.
