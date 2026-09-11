availability_economics_snapshot <- function(ids,
                                              days = 4L,
                                              bars = NULL,
                                              membership = NULL,
                                              status = NULL,
                                              lifetime = NULL) {
  dates <- as.Date("2020-01-01") + seq_len(days) - 1L
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00",
      knowledge_time = as.POSIXct(dates, tz = "UTC") - 1
    ),
    venue_id = "XNYS"
  )
  if (is.null(bars)) {
    grid <- expand.grid(
      instrument_id = ids,
      day = seq_len(days),
      KEEP.OUT.ATTRS = FALSE,
      stringsAsFactors = FALSE
    )
    bars <- data.frame(
      ts_utc = as.POSIXct(paste(dates[grid$day], "16:00:00"), tz = "UTC"),
      instrument_id = grid$instrument_id,
      open = 100,
      high = 101,
      low = 99,
      close = 100,
      volume = 1000
    )
  }
  families <- list(sessions)
  if (!is.null(membership)) families <- c(families, list(membership))
  if (!is.null(status)) families <- c(families, list(status))
  if (!is.null(lifetime)) families <- c(families, list(lifetime))
  ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = ids),
    facts = do.call(ledgr_facts, families)
  )
}

availability_economics_tables <- function(bt) {
  opened <- ledgr_test_open_duckdb(bt$db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  list(
    run = DBI::dbGetQuery(opened$con, "SELECT status FROM runs WHERE run_id = ?", params = list(bt$run_id)),
    completion = DBI::dbGetQuery(opened$con, "SELECT * FROM run_completion WHERE run_id = ?", params = list(bt$run_id)),
    diagnostics = DBI::dbGetQuery(opened$con, "SELECT * FROM run_diagnostics WHERE run_id = ? ORDER BY diagnostic_seq", params = list(bt$run_id)),
    events = DBI::dbGetQuery(opened$con, "SELECT * FROM ledger_events WHERE run_id = ? ORDER BY event_seq", params = list(bt$run_id))
  )
}

testthat::test_that("availability target rules and post-risk closure fail closed", {
  view <- list(
    member = c(MEMBER = TRUE, FORMER = FALSE, HALTED = TRUE),
    target_restricted = c(MEMBER = FALSE, FORMER = FALSE, HALTED = TRUE)
  )
  current <- c(MEMBER = 0, FORMER = 10, HALTED = 4)
  good <- c(MEMBER = 2, FORMER = 5, HALTED = 0)
  testthat::expect_invisible(
    ledgr:::ledgr_availability_validate_strategy_targets(good, current, view)
  )
  testthat::expect_error(
    ledgr:::ledgr_availability_validate_strategy_targets(
      c(MEMBER = 2, FORMER = 11, HALTED = 0), current, view
    ),
    class = "ledgr_nonmember_exposure_increase"
  )
  testthat::expect_error(
    ledgr:::ledgr_availability_validate_strategy_targets(
      c(MEMBER = 2, FORMER = 5, HALTED = 2), current, view
    ),
    class = "ledgr_restricted_target"
  )
  testthat::expect_invisible(
    ledgr:::ledgr_availability_validate_post_risk(c(A = 0, B = 3), c(A = -2, B = 5))
  )
  testthat::expect_error(
    ledgr:::ledgr_availability_validate_post_risk(c(A = 3), c(A = 2)),
    class = "ledgr_post_risk_inadmissible"
  )
  testthat::expect_invisible(
    ledgr:::ledgr_availability_validate_short_exposure(c(A = -2, B = 1), c(A = -2, B = 0))
  )
  testthat::expect_error(
    ledgr:::ledgr_availability_validate_short_exposure(c(A = -3), c(A = -2)),
    class = "ledgr_short_exposure_unsupported"
  )
  testthat::expect_error(
    ledgr:::ledgr_availability_validate_short_exposure(c(A = -1e-9), c(A = 0)),
    class = "ledgr_short_exposure_unsupported"
  )
})

testthat::test_that("active rebalance preserves held nonmembers and reserves exposure", {
  ctx <- list(
    universe = c("FORMER", "MEMBER"),
    members = "MEMBER",
    availability_active = TRUE,
    equity = 1000,
    vec = list(
      positions = c(3, 0),
      close = c(NA, 50),
      risk_mark = c(100, 50)
    ),
    idx = function(id) match(id, c("FORMER", "MEMBER"))
  )
  target <- ledgr_target_rebalance(
    ledgr_weights(c(MEMBER = 1), universe = "MEMBER"),
    ctx
  )
  testthat::expect_identical(c(target), c(FORMER = 3, MEMBER = 14))

  ctx$vec$close[[2L]] <- NA_real_
  testthat::expect_error(
    ledgr_target_rebalance(ledgr_weights(c(MEMBER = 1), universe = "MEMBER"), ctx),
    class = "ledgr_target_sizing_unavailable"
  )
})

testthat::test_that("affordability credits accepted reductions before purchases", {
  entry <- function(id, current, delta, side, qty, price) {
    list(
      target_idx = match(id, c("BUY_EXACT", "SELL", "BUY_EXTRA")),
      instrument_id = id,
      current_qty = current,
      delta = delta,
      fill = list(side = side, qty = qty, fill_price = price, fee = 0)
    )
  }
  entries <- list(
    entry("BUY_EXACT", 0, 10, "BUY", 10, 10),
    entry("SELL", 10, -10, "SELL", 10, 10),
    entry("BUY_EXTRA", 0, 1, "BUY", 1, 10)
  )
  out <- ledgr:::ledgr_availability_apply_affordability(entries, cash = 0)
  testthat::expect_identical(
    vapply(out$accepted, `[[`, character(1), "instrument_id"),
    c("BUY_EXACT", "SELL")
  )
  testthat::expect_identical(out$rejected[[1L]]$reason_code, "insufficient_cash")
  testthat::expect_equal(out$final_cash, 0, tolerance = 1e-12)
  permuted <- ledgr:::ledgr_availability_apply_affordability(rev(entries), cash = 0)
  testthat::expect_setequal(
    vapply(permuted$accepted, `[[`, character(1), "instrument_id"),
    c("BUY_EXACT", "SELL")
  )
  testthat::expect_equal(permuted$final_cash, out$final_cash, tolerance = 1e-12)
  boundary <- ledgr:::ledgr_availability_apply_affordability(
    list(entry("BUY_EXACT", 0, 1, "BUY", 1, 5e-9)),
    cash = 0
  )
  testthat::expect_length(boundary$accepted, 1L)
  testthat::expect_equal(boundary$final_cash, -5e-9, tolerance = 1e-15)
  blocked <- entry("BUY_EXACT", 0, 10, "BUY", 10, 10)
  blocked$blocking_reasons <- "trading_halted"
  blocked <- ledgr:::ledgr_availability_apply_affordability(list(blocked), cash = 0)
  testthat::expect_identical(
    blocked$rejected[[1L]]$reasons,
    "trading_halted|insufficient_cash"
  )
})

testthat::test_that("availability short guard runs after explicit long-only risk", {
  snapshot <- availability_economics_snapshot(c("AAA", "BBB"), days = 3L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  short_exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) c(AAA = -1, BBB = 5),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  testthat::expect_error(
    ledgr_run(short_exp, run_id = "active-short-rejected"),
    class = "ledgr_short_exposure_unsupported"
  )
  opened <- ledgr_test_open_duckdb(snapshot$db_path)
  failed_events <- DBI::dbGetQuery(
    opened$con,
    "SELECT * FROM ledger_events WHERE run_id = 'active-short-rejected'"
  )
  ledgr_test_close_duckdb(opened$con, opened$drv)
  testthat::expect_equal(nrow(failed_events), 0L)
  long_only_exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) stats::setNames(rep(-1, length(ctx$universe)), ctx$universe),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero(),
    risk_chain = ledgr_risk_chain(ledgr_risk_long_only())
  )
  bt <- ledgr_run(long_only_exp, run_id = "active-short-clipped")
  on.exit(close(bt), add = TRUE)
  testthat::expect_identical(availability_economics_tables(bt)$run$status, "DONE")
})

testthat::test_that("existing short holdings may hold or consume cash to cover", {
  testthat::expect_invisible(
    ledgr:::ledgr_availability_validate_short_exposure(c(AAA = -2), c(AAA = -2))
  )
  cover <- list(
    target_idx = 1L,
    instrument_id = "AAA",
    current_qty = -2,
    delta = 1,
    fill = list(side = "BUY", qty = 1, fill_price = 100, fee = 0)
  )
  out <- ledgr:::ledgr_availability_apply_affordability(list(cover), cash = 100)
  testthat::expect_length(out$accepted, 1L)
  testthat::expect_equal(out$final_cash, 0)
})

testthat::test_that("new positive exposure without a risk mark stops before fills", {
  dates <- as.Date("2020-01-01") + 0:3
  bars <- data.frame(
    ts_utc = as.POSIXct(paste(dates, "16:00:00"), tz = "UTC"),
    instrument_id = "CLOCK",
    open = 100,
    high = 101,
    low = 99,
    close = 100,
    volume = 1000
  )
  snapshot <- availability_economics_snapshot(c("AAA", "CLOCK"), bars = bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) c(AAA = 1, CLOCK = 0),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp, run_id = "risk-mark-unavailable")
  on.exit(close(bt), add = TRUE)
  stored <- availability_economics_tables(bt)
  testthat::expect_identical(stored$run$status, "INCOMPLETE")
  testthat::expect_identical(stored$completion$stop_reason, "risk_mark_unavailable")
  testthat::expect_false(any(stored$events$event_type == "FILL"))
  testthat::expect_true(any(stored$diagnostics$reason_code == "risk_mark_unavailable"))
})

testthat::test_that("stale valuation marks feed max-weight without pricing execution", {
  dates <- as.Date("2020-01-01") + 0:3
  bars <- data.frame(
    ts_utc = as.POSIXct(paste(c(dates[[1L]], dates), "16:00:00"), tz = "UTC"),
    instrument_id = c("AAA", rep("CLOCK", 4L)),
    open = 100,
    high = 101,
    low = 99,
    close = 100,
    volume = 1000
  )
  snapshot <- availability_economics_snapshot(c("AAA", "CLOCK"), bars = bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      if (identical(ctx$ts_utc, "2020-01-02T16:00:00Z")) {
        c(AAA = 10, CLOCK = 0)
      } else {
        ctx$hold()
      }
    },
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 5), cost_basis = c(AAA = 100)),
    valuation_policy = ledgr_valuation_stale(2),
    cost_model = ledgr_cost_zero(),
    risk_chain = ledgr_risk_chain(ledgr_risk_max_weight(0.2))
  )
  bt <- ledgr_run(exp, run_id = "stale-risk-mark")
  on.exit(close(bt), add = TRUE)
  stored <- availability_economics_tables(bt)
  testthat::expect_identical(stored$run$status, "DONE")
  stale <- stored$diagnostics[
    stored$diagnostics$instrument_id == "AAA" &
      !is.na(stored$diagnostics$mark_age) & stored$diagnostics$mark_age > 0,
    ,
    drop = FALSE
  ]
  testthat::expect_true(nrow(stale) > 0L)
  testthat::expect_true(all(stale$mark_source == "stale_close"))
  testthat::expect_true(all(is.na(stale$price[stale$stage == "execution"])))
  testthat::expect_true(any(stale$reason_code == "stale_mark_reduction"))
  testthat::expect_identical(
    ledgr_run_info(snapshot, bt$run_id)$risk_chain_hash,
    exp$risk_chain_hash
  )
})

testthat::test_that("venue sessions age marks across a whole-feed outage", {
  dates <- as.POSIXct(paste(as.Date("2020-01-01") + 0:3, "16:00:00"), tz = "UTC")
  bars <- data.frame(
    ts_utc = dates[c(1L, 4L)],
    instrument_id = "AAA",
    open = 100,
    high = 101,
    low = 99,
    close = 100,
    volume = 1000
  )
  snapshot <- availability_economics_snapshot("AAA", days = 4L, bars = bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$hold(),
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 2), cost_basis = c(AAA = 100)),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp, run_id = "whole-feed-outage")
  on.exit(close(bt), add = TRUE)
  stored <- availability_economics_tables(bt)
  testthat::expect_identical(stored$run$status, "INCOMPLETE")
  testthat::expect_identical(stored$completion$stop_reason, "valuation_horizon_exhausted")
  testthat::expect_identical(
    as.POSIXct(stored$completion$achieved_end_utc, tz = "UTC"),
    dates[[2L]]
  )
})

testthat::test_that("current-mark-only valuation stops on the first missing session", {
  dates <- as.POSIXct(paste(as.Date("2020-01-01") + 0:2, "16:00:00"), tz = "UTC")
  bars <- data.frame(
    ts_utc = dates[c(1L, 3L)],
    instrument_id = "AAA",
    open = 100,
    high = 101,
    low = 99,
    close = 100,
    volume = 1000
  )
  snapshot <- availability_economics_snapshot("AAA", days = 3L, bars = bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$hold(),
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 1), cost_basis = c(AAA = 100)),
    valuation_policy = ledgr_valuation_stale(0),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp, run_id = "current-mark-only")
  on.exit(close(bt), add = TRUE)
  stored <- availability_economics_tables(bt)
  testthat::expect_identical(stored$run$status, "INCOMPLETE")
  testthat::expect_identical(stored$completion$stop_reason, "valuation_horizon_exhausted")
  stop_row <- stored$diagnostics[stored$diagnostics$outcome == "stopped", , drop = FALSE]
  testthat::expect_identical(stop_row$mark_age, 1L)
})

testthat::test_that("known inactivity does not freeze valuation age", {
  dates <- as.POSIXct(paste(as.Date("2020-01-01") + 0:3, "16:00:00"), tz = "UTC")
  lifetime <- ledgr_facts_lifetime(data.frame(
    instrument_id = "AAA",
    effective_from = dates[[2L]],
    knowledge_time = dates[[2L]] - 1,
    assertion = "known_inactive"
  ))
  bars <- data.frame(
    ts_utc = dates[c(1L, 4L)],
    instrument_id = "AAA",
    open = 100,
    high = 101,
    low = 99,
    close = 100,
    volume = 1000
  )
  snapshot <- availability_economics_snapshot(
    "AAA",
    days = 4L,
    bars = bars,
    lifetime = lifetime
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$hold(),
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 1), cost_basis = c(AAA = 100)),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp, run_id = "inactive-mark-aging")
  on.exit(close(bt), add = TRUE)
  stored <- availability_economics_tables(bt)
  stop_row <- stored$diagnostics[stored$diagnostics$outcome == "stopped", , drop = FALSE]
  testthat::expect_identical(stored$run$status, "INCOMPLETE")
  testthat::expect_identical(stop_row$mark_age, 2L)
  testthat::expect_identical(
    stop_row$reasons,
    "valuation_horizon_exhausted|lifetime_inactive"
  )
})

testthat::test_that("valuation exhaustion commits an incomplete direct-run prefix", {
  dates <- as.Date("2020-01-01") + 0:4
  bars <- data.frame(
    ts_utc = as.POSIXct(paste(c(dates[1:2], dates), "16:00:00"), tz = "UTC"),
    instrument_id = c(rep("AAA", 2L), rep("CLOCK", 5L)),
    open = 100,
    high = 101,
    low = 99,
    close = 100,
    volume = 1000
  )
  snapshot <- availability_economics_snapshot(c("AAA", "CLOCK"), days = 5L, bars = bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      if (identical(ctx$ts_utc, "2020-01-01T16:00:00Z")) c(AAA = 2, CLOCK = 0) else ctx$hold()
    },
    opening = ledgr_opening(cash = 1000),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp, run_id = "valuation-exhaustion")
  on.exit(close(bt), add = TRUE)
  stored <- availability_economics_tables(bt)
  testthat::expect_identical(stored$run$status, "INCOMPLETE")
  testthat::expect_identical(stored$completion$stop_reason, "valuation_horizon_exhausted")
  testthat::expect_false(stored$completion$complete_performance)
  testthat::expect_equal(stored$completion$affected_exposure, 200)
  testthat::expect_identical(stored$completion$affected_exposure_basis, "last_accepted_close_gross")
  testthat::expect_equal(nrow(ledgr_results(bt, "equity")), 3L)
  testthat::expect_identical(
    as.POSIXct(stored$completion$last_fully_valued_ts_utc, tz = "UTC"),
    as.POSIXct("2020-01-03 16:00:00", tz = "UTC")
  )
  testthat::expect_identical(
    as.POSIXct(stored$completion$last_executed_ts_utc, tz = "UTC"),
    as.POSIXct("2020-01-02 16:00:00", tz = "UTC")
  )
  testthat::expect_true(any(stored$events$event_type == "FILL"))
  stop_row <- stored$diagnostics[stored$diagnostics$outcome == "stopped", , drop = FALSE]
  testthat::expect_identical(stop_row$reason_code, "valuation_horizon_exhausted")
  testthat::expect_equal(stop_row$quantity, 2)
  testthat::expect_equal(stop_row$price, 100)
})

testthat::test_that("terminal assertions stop without fabricated settlement", {
  terminal <- ledgr_facts_lifetime(data.frame(
    instrument_id = "AAA",
    effective_from = as.POSIXct("2020-01-02 16:00:00", tz = "UTC"),
    knowledge_time = as.POSIXct("2020-01-02 15:59:59", tz = "UTC"),
    assertion = "known_inactive",
    terminal_event = "delisted"
  ))
  snapshot <- availability_economics_snapshot("AAA", days = 3L, lifetime = terminal)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$hold(),
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 2), cost_basis = c(AAA = 100)),
    valuation_policy = ledgr_valuation_stale(2),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp, run_id = "terminal-settlement")
  on.exit(close(bt), add = TRUE)
  stored <- availability_economics_tables(bt)
  testthat::expect_identical(stored$run$status, "INCOMPLETE")
  testthat::expect_identical(stored$completion$stop_reason, "terminal_settlement_unsupported")
  testthat::expect_false(any(stored$events$ts_utc >= as.POSIXct("2020-01-02 16:00:00", tz = "UTC")))
})

testthat::test_that("affected exposure is gross and missing references fail closed", {
  valuation <- list(
    reference = c(LONG = 100, SHORT = 40, MISSING = NA_real_),
    source_ts = stats::setNames(as.POSIXct(rep("2020-01-01", 3L), tz = "UTC"), c("LONG", "SHORT", "MISSING")),
    age = c(LONG = 0L, SHORT = 2L, MISSING = NA_integer_),
    permissible = c(LONG = TRUE, SHORT = FALSE, MISSING = FALSE)
  )
  gross <- ledgr:::ledgr_availability_affected_exposure(
    c("LONG", "SHORT", "LONG"),
    c(LONG = 10, SHORT = -5),
    valuation
  )
  testthat::expect_equal(gross$value, 1200)
  testthat::expect_equal(length(gross$details), 2L)
  testthat::expect_false(gross$details[[2L]]$mark_permissible)
  testthat::expect_true(is.na(ledgr:::ledgr_availability_affected_exposure(
    c("LONG", "MISSING"),
    c(LONG = 10, MISSING = 1),
    valuation
  )$value))
  testthat::expect_equal(ledgr:::ledgr_availability_affected_exposure(
    character(), c(LONG = 10), valuation
  )$value, 0)
  testthat::expect_true(is.na(ledgr:::ledgr_availability_affected_exposure(
    NULL, c(LONG = 10), valuation
  )$value))
})

testthat::test_that("a rejected sale never funds an unrelated purchase", {
  dates <- as.POSIXct(paste(as.Date("2020-01-01") + 0:2, "16:00:00"), tz = "UTC")
  status <- ledgr_facts_trading_status(data.frame(
    instrument_id = c("SELL", "SELL", "BUY"),
    effective_from = c(dates[[1L]], dates[[2L]], dates[[1L]]),
    effective_to = c(dates[[2L]], as.POSIXct(NA, tz = "UTC"), as.POSIXct(NA, tz = "UTC")),
    knowledge_time = c(dates[[1L]] - 1, dates[[2L]] - 1, dates[[1L]] - 1),
    status = c("active", "halted", "active"),
    source = "exchange",
    precedence = 1L
  ))
  snapshot <- availability_economics_snapshot(c("SELL", "BUY"), days = 3L, status = status)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    if (identical(ctx$ts_utc, "2020-01-01T16:00:00Z")) c(SELL = 0, BUY = 10) else ctx$hold()
  }
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    opening = ledgr_opening(cash = 1, positions = c(SELL = 10), cost_basis = c(SELL = 100)),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp, run_id = "rejected-sale-no-funding")
  on.exit(close(bt), add = TRUE)
  stored <- availability_economics_tables(bt)
  executed <- stored$events[stored$events$ts_utc >= dates[[2L]], , drop = FALSE]
  testthat::expect_equal(nrow(executed), 0L)
  execution <- stored$diagnostics[stored$diagnostics$stage == "execution", , drop = FALSE]
  testthat::expect_setequal(execution$reason_code, c("trading_halted", "insufficient_cash"))
})

testthat::test_that("a blocked exit executes only after a new zero target", {
  dates <- as.POSIXct(paste(as.Date("2020-01-01") + 0:3, "16:00:00"), tz = "UTC")
  status <- ledgr_facts_trading_status(data.frame(
    instrument_id = rep("AAA", 3L),
    effective_from = dates[1:3],
    effective_to = c(dates[[2L]], dates[[3L]], as.POSIXct(NA, tz = "UTC")),
    knowledge_time = dates[1:3] - 1,
    status = c("active", "halted", "active"),
    source = "exchange",
    precedence = 1L
  ))
  snapshot <- availability_economics_snapshot("AAA", days = 4L, status = status)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    opening = ledgr_opening(cash = 1, positions = c(AAA = 2), cost_basis = c(AAA = 100)),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp, run_id = "blocked-exit-retry")
  on.exit(close(bt), add = TRUE)
  stored <- availability_economics_tables(bt)
  execution <- stored$diagnostics[stored$diagnostics$stage == "execution", , drop = FALSE]
  testthat::expect_identical(execution$outcome, c("no_fill", "filled"))
  testthat::expect_identical(execution$reason_code, c("trading_halted", ""))
  fill <- stored$events[stored$events$event_type == "FILL", , drop = FALSE]
  testthat::expect_equal(nrow(fill), 1L)
  testthat::expect_equal(fill$qty, 2)
  testthat::expect_identical(fill$ts_utc, dates[[3L]])
})

testthat::test_that("execution diagnostics retain ordered gate reasons", {
  dates <- as.POSIXct(paste(as.Date("2020-01-01") + 0:2, "16:00:00"), tz = "UTC")
  status <- ledgr_facts_trading_status(data.frame(
    instrument_id = c("AAA", "AAA"),
    effective_from = dates[1:2],
    effective_to = c(dates[[2L]], as.POSIXct(NA, tz = "UTC")),
    knowledge_time = dates[1:2] - 1,
    status = c("active", "halted"),
    source = "exchange",
    precedence = 1L
  ))
  bars <- data.frame(
    ts_utc = dates[c(1L, 3L)],
    instrument_id = "AAA",
    open = 100,
    high = 101,
    low = 99,
    close = 100,
    volume = 1000
  )
  snapshot <- availability_economics_snapshot("AAA", days = 3L, bars = bars, status = status)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      if (identical(ctx$ts_utc, "2020-01-01T16:00:00Z")) c(AAA = 1) else ctx$hold()
    },
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp, run_id = "ordered-execution-reasons")
  on.exit(close(bt), add = TRUE)
  diagnostics <- availability_economics_tables(bt)$diagnostics
  row <- diagnostics[
    diagnostics$stage == "execution" & diagnostics$instrument_id == "AAA",
    ,
    drop = FALSE
  ]
  testthat::expect_identical(row$reason_code[[1L]], "trading_halted")
  testthat::expect_identical(row$reasons[[1L]], "trading_halted|execution_bar_missing")
})

testthat::test_that("execution-time membership changes are diagnostic only", {
  dates <- as.POSIXct(paste(as.Date("2020-01-01") + 0:2, "16:00:00"), tz = "UTC")
  membership <- ledgr_facts_membership_snapshots(
    data.frame(
      instrument_id = c("AAA", NA_character_),
      effective_from = dates[1:2],
      knowledge_time = dates[1:2] - 1
    ),
    universe_id = "changing",
    complete = TRUE
  )
  snapshot <- availability_economics_snapshot("AAA", days = 3L, membership = membership)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      if (identical(ctx$ts_utc, "2020-01-01T16:00:00Z")) c(AAA = 1) else ctx$hold()
    },
    universe = ledgr_universe_members("changing"),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp, run_id = "membership-change-diagnostic")
  on.exit(close(bt), add = TRUE)
  stored <- availability_economics_tables(bt)
  testthat::expect_identical(stored$run$status, "DONE")
  filled <- stored$diagnostics[
    stored$diagnostics$stage == "execution" & stored$diagnostics$outcome == "filled",
    ,
    drop = FALSE
  ]
  testthat::expect_identical(filled$reason_code[[1L]], "membership_changed_before_execution")
  testthat::expect_true(any(stored$events$event_type == "FILL"))
})

testthat::test_that("decision traces append across deliberate interruption and resume", {
  snapshot <- availability_economics_snapshot("AAA", days = 3L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  prior_interrupt <- getOption("ledgr.interrupt")
  on.exit(options(ledgr.interrupt = prior_interrupt), add = TRUE)
  strategy <- function(ctx, params) {
    if (identical(ctx$ts_utc, "2020-01-01T16:00:00Z")) {
      options(ledgr.interrupt = TRUE)
    }
    ctx$flat()
  }
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  first <- ledgr_run(exp, run_id = "availability-interrupted")
  first_stored <- availability_economics_tables(first)
  first_diagnostics <- first_stored$diagnostics
  testthat::expect_identical(first_stored$run$status, "RUNNING")
  testthat::expect_equal(nrow(first_stored$completion), 0L)
  testthat::expect_gt(nrow(first_diagnostics), 0L)
  close(first)

  options(ledgr.interrupt = FALSE)
  resumed <- ledgr_run(exp, run_id = "availability-interrupted")
  on.exit(close(resumed), add = TRUE)
  resumed_stored <- availability_economics_tables(resumed)
  testthat::expect_identical(resumed_stored$run$status, "DONE")
  testthat::expect_equal(nrow(resumed_stored$completion), 1L)
  testthat::expect_gt(nrow(resumed_stored$diagnostics), nrow(first_diagnostics))
  testthat::expect_identical(
    resumed_stored$diagnostics[seq_len(nrow(first_diagnostics)), , drop = FALSE],
    first_diagnostics
  )
  testthat::expect_identical(
    resumed_stored$diagnostics$diagnostic_seq,
    seq_len(nrow(resumed_stored$diagnostics))
  )
})

testthat::test_that("unexpected fold errors roll back economics and retain error diagnostics", {
  snapshot <- availability_economics_snapshot("AAA", days = 3L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      if (identical(ctx$ts_utc, "2020-01-02T16:00:00Z")) stop("injected fold failure")
      c(AAA = 1)
    },
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  testthat::expect_error(
    ledgr_run(exp, run_id = "unexpected-fold-error"),
    "injected fold failure"
  )
  opened <- ledgr_test_open_duckdb(snapshot$db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  run <- DBI::dbGetQuery(
    opened$con,
    "SELECT status FROM runs WHERE run_id = 'unexpected-fold-error'"
  )
  events <- DBI::dbGetQuery(
    opened$con,
    "SELECT * FROM ledger_events WHERE run_id = 'unexpected-fold-error'"
  )
  diagnostics <- DBI::dbGetQuery(
    opened$con,
    "SELECT * FROM run_diagnostics WHERE run_id = 'unexpected-fold-error'"
  )
  completion <- DBI::dbGetQuery(
    opened$con,
    "SELECT * FROM run_completion WHERE run_id = 'unexpected-fold-error'"
  )
  testthat::expect_identical(run$status, "FAILED")
  testthat::expect_equal(nrow(events), 0L)
  testthat::expect_equal(nrow(completion), 0L)
  testthat::expect_equal(nrow(diagnostics), 1L)
  testthat::expect_identical(diagnostics$stage, "strategy")
  testthat::expect_identical(diagnostics$outcome, "error")
  testthat::expect_identical(diagnostics$reason_code, "fold_exception")
})
