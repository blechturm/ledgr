# Maintainer Response: Multi-Output Indicator UX And Contract

**Status:** Maintainer response.
**Date:** 2026-05-15
**Author:** ledgr maintainer
**RFC:** `inst/design/rfc/rfc_multi_output_indicator_ux.md`
**Codex response:** `inst/design/rfc/rfc_multi_output_indicator_ux_response.md`

---

## Accepted

- The overall verdict: bundle UX first, batching deferred.
- `ledgr_indicator_bundle` as an explicit class, not a polymorphic return type
  from the existing single-output constructor.
- Flatten at feature boundaries (`ledgr_feature_map`, experiment, precompute)
  but only for classed bundles, not arbitrary nested lists.
- N output-specific fingerprints as the external identity. Shared computation
  fingerprint is internal scheduler metadata for the later batching sprint.
- TTR retrofit alongside the talib adapter, not after.

---

## Push-Back: The Naming API Is Still Too Verbose

The proposed naming shape:

```r
ledgr_ind_ttr_outputs(
  "BBands",
  input = "close",
  outputs = c(bb_dn = "dn", bb_mavg = "mavg", bb_up = "up"),
  n = 20
)
```

requires the user to spell out both sides of a name mapping that the indicator
already knows. This is the problem we are trying to solve, not a solution to it.

The right reference point is `{recipes}`. Across all multi-output steps in that
package — `step_pca()`, `step_dummy()`, `step_lag()`, `step_interact()` — the
user never enumerates output names. The step derives them automatically. User
control comes through `prefix`, `sep`, or a `naming` function argument, not
through an explicit mapping.

The target API shape for ledgr:

```r
# default: indicator's own output names
ledgr_ind_ttr_outputs("BBands", input = "close", n = 20)
# → feature IDs: dn, mavg, up, pctB

# prefix for namespacing
ledgr_ind_ttr_outputs("BBands", input = "close", n = 20, prefix = "bb")
# → feature IDs: bb_dn, bb_mavg, bb_up, bb_pctB

# filter to a subset (no renaming required)
ledgr_ind_ttr_outputs("BBands", input = "close", n = 20, outputs = c("dn", "up"))
# → feature IDs: dn, up
```

When `outputs` is a character vector of column names (not a named character
vector), it is a filter, not a rename map. Renaming is handled by `prefix` or,
as an escape hatch, a `naming` function following the `step_dummy` pattern.

---

## Resolved: Indicator Output Metadata

Q8 is answered. Neither TTR nor talib (R) expose output metadata
programmatically — no API, no lookup table, nothing in either package. Output
column names can only be discovered by running the function and calling
`colnames()` on the result.

This makes the static-table vs lazy-discovery question moot in favour of lazy
discovery: **both adapters already pay the construction-time synthetic call
cost**. The TTR adapter runs `ledgr_ttr_validate_output_contract()` at
construction, which calls the function on synthetic bars and routes through
`ledgr_ttr_select_output()`. The available column names are already present in
that result. The bundle constructor simply captures them rather than discarding
them.

For talib the same path applies. The adapter already requires
`requireNamespace("talib")` at construction, so running on synthetic bars
introduces no new dependency constraint. `talib::lookback()` gives warmup;
a synthetic call gives output names. No separate introspection API is needed.

The one deferred edge case is enumerating a bundle's available outputs
*before* constructing it — i.e., a `ledgr_ttr_available_outputs("BBands")`
discovery helper. That is a discoverability question separate from the bundle
UX and can be deferred.

---

## Revised Acceptance Criteria

Amending Codex's minimal acceptance criteria:

- `ledgr_ind_ttr_outputs()` accepts `prefix` and optional `outputs` (character
  filter, not a rename map). Returns a `ledgr_indicator_bundle`.
- Default feature IDs use the indicator's own output column names, optionally
  prefixed.
- A `naming` function argument is available as an escape hatch but is not the
  primary path.
- `ledgr_feature_map()` accepts and flattens `ledgr_indicator_bundle` objects.
- Bundle construction validates that all requested output names exist, failing
  early with a clear error listing available outputs.
- Existing `ledgr_ind_ttr(output = ...)` single-output path is unchanged.
- Documentation teaches `ledgr_ind_ttr_outputs()` with `prefix` as the primary
  multi-output pattern.
