# LDG-3166 (design note Section 5, decision 10): the next-open fill model is
# the typed plan batch. Each block keeps its original inputs and values; the
# proposal, fill-context and fill-intent object shapes retire with the
# objects (Synthesis 3.3).

# The dense planner on one decision pulse: `open` is the next-open matrix
# (instruments by pulses), `delta` the context targets from flat positions.
ledgr_test_dense_plan <- function(open,
                                  delta,
                                  context_pos = seq_along(delta),
                                  has_next = TRUE,
                                  exec_ts = 1577923200,
                                  epoch_valid = TRUE,
                                  resolver = ledgr_test_cost_resolver()) {
  ledgr:::ledgr_fold_build_pulse_plan(
    context_pos = as.integer(context_pos),
    target_qty = as.numeric(delta),
    position = numeric(length(delta)),
    actionable_k = seq_along(delta),
    pulse_idx = 1L,
    has_next = has_next,
    exec_ts = if (has_next) exec_ts else NA_real_,
    epoch_valid = epoch_valid,
    bars_mat = list(open = open),
    cost_resolver = resolver,
    n_run = nrow(open)
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
  row <- ledgr:::ledgr_fill_event_row("run-1", f$fill, f$i, f$instrument_id, 1L)$row
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

testthat::test_that("the dense planner reads the next open of each row's run position", {
  # Category 5: the matrix-backed context's instrument, side, quantity and
  # next open are the typed row's pos, side, qty and price.
  open <- rbind(AAA = c(100, 101), BBB = c(200, 99))
  plan <- ledgr_test_dense_plan(open, c(-5, 3), context_pos = c(2L, 1L))
  fill <- plan$fill
  testthat::expect_identical(fill$pos, c(2L, 1L))
  testthat::expect_identical(fill$side, c(-1L, 1L))
  testthat::expect_identical(fill$qty, c(5, 3))
  testthat::expect_identical(fill$price, c(99, 101))
  # Controls: a corrupted instrument mapping and a corrupted next open.
  testthat::expect_false(identical(ledgr_test_dense_plan(open, c(-5, 3), context_pos = 1:2)$fill$price, fill$price))
  corrupt <- open
  corrupt[2L, 2L] <- 98
  testthat::expect_false(identical(ledgr_test_dense_plan(corrupt, c(-5, 3), context_pos = c(2L, 1L))$fill$price, fill$price))
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
  # Category 4: the has_next = FALSE path plans no fill, rejects the row for
  # the missing opportunity and warns once per target.
  open <- matrix(100, 1L, 1L)
  testthat::expect_warning(
    plan <- ledgr_test_dense_plan(open, 1, has_next = FALSE),
    "LEDGR_LAST_BAR_NO_FILL",
    fixed = TRUE
  )
  testthat::expect_length(plan$fill$k, 0L)
  testthat::expect_identical(plan$economic_event_kinds, integer())
  testthat::expect_identical(ledgr:::.ledgr_plan_reason_levels[plan$rejection$primary], "final_pulse_no_execution")
})

testthat::test_that("invalid inputs fail loud", {
  bar <- list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = 100)

  # Category 4: the typed fill group refuses a non-finite quantity; the dense
  # planner refuses a missing next open with the next-open price message.
  testthat::expect_error(
    ledgr_test_next_open_fill(desired_qty_delta = Inf, next_bar = bar, spread_bps = 0, commission_fixed = 0),
    class = "ledgr_invalid_pulse_plan"
  )

  testthat::expect_error(
    ledgr_test_dense_plan(matrix(c(100, NaN), 1L, 2L), 1),
    "next_open_price",
    fixed = TRUE,
    class = "ledgr_invalid_fill_input"
  )

  testthat::expect_error(
    ledgr_test_next_open_fill(desired_qty_delta = 1, next_bar = bar, spread_bps = -1, commission_fixed = 0),
    class = "ledgr_invalid_cost_model"
  )
})
