# Synthesis Response: Sweep Promotion Context For v0.1.8

**Status:** Reviewer response.
**Date:** 2026-05-14
**Synthesis:** `inst/design/rfc/rfc_sweep_promotion_context_v0_1_8_synthesis.md`
**Reviewer:** Claude (Sonnet 4.6)

---

## Overall Assessment

The synthesis correctly adopts all three corrections from the RFC response:
dedicated table, defined `sweep_id`, serializable warnings. The core design is
sound. One material issue must be resolved before the spec is patched.

---

## Material Issue: The Dual-Summary Approach Fails For The Primary UX Pattern

The synthesis introduces two candidate summaries:

- `source_candidate_summary_json` — all candidates in the original sweep
- `selection_view_summary_json` — the filtered/sorted table the user selected from

The motivation is correct: a full selection audit should preserve both the
candidate universe and the selection view. The problem is that the primary
documented workflow breaks the assumption that both are available at
`ledgr_promote()` call time.

The user workflow is:

```r
candidate <- train_results |>
  dplyr::filter(status == "DONE") |>
  dplyr::arrange(dplyr::desc(sharpe_ratio)) |>
  ledgr_candidate(1)
```

`ledgr_classed_tibble()` — the internal helper that creates all classed tibbles
including `ledgr_sweep_results` — prepends a class name to a plain tibble. It
does not implement `dplyr_reconstruct`, `vec_restore`, or any vctrs/dplyr
attribute-preservation protocol. After `dplyr::filter() |> dplyr::arrange()`,
the result is a plain tibble. Class and attributes — including `sweep_meta` —
are gone by the time `ledgr_candidate(1)` is called.

`ledgr_candidate()` only sees the filtered/sorted rows. It cannot recover the
full source universe unless:

1. `ledgr_sweep_results` implements dplyr reconstruction methods so attributes
   survive filter/arrange — non-trivial v0.1.8 scope.
2. The full compact source summary is copied into every row's `provenance` list
   column — redundant storage per row.
3. The full compact source summary is stored in `sweep_meta` before filter/arrange
   runs, and `ledgr_candidate()` reads it from there — requires `sweep_meta` to
   survive the dplyr pipeline, which it does not under the current
   `ledgr_classed_tibble()` implementation.

None of these are practical for v0.1.8. The synthesis proposes a dual-summary
design without resolving how the source summary is obtained in the common case.

### Resolution

Collapse to a single `candidate_summary_json` for v0.1.8.

`candidate_summary_json` is the compact summary of the table passed to
`ledgr_candidate()` — whatever the user filtered, sorted, and selected from.
This is the selection view. It is always available because `ledgr_candidate()`
receives it directly as its first argument.

Rename the schema column from the two proposed fields to one:

```sql
candidate_summary_json  TEXT NOT NULL
```

The selection view answers the most critical selection-audit question:

```text
What did the user actually select from?
```

If the user selected from the full unfiltered sweep, it captures the full
universe. If the user filtered first, it captures the filtered view — which is
exactly what the user exercised judgment over.

Defer `source_candidate_summary_json` to when `ledgr_sweep_results` implements
dplyr reconstruction methods or when `ledgr_save_sweep()` provides an
alternative source-universe recovery path. Add a horizon note:

```text
YYYY-MM-DD [sweep] Source candidate universe in promotion context

Future: when ledgr_sweep_results implements dplyr_reconstruct, add
source_candidate_summary_json alongside the selection-view summary so
promotion context captures the full candidate universe separately from
the user's filtered selection view. Currently collapsed to single
candidate_summary_json because dplyr attribute propagation is not
implemented on ledgr_sweep_results.
```

---

## Correction: `selection_view_summary_json` Does Capture Sort Order Implicitly

One observation in favor of the selection-view-only approach: if
`candidate_summary_json` stores rows in the order they were passed to
`ledgr_candidate()`, and the user sorted before calling `ledgr_candidate()`,
then the stored summary row order reflects the user's ranking. Row 1 of the
stored summary is the candidate that was selected. This implicitly records "this
was the top row under the user's applied ordering" without ledgr needing to
infer the sort key.

The implementation should preserve row order when serializing the summary.

---

## Open Question Resolutions

### 1. Two summaries or one + scope field?

One summary (`candidate_summary_json`). See the material issue above. Two
summaries cannot be reliably populated under the current implementation without
dplyr reconstruction support. Scope field is unnecessary if only one summary
is stored.

### 2. Nullable selection view?

Moot if dual summaries are collapsed to one.

### 3. Preferred `sweep_id` generator?

Use `proc.time()["elapsed"]`, `Sys.getpid()`, and a package-environment counter.
No new package dependency. Does not touch `.Random.seed`.

Recommended implementation:

```r
.ledgr_sweep_counter <- new.env(parent = emptyenv())
.ledgr_sweep_counter$n <- 0L

ledgr_generate_sweep_id <- function() {
  .ledgr_sweep_counter$n <- .ledgr_sweep_counter$n + 1L
  paste0(
    format(proc.time()["elapsed"], nsmall = 3),
    "_", Sys.getpid(),
    "_", .ledgr_sweep_counter$n
  )
}
```

This is unique per session, monotonic within a session, and produces no
`.Random.seed` side effects. Do not use `sample.int()` even with local RNG
isolation — the RNG contract tightening in v0.1.8 makes any ambient RNG use
suspicious and hard to audit.

Avoid the `uuid` package dependency. UUID is a well-defined standard but adding
a package dependency for one narrow use case is not worth it when the above
approach is sufficient and fully internal.

### 4. Export `ledgr_promotion_context(bt)` in v0.1.8?

Export both:

```r
ledgr_promotion_context(bt)
ledgr_run_promotion_context(exp, run_id)
```

`ledgr_promotion_context(bt)` is the immediate post-promotion path — the user
just called `ledgr_promote()` and has the result in hand. This is the most
common first access. `ledgr_run_promotion_context()` is the store-lookup path
for later sessions or other processes. Both are read-only wrappers over stored
JSON and carry no implementation complexity beyond deserialization. Ship both.

### 5. `note` as plain text or structured?

Plain text for v0.1.8. `TEXT` column, free-form user annotation. Do not
introduce a structured note schema before there is a use case for it.

---

## Additional Finding: Write Failure After Successful Run

The synthesis correctly says the context write happens only after `ledgr_run()`
succeeds. But it does not specify what happens if the `run_promotion_context`
write itself fails (e.g., a DuckDB error on the second write).

The committed run already exists and cannot be rolled back. The spec must
specify: if the promotion context write fails, emit a warning and return the
committed run result. Do not fail the promotion. Do not attempt to roll back
`ledgr_run()`.

The warning message should name the recovery step:

> Promotion context could not be written for run '{run_id}'. The committed run
> is intact. To inspect the candidate manually, retain the candidate object or
> the source sweep result.

There is no `ledgr_write_promotion_context_for_run()` recovery function in scope
for v0.1.8. Accept the loss and document it.

---

## Revised Schema

After collapsing to one candidate summary:

```sql
CREATE TABLE IF NOT EXISTS run_promotion_context (
  run_id                    TEXT NOT NULL PRIMARY KEY,
  promotion_context_version TEXT NOT NULL,
  source                    TEXT NOT NULL,
  promoted_at_utc           TIMESTAMP NOT NULL,
  note                      TEXT,
  selected_candidate_json   TEXT NOT NULL,
  source_sweep_json         TEXT NOT NULL,
  candidate_summary_json    TEXT NOT NULL
)
```

Eight columns. Clean. Queryable on scalar fields, nested data in JSON strings.

---

## Required Spec Patch Summary

1. Replace the dual-summary approach with a single `candidate_summary_json`
   (the selection view).
2. Remove `selection_view_summary_json` from the schema and all spec sections.
3. Update `source_candidate_summary_json` → `candidate_summary_json` throughout.
4. Add a horizon note for source-universe tracking via future dplyr reconstruction.
5. Add `sweep_id` generation via proc.time/PID/counter to the sweep output
   handler ticket. No UUID dependency.
6. Add write-failure behavior to the `ledgr_promote()` spec: warn, return
   committed run, do not abort.
7. Add `ledgr_generate_sweep_id()` as internal helper to the sweep ticket scope.
8. Update the required tests list: replace tests referencing
   `source_candidate_summary_json` with `candidate_summary_json`; add test that
   row order in `candidate_summary_json` reflects sort order of input.

---

## Summary

Accept with one material change: collapse `source_candidate_summary_json` +
`selection_view_summary_json` to a single `candidate_summary_json`. The dual-
summary design fails for the primary UX pattern because `ledgr_classed_tibble()`
does not implement dplyr attribute preservation, so sweep attributes do not
survive the user's filter/arrange pipeline. The selection view (what was passed
to `ledgr_candidate()`) is the only reliably available summary at
`ledgr_promote()` call time.

Everything else in the synthesis is accepted: dedicated table, schema version
107, `sweep_id` as non-RNG event ID, `note = NULL`, canonical JSON
serialization, `n_warnings`/`warning_classes`, both read helpers in v0.1.8,
write-after-success timing, size bound reasoning.
