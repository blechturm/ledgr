strict_dispatch_fixture <- function(instruments, days = 5L) {
  dates <- as.Date("2024-01-01") + seq_len(days) - 1L
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00",
      knowledge_time = as.POSIXct(dates, tz = "UTC") - 1,
      stringsAsFactors = FALSE
    ),
    venue_id = "XNYS"
  )
  bars <- do.call(rbind, lapply(seq_along(instruments), function(i) {
    close <- 100 * i + seq_len(days)
    data.frame(
      ts_utc = as.POSIXct(paste(dates, "16:00:00"), tz = "UTC"),
      instrument_id = instruments[[i]],
      open = close - 0.5,
      high = close + 1,
      low = close - 1,
      close = close,
      volume = 1000,
      stringsAsFactors = FALSE
    )
  }))
  ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = instruments),
    facts = ledgr_facts(sessions), price_basis = "split_adjusted"
  )
}

strict_dispatch_experiment <- function(snapshot, instruments) {
  sma_id <- ledgr_feature_id(ledgr_ind_sma(2L))
  returns_id <- ledgr_feature_id(ledgr_ind_returns(2L))
  strategy <- function(ctx, params) {
    sma <- unname(ctx$vec$feature(sma_id))
    returns <- unname(ctx$vec$feature(returns_id))
    list(
      targets = ctx$flat(),
      state_update = if (all(is.finite(c(sma, returns)))) {
        list(sma = sma, returns = returns)
      } else {
        list()
      }
    )
  }
  ledgr_experiment(
    snapshot,
    strategy,
    universe = instruments,
    features = list(ledgr_ind_sma(2L), ledgr_ind_returns(2L)),
    valuation_policy = ledgr_valuation_stale(1L),
    cost_model = ledgr_cost_zero()
  )
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0157] strict dispatch resolves once per definition", {
  original_certify <- ledgr:::ledgr_feature_certify
  calls <- character()
  testthat::local_mocked_bindings(
    ledgr_feature_certify = function(def) {
      certified <- original_certify(def)
      calls <<- c(calls, if (is.null(certified$kind)) "scalar" else certified$kind)
      certified
    },
    .package = "ledgr"
  )

  for (count in c(2L, 4L)) {
    instruments <- sprintf("I%02d", seq_len(count))
    snapshot <- strict_dispatch_fixture(instruments)
    on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
    experiment <- strict_dispatch_experiment(snapshot, instruments)
    calls <- character()
    bt <- ledgr_run(experiment, run_id = paste0("dispatch-", count))
    on.exit(close(bt), add = TRUE)
    testthat::expect_identical(sort(calls), c("returns", "sma"))
    state <- availability_last_state(bt)
    expected_sma <- 100 * seq_len(count) + 4.5
    expected_returns <- 2 / (100 * seq_len(count) + 3)
    testthat::expect_identical(unname(unlist(state$sma)), expected_sma)
    testthat::expect_identical(unname(unlist(state$returns)), expected_returns)
  }

  instruments <- c("I01", "I02")
  snapshot <- strict_dispatch_fixture(instruments)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- strict_dispatch_experiment(snapshot, instruments)
  calls <- character()
  sweep <- ledgr_sweep(
    experiment,
    ledgr_grid_named(a = list(strategy = list()), b = list(strategy = list())),
    stop_on_error = TRUE
  )
  testthat::expect_identical(sort(calls), c("returns", "sma"))
  testthat::expect_identical(sweep$status, c("DONE", "DONE"))
})
