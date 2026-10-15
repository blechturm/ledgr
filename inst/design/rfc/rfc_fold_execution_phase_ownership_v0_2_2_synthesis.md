# Synthesis: Fold Execution Phases And State Ownership For v0.2.2

**Status:** Accepted by the maintainer on 2026-10-15 after the focused Type 1
confirmation PASS (Codex, 2026-10-15), explicitly including the Section 5.5
live-return exception to decision (7). Sections 3 to 8 and 11 bind; the
acceptance commit applies Section 3 to Cut 15 authority and rewrites the
Workstream 38 tickets. Acceptance claims no implementation.
**Author/date:** Claude, 2026-10-15. Author of the Type 2 response; not
author of either seed. Final review belongs to an author who wrote neither
seed v2 nor this synthesis.
**Mode:** Decision synthesis, on the maintainer's instruction of 2026-10-15
that synthesis precedes any authority amendment. Seed v2 Section 11 asked for
a maintainer decision first; `../rfc_cycle.md` reserves that stage for
product-level binary choices and none surfaces here, so the stage is skipped
and the authority change is bound in Section 3 and applied at acceptance.
**Inputs:** seed v2, the Type 2 response, seed v1, Cut 15 and Workstream 38 in
`../ledgr_v0_2_2_spec_packet/tickets.yml`, the execution-core consolidation
section of the macro plan, the Execution, Availability, Strategy, Context and
Result contracts, the accounting-core synthesis, the compiled-availability
accounting closeout, and the code at the executable baseline.
**Executable baseline:** `07f91bcfa9455d5eafa5ef4c1712f0ccd7b6fee3`. Line
anchors below are read from that tree in the `ws38` worktree.

## 1. Corrections The Synthesis Author Owes

1. **The response artifact is a paraphrase.** The seed author transcribed the
   Type 2 review into `rfc_fold_execution_phase_ownership_v0_2_2_response.md`
   and kept one code anchor of about forty. The substance is faithful; the
   audit trail is not. This synthesis restores the anchors for every claim it
   binds. The maintainer may replace the artifact body with the verbatim
   review; nothing below depends on that choice.
2. **Seed v2's service census is incomplete.** It omits the telemetry
   environment, written in P5 and totaled in E, and the scalar-access tracker
   built at `R/fold-engine.R:443-447` and consumed by P2 helpers. Section 5.2
   lists both.
3. **Seed v2's sequence contradicts the cycle.** Its Section 11 step 1 is
   replaced by this synthesis and Section 13.
4. **The response's dense-planner citation** should read
   `R/fold-engine.R:114-200`; seed v2 already corrected it.
5. **Four further departures from seed v2**, three named by final review F8
   and one by the focused re-review: stages as top-level functions, which
   seed v2 Section 10 left open and LDG-3053 already requires; permission to
   move telemetry sample points (Section 7 witness 7); the exclusion of R6 on
   the project's dependency stance, which the RFC inputs did not discuss; and
   the Section 4 rule that the stage count may change only by RFC, where seed
   v2 Section 4 said only that the count is private and not an identity
   input. Each is a synthesis choice open to challenge at acceptance.
6. **Seed v2's P5 order** put the ordinary `processed` increment after
   telemetry and checkpoint work; the code increments first
   (`R/fold-engine.R:1322`, `:1324`, `:1341`). Seed v2 is patched in place
   with a revision note, as is its Section 8 oracle (final review F2).
7. **Two seed v2 provisions are superseded, not patched.** Its Section 6
   proposes deleting the three fold return fields; Section 5.5 binds a live
   return instead. Its Section 9 item 4 injects accounting-fact failures for
   both handlers; Section 7 witness 4 limits that to the memory handler, the
   only one with the method. The seed text stands as the historical proposal
   and its revision note points here. Section 13 reads consistency against
   this list.

## 2. Decision

Accept seed v2's direction: one fold envelope and five pulse stages, with the
ownership model of its Sections 5 and 6, the oracle of its Section 8, and the
evidence of its Section 9. No third seed. No spike. The extraction remains a
pure refactor under Cut 15 decision (7); this synthesis names the two places
where "pure" needs a stated decision (Sections 5.5 and 5.6) and decides them.

One choice goes beyond seed v2, which left it open: the fold-owned mutable
state is one environment with a fixed, locked name set (Section 5.1). Grounds:
a locked environment fixes the binding-name set structurally, and the
constructor LDG-3052 already requires validates the types; the carrier reaches
every stage by reference, so no stage passes or returns it by value and no
stage needs a write-back binding; and the stale return in Section 5.5 arose
from a loop-local binding shadowing an outer one, a shape a single shared
environment cannot reproduce. The environment guarantees nothing about vector
copies. Whether a write copies depends on the write form and on sharing, not
on the carrier kind: on R 4.6.1, `tracemem` shows `e$v[i] <- x` and
`e[["v"]][i] <- x` copying an unshared vector, `v[i] <<- x` from a closure
enclosed by the environment writing in place, every form copying once another
binding holds the vector, and `evalq(v[i] <- x, e)` refusing on a locked
environment because complex assignment needs a `*tmp*` binding. The Section 7
detectors and clocks measure the write form the implementation chooses. The
lock does not by itself prevent a second carrier; the detectors carry that
obligation. R6 is excluded by the project's dependency stance (functions, not
R6); the RFC inputs did not discuss it, so it is recorded as a synthesis
choice.

## 3. Supersession Of Cut 15 Decision (11)

Decision (11) in the Cut 15 `decisions` field binds eight phases ending in a
"valuation/state update" phase. Equity and valuation marks are produced before
the strategy call (`R/fold-engine.R:769`, `:780`, `:789`), so an extraction
that followed the eight labels in order would move `record_equity_fact` after
fill application and change every memory-handler equity fact and every
availability `equity_facts` entry. The count and that placement are
superseded. Two rules in decision (11) stand: public `ctx` and its frames are
created and consumed inside the decision stage, and canonical fills keep the
order lot transition, event write, accounting fact, cash/position mutation.

| Target artifact | Addressed section | Disposition | Replacement |
| --- | --- | --- | --- |
| `tickets.yml` Cut 15 `decisions` (11) | eight-phase list; final valuation/state phase | superseded in part | Section 4; retained rules in 4.3 and 4.5 |
| `tickets.yml` Cut 15 `decisions` (7) | pure refactor; fixes no defect | amended by one named exception | retained for every other defect (Section 5.6); the Section 5.5 live return is the single permitted repair, accepted explicitly by the maintainer |
| `tickets[id=LDG-3052].title` | "typed fold-state and phase contract" | unchanged | generic wording |
| `tickets[id=LDG-3052].scope`, `.acceptance` | eight phase names; carrier; detectors | amended | Sections 4, 5, 7, 8 |
| `tickets[id=LDG-3053].title` | "input, decision, context and strategy phases" | amended | Sections 4.2, 4.3 |
| `tickets[id=LDG-3053].scope`, `.acceptance` | four phase names as top-level functions | amended | Sections 4.2, 4.3, 8 |
| `tickets[id=LDG-3054].title` | "fill, accounting, event and valuation phases" | amended | Sections 4.4 to 4.6 |
| `tickets[id=LDG-3054].scope`, `.acceptance` | "names the eight phases in order"; "do not ... fix a routed defect" | amended | Sections 4.4 to 4.6, 8; Section 5.5 live return named as the one permitted repair |
| `workstreams[id=38].review.reason` | phase assignments | amended | Section 4 |
| `macro_plan_history.md` amendment 2026-10-14 (2) | fold phase extraction | unchanged | historical record |
| `contracts.md` Fold Core And Output Handlers | fold core and handler roles | unchanged | retained address; no shipped rule changes |
| `rfc/README.md` pipeline row | Active | amended at acceptance | Section 11 obligations |
| `decisions.md` | none | no row | no contract group changes |

At acceptance the Cut 15 `decisions` field receives a dated amendment naming
this section for decision (11) and the Section 5.5 exception for decision (7);
the historical text of both decisions is preserved, not edited.
The ticket fields are rewritten by the maintainer in the same acceptance
commit. Acceptance claims no implementation.

## 4. Bound Architecture

The count is private, not an identity input, and may change only by RFC.
Every stage is one top-level function with one production caller; seed v2
left top-level versus nested open, and LDG-3053 already requires top-level
phase functions, so this is a disclosed synthesis choice. Stage boundaries
preserve statement order, condition classes and messages, callback boundaries
and dense/availability divergence.

### 4.1 E. Fold envelope

Validate the execution spec (`R/fold-engine.R:237`); prepare run-scoped inputs
and services (`:286-490`); when a seed is supplied, save ambient RNG, seed, and
restore on every exit (`:271-284`); unseeded strategies may advance ambient RNG
and the runner and sweep keep their outer scopes (`R/backtest-runner.R:686-699`;
`R/sweep.R:152-165`). Initialize handler buffers, bind the corporate-action
boundary at `start_idx` (`:514`), run the handler transaction (`:1388`), drive
pulses, apply stop results (Section 5.4), flush pending work and write
completion and diagnostics (`:1359-1383`), map an exception to the existing
availability diagnostic (`:1393-1411`), and return the fold result (Section
5.5). The persistent handler's transaction spans the whole invocation and
re-raises an interrupt after rollback (`R/backtest-runner.R:276-284`); the
memory handler runs the loop bare (`R/sweep.R:1791`).

### 4.2 P1. Observe and settle

Select the pulse's prepared views; post due corporate-action cash
(`:555-578`); derive the decision view and valuation (`:586`); post scheduled
dispositions and re-derive the view when any posted (`:589-609`); resolve
lifetime terminals, dispose or stop, and re-derive the view (`:611-692`); stop
on an unpriced holding (`:700-710`); record freeze entry and exit (`:711-734`);
normalize the carried strategy state for a changed axis (`:753-758`); value
pulse-start holdings (`:769`); append the availability equity fact and call the
handler's equity recorder when it exists (`:780-795`). Dense P1 is the
corporate-action post, valuation and equity call only.

P1 is one stage because dispositions and terminals consume current marks and
force re-observation; the decision view is derived up to three times in one
pulse (`:586`, `:607`, `:692`). Three write orders inside P1 stay distinct:
corporate-action cash appends its event, then mutates cash
(`R/corporate-action-settlement.R:452-453`); a disposition mutates a candidate
state, appends, and the caller installs it (`R/terminal-outcomes.R:156-215`;
`R/fold-engine.R:681`); fills follow Section 4.5. A dense corporate-action
refusal aborts (`:572`); an availability refusal is a stop.

P1 returns a decision packet: pulse index and time, axis identities and
positions in axis order, cash and positions value, eligibility and valuation
planes, source-row locators into prepared bars and feature matrices, and the
membership vector. It returns no data frame. The packet lives until the end
of P5.

### 4.3 P2. Decide

Slice the public frames from the packet's locators, build the public context
(`:815-873`), reset pulse notes and attach them (`:880-881`), call the strategy
and wrap failure with the same context (`:882-897`), normalize the result shape
(`:903-917`), validate targets (`:919`), apply the availability target rules
and the risk-mark gate (`:954-985`), apply risk and post-risk validation
(`:988-993`), and record the decision and stale-mark traces (`:995-1017`).
Return pre-risk targets, post-risk targets and the raw user state update.
`ctx`, `bars`, `feature_table` and `features_wide` die when P2 returns; they
never enter the carrier and never cross a stage boundary. P2 does not
normalize the state update.

### 4.4 P3. Plan execution

Compute deltas (`:1024-1029`), build the mode-specific plan (`:1038-1070`),
validate declared event kinds (`:1071-1077`), run the availability
affordability pre-check as a stop (`:1084-1108`) and append the rejected and
filled segments (`:1110-1145`). Return the immutable plan and the segments.
P3 mutates no economic state and no handler buffer. The dense planner keeps
next-bar timing and the final-bar warning (`:114-200`); the availability
planner keeps the declared opening, membership input and no-fill reasons
(`R/availability-economics.R:368-494`).

### 4.5 P4. Apply economic events atomically

Bind the next corporate-action boundary (`:1152`), then apply the plan. For
each canonical fill: lot transition and installation (`:1190-1198`); handler
fill-event write and event-sequence advance (`:1205-1210`); handler
accounting-fact record when the method exists (`:1211-1217`); position and
cash mutation (`:1224-1231`). The compiled batch keeps its own FILL-only order,
state first and batch append second, inside its closed envelope
(`:1157-1181`); unsupported kinds refuse before mutation. Extraction does not
reconcile the two orders.

### 4.6 P5. Commit the pulse

Flush staged fills (`:1239`); update the last executed time and reconcile
recorded cash against the plan, aborting on mismatch (`:1243-1256`); compute
and append the reconciliation segment from the packet and both target vectors
(`:1261-1290`); normalize the raw state update for the axis (`:1294-1305`);
serialize and write or buffer strategy state by event mode (`:1306-1320`);
increment `processed` (`:1322`); record telemetry (`:1324-1339`); flush a due
checkpoint (`:1341-1347`); apply the max-pulse and cooperative interrupt
controls (`:1349-1356`). The reconciliation abort is a fold exception, not a
stop. Only the cooperative option is pulse-granular; a signal interrupt may
arrive in any stage, and the persistent handler rolls back the invocation.

## 5. State Ownership

### 5.1 Fold-owned mutable state

One environment, constructed once in E with every name present and typed,
then locked against new bindings. Slots: cash, positions, lot state, carried
strategy state and the axis it was normalized for, event sequence, status,
stop reason, affected exposure, `processed`, `full_run`, `equity_facts`, last
fully valued and last executed times, the frozen set, the current stage label
and pulse time for the exception diagnostic, the pending diagnostic segments,
the diagnostic sequence counter (`:400-401`, advanced on every block flush)
and the telemetry sample index (`:1325`, read at `:1414`). Every slot is
mutated only by its owning stage or by E when applying a stop result. `ctx`
must not reference the carrier; positions reach it as the copied snapshot they
do today (`:811-813`). A second mutable aggregate, a copied mutable aggregate,
and a data frame slot are each a detector failure.

Census boundary. Sections 5.1 and 5.2 cover state reachable from the pulse
body that carries run or pulse meaning. Process-global utility state is
outside both: `canonical_json()` reads and writes the package's content-keyed
JSON memo (`R/config-canonical-json.R:107-112`) from any stage that
serializes. It carries no run state, and extraction neither moves nor
declares it.

### 5.2 Declared stateful run services

A closure-owned service is permitted only when its mutating or cursor-bearing
methods and their calling stages are declared. This census covers every
closure or environment reachable from the pulse body that carries run or
pulse state at the baseline, within the Section 5.1 boundary; the history wave
extends it by amendment.

| Service | Mutating or state-sensitive calls | Stage |
| --- | --- | --- |
| valuation state (`R/availability-economics.R:72-88`) | `advance` | P1 |
| prepared provider (`R/availability-provider-prepared.R:66-81`, `:147-158`) | `decision_view`; `execution_view` | P1; P3 |
| corporate-action plan (`R/corporate-action-settlement.R:353-364`, `:375-392`, `:394-459`) | `post`, `post_disposition`, `check_quantity_effects`; `bind_boundary` | P1; E and P4 |
| pulse notes (`R/fold-engine.R:522`, `:880-881`) | reset; helper writes during the callback; read | P2 |
| fast context and scalar-access tracker (`R/pulse-context.R:507-521`; `R/fold-engine.R:443-447`) | pulse index and accessor state | P2 |
| feature-bundle accessors (`R/runtime-projection.R:574-640`, `:644-701`) | last explicit feature-map memo, written by `ctx$features()` calls inside the callback, in both the per-pulse and the fast-state variants | P2 |
| diagnostic writer (`R/availability-diagnostic-writer.R`) | `append_block`, whose internal chunk flush calls the handler's `write_run_diagnostics`; `drain`, `release` | E applying a stop, P5; E |
| output handler | `init_buffers`, `run_transaction`, `write_run_evidence`, `write_exception_diagnostic`: E; `write_run_diagnostics`: E and wherever a diagnostic block flushes (stop application, P5); `append_event_rows`, `record_equity_fact`: P1; `write_fill_events`, `record_accounting_fact`, `append_compiled_spot_batch`: P4; `flush_pulse_events`, `write_strategy_state`, `buffer_strategy_state`: P5; `pending_event_count`, `pending_state_count`, `flush_pending`: P5 and E (`R/fold-engine.R:1341-1347`, `:1359-1362`) | as listed |
| telemetry environment | sample writes; totals | P5; E |

A call-site census detector rejects a declared mutator called from an
undeclared stage. Services are neither immutable inputs nor carrier slots.

### 5.3 Short-lived typed results

The P1 packet lives through P5. P2's two target vectors live through P5 and
its raw state update through P5 normalization. P3's plan is immutable through
P4 and its segments live through the P5 flush. Per-fill locals die after the
cash mutation. Public frames never leave P2.

### 5.4 Stop result

P1, P2 and P3 may return one typed stop result: status, reason code, affected
instrument IDs and exposure, diagnostic segments in emission order, and
whether the pulse counts as processed. E alone applies it: it sets status,
reason and affected exposure, appends the segments, increments `processed`
when the result says so, flushes the diagnostic block, and breaks, in that
order, matching `:982-984` and `:1106-1108`. The current asymmetry is
preserved: the P2 risk-mark stop (`:967-984`) and the P3 affordability stop
(`:1096-1108`) count the pulse; P1 settlement, terminal and valuation stops do
not (`:474-490`).

### 5.5 The fold return

Sixteen assignment sites inside `run_loop()` write loop-local bindings: nine
to `state` or its components (`:565`, `:597`, `:681`, `:1168-1170`, `:1198`,
`:1230-1231`), five to `event_seq` (`:566`, `:598`, `:682`, `:1171`, `:1210`)
and two to `state_prev_mem` (`:753`, `:1311`). The return at `:1416-1425`
therefore exposes the pre-loop `state`, `state_prev` and `next_event_seq`.
Production consumers: the runner stores all three and never reads them
(`R/backtest-runner.R:1268-1270`); sweep reads none. Registered consumers: the
compiled-parity detecting blocks LTB-0006 and LTB-0013 compare
`fold$state$cash`, `fold$state$positions`, `fold$state$lot_state` and
`fold$next_event_seq` between the compiled and canonical paths
(`tests/testthat/test-execution-spec.R:604-610`, `:751-757`). Today both paths
return the same pre-loop values, so those assertions pass without comparing
anything the loop produced.

Bound: the fold returns live values for the three fields. This repairs the
stale-return defect, so it is an exception to decision (7); it is the only
one this synthesis admits, the Section 3 table records it for explicit
maintainer acceptance, and every other defect stays recorded and routed. With
the Section 5.1 environment the return is reference-cheap, and the four
return-field comparisons in each block become real; the blocks' other
assertions already compare produced events, attributes, summaries and
reconstructions. The three dead runner stores may be removed as cleanup.
Both blocks must pass against the live return before Workstream 38 closes
(Gate C). If either fails, the failure stops dependent work and the test is
not changed. The implementer establishes the cause first: an extraction or
return-plumbing defect is fixed inside the workstream; a divergence that
predates the refactor is recorded and routed under decision (7) and fails
closed, so the gate stays red and the workstream stops for maintainer
disposition. Routing alone never clears the gate. The draft of this synthesis
bound deletion of the three fields. Final review F1 established the two
registered consumers; the synthesis author then chose live return over
deletion, because deletion would have left four assertions in each block
hollow or forced a change to registered tests. The review did not select the
remedy.

### 5.6 Handler-side delta arithmetic

The buffered persistent path and the memory handler call
`ledgr_fill_event_payload`, which computes `cash_delta` and `position_delta`
for the event row (`R/backtest-runner.R:132-137`); the live persistent path
bypasses it and computes the same values inside `ledgr_write_fill_events`
(`R/backtest-runner.R:519-531`; `R/ledger-writer.R`); the fold computes them
for state (`:1225`); the planner computes them for affordability
(`R/availability-economics.R:303-309`). The memory handler also splits leg fees
(`R/sweep.R:2070`), a projection. Bound: extraction preserves all of these
byte-identical, moves none, and records the duplicate as the Section 11
obligation. The availability reconciliation (`:1256`) remains the runtime
cross-check. Seed v1's claim that handlers are already economics-free is
withdrawn.

The Execution contract's Cost Resolution And Accounting Events heading says
output handlers must not compute cash deltas. The baseline already disagrees
with that clause by letter. This synthesis records the discrepancy; it
neither amends the clause nor exempts the handlers, and the baseline is not
evidence of compliance. Workstream 33, the present-tense contract pass, owns
the disposition: narrow the clause to the row-materialization reading the
code implements, or route a code ticket. Workstream 38 changes nothing here.

## 6. Mode, History And Compiled Seams

Availability owns dynamic axes, valuation, terminal and freeze behavior,
affordability and reconciliation; dense owns its fixed axis, fast context and
final-bar warning. Extraction adds no mode, branch or unification; dense stays
frozen under the release-line decision in the macro plan's execution-core
consolidation section.

History: P1 is the sole reader of history-derived values and P2 the sole
adapter of those values to the public context. Whether history arrives as
prepared typed values or as a declared incremental service is the history
wave's decision; this RFC chooses neither and the Section 5.2 census is where
that service would be declared.

Compiled execution: P4 is a demonstrated candidate seam, by the LDG-2992
hybrid in which fills ran compiled while P1 events ran canonical on the same
lot state. The compiled-execution-envelope RFC may keep P4 alone or widen the
seam to P3 plus P4. Canonical R remains the normative oracle. No default,
envelope or fallback is decided here.

## 7. Oracle And Evidence Before Extraction

**Recorder repair.** Schema 120 deleted feature persistence; one query line
executed under two tags (`dev/bench/v0_2_2_real_data_scale/run_record.R:148`)
aborts the recorder. The repair is evidence tooling and adds no compatibility
surface. Its acceptance oracle has two parts. First, a family-name assertion:
the repaired recorder's family set on the accepted tree equals the last
accepted fixture record's set minus `momentum_features` and
`equal_weight_features` plus the one new feature-hash family, and nothing
else; the historical record is named by path and source commit in the
LDG-3052 evidence. Second, the byte comparison against that record is
informational, because it crosses the schema-120 and identity-rule-3
transition: `run_families()` keeps `schema_version` in both run-info families
(`run_record.R:61`, `:143`), so those and any identity-bearing column differ by
design, and the implementer enumerates every differing family and explains
each by the transition before the record is accepted. `check_record.R:15-26`
cannot report "exactly two missing" on its own, since it takes the union of
both sides and the added witness is missing on the historical side. The
complete new manifest is the oracle from the repaired baseline onward: every
extraction commit compares byte-for-byte against its immediate parent. The
recorder gains a declared per-phase family manifest and fails when a wanted
phase writes fewer families than declared; the derived count is reporting
only. A recording wrapper around the momentum strategy hashes
`ctx$vec$feature(id)` for every registered feature over `ctx$universe` at each
pulse into one new family, preserving a feature-value oracle through the
surviving vector surface without the deleted table or `ctx$feature_table`. A
schema catalogue test proves the `features` table is absent. The repaired
record on the accepted tree is the parent baseline for the first extraction
commit.

**Witnesses the workstream must register.**

1. The inventory: every read, write, service call and observable effect of the
   pulse body mapped to E or exactly one stage, including both `state`
   bindings of Section 5.5.
2. Detectors: second carrier or copied mutable aggregate; data-frame carrier
   slot or stage argument; `ctx` referencing the carrier; undeclared service
   mutator by stage; duplicated inline stage body after extraction.
3. Context identity: dense, availability and empty-axis pulses produce
   identical context classes, names, order, alias behavior, helpers, errors
   and callback side effects before and after each commit.
4. Fault injection: a delegating handler around each real handler throws on
   the Nth `write_fill_events` in a multi-fill pulse, for both handlers in
   both modes, and on the Nth `record_accounting_fact` for the memory
   handler, the only handler with that method (the persistent handler at
   `R/backtest-runner.R:246-583` defines none; `R/fold-engine.R:1211` guards
   the call). Durable execution rolls back the invocation; an availability
   run also writes the existing exception diagnostic (`:1393-1411`), while a
   dense run writes none and keeps its current failure path; the memory
   candidate fails with no partial summary; an invalid fill fails in lot
   application before any write. The existing `exception_rollback` and
   `nonmember_increase_rollback` witnesses are the base.
5. Interrupted-plus-resumed equals uninterrupted; seeded caller RNG is
   restored on success, strategy error and interruption; unseeded runs are
   not claimed to restore it.
6. Each stage commit passes the manifest ladder byte-identically against its
   immediate parent and keeps the paired-clock median at or below 1.05 on
   `dev/bench/peer_benchmark/peer_benchmark.R` and the availability arm of
   `dev/spikes/one_execution_mode/probe.R`, three alternating pairs each.
7. Telemetry keys are unchanged; sample points may move with stage
   boundaries because sampled values are clocks, not compared bytes. This is
   a synthesis resolution; seed v2 left telemetry sampling open.

## 8. Ticket Consequences And Gates

Rewritten at acceptance by the maintainer; this synthesis names content, not
text. LDG-3052 owns the inventory, the carrier constructor and lock, the stop
result type, the service census and its detector, the other detectors, the
recorder repair and the parent baseline. LDG-3053 extracts E's skeleton, P1
and P2, one stage per commit. LDG-3054 extracts P3, P4 and P5, reduces
`ledgr_execute_fold()` to orchestration, makes the Section 5.5 return live as
the one permitted repair, removes the three dead runner stores, and records
the final stage profile for the compiled-execution-envelope RFC. The
Workstream 38 review claim names five stages and the three ownership classes.

| Gate | When | Must hold |
| --- | --- | --- |
| A | before the first extraction commit | inventory checked in; detectors registered and failing on their mutations; recorder repaired with manifest and feature witness; Section 7 family-name assertion and transition-difference enumeration recorded; parent baseline recorded on the accepted tree; Section 5.5 consumer disposition recorded |
| B | every stage commit | one stage moved, old inline body absent; manifest ladder identical to the immediate parent; both clocks at or below 1.05; detectors green; seven optimization shapes walked on every changed function |
| C | Workstream 38 close | witnesses 3 to 5 green as Section 7 states them; orchestrator names five stages in order; LTB-0006 and LTB-0013 pass against the live return, unchanged; a failure is investigated for cause and routed per Section 5.5 and keeps this gate red; package suite and `R CMD check` pass as LDG-3054 already requires; stage profile recorded; no `contracts.md` edit (Workstream 33 owns any) |

## 9. Rejected, One Line Each

- Eight phases because decision (11) listed eight: the order misplaces
  valuation and reorders a recorded fact.
- A maintainer decision before synthesis: the cycle reserves that stage for
  product-level binary choices; authority changes bind at acceptance.
- Splitting P1 into settle and observe: settlement consumes marks and forces
  re-observation; the split would repeat or hide that dependency.
- Passing `ctx` or any frame between stages: the public context carries data
  frames and would cross a typed boundary.
- Normalizing the state update in P2: it reorders an error against fill
  staging and the appended reconciliation block.
- A list-and-return carrier: passes and returns the carrier by value and needs
  one write-back binding per stage call, the shape that produced the stale
  return; copy behavior is not the ground, since it depends on the write form
  in either design.
- An R6 carrier: excluded by the project's dependency stance.
- Deleting the three return fields: two registered detecting blocks read
  them in four assertions each; deletion would leave those assertions hollow
  or force a test change.
- Closing Workstream 38 with a routed LTB-0006 or LTB-0013 failure: compiled
  divergence fails closed and LDG-3054 requires passing checks; routing
  records, it does not clear.
- Making handlers economics-free in this cycle: four byte-identical
  computations would move during a refactor that must not move them.
- Deciding history representation or compiled envelope here: separate RFCs
  own both; this RFC binds only the P1 reader and P4 seam rules.
- Unifying modes during extraction: dense is frozen by release-line decision.
- Keeping 51 families with a placeholder, or restoring the `features` table
  for evidence: compatibility code for a deleted surface.
- Dropping the feature-value oracle: a strategy-insensitive bug in the P1 to
  P2 move would be invisible to the equal-weight families.
- A prerequisite spike: every fact is in the baseline tree; stage-call
  overhead is already gated by the clocks.

## 10. Open Questions Promoted To Spec-Cut

- Whether the recorder repair is its own ticket or an LDG-3052 acceptance item.
- The exact per-phase family manifest and the name of the feature-hash family.
- Field names of the stop result and the carrier slots, under Section 5.
- Where inside P2 the frame slicing now at `:735-749` lands, and whether the
  dense fast-context update keeps its separate branch inside P2.
- How the inventory file is checked in and kept current across the six
  commits.

## 11. Future Obligations Recorded

- **Output-handler consolidation or compiled-execution-envelope RFC,
  whichever opens first:** one computation of fill cash and position deltas
  consumed by the row builders, and leg-fee splitting named as a projection
  (Section 5.6). Trigger: the first ticket that edits `write_fill_events` or
  `ledgr_fill_event_payload`.
- **Compiled-execution-envelope RFC:** consumes the P4 seam or a P3 plus P4
  seam, the final stage profile from LDG-3054, and the live fold return of
  Section 5.5.
- **Workstream 33:** disposition of the pre-existing handler/contract
  discrepancy recorded in Section 5.6.
- **History wave (WS3/WS4):** P1 as sole reader, P2 as sole adapter, and any
  incremental history service declared in the Section 5.2 census by
  amendment.
- **Context frame retirement:** after extraction the frames are P2-local, so
  retirement edits P2 and the context helpers only.
- **Governance:** the acceptance commit amends Cut 15 decision (11) per
  Section 3, records the Section 5.5 exception to decision (7), and rewrites
  every `tickets.yml` address the Section 3 table marks amended; the pipeline
  row moves to accepted with these obligations.

Speculative deferral for the horizon at acceptance: a fused P3 plus P4
compiled kernel; a unified stop-or-abort type that also covers the P5
reconciliation mismatch. Neither is authorized.

## 12. Failure Scenarios

| Scenario | Bound behavior | Failure of this design |
| --- | --- | --- |
| Equity fact moved after fills | P1 records it before the strategy | an eight-label extraction reorders a recorded fact |
| Reconciliation lacks marks | packet lives through P5 | a packet released after P2 breaks P5 |
| Service mutated from the wrong stage | census detector fails | a cursor advances twice or not at all |
| Second state binding | one locked environment | the stale-return pattern returns under a new name |
| Stop applied inside a stage | E alone applies stop results | processed count or flush order drifts |
| State update normalized early | P5 normalizes | the user-state error precedes fill staging |
| Handler delta drifts from fold delta | byte-identical, cross-checked by reconciliation | the duplicate silently diverges in a later edit |
| Recorder family lost silently | per-phase manifest fails the record | a comparison passes on fewer families |
| Feature bug the strategy ignores | `ctx$vec$feature` hash family | equal-weight families stay identical |
| Signal interrupt mid-stage | whole-invocation rollback, re-raise | a half-applied pulse persists |
| Live return fails a detecting block | cause established first; an extraction defect is fixed in the workstream, a prior divergence is routed and fails closed; Gate C stays red | the block is weakened, or a routed failure is read as clearing the gate |
| A second defect fixed in passing | decision (7) admits only the Section 5.5 exception | the refactor accretes repairs |

## 13. Release Boundary And Final Review

This synthesis gates Workstream 38 and the Section 3 amendment and nothing
else. No code, recorder, ticket, contract or roadmap change is authorized
before maintainer acceptance; after acceptance, implementation follows the
rewritten tickets and Section 8 gates.

Final review is Type 1 by an author of neither seed v2 nor this synthesis:
every line anchor in Sections 3 to 5 resolves at the baseline; the equity fact
and valuation marks precede the strategy call; the sixteen assignment sites in
Section 5.5 are the complete set and its consumer disposition names every
production and registered reader; the Section 5.2 census matches every `<<-`
and environment write reachable from the pulse body within the Section 5.1
boundary; the three P1 write orders are cited correctly; the Section 7
family-name assertion is reproducible and every byte difference against the
historical record is explained by the transition; seed v2 and this synthesis
are consistent except where Section 1 item 7 marks a seed provision
superseded; the Section 5.5 live return is the only repair any rewritten
ticket admits; no shipped contract rule changes. A design concern returns
`NEEDS_TYPE_2` and stops.

## Revision History

- 2026-10-15 - Draft for final review. Stages run: seed v1 (Codex), Type 2
  response (Claude), response review by the seed author incorporating all
  thirteen findings, seed v2 (Codex), this synthesis (Claude). Research input
  skipped: the corpus already covers the baseline. Maintainer-decision stage
  skipped: no product-level binary choice; the authority amendment binds here.
- 2026-10-15 - Patched in place after Type 1 final review by Codex
  (CHANGES_REQUIRED; `rfc_fold_execution_phase_ownership_v0_2_2_final_review.md`).
  F1: the assignment inventory corrected to sixteen sites and three dead
  stores; Section 5.5 reversed from deleting the three return fields to
  returning live values, because LTB-0006 and LTB-0013 read them and today
  compare pre-loop values. F2: the recorder oracle split into a family-name
  assertion and an explained transition comparison. F3: `diagnostic_seq`,
  `telemetry_idx`, the feature-bundle accessor memos and the pending-count
  reads added; handler stage sets corrected; the JSON memo named as process
  state outside the census; the scalar-tracker citation qualified. F4: stop
  application order corrected to count, flush, break. F5: the fault-injection
  matrix corrected to the methods and diagnostics that exist. F6: the live
  write path described correctly; the pre-existing handler/contract
  discrepancy routed to Workstream 33. F7: ticket titles and the review reason
  added to the supersession table with YAML addresses. F8: three further
  departures from seed v2 disclosed; the environment rationale narrowed; seed
  v2's P5 order and Section 8 oracle patched in place. Focused Type 1
  re-review due.
- 2026-10-15 - Patched in place after the focused Type 1 re-review by Codex
  (CHANGES_REQUIRED, four findings;
  `rfc_fold_execution_phase_ownership_v0_2_2_final_re_review.md`). Finding 1:
  Gate C no longer accepts a routed LTB-0006 or LTB-0013 failure; both must
  pass, a failure is investigated for cause and keeps the gate red, and the
  LDG-3054 package-check requirement is restated. Finding 2: the live return
  is named the single exception to decision (7), recorded in the Section 3
  table for explicit maintainer acceptance and attributed to the synthesis
  author's response to F1, not to the review. Finding 3: the no-copy claim
  withdrawn from Sections 2 and 9; copy behavior restated as a property of
  write form and sharing, with a `tracemem` probe on R 4.6.1. Finding 4: seed
  v2 Sections 6 and 9 item 4 marked superseded (Section 1 item 7, Section 13)
  and the count-only-by-RFC rule disclosed as a departure. Second focused
  confirmation due; a further correction round would be the third.
- 2026-10-15 - Focused Type 1 confirmation by Codex: PASS, all four
  dispositions close the re-review findings, no further correction round.
  One-line record and no file, per the cycle's record rule. Confirms the
  document corrections only, not implementation. Awaiting maintainer
  acceptance.
- 2026-10-15 - Accepted by the maintainer, explicitly including the Section
  5.5 exception to decision (7). The acceptance commit amends Cut 15 decisions
  (11) and (7), rewrites LDG-3052 to LDG-3054 and the Workstream 38 review
  reason, moves the pipeline row to obligations open and parks the Section 11
  speculative deferrals in `../horizon.md`.
