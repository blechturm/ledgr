# RFC Response: Typed Accounting Event Boundary for v0.2.3

- Status: Type 2 response v1; response review by Codex is next
- Author: Claude (not the seed author)
- Date: 2026-10-29
- Mode: Type 2, per the maintainer brief
- Seed reviewed: `rfc_typed_accounting_event_boundary_v0_2_3_seed.md` v1
- Baseline reviewed: `269553ca`; spikes `269553ca` and `35adbc2a`
- Budget: `spike_protocol.md` Section 4, 300 lines

## 1. Disposition

**ACCEPT_WITH_CHANGES.** One ordered wide typed `ledger_events` table, no
accounting-critical `meta_json`, one preparer and one replay, a store-format
bump with unconditional old-store refusal: this survives and is right. The
seed's census, its authority rule for `position_delta`, its validation
placement, its WS7 step and its public-surface claim do not survive as
written. Sections 3 to 5 list what the synthesis must bind differently. No
architectural alternative is proposed. A seed v2 is optional: it is cleaner
if the maintainer wants Section 3's census and the Section 4 authority rule as
binding text before synthesis; otherwise the synthesis can absorb this
response directly.

## 2. What the spikes established versus inference

| Claim | Evidence or inference |
| --- | --- |
| Fill JSON duplicates typed columns and exact arithmetic | Established by source: `backtest-runner.R:132-146`, `ledger-writer.R:93-100`, `accounting-replay.R:103-120`. |
| Cash and disposition rows carry non-duplicated evidence | Established by source: `corporate-action-settlement.R:573-585`, `:683-697`; `fold-engine.R:457-471`; `terminal-outcomes.R:187-198`. |
| The memory sink retains typed effects without JSON | Established for fills only (`output-handler.R:181-182`, `:561-572`). Inference, and wrong, for the other three kinds (Section 3, C1). |
| Both layouts round-trip 32 fields exactly; wide is smaller and not slower | Established on one synthetic shape, 70,000 fills and 1,500 other rows (`dev/spikes/typed-accounting-boundary/evidence/semantic.csv`). The 98 percent-null evidence columns on that mix are the reason the wide table compresses; a real ledger has the same mix. |
| Companion tables buy nothing worth joins | Inference from the fork, stated as such by the closeout. Accepted. |
| Shared replay 9.36 to 4.45 s; direct encoder 24.36 to 21.84 s | Established at `891c23c8`, before WS1 moved the fill payload into one handler. Directionally valid; absolute figures belong to the pre-WS1 tree. |
| JSON removal needs no second accounting model | Established: every replay already goes through one preparer (Section 3, C3). |

## 3. Factual and code corrections

**C1. The memory sink is not JSON-free.** Only fills skip serialization
(`backtest-runner.R:146`, `serialize_meta_json = FALSE`). Opening rows
(`fold-event-buffer.R:155-172`), cash rows
(`corporate-action-settlement.R:573-599`) and disposition rows
(`terminal-outcomes.R:187-213`) are serialized by their producers, parsed
back by a one-row `ledgr_prepare_accounting_events()` call before append
(`corporate-action-settlement.R:602`, `terminal-outcomes.R:214`), parsed
again by the memory sink's `append_event_rows()`
(`output-handler.R:714-735`), and parsed a third time by the preparer when
replayed (`accounting-replay.R:79-125`). Seed Section 2 should say: the
typed seam exists for fills; the other three kinds pay serialize-parse-parse
on both sinks.

**C2. Producer names are phantom.** `ledgr_fill_event()` and
`ledgr_event_buffer_stage_opening()` (inventory.md) do not exist. The
producers are `ledgr_fill_event_payload()` (`backtest-runner.R:103`),
`ledgr_write_fill_events()` for db_live (`ledger-writer.R:18`),
`ledgr_opening_position_event_rows()` (`fold-event-buffer.R:114`), the
settlement plan's `post_cash` (`corporate-action-settlement.R:545`),
`ledgr_disposition_post()` (`terminal-outcomes.R:126`) fed by two metadata
builders (scheduled, `corporate-action-settlement.R:683-697`; lifetime,
`fold-engine.R:457-471`), and the compiled batch
`append_compiled_spot_batch()` (`output-handler.R:738-785`, called at
`fold-engine.R:1336`).

**C3. Consumers missing from the census (seed Q7).**
`fold-reconstruction.R` (three preparer sites, `:11`, `:163`, `:212`, the
durable-sweep fallback and memory reconstruction); `walk-forward.R:1186`
(`ledgr_lot_state_asof()`, `lot-accounting.R:224-237`) and `:1227-1240`
(carried opening replay); `backtest-runner.R:1229-1242`
(`ledgr_state_asof()`); the headline closed-trade walk
`backtest-results.R:505-571`, a second event loop with its own cumulative
`position_delta` arithmetic and a `%||% 0` fallback; the public projection
`ledgr_results(bt, "ledger")`, which is `SELECT *` over the table
(`backtest-results.R:1262-1272`), printed by the metrics vignette
(`vignettes/metrics-and-accounting.qmd:200-205`) and referenced by 20 test
files; and `ledgr_corporate_action_result_events()`
(`corporate-action-results.R:115-135`) feeding two more metadata readers
(`:206`, `:252`) besides the summary reader at `:444`.

**C4. Three durable write paths, not one.** The DuckDB sink appends the
buffer (`output-handler.R:73-75`) and writes db_live fills through
`ledgr_write_fill_events()` (`:77-86`). The third,
`ledgr_write_opening_position_events()` (`backtest-runner.R:273-291`),
appends opening rows with `dbAppendTable()` from `run-resume.R:93`, bypassing
the handler. WS8's "changes publication" must name it; a typed column added
to the sink alone leaves the resume opening path writing the old shape.

**C5. `position_delta` is an authority nowhere today.** The fold derives
positions from lots (`fold-engine.R:1390-1393`); the replay derives them from
lots (`accounting-replay.R:311-315`) and reads `position_delta` only to
reconcile dispositions (`:222-234`). Two readers cumulate it instead: the
entitlement recount (`corporate-action-settlement.R:68-75`, with a FILL
fallback to signed quantity) and the headline walk (C3). `cash_delta` is the
replay's cash authority (`accounting-replay.R:297`).

**C6. Tolerances are mixed.** Disposition quantity, price and both deltas
reconcile at tolerance zero (`accounting-replay.R:226-229`);
`realized_model_pnl` reconciles at the kernel's dust tolerance
(`lot-accounting.R:476-480`). Seed Section 6 says "exact signed effects"
without naming which fields are zero-tolerance.

**C7. Fallbacks the seed must list for deletion, not inherit.** FILL rows
with empty or partial metadata derive their deltas (`accounting-replay.R:94-99`,
`:103-120`); `ledgr_terminal_outcome_rows()` derives the choice and basis
for "events recorded before choice and basis were persisted"
(`terminal-outcomes.R:283-291`), a missing-marker fallback AGENTS.md forbids;
the headline walk's `%||% 0`; `ledgr_lot_apply_opening()` returns the state
unchanged on a malformed opening (`lot-accounting.R:147-157`); the unsorted
ledger fallbacks (`corporate-action-settlement.R:119-135`,
`availability-results.R:427`, `accounting-replay.R:359-361`) replay a
timestamp order ledgr never writes.

**C8. The contract names `meta_json`.** `contract-execution-accounting-events`
(`contracts.md:362-370`) binds "the event's quantity and price equal those
recorded in its canonical `meta_json`" and "replay rejects a disposition
whose event fields disagree with that record". Seed Sections 8 and 9 amend
no contract rule group; the synthesis must restate that bullet on typed
columns and amend `contract-persistence-current-format` for schema 125.

**C9. Dead memory auxiliaries.** The attributes `ledgr_event_meta`,
`ledgr_event_realized` and `ledgr_event_cost_basis` and the sink columns
behind them have no reader outside `output-handler.R`; `event_realized` and
`event_cost_basis` are written per fill by `record_accounting_fact()`
(`:787-800`). Seed Section 7's "no per-event metadata list" should extend
to deleting all three.

**C10. Memory sweep candidates do not replay.** `inline_summary()`
(`output-handler.R:313-360`) builds equity and fills from live legs and
equity facts; the `typed_events()` replay (`sweep.R:1891-1900`) is the
durable-sweep fallback (horizon open-032). Seed Section 7's "memory-backed
sweeps hand typed columns directly to preparation" describes a path the
memory sink never takes, and the block-equality witness LTB-0020 compares a
buffer production never prepares. Either the typed carrier becomes the
memory candidate's result path too (one replay, slower) or the inline path
is named as the second, non-replay projection it is.

**C11. Minor.** The seed says "unique `event_id` and `event_seq`";
uniqueness of `event_seq` is per run (`UNIQUE(run_id, event_seq)`,
`db-schema-current.R:77-80`) and the preparer checks it per block only
(`accounting-replay.R:47-49`). Scheduled dispositions already persist no
`terminal_event` or `matched_label` (`corporate-action-settlement.R:683-697`)
although the resolver returns `matched_label = "default"`
(`terminal-outcomes.R:94`); the seed's null rule matches persistence, not the
resolver, and should say so.

## 4. Architectural objections and answers to the Type 2 questions

**Q1. Signed-effect authority.** Persist both columns `NOT NULL`, but
correct the rule. `cash_delta` is authoritative for replay cash, as today.
Positions stay lot-derived in the fold and the replay; `position_delta` is a
published effect reconciled at tolerance zero to its kind's formula (signed
`qty` for `FILL`, `qty` for opening, `0` for cash, `-position_before` for
`DISPOSITION`) and consumed by no position walk. The seed's "replay must not
recompute" is right for cash and wrong for positions: making `position_delta`
the position authority inverts the lot-authority rule (accounting-core
synthesis 3.2) and opens a dust divergence, because
`ledgr_lot_apply_fill()` snaps lot remainders at `ledgr_lot_dust_tolerance()`
(`lot-accounting.R:284-296`) while cumulative deltas never do. WS7 therefore
redirects the entitlement recount and the headline walk to the replay's
`position_after`, and deletes both cumulative-delta loops. Keeping the column
is still right: the compiled batch publishes it, the block witness compares
it, and the recount's resume contract (`contract-persistence-fold-evidence`)
is cheaper to prove on a stored column than on a derivation.

**Q2. Companion storage.** No. The fork and C3 agree. One addition: the
resume dedupe guard reads every row of the run to find fact IDs
(`corporate-action-settlement.R:12-21`, `:393-425`); with a typed
`source_fact_id` it reads `WHERE source_fact_id IS NOT NULL`. That is a WS8
consequence worth recording, not a layout argument.

**Q3. Reconstructible fields.** Three are derivable but should stay, each
with a stated reason the seed lacks: `gross_cash_per_parent_unit` duplicates
the sealed fact, and `entitled_quantity` duplicates the recount, but the
seed's own validation `cash_delta == entitled_quantity *
gross_cash_per_parent_unit` needs both in the row, and an event row should
validate without opening the snapshot. `position_before` and
`realized_model_pnl` are the fold's witnesses for the replay's reconciliation
(C6) and are the only durable record of the fold's realized figure for a
disposition. `affected_marked_exposure` is a diagnostic the summary sums
(`corporate-action-results.R:567-570`); reconstructing it means re-running
valuation, so keep it, labelled diagnostic. Demoting `cost_basis` to `price`
is correct (`fold-event-buffer.R:170`). Nothing else is removable.

**Q4. Required, nullable and forbidden rules: four gaps.**
(a) Opening `price`: the seed's "finite non-negative" refuses what
LTB-0020 registers as valid (basis 0 and -5,
`test-accounting-core-consolidation.R:148-158`). Tightening needs its own
reason and a test change needs a stated reason; see M2.
(b) Write-off provenance: a write-off records `mark_source = "write_off"`,
`mark_age = 0` and `mark_source_ts_utc` equal to the disposition pulse
(`terminal-outcomes.R:110-121`). Bind it, so a null mark source is never
admitted for a disposition.
(c) Ordering: `ledgr_accounting_positions_at_pairs()` and the timeline
reader assume `ts_utc` non-decreasing in `event_seq` order (C7). Bind it as
a typed-append invariant per run and delete the unsorted fallbacks.
(d) The `source` column: `NULL` for `FILL`, required otherwise; the compiled
batch publishes none (`output-handler.R:761`) and must publish `NULL`
explicitly. `instrument_id NOT NULL` is a tightening every producer already
satisfies.

**Q5. WS7-then-WS8.** The order is right and the macro plan binds WS4 before
both, but the seed hides WS7's temporary work. The current preparer exposes
evidence only as the parsed `meta` list (`accounting-replay.R:262`); the
corporate-action and terminal readers consume that list, and
`ledgr_lot_apply_event()` reads `meta` for openings and dispositions
(`lot-accounting.R:420-426`, `:447-485`). For WS7 to redirect those readers
to typed vectors while the store is still JSON, the preparer must extract
about eighteen evidence fields from the parsed metadata into typed vectors:
roughly forty lines written in WS7 and replaced in WS8 when the columns
arrive typed. That is acceptable only if WS7 also makes the changes that
survive: `ledgr_lot_apply_event()` takes typed scalars instead of `meta`;
`ledgr_corporate_action_event_meta()`, `ledgr_lot_parse_meta()` in the sink
and `prepared$meta` are deleted; the two cumulative-delta loops go (Q1); the
headline walk and `ledgr_terminal_outcome_rows()` read the carrier. The
unsafe state is not between WS7 and WS8; it is a WS7 that adds typed vectors
beside `meta` and leaves both, which is the dual authority seed Section 11
rejects. Whether WS7 and WS8 are one cut is M3.

**Q6. Can public parity hide a lost audit guarantee?** Yes, three ways.
`ledgr_results(bt, "ledger")` is public and changes shape (C3), so gate 5
as written cannot pass unchanged; M1 decides it. The resume double-credit and
duplicate-fact guards (`corporate-action-settlement.R:393-425`) and the
disposition reconciliation refusals (`accounting-replay.R:226-234`,
`lot-accounting.R:470-485`) have no public footprint; gate 6's mutation list
must name them (a duplicated `source_fact_id` on resume refuses; a
disposition whose `qty` or `price` disagrees with `position_before` or the
mark refuses; a `realized_model_pnl` outside dust tolerance refuses). The
INCOMPLETE `annualized_return` difference routed to WS7 (cut 1 decision 2)
must appear in gate 5 as a decided difference.

**Q7.** Answered in C2 to C4.

**Q8. Duplicated validation.** Yes, four places: producers via one-row
preparer calls (C1), the preparer's per-event loop
(`accounting-replay.R:146-242`), the kernel (`lot-accounting.R:245-256`,
`:447-458`, `:476-485`) and the headline walk. The seed's "once at the typed
append/preparation boundary" names two places. Bind: one vectorized
structural validator, a grouped sweep over a typed block, called by the
producers at append and by the preparer on read; arithmetic reconciliation
only in replay, where lots exist. Delete the one-row producer-side preparer
calls.

**Q9. Cross-asset room.** Adequate. A new source adds columns and a schema
bump; no generic mechanism. One caution: the seed should not name "cash
evidence" and "disposition evidence" column groups in the schema; the groups
are prose, the schema is flat.

**Chunk gate.** LTB-0021 splits a fills-only stream
(`test-accounting-core-consolidation.R:162-209`). Gate 4 must split between
a cash row and its disposition, inside an opening block, and before a
disposition whose `position_before` the previous block built.

## 5. What survives, changes, is rejected

Survives: one wide typed table, the closed vocabulary (seed Section 4), the
column list (Section 5) less C11, exact zero-tolerance reconciliation for
quantities, prices and deltas, one chunkable prepared carrier, schema 125
with unconditional refusal, the ten gates, Section 11's rejections.

Changes: the census (C2 to C4); the authority rule (Q1); C6's tolerance
statement; C7's deletion list; C8's contract amendments; C9's auxiliaries;
C10's memory path; Q4's four rules; Q5's WS7 content; Q6's mutation list;
Q8's validator placement; the chunk gate.

Rejected: `position_delta` as the position authority; "validation once" at
two places; a WS7 that leaves `meta` beside typed vectors; opening
`price >= 0` without a reason; byte-identity of every public table as a
claim that includes the ledger projection.

## 6. Maintainer decisions

**M1. `ledgr_results(bt, "ledger")` after the change.** (a) keep `SELECT *`,
so users see the wide typed row with nulls; (b) project the ten common
columns plus `cash_delta`, `position_delta` and `source`; (c) remove the
table. Recommend (a): the vignette calls it the most literal view, and a
wide row with nulls is that view. Consequence: the metrics vignette's printed
ledger changes and the 20 test files that read it follow.

**M2. Opening cost basis sign.** Keep admitting zero and negative basis as
LTB-0020 registers, or tighten to non-negative as the seed writes. Recommend
keep; no economic rule refuses a negative basis today and the change would
rewrite a registered oracle.

**M3. One cut or two.** The macro plan places WS7 in Phase C and WS8 in
Phase D. Recommend one cut with the two workstreams in order and one store
rebuild, because a WS7 cut that ships alone leaves typed replay beside JSON
evidence columns for a release-ready state. This is a macro-plan change and
is the maintainer's.

**M4. Memory candidate results.** Keep `inline_summary()` as the memory
sink's result path (fast, no replay) and name it, or route memory candidates
through the typed carrier for one replay everywhere. Recommend keep and
name; C10 shows the parity witness then needs a production caller.

## 7. Left to the ticket cut

DuckDB column types per the inventory CSV and whether kind rules are DuckDB
`CHECK` constraints or R validation; the validator's shape; fixture list;
golden-catalogue update; NEWS; the 44 test files that mention `meta_json`
and the 20 that read the ledger projection; the compiled batch's `source`
column; the resume opening path's typed append (C4); the dedupe guard's typed
query (Q2).
