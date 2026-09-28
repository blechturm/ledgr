# Ablation for the segmented-feature-views spike.
#
# Spike protocol section 3, step two continued: push the fork at edges the eight
# charter cases hold fixed. The charter established the seam on one instrument,
# one authoring style and one width. Two claims in the synthesis are stated in
# quantities and are falsifiable by varying exactly those:
#
#   Block A, authoring style. Section 6.1 bounds the forward reach at `W_f - 1`
#   and fences the derivation to features whose entire input dependency is
#   bounded by `W_f`. The fence is either load bearing or decorative. Vary the
#   style and find out.
#
#   Block B, universe size. Section 6.2 claims a breakpoint recomputes one
#   series rather than the panel, from per-instrument locality. A cross
#   instrument leak falsifies it. Vary the universe and count who revises.
#
# Kill condition for this ablation: if a finite-window style revises outside
# [a, b + A_in + W_f - 1], section 6.1's bound is wrong as written. If a
# non-subject instrument revises under an instrument-scoped barrier, section
# 6.2's locality premise is wrong.
#
#   Rscript dev/spikes/segmented-feature-views/spike_ablation.R

suppressMessages(pkgload::load_all(".", quiet = TRUE, export_all = TRUE))

OUT <- "dev/spikes/segmented-feature-views"
source(file.path(OUT, "spike_core.R"))

rows <- list()
record <- function(case, key, value, unit, how) {
  rows[[length(rows) + 1L]] <<- data.frame(
    case = case, key = key, value = as.character(value), unit = unit,
    derived_from = how, stringsAsFactors = FALSE
  )
}

# Geometry shared with charter case A, so block A varies only the style.
FROM_I <- 6L
TO_I <- 8L
KNOWN_I <- 18L
AGE <- 5L

# =============================================== block A: authoring styles
# One universe, one barrier, one width where the style allows it. `width` is the
# window for the finite styles and the EMA span; `expanding_mean` ignores it.
ablate_style <- function(style, width) {
  name <- sprintf("A_%s_w%d", style, width)
  inputs <- base_inputs(11L)
  subject <- inputs$instruments$instrument_id[[4L]]
  sealed <- seal_with_barrier(inputs, subject, FROM_I, TO_I, KNOWN_I)
  on.exit({
    ledgr_snapshot_close(sealed$snapshot)
    unlink(sealed$db)
  }, add = TRUE)
  v <- views(sealed, subject, AGE, width, style = style)
  before <- v$feature(v$prepare(sealed$known_at - 1))
  after <- v$feature(v$prepare(sealed$known_at))
  d <- revised(before, after)
  record(name, "revised_cells", length(d), "count", "difference between views")
  record(name, "axis_sessions", v$n_axis, "count", "venue axis length")
  if (length(d) > 0L) {
    record(name, "first_revised_index", d[[1L]], "index", "first differing cell")
    record(name, "last_revised_index", d[[length(d)]], "index",
           "last differing cell")
    # Forward reach past the barrier's last session, which section 6.1 puts at
    # A_in + W_f - 1 for a finite window.
    record(name, "reach_past_barrier", d[[length(d)]] - TO_I, "sessions",
           sprintf("last revised index minus barrier end %d", TO_I))
    record(name, "inside_section_6_1_bound",
           all(d >= FROM_I & d <= TO_I + AGE + width - 1L), "logical",
           sprintf("all revised within [%d, %d]", FROM_I,
                   TO_I + AGE + width - 1L))
    record(name, "revises_to_end_of_axis",
           d[[length(d)]] == v$n_axis, "logical",
           "last revised cell is the final session on the axis")
  }
  invisible(NULL)
}

for (w in c(3L, 5L)) {
  ablate_style("rolling_mean", w)
  ablate_style("rolling_max", w)
  ablate_style("ema", w)
}
ablate_style("expanding_mean", 3L)

# ================================================ block B: universe size
# The candidate at panel scope: read the sealed store once, then prepare and
# compute per instrument. Counts how many instruments revise when one
# instrument's barrier becomes knowable.
#
# `cross_sectional = TRUE` swaps the per-instrument feature for one reading the
# cross-sectional mean of prepared closes. Section 6.2 states that such a feature
# breaks per-instrument locality and collapses the cheap single-series recompute
# into a panel recompute. That is an assertion in the document; here it runs.
panel_revisions <- function(n_inst, width = 3L, style = "rolling_mean",
                            cross_sectional = FALSE) {
  name <- if (cross_sectional) sprintf("C_cross_sectional_%d", n_inst)
          else sprintf("B_universe_%d", n_inst)
  inputs <- base_inputs(11L, n_inst = n_inst)
  subject <- inputs$instruments$instrument_id[[4L]]
  sealed <- seal_with_barrier(inputs, subject, FROM_I, TO_I, KNOWN_I)
  on.exit({
    ledgr_snapshot_close(sealed$snapshot)
    unlink(sealed$db)
  }, add = TRUE)

  con <- DBI::dbConnect(duckdb::duckdb(), sealed$snapshot$db_path,
                        read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  bars <- DBI::dbGetQuery(
    con, paste("SELECT instrument_id, ts_utc, close FROM snapshot_bars",
               "WHERE snapshot_id = ? ORDER BY instrument_id, ts_utc"),
    params = list(sealed$snapshot$snapshot_id)
  )
  prov <- ledgr_availability_provider_data(con, sealed$snapshot$snapshot_id)
  axis <- sealed$axis
  fn <- feature_styles[[style]]

  ids <- as.character(inputs$instruments$instrument_id)
  bar_inst <- as.character(bars$instrument_id)
  bar_ts <- as.numeric(as.POSIXct(bars$ts_utc, tz = "UTC"))
  life_inst <- as.character(prov$lifetime$instrument_id)
  life_know <- as.numeric(as.POSIXct(prov$lifetime$knowledge_time, tz = "UTC"))
  life_from <- as.numeric(as.POSIXct(prov$lifetime$effective_from, tz = "UTC"))
  life_to <- as.numeric(as.POSIXct(prov$lifetime$effective_to, tz = "UTC"))
  life_inactive <- as.character(prov$lifetime$assertion) == "known_inactive"

  prepared_at <- function(id, cutoff) {
    sel <- bar_inst == id
    bts <- bar_ts[sel]
    observed <- axis %in% bts
    close_at <- rep(NA_real_, length(axis))
    close_at[observed] <- bars$close[sel][match(axis[observed], bts)]
    lsel <- which(life_inst == id & life_inactive & life_know <= cutoff)
    bar <- logical(length(axis))
    for (k in lsel) {
      e <- life_to[[k]]
      if (is.na(e)) e <- Inf
      bar <- bar | (axis >= life_from[[k]] & axis < e)
    }
    out <- close_at
    for (i in seq_along(axis)) {
      if (observed[[i]]) next
      src <- if (i == 1L) integer() else rev(which(observed[seq_len(i - 1L)]))
      if (length(src) == 0L) next
      src <- src[[1L]]
      if ((i - src) > AGE) next
      if (any(bar[seq.int(src + 1L, i)])) next
      out[[i]] <- close_at[[src]]
    }
    out
  }

  # Per instrument the feature reads only its own prepared closes. Cross
  # sectionally it reads its own value demeaned by the panel at that session, so
  # one instrument's input reaches every instrument's output.
  feat_at <- function(cutoff) {
    p <- vapply(ids, function(id) prepared_at(id, cutoff), numeric(length(axis)))
    if (cross_sectional) {
      m <- apply(p, 1L, function(r)
        if (all(is.na(r))) NA_real_ else mean(r, na.rm = TRUE))
      p <- p - m
    }
    vapply(seq_along(ids), function(j) fn(p[, j], width), numeric(length(axis)))
  }

  before <- feat_at(sealed$known_at - 1)
  after <- feat_at(sealed$known_at)
  revised_any <- character()
  total <- 0L
  for (j in seq_along(ids)) {
    d <- revised(before[, j], after[, j])
    if (length(d) > 0L) {
      revised_any <- c(revised_any, ids[[j]])
      total <- total + length(d)
    }
  }
  record(name, "instruments", length(ids), "count", "universe size")
  record(name, "instruments_revised", length(revised_any), "count",
         "instruments with any differing cell between cutoffs")
  record(name, "subject_is_the_only_one_revised",
         identical(revised_any, subject), "logical",
         "revised set equals the instrument carrying the barrier")
  record(name, "panel_revised_cells", total, "count",
         "revised cells summed over the panel")
  # Section 6.2's multiplier: breakpoints are the distinct knowledge times of an
  # instrument's own barrier facts. Counted from the sealed store.
  per <- vapply(ids, function(id)
    length(unique(life_know[life_inst == id & life_inactive])), integer(1))
  record(name, "barrier_facts_total", sum(per), "count",
         "instrument-scoped barrier knowledge times in the sealed store")
  record(name, "barrier_facts_max_per_instrument", max(per), "count",
         "largest per-instrument breakpoint count")
  record(name, "instruments_with_no_barrier", sum(per == 0L), "count",
         "instruments whose series is cutoff-invariant under this fixture")
  invisible(NULL)
}

for (n in c(4L, 40L, 200L)) panel_revisions(n)
for (n in c(4L, 40L, 200L)) panel_revisions(n, cross_sectional = TRUE)

# ======================================= block D: the bias of not revising
# What the pragmatic shortcut costs in correctness. Three series over the axis,
# all read the way a run reads them - the value at session t:
#
#   reference  prepared at t for every t. The diagonal of the correct behaviour.
#   full       one preparation using every fact in the snapshot, reused at every
#              pulse. What a backtester does when it loads today's data and runs
#              history through it. This is lookahead.
#   stale      one preparation at the run's first cutoff, never revised. This is
#              staleness, and carries no lookahead.
#
# The two shortcuts fail in opposite directions, so both are measured against the
# same reference. No clock here either: this block measures bias, not cost.
bias_of_shortcut <- function(style, width) {
  name <- sprintf("D_%s_w%d", style, width)
  inputs <- base_inputs(11L)
  subject <- inputs$instruments$instrument_id[[4L]]
  sealed <- seal_with_barrier(inputs, subject, FROM_I, TO_I, KNOWN_I)
  on.exit({
    ledgr_snapshot_close(sealed$snapshot)
    unlink(sealed$db)
  }, add = TRUE)
  v <- views(sealed, subject, AGE, width, style = style)
  n <- v$n_axis

  reference <- vapply(seq_len(n), function(t)
    v$feature(v$prepare(sealed$axis[[t]]))[[t]], numeric(1))
  full <- v$feature(v$prepare(Inf))
  stale <- v$feature(v$prepare(sealed$axis[[1L]]))

  record(name, "axis_sessions", n, "count", "venue axis length")
  record(name, "full_diag_cells_biased", length(revised(reference, full)),
         "count", "diagonal cells where the full-knowledge shortcut differs")
  record(name, "stale_diag_cells_biased", length(revised(reference, stale)),
         "count", "diagonal cells where the never-revised shortcut differs")

  # Direction. A lost signal is a session the point-in-time run could act on and
  # the shortcut cannot; a fabricated signal is the reverse.
  record(name, "full_signals_lost", sum(!is.na(reference) & is.na(full)),
         "count", "reference has a value where the shortcut has none")
  record(name, "full_signals_fabricated", sum(is.na(reference) & !is.na(full)),
         "count", "shortcut has a value where the reference has none")
  record(name, "stale_signals_lost", sum(!is.na(reference) & is.na(stale)),
         "count", "reference has a value where the shortcut has none")
  record(name, "stale_signals_fabricated", sum(is.na(reference) & !is.na(stale)),
         "count", "shortcut has a value where the reference has none")

  # Magnitude, where the shortcut produces a value at all.
  both <- !is.na(reference) & !is.na(full)
  if (any(both)) {
    rel <- abs(full[both] - reference[both]) / pmax(abs(reference[both]), 1e-12)
    record(name, "full_cells_both_present", sum(both), "count",
           "diagonal cells where reference and shortcut both have values")
    record(name, "full_max_rel_bias", signif(max(rel), 4), "ratio",
           "largest relative difference where both have values")
    record(name, "full_mean_rel_bias", signif(mean(rel), 4), "ratio",
           "mean relative difference where both have values")
  }

  # Section 6.2's segmentation payoff, from the same preparations: how many
  # distinct barrier states the axis actually visits.
  pats <- vapply(seq_len(n), function(t)
    paste(as.integer(v$prepare(sealed$axis[[t]])$barrier), collapse = ""),
    character(1))
  record(name, "cutoffs_on_axis", n, "count", "one per pulse")
  record(name, "distinct_views_needed", length(unique(pats)), "count",
         "distinct barrier states over those cutoffs")
  invisible(NULL)
}

bias_of_shortcut("rolling_mean", 3L)
bias_of_shortcut("rolling_mean", 5L)
bias_of_shortcut("ema", 3L)
bias_of_shortcut("expanding_mean", 3L)

# ================================== block E: when the shortcut stops being free
# Block D found the never-revised shortcut unbiased on the decision diagonal, but
# that is a property of the geometry rather than of the shortcut. A pulse at
# session t reads the value at t, and by the time this fixture's fact becomes
# knowable the window has already moved past the barrier, so no decision ever
# sees the revision. Move the fact earlier and it must.
#
# The crossover is the measurement: the shortcut is free while the fact arrives
# later than the feature's own reach past the barrier, and biased once it arrives
# inside it. If the crossover tracks the window width, the condition is a
# knowledge lag against `W_f` and can be stated in the synthesis.
knowledge_lag_sweep <- function(known_i, width) {
  name <- sprintf("E_known%02d_w%d", known_i, width)
  inputs <- base_inputs(11L)
  subject <- inputs$instruments$instrument_id[[4L]]
  sealed <- seal_with_barrier(inputs, subject, FROM_I, TO_I, known_i)
  on.exit({
    ledgr_snapshot_close(sealed$snapshot)
    unlink(sealed$db)
  }, add = TRUE)
  v <- views(sealed, subject, AGE, width)
  n <- v$n_axis
  reference <- vapply(seq_len(n), function(t)
    v$feature(v$prepare(sealed$axis[[t]]))[[t]], numeric(1))
  stale <- v$feature(v$prepare(sealed$axis[[1L]]))
  full <- v$feature(v$prepare(Inf))
  d <- revised(v$feature(v$prepare(sealed$axis[[1L]])), full)
  record(name, "knowledge_session", known_i, "index",
         "session whose close is the barrier's knowledge time")
  record(name, "lag_past_barrier_end", known_i - TO_I, "sessions",
         sprintf("knowledge session minus barrier end %d", TO_I))
  record(name, "history_revised_cells", length(d), "count",
         "cells a history view revises, whatever the diagonal does")
  # The crossover is relative to the affected observation, not to the barrier's
  # end, so the first revised cell is recorded rather than asserted.
  record(name, "first_history_revised_index", if (length(d) > 0L) d[[1L]] else NA,
         "index", "earliest cell a history view revises")
  record(name, "last_history_revised_index",
         if (length(d) > 0L) d[[length(d)]] else NA, "index",
         "latest cell a history view revises")
  record(name, "stale_diag_cells_biased", length(revised(reference, stale)),
         "count", "decisions the never-revised shortcut gets wrong")
  record(name, "full_diag_cells_biased", length(revised(reference, full)),
         "count", "decisions the full-knowledge shortcut gets wrong")
  invisible(NULL)
}

for (w in c(3L, 5L)) {
  for (k in c(7L, 8L, 9L, 10L, 11L, 14L)) knowledge_lag_sweep(k, w)
}

evidence <- do.call(rbind, rows)
utils::write.csv(evidence, file.path(OUT, "spike_ablation_evidence.csv"),
                 row.names = FALSE)
print(evidence, right = FALSE, max = 400)
