availability_v201_membership_fixture <- function(days = 5L,
                                                  bar_days = seq_len(days)) {
  membership <- ledgr_facts_membership_snapshots(
    data.frame(
      effective_from = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
      knowledge_time = as.POSIXct("2019-12-31 00:00:00", tz = "UTC"),
      set_id = "production-members",
      members = I(list("AAA")),
      source = "test",
      stringsAsFactors = FALSE
    ),
    universe_id = "U",
    complete = TRUE
  )
  availability_runtime_fixture(
    days = days,
    bar_days = bar_days,
    membership = membership
  )
}

availability_v201_inspection_case <- function(interrupt_day = NULL) {
  fixture <- availability_v201_fold_fixture()
  db <- tempfile(
    "availability_provider_",
    fileext = ".duckdb"
  )
  snapshot <- ledgr_snapshot_from_df(
    fixture$bars,
    instruments_df = fixture$instruments,
    db_path = db,
    snapshot_id = "provider-consumer",
    facts = fixture$facts
  )
  on.exit({
    ledgr_snapshot_close(snapshot)
    unlink(c(db, paste0(db, ".wal")), force = TRUE)
  }, add = TRUE)
  interrupt_at <- if (is.null(interrupt_day)) "" else {
    format(
      availability_v201_at(interrupt_day, "21:00:00"),
      "%Y-%m-%dT%H:%M:%SZ",
      tz = "UTC"
    )
  }
  withr::local_options(list(
    ledgr.interrupt = FALSE,
    ledgr.v201.interrupt_at = interrupt_at,
    ledgr.v201.fail_at = "",
    ledgr.v201.increase_nonmember_at = "",
    ledgr.v201.exit_eee_from = ""
  ))
  experiment <- ledgr_experiment(
    snapshot,
    availability_v201_fold_strategy,
    universe = ledgr_universe_members("U"),
    valuation_policy = ledgr_valuation_stale(max_sessions = 2L),
    cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1e6)
  )
  run_id <- if (is.null(interrupt_day)) "provider-direct" else "provider-resumed"
  if (!is.null(interrupt_day)) {
    first <- ledgr_run(experiment, run_id = run_id)
    close(first)
    options(
      ledgr.interrupt = FALSE,
      ledgr.v201.interrupt_at = ""
    )
  }
  direct <- ledgr_run(experiment, run_id = run_id)
  diagnostics <- tibble::as_tibble(direct, what = "diagnostics")
  decision <- diagnostics[diagnostics$stage == "decision", , drop = FALSE][1L, ]
  active_availability <- tibble::as_tibble(direct, what = "availability")
  active_equity <- ledgr_compute_equity_curve(direct)
  active_explain <- ledgr_run_explain(
    direct,
    as.character(decision$instrument_id[[1L]]),
    decision$ts_utc[[1L]]
  )
  close(direct)

  reopened <- tryCatch(
    ledgr_run_open(snapshot, run_id),
    error = identity
  )
  reopen_error <- NULL
  reopened_availability <- NULL
  reopened_explain <- NULL
  reopened_equity <- NULL
  if (inherits(reopened, "error")) {
    reopen_error <- list(
      class = class(reopened),
      message = conditionMessage(reopened)
    )
  } else {
    reopened_availability <- tibble::as_tibble(
      reopened,
      what = "availability"
    )
    reopened_equity <- ledgr_compute_equity_curve(reopened)
    reopened_explain <- ledgr_run_explain(
      reopened,
      as.character(decision$instrument_id[[1L]]),
      decision$ts_utc[[1L]]
    )
    close(reopened)
  }

  list(
    store = availability_v201_read_store(db, run_id),
    active_availability = active_availability,
    active_equity = active_equity,
    active_explain = active_explain,
    reopened_availability = reopened_availability,
    reopened_equity = reopened_equity,
    reopened_explain = reopened_explain,
    reopen_error = reopen_error
  )
}

# ledgr-test-profile: review
testthat::test_that("production consumers build one prepared provider at each boundary", {
  builds <- new.env(parent = emptyenv())
  builds$n <- 0L
  original <- ledgr:::ledgr_availability_provider_build_prepared
  snapshot <- availability_v201_membership_fixture()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    universe = ledgr_universe_members("U"),
    valuation_policy = ledgr_valuation_stale(1L),
    cost_model = ledgr_cost_zero()
  )

  local({
    testthat::local_mocked_bindings(
      ledgr_availability_provider_build_prepared = function(...) {
        builds$n <- builds$n + 1L
        original(...)
      },
      ledgr_membership_resolve_at = function(...) {
        stop("provider consumer called the public membership resolver")
      },
      ledgr_membership_evidence = function(...) {
        stop("provider consumer called the public membership evidence path")
      },
      .package = "ledgr"
    )

    bt <- ledgr_run(experiment, run_id = "production-provider-boundaries")
    on.exit(close(bt), add = TRUE)
    testthat::expect_identical(builds$n, 1L)

    builds$n <- 0L
    availability <- tibble::as_tibble(bt, what = "availability")
    testthat::expect_gt(nrow(availability), 0L)
    testthat::expect_identical(builds$n, 1L)

    builds$n <- 0L
    diagnostics <- tibble::as_tibble(bt, what = "diagnostics")
    decision <- diagnostics[diagnostics$stage == "decision", , drop = FALSE][1L, ]
    ledgr_run_explain(
      bt,
      as.character(decision$instrument_id[[1L]]),
      decision$ts_utc[[1L]]
    )
    testthat::expect_identical(builds$n, 1L)

    builds$n <- 0L
    close(bt)
    reopened <- ledgr_run_open(snapshot, "production-provider-boundaries")
    close(reopened)
    testthat::expect_identical(builds$n, 0L)
  })
})

# ledgr-test-profile: review
testthat::test_that("INCOMPLETE reopen builds one prepared provider", {
  builds <- new.env(parent = emptyenv())
  builds$n <- 0L
  original <- ledgr:::ledgr_availability_provider_build_prepared
  snapshot <- availability_v201_membership_fixture(
    days = 4L,
    bar_days = c(1L, 2L, 4L)
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      target <- ctx$hold()
      target[["AAA"]] <- 1
      target
    },
    universe = ledgr_universe_members("U"),
    valuation_policy = ledgr_valuation_stale(0L),
    cost_model = ledgr_cost_zero()
  )

  local({
    testthat::local_mocked_bindings(
      ledgr_availability_provider_build_prepared = function(...) {
        builds$n <- builds$n + 1L
        original(...)
      },
      ledgr_membership_resolve_at = function(...) {
        stop("provider consumer called the public membership resolver")
      },
      ledgr_membership_evidence = function(...) {
        stop("provider consumer called the public membership evidence path")
      },
      .package = "ledgr"
    )
    bt <- ledgr_run(experiment, run_id = "production-provider-incomplete")
    close(bt)
    testthat::expect_identical(builds$n, 1L)

    builds$n <- 0L
    reopened <- ledgr_run_open(snapshot, "production-provider-incomplete")
    close(reopened)
    testthat::expect_identical(builds$n, 1L)
  })
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("provider results and reopen surfaces preserve production evidence", {
  for (interrupt_day in list(NULL, 6L)) {
    production <- availability_v201_inspection_case(interrupt_day)
    testthat::expect_null(production$reopen_error)
    testthat::expect_identical(
      production$active_availability,
      production$reopened_availability
    )
    testthat::expect_identical(
      production$active_equity,
      production$reopened_equity
    )
    testthat::expect_identical(
      production$active_explain,
      production$reopened_explain
    )
  }
})
