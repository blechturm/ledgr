memory_script_dir <- function() {
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (!length(file_arg)) return(normalizePath(getwd(), winslash = "/"))
  dirname(normalizePath(sub("^--file=", "", file_arg[[1L]]), winslash = "/"))
}

memory_repo_helper <- function(script_dir = memory_script_dir()) {
  normalizePath(
    file.path(script_dir, "..", "v0_2_2_long_window_regression", "helpers.R"),
    winslash = "/", mustWork = TRUE
  )
}

source(memory_repo_helper(), local = TRUE)

memory_manifest <- function(script_dir = memory_script_dir()) {
  utils::read.csv(file.path(script_dir, "manifest.csv"),
                  stringsAsFactors = FALSE, check.names = FALSE)
}

memory_fixture_row <- function() {
  row <- memory_manifest()[1L, , drop = FALSE]
  data.frame(
    shape_id = row$shape_id, profile = "ordinary", mode = "run",
    sessions = row$sessions, instruments = row$instruments,
    members = row$members, sets = row$sets, churn = row$churn,
    terminals = 0L, terminal_ownership = "none", gap_pattern = "none",
    stale_budget = 2L, features = row$features, strategy = row$strategy,
    expected_status = row$expected_status, stringsAsFactors = FALSE
  )
}

memory_experiment <- function(snapshot, persist_features, availability = TRUE,
                              timing = NULL) {
  row <- memory_fixture_row()
  if (is.null(timing)) {
    timing <- new.env(parent = emptyenv())
    timing$first <- NULL
    timing$last <- NULL
    timing$calls <- 0L
  }
  args <- list(
    snapshot = snapshot,
    strategy = lwreg_strategy(row$strategy, timing),
    features = lwreg_features(row$features),
    opening = ledgr_opening(cash = 1e6),
    cost_model = ledgr_cost_zero(),
    persist_features = isTRUE(persist_features)
  )
  if (isTRUE(availability)) {
    args$universe <- ledgr_universe_members("synthetic_members")
    args$valuation_policy <- ledgr_valuation_stale(2L)
  }
  do.call(ledgr_experiment, args)
}

memory_table_identity <- function(bt, table, order_by) {
  con <- DBI::dbConnect(duckdb::duckdb(), bt$db_path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  rows <- DBI::dbGetQuery(
    con,
    paste0("SELECT * FROM ", table, " WHERE run_id = ? ORDER BY ", order_by),
    params = list(bt$run_id)
  )
  lwreg_identity(rows)
}

memory_run_identities <- function(bt, persist_features) {
  identities <- lwreg_run_identities(bt)
  identities$availability <- lwreg_identity(
    tibble::as_tibble(bt, what = "availability")
  )
  identities$features <- if (isTRUE(persist_features)) {
    memory_table_identity(bt, "features", "instrument_id, ts_utc, feature_name")
  } else {
    list(rows = 0L, hash = lwreg_hash(data.frame()))
  }
  identities
}

memory_phase_markers <- function(ns) {
  steps <- vapply(as.list(body(ns$ledgr_run_fold_impl)), function(step) {
    paste(deparse(step, width.cutoff = 500L), collapse = "\n")
  }, character(1L))
  find_one <- function(pattern) {
    hit <- which(grepl(pattern, steps, fixed = TRUE))
    if (length(hit) != 1L) {
      stop("Phase marker is not unique: ", pattern, " (", length(hit), ")")
    }
    hit
  }
  c(
    hydration = find_one("raw_bars_by_id <- split(bars_all"),
    features = find_one("run_feature_series <- list()"),
    setup = find_one("strategy <- ledgr_strategy_from_config(cfg)"),
    fold = find_one("fold_result <- tryCatch("),
    finalize = find_one("finalized <- ledgr_run_finalize(")
  )
}

memory_product_status <- function(repo) lwreg_product_tree_status(repo)
memory_git_commit <- function(repo) lwreg_git_commit(repo)
