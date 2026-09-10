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
#'   `ledgr_sweep_trades()` returns retained closed-trade evidence with
#'   `sweep_id`, `candidate_id`, `candidate_row`, `trade_seq`, `close_ts_utc`,
#'   `realized_pnl`, and `win_loss`.
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
#'   one return/equity column per candidate. Candidate IDs that collide with the
#'   structural `ts_utc` column or the reserved `..ledgr_candidate_` prefix are
#'   represented by that prefix followed by their lowercase UTF-8 hex bytes.
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
    out[[ledgr_sweep_wide_candidate_name(id)]] <- values
  }
  out
}

ledgr_sweep_wide_candidate_prefix <- function() {
  "..ledgr_candidate_"
}

ledgr_sweep_wide_candidate_name <- function(candidate_id) {
  prefix <- ledgr_sweep_wide_candidate_prefix()
  if (!identical(candidate_id, "ts_utc") && !startsWith(candidate_id, prefix)) {
    return(candidate_id)
  }
  bytes <- charToRaw(enc2utf8(candidate_id))
  paste0(prefix, paste(sprintf("%02x", as.integer(bytes)), collapse = ""))
}

ledgr_sweep_wide_candidate_id <- function(column_name) {
  prefix <- ledgr_sweep_wide_candidate_prefix()
  if (!startsWith(column_name, prefix)) {
    return(column_name)
  }
  encoded <- substring(column_name, nchar(prefix) + 1L)
  valid <- nzchar(encoded) && nchar(encoded) %% 2L == 0L &&
    grepl("^[0-9a-f]+$", encoded)
  if (!isTRUE(valid)) {
    rlang::abort(
      "Invalid reserved candidate column encoding.",
      class = c("ledgr_invalid_sweep_projection", "ledgr_invalid_args")
    )
  }
  starts <- seq.int(1L, nchar(encoded), by = 2L)
  bytes <- as.raw(strtoi(substring(encoded, starts, starts + 1L), base = 16L))
  candidate_id <- rawToChar(bytes)
  Encoding(candidate_id) <- "UTF-8"
  candidate_id
}

#' Return panel evidence
#'
#' `ledgr_return_panel()` constructs the classed return-panel evidence object
#' consumed by ledgr's selection-integrity diagnostics. The input is clean
#' period returns: do not include the structural first-row `NA` used by retained
#' sweep returns. Use [ledgr_sweep_returns_panel()] for the sweep-sourced
#' accessor.
#'
#' @param returns A wide numeric matrix/data frame with one candidate per
#'   column, or a tidy long data frame with `candidate_id` and `period_return`
#'   columns plus at most one ordering column (`ts_utc`, `ts`, `period_label`,
#'   or `period`).
#' @param ts Optional `Date` or `POSIXct` ordering labels for wide inputs. When
#'   `NULL`, deterministic labels `period_000001`, `period_000002`, ... are
#'   used.
#' @param value Character scalar. Only `"returns"` is supported in v1.
#' @return A `ledgr_return_panel` object.
#' @examples
#' returns <- data.frame(
#'   conservative = c(0.004, -0.011, 0.006, 0.002),
#'   balanced = c(0.009, -0.004, 0.012, -0.001)
#' )
#' panel <- ledgr_return_panel(returns)
#' panel$panel_hash
#' @export
ledgr_return_panel <- function(returns,
                               ts = NULL,
                               value = c("returns")) {
  value <- match.arg(value)
  if (inherits(returns, "ledgr_return_panel")) {
    rlang::abort(
      "`returns` is already a ledgr_return_panel object.",
      class = c("ledgr_invalid_return_panel", "ledgr_invalid_args")
    )
  }
  shape <- ledgr_return_panel_detect_shape(returns)
  if (identical(shape, "wide")) {
    m <- ledgr_return_panel_wide_matrix(returns)
    labels <- ledgr_return_panel_labels(ts, nrow(m))
    return(ledgr_return_panel_build(
      matrix = m,
      labels = labels$labels,
      ts_utc = labels$ts_utc,
      value = value,
      source = "user_return_panel",
      first_row_dropped = FALSE,
      completed_candidate_ids = colnames(m),
      excluded_candidate_ids = character(),
      sweep_id = NA_character_,
      metric_context_hash = NA_character_,
      cost_model_hash = NA_character_,
      risk_chain_hash = NA_character_,
      input_identity = NULL
    ))
  }

  ledgr_return_panel_from_long(returns, value = value)
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
  labels <- ledgr_sweep_returns_ts_labels(ts_utc)
  identity <- ledgr_return_panel_sweep_identity(x)

  ledgr_return_panel_build(
    matrix = mat,
    labels = labels,
    ts_utc = ts_utc,
    value = value,
    source = "retained_sweep_returns",
    first_row_dropped = drop_first,
    completed_candidate_ids = completed,
    excluded_candidate_ids = excluded,
    sweep_id = identity$sweep_id,
    snapshot_hash = identity$snapshot_hash,
    metric_context_hash = identity$metric_context_hash,
    cost_model_hash = identity$cost_model_hash,
    risk_chain_hash = identity$risk_chain_hash,
    input_identity = identity,
    long = ledgr_sweep_returns_panel_long(rows_by_candidate),
    complete = isTRUE(complete),
    extra_class = "ledgr_sweep_returns_panel"
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

ledgr_return_panel_resolve <- function(x,
                                       candidates = NULL,
                                       value = c("returns"),
                                       complete = TRUE) {
  value <- match.arg(value)
  if (inherits(x, "ledgr_return_panel")) {
    ledgr_return_panel_validate(x)
    if (!identical(x$value, value)) {
      rlang::abort(
        sprintf("Return panel value `%s` is not supported for `%s` diagnostics.", x$value, value),
        class = c("ledgr_invalid_return_panel", "ledgr_invalid_args")
      )
    }
    candidates <- ledgr_sweep_returns_normalize_candidates(candidates)
    if (is.null(candidates)) {
      return(x)
    }
    return(ledgr_return_panel_subset(x, candidates))
  }
  if (inherits(x, "ledgr_sweep_results")) {
    return(ledgr_sweep_returns_panel(
      x,
      candidates = candidates,
      value = value,
      complete = complete
    ))
  }
  rlang::abort(
    "`x` must be a ledgr_return_panel or ledgr_sweep_results object. Raw matrices and data frames must be wrapped with ledgr_return_panel() first.",
    class = c("ledgr_invalid_return_panel_input", "ledgr_invalid_args")
  )
}

ledgr_return_panel_detect_shape <- function(returns) {
  if (is.matrix(returns)) {
    return("wide")
  }
  if (!is.data.frame(returns)) {
    rlang::abort(
      "`returns` must be a numeric matrix, wide data frame, or tidy long data frame.",
      class = c("ledgr_invalid_return_panel_input", "ledgr_invalid_args")
    )
  }
  has_candidate <- "candidate_id" %in% names(returns)
  has_return <- "period_return" %in% names(returns)
  if (xor(has_candidate, has_return)) {
    rlang::abort(
      "Return-panel data frames with `candidate_id` or `period_return` must include both columns for tidy-long input.",
      class = c("ledgr_return_panel_ambiguous_shape", "ledgr_invalid_args")
    )
  }
  if (has_candidate && has_return) {
    allowed <- c("candidate_id", "period_return", "ts_utc", "ts", "period_label", "period")
    extra <- setdiff(names(returns), allowed)
    if (length(extra) > 0L) {
      rlang::abort(
        sprintf(
          "Return-panel tidy-long input has unsupported columns: %s. Use only candidate_id, period_return, and one ordering column.",
          paste(extra, collapse = ", ")
        ),
        class = c("ledgr_return_panel_ambiguous_shape", "ledgr_invalid_args"),
        columns = extra
      )
    }
    return("long")
  }
  "wide"
}

ledgr_return_panel_wide_matrix <- function(returns) {
  m <- as.matrix(returns)
  storage.mode(m) <- "double"
  ledgr_return_panel_validate_matrix(m)
  m
}

ledgr_return_panel_validate_matrix <- function(m, allow_missing = FALSE) {
  if (!is.matrix(m) || !is.numeric(m)) {
    rlang::abort(
      "Return panels require a numeric return matrix.",
      class = c("ledgr_invalid_return_panel", "ledgr_invalid_args")
    )
  }
  if (nrow(m) < 1L || ncol(m) < 1L) {
    rlang::abort(
      "Return panels require at least one period and one candidate.",
      class = c("ledgr_invalid_return_panel", "ledgr_invalid_args")
    )
  }
  non_finite <- !is.finite(m)
  if (any(non_finite & !is.na(m))) {
    rlang::abort(
      "Return panels require finite period returns.",
      class = c("ledgr_invalid_return_panel", "ledgr_invalid_args")
    )
  }
  if (anyNA(m) && !isTRUE(allow_missing)) {
    rlang::abort(
      "Return panels require finite period returns with no missing values.",
      class = c("ledgr_invalid_return_panel", "ledgr_invalid_args")
    )
  }
  ids <- colnames(m)
  if (is.null(ids) ||
      length(ids) != ncol(m) ||
      anyNA(ids) ||
      any(!nzchar(ids)) ||
      anyDuplicated(ids)) {
    rlang::abort(
      "Return panels require non-empty unique candidate ids in column names.",
      class = c("ledgr_return_panel_missing_candidate_ids", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

ledgr_return_panel_labels <- function(ts, n) {
  if (is.null(ts)) {
    labels <- sprintf("period_%06d", seq_len(n))
    return(list(labels = labels, ts_utc = labels))
  }
  if (inherits(ts, "Date")) {
    ts <- as.POSIXct(ts, tz = "UTC")
  } else if (inherits(ts, "POSIXt")) {
    ts <- as.POSIXct(ts, tz = "UTC")
  } else {
    rlang::abort(
      "`ts` must be NULL, Date, or POSIXct.",
      class = c("ledgr_return_panel_invalid_ts", "ledgr_invalid_args")
    )
  }
  if (length(ts) != n || anyNA(ts)) {
    rlang::abort(
      "`ts` must have one non-missing value per return row.",
      class = c("ledgr_return_panel_invalid_ts", "ledgr_invalid_args")
    )
  }
  if (anyDuplicated(as.numeric(ts))) {
    rlang::abort(
      "`ts` values must be unique.",
      class = c("ledgr_return_panel_invalid_ts", "ledgr_invalid_args")
    )
  }
  ord <- order(as.numeric(ts))
  if (!identical(ord, seq_along(ts))) {
    rlang::abort(
      "`ts` must be in ascending order.",
      class = c("ledgr_return_panel_invalid_ts", "ledgr_invalid_args")
    )
  }
  list(labels = ledgr_sweep_returns_ts_labels(ts), ts_utc = ts)
}

ledgr_return_panel_from_long <- function(returns, value) {
  label_columns <- intersect(c("ts_utc", "ts", "period_label", "period"), names(returns))
  if (length(label_columns) > 1L) {
    rlang::abort(
      sprintf("Tidy return-panel input must use at most one ordering column; found %s.", paste(label_columns, collapse = ", ")),
      class = c("ledgr_return_panel_ambiguous_shape", "ledgr_invalid_args"),
      columns = label_columns
    )
  }
  if (nrow(returns) < 1L) {
    rlang::abort(
      "Return panels require at least one row.",
      class = c("ledgr_invalid_return_panel", "ledgr_invalid_args")
    )
  }
  ids <- as.character(returns$candidate_id)
  if (anyNA(ids) || any(!nzchar(ids))) {
    rlang::abort(
      "Tidy return-panel input requires non-empty candidate_id values.",
      class = c("ledgr_return_panel_missing_candidate_ids", "ledgr_invalid_args")
    )
  }
  returns$.__candidate_id <- ids
  returns$.__return <- as.numeric(returns$period_return)
  if (anyNA(returns$.__return) || any(!is.finite(returns$.__return))) {
    rlang::abort(
      "Return panels require finite period returns with no missing values.",
      class = c("ledgr_invalid_return_panel", "ledgr_invalid_args")
    )
  }

  candidate_ids <- unique(ids)
  label_info <- ledgr_return_panel_long_labels(returns, label_columns)
  labels <- label_info$labels
  m <- matrix(
    NA_real_,
    nrow = length(labels),
    ncol = length(candidate_ids),
    dimnames = list(labels, candidate_ids)
  )
  label_index <- match(label_info$row_labels, labels)
  candidate_index <- match(ids, candidate_ids)
  key <- paste(candidate_index, label_index, sep = "\r")
  if (anyDuplicated(key)) {
    rlang::abort(
      "Tidy return-panel input has duplicate candidate_id/order-label rows.",
      class = c("ledgr_invalid_return_panel", "ledgr_invalid_args")
    )
  }
  m[cbind(label_index, candidate_index)] <- returns$.__return
  if (anyNA(m)) {
    rlang::abort(
      "Tidy return-panel input must contain a complete candidate x period grid.",
      class = c("ledgr_sweep_returns_incomplete_panel", "ledgr_validation_pbo_incomplete_panel", "ledgr_invalid_args"),
      candidate_ids = candidate_ids
    )
  }

  ledgr_return_panel_build(
    matrix = m,
    labels = labels,
    ts_utc = label_info$ts_utc,
    value = value,
    source = "user_return_panel",
    first_row_dropped = FALSE,
    completed_candidate_ids = candidate_ids,
    excluded_candidate_ids = character(),
    sweep_id = NA_character_,
    metric_context_hash = NA_character_,
    cost_model_hash = NA_character_,
    risk_chain_hash = NA_character_,
    input_identity = NULL
  )
}

ledgr_return_panel_long_labels <- function(returns, label_columns) {
  if (length(label_columns) == 0L) {
    counts <- stats::ave(seq_len(nrow(returns)), returns$.__candidate_id, FUN = seq_along)
    labels <- sprintf("period_%06d", as.integer(counts))
    n_periods <- max(as.integer(counts))
    panel_labels <- sprintf("period_%06d", seq_len(n_periods))
    return(list(
      labels = panel_labels,
      row_labels = labels,
      ts_utc = panel_labels
    ))
  }
  label_col <- label_columns[[1L]]
  values <- returns[[label_col]]
  if (inherits(values, "Date")) {
    values <- as.POSIXct(values, tz = "UTC")
  }
  if (inherits(values, "POSIXt")) {
    if (anyNA(values)) {
      rlang::abort(
        "Return-panel ordering labels must not be missing.",
        class = c("ledgr_return_panel_invalid_ts", "ledgr_invalid_args")
      )
    }
    values <- as.POSIXct(values, tz = "UTC")
    labels <- ledgr_sweep_returns_ts_labels(values)
    all_ts <- sort(unique(as.numeric(values)))
    return(list(
      labels = ledgr_sweep_returns_ts_labels(as.POSIXct(all_ts, origin = "1970-01-01", tz = "UTC")),
      row_labels = labels,
      ts_utc = as.POSIXct(all_ts, origin = "1970-01-01", tz = "UTC")
    ))
  }
  labels <- as.character(values)
  if (anyNA(labels) || any(!nzchar(labels))) {
    rlang::abort(
      "Return-panel ordering labels must not be missing or empty.",
      class = c("ledgr_return_panel_invalid_ts", "ledgr_invalid_args")
    )
  }
  unique_labels <- sort(unique(labels))
  list(labels = unique_labels, row_labels = labels, ts_utc = unique_labels)
}

ledgr_return_panel_build <- function(matrix,
                                     labels,
                                     ts_utc,
                                     value,
                                     source,
                                     first_row_dropped,
                                     completed_candidate_ids,
                                     excluded_candidate_ids,
                                     sweep_id,
                                     snapshot_hash = NA_character_,
                                     metric_context_hash,
                                     cost_model_hash,
                                     risk_chain_hash,
                                     input_identity,
                                     long = NULL,
                                     complete = TRUE,
                                     extra_class = NULL) {
  ledgr_return_panel_validate_matrix(matrix, allow_missing = !isTRUE(complete))
  labels <- as.character(labels)
  if (length(labels) != nrow(matrix) ||
      anyNA(labels) ||
      any(!nzchar(labels)) ||
      anyDuplicated(labels)) {
    rlang::abort(
      "Return-panel labels must be non-empty unique values with one label per row.",
      class = c("ledgr_invalid_return_panel", "ledgr_invalid_args")
    )
  }
  rownames(matrix) <- labels
  candidate_ids <- colnames(matrix)
  if (is.null(long)) {
    long <- ledgr_return_panel_long_from_matrix(
      matrix = matrix,
      labels = labels,
      ts_utc = ts_utc,
      sweep_id = sweep_id
    )
  }
  out <- list(
    long = long,
    matrix = matrix,
    ts_utc = ts_utc,
    labels = labels,
    candidate_ids = candidate_ids,
    completed_candidate_ids = as.character(completed_candidate_ids),
    excluded_candidate_ids = as.character(excluded_candidate_ids),
    value = value,
    source = source,
    panel_hash = ledgr_return_panel_hash(matrix, labels, value),
    first_row_dropped = isTRUE(first_row_dropped),
    complete = isTRUE(complete),
    sweep_id = as.character(sweep_id %||% NA_character_),
    snapshot_hash = as.character(snapshot_hash %||% NA_character_),
    metric_context_hash = as.character(metric_context_hash %||% NA_character_),
    cost_model_hash = as.character(cost_model_hash %||% NA_character_),
    risk_chain_hash = as.character(risk_chain_hash %||% NA_character_),
    input_identity = input_identity
  )
  class(out) <- c("ledgr_return_panel", extra_class, "list")
  out
}

ledgr_return_panel_long_from_matrix <- function(matrix, labels, ts_utc, sweep_id) {
  rows <- lapply(seq_len(ncol(matrix)), function(j) {
    tibble::tibble(
      sweep_id = rep(as.character(sweep_id %||% NA_character_), nrow(matrix)),
      candidate_id = rep(colnames(matrix)[[j]], nrow(matrix)),
      ts_utc = ts_utc,
      equity = rep(NA_real_, nrow(matrix)),
      period_return = as.numeric(matrix[, j])
    )
  })
  tibble::as_tibble(do.call(rbind, rows))
}

ledgr_return_panel_hash <- function(matrix, labels, value) {
  payload <- list(
    schema = "ledgr_return_panel_v1",
    value = value,
    candidate_ids = unname(colnames(matrix)),
    labels = unname(as.character(labels)),
    returns = unname(lapply(seq_len(nrow(matrix)), function(i) {
      unname(lapply(as.numeric(matrix[i, ]), function(x) {
        if (is.na(x)) {
          return("NA_REAL")
        }
        x
      }))
    }))
  )
  digest::digest(canonical_json(payload), algo = "sha256")
}

ledgr_return_panel_validate <- function(x) {
  if (!inherits(x, "ledgr_return_panel") || !is.list(x)) {
    rlang::abort(
      "`x` must be a ledgr_return_panel object.",
      class = c("ledgr_invalid_return_panel", "ledgr_invalid_args")
    )
  }
  required <- c(
    "matrix", "labels", "candidate_ids", "value", "source", "panel_hash",
    "first_row_dropped", "complete"
  )
  missing <- setdiff(required, names(x))
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf("Malformed return panel is missing fields: %s.", paste(missing, collapse = ", ")),
      class = c("ledgr_invalid_return_panel", "ledgr_invalid_args"),
      missing_fields = missing
    )
  }
  ledgr_return_panel_validate_matrix(x$matrix, allow_missing = !isTRUE(x$complete))
  expected <- ledgr_return_panel_hash(x$matrix, x$labels, x$value)
  if (!identical(x$panel_hash, expected)) {
    rlang::abort(
      "Return-panel hash does not match its normalized evidence.",
      class = c("ledgr_invalid_return_panel", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

ledgr_return_panel_subset <- function(panel, candidates) {
  missing <- setdiff(candidates, panel$candidate_ids)
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf("Unknown return-panel candidate_id: %s.", paste(missing, collapse = ", ")),
      class = c("ledgr_sweep_returns_candidate_not_found", "ledgr_invalid_args"),
      candidate_ids = missing
    )
  }
  m <- panel$matrix[, candidates, drop = FALSE]
  long <- panel$long[as.character(panel$long$candidate_id) %in% candidates, , drop = FALSE]
  excluded <- union(panel$excluded_candidate_ids, setdiff(panel$candidate_ids, candidates))
  ledgr_return_panel_build(
    matrix = m,
    labels = panel$labels,
    ts_utc = panel$ts_utc,
    value = panel$value,
    source = panel$source,
    first_row_dropped = isTRUE(panel$first_row_dropped),
    completed_candidate_ids = panel$completed_candidate_ids,
    excluded_candidate_ids = excluded,
    sweep_id = panel$sweep_id,
    snapshot_hash = panel$snapshot_hash,
    metric_context_hash = panel$metric_context_hash,
    cost_model_hash = panel$cost_model_hash,
    risk_chain_hash = panel$risk_chain_hash,
    input_identity = panel$input_identity,
    long = tibble::as_tibble(long),
    complete = isTRUE(panel$complete),
    extra_class = setdiff(class(panel), c("ledgr_return_panel", "list"))
  )
}

ledgr_return_panel_sweep_identity <- function(sweep) {
  list(
    sweep_id = ledgr_return_panel_scalar_attr(sweep, "sweep_id"),
    snapshot_hash = ledgr_return_panel_scalar_attr(sweep, "snapshot_hash"),
    metric_context_hash = ledgr_return_panel_scalar_attr(sweep, "metric_context_hash"),
    cost_model_hash = ledgr_return_panel_scalar_attr(sweep, "cost_model_hash"),
    risk_chain_hash = ledgr_return_panel_scalar_attr(sweep, "risk_chain_hash")
  )
}

ledgr_return_panel_scalar_attr <- function(x, name) {
  value <- attr(x, name, exact = TRUE)
  if (is.character(value) && length(value) == 1L && !is.na(value) && nzchar(value)) {
    return(as.character(value))
  }
  NA_character_
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
    "risk_chain_hash", "risk_plan_json",
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
