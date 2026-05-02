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
library(tibble)
data("ledgr_demo_bars", package = "ledgr")


## ----snapshot---------------------------------------------------------------------------
db_path <- tempfile("ledgr_store_", fileext = ".duckdb")

bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    between(ts_utc, ledgr_utc("2019-01-01"), ledgr_utc("2019-06-30"))
  )

snapshot <- ledgr_snapshot_from_df(
  bars,
  db_path = db_path,
  snapshot_id = "store_demo_snapshot"
)


## ----csv-snapshot, eval=FALSE-----------------------------------------------------------
# snapshot <- ledgr_snapshot_from_csv(
#   "data/daily_bars.csv",
#   db_path = "research.duckdb",
#   snapshot_id = "eod_2019_h1"
# )


## ----csv-snapshot-load, eval=FALSE------------------------------------------------------
# snapshot <- ledgr_snapshot_load("research.duckdb", snapshot_id = "eod_2019_h1")


## ----experiment-------------------------------------------------------------------------
features <- list(ledgr_ind_sma(20))

trend_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  for (id in ctx$universe) {
    sma <- ctx$feature(id, "sma_20")
    if (is.finite(sma) && ctx$close(id) > sma) {
      targets[id] <- params$qty
    }
  }
  targets
}

exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = trend_strategy,
  features = features,
  opening = ledgr_opening(cash = 10000)
)

bt_small <- exp |>
  ledgr_run(params = list(qty = 5), run_id = "trend_qty_5")

bt_large <- exp |>
  ledgr_run(params = list(qty = 15), run_id = "trend_qty_15")


## ----list-------------------------------------------------------------------------------
ledgr_run_list(snapshot)


## ----label-tags-------------------------------------------------------------------------
snapshot <- snapshot |>
  ledgr_run_label("trend_qty_5", "Baseline quantity") |>
  ledgr_run_tag("trend_qty_5", c("baseline", "trend")) |>
  ledgr_run_tag("trend_qty_15", c("trend", "larger-size"))

ledgr_run_list(snapshot)


## ----list-deeper------------------------------------------------------------------------
ledgr_run_list(snapshot) |>
  as_tibble() |>
  select(run_id, label, tags, status, final_equity, execution_mode)


## ----info-------------------------------------------------------------------------------
info <- ledgr_run_info(snapshot, "trend_qty_5")
info


## ----compare----------------------------------------------------------------------------
ledgr_compare_runs(snapshot, run_ids = c("trend_qty_5", "trend_qty_15"))


## ----open-------------------------------------------------------------------------------
reopened <- ledgr_run_open(snapshot, "trend_qty_5")
summary(reopened)
tail(ledgr_results(reopened, what = "equity"), 3)
close(reopened)


## ----archive----------------------------------------------------------------------------
snapshot <- snapshot |>
  ledgr_run_archive("trend_qty_15", reason = "larger position kept for reference")

ledgr_run_list(snapshot)


## ----cleanup----------------------------------------------------------------------------
close(bt_small)
close(bt_large)
ledgr_snapshot_close(snapshot)

