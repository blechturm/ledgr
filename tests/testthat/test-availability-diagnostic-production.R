diagnostic_production_handler <- function() {
  state <- new.env(parent = emptyenv())
  state$writes <- list()
  list(
    state = state,
    handler = list(
      write_run_diagnostics = function(rows) {
        state$writes[[length(state$writes) + 1L]] <- rows
        invisible(TRUE)
      }
    )
  )
}

diagnostic_production_block <- function(n, first_seq = 1L, id_offset = 0L) {
  ledgr:::ledgr_availability_diagnostic_block(
    run_id = "diagnostic-production",
    ts_utc = as.POSIXct("2020-01-02 21:00:00", tz = "UTC"),
    first_seq = first_seq,
    segments = list(list(
      n = n,
      instrument_id = sprintf("I%02d", id_offset + seq_len(n)),
      stage = "decision",
      outcome = "observed",
      reason_code = "member_asserted",
      target = seq_len(n),
      mark_age = seq_len(n) - 1L
    ))
  )
}

testthat::test_that("the production diagnostic path defaults to one typed block", {
  sink <- diagnostic_production_handler()
  writer <- ledgr:::ledgr_fold_diagnostic_writer(
    "diagnostic-production",
    sink$handler
  )
  testthat::expect_identical(names(writer), c("append_block", "drain", "release"))

  writer$append_block(diagnostic_production_block(2L))
  testthat::expect_length(sink$state$writes, 0L)
  testthat::expect_equal(nrow(writer$drain()), 2L)

})

testthat::test_that("typed diagnostic blocks split across injected chunks", {
  for (capacity in c(7L, 4096L)) {
    sink <- diagnostic_production_handler()
    writer <- ledgr:::ledgr_columnar_diagnostic_writer(
      "diagnostic-production",
      sink$handler,
      chunk_rows = capacity
    )
    block <- diagnostic_production_block(capacity + 3L)
    writer$append_block(block)
    testthat::expect_equal(
      vapply(sink$state$writes, nrow, integer(1)),
      capacity
    )
    tail <- writer$drain()
    testthat::expect_equal(nrow(tail), 3L)
    actual <- do.call(rbind, c(sink$state$writes, list(tail)))
    expected <- as.data.frame(block, stringsAsFactors = FALSE)
    rownames(actual) <- NULL
    rownames(expected) <- NULL
    testthat::expect_identical(actual, expected)
    testthat::expect_s3_class(actual$ts_utc, "POSIXct")
    testthat::expect_type(actual$diagnostic_seq, "integer")
    testthat::expect_type(actual$target, "double")
    testthat::expect_type(actual$instrument_id, "character")
  }

  for (bad in list(
    0L,
    -1L,
    1.5,
    NA_integer_,
    Inf,
    NaN,
    c(1L, 2L),
    "7"
  )) {
    testthat::expect_error(
      ledgr:::ledgr_columnar_diagnostic_writer(
        "diagnostic-production",
        sink$handler,
        chunk_rows = bad
      ),
      "positive integer",
      class = "ledgr_invalid_args"
    )
  }
})

testthat::test_that("a production block chunk remains available when its append fails", {
  state <- new.env(parent = emptyenv())
  state$fail <- TRUE
  state$writes <- list()
  handler <- list(write_run_diagnostics = function(rows) {
    if (state$fail) {
      state$fail <- FALSE
      stop("injected diagnostic append failure")
    }
    state$writes[[length(state$writes) + 1L]] <- rows
    invisible(TRUE)
  })
  writer <- ledgr:::ledgr_columnar_diagnostic_writer(
    "diagnostic-production",
    handler,
    chunk_rows = 2L
  )
  writer$append_block(diagnostic_production_block(2L))
  testthat::expect_error(
    writer$append_block(diagnostic_production_block(1L, first_seq = 3L, id_offset = 2L)),
    "injected diagnostic append failure"
  )
  writer$append_block(diagnostic_production_block(1L, first_seq = 3L, id_offset = 2L))
  tail <- writer$drain()
  testthat::expect_identical(writer$drain(), tail)
  writer$release()
  testthat::expect_equal(nrow(writer$drain()), 0L)
  actual <- do.call(rbind, c(state$writes, list(tail)))
  rownames(actual) <- NULL
  testthat::expect_identical(actual$instrument_id, c("I01", "I02", "I03"))
  testthat::expect_identical(actual$diagnostic_seq, 1:3)
})
