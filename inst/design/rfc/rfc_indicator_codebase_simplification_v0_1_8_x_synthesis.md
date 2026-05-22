# RFC Synthesis: Indicator Codebase Simplification

**Status:** Accepted synthesis - binding for v0.1.8.x ticket cut. Placement in
v0.1.8.1 requires an explicit active spec-packet amendment.
**Date:** 2026-05-22
**Source RFC:** `inst/design/rfc/rfc_indicator_codebase_simplification_v0_1_8_x.md`
**Reviewer response:** `inst/design/rfc/rfc_indicator_codebase_simplification_v0_1_8_x_response.md`

---

## 1. Decision Summary

The RFC's main direction is accepted: the first useful simplification is to
extract the package-level determinism and fingerprinting helpers from
`R/indicator.R` into a new `R/determinism.R` file.

This is accepted as a narrow internal refactor only. It must not change:

- public indicator APIs;
- feature IDs;
- feature fingerprints;
- strategy function fingerprints;
- feature-cache keys;
- precomputed feature identity;
- error classes;
- roxygen output;
- sweep feature-factory behavior.

The goal is not to reduce file count. The goal is to make the indicator cluster
legible:

```text
R/indicator.R      -> indicator contract, feature ID helper, fingerprint, registry
R/determinism.R    -> stable payloads, function fingerprints, deterministic code guards
```

The remaining file-shape cleanup is deferred.

---

## 2. Accepted Phase 1: Determinism Extraction

Create `R/determinism.R` and move these helpers from `R/indicator.R` without
renaming them:

- `ledgr_deparse_one()`;
- `ledgr_static_function_signature()`;
- `ledgr_stable_payload()`;
- `ledgr_function_fingerprint()`;
- `ledgr_are_params_deterministic()`;
- `ledgr_assert_indicator_fn_pure()`;
- `ledgr_assert_indicator_safe()`.

Keep these indicator-specific functions in `R/indicator.R`:

- `ledgr_indicator()`;
- `ledgr_feature_id()`;
- `print.ledgr_indicator()`;
- `ledgr_indicator_fingerprint()`;
- indicator registry functions.

`ledgr_assert_indicator_fn_pure()` and `ledgr_assert_indicator_safe()` keep
their indicator-prefixed names in Phase 1. The name mismatch is accepted
internal debt. Renaming them would create call-site churn without improving the
current ticket's safety.

`R/determinism.R` should include a short file header explaining that the two
indicator-prefixed helpers remain named that way for compatibility and may be
renamed only in a later determinism-API cleanup.

---

## 3. Hash And Identity Semantics

The implementation must preserve the existing hash semantics exactly.

### What Fingerprints Do Not Affect

`ledgr_indicator_fingerprint()` does not define feature IDs.

`ledgr_feature_id()` returns `indicator$id` directly, or the mapped feature IDs
from a `ledgr_feature_map`. Feature IDs are set at construction time and must
not drift during this refactor.

### What Fingerprints Do Affect

Fingerprint drift would affect:

- session-only feature-cache keys;
- precomputed-feature payload objects built against sealed snapshots;
- candidate feature fingerprints and feature-set hashes in sweeps;
- registered-run compatibility checks against recorded indicator fingerprints;
- functional strategy registry keys and config identity.

The persisted `strategy_source_hash` is produced by strategy source capture, not
directly by `ledgr_function_fingerprint()`. The function fingerprint still
matters because it creates functional strategy registry keys used in executable
configuration identity.

Feature-cache drift would cause cache misses, not corrupted persisted cache
reads. The session feature cache is not persisted to DuckDB. The higher-risk
case is precomputed feature payload validation: payloads created before a hash
drift would no longer match the current feature definitions.

---

## 4. Required Test Gates

Phase 1 must start by adding fingerprint and feature-factory identity pins on
the pre-refactor code. The move to `R/determinism.R` happens only after those
pins exist.

### Hard Fingerprint Pins

Add `tests/testthat/test-fingerprint-stability.R` with hard pins for:

- `ledgr_ind_sma(20)`;
- `ledgr_ind_ema(20)`;
- `ledgr_ind_rsi(14)`;
- `ledgr_ind_returns(5)`;
- `ledgr_adapter_r()` wrapping a local closure defined in the test file;
- `ledgr_function_fingerprint()` over a sample strategy closure defined in the
  test file;
- `ledgr_feature_engine_version()`.

Do not hard-pin a base or stats package function such as `stats::median`.
R-version changes can alter deparse output and produce false positives unrelated
to ledgr.

### Version-Conditional TTR Pins

Add version-aware pins for:

- `ledgr_ind_ttr("RSI", input = "close", n = 14)`;
- `ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20)`.

These pins must be keyed to the recorded `packageVersion("TTR")` or skipped
when the installed TTR version differs. TTR fingerprints intentionally include
TTR version metadata, so a TTR upgrade is not a ledgr regression.

### Feature-Factory Identity Pins

Add a feature-factory parity gate for:

```r
features = function(params) list(ledgr_ind_sma(params$n))
```

The test must use a concrete two-candidate grid:

```r
grid <- ledgr_param_grid(short = list(n = 10L), long = list(n = 20L))
```

Use the existing deterministic sweep fixture shape (`ledgr_sweep_test_bars()`,
with any needed extraction into a shared helper) and a fixed scoring range inside
that fixture. Pin the pre-refactor candidate feature fingerprints and
feature-set hashes, then assert those identities remain unchanged after the
move. This protects indicator-parameter tuning in sweeps, which is a
load-bearing workflow rather than an edge case.

### Standard Gates

The Phase 1 ticket must also pass:

- full indicator tests;
- feature-cache tests;
- precompute/sweep feature-factory tests;
- API export lock tests;
- `devtools::document()` with no unexpected `man/*.Rd` diffs.

No prose, signature, example, export, or public help output should change as a
result of Phase 1.

---

## 5. Implementation Constraints

The move must preserve all current `include_captures` arguments.

Current rules:

- `ledgr_indicator_fingerprint()` fingerprints indicator `fn` and `series_fn`
  with `include_captures = FALSE`;
- `ledgr_adapter_r()` fingerprints wrapped package functions with
  `include_captures = FALSE`;
- feature-cache helper fingerprints keep their current values;
- strategy registration keeps its current `include_captures` behavior.

Changing capture treatment is a separate identity contract change and is not in
scope.

Because this is a partial-file move, git blame for the moved helpers will point
at `R/determinism.R` after Phase 1. Add a short file comment noting that these
functions were moved from `R/indicator.R` during
`LDG-IND-SIMPLIFY-PHASE-1`, and that pre-refactor blame/history lives in
`R/indicator.R`.

The following error classes must remain unchanged:

- `ledgr_invalid_args`;
- `ledgr_purity_violation`;
- `ledgr_config_non_deterministic`.

---

## 6. Deferred Work

### File Naming And Role Cleanup

Defer file renames and file splits until after Phase 1 has shipped and completed
at least one CI cycle.

Potential later shape:

```text
R/indicator-builtins.R
R/indicator-adapters.R
R/indicator-ttr.R
R/indicator-dev.R
R/pulse-snapshot.R
```

Do not rename `R/indicator_dev.R` to `indicator-repl.R`. That name is too narrow
because the file currently also owns `ledgr_pulse_snapshot()` and pulse-context
inspection helpers.

### Documentation Alignment

Defer the documentation alignment pass, but keep these decisions for that work:

- built-ins are first-class public convenience indicators, not illustrative
  examples;
- TTR and future talib helpers are adapter-backed indicators;
- feature factories are the correct path for tuning indicator parameters in
  sweeps;
- `ledgr_feature_map()` is the preferred shape when users plan to inspect pulse
  features.

This should coordinate with the v0.1.8.1 feature lifecycle documentation track,
not duplicate it.

### Feature Shape Normalization

Do not broaden `ledgr_pulse_features()` input support in this refactor.

The plain-list versus `ledgr_feature_map()` inspection friction is real, but it
changes accepted inputs and error messages. It belongs in a separate feature
lifecycle UX ticket.

---

## 7. Cycle Placement

Phase 1 is eligible for v0.1.8.1 only if the active spec packet is explicitly
amended.

Reason to include it in v0.1.8.1:

- it is a stabilization refactor;
- it clarifies a package-level determinism primitive;
- it is independent of the multi-output bundle implementation;
- it can be guarded by pre-refactor hash pins.

Reason to park it for a later v0.1.8.x patch:

- it touches the hash spine;
- the v0.1.8.1 packet is already scoped around auditr UX stabilization and
  multi-output bundle authoring;
- adding it mid-cycle increases review load.

Both placements are defensible. The maintainer must choose by amending the
active spec packet or leaving this synthesis as future v0.1.8.x guidance.

---

## 8. Non-Goals

Phase 1 must not:

- rename files other than adding `R/determinism.R`;
- change public APIs;
- change feature IDs;
- change hashes;
- change exports;
- change docs;
- implement multi-output bundles;
- introduce grouped precompute;
- alter TTR behavior;
- broaden `ledgr_pulse_features()` input support;
- split `R/indicator_dev.R`;
- remove or change the indicator registry.

---

## 9. Ticket Sketch

Suggested ticket title:

```text
LDG-IND-SIMPLIFY-PHASE-1: Extract determinism helpers from indicator core
```

Required sequence:

1. Add pre-refactor fingerprint-stability tests.
2. Add pre-refactor feature-factory identity pins.
3. Move accepted helper functions into `R/determinism.R` without renaming.
4. Confirm hash pins still pass.
5. Confirm feature-factory identity pins still pass.
6. Run targeted indicator, feature-cache, precompute, and sweep tests.
7. Run API export lock tests.
8. Run `devtools::document()` and verify no unexpected `man/*.Rd` diffs.

The ticket is complete only if all pins remain unchanged after the move.
