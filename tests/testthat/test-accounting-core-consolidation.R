ledgr_accounting_test_meta <- function(...) {
  as.character(canonical_json(list(...)))
}

ledgr_accounting_test_events <- function() {
  data.frame(
    event_id = paste0("accounting-", 1:4),
    run_id = rep("accounting-core", 4),
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 0:3,
    event_type = c("CASHFLOW", "FILL", "FILL", "CASHFLOW"),
    instrument_id = rep("AAA", 4),
    side = c(NA_character_, "SELL", "BUY", NA_character_),
    qty = c(10, 15, 5, NA_real_),
    price = c(100, 120, 110, NA_real_),
    fee = c(0, 5, 1, 0),
    meta_json = c(
      ledgr_accounting_test_meta(
        source = "opening_position", cash_delta = 0,
        position_delta = 10, cost_basis = 100
      ),
      ledgr_accounting_test_meta(cash_delta = 1795, position_delta = -15),
      ledgr_accounting_test_meta(cash_delta = -551, position_delta = 5),
      ledgr_accounting_test_meta(
        source = "corporate_action_cash", source_fact_id = "fact-cash-1",
        cash_delta = 500, position_delta = 0, entitled_quantity = 10,
        gross_cash_per_parent_unit = 50, amount_policy_id = "cash_amount.v002",
        posting_policy_id = "cash_posting.v002", late_arrival = FALSE,
        affected_marked_exposure = 0
      )
    ),
    event_seq = 1:4,
    stringsAsFactors = FALSE
  )
}

# LDG-3164 (decision 10, category 2): the same FIFO witnesses on the typed
# book. AAA is book position 1; live lots and aggregates are read from the
# book instead of the removed named-list container.
ledgr_test_book_lots <- function(book, pos = 1L) {
  live <- ledgr:::ledgr_lot_book_live(book, pos)
  list(qty = live$qty, price = live$price)
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0019] flat lot carrier preserves independent FIFO arithmetic", {
  state <- ledgr:::ledgr_lot_book(1L)
  state <- ledgr:::ledgr_lot_opening(state, 1L, 10, 100)$book
  first <- ledgr:::ledgr_lot_fill(state, 1L, -1L, 15, 120, 5)
  state <- first$book
  testthat::expect_equal(first$applied$realized_close, 200)
  testthat::expect_equal(state$realized_pnl, 195)
  testthat::expect_equal(state$net_by_inst[[1L]], -5)
  testthat::expect_equal(state$total_cost_basis, -600)
  testthat::expect_equal(
    ledgr_test_book_lots(state),
    list(qty = -5, price = 120)
  )

  second <- ledgr:::ledgr_lot_fill(state, 1L, 1L, 2, 110, 1)
  state <- second$book
  testthat::expect_equal(second$applied$realized_close, 20)
  testthat::expect_equal(state$realized_pnl, 214)
  testthat::expect_equal(state$net_by_inst[[1L]], -3)
  testthat::expect_equal(state$total_cost_basis, -360)

  state <- ledgr:::ledgr_lot_fill(state, 1L, 1L, 3, 130, 0)$book
  testthat::expect_equal(state$realized_pnl, 184)
  testthat::expect_equal(state$total_cost_basis, 0)
  testthat::expect_equal(state$net_by_inst[[1L]], 0)
  testthat::expect_identical(ledgr:::ledgr_lot_book_live_count(state, 1L), 0L)

  deep <- ledgr:::ledgr_lot_book(1L)
  buy_prices <- seq_len(512) + 100
  for (price in buy_prices) {
    deep <- ledgr:::ledgr_lot_fill(deep, 1L, 1L, 1, price, 0)$book
  }
  for (i in seq_along(buy_prices)) {
    deep <- ledgr:::ledgr_lot_fill(deep, 1L, -1L, 1, 1000, 0)$book
  }
  testthat::expect_equal(deep$realized_pnl, sum(1000 - buy_prices))
  testthat::expect_equal(deep$total_cost_basis, 0)
  testthat::expect_identical(ledgr:::ledgr_lot_book_live_count(deep, 1L), 0L)
  testthat::expect_false(any(c("cash", "positions") %in% names(deep)))

  # Fractional multi-lot reversal: the lot segment, rather than a separately
  # accumulated scalar, is authoritative for how much of a fill closes.
  fractional <- ledgr:::ledgr_lot_book(1L)
  fractional_side <- c(rep("SELL", 4), rep("BUY", 2), "SELL")
  fractional_qty <- c(2.117, 0.129, 0.520, 2.254, 4.151, 1.016, 0.500)
  fractional_price <- c(54.45, 28.01, 29.28, 47.48, 40.96, 16.13, 20)
  for (i in seq_along(fractional_qty)) {
    fractional <- ledgr:::ledgr_lot_fill(
      fractional,
      1L,
      ledgr:::ledgr_lot_side(fractional_side[[i]]),
      fractional_qty[[i]],
      fractional_price[[i]],
      0
    )$book
    live <- ledgr_test_book_lots(fractional)$qty
    testthat::expect_lte(
      abs(fractional$net_by_inst[[1L]] - sum(live)),
      4 * ledgr:::ledgr_lot_dust_tolerance(
        fractional$net_by_inst[[1L]], live
      )
    )
    testthat::expect_lte(length(unique(sign(live))), 1L)
  }
  testthat::expect_equal(fractional$realized_pnl, 57.65642, tolerance = 1e-12)
  testthat::expect_equal(fractional$total_cost_basis, -7.06, tolerance = 1e-12)
  testthat::expect_equal(
    ledgr_test_book_lots(fractional),
    list(qty = -0.353, price = 20),
    tolerance = 1e-12
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0020] one preparer gives memory and table sources one block", {
  table_rows <- ledgr_accounting_test_events()
  memory_rows <- table_rows
  meta <- lapply(table_rows$meta_json, ledgr:::ledgr_json_read_nested)
  attr(memory_rows, "ledgr_event_cash_delta") <- vapply(meta, `[[`, numeric(1), "cash_delta")
  attr(memory_rows, "ledgr_event_position_delta") <- vapply(meta, `[[`, numeric(1), "position_delta")
  attr(memory_rows, "ledgr_event_meta") <- rep(list(list(wrong = TRUE)), nrow(memory_rows))
  attr(memory_rows, "ledgr_event_realized") <- rep(999, nrow(memory_rows))
  attr(memory_rows, "ledgr_event_cost_basis") <- rep(999, nrow(memory_rows))

  testthat::expect_identical(
    ledgr:::ledgr_prepare_accounting_events(memory_rows, "AAA"),
    ledgr:::ledgr_prepare_accounting_events(table_rows, "AAA")
  )

  bad <- table_rows[2, , drop = FALSE]
  bad$event_type <- "FEE"
  testthat::expect_error(
    ledgr:::ledgr_prepare_accounting_events(bad),
    class = "ledgr_invalid_accounting_event"
  )
  bad <- table_rows[2, , drop = FALSE]
  bad$side <- "SHORT"
  testthat::expect_error(
    ledgr:::ledgr_prepare_accounting_events(bad),
    class = "ledgr_invalid_accounting_event"
  )
  for (field in c("qty", "price", "fee")) {
    bad <- table_rows[2, , drop = FALSE]
    bad[[field]] <- if (identical(field, "fee")) -1 else 0
    testthat::expect_error(
      ledgr:::ledgr_prepare_accounting_events(bad),
      class = "ledgr_invalid_accounting_event"
    )
  }
  bad <- table_rows[1, , drop = FALSE]
  bad$meta_json <- ledgr_accounting_test_meta(
    source = "opening_position", cash_delta = 0, position_delta = 1
  )
  testthat::expect_error(
    ledgr:::ledgr_prepare_accounting_events(bad),
    class = "ledgr_invalid_ledger_meta"
  )
  for (opening_basis in c(0, -5)) {
    valid <- table_rows[1, , drop = FALSE]
    valid$qty <- 1
    valid$price <- opening_basis
    valid$meta_json <- ledgr_accounting_test_meta(
      source = "opening_position", cash_delta = 0,
      position_delta = 1, cost_basis = opening_basis
    )
    testthat::expect_identical(
      ledgr:::ledgr_prepare_accounting_events(valid)$operation,
      3L
    )
  }
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("[LTB-0021] chunked reader is identical across its fetch boundary", {
  test_con <- get_test_connection()
  on.exit(close_test_connection(test_con), add = TRUE)
  n <- 50002L
  event_seq <- seq_len(n)
  side_cycle <- c("BUY", "BUY", "BUY", "SELL", "SELL", "SELL")
  sides <- rep(side_cycle, length.out = n)
  prices <- 100 + event_seq * 1e-6
  rows <- data.frame(
    event_id = sprintf("ev_chunk_%05d", event_seq),
    run_id = "run_accounting_chunk_boundary",
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + event_seq,
    event_type = "FILL",
    instrument_id = "AAA",
    side = sides,
    qty = 1,
    price = prices,
    fee = 0,
    meta_json = NA_character_,
    event_seq = event_seq,
    stringsAsFactors = FALSE
  )
  DBI::dbAppendTable(test_con$con, "ledger_events", rows)
  bt <- ledgr:::new_ledgr_backtest(
    run_id = "run_accounting_chunk_boundary",
    db_path = test_con$db_path,
    config = list(data = list(snapshot_id = "snap_accounting_chunk_boundary"))
  )

  chunked <- ledgr_run_fills(bt)
  whole_replay <- ledgr:::ledgr_replay_accounting_events(
    ledgr:::ledgr_prepare_accounting_events(rows, "AAA")
  )
  whole <- ledgr:::ledgr_accounting_fills_from_replay(
    whole_replay,
    as.POSIXct(character(), tz = "UTC")
  )

  replay_columns <- setdiff(names(chunked), "recording_pulse_ts_utc")
  testthat::expect_identical(
    chunked[, replay_columns, drop = FALSE],
    whole[, replay_columns, drop = FALSE]
  )
  testthat::expect_true(all(is.na(chunked$recording_pulse_ts_utc)))
  testthat::expect_identical(nrow(chunked), n)
  testthat::expect_identical(chunked$event_seq, event_seq)
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0022] depth scaling detector rejects a write-path rescan", {
  # A per-call timing slope is a normal-runtime invariant: covr's counters add
  # depth-independent cost to the instrumented kernel calls only, which
  # flattens the mutant's slope, so it is skipped under coverage only.
  testthat::skip_on_covr()
  depths <- c(25L, 100L, 400L, 800L)
  noise_allowance <- 0.30
  calls_per_depth <- 1500L
  # LDG-3164 (decision 10, category 5): the kernel and its rescan mutant are
  # rebuilt on the typed book; the measured object moved, the thresholds
  # did not.
  measure <- function(kernel) {
    vapply(depths, function(depth) {
      seed <- ledgr:::ledgr_lot_book(1L)
      for (i in seq_len(depth)) seed <- production(seed, "BUY", i)$book
      elapsed <- replicate(3L, {
        unname(system.time({
          for (i in seq_len(calls_per_depth)) kernel(seed, "SELL", i)
        })[["elapsed"]]) / calls_per_depth
      })
      median(elapsed)
    }, numeric(1))
  }
  production <- function(state, side, i) {
    ledgr:::ledgr_lot_fill(
      state, 1L, ledgr:::ledgr_lot_side(side), 1,
      if (identical(side, "BUY")) 100 + i / 1000 else 200 + i / 1000,
      0
    )
  }
  mutated <- function(state, side, i) {
    out <- production(state, side, i)
    values <- ledgr_test_book_lots(out$book)
    attr(out, "mutated_scan") <- sum(vapply(
      seq_along(values$qty),
      function(j) values$qty[[j]] * values$price[[j]],
      numeric(1)
    ))
    out
  }
  depth_slope <- function(cost) {
    unname(stats::coef(stats::lm(log(pmax(cost, 1e-9)) ~ log(depths)))[[2L]])
  }

  production_cost <- measure(production)
  mutant_cost <- measure(mutated)
  testthat::expect_lte(depth_slope(production_cost), noise_allowance)
  testthat::expect_gt(depth_slope(mutant_cost), noise_allowance)
})
