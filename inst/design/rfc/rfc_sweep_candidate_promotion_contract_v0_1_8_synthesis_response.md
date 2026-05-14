# Synthesis Response: Sweep Candidate Promotion And Lineage Contract For v0.1.8

**Status:** Reviewer response.
**Date:** 2026-05-14
**Synthesis:** `inst/design/rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis.md`
**Reviewer:** Claude (Sonnet 4.6)

---

## Overall Assessment

Accept the synthesis. The three-level identity model is correct and cleanly
resolves the attribute-vs-column ambiguity from both RFC responses. The hybrid
shape (`execution_seed` scalar plus `provenance` list column) is the right
structural choice. The candidate selection and promotion APIs are well-formed.

Three items before patching the spec:

1. The `provenance` list column needs a `provenance_version` field.
2. The spec's §4.4 attribute block still lists "derived candidate seed" — it
   must be updated once `execution_seed` and `provenance` are added as columns.
3. The candidate print UX should show the strategy name alongside the hash, not
   the hash alone.

---

## Correction 1: `provenance` Schema Needs A Version Field

The synthesis specifies the `provenance` named list as:

```r
list(
  snapshot_hash    = "...",
  strategy_hash    = "...",
  feature_set_hash = "...",
  master_seed      = 123L,
  seed_contract    = "ledgr_seed_v1",
  evaluation_scope = "exploratory"
)
```

`seed_contract` versions the seed derivation contract. It does not version the
`provenance` struct itself. If a future release adds a field — say,
`opening_state_hash` — there is no way to distinguish an old saved RDS (missing
the field) from a new one (containing it) without reading the provenance contents
and checking for field existence.

Add `provenance_version = "ledgr_provenance_v1"` as the first field. The spec
should define what `v1` contains. Future field additions increment the version.

This is especially important because sweep results are explicitly expected to be
saved as RDS artifacts and promoted later. Provenance objects from different
ledgr versions must be distinguishable.

---

## Correction 2: The §4.4 Attribute Block Must Be Updated

The current spec §4.4 says the result-level attributes must include:

> RNG contract metadata, including master seed and derived candidate seed.

With `execution_seed` (derived candidate seed) moving to a visible column and
`master_seed` moving into both `provenance` and result-level attributes, this
sentence needs to change to:

> RNG contract metadata, including master seed and seed derivation
> contract/version. The per-candidate execution seed is the row-level
> `execution_seed` column; `master_seed` is also duplicated in the row-level
> `provenance` list column for self-contained candidate objects.

This makes the intentional redundancy explicit: `master_seed` lives in both
places deliberately. The row-level `provenance$master_seed` is authoritative
when the parent sweep object's attributes have been lost. The result-level
attribute is authoritative for the sweep object itself.

---

## Correction 3: Candidate Print Should Show Strategy Name

The synthesis print example shows:

```text
strategy: 2a91b...
```

`strategy_hash` is a hash of the strategy closure identity. It is precise but
not human-readable. The sweep metadata carried in `sweep_meta` includes strategy
identity — at minimum the strategy name or label visible in the experiment.

The print method should show the strategy name from `sweep_meta` if available,
with the hash as supplementary context:

```text
strategy: momentum_strategy (2a91b...)
```

If the strategy name is not recoverable from `sweep_meta`, fall back to hash
only. Never show an empty or missing field silently.

---

## Open Question Resolutions

### 1. Hybrid shape (`execution_seed` scalar + `provenance` list)?

Accept. The separation is semantically correct.

`execution_seed` is not just provenance; it is the primary execution argument
for promotion. Making it scalar ensures it is visible in default print, easy to
access without list accessor helpers, and obviously promotion-relevant. Nesting
it inside `provenance` would obscure its promotion-critical role.

Everything else in `provenance` is lineage context, not a direct execution
argument. The list column is the right container for that.

### 2. `feature_set_hash` per-candidate inside `provenance`?

Accept, with a note on filtering ergonomics.

`feature_set_hash` is per-candidate (not sweep-constant) because different params
can resolve to different feature sets. It belongs in a per-row location. The
`provenance` list column is the right home.

The ergonomics cost is real: filtering candidates by shared feature set requires:

```r
results |> dplyr::filter(purrr::map_chr(provenance, "feature_set_hash") == x)
```

rather than `filter(feature_set_hash == x)`. This is acceptable because
feature-set filtering is a diagnostic operation, not a primary ranking operation.
Primary ranking is by metrics, which are scalar. If filtering by feature set
becomes common, a helper accessor (`ledgr_feature_set_hash(results)`) can be
added in v0.1.8.x without changing the column schema.

### 3. `ledgr_candidate()` input type?

Accept the lazy approach from the synthesis.

`ledgr_candidate()` should accept any tibble-like input with the required
promotion columns (`run_id`, `params`, `execution_seed`, `provenance`). When
input is not a classed `ledgr_sweep_results` object, emit a one-line message
(not warning, not error) that sweep metadata is absent and metadata-dependent
operations will fail:

```text
Note: input is not a `ledgr_sweep_results` object; sweep-level metadata
will not be available in the candidate.
```

Requiring classed input would break workflows where users work with a single
serialized candidate saved independently of the parent sweep object. The graceful
degradation model is correct.

### 4. Missing `sweep_meta` — lazy failure?

Lazy failure is correct.

Hard failure at extraction time would mean `ledgr_candidate()` on a plain
one-row tibble (from a manually loaded RDS or an agent handoff) always fails,
even when the user only needs `params` and `execution_seed` for promotion. That
is too strict.

The failure mode should be specific: `ledgr_promote(require_same_snapshot = TRUE)`
fails clearly when `provenance$snapshot_hash` is absent and explains why. The
error must not be generic — it must name the missing field and how to recover.

### 5. `execution_seed` in default print for all sweeps?

Always show it, formatted as `-` when `NA_integer_`.

The argument for conditional display ("only show when at least one candidate is
seeded") would mean the column appears and disappears depending on whether the
user supplied a seed. That is worse than a consistent all-`-` column that sets
clear expectations.

An all-`-` `execution_seed` column communicates "you have not supplied a sweep
seed" and prepares users for the moment they do. Consistent visibility is better
than contextual visibility here.

---

## Additional Finding: Four List Columns Requires Careful Print Curation

`ledgr_sweep_results` will now have four list columns: `params`,
`feature_fingerprints`, `warnings`, and `provenance`. This is a significant
amount of nested data.

The default print method must be carefully curated. Suggested default curated
view columns, in display order:

```text
run_id | status | sharpe_ratio | total_return | max_drawdown | n_trades
execution_seed | error_class | error_msg
```

`params`, `feature_fingerprints`, `warnings`, and `provenance` should all be
hidden from default sweep print but accessible with `print(results, verbose = TRUE)`
or explicit column selection. The print method footer should note how many hidden
columns exist: `# ... with 4 more list columns: params, feature_fingerprints,
warnings, provenance`.

This is a spec-level requirement, not just a cosmetic choice. Without explicit
curation, the default tibble print of four list columns with variable-length
nested content will be unusable.

---

## Required Spec Patch Summary

When patching the spec and UX docs for this synthesis:

1. Add `execution_seed` (integer) and `provenance` (list) to §4.4 visible
   columns. Total: 19.
2. Update §4.4 attribute block: remove "derived candidate seed"; clarify
   `master_seed` duplication is intentional.
3. Add `provenance_version = "ledgr_provenance_v1"` as the first field in the
   `provenance` struct definition.
4. Define `ledgr_candidate()`, `ledgr_promote()`, and `ledgr_sweep_candidate`
   in a new §4.6.
5. Replace the §4.3 manual extraction example with a placeholder comment; add
   the full `ledgr_candidate()` / `ledgr_promote()` examples to §4.6.
6. Make train/test promotion the primary example in §4.6. Same-snapshot replay
   is secondary.
7. Add `ledgr_sweep_candidate` print expectations to §4.6: strategy name plus
   hash, `execution -` for unseeded candidates, compact provenance block.
8. Add default print curation requirements to §4.4 or §4.6: four list columns
   hidden by default, visible via `verbose = TRUE`.
9. Add two new tickets to §12:
   - Sweep output handler: `execution_seed` + `provenance` columns, default
     print curation.
   - Promotion API: `ledgr_candidate()`, `ledgr_promote()`,
     `ledgr_sweep_candidate`, print methods.
10. Add to §11 test list: all items from synthesis §Required Spec Changes, plus
    `provenance_version` field present in all candidates; `strategy_hash` and
    name in print when sweep metadata is available; degraded-mode promotion
    (missing `sweep_meta`) succeeding for basic `ledgr_promote()` calls.

---

## Summary

Accept the synthesis. Patch before spec update:

- Add `provenance_version` to the `provenance` struct.
- Update §4.4 attribute block to reflect `execution_seed` and `master_seed`
  column placement.
- Show strategy name alongside hash in candidate print.
- Curate the default print view explicitly: four list columns hidden, footer
  notes their presence.
- Resolve open questions as above: hybrid shape yes; `feature_set_hash` in
  `provenance` yes with filtering ergonomics noted; lazy input validation; lazy
  metadata failure; always show `execution_seed` in default print.
