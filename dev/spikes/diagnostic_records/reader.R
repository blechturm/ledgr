# Stage 2b reader. A run recorded by the fork stores, in place of its clean-
# hold rows, one count per decided pulse (table spike_hold_counts: run,
# ts_utc, n). dr_ensure_holds(con) rebuilds those rows for every such run in
# the store and registers them on the connection as relation `spike_holds`,
# in run_diagnostics' column order; the fork appends `UNION ALL SELECT * FROM
# spike_holds` to ledgr's one logical-trace view, so results, explain,
# summary and the coverage checks read through ledgr's own code. A pulse
# whose gaps differ from its certified count refuses (absence never means
# hold). Fixed universes only: the decision axis is the configured
# instrument order. Expects `ns` (the ledgr namespace).

dr_holds_cache <- new.env()

dr_rebuild_run <- function(con, run_id, template, certified) {
  q <- function(sql) DBI::dbGetQuery(con, sql, params = list(run_id))
  E <- q("SELECT diagnostic_seq AS seq, ts_utc, instrument_id, stage FROM run_diagnostics WHERE run_id = ?")
  Fi <- q("SELECT decision_seq, execution_seq, ts_utc, instrument_id FROM run_diagnostic_implicit WHERE run_id = ?")
  N <- q("SELECT logical_count FROM run_diagnostic_coverage WHERE run_id = ?")$logical_count
  cfg <- ns$ledgr_json_read_config(q("SELECT config_json FROM runs WHERE run_id = ?")$config_json)
  if (!is.null(cfg$availability$universe_rule)) stop("spike reader: membership axes are not rebuilt in stage 2b")
  axis <- as.character(cfg$universe$instrument_ids)
  stored <- rbind(data.frame(seq = E$seq, ts = E$ts_utc), data.frame(seq = Fi$decision_seq, ts = Fi$ts_utc),
                  data.frame(seq = Fi$execution_seq, ts = Fi$ts_utc))
  stored <- stored[!is.na(stored$seq), , drop = FALSE]
  stored <- stored[order(stored$seq, method = "radix"), , drop = FALSE]
  missing <- setdiff(seq_len(N), stored$seq)
  nxt <- findInterval(missing, stored$seq) + 1L
  pulse <- as.numeric(stored$ts[pmin(nxt, nrow(stored))])
  counts <- table(pulse)
  cert <- stats::setNames(certified$n, as.numeric(certified$ts_utc))
  if (any(nxt > nrow(stored)) || length(counts) != length(cert) || !all(names(counts) %in% names(cert)) ||
      any(as.integer(counts[names(cert)]) != cert)) {
    rlang::abort(sprintf("Diagnostic hold evidence is corrupt for run `%s`.", run_id), class = "ledgr_diagnostic_corrupt")
  }
  dec <- rbind(data.frame(seq = E$seq, ts = as.numeric(E$ts_utc), id = E$instrument_id)[E$stage == "decision" &
                                                                                          nzchar(E$instrument_id), ],
               data.frame(seq = Fi$decision_seq, ts = as.numeric(Fi$ts_utc), id = Fi$instrument_id))
  k_stored <- match(dec$id, axis)
  base_stored <- tapply(dec$seq - k_stored, dec$ts, function(b) b[[1L]])
  first_gap <- tapply(missing, pulse, min) - 1L
  base <- base_stored[as.character(pulse)]
  base[is.na(base)] <- first_gap[as.character(pulse)][is.na(base)]
  ids <- axis[missing - as.integer(base)]
  ts <- .POSIXct(pulse, tz = "UTC")
  ev <- q("SELECT ts_utc, instrument_id, position_delta, event_seq FROM ledger_events WHERE run_id = ?")
  ev <- ev[order(ev$instrument_id, as.numeric(ev$ts_utc), ev$event_seq, method = "radix"), , drop = FALSE]
  pos <- numeric(length(ids))
  for (id in unique(ids)) {
    e <- ev[ev$instrument_id == id, , drop = FALSE]
    if (!nrow(e)) next
    run <- Reduce(`+`, e$position_delta, accumulate = TRUE)
    hit <- which(ids == id)
    at <- findInterval(pulse[hit], as.numeric(e$ts_utc))
    pos[hit] <- ifelse(at == 0L, 0, run[pmax(at, 1L)])
  }
  bars <- q("SELECT b.instrument_id, b.ts_utc, b.close FROM snapshot_bars b JOIN runs r
             ON b.snapshot_id = r.snapshot_id WHERE r.run_id = ?")
  key <- function(i, t) paste(i, format(as.numeric(t), scientific = FALSE))
  price <- bars$close[match(key(ids, pulse), key(bars$instrument_id, bars$ts_utc))]
  n <- length(ids)
  out <- data.frame(run_id = rep(run_id, n), diagnostic_seq = as.integer(missing), ts_utc = ts, instrument_id = ids,
    stage = "decision", outcome = "recorded", reason_code = "decision_recorded", reasons = "decision_recorded",
    target = pos, quantity = pos, price = price, mark_source = "current_close", mark_age = 0L,
    decision_ts_utc = ts, execution_ts_utc = .POSIXct(rep(NA_real_, n), tz = "UTC"), event_seq = NA_integer_,
    target_before_risk = pos, target_after_risk = pos, position_before = pos, position_after = pos,
    feature_identity_json = NA_character_, detail_json = "{}", stringsAsFactors = FALSE)
  out[names(template)]
}

dr_ensure_holds <- function(con) {
  has <- DBI::dbExistsTable(con, "spike_hold_counts")
  template <- DBI::dbGetQuery(con, "SELECT * FROM run_diagnostics LIMIT 0")
  counts <- if (has) DBI::dbGetQuery(con, "SELECT run, ts_utc, n FROM spike_hold_counts") else NULL
  key <- paste(con@driver@dbdir, if (is.null(counts)) "none" else paste(nrow(counts), sum(counts$n)))
  # Registrations are tracked per connection: a failed probe query would
  # abort the run's open transaction.
  ptr <- paste(utils::capture.output(print(con@conn_ref)), collapse = " ")
  registered_key <- dr_holds_cache$registered[[ptr]]
  registered <- !is.null(registered_key)
  if (registered && identical(registered_key, key)) return(invisible(NULL))
  if (!identical(dr_holds_cache$key, key)) {
    t0 <- proc.time()[["elapsed"]]
    runs <- if (is.null(counts)) character() else unique(counts$run)
    parts <- lapply(runs, function(r) dr_rebuild_run(con, r, template, counts[counts$run == r, , drop = FALSE]))
    dr_holds_cache$rows <- if (length(parts)) do.call(rbind, parts) else template
    dr_holds_cache$key <- key
    dr_holds_cache$rebuild_s <- (dr_holds_cache$rebuild_s %||% 0) + (proc.time()[["elapsed"]] - t0)
  }
  duckdb::duckdb_register(con, "spike_holds", dr_holds_cache$rows, overwrite = TRUE)
  if (is.null(dr_holds_cache$registered)) dr_holds_cache$registered <- list()
  dr_holds_cache$registered[[ptr]] <- key
  invisible(NULL)
}
