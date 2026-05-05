## ----setup, include=FALSE---------------------------------------------------------------
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
options(width = 90)
options(cli.unicode = FALSE)
default_output_hook <- knitr::knit_hooks$get("output")
knitr::knit_hooks$set(
  output = function(x, options) {
    default_output_hook(gsub("[ \t]+(?=\n)", "", x, perl = TRUE), options)
  }
)
demo_data_path <- if (file.exists("data/ledgr_demo_bars.rda")) {
  "data/ledgr_demo_bars.rda"
} else {
  file.path("..", "data", "ledgr_demo_bars.rda")
}
if (!exists("ledgr_demo_bars") && file.exists(demo_data_path)) {
  load(demo_data_path)
}


## ----library, message=FALSE-------------------------------------------------------------
library(ledgr)
library(dplyr)
data("ledgr_demo_bars", package = "ledgr")


## ----leakage-wrong, eval=FALSE----------------------------------------------------------
# leaky_signals <- ledgr_demo_bars |>
#   group_by(instrument_id) |>
#   arrange(ts_utc, .by_group = TRUE) |>
#   mutate(
#     tomorrow_close = lead(close),
#     buy_signal = tomorrow_close > close
#   )


## ----leakage-right----------------------------------------------------------------------
no_leak_bar_strategy <- function(ctx, params) {
  targets <- ctx$flat()

  for (id in ctx$universe) {
    if (ctx$close(id) > ctx$open(id)) {
      targets[id] <- 1
    }
  }

  targets
}


## ----flat-strategy----------------------------------------------------------------------
flat_strategy <- function(ctx, params) {
  ctx$flat()
}


## ----hold-example-----------------------------------------------------------------------
hold_unless_down <- function(ctx, params) {
  targets <- ctx$hold()

  for (id in ctx$universe) {
    if (ctx$close(id) < ctx$open(id)) {
      targets[id] <- 0
    }
  }

  targets
}


## ----buy-if-up--------------------------------------------------------------------------
buy_if_up <- function(ctx, params) {
  targets <- ctx$flat()

  for (id in ctx$universe) {
    if (ctx$close(id) > ctx$open(id)) {
      targets[id] <- 1
    }
  }

  targets
}


## ----buy-if-up-param--------------------------------------------------------------------
buy_if_up_qty <- function(ctx, params) {
  targets <- ctx$flat()

  for (id in ctx$universe) {
    if (ctx$close(id) > ctx$open(id)) {
      targets[id] <- params$qty
    }
  }

  targets
}


## ----data-------------------------------------------------------------------------------
bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    between(
      ts_utc,
      ledgr_utc("2019-01-01"),
      ledgr_utc("2019-06-30")
    )
  )

snapshot <- ledgr_snapshot_from_df(
  bars,
  snapshot_id = "strategy_chapter_snapshot"
)


## ----feature-ids------------------------------------------------------------------------
features <- list(ledgr_ind_returns(5))

ledgr_feature_id(features)


## ----pulse------------------------------------------------------------------------------
pulse <- ledgr_pulse_snapshot(
  snapshot,
  universe = c("DEMO_01", "DEMO_02"),
  ts_utc = ledgr_utc("2019-03-01"),
  features = features
)

pulse$ts_utc
pulse$universe
pulse$close("DEMO_01")
pulse$feature("DEMO_01", "return_5")
pulse$hold()


## ----pulse-wide-------------------------------------------------------------------------
ledgr_pulse_wide(pulse) |>
  glimpse()


## ----pulse-pipeline---------------------------------------------------------------------
signal <- signal_return(pulse, lookback = 5)
signal

selection <- select_top_n(signal, n = 1)
selection

weights <- weight_equal(selection)
weights

target <- target_rebalance(weights, pulse, equity_fraction = 0.1)
target


## ----floor-sizing-----------------------------------------------------------------------
raw_qty <- weights[["DEMO_01"]] * 0.1 * pulse$equity / pulse$close("DEMO_01")
c(pre_floor = raw_qty, target_qty = unclass(target)[["DEMO_01"]])


## ----close-pulse------------------------------------------------------------------------
close(pulse)


## ----helper-strategy--------------------------------------------------------------------
top_return_strategy <- function(ctx, params) {
  signal <- signal_return(ctx, lookback = params$lookback)
  selection <- suppressWarnings(
    select_top_n(signal, n = params$n),
    classes = "ledgr_empty_selection"
  )

  weights <- weight_equal(selection)
  target_rebalance(weights, ctx, equity_fraction = params$equity_fraction)
}


## ----experiment-------------------------------------------------------------------------
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = top_return_strategy,
  features = features,
  opening = ledgr_opening(cash = 10000)
)


## ----feature-map-setup------------------------------------------------------------------
mapped_features <- ledgr_feature_map(
  ret_5 = ledgr_ind_returns(5),
  sma_10 = ledgr_ind_sma(10)
)

ledgr_feature_id(mapped_features)


## ----feature-map-strategy---------------------------------------------------------------
mapped_return_strategy <- function(ctx, params) {
  targets <- ctx$flat()

  for (id in ctx$universe) {
    x <- ctx$features(id, mapped_features)

    if (
      passed_warmup(x) &&
        x[["ret_5"]] > params$min_return &&
        ctx$close(id) > x[["sma_10"]]
    ) {
      targets[id] <- params$qty
    }
  }

  targets
}


## ----feature-map-experiment-------------------------------------------------------------
mapped_exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = mapped_return_strategy,
  features = mapped_features,
  opening = ledgr_opening(cash = 10000)
)


## ----run-feature-map--------------------------------------------------------------------
bt_mapped <- mapped_exp |>
  ledgr_run(
    params = list(min_return = 0, qty = 5),
    run_id = "mapped_return"
  )

summary(bt_mapped)


## ----run-one----------------------------------------------------------------------------
bt_top_1 <- exp |>
  ledgr_run(
    params = list(lookback = 5, n = 1, equity_fraction = 0.1),
    run_id = "top_return_1"
  )

summary(bt_top_1)


## ----trades-----------------------------------------------------------------------------
ledgr_results(bt_top_1, what = "trades")


## ----run-two----------------------------------------------------------------------------
bt_top_2 <- exp |>
  ledgr_run(
    params = list(lookback = 5, n = 2, equity_fraction = 0.1),
    run_id = "top_return_2"
  )

ledgr_compare_runs(snapshot, run_ids = c("top_return_1", "top_return_2"))


## ----baseline---------------------------------------------------------------------------
flat_exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = flat_strategy,
  opening = ledgr_opening(cash = 10000)
)

bt_flat <- flat_exp |>
  ledgr_run(params = list(), run_id = "flat_baseline")

ledgr_compare_runs(snapshot, run_ids = c("top_return_1", "top_return_2", "flat_baseline"))


## ----extract----------------------------------------------------------------------------
ledgr_extract_strategy(snapshot, "top_return_1", trust = FALSE)


## ----cleanup----------------------------------------------------------------------------
close(bt_top_1)
close(bt_top_2)
close(bt_flat)
close(bt_mapped)
ledgr_snapshot_close(snapshot)

