# Add Optional `{talib}` Indicator Adapter

## Context

Serkan has agreed to draft a PR for this -- thank you.

ledgr supports external indicator packages through adapters. `ledgr_ind_ttr()`
wraps `{TTR}`. This issue specifies an adapter for `{talib}`:

<https://github.com/serkor1/ta-lib-R>

The goal is to let ledgr users register TA-Lib-backed indicators as ordinary
ledgr features, without adding a new execution path or changing any existing
ledgr execution semantics.

## How ledgr Features Work

ledgr precomputes all feature series before a run starts and caches them keyed
by feature fingerprint. Strategies receive bar-by-bar slices from that cache --
the indicator is never called again at runtime.

`series_fn(bars, params)` is the full-series precompute entry point: it receives
all bars for one instrument and returns a numeric vector aligned to
`nrow(bars)`, with `NA_real_` for warmup rows. `stable_after` tells ledgr where
the warmup ends.

This is why `{talib}` is a natural fit. Its indicators already operate on full
OHLCV data frames and expose lookback metadata directly via `talib::lookback()`.

## Desired API Shape

```r
features <- ledgr_feature_map(
  rsi_14 = ledgr_ind_talib("RSI", input = "close", n = 14),
  bb_up  = ledgr_ind_talib("BBANDS", input = "ohlc", output = "UpperBand", n = 20)
)
```

`{talib}`'s snake_case names should also be accepted:

```r
ledgr_ind_talib("relative_strength_index", input = "close", n = 14)
```

Internally the adapter should canonicalize to the TA-Lib alias form (`"RSI"`,
`"BBANDS"`, `"MACD"`) for feature IDs and fingerprints.

## Implementation Contract

The adapter should return normal `ledgr_indicator` objects. The implementation
path is `series_fn`:

```r
series_fn <- function(bars, params) {
  result <- talib::RSI(bars, n = params$n)
  as.numeric(result)
}
```

The returned vector must be numeric, aligned to `nrow(bars)`, and use
`NA_real_` for warmup rows. Short samples must return aligned `NA_real_` values
rather than propagating low-level `{talib}` errors.

`stable_after` should be derived from `{talib}`'s lookback support:

```r
stable_after <- talib::lookback("RSI", n = 14)
```

Exact API may vary -- confirm against `{talib}` `0.9-1`.

## Input Mapping

Use ledgr's existing input-key convention:

- `"close"`
- `"hl"`
- `"hlc"`
- `"ohlc"`
- `"hlcv"`

These map to ledgr's lowercase bar columns (`open`, `high`, `low`, `close`,
`volume`), which matches `{talib}`'s default OHLCV naming. No renaming should be
needed inside the adapter.

## Feature Identity

Feature fingerprints must be deterministic and include:

- canonical TA-Lib alias;
- `{talib}` package version;
- input mapping;
- selected output column;
- forwarded arguments;
- `stable_after`;
- `source = "talib"`.

`ledgr_feature_contracts()` should report talib-backed indicators with
`source = "talib"`.

## Multi-Output Indicators

Multi-output indicators require explicit `output = ...`:

```r
ledgr_ind_talib("BBANDS", input = "ohlc", output = "UpperBand", n = 20)
ledgr_ind_talib("MACD", input = "close", output = "macd", fast = 12, slow = 26, signal = 9)
```

The adapter should validate that the requested output column exists.

## Initial Scope

Start with continuous numeric indicators. Suggested initial set:

- RSI
- SMA
- EMA
- MACD
- BBANDS
- ATR
- stochastic

Out of scope for this PR:

- Candlestick patterns. Functions like `CDL_DOJI` return discrete codes
  (`-100`, `0`, `100`), which have different output semantics from continuous
  numeric features and deserve their own design pass.
- Charting. No `talib::chart()`, `talib::indicator()`, plotly, or ggplot2
  integration.

## Testing Expectations

- Constructor validation.
- Feature ID and fingerprint stability.
- `source = "talib"` in `ledgr_feature_contracts()`.
- Direct output parity against `{talib}` for each supported indicator.
- Warmup boundary tests using `talib::lookback()` metadata.
- Short-sample tests returning aligned `NA_real_`.
- Multi-output selection tests.
- Clean `skip_if_not_installed("talib", minimum_version = "0.9-1")` behavior.
- At least one end-to-end `ledgr_run()` test with a talib-backed feature,
  including a sealed durable snapshot path, not only an in-memory path.

## Notes For Contributor

A draft PR is welcome -- API and warmup details can be refined in review.

The important boundary: the adapter produces ordinary `ledgr_indicator` objects
and preserves ledgr's existing snapshot-backed, no-lookahead execution path.
`{talib}` must remain optional (`Suggests`, not `Imports`). Tests must skip
cleanly when `{talib}` is not installed. Minimum version: `>= 0.9-1`.

