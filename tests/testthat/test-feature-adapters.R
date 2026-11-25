# Cut 24 stage 2 (LDG-3259; feature-engine stages 2-3 synthesis, rules 1-3
# and 12): the feature adapters.

testthat::test_that("[Cut 24 adapters] the adapter list is fixed, ordered and builds nothing", {
  # Describing the adapters constructs no indicator.
  testthat::local_mocked_bindings(
    ledgr_ind_sma = function(...) stop("constructed"), ledgr_ind_ema = function(...) stop("constructed"),
    ledgr_ind_rsi = function(...) stop("constructed"), ledgr_ind_returns = function(...) stop("constructed"),
    ledgr_ind_ttr = function(...) stop("constructed"), .package = "ledgr")
  adapters <- ledgr:::ledgr_feature_adapters()
  testthat::expect_identical(names(adapters), c("ledgr", "TTR"))
  fields <- c("name", "package", "catalogue_rows", "constructors", "candidates", "certified", "segment", "bind")
  for (adapter in adapters) {
    testthat::expect_identical(names(adapter), fields)
    testthat::expect_true(all(vapply(adapter[c("catalogue_rows", "candidates", "certified", "segment")],
                                     is.function, logical(1))))
  }
  testthat::expect_identical(vapply(adapters, `[[`, "", "package"), c(ledgr = "ledgr", TTR = "TTR"))
  testthat::expect_false("ledgr_feature_adapters" %in% getNamespaceExports("ledgr"))
  # The descriptions reach no backend: neither builder calls a loader or the
  # backend itself.
  for (builder in c("ledgr_feature_adapter_ledgr", "ledgr_feature_adapter_ttr", "ledgr_feature_adapters")) {
    globals <- codetools::findGlobals(get(builder, envir = asNamespace("ledgr")), merge = TRUE)
    testthat::expect_false(any(c("requireNamespace", "loadNamespace", "library", "getExportedValue") %in% globals),
                           info = builder)
  }
})

testthat::test_that("[Cut 24 adapters] source values, catalogue, constructors and provenance read the adapters unchanged", {
  testthat::expect_identical(ledgr:::ledgr_indicator_sources(), c("ledgr", "TTR", "custom"))
  testthat::expect_error(
    ledgr_indicator("x", fn = function(window) 1, requires_bars = 1L, source = "TA-Lib"),
    "`source` must be one of 'ledgr', 'TTR', or 'custom'.", fixed = TRUE, class = "ledgr_invalid_args")
  testthat::expect_identical(ledgr:::ledgr_indicator_source(list(source = "TA-Lib")), "custom")
  testthat::expect_identical(ledgr:::ledgr_indicator_source(list(source = "TTR")), "TTR")
  catalogue <- ledgr:::ledgr_indicator_history_catalogue()
  testthat::expect_identical(nrow(catalogue), 48L)
  testthat::expect_identical(names(catalogue), c("source", "family", "output", "variant", "history_class",
                                                 "required_fields", "input_carry", "width"))
  # The cut base's catalogue, row for row (ea580bc6).
  testthat::expect_identical(digest::digest(catalogue, algo = "sha256"),
                             "4bb152ad1c8ac1a53ceab9e1afd8e4164aacbee96793bd67ff5a1fc020a47ab1")
  registry <- ledgr:::ledgr_param_constructor_registry()
  testthat::expect_identical(names(registry), c("ledgr_ind_sma", "ledgr_ind_ema", "ledgr_ind_rsi", "ledgr_ind_returns",
                                                "ledgr_ind_ttr", "ledgr_ind_ttr_outputs"))
  testthat::expect_identical(registry$ledgr_ind_ttr, ledgr_ind_ttr)
  versions <- yyjsonr::read_json_str(ledgr:::ledgr_dependency_versions_json())
  testthat::expect_setequal(names(versions), c("R", "ledgr", "collapse", "duckdb", "DBI", "digest", "yyjsonr",
                                                "tibble", "TTR"))
})

testthat::test_that("[Cut 24 adapters] certification outcomes equal the cut base on every witness", {
  expected <- utils::read.csv(testthat::test_path("fixtures", "cut24-certification-outcomes.csv"),
                              stringsAsFactors = FALSE, colClasses = "character", na.strings = "NA")
  witnesses <- suppressWarnings(cut24_certification_witnesses())
  # The witness population is the expected one: every catalogue row and the
  # hostile definitions, none lost from both.
  testthat::expect_identical(names(witnesses), expected$witness)
  testthat::expect_identical(sum(grepl("^row:", expected$witness)), 48L)
  observed <- cut24_certification_outcomes(witnesses)
  observed[] <- lapply(observed, as.character)
  testthat::expect_identical(observed, expected)
  # The adapter that matched computes the definition.
  cert <- ledgr:::ledgr_feature_certify(witnesses[["row:TTR:SMA:value:default"]])
  testthat::expect_identical(cert$segment, ledgr:::ledgr_feature_adapter_ttr_segment)
  cert <- ledgr:::ledgr_feature_certify(witnesses[["row:ledgr:sma:value:default"]])
  testthat::expect_identical(cert$segment, ledgr:::ledgr_feature_adapter_ledgr_segment)
  cert <- ledgr:::ledgr_feature_certify(witnesses[["edited_id"]])
  testthat::expect_null(cert$segment)
})

testthat::test_that("[Cut 24 adapters] the engine version binds the adapters", {
  bound_source <- paste(deparse(body(ledgr:::ledgr_feature_engine_version)), collapse = "\n")
  testthat::expect_match(bound_source, "ledgr_feature_adapters()", fixed = TRUE)
  for (adapter in ledgr:::ledgr_feature_adapters()) {
    testthat::expect_true(all(vapply(adapter$bind, exists, logical(1), envir = asNamespace("ledgr"), inherits = FALSE)))
  }
})
