# Cut 23 decision 5a: which oracle public entries reach the stored-config
# rebuild of built-in ids (ledgr_feature_defs_from_config()), on both clocks,
# with the oracle's own public-entry fixtures and feature set. Prints, per
# clock and entry, the number of rebuild calls and the built-in ids rebuilt
# (sma_<n>, return_1). Committed runs must reach both; sweeps, explicit
# precompute, reuse and pulse inspection use the experiment's converted
# definitions and call the rebuild zero times.
#
#   Rscript rebuild_coverage.R --lib=<library> --out=<scratch dir>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  .libPaths(c(normalizePath(arg("lib"), winslash = "/", mustWork = TRUE), .libPaths()))
  suppressPackageStartupMessages(library(ledgr))
  ns <- asNamespace("ledgr")
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  source(file.path(here, "corpus.R"), local = TRUE)
  out <- arg("out")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  box <- new.env(parent = emptyenv())
  original <- get("ledgr_feature_defs_from_config", ns)
  unlockBinding("ledgr_feature_defs_from_config", ns)
  assign("ledgr_feature_defs_from_config", function(cfg) {
    defs <- original(cfg)
    ids <- vapply(defs, function(d) d$id, character(1))
    box$calls <- box$calls + 1L
    box$ids <- c(box$ids, ids[grepl("^sma_[0-9]+$", ids) | ids == "return_1"])
    defs
  }, ns)
  entry <- function(clock, name, expr) {
    box$calls <- 0L
    box$ids <- character()
    force(expr)
    cat(sprintf("%-18s %-17s rebuild calls %d  built-in ids %s\n", clock, name, box$calls,
                paste(sort(unique(box$ids)), collapse = ",")))
  }
  features <- fx_e2e_features()
  ids <- vapply(features, function(f) f$id, "")
  grid <- ledgr::ledgr_grid_named(a = list(strategy = list(tag = "a", features = ids)))
  for (clock in c("bar_native", "declared_sessions")) {
    build <- if (identical(clock, "bar_native")) fx_bar_native else fx_declared
    seen <- new.env()
    fx <- build(file.path(out, paste0(clock, ".duckdb")), fx_spy(seen), features)
    entry(clock, "run", close(ledgr::ledgr_run(fx$exp, params = list(tag = "run", features = ids), run_id = "run")))
    entry(clock, "sweep", ledgr::ledgr_sweep(fx$exp, grid))
    pre <- NULL
    entry(clock, "precompute", pre <- ledgr::ledgr_precompute_features(fx$exp, grid))
    entry(clock, "precompute_reuse", ledgr::ledgr_sweep(fx$exp, grid, precomputed_features = pre))
    entry(clock, "inspect", ledgr::ledgr_pulse_snapshot(fx$exp, ts_utc = fx$axis[[20L]], params = list(tag = "inspect")))
    dated <- build(file.path(out, paste0(clock, "_dated.duckdb")), fx_spy(seen), features,
                   opening_date = as.Date(fx$axis[[10L]]))
    entry(clock, "dated_run", close(ledgr::ledgr_run(dated$exp, params = list(tag = "dated", features = ids),
                                                     run_id = "dated")))
    ledgr::ledgr_snapshot_close(fx$snapshot)
    ledgr::ledgr_snapshot_close(dated$snapshot)
  }
})
