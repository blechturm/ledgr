# Diagnostic Records Amendment: D3 Decision Synthesis

- Mode: Decision synthesis, RFC cycle stage 7.
- Author: Codex; date: 2026-11-10.
- Status: **narrow synthesis of D3; awaiting maintainer acceptance**.
- Reviewed tree: `87bbf15402938ec6bf517cd57bb83e89e040ae53`, detached.
  Its `R/` has no difference from `d5b3a151`. Code citations below resolve
  at that pin; design and evidence citations resolve at the reviewed tree.
- Inputs: the diagnostic-records [seed](rfc_diagnostic_records_v0_2_3_seed.md)
  D3 and Section 2; [Type 2 response](rfc_diagnostic_records_v0_2_3_response.md)
  Section 2 and Additional corrections; maintainer routing of Cut 13 R3 on
  2026-11-10, supplied in the operative brief. That routing substitutes for
  the D3 response review. No separate D3 seed v2 is required by this brief.
- Scope: `dev/lean_core/` upon acceptance, then the atomic switch. Nothing
  here changes the frozen core in `R/`, shipped contracts, a stored codec,
  or a registered test. D1, D2, D4-D7 and seed Section 4 remain **revise before
  synthesis**. This decision needs none of them to be accepted.

Aliases: **P** = `inst/design/rfc/rfc_lean_core_pulse_plumbing_v0_2_3_synthesis.md`;
**D** = `inst/design/rfc/rfc_per_pulse_durable_records_v0_2_3_synthesis.md`;
**I**, **M**, **L** = `lean_core_interface.md`, `macro_plan.md`,
`lean_core_rules_ledger.md` under `inst/design/ledgr_v0_2_3_spec_packet/`;
**E** = `dev/spikes/diagnostic_records/`; **T** = `E/type2_probe/`.
The response's `probe/` means **T**, not a directory beside its Markdown file.
Links below use the intended installation location, `inst/design/rfc/`.

## 1. Decision and evidence

**Adopt no persistent store writes while pulses are processed. Keep logical
acceptance and publication per pulse. Materialize committed records in bounded
batches after the loop, within the existing fold transaction.** A sweep
candidate uses the same acceptance rules in memory and never writes a store;
worker candidates also remain non-writing after their loop. The orchestrator's
existing publication responsibilities do not move into workers.

This resolves Cut 13 R3 by preserving P4/P5's protocol, rather than replacing
it with a whole-run publication call. P4 reserves records and advances accepted
sequence/time boundaries in its existing order. P5 checks capacity and makes
the complete pulse's fill ranges and legs committed. A later materialization
call consumes those commitments; it does not accept the run's fills anew.
P1 and non-fill producers commit at their own existing semantic boundaries.

The distinction is observable. A recorder or handler read during execution
can see the then-committed prefix, never an outstanding fill suffix; the
handler-local accepted-range leg exception stays. Stage refusals retain their
precedence and pulse identity. There is no in-loop SQL visibility, insert
failure or durable checkpoint. External readers receive durable evidence only
after transaction success. A single terminal logical publication would erase
these internal boundaries and defer capacity/append failures to the last
pulse; merely recovering the same successful tables would not establish
equivalence.

The pin separates these operations: P4 installs the book, publishes, advances
sequence and records legs before installing positions/cash
(`R/fold-engine.R:1476-1512`); P5 exposes fills/legs before reconciliation
(`:1542-1584`; `R/output-handler.R:571-587`). Physical event drainage is later
(`R/fold-engine.R:1651-1656,2033-2035`). The
[fold core](../contracts.md#contract-execution-fold-core),
[event staging](../contracts.md#contract-execution-event-staging) and
[fold evidence](../contracts.md#contract-persistence-fold-evidence) groups
distinguish accepted effects, publication and transaction success.

Choose **bounded terminal batches**, rather than a required append per table:
the owned records already live for the run; a giant expanded frame adds a
second run-sized representation without improving atomicity. A small table
may fit in one batch. A large pulse may span physical batches because its
logical commitment has already completed. Batch boundaries neither reset
logical counters nor create transaction commits. Expansion within a batch is
vectorized; a loop over terminal store batches is justified by the bounded
DBI transfer boundary, not by per-row economic work.

The response's D3 conditions are met: typed owners, bounded terminal
materialization, accepted-prefix and rollback preservation, explicit memory
accounting and a named `checkpoint_every` disposition. Its H1 figures support
pursuing this representation, not a bound or an implemented-writer claim.
`T/h1.csv:2` reports DONE on snapshot hash
`e8cbb805486726cd9e8758e377bdc92a97e80b4a07f3df2d5fc1b9c8766430a1`:

| Retained pin payload, after excluding holds | Rows | MiB |
| --- | ---: | ---: |
| Explicit diagnostics | 23,036 | 5.795 |
| Implicit clean fills | 8,797 | 0.998 |
| Ledger events | measured separately | 3.023 |
| Equity | measured separately | 0.387 |
| Total | | 10.204 |

These are R frame object sizes, excluding 163,775 holds, count/header records,
any further exact-position evidence, capacity slack and terminal copies
(response `:107-140`; environment `T/environment.csv:2`: R 4.6.1, DuckDB 2.0.0,
pin `d5b3a151`). They are conditional payload observations, not the memory
required by D3 independently of D1. With the current codec all evidence it
requires must still be retained. `E/evidence/probe_writes.csv:17` records nine
in-loop implicit-row appends on crossover 500 x 1,260; the fork moves them
after the loop. Its successful table comparisons (`E/evidence/fork_runs.csv`)
do not settle the response's later fractional-position counterexample or
prove every stop prefix. No private input or workload was rerun here.

**Transaction scope is precise.** The fold's one transaction is the boundary
for terminal event, diagnostic, codec, coverage, summary and completion
materialization (`R/fold-engine.R:2033-2059`). Equity remains the frozen valued
prefix passed to the pin's later finalization (`:2095-2096`;
`R/backtest-runner.R:899-912`). That finalization already has a separate
equity/status transaction (`R/run-finalize.R:383-436,449-471`). D3 changes no
such boundary. Thus "one transaction" does not claim that registration,
equity finalization, failed-attempt evidence and telemetry all share one SQL
transaction. Moving equity/status into the fold transaction is rejected here:
it is unnecessary for no in-loop writes and would change I:795-797 and
[telemetry and recovery](../contracts.md#contract-persistence-telemetry-and-recovery)
(`contracts.md:1705-1712`). Equity is held during the loop and written only
after it through that existing finalization. Recovery after a committed fold
and failed finalization stays available without callbacks.

## 2. Memory and `checkpoint_every`

The replacement for R7's working-storage bound is **run-long owned typed
records, plus bounded terminal expansion**. Allocate predictable pulse
columns once; grow other typed columns by capacity and write by index. Do
not collect a frame or list per pulse. Count retained event/diagnostic/leg
capacity, pulse headers, equity and growth copies, as well as used rows.
Source/history, live lots, recorder captures and requested public results
remain separately accounted; separation does not remove them from the
process peak. A row bound on expansion is not a byte bound on strings or
the whole invocation.

Each cut changing this path records live used/allocated capacities and peak
memory during terminal materialization on its covered portable workloads,
including an exception-heavy case. Record the batch row limit and the
simultaneously live owned records, expanded columns and transfer copies.
Use the existing memory method; retain the macro family method's milestone
H1/worker and full memory records (M:823-833). These observations are not a
new per-cut numerical memory gate. At the switch, measure the full execution,
materialization and reader/finalization peaks with the surviving codec,
including H1 and worker multiplicity, rather than extrapolating 10.204 MiB.

There is **no new total-memory ceiling or diagnostic-volume refusal** in D3,
and no promise of success for arbitrarily long or exception-heavy runs.
Run-long records can exhaust memory. Existing entry/index/counter limits,
pulse diagnostic capacity and the contracted P5 fill-capacity refusal remain;
allocation failure aborts with the error/interrupt protocol below where R can
handle it. No spill file or in-loop store drain is a fallback. Process death
cannot promise an R exception diagnostic; existing transaction/restart rules
apply. This is an explicit withdrawal of R7's chunk-sized working-storage
guarantee, requiring acceptance of this amendment.

The maintainer's 2026-11-09 acceptance of the **1 MiB preparation miss** does
not cover this change. It disposed of one 456 versus 455 MiB cell, whose peak
was set by pinned steps after hydration (tickets.yml:4434,4443). It neither
authorized run-long diagnostics nor waived future measurements.

`checkpoint_every` is not a logical-commit cadence: the pin commits pulse
visibility independently and uses this hashed value only to flush buffered
events (`R/backtest-config.R:93,164-169,188-193`;
`R/config-hash.R:28-61`; `R/fold-engine.R:1651-1656`). P:305 and its open
question still say this needs a decision, but **L:39, LR-20** records the
maintainer's 2026-11-06 decision to retire it with `execution_mode`, also
recorded in the RFC README pulse-plumbing row. Adopt and reconcile that
decision, rather than opening it again:

- **Before the switch:** the lean entry has no `checkpoint_every` argument.
  The adapter accepts only the pin's baseline `engine.checkpoint_every =
  10000L` and no `control$checkpoint_every` key. It refuses a non-default
  value or that explicit control override before the first pulse with the
  existing lean coverage condition, naming the unsupported control; the
  harness may run the complete workload on the pin. The default field remains
  in the upstream pin's config/hash, checked as an input restriction and
  absent from the lean execution state. It schedules neither writes nor
  logical commits. This is a dev-only adapter constraint, not a public
  ignored argument or a silently rewritten config/hash.
- **At the switch:** remove the public formal, engine field, control key,
  execution-spec/service plumbing and all readers/examples teaching the
  control. Refuse the retired control key. Include its deletion in LR-12/
  LR-20's explicit configuration/dependent-identity and store-version/
  fingerprint change. Use P Section 5's already required identity-rule
  successor (5 to 6 against today's pin), reconciled with the switch baseline;
  record actual dependent hashes and the then-current store successor. No
  old-config normalization, migration or compatibility reader is added.
  The terminal batch limit is internal and does not enter economic identity.

## 3. Exact pulse-plumbing supersession

The following is the operative amendment text to append at acceptance.
Quoted old clauses identify the superseded text; unquoted surrounding clauses
remain. Scope is the pending lean core only, then its atomic switch. Original
text and evidence remain historical, with notices pointing to this amendment.

### D3-A. R7, R8, R9 and R10

**R7, P:149:** replace "The latter may be immutable indexed columns, but must
outlive their pending chunk." with:

> The latter may be immutable indexed columns, but must outlive every
> accepted record that refers to them, through terminal materialization.

**R7, P:152-157:** replace:

> Working output expands and drains by a fixed row bound and at normal or
> INCOMPLETE end, including an under-full final chunk. A pulse larger than the
> chunk is split without publishing an incomplete logical fill batch. Working
> storage is bounded by the chunk plus the prepared maximum pulse reservation;
> do not accumulate a run-long list of pulse blocks. Retained memory results,
> equity, source/history, lots and public views are accounted separately.

with:

> During pulse processing retain output in run-long owned typed records;
> perform no persistent store write or spill. Commit accepted ranges at their
> existing semantic boundaries. After normal loop exit, including INCOMPLETE
> and max_pulses, expand only committed records in batches with a fixed row
> limit, and write them once within the fold's one transaction. The last
> under-full batch is included. A committed pulse may span physical batches;
> no logical fill batch is partially published. Total working storage grows
> with retained records; only terminal expansion has a batch row limit. Do not
> accumulate per-pulse frames or lists. Measure used and allocated capacity
> and terminal peak under this D3 synthesis Section 2; it sets no new total
> memory limit or refusal. Account equity, source/history, lots, captures and
> requested public results as well. Equity's later finalization transaction
> remains unchanged.

R7's fill fields, P3-computed effects, exact residual evidence and prohibition
on recomputing effects remain (P:146-151). A terminal batch is a transfer unit,
not a replacement evidence codec.

**R8, P:162-163:** replace "Durable writes use the in-memory chunk path within
the invocation's one transaction; chunks are not transaction commits." with:

> Durable fold writes consume the committed in-memory records only after
> pulse processing ends, in bounded terminal batches within the invocation's
> one fold transaction. Batches are neither pulse publication nor transaction
> commits. Candidates retain their existing output capabilities in memory;
> they and workers perform no persistent writes. Pre-loop setup and existing
> post-fold finalization, exception and telemetry writes retain their own
> boundaries.

R8's mode retirement and no-compatibility clauses remain. Add:

> checkpoint_every retires under LR-20 and D3 Section 2; it is not repurposed
> as a logical commit control. The dev adapter refuses non-default use before
> the switch; the switch removes the field and records the identity change.

**R9, P:167-179:** replace the full rule:

> **R9. Reserve, then commit.** Failed candidate calculation changes no handler
> state. P4 installs the successful book, reserves/writes compact rows, advances
> accepted sequence/time metadata and event sequence, records legs, then installs
> lot-derived positions and ordered cash, preserving the contracted order.
> P5 checks logical fill-event capacity before exposing the complete fill batch and
> legs. Reserved, accepted and publicly committed extents are distinct; no
> reader/flush/recorder sees an uncommitted suffix except the handler-local leg
> projection for its own accepted range. Growth preserves outstanding ranges;
> every reused row initializes every represented column/default. Debug append
> failure advances no accepted boundary or committed count. Workers are
> candidate-local. Handler failure aborts; no private-state rollback is promised.
> The existing compiled arm keeps its state/sequence-before-append order until
> its separately authorized WS14 replacement; R9 does not reorder that arm.

with:

> **R9. Reserve, then commit in memory.** Failed candidate calculation changes
> no handler state. P4 installs the successful book, reserves/writes compact
> owned rows, advances accepted sequence/time metadata and event sequence,
> records legs, then installs lot-derived positions and ordered cash, in the
> contracted order. P5 checks logical fill-event capacity on that pulse before
> exposing the complete fill batch and legs as committed in memory. Reserved,
> accepted and publicly committed extents stay distinct. A handler read or
> recorder sees only the then-committed prefix; only the handler-local leg
> projection may inspect its own accepted range before P5. No store write is
> involved. P1 and non-fill effects commit at their own semantic boundaries.
> Sequence/time boundaries, fill counts, committed extents and leg visibility
> advance during execution, independently of terminal batches. Terminal
> expansion consumes only committed records and performs no new logical
> publication or economic calculation. Growth preserves outstanding ranges;
> initialize every reused represented column/default. Debug append failure
> advances no accepted boundary or committed count. Workers are candidate-local.
> Handler failure aborts; private-state rollback is not promised. The existing
> compiled arm's state/sequence-before-append order stays until its separately
> authorized WS14 replacement; its terminal-write adapter must preserve that
> order and the separately accepted LR-19 capacity disposition. Slice 1 still
> refuses compiled FIFO.

**R10, P:185:** replace "P5 or E-stop drains and resets staging; handed-out
chunks are frozen." with:

> P5 or E-stop drains pulse staging into its owned in-memory committed
> records and resets staging; no drain writes a persistent store. Handed-out
> captures are frozen. Expansion and store transfer occur after the loop.

This clarifies the destination of drainage only. It neither authorizes a new
hold codec nor changes R10's logical positions, exact evidence, capacity or
stop placement. D Sections 2-4 and the current codec stay in force.

### D3-B. Section 5 prefix protocol

The opening distinction between logical publication and physical insert timing
(P:256-259) remains. These are exact replacements for the affected table
clauses; the rest of each row remains unless explicitly replaced below.

| Existing boundary and quoted old clause | Replacement |
| --- | --- |
| Successful candidate, P4 publication or leg failure: "A failed range is not committed or flushed; discard a failed memory candidate, rollback the entire durable invocation." | A failed range is not committed or terminally materialized. Discard the failed memory candidate and its handler; roll back the durable fold invocation. A handler error after private book/state installation still promises no private-state restoration. No accepted earlier pulse becomes a successful partial candidate. |
| P5 event capacity: replace its entire row, quoted below. | Check cumulative accepted fill events plus this pulse's complete fill batch against the prepared run limit, max(1, pulses x instruments), under LR-19. Refuse at P5, after P4's sequence/leg/state work and before committing the batch or releasing its legs, with ledgr_event_buffer_capacity_exceeded, the original message, current stage accounting and that pulse's timestamp. Physical reservations must not enforce this logical limit early; terminal transfer must not enforce it late or reset the count. Non-fill events do not count. LR-19's removal of the old memory non-fill/compiled append refusals is already an explicit oracle difference, not new D3 parity. |
| P1/opening/non-fill publication: "A materializing handler read expands only committed compact ranges." | Commit accepted effects in memory at their existing boundary, preserving append-before-state-install and terminal/corporate-action order; do not wait for the next P5. A handler read may expand only committed ranges in memory, without a store write. Opening/pre-loop boundaries and their sequence seed remain; mixed producers and compiled ranges cannot overlap outstanding fill reservations. Transfer their accepted rows after the loop with no duplication. |
| Normal P5, skip and multiple fill batches: "Flush full committed chunks once; never insert them again at final drain." | Commit complete pulse ranges and release legs in event order during P5, including skips and multiple batches. Retain those ranges through loop exit; do not flush them to a store during execution. After normal end, materialize every committed range exactly once in bounded batches, including the tail, then completion evidence before fold transaction success. Preserve logical diagnostics and the valued equity prefix handed to finalization. |
| INCOMPLETE mid-chunk: replace its entire row, quoted below; rename boundary "INCOMPLETE stop". | E installs the stop exactly once with the original processed-count meaning and commits its diagnostic staging in memory, including deferred decisions, the stop row and logical/codec coverage. Preserve prior committed events and any already accepted P1 non-fill effects on the stop pulse. Never create P4/P5 effects for a P1/P2/P3 stop. After loop exit, materialize that prefix and its under-full terminal batch before completion evidence and fold transaction success. Preserve the exact valued equity prefix, including zero valued rows, and distinct last-valued/last-executed clocks. The P3 affordability_reconciliation_failed stop reached by Cut 13 R1 follows this rule: counts_processed = TRUE, deferred explicit decisions and stop, no stopped-pulse fills, reconciliation success row, state acceptance or hold certification. It returns INCOMPLETE, not an error rollback. |
| Error/interrupt during any chunk/stop/final drain: replace its entire row, quoted below; rename boundary "Error/interrupt during processing or terminal materialization". | Stop processing and discard unmaterialized records. Roll back all fold-transaction writes, including any already transferred terminal batches. Preserve the original condition and its pulse/stage for processing failures. Keep the existing post-rollback exception/FAILED handling and refreshed diagnostic sequence; do not replace a transfer error with an economic refusal. Real interrupts re-raise after rollback. Discard failed candidate handlers and retained state; no successful partial memory candidate, worker durable write or partially promotable interrupted sweep is allowed. |
| Growth, reuse, recorder and requested outputs: "Output retention is separate from bounded working storage (R/output-handler.R:415,761,774)." | Run-long owned record capacity and bounded terminal expansion are measured separately from requested outputs, and all contribute to peak memory. Existing reserved/accepted range preservation, dirty-row initialization, committed-prefix exposure, handler-local leg exception, frozen captures and failed-handler discard requirements remain. |

Old **P5 event capacity** row (P:265):

> Keep ledgr_event_buffer_capacity_exceeded at P5, after P4's sequence/leg/state
> work and before fill visibility (R/output-handler.R:571). Reserving physical
> scratch space at P4 must not enforce that logical limit early. Chunk recycling
> must not change which rows count toward the limit. Today durable counts
> buffered fills since its last flush (`R/output-handler.R:673-686`) and memory
> counts every row, refusing P1 and compiled appends before P5 (`:699-705`,
> `:734-737`); the one-path counted population is a spec-cut choice, and any
> refusal difference is a ledger row.

Old **INCOMPLETE mid-chunk** row (P:268):

> E installs the stop once, with its original processed-count meaning; drain
> prior pulse staging plus that stop's physical rows, logical coverage/implicit
> codec and every already accepted P1 non-fill row. Do not create P4/P5 effects
> for a pulse stopped in P1/P2/P3. Drain all earlier committed compact events
> and the under-full tail before completion evidence and transaction success;
> use the exact valued equity prefix and distinct last-valued/last-executed
> clocks. This follows R/fold-engine.R:1947,1980,2003,2033 and
> R/fold-phase-contract.R:197.

Old **Error/interrupt during any chunk/stop/final drain** row (P:269):

> Roll back all invocation writes, including earlier full chunks; preserve
> original condition and existing post-rollback exception/FAILED handling and
> refreshed diagnostic sequence (R/output-handler.R:93,118,643;
> R/fold-engine.R:2057-2083). No successful partial memory candidate; no worker
> durable writes or partially promotable interrupted sweep.

Add this table row (there is no existing max_pulses row):

| Boundary | Required behavior |
| --- | --- |
| max_pulses | P5 completes and commits the final permitted pulse in memory, increments processed and sets full_run = FALSE at the pin's point. Materialize only that accepted prefix after loop exit; omit completion evidence and preserve the pin's nonterminal return/equity-prefix behavior. A later invocation follows fresh-attempt replacement/restart, not pulse resume. Do not reinterpret this as an INCOMPLETE stop or fabricate unprocessed diagnostics. |

The candidate-calculation-failure row (P:263) stays verbatim. All economic and
debug refusal ordering there survives. For capacity, the original detector
is `R/fold-event-buffer.R:15-19`; P5 calls it at
`R/output-handler.R:577`, with stage set at `R/fold-engine.R:1389` and pulse
time at `:1931`. Preserve those observables even if terminal materialization
could otherwise fit the rows. Logical-limit exhaustion and allocation failure
are distinct. LR-19's population/limit is not a total memory bound.

Normal-stop support is not inferred from a successful-run diff: P3's
`counts_processed = TRUE` stop is `R/fold-engine.R:1178-1204`, E's three stop
arms are `:1947-1951,1980-1983,2003-2006`, and max_pulses/completion handling
is `:1658-1662,2037-2050` and `R/backtest-runner.R:861-897`.
The [fold evidence](../contracts.md#contract-persistence-fold-evidence) and
[completion evidence](../contracts.md#contract-persistence-completion-evidence)
groups continue to govern recovery. The memory transaction is just `fn()`
(`R/output-handler.R:690`); discard its handler on failure rather than claim
SQL rollback cleans it. I:846-859's fresh-attempt/RNG fallback rule remains.

### D3-C. Related operative clauses

- P:272-275: replace "Chunk size is a spec-cut choice." with "The terminal
  batch row limit is a spec-cut choice; it is unrelated to logical commitment
  cadence." Replace "append/leg/flush faults" with "append/leg faults,
  faults during terminal expansion and first/middle/final store batches".
  The listed small-batch, oversized-pulse, multiple-batch, P1-stop, growth,
  dirty-reuse, skip, interrupt and isolation witnesses remain.
- P:305: replace "R8 does not authorize any change to `checkpoint_every`."
  with "LR-20 and this D3 amendment authorize retirement of checkpoint_every
  with explicit configuration and dependent-identity changes at the switch;
  before the switch its non-default use is refused by the lean adapter."
- P's **Open Questions Promoted To Spec-Cut**, P:432-433: replace "choose the
  concrete chunk row bound and its relation to `engine.checkpoint_every`
  (a hashed pulse-count flush control, `R/backtest-config.R:93,192`): keep
  its meaning, or record its change as an explicit identity change with its
  own ledger row; maximum pulse reservation, the event-capacity counted
  population (Section 5)" with "choose the terminal batch row limit and
  maximum pulse reservation; implement LR-19's cumulative fill-only capacity
  rule at P5 and LR-20's retirement of checkpoint_every, including the D3
  dev-adapter restriction and switch identity evidence". Remaining open
  questions and future obligations stay.
- P Sections 6-7's installation/switch instructions that require bounded
  expansion or a chunk path now mean **bounded terminal expansion of
  per-pulse committed in-memory records**, not in-loop transfer or bounded
  total storage. Keep their current-store, no-compatibility, test-census,
  debug-on/off, worker, recovery and identity duties. LR-12's "one chunked
  write path" receives the same terminal meaning. In LR-20 replace "the
  bounded output chunk replaces it" with "bounded terminal output batches
  replace physical flush scheduling; logical commitment remains per pulse".

## 4. Rejected alternatives

| Alternative | Reason |
| --- | --- |
| In-loop chunk writes, or spilling to a temporary persistent store | Contradicts the maintainer's 2026-11-10 routing and no-write position. |
| One terminal logical publication through the pin's ordinary whole-run handler call | Successful final tables alone do not preserve pulse capacity refusals, accepted sequence/time boundaries, leg visibility or P1-stop prefixes. A terminal adapter may consume already committed records, but may not stand in for P4/P5. |
| Require one giant append/frame per table | Adds run-sized expansion copies; bounded batches preserve transaction atomicity and cap expansion rows. |
| Call the H1 payload a memory bound, or borrow the 1 MiB waiver | H1 excludes several capacities/copies and assumes holds omitted; the waiver concerned preparation only. |
| Keep checkpoint_every as a logical commit cadence or an ignored compatibility control | Reinterprets a hashed flush control, conflicts with per-pulse acceptance and LR-20, and preserves obsolete API surface. |
| Make D3 conditional on D1/D5, omit successful reconciliation, change summaries or choose opt-in diagnostics | Those decisions are still open. D3 works with current-format retained evidence; no loss of trace or new codec is authorized. |

The response's additional corrections concerning exact positions, summary
counting, reconciliation and default trace cost are preserved as objections
for their own decisions, not answered by terminal writes. D Sections 2-4,
the [current format](../contracts.md#contract-persistence-current-format) and
the [result read surfaces](../contracts.md#contract-result-read-surfaces)
remain authoritative. There is no claim of a faster default or zero mandatory
accounting work for candidates.

## 5. Open questions promoted to spec-cut

The cut chooses the terminal batch row limit, typed growth capacities and
reservation/range API within Sections 2-3. It does not choose a new logical
publication point, capacity population, memory refusal or checkpoint meaning.
Record capacity and terminal peak at each owning cut, with private H1/full
worker evidence at the macro milestones.

Before closing the implementation, demonstrate durable and memory positive/
refusal parity with debug on/off: empty/no-fill runs; skips; batch size one;
a pulse spanning batches; multiple batches per P5; P1 effects followed by a
P2/P3 stop; Cut 13 R1's affordability stop; zero-valued-row INCOMPLETE;
max_pulses; dirty growth/reuse; immutable recorder captures; candidate
isolation; processing/leg/terminal-transfer errors and real interrupts;
post-commit finalization recovery and nonterminal fresh restart. Force the
P5 capacity refusal after earlier accepted pulses and assert class, message,
stage, pulse time and pre-commit leg visibility. Show that changing the
terminal batch limit cannot move it. Test the checkpoint entry restriction.
Some cases wait for the slice that covers their features; slice 1 proves its
covered cases, and the switch cannot ship with the remaining cases unowned.

Wrap every package store-write boundary while processing pulses and require
zero calls for both sinks. Demonstrate this detector with one real misplaced
write, and demonstrate a terminal middle-batch fault rolling back earlier
batches. Preserve registered fixtures/oracles and record each separately
authorized semantic disposition, including LR-19/LR-20. D3 adds no blanket
test-edit permission. These are implementation obligations, not evidence
claimed by this synthesis; independent Type 1 final review is still next.

## 6. Future obligations recorded

No new later-window RFC obligation is created. P Section 8's existing future
obligations remain unchanged. D1, D2, D4-D7 and seed Section 4 stay in this
amendment's active RFC route, not in the horizon.

The immediate cut obligations in Sections 2 and 5 belong to WS16 slices and
WS14a's atomic switch, including the live-source contradiction census,
deletion of the old runtime fold and contract/identity/config/store
consolidation. Until tickets.yml takes ownership, keep them in the RFC
pipeline and decision bridge; they do not require another RFC cycle.

## 7. Installation at acceptance

These are proposed edits, not edits performed in this worktree. Acceptance
records its actual date/provenance; it does not claim implementation.

1. Install this file as
   `inst/design/rfc/rfc_diagnostic_records_v0_2_3_synthesis_d3.md`, updating
   its status with the maintainer's acceptance and independent final-review
   disposition. Keep the narrow scope and the unresolved decisions visible.
2. Append **Section 3, D3-A through D3-C verbatim** to P under
   `## Amendment: terminal physical writes (D3, 2026-11-10)` and this line:
   "Authority: diagnostic-records D3 synthesis Sections 1-3 and 5-7, accepted
   by the maintainer on [actual acceptance date]; pending lean core and atomic
   switch only. No shipped implementation is claimed."
   Link that amendment from P's record header with acceptance provenance.
   At R7, R8, R9, R10, Section 5, Section 6, Section 7 and the Section 8
   open-question paragraph add this exact local notice (link to the new
   appended heading): "Amended in pending lean-core scope by Amendment:
   terminal physical writes (D3, 2026-11-10). Per-pulse logical commitment
   remains; persistent writes and bounded expansion occur after the loop.
   Run-long record storage replaces the chunk-sized working-storage bound;
   checkpoint_every follows LR-20 and the D3 adapter/switch disposition."
   Keep original text as the superseded historical record. Apply D3-C's
   two exact ledger wording updates to L:31,39; retain LR-19 as accepted.
3. In I Section 19's status block, replace the R3 pending sentence
   (I:776-778) with: "Patched on 2026-11-10 with cut review R1, R2 and
   R4-R9; R3 is resolved by the accepted diagnostic-records D3 synthesis:
   per-pulse logical commitment in memory, followed by bounded terminal
   materialization. Acceptance provenance is recorded in that synthesis."
   Replace I:800-805, beginning "handler effects inside", with:

   > handler effects inside output_handler$run_transaction(). P4/P5 retain
   > per-pulse logical acceptance, sequence/time boundaries, committed extents
   > and leg visibility against the lean loop's owned in-memory records,
   > including P5's capacity refusal on its original pulse. P1/non-fill
   > publication keeps its own boundary. No persistent store write occurs
   > while pulses are processed. After loop exit, bounded terminal batches
   > consume only committed records inside that fold transaction; they do
   > not publish the run anew. Equity finalization and recovery remain the
   > pin's. The accepted diagnostic-records D3 synthesis governs memory,
   > stop/error prefixes and the checkpoint_every entry restriction.

   Replace **I Section 19.5 in full** with the following. This changes the
   transfer and commitment wording, not Section 19's accepted reconstruction
   experiment or the future durable codec:

   > ### 19.5 After the last pulse
   >
   > 1. Use the committed prefix selected during processing: every completed
   >    P5, any independently accepted P1/non-fill records, and E's installed
   >    INCOMPLETE stop evidence. No failed reservation or unprocessed pulse
   >    enters it. Keep the valued equity prefix and the distinct last-valued
   >    and last-executed clocks.
   > 2. For the current-format slice-1 experiment, expand diagnostics after
   >    the loop from Section 19's recorded exceptions, clean-fill indices,
   >    hold counts, pulse sequence offsets and reconciliation tuples, in
   >    bounded batches. Rebuild positions from the exact recorded book nets,
   >    never sums of fill deltas; preserve all fields, logical sequences,
   >    canonical JSON and the current implicit codec. This does not decide
   >    whether a future store omits hold rows or reconciliation evidence.
   >    A sweep candidate applies its existing keep rule before expansion;
   >    it builds only retained output and reserves the other logical positions.
   > 3. Materialize committed events, legs and diagnostics through terminal
   >    adapters to the pin's handler/writer. Each bounded batch transfers
   >    already committed records; no whole-run handler call replaces P4/P5
   >    acceptance or repeats their guards. Store rows are written exactly
   >    once, followed by current codec coverage/summary and, for a full_run
   >    exit, completion evidence, all within the existing fold transaction.
   >    No pulse-loop store write or persistent spill is allowed. The memory
   >    sink and workers perform no store write. Equity is returned to the
   >    pin's existing finalization; its transaction/recovery boundary stays.
   > 4. On an error discard the attempt's memory; durable fold writes,
   >    including any terminal batches, roll back. Retain the pin's original
   >    condition and post-rollback exception/FAILED handling (pulse time,
   >    stage, condition class/message and refreshed diagnostic sequence).
   >    Interrupts re-raise after rollback. Failed memory handlers are
   >    discarded, not reused. A normal INCOMPLETE stop instead materializes
   >    its accepted prefix and completion evidence. A max_pulses exit
   >    materializes its accepted prefix without completion evidence and
   >    follows the pin's nonterminal equity-prefix/return behavior.

   In I:931-932 replace "The other exit is an error, which discards the run
   (19.5)." with "Errors and interrupts discard the attempt under 19.5;
   max_pulses preserves its nonterminal prefix without completion evidence."
   In I Section 19.7 replace its first two bullets (I:976-979) with:

   > - that the in-memory owner enforces the per-pulse P4/P5 range, boundary,
   >   leg and capacity protocol, including refused pulses;
   > - that bounded terminal adapters transfer that prefix exactly once with
   >   identical current-format events, legs, diagnostics, coverage and summary,
   >   and that a batch fault rolls back every prior transfer in the fold.

   Keep the position-facts and strategy-state verification bullets. Add the
   Section 5 prefix/capacity/transfer witnesses and Section 2 capacity/peak
   observations to the owning ticket's evidence requirements; do not change
   its status, ordering or registered oracle as an acceptance side effect.
4. Replace the diagnostic-records RFC README row with this exact row, filling
   the acceptance date when it happens:

```text
| <a id="diagnostic-records"></a>Diagnostic records amendment (D3 terminal writes; other decisions open) | **Active; D3 obligations open** | [Seed v1](rfc_diagnostic_records_v0_2_3_seed.md) (Claude, 2026-11-09); [Type 2 response](rfc_diagnostic_records_v0_2_3_response.md) (Codex, 2026-11-09; probe paths are dev/spikes/diagnostic_records/type2_probe/); [D3 synthesis](rfc_diagnostic_records_v0_2_3_synthesis_d3.md) (Codex, 2026-11-10; maintainer acceptance [actual acceptance date]); [spike closeout](../../../dev/spikes/diagnostic_records/closeout.md) | Maintainer routing of Cut 13 R3 on 2026-11-10 substitutes for the D3 response review only. D3 Sections 1-3 bind no persistent writes during pulse processing, per-pulse in-memory logical commitment and bounded terminal materialization; Sections 5-7 route proof/installation to WS16 and the atomic switch, with tickets.yml taking ownership at cut. Independent Type 1 final-review disposition is linked here when available. D1, D2, D4-D7 and seed Section 4 remain revise before synthesis; their response review is still due. LDG-3219's sweep keep rule remains separately ticketed. No shipped behavior or codec change is claimed. |
```

   In the existing pulse-plumbing README row append: "D3's accepted
   [terminal-write amendment](rfc_diagnostic_records_v0_2_3_synthesis_d3.md)
   supersedes the in-loop chunk/working-storage clauses; per-pulse logical
   commitment remains. LR-19 and LR-20 are reconciled there."
   In `decisions.md`'s `lean-core-one-write-path` row append the same D3 link
   to its accepted source cell and append "Terminal physical writes and
   run-long capacity accounting under D3; awaiting WS16/switch" to its
   status cell. This keeps the accepted-obligation route discoverable without
   marking the unresolved diagnostic-records decisions accepted.
5. At the switch, consolidate only implemented rules into the stable
   [fold core](../contracts.md#contract-execution-fold-core),
   [event staging](../contracts.md#contract-execution-event-staging),
   [fold evidence](../contracts.md#contract-persistence-fold-evidence),
   [current format](../contracts.md#contract-persistence-current-format),
   [execution identity](../contracts.md#contract-execution-identity) and
   [telemetry/recovery](../contracts.md#contract-persistence-telemetry-and-recovery)
   groups. Acceptance installs pending authority and notices only. The frozen
   `R/` oracle, current store and historical evidence remain unchanged until
   their separately owned switch dispositions.
