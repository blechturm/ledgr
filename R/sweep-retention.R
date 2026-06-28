ledgr_sweep_retention_schema_version <- 2L

#' Sweep retention policy
#'
#' `ledgr_sweep_retention()` creates a classed retention policy for
#' [ledgr_sweep()]. Retention controls which optional sweep evidence is kept in
#' memory or later persisted. It is not part of execution identity.
#'
#' @param returns Character scalar. `"none"` keeps the current scalar-only sweep
#'   output. `"completed"` requests retained net equity/return series for
#'   completed candidates.
#' @param trades Character scalar. `"none"` keeps no trade evidence. `"closed"`
#'   requests retained closed-trade evidence for completed candidates.
#' @return A `ledgr_sweep_retention` object.
#' @examples
#' ledgr_sweep_retention()
#' ledgr_sweep_retention("completed")
#' ledgr_sweep_retention(returns = "completed", trades = "closed")
#' @export
ledgr_sweep_retention <- function(returns = c("none", "completed"),
                                  trades = c("none", "closed")) {
  if (missing(returns)) {
    returns <- "none"
  }
  if (missing(trades)) {
    trades <- "none"
  }
  if (!is.character(returns) ||
      length(returns) != 1L ||
      is.na(returns) ||
      !returns %in% c("none", "completed")) {
    rlang::abort(
      "`returns` must be one of \"none\" or \"completed\".",
      class = c("ledgr_invalid_sweep_retention", "ledgr_invalid_args")
    )
  }
  if (!is.character(trades) ||
      length(trades) != 1L ||
      is.na(trades) ||
      !trades %in% c("none", "closed")) {
    rlang::abort(
      "`trades` must be one of \"none\" or \"closed\".",
      class = c("ledgr_invalid_sweep_retention", "ledgr_invalid_args")
    )
  }
  structure(
    list(
      retention_schema_version = ledgr_sweep_retention_schema_version,
      returns = unname(returns),
      trades = unname(trades)
    ),
    class = c("ledgr_sweep_retention", "list")
  )
}

ledgr_sweep_retention_normalize <- function(retain) {
  if (!inherits(retain, "ledgr_sweep_retention")) {
    rlang::abort(
      "`retain` must be created with ledgr_sweep_retention().",
      class = c("ledgr_invalid_sweep_retention", "ledgr_invalid_args")
    )
  }
  legacy_version <- identical(retain$retention_schema_version, 1L)
  current_version <- identical(retain$retention_schema_version, ledgr_sweep_retention_schema_version)
  trades <- retain$trades %||% "none"
  if (!is.list(retain) ||
      (!legacy_version && !current_version) ||
      !is.character(retain$returns) ||
      length(retain$returns) != 1L ||
      is.na(retain$returns) ||
      !retain$returns %in% c("none", "completed") ||
      !is.character(trades) ||
      length(trades) != 1L ||
      is.na(trades) ||
      !trades %in% c("none", "closed")) {
    rlang::abort(
      "`retain` has an invalid ledgr sweep retention shape.",
      class = c("ledgr_invalid_sweep_retention", "ledgr_invalid_args")
    )
  }
  ledgr_sweep_retention(retain$returns, trades = trades)
}

ledgr_sweep_empty_returns <- function(include_sweep_id = TRUE) {
  out <- tibble::tibble(
    candidate_id = character(),
    candidate_row = integer(),
    ts_utc = as.POSIXct(character(), tz = "UTC"),
    equity = numeric(),
    period_return = numeric()
  )
  if (isTRUE(include_sweep_id)) {
    out <- tibble::tibble(sweep_id = character(), out)
  }
  out
}

ledgr_sweep_retained_returns_from_equity <- function(equity,
                                                     candidate_id,
                                                     candidate_row) {
  if (!is.data.frame(equity) || nrow(equity) == 0L) {
    return(ledgr_sweep_empty_returns(include_sweep_id = FALSE))
  }
  equity_values <- as.numeric(equity$equity)
  period_return <- c(NA_real_, compute_period_returns(equity_values))
  tibble::tibble(
    candidate_id = rep(as.character(candidate_id), nrow(equity)),
    candidate_row = rep(as.integer(candidate_row), nrow(equity)),
    ts_utc = as.POSIXct(equity$ts_utc, tz = "UTC"),
    equity = equity_values,
    period_return = period_return
  )
}

ledgr_sweep_collect_retained_returns <- function(results, sweep_id) {
  retained <- lapply(results, `[[`, "retained_returns")
  retained <- retained[!vapply(retained, is.null, logical(1))]
  retained <- retained[vapply(retained, nrow, integer(1)) > 0L]
  if (length(retained) == 0L) {
    return(ledgr_sweep_empty_returns(include_sweep_id = TRUE))
  }
  out <- tibble::as_tibble(do.call(rbind, retained))
  tibble::tibble(
    sweep_id = rep(as.character(sweep_id), nrow(out)),
    candidate_id = as.character(out$candidate_id),
    candidate_row = as.integer(out$candidate_row),
    ts_utc = as.POSIXct(out$ts_utc, tz = "UTC"),
    equity = as.numeric(out$equity),
    period_return = as.numeric(out$period_return)
  )
}

ledgr_sweep_empty_trades <- function(include_sweep_id = TRUE) {
  out <- tibble::tibble(
    candidate_id = character(),
    candidate_row = integer(),
    trade_seq = integer(),
    close_ts_utc = as.POSIXct(character(), tz = "UTC"),
    realized_pnl = numeric(),
    win_loss = character()
  )
  if (isTRUE(include_sweep_id)) {
    out <- tibble::tibble(sweep_id = character(), out)
  }
  out
}

ledgr_sweep_retained_trades_from_fills <- function(fills,
                                                   candidate_id,
                                                   candidate_row) {
  if (!is.data.frame(fills) || nrow(fills) == 0L) {
    return(ledgr_sweep_empty_trades(include_sweep_id = FALSE))
  }
  trades <- ledgr_closed_trade_rows(fills)
  if (!is.data.frame(trades) || nrow(trades) == 0L) {
    return(ledgr_sweep_empty_trades(include_sweep_id = FALSE))
  }
  order_cols <- list(as.POSIXct(trades$ts_utc, tz = "UTC"))
  if ("event_seq" %in% names(trades)) {
    order_cols <- c(order_cols, list(as.integer(trades$event_seq)))
  }
  ord <- do.call(order, order_cols)
  trades <- trades[ord, , drop = FALSE]
  pnl <- as.numeric(trades$realized_pnl)
  win_loss <- ifelse(
    is.na(pnl),
    NA_character_,
    ifelse(pnl > 0, "WIN", ifelse(pnl < 0, "LOSS", "BREAKEVEN"))
  )
  tibble::tibble(
    candidate_id = rep(as.character(candidate_id), nrow(trades)),
    candidate_row = rep(as.integer(candidate_row), nrow(trades)),
    trade_seq = seq_len(nrow(trades)),
    close_ts_utc = as.POSIXct(trades$ts_utc, tz = "UTC"),
    realized_pnl = pnl,
    win_loss = win_loss
  )
}

ledgr_sweep_collect_retained_trades <- function(results, sweep_id) {
  retained <- lapply(results, `[[`, "retained_trades")
  retained <- retained[!vapply(retained, is.null, logical(1))]
  retained <- retained[vapply(retained, nrow, integer(1)) > 0L]
  if (length(retained) == 0L) {
    return(ledgr_sweep_empty_trades(include_sweep_id = TRUE))
  }
  out <- tibble::as_tibble(do.call(rbind, retained))
  tibble::tibble(
    sweep_id = rep(as.character(sweep_id), nrow(out)),
    candidate_id = as.character(out$candidate_id),
    candidate_row = as.integer(out$candidate_row),
    trade_seq = as.integer(out$trade_seq),
    close_ts_utc = as.POSIXct(out$close_ts_utc, tz = "UTC"),
    realized_pnl = as.numeric(out$realized_pnl),
    win_loss = as.character(out$win_loss)
  )
}

#' Retained sweep return series
#'
#' `ledgr_sweep_returns()` returns the retained long net portfolio equity and
#' adjacent-period return series for completed sweep candidates. Retained
#' returns are net strategy returns only; they are not benchmark-relative
#' returns and they do not include gross-vs-net attribution.
#'
#' @param x A `ledgr_sweep_results` object.
#' @param candidates Optional character vector of `candidate_id` values.
#' @return `ledgr_sweep_returns()` returns a tibble with `sweep_id`,
#'   `candidate_id`, `ts_utc`, `equity`, and `period_return`.
#'   `ledgr_sweep_returns_wide()` returns a tibble with `ts_utc` followed by
#'   one column per candidate. `ledgr_sweep_returns_panel()` returns a classed
#'   list with normalized long evidence, a numeric matrix, UTC timestamps, the
#'   candidate ids used, completed candidate ids, excluded candidate ids, and
#'   first-row handling metadata. `ledgr_sweep_returns_matrix()`,
#'   `ledgr_sweep_returns_data_frame()`, and `ledgr_sweep_returns_xts()` return
#'   adapter-shaped projections over that normalized panel.
#' @examples
#' bars <- data.frame(
#'   instrument_id = "AAA",
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:4,
#'   open = c(10, 11, 12, 11, 13),
#'   high = c(11, 12, 13, 12, 14),
#'   low = c(9, 10, 11, 10, 12),
#'   close = c(10, 11, 12, 11, 13),
#'   volume = 1000
#' )
#' snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["AAA"] <- params$qty
#'   targets
#' }
#' exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
#' grid <- ledgr_param_grid(flat = list(qty = 0), long = list(qty = 1))
#' sweep <- ledgr_sweep(exp, grid, retain = ledgr_sweep_retention("completed"))
#'
#' long <- ledgr_sweep_returns(sweep)
#' long[!is.na(long$period_return), ]
#' ledgr_sweep_returns_wide(sweep, value = "equity")
#'
#' ledgr_snapshot_close(snapshot)
#' @export
ledgr_sweep_returns <- function(x, candidates = NULL) {
  ledgr_sweep_returns_resolve(x, candidates = candidates)
}

#' @describeIn ledgr_sweep_returns Return retained closed-trade evidence for
#'   completed sweep candidates. This evidence is captured at sweep time from
#'   closed trade rows and is not reconstructed from saved fills.
#' @export
ledgr_sweep_trades <- function(x, candidates = NULL) {
  ledgr_sweep_trades_resolve(x, candidates = candidates)
}

#' @describeIn ledgr_sweep_returns Return retained sweep return or equity
#'   series in wide form. Use the long form when you want candidate metadata
#'   beside each row; use the wide form when an external metric package expects
#'   one return/equity column per candidate.
#' @param value Value to widen. `"returns"` uses `period_return`; `"equity"`
#'   uses `equity`.
#' @export
ledgr_sweep_returns_wide <- function(x,
                                     candidates = NULL,
                                     value = c("returns", "equity")) {
  value <- match.arg(value)
  long <- ledgr_sweep_returns_resolve(x, candidates = candidates)
  ids <- if (is.null(candidates)) {
    unique(as.character(long$candidate_id))
  } else {
    as.character(candidates)
  }
  ts_utc <- unique(as.POSIXct(long$ts_utc, tz = "UTC"))
  out <- tibble::tibble(ts_utc = ts_utc)
  value_col <- if (identical(value, "returns")) "period_return" else "equity"
  for (id in ids) {
    rows <- long[as.character(long$candidate_id) == id, , drop = FALSE]
    values <- rep(NA_real_, length(ts_utc))
    idx <- match(as.POSIXct(rows$ts_utc, tz = "UTC"), ts_utc)
    values[idx] <- as.numeric(rows[[value_col]])
    out[[id]] <- values
  }
  out
}

#' @describeIn ledgr_sweep_returns Return a normalized retained-return panel.
#'   For `value = "returns"`, the structural first timestamp is dropped after
#'   verifying each candidate's first `period_return` is `NA_real_`.
#' @param complete Logical scalar. If `TRUE`, require every selected completed
#'   candidate to share the same timestamp grid after first-row handling.
#' @export
ledgr_sweep_returns_panel <- function(x,
                                      candidates = NULL,
                                      value = c("returns", "equity"),
                                      complete = TRUE) {
  value <- match.arg(value)
  ledgr_sweep_returns_validate_complete(complete)
  requested <- ledgr_sweep_returns_requested_candidates(x, candidates)
  long <- ledgr_sweep_returns_resolve(x, candidates = candidates)
  completed <- ledgr_sweep_returns_completed_candidates(x)
  used <- requested[requested %in% unique(as.character(long$candidate_id))]
  excluded <- setdiff(as.character(x$candidate_id), used)
  drop_first <- identical(value, "returns")
  value_col <- if (identical(value, "returns")) "period_return" else "equity"

  rows_by_candidate <- lapply(used, function(candidate_id) {
    ledgr_sweep_returns_panel_rows(long, candidate_id, drop_first = drop_first)
  })
  names(rows_by_candidate) <- used

  if (isTRUE(complete)) {
    ledgr_sweep_returns_assert_complete(rows_by_candidate)
  }
  ts_utc <- ledgr_sweep_returns_panel_timestamps(rows_by_candidate)
  mat <- ledgr_sweep_returns_panel_matrix(rows_by_candidate, ts_utc, used, value_col)

  structure(
    list(
      long = ledgr_sweep_returns_panel_long(rows_by_candidate),
      matrix = mat,
      ts_utc = ts_utc,
      candidate_ids = used,
      completed_candidate_ids = completed,
      excluded_candidate_ids = excluded,
      value = value,
      first_row_dropped = drop_first,
      complete = isTRUE(complete)
    ),
    class = c("ledgr_sweep_returns_panel", "list")
  )
}

#' @describeIn ledgr_sweep_returns Return a numeric `T x N` matrix over a
#'   normalized retained-return panel.
#' @export
ledgr_sweep_returns_matrix <- function(x,
                                       candidates = NULL,
                                       value = c("returns", "equity"),
                                       complete = TRUE) {
  panel <- ledgr_sweep_returns_panel(
    x,
    candidates = candidates,
    value = value,
    complete = complete
  )
  ledgr_sweep_returns_attach_projection_attrs(panel$matrix, panel)
}

#' @describeIn ledgr_sweep_returns Return a base data frame over a normalized
#'   retained-return panel.
#' @export
ledgr_sweep_returns_data_frame <- function(x,
                                           candidates = NULL,
                                           value = c("returns", "equity"),
                                           complete = TRUE) {
  panel <- ledgr_sweep_returns_panel(
    x,
    candidates = candidates,
    value = value,
    complete = complete
  )
  out <- as.data.frame(panel$matrix, check.names = FALSE, stringsAsFactors = FALSE)
  ledgr_sweep_returns_attach_projection_attrs(out, panel)
}

#' @describeIn ledgr_sweep_returns Return an optional `xts` projection over a
#'   normalized retained-return panel. The `xts` package remains optional and is
#'   not imported by ledgr.
#' @export
ledgr_sweep_returns_xts <- function(x,
                                    candidates = NULL,
                                    value = c("returns", "equity"),
                                    complete = TRUE) {
  if (!requireNamespace("xts", quietly = TRUE)) {
    rlang::abort(
      "ledgr_sweep_returns_xts() requires the optional package 'xts'. Install it with install.packages('xts').",
      class = c("ledgr_missing_package", "ledgr_invalid_args")
    )
  }
  panel <- ledgr_sweep_returns_panel(
    x,
    candidates = candidates,
    value = value,
    complete = complete
  )
  out <- xts::xts(panel$matrix, order.by = panel$ts_utc)
  attr(out, "ledgr_external_evidence") <- list(
    source = "retained_sweep_returns",
    package = "xts",
    package_version = as.character(utils::packageVersion("xts"))
  )
  ledgr_sweep_returns_attach_projection_attrs(out, panel)
}

ledgr_sweep_returns_resolve <- function(x, candidates = NULL) {
  if (!inherits(x, "ledgr_sweep_results")) {
    rlang::abort("`x` must be a ledgr_sweep_results object.", class = "ledgr_invalid_args")
  }
  retain <- attr(x, "sweep_retention", exact = TRUE)
  returns <- attr(x, "sweep_returns", exact = TRUE)
  if (!inherits(retain, "ledgr_sweep_retention") ||
      !identical(retain$returns, "completed") ||
      is.null(returns)) {
    rlang::abort(
      "Sweep returns were not retained. Run ledgr_sweep(..., retain = ledgr_sweep_retention(\"completed\")) first.",
      class = c("ledgr_sweep_returns_unretained", "ledgr_invalid_args")
    )
  }
  candidates <- ledgr_sweep_returns_normalize_candidates(candidates)
  if (is.null(candidates)) {
    candidates_scope <- unique(as.character(x$candidate_id))
    returns <- ledgr_sweep_returns_filter_and_order(returns, candidates_scope)
  } else {
    ledgr_sweep_returns_validate_candidates(x, returns, candidates)
    returns <- ledgr_sweep_returns_filter_and_order(returns, candidates)
  }
  ledgr_sweep_returns_public_columns(returns)
}

ledgr_sweep_returns_filter_and_order <- function(returns, candidates) {
  if (length(candidates) == 0L) {
    return(returns[FALSE, , drop = FALSE])
  }
  returns <- returns[as.character(returns$candidate_id) %in% candidates, , drop = FALSE]
  id_order <- match(as.character(returns$candidate_id), candidates)
  ts_order <- order(id_order, as.POSIXct(returns$ts_utc, tz = "UTC"))
  returns[ts_order, , drop = FALSE]
}

ledgr_sweep_returns_public_columns <- function(returns) {
  out <- tibble::as_tibble(returns)
  out <- out[, c("sweep_id", "candidate_id", "ts_utc", "equity", "period_return"), drop = FALSE]
  out$ts_utc <- as.POSIXct(out$ts_utc, tz = "UTC")
  out$equity <- as.numeric(out$equity)
  out$period_return <- as.numeric(out$period_return)
  out
}

ledgr_sweep_trades_resolve <- function(x, candidates = NULL) {
  if (!inherits(x, "ledgr_sweep_results")) {
    rlang::abort("`x` must be a ledgr_sweep_results object.", class = "ledgr_invalid_args")
  }
  retain <- attr(x, "sweep_retention", exact = TRUE)
  trades <- attr(x, "sweep_trades", exact = TRUE)
  if (!inherits(retain, "ledgr_sweep_retention") ||
      !identical(retain$trades, "closed") ||
      is.null(trades)) {
    rlang::abort(
      "Sweep closed trades were not retained. Run ledgr_sweep(..., retain = ledgr_sweep_retention(trades = \"closed\")) first.",
      class = c("ledgr_sweep_trades_unretained", "ledgr_invalid_args")
    )
  }
  candidates <- ledgr_sweep_returns_normalize_candidates(candidates)
  if (is.null(candidates)) {
    candidates_scope <- unique(as.character(x$candidate_id))
    ledgr_sweep_trades_validate_retained_completeness(x, trades, candidates_scope)
    trades <- ledgr_sweep_trades_filter_and_order(trades, candidates_scope)
  } else {
    ledgr_sweep_trades_validate_candidates(x, trades, candidates)
    trades <- ledgr_sweep_trades_filter_and_order(trades, candidates)
  }
  ledgr_sweep_trades_public_columns(trades)
}

ledgr_sweep_trades_filter_and_order <- function(trades, candidates) {
  if (length(candidates) == 0L) {
    return(trades[FALSE, , drop = FALSE])
  }
  trades <- trades[as.character(trades$candidate_id) %in% candidates, , drop = FALSE]
  id_order <- match(as.character(trades$candidate_id), candidates)
  trades_order <- order(id_order, as.integer(trades$trade_seq))
  trades[trades_order, , drop = FALSE]
}

ledgr_sweep_trades_public_columns <- function(trades) {
  out <- tibble::as_tibble(trades)
  out <- out[, c(
    "sweep_id", "candidate_id", "candidate_row", "trade_seq",
    "close_ts_utc", "realized_pnl", "win_loss"
  ), drop = FALSE]
  out$candidate_row <- as.integer(out$candidate_row)
  out$trade_seq <- as.integer(out$trade_seq)
  out$close_ts_utc <- as.POSIXct(out$close_ts_utc, tz = "UTC")
  out$realized_pnl <- as.numeric(out$realized_pnl)
  out$win_loss <- as.character(out$win_loss)
  out
}

ledgr_sweep_returns_validate_complete <- function(complete) {
  if (!is.logical(complete) || length(complete) != 1L || is.na(complete)) {
    rlang::abort("`complete` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }
  invisible(TRUE)
}

ledgr_sweep_returns_requested_candidates <- function(x, candidates) {
  if (!inherits(x, "ledgr_sweep_results")) {
    rlang::abort("`x` must be a ledgr_sweep_results object.", class = "ledgr_invalid_args")
  }
  if (is.null(candidates)) {
    return(unique(as.character(x$candidate_id)))
  }
  ledgr_sweep_returns_normalize_candidates(candidates)
}

ledgr_sweep_returns_completed_candidates <- function(x) {
  ids <- as.character(x$candidate_id)
  if (!"status" %in% names(x)) {
    return(character())
  }
  ids[as.character(x$status) == "DONE"]
}

ledgr_sweep_returns_panel_rows <- function(long, candidate_id, drop_first) {
  rows <- long[as.character(long$candidate_id) == candidate_id, , drop = FALSE]
  rows <- rows[order(as.POSIXct(rows$ts_utc, tz = "UTC")), , drop = FALSE]
  rows$ts_utc <- as.POSIXct(rows$ts_utc, tz = "UTC")
  rows$equity <- as.numeric(rows$equity)
  rows$period_return <- as.numeric(rows$period_return)
  if (isTRUE(drop_first) && nrow(rows) > 0L) {
    if (!is.na(rows$period_return[[1L]])) {
      rlang::abort(
        sprintf("Retained returns for candidate `%s` do not have a structural first-row NA.", candidate_id),
        class = c("ledgr_sweep_returns_first_row_invalid", "ledgr_invalid_args"),
        candidate_id = candidate_id
      )
    }
    rows <- rows[-1L, , drop = FALSE]
  }
  rows
}

ledgr_sweep_returns_assert_complete <- function(rows_by_candidate) {
  if (length(rows_by_candidate) <= 1L) {
    return(invisible(TRUE))
  }
  reference_idx <- which.max(vapply(rows_by_candidate, nrow, integer(1)))
  reference <- as.POSIXct(rows_by_candidate[[reference_idx]]$ts_utc, tz = "UTC")
  reference_iso <- ledgr_sweep_returns_ts_labels(reference)
  offending <- character()
  missing <- list()
  extra <- list()

  for (candidate_id in names(rows_by_candidate)) {
    ts_utc <- as.POSIXct(rows_by_candidate[[candidate_id]]$ts_utc, tz = "UTC")
    same <- length(ts_utc) == length(reference) &&
      identical(as.numeric(ts_utc), as.numeric(reference))
    if (!same) {
      offending <- c(offending, candidate_id)
      ts_iso <- ledgr_sweep_returns_ts_labels(ts_utc)
      missing[[candidate_id]] <- setdiff(reference_iso, ts_iso)
      extra[[candidate_id]] <- setdiff(ts_iso, reference_iso)
    }
  }
  if (length(offending) > 0L) {
    rlang::abort(
      sprintf(
        "Retained sweep returns do not form a complete common timestamp panel for candidate_id: %s.",
        paste(offending, collapse = ", ")
      ),
      class = c("ledgr_sweep_returns_incomplete_panel", "ledgr_validation_pbo_incomplete_panel", "ledgr_invalid_args"),
      candidate_ids = offending,
      missing_timestamps = missing,
      extra_timestamps = extra
    )
  }
  invisible(TRUE)
}

ledgr_sweep_returns_panel_timestamps <- function(rows_by_candidate) {
  if (length(rows_by_candidate) == 0L) {
    return(as.POSIXct(character(), tz = "UTC"))
  }
  ts_num <- sort(unique(unlist(lapply(rows_by_candidate, function(rows) {
    as.numeric(as.POSIXct(rows$ts_utc, tz = "UTC"))
  }), use.names = FALSE)))
  as.POSIXct(ts_num, origin = "1970-01-01", tz = "UTC")
}

ledgr_sweep_returns_panel_matrix <- function(rows_by_candidate,
                                             ts_utc,
                                             candidate_ids,
                                             value_col) {
  out <- matrix(
    NA_real_,
    nrow = length(ts_utc),
    ncol = length(candidate_ids),
    dimnames = list(ledgr_sweep_returns_ts_labels(ts_utc), candidate_ids)
  )
  if (length(candidate_ids) == 0L || length(ts_utc) == 0L) {
    return(out)
  }
  ts_num <- as.numeric(ts_utc)
  for (candidate_id in candidate_ids) {
    rows <- rows_by_candidate[[candidate_id]]
    idx <- match(as.numeric(as.POSIXct(rows$ts_utc, tz = "UTC")), ts_num)
    out[idx, candidate_id] <- as.numeric(rows[[value_col]])
  }
  out
}

ledgr_sweep_returns_panel_long <- function(rows_by_candidate) {
  rows_by_candidate <- rows_by_candidate[vapply(rows_by_candidate, nrow, integer(1)) > 0L]
  if (length(rows_by_candidate) == 0L) {
    return(ledgr_sweep_empty_returns(include_sweep_id = TRUE))
  }
  tibble::as_tibble(do.call(rbind, unname(rows_by_candidate)))
}

ledgr_sweep_returns_ts_labels <- function(ts_utc) {
  if (length(ts_utc) == 0L) {
    return(character())
  }
  format(as.POSIXct(ts_utc, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

ledgr_sweep_returns_attach_projection_attrs <- function(out, panel) {
  attr(out, "ledgr_return_panel") <- list(
    source = "retained_sweep_returns",
    value = panel$value,
    candidate_ids = panel$candidate_ids,
    completed_candidate_ids = panel$completed_candidate_ids,
    excluded_candidate_ids = panel$excluded_candidate_ids,
    first_row_dropped = panel$first_row_dropped,
    complete = panel$complete
  )
  out
}

ledgr_sweep_returns_normalize_candidates <- function(candidates) {
  if (is.null(candidates)) {
    return(NULL)
  }
  if (!is.character(candidates) ||
      length(candidates) < 1L ||
      anyNA(candidates) ||
      any(!nzchar(candidates))) {
    rlang::abort("`candidates` must be NULL or a non-empty character vector.", class = "ledgr_invalid_args")
  }
  as.character(candidates)
}

ledgr_sweep_returns_validate_candidates <- function(x, returns, candidates) {
  known <- as.character(x$candidate_id)
  missing <- setdiff(candidates, known)
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf("Unknown sweep candidate_id: %s.", paste(missing, collapse = ", ")),
      class = c("ledgr_sweep_returns_candidate_not_found", "ledgr_invalid_args")
    )
  }
  status <- stats::setNames(as.character(x$status), known)
  not_completed <- candidates[status[candidates] != "DONE"]
  if (length(not_completed) > 0L) {
    rlang::abort(
      sprintf("Retained returns are available only for completed candidates: %s.", paste(not_completed, collapse = ", ")),
      class = c("ledgr_sweep_returns_candidate_not_completed", "ledgr_invalid_args")
    )
  }
  retained_ids <- unique(as.character(returns$candidate_id))
  missing_retained <- setdiff(candidates, retained_ids)
  if (length(missing_retained) > 0L) {
    rlang::abort(
      sprintf("Retained returns are missing for completed candidate_id: %s.", paste(missing_retained, collapse = ", ")),
      class = c("ledgr_sweep_returns_candidate_not_completed", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

ledgr_sweep_trades_validate_candidates <- function(x, trades, candidates) {
  known <- as.character(x$candidate_id)
  missing <- setdiff(candidates, known)
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf("Unknown sweep candidate_id: %s.", paste(missing, collapse = ", ")),
      class = c("ledgr_sweep_trades_candidate_not_found", "ledgr_invalid_args")
    )
  }
  status <- stats::setNames(as.character(x$status), known)
  not_completed <- candidates[status[candidates] != "DONE"]
  if (length(not_completed) > 0L) {
    rlang::abort(
      sprintf("Retained trades are available only for completed candidates: %s.", paste(not_completed, collapse = ", ")),
      class = c("ledgr_sweep_trades_candidate_not_completed", "ledgr_invalid_args")
    )
  }
  n_trades <- if ("n_trades" %in% names(x)) stats::setNames(as.integer(x$n_trades), known) else stats::setNames(rep(NA_integer_, length(known)), known)
  required <- candidates[!is.na(n_trades[candidates]) & n_trades[candidates] > 0L]
  retained_ids <- unique(as.character(trades$candidate_id))
  missing_retained <- setdiff(required, retained_ids)
  if (length(missing_retained) > 0L) {
    rlang::abort(
      sprintf("Retained trades are missing for completed candidate_id: %s.", paste(missing_retained, collapse = ", ")),
      class = c("ledgr_sweep_trades_candidate_not_retained", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

ledgr_sweep_trades_validate_retained_completeness <- function(x, trades, candidates) {
  known <- as.character(x$candidate_id)
  status <- stats::setNames(as.character(x$status), known)
  n_trades <- if ("n_trades" %in% names(x)) {
    stats::setNames(as.integer(x$n_trades), known)
  } else {
    stats::setNames(rep(NA_integer_, length(known)), known)
  }
  completed <- candidates[status[candidates] == "DONE"]
  required <- completed[!is.na(n_trades[completed]) & n_trades[completed] > 0L]
  retained_ids <- unique(as.character(trades$candidate_id))
  missing_retained <- setdiff(required, retained_ids)
  if (length(missing_retained) > 0L) {
    rlang::abort(
      sprintf("Retained trades are missing for completed candidate_id: %s.", paste(missing_retained, collapse = ", ")),
      class = c("ledgr_sweep_trades_candidate_not_retained", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

#' @export
`[.ledgr_sweep_results` <- function(x, i, j, drop = FALSE) {
  out <- NextMethod("[")
  if (!is.data.frame(out) || isTRUE(drop)) {
    return(out)
  }
  ledgr_sweep_results_restore(out, x)
}

ledgr_sweep_results_restore <- function(out, template) {
  attr_names <- c(
    "sweep_id", "snapshot_id", "snapshot_hash", "scoring_range", "universe",
    "master_seed", "seed_contract", "evaluation_scope", "strategy_hash",
    "strategy_name", "strategy_source_capture_method", "strategy_preflight",
    "feature_union", "feature_union_hash", "feature_engine_version",
    "candidate_features", "metric_context", "metric_context_hash",
    "metric_context_version", "cost_model_hash", "cost_plan_json",
    "sweep_retention", "execution_assumptions", "saved_sweep"
  )
  for (name in attr_names) {
    attr(out, name) <- attr(template, name, exact = TRUE)
  }
  attr(out, "sweep_returns") <- ledgr_sweep_returns_filter_to_result(
    attr(template, "sweep_returns", exact = TRUE),
    out
  )
  attr(out, "sweep_trades") <- ledgr_sweep_trades_filter_to_result(
    attr(template, "sweep_trades", exact = TRUE),
    out
  )
  class(out) <- unique(c(
    intersect(c("ledgr_saved_sweep_results", "ledgr_sweep_results"), class(template)),
    class(out)
  ))
  out
}

ledgr_sweep_returns_filter_to_result <- function(returns, out) {
  if (!is.data.frame(returns) || !"candidate_id" %in% names(out)) {
    return(returns)
  }
  ledgr_sweep_returns_filter_and_order(returns, unique(as.character(out$candidate_id)))
}

ledgr_sweep_trades_filter_to_result <- function(trades, out) {
  if (!is.data.frame(trades) || !"candidate_id" %in% names(out)) {
    return(trades)
  }
  ledgr_sweep_trades_filter_and_order(trades, unique(as.character(out$candidate_id)))
}
