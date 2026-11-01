# LDG-3166 (design note Section 5, decision 10): the next-open fill model is
# the typed plan batch. Each block keeps its original inputs and values; the
# proposal, fill-context and fill-intent object shapes retire with the
# objects (Synthesis 3.3).

# The canonical planner on one fixed-basket decision pulse: `open` is the
# prepared next-open matrix and `delta` the context targets from flat positions.
ledgr_test_dense_plan <- function(open,
                                  delta,
                                  context_pos = seq_along(delta),
                                  has_next = TRUE,
                                  exec_ts = 1577923200,
                                  epoch_valid = TRUE,
                                  resolver = ledgr_test_cost_resolver()) {
  next_open <- if (isTRUE(has_next)) {
    as.numeric(open[, 2L, drop = TRUE])
  } else {
    rep(NA_real_, nrow(open))
  }
  n <- length(delta)
  ledgr:::ledgr_fold_build_availability_pulse_plan(
    context_pos = as.integer(context_pos),
    target_qty = as.numeric(delta),
    position = numeric(length(delta)),
    actionable_k = seq_along(delta),
    member = rep(TRUE, length(delta)),
    execution = list(
      exec_ts = if (has_next) exec_ts else NA_real_,
      has_next = isTRUE(has_next),
      open = next_open
    ),
    execution_view = list(
      member = rep(TRUE, n), restricted = rep(FALSE, n),
      reason_offset = rep(0L, n), reason_count = rep(0L, n),
      reason_code = integer()
    ),
    epoch_valid = epoch_valid,
    cost_resolver = resolver,
    cash = 1e300,
    instrument_ids = paste0("I", seq_len(nrow(open)))
  )
}

testthat::test_that("fill model is deterministic and rounds fill_price", {
  bar <- list(
    instrument_id = "AAA",
    ts_utc = as.POSIXct("2020-01-02 00:00:00", tz = "UTC"),
    open = 100.123456789
  )

  # Category 4: the batch resolver on one row.
  a <- ledgr_test_next_open_fill(
    desired_qty_delta = 10,
    next_bar = bar,
    spread_bps = 7,
    commission_fixed = 1.25
  )
  b <- ledgr_test_next_open_fill(
    desired_qty_delta = 10,
    next_bar = bar,
    spread_bps = 7,
    commission_fixed = 1.25
  )

  testthat::expect_identical(a, b)
  testthat::expect_identical(a$fill$side, 1L)
  testthat::expect_equal(a$fill$qty, 10)
  testthat::expect_equal(a$fill$price, round(100.123456789 * (1 + 7 / 20000), 8))
})

testthat::test_that("execution epochs stay doubles inside the plan and become POSIXct at the boundary", {
  bar <- list(
    instrument_id = "AAA",
    ts_utc = as.POSIXct("2020-01-02 00:00:00", tz = "UTC"),
    open = 100
  )
  # Category 5 (Synthesis 4): epochs inside the carrier, POSIXct at the
  # output boundary.
  f <- ledgr_test_next_open_fill(10, bar, spread_bps = 0, commission_fixed = 0)
  testthat::expect_true(is.double(f$fill$exec_ts) && is.null(attributes(f$fill$exec_ts)))
  testthat::expect_identical(f$fill$exec_ts, as.numeric(bar$ts_utc))
  # LDG-3167 (category 5; the per-fill row helper retires): the published
  # block keeps the epoch; the handler's published row is the boundary.
  block <- ledgr:::ledgr_fill_event_payload("run-1", f$fill, f$i, f$instrument_id, 1L)
  testthat::expect_true(is.double(block$ts_utc) && is.null(attributes(block$ts_utc)))
  handler <- ledgr:::ledgr_output_handler(ledgr:::ledgr_output_sink_memory("run-1"))
  handler$init_buffers(1L)
  handler$write_fill_events(f$fill, f$i, f$instrument_id, 1L)
  handler$flush_pulse_events()
  row <- handler$events()
  testthat::expect_s3_class(row$ts_utc, "POSIXct")
  testthat::expect_identical(attr(row$ts_utc, "tzone"), "UTC")
  testthat::expect_identical(as.numeric(row$ts_utc), as.numeric(bar$ts_utc))
})

testthat::test_that("sub-second fill timestamps fail loud", {
  # Category 4: the opportunity axis is validated once; a fill that needs a
  # sub-second epoch refuses with the fill model's class.
  epoch <- as.numeric(as.POSIXct("2020-01-02 00:00:00", tz = "UTC")) + 0.25
  testthat::expect_identical(ledgr:::ledgr_plan_epoch_valid(c(epoch - 0.25, epoch, NA)), c(TRUE, FALSE, FALSE))
  open <- matrix(100, 1L, 2L)
  testthat::expect_error(
    ledgr_test_dense_plan(open, 10, exec_ts = epoch, epoch_valid = FALSE),
    class = "LEDGR_SUBSECOND_TIMESTAMP"
  )
  testthat::expect_error(ledgr:::ledgr_plan_refuse_epoch(epoch), class = "ledgr_invalid_fill_input")
})

testthat::test_that("the availability execution packet projects the next bar onto the run axis", {
  # Category 5: the proposal's execution-bar shape retires; the next-bar
  # values the fill model reads are the execution packet's run-axis columns.
  pulses <- as.POSIXct("2024-01-01 16:00:00", tz = "UTC") + 86400 * 0:3
  bars <- data.frame(
    ts_utc = rep(pulses, 2L),
    instrument_id = rep(c("AAA", "BBB"), each = 4L),
    open = c(100, 101, 102, 103, 50, 51, 52, 53),
    high = c(101, 102.5, 103.5, 104.5, 51, 52.5, 53.5, 54.5),
    low = c(99, 99.5, 100.5, 101.5, 49, 49.5, 50.5, 51.5),
    close = c(100.5, 101.5, 102.5, 103.5, 50.5, 51.5, 52.5, 53.5),
    volume = c(1000, 1100, 1200, 1300, 2000, 2100, 2200, 2300),
    stringsAsFactors = FALSE
  )
  sessions <- ledgr_facts_sessions(data.frame(session_date = as.Date(pulses), status = "open",
    session_open = "09:30:00", session_close = "16:00:00", knowledge_time = pulses - 86400,
    stringsAsFactors = FALSE), venue_id = "XNYS")
  snapshot <- ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
    facts = ledgr_facts(sessions), price_basis = "split_adjusted", db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  packets <- list()
  packet <- ledgr:::ledgr_carrier_packet
  testthat::local_mocked_bindings(
    ledgr_carrier_packet = function(x, group, n_run) {
      if (identical(group, "execution_packet") && isTRUE(x$has_next)) packets[[length(packets) + 1L]] <<- x
      packet(x, group, n_run)
    },
    .package = "ledgr"
  )
  exp <- ledgr_experiment(snapshot, function(ctx, params) {
    target <- ctx$hold()
    target[["BBB"]] <- 1
    target
  }, cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000))
  close(ledgr_run(exp, run_id = "fill-model-packet", seed = 1L))
  testthat::expect_length(packets, 3L)
  fields <- c("open", "high", "low", "close", "volume")
  projected <- function(p) {
    next_day <- bars[as.Date(bars$ts_utc) == as.Date(.POSIXct(p$exec_ts, tz = "UTC")), ]
    all(vapply(fields, function(f) identical(p[[f]], next_day[[f]][match(c("AAA", "BBB"), next_day$instrument_id)]), logical(1)))
  }
  testthat::expect_true(all(vapply(packets, projected, logical(1))))
  # Controls: a corrupted instrument mapping and each corrupted bar field.
  swapped <- packets[[1L]]
  for (f in fields) swapped[[f]] <- rev(swapped[[f]])
  testthat::expect_false(projected(swapped))
  for (f in fields) {
    bad <- packets[[1L]]
    bad[[f]][[2L]] <- bad[[f]][[2L]] + 1
    testthat::expect_false(projected(bad), info = f)
  }
})

# LDG-3166 correction round 1 (ws13_checkpoint_review.md F5): the registered
# witnesses of the former proposal tests keep their original values, side,
# quantity and instrument at the boundaries that now carry them.

# A three-session snapshot where AAA's second session is `next_bar`; BBB has
# distinct values so a crossed instrument mapping is visible.
ledgr_test_next_bar_snapshot <- function(next_bar, avail) {
  pulses <- as.POSIXct("2024-01-01 16:00:00", tz = "UTC") + 86400 * 0:2
  aaa <- data.frame(ts_utc = pulses, instrument_id = "AAA", open = c(100, next_bar$open, 100),
    high = c(100.5, next_bar$high, 100.5), low = c(99.5, next_bar$low, 99.5),
    close = c(100, next_bar$close, 100), volume = c(500, next_bar$volume, 500))
  bbb <- data.frame(ts_utc = pulses, instrument_id = "BBB", open = 50, high = 51, low = 49, close = 50.5, volume = 700)
  bars <- rbind(aaa, bbb)
  if (!avail) return(ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb")))
  sessions <- ledgr_facts_sessions(data.frame(session_date = as.Date(pulses), status = "open",
    session_open = "09:30:00", session_close = "16:00:00", knowledge_time = pulses - 86400,
    stringsAsFactors = FALSE), venue_id = "XNYS")
  ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
    facts = ledgr_facts(sessions), price_basis = "split_adjusted", db_path = tempfile(fileext = ".duckdb"))
}
ledgr_test_first_day <- function(target) {
  force(target)
  function(ctx, params) {
    t <- ctx$hold()
    if (substr(ctx$ts_utc, 1L, 10L) == "2024-01-01") t[names(target)] <- target
    t
  }
}

testthat::test_that("next-open proposal and public cost resolver preserve fill intents", {
  # Original inputs: BUY 10 of AAA at a next bar 100/101/99/100.5/100000,
  # spread 7 and fixed fee 1.25. The bar is the availability execution
  # packet's run-axis next bar (typed boundary); the fill is P3's typed row.
  bar <- list(open = 100, high = 101, low = 99, close = 100.5, volume = 100000)
  snapshot <- ledgr_test_next_bar_snapshot(bar, avail = TRUE)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  seen <- new.env()
  packet <- ledgr:::ledgr_carrier_packet
  plan <- ledgr:::ledgr_fold_stage_plan
  testthat::local_mocked_bindings(
    ledgr_carrier_packet = function(x, group, n_run) {
      if (identical(group, "execution_packet") && is.null(seen$packet)) seen$packet <- x
      packet(x, group, n_run)
    },
    ledgr_fold_stage_plan = function(fold_state, services, ...) {
      out <- plan(fold_state, services, ...)
      if (is.null(seen$fill) && length(out$batch$fill$k)) {
        seen$fill <- out$batch$fill
        seen$ids <- services$instrument_ids
      }
      out
    },
    .package = "ledgr"
  )
  exp <- ledgr_experiment(snapshot, ledgr_test_first_day(c(AAA = 10)), opening = ledgr_opening(cash = 1e4),
    cost_model = ledgr_cost_chain(ledgr_cost_spread_bps(7), ledgr_cost_fixed_fee(1.25)))
  close(ledgr_run(exp, run_id = "fill-model-proposal-witness", seed = 1L))
  fill <- seen$fill
  fields <- c("open", "high", "low", "close", "volume")
  projected <- function(p, ids) {
    at <- match("AAA", ids)
    all(vapply(fields, function(f) identical(p[[f]][[at]], bar[[f]]), logical(1)))
  }
  testthat::expect_identical(seen$ids[fill$pos], "AAA")
  testthat::expect_identical(fill$side, 1L)
  testthat::expect_equal(fill$qty, 10)
  testthat::expect_true(projected(seen$packet, seen$ids))
  testthat::expect_equal(seen$packet$volume[[match("AAA", seen$ids)]], 100000)
  # Through the boundary equals the one-row batch at the same bar.
  legacy <- ledgr_test_next_open_fill(
    desired_qty_delta = 10,
    next_bar = list(instrument_id = "AAA", ts_utc = .POSIXct(fill$exec_ts, tz = "UTC"), open = 100),
    spread_bps = 7,
    commission_fixed = 1.25
  )
  for (f in c("side", "qty", "price", "fee", "cash_delta", "position_delta", "exec_ts")) {
    testthat::expect_identical(fill[[f]], legacy$fill[[f]], info = f)
  }
  # Controls: a crossed instrument mapping and each corrupted bar field.
  testthat::expect_false(projected(seen$packet, rev(seen$ids)))
  for (f in fields) {
    bad <- seen$packet
    bad[[f]][[match("AAA", seen$ids)]] <- bad[[f]][[match("AAA", seen$ids)]] + 1
    testthat::expect_false(projected(bad, seen$ids), info = f)
  }
})

testthat::test_that("next-open planning consumes the prepared execution open", {
  # Buy 5 of AAA at the next prepared open. The canonical
  # planner receives only the execution field it owns rather than a second
  # matrix-backed bar view.
  bar <- list(open = 101, high = 102, low = 99, close = 100.5, volume = 100000)
  snapshot <- ledgr_test_next_bar_snapshot(bar, avail = FALSE)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  seen <- new.env()
  build <- ledgr:::ledgr_fold_build_availability_pulse_plan
  plan <- ledgr:::ledgr_fold_stage_plan
  testthat::local_mocked_bindings(
    ledgr_fold_stage_plan = function(fold_state, services, ...) {
      seen$ids <- services$instrument_ids
      plan(fold_state, services, ...)
    },
    ledgr_fold_build_availability_pulse_plan = function(context_pos, target_qty, position, actionable_k,
                                                        member, execution, execution_view, epoch_valid,
                                                        cost_resolver, cash, instrument_ids) {
      out <- build(context_pos, target_qty, position, actionable_k, member, execution,
        execution_view, epoch_valid, cost_resolver, cash, instrument_ids)
      if (is.null(seen$fill) && length(out$fill$k)) {
        seen$fill <- out$fill
        seen$open <- execution$open
      }
      out
    },
    .package = "ledgr"
  )
  exp <- ledgr_experiment(snapshot, ledgr_test_first_day(c(AAA = 5)), opening = ledgr_opening(cash = 1e4),
    cost_model = ledgr_cost_zero())
  bt <- ledgr_run(exp, run_id = "fill-model-matrix-witness", seed = 1L)
  ids <- ledgr_results(bt, "ledger")$instrument_id
  close(bt)
  fill <- seen$fill
  aaa <- match("AAA", seen$ids)
  testthat::expect_identical(ids, "AAA")
  testthat::expect_identical(fill$pos, aaa)
  testthat::expect_identical(fill$side, 1L)
  testthat::expect_equal(fill$qty, 5)
  testthat::expect_equal(fill$price, 101)
  testthat::expect_equal(seen$open[[fill$pos]], bar$open)
})

testthat::test_that("the canonical planner maps each prepared next open by run position", {
  # Category 5: instrument, side, quantity and next open are the typed row's
  # pos, side, qty and price.
  open <- rbind(AAA = c(100, 101), BBB = c(200, 99))
  plan <- ledgr_test_dense_plan(open, c(5, 3), context_pos = c(2L, 1L))
  fill <- plan$fill
  testthat::expect_identical(fill$pos, c(2L, 1L))
  testthat::expect_identical(fill$side, c(1L, 1L))
  testthat::expect_identical(fill$qty, c(5, 3))
  testthat::expect_identical(fill$price, c(99, 101))
  # Controls: a corrupted instrument mapping and a corrupted next open.
  testthat::expect_false(identical(ledgr_test_dense_plan(open, c(5, 3), context_pos = 1:2)$fill$price, fill$price))
  corrupt <- open
  corrupt[2L, 2L] <- 98
  testthat::expect_false(identical(ledgr_test_dense_plan(corrupt, c(5, 3), context_pos = c(2L, 1L))$fill$price, fill$price))
})

testthat::test_that("BUY/SELL spread adjustment is symmetric and spread=0 yields open", {
  bar <- list(
    instrument_id = "AAA",
    ts_utc = "2020-01-02T00:00:00Z",
    open = 100
  )

  buy <- ledgr_test_next_open_fill(
    desired_qty_delta = 1,
    next_bar = bar,
    spread_bps = 10,
    commission_fixed = 0
  )
  sell <- ledgr_test_next_open_fill(
    desired_qty_delta = -1,
    next_bar = bar,
    spread_bps = 10,
    commission_fixed = 0
  )

  testthat::expect_equal(buy$fill$price, 100 * (1 + 10 / 20000))
  testthat::expect_equal(sell$fill$price, 100 * (1 - 10 / 20000))

  buy0 <- ledgr_test_next_open_fill(
    desired_qty_delta = 1,
    next_bar = bar,
    spread_bps = 0,
    commission_fixed = 0
  )
  sell0 <- ledgr_test_next_open_fill(
    desired_qty_delta = -1,
    next_bar = bar,
    spread_bps = 0,
    commission_fixed = 0
  )

  testthat::expect_equal(buy0$fill$price, 100)
  testthat::expect_equal(sell0$fill$price, 100)
})

testthat::test_that("fee is included and must be non-negative", {
  bar <- list(
    instrument_id = "AAA",
    ts_utc = "2020-01-02T00:00:00Z",
    open = 100
  )

  fill <- ledgr_test_next_open_fill(
    desired_qty_delta = 1,
    next_bar = bar,
    spread_bps = 0,
    commission_fixed = 2.5
  )
  testthat::expect_equal(fill$fill$fee, 2.5)

  testthat::expect_error(
    ledgr_test_next_open_fill(
      desired_qty_delta = 1,
      next_bar = bar,
      spread_bps = 0,
      commission_fixed = -0.1
    ),
    class = "ledgr_invalid_cost_model"
  )
})

testthat::test_that("[LTB-0002] last-bar policy returns a structured NO_FILL with WARN code", {
  # Category 4: the has_next = FALSE path plans no fill and rejects the row
  # with the structured final-pulse reason.
  open <- matrix(100, 1L, 1L)
  plan <- ledgr_test_dense_plan(open, 1, has_next = FALSE)
  testthat::expect_length(plan$fill$k, 0L)
  testthat::expect_identical(plan$economic_event_kinds, integer())
  testthat::expect_identical(ledgr:::.ledgr_plan_reason_levels[plan$rejection$primary], "final_pulse_no_execution")
})

testthat::test_that("invalid inputs fail loud", {
  bar <- list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = 100)

  # The registered witnesses, unchanged: the production next-open input
  # refusals (ledgr_plan_refuse_inputs) through the one-row batch helper.
  testthat::expect_error(
    ledgr_test_next_open_fill(desired_qty_delta = Inf, next_bar = bar, spread_bps = 0, commission_fixed = 0),
    "desired_qty_delta",
    fixed = TRUE
  )

  testthat::expect_error(
    ledgr_test_next_open_fill(desired_qty_delta = 1, next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = NaN), spread_bps = 0, commission_fixed = 0),
    "next_bar$open",
    fixed = TRUE
  )

  testthat::expect_error(
    ledgr_test_next_open_fill(desired_qty_delta = 1, next_bar = bar, spread_bps = -1, commission_fixed = 0),
    class = "ledgr_invalid_cost_model"
  )

  # The canonical planner classifies an absent prepared execution price as a
  # typed row rejection rather than accepting a non-finite fill.
  missing_open <- ledgr_test_dense_plan(matrix(c(100, NaN), 1L, 2L), 1)
  testthat::expect_identical(
    ledgr:::.ledgr_plan_reason_levels[missing_open$rejection$primary],
    "execution_bar_missing"
  )
})
