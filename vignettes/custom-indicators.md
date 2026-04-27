# Developing Custom Indicators

Full content in v0.1.3.

This vignette outline covers deterministic indicator construction, registry
usage, built-in indicators, R-function adapters, CSV adapters, and replay-safe
fingerprints.

## Outline

- Build indicators with `ledgr_indicator()`
- Add `series_fn` for full-series precomputation in backtests
- Use `ledgr_ind_sma()`, `ledgr_ind_ema()`, `ledgr_ind_rsi()`, and `ledgr_ind_returns()`
- Register and retrieve indicators
- Wrap package functions with `ledgr_adapter_r()`
- Use precomputed values with `ledgr_adapter_csv()`
- Understand purity and fingerprint requirements

## Vectorized Backtest Path

Custom indicators can provide two functions:

- `fn(window, params)` computes the latest value from a bounded window. This is
  used for interactive pulse development and as a fallback.
- `series_fn(bars, params)` computes the full numeric series for one instrument,
  aligned to the input rows. This is the preferred backtest path.

```r
atr_20 <- ledgr_indicator(
  id = "atr_20",
  fn = function(window, params) {
    hlc <- cbind(High = window$high, Low = window$low, Close = window$close)
    as.numeric(utils::tail(TTR::ATR(hlc, n = params$n)[, "atr"], 1))
  },
  series_fn = function(bars, params) {
    hlc <- cbind(High = bars$high, Low = bars$low, Close = bars$close)
    as.numeric(TTR::ATR(hlc, n = params$n)[, "atr"])
  },
  requires_bars = 21,
  stable_after = 21,
  params = list(n = 20)
)
```

The `series_fn` contract is strict:

- input is one instrument's bars in ascending time order;
- output is a numeric vector of length `nrow(bars)`;
- output position `i` belongs to bar row `i`;
- warmup `NA_real_` and `NaN` are normalized to `NA_real_`;
- infinite values, post-warmup `NA`, and post-warmup `NaN` values are invalid.

If an indicator has no `series_fn`, ledgr still supports `fn`. In v0.1.4 the
fallback uses bounded windows instead of expanding full-history slices, so
custom indicators do not accidentally do O(n^2) work by default.

The ATR example above uses `TTR`; production package examples should guard
optional dependencies before running them.
