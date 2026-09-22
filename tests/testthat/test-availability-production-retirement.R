# ledgr-test-file-profile: review
testthat::test_that("retired availability entry points are absent", {
  ns <- asNamespace("ledgr")
  retired_functions <- c(
    "ledgr_availability_provider_build_current",
    "ledgr_availability_members_at",
    "ledgr_availability_status_at",
    "ledgr_availability_lifetime_at",
    "ledgr_availability_terminal_event_at",
    "ledgr_row_list_diagnostic_writer",
    "ledgr_availability_diagnostic_fields"
  )
  testthat::expect_false(any(vapply(
    retired_functions,
    exists,
    logical(1),
    envir = ns,
    inherits = FALSE
  )))

})

testthat::test_that("production provider consumers bypass public inspection helpers", {
  ns <- asNamespace("ledgr")
  retained <- c("ledgr_membership_resolve_at", "ledgr_membership_evidence")
  testthat::expect_true(all(vapply(
    retained,
    exists,
    logical(1),
    envir = ns,
    inherits = FALSE
  )))

  testthat::local_mocked_bindings(
    ledgr_membership_resolve_at = function(...) {
      stop("production consumer called the public membership resolver")
    },
    ledgr_membership_evidence = function(...) {
      stop("production consumer called the public membership evidence path")
    },
    .package = "ledgr"
  )
  result <- availability_v201_run_case("production", "direct", 7L)$final
  testthat::expect_gt(nrow(result$diagnostics), 0L)
})
