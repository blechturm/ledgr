# WS1 timing protocol (v0.2.3 cut 1, LDG-3127): the frozen workload and path
# matrix shared by runner.R, measure.R and check.R. protocol.md explains it.
# Changing this file after the base record changes the protocol; check.R
# refuses a record whose recorded digest of this file differs.

ws1_timing_protocol_version <- "ws1-timing-1"
# Pairs per record. The cut requires at least five. Eight are frozen: an even
# count lets each arm run first in exactly half of the pairs (a one-pair runner
# smoke run on one tree showed the second process of a cell about 5% slower on
# the run path), and more pairs make each median less sensitive to one
# disturbed process. check.R requires exactly this many, so a record cannot
# add pairs until it passes.
ws1_timing_pairs <- 8L
ws1_timing_bound <- 1.03
ws1_timing_paths <- c("run", "sweep")
ws1_timing_arms <- c("base", "candidate")
ws1_timing_power_plan_guid <- "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" # High performance
ws1_timing_affinity <- 65535 # 0xFFFF, performance cores 0-15

# Files whose bytes define the protocol; their SHA-256 is recorded with every
# record and re-checked by check.R.
ws1_timing_protocol_files <- c(
  "dev/bench/v0_2_3_ws1_timing/matrix.R",
  "dev/bench/v0_2_3_ws1_timing/measure.R",
  "dev/bench/v0_2_3_ws1_timing/runner.R",
  "dev/bench/v0_2_3_ws1_timing/check.R",
  "dev/bench/v0_2_3_output_freeze/fixtures.R",
  "dev/bench/v0_2_3_output_freeze/timing.R"
)
# Line-ending-insensitive SHA-256 of a text file, so that a CRLF checkout of
# the same commit yields the same digest.
ws1_timing_file_digest <- function(path) {
  text <- paste0(paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "
"), "
")
  digest::digest(enc2utf8(text), algo = "sha256", serialize = FALSE)
}
# A0 lib.R may migrate its observer attachment points under cut decision (1),
# so only the one definition used here, a0_retain, is pinned (its deparsed text).
ws1_timing_retain_text <- function(root) {
  exprs <- as.list(parse(file.path(root, "dev/bench/v0_2_3_output_freeze/lib.R"), keep.source = FALSE))
  hit <- Filter(function(x) {
    is.call(x) && identical(x[[1L]], as.name("<-")) && identical(x[[2L]], as.name("a0_retain"))
  }, exprs)
  paste(deparse(hit[[1L]]), collapse = "\n")
}

# Columns of raw.csv, one row per measurement process (measure.R writes all but
# exit_status, which runner.R adds).
ws1_timing_raw_fields <- c("seq", "pair", "arm", "workload", "path", "seconds", "outcome", "error",
  "candidates", "statuses", "n_trades", "pid", "affinity", "power_plan_guid", "ledgr_path",
  "ledgr_version", "started_utc", "exit_status")

# One row per workload. Every workload runs through both paths. `statuses` is
# the expected per-candidate terminal status in grid row order, for both the
# committed runs (ledgr_run_list()$status) and the sweep rows (sweep$status);
# a measurement with any other status is a failed execution.
ws1_timing_workloads <- data.frame(
  workload = c(
    "dense_cost", "dense_risk_features", "dense_dividend_state",
    "avail_terminal_resume", "avail_acquisition", "avail_incomplete",
    "walk_forward", "timing_scale", "dense_scale_50x1260"
  ),
  source = c(
    rep("A0 fixtures.R a0_workloads", 7L),
    "A0 timing.R a0_fx_timing_scale (20 x 252)",
    "matrix.R ws1_fx_dense_scale_50x1260 (50 x 1260)"
  ),
  candidates = c(3L, 2L, 2L, 1L, 2L, 2L, 2L, 2L, 2L),
  statuses = c(
    "DONE;DONE;DONE", "DONE;DONE", "DONE;DONE", "DONE", "DONE;DONE",
    "INCOMPLETE;INCOMPLETE", "DONE;DONE", "DONE;DONE", "DONE;DONE"
  ),
  stringsAsFactors = FALSE
)

ws1_timing_cells <- function() {
  w <- ws1_timing_workloads$workload
  data.frame(
    workload = rep(w, each = length(ws1_timing_paths)),
    path = rep(ws1_timing_paths, times = length(w)),
    stringsAsFactors = FALSE
  )
}

# Extracts one top-level `name <- value` definition from an A0 script without
# running the script, so the timed fixture is A0's code byte for byte.
ws1_extract_definition <- function(path, name, envir = globalenv()) {
  exprs <- as.list(parse(path, keep.source = FALSE))
  hit <- Filter(function(x) {
    is.call(x) && identical(x[[1L]], as.name("<-")) && identical(x[[2L]], as.name(name))
  }, exprs)
  if (length(hit) != 1L) {
    stop(sprintf("ws1 timing: expected one definition of %s in %s", name, path), call. = FALSE)
  }
  eval(hit[[1L]][[3L]], envir = envir)
}

# The larger dense workload: 50 instruments x 1260 sessions (63,000 bars),
# deterministic prices (no RNG), SMA(20), 5 bps spread, a vectorised strategy
# so that event, fill and equity output rather than strategy code dominates.
# About 6,200 fills per candidate on the base tree.
ws1_fx_dense_scale_50x1260 <- function(db_path) {
  days <- 1260L
  ids <- sprintf("I%03d", 1:50)
  ts <- as.POSIXct("2015-01-01", tz = "UTC") + 86400 * (seq_len(days) - 1L)
  bars <- do.call(rbind, lapply(seq_along(ids), function(j) {
    close <- 100 * exp(cumsum(0.01 * sin(seq_len(days) * (0.05 + j / 97) + j)))
    data.frame(instrument_id = ids[[j]], ts_utc = ts, open = close * 0.999, high = close * 1.01,
      low = close * 0.99, close = close, volume = 1e5, stringsAsFactors = FALSE)
  }))
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path, snapshot_id = "ws1_dense_scale_50x1260")
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    sma <- ctx$vec$feature("sma_20")
    up <- !is.na(sma) & ctx$vec$close > sma
    targets[ctx$universe[up]] <- params$qty
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, features = list(ledgr_ind_sma(20)),
    opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_spread_bps(5))
  grid <- ledgr_grid_named(q10 = list(strategy = list(qty = 10)), q20 = list(strategy = list(qty = 20)))
  list(snapshot = snapshot, exp = exp, grid = grid, seed = 7L)
}

# Loads every fixture into `envir` (ledgr must already be attached) and
# returns the fixture constructor and the sweep retention for one workload.
ws1_timing_fixture <- function(root, workload, envir = globalenv()) {
  a0 <- file.path(root, "dev", "bench", "v0_2_3_output_freeze")
  sys.source(file.path(a0, "fixtures.R"), envir = envir)
  retain <- ws1_extract_definition(file.path(a0, "lib.R"), "a0_retain", envir)
  fixture <- switch(workload,
    timing_scale = ws1_extract_definition(file.path(a0, "timing.R"), "a0_fx_timing_scale", envir),
    dense_scale_50x1260 = ws1_fx_dense_scale_50x1260,
    get("a0_workloads", envir = envir)[[workload]]$fixture
  )
  if (!is.function(fixture)) {
    stop(sprintf("ws1 timing: unknown workload %s", workload), call. = FALSE)
  }
  list(fixture = fixture, retain = retain)
}
