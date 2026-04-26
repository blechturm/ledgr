# ledgr Pre-v0.1.4 Stabilisation Plan

**Status:** Revised draft  
**Date:** 2026-04-26  
**Supersedes:** `ledg_pre_v0.1.4_api_cleanup_proposal.md`  
**Inputs:** API cleanup proposal, evaluation report, Codex review, Claude synthesis

## Background

v0.1.3 is tagged and public. The package now has a credible onboarding path, but
the first real evaluation surfaced issues that should be addressed before the
experiment-store layer is built in v0.1.4.

The goal of this plan is targeted stabilisation, not a broad refactor. The work
focuses on:

1. clarifying the public API surface;
2. fixing durable-research workflow gaps;
3. removing common strategy-writing footguns;
4. improving custom-indicator performance enough for parameter sweeps;
5. documenting lifecycle and compatibility decisions before they become implicit.

## What This Does Not Touch

- The ledger append model.
- Snapshot sealing and artifact-hash semantics.
- The canonical `ledgr_backtest()` wrapper path.
- The core target-vector strategy contract.
- The scalar `ctx$cash` and `ctx$equity` fields.
- Live, paper, or broker execution.

## Pre-Gate: Compatibility Policy

**Timing:** Before locking v0.1.4 tickets.  
**Priority:** P0  
**Effort:** 0.25 days

v0.1.3 is public. Any removal of exported functions or behavior changes now need
an explicit v0.x policy.

Recommended policy:

> During v0.x, ledgr may make breaking changes when they protect correctness or
> simplify the public model. Every breaking change must be documented in
> `NEWS.md` and, where practical, pass through one deprecation release before
> hard removal.

**Definition of done:**

- Compatibility policy is added to the design docs.
- `contracts.md` links or summarizes the policy.
- `NEWS.md` is treated as mandatory for any breaking or deprecating API change.

## Pre-Gate: R6 Strategy Identity

**Timing:** Before locking the experiment-store run identity spec.  
**Priority:** P0  
**Effort:** 0.5 days

Functional strategies can be identified through source text, explicit
parameters, and hashes. R6 strategies do not yet have an equally clear
identity model. If v0.1.4 stores run identity without deciding how R6 strategies
are classified, the decision will be made implicitly by implementation details.

Recommended policy:

- Functional strategies with explicit `strategy_params` are the Tier 1
  reproducibility path.
- R6 strategies are Tier 2 by default unless they provide explicit
  source/params metadata or a future strategy-identity method.
- Run metadata must expose the reproducibility tier so users can distinguish
  fully replayable runs from auditable-but-not-fully-replayable runs.

**Definition of done:**

- v0.1.4 spec states how functional and R6 strategies map to reproducibility
  tiers.
- Run identity design does not silently treat R6 objects as fully reproducible.
- `contracts.md` records the strategy identity boundary.

## Pre-Gate: Design-File Encoding Hygiene

**Timing:** Before converting this plan into tickets.  
**Priority:** P1  
**Effort:** 0.25 days

Some current design inputs contain mojibake from pasted text. These files are
agent-facing project metadata, so encoding corruption makes search, parsing, and
future review worse.

**Definition of done:**

- Design files under `inst/design/` that feed v0.1.4 are normalized to clean
  UTF-8 or plain ASCII.
- Corrupted dash characters, multiplication signs, comparison symbols, and
  warning glyphs are replaced with readable text.

## Track A: API Surface Cleanup

**Timing:** Before or at the start of v0.1.4.  
**Rationale:** v0.1.4 will add run discovery, run identity, and experiment-store
primitives. The public surface should not carry avoidable contradictions into
that layer.

### A1: Define Lifecycle For `ledgr_backtest_run()`

**Priority:** P0  
**Effort:** 0.5 days

**Problem:**  
`ledgr_backtest_run()` is exported, used by old acceptance tests, and listed in
the locked export-surface test. Its own documentation says most users should call
`ledgr_backtest()`. Hard-unexporting it is a breaking change and cannot be
treated as mechanical cleanup.

**Decision:**  
In v0.1.4, soft-deprecate or clearly mark the function as low-level. Do not hard
remove it unless the compatibility policy explicitly permits the break and the
release notes call it out.

**Tasks:**

1. Keep the function exported for v0.1.4 unless a breaking-change decision is
   made.
2. Update docs to call it a low-level runner for internal/recovery workflows.
3. Keep examples illustrative-only unless a public config-construction path is
   available.
4. Add lifecycle wording to `NEWS.md` if deprecation is chosen.
5. If hard removal is chosen, update `NAMESPACE`, `test-api-exports.R`, old
   acceptance tests, specs, contracts, and release notes in one patch.

**Definition of done:**

- The public status of `ledgr_backtest_run()` is unambiguous.
- Docs no longer teach calling it after `ledgr_backtest()`.
- Any deprecation or removal is reflected in `NEWS.md`.

### A2: Class And Validate `ledgr_config()` Internally

**Priority:** P0  
**Effort:** 1 day

**Problem:**  
`ledgr_config()` constructs the canonical run config, but currently returns a
plain list and is not exported. The experiment-store layer will need a stable
config identity and validation path, but exporting the constructor too early
would commit ledgr to a public config shape before the run-store API is settled.

**Decision:**  
Stabilize the internal type first. Defer export until v0.1.4 proves that users
need direct config construction.

**Tasks:**

1. Add `class = "ledgr_config"` to the returned config object.
2. Add internal `validate_ledgr_config()`.
3. Add `print.ledgr_config()` if config objects remain visible through
   `bt$config`.
4. Keep `ledgr_config()` internal unless the v0.1.4 experiment-store spec
   requires public construction.

**Definition of done:**

- Config objects have a stable internal class.
- Internal validation is shared by runner and future run-hydration code.
- Export decision is recorded explicitly instead of happening accidentally.

### A3: Deprecate Public `ledgr_data_hash()` And Replace Internal Uses Deliberately

**Priority:** P1  
**Effort:** 1 day

**Problem:**  
`ledgr_data_hash()` is a v0.1.0-era helper over the legacy `bars` table. Modern
snapshot workflows use `snapshot_bars` and `snapshot_hash`. However, the function
still has internal call sites in:

- `R/backtest-runner.R`, for run `data_hash`;
- `R/snapshot_adapters.R`, through a temporary `bars` view over `snapshot_bars`.

Hard removal without replacing those internal responsibilities would break the
run path.

**Decision:**  
Deprecate or mark the public helper as legacy, but replace internal uses in the
same patch before any hard removal.

**Tasks:**

1. Identify the distinct hash responsibilities:
   - snapshot artifact hash;
   - run data-subset hash, if still needed;
   - future feature-cache input identity.
2. Add explicit internal helpers for current run/adapter needs.
3. Stop examples from teaching direct writes to the legacy `bars` table as a
   normal workflow.
4. Deprecate public `ledgr_data_hash()` or mark it as legacy v0.1.0.
5. Document the transition in `NEWS.md`.

**Definition of done:**

- Internal run and adapter paths no longer depend on ambiguous public legacy
  behavior.
- Public docs do not encourage direct `bars` table insertion outside legacy
  context.
- Any public deprecation is documented.

### A4: Clarify `ledgr_state_reconstruct()` As Low-Level Recovery

**Priority:** P2  
**Effort:** 0.5 days

**Problem:**  
`ledgr_state_reconstruct(run_id, con)` requires a DBI connection. Trying to hide
that in examples would be dishonest. But users should also not think DBI is
needed for normal result inspection.

**Tasks:**

1. Lead examples with `tibble::as_tibble(bt, what = "equity")` for normal use.
2. Show `ledgr_state_reconstruct()` only as low-level recovery/rebuild.
3. State that callers who use the low-level function own DBI connection
   lifecycle.
4. Consider a later no-DBI wrapper such as `ledgr_reconstruct_run(db_path,
   run_id)` if this workflow becomes common.

**Definition of done:**

- Normal users are routed to S3/tibble result helpers.
- Low-level reconstruction remains documented accurately.

### A5: Optional `ledgr_deregister_indicator()`

**Priority:** P3  
**Effort:** 0.5 days

**Problem:**  
The original API-cleanup review noted registry examples using `overwrite = TRUE`
and leaving global registry residue. Current examples already use local cleanup,
so this is no longer a blocker.

`ledgr_deregister_indicator()` may still be useful for interactive sessions and
tests.

**Tasks:**

1. Decide whether public deregistration is worth adding.
2. If added, use:

   ```r
   ledgr_deregister_indicator(name, missing_ok = TRUE)
   ```

3. Document that deregistration affects only the session registry, not persisted
   run artifacts.

**Definition of done:**

- Either no action is taken and this item is closed as unnecessary, or
  deregistration is exported and tested.

### A6: Resolve `ledgr_backtest_bench()` Public/Internal Status

**Priority:** P1  
**Effort:** 0.25 days

**Problem:**  
`ledgr_backtest_bench()` is exported, but its title says internal. With v0.1.4
adding performance work, a small telemetry helper may be useful publicly. The
current contradiction should be removed.

**Tasks:**

1. Decide whether `ledgr_backtest_bench()` is public or internal.
2. If public, remove "(internal)" from the title and document expected use.
3. If internal, deprecate or unexport through the compatibility policy.

**Definition of done:**

- Export status and documentation agree.

## Track B: Research Ergonomics

**Timing:** v0.1.4.  
**Rationale:** These close the gaps that appear once users move beyond the README
and begin re-running scripts, sizing positions, and debugging strategy state.

### B1: `ledgr_snapshot_load()`

**Priority:** P0  
**Effort:** 1 day

**Problem:**  
Re-running a script that creates a snapshot with the same `db_path` and
`snapshot_id` fails with `snapshot_id already exists`. The durable artifact
workflow needs a read path for existing sealed snapshots.

**Tasks:**

1. Implement `ledgr_snapshot_load(db_path, snapshot_id, verify = FALSE)`.
2. Validate that the snapshot exists.
3. Validate that status is `SEALED`.
4. Return a `ledgr_snapshot` handle without importing or mutating bars.
5. Do not silently create or overwrite snapshots.
6. Document when full hash verification happens.

**Definition of done:**

- Re-running a script can load the existing snapshot instead of failing.
- Missing or unsealed snapshots produce clear errors.
- The getting-started vignette shows the load path for reruns.

### B2: Path-First `ledgr_snapshot_list()`

**Priority:** P1  
**Effort:** 0.5 days

**Problem:**  
`ledgr_snapshot_list()` currently requires a DBI connection. Modern user docs
teach `db_path`, not raw DBI.

**Tasks:**

1. Support both:

   ```r
   ledgr_snapshot_list(con)
   ledgr_snapshot_list("artifact.duckdb")
   ```

2. If a path is supplied, open and close the connection internally.
3. Preserve the existing connection-based path.

**Definition of done:**

- Path-first listing works.
- Existing connection-first calls keep working.

### B3: `ctx$current_targets()` And Target Initialization Docs

**Priority:** P0  
**Effort:** 0.5 days

**Problem:**  
`ctx$targets()` returns a full target vector initialized to zero. That is correct
for "start from flat" logic, but it is a footgun for "hold unless signal changes"
strategies.

**Tasks:**

1. Add `ctx$current_targets()`, returning current positions over the full
   universe.
2. Make it available in runtime and `ledgr_pulse_snapshot()` contexts.
3. Document:
   - `ctx$targets()` starts from flat;
   - `ctx$current_targets()` starts from current holdings.
4. Update examples that intend to hold state.

**Definition of done:**

- Hold-state strategies can be written without manually looping over
  `ctx$position()`.
- Docs explicitly warn that returning zeros means go flat.

### B4: Position Sizing Documentation

**Priority:** P1  
**Effort:** 0.5 days

**Problem:**  
Examples that target one share make strategy returns look tiny on large initial
capital. This is a documentation problem, not an API problem.

**Tasks:**

1. Show sizing from scalar fields:

   ```r
   targets <- ctx$current_targets()
   qty <- floor(ctx$cash * 0.95 / ctx$close("SPY"))
   targets["SPY"] <- qty
   targets
   ```

2. Mention `ctx$cash` and `ctx$equity` in strategy docs.
3. Do not add `ctx$cash()` or `ctx$equity()` methods.

**Definition of done:**

- Vignette examples deploy a meaningful fraction of capital.
- Users can see how absolute target quantities relate to portfolio sizing.

### B5: Connection Lifecycle Documentation

**Priority:** P2  
**Effort:** 0.25 days

**Problem:**  
Backtest and snapshot objects hold DuckDB connections. Users should see the
safe cleanup pattern in longer scripts.

**Tasks:**

1. Document:

   ```r
   bt <- ledgr_backtest(...)
   on.exit(close(bt), add = TRUE)
   ```

2. Explain that closing releases the connection; it does not delete a persistent
   DuckDB file.

**Definition of done:**

- `ledgr_backtest()` docs and at least one tutorial use `on.exit(close(...),
  add = TRUE)`.

### B6: Fill Model Documentation

**Priority:** P2  
**Effort:** 0.25 days

**Problem:**  
Docs currently imply `fill_model = NULL` means instant fill, but the code uses
`type = "next_open"` with zero spread and zero fixed commission.

**Tasks:**

1. Document the default precisely:

   > next available open price, zero spread, zero fixed commission.

2. Add one concrete non-default example.
3. If a helper is exported later, prefer a name that reflects behavior, e.g.
   `ledgr_fill_next_open()`.

**Definition of done:**

- Users can understand when and where target changes are filled.
- The docs no longer call next-open execution "instant."

### B7: Rebalance Throttling Documentation

**Priority:** P2  
**Effort:** 0.5 days

**Problem:**  
Strategies run on every pulse. There is no built-in rebalance scheduler yet.
Users need a documented self-throttle pattern.

**Tasks:**

1. Confirm `ctx$ts_utc` is available in runtime and interactive contexts.
2. Document a monthly rebalance pattern:

   ```r
   targets <- ctx$current_targets()
   if (format(as.Date(ctx$ts_utc), "%d") != "01") return(targets)
   ```

3. Avoid adding `rebalance_frequency` in this stabilization pass.

**Definition of done:**

- Users can write simple throttle logic without engine-level scheduling.

## Track C: Performance

**Timing:** v0.1.4, or v0.1.4.1 if scope pressure is high.  
**Rationale:** Custom-indicator cost is the main blocker for parameter sweeps and
interactive research iteration.

### C1: `series_fn` Vectorized Indicator API

**Priority:** P0  
**Effort:** 2-3 days

**Problem:**  
Feature computation is already a pre-pass, but generic custom indicators are
computed by repeatedly calling `fn()` over expanding windows. For many useful
indicators this creates O(n^2)-like behavior.

**Fix:**  
Add optional `series_fn` to `ledgr_indicator()`.

```r
ledgr_indicator(
  id = "atr_20",
  fn = function(window, params) TTR::ATR(window)[nrow(window), "atr"],
  series_fn = function(bars, params) TTR::ATR(bars)[, "atr"],
  requires_bars = 20,
  stable_after = 20,
  params = list()
)
```

**Contract:**

- `series_fn` receives one instrument's full bar series in ascending time order.
- It receives deterministic `params`.
- It returns a numeric vector of length `nrow(bars)`.
- Output aligns to bar row order.
- `NA_real_` and `NaN` are allowed during warmup; the engine normalizes both to
  `NA_real_` before caching.
- Outside the warmup region, non-finite values are invalid.
- Warmup handling before `stable_after` must be explicit and tested.
- `series_fn` must pass purity checks.
- `series_fn` must be included in indicator fingerprinting.

**Fallback behavior decision:**  
The current fallback `fn` path uses expanding windows in
`ledgr_compute_feature_series()`, while `ledgr_compute_feature_latest()` uses a
bounded tail window. This inconsistency should be resolved.

Recommendation:

- Define `fn` as latest-value logic over the minimum sufficient lookback window.
- Change fallback series computation to pass bounded windows using
  `stable_after`.
- Document this as a v0.1.4 behavior change in `NEWS.md`.

**Tasks:**

1. Add `series_fn` parameter and validation to `ledgr_indicator()`.
2. Update feature precomputation to use `series_fn` when present.
3. Add `series_fn` implementations for built-in indicators.
4. Add tests for alignment, warmup, purity, and fingerprint changes.
5. Update adapter APIs where useful.
6. Document the behavior change for fallback `fn` if bounded windows are adopted.

**Definition of done:**

- Custom indicators with `series_fn` avoid the expanding-window loop.
- Built-in indicators use the vectorized path.
- `fn`-only indicators still work.
- Any fallback behavior change is in `NEWS.md`.

### C2: Feature Cache Across Sweeps

**Priority:** P1  
**Effort:** 2-3 days  
**Dependency:** C1

**Problem:**  
Parameter sweeps over the same snapshot and indicator definitions recompute the
same feature series on each run.

**Fix:**  
Add a session-scoped feature cache keyed by data identity and indicator identity.

Recommended key:

```text
snapshot_hash
+ instrument_id
+ indicator_fingerprint
+ feature_engine_version
```

Use `snapshot_hash`, not `snapshot_id`, because snapshot IDs are user labels and
can collide across databases. If the cache stores only range-limited series,
include the range in the key. If it stores full-snapshot series, range is not
needed.

**Tasks:**

1. Define cache key and feature-engine version.
2. Implement session-scoped cache.
3. Add public `ledgr_clear_feature_cache()`.
4. Add telemetry showing feature precompute cache hits and misses.
5. Add tests that verify `series_fn` is not called again on cache hit.
6. Document that the cache is session-scoped and not persisted.

**Definition of done:**

- First run computes and caches features.
- Subsequent runs with same snapshot hash and indicator fingerprint do not call
  `series_fn`.
- Telemetry shows near-zero feature precompute time on cache hits.
- Tests avoid brittle wall-clock thresholds.

Note: a 100-run sweep cannot be expected to complete in less than two times a
single run, because strategy execution, fill logic, ledger writes, and equity
outputs still run for each backtest.

## Revised Priority Summary

| ID | Title | Priority | Timing |
|:---|:---|:---|:---|
| Pre | v0.x compatibility policy | P0 | Pre-spec |
| Pre | R6 strategy identity policy | P0 | Pre-spec |
| Pre | Design-file encoding hygiene | P1 | Pre-spec |
| A1 | Lifecycle for `ledgr_backtest_run()` | P0 | Pre-spec |
| A2 | Internal `ledgr_config` class/validator | P0 | Pre-spec/v0.1.4 |
| A3 | Deprecate public `ledgr_data_hash`; replace internals | P1 | v0.1.4 |
| A4 | Clarify `ledgr_state_reconstruct()` docs | P2 | v0.1.4 |
| A5 | Optional `ledgr_deregister_indicator()` | P3 | Optional |
| A6 | Resolve `ledgr_backtest_bench()` status | P1 | Pre-spec |
| B1 | `ledgr_snapshot_load()` | P0 | v0.1.4 |
| B2 | Path-first `ledgr_snapshot_list()` | P1 | v0.1.4 |
| B3 | `ctx$current_targets()` | P0 | v0.1.4 |
| B4 | Position sizing docs | P1 | v0.1.4 |
| B5 | Connection lifecycle docs | P2 | v0.1.4 |
| B6 | Fill model docs | P2 | v0.1.4 |
| B7 | Rebalance throttling docs | P2 | v0.1.4 |
| C1 | `series_fn` indicator API | P0 | v0.1.4 |
| C2 | Feature cache across sweeps | P1 | v0.1.4/v0.1.4.1 |

## Global Definition Of Done

- `R CMD check --no-manual --no-build-vignettes` passes with 0 errors and 0
  warnings.
- v0.1.2 and v0.1.3 acceptance tests pass.
- Coverage gate remains at or above 80%.
- `contracts.md` is updated for:
  - compatibility policy;
  - R6 and functional strategy reproducibility tiers;
  - config lifecycle;
  - snapshot load semantics;
  - target helper semantics;
  - feature series/cache identity.
- `NEWS.md` documents any deprecation, breaking change, or indicator behavior
  change.
- v0.1.4 tickets are generated from this revised plan before implementation
  begins.
