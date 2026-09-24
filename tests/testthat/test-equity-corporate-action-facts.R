equity_corporate_action_rows <- function() {
  data.frame(
    fact_id = c("fictional_cash_1", "fictional_spin_1"),
    subtype = c("ordinary_cash_dividend", "spin_off"),
    parent_instrument_id = c("PARENT", "PARENT"),
    entitlement_time = as.POSIXct(
      c("2020-01-02 16:00:00", "2020-01-03 16:00:00"),
      tz = "UTC"
    ),
    effective_time = as.POSIXct(
      c("2020-01-02 16:00:00", "2020-01-03 16:00:00"),
      tz = "UTC"
    ),
    knowledge_time = as.POSIXct(
      c("2020-01-01 12:00:00", "2020-01-02 12:00:00"),
      tz = "UTC"
    ),
    payment_time = as.POSIXct(c(NA, NA), origin = "1970-01-01", tz = "UTC"),
    complete = c(TRUE, FALSE),
    refusal_reason = c(NA, "recipient_quantity_unavailable"),
    provenance_tier = c("snapshot_bound", "upstream_vintage_bound"),
    upstream_build_id = c(NA, "fictional_build_1"),
    bar_vintage_id = c(NA, "fictional_bars_1"),
    gross_cash_per_parent_unit = c(1.25, NA),
    gross_cash_validated = c(TRUE, FALSE),
    recipient_instrument_id = c(NA, "CHILD"),
    recipient_identity_validated = c(FALSE, TRUE),
    recipient_quantity_per_parent_unit = c(NA, NA),
    recipient_quantity_validated = c(FALSE, FALSE),
    source = "fictional_adapter",
    stringsAsFactors = FALSE
  )
}

equity_corporate_action_bars <- function() {
  data.frame(
    instrument_id = rep(c("CHILD", "PARENT"), each = 2L),
    ts_utc = rep(
      as.POSIXct(c("2020-01-02 16:00:00", "2020-01-03 16:00:00"), tz = "UTC"),
      2L
    ),
    open = c(20, 21, 100, 101),
    high = c(21, 22, 101, 102),
    low = c(19, 20, 99, 100),
    close = c(20, 21, 100, 101),
    volume = 100,
    stringsAsFactors = FALSE
  )
}

testthat::test_that("[LTB-0027] corporate-action facts validate each sealed field", {
  rows <- equity_corporate_action_rows()
  family <- ledgr_facts_equity_corporate_actions(rows)

  testthat::expect_s3_class(family, "ledgr_facts_equity_corporate_actions")
  testthat::expect_identical(family$family, "equity_corporate_actions")
  testthat::expect_identical(family$scope_id, "equity")
  testthat::expect_true(is.na(family$rows$payment_time[[1L]]))
  testthat::expect_identical(
    family$rows$recipient_instrument_id[[2L]],
    "CHILD"
  )
  testthat::expect_true(is.na(
    family$rows$recipient_quantity_per_parent_unit[[2L]]
  ))

  unvalidated <- rows
  unvalidated$gross_cash_validated[[1L]] <- FALSE
  testthat::expect_error(
    ledgr_facts_equity_corporate_actions(unvalidated),
    class = "ledgr_fact_unvalidated_term"
  )
  unvalidated <- rows
  unvalidated$recipient_identity_validated[[2L]] <- FALSE
  testthat::expect_error(
    ledgr_facts_equity_corporate_actions(unvalidated),
    class = "ledgr_fact_unvalidated_term"
  )
  unvalidated <- rows
  unvalidated$recipient_quantity_per_parent_unit[[2L]] <- 0.5
  testthat::expect_error(
    ledgr_facts_equity_corporate_actions(unvalidated),
    class = "ledgr_fact_unvalidated_term"
  )

  invalid_state <- rows
  invalid_state$refusal_reason[[2L]] <- NA
  testthat::expect_error(
    ledgr_facts_equity_corporate_actions(invalid_state),
    class = "ledgr_fact_invalid_completeness"
  )
  invalid_state <- rows
  invalid_state$refusal_reason[[1L]] <- "not_actually_complete"
  testthat::expect_error(
    ledgr_facts_equity_corporate_actions(invalid_state),
    class = "ledgr_fact_invalid_completeness"
  )

  invalid_tier <- rows
  invalid_tier$upstream_build_id[[1L]] <- "unexpected_build"
  testthat::expect_error(
    ledgr_facts_equity_corporate_actions(invalid_tier),
    class = "ledgr_fact_invalid_provenance_tier"
  )
  invalid_tier <- rows
  invalid_tier$bar_vintage_id[[2L]] <- NA
  testthat::expect_error(
    ledgr_facts_equity_corporate_actions(invalid_tier),
    class = "ledgr_fact_invalid_provenance_tier"
  )
  invalid_tier <- rows
  invalid_tier$upstream_build_id[[2L]] <- NA
  testthat::expect_error(
    ledgr_facts_equity_corporate_actions(invalid_tier),
    class = "ledgr_fact_invalid_provenance_tier"
  )
  invalid_tier <- rows
  invalid_tier$upstream_build_id[[2L]] <- NA
  invalid_tier$bar_vintage_id[[2L]] <- NA
  testthat::expect_error(
    ledgr_facts_equity_corporate_actions(invalid_tier),
    class = "ledgr_fact_invalid_provenance_tier"
  )

  invalid_clock <- rows
  invalid_clock$payment_time[[1L]] <- as.POSIXct(
    "2020-01-01 16:00:00",
    tz = "UTC"
  )
  testthat::expect_error(
    ledgr_facts_equity_corporate_actions(invalid_clock),
    class = "ledgr_fact_invalid_clock_order"
  )
})

testthat::test_that("[LTB-0028] corporate-action rows migrate, seal, and move identity", {
  bars <- equity_corporate_action_bars()
  facts <- ledgr_facts(
    ledgr_facts_equity_corporate_actions(equity_corporate_action_rows())
  )
  first <- ledgr_snapshot_from_df(bars, facts = facts)
  withr::defer(ledgr_snapshot_close(first))
  first_hash <- ledgr_snapshot_info(first)$snapshot_hash[[1L]]
  stored <- ledgr:::ledgr_snapshot_availability_read(
    ledgr:::get_connection(first),
    first$snapshot_id
  )$snapshot_equity_corporate_actions
  testthat::expect_identical(nrow(stored), 2L)
  testthat::expect_identical(stored$refusal_reason[[2L]], "recipient_quantity_unavailable")
  con_first <- ledgr:::get_connection(first)
  DBI::dbExecute(
    con_first,
    paste(
      "UPDATE snapshot_equity_corporate_actions",
      "SET gross_cash_validated = FALSE",
      "WHERE snapshot_id = ? AND gross_cash_per_parent_unit IS NOT NULL"
    ),
    params = list(first$snapshot_id)
  )
  testthat::expect_error(
    ledgr:::ledgr_snapshot_validate_availability_for_seal(
      con_first,
      first$snapshot_id
    ),
    class = "ledgr_fact_unvalidated_term"
  )
  DBI::dbExecute(
    con_first,
    paste(
      "UPDATE snapshot_equity_corporate_actions",
      "SET gross_cash_validated = TRUE",
      "WHERE snapshot_id = ? AND gross_cash_per_parent_unit IS NOT NULL"
    ),
    params = list(first$snapshot_id)
  )

  changed_rows <- equity_corporate_action_rows()
  changed_rows$gross_cash_per_parent_unit[[1L]] <- 1.5
  changed <- ledgr_snapshot_from_df(
    bars,
    facts = ledgr_facts(
      ledgr_facts_equity_corporate_actions(changed_rows)
    )
  )
  withr::defer(ledgr_snapshot_close(changed))
  testthat::expect_false(identical(
    first_hash,
    ledgr_snapshot_info(changed)$snapshot_hash[[1L]]
  ))

  copied_rows <- equity_corporate_action_rows()
  copied_rows$payment_time[[1L]] <- copied_rows$effective_time[[1L]]
  copied <- ledgr_snapshot_from_df(
    bars,
    facts = ledgr_facts(
      ledgr_facts_equity_corporate_actions(copied_rows)
    )
  )
  withr::defer(ledgr_snapshot_close(copied))
  testthat::expect_false(identical(
    first_hash,
    ledgr_snapshot_info(copied)$snapshot_hash[[1L]]
  ))

  no_facts_path <- tempfile(fileext = ".duckdb")
  no_facts <- ledgr_snapshot_from_df(bars, db_path = no_facts_path)
  no_facts_hash <- ledgr_snapshot_info(no_facts)$snapshot_hash[[1L]]
  ledgr_snapshot_close(no_facts)
  con <- ledgr_db_init(no_facts_path)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbExecute(con, "DROP TABLE snapshot_equity_corporate_actions")
  DBI::dbExecute(
    con,
    "UPDATE ledgr_schema_metadata SET value = '115'
     WHERE key = 'experiment_store_schema_version'"
  )
  DBI::dbDisconnect(con, shutdown = TRUE)
  testthat::expect_message(
    con <- ledgr_db_init(no_facts_path),
    "Upgraded ledgr experiment-store schema from version 115 to 116"
  )
  testthat::expect_true(ledgr:::ledgr_experiment_store_table_exists(
    con,
    "snapshot_equity_corporate_actions"
  ))
  testthat::expect_identical(
    ledgr:::ledgr_experiment_store_version(con),
    116L
  )
  testthat::expect_identical(
    ledgr:::ledgr_snapshot_hash(con, no_facts$snapshot_id),
    no_facts_hash
  )
  testthat::expect_no_error(ledgr_create_schema(con))
})

testthat::test_that("[LTB-0029] corporate-action facts do not activate availability", {
  snapshot <- ledgr_snapshot_from_df(
    equity_corporate_action_bars(),
    facts = ledgr_facts(
      ledgr_facts_equity_corporate_actions(equity_corporate_action_rows())
    )
  )
  withr::defer(ledgr_snapshot_close(snapshot))

  activation <- ledgr:::ledgr_availability_activation(snapshot)
  testthat::expect_false(activation$active)
  testthat::expect_identical(activation$declared_families, character())
  testthat::expect_true(
    "equity_corporate_actions" %in% activation$headers$family
  )
  validated <- ledgr:::ledgr_availability_validate_experiment(
    snapshot,
    universe = NULL,
    valuation_policy = NULL
  )
  testthat::expect_false(validated$active)
})

testthat::test_that("[LTB-0030] a fictional adapter seals the canonical facts", {
  adapter_path <- testthat::test_path(
    "..", "..", "vignettes", "fictional-corporate-action-adapter.R"
  )
  adapter_source <- paste(readLines(adapter_path, warn = FALSE), collapse = "\n")
  forbidden <- c(
    "ledgr[.]sharadar", "sharadar", "ticker", "permaticker",
    "actiontype", "date", "action", "name", "value",
    "contraticker", "contrapermaticker", "contraname"
  )
  for (token in forbidden) {
    testthat::expect_no_match(
      adapter_source,
      paste0("\\b", token, "\\b"),
      perl = TRUE,
      ignore.case = TRUE,
      info = paste("fictional adapter must not reference", token)
    )
  }

  adapter_env <- new.env(parent = globalenv())
  sys.source(adapter_path, envir = adapter_env)
  canonical_rows <- equity_corporate_action_rows()
  fictional_rows <- data.frame(
    record_key = canonical_rows$fact_id,
    effect_code = c("PAYMENT", "CHILD_GRANT"),
    subject_key = canonical_rows$parent_instrument_id,
    rights_at = canonical_rows$entitlement_time,
    changes_at = canonical_rows$effective_time,
    seen_at = canonical_rows$knowledge_time,
    settles_at = canonical_rows$payment_time,
    terms_ready = canonical_rows$complete,
    why_refused = canonical_rows$refusal_reason,
    lineage_level = canonical_rows$provenance_tier,
    source_build = canonical_rows$upstream_build_id,
    price_release = canonical_rows$bar_vintage_id,
    cash_units = canonical_rows$gross_cash_per_parent_unit,
    cash_checked = canonical_rows$gross_cash_validated,
    destination_key = canonical_rows$recipient_instrument_id,
    destination_checked = canonical_rows$recipient_identity_validated,
    share_units = canonical_rows$recipient_quantity_per_parent_unit,
    share_units_checked = canonical_rows$recipient_quantity_validated,
    stringsAsFactors = FALSE
  )
  expected <- ledgr_facts_equity_corporate_actions(canonical_rows)
  actual <- adapter_env$fictional_corporate_action_adapter(fictional_rows)
  testthat::expect_identical(actual, expected)

  bars <- equity_corporate_action_bars()
  expected_snapshot <- ledgr_snapshot_from_df(
    bars,
    facts = ledgr_facts(expected)
  )
  withr::defer(ledgr_snapshot_close(expected_snapshot))
  actual_snapshot <- ledgr_snapshot_from_df(
    bars,
    facts = ledgr_facts(actual)
  )
  withr::defer(ledgr_snapshot_close(actual_snapshot))
  testthat::expect_identical(
    ledgr_snapshot_info(actual_snapshot)$snapshot_hash[[1L]],
    ledgr_snapshot_info(expected_snapshot)$snapshot_hash[[1L]]
  )
})
