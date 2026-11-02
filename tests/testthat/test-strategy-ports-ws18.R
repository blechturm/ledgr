ws18_ports_path <- testthat::test_path(
  "..", "..", "dev", "bench", "v0_2_3_ws5", "semantic_ports.R"
)

# ledgr-test-profile: review
testthat::test_that("[LTB-0543] frozen strategy ports keep fills and declared state", {
  testthat::expect_true(file.exists(ws18_ports_path))
  env <- new.env(parent = globalenv())
  sys.source(ws18_ports_path, envir = env)
  result <- env$ws5_run_semantic_ports()

  testthat::expect_identical(nrow(result$trailing), 58L)
  testthat::expect_identical(nrow(result$turtle), 741L)
  testthat::expect_true(all(c("BUY", "SELL") %in% result$trailing$side))
  testthat::expect_true(all(c("BUY", "SELL") %in% result$turtle$side))
  testthat::expect_identical(
    vapply(result$state, nrow, integer(1L)),
    c(trailing = 1045L, turtle = 1045L)
  )
  marker <- ledgr:::ledgr_strategy_state_cursor_marker
  testthat::expect_identical(
    vapply(
      result$state,
      function(rows) sum(rows$state_json != marker),
      integer(1L)
    ),
    c(trailing = 283L, turtle = 691L)
  )

  source <- paste(readLines(ws18_ports_path, warn = FALSE), collapse = "\n")
  testthat::expect_no_match(source, "ctx$state_prev", fixed = TRUE)
  testthat::expect_no_match(source, "ctx$vec", fixed = TRUE)
  testthat::expect_no_match(source, "ledgr_select_top_n", fixed = TRUE)
  testthat::expect_match(source, "ledgr_strategy_result(target, peak = peak)", fixed = TRUE)
  testthat::expect_match(source, "ledgr_strategy_result(target, stop = stop)", fixed = TRUE)
})
