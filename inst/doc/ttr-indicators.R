## ----setup, include=FALSE---------------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)
options(width = 90)
demo_data_path <- if (file.exists("data/ledgr_demo_bars.rda")) {
  "data/ledgr_demo_bars.rda"
} else {
  file.path("..", "data", "ledgr_demo_bars.rda")
}
if (!exists("ledgr_demo_bars") && file.exists(demo_data_path)) {
  load(demo_data_path)
}

## ----rules------------------------------------------------------------------------------
library(ledgr)
library(dplyr)
data("ledgr_demo_bars", package = "ledgr")

as.data.frame(ledgr_ttr_warmup_rules()[, c("ttr_fn", "input", "formula")])

## ----simple, eval=requireNamespace("TTR", quietly = TRUE)-------------------------------
rsi_14 <- ledgr_ind_ttr("RSI", input = "close", n = 14)
wma_10 <- ledgr_ind_ttr("WMA", input = "close", n = 10)
mom_10 <- ledgr_ind_ttr("momentum", input = "close", n = 10)

ledgr_feature_id(rsi_14)
ledgr_feature_id(wma_10)
ledgr_feature_id(mom_10)

## ----builtin-ids------------------------------------------------------------------------
builtins <- list(
  ledgr_ind_sma(20),
  ledgr_ind_ema(20),
  ledgr_ind_rsi(14),
  ledgr_ind_returns(5)
)

ledgr_feature_id(builtins)

## ----multi, eval=requireNamespace("TTR", quietly = TRUE)--------------------------------
atr_20 <- ledgr_ind_ttr("ATR", input = "hlc", output = "atr", n = 20)
bb_up <- ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20)
macd_line <- ledgr_ind_ttr(
  "MACD",
  input = "close",
  output = "macd",
  nFast = 12,
  nSlow = 26,
  nSig = 9,
  percent = FALSE
)
macd_signal <- ledgr_ind_ttr(
  "MACD",
  input = "close",
  output = "signal",
  nFast = 12,
  nSlow = 26,
  nSig = 9
)
aroon_osc <- ledgr_ind_ttr("aroon", input = "hl", output = "oscillator", n = 20)

ledgr_feature_id(list(rsi_14, atr_20, bb_up, macd_line, macd_signal, aroon_osc))

## ----warmup-values, eval=requireNamespace("TTR", quietly = TRUE)------------------------
c(
  rsi = rsi_14$requires_bars,
  momentum = mom_10$requires_bars,
  bbands = bb_up$requires_bars,
  macd = macd_line$requires_bars,
  macd_signal = macd_signal$requires_bars
)

## ----backtest, eval=requireNamespace("TTR", quietly = TRUE)-----------------------------
bars <- ledgr_demo_bars |>
  filter(
    instrument_id == "DEMO_01",
    between(ts_utc, ledgr_utc("2019-01-01"), ledgr_utc("2019-06-30"))
  )

features <- list(
  ledgr_ind_ttr("RSI", input = "close", n = 14),
  ledgr_ind_ttr("momentum", input = "close", n = 10),
  ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20),
  ledgr_ind_ttr(
    "MACD",
    input = "close",
    output = "macd",
    nFast = 12,
    nSlow = 26,
    nSig = 9,
    percent = FALSE
  )
)
ledgr_feature_id(features)

strategy <- function(ctx, params) {
  targets <- ctx$hold()
  rsi <- ctx$feature("DEMO_01", "ttr_rsi_14")
  mom <- ctx$feature("DEMO_01", "ttr_momentum_10")
  bb_up <- ctx$feature("DEMO_01", "ttr_bbands_20_up")
  macd <- ctx$feature("DEMO_01", "ttr_macd_12_26_9_false_macd")

  # This article uses one demo instrument, so only DEMO_01 is targeted.
  if (
    !is.na(rsi) &&
      !is.na(mom) &&
      !is.na(bb_up) &&
      !is.na(macd) &&
      rsi > 50 &&
      mom > 0 &&
      macd > 0 &&
      ctx$close("DEMO_01") > bb_up
  ) {
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
close(bt)
ledgr_snapshot_close(snapshot)

## ----unsupported, eval=requireNamespace("TTR", quietly = TRUE)--------------------------
ledgr_ind_ttr(
  "DEMA",
  input = "close",
  n = 10,
  requires_bars = 20
)$id

