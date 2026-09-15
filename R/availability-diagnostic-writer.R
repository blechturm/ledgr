# Spike seam for the availability hot-path representation RFC (Charter v2).
#
# Selects, once per fold, how availability diagnostics are accumulated before
# persistence. Mode "rows" is the unchanged production path: one data frame per
# diagnostic row, retained in a list, bound once with do.call(rbind, ...).
# Mode "columnar" is the single chartered alternative: typed column buffers of
# bounded capacity, manifested as one data frame per chunk and flushed through
# the existing output handler, which still owns the transaction and assigns
# diagnostic_seq at write time. Schema, values, order, reason vocabulary, and
# persisted rows are unchanged. The mode is read once from
# options(ledgr.internal.spike_diagnostic_writer); the default is "rows".

ledgr_fold_diagnostic_writer <- function(run_id, output_handler, pulses_posix) {
  mode <- getOption("ledgr.internal.spike_diagnostic_writer", "rows")
  if (identical(mode, "columnar")) {
    chunk_rows <- as.integer(getOption("ledgr.internal.spike_diagnostic_chunk_rows", 4096L))
    if (length(chunk_rows) != 1L || is.na(chunk_rows) || chunk_rows < 1L) {
      rlang::abort("`ledgr.internal.spike_diagnostic_chunk_rows` must be a positive integer.", class = "ledgr_invalid_args")
    }
    return(ledgr_columnar_diagnostic_writer(run_id, output_handler, chunk_rows))
  }
  ledgr_row_list_diagnostic_writer(run_id, pulses_posix)
}

# Production behaviour, moved verbatim behind the seam.
ledgr_row_list_diagnostic_writer <- function(run_id, pulses_posix) {
  diagnostic_rows <- list()
  append <- function(row, diagnostic_seq) {
    row$diagnostic_seq <- diagnostic_seq
    diagnostic_rows[[diagnostic_seq]] <<- row
    invisible(NULL)
  }
  drain <- function() {
    if (length(diagnostic_rows) == 0L) {
      return(ledgr_availability_diagnostic_row(
        run_id = run_id,
        diagnostic_seq = 1L,
        ts_utc = pulses_posix[[1L]],
        stage = "decision",
        outcome = "observed",
        reason_code = "no_diagnostics"
      )[0, , drop = FALSE])
    }
    do.call(rbind, diagnostic_rows)
  }
  list(mode = "rows", row = ledgr_availability_diagnostic_row, append = append, drain = drain)
}

# Same signature, defaults, and coercions as ledgr_availability_diagnostic_row(),
# returning a typed list of scalars instead of a one-row data frame.
ledgr_availability_diagnostic_fields <- function(run_id,
                                                 diagnostic_seq,
                                                 ts_utc,
                                                 instrument_id = "",
                                                 stage,
                                                 outcome,
                                                 reason_code = "",
                                                 reasons = reason_code,
                                                 target = NA_real_,
                                                 quantity = NA_real_,
                                                 price = NA_real_,
                                                 mark_source = "",
                                                 mark_age = NA_integer_,
                                                 decision_ts_utc = ts_utc,
                                                 execution_ts_utc = as.POSIXct(NA, tz = "UTC"),
                                                 event_seq = NA_integer_,
                                                 target_before_risk = NA_real_,
                                                 target_after_risk = NA_real_,
                                                 position_before = NA_real_,
                                                 position_after = NA_real_,
                                                 feature_identity_json = NA_character_,
                                                 detail_json = "{}") {
  list(
    run_id = as.character(run_id),
    diagnostic_seq = as.integer(diagnostic_seq),
    ts_utc = as.POSIXct(ts_utc, tz = "UTC"),
    instrument_id = as.character(instrument_id),
    stage = as.character(stage),
    outcome = as.character(outcome),
    reason_code = as.character(reason_code),
    reasons = as.character(reasons),
    target = as.numeric(target),
    quantity = as.numeric(quantity),
    price = as.numeric(price),
    mark_source = as.character(mark_source),
    mark_age = as.integer(mark_age),
    decision_ts_utc = as.POSIXct(decision_ts_utc, tz = "UTC"),
    execution_ts_utc = as.POSIXct(execution_ts_utc, tz = "UTC"),
    event_seq = as.integer(event_seq),
    target_before_risk = as.numeric(target_before_risk),
    target_after_risk = as.numeric(target_after_risk),
    position_before = as.numeric(position_before),
    position_after = as.numeric(position_after),
    feature_identity_json = as.character(feature_identity_json),
    detail_json = as.character(detail_json)
  )
}

ledgr_availability_diagnostic_columns <- function(n) {
  chr <- function() character(n)
  int <- function() integer(n)
  dbl <- function() numeric(n)
  ts <- function() as.POSIXct(rep(NA_real_, n), origin = "1970-01-01", tz = "UTC")
  list(
    run_id = chr(), diagnostic_seq = int(), ts_utc = ts(), instrument_id = chr(),
    stage = chr(), outcome = chr(), reason_code = chr(), reasons = chr(),
    target = dbl(), quantity = dbl(), price = dbl(), mark_source = chr(),
    mark_age = int(), decision_ts_utc = ts(), execution_ts_utc = ts(),
    event_seq = int(), target_before_risk = dbl(), target_after_risk = dbl(),
    position_before = dbl(), position_after = dbl(),
    feature_identity_json = chr(), detail_json = chr()
  )
}

# The chartered alternative. Columns live in an environment so writes target
# stable preallocated vectors. Numeric, integer, and POSIXct writes use
# collapse::setv(); character writes use base replacement, the same split the
# production durable handler adopted in v0.1.8.9 (R/backtest-runner.R:381-394).
ledgr_columnar_diagnostic_writer <- function(run_id, output_handler, chunk_rows) {
  cols <- new.env(parent = emptyenv())
  column_names <- names(ledgr_availability_diagnostic_columns(0L))
  n <- 0L
  reset <- function() {
    fresh <- ledgr_availability_diagnostic_columns(chunk_rows)
    for (nm in column_names) assign(nm, fresh[[nm]], envir = cols)
    n <<- 0L
    invisible(NULL)
  }
  reset()
  put <- function(nm, i, value) {
    col <- get(nm, envir = cols)
    if (is.character(col)) {
      col[[i]] <- value
      assign(nm, col, envir = cols)
      return(invisible(NULL))
    }
    collapse::setv(col, i, value, vind1 = TRUE)
    invisible(NULL)
  }
  build <- function(k) {
    out <- lapply(column_names, function(nm) {
      col <- get(nm, envir = cols)
      if (k < length(col)) col[seq_len(k)] else col
    })
    names(out) <- column_names
    as.data.frame(out, stringsAsFactors = FALSE)
  }
  flush <- function() {
    if (n == 0L) return(invisible(NULL))
    output_handler$write_run_diagnostics(build(n))
    reset()
    invisible(NULL)
  }
  append <- function(fields, diagnostic_seq) {
    if (n >= chunk_rows) flush()
    i <- n + 1L
    fields$diagnostic_seq <- as.integer(diagnostic_seq)
    for (nm in column_names) put(nm, i, fields[[nm]])
    n <<- i
    invisible(NULL)
  }
  drain <- function() {
    out <- build(n)
    reset()
    out
  }
  list(mode = "columnar", row = ledgr_availability_diagnostic_fields, append = append, drain = drain)
}
