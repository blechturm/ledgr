ledgr_walk_forward_schema_version <- "v1"
ledgr_fold_schema_version <- "v2"
ledgr_fold_list_schema_version <- "v2"

#' Walk-forward fold constructors
#'
#' These constructors define calendar-time walk-forward fold value objects.
#' Folds describe train and test scoring windows only; they do not execute
#' strategies, select candidates, persist artifacts, or perform statistical
#' validation.
#'
#' `ledgr_fold()` creates a single explicit fold. `ledgr_folds_rolling()` and
#' `ledgr_folds_anchored()` create ordered fold lists from calendar durations.
#' V1 supports only `gap = NULL`; purged and embargoed gap semantics are
#' reserved for a later validation-diagnostics layer.
#' Duration-based constructors produce inclusive end timestamps one second
#' before the next period boundary.
#'
#' @param train_start,train_end,test_start,test_end Fold boundary timestamps or
#'   civil Dates. When applied to an availability-aware experiment, Date starts
#'   resolve to venue-session opens and Date ends to session closes; POSIXct
#'   values remain exact instants.
#' @param fold_seq Positive integer fold sequence.
#' @param scheme Fold scheme, currently `"rolling"` or `"anchored"`.
#' @param gap Reserved. Must be `NULL` in v1.
#' @param start,end Calendar range used to generate a fold list.
#' @param train_window,test_window,step Positive calendar durations such as
#'   `"1 year"`, `"3 months"`, or `"10 days"`.
#' @param train_window_initial Initial anchored train-window duration.
#' @return A `ledgr_fold` or `ledgr_fold_list` object.
#' @examples
#' ledgr_fold(
#'   train_start = "2020-01-01",
#'   train_end = "2020-12-31",
#'   test_start = "2021-01-01",
#'   test_end = "2021-03-31"
#' )
#'
#' ledgr_folds_rolling(
#'   start = "2020-01-01",
#'   end = "2021-12-31",
#'   train_window = "1 year",
#'   test_window = "3 months",
#'   step = "3 months"
#' )
#'
#' ledgr_folds_anchored(
#'   start = "2020-01-01",
#'   end = "2021-12-31",
#'   train_window_initial = "1 year",
#'   test_window = "3 months"
#' )
#' @export
ledgr_fold <- function(train_start,
                       train_end,
                       test_start,
                       test_end,
                       fold_seq = 1L,
                       scheme = c("rolling", "anchored"),
                       gap = NULL) {
  scheme <- match.arg(scheme)
  ledgr_walk_forward_validate_gap(gap)
  fold_seq <- ledgr_walk_forward_validate_positive_integer(fold_seq, "`fold_seq`")

  civil_boundaries <- list(
    train_start = if (inherits(train_start, "Date") && !inherits(train_start, "POSIXt")) as.character(train_start) else NULL,
    train_end = if (inherits(train_end, "Date") && !inherits(train_end, "POSIXt")) as.character(train_end) else NULL,
    test_start = if (inherits(test_start, "Date") && !inherits(test_start, "POSIXt")) as.character(test_start) else NULL,
    test_end = if (inherits(test_end, "Date") && !inherits(test_end, "POSIXt")) as.character(test_end) else NULL
  )

  train_start_utc <- ledgr_walk_forward_posix(train_start, "`train_start`")
  train_end_utc <- ledgr_walk_forward_posix(train_end, "`train_end`")
  test_start_utc <- ledgr_walk_forward_posix(test_start, "`test_start`")
  test_end_utc <- ledgr_walk_forward_posix(test_end, "`test_end`")

  ledgr_walk_forward_validate_fold_boundaries(
    train_start_utc = train_start_utc,
    train_end_utc = train_end_utc,
    test_start_utc = test_start_utc,
    test_end_utc = test_end_utc
  )

  out <- structure(
    list(
      fold_id = NA_character_,
      fold_seq = fold_seq,
      scheme = scheme,
      train_start_utc = train_start_utc,
      train_end_utc = train_end_utc,
      test_start_utc = test_start_utc,
      test_end_utc = test_end_utc,
      civil_boundaries = civil_boundaries,
      gap_value = NULL,
      gap_unit = NULL,
      fold_schema_version = ledgr_fold_schema_version
    ),
    class = c("ledgr_fold", "list")
  )
  out$fold_id <- ledgr_fold_id(out)
  out
}

#' @rdname ledgr_fold
#' @export
ledgr_folds_rolling <- function(start,
                                end,
                                train_window,
                                test_window,
                                step = test_window,
                                gap = NULL) {
  ledgr_walk_forward_validate_gap(gap)
  start_utc <- ledgr_walk_forward_posix(start, "`start`")
  end_utc <- ledgr_walk_forward_posix(end, "`end`")
  if (start_utc >= end_utc) {
    rlang::abort("`start` must be before `end`.", class = "ledgr_walk_forward_invalid_fold_window")
  }

  train_period <- ledgr_walk_forward_period(train_window, "`train_window`")
  test_period <- ledgr_walk_forward_period(test_window, "`test_window`")
  step_period <- ledgr_walk_forward_period(step, "`step`")

  folds <- list()
  fold_seq <- 1L
  train_start <- start_utc
  repeat {
    train_end_exclusive <- ledgr_walk_forward_shift(train_start, train_period)
    test_start <- train_end_exclusive
    test_end_exclusive <- ledgr_walk_forward_shift(test_start, test_period)
    train_end <- ledgr_walk_forward_inclusive_end(train_end_exclusive)
    test_end <- ledgr_walk_forward_inclusive_end(test_end_exclusive)
    if (test_end > end_utc) {
      break
    }
    folds[[length(folds) + 1L]] <- ledgr_fold(
      train_start = train_start,
      train_end = train_end,
      test_start = test_start,
      test_end = test_end,
      fold_seq = fold_seq,
      scheme = "rolling",
      gap = NULL
    )
    fold_seq <- fold_seq + 1L
    train_start <- ledgr_walk_forward_shift(train_start, step_period)
    if (train_start >= end_utc) {
      break
    }
  }

  ledgr_fold_list(
    folds,
    constructor = list(
      type_id = "rolling",
      start_utc = start_utc,
      end_utc = end_utc,
      train_window = train_period$label,
      test_window = test_period$label,
      step = step_period$label,
      gap = NULL
    )
  )
}

#' @rdname ledgr_fold
#' @export
ledgr_folds_anchored <- function(start,
                                 end,
                                 train_window_initial,
                                 test_window,
                                 step = test_window,
                                 gap = NULL) {
  ledgr_walk_forward_validate_gap(gap)
  start_utc <- ledgr_walk_forward_posix(start, "`start`")
  end_utc <- ledgr_walk_forward_posix(end, "`end`")
  if (start_utc >= end_utc) {
    rlang::abort("`start` must be before `end`.", class = "ledgr_walk_forward_invalid_fold_window")
  }

  train_period <- ledgr_walk_forward_period(train_window_initial, "`train_window_initial`")
  test_period <- ledgr_walk_forward_period(test_window, "`test_window`")
  step_period <- ledgr_walk_forward_period(step, "`step`")

  folds <- list()
  fold_seq <- 1L
  train_end_exclusive <- ledgr_walk_forward_shift(start_utc, train_period)
  repeat {
    test_start <- train_end_exclusive
    test_end_exclusive <- ledgr_walk_forward_shift(test_start, test_period)
    train_end <- ledgr_walk_forward_inclusive_end(train_end_exclusive)
    test_end <- ledgr_walk_forward_inclusive_end(test_end_exclusive)
    if (test_end > end_utc) {
      break
    }
    folds[[length(folds) + 1L]] <- ledgr_fold(
      train_start = start_utc,
      train_end = train_end,
      test_start = test_start,
      test_end = test_end,
      fold_seq = fold_seq,
      scheme = "anchored",
      gap = NULL
    )
    fold_seq <- fold_seq + 1L
    train_end_exclusive <- ledgr_walk_forward_shift(train_end_exclusive, step_period)
    if (train_end_exclusive >= end_utc) {
      break
    }
  }

  ledgr_fold_list(
    folds,
    constructor = list(
      type_id = "anchored",
      start_utc = start_utc,
      end_utc = end_utc,
      train_window_initial = train_period$label,
      test_window = test_period$label,
      step = step_period$label,
      gap = NULL
    )
  )
}

#' @export
print.ledgr_fold <- function(x, ...) {
  x <- ledgr_validate_fold(x)
  cat("ledgr fold\n")
  cat("==========\n")
  cat("ID:     ", substr(x$fold_id, 1L, 12L), "\n", sep = "")
  cat("Seq:    ", x$fold_seq, "\n", sep = "")
  cat("Scheme: ", x$scheme, "\n", sep = "")
  cat("Train:  ", ledgr_walk_forward_iso(x$train_start_utc), " to ",
      ledgr_walk_forward_iso(x$train_end_utc), "\n", sep = "")
  cat("Test:   ", ledgr_walk_forward_iso(x$test_start_utc), " to ",
      ledgr_walk_forward_iso(x$test_end_utc), "\n", sep = "")
  invisible(x)
}

#' @export
print.ledgr_fold_list <- function(x, ...) {
  x <- ledgr_validate_fold_list(x)
  cat("ledgr fold list\n")
  cat("================\n")
  constructor <- attr(x, "constructor", exact = TRUE)
  if (is.list(constructor) && is.character(constructor$type_id)) {
    cat("Scheme: ", constructor$type_id, "\n", sep = "")
  }
  cat("Folds:  ", length(x), "\n", sep = "")
  cat("Hash:   ", substr(ledgr_fold_list_hash(x), 1L, 12L), "\n", sep = "")
  if (length(x) > 0L) {
    # Show dates only when starts are start-of-day and ends are either
    # start-of-day or inclusive end-of-day. Rolling/anchored folds use
    # 23:59:59 ends; explicit date-only folds may use 00:00:00 ends.
    day_aligned <- all(vapply(x, function(f) {
      starts_day <- all(grepl("T00:00:00Z$", c(
        ledgr_walk_forward_iso(f$train_start_utc),
        ledgr_walk_forward_iso(f$test_start_utc)
      )))
      ends_day <- all(grepl("T(00:00:00|23:59:59)Z$", c(
        ledgr_walk_forward_iso(f$train_end_utc),
        ledgr_walk_forward_iso(f$test_end_utc)
      )))
      starts_day && ends_day
    }, logical(1)))
    show_time <- !day_aligned
    fmt <- function(ts) {
      iso <- ledgr_walk_forward_iso(ts)
      if (show_time) iso else substr(iso, 1L, 10L)
    }
    windows <- tibble::tibble(
      fold = vapply(x, function(f) as.integer(f$fold_seq), integer(1)),
      train = vapply(x, function(f) sprintf("%s -> %s", fmt(f$train_start_utc), fmt(f$train_end_utc)), character(1)),
      test = vapply(x, function(f) sprintf("%s -> %s", fmt(f$test_start_utc), fmt(f$test_end_utc)), character(1))
    )
    cat("\n")
    print(windows, ...)
  }
  invisible(x)
}

ledgr_walk_forward_validate_gap <- function(gap) {
  if (!is.null(gap)) {
    rlang::abort(
      "`gap` must be NULL in v1. Purged and embargoed folds are deferred.",
      class = c("ledgr_walk_forward_gap_not_supported", "ledgr_walk_forward_invalid_fold_window")
    )
  }
  invisible(TRUE)
}

ledgr_walk_forward_validate_positive_integer <- function(x, arg) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) ||
      !is.finite(x) || x < 1 || x != as.integer(x)) {
    rlang::abort(
      sprintf("%s must be a positive integer scalar.", arg),
      class = "ledgr_walk_forward_invalid_fold_window"
    )
  }
  as.integer(x)
}

ledgr_walk_forward_posix <- function(x, arg) {
  out <- tryCatch(
    as.POSIXct(ledgr_iso_utc(x), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"),
    error = function(e) {
      rlang::abort(
        sprintf("%s must be a parseable UTC timestamp.", arg),
        class = "ledgr_walk_forward_invalid_fold_window",
        parent = e
      )
    }
  )
  if (length(out) != 1L || is.na(out)) {
    rlang::abort(
      sprintf("%s must be a scalar UTC timestamp.", arg),
      class = "ledgr_walk_forward_invalid_fold_window"
    )
  }
  attr(out, "tzone") <- "UTC"
  out
}

ledgr_walk_forward_iso <- function(x) {
  format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

ledgr_walk_forward_validate_fold_boundaries <- function(train_start_utc,
                                                        train_end_utc,
                                                        test_start_utc,
                                                        test_end_utc) {
  if (train_start_utc > train_end_utc) {
    rlang::abort("Train window start must be before or equal to train window end.", class = "ledgr_walk_forward_invalid_fold_window")
  }
  if (test_start_utc > test_end_utc) {
    rlang::abort("Test window start must be before or equal to test window end.", class = "ledgr_walk_forward_invalid_fold_window")
  }
  if (train_end_utc >= test_start_utc) {
    rlang::abort("Train and test windows must be ordered and non-overlapping.", class = "ledgr_walk_forward_invalid_fold_window")
  }
  invisible(TRUE)
}

ledgr_walk_forward_period <- function(x, arg) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    rlang::abort(
      sprintf("%s must be a positive calendar duration such as \"3 months\".", arg),
      class = "ledgr_walk_forward_invalid_fold_window"
    )
  }
  m <- regexec("^\\s*([0-9]+)\\s+([A-Za-z]+)\\s*$", x)
  parts <- regmatches(x, m)[[1]]
  if (length(parts) != 3L) {
    rlang::abort(
      sprintf("%s must be a positive calendar duration such as \"3 months\".", arg),
      class = "ledgr_walk_forward_invalid_fold_window"
    )
  }
  value <- as.integer(parts[[2]])
  unit <- tolower(parts[[3]])
  if (is.na(value) || value < 1L) {
    rlang::abort(
      sprintf("%s must use a positive integer duration.", arg),
      class = "ledgr_walk_forward_invalid_fold_window"
    )
  }
  unit <- switch(
    unit,
    second = "secs",
    seconds = "secs",
    sec = "secs",
    secs = "secs",
    minute = "mins",
    minutes = "mins",
    min = "mins",
    mins = "mins",
    hour = "hours",
    hours = "hours",
    day = "days",
    days = "days",
    week = "weeks",
    weeks = "weeks",
    month = "months",
    months = "months",
    quarter = {
      value <- value * 3L
      "months"
    },
    quarters = {
      value <- value * 3L
      "months"
    },
    year = "years",
    years = "years",
    NULL
  )
  if (is.null(unit)) {
    rlang::abort(
      sprintf("%s uses an unsupported duration unit.", arg),
      class = "ledgr_walk_forward_invalid_fold_window"
    )
  }
  list(value = value, unit = unit, label = paste(value, unit))
}

ledgr_walk_forward_shift <- function(x, period) {
  out <- seq(from = as.POSIXct(x, tz = "UTC"), by = paste(period$value, period$unit), length.out = 2L)[[2L]]
  out <- as.POSIXct(out, origin = "1970-01-01", tz = "UTC")
  attr(out, "tzone") <- "UTC"
  out
}

ledgr_walk_forward_inclusive_end <- function(exclusive_end) {
  out <- as.POSIXct(exclusive_end, tz = "UTC") - 1
  attr(out, "tzone") <- "UTC"
  out
}

ledgr_fold_payload <- function(fold) {
  fold <- ledgr_validate_fold_shape(fold, check_id = FALSE)
  list(
    scheme = fold$scheme,
    train_start_utc = fold$train_start_utc,
    train_end_utc = fold$train_end_utc,
    test_start_utc = fold$test_start_utc,
    test_end_utc = fold$test_end_utc,
    civil_boundaries = fold$civil_boundaries,
    gap_value = fold$gap_value,
    gap_unit = fold$gap_unit,
    fold_seq = fold$fold_seq,
    fold_schema_version = fold$fold_schema_version
  )
}

ledgr_fold_id <- function(fold) {
  digest::digest(as.character(canonical_json(ledgr_fold_payload(fold))), algo = "sha256")
}

ledgr_validate_fold <- function(fold) {
  ledgr_validate_fold_shape(fold, check_id = TRUE)
}

ledgr_validate_fold_shape <- function(fold, check_id = TRUE) {
  if (!inherits(fold, "ledgr_fold") || !is.list(fold)) {
    rlang::abort("`fold` must be a ledgr_fold object.", class = "ledgr_walk_forward_invalid_fold")
  }
  required <- c(
    "fold_id", "fold_seq", "scheme", "train_start_utc", "train_end_utc",
    "test_start_utc", "test_end_utc", "gap_value", "gap_unit",
    "fold_schema_version", "civil_boundaries"
  )
  if (!all(required %in% names(fold))) {
    rlang::abort("`fold` has an invalid ledgr_fold shape.", class = "ledgr_walk_forward_invalid_fold")
  }
  fold_seq <- ledgr_walk_forward_validate_positive_integer(fold$fold_seq, "`fold$fold_seq`")
  if (!identical(fold$scheme, "rolling") && !identical(fold$scheme, "anchored")) {
    rlang::abort("`fold$scheme` must be \"rolling\" or \"anchored\".", class = "ledgr_walk_forward_invalid_fold")
  }
  if (!identical(fold$fold_schema_version, ledgr_fold_schema_version)) {
    rlang::abort("`fold` has an unsupported fold schema version.", class = "ledgr_walk_forward_invalid_fold")
  }
  ledgr_walk_forward_validate_fold_boundaries(
    fold$train_start_utc,
    fold$train_end_utc,
    fold$test_start_utc,
    fold$test_end_utc
  )
  fold$fold_seq <- fold_seq
  if (isTRUE(check_id)) {
    expected_id <- ledgr_fold_id(fold)
    if (!identical(fold$fold_id, expected_id)) {
      rlang::abort("`fold$fold_id` does not match the canonical fold payload.", class = "ledgr_walk_forward_invalid_fold")
    }
  }
  fold
}

ledgr_fold_list <- function(folds, constructor = list(type_id = "explicit")) {
  if (!is.list(folds) || length(folds) < 1L) {
    rlang::abort("Fold constructors produced no folds for the supplied range.", class = "ledgr_walk_forward_invalid_fold_window")
  }
  folds <- lapply(folds, ledgr_validate_fold)
  seqs <- vapply(folds, `[[`, integer(1), "fold_seq")
  if (!identical(seqs, seq_along(folds))) {
    rlang::abort("Fold sequences must be contiguous and start at 1.", class = "ledgr_walk_forward_invalid_fold_window")
  }
  out <- structure(
    folds,
    class = c("ledgr_fold_list", "list"),
    constructor = constructor,
    fold_list_schema_version = ledgr_fold_list_schema_version
  )
  attr(out, "fold_list_hash") <- ledgr_fold_list_hash(out)
  out
}

ledgr_validate_fold_list <- function(folds) {
  if (!inherits(folds, "ledgr_fold_list") || !is.list(folds)) {
    rlang::abort("`folds` must be a ledgr_fold_list object.", class = "ledgr_walk_forward_invalid_fold")
  }
  if (!identical(attr(folds, "fold_list_schema_version", exact = TRUE), ledgr_fold_list_schema_version)) {
    rlang::abort("`folds` has an unsupported fold-list schema version.", class = "ledgr_walk_forward_invalid_fold")
  }
  invisible(lapply(folds, ledgr_validate_fold))
  hash <- ledgr_fold_list_hash(folds)
  if (!identical(attr(folds, "fold_list_hash", exact = TRUE), hash)) {
    rlang::abort("`folds` has an invalid fold_list_hash.", class = "ledgr_walk_forward_invalid_fold")
  }
  folds
}

ledgr_fold_list_payload <- function(folds) {
  folds <- ledgr_validate_fold_list_without_hash(folds)
  list(
    fold_list_schema_version = ledgr_fold_list_schema_version,
    fold_ids = vapply(folds, `[[`, character(1), "fold_id"),
    constructor = attr(folds, "constructor", exact = TRUE)
  )
}

ledgr_validate_fold_list_without_hash <- function(folds) {
  if (!inherits(folds, "ledgr_fold_list") || !is.list(folds)) {
    rlang::abort("`folds` must be a ledgr_fold_list object.", class = "ledgr_walk_forward_invalid_fold")
  }
  invisible(lapply(folds, ledgr_validate_fold))
  folds
}

ledgr_fold_list_hash <- function(folds) {
  digest::digest(as.character(canonical_json(ledgr_fold_list_payload(folds))), algo = "sha256")
}

ledgr_experiment_window <- function(exp,
                                    start_utc,
                                    end_utc,
                                    opening_state_policy = c("carry_test_state", "flat_test_state"),
                                    hydration_start_utc = NULL,
                                    execution_start_utc = NULL,
                                    validate_pulses = TRUE) {
  if (!inherits(exp, "ledgr_experiment")) {
    rlang::abort("`exp` must be a ledgr_experiment object.", class = "ledgr_invalid_args")
  }
  opening_state_policy <- match.arg(opening_state_policy)
  release <- ledgr_snapshot_hold(exp$snapshot)
  on.exit(release(), add = TRUE)
  meta <- ledgr_precompute_snapshot_meta(exp$snapshot)
  if (isTRUE(exp$availability$active)) {
    start_utc <- ledgr_snapshot_resolve_civil_boundary(
      exp$snapshot,
      start_utc,
      edge = "open"
    )
    end_utc <- ledgr_snapshot_resolve_civil_boundary(
      exp$snapshot,
      end_utc,
      edge = "close"
    )
  }
  scoring_start <- ledgr_walk_forward_posix(start_utc, "`start_utc`")
  scoring_end <- ledgr_walk_forward_posix(end_utc, "`end_utc`")
  # Until the joint WS3/WS4 history-start design, scoring_start is the sole
  # evaluation, execution and feature-state boundary. hydration_start_utc is
  # kept as the identity seam for that design: it is stored equal to the
  # scoring start, and any other value refuses rather than being ignored.
  if (!is.null(hydration_start_utc)) {
    requested_hydration_start <- ledgr_walk_forward_posix(hydration_start_utc, "`hydration_start_utc`")
    if (!identical(as.numeric(requested_hydration_start), as.numeric(scoring_start))) {
      rlang::abort(
        sprintf(
          paste(
            "`hydration_start_utc` (%s) differs from the scoring start (%s).",
            "Feature state starts at the scoring start; hydration from earlier",
            "history is planned with the point-in-time history design. Omit",
            "`hydration_start_utc` or set it equal to `start_utc`."
          ),
          ledgr_walk_forward_iso(requested_hydration_start),
          ledgr_walk_forward_iso(scoring_start)
        ),
        class = c("ledgr_unsupported_hydration_start", "ledgr_walk_forward_invalid_fold_window")
      )
    }
  }
  hydration_start <- scoring_start
  # A distinct execution start would need semantics for targets returned
  # between two clocks, so it refuses.
  if (!is.null(execution_start_utc)) {
    requested_execution_start <- ledgr_walk_forward_posix(execution_start_utc, "`execution_start_utc`")
    if (!identical(as.numeric(requested_execution_start), as.numeric(scoring_start))) {
      rlang::abort(
        sprintf(
          paste(
            "`execution_start_utc` (%s) differs from the scoring start (%s).",
            "Execution starts at the scoring start; omit `execution_start_utc`",
            "or set it equal to `start_utc`."
          ),
          ledgr_walk_forward_iso(requested_execution_start),
          ledgr_walk_forward_iso(scoring_start)
        ),
        class = c("ledgr_unsupported_execution_start", "ledgr_walk_forward_invalid_fold_window")
      )
    }
  }
  execution_start <- scoring_start
  snapshot_start <- ledgr_walk_forward_posix(meta$start, "`snapshot_start`")
  snapshot_end <- ledgr_walk_forward_posix(meta$end, "`snapshot_end`")

  if (scoring_start > scoring_end) {
    rlang::abort("Window scoring start must be before or equal to scoring end.", class = "ledgr_walk_forward_invalid_fold_window")
  }
  sealed <- ledgr_sealed_range_window(
    scoring_start, scoring_end, snapshot_start, snapshot_end,
    "Experiment window", "ledgr_walk_forward_invalid_fold_window"
  )
  scoring_start <- sealed$start
  scoring_end <- sealed$end
  hydration_start <- scoring_start
  execution_start <- scoring_start
  ledgr_snapshot_ensure_handle(exp$snapshot)

  out <- structure(
    list(
      hydration_start_utc = hydration_start,
      scoring_start_utc = scoring_start,
      scoring_end_utc = scoring_end,
      execution_start_utc = execution_start,
      opening_state_policy = opening_state_policy,
      window_schema_version = ledgr_walk_forward_schema_version
    ),
    class = c("ledgr_experiment_window", "list")
  )
  if (isTRUE(validate_pulses)) {
    ledgr_experiment_window_validate_pulses(exp, out)
  }
  out
}

ledgr_experiment_window_from_fold <- function(exp,
                                             fold,
                                             window = c("train", "test"),
                                             opening_state_policy = c("carry_test_state", "flat_test_state")) {
  fold <- ledgr_validate_fold(fold)
  window <- match.arg(window)
  opening_state_policy <- match.arg(opening_state_policy)
  if (identical(window, "train")) {
    train_start <- if (!is.null(fold$civil_boundaries$train_start)) {
      as.Date(fold$civil_boundaries$train_start)
    } else fold$train_start_utc
    train_end <- if (!is.null(fold$civil_boundaries$train_end)) {
      as.Date(fold$civil_boundaries$train_end)
    } else fold$train_end_utc
    return(ledgr_experiment_window(
      exp = exp,
      start_utc = train_start,
      end_utc = train_end,
      opening_state_policy = opening_state_policy
    ))
  }
  test_start <- if (!is.null(fold$civil_boundaries$test_start)) {
    as.Date(fold$civil_boundaries$test_start)
  } else fold$test_start_utc
  test_end <- if (!is.null(fold$civil_boundaries$test_end)) {
    as.Date(fold$civil_boundaries$test_end)
  } else fold$test_end_utc
  ledgr_experiment_window(
    exp = exp,
    start_utc = test_start,
    end_utc = test_end,
    opening_state_policy = opening_state_policy
  )
}

ledgr_walk_forward_fold_windows <- function(exp, fold, opening_state_policy) {
  list(
    train = ledgr_experiment_window_from_fold(
      exp,
      fold,
      window = "train",
      opening_state_policy = opening_state_policy
    ),
    test = ledgr_experiment_window_from_fold(
      exp,
      fold,
      window = "test",
      opening_state_policy = opening_state_policy
    )
  )
}

ledgr_experiment_window_validate_pulses <- function(exp, window) {
  release <- ledgr_snapshot_hold(exp$snapshot)
  on.exit(release(), add = TRUE)
  bars_by_id <- ledgr_precompute_fetch_bars(
    exp$snapshot,
    exp$universe,
    ledgr_walk_forward_iso(window$scoring_start_utc),
    ledgr_walk_forward_iso(window$scoring_end_utc)
  )
  bars_by_id <- ledgr_sweep_normalize_bars_by_id(bars_by_id, exp$universe)
  if (isTRUE(exp$availability$active)) {
    availability_data <- ledgr_availability_provider_data(
      get_connection(exp$snapshot),
      exp$snapshot$snapshot_id
    )
    provider <- ledgr_availability_provider_portable(
      availability_data,
      ledgr_sweep_availability_config(exp),
      ledgr_precompute_snapshot_meta(exp$snapshot)$snapshot_hash,
      bars_by_id
    )
    ledgr_availability_require_coverage(provider, ledgr_snapshot_bar_range(get_connection(exp$snapshot), exp$snapshot$snapshot_id, window$scoring_start_utc, window$scoring_end_utc))
    calendar <- ledgr_availability_calendar(
      provider,
      window$scoring_start_utc,
      window$scoring_end_utc
    )
    bars_by_id <- ledgr_sweep_align_availability_bars(
      bars_by_id,
      exp$universe,
      calendar$pulses_posix
    )
    n_pulses <- length(calendar$pulses_posix)
  } else {
    ledgr_precompute_validate_static_coverage(bars_by_id, exp$universe)
    n_pulses <- nrow(bars_by_id[[exp$universe[[1L]]]])
  }
  if (n_pulses < 2L) {
    rlang::abort(
      "Experiment windows must contain at least two scoring pulses.",
      class = "ledgr_walk_forward_invalid_fold_window"
    )
  }
  invisible(TRUE)
}

ledgr_experiment_window_resolve <- function(exp, window = NULL) {
  if (is.null(window)) {
    return(NULL)
  }
  if (!inherits(window, "ledgr_experiment_window")) {
    rlang::abort("`window` must be created by ledgr_experiment_window().", class = "ledgr_walk_forward_invalid_fold_window")
  }
  if (!inherits(exp, "ledgr_experiment")) {
    rlang::abort("`exp` must be a ledgr_experiment object.", class = "ledgr_invalid_args")
  }
  window
}

ledgr_run_window <- function(exp,
                             params = list(),
                             feature_params = list(),
                             window,
                             run_id = NULL,
                             seed = NULL,
                             compiled_accounting_model = NULL,
                             history_substrate = NULL) {
  window <- ledgr_experiment_window_resolve(exp, window)
  ledgr_run_experiment(
    exp = exp,
    params = params,
    feature_params = feature_params,
    run_id = run_id,
    seed = seed,
    compiled_accounting_model = compiled_accounting_model,
    window = window,
    history_substrate = history_substrate
  )
}

# The experiment's pulse calendar over [start, end]: open-session closes for an
# availability-aware experiment, otherwise the universe's bar timestamps.
ledgr_walk_forward_pulse_calendar <- function(exp, start, end) {
  release <- ledgr_snapshot_hold(exp$snapshot)
  on.exit(release(), add = TRUE)
  con <- get_connection(exp$snapshot)
  snapshot_id <- exp$snapshot$snapshot_id
  if (isTRUE(exp$availability$active)) {
    sessions <- ledgr_availability_provider_data(con, snapshot_id)$sessions
    close <- as.POSIXct(sessions$session_close[sessions$status == "open"], tz = "UTC")
    close <- close[!is.na(close) & close >= start & close <= end]
    return(sort(unique(close)))
  }
  placeholders <- paste(rep("?", length(exp$universe)), collapse = ", ")
  rows <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT DISTINCT ts_utc FROM snapshot_bars WHERE snapshot_id = ? ",
      "AND instrument_id IN (", placeholders, ") AND ts_utc >= ? AND ts_utc <= ? ORDER BY ts_utc"
    ),
    params = c(list(snapshot_id), as.list(exp$universe), list(start, end))
  )
  as.POSIXct(rows$ts_utc, tz = "UTC")
}

# carry_test_state hands each test window's closing state to the next one, so
# consecutive test windows must be ordered and contiguous. A window that does
# not start after the previous one ends would open from state the previous
# window reached later in time (overlap or reverse order), and a pulse between
# two windows is never observed, so positions would cross it unvalued and any
# terminal event inside it would go unsettled. Refuse before any training
# sweep or store write and name the first offending pair.
ledgr_walk_forward_refuse_noncontiguous_carry <- function(exp, fold_windows) {
  if (inherits(fold_windows, "ledgr_fold_list")) {
    fold_windows <- lapply(fold_windows, function(fold) {
      ledgr_walk_forward_fold_windows(exp, fold, "carry_test_state")
    })
  }
  if (length(fold_windows) < 2L) return(invisible(TRUE))
  test_start <- as.POSIXct(vapply(fold_windows, function(x) {
    as.numeric(x$test$scoring_start_utc)
  }, numeric(1)),
                           origin = "1970-01-01", tz = "UTC")
  test_end <- as.POSIXct(vapply(fold_windows, function(x) {
    as.numeric(x$test$scoring_end_utc)
  }, numeric(1)),
                         origin = "1970-01-01", tz = "UTC")
  n <- length(fold_windows)
  unordered <- which(test_start[-1L] <= test_end[-n])
  if (length(unordered) > 0L) {
    k <- unordered[[1L]]
    relation <- if (test_start[[k + 1L]] < test_start[[k]]) "starts before" else "overlaps"
    rlang::abort(
      sprintf(
        paste(
          "`opening_state_policy = \"carry_test_state\"` needs test windows in time order",
          "that do not overlap: test window %d (starts %s) %s test window %d (%s to %s),",
          "so it would open from that window's later state. Use contiguous folds, with",
          "`step` equal to `test_window`, or `opening_state_policy = \"flat_test_state\"`."
        ),
        k + 1L, ledgr_walk_forward_iso(test_start[[k + 1L]]), relation, k,
        ledgr_walk_forward_iso(test_start[[k]]), ledgr_walk_forward_iso(test_end[[k]])
      ),
      class = c("ledgr_walk_forward_overlapping_carry", "ledgr_walk_forward_invalid_fold_window")
    )
  }
  pulses <- as.numeric(ledgr_walk_forward_pulse_calendar(exp, min(test_start), max(test_end)))
  after_end <- findInterval(as.numeric(test_end[-n]), pulses)
  before_next <- findInterval(as.numeric(test_start[-1L]), pulses, left.open = TRUE)
  between <- before_next - after_end
  gap <- which(between > 0L)
  if (length(gap) == 0L) return(invisible(TRUE))
  k <- gap[[1L]]
  rlang::abort(
    sprintf(
      paste(
        "`opening_state_policy = \"carry_test_state\"` cannot carry positions across",
        "%d unobserved pulse(s) between test window %d (ends %s) and test window %d",
        "(starts %s). Use contiguous folds, with `step` equal to `test_window`, or",
        "`opening_state_policy = \"flat_test_state\"`."
      ),
      between[[k]], k, ledgr_walk_forward_iso(test_end[[k]]), k + 1L, ledgr_walk_forward_iso(test_start[[k + 1L]])
    ),
    class = c("ledgr_walk_forward_gapped_carry", "ledgr_walk_forward_invalid_fold_window")
  )
}
