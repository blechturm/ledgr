.ledgr_fold_state_slots <- c(
  "cash",
  "positions",
  "lot_state",
  "state_prev",
  "position_facts",
  "state_axis",
  "event_seq",
  "status",
  "stop_reason",
  "affected_exposure",
  "processed",
  "full_run",
  "last_fully_valued",
  "last_executed",
  "frozen_set",
  "current_stage",
  "current_ts",
  "pending_segments",
  "equity_facts",
  "diagnostic_seq",
  "telemetry_idx"
)

ledgr_fold_state_new <- function(
    cash,
    positions,
    lot_state,
    state_prev = NULL,
    position_facts = NULL,
    state_axis = NULL,
    event_seq = 1L,
    status = "DONE",
    stop_reason = NA_character_,
    affected_exposure = list(
      value = NA_real_,
      details = list(),
      ts_utc = as.POSIXct(NA, tz = "UTC"),
      specified = FALSE
    ),
    processed = 0L,
    full_run = TRUE,
    last_fully_valued = as.POSIXct(NA, tz = "UTC"),
    last_executed = as.POSIXct(NA, tz = "UTC"),
    frozen_set = character(),
    current_stage = "fold",
    current_ts = as.POSIXct(NA, tz = "UTC"),
    pending_segments = ledgr_fold_diagnostic_staging(0L),
    equity_facts = ledgr_fold_equity_record(0L),
    diagnostic_seq = 0L,
    telemetry_idx = 0L) {
  out <- new.env(parent = emptyenv())
  out$cash <- cash
  out$positions <- positions
  out$lot_state <- lot_state
  out$state_prev <- state_prev
  out$position_facts <- position_facts %||% ledgr_position_fact_state(length(positions))
  out$state_axis <- state_axis
  out$event_seq <- event_seq
  out$status <- status
  out$stop_reason <- stop_reason
  out$affected_exposure <- affected_exposure
  out$processed <- processed
  out$full_run <- full_run
  out$last_fully_valued <- last_fully_valued
  out$last_executed <- last_executed
  out$frozen_set <- frozen_set
  out$current_stage <- current_stage
  out$current_ts <- current_ts
  out$pending_segments <- pending_segments
  out$equity_facts <- equity_facts
  out$diagnostic_seq <- diagnostic_seq
  out$telemetry_idx <- telemetry_idx
  ledgr_fold_state_validate(out)
  lockEnvironment(out, bindings = FALSE)
  out
}

ledgr_fold_state_validate <- function(x) {
  invalid <- function(detail) {
    rlang::abort(
      paste0("Invalid internal fold state: ", detail, "."),
      class = "ledgr_internal_error"
    )
  }
  if (!is.environment(x) || !identical(parent.env(x), emptyenv())) {
    invalid("the carrier must be an environment with an empty parent")
  }
  actual <- sort(ls(x, all.names = TRUE), method = "radix")
  expected <- sort(.ledgr_fold_state_slots, method = "radix")
  if (!identical(actual, expected)) invalid("the slot set is not exact")
  values <- mget(.ledgr_fold_state_slots, envir = x, inherits = FALSE)
  if (any(vapply(values, is.data.frame, logical(1L)))) {
    invalid("data-frame slots are forbidden")
  }
  # The lot book (V-book) and the run-axis positions that its axis defines:
  # positions are an unnamed finite double vector, one entry per book
  # instrument (Synthesis 3.1 and Section 4, groups "state" and "book").
  book_problem <- ledgr_lot_book_problem(x$lot_state, reduction = FALSE)
  if (!is.null(book_problem)) invalid(paste0("the lot book is invalid: ", book_problem))
  if (!is.double(x$positions) || !is.null(names(x$positions)) ||
      length(x$positions) != length(x$lot_state$offset) ||
      !all(is.finite(x$positions))) {
    invalid("positions must be an unnamed finite double vector on the book axis")
  }
  # Positions equal to the lot-derived net (Synthesis Section 4, F4.01) is
  # not checked here: the base admits imported positions that differ from
  # the imported book (carried windows in the last bits; execution specs
  # holding positions without lots). Settled by the cut 5 amendment of 2026-10-30 (LDG-3164).
  exposure_fields <- c("value", "details", "ts_utc", "specified")
  if (!is.numeric(x$cash) || length(x$cash) != 1L || !is.finite(x$cash) ||
      is.data.frame(x$state_prev) ||
      !is.list(x$position_facts) ||
      !identical(names(x$position_facts), c("entry_bar", "exit_bar")) ||
      length(x$position_facts$entry_bar) != length(x$positions) ||
      length(x$position_facts$exit_bar) != length(x$positions) ||
      !(is.null(x$state_axis) || is.character(x$state_axis)) ||
      !is.integer(x$event_seq) || length(x$event_seq) != 1L ||
      is.na(x$event_seq) || x$event_seq < 1L ||
      !is.character(x$status) || length(x$status) != 1L ||
      is.na(x$status) || !nzchar(x$status) ||
      !is.character(x$stop_reason) || length(x$stop_reason) != 1L ||
      !is.list(x$affected_exposure) ||
      !all(exposure_fields %in% names(x$affected_exposure)) ||
      !is.integer(x$processed) || length(x$processed) != 1L ||
      is.na(x$processed) || x$processed < 0L ||
      !is.logical(x$full_run) || length(x$full_run) != 1L ||
      is.na(x$full_run) ||
      !inherits(x$last_fully_valued, "POSIXct") ||
      length(x$last_fully_valued) != 1L ||
      !inherits(x$last_executed, "POSIXct") || length(x$last_executed) != 1L ||
      !is.character(x$frozen_set) || anyNA(x$frozen_set) ||
      !is.character(x$current_stage) || length(x$current_stage) != 1L ||
      is.na(x$current_stage) || !nzchar(x$current_stage) ||
      !inherits(x$current_ts, "POSIXct") || length(x$current_ts) != 1L ||
      !is.integer(x$diagnostic_seq) || length(x$diagnostic_seq) != 1L ||
      is.na(x$diagnostic_seq) || x$diagnostic_seq < 0L ||
      !is.integer(x$telemetry_idx) || length(x$telemetry_idx) != 1L ||
      is.na(x$telemetry_idx) || x$telemetry_idx < 0L) {
    invalid("one or more slots have the wrong type or size")
  }
  # The typed pulse diagnostics staging (V-diagnostics) and equity record
  # (V-equity): exact columns, types, row axis, used-row bounds and the used
  # prefix's missingness and order (LDG-3168, Synthesis 3.6).
  problem <- ledgr_carrier_problem(x$pending_segments, "diagnostics", NA_integer_)
  if (!is.null(problem)) invalid(paste0("the pending diagnostics are invalid: ", problem))
  problem <- ledgr_carrier_problem(x$equity_facts, "equity", NA_integer_)
  if (!is.null(problem)) invalid(paste0("the equity record is invalid: ", problem))
  invisible(x)
}

# A stage's stop result (V-stop): its status and reason, the affected
# instruments and exposure, its diagnostics as a fully used block of the
# staging schema, and whether its pulse counts as processed. E alone
# installs it (ledgr_fold_apply_stop()).
ledgr_fold_stop_result <- function(
    status,
    reason_code,
    affected_instrument_ids = character(),
    affected_exposure = list(),
    diagnostics = ledgr_fold_diagnostic_rows(list(n = 0L), NA_real_),
    counts_processed = FALSE) {
  out <- structure(
    list(
      status = status,
      reason_code = reason_code,
      affected_instrument_ids = affected_instrument_ids,
      affected_exposure = affected_exposure,
      diagnostics = diagnostics,
      counts_processed = counts_processed
    ),
    class = "ledgr_fold_stop_result"
  )
  problem <- ledgr_carrier_problem(out, "stop", NA_integer_)
  if (!is.null(problem)) {
    rlang::abort(
      paste0("Invalid internal fold stop result: ", problem, "."),
      class = "ledgr_internal_error"
    )
  }
  out
}

ledgr_is_fold_stop_result <- function(x) {
  inherits(x, "ledgr_fold_stop_result")
}

# E's one installation of a stop result: status, reason and affected
# exposure, the stop's diagnostics staged after the pulse's earlier rows,
# and the processed count when the stop counts its pulse; then the state
# is validated. The caller drains the staging and ends the loop.
ledgr_fold_apply_stop <- function(fold_state, stop) {
  fold_state$status <- stop$status
  fold_state$stop_reason <- stop$reason_code
  fold_state$affected_exposure <- stop$affected_exposure
  ledgr_fold_staging_write(fold_state, stop$diagnostics)
  if (stop$counts_processed) {
    fold_state$processed <- fold_state$processed + 1L
  }
  ledgr_fold_state_validate(fold_state)
  invisible(NULL)
}
