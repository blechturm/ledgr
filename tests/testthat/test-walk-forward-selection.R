testthat::test_that("walk-forward selection rules hash canonical scalar payloads", {
  rule <- ledgr_select_argmax("sharpe_ratio")
  same <- ledgr_select_argmax("sharpe_ratio")
  opposite <- ledgr_select_argmin("sharpe_ratio")

  testthat::expect_s3_class(rule, "ledgr_selection_rule")
  testthat::expect_match(rule$selection_rule_hash, "^[0-9a-f]{64}$")
  testthat::expect_identical(rule$selection_rule_hash, same$selection_rule_hash)
  testthat::expect_false(identical(rule$selection_rule_hash, opposite$selection_rule_hash))
  testthat::expect_identical(
    names(ledgr:::ledgr_selection_rule_payload(rule)),
    c("type_id", "schema_version", "metric", "direction")
  )
  testthat::expect_true(any(grepl("ledgr selection rule", capture.output(print(rule)), fixed = TRUE)))
})

testthat::test_that("walk-forward selection fails closed on metric classes and eligibility", {
  scores <- data.frame(
    candidate_key = c("b", "a", "c", "d"),
    sharpe_ratio = c(1, 1, NA, Inf),
    total_return = c(0.5, 0.4, 0.1, 0.2),
    n_trades = c(10L, 9L, 8L, 7L),
    stringsAsFactors = FALSE
  )

  selected <- ledgr:::ledgr_selection_rule_select(ledgr_select_argmax("sharpe_ratio"), scores)
  testthat::expect_identical(selected$candidate_key, "a")

  selected_min <- ledgr:::ledgr_selection_rule_select(
    ledgr_select_argmin("sharpe_ratio"),
    transform(scores, sharpe_ratio = c(0.5, 0.25, 0.25, NA))
  )
  testthat::expect_identical(selected_min$candidate_key, "a")

  testthat::expect_error(
    ledgr:::ledgr_selection_rule_select(ledgr_select_argmax("missing_metric"), scores),
    class = "ledgr_walk_forward_metric_missing"
  )
  testthat::expect_error(
    ledgr:::ledgr_selection_rule_select(ledgr_select_argmax("total_return"), scores),
    class = "ledgr_walk_forward_metric_class_invalid"
  )
  testthat::expect_error(
    ledgr:::ledgr_selection_rule_select(ledgr_select_argmax("n_trades"), scores),
    class = "ledgr_walk_forward_metric_class_invalid"
  )
  testthat::expect_error(
    ledgr:::ledgr_selection_rule_select(
      ledgr_select_argmax("sharpe_ratio"),
      transform(scores, sharpe_ratio = c(NA, NaN, Inf, -Inf))
    ),
    class = "ledgr_walk_forward_no_selection"
  )
  testthat::expect_error(
    ledgr:::ledgr_selection_rule_select(
      ledgr_select_argmax("sharpe_ratio"),
      data.frame(sharpe_ratio = c(1, 2))
    ),
    class = "ledgr_walk_forward_candidate_key_missing"
  )
})
