# RFC Seed v2: Typed Accounting Event Boundary for v0.2.3

- Status: Seed v2; decision synthesis by an author other than Codex is next
- Author: Codex
- Date: 2026-10-29
- Target window: v0.2.3, before WS7 and WS8 implementation
- Baseline reviewed: `269553ca`
- Evidence: typed-boundary probe `269553ca`; redundant-accounting spike
  `35adbc2a`
- Prior stages: seed v1; Type 2 response v1; Codex response review

This RFC uses "first implementation" for this boundary, not ledgr 1.0. ledgr
is pre-CRAN and has no external stored research corpus requiring an old event
schema to execute. A deliberate format reset is allowed; silent drift is not.

## 1. Question and Boundary

What single typed representation should connect fold publication, durable
storage and chunked accounting replay after ledgr removes accounting-critical
JSON?

This seed binds the event carrier shared by WS7 and WS8. It does not change
fill timing, costs, lots, terminal policy, corporate-action entitlement,
strategy behavior, execution order or the optional compiled-accounting
envelope. It adds no event kind for futures, funding, borrow, margin, FX or
tax.

## 2. Executed Inputs and Corrections

The typed seam exists today for memory-sink fills. Opening, corporate cash and
disposition producers still serialize JSON; their rows are parsed before
append, parsed by the sink and parsed again for replay. The DuckDB sink also
persists `meta_json`. The redesign removes this representation rather than
optimizing its encoder.

The field census covers the real producers, including db-live fills, buffered
opening rows, corporate cash, both disposition sources, the compiled batch and
the resume-opening direct append. The consumer cut must also cover fold
reconstruction, state-as-of, walk-forward carry, the headline closed-trade
walk, corporate-action and terminal reporting and the public ledger result.
The ticket-cut census is a checked-in literal derived from source; this seed
does not freeze guessed file counts.

The storage fork compared one wide table with one common table plus evidence
companions over 71,500 deterministic, fill-heavy events and 32 fields. Both
round-tripped every cell. Wide used 2,633,728 bytes versus 3,944,448; median
writes were 0.11 versus 0.14 seconds and median reads 0.05 seconds for both.
This establishes the smallest candidate for that measured shape, not a law
for every future event mix. Removing `source_fact_id` changed 1,000 cells and
the checker refused it.

The redundant-accounting spike measured shared result replay at 9.36 to 4.45
seconds and a specialized fill encoder at 24.36 to 21.84 seconds on its
pre-WS1 tree. The maintainer rejected the encoder direction: eliminate the
redundant representation.

## 3. Maintainer Decisions, 2026-10-29

1. `ledgr_results(bt, "ledger")` remains `SELECT *`. Its deliberately changed
   public shape is the complete wide typed row; other result tables remain
   stable unless a ticket records a decided correction.
2. Opening cost basis preserves every finite value, including zero and
   negative values registered by LTB-0020.
3. WS7 and WS8 form one cut, ordered reader consolidation then typed
   persistence, with one store rebuild after the identity-changing work.
4. The memory candidate keeps the fast `inline_summary()` path. It is a named
   live projection, not another durable replay, and requires parity evidence
   and a production-caller detector.

## 4. Bound Architecture and Authorities

Use one ordered, wide `ledger_events` table with common typed columns and
nullable type-specific evidence columns. Remove `meta_json` from that table.
Use one prepared typed replay carrier and one canonical replay for durable and
reconstruction readers. Do not retain a parsed metadata list beside it.

`cash_delta` is the replay cash authority. Positions remain derived from the
canonical lot state in fold and replay. `position_delta` is persisted `NOT
NULL` as an exactly reconciled publication witness, compiled-path parity field
and event-shape check; it is not position-state authority. All cumulative
position walks outside canonical replay are deleted. `position_after` comes
only from replayed lots.

Rare corporate-action and terminal evidence stays in nullable typed columns.
It makes an event independently auditable without reopening the snapshot.
`affected_marked_exposure` is retained as a diagnostic. A later physical
companion layout needs contrary scale evidence; it does not change this typed
logical carrier.

## 5. Vocabulary and Durable Fields

The closed event vocabulary remains:

| event type | source | meaning |
| --- | --- | --- |
| `FILL` | missing | one resolved execution fill |
| `CASHFLOW` | `opening_position` | initial lot and position seed |
| `CASHFLOW` | `corporate_action_cash` | one evidenced cash posting |
| `DISPOSITION` | `corporate_action_disposition` | scheduled terminal close |
| `DISPOSITION` | `lifetime_terminal_disposition` | lifetime terminal close |

Unknown combinations refuse. `source` is explicitly missing for `FILL` and
required otherwise. Operation codes may optimize dispatch but are derived and
not persisted. `event_seq` uniqueness is per run.

Common columns:

```
event_id, run_id, ts_utc, event_type, instrument_id,
side, qty, price, fee, event_seq
```

Effects and discriminator:

```
cash_delta, position_delta, source
```

Corporate-cash evidence:

```
source_fact_id, entitled_quantity, gross_cash_per_parent_unit,
amount_policy_id, posting_policy_id, late_arrival,
affected_marked_exposure
```

Disposition evidence:

```
terminal_event, matched_label, disposition_policy_id,
disposition_choice, disposition_basis, mark_source,
mark_source_ts_utc, mark_age, haircut_fraction,
position_before, realized_model_pnl
```

`source_fact_id` and `affected_marked_exposure` are shared where applicable.
Irrelevant non-null fields refuse. Quantity, mark, cost basis, signed effects
and position-after values are not duplicated inside a second payload.

## 6. Kind Rules and Arithmetic

All events require a run, UTC timestamp, known type and source combination,
instrument, unique event identity and sequence within the run, and finite
typed effects. Event time is non-decreasing in event-sequence order per run.

`FILL` requires `BUY` or `SELL`, positive finite quantity and price, and
finite non-negative fee. `cash_delta` and `position_delta` equal the single
`ledgr_fill_publication_deltas()` result at tolerance zero.

Opening requires finite nonzero quantity, finite price of any sign, zero fee
and cash effect, and `position_delta == qty`. Price is cost basis.

Corporate cash requires its source fact and policy identities, finite
entitled quantity and gross cash per parent unit, a logical late-arrival flag,
zero position effect and the exact posted cash effect. Its typed inputs permit
validation without reopening the snapshot.

Disposition requires source-fact, policy, choice, basis and mark evidence;
positive quantity, finite non-negative price, zero fee, finite signed
`position_before`, and exact effects. Quantity, price and signed deltas
reconcile at tolerance zero. `qty == abs(position_before)`,
`position_delta == -position_before` and
`cash_delta == position_before * price`. `realized_model_pnl` reconciles at
the canonical lot dust tolerance. Write-off records bind `mark_source =
"write_off"`, `mark_age = 0` and the disposition pulse as mark time.
Lifetime-only labels are null for scheduled dispositions even when the
resolver internally reports a default match.

The ticket cut supplies a literal per-kind required/null/forbidden matrix.

## 7. One Validation Vocabulary at Two Trust Boundaries

One vectorized, grouped validator owns typed structural and row-arithmetic
rules. Append invokes it before rows become durable. Read preparation invokes
the same rules against persisted blocks. This is one vocabulary reused at two
trust boundaries, not two implementations.

Lot-dependent reconciliation, including disposition realized PnL, occurs in
canonical replay where lot state exists. Producers do not call the preparer on
one-row data frames. Projection code owns no private accounting validator.

Delete current fallbacks for missing or partial fill metadata, inferred
terminal choice or basis, malformed openings, headline `%||% 0` effects and
unsorted timelines. Older or malformed rows refuse; they are not repaired.

Resume deduplication reads typed `source` and `source_fact_id`. It enforces
fact uniqueness within a posting source and refuses incompatible cash and
disposition postings for the same fact. A non-null fact ID alone is not a
sufficient discriminator.

## 8. Replay, Projection and the Memory Exception

The prepared carrier is columnar and chunkable: common columns, effects,
closed evidence fields, stable instrument indexes and derived operation
codes. It contains no per-event metadata list and no product-runtime event
attributes. Tests and `dev/bench/v0_2_3_output_freeze/lib.R` migrate away from
the old attributes rather than pretending they never consumed them.

Memory and durable inputs reach the same preparation shape where replay is
required. Durable readers fetch bounded typed blocks. Splitting an ordered
stream at any event leaves every replay fact and final state unchanged.

`inline_summary()` remains the explicit exception for ordinary in-memory
sweep candidates. It projects already-computed fill legs and equity facts and
does not replay a durable ledger. Supported candidate shapes must match the
durable result path, and a detector must prove production still calls it.

Replay owns lot transitions and event facts. Projections own fills, trades,
equity, corporate-action summaries, terminal outcomes, resume state and
printing. The headline and entitlement position walks consume canonical
replay state rather than cumulating `position_delta`.

## 9. One Ordered Cut

WS7 first leaves one typed carrier: it extracts current JSON evidence into
typed vectors temporarily, changes lot application to typed scalars, removes
`prepared$meta` and metadata parsers, redirects every reader, deletes the two
cumulative position walks, and establishes one chunked replay and projection
set. It must not leave typed vectors and parsed metadata as dual authorities.

WS8 then makes every producer and all three durable write paths publish the
typed schema directly, including resume opening and compiled batches. It
removes event JSON encode/decode and temporary extraction, replaces resume
dedupe with the typed query, and resets the current store format. The two
workstreams are one cut and one rebuild, but retain separate detecting claims.

## 10. Persistence, Contracts and Public Surface

Implementation increments `ledgr_experiment_store_schema_version`; at the
reviewed baseline the successor is 125. It changes the store-format
fingerprint and golden catalogue. Older, missing-marker and differently
fingerprinted stores refuse before read or write. There is no migration,
compatibility reader, inferred column or JSON fallback.

Amend `contract-execution-accounting-events` to bind typed fields instead of
canonical `meta_json`, and `contract-persistence-current-format` for schema
125. `meta_json` remains valid for configuration, provenance and interchange
outside accounting-critical event storage.

Raw storage remains internal, but `ledgr_results(bt, "ledger")` deliberately
returns `SELECT *` over the new wide typed table. Document and test that shape.
Other public tables, values, types, ordering and missingness remain stable
except the already-decided INCOMPLETE annualized-return correction owned by
WS7.

## 11. Detecting Evidence

The ticket cut carries failure-sensitive gates for:

1. literal source-derived producer, writer, reader, test and doc censuses;
2. independent per-kind typed fixtures, including partial close, reversal,
   opening with negative basis, cash, both dispositions, zero-price and
   write-off cases and resume;
3. memory-versus-DuckDB prepared-block identity before replay;
4. one-block versus adversarial chunk splits, including opening blocks,
   cash-to-disposition and prior-block `position_before`;
5. public-table and print parity, with the two deliberate differences named;
6. required/null/forbidden and arithmetic mutations, duplicate-fact resume,
   disposition mismatch and realized-PnL dust refusal;
7. no `ledger_events.meta_json`, event JSON encode/decode, metadata list,
   cumulative position walk or unsorted fallback;
8. old-store refusal before read or write, with no migration path;
9. `inline_summary()` production use and parity against durable results;
10. the seven optimization shapes across publication, validation,
    preparation, replay and projection; and
11. attributed warm run, read, combined workflow and peak-memory records.

WS3 and WS9 retain release-wide runtime and bounded-memory conclusions.

## 12. Rejected and Deferred

Rejected: specialized JSON encoding; typed key-value metadata; one table per
kind; JSON beside typed columns; reconstructing evidence from snapshots;
`position_delta` as position-state authority; migrations or inferred old
rows; separate validation vocabularies; and replay inside each projection.

Later asset classes add explicit typed fields, vocabulary entries and a schema
reset through their own RFC. This seed does not prebuild a generic extension
mechanism.

## 13. Sequence

1. Decision synthesis by an author other than seed v2's author.
2. Type 1 final review by an author other than the synthesis author.
3. Maintainer acceptance and routing: one ordered WS7/WS8 cut.
4. Rebuild affected stores once after the identity-changing cut.
5. WS3 and WS9 record integrated runtime and memory.

This seed authorizes no product, contract, schema or ticket change.
