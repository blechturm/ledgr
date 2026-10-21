# ledgr-test-file-profile: review

testthat::test_that("[LTB-0407] history results expose their metadata, align solver weights and default the sufficiency lookback", {
  captured <- ws42_capture_run(reader = function(ctx) {
    list(
      fast = ledgr_history_frame(ctx, feature = "fast", lookback = 2L,
        instruments = "decision_axis", na_action = "drop_instruments"),
      fast_long = ledgr_history_frame(ctx, feature = "fast", lookback = 2L,
        instruments = "decision_axis", na_action = "drop_instruments", layout = "long"),
      close_all = ledgr_history_frame(ctx, bar = "close"),
      fast_admissible = ledgr_history_frame(ctx, feature = "fast", lookback = 2L,
        na_action = "drop_instruments")
    )
  })
  on.exit({
    close(captured$bt)
    ledgr_snapshot_close(captured$fixture$snapshot)
  }, add = TRUE)
  axis <- captured$fixture$axis
  at7 <- captured$seen[[ws42_iso(axis[[7L]])]]

  # Session 7: CCC is a known-inactive member on the decision axis. SMA(2) of
  # AAA (10 + k) is 15.5, 16.5 and of BBB (20 + k) 25.5, 26.5 over sessions
  # 6-7; CCC has no calculation in the window and leaves the sample.
  fast <- at7$fast
  info <- ledgr_history_info(fast)
  testthat::expect_s3_class(info, "ledgr_history_info")
  testthat::expect_identical(info$source, "feature:sma_2")
  testthat::expect_identical(info$source_kind, "feature")
  testthat::expect_identical(info$source_id, "sma_2")
  testthat::expect_identical(as.numeric(info$cutoff_utc), as.numeric(axis[[7L]]))
  testthat::expect_identical(as.numeric(info$data_start_utc), as.numeric(axis[[1L]]))
  testthat::expect_identical(as.numeric(info$window_start_utc), as.numeric(axis[[6L]]))
  testthat::expect_identical(info$requested_lookback, 2L)
  testthat::expect_identical(info$available_lookback, 2L)
  testthat::expect_identical(info$instruments, "decision_axis")
  testthat::expect_identical(info$na_action, "drop_instruments")
  testthat::expect_identical(info$layout, "wide")
  testthat::expect_identical(info$included_ids, c("AAA", "BBB"))
  testthat::expect_identical(info$excluded_ids, "CCC")
  testthat::expect_s3_class(info$selection, "tbl_df")
  testthat::expect_identical(info$selection$instrument_id, c("AAA", "BBB", "CCC"))
  testthat::expect_identical(info$selection$included, c(TRUE, TRUE, FALSE))
  testthat::expect_true(nzchar(info$selection$exclusion_reason[[3L]]))
  testthat::expect_identical(info$selection$admissibility_reason[[3L]], "lifetime_inactive")
  testthat::expect_true(is.logical(info$used_before_window) && length(info$used_before_window) == 1L)
  testthat::expect_identical(dim(info$evidence$calculation_valid), c(2L, 2L))
  testthat::expect_identical(info$policy_identity$price_carry, 5L)
  # The accessor returns the recorded metadata, not a second reading.
  meta <- attr(fast, "ledgr_history")
  testthat::expect_identical(info$selection, tibble::as_tibble(meta$selection))
  testthat::expect_identical(info$used_before_window, meta$used_before_window)
  testthat::expect_identical(ledgr_history_info(at7$fast_long)$included_ids, c("AAA", "BBB"))
  testthat::expect_null(ledgr_history_info(at7$fast_long)$evidence)
  info_printed <- utils::capture.output(print(info))
  testthat::expect_true("Excluded:     CCC (" %in% substr(info_printed, 1L, 19L))
  testthat::expect_true("# i Selection table: info$selection" %in% info_printed)

  # The print footer names the accessor.
  testthat::expect_true(
    "# i Selection, exclusions and window: ledgr_history_info(x)" %in% utils::capture.output(print(fast))
  )

  # Like the matrix adapter, the accessor refuses a result that no longer
  # matches its recorded axis and instruments.
  broken <- fast
  broken$BBB <- NULL
  testthat::expect_error(ledgr_history_info(broken), class = "ledgr_invalid_history_result")
  testthat::expect_error(ledgr_history_weights(broken, c(0.5, 0.5)), class = "ledgr_invalid_history_result")
  testthat::expect_error(ledgr_history_info(data.frame(x = 1)), class = "ledgr_invalid_history_result")
  # Sufficiency refuses the same stale results (close review 44a F3): a
  # result whose rows were filtered keeps its class and metadata but no
  # longer matches its recorded two sessions.
  filtered <- fast[2L, , drop = FALSE]
  attr(filtered, "ledgr_history") <- attr(fast, "ledgr_history")
  class(filtered) <- class(fast)
  testthat::expect_error(ledgr_history_sufficient(filtered), class = "ledgr_invalid_history_result")
  testthat::expect_error(ledgr_history_sufficient(broken, lookback = 1L), class = "ledgr_invalid_history_result")
  # The long layout is checked the same way (re-review 1 R3): keeping only
  # AAA's rows leaves a result that no longer holds its recorded instruments.
  long_filtered <- at7$fast_long[at7$fast_long$instrument_id == "AAA", , drop = FALSE]
  attr(long_filtered, "ledgr_history") <- attr(at7$fast_long, "ledgr_history")
  class(long_filtered) <- class(at7$fast_long)
  testthat::expect_error(
    ledgr_history_sufficient(long_filtered, min_instruments = 2L),
    class = "ledgr_invalid_history_result"
  )
  # Under the "admissible" selector CCC is not requested at session 7, so it
  # is not an excluded instrument (close review 44a N2).
  admissible_info <- ledgr_history_info(at7$fast_admissible)
  testthat::expect_identical(admissible_info$included_ids, c("AAA", "BBB"))
  testthat::expect_identical(admissible_info$excluded_ids, character())
  testthat::expect_identical(
    admissible_info$selection$requested[admissible_info$selection$instrument_id == "CCC"],
    FALSE
  )

  # Solver output becomes identified weights without colnames(): an unnamed
  # vector in the matrix column order, a named vector in any order, and a
  # one-column matrix all give AAA = 0.25, BBB = 0.75.
  expected <- ledgr_weights(c(AAA = 0.25, BBB = 0.75), origin = "ledgr_history_weights")
  testthat::expect_identical(colnames(ledgr_history_matrix(fast)), c("AAA", "BBB"))
  testthat::expect_identical(ledgr_history_weights(fast, c(0.25, 0.75)), expected)
  testthat::expect_identical(ledgr_history_weights(fast, c(BBB = 0.75, AAA = 0.25)), expected)
  testthat::expect_identical(ledgr_history_weights(fast, matrix(c(0.25, 0.75), ncol = 1L)), expected)
  testthat::expect_identical(
    ledgr_history_weights(fast, matrix(c(0.25, 0.75), nrow = 1L, dimnames = list(NULL, c("AAA", "BBB")))),
    expected
  )
  testthat::expect_identical(ledgr_history_weights(at7$fast_long, c(0.25, 0.75)), expected)
  for (bad in list(c(0.5, 0.25, 0.25), 1, numeric(), c(AAA = 0.5, CCC = 0.5), c(AAA = 0.5, AAA = 0.5),
                   matrix(1, 2L, 2L), "0.5")) {
    testthat::expect_error(ledgr_history_weights(fast, bad), class = "ledgr_history_weights_mismatch")
  }
  testthat::expect_error(ledgr_history_weights(fast, c(0.5, NA)), class = "ledgr_invalid_strategy_type")
  # Three included instruments at session 6 (CCC's inactivity is not yet
  # known): names in a cyclic order are matched by name, not by a
  # permutation of positions (close review 44a N2).
  fast6 <- captured$seen[[ws42_iso(axis[[6L]])]]$fast
  testthat::expect_identical(ledgr_history_info(fast6)$included_ids, c("AAA", "BBB", "CCC"))
  testthat::expect_identical(
    ledgr_history_weights(fast6, c(BBB = 0.2, CCC = 0.3, AAA = 0.5)),
    ledgr_weights(c(AAA = 0.5, BBB = 0.2, CCC = 0.3), origin = "ledgr_history_weights")
  )

  # Sufficiency defaults to the finite lookback the result was read with and
  # refuses to guess one for a full-lookback read.
  testthat::expect_true(ledgr_history_sufficient(fast))
  testthat::expect_true(ledgr_history_sufficient(fast, min_instruments = 2L))
  testthat::expect_false(ledgr_history_sufficient(fast, min_instruments = 3L))
  testthat::expect_false(ledgr_history_sufficient(fast, lookback = 3L))
  testthat::expect_error(ledgr_history_sufficient(at7$close_all), class = "ledgr_invalid_history_request")
  testthat::expect_true(ledgr_history_sufficient(at7$close_all, lookback = 7L))
  testthat::expect_false(ledgr_history_sufficient(at7$close_all, lookback = 8L))
  at1 <- captured$seen[[ws42_iso(axis[[1L]])]]
  # Session 1 holds one of the two requested sessions.
  testthat::expect_false(ledgr_history_sufficient(at1$fast))

  # A strategy using all three runs at Tier 1 and turns weights into targets.
  # At session 6 CCC's inactivity is not yet known, so it is admissible and
  # its SMA (35, from a carried close) is complete: three instruments are
  # included and each gets 1/3. With AAA at 16, BBB at 26 and cash 1000 the
  # rebalance buys floor(1000 / 3 / 16) = 20 AAA and floor(1000 / 3 / 26) = 12
  # BBB, filled at session 7's open; CCC has no current close, so its share is
  # skipped and not redistributed.
  strategy <- function(ctx, params) {
    if (!identical(ctx$ts_utc, "2021-01-11T21:00:00Z")) return(ctx$hold())
    returns <- ledgr_history_frame(ctx, feature = "fast", lookback = 2L, na_action = "drop_instruments")
    if (!ledgr_history_sufficient(returns, min_instruments = 2L)) return(ctx$hold())
    n <- length(ledgr_history_info(returns)$included_ids)
    ledgr_target_rebalance(ledgr_history_weights(returns, rep(1 / n, n)), ctx, equity_fraction = 1)
  }
  testthat::expect_identical(ledgr_strategy_preflight(strategy)$tier, "tier_1")
  bought <- ws42_history_fixture(strategy = strategy)
  on.exit(ledgr_snapshot_close(bought$snapshot), add = TRUE)
  bt <- ledgr_run(bought$exp, run_id = "bridge-run")
  on.exit(close(bt), add = TRUE)
  fills <- as.data.frame(ledgr_results(bt, "fills"))
  testthat::expect_identical(fills$instrument_id, c("AAA", "BBB"))
  testthat::expect_identical(as.numeric(fills$qty), c(20, 12))
  testthat::expect_identical(as.numeric(fills$price), c(17, 27))
})
