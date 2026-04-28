testthat::test_that("ledgr_opening validates cash, positions, and cost basis", {
  opening <- ledgr_opening(
    cash = 1000,
    date = "2020-01-02",
    positions = c(AAA = 10, BBB = 5),
    cost_basis = c(BBB = 99, AAA = 101)
  )

  testthat::expect_s3_class(opening, "ledgr_opening")
  testthat::expect_identical(opening$date, "2020-01-02T00:00:00Z")
  testthat::expect_identical(names(opening$positions), c("AAA", "BBB"))
  testthat::expect_identical(names(opening$cost_basis), c("AAA", "BBB"))
  testthat::expect_equal(opening$cost_basis, c(AAA = 101, BBB = 99))

  testthat::expect_error(ledgr_opening(cash = -1), class = "ledgr_invalid_opening")
  testthat::expect_error(ledgr_opening(cash = NA_real_), class = "ledgr_invalid_opening")
  testthat::expect_error(ledgr_opening(cash = 1, positions = c(10)), class = "ledgr_invalid_opening")
  testthat::expect_error(ledgr_opening(cash = 1, positions = c(AAA = -1)), class = "ledgr_invalid_opening")
  testthat::expect_error(
    ledgr_opening(cash = 1, positions = c(AAA = 1), cost_basis = c(BBB = 1)),
    class = "ledgr_invalid_opening"
  )
  testthat::expect_error(
    ledgr_opening(cash = 1, cost_basis = c(AAA = 1)),
    class = "ledgr_invalid_opening"
  )
})

testthat::test_that("ledgr_experiment builds a validated experiment object", {
  bars <- ledgr_test_make_bars(c("AAA", "BBB"), as.Date("2020-01-01") + 0:4)
  db_path <- tempfile(fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    stats::setNames(rep(0, length(ctx$universe)), ctx$universe)
  }
  features <- list(ledgr_ind_sma(2))
  con <- get_connection(snapshot)
  runs_before <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM runs")$n[[1]]

  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    features = features,
    opening = ledgr_opening(cash = 1000),
    universe = "AAA"
  )

  testthat::expect_s3_class(exp, "ledgr_experiment")
  testthat::expect_identical(exp$snapshot$snapshot_id, snapshot$snapshot_id)
  testthat::expect_identical(exp$universe, "AAA")
  testthat::expect_identical(exp$features_mode, "list")
  testthat::expect_s3_class(exp$opening, "ledgr_opening")
  testthat::expect_identical(exp$fill_model$type, "next_open")
  testthat::expect_true(exp$persist_features)
  testthat::expect_identical(exp$execution_mode, "audit_log")
  runs_after <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM runs")$n[[1]]
  testthat::expect_identical(runs_after, runs_before)
})

testthat::test_that("ledgr_experiment defaults universe to all snapshot instruments", {
  bars <- ledgr_test_make_bars(c("AAA", "BBB"), as.Date("2020-01-01") + 0:2)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    stats::setNames(rep(0, length(ctx$universe)), ctx$universe)
  }

  exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy)

  testthat::expect_identical(exp$universe, c("AAA", "BBB"))
})

testthat::test_that("ledgr_experiment rejects unsealed snapshots", {
  db_path <- tempfile(fileext = ".duckdb")
  opened <- ledgr_test_open_duckdb(db_path)
  con <- opened$con
  drv <- opened$drv
  on.exit(ledgr_test_close_duckdb(con, drv), add = TRUE)
  ledgr_create_schema(con)
  snapshot_id <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20200101_000000_abcd")
  snapshot <- ledgr:::new_ledgr_snapshot(db_path = db_path, snapshot_id = snapshot_id)
  strategy <- function(ctx, params) {
    stats::setNames(rep(0, length(ctx$universe)), ctx$universe)
  }

  testthat::expect_error(
    ledgr_experiment(snapshot = snapshot, strategy = strategy),
    class = "ledgr_invalid_experiment"
  )
})

testthat::test_that("ledgr_experiment validates strategy, universe, features, and opening", {
  bars <- ledgr_test_make_bars(c("AAA", "BBB"), as.Date("2020-01-01") + 0:2)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    stats::setNames(rep(0, length(ctx$universe)), ctx$universe)
  }

  testthat::expect_error(
    ledgr_experiment(snapshot = snapshot, strategy = function(ctx) ctx),
    class = "ledgr_invalid_experiment_strategy"
  )
  testthat::expect_error(
    ledgr_experiment(snapshot = snapshot, strategy = function(ctx, params, extra) ctx),
    class = "ledgr_invalid_experiment_strategy"
  )
  testthat::expect_error(
    ledgr_experiment(snapshot = snapshot, strategy = strategy, universe = "CCC"),
    class = "ledgr_invalid_experiment"
  )
  testthat::expect_error(
    ledgr_experiment(snapshot = snapshot, strategy = strategy, universe = c("AAA", "AAA")),
    class = "ledgr_invalid_experiment"
  )
  testthat::expect_error(
    ledgr_experiment(snapshot = snapshot, strategy = strategy, features = list("bad")),
    class = "ledgr_invalid_experiment_features"
  )
  testthat::expect_error(
    ledgr_experiment(snapshot = snapshot, strategy = strategy, features = function(x) list()),
    class = "ledgr_invalid_experiment_features"
  )
  testthat::expect_error(
    ledgr_experiment(
      snapshot = snapshot,
      strategy = strategy,
      universe = "AAA",
      opening = ledgr_opening(cash = 1, positions = c(BBB = 1))
    ),
    class = "ledgr_invalid_experiment"
  )
})

testthat::test_that("ledgr_experiment accepts feature functions without executing them", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:2)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    stats::setNames(rep(0, length(ctx$universe)), ctx$universe)
  }
  called <- FALSE
  feature_fn <- function(params) {
    called <<- TRUE
    list(ledgr_ind_sma(params$n))
  }

  exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy, features = feature_fn)

  testthat::expect_s3_class(exp, "ledgr_experiment")
  testthat::expect_identical(exp$features_mode, "function")
  testthat::expect_false(called)
})

testthat::test_that("experiment-related print methods are concise", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:2)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    stats::setNames(rep(0, length(ctx$universe)), ctx$universe)
  }
  exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy)

  opening_out <- utils::capture.output(print(exp$opening))
  experiment_out <- utils::capture.output(print(exp))

  testthat::expect_true(any(grepl("ledgr_opening", opening_out, fixed = TRUE)))
  testthat::expect_true(any(grepl("Cash:", opening_out, fixed = TRUE)))
  testthat::expect_true(any(grepl("ledgr_experiment", experiment_out, fixed = TRUE)))
  testthat::expect_true(any(grepl("Snapshot ID:", experiment_out, fixed = TRUE)))
  testthat::expect_true(any(grepl("Universe:", experiment_out, fixed = TRUE)))
})

testthat::test_that("ledgr_opening_from_broker is a reserved non-network hook", {
  testthat::expect_error(
    ledgr_opening_from_broker(list()),
    class = "ledgr_broker_adapter_not_supported"
  )
})
