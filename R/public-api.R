ledgr_open_duckdb_with_retry <- function(db_path, attempts = 50L, sleep_s = 0.05) {
  attempts <- as.integer(attempts)
  if (attempts < 1L) attempts <- 1L

  last_err <- NULL
  for (i in seq_len(attempts)) {
    drv <- duckdb::duckdb()
    out <- tryCatch(
      {
        con <- DBI::dbConnect(drv, dbdir = db_path)
        list(con = con, drv = drv)
      },
      error = function(e) {
        last_err <<- e
        try(duckdb::duckdb_shutdown(drv), silent = TRUE)
        NULL
      }
    )
    if (!is.null(out)) return(out)
    gc()
    Sys.sleep(sleep_s)
  }
  stop(last_err)
}

ledgr_checkpoint_duckdb <- function(con) {
  if (!is.null(con) && DBI::dbIsValid(con)) {
    suppressWarnings(try(DBI::dbExecute(con, "CHECKPOINT"), silent = TRUE))
  }
  invisible(TRUE)
}

#' Initialize or open a ledgr DuckDB database (v0.1.0)
#'
#' Opens a DuckDB database at `db_path`, creates the v0.1.0 schema if needed,
#' and validates it.
#'
#' @param db_path Path to a DuckDB database file (or `":memory:"`).
#' @return A DBI connection.
#' @examples
#' db_path <- tempfile(fileext = ".duckdb")
#' con <- ledgr_db_init(db_path)
#' ledgr_validate_schema(con)
#' DBI::dbDisconnect(con, shutdown = TRUE)
#' @export
ledgr_db_init <- function(db_path) {
  if (!is.character(db_path) || length(db_path) != 1 || is.na(db_path) || !nzchar(db_path)) {
    rlang::abort("`db_path` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  opened <- ledgr_open_duckdb_with_retry(db_path)
  con <- opened$con
  drv <- opened$drv
  attr(con, "ledgr_duckdb_drv") <- drv

  ledgr_create_schema(con)
  ledgr_validate_schema(con)
  con
}

#' Reconstruct derived state for a run (v0.1.0)
#'
#' Rebuilds derived tables from the event-sourced ledger and bars, and returns
#' the reconstructed state artifacts.
#'
#' @param run_id Run identifier.
#' @param con A DBI connection to DuckDB.
#' @return A list with `positions`, `cash`, `pnl`, and `equity_curve`.
#' @details
#' This is the low-level reconstruction API. User-facing helpers such as
#' `ledgr_compute_equity_curve()` and `as_tibble(bt, what = "equity")`
#' delegate to the same ledger-derived state model without requiring users to
#' manage a raw DBI connection.
#'
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102, 103),
#'   high = c(101, 102, 103, 104),
#'   low = c(99, 100, 101, 102),
#'   close = c(100, 101, 102, 103),
#'   volume = 1000
#' )
#' strategy <- function(ctx) {
#'   targets <- ctx$targets()
#'   targets["AAA"] <- 1
#'   targets
#' }
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000)
#' tibble::as_tibble(bt, what = "equity")
#'
#' # Low-level reconstruction requires an explicit DBI connection.
#' con <- ledgr_db_init(bt$db_path)
#' state <- ledgr_state_reconstruct(bt$run_id, con)
#' state$positions
#' DBI::dbDisconnect(con, shutdown = TRUE)
#' close(bt)
#' @export
ledgr_state_reconstruct <- function(run_id, con) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  if (!is.character(run_id) || length(run_id) != 1 || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  row <- DBI::dbGetQuery(con, "SELECT config_json FROM runs WHERE run_id = ?", params = list(run_id))
  if (nrow(row) != 1) {
    rlang::abort(sprintf("run_id not found in runs table: %s", run_id), class = "ledgr_invalid_args")
  }
  if (is.null(row$config_json[[1]]) || is.na(row$config_json[[1]]) || !nzchar(row$config_json[[1]])) {
    rlang::abort("runs.config_json is required for reconstruction.", class = "ledgr_invalid_run")
  }

  cfg <- jsonlite::fromJSON(row$config_json[[1]], simplifyVector = TRUE, simplifyDataFrame = FALSE, simplifyMatrix = FALSE)
  universe <- cfg$universe$instrument_ids
  initial_cash <- cfg$backtest$initial_cash
  if (!is.numeric(initial_cash) || length(initial_cash) != 1 || is.na(initial_cash) || !is.finite(initial_cash)) {
    rlang::abort("runs.config_json must include backtest.initial_cash as a finite numeric scalar.", class = "ledgr_invalid_run")
  }
  if (!is.character(universe) || length(universe) < 1 || anyNA(universe) || any(!nzchar(universe))) {
    rlang::abort("runs.config_json must include universe.instrument_ids as a non-empty character vector.", class = "ledgr_invalid_run")
  }

  rebuilt <- ledgr_rebuild_derived_state(con, run_id, as.numeric(initial_cash))

  eq <- rebuilt$equity_curve
  if (nrow(eq) > 0) {
    eq$ts_utc <- vapply(eq$ts_utc, ledgr_normalize_ts_utc, character(1))
    eq$cash <- as.numeric(eq$cash)
    eq$positions_value <- as.numeric(eq$positions_value)
    eq$equity <- as.numeric(eq$equity)
    eq$realized_pnl <- as.numeric(eq$realized_pnl)
    eq$unrealized_pnl <- as.numeric(eq$unrealized_pnl)
  }
  eq <- eq[, c("ts_utc", "cash", "positions_value", "equity", "realized_pnl", "unrealized_pnl"), drop = FALSE]

  pos <- rebuilt$positions
  pos_all <- stats::setNames(rep(0, length(universe)), universe)
  if (length(pos) > 0) {
    pos_all[names(pos)] <- as.numeric(pos)
  }

  list(
    positions = data.frame(
      instrument_id = universe,
      qty = as.numeric(pos_all),
      stringsAsFactors = FALSE
    ),
    cash = eq[, c("ts_utc", "cash")],
    pnl = eq[, c("ts_utc", "realized_pnl", "unrealized_pnl")],
    equity_curve = eq
  )
}
