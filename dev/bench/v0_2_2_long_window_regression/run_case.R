args <- commandArgs(TRUE)
if (length(args) != 4L) {
  stop("Usage: run_case.R <repo> <fixture_db> <shape_id> <out_json>")
}
repo <- normalizePath(args[[1L]], winslash = "/")
fixture_db <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
shape_id <- args[[3L]]
out_json <- args[[4L]]
script <- dirname(normalizePath(sub("^--file=", "", grep(
  "^--file=", commandArgs(FALSE), value = TRUE
)[[1L]]), winslash = "/"))
source(file.path(script, "helpers.R"), local = TRUE)
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))

row <- lwreg_shape(shape_id, script)
work_db <- tempfile(fileext = ".duckdb")
if (!file.copy(fixture_db, work_db, overwrite = TRUE)) {
  stop("Could not copy fixture database")
}
on.exit(unlink(c(work_db, paste0(work_db, ".wal"))), add = TRUE)
snapshot <- ledgr_snapshot_open(work_db)
on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

run_once <- function(label) {
  timing <- new.env(parent = emptyenv())
  timing$first <- NULL
  timing$last <- NULL
  timing$calls <- 0L
  exp <- lwreg_experiment(snapshot, row, timing)
  start <- proc.time()[["elapsed"]]
  bt <- ledgr_run(
    exp,
    run_id = sprintf("lwreg_%s_%s_%s", shape_id, label, Sys.getpid())
  )
  elapsed <- proc.time()[["elapsed"]] - start
  on.exit(close(bt), add = TRUE)
  info <- ledgr_run_info(snapshot, bt$run_id)
  list(
    status = info$status,
    elapsed_s = elapsed,
    setup_s = if (is.null(timing$first)) NA_real_ else timing$first - start,
    loop_s = if (is.null(timing$first)) NA_real_ else timing$last - timing$first,
    finalize_s = if (is.null(timing$last)) NA_real_ else {
      start + elapsed - timing$last
    },
    strategy_calls = timing$calls,
    identities = lwreg_run_identities(bt)
  )
}

sweep_once <- function() {
  timing <- new.env(parent = emptyenv())
  timing$first <- NULL
  timing$last <- NULL
  timing$calls <- 0L
  exp <- lwreg_experiment(snapshot, row, timing)
  grid <- ledgr_param_grid(
    first = list(variant = 1L),
    second = list(variant = 2L)
  )
  measured <- lwreg_elapsed(ledgr_sweep(
    exp,
    grid,
    seed = 1L,
    workers = 1L,
    stop_on_error = TRUE,
    retain = ledgr_sweep_retention(returns = "completed")
  ))
  list(
    status = paste(measured$value$status, collapse = "+"),
    elapsed_s = measured$seconds,
    strategy_calls = timing$calls,
    identities = lwreg_sweep_identity(measured$value)
  )
}

walk_forward_once <- function() {
  timing <- new.env(parent = emptyenv())
  timing$first <- NULL
  timing$last <- NULL
  timing$calls <- 0L
  exp <- lwreg_experiment(snapshot, row, timing)
  probe <- jsonlite::read_json(file.path(
    dirname(fixture_db), "fixture_probe.json"
  ))
  folds <- ledgr_folds_rolling(
    start = probe$first_session,
    end = probe$last_session,
    train_window = "12 months",
    test_window = "3 months",
    step = "3 months"
  )
  measured <- lwreg_elapsed(ledgr_walk_forward(
    exp,
    ledgr_param_grid(first = list(variant = 1L),
                     second = list(variant = 2L)),
    folds,
    ledgr_rule_argmax("sharpe_ratio"),
    seed = 1L
  ))
  on.exit(lapply(measured$value$test_runs, close), add = TRUE)
  list(
    status = measured$value$status,
    elapsed_s = measured$seconds,
    strategy_calls = timing$calls,
    identities = list(
      folds = lwreg_identity(measured$value$folds),
      scores = lwreg_identity(measured$value$scores),
      selected = lwreg_identity(measured$value$selected),
      degradation = lwreg_identity(measured$value$degradation)
    )
  )
}

if (identical(row$mode, "run") || identical(row$mode, "run_resolve")) {
  ledgr_feature_cache_clear()
  cold <- run_once("cold")
  warm <- run_once("warm")
  resolve <- NULL
  if (identical(row$mode, "run_resolve")) {
    at <- paste0(jsonlite::read_json(
      file.path(dirname(fixture_db), "fixture_probe.json")
    )$last_session, "T21:00:00Z")
    first <- lwreg_elapsed(ledgr_facts_resolve(
      snapshot, "membership", "synthetic_members", at = at
    ))
    second <- lwreg_elapsed(ledgr_facts_resolve(
      snapshot, "membership", "synthetic_members", at = at
    ))
    resolve <- list(
      cold_s = first$seconds,
      warm_s = second$seconds,
      cold = lwreg_resolution_identity(first$value),
      warm = lwreg_resolution_identity(second$value)
    )
  }
} else if (identical(row$mode, "sweep")) {
  ledgr_feature_cache_clear()
  cold <- sweep_once()
  warm <- sweep_once()
  resolve <- NULL
} else if (identical(row$mode, "walk_forward")) {
  ledgr_feature_cache_clear()
  cold <- walk_forward_once()
  warm <- walk_forward_once()
  resolve <- NULL
} else {
  stop("run_case.R does not execute mode: ", row$mode)
}

commit <- trimws(system2("git", c("-C", repo, "rev-parse", "HEAD"),
                         stdout = TRUE))
out <- list(
  shape_id = shape_id,
  commit = commit,
  package_version = as.character(utils::packageVersion("ledgr")),
  r_version = paste(R.version$major, R.version$minor, sep = "."),
  duckdb_version = as.character(utils::packageVersion("duckdb")),
  collapse_version = as.character(utils::packageVersion("collapse")),
  snapshot = lwreg_snapshot_info(snapshot),
  cold = cold,
  warm = warm,
  facts_resolve = resolve
)
dir.create(dirname(out_json), recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(out, out_json, auto_unbox = TRUE, pretty = TRUE,
                     null = "null", digits = 16)
