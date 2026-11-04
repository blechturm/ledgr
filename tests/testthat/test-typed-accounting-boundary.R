# ledgr-test-file-profile: review

typed_accounting_row <- function(seq,
                                 type,
                                 instrument = "AAA",
                                 side = NA_character_,
                                 qty = NA_real_,
                                 price = NA_real_,
                                 fee = 0,
                                 cash_delta,
                                 position_delta,
                                 ...) {
  ledgr:::ledgr_accounting_rows(
    event_id = paste0("typed-", seq),
    run_id = "typed-accounting",
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + seq,
    event_type = type,
    instrument_id = instrument,
    side = side,
    qty = qty,
    price = price,
    fee = fee,
    event_seq = as.integer(seq),
    cash_delta = cash_delta,
    position_delta = position_delta,
    ...
  )
}

typed_accounting_opening <- function(seq = 1L, qty = 10, price = 100) {
  typed_accounting_row(
    seq, "CASHFLOW", qty = qty, price = price,
    cash_delta = 0, position_delta = qty, source = "opening_position"
  )
}

typed_accounting_disposition <- function(seq = 2L,
                                         source = "corporate_action_disposition",
                                         before = 10,
                                         price = 110,
                                         realized = 100,
                                         choice = "last_mark") {
  lifetime <- identical(source, "lifetime_terminal_disposition")
  typed_accounting_row(
    seq, "DISPOSITION", qty = abs(before), price = price,
    cash_delta = before * price, position_delta = -before,
    source = source, source_fact_id = paste0("fact-", seq),
    disposition_policy_id = paste0("policy-", seq),
    disposition_choice = choice,
    disposition_basis = if (lifetime) "label" else "evidence",
    mark_source = if (identical(choice, "write_off")) "write_off" else "current_close",
    mark_source_ts_utc = as.POSIXct("2020-01-01", tz = "UTC"),
    mark_age = 0L, position_before = before,
    realized_model_pnl = realized,
    affected_marked_exposure = abs(before * price),
    terminal_event = if (lifetime) "delisting" else NA_character_,
    matched_label = if (lifetime) "delisting" else NA_character_
  )
}

testthat::test_that("[LTB-0550] typed accounting carrier owns fields and block boundaries", {
  literal_columns <- c(
    "event_id", "run_id", "ts_utc", "event_type", "instrument_id",
    "side", "qty", "price", "fee", "event_seq", "cash_delta",
    "position_delta", "source", "source_fact_id", "entitled_quantity",
    "gross_cash_per_parent_unit", "amount_policy_id", "posting_policy_id",
    "late_arrival", "affected_marked_exposure", "terminal_event",
    "matched_label", "disposition_policy_id", "disposition_choice",
    "disposition_basis", "mark_source", "mark_source_ts_utc", "mark_age",
    "haircut_fraction", "position_before", "realized_model_pnl"
  )
  testthat::expect_identical(ledgr:::ledgr_experiment_store_schema_version, 125L)
  testthat::expect_identical(ledgr:::ledgr_accounting_event_columns(), literal_columns)
  ddl <- unname(
    ledgr:::ledgr_current_schema_definition()$tables[["ledger_events"]]
  )
  testthat::expect_no_match(ddl, "meta_json", fixed = TRUE)
  for (column in literal_columns) {
    testthat::expect_match(ddl, column, fixed = TRUE, info = column)
  }
  testthat::expect_match(ddl, "UNIQUE(run_id, event_seq)", fixed = TRUE)
  testthat::expect_match(
    ddl,
    "'opening_position', 'corporate_action_cash', 'corporate_action_disposition', 'lifetime_terminal_disposition'",
    fixed = TRUE
  )

  producer_names <- c(
    "ledgr_fill_event_payload", "ledgr_opening_position_event_rows",
    "ledgr_corporate_action_plan", "ledgr_disposition_post"
  )
  for (name in producer_names) {
    source <- paste(deparse(body(get(name, envir = asNamespace("ledgr")))), collapse = "\n")
    testthat::expect_match(source, "ledgr_accounting_rows", fixed = TRUE, info = name)
    testthat::expect_no_match(source, "meta_json", fixed = TRUE, info = name)
    testthat::expect_no_match(source, "canonical_json", fixed = TRUE, info = name)
    testthat::expect_no_match(source, "ledgr_json_read_nested", fixed = TRUE, info = name)
  }
  testthat::expect_false(exists(
    "ledgr_lot_parse_meta", envir = asNamespace("ledgr"), inherits = FALSE
  ))

  opening <- typed_accounting_opening()
  fill <- typed_accounting_row(
    2L, "FILL", side = "SELL", qty = 15, price = 120, fee = 5,
    cash_delta = 1795, position_delta = -15
  )
  cash <- typed_accounting_row(
    3L, "CASHFLOW",
    cash_delta = 50, position_delta = 0,
    source = "corporate_action_cash", source_fact_id = "cash-fact",
    entitled_quantity = 5, gross_cash_per_parent_unit = 10,
    amount_policy_id = "amount-policy", posting_policy_id = "posting-policy",
    late_arrival = FALSE, affected_marked_exposure = 600
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

  testthat::expect_false("subtype" %in% ledgr:::ledgr_accounting_event_columns())

  # A disposition after 100 cash rows retains every typed evidence field;
  # preparation has no schema probe or row-wise decoder.
  early_cash <- do.call(rbind, lapply(2:101, function(event_seq) {
    typed_accounting_row(
      event_seq,
      "CASHFLOW",
      cash_delta = 0, position_delta = 0,
      source = "corporate_action_cash",
      source_fact_id = paste0("early-cash-", event_seq),
      entitled_quantity = 0, gross_cash_per_parent_unit = 1,
      amount_policy_id = "amount-policy", posting_policy_id = "posting-policy",
      late_arrival = FALSE, affected_marked_exposure = 0
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
  bad_cash$cash_delta <- 49
  testthat::expect_error(
    ledgr:::ledgr_prepare_accounting_events(bad_cash),
    class = "ledgr_invalid_ledger_meta"
  )

  replace_field <- function(row, name, value) {
    row[[name]] <- value
    row
  }
  mutation_cases <- list(
    list(category = "required", row = replace_field(disposition, "disposition_policy_id", NA_character_)),
    list(category = "required", row = transform(disposition, qty = NA_real_)),
    list(category = "required", row = transform(disposition, price = NA_real_)),
    list(category = "null", row = replace_field(disposition, "entitled_quantity", 1)),
    list(category = "null", row = replace_field(disposition, "amount_policy_id", "not-applicable")),
    list(category = "null", row = replace_field(disposition, "late_arrival", FALSE)),
    list(category = "integral", row = replace_field(disposition, "mark_age", 1.5)),
    list(category = "non-negative", row = replace_field(disposition, "mark_age", -1)),
    list(category = "integral", row = transform(disposition, event_seq = 4.5)),
    list(category = "vocabulary", row = replace_field(disposition, "unexpected_key", "x")),
    list(category = "formula", row = replace_field(disposition, "cash_delta", 1099))
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
