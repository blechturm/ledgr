# ledgr-test-profile: fast
testthat::test_that("[LTB-0269] inline schema-version literals match their census", {
  root <- ledgr_test_source_root()
  source_files <- list.files(
    file.path(root, "R"),
    pattern = "[.]R$",
    full.names = TRUE
  )
  literal_pattern <- paste0(
    "schema_version\\s*=\\s*1L\\b|",
    "snapshot\\$snapshot_schema_version\\),\\s*1L\\b|",
    "schema_version[^\\n]*%\\|\\|%\\s*1L\\b|",
    "schema_version\\s*=\\s*ledgr_universe_rule_schema_version\\b"
  )
  observed <- unlist(lapply(source_files, function(path) {
    lines <- readLines(path, warn = FALSE)
    hit <- grep(literal_pattern, lines, perl = TRUE)
    if (length(hit) == 0L) return(character())
    sprintf("R/%s:%d", basename(path), hit)
  }), use.names = FALSE)

  census_path <- testthat::test_path(
    "fixtures", "schema-version-literal-census.csv"
  )
  census <- utils::read.csv(
    census_path,
    stringsAsFactors = FALSE,
    na.strings = character()
  )
  testthat::expect_identical(sort(observed), sort(census$source_location))
  testthat::expect_false(anyDuplicated(census$source_location) > 0L)
  testthat::expect_setequal(
    unique(census$classification),
    c("config_persisted", "memory_only")
  )
  testthat::expect_true(all(nzchar(census$enclosing_object)))
  testthat::expect_true(all(nzchar(census$field)))
  testthat::expect_true(all(nzchar(census$persistence_path)))
  testthat::expect_true(all(nzchar(census$disposition)))

  persisted <- census[census$classification == "config_persisted", , drop = FALSE]
  testthat::expect_identical(nrow(persisted), 1L)
  testthat::expect_identical(
    persisted$disposition,
    "fingerprinted_constant:ledgr_universe_rule_schema_version"
  )
  testthat::expect_identical(
    unname(ledgr:::ledgr_store_format_bindings()[[
      "ledgr_universe_rule_schema_version"
    ]]),
    1L
  )
})
