## ----setup, include=FALSE---------------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  fig.path = "figures/getting-started-",
  out.width = "100%"
)
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

## ----attach-----------------------------------------------------------------------------
library(ledgr)
library(dplyr)
library(tibble)
data("ledgr_demo_bars", package = "ledgr")

## ----demo-data--------------------------------------------------------------------------
bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    between(ts_utc, ledgr_utc("2019-01-01"), ledgr_utc("2019-06-30"))
  )

bars |>
  slice_head(n = 6)

## ----snapshot---------------------------------------------------------------------------
snapshot <- ledgr_snapshot_from_df(bars)
snapshot

## ----strategy---------------------------------------------------------------------------
strategy <- function(ctx, params) {
  targets <- ctx$flat()

  for (id in ctx$universe) {
    sma <- ctx$feature(id, "sma_20")
    if (is.finite(sma) && ctx$close(id) > sma) {
      targets[id] <- params$qty
    }
  }

  targets
}

## ----features---------------------------------------------------------------------------
features <- list(ledgr_ind_sma(20))
ledgr_feature_id(features)

## ----experiment-------------------------------------------------------------------------
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  features = features,
  opening = ledgr_opening(cash = 10000)
)

exp

## ----run--------------------------------------------------------------------------------
bt <- exp |>
  ledgr_run(params = list(qty = 10), run_id = "getting_started_qty_10")

bt

## ----summary----------------------------------------------------------------------------
summary(bt)

## ----result-tables----------------------------------------------------------------------
ledgr_results(bt, what = "trades")
tail(ledgr_results(bt, what = "equity"), 4)

## ----ledger-----------------------------------------------------------------------------
head(ledgr_results(bt, what = "ledger"), 6)

## ----pulse------------------------------------------------------------------------------
pulse <- ledgr_pulse_snapshot(
  snapshot = snapshot,
  universe = c("DEMO_01", "DEMO_02"),
  ts_utc = "2019-03-01T00:00:00Z",
  features = features
)

pulse$close("DEMO_01")
pulse$feature("DEMO_01", "sma_20")
strategy(pulse, list(qty = 10))
close(pulse)

## ----second-run-------------------------------------------------------------------------
bt_qty_20 <- exp |>
  ledgr_run(params = list(qty = 20), run_id = "getting_started_qty_20")

ledgr_compare_runs(snapshot, run_ids = c("getting_started_qty_10", "getting_started_qty_20"))

## ----durable----------------------------------------------------------------------------
artifact_db <- tempfile("ledgr_getting_started_", fileext = ".duckdb")
durable_snapshot <- ledgr_snapshot_from_df(
  bars,
  db_path = artifact_db,
  snapshot_id = "getting_started_snapshot"
)

durable_exp <- ledgr_experiment(
  snapshot = durable_snapshot,
  strategy = strategy,
  features = features,
  opening = ledgr_opening(cash = 10000)
)

durable_bt <- durable_exp |>
  ledgr_run(params = list(qty = 10), run_id = "durable_qty_10")

close(durable_bt)
ledgr_snapshot_close(durable_snapshot)

reloaded <- ledgr_snapshot_load(artifact_db, "getting_started_snapshot", verify = TRUE)
ledgr_run_list(reloaded)
ledgr_run_info(reloaded, "durable_qty_10")
ledgr_snapshot_close(reloaded)

## ----cleanup----------------------------------------------------------------------------
close(bt)
close(bt_qty_20)
ledgr_snapshot_close(snapshot)

