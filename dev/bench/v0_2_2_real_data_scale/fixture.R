# Real-data scale fixture (Cut 11 LDG-2982).
#
# A vendor-neutral availability snapshot shaped like the 1998-2026 Sharadar
# run at reduced size: monthly complete membership sets that rotate, session
# facts, terminal delistings with labelled lifetime facts (disposed under the
# research policy), missing member bars, and cash dividends on held members
# that post during the run. A small dense snapshot exercises the dense
# result-reader branch. Fixed snapshot IDs keep run, sweep and walk-forward
# identities comparable between trees.

scale_fixture_dates <- function(n_days) {
  days <- seq(as.Date("2016-01-04"), by = "day", length.out = ceiling(n_days * 7 / 5) + 14L)
  days[as.integer(format(days, "%u")) <= 5L][seq_len(n_days)]
}

scale_fixture_snapshot <- function(db_path, n_inst = 800L, n_days = 1260L, n_mem = 300L, seed = 1L) {
  set.seed(seed)
  dates <- scale_fixture_dates(n_days)
  pulses <- as.POSIXct(paste(dates, "21:00:00"), tz = "UTC")
  ids <- sprintf("I%04d", seq_len(n_inst))
  ret <- matrix(stats::rnorm(n_inst * n_days, 0.0003, 0.02), n_inst, n_days)
  px <- 50 * exp(t(apply(ret, 1L, cumsum)))
  bars <- data.frame(
    instrument_id = rep(ids, each = n_days), ts_utc = rep(pulses, times = n_inst),
    open = as.vector(t(px)), high = as.vector(t(px)) * 1.01, low = as.vector(t(px)) * 0.99,
    close = as.vector(t(px)), volume = 1000, stringsAsFactors = FALSE
  )

  # Ten members delist at staggered dates; their bars stop and later sets
  # exclude them. A labelled terminal is disposed under the research policy.
  delisted <- ids[as.integer(round(seq(2L, n_mem - 1L, length.out = 10L)))]
  delist_day <- as.integer(round(seq(0.12, 0.85, length.out = 10L) * n_days))
  drop <- rep(FALSE, nrow(bars))
  for (k in seq_along(delisted)) {
    drop <- drop | (bars$instrument_id == delisted[[k]] & bars$ts_utc >= pulses[[delist_day[[k]]]])
  }
  # About half a percent of the remaining bars are missing (vendor gaps).
  drop <- drop | (seq_len(nrow(bars)) %in% sample.int(nrow(bars), floor(0.005 * nrow(bars))))
  bars <- bars[!drop, , drop = FALSE]

  all_days <- seq(min(dates), max(dates), by = "day")
  open <- all_days %in% dates
  sessions <- ledgr::ledgr_facts_sessions(
    data.frame(session_date = all_days, status = ifelse(open, "open", "closed"),
               session_open = ifelse(open, "14:30:00", NA), session_close = ifelse(open, "21:00:00", NA),
               stringsAsFactors = FALSE),
    venue_id = "XNYS", knowledge = "assume_effective"
  )
  month_starts <- which(!duplicated(format(dates, "%Y-%m")))
  sets <- data.frame(effective_from = pulses[month_starts], knowledge_time = pulses[month_starts] - 3600,
                     source = "scale_fixture", stringsAsFactors = FALSE)
  sets$members <- I(lapply(seq_along(month_starts), function(k) {
    off <- (k - 1L) * max(1L, (n_inst - n_mem) %/% length(month_starts))
    members <- ids[((off + seq_len(n_mem) - 1L) %% n_inst) + 1L]
    gone <- delisted[delist_day <= month_starts[[k]]]
    setdiff(members, gone)
  }))
  membership <- ledgr::ledgr_facts_membership_snapshots(sets, universe_id = "U", complete = TRUE)
  lifetime <- ledgr::ledgr_facts_lifetime(data.frame(
    instrument_id = delisted, effective_from = pulses[delist_day], knowledge_time = pulses[delist_day] - 1,
    assertion = "known_inactive", terminal_event = "bankruptcy", stringsAsFactors = FALSE
  ))
  # Cash dividends on the first members of the opening set, at pulse clocks.
  payers <- sets$members[[1L]][1:5]
  div_day <- as.integer(round(seq(0.05, 0.8, length.out = 5L) * n_days))
  dividends <- ledgr::ledgr_facts_equity_corporate_actions(data.frame(
    fact_id = sprintf("div-%d", seq_along(payers)), subtype = "ordinary_cash_dividend",
    parent_instrument_id = payers, entitlement_time = pulses[div_day - 1L],
    effective_time = pulses[div_day], knowledge_time = pulses[[1L]] - 3600,
    payment_time = pulses[div_day + 5L], complete = TRUE, provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = 0.5, gross_cash_validated = TRUE,
    recipient_identity_validated = FALSE, recipient_quantity_validated = FALSE,
    source = "scale_fixture", stringsAsFactors = FALSE
  ))
  ledgr::ledgr_snapshot_from_df(
    bars, data.frame(instrument_id = ids), db_path = db_path, snapshot_id = "scale-fixture",
    facts = ledgr::ledgr_facts(sessions, membership, lifetime, dividends), price_basis = "split_adjusted"
  )
}

scale_fixture_dense_snapshot <- function(db_path, n_inst = 40L, n_days = 250L, seed = 2L) {
  set.seed(seed)
  dates <- scale_fixture_dates(n_days)
  pulses <- as.POSIXct(paste(dates, "21:00:00"), tz = "UTC")
  ids <- sprintf("D%03d", seq_len(n_inst))
  px <- 50 * exp(t(apply(matrix(stats::rnorm(n_inst * n_days, 0.0003, 0.02), n_inst, n_days), 1L, cumsum)))
  ledgr::ledgr_snapshot_from_df(
    data.frame(instrument_id = rep(ids, each = n_days), ts_utc = rep(pulses, times = n_inst),
               open = as.vector(t(px)), high = as.vector(t(px)) * 1.01, low = as.vector(t(px)) * 0.99,
               close = as.vector(t(px)), volume = 1000, stringsAsFactors = FALSE),
    db_path = db_path, snapshot_id = "scale-dense"
  )
}

# Strategies shared by every lane (the LDG-2976 strategies).
scale_momentum <- function(ctx, params) {
  month <- substr(ctx$ts_utc, 1L, 7L)
  if (identical(ctx$state_prev$month, month)) return(ctx$hold())
  target <- ctx |> ledgr_signal_return(params$lookback) |>
    ledgr_select_top_n(params$n, partial = "allow") |> ledgr_weight_equal() |>
    ledgr_target_rebalance(ctx, equity_fraction = 0.95)
  list(targets = target, state_update = list(month = month))
}
scale_equal_weight <- function(ctx, params) {
  month <- substr(ctx$ts_utc, 1L, 7L)
  if (identical(ctx$state_prev$month, month)) return(ctx$hold())
  target <- ctx |> ledgr_selection() |> ledgr_weight_equal() |>
    ledgr_target_rebalance(ctx, equity_fraction = params$f)
  list(targets = target, state_update = list(month = month))
}
