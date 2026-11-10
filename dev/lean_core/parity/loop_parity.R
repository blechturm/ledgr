# Whole-run parity of the compact-state lean loop (LDG-3219, interface
# Section 19.6). Each workload runs on the pinned build, then with the lean
# envelope installed; every run-store table (diagnostics decoded), the public
# readers and the conditions are compared in A0 canonical form
# (dev/bench/v0_2_3_output_freeze/lib.R, doubles at %.17g). A workload the
# loop refuses before its first pulse runs on the pin and is recorded as
# refused with the feature named.
#
#   Rscript dev/lean_core/parity/loop_parity.R --lib=<pinned library>
#     --debug=0|1 --out=<csv> [--workloads=<id,...>]

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
source(file.path(here, "..", "load.R"))
lean <- lean_core_load(lib, debug = debug)
ns <- asNamespace("ledgr")
pinned_envelope <- get("ledgr_fold_envelope", envir = ns)
tally <- new.env()
tally$lean <- 0L
tally$refused <- character()
lean_inner <- lean$lean_fold_envelope
lean$lean_fold_envelope <- function(execution, output_handler) {
  cov <- tryCatch({ lean$lean_loop_coverage(ledgr_validate_execution_spec(execution), output_handler); NULL },
                  ledgr_lean_not_covered = function(c) c)
  if (!is.null(cov)) {
    tally$refused <- c(tally$refused, cov$feature)
    return(pinned_envelope(execution, output_handler))
  }
  tally$lean <- tally$lean + 1L
  lean_inner(execution, output_handler)
}
environment(lean$lean_fold_envelope) <- lean
install <- lean$lean_loop_install

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
extra <- list(
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
  tally$lean <- 0L
  tally$refused <- character()
  restore <- install()
  candidate <- tryCatch(run_tables(id), finally = restore())
  t2 <- proc.time()[["elapsed"]]
  refused <- paste(unique(tally$refused), collapse = "; ")
  for (path in union(names(pinned), names(candidate))) {
    for (tab in union(names(pinned[[path]]), names(candidate[[path]]))) {
      a <- pinned[[path]][[tab]]; b <- candidate[[path]][[tab]]
      same <- identical(a, b)
      rows[[length(rows) + 1L]] <- data.frame(
        workload = id, path = path, table = tab, debug = as.integer(debug),
        lean_folds = tally$lean, refused = refused, rows = if (is.null(a)) NA_integer_ else nrow(a), identical = same,
        first_difference = if (same) "" else if (is.null(a) || is.null(b)) "<missing>" else first_difference(a, b),
        pinned_s = round(t1 - t0, 2), lean_s = round(t2 - t1, 2), stringsAsFactors = FALSE)
    }
  }
  res <- do.call(rbind, rows)
  cat(sprintf("%-22s %s  lean folds %d  refused [%s]  pinned %.1f s  lean %.1f s\n", id,
              if (all(res$identical[res$workload == id])) "identical" else "DIFFERENT", tally$lean, refused,
              t1 - t0, t2 - t1))
}
res <- do.call(rbind, rows)
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(res, out, row.names = FALSE)
cat(sprintf("%d tables, %d different\n", nrow(res), sum(!res$identical)))
if (any(!res$identical)) quit(status = 1L)
