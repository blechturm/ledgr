# RFC: Sweep Promotion Context For v0.1.8

**Status:** Draft RFC for review.
**Date:** 2026-05-14
**Author:** Codex
**Related documents:**

- `inst/design/rfc/rfc_sweep_candidate_promotion_contract_v0_1_8.md`
- `inst/design/rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_response.md`
- `inst/design/rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis.md`
- `inst/design/rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis_response.md`
- `inst/design/ledgr_v0_1_8_spec_packet/v0_1_8_spec.md`
- `inst/design/architecture/ledgr_sweep_mode_ux.md`

## Purpose

This RFC proposes a v0.1.8 promotion-context contract.

The core question is:

```text
When a sweep candidate is promoted to a committed ledgr_run(), can the committed
run explain the candidate universe it came from?
```

The answer should be yes.

v0.1.8 does not need to persist every sweep as a standalone replayable artifact.
But when a user promotes a selected candidate, the committed run should carry a
durable summary of the sweep context that produced that selection.

This gives ledgr a stronger audit story:

```text
The run is reproducible, and its selection context is inspectable.
```

## Problem

The v0.1.8 sweep workflow is:

```text
sweep candidate grid -> select one candidate -> ledgr_run()
```

The committed run stores durable provenance for the selected execution. That is
necessary but not sufficient to understand the research decision.

A future reader of the committed run should be able to answer:

```text
Which sweep did this run come from?
How many alternatives were considered?
What were the metrics of the alternatives?
Which params and seed were selected?
Were there failed candidates?
Was this an exploratory, train, or test evaluation context?
```

Without this, a promoted run can be perfectly reproducible while still hiding
the selection process that produced it.

## Non-Goal: Full Sweep Persistence

This RFC does not propose full sweep persistence for v0.1.8.

Full sweep persistence would mean something like:

```r
ledgr_save_sweep(results, path)
ledgr_load_sweep(path)
ledgr_verify_sweep_sources(results, search_paths)
```

That is useful, especially for expensive sweeps, but it creates a larger
artifact/replay system:

- locating the original snapshot file;
- recovering strategy source;
- recovering feature factories;
- validating package versions;
- rerunning all candidates;
- comparing old and new sweep results.

That belongs in a future design. v0.1.8 should solve the narrower and more
important first problem: every promoted run should explain the sweep superset it
was selected from.

## Proposed Contract

When `ledgr_promote()` commits a candidate through `ledgr_run()`, it attaches a
durable `promotion_context` to the committed run.

The promotion context is a compact selection-audit record, not a replayable
sweep artifact.

Recommended structure:

```r
promotion_context <- list(
  promotion_context_version = "ledgr_promotion_v1",
  source = "ledgr_sweep",
  promoted_at_utc = "...",

  selected_candidate = list(
    run_id = "conservative",
    params = list(...),
    execution_seed = 98234117L,
    provenance = list(...)
  ),

  source_sweep = list(
    sweep_id = "...",
    snapshot_hash = "...",
    strategy_hash = "...",
    feature_union_hash = "...",
    master_seed = 123L,
    seed_contract = "ledgr_seed_v1",
    evaluation_scope = "exploratory",
    n_candidates = 48L
  ),

  candidate_summary = tibble::tibble(
    run_id = ...,
    status = ...,
    final_equity = ...,
    total_return = ...,
    annualized_return = ...,
    volatility = ...,
    sharpe_ratio = ...,
    max_drawdown = ...,
    n_trades = ...,
    win_rate = ...,
    avg_trade = ...,
    time_in_market = ...,
    execution_seed = ...,
    params = ...,
    provenance = ...,
    error_class = ...,
    error_msg = ...
  )
)
```

The exact storage format is an implementation detail, but the semantic fields
must be recoverable from the committed run.

## What This Enables

The promoted run can answer selection-audit questions without requiring the
user to locate the original unsaved sweep object.

Examples:

```r
info <- ledgr_run_info(exp, "momentum_v1_test")
info$promotion_context$source_sweep$n_candidates
info$promotion_context$candidate_summary
```

Potential helper:

```r
ledgr_promotion_context(bt)
```

or:

```r
ledgr_run_promotion_context(exp, run_id = "momentum_v1_test")
```

This should be a read API over stored run metadata. It must not create a new
execution path.

## Storage Scope

The promotion context should be stored with the committed run, not as an
independent sweep artifact.

Possible storage locations:

1. run metadata JSON;
2. a dedicated `run_promotion_context` table;
3. provenance payload extension if existing provenance storage supports nested
   records safely.

The implementation ticket should choose the storage location based on existing
run-store conventions. The contract is the recoverable semantic content, not
the physical schema.

## Candidate Summary Scope

The candidate summary should be compact. It should include:

- candidate labels;
- candidate status;
- standard summary metrics;
- params;
- execution seed;
- row-level provenance;
- error class/message.

It should not include:

- full ledger event streams for every candidate;
- full equity curves for every candidate;
- feature matrices;
- full strategy source per row;
- full feature definitions per row.

Those are full sweep artifact concerns and are out of scope for v0.1.8.

## Duplication Tradeoff

If a user promotes multiple candidates from the same sweep, each committed run
may store the same candidate summary.

That duplication is acceptable in v0.1.8 because:

- it avoids a new durable sweep-artifact registry;
- candidate summaries are small relative to ledger/equity artifacts;
- it keeps each promoted run self-contained from a selection-audit perspective;
- it avoids needing a sweep ID namespace before sweep persistence exists.

A future `ledgr_save_sweep()` design can reduce duplication by storing a shared
sweep artifact and letting promoted runs reference it.

## User Workflow

Primary train/test workflow:

```r
candidate <- train_results |>
  dplyr::filter(status == "DONE") |>
  dplyr::arrange(dplyr::desc(sharpe_ratio)) |>
  ledgr_candidate(1)

bt_test <- test_exp |>
  ledgr_promote(candidate, run_id = "momentum_v1_test")
```

After promotion:

```r
ctx <- ledgr_promotion_context(bt_test)
ctx$selected_candidate$run_id
ctx$source_sweep$n_candidates
ctx$candidate_summary
```

The user can inspect the selected candidate and alternatives without needing to
reload the original sweep result object.

## Relationship To `ledgr_sweep_results`

`ledgr_sweep_results` remains an in-memory result table in v0.1.8. It is not
automatically persisted as a run artifact.

`ledgr_promote()` is the bridge:

```text
ledgr_sweep_results -> ledgr_sweep_candidate -> ledgr_promote() -> ledgr_run()
```

At promotion time, ledgr copies the compact selection context from the source
sweep result/candidate into the committed run.

If a user calls `ledgr_run()` directly without `ledgr_promote()`, there is no
promotion context.

## Relationship To Full Sweep Replay

Promotion context supports:

```text
selection audit
candidate comparison after promotion
understanding the superset from which a run was selected
```

It does not support:

```text
rerunning the whole sweep from disk
locating the original snapshot file automatically
recovering feature factories automatically
recovering strategy source beyond existing ledgr strategy recovery
```

Those belong to future sweep artifact work.

## Future Horizon Entry

If this RFC is accepted, add a horizon note for full sweep artifacts:

```text
YYYY-MM-DD [sweep] Promotion-grade sweep artifacts

Future design: save/load complete sweep result bundles with manifest, snapshot
locator hints, strategy/feature recovery metadata, package/version metadata, and
verification helpers. Useful for expensive sweeps and offline audit. Deferred
because v0.1.8 stores compact selection context on promoted runs instead.
```

## Required Spec Changes If Accepted

If accepted, patch the v0.1.8 spec to:

1. Define `promotion_context` as durable selection-audit metadata stored on runs
   created through `ledgr_promote()`.
2. Require `promotion_context_version = "ledgr_promotion_v1"`.
3. Define required fields for `selected_candidate`, `source_sweep`, and
   `candidate_summary`.
4. State that `ledgr_run()` without `ledgr_promote()` has no promotion context.
5. Add tests that `ledgr_promote()` stores promotion context.
6. Add tests that promotion context is recoverable through run info or a helper.
7. Add tests that candidate summary includes all candidates, not only the
   selected candidate.
8. Add a non-goal: no full sweep artifact save/load in v0.1.8.
9. Add the horizon note for future sweep artifact persistence.

## Open Questions For Review

1. Should promotion context live in existing run metadata JSON or a dedicated
   table?
2. Should v0.1.8 expose a public helper named `ledgr_promotion_context()`, or is
   `ledgr_run_info()` enough for first release?
3. Should `candidate_summary$params` remain a list column in stored metadata, or
   be stored as canonical JSON for long-term stability?
4. Should `warnings` be included in `candidate_summary`, or only
   `error_class`/`error_msg`?
5. Should the promotion context include the candidate ranking order at promotion
   time, or only the raw candidate table?

## Recommendation

Accept promotion context for v0.1.8.

Do not auto-persist full sweeps yet. Instead, make promoted runs
selection-auditable by storing the compact sweep superset that produced the
selected candidate.

This keeps v0.1.8 scoped while reinforcing ledgr's core value:

```text
not just reproducible runs, but auditable research decisions
```
