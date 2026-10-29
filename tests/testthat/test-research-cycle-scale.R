# Cut 11 Workstream 22: research-cycle scaling repairs. Each rewritten shape
# is compared with the original algorithm, kept here as the reference.

testthat::test_that("[LTB-0209] the positions timeline equals replaying the ledger up to each time", {
  snapshot <- scale_test_events_snapshot()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  rotate <- function(ctx, params) {
    day <- as.integer(format(as.Date(substr(ctx$ts_utc, 1, 10)), "%d"))
    weights <- if (day %% 2L == 0L) c(AAA = 0.6, BBB = 0.2, CCC = 0.2) else c(AAA = 0.2, BBB = 0.5, CCC = 0.3)
    ids <- ctx$universe[ctx$vec$admissible]
    ledgr_weights(weights[ids], universe = ctx$universe) |> ledgr_target_rebalance(ctx, equity_fraction = 0.9)
  }
  bt <- ledgr_run(ledgr_experiment(snapshot, rotate,
    universe = ledgr_universe_members("u"),
    valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000)
  ), run_id = "timeline")
  on.exit(close(bt), add = TRUE)
  con <- ledgr:::get_connection(snapshot)
  times <- sort(unique(ledgr_results(bt, "diagnostics")$ts_utc))
  testthat::expect_gt(nrow(ledgr_results(bt, "fills")), 5L)
  testthat::expect_true(any(ledgr_results(bt, "ledger")$event_type == "DISPOSITION"))
  full_expected <- function(run_id, ids, time) {
    expected <- ledgr:::ledgr_availability_positions_asof(con, run_id, time)
    out <- stats::setNames(rep(0, length(ids)), ids)
    out[names(expected)] <- expected
    out
  }
  timeline <- ledgr:::ledgr_availability_positions_timeline(con, "timeline", times)
  for (i in seq_along(times)) {
    testthat::expect_identical(timeline$position[, i], full_expected("timeline", timeline$ids, times[[i]]))
  }

  # Ten 0.1 buys and one 1.0 sell leave arithmetic dust. Canonical replay now
  # normalizes that dust at the same transition where FIFO closes its lot;
  # raw grouped cumsum() would retain a nonzero held position.
  template <- DBI::dbGetQuery(con, "SELECT * FROM ledger_events WHERE run_id = 'timeline' AND event_type = 'FILL' LIMIT 1")
  synthetic <- template[rep(1L, 11L), , drop = FALSE]
  synthetic$run_id <- "synthetic"
  synthetic$event_id <- sprintf("synthetic_%08d", 1:11)
  synthetic$event_seq <- 1:11
  synthetic$ts_utc <- as.POSIXct("2021-02-01 21:00", tz = "UTC") + 86400 * c(0:9, 9)
  synthetic$instrument_id <- "AAA"
  synthetic$side <- c(rep("BUY", 10L), "SELL")
  synthetic$qty <- c(rep(0.1, 10L), 1)
  synthetic$price <- 10
  synthetic$fee <- 0
  synthetic$meta_json <- "{}"
  DBI::dbAppendTable(con, "ledger_events", synthetic)
  at <- as.POSIXct("2021-02-01 21:00", tz = "UTC") + 86400 * c(-1, 0:9)
  fractional <- ledgr:::ledgr_availability_positions_timeline(con, "synthetic", at)
  for (i in seq_along(at)) {
    testthat::expect_identical(fractional$position[, i], full_expected("synthetic", fractional$ids, at[[i]]))
  }
  testthat::expect_identical(unname(fractional$position["AAA", 11L]), 0)
  events <- DBI::dbGetQuery(con, "SELECT * FROM ledger_events WHERE run_id = 'synthetic' ORDER BY event_seq")
  replay <- ledgr:::ledgr_replay_accounting_events(ledgr:::ledgr_prepare_accounting_events(events))
  from_replay <- ledgr:::ledgr_accounting_positions_at_pulses(replay, at, "AAA")
  testthat::expect_identical(
    unname(from_replay[1L, ]),
    unname(fractional$position["AAA", ])
  )

  # A ledger whose timestamps decrease in event order is refused, so readers
  # replay per time.
  backwards <- synthetic[1:3, , drop = FALSE]
  backwards$run_id <- "backwards"
  backwards$event_id <- sprintf("backwards_%08d", 1:3)
  backwards$ts_utc <- as.POSIXct("2021-03-01 21:00", tz = "UTC") + 86400 * c(2, 0, 1)
  DBI::dbAppendTable(con, "ledger_events", backwards)
  testthat::expect_null(ledgr:::ledgr_availability_positions_timeline(con, "backwards", at))

  # The active result branch equals its per-time fallback.
  active <- ledgr_results(bt, "availability")
  testthat::local_mocked_bindings(ledgr_availability_positions_timeline = function(...) NULL, .package = "ledgr")
  testthat::expect_identical(ledgr_results(bt, "availability"), active)
})

# The per-fill loop the vectorised resolver replaced.
scale_test_reference_recording <- function(fills, diagnostics, sessions, version) {
  out <- rep(NA_real_, nrow(fills))
  diagnostics <- diagnostics[diagnostics$stage == "execution" & diagnostics$outcome == "filled", , drop = FALSE]
  fill_time <- as.numeric(fills$ts_utc)
  diag_execution <- as.numeric(diagnostics$execution_ts_utc)
  diag_decision <- as.numeric(diagnostics$decision_ts_utc)
  session_open <- as.numeric(sessions$session_open)
  session_close <- as.numeric(sessions$session_close)
  for (i in seq_len(nrow(fills))) {
    cand <- which(!is.na(diagnostics$event_seq) & diagnostics$event_seq == fills$event_seq[[i]])
    if (length(cand) == 0L) {
      cand <- which(diagnostics$instrument_id == fills$instrument_id[[i]] & !is.na(diag_execution) &
        diag_execution == fill_time[[i]])
    }
    if (length(cand) != 1L) next
    if (is.na(diag_execution[[cand]]) || diag_execution[[cand]] != fill_time[[i]]) next
    exec <- if (version == 2L) which(session_open == fill_time[[i]]) else which(session_close == fill_time[[i]])
    prior <- exec - 1L
    hit <- exec[prior >= 1L & session_close[prior] == diag_decision[[cand]]]
    if (length(hit) != 1L) next
    out[[i]] <- session_close[[hit[[1L]]]]
  }
  as.POSIXct(out, origin = "1970-01-01", tz = "UTC")
}

testthat::test_that("[LTB-0210] vectorised fill recording pulses equal the per-fill rule", {
  set.seed(210)
  day <- as.POSIXct("2021-01-04", tz = "UTC") + 86400 * (0:59)
  sessions <- data.frame(status = "open", session_open = day + 14.5 * 3600, session_close = day + 21 * 3600)
  # Two sessions share an execution time (the rare path).
  sessions$session_open[[31]] <- sessions$session_open[[30]]
  n <- 400L
  k <- sample.int(59L, n, TRUE) + 1L
  exec_time <- sessions$session_open[k]
  fills <- data.frame(event_seq = seq_len(n), ts_utc = exec_time, instrument_id = sample(c("A", "B", NA), n, TRUE))
  diag <- data.frame(
    event_seq = seq_len(n), instrument_id = fills$instrument_id, stage = "execution",
    outcome = "filled", decision_ts_utc = sessions$session_close[k - 1L], execution_ts_utc = exec_time
  )
  diag$event_seq[sample.int(n, 40L)] <- NA
  diag$event_seq[sample.int(n, 20L)] <- 7L
  diag$execution_ts_utc[sample.int(n, 20L)] <- NA
  diag$decision_ts_utc[sample.int(n, 20L)] <- day[[1]]
  diag <- rbind(diag, transform(diag[1:30, ], stage = "decision"))
  timing <- list(
    execution_timing_convention = "availability_open_v2",
    execution_timing_version = 2L
  )
  got <- ledgr:::ledgr_fill_recording_pulses_from_evidence(fills, diag, sessions, timing)
  expected <- scale_test_reference_recording(fills, diag, sessions, 2L)
  testthat::expect_identical(got, expected)
  testthat::expect_gt(sum(!is.na(got)), 100L)
  testthat::expect_gt(sum(is.na(got)), 20L)
})

testthat::test_that("[LTB-0211] a memory sweep keeps only the diagnostic rows its candidate row reads", {
  handler <- ledgr:::ledgr_output_handler(ledgr:::ledgr_output_sink_memory("scale"))
  rows <- data.frame(
    run_id = "scale", diagnostic_seq = 0L, ts_utc = as.POSIXct("2021-01-04 21:00", tz = "UTC") + 86400 * 0:7,
    instrument_id = c("A", "B", "A", "C", "B", "A", "D", "E"),
    stage = c("decision", "decision", "decision", "valuation", "decision", "execution", "valuation", "decision"),
    outcome = c("recorded", "recorded", "recorded", "disposed", "recorded", "filled", "stopped", "recorded"),
    reason_code = c(
      "decision_recorded", "decision_recorded", "decision_recorded", "terminal_disposition",
      "decision_recorded", "", "valuation_horizon_exhausted", "decision_recorded"
    ),
    quantity = c(10, 0, 5, 3, 7, 2, 4, NA), price = 1,
    mark_source = c("stale_close", "stale_close", "current_close", "", "frozen_close", "", "", "frozen_close"),
    mark_age = c(2L, 3L, 0L, NA, 9L, NA, NA, 4L), stringsAsFactors = FALSE
  )
  handler$write_run_diagnostics(rows[1:5, ])
  handler$write_run_diagnostics(rows[6:8, ])
  handler$write_exception_diagnostic(rows[7, ])
  kept <- handler$diagnostics()
  testthat::expect_identical(kept$diagnostic_seq, c(1L, 4L, 5L, 7L, 9L))
  full <- rbind(rows, rows[7, ])
  full$diagnostic_seq <- seq_len(nrow(full))
  testthat::expect_identical(
    ledgr:::ledgr_valuation_inputs_from_diagnostics(kept),
    ledgr:::ledgr_valuation_inputs_from_diagnostics(full)
  )
  testthat::expect_identical(ledgr:::ledgr_stopped_instrument_ids(kept), ledgr:::ledgr_stopped_instrument_ids(full))
  testthat::expect_null(ledgr:::ledgr_output_handler(ledgr:::ledgr_output_sink_memory("empty"))$diagnostics())
})

testthat::test_that("[LTB-0212] vectorised asset-state normalisation equals the per-ID rule", {
  reference <- function(state_value, axis) {
    asset_state <- state_value$asset_state %||% list()
    normalized <- stats::setNames(vector("list", length(axis)), axis)
    for (id in axis) normalized[[id]] <- asset_state[[id]] %||% list()
    state_value$asset_state <- normalized
    state_value
  }
  cases <- list(
    list(state = list(month = "m"), axis = c("B", "A")),
    list(state = list(asset_state = list(A = list(x = 1), C = NULL, D = list())), axis = c("C", "A", "B", "D")),
    list(state = list(asset_state = list(Z = list(y = 2))), axis = character()),
    list(state = NULL, axis = "A")
  )
  for (case in cases) {
    state <- case$state
    if (is.null(state)) state <- list()
    once <- ledgr:::ledgr_fold_asset_state_normalize(case$state, case$axis, drop_exited = TRUE)
    testthat::expect_identical(once, reference(state, case$axis))
    testthat::expect_identical(ledgr:::ledgr_fold_asset_state_normalize(once, case$axis), once)
    testthat::expect_identical(ledgr:::ledgr_fold_asset_state_normalize(once, case$axis, drop_exited = TRUE), once)
  }
})

testthat::test_that("[LTB-0214] carried strategy state equals normalising it on every pulse", {
  snapshot <- scale_test_events_snapshot(second_members = c("AAA", "BBB"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  reference <- function(state_value, axis) {
    asset_state <- state_value$asset_state %||% list()
    normalized <- stats::setNames(vector("list", length(axis)), axis)
    for (id in axis) normalized[[id]] <- asset_state[[id]] %||% list()
    state_value$asset_state <- normalized
    state_value
  }
  seen <- new.env()
  seen$axes <- list()
  seen$updates <- list()
  carry <- function(ctx, params) {
    k <- length(seen$axes) + 1L
    seen$axes[[k]] <- ctx$universe
    extra <- if ("CCC" %in% ctx$universe) list(CCC = list(m = k)) else list()
    update <- if (k %% 3L == 2L) list(k = k, asset_state = c(list(AAA = list(n = k), BBB = NULL), extra)) else NULL
    seen$updates[k] <- list(update)
    list(targets = ctx$flat(), state_update = update)
  }
  bt <- ledgr_run(ledgr_experiment(snapshot, carry,
    universe = ledgr_universe_members("u"),
    valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000)
  ), run_id = "carry")
  on.exit(close(bt), add = TRUE)
  testthat::expect_true(any(lengths(seen$axes) == 3L) && any(lengths(seen$axes) == 2L))
  expected <- character(length(seen$axes))
  previous <- list()
  for (k in seq_along(seen$axes)) {
    state <- if (is.null(seen$updates[[k]])) previous else seen$updates[[k]]
    previous <- reference(state, seen$axes[[k]])
    expected[[k]] <- as.character(ledgr:::canonical_json(previous))
  }
  got <- DBI::dbGetQuery(
    ledgr:::get_connection(snapshot),
    "SELECT state_json FROM strategy_state WHERE run_id = 'carry' ORDER BY ts_utc"
  )$state_json
  testthat::expect_identical(got, expected)
})

testthat::test_that("[LTB-0213] pair keys keep the original duplicates and order", {
  a <- c("x", "x", "y", NA, "NA", "y")
  b <- c("t1", "t1", "t1", "t2", "t2", NA)
  testthat::expect_identical(duplicated(ledgr:::ledgr_pair_key(a, b)), duplicated(paste(a, b, sep = "\r")))
  ts <- as.POSIXct("2021-01-04 21:00", tz = "UTC") + c(0, 0, 86400, 86400)
  testthat::expect_identical(
    duplicated(ledgr:::ledgr_pair_key(c("A", "A", "A", "B"), ts)),
    duplicated(paste0(c("A", "A", "A", "B"), "\n", ts))
  )
  fall_back <- as.POSIXct("2021-11-07 05:30", tz = "UTC") + c(0, 3600)
  local <- .POSIXct(as.numeric(fall_back), tz = "America/New_York")
  testthat::expect_identical(as.character(local[[1]]), as.character(local[[2]]))
  testthat::expect_false(identical(as.numeric(local[[1]]), as.numeric(local[[2]])))
  testthat::expect_identical(
    duplicated(ledgr:::ledgr_pair_key(c("A", "A"), local)),
    duplicated(paste(c("A", "A"), local, sep = "\r"))
  )

})

testthat::test_that("[LTB-0215] strategy state changed in place is persisted as it is on every pulse", {
  bars <- ledgr_test_make_bars(c("AAA", "BBB"), as.Date("2020-01-01") + 0:5)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  live <- new.env()
  live$x <- numeric()
  mutate <- function(ctx, params) {
    st <- ctx$state_prev
    if (!is.list(st) || is.null(st$x)) {
      st <- list(x = 0)
    } else {
      collapse::setv(st, 1L, st$x + 1, vind1 = TRUE)
    }
    live$x <- c(live$x, st$x)
    list(targets = ctx$flat(), state_update = st)
  }
  bt <- ledgr_run(ledgr_experiment(snapshot, mutate,
    cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000)
  ), run_id = "in_place")
  on.exit(close(bt), add = TRUE)
  got <- DBI::dbGetQuery(
    ledgr:::get_connection(snapshot),
    "SELECT state_json FROM strategy_state WHERE run_id = 'in_place' ORDER BY ts_utc"
  )$state_json
  expected <- vapply(live$x, function(x) as.character(ledgr:::canonical_json(list(x = x))), character(1))
  testthat::expect_gt(length(unique(live$x)), 3L)
  testthat::expect_identical(got, expected)
})

testthat::test_that("[LTB-0216] the dense results plane replays the ledger once, not per time", {
  bars <- ledgr_test_make_bars(c("AAA", "BBB"), as.Date("2020-01-01") + 0:7)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  flip <- function(ctx, params) {
    target <- ctx$flat()
    target[[if (as.integer(format(as.Date(substr(ctx$ts_utc, 1, 10)), "%d")) %% 2L == 0L) "AAA" else "BBB"]] <- 3
    target
  }
  bt <- suppressWarnings(ledgr_run(ledgr_experiment(snapshot, flip,
    cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 10000)
  ), run_id = "dense_once"))
  on.exit(close(bt), add = TRUE)
  testthat::expect_gt(nrow(ledgr_results(bt, "fills")), 4L)
  per_time <- new.env()
  per_time$calls <- 0L
  asof <- ledgr:::ledgr_availability_positions_asof
  testthat::local_mocked_bindings(
    ledgr_availability_positions_asof = function(...) {
      per_time$calls <- per_time$calls + 1L
      asof(...)
    },
    .package = "ledgr"
  )
  once <- ledgr_results(bt, "availability")
  testthat::expect_identical(per_time$calls, 0L)
  testthat::expect_true(any(once$held))
  testthat::local_mocked_bindings(ledgr_availability_positions_timeline = function(...) NULL, .package = "ledgr")
  testthat::expect_identical(ledgr_results(bt, "availability"), once)
  testthat::expect_identical(per_time$calls, length(unique(once$ts_utc)))
})
