# ledgr v0.1.4 Specification - Research Workflow Stabilisation

**Document Version:** 1.0.0  
**Author:** Max Thomasberger  
**Date:** April 27, 2026  
**Release Type:** Stabilisation Milestone  
**Status:** **LOCKED FOR RELEASE VALIDATION**

## 0. Goal

v0.1.4 stabilises the post-onboarding research loop before the larger
experiment-store API is finalized.

The release improves durable snapshot reuse, strategy authoring ergonomics,
indicator performance, and reference documentation without changing the
canonical execution semantics introduced in earlier v0.1.x releases.

The original roadmap placed "Experiment Store Core" in v0.1.4. Evaluation after
v0.1.3 showed that the safer sequence is:

```text
v0.1.4  research workflow stabilisation
v0.1.5  experiment store core
v0.1.6  experiment comparison and strategy recovery
v0.1.7  lightweight sweep mode
```

---

## 1. Hard Requirements

### R1: No New Execution Semantics

v0.1.4 MUST NOT change pulse ordering, fill semantics, ledger event semantics,
snapshot sealing, snapshot hashing, or derived-state reconstruction semantics.

All convenience and performance work must preserve the canonical
`ledgr_backtest()` -> config -> runner path.

### R2: Durable Research Scripts Must Be Re-runnable

Users must be able to reopen an existing sealed snapshot from a durable DuckDB
file without re-importing data, overwriting data, or silently resealing the
snapshot.

### R3: Strategy Footguns Must Be Visible And Avoidable

`ctx$targets()` and `ctx$current_targets()` must have distinct, documented
semantics:

- `ctx$targets()` starts from flat targets.
- `ctx$current_targets()` starts from current holdings.

Examples that hold existing positions should use `ctx$current_targets()`.

### R4: Indicator Performance Must Preserve Feature Semantics

`series_fn` and the session feature cache are optimizations. They must not alter
no-lookahead behavior, warmup handling, feature alignment, or indicator
fingerprints.

### R5: Optional Integrations Stay Outside The Core

TTR support must remain an adapter layer that produces normal
`ledgr_indicator` objects. TTR must remain optional, and the execution engine
must not depend on TTR directly.

### R6: Public API Lifecycle Must Be Explicit

v0.x may make breaking changes only when they protect correctness or simplify
the public model. Breaking changes and deprecations must be documented in
`NEWS.md`; where practical, they pass through one deprecation release before
hard removal.

---

## 2. Scope

### 2.1 Public API And Lifecycle Cleanup

v0.1.4 clarifies public/internal boundaries before the experiment-store layer:

- `ledgr_backtest_run()` remains exported but is documented as a low-level
  internal/recovery runner. Normal users should call `ledgr_backtest()`.
- `ledgr_backtest_bench()` is public telemetry and must not be labelled
  internal.
- `ledgr_config()` remains internal but returns a validated `ledgr_config` S3
  object.
- `ledgr_data_hash()` remains exported as a legacy v0.1.0 direct-bars helper;
  modern snapshot workflows use sealed snapshot hashes.
- `ledgr_state_reconstruct()` remains a low-level recovery API that requires a
  DBI connection; normal result inspection uses `as_tibble()`, `summary()`,
  `plot()`, and related result helpers.

### 2.2 Durable Snapshot Workflow

v0.1.4 adds:

- `ledgr_snapshot_load(db_path, snapshot_id, verify = FALSE)`
- path-first `ledgr_snapshot_list(db_path)`

`ledgr_snapshot_load()` must:

- require an existing snapshot;
- require status `SEALED`;
- never create, import, overwrite, or reseal data;
- optionally recompute and verify the snapshot hash when `verify = TRUE`.

### 2.3 Strategy And Pulse Ergonomics

v0.1.4 adds:

- `ctx$current_targets()` to runtime contexts;
- `ctx$current_targets()` to `ledgr_pulse_snapshot()` contexts;
- docs for `ctx$cash`, `ctx$equity`, and `ctx$close(id)` position sizing;
- examples for hold-unless-signal and rebalance-throttling patterns.

The scalar fields `ctx$cash` and `ctx$equity` remain fields, not methods.

### 2.4 Feature Series And Session Cache

v0.1.4 adds optional full-series indicator computation:

```r
ledgr_indicator(
  id = "example",
  fn = function(window, params) tail(window$close, 1),
  series_fn = function(bars, params) bars$close,
  requires_bars = 1,
  params = list()
)
```

`series_fn` receives one instrument's full bar series in ascending time order
and returns a numeric vector aligned to `nrow(bars)`.

Warmup `NA_real_` and warmup `NaN` normalize to `NA_real_`. Infinite values,
post-warmup `NA`, and post-warmup `NaN` are invalid.

The session feature cache is keyed by:

```text
snapshot_hash
+ instrument_id
+ indicator_fingerprint
+ feature_engine_version
+ date_range
```

The cache is never persisted to DuckDB. It can be cleared with
`ledgr_clear_feature_cache()`.

### 2.5 TTR Indicator Adapter

v0.1.4 adds:

- `ledgr_ind_ttr()`
- `ledgr_ttr_warmup_rules()`

The TTR adapter contract is:

- TTR remains optional.
- TTR functions are wrapped as `ledgr_indicator` objects.
- TTR metadata is stored in indicator params for fingerprinting and diagnostics.
- Only documented warmup rules may be inferred automatically.
- Inferred warmup rules must be deterministic from explicit arguments alone.
- Rules are verified against direct TTR output in tests.
- Unknown or ambiguous TTR functions require explicit `requires_bars`.

Supported input mappings:

```text
close -> bars$close
hl    -> High/Low matrix
hlc   -> High/Low/Close matrix
ohlc  -> Open/High/Low/Close matrix
hlcv  -> High/Low/Close/Volume matrix
```

---

## 3. Non-Goals

v0.1.4 does not implement:

- live trading;
- paper trading;
- broker adapters;
- streaming data;
- engine-level rebalance scheduling;
- persistent feature cache;
- full experiment-store APIs;
- run comparison;
- strategy extraction or revival;
- lightweight sweep mode.

The full experiment-store API moves to v0.1.5.

---

## 4. Verification Gates

LDG-714 is accepted only when the following gates pass:

1. `contracts.md` and `NEWS.md` match the implemented v0.1.4 scope.
2. v0.1.2 and v0.1.3 acceptance tests pass.
3. README cold-start check passes.
4. Coverage remains at or above 80%.
5. pkgdown site builds.
6. `R CMD check --no-manual --no-build-vignettes` passes with 0 errors and 0
   warnings.
7. Ubuntu and Windows CI are green.

Remote CI cannot be proven locally. Local LDG-714 execution may prepare and
validate the release, but final acceptance requires green remote CI after push.

---

## 5. Ticket Summary

| Ticket | Title | Status |
|:---|:---|:---|
| LDG-701 | Compatibility Policy and Design-File Hygiene | Done |
| LDG-702 | Strategy Identity and Reproducibility Tiers | Done |
| LDG-703 | Low-Level API Lifecycle Cleanup | Done |
| LDG-704 | Internal `ledgr_config` Class and Validation | Done |
| LDG-705 | Public `ledgr_data_hash()` Deprecation and Internal Hash Split | Done |
| LDG-706 | Reconstruction Documentation Cleanup | Done |
| LDG-707 | Optional Indicator Deregistration Helper | Done |
| LDG-708 | Load Existing Sealed Snapshots | Done |
| LDG-709 | Path-First Snapshot Listing | Done |
| LDG-710 | Current Target Helper | Done |
| LDG-711 | Research Workflow Documentation Updates | Done |
| LDG-712 | Vectorized Indicator `series_fn` | Done |
| LDG-713 | Feature Cache Across Parameter Sweeps | Done |
| LDG-715 | Low-Code TTR Indicator Constructor | Done |
| LDG-716 | Expand TTR Warmup Rules and Indicator Documentation | Done |
| LDG-714 | v0.1.4 Stabilisation Gate | Pending remote CI |

---

## 6. Roadmap Impact

The release order is now:

- v0.1.4: research workflow stabilisation;
- v0.1.5: experiment store core;
- v0.1.6: experiment comparison and strategy recovery;
- v0.1.7: lightweight parameter sweep mode.

This sequencing keeps v0.1.4 small enough to validate while preserving the
larger product direction: a deterministic, event-sourced research framework
that can later grow into paper and live trading without splitting the strategy
model.
