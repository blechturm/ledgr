sizing_evidence_context <- function() {
  list(
    universe = c("AAA", "BBB", "OLD", "MISS"),
    equity = 1000,
    cash = 400,
    close = c(AAA = 10, BBB = 20, OLD = 5, MISS = NA_real_),
    position = c(AAA = 10, BBB = 5, OLD = 4, MISS = 2),
    held = c(AAA = TRUE, BBB = TRUE, OLD = TRUE, MISS = TRUE),
    member = c(AAA = TRUE, BBB = TRUE, OLD = FALSE, MISS = TRUE),
    buyable = c(AAA = TRUE, BBB = TRUE, OLD = FALSE, MISS = TRUE),
    holding_value = c(AAA = 100, BBB = 100, OLD = 20, MISS = 30),
    .notes = new.env(parent = emptyenv())
  )
}

sizing_evidence_bars <- function(days = 4L) {
  ids <- c("AAA", "BBB", "CCC")
  price <- c(AAA = 30, BBB = 200, CCC = 10)
  dates <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * (seq_len(days) - 1L)
  do.call(rbind, lapply(dates, function(ts) {
    data.frame(
      ts_utc = ts,
      instrument_id = ids,
      open = unname(price),
      high = unname(price),
      low = unname(price),
      close = unname(price),
      volume = 1000,
      stringsAsFactors = FALSE
    )
  }))
}

# ledgr-test-profile: fast
testthat::test_that("[LTB-0539] target helpers carry exact typed sizing evidence", {
  ctx <- sizing_evidence_context()
  target <- ledgr_target_rebalance(
    ctx,
    weights = c(AAA = 0.4, BBB = 0.001, MISS = 0.2),
    keep = "OLD",
    index_leavers = "sell",
    capital_base = "remaining_equity"
  )
  evidence <- attr(target, "sizing_evidence", exact = TRUE)

  testthat::expect_s3_class(evidence, "ledgr_sizing_evidence")
  testthat::expect_identical(
    names(evidence),
    c(
      "instrument_id", "requested_quantity", "pre_floor_quantity",
      "rounded_quantity", "price", "position_before", "reason_code"
    )
  )
  testthat::expect_identical(evidence$instrument_id, c("AAA", "BBB", "MISS"))
  testthat::expect_equal(evidence$requested_quantity, c(39.2, 0.049, NA_real_))
  testthat::expect_equal(evidence$pre_floor_quantity, c(39.2, 0.049, NA_real_))
  testthat::expect_identical(evidence$rounded_quantity, c(39, 0, 2))
  testthat::expect_identical(evidence$price, c(10, 20, NA_real_))
  testthat::expect_identical(evidence$position_before, c(10, 5, 2))
  testthat::expect_identical(
    evidence$reason_code,
    c("sizing_rounded", "sizing_rounded_to_zero_liquidation", "sizing_unavailable")
  )

  zero <- ledgr_target_rebalance(
    ctx,
    weights = c(MISS = 0),
    keep = "OLD",
    index_leavers = "sell"
  )
  zero_evidence <- attr(zero, "sizing_evidence", exact = TRUE)
  miss <- match("MISS", zero_evidence$instrument_id)
  testthat::expect_identical(zero_evidence$reason_code[[miss]], "sizing_liquidation")
  testthat::expect_true(is.na(zero_evidence$price[[miss]]))
  testthat::expect_identical(zero_evidence$rounded_quantity[[miss]], 0)

  empty <- sizing_evidence_context()
  empty$position["BBB"] <- 0
  empty$holding_value["BBB"] <- 0
  addition <- ledgr_target_adjust(
    empty,
    add_value = c(BBB = 1),
    capital_base = "total_equity"
  )
  addition_evidence <- attr(addition, "sizing_evidence", exact = TRUE)
  testthat::expect_identical(
    addition_evidence$reason_code,
    "sizing_rounded_to_zero_addition"
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0540] runs persist and report sizing evidence without JSON", {
  snapshot <- ledgr_snapshot_from_df(
    sizing_evidence_bars(),
    instruments_df = data.frame(
      instrument_id = c("AAA", "BBB", "CCC"),
      currency = "USD",
      stringsAsFactors = FALSE
    )
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    target <- ledgr_target_rebalance(
      ctx,
      weights = c(AAA = 0.5, BBB = 0.1, CCC = 0),
      capital_base = "total_equity"
    )
    ledgr_strategy_result(target, intent_reason = "rebalanced")
  }
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    opening = ledgr_opening(
      cash = 100,
      positions = c(CCC = 1),
      cost_basis = c(CCC = 10)
    ),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(experiment, run_id = "sizing-evidence")
  on.exit(close(bt), add = TRUE)
  diagnostics <- ledgr_results(bt, "diagnostics")
  rows <- diagnostics[diagnostics$stage == "sizing", , drop = FALSE]
  first_time <- min(as.numeric(rows$ts_utc))
  first <- rows[as.numeric(rows$ts_utc) == first_time, , drop = FALSE]
  first <- first[match(c("AAA", "BBB", "CCC"), first$instrument_id), , drop = FALSE]

  testthat::expect_identical(first$reason_code, c(
    "sizing_rounded",
    "sizing_rounded_to_zero_addition",
    "sizing_liquidation"
  ))
  testthat::expect_equal(first$target_before_risk, c(55 / 30, 11 / 200, 0))
  testthat::expect_equal(first$target, c(55 / 30, 11 / 200, 0))
  testthat::expect_identical(first$quantity, c(1, 0, 0))
  testthat::expect_identical(first$price, c(30, 200, 10))
  testthat::expect_identical(first$position_before, c(0, 0, 1))
  testthat::expect_identical(first$detail_json, rep("{}", 3L))

  intent <- diagnostics[diagnostics$reason_code == "strategy_intent", , drop = FALSE]
  testthat::expect_identical(intent$reasons, rep("rebalanced", 4L))
  testthat::expect_identical(intent$detail_json, rep("{}", 4L))
  explanation <- ledgr_run_explain(bt, "AAA")
  testthat::expect_identical(explanation$intent_reason, rep("rebalanced", 4L))

  summary_value <- ledgr:::ledgr_run_sizing_summary(bt)
  testthat::expect_true(summary_value$available)
  testthat::expect_identical(summary_value$evidenced_decisions, 4L)
  testthat::expect_identical(summary_value$unavailable_decisions, 0L)
  testthat::expect_identical(summary_value$rounded_to_zero_instructions, 4L)
  testthat::expect_equal(summary_value$pooled_coverage, 30 / 66)
  testthat::expect_equal(summary_value$minimum_decision_coverage, 30 / 66)
  testthat::expect_equal(summary_value$last_decision_coverage, 30 / 66)
  testthat::expect_identical(summary_value$currency, "USD")
  testthat::expect_match(summary_value$decision_clock, "decision mark", fixed = TRUE)
  printed <- capture.output(summary(bt))
  testthat::expect_true(any(grepl("Decision-exposure diagnostics", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("Final actual invested exposure", printed, fixed = TRUE)))
  testthat::expect_false(any(grepl("intent_reason", rows$detail_json, fixed = TRUE)))

  sweep <- ledgr_sweep(
    experiment,
    ledgr_grid_named(one = list(strategy = list())),
    seed = 1L
  )
  testthat::expect_false(any(vapply(sweep$diagnostics, function(x) {
    !is.null(x) && any(x$stage == "sizing")
  }, logical(1L))))
  testthat::expect_false("sizing_coverage" %in% names(sweep))
  promoted <- ledgr_promote(
    experiment,
    ledgr_candidate(sweep, "one"),
    run_id = "sizing-evidence-promoted"
  )
  on.exit(close(promoted), add = TRUE)
  testthat::expect_equal(
    ledgr:::ledgr_run_sizing_summary(promoted)$pooled_coverage,
    30 / 66
  )

  raw <- ledgr_run(
    ledgr_experiment(
      snapshot,
      function(ctx, params) ctx$hold(),
      opening = ledgr_opening(cash = 100),
      cost_model = ledgr_cost_zero()
    ),
    run_id = "sizing-evidence-raw"
  )
  on.exit(close(raw), add = TRUE)
  raw_rows <- ledgr_results(raw, "diagnostics")
  raw_rows <- raw_rows[raw_rows$stage == "sizing", , drop = FALSE]
  testthat::expect_identical(nrow(raw_rows), 1L)
  testthat::expect_identical(raw_rows$reason_code, "sizing_intent_unavailable")
  raw_summary <- ledgr:::ledgr_run_sizing_summary(raw)
  testthat::expect_false(raw_summary$available)
  testthat::expect_identical(raw_summary$unavailable_decisions, 4L)
  testthat::expect_true(is.na(raw_summary$pooled_coverage))
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0542] risk and cash rejection do not relabel sizing intent", {
  risk_snapshot <- ledgr_snapshot_from_df(sizing_evidence_bars(3L))
  on.exit(ledgr_snapshot_close(risk_snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    ledgr_target_rebalance(
      ctx,
      weights = c(AAA = 0.8),
      capital_base = "total_equity"
    )
  }
  risk_run <- ledgr_run(ledgr_experiment(
    risk_snapshot,
    strategy,
    opening = ledgr_opening(cash = 1000),
    cost_model = ledgr_cost_zero(),
    risk_chain = ledgr_risk_chain(ledgr_risk_max_weight(0.2))
  ))
  on.exit(close(risk_run), add = TRUE)
  risk_rows <- ledgr_results(risk_run, "diagnostics")
  risk_sizing <- risk_rows[risk_rows$stage == "sizing", , drop = FALSE]
  risk_decision <- risk_rows[
    risk_rows$stage == "decision" & risk_rows$instrument_id == "AAA",
    , drop = FALSE
  ]
  testthat::expect_true(nrow(risk_sizing) > 0L)
  testthat::expect_true(all(risk_sizing$reason_code == "sizing_rounded"))
  testthat::expect_true(any(
    risk_decision$target_before_risk != risk_decision$target_after_risk
  ))

  cash_bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2,
    instrument_id = "AAA",
    open = c(10, 100, 100),
    high = c(10, 100, 100),
    low = c(10, 100, 100),
    close = c(10, 100, 100),
    volume = 1000
  )
  cash_snapshot <- ledgr_snapshot_from_df(cash_bars)
  on.exit(ledgr_snapshot_close(cash_snapshot), add = TRUE)
  cash_run <- ledgr_run(ledgr_experiment(
    cash_snapshot,
    strategy,
    opening = ledgr_opening(cash = 50),
    cost_model = ledgr_cost_zero()
  ))
  on.exit(close(cash_run), add = TRUE)
  cash_rows <- ledgr_results(cash_run, "diagnostics")
  cash_sizing <- cash_rows[cash_rows$stage == "sizing", , drop = FALSE]
  testthat::expect_true(nrow(cash_sizing) > 0L)
  testthat::expect_identical(cash_sizing$reason_code[[1L]], "sizing_rounded")
  testthat::expect_false(any(cash_sizing$reason_code == "sizing_unavailable"))
  testthat::expect_true(any(cash_rows$reason_code == "insufficient_cash"))
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0541] sizing evidence is bound and stays out of the pulse JSON path", {
  root <- testthat::test_path("..", "..")
  fold_source <- readLines(file.path(root, "R", "fold-engine.R"), warn = FALSE)
  reader_source <- readLines(file.path(root, "R", "availability-results.R"), warn = FALSE)
  binding <- ledgr:::ledgr_store_format_bindings()

  testthat::expect_identical(
    unname(binding[["ledgr_sizing_evidence_rule_version"]]),
    1L
  )
  testthat::expect_true(any(grepl("stage = \"sizing\"", fold_source, fixed = TRUE)))
  testthat::expect_true(any(grepl("reasons = intent_reason", fold_source, fixed = TRUE)))
  testthat::expect_false(any(grepl("canonical_json(list(intent_reason", fold_source, fixed = TRUE)))
  testthat::expect_false(any(grepl("ledgr_strategy_intent_reasons", reader_source, fixed = TRUE)))
})
