# One-instrument causal-history substrate built from literal vectors. `close`
# NA marks a missing bar; `fields` overrides individual OHLCV vectors.
ws43_history_axis <- function(n) {
  as.POSIXct("2020-01-01 21:00:00", tz = "UTC") + (seq_len(n) - 1L) * 86400
}

ws43_history_substrate <- function(close,
                                   fields = list(),
                                   lifetime = NULL,
                                   policy = ledgr_history_policy(),
                                   instrument_id = "AAA") {
  n <- length(close)
  axis <- ws43_history_axis(n)
  values <- list(
    open = close,
    high = close + 1,
    low = close - 1,
    close = close,
    volume = rep(1000, n)
  )
  values[names(fields)] <- fields
  observed <- Reduce(`|`, lapply(values[c("open", "high", "low", "close")], is.finite))
  bars <- data.frame(
    instrument_id = instrument_id,
    ts_utc = axis,
    open = values$open,
    high = values$high,
    low = values$low,
    close = values$close,
    volume = values$volume,
    stringsAsFactors = FALSE
  )[observed, , drop = FALSE]
  families <- "sessions"
  if (!is.null(lifetime)) families <- c(families, "lifetime")
  data <- list(
    families = data.frame(family = families, stringsAsFactors = FALSE),
    lifetime = if (is.null(lifetime)) NULL else lifetime$rows,
    sessions = data.frame(
      venue_id = "V",
      session_date = as.Date(axis),
      status = "open",
      session_open = axis - 6 * 3600,
      session_close = axis,
      knowledge_time = axis - 6 * 3600,
      stringsAsFactors = FALSE
    )
  )
  config <- list(
    universe = list(instrument_ids = instrument_id),
    availability = list(
      universe_rule = NULL,
      valuation_policy = unclass(ledgr_valuation_stale())
    ),
    history_policy = policy
  )
  ledgr:::ledgr_history_substrate(
    bars = bars,
    instrument_ids = instrument_id,
    axis = axis,
    availability_data = data,
    availability_config = config,
    snapshot_hash = "ws43"
  )
}

ws43_feature_values <- function(substrate, definition, ...) {
  out <- ledgr:::ledgr_history_compute_feature_series(
    substrate,
    list(definition),
    ...
  )
  as.numeric(out[[1L]][1L, ])
}
