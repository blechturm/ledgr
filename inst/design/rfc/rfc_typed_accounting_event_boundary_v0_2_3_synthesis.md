# Synthesis: Typed Accounting Event Boundary For v0.2.3

Role: record; decision synthesis, binding in its stated scope once accepted.
Status: accepted by the maintainer on 2026-10-29 after final review
PASS_AFTER_PATCHES (Codex) and in-place patches P1 to P5.
Mode: Decision synthesis. Author: Claude (response author; author of neither
seed). Date: 2026-10-29.
Final review: `rfc_typed_accounting_event_boundary_v0_2_3_final_review.md`.
Brief: drafted by the synthesis author, not the maintainer, from the Codex
handoff of 2026-10-29. Question: bind the typed accounting event carrier for
WS7 and WS8 from seed v2, the Type 2 response and its review, and record what
is rejected. The maintainer reread and accepted the brief and synthesis
together on 2026-10-29.
Baseline: `269553ca`. Inputs: seed v1, response v1, response review, seed v2
(with the maintainer decisions of 2026-10-29 in its Section 3), the
accounting-core synthesis, `contracts.md`, the v0.2.3 macro plan, AGENTS.md
and the optimization coding style.

## 1. Corrections The Synthesis Author Owes

The response review's six corrections to the response hold against the tree
and are bound here as the review states them.

1. The memory attributes `ledgr_event_meta`, `ledgr_event_realized` and
   `ledgr_event_cost_basis` are product-dead, not repository-dead: five test
   files and `dev/bench/v0_2_3_output_freeze/lib.R` read them. They are
   deleted, and those consumers migrate (3.5).
2. The storage fork's 98 percent-null evidence mix is one fill-heavy shape,
   not a property of every ledger. The wide table is bound as the smallest
   measured candidate, not as a law (3.1, Section 9).
3. Validation runs at two trust boundaries with one vocabulary (3.4).
4. Resume dedupe reads `source` and `source_fact_id` together (3.4).
5. No file counts are pinned; the cut's census is a checked-in literal.
6. `position_delta` is kept as a publication witness, a compiled parity field
   and an event-shape reconciliation input, never as a position source (3.2).

Seed v2's own load-bearing claims resolve: three durable write paths
(`output-handler.R:73-86`, `backtest-runner.R:273-291` via
`run-resume.R:93`); the three parses per non-fill event
(`corporate-action-settlement.R:602`, `terminal-outcomes.R:214`,
`output-handler.R:725`, `accounting-replay.R:79-125`); LTB-0020 registers
opening bases 0 and -5 as valid
(`test-accounting-core-consolidation.R:148-158`); `inline_summary()` is the
memory candidate's production path (`output-handler.R:313-360`,
`sweep.R:1884-1900`).

## 2. Decision

Accept seed v2 with its four maintainer decisions and the corrections above.
No third seed; no prerequisite spike. The scope is the event carrier shared
by WS7 and WS8 and nothing else: fill timing, costs, the lot kernel, terminal
and corporate-action policy, strategy behavior, execution order and the
compiled envelope are unchanged.

Bound: one ordered wide typed `ledger_events` table with no `meta_json`;
`cash_delta` as the replay's cash authority and canonical lots as the only
position authority; a per-kind field matrix (3.3); one vectorized validator
invoked at append and at read, with lot-dependent reconciliation in replay;
one prepared typed carrier and one replay for every durable and
reconstruction reader, with `inline_summary()` as the one named live
projection; one cut, WS7 then WS8, one store rebuild; schema 125 with
unconditional refusal of every older store.

**Identity (macro plan rule 5).** Snapshot content identity: none. Run
configuration identity: none; accounting columns are not configuration
inputs and no policy identity changes. Store format fingerprint: changes,
through `ledgr_experiment_store_schema_version` 125 and the DDL catalogue.
**Release impact (rule 6):** product tests; documentation (`ledgr_results()`
roxygen for `what = "ledger"`, the metrics vignette's ledger chunk);
schema/identity; performance records; one `NEWS.md` entry. Package
dependency changes: none; the sequencing dependency on WS4 is D7.

## 3. Bound Architecture

### 3.1 The logical ledger and its DDL

`ledger_events` keeps the ten common columns `event_id`, `run_id`,
`ts_utc`, `event_type`, `instrument_id`, `side`, `qty`, `price`, `fee`,
`event_seq`; adds `cash_delta DOUBLE NOT NULL`, `position_delta DOUBLE NOT
NULL` and `source VARCHAR`; adds the seven corporate-cash and eleven
disposition evidence columns of seed v2 Section 5 with the DuckDB types in
`dev/spikes/typed-accounting-boundary/event_field_inventory.csv`
(`typed_candidate`), except that `cost_basis` is not a column. `meta_json` is
removed. `instrument_id` and `fee` become `NOT NULL`. The existing
`CHECK` on `event_type` and `side` and `UNIQUE(run_id, event_seq)` stay; one
`CHECK` on the four `source` tokens is added. Per-kind rules are R validator
rules, not DuckDB constraints: DuckDB `CHECK` passes nulls, the store contract
forbids proving constraints by writing probe rows, and the catalogue
fingerprint already pins the DDL. The physical layout is one table; a
companion layout needs contrary evidence at a real scale (Section 9).

### 3.2 Authorities

The fold applies lots and derives positions from them
(`fold-engine.R:1349-1393`); the replay does the same
(`accounting-replay.R:296-328`). That does not change. `cash_delta` is what
replay adds to cash. `position_delta` is persisted exact and consumed by no
position walk: the entitlement recount (`corporate-action-settlement.R:35-140`)
and the headline closed-trade walk (`backtest-results.R:505-571`) are
redirected to replayed `position_after`, and both cumulative loops are
deleted. The `FILL` fallback that derives deltas from an empty payload
(`accounting-replay.R:94-99`, `:103-120`) goes with them.

### 3.3 Per-kind field matrix

`req` is required non-null; `null` is required null; a formula is required
at tolerance zero unless stated. Scheduled is `corporate_action_disposition`;
lifetime is `lifetime_terminal_disposition`.

| field | FILL | opening | corporate cash | scheduled | lifetime |
| --- | --- | --- | --- | --- | --- |
| `side` | `BUY`/`SELL` | null | null | null | null |
| `qty` | req, > 0 | req, != 0, signed | null | req, > 0 | req, > 0 |
| `price` | req, > 0 | req, finite, any sign | null | req, > 0 | req, >= 0 |
| `fee` | req, >= 0 | 0 | 0 | 0 | 0 |
| `cash_delta` | `ledgr_fill_publication_deltas()` | 0 | `entitled_quantity * gross_cash_per_parent_unit` | `position_before * price` | same |
| `position_delta` | signed `qty` | `qty` | 0 | `-position_before` | same |
| `source` | null | `opening_position` | `corporate_action_cash` | scheduled | lifetime |
| `source_fact_id` | null | null | req | req | req |
| `entitled_quantity`, `gross_cash_per_parent_unit`, `amount_policy_id`, `posting_policy_id`, `late_arrival` | null | null | req | null | null |
| `affected_marked_exposure` | null | null | req (0 without a mark) | req | req |
| `terminal_event`, `matched_label` | null | null | null | null | req, non-empty |
| `disposition_policy_id`, `disposition_choice`, `disposition_basis`, `mark_source`, `mark_source_ts_utc`, `mark_age`, `position_before`, `realized_model_pnl` | null | null | null | req | req |
| `haircut_fraction` | null | null | null | null | req iff choice is `haircut`, else null |

Further rules. `qty == abs(position_before)` for both dispositions.
`realized_model_pnl` reconciles in replay at `ledgr_lot_dust_tolerance()`
(`lot-accounting.R:476-480`), not at zero. A write-off records `mark_source =
"write_off"`, `mark_age = 0` and the disposition pulse as `mark_source_ts_utc`
(`terminal-outcomes.R:110-121`). A scheduled disposition's price is strictly
positive: the scheduled resolver posts only on a finite positive mark
(`terminal-outcomes.R:84-90`); only a lifetime disposition may persist zero,
through write-off (`terminal-outcomes.R:45-48`). Scheduled
`disposition_basis` is `evidence` and its choice is `last_permissible` or
`last_mark`; lifetime basis is `label`, `default` or `frozen_fallback` and
its persisted choice is `last_permissible`, `last_mark`, `haircut` or
`write_off`, since `refuse` posts no event (`corporate-action-policy.R:65-69`,
`terminal-outcomes.R:34-49`). Required text fields are non-empty:
`source_fact_id`, the policy identifiers, `mark_source`, and on lifetime rows
`terminal_event` and `matched_label`. `affected_marked_exposure` is finite
and non-negative; `mark_source_ts_utc` is a valid UTC timestamp; `mark_age`
is a non-negative integer. Opening `price` keeps any finite value
(maintainer decision 2).

Ordering carries across blocks. The validator takes the prior block's last
`event_seq` and `ts_utc` at both boundaries: within a block `event_seq`
strictly increases and `ts_utc` never decreases; a later block, whether
appended or fetched, begins with a strictly greater sequence and a timestamp
no earlier than the prior block's last. `event_seq` is unique per run. Any
other type, source or non-null irrelevant field refuses.

### 3.4 One validator, two boundaries; reconciliation in replay

One vectorized, grouped validator owns 3.3 as a sweep over a typed block:
grouped by kind, no per-event loop, no one-row frames. Every producer calls
it on its block before append; the preparer calls it on every fetched block
before replay. The one-row preparer calls at `corporate-action-settlement.R:602`
and `terminal-outcomes.R:214` are deleted. The lot kernel keeps its input
checks; `ledgr_lot_apply_event()` takes typed scalars (`qty` and `cost_basis`
for an opening; `position_before`, `price` and `realized_model_pnl` for a
disposition) and reads no list. The replay owns every lot-dependent check:
a disposition must consume the position and every live lot
(`lot-accounting.R:468-475`) and match `realized_model_pnl` at dust tolerance.

Deleted fallbacks: the terminal-choice inference at
`terminal-outcomes.R:283-291`; the headline `%||% 0`; the silent return of
`ledgr_lot_apply_opening()` on a malformed opening (`lot-accounting.R:147-157`),
which becomes a refusal; the unsorted-ledger branches at
`corporate-action-settlement.R:119-135`, `availability-results.R:427` and
`accounting-replay.R:359-361`. Resume dedupe reads `source` and
`source_fact_id` for the run where `source_fact_id IS NOT NULL`, refuses a
fact repeated within a posting source and a fact posted as both cash and
disposition; it reads no fill rows.

### 3.5 Carrier, readers and the memory exception

The prepared carrier is the ten common columns, the two effects, `source`,
the evidence columns, `instrument_index`, `instrument_ids` and derived
`operation` codes. It has no `meta` list and no event attributes. The memory
sink drops its `meta`, `event_realized` and `event_cost_basis` columns and
the three attributes; `record_accounting_fact()` keeps leg staging only; the
compiled batch publishes typed effects and `source = NULL`, the handler stops
storing its realized and basis vectors, and the compiled parity witness
compares typed effect columns and leg fees instead of JSON bytes. The five
test files and the A0 harness library that read the attributes migrate to
the carrier or to public results.

Every durable or reconstruction reader that derives accounting state or an
accounting-semantic projection goes through the preparer and the replay:
`backtest-fills.R:121-166` (chunked), `fold-reconstruction.R:11`,
`:163`, `:212`, `run-finalize.R:526-528`, `derived-state.R:120-121`,
`availability-results.R:396-397`, `:428-429`, `run-store.R:391-392`,
`backtest-runner.R:1241-1242`, `lot-accounting.R:220-221`,
`walk-forward.R:1186`, `:1237-1240`, and the corporate-action and terminal
readers at `corporate-action-results.R:206`, `:252`, `:444-461`, which
consume evidence columns from the carrier. Projections own fills, trades,
equity, summaries, terminal outcomes, resume state and printing; none owns an
event loop. A projection may subset carrier vectors. Splitting one ordered
stream at any event leaves every replay fact and the final state unchanged.
Exempt, because they derive no cash, positions, lots, realized PnL or
trades: the raw ledger projection (3.7), the typed dedupe query (3.4), and
the identity, order and cleanup queries for the next sequence
(`ledger-writer.R:105-109`, `run-resume.R:82-86`), the last executed fill
(`backtest-runner.R:1059-1063`) and the resume tail delete
(`run-resume.R:72-78`). They read typed primitives directly and never replay.

`inline_summary()` (`output-handler.R:313-360`) remains the memory
candidate's result path (maintainer decision 4). It is a live projection of
fill legs and equity facts the fold already computed, not a replay. Its
parity against the durable path on the supported candidate shapes is a
registered claim, and a detector proves production still calls it.

### 3.6 Producers and write paths

Producers publish typed columns directly: `ledgr_fill_event_payload()`
(`backtest-runner.R:103`) and `ledgr_write_fill_events()`
(`ledger-writer.R:18`) through `ledgr_fill_publication_deltas()`;
`ledgr_opening_position_event_rows()` (`fold-event-buffer.R:114`); the
settlement plan's `post_cash` (`corporate-action-settlement.R:545`);
`ledgr_disposition_post()` (`terminal-outcomes.R:126`) from the scheduled
and lifetime builders (`corporate-action-settlement.R:683-697`,
`fold-engine.R:457-471`); `append_compiled_spot_batch()`
(`output-handler.R:738`). All three durable write paths publish the typed
schema: the sink append and db_live insert, and the resume opening append at
`backtest-runner.R:273-291`. `canonical_json()` and `ledgr_json_read_nested()`
stay for configuration, provenance and interchange; no accounting event is
encoded or decoded as JSON anywhere.

### 3.7 Persistence, contracts and public surface

`ledgr_experiment_store_schema_version` becomes 125 at implementation (the
successor of the reviewed baseline's 124). The store gate refuses every
older, unmarked or fingerprint-mismatched store with
`ledgr_store_rebuild_required`; no migration, reader or inference exists.
`contract-execution-accounting-events` is restated on typed fields: a
disposition's quantity, price and effects equal the typed row's
`position_before`, mark and evidence, and replay rejects disagreement.
`contract-persistence-current-format` names schema 125 and the removed
column. `ledgr_results(bt, "ledger")` stays `SELECT *` and deliberately
returns the wide typed row (maintainer decision 1); its roxygen and the
metrics vignette say so. Every other public table, print and summary keeps
its values, names, types, order and missingness, except the INCOMPLETE
`annualized_return` correction already owned by WS7.

## 4. Decisions Resolved

**D1 to D4.** The maintainer's four decisions of 2026-10-29 (seed v2
Section 3): `SELECT *` ledger; any finite opening basis; one ordered cut with
one rebuild; `inline_summary()` retained and named.

**D5. Kind rules live in R.** Per 3.1; DuckDB keeps vocabulary `CHECK`s and
the uniqueness constraint only.

**D6. WS7's temporary extraction is permitted and bounded.** WS7 may extract
evidence fields from the parsed payload into typed vectors so readers reach
the carrier before storage changes; the extraction is deleted in WS8 of the
same cut, and WS7 may not leave `prepared$meta` or a metadata parser beside
the vectors.

**D7. Macro-plan placement.** Decision 3 moves WS8 from Phase D into WS7's
cut; the cut still opens after WS4 (binding edge WS4 to WS7). Acceptance
records the amendment in the macro plan.

**D8. The compiled envelope is untouched.** Only the handler's storage of
its output changes; `spot_fifo.cpp` and the dispatch guard are not edited.

## 5. Workstream And Tickets

One cut, two workstreams, one Type 1 review each, in this order.

WS7, one result reader:
1. the carrier and the validator (3.3, 3.4), with the temporary extraction of
   D6 and the typed-scalar `ledgr_lot_apply_event()`;
2. redirection of every reader in 3.5 and deletion of the two position walks,
   the one-row preparer calls, the fallbacks and the sink auxiliaries;
3. the chunk, block-equality and parity claims of Section 6, including the
   `inline_summary()` parity and detector; the INCOMPLETE `annualized_return`
   correction.

WS8, typed persistence:
4. DDL, schema 125, catalogue and fingerprint, store refusal;
5. typed publication on all producers and all three write paths, removal of
   the extraction and of every accounting JSON encode or decode, the typed
   dedupe query;
6. contract amendments, `ledgr_results()` roxygen, vignette, `NEWS.md`;
7. the performance record and the seven-shape review; one store rebuild.

## 6. Evidence Before Old Paths Leave

1. A checked-in literal census of producers, writers, readers, tests and
   docs that reference accounting event columns, derived from source.
2. Independently calculated typed fixtures per kind: partial close, reversal,
   opening with zero and negative basis, corporate cash with and without a
   mark, scheduled and lifetime dispositions, a zero-price write-off on the
   lifetime arm, haircut, resume.
3. Block equality: the prepared carrier from the memory sink and from DuckDB
   is `identical()` before replay, as a failure-sensitive boundary fixture.
   Production-caller detectors cover `inline_summary()` and the durable
   preparer separately; the memory-preparation arm needs none (D4).
4. Chunk identity: one block versus splits inside an opening block, between
   a cash row and its disposition, before a disposition whose
   `position_before` the previous block built, immediately before a
   duplicate sequence and immediately before a decreasing timestamp, so that
   removing the carried boundary state fails.
5. Public parity: every public table and print byte-identical to the A0
   records and the frozen v0.2.2 reference, except the ledger shape and the
   INCOMPLETE `annualized_return` correction, each recorded.
6. Mutations that must fail: each required, null and formula cell of 3.3;
   a zero-price scheduled disposition; an empty `source_fact_id`, policy
   identifier, `mark_source`, `terminal_event` or `matched_label`; a negative
   `affected_marked_exposure`; an invalid `mark_source_ts_utc` or negative
   `mark_age`; a repeated `source_fact_id` within a posting source on resume;
   a fact posted as cash and as disposition; a disposition whose `qty` or
   `price` disagrees with `position_before` or the mark; `realized_model_pnl`
   outside dust tolerance; an appended or fetched block that repeats a
   sequence or is older than the prior block's last event.
7. Structural detectors: no `ledger_events.meta_json`; no accounting JSON
   encode or decode; no `meta` list; no cumulative position walk; no
   unsorted fallback; the validator called at both boundaries.
8. Old-store refusal before any read or write; no migration path.
9. `inline_summary()` production use and parity against the durable path.
10. The seven optimization shapes on publication, validation, preparation,
    replay and projection.
11. Attributed warm run, result read, run-plus-results and peak-memory
    records against the pre-cut tree, with no-regression gates; WS3 and WS9
    own release-wide conclusions.

## 7. Rejected, One Line Each

- A specialized fill-JSON encoder: optimizes a representation being removed.
- Typed key-value metadata: the same parsing problem in another format.
- One table per kind, or companions now: no measured benefit; joins and two
  ordering paths.
- JSON beside typed columns, or a WS7 that keeps `meta` beside vectors: two
  authorities.
- `position_delta` as position authority: inverts the lot rule and opens a
  dust divergence.
- Dropping `position_delta`: loses the publication witness and the compiled
  parity field for eight bytes a row.
- Validation only at append, or only in replay: one boundary unguarded.
- Dedupe on a non-null fact ID alone: loses the cash-versus-disposition
  distinction.
- Reconstructing evidence from the snapshot: weakens run evidence and
  resume.
- Tightening opening basis to non-negative: an economic decision with no
  stated reason; it would rewrite LTB-0020.
- Migrating, inferring or reading old stores: pre-CRAN policy.
- Replay inside projections, or a memory replay replacing
  `inline_summary()`: the duplicated-reader defect, or a slower path for no
  gain.

## 8. Open Questions Promoted To Spec-Cut

- The validator's function name and whether the preparer calls it before or
  after instrument indexing.
- The `LTB` prefixes and test profiles of each Section 6 claim.
- The exact `NEWS.md` wording and the vignette prose for the wide ledger.
- Which A0 attachment points migrate from the attributes to the carrier.

## 9. Future Obligations And Speculative Deferrals

Obligations (RFC pipeline): a later event kind or source for another asset
class adds typed fields, vocabulary entries and a schema reset through its
own focused RFC; the compiled-execution-envelope obligation is unchanged and
consumes the typed carrier. Speculative (horizon): a physical companion
layout, reopened only by contrary evidence at a real corporate-action-heavy
scale; it would not change the logical carrier.

## 10. Failure Scenarios

| Scenario | Bound behaviour | Failure of this design |
| --- | --- | --- |
| Producer publishes a wrong effect | the validator refuses at append | the row is durable and replay trusts it |
| Store row edited by hand | the validator refuses at read | a projection reads it |
| Disposition drifts from its lots | replay refuses in the kernel | positions and cash disagree silently |
| Chunk boundary inside a disposition pair | state threads across blocks | `position_before` reconciles against an empty prior block |
| Duplicate sequence or decreasing time at a fetch boundary | the carried boundary state refuses | a block-local check lets it through |
| Resume after a cash posting | typed dedupe refuses the repeat | double credit |
| Memory and DuckDB diverge | block equality fails before replay | the bug sits in the shared validator |
| Old store opened | `ledgr_store_rebuild_required` | a column is inferred |
| Headline count disagrees with trades | impossible: one replay | a second walk returns |
| Compiled batch publishes no `source` | explicit null, parity on typed columns | JSON parity re-enters |

## 11. Release Boundary And Final Review

This synthesis binds the WS7 and WS8 cut of v0.2.3 and nothing else. No code,
test, ticket, schema, contract or macro-plan change is authorized before
maintainer acceptance; acceptance routes Section 9, amends the macro plan per
D7 and updates `decisions.md`.

Final review is Type 1: every citation in Sections 1 and 3 resolves at the
baseline; the matrix in 3.3 matches every producer's current output; no
reader in 3.5 is missing from the census; the validator is one function at
two boundaries; no ticket derives positions from `position_delta`; the
identity and release-impact statements in Section 2 are complete; the
rejected list in Section 7 contains no decision the synthesis also binds.
A design finding returns `NEEDS_TYPE_2`.

## Revision History

- 2026-10-29 - Accepted by the maintainer after rereading the author-drafted
  brief and the patched synthesis together. Acceptance authorizes only the
  Section 11 routing; implementation remains owned by the ticket cut.
- 2026-10-29 - Type 1 final-review patches (Codex, PASS_AFTER_PATCHES),
  applied in place by the synthesis author after checking each citation:
  P1 scheduled dispositions require a positive price, only a lifetime
  write-off persists zero (3.3, Section 6 items 2 and 6); P2 the lifetime
  choice vocabulary and the non-empty, finite and valid-time rules for
  evidence fields (3.3, item 6); P3 ordering state carried across appended
  and fetched blocks (3.3, items 4 and 6, Section 10); P4 no production
  caller required for the memory-preparation arm (item 3); P5 the replay
  rule limited to accounting-semantic readers, with the raw ledger, typed
  dedupe and bookkeeping queries exempt (3.5), and the dependency wording in
  Section 2. No decision changed.
- 2026-10-29 - Synthesis by Claude from seed v2, the Type 2 response and its
  review, under an author-drafted brief; provisional until maintainer
  rereading. No decision departs from seed v2; D5 to D8 are synthesis
  choices that v2 left open or implied.
