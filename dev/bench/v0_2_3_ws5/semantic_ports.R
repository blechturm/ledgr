# Frozen strategy-port witness for LDG-3188.
#
# The fixture and two strategy meanings come from the accepted strategy-grammar
# evidence at ee377f31 (trailing stop) and 93369b94 (Turtle). This runner keeps
# the original four-year, 30-stock/eight-ETF input shape and checks the recorded
# 58- and 741-fill outcomes through the current public strategy grammar.

if (!exists("ledgr_experiment", mode = "function")) {
  suppressMessages(pkgload::load_all(".", quiet = TRUE))
}

ws5_port_snapshot <- function(db_path = tempfile(fileext = ".duckdb"),
                              from = "2018-01-01", to = "2021-12-31") {
  stock_ids <- sprintf("STK%02d", 1:30)
  etf_ids <- c("SPY", "EFA", "AGG", "GLD", "VNQ", "DBC", "TLT", "BIL")
  pit <- ledgr_sim_pit_inputs(
    stock_ids, from = from, to = to, seed = 42L, cases = character()
  )
  open_days <- pit$sessions$session_date[pit$sessions$status == "open"]
  close_ts <- unique(pit$bars$ts_utc)
  stopifnot(length(open_days) == length(close_ts))

  etf <- ledgr_sim_bars(
    n_instruments = 7L, n_days = length(open_days), seed = 7L,
    start = from, instrument_prefix = "E"
  )
  etf$instrument_id <- etf_ids[match(etf$instrument_id, sprintf("E%02d", 1:7))]
  etf$ts_utc <- close_ts[match(as.Date(etf$ts_utc), open_days)]
  for (id in c("AGG", "TLT")) {
    take <- etf$instrument_id == id
    base <- etf$close[take][[1L]]
    for (column in c("open", "high", "low", "close")) {
      etf[[column]][take] <- base * (etf[[column]][take] / base)^0.35
    }
  }
  n <- length(close_ts)
  bil_close <- 100 * exp(cumsum(rep(0.00008, n)))
  bil_open <- c(100, bil_close[-n])
  bil <- data.frame(
    ts_utc = close_ts, instrument_id = "BIL", open = bil_open,
    high = pmax(bil_open, bil_close) + 0.001,
    low = pmin(bil_open, bil_close) - 0.001, close = bil_close,
    volume = 1e6
  )

  stocks <- as.data.frame(pit$bars)
  leave <- match(as.Date("2021-02-01"), open_days)
  k <- match(as.Date(stocks$ts_utc), open_days)
  lift <- exp(0.003 * pmin(pmax(k - (leave - 200), 0), 200))
  stock_four <- stocks$instrument_id == "STK04"
  for (column in c("open", "high", "low", "close")) {
    stocks[[column]][stock_four] <- stocks[[column]][stock_four] * lift[stock_four]
  }
  bars <- rbind(stocks[names(bil)], as.data.frame(etf)[names(bil)], bil)

  at_close <- function(x) as.POSIXct(paste(x, "16:00:00"), tz = "UTC")
  start <- close_ts[[1L]]
  membership <- data.frame(
    instrument_id = c(sprintf("STK%02d", 1:24), sprintf("STK%02d", 25:30), "STK05"),
    effective_from = c(
      rep(start, 24),
      at_close(c("2018-06-01", "2018-09-04", "2019-03-01", "2019-07-01",
                 "2020-01-02", "2020-06-01")),
      at_close("2020-03-02")
    ),
    effective_to = c(
      at_close(c("2019-04-01", "2019-10-01", "2020-04-01", "2021-02-01",
                 "2019-06-03")),
      rep(as.POSIXct(NA, tz = "UTC"), 19),
      rep(as.POSIXct(NA, tz = "UTC"), 6),
      as.POSIXct(NA, tz = "UTC")
    ),
    member = TRUE
  )
  etf_membership <- data.frame(
    instrument_id = etf_ids, effective_from = start, member = TRUE
  )
  facts <- ledgr_facts(
    ledgr_facts_sessions(
      pit$sessions, venue_id = "DEMO_VENUE", knowledge = "evidenced",
      timezone = "UTC"
    ),
    ledgr_facts_membership_intervals(
      membership, universe_id = "stocks", knowledge = "assume_effective"
    ),
    ledgr_facts_membership_intervals(
      etf_membership, universe_id = "etfs", knowledge = "assume_effective"
    )
  )
  ledgr_snapshot_from_df(
    bars, facts = facts, db_path = db_path,
    snapshot_id = "ws5_strategy_ports", price_basis = "split_adjusted"
  )
}

ws5_trailing_strategy <- function(ctx, params) {
  peak <- pmax(ctx$state$peak, ctx$close, na.rm = TRUE)
  sell <- ctx$held & ctx$close < 0.95 * peak
  buy <- !ctx$held &
    (is.na(ctx$bars_since_exit) | ctx$bars_since_exit >= params$wait)
  peak[sell | !(ctx$held | buy)] <- NA_real_
  target <- ledgr_target_adjust(
    ctx,
    weights = ledgr_weight_equal(ctx$universe[buy], each = 0.2),
    exit = sell,
    capital_base = "total_equity"
  )
  ledgr_strategy_result(target, peak = peak)
}

ws5_turtle_features <- function() {
  prior_high <- ledgr_indicator(
    id = "prior_high_20",
    fn = function(window) max(window$high[-nrow(window)]),
    requires_bars = 21L, stable_after = 21L,
    history_class = "bounded", required_fields = "high", tolerance = 0,
    input_carry = "excluded"
  )
  prior_low <- ledgr_indicator(
    id = "prior_low_10",
    fn = function(window) min(window$low[-nrow(window)]),
    requires_bars = 11L, stable_after = 11L,
    history_class = "bounded", required_fields = "low", tolerance = 0,
    input_carry = "excluded"
  )
  ledgr_feature_map(
    prior_high_20 = prior_high,
    prior_low_10 = prior_low,
    atr = ledgr_ind_ttr("ATR", input = "hlc", output = "atr", n = 20L)
  )
}

ws5_turtle_strategy <- function(ctx, params) {
  stop <- ctx$state$stop
  exits <- ctx$held &
    (ctx$close < ctx$prior_low_10 | ctx$close < stop) %in% TRUE
  entries <- !ctx$held & ctx$buyable &
    (ctx$close > ctx$prior_high_20 & ctx$atr > 0) %in% TRUE
  target <- ctx$hold()
  target[exits] <- 0
  units <- ifelse(entries, floor(params$risk * ctx$equity / ctx$atr), 0)
  budget <- ctx$cash + sum((ctx$position * ctx$close)[exits])
  cost <- sum(units * ctx$close)
  if (cost > params$invest * budget) {
    units <- floor(units * params$invest * budget / cost)
  }
  target[entries] <- units[entries]
  stop[entries] <- (ctx$close - 2 * ctx$atr)[entries]
  stop[exits] <- NA_real_
  ledgr_strategy_result(target, stop = stop)
}

ws5_fill_digest <- function(fills) {
  values <- fills[c("ts_utc", "instrument_id", "side", "qty", "price")]
  values$ts_utc <- format(
    values$ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
  )
  payload <- ledgr:::canonical_json(lapply(values, unname))
  digest::digest(as.character(payload), algo = "sha256", serialize = FALSE)
}

ws5_run_semantic_ports <- function(snapshot = ws5_port_snapshot()) {
  close_snapshot <- missing(snapshot)
  if (close_snapshot) on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  quiet <- function(expr) withCallingHandlers(expr, warning = function(w) {
    if (grepl("LEDGR_LAST_BAR_NO_FILL", conditionMessage(w), fixed = TRUE)) {
      invokeRestart("muffleWarning")
    }
  })
  trailing <- ledgr_experiment(
    snapshot, ws5_trailing_strategy,
    universe = "SPY", asset_state = list(peak = NA_real_),
    opening = ledgr_opening(
      cash = 100000, positions = c(SPY = 100), cost_basis = c(SPY = 100)
    ),
    cost_model = ledgr_cost_zero()
  )
  turtle <- ledgr_experiment(
    snapshot, ws5_turtle_strategy,
    features = ws5_turtle_features(),
    universe = ledgr_universe_members("stocks"),
    asset_state = list(stop = NA_real_),
    opening = ledgr_opening(cash = 100000),
    cost_model = ledgr_cost_zero()
  )
  trailing_run <- quiet(ledgr_run(
    trailing, params = list(wait = 5L), run_id = "ws5_trailing_port"
  ))
  on.exit(close(trailing_run), add = TRUE)
  turtle_run <- quiet(ledgr_run(
    turtle, params = list(risk = 0.01, invest = 0.98), run_id = "ws5_turtle_port"
  ))
  on.exit(close(turtle_run), add = TRUE)
  trailing_fills <- as.data.frame(ledgr_results(trailing_run, "fills"))
  turtle_fills <- as.data.frame(ledgr_results(turtle_run, "fills"))
  stopifnot(nrow(trailing_fills) == 58L, nrow(turtle_fills) == 741L)
  list(
    trailing = trailing_fills,
    turtle = turtle_fills,
    turtle_fill_digest = ws5_fill_digest(turtle_fills),
    trailing_experiment = trailing,
    turtle_experiment = turtle
  )
}

if (identical(environment(), globalenv()) && !interactive()) {
  result <- ws5_run_semantic_ports()
  cat("WS5_SEMANTIC_PORTS_OK trailing=", nrow(result$trailing),
      " turtle=", nrow(result$turtle), "\n", sep = "")
}
