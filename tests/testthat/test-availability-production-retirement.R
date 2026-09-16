testthat::test_that("installed availability runtime contains no retired arm", {
  ns <- asNamespace("ledgr")
  retired_functions <- c(
    "ledgr_availability_provider_build_current",
    "ledgr_availability_members_at",
    "ledgr_availability_status_at",
    "ledgr_availability_lifetime_at",
    "ledgr_availability_terminal_event_at",
    "ledgr_row_list_diagnostic_writer",
    "ledgr_availability_diagnostic_fields"
  )
  testthat::expect_false(any(vapply(
    retired_functions,
    exists,
    logical(1),
    envir = ns,
    inherits = FALSE
  )))

  forbidden <- c(
    "ledgr.internal.spike_availability_provider",
    "ledgr.internal.spike_diagnostic_writer",
    "ledgr.internal.spike_diagnostic_chunk_rows",
    "ledgr.internal.spike_diagnostic_block",
    "spike_arm",
    "spike_diagnostic_mode",
    retired_functions,
    "do.call(rbind, diagnostic_rows)"
  )
  r_dir <- testthat::test_path("..", "..", "R")
  if (dir.exists(r_dir)) {
    source <- paste(
      unlist(lapply(
        list.files(r_dir, pattern = "[.]R$", full.names = TRUE),
        readLines,
        warn = FALSE
      )),
      collapse = "\n"
    )
    for (token in forbidden) {
      testthat::expect_false(grepl(token, source, fixed = TRUE), info = token)
    }
  } else {
    testthat::succeed("source-tree scan is unavailable in installed-package tests")
  }
})

testthat::test_that("provider consumers do not call public inspection helpers", {
  ns <- asNamespace("ledgr")
  retained <- c("ledgr_membership_resolve_at", "ledgr_membership_evidence")
  testthat::expect_true(all(vapply(
    retained,
    exists,
    logical(1),
    envir = ns,
    inherits = FALSE
  )))

  consumers <- c(
    "ledgr_availability_provider",
    "ledgr_availability_provider_portable",
    "ledgr_availability_provider_build",
    "ledgr_availability_provider_build_prepared"
  )
  consumer_source <- paste(vapply(
    consumers,
    function(name) paste(deparse(get(name, envir = ns)), collapse = "\n"),
    character(1)
  ), collapse = "\n")
  for (name in retained) {
    testthat::expect_false(grepl(name, consumer_source, fixed = TRUE), info = name)
  }
})
