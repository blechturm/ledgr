testthat::test_that("risk primitive constructors validate and store canonical fields", {
  none <- ledgr_risk_none()
  long_only <- ledgr_risk_long_only()
  max_weight <- ledgr_risk_max_weight(0.25)
  param_weight <- ledgr_risk_max_weight(ledgr_param("max_weight"))

  testthat::expect_s3_class(none, "ledgr_risk_model")
  testthat::expect_identical(none$type_id, "none")
  testthat::expect_identical(long_only$type_id, "long_only")
  testthat::expect_identical(max_weight$type_id, "max_weight")
  testthat::expect_equal(max_weight$args$max_weight, 0.25)
  testthat::expect_s3_class(param_weight$args$max_weight, "ledgr_param_ref")

  testthat::expect_error(ledgr_risk_max_weight(0), class = "ledgr_invalid_risk_model")
  testthat::expect_error(ledgr_risk_max_weight(1.01), class = "ledgr_invalid_risk_model")
  testthat::expect_error(ledgr_risk_max_weight(NA_real_), class = "ledgr_invalid_risk_model")
  testthat::expect_error(ledgr_risk_max_weight(c(0.1, 0.2)), class = "ledgr_invalid_risk_model")
  testthat::expect_error(ledgr_risk_max_weight("0.2"), class = "ledgr_invalid_risk_model")
})

testthat::test_that("risk chains accept only ledgr-owned risk objects", {
  risk <- ledgr_risk_chain(
    ledgr_risk_long_only(),
    ledgr_risk_max_weight(0.20)
  )

  testthat::expect_s3_class(risk, "ledgr_risk_model")
  testthat::expect_identical(risk$type_id, "chain")
  testthat::expect_length(ledgr:::ledgr_risk_flat_steps(risk), 2)

  nested <- ledgr_risk_chain(
    ledgr_risk_none(),
    ledgr_risk_chain(ledgr_risk_long_only()),
    ledgr_risk_max_weight(0.20)
  )
  testthat::expect_length(ledgr:::ledgr_risk_flat_steps(nested), 2)
  testthat::expect_s3_class(ledgr_risk_chain(), "ledgr_risk_model")
  testthat::expect_identical(ledgr_risk_chain()$type_id, "none")

  testthat::expect_error(
    ledgr_risk_chain(function(targets) targets),
    class = "ledgr_invalid_risk_model"
  )
  testthat::expect_error(
    ledgr_risk_chain(list(type_id = "long_only")),
    class = "ledgr_invalid_risk_model"
  )
})

testthat::test_that("risk identity is deterministic and content-sensitive", {
  a <- ledgr_risk_chain(ledgr_risk_long_only(), ledgr_risk_max_weight(0.20))
  b <- ledgr_risk_chain(ledgr_risk_long_only(), ledgr_risk_max_weight(0.20))
  c <- ledgr_risk_chain(ledgr_risk_long_only(), ledgr_risk_max_weight(0.25))
  d <- ledgr_risk_chain(ledgr_risk_max_weight(0.20), ledgr_risk_long_only())

  hash_a <- ledgr:::ledgr_risk_chain_hash(a)
  hash_b <- ledgr:::ledgr_risk_chain_hash(b)
  hash_c <- ledgr:::ledgr_risk_chain_hash(c)
  hash_d <- ledgr:::ledgr_risk_chain_hash(d)

  testthat::expect_match(hash_a, "^[0-9a-f]{64}$")
  testthat::expect_identical(hash_a, hash_b)
  testthat::expect_false(identical(hash_a, hash_c))
  testthat::expect_false(identical(hash_a, hash_d))

  payload <- ledgr:::ledgr_risk_plan_payload(a)
  testthat::expect_identical(names(payload$steps[[1]]), c("type_id", "schema_version", "args"))

  plan <- ledgr:::ledgr_risk_plan_json(a)
  testthat::expect_type(plan, "character")
  testthat::expect_match(plan, '"risk_schema_version":1', fixed = TRUE)
  testthat::expect_match(plan, '"type_id":"chain"', fixed = TRUE)
  testthat::expect_match(plan, '"type_id":"long_only"', fixed = TRUE)
  testthat::expect_match(plan, '"type_id":"max_weight"', fixed = TRUE)
})

testthat::test_that("no-op risk normalizes NULL, omitted, empty chain, and explicit none", {
  omitted_json <- ledgr:::ledgr_risk_plan_json()
  null_json <- ledgr:::ledgr_risk_plan_json(NULL)
  none_json <- ledgr:::ledgr_risk_plan_json(ledgr_risk_none())
  empty_chain_json <- ledgr:::ledgr_risk_plan_json(ledgr_risk_chain())

  testthat::expect_identical(omitted_json, null_json)
  testthat::expect_identical(omitted_json, none_json)
  testthat::expect_identical(omitted_json, empty_chain_json)
  testthat::expect_identical(
    ledgr:::ledgr_risk_chain_hash(NULL),
    ledgr:::ledgr_risk_chain_hash(ledgr_risk_none())
  )
})

testthat::test_that("risk plan JSON reconstructs byte-equivalent public risk objects", {
  risk <- ledgr_risk_chain(
    ledgr_risk_long_only(),
    ledgr_risk_max_weight(ledgr_param("max_weight"))
  )
  json <- ledgr:::ledgr_risk_plan_json(risk)
  reconstructed <- ledgr:::ledgr_risk_plan_reconstruct(json)

  testthat::expect_s3_class(reconstructed, "ledgr_risk_model")
  testthat::expect_identical(ledgr:::ledgr_risk_plan_json(reconstructed), json)
  testthat::expect_identical(
    ledgr:::ledgr_risk_chain_hash(reconstructed),
    ledgr:::ledgr_risk_chain_hash(risk)
  )

  payload <- ledgr:::ledgr_json_read_nested(json)
  max_weight_arg <- payload$steps[[2]]$args$max_weight
  testthat::expect_identical(max_weight_arg$kind, "param_ref")
  testthat::expect_identical(max_weight_arg$name, "max_weight")
})

testthat::test_that("compiled risk plans are plain serializable value objects", {
  risk <- ledgr_risk_chain(ledgr_risk_long_only(), ledgr_risk_max_weight(0.20))
  payload <- ledgr:::ledgr_risk_plan_payload(risk)

  testthat::expect_type(payload, "list")
  testthat::expect_null(attr(payload, "class"))
  testthat::expect_false(any(vapply(payload, is.function, logical(1))))
  testthat::expect_true(length(serialize(payload, NULL)) > 0)
})

testthat::test_that("risk print and str are stable smoke surfaces", {
  risk <- ledgr_risk_chain(ledgr_risk_long_only(), ledgr_risk_max_weight(0.20))
  out <- utils::capture.output(print(risk))
  structure_out <- utils::capture.output(str(risk))

  testthat::expect_true(any(grepl("ledgr risk chain", out, fixed = TRUE)))
  testthat::expect_true(any(grepl("long_only", out, fixed = TRUE)))
  testthat::expect_true(any(grepl("max_weight", out, fixed = TRUE)))
  testthat::expect_true(any(grepl("ledgr_risk_chain", structure_out, fixed = TRUE)))
})
