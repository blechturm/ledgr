# ledgr-test-file-profile: review
testthat::test_that("[LTB-0554] logical diagnostics own every production read", {
  bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
    instrument_id = "AAA",
    open = 10:13,
    high = 11:14,
    low = 9:12,
    close = 10:13,
    volume = 1000
  )
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  strategy <- function(ctx, params) {
    calls$n <- calls$n + 1L
    if (ctx$ts_utc == "2020-01-01T00:00:00Z") c(AAA = 1) else ctx$hold()
  }
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  bt <- ledgr_run(
    ledgr_experiment(
      snapshot,
      strategy,
      opening = ledgr_opening(cash = 1000),
      cost_model = ledgr_cost_zero()
    ),
    run_id = "decoder-boundary"
  )
  on.exit(close(bt), add = TRUE)
  testthat::local_mocked_bindings(
    ledgr_diagnostic_clean_fill = function(decision, risk, fill, fill_reason) {
      rep(FALSE, length(fill$k))
    },
    ledgr_diagnostic_clean_hold = function(decision, risk, excluded_k = integer()) {
      rep(FALSE, decision$n)
    },
    .package = "ledgr"
  )
  bt_explicit <- ledgr_run(
    ledgr_experiment(
      snapshot,
      strategy,
      opening = ledgr_opening(cash = 1000),
      cost_model = ledgr_cost_zero()
    ),
    run_id = "decoder-all-explicit"
  )
  on.exit(close(bt_explicit), add = TRUE)
  calls_after_run <- calls$n

  opened <- ledgr:::ledgr_backtest_read_connection(bt)
  on.exit(opened$close(), add = TRUE)
  physical <- DBI::dbGetQuery(
    opened$con,
    "SELECT * FROM run_diagnostics WHERE run_id = ? ORDER BY diagnostic_seq",
    params = list(bt_explicit$run_id)
  )
  absent <- physical$stage == "sizing" & !nzchar(physical$reasons)
  physical$reasons[absent] <- NA_character_
  decoded <- ledgr:::ledgr_diagnostic_decode(opened$con, bt$run_id)
  physical$run_id <- bt$run_id
  testthat::expect_identical(as.data.frame(decoded), physical)
  compact <- DBI::dbGetQuery(
    opened$con,
    "SELECT * FROM run_diagnostic_implicit WHERE run_id = ? ORDER BY decision_seq",
    params = list(bt$run_id)
  )
  testthat::expect_gt(nrow(compact), 0L)
  testthat::expect_lt(
    DBI::dbGetQuery(opened$con,
      "SELECT COUNT(*) AS n FROM run_diagnostics WHERE run_id = ?",
      params = list(bt$run_id))$n[[1L]],
    nrow(decoded)
  )
  sizing <- ledgr:::ledgr_run_sizing_summary(bt, con = opened$con)
  testthat::expect_false(sizing$available)
  testthat::expect_true(sizing$raw_intent_unavailable)
  testthat::expect_identical(sizing$unavailable_decisions, 4L)
  compact_flags <- ledgr:::ledgr_diagnostic_flag_counts(opened$con, bt$run_id)
  testthat::expect_identical(compact_flags$decisions[[1L]],
                             as.integer(sum(decoded$stage == "decision")))
  testthat::expect_no_error(testthat::with_mocked_bindings(
    ledgr:::ledgr_diagnostic_summary_from_store(opened$con, bt$run_id),
    ledgr_diagnostic_decode = function(...) {
      stop("terminal summary materialized the full logical trace")
    },
    .package = "ledgr"
  ))
  # Store-wide summaries consume the persisted, hashed summary rather than
  # re-decoding or re-validating a trace whose size grows with the run.
  testthat::expect_no_error(testthat::with_mocked_bindings(
    {
      ledgr:::ledgr_diagnostic_flag_counts(opened$con, bt$run_id)
      ledgr:::ledgr_run_sizing_summary(bt, con = opened$con)
      ledgr:::ledgr_run_completion_info_many(opened$con, bt$run_id)
    },
    ledgr_diagnostic_require_coverage = function(...) {
      stop("store-wide summary revalidated the logical trace")
    },
    ledgr_diagnostic_decode = function(...) {
      stop("store-wide summary decoded the logical trace")
    },
    .package = "ledgr"
  ))

  # Sweep folds use a memory sink. They must not allocate the durable
  # implicit-row buffer at construction.
  memory_handler <- ledgr:::ledgr_output_handler(
    ledgr:::ledgr_output_sink_memory("no-implicit-buffer")
  )
  testthat::expect_no_error(testthat::with_mocked_bindings(
    ledgr:::ledgr_columnar_diagnostic_writer(
      run_id = "no-implicit-buffer",
      output_handler = memory_handler
    ),
    ledgr_diagnostic_implicit_columns = function(...) {
      stop("memory sink allocated a durable implicit buffer")
    },
    .package = "ledgr"
  ))

  first_decision <- decoded$ts_utc[decoded$stage == "decision"][[1L]]
  coverage_call <- new.env(parent = emptyenv())
  original_coverage <- ledgr:::ledgr_diagnostic_require_coverage
  bounded <- testthat::with_mocked_bindings(
    ledgr:::ledgr_diagnostic_decode(
      opened$con,
      bt$run_id,
      instrument_id = "AAA",
      explain_ts_utc = first_decision
    ),
    ledgr_diagnostic_require_coverage = function(
      con, run_ids, instrument_id = NULL, explain_ts_utc = NULL
    ) {
      coverage_call$instrument_id <- instrument_id
      coverage_call$explain_ts_utc <- explain_ts_utc
      original_coverage(
        con, run_ids,
        instrument_id = instrument_id,
        explain_ts_utc = explain_ts_utc
      )
    },
    .package = "ledgr"
  )
  # The reader query remains bounded, while integrity validation is one full
  # stored-state check shared by this handle. A filtered first check could not
  # authorize the later full diagnostic read from the same cache entry.
  testthat::expect_null(coverage_call$instrument_id)
  testthat::expect_null(coverage_call$explain_ts_utc)
  expected <- decoded[
    decoded$instrument_id == "AAA" &
      ((decoded$stage == "decision" & decoded$ts_utc == first_decision) |
         (decoded$stage == "execution" & decoded$decision_ts_utc == first_decision)),
    ,
    drop = FALSE
  ]
  testthat::expect_identical(bounded, expected)
  testthat::expect_identical(calls$n, calls_after_run)

  # Stored summaries are derived evidence, not a second authority: missing
  # or mutated rows refuse even while the logical trace remains intact.
  summary_row <- DBI::dbGetQuery(
    opened$con,
    "SELECT * FROM run_diagnostic_summary WHERE run_id = ?",
    params = list(bt$run_id)
  )
  DBI::dbExecute(
    opened$con,
    "UPDATE run_diagnostic_summary SET decisions = decisions + 1 WHERE run_id = ?",
    params = list(bt$run_id)
  )
  testthat::expect_error(
    ledgr:::ledgr_diagnostic_flag_counts(opened$con, bt$run_id),
    class = "ledgr_diagnostic_corrupt"
  )
  testthat::expect_error(
    ledgr:::ledgr_run_sizing_summary(bt, con = opened$con),
    class = "ledgr_diagnostic_corrupt"
  )
  DBI::dbExecute(
    opened$con,
    "DELETE FROM run_diagnostic_summary WHERE run_id = ?",
    params = list(bt$run_id)
  )
  testthat::expect_error(
    ledgr:::ledgr_diagnostic_flag_counts(opened$con, bt$run_id),
    class = "ledgr_diagnostic_corrupt"
  )
  ledgr:::ledgr_store_append(opened$con, "run_diagnostic_summary", summary_row)

  # Coverage and association evidence fail closed. A value mutation breaks
  # the exact clean-pair relation; deleting a pair leaves sequence holes.
  first <- compact[1L, , drop = FALSE]
  DBI::dbExecute(
    opened$con,
    "UPDATE run_diagnostic_implicit SET target = target + 1 WHERE run_id = ? AND decision_seq = ?",
    params = list(bt$run_id, first$decision_seq[[1L]])
  )
  testthat::expect_error(
    ledgr:::ledgr_diagnostic_decode(opened$con, bt$run_id),
    class = "ledgr_diagnostic_corrupt"
  )
  DBI::dbExecute(
    opened$con,
    "UPDATE run_diagnostic_implicit SET target = ? WHERE run_id = ? AND decision_seq = ?",
    params = list(first$target[[1L]], bt$run_id, first$decision_seq[[1L]])
  )
  DBI::dbExecute(
    opened$con,
    "DELETE FROM run_diagnostic_implicit WHERE run_id = ? AND decision_seq = ?",
    params = list(bt$run_id, first$decision_seq[[1L]])
  )
  testthat::expect_error(
    ledgr:::ledgr_diagnostic_decode(opened$con, bt$run_id),
    class = "ledgr_diagnostic_corrupt"
  )
  ledgr:::ledgr_store_append(opened$con, "run_diagnostic_implicit", first)

  r_files <- list.files(
    testthat::test_path("..", "..", "R"),
    pattern = "[.]R$",
    full.names = TRUE
  )
  hits <- vapply(r_files, function(path) {
    any(grepl("run_diagnostics", readLines(path, warn = FALSE), fixed = TRUE))
  }, logical(1))
  readers <- sort(basename(r_files[hits]), method = "radix")
  testthat::expect_identical(
    readers,
    sort(c(
      "availability-diagnostic-writer.R", "availability-results.R",
      "db-schema-current.R",
      "diagnostic-codec.R", "diagnostic-decoder.R",
      "fold-engine.R", "output-handler.R",
      "run-resume.R"
    ), method = "radix")
  )
})

testthat::test_that("[LTB-0556] implicit certification is exact and missing-safe", {
  decision <- ledgr:::ledgr_fold_diagnostic_segment(list(
    n = 1L,
    instrument_id = "AAA",
    stage = "decision",
    outcome = "recorded",
    reason_code = "decision_recorded",
    reasons = "decision_recorded",
    target = 1,
    quantity = 0,
    price = 10,
    mark_source = "current_close",
    mark_age = 0L,
    target_before_risk = 1,
    target_after_risk = 1,
    position_before = 0,
    position_after = 0
  ), as.POSIXct("2020-01-01", tz = "UTC"))
  fill <- list(
    k = 1L, position_before = 0, planned_position_after = 1,
    qty = 1, price = 11, exec_ts = as.numeric(as.POSIXct("2020-01-02", tz = "UTC"))
  )
  reason <- list(reason = "", reasons = "")
  testthat::expect_true(ledgr:::ledgr_diagnostic_clean_fill(decision, NULL, fill, reason))
  changed <- decision
  changed$target_after_risk <- 1 + 1e-12
  testthat::expect_false(ledgr:::ledgr_diagnostic_clean_fill(changed, NULL, fill, reason))
  missing <- decision
  missing$target_after_risk <- NA_real_
  clean <- ledgr:::ledgr_diagnostic_clean_fill(missing, NULL, fill, reason)
  clean[is.na(clean)] <- FALSE
  testthat::expect_false(clean)

  bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2,
    instrument_id = "AAA",
    open = c(10, 999, 12),
    high = c(11, 1000, 13),
    low = c(9, 998, 11),
    close = c(10, 999, 12),
    volume = 1000
  )
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  order_witness <- new.env(parent = emptyenv())
  order_witness$p2 <- FALSE
  order_witness$certified <- 0L
  order_witness$expanded <- 0L
  original_clean_hold <- ledgr:::ledgr_diagnostic_clean_hold
  original_add_residual <- ledgr:::ledgr_fold_staging_add_residual
  testthat::local_mocked_bindings(
    ledgr_diagnostic_clean_hold = function(...) {
      testthat::expect_true(order_witness$p2)
      order_witness$certified <- order_witness$certified + 1L
      original_clean_hold(...)
    },
    ledgr_fold_staging_add_residual = function(...) {
      testthat::expect_gt(order_witness$certified, 0L)
      order_witness$expanded <- order_witness$expanded + 1L
      original_add_residual(...)
    },
    .package = "ledgr"
  )
  bt <- ledgr_run(ledgr_experiment(
    snapshot,
    function(ctx, params) {
      # P2 sees the current pulse, never the distinctive next-bar outcome.
      if (identical(ctx$ts_utc, "2020-01-01T00:00:00Z")) {
        testthat::expect_identical(unname(ctx$close), 10)
      }
      order_witness$p2 <- TRUE
      ctx$hold()
    },
    opening = ledgr_opening(cash = 1000),
    cost_model = ledgr_cost_zero()
  ), run_id = "certify-before-expand")
  on.exit(close(bt), add = TRUE)
  testthat::expect_gt(order_witness$certified, 0L)
  testthat::expect_gt(order_witness$expanded, 0L)
})

testthat::test_that("[LTB-0557] registered nonterminal runs publish empty evidence", {
  bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2,
    instrument_id = "AAA",
    open = 10:12,
    high = 11:13,
    low = 9:11,
    close = 10:12,
    volume = 1000
  )
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  bt <- ledgr_run(ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$hold(),
    opening = ledgr_opening(cash = 1000),
    cost_model = ledgr_cost_zero()
  ), run_id = "empty-evidence-birth")
  on.exit(close(bt), add = TRUE)
  opened <- ledgr:::ledgr_backtest_read_connection(bt)
  on.exit(opened$close(), add = TRUE)

  stored <- DBI::dbGetQuery(
    opened$con,
    "SELECT config_json, snapshot_id FROM runs WHERE run_id = ?",
    params = list(bt$run_id)
  )
  cfg <- ledgr:::ledgr_json_read_config(stored$config_json[[1L]])

  # Registration itself owns the CREATED evidence. Calling the initializer
  # here would let a missing production call pass this detector.
  created_id <- "empty-evidence-created"
  ledgr:::ledgr_run_registration(
    con = opened$con,
    cfg = cfg,
    run_id = created_id,
    seed = cfg$engine$seed,
    snapshot_id = stored$snapshot_id[[1L]],
    metric_context = ledgr_metric_context()
  )

  # Restart itself owns the replacement RUNNING evidence. The completed run
  # supplies a real registered identity; restart atomically deletes its prior
  # attempt and publishes the empty logical trace before status is exposed.
  ledgr:::ledgr_run_restart_nonterminal(
    con = opened$con,
    run_id = bt$run_id,
    is_restart = TRUE,
    start_ts_utc = bars$ts_utc[[1L]],
    opening_positions = numeric(),
    opening_cost_basis = numeric()
  )
  DBI::dbExecute(
    opened$con,
    "UPDATE runs SET status = 'RUNNING', error_msg = NULL WHERE run_id = ?",
    params = list(bt$run_id)
  )

  cases <- c(CREATED = created_id, RUNNING = bt$run_id)
  for (status in names(cases)) {
    run_id <- unname(cases[[status]])
    listed <- ledgr_run_list(snapshot)
    testthat::expect_identical(listed$status[listed$run_id == run_id], status)
    info <- ledgr_run_info(snapshot, run_id)
    testthat::expect_identical(info$status, status)
    testthat::expect_true(is.na(
      listed$valuation_state[listed$run_id == run_id]
    ))
  }
})

testthat::test_that("[LTB-0558] in-pulse implicit sequence order is exact", {
  axis <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3
  bars <- expand.grid(
    ts_utc = axis,
    instrument_id = c("AAA", "BBB"),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  bars <- bars[order(bars$ts_utc, bars$instrument_id), , drop = FALSE]
  bars$open <- bars$high <- bars$low <- bars$close <- 10
  bars$volume <- 1000
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  first <- format(axis[[1L]], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  bt <- ledgr_run(ledgr_experiment(
    snapshot,
    function(ctx, params) {
      if (identical(ctx$ts_utc, first)) c(AAA = 1, BBB = 1) else ctx$hold()
    },
    opening = ledgr_opening(cash = 1000),
    cost_model = ledgr_cost_zero()
  ), run_id = "implicit-sequence-order")
  on.exit(close(bt), add = TRUE)
  opened <- ledgr:::ledgr_backtest_read_connection(bt)
  on.exit(opened$close(), add = TRUE)
  rows <- DBI::dbGetQuery(
    opened$con,
    paste(
      "SELECT * FROM run_diagnostic_implicit WHERE run_id = ?",
      "ORDER BY ts_utc, instrument_id"
    ),
    params = list(bt$run_id)
  )
  group <- rows[rows$ts_utc == rows$ts_utc[[1L]], , drop = FALSE]
  testthat::expect_gte(nrow(group), 2L)
  one <- group[1L, ]
  two <- group[2L, ]
  testthat::expect_silent(ledgr:::ledgr_diagnostic_decode(opened$con, bt$run_id))

  # Each half of the order token has an authority outside the token itself.
  # Mutate them independently before the coordinated-rewrite cases below.
  axis_size <- 2L
  context_half <- function(value) ((value - 1) %/% axis_size) + 1
  axis_half <- function(value) ((value - 1) %% axis_size) + 1
  one_context_bad <- (context_half(two$decision_order) - 1L) * axis_size +
    axis_half(one$decision_order)
  two_context_bad <- (context_half(one$decision_order) - 1L) * axis_size +
    axis_half(two$decision_order)
  DBI::dbExecute(
    opened$con,
    paste(
      "UPDATE run_diagnostic_implicit SET decision_seq = -1, decision_order = -1",
      "WHERE run_id = ? AND decision_seq = ?"
    ),
    params = list(bt$run_id, one$decision_seq)
  )
  DBI::dbExecute(
    opened$con,
    paste(
      "UPDATE run_diagnostic_implicit SET decision_seq = ?, decision_order = ?",
      "WHERE run_id = ? AND decision_seq = ?"
    ),
    params = list(
      one$decision_seq, two_context_bad, bt$run_id, two$decision_seq
    )
  )
  DBI::dbExecute(
    opened$con,
    paste(
      "UPDATE run_diagnostic_implicit SET decision_seq = ?, decision_order = ?",
      "WHERE run_id = ? AND decision_seq = -1"
    ),
    params = list(two$decision_seq, one_context_bad, bt$run_id)
  )
  testthat::expect_error(
    ledgr:::ledgr_diagnostic_decode(opened$con, bt$run_id),
    "decision-order evidence is corrupt for run `implicit-sequence-order`",
    class = "ledgr_diagnostic_corrupt"
  )
  DBI::dbExecute(
    opened$con,
    paste(
      "UPDATE run_diagnostic_implicit SET decision_seq = -1, decision_order = -1",
      "WHERE run_id = ? AND decision_seq = ?"
    ),
    params = list(bt$run_id, two$decision_seq)
  )
  DBI::dbExecute(
    opened$con,
    paste(
      "UPDATE run_diagnostic_implicit SET decision_seq = ?, decision_order = ?",
      "WHERE run_id = ? AND decision_seq = ?"
    ),
    params = list(
      two$decision_seq, two$decision_order, bt$run_id, one$decision_seq
    )
  )
  DBI::dbExecute(
    opened$con,
    paste(
      "UPDATE run_diagnostic_implicit SET decision_seq = ?, decision_order = ?",
      "WHERE run_id = ? AND decision_seq = -1"
    ),
    params = list(one$decision_seq, one$decision_order, bt$run_id)
  )

  other_axis <- if (axis_half(one$decision_order) == 1L) 2L else 1L
  axis_bad <- (context_half(one$decision_order) - 1L) * axis_size + other_axis
  DBI::dbExecute(
    opened$con,
    paste(
      "UPDATE run_diagnostic_implicit SET decision_order = ?",
      "WHERE run_id = ? AND decision_seq = ?"
    ),
    params = list(axis_bad, bt$run_id, one$decision_seq)
  )
  testthat::expect_error(
    ledgr:::ledgr_diagnostic_decode(opened$con, bt$run_id),
    "decision-order evidence is corrupt for run `implicit-sequence-order`",
    class = "ledgr_diagnostic_corrupt"
  )
  DBI::dbExecute(
    opened$con,
    paste(
      "UPDATE run_diagnostic_implicit SET decision_order = ?",
      "WHERE run_id = ? AND decision_seq = ?"
    ),
    params = list(one$decision_order, bt$run_id, one$decision_seq)
  )
  testthat::expect_silent(ledgr:::ledgr_diagnostic_decode(opened$con, bt$run_id))

  second <- ledgr_run(ledgr_experiment(
    snapshot,
    function(ctx, params) {
      if (identical(ctx$ts_utc, first)) c(AAA = 1, BBB = 1) else ctx$hold()
    },
    opening = ledgr_opening(cash = 1000),
    cost_model = ledgr_cost_zero()
  ), run_id = "implicit-sequence-order-second")
  on.exit(close(second), add = TRUE)
  second_rows <- DBI::dbGetQuery(
    opened$con,
    "SELECT * FROM run_diagnostic_implicit WHERE run_id = ? ORDER BY decision_seq",
    params = list(second$run_id)
  )
  DBI::dbExecute(
    opened$con,
    "UPDATE run_diagnostic_implicit SET fill_price = fill_price + 1 WHERE run_id = ? AND decision_seq = ?",
    params = list(second$run_id, second_rows$decision_seq[[1L]])
  )
  testthat::expect_error(
    ledgr:::ledgr_diagnostic_decode(opened$con, c(bt$run_id, second$run_id)),
    "association evidence is corrupt for run `implicit-sequence-order-second`",
    class = "ledgr_diagnostic_corrupt"
  )
  DBI::dbExecute(
    opened$con,
    "UPDATE run_diagnostic_implicit SET fill_price = fill_price - 1 WHERE run_id = ? AND decision_seq = ?",
    params = list(second$run_id, second_rows$decision_seq[[1L]])
  )

  second_one <- second_rows[1L, ]
  second_two <- second_rows[2L, ]
  DBI::dbExecute(
    opened$con,
    "UPDATE run_diagnostic_implicit SET decision_seq = -1 WHERE run_id = ? AND decision_seq = ?",
    params = list(second$run_id, second_one$decision_seq)
  )
  DBI::dbExecute(
    opened$con,
    "UPDATE run_diagnostic_implicit SET decision_seq = ? WHERE run_id = ? AND decision_seq = ?",
    params = list(second_one$decision_seq, second$run_id, second_two$decision_seq)
  )
  DBI::dbExecute(
    opened$con,
    "UPDATE run_diagnostic_implicit SET decision_seq = ? WHERE run_id = ? AND decision_seq = -1",
    params = list(second_two$decision_seq, second$run_id)
  )
  testthat::expect_error(
    ledgr:::ledgr_diagnostic_decode(opened$con, c(bt$run_id, second$run_id)),
    "sequence evidence is corrupt for run `implicit-sequence-order-second`",
    class = "ledgr_diagnostic_corrupt"
  )

  testthat::expect_error(
    DBI::dbExecute(
      opened$con,
      "UPDATE run_diagnostic_implicit SET decision_seq = ? WHERE run_id = ? AND decision_seq = ?",
      params = list(one$decision_seq, bt$run_id, two$decision_seq)
    )
  )
  DBI::dbExecute(
    opened$con,
    "UPDATE run_diagnostic_implicit SET decision_seq = -1 WHERE run_id = ? AND decision_seq = ?",
    params = list(bt$run_id, one$decision_seq)
  )
  DBI::dbExecute(
    opened$con,
    "UPDATE run_diagnostic_implicit SET decision_seq = ? WHERE run_id = ? AND decision_seq = ?",
    params = list(one$decision_seq, bt$run_id, two$decision_seq)
  )
  DBI::dbExecute(
    opened$con,
    "UPDATE run_diagnostic_implicit SET decision_seq = ? WHERE run_id = ? AND decision_seq = -1",
    params = list(two$decision_seq, bt$run_id)
  )
  testthat::expect_error(
    ledgr:::ledgr_diagnostic_decode(opened$con, bt$run_id),
    class = "ledgr_diagnostic_corrupt"
  )

  # Restore the diagnostic sequence, then coordinate a rewrite of both the
  # sequence and its stored ordinal. The ordinal is anchored independently to
  # the immutable run axis, so the coordinated rewrite must still refuse.
  DBI::dbExecute(
    opened$con,
    "UPDATE run_diagnostic_implicit SET decision_seq = -1 WHERE run_id = ? AND decision_seq = ?",
    params = list(bt$run_id, two$decision_seq)
  )
  DBI::dbExecute(
    opened$con,
    "UPDATE run_diagnostic_implicit SET decision_seq = ? WHERE run_id = ? AND decision_seq = ?",
    params = list(two$decision_seq, bt$run_id, one$decision_seq)
  )
  DBI::dbExecute(
    opened$con,
    "UPDATE run_diagnostic_implicit SET decision_seq = ? WHERE run_id = ? AND decision_seq = -1",
    params = list(one$decision_seq, bt$run_id)
  )
  testthat::expect_silent(ledgr:::ledgr_diagnostic_decode(opened$con, bt$run_id))

  DBI::dbExecute(
    opened$con,
    paste(
      "UPDATE run_diagnostic_implicit SET decision_seq = -1, decision_order = -1",
      "WHERE run_id = ? AND decision_seq = ?"
    ),
    params = list(bt$run_id, one$decision_seq)
  )
  DBI::dbExecute(
    opened$con,
    paste(
      "UPDATE run_diagnostic_implicit SET decision_seq = ?, decision_order = ?",
      "WHERE run_id = ? AND decision_seq = ?"
    ),
    params = list(one$decision_seq, one$decision_order, bt$run_id, two$decision_seq)
  )
  DBI::dbExecute(
    opened$con,
    paste(
      "UPDATE run_diagnostic_implicit SET decision_seq = ?, decision_order = ?",
      "WHERE run_id = ? AND decision_seq = -1"
    ),
    params = list(two$decision_seq, two$decision_order, bt$run_id)
  )
  testthat::expect_error(
    ledgr:::ledgr_diagnostic_decode(opened$con, bt$run_id),
    "decision-order evidence is corrupt for run `implicit-sequence-order`",
    class = "ledgr_diagnostic_corrupt"
  )

  # The validator is a bounded SQL query, not an R reconstruction of the
  # implicit plane. Its result boundary is one offending run at most.
  validator_source <- paste(deparse(ledgr:::ledgr_diagnostic_decision_order_bad),
                            collapse = "\n")
  testthat::expect_match(validator_source, "duckdb_register")
  testthat::expect_match(validator_source, "duckdb_unregister")
  testthat::expect_match(validator_source, "snapshot_membership_sets")
  testthat::expect_match(validator_source, "ASOF LEFT JOIN member_states")
  testthat::expect_match(validator_source, "ledgr_diagnostic_with_bounded_memory")
  testthat::expect_match(validator_source, "LIMIT 1")
  testthat::expect_false(grepl(
    "SELECT member_rank FROM member_states",
    validator_source,
    fixed = TRUE
  ))
  testthat::expect_false(grepl("format(", validator_source, fixed = TRUE))
  testthat::expect_false(grepl("order(", validator_source, fixed = TRUE))
})

testthat::test_that("[LTB-0560] dynamic context order has an independent anchor", {
  dates <- as.Date("2020-01-01") + 0:2
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
  membership <- ledgr_facts_membership_snapshots(
    data.frame(
      instrument_id = "BBB",
      effective_from = as.POSIXct(dates[[1L]], tz = "UTC"),
      knowledge_time = as.POSIXct(dates[[1L]], tz = "UTC") - 1,
      set_id = "complete_set",
      stringsAsFactors = FALSE
    ),
    universe_id = "dynamic-order",
    complete = TRUE
  )
  bars <- expand.grid(
    ts_utc = as.POSIXct(paste(dates, "16:00:00"), tz = "UTC"),
    instrument_id = c("AAA", "BBB"),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  bars$open <- bars$high <- bars$low <- bars$close <- 10
  bars$volume <- 1000
  snapshot <- ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
    facts = ledgr_facts(sessions, membership),
    price_basis = "split_adjusted"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$hold(),
    universe = ledgr_universe_members("dynamic-order"),
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = 1),
      cost_basis = c(AAA = 10)
    ),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(experiment, run_id = "dynamic-context-order")
  on.exit(close(bt), add = TRUE)
  opened <- ledgr:::ledgr_backtest_read_connection(bt)
  on.exit(opened$close(), add = TRUE)
  rows <- DBI::dbGetQuery(
    opened$con,
    paste(
      "SELECT decision_seq, decision_order, instrument_id, ts_utc",
      "FROM run_diagnostic_implicit WHERE run_id = ?",
      "ORDER BY ts_utc, decision_seq"
    ),
    params = list(bt$run_id)
  )
  pulse <- rows[rows$ts_utc == rows$ts_utc[[1L]], , drop = FALSE]
  testthat::expect_identical(pulse$instrument_id, c("BBB", "AAA"))
  testthat::expect_silent(
    ledgr:::ledgr_diagnostic_decode(opened$con, bt$run_id)
  )

  first <- pulse[1L, ]
  second <- pulse[2L, ]
  axis_size <- 2
  context_half <- function(value) ((value - 1) %/% axis_size) + 1
  axis_half <- function(value) ((value - 1) %% axis_size) + 1
  first_reordered <-
    (context_half(second$decision_order) - 1) * axis_size +
    axis_half(first$decision_order)
  second_reordered <-
    (context_half(first$decision_order) - 1) * axis_size +
    axis_half(second$decision_order)
  DBI::dbExecute(
    opened$con,
    paste(
      "UPDATE run_diagnostic_implicit SET decision_seq = -1, decision_order = -1",
      "WHERE run_id = ? AND decision_seq = ?"
    ),
    params = list(bt$run_id, first$decision_seq)
  )
  DBI::dbExecute(
    opened$con,
    paste(
      "UPDATE run_diagnostic_implicit SET decision_seq = ?, decision_order = ?",
      "WHERE run_id = ? AND decision_seq = ?"
    ),
    params = list(
      first$decision_seq, second_reordered,
      bt$run_id, second$decision_seq
    )
  )
  DBI::dbExecute(
    opened$con,
    paste(
      "UPDATE run_diagnostic_implicit SET decision_seq = ?, decision_order = ?",
      "WHERE run_id = ? AND decision_seq = -1"
    ),
    params = list(second$decision_seq, first_reordered, bt$run_id)
  )
  testthat::expect_error(
    ledgr:::ledgr_diagnostic_decode(opened$con, bt$run_id),
    "decision-order evidence is corrupt for run `dynamic-context-order`",
    class = "ledgr_diagnostic_corrupt"
  )
})

testthat::test_that("[LTB-0561] public readers validate one stored diagnostic state once", {
  bars <- expand.grid(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
    instrument_id = c("AAA", "BBB"),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  bars <- bars[order(bars$ts_utc, bars$instrument_id), , drop = FALSE]
  bars$open <- bars$high <- bars$low <- bars$close <- 10
  bars$volume <- 1000
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  bt <- ledgr_run(ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$hold(),
    opening = ledgr_opening(cash = 1000),
    cost_model = ledgr_cost_zero()
  ), run_id = "diagnostic-validation-reuse")
  on.exit(close(bt), add = TRUE)

  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  original <- ledgr:::ledgr_diagnostic_decision_order_bad
  testthat::local_mocked_bindings(
    ledgr_diagnostic_decision_order_bad = function(...) {
      calls$n <- calls$n + 1L
      original(...)
    },
    .package = "ledgr"
  )
  first_ts <- bars$ts_utc[[1L]]
  opened_before <- ledgr:::ledgr_backtest_read_connection(bt)
  on.exit(opened_before$close(), add = TRUE)
  memory_limit_before <- DBI::dbGetQuery(
    opened_before$con,
    "SELECT current_setting('memory_limit') AS value"
  )$value[[1L]]
  testthat::expect_no_error(ledgr_run_explain(bt, "AAA", first_ts))
  testthat::expect_identical(calls$n, 1L)
  testthat::expect_no_error(ledgr_run_explain(bt, "AAA"))
  testthat::expect_no_error(capture.output(print(bt)))
  testthat::expect_no_error(capture.output(summary(bt)))
  testthat::expect_no_error(ledgr_compute_metrics(bt))
  testthat::expect_no_error(ledgr_results(bt, "diagnostics"))
  testthat::expect_identical(calls$n, 1L)
  testthat::expect_identical(
    DBI::dbGetQuery(
      opened_before$con,
      "SELECT current_setting('memory_limit') AS value"
    )$value[[1L]],
    memory_limit_before
  )

  # Changing the persisted state token invalidates the handle cache. Coverage
  # remains the authority, so the first following public read refuses.
  opened <- ledgr:::ledgr_backtest_read_connection(bt)
  on.exit(opened$close(), add = TRUE)
  DBI::dbExecute(
    opened$con,
    paste(
      "UPDATE run_diagnostic_coverage SET logical_count = logical_count + 1",
      "WHERE run_id = ?"
    ),
    params = list(bt$run_id)
  )
  testthat::expect_error(
    ledgr_results(bt, "diagnostics"),
    "coverage is corrupt",
    class = "ledgr_diagnostic_corrupt"
  )
  DBI::dbExecute(
    opened$con,
    paste(
      "UPDATE run_diagnostic_coverage SET logical_count = logical_count - 1",
      "WHERE run_id = ?"
    ),
    params = list(bt$run_id)
  )

  # The run/snapshot store stamp changes on a direct compact-row write, so the
  # already-opened handle cannot hide corruption behind its prior proof.
  row <- DBI::dbGetQuery(
    opened$con,
    paste(
      "SELECT decision_seq, target FROM run_diagnostic_implicit",
      "WHERE run_id = ? ORDER BY decision_seq LIMIT 1"
    ),
    params = list(bt$run_id)
  )
  DBI::dbExecute(
    opened$con,
    paste(
      "UPDATE run_diagnostic_implicit SET target = target + 1",
      "WHERE run_id = ? AND decision_seq = ?"
    ),
    params = list(bt$run_id, row$decision_seq[[1L]])
  )
  testthat::expect_error(
    ledgr_results(bt, "diagnostics"),
    class = "ledgr_diagnostic_corrupt"
  )
  DBI::dbExecute(
    opened$con,
    paste(
      "UPDATE run_diagnostic_implicit SET target = ?",
      "WHERE run_id = ? AND decision_seq = ?"
    ),
    params = list(row$target[[1L]], bt$run_id, row$decision_seq[[1L]])
  )
  reopened <- ledgr_run_open(snapshot, bt$run_id)
  on.exit(close(reopened), add = TRUE)
  testthat::expect_no_error(ledgr_results(reopened, "diagnostics"))
})
