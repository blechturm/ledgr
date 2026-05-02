ledgr_run_store_open <- function(db_path) {
  if (!is.character(db_path) || length(db_path) != 1 || is.na(db_path) || !nzchar(db_path)) {
    rlang::abort("`db_path` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (identical(db_path, ":memory:")) {
    rlang::abort("`db_path` cannot be ':memory:' for experiment-store discovery.", class = "ledgr_invalid_args")
  }
  if (!file.exists(db_path)) {
    rlang::abort(sprintf("DuckDB file does not exist: %s", db_path), class = "ledgr_db_not_found")
  }

  opened <- ledgr_open_duckdb_with_retry(db_path)
  attr(opened$con, "ledgr_duckdb_drv") <- opened$drv
  opened
}

ledgr_run_store_snapshot_path <- function(snapshot, arg = "snapshot") {
  if (!inherits(snapshot, "ledgr_snapshot")) {
    if (is.character(snapshot) && length(snapshot) == 1L && !is.na(snapshot) && nzchar(snapshot)) {
      rlang::abort(
        sprintf(
          "`%s` must be a ledgr_snapshot object in v0.1.7. Resume from a DuckDB file with ledgr_snapshot_load(db_path, snapshot_id), then call this API with the snapshot.",
          arg
        ),
        class = "ledgr_snapshot_required"
      )
    }
    rlang::abort(
      sprintf("`%s` must be a ledgr_snapshot object.", arg),
      class = "ledgr_invalid_args"
    )
  }
  db_path <- snapshot$db_path
  if (!is.character(db_path) || length(db_path) != 1L || is.na(db_path) || !nzchar(db_path)) {
    rlang::abort("`snapshot$db_path` must be a non-empty character scalar.", class = "ledgr_invalid_snapshot")
  }
  if (!is.character(snapshot$snapshot_id) || length(snapshot$snapshot_id) != 1L ||
    is.na(snapshot$snapshot_id) || !nzchar(snapshot$snapshot_id)) {
    rlang::abort("`snapshot$snapshot_id` must be a non-empty character scalar.", class = "ledgr_invalid_snapshot")
  }
  if (identical(db_path, ":memory:")) {
    rlang::abort(
      "Snapshot-first experiment-store APIs require a durable DuckDB file, not ':memory:'.",
      class = "ledgr_invalid_snapshot"
    )
  }
  db_path
}

ledgr_run_store_snapshot_id <- function(snapshot) {
  snapshot$snapshot_id
}

ledgr_run_store_close <- function(opened) {
  if (is.list(opened) && !is.null(opened$con) && DBI::dbIsValid(opened$con)) {
    ledgr_checkpoint_duckdb(opened$con)
    suppressWarnings(try(DBI::dbDisconnect(opened$con, shutdown = FALSE), silent = TRUE))
  }
  if (is.list(opened) && !is.null(opened$drv)) {
    suppressWarnings(try(duckdb::duckdb_shutdown(opened$drv), silent = TRUE))
  }
  invisible(TRUE)
}

ledgr_run_store_has_col <- function(con, table_name, column_name) {
  ledgr_experiment_store_table_exists(con, table_name) &&
    column_name %in% ledgr_experiment_store_columns(con, table_name)
}

ledgr_run_store_optional_join <- function(con, table_name, alias, on_sql) {
  if (!ledgr_experiment_store_table_exists(con, table_name)) return("")
  sprintf("LEFT JOIN %s %s ON %s", table_name, alias, on_sql)
}

ledgr_run_store_fetch <- function(con, include_archived = FALSE, run_id = NULL, snapshot_id = NULL) {
  ledgr_experiment_store_check_schema(con, write = FALSE)
  if (!ledgr_experiment_store_table_exists(con, "runs")) {
    return(tibble::tibble())
  }

  runs_cols <- ledgr_experiment_store_columns(con, "runs")
  run_expr <- function(column, default = "NULL") {
    if (column %in% runs_cols) paste0("r.", column) else default
  }
  prov_expr <- function(column, default = "NULL") {
    if (ledgr_run_store_has_col(con, "run_provenance", column)) {
      sprintf("(SELECT p.%s FROM run_provenance p WHERE p.run_id = r.run_id LIMIT 1)", column)
    } else {
      default
    }
  }
  telem_expr <- function(column, default = "NULL") {
    if (ledgr_run_store_has_col(con, "run_telemetry", column)) paste0("t.", column) else default
  }
  snap_expr <- function(column, default = "NULL") {
    if (ledgr_run_store_has_col(con, "snapshots", column)) paste0("s.", column) else default
  }

  archived_expr <- run_expr("archived", "FALSE")
  quote_string <- function(x) {
    as.character(DBI::dbQuoteString(con, as.character(x)))
  }
  where <- character()
  if (!isTRUE(include_archived)) {
    where <- c(where, sprintf("COALESCE(%s, FALSE) = FALSE", archived_expr))
  }
  if (!is.null(run_id)) {
    where <- c(where, sprintf("r.run_id = %s", quote_string(run_id)))
  }
  if (!is.null(snapshot_id) && "snapshot_id" %in% runs_cols) {
    where <- c(where, sprintf("r.snapshot_id = %s", quote_string(snapshot_id)))
  }
  where_sql <- if (length(where) > 0L) paste("WHERE", paste(where, collapse = " AND ")) else ""

  telemetry_join <- ledgr_run_store_optional_join(con, "run_telemetry", "t", "t.run_id = r.run_id")
  snapshot_join <- ledgr_run_store_optional_join(con, "snapshots", "s", "s.snapshot_id = r.snapshot_id")
  tags_expr <- if (ledgr_experiment_store_table_exists(con, "run_tags")) {
    "(SELECT string_agg(rt.tag, ', ' ORDER BY rt.tag) FROM run_tags rt WHERE rt.run_id = r.run_id)"
  } else {
    "NULL"
  }
  equity_join <- if (ledgr_experiment_store_table_exists(con, "equity_curve")) {
    "
    LEFT JOIN (
      SELECT run_id,
             MAX(CASE WHEN rn_first = 1 THEN equity END) AS first_equity,
             MAX(CASE WHEN rn_last = 1 THEN equity END) AS final_equity,
             MIN(CASE
               WHEN running_max IS NULL OR running_max = 0 THEN NULL
               ELSE equity / running_max - 1
             END) AS max_drawdown
      FROM (
        SELECT run_id,
               equity,
               ROW_NUMBER() OVER (PARTITION BY run_id ORDER BY ts_utc ASC) AS rn_first,
               ROW_NUMBER() OVER (PARTITION BY run_id ORDER BY ts_utc DESC) AS rn_last,
               MAX(equity) OVER (
                 PARTITION BY run_id
                 ORDER BY ts_utc ASC
                 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
               ) AS running_max
        FROM equity_curve
      ) eq_ranked
      GROUP BY run_id
    ) eq ON eq.run_id = r.run_id
    "
  } else {
    "
    LEFT JOIN (
      SELECT
        CAST(NULL AS TEXT) AS run_id,
        CAST(NULL AS DOUBLE) AS first_equity,
        CAST(NULL AS DOUBLE) AS final_equity,
        CAST(NULL AS DOUBLE) AS max_drawdown
      WHERE FALSE
    ) eq ON eq.run_id = r.run_id
    "
  }
  trades_join <- if (ledgr_experiment_store_table_exists(con, "ledger_events")) {
    "
    LEFT JOIN (
      SELECT run_id, COUNT(*) AS n_trades
      FROM ledger_events
      WHERE event_type = 'FILL'
      GROUP BY run_id
    ) tr ON tr.run_id = r.run_id
    "
  } else {
    "
    LEFT JOIN (
      SELECT CAST(NULL AS TEXT) AS run_id, CAST(NULL AS INTEGER) AS n_trades
      WHERE FALSE
    ) tr ON tr.run_id = r.run_id
    "
  }

  sql <- sprintf(
    "
    SELECT
      r.run_id,
      %s AS label,
      %s AS snapshot_id,
      %s AS snapshot_hash,
      %s AS created_at_utc,
      %s AS status,
      COALESCE(%s, FALSE) AS archived,
      %s AS archived_at_utc,
      %s AS archive_reason,
      %s AS tags,
      COALESCE(%s, 'legacy') AS reproducibility_level,
      %s AS strategy_type,
      %s AS strategy_source_hash,
      %s AS strategy_source_capture_method,
      %s AS strategy_params_json,
      %s AS strategy_params_hash,
      %s AS ledgr_version,
      %s AS R_version,
      %s AS dependency_versions_json,
      %s AS config_hash,
      %s AS data_hash,
      COALESCE(%s, %s) AS execution_mode,
      %s AS elapsed_sec,
      %s AS pulse_count,
      %s AS persist_features,
      %s AS feature_cache_hits,
      %s AS feature_cache_misses,
      %s AS error_msg,
      eq.final_equity,
      eq.max_drawdown,
      CASE
        WHEN eq.first_equity IS NULL OR eq.first_equity = 0 THEN NULL
        ELSE eq.final_equity / eq.first_equity - 1
      END AS total_return,
      COALESCE(tr.n_trades, 0) AS n_trades,
      %s AS config_json,
      %s AS schema_version
    FROM runs r
    %s
    %s
    %s
    %s
    %s
    ORDER BY %s, r.run_id
    ",
    run_expr("label"),
    run_expr("snapshot_id"),
    snap_expr("snapshot_hash"),
    run_expr("created_at_utc"),
    run_expr("status"),
    archived_expr,
    run_expr("archived_at_utc"),
    run_expr("archive_reason"),
    tags_expr,
    prov_expr("reproducibility_level"),
    prov_expr("strategy_type"),
    prov_expr("strategy_source_hash"),
    prov_expr("strategy_source_capture_method"),
    prov_expr("strategy_params_json"),
    prov_expr("strategy_params_hash"),
    prov_expr("ledgr_version"),
    prov_expr("R_version"),
    prov_expr("dependency_versions_json"),
    run_expr("config_hash"),
    run_expr("data_hash"),
    telem_expr("execution_mode"),
    run_expr("execution_mode"),
    telem_expr("elapsed_sec"),
    telem_expr("pulse_count"),
    telem_expr("persist_features"),
    telem_expr("feature_cache_hits"),
    telem_expr("feature_cache_misses"),
    run_expr("error_msg"),
    run_expr("config_json"),
    run_expr("schema_version"),
    telemetry_join,
    snapshot_join,
    equity_join,
    trades_join,
    where_sql,
    run_expr("created_at_utc", "r.run_id")
  )

  out <- DBI::dbGetQuery(con, sql)
  if (nrow(out) == 0L) {
    return(tibble::as_tibble(out))
  }

  if ("created_at_utc" %in% names(out)) {
    out$created_at_utc <- vapply(out$created_at_utc, ledgr_run_store_format_ts, character(1))
  }
  if ("archived_at_utc" %in% names(out)) {
    out$archived_at_utc <- vapply(out$archived_at_utc, ledgr_run_store_format_ts, character(1))
  }
  if ("archived" %in% names(out)) out$archived <- as.logical(out$archived)
  if ("persist_features" %in% names(out)) out$persist_features <- as.logical(out$persist_features)
  if ("pulse_count" %in% names(out)) out$pulse_count <- as.integer(out$pulse_count)
  if ("n_trades" %in% names(out)) out$n_trades <- as.integer(out$n_trades)
  if ("n_trades" %in% names(out) && ledgr_experiment_store_table_exists(con, "ledger_events")) {
    trade_stats <- ledgr_compare_runs_fill_stats(con, unique(as.character(out$run_id)))
    trade_idx <- match(as.character(out$run_id), trade_stats$run_id)
    out$n_trades <- as.integer(trade_stats$n_trades[trade_idx])
    out$n_trades[is.na(out$n_trades)] <- 0L
  }
  tibble::as_tibble(out)
}

ledgr_run_store_format_ts <- function(x) {
  if (is.null(x) || length(x) != 1L || is.na(x)) return(NA_character_)
  ledgr_normalize_ts_utc(x)
}

ledgr_run_store_normalize_optional_text <- function(x, arg) {
  if (is.null(x)) {
    return(NA_character_)
  }
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    rlang::abort(sprintf("`%s` must be NULL or a character scalar.", arg), class = "ledgr_invalid_args")
  }
  if (!nzchar(x)) {
    return(NA_character_)
  }
  x
}

ledgr_run_store_assert_run_exists <- function(con, run_id, snapshot_id = NULL) {
  if (!ledgr_experiment_store_table_exists(con, "runs")) {
    rlang::abort(sprintf("Run not found: %s", run_id), class = "ledgr_run_not_found")
  }
  runs_cols <- ledgr_experiment_store_columns(con, "runs")
  where <- "run_id = ?"
  params <- list(run_id)
  if (!is.null(snapshot_id) && "snapshot_id" %in% runs_cols) {
    where <- paste(where, "AND snapshot_id = ?")
    params <- c(params, list(snapshot_id))
  }
  row <- DBI::dbGetQuery(
    con,
    paste("SELECT run_id FROM runs WHERE", where),
    params = params
  )
  if (nrow(row) != 1L) {
    rlang::abort(sprintf("Run not found: %s", run_id), class = "ledgr_run_not_found")
  }
  invisible(TRUE)
}

ledgr_compare_runs_fill_stats <- function(con, run_ids) {
  empty <- tibble::tibble(
    run_id = run_ids,
    n_trades = rep(0L, length(run_ids)),
    win_rate = rep(NA_real_, length(run_ids))
  )
  if (length(run_ids) == 0L || !ledgr_experiment_store_table_exists(con, "ledger_events")) {
    return(empty)
  }

  placeholders <- paste(rep("?", length(run_ids)), collapse = ", ")
  rows <- DBI::dbGetQuery(
    con,
    sprintf(
      "
      SELECT run_id, event_seq, instrument_id, side, qty, price
      FROM ledger_events
      WHERE run_id IN (%s) AND event_type IN ('FILL', 'FILL_PARTIAL')
      ORDER BY run_id, event_seq
      ",
      placeholders
    ),
    params = as.list(run_ids)
  )
  if (nrow(rows) == 0L) {
    return(empty)
  }

  stats <- lapply(run_ids, function(run_id) {
    run_rows <- rows[rows$run_id == run_id, , drop = FALSE]
    if (nrow(run_rows) == 0L) {
      return(data.frame(run_id = run_id, n_trades = 0L, win_rate = NA_real_, stringsAsFactors = FALSE))
    }

    fifo <- new.env(parent = emptyenv())
    realized <- numeric(0)

    for (i in seq_len(nrow(run_rows))) {
      inst <- as.character(run_rows$instrument_id[[i]])
      side_norm <- toupper(as.character(run_rows$side[[i]]))
      qty <- suppressWarnings(as.numeric(run_rows$qty[[i]]))
      price <- suppressWarnings(as.numeric(run_rows$price[[i]]))
      if (is.na(qty) || qty <= 0 || is.na(price)) {
        next
      }
      if (side_norm %in% c("BUY", "COVER", "BUY_TO_COVER")) {
        direction <- 1L
      } else if (side_norm %in% c("SELL", "SHORT", "SELL_SHORT")) {
        direction <- -1L
      } else {
        next
      }

      lots <- if (exists(inst, envir = fifo, inherits = FALSE)) {
        get(inst, envir = fifo, inherits = FALSE)
      } else {
        data.frame(qty = numeric(), price = numeric(), stringsAsFactors = FALSE)
      }

      net_pos <- if (nrow(lots) > 0L) sum(lots$qty) else 0
      close_qty <- 0
      if (direction > 0L && net_pos < 0) {
        close_qty <- min(qty, abs(net_pos))
      } else if (direction < 0L && net_pos > 0) {
        close_qty <- min(qty, net_pos)
      }
      open_qty <- qty - close_qty

      if (close_qty > 0) {
        remaining_close <- close_qty
        realized_close <- 0
        compensation <- 0
        if (direction > 0L) {
          while (remaining_close > 0 && nrow(lots) > 0 && lots$qty[[1]] < 0) {
            cover_qty <- min(remaining_close, abs(lots$qty[[1]]))
            delta <- (lots$price[[1]] - price) * cover_qty
            y <- delta - compensation
            t <- realized_close + y
            compensation <- (t - realized_close) - y
            realized_close <- t
            lots$qty[[1]] <- lots$qty[[1]] + cover_qty
            remaining_close <- remaining_close - cover_qty
            if (abs(lots$qty[[1]]) < 1e-12) lots <- lots[-1, , drop = FALSE]
          }
        } else {
          while (remaining_close > 0 && nrow(lots) > 0 && lots$qty[[1]] > 0) {
            cover_qty <- min(remaining_close, lots$qty[[1]])
            delta <- (price - lots$price[[1]]) * cover_qty
            y <- delta - compensation
            t <- realized_close + y
            compensation <- (t - realized_close) - y
            realized_close <- t
            lots$qty[[1]] <- lots$qty[[1]] - cover_qty
            remaining_close <- remaining_close - cover_qty
            if (abs(lots$qty[[1]]) < 1e-12) lots <- lots[-1, , drop = FALSE]
          }
        }
        realized <- c(realized, realized_close)
      }

      if (open_qty > 0) {
        lot_qty <- if (direction > 0L) open_qty else -open_qty
        lots <- rbind(
          lots,
          data.frame(qty = lot_qty, price = price, stringsAsFactors = FALSE)
        )
      }

      assign(inst, lots, envir = fifo)
    }

    n_trades <- length(realized)
    data.frame(
      run_id = run_id,
      n_trades = as.integer(n_trades),
      win_rate = if (n_trades > 0L) sum(realized > 0, na.rm = TRUE) / n_trades else NA_real_,
      stringsAsFactors = FALSE
    )
  })

  tibble::as_tibble(do.call(rbind, stats))
}

ledgr_compare_runs_select <- function(rows, fill_stats) {
  out <- rows
  out$n_trades <- NULL
  fill_idx <- match(out$run_id, fill_stats$run_id)
  out$n_trades <- fill_stats$n_trades[fill_idx]
  out$win_rate <- fill_stats$win_rate[fill_idx]
  out$n_trades[is.na(out$n_trades)] <- 0L
  out$n_trades <- as.integer(out$n_trades)
  cols <- c(
    "run_id",
    "label",
    "archived",
    "created_at_utc",
    "snapshot_id",
    "status",
    "final_equity",
    "total_return",
    "max_drawdown",
    "n_trades",
    "win_rate",
    "execution_mode",
    "elapsed_sec",
    "reproducibility_level",
    "strategy_source_hash",
    "strategy_params_hash",
    "config_hash",
    "snapshot_hash"
  )
  out <- out[, intersect(cols, names(out)), drop = FALSE]
  ledgr_classed_tibble(out, "ledgr_comparison")
}

ledgr_classed_tibble <- function(x, class_name) {
  out <- tibble::as_tibble(x)
  class(out) <- c(class_name, setdiff(class(out), class_name))
  out
}

ledgr_format_percent <- function(x, digits = 1L, signed = FALSE) {
  out <- rep(NA_character_, length(x))
  ok <- !is.na(x)
  fmt <- if (isTRUE(signed)) paste0("%+.", digits, "f%%") else paste0("%.", digits, "f%%")
  out[ok] <- sprintf(fmt, 100 * as.numeric(x[ok]))
  out
}

ledgr_print_curated_tibble <- function(title, x, cols, footer, ...) {
  view <- tibble::as_tibble(x[, intersect(cols, names(x)), drop = FALSE])
  if ("total_return" %in% names(view)) view$total_return <- ledgr_format_percent(view$total_return, signed = TRUE)
  if ("max_drawdown" %in% names(view)) view$max_drawdown <- ledgr_format_percent(view$max_drawdown)
  if ("win_rate" %in% names(view)) view$win_rate <- ledgr_format_percent(view$win_rate)

  cat(title, "\n", sep = "")
  print(view, ...)
  cat("\n")
  for (line in footer) {
    cat("# i ", line, "\n", sep = "")
  }
  invisible(x)
}

ledgr_run_info_from_row <- function(row, db_path) {
  if (nrow(row) != 1L) {
    rlang::abort("`row` must contain exactly one run.", class = "ledgr_internal_error")
  }
  info <- as.list(row[1, , drop = TRUE])
  info$db_path <- db_path
  info$telemetry_missing <- all(vapply(
    info[c("elapsed_sec", "persist_features", "feature_cache_hits", "feature_cache_misses")],
    function(x) is.null(x) || length(x) == 0L || is.na(x),
    logical(1)
  ))
  info$legacy_pre_provenance <- identical(info$reproducibility_level, "legacy") ||
    identical(info$strategy_source_capture_method, "legacy_pre_provenance")
  structure(info, class = c("ledgr_run_info", "list"))
}

#' Compare completed runs in a ledgr experiment store
#'
#' Reads stored run metadata, provenance, telemetry, and result artifacts from a
#' durable DuckDB experiment store. Strategies are not rerun, recovered source
#' is not evaluated, and the database is not mutated.
#'
#' @param snapshot A sealed `ledgr_snapshot` object. Use
#'   `ledgr_snapshot_load(db_path, snapshot_id)` to resume from a durable
#'   DuckDB file in a new R session.
#' @param run_ids Optional character vector of run IDs. If supplied, output
#'   preserves this order, including duplicates, and may include archived
#'   completed runs. If `NULL`, compares all non-archived completed runs.
#' @param include_archived Logical scalar. Used only when `run_ids = NULL`.
#' @param metrics Metrics set. Only `"standard"` is supported in v0.1.7.
#' @return A `ledgr_comparison` object, which is a classed tibble with one row
#'   per completed run. `n_trades` counts closed trade rows, not open-only fill
#'   rows; `win_rate` is computed over those closed trade rows.
#' @examples
#' bars <- subset(ledgr_demo_bars, instrument_id == "DEMO_01")
#' snapshot <- ledgr_snapshot_from_df(utils::head(bars, 30))
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["DEMO_01"] <- params$qty
#'   targets
#' }
#' exp <- ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 1000))
#' bt_a <- ledgr_run(exp, params = list(qty = 1), run_id = "qty-1")
#' on.exit(close(bt_a), add = TRUE)
#' bt_b <- ledgr_run(exp, params = list(qty = 2), run_id = "qty-2")
#' on.exit(close(bt_b), add = TRUE)
#' ledgr_compare_runs(snapshot, run_ids = c("qty-1", "qty-2"))
#' ledgr_snapshot_close(snapshot)
#' @export
ledgr_compare_runs <- function(snapshot, run_ids = NULL, include_archived = FALSE, metrics = c("standard")) {
  if (!is.character(metrics) || length(metrics) != 1L || !identical(metrics, "standard")) {
    rlang::abort("Only metrics = 'standard' is supported in v0.1.7.", class = "ledgr_invalid_args")
  }
  if (!is.logical(include_archived) || length(include_archived) != 1L || is.na(include_archived)) {
    rlang::abort("`include_archived` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }
  if (!is.null(run_ids)) {
    if (!is.character(run_ids) || any(is.na(run_ids)) || any(!nzchar(run_ids))) {
      rlang::abort("`run_ids` must be NULL or a character vector of non-empty run IDs.", class = "ledgr_invalid_args")
    }
  }

  db_path <- ledgr_run_store_snapshot_path(snapshot)
  snapshot_id <- ledgr_run_store_snapshot_id(snapshot)
  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)

  if (is.null(run_ids)) {
    rows <- ledgr_run_store_fetch(opened$con, include_archived = include_archived, snapshot_id = snapshot_id)
    rows <- rows[rows$status == "DONE", , drop = FALSE]
  } else {
    unique_ids <- unique(run_ids)
    rows <- ledgr_run_store_fetch(opened$con, include_archived = TRUE, snapshot_id = snapshot_id)
    rows <- rows[as.character(rows$run_id) %in% unique_ids, , drop = FALSE]
    found <- as.character(rows$run_id)
    missing <- setdiff(unique_ids, found)
    if (length(missing) > 0L) {
      rlang::abort(
        sprintf("Run IDs not found: %s", paste(missing, collapse = ", ")),
        class = "ledgr_run_not_found"
      )
    }
    bad <- rows[is.na(rows$status) | rows$status != "DONE", , drop = FALSE]
    if (nrow(bad) > 0L) {
      rlang::abort(
        sprintf(
          "Run '%s' has status %s and cannot be compared as a completed run. Use ledgr_run_info() for diagnostics.",
          bad$run_id[[1]],
          bad$status[[1]]
        ),
        class = "ledgr_run_not_complete"
      )
    }
    rows <- rows[match(run_ids, rows$run_id), , drop = FALSE]
  }

  if (nrow(rows) == 0L) {
    return(ledgr_compare_runs_select(rows, tibble::tibble(run_id = character(), n_trades = integer(), win_rate = numeric())))
  }
  fill_stats <- ledgr_compare_runs_fill_stats(opened$con, as.character(unique(rows$run_id)))
  out <- ledgr_compare_runs_select(rows, fill_stats)
  out
}

#' Print a run comparison
#'
#' @param x A `ledgr_comparison` object returned by [ledgr_compare_runs()].
#' @param ... Passed to the tibble print method for the curated view.
#' @return The input object, invisibly.
#' @export
print.ledgr_comparison <- function(x, ...) {
  ledgr_print_curated_tibble(
    "# ledgr comparison",
    x,
    cols = c(
      "run_id", "label", "final_equity", "total_return",
      "max_drawdown", "n_trades", "win_rate", "reproducibility_level"
    ),
    footer = c(
      "Full identity and telemetry columns remain available on this tibble.",
      "Inspect one run with ledgr_run_info(snapshot, run_id)."
    ),
    ...
  )
}

#' List runs in a ledgr experiment store
#'
#' Discovers stored runs in a DuckDB experiment-store file without recomputing
#' or mutating runs. Archived runs are hidden by default.
#'
#' @param snapshot A sealed `ledgr_snapshot` object. Use
#'   `ledgr_snapshot_load(db_path, snapshot_id)` to resume from a durable
#'   DuckDB file in a new R session.
#' @param include_archived Logical scalar. If `TRUE`, include archived runs.
#' @return A `ledgr_run_list` object, which is a classed tibble with run
#'   identity, provenance, status, telemetry summary, and basic result summary
#'   columns.
#' @examples
#' bars <- subset(ledgr_demo_bars, instrument_id == "DEMO_01")
#' snapshot <- ledgr_snapshot_from_df(utils::head(bars, 10))
#' strategy <- function(ctx, params) ctx$flat()
#' exp <- ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 1000))
#' bt <- ledgr_run(exp, params = list(), run_id = "flat")
#' ledgr_run_list(snapshot)
#' close(bt)
#' ledgr_snapshot_close(snapshot)
#' @export
ledgr_run_list <- function(snapshot, include_archived = FALSE) {
  if (!is.logical(include_archived) || length(include_archived) != 1L || is.na(include_archived)) {
    rlang::abort("`include_archived` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }
  db_path <- ledgr_run_store_snapshot_path(snapshot)
  snapshot_id <- ledgr_run_store_snapshot_id(snapshot)
  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  out <- ledgr_run_store_fetch(opened$con, include_archived = include_archived, snapshot_id = snapshot_id)
  detail_cols <- c("config_json", "dependency_versions_json", "strategy_params_json")
  ledgr_classed_tibble(out[setdiff(names(out), detail_cols)], "ledgr_run_list")
}

#' Print a run list
#'
#' @param x A `ledgr_run_list` object returned by [ledgr_run_list()].
#' @param ... Passed to the tibble print method for the curated view.
#' @return The input object, invisibly.
#' @export
print.ledgr_run_list <- function(x, ...) {
  cols <- c(
    "run_id", "label", "tags", "status", "final_equity",
    "total_return", "execution_mode", "reproducibility_level"
  )
  if ("archived" %in% names(x) && any(as.logical(x$archived), na.rm = TRUE)) {
    cols <- c("run_id", "label", "archived", "tags", "status", "final_equity", "total_return", "execution_mode")
  }
  ledgr_print_curated_tibble(
    "# ledgr run list",
    x,
    cols = cols,
    footer = c(
      "Full identity and telemetry columns remain available on this tibble.",
      "Inspect one run with ledgr_run_info(snapshot, run_id)."
    ),
    ...
  )
}

#' Inspect one run in a ledgr experiment store
#'
#' Returns a structured `ledgr_run_info` object for a stored run. This function
#' reads run metadata and diagnostics only; it does not execute strategy code.
#'
#' @param snapshot A sealed `ledgr_snapshot` object. Use
#'   `ledgr_snapshot_load(db_path, snapshot_id)` to resume from a durable
#'   DuckDB file in a new R session.
#' @param run_id Run identifier.
#' @return A `ledgr_run_info` object.
#' @examples
#' bars <- subset(ledgr_demo_bars, instrument_id == "DEMO_01")
#' snapshot <- ledgr_snapshot_from_df(utils::head(bars, 10))
#' strategy <- function(ctx, params) ctx$flat()
#' exp <- ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 1000))
#' bt <- ledgr_run(exp, params = list(), run_id = "flat")
#' ledgr_run_info(snapshot, bt$run_id)
#' close(bt)
#' ledgr_snapshot_close(snapshot)
#' @export
ledgr_run_info <- function(snapshot, run_id) {
  if (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  db_path <- ledgr_run_store_snapshot_path(snapshot)
  snapshot_id <- ledgr_run_store_snapshot_id(snapshot)
  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)

  row <- ledgr_run_store_fetch(opened$con, include_archived = TRUE, run_id = run_id, snapshot_id = snapshot_id)
  if (nrow(row) != 1L) {
    rlang::abort(sprintf("Run not found: %s", run_id), class = "ledgr_run_not_found")
  }

  ledgr_run_info_from_row(row, db_path)
}

#' Print run information
#'
#' @param x A `ledgr_run_info` object.
#' @param ... Unused.
#' @return The input object, invisibly.
#' @export
print.ledgr_run_info <- function(x, ...) {
  if (!inherits(x, "ledgr_run_info")) {
    rlang::abort("`x` must be a ledgr_run_info object.", class = "ledgr_invalid_args")
  }

  value <- function(name, default = "NA") {
    val <- x[[name]]
    if (is.null(val) || length(val) == 0L || is.na(val)) return(default)
    as.character(val[[1]])
  }

  cat("ledgr Run Info\n")
  cat("==============\n\n")
  cat("Run ID:          ", value("run_id"), "\n", sep = "")
  cat("Label:           ", value("label"), "\n", sep = "")
  cat("Status:          ", value("status"), "\n", sep = "")
  cat("Archived:        ", value("archived", "FALSE"), "\n", sep = "")
  cat("Tags:            ", value("tags"), "\n", sep = "")
  cat("Snapshot:        ", value("snapshot_id"), "\n", sep = "")
  cat("Snapshot Hash:   ", value("snapshot_hash"), "\n", sep = "")
  cat("Config Hash:     ", value("config_hash"), "\n", sep = "")
  cat("Strategy Hash:   ", value("strategy_source_hash"), "\n", sep = "")
  cat("Params Hash:     ", value("strategy_params_hash"), "\n", sep = "")
  cat("Reproducibility: ", value("reproducibility_level"), "\n", sep = "")
  cat("Execution Mode:  ", value("execution_mode"), "\n", sep = "")
  cat("Elapsed Sec:     ", value("elapsed_sec"), "\n", sep = "")
  cat("Persist Features:", value("persist_features"), "\n", sep = "")
  cat("Cache Hits:      ", value("feature_cache_hits"), "\n", sep = "")
  cat("Cache Misses:    ", value("feature_cache_misses"), "\n", sep = "")
  if (isTRUE(x$legacy_pre_provenance)) {
    cat("\nLegacy/pre-provenance run: strategy provenance is incomplete.\n")
  }
  if (!identical(value("status"), "DONE")) {
    cat("\nDiagnostics: ", value("error_msg"), "\n", sep = "")
  }
  invisible(x)
}

#' Reopen a completed run from a ledgr experiment store
#'
#' Returns a `ledgr_backtest`-compatible handle over an existing completed run.
#' The run is not recomputed and strategy code is not executed.
#'
#' @param snapshot A sealed `ledgr_snapshot` object. Use
#'   `ledgr_snapshot_load(db_path, snapshot_id)` to resume from a durable
#'   DuckDB file in a new R session.
#' @param run_id Run identifier. The run must have status `DONE`.
#' @return A `ledgr_backtest` object.
#' @examples
#' bars <- subset(ledgr_demo_bars, instrument_id == "DEMO_01")
#' snapshot <- ledgr_snapshot_from_df(utils::head(bars, 10))
#' strategy <- function(ctx, params) ctx$flat()
#' exp <- ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 1000))
#' bt <- ledgr_run(exp, params = list(), run_id = "flat")
#' run_id <- bt$run_id
#' close(bt)
#' reopened <- ledgr_run_open(snapshot, run_id)
#' summary(reopened)
#' close(reopened)
#' ledgr_snapshot_close(snapshot)
#' @export
ledgr_run_open <- function(snapshot, run_id) {
  if (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  db_path <- ledgr_run_store_snapshot_path(snapshot)
  snapshot_id <- ledgr_run_store_snapshot_id(snapshot)
  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  ledgr_experiment_store_check_schema(opened$con, write = FALSE)

  row <- DBI::dbGetQuery(
    opened$con,
    "SELECT run_id, status, config_json FROM runs WHERE run_id = ? AND snapshot_id = ?",
    params = list(run_id, snapshot_id)
  )
  if (nrow(row) != 1L) {
    rlang::abort(sprintf("Run not found: %s", run_id), class = "ledgr_run_not_found")
  }
  status <- row$status[[1]]
  if (!identical(status, "DONE")) {
    rlang::abort(
      sprintf("Run '%s' has status %s and cannot be opened as a completed backtest. Use ledgr_run_info() for diagnostics.", run_id, status),
      class = "ledgr_run_not_complete"
    )
  }
  config_json <- row$config_json[[1]]
  if (is.null(config_json) || is.na(config_json) || !nzchar(config_json)) {
    rlang::abort(sprintf("Run '%s' has no stored config_json and cannot be reopened.", run_id), class = "ledgr_invalid_run")
  }

  cfg <- tryCatch(
    jsonlite::fromJSON(config_json, simplifyVector = TRUE, simplifyDataFrame = FALSE, simplifyMatrix = FALSE),
    error = function(e) {
      rlang::abort(sprintf("Run '%s' has invalid config_json and cannot be reopened.", run_id), class = "ledgr_invalid_run", parent = e)
    }
  )
  cfg$db_path <- db_path
  required_config_fields <- c("db_path", "engine", "universe", "backtest", "fill_model", "strategy")
  missing_config_fields <- setdiff(required_config_fields, names(cfg))
  if (length(missing_config_fields) > 0L) {
    rlang::abort(
      sprintf(
        "Run '%s' has legacy or incomplete config_json and cannot be reopened. Use ledgr_run_info() to inspect available metadata.",
        run_id
      ),
      class = "ledgr_invalid_run"
    )
  }
  class(cfg) <- unique(c("ledgr_config", class(cfg)))
  tryCatch(
    validate_ledgr_config(cfg),
    error = function(e) {
      rlang::abort(sprintf("Run '%s' has invalid config_json and cannot be reopened.", run_id), class = "ledgr_invalid_run", parent = e)
    }
  )
  new_ledgr_backtest(run_id = run_id, db_path = db_path, config = cfg)
}

#' Set a human-readable label for a run
#'
#' Updates only the mutable label metadata for a stored run. The immutable
#' `run_id` and experiment identity hashes are not changed.
#'
#' @param snapshot A sealed `ledgr_snapshot` object. Use
#'   `ledgr_snapshot_load(db_path, snapshot_id)` to resume from a durable
#'   DuckDB file in a new R session.
#' @param run_id Run identifier.
#' @param label Human-readable label. Use `NULL` or `""` to clear the label.
#' @return The input `ledgr_snapshot`, invisibly.
#' @examples
#' bars <- subset(ledgr_demo_bars, instrument_id == "DEMO_01")
#' snapshot <- ledgr_snapshot_from_df(utils::head(bars, 10))
#' strategy <- function(ctx, params) ctx$flat()
#' exp <- ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 1000))
#' bt <- ledgr_run(exp, params = list(), run_id = "flat")
#' ledgr_run_label(snapshot, bt$run_id, "baseline")
#' close(bt)
#' ledgr_snapshot_close(snapshot)
#' @export
ledgr_run_label <- function(snapshot, run_id, label = NULL) {
  if (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  label <- ledgr_run_store_normalize_optional_text(label, "label")

  db_path <- ledgr_run_store_snapshot_path(snapshot)
  snapshot_id <- ledgr_run_store_snapshot_id(snapshot)
  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  ledgr_experiment_store_check_schema(opened$con, write = TRUE, inform = TRUE)
  ledgr_run_store_assert_run_exists(opened$con, run_id, snapshot_id = snapshot_id)

  DBI::dbExecute(
    opened$con,
    "UPDATE runs SET label = ? WHERE run_id = ? AND snapshot_id = ?",
    params = list(label, run_id, snapshot_id)
  )
  ledgr_checkpoint_duckdb(opened$con, strict = TRUE)
  invisible(snapshot)
}

#' Archive a run without deleting artifacts
#'
#' Marks a stored run as archived so it is hidden from default run lists while
#' remaining inspectable and, if completed, reopenable. Archiving is
#' idempotent and does not rewrite existing archive metadata.
#'
#' @param snapshot A sealed `ledgr_snapshot` object. Use
#'   `ledgr_snapshot_load(db_path, snapshot_id)` to resume from a durable
#'   DuckDB file in a new R session.
#' @param run_id Run identifier.
#' @param reason Optional archive reason. Empty strings are stored as `NULL`.
#' @return The input `ledgr_snapshot`, invisibly.
#' @examples
#' bars <- subset(ledgr_demo_bars, instrument_id == "DEMO_01")
#' snapshot <- ledgr_snapshot_from_df(utils::head(bars, 10))
#' strategy <- function(ctx, params) ctx$flat()
#' exp <- ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 1000))
#' bt <- ledgr_run(exp, params = list(), run_id = "flat")
#' ledgr_run_archive(snapshot, bt$run_id, reason = "example cleanup")
#' close(bt)
#' ledgr_snapshot_close(snapshot)
#' @export
ledgr_run_archive <- function(snapshot, run_id, reason = NULL) {
  if (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  reason <- ledgr_run_store_normalize_optional_text(reason, "reason")

  db_path <- ledgr_run_store_snapshot_path(snapshot)
  snapshot_id <- ledgr_run_store_snapshot_id(snapshot)
  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  ledgr_experiment_store_check_schema(opened$con, write = TRUE, inform = TRUE)
  ledgr_run_store_assert_run_exists(opened$con, run_id, snapshot_id = snapshot_id)

  DBI::dbExecute(
    opened$con,
    "
    UPDATE runs
    SET archived = TRUE,
        archived_at_utc = CASE
          WHEN COALESCE(archived, FALSE) = TRUE THEN archived_at_utc
          ELSE ?
        END,
        archive_reason = CASE
          WHEN COALESCE(archived, FALSE) = TRUE THEN archive_reason
          ELSE ?
        END
    WHERE run_id = ? AND snapshot_id = ?
    ",
    params = list(as.POSIXct(Sys.time(), tz = "UTC"), reason, run_id, snapshot_id)
  )
  ledgr_checkpoint_duckdb(opened$con, strict = TRUE)
  invisible(snapshot)
}
