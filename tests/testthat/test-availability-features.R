availability_strict_matrix_fixture <- function() {
  dates <- as.Date("2020-01-01") + 0:6
  is_open <- seq_along(dates) != 3L
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = ifelse(is_open, "open", "closed"),
      session_open = ifelse(is_open, "09:30:00", NA_character_),
      session_close = ifelse(is_open, "16:00:00", NA_character_),
      knowledge_time = as.POSIXct("2019-12-01", tz = "UTC"),
      stringsAsFactors = FALSE
    ),
    venue_id = "XNYS"
  )
  observations <- data.frame(
    instrument_id = c(rep("AAA", 5L), rep("BBB", 3L)),
    day = c(1L, 2L, 5L, 6L, 7L, 5L, 6L, 7L),
    close = c(10, 12, 14, 16, 18, 20, 22, 24),
    stringsAsFactors = FALSE
  )
  observations$ts_utc <- as.POSIXct(
    paste(dates[observations$day], "16:00:00"),
    tz = "UTC"
  )
  observations$open <- observations$close
  observations$high <- observations$close + 1
  observations$low <- observations$close - 1
  observations$volume <- 1000
  bars <- observations[, c(
    "ts_utc", "instrument_id", "open", "high", "low", "close", "volume"
  )]
  ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
    facts = ledgr_facts(sessions), price_basis = "split_adjusted"
  )
}

availability_session_axis_fixture <- function() {
  dates <- as.Date("2020-01-01") + 0:4
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00",
      knowledge_time = as.POSIXct("2019-12-01", tz = "UTC"),
      stringsAsFactors = FALSE
    ),
    venue_id = "XNYS"
  )
  lifetime <- ledgr_facts_lifetime(data.frame(
    instrument_id = c("AAA", "BBB"),
    effective_from = as.POSIXct("2020-01-03 00:00:00", tz = "UTC"),
    effective_to = as.POSIXct("2020-01-05 00:00:00", tz = "UTC"),
    knowledge_time = as.POSIXct("2020-01-02 23:00:00", tz = "UTC"),
    assertion = "known_inactive",
    source = "session_axis_fixture",
    stringsAsFactors = FALSE
  ))
  observations <- data.frame(
    instrument_id = c(rep("AAA", 3L), rep("BBB", 5L)),
    day = c(1L, 2L, 5L, 1L, 2L, 3L, 4L, 5L),
    close = c(10, 12, 18, 20, 22, 24, 26, 28),
    stringsAsFactors = FALSE
  )
  observations$ts_utc <- as.POSIXct(
    paste(dates[observations$day], "16:00:00"),
    tz = "UTC"
  )
  observations$open <- observations$close
  observations$high <- observations$close + 1
  observations$low <- observations$close - 1
  observations$volume <- 1000
  bars <- observations[, c(
    "ts_utc", "instrument_id", "open", "high", "low", "close", "volume"
  )]
  ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
    facts = ledgr_facts(sessions, lifetime), price_basis = "split_adjusted"
  )
}

availability_strict_probe_strategy <- function(ctx, params) {
  encode <- function(value) {
    if (is.na(value)) "NA" else format(value, digits = 17, trim = TRUE)
  }
  values <- vapply(
    c("AAA", "BBB"),
    function(id) ctx$features(id)[["signal"]],
    numeric(1)
  )
  warning(
    sprintf(
      "STRICT_MATRIX|%d|%s|%s|%s",
      as.integer(params$window),
      ctx$ts_utc,
      encode(values[[1L]]),
      encode(values[[2L]])
    ),
    call. = FALSE
  )
  ctx$hold()
}

availability_strict_capture <- function(expr) {
  messages <- character()
  value <- withCallingHandlers(
    force(expr),
    warning = function(condition) {
      message <- conditionMessage(condition)
      if (startsWith(message, "STRICT_MATRIX|")) {
        messages <<- c(messages, message)
      }
      invokeRestart("muffleWarning")
    }
  )
  list(value = value, messages = messages)
}

availability_strict_sweep_messages <- function(sweep) {
  unlist(lapply(
    sweep$warnings,
    function(conditions) vapply(conditions, conditionMessage, character(1))
  ), use.names = FALSE)
}

availability_strict_matrix <- function(messages) {
  messages <- messages[startsWith(messages, "STRICT_MATRIX|")]
  fields <- strsplit(messages, "|", fixed = TRUE)
  out <- data.frame(
    window = as.integer(vapply(fields, `[[`, character(1), 2L)),
    ts_utc = vapply(fields, `[[`, character(1), 3L),
    AAA = suppressWarnings(as.numeric(vapply(fields, `[[`, character(1), 4L))),
    BBB = suppressWarnings(as.numeric(vapply(fields, `[[`, character(1), 5L))),
    stringsAsFactors = FALSE
  )
  out[order(out$window, out$ts_utc), , drop = FALSE]
}

availability_strict_expected <- function(window) {
  pulses <- paste0(
    c("2020-01-01", "2020-01-02", "2020-01-04", "2020-01-05", "2020-01-06", "2020-01-07"),
    "T16:00:00Z"
  )
  values <- switch(
    as.character(window),
    `2` = list(
      AAA = c(NA, 11, NA, NA, 15, 17),
      BBB = c(NA, NA, NA, NA, 21, 23)
    ),
    `3` = list(
      AAA = c(NA, NA, NA, NA, NA, 16),
      BBB = c(NA, NA, NA, NA, NA, 22)
    ),
    stop("unsupported expected window")
  )
  data.frame(
    window = rep(as.integer(window), length(pulses)),
    ts_utc = pulses,
    AAA = values$AAA,
    BBB = values$BBB,
    stringsAsFactors = FALSE
  )
}

# Under the default history policy, AAA's missing 4 January close is carried
# from 2 January (v12 Section 5); BBB has no earlier source to carry.
availability_carry_expected <- function(window) {
  out <- availability_strict_expected(window)
  out$AAA <- switch(
    as.character(window),
    `2` = c(NA, 11, 12, 13, 15, 17),
    `3` = c(NA, NA, 34 / 3, 38 / 3, 14, 16),
    stop("unsupported expected window")
  )
  out
}

availability_strict_policy <- function() {
  ledgr_history_policy(price_carry = NULL)
}

# ledgr-test-profile: fast
testthat::test_that("[LTB-0093] lifetime inactivity keeps venue feature sessions", {
  snapshot <- availability_session_axis_fixture()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- ledgr_experiment(
    snapshot,
    availability_strict_probe_strategy,
    features = ledgr_feature_map(signal = ledgr_ind_sma(2L)),
    valuation_policy = ledgr_valuation_stale(1L),
    cost_model = ledgr_cost_zero()
  )
  captured <- availability_strict_capture(ledgr_run(
    experiment,
    params = list(window = 2L),
    run_id = "lifetime-feature-session-axis"
  ))
  on.exit(close(captured$value), add = TRUE)

  actual <- availability_strict_matrix(captured$messages)
  expected <- data.frame(
    window = rep(2L, 5L),
    ts_utc = paste0(
      format(as.Date("2020-01-01") + 0:4, "%Y-%m-%d"),
      "T16:00:00Z"
    ),
    AAA = c(NA, 11, NA, NA, 15),
    BBB = c(NA, 21, NA, NA, 25),
    stringsAsFactors = FALSE
  )
  testthat::expect_identical(
    actual[, c("window", "ts_utc")],
    expected[, c("window", "ts_utc")]
  )
  testthat::expect_equal(actual[, c("AAA", "BBB")], expected[, c("AAA", "BBB")])

  # The window after the interval counts expected sessions: 2 and 5 January.
  post_interval <- actual$ts_utc == "2020-01-05T16:00:00Z"
  testthat::expect_equal(actual$AAA[post_interval], (12 + 18) / 2)
  testthat::expect_equal(actual$BBB[post_interval], (22 + 28) / 2)
  # BBB's real prints inside the interval (24, 26) enter no calculation.
  inactive_interval <- actual$ts_utc %in% c(
    "2020-01-03T16:00:00Z",
    "2020-01-04T16:00:00Z"
  )
  testthat::expect_true(all(is.na(actual$BBB[inactive_interval])))

  inactive_explanation <- ledgr_run_explain(
    captured$value,
    "BBB",
    as.POSIXct("2020-01-03 16:00:00", tz = "UTC")
  )
  testthat::expect_true(inactive_explanation$target_restricted[[1L]])
  testthat::expect_identical(
    inactive_explanation$target_restriction_reason[[1L]],
    "lifetime_inactive"
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0073] strict feature matrices survive every execution route", {
  snapshot <- availability_strict_matrix_fixture()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  opening <- ledgr_opening(
    cash = 100000,
    positions = c(AAA = 1),
    cost_basis = c(AAA = 10)
  )
  concrete <- ledgr_experiment(
    snapshot,
    availability_strict_probe_strategy,
    features = ledgr_feature_map(signal = ledgr_ind_sma(2)),
    opening = opening,
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero(),
    history_policy = availability_strict_policy()
  )
  parameterized <- ledgr_experiment(
    snapshot,
    availability_strict_probe_strategy,
    features = ledgr_feature_map(signal = ledgr_ind_sma(ledgr_param("n"))),
    opening = opening,
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero(),
    history_policy = availability_strict_policy()
  )
  grid <- ledgr_grid_named(
    two = list(feature = list(n = 2L), strategy = list(window = 2L)),
    three = list(feature = list(n = 3L), strategy = list(window = 3L))
  )

  direct_cold <- availability_strict_capture(ledgr_run(
    concrete,
    params = list(window = 2L),
    run_id = "strict-direct-cold"
  ))
  on.exit(close(direct_cold$value), add = TRUE)
  direct_warm <- availability_strict_capture(ledgr_run(
    concrete,
    params = list(window = 2L),
    run_id = "strict-direct-warm"
  ))
  on.exit(close(direct_warm$value), add = TRUE)
  testthat::expect_identical(
    direct_warm$value$config$config_hash,
    direct_cold$value$config$config_hash
  )

  one <- ledgr_sweep(
    concrete,
    ledgr_param_grid(one = list(window = 2L)),
    stop_on_error = TRUE
  )
  sequential <- ledgr_sweep(parameterized, grid, stop_on_error = TRUE)
  parallel <- NULL
  if (requireNamespace("mirai", quietly = TRUE) && !ledgr_test_in_coverage()) {
    parallel <- ledgr_sweep(
      parameterized,
      grid,
      workers = 2L,
      stop_on_error = TRUE
    )
  }

  partial <- availability_strict_capture(ledgr:::ledgr_run_fold(
    direct_cold$value$config,
    run_id = "strict-resume",
    control = list(max_pulses = 3L)
  ))
  resumed <- availability_strict_capture(ledgr_run_config(
    direct_cold$value$config,
    run_id = "strict-resume"
  ))
  resume_messages <- c(partial$messages, resumed$messages)

  observed <- list(
    direct_cold = direct_cold$messages,
    direct_warm = direct_warm$messages,
    one_candidate_sequential = availability_strict_sweep_messages(one),
    multi_candidate_sequential = availability_strict_sweep_messages(sequential),
    interrupted_resume = resume_messages
  )
  if (!is.null(parallel)) {
    observed$multi_candidate_parallel <- availability_strict_sweep_messages(parallel)
  }
  expected_windows <- list(
    direct_cold = 2L,
    direct_warm = 2L,
    one_candidate_sequential = 2L,
    multi_candidate_sequential = c(2L, 3L),
    interrupted_resume = 2L,
    multi_candidate_parallel = c(2L, 3L)
  )
  for (route in names(observed)) {
    actual <- availability_strict_matrix(observed[[route]])
    expected <- do.call(rbind, lapply(
      expected_windows[[route]],
      availability_strict_expected
    ))
    rownames(expected) <- NULL
    testthat::expect_identical(
      actual[, c("window", "ts_utc")],
      expected[, c("window", "ts_utc")],
      info = paste(route, "keeps the expected-session pulse and window identity")
    )
    testthat::expect_identical(
      unname(is.na(as.matrix(actual[, c("AAA", "BBB")]))),
      unname(is.na(as.matrix(expected[, c("AAA", "BBB")]))),
      info = paste(route, "keeps warmup, gap, recovery and late-start NA positions")
    )
    testthat::expect_equal(
      actual[, c("AAA", "BBB")],
      expected[, c("AAA", "BBB")],
      tolerance = 1e-12,
      info = paste(route, "keeps finite strict-window values")
    )
  }

  carried <- ledgr_experiment(
    snapshot,
    availability_strict_probe_strategy,
    features = ledgr_feature_map(signal = ledgr_ind_sma(ledgr_param("n"))),
    opening = opening,
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  carried_sweep <- ledgr_sweep(carried, grid, stop_on_error = TRUE)
  carried_concrete <- ledgr_experiment(
    snapshot,
    availability_strict_probe_strategy,
    features = ledgr_feature_map(signal = ledgr_ind_sma(2)),
    opening = opening,
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  carried_direct <- availability_strict_capture(ledgr_run(
    carried_concrete,
    params = list(window = 2L),
    run_id = "strict-default-carry"
  ))
  on.exit(close(carried_direct$value), add = TRUE)
  carried_expected <- rbind(
    availability_carry_expected(2L),
    availability_carry_expected(3L)
  )
  rownames(carried_expected) <- NULL
  testthat::expect_equal(
    availability_strict_matrix(availability_strict_sweep_messages(carried_sweep)),
    carried_expected,
    tolerance = 1e-12
  )
  testthat::expect_equal(
    availability_strict_matrix(carried_direct$messages),
    availability_carry_expected(2L),
    tolerance = 1e-12
  )

  equity <- ledgr_results(direct_cold$value, "equity")
  missing_pulse <- format(
    as.POSIXct(equity$ts_utc, tz = "UTC"),
    "%Y-%m-%dT%H:%M:%SZ",
    tz = "UTC"
  ) == "2020-01-04T16:00:00Z"
  testthat::expect_identical(sum(missing_pulse), 1L)
  testthat::expect_true(is.finite(equity$positions_value[missing_pulse]))
  direct_matrix <- availability_strict_matrix(direct_cold$messages)
  testthat::expect_true(is.na(direct_matrix$AAA[direct_matrix$ts_utc == "2020-01-04T16:00:00Z"]))

  defs <- ledgr:::ledgr_resolve_feature_candidates(parameterized, grid, stop_on_error = TRUE)
  testthat::expect_identical(
    vapply(defs$candidates, function(x) x$feature_defs[[1L]]$gap_contract, character(1)),
    c("strict_window", "strict_window")
  )
  testthat::expect_identical(
    defs$candidate_features$feature_ids,
    list("sma_2", "sma_3")
  )

  article <- readLines(
    testthat::test_path("..", "..", "vignettes", "missing-data-and-sessions.qmd"),
    warn = FALSE
  )
  table_start <- match("<!-- strict-gap-table:start -->", article)
  table_end <- match("<!-- strict-gap-table:end -->", article)
  testthat::expect_true(!is.na(table_start) && !is.na(table_end))
  table_lines <- article[(table_start + 1L):(table_end - 1L)]
  table_lines <- table_lines[grepl("^\\| 2020-[0-9]{2}-[0-9]{2} \\|", table_lines)]
  cells <- lapply(table_lines, function(line) {
    trimws(strsplit(sub("^\\||\\|$", "", line), "|", fixed = TRUE)[[1L]])
  })
  documented <- as.data.frame(
    do.call(rbind, cells),
    stringsAsFactors = FALSE
  )
  names(documented) <- c(
    "date", "session", "AAA_bar", "AAA", "BBB_bar", "BBB", "meaning"
  )
  testthat::expect_identical(
    documented$date,
    format(as.Date("2020-01-01") + 0:6, "%Y-%m-%d")
  )
  testthat::expect_identical(
    documented$session,
    c("open", "open", "closed", "open", "open", "open", "open")
  )
  testthat::expect_identical(
    documented$AAA_bar,
    c("10", "12", "no pulse", "missing", "14", "16", "18")
  )
  testthat::expect_identical(
    documented$BBB_bar,
    c("absent", "absent", "no pulse", "absent", "20", "22", "24")
  )
  open_rows <- documented$session == "open"
  value <- function(x) {
    out <- suppressWarnings(as.numeric(x))
    out[x == "NA"] <- NA_real_
    out
  }
  expected_two <- availability_strict_expected(2L)
  testthat::expect_identical(
    documented$date[open_rows],
    substr(expected_two$ts_utc, 1L, 10L)
  )
  testthat::expect_equal(value(documented$AAA[open_rows]), expected_two$AAA)
  testthat::expect_equal(value(documented$BBB[open_rows]), expected_two$BBB)
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0074] public TTR SMA shares the strict-window contract", {
  testthat::skip_if_not_installed("TTR")
  snapshot <- availability_strict_matrix_fixture()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  opening <- ledgr_opening(
    cash = 100000,
    positions = c(AAA = 1),
    cost_basis = c(AAA = 10)
  )
  ttr_sma <- ledgr_ind_ttr("SMA", input = "close", n = 2L)
  custom_sma <- ledgr_indicator(
    "custom_sma_2",
    function(window) mean(window$close),
    requires_bars = 2L,
    gap_contract = "strict_window"
  )
  indicators <- list(
    built_in = ledgr_ind_sma(2L),
    public_ttr = ttr_sma,
    custom = custom_sma
  )
  testthat::expect_identical(
    vapply(indicators, `[[`, character(1), "gap_contract"),
    c(built_in = "strict_window", public_ttr = "strict_window", custom = "strict_window")
  )

  dense_ttr <- ttr_sma
  dense_ttr$gap_contract <- NULL
  testthat::expect_identical(
    ledgr_indicator_fingerprint(ttr_sma),
    ledgr_indicator_fingerprint(dense_ttr)
  )
  dense_bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
    close = c(10, 12, 14, 16)
  )
  testthat::expect_identical(
    ledgr:::ledgr_compute_feature_series(dense_bars, ttr_sma),
    ledgr:::ledgr_compute_feature_series(dense_bars, dense_ttr)
  )

  # The strict-window certification of TTR forms is the bounded rows of the
  # package catalogue (v12 Section 6); every other form follows the custom
  # rules and is not a strict window.
  catalogue_cases <- list(
    certified = list("SMA", "close", NULL, list(n = 2L), 2L, "bounded"),
    history_dependent_ema = list("EMA", "close", NULL, list(n = 2L), 2L, "history_dependent"),
    history_dependent_rsi = list("RSI", "close", NULL, list(n = 2L), 3L, "history_dependent"),
    wrong_input = list("SMA", "hl", NULL, list(n = 2L), 2L, NA_character_),
    selected_output = list("SMA", "close", "value", list(n = 2L), 2L, NA_character_),
    extra_argument = list("SMA", "close", NULL, list(n = 2L, extra = TRUE), 2L, NA_character_),
    wrong_requires = list("SMA", "close", NULL, list(n = 2L), 3L, NA_character_)
  )
  for (case in catalogue_cases) {
    row <- do.call(
      ledgr:::ledgr_ttr_catalogue_row,
      stats::setNames(case[1:5], c(
        "ttr_fn", "input", "output", "args", "requires_bars"
      ))
    )
    actual <- if (is.null(row)) NA_character_ else row$history_class[[1L]]
    testthat::expect_identical(actual, case[[6L]])
  }
  testthat::expect_null(ledgr_ind_ttr("EMA", input = "close", n = 2L)$gap_contract)
  testthat::expect_null(ledgr_ind_ttr("RSI", input = "close", n = 2L)$gap_contract)
  bbands_bundle <- ledgr_ind_ttr_outputs(
    "BBands",
    input = "close",
    outputs = c("dn", "up"),
    n = 2L
  )
  testthat::expect_s3_class(bbands_bundle, "ledgr_indicator_bundle")
  testthat::expect_true(all(vapply(
    ledgr:::ledgr_indicator_bundle_indicators(bbands_bundle),
    function(indicator) identical(indicator$gap_contract, "strict_window"),
    logical(1)
  )))
  root <- ledgr_test_source_root()
  if (ledgr_test_design_source_context(root)) {
    contract_text <- paste(readLines(
      file.path(root, "inst", "design", "contracts.md"),
      warn = FALSE
    ), collapse = "\n")
    testthat::expect_match(
      contract_text,
      "A history-dependent definition runs once per contiguous segment",
      fixed = TRUE
    )
    testthat::expect_match(
      contract_text,
      "Return- and volatility-family catalogue rows never consume a carried",
      fixed = TRUE
    )
  }

  indicator_article <- readLines(
    testthat::test_path("..", "..", "vignettes", "indicators.qmd"),
    warn = FALSE
  )
  support_start <- match("<!-- strict-gap-support:start -->", indicator_article)
  support_end <- match("<!-- strict-gap-support:end -->", indicator_article)
  testthat::expect_true(!is.na(support_start) && !is.na(support_end))
  support_lines <- indicator_article[(support_start + 1L):(support_end - 1L)]
  support_lines <- support_lines[
    grepl("^\\| ", support_lines) & !grepl("^\\| ---", support_lines)
  ]
  support_cells <- lapply(support_lines[-1L], function(line) {
    trimws(strsplit(sub("^\\||\\|$", "", line), "|", fixed = TRUE)[[1L]])
  })
  documented_class <- stats::setNames(
    vapply(support_cells, `[[`, character(1), 3L),
    vapply(support_cells, `[[`, character(1), 1L)
  )
  # Every documented form runs in availability mode; the documented history
  # class must be the class the constructors declare.
  class_of <- function(indicators) {
    classes <- unique(vapply(indicators, `[[`, character(1), "history_class"))
    if (length(classes) == 1L) classes else "per catalogue row"
  }
  forms <- list(
    "Built-in SMA, EMA, RSI or returns" = list(
      ledgr_ind_sma(2L), ledgr_ind_ema(2L), ledgr_ind_rsi(2L), ledgr_ind_returns(2L)
    ),
    "Registered TTR form" = list(
      ttr_sma,
      ledgr_ind_ttr("EMA", input = "close", n = 2L),
      ledgr_ind_ttr("RSI", input = "close", n = 2L, maType = "SMA")
    ),
    "TTR output bundle" = c(
      ledgr:::ledgr_indicator_bundle_indicators(bbands_bundle),
      ledgr:::ledgr_indicator_bundle_indicators(ledgr_ind_ttr_outputs(
        "MACD", input = "close", nFast = 2L, nSlow = 3L, nSig = 2L
      ))
    ),
    "Custom bounded declaration" = list(custom_sma),
    "Undeclared custom or unregistered TTR form" = list(
      ledgr_indicator("undeclared", function(window) mean(window$close), requires_bars = 2L),
      ledgr_ind_ttr("SMA", input = "close", n = 2L, requires_bars = 3L),
      ledgr_ind_ttr("RSI", input = "close", n = 2L, requires_bars = 2L)
    )
  )
  executable_class <- vapply(forms, function(indicators) {
    admitted <- tryCatch({
      ledgr:::ledgr_availability_validate_features(indicators, "list")
      TRUE
    }, error = function(e) FALSE)
    if (!admitted) return("refused")
    switch(
      class_of(indicators),
      bounded = "Supported: bounded",
      history_dependent = "Supported: history-dependent",
      "Supported: per catalogue row"
    )
  }, character(1))
  testthat::expect_identical(documented_class, executable_class)

  source_messages <- list()
  source_runs <- list()
  for (source in names(indicators)) {
    experiment <- ledgr_experiment(
      snapshot,
      availability_strict_probe_strategy,
      features = ledgr_feature_map(signal = indicators[[source]]),
      opening = opening,
      valuation_policy = ledgr_valuation_stale(1),
      cost_model = ledgr_cost_zero()
    )
    captured <- availability_strict_capture(ledgr_run(
      experiment,
      params = list(window = 2L),
      run_id = paste0("strict-source-", source)
    ))
    on.exit(close(captured$value), add = TRUE)
    source_runs[[source]] <- list(experiment = experiment, backtest = captured$value)
    source_messages[[source]] <- availability_strict_matrix(captured$messages)
    testthat::expect_identical(
      unname(is.na(as.matrix(source_messages[[source]][, c("AAA", "BBB")]))),
      unname(is.na(as.matrix(availability_carry_expected(2L)[, c("AAA", "BBB")])))
    )
    testthat::expect_equal(
      unname(as.matrix(source_messages[[source]][, c("AAA", "BBB")])),
      unname(as.matrix(availability_carry_expected(2L)[, c("AAA", "BBB")])),
      tolerance = 1e-8
    )
  }
  testthat::expect_equal(
    unname(as.matrix(source_messages$public_ttr[, c("AAA", "BBB")])),
    unname(as.matrix(source_messages$built_in[, c("AAA", "BBB")])),
    tolerance = 1e-8
  )
  testthat::expect_equal(
    unname(as.matrix(source_messages$custom[, c("AAA", "BBB")])),
    unname(as.matrix(source_messages$built_in[, c("AAA", "BBB")])),
    tolerance = 1e-8
  )

  ttr_experiment <- source_runs$public_ttr$experiment
  ttr_cold <- availability_strict_capture(ledgr_run(
    ttr_experiment,
    params = list(window = 2L),
    run_id = "strict-ttr-cold"
  ))
  on.exit(close(ttr_cold$value), add = TRUE)
  ttr_warm <- availability_strict_capture(ledgr_run(
    ttr_experiment,
    params = list(window = 2L),
    run_id = "strict-ttr-warm"
  ))
  on.exit(close(ttr_warm$value), add = TRUE)
  testthat::expect_identical(
    availability_strict_matrix(ttr_warm$messages),
    availability_strict_matrix(ttr_cold$messages)
  )

  ttr_one <- ledgr_sweep(
    ttr_experiment,
    ledgr_param_grid(one = list(window = 2L)),
    stop_on_error = TRUE
  )
  testthat::expect_identical(ttr_one$status, "DONE")
  testthat::expect_equal(
    unname(as.matrix(availability_strict_matrix(
      availability_strict_sweep_messages(ttr_one)
    )[, c("AAA", "BBB")])),
    unname(as.matrix(availability_carry_expected(2L)[, c("AAA", "BBB")])),
    tolerance = 1e-8
  )

  ttr_parameterized <- ledgr_experiment(
    snapshot,
    availability_strict_probe_strategy,
    features = ledgr_feature_map(
      signal = ledgr_ind_ttr("SMA", input = "close", n = ledgr_param("n"))
    ),
    opening = opening,
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  ttr_grid <- ledgr_grid_named(
    two = list(feature = list(n = 2L), strategy = list(window = 2L)),
    three = list(feature = list(n = 3L), strategy = list(window = 3L))
  )
  ttr_sweep <- ledgr_sweep(ttr_parameterized, ttr_grid, stop_on_error = TRUE)
  testthat::expect_identical(ttr_sweep$status, c("DONE", "DONE"))
  testthat::expect_equal(
    unname(as.matrix(availability_strict_matrix(
      availability_strict_sweep_messages(ttr_sweep)
    )[, c("AAA", "BBB")])),
    unname(as.matrix(rbind(
      availability_carry_expected(2L)[, c("AAA", "BBB")],
      availability_carry_expected(3L)[, c("AAA", "BBB")]
    ))),
    tolerance = 1e-8
  )

  partial <- availability_strict_capture(ledgr:::ledgr_run_fold(
    ttr_cold$value$config,
    run_id = "strict-ttr-resume",
    control = list(max_pulses = 3L)
  ))
  resumed <- availability_strict_capture(ledgr_run_config(
    ttr_cold$value$config,
    run_id = "strict-ttr-resume"
  ))
  testthat::expect_equal(
    unname(as.matrix(availability_strict_matrix(
      c(partial$messages, resumed$messages)
    )[, c("AAA", "BBB")])),
    unname(as.matrix(availability_carry_expected(2L)[, c("AAA", "BBB")])),
    tolerance = 1e-8
  )

  # History-dependent TTR forms and bundles now run (v12 Section 6) rather
  # than refusing with the retired gap_unsupported condition.
  for (history_feature in list(
    list(ledgr_ind_ttr("EMA", input = "close", n = 2L)),
    list(ledgr_ind_ttr("RSI", input = "close", n = 2L)),
    list(ledgr_ind_ttr_outputs("MACD", input = "close", nSlow = 3L, nFast = 2L, nSig = 2L))
  )) {
    experiment <- ledgr_experiment(
      snapshot,
      function(ctx, params) ctx$hold(),
      features = history_feature,
      valuation_policy = ledgr_valuation_stale(1),
      cost_model = ledgr_cost_zero()
    )
    testthat::expect_s3_class(experiment, "ledgr_experiment")
  }
})

testthat::test_that("strict scalar series and active identity contracts agree", {
  strict <- ws43_history_substrate(
    c(100, 101, NA, 103),
    policy = ledgr_history_policy(price_carry = NULL)
  )
  sma <- ledgr_ind_sma(2)
  dense_sma <- sma
  dense_sma$gap_contract <- NULL
  testthat::expect_equal(
    ws43_feature_values(strict, sma),
    c(NA, 100.5, NA, NA)
  )
  testthat::expect_identical(
    ledgr_indicator_fingerprint(sma),
    ledgr_indicator_fingerprint(dense_sma)
  )
  testthat::expect_identical(
    ledgr_feature_engine_version(),
    ledgr_feature_engine_version(FALSE)
  )
  testthat::expect_false(identical(
    ledgr_feature_engine_version(),
    ledgr_feature_engine_version(TRUE)
  ))

  disagreeing <- ledgr_indicator(
    "disagreeing",
    function(window) mean(window$close),
    requires_bars = 2,
    series_fn = function(bars, params) rep(0, nrow(bars)),
    gap_contract = "strict_window"
  )
  testthat::expect_error(
    ws43_feature_values(strict, disagreeing),
    class = "ledgr_indicator_gap_parity"
  )
})

# ledgr-test-profile: review
testthat::test_that("undeclared indicators run as history-dependent in availability experiments", {
  snapshot <- availability_runtime_fixture(days = 6L, bar_days = c(1L, 2L, 4L, 5L, 6L))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  undeclared <- ledgr_indicator(
    "undeclared",
    function(window) mean(window$close),
    requires_bars = 2
  )
  testthat::expect_identical(undeclared$history_class, "history_dependent")
  strategy <- function(ctx, params) {
    value <- ctx$feature("AAA", "undeclared")
    history <- if (is.null(ctx$state_prev$history)) list() else ctx$state_prev$history
    history[[length(history) + 1L]] <- if (is.na(value)) "NA" else format(value, digits = 17)
    list(targets = ctx$hold(), state_update = list(history = history))
  }
  run <- ledgr_run(ledgr_experiment(
    snapshot,
    strategy,
    features = list(undeclared),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero(),
    history_policy = ledgr_history_policy(price_carry = NULL)
  ))
  on.exit(close(run), add = TRUE)
  # Session 3 has no bar: the segment restarts at session 4 and re-warms.
  testthat::expect_identical(
    unlist(availability_last_state(run)$history),
    c("NA", "101.5", "NA", "NA", "104.5", "105.5")
  )
})

# ledgr-test-profile: review
testthat::test_that("future facts do not change earlier features", {
  future_status <- ledgr_facts_trading_status(data.frame(
    instrument_id = "AAA",
    effective_from = as.POSIXct("2020-02-01", tz = "UTC"),
    knowledge_time = as.POSIXct("2020-02-01", tz = "UTC"),
    status = "halted",
    source = "future",
    precedence = 1L
  ))
  snapshots <- list(
    availability_runtime_fixture(),
    availability_runtime_fixture(status = future_status)
  )
  on.exit(lapply(snapshots, ledgr_snapshot_close), add = TRUE)
  strategy <- function(ctx, params) {
    history <- if (is.null(ctx$state_prev$history)) list() else ctx$state_prev$history
    value <- ctx$feature("AAA", "sma_2")
    history[[length(history) + 1L]] <- if (is.na(value)) "NA" else format(value, digits = 17)
    list(targets = ctx$hold(), state_update = list(history = history))
  }
  runs <- lapply(snapshots, function(snapshot) {
    ledgr_run(ledgr_experiment(
      snapshot,
      strategy,
      features = list(ledgr_ind_sma(2)),
      valuation_policy = ledgr_valuation_stale(1),
      cost_model = ledgr_cost_zero()
    ))
  })
  on.exit(lapply(runs, close), add = TRUE)
  testthat::expect_identical(
    availability_last_state(runs[[1L]])$history,
    availability_last_state(runs[[2L]])$history
  )
})
