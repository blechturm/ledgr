# Production diagnostic accumulation for availability-aware folds. The default
# path constructs one typed block per pulse and appends it to bounded typed
# column buffers. The durable output handler still owns the transaction and
# assigns diagnostic_seq at write time. Chunk capacity is an unexported
# constructor seam used by tests; ordinary folds always use 4096 rows.
#
# The exact "rows" and columnar-block-"off" selections retain the two reviewed
# reference arms until Batch 4 records parity and removes them. Malformed or
# absent selections take the production path. The mode stamp remains outside
# persisted values for that retirement gate.

ledgr_fold_diagnostic_writer <- function(run_id,
                                         output_handler,
                                         pulses_posix,
                                         chunk_rows = 4096L) {
  mode <- getOption("ledgr.internal.spike_diagnostic_writer", "columnar")
  block <- !identical(
    getOption("ledgr.internal.spike_diagnostic_block", "on"),
    "off"
  )
  writer <- if (identical(mode, "rows")) {
    ledgr_row_list_diagnostic_writer(run_id, pulses_posix)
  } else {
    ledgr_columnar_diagnostic_writer(
      run_id,
      output_handler,
      chunk_rows = chunk_rows,
      block = block
    )
  }
  attr(writer, "spike_diagnostic_mode") <- if (isTRUE(writer$block)) "block" else writer$mode
  writer
}

# Pre-promotion reference behaviour, retained temporarily for Batch 4 parity.
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
  release <- function() {
    diagnostic_rows <<- list()
    invisible(NULL)
  }
  list(
    mode = "rows",
    row = ledgr_availability_diagnostic_row,
    append = append,
    drain = drain,
    release = release
  )
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

# Build one typed diagnostic block per pulse. `segments`
# is a list of segment lists in emission order; each carries `n` (its row
# count) and, for any subset of the field names, a vector of length n or 1.
# Absent fields take the defaults of ledgr_availability_diagnostic_fields():
# `reasons` defaults to the segment's reason_code and `decision_ts_utc` to the
# pulse timestamp. Every row shares `ts_utc`; diagnostic_seq starts at
# `first_seq`. The result is a list of typed, unnamed vectors in the column
# order of ledgr_availability_diagnostic_columns(), the same values and
# coercions the scalar constructor applies row by row.
ledgr_availability_diagnostic_block <- function(run_id, ts_utc, first_seq, segments) {
  n_seg <- vapply(segments, function(s) as.integer(s$n), integer(1))
  n <- sum(n_seg)
  ts_num <- as.numeric(as.POSIXct(ts_utc, tz = "UTC"))
  to_seconds <- function(v) {
    if (inherits(v, "POSIXct") || is.numeric(v)) as.numeric(v) else as.numeric(as.POSIXct(v, tz = "UTC"))
  }
  segments <- lapply(segments, function(s) {
    if (is.null(s$reasons)) s$reasons <- if (is.null(s$reason_code)) "" else s$reason_code
    s
  })
  column <- function(name, default, coerce) {
    parts <- lapply(seq_along(segments), function(k) {
      v <- segments[[k]][[name]]
      if (is.null(v)) v <- default
      if (!length(v) %in% c(1L, n_seg[[k]])) {
        rlang::abort(sprintf("Diagnostic block field `%s` has length %d for a segment of %d rows.", name, length(v), n_seg[[k]]),
                     class = "ledgr_invalid_fold_execution")
      }
      rep_len(coerce(unname(v)), n_seg[[k]])
    })
    unlist(parts, use.names = FALSE)
  }
  ts_col <- function(name, default) .POSIXct(column(name, default, to_seconds), tz = "UTC")
  list(
    run_id = rep_len(as.character(run_id), n),
    diagnostic_seq = as.integer(first_seq) + seq_len(n) - 1L,
    ts_utc = .POSIXct(rep_len(ts_num, n), tz = "UTC"),
    instrument_id = column("instrument_id", "", as.character),
    stage = column("stage", NA_character_, as.character),
    outcome = column("outcome", NA_character_, as.character),
    reason_code = column("reason_code", "", as.character),
    reasons = column("reasons", "", as.character),
    target = column("target", NA_real_, as.numeric),
    quantity = column("quantity", NA_real_, as.numeric),
    price = column("price", NA_real_, as.numeric),
    mark_source = column("mark_source", "", as.character),
    mark_age = column("mark_age", NA_integer_, as.integer),
    decision_ts_utc = ts_col("decision_ts_utc", ts_num),
    execution_ts_utc = ts_col("execution_ts_utc", NA_real_),
    event_seq = column("event_seq", NA_integer_, as.integer),
    target_before_risk = column("target_before_risk", NA_real_, as.numeric),
    target_after_risk = column("target_after_risk", NA_real_, as.numeric),
    position_before = column("position_before", NA_real_, as.numeric),
    position_after = column("position_after", NA_real_, as.numeric),
    feature_identity_json = column("feature_identity_json", NA_character_, as.character),
    detail_json = column("detail_json", "{}", as.character)
  )
}

# Production column writer. Columns live in an environment so writes target
# stable preallocated vectors. Numeric, integer, and POSIXct writes use
# collapse::setv(); character writes use base replacement, the same split the
# production durable handler adopted in v0.1.8.9 (R/backtest-runner.R:381-394).
# With block = TRUE (diagnostic block spike) the writer also accepts one typed
# block per pulse: append_block() fills the same bounded chunks, splitting a
# block across a chunk boundary, with base block replacement for character
# columns and collapse::setv() vector writes for the others.
ledgr_columnar_diagnostic_writer <- function(run_id,
                                             output_handler,
                                             chunk_rows = 4096L,
                                             block = TRUE) {
  if (
    length(chunk_rows) != 1L ||
      !is.numeric(chunk_rows) ||
      is.na(chunk_rows) ||
      !is.finite(chunk_rows) ||
      chunk_rows < 1L ||
      chunk_rows != as.integer(chunk_rows)
  ) {
    rlang::abort(
      "`chunk_rows` must be a positive integer.",
      class = "ledgr_invalid_args"
    )
  }
  chunk_rows <- as.integer(chunk_rows)
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
  append_block <- function(fields) {
    if (!identical(names(fields), column_names)) {
      rlang::abort("Diagnostic block columns differ from the writer schema.", class = "ledgr_invalid_fold_execution")
    }
    total <- length(fields$diagnostic_seq)
    start <- 1L
    while (start <= total) {
      if (n >= chunk_rows) flush()
      take <- min(chunk_rows - n, total - start + 1L)
      whole <- take == total
      src <- if (whole) NULL else seq.int(start, length.out = take)
      dest <- seq.int(n + 1L, length.out = take)
      for (nm in column_names) {
        col <- get(nm, envir = cols)
        value <- if (whole) fields[[nm]] else fields[[nm]][src]
        if (is.character(col)) {
          col[dest] <- value
          assign(nm, col, envir = cols)
        } else {
          collapse::setv(col, dest, value, vind1 = TRUE)
        }
      }
      n <<- n + take
      start <- start + take
    }
    invisible(NULL)
  }
  drain <- function() {
    build(n)
  }
  list(
    mode = "columnar",
    block = isTRUE(block),
    row = ledgr_availability_diagnostic_fields,
    append = append,
    append_block = if (isTRUE(block)) append_block else NULL,
    drain = drain,
    release = reset
  )
}
