# Runnable fork for the late-known barrier revision seam, scenario driven.
#
# Spike protocol section 3. Step one built one fork and ran it; this is step two,
# pushing it at edges so its behaviour generates the cases. Expected answers are
# frozen only in the committed evidence CSV, never pre-authored here.
#
# Charter: dev/spikes/segmented-feature-views/charter.md
# Question: does a late-known carry barrier revise an earlier finite-window
# feature value and its evidence, while a previously returned result stays
# unchanged?
#
# Production R/ code is not modified. The candidate preparation is standalone,
# in the shape the availability-provider-preparation spike used.
#
#   Rscript dev/spikes/segmented-feature-views/spike_runner.R

suppressMessages(pkgload::load_all(".", quiet = TRUE, export_all = TRUE))

OUT <- "dev/spikes/segmented-feature-views"
rows <- list()
record <- function(case, key, value, unit, how) {
  rows[[length(rows) + 1L]] <<- data.frame(
    case = case, key = key, value = as.character(value), unit = unit,
    derived_from = how, stringsAsFactors = FALSE
  )
}

# ------------------------------------------------------------------- fixture
base_inputs <- function(seed = 11L) {
  ledgr_sim_pit_inputs(
    instrument_ids = paste0("SG", 1:4), from = "2020-01-01", to = "2020-01-31",
    seed = seed, venue_id = "SPIKE_VENUE", universe_id = "SPIKE_UNIVERSE"
  )
}

# Seal one snapshot whose subject instrument carries a late-known inactive
# interval carved out of its active assertions. Opposing assertions may not
# overlap in effective time (LFB-012), so the interval is carved rather than
# layered; before its knowledge time it is absent, which resolves to `unknown`,
# and gate 21 leaves `unknown` unrestricted.
seal_with_barrier <- function(inputs, subject, from_i, to_i, known_i, drop_bars = integer()) {
  sess <- inputs$sessions
  open_dates <- sess$session_date[sess$status == "open"]
  close_utc <- ledgr_session_times(sess$session_close, sess$session_date, "UTC",
                                   "session_close")
  at <- function(i) close_utc[match(open_dates[[i]], sess$session_date)]

  others <- inputs$lifetime[inputs$lifetime$instrument_id != subject, , drop = FALSE]
  carved <- data.frame(
    instrument_id = subject,
    effective_from = c(at(1L), at(from_i), at(to_i)),
    effective_to = c(at(from_i), at(to_i), as.POSIXct(NA, tz = "UTC")),
    knowledge_time = c(at(1L), at(known_i), at(1L)),
    assertion = c("known_active", "known_inactive", "known_active"),
    terminal_event = NA_character_, source = "spike_segmented",
    stringsAsFactors = FALSE
  )
  bars <- inputs$bars
  if (length(drop_bars) > 0L) {
    kill <- bars$instrument_id == subject &
      as.numeric(as.POSIXct(bars$ts_utc, tz = "UTC")) %in%
        as.numeric(vapply(drop_bars, at, numeric(1)))
    bars <- bars[!kill, , drop = FALSE]
  }
  args_for <- function(family) {
    spec <- inputs$recipe$constructors[[family]]
    spec[setdiff(names(spec), "enabled")]
  }
  facts <- ledgr_facts(
    do.call(ledgr_facts_sessions, c(list(df = sess), args_for("sessions"))),
    do.call(ledgr_facts_membership_snapshots,
            c(list(df = inputs$membership), args_for("membership"))),
    do.call(ledgr_facts_lifetime, c(list(df = rbind(others, carved)),
                                    args_for("lifetime"))),
    do.call(ledgr_facts_trading_status,
            c(list(df = inputs$trading_status), args_for("trading_status")))
  )
  db <- tempfile(fileext = ".duckdb")
  snap <- ledgr_snapshot_from_df(bars, instruments_df = inputs$instruments,
                                 facts = facts, db_path = db,
                                 price_basis = inputs$recipe$price_basis)
  list(snapshot = snap, db = db, axis = as.numeric(close_utc[
    match(open_dates, sess$session_date)]), open_dates = open_dates,
    known_at = as.numeric(at(known_i)))
}

# ------------------------------------- the candidate: one view per cutoff
views <- function(sealed, subject, age, width) {
  con <- DBI::dbConnect(duckdb::duckdb(), sealed$snapshot$db_path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  bars <- DBI::dbGetQuery(
    con, paste("SELECT ts_utc, close FROM snapshot_bars",
               "WHERE snapshot_id = ? AND instrument_id = ? ORDER BY ts_utc"),
    params = list(sealed$snapshot$snapshot_id, subject)
  )
  prov <- ledgr_availability_provider_data(con, sealed$snapshot$snapshot_id)
  life <- prov$lifetime[as.character(prov$lifetime$instrument_id) == subject, , drop = FALSE]

  axis <- sealed$axis
  bts <- as.numeric(as.POSIXct(bars$ts_utc, tz = "UTC"))
  observed <- axis %in% bts
  close_at <- rep(NA_real_, length(axis))
  close_at[observed] <- bars$close[match(axis[observed], bts)]

  barriers_at <- function(cutoff) {
    acc <- life[as.character(life$assertion) == "known_inactive" &
                  as.numeric(as.POSIXct(life$knowledge_time, tz = "UTC")) <= cutoff, ,
                drop = FALSE]
    hit <- logical(length(axis))
    for (i in seq_len(nrow(acc))) {
      s <- as.numeric(as.POSIXct(acc$effective_from[[i]], tz = "UTC"))
      e <- as.numeric(as.POSIXct(acc$effective_to[[i]], tz = "UTC"))
      if (is.na(e)) e <- Inf
      hit <- hit | (axis >= s & axis < e)
    }
    hit
  }
  # Price-input carry: fill from the latest earlier observed session, within
  # `age`, provided the filled span does not touch a barrier session. Section 5.2
  # defines a barrier as a session or interval a carried value may not span.
  prepare <- function(cutoff) {
    bar <- barriers_at(cutoff)
    out <- close_at
    carried <- rep(NA_integer_, length(axis))
    for (i in seq_along(axis)) {
      if (observed[[i]]) next
      src <- if (i == 1L) integer() else rev(which(observed[seq_len(i - 1L)]))
      if (length(src) == 0L) next
      src <- src[[1L]]
      if ((i - src) > age) next
      if (any(bar[seq.int(src + 1L, i)])) next
      out[[i]] <- close_at[[src]]
      carried[[i]] <- i - src
    }
    list(close = out, carried = carried, barrier = bar)
  }
  feature <- function(prep) {
    v <- rep(NA_real_, length(axis))
    for (i in seq.int(width, length(axis))) {
      w <- prep$close[seq.int(i - width + 1L, i)]
      if (!anyNA(w)) v[[i]] <- mean(w)
    }
    v
  }
  list(prepare = prepare, feature = feature, observed = observed,
       n_axis = length(axis))
}

revised <- function(a, b) {
  which(!(is.na(a) & is.na(b)) &
          (is.na(a) != is.na(b) |
             (!is.na(a) & !is.na(b) & abs(a - b) > 1e-9)))
}

# ------------------------------------------------------------------- cases
run_case <- function(name, subject_i = 4L, from_i = 6L, to_i = 8L, known_i = 18L,
                     age = 5L, width = 3L, drop_bars = integer(), seed = 11L) {
  inputs <- base_inputs(seed)
  subject <- inputs$instruments$instrument_id[[subject_i]]
  sealed <- seal_with_barrier(inputs, subject, from_i, to_i, known_i, drop_bars)
  on.exit({ ledgr_snapshot_close(sealed$snapshot); unlink(sealed$db) }, add = TRUE)
  v <- views(sealed, subject, age, width)
  before <- v$feature(v$prepare(sealed$known_at - 1))
  after <- v$feature(v$prepare(sealed$known_at))
  d <- revised(before, after)
  record(name, "revised_cells", length(d), "count", "difference between views")
  record(name, "carried_before", sum(!is.na(v$prepare(sealed$known_at - 1)$carried)),
         "count", "candidate carry at the earlier cutoff")
  record(name, "carried_after", sum(!is.na(v$prepare(sealed$known_at)$carried)),
         "count", "candidate carry at the later cutoff")
  record(name, "stable_on_recompute",
         identical(v$feature(v$prepare(sealed$known_at - 1)), before), "logical",
         "two preparations at the same cutoff")
  # Section 4.4: an observation inside an accepted inactive interval stays
  # admissible. Check the prepared close at an observed in-barrier session.
  pa <- v$prepare(sealed$known_at)
  inside <- which(pa$barrier & v$observed)
  if (length(inside) > 0L) {
    record(name, "observed_inside_barrier_retained",
           !is.na(pa$close[[inside[[1L]]]]), "logical",
           "prepared close at an observed session inside the barrier")
  }
  if (length(d) > 0L) {
    record(name, "first_revised_index", d[[1L]], "index", "first differing cell")
    record(name, "last_revised_index", d[[length(d)]], "index", "last differing cell")
    # Locality: section 6.1 bounds the affected range at [a, b + age + width - 1].
    lo <- from_i
    hi <- to_i + age + width - 1L
    record(name, "revisions_inside_bound",
           all(d >= lo & d <= hi), "logical",
           sprintf("all revised indices within [%d, %d]", lo, hi))
  }
  invisible(NULL)
}

run_case("A_gap_inside_barrier")                                    # the seam
run_case("B_no_gap_inside_barrier", drop_bars = integer(), from_i = 12L, to_i = 14L)
run_case("C_gap_before_barrier", drop_bars = 3L, from_i = 12L, to_i = 14L)
run_case("D_strict_policy_no_carry", age = 0L)
run_case("E_age_refuses_before_barrier", drop_bars = c(10L, 11L), from_i = 14L,
         to_i = 16L, known_i = 20L, age = 1L)
run_case("F_width_five", width = 5L)
run_case("G_barrier_late_in_axis", from_i = 15L, to_i = 17L, known_i = 20L)
run_case("H_wide_barrier", from_i = 5L, to_i = 12L)

evidence <- do.call(rbind, rows)
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(evidence, file.path(OUT, "spike_evidence.csv"), row.names = FALSE)
print(evidence, right = FALSE, max = 400)
