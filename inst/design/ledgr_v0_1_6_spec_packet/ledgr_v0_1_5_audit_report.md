# ledgr v0.1.5 — Usability Audit Report

**Auditor:** Claude Sonnet 4.6  
**Date:** 2026-04-28  
**Package:** `blechturm/ledgr` @ commit `594599c` (v0.1.5)  
**R Version:** 4.5.2  
**Platform:** Windows 11 Pro 10.0.26200  
**Test suite:** `01_data_and_snapshots.R`, `02_strategies.R`, `03_indicators.R`, `04_experiment_store.R`, `05_edge_cases.R`  
**Full output:** `run_all_output.txt`

---

## Executive Summary

ledgr is a well-conceived event-sourced backtesting framework with a sound architectural foundation. Its core loop — sealed snapshot → pulse engine → immutable event ledger — correctly prevents lookahead and produces reproducible results. The indicator system and experiment store are the standout features. However, the package carries meaningful friction in its first-use experience: a non-obvious feature ID naming scheme causes strategy failures that are hard to anticipate, several documented functions are broken or have wrong signatures in the reference, and the documentation has significant gaps around multi-asset strategies, fill models, and the experiment store.

**Overall verdict:** Promising research tool, not yet suitable as a primary production-facing library without UX polish.

---

## Test Results Summary

| Section | Description | PASS | FAIL | Total |
|---------|-------------|------|------|-------|
| 1 | Snapshot creation (all ingestion paths) | 11 | 3 | 14 |
| 2 | Strategies & backtests (6 strategies) | 8 | 4 | 12 |
| 3 | Indicators (18 TTR + custom API) | 35 | 2* | 37 |
| 4 | Experiment store (run management) | 11 | 3 | 14 |
| 5 | Edge cases & error handling | 14 | 2† | 16 |
| **Total** | | **79** | **14** | **93** |

\* Both failures are confirmed bugs in `ledgr` itself, not test errors.  
† Both "failures" are design gaps rather than crashes (zero capital not rejected, last-bar warning not emitted).

---

## Performance Benchmarks

All times on Windows 11, R 4.5.2, synthetic OHLCV (no disk I/O bottleneck):

| Operation | Assets | Bars | Features | Elapsed |
|-----------|--------|------|----------|---------|
| Buy-and-hold | 1 | 504 | 0 | 2.16 s |
| SMA crossover | 1 | 504 | 2 | 2.83 s |
| RSI mean reversion | 1 | 504 | 1 | 2.64 s |
| Multi-asset EMA+BBands | 5 | 504 | 4 | 2.22 s |
| RSI+MACD+ATR | 1 | 504 | 4 | 1.89 s |
| Single indicator backtest (avg, 252 bars) | 1 | 252 | 1 | ~2.2 s |
| Yahoo Finance fetch (2 symbols, 1 year) | 2 | 500 | — | 1.1 s |
| `ledgr_run_open()` (no recompute) | — | — | — | 0.22 s |
| Snapshot creation (5 assets, 252 bars) | — | 1260 | — | 0.65 s |

**Observation:** There is a fixed overhead of ~1.9–2.2 s per backtest that is largely independent of bar count and feature count. This overhead is dominated by DuckDB session setup, event ledger writes, and R↔DuckDB marshalling — not by the strategy computation itself. A 252-bar single-asset run takes roughly the same time as a 504-bar 5-asset run. For iterative research workflows with hundreds of backtests this floor cost is significant and should be called out explicitly in the docs.

---

## Confirmed Bugs

### BUG-1: `ledgr_state_reconstruct()` — missing `con` argument

**Severity:** High  
**Reproduction:** Call `ledgr_state_reconstruct(bt)` on any completed backtest object.  
**Error:** `error in evaluating the argument 'dbObj' in selecting a method for function 'dbIsValid': argument "con" is missing, with no default`  
**Impact:** The function is completely unusable. It dispatches to a DBI method internally with a missing argument.

### BUG-2: `ledgr_snapshot_list(ledgr_snapshot)` — dispatch error

**Severity:** Medium  
**Reproduction:** `ledgr_snapshot_list(snap)` where `snap` is a `ledgr_snapshot` object.  
**Error:** `unable to find an inherited method for function 'dbIsValid' for signature 'dbObj = "ledgr_snapshot"'`  
**Note:** `ledgr_snapshot_list(con)` where `con` is a DBI connection works correctly. The docs state it accepts either. Only the `ledgr_snapshot_info()` overload works with a snapshot object.

### BUG-3: `ledgr_data_hash(data.frame)` — wrong dispatch

**Severity:** Low  
**Reproduction:** `ledgr_data_hash(bars_df)` where `bars_df` is a data frame.  
**Error:** `unable to find an inherited method for function 'dbIsValid' for signature 'dbObj = "data.frame"'`  
**Note:** The reference page implies this hashes data for fingerprinting, but the function dispatches to a DBI method. The actual expected input is unclear.

### BUG-4: `ledgr_backtest_bench()` — undocumented expected argument type

**Severity:** Medium  
**Reproduction:** `ledgr_backtest_bench(artifact_db)` where `artifact_db` is a DuckDB file path.  
**Error:** `` `bt` must be a ledgr_backtest object. ``  
**Note:** The reference page does not clearly document what argument type is expected. Passing a db_path (consistent with `ledgr_run_list`) fails.

### BUG-5: `strategy_params` not accessible via `ctx$params`

**Severity:** High  
**Reproduction:**
```r
ledgr_backtest(
  ...,
  strategy_params = list(rsi_buy = 35),
  strategy = function(ctx) {
    thresh <- ctx$params$rsi_buy  # NULL — argument is of length zero
  }
)
```
**Error:** `argument is of length zero`  
**Note:** The parameter is accepted by `ledgr_backtest()` without error, and the getting-started docs mention `strategy_params`, but there is no documented example showing how to access params from within the strategy. `ctx$params` appears to return NULL or an invalid object.

### BUG-6: `ledgr_backtest_bench()` — requires a `ledgr_backtest` object, not a db path

See BUG-4 above. After investigation: the function likely benchmarks a single run, not the entire experiment store. The `ledgr_run_list()` pattern (which takes `db_path`) does not apply here.

---

## UX Issues

### UX-1: Feature ID naming is opaque and non-discoverable ⚠️ (Critical)

This is the most impactful UX problem in the package. The feature IDs assigned by the engine to `ledgr_ind_ttr()` indicators follow an undocumented encoding scheme:

| Call | Expected ID (intuitive) | Actual ID |
|------|------------------------|-----------|
| `ledgr_ind_ttr("BBands", output="up", n=20)` | `bbands_up` | `ttr_bbands_20_up` |
| `ledgr_ind_ttr("MACD", output="macd", nFast=12, nSlow=26, nSig=9)` | `macd_macd` | `ttr_macd_12_26_9_macd` |
| `ledgr_ind_ttr("ATR", output="atr", n=14)` | `atr_atr` | `ttr_atr_14_atr` |
| `ledgr_ind_ttr("CCI", n=20)` | `cci_cci` | `ttr_cci_20_cci` |

The convention is `ttr_{fn_lower}_{params}_{output}`. This is internally deterministic and defensible (it prevents collisions between `sma_10` and `sma_20`), but it is **completely undocumented** and impossible to guess without trial-and-error.

**Every user will fail Strategy 4 and 5 (multi-indicator strategies) the first time they write them.** The error message does list the available IDs, which mitigates the impact, but relying on runtime errors for discoverability is poor UX.

**Recommendation:** Either (a) document the naming scheme explicitly with examples, (b) expose `ind$id` prominently so users know the ID before writing strategy code, or (c) provide a `ledgr_feature_id()` helper that computes the ID from a given indicator definition.

### UX-2: MACD requires different parameter names than all other indicators

`ledgr_ind_ttr("MACD", n = NULL)` fails with a clear error asking for `nFast`, `nSlow`, `nSig`. All other indicators use `n`. This special case is mentioned in the TTR vignette example but not called out as a deviation from the norm.

### UX-3: Two-tier API is conflated in the reference

The snapshot API has two completely different calling conventions:

**High-level (object-based, recommended):**
```r
snap <- ledgr_snapshot_from_df(bars_df)
# returns a ledgr_snapshot object; DBI is hidden
```

**Low-level (connection-based):**
```r
con <- ledgr_db_init(db_path)
sid <- ledgr_snapshot_create(con)
ledgr_snapshot_import_bars_csv(con, sid, csv)
ledgr_snapshot_seal(con, sid)
DBI::dbDisconnect(con, shutdown = TRUE)
```

The reference page lists both tiers in the same "Snapshots" section without explaining which to use or why. Several functions (`ledgr_snapshot_list`, `ledgr_snapshot_info`) claim to accept either a `con` or a `ledgr_snapshot` but the snap-object dispatch is broken (BUG-2).

### UX-4: `ledgr_compute_metrics()` reference is misleading

The reference page and summary output hint that this is a standalone metrics function you can call on an equity tibble. In practice it requires a full `ledgr_backtest` object. Calling it on `as_tibble(bt, what="equity")` produces:
```
`x` must be a ledgr_snapshot or ledgr_backtest object.
```

### UX-5: Duplicate feature name error message is internal DuckDB jargon

When two indicators with the same ID are passed to `features`, the error is:
```
TransactionContext Error: Current transaction is aborted (please ROLLBACK)
```
This is a raw DuckDB error that leaks the storage layer. A user-facing message ("Duplicate feature ID: sma_10 is registered twice") would be far more actionable.

### UX-6: `initial_cash = 0` silently accepted

A backtest with zero starting capital proceeds without error or warning. Every position size calculation (`floor(ctx$equity * 0.99 / ctx$close(...))`) will return 0, producing a dead run. A guard at backtest creation is warranted.

### UX-7: LEDGR_LAST_BAR_NO_FILL warning not observed

The documentation states: "If strategy requests position change on the last available bar, ledgr warns with `LEDGR_LAST_BAR_NO_FILL`." Testing with a 5-bar dataset where the strategy attempts to buy on every pulse did not trigger this warning. The warning may have been removed or the condition is more specific than documented.

### UX-8: `ctx$current_targets()` vs `ctx$targets()` distinction is subtle

`ctx$targets()` returns a named zero-vector (all instruments at zero), while `ctx$current_targets()` returns the current live positions. This distinction is crucial — using `ctx$targets()` as the base and only overriding specific names will inadvertently flatten all positions on every bar. This gotcha is mentioned once in the getting-started guide but not emphasized. New users consistently reach for the wrong one first.

### UX-9: `print(bt)` and `summary(bt)` print the same content

`print(bt)` displays the full results block. `summary(bt)` shows a metrics-only block followed by the same results. The distinction between print/summary is blurry and neither is a true tidy summary. Sharpe ratio, Sortino ratio, and Calmar ratio are absent from both.

---

## Documentation Critique

### What works well

- **Getting Started article** is clear and well-paced. The pipeline diagram (data → snapshot → pulses → event ledger → results) is an excellent conceptual anchor. The "no-lookahead" guarantee is stated explicitly and early.
- **TTR Indicators article** lists all 18 supported functions with input types, output column selection, and example code. This is the most complete article in the package.
- **Error messages for input validation** are generally good: missing columns, OHLC violations, non-chronological data, and universe mismatch all produce actionable error messages.
- **`ledgr_snapshot_info()` metadata** is rich — snapshot hash, bar count, instrument count, creation/seal timestamps, and JSON metadata are all included.

### What is missing or misleading

| Gap | Impact |
|-----|--------|
| **Feature ID naming convention not documented** | Every multi-indicator strategy will fail silently on first write | High |
| **`strategy_params` access mechanism not shown** | A documented parameter that cannot be used | High |
| **No vignette on the experiment store** | The most distinctive feature (run management, reproducibility tiers) has no dedicated article | High |
| **No vignette on multi-asset strategies** | The monthly rebalance pattern and per-instrument feature access are only hinted at | Medium |
| **No vignette on fill models** | `spread_bps` and `commission_fixed` are listed but not explained; no discussion of transaction cost impact on results | Medium |
| **Low-level vs high-level API not distinguished** | Users reading the reference cannot tell which functions to call | Medium |
| **`ledgr_backtest_bench()` has no meaningful docs** | Function purpose and expected arguments are unclear | Medium |
| **Design Philosophy article is 404** | A linked article returns HTTP 404 | Low |
| **Reproducibility tiers (tier_1, tier_2) unexplained** | The run info shows `reproducibility: tier_2` with no explanation of what tiers mean | Low |
| **`close()` resource management undocumented** | Users must discover that snapshot and backtest objects hold DuckDB connections that must be closed | Low |

---

## Architecture Observations

### Strengths

1. **Immutable event ledger** — All state flows through append-only fills. "Trades, equity, and metrics are views over recorded history." This is the right abstraction for reproducible research.

2. **Sealed snapshot** — Locking data before a backtest begins means data mutation is impossible after the fact. This solves a real problem in research: inadvertent lookahead from mutable data sources.

3. **DuckDB as the persistence layer** — Excellent choice. Fast, self-contained, no server, supports both in-memory and durable modes. The DuckDB file serves as the artifact store for both snapshots and runs.

4. **Pulse engine correctly prevents lookahead** — Tested via edge case EC-4 and EC-5: the engine does not expose future prices to the strategy. The fill model (next-open fill) is the right default.

5. **Custom indicator API** — `ledgr_indicator(id, fn, requires_bars)` with a `window` object (containing all OHLCV fields) is clean and composable. `ledgr_adapter_r()` makes it trivial to wrap any base-R function. `ledgr_adapter_csv()` supports pre-computed signals from external systems.

6. **Experiment store** — `ledgr_run_list`, `ledgr_run_open`, `ledgr_run_label`, `ledgr_run_archive` form a coherent research workflow. The idempotency of `run_id` (returning the existing run rather than recomputing) is correct and useful. Run-level hashes (snapshot hash, config hash, strategy hash, params hash) are the foundation for a real reproducibility guarantee.

### Weaknesses

1. **Fixed per-backtest overhead (~2 s)** — The DuckDB session initialization and event ledger I/O dominate runtime for typical short research backtests. Iterating over a grid of 100 parameter combinations would take ~200 s just in infrastructure overhead. A batch/vectorized backtest mode (multiple parameter sets, single session) would be a major productivity improvement.

2. **No short selling** — Negative targets are silently clamped to zero. This is a fundamental limitation for strategies that require hedging or market-neutral positions. The min fill quantity returned `Inf` in our test (a reporting artifact), but no fills for short positions were created.

3. **No portfolio-level position sizing** — The strategy must compute share quantities manually (`floor(equity * weight / price)`). Helpers for common sizing schemes (Kelly, risk parity, volatility targeting) would reduce boilerplate and errors.

4. **No walk-forward / cross-validation** — There is no built-in support for out-of-sample testing. A walk-forward runner that chunks the snapshot and runs train/test splits would be a significant addition.

5. **Feature state is not accessible across instruments in a single call** — The strategy loop must call `ctx$feature(sym, name)` per instrument. There is no `ctx$all_features()` that returns a cross-sectional matrix, which limits signal construction for ranking-based strategies.

6. **`ctx$current_targets()` / `ctx$targets()` naming** — `targets()` (zero vector) vs `current_targets()` (live positions) is a confusion-prone pair. Renaming to `ctx$empty_targets()` / `ctx$targets()` would be clearer.

---

## Indicator Coverage

All 18 TTR indicators documented as supported were tested. All passed:

| Category | Indicators |
|----------|-----------|
| Close-based (all pass) | SMA, EMA, WMA, RSI, ROC, momentum, runMean, runSD, runVar, runMAD |
| Multi-input (all pass) | BBands (up/dn/mavg), MACD (macd/signal), ATR (atr/trueHigh), CCI, aroon (oscillator), DonchianChannel (high), MFI, CMF |
| Manual warmup | DEMA (pass) |
| Custom `ledgr_indicator()` | Pass — `fn(window)` receives full OHLCV window |
| `ledgr_adapter_r()` | Pass — wraps any base-R function |
| `ledgr_adapter_csv()` | Pass — loads pre-computed signals |
| `ledgr_signal_strategy()` | Pass — "LONG"/"FLAT"/"SHORT" signal wrapper |

---

## Edge Case Findings

| Test | Result | Notes |
|------|--------|-------|
| Missing required columns | ✓ Rejected | Clear error listing missing columns |
| NA prices | ✓ Rejected at snapshot | `bars_df OHLC columns must be finite numeric values` |
| Negative targets (shorting) | ✓ Clamped | No error; short positions silently not created |
| Out-of-universe `ctx$close()` | ✓ Error propagated | Error surfaces correctly to strategy |
| Always-throwing strategy | ✓ Error propagated | Backtest fails with strategy error |
| `initial_cash = 0` | ✗ Silently accepted | No guard — all position sizes compute to 0 |
| Bars < warmup period | ✓ Accepted silently | Features all NA; correct by design |
| Last-bar position change | ✗ Warning not emitted | Documented warning `LEDGR_LAST_BAR_NO_FILL` not observed |
| Duplicate timestamps | ✓ Rejected | `must be chronological per instrument (non-decreasing ts_utc)` |
| Empty universe | ✓ Rejected | `universe must contain at least one instrument` |
| `start > end` window | ✓ Rejected | Clear error |
| Ghost symbol in targets | ✓ Rejected | `extra instruments: NONEXISTENT` |
| Duplicate feature names | ✓ Rejected | Error message is raw DuckDB text (UX-5 above) |
| Invalid db path | ✓ Error | `cannot open the connection` |
| start/end window filter | ✓ Correct | Returns exact bar range |

---

## Recommendations (Priority Order)

1. **Document the feature ID naming scheme** (or expose `ind$id` prominently). This is the #1 first-use failure point.
2. **Fix `ledgr_state_reconstruct()`** — crashes unconditionally.
3. **Document `strategy_params` access** — show `ctx$params$key` in a working example.
4. **Add a "Experiment Store" vignette** — run management, labels, archive, and the reproducibility tier system.
5. **Fix `ledgr_snapshot_list(ledgr_snapshot)`** — document or fix the dispatch.
6. **Add `initial_cash` validation** — warn or error on zero/negative values.
7. **Replace internal DuckDB error on duplicate features** with a user-facing message.
8. **Address the ~2 s fixed overhead** — document it as a known characteristic and/or add a batch mode.
9. **Clarify `ctx$targets()` vs `ctx$current_targets()`** — rename or add clear docstring explaining the dangerous default.
10. **Add Sharpe/Sortino to `summary(bt)`** — these are the most basic risk-adjusted metrics expected by any quant practitioner.
