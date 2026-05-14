# RFC: Sweep Candidate Promotion Contract For v0.1.8

**Status:** Draft RFC for v0.1.8 spec decision.
**Date:** 2026-05-13
**Author:** Codex
**Related documents:**

- `inst/design/ledgr_v0_1_8_spec_packet/v0_1_8_spec.md`
- `inst/design/architecture/ledgr_sweep_mode_ux.md`
- `inst/design/rfc/rfc_rng_contract_v0_1_8.md`
- `inst/design/rfc/rfc_rng_contract_v0_1_8_response.md`

## Purpose

v0.1.8 sweep introduces a new user workflow:

```text
evaluate candidates -> select candidate -> commit with ledgr_run()
```

The current sweep UX demonstrates promotion by manually extracting `params`
from the selected row and passing them to `ledgr_run()`. That is sufficient for
deterministic strategies, but it is not sufficient once v0.1.8 accepts explicit
execution seeds.

For stochastic strategies, promotion must replay the exact candidate evaluation,
not re-run the same params with a different seed. Therefore the sweep result row
must carry the actual seed used by that candidate, and ledgr should provide a
promotion helper so users do not have to remember how to unpack list columns.

## Design Principle

Promotion is replay of one candidate, not a new stochastic draw.

The promotion contract is:

```text
sweep input seed -> master_seed
candidate label  -> execution_seed
promoted run     -> ledgr_run(params = candidate params, seed = execution_seed)
```

For `ledgr_run()`, the supplied seed is the fold seed. For `ledgr_sweep()`, the
supplied seed is a master seed, and the sweep dispatcher derives one
`execution_seed` per candidate before candidate evaluation.

If the promoted run uses the same experiment snapshot, same params, same
features, same opening state, same execution assumptions, and the candidate's
`execution_seed`, then the promoted `ledgr_run()` must produce the same
semantic result as the sweep candidate.

If the promoted run uses a different snapshot, as in train/test evaluation, the
helper still carries the same params and seed into the new experiment. The
result is a held-out evaluation, not an exact replay.

## Row-Level Seed Requirement

`execution_seed` must be a row-level field in `ledgr_sweep_results`.

It is not enough to store derived seeds only in object attributes, because the
sweep result table is the promotion surface and may be saved as a research
artifact. Attributes are fragile across common table operations and export
paths; the seed that makes a candidate replayable must travel with the row.

Recommended column:

| Column | Type | Meaning |
| --- | --- | --- |
| `execution_seed` | integer | Actual fold seed used by this candidate; `NA_integer_` when sweep seed was `NULL` |

Result-level metadata should still record:

- `master_seed`;
- seed derivation helper name;
- seed derivation contract/version;
- RNG kind metadata if implemented.

The seed must not be hidden inside `params`. Strategy params and execution
identity are separate concepts.

## Promotion Helper

Users should not have to write:

```r
params = winner$params[[1]]
seed = winner$execution_seed
```

That is too easy to get wrong, especially once ranking, filtering, and
train/test workflows are involved.

The recommended UX is a typed candidate object plus a promotion helper.

### Candidate Selection

`ledgr_candidate()` extracts exactly one promotion-ready row from
`ledgr_sweep_results`.

Recommended examples:

```r
candidate <- results |>
  ledgr_candidate("conservative")
```

For caller-owned ranking:

```r
candidate <- results |>
  dplyr::filter(status == "DONE") |>
  dplyr::arrange(dplyr::desc(sharpe_ratio)) |>
  ledgr_candidate(1)
```

Expected behavior:

- character input selects by sweep `run_id` candidate label;
- integer input selects by row position after any user filtering/sorting;
- selection must resolve to exactly one row;
- failed candidates error by default;
- the returned object has class `ledgr_sweep_candidate`;
- the object retains candidate row fields plus relevant result-level metadata.

### Candidate Promotion

`ledgr_promote()` commits a selected candidate through `ledgr_run()`.

Recommended examples:

```r
candidate <- results |>
  ledgr_candidate("conservative")

bt <- exp |>
  ledgr_promote(candidate, run_id = "momentum_v1")
```

For train/test discipline:

```r
candidate <- train_results |>
  dplyr::filter(status == "DONE") |>
  dplyr::arrange(dplyr::desc(sharpe_ratio)) |>
  ledgr_candidate(1)

bt_test <- test_exp |>
  ledgr_promote(candidate, run_id = "momentum_v1_test")
```

Internal behavior:

```r
ledgr_promote(exp, candidate, run_id = run_id)
```

must call the committed run path with:

```text
params = candidate params
seed   = candidate execution_seed, or NULL when execution_seed is NA
run_id = explicit user-supplied run_id
```

The helper must not create a new execution path. It is a small wrapper around
`ledgr_run()` and must share the same fold core.

## Same-Snapshot Replay

For exact replay checks, `ledgr_promote()` may support an optional assertion:

```r
ledgr_promote(exp, candidate, run_id = "momentum_v1", require_same_snapshot = TRUE)
```

If `require_same_snapshot = TRUE`, the helper aborts when the experiment
snapshot hash differs from the candidate's source snapshot hash.

The default should allow different snapshots, because train/test promotion is a
normal workflow:

```text
train snapshot -> sweep candidate -> promote candidate on test snapshot
```

Different-snapshot promotion is validation, not replay.

## Run Recovery

The committed run must expose the actual seed used to produce it.

Required recovery surfaces:

- `ledgr_run_info()` includes `seed`;
- strategy extraction/recovery returns the seed alongside
  `strategy_function` and `strategy_params`;
- run summary/print output displays the seed, for example `seed: <none>` or
  `seed: 123456789`.

This makes the committed run structurally replayable:

```text
snapshot + strategy_function + strategy_params + seed + execution assumptions
```

## Artifact Implications

v0.1.8 does not need to auto-save sweep artifacts. However, because users will
save sweep results themselves, the result object should be robust when saved as
an R object:

```r
saveRDS(results, "sweep_results.rds")
```

R-native artifacts preserve list columns such as `params` and integer columns
such as `execution_seed`. Flat CSV exports are useful for inspection but are not
promotion-grade unless a future manifest/export helper serializes params
explicitly.

Open future design question:

```text
Should ledgr add params_json or a ledgr_sweep_manifest() export so non-RDS
artifacts can be promotion-grade?
```

This is not required for v0.1.8 if the documented promotion path uses live
`ledgr_sweep_results` objects or RDS-preserved result objects.

## Required Spec Changes If Accepted

If this RFC is accepted, the v0.1.8 spec and UX docs should change as follows:

1. Add visible `execution_seed` to `ledgr_sweep_results`.
2. Keep `master_seed` and derivation metadata at result-object level.
3. Update promotion examples to use `ledgr_candidate()` and `ledgr_promote()`.
4. State that same-snapshot promotion with the same params and
   `execution_seed` must reproduce the sweep candidate.
5. Add tests for `ledgr_candidate()` selection by label and row position.
6. Add tests that `ledgr_promote()` passes params and execution seed to
   `ledgr_run()`.
7. Add tests that `ledgr_run_info()` and strategy recovery expose the committed
   seed.
8. Add docs explaining that different-snapshot promotion is validation, not
   exact replay.

## Non-Goals

This RFC does not require:

- automatic persistence of all sweep result tables;
- a public parallel sweep API;
- `ctx$seed()` helpers;
- a public stochastic-strategy helper surface;
- storing seed inside strategy params;
- a new execution engine;
- `ledgr_tune()`.

## Open Questions

1. Is `ledgr_promote()` the right helper name, or should the public helper be
   more explicit, such as `ledgr_run_candidate()`?
2. Should `execution_seed` be shown by the default print method or hidden with
   other promotion columns?
3. Should `ledgr_candidate()` error on failed candidates always, or allow
   `allow_failed = TRUE` for diagnostics?
4. Should v0.1.8 add a promotion-grade manifest/export helper, or defer that
   until users need non-RDS sweep artifacts?

## Recommendation

Accept the row-level `execution_seed` requirement and the typed promotion
helper pattern for v0.1.8.

This keeps the promotion workflow elegant while preserving the strict replay
contract:

```text
sweep candidate row -> ledgr_sweep_candidate -> ledgr_promote() -> ledgr_run()
```

Users get a simple API. ledgr keeps exact control over params, seed, snapshot
identity, and execution semantics.
