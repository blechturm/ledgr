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
  testthat::expect_null(attr(wide, "ledgr_history")$evidence)
  testthat::expect_true(all(ledgr:::ledgr_history_cell_fields() %in% names(long)))
  testthat::expect_false("matrix_value_sha256" %in%
    names(attr(direct, "ledgr_history")))
  testthat::expect_false(exists(
    "ledgr_history_matrix_value_sha256", envir = asNamespace("ledgr"),
    inherits = FALSE
  ))
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
  for (x in list(changed, math_changed, row_subset, column_subset, replaced)) {
    testthat::expect_error(
      ledgr_history_info(x), class = "ledgr_invalid_history_result"
    )
  }
  # Attribute-preserving base transforms remain ordinary R objects with
  # provenance about the originating read. The metadata is structural, not
  # an authentication seal over the transformed values.
  testthat::expect_identical(
    ledgr_history_info(preserved), ledgr_history_info(direct)
  )
  testthat::expect_identical(
    ledgr_align_weights(rep(1 / 3, 3L), preserved),
    ledgr_weights(c(AAA = 1 / 3, BBB = 1 / 3, CCC = 1 / 3),
      origin = "ledgr_align_weights")
  )
  testthat::expect_false(identical(as.double(preserved), as.double(direct)))
  # Readiness and alignment use the structural provenance and do not rescan
  # or hash transient values.
  testthat::expect_true(ledgr_passed_warmup(preserved))

  local({
    testthat::local_mocked_bindings(
      ledgr_history_bar_evidence = function(...) stop("ordinary bar built evidence"),
      ledgr_history_feature_evidence = function(...) stop("ordinary feature built evidence"),
      .package = "ledgr"
    )
    testthat::expect_silent(ledgr_history_matrix(
      ctx, bar = "close", lookback = 2L, min_observations = 0L
    ))
    testthat::expect_silent(ledgr_history_frame(
      ctx, bar = "close", lookback = 2L, min_observations = 0L
    ))
    testthat::expect_silent(ledgr_history_matrix(
      ctx, feature = "fast", lookback = 2L, min_observations = 0L
    ))
    # Exclusion is still an ordinary compact read: it may not reacquire the
    # diagnostic planes merely to name the exclusion reason.
    testthat::expect_silent(ledgr_history_matrix(
      ctx, bar = "volume", lookback = 3L, min_observations = 3L
    ))
  })

  # The owner prepares immutable mask summaries before the first public read.
  # An excluded read adds no field-position or patch cache.
  owner_fixture <- ws42_history_fixture(
    policy = ledgr_history_policy(price_carry = 1L)
  )
  on.exit(ledgr_snapshot_close(owner_fixture$snapshot), add = TRUE)
  owner_ctx <- ledgr_pulse_snapshot(
    owner_fixture$exp, ts_utc = owner_fixture$axis[[5L]]
  )
  owner_substrate <- ledgr:::ledgr_history_context_view(owner_ctx)$service$substrate
  owner_memo <- ledgr:::ledgr_history_memo(owner_substrate)
  before_memo <- ls(owner_memo, all.names = TRUE)
  testthat::expect_true("base_masks" %in% before_memo)
  expired <- ledgr_history_matrix(
    owner_ctx, bar = "close", lookback = 3L, min_observations = 3L
  )
  after_memo <- ls(owner_memo, all.names = TRUE)
  testthat::expect_identical(after_memo, before_memo)
  testthat::expect_false(any(grepl("base_(open|high|low|close|volume)", after_memo)))
  expired_long <- ledgr_history_frame(
    owner_ctx, bar = "close", lookback = 3L, min_observations = 3L,
    layout = "long"
  )
  expired_info <- ledgr_history_info(expired)
  testthat::expect_identical(
    expired_info$selection$exclusion_reason[
      expired_info$selection$instrument_id == "BBB"
    ],
    "carry_expired"
  )
  testthat::expect_identical(
    ledgr_history_matrix(expired_long), expired
  )

  # The compiled boundary can expose its exact source-value accesses for a
  # structural test without retaining them in an ordinary result. BBB has no
  # sessions 3-4: close carries session 2, while volume reads only 3-5.
  trace_one <- function(field, carry, allowed) {
    rows <- unname(owner_substrate$instrument_index["BBB"])
    columns <- 3:5
    masks <- ledgr:::ledgr_history_bar_mask_view(
      owner_substrate, rows, columns, 5L, carry
    )
    ledgr:::ledgr_history_value_slice(
      owner_substrate$bars[[field]], rows, columns, masks,
      owner_substrate$bar_gap_runs[[field]], carry, allowed, 0L,
      names(owner_substrate$pulse_index)[columns], "BBB",
      trace_access = TRUE
    )$source_access
  }
  # Linear indexes in the 3-row source plane: requested 3,4,5 and, for
  # carried close cells, their session-2 source.
  testthat::expect_identical(trace_one("close", 5L, TRUE), c(8L, 5L, 11L, 5L, 14L))
  testthat::expect_identical(trace_one("volume", 0L, FALSE), c(8L, 11L, 14L))
  compact_source <- readLines(
    testthat::test_path("..", "..", "src", "history_compact.cpp"), warn = FALSE
  )
  start <- grep("SEXP ledgr_cpp_history_bar_compact", compact_source, fixed = TRUE)[[1L]]
  compact_source <- compact_source[start:length(compact_source)]
  testthat::expect_identical(sum(grepl("stored[", compact_source, fixed = TRUE)), 1L)

  local({
    original_slice <- ledgr:::ledgr_history_value_slice
    seen <- list()
    testthat::local_mocked_bindings(
      ledgr_history_value_slice = function(stored, rows, columns, masks, gaps,
                                           max_carry_sessions, carry_allowed,
                                           min_observations,
                                           axis_names, instrument_ids,
                                           manifestation = "matrix",
                                           trace_access = FALSE) {
        seen[[length(seen) + 1L]] <<- list(
          rows = rows, columns = columns,
          dependency_first = masks$dependency_first,
          max_carry_sessions = max_carry_sessions
        )
        original_slice(
          stored, rows, columns, masks, gaps,
          max_carry_sessions, carry_allowed, min_observations,
          axis_names, instrument_ids,
          manifestation = manifestation, trace_access = trace_access
        )
      },
      .package = "ledgr"
    )
    bounded <- ledgr_history_matrix(
      ctx, bar = "close", lookback = 2L, min_observations = 0L
    )
    testthat::expect_length(seen, 1L)
    testthat::expect_identical(seen[[1L]]$columns, 4:5)
    testthat::expect_identical(seen[[1L]]$dependency_first, 1L)
    testthat::expect_identical(seen[[1L]]$max_carry_sessions, 5L)
    testthat::expect_identical(nrow(bounded), 2L)
  })

  local({
    testthat::local_mocked_bindings(
      ledgr_history_matrix_from_plan = function(...) {
        stop("wide frame built a matrix")
      },
      .package = "ledgr"
    )
    sibling <- ledgr_history_frame(
      ctx, bar = "close", lookback = 2L, min_observations = 0L
    )
    testthat::expect_identical(names(sibling), c("ts_utc", "AAA", "BBB", "CCC"))
  })

  memo_names <- ls(ledgr:::ledgr_history_memo(
    ledgr:::ledgr_history_context_view(ctx)$service$substrate
  ))
  testthat::expect_false(any(grepl(
    "finite.*count|count.*finite|_patch_", memo_names
  )))

  isolated <- ledgr_history_matrix(
    ctx, bar = "close", lookback = 2L, min_observations = 0L
  )
  expected_fresh <- as.double(isolated)
  isolated[1L, 1L] <- -999
  fresh <- ledgr_history_matrix(
    ctx, bar = "close", lookback = 2L, min_observations = 0L
  )
  testthat::expect_identical(as.double(fresh), expected_fresh)
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
