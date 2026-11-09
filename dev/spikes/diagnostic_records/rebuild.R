# Charter prerequisite: do clean-hold rows rebuild exactly from what would
# remain stored? No fold change: each workload runs on the pin, then the
# rebuild reads only
#   - the stored explicit rows, the implicit fill rows and the coverage count
#     (the logical row total);
#   - the run's ledger events, the snapshot's bar closes, the run config and
#     the public `availability` view (sealed facts; no strategy code runs);
#   - one integer per decided pulse, the certified hold count, used only to
#     check the rebuild (the fold would write it in place of the hold rows).
# It rebuilds every clean hold (sequence position, instrument, position,
# price) and compares the full decoded trace with the pin's, identical().
#
#   Rscript dev/spikes/diagnostic_records/rebuild.R <pinned lib> <out dir> [workload,...] [--gut]
#
# --gut removes one stored decision row before the rebuild, as a corrupt
# store would; the hold count check must then fail.

args <- commandArgs(TRUE)
gut <- "--gut" %in% args
args <- setdiff(args, "--gut")
lib <- args[[1L]]
out <- args[[2L]]
dir.create(out, recursive = TRUE, showWarnings = FALSE)
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                              winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(repo, "dev/bench/v0_2_3_ws16_entry/common.R"))
pin <- ws16_load_installed(lib)
work <- file.path(tempdir(), "diag_rebuild")
dir.create(work, showWarnings = FALSE)
source(file.path(here, "workloads.R"))
ids <- if (length(args) >= 3L) strsplit(args[[3L]], ",")[[1L]] else names(dr_workloads)
now <- function() as.numeric(Sys.time())
key <- function(id, ts) paste(id, format(as.numeric(ts), scientific = FALSE))

# Positions as of each (instrument, time): the sequential double sum of the
# instrument's position deltas over events at or before that time, in event
# order (not cumsum(), which accumulates in long double).
positions_at <- function(ev, ids, ts) {
  out <- numeric(length(ids))
  for (id in unique(ids)) {
    e <- ev[ev$instrument_id == id, , drop = FALSE]
    hit <- which(ids == id)
    if (nrow(e) == 0L) next
    e <- e[order(as.numeric(e$ts_utc), e$event_seq, method = "radix"), , drop = FALSE]
    run <- Reduce(`+`, e$position_delta, accumulate = TRUE)
    at <- findInterval(as.numeric(ts[hit]), as.numeric(e$ts_utc))
    out[hit] <- ifelse(at == 0L, 0, run[pmax(at, 1L)])
  }
  out
}

rows_out <- list()
for (id in ids) {
  w <- dr_workloads[[id]]()
  bt <- suppressWarnings(ledgr::ledgr_run(w$exp, params = w$params, run_id = "rebuild", seed = w$seed))
  truth <- as.data.frame(tibble::as_tibble(ledgr::ledgr_results(bt, "diagnostics")))
  t0 <- now()
  av <- as.data.frame(tibble::as_tibble(ledgr::ledgr_results(bt, "availability")))
  t_av <- now() - t0
  close(bt)
  ledgr::ledgr_snapshot_close(w$snapshot)
  con <- DBI::dbConnect(duckdb::duckdb(), w$db, read_only = TRUE)
  q <- function(sql) DBI::dbGetQuery(con, sql, params = list("rebuild"))
  t0 <- now()
  E <- q("SELECT diagnostic_seq AS seq, ts_utc, instrument_id, stage FROM run_diagnostics WHERE run_id = ?")
  Fi <- q("SELECT decision_seq, execution_seq, ts_utc, instrument_id FROM run_diagnostic_implicit
           WHERE run_id = ? AND execution_seq IS NOT NULL")
  N <- q("SELECT logical_count FROM run_diagnostic_coverage WHERE run_id = ?")$logical_count
  ev <- q("SELECT ts_utc, instrument_id, position_delta, event_seq FROM ledger_events WHERE run_id = ?")
  bars <- q("SELECT b.instrument_id, b.ts_utc, b.close FROM snapshot_bars b JOIN runs r
             ON b.snapshot_id = r.snapshot_id WHERE r.run_id = ?")
  cfg <- ledgr:::ledgr_json_read_config(q("SELECT config_json FROM runs WHERE run_id = ?")$config_json)
  t_read <- now() - t0
  # The certified count per decided pulse, as the fold would store it.
  certified <- q("SELECT ts_utc, count(*) AS n FROM run_diagnostic_implicit
                  WHERE run_id = ? AND execution_seq IS NULL GROUP BY ts_utc")
  DBI::dbDisconnect(con, shutdown = TRUE)
  if (gut) {
    explicit_decision <- which(E$stage == "decision" & nzchar(E$instrument_id))
    if (length(explicit_decision)) E <- E[-explicit_decision[[1L]], , drop = FALSE] else Fi <- Fi[-1L, , drop = FALSE]
  }

  t0 <- now()
  stored <- rbind(data.frame(seq = E$seq, ts = E$ts_utc), data.frame(seq = Fi$decision_seq, ts = Fi$ts_utc),
                  data.frame(seq = Fi$execution_seq, ts = Fi$ts_utc))
  stored <- stored[order(stored$seq, method = "radix"), , drop = FALSE]
  missing <- setdiff(seq_len(N), stored$seq)
  # A pulse closes with a stored row (its reconciliation row), so a missing
  # position belongs to the pulse of the next stored row.
  nxt <- findInterval(missing, stored$seq) + 1L
  unplaced <- sum(nxt > nrow(stored))
  pulse_ts <- stored$ts[pmin(nxt, nrow(stored))]
  # Refuse before decoding when the gaps do not match the certified counts:
  # absence never means hold.
  counts <- table(as.numeric(pulse_ts))
  cert <- stats::setNames(certified$n, as.numeric(certified$ts_utc))
  count_ok <- unplaced == 0L && length(counts) == length(cert) && all(names(counts) %in% names(cert)) &&
    all(as.integer(counts[names(cert)]) == cert)
  if (!count_ok) {
    rows_out[[length(rows_out) + 1L]] <- data.frame(
      workload = id, gut = gut, logical_rows = N, rebuilt_holds = 0L, unplaced = unplaced,
      base_from_stored = NA, base_all_holds = NA, base_conflict = NA, hold_count_check = FALSE,
      trace_identical = NA, first_difference = "refused: gaps differ from the certified hold counts",
      read_s = round(t_read, 3), availability_s = round(t_av, 3), rebuild_s = NA)
    cat(sprintf("%-20s refused: gaps differ from the certified hold counts\n", id))
    next
  }
  # The decision axis of each pulse: the availability rows of that time, in
  # context order (fixed universe: the configured order; membership: members
  # first, then by instrument ID, as the integrity check expects).
  membership <- !is.null(cfg$availability$universe_rule)
  fixed_ids <- as.character(cfg$universe$instrument_ids)
  av_ts <- split(av, as.numeric(av$ts_utc))
  axis_of <- function(ts) {
    a <- av_ts[[format(as.numeric(ts), scientific = FALSE)]]
    if (is.null(a)) return(character())
    if (membership) a$instrument_id[order(!a$member, a$instrument_id, method = "radix")]
    else a$instrument_id[order(match(a$instrument_id, fixed_ids))]
  }
  dec <- rbind(data.frame(seq = E$seq, ts = E$ts_utc, id = E$instrument_id)[E$stage == "decision" & nzchar(E$instrument_id), ],
               data.frame(seq = Fi$decision_seq, ts = Fi$ts_utc, id = Fi$instrument_id))
  dec_by_ts <- split(dec, as.numeric(dec$ts))
  hold_id <- character(length(missing))
  base_rule <- c(stored = 0L, all_holds = 0L, conflict = 0L)
  for (t in unique(as.numeric(pulse_ts))) {
    m <- which(as.numeric(pulse_ts) == t)
    axis <- axis_of(.POSIXct(t, tz = "UTC"))
    d <- dec_by_ts[[format(t, scientific = FALSE)]]
    base <- if (!is.null(d) && nrow(d) > 0L) unique(d$seq - match(d$id, axis)) else integer()
    if (length(base) == 1L && !is.na(base)) {
      base_rule[["stored"]] <- base_rule[["stored"]] + 1L
    } else if (length(base) == 0L) {
      base <- min(missing[m]) - 1L
      base_rule[["all_holds"]] <- base_rule[["all_holds"]] + 1L
    } else {
      base_rule[["conflict"]] <- base_rule[["conflict"]] + 1L
      base <- base[[1L]]
    }
    hold_id[m] <- axis[missing[m] - base]
  }
  close_of <- bars$close[match(key(hold_id, pulse_ts), key(bars$instrument_id, bars$ts_utc))]
  pos <- positions_at(ev, hold_id, pulse_ts)
  n <- length(missing)
  rebuilt <- data.frame(
    run_id = rep("rebuild", n), diagnostic_seq = as.integer(missing), ts_utc = pulse_ts,
    instrument_id = hold_id, stage = "decision", outcome = "recorded",
    reason_code = "decision_recorded", reasons = "decision_recorded",
    target = pos, quantity = pos, price = close_of, mark_source = "current_close", mark_age = 0L,
    decision_ts_utc = pulse_ts, execution_ts_utc = .POSIXct(rep(NA_real_, n), tz = "UTC"),
    event_seq = NA_integer_, target_before_risk = pos, target_after_risk = pos,
    position_before = pos, position_after = pos, feature_identity_json = NA_character_,
    detail_json = "{}", stringsAsFactors = FALSE)
  t_rebuild <- now() - t0

  # The rows the stored evidence decodes to (the pin's decoder), plus the rebuild.
  kept <- truth[truth$diagnostic_seq %in% stored$seq, ]
  combined <- rbind(kept, rebuilt)
  combined <- combined[order(combined$diagnostic_seq, method = "radix"), ]
  rownames(combined) <- NULL
  same <- identical(combined, truth)
  diff_at <- ""
  if (!same) {
    if (nrow(combined) != nrow(truth)) diff_at <- sprintf("rows %d vs %d", nrow(combined), nrow(truth))
    else for (col in names(truth)) {
      a <- combined[[col]]; b <- truth[[col]]
      bad <- which(xor(is.na(a), is.na(b)) | (!is.na(a) & !is.na(b) & a != b))
      if (length(bad) || !identical(attributes(a), attributes(b))) {
        diff_at <- sprintf("%s at seq %s", col, if (length(bad)) truth$diagnostic_seq[bad[[1L]]] else "<attributes>")
        break
      }
    }
  }
  rows_out[[length(rows_out) + 1L]] <- data.frame(
    workload = id, gut = gut, logical_rows = N, rebuilt_holds = n, unplaced = unplaced,
    base_from_stored = base_rule[["stored"]], base_all_holds = base_rule[["all_holds"]],
    base_conflict = base_rule[["conflict"]], hold_count_check = count_ok, trace_identical = same,
    first_difference = diff_at, read_s = round(t_read, 3), availability_s = round(t_av, 3),
    rebuild_s = round(t_rebuild, 3))
  cat(sprintf("%-20s holds %d  count check %s  trace identical %s %s  (read %.2f s, availability %.2f s, rebuild %.2f s)\n",
              id, n, count_ok, same, diff_at, t_read, t_av, t_rebuild))
}
res <- do.call(rbind, rows_out)
utils::write.csv(res, file.path(out, if (gut) "rebuild_gut.csv" else "rebuild.csv"), row.names = FALSE)
