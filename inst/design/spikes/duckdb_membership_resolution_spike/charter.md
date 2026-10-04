# Charter: DuckDB Membership Resolution Spike

**Status:** Executable charter; binds nothing.
**Author:** Codex. **Date:** 2026-10-04
**Protocol:** `inst/design/spike_protocol.md`
**Feeds:** v0.2.2 direct optimization planning after Workstream 9.

## 1. Question

> Can a sealed-snapshot membership inspection push historical filtering into
> DuckDB and materially reduce public resolution time while returning exactly
> the current rows and evidence under current integrity verification?

That is the only question.

## 2. Cheaper Prerequisite

Can the last complete set bound the persisted rows loaded into R without
changing the existing resolver's result?

The probe answered conditionally. At 30,000 rows there was no pruning and no
gain. At 300,000 rows a late complete set reduced the public call from 7.25 to
4.07 seconds, with exact rows and evidence.

## 3. Fork

The runner uses the public sealed-snapshot input and performs the ordinary
full snapshot-hash verification. One scratch resolver reads eligible headers,
keeps the last complete header and later headers, asks DuckDB for only their
set rows plus applicable set-less rows, and passes that reduced data to the
existing R resolver.

It may not replace the resolver, change precedence, trust the stored hash,
add an index or alter package source.

## 4. Cases And Gate

At 6,000, 30,000 and 300,000 set rows, the runner compares explicit-instrument
and full-universe public results. The fixture carries complete and incremental
sets, changing membership composition, an unknown requested instrument and
set-less overrides.

GREEN requires exact rows and evidence in all six cases, at most 20% of set
rows transferred at the 300,000-row boundary, and at least 1.5x lower median
public time there. Otherwise the spike is RED. This is the only gate.

## 5. Kill Condition

Stop if parity needs a new stored representation, index, schema, hash shortcut
or a second membership resolver. Such a result must re-enter planning rather
than grow the harness.

## 6. Deliverables And Gut

Exactly three executor deliverables:

- `spike_runner.R`, writing deterministic cases plus timing CSVs;
- `spike_checker.R`, rerunning into scratch, diffing deterministic evidence and
  guarding package scope;
- `spike_inventory.md`, naming what was demoted, deleted and learned.

The gut chooses a boundary after the last complete set, dropping the reset
header rather than loading a harmless superset. The 300,000-row fixture must
change membership or evidence and fail the deterministic diff. A tied-clock,
mixed-case set-ID case requires the boundary to follow the retained R
resolver's ordering rather than DuckDB byte collation.

The closeout is the protocol's one-page terminal record.

## 7. Non-Goals And Budgets

No in-memory-family SQL path, public API, schema, snapshot identity,
verification policy or provider-run change. Harness: 1,500 R lines;
correction: 500 lines; charter: 150 lines; closeout: one page. An overrun stops
the spike.
