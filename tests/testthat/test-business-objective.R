testthat::test_that("business objectives are deterministic all-pass plans", {
  max_dd <- ledgr_objective_max_drawdown(0.20)
  min_trades <- ledgr_objective_min_trades(30)
  trajectory <- ledgr_objective_positive_trajectory(0)
  objective <- ledgr_business_objective(max_dd, min_trades, trajectory)
  repeated <- ledgr_business_objective(
    ledgr_objective_max_drawdown(0.20),
    ledgr_objective_min_trades(30),
    ledgr_objective_positive_trajectory(0)
  )

  testthat::expect_s3_class(objective, "ledgr_business_objective")
  testthat::expect_identical(objective$business_objective_schema_version, 1L)
  testthat::expect_identical(objective$composition, "all_pass")
  testthat::expect_identical(
    vapply(objective$criteria, `[[`, character(1), "criterion_id"),
    c("max_drawdown", "min_trades", "positive_trajectory")
  )
  testthat::expect_match(objective$business_objective_hash, "^[0-9a-f]{64}$")
  testthat::expect_identical(objective$business_objective_hash, repeated$business_objective_hash)
  testthat::expect_identical(objective$plan_json, repeated$plan_json)

  changed <- ledgr_business_objective(
    ledgr_objective_max_drawdown(0.21),
    min_trades,
    trajectory
  )
  reordered <- ledgr_business_objective(trajectory, min_trades, max_dd)
  testthat::expect_false(identical(objective$business_objective_hash, changed$business_objective_hash))
  testthat::expect_false(identical(objective$business_objective_hash, reordered$business_objective_hash))

  rebuilt <- ledgr:::ledgr_business_objective_from_plan_json(objective$plan_json)
  testthat::expect_s3_class(rebuilt, "ledgr_business_objective")
  testthat::expect_identical(rebuilt$plan_json, objective$plan_json)
  testthat::expect_identical(rebuilt$business_objective_hash, objective$business_objective_hash)
  testthat::expect_true(all(vapply(rebuilt$criteria, function(x) is.function(x$evaluate), logical(1))))

  edited_bins <- ledgr:::ledgr_json_read_nested(
    ledgr_business_objective(ledgr_objective_even_trades())$plan_json
  )
  edited_bins$criteria[[1L]]$params$time_bins <- 99L
  testthat::expect_error(
    ledgr:::ledgr_business_objective_from_plan_json(
      as.character(ledgr:::canonical_json(edited_bins))
    ),
    class = "ledgr_invalid_objective_criterion"
  )

  printed <- utils::capture.output(print(objective))
  testthat::expect_true(any(grepl("all criteria must pass", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl(substr(objective$business_objective_hash, 1L, 12L), printed, fixed = TRUE)))
})

testthat::test_that("business objectives reject unowned or malformed criteria", {
  testthat::expect_error(
    ledgr_business_objective(),
    class = "ledgr_invalid_business_objective"
  )
  testthat::expect_error(
    ledgr_business_objective(function(x) TRUE),
    class = "ledgr_invalid_objective_criterion"
  )
  testthat::expect_error(
    ledgr_business_objective(list(criterion_id = "max_drawdown")),
    class = "ledgr_invalid_objective_criterion"
  )
  testthat::expect_error(
    ledgr_business_objective(
      ledgr_objective_max_drawdown(0.20),
      ledgr_objective_max_drawdown(0.30)
    ),
    class = "ledgr_duplicate_objective_criterion"
  )
  testthat::expect_error(
    ledgr:::ledgr_objective_criterion_new(
      "max_drawdown",
      "summary.max_drawdown",
      list(max_drawdown = new.env(parent = emptyenv()))
    ),
    class = "ledgr_invalid_objective_criterion"
  )
  testthat::expect_error(
    ledgr:::ledgr_objective_criterion_new("third_party", "custom", list()),
    class = "ledgr_unknown_objective_criterion"
  )

  criterion <- ledgr_objective_max_drawdown(0.20)
  criterion$criterion_hash <- paste(rep("0", 64L), collapse = "")
  testthat::expect_error(
    ledgr_business_objective(criterion),
    class = "ledgr_objective_criterion_hash_mismatch"
  )

  replaced_evaluator <- ledgr_objective_max_drawdown(0.20)
  replaced_evaluator$evaluate <- function(...) {
    list(
      value = 0,
      threshold = 1,
      passed = TRUE,
      reason = "forged_pass",
      evidence_source = "forged",
      details = list()
    )
  }
  objective_with_replaced_evaluator <- ledgr_business_objective(replaced_evaluator)
  restored <- ledgr:::ledgr_objective_step_evaluate(
    objective_with_replaced_evaluator$criteria[[1L]],
    evidence = 0.30
  )
  testthat::expect_false(restored$passed)
  testthat::expect_identical(restored$reason, "max_drawdown_exceeded")

  objective <- ledgr_business_objective(ledgr_objective_min_trades(2))
  objective$business_objective_hash <- paste(rep("0", 64L), collapse = "")
  testthat::expect_error(
    print(objective),
    class = "ledgr_business_objective_hash_mismatch"
  )

  invalid_constructors <- list(
    function() ledgr_objective_even_trades(0),
    function() ledgr_objective_even_profit(1.1),
    function() ledgr_objective_max_drawdown(-0.1),
    function() ledgr_objective_stable_runs(0),
    function() ledgr_objective_min_trades(-1),
    function() ledgr_objective_positive_trajectory(Inf),
    function() ledgr_objective_stable_region(parameter_columns = c("x", "x"))
  )
  for (constructor in invalid_constructors) {
    testthat::expect_error(constructor(), class = "ledgr_invalid_objective_criterion")
  }
})

testthat::test_that("criterion steps expose one generic internal evaluation contract", {
  steps <- list(
    ledgr_objective_even_trades(),
    ledgr_objective_even_profit(),
    ledgr_objective_stable_region(),
    ledgr_objective_max_drawdown(),
    ledgr_objective_stable_runs(),
    ledgr_objective_min_trades(),
    ledgr_objective_positive_trajectory()
  )
  testthat::expect_true(all(vapply(steps, inherits, logical(1), "ledgr_objective_criterion")))
  testthat::expect_true(all(vapply(steps, function(x) is.function(x$evaluate), logical(1))))
  testthat::expect_true(all(vapply(steps, function(x) {
    is.character(x$criterion_id) && is.character(x$evidence_key) &&
      is.list(x$params) && grepl("^[0-9a-f]{64}$", x$criterion_hash)
  }, logical(1))))

  pass <- ledgr:::ledgr_objective_step_evaluate(
    ledgr_objective_max_drawdown(0.20),
    evidence = 0.10,
    candidate_id = "candidate_01"
  )
  fail <- ledgr:::ledgr_objective_step_evaluate(
    ledgr_objective_max_drawdown(0.20),
    evidence = 0.30,
    candidate_id = "candidate_01"
  )
  testthat::expect_identical(pass$passed, TRUE)
  testthat::expect_identical(fail$passed, FALSE)
  testthat::expect_identical(fail$reason, "max_drawdown_exceeded")
  testthat::expect_identical(pass$evidence_source, "summary.max_drawdown")
})

testthat::test_that("business-objective provenance is excluded from identity code", {
  files <- c(
    "R/config-hash.R",
    "R/sweep.R",
    "R/walk-forward.R",
    "R/walk-forward-identity.R"
  )
  paths <- vapply(files, function(path) testthat::test_path("..", "..", path), character(1))
  paths <- paths[file.exists(paths)]
  identity_code <- paste(vapply(paths, function(path) paste(readLines(path, warn = FALSE), collapse = "\n"), character(1)), collapse = "\n")
  testthat::expect_no_match(identity_code, "business_objective_hash", fixed = TRUE)
  testthat::expect_no_match(identity_code, "ledgr_business_objective", fixed = TRUE)
})
