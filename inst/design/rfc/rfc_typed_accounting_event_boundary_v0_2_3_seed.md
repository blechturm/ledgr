# RFC Seed: Typed Accounting Event Boundary for v0.2.3

- Status: Seed v1; Type 2 response is next
- Author: Codex
- Date: 2026-10-29
- Target window: v0.2.3, before WS7 and WS8 implementation
- Baseline reviewed: `269553ca`
- Evidence: typed-boundary probe `269553ca`; redundant-accounting spike
  `35adbc2a`

This RFC uses "first implementation" for this boundary, not ledgr 1.0. ledgr
is pre-CRAN and has no external stored research corpus requiring an old event
schema to execute. A deliberate format reset is allowed; silent drift is not.

## 1. Question and Boundary

What single typed representation should connect fold publication, durable
storage and chunked accounting replay after ledgr removes accounting-critical
JSON?

This seed binds the event carrier shared by WS7 and WS8. It does not change
fill timing, costs, lots, terminal policy, corporate-action entitlement,
strategy behavior, execution order, public result meanings or the optional
compiled-accounting envelope. It adds no event kind for futures, funding,
borrow, margin, FX or tax.

## 2. Executed Inputs

The package probe found that the memory output sink already retains typed
`cash_delta`, `position_delta`, replay facts and parsed metadata without
serializing JSON. The DuckDB sink instead persists eleven source columns with
`meta_json`; readers parse it back.

The field census covers every current producer and reader. Fill JSON is
redundant. Opening JSON is a discriminator plus values duplicated by `qty` and
`price`. Corporate-action cash and dispositions also carry real evidence:
source-fact and policy identities, entitlement inputs, valuation provenance,
late-arrival and terminal-policy decisions. Removing JSON may not remove that
evidence.

The storage fork compared one wide typed table with one common table plus
three evidence companions over 71,500 deterministic events and 32 fields.
Both round-tripped every cell. The wide table used 2,633,728 bytes versus
3,944,448; median writes were 0.11 versus 0.14 seconds and median reads were
0.05 seconds for both. These are bounded structural measurements, not a
database ranking. They give no reason to accept companion-table complexity.
Deleting `source_fact_id` changed 1,000 cells and the checker refused it.

The earlier redundant-accounting spike measured two separate costs. Sharing
one result replay reduced its complete three-result read from 9.36 to 4.45
seconds. A specialized fill-JSON encoder reduced the engine median from 24.36
to 21.84 seconds. Combined, the measured run-plus-results workflow moved from
33.72 to 26.37 seconds with exact outputs. The maintainer rejected the
specialized encoder as product direction: remove the redundant representation
rather than make it faster.

## 3. Proposed Decision

Use one ordered `ledger_events` table with common typed columns and nullable
type-specific evidence columns. Remove `meta_json` from that table. Keep one
prepared typed replay boundary for memory and DuckDB sources, and one replay
implementation. Public result projections stay outside replay.

Persist the exact signed `cash_delta` and `position_delta` published by the
fold. They are authoritative event effects even when derivable from other
columns. Replay must not recompute a possibly different value. Validation
reconciles them exactly against the event primitives and policy outcome.

Persist rare corporate-action and terminal evidence as nullable typed columns
in the same table. DuckDB compression and the executed storage fork make a
second schema unjustified. A later companion-table change needs measured
evidence on a real scale; it is not designed here.

## 4. Closed Event Vocabulary

The durable `event_type` vocabulary remains:

| type | source | meaning |
| --- | --- | --- |
| `FILL` | missing | one resolved execution fill |
| `CASHFLOW` | `opening_position` | initial lot and position seed |
| `CASHFLOW` | `corporate_action_cash` | one evidenced cash posting |
| `DISPOSITION` | `corporate_action_disposition` | scheduled evidenced terminal close |
| `DISPOSITION` | `lifetime_terminal_disposition` | lifetime terminal close |

Unknown types and sources refuse before append or replay. `source` is required
for `CASHFLOW` and `DISPOSITION` and missing for `FILL`. Internal operation
codes may optimize dispatch but are derived and never persisted.

This is one event vocabulary, not one table per event type and not a generic
key-value event system.

## 5. Durable Columns

The common columns remain:

```
event_id, run_id, ts_utc, event_type, instrument_id,
side, qty, price, fee, event_seq
```

The typed effect and discriminator columns are:

```
cash_delta, position_delta, source
```

The cash-evidence columns are:

```
source_fact_id, entitled_quantity, gross_cash_per_parent_unit,
amount_policy_id, posting_policy_id, late_arrival,
affected_marked_exposure
```

The disposition-evidence columns are:

```
terminal_event, matched_label, disposition_policy_id,
disposition_choice, disposition_basis, mark_source,
mark_source_ts_utc, mark_age, haircut_fraction,
position_before, realized_model_pnl
```

`source_fact_id` and `affected_marked_exposure` are shared by corporate-action
cash and dispositions. All other evidence columns are null outside their named
kind. Irrelevant non-null values refuse rather than being ignored.

The following current JSON values are not independent durable columns:

- fill `fee`, quantity, price and signed deltas already have typed columns;
- fill `realized_pnl` is null and replay produces realized facts;
- opening `opening_position` duplicates `source`, `position_delta` duplicates
  `qty`, `cost_basis` duplicates `price`, and `cash_delta` is zero;
- disposition `quantity` duplicates `qty`, `mark` duplicates `price`, and
  `position_after` is zero.

`event_realized`, `event_cost_basis`, close/open quantities and final lot state
remain replay outputs, not durable event inputs.

## 6. Per-Kind Validity and Arithmetic

All events require unique `event_id` and `event_seq`, a run, UTC timestamp,
known type, instrument and finite typed effects.

`FILL` requires `BUY` or `SELL`, positive finite quantity and price, and a
finite non-negative fee. Its effects equal the one
`ledgr_fill_publication_deltas()` computation over those resolved primitives.

Opening position requires finite nonzero `qty`, finite non-negative `price`,
zero fee and cash effect, and `position_delta == qty`. Its price is cost basis.

Corporate-action cash requires a non-empty source fact and policy IDs, finite
entitled quantity and gross cash per parent unit, a logical late-arrival flag,
zero position effect and the exact cash effect posted by settlement. The
entitlement inputs reconcile that effect without replacing it.

Disposition requires the existing source, source fact, policy, choice, basis
and mark evidence; positive `qty`, finite non-negative `price`, zero fee,
finite signed `position_before`, zero resulting position, and exact signed
effects. `qty == abs(position_before)`, `position_delta == -position_before`
and `cash_delta == position_before * price` at tolerance zero. Lifetime-only
labels are null for scheduled dispositions. `matched_label` and
`haircut_fraction` are nullable only when the chosen policy permits them.

Validation occurs once at the typed append/preparation boundary. It does not
build one-row data frames, parse JSON, or create a second vocabulary. The
canonical R arithmetic remains the executable oracle.

## 7. One Typed Replay Boundary

The shared prepared carrier is columnar and chunkable. It contains the common
columns, signed effects, closed evidence columns, stable instrument indexes and
derived operation codes. It contains no per-event metadata list.

Memory-backed sweeps hand typed columns directly to preparation. Durable
readers fetch typed columns in bounded blocks. Splitting one ordered stream at
any event must leave every replay fact and final state unchanged. Replay owns
lot transitions and event facts; projections own fills, trades, equity,
corporate-action summaries, terminal outcomes, resume state and printing.

WS7 first redirects every current reader through this typed prepared/replay
contract. While the old store still exists, it may use only the existing
preparer to decode current rows; it must not add another generic JSON layer.
WS8 then changes publication and storage to typed columns, removes the JSON
decode path and deletes superseded metadata helpers. There is no permanent
dual representation or fallback.

## 8. Persistence and Compatibility

The storage change increments `ledgr_experiment_store_schema_version` from the
current value at implementation. At baseline that successor is 125. It also
changes the store-format fingerprint and golden catalogue.

Older, missing-marker and differently fingerprinted stores refuse through the
existing classed store gate. There is no migration, compatibility reader,
missing-column inference or temporary JSON fallback. Maintainer datasets are
rebuilt and experiments rerun.

`meta_json` remains appropriate for configuration, provenance and interchange
outside accounting-critical event storage. This RFC does not declare JSON a
forbidden package-wide format.

## 9. Public Surface

Raw `ledger_events` storage remains internal. This RFC adds no public generic
event accessor and no user-defined event schema.

Existing fills, trades, equity, availability marks, corporate-action results,
terminal outcomes, summaries and print methods retain their values, names,
types, ordering and missingness unless a later ticket records a deliberate
correction. Typed evidence may be projected internally, but users do not need
to understand the storage layout.

Run, resume, sweep, promotion and walk-forward identity keep their economic
inputs. The format fingerprint and store schema identify the representation
change; accounting columns do not become configuration identity inputs.

## 10. Detecting Evidence

The ticket cut must carry gates that can fail:

1. a literal source-derived census of every event producer and consumer;
2. exact per-kind fixtures independently calculating typed effects and
   evidence, including partial close, reversal, opening, cash, both disposition
   sources, zero-price disposition, haircut and resume;
3. memory-versus-DuckDB prepared-block identity before replay;
4. one-block versus adversarially split chunk replay identity;
5. exact pre-cut/post-cut public tables and prints on unchanged semantics;
6. mutations for each required, forbidden and reconciliation field;
7. a structural detector that `ledger_events` has no `meta_json` and replay
   performs no accounting-event JSON encode or decode;
8. old-store refusal before read or write, with no migration path;
9. the seven optimization shapes on publication, preparation, replay and
   result readers; and
10. warm run, result-read, run-plus-results and peak-memory records, with
    no-regression gates and the redundant-accounting shape reported.

The performance record attributes encoding, persistence, preparation, replay
and projection separately. A speedup is welcome but cannot excuse changed
financial results or evidence loss. WS3 and WS9 own release-wide timing and
memory conclusions.

## 11. Rejected Alternatives

- Specialized fill-JSON encoder: optimizes a representation being removed.
- Generic typed key-value metadata: preserves the same parsing problem in a
  different format.
- One durable table per event type: adds joins and multiple ordering paths
  without measured benefit.
- Reconstruct policy evidence from snapshot facts later: weakens durable run
  evidence and resume behavior.
- Keep JSON beside typed columns: creates two authorities and reconciliation
  work.
- Migrate or infer old stores: contradicts the pre-CRAN compatibility policy.
- Fold replay into each result projection: recreates the duplicated-reader
  defect WS7 exists to remove.

## 12. Type 2 Questions

1. Is a persisted signed-effect pair the right authority, or should replay
   derive it despite the one-publication rule?
2. Does any inventoried rare field justify companion storage now?
3. Is any field classified as durable evidence actually reconstructible
   without weakening reopening, resume or a shipped result?
4. Are the required/nullable/forbidden rules complete for all five sources?
5. Does the WS7-then-WS8 sequence create avoidable temporary work or an unsafe
   intermediate state?
6. Can the public-result parity gate conceal a lost internal audit guarantee?
7. Which current reader or producer is missing from the census?
8. Is any proposed validation duplicated rather than owned once at the typed
   boundary?
9. Does this seed preserve enough room for later cross-asset event types
   without building their generic mechanism now?

## 13. Sequence

1. Type 2 response by an author other than this seed's author.
2. Response review and seed v2 if the architecture changes materially.
3. Maintainer decisions, synthesis and Type 1 final review.
4. Ticket cut: WS7 typed replay first, WS8 typed persistence second.
5. Rebuild affected stores once after the final identity-changing cut.
6. WS3 and WS9 record integrated runtime and memory.

This seed authorizes no product, contract, schema or ticket change.
