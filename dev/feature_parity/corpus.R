# The feature-path oracle's case corpus (Cut 22 decision 2, LDG-3249).
#
# Substrates and definition sets start from the measuring step's fixtures
# (dev/spikes/feature_stage1_probe/fixtures.R: six substrates, fifteen sets)
# and add the RFC's case list: every catalogue row (every supported warmup
# rule and documented or derived output, MACD histogram included),
# stable_after greater than requires_bars, an unregistered ohlc form, an
# empty history, and the public entry points (runs, implicit sweeps,
# explicit precompute with reuse, pulse inspection) on both clocks with a
# scoring start after the data start. Substrates are built with
# ledgr:::ledgr_history_substrate(), as the registered tests do. Every
# function here reads only the loaded ledgr namespace `ns`.

fx_sessions <- function(axis) {
  data.frame(venue_id = "V", session_date = as.Date(axis), status = "open",
             session_open = axis - 6 * 3600, session_close = axis,
             knowledge_time = axis - 6 * 3600, stringsAsFactors = FALSE)
}

# Late-known inactive sessions, a delisting, a relisting, missing bars and an
# NA volume (a copy of test-history-frame.R's ws42_hostile_substrate()).
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
  ns$ledgr_history_substrate(bars = bars, instrument_ids = c("AAA", "BBB", "CCC"), axis = axis,
    availability_data = data, availability_config = config, snapshot_hash = "fx-hostile")
}

# Six instruments x 120 sessions: P1 scattered close holes, P2 high-only
# holes, P3 volume holes, P4 a 20-session gap, P5 only its last 4 bars
# (never calculated for wide definitions), P6 dense.
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
  sim <- sim[Reduce(`|`, lapply(sim[c("open", "high", "low", "close")], is.finite)), ]
  fx_plain_substrate(sim, ids, axis, "fx-panel", policy)
}

fx_plain_substrate <- function(bars, ids, axis, hash, policy) {
  data <- list(families = data.frame(family = "sessions", stringsAsFactors = FALSE),
               lifetime = NULL, sessions = fx_sessions(axis))
  config <- list(universe = list(instrument_ids = ids),
                 availability = list(universe_rule = NULL, valuation_policy = unclass(ledgr::ledgr_valuation_stale())),
                 history_policy = policy)
  ns$ledgr_history_substrate(bars = bars[c("instrument_id", "ts_utc", "open", "high", "low", "close", "volume")],
    instrument_ids = ids, axis = axis, availability_data = data, availability_config = config,
    snapshot_hash = hash)
}

# Two bars only: every definition here is short.
fx_short <- function(policy) {
  axis <- as.POSIXct("2020-01-01 21:00:00", tz = "UTC") + 0:1 * 86400
  bars <- data.frame(instrument_id = "S", ts_utc = axis, open = c(10, 11), high = c(11, 12),
                     low = c(9, 10), close = c(10.5, 11.5), volume = c(100, 110), stringsAsFactors = FALSE)
  fx_plain_substrate(bars, "S", axis, "fx-short", policy)
}

# An instrument with no bar at all beside one with twelve.
fx_empty <- function(policy) {
  axis <- as.POSIXct("2020-01-01 21:00:00", tz = "UTC") + 0:11 * 86400
  k <- seq_along(axis)
  bars <- data.frame(instrument_id = "F", ts_utc = axis, open = 50 + k, high = 51 + k + k %% 3,
                     low = 49 + k, close = 50.5 + k + sin(k), volume = 500 + k, stringsAsFactors = FALSE)
  fx_plain_substrate(bars, c("E", "F"), axis, "fx-empty", policy)
}

fx_substrates <- function() {
  pol <- ledgr::ledgr_history_policy
  list(
    hostile_carry2 = fx_hostile(pol(price_carry = 2L)),
    hostile_strict = fx_hostile(pol(price_carry = NULL)),
    hostile_outcarry = fx_hostile(pol(price_carry = 2L, output_carry = 2L)),
    panel_carry5 = fx_panel(pol()),
    panel_strict_outcarry = fx_panel(pol(price_carry = NULL, output_carry = 3L)),
    short = fx_short(pol()),
    empty = fx_empty(pol(output_carry = 2L)))
}

fx_def <- function(x) ns$ledgr_precompute_feature_def_from_indicator(x)
fx_bundle <- function(b) lapply(ns$ledgr_indicator_bundle_indicators(b), fx_def)
fx_ttr <- function(...) fx_def(ledgr::ledgr_ind_ttr(...))

# One definition per package catalogue row: the four built-ins and every TTR
# family, output and algorithm variant (ledgr_indicator_history_catalogue()).
fx_catalogue_rows <- function() {
  rows <- ns$ledgr_indicator_history_catalogue()
  rules <- ledgr::ledgr_ind_ttr_warmup_rules()
  builtin <- list(sma = ledgr::ledgr_ind_sma, ema = ledgr::ledgr_ind_ema,
                  rsi = ledgr::ledgr_ind_rsi, returns = ledgr::ledgr_ind_returns)
  lapply(seq_len(nrow(rows)), function(r) {
    row <- rows[r, ]
    if (row$source == "ledgr") return(fx_def(builtin[[row$family]](3L)))
    args <- if (row$family == "MACD") list(nFast = 2L, nSlow = 3L, nSig = 2L) else list(n = 3L)
    if (row$variant != "default") {
      kv <- strsplit(row$variant, "=", fixed = TRUE)[[1L]]
      args[[kv[[1L]]]] <- if (kv[[2L]] %in% c("TRUE", "FALSE")) as.logical(kv[[2L]]) else kv[[2L]]
    }
    output <- if (row$output == "value") NULL else row$output
    do.call(fx_ttr, c(list(row$family, input = rules$input[match(row$family, rules$ttr_fn)],
                           output = output), args))
  })
}

fx_defs <- function() {
  close <- c(
    list(fx_def(ledgr::ledgr_ind_sma(3)), fx_def(ledgr::ledgr_ind_ema(3)), fx_def(ledgr::ledgr_ind_rsi(3)),
         fx_def(ledgr::ledgr_ind_returns(2)),
         fx_ttr("SMA", input = "close", n = 3L), fx_ttr("SMA", input = "close", n = 8L),
         fx_ttr("EMA", input = "close", n = 3L), fx_ttr("RSI", input = "close", n = 3L),
         fx_ttr("RSI", input = "close", n = 3L, maType = "SMA"), fx_ttr("runSD", input = "close", n = 3L)),
    fx_bundle(ledgr::ledgr_ind_ttr_outputs("MACD", input = "close", nFast = 2L, nSlow = 3L, nSig = 2L)),
    fx_bundle(ledgr::ledgr_ind_ttr_outputs("BBands", input = "close", n = 3L)))
  hl <- c(fx_bundle(ledgr::ledgr_ind_ttr_outputs("aroon", input = "hl", n = 3L)),
          fx_bundle(ledgr::ledgr_ind_ttr_outputs("DonchianChannel", input = "hl", n = 3L)))
  hlc <- c(fx_bundle(ledgr::ledgr_ind_ttr_outputs("ATR", input = "hlc", n = 3L)),
           list(fx_ttr("CCI", input = "hlc", n = 3L)))
  hlcv <- list(fx_ttr("MFI", input = "hlcv", n = 3L), fx_ttr("CMF", input = "hlcv", n = 3L))
  # Claims the TTR SMA identity with replaced functions: certified as the
  # catalogue row, so its own code must never run.
  forged <- fx_ttr("SMA", input = "close", n = 3L, id = "forged_sma")
  forged$series_fn <- function(bars, params) stop("forged series_fn ran")
  forged$fn <- function(window, params) stop("forged fn ran")
  ind <- ledgr::ledgr_indicator
  # Custom callbacks that read a non-required field (required_fields close).
  custom_volume <- fx_def(ind("custom_volume",
    fn = function(bars) as.numeric(utils::tail(bars$close, 1L)), requires_bars = 1L,
    series_fn = function(bars) as.numeric(bars$close) + ifelse(is.finite(bars$volume), bars$volume * 1e-6, 0),
    required_fields = "close"))
  custom_open_fn <- fx_def(ind("custom_open_fn",
    fn = function(window) sum(window$open, na.rm = TRUE) + mean(window$close), requires_bars = 3L,
    gap_contract = "strict_window", required_fields = "close"))
  custom_high_excluded <- fx_def(ind("custom_high_excluded",
    fn = function(bars) 0, requires_bars = 2L,
    series_fn = function(bars) as.numeric(bars$close) - ifelse(is.finite(bars$high), bars$high, 0),
    required_fields = "close", input_carry = "excluded"))
  # Fails on any NA volume after warmup: a refusal that depends on the frame.
  custom_volume_strict <- fx_def(ind("custom_volume_strict",
    fn = function(bars) 0, requires_bars = 1L,
    series_fn = function(bars) as.numeric(bars$volume), required_fields = "close"))
  custom_lookahead <- fx_def(ind("custom_lookahead",
    fn = function(bars) 0, requires_bars = 1L,
    series_fn = function(bars) rev(cummax(rev(as.numeric(bars$close)))), required_fields = "close"))
  custom_parity <- fx_def(ind("custom_parity",
    fn = function(window) mean(window$close) + 1, requires_bars = 3L, gap_contract = "strict_window",
    series_fn = function(bars) as.numeric(stats::filter(bars$close, rep(1 / 3, 3), sides = 1)),
    required_fields = "close"))
  unregistered <- list(fx_ttr("SMA", input = "close", n = 3L, requires_bars = 5L, id = "ttr_sma_unreg"),
                       fx_ttr("ATR", input = "hlc", output = "atr", n = 3L, maType = "WMA", id = "ttr_atr_wma"))
  custom <- list(custom_volume, custom_open_fn, custom_high_excluded)
  all_cert <- c(close, hl, hlc, hlcv)
  # Added for the permanent oracle (the RFC's case list).
  stable_late <- list(fx_ttr("SMA", input = "close", n = 3L, stable_after = 6L, id = "ttr_sma_late"),
                      fx_def(ind("custom_late", fn = function(window) mean(window$close), requires_bars = 2L,
                                 stable_after = 5L, gap_contract = "strict_window",
                                 series_fn = function(bars) as.numeric(stats::filter(bars$close, c(0.5, 0.5), sides = 1)))))
  custom_ohlc <- list(fx_ttr("volatility", input = "ohlc", n = 3L, calc = "garman.klass",
                             requires_bars = 3L, id = "ttr_vol_gk"),
                      fx_def(ind("custom_range_ohlc", fn = function(bars) 0, requires_bars = 2L,
                                 series_fn = function(bars) as.numeric(bars$high - bars$low + bars$open * 0),
                                 required_fields = c("open", "high", "low", "close"))))
  name <- function(x) stats::setNames(x, vapply(x, function(d) d$id, ""))
  # Resolved parameterised forms (close review round 1, F4): ledgr_param()
  # arguments resolved through a feature map, single-output and bundled.
  param_map <- ledgr::ledgr_feature_map(
    signal = ledgr::ledgr_ind_ttr("RSI", input = "close", n = ledgr::ledgr_param("rsi_n")),
    range = ledgr::ledgr_ind_ttr("ATR", input = "hlc", output = "atr", n = ledgr::ledgr_param("atr_n")),
    ledgr::ledgr_ind_ttr_outputs("BBands", input = "close", outputs = c("dn", "up"), n = ledgr::ledgr_param("bb_n")))
  resolved <- lapply(ns$ledgr_feature_map_indicators(
    ns$ledgr_resolve_feature_map(param_map, feature_params = list(rsi_n = 3L, atr_n = 3L, bb_n = 4L))), fx_def)
  is_bundle <- vapply(resolved, function(d) identical(d$params$ttr_fn, "BBands"), logical(1))
  lapply(list(
    close = close, hl = hl, hlc = hlc, hlcv = hlcv, all_cert = all_cert,
    forged = list(forged),
    custom_volume = list(custom_volume), custom_open_fn = list(custom_open_fn),
    custom_high_excluded = list(custom_high_excluded), custom_volume_strict = list(custom_volume_strict),
    custom_lookahead = list(custom_lookahead), custom_parity = list(custom_parity),
    close_with_lookahead = c(close, list(custom_lookahead)),
    unregistered = unregistered,
    mixed = c(close, hl, custom, unregistered),
    catalogue_rows = fx_catalogue_rows(),
    stable_late = stable_late,
    custom_ohlc = custom_ohlc,
    parameterized_single = resolved[!is_bundle],
    parameterized_bundle = resolved[is_bundle],
    parameterized_mixed = c(resolved, list(custom_volume))), name)
}

# The single-definition read entry (ledgr_history_feature_planes): the
# measuring step's 14 cases.
fx_read_entry_cases <- function(sets) {
  out <- list()
  for (s in c("hostile_carry2", "panel_carry5")) {
    for (set in c("close", "hlc", "custom_volume")) {
      for (d in sets[[set]][seq_len(min(3L, length(sets[[set]])))]) {
        out[[length(out) + 1L]] <- list(substrate = s, name = paste0(set, ":", d$id), def = d)
      }
    }
    # Close review round 1, F4: every resolved parameterised definition.
    for (set in c("parameterized_single", "parameterized_bundle")) {
      for (d in sets[[set]]) {
        out[[length(out) + 1L]] <- list(substrate = s, name = paste0(set, ":", d$id), def = d)
      }
    }
  }
  out
}

# Pulse axes for the formatted-axis consumers (cut review 22, R6).
fx_axes <- function() {
  utc <- as.POSIXct("2021-01-04 21:00:00", tz = "UTC") + 0:3 * 86400
  named <- utc
  names(named) <- c("a", "b", "c", "d")
  list(
    utc = utc,
    named = named,
    empty = as.POSIXct(character(), tz = "UTC"),
    new_york = as.POSIXct("2021-01-04 16:00:00", tz = "America/New_York") + 0:3 * 86400,
    fractional = utc + c(0.25, 0.5, 0.75, 0.999),
    unset_tz = .POSIXct(as.numeric(utc)))
}

# ---- public entry points --------------------------------------------------

fx_e2e_features <- function() {
  ind <- ledgr::ledgr_indicator
  c(list(ledgr::ledgr_ind_sma(3), ledgr::ledgr_ind_ema(3), ledgr::ledgr_ind_returns(2),
         ledgr::ledgr_ind_ttr("SMA", input = "close", n = 3L),
         ledgr::ledgr_ind_ttr("ATR", input = "hlc", output = "atr", n = 3L),
         ledgr::ledgr_ind_ttr("MFI", input = "hlcv", n = 3L),
         ledgr::ledgr_ind_ttr("aroon", input = "hl", output = "oscillator", n = 3L),
         ind("custom_volume", fn = function(bars) as.numeric(utils::tail(bars$close, 1L)), requires_bars = 1L,
             series_fn = function(bars) as.numeric(bars$close) + ifelse(is.finite(bars$volume), bars$volume * 1e-6, 0),
             required_fields = "close"),
         ind("custom_open_fn", fn = function(window) sum(window$open, na.rm = TRUE) + mean(window$close),
             requires_bars = 3L, gap_contract = "strict_window", required_fields = "close")),
    ns$ledgr_indicator_bundle_indicators(
      ledgr::ledgr_ind_ttr_outputs("MACD", input = "close", nFast = 2L, nSlow = 3L, nSig = 2L)))
}

fx_lookahead_feature <- function() {
  ledgr::ledgr_indicator("custom_lookahead", fn = function(bars) 0, requires_bars = 1L,
    series_fn = function(bars) rev(cummax(rev(as.numeric(bars$close)))), required_fields = "close")
}

# A strategy that records the long history of every feature at each pulse
# under "<tag> <ts_utc> <feature>" and holds. The strategy preflight refuses
# free function symbols, so `seen` is captured, not looked up.
fx_spy <- function(seen) {
  function(ctx, params) {
    for (f in params$features) {
      seen[[paste(params$tag, ctx$ts_utc, f)]] <- ledgr::ledgr_history_frame(
        ctx, feature = f, lookback = Inf, instruments = "decision_axis",
        min_observations = 0L, layout = "long")
    }
    ctx$hold()
  }
}

# Bar-native clock: a fixed basket of three dense instruments.
fx_bar_native <- function(db_path, strategy, features, opening_date = NULL) {
  days <- as.Date("2021-02-01") + 0:29
  k <- seq_along(days)
  bars <- do.call(rbind, lapply(1:3, function(j) {
    close <- 20 * j + k + 2 * sin(k * j)
    data.frame(instrument_id = c("AAA", "BBB", "CCC")[[j]],
               ts_utc = as.POSIXct(paste(days, "21:00:00"), tz = "UTC"),
               open = close - 0.3, high = close + 1 + cos(k)^2, low = close - 1 - sin(k)^2,
               close = close, volume = 1000 * j + 10 * k, stringsAsFactors = FALSE)
  }))
  snapshot <- ledgr::ledgr_snapshot_from_df(bars, db_path = db_path)
  exp <- ledgr::ledgr_experiment(
    snapshot = snapshot, strategy = strategy, universe = c("AAA", "BBB", "CCC"),
    features = features, cost_model = ledgr::ledgr_cost_zero(),
    opening = ledgr::ledgr_opening(cash = 1000, date = opening_date))
  list(snapshot = snapshot, exp = exp, axis = as.POSIXct(paste(days, "21:00:00"), tz = "UTC"))
}

# Declared-session clock: 24 venue sessions; BBB has no print on three of
# them; CCC's known_inactive fact is effective at session 14 and becomes
# known at session 16; a membership universe of all three.
fx_declared <- function(db_path, strategy, features, opening_date = NULL) {
  calendar <- seq(as.Date("2021-01-04"), by = "day", length.out = 34)
  days <- calendar[!weekdays(calendar) %in% c("Saturday", "Sunday")][1:24]
  utc <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  k <- seq_along(days)
  gaps <- c(5L, 6L, 11L)
  bars <- rbind(
    data.frame(instrument_id = "AAA", ts_utc = utc(days), close = 10 + k + sin(k)),
    data.frame(instrument_id = "BBB", ts_utc = utc(days[-gaps]), close = 20 + k[-gaps] + cos(k[-gaps])),
    data.frame(instrument_id = "CCC", ts_utc = utc(days[1:13]), close = 30 + k[1:13]))
  bars$open <- bars$close - 0.25
  bars$high <- bars$close + 0.75
  bars$low <- bars$close - 0.5
  bars$volume <- 100 + seq_len(nrow(bars))
  span <- seq(min(days), max(days), by = "day")
  open <- span %in% days
  sessions <- data.frame(session_date = span, status = ifelse(open, "open", "closed"),
                         session_open = ifelse(open, "14:30:00", NA), session_close = ifelse(open, "21:00:00", NA))
  membership <- data.frame(effective_from = utc(days[[1]] - 1), knowledge_time = utc(days[[1]] - 1), source = "t")
  membership$members <- I(list(c("AAA", "BBB", "CCC")))
  facts <- ledgr::ledgr_facts(
    ledgr::ledgr_facts_sessions(sessions, venue_id = "V", knowledge = "assume_effective"),
    ledgr::ledgr_facts_membership_snapshots(membership, universe_id = "u", complete = TRUE,
                                             knowledge = "assume_effective"),
    ledgr::ledgr_facts_lifetime(data.frame(
      instrument_id = "CCC", effective_from = utc(days[[14]]) - 6.5 * 3600,
      knowledge_time = utc(days[[16]]) - 6.5 * 3600, assertion = "known_inactive",
      terminal_event = NA_character_)))
  snapshot <- ledgr::ledgr_snapshot_from_df(
    bars, data.frame(instrument_id = c("AAA", "BBB", "CCC")),
    db_path = db_path, facts = facts, price_basis = "split_adjusted")
  exp <- ledgr::ledgr_experiment(
    snapshot, strategy, universe = ledgr::ledgr_universe_members("u"), features = features,
    valuation_policy = ledgr::ledgr_valuation_stale(3), cost_model = ledgr::ledgr_cost_zero(),
    opening = ledgr::ledgr_opening(cash = 1000, date = opening_date),
    history_policy = ledgr::ledgr_history_policy(price_carry = 2L, output_carry = 2L))
  list(snapshot = snapshot, exp = exp, axis = utc(days))
}
