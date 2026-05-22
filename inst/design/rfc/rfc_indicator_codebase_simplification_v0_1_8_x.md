# RFC: Indicator Codebase Simplification

**Status:** Request for comment - code-organization proposal; no implementation
started.
**Date:** 2026-05-22
**Author:** Codex
**Input:** Maintainer request and Claude Code simplification proposal.
**Context files:**
- `R/indicator.R` - core `ledgr_indicator()` contract, fingerprinting, registry
- `R/indicators_builtin.R` - exported ledgr built-in indicators
- `R/indicator_adapters.R` - generic R and CSV indicator adapters
- `R/indicator-ttr.R` - TTR-backed indicator adapter
- `R/indicator_dev.R` - indicator REPL helper and pulse snapshot inspection
- `R/feature-map.R` - `ledgr_feature_map()` authoring layer
- `R/feature-cache.R` - feature cache fingerprints
- `R/strategy-fn.R` - strategy function fingerprints
- `inst/design/ledgr_v0_1_8_1_spec_packet/v0_1_8_1_spec.md`
- `inst/design/rfc/rfc_multi_output_indicator_ux_synthesis.md`

---

## 1. Problem Statement

The indicator subsystem is functionally coherent but feels larger and less
legible than it needs to be. The current file cluster mixes several concerns:

- the public indicator constructor and single-output feature contract;
- generic determinism and fingerprinting helpers;
- built-in indicators;
- generic adapters;
- TTR-specific adapter logic;
- interactive indicator development and pulse inspection helpers;
- feature-map authoring.

The result is not a runtime architecture problem. The single-output
`series_fn()` contract is sound, and the multi-output bundle synthesis correctly
keeps bundles as an authoring convenience over ordinary indicators. The problem
is codebase readability: a maintainer trying to understand "the indicator path"
has to separate contracts, adapters, determinism plumbing, feature maps, and
inspection tooling at the same time.

This RFC proposes a narrow simplification pass that improves codebase
orientation without changing indicator behavior, feature IDs, fingerprints,
sweep semantics, or the feature factory path used to tune indicator parameters.

---

## 2. Current Roles In The Indicator Cluster

### `R/indicator.R`

This file currently carries three roles:

1. Public indicator construction and validation:
   - `ledgr_indicator()`;
   - `ledgr_feature_id()`;
   - `print.ledgr_indicator()`.
2. Determinism and fingerprinting infrastructure:
   - `ledgr_assert_indicator_fn_pure()`;
   - `ledgr_assert_indicator_safe()`;
   - `ledgr_are_params_deterministic()`;
   - `ledgr_stable_payload()`;
   - `ledgr_function_fingerprint()`.
3. Indicator fingerprint and registry:
   - `ledgr_indicator_fingerprint()`;
   - `ledgr_register_indicator()`;
   - `ledgr_deregister_indicator()`;
   - `ledgr_get_indicator()`;
   - `ledgr_list_indicators()`.

The second role is not indicator-specific. `ledgr_function_fingerprint()` and
`ledgr_stable_payload()` are also used by `R/feature-cache.R`,
`R/strategy-fn.R`, and `R/indicator_adapters.R`. That makes the determinism
scaffold a package-level concern, not merely an indicator implementation detail.

### `R/indicators_builtin.R`

This file defines exported public helpers:

- `ledgr_ind_sma()`;
- `ledgr_ind_ema()`;
- `ledgr_ind_rsi()`;
- `ledgr_ind_returns()`.

These are not illustrative examples. They are exported, documented, used in the
README, and used throughout tests and vignettes. The package should treat them
as first-class public convenience indicators.

### `R/indicator_adapters.R`

This file defines generic adapter entry points:

- `ledgr_adapter_r()`;
- `ledgr_adapter_csv()`.

It depends on function fingerprinting but does not need to own that logic.

### `R/indicator-ttr.R`

This file is large because it owns a real adapter surface:

- TTR function resolution;
- input shape normalization;
- output selection;
- warmup inference;
- ID construction;
- `series_fn()` wrapping.

Its size is justified by the external adapter complexity. It should remain
separate from the core indicator contract.

### `R/indicator_dev.R`

This file combines two distinct user-facing tools:

- `ledgr_indicator_dev()` and its print/close methods;
- `ledgr_pulse_snapshot()` and pulse-context inspection helpers.

Calling the whole file "REPL" would be too narrow. Pulse snapshots are not just
indicator REPL support; they are part of strategy and feature inspection.

### `R/feature-map.R`

`ledgr_feature_map()` is the authoring layer that binds user-facing aliases to
ordinary indicators. It is the right boundary for multi-output bundles to
flatten, and it is also the shape users should prefer when they plan to inspect
pulse features.

---

## 3. Design Constraints

Any simplification must preserve these contracts:

1. **No second feature engine.** Indicators still precompute feature series
   before execution. Strategies still read scalar feature values from the pulse
   context.
2. **No fingerprint drift.** Existing indicators, feature factories, adapters,
   and strategy functions must hash identically before and after the refactor.
3. **No feature ID drift.** Built-in, TTR, custom, and future bundle-expanded
   feature IDs must remain stable.
4. **Indicator-parameter tuning remains load-bearing.** Sweep users must be able
   to use `features = function(params) list(ledgr_ind_sma(params$n))`. This is
   not an edge case; it is the normal path for tuning indicator parameters.
5. **Multi-output bundle direction remains unchanged.** Bundles flatten to
   ordinary single-output indicators at feature declaration boundaries.
6. **Pulse inspection remains read-only.** Inspection helpers must not mutate
   snapshot or run state.

---

## 4. Assessment Of Proposed Simplifications

### Proposal A: Rename Files For Consistency

Claude's proposal:

```text
indicator.R
indicators_builtin.R
indicator_adapters.R
indicator-ttr.R
indicator_dev.R
```

should be made visually consistent as an `indicator-*` cluster.

Assessment: correct as a readability improvement, but it is mostly perception
and repository hygiene. It should not be the first ticket unless the team wants
a low-risk polish pass. File moves create git-history noise and can distract
from the more important concern separation.

Recommended eventual shape:

```text
R/indicator.R            # constructor, feature ID helper, indicator fingerprint, registry
R/indicator-builtins.R   # exported standard ledgr indicators
R/indicator-adapters.R   # generic R/CSV adapters
R/indicator-ttr.R        # TTR adapter
R/indicator-dev.R        # indicator development session
R/pulse-snapshot.R       # pulse snapshot and pulse inspection context helpers
R/determinism.R          # stable payload and function fingerprint helpers
```

The important correction is that `indicator_dev.R` should not simply become
`indicator-repl.R` unless `ledgr_pulse_snapshot()` is split out first.

### Proposal B: Extract Determinism Scaffold

Claude's proposal:

Move `ledgr_function_fingerprint()`, `ledgr_stable_payload()`, and related
purity helpers out of `R/indicator.R`.

Assessment: accepted as the strongest simplification. The cross-reference check
confirms that these helpers are package-level infrastructure:

- `R/feature-cache.R` fingerprints feature computation functions and params;
- `R/strategy-fn.R` fingerprints strategy functions;
- `R/indicator_adapters.R` fingerprints wrapped package functions;
- `R/indicator.R` fingerprints indicator functions and params.

The recommended file name is `R/determinism.R`, not `R/purity-guards.R`.
"Purity guards" is narrower than the actual role: the code handles stable
payload normalization, function signatures, captured values, and deterministic
hash inputs.

First-pass implementation should move functions without renaming them. That
keeps tests, internal call sites, error classes, and fingerprints stable.

Recommended split:

```text
R/determinism.R
  ledgr_deparse_one()
  ledgr_static_function_signature()
  ledgr_stable_payload()
  ledgr_function_fingerprint()
  ledgr_are_params_deterministic()
  ledgr_assert_indicator_fn_pure()
  ledgr_assert_indicator_safe()

R/indicator.R
  ledgr_indicator()
  ledgr_feature_id()
  print.ledgr_indicator()
  ledgr_indicator_fingerprint()
  indicator registry functions
```

The two `ledgr_assert_indicator_*()` names are indicator-specific, but they
belong near the generic deterministic-code scanner they wrap. Renaming them can
be considered later only if there is a broader determinism API cleanup.

### Proposal C: Decide Whether Built-Ins Are Public API

Claude's proposal:

Built-ins are exported and used in docs; stop treating them as illustrative.

Assessment: accepted. `ledgr_ind_sma()`, `ledgr_ind_ema()`,
`ledgr_ind_rsi()`, and `ledgr_ind_returns()` are public API. The documentation
should describe them as built-in ledgr indicators or standard convenience
indicators, not examples that happen to ship with the package.

Do not move them to `inst/examples/`.

### Proposal D: Rename `indicator_dev.R` To `indicator-repl.R`

Assessment: partially rejected. The premise is right that `indicator_dev.R`
contains user-facing tooling rather than core engine code. The proposed name is
too narrow because the file also contains `ledgr_pulse_snapshot()` and
pulse-context helpers.

Preferred path:

1. Split pulse snapshot/inspection helpers into `R/pulse-snapshot.R`.
2. Rename the remaining indicator dev session file to `R/indicator-dev.R`.
3. Avoid the `indicator-repl.R` name unless the public docs also adopt "REPL"
   terminology.

### Proposal E: Do Not Merge The Kernel Into Adapters

Assessment: accepted. `R/indicator.R` should remain the core contract file.
Merging TTR, built-ins, generic adapters, or feature-map code into it would make
the package harder to reason about. The simplification should separate roles,
not reduce file count at the cost of conceptual clarity.

---

## 5. Additional Finding: Feature Shape Normalization

The maintainer review workbook exposed a separate but related UX issue:
different feature-facing helpers accept overlapping but not identical feature
shapes.

Examples:

- `ledgr_experiment(features = ...)` accepts a list, a `ledgr_feature_map`, or a
  feature factory.
- `ledgr_pulse_snapshot(features = ...)` accepts a list or a
  `ledgr_feature_map`.
- `ledgr_pulse_features(pulse, feature_map = ...)` accepts `NULL` or a
  `ledgr_feature_map`, but not a plain indicator list.

This is not primarily an indicator-codebase simplification problem. It is a
feature lifecycle UX problem already represented in the v0.1.8.1 auditr
findings. This RFC should not widen into an input-normalization change.

However, the codebase would be easier to reason about if a future ticket
introduced one internal normalizer for feature declarations, for example:

```r
ledgr_normalize_feature_declaration(x, allow_factory = FALSE)
```

or:

```r
ledgr_as_feature_map(x)
```

That should be designed as a separate API/UX ticket because it can change error
messages and accepted inputs.

---

## 6. Recommended Implementation Sequence

### Phase 1: Determinism Extraction

Move generic determinism and fingerprint helpers from `R/indicator.R` to
`R/determinism.R`.

Requirements:

- preserve all function names;
- preserve all error classes;
- preserve canonical payload behavior;
- preserve function and indicator fingerprints;
- keep `ledgr_indicator_fingerprint()` in `R/indicator.R` because it is
  indicator-specific;
- run focused fingerprint stability tests and full indicator tests.

This is the highest-value simplification because it turns a hidden architectural
concern into an explicit one.

### Phase 2: File Naming And Role Cleanup

Apply file naming cleanup only after Phase 1 is stable.

Recommended changes:

- `R/indicators_builtin.R` -> `R/indicator-builtins.R`;
- `R/indicator_adapters.R` -> `R/indicator-adapters.R`;
- `R/indicator_dev.R` -> split into `R/indicator-dev.R` and
  `R/pulse-snapshot.R`.

This phase should contain no behavior changes.

### Phase 3: Documentation Alignment

Update docs to teach the actual public roles:

- built-ins are first-class convenience indicators;
- TTR and future talib adapters are adapter-backed indicators;
- feature factories are the correct way to tune indicator parameters in sweeps;
- `ledgr_feature_map()` is the preferred authoring shape when users plan to
  inspect feature values.

This overlaps with the active v0.1.8.1 feature lifecycle documentation track and
should be coordinated with that work rather than duplicated.

---

## 7. Non-Goals

This RFC does not propose:

- changing `ledgr_indicator()` arguments;
- changing `series_fn(bars, params)` semantics;
- changing feature IDs;
- changing feature fingerprints or config hashes;
- changing `ledgr_ind_ttr()` behavior;
- implementing multi-output bundles;
- introducing grouped precompute or `multi_series_fn`;
- broadening `ledgr_pulse_features()` input support;
- removing the indicator registry;
- moving built-ins out of public API.

---

## 8. Acceptance Criteria If Implemented

1. Existing indicator tests pass unchanged or with only file-location-sensitive
   updates.
2. Existing API export lock tests pass.
3. Representative fingerprints are identical before and after the refactor:
   - built-in indicator fingerprint;
   - TTR indicator fingerprint;
   - generic adapter fingerprint;
   - feature cache fingerprint;
   - strategy function fingerprint.
4. `ledgr_feature_id()` output is unchanged for built-ins, TTR indicators, and
   custom indicators.
5. `features = function(params) ...` sweep and precompute tests still pass.
6. Roxygen output is unchanged except for source-file references if any are
   generated.
7. No new public functions are exported.

---

## 9. Open Questions

1. Should the first implementation be ticketed as a v0.1.8.1 cleanup, or parked
   for v0.1.8.x after the auditr documentation work?
2. Should `ledgr_assert_indicator_fn_pure()` and
   `ledgr_assert_indicator_safe()` remain indicator-named internal helpers, or
   should a later determinism RFC rename them to package-level names?
3. Should the feature-shape normalization issue be solved by broader input
   support in inspection helpers, or by stronger documentation that
   `ledgr_feature_map()` is the inspection-oriented shape?
4. Should file moves be grouped into one polish commit, or avoided until there
   is a larger indicator API ticket to amortize git-history churn?

---

## 10. Recommendation

Accept Phase 1 as the only near-term implementation candidate:

```text
Extract package-level determinism/fingerprint helpers to R/determinism.R.
Do not change public behavior.
Do not change hashes.
Do not rename public functions.
```

Treat naming cleanup and `indicator_dev.R` splitting as follow-up polish. Treat
feature-shape normalization as a separate UX design question, not part of this
refactor.

This gives the maintainer the main benefit immediately: `R/indicator.R` becomes
the indicator contract and registry again, while deterministic hashing becomes a
visible package-level primitive shared by indicators, features, adapters, and
strategies.
