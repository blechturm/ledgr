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
