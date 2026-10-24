# ledgr-test-file-profile: review

testthat::test_that("[LTB-0488] direct history matrices share one causal read and keep estimator identity", {
  fixture <- ws42_history_fixture()
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  ctx <- ledgr_pulse_snapshot(fixture$exp, ts_utc = fixture$axis[[5L]])

  direct <- ledgr_history_matrix(
    ctx, bar = "close", lookback = Inf, min_observations = 0L
  )
  wide <- ledgr_history_frame(
    ctx, bar = "close", lookback = Inf, min_observations = 0L
  )
  long <- ledgr_history_frame(
    ctx, bar = "close", lookback = Inf, min_observations = 0L,
    layout = "long"
  )
  from_wide <- ledgr_history_matrix(wide)
  from_long <- ledgr_history_matrix(long)
  testthat::expect_identical(direct, from_wide)
  testthat::expect_identical(direct, from_long)

  local({
    original_read <- ledgr:::ledgr_history_read_plan
    calls <- 0L
    testthat::local_mocked_bindings(
      ledgr_history_read_plan = function(...) {
        calls <<- calls + 1L
        original_read(...)
      },
      ledgr_history_plan_frame = function(...) stop("direct matrix built a frame"),
      .package = "ledgr"
    )
    structural <- ledgr_history_matrix(
      ctx, bar = "close", lookback = Inf, min_observations = 0L
    )
    testthat::expect_identical(calls, 1L)
    testthat::expect_identical(structural, direct)
  })
  testthat::expect_s3_class(direct, "ledgr_history_matrix")
  testthat::expect_true(is.matrix(direct) && is.double(direct))
  testthat::expect_null(attr(direct, "ledgr_history")$evidence)
  testthat::expect_false(any(c("frame", "data") %in%
    names(attr(direct, "ledgr_history"))))
  testthat::expect_identical(dim(stats::cov(direct)), c(3L, 3L))
  testthat::expect_identical(
    ledgr_align_weights(rep(1 / 3, 3L), direct),
    ledgr_weights(c(AAA = 1 / 3, BBB = 1 / 3, CCC = 1 / 3),
      origin = "ledgr_align_weights")
  )

  empty_rows <- ledgr_history_matrix(ctx, bar = "close", lookback = 0L)
  empty_cols <- ledgr_history_matrix(
    ctx, bar = "close", lookback = 2L, instruments = character()
  )
  testthat::expect_identical(dim(empty_rows), c(0L, 3L))
  testthat::expect_identical(dim(empty_cols), c(2L, 0L))
  testthat::expect_identical(ledgr_history_info(empty_rows)$included_ids,
                             c("AAA", "BBB", "CCC"))
  testthat::expect_identical(ledgr_history_info(empty_cols)$included_ids,
                             character())
  testthat::expect_true(ledgr_passed_warmup(empty_rows))
  testthat::expect_false(ledgr_passed_warmup(empty_cols))
  testthat::expect_identical(
    ledgr_history_matrix(ledgr_history_frame(
      ctx, bar = "close", lookback = 0L, layout = "long"
    )),
    empty_rows
  )

  changed <- direct + 0
  math_changed <- abs(direct)
  row_subset <- direct[1:2, , drop = FALSE]
  column_subset <- direct[, 1:2, drop = FALSE]
  preserved <- pmax(direct, max(direct, na.rm = TRUE) + 1)
  replaced <- direct
  replaced[1L, 1L] <- replaced[1L, 1L]
  for (x in list(changed, math_changed, row_subset, column_subset, replaced, preserved)) {
    testthat::expect_error(
      ledgr_history_info(x), class = "ledgr_invalid_history_result"
    )
  }
  testthat::expect_error(
    ledgr_align_weights(rep(1 / 3, 3L), preserved),
    class = "ledgr_invalid_history_result"
  )
  # Readiness is deliberately read from the recorded requirement result and
  # does not rescan matrix cells; value-consuming helpers enforce the seal.
  testthat::expect_true(ledgr_passed_warmup(preserved))
})

testthat::test_that("[LTB-0489] history requirements count treated finite values and drive one readiness predicate", {
  values <- rbind(
    complete = c(1, 2, 3),
    input_carry = c(1, 1, 3),
    output_carry = c(1, 1, 3),
    non_finite = c(1, Inf, 3),
    missing = c(1, NA, 3)
  )
  input <- matrix(FALSE, nrow = 5L, ncol = 3L)
  input[2L, 2L] <- TRUE
  output <- matrix(FALSE, nrow = 5L, ncol = 3L)
  output[3L, 2L] <- TRUE
  admission <- ledgr:::ledgr_history_estimator_admission(
    list(
      value = values,
      calculation_valid = is.finite(values) & !output,
      input_carried = input,
      output_carried = output,
      missing_reason = matrix("", 5L, 3L),
      barrier_reason = matrix("", 5L, 3L)
    ),
    min_observations = 3L
  )
  testthat::expect_identical(
    admission$finite_observation_count, c(3L, 3L, 3L, 2L, 2L)
  )
  testthat::expect_identical(
    unname(admission$included), c(TRUE, TRUE, TRUE, FALSE, FALSE)
  )

  fixture <- ws42_history_fixture(
    features = ledgr_feature_map(fast = ledgr_ind_returns(1L))
  )
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  ctx <- ledgr_pulse_snapshot(fixture$exp, ts_utc = fixture$axis[[5L]])
  strict <- ledgr_history_matrix(
    ctx, feature = "fast", lookback = 2L, instruments = "decision_axis",
    min_instruments = 3L
  )
  partial <- ledgr_history_matrix(
    ctx, feature = "fast", lookback = 2L, instruments = "decision_axis",
    min_observations = 1L, min_instruments = 2L
  )
  zero <- ledgr_history_matrix(
    ctx, feature = "fast", lookback = 2L, instruments = "decision_axis",
    min_observations = 0L, min_instruments = 3L
  )
  testthat::expect_identical(ledgr_history_info(strict)$included_ids, c("AAA", "CCC"))
  testthat::expect_false(ledgr_passed_warmup(strict))
  testthat::expect_true(ledgr_passed_warmup(partial))
  testthat::expect_true(ledgr_passed_warmup(zero))
  testthat::expect_true(anyNA(zero))
  testthat::expect_error(
    ledgr_history_matrix(ctx, feature = "fast", lookback = 2L,
      min_observations = 3L),
    class = "ledgr_invalid_history_request"
  )
  testthat::expect_error(
    ledgr_history_matrix(ctx, feature = "fast"),
    class = "ledgr_invalid_history_request"
  )
  testthat::expect_error(
    ledgr_history_frame(ctx, feature = "fast"),
    class = "ledgr_invalid_history_request"
  )

  testthat::expect_false("ledgr_history_sufficient" %in% getNamespaceExports("ledgr"))
  testthat::expect_false("na_action" %in% names(formals(ledgr_history_frame)))
  body <- paste(deparse(body(ledgr_passed_warmup)), collapse = "\n")
  testthat::expect_match(body, "meta\\$passed_warmup")
})
