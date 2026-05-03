Indicators And Feature IDs
================

``` r
library(ledgr)
library(dplyr)
data("ledgr_demo_bars", package = "ledgr")
```

Indicators are how ledgr turns sealed market data into pulse-time
features. This article teaches built-in ledgr indicators and TTR-backed
indicators under one mental model.

The important contract is the same for built-in indicators and
TTR-backed indicators:

1.  Define indicator objects before the run.
2.  Register those objects with the experiment.
3.  Ask ledgr for their exact feature IDs.
4.  Read those IDs from `ctx$feature()` inside the strategy.
5.  Treat warmup `NA` as "known feature, not usable yet."

The strategy never receives the whole feature table. At each pulse it
receives only the current feature values that could have been known at
that time.

## Built-In Indicators

Built-in indicators cover common ledgr-native features. They are
ordinary indicator objects with deterministic IDs and warmup
requirements.

``` r
builtins <- list(
  sma_20 = ledgr_ind_sma(20),
  ema_20 = ledgr_ind_ema(20),
  rsi_14 = ledgr_ind_rsi(14),
  ret_5 = ledgr_ind_returns(5)
)

ledgr_feature_id(builtins)
#> [1] "sma_20"   "ema_20"   "rsi_14"   "return_5"
```

The names in `builtins` are for your R code. The strings returned by
`ledgr_feature_id()` are ledgr's feature IDs. Strategies use the
returned feature IDs, not guessed strings.

For example:

``` r
ctx$feature("DEMO_01", "sma_20")
ctx$feature("DEMO_01", "return_5")
```

## TTR-Backed Indicators

`ledgr_ind_ttr()` is the adapter for supported indicators from the
suggested `TTR` package. TTR stays outside the core engine:

``` text
TTR -> ledgr_ind_ttr() -> ledgr_indicator -> deterministic pulse engine
```

The engine sees a normal `ledgr_indicator`. That means TTR-backed
indicators follow the same feature-ID and warmup rules as built-in
indicators.

``` r
ttr_features <- list(
  ttr_rsi = ledgr_ind_ttr("RSI", input = "close", n = 14),
  bb_up = ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20),
  macd = ledgr_ind_ttr(
    "MACD",
    input = "close",
    output = "macd",
    nFast = 12,
    nSlow = 26,
    nSig = 9,
    percent = FALSE
  ),
  macd_signal = ledgr_ind_ttr(
    "MACD",
    input = "close",
    output = "signal",
    nFast = 12,
    nSlow = 26,
    nSig = 9,
    percent = FALSE
  )
)

ledgr_feature_id(ttr_features)
#> [1] "ttr_rsi_14"                    "ttr_bbands_20_up"             
#> [3] "ttr_macd_12_26_9_false_macd"   "ttr_macd_12_26_9_false_signal"
```

The examples produce IDs such as `ttr_bbands_20_up`,
`ttr_macd_12_26_9_false_macd`, and `ttr_macd_12_26_9_false_signal`.

Some TTR functions return several columns. For those functions, choose
one column with `output` before asking ledgr for the feature ID.
`BBands` exposes `dn`, `mavg`, `up`, and `pctB`. `MACD` exposes `macd`
and `signal`; ledgr also supports a derived `histogram`.

The two MACD examples above use matching explicit arguments. Explicit
arguments become part of the feature ID, so combine MACD outputs in one
strategy only when their argument sets match the computation you intend.
If one MACD output uses `percent = FALSE`, the paired `signal` output
should usually set `percent = FALSE` too.

## Warmup Is General

Every ledgr indicator declares `requires_bars` and `stable_after`.
`requires_bars` is the first row where the indicator may produce a
non-`NA` value. `stable_after` is the first row ledgr treats as stable.

Built-in and supported TTR-backed indicators use the same rule: before
warmup has passed, the feature value is `NA`.

``` r
data.frame(
  alias = names(builtins),
  feature_id = ledgr_feature_id(builtins),
  requires_bars = vapply(builtins, function(x) x$requires_bars, integer(1)),
  stable_after = vapply(builtins, function(x) x$stable_after, integer(1)),
  row.names = NULL
)
#>    alias feature_id requires_bars stable_after
#> 1 sma_20     sma_20            20           20
#> 2 ema_20     ema_20            21           21
#> 3 rsi_14     rsi_14            15           15
#> 4  ret_5   return_5             6            6
```

Warmup `NA` is expected. Unknown feature IDs are different:
`ctx$feature()` fails loudly when the ID was not registered with the
experiment.

TTR warmup inference is inspectable:

``` r
ledgr_ttr_warmup_rules() |>
  select(ttr_fn, input, formula)
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

For MACD, ledgr verifies the supported warmup rules against direct TTR
output. With current TTR behavior, the `macd` output is first valid at
`nSlow`, while `signal` and the derived ledgr `histogram` output are
first valid at `nSlow + nSig - 1`. The same rule is verified for both
`percent = TRUE` and `percent = FALSE`.

## Use Features In A Strategy

Keep feature definitions and feature IDs together. A named list gives
readable names to your R code, while `ledgr_feature_id()` gives the
exact IDs used by the pulse context.

``` r
features <- list(
  ret_5 = ledgr_ind_returns(5),
  rsi_14 = ledgr_ind_ttr("RSI", input = "close", n = 14),
  bb_up = ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20)
)

feature_ids <- setNames(ledgr_feature_id(features), names(features))
feature_ids
#>              ret_5             rsi_14              bb_up 
#>         "return_5"       "ttr_rsi_14" "ttr_bbands_20_up"
```

Inside the strategy, read the current values for each instrument and
guard the decision until all requested features have passed warmup.

``` r
read_features <- function(ctx, id, feature_ids) {
  vapply(
    feature_ids,
    function(feature_id) ctx$feature(id, feature_id),
    numeric(1)
  )
}

strategy <- function(ctx, params) {
  targets <- ctx$flat()

  for (id in ctx$universe) {
    x <- read_features(ctx, id, feature_ids)

    if (
      all(!is.na(x)) &&
        x[["ret_5"]] > 0 &&
        x[["rsi_14"]] > 50 &&
        ctx$close(id) > x[["bb_up"]]
    ) {
      targets[id] <- params$qty
    }
  }

  targets
}
```

That pattern keeps the signal logic readable:

- `feature_ids` is where feature identity lives.
- `read_features()` is only a local convenience for the current API.
- `all(!is.na(x))` is the warmup gate.
- The condition after the warmup gate is the trading idea.

## Run The Example

Use two demo instruments so the strategy body has to work over
`ctx$universe`, not one hardcoded instrument.

``` r
bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    between(
      ts_utc,
      article_utc("2019-01-01"),
      article_utc("2019-06-30")
    )
  )

snapshot <- ledgr_snapshot_from_df(
  bars,
  snapshot_id = paste0("indicators-vignette-", Sys.getpid())
)

exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  features = features,
  opening = ledgr_opening(cash = 10000)
)

run_id <- paste0("indicators-demo-", Sys.getpid())

bt <- exp |>
  ledgr_run(params = list(qty = 10), run_id = run_id)

as.data.frame(ledgr_results(bt, what = "fills"))
#>    event_seq     ts_utc instrument_id side qty     price fee realized_pnl action
#> 1          1 2019-01-31       DEMO_01  BUY  10  94.50105   0    0.0000000   OPEN
#> 2          2 2019-02-04       DEMO_01 SELL  10  95.48066   0    9.7961366  CLOSE
#> 3          3 2019-02-27       DEMO_01  BUY  10 100.04780   0    0.0000000   OPEN
#> 4          4 2019-03-05       DEMO_01 SELL  10 105.85320   0   58.0539967  CLOSE
#> 5          5 2019-04-04       DEMO_02  BUY  10  71.97314   0    0.0000000   OPEN
#> 6          6 2019-04-08       DEMO_02 SELL  10  71.52468   0   -4.4845909  CLOSE
#> 7          7 2019-04-18       DEMO_02  BUY  10  74.75922   0    0.0000000   OPEN
#> 8          8 2019-04-19       DEMO_02 SELL  10  75.80787   0   10.4864760  CLOSE
#> 9          9 2019-04-23       DEMO_02  BUY  10  76.37167   0    0.0000000   OPEN
#> 10        10 2019-04-25       DEMO_02 SELL  10  76.43829   0    0.6662427  CLOSE
#> 11        11 2019-05-13       DEMO_02  BUY  10  80.17480   0    0.0000000   OPEN
#> 12        12 2019-05-14       DEMO_02 SELL  10  79.94966   0   -2.2513944  CLOSE
#> 13        13 2019-05-17       DEMO_02  BUY  10  81.49457   0    0.0000000   OPEN
#> 14        14 2019-05-20       DEMO_02 SELL  10  81.14211   0   -3.5245677  CLOSE

close(bt)
ledgr_snapshot_close(snapshot)
```

The experiment registers the indicator objects. The strategy reads
feature values by ID at each pulse. ledgr handles feature computation
before execution and then gives the strategy only the pulse-time values.

## Unsupported Or Custom Indicators

When a TTR function is not in the warmup rules table, provide
`requires_bars` explicitly:

``` r
ledgr_ind_ttr(
  "DEMA",
  input = "close",
  n = 10,
  requires_bars = 20
)$id
#> [1] "ttr_dema_10"
```

For non-TTR sources or more specialized logic, use `ledgr_indicator()`
directly with a `series_fn`. That is the adapter escape hatch: external
logic remains at the boundary, while the engine keeps the same
deterministic indicator contract.

## What's Next?

For strategy authoring, read
`vignette("strategy-development", package = "ledgr")`. For accounting
and summary metrics, read
`vignette("metrics-and-accounting", package = "ledgr")`. For
TTR-specific output names and supported warmup inference, see
`?ledgr_ind_ttr` and `?ledgr_ttr_warmup_rules`.
