testthat::test_that("prepared provider preserves the frozen provider witnesses", {
  fixture <- availability_v201_provider_data()
  config <- availability_v201_provider_config(fixture$ids)
  providers <- lapply(
    c("reference", "current", "prepared"),
    availability_v201_build_provider,
    data = fixture$data,
    config = config
  )
  names(providers) <- c("reference", "current", "prepared")

  cutoffs <- availability_v201_at(c(8L, 1L, 4L, 3L, 6L, 2L, 8L, 5L))
  positions <- stats::setNames(c(0, 4, 0, 2), fixture$ids)
  execution_ids <- c("AAA", "BBB", "CCC", "DDD")
  signatures <- vector("list", length(cutoffs))

  for (i in seq_along(cutoffs)) {
    cutoff <- cutoffs[[i]]
    reference <- list(
      decision = providers$reference$decision_view(cutoff, positions),
      execution = providers$reference$execution_view(cutoff, execution_ids),
      facts = providers$reference$facts(cutoff)
    )
    current <- list(
      decision = providers$current$decision_view(cutoff, positions),
      execution = providers$current$execution_view(cutoff, execution_ids),
      facts = providers$current$facts(cutoff)
    )
    prepared <- list(
      decision = providers$prepared$decision_view(cutoff, positions),
      execution = providers$prepared$execution_view(cutoff, execution_ids),
      facts = providers$prepared$facts(cutoff)
    )
    testthat::expect_identical(current, reference)
    testthat::expect_identical(prepared, reference)
    signatures[[i]] <- data.frame(
      cutoff = format(cutoff, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      members = paste(reference$decision$members, collapse = "|"),
      status = paste(
        paste(names(reference$facts$status), reference$facts$status, sep = "="),
        collapse = "|"
      ),
      lifetime = paste(
        paste(
          names(reference$facts$lifetime),
          reference$facts$lifetime,
          sep = "="
        ),
        collapse = "|"
      ),
      terminal = paste(
        paste(
          names(reference$facts$terminal_event),
          reference$facts$terminal_event,
          sep = "="
        ),
        collapse = "|"
      ),
      stringsAsFactors = FALSE
    )
  }

  actual <- do.call(rbind, signatures[c(2L, 4L, 3L, 5L, 1L)])
  rownames(actual) <- NULL
  expected <- data.frame(
    cutoff = c(
      "2021-01-04T00:00:00Z",
      "2021-01-06T00:00:00Z",
      "2021-01-07T00:00:00Z",
      "2021-01-09T00:00:00Z",
      "2021-01-11T00:00:00Z"
    ),
    members = c(
      "AAA|BBB",
      "AAA|BBB|CCC|DDD",
      "AAA|BBB|CCC|DDD",
      "BBB|CCC|DDD",
      "BBB|CCC"
    ),
    status = c(
      "AAA=active|BBB=halted|CCC=unknown|DDD=unknown",
      "AAA=halted|BBB=halted|CCC=unknown|DDD=unknown",
      "AAA=halted|BBB=active|CCC=conflicting|DDD=unknown",
      "AAA=active|BBB=active|CCC=unknown|DDD=unknown",
      "AAA=active|BBB=active|CCC=unknown|DDD=unknown"
    ),
    lifetime = c(
      "AAA=known_active|BBB=known_active|CCC=known_active|DDD=known_active",
      "AAA=known_active|BBB=known_active|CCC=known_active|DDD=known_active",
      "AAA=known_active|BBB=known_active|CCC=known_active|DDD=known_active",
      "AAA=known_active|BBB=known_active|CCC=known_active|DDD=known_active",
      "AAA=known_active|BBB=known_active|CCC=known_active|DDD=known_inactive"
    ),
    terminal = c(
      "AAA=|BBB=|CCC=|DDD=",
      "AAA=|BBB=|CCC=|DDD=",
      "AAA=|BBB=|CCC=|DDD=",
      "AAA=|BBB=|CCC=|DDD=",
      "AAA=|BBB=|CCC=|DDD=delisted"
    ),
    stringsAsFactors = FALSE
  )
  availability_v201_assert_frozen(actual, expected)

  perturbed <- expected
  perturbed$members[[3L]] <- "AAA"
  testthat::expect_error(
    availability_v201_assert_frozen(actual, perturbed),
    "frozen witness mismatch"
  )
})

testthat::test_that("declared empty status family keeps the row-presence default", {
  fixture <- availability_v201_provider_data(empty_status = TRUE)
  config <- availability_v201_provider_config(fixture$ids)
  providers <- lapply(
    c("reference", "current", "prepared"),
    availability_v201_build_provider,
    data = fixture$data,
    config = config
  )
  views <- lapply(providers, function(provider) {
    provider$facts(availability_v201_at(8L), fixture$ids)
  })
  testthat::expect_identical(views[[2L]], views[[1L]])
  testthat::expect_identical(views[[3L]], views[[1L]])
  testthat::expect_identical(
    unname(views[[3L]]$status),
    rep("active", length(fixture$ids))
  )
})

testthat::test_that("the production provider defaults to prepared instance-local cursors", {
  withr::local_options(list(
    ledgr.internal.spike_availability_provider = NULL
  ))
  fixture <- availability_v201_provider_data()
  config <- availability_v201_provider_config(fixture$ids)
  first <- availability_v201_build_provider(
    "prepared",
    fixture$data,
    config
  )
  second <- ledgr:::ledgr_availability_provider_build(
    fixture$data,
    config,
    "witness-hash",
    function(...) stop("history is unreachable in provider witnesses")
  )

  testthat::expect_identical(attr(second, "spike_arm"), "prepared")
  positions <- stats::setNames(c(0, 4, 0, 2), fixture$ids)
  cutoffs <- availability_v201_at(c(8L, 2L, 6L, 1L, 8L, 4L))
  first_views <- lapply(cutoffs, first$decision_view, positions = positions)
  second_views <- lapply(
    rev(cutoffs),
    second$decision_view,
    positions = positions
  )
  testthat::expect_identical(first_views, rev(second_views))

  withr::local_options(list(
    ledgr.internal.spike_availability_provider = "not-an-arm"
  ))
  production_safe <- ledgr:::ledgr_availability_provider_build(
    fixture$data,
    config,
    "witness-hash",
    function(...) stop("history is unreachable in provider witnesses")
  )
  testthat::expect_identical(attr(production_safe, "spike_arm"), "prepared")
})

testthat::test_that("public membership resolution agrees with prepared views", {
  ids <- c("AAA", "BBB", "CCC", "DDD")
  dates <- as.Date("2021-01-04") + 0:8
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "14:30:00",
      session_close = "21:00:00",
      knowledge_time = availability_v201_at(rep(0L, length(dates))),
      stringsAsFactors = FALSE
    ),
    venue_id = "SYNTH"
  )
  membership <- data.frame(
    effective_from = availability_v201_at(c(1L, 3L, 5L)),
    knowledge_time = availability_v201_at(c(0L, 2L, 6L)),
    set_id = c("L1", "P1", "L2"),
    members = I(list(c("AAA", "BBB"), "CCC", c("BBB", "CCC"))),
    source = "witness",
    stringsAsFactors = FALSE
  )
  facts <- ledgr_facts(
    sessions,
    ledgr_facts_membership_snapshots(
      membership,
      "U",
      complete = c(TRUE, FALSE, TRUE)
    )
  )
  bars <- do.call(rbind, lapply(ids, function(id) {
    data.frame(
      ts_utc = as.POSIXct(paste(dates, "21:00:00"), tz = "UTC"),
      instrument_id = id,
      open = 100,
      high = 101,
      low = 99,
      close = 100,
      volume = 1000,
      stringsAsFactors = FALSE
    )
  }))
  snapshot <- ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = ids),
    facts = facts,
    snapshot_id = "witness"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  opened <- ledgr_test_open_duckdb(snapshot$db_path)
  data <- ledgr:::ledgr_availability_provider_data(opened$con, "witness")
  ledgr_test_close_duckdb(opened$con, opened$drv)
  provider <- availability_v201_build_provider(
    "prepared",
    data,
    availability_v201_provider_config(ids)
  )
  zero <- stats::setNames(numeric(length(ids)), ids)
  cutoffs <- availability_v201_at(c(6L, 1L, 3L, 6L, 5L, 2L))

  for (i in seq_along(cutoffs)) {
    cutoff <- cutoffs[[i]]
    public <- ledgr_facts_resolve(snapshot, "membership", "U", at = cutoff)
    public_members <- ledgr:::ledgr_availability_stable_ids(
      as.character(public$rows$instrument_id[public$rows$member %in% TRUE])
    )
    testthat::expect_identical(
      provider$decision_view(cutoff, zero)$members,
      public_members
    )
  }
})

testthat::test_that("retained references are test-only and detect perturbation", {
  retained <- c(
    "availability_reference_validate_status_conflicts",
    "availability_reference_validate_membership_conflicts",
    "availability_reference_validate_lifetime_conflicts",
    "availability_reference_provider_build_current",
    "availability_reference_diagnostic_fields",
    "availability_reference_row_list_writer"
  )
  testthat::expect_false(any(vapply(
    retained,
    exists,
    logical(1),
    envir = asNamespace("ledgr"),
    inherits = FALSE
  )))

  row <- availability_reference_diagnostic_fields(
    run_id = "witness",
    diagnostic_seq = 1L,
    ts_utc = availability_v201_at(1L),
    stage = "decision",
    outcome = "observed"
  )
  testthat::expect_identical(
    row,
    ledgr:::ledgr_availability_diagnostic_fields(
      run_id = "witness",
      diagnostic_seq = 1L,
      ts_utc = availability_v201_at(1L),
      stage = "decision",
      outcome = "observed"
    )
  )
  perturbed <- row
  perturbed$outcome <- "blocked"
  testthat::expect_error(
    availability_v201_assert_frozen(row, perturbed),
    "frozen witness mismatch"
  )
})
