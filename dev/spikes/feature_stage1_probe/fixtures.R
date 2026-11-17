# Fixtures for the candidate 2 and 3 probe. Substrates are built directly
# with ledgr:::ledgr_history_substrate(), as the registered tests do
# (tests/testthat/helper-indicator-history.R, test-history-frame.R).

fx_sessions <- function(axis) {
  data.frame(venue_id = "V", session_date = as.Date(axis), status = "open",
             session_open = axis - 6 * 3600, session_close = axis,
             knowledge_time = axis - 6 * 3600, stringsAsFactors = FALSE)
}

# Copy of ws42_hostile_substrate() (test-history-frame.R:211): late-known
# inactive sessions, a delisting, a relisting, missing bars and an NA volume.
fx_hostile <- function(policy) {
  axis <- as.POSIXct("2021-03-01 21:00:00", tz = "UTC") + 0:9 * 86400
  lifetime <- ledgr::ledgr_facts_lifetime(data.frame(
    instrument_id = c("AAA", "AAA", "AAA", "BBB", "BBB", "CCC", "CCC", "CCC", "CCC", "CCC"),
    effective_from = axis[c(1L, 4L, 8L, 1L, 6L, 1L, 3L, 5L, 6L, 8L)] - 3600,
    effective_to = as.POSIXct(
      c(axis[[4L]], axis[[8L]], NA, axis[[6L]], NA, axis[[3L]], axis[[5L]], axis[[6L]], axis[[8L]], NA) - 3600,
      origin = "1970-01-01", tz = "UTC"),
    knowledge_time = axis[c(1L, 6L, 9L, 1L, 6L, 1L, 4L, 5L, 6L, 9L)] - 3600,
    assertion = c("known_active", "known_inactive", "known_active", "known_active", "known_inactive",
                  "known_active", "known_inactive", "known_active", "known_inactive", "known_active"),
    terminal_event = c(NA, NA, NA, NA, "delisting", NA, NA, NA, "delisting", NA),
    source = "test", stringsAsFactors = FALSE))
  bars <- expand.grid(instrument_id = c("AAA", "BBB", "CCC"), ts_utc = axis,
                      KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  bars$close <- 100 + seq_len(nrow(bars)) + sin(seq_len(nrow(bars)))
  bars$open <- bars$close - 0.5
  bars$high <- bars$close + 1 + cos(seq_len(nrow(bars)))^2
  bars$low <- bars$close - 1
  bars$volume <- 1000 + seq_len(nrow(bars))
  drop <- (bars$instrument_id == "AAA" & bars$ts_utc %in% axis[c(2L, 3L, 6L, 9L)]) |
    (bars$instrument_id == "BBB" & bars$ts_utc %in% axis[c(4L, 5L)]) |
    (bars$instrument_id == "CCC" & bars$ts_utc %in% axis[c(2L, 7L)])
  bars <- bars[!drop, , drop = FALSE]
  bars$volume[bars$instrument_id == "AAA" & bars$ts_utc == axis[[5L]]] <- NA_real_
  data <- list(families = data.frame(family = c("lifetime", "sessions"), stringsAsFactors = FALSE),
               lifetime = lifetime$rows, sessions = fx_sessions(axis))
  config <- list(universe = list(instrument_ids = c("AAA", "BBB", "CCC")),
                 availability = list(valuation_policy = unclass(ledgr::ledgr_valuation_stale())),
                 history_policy = policy)
  ledgr:::ledgr_history_substrate(bars = bars, instrument_ids = c("AAA", "BBB", "CCC"), axis = axis,
    availability_data = data, availability_config = config, snapshot_hash = "fx-hostile")
}

# Six instruments x 120 sessions with field-level holes:
#   P1 scattered close holes (carry admits short ones), P2 high-only holes
#   (hl/hlc admission differs from close), P3 volume holes, P4 a 20-session
#   gap longer than any carry, P5 only its last 4 bars (never calculated for
#   wide definitions), P6 dense.
fx_panel <- function(policy, n = 120L) {
  ids <- sprintf("P%d", 1:6)
  axis <- as.POSIXct("2020-01-01 21:00:00", tz = "UTC") + (seq_len(n) - 1L) * 86400
  sim <- ledgr::ledgr_sim_bars(6L, n, seed = 20261117L, start = "2020-01-01", instrument_prefix = "P")
  sim <- sim[order(sim$instrument_id, sim$ts_utc, method = "radix"), ]
  sim$instrument_id <- ids[match(sim$instrument_id, sort(unique(sim$instrument_id)))]
  position <- stats::ave(seq_len(nrow(sim)), sim$instrument_id, FUN = seq_along)
  sim <- sim[position <= n, ]
  sim$ts_utc <- axis[position[position <= n]]
  set.seed(7L)
  pick <- function(id, k) which(sim$instrument_id == id)[k]
  sim$close[pick("P1", sort(sample(10:110, 12)))] <- NA_real_
  sim$high[pick("P2", sort(sample(10:110, 12)))] <- NA_real_
  sim$volume[pick("P3", sort(sample(10:110, 12)))] <- NA_real_
  sim <- sim[!(sim$instrument_id == "P4" & as.integer(sim$ts_utc - axis[[1L]], units = "days") %in% 50:69), ]
  sim <- sim[!(sim$instrument_id == "P5" & sim$ts_utc < axis[[n - 3L]]), ]
  # A row with every price missing is no bar at all.
  sim <- sim[Reduce(`|`, lapply(sim[c("open", "high", "low", "close")], is.finite)), ]
  data <- list(families = data.frame(family = "sessions", stringsAsFactors = FALSE),
               lifetime = NULL, sessions = fx_sessions(axis))
  config <- list(universe = list(instrument_ids = ids),
                 availability = list(universe_rule = NULL, valuation_policy = unclass(ledgr::ledgr_valuation_stale())),
                 history_policy = policy)
  ledgr:::ledgr_history_substrate(bars = sim[c("instrument_id", "ts_utc", "open", "high", "low", "close", "volume")],
    instrument_ids = ids, axis = axis, availability_data = data, availability_config = config,
    snapshot_hash = "fx-panel")
}

# Two bars only: every definition here is short.
fx_short <- function(policy) {
  axis <- as.POSIXct("2020-01-01 21:00:00", tz = "UTC") + 0:1 * 86400
  bars <- data.frame(instrument_id = "S", ts_utc = axis, open = c(10, 11), high = c(11, 12),
                     low = c(9, 10), close = c(10.5, 11.5), volume = c(100, 110), stringsAsFactors = FALSE)
  data <- list(families = data.frame(family = "sessions", stringsAsFactors = FALSE),
               lifetime = NULL, sessions = fx_sessions(axis))
  config <- list(universe = list(instrument_ids = "S"),
                 availability = list(universe_rule = NULL, valuation_policy = unclass(ledgr::ledgr_valuation_stale())),
                 history_policy = policy)
  ledgr:::ledgr_history_substrate(bars = bars, instrument_ids = "S", axis = axis,
    availability_data = data, availability_config = config, snapshot_hash = "fx-short")
}

fx_defs <- function() {
  def <- function(x) ledgr:::ledgr_precompute_feature_def_from_indicator(x)
  bundle <- function(b) lapply(ledgr:::ledgr_indicator_bundle_indicators(b), def)
  ttr <- function(...) def(ledgr::ledgr_ind_ttr(...))
  close <- c(
    list(def(ledgr::ledgr_ind_sma(3)), def(ledgr::ledgr_ind_ema(3)), def(ledgr::ledgr_ind_rsi(3)),
         def(ledgr::ledgr_ind_returns(2)),
         ttr("SMA", input = "close", n = 3L), ttr("SMA", input = "close", n = 8L),
         ttr("EMA", input = "close", n = 3L), ttr("RSI", input = "close", n = 3L),
         ttr("RSI", input = "close", n = 3L, maType = "SMA"), ttr("runSD", input = "close", n = 3L)),
    bundle(ledgr::ledgr_ind_ttr_outputs("MACD", input = "close", nFast = 2L, nSlow = 3L, nSig = 2L)),
    bundle(ledgr::ledgr_ind_ttr_outputs("BBands", input = "close", n = 3L)))
  hl <- c(bundle(ledgr::ledgr_ind_ttr_outputs("aroon", input = "hl", n = 3L)),
          bundle(ledgr::ledgr_ind_ttr_outputs("DonchianChannel", input = "hl", n = 3L)))
  hlc <- c(bundle(ledgr::ledgr_ind_ttr_outputs("ATR", input = "hlc", n = 3L)),
           list(ttr("CCI", input = "hlc", n = 3L)))
  hlcv <- list(ttr("MFI", input = "hlcv", n = 3L), ttr("CMF", input = "hlcv", n = 3L))
  # A copy that claims the TTR SMA identity with replaced functions: it is
  # certified as the catalogue row and its own code must never run.
  forged <- ttr("SMA", input = "close", n = 3L, id = "forged_sma")
  forged$series_fn <- function(bars, params) stop("forged series_fn ran")
  forged$fn <- function(window, params) stop("forged fn ran")
  # Custom callbacks that read a non-required field (required_fields close).
  custom_volume <- def(ledgr::ledgr_indicator("custom_volume",
    fn = function(bars) as.numeric(utils::tail(bars$close, 1L)), requires_bars = 1L,
    series_fn = function(bars) as.numeric(bars$close) + ifelse(is.finite(bars$volume), bars$volume * 1e-6, 0),
    required_fields = "close"))
  custom_open_fn <- def(ledgr::ledgr_indicator("custom_open_fn",
    fn = function(window) sum(window$open, na.rm = TRUE) + mean(window$close), requires_bars = 3L,
    gap_contract = "strict_window", required_fields = "close"))
  custom_high_excluded <- def(ledgr::ledgr_indicator("custom_high_excluded",
    fn = function(bars) 0, requires_bars = 2L,
    series_fn = function(bars) as.numeric(bars$close) - ifelse(is.finite(bars$high), bars$high, 0),
    required_fields = "close", input_carry = "excluded"))
  # Fails on any NA volume after warmup: a refusal that depends on which
  # fields the frame carries.
  custom_volume_strict <- def(ledgr::ledgr_indicator("custom_volume_strict",
    fn = function(bars) 0, requires_bars = 1L,
    series_fn = function(bars) as.numeric(bars$volume), required_fields = "close"))
  # Refusals the causality probe must still raise: a definition that reads
  # later rows, and a bounded custom fn that disagrees with its series_fn.
  custom_lookahead <- def(ledgr::ledgr_indicator("custom_lookahead",
    fn = function(bars) 0, requires_bars = 1L,
    series_fn = function(bars) rev(cummax(rev(as.numeric(bars$close)))), required_fields = "close"))
  custom_parity <- def(ledgr::ledgr_indicator("custom_parity",
    fn = function(window) mean(window$close) + 1, requires_bars = 3L, gap_contract = "strict_window",
    series_fn = function(bars) as.numeric(stats::filter(bars$close, rep(1 / 3, 3), sides = 1)),
    required_fields = "close"))
  unregistered <- list(ttr("SMA", input = "close", n = 3L, requires_bars = 5L, id = "ttr_sma_unreg"),
                       ttr("ATR", input = "hlc", output = "atr", n = 3L, maType = "WMA", id = "ttr_atr_wma"))
  custom <- list(custom_volume, custom_open_fn, custom_high_excluded)
  all_cert <- c(close, hl, hlc, hlcv)
  name <- function(x) stats::setNames(x, vapply(x, function(d) d$id, ""))
  lapply(list(
    close = close, hl = hl, hlc = hlc, hlcv = hlcv, all_cert = all_cert,
    forged = list(forged),
    custom_volume = list(custom_volume), custom_open_fn = list(custom_open_fn),
    custom_high_excluded = list(custom_high_excluded), custom_volume_strict = list(custom_volume_strict),
    custom_lookahead = list(custom_lookahead), custom_parity = list(custom_parity),
    close_with_lookahead = c(close, list(custom_lookahead)),
    unregistered = unregistered,
    mixed = c(close, hl, custom, unregistered)), name)
}
