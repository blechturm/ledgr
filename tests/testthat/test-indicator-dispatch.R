# ledgr-test-file-profile: review

testthat::test_that("[LTB-0321] a custom indicator with a built-in id runs its own function in both modes", {
  # Cut 16 decision (19): an indicator whose id matches a built-in pattern
  # (`sma_<n>`, `return_1`) but whose definition is not the built-in is
  # computed with its own function in dense and availability runs; it is
  # never silently replaced by the built-in.
  features <- list(
    ledgr_indicator("sma_3", function(window) 42, requires_bars = 3L, gap_contract = "strict_window"),
    ledgr_indicator("return_1", function(window) -7, requires_bars = 2L, gap_contract = "strict_window")
  )
  builtins <- list(ledgr_ind_sma(3L), ledgr_ind_returns(1L))
  # Runs register their indicators in the session registry; each run here
  # starts without these ids and the previous entries are restored.
  registry <- get(".ledgr_indicator_registry", asNamespace("ledgr"))
  ids <- c("sma_3", "return_1")
  saved <- mget(ids, envir = registry, ifnotfound = list(NULL))
  clear <- function() {
    present <- ids[vapply(ids, exists, logical(1), envir = registry, inherits = FALSE)]
    if (length(present)) rm(list = present, envir = registry)
  }
  on.exit({
    clear()
    for (id in ids) if (!is.null(saved[[id]])) assign(id, saved[[id]], envir = registry)
  }, add = TRUE)
  observe <- function(snapshot, features, availability, run_id) {
    clear()
    seen <- new.env(parent = emptyenv())
    seen$sma <- numeric()
    seen$ret <- numeric()
    strategy <- function(ctx, params) {
      seen$sma <- c(seen$sma, ctx$feature("AAA", "sma_3"))
      seen$ret <- c(seen$ret, ctx$feature("AAA", "return_1"))
      ctx$hold()
    }
    args <- list(snapshot, strategy, features = features, cost_model = ledgr_cost_zero())
    if (isTRUE(availability)) args$valuation_policy <- ledgr_valuation_stale(1L)
    exp <- do.call(ledgr_experiment, args)
    bt <- ledgr_run(exp, run_id = run_id)
    close(bt)
    list(sma = seen$sma, ret = seen$ret)
  }

  dense <- ws42_dense_snapshot()
  on.exit(ledgr_snapshot_close(dense), add = TRUE)
  custom_dense <- observe(dense, features, FALSE, "dense-custom")
  testthat::expect_identical(custom_dense$sma[!is.na(custom_dense$sma)], rep(42, 4L))
  testthat::expect_identical(custom_dense$ret[!is.na(custom_dense$ret)], rep(-7, 5L))
  # The package built-ins under the same ids still compute their own values.
  builtin_dense <- observe(dense, builtins, FALSE, "dense-builtin")
  testthat::expect_identical(builtin_dense$sma[!is.na(builtin_dense$sma)], c(12, 13, 14, 15))

  availability <- availability_runtime_fixture(days = 6L)
  on.exit(ledgr_snapshot_close(availability), add = TRUE)
  custom_availability <- observe(availability, features, TRUE, "availability-custom")
  testthat::expect_identical(custom_availability$sma[!is.na(custom_availability$sma)], rep(42, 4L))
  testthat::expect_identical(custom_availability$ret[!is.na(custom_availability$ret)], rep(-7, 5L))
  builtin_availability <- observe(availability, builtins, TRUE, "availability-builtin")
  testthat::expect_identical(
    builtin_availability$sma[!is.na(builtin_availability$sma)],
    c(102, 103, 104, 105)
  )
})
