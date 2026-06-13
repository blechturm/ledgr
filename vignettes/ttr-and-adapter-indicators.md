# TTR And Adapter Indicators


<style>
.ledgr-diagram {
  margin: 1.25rem auto 1.5rem auto;
  text-align: center;
}
.ledgr-diagram .mermaid {
  display: inline-block;
  max-width: 760px;
  width: 100%;
}
.ledgr-diagram .node text,
.ledgr-diagram .edgeLabel {
  font-size: 18px !important;
}
</style>

This article covers adapter-backed indicator declarations, especially
TTR indicators and multi-output bundles. The conceptual feature
lifecycle lives in `vignette("indicators", package = "ledgr")`.

## Prerequisites

``` r
library(ledgr)
library(dplyr)
data("ledgr_demo_bars", package = "ledgr")
```

``` r
bars <- ledgr_demo_bars |>
  dplyr::filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    dplyr::between(ts_utc, ledgr_utc("2019-01-01"), ledgr_utc("2019-06-30"))
  )
```

## TTR-Backed Indicators

`ledgr_ind_ttr()` is the adapter for supported indicators from the
suggested `TTR` package. TTR stays outside the core engine:

<div class="ledgr-diagram ledgr-ttr-adapter">

``` mermaid

flowchart LR
  ttr["TTR"]
  adapter["ledgr_ind_ttr()"]
  indicator["ledgr_indicator"]
  engine["deterministic<br/>pulse engine"]

  ttr --> adapter --> indicator --> engine
```

</div>

The engine sees a normal `ledgr_indicator`. That means TTR-backed
indicators follow the same feature-ID, warmup, and pulse-view rules as
built-in indicators. The TTR-backed examples below are skipped when
`TTR` is not installed. In your own project, install TTR with
`install.packages("TTR")` before creating TTR-backed indicators.

### Single-Output TTR Indicators

``` r
ttr_features <- ledgr_feature_map(
  ret_5 = ledgr_ind_returns(5),
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

ledgr_feature_contracts(ttr_features)
#> # A tibble: 5 × 5
#>   alias       feature_id                    source requires_bars stable_after
#>   <chr>       <chr>                         <chr>          <int>        <int>
#> 1 ret_5       return_5                      ledgr              6            6
#> 2 ttr_rsi     ttr_rsi_14                    TTR               15           15
#> 3 bb_up       ttr_bbands_20_up              TTR               20           20
#> 4 macd        ttr_macd_12_26_9_false_macd   TTR               34           34
#> 5 macd_signal ttr_macd_12_26_9_false_signal TTR               34           34
ledgr_feature_id(ttr_features)
#>                           ret_5                         ttr_rsi 
#>                      "return_5"                    "ttr_rsi_14" 
#>                           bb_up                            macd 
#>              "ttr_bbands_20_up"   "ttr_macd_12_26_9_false_macd" 
#>                     macd_signal 
#> "ttr_macd_12_26_9_false_signal"
```

This mixed feature map combines a built-in return feature with
TTR-backed RSI, BBands, and MACD features. The MACD ID embeds the
explicit arguments because they are part of the calculation identity.

### Native RSI vs TTR RSI

ledgr also includes a native RSI helper. It does not require TTR and
follows the same ID and warmup contract as other built-in indicators:

``` r
native_rsi_features <- ledgr_feature_map(
  rsi_14 = ledgr_ind_rsi(14)
)

ledgr_feature_contracts(native_rsi_features)
#> # A tibble: 1 × 5
#>   alias  feature_id source requires_bars stable_after
#>   <chr>  <chr>      <chr>          <int>        <int>
#> 1 rsi_14 rsi_14     ledgr             15           15
ledgr_feature_id(native_rsi_features)
#>   rsi_14 
#> "rsi_14"
```

The native RSI feature ID is `rsi_14`. The TTR-backed RSI feature ID
above is `ttr_rsi_14`. Those are different feature definitions and
should not be treated as interchangeable without checking that their
calculation and warmup behavior match your research intent.

RSI is a common mean-reversion input. One compact rule is: buy when RSI
is below 30, then return to flat when the condition is no longer true.
The experiment registers the RSI indicator before the run; the strategy
only reads the pulse-time value. The example below uses native RSI so it
works without TTR. Use TTR-backed RSI when you deliberately want adapter
behavior.

``` r
rsi_features <- native_rsi_features

rsi_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  for (id in ctx$universe) {
    x <- ctx$features(id, rsi_features)
    if (ledgr_passed_warmup(x) && x[["rsi_14"]] < params$oversold) {
      targets[id] <- params$qty
    }
  }
  targets
}

rsi_snapshot <- ledgr_snapshot_from_df(
  bars,
  snapshot_id = paste0("rsi-vignette-", Sys.getpid())
)

rsi_exp <- ledgr_experiment(
  snapshot = rsi_snapshot,
  strategy = rsi_strategy,
  features = rsi_features,
  opening = ledgr_opening(cash = 10000),
  cost_model = ledgr_cost_zero()
)

rsi_bt <- ledgr_run(
  rsi_exp,
  params = list(oversold = 30, qty = 10),
  run_id = paste0("rsi-demo-", Sys.getpid())
)

ledgr_results(rsi_bt, what = "fills")
#> # A tibble: 16 × 9
#>    event_seq ts_utc     instrument_id side    qty price   fee realized_pnl action
#>        <int> <date>     <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr> 
#>  1         1 2019-01-22 DEMO_01       BUY      10  87.2     0         0    OPEN  
#>  2         2 2019-01-23 DEMO_02       BUY      10  69.1     0         0    OPEN  
#>  3         3 2019-01-24 DEMO_01       SELL     10  89.0     0        17.9  CLOSE 
#>  4         4 2019-01-25 DEMO_02       SELL     10  69.9     0         7.59 CLOSE 
#>  5         5 2019-02-07 DEMO_02       BUY      10  67.9     0         0    OPEN  
#>  6         6 2019-02-08 DEMO_02       SELL     10  67.2     0        -6.26 CLOSE 
#>  7         7 2019-02-14 DEMO_02       BUY      10  66.5     0         0    OPEN  
#>  8         8 2019-02-18 DEMO_02       SELL     10  67.2     0         7.00 CLOSE 
#>  9         9 2019-05-01 DEMO_01       BUY      10  98.7     0         0    OPEN  
#> 10        10 2019-05-03 DEMO_01       SELL     10  99.9     0        12.6  CLOSE 
#> 11        11 2019-05-30 DEMO_01       BUY      10  94.2     0         0    OPEN  
#> 12        12 2019-06-12 DEMO_02       BUY      10  75.3     0         0    OPEN  
#> 13        13 2019-06-13 DEMO_02       SELL     10  76.5     0        12.1  CLOSE 
#> 14        14 2019-06-18 DEMO_01       SELL     10  87.7     0       -65.1  CLOSE 
#> 15        15 2019-06-19 DEMO_01       BUY      10  87.3     0         0    OPEN  
#> 16        16 2019-06-28 DEMO_01       SELL     10  87.7     0         4.23 CLOSE
close(rsi_bt)
ledgr_snapshot_close(rsi_snapshot)
```

Some TTR functions return several columns. For those functions, choose
one column with `output` when you need exactly one output, or use
`ledgr_ind_ttr_outputs()` to declare several outputs from one shared TTR
configuration. `BBands` exposes `dn`, `mavg`, `up`, and `pctB`. `MACD`
exposes `macd` and `signal`; ledgr also supports a derived `histogram`.

### Multi-Output TTR Indicators

``` r
ledgr_feature_contracts(ledgr_feature_map(
  bb_dn = ledgr_ind_ttr("BBands", input = "close", output = "dn", n = 20),
  bb_mavg = ledgr_ind_ttr("BBands", input = "close", output = "mavg", n = 20),
  bb_up = ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20),
  bb_pctB = ledgr_ind_ttr("BBands", input = "close", output = "pctB", n = 20)
))
#> # A tibble: 4 × 5
#>   alias   feature_id         source requires_bars stable_after
#>   <chr>   <chr>              <chr>          <int>        <int>
#> 1 bb_dn   ttr_bbands_20_dn   TTR               20           20
#> 2 bb_mavg ttr_bbands_20_mavg TTR               20           20
#> 3 bb_up   ttr_bbands_20_up   TTR               20           20
#> 4 bb_pctB ttr_bbands_20_pctb TTR               20           20
```

### Bundle Naming Rules

For multi-output authoring, prefer the bundle helper. By default, bundle
feature IDs use a normalized prefix derived from the TTR function name.
For `BBands`, that produces `bbands_dn`, `bbands_mavg`, `bbands_up`, and
`bbands_pctb`. The helper returns a `ledgr_indicator_bundle`, but the
experiment sees ordinary single-output indicators after feature
declaration is materialized.

Those bundle IDs are shorter than the hand-written single-output TTR IDs
such as `ttr_bbands_20_up`. That asymmetry is intentional: bundle
defaults optimize for readable output names. Use
`naming = c(up = "ttr_bbands_20_up")` or hand-written
`ledgr_ind_ttr(output = ...)` calls when you need exact legacy IDs.

``` r
bbands_bundle <- ledgr_ind_ttr_outputs("BBands", input = "close", n = 20)
ledgr_feature_id(bbands_bundle)
#> [1] "bbands_dn"   "bbands_mavg" "bbands_up"   "bbands_pctb"
ledgr_feature_contracts(bbands_bundle)
#> # A tibble: 4 × 5
#>   alias feature_id  source requires_bars stable_after
#>   <chr> <chr>       <chr>          <int>        <int>
#> 1 <NA>  bbands_dn   TTR               20           20
#> 2 <NA>  bbands_mavg TTR               20           20
#> 3 <NA>  bbands_up   TTR               20           20
#> 4 <NA>  bbands_pctb TTR               20           20
```

When a bundle is placed inside `ledgr_feature_map()`, its entries expand
using their feature IDs as aliases. A single alias on the bundle
argument is ignored because one alias cannot name several outputs.
Control the generated feature IDs with the bundle’s `prefix` argument
instead.

Use `outputs` as a filter. The derived or explicit prefix still applies
to selected outputs, so a subset remains collision-resistant:

``` r
bbands_subset <- ledgr_ind_ttr_outputs(
  "BBands",
  input = "close",
  outputs = c("dn", "up"),
  prefix = "bb",
  n = 20
)
ledgr_feature_id(bbands_subset)
#> [1] "bb_dn" "bb_up"
```

`naming` renames selected outputs; it is not itself an output filter.
When renaming only part of a bundle, make the filter explicit:

``` r
bbands_named_subset <- ledgr_ind_ttr_outputs(
  "BBands",
  input = "close",
  outputs = c("dn", "up"),
  naming = c(dn = "lower_band", up = "upper_band"),
  n = 20
)
ledgr_feature_id(bbands_named_subset)
#> [1] "lower_band" "upper_band"
```

Set `prefix = NULL` only when you explicitly want raw normalized output
names such as `dn`, `up`, or `pctb`. Raw names are short and can collide
when one experiment combines several bundles or parameterizations.

### MACD Argument Consistency

The two MACD entries in `ttr_features` both set `percent = FALSE`.
Explicit arguments become part of the feature ID, so combine MACD
outputs in one strategy only when their argument sets match the
computation you intend. If one MACD output uses `percent = FALSE`, the
paired `signal` output should usually set `percent = FALSE` too.

### TTR Warmup Rules

TTR warmup inference is inspectable:

``` r
ledgr_ind_ttr_warmup_rules() |>
  select(ttr_fn, input, formula)
#> # A tibble: 18 × 3
#>    ttr_fn          input formula         
#>    <chr>           <chr> <chr>           
#>  1 RSI             close n + 1           
#>  2 SMA             close n               
#>  3 EMA             close n               
#>  4 ATR             hlc   n + 1           
#>  5 MACD            close nSlow + nSig - 1
#>  6 WMA             close n               
#>  7 ROC             close n + 1           
#>  8 momentum        close n + 1           
#>  9 CCI             hlc   n               
#> 10 BBands          close n               
#> 11 aroon           hl    n               
#> 12 DonchianChannel hl    n               
#> 13 MFI             hlcv  n + 1           
#> 14 CMF             hlcv  n               
#> 15 runMean         close n               
#> 16 runSD           close n               
#> 17 runVar          close n               
#> 18 runMAD          close n
```

For MACD, ledgr verifies the supported warmup rules against direct TTR
output. TTR computes the signal EMA internally even when you select only
the `macd` column. In a pulse-by-pulse backtest, all supported MACD
outputs are therefore first callable at `nSlow + nSig - 1`. The same
rule is verified for `macd`, `signal`, the derived ledgr `histogram`,
and both `percent = TRUE` and `percent = FALSE`.

To debug a TTR-backed feature at one decision time, use an active
snapshot handle, choose a timestamp late enough for the indicator
warmup, and pass the same TTR feature map to `ledgr_pulse_snapshot()`. A
completed backtest proves the run succeeded, but it does not replace the
snapshot handle needed for interactive pulse inspection.

``` r
ttr_pulse <- ledgr_pulse_snapshot(
  snapshot,
  universe = c("DEMO_01", "DEMO_02"),
  ts_utc = ledgr_utc("2019-06-03"),
  features = ttr_features
)

ledgr_pulse_features(ttr_pulse, ttr_features)
close(ttr_pulse)
```

## TTR Warmup Verification

Adapter-backed indicators still use the same ledgr feature contract as
built-in indicators: each declaration has a `stable_after` value, and
warmup before that point is ordinary `NA`. TTR-specific work is deciding
the right lookback rule for the wrapped function.

``` r
ledgr_ind_ttr_warmup_rules()
#> # A tibble: 18 × 5
#>    ttr_fn          input formula          required_args id_args  
#>    <chr>           <chr> <chr>            <list>        <list>   
#>  1 RSI             close n + 1            <chr [1]>     <chr [1]>
#>  2 SMA             close n                <chr [1]>     <chr [1]>
#>  3 EMA             close n                <chr [1]>     <chr [1]>
#>  4 ATR             hlc   n + 1            <chr [1]>     <chr [1]>
#>  5 MACD            close nSlow + nSig - 1 <chr [3]>     <chr [3]>
#>  6 WMA             close n                <chr [1]>     <chr [1]>
#>  7 ROC             close n + 1            <chr [1]>     <chr [1]>
#>  8 momentum        close n + 1            <chr [1]>     <chr [1]>
#>  9 CCI             hlc   n                <chr [1]>     <chr [1]>
#> 10 BBands          close n                <chr [1]>     <chr [1]>
#> 11 aroon           hl    n                <chr [1]>     <chr [1]>
#> 12 DonchianChannel hl    n                <chr [1]>     <chr [1]>
#> 13 MFI             hlcv  n + 1            <chr [1]>     <chr [1]>
#> 14 CMF             hlcv  n                <chr [1]>     <chr [1]>
#> 15 runMean         close n                <chr [1]>     <chr [1]>
#> 16 runSD           close n                <chr [1]>     <chr [1]>
#> 17 runVar          close n                <chr [1]>     <chr [1]>
#> 18 runMAD          close n                <chr [1]>     <chr [1]>
```

When a TTR function is covered by the rule table, ledgr derives the
warmup from its parameters. When a function is not covered, provide
`requires_bars` explicitly instead of guessing from the output after the
fact. The general warmup and zero-trade diagnostic checklist lives in
`vignette("indicators", package = "ledgr")`.

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

## Where Next

- `vignette("indicators", package = "ledgr")` covers the feature
  lifecycle and strategy-time access patterns.
- `vignette("custom-indicators", package = "ledgr")` covers custom
  package indicators when an adapter is not enough.
- `vignette("strategy-authoring-tools", package = "ledgr")` shows how
  adapter-backed features enter feature maps and strategy helpers.
