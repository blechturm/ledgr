# Decision: Sweep Promotion Context For v0.1.8

**Status:** Accepted for v0.1.8 spec patch.
**Date:** 2026-05-14
**Decision owner:** Max / ledgr design process
**Thread:**

- `inst/design/rfc/rfc_sweep_promotion_context_v0_1_8.md`
- `inst/design/rfc/rfc_sweep_promotion_context_v0_1_8_response.md`
- `inst/design/rfc/rfc_sweep_promotion_context_v0_1_8_synthesis.md`
- `inst/design/rfc/rfc_sweep_promotion_context_v0_1_8_synthesis_response.md`

## Decision

v0.1.8 will store durable selection-audit metadata for runs created through
`ledgr_promote()`.

The feature is promotion context, not full sweep persistence.

```text
ledgr_sweep_results -> ledgr_sweep_candidate -> ledgr_promote() -> ledgr_run()
                                                        |
                                                        v
                                             run_promotion_context
```

The committed run remains the durable artifact. Promotion context records the
candidate view and sweep identity that led to that run.

## Accepted Scope

### Dedicated Store Table

Add a dedicated table:

```text
run_promotion_context
```

Use schema version `107`.

Accepted schema:

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

`run_promotion_context` follows the existing store pattern:

```text
runs
run_provenance
run_telemetry
run_tags
run_promotion_context
```

### Context Version

Use:

```text
promotion_context_version = "ledgr_promotion_v1"
```

This versions the promotion-context structure. It is separate from row-level
`provenance_version` and seed derivation contract/version.

### Sweep ID

`ledgr_sweep()` generates a `sweep_id` at sweep start.

Rules:

- `sweep_id` identifies a research event, not a deterministic input hash;
- two identical sweeps should get different IDs;
- generation must not touch `.Random.seed` or strategy RNG state;
- no UUID dependency is required for v0.1.8;
- use an internal helper, tentatively `ledgr_generate_sweep_id()`, based on
  non-RNG process/session/counter information.

`sweep_id` is stored on `ledgr_sweep_results`, copied into
`ledgr_sweep_candidate`, and written into `source_sweep_json`.

### Candidate Summary

Use one summary:

```text
candidate_summary_json
```

It stores the compact summary of the table passed to `ledgr_candidate()`.

This is the selection view:

```r
candidate <- train_results |>
  dplyr::filter(status == "DONE") |>
  dplyr::arrange(dplyr::desc(sharpe_ratio)) |>
  ledgr_candidate(1)
```

In this example, `candidate_summary_json` records the filtered and sorted
`DONE` view, not necessarily the full original sweep universe.

The row order in `candidate_summary_json` must be preserved. If the user sorted
before candidate selection, the stored summary records that order.

### JSON Serialization

Nested durable fields are stored as canonical JSON strings:

- `selected_candidate_json`;
- `source_sweep_json`;
- `candidate_summary_json`.

Candidate summaries must be converted to JSON-compatible records before calling
`canonical_json()`. Do not pass tibbles or R condition objects directly to
`canonical_json()`.

Candidate summary records should include:

```text
run_id
status
final_equity
total_return
annualized_return
volatility
sharpe_ratio
max_drawdown
n_trades
win_rate
avg_trade
time_in_market
execution_seed
params_json
provenance_json
n_warnings
warning_classes
error_class
error_msg
```

`params_json` and `provenance_json` are per-row canonical JSON strings.

### Warning Serialization

Do not store full R condition objects in durable promotion context.

Store:

```text
n_warnings
warning_classes
```

`warning_classes` is a JSON array of unique warning condition class strings.

### Promotion Note

`ledgr_promote()` accepts:

```r
note = NULL
```

The note is plain text in v0.1.8 and is stored in
`run_promotion_context.note`.

Do not infer or store ranking logic automatically. The note lets users record
selection intent in their own words.

### Write Timing And Failure Behavior

`ledgr_promote()` writes promotion context only after `ledgr_run()` succeeds and
the committed run exists.

If the promotion-context write fails:

- emit a warning;
- return the committed run result;
- do not roll back or fail the successful run;
- do not add a recovery writer in v0.1.8.

The warning should clearly state that the committed run is intact and promotion
context was not written.

### Read API

Expose promotion context through:

```r
ledgr_promotion_context(bt)
ledgr_run_promotion_context(exp, run_id)
ledgr_run_info(... )$promotion_context
```

Behavior:

- promoted runs return parsed promotion context;
- direct `ledgr_run()` runs return `NULL`;
- helpers are read-only and do not execute strategy code or mutate store state.

## Deferred Scope

### Full Sweep Persistence

Do not add full sweep save/load/replay in v0.1.8.

Deferred future feature:

```r
ledgr_save_sweep()
ledgr_load_sweep()
ledgr_verify_sweep_sources()
```

This remains parked in `inst/design/horizon.md`.

### Full Source Candidate Universe

Do not store a separate `source_candidate_summary_json` in v0.1.8.

Reason:

The primary UX uses dplyr pipelines before `ledgr_candidate()`. Current classed
tibbles do not implement dplyr/vctrs reconstruction, so original sweep
attributes and source-universe summaries cannot be reliably recovered after:

```r
filter() |> arrange()
```

v0.1.8 stores the selection view passed to `ledgr_candidate()`.

Future work may add source-universe tracking after either:

- `ledgr_sweep_results` implements dplyr reconstruction; or
- full sweep artifacts provide a durable source-universe record.

### Other Deferrals

Do not add in v0.1.8:

- UUID dependency solely for sweep IDs;
- structured note schema;
- durable full warning condition objects;
- inferred ranking logic;
- full ledger/equity/event streams for every sweep candidate;
- a recovery writer for failed promotion-context writes.

## Required Tests

Spec tickets should include tests for:

- schema migration creates `run_promotion_context` and bumps store schema to
  `107`;
- direct `ledgr_run()` has no promotion context;
- `ledgr_promote()` writes context only after successful run commit;
- context write failure warns and still returns the committed run;
- `ledgr_promotion_context()` returns parsed context for promoted runs;
- `ledgr_promotion_context()` returns `NULL` for direct runs;
- `ledgr_run_promotion_context()` can read context by store/run ID;
- `ledgr_run_info()` includes optional `promotion_context`;
- `sweep_id` exists and does not perturb execution RNG state;
- `candidate_summary_json` reflects the filtered/sorted table passed to
  `ledgr_candidate()`;
- row order in `candidate_summary_json` is preserved;
- params round-trip through `params_json`;
- provenance round-trips through `provenance_json`;
- warning counts and warning class arrays are serialized correctly;
- failed candidates appear in the selection-view summary when present;
- promotion note is stored and recovered.

## Horizon Entry

Keep the existing horizon entry for promotion-grade sweep artifacts. Add a
separate future note only if source-universe tracking remains important after
the v0.1.8 implementation:

```text
[sweep] Source candidate universe in promotion context

Future: when ledgr_sweep_results implements dplyr reconstruction or full sweep
artifacts exist, add source_candidate_summary_json alongside the selection-view
summary so promotion context captures the full candidate universe separately
from the user's filtered selection view.
```

## Patch Source

Use this decision document as the source for v0.1.8 spec and UX patches.

Do not infer accepted scope from earlier drafts where this document contradicts
them.
