# Typed accounting boundary spike

**Status:** executed; GREEN for a focused typed-accounting RFC.

## Question

Given ledgr's closed accounting event vocabulary and the complete field census,
does a companion-table layout provide enough benefit over one wide nullable
typed event table to justify joins and multiple persistence paths?

## Prerequisite

The representation seam must already be independent of JSON. The executed
probe confirms that the memory output sink retains typed accounting columns and
does not serialize metadata JSON, while the DuckDB sink persists the older
`meta_json` event surface. The earlier redundant-accounting spike also showed
that the accounting reader can consume prepared typed deltas.

## Kill condition

Stop and recharter the field census if a shipped event producer or result
surface requires free-form metadata outside the inventoried closed fields. Stop
the layout comparison if either prototype cannot reproduce every inventoried
field exactly.

## Alternatives

1. one ordered event table with common and nullable type-specific columns;
2. one ordered common event table plus opening, cash and disposition evidence
   tables joined by `event_seq`.

This is a storage-shape probe, not a product implementation. It changes no
package code, schema, contracts or public result.

## Run

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/spikes/typed-accounting-boundary/run_spike.R dev/spikes/typed-accounting-boundary/evidence
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/spikes/typed-accounting-boundary/check_spike.R
```

The runner writes semantic, timing and gut CSVs. The checker reruns in a
scratch directory, diffs the deterministic semantic evidence, requires exact
roundtrips, confirms that deleting `source_fact_id` is detected, and guards
package scope.
