# Whole-run parity of the compact-state lean loop (LDG-3219, interface
# Section 19.6). Each workload runs on the pinned build, then through
# lean_loop_run() (the harness entry: lean loop installed, pre-pulse refusals
# on the pin, a mid-run coverage condition reruns the complete workload on
# the pin). Every run-store table (diagnostics decoded), the public readers,
# the conditions and the sweep results are compared in A0 canonical form
# (dev/bench/v0_2_3_output_freeze/lib.R, doubles at %.17g). The detectors
# (no handler call and no hold expansion while pulses run) are checked on
# every lean workload.
#
#   Rscript dev/lean_core/parity/loop_parity.R --lib=<pinned library>
#     --debug=0|1 --out=<csv> [--workloads=<id,...>] [--batch-rows=<n>]
#     [--mutation=<name>]
#
# --mutation runs a registered mutation or witness fault and inverts the
# verdict: fill_price_ulp, drop_hold and hold_position must make some table
# differ; write_in_loop must fire the store-write detector, hold_in_loop the
# hold detector, store_in_loop (DBI and ledgr_store_append on a scratch store) the store-boundary detector; batch_fault must fail the run after a real terminal store write and roll it back.
# PASS* marks a workload whose public call stopped before any fold ran.

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
batch_rows <- as.integer(arg("batch-rows", "65536"))
mutation <- arg("mutation", "")
mutations <- c("fill_price_ulp", "drop_hold", "hold_position", "write_in_loop", "store_in_loop", "hold_in_loop", "batch_fault")
if (nzchar(mutation) && !mutation %in% mutations) stop("unknown --mutation: ", mutation, call. = FALSE)
source(file.path(here, "..", "load.R"))
lean <- lean_core_load(lib, debug = debug)
ns <- asNamespace("ledgr")

repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(repo, "dev/bench/v0_2_3_ws16_entry/workloads.R"))
source(file.path(repo, "dev/bench/v0_2_3_output_freeze/lib.R"))
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))
source(file.path(here, "prep_fixture.R"))
work <- file.path(tempdir(), "loop_parity")
dir.create(work, showWarnings = FALSE)

collect_open <- function(snapshot, db, run_id, exp, ...) {
  sink <- a0_new_sink()
  ok <- a0_run_or_record(close(ledgr::ledgr_run(exp, run_id = run_id, ...)), run_id, sink)
  # A reader refusal (an INCOMPLETE run) is itself compared.
  readers <- if (ok) tryCatch(a0_reader_tables(snapshot, run_id), error = function(e) {
    list(reader_refusal = data.frame(class = class(e)[[1L]], message = conditionMessage(e), stringsAsFactors = FALSE))
  })
  list(run = c(a0_store_tables(db, run_id), readers,
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
crossover_exp <- function(snapshot) {
  strategy <- r_floor_transition
  environment(strategy) <- ns
  ledgr::ledgr_experiment(snapshot, strategy,
    features = ledgr::ledgr_feature_map(
      fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
    risk_chain = ledgr::ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE))
}
crossover <- function(n_inst, n_days) function() {
  name <- sprintf("crossover_%dx%d", n_inst, n_days)
  db <- build(name, function(db) ledgr::ledgr_snapshot_from_df(r_floor_fixture(n_inst, n_days)$bars, db_path = db,
                                                              snapshot_id = name, price_basis = "split_adjusted"))
  collect(db, name, "lp-crossover", crossover_exp, seed = 20260530L)
}
source(file.path(here, "loop_workloads.R"))
extra <- c(list(
  crossover_3x40 = crossover(3L, 40L),
  crossover_10x300 = crossover(10L, 300L),
  crossover_10x7200 = crossover(10L, 7200L),
  crossover_20x23400 = crossover(20L, 23400L),
  crossover_500x1260 = crossover(500L, 1260L),
  fill_heavy_500x1260 = function() {
    db <- build("fill", function(db) ledgr::ledgr_snapshot_from_df(ws16_fill_heavy_bars(), db_path = db,
                                                                   snapshot_id = "lp_fill"))
    collect(db, "lp_fill", "lp-fill", ws16_fill_heavy_experiment, seed = 20260530L)
  },
  momentum_40x504 = function() {
    db <- build("momentum", function(db) ws16_momentum_snapshot(40L, 504L, db, "lp_momentum"))
    collect(db, "lp_momentum", "lp-momentum", function(s) ws16_momentum_experiment(s, 63L),
            params = list(lookback = 63L, n = 10L), seed = 1L)
  },
  prep_fixture = function() {
    db <- file.path(work, "prep_fixture.duckdb")
    if (file.exists(db)) unlink(db)
    fx <- lc_prep_fixture(db)
    on.exit(ledgr::ledgr_snapshot_close(fx$snapshot))
    collect_open(fx$snapshot, db, "lp-prep-fixture", fx$exp, seed = 1L,
                 params = utils::modifyList(lc_prep_fixture_params, list(trade = TRUE, lookback = 10L, n = 3L)))
  }
), loop_constructed, loop_witnesses)
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
verdicts <- character()
for (id in ids) {
  t0 <- proc.time()[["elapsed"]]
  pinned <- run_tables(id)
  t1 <- proc.time()[["elapsed"]]
  attempt <- lean$lean_loop_run(function() {
    lean$lean_entry$batch_rows <- batch_rows
    if (nzchar(mutation)) lean$lean_entry$mutation <- mutation
    run_tables(id)
  })
  t2 <- proc.time()[["elapsed"]]
  candidate <- attempt$value
  rec <- attr(attempt, "lean")
  refused <- paste(unique(rec$refused), collapse = "; ")
  backstop <- paste(unique(rec$backstop), collapse = "; ")
  writes <- paste(unique(rec$store_writes), collapse = "; ")
  path_rows <- list()
  for (path in union(names(pinned), names(candidate))) {
    for (tab in union(names(pinned[[path]]), names(candidate[[path]]))) {
      a <- pinned[[path]][[tab]]; b <- candidate[[path]][[tab]]
      same <- identical(a, b)
      path_rows[[length(path_rows) + 1L]] <- data.frame(
        workload = id, path = path, table = tab, debug = as.integer(debug), batch_rows = batch_rows,
        mutation = mutation, lean_folds = rec$lean_folds, refused = refused, backstop = backstop,
        store_writes = writes, hold_calls = rec$hold_calls, rows = if (is.null(a)) NA_integer_ else nrow(a),
        identical = same,
        first_difference = if (same) "" else if (is.null(a) || is.null(b)) "<missing>" else first_difference(a, b),
        pinned_s = round(t1 - t0, 2), lean_s = round(t2 - t1, 2), stringsAsFactors = FALSE)
    }
  }
  res <- do.call(rbind, path_rows)
  rows <- c(rows, path_rows)
  same_all <- all(res$identical)
  events_left <- sum(vapply(candidate, function(p) if (is.data.frame(p$ledger_events)) nrow(p$ledger_events) else 0L, 0L))
  verdict <- switch(if (nzchar(mutation)) mutation else "none",
    none = if (!(same_all && !nzchar(writes) && rec$hold_calls == 0L)) "FAIL" else
      if (rec$lean_folds == 0L && !nzchar(refused)) "PASS*" else "PASS",
    fill_price_ulp = , drop_hold = , hold_position = if (rec$lean_folds == 0L) "NOT RUN" else if (!same_all) "CAUGHT" else "MISSED",
    write_in_loop = if (rec$lean_folds == 0L) "NOT RUN" else if (nzchar(writes)) "CAUGHT" else "MISSED",
    store_in_loop = if (rec$lean_folds == 0L) "NOT RUN" else
      if (all(c("DBI::dbExecute", "ledgr::ledgr_store_append") %in% rec$store_writes)) "CAUGHT" else "MISSED",
    hold_in_loop = if (rec$lean_folds == 0L) "NOT RUN" else if (rec$hold_calls > 0L) "CAUGHT" else "MISSED",
    # the fault fires only after a real terminal store write, which must be rolled back
    batch_fault = if (rec$lean_folds == 0L) "NOT RUN" else
      if (!same_all && events_left == 0L && isTRUE(rec$writes_before_fault > 0L)) "ROLLED BACK" else "MISSED")
  verdicts[[id]] <- verdict
  cat(sprintf("%-26s %-11s %s  lean folds %d  refused [%s]  backstop [%s]  writes [%s]  holds %d  pinned %.1f s  lean %.1f s\n",
              id, verdict, if (same_all) "identical" else "DIFFERENT", rec$lean_folds, refused, backstop, writes,
              rec$hold_calls, t1 - t0, t2 - t1))
}
res <- do.call(rbind, rows)
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(res, out, row.names = FALSE)
cat(sprintf("%d tables, %d different; verdicts: %s\n", nrow(res), sum(!res$identical),
            paste(names(table(verdicts)), table(verdicts), sep = " ", collapse = ", ")))
bad <- if (nzchar(mutation)) verdicts %in% c("MISSED") else verdicts == "FAIL"
if (any(bad)) quit(status = 1L)
