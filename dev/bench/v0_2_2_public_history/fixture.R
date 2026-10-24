# Workstream 42 public-history scale fixture (Cut 16 LDG-3062..3064).
#
# A vendor-neutral availability snapshot at the H1 shape: about 1,166
# instruments by 7,213 sessions, rotating complete membership sets (580 by
# default), labelled delistings, a share of late-known lifetime facts, about
# 0.5 percent missing member bars and cash dividends on held members. It is
# adapted from dev/bench/v0_2_2_real_data_scale/fixture.R; only the set
# cadence and the late-known lifetime share are added. No vendor row is used.

public_history_dates <- function(n_days) {
  days <- seq(as.Date("1998-01-02"), by = "day", length.out = ceiling(n_days * 7 / 5) + 14L)
  days[as.integer(format(days, "%u")) <= 5L][seq_len(n_days)]
}

public_history_snapshot <- function(db_path,
                                    n_inst = 1166L,
                                    n_days = 7213L,
                                    n_mem = 600L,
                                    n_sets = 580L,
                                    seed = 1L,
                                    snapshot_id = "public-history-scale") {
  set.seed(seed)
  dates <- public_history_dates(n_days)
  pulses <- as.POSIXct(paste(dates, "21:00:00"), tz = "UTC")
  ids <- sprintf("I%04d", seq_len(n_inst))
  ret <- matrix(stats::rnorm(n_inst * n_days, 0.0002, 0.02), n_inst, n_days)
  px <- 50 * exp(t(apply(ret, 1L, cumsum)))
  rm(ret)
  bars <- data.frame(
    instrument_id = rep(ids, each = n_days), ts_utc = rep(pulses, times = n_inst),
    open = as.vector(t(px)), high = as.vector(t(px)) * 1.01, low = as.vector(t(px)) * 0.99,
    close = as.vector(t(px)), volume = 1000, stringsAsFactors = FALSE
  )
  rm(px)
  # Twenty members delist at staggered dates with a labelled terminal.
  delisted <- ids[as.integer(round(seq(2L, n_mem - 1L, length.out = 20L)))]
  delist_day <- as.integer(round(seq(0.08, 0.9, length.out = 20L) * n_days))
  drop <- rep(FALSE, nrow(bars))
  inst_of <- match(bars$instrument_id, ids)
  day_of <- rep(seq_len(n_days), times = n_inst)
  for (k in seq_along(delisted)) {
    drop <- drop | (inst_of == match(delisted[[k]], ids) & day_of >= delist_day[[k]])
  }
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
  set_starts <- unique(as.integer(round(seq(1L, n_days, length.out = n_sets + 1L)[seq_len(n_sets)])))
  sets <- data.frame(effective_from = pulses[set_starts], knowledge_time = pulses[set_starts] - 3600,
                     source = "public_history_scale", stringsAsFactors = FALSE)
  sets$members <- I(lapply(seq_along(set_starts), function(k) {
    off <- (k - 1L) * max(1L, (n_inst - n_mem) %/% length(set_starts))
    members <- ids[((off + seq_len(n_mem) - 1L) %% n_inst) + 1L]
    gone <- delisted[delist_day <= set_starts[[k]]]
    setdiff(members, gone)
  }))
  membership <- ledgr::ledgr_facts_membership_snapshots(sets, universe_id = "U", complete = TRUE)
  # Delistings are known one second before they take effect; a further 40
  # instruments receive a labelled ten-session inactive interval that is
  # known only five sessions after it starts (late-known lifetime facts). The
  # label lets the research policy dispose a held position instead of
  # stopping the run.
  late <- setdiff(ids[seq(5L, n_inst, by = max(1L, n_inst %/% 40L))], delisted)
  late <- late[seq_len(min(40L, length(late)))]
  late_day <- as.integer(round(seq(0.1, 0.95, length.out = length(late)) * n_days))
  lifetime <- ledgr::ledgr_facts_lifetime(data.frame(
    instrument_id = c(delisted, late),
    effective_from = c(pulses[delist_day], pulses[late_day] - 6.5 * 3600),
    effective_to = as.POSIXct(c(rep(NA_real_, length(delisted)), as.numeric(pulses[late_day + 10L]) - 6.5 * 3600),
                              origin = "1970-01-01", tz = "UTC"),
    knowledge_time = c(pulses[delist_day] - 1, pulses[late_day + 5L] - 6.5 * 3600),
    assertion = "known_inactive",
    terminal_event = c(rep("bankruptcy", length(delisted)), rep("delisting", length(late))),
    stringsAsFactors = FALSE
  ))
  payers <- sets$members[[1L]][1:5]
  div_day <- as.integer(round(seq(0.05, 0.8, length.out = 5L) * n_days))
  dividends <- ledgr::ledgr_facts_equity_corporate_actions(data.frame(
    fact_id = sprintf("div-%d", seq_along(payers)), subtype = "ordinary_cash_dividend",
    parent_instrument_id = payers, entitlement_time = pulses[div_day - 1L],
    effective_time = pulses[div_day], knowledge_time = pulses[[1L]] - 3600,
    payment_time = pulses[div_day + 5L], complete = TRUE, provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = 0.5, gross_cash_validated = TRUE,
    recipient_identity_validated = FALSE, recipient_quantity_validated = FALSE,
    source = "public_history_scale", stringsAsFactors = FALSE
  ))
  ledgr::ledgr_snapshot_from_df(
    bars, data.frame(instrument_id = ids), db_path = db_path, snapshot_id = snapshot_id,
    facts = ledgr::ledgr_facts(sessions, membership, lifetime, dividends), price_basis = "split_adjusted"
  )
}

# Monthly equal weight over admissible members (no history read).
public_history_equal_weight <- function(ctx, params) {
  month <- substr(ctx$ts_utc, 1L, 7L)
  if (identical(ctx$state_prev$month, month)) return(ctx$hold())
  target <- ctx |> ledgr_selection() |> ledgr_weight_equal() |>
    ledgr_target_rebalance(ctx, equity_fraction = params$f)
  list(targets = target, state_update = list(month = month))
}

# The same rebalance, but each pulse reads 21 sessions of close history and
# each rebalance a 252-session window with drop_instruments.
public_history_reader <- function(ctx, params) {
  short <- ledgr_history_frame(ctx, bar = "close", lookback = 21L,
                               min_observations = 0L)
  month <- substr(ctx$ts_utc, 1L, 7L)
  if (identical(ctx$state_prev$month, month)) return(ctx$hold())
  long <- ledgr_history_frame(ctx, bar = "close", lookback = 252L)
  x <- ledgr_history_matrix(long)
  target <- ctx |> ledgr_selection() |> ledgr_weight_equal() |>
    ledgr_target_rebalance(ctx, equity_fraction = params$f)
  list(targets = target, state_update = list(month = month, n = ncol(x) + nrow(short)))
}
