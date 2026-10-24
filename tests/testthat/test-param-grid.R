testthat::test_that("rectangular strategy grids preserve row order and primitive types", {
  frame <- data.frame(
    n = c(2L, 3L),
    threshold = c(0.1, 0.2),
    enabled = c(TRUE, FALSE),
    method = c("a", "b"),
    row.names = c("ignored-b", "ignored-a"),
    stringsAsFactors = FALSE
  )
  grid <- ledgr:::ledgr_executable_grid_normalize(frame)
  expected <- ledgr:::ledgr_executable_grid_normalize(
    ledgr_strategy_grid(
      n = c(2L, 3L),
      threshold = c(0.1, 0.2),
      enabled = c(TRUE, FALSE),
      method = c("a", "b"),
      .filter = (n == 2L & threshold == 0.1 & enabled & method == "a") |
        (n == 3L & threshold == 0.2 & !enabled & method == "b")
    )
  )

  testthat::expect_identical(grid$labels, expected$labels)
  testthat::expect_identical(grid$params, expected$params)
  testthat::expect_identical(grid$identity_params, expected$identity_params)
  testthat::expect_identical(
    vapply(grid$params, function(x) typeof(x$strategy_params$n), character(1)),
    c("integer", "integer")
  )
  testthat::expect_identical(
    lapply(grid$params, `[[`, "feature_params"),
    list(list(), list())
  )
})

testthat::test_that("rectangular strategy-grid boundaries fail before execution", {
  normalize <- ledgr:::ledgr_executable_grid_normalize
  empty <- data.frame(x = integer())
  duplicate_zero <- data.frame(row.names = 1:2)
  duplicate_names <- structure(data.frame(1:2, 3:4), names = c("x", "x"))
  empty_name <- structure(data.frame(1:2), names = "")

  testthat::expect_error(normalize(empty), class = "ledgr_invalid_grid")
  testthat::expect_error(normalize(duplicate_zero), class = "ledgr_duplicate_grid_rows")
  testthat::expect_error(normalize(duplicate_names), class = "ledgr_invalid_grid")
  testthat::expect_error(normalize(empty_name), class = "ledgr_invalid_grid")
  testthat::expect_error(normalize(data.frame(x = c(1L, 1L))), class = "ledgr_duplicate_grid_rows")
  testthat::expect_error(normalize(data.frame(x = c(1L, NA_integer_))), class = "ledgr_invalid_grid_value")
  testthat::expect_error(normalize(data.frame(x = c(TRUE, NA))), class = "ledgr_invalid_grid_value")
  testthat::expect_error(normalize(data.frame(x = c(1, NA_real_))), class = "ledgr_invalid_grid_value")
  testthat::expect_error(normalize(data.frame(x = c("a", NA_character_))), class = "ledgr_invalid_grid_value")
  testthat::expect_error(normalize(data.frame(x = c(1, Inf))), class = "ledgr_invalid_grid_value")
  testthat::expect_error(normalize(data.frame(x = c(1, -Inf))), class = "ledgr_invalid_grid_value")
  testthat::expect_error(normalize(data.frame(x = c(1, NaN))), class = "ledgr_invalid_grid_value")
  testthat::expect_error(normalize(data.frame(x = factor("a"))), class = "ledgr_invalid_grid_column")
  testthat::expect_error(normalize(data.frame(x = as.Date("2020-01-01"))), class = "ledgr_invalid_grid_column")
  testthat::expect_error(normalize(data.frame(x = as.POSIXct("2020-01-01", tz = "UTC"))), class = "ledgr_invalid_grid_column")
  testthat::expect_error(normalize(data.frame(x = I(list(1L)))), class = "ledgr_invalid_grid_column")
  testthat::expect_error(normalize(data.frame(x = 1 + 1i)), class = "ledgr_invalid_grid_column")
  testthat::expect_error(normalize(data.frame(x = I(as.raw(1L)))), class = "ledgr_invalid_grid_column")

  one_empty <- normalize(data.frame(row.names = 1L))
  testthat::expect_length(one_empty$params, 1L)
  testthat::expect_identical(one_empty$params[[1]]$strategy_params, list())
})

testthat::test_that("[LTB-0496] the retired parameter-grid API is absent", {
  exports <- getNamespaceExports("ledgr")
  retired <- c(
    paste0("ledgr_", "param_grid"),
    paste0("ledgr_invalid_", "param_grid"),
    paste0("ledgr_duplicate_", "param_grid", "_labels")
  )
  testthat::expect_false(any(retired %in% exports))
  testthat::expect_false(any(vapply(
    retired,
    exists,
    logical(1),
    envir = asNamespace("ledgr"),
    inherits = FALSE
  )))
  testthat::expect_true("ledgr_sweep" %in% exports)
  testthat::expect_false("ledgr_tune" %in% exports)

  root <- testthat::test_path("..", "..")
  files <- c(
    file.path(root, "NAMESPACE"),
    file.path(root, "_pkgdown.yml"),
    list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE),
    list.files(file.path(root, "man"), pattern = "[.]Rd$", full.names = TRUE),
    list.files(file.path(root, "vignettes"), pattern = "[.](qmd|Rmd|md)$", full.names = TRUE),
    list.files(file.path(root, "tests", "testthat"), pattern = "[.]R$", full.names = TRUE)
  )
  files <- files[file.exists(files)]
  occurrences <- vapply(files, function(path) {
    text <- readLines(path, warn = FALSE)
    any(vapply(retired, function(name) any(grepl(name, text, fixed = TRUE)), logical(1)))
  }, logical(1))
  testthat::expect_false(any(occurrences), info = paste(files[occurrences], collapse = ", "))
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0494] rectangular strategy grids keep identity and namespaces", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets[["AAA"]] <- params$n
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  invalid_exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      ctx$flat()
    },
    cost_model = ledgr_cost_zero()
  )
  invalid <- list(
    data.frame(x = integer()),
    data.frame(row.names = 1:2),
    structure(data.frame(1:2, 3:4), names = c("x", "x")),
    structure(data.frame(1:2), names = ""),
    data.frame(x = c(1L, 1L)),
    data.frame(x = c(1L, NA_integer_)),
    data.frame(x = c(TRUE, NA)),
    data.frame(x = c(1, NA_real_)),
    data.frame(x = c("a", NA_character_)),
    data.frame(x = c(1, Inf)),
    data.frame(x = c(1, -Inf)),
    data.frame(x = c(1, NaN)),
    data.frame(x = factor("a")),
    data.frame(x = as.Date("2020-01-01")),
    data.frame(x = as.POSIXct("2020-01-01", tz = "UTC")),
    data.frame(x = I(list(1L))),
    data.frame(x = 1 + 1i),
    data.frame(x = I(as.raw(1L)))
  )
  for (bad in invalid) {
    testthat::expect_error(ledgr_sweep(invalid_exp, bad), class = "ledgr_invalid_grid")
  }
  empty_exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    cost_model = ledgr_cost_zero()
  )
  empty_candidate <- ledgr_sweep(empty_exp, data.frame(row.names = 1L))
  testthat::expect_identical(empty_candidate$status, "DONE")
  testthat::expect_identical(empty_candidate$params, list(list()))
  testthat::expect_error(
    ledgr:::ledgr_grid_candidate_feature_params(list(n = 2L)),
    class = "ledgr_invalid_executable_grid"
  )
  rectangular <- tidyr::crossing(
    n = c(1L, 2L), threshold = c(0.1, 0.2), enabled = TRUE, method = "a"
  )
  constructed <- ledgr_strategy_grid(
    n = c(1L, 2L), threshold = c(0.1, 0.2), enabled = TRUE, method = "a"
  )

  canonical_calls <- 0L
  original_canonical_json <- ledgr:::canonical_json
  normalized <- testthat::with_mocked_bindings(
    ledgr_executable_grid_normalize(rectangular),
    canonical_json = function(x, ...) {
      canonical_calls <<- canonical_calls + 1L
      original_canonical_json(x, ...)
    },
    .package = "ledgr"
  )
  testthat::expect_identical(canonical_calls, nrow(rectangular))
  testthat::expect_identical(
    vapply(normalized$params, function(x) x$strategy_params$n, integer(1)),
    c(1L, 1L, 2L, 2L)
  )
  testthat::expect_identical(
    vapply(normalized$params, function(x) x$strategy_params$threshold, double(1)),
    c(0.1, 0.2, 0.1, 0.2)
  )

  calls <- 0L
  original <- ledgr:::ledgr_strategy_grid_from_frame
  testthat::local_mocked_bindings(
    ledgr_strategy_grid_from_frame = function(x, arg = "param_grid") {
      calls <<- calls + 1L
      original(x, arg = arg)
    },
    .package = "ledgr"
  )
  from_frame <- ledgr_sweep(exp, rectangular, seed = 901L)
  from_constructor <- ledgr_sweep(exp, constructed, seed = 901L)
  testthat::expect_identical(calls, 1L)
  testthat::expect_identical(
    vapply(from_frame$params, function(x) x$n, integer(1)),
    c(1L, 1L, 2L, 2L)
  )
  testthat::expect_identical(
    vapply(from_constructor$params, function(x) x$n, integer(1)),
    c(1L, 2L, 1L, 2L)
  )
  testthat::expect_setequal(from_frame$candidate_id, from_constructor$candidate_id)
  constructor_match <- match(from_frame$candidate_id, from_constructor$candidate_id)
  testthat::expect_false(anyNA(constructor_match))
  aligned_constructor <- from_constructor[constructor_match, , drop = FALSE]
  testthat::expect_identical(from_frame$params, aligned_constructor$params)
  testthat::expect_identical(from_frame$feature_params, rep(list(list()), 4L))
  testthat::expect_identical(from_frame$execution_seed, aligned_constructor$execution_seed)
  testthat::expect_identical(from_frame$final_equity, aligned_constructor$final_equity)
  frame_rows <- ledgr:::ledgr_sweep_storage_candidate_rows(from_frame, sweep_id = "same")
  constructor_rows <- ledgr:::ledgr_sweep_storage_candidate_rows(from_constructor, sweep_id = "same")
  constructor_rows <- constructor_rows[
    match(frame_rows$candidate_id, constructor_rows$candidate_id),
    ,
    drop = FALSE
  ]
  persisted_payload <- setdiff(names(frame_rows), "candidate_row")
  testthat::expect_identical(
    frame_rows[persisted_payload],
    constructor_rows[persisted_payload]
  )
  testthat::expect_identical(frame_rows$candidate_row, seq_len(nrow(frame_rows)))
  testthat::expect_identical(constructor_rows$candidate_row, constructor_match)

  saved_id <- ledgr_sweep_save(from_frame, snapshot, sweep_id = "rectangular")
  reopened <- ledgr_sweep_open(snapshot, saved_id)
  testthat::expect_identical(reopened$params, from_frame$params)
  testthat::expect_identical(reopened$feature_params, from_frame$feature_params)
  testthat::expect_identical(reopened$execution_seed, from_frame$execution_seed)

  promoted_id <- from_frame$candidate_id[[1L]]
  live_run <- ledgr_promote(exp, ledgr_candidate(from_frame, promoted_id), run_id = "rect_live")
  reopened_run <- ledgr_promote(exp, ledgr_candidate(reopened, promoted_id), run_id = "rect_reopened")
  live_context <- ledgr_promotion_context(live_run)
  reopened_context <- ledgr_promotion_context(reopened_run)
  ignored <- c("run_id", "promoted_at_utc", "source_sweep")
  testthat::expect_identical(
    live_context[setdiff(names(live_context), ignored)],
    reopened_context[setdiff(names(reopened_context), ignored)]
  )

  fmap <- ledgr_feature_map(signal = ledgr_ind_sma(ledgr_param("n")))
  feature_exp <- ledgr_experiment(snapshot, strategy, features = fmap, cost_model = ledgr_cost_zero())
  strategy_only <- ledgr:::ledgr_executable_grid_normalize(data.frame(n = 2L))
  unresolved <- ledgr:::ledgr_resolve_feature_candidates(feature_exp, strategy_only)
  testthat::expect_identical(unresolved$candidate_features$feature_params, list(list()))
  testthat::expect_identical(unresolved$candidate_features$status, "failed")
  testthat::expect_identical(unresolved$candidate_features$error_class, "ledgr_param_missing")
  composed <- ledgr_grid_cross(
    features = ledgr_feature_grid(n = 2L),
    strategy = data.frame(n = 7L)
  )
  resolved <- ledgr:::ledgr_resolve_feature_candidates(feature_exp, composed, stop_on_error = TRUE)
  testthat::expect_identical(resolved$candidate_features$feature_params, list(list(n = 2L)))
  testthat::expect_identical(resolved$candidate_features$params, list(list(n = 7L)))
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0495] sweep prints show readable parameter namespaces", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:3)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(
    empty = list(),
    strategy_only = list(strategy = list(qty = 1L)),
    feature_only = list(feature = list(n = 2L)),
    composed = list(feature = list(n = 3L), strategy = list(qty = 2L))
  )
  sweep <- ledgr_sweep(exp, grid, seed = 71L)
  sweep$status <- c("DONE", "INCOMPLETE", "FAILED", "DONE")
  before <- serialize(sweep, NULL, version = 3L)
  expect_namespace_rows <- function(text) {
    testthat::expect_true(any(grepl(
      '"{\\"qty\\":1}"   "{}"           strategy_only',
      text,
      fixed = TRUE
    )))
    testthat::expect_true(any(grepl(
      '"{}"            "{\\"n\\":2}"    feature_only',
      text,
      fixed = TRUE
    )))
    testthat::expect_true(any(grepl(
      '"{\\"qty\\":2}"   "{\\"n\\":3}"    composed',
      text,
      fixed = TRUE
    )))
  }
  for (width in c(60L, 140L)) {
    printed <- utils::capture.output(print(sweep, width = width))
    testthat::expect_true(any(grepl("strategy_params", printed, fixed = TRUE)))
    testthat::expect_true(any(grepl("feature_params", printed, fixed = TRUE)))
    header <- printed[grepl("candidate_id", printed, fixed = TRUE)][[1L]]
    testthat::expect_lt(regexpr("strategy_params", header, fixed = TRUE)[[1L]], regexpr("candidate_id", header, fixed = TRUE)[[1L]])
    expect_namespace_rows(printed)
  }
  testthat::expect_identical(serialize(sweep, NULL, version = 3L), before)

  sweep_id <- ledgr_sweep_save(sweep, snapshot, sweep_id = "print_namespaces")
  reopened <- ledgr_sweep_open(snapshot, sweep_id)
  testthat::expect_identical(reopened$status, sweep$status)
  reopened_text <- utils::capture.output(print(reopened, width = 60L))
  expect_namespace_rows(reopened_text)

  candidate_text <- utils::capture.output(print(ledgr_candidate(sweep, 4L)))
  testthat::expect_lt(
    which(grepl("Strategy params", candidate_text, fixed = TRUE))[[1L]],
    which(grepl("Candidate ID", candidate_text, fixed = TRUE))[[1L]]
  )
  testthat::expect_true(any(grepl("Strategy params:  {\"qty\":2}", candidate_text, fixed = TRUE)))
  testthat::expect_true(any(grepl("Feature params:   {\"n\":3}", candidate_text, fixed = TRUE)))
  review <- ledgr_sweep_review(sweep, rank_by = desc(total_return), n = 4L)
  reopened_review <- ledgr_sweep_review(reopened, rank_by = desc(total_return), n = 4L)
  for (name in names(review$top)) {
    testthat::expect_identical(reopened_review$top[[name]], review$top[[name]])
  }
  for (name in names(review$issues)) {
    testthat::expect_identical(reopened_review$issues[[name]], review$issues[[name]])
  }
  for (width in c(60L, 140L)) {
    review_text <- utils::capture.output(print(review, width = width))
    testthat::expect_true(any(grepl("strategy_params", review_text, fixed = TRUE)))
    testthat::expect_true(any(grepl("feature_params", review_text, fixed = TRUE)))
    expect_namespace_rows(review_text)
  }

  long <- ledgr_grid_named(long = list(strategy = list(
    description = paste(rep("long-value", 20L), collapse = "-")
  )))
  long_sweep <- ledgr_sweep(exp, long)
  testthat::expect_true(any(grepl(
    "ledgr_candidate()", utils::capture.output(print(long_sweep, width = 140L)),
    fixed = TRUE
  )))
})
