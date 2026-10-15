# One-execution-mode probe (spike_protocol.md Section 1). Binds nothing.
#
# Runs a dense fixture through today's dense path and through the
# availability path (same bars plus implied session facts, full fixed
# universe, never-stale valuation policy), writes every result surface as CSV
# and diffs them.
#
#   Rscript dev/spikes/one_execution_mode/probe.R <repo> <out_dir> [case ...]
#
# Cases are listed in oem_cases(). Default: every case except the clock.

`%||%` <- function(x, y) if (is.null(x)) y else x

oem_load <- function(repo) {
  suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
  source(file.path(repo, "dev/bench/v0_2_2_long_window_regression/helpers.R"),
         local = globalenv())
  invisible(TRUE)
}

# ---- fixtures ---------------------------------------------------------------

# Registered peer fixture: dev/bench/peer_benchmark/peer_benchmark.R, preset
# record (100 instruments x 252 days, seed 20260530, TTR SMA 5/10 cross).
oem_peer_bars <- function() {
  as.data.frame(ledgr_sim_bars(
    n_instruments = 100L, n_days = 252L, seed = 20260530L,
    instrument_prefix = "PEER_"
  ))
}

oem_peer_features <- function(kind = "ttr") {
  if (identical(kind, "builtin")) {
    return(ledgr_feature_map(fast = ledgr_ind_sma(5L), slow = ledgr_ind_sma(10L)))
  }
  ledgr_feature_map(
    fast = ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
    slow = ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)
  )
}

# Copied from peer_benchmark.R peer_strategy(fast_id, slow_id); the builtin
# row reads sma_5/sma_10 as the peer benchmark does.
oem_peer_strategy <- function(fast_id = "fast", slow_id = "slow") {
  function(ctx, params) {
    targets <- ctx$hold()
    fw <- ctx$features_wide
    instruments <- as.character(fw$instrument_id)
    n <- length(instruments)
    fast <- if (fast_id %in% names(fw)) suppressWarnings(as.numeric(fw[[fast_id]])) else rep(NA_real_, n)
    slow <- if (slow_id %in% names(fw)) suppressWarnings(as.numeric(fw[[slow_id]])) else rep(NA_real_, n)
    current_above <- is.finite(fast) & is.finite(slow) & fast > slow
    prev_above <- ctx$state_prev$above %||% list()
    was_above <- rep(FALSE, n)
    prev_names <- names(prev_above)
    if (length(prev_above) > 0L && length(prev_names) > 0L) {
      idx <- match(instruments, prev_names)
      ok <- !is.na(idx)
      if (any(ok)) {
        was_above[ok] <- as.logical(unlist(prev_above[idx[ok]], use.names = FALSE))
        was_above[is.na(was_above)] <- FALSE
      }
    }
    cross_up <- current_above & !was_above
    cross_down <- !current_above & was_above
    if (any(cross_up)) targets[instruments[cross_up]] <- 1
    if (any(cross_down)) targets[instruments[cross_down]] <- 0
    list(targets = targets,
         state_update = list(above = as.list(stats::setNames(current_above, instruments))))
  }
}

# Registered long-window dense witness: dev/bench/v0_2_2_durable_run_memory
# (bars of the durable_memory shape, 1,514 sessions x 600 instruments,
# returns 63/126/252, monthly top-10 momentum, sealed without facts). The
# bars are regenerated with the same seed and formula as lwreg_build_fixture().
oem_lw_bars <- function(sessions_n = 1514L, instruments_n = 600L) {
  dates <- lwreg_session_dates(sessions_n)
  ids <- sprintf("I%04d", seq_len(instruments_n))
  set.seed(1L)
  ret <- matrix(stats::rnorm(sessions_n * instruments_n, 0.0003, 0.02), nrow = sessions_n)
  cl <- as.vector(100 * exp(apply(ret, 2L, cumsum)))
  data.frame(
    ts_utc = rep(as.POSIXct(paste(dates, "21:00:00"), tz = "UTC"), times = instruments_n),
    instrument_id = rep(ids, each = sessions_n),
    open = cl, high = cl * 1.005, low = cl * 0.995, close = cl, volume = 1e5,
    stringsAsFactors = FALSE
  )
}

# Implied session calendar: one open session per distinct bar timestamp,
# closing at that timestamp and opening `open_lead` seconds earlier on the
# same civil date in `timezone`; every other civil date is closed.
oem_implied_sessions <- function(bars, timezone, open_lead = 1) {
  closes <- sort(unique(as.POSIXct(bars$ts_utc, tz = "UTC")))
  local_date <- as.Date(format(closes, "%Y-%m-%d", tz = timezone))
  if (anyDuplicated(local_date)) stop("Two bar timestamps share a civil date in ", timezone)
  civil <- seq(min(local_date), max(local_date), by = "day")
  at <- match(civil, local_date)
  open <- !is.na(at)
  close_ts <- closes[at]
  data.frame(
    session_date = civil,
    status = ifelse(open, "open", "closed"),
    session_open = close_ts - open_lead,
    session_close = close_ts,
    knowledge_time = as.POSIXct(paste(min(civil) - 3, "00:00:00"), tz = "UTC"),
    source = "implied_from_bar_timestamps",
    stringsAsFactors = FALSE
  )
}

oem_seal <- function(bars, db_path, snapshot_id, facts = NULL) {
  unlink(c(db_path, paste0(db_path, ".wal")))
  ids <- sort(unique(as.character(bars$instrument_id)))
  args <- list(bars, instruments_df = data.frame(instrument_id = ids),
               db_path = db_path, snapshot_id = snapshot_id)
  if (!is.null(facts)) args$facts <- facts
  do.call(ledgr_snapshot_from_df, args)
}

# ---- one arm ----------------------------------------------------------------

oem_fixture <- function(name) {
  switch(name,
    peer = list(bars = oem_peer_bars(), timezone = "Etc/GMT+1",
                strategy = oem_peer_strategy(), features = oem_peer_features("ttr"),
                cash = 1e7),
    lw = list(bars = oem_lw_bars(), timezone = "UTC",
              strategy = lwreg_strategy("momentum", new.env()),
              features = lwreg_features("returns_63+returns_126+returns_252"),
              cash = 1e6),
    stop("Unknown fixture: ", name))
}

# mode: "dense" seals bars only; "availability" seals bars plus implied
# sessions (and optional complete membership) and declares `policy`.
oem_arm <- function(fx, mode, work_dir, policy = NULL, membership = FALSE,
                    bars = fx$bars) {
  db <- file.path(work_dir, paste0(mode, ".duckdb"))
  ids <- sort(unique(as.character(bars$instrument_id)))
  facts <- NULL
  if (!identical(mode, "dense")) {
    sessions <- oem_implied_sessions(fx$bars, fx$timezone)
    families <- list(ledgr_facts_sessions(sessions, "IMPLIED", timezone = fx$timezone))
    if (isTRUE(membership)) {
      families[[2L]] <- ledgr_facts_membership_snapshots(
        data.frame(instrument_id = ids,
                   effective_from = min(sessions$knowledge_time),
                   knowledge_time = min(sessions$knowledge_time),
                   source = "implied_full_membership"),
        "ALL", complete = TRUE)
    }
    facts <- do.call(ledgr_facts, families)
  }
  snap <- oem_seal(bars, db, paste0("oem_", mode), facts)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)
  args <- list(snapshot = snap, strategy = fx$strategy, features = fx$features,
               opening = ledgr_opening(cash = fx$cash), cost_model = ledgr_cost_zero())
  args$universe <- if (isTRUE(membership)) ledgr_universe_members("ALL") else ids
  if (!identical(mode, "dense")) args$valuation_policy <- policy
  exp <- do.call(ledgr_experiment, args)
  warns <- character()
  t0 <- proc.time()[["elapsed"]]
  bt <- tryCatch(
    withCallingHandlers(ledgr_run(exp, run_id = "oem_run"), warning = function(w) {
      warns <<- c(warns, conditionMessage(w)); invokeRestart("muffleWarning")
    }),
    error = identity)
  engine_s <- proc.time()[["elapsed"]] - t0
  warn_note <- paste(sprintf("%dx %s", as.integer(table(substr(warns, 1, 60))),
                             names(table(substr(warns, 1, 60)))), collapse = " / ")
  snapshot_hash <- ledgr_snapshot_info(snap)$snapshot_hash
  if (inherits(bt, "error")) {
    return(list(error = bt, engine_s = engine_s, snapshot_hash = snapshot_hash,
                status = paste("ERROR", class(bt)[[1L]]), warnings = warn_note))
  }
  on.exit(close(bt), add = TRUE)
  info <- ledgr_run_info(snap, bt$run_id)
  tel <- ledgr_get_run_telemetry(bt$run_id)
  list(surfaces = oem_surfaces(bt), engine_s = engine_s, status = info$status,
       t_pre = tel$t_pre %||% NA_real_, t_loop = tel$t_loop %||% NA_real_,
       config_hash = info$config_hash, snapshot_hash = snapshot_hash, warnings = warn_note,
       completion = oem_completion(bt), reasons = oem_reasons(bt))
}

# Availability diagnostic reason counts other than the per-pulse bookkeeping.
oem_reasons <- function(bt) {
  d <- tryCatch(as.data.frame(ledgr_results(bt, "diagnostics")), error = function(e) NULL)
  if (is.null(d) || !nrow(d) || !"reason_code" %in% names(d)) return("")
  r <- d$reason_code[!d$reason_code %in% c("decision_recorded", "affordability_reconciled", "")]
  if (!length(r)) return("")
  t <- table(r)
  paste(sprintf("%s=%d", names(t), as.integer(t)), collapse = " ")
}

# Availability completion record (stop reason, last valued pulse); NA for dense.
oem_completion <- function(bt) {
  x <- ledgr_run_completion(bt)
  if (!isTRUE(x$completion_evidence_available)) return("no completion record")
  paste(x$completion_status, x$stop_reason, format(x$achieved_end_utc, tz = "UTC"),
        paste(x$affected_instrument_ids, collapse = ","), sep = " / ")
}

oem_plain <- function(x) {
  x <- as.data.frame(x, stringsAsFactors = FALSE)
  x$run_id <- NULL
  for (col in names(x)) {
    if (inherits(x[[col]], "POSIXct")) {
      x[[col]] <- format(x[[col]], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    } else if (is.numeric(x[[col]])) {
      x[[col]] <- sprintf("%.17g", x[[col]])
    } else if (is.list(x[[col]])) {
      x[[col]] <- vapply(x[[col]], function(v) paste(format(v), collapse = "|"), character(1))
    } else {
      x[[col]] <- as.character(x[[col]])
    }
  }
  rownames(x) <- NULL
  x
}

oem_surfaces <- function(bt) {
  fills <- as.data.frame(ledgr_results(bt, "fills"))
  ledger <- as.data.frame(ledgr_results(bt, "ledger"))
  positions <- if (nrow(fills)) {
    signed <- ifelse(fills$side == "BUY", fills$qty, -fills$qty)
    p <- stats::aggregate(list(qty = signed), list(instrument_id = fills$instrument_id), sum)
    p[order(p$instrument_id), , drop = FALSE]
  } else data.frame(instrument_id = character(), qty = numeric())
  metrics <- ledgr_compute_metrics(bt)
  list(
    fills = oem_plain(fills),
    ledger = oem_plain(ledger),
    equity = oem_plain(ledgr_results(bt, "equity")),
    trades = oem_plain(ledgr_results(bt, "trades")),
    positions = oem_plain(positions),
    metrics = oem_plain(as.data.frame(lapply(metrics, function(v) if (length(v) == 1L) v else NA)))
  )
}

# ---- checker ----------------------------------------------------------------

# Compares two plain (all-character) frames. Returns "identical" or a
# description of the first differing row and its differing columns.
oem_diff <- function(ref, cand) {
  if (is.null(ref) || is.null(cand)) return("missing surface")
  if (!identical(names(ref), names(cand))) {
    return(sprintf("columns differ: [%s] vs [%s]", paste(names(ref), collapse = ","),
                   paste(names(cand), collapse = ",")))
  }
  n <- min(nrow(ref), nrow(cand))
  rows <- seq_len(n)
  differs <- vapply(names(ref), function(col) {
    a <- ref[[col]][rows]; b <- cand[[col]][rows]
    sum(!(a == b | (is.na(a) & is.na(b))), na.rm = TRUE) + sum(xor(is.na(a), is.na(b)))
  }, numeric(1))
  bad_rows <- which(Reduce(`|`, lapply(names(ref), function(col) {
    a <- ref[[col]][rows]; b <- cand[[col]][rows]
    xor(is.na(a), is.na(b)) | (!is.na(a) & !is.na(b) & a != b)
  }), logical(n)))
  count_note <- if (nrow(ref) != nrow(cand)) sprintf("row count %d vs %d", nrow(ref), nrow(cand)) else ""
  if (!length(bad_rows)) return(if (nzchar(count_note)) count_note else "identical")
  i <- bad_rows[[1L]]
  bad <- names(differs)[differs > 0]
  first <- names(ref)[!mapply(identical, ref[i, ], cand[i, ])]
  paste0(
    sprintf("first row %d: %s", i, paste(sprintf("%s %s -> %s", first,
      unlist(ref[i, first]), unlist(cand[i, first])), collapse = "; ")),
    sprintf(" | differing rows by column: %s of %d",
            paste(sprintf("%s=%d", bad, differs[bad]), collapse = ", "), n),
    if (nzchar(count_note)) paste0(" | ", count_note) else ""
  )
}

oem_write <- function(arm, dir) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  if (!is.null(arm$error)) {
    writeLines(c(paste(class(arm$error), collapse = "|"), conditionMessage(arm$error)),
               file.path(dir, "error.txt"))
    return(invisible())
  }
  for (s in names(arm$surfaces)) {
    con <- gzfile(file.path(dir, paste0(s, ".csv.gz")), "w")
    utils::write.csv(arm$surfaces[[s]], con, row.names = FALSE)
    close(con)
  }
}

oem_compare <- function(case, dense, avail) {
  surfaces <- c("fills", "ledger", "equity", "trades", "positions", "metrics")
  data.frame(
    case = case, surface = surfaces,
    result = vapply(surfaces, function(s) {
      if (!is.null(dense$error)) return(paste("dense error:", conditionMessage(dense$error)))
      if (!is.null(avail$error)) return(paste("availability error:", conditionMessage(avail$error)))
      oem_diff(dense$surfaces[[s]], avail$surfaces[[s]])
    }, character(1)),
    stringsAsFactors = FALSE, row.names = NULL
  )
}

# ---- cases ------------------------------------------------------------------

oem_cases <- function() {
  c("prereq", "peer", "peer_builtin", "peer_members", "lw", "gap_held", "gap_held_default",
    "gap_free", "gap_exec", "gut")
}

# Picks one (instrument, pulse) bar to delete, derived from the full-bars
# dense run's fills: "held" = strictly inside a holding interval, "free" = an
# instrument never held, "exec" = the execution bar of an opening fill.
oem_pick_gap <- function(fills, bars, kind) {
  fills <- fills[order(fills$instrument_id, as.numeric(fills$event_seq)), , drop = FALSE]
  pulses <- sort(unique(format(bars$ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")))
  mid <- pulses[seq(length(pulses) %/% 3L, 2L * length(pulses) %/% 3L)]
  # "held" starts at a BUY and runs to the next fill; "free" starts at a SELL.
  side <- if (identical(kind, "free")) "SELL" else "BUY"
  buys <- which(fills$side == side & fills$recording_pulse_ts_utc %in% mid)
  for (b in buys) {
    if (identical(kind, "exec")) {
      return(list(instrument_id = fills$instrument_id[[b]], ts = fills$recording_pulse_ts_utc[[b]]))
    }
    nxt <- b + 1L
    if (nxt > nrow(fills) || fills$instrument_id[[nxt]] != fills$instrument_id[[b]]) next
    inside <- pulses[pulses > fills$recording_pulse_ts_utc[[b]] & pulses < fills$recording_pulse_ts_utc[[nxt]]]
    if (length(inside) >= 3L) {
      return(list(instrument_id = fills$instrument_id[[b]], ts = inside[[2L]]))
    }
  }
  stop("No gap candidate of kind ", kind)
}

oem_drop_bar <- function(bars, gap) {
  hit <- bars$instrument_id == gap$instrument_id &
    format(bars$ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC") == gap$ts
  stopifnot(sum(hit) == 1L)
  bars[!hit, , drop = FALSE]
}

# The gut: move one opening fill's execution-bar open inside its high/low.
oem_break_bar <- function(bars, fills) {
  first <- fills[fills$side == "BUY", , drop = FALSE][1L, ]
  hit <- which(bars$instrument_id == first$instrument_id &
    format(bars$ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC") == first$recording_pulse_ts_utc)
  o <- bars$open[hit]
  bars$open[hit] <- if (bars$high[hit] > o) o + (bars$high[hit] - o) / 2 else o - (o - bars$low[hit]) / 2
  bars
}

# Prerequisite: can the availability path run on a dense snapshot (no sealed
# facts) with a calendar implied from its bars? Executes the public entry
# and the internal calendar readers against the dense peer snapshot.
oem_prereq <- function(out_dir) {
  fx <- oem_fixture("peer")
  work <- file.path(tempdir(), "prereq")
  dir.create(work, recursive = TRUE, showWarnings = FALSE)
  snap <- oem_seal(fx$bars, file.path(work, "dense.duckdb"), "oem_dense")
  on.exit(ledgr_snapshot_close(snap), add = TRUE)
  root_before <- ledgr_snapshot_info(snap)$snapshot_hash
  attempt <- function(step, expr) {
    res <- tryCatch({ force(expr); "ran" }, error = function(e) {
      paste0(class(e)[[1L]], ": ", conditionMessage(e))
    })
    data.frame(step = step, outcome = res, stringsAsFactors = FALSE)
  }
  con <- ledgr_snapshot_connection(snap)$con
  data <- ledgr_availability_provider_data(con, snap$snapshot_id)
  bar_range <- ledgr_snapshot_bar_range(con, snap$snapshot_id,
                                        min(fx$bars$ts_utc), max(fx$bars$ts_utc))
  rows <- rbind(
    attempt("public: ledgr_experiment(dense snapshot, valuation_policy = never stale)",
      ledgr_experiment(snap, fx$strategy, features = fx$features,
                       cost_model = ledgr_cost_zero(),
                       valuation_policy = ledgr_valuation_stale(0, "refuse"))),
    data.frame(step = "internal: sealed snapshot_sessions rows on the dense snapshot",
               outcome = as.character(nrow(data$sessions))),
    attempt("internal: ledgr_availability_require_coverage(provider sessions)",
      ledgr_availability_require_coverage(list(sessions = data$sessions), bar_range)),
    attempt("internal: ledgr_availability_calendar(provider sessions)",
      ledgr_availability_calendar(list(sessions = data$sessions),
                                  min(fx$bars$ts_utc), max(fx$bars$ts_utc))),
    data.frame(step = "snapshot root unchanged by the attempts",
               outcome = as.character(identical(root_before, ledgr_snapshot_info(snap)$snapshot_hash)))
  )
  dir.create(file.path(out_dir, "prereq"), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(rows, file.path(out_dir, "prereq", "prereq.csv"), row.names = FALSE)
  print(rows, right = FALSE)
}

oem_run_case <- function(case, out_dir) {
  if (identical(case, "prereq")) return(oem_prereq(out_dir))
  work <- file.path(tempdir(), case)
  dir.create(work, recursive = TRUE, showWarnings = FALSE)
  never_stale <- ledgr_valuation_stale(max_sessions = 0, exhausted = "refuse")
  spec <- switch(case,
    peer = list(fx = "peer", policy = never_stale),
    peer_builtin = list(fx = "peer", policy = never_stale, features = "builtin"),
    peer_members = list(fx = "peer", policy = never_stale, membership = TRUE),
    lw = list(fx = "lw", policy = never_stale),
    gap_held = list(fx = "peer", policy = never_stale, gap = "held"),
    gap_held_default = list(fx = "peer", policy = ledgr_valuation_stale(), gap = "held"),
    gap_free = list(fx = "peer", policy = never_stale, gap = "free"),
    gap_exec = list(fx = "peer", policy = never_stale, gap = "exec"),
    gut = list(fx = "peer", policy = never_stale, gut = TRUE),
    stop("Unknown case: ", case))
  fx <- oem_fixture(spec$fx)
  if (identical(spec$features, "builtin")) {
    fx$features <- oem_peer_features("builtin")
    fx$strategy <- oem_peer_strategy("sma_5", "sma_10")
  }
  note <- ""
  dense_bars <- avail_bars <- fx$bars
  if (!is.null(spec$gap) || isTRUE(spec$gut)) {
    base <- oem_arm(fx, "dense", work)
    base_fills <- base$surfaces$fills
    if (isTRUE(spec$gut)) {
      avail_bars <- oem_break_bar(fx$bars, base_fills)
      note <- "gut: one execution-bar open changed in the availability arm only"
    } else {
      gap <- oem_pick_gap(base_fills, fx$bars, spec$gap)
      dense_bars <- avail_bars <- oem_drop_bar(fx$bars, gap)
      note <- sprintf("gap %s: removed bar %s at %s", spec$gap, gap$instrument_id, gap$ts)
    }
  }
  dense <- oem_arm(fx, "dense", work, bars = dense_bars)
  avail <- oem_arm(fx, "availability", work, policy = spec$policy,
                   membership = isTRUE(spec$membership), bars = avail_bars)
  oem_write(dense, file.path(out_dir, case, "dense"))
  oem_write(avail, file.path(out_dir, case, "availability"))
  cmp <- oem_compare(case, dense, avail)
  ident <- data.frame(case = case, arm = c("dense", "availability"),
                      status = c(dense$status %||% "ERROR", avail$status %||% "ERROR"),
                      completion = c(dense$completion %||% NA, avail$completion %||% NA),
                      engine_s = c(dense$engine_s, avail$engine_s),
                      t_pre = c(dense$t_pre %||% NA, avail$t_pre %||% NA),
                      t_loop = c(dense$t_loop %||% NA, avail$t_loop %||% NA),
                      snapshot_hash = c(dense$snapshot_hash %||% NA, avail$snapshot_hash %||% NA),
                      config_hash = c(dense$config_hash %||% NA, avail$config_hash %||% NA),
                      warnings = c(dense$warnings %||% "", avail$warnings %||% ""),
                      reasons = c(dense$reasons %||% "", avail$reasons %||% ""),
                      note = note)
  utils::write.csv(cmp, file.path(out_dir, case, "compare.csv"), row.names = FALSE)
  utils::write.csv(ident, file.path(out_dir, case, "identity.csv"), row.names = FALSE)
  print(cmp, right = FALSE)
  print(ident)
  invisible(cmp)
}

# ---- clock ------------------------------------------------------------------

# Engine phase (the ledgr_run() call) of the peer fixture, one arm per fresh
# process, alternating order across pairs.
oem_clock <- function(repo, out_dir, features = "ttr", pairs = 3L) {
  script <- file.path(repo, "dev/spikes/one_execution_mode/probe.R")
  rscript <- file.path(R.home("bin"), "Rscript")
  child <- function(mode) {
    out <- system2(rscript, c(script, repo, out_dir, "--clock-child", mode, features),
                   stdout = TRUE, stderr = FALSE)
    line <- grep("^ENGINE_S ", out, value = TRUE)
    if (length(line) != 1L) stop("Clock child failed: ", paste(out, collapse = "\n"))
    v <- as.numeric(strsplit(sub("^ENGINE_S ", "", line), " ")[[1L]])
    data.frame(engine_s = v[[1L]], t_pre = v[[2L]], t_loop = v[[3L]])
  }
  rows <- list()
  for (k in seq_len(pairs)) {
    order <- if (k %% 2L) c("dense", "availability") else c("availability", "dense")
    for (mode in order) rows[[length(rows) + 1L]] <- data.frame(features = features, pair = k, arm = mode, child(mode))
  }
  rows <- do.call(rbind, rows)
  med <- function(arm, col) stats::median(rows[[col]][rows$arm == arm])
  pair_ratio <- function(col) stats::median(
    rows[[col]][rows$arm == "availability"][order(rows$pair[rows$arm == "availability"])] /
      rows[[col]][rows$arm == "dense"][order(rows$pair[rows$arm == "dense"])])
  summary <- data.frame(
    features = features, phase = c("engine_s", "t_pre", "t_loop"),
    dense_median_s = vapply(c("engine_s", "t_pre", "t_loop"), med, numeric(1), arm = "dense"),
    availability_median_s = vapply(c("engine_s", "t_pre", "t_loop"), med, numeric(1), arm = "availability"),
    median_pair_ratio = vapply(c("engine_s", "t_pre", "t_loop"), pair_ratio, numeric(1)),
    row.names = NULL)
  dir.create(file.path(out_dir, "clock"), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(rows, file.path(out_dir, "clock", paste0("clock_raw_", features, ".csv")), row.names = FALSE)
  utils::write.csv(summary, file.path(out_dir, "clock", paste0("clock_summary_", features, ".csv")), row.names = FALSE)
  print(rows); print(summary)
}

oem_clock_child <- function(out_dir, mode, features) {
  fx <- oem_fixture("peer")
  if (identical(features, "builtin")) {
    fx$features <- oem_peer_features("builtin")
    fx$strategy <- oem_peer_strategy("sma_5", "sma_10")
  }
  work <- file.path(tempdir(), paste0("clock_", mode))
  dir.create(work, recursive = TRUE, showWarnings = FALSE)
  arm <- oem_arm(fx, mode, work, policy = ledgr_valuation_stale(max_sessions = 0, exhausted = "refuse"))
  if (!is.null(arm$error)) stop(conditionMessage(arm$error))
  cat(sprintf("ENGINE_S %.3f %.3f %.3f\n", arm$engine_s, arm$t_pre, arm$t_loop))
}

oem_main <- function(args = commandArgs(TRUE)) {
  repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
  out_dir <- args[[2L]]
  oem_load(repo)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  if (length(args) >= 4L && identical(args[[3L]], "--clock-child")) {
    return(oem_clock_child(out_dir, args[[4L]], args[[5L]]))
  }
  cases <- if (length(args) > 2L) args[-(1:2)] else oem_cases()
  for (case in cases) {
    cat("== case", case, "\n")
    if (startsWith(case, "clock")) {
      oem_clock(repo, out_dir, features = if (identical(case, "clock_builtin")) "builtin" else "ttr")
    } else {
      oem_run_case(case, out_dir)
    }
  }
}

if (sys.nframe() == 0L) oem_main()
