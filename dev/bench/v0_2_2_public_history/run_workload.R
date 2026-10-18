# Workstream 42 scale workloads (Cut 16 LDG-3062..3064).
#
#   Rscript run_workload.R <repo> <db_path> <workload> <out_csv> [--build]
#     [--size=n_inst,n_days,n_mem,n_sets] [--folds=n] [--label=tree]
#
# Loads <repo> with pkgload (compiled once beforehand), optionally builds the
# fixture snapshot at <db_path>, runs one workload and appends one CSV row:
# workload, repo commit, elapsed seconds, R heap peak MB (gc "max used"
# Vcells + Ncells since the workload started) and a workload-specific note.
# Workloads: build, run_plain, run_history, inspect, precompute, sweep,
# walk_forward. History workloads exist only on trees that expose
# ledgr_history_frame(). One workload per process; no tests run alongside.

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[length(hit)]]) else default
}
repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
db_path <- args[[2L]]
workload <- args[[3L]]
out_csv <- args[[4L]]
size <- as.integer(strsplit(opt("size", "1166,7213,600,580"), ",", fixed = TRUE)[[1L]])
n_folds <- as.integer(opt("folds", "16"))

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all(repo, quiet = TRUE))
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
source(file.path(here, "fixture.R"))

commit <- tryCatch(
  system2("git", c("-C", shQuote(repo), "rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE),
  error = function(e) NA_character_
)
if (length(commit) == 0L) commit <- basename(repo)
commit <- opt("label", commit[[1L]])

record <- function(elapsed, peak, note = "") {
  row <- data.frame(
    workload = workload, tree = commit[[1L]], n_inst = size[[1L]], n_days = size[[2L]],
    elapsed_seconds = round(elapsed, 3), heap_peak_mb = round(peak, 1), note = note,
    stringsAsFactors = FALSE
  )
  utils::write.table(row, out_csv, sep = ",", row.names = FALSE,
                     col.names = !file.exists(out_csv), append = file.exists(out_csv))
  print(row)
}
measure <- function(expr) {
  invisible(gc(reset = TRUE))
  base <- sum(gc()[, 2L])
  t0 <- Sys.time()
  value <- force(expr)
  elapsed <- as.numeric(Sys.time() - t0, units = "secs")
  peak <- sum(gc()[, 6L]) - base
  list(value = value, elapsed = elapsed, peak = peak)
}

if (identical(workload, "build")) {
  if (file.exists(db_path)) unlink(db_path)
  m <- measure(public_history_snapshot(db_path, size[[1L]], size[[2L]], size[[3L]], size[[4L]]))
  ledgr_snapshot_close(m$value)
  record(m$elapsed, m$peak, "snapshot build and seal")
  quit(save = "no")
}

snapshot <- ledgr_snapshot_open(db_path, "public-history-scale")
experiment <- function(strategy) {
  ledgr_experiment(
    snapshot, strategy, universe = ledgr_universe_members("U"),
    valuation_policy = ledgr_valuation_stale(5), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1e6)
  )
}

if (identical(workload, "run_plain")) {
  exp <- experiment(public_history_equal_weight)
  m <- measure(ledgr_run(exp, params = list(f = 0.95), run_id = paste0("plain-", Sys.getpid())))
  eq <- ledgr_results(m$value, "equity")
  record(m$elapsed, m$peak, sprintf("final_equity=%.4f rows=%d", eq$equity[[nrow(eq)]], nrow(eq)))
} else if (identical(workload, "run_history")) {
  exp <- experiment(public_history_reader)
  m <- measure(ledgr_run(exp, params = list(f = 0.95), run_id = paste0("history-", Sys.getpid())))
  eq <- ledgr_results(m$value, "equity")
  record(m$elapsed, m$peak, sprintf("final_equity=%.4f rows=%d", eq$equity[[nrow(eq)]], nrow(eq)))
} else if (identical(workload, "inspect")) {
  exp <- experiment(public_history_equal_weight)
  axis <- public_history_dates(size[[2L]])
  cutoffs <- as.POSIXct(paste(axis[as.integer(round(c(0.25, 0.5, 0.99) * length(axis)))], "21:00:00"), tz = "UTC")
  m <- measure(lapply(cutoffs, function(cutoff) {
    ctx <- ledgr_pulse_snapshot(exp, ts_utc = cutoff, params = list(f = 0.95))
    ledgr_history_frame(ctx, bar = "close", lookback = 252L)
  }))
  record(m$elapsed, m$peak, sprintf("three cutoffs; last frame %dx%d", nrow(m$value[[3L]]), ncol(m$value[[3L]])))
} else if (identical(workload, "precompute")) {
  exp <- ledgr_experiment(
    snapshot, public_history_equal_weight, universe = ledgr_universe_members("U"),
    features = function(params) list(ledgr_ind_returns(params$n)),
    valuation_policy = ledgr_valuation_stale(5), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1e6)
  )
  grid <- ledgr_param_grid(list(f = 0.9, n = 20L), list(f = 0.95, n = 60L))
  m <- measure(ledgr_precompute_features(exp, grid))
  record(m$elapsed, m$peak, sprintf("features=%d", nrow(m$value$feature_union)))
} else if (identical(workload, "sweep")) {
  exp <- experiment(public_history_equal_weight)
  grid <- ledgr_param_grid(list(f = 0.8), list(f = 0.9), list(f = 0.95))
  m <- measure(ledgr_sweep(exp, grid))
  record(m$elapsed, m$peak, sprintf("final_equity=%s", paste(round(m$value$final_equity, 4), collapse = "/")))
} else if (identical(workload, "walk_forward")) {
  exp <- experiment(public_history_equal_weight)
  axis <- public_history_dates(size[[2L]])
  utc <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  first_test <- as.integer(round(0.4 * length(axis)))
  test_len <- floor((length(axis) - first_test) / n_folds)
  folds <- lapply(seq_len(n_folds), function(k) {
    test_start <- first_test + (k - 1L) * test_len + 1L
    test_end <- test_start + test_len - 1L
    ledgr_fold(utc(axis[[max(1L, test_start - 250L)]]), utc(axis[[test_start - 1L]]),
               utc(axis[[test_start]]), utc(axis[[test_end]]), fold_seq = k)
  })
  folds <- ledgr:::ledgr_fold_list(folds, constructor = list(type_id = "explicit"))
  grid <- ledgr_param_grid(list(f = 0.9), list(f = 0.95))
  m <- measure(suppressWarnings(ledgr_walk_forward(
    exp, grid, folds, selection_rule = ledgr_rule_argmax("annualized_return"), seed = 1L
  )))
  finals <- vapply(m$value$test_runs, function(bt) {
    eq <- if (inherits(bt, "ledgr_backtest")) ledgr_results(bt, "equity") else NULL
    if (is.null(eq) || nrow(eq) == 0L) NA_real_ else eq$equity[[nrow(eq)]]
  }, numeric(1))
  status <- table(as.character(m$value$folds$status))
  record(m$elapsed, m$peak, sprintf(
    "folds=%d status=%s test_runs_with_equity=%d last_final=%.4f", n_folds,
    paste(names(status), status, sep = ":", collapse = "/"), sum(!is.na(finals)),
    finals[[length(finals)]]
  ))
} else {
  stop("Unknown workload: ", workload, call. = FALSE)
}
ledgr_snapshot_close(snapshot)
