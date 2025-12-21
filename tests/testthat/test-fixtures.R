test_that("test_bars fixture has expected structure", {
  expect_true(exists("test_bars"))
  expect_equal(nrow(test_bars), 732)
  expect_equal(length(unique(test_bars$instrument_id)), 2)
  expect_true(all(table(test_bars$instrument_id) == 366))
})

test_that("test_bars fixture is deterministic", {
  env1 <- new.env(parent = baseenv())
  env2 <- new.env(parent = baseenv())

  fixture_path <- testthat::test_path("fixtures", "test_bars.R")
  sys.source(fixture_path, envir = env1)
  sys.source(fixture_path, envir = env2)

  expect_identical(env1$test_bars, env2$test_bars)
})
