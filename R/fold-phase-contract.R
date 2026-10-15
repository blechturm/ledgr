.ledgr_fold_state_slots <- c(
  "cash",
  "positions",
  "lot_state",
  "state_prev",
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
  "diagnostic_seq",
  "telemetry_idx"
)

ledgr_fold_state_new <- function(
    cash,
    positions,
    lot_state,
    state_prev = NULL,
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
    pending_segments = list(),
    diagnostic_seq = 0L,
    telemetry_idx = 0L) {
  out <- new.env(parent = emptyenv())
  out$cash <- cash
  out$positions <- positions
  out$lot_state <- lot_state
  out$state_prev <- state_prev
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
  if (!is.numeric(x$cash) || length(x$cash) != 1L || is.na(x$cash) ||
      !is.numeric(x$positions) || is.null(names(x$positions)) ||
      anyNA(names(x$positions)) || any(!nzchar(names(x$positions))) ||
      anyDuplicated(names(x$positions)) ||
      !is.list(x$lot_state) ||
      is.data.frame(x$state_prev) ||
      !(is.null(x$state_axis) || is.character(x$state_axis)) ||
      !is.integer(x$event_seq) || length(x$event_seq) != 1L ||
      is.na(x$event_seq) || x$event_seq < 1L ||
      !is.character(x$status) || length(x$status) != 1L ||
      is.na(x$status) || !nzchar(x$status) ||
      !is.character(x$stop_reason) || length(x$stop_reason) != 1L ||
      !is.list(x$affected_exposure) ||
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
      !is.list(x$pending_segments) ||
      !is.integer(x$diagnostic_seq) || length(x$diagnostic_seq) != 1L ||
      is.na(x$diagnostic_seq) || x$diagnostic_seq < 0L ||
      !is.integer(x$telemetry_idx) || length(x$telemetry_idx) != 1L ||
      is.na(x$telemetry_idx) || x$telemetry_idx < 0L) {
    invalid("one or more slots have the wrong type or size")
  }
  invisible(x)
}

ledgr_fold_stop_result <- function(
    status,
    reason_code,
    affected_instrument_ids = character(),
    affected_exposure = list(),
    diagnostic_segments = list(),
    counts_processed = FALSE) {
  out <- structure(
    list(
      status = status,
      reason_code = reason_code,
      affected_instrument_ids = affected_instrument_ids,
      affected_exposure = affected_exposure,
      diagnostic_segments = diagnostic_segments,
      counts_processed = counts_processed
    ),
    class = "ledgr_fold_stop_result"
  )
  if (!is.character(out$status) || length(out$status) != 1L ||
      is.na(out$status) || !nzchar(out$status) ||
      !is.character(out$reason_code) || length(out$reason_code) != 1L ||
      is.na(out$reason_code) || !nzchar(out$reason_code) ||
      !is.character(out$affected_instrument_ids) ||
      anyNA(out$affected_instrument_ids) ||
      !is.list(out$affected_exposure) ||
      !is.list(out$diagnostic_segments) ||
      !is.logical(out$counts_processed) ||
      length(out$counts_processed) != 1L || is.na(out$counts_processed)) {
    rlang::abort(
      "Invalid internal fold stop result.",
      class = "ledgr_internal_error"
    )
  }
  out
}

ledgr_is_fold_stop_result <- function(x) {
  inherits(x, "ledgr_fold_stop_result")
}

ledgr_fold_equity_fact_accumulator <- function(capacity) {
  capacity <- as.integer(capacity)
  if (length(capacity) != 1L || is.na(capacity) || capacity < 0L) {
    rlang::abort(
      "Invalid internal equity-fact accumulator capacity.",
      class = "ledgr_internal_error"
    )
  }
  values <- vector("list", capacity)
  size <- 0L
  append <- function(value) {
    size <<- size + 1L
    if (size > capacity) {
      rlang::abort(
        "Internal equity-fact accumulator exceeded its capacity.",
        class = "ledgr_internal_error"
      )
    }
    collapse::setv(values, size, list(value), vind1 = TRUE, xlist = TRUE)
    invisible(NULL)
  }
  collect <- function() {
    if (size == 0L) return(list())
    values[seq_len(size)]
  }
  list(append = append, collect = collect)
}
