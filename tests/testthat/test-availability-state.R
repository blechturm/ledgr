testthat::test_that("dynamic membership drives the axis and stable asset state", {
  dates <- as.POSIXct(c("2020-01-01", "2020-01-02", "2020-01-03", "2020-01-04"), tz = "UTC")
  membership <- ledgr_facts_membership_snapshots(
    data.frame(
      instrument_id = c("AAA", NA_character_, "AAA", NA_character_),
      effective_from = dates,
      knowledge_time = dates - 1,
      stringsAsFactors = FALSE
    ),
    universe_id = "dynamic",
    complete = TRUE
  )
  snapshot <- availability_runtime_fixture(days = 4L, membership = membership)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    history <- if (is.null(ctx$state_prev$history)) list() else ctx$state_prev$history
    step <- if (is.null(ctx$state_prev$step)) 1L else as.integer(ctx$state_prev$step) + 1L
    history[[length(history) + 1L]] <- list(
      universe = ctx$universe,
      members = ctx$members,
      portfolio = ctx$state_prev$portfolio,
      asset_empty = length(ctx$state_prev$asset_state) == 0L ||
        ("AAA" %in% names(ctx$state_prev$asset_state) &&
         length(ctx$state_prev$asset_state$AAA) == 0L),
      plane_names = intersect(
        c(
          "member", "held", "target_restricted", "target_restriction_reason",
          "admissible", "priced", "mark_age"
        ),
        names(ctx$vec)
      )
    )
    asset_state <- stats::setNames(vector("list", length(ctx$universe)), ctx$universe)
    for (id in ctx$universe) asset_state[[id]] <- list(seen = TRUE)
    list(
      targets = stats::setNames(numeric(length(ctx$universe)), ctx$universe),
      state_update = list(
        portfolio = "kept",
        step = step,
        history = history,
        asset_state = asset_state
      )
    )
  }
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    universe = ledgr_universe_members("dynamic"),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp)
  on.exit(close(bt), add = TRUE)
  final_state <- availability_last_state(bt)
  seen <- final_state$history
  # The fixture declares four membership states, ending with a second removal.
  testthat::expect_identical(
    lapply(seen, `[[`, "universe"),
    list("AAA", list(), "AAA", list())
  )
  testthat::expect_identical(
    lapply(seen, `[[`, "members"),
    list("AAA", list(), "AAA", list())
  )
  testthat::expect_identical(final_state$step, 4L)
  testthat::expect_identical(seen[[2L]]$portfolio, "kept")
  testthat::expect_true(seen[[3L]]$asset_empty)
  testthat::expect_identical(
    seen[[1L]]$plane_names,
    c(
      "member", "held", "target_restricted", "target_restriction_reason",
      "admissible", "priced", "mark_age"
    )
  )
  testthat::expect_equal(nrow(availability_state_rows(bt)), 4L)
})

testthat::test_that("provider orders members before stable held nonmembers", {
  dates <- as.Date("2020-01-01") + 0:2
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00",
      knowledge_time = as.POSIXct(dates, tz = "UTC") - 1
    ),
    venue_id = "XNYS"
  )
  member_ids <- c("zeta", "Alpha", "mike", "BRAVO", "alpha2")
  membership_snapshots <- ledgr_facts_membership_snapshots(
    data.frame(
      instrument_id = member_ids,
      effective_from = as.POSIXct(dates[[1L]], tz = "UTC"),
      knowledge_time = as.POSIXct(dates[[1L]], tz = "UTC") - 1,
      set_id = "complete_set"
    ),
    universe_id = "ordered",
    complete = TRUE
  )
  membership_intervals <- ledgr_facts_membership_intervals(
    data.frame(
      instrument_id = member_ids,
      effective_from = as.POSIXct(dates[[1L]], tz = "UTC"),
      knowledge_time = as.POSIXct(dates[[1L]], tz = "UTC") - 1,
      member = TRUE,
      fact_id = paste0("fact_", c(5L, 3L, 1L, 4L, 2L))
    ),
    universe_id = "ordered"
  )
  instrument_ids <- c(member_ids, "HOLD_Z", "HOLD_A")
  grid <- expand.grid(
    instrument_id = instrument_ids,
    ts_utc = as.POSIXct(paste(dates, "16:00:00"), tz = "UTC"),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  grid$open <- grid$high <- grid$low <- grid$close <- 100
  grid$volume <- 1000
  views <- lapply(
    list(membership_snapshots, membership_intervals),
    function(membership) {
      snapshot <- ledgr_snapshot_from_df(
        grid,
        instruments_df = data.frame(instrument_id = instrument_ids),
        facts = ledgr_facts(sessions, membership)
      )
      on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
      config <- list(
        data = list(snapshot_id = snapshot$snapshot_id),
        universe = list(instrument_ids = instrument_ids),
        availability = list(
          active = TRUE,
          declared_families = c("membership", "sessions"),
          universe_rule = unclass(ledgr_universe_members("ordered"))
        )
      )
      provider <- ledgr_availability_provider(
        get_connection(snapshot),
        config,
        ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
      )
      positions <- stats::setNames(numeric(length(instrument_ids)), instrument_ids)
      positions[c("HOLD_Z", "HOLD_A")] <- 1
      provider$decision_view(
        as.POSIXct("2020-01-01 16:00:00", tz = "UTC"),
        positions
      )
    }
  )
  expected_members <- c("Alpha", "BRAVO", "alpha2", "mike", "zeta")
  expected_axis <- c(expected_members, "HOLD_A", "HOLD_Z")
  for (view in views) {
    testthat::expect_identical(view$members, expected_members)
    testthat::expect_identical(view$axis, expected_axis)
    testthat::expect_identical(
      unname(view$member),
      c(rep(TRUE, length(expected_members)), FALSE, FALSE)
    )
    testthat::expect_identical(
      unname(view$held),
      c(rep(FALSE, length(expected_members)), TRUE, TRUE)
    )
  }
})

testthat::test_that("asset state prunes exits, resets re-entry, and fails closed", {
  state <- list(
    portfolio = "kept",
    asset_state = list(AAA = list(seen = TRUE), EXIT = list(old = TRUE))
  )
  pruned <- ledgr:::ledgr_fold_asset_state_normalize(state, "AAA", drop_exited = TRUE)
  testthat::expect_identical(names(pruned$asset_state), "AAA")
  testthat::expect_identical(pruned$asset_state$AAA, list(seen = TRUE))
  testthat::expect_identical(pruned$portfolio, "kept")

  empty <- ledgr:::ledgr_fold_asset_state_normalize(pruned, character(), drop_exited = TRUE)
  testthat::expect_identical(
    empty$asset_state,
    stats::setNames(vector("list", 0L), character())
  )
  reentered <- ledgr:::ledgr_fold_asset_state_normalize(empty, "EXIT", drop_exited = TRUE)
  testthat::expect_identical(reentered$asset_state, list(EXIT = list()))
  testthat::expect_identical(reentered$portfolio, "kept")

  testthat::expect_error(
    ledgr:::ledgr_fold_asset_state_normalize(state, "AAA"),
    class = "ledgr_invalid_strategy_state"
  )
  testthat::expect_error(
    ledgr:::ledgr_fold_asset_state_normalize(list(asset_state = 1), "AAA"),
    class = "ledgr_invalid_strategy_state"
  )
  testthat::expect_error(
    ledgr:::ledgr_fold_asset_state_normalize(list(asset_state = list(list())), "AAA"),
    class = "ledgr_invalid_strategy_state"
  )
})

testthat::test_that("prepared valuation advances finite closes without rescanning prefixes", {
  pulses <- as.POSIXct(paste(as.Date("2020-01-01") + 0:5, "16:00:00"), tz = "UTC")
  bars_mat <- list(
    close = rbind(
      AAA = c(NA, 100, NA, NA, 104, NA),
      BBB = rep(NA_real_, 6L),
      CCC = c(50, rep(NA_real_, 5L)),
      DDD = c(NA, NA, 30, NA, NA, 35)
    )
  )
  state <- ledgr:::ledgr_availability_valuation_state(
    bars_mat,
    rownames(bars_mat$close),
    pulses,
    2L
  )

  first <- state$advance(1L, c("CCC", "AAA", "BBB"))
  testthat::expect_identical(first$reference, c(CCC = 50, AAA = NA_real_, BBB = NA_real_))
  testthat::expect_identical(first$age, c(CCC = 0L, AAA = NA_integer_, BBB = NA_integer_))
  testthat::expect_identical(first$source, c(CCC = "current_close", AAA = "missing", BBB = "missing"))
  testthat::expect_identical(first$source_row, c(CCC = 3L, AAA = 1L, BBB = 2L))

  third <- state$advance(3L, c("AAA", "CCC", "DDD", "BBB"))
  testthat::expect_identical(third$reference, c(AAA = 100, CCC = 50, DDD = 30, BBB = NA_real_))
  testthat::expect_identical(third$age, c(AAA = 1L, CCC = 2L, DDD = 0L, BBB = NA_integer_))
  testthat::expect_identical(
    third$source,
    c(AAA = "stale_close", CCC = "stale_close", DDD = "current_close", BBB = "missing")
  )

  fourth <- state$advance(4L, c("AAA", "CCC", "DDD"))
  testthat::expect_identical(fourth$age, c(AAA = 2L, CCC = 3L, DDD = 1L))
  testthat::expect_identical(fourth$permissible, c(AAA = TRUE, CCC = FALSE, DDD = TRUE))
  testthat::expect_identical(fourth$mark, c(AAA = 100, CCC = NA_real_, DDD = 30))
  testthat::expect_identical(fourth$source, c(AAA = "stale_close", CCC = "expired_close", DDD = "stale_close"))

  repeated <- state$advance(4L, "AAA")
  testthat::expect_identical(repeated$age, c(AAA = 2L))
  testthat::expect_identical(
    as.numeric(repeated$source_ts),
    as.numeric(pulses[[2L]])
  )

  testthat::expect_error(
    state$advance(3L, "AAA"),
    class = "ledgr_availability_valuation_out_of_order"
  )
  testthat::expect_error(state$advance(4L, c("AAA", "AAA")), "unique prepared")
  testthat::expect_error(state$advance(4L, "UNKNOWN"), "unique prepared")

  stats <- state$stats()
  testthat::expect_identical(stats$row_index_builds, 1L)
  testthat::expect_identical(stats$row_index_cells, 4L)
  testthat::expect_equal(stats$close_cells_read, 4L * 4L)
  # The duplicate and unknown-axis calls also perform lookups before aborting.
  testthat::expect_equal(
    stats$source_index_lookups,
    3L + 4L + 3L + 1L + 2L + 1L
  )
})

testthat::test_that("prepared valuation work is exactly linear in source cells and emitted axis cells", {
  shapes <- list(
    c(source = 3L, axis = 2L, pulses = 5L),
    c(source = 31L, axis = 17L, pulses = 43L),
    c(source = 563L, axis = 505L, pulses = 757L)
  )
  observed <- lapply(shapes, function(shape) {
    ids <- sprintf("I%04d", seq_len(shape[["source"]]))
    pulses <- as.POSIXct("2020-01-01", tz = "UTC") + seq_len(shape[["pulses"]])
    close <- matrix(
      seq_len(shape[["source"]] * shape[["pulses"]]),
      nrow = shape[["source"]]
    )
    close[seq.int(2L, length(close), by = 11L)] <- NA_real_
    state <- ledgr:::ledgr_availability_valuation_state(
      list(close = close),
      ids,
      pulses,
      2L
    )
    axis <- ids[seq_len(shape[["axis"]])]
    for (pulse_idx in seq_len(shape[["pulses"]])) state$advance(pulse_idx, axis)
    state$stats()
  })
  for (i in seq_along(shapes)) {
    testthat::expect_identical(observed[[i]]$row_index_builds, 1L)
    testthat::expect_equal(
      observed[[i]]$row_index_cells,
      shapes[[i]][["source"]]
    )
    testthat::expect_equal(
      observed[[i]]$close_cells_read,
      shapes[[i]][["source"]] * shapes[[i]][["pulses"]]
    )
    testthat::expect_equal(
      observed[[i]]$source_index_lookups,
      shapes[[i]][["axis"]] * shapes[[i]][["pulses"]]
    )
  }
})

testthat::test_that("valuation retirement guard excludes matching, prefix scans, and selectors", {
  namespace <- asNamespace("ledgr")
  retired <- c(
    "ledgr_availability_valuation_marks",
    "ledgr_availability_valuation_marks_reference",
    "ledgr_availability_valuation_state_reference",
    "ledgr_availability_valuation_state_prepared",
    "ledgr_fold_availability_mark_age"
  )
  testthat::expect_false(any(vapply(
    retired,
    exists,
    logical(1),
    envir = namespace,
    inherits = FALSE
  )))
  reachable_bodies <- function(root, function_env = namespace) {
    queue <- root
    seen <- character()
    out <- character()
    while (length(queue) > 0L) {
      name <- queue[[1L]]
      queue <- queue[-1L]
      if (name %in% seen) next
      candidate <- get(name, envir = function_env, inherits = FALSE)
      seen <- c(seen, name)
      out <- c(out, paste(deparse(body(candidate)), collapse = "\n"))
      called <- all.names(body(candidate), functions = TRUE, unique = TRUE)
      internal <- called[vapply(called, function(called_name) {
        present <- exists(
          called_name,
          envir = function_env,
          inherits = FALSE
        )
        if (!present) return(FALSE)
        called_fn <- get(called_name, envir = function_env, inherits = FALSE)
        is.function(called_fn) && identical(environment(called_fn), function_env)
      }, logical(1))]
      queue <- c(queue, setdiff(internal, seen))
    }
    out
  }
  probe_env <- new.env(parent = baseenv())
  probe_env$helper <- function() match("needle", "haystack")
  environment(probe_env$helper) <- probe_env
  probe_env$root <- function() helper()
  environment(probe_env$root) <- probe_env
  testthat::expect_match(
    paste(reachable_bodies("root", probe_env), collapse = "\n"),
    "match\\("
  )
  state_body <- paste(
    reachable_bodies("ledgr_availability_valuation_state"),
    collapse = "\n"
  )
  fold_body <- paste(deparse(body(ledgr:::ledgr_execute_fold)), collapse = "\n")
  testthat::expect_false(grepl("match\\(", state_body))
  testthat::expect_false(grepl("seq_len\\(pulse_idx\\)", state_body))
  testthat::expect_false(grepl("which\\(", state_body))
  testthat::expect_false(grepl("getOption|valuation_arm", state_body))
  testthat::expect_false(grepl("valuation_arm|marks_reference", fold_body))
  testthat::expect_false("valuation_state" %in% names(formals(ledgr:::ledgr_execution_spec)))
})

testthat::test_that("dense folds never construct availability valuation state", {
  dates <- as.POSIXct(
    paste(as.Date("2020-01-01") + 0:1, "16:00:00"),
    tz = "UTC"
  )
  bars <- data.frame(
    ts_utc = dates,
    instrument_id = "AAA",
    open = 100,
    high = 101,
    low = 99,
    close = 100,
    volume = 1000
  )
  snapshot <- ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = "AAA")
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    cost_model = ledgr_cost_zero()
  )
  testthat::local_mocked_bindings(
    ledgr_availability_valuation_state = function(...) {
      stop("dense fold reached availability valuation")
    },
    .package = "ledgr"
  )
  bt <- ledgr_run(experiment, run_id = "dense-valuation-bypass")
  on.exit(close(bt), add = TRUE)
  testthat::expect_identical(
    ledgr_run_info(snapshot, "dense-valuation-bypass")$status,
    "DONE"
  )
})
