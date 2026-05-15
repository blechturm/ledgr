# RFC Synthesis: Multi-Output Indicator UX And Contract

**Status:** Approved synthesis.
**Date:** 2026-05-15
**RFC:** `inst/design/rfc/rfc_multi_output_indicator_ux.md`
**Inputs:**
- `inst/design/rfc/rfc_multi_output_indicator_ux_response.md`
- `inst/design/rfc/rfc_multi_output_indicator_ux_maintainer_response.md`

---

## Decision Summary

Multi-output indicator UX should be solved first as an authoring-layer bundle,
not by changing the core feature series contract.

Accepted direction:

```text
Bundle UX now:
  ledgr_indicator_bundle
  ordinary single-output indicators underneath
  flatten at feature declaration boundaries
  output-specific feature IDs and fingerprints

Batching later:
  grouped precompute / multi_series_fn-like optimization
  internal shared computation fingerprint
  no user-facing API rewrite
```

The existing single-output contract remains authoritative:

```r
series_fn(bars, params) -> numeric vector aligned to nrow(bars)
```

Strategies still read scalar feature IDs via `ctx$feature()` or mapped feature
views. A multi-output bundle is only an authoring convenience for creating and
registering several ordinary feature definitions from one shared indicator
configuration.

---

## Accepted Design

### Explicit Bundle Class

Add an explicit `ledgr_indicator_bundle` class. Do not make
`ledgr_ind_ttr()` return different object types depending on whether the user
supplies `output` or `outputs`.

Single-output constructors remain single-output constructors:

```r
ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20)
```

Multi-output authoring uses a separate helper:

```r
ledgr_ind_ttr_outputs("BBands", input = "close", n = 20, prefix = "bb")
```

The bundle contains ordinary `ledgr_indicator` objects. It may carry metadata
for printing, validation, and future batching, but it is not a new runtime
feature source.

### Flatten Only Classed Bundles

`ledgr_indicator_bundle` objects should flatten at feature declaration
boundaries:

- `ledgr_feature_map()`;
- `ledgr_experiment(features = ...)`;
- `features = function(params) ...`;
- precompute/sweep feature resolution.

The flattening rule must be narrow:

```text
accept ledgr_indicator
flatten ledgr_indicator_bundle
reject arbitrary nested lists
```

Do not turn `ledgr_feature_map()` into a general recursive list normalizer.
Feature-map aliases and feature IDs are part of the reproducibility contract,
so ambiguous nested-list naming should fail loudly.

### Output-Specific External Identity

Every output in a bundle remains an ordinary feature with its own feature ID and
fingerprint.

External provenance continues to use output-specific identity:

- sweep row `feature_fingerprints`;
- candidate `feature_set_hash`;
- precomputed payload fingerprints;
- config hashes;
- strategy-visible feature IDs.

A shared computation fingerprint may be added later as internal scheduler
metadata, but it is not part of the first UX patch.

---

## Naming Decision

The bundle helper should not require users to spell both sides of a rename map.
That repeats information the adapter already knows.

The default naming path should be collision-resistant. By default, bundle
feature IDs should use a normalized indicator-family prefix derived from the
backend function name. Raw backend output names remain available only by
explicit opt-in with `prefix = NULL`.

Primary API:

```r
# default: normalized family prefix
ledgr_ind_ttr_outputs("BBands", input = "close", n = 20)
# feature IDs: bbands_dn, bbands_mavg, bbands_up, bbands_pctb

# concise explicit prefix
ledgr_ind_ttr_outputs("BBands", input = "close", n = 20, prefix = "bb")
# feature IDs: bb_dn, bb_mavg, bb_up, bb_pctb

# subset outputs without renaming
ledgr_ind_ttr_outputs("BBands", input = "close", n = 20, outputs = c("dn", "up"))
# feature IDs: bbands_dn, bbands_up

# raw backend output names, explicit opt-in
ledgr_ind_ttr_outputs("BBands", input = "close", n = 20, prefix = NULL)
# feature IDs: dn, mavg, up, pctb
```

`outputs` is a filter, not a rename map. If supplied, it selects backend output
columns by name.

Renaming is handled by:

- the derived default prefix;
- explicit `prefix`, the primary user-facing override;
- `prefix = NULL`, an explicit opt-in to raw backend output names;
- optional `naming`, an escape hatch for custom naming.

Derived prefixes and output-name tokens should use the same token rules as
generated TTR IDs: lower-case, replace non-alphanumeric runs with `_`, trim
leading/trailing `_`, and fall back to `x` if the result is empty. That means a
backend function name such as `BBands` derives `bbands`, and an output column
such as `pctB` derives `pctb`.

Documentation should teach the derived default and concise explicit `prefix`
forms. Raw backend output names such as `dn`, `up`, `signal`, or `histogram`
are collision-prone when multiple bundles or parameterizations appear in one
experiment, so raw names should not be the default.

Duplicate feature IDs must remain hard errors. If a user relies on raw output
names and creates a collision, ledgr should fail loudly rather than silently
renaming features.

Instrument IDs must not enter generated feature IDs. Feature IDs describe the
indicator definition, not the instruments it is applied to. Instrument-specific
names belong only in diagnostic or wide views such as
`{instrument_id}__feature_{feature_id}`.

---

## General Indicator Naming Standard

This RFC is about multi-output indicators, but the naming rule should be
consistent with the single-output adapter surface.

General standard:

```text
engine feature IDs:
  stable, deterministic, collision-resistant, instrument-agnostic

single-output adapter constructors:
  keep existing deterministic generated IDs
  keep `id` as the exact override
  do not require `prefix` unless a concrete UX need appears

multi-output bundle constructors:
  derive a collision-resistant family prefix by default
  allow explicit `prefix`
  allow `prefix = NULL` only as raw-name opt-in
  allow `naming` as an advanced escape hatch

strategy readability:
  use feature maps and aliases where user-facing names should differ from
  engine feature IDs
```

This means existing single-output examples such as:

```r
ledgr_ind_ttr("SMA", input = "close", n = 20)
```

can keep their current generated IDs. The multi-output bundle is stricter by
default because raw backend column names are usually too short to be safe as
engine feature IDs.

---

## Output Discovery

The accepted discovery approach is construction-time lazy discovery using
synthetic bars.

Rationale:

- TTR does not expose output metadata programmatically.
- talib R bindings also do not expose output metadata programmatically.
- The current TTR constructor already runs a synthetic validation call through
  `ledgr_ttr_validate_output_contract()`.
- Bundle construction can capture available output names from that same
  synthetic result instead of discarding them.
- The talib adapter can use the same pattern: `talib::lookback()` for warmup,
  synthetic execution for output names.

This means a bundle constructor requires the backend package to be installed at
construction time. That is already true for `ledgr_ind_ttr()` and is expected
for the talib adapter.

Static output metadata remains useful for documentation and tests if added
later, but it is not required for the first bundle UX.

Deferred discoverability helper:

```r
ledgr_ttr_available_outputs("BBands")
```

This helper is useful, but separate from the bundle contract. It should not
block the bundle UX.

---

## Deferred Batching

The first implementation should not add `multi_series_fn` or grouped precompute
execution.

Later batching can be implemented behind the bundle shape:

```text
external:
  output-specific feature_id
  output-specific feature fingerprint

internal:
  computation_fingerprint = backend + function + input + shared args
  output_name = backend output column / derived output
```

The precompute scheduler can then group compatible outputs, call the backend
once per instrument and parameterization, validate each returned vector with
the existing numeric-series normalizer, and fill the existing output-specific
payload slots.

This preserves the strategy and provenance contracts while reducing redundant
precompute work.

---

## TTR And talib Adapter Consistency

The multi-output bundle pattern should be shared by TTR and talib.

Do not ship a state where talib teaches bundle ergonomics while TTR examples
continue to teach repeated one-output calls as the primary idiom.

The existing low-level TTR form remains valid:

```r
ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20)
```

But documentation for multi-output use should prefer:

```r
bb <- ledgr_ind_ttr_outputs("BBands", input = "close", n = 20)
```

The talib adapter should follow the same convention when it introduces
multi-output functions.

---

## First Ticket Shape

A first implementation ticket should include:

- `ledgr_indicator_bundle` class and validation helper.
- `ledgr_ind_ttr_outputs()` returning a bundle of ordinary
  `ledgr_indicator` objects.
- derived default prefix, explicit `prefix`, `prefix = NULL`, `outputs`, and
  optional `naming` support.
- Lazy output discovery from synthetic backend execution.
- Early validation that requested `outputs` exist, with an error listing
  available outputs.
- Bundle flattening at feature boundaries.
- Tests proving existing `ledgr_ind_ttr(output = ...)` IDs and fingerprints are
  unchanged.
- Tests proving bundle entries are ordinary indicators with unique feature IDs
  and output-specific fingerprints.
- Tests proving default bundle IDs use a normalized family prefix and
  `prefix = NULL` uses raw backend output names.
- Tests proving `outputs` filters still receive the derived/default or explicit
  prefix.
- Tests proving feature maps, static experiment features, and
  `features = function(params)` all materialize bundles consistently.
- Documentation teaching derived default and explicit-prefix multi-output
  authoring.

The first ticket should explicitly exclude:

- precompute batching;
- `multi_series_fn`;
- public available-output discovery helpers;
- arbitrary nested-list feature flattening;
- changing existing single-output indicator IDs.

---

## Open Follow-Up Questions

The RFC thread leaves these as future design items, not blockers for the first
bundle UX:

- Should a public `ledgr_ttr_available_outputs()` helper exist?
- Should bundle print output show backend output names, feature IDs, or both?
- How should later grouped precompute record shared computation fingerprints in
  diagnostics without changing feature provenance?

---

## Verdict

Proceed with bundle UX first.

The key design boundary is:

```text
authoring bundle != runtime multi-output feature
```

That keeps ledgr's existing feature identity, sweep provenance, and strategy
lookup contracts intact while making multi-output indicator authoring much less
error-prone.
