# Workstream 24 implementation closeout

Status: implementation complete; awaiting the independent Type 1 close review.

The independent review returned `CHANGES_REQUIRED` in `close_review_24.md`.
Correction `14d48de7` preserves non-midnight disposition provenance as
`POSIXct`, removes redundant fill-path frame construction and mark formatting,
migrates the A0 memory attachment to typed columns, exhausts the producer and
write-site census, and removes the remaining schema-124 publication teaching.
The non-midnight mutation fails the registered terminal-reporting block. A
fresh 281-file A0 record at `14d48de7` passes the typed-vs-JSON semantic
comparison against immutable base `0d6c0b11`: 22 event files, 13 schema-marker
tables and the four already accepted INCOMPLETE annualized-return cells.
The attachment refuses a typed row with either accounting effect missing
(`A0_TYPED_MISSING_REFUSED`). A post-correction source build succeeds and the
supported-C-locale `R CMD check --no-manual --no-build-vignettes` runs the
installed tests and all vignette code, reporting only the same two
pre-rendered-vignette warnings.

Workstream 24 completes the schema-125 half of the accepted typed-accounting
boundary. Product commit `8055fa29` changes the store and every accounting
producer atomically. There is no schema-124 reader, migration, missing-marker
fallback or accounting JSON compatibility path.

## Implemented boundary

`ledger_events` is one ordered 31-column typed table: common identity and
execution columns, signed accounting effects, source identity, corporate-cash
evidence and disposition evidence. The schema carries the accepted unique
`(run_id, event_seq)` key and source vocabulary. The experiment-store marker
is 125 and the current schema catalogue/fingerprint is re-pinned. The existing
store gate therefore refuses schema 124, unmarked and fingerprint-mismatched
stores before a product read or write.

Fills, opening positions, corporate cash, scheduled dispositions and lifetime
dispositions all construct `ledgr_accounting_rows()` directly. The persistent
and memory handlers stage the same typed columns. Audit-log persistence keeps
the existing typed block buffer and performs one append per flush; db-live
keeps its required immediate append of the already validated pulse block.
Resume opening uses the same block constructor and append validator. No sink
recomputes publication economics.

`ledgr_validate_accounting_append()` validates the exact carrier at the append
boundary. `ledgr_prepare_accounting_events()` validates and normalizes typed
columns only; it performs no JSON extraction. Replay, public results, run
reopening, corporate-action reporting, terminal reporting and lot
reconstruction consume those typed columns. Resume dedupe reads only
`source, source_fact_id`, excludes fill rows and refuses a fact repeated within
one posting source or across cash and disposition sources.

The former accounting `meta_json` encoder/decoder, meta list, event attributes,
handler basis/realized auxiliary vectors and `ledgr_lot_parse_meta()` are
deleted. The remaining `meta_json` uses belong to snapshot, configuration and
walk-forward records, not ledger accounting. `spot_fifo.cpp` and compiled
dispatch are unchanged.

## Detection and parity

LTB-0550/LCL-0539 owns the literal schema version, ordered column catalogue,
DDL source vocabulary, producer census, absence of accounting JSON, grouped
typed validation, cross-block order state, formula checks and replay arithmetic.
The schema golden files pin all 2,647 normalized schema rows on DuckDB 2.0.0.
LTB-0553/LCL-0542 keeps the heterogeneous late-disposition witness on typed
columns. Existing LTB-0035 and LTB-0053 detect within-source and cross-source
cash/disposition dedupe. Wrong-effect rows refuse before a durable append.

The memory-event fixture changes only from the temporary schema-124 auxiliary
shape to the accepted typed columns. Every economic oracle remains the same.
The complete package suite reaches every WS24-owned block successfully. Its
eight failures reproduce the recorded baseline groups: two historical YAML
parsers (LTB-0408 and LTB-0416), one Windows latin1 assertion (LTB-0247) and
five native-encoding sweep-retention assertions. The optional quantmod
missing-package path remains the one skip. These are not represented as WS24
passes or regressions.

The private WS23 Sharadar gate is not rerun here. Its accepted aggregate record
at ledgr-research `e8ff0bd` fixed the input boundary for this transition; the
next private milestone belongs to LDG-3209 after the complete Cut 11 format is
known.

`R CMD build --no-build-vignettes` succeeds. A full supported-C-locale
`R CMD check --no-manual --no-build-vignettes` runs the installed-package tests
and all vignette code successfully. It reports only the repository's two known
pre-rendered-vignette warnings. Its first pass found one unqualified `tail()`
in the new append boundary; correction `ac991cbd` qualifies `utils::tail()`,
and a rebuilt post-correction code/documentation check reports no code NOTE and
the same two vignette warnings.

## Append batching decision

Workstream 24 retains the one mechanism already measured and mutation-tested
by the WS4a publication batch: typed rows are constructed once per pulse,
audit-log mode buffers typed blocks and appends once per configured flush, and
db-live appends the same validated pulse block immediately because its public
mode promises immediate visibility. The C13c append/flush fault matrix proves
whole-run rollback and no swallowed write, while the event-buffer growth and
compiled parity witnesses pin block order, fees and effects. A row-at-a-time
replacement would add a second mechanism and violate the registered block
boundary; no new microbenchmark is needed to choose between already-settled
shapes. This is rule-16 design evidence, not a workstream timing gate.

## Seven-shape and cold-read walk

The seven optimization shapes were walked over every changed producer, sink,
writer and reader:

1. producers construct one typed frame per block; no one-row frame collection,
   growing `rbind()` or list append remains on an event path;
2. no producer or reader performs a full ledger subset once per instrument;
3. timestamps are normalized vectorially at the accounting boundary, never
   parsed one event at a time in replay;
4. no accounting event is encoded, decoded, hashed or validated as JSON;
5. fill effects are carried from P3 and all other effects are constructed once;
   sinks and replay do not recompute discarded values;
6. validation is column-wise and grouped, with no pairwise event scan; and
7. the existing owned typed buffers retain indexed `collapse::setv()` writes;
   no environment-held vector receives scalar base subassignment.

A cold ledger read is a `SELECT *` over the typed table. Public ledger results
return that stored shape without a projection parser. Accounting-semantic
readers perform one typed preparation/replay per fetched block; they do not
reintroduce per-row conversion, repeat preparation per instrument or retain a
hidden schema-124 path.

## Documentation

The accounting contract, `ledgr_results(..., what = "ledger")` and
`as_tibble()` help, the accounting vignette, internal snapshot manual and NEWS
now teach the public ledger as one wide typed `SELECT *` result. Non-applicable
evidence fields are typed missing values. There is no JSON accounting envelope
to unpack. Documentation-contract tests pin those statements and schema 125 as
the current format while preserving historical NEWS records about schema 124.
