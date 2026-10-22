# ledgr-test-file-profile: review

testthat::test_that("[LTB-0407] history results expose their metadata, align solver weights and default the sufficiency lookback", {
  captured <- ws42_capture_run(reader = function(ctx) {
    list(
      fast = ledgr_history_frame(ctx, feature = "fast", lookback = 2L,
        instruments = "decision_axis", na_action = "drop_instruments"),
      fast_long = ledgr_history_frame(ctx, feature = "fast", lookback = 2L,
        instruments = "decision_axis", na_action = "drop_instruments", layout = "long"),
      close_all = ledgr_history_frame(ctx, bar = "close"),
      fast_admissible = ledgr_history_frame(ctx, feature = "fast", lookback = 2L,
        na_action = "drop_instruments")
    )
  })
  on.exit({
    close(captured$bt)
    ledgr_snapshot_close(captured$fixture$snapshot)
  }, add = TRUE)
  axis <- captured$fixture$axis
  at7 <- captured$seen[[ws42_iso(axis[[7L]])]]

  # Session 7: CCC is a known-inactive member on the decision axis. SMA(2) of
  # AAA (10 + k) is 15.5, 16.5 and of BBB (20 + k) 25.5, 26.5 over sessions
  # 6-7; CCC has no calculation in the window and leaves the sample.
  fast <- at7$fast
  info <- ledgr_history_info(fast)
  testthat::expect_s3_class(info, "ledgr_history_info")
  testthat::expect_identical(info$source, "feature:sma_2")
  testthat::expect_identical(info$source_kind, "feature")
  testthat::expect_identical(info$source_id, "sma_2")
  testthat::expect_identical(as.numeric(info$cutoff_utc), as.numeric(axis[[7L]]))
  testthat::expect_identical(as.numeric(info$data_start_utc), as.numeric(axis[[1L]]))
  testthat::expect_identical(as.numeric(info$window_start_utc), as.numeric(axis[[6L]]))
  testthat::expect_identical(info$requested_lookback, 2L)
  testthat::expect_identical(info$available_lookback, 2L)
  testthat::expect_identical(info$instruments, "decision_axis")
  testthat::expect_identical(info$na_action, "drop_instruments")
  testthat::expect_identical(info$layout, "wide")
  testthat::expect_identical(info$included_ids, c("AAA", "BBB"))
  testthat::expect_identical(info$excluded_ids, "CCC")
  testthat::expect_s3_class(info$selection, "tbl_df")
  testthat::expect_identical(info$selection$instrument_id, c("AAA", "BBB", "CCC"))
  testthat::expect_identical(info$selection$included, c(TRUE, TRUE, FALSE))
  testthat::expect_true(nzchar(info$selection$exclusion_reason[[3L]]))
  testthat::expect_identical(info$selection$admissibility_reason[[3L]], "lifetime_inactive")
  testthat::expect_true(is.logical(info$used_before_window) && length(info$used_before_window) == 1L)
  testthat::expect_identical(dim(info$evidence$calculation_valid), c(2L, 2L))
  testthat::expect_identical(info$policy_identity$price_carry, 5L)
  # The accessor returns the recorded metadata, not a second reading.
  meta <- attr(fast, "ledgr_history")
  testthat::expect_identical(info$selection, tibble::as_tibble(meta$selection))
  testthat::expect_identical(info$used_before_window, meta$used_before_window)
  testthat::expect_identical(ledgr_history_info(at7$fast_long)$included_ids, c("AAA", "BBB"))
  testthat::expect_null(ledgr_history_info(at7$fast_long)$evidence)
  info_printed <- utils::capture.output(print(info))
  testthat::expect_true("Excluded:     CCC (" %in% substr(info_printed, 1L, 19L))
  testthat::expect_true("# i Selection table: info$selection" %in% info_printed)

  # The print footer names the accessor.
  testthat::expect_true(
    "# i Selection, exclusions and window: ledgr_history_info(x)" %in% utils::capture.output(print(fast))
  )

  # Like the matrix adapter, the accessor refuses a result that no longer
  # matches its recorded axis and instruments.
  broken <- fast
  broken$BBB <- NULL
  testthat::expect_error(ledgr_history_info(broken), class = "ledgr_invalid_history_result")
  testthat::expect_error(ledgr_align_weights(c(0.5, 0.5), broken), class = "ledgr_invalid_history_result")
  testthat::expect_error(ledgr_history_info(data.frame(x = 1)), class = "ledgr_invalid_history_result")
  # Sufficiency refuses the same stale results (close review 44a F3): a
  # result whose rows were filtered keeps its class and metadata but no
  # longer matches its recorded two sessions.
  filtered <- fast[2L, , drop = FALSE]
  attr(filtered, "ledgr_history") <- attr(fast, "ledgr_history")
  class(filtered) <- class(fast)
  testthat::expect_error(ledgr_history_sufficient(filtered), class = "ledgr_invalid_history_result")
  testthat::expect_error(ledgr_history_sufficient(broken, lookback = 1L), class = "ledgr_invalid_history_result")
  # The long layout is checked the same way (re-review 1 R3): keeping only
  # AAA's rows leaves a result that no longer holds its recorded instruments.
  long_filtered <- at7$fast_long[at7$fast_long$instrument_id == "AAA", , drop = FALSE]
  attr(long_filtered, "ledgr_history") <- attr(at7$fast_long, "ledgr_history")
  class(long_filtered) <- class(at7$fast_long)
  testthat::expect_error(
    ledgr_history_sufficient(long_filtered, min_instruments = 2L),
    class = "ledgr_invalid_history_result"
  )
  # Under the "admissible" selector CCC is not requested at session 7, so it
  # is not an excluded instrument (close review 44a N2).
  admissible_info <- ledgr_history_info(at7$fast_admissible)
  testthat::expect_identical(admissible_info$included_ids, c("AAA", "BBB"))
  testthat::expect_identical(admissible_info$excluded_ids, character())
  testthat::expect_identical(
    admissible_info$selection$requested[admissible_info$selection$instrument_id == "CCC"],
    FALSE
  )

  # Solver output becomes identified weights without colnames(): an unnamed
  # vector in the matrix column order, a named vector in any order, and a
  # one-column matrix all give AAA = 0.25, BBB = 0.75.
  expected <- ledgr_weights(c(AAA = 0.25, BBB = 0.75), origin = "ledgr_align_weights")
  testthat::expect_identical(colnames(ledgr_history_matrix(fast)), c("AAA", "BBB"))
  testthat::expect_identical(ledgr_align_weights(c(0.25, 0.75), fast), expected)
  testthat::expect_identical(ledgr_align_weights(c(BBB = 0.75, AAA = 0.25), fast), expected)
  testthat::expect_identical(ledgr_align_weights(matrix(c(0.25, 0.75), ncol = 1L), fast), expected)
  testthat::expect_identical(
    ledgr_align_weights(matrix(c(0.25, 0.75), nrow = 1L, dimnames = list(NULL, c("AAA", "BBB"))), fast),
    expected
  )
  testthat::expect_identical(ledgr_align_weights(c(0.25, 0.75), at7$fast_long), expected)
  for (bad in list(c(0.5, 0.25, 0.25), 1, numeric(), c(AAA = 0.5, CCC = 0.5), c(AAA = 0.5, AAA = 0.5),
                   matrix(1, 2L, 2L), "0.5")) {
    testthat::expect_error(ledgr_align_weights(bad, fast), class = "ledgr_weight_alignment_mismatch")
  }
  testthat::expect_error(ledgr_align_weights(c(0.5, NA), fast), class = "ledgr_invalid_strategy_type")
  # Three included instruments at session 6 (CCC's inactivity is not yet
  # known): names in a cyclic order are matched by name, not by a
  # permutation of positions (close review 44a N2).
  fast6 <- captured$seen[[ws42_iso(axis[[6L]])]]$fast
  testthat::expect_identical(ledgr_history_info(fast6)$included_ids, c("AAA", "BBB", "CCC"))
  testthat::expect_identical(
    ledgr_align_weights(c(BBB = 0.2, CCC = 0.3, AAA = 0.5), fast6),
    ledgr_weights(c(AAA = 0.5, BBB = 0.2, CCC = 0.3), origin = "ledgr_align_weights")
  )

  # Sufficiency defaults to the finite lookback the result was read with and
  # refuses to guess one for a full-lookback read.
  testthat::expect_true(ledgr_history_sufficient(fast))
  testthat::expect_true(ledgr_history_sufficient(fast, min_instruments = 2L))
  testthat::expect_false(ledgr_history_sufficient(fast, min_instruments = 3L))
  testthat::expect_false(ledgr_history_sufficient(fast, lookback = 3L))
  testthat::expect_error(ledgr_history_sufficient(at7$close_all), class = "ledgr_invalid_history_request")
  testthat::expect_true(ledgr_history_sufficient(at7$close_all, lookback = 7L))
  testthat::expect_false(ledgr_history_sufficient(at7$close_all, lookback = 8L))
  at1 <- captured$seen[[ws42_iso(axis[[1L]])]]
  # Session 1 holds one of the two requested sessions.
  testthat::expect_false(ledgr_history_sufficient(at1$fast))

  # A strategy using all three runs at Tier 1 and turns weights into targets.
  # At session 6 CCC's inactivity is not yet known, so it is admissible and
  # its SMA (35, from a carried close) is complete: three instruments are
  # included and each gets 1/3. With AAA at 16, BBB at 26 and cash 1000 the
  # rebalance buys floor(1000 / 3 / 16) = 20 AAA and floor(1000 / 3 / 26) = 12
  # BBB, filled at session 7's open; CCC has no current close, so its share is
  # skipped and not redistributed.
  strategy <- function(ctx, params) {
    if (!identical(ctx$ts_utc, "2021-01-11T21:00:00Z")) return(ctx$hold())
    returns <- ledgr_history_frame(ctx, feature = "fast", lookback = 2L, na_action = "drop_instruments")
    if (!ledgr_history_sufficient(returns, min_instruments = 2L)) return(ctx$hold())
    n <- length(ledgr_history_info(returns)$included_ids)
    ledgr_target_rebalance(ledgr_align_weights(rep(1 / n, n), returns), ctx, equity_fraction = 1)
  }
  testthat::expect_identical(ledgr_strategy_preflight(strategy)$tier, "tier_1")
  bought <- ws42_history_fixture(strategy = strategy)
  on.exit(ledgr_snapshot_close(bought$snapshot), add = TRUE)
  bt <- ledgr_run(bought$exp, run_id = "bridge-run")
  on.exit(close(bt), add = TRUE)
  fills <- as.data.frame(ledgr_results(bt, "fills"))
  testthat::expect_identical(fills$instrument_id, c("AAA", "BBB"))
  testthat::expect_identical(as.numeric(fills$qty), c(20, 12))
  testthat::expect_identical(as.numeric(fills$price), c(17, 27))
})

testthat::test_that("[LTB-0417] ledgr_align_weights takes the solution first and refuses missing names and non-finite weights by their own classes", {
  captured <- ws42_capture_run(reader = function(ctx) {
    ledgr_history_frame(ctx, feature = "fast", lookback = 2L,
      instruments = "decision_axis", na_action = "drop_instruments")
  })
  on.exit({
    close(captured$bt)
    ledgr_snapshot_close(captured$fixture$snapshot)
  }, add = TRUE)
  # Session 7 of the WS42 fixture includes AAA and BBB (LTB-0407).
  fast <- captured$seen[[ws42_iso(captured$fixture$axis[[7L]])]]
  testthat::expect_identical(ledgr_history_info(fast)$included_ids, c("AAA", "BBB"))

  # The solver output is the first argument, so it pipes into the bridge and
  # the bridge's origin names it.
  testthat::expect_identical(names(formals(ledgr_align_weights)), c("solution", "history"))
  piped <- c(0.25, 0.75) |> ledgr_align_weights(fast)
  testthat::expect_identical(piped, ledgr_weights(c(AAA = 0.25, BBB = 0.75), origin = "ledgr_align_weights"))
  testthat::expect_identical(attr(piped, "origin"), "ledgr_align_weights")
  testthat::expect_identical(ledgr_align_weights(history = fast, solution = c(BBB = 0.75, AAA = 0.25)), piped)

  # A missing name (empty or NA) among named weights cannot be aligned and
  # refuses with the alignment class, which is also ledgr_invalid_args.
  missing_names <- list(
    c(AAA = 0.25, 0.75),
    stats::setNames(c(0.25, 0.75), c("AAA", NA)),
    matrix(c(0.25, 0.75), nrow = 1L, dimnames = list(NULL, c("", "BBB")))
  )
  for (bad in missing_names) {
    cnd <- tryCatch(ledgr_align_weights(bad, fast), error = function(e) e)
    testthat::expect_s3_class(cnd, "ledgr_weight_alignment_mismatch")
    testthat::expect_s3_class(cnd, "ledgr_invalid_args")
  }

  # A three-dimensional array or a character vector whose length matches the
  # included instruments reaches only the shape and type refusals.
  for (bad in list(array(c(0.25, 0.75), c(1L, 1L, 2L)), c("0.25", "0.75"))) {
    cnd <- tryCatch(ledgr_align_weights(bad, fast), error = function(e) e)
    testthat::expect_s3_class(cnd, "ledgr_weight_alignment_mismatch")
  }
  # The history is validated before the solution.
  testthat::expect_error(ledgr_align_weights("0.5", data.frame(x = 1)),
    class = "ledgr_invalid_history_result")

  # A missing or non-finite weight in an aligned solution refuses through
  # ledgr_weights() with ledgr_invalid_strategy_type, never the alignment class.
  for (bad in list(c(0.25, Inf), c(NaN, 0.75), c(BBB = -Inf, AAA = 0.25), c(NA_real_, 0.75))) {
    cnd <- tryCatch(ledgr_align_weights(bad, fast), error = function(e) e)
    testthat::expect_s3_class(cnd, "ledgr_invalid_strategy_type")
    testthat::expect_false(inherits(cnd, "ledgr_weight_alignment_mismatch"))
  }
})

# Files of the current public surface: exports, help, code, articles, the
# reference index, NEWS and the contracts.
ws44_current_surface_files <- function(root) {
  text <- "[.](R|Rd|qmd|Rmd|md)$"
  c(
    file.path(root, "NAMESPACE"),
    list.files(file.path(root, "man"), pattern = text, full.names = TRUE, recursive = TRUE),
    list.files(file.path(root, "R"), pattern = text, full.names = TRUE, recursive = TRUE),
    list.files(file.path(root, "vignettes"), pattern = text, full.names = TRUE, recursive = TRUE),
    file.path(root, "_pkgdown.yml"),
    file.path(root, "NEWS.md"),
    file.path(root, "inst", "design", "contracts.md")
  )
}

# Files among `files` whose text contains `name`.
ws44_files_naming <- function(files, name) {
  files[vapply(files, function(path) {
    any(grepl(name, readLines(path, warn = FALSE, encoding = "UTF-8"), fixed = TRUE))
  }, logical(1))]
}

testthat::test_that("[LTB-0418] the superseded weights bridge name is absent from every current surface", {
  # Assembled so this block does not name the old bridge itself; the stem
  # also matches the old condition class (stem plus "_mismatch").
  old <- paste0("ledgr_history", "_weights")
  testthat::expect_false(exists(old, envir = asNamespace("ledgr"), inherits = FALSE))
  testthat::expect_false(old %in% getNamespaceExports("ledgr"))
  testthat::expect_true("ledgr_align_weights" %in% getNamespaceExports("ledgr"))
  root <- ledgr_test_source_root()
  if (!ledgr_test_checkout_context(root)) return(invisible(NULL))
  files <- ws44_current_surface_files(root)
  testthat::expect_true(all(file.exists(files)))
  testthat::expect_true(file.path(root, "man", "ledgr_align_weights.Rd") %in% files)
  testthat::expect_false(file.exists(file.path(root, "man", paste0(old, ".Rd"))))
  testthat::expect_identical(ws44_files_naming(files, old), character())
  # The scan reads the surfaces it claims: the new names are found in them.
  testthat::expect_true(file.path(root, "NAMESPACE") %in% ws44_files_naming(files, "ledgr_align_weights"))
  testthat::expect_true(
    file.path(root, "inst", "design", "contracts.md") %in%
      ws44_files_naming(files, "ledgr_weight_alignment_mismatch")
  )
})
