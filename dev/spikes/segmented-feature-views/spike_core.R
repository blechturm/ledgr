# Shared fixture and candidate for the segmented-feature-views spike.
#
# Extracted from spike_runner.R so the ablation can reuse it unchanged. The
# checker proves the extraction is behaviour preserving: the runner's recorded
# evidence must still reproduce exactly.
#
# Production R/ code is not modified. The candidate preparation is standalone,
# in the shape the availability-provider-preparation spike used.

# ------------------------------------------------------------------- fixture
base_inputs <- function(seed = 11L, n_inst = 4L) {
  ledgr_sim_pit_inputs(
    instrument_ids = paste0("SG", seq_len(n_inst)),
    from = "2020-01-01", to = "2020-01-31",
    seed = seed, venue_id = "SPIKE_VENUE", universe_id = "SPIKE_UNIVERSE"
  )
}

# Seal one snapshot whose subject instrument carries a late-known inactive
# interval carved out of its active assertions. Opposing assertions may not
# overlap in effective time (LFB-012), so the interval is carved rather than
# layered; before its knowledge time it is absent, which resolves to `unknown`,
# and gate 21 leaves `unknown` unrestricted.
seal_with_barrier <- function(inputs, subject, from_i, to_i, known_i,
                              drop_bars = integer()) {
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

# --------------------------------------------------------- authoring styles
# Each style maps a prepared close vector to a feature series. `rolling_mean` is
# the style the charter's eight cases use; the others exist to ablate the
# section 6.1 scope note, which fences the bound to features whose whole input
# dependency is bounded by `W_f`.
feature_styles <- list(
  # finite window, the charter's style
  rolling_mean = function(x, width) {
    v <- rep(NA_real_, length(x))
    for (i in seq.int(width, length(x))) {
      w <- x[seq.int(i - width + 1L, i)]
      if (!anyNA(w)) v[[i]] <- mean(w)
    }
    v
  },
  # finite window, different reducer: dependency is the window, not the mean
  rolling_max = function(x, width) {
    v <- rep(NA_real_, length(x))
    for (i in seq.int(width, length(x))) {
      w <- x[seq.int(i - width + 1L, i)]
      if (!anyNA(w)) v[[i]] <- max(w)
    }
    v
  },
  # recursive: state carries forward indefinitely, missing inputs skipped
  ema = function(x, width) {
    alpha <- 2 / (width + 1)
    v <- rep(NA_real_, length(x))
    s <- NA_real_
    for (i in seq_along(x)) {
      if (!is.na(x[[i]])) {
        s <- if (is.na(s)) x[[i]] else alpha * x[[i]] + (1 - alpha) * s
      }
      v[[i]] <- s
    }
    v
  },
  # expanding: every past observation is in scope forever
  expanding_mean = function(x, width) {
    v <- rep(NA_real_, length(x))
    n <- 0L; tot <- 0
    for (i in seq_along(x)) {
      if (!is.na(x[[i]])) { n <- n + 1L; tot <- tot + x[[i]] }
      if (n > 0L) v[[i]] <- tot / n
    }
    v
  }
)

# ------------------------------------- the candidate: one view per cutoff
views <- function(sealed, subject, age, width, style = "rolling_mean") {
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
  fn <- feature_styles[[style]]
  if (is.null(fn)) stop("unknown authoring style: ", style)
  feature <- function(prep) fn(prep$close, width)
  list(prepare = prepare, feature = feature, observed = observed,
       n_axis = length(axis))
}

revised <- function(a, b) {
  which(!(is.na(a) & is.na(b)) &
          (is.na(a) != is.na(b) |
             (!is.na(a) & !is.na(b) & abs(a - b) > 1e-9)))
}
