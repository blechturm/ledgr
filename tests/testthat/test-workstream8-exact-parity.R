workstream8_feature_lookup_oracle <- function(feature_map = NULL,
                                               active_alias_map = NULL) {
  if (missing(feature_map) || is.null(feature_map)) {
    storage <- ledgr:::ledgr_alias_map_storage(active_alias_map)
    if (is.null(storage$alias_map)) {
      rlang::abort(
        "`ctx$features(instrument_id)` requires an active alias map. Use `ctx$features(instrument_id, feature_map)` or `ctx$feature(instrument_id, feature_id)` for exact-ID lookup.",
        class = c("ledgr_no_active_alias_map", "ledgr_invalid_pulse_context")
      )
    }
    return(storage$alias_map)
  }
  ledgr:::ledgr_feature_lookup_map(feature_map)
}

workstream8_features_wide_oracle <- function(features) {
  if (!ledgr:::ledgr_feature_table_ready(features)) return(data.frame())
  instrument_id <- as.character(features[["instrument_id"]])
  feature_name <- as.character(features[["feature_name"]])
  feature_value <- as.numeric(features[["feature_value"]])
  valid <- !is.na(instrument_id) & nzchar(instrument_id) &
    !is.na(feature_name) & nzchar(feature_name)
  if (!any(valid)) return(data.frame())
  instrument_id <- instrument_id[valid]
  feature_name <- feature_name[valid]
  feature_value <- feature_value[valid]
  instruments <- unique(instrument_id)
  feature_names <- unique(feature_name)
  values <- matrix(
    NA_real_,
    nrow = length(instruments),
    ncol = length(feature_names),
    dimnames = list(instruments, feature_names)
  )
  for (i in seq_along(feature_value)) {
    values[instrument_id[[i]], feature_name[[i]]] <- feature_value[[i]]
  }
  out <- data.frame(instrument_id = instruments, stringsAsFactors = FALSE)
  if ("ts_utc" %in% names(features)) {
    ts_utc <- vapply(features[["ts_utc"]][valid], ledgr:::ledgr_iso_utc, character(1))
    out$ts_utc <- vapply(
      instruments,
      function(inst) ts_utc[which(instrument_id == inst)[[1L]]],
      character(1)
    )
  }
  out <- cbind(
    out,
    as.data.frame(values, check.names = FALSE, stringsAsFactors = FALSE)
  )
  rownames(out) <- NULL
  out
}

workstream8_reachable_functions <- function(entry_points, overrides = list()) {
  namespace <- asNamespace("ledgr")
  queue <- unique(entry_points)
  seen <- character()
  calls <- list()
  while (length(queue) > 0L) {
    name <- queue[[1L]]
    queue <- queue[-1L]
    if (name %in% seen) next
    fn <- overrides[[name]]
    if (is.null(fn) && exists(name, envir = namespace, inherits = FALSE)) {
      fn <- get(name, envir = namespace, inherits = FALSE)
    }
    if (!is.function(fn)) next
    seen <- c(seen, name)
    direct <- unique(all.names(body(fn), functions = TRUE))
    calls[[name]] <- direct
    package_calls <- direct[vapply(direct, function(call) {
      call %in% names(overrides) ||
        (exists(call, envir = namespace, inherits = FALSE) &&
           is.function(get(call, envir = namespace, inherits = FALSE)))
    }, logical(1L))]
    queue <- unique(c(queue, setdiff(package_calls, seen)))
  }
  list(functions = seen, calls = calls)
}

workstream8_forbidden_identity_calls <- function(graph) {
  calls <- unique(unlist(graph$calls, use.names = FALSE))
  direct <- calls[calls %in% c(
    "ledgr_alias_map_storage", "canonical_json", "digest"
  )]
  package_identity <- graph$functions[grepl(
    "(^|_)(hash|sha256|digest|canonical_json)($|_)",
    graph$functions,
    perl = TRUE
  )]
  unique(c(direct, package_identity))
}

workstream8_session_facts <- function() {
  dates <- as.Date("2024-01-01") + 0:7
  weekday <- as.POSIXlt(dates)$wday %in% 1:5
  ledgr_facts(ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = ifelse(weekday, "open", "closed"),
      session_open = ifelse(weekday, "09:30:00", NA_character_),
      session_close = ifelse(weekday, "16:00:00", NA_character_),
      knowledge_time = as.POSIXct("2023-12-01", tz = "UTC"),
      stringsAsFactors = FALSE
    ),
    venue_id = "XNYS",
    timezone = "America/New_York"
  ))
}

workstream8_old_observation_times <- function(x, facts, session_rows = NULL) {
  session_family <- ledgr:::ledgr_session_family(facts)
  date_labels <- inherits(x, "Date") ||
    (is.character(x) && all(is.na(x) | grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)))
  if (isTRUE(date_labels) && !is.null(session_family)) {
    dates <- suppressWarnings(as.Date(as.character(x), format = "%Y-%m-%d"))
    rows <- session_family$rows
    idx <- match(as.character(dates), as.character(rows$session_date))
    out <- as.POSIXct(rep(NA_real_, length(dates)), origin = "1970-01-01", tz = "UTC")
    mapped <- !is.na(idx) & rows$status[idx] == "open"
    out[mapped] <- rows$session_close[idx[mapped]]
    return(out)
  }
  out <- as.POSIXct(rep(NA_real_, length(x)), origin = "1970-01-01", tz = "UTC")
  for (i in seq_along(x)) {
    out[[i]] <- tryCatch(
      ledgr:::ledgr_fact_time(x[i], "ts_utc", allow_missing = TRUE)[[1L]],
      error = function(e) as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
    )
  }
  out
}

workstream8_old_session_closes <- function(ts,
                                           facts,
                                           session_rows = NULL,
                                           tokens = NULL) {
  rows <- ledgr:::ledgr_session_open_rows(facts)
  if (is.null(rows)) return(rep(TRUE, length(ts)))
  ledgr:::ledgr_fact_time_token(ts) %in%
    ledgr:::ledgr_fact_time_token(rows$session_close)
}

workstream8_observation_bars <- function() {
  data.frame(
    instrument_id = c("AAA", "BBB", "AAA", "BBB"),
    ts_utc = c(
      "2024-01-02T21:00:00Z",
      "2024-01-02T21:00:00Z",
      "not-a-time",
      "not-a-time"
    ),
    open = c(10, 20, 11, 21),
    high = c(11, 21, 12, 22),
    low = c(9, 19, 10, 20),
    close = c(10.5, 20.5, 11.5, 21.5),
    volume = c(100, 200, 110, 210),
    stringsAsFactors = FALSE
  )
}

workstream8_marks_oracle <- function(provider,
                                     axis,
                                     calendar,
                                     pulse_idx,
                                     strict_cutoff = FALSE) {
  close <- matrix(
    NA_real_,
    nrow = length(axis),
    ncol = pulse_idx,
    dimnames = list(axis, NULL)
  )
  pulses <- as.POSIXct(calendar$pulses_posix, tz = "UTC")
  cutoff <- pulses[[pulse_idx]] - if (isTRUE(strict_cutoff)) 1 else 0
  for (i in seq_along(axis)) {
    history <- provider$history(axis[[i]], cutoff)
    if (nrow(history) == 0L) next
    index <- match(
      as.numeric(as.POSIXct(history$ts_utc, tz = "UTC")),
      as.numeric(pulses[seq_len(pulse_idx)])
    )
    keep <- !is.na(index)
    close[i, index[keep]] <- as.numeric(history$close[keep])
  }
  state <- ledgr:::ledgr_availability_valuation_state(
    bars_mat = list(close = close),
    instrument_ids = axis,
    pulses_posix = pulses[seq_len(pulse_idx)],
    max_sessions = as.integer(provider$valuation_policy$max_sessions)
  )
  state$advance(pulse_idx, axis)
}

# ledgr-test-profile: review
testthat::test_that("workstream 8 hot-path substitutions preserve exact results", {
  alias_map <- c(fast = "sma_5", slow = "sma_20")
  testthat::expect_identical(
    ledgr:::ledgr_feature_lookup_map(active_alias_map = alias_map),
    workstream8_feature_lookup_oracle(active_alias_map = alias_map)
  )
  candidate_error <- rlang::catch_cnd(
    ledgr:::ledgr_feature_lookup_map(active_alias_map = NULL)
  )
  oracle_error <- rlang::catch_cnd(
    workstream8_feature_lookup_oracle(active_alias_map = NULL)
  )
  testthat::expect_identical(class(candidate_error), class(oracle_error))
  testthat::expect_error(
    ledgr:::ledgr_feature_lookup_map(
      active_alias_map = stats::setNames(1L, "fast")
    ),
    class = "ledgr_invalid_alias_map"
  )

  pulses <- as.POSIXct("2020-01-01", tz = "UTC") + 0:2 * 86400
  projection <- ledgr:::ledgr_runtime_projection(
    feature_values = list(signal = matrix(seq_len(6), nrow = 2L)),
    universe = c("AAA", "BBB"),
    pulses_posix = pulses
  )
  schema <- ledgr:::ledgr_projection_feature_table_schema()
  views <- ledgr:::ledgr_projection_pulse_views(projection, "signal")
  testthat::expect_identical(views$feature_table, replicate(3L, schema, simplify = FALSE))
  testthat::expect_identical(
    ledgr:::ledgr_projection_pulse_views(
      projection,
      "signal",
      feature_table = "full"
    )$features_wide,
    views$features_wide
  )
  testthat::expect_error(
    ledgr:::ledgr_projection_pulse_views(
      projection,
      "signal",
      feature_table = "third"
    ),
    class = "simpleError"
  )
  changed <- schema[, c("ts_utc", "instrument_id", "feature_name", "feature_value")]
  testthat::expect_false(identical(rep(list(changed), 3L), views$feature_table))
})

# ledgr-test-profile: review
testthat::test_that("features_wide uses integer indexing with last-write parity", {
  make_features <- function(n_instruments, n_features) {
    instruments <- sprintf("I%04d", seq_len(n_instruments))
    features <- sprintf("F%02d", seq_len(n_features))
    data.frame(
      instrument_id = rep(instruments, times = n_features),
      ts_utc = as.POSIXct("2020-01-01", tz = "UTC"),
      feature_name = rep(features, each = n_instruments),
      feature_value = seq_len(n_instruments * n_features),
      stringsAsFactors = FALSE
    )
  }
  for (shape in list(c(40L, 2L), c(200L, 5L), c(563L, 5L))) {
    input <- make_features(shape[[1L]], shape[[2L]])
    testthat::expect_identical(
      ledgr:::ledgr_features_wide(input),
      workstream8_features_wide_oracle(input)
    )
  }
  missing <- make_features(40L, 2L)
  missing$feature_value[c(1L, 17L)] <- NA_real_
  duplicate <- rbind(
    missing,
    transform(missing[1L, , drop = FALSE], feature_value = 999)
  )
  testthat::expect_identical(
    ledgr:::ledgr_features_wide(duplicate),
    workstream8_features_wide_oracle(duplicate)
  )
  testthat::expect_identical(
    ledgr:::ledgr_features_wide(duplicate)$F01[[1L]],
    999
  )
})

# ledgr-test-profile: review
testthat::test_that("identity helpers are unreachable from feature pulse access", {
  entry_points <- c(
    "ledgr_feature_bundle_accessor",
    "ledgr_projection_feature_bundle_accessor",
    "ledgr_projection_feature_bundle_accessor_state"
  )
  graph <- workstream8_reachable_functions(entry_points)
  testthat::expect_true("ledgr_feature_lookup_map" %in% graph$functions)
  testthat::expect_length(workstream8_forbidden_identity_calls(graph), 0L)

  mutant <- ledgr:::ledgr_feature_lookup_map
  body(mutant) <- quote({
    ledgr_alias_map_storage(active_alias_map)$alias_map
  })
  mutant_graph <- workstream8_reachable_functions(
    entry_points,
    overrides = list(ledgr_feature_lookup_map = mutant)
  )
  testthat::expect_true(
    "ledgr_alias_map_storage" %in%
      workstream8_forbidden_identity_calls(mutant_graph)
  )
})

# ledgr-test-profile: review
testthat::test_that("prepared availability input preserves the rowwise oracle", {
  facts <- workstream8_session_facts()
  facts_none <- ledgr_facts(ledgr_facts_trading_status(data.frame(
    instrument_id = "AAA",
    effective_from = as.POSIXct("2024-01-01", tz = "UTC"),
    status = "active",
    source = "workstream8",
    stringsAsFactors = FALSE
  )))
  cases <- list(
    posix_mixed = list(
      x = structure(c(
        as.numeric(as.POSIXct("2024-01-02 21:00:00", tz = "UTC")),
        NA_real_,
        as.numeric(as.POSIXct("2024-01-03 21:00:00", tz = "UTC")) + 0.5
      ), class = c("POSIXct", "POSIXt"), tzone = "UTC"),
      facts = facts
    ),
    character_mixed = list(
      x = c(
        "2024-01-02T21:00:00Z",
        "2024-01-03T21:00:00",
        "2024-01-04 21:00:00",
        "2024-01-05",
        "",
        "not-a-time",
        NA_character_
      ),
      facts = facts
    ),
    date_with_sessions = list(
      x = as.Date(c("2024-01-02", "2024-01-06", NA)),
      facts = facts
    ),
    date_without_sessions = list(
      x = as.Date(c("2024-01-02", NA)),
      facts = facts_none
    ),
    equivalent_timezones = list(
      x = as.POSIXct(
        c("2024-01-02 16:00:00", "2024-01-03 16:00:00"),
        tz = "America/New_York"
      ),
      facts = facts
    )
  )
  for (case in cases) {
    testthat::expect_identical(
      ledgr:::ledgr_availability_observation_times(case$x, case$facts),
      workstream8_old_observation_times(case$x, case$facts)
    )
  }

  bars <- workstream8_observation_bars()
  old_report <- local({
    testthat::local_mocked_bindings(
      ledgr_availability_observation_times = workstream8_old_observation_times,
      ledgr_availability_times_are_session_closes = workstream8_old_session_closes,
      .package = "ledgr"
    )
    ledgr_facts_validate(facts, bars, invalid_observations = "quarantine")
  })
  new_report <- ledgr_facts_validate(
    facts,
    bars,
    invalid_observations = "quarantine"
  )
  testthat::expect_identical(new_report, old_report)

  old_snapshot <- local({
    testthat::local_mocked_bindings(
      ledgr_availability_observation_times = workstream8_old_observation_times,
      ledgr_availability_times_are_session_closes = workstream8_old_session_closes,
      .package = "ledgr"
    )
    ledgr_snapshot_from_df(
      bars,
      facts = facts,
      invalid_observations = "quarantine",
      snapshot_id = "workstream8-parity",
      db_path = tempfile(fileext = ".duckdb")
    )
  })
  on.exit(ledgr_snapshot_close(old_snapshot), add = TRUE)
  new_snapshot <- ledgr_snapshot_from_df(
    bars,
    facts = facts,
    invalid_observations = "quarantine",
    snapshot_id = "workstream8-parity",
    db_path = tempfile(fileext = ".duckdb")
  )
  on.exit(ledgr_snapshot_close(new_snapshot), add = TRUE)
  testthat::expect_identical(
    ledgr_snapshot_info(new_snapshot)$snapshot_hash,
    ledgr_snapshot_info(old_snapshot)$snapshot_hash
  )
})

# ledgr-test-profile: review
testthat::test_that("availability parser optimization ships with the single-assert path", {
  facts <- workstream8_session_facts()
  bars <- workstream8_observation_bars()
  observed <- new.env(parent = emptyenv())
  observed$assertions <- 0L
  observed$parses <- 0L
  original_assert <- ledgr:::ledgr_facts_assert
  original_parse <- ledgr:::ledgr_fact_time
  testthat::local_mocked_bindings(
    ledgr_facts_assert = function(...) {
      observed$assertions <- observed$assertions + 1L
      original_assert(...)
    },
    ledgr_fact_time = function(...) {
      observed$parses <- observed$parses + 1L
      original_parse(...)
    },
    .package = "ledgr"
  )
  report <- ledgr:::ledgr_availability_validate_inputs(
    facts,
    bars,
    instruments_df = NULL,
    invalid_observations = "quarantine"
  )
  testthat::expect_true(report$can_seal)
  testthat::expect_identical(observed$assertions, 1L)
  # One witness binds the two LDG-2803 changes together: the exact distinct-
  # value parser is not permitted to ship without removal of the redundant
  # nested facts assertion that made the historical candidate incomplete.
  testthat::expect_identical(length(unique(bars$ts_utc)), 2L)
  testthat::expect_identical(observed$parses, 2L)
  testthat::expect_identical(
    report$observations$outcome,
    c("accepted", "accepted", "quarantine_candidate", "quarantine_candidate")
  )
  testthat::expect_identical(
    report$quarantine_rows$supplied_instrument_id,
    c("AAA", "BBB")
  )
})

# ledgr-test-profile: review
testthat::test_that("availability marks use one query and preserve the prefix oracle", {
  snapshot <- availability_runtime_fixture(days = 5L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      target <- ctx$hold()
      target[ctx$vec$member & !ctx$vec$target_restricted] <- 1
      target
    },
    valuation_policy = ledgr_valuation_stale(2),
    cost_model = ledgr_cost_zero()
  )
  run <- ledgr_run(experiment, run_id = "workstream8-marks")
  on.exit(close(run), add = TRUE)

  observed <- new.env(parent = emptyenv())
  observed$queries <- 0L
  original_rows <- ledgr:::ledgr_availability_marks_rows
  availability <- local({
    testthat::local_mocked_bindings(
      ledgr_availability_marks_rows = function(...) {
        observed$queries <- observed$queries + 1L
        original_rows(...)
      },
      .package = "ledgr"
    )
    tibble::as_tibble(ledgr_results(run, "availability"))
  })
  testthat::expect_identical(observed$queries, 1L)

  con <- ledgr:::get_connection(snapshot)
  provider <- ledgr:::ledgr_availability_provider(
    con,
    run$config,
    ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
  )
  calendar <- ledgr:::ledgr_availability_calendar(
    provider,
    run$config$backtest$start_ts_utc,
    run$config$backtest$end_ts_utc
  )
  pulses <- as.POSIXct(calendar$pulses_posix, tz = "UTC")
  bounded_rows <- ledgr:::ledgr_availability_marks_rows(
    con,
    ledgr_snapshot_info(snapshot)$snapshot_id[[1L]],
    unique(as.character(availability$instrument_id)),
    pulses[[1L]]
  )
  full_rows <- ledgr:::ledgr_availability_marks_rows(
    con,
    ledgr_snapshot_info(snapshot)$snapshot_id[[1L]],
    unique(as.character(availability$instrument_id)),
    pulses[[length(pulses)]]
  )
  testthat::expect_gt(nrow(bounded_rows), 0L)
  testthat::expect_lt(nrow(bounded_rows), nrow(full_rows))
  testthat::expect_true(all(bounded_rows$ts_utc <= pulses[[1L]]))
  times <- sort(unique(availability$ts_utc))
  for (time in times) {
    rows <- availability[availability$ts_utc == time, , drop = FALSE]
    axis <- as.character(rows$instrument_id)
    pulse_idx <- match(as.numeric(time), as.numeric(pulses))
    oracle <- workstream8_marks_oracle(provider, axis, calendar, pulse_idx)
    testthat::expect_identical(rows$priced, as.logical(oracle$priced[axis]))
    testthat::expect_identical(rows$mark_source, as.character(oracle$source[axis]))
    testthat::expect_identical(rows$mark_age, as.integer(oracle$age[axis]))
  }

  first <- availability[availability$ts_utc == min(times), , drop = FALSE]
  first_pulse <- match(as.numeric(min(times)), as.numeric(pulses))
  strict_mutant <- workstream8_marks_oracle(
    provider,
    as.character(first$instrument_id),
    calendar,
    first_pulse,
    strict_cutoff = TRUE
  )
  testthat::expect_false(identical(
    first$priced,
    as.logical(strict_mutant$priced[first$instrument_id])
  ))
})
