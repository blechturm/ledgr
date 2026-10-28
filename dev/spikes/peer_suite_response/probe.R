# Response-stage probe: does the availability core reproduce today's dense SMA
# fills on a bars-only workload (a C1 preview), does the current SMA recipe
# enter on a first usable score without an observed transition, can a
# decision-level first divergence be located without a peer, and can holdings
# by asset be read from native ledger events? Small correctness probe only.
root <- "C:/Users/maxth/Documents/GitHub/ledgr"
suppressMessages(pkgload::load_all(root, quiet = TRUE))
source(file.path(root, "dev/bench/peer_benchmark/peer_benchmark.R"))
base <- file.path(root, "dev/spikes/peer_suite_response")
args <- commandArgs(trailingOnly = TRUE)
gut <- "--gut" %in% args; args <- setdiff(args, "--gut")
out <- if (length(args)) args[1] else file.path(base, "evidence")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
quiet <- function(expr) withCallingHandlers(expr, warning = function(w) {
  if (grepl("LEDGR_LAST_BAR_NO_FILL", conditionMessage(w))) invokeRestart("muffleWarning")
})
bars <- ledgr_sim_bars(n_instruments = 12L, n_days = 90L, seed = 20260530L,
  start = "2020-01-01", instrument_prefix = "P")
bars$ts_utc <- bars$ts_utc + 21 * 3600  # session close 21:00 UTC on both paths
days <- sort(unique(as.Date(bars$ts_utc)))
calendar <- seq(min(days), max(days), by = "day")
open <- calendar %in% days
sessions <- data.frame(session_date = calendar, status = ifelse(open, "open", "closed"),
  session_open = ifelse(open, "14:30:00", NA), session_close = ifelse(open, "21:00:00", NA))
membership <- data.frame(effective_from = as.POSIXct(paste(days[1] - 1, "21:00:00"), tz = "UTC"),
  knowledge_time = as.POSIXct(paste(days[1] - 1, "21:00:00"), tz = "UTC"), source = "probe")
membership$members <- I(list(sort(unique(bars$instrument_id))))
facts <- ledgr_facts(
  ledgr_facts_sessions(sessions, venue_id = "V", knowledge = "assume_effective"),
  ledgr_facts_membership_snapshots(membership, universe_id = "u", complete = TRUE,
    knowledge = "assume_effective"))
features <- peer_public_ttr_features(5, 10)
strategy <- peer_strategy("fast", "slow")
run_one <- function(label, with_facts, opening_date = NULL) {
  snapshot <- ledgr_snapshot_from_df(bars, snapshot_id = paste0("resp_", label),
    facts = if (with_facts) facts else NULL, price_basis = "split_adjusted")
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(snapshot, strategy = strategy, features = features,
    opening = ledgr_opening(cash = 1e7, date = opening_date),
    universe = if (with_facts) ledgr_universe_members("u") else NULL,
    cost_model = ledgr_cost_zero(), risk_chain = ledgr_risk_none())
  bt <- quiet(ledgr_run(exp, run_id = paste0("resp_", label), seed = 1L))
  on.exit(close(bt), add = TRUE)
  res <- list(
    fills = as.data.frame(ledgr_results(bt, "fills")),
    equity = as.data.frame(ledgr_results(bt, "equity")),
    ledger = as.data.frame(ledgr_results(bt, "ledger")),
    diagnostics = nrow(as.data.frame(ledgr_results(bt, "diagnostics"))),
    snapshot_hash = ledgr_snapshot_info(snapshot)$snapshot_hash,
    config_hash = ledgr:::config_hash(bt$config))
  write.csv(res$fills, file.path(out, paste0("fills_", label, ".csv")), row.names = FALSE)
  res
}
late <- days[30]
dense <- run_one("dense", FALSE)
avail <- run_one("avail", TRUE)
dense_late <- run_one("dense_late", FALSE, late)
avail_late <- run_one("avail_late", TRUE, late)
same <- function(a, b) identical(a$fills, b$fills)
first_diff <- function(a, b) {
  n <- min(nrow(a$fills), nrow(b$fills))
  for (i in seq_len(n)) if (!identical(a$fills[i, ], b$fills[i, ])) return(as.character(a$fills$ts_utc[i]))
  if (nrow(a$fills) != nrow(b$fills)) "row_count" else NA_character_
}
# Fill identity keyed on the recording pulse, not the execution stamp or sequence.
fill_key <- function(f) do.call(paste, f[, c("recording_pulse_ts_utc", "instrument_id", "side", "qty", "price", "fee")])
same_keyed <- function(a, b) identical(fill_key(a$fills), fill_key(b$fills))
extra_late <- avail_late$fills[!fill_key(avail_late$fills) %in% fill_key(dense_late$fills), ]
write.csv(extra_late, file.path(out, "extra_fills_avail_late.csv"), row.names = FALSE)
# Decision timelines from the recipe's indicator source (TTR), under two rules:
# first-state (what the recipe does: an above-state after warmup is an entry)
# and transition-only (an entry needs a usable prior below-state).
fmt <- function(x) format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
decide <- function(transition_only) {
  rows <- lapply(split(bars, bars$instrument_id), function(d) {
    d <- d[order(d$ts_utc), ]
    fast <- as.numeric(TTR::SMA(d$close, 5)); slow <- as.numeric(TTR::SMA(d$close, 10))
    usable <- is.finite(fast) & is.finite(slow)
    above <- usable & fast > slow
    prev_above <- c(FALSE, head(above, -1)); prev_usable <- c(FALSE, head(usable, -1))
    enter <- above & !prev_above & (!transition_only | prev_usable)
    exit <- usable & !above & prev_above
    data.frame(instrument_id = d$instrument_id[1], signal_ts = fmt(d$ts_utc[enter | exit]),
      target = ifelse(enter[enter | exit], 1, 0))
  })
  r <- do.call(rbind, rows); r <- r[order(r$signal_ts, r$instrument_id), ]; rownames(r) <- NULL; r
}
first_state <- decide(FALSE)
transition <- decide(if (gut) FALSE else TRUE)
key <- function(r) paste(r$instrument_id, r$signal_ts, r$target)
only_first <- first_state[!key(first_state) %in% key(transition), ]
first_entries <- first_state[first_state$target == 1 & !duplicated(first_state$instrument_id), ]
entered_without_transition <- sum(!key(first_entries) %in% key(transition))
# Dense fills execute at the next session's open; map each decision to that session.
next_session <- setNames(c(fmt(as.POSIXct(days[-1], tz = "UTC") + 21 * 3600), NA),
  format(days, "%Y-%m-%d"))
decided_key <- paste(first_state$instrument_id, next_session[substr(first_state$signal_ts, 1, 10)])
dense_fill_key <- paste(dense$fills$instrument_id, fmt(as.POSIXct(dense$fills$ts_utc, tz = "UTC")))
# Holdings by asset from native ledger FILL events, cross-checked against equity.
ledger <- dense$ledger[dense$ledger$event_type == "FILL", ]
signed <- ifelse(ledger$side == "BUY", 1, -1) * ledger$qty
ledger_day <- format(as.POSIXct(ledger$ts_utc, tz = "UTC"), "%Y-%m-%d")
pulse_days <- format(as.POSIXct(dense$equity$ts_utc, tz = "UTC"), "%Y-%m-%d")
ids <- sort(unique(bars$instrument_id))
holdings <- sapply(ids, function(id) cumsum(vapply(pulse_days, function(p)
  sum(signed[ledger$instrument_id == id & ledger_day == p]), numeric(1))))
closes <- sapply(ids, function(id) {
  d <- bars[bars$instrument_id == id, ]
  d$close[match(pulse_days, format(as.Date(d$ts_utc)))]
})
holdings_value <- rowSums(holdings * closes)
write.csv(data.frame(ts_utc = dense$equity$ts_utc, holdings, positions_value = dense$equity$positions_value,
  holdings_value = holdings_value), file.path(out, "holdings_check.csv"), row.names = FALSE)
write.csv(first_state, file.path(out, "decisions_first_state.csv"), row.names = FALSE)
write.csv(transition, file.path(out, "decisions_transition_only.csv"), row.names = FALSE)
observed <- data.frame(observation = c(
  "dense_fill_count", "avail_fill_count", "dense_diagnostic_rows", "avail_diagnostic_rows",
  "dense_vs_avail_fills_identical_opening_at_data_start", "first_fill_difference_data_start",
  "dense_late_fill_count", "avail_late_fill_count",
  "dense_vs_avail_fills_identical_opening_session_30", "first_fill_difference_session_30",
  "dense_vs_avail_identical_keyed_on_recording_pulse_data_start",
  "dense_vs_avail_identical_keyed_on_recording_pulse_session_30",
  "avail_late_extra_fills", "avail_late_extra_fill_recording_pulses",
  "instruments", "instruments_entering_on_first_usable_score_without_transition",
  "decisions_first_state_rule", "decisions_transition_only_rule", "decisions_only_in_first_state_rule",
  "first_decision_divergence_ts", "dense_fills_matching_first_state_decisions_share",
  "max_abs_holdings_value_minus_positions_value"),
  value = c(nrow(dense$fills), nrow(avail$fills), dense$diagnostics, avail$diagnostics,
    same(dense, avail), first_diff(dense, avail), nrow(dense_late$fills), nrow(avail_late$fills),
    same(dense_late, avail_late), first_diff(dense_late, avail_late),
    same_keyed(dense, avail), same_keyed(dense_late, avail_late),
    nrow(extra_late), paste(unique(as.character(extra_late$recording_pulse_ts_utc)), collapse = ";"),
    length(ids), entered_without_transition,
    nrow(first_state), nrow(transition), nrow(only_first),
    if (nrow(only_first)) only_first$signal_ts[1] else NA_character_,
    sprintf("%.4f", mean(dense_fill_key %in% decided_key)),
    sprintf("%.3e", max(abs(holdings_value - dense$equity$positions_value)))))
write.csv(observed, file.path(out, "observations.csv"), row.names = FALSE)
writeLines(c(paste("source:", system2("C:/Program Files/Git/cmd/git.exe", c("-C", root, "rev-parse", "HEAD"), stdout = TRUE)),
  paste("snapshot_hash_dense:", dense$snapshot_hash), paste("snapshot_hash_avail:", avail$snapshot_hash),
  paste("config_hash_dense:", dense$config_hash), paste("config_hash_avail:", avail$config_hash),
  capture.output(sessionInfo())), file.path(out, "environment.txt"))
print(observed, row.names = FALSE)
