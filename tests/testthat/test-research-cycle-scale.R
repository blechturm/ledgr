# Cut 11 Workstream 22: research-cycle scaling repairs. Each rewritten shape
# is compared with the original algorithm, kept here as the reference.

scale_test_events_snapshot <- function() {
  days <- as.Date("2021-01-04") + c(0:4, 7:11, 14:18)
  utc <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  ids <- c("AAA", "BBB", "CCC")
  bars <- do.call(rbind, lapply(seq_along(ids), function(k) {
    keep <- if (ids[[k]] == "CCC") days[1:9] else days
    data.frame(instrument_id = ids[[k]], ts_utc = utc(keep), open = 10 * k + seq_along(keep) / 10,
               high = 10 * k + seq_along(keep) / 10, low = 10 * k + seq_along(keep) / 10,
               close = 10 * k + seq_along(keep) / 10, volume = 100)
  }))
  bars <- bars[!(bars$instrument_id == "BBB" & bars$ts_utc == utc(days[[6]])), , drop = FALSE]
  calendar <- seq(min(days), max(days), by = "day")
  open <- calendar %in% days
  membership <- data.frame(effective_from = utc(days[[1]] - 1), knowledge_time = utc(days[[1]] - 1), source = "t")
  membership$members <- I(list(ids))
  facts <- ledgr_facts(
    ledgr_facts_sessions(data.frame(session_date = calendar, status = ifelse(open, "open", "closed"),
                                    session_open = ifelse(open, "14:30:00", NA), session_close = ifelse(open, "21:00:00", NA)),
                         venue_id = "V", knowledge = "assume_effective"),
    ledgr_facts_membership_snapshots(membership, universe_id = "u", complete = TRUE, knowledge = "assume_effective"),
    ledgr_facts_lifetime(data.frame(instrument_id = "CCC", effective_from = utc(days[[10]]),
                                    knowledge_time = utc(days[[10]]) - 1, assertion = "known_inactive",
                                    terminal_event = "bankruptcy"))
  )
  ledgr_snapshot_from_df(bars, data.frame(instrument_id = ids), db_path = tempfile(fileext = ".duckdb"), facts = facts)
}

testthat::test_that("[LTB-0209] the positions timeline equals replaying the ledger up to each time", {
  snapshot <- scale_test_events_snapshot()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  rotate <- function(ctx, params) {
    day <- as.integer(format(as.Date(substr(ctx$ts_utc, 1, 10)), "%d"))
    weights <- if (day %% 2L == 0L) c(AAA = 0.6, BBB = 0.2, CCC = 0.2) else c(AAA = 0.2, BBB = 0.5, CCC = 0.3)
    ids <- ctx$universe[ctx$vec$admissible]
    ledgr_weights(weights[ids], universe = ctx$universe) |> ledgr_target_rebalance(ctx, equity_fraction = 0.9)
  }
  bt <- ledgr_run(ledgr_experiment(snapshot, rotate, universe = ledgr_universe_members("u"),
                                   valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero(),
                                   opening = ledgr_opening(cash = 1000)), run_id = "timeline")
  on.exit(close(bt), add = TRUE)
  con <- ledgr:::get_connection(snapshot)
  times <- sort(unique(ledgr_results(bt, "diagnostics")$ts_utc))
  testthat::expect_gt(nrow(ledgr_results(bt, "fills")), 5L)
  testthat::expect_true(any(ledgr_results(bt, "ledger")$event_type == "DISPOSITION"))
  timeline <- ledgr:::ledgr_availability_positions_timeline(con, "timeline", times)
  for (i in seq_along(times)) {
    expected <- ledgr:::ledgr_availability_positions_asof(con, "timeline", times[[i]])
    got <- timeline$position[, i]
    traded <- names(expected) %||% character()
    testthat::expect_identical(unname(got[traded]), unname(expected))
    testthat::expect_true(all(got[setdiff(names(got), traded)] == 0))
  }
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
  for (version in c(1L, 2L)) {
    sessions <- data.frame(status = "open", session_open = day + 14.5 * 3600, session_close = day + 21 * 3600)
    # Two sessions share an execution time (the rare path).
    sessions$session_open[[31]] <- sessions$session_open[[30]]
    n <- 400L
    k <- sample.int(59L, n, TRUE) + 1L
    exec_time <- if (version == 2L) sessions$session_open[k] else sessions$session_close[k]
    fills <- data.frame(event_seq = seq_len(n), ts_utc = exec_time, instrument_id = sample(c("A", "B", NA), n, TRUE))
    diag <- data.frame(event_seq = seq_len(n), instrument_id = fills$instrument_id, stage = "execution",
                       outcome = "filled", decision_ts_utc = sessions$session_close[k - 1L], execution_ts_utc = exec_time)
    diag$event_seq[sample.int(n, 40L)] <- NA                # fall back to instrument and time
    diag$event_seq[sample.int(n, 20L)] <- 7L                # repeated event_seq: unresolved
    diag$execution_ts_utc[sample.int(n, 20L)] <- NA         # missing execution time
    diag$decision_ts_utc[sample.int(n, 20L)] <- day[[1]]     # decision does not match
    diag <- rbind(diag, transform(diag[1:30, ], stage = "decision"))
    timing <- list(execution_timing_convention = if (version == 2L) "availability_open_v2" else "availability_close_v1",
                   execution_timing_version = version)
    got <- ledgr:::ledgr_fill_recording_pulses_from_evidence(fills, diag, sessions, timing)
    expected <- scale_test_reference_recording(fills, diag, sessions, version)
    testthat::expect_identical(got, expected)
    testthat::expect_gt(sum(!is.na(got)), 100L)
    testthat::expect_gt(sum(is.na(got)), 20L)
  }
})

testthat::test_that("[LTB-0211] a memory sweep keeps only the diagnostic rows its candidate row reads", {
  handler <- ledgr:::ledgr_memory_output_handler("scale")
  rows <- data.frame(
    run_id = "scale", diagnostic_seq = 0L, ts_utc = as.POSIXct("2021-01-04 21:00", tz = "UTC") + 86400 * 0:7,
    instrument_id = c("A", "B", "A", "C", "B", "A", "D", "E"),
    stage = c("decision", "decision", "decision", "valuation", "decision", "execution", "valuation", "decision"),
    outcome = c("recorded", "recorded", "recorded", "disposed", "recorded", "filled", "stopped", "recorded"),
    reason_code = c("decision_recorded", "decision_recorded", "decision_recorded", "terminal_disposition",
                    "decision_recorded", "", "valuation_horizon_exhausted", "decision_recorded"),
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
  testthat::expect_identical(ledgr:::ledgr_valuation_inputs_from_diagnostics(kept),
                             ledgr:::ledgr_valuation_inputs_from_diagnostics(full))
  testthat::expect_identical(ledgr:::ledgr_stopped_instrument_ids(kept), ledgr:::ledgr_stopped_instrument_ids(full))
  testthat::expect_null(ledgr:::ledgr_memory_output_handler("empty")$diagnostics())
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
    testthat::expect_identical(
      ledgr:::ledgr_fold_asset_state_normalize(case$state, case$axis, drop_exited = TRUE),
      reference(state, case$axis)
    )
  }
})
