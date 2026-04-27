# ledgr v0.1.4 Stabilisation Tickets

**Version:** 1.0.0  
**Date:** April 26, 2026  
**Total Tickets:** 16  
**Estimated Duration:** 2-3 weeks

---

## Ticket Organization

v0.1.4 is a stabilisation and research-loop release. It should make the
post-v0.1.3 package safer to use for repeated research scripts and parameter
sweeps before the larger experiment-store API is finalized.

The ticket range starts at `LDG-701` to avoid collisions with v0.1.3 tickets.

### Dependency DAG

```text
LDG-701 -> LDG-702 -> LDG-714
LDG-701 -> LDG-703 -> LDG-714
LDG-701 -> LDG-704 -> LDG-714
LDG-701 -> LDG-705 -> LDG-714
LDG-706 ------------------> LDG-714

LDG-708 -> LDG-711 -> LDG-714
LDG-709 -----------> LDG-714
LDG-710 -> LDG-711 -> LDG-714

LDG-712 -> LDG-713 -> LDG-715 -> LDG-716 -> LDG-714
```

`LDG-714` is the stabilisation gate. It should not be accepted until contracts,
NEWS, tests, reference docs, and release checks reflect the accepted scope.
`LDG-707` is optional and is not a release-gate dependency unless the team
chooses to add public indicator deregistration in v0.1.4.

### Priority Levels

- **P0 (Blocker):** Required before v0.1.4 design or release validation can be trusted
- **P1 (Critical):** Required for the research workflow to feel coherent
- **P2 (Important):** Required for documentation quality and maintainability
- **P3 (Optional):** Useful, but not a release blocker

---

## LDG-701: Compatibility Policy and Design-File Hygiene

**Priority:** P0  
**Effort:** 0.5 days  
**Dependencies:** None

**Description:**
Document the v0.x compatibility policy and normalize v0.1.4 design inputs before
implementation begins. v0.1.3 is public, so exported API removals and behavior
changes must be deliberate and visible.

**Tasks:**
1. Add a v0.x compatibility policy to the design docs.
2. State that breaking changes are allowed during v0.x only when they protect
   correctness or simplify the public model.
3. Require `NEWS.md` entries for all breaking changes and deprecations.
4. State that deprecation should pass through one release where practical.
5. Update `inst/design/contracts.md` to summarize or link the policy.
6. Normalize v0.1.4 design inputs to clean UTF-8 or plain ASCII.
7. Remove mojibake from v0.1.4 design documents.

**Acceptance Criteria:**
- [x] v0.x compatibility policy is present in design docs.
- [x] `contracts.md` records the compatibility policy.
- [x] `NEWS.md` is named as mandatory for deprecations and breaking changes.
- [x] v0.1.4 design inputs no longer contain mojibake.
- [x] The policy is referenced by tickets that change exported APIs.

**Test Requirements:**
- `rg -n "[^\\x00-\\x7F]" inst/design/ledgr_v0_1_4_spec_packet`
- Manual review of `contracts.md`

**Source Reference:** Pre-Gate: Compatibility Policy; Pre-Gate: Design-File Encoding Hygiene

---

## LDG-702: Strategy Identity and Reproducibility Tiers

**Priority:** P0 (release-critical, not implementation-blocking)  
**Effort:** 0.5-1 day  
**Dependencies:** LDG-701

**Description:**
Decide how functional and R6 strategies are represented in the future
experiment-store identity model. This must be explicit before run identity is
finalized. This ticket does not block unrelated implementation work such as
snapshot loading, context helpers, or indicator performance; it blocks the
v0.1.4 stabilisation gate and any final run-identity design.

**Tasks:**
1. Define strategy reproducibility tiers for v0.1.4.
2. Treat functional strategies with explicit `strategy_params` as the Tier 1
   path.
3. Classify R6 strategies as Tier 2 by default unless they provide explicit
   source/params metadata or a future identity method.
4. Specify how strategy tier is exposed in run metadata.
5. Update `contracts.md` with the strategy identity boundary.
6. Add a note to the v0.1.4 spec packet before implementation tickets rely on
   run identity.

**Acceptance Criteria:**
- [x] Functional and R6 strategies have explicit reproducibility-tier rules.
- [x] R6 objects are not silently treated as fully reproducible.
- [x] Run metadata design includes a strategy reproducibility tier.
- [x] `contracts.md` records the strategy identity boundary.

**Test Requirements:**
- Design review only

**Source Reference:** Pre-Gate: R6 Strategy Identity

---

## LDG-703: Low-Level API Lifecycle Cleanup

**Priority:** P0  
**Effort:** 1 day  
**Dependencies:** LDG-701

**Description:**
Resolve public/internal status for low-level APIs whose docs currently conflict
with their export status: `ledgr_backtest_run()` and `ledgr_backtest_bench()`.

**Tasks:**
1. Decide whether `ledgr_backtest_run()` remains exported in v0.1.4.
2. Prefer soft deprecation or clear low-level lifecycle wording for
   `ledgr_backtest_run()` unless a deliberate breaking removal is accepted.
3. Ensure docs no longer teach calling `ledgr_backtest_run()` after
   `ledgr_backtest()`.
4. If `ledgr_backtest_run()` is removed, update `NAMESPACE`,
   `test-api-exports.R`, old acceptance tests, contracts, and `NEWS.md`.
5. Decide whether `ledgr_backtest_bench()` is public telemetry or internal.
6. If public, remove "(internal)" from its title and document expected use.
7. If internal, route through the compatibility policy before unexporting.

**Acceptance Criteria:**
- [x] `ledgr_backtest_run()` public status is unambiguous.
- [x] `ledgr_backtest_run()` examples do not invert the public call graph.
- [x] Any deprecation or removal is documented in `NEWS.md`.
- [x] `ledgr_backtest_bench()` title and export status agree.
- [x] Export surface test reflects the accepted lifecycle decision.

**Test Requirements:**
- `tests/testthat/test-api-exports.R`
- `devtools::document()` or `roxygen2::roxygenise()`
- `R CMD check --no-manual --no-build-vignettes`

**Source Reference:** A1, A6

---

## LDG-704: Internal `ledgr_config` Class and Validation

**Priority:** P0  
**Effort:** 1 day  
**Dependencies:** LDG-701

**Description:**
Stabilize the internal config object before the experiment-store layer depends
on it. Do not export `ledgr_config()` until the run-store API proves user-facing
construction is needed.

**Tasks:**
1. Add `class = "ledgr_config"` to configs returned by `ledgr_config()`.
2. Add internal `validate_ledgr_config()`.
3. Add `print.ledgr_config()` if config objects remain visible through
   `bt$config`.
4. Share config validation between runner and future run-hydration paths.
5. Record the export decision explicitly in docs or tickets.

**Acceptance Criteria:**
- [x] Config objects have class `ledgr_config`.
- [x] Internal validation exists and is tested.
- [x] Existing `ledgr_backtest()` and runner behavior is unchanged.
- [x] `ledgr_config()` remains internal unless an explicit export decision is
      recorded.
- [x] `contracts.md` records the config lifecycle contract.

**Test Requirements:**
- `tests/testthat/test-backtest-wrapper.R`
- `tests/testthat/test-config*.R` or new targeted config tests
- Acceptance tests for v0.1.0-v0.1.3

**Source Reference:** A2

---

## LDG-705: Public `ledgr_data_hash()` Deprecation and Internal Hash Split

**Priority:** P1  
**Effort:** 1 day  
**Dependencies:** LDG-701

**Description:**
Deprecate or legacy-mark the public v0.1.0 `ledgr_data_hash()` helper without
breaking internal run and snapshot-adapter hash paths.

**Tasks:**
1. Audit all internal call sites of `ledgr_data_hash()`.
2. Separate hash responsibilities:
   - snapshot artifact hash;
   - run data-subset hash, if retained;
   - future feature-cache input identity.
3. Add explicit internal helpers for run and adapter needs.
4. Replace internal uses of the public legacy helper.
5. Update docs so users are not taught direct `bars` table writes as a modern
   workflow.
6. Deprecate or mark public `ledgr_data_hash()` as legacy v0.1.0.
7. Document the transition in `NEWS.md`.

**Acceptance Criteria:**
- [x] Internal run and adapter paths no longer depend on ambiguous public
      legacy semantics.
- [x] Public docs explain that `ledgr_data_hash()` is legacy if it remains
      exported.
- [x] Snapshot-backed workflows use snapshot hashes, not direct `bars` writes.
- [x] Any deprecation is reflected in `NEWS.md`.

**Test Requirements:**
- `tests/testthat/test-data-hash.R`
- Snapshot adapter tests
- Acceptance tests for snapshot-backed runs

**Source Reference:** A3

---

## LDG-706: Reconstruction Documentation Cleanup

**Priority:** P2  
**Effort:** 0.5 days  
**Dependencies:** None

**Description:**
Clarify that `ledgr_state_reconstruct(run_id, con)` is a low-level recovery API
that requires an explicit DBI connection, while normal users should inspect
results through S3/tibble helpers.

**Tasks:**
1. Lead user examples with `tibble::as_tibble(bt, what = "equity")`.
2. Show `ledgr_state_reconstruct()` only as low-level recovery/rebuild.
3. State clearly that callers using `ledgr_state_reconstruct()` own the DBI
   connection lifecycle.
4. Keep `ledgr_extract_fills()` and `ledgr_compute_equity_curve()` positioned
   as read helpers, not alternate reconstruction implementations.

**Acceptance Criteria:**
- [x] Normal result inspection examples do not require DBI.
- [x] Low-level reconstruction docs are accurate about `con`.
- [x] `contracts.md` remains consistent with the reconstruction delegation
      chain.

**Test Requirements:**
- `devtools::document()` or `roxygen2::roxygenise()`
- `R CMD check --no-manual --no-build-vignettes`

**Source Reference:** A4

---

## LDG-707: Optional Indicator Deregistration Helper

**Priority:** P3  
**Effort:** 0.5 days  
**Dependencies:** None

**Description:**
Add `ledgr_deregister_indicator()` for interactive sessions and tests. This
is optional because current examples already clean up local registry state, but
the helper is useful for explicit session cleanup and avoids direct access to
the package registry environment.

**Tasks:**
1. [x] Decide whether public deregistration is worth adding in v0.1.4.
2. [x] If added, implement `ledgr_deregister_indicator(name, missing_ok = TRUE)`.
3. [x] Ensure deregistration affects only the session registry.
4. [x] Document that persisted run artifacts are not changed.
5. [x] Add tests for existing, missing, and invalid names.

**Acceptance Criteria:**
- [x] Decision is recorded.
- [x] If implemented, helper is exported, documented, and tested.
- [x] Helper does not mutate persisted artifacts.
- [x] Not applicable: helper was implemented rather than closed as intentionally
  unnecessary.

**Test Requirements:**
- `tests/testthat/test-indicators.R`
- `tests/testthat/test-api-exports.R` if exported

**Source Reference:** A5

**Classification:**
```yaml
risk_level: low
implementation_tier: M
review_tier: M
classification_reason: >
  New exported function with bounded scope. The indicator registry is
  session-scoped and not persisted, so deregistration cannot corrupt run
  artifacts. New export requires a NEWS entry per the compatibility policy.
invariants_at_risk:
  - indicator registry consistency
  - new export must not break existing ledgr_register_indicator() contract
required_context:
  - R/indicator.R
  - tests/testthat/test-indicators.R
  - tests/testthat/test-api-exports.R
  - inst/design/contracts.md (Compatibility Policy)
tests_required:
  - deregistering an existing indicator removes it from the registry
  - deregistering a missing indicator with missing_ok = TRUE succeeds silently
  - deregistering a missing indicator with missing_ok = FALSE errors
  - persisted run artifacts are not affected
  - NAMESPACE and exports are clean
escalation_triggers:
  - implementation touches indicator fingerprinting logic
  - implementation affects registered indicators in active backtest state
forbidden_actions:
  - modifying ledgr_register_indicator() behaviour
  - touching the execution path or fingerprinting logic
```

---

## LDG-708: Load Existing Sealed Snapshots

**Priority:** P0  
**Effort:** 1 day  
**Dependencies:** None

**Description:**
Add `ledgr_snapshot_load()` so durable research scripts can reopen an existing
sealed snapshot without re-importing data or failing on duplicate
`snapshot_id`.

**Tasks:**
1. Implement `ledgr_snapshot_load(db_path, snapshot_id, verify = FALSE)`.
2. Validate that `snapshot_id` exists.
3. Validate that status is `SEALED`.
4. Return a `ledgr_snapshot` handle without importing or mutating bars.
5. Do not silently create or overwrite snapshots.
6. Document when full artifact-hash verification occurs.
7. Update the getting-started vignette to show the load path for reruns.

**Acceptance Criteria:**
- [x] Re-running a script can load an existing snapshot instead of failing.
- [x] Missing snapshots error clearly.
- [x] Unsealed snapshots error clearly.
- [x] Loading a snapshot does not mutate persistent tables.
- [x] Vignette shows the durable rerun workflow.

**Test Requirements:**
- New `tests/testthat/test-snapshots-load.R`
- Snapshot creation/list/info tests
- Getting-started vignette render

**Source Reference:** B1

---

## LDG-709: Path-First Snapshot Listing

**Priority:** P1  
**Effort:** 0.5 days  
**Dependencies:** None

**Description:**
Make `ledgr_snapshot_list()` support both DBI connections and DuckDB file paths,
matching the v0.1.2+ user mental model.

**Tasks:**
1. Support `ledgr_snapshot_list(con)`.
2. Support `ledgr_snapshot_list("artifact.duckdb")`.
3. Open and close connections internally for path input.
4. Preserve the existing `status` filter.
5. Update examples to show path-first use.

**Acceptance Criteria:**
- [x] Path input works without manual DBI setup.
- [x] Connection input remains backward compatible.
- [x] Path-based calls close their internal connection.
- [x] Existing `status` behavior is unchanged.

**Test Requirements:**
- `tests/testthat/test-snapshots-create-list.R`
- New path-first tests
- `R CMD check --no-manual --no-build-vignettes`

**Source Reference:** B2

---

## LDG-710: Current Target Helper

**Priority:** P0  
**Effort:** 0.5-1 day  
**Dependencies:** None

**Description:**
Add `ctx$current_targets()` to prevent accidental flattening in strategies that
intend to hold current positions when no signal fires.

**Tasks:**
1. Add `ctx$current_targets()` to runtime pulse contexts.
2. Add the same helper to `ledgr_pulse_snapshot()` contexts.
3. Return a full named numeric vector over `ctx$universe`.
4. Initialize values from current positions.
5. Use zero for known instruments with no current position.
6. Preserve existing `ctx$targets(default = 0)` behavior.
7. Document that `ctx$targets()` starts from flat and
   `ctx$current_targets()` starts from current holdings.
8. Add tests for flat, held, multi-instrument, and invalid-universe contexts.

**Acceptance Criteria:**
- [x] Runtime contexts expose `ctx$current_targets()`.
- [x] Interactive pulse contexts expose `ctx$current_targets()`.
- [x] Existing `ctx$targets()` behavior remains backward compatible.
- [x] Docs warn that returning zero targets means go flat.
- [x] Hold-state strategy examples use `ctx$current_targets()`.

**Test Requirements:**
- `tests/testthat/test-pulse-context-accessors.R`
- `tests/testthat/test-indicator-tools.R`
- Strategy contract tests

**Source Reference:** B3

---

## LDG-711: Research Workflow Documentation Updates

**Priority:** P1  
**Effort:** 1 day  
**Dependencies:** LDG-708, LDG-710

**Description:**
Update docs and tutorials for realistic research workflows: position sizing,
connection cleanup, fill model behavior, and rebalance throttling.

**Tasks:**
1. Show position sizing from scalar fields:
   `ctx$cash`, `ctx$equity`, and `ctx$close(id)`.
2. Do not add `ctx$cash()` or `ctx$equity()` methods.
3. Add `on.exit(close(bt), add = TRUE)` to longer-running examples.
4. Explain that closing releases DuckDB connections and does not delete stable
   files.
5. Correct fill model wording: default is next available open price, zero
   spread, zero fixed commission.
6. Add one non-default fill model example if the API supports it cleanly.
7. Document self-throttling with `ctx$ts_utc`.
8. Show a monthly rebalance pattern using `ctx$current_targets()`.
9. Update README/vignettes only where this improves clarity; keep README short.

**Acceptance Criteria:**
- [x] Vignette examples deploy a meaningful fraction of capital.
- [x] `ctx$cash` and `ctx$equity` are documented as scalar fields.
- [x] Connection lifecycle docs include `on.exit(close(...), add = TRUE)`.
- [x] Fill model docs say next-open, not instant.
- [x] Rebalance throttling example uses `ctx$ts_utc`.
- [x] No engine-level `rebalance_frequency` is added in this ticket.

**Test Requirements:**
- README render smoke test if README changes
- Getting-started vignette render
- `R CMD check --no-manual --no-build-vignettes`

**Source Reference:** B4, B5, B6, B7

---

## LDG-712: Vectorized Indicator `series_fn`

**Priority:** P0  
**Effort:** 2-3 days  
**Dependencies:** None

**Description:**
Add an optional vectorized full-series indicator path to avoid the current
expanding-window fallback cost for custom indicators.

**Tasks:**
1. Add `series_fn` parameter to `ledgr_indicator()`.
2. Validate `series_fn` purity and deterministic behavior.
3. Include `series_fn` in indicator fingerprinting.
4. Define the contract:
   - input is one instrument's full bar series in ascending time order;
   - output is numeric length `nrow(bars)`;
   - output aligns to bar row order;
   - warmup `NA_real_` and `NaN` are normalized to `NA_real_`;
   - non-finite values outside warmup are invalid.
5. Update feature precomputation to use `series_fn` when present.
6. Add `series_fn` implementations for built-in indicators.
7. Decide and implement fallback `fn` window semantics.
8. If fallback `fn` moves from expanding to bounded windows, document this
   behavior change in `NEWS.md`.
9. Update indicator docs.
10. Update the existing custom-indicators vignette if it remains current, or
    create a focused custom-indicators vignette section if the existing article
    is not adequate for `series_fn`.

**Acceptance Criteria:**
- [x] Custom indicators with `series_fn` avoid the expanding-window loop.
- [x] Built-in indicators use the vectorized path.
- [x] `fn`-only indicators continue to work.
- [x] `series_fn` output length and alignment are validated.
- [x] Warmup `NaN` is normalized to `NA_real_`.
- [x] Indicator fingerprint changes when `series_fn` changes.
- [x] Any fallback behavior change is documented in `NEWS.md`.

**Test Requirements:**
- `tests/testthat/test-indicators.R`
- `tests/testthat/test-features.R`
- No-lookahead tests
- Custom-indicators vignette/render check if the vignette is changed or created

**Source Reference:** C1

---

## LDG-713: Feature Cache Across Parameter Sweeps

**Priority:** P1  
**Effort:** 2-3 days  
**Dependencies:** LDG-712

**Description:**
Add a session-scoped feature cache so repeated runs over the same snapshot and
indicator fingerprint do not recompute the same feature series.

**Tasks:**
1. [x] Define feature cache key:
   `snapshot_hash + instrument_id + indicator_fingerprint + feature_engine_version`.
2. [x] Use `snapshot_hash`, not `snapshot_id`, as data identity.
3. [x] Include date range in the key only if the cache stores range-limited series.
4. [x] Implement a session-scoped cache.
5. [x] Add public `ledgr_clear_feature_cache()`.
6. [x] Add telemetry for feature cache hits and misses.
7. [x] Make precomputation check the cache before calling `series_fn`.
8. [x] Add tests proving `series_fn` is not called again on cache hit.
9. [x] Document that the cache is not persisted across R sessions.

**Acceptance Criteria:**
- [x] First run computes and caches feature series.
- [x] Subsequent same-snapshot/same-indicator runs do not call `series_fn`.
- [x] Cache key uses `snapshot_hash`.
- [x] Cache key includes indicator fingerprint and feature-engine version.
- [x] Telemetry shows cache hits/misses.
- [x] Tests avoid brittle wall-clock thresholds.
- [x] `ledgr_clear_feature_cache()` is exported and tested.

**Test Requirements:**
- New feature cache tests
- `tests/testthat/test-features.R`
- `tests/testthat/test-backtest-wrapper.R`
- Coverage gate

**Source Reference:** C2

---

## LDG-715: Low-Code TTR Indicator Constructor

**Priority:** P1  
**Effort:** 1-2 days  
**Dependencies:** LDG-713

**Description:**
Add a low-code `ledgr_ind_ttr()` constructor for common TTR indicators. The
constructor should produce normal `ledgr_indicator` objects with `series_fn`
support, deterministic fingerprints, and explicit warmup semantics.

This is not a generic loose wrapper around arbitrary R functions. It is a
TTR-specific convenience layer that lets users write readable research code for
well-known technical indicators while preserving ledgr's reproducibility
contracts.

**User-Facing UX:**
```r
rsi_14 <- ledgr_ind_ttr("RSI", input = "close", n = 14)

atr_20 <- ledgr_ind_ttr(
  "ATR",
  input = "hlc",
  output = "atr",
  n = 20
)

macd <- ledgr_ind_ttr(
  "MACD",
  input = "close",
  output = "macd",
  nFast = 12,
  nSlow = 26,
  nSig = 9
)
```

**Design Rules:**
1. Name the constructor `ledgr_ind_ttr()`, not `ledgr_adapter_ttr()`, because it
   creates an indicator rather than a data/snapshot adapter.
2. Add `ledgr_ttr_warmup_rules()` as an exported inspectable rules table. Do not
   export a mutable constant.
   The return schema must be a data frame/tibble with at least:
   - `ttr_fn`: TTR function name;
   - `input`: supported ledgr input shape;
   - `formula`: human-readable warmup formula;
   - `required_args`: character/list column of args required for inference;
   - `id_args`: character/list column giving deterministic ID arg order.
3. Include a TTR function in the inference table only when required bars are
   deterministic from explicit arguments alone. No heuristics.
4. Do not rely on TTR's default indicator parameters for warmup inference or ID
   generation. Parameterized functions must receive explicit args such as `n`,
   `nFast`, `nSlow`, and `nSig`.
5. If warmup cannot be inferred, require explicit `requires_bars` and give an
   actionable error explaining how to measure it by counting leading `NA` values
   on a sample TTR output.
   Known functions with missing explicit args must fail before calling TTR with
   an example-driven message, for example:
   ```text
   TTR::RSI requires explicit `n` for ledgr warmup inference and stable indicator IDs.
   Example: ledgr_ind_ttr("RSI", input = "close", n = 14)
   ```
6. Store TTR metadata in indicator params with a clear split between identity
   fields and forwarded TTR args:
   ```r
   params = list(
     ttr_fn = "ATR",
     ttr_version = as.character(utils::packageVersion("TTR")),
     input = "hlc",
     output = "atr",
     args = list(n = 20)
   )
   ```
7. Forward only `params$args` to TTR:
   ```r
   ttr_fn <- getExportedValue("TTR", params$ttr_fn)
   result <- do.call(ttr_fn, c(list(x), params$args))
   ```
8. Include `ttr_version` in params so indicator fingerprints change when TTR is
   upgraded.
9. Generate deterministic default IDs from explicit user-supplied args:
   `ttr_<fn>_<id_args in rules-table order>[_<output>]`.
10. For known functions, ID arg order comes from the rules table, not
    alphabetical order. For unknown functions with explicit `requires_bars`, use
    alphabetical ordering of supplied args unless the user provides `id`.

**Input Mapping Contract:**
- `input = "close"` -> numeric vector `bars$close`
- `input = "hlc"` -> matrix with columns `High`, `Low`, `Close`
- `input = "ohlc"` -> matrix with columns `Open`, `High`, `Low`, `Close`
- `input = "hlcv"` -> matrix with columns `High`, `Low`, `Close`, `Volume`

Column names must match TTR expectations exactly for functions that validate
their input names.

**Initial Warmup Rules:**
- `RSI`, `input = "close"`: `requires_bars = n + 1`, `id_args = n`
- `SMA`, `input = "close"`: `requires_bars = n`, `id_args = n`
- `EMA`, `input = "close"`: `requires_bars = n + 1`, `id_args = n`
- `ATR`, `input = "hlc"`: `requires_bars = n + 1`, `id_args = n`
- `MACD`, `input = "close"`: `requires_bars = nSlow + nSig - 1`,
  `id_args = nFast,nSlow,nSig`

**Tasks:**
1. [x] Implement `ledgr_ttr_warmup_rules()`.
2. [x] Implement `ledgr_ind_ttr(ttr_fn, input, output = NULL, id = NULL,
   requires_bars = NULL, stable_after = requires_bars, ...)`.
3. [x] Implement TTR input builders with explicit column naming.
4. [x] Implement TTR output selection:
   - vector output can use `output = NULL`;
   - multi-column output requires `output`;
   - invalid output names fail with available choices.
5. [x] Implement scalar `fn` fallback and vectorized `series_fn` from the same
   TTR call template.
6. [x] Add dependency handling with `requireNamespace("TTR", quietly = TRUE)` and a
   clear error when TTR is unavailable.
7. [x] Include TTR version, input shape, output name, function name, and forwarded
   args in indicator params/fingerprints.
8. [x] Add reference documentation and examples guarded for optional TTR dependency
   where needed.
9. [x] Update custom-indicators or getting-started docs only where this improves the
   research-loop story without bloating onboarding.

**Acceptance Criteria:**
- [x] `ledgr_ind_ttr("RSI", input = "close", n = 14)` creates a valid
      `ledgr_indicator`.
- [x] `ledgr_ind_ttr("ATR", input = "hlc", output = "atr", n = 20)` creates a
      valid `ledgr_indicator`.
- [x] `ledgr_ind_ttr("MACD", input = "close", output = "macd", nFast = 12,
      nSlow = 26, nSig = 9)` creates a valid `ledgr_indicator`.
- [x] `series_fn` is used in backtest feature precomputation.
- [x] Scalar `fn` and `series_fn` agree on the latest value for supported
      indicators.
- [x] `ledgr_ttr_warmup_rules()` is exported, documented, and test-covered.
- [x] `ledgr_ttr_warmup_rules()` returns the documented schema.
- [x] Warmup inference uses only explicit args and documented deterministic
      rules.
- [x] Missing required explicit args fail before calling TTR.
- [x] Unknown functions require explicit `requires_bars`.
- [x] Multi-column TTR output without `output` fails with available column names.
- [x] Invalid `output` names fail with available column names.
- [x] Indicator fingerprint changes when TTR version metadata changes.
- [x] Input builders produce TTR-compatible column names.

**Test Requirements:**
- `tests/testthat/test-indicators.R`
- `tests/testthat/test-indicator-adapters.R` or new `test-indicator-ttr.R`
- Warmup-rule contract test that runs each rules-table entry against TTR output
  and verifies the first non-`NA` row matches the inferred `requires_bars`
- Backtest integration test proving `series_fn` is called once per instrument
- Optional-dependency skip path when TTR is unavailable
- `R CMD check --no-manual --no-build-vignettes`

**Source Reference:** TTR UX discussion after LDG-712

**Status Note:** P1 outstanding — MACD `histogram` output gets
`requires_bars = nSlow` instead of `nSlow + nSig - 1`. Fix
`ledgr_ttr_infer_requires_bars` to include `"histogram"` in the signal-tier
warmup branch, and add histogram and signal cases to the warmup verification
test.

**Classification:**
```yaml
risk_level: low
implementation_tier: M
review_tier: M
classification_reason: >
  Narrow bug fix in the TTR adapter. One-line change to
  ledgr_ttr_infer_requires_bars to include histogram in the signal-tier warmup
  branch, plus verification test cases. Does not touch the execution path,
  fill semantics, or any other invariant-sensitive area.
invariants_at_risk:
  - MACD histogram warmup correctness (currently too short by nSig - 1 bars)
required_context:
  - R/indicator-ttr.R
  - tests/testthat/test-indicator-ttr.R
  - LDG-715 review findings (MACD histogram P1 bug)
tests_required:
  - ledgr_ttr_infer_requires_bars("MACD", ..., output = "histogram") returns nSlow + nSig - 1
  - warmup verification test covers MACD histogram output against actual TTR output
  - warmup verification test covers MACD signal output against actual TTR output
escalation_triggers:
  - fix requires touching anything outside R/indicator-ttr.R and test-indicator-ttr.R
forbidden_actions:
  - changing any other warmup formula
  - touching the execution path or feature cache
```

---

## LDG-716: Expand TTR Warmup Rules and Indicator Documentation

**Priority:** P1  
**Effort:** 1-2 days  
**Dependencies:** LDG-715

**Description:**
Expand the TTR adapter from the initial core set to a broader common technical
analysis set while preserving the LDG-715 rule: only infer warmup when the first
stable row is deterministic from explicit arguments alone.

This ticket should make the TTR bridge a visible value proposition: ledgr users
can use common TTR indicators as normal `ledgr_indicator` objects with
deterministic IDs, fingerprint metadata, `series_fn` precomputation, and feature
caching.

**Candidate Functions:**
- `WMA`, `input = "close"`: `requires_bars = n`, `id_args = n`
- `ROC`, `input = "close"`: `requires_bars = n + 1`, `id_args = n`
- `momentum`, `input = "close"`: `requires_bars = n + 1`, `id_args = n`
- `CCI`, `input = "hlc"`: `requires_bars = n`, `id_args = n`
- `BBands`, `input = "close"`: `requires_bars = n`, `id_args = n`
- `aroon`, `input = "hlc"`: `requires_bars = n + 1`, `id_args = n`
- `DonchianChannel`, `input = "hlc"`: `requires_bars = n`, `id_args = n`
- `MFI`, `input = "hlcv"`: `requires_bars = n + 1`, `id_args = n`
- `CMF`, `input = "hlcv"`: `requires_bars = n`, `id_args = n`
- Rolling statistics with deterministic `n`, for example `runMean`, `runSD`,
  `runVar`, and `runMAD`, `input = "close"`: `requires_bars = n`,
  `id_args = n`

The final implementation may drop a candidate if TTR output, arguments, or
warmup behavior fail the deterministic inclusion rule. Dropped candidates must
be listed in a short implementation note or ticket comment.

**Explicitly Out Of Scope:**
- `ADX`, `stoch`, `DEMA`, `TEMA`, `ZLEMA`, `HMA`, `SAR`, `PSAR`, `OBV`, `CLV`,
  `williamsAD`, and similar functions whose warmup or semantics need a separate
  design decision.
- Heuristic warmup approximations.
- Making TTR a hard dependency.
- Changing the feature-engine `series_fn` contract.

**Documentation Scope:**
Add a pkgdown article or article-style vignette explaining the TTR adapter as a
hexagonal boundary:

```text
TTR -> ledgr_ind_ttr() -> ledgr_indicator -> deterministic pulse engine
```

The article should explain:
- the indicator port: `fn`, `series_fn`, `requires_bars`, `stable_after`, and
  `params`;
- why TTR stays outside the engine and the engine only sees `ledgr_indicator`
  objects;
- how TTR metadata affects indicator fingerprints;
- examples for simple, multi-input, and multi-output indicators;
- `ledgr_ttr_warmup_rules()` as the inspectable source of inferred support;
- custom `series_fn` as the escape hatch for unsupported indicators.

**Tasks:**
1. Expand `ledgr_ttr_warmup_rules()` with the accepted common TTR functions.
2. Update `ledgr_ttr_infer_requires_bars()` and ID generation coverage for all
   new rows.
3. Add or adjust input/output selection support only where it follows the
   existing LDG-715 contracts.
4. Extend warmup verification tests so every rules-table row is run against
   actual TTR output and the first non-`NA` row equals inferred
   `requires_bars`.
5. Add required-argument and multi-output error tests for representative new
   functions.
6. Add documentation for the TTR adapter philosophy and examples.
7. Add the article to `_pkgdown.yml` under the relevant navbar section.
8. Update `NEWS.md` and `contracts.md` if the supported TTR surface or contract
   language changes.

**Acceptance Criteria:**
- [ ] Every added TTR rule has deterministic warmup from explicit args alone.
- [ ] Every rules-table row is tested against actual TTR output.
- [ ] No added rule relies on TTR default parameters for warmup or ID
      generation.
- [ ] Deterministic IDs use rules-table `id_args` order.
- [ ] Multi-output indicators require or validate `output` with available
      choices.
- [ ] Unsupported/ambiguous TTR functions still require explicit
      `requires_bars`.
- [ ] TTR remains an optional dependency.
- [ ] TTR adapter article renders offline and links from appropriate reference
      or pkgdown navigation.
- [ ] `_pkgdown.yml` links the article from the package site navigation.

**Test Requirements:**
- `tests/testthat/test-indicator-ttr.R`
- warmup-rule contract test over all rows in `ledgr_ttr_warmup_rules()`
- representative backtest integration test for at least one newly added
  indicator
- documentation render / pkgdown build check
- `R CMD check --no-manual --no-build-vignettes`

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Bounded expansion of the TTR adapter within the existing LDG-715 contract.
  The work adds supported warmup-rule rows, tests them against actual TTR
  output, and documents the adapter philosophy. It does not touch the execution
  path or persistence, but warmup correctness affects feature availability and
  deserves Tier H review.
invariants_at_risk:
  - TTR warmup correctness
  - deterministic indicator IDs
  - TTR input/output mapping correctness
  - documentation must not imply unsupported TTR functions are inferred
required_context:
  - inst/design/model_routing.md
  - R/indicator-ttr.R
  - tests/testthat/test-indicator-ttr.R
  - inst/design/contracts.md (Context Contract and series_fn/TTR metadata contract)
  - _pkgdown.yml
  - LDG-715 review findings
  - TTR documentation for newly added functions
tests_required:
  - every new rules-table row is verified against actual TTR output
  - required explicit args fail before calling TTR
  - supported input mappings produce TTR-compatible column names
  - multi-output functions require or validate output selection
  - deterministic IDs use rules-table id_args order
  - pkgdown article/example renders without network access
  - _pkgdown.yml links the article from the package site navigation
  - R CMD check passes
escalation_triggers:
  - adding a TTR function whose warmup is not deterministic from explicit args alone
  - changing ledgr_indicator(), feature computation, feature cache, or execution code
  - adding hard dependencies on TTR or pkgdown-only packages
  - changing public behavior of existing supported TTR wrappers beyond documented warmup additions
forbidden_actions:
  - using heuristic or approximate warmup rules
  - relying on TTR default indicator parameters for ID or warmup inference
  - making TTR a hard package dependency
  - changing the core feature-engine series_fn contract
```

---

## LDG-714: v0.1.4 Stabilisation Gate

**Priority:** P0  
**Effort:** 1 day  
**Dependencies:** LDG-701, LDG-702, LDG-703, LDG-704, LDG-705, LDG-706, LDG-708, LDG-709, LDG-710, LDG-711, LDG-712, LDG-713, LDG-715, LDG-716

**Description:**
Final validation gate for the v0.1.4 stabilisation cycle.

**Tasks:**
1. Ensure `contracts.md` is updated for compatibility policy, strategy tiers,
   config lifecycle, snapshot load semantics, target helper semantics, and
   feature series/cache identity.
2. Ensure `NEWS.md` documents all deprecations, breaking changes, and behavior
   changes.
3. Regenerate documentation.
4. Run v0.1.2 and v0.1.3 acceptance tests.
5. Run the full package check.
6. Run coverage gate.
7. Run README and vignette render checks if docs changed.
8. Confirm CI is green on Ubuntu and Windows.

**Acceptance Criteria:**
- [ ] `R CMD check --no-manual --no-build-vignettes` passes with 0 errors and
      0 warnings.
- [ ] v0.1.2 and v0.1.3 acceptance tests pass.
- [ ] Coverage remains at or above 80%.
- [ ] README cold-start check passes if README changed.
- [ ] pkgdown site builds if reference/vignette docs changed.
- [ ] Ubuntu and Windows CI are green.
- [ ] `contracts.md` and `NEWS.md` match the implemented scope.

**Test Requirements:**
- `tools/check-readme-example.R`
- `tools/check-coverage.R`
- `R CMD check --no-manual --no-build-vignettes`
- `.github/workflows/R-CMD-check.yaml`
- `pkgdown::build_site()`

**Source Reference:** Global Definition Of Done

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Release gate. Validates the entire v0.1.4 scope — contracts, NEWS, test
  coverage, R CMD check, CI, and acceptance tests. Cannot be delegated to a
  lower tier. This ticket IS the final Tier H review.
invariants_at_risk:
  - all v0.1.4 contracts
  - public API surface and compatibility policy
  - reproducibility and determinism guarantees
  - coverage gate
required_context:
  - inst/design/contracts.md
  - NEWS.md
  - inst/design/ledgr_v0_1_4_spec_packet/v0_1_4_tickets.md (all acceptance criteria)
  - inst/design/model_routing.md
  - .github/workflows/R-CMD-check.yaml
  - tools/check-coverage.R
  - tools/check-readme-example.R
  - All prior review findings for v0.1.4 tickets
tests_required:
  - R CMD check passes 0 errors 0 warnings on Ubuntu and Windows
  - coverage >= 80%
  - README cold-start check passes
  - pkgdown site builds without errors
  - v0.1.2 and v0.1.3 acceptance tests pass
  - contracts.md and NEWS.md match implemented scope
escalation_triggers: []
forbidden_actions:
  - accepting the gate with any open P0 or P1 issues
  - bypassing R CMD check or coverage gate
  - releasing without green CI on both platforms
```

---

## Out of Scope

Do not implement these in the stabilisation cycle:

- live trading;
- paper trading;
- broker adapters;
- streaming data;
- engine-level rebalance scheduler;
- parameter optimization UI;
- persistent feature cache;
- full experiment-store comparison API;
- strategy extraction/revival API.
