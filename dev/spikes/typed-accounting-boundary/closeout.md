# Closeout: typed accounting boundary

**Outcome:** GREEN for a focused RFC, with one wide nullable typed event table
as the provisional storage candidate. The spike authorizes no schema change.

## What ran

The package probe executed the current output sinks and accounting column
surface. The storage fork then wrote and read 71,500 deterministic events:
70,000 fills and 500 each of opening positions, corporate-action cash events
and dispositions. It compared exactly two layouts over the same 32 typed
fields: one wide event table and one common table with three evidence
companions. Each layout ran three fresh DuckDB files. A gut removed
`source_fact_id` from the companion projection.

## What was learned

Both layouts reproduce every typed cell exactly. The gut changes 1,000 cells
and is rejected, showing that the checker protects real corporate-action and
terminal evidence rather than only fill economics.

On this bounded fixture, the wide table occupies 2,633,728 bytes and the
companion layout 3,944,448 bytes. Median writes are 0.11 and 0.14 seconds;
both median reads are 0.05 seconds. These are structural measurements on one
synthetic shape, not a general database ranking. They provide no evidence that
the extra tables, indexes and joins buy enough to justify their additional
schema and reader complexity.

The more important result is architectural: ledgr already owns typed event
effects in its memory output handler, while durable persistence converts the
closed evidence vocabulary to JSON and readers parse it back. Removing that
round trip does not require a second accounting model.

## What the RFC may consume

- Preserve one ordered event vocabulary and start from one typed durable table.
- Eliminate duplicated JSON values, not source-fact, policy or valuation
  evidence.
- Make the typed replay interface the shared reader contract before changing
  durable storage.
- Bind exact arithmetic, nullable-field validation, schema-version bump and
  refusal of older stores in design authority.

## Open

The spike does not decide whether signed deltas are stored or derived, whether
rare evidence fields should later move to companions at a proven scale, or the
exact public projection of typed evidence. Those are RFC questions. Full
workflow performance and peak memory remain WS3/WS9 verification work.
