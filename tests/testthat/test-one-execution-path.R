ws4b_bars <- function(days = 4L, instruments = "AAA") {
  axis <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * seq_len(days) - 86400
  out <- expand.grid(
    ts_utc = axis,
    instrument_id = instruments,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  out <- out[order(out$instrument_id, out$ts_utc), , drop = FALSE]
  price <- 100 + match(out$ts_utc, axis)
  transform(
    out,
    open = price,
    high = price + 1,
    low = price - 1,
    close = price,
    volume = 1000
  )
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0523] run and sweep refuse the same invalid strategy state", {
  snapshot <- ledgr_snapshot_from_df(ws4b_bars(3L))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  cases <- list(
    list(
      id = "non-finite",
      exp = ledgr_experiment(opening = ledgr_opening(cash = 100000),
        snapshot,
        function(ctx, params) {
          list(targets = ctx$hold(), state_update = list(value = Inf))
        },
        portfolio_state = list(value = 0),
        cost_model = ledgr_cost_zero()
      ),
      class = "ledgr_invalid_strategy_state"
    ),
    list(
      id = "non-deterministic",
      exp = ledgr_experiment(opening = ledgr_opening(cash = 100000),
        snapshot,
        function(ctx, params) {
          list(
            targets = ctx$hold(),
            state_update = list(value = function(x) x)
          )
        },
        portfolio_state = list(value = 0),
        cost_model = ledgr_cost_zero()
      ),
      class = "ledgr_invalid_strategy_state"
    )
  )
  grid <- ledgr_grid_named(candidate = list(strategy = list()))

  for (case in cases) {
    run_error <- testthat::expect_error(
      ledgr_run(case$exp, run_id = paste0("bad-state-", case$id)),
      class = case$class
    )
    sweep <- ledgr_sweep(case$exp, grid)
    testthat::expect_identical(sweep$status, "FAILED")
    testthat::expect_identical(sweep$error_class, class(run_error)[[1L]])
  }
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0524] bar-native coverage starts at the executable boundary", {
  bars <- ws4b_bars(5L, c("AAA", "BBB"))
  gap <- bars$instrument_id == "BBB" &
    bars$ts_utc == as.POSIXct("2020-01-02", tz = "UTC")
  bars <- bars[!gap, , drop = FALSE]
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    universe = c("AAA", "BBB"),
    opening = ledgr_opening(cash = 1000, date = as.Date("2020-01-04")),
    cost_model = ledgr_cost_zero()
  )

  bt <- ledgr_run(exp, run_id = "coverage-after-opening")
  on.exit(close(bt), add = TRUE)
  testthat::expect_identical(nrow(ledgr_results(bt, "equity")), 2L)
  pulse <- ledgr_pulse_snapshot(
    exp,
    ts_utc = as.POSIXct("2020-01-04", tz = "UTC")
  )
  on.exit(close(pulse), add = TRUE)
  testthat::expect_identical(pulse$universe, c("AAA", "BBB"))

  # A missing bar after the executable boundary remains a public strict-
  # coverage refusal. This distinguishes the accepted pre-opening omission
  # above from an in-range gap without pinning a private preparation seam.
  in_range_bars <- ws4b_bars(5L, c("AAA", "BBB"))
  in_range_gap <- in_range_bars$instrument_id == "BBB" &
    in_range_bars$ts_utc == as.POSIXct("2020-01-05", tz = "UTC")
  in_range_bars <- in_range_bars[!in_range_gap, , drop = FALSE]
  in_range_snapshot <- ledgr_snapshot_from_df(in_range_bars)
  on.exit(ledgr_snapshot_close(in_range_snapshot), add = TRUE)
  in_range_exp <- ledgr_experiment(
    in_range_snapshot,
    function(ctx, params) ctx$flat(),
    universe = c("AAA", "BBB"),
    opening = ledgr_opening(cash = 1000, date = as.Date("2020-01-04")),
    cost_model = ledgr_cost_zero()
  )
  testthat::expect_error(
    ledgr_run(in_range_exp, run_id = "coverage-inside-execution"),
    class = "LEDGR_SNAPSHOT_COVERAGE_ERROR"
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0525] final-pulse diagnostic sequences match memory and durable sinks", {
  snapshot <- ledgr_snapshot_from_df(ws4b_bars(3L))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    target <- ctx$flat()
    if (identical(ctx$ts_utc, "2020-01-03T00:00:00Z")) target[["AAA"]] <- 1
    target
  }
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(candidate = list(strategy = list()))
  sweep <- ledgr_sweep(exp, grid)
  bt <- ledgr_run(exp, run_id = "final-pulse-sequence")
  on.exit(close(bt), add = TRUE)
  durable <- ledgr_results(bt, "diagnostics")
  durable <- durable[durable$reason_code == "final_pulse_no_execution", , drop = FALSE]
  memory <- sweep$diagnostics[[1L]]
  memory <- memory[memory$reason_code == "final_pulse_no_execution", , drop = FALSE]
  testthat::expect_identical(nrow(durable), 1L)
  testthat::expect_identical(nrow(memory), 1L)
  testthat::expect_identical(memory$diagnostic_seq, durable$diagnostic_seq)
  shared <- setdiff(intersect(names(memory), names(durable)), "run_id")
  testthat::expect_identical(
    lapply(shared, function(name) memory[[name]]),
    lapply(shared, function(name) durable[[name]])
  )
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0526] target-change tolerance keeps its relative and absolute boundary", {
  tolerance <- sqrt(.Machine$double.eps)
  testthat::expect_false(ledgr:::ledgr_fold_target_changed(
    tolerance, 0, tolerance = tolerance
  ))
  testthat::expect_true(ledgr:::ledgr_fold_target_changed(
    tolerance + .Machine$double.eps, 0, tolerance = tolerance
  ))
  target <- 100
  testthat::expect_false(ledgr:::ledgr_fold_target_changed(
    target + tolerance * target, target, tolerance = tolerance
  ))
  testthat::expect_true(ledgr:::ledgr_fold_target_changed(
    target + 2 * tolerance * target, target, tolerance = tolerance
  ))
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0527] reconciliation formatting stays outside the pulse stage", {
  stage <- paste(deparse(body(ledgr:::ledgr_fold_stage_commit)), collapse = "\n")
  drain <- paste(deparse(body(ledgr:::ledgr_fold_diagnostic_block)), collapse = "\n")
  target <- paste(deparse(body(ledgr:::ledgr_fold_target_changed)), collapse = "\n")

  testthat::expect_no_match(stage, "ledgr_fold_reconciliation_detail", fixed = TRUE)
  testthat::expect_no_match(stage, "ledgr_json_write_canonical_v2", fixed = TRUE)
  testthat::expect_match(stage, "ledgr_fold_reconciliation_check", fixed = TRUE)
  testthat::expect_match(drain, "ledgr_fold_reconciliation_detail", fixed = TRUE)
  testthat::expect_match(drain, "reason_code", fixed = TRUE)
  testthat::expect_no_match(target, "all.equal", fixed = TRUE)
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0528] identity rule four artifacts refuse at each current boundary", {
  db_path <- tempfile(fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(ws4b_bars(3L), db_path = db_path)
  on.exit(try(ledgr_snapshot_close(snapshot), silent = TRUE), add = TRUE)

  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000),
    snapshot,
    function(ctx, params) ctx$flat(),
    cost_model = ledgr_cost_zero()
  )
  sweep <- ledgr_sweep(exp, ledgr_grid_named(candidate = list()))
  old_sweep <- sweep
  attr(old_sweep, "identity_rule_version") <- 4L
  testthat::expect_error(
    ledgr_sweep_save(old_sweep, snapshot, sweep_id = "rule-four"),
    class = "ledgr_sweep_schema_incompatible"
  )

  old_session <- list(
    status = "DONE",
    walk_forward_schema_version = ledgr:::ledgr_walk_forward_schema_version,
    candidate_schema_version = ledgr:::ledgr_walk_forward_candidate_schema_version,
    identity_rule_version = 4L
  )
  testthat::expect_error(
    ledgr:::ledgr_walk_forward_parse_session_meta(
      as.character(ledgr:::canonical_json(old_session))
    ),
    class = "ledgr_walk_forward_invalid_session"
  )

  con <- ledgr:::get_connection(snapshot)
  old_bindings <- ledgr:::ledgr_store_format_bindings()
  old_bindings$ledgr_identity_rule_version <- 4L
  DBI::dbExecute(
    con,
    paste0(
      "UPDATE ledgr_schema_metadata SET value = ? ",
      "WHERE key = 'format_fingerprint'"
    ),
    params = list(as.character(ledgr:::ledgr_store_format_json(old_bindings)))
  )
  ledgr_snapshot_close(snapshot)
  error <- testthat::expect_error(
    ledgr_snapshot_open(db_path),
    class = "ledgr_store_rebuild_required"
  )
  testthat::expect_identical(error$cause, "fingerprint_mismatch")
  testthat::expect_identical(
    error$differing_constants,
    "ledgr_identity_rule_version"
  )
})
