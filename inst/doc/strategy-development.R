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

## ----library----------------------------------------------------------------------------
library(ledgr)
library(dplyr)
data("ledgr_demo_bars", package = "ledgr")

## ----ctx-strategy-----------------------------------------------------------------------
flat_strategy <- function(ctx, params) {
  ctx$flat()
}

## ----params-strategy--------------------------------------------------------------------
threshold_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  for (id in ctx$universe) {
    if (ctx$close(id) > params$threshold[[id]]) {
      targets[id] <- params$qty
    }
  }
  targets
}

## ----target-example---------------------------------------------------------------------
buy_one_if_up <- function(ctx, params) {
  targets <- ctx$flat()
  if (ctx$close("AAA") > ctx$open("AAA")) {
    targets["AAA"] <- 1
  }
  targets
}

## ----sizing-example---------------------------------------------------------------------
top_two_equal_quantity <- function(ctx, params) {
  targets <- ctx$flat()
  scores <- numeric()

  for (id in ctx$universe) {
    score <- ctx$feature(id, "return_1")
    if (!is.na(score)) {
      scores[id] <- score
    }
  }

  if (length(scores) == 0) return(targets)

  selected <- names(sort(scores, decreasing = TRUE))[seq_len(min(2, length(scores)))]
  targets[selected] <- params$qty_per_instrument
  targets
}

## ----builtins---------------------------------------------------------------------------
sma_3 <- ledgr_ind_sma(3)
ret_1 <- ledgr_ind_returns(1)
ledgr_feature_id(list(sma_3, ret_1))

## ----ttr--------------------------------------------------------------------------------
rsi_3 <- ledgr_ind_ttr("RSI", input = "close", n = 3)
bb_up <- ledgr_ind_ttr("BBands", input = "close", output = "up", n = 3)
ledgr_feature_id(list(rsi_3, bb_up))

## ----indicator-strategy-----------------------------------------------------------------
rsi_strategy <- function(ctx, params) {
  targets <- ctx$hold()
  rsi <- ctx$feature("AAA", "ttr_rsi_3")
  if (is.na(rsi)) return(targets)

  if (rsi < params$buy_below) {
    targets["AAA"] <- params$qty
  } else if (rsi > params$sell_above) {
    targets["AAA"] <- 0
  }
  targets
}

## ----warmup-flat------------------------------------------------------------------------
sma_breakout <- function(ctx, params) {
  targets <- ctx$flat()
  sma <- ctx$feature("AAA", "sma_3")
  if (is.na(sma)) return(targets)

  if (ctx$close("AAA") > sma) {
    targets["AAA"] <- params$qty
  }
  targets
}

## ----data-------------------------------------------------------------------------------
bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    between(ts_utc, ledgr_utc("2019-01-01"), ledgr_utc("2019-04-30"))
  )

snapshot <- ledgr_snapshot_from_df(
  bars,
  snapshot_id = "strategy_demo_snapshot"
)

## ----pulse------------------------------------------------------------------------------
pulse <- ledgr_pulse_snapshot(
  snapshot,
  universe = c("DEMO_01", "DEMO_02"),
  ts_utc = "2019-03-01T00:00:00Z",
  features = list(sma_3, rsi_3)
)

pulse$close("DEMO_01")
pulse$feature("DEMO_01", "sma_3")
pulse$hold()
threshold_strategy(
  pulse,
  list(threshold = c(DEMO_01 = 55, DEMO_02 = 75), qty = 1)
)
close(pulse)

## ----compare-params---------------------------------------------------------------------
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = threshold_strategy,
  opening = ledgr_opening(cash = 10000)
)

bt_qty_1 <- exp |>
  ledgr_run(
    params = list(threshold = c(DEMO_01 = 55, DEMO_02 = 75), qty = 1),
    run_id = "threshold_qty_1"
  )

bt_qty_3 <- exp |>
  ledgr_run(
    params = list(threshold = c(DEMO_01 = 55, DEMO_02 = 75), qty = 3),
    run_id = "threshold_qty_3"
  )

ledgr_compare_runs(snapshot, run_ids = c("threshold_qty_1", "threshold_qty_3"))

## ----compare-strategies-----------------------------------------------------------------
flat_exp <- ledgr_experiment(
  snapshot,
  strategy = flat_strategy,
  opening = ledgr_opening(cash = 10000)
)

bt_flat <- flat_exp |>
  ledgr_run(params = list(), run_id = "flat")

ledgr_compare_runs(snapshot, run_ids = c("threshold_qty_1", "flat"))

## ----extract----------------------------------------------------------------------------
extracted <- ledgr_extract_strategy(snapshot, "threshold_qty_1", trust = FALSE)
extracted

## ----cleanup----------------------------------------------------------------------------
close(bt_qty_1)
close(bt_qty_3)
close(bt_flat)
close(snapshot)

