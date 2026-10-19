# Usage: Rscript checker_scale.R <tree> <label> <config> <n_inst> <n_sess> <out.csv>
# Times the LDG-3067 sampled causality check inside one feature preparation
# (same synthetic panel and definitions as scale.R) and counts its prefix
# recomputations. check_seconds is the time spent in
# ledgr_history_feature_causality(); feature_seconds includes it.
# config: "parity"    - gaps, no lifetime facts, price_carry = NULL, common defs
#         "realistic" - gaps, lifetime facts, default policy, full definition set
args <- commandArgs(TRUE)
tree <- args[[1]]; label <- args[[2]]; config <- args[[3]]
n_inst <- as.integer(args[[4]]); n_sess <- as.integer(args[[5]])
out_csv <- args[[6]]
suppressMessages(pkgload::load_all(tree, quiet = TRUE))

set.seed(20261017)
axis <- as.POSIXct("1998-01-02 21:00:00", tz = "UTC") + (seq_len(n_sess) - 1L) * 86400
ids <- sprintf("I%04d", seq_len(n_inst))
# Gappy panel: about 30 percent of instruments list late; about 0.5 percent of
# sessions start a missing run of 1 to 8 sessions (some beyond carry).
start <- ifelse(stats::runif(n_inst) < 0.3, sample.int(n_sess %/% 2, n_inst, replace = TRUE), 1L)
present <- matrix(TRUE, n_inst, n_sess)
for (i in seq_len(n_inst)) {
  if (start[[i]] > 1L) present[i, seq_len(start[[i]] - 1L)] <- FALSE
  gap_starts <- which(stats::runif(n_sess) < 0.005)
  for (g in gap_starts) present[i, g:min(n_sess, g + sample.int(8L, 1L) - 1L)] <- FALSE
}
price <- 100 * exp(t(apply(matrix(stats::rnorm(n_inst * n_sess, 0, 0.01), n_inst), 1, cumsum)))
cell <- which(present, arr.ind = TRUE)
close <- price[present]
bars <- data.frame(
  instrument_id = ids[cell[, 1L]],
  ts_utc = axis[cell[, 2L]],
  open = close * (1 + stats::rnorm(length(close), 0, 0.002)),
  high = close * 1.01,
  low = close * 0.99,
  close = close,
  volume = round(1e5 * stats::runif(length(close), 0.5, 1.5)),
  stringsAsFactors = FALSE
)
families <- "sessions"
lifetime <- NULL
if (identical(config, "realistic")) {
  # About 5 percent of instruments have a known-when-effective inactive
  # interval, and 1 percent learn it 10 sessions late.
  chosen <- which(stats::runif(n_inst) < 0.06)
  if (length(chosen) > 0L) {
    from <- sample.int(n_sess - 40L, length(chosen), replace = TRUE) + 20L
    lagged <- stats::runif(length(chosen)) < 1 / 6
    lifetime <- ledgr_facts_lifetime(data.frame(
      instrument_id = ids[chosen],
      effective_from = axis[from] - 3600,
      effective_to = axis[from + 10L] - 3600,
      knowledge_time = axis[from + ifelse(lagged, 10L, 0L)] - 3600,
      assertion = "known_inactive",
      source = "scale",
      stringsAsFactors = FALSE
    ))
    families <- c(families, "lifetime")
  }
}
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
policy <- if (identical(config, "parity")) ledgr_history_policy(price_carry = NULL) else ledgr_history_policy()
cfg <- list(
  universe = list(instrument_ids = ids),
  availability = list(universe_rule = NULL, valuation_policy = unclass(ledgr_valuation_stale())),
  history_policy = policy
)
t_sub <- system.time(substrate <- ledgr:::ledgr_history_substrate(
  bars = bars, instrument_ids = ids, axis = axis,
  availability_data = data, availability_config = cfg, snapshot_hash = "scale"
))[["elapsed"]]
rm(bars, price, present, cell, close)
invisible(gc())

indicators <- list(ledgr_ind_sma(20L), ledgr_ind_sma(50L), ledgr_ind_returns(1L), ledgr_ind_returns(20L))
if (identical(config, "realistic")) {
  indicators <- c(indicators, list(
    ledgr_ind_ema(10L), ledgr_ind_rsi(14L),
    ledgr_ind_ttr("EMA", input = "close", n = 20L),
    ledgr_ind_ttr("RSI", input = "close", n = 14L)
  ),
  ledgr:::ledgr_indicator_bundle_indicators(ledgr_ind_ttr_outputs(
    "MACD", input = "close", nFast = 12L, nSlow = 26L, nSig = 9L)),
  ledgr:::ledgr_indicator_bundle_indicators(ledgr_ind_ttr_outputs(
    "BBands", input = "close", outputs = c("dn", "up"), n = 20L)),
  list(ledgr_ind_ttr("ATR", input = "hlc", output = "atr", n = 14L)))
}
if (identical(config, "ttr_sma")) {
  indicators <- list(ledgr_ind_ttr("SMA", input = "close", n = 20L))
}
defs <- lapply(indicators, function(ind) {
  def <- ledgr:::ledgr_precompute_feature_def_from_indicator(ind)
  def$fingerprint <- ledgr:::ledgr_active_feature_fingerprint(def)
  def
})
names(defs) <- vapply(defs, `[[`, character(1), "fingerprint")
ns <- asNamespace("ledgr")
check_seconds <- 0
prefix_calls <- 0L
original_check <- ns$ledgr_history_feature_causality
original_prefix <- ns$ledgr_history_feature_inputs_prefix
timed_check <- function(...) {
  t0 <- proc.time()[["elapsed"]]
  on.exit(check_seconds <<- check_seconds + proc.time()[["elapsed"]] - t0)
  original_check(...)
}
counted_prefix <- function(...) {
  prefix_calls <<- prefix_calls + 1L
  original_prefix(...)
}
environment(timed_check) <- environment()
unlockBinding("ledgr_history_feature_causality", ns)
assign("ledgr_history_feature_causality", timed_check, envir = ns)
unlockBinding("ledgr_history_feature_inputs_prefix", ns)
assign("ledgr_history_feature_inputs_prefix", counted_prefix, envir = ns)
invisible(gc(reset = TRUE))
t_feat <- system.time(payload <- ledgr:::ledgr_history_precompute_payload(
  defs, substrate,
  calculation_start = axis[[1L]],
  calculation_end = axis[[n_sess]]
))[["elapsed"]]
row <- data.frame(
  tree = label, config = config, instruments = n_inst, sessions = n_sess,
  definitions = length(defs), bars = sum(substrate$bars$observed),
  feature_seconds = t_feat, check_seconds = check_seconds,
  check_share = round(check_seconds / t_feat, 4),
  prefix_recomputations = prefix_calls,
  stringsAsFactors = FALSE
)
print(row)
utils::write.table(row, out_csv, sep = ",", row.names = FALSE,
  col.names = !file.exists(out_csv), append = file.exists(out_csv))
