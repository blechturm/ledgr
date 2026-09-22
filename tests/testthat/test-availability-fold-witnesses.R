availability_v201_scenarios <- list(
  direct = list(),
  direct_chunk4096 = list(chunk_rows = 4096L),
  interrupt_resume = list(interrupt_day = 6L),
  exception_rollback = list(fail_day = 7L),
  nonmember_increase_rollback = list(increase_day = 6L),
  resume_exception = list(interrupt_day = 5L, resume_fail_day = 8L),
  early_exit = list(exit_day = 7L),
  interrupt_resume_early_exit = list(interrupt_day = 6L, exit_day = 7L)
)

availability_v201_run_scenarios <- function() {
  out <- list()
  for (scenario in names(availability_v201_scenarios)) {
    args <- availability_v201_scenarios[[scenario]]
    chunk_rows <- args$chunk_rows %||% 7L
    args$chunk_rows <- NULL
    out[[scenario]] <- do.call(
      availability_v201_run_case,
      c(list(arm = "production", scenario = scenario, chunk_rows = chunk_rows), args)
    )
  }
  out
}

# ledgr-test-profile: heavy_protocol
testthat::test_that("ported fold witnesses preserve every persisted surface", {
  results <- availability_v201_run_scenarios()

  direct <- results[["direct"]]$final
  direct_large <- results[["direct_chunk4096"]]$final
  testthat::expect_identical(
    availability_v201_strip_run_id(direct$diagnostics),
    availability_v201_strip_run_id(direct_large$diagnostics)
  )

  summaries <- do.call(rbind, lapply(
    names(results),
    function(scenario) {
      chunk_rows <- availability_v201_scenarios[[scenario]]$chunk_rows %||%
        7L
      availability_v201_case_summary(
        results[[scenario]],
        scenario,
        "production",
        chunk_rows
      )
    }
  ))
  rownames(summaries) <- NULL
  summaries <- summaries[order(summaries$scenario, summaries$arm), ]
  rownames(summaries) <- NULL
  expected <- utils::read.csv(
    testthat::test_path(
      "fixtures",
      "availability-v0-2-0-1",
      "scenario-summary.csv"
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expected <- expected[expected$arm == "block", , drop = FALSE]
  expected$arm <- "production"
  rownames(expected) <- NULL
  availability_v201_expect_frozen(summaries, expected)

  perturbed <- expected
  perturbed$diagnostics[[1L]] <- perturbed$diagnostics[[1L]] + 1L
  testthat::expect_error(
    availability_v201_assert_frozen(summaries, perturbed),
    "frozen witness mismatch"
  )
})

# ledgr-test-profile: review
testthat::test_that("direct persisted rows match the reviewed baseline", {
  result <- availability_v201_run_case("production", "direct", 7L)$final
  fixture_dir <- testthat::test_path(
    "fixtures",
    "availability-v0-2-0-1"
  )
  surfaces <- c(
    "diagnostics", "events", "equity", "state", "completion", "identity"
  )
  for (surface in surfaces) {
    expected <- utils::read.csv(
      file.path(fixture_dir, paste0(surface, ".csv")),
      colClasses = "character",
      na.strings = NULL,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    actual <- availability_v201_freeze_frame(result[[surface]])
    if (identical(surface, "identity")) {
      testthat::expect_identical(expected$engine_version, "0.2.0.1")
      actual$engine_version <- NULL
      expected$engine_version <- NULL
    }
    testthat::expect_identical(actual, expected, info = surface)
    perturbed <- expected
    perturbed[[1L]][[1L]] <- paste0(perturbed[[1L]][[1L]], "-perturbed")
    testthat::expect_error(
      availability_v201_assert_frozen(actual, perturbed),
      "frozen witness mismatch",
      info = surface
    )
  }

  token <- with(
    result$diagnostics,
    stage == "execution" &
      outcome == "no_fill" &
      reason_code == "execution_bar_missing"
  )
  testthat::expect_true(any(token))
})

testthat::test_that("run identity excludes exactly the three registered fields", {
  raw <- data.frame(
    run_id = "witness",
    created_at_utc = "2021-01-01T00:00:00Z",
    archived_at_utc = NA_character_,
    config_hash = "hash",
    config_json = yyjsonr::write_json_str(
      list(
        db_path = "store.duckdb",
        data = list(
          snapshot_db_path = "snapshot.duckdb",
          snapshot_id = "witness"
        ),
        strategy = list(kind = "functional")
      ),
      auto_unbox = TRUE
    ),
    stringsAsFactors = FALSE
  )
  normalized <- availability_v201_normalize_identity(raw)
  testthat::expect_identical(
    setdiff(names(raw), names(normalized)),
    "created_at_utc"
  )
  config <- yyjsonr::read_json_str(normalized$config_json)
  testthat::expect_false("db_path" %in% names(config))
  testthat::expect_false("snapshot_db_path" %in% names(config$data))
  testthat::expect_identical(config$data$snapshot_id, "witness")
  testthat::expect_identical(config$strategy$kind, "functional")
  testthat::expect_true(all(c(
    "run_id", "archived_at_utc", "config_hash", "config_json"
  ) %in% names(normalized)))
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("ported failures roll back and resumes preserve prefixes", {
  exception <- availability_v201_run_case(
    "production",
    "exception_rollback",
    7L,
    fail_day = 7L
  )
  nonmember <- availability_v201_run_case(
    "production",
    "nonmember_increase_rollback",
    7L,
    increase_day = 6L
  )
  resumed <- availability_v201_run_case(
    "production",
    "resume_exception",
    7L,
    interrupt_day = 5L,
    resume_fail_day = 8L
  )

  testthat::expect_s3_class(exception$first_error, "ledgr_strategy_error")
  testthat::expect_s3_class(
    nonmember$first_error,
    "ledgr_nonmember_exposure_increase"
  )
  testthat::expect_s3_class(resumed$resume_error, "ledgr_strategy_error")
  expected_reasons <- c("fold_exception", "nonmember_exposure_increase")
  for (i in seq_along(expected_reasons)) {
    result <- list(exception, nonmember)[[i]]
    testthat::expect_identical(result$final$identity$status, "FAILED")
    testthat::expect_equal(nrow(result$final$diagnostics), 1L)
    testthat::expect_identical(
      result$final$diagnostics$reason_code,
      expected_reasons[[i]]
    )
    testthat::expect_equal(nrow(result$final$events), 0L)
  }
  testthat::expect_identical(resumed$first$identity$status, "RUNNING")
  testthat::expect_identical(resumed$final$identity$status, "FAILED")
  prefix <- resumed$first$diagnostics
  testthat::expect_identical(
    resumed$final$diagnostics[seq_len(nrow(prefix)), ],
    prefix
  )
  testthat::expect_identical(
    resumed$final$diagnostics$reason_code[[nrow(resumed$final$diagnostics)]],
    "fold_exception"
  )
  testthat::expect_identical(resumed$final$equity, resumed$first$equity)
})
