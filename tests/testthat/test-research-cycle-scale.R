# Cut 11 Workstream 22: research-cycle scaling repairs. Each rewritten shape
# is compared with the original algorithm, kept here as the reference.

scale_test_reference_positions_asof <- function(con,
                                                 run_id,
                                                 ids,
                                                 time,
                                                 replay_fn = ledgr:::ledgr_replay_accounting_events) {
  events <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT * FROM ledger_events",
      "WHERE run_id = ? AND ts_utc <= ? ORDER BY event_seq"
    ),
    params = list(run_id, as.POSIXct(time, tz = "UTC"))
  )
  out <- stats::setNames(rep(0, length(ids)), ids)
  if (nrow(events) == 0L) return(out)
  replay <- replay_fn(ledgr:::ledgr_prepare_accounting_events(events, ids))
  out[names(replay$positions)] <- replay$positions
  out
}

testthat::test_that("[LTB-0209] the positions timeline equals replaying the ledger up to each time", {
  snapshot <- scale_test_events_snapshot()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  rotate <- function(ctx, params) {
    day <- as.integer(format(as.Date(substr(ctx$ts_utc, 1, 10)), "%d"))
    weights <- if (day %% 2L == 0L) c(AAA = 0.6, BBB = 0.2, CCC = 0.2) else c(AAA = 0.2, BBB = 0.5, CCC = 0.3)
    ids <- ctx$universe[ctx$buyable]
    ledgr_weights(weights[ids], universe = ctx$universe) |> ledgr_target_rebalance(ctx, weights = _, invest_fraction = 0.9)
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
    scale_test_reference_positions_asof(con, run_id, ids, time)
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
  effects <- ledgr_test_fill_effects(
    synthetic$side, synthetic$qty, synthetic$price, synthetic$fee
  )
  synthetic$cash_delta <- effects$cash_delta
  synthetic$position_delta <- effects$position_delta
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

  # A ledger whose timestamps decrease in event order is refused. There is no
  # per-time fallback that can silently give a different answer.
  backwards <- synthetic[1:3, , drop = FALSE]
  backwards$run_id <- "backwards"
  backwards$event_id <- sprintf("backwards_%08d", 1:3)
  backwards$ts_utc <- as.POSIXct("2021-03-01 21:00", tz = "UTC") + 86400 * c(2, 0, 1)
  DBI::dbAppendTable(con, "ledger_events", backwards)
  testthat::expect_error(
    ledgr:::ledgr_availability_positions_timeline(con, "backwards", at),
    class = "ledgr_invalid_accounting_event"
  )
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

testthat::test_that("[LTB-0210] fill recording pulses use only the configured session axis", {
  set.seed(210)
  day <- as.POSIXct("2021-01-04", tz = "UTC") + 86400 * (0:59)
  sessions <- data.frame(status = "open", session_open = day + 14.5 * 3600, session_close = day + 21 * 3600)
  # Two sessions share an execution time (the rare path).
  sessions$session_open[[31]] <- sessions$session_open[[30]]
  n <- 400L
  k <- sample.int(59L, n, TRUE) + 1L
  exec_time <- sessions$session_open[k]
  fills <- data.frame(event_seq = seq_len(n), ts_utc = exec_time, instrument_id = sample(c("A", "B", NA), n, TRUE))
  timing <- list(
    execution_timing_convention = "availability_open_v2",
    execution_timing_version = 2L
  )
  got <- ledgr:::ledgr_fill_recording_pulses_from_sessions(fills, sessions, timing)
  expected <- rep(as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"), n)
  for (i in seq_len(n)) {
    hit <- which(as.numeric(sessions$session_open) == as.numeric(fills$ts_utc[[i]]))
    if (length(hit) == 1L && hit[[1L]] >= 2L) expected[[i]] <- sessions$session_close[[hit[[1L]]]]
  }
  testthat::expect_identical(got, expected)
  testthat::expect_gt(sum(!is.na(got)), 100L)
  testthat::expect_gt(sum(is.na(got)), 0L)
  source <- paste(readLines(testthat::test_path("..", "..", "R", "execution-timing.R"), warn = FALSE), collapse = "\n")
  testthat::expect_false(grepl("run_diagnostics", source, fixed = TRUE))
})

testthat::test_that("[LTB-0211] a memory sweep keeps only the diagnostic rows its candidate row reads", {
  handler <- ledgr:::ledgr_output_handler(ledgr:::ledgr_output_sink_memory("scale"))
  rows <- data.frame(
    run_id = "scale", diagnostic_seq = seq_len(8L), ts_utc = as.POSIXct("2021-01-04 21:00", tz = "UTC") + 86400 * 0:7,
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
  exception <- rows[7, ]
  exception$diagnostic_seq <- 9L
  handler$write_exception_diagnostic(exception)
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

testthat::test_that("[LTB-0215] typed strategy state changed in place is persisted exactly", {
  bars <- ledgr_test_make_bars(c("AAA", "BBB"), as.Date("2020-01-01") + 0:5)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  live <- new.env()
  live$x <- numeric()
  mutate <- function(ctx, params) {
    st <- unclass(ctx$state)
    collapse::setv(st, 1L, st$x + 1, vind1 = TRUE)
    live$x <- c(live$x, st$x)
    list(targets = ctx$flat(), state_update = st)
  }
  bt <- ledgr_run(ledgr_experiment(snapshot, mutate,
    portfolio_state = list(x = 0),
    cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000)
  ), run_id = "in_place")
  on.exit(close(bt), add = TRUE)
  testthat::expect_gt(length(unique(live$x)), 3L)
  testthat::expect_identical(live$x, as.double(seq_along(live$x)))
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
  replay_count <- new.env()
  replay_count$calls <- 0L
  replay_original <- ledgr:::ledgr_replay_accounting_events
  testthat::local_mocked_bindings(
    ledgr_replay_accounting_events = function(...) {
      replay_count$calls <- replay_count$calls + 1L
      replay_original(...)
    },
    .package = "ledgr"
  )
  once <- ledgr_results(bt, "availability")
  testthat::expect_identical(replay_count$calls, 1L)
  testthat::expect_true(any(once$held))
  con <- ledgr:::get_connection(bt)
  expected_held <- logical(nrow(once))
  result_times <- unique(once$ts_utc)
  for (time_idx in seq_along(result_times)) {
    time <- result_times[[time_idx]]
    rows <- which(once$ts_utc == time)
    ids <- as.character(once$instrument_id[rows])
    position <- scale_test_reference_positions_asof(
      con, bt$run_id, ids, time, replay_fn = replay_original
    )
    expected_held[rows] <- unname(position[ids] != 0)
  }
  testthat::expect_identical(once$held, expected_held)
})
