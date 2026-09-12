testthat::test_that("availability policies activate explicitly and preserve dense omission", {
  rule <- ledgr_universe_members("dynamic")
  valuation <- ledgr_valuation_stale(0)
  testthat::expect_s3_class(rule, "ledgr_universe_rule")
  testthat::expect_s3_class(valuation, "ledgr_valuation_policy")
  testthat::expect_output(print(rule), "Universe ID: dynamic", fixed = TRUE)
  testthat::expect_output(print(valuation), "Maximum age: 0 sessions", fixed = TRUE)
  testthat::expect_error(ledgr_universe_members(""), class = "ledgr_fact_invalid_id")
  testthat::expect_error(ledgr_valuation_stale(-1), class = "ledgr_invalid_valuation_policy")

  dense_bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2,
    instrument_id = "AAA",
    open = 100:102,
    high = 101:103,
    low = 99:101,
    close = 100:102,
    volume = 1000
  )
  dense_snapshot <- ledgr_snapshot_from_df(dense_bars)
  on.exit(ledgr_snapshot_close(dense_snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$hold()
  dense <- ledgr_experiment(dense_snapshot, strategy, cost_model = ledgr_cost_zero())
  testthat::expect_null(dense$availability)
  dense_plan <- ledgr_experiment_plan(dense)
  testthat::expect_false(dense_plan$availability_active)
  testthat::expect_true(all(dense_plan$checks$status == "disabled"))
  dense_bt <- ledgr_run(dense)
  on.exit(close(dense_bt), add = TRUE)
  testthat::expect_s3_class(dense_bt, "ledgr_backtest")
  testthat::expect_null(availability_run_config(dense_bt)$availability)

  sma <- ledgr_ind_sma(2)
  sma_without_gap <- sma
  sma_without_gap$gap_contract <- NULL
  dense_feature <- ledgr_experiment(
    dense_snapshot,
    strategy,
    features = list(sma),
    cost_model = ledgr_cost_zero()
  )
  dense_feature_without_gap <- ledgr_experiment(
    dense_snapshot,
    strategy,
    features = list(sma_without_gap),
    cost_model = ledgr_cost_zero()
  )
  dense_feature_bt <- ledgr_run(dense_feature)
  dense_feature_without_gap_bt <- ledgr_run(dense_feature_without_gap)
  on.exit(close(dense_feature_bt), add = TRUE)
  on.exit(close(dense_feature_without_gap_bt), add = TRUE)
  testthat::expect_null(dense_feature_bt$config$features$defs[[1L]]$gap_contract)
  testthat::expect_identical(
    ledgr:::config_hash(dense_feature_bt$config),
    ledgr:::config_hash(dense_feature_without_gap_bt$config)
  )

  snapshot <- availability_runtime_fixture()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  testthat::expect_error(
    ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero()),
    class = "ledgr_valuation_policy_required"
  )
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  plan <- ledgr_experiment_plan(exp)
  testthat::expect_output(print(plan), "Availability: active", fixed = TRUE)
  testthat::expect_true(plan$availability_active)
  testthat::expect_identical(plan$universe_type, "fixed")
  testthat::expect_identical(plan$checks$status, c("omitted", "declared", "omitted", "omitted"))
  active_bt <- ledgr_run(exp)
  on.exit(close(active_bt), add = TRUE)
  testthat::expect_s3_class(active_bt, "ledgr_backtest")
  testthat::expect_true(availability_run_config(active_bt)$availability$active)
  testthat::expect_error(
    ledgr_run(exp, compiled_accounting_model = "spot_fifo"),
    class = "ledgr_compiled_availability_unsupported"
  )
})

testthat::test_that("effective plans disclose assumption-backed fact families", {
  dates <- as.Date("2020-01-01") + 0:2
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00"
    ),
    venue_id = "XNYS",
    knowledge = "assume_effective"
  )
  ts <- as.POSIXct(paste(dates, "16:00:00"), tz = "UTC")
  bars <- data.frame(
    ts_utc = ts,
    instrument_id = "AAA",
    open = 100:102,
    high = 101:103,
    low = 99:101,
    close = 100:102,
    volume = 1000
  )
  snapshot <- ledgr_snapshot_from_df(bars, facts = ledgr_facts(sessions))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$hold(),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  plan <- ledgr_experiment_plan(exp)
  testthat::expect_identical(
    plan$checks$status,
    c("omitted", "assumption_backed", "omitted", "omitted")
  )
})

testthat::test_that("fixed baskets remain fixed when availability facts are declared", {
  dates <- as.POSIXct(c("2020-01-01", "2020-01-02"), tz = "UTC")
  membership <- ledgr_facts_membership_snapshots(
    data.frame(
      instrument_id = c(NA_character_, NA_character_),
      effective_from = dates,
      knowledge_time = dates - 1
    ),
    universe_id = "different_rule",
    complete = TRUE
  )
  snapshot <- availability_runtime_fixture(membership = membership)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    list(
      targets = ctx$hold(),
      state_update = list(members = ctx$members)
    )
  }
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    universe = "AAA",
    valuation_policy = ledgr_valuation_stale(0),
    cost_model = ledgr_cost_zero()
  )
  testthat::expect_identical(ledgr_experiment_plan(exp)$universe_type, "fixed")
  bt <- ledgr_run(exp)
  on.exit(close(bt), add = TRUE)
  testthat::expect_identical(availability_last_state(bt)$members, "AAA")
})

testthat::test_that(
  "active construction requires sessions valuation and a declared membership rule",
  {
  dates <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2
  bars <- data.frame(
    ts_utc = dates,
    instrument_id = "AAA",
    open = 100:102,
    high = 101:103,
    low = 99:101,
    close = 100:102,
    volume = 1000
  )
  status <- ledgr_facts_trading_status(data.frame(
    instrument_id = "AAA",
    effective_from = dates[[1L]],
    knowledge_time = dates[[1L]] - 1,
    status = "active",
    source = "test",
    precedence = 1L
  ))
  no_sessions <- ledgr_snapshot_from_df(bars, facts = ledgr_facts(status))
  on.exit(ledgr_snapshot_close(no_sessions), add = TRUE)
  strategy <- function(ctx, params) ctx$hold()
  testthat::expect_error(
    ledgr_experiment(
      no_sessions,
      strategy,
      valuation_policy = ledgr_valuation_stale(1),
      cost_model = ledgr_cost_zero()
    ),
    class = "ledgr_availability_sessions_required"
  )

  snapshot <- availability_runtime_fixture()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  testthat::expect_error(
    ledgr_experiment(
      snapshot,
      strategy,
      universe = ledgr_universe_members("missing"),
      valuation_policy = ledgr_valuation_stale(1),
      cost_model = ledgr_cost_zero()
    ),
    class = "ledgr_membership_universe_not_found"
  )
  }
)

# Regression: the run window bounds are ISO8601 strings with `T`/`Z`. Parsing
# them without an explicit format silently truncates to midnight, which drops
# the final session close from the decision axis and strands the last target.
availability_window_fixture <- function(session_open = "14:30:00",
                                        session_close = "21:00:00") {
  dates <- as.Date(c("2020-01-13", "2020-01-14", "2020-01-15", "2020-01-16", "2020-01-17"))
  ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = session_open,
      session_close = session_close,
      knowledge_time = as.POSIXct("2020-01-01", tz = "UTC"),
      stringsAsFactors = FALSE
    ),
    venue_id = "DEMO",
    timezone = "UTC"
  )
}

testthat::test_that("run window bounds keep their time of day", {
  sessions <- availability_window_fixture()
  provider <- list(sessions = sessions$rows)

  # The last session closes at 21:00 on the end date and must be a pulse.
  full <- ledgr_availability_calendar(
    provider,
    "2020-01-13T21:00:00Z",
    "2020-01-17T21:00:00Z"
  )
  testthat::expect_length(full$pulses, 5L)
  testthat::expect_equal(
    max(full$pulses),
    as.POSIXct("2020-01-17 21:00:00", tz = "UTC")
  )

  # An intraday start bound after a session's close excludes that session.
  early <- availability_window_fixture(
    session_open = "09:30:00",
    session_close = "14:00:00"
  )
  trimmed <- ledgr_availability_calendar(
    list(sessions = early$rows),
    "2020-01-13T21:00:00Z",
    "2020-01-17T21:00:00Z"
  )
  testthat::expect_length(trimmed$pulses, 4L)
  testthat::expect_equal(
    min(trimmed$pulses),
    as.POSIXct("2020-01-14 14:00:00", tz = "UTC")
  )
})

testthat::test_that("a target on the last decision fills at the final session open", {
  sessions <- availability_window_fixture()
  open_dates <- as.Date(c("2020-01-13", "2020-01-14", "2020-01-15", "2020-01-16", "2020-01-17"))
  bars <- data.frame(
    ts_utc = open_dates,
    instrument_id = "BBB",
    open = c(50, 51, 52, 53, 59),
    high = c(51, 52, 53, 54, 60),
    low = c(49, 50, 51, 52, 58),
    close = c(50, 51, 52, 53, 59),
    volume = 1000,
    stringsAsFactors = FALSE
  )
  membership <- ledgr_facts_membership_snapshots(
    data.frame(
      effective_from = as.POSIXct("2020-01-13", tz = "UTC"),
      knowledge_time = as.POSIXct("2020-01-01", tz = "UTC"),
      instrument_id = "BBB",
      source = "synthetic",
      stringsAsFactors = FALSE
    ),
    universe_id = "demo",
    complete = TRUE
  )
  snapshot <- ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = "BBB"),
    facts = ledgr_facts(sessions, membership)
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  # Buy on 16 Jan, the last session that still has a next open to fill against.
  strategy <- function(ctx, params) {
    target <- ctx$hold()
    if (substr(ctx$ts_utc, 1, 10) == "2020-01-16") target[["BBB"]] <- 10
    target
  }
  bt <- ledgr_run(
    ledgr_experiment(
      snapshot,
      strategy,
      universe = ledgr_universe_members("demo"),
      valuation_policy = ledgr_valuation_stale(2),
      cost_model = ledgr_cost_zero(),
      opening = ledgr_opening(cash = 10000)
    ),
    run_id = "final-session-fill"
  )
  on.exit(close(bt), add = TRUE)

  equity <- ledgr_results(bt, "equity")
  testthat::expect_equal(nrow(equity), 5L)
  testthat::expect_equal(
    max(equity$ts_utc),
    as.POSIXct("2020-01-17 21:00:00", tz = "UTC")
  )

  fills <- ledgr_results(bt, "fills")
  testthat::expect_equal(nrow(fills), 1L)
  # Priced at the 17 Jan open, recorded at the 17 Jan close pulse.
  testthat::expect_equal(fills$price[[1L]], 59)
  testthat::expect_equal(
    fills$ts_utc[[1L]],
    as.POSIXct("2020-01-17 21:00:00", tz = "UTC")
  )
})

testthat::test_that("normalized timestamps are never parsed without an explicit format", {
  sources <- list.files("../../R", pattern = "[.]R$", full.names = TRUE)
  if (length(sources) == 0L) testthat::skip("package sources not available")
  offenders <- character()
  for (path in sources) {
    text <- paste(readLines(path, warn = FALSE), collapse = "\n")
    pattern <- paste0("as", "\\.", "POSIXct", "\\(", "\\s*", "ledgr_normalize_ts_utc", "\\(")
    starts <- gregexpr(pattern, text)[[1L]]
    if (starts[[1L]] == -1L) next
    for (start in starts) {
      window <- substr(text, start, start + 200L)
      if (!grepl("%Y-%m-%dT%H:%M:%SZ", window, fixed = TRUE)) {
        offenders <- c(offenders, basename(path))
      }
    }
  }
  testthat::expect_equal(offenders, character())
})
