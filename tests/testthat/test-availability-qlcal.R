# ledgr-test-profile: review
testthat::test_that("qlcal adapter materializes closures and complete overrides", {
  testthat::skip_if_not_installed("qlcal")
  calendar <- qlcal::getCalendar("UnitedStates/NYSE")
  global_before <- qlcal::getId()
  overrides <- data.frame(
    session_date = as.Date("2024-07-03"),
    status = "open",
    session_open = "09:30:00",
    session_close = "13:00:00",
    stringsAsFactors = FALSE
  )
  family <- ledgr_facts_sessions_qlcal(
    calendar,
    from = as.Date("2024-07-03"),
    to = as.Date("2024-07-05"),
    venue_id = "XNYS",
    timezone = "America/New_York",
    session_open = "09:30:00",
    session_close = "16:00:00",
    overrides = overrides,
    provenance = list(source = "test-calendar")
  )
  testthat::expect_identical(qlcal::getId(), global_before)
  testthat::expect_identical(family$rows$session_date, as.Date("2024-07-03") + 0:2)
  testthat::expect_identical(family$rows$status, c("open", "closed", "open"))
  testthat::expect_identical(
    format(family$rows$session_close[[1L]], "%H:%M:%S", tz = "America/New_York"),
    "13:00:00"
  )
  testthat::expect_identical(family$metadata$schedule_basis, "generated")
  testthat::expect_identical(family$metadata$calendar_id, "UnitedStates/NYSE")
  testthat::expect_identical(family$metadata$provider, "qlcal")
  testthat::expect_identical(family$metadata$adapter_normalization_version, 1L)
  testthat::expect_false("generated_at" %in% names(family$metadata))
  testthat::expect_false(any(vapply(family, inherits, logical(1), "externalptr")))

  duplicate <- rbind(overrides, overrides)
  testthat::expect_error(
    ledgr_facts_sessions_qlcal(
      calendar, as.Date("2024-07-03"), as.Date("2024-07-05"), "XNYS",
      "America/New_York", "09:30:00", "16:00:00", overrides = duplicate
    ),
    class = "ledgr_session_override_invalid"
  )
  outside <- overrides
  outside$session_date <- as.Date("2024-07-06")
  testthat::expect_error(
    ledgr_facts_sessions_qlcal(
      calendar, as.Date("2024-07-03"), as.Date("2024-07-05"), "XNYS",
      "America/New_York", "09:30:00", "16:00:00", overrides = outside
    ),
    class = "ledgr_session_override_invalid"
  )
  testthat::expect_error(
    ledgr_facts_sessions_qlcal(
      "UnitedStates/NYSE", as.Date("2024-07-03"), as.Date("2024-07-05"), "XNYS",
      "America/New_York", "09:30:00", "16:00:00"
    ),
    class = "ledgr_session_adapter_invalid"
  )
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("qlcal metadata and assumptions enter existing identity", {
  testthat::skip_if_not_installed("qlcal")
  calendar <- qlcal::getCalendar("UnitedStates/NYSE")
  make_family <- function(close = "16:00:00",
                          knowledge = "assume_effective",
                          knowledge_time = NULL,
                          overrides = NULL) {
    ledgr_facts_sessions_qlcal(
      calendar,
      as.Date("2024-07-01"),
      as.Date("2024-07-05"),
      "XNYS",
      "America/New_York",
      "09:30:00",
      close,
      knowledge = knowledge,
      knowledge_time = knowledge_time,
      overrides = overrides,
      provenance = list(source = "test-calendar")
    )
  }
  assumed <- make_family()
  evidenced <- make_family(
    knowledge = "evidenced",
    knowledge_time = as.POSIXct("2024-01-01", tz = "UTC")
  )
  different_hours <- make_family(close = "15:59:00")
  override <- data.frame(
    session_date = as.Date("2024-07-03"), status = "open",
    session_open = "09:30:00", session_close = "13:00:00"
  )
  different_override <- make_family(overrides = override)
  testthat::expect_length(unique(c(
    assumed$fact_hash,
    evidenced$fact_hash,
    different_hours$fact_hash,
    different_override$fact_hash
  )), 4L)

  changed_metadata <- assumed$metadata
  changed_metadata$provider_version <- "different"
  changed_provider <- ledgr:::ledgr_new_fact_family(
    assumed$family,
    assumed$scope_id,
    assumed$rows,
    assumed$headers,
    changed_metadata
  )
  testthat::expect_false(identical(changed_provider$fact_hash, assumed$fact_hash))
  testthat::expect_identical(make_family()$fact_hash, assumed$fact_hash)

  snapshot_hash <- function(family) {
    dates <- family$rows$session_date[family$rows$status == "open"]
    snapshot <- ledgr_snapshot_from_df(data.frame(
      instrument_id = "AAA",
      ts_utc = dates,
      open = seq_along(dates) + 99,
      high = seq_along(dates) + 100,
      low = seq_along(dates) + 98,
      close = seq_along(dates) + 99,
      volume = 100
    ), facts = ledgr_facts(family))
    on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
    ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
  }
  hashes <- vapply(
    list(assumed, evidenced, different_hours, different_override, changed_provider),
    snapshot_hash,
    character(1)
  )
  testthat::expect_length(unique(hashes), 5L)
  testthat::expect_identical(snapshot_hash(make_family()), hashes[[1L]])

  make_plan <- function(family) {
    dates <- family$rows$session_date[family$rows$status == "open"]
    bars <- data.frame(
      instrument_id = "AAA",
      ts_utc = dates,
      open = seq_along(dates) + 99,
      high = seq_along(dates) + 100,
      low = seq_along(dates) + 98,
      close = seq_along(dates) + 99,
      volume = 100
    )
    snapshot <- ledgr_snapshot_from_df(bars, facts = ledgr_facts(family))
    on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
    experiment <- ledgr_experiment(
      snapshot,
      function(ctx, params) ctx$hold(),
      valuation_policy = ledgr_valuation_stale(1),
      cost_model = ledgr_cost_zero()
    )
    ledgr_experiment_plan(experiment)
  }
  assumed_plan <- make_plan(assumed)
  evidenced_plan <- make_plan(evidenced)
  session_row <- assumed_plan$checks[assumed_plan$checks$family == "sessions", ]
  evidenced_row <- evidenced_plan$checks[evidenced_plan$checks$family == "sessions", ]
  testthat::expect_identical(session_row$status, "assumption_backed")
  testthat::expect_identical(
    session_row$assumption_reasons,
    "knowledge_assume_effective|generated_schedule"
  )
  testthat::expect_identical(evidenced_row$status, "assumption_backed")
  testthat::expect_identical(evidenced_row$assumption_reasons, "generated_schedule")
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("materialized qlcal sessions reopen without calendar state", {
  testthat::skip_if_not_installed("qlcal")
  family <- ledgr_facts_sessions_qlcal(
    qlcal::getCalendar("UnitedStates/NYSE"),
    as.Date("2024-07-01"),
    as.Date("2024-07-05"),
    "XNYS",
    "America/New_York",
    "09:30:00",
    "16:00:00",
    provenance = list(source = "test-calendar")
  )
  open_dates <- family$rows$session_date[family$rows$status == "open"]
  bars <- data.frame(
    instrument_id = "AAA", ts_utc = open_dates,
    open = 100 + seq_along(open_dates), high = 101 + seq_along(open_dates),
    low = 99 + seq_along(open_dates), close = 100 + seq_along(open_dates), volume = 100
  )
  db_path <- tempfile(fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(bars, facts = ledgr_facts(family), db_path = db_path)
  snapshot_id <- snapshot$snapshot_id
  ledgr_snapshot_close(snapshot)
  reopened <- ledgr_snapshot_open(db_path, snapshot_id, verify = TRUE)
  history <- ledgr_facts_history(reopened, "sessions", "XNYS")
  testthat::expect_equal(nrow(history$rows), 5L)
  testthat::expect_identical(history$metadata$source, "snapshot")
  experiment <- ledgr_experiment(
    reopened,
    function(ctx, params) ctx$hold(),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  run <- ledgr_run(experiment)
  testthat::expect_identical(ledgr_run_info(reopened, run$run_id)$status, "DONE")
  close(run)
  ledgr_snapshot_close(reopened)
  testthat::expect_equal(
    length(grep("qlcal", deparse(body(ledgr_facts_history)), fixed = TRUE)),
    0L
  )
  testthat::expect_equal(
    length(grep("qlcal", deparse(body(ledgr_facts_resolve)), fixed = TRUE)),
    0L
  )
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("materialized sessions run in a fresh process without loading qlcal", {
  testthat::skip_on_covr()
  testthat::skip_if_not_installed("qlcal")
  testthat::skip_if_not_installed("pkgload")
  family <- ledgr_facts_sessions_qlcal(
    qlcal::getCalendar("UnitedStates/NYSE"),
    as.Date("2024-07-01"),
    as.Date("2024-07-05"),
    "XNYS",
    "America/New_York",
    "09:30:00",
    "16:00:00",
    provenance = list(source = "test-calendar")
  )
  open_dates <- family$rows$session_date[family$rows$status == "open"]
  db_path <- tempfile(fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(data.frame(
    instrument_id = "AAA",
    ts_utc = open_dates,
    open = 100 + seq_along(open_dates),
    high = 101 + seq_along(open_dates),
    low = 99 + seq_along(open_dates),
    close = 100 + seq_along(open_dates),
    volume = 100
  ), facts = ledgr_facts(family), db_path = db_path)
  snapshot_id <- snapshot$snapshot_id
  ledgr_snapshot_close(snapshot)

  script <- tempfile(fileext = ".R")
  root <- normalizePath(testthat::test_path("..", ".."), winslash = "/")
  installed_root <- normalizePath(system.file(package = "ledgr"), winslash = "/")
  writeLines(c(
    "args <- commandArgs(trailingOnly = TRUE)",
    "if (file.exists(file.path(args[[1L]], 'DESCRIPTION')) && !identical(Sys.getenv('R_COVR'), 'true')) {",
    "  pkgload::load_all(args[[1L]], quiet = TRUE)",
    "} else {",
    "  library(ledgr, lib.loc = dirname(args[[4L]]))",
    "}",
    "stopifnot(!'qlcal' %in% loadedNamespaces())",
    "snapshot <- ledgr_snapshot_open(args[[2L]], args[[3L]], verify = TRUE)",
    "history <- ledgr_facts_history(snapshot, 'sessions', 'XNYS')",
    "stopifnot(nrow(history$rows) == 5L)",
    "experiment <- ledgr_experiment(snapshot, function(ctx, params) ctx$hold(),",
    "  valuation_policy = ledgr_valuation_stale(1), cost_model = ledgr_cost_zero())",
    "run <- ledgr_run(experiment)",
    "stopifnot(ledgr_run_info(snapshot, run$run_id)$status == 'DONE')",
    "close(run)",
    "ledgr_snapshot_close(snapshot)",
    "stopifnot(!'qlcal' %in% loadedNamespaces())",
    "cat('DONE')"
  ), script)
  output <- system2(
    file.path(R.home("bin"), "Rscript"),
    c(
      shQuote(script), shQuote(root), shQuote(db_path), shQuote(snapshot_id),
      shQuote(installed_root)
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  testthat::expect_identical(attr(output, "status"), NULL)
  testthat::expect_match(paste(output, collapse = "\n"), "DONE", fixed = TRUE)
})
