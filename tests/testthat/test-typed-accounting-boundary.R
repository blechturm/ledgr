# ledgr-test-file-profile: review

typed_accounting_row <- function(seq,
                                 type,
                                 instrument = "AAA",
                                 side = NA_character_,
                                 qty = NA_real_,
                                 price = NA_real_,
                                 fee = 0,
                                 meta) {
  data.frame(
    event_id = paste0("typed-", seq),
    run_id = "typed-accounting",
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + seq,
    event_type = type,
    instrument_id = instrument,
    side = side,
    qty = qty,
    price = price,
    fee = fee,
    meta_json = canonical_json(meta),
    event_seq = as.integer(seq),
    stringsAsFactors = FALSE
  )
}

typed_accounting_opening <- function(seq = 1L, qty = 10, price = 100) {
  typed_accounting_row(
    seq, "CASHFLOW", qty = qty, price = price,
    meta = list(
      source = "opening_position", cash_delta = 0,
      position_delta = qty, cost_basis = price, opening_position = TRUE
    )
  )
}

typed_accounting_disposition <- function(seq = 2L,
                                         source = "corporate_action_disposition",
                                         before = 10,
                                         price = 110,
                                         realized = 100,
                                         choice = "last_mark") {
  lifetime <- identical(source, "lifetime_terminal_disposition")
  meta <- list(
    source = source,
    source_fact_id = paste0("fact-", seq),
    disposition_policy_id = paste0("policy-", seq),
    disposition_choice = choice,
    disposition_basis = if (lifetime) "label" else "evidence",
    mark_source = if (identical(choice, "write_off")) "write_off" else "current_close",
    mark_source_ts_utc = "2020-01-01T00:00:00Z",
    mark_age = 0L,
    quantity = abs(before),
    mark = price,
    position_before = before,
    position_after = 0,
    position_delta = -before,
    cash_delta = before * price,
    realized_model_pnl = realized,
    affected_marked_exposure = abs(before * price)
  )
  if (lifetime) {
    meta$terminal_event <- "delisting"
    meta$matched_label <- "delisting"
  }
  typed_accounting_row(
    seq, "DISPOSITION", qty = abs(before), price = price,
    meta = meta
  )
}

testthat::test_that("[LTB-0550] typed accounting carrier owns fields and block boundaries", {
  opening <- typed_accounting_opening()
  fill <- typed_accounting_row(
    2L, "FILL", side = "SELL", qty = 15, price = 120, fee = 5,
    meta = list(cash_delta = 1795, position_delta = -15)
  )
  cash <- typed_accounting_row(
    3L, "CASHFLOW",
    meta = list(
      source = "corporate_action_cash", source_fact_id = "cash-fact",
      cash_delta = 50, position_delta = 0, entitled_quantity = 5,
      gross_cash_per_parent_unit = 10, amount_policy_id = "amount-policy",
      posting_policy_id = "posting-policy", late_arrival = FALSE,
      affected_marked_exposure = 600
    )
  )
  disposition <- typed_accounting_disposition(
    4L,
    source = "lifetime_terminal_disposition",
    before = -5,
    price = 0,
    realized = 600,
    choice = "write_off"
  )
  rows <- rbind(opening, fill, cash, disposition)
  prepared <- ledgr:::ledgr_prepare_accounting_events(rows, "AAA")

  testthat::expect_false("meta" %in% names(prepared))
  testthat::expect_identical(prepared$operation, c(3L, 1L, 2L, 4L))
  testthat::expect_identical(prepared$source, c(
    "opening_position", NA_character_, "corporate_action_cash",
    "lifetime_terminal_disposition"
  ))
  testthat::expect_identical(prepared$source_fact_id, c(
    NA_character_, NA_character_, "cash-fact", "fact-4"
  ))
  testthat::expect_equal(prepared$cash_delta, c(0, 1795, 50, 0))
  testthat::expect_equal(prepared$position_delta, c(10, -15, 0, 5))
  testthat::expect_identical(prepared$terminal_event, c(
    NA_character_, NA_character_, NA_character_, "delisting"
  ))
  testthat::expect_equal(prepared$affected_marked_exposure, c(NA, NA, 600, 0))

  # A legacy non-disposition row may carry its own subtype. yyjsonr widens
  # that key to an all-missing column cell on the DISPOSITION row; the typed
  # matrix refuses only a subtype value on the disposition itself.
  cash_with_subtype <- cash
  cash_meta <- yyjsonr::read_json_str(cash_with_subtype$meta_json[[1L]])
  cash_meta$subtype <- "ordinary_cash_dividend"
  cash_with_subtype$meta_json[[1L]] <- canonical_json(cash_meta)
  testthat::expect_no_error(ledgr:::ledgr_prepare_accounting_events(
    rbind(opening, fill, cash_with_subtype, disposition),
    "AAA"
  ))

  # The first disposition may arrive after yyjsonr's default 100-row schema
  # probe. One bulk preparation must still retain every late evidence field.
  early_cash <- do.call(rbind, lapply(2:101, function(event_seq) {
    typed_accounting_row(
      event_seq,
      "CASHFLOW",
      meta = list(
        source = "corporate_action_cash",
        source_fact_id = paste0("early-cash-", event_seq),
        cash_delta = 0,
        position_delta = 0,
        entitled_quantity = 0,
        gross_cash_per_parent_unit = 1,
        amount_policy_id = "amount-policy",
        posting_policy_id = "posting-policy",
        late_arrival = FALSE,
        affected_marked_exposure = 0
      )
    )
  }))
  late_disposition <- typed_accounting_disposition(102L)
  late_prepared <- ledgr:::ledgr_prepare_accounting_events(
    rbind(typed_accounting_opening(1L), early_cash, late_disposition),
    "AAA"
  )
  testthat::expect_identical(late_prepared$qty[[102L]], 10)
  testthat::expect_identical(late_prepared$price[[102L]], 110)
  testthat::expect_identical(late_prepared$position_before[[102L]], 10)
  testthat::expect_identical(late_prepared$position_delta[[102L]], -10)
  testthat::expect_identical(late_prepared$realized_model_pnl[[102L]], 100)
  testthat::expect_identical(
    late_prepared$disposition_policy_id[[102L]],
    "policy-102"
  )

  replay <- ledgr:::ledgr_replay_accounting_events(prepared, initial_cash = 1000)
  testthat::expect_equal(replay$cash, 2845)
  testthat::expect_equal(unname(replay$positions[["AAA"]]), 0)
  testthat::expect_equal(replay$event_realized, c(0, 195, 195, 795))

  first <- ledgr:::ledgr_prepare_accounting_events(rows[1:2, ], "AAA")
  first_replay <- ledgr:::ledgr_replay_accounting_events(first, initial_cash = 1000)
  second <- ledgr:::ledgr_prepare_accounting_events(
    rows[3:4, ],
    first$instrument_ids,
    prior_event_seq = tail(first$event_seq, 1L),
    prior_ts_utc = tail(first$ts_utc, 1L)
  )
  second_replay <- ledgr:::ledgr_replay_accounting_events(
    second,
    initial_cash = first_replay$cash,
    initial_positions = first_replay$positions,
    lot_state = first_replay$lot_state
  )
  testthat::expect_equal(second_replay$cash, replay$cash)
  testthat::expect_equal(second_replay$positions, replay$positions)
  testthat::expect_equal(second_replay$lot_state$realized_pnl, replay$lot_state$realized_pnl)

  duplicate <- rows[3:4, ]
  duplicate$event_seq[[1L]] <- 2L
  testthat::expect_error(
    ledgr:::ledgr_prepare_accounting_events(
      duplicate,
      first$instrument_ids,
      prior_event_seq = 2L,
      prior_ts_utc = tail(first$ts_utc, 1L)
    ),
    class = "ledgr_invalid_accounting_event"
  )
  decreasing <- rows[3:4, ]
  decreasing$ts_utc[[1L]] <- first$ts_utc[[1L]]
  testthat::expect_error(
    ledgr:::ledgr_prepare_accounting_events(
      decreasing,
      first$instrument_ids,
      prior_event_seq = 2L,
      prior_ts_utc = tail(first$ts_utc, 1L)
    ),
    class = "ledgr_invalid_accounting_event"
  )

  scheduled_zero <- typed_accounting_disposition(price = 0, realized = -1000)
  testthat::expect_error(
    ledgr:::ledgr_prepare_accounting_events(scheduled_zero),
    class = "ledgr_invalid_ledger_meta"
  )
  bad_cash <- cash
  bad_cash$meta_json <- sub('"cash_delta":50', '"cash_delta":49', bad_cash$meta_json, fixed = TRUE)
  testthat::expect_error(
    ledgr:::ledgr_prepare_accounting_events(bad_cash),
    class = "ledgr_invalid_ledger_meta"
  )

  replace_meta <- function(row, name, value) {
    meta <- yyjsonr::read_json_str(row$meta_json[[1L]])
    meta[[name]] <- value
    row$meta_json[[1L]] <- canonical_json(meta)
    row
  }
  mutation_cases <- list(
    list(category = "required", row = replace_meta(disposition, "disposition_policy_id", NULL)),
    list(category = "required", row = transform(disposition, qty = NA_real_)),
    list(category = "required", row = transform(disposition, price = NA_real_)),
    list(category = "null", row = replace_meta(disposition, "entitled_quantity", 1)),
    list(category = "null", row = replace_meta(disposition, "amount_policy_id", "not-applicable")),
    list(category = "null", row = replace_meta(disposition, "late_arrival", FALSE)),
    list(category = "null", row = replace_meta(disposition, "cost_basis", 100)),
    list(category = "integral", row = replace_meta(disposition, "mark_age", 1.5)),
    list(category = "non-negative", row = replace_meta(disposition, "mark_age", -1)),
    list(category = "integral", row = transform(disposition, event_seq = 4.5)),
    list(category = "vocabulary", row = replace_meta(disposition, "unexpected_key", "x")),
    list(category = "formula", row = replace_meta(disposition, "cash_delta", 1099))
  )
  for (case in mutation_cases) {
    testthat::expect_error(
      ledgr:::ledgr_prepare_accounting_events(case$row),
      class = "ledgr_invalid_accounting_event",
      info = case$category
    )
  }

  handler <- ledgr:::ledgr_output_handler(
    ledgr:::ledgr_output_sink_memory("typed-accounting")
  )
  handler$init_buffers(4L)
  handler$append_event_rows(typed_accounting_opening(1L))
  duplicate_append <- typed_accounting_opening(1L)
  testthat::expect_error(
    handler$append_event_rows(duplicate_append),
    class = "ledgr_invalid_accounting_event"
  )
  decreasing_append <- typed_accounting_opening(2L)
  decreasing_append$ts_utc <- as.POSIXct("2019-12-31", tz = "UTC")
  testthat::expect_error(
    handler$append_event_rows(decreasing_append),
    class = "ledgr_invalid_accounting_event"
  )

  resumed <- ledgr:::ledgr_output_handler(
    ledgr:::ledgr_output_sink_memory("typed-accounting")
  )
  resumed$seed_event_boundary(8L, as.POSIXct("2020-01-08", tz = "UTC"))
  resumed$init_buffers(2L)
  stale_sequence <- typed_accounting_opening(8L)
  stale_sequence$ts_utc <- as.POSIXct("2020-01-09", tz = "UTC")
  testthat::expect_error(
    resumed$append_event_rows(stale_sequence),
    class = "ledgr_invalid_accounting_event"
  )
  stale_time <- typed_accounting_opening(9L)
  stale_time$ts_utc <- as.POSIXct("2020-01-07", tz = "UTC")
  testthat::expect_error(
    resumed$append_event_rows(stale_time),
    class = "ledgr_invalid_accounting_event"
  )

  live_sink <- ledgr:::ledgr_output_sink_memory("typed-accounting")
  live_sink$serialize_meta_json <- TRUE
  live_sink$write_fill_live <- function(...) {
    structure(list(status = "WROTE"), class = "ledgr_ledger_write_result")
  }
  live <- ledgr:::ledgr_output_handler(live_sink)
  invalid_live_fill <- list(
    side = 1L, qty = 1, price = 100, fee = 0,
    cash_delta = -99, position_delta = 1,
    exec_ts = as.numeric(as.POSIXct("2020-01-02", tz = "UTC"))
  )
  testthat::expect_error(
    live$write_fill_events(
      invalid_live_fill, 1L, "AAA", 1L,
      use_transaction = TRUE, stage = TRUE
    ),
    class = "ledgr_invalid_accounting_event"
  )
})
