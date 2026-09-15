# Prerequisite probe for the remaining availability-diagnostics hot path.
#
# This is spike_protocol.md section 1 work. It is not a Charter, production
# implementation, semantic acceptance suite, or public benchmark. It changes
# no package file.
#
# One question:
#   At the registered 757-pulse by 505-instrument shape, can constructing and
#   appending one typed diagnostic block per pulse remove at least 75% of the
#   wall used by the reviewed scalar-fields-plus-row-append path, while
#   producing byte-identical R values across a chunk boundary?
#
# The 75% threshold is only a prerequisite routing rule. A later Charter must
# register the full-fold wall, memory, persistence, failure, resume, and reopen
# evidence required for production adoption.
#
# Run from any directory:
#   LEDGR_PROBE_LIB=<library-with-collapse-2.1.8> Rscript \
#     dev/spikes/availability-diagnostic-block-write/probe.R

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 0L) stop("This probe takes no arguments.")

script_path <- local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(file_arg) == 0L) stop("Run this probe with Rscript.")
  normalizePath(sub("^--file=", "", file_arg[[1L]]), winslash = "/")
})
probe_dir <- dirname(script_path)
repo_root <- normalizePath(file.path(probe_dir, "..", "..", ".."), winslash = "/")
probe_library <- Sys.getenv("LEDGR_PROBE_LIB", unset = "")
if (!nzchar(probe_library) || !dir.exists(probe_library)) {
  stop("LEDGR_PROBE_LIB must name a library containing collapse 2.1.8.")
}
.libPaths(c(normalizePath(probe_library, winslash = "/"), .libPaths()))
if (!identical(as.character(utils::packageVersion("collapse")), "2.1.8")) {
  stop("The probe requires exactly collapse 2.1.8.")
}
pkgload::load_all(repo_root, quiet = TRUE, export_all = TRUE)

SPEC <- list(
  pulses = 757L,
  instruments = 505L,
  rows_per_pulse = 506L,
  rows = 383042L,
  chunk_rows = 4096L,
  repetitions = 3L,
  reduction_required = 0.75
)
stopifnot(SPEC$pulses * SPEC$rows_per_pulse == SPEC$rows)

ids <- sprintf("I%03d", seq_len(SPEC$instruments))
first_cutoff <- as.POSIXct("2021-01-04 21:00:00", tz = "UTC")
cutoffs <- first_cutoff + (seq_len(SPEC$pulses) - 1L) * 86400
na_ts <- as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")

scalar_fields <- function(pulse, row_in_pulse, diagnostic_seq) {
  portfolio <- row_in_pulse > SPEC$instruments
  instrument <- if (portfolio) "" else ids[[row_in_pulse]]
  target <- if (portfolio) NA_real_ else row_in_pulse / 1000
  quantity <- if (portfolio) NA_real_ else 0
  price <- if (portfolio) NA_real_ else 100 + row_in_pulse / 10
  mark_age <- if (portfolio) NA_integer_ else as.integer((row_in_pulse - 1L) %% 3L)
  reason <- if (portfolio) "portfolio_reconciled" else "decision_recorded"
  ledgr_availability_diagnostic_fields(
    run_id = "diagnostic-prerequisite",
    diagnostic_seq = diagnostic_seq,
    ts_utc = cutoffs[[pulse]],
    instrument_id = instrument,
    stage = if (portfolio) "valuation" else "decision",
    outcome = if (portfolio) "reconciled" else "recorded",
    reason_code = reason,
    reasons = reason,
    target = target,
    quantity = quantity,
    price = price,
    mark_source = if (portfolio) "" else "current_close",
    mark_age = mark_age,
    decision_ts_utc = cutoffs[[pulse]],
    execution_ts_utc = na_ts,
    event_seq = NA_integer_,
    target_before_risk = target,
    target_after_risk = target,
    position_before = quantity,
    position_after = quantity,
    feature_identity_json = NA_character_,
    detail_json = "{}"
  )
}

pulse_block <- function(pulse, first_seq) {
  idx <- seq_len(SPEC$instruments)
  n <- SPEC$rows_per_pulse
  ts <- cutoffs[[pulse]]
  target <- c(idx / 1000, NA_real_)
  quantity <- c(numeric(SPEC$instruments), NA_real_)
  price <- c(100 + idx / 10, NA_real_)
  reason <- c(rep("decision_recorded", SPEC$instruments), "portfolio_reconciled")
  list(
    run_id = rep("diagnostic-prerequisite", n),
    diagnostic_seq = as.integer(first_seq + seq_len(n) - 1L),
    ts_utc = rep(ts, n),
    instrument_id = c(ids, ""),
    stage = c(rep("decision", SPEC$instruments), "valuation"),
    outcome = c(rep("recorded", SPEC$instruments), "reconciled"),
    reason_code = reason,
    reasons = reason,
    target = target,
    quantity = quantity,
    price = price,
    mark_source = c(rep("current_close", SPEC$instruments), ""),
    mark_age = c(as.integer((idx - 1L) %% 3L), NA_integer_),
    decision_ts_utc = rep(ts, n),
    execution_ts_utc = rep(na_ts, n),
    event_seq = rep(NA_integer_, n),
    target_before_risk = target,
    target_after_risk = target,
    position_before = quantity,
    position_after = quantity,
    feature_identity_json = rep(NA_character_, n),
    detail_json = rep("{}", n)
  )
}

block_writer <- function(output_handler, chunk_rows) {
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
  append_block <- function(fields) {
    if (!identical(names(fields), column_names)) stop("Diagnostic block schema differs.")
    total <- length(fields[[1L]])
    if (any(lengths(fields) != total)) stop("Diagnostic block columns differ in length.")
    source_start <- 1L
    while (source_start <= total) {
      if (n >= chunk_rows) flush()
      take <- min(chunk_rows - n, total - source_start + 1L)
      source_idx <- seq.int(source_start, length.out = take)
      dest_idx <- seq.int(n + 1L, length.out = take)
      for (nm in column_names) {
        col <- get(nm, envir = cols)
        value <- fields[[nm]][source_idx]
        if (is.character(col)) {
          col[dest_idx] <- value
          assign(nm, col, envir = cols)
        } else {
          collapse::setv(col, dest_idx, value, vind1 = TRUE)
        }
      }
      n <<- n + take
      source_start <- source_start + take
    }
    invisible(NULL)
  }
  drain <- function() {
    out <- build(n)
    reset()
    out
  }
  list(append_block = append_block, drain = drain)
}

counting_handler <- function(capture = FALSE) {
  state <- new.env(parent = emptyenv())
  state$rows <- 0L
  state$frames <- 0L
  state$last_seq <- 0L
  state$chunks <- list()
  consume <- function(x) {
    if (!is.data.frame(x)) stop("Writer did not manifest a data frame.")
    if (!identical(names(x), names(ledgr_availability_diagnostic_columns(0L)))) {
      stop("Manifested diagnostic schema differs.")
    }
    if (nrow(x) > 0L) {
      expected <- seq.int(state$last_seq + 1L, length.out = nrow(x))
      if (!identical(x$diagnostic_seq, as.integer(expected))) stop("Sequence differs.")
      state$last_seq <- x$diagnostic_seq[[nrow(x)]]
    }
    state$rows <- state$rows + nrow(x)
    state$frames <- state$frames + 1L
    if (capture) state$chunks[[length(state$chunks) + 1L]] <- x
    invisible(NULL)
  }
  list(
    output = list(write_run_diagnostics = consume),
    consume = consume,
    state = state
  )
}

run_scalar <- function(n_pulses, capture = FALSE) {
  handler <- counting_handler(capture)
  writer <- ledgr_columnar_diagnostic_writer(
    "diagnostic-prerequisite", handler$output, SPEC$chunk_rows
  )
  seq_value <- 0L
  for (pulse in seq_len(n_pulses)) {
    for (row_in_pulse in seq_len(SPEC$rows_per_pulse)) {
      seq_value <- seq_value + 1L
      writer$append(scalar_fields(pulse, row_in_pulse, seq_value), seq_value)
    }
  }
  handler$consume(writer$drain())
  list(state = handler$state, data = if (capture) do.call(rbind, handler$state$chunks) else NULL)
}

run_block <- function(n_pulses, capture = FALSE) {
  handler <- counting_handler(capture)
  writer <- block_writer(handler$output, SPEC$chunk_rows)
  seq_value <- 0L
  for (pulse in seq_len(n_pulses)) {
    writer$append_block(pulse_block(pulse, seq_value + 1L))
    seq_value <- seq_value + SPEC$rows_per_pulse
  }
  handler$consume(writer$drain())
  list(state = handler$state, data = if (capture) do.call(rbind, handler$state$chunks) else NULL)
}

parity_pulses <- 9L
scalar_parity <- run_scalar(parity_pulses, capture = TRUE)$data
block_parity <- run_block(parity_pulses, capture = TRUE)$data
parity <- identical(scalar_parity, block_parity)
if (!parity) stop("Scalar and block paths differ across the chunk boundary.")

# Warm both paths without consuming a measured repetition.
invisible(run_scalar(2L))
invisible(run_block(2L))

measure <- function(arm, fun) {
  rows <- vector("list", SPEC$repetitions)
  for (repetition in seq_len(SPEC$repetitions)) {
    gc(full = TRUE)
    gc(full = TRUE)
    elapsed <- system.time(result <- fun(SPEC$pulses))[["elapsed"]]
    if (result$state$rows != SPEC$rows || result$state$last_seq != SPEC$rows) {
      stop("Measured path did not produce the registered row shape.")
    }
    rows[[repetition]] <- data.frame(
      arm = arm,
      repetition = repetition,
      elapsed_seconds = as.numeric(elapsed),
      rows = result$state$rows,
      frames = result$state$frames,
      parity_across_chunk = parity,
      collapse_version = as.character(utils::packageVersion("collapse")),
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

measurements <- rbind(
  measure("scalar_fields_row_append", run_scalar),
  measure("pulse_block", run_block)
)
current_median <- stats::median(
  measurements$elapsed_seconds[measurements$arm == "scalar_fields_row_append"]
)
block_median <- stats::median(
  measurements$elapsed_seconds[measurements$arm == "pulse_block"]
)
reduction <- 1 - block_median / current_median
answer <- if (parity && is.finite(reduction) && reduction >= SPEC$reduction_required) {
  "PULSE_BLOCK_REQUIRED"
} else {
  "NO_CLEAR_BLOCK_WRITE_GAP"
}

measurements$registered_rows <- SPEC$rows
measurements$current_median_seconds <- current_median
measurements$block_median_seconds <- block_median
measurements$wall_reduction <- reduction
measurements$prerequisite_answer <- answer

output_path <- file.path(probe_dir, "probe_measurements.csv")
utils::write.csv(measurements, output_path, row.names = FALSE, na = "")

cat("R_version=", as.character(getRversion()), "\n", sep = "")
cat("collapse_version=", as.character(utils::packageVersion("collapse")), "\n", sep = "")
cat("registered_rows=", SPEC$rows, "\n", sep = "")
cat("parity_across_chunk=", parity, "\n", sep = "")
cat("current_median_seconds=", sprintf("%.3f", current_median), "\n", sep = "")
cat("block_median_seconds=", sprintf("%.3f", block_median), "\n", sep = "")
cat("wall_reduction=", sprintf("%.4f", reduction), "\n", sep = "")
cat("PREREQUISITE_ANSWER=", answer, "\n", sep = "")
cat("evidence=", normalizePath(output_path, winslash = "/"), "\n", sep = "")
