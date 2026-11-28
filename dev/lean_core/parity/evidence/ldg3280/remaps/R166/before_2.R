  appended <- 0L
  handler <- ns$ledgr_output_handler
  counted <- function(expr) testthat::with_mocked_bindings(
    ledgr_output_handler = function(sink, ...) {
      h <- handler(sink, ...)
      append <- h$append_compiled_spot_batch
      h$append_compiled_spot_batch <- function(batch) {
        appended <<- appended + 1L
        append(batch)
      }
      h
    },
    expr,
    .package = "ledgr"
  )
  # Ordinary compiled fills are appended and unchanged.
  testthat::expect_identical(counted(ws4a_public_ovf(FALSE, 10, cash, list(S = 5), compiled = TRUE))$sweep,
    c("DONE", "1000"))
  testthat::expect_gt(appended, 0L)
