# Real-data scale recorder (Cut 11 LDG-2982).
#
#   Rscript run_record.R <repo> <out_dir> [--lane=fixture|sharadar]
#     [--snapshot=<path>] [--universe=<id>] [--phases=a,b,...]
#     [--size=n_inst,n_days,n_mem] [--allow-dirty]
#
# Runs the public point-in-time research cycle on one tree and writes every
# comparison family as a canonical CSV under <out_dir>/families, plus
# <out_dir>/phases.csv (wall-clock phase boundaries, used by run_pair.R to
# attribute elapsed time and peak memory) and <out_dir>/meta.csv. Run-specific
# columns (timestamps of the recording itself, timings, versions, paths) are
# dropped; identity hashes go to the informational `identity` family, because
# ledgr fingerprints implementation bodies and a behavior-preserving change may
# legitimately move them. The sharadar lane runs on a copy of a private
# snapshot and writes full families, which hold vendor rows: its <out_dir> must
# be in the private store, and the recorder refuses one inside a Git work
# tree. summarize_record.R writes the aggregate (family hashes, row counts,
# clocks) that may leave the store.

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[length(hit)]]) else default
}
repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
out_dir <- args[[2L]]
lane <- opt("lane", "fixture")
size <- as.integer(strsplit(opt("size", "800,1260,300"), ",", fixed = TRUE)[[1L]])
all_phases <- c("build", "run_momentum", "run_equal_weight", "readers", "availability", "explain",
                "dense", "sweep", "promote", "walk_forward")
phases <- if (is.null(opt("phases"))) all_phases else strsplit(opt("phases"), ",", fixed = TRUE)[[1L]]
git <- function(...) paste(suppressWarnings(system2("git", c("-C", shQuote(repo), ...), stdout = TRUE, stderr = TRUE)), collapse = "\n")
if (identical(lane, "sharadar")) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  inside <- suppressWarnings(system2("git", c("-C", shQuote(out_dir), "rev-parse", "--is-inside-work-tree"),
                                     stdout = TRUE, stderr = FALSE))
  if (identical(inside, "true")) stop("The sharadar lane writes vendor rows; use an <out_dir> in the private store.", call. = FALSE)
}
dirty <- git("status", "--porcelain", "--untracked-files=no", "--", "R", "src", "DESCRIPTION", "NAMESPACE")
if (nzchar(dirty) && !"--allow-dirty" %in% args) stop("Refusing to record from a dirty product tree:\n", dirty, call. = FALSE)

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
source(file.path(here, "fixture.R"))
fam_dir <- file.path(out_dir, "families")
dir.create(fam_dir, recursive = TRUE, showWarnings = FALSE)
work <- file.path(out_dir, "work")
dir.create(work, showWarnings = FALSE)

phase_log <- file.path(out_dir, "phases.csv")
writeLines("phase,start,end", phase_log)
in_phase <- function(name, expr) {
  t0 <- Sys.time()
  value <- force(expr)
  cat(sprintf("%s,%.3f,%.3f\n", name, as.numeric(t0), as.numeric(Sys.time())), file = phase_log, append = TRUE)
  value
}
want <- function(name) name %in% phases

drop_cols <- "^(t_engine|t_results|t_fills_extract|elapsed_sec|created_at_utc|selected_at_utc|updated_at_utc|ledgr_version|R_version|dependency_versions_json|db_path|config_json|sweep_id|archived_at_utc)$"
canon_value <- function(x) {
  if (inherits(x, "POSIXt")) return(format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"))
  if (is.list(x)) return(vapply(x, function(v) as.character(jsonlite::toJSON(v, auto_unbox = TRUE, digits = NA, null = "null", na = "null")), character(1)))
  if (is.double(x)) return(ifelse(is.na(x), "NA", formatC(x, digits = 17, format = "g")))
  as.character(x)
}
family <- function(name, df) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  df <- df[, !grepl(drop_cols, names(df)), drop = FALSE]
  out <- as.data.frame(lapply(df, canon_value), stringsAsFactors = FALSE, optional = TRUE)
  names(out) <- names(df)
  utils::write.csv(out, file.path(fam_dir, paste0(name, ".csv")), row.names = FALSE)
  invisible(nrow(df))
}
# Large tables are compared by content digest: every row in a stable order.
digest_family <- function(name, con, sql) {
  rows <- DBI::dbGetQuery(con, sql)
  rows <- rows[, !grepl(drop_cols, names(rows)), drop = FALSE]
  tmp <- tempfile(fileext = ".csv")
  utils::write.csv(as.data.frame(lapply(rows, canon_value), optional = TRUE), tmp, row.names = FALSE)
  family(name, data.frame(rows = nrow(rows), sha256 = digest::digest(file = tmp, algo = "sha256")))
}
identity <- list()
note_identity <- function(key, value) identity[[key]] <<- paste(as.character(unlist(value)), collapse = "|")
s3list <- function(x) data.frame(field = names(x), value = canon_value(unname(as.list(x))), stringsAsFactors = FALSE)

# ---- Snapshot ------------------------------------------------------------------
if (identical(lane, "fixture")) {
  snap_path <- file.path(work, "scale.duckdb")
  unlink(snap_path)
  snapshot <- in_phase("build", scale_fixture_snapshot(snap_path, size[[1L]], size[[2L]], size[[3L]]))
  universe <- "U"
  mom_params <- list(lookback = 60L, n = 20L)
  mom_feature <- ledgr_ind_returns(60L)
} else {
  snap_path <- file.path(work, "sharadar.duckdb")
  stopifnot(file.copy(opt("snapshot"), snap_path, overwrite = TRUE))
  snapshot <- ledgr_snapshot_open(snap_path)
  universe <- opt("universe")
  mom_params <- list(lookback = 252L, n = 20L)
  mom_feature <- ledgr_ind_returns(252L)
}
con <- get_connection(snapshot)
info <- ledgr_snapshot_info(snapshot)
family("snapshot_info", info[, c("snapshot_id", "status", "snapshot_hash", "start_date", "end_date"), drop = FALSE])
if (identical(lane, "fixture")) {
  for (tb in grep("^snapshot_", DBI::dbListTables(con), value = TRUE)) {
    digest_family(paste0("snapshot_table_", tb), con, sprintf("SELECT * FROM %s ORDER BY ALL", tb))
  }
  # Refusal and quarantine outcomes on constructed invalid inputs.
  cls <- function(expr) tryCatch({ force(expr); "ok" }, error = function(e) paste(class(e), collapse = "|"))
  dup <- data.frame(instrument_id = "X", ts_utc = as.POSIXct("2020-01-02 21:00", tz = "UTC") + c(0, 0, 86400),
                    open = 1, high = 1, low = 1, close = 1, volume = 1)
  closed <- dup[-2L, ]
  closed$ts_utc[[2L]] <- as.POSIXct("2020-01-04 21:00", tz = "UTC")
  closed_sessions <- ledgr_facts(ledgr_facts_sessions(
    data.frame(session_date = as.Date(c("2020-01-02", "2020-01-03", "2020-01-04")), status = c("open", "open", "closed"),
               session_open = c("14:30:00", "14:30:00", NA), session_close = c("21:00:00", "21:00:00", NA)),
    venue_id = "V", knowledge = "assume_effective"))
  q <- tryCatch(ledgr_snapshot_from_df(closed, db_path = tempfile(fileext = ".duckdb"), facts = closed_sessions),
                error = function(e) e)
  quarantine <- if (inherits(q, "error")) paste(class(q), collapse = "|") else
    nrow(DBI::dbGetQuery(get_connection(q), "SELECT * FROM snapshot_observation_quarantine"))
  family("refusals", data.frame(
    case = c("duplicate_bar", "bar_on_closed_session"),
    outcome = c(cls(ledgr_snapshot_from_df(dup, db_path = tempfile(fileext = ".duckdb"))), as.character(quarantine))
  ))
}

experiment <- function(strategy, features = list()) {
  ledgr_experiment(snapshot, strategy, features = features, universe = ledgr_universe_members(universe),
                   valuation_policy = ledgr_valuation_stale(5), cost_model = ledgr_cost_zero(),
                   opening = ledgr_opening(cash = 1e6))
}
run_families <- function(tag, bt) {
  for (w in c("equity", "returns", "fills", "trades", "ledger", "diagnostics")) family(paste0(tag, "_", w), ledgr_results(bt, w))
  run_info <- unclass(ledgr_run_info(snapshot, bt$run_id))
  note_identity(paste0(tag, "_config_hash"), run_info$config_hash)
  note_identity(paste0(tag, "_feature_set_hash"), run_info$feature_set_hash)
  run_info <- run_info[!grepl(drop_cols, names(run_info)) &
                         !names(run_info) %in% c("config_hash", "feature_set_hash", "strategy_source_hash")]
  family(paste0(tag, "_run_info"), s3list(run_info))
  family(paste0(tag, "_completion"), DBI::dbGetQuery(con, "SELECT * FROM run_completion WHERE run_id = ?", params = list(bt$run_id)))
  family(paste0(tag, "_metrics"), ledgr_compute_metrics(bt))
  family(paste0(tag, "_valuation_summary"), ledgr_valuation_summary(bt))
  family(paste0(tag, "_ca_summary"), s3list(ledgr_corporate_action_summary(bt)))
  family(paste0(tag, "_features"), DBI::dbGetQuery(con, "SELECT * FROM features WHERE run_id = ? ORDER BY ALL", params = list(bt$run_id)))
  family(paste0(tag, "_strategy_state"), DBI::dbGetQuery(con, "SELECT ts_utc, state_json FROM strategy_state WHERE run_id = ? ORDER BY ts_utc", params = list(bt$run_id)))
}

if (want("run_momentum")) {
  mom <- in_phase("run_momentum", ledgr_run(experiment(scale_momentum, list(mom_feature)), params = mom_params, run_id = "scale-momentum"))
  in_phase("readers", run_families("momentum", mom))
  if (want("availability")) in_phase("availability", family("momentum_availability", ledgr_results(mom, "availability")))
  if (want("explain")) {
    fills <- ledgr_results(mom, "fills")
    picks <- unique(fills$instrument_id)[[1L]]
    in_phase("explain", family("momentum_explain", do.call(rbind, lapply(picks, function(id) {
      as.data.frame(ledgr_run_explain(mom, id))
    }))))
  }
}
if (want("run_equal_weight")) {
  ew <- in_phase("run_equal_weight", ledgr_run(experiment(scale_equal_weight), params = list(f = 0.95), run_id = "scale-equal-weight"))
  in_phase("readers", run_families("equal_weight", ew))
}
if (want("dense") && identical(lane, "fixture")) {
  dense <- scale_fixture_dense_snapshot(file.path(work, "dense.duckdb"))
  dbt <- in_phase("dense", ledgr_run(ledgr_experiment(dense, function(ctx, params) {
    target <- ctx$flat(); target[ctx$universe[1:5]] <- 10; target
  }, cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e5)), run_id = "scale-dense"))
  family("dense_equity", ledgr_results(dbt, "equity"))
  family("dense_availability", ledgr_results(dbt, "availability"))
  family("dense_metrics", ledgr_compute_metrics(dbt))
}

# Sweep: three equal-weight candidates; every candidate holds the dividend
# payers, so each must post through its own corporate-action state.
if (want("sweep") || want("promote")) {
  sw <- in_phase("sweep", ledgr_sweep(experiment(scale_equal_weight), ledgr_strategy_grid(f = c(0.9, 0.95, 0.99)),
                                      retain = ledgr_sweep_retention("completed", "closed"), seed = 1L))
  note_identity("sweep_feature_engine_version", attr(sw, "feature_engine_version"))
  note_identity("sweep_strategy_hash", attr(sw, "strategy_hash"))
  family("sweep_rows", sw[, setdiff(names(sw), c("provenance", "feature_fingerprints")), drop = FALSE])
  family("sweep_returns", ledgr_sweep_returns(sw))
  family("sweep_trades", ledgr_sweep_trades(sw))
  if (want("promote")) {
    pr <- in_phase("promote", ledgr_promote(experiment(scale_equal_weight), ledgr_candidate(sw, 2L), run_id = "scale-promoted"))
    for (w in c("equity", "fills", "ledger")) family(paste0("promoted_", w), ledgr_results(pr, w))
  }
}
if (want("walk_forward")) {
  starts <- if (identical(lane, "fixture")) c(info$start_date, info$end_date) else c("1998-01-02", "2026-09-04")
  # Contiguous rolling folds; a short test instance uses shorter windows.
  short <- identical(lane, "fixture") && size[[2L]] < 1000L
  test_window <- if (short) "2 months" else "1 year"
  folds <- ledgr_folds_rolling(substr(starts[[1L]], 1L, 10L), substr(starts[[2L]], 1L, 10L),
                               train_window = if (short) "4 months" else "2 years",
                               test_window = test_window, step = test_window)
  wf <- in_phase("walk_forward", ledgr_walk_forward(experiment(scale_momentum, list(mom_feature)),
                                                    ledgr_strategy_grid(lookback = mom_params$lookback, n = c(10L, 20L)),
                                                    folds, ledgr_rule_argmax("sharpe_ratio"), seed = 1L))
  note_identity("wf_session_id", wf$session_id)
  family("wf_folds", wf$folds[, setdiff(names(wf$folds), "session_id"), drop = FALSE])
  family("wf_scores", wf$scores[, setdiff(names(wf$scores), "session_id"), drop = FALSE])
}

family("identity", data.frame(key = names(identity), value = unlist(identity), stringsAsFactors = FALSE))
utils::write.csv(data.frame(
  key = c("commit", "lane", "size", "phases", "R", "recorded_at"),
  value = c(git("rev-parse", "HEAD"), lane, paste(size, collapse = ","), paste(phases, collapse = ","),
            R.version.string, format(Sys.time(), tz = "UTC"))
), file.path(out_dir, "meta.csv"), row.names = FALSE)
ledgr_snapshot_close(snapshot)
cat("RECORD_OK", out_dir, "\n")
