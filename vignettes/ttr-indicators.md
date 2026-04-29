TTR Indicators In ledgr
================

`ledgr_ind_ttr()` is the low-code path for using TTR indicators in
ledgr.

TTR stays outside the core engine. The adapter translates a TTR call
into a normal `ledgr_indicator`:

``` text
TTR -> ledgr_ind_ttr() -> ledgr_indicator -> deterministic pulse engine
```

The engine does not need to know which external package produced the
feature. It only sees the ledgr indicator contract: `fn`, `series_fn`,
`requires_bars`, `stable_after`, and deterministic `params`.

## Inspect Supported Warmup Rules

``` r
library(ledgr)
data("ledgr_demo_bars", package = "ledgr")

as.data.frame(ledgr_ttr_warmup_rules()[, c("ttr_fn", "input", "formula")])
#>             ttr_fn input                                         formula
#> 1              RSI close                                           n + 1
#> 2              SMA close                                               n
#> 3              EMA close                                               n
#> 4              ATR   hlc                                           n + 1
#> 5             MACD close macd: nSlow; signal/histogram: nSlow + nSig - 1
#> 6              WMA close                                               n
#> 7              ROC close                                           n + 1
#> 8         momentum close                                           n + 1
#> 9              CCI   hlc                                               n
#> 10          BBands close                                               n
#> 11           aroon    hl                                               n
#> 12 DonchianChannel    hl                                               n
#> 13             MFI  hlcv                                           n + 1
#> 14             CMF  hlcv                                               n
#> 15         runMean close                                               n
#> 16           runSD close                                               n
#> 17          runVar close                                               n
#> 18          runMAD close                                               n
```

`ledgr_ttr_warmup_rules()` is the inspectable contract for automatic
warmup inference. A TTR function is listed only when ledgr can infer the
first stable row from explicit arguments alone. Unsupported or ambiguous
functions can still be used by supplying `requires_bars` manually.

## Simple Close-Based Indicators

``` r
rsi_14 <- ledgr_ind_ttr("RSI", input = "close", n = 14)
wma_10 <- ledgr_ind_ttr("WMA", input = "close", n = 10)

ledgr_feature_id(rsi_14)
#> [1] "ttr_rsi_14"
ledgr_feature_id(wma_10)
#> [1] "ttr_wma_10"
```

The generated ID is derived from the TTR function and explicit
arguments. ledgr does not rely on TTR defaults for warmup inference or
ID construction.

Built-in indicators follow the same convention:

``` r
builtins <- list(
  ledgr_ind_sma(20),
  ledgr_ind_ema(20),
  ledgr_ind_rsi(14),
  ledgr_ind_returns(5)
)

ledgr_feature_id(builtins)
#> [1] "sma_20"   "ema_20"   "rsi_14"   "return_5"
```

Those strings are the names you use inside a strategy:

``` r
ctx$feature("AAA", "sma_20")
ctx$feature("AAA", "return_5")
```

## Multi-Input And Multi-Output Indicators

``` r
atr_20 <- ledgr_ind_ttr("ATR", input = "hlc", output = "atr", n = 20)
bb_up <- ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20)
macd_signal <- ledgr_ind_ttr(
  "MACD",
  input = "close",
  output = "signal",
  nFast = 12,
  nSlow = 26,
  nSig = 9
)
aroon_osc <- ledgr_ind_ttr("aroon", input = "hl", output = "oscillator", n = 20)

ledgr_feature_id(list(rsi_14, atr_20, bb_up, macd_signal, aroon_osc))
#> [1] "ttr_rsi_14"              "ttr_atr_20_atr"          "ttr_bbands_20_up"       
#> [4] "ttr_macd_12_26_9_signal" "ttr_aroon_20_oscillator"
```

Some TTR indicators return several columns. For those indicators, choose
the column with `output`. The available outputs are checked at
construction time so errors happen before a backtest starts.

The ID format is deterministic:

``` text
ttr_<function>_<explicit args>_<output>
```

For example, the IDs above include `ttr_rsi_14`, `ttr_atr_20_atr`,
`ttr_bbands_20_up`, and `ttr_macd_12_26_9_signal`. Use
`ledgr_feature_id(ind)` or print the indicator object instead of
guessing the string.

## Feature Computation In A Backtest

``` r
bars <- subset(
  ledgr_demo_bars,
  instrument_id == "DEMO_01" &
    ts_utc >= as.POSIXct("2019-01-01", tz = "UTC") &
    ts_utc <= as.POSIXct("2019-06-30", tz = "UTC")
)

features <- list(
  ledgr_ind_ttr("RSI", input = "close", n = 14),
  ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20)
)
ledgr_feature_id(features)
#> [1] "ttr_rsi_14"       "ttr_bbands_20_up"

strategy <- function(ctx, params) {
  targets <- ctx$hold()
  rsi <- ctx$feature("DEMO_01", "ttr_rsi_14")
  bb_up <- ctx$feature("DEMO_01", "ttr_bbands_20_up")

  # This article uses one demo instrument, so only DEMO_01 is targeted.
  if (!is.na(rsi) && !is.na(bb_up) && rsi > 50 && ctx$close("DEMO_01") > bb_up) {
    targets["DEMO_01"] <- params$qty
  }
  targets
}

snapshot <- ledgr_snapshot_from_df(bars)
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  features = features,
  opening = ledgr_opening(cash = 10000)
)

bt <- exp |>
  ledgr_run(params = list(qty = 10), run_id = paste0("ttr-article-demo-", Sys.getpid()))

nrow(tibble::as_tibble(bt, what = "trades"))
#> [1] 1
close(bt)
ledgr_snapshot_close(snapshot)
```

TTR-backed indicators use `series_fn`, so ledgr computes the full
feature series once per instrument before the pulse loop and then
performs lookups during execution. The indicator fingerprint includes
TTR metadata, including the installed TTR version.

## Unsupported TTR Functions

``` r
ledgr_ind_ttr(
  "DEMA",
  input = "close",
  n = 10,
  requires_bars = 20
)$id
#> [1] "ttr_dema_10"
```

When a TTR function is not in the warmup rules table, provide
`requires_bars` explicitly. To measure it, run the TTR function on a
sufficiently long series and count the leading `NA` rows in the selected
output, then add one.

For non-TTR sources or more specialized logic, use `ledgr_indicator()`
directly with a `series_fn`. That is the adapter escape hatch: external
logic remains at the boundary, while the engine keeps the same
deterministic indicator contract.
