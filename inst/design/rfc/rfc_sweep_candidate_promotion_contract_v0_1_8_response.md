# RFC Response: Sweep Candidate Promotion Contract For v0.1.8

**Status:** Reviewer response.
**Date:** 2026-05-13
**RFC:** `inst/design/rfc/rfc_sweep_candidate_promotion_contract_v0_1_8.md`
**Reviewer:** Claude (Sonnet 4.6)

---

## Overall Assessment

The RFC diagnoses a real gap in the v0.1.8 spec. The existing spec (§4.4)
routes RNG contract metadata — including derived candidate seed — to object
attributes. The RFC correctly argues that the derived seed must also live as a
visible row-level column so it travels with the candidate after
`filter()`/`arrange()` operations. That is the right resolution of the
ambiguity left by the RNG RFC response.

The typed candidate / promotion helper proposal is sound in shape. Two scope
corrections before ticket cut:

1. `execution_seed` as a visible column is output-handler work that belongs in
   the sweep extraction ticket. It is not separable from the sweep result.
2. `ledgr_candidate()` / `ledgr_promote()` / `ledgr_sweep_candidate` are a
   separate promotion ticket within v0.1.8. They do not touch the fold core,
   output handler, or sweep dispatcher, so they can be developed independently
   once sweep is landed.

The spec promotion example at §4.3 must be replaced. It models manual
extraction of `params[[1]]`, which will become a footgun once
`execution_seed` exists as a separate column that must accompany the params.

---

## Correction 1: The RNG RFC Response Left Attribute-vs-Column Ambiguous

The RNG RFC response (item 5 under v0.1.8 Must-Have) says:

> Sweep candidates should record `master_seed` and `derived_seed` (or `NULL`)
> in result attributes or as metadata columns.

The spec (§4.4) resolved this as: derived candidate seed goes into object
attributes, alongside snapshot identity, strategy identity, and other
result-level metadata.

This RFC correctly identifies the problem: attributes do not survive intact
across the operations users will perform on sweep results before promoting.
After:

```r
results |>
  dplyr::filter(status == "DONE") |>
  dplyr::arrange(dplyr::desc(sharpe_ratio)) |>
  dplyr::slice(1)
```

the resulting single-row tibble may not carry the original attributes, or
carries them without modification even though slice operations do not update
them. A user who then extracts `execution_seed` from the surviving row's column
value gets the right seed. A user who reads it from an attribute on the sliced
object gets undefined behavior.

The resolution: `execution_seed` is a visible column. `master_seed` remains
in result-level attributes because it is constant across all rows and is not a
per-candidate value. The ambiguous sentence in the RNG RFC response is resolved
in this RFC's favor.

---

## Correction 2: `execution_seed` Belongs In The Sweep Output Handler Ticket

The RFC's recommended spec changes list `execution_seed` as a column to add.
From a ticket-scope perspective: the sweep output handler produces the
`ledgr_sweep_results` object. Whatever columns that object must have are part
of the sweep output handler ticket, not a separate promotion ticket.

`execution_seed` must be populated by the sweep dispatcher before candidate
dispatch (because that is when the derived seed is computed) and forwarded
through the output handler into the result row. This happens inside the sweep
machinery, not in the promotion helper.

Implementation consequence: the sweep extraction ticket defines the column
schema including `execution_seed`. The promotion ticket (`ledgr_candidate()` /
`ledgr_promote()`) consumes the column; it does not define it.

---

## Correction 3: `ledgr_sweep_candidate` Must Carry Explicit Result-Level Metadata

The RFC says the candidate object "retains candidate row fields plus relevant
result-level metadata" without specifying which metadata.

This must be specified before implementation begins. The promotion helper is
only useful if the candidate object is self-contained: a user who saves a
`ledgr_sweep_candidate` to a variable, closes the session, and reopens the RDS
should be able to promote it without holding a reference to the original
`ledgr_sweep_results` object.

Minimum result-level metadata to copy onto `ledgr_sweep_candidate`:

- `master_seed` (integer or `NULL`);
- seed derivation contract/version;
- source experiment identity: snapshot hash, strategy identity, feature union
  fingerprint;
- `evaluation_scope`.

These can be stored as a named list in a single `sweep_meta` attribute on the
`ledgr_sweep_candidate` object. The fields must be documented alongside the
class definition.

---

## Scope Split

### Sweep Extraction Ticket (must accompany `ledgr_sweep()` landing)

**Add `execution_seed` as a visible column in `ledgr_sweep_results`.**

Column type: `integer`. Value: the derived fold seed passed to the fold core for
this candidate. `NA_integer_` when the sweep seed was `NULL`.

The column is populated by the sweep dispatcher at derivation time. The output
handler receives the seed alongside other candidate-level metadata and writes it
into the result row.

The visible column list in §4.4 grows from 17 to 18. `execution_seed` belongs
after `feature_fingerprints`, before or after RNG columns per implementation
judgment.

**Update §4.4 attribute spec.**

Remove "derived candidate seed" from the RNG contract metadata listed in the
attributes block. Keep `master_seed` and derivation contract/version in
attributes because they are result-level constants. Per-candidate values
(`execution_seed`) live in the visible column.

**Replace the §4.3 promotion example.**

The current example shows:

```r
winner <- results |>
  dplyr::filter(status == "DONE") |>
  dplyr::arrange(dplyr::desc(total_return)) |>
  dplyr::slice(1) |>
  dplyr::pull(params) |>
  .[[1]]

bt <- exp |>
  ledgr_run(params = winner, run_id = "momentum_v1")
```

This must be replaced with the `ledgr_candidate()` / `ledgr_promote()` pattern
once the promotion ticket lands. Until then, add a comment that the manual
extraction pattern is a placeholder:

> This example shows manual param extraction for clarity. The v0.1.8
> promotion ticket replaces this with `ledgr_candidate()` and
> `ledgr_promote()`, which carry params and execution seed together.

### Promotion Ticket (separate, within v0.1.8)

**`ledgr_candidate()`**

```r
ledgr_candidate(results, label_or_index)
```

- `label_or_index`: character label selects by `run_id`; integer or
  double scalar selects by row position after any user filtering/sorting.
  Both forms must be handled; a double input of `1` must behave identically to
  `1L`. Non-scalar, non-finite, or out-of-range values are errors.
- Resolves to exactly one row or errors.
- Failed candidates error by default. `allow_failed = TRUE` suppresses the
  error for diagnostic use only. Do not document `allow_failed = TRUE` as a
  promotion path.
- The returned `ledgr_sweep_candidate` object carries all visible row fields
  and the result-level metadata listed in Correction 3.

**`ledgr_promote()`**

```r
ledgr_promote(exp, candidate, run_id, require_same_snapshot = FALSE)
```

Internal call:

```r
ledgr_run(
  exp,
  params    = candidate$params,
  run_id    = run_id,
  seed      = if (is.na(candidate$execution_seed)) NULL
              else candidate$execution_seed
)
```

The `seed = NULL` path when `execution_seed` is `NA` must be explicit in the
implementation and documented. A user who promotes a candidate from a
deterministic (unseeded) sweep should not receive an error; the promoted run
simply has `seed = NULL`.

`require_same_snapshot = FALSE` is the correct default. Train/test promotion —
sweeping on a train snapshot and promoting onto a test experiment — is a first-
class workflow per §4.5. Defaulting to a warning or abort would break every
train/test user. Keep the binary: `TRUE` aborts when snapshot hash differs,
`FALSE` allows any experiment without warning.

`ledgr_promote()` must not create a new execution path. It is a thin wrapper
around `ledgr_run()` that unboxes the candidate's list columns and forwards the
right seed. The fold core is unchanged.

**`ledgr_sweep_candidate` print method**

The print method should display: candidate `run_id`, `status`, key metrics
(total_return, sharpe_ratio, max_drawdown), `params`, `execution_seed`, and
`sweep_meta$master_seed`. `execution_seed` should format as `-` when `NA` so
users visually understand that no seed was applied.

---

## Responses To Open Questions

### 1. `ledgr_promote()` vs `ledgr_run_candidate()`?

`ledgr_promote()` is the right name.

`ledgr_run_candidate()` implies running candidates — which is `ledgr_sweep()`'s
job. `ledgr_promote()` describes the semantic action: a sweep candidate is
promoted to a committed, durable experiment-store run. The verb is correct.

### 2. Should `execution_seed` appear in default print?

Yes. Show it. Format `NA_integer_` as `-`.

`execution_seed` is a first-class column in the promotion contract. Hiding it
would be inconsistent with its importance. For the many v0.1.8 runs where it is
NA (deterministic strategies without a sweep seed), the `-` formatting makes the
absence informative rather than cluttered.

For `ledgr_sweep_results` print output, `execution_seed` should appear in a
curated-column display alongside `run_id`, `status`, `sharpe_ratio`, and
`params`. Its presence there trains users to expect it when they move to
stochastic strategies.

### 3. Should `ledgr_candidate()` error on failed candidates always?

Error by default, `allow_failed = TRUE` as escape hatch. This is correct.

Failed candidates should not be accidentally promoted. The default error is the
safety rail. `allow_failed = TRUE` covers the diagnostic use case: a user who
wants to inspect the error state of a specific candidate by label. It should not
be in the main documentation flow.

### 4. Promotion-grade manifest/export helper?

Defer. The RDS path is sufficient for v0.1.8. The question of
`params_json` / `ledgr_sweep_manifest()` for flat exports is real but belongs
after the first stochastic sweep workflows establish what users actually need.
Premature serialization format commits are expensive to break.

---

## Additional Finding: Train/Test Promotion Is The First-Class Case

The RFC's train/test example:

```r
candidate <- train_results |>
  dplyr::filter(status == "DONE") |>
  dplyr::arrange(dplyr::desc(sharpe_ratio)) |>
  ledgr_candidate(1)

bt_test <- test_exp |>
  ledgr_promote(candidate, run_id = "momentum_v1_test")
```

is the natural implementation of the evaluation discipline spec (§4.5), which
currently shows only prose. This example should become the canonical promotion
example in the first sweep vignette, not the same-snapshot replay case.

The same-snapshot exact replay use case (`require_same_snapshot = TRUE`) is
important but secondary. Most users promote candidates onto a different snapshot
(held-out test data or a new live experiment). The promotion API should be
written and documented from the perspective of the train/test user first, with
same-snapshot replay as an explicit assertion option.

---

## Additional Finding: Run Recovery Already Works For Seeds

The RFC requires `ledgr_run_info()` to include `seed`. This is already
satisfied: `engine.seed` is stored in `config_json` as confirmed during the RNG
RFC review, and `ledgr_run_info()` returns config metadata. The only new work
is ensuring the public display surface shows the seed in a human-readable way:
`seed: <none>` for `NULL`, `seed: 123456789` for a supplied integer. This is a
print/display change, not a storage change.

---

## Proposed Spec Updates If Accepted

1. Add `execution_seed` (integer) to §4.4 visible columns (18 total). Document
   that `NA_integer_` means no fold seed was applied.
2. Remove "derived candidate seed" from the §4.4 attribute block. Retain
   `master_seed` and derivation contract/version in attributes.
3. Add a note to the §4.3 example that manual extraction is a placeholder for
   the promotion-ticket helpers.
4. Add §4.6 "Candidate Promotion API" covering `ledgr_candidate()`,
   `ledgr_promote()`, and `ledgr_sweep_candidate` with the train/test example
   as the primary illustration.
5. State in §4.6 that same-snapshot replay with identical params and
   `execution_seed` must reproduce the sweep candidate result. This is the
   forward-looking parity requirement.
6. Add two new tickets to §12:
   - Promotion ticket: `ledgr_candidate()`, `ledgr_promote()`,
     `ledgr_sweep_candidate` S3 class, print method, `execution_seed` → seed
     forwarding in `ledgr_promote()`.
   - Run recovery display: `ledgr_run_info()` seed surface,
     `seed: <none>` / `seed: N` in print output.
7. Add to §11 test list: `ledgr_candidate()` label selection, position
   selection, and error-on-failed; `ledgr_promote()` forwarding params and
   seed; `ledgr_promote()` with `require_same_snapshot = TRUE` aborting on
   snapshot mismatch; `execution_seed = NA` → `seed = NULL` in promoted run.

---

## Summary

Accept the RFC's core direction with the following adjustments:

- Resolve the RNG RFC response ambiguity: `execution_seed` is a row-level
  visible column; `master_seed` stays in result-level attributes.
- Assign `execution_seed` population to the sweep extraction ticket, not the
  promotion ticket.
- Specify explicitly that `ledgr_sweep_candidate` carries a fixed set of
  result-level metadata attributes so it is self-contained for promotion.
- Specify `execution_seed = NA` → `seed = NULL` in `ledgr_promote()`.
- Default `require_same_snapshot = FALSE` is correct; do not add a default
  warning for different-snapshot promotion because train/test is the
  normal workflow.
- Show `execution_seed` in default print, formatted as `-` when NA.
- Establish train/test promotion as the primary promotion example in docs.
- Defer run-recovery display changes to their own narrow ticket.
- Defer manifest/export helper until stochastic usage establishes real needs.
