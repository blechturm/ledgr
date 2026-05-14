# Synthesis: Sweep Candidate Promotion And Lineage Contract For v0.1.8

**Status:** Draft synthesis for review.
**Date:** 2026-05-14
**Author:** Codex
**Inputs:**

- `inst/design/rfc/rfc_sweep_candidate_promotion_contract_v0_1_8.md`
- `inst/design/rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_response.md`
- `inst/design/rfc/rfc_rng_contract_v0_1_8.md`
- `inst/design/rfc/rfc_rng_contract_v0_1_8_response.md`
- `inst/design/architecture/ledgr_sweep_mode_ux.md`
- `inst/design/ledgr_v0_1_8_spec_packet/v0_1_8_spec.md`

## Purpose

This synthesis resolves the promotion and candidate-lineage design questions
before patching the v0.1.8 spec and sweep UX documents.

The motivating problem is simple:

```text
A sweep result row is the user's promotion surface.
That row must carry enough identity to understand and safely promote it.
```

The original promotion RFC correctly identified that stochastic promotion needs
the actual per-candidate execution seed. Claude's response accepted that
direction and clarified ticket scope. The remaining UX gap is broader than RNG:
after filtering, sorting, slicing, saving, or handing one candidate to an
agent, the user should still be able to answer:

```text
Which snapshot was this evaluated on?
Which strategy identity produced it?
Which feature set did this candidate use?
Which params and execution seed should be promoted?
```

Object attributes alone are too fragile for that job. Full durable provenance
in every row would be too heavy. The synthesis below chooses a middle path:
compact row-level lineage keys, rich result-level metadata, and durable
provenance only after `ledgr_run()`.

## Decision Summary

Accept the promotion RFC with amendments:

1. `execution_seed` is a visible row-level column in `ledgr_sweep_results`.
2. Compact lineage is row-level, either as scalar columns or as a `provenance`
   list column. The recommended first design is a hybrid: `execution_seed` as
   a scalar column plus `provenance` as a typed list column.
3. Full sweep metadata remains in object attributes and is copied into
   `ledgr_sweep_candidate` as a `sweep_meta` attribute.
4. `ledgr_candidate()` extracts one typed candidate row and preserves row
   fields plus required sweep metadata.
5. `ledgr_promote()` is the public helper that commits a candidate by calling
   `ledgr_run()` with the candidate params and `execution_seed`.
6. Train/test promotion is the primary documentation example.
7. Same-snapshot replay is supported by an explicit
   `require_same_snapshot = TRUE` assertion.
8. Manifest or flat-file promotion exports are deferred.

## Three Identity Levels

The design separates identity into three levels.

### 1. Candidate Row Identity

Candidate row identity is the compact, sliceable, saveable identity needed to
inspect, rank, select, and promote a candidate.

Recommended row-level fields:

| Column | Type | Meaning |
| --- | --- | --- |
| `run_id` | chr | Sweep candidate label, not a committed run ID |
| `status` | chr | Candidate status, for example `DONE` or `FAILED` |
| `params` | list | Full strategy params for this candidate |
| `execution_seed` | int | Actual fold seed used by this candidate; `NA_integer_` when unseeded |
| `provenance` | list | Compact candidate lineage bundle |
| `feature_fingerprints` | list | Resolved feature identities required by this candidate |
| `warnings` | list | Candidate warnings and non-fatal interpretation conditions |
| `error_class` | chr | Error class on failure |
| `error_msg` | chr | Error message on failure |

Metric columns remain as already proposed:

```text
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
```

The row-level fields are not full provenance. They are compact lineage values
that make a candidate understandable and promotion-safe after ordinary table
operations.

The recommended `provenance` list-column entry is a typed named list with stable
fields such as:

```r
list(
  snapshot_hash = "...",
  strategy_hash = "...",
  feature_set_hash = "...",
  master_seed = 123L,
  seed_contract = "ledgr_seed_v1",
  evaluation_scope = "exploratory"
)
```

`execution_seed` is intentionally scalar rather than nested because it is not
only provenance; it is the execution argument required to replay or promote the
candidate. Keeping it visible trains users to notice it, makes print output
clear, and avoids forcing promotion code to dig into nested metadata for the
most operationally important value.

### 2. Sweep Object Identity

Sweep object identity is metadata for the complete `ledgr_sweep_results`
object.

Recommended result-level metadata:

- `master_seed`;
- seed derivation helper name and contract/version;
- snapshot id and snapshot hash;
- strategy identity and preflight result;
- feature union fingerprint and feature engine metadata;
- opening state;
- fill/cost assumptions;
- evaluation scope;
- ledgr version and created timestamp if available.

This metadata is useful for printing, audit, and promotion support. It is not
durable experiment-store provenance.

### 3. Committed Run Provenance

Committed run provenance is created only by `ledgr_run()`.

It includes the durable run configuration, snapshot identity, strategy identity,
params hash, seed, execution assumptions, ledger/equity rows, metrics, and
stored provenance/recovery fields.

Sweep should not pretend to be this. Sweep provides candidate identity and
promotion support; `ledgr_run()` creates the durable artifact.

## Why Row-Level Lineage Is Needed

The current design puts snapshot identity, strategy identity, feature identity,
and RNG metadata mostly in object attributes. That is compact but weak in the
exact places users will touch sweep results:

```r
winner <- results |>
  dplyr::filter(status == "DONE") |>
  dplyr::arrange(dplyr::desc(sharpe_ratio)) |>
  dplyr::slice(1)
```

After this pipeline, relying on result-level attributes is unsafe unless ledgr
implements and tests strict reconstruction methods. Even then, attributes are
awkward for agent and human inspection.

The seed issue is promotion-critical:

```text
same params + wrong seed = different stochastic candidate
```

The lineage issue is interpretability-critical:

```text
candidate row without snapshot/strategy/feature identity is hard to audit
```

Therefore `execution_seed` must be row-level. Snapshot, strategy, and feature
lineage must also be row-level, either as scalar columns or as fields inside a
row-level `provenance` list column.

## Column Name Rationale

Use hashes, not user-facing names, as compact lineage keys.

- `snapshot_hash` is already an artifact identity concept.
- `strategy_hash` should refer to the accepted strategy identity hash for the
  strategy/preflight surface.
- `feature_set_hash` is a compact hash of the candidate's resolved
  `feature_fingerprints`.

Do not add `strategy_id` unless ledgr already has a stable public concept with
that name. A hash is less friendly but more precise.

Do not add full feature definitions or strategy source to every row. Those
belong in sweep metadata and committed run provenance.

## Scalar Columns Versus `provenance` List Column

There are two acceptable row-level lineage shapes.

### Option A: Scalar Lineage Columns

```text
execution_seed
snapshot_hash
strategy_hash
feature_set_hash
```

This is easiest to filter, join, and inspect with dplyr. It also exports better
to flat formats. The downside is that the result table becomes wider and any
future lineage key requires another top-level column.

### Option B: Nested Provenance Column

```text
execution_seed
provenance
```

where `provenance` is a list column of typed named lists. This keeps the table
compact and tidy while preserving row-level lineage through `filter()`,
`arrange()`, `slice()`, and RDS saves. The downside is that filtering by lineage
requires unnesting or helper accessors, and CSV export is not promotion-grade.

### Recommendation

Use the hybrid:

```text
execution_seed
provenance
```

The scalar `execution_seed` is promotion-critical. Snapshot, strategy, feature,
master seed, seed-contract, and evaluation-scope lineage belong together in the
row-level `provenance` list column.

The default print method should show `execution_seed`. It may hide
`provenance`, while `print.ledgr_sweep_candidate()` should render the
provenance fields in a readable block.

## Feature Identity Detail

`feature_fingerprints` remains a candidate-specific list column.

`feature_set_hash` is derived from that candidate's normalized fingerprint set.
It is useful for scanning and joining. It should differ when indicator params
change the resolved feature set.

The result-level feature metadata still stores the union of all feature
fingerprints requested by the sweep and any precompute metadata needed to
validate the sweep object.

## Seed Detail

`execution_seed` is the actual fold seed for the candidate.

Rules:

- if `ledgr_sweep(seed = NULL)`, `execution_seed` is `NA_integer_`;
- if `ledgr_sweep(seed = 123)`, each candidate has an integer
  `execution_seed` derived by the sweep dispatcher before candidate execution;
- promotion forwards `execution_seed` as the `seed` argument to `ledgr_run()`;
- `NA_integer_` maps to `seed = NULL` during promotion.

`master_seed` stays in result-level metadata because it is constant across the
sweep and is not sufficient for promotion by itself.

## Candidate Selection API

`ledgr_candidate()` extracts exactly one promotion-ready row from
`ledgr_sweep_results`.

Recommended signature:

```r
ledgr_candidate(results, label_or_index, allow_failed = FALSE)
```

Behavior:

- character input selects by `run_id`;
- integer input selects by row position after user filtering/sorting;
- double input equivalent to `1` is accepted as row position if finite and
  whole-numbered;
- non-scalar, non-finite, duplicate, or out-of-range selections error;
- failed candidates error unless `allow_failed = TRUE`;
- the return value has class `ledgr_sweep_candidate`;
- the candidate object carries all row fields;
- the candidate object carries required sweep metadata in `attr(x,
  "sweep_meta")`.

Minimum `sweep_meta` fields copied to the candidate object:

- `master_seed`;
- seed derivation contract/version;
- source snapshot hash;
- strategy hash and strategy identity metadata;
- feature union fingerprint;
- evaluation scope.

If a user passes a single-row tibble that no longer has required sweep metadata,
`ledgr_candidate()` should still return a candidate if the row-level promotion
fields are present, but metadata-dependent operations must fail clearly.

For example, `require_same_snapshot = TRUE` cannot be honored without
`provenance$snapshot_hash` or equivalent row-level snapshot lineage.

## Promotion API

`ledgr_promote()` commits a selected candidate through `ledgr_run()`.

Recommended signature:

```r
ledgr_promote(exp, candidate, run_id, require_same_snapshot = FALSE)
```

Internal behavior:

```text
params = candidate$params
seed   = candidate$execution_seed, or NULL when execution_seed is NA
run_id = explicit user run_id
```

The implementation is a thin wrapper around `ledgr_run()`. It must not create a
new execution path or bypass fold-core parity.

`require_same_snapshot = FALSE` is the correct default because train/test
promotion is first-class. If `require_same_snapshot = TRUE`, the helper compares
the candidate's row-level snapshot lineage against the target experiment
snapshot hash and aborts on mismatch.

Do not warn by default on different-snapshot promotion. That is the normal
validation workflow.

## Primary UX Example

The primary documentation example should be train/test promotion:

```r
candidate <- train_results |>
  dplyr::filter(status == "DONE") |>
  dplyr::arrange(dplyr::desc(sharpe_ratio)) |>
  ledgr_candidate(1)

bt_test <- test_exp |>
  ledgr_promote(candidate, run_id = "momentum_v1_test")
```

Same-snapshot replay is secondary:

```r
candidate <- results |>
  ledgr_candidate("conservative")

bt <- exp |>
  ledgr_promote(
    candidate,
    run_id = "momentum_v1_replay",
    require_same_snapshot = TRUE
  )
```

## Candidate Print UX

`print.ledgr_sweep_candidate()` should display a compact provenance block:

```text
# ledgr sweep candidate: conservative
status: DONE
snapshot: 8f3c1a...
strategy: 2a91b...
features: c733e...
seed: master 123, execution 98234117

metrics:
  sharpe_ratio: 1.21
  total_return: 12.3%
  max_drawdown: -8.1%

params:
  threshold: 0.005
  sma_n: 50
  qty: 10
```

For unseeded candidates, print `execution -` rather than `NA`.

The sweep table print method should show `execution_seed` in the curated view,
formatted as `-` when missing. The `provenance` list column may be hidden from
the default print view but must be present as ordinary row-level data.

## Artifact Guidance

v0.1.8 does not need to auto-save sweep artifacts.

R-native artifacts are enough for first release:

```r
saveRDS(results, "sweep_results.rds")
```

RDS preserves list columns and integer seed columns. Flat CSV exports are useful
for inspection but are not promotion-grade unless a future helper serializes
params and metadata explicitly.

Defer `params_json`, `ledgr_sweep_manifest()`, or promotion-grade flat export
until real usage shows what is needed.

## Required Spec Changes If Accepted

If this synthesis is accepted, patch the v0.1.8 spec and UX documents to:

1. Add row-level `execution_seed`.
2. Add row-level compact lineage, preferably a `provenance` list column with
   `snapshot_hash`, `strategy_hash`, `feature_set_hash`, `master_seed`,
   seed-contract, and evaluation-scope fields.
3. Keep `master_seed`, derivation contract/version, and rich metadata at the
   result-object level.
4. Define `ledgr_candidate()`, `ledgr_sweep_candidate`, and `ledgr_promote()`.
5. Make train/test promotion the primary example.
6. Replace manual `params[[1]]` extraction examples.
7. Add `ledgr_sweep_candidate` print expectations.
8. Add tests for:
   - row-level `execution_seed`;
   - row-level provenance lineage;
   - `feature_set_hash` changing when resolved candidate features change;
   - `ledgr_candidate()` label and row-position selection;
   - `ledgr_candidate()` failure on failed candidates by default;
   - metadata copied to `sweep_meta`;
   - behavior when metadata is missing but row-level promotion fields exist;
   - `ledgr_promote()` forwarding params and seed to `ledgr_run()`;
   - `execution_seed = NA_integer_` mapping to `seed = NULL`;
   - `require_same_snapshot = TRUE` aborting on snapshot mismatch;
   - same-snapshot promotion reproducing the sweep candidate for seeded
     stochastic strategies.

## Non-Goals

This synthesis does not require:

- automatic persistence of sweep result tables;
- promotion-grade flat-file export;
- a public parallel sweep API;
- `ctx$seed()` helpers;
- storing seed inside strategy params;
- full durable provenance in sweep rows;
- a new execution path;
- `ledgr_tune()`.

## Open Questions For Review

1. Is the hybrid shape (`execution_seed` scalar plus `provenance` list column)
   preferable to separate scalar lineage columns?
2. Is `feature_set_hash` per-candidate, derived from `feature_fingerprints`, the
   right level of detail?
3. Should `ledgr_candidate()` accept a plain one-row tibble with required
   columns, or require classed `ledgr_sweep_results` input?
4. Should missing `sweep_meta` be a hard error at candidate extraction time, or
   only when metadata-dependent operations are requested?
5. Should `execution_seed` be in the default sweep print view for all sweeps, or
   only when at least one candidate is seeded?

## Recommendation

Adopt the three-level identity model:

```text
candidate row identity  -> compact lineage and promotion fields
sweep object identity   -> rich in-memory metadata
committed run provenance -> durable ledgr_run artifact
```

Add row-level `execution_seed` and row-level provenance lineage, preferably via
a `provenance` list column. Add `ledgr_candidate()` and `ledgr_promote()` so
users do not manually unpack list columns or remember seed-forwarding rules.

This gives users a clean promotion workflow while preserving ledgr's strict
execution and replay contracts.
