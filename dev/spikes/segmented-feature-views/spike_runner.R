# Smallest runnable fork for the late-known barrier revision seam.
#
# Spike protocol section 3, step 1. This is the fork, not the harness: no
# checker, no expected table, no witness list. Those come after this has run and
# its failures have generated the cases.
#
# Charter: dev/spikes/segmented-feature-views/charter.md
# Question: does a late-known carry barrier revise an earlier finite-window
# feature value and its evidence, while a previously returned result stays
# unchanged?
#
# Production R/ code is not modified. The candidate preparation is implemented
# here, standalone, in the shape the availability-provider-preparation spike
# used before its result was promoted.
#
# Run from the repository root:
#   Rscript dev/spikes/segmented-feature-views/spike_runner.R

suppressMessages(pkgload::load_all(".", quiet = TRUE, export_all = TRUE))

OUT <- "dev/spikes/segmented-feature-views"
AGE <- 5L       # declared maximum input carry age, in venue open sessions
WIDTH <- 3L     # stable_after for the one finite-window feature

rows <- list()
record <- function(key, value, unit, how) {
  rows[[length(rows) + 1L]] <<- data.frame(
    key = key, value = as.character(value), unit = unit, derived_from = how,
    stringsAsFactors = FALSE
  )
}

# ------------------------------------------------------------------- fixture
inputs <- ledgr_sim_pit_inputs(
  instrument_ids = paste0("SG", 1:4),
  from = "2020-01-01",
  to = "2020-01-31",
  seed = 11L,
  venue_id = "SPIKE_VENUE",
  universe_id = "SPIKE_UNIVERSE"
)
open_dates <- inputs$sessions$session_date[inputs$sessions$status == "open"]
close_utc <- ledgr_session_times(
  inputs$sessions$session_close, inputs$sessions$session_date, "UTC",
  "session_close"
)
at <- function(i) close_utc[match(open_dates[[i]], inputs$sessions$session_date)]

# The barrier goes on the instrument that already has a missing observation, so
# a carry path can cross it. The generator puts that gap on instrument 4.
subject <- inputs$instruments$instrument_id[[4L]]
barrier_from <- at(6L)
barrier_to <- at(8L)
barrier_known <- at(18L)

# Three non-overlapping lifetime rows. Opposing assertions may not overlap in
# effective time (LFB-012), so the inactive interval is carved out rather than
# layered over an open-ended active one. Before its knowledge time the interval
# is simply absent, which resolves to `unknown`, and gate 21 makes `unknown`
# unrestricted.
others <- inputs$lifetime[inputs$lifetime$instrument_id != subject, , drop = FALSE]
carved <- data.frame(
  instrument_id = subject,
  effective_from = c(at(1L), barrier_from, barrier_to),
  effective_to = c(barrier_from, barrier_to, as.POSIXct(NA, tz = "UTC")),
  knowledge_time = c(at(1L), barrier_known, at(1L)),
  assertion = c("known_active", "known_inactive", "known_active"),
  terminal_event = NA_character_,
  source = "spike_segmented",
  stringsAsFactors = FALSE
)
lifetime <- rbind(others, carved)
record("subject_instrument", subject, "id", "generator instrument master")
record("barrier_effective_from", format(barrier_from, "%Y-%m-%d"), "date",
       "spike fixture")
record("barrier_effective_to", format(barrier_to, "%Y-%m-%d"), "date",
       "spike fixture")
record("barrier_knowledge_time", format(barrier_known, "%Y-%m-%d"), "date",
       "spike fixture")

args_for <- function(family) {
  spec <- inputs$recipe$constructors[[family]]
  spec[setdiff(names(spec), "enabled")]
}
facts <- ledgr_facts(
  do.call(ledgr_facts_sessions, c(list(df = inputs$sessions), args_for("sessions"))),
  do.call(ledgr_facts_membership_snapshots,
          c(list(df = inputs$membership), args_for("membership"))),
  do.call(ledgr_facts_lifetime, c(list(df = lifetime), args_for("lifetime"))),
  do.call(ledgr_facts_trading_status,
          c(list(df = inputs$trading_status), args_for("trading_status")))
)
db_path <- tempfile(fileext = ".duckdb")
snapshot <- ledgr_snapshot_from_df(
  inputs$bars, instruments_df = inputs$instruments, facts = facts,
  db_path = db_path, price_basis = inputs$recipe$price_basis
)
record("fixture_seals", TRUE, "logical", "ledgr_snapshot_from_df returned")

# --------------------------------------------- read back from the sealed store
con <- DBI::dbConnect(duckdb::duckdb(), snapshot$db_path, read_only = TRUE)
on.exit({
  DBI::dbDisconnect(con, shutdown = TRUE)
  ledgr_snapshot_close(snapshot)
  unlink(db_path)
}, add = TRUE)

bars <- DBI::dbGetQuery(
  con,
  paste(
    "SELECT ts_utc, close FROM snapshot_bars",
    "WHERE snapshot_id = ? AND instrument_id = ? ORDER BY ts_utc"
  ),
  params = list(snapshot$snapshot_id, subject)
)
prov <- ledgr_availability_provider_data(con, snapshot$snapshot_id)
life <- prov$lifetime[as.character(prov$lifetime$instrument_id) == subject, , drop = FALSE]
record("sealed_bars_for_subject", nrow(bars), "count", "snapshot_bars query")
record("sealed_lifetime_rows_for_subject", nrow(life), "count",
       "ledgr_availability_provider_data")

axis <- as.numeric(close_utc[match(open_dates, inputs$sessions$session_date)])
observed <- axis %in% as.numeric(as.POSIXct(bars$ts_utc, tz = "UTC"))
close_at <- rep(NA_real_, length(axis))
close_at[observed] <- bars$close[match(axis[observed],
                                       as.numeric(as.POSIXct(bars$ts_utc, tz = "UTC")))]
record("observed_sessions", sum(observed), "count", "sealed bars against the axis")
record("missing_sessions", sum(!observed), "count", "sealed bars against the axis")

# ------------------------------- the candidate: one prepared view per cutoff
# Barrier sessions at a cutoff are the axis sessions inside an accepted
# known_inactive interval. A fact is accepted when its knowledge time has passed.
barriers_at <- function(cutoff) {
  acc <- life[
    as.character(life$assertion) == "known_inactive" &
      as.numeric(as.POSIXct(life$knowledge_time, tz = "UTC")) <= cutoff, ,
    drop = FALSE
  ]
  if (nrow(acc) == 0L) return(logical(length(axis)))
  hit <- logical(length(axis))
  for (i in seq_len(nrow(acc))) {
    s <- as.numeric(as.POSIXct(acc$effective_from[[i]], tz = "UTC"))
    e <- as.numeric(as.POSIXct(acc$effective_to[[i]], tz = "UTC"))
    if (is.na(e)) e <- Inf
    hit <- hit | (axis >= s & axis < e)
  }
  hit
}

# Price-input carry: fill a missing close from the latest earlier observed
# session, within AGE, provided no session in the filled span is a barrier.
prepare_at <- function(cutoff) {
  bar <- barriers_at(cutoff)
  out <- close_at
  carried <- rep(NA_integer_, length(axis))
  for (i in seq_along(axis)) {
    if (observed[[i]]) next
    src <- if (i == 1L) integer() else rev(which(observed[seq_len(i - 1L)]))
    if (length(src) == 0L) next
    src <- src[[1L]]
    if ((i - src) > AGE) next
    if (any(bar[seq.int(src + 1L, i)])) next
    out[[i]] <- close_at[[src]]
    carried[[i]] <- i - src
  }
  list(close = out, carried = carried, barrier = bar)
}

# One finite-window feature over prepared closes, NA if the window is incomplete.
feature_at <- function(prep) {
  v <- rep(NA_real_, length(axis))
  for (i in seq.int(WIDTH, length(axis))) {
    w <- prep$close[seq.int(i - WIDTH + 1L, i)]
    if (!anyNA(w)) v[[i]] <- mean(w)
  }
  v
}

t_before <- as.numeric(barrier_known) - 1
t_after <- as.numeric(barrier_known)
p_before <- prepare_at(t_before)
p_after <- prepare_at(t_after)
f_before <- feature_at(p_before)
f_after <- feature_at(p_after)

record("barrier_sessions_before_knowledge", sum(p_before$barrier), "count",
       "candidate resolution at the earlier cutoff")
record("barrier_sessions_after_knowledge", sum(p_after$barrier), "count",
       "candidate resolution at the later cutoff")
record("carried_sessions_before_knowledge", sum(!is.na(p_before$carried)),
       "count", "candidate carry at the earlier cutoff")
record("carried_sessions_after_knowledge", sum(!is.na(p_after$carried)),
       "count", "candidate carry at the later cutoff")

differing <- which(!(is.na(f_before) & is.na(f_after)) &
                     (is.na(f_before) != is.na(f_after) |
                        (!is.na(f_before) & !is.na(f_after) &
                           abs(f_before - f_after) > 1e-9)))
record("feature_cells_revised", length(differing), "count",
       "difference between the two prepared views")
if (length(differing) > 0L) {
  record("first_revised_session",
         format(open_dates[[differing[[1L]]]], "%Y-%m-%d"), "date",
         "index of the first differing feature cell")
  record("first_revised_before", f_before[[differing[[1L]]]], "value",
         "feature at the earlier cutoff")
  record("first_revised_after",
         ifelse(is.na(f_after[[differing[[1L]]]]), "NA",
                format(f_after[[differing[[1L]]]])), "value",
         "feature at the later cutoff")
}

# A view returned at the earlier cutoff must not change when asked again.
again <- feature_at(prepare_at(t_before))
record("earlier_view_stable_on_recompute", identical(again, f_before), "logical",
       "two preparations at the same cutoff")

evidence <- do.call(rbind, rows)
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(evidence, file.path(OUT, "spike_evidence.csv"), row.names = FALSE)
print(evidence, right = FALSE)
