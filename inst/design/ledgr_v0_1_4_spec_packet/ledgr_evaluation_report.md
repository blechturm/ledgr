# ledgr Package Evaluation Report

**Package:** ledgr v0.1.3  
**Evaluated:** 2026-04-26  
**R version:** 4.5.2  
**Evaluator:** Automated UX/functionality test via Claude Code  

---

## 1. Test Setup

Four trading strategies were implemented using real market data (SPY, QQQ, GLD) over a 5-year window (2020-01-01 to 2024-12-31). Each strategy exercises a different part of the ledgr API.

| Strategy | Instruments | Indicators | API Surface Tested |
|---|---|---|---|
| SMA Crossover (20/50) | SPY | `ledgr_ind_sma()` | snapshot, backtest, all result views |
| RSI Mean-Reversion (14) | SPY | `ledgr_ind_rsi()` | signal_strategy wrapper, pulse debugging |
| EMA Trend + ATR Filter | SPY | `ledgr_ind_ema()` + custom `ledgr_indicator()` | custom indicator via TTR |
| Momentum Rotation | SPY / QQQ / GLD | custom `ledgr_indicator()` | multi-asset, universe inference |

---

## 2. Strategy Performance Summary

Backtest period: 2020-01-01 to 2024-12-31 | Initial capital: $100,000 | No commission model.

> **WARNING: Important caveat:** All strategies use absolute quantity `1` (one share). With $100K capital and SPY at ~$300-600/share, only 0.3-0.6% of the portfolio is deployed at any time. Returns appear tiny as a result. This is a documentation/UX issue (see Section 5.4).

| Strategy | Total Return | Ann. Return | Volatility | Max DD | Trades | Win Rate | Avg Trade | Time in Market |
|---|---|---|---|---|---|---|---|---|
| SMA Crossover (20/50) | +0.30% | +0.06% | 0.10% | -0.15% | 21 | 23.8% | $5.34 | 68.0% |
| RSI Mean-Reversion (raw) | -0.02% | -0.00% | 0.35% | -0.35% | 50 | 34.0% | $1.27 | 5.9% |
| RSI Mean-Reversion (signal_strategy) | -0.04% | -0.01% | 0.16% | -0.33% | 26 | 38.5% | $4.91 | 29.8% |
| EMA Trend (50/200) | +0.24% | +0.05% | 0.06% | -0.09% | 5 | 20.0% | $12.11 | 65.7% |
| EMA Trend + ATR20 Filter | +0.24% | +0.05% | 0.10% | -0.14% | 9 | 22.2% | $18.46 | 61.1% |
| Momentum Rotation | -0.01% | -0.00% | 2.97% | -1.21% | 291 | 28.5% | $0.74 | 71.4% |
| **Buy-and-Hold SPY (benchmark)** | **+0.27%** | **+0.05%** | 0.08% | -0.12% | 1 | 0%* | $0* | 99.9% |

*Win rate / avg_trade for B&H = 0 because the position was never closed; metrics are based on realized P&L only.

---

## 3. Performance / Speed

Measured with `proc.time()` elapsed on a local Windows machine.

| Operation | Time |
|---|---|
| `ledgr_snapshot_from_yahoo("SPY", 5y)` | 1.02 s |
| `ledgr_snapshot_from_yahoo(3 symbols, 5y)` | 1.43 s |
| Backtest: SMA 20/50, 1257 bars | 3.22 s |
| Backtest: RSI 14, 1257 bars | 2.90 s |
| Backtest: EMA 50+200 (2 built-in indicators), 1257 bars | 4.86 s |
| Backtest: EMA 50+200 + custom ATR20 (TTR), 1257 bars | **17.14 s** |
| Backtest: 3-asset momentum (1 custom indicator), 3x1257 bars | 3.90 s |
| Backtest: Buy-and-hold SPY, 1257 bars | 1.57 s |
| `ledgr_pulse_snapshot()` (single bar debug) | 0.11 s |

**Finding 3.1 - Custom R indicators are 3.5x slower than built-ins.**  
Adding one custom `ledgr_indicator()` that calls `TTR::ATR()` increased backtest time from 4.86 s to 17.14 s (+12.3 s) for 1,257 bars. The overhead likely comes from per-pulse R function dispatch and data-frame construction overhead. Built-in indicators (`ledgr_ind_ema`, `ledgr_ind_sma`, `ledgr_ind_rsi`) are presumably implemented more efficiently in the engine layer.

For research workflows with many parameter combinations (e.g., grid searches), the 12-17 second base cost per run would become a significant bottleneck.

**Finding 3.2 - Pulse debugging is fast (0.11 s).**  
`ledgr_pulse_snapshot()` is well-optimized for the interactive debugging use case.

**Finding 3.3 - Base backtest speed is moderate.**  
3-5 seconds for 1,257 bars x 1-2 built-in indicators is workable for single runs but feels slow for interactive research. By comparison, Python-based backtesting frameworks (Zipline, VectorBT) process similar datasets in <0.5 s. Whether the overhead is inherent to the event-sourced architecture or an optimization opportunity is unclear.

---

## 4. Errors Encountered

### Error 4.1 - `snapshot_id already exists` (reproducibility workflow blocker)

**Severity: High**

When `ledgr_snapshot_from_yahoo()` is called a second time with the same `db_path` and `snapshot_id` (e.g., re-running a script), it throws:

```
Error in ledgr_snapshot_create(...) : snapshot_id already exists: spy_2020_2024
```

There is no "load if exists" path, no `overwrite` parameter, and no `ledgr_snapshot_load()` function. This directly contradicts the "durable research artifact" workflow the vignette promotes:

```r
# From getting-started vignette - this will FAIL on the second run:
snapshot <- ledgr_snapshot_from_csv(csv_path = "bars.csv", db_path = "artifact.duckdb")
```

**Workaround used during evaluation:** Remove `db_path` argument to use a fresh `tempfile()` each run (loses persistence).

**Recommended fix:** Add `overwrite = FALSE` parameter, or add `ledgr_snapshot_load(db_path, snapshot_id)` function.

---

### Error 4.2 - `ledgr_snapshot_list()` crashes with missing `con` argument

**Severity: Medium**

Calling `ledgr_snapshot_list()` without arguments (as implied by the reference docs) throws:

```
error in evaluating the argument 'dbObj' in selecting a method for function 'dbIsValid':
  argument "con" is missing, with no default
```

The function signature in the docs shows no required parameters, but internally it expects a database connection that isn't exposed. The function is broken as documented.

**Recommended fix:** Either accept a `db_path` argument and open the connection internally, or fix the default so it falls back to an in-memory list of snapshots created in the session.

---

## 5. UX Observations

### 5.1 - `snapshot_id` naming convention warning is noisy

The package warns when `snapshot_id` doesn't match `snapshot_YYYYmmdd_HHMMSS_XXXX`:

```
Warning: `snapshot_id` does not match 'snapshot_YYYYmmdd_HHMMSS_XXXX'.
  Using a canonical format improves provenance.
```

This warning appears on every snapshot creation, including in the official tutorial examples that use simple IDs like `"demo"`. New users following the vignette will immediately see a warning for code that is copy-pasted from the docs.

**Recommended fix:** Either update tutorial examples to use canonical IDs, or add a `quiet = TRUE` parameter to suppress the warning for users who don't need provenance tracking.

---

### 5.2 - `ctx$targets()` initializes to zero, not to current positions (undocumented)

The docs say `ctx$targets()` "creates named target vector across full universe." A reasonable reading of "creates" suggests it returns the current holdings so the strategy only needs to update what changes. In practice, it returns a zero vector (all flat).

This was discovered when the RSI raw strategy showed only 5.9% time-in-market vs 29.8% for the equivalent `ledgr_signal_strategy()` version. In the raw strategy:

```r
# Between RSI 30-70: intended to "hold" current position
targets <- ctx$targets()       # actually returns zeros
# ... neither branch fires ...
return(targets)                # returns zeros = go flat!
```

The "hold" case silently flattens the position. The signal_strategy version correctly uses `ctx$position("SPY")` to check current holdings.

**Recommended fix:** Document clearly in `ctx$targets()` that it returns a zero vector. Add a note warning that omitting an instrument from targets means "go flat on that instrument." Consider adding `ctx$current_targets()` that initializes from actual positions.

---

### 5.3 - No portfolio-fraction position sizing

The strategy interface accepts only absolute share quantities. There is no:
- `ctx$cash()` or `ctx$portfolio_value()` to compute share quantities from portfolio percentages
- Convenience such as `floor(ctx$portfolio_value() * 0.99 / ctx$close("SPY"))` being documented

Without these, all tutorial strategies use `targets["SPY"] <- 1L`, which with $100K capital deploys approx.0.3% of portfolio. The strategy appears to "barely beat cash" even when the underlying signal logic is sound. This is the biggest source of user confusion for anyone evaluating the package for the first time.

**Recommended fix:** Add `ctx$cash()` and `ctx$equity()` methods to allow position sizing, and update tutorial examples to show a realistic allocation like:

```r
strategy <- function(ctx) {
  targets <- ctx$targets()
  if (signal_is_long) {
    price <- ctx$close("SPY")
    qty   <- floor(ctx$cash() * 0.95 / price)  # deploy 95% of cash
    targets["SPY"] <- qty
  }
  targets
}
```

---

### 5.4 - `win_rate` and `avg_trade` are zero for buy-and-hold

`ledgr_compute_metrics()` computes `win_rate` and `avg_trade` from realized P&L of closed trades. A buy-and-hold strategy with one BUY and no SELL has `win_rate = 0` and `avg_trade = 0`, even though the strategy is clearly profitable.

This is technically correct (no closed trades = no realized wins) but will confuse users benchmarking against B&H.

**Recommended fix:** Document this behavior. Optionally, add an `unrealized_pnl` or `open_pnl` field to the equity curve or metrics.

---

### 5.5 - `as_tibble(what = "ledger")` returns only fills

The design philosophy describes the "event ledger" as the source of truth containing all recorded decisions and state changes. In practice, `as_tibble(bt, what = "ledger")` returns 21 rows for the SMA strategy - the same count as `what = "trades"`. If the ledger contains only fill events, it's not materially different from the trades view.

Expected ledger events might include: signal decisions, portfolio valuations at each pulse, indicator values, rejected orders, etc.

**Recommended fix:** Clarify the distinction between "trades" and "ledger" in the docs. If they currently return the same data, document why, or expand the event types captured.

---

### 5.6 - print/summary connection state inconsistency

For the same snapshot object, `print(snap)` showed `Connection: Closed (opens on-demand)` while `summary(snap)` showed `Connection: Open`. After `summary()` opened the connection to compute the per-instrument table, the connection remained open. This is cosmetically inconsistent.

---

### 5.7 - Package version warnings on every load

On R 4.5.2, the packages `quantmod`, `xts`, `TTR`, and `tibble` each warn "was built under R version 4.5.3" on every run. This is a dependency management issue (ledgr bundles or requires packages built for a newer R patch) but creates noisy output for users.

---

### 5.8 - No commission / slippage model in default workflow

`fill_model = NULL` means instant fills at close with zero fees. The fills table confirms `fee = 0` for every trade. For a backtesting framework used in research, this overstates strategy performance. While the parameter exists, its API is not surfaced in the reference docs, making it invisible to new users.

**Recommended fix:** Document `fill_model` with at least one concrete example (e.g., a fixed commission per trade).

---

### 5.9 - Momentum rotation fires daily (no rebalance throttling)

The multi-asset momentum strategy fired 291 trades over 5 years - roughly one rotation every 4.3 trading days. This is because `ledgr_backtest()` calls the strategy function on every bar with no built-in rebalance throttle. A daily-bar momentum strategy that computes 20-day returns will naturally churn constantly.

There is no `rebalance_frequency` parameter or helper. In other frameworks (Zipline's `schedule_function`, backtrader's timer), rebalancing at weekly/monthly cadence is a first-class feature.

**Recommended fix:** Add a `ctx$bar_index()` or `ctx$ts_utc()` method (or document that it exists) so strategies can self-throttle:

```r
if (format(ctx$ts_utc(), "%d") == "01") { # first trading day of month
  # rebalance
}
```

Or provide a `rebalance_on` parameter to `ledgr_backtest()`.

---

### 5.10 - Connection resource management requires user discipline

Every backtest creates a DuckDB connection that must be closed with `close(bt)`. If a script errors partway through, connections leak. The docs don't show `on.exit(close(bt))` or a `with_backtest()` pattern.

**Recommended fix:** Document `on.exit(close(bt), add = TRUE)` as the recommended pattern, or provide a `ledgr_with_backtest()` helper that auto-closes.

---

## 6. What Works Well

**6.1 - Core strategy API is clean and intuitive.**  
The `ctx$close()`, `ctx$feature()`, `ctx$position()`, `ctx$targets()` interface is well-designed. The strategy-as-function pattern is idiomatic R. A new user can write a meaningful strategy in ~10 lines.

**6.2 - `ledgr_signal_strategy()` wrapper is a good ergonomic shortcut.**  
For simple long/flat/short strategies, the signal wrapper avoids boilerplate. The LONG/FLAT/SHORT vocabulary is clear.

**6.3 - Built-in indicators cover the basics.**  
`ledgr_ind_sma()`, `ledgr_ind_ema()`, `ledgr_ind_rsi()` cover the most common indicators. The `ledgr_indicator()` custom constructor is straightforward for extending with TTR or any R function.

**6.4 - `ledgr_pulse_snapshot()` is an excellent debugging tool.**  
Being able to freeze a single decision point and replay the strategy function is genuinely useful and fast (0.11 s). This is one of the most distinctive features of ledgr.

**6.5 - print() and summary() output is well-formatted.**  
Both methods produce readable, well-labeled output with clear sections. The equity curve tibble (`ts_utc`, `equity`, `cash`, `positions_value`, `running_max`, `drawdown`) is well-structured.

**6.6 - Reproducibility design is sound.**  
The event-sourced ledger, sealed snapshots with data hashes, and `run_id` for resumable runs provide genuine reproducibility guarantees that most R backtesting packages lack.

**6.7 - Yahoo Finance integration works out of the box.**  
`ledgr_snapshot_from_yahoo()` downloads 5 years of data and seals it into DuckDB in ~1 second. The dependency on `quantmod` is well-hidden.

**6.8 - `as_tibble()` multi-view output is convenient.**  
The `what = "trades"` / `"equity"` / `"ledger"` parameter makes it easy to pipe results into ggplot2 or dplyr without manual extraction.

---

## 7. Summary of Recommended Improvements

| Priority | Issue | Effort |
|---|---|---|
| High | Add `ledgr_snapshot_load()` or `overwrite` param to fix re-run crash | Low |
| High | Fix `ledgr_snapshot_list()` crash (missing `con` argument) | Low |
| Medium | Add `ctx$cash()` / `ctx$equity()` for position sizing | Medium |
| Medium | Document `ctx$targets()` zero-initialization clearly | Low |
| Medium | Add rebalance throttling (`ctx$ts_utc()` or `rebalance_on` param) | Medium |
| Low | Document `on.exit(close(bt))` pattern for connection safety | Low |
| Low | Document `fill_model` with example | Low |
| Low | Clarify "ledger" vs "trades" view distinction | Low |
| Low | Add `ctx$current_targets()` initialized from actual positions | Medium |
| Low | Investigate custom indicator performance (3.5x overhead) | Medium |
| Low | Fix `snapshot_id` naming warning in tutorial examples | Trivial |
| Low | Fix print/summary connection state display inconsistency | Trivial |

---

## 8. Overall Assessment

ledgr v0.1.3 is a well-conceived package with a genuinely interesting architecture. The event-sourced design provides reproducibility guarantees that are rare in R backtesting, and the `ledgr_pulse_snapshot()` debugging workflow is the standout feature.

The API surface is clean for simple strategies, and the built-in indicators and Yahoo Finance integration lower the barrier to entry. For its target audience - R quantitative researchers who value auditability over raw speed - the design is fit for purpose.

The two blocking issues (snapshot re-run crash, `ledgr_snapshot_list()` crash) need to be fixed before the package is recommended for general use. The missing position-sizing helpers make tutorial strategies misleadingly show near-zero returns, which could discourage early adopters.

Performance is adequate for single-run research but would be limiting for parameter sweeps or strategies with custom R indicators.

**Recommended next steps for the maintainer:**
1. Fix the two crash-level bugs.
2. Add `ctx$cash()` / `ctx$equity()` and update tutorial examples to show realistic portfolio sizing.
3. Investigate the custom indicator performance gap.
4. Add one worked example using `on.exit(close(bt))` and a monthly rebalance pattern.
