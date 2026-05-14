# RFC Response: Sweep Promotion Context For v0.1.8

**Status:** Reviewer response.
**Date:** 2026-05-14
**RFC:** `inst/design/rfc/rfc_sweep_promotion_context_v0_1_8.md`
**Reviewer:** Claude (Sonnet 4.6)

---

## Overall Assessment

Accept the promotion context design. Storing a compact selection-audit record
on every promoted run is the right move, and the timing is correct: do it now
while the promotion API is being built, not as a retrofit.

Three items require resolution before implementation begins:

1. The RFC's storage recommendation must be corrected: a new
   `run_promotion_context` table is the right shape, not a JSON blob in run
   metadata.
2. `sweep_id` is undefined and must be defined before implementation.
3. `warnings` in `candidate_summary` must be specified as a serializable form,
   not R condition objects.

---

## Correction 1: Storage Is A New Table, Not A JSON Blob

The RFC lists three storage options without recommending one, deferring to "the
implementation ticket." Based on the existing store schema, the answer is clear:
a new `run_promotion_context` table, following the same pattern as
`run_provenance`.

The store already separates concerns into tables:
- `runs` — identity, status, metrics
- `run_provenance` — strategy source, params, reproducibility
- `run_telemetry` — execution diagnostics
- `run_tags` — mutable user metadata

`run_promotion_context` belongs alongside these. The `run_provenance` table was
created ahead of its writers in the schema migration with `CREATE TABLE IF NOT
EXISTS`, with a separate ticket filling in the writer. The same pattern applies
here.

Recommended `run_promotion_context` schema:

```sql
CREATE TABLE IF NOT EXISTS run_promotion_context (
  run_id                     TEXT NOT NULL PRIMARY KEY,
  promotion_context_version  TEXT NOT NULL,
  source                     TEXT NOT NULL,
  promoted_at_utc            TIMESTAMP NOT NULL,
  note                       TEXT,
  selected_candidate_json    TEXT NOT NULL,
  source_sweep_json          TEXT NOT NULL,
  candidate_summary_json     TEXT NOT NULL
)
```

Scalar fields (`promotion_context_version`, `source`, `promoted_at_utc`, `note`)
are native columns. Nested data (`selected_candidate`, `source_sweep`,
`candidate_summary`) are stored as JSON strings using `canonical_json()` where
available.

This keeps the table queryable for simple audits:

```sql
SELECT run_id, source, promoted_at_utc, note
FROM run_promotion_context
WHERE source = 'ledgr_sweep'
```

while keeping complex nested structures in JSON for flexibility.

The schema migration bumps `ledgr_experiment_store_schema_version` from 106 to
107. Old stores gain an empty `run_promotion_context` table. Runs without a
promotion context row have no entry; `ledgr_promotion_context()` returns `NULL`
for those runs. This is backward-compatible.

---

## Correction 2: `sweep_id` Is Undefined

The RFC's `source_sweep` includes `sweep_id = "..."`. Neither the spec, the
UX document, the promotion contract RFC, nor the synthesis defines `sweep_id`
or specifies how `ledgr_sweep()` generates one.

This must be resolved before the promotion ticket begins.

Recommended definition: `ledgr_sweep()` generates a UUID (`uuid` package or
`paste0(format(Sys.time(), "%Y%m%dT%H%M%S"), "_", sample.int(.Machine$integer.max, 1))`)
at sweep start. The UUID is stored as an attribute on the `ledgr_sweep_results`
object. `ledgr_candidate()` copies it into `sweep_meta`. `ledgr_promote()`
reads it from the candidate's `sweep_meta` and writes it into
`source_sweep_json`.

Do not use a deterministic hash of sweep inputs as `sweep_id`. Two identical
sweeps are different research events. They should have different IDs. A UUID
captures this correctly.

Add to the spec: `ledgr_sweep()` produces a `sweep_id` UUID stored in the
result object attributes. This is part of the sweep output handler ticket, not
the promotion context ticket.

---

## Correction 3: `warnings` In `candidate_summary` Must Be Serializable

The RFC includes `warnings` in the `candidate_summary` tibble. R condition
objects are not JSON-serializable in a meaningful way — they carry class
hierarchies, call stacks, and environment references that cannot be faithfully
stored in DuckDB.

Replace `warnings` in the stored `candidate_summary` with two scalar fields:

- `n_warnings`: integer count of warning conditions.
- `warning_classes`: JSON array of unique warning condition class strings.

This answers the selection-audit questions "were there warnings?" and "what
kind of warnings?" without storing non-serializable objects. Full condition
objects are in the live sweep result or in existing DuckDB telemetry.

---

## Open Question Resolutions

### 1. Metadata JSON or dedicated table?

Dedicated table. See Correction 1.

A JSON blob in run metadata would co-mingle promotion context with config and
execution metadata and would not follow the existing store pattern. A dedicated
table is queryable, follows the `run_provenance` precedent, and keeps concerns
separated.

### 2. Public `ledgr_promotion_context()` helper or only `ledgr_run_info()`?

Both, in the promotion context ticket.

`ledgr_run_info()` should expose `promotion_context` as an optional field in
its return value. When a run was promoted, the field is populated; when it was
created by `ledgr_run()` directly, the field is `NULL`.

`ledgr_promotion_context()` is a convenience accessor:

```r
ledgr_promotion_context(bt)
```

returning the fully parsed context or `NULL`. It is a thin wrapper over the
stored JSON, not a new execution path. Ship it in v0.1.8.

Also expose:

```r
ledgr_run_promotion_context(exp, run_id = "momentum_v1_test")
```

for store-level lookup when the live result object is not available.

### 3. params in `candidate_summary` — list column or canonical JSON?

Canonical JSON string per candidate.

For durable storage, R list objects are not stable across sessions or versions.
`canonical_json()` already exists and is already used by `ledgr_param_grid()`.
Use it here.

In stored `candidate_summary_json`, each candidate's params field is a
canonical JSON string. When a user reads the context back (via
`ledgr_promotion_context()`), ledgr deserializes the JSON back to a named list
for each candidate. The round-trip must be tested with the canonical types
`canonical_json()` supports.

Same applies to `provenance` in each candidate summary row: serialize as JSON
string on write, parse on read.

### 4. `warnings` in `candidate_summary`?

Replace with `n_warnings` (integer) and `warning_classes` (character vector
serialized as JSON array). See Correction 3.

### 5. Ranking order at promotion time?

Do not store ranking order. Add an optional `note = NULL` argument to
`ledgr_promote()` instead:

```r
ledgr_promote(
  test_exp, candidate,
  run_id    = "momentum_v1_test",
  note      = "Top Sharpe from train sweep, 48 candidates, ranked 2026-05-14"
)
```

This note is stored in the `note` column of `run_promotion_context`. It is more
flexible than a computed rank order — it captures the user's intent, not just
the sort key. Users can note "Best Sharpe after removing candidates with fewer
than 5 trades" without ledgr inferring that from a stored sorted table.

Storing a ranked summary would require `ledgr_promote()` to know the ranking
logic the user applied, which it cannot. The candidate object does not carry
sort metadata. A user-supplied note is the correct substitute.

---

## Additional Finding: Scope Is Correct, Implementation Order Matters

The RFC correctly scopes promotion context as v0.1.8. The schema migration
follows existing patterns and is backward-compatible. The implementation surface
is bounded and follows existing writers (`run_provenance` precedent).

The natural implementation order for the promotion context ticket:

1. Schema migration: create `run_promotion_context` table, bump schema version
   to 107.
2. Sweep output handler: add `sweep_id` UUID to `ledgr_sweep_results` (this
   is output handler ticket scope).
3. `ledgr_promote()`: after `ledgr_run()` succeeds, serialize and write
   promotion context to `run_promotion_context`.
4. `ledgr_promotion_context()` and `ledgr_run_promotion_context()`: read
   helpers over stored JSON.
5. `ledgr_run_info()` integration: surface `promotion_context` as named field.

The promotion context write must happen after `ledgr_run()` succeeds and the
run is committed. If `ledgr_run()` fails, no promotion context is written.

---

## Additional Finding: Large-Sweep Size Is Bounded For v0.1.8

The RFC notes that promoting multiple candidates from the same sweep duplicates
the `candidate_summary`. For a 100-candidate sweep: 100 rows × ~500 bytes per
row = ~50KB of JSON per promoted run. For the spec's threshold (20 combinations
before a warning), typical v0.1.8 sweeps are well under 1MB per promoted run.

This is acceptable. Note it in the spec non-goals or the horizon note: "If
sweep sizes routinely exceed ~500 candidates, `run_promotion_context` storage
should be revisited alongside `ledgr_save_sweep()`."

---

## Required Spec Changes If Accepted

1. Add `run_promotion_context` table to the schema section of the spec.
2. Define `sweep_id` as a UUID generated at sweep start by `ledgr_sweep()` and
   stored in `ledgr_sweep_results` attributes.
3. Add `note = NULL` to `ledgr_promote()` signature.
4. Specify `warnings` in stored `candidate_summary` as `n_warnings` +
   `warning_classes`, not full condition objects.
5. Add `promotion_context` as an optional field in `ledgr_run_info()` return.
6. Add `ledgr_promotion_context()` and `ledgr_run_promotion_context()` as
   public helpers in the promotion API section.
7. Add to the promotion ticket scope: schema migration (version 107),
   `run_promotion_context` writer in `ledgr_promote()`, read helpers.
8. Add to the sweep output handler ticket scope: `sweep_id` UUID generation and
   storage on `ledgr_sweep_results`.
9. Add to §11 test list:
   - promotion context is written after successful `ledgr_promote()`;
   - promotion context is absent for direct `ledgr_run()` calls;
   - `ledgr_promotion_context()` returns `NULL` for runs without context;
   - `candidate_summary` includes all candidates, not only selected;
   - params round-trip through canonical JSON correctly;
   - `n_warnings` and `warning_classes` correct for candidates with warnings;
   - schema migration: old stores gain empty `run_promotion_context` table.
10. Add horizon note for full sweep artifact persistence
    (`ledgr_save_sweep()` / `ledgr_load_sweep()`).

---

## Summary

Accept. The direction is correct and the implementation fits the existing store
pattern.

Corrections before implementation begins:

- Use a new `run_promotion_context` table (schema version 107), not a JSON
  blob in run metadata. Follows the `run_provenance` pattern.
- Define `sweep_id` as a UUID generated at sweep start; add it to
  `ledgr_sweep_results` attributes in the sweep output handler ticket.
- Replace `warnings` in stored `candidate_summary` with `n_warnings` +
  `warning_classes`.
- Add `note = NULL` to `ledgr_promote()` instead of storing ranking order.
- Ship `ledgr_promotion_context()` and `ledgr_run_promotion_context()` in
  v0.1.8 alongside the promotion API.
