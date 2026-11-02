ws17_dense_fixture <- function(strategy, asset_state = list(), portfolio_state = list(), days = 4L) {
  ids <- c("BBB", "AAA")
  bars <- data.frame(
    instrument_id = rep(ids, each = days),
    ts_utc = rep(as.POSIXct("2024-01-01", tz = "UTC") + 86400 * seq_len(days) - 86400, 2L),
    open = 10, high = 10, low = 10, close = 10, volume = 1000
  )
  snapshot <- ledgr_snapshot_from_df(bars)
  list(
    snapshot = snapshot,
    exp = ledgr_experiment(
      snapshot, strategy,
      opening = ledgr_opening(cash = 1000),
      cost_model = ledgr_cost_zero(),
      asset_state = asset_state,
      portfolio_state = portfolio_state
    )
  )
}

# ledgr-test-profile: fast
testthat::test_that("[LTB-0532] declared state preserves type, missingness and axis", {
  declaration <- ledgr:::ledgr_strategy_state_normalize(
    asset_state = list(peak = NA_real_, count = NA_integer_),
    portfolio_state = list(flag = NA, regime = NA_character_, whole = 2)
  )
  axis <- c("BBB", "AAA")
  state <- ledgr:::ledgr_strategy_state_defaults(declaration, axis)
  testthat::expect_type(state$peak, "double")
  testthat::expect_type(state$count, "integer")
  testthat::expect_type(state$flag, "logical")
  testthat::expect_type(state$regime, "character")
  testthat::expect_identical(names(state$peak), axis)
  state$peak <- c(BBB = 4, AAA = NA_real_)
  state$count <- c(BBB = 1L, AAA = 2L)
  state$flag <- TRUE
  state$regime <- "risk_on"
  json <- ledgr:::ledgr_strategy_state_encode(state, declaration, axis)
  decoded <- ledgr:::ledgr_strategy_state_decode(json, declaration)
  testthat::expect_identical(decoded$values, state)
  testthat::expect_identical(decoded$axis, axis)
  testthat::expect_type(decoded$values$whole, "double")
  testthat::expect_false(identical(json, ledgr:::ledgr_strategy_state_cursor_marker))
  testthat::expect_error(
    ledgr:::ledgr_strategy_state_decode(
      ledgr:::ledgr_strategy_state_cursor_marker, declaration
    ),
    class = "ledgr_invalid_strategy_state"
  )

  empty_state <- ledgr:::ledgr_strategy_state_defaults(declaration, character())
  empty_decoded <- ledgr:::ledgr_strategy_state_decode(
    ledgr:::ledgr_strategy_state_encode(empty_state, declaration, character()),
    declaration
  )
  testthat::expect_identical(empty_decoded$axis, character())
  testthat::expect_identical(empty_decoded$values$peak, stats::setNames(numeric(), character()))

  reordered <- ledgr:::ledgr_strategy_state_align(
    decoded$values, declaration, decoded$axis, c("AAA", "CCC", "BBB")
  )
  testthat::expect_identical(reordered$peak, c(AAA = NA_real_, CCC = NA_real_, BBB = 4))
  testthat::expect_identical(reordered$count, c(AAA = 2L, CCC = NA_integer_, BBB = 1L))

  testthat::expect_error(
    ledgr:::ledgr_strategy_state_normalize(list(x = 1), list(x = 2)),
    class = "ledgr_invalid_strategy_state"
  )
  testthat::expect_error(
    ledgr:::ledgr_strategy_state_normalize(list(targets = 1), list()),
    class = "ledgr_invalid_strategy_state"
  )
  testthat::expect_error(
    ledgr:::ledgr_strategy_state_normalize(list(x = list(1)), list()),
    class = "ledgr_invalid_strategy_state"
  )
  testthat::expect_error(
    ledgr:::ledgr_strategy_state_normalize(list(x = NaN), list()),
    class = "ledgr_invalid_strategy_state"
  )
  testthat::expect_error(
    ledgr:::ledgr_strategy_state_normalize(list(x = Inf), list()),
    class = "ledgr_invalid_strategy_state"
  )
  testthat::expect_error(
    ledgr:::ledgr_strategy_state_apply_values(
      state, list(peak = c(AAA = 1, OFF = 2)), declaration, axis, patch = TRUE
    ),
    class = "ledgr_invalid_strategy_state"
  )
  view <- ledgr:::ledgr_strategy_state_view(state)
  testthat::expect_error(view$unknown, class = "ledgr_invalid_strategy_state")
  testthat::expect_error(view[["unknown"]], class = "ledgr_invalid_strategy_state")
  frozen_peak <- view$peak
  state$peak[[1L]] <- 99
  testthat::expect_identical(view$peak, frozen_peak)

  tampered <- ledgr:::ledgr_json_read_nested(json)
  tampered$fields[[1L]]$name <- "undeclared"
  testthat::expect_error(
    ledgr:::ledgr_strategy_state_decode(canonical_json(tampered), declaration),
    class = "ledgr_invalid_strategy_state"
  )

  a <- ledgr:::ledgr_strategy_state_normalize(
    asset_state = list(z = 1, a = 2L), portfolio_state = list(flag = FALSE)
  )
  b <- ledgr:::ledgr_strategy_state_normalize(
    portfolio_state = list(flag = FALSE), asset_state = list(a = 2L, z = 1)
  )
  changed_default <- ledgr:::ledgr_strategy_state_normalize(
    asset_state = list(z = 2, a = 2L), portfolio_state = list(flag = FALSE)
  )
  changed_type <- ledgr:::ledgr_strategy_state_normalize(
    asset_state = list(z = 1L, a = 2L), portfolio_state = list(flag = FALSE)
  )
  testthat::expect_identical(
    canonical_json(ledgr:::ledgr_strategy_state_identity(a)),
    canonical_json(ledgr:::ledgr_strategy_state_identity(b))
  )
  testthat::expect_false(identical(
    canonical_json(ledgr:::ledgr_strategy_state_identity(a)),
    canonical_json(ledgr:::ledgr_strategy_state_identity(changed_default))
  ))
  testthat::expect_false(identical(
    canonical_json(ledgr:::ledgr_strategy_state_identity(a)),
    canonical_json(ledgr:::ledgr_strategy_state_identity(changed_type))
  ))

  strategy <- function(ctx, params) ctx$hold()
  make_experiment <- function(asset_state, portfolio_state) {
    ledgr_experiment(
      ws17_dense_fixture(strategy)$snapshot,
      strategy,
      opening = ledgr_opening(cash = 1000),
      cost_model = ledgr_cost_zero(),
      asset_state = asset_state,
      portfolio_state = portfolio_state
    )
  }
  experiments <- list(
    make_experiment(list(z = 1, a = 2L), list(flag = FALSE)),
    make_experiment(list(a = 2L, z = 1), list(flag = FALSE)),
    make_experiment(list(z = 2, a = 2L), list(flag = FALSE)),
    make_experiment(list(z = 1L, a = 2L), list(flag = FALSE))
  )
  on.exit(lapply(experiments, function(x) ledgr_snapshot_close(x$snapshot)), add = TRUE)
  runs <- Map(
    function(exp, run_id) ledgr_run(exp, run_id = run_id),
    experiments,
    paste0("ws17-identity-", seq_along(experiments))
  )
  on.exit(lapply(runs, close), add = TRUE, after = FALSE)
  hashes <- vapply(runs, function(run) ledgr:::config_hash(run$config), character(1L))
  testthat::expect_identical(hashes[[1L]], hashes[[2L]])
  testthat::expect_false(identical(hashes[[1L]], hashes[[3L]]))
  testthat::expect_false(identical(hashes[[1L]], hashes[[4L]]))
  testthat::expect_identical(
    ledgr:::ledgr_store_format_bindings()[["ledgr_strategy_state_rule_version"]],
    1L
  )
  missing_rule <- ledgr:::ledgr_strategy_state_identity(a)
  missing_rule$rule_version <- NULL
  old_rule <- ledgr:::ledgr_strategy_state_identity(a)
  old_rule$rule_version <- 0L
  malformed <- ledgr:::ledgr_strategy_state_identity(a)
  malformed$fields[[1L]]$scope <- NULL
  testthat::expect_error(
    ledgr:::ledgr_strategy_state_from_identity(missing_rule),
    class = "ledgr_invalid_strategy_state"
  )
  testthat::expect_error(
    ledgr:::ledgr_strategy_state_from_identity(old_rule),
    class = "ledgr_invalid_strategy_state"
  )
  testthat::expect_error(
    ledgr:::ledgr_strategy_state_from_identity(malformed),
    class = "ledgr_invalid_strategy_state"
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0533] helper patches and raw replacements stay distinct", {
  strategy <- function(ctx, params) {
    if (ctx$state$count == 0L) {
      return(ledgr_strategy_result(
        ctx$hold(), count = 1L, peak = c(BBB = 3, AAA = 4),
        intent_reason = "patched"
      ))
    }
    if (ctx$state$count == 1L) {
      return(list(targets = ctx$hold(), state_update = list(count = 2L)))
    }
    if (ctx$state$count == 2L) return(ledgr_strategy_result(ctx$hold(), reset_state = TRUE))
    ctx$hold()
  }
  fixture <- ws17_dense_fixture(
    strategy,
    asset_state = list(peak = NA_real_),
    portfolio_state = list(count = 0L, regime = "risk_on"),
    days = 3L
  )
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  run <- ledgr_run(fixture$exp, run_id = "ws17-patch-replace")
  on.exit(close(run), add = TRUE, after = FALSE)
  rows <- DBI::dbGetQuery(
    get_connection(fixture$snapshot),
    "SELECT state_json FROM strategy_state WHERE run_id = 'ws17-patch-replace' ORDER BY ts_utc"
  )
  declaration <- fixture$exp$strategy_state
  decoded <- lapply(rows$state_json[1:3], ledgr:::ledgr_strategy_state_decode,
    declaration = declaration)
  testthat::expect_identical(decoded[[1L]]$values$count, 1L)
  testthat::expect_identical(decoded[[1L]]$values$regime, "risk_on")
  testthat::expect_identical(decoded[[2L]]$values$count, 2L)
  testthat::expect_identical(decoded[[2L]]$values$regime, "risk_on")
  testthat::expect_true(all(is.na(decoded[[2L]]$values$peak)))
  testthat::expect_identical(decoded[[3L]]$values$count, 0L)
  testthat::expect_identical(decoded[[3L]]$values$regime, "risk_on")

  testthat::expect_error(
    ledgr_strategy_result(c(AAA = 0), count = 1L, reset_state = TRUE),
    class = "ledgr_invalid_strategy_state"
  )
  previous <- ledgr:::ledgr_strategy_state_defaults(declaration, c("BBB", "AAA"))
  broadcast <- ledgr:::ledgr_strategy_state_apply_values(
    previous, list(peak = 7), declaration, c("BBB", "AAA"), patch = TRUE
  )
  testthat::expect_identical(broadcast$peak, c(BBB = 7, AAA = 7))
  reset_one <- ledgr:::ledgr_strategy_state_apply_values(
    broadcast, list(peak = c(BBB = NA_real_, AAA = 4)), declaration,
    c("BBB", "AAA"), patch = TRUE
  )
  testthat::expect_identical(reset_one$peak, c(BBB = NA_real_, AAA = 4))
  testthat::expect_error(
    ledgr:::ledgr_strategy_state_apply_values(
      previous, list(peak = NaN), declaration, c("BBB", "AAA"), patch = TRUE
    ),
    class = "ledgr_invalid_strategy_state"
  )
  emptied <- ledgr:::ledgr_strategy_state_apply_values(
    decoded[[1L]]$values, list(), declaration, c("BBB", "AAA"), patch = FALSE
  )
  testthat::expect_identical(
    emptied,
    ledgr:::ledgr_strategy_state_defaults(declaration, c("BBB", "AAA"))
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0534] unchanged cursors resume without replay or encoding", {
  encodes <- 0L
  original_encode <- ledgr:::ledgr_strategy_state_encode
  testthat::local_mocked_bindings(
    ledgr_strategy_state_encode = function(...) {
      encodes <<- encodes + 1L
      original_encode(...)
    },
    .package = "ledgr"
  )
  strategy <- function(ctx, params) {
    if (ctx$state$count == 0L) {
      ledgr_strategy_result(ctx$hold(), count = 1L)
    } else {
      ctx$hold()
    }
  }
  fixture <- ws17_dense_fixture(strategy, portfolio_state = list(count = 0L), days = 5L)
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  old <- options(ledgr.interrupt = TRUE)
  on.exit(options(old), add = TRUE)
  first <- ledgr_run(fixture$exp, run_id = "ws17-resume")
  close(first)
  options(ledgr.interrupt = FALSE)
  resumed <- ledgr_run(fixture$exp, run_id = "ws17-resume")
  on.exit(close(resumed), add = TRUE, after = FALSE)
  rows <- DBI::dbGetQuery(
    get_connection(fixture$snapshot),
    "SELECT ts_utc, state_json FROM strategy_state WHERE run_id = 'ws17-resume' ORDER BY ts_utc"
  )
  testthat::expect_equal(nrow(rows), 5L)
  testthat::expect_false(identical(rows$state_json[[1L]], ledgr:::ledgr_strategy_state_cursor_marker))
  testthat::expect_true(all(rows$state_json[-1L] == ledgr:::ledgr_strategy_state_cursor_marker))
  testthat::expect_equal(length(unique(rows$ts_utc)), 5L)
  testthat::expect_identical(encodes, 1L)

  no_state <- ws17_dense_fixture(function(ctx, params) ctx$hold(), days = 3L)
  on.exit(ledgr_snapshot_close(no_state$snapshot), add = TRUE, after = FALSE)
  no_state_run <- ledgr_run(no_state$exp, run_id = "ws17-no-state")
  on.exit(close(no_state_run), add = TRUE, after = FALSE)
  testthat::expect_true(all(
    availability_state_rows(no_state_run)$state_json ==
      ledgr:::ledgr_strategy_state_cursor_marker
  ))

  same <- ws17_dense_fixture(
    function(ctx, params) {
      list(targets = ctx$hold(), state_update = list(count = 0L))
    },
    portfolio_state = list(count = 0L), days = 3L
  )
  on.exit(ledgr_snapshot_close(same$snapshot), add = TRUE, after = FALSE)
  same_run <- ledgr_run(same$exp, run_id = "ws17-identical-raw")
  on.exit(close(same_run), add = TRUE, after = FALSE)
  testthat::expect_true(all(
    availability_state_rows(same_run)$state_json ==
      ledgr:::ledgr_strategy_state_cursor_marker
  ))
  testthat::expect_identical(encodes, 1L)
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0536] asset state follows ID lifecycle and axis checkpoints", {
  snapshot <- scale_test_events_snapshot(second_members = c("AAA", "BBB"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  seen <- new.env(parent = emptyenv())
  seen$axis <- list()
  seen$before <- list()
  strategy <- function(ctx, params) {
    k <- length(seen$axis) + 1L
    seen$axis[[k]] <- ctx$universe
    seen$before[[k]] <- ctx$state$visits
    ledgr_strategy_result(ctx$flat(), visits = ctx$state$visits + 1L)
  }
  run <- ledgr_run(ledgr_experiment(
    snapshot, strategy,
    universe = ledgr_universe_members("u"),
    valuation_policy = ledgr_valuation_stale(2),
    asset_state = list(visits = 0L),
    cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000)
  ), run_id = "ws17-axis-lifecycle")
  on.exit(close(run), add = TRUE, after = FALSE)

  previous <- stats::setNames(integer(), character())
  changed_axis <- logical(length(seen$axis))
  for (k in seq_along(seen$axis)) {
    axis <- seen$axis[[k]]
    expected <- stats::setNames(integer(length(axis)), axis)
    shared <- intersect(axis, names(previous))
    expected[shared] <- previous[shared]
    testthat::expect_identical(seen$before[[k]], expected, info = paste("pulse", k))
    changed_axis[[k]] <- !identical(names(previous), axis)
    previous <- expected + 1L
  }
  rows <- availability_state_rows(run)
  testthat::expect_identical(nrow(rows), length(seen$axis))
  testthat::expect_true(all(
    rows$state_json[changed_axis] != ledgr:::ledgr_strategy_state_cursor_marker
  ))
  testthat::expect_true(any(vapply(seen$axis, length, integer(1)) == 3L))
  testthat::expect_true(any(vapply(seen$axis, length, integer(1)) == 2L))
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0535] pulse inspection uses declarations and retires state_prev", {
  fixture <- ws17_dense_fixture(
    function(ctx, params) ctx$hold(),
    asset_state = list(peak = NA_real_),
    portfolio_state = list(count = 0L)
  )
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  pulse <- ledgr_pulse_snapshot(
    fixture$snapshot,
    universe = c("BBB", "AAA"),
    ts_utc = "2024-01-02T00:00:00Z",
    asset_state = list(peak = NA_real_),
    portfolio_state = list(count = 0L)
  )
  on.exit(close(pulse), add = TRUE, after = FALSE)
  testthat::expect_identical(pulse$state$count, 0L)
  testthat::expect_identical(pulse$state$peak, c(BBB = NA_real_, AAA = NA_real_))
  testthat::expect_error(
    ledgr_pulse_snapshot(
      fixture$snapshot, universe = "AAA", ts_utc = "2024-01-02T00:00:00Z",
      state_prev = list(count = 1L)
    ),
    class = "ledgr_invalid_strategy_state"
  )
  testthat::expect_false("state_prev" %in% names(pulse))
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("[LTB-0537] sweep candidates isolate declared state across workers", {
  testthat::skip_if_not_installed("mirai")
  ledgr_test_skip_workers_in_coverage()
  strategy <- function(ctx, params) {
    next_count <- ctx$state$count + 1L
    target <- ctx$flat()
    target[] <- next_count
    ledgr_strategy_result(target, count = next_count)
  }
  fixture <- ws17_dense_fixture(
    strategy, portfolio_state = list(count = 0L), days = 4L
  )
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  grid <- ledgr_grid_named(
    first = list(strategy = list(label = "first")),
    second = list(strategy = list(label = "second"))
  )
  sequential <- ledgr_sweep(fixture$exp, grid, seed = 41L, workers = 1L)
  parallel <- ledgr_sweep(fixture$exp, grid, seed = 41L, workers = 2L)
  stable <- function(x) {
    data.frame(
      candidate_id = x$candidate_id,
      final_equity = x$final_equity,
      stringsAsFactors = FALSE
    )
  }
  testthat::expect_identical(stable(parallel), stable(sequential))
  testthat::expect_identical(sequential$final_equity[[1L]], sequential$final_equity[[2L]])
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("[LTB-0538] walk-forward resets declared state for every run", {
  days <- 10L
  bars <- data.frame(
    instrument_id = rep("AAA", days),
    ts_utc = as.POSIXct("2024-01-01", tz = "UTC") + 86400 * (0:(days - 1L)),
    open = 10 + 0:(days - 1L), high = 11 + 0:(days - 1L),
    low = 9 + 0:(days - 1L), close = 10 + 0:(days - 1L), volume = 1000
  )
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    next_count <- ctx$state$count + 1L
    target <- ctx$flat()
    target[] <- params$quantity
    ledgr_strategy_result(target, count = next_count)
  }
  exp <- ledgr_experiment(
    snapshot, strategy,
    opening = ledgr_opening(cash = 1000), cost_model = ledgr_cost_zero(),
    portfolio_state = list(count = 0L)
  )
  folds <- ledgr:::ledgr_fold_list(list(
    ledgr_fold("2024-01-01", "2024-01-04", "2024-01-05", "2024-01-06", 1L),
    ledgr_fold("2024-01-03", "2024-01-06", "2024-01-07", "2024-01-08", 2L)
  ), constructor = list(type_id = "explicit"))
  result <- suppressWarnings(ledgr_walk_forward(
    exp,
    grid = ledgr_grid_named(one = list(strategy = list(quantity = 1))),
    folds = folds,
    selection_rule = ledgr_rule_argmax("annualized_return"),
    opening_state_policy = "flat_test_state",
    seed = 17L
  ))
  on.exit(lapply(result$test_runs, close), add = TRUE, after = FALSE)
  testthat::expect_identical(length(result$test_runs), 2L)
  for (run in result$test_runs) {
    row <- DBI::dbGetQuery(
      get_connection(snapshot),
      paste(
        "SELECT state_json FROM strategy_state WHERE run_id = ?",
        "ORDER BY ts_utc LIMIT 1"
      ),
      params = list(run$run_id)
    )
    restored <- ledgr:::ledgr_strategy_state_decode(
      row$state_json[[1L]], exp$strategy_state
    )
    testthat::expect_identical(restored$values$count, 1L)
  }
})
