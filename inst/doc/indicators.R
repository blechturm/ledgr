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


## ----packages, message=FALSE------------------------------------------------------------
library(ledgr)
library(dplyr)
data("ledgr_demo_bars", package = "ledgr")


## ----built-in-feature-map---------------------------------------------------------------
features <- ledgr_feature_map(
  ret_5 = ledgr_ind_returns(5),
  sma_10 = ledgr_ind_sma(10)
)


## ----pulse-setup------------------------------------------------------------------------
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
  snapshot_id = paste0("indicators-vignette-", Sys.getpid())
)

pulse <- ledgr_pulse_snapshot(
  snapshot,
  universe = c("DEMO_01", "DEMO_02"),
  ts_utc = ledgr_utc("2019-03-01"),
  features = features
)


## ----pulse-long-------------------------------------------------------------------------
ledgr_pulse_features(pulse, features)


## ----pulse-wide-------------------------------------------------------------------------
ledgr_pulse_wide(pulse, features)


## ----scalar-access----------------------------------------------------------------------
ids <- ledgr_feature_id(features)
pulse$feature("DEMO_01", ids[["ret_5"]])


## ----mapped-access----------------------------------------------------------------------
x <- pulse$features("DEMO_01", features)
x
passed_warmup(x)


## ----strategy-definition----------------------------------------------------------------
strategy <- function(ctx, params) {
  targets <- ctx$flat()

  for (id in ctx$universe) {
    x <- ctx$features(id, features)

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


## ----run-example------------------------------------------------------------------------
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  features = features,
  opening = ledgr_opening(cash = 10000)
)

run_id <- paste0("indicators-demo-", Sys.getpid())

bt <- exp |>
  ledgr_run(params = list(min_return = 0, qty = 10), run_id = run_id)

ledgr_results(bt, what = "fills")

close(pulse)
close(bt)
ledgr_snapshot_close(snapshot)


## ----feature-contracts------------------------------------------------------------------
ledgr_feature_contracts(features)


## ----plain-list-contracts---------------------------------------------------------------
plain_features <- list(ledgr_ind_returns(5), ledgr_ind_sma(10))
ledgr_feature_contracts(plain_features)


## ----parameter-grid-features, eval=FALSE------------------------------------------------
# swept_features <- ledgr_feature_map(
#   ret_5 = ledgr_ind_returns(5),
#   ret_10 = ledgr_ind_returns(10),
#   ret_20 = ledgr_ind_returns(20)
# )
# 
# feature_ids <- ledgr_feature_id(swept_features)
# 
# parameterized_strategy <- function(ctx, params) {
#   targets <- ctx$flat()
#   feature_id <- feature_ids[[paste0("ret_", params$lookback)]]
# 
#   for (id in ctx$universe) {
#     ret <- ctx$feature(id, feature_id)
#     if (is.finite(ret) && ret > params$min_return) {
#       targets[id] <- params$qty
#     }
#   }
# 
#   targets
# }
# 
# grid <- ledgr_param_grid(
#   lookback = c(5, 10, 20),
#   min_return = 0,
#   qty = 10
# )


## ----install-ttr, eval=FALSE------------------------------------------------------------
# install.packages("TTR")


## ----ttr-backed-indicators, eval=requireNamespace("TTR", quietly = TRUE)----------------
ttr_features <- ledgr_feature_map(
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


## ----ttr-output-examples, eval=requireNamespace("TTR", quietly = TRUE)------------------
ledgr_feature_contracts(ledgr_feature_map(
  bb_dn = ledgr_ind_ttr("BBands", input = "close", output = "dn", n = 20),
  bb_mavg = ledgr_ind_ttr("BBands", input = "close", output = "mavg", n = 20),
  bb_up = ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20),
  bb_pctB = ledgr_ind_ttr("BBands", input = "close", output = "pctB", n = 20)
))


## ----ttr-warmup-rules, message=FALSE, eval=requireNamespace("TTR", quietly = TRUE)------
ledgr_ttr_warmup_rules() |>
  select(ttr_fn, input, formula)


## ----ttr-pulse-snapshot, eval=FALSE-----------------------------------------------------
# ttr_pulse <- ledgr_pulse_snapshot(
#   snapshot,
#   universe = c("DEMO_01", "DEMO_02"),
#   ts_utc = ledgr_utc("2019-06-03"),
#   features = ttr_features
# )
# 
# ledgr_pulse_features(ttr_pulse, ttr_features)
# close(ttr_pulse)


## ----unsupported-ttr, eval=requireNamespace("TTR", quietly = TRUE)----------------------
ledgr_ind_ttr(
  "DEMA",
  input = "close",
  n = 10,
  requires_bars = 20
)$id

