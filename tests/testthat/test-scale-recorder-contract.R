# ledgr-test-file-profile: review

testthat::test_that("[LTB-0277] the scale recorder has an exact schema-120 family manifest", {
  repository <- if (exists("ledgr_test_source_root", mode = "function")) {
    ledgr_test_source_root()
  } else {
    normalizePath(".", winslash = "/")
  }
  checkout <- file.exists(file.path(repository, ".git")) ||
    file.exists(file.path(repository, ".Rbuildignore"))
  suite <- file.path(
    repository,
    "dev", "bench", "v0_2_2_real_data_scale"
  )

  if (!checkout) {
    testthat::expect_false(file.exists(file.path(repository, ".git")))
    testthat::expect_false(file.exists(file.path(repository, ".Rbuildignore")))
    testthat::expect_false(dir.exists(file.path(repository, "dev")))
    return(invisible(NULL))
  }

  testthat::expect_true(dir.exists(suite))
  testthat::expect_true("^dev(/|$)" %in% readLines(
    file.path(repository, ".Rbuildignore"),
    warn = FALSE
  ))
  helper <- file.path(suite, "record_manifest.R")
  manifest_path <- file.path(suite, "family_manifest.csv")
  transition_path <- file.path(suite, "family_transition_schema120.csv")
  testthat::expect_true(file.exists(helper))
  testthat::expect_true(file.exists(manifest_path))
  testthat::expect_true(file.exists(transition_path))

  helper_env <- new.env(parent = baseenv())
  sys.source(helper, envir = helper_env)
  manifest <- helper_env$ledgr_scale_record_manifest_read(manifest_path)
  testthat::expect_silent(helper_env$ledgr_scale_record_validate_transition(
    manifest,
    transition_path
  ))

  phases <- c(
    "build", "run_momentum", "run_equal_weight", "readers",
    "availability", "explain", "dense", "sweep", "promote",
    "walk_forward"
  )
  current_fixture <- helper_env$ledgr_scale_record_expected_families(
    manifest,
    "fixture",
    phases
  )
  testthat::expect_length(current_fixture, 51L)
  testthat::expect_true("momentum_feature_plane" %in% current_fixture)
  testthat::expect_false(any(c(
    "momentum_features", "equal_weight_features"
  ) %in% current_fixture))

  historical <- utils::read.csv(
    file.path(suite, "evidence", "sharadar_pair", "accepted-1.csv"),
    stringsAsFactors = FALSE
  )$family
  current_sharadar <- helper_env$ledgr_scale_record_expected_families(
    manifest,
    "sharadar",
    phases
  )
  testthat::expect_setequal(
    setdiff(historical, current_sharadar),
    c("momentum_features", "equal_weight_features")
  )
  testthat::expect_setequal(
    setdiff(current_sharadar, historical),
    "momentum_feature_plane"
  )

  record <- tempfile("ledgr-scale-manifest-")
  family_dir <- file.path(record, "families")
  dir.create(family_dir, recursive = TRUE)
  on.exit(unlink(record, recursive = TRUE), add = TRUE)
  expected <- helper_env$ledgr_scale_record_expected_families(
    manifest,
    "fixture",
    "run_momentum"
  )
  invisible(file.create(file.path(family_dir, paste0(expected, ".csv"))))
  testthat::expect_silent(helper_env$ledgr_scale_record_validate_manifest(
    record,
    manifest,
    "fixture",
    "run_momentum"
  ))
  unlink(file.path(family_dir, paste0(expected[[1L]], ".csv")))
  testthat::expect_error(
    helper_env$ledgr_scale_record_validate_manifest(
      record,
      manifest,
      "fixture",
      "run_momentum"
    ),
    "missing:",
    fixed = TRUE
  )
  invisible(file.create(file.path(family_dir, paste0(expected[[1L]], ".csv"))))
  invisible(file.create(file.path(family_dir, "undeclared.csv")))
  testthat::expect_error(
    helper_env$ledgr_scale_record_validate_manifest(
      record,
      manifest,
      "fixture",
      "run_momentum"
    ),
    "extra: undeclared",
    fixed = TRUE
  )

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)
  tables <- DBI::dbGetQuery(
    con,
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main'"
  )$table_name
  testthat::expect_false("features" %in% tables)
})
