# ledgr-test-profile: fast
testthat::test_that("[LTB-0032] corporate-action policy is closed and versioned", {
  research <- ledgr_corporate_actions_research()
  omitted <- eval(
    formals(ledgr_experiment)$corporate_action_policy,
    envir = asNamespace("ledgr")
  )
  strict <- ledgr_corporate_actions_strict()

  testthat::expect_identical(omitted, research)
  testthat::expect_identical(
    unname(unlist(research[c(
      "cash_amount", "cash_posting", "held_terminal_position",
      "unsupported_quantity"
    )], use.names = FALSE)),
    c("gross", "effective_close", "last_permissible", "report_only")
  )
  testthat::expect_identical(
    unname(unlist(strict[c(
      "cash_amount", "cash_posting", "held_terminal_position",
      "unsupported_quantity"
    )], use.names = FALSE)),
    rep("refuse", 4L)
  )
  testthat::expect_true(all(grepl("[.]v001$", unlist(research$identity))))
  short_values <- unlist(research[c(
    "cash_amount", "cash_posting", "held_terminal_position",
    "unsupported_quantity"
  )], use.names = FALSE)
  testthat::expect_false(any(unlist(research$identity) %in% short_values))

  baseline <- list(
    corporate_actions = ledgr:::ledgr_corporate_action_policy_identity(research)
  )
  alternatives <- list(
    ledgr_corporate_actions(cash_amount = "refuse"),
    ledgr_corporate_actions(cash_posting = "next_open"),
    ledgr_corporate_actions(held_terminal_position = "last_mark"),
    ledgr_corporate_actions(unsupported_quantity = "refuse")
  )
  hashes <- vapply(alternatives, function(policy) {
    ledgr:::config_hash(list(
      corporate_actions = ledgr:::ledgr_corporate_action_policy_identity(policy)
    ))
  }, character(1))
  testthat::expect_true(all(hashes != ledgr:::config_hash(baseline)))

  testthat::expect_error(
    ledgr_corporate_actions(cash_amount = "gr"),
    class = "ledgr_invalid_corporate_action_policy"
  )
  testthat::expect_error(
    ledgr_corporate_actions(cash_posting = function() NULL),
    class = "ledgr_invalid_corporate_action_policy"
  )
  tampered <- research
  tampered$identity$cash_amount <- "gross"
  testthat::expect_error(
    ledgr:::ledgr_validate_corporate_action_policy(tampered),
    class = "ledgr_invalid_corporate_action_policy"
  )
})

testthat::test_that("[LTB-0037] cash-distribution vignette records both presets", {
  root <- testthat::test_path("..", "..")
  source_path <- file.path(root, "vignettes", "corporate-action-cash.qmd")
  rendered_path <- file.path(root, "vignettes", "corporate-action-cash.md")
  testthat::expect_true(file.exists(source_path))
  testthat::expect_true(file.exists(rendered_path))
  source <- paste(readLines(source_path, warn = FALSE), collapse = "\n")
  rendered <- paste(readLines(rendered_path, warn = FALSE), collapse = "\n")
  testthat::expect_no_match(source, "eval: false", fixed = TRUE)
  testthat::expect_match(
    source,
    "corporate_action_policy = ledgr_corporate_actions_research()",
    fixed = TRUE
  )
  testthat::expect_match(
    source,
    "corporate_action_policy = ledgr_corporate_actions_strict()",
    fixed = TRUE
  )
  expected_output <- c(
    "Corporate actions: MODELED - configured settlement conventions were exercised",
    "cash_amount.gross: 1",
    "cash_posting.effective_close: 1",
    "Gross cash posted:           2.5",
    "Strict policy refused: Corporate-action cash settlement is refused by the selected policy."
  )
  testthat::expect_true(all(vapply(
    expected_output,
    grepl,
    logical(1),
    x = rendered,
    fixed = TRUE
  )))
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0033] legacy runs do not acquire a policy on reopen", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:2)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp, run_id = "legacy-policy-absence")
  close(bt)

  con <- get_connection(snapshot)
  row <- DBI::dbGetQuery(
    con,
    "SELECT config_json FROM runs WHERE run_id = ?",
    params = list("legacy-policy-absence")
  )
  legacy <- ledgr:::ledgr_json_read_config(row$config_json[[1L]])
  legacy$corporate_actions <- NULL
  legacy_json <- canonical_json(legacy)
  legacy_hash <- ledgr:::config_hash(legacy)
  DBI::dbExecute(
    con,
    "UPDATE runs SET config_json = ?, config_hash = ? WHERE run_id = ?",
    params = list(legacy_json, legacy_hash, "legacy-policy-absence")
  )

  reopened <- ledgr_run_open(snapshot, "legacy-policy-absence")
  on.exit(close(reopened), add = TRUE)
  testthat::expect_null(reopened$config$corporate_actions)
  testthat::expect_null(
    ledgr:::ledgr_json_read_config(
      ledgr_run_info(snapshot, "legacy-policy-absence")$config_json
    )$corporate_actions
  )
})
