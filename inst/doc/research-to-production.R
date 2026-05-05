## ----setup, include=FALSE---------------------------------------------------------------
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
options(width = 90)


## ----experiment-store-api, eval=FALSE---------------------------------------------------
# snapshot <- ledgr_snapshot_load(db_path, "snapshot_id")
# 
# runs <- ledgr_run_list(snapshot)
# 
# info <- ledgr_run_info(snapshot, "sma_20_production_candidate")
# 
# bt <- ledgr_run_open(snapshot, "sma_20_production_candidate")
# ledgr_results(bt, what = "equity")
# 
# snapshot <- snapshot |>
#   ledgr_run_label("sma_20_production_candidate", "approved-baseline") |>
#   ledgr_run_archive("discarded-parameter-test", reason = "bad regime fit")

