# WS45 shared fixture generators. Pure input data frames; no ledgr calls
# except the public constructors, so BASE and candidate see the same input.

ws45_days <- function(n_days, start = as.Date("2015-01-01")) {
  start + seq_len(n_days) - 1L
}

ws45_sessions_df <- function(n_days, start = as.Date("2015-01-01")) {
  dates <- ws45_days(n_days, start)
  weekday <- as.POSIXlt(dates)$wday
  open <- !weekday %in% c(0L, 6L)
  data.frame(
    session_date = dates,
    status = ifelse(open, "open", "closed"),
    session_open = ifelse(open, "09:30:00", NA_character_),
    session_close = ifelse(open, "16:00:00", NA_character_),
    knowledge_time = as.POSIXct("2014-12-01", tz = "UTC"),
    source = "fixture",
    stringsAsFactors = FALSE
  )
}

ws45_open_dates <- function(sessions_df) {
  sessions_df$session_date[sessions_df$status == "open"]
}

# Membership intervals: `n_inst` instruments with `per` contiguous,
# alternating-state Date intervals each.
ws45_membership_df <- function(n_inst, per, open_dates, date_class = "Date") {
  stopifnot(length(open_dates) > per + 1L)
  inst <- sprintf("I%05d", rep(seq_len(n_inst), each = per))
  k <- rep(seq_len(per), times = n_inst)
  offset <- rep((seq_len(n_inst) - 1L) %% 3L, each = per)
  from <- open_dates[k + offset]
  to <- open_dates[k + offset + 1L]
  df <- data.frame(
    instrument_id = inst,
    effective_from = from,
    effective_to = to,
    knowledge_time = from,
    member = (k %% 2L) == 1L,
    source = "fixture",
    stringsAsFactors = FALSE
  )
  if (identical(date_class, "POSIXct")) {
    df$effective_from <- as.POSIXct(paste(df$effective_from, "14:30:00"), tz = "UTC")
    df$effective_to <- as.POSIXct(paste(df$effective_to, "14:30:00"), tz = "UTC")
    df$knowledge_time <- as.POSIXct(paste(df$knowledge_time, "14:30:00"), tz = "UTC")
  }
  df
}

# Trading status with correction chains: every `every`-th row of an
# instrument is superseded by one successor (chain depth `depth`).
ws45_status_df <- function(n_inst, per, open_dates, every = 10L, depth = 1L,
                           date_class = "POSIXct") {
  at <- function(i) {
    if (identical(date_class, "Date")) return(open_dates[i])
    as.POSIXct(paste(open_dates[i], "14:30:00"), tz = "UTC")
  }
  inst_index <- rep(seq_len(n_inst), each = per)
  k <- rep(seq_len(per), times = n_inst)
  base <- data.frame(
    instrument_id = sprintf("I%05d", inst_index),
    effective_from = at(k),
    effective_to = at(k + 1L),
    knowledge_time = at(k),
    status = ifelse(k %% 2L == 1L, "active", "halted"),
    source = "fixture",
    precedence = 1L,
    fact_id = sprintf("s%05d_%04d", inst_index, k),
    supersedes_fact_id = NA_character_,
    stringsAsFactors = FALSE
  )
  if (every <= 0L) return(base)
  corrected <- which(k %% every == 0L)
  out <- list(base)
  previous <- base$fact_id[corrected]
  for (d in seq_len(depth)) {
    succ <- base[corrected, , drop = FALSE]
    succ$fact_id <- paste0(succ$fact_id, "_c", d)
    succ$supersedes_fact_id <- previous
    succ$knowledge_time <- at(k[corrected] + d)
    succ$status <- ifelse(d %% 2L == 1L, "quotation_only", base$status[corrected])
    previous <- succ$fact_id
    out[[length(out) + 1L]] <- succ
  }
  do.call(rbind, out)
}

ws45_lifetime_df <- function(n_inst, open_dates) {
  data.frame(
    instrument_id = sprintf("I%05d", seq_len(n_inst)),
    effective_from = open_dates[1L],
    knowledge_time = open_dates[1L],
    assertion = "known_active",
    source = "fixture",
    stringsAsFactors = FALSE
  )
}

ws45_dividend_df <- function(n_inst, per, open_dates, date_class = "Date") {
  inst <- sprintf("I%05d", rep(seq_len(n_inst), each = per))
  k <- rep(seq_len(per), times = n_inst)
  ent <- open_dates[2L * k]
  eff <- open_dates[2L * k + 1L]
  df <- data.frame(
    subtype = "ordinary_cash_dividend",
    parent_instrument_id = inst,
    entitlement_time = ent,
    effective_time = eff,
    complete = TRUE,
    provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = 0.25,
    gross_cash_validated = TRUE,
    source = "fixture",
    stringsAsFactors = FALSE
  )
  if (identical(date_class, "POSIXct")) {
    df$entitlement_time <- as.POSIXct(paste(df$entitlement_time, "21:00:00"), tz = "UTC")
    df$effective_time <- as.POSIXct(paste(df$effective_time, "21:00:00"), tz = "UTC")
  }
  df
}
