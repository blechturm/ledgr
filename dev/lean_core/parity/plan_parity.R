# Whole-run parity of a lean stage swapped into the pinned run (macro WS16
# family method, point 3). Each workload runs twice in this process: on the
# pinned build, then with the lean stage installed; every run-store table
# (diagnostics decoded), the public fill, trade and metric readers and the
# conditions are compared in A0 canonical form (dev/bench/v0_2_3_output_freeze/
# lib.R), which prints doubles at %.17g, so a one-ulp change shows.
#
#   Rscript dev/lean_core/parity/plan_parity.R --lib=<pinned library> --debug=0|1
#     --out=<csv> [--stage=plan] [--workloads=<id,...>]
#
# Workloads: the eight A0 workloads (run, sweep with one worker, compiled
# FIFO, restart, abort and walk-forward paths), and momentum_40x504,
# fill_heavy_500x1260, prep_fixture, crossover_10x7200, crossover_500x1260 and
# the portable shapes portable_500x1260/2520/5040. A0's sweep_w2 path runs in
# worker processes that load the plain pin: it is compared, but it does not
# exercise the lean stage.

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) return(default %||% stop("--", name, "= is required", call. = FALSE))
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
`%||%` <- function(a, b) if (is.null(a)) b else a
lib <- arg("lib")
debug <- identical(arg("debug", "0"), "1")
out <- arg("out")
stage <- arg("stage", "plan")
source(file.path(here, "..", "load.R"))
lean <- lean_core_load(lib, debug = debug)
if (!identical(stage, "plan")) stop("unknown --stage=", stage, call. = FALSE)
# Counts lean P3 calls, so a run the lean stage never reached cannot pass.
lean_calls <- 0L
lean_inner <- lean$lean_stage_plan
lean$lean_stage_plan <- function(...) {
  lean_calls <<- lean_calls + 1L
  lean_inner(...)
}
# Mutations (each must make parity fail): a defect injected into the lean
# stage's environment only, so the pinned arm is untouched.
mutation <- arg("mutation", "none")
switch(mutation,
  none = NULL,
  # a fill price one ulp high: ledger events, fills, equity
  fill_price_ulp = local({
    inner <- lean$lean_stage_plan
    lean$lean_stage_plan <- function(...) {
      r <- inner(...)
      if (!is.null(r$batch)) r$batch$fill$price <- r$batch$fill$price * (1 + .Machine$double.eps)
      r
    }
  }),
  # an implicit hold row's target changed: stored diagnostics only
  hold_target_changed = local({
    inner <- lean$lean_plan_clean
    lean$lean_plan_clean <- function(...) {
      r <- inner(...)
      h <- which(r$clean_hold)
      if (length(h)) r$target[[h[[1L]]]] <- r$target[[h[[1L]]]] + 1
      r
    }
  }),
  # two rejection reason codes swapped: rejection diagnostics
  reason_levels_swapped = local({
    lv <- get(".ledgr_plan_reason_levels", envir = asNamespace("ledgr"))
    lean$.ledgr_plan_reason_levels <- replace(lv, 2:3, lv[3:2])
  }),
  stop("unknown --mutation=", mutation, call. = FALSE)
)
install <- lean$lean_plan_install
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(repo, "dev/bench/v0_2_3_ws16_entry/workloads.R"))
source(file.path(repo, "dev/bench/v0_2_3_output_freeze/lib.R"))
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))
source(file.path(here, "prep_fixture.R"))
ns <- asNamespace("ledgr")
work <- file.path(tempdir(), "plan_parity")
dir.create(work, showWarnings = FALSE)

# One committed run of a non-A0 workload: its store tables and readers.
collect_open <- function(snapshot, db, run_id, exp, ...) {
  sink <- a0_new_sink()
  ok <- a0_run_or_record(close(ledgr::ledgr_run(exp, run_id = run_id, ...)), run_id, sink)
  list(run = c(a0_store_tables(db, run_id), if (ok) a0_reader_tables(snapshot, run_id),
               list(run_conditions = a0_canon(sink$rows, "run_conditions", "seq"))))
}
collect <- function(db, snapshot_id, run_id, experiment, ...) {
  snapshot <- ledgr::ledgr_snapshot_open(db, snapshot_id, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  collect_open(snapshot, db, run_id, experiment(snapshot), ...)
}
build <- function(name, make) {
  db <- file.path(work, paste0(name, ".duckdb"))
  if (file.exists(db)) unlink(db)
  ledgr::ledgr_snapshot_close(make(db))
  db
}
crossover <- function(n_inst, n_days) function() {
  name <- sprintf("crossover_%dx%d", n_inst, n_days)
  db <- build(name, function(db) ledgr::ledgr_snapshot_from_df(r_floor_fixture(n_inst, n_days)$bars, db_path = db,
                                                              snapshot_id = name, price_basis = "split_adjusted"))
  strategy <- r_floor_transition
  environment(strategy) <- ns
  collect(db, name, "pp-crossover", function(snapshot) ledgr::ledgr_experiment(snapshot, strategy,
    features = ledgr::ledgr_feature_map(
      fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
    risk_chain = ledgr::ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE)), seed = 20260530L)
}
portable <- function(days) function() {
  name <- sprintf("portable_500x%d", days)
  db <- build(name, function(db) ws16_momentum_snapshot(500L, days, db, name))
  con <- DBI::dbConnect(duckdb::duckdb(), db, read_only = TRUE)
  first <- DBI::dbGetQuery(con, "SELECT min(instrument_id) AS id FROM snapshot_instruments WHERE snapshot_id = ?",
                           params = list(name))$id
  DBI::dbDisconnect(con, shutdown = TRUE)
  collect(db, name, "pp-portable", function(snapshot) lc_prep_shape_experiment(snapshot),
          params = lc_prep_shape_params(first), seed = 1L)
}
extra <- list(
  momentum_40x504 = function() {
    db <- build("momentum", function(db) ws16_momentum_snapshot(40L, 504L, db, "pp_momentum"))
    collect(db, "pp_momentum", "pp-momentum", function(s) ws16_momentum_experiment(s, 63L),
            params = list(lookback = 63L, n = 10L), seed = 1L)
  },
  fill_heavy_500x1260 = function() {
    db <- build("fill", function(db) ledgr::ledgr_snapshot_from_df(ws16_fill_heavy_bars(), db_path = db,
                                                                   snapshot_id = "pp_fill"))
    collect(db, "pp_fill", "pp-fill", ws16_fill_heavy_experiment, seed = 20260530L)
  },
  prep_fixture = function() {
    db <- file.path(work, "prep_fixture.duckdb")
    if (file.exists(db)) unlink(db)
    fx <- lc_prep_fixture(db)
    on.exit(ledgr::ledgr_snapshot_close(fx$snapshot))
    # Trading on: membership exits, the relisted and late-known inactive
    # instruments and missing execution bars reach P3.
    collect_open(fx$snapshot, db, "pp-prep-fixture", fx$exp, seed = 1L,
                 params = utils::modifyList(lc_prep_fixture_params, list(trade = TRUE, lookback = 10L, n = 3L)))
  },
  crossover_10x7200 = crossover(10L, 7200L),
  crossover_500x1260 = crossover(500L, 1260L),
  portable_500x1260 = portable(1260L),
  portable_500x2520 = portable(2520L),
  portable_500x5040 = portable(5040L)
)
all_ids <- c(names(a0_workloads), names(extra))
ids <- strsplit(arg("workloads", paste(all_ids, collapse = ",")), ",")[[1L]]
if (length(bad <- setdiff(ids, all_ids))) stop("unknown workload(s): ", paste(bad, collapse = ", "), call. = FALSE)

run_tables <- function(id) {
  if (id %in% names(a0_workloads)) a0_run_workload(id, work)$tables else extra[[id]]()
}
first_difference <- function(a, b) {
  if (!identical(names(a), names(b))) return("<columns>")
  if (nrow(a) != nrow(b)) return(sprintf("<rows %d vs %d>", nrow(a), nrow(b)))
  if (!identical(attr(a, "a0_types"), attr(b, "a0_types"))) return("<types>")
  for (col in names(a)) {
    d <- which(!(a[[col]] == b[[col]] | (is.na(a[[col]]) & is.na(b[[col]]))) | xor(is.na(a[[col]]), is.na(b[[col]])))
    if (length(d)) return(sprintf("row %d column %s: %s vs %s", d[[1L]], col, a[[col]][[d[[1L]]]], b[[col]][[d[[1L]]]]))
  }
  "<attributes>"
}
rows <- list()
for (id in ids) {
  t0 <- proc.time()[["elapsed"]]
  pinned <- run_tables(id)
  t1 <- proc.time()[["elapsed"]]
  lean_calls <- 0L
  restore <- install()
  candidate <- tryCatch(run_tables(id), finally = restore())
  t2 <- proc.time()[["elapsed"]]
  for (path in union(names(pinned), names(candidate))) {
    for (tab in union(names(pinned[[path]]), names(candidate[[path]]))) {
      a <- pinned[[path]][[tab]]; b <- candidate[[path]][[tab]]
      same <- identical(a, b)
      rows[[length(rows) + 1L]] <- data.frame(
        workload = id, path = path, table = tab, debug = as.integer(debug), stage = stage, mutation = mutation,
        lean_calls = lean_calls, rows = if (is.null(a)) NA_integer_ else nrow(a), identical = same,
        first_difference = if (same) "" else if (is.null(a) || is.null(b)) "<missing>" else first_difference(a, b),
        pinned_s = round(t1 - t0, 2), lean_s = round(t2 - t1, 2), stringsAsFactors = FALSE)
    }
  }
  res <- do.call(rbind, rows)
  cat(sprintf("%-22s %s  lean P3 calls %d  pinned %.1f s  lean %.1f s\n", id,
              if (all(res$identical[res$workload == id])) "identical" else "DIFFERENT", lean_calls, t1 - t0, t2 - t1))
}
res <- do.call(rbind, rows)
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(res, out, row.names = FALSE)
cat(sprintf("%d tables, %d different\n", nrow(res), sum(!res$identical)))
if (any(!res$identical) || any(res$lean_calls == 0L)) quit(status = 1L)
