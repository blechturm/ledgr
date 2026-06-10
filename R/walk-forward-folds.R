ledgr_walk_forward_schema_version <- "v1"
ledgr_fold_schema_version <- "v1"
ledgr_fold_list_schema_version <- "v1"

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
#' @param train_start,train_end,test_start,test_end Fold boundary timestamps.
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
  cat("Folds: ", length(x), "\n", sep = "")
  cat("Hash:  ", substr(ledgr_fold_list_hash(x), 1L, 12L), "\n", sep = "")
  constructor <- attr(x, "constructor", exact = TRUE)
  if (is.list(constructor) && is.character(constructor$type_id)) {
    cat("Scheme:", constructor$type_id, "\n")
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
    as.POSIXct(iso_utc(x), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"),
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
    "fold_schema_version"
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
  meta <- ledgr_precompute_snapshot_meta(exp$snapshot)
  scoring_start <- ledgr_walk_forward_posix(start_utc, "`start_utc`")
  scoring_end <- ledgr_walk_forward_posix(end_utc, "`end_utc`")
  hydration_start <- if (is.null(hydration_start_utc)) {
    ledgr_walk_forward_posix(meta$start, "`hydration_start_utc`")
  } else {
    ledgr_walk_forward_posix(hydration_start_utc, "`hydration_start_utc`")
  }
  execution_start <- if (is.null(execution_start_utc)) {
    scoring_start
  } else {
    ledgr_walk_forward_posix(execution_start_utc, "`execution_start_utc`")
  }
  snapshot_start <- ledgr_walk_forward_posix(meta$start, "`snapshot_start`")
  snapshot_end <- ledgr_walk_forward_posix(meta$end, "`snapshot_end`")

  if (scoring_start > scoring_end) {
    rlang::abort("Window scoring start must be before or equal to scoring end.", class = "ledgr_walk_forward_invalid_fold_window")
  }
  if (hydration_start > execution_start) {
    rlang::abort("Window hydration start must be before or equal to execution start.", class = "ledgr_walk_forward_invalid_fold_window")
  }
  if (execution_start < scoring_start || execution_start > scoring_end) {
    rlang::abort("Window execution start must fall inside the scoring window.", class = "ledgr_walk_forward_invalid_fold_window")
  }
  if (hydration_start < snapshot_start || scoring_end > snapshot_end) {
    rlang::abort("Experiment window must be inside the sealed snapshot range.", class = "ledgr_walk_forward_invalid_fold_window")
  }

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
    return(ledgr_experiment_window(
      exp = exp,
      start_utc = fold$train_start_utc,
      end_utc = fold$train_end_utc,
      opening_state_policy = opening_state_policy
    ))
  }
  ledgr_experiment_window(
    exp = exp,
    start_utc = fold$test_start_utc,
    end_utc = fold$test_end_utc,
    opening_state_policy = opening_state_policy
  )
}

ledgr_experiment_window_validate_pulses <- function(exp, window) {
  bars_by_id <- ledgr_precompute_fetch_bars(
    exp$snapshot,
    exp$universe,
    ledgr_walk_forward_iso(window$scoring_start_utc),
    ledgr_walk_forward_iso(window$scoring_end_utc)
  )
  bars_by_id <- ledgr_sweep_normalize_bars_by_id(bars_by_id, exp$universe)
  ledgr_precompute_validate_static_coverage(bars_by_id, exp$universe)
  n_pulses <- nrow(bars_by_id[[exp$universe[[1L]]]])
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
                             compiled_accounting_model = NULL) {
  window <- ledgr_experiment_window_resolve(exp, window)
  ledgr_run_experiment(
    exp = exp,
    params = params,
    feature_params = feature_params,
    run_id = run_id,
    seed = seed,
    compiled_accounting_model = compiled_accounting_model,
    window = window
  )
}
