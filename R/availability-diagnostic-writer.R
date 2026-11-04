# Production diagnostic accumulation for availability-aware folds: the fold
# drains each pulse's typed staging (ledgr_fold_diagnostic_block()) into
# bounded typed column buffers. The durable output handler still owns the
# transaction and assigns diagnostic_seq at write time. Chunk capacity is an
# unexported constructor seam used by tests; ordinary folds use 65,536 rows.

# A chunk of 65,536 rows keeps the buffer bounded (a few megabytes) while a
# durable run makes about sixteen times fewer appends than with 4,096.
ledgr_fold_diagnostic_writer <- function(run_id,
                                         output_handler,
                                         chunk_rows = 65536L) {
  ledgr_columnar_diagnostic_writer(
    run_id,
    output_handler,
    chunk_rows = chunk_rows
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

ledgr_diagnostic_implicit_columns <- function(n) {
  chr <- function() character(n)
  int <- function() integer(n)
  dbl <- function() numeric(n)
  ts <- function() as.POSIXct(rep(NA_real_, n), origin = "1970-01-01", tz = "UTC")
  list(
    run_id = chr(), decision_seq = int(), execution_seq = int(),
    decision_order = int(), ts_utc = ts(),
    instrument_id = chr(), target = dbl(), position_before = dbl(),
    decision_price = dbl(), decision_mark_source = chr(), decision_mark_age = int(),
    fill_quantity = dbl(), fill_price = dbl(), execution_ts_utc = ts(),
    event_seq = int(), position_after = dbl()
  )
}

# Production column writer. Columns live in an environment so writes target
# stable preallocated vectors, and every column, character included, is
# written in place with collapse::setv(). The writer accepts one typed block
# per pulse: append_block() fills bounded chunks, splitting a block across a
# chunk boundary. A flush or release replaces the buffers with fresh vectors,
# so a frame handed to the output handler never shares a buffer that a later
# write changes.
ledgr_columnar_diagnostic_writer <- function(run_id,
                                             output_handler,
                                             chunk_rows = 4096L) {
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
  can_encode <- is.function(output_handler$write_run_diagnostic_implicit)
  implicit_cols <- if (can_encode) new.env(parent = emptyenv()) else NULL
  implicit_names <- if (can_encode) {
    names(ledgr_diagnostic_implicit_columns(0L))
  } else {
    character()
  }
  n <- 0L
  implicit_n <- 0L
  logical_count <- 0L
  reset <- function() {
    fresh <- ledgr_availability_diagnostic_columns(chunk_rows)
    for (nm in column_names) assign(nm, fresh[[nm]], envir = cols)
    n <<- 0L
    invisible(NULL)
  }
  reset()
  reset_implicit <- function() {
    if (!can_encode) {
      implicit_n <<- 0L
      return(invisible(NULL))
    }
    fresh <- ledgr_diagnostic_implicit_columns(chunk_rows)
    for (nm in implicit_names) assign(nm, fresh[[nm]], envir = implicit_cols)
    implicit_n <<- 0L
    invisible(NULL)
  }
  reset_implicit()
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
  build_implicit <- function(k) {
    out <- lapply(implicit_names, function(nm) {
      col <- get(nm, envir = implicit_cols)
      if (k < length(col)) col[seq_len(k)] else col
    })
    names(out) <- implicit_names
    as.data.frame(out, stringsAsFactors = FALSE)
  }
  flush_implicit <- function() {
    if (implicit_n == 0L) return(invisible(NULL))
    output_handler$write_run_diagnostic_implicit(build_implicit(implicit_n))
    reset_implicit()
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
      # Every column, character included, is written in place by index; a
      # copy-on-write assignment would copy the whole chunk per block.
      for (nm in column_names) {
        value <- if (whole) fields[[nm]] else fields[[nm]][src]
        collapse::setv(get(nm, envir = cols), dest, value, vind1 = TRUE)
      }
      n <<- n + take
      start <- start + take
    }
    invisible(NULL)
  }
  append_implicit <- function(fields) {
    if (!can_encode) {
      rlang::abort("Implicit diagnostics require a durable codec writer.", class = "ledgr_internal_error")
    }
    total <- fields$n
    start <- 1L
    while (start <= total) {
      if (implicit_n >= chunk_rows) flush_implicit()
      take <- min(chunk_rows - implicit_n, total - start + 1L)
      src <- seq.int(start, length.out = take)
      dest <- seq.int(implicit_n + 1L, length.out = take)
      for (nm in implicit_names) {
        collapse::setv(
          get(nm, envir = implicit_cols),
          dest,
          fields[[nm]][src],
          vind1 = TRUE
        )
      }
      implicit_n <<- implicit_n + take
      start <- start + take
    }
    invisible(NULL)
  }
  drain <- function() {
    flush()
    flush_implicit()
    if (is.function(output_handler$write_diagnostic_coverage)) {
      output_handler$write_diagnostic_coverage(logical_count)
    }
    if (is.function(output_handler$write_diagnostic_summary)) {
      output_handler$write_diagnostic_summary()
    }
    build(n)
  }
  list(
    keep = output_handler$diagnostic_keep,
    can_encode = can_encode,
    append_block = append_block,
    append_implicit = append_implicit,
    record_coverage = function(n) {
      logical_count <<- as.integer(n)
      invisible(NULL)
    },
    drain = drain,
    release = function() {
      reset()
      implicit_n <<- 0L
      implicit_cols <<- if (can_encode) new.env(parent = emptyenv()) else NULL
      logical_count <<- 0L
      invisible(NULL)
    }
  )
}
