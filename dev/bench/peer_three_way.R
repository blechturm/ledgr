# Three-way peer comparison driver (R side): ledgr + quantstrat across widths.
#
# Apples-to-apples, same-host SMA-crossover throughput. Generates one seeded
# bars set per width via ledgr_sim_bars(), writes it to a shared CSV that the
# Python backtrader driver (peer_three_way_backtrader.py) reads, so all three
# engines see identical data. ledgr uses TTR-backed SMA features and the
# feature-wide strategy surface so the canonical peer row exercises the quick
# vectorized indicator path; quantstrat runs the matched SMA(fast)/SMA(slow)
# crossover.
#
# Timing boundary (execution only; data gen + engine setup excluded):
#   ledgr      -> ledgr_run() wall
#   quantstrat -> applyStrategy() + updatePortf()/updateAcct()/updateEndEq()
# Headline unit: security_bars_sec = n_inst * n_pulses / wall.
#
# Caveats: same-host orientation, not event/accounting parity. ledgr persists a
# durable ledger/equity to DuckDB; quantstrat builds an in-memory blotter. ledgr
# and quantstrat both use TTR-backed SMA calculation; Backtrader uses its native
# indicator implementation. Fill counts are close, not identical.
#
# Usage:
#   Rscript dev/bench/peer_three_way.R --widths 10,50,100,250 --days 1260
#   then:  python dev/bench/peer_three_way_backtrader.py --widths 10,50,100,250

suppressWarnings(suppressMessages({
  if (file.exists("DESCRIPTION") &&
      identical(unname(read.dcf("DESCRIPTION")[1L, "Package"]), "ledgr")) {
    pkgload::load_all(".", quiet = TRUE)
  } else library(ledgr)
  library(quantstrat)
}))

a <- commandArgs(trailingOnly = TRUE)
gi <- function(k, d) { i <- which(a == k); if (length(i)) as.integer(a[[i + 1L]]) else d }
DAYS <- gi("--days", 1260L); FAST <- gi("--fast", 20L); SLOW <- gi("--slow", 50L); SEED <- gi("--seed", 20260529L)
wi <- which(a == "--widths"); WIDTHS <- if (length(wi)) as.integer(strsplit(a[[wi + 1L]], ",")[[1L]]) else c(10L, 50L, 100L, 250L)
oi <- which(a == "--out-dir"); OUT <- if (length(oi)) a[[oi + 1L]] else "dev/bench/results"
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

run_ledgr <- function(bars, fast_n, slow_n) {
  if (!requireNamespace("TTR", quietly = TRUE)) {
    stop("The canonical ledgr peer row needs the 'TTR' package.")
  }
  mk <- function(id, w) {
    force(w)
    ledgr_indicator(
      id = id,
      fn = function(window) {
        x <- as.numeric(window$close)
        if (length(x) < w) return(NA_real_)
        as.numeric(TTR::SMA(x, n = w))[[length(x)]]
      },
      requires_bars = w,
      series_fn = function(bars, params) as.numeric(TTR::SMA(as.numeric(bars$close), n = w))
    )
  }
  db <- tempfile(fileext = ".duckdb"); on.exit(unlink(db), add = TRUE)
  snap <- ledgr_snapshot_from_df(bars, db_path = db); on.exit(ledgr_snapshot_close(snap), add = TRUE)
  features <- ledgr_feature_map(fast = mk("sma_ttr_fast", fast_n), slow = mk("sma_ttr_slow", slow_n))
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    fw <- ctx$features_wide
    fast <- fw$sma_ttr_fast
    slow <- fw$sma_ttr_slow
    long <- !is.na(fast) & !is.na(slow) & fast > slow
    if (any(long)) {
      targets[fw$instrument_id[long]] <- params$qty
    }
    targets
  }
  exp <- ledgr_experiment(snapshot = snap, strategy = strategy,
                          features = features, opening = ledgr_opening(cash = 1e7), persist_features = FALSE)
  rid <- paste0("peer3_", paste(sample(c(0:9, letters), 6L, TRUE), collapse = ""))
  el <- system.time(bt <- ledgr_run(exp, params = list(qty = 1, threshold = 0), run_id = rid))[["elapsed"]]
  fills <- tryCatch(nrow(ledgr_results(bt, "fills")), error = function(e) NA_integer_); close(bt)
  list(wall = el, fills = fills)
}

# Unique portfolio/account/strategy names per width: blotter's rm.strat() does
# not remove the account, so reusing names across widths errors out.
run_quantstrat <- function(bars, fast_n, slow_n, tag) {
  Sys.setenv(TZ = "UTC"); symbols <- unique(bars$instrument_id)
  for (sym in symbols) {
    d <- bars[bars$instrument_id == sym, , drop = FALSE]
    x <- xts::xts(as.matrix(d[, c("open", "high", "low", "close", "volume")]), order.by = as.POSIXct(d$ts_utc, tz = "UTC"))
    colnames(x) <- c("Open", "High", "Low", "Close", "Volume"); assign(sym, x, envir = globalenv())
  }
  on.exit(suppressWarnings(rm(list = symbols, envir = globalenv())), add = TRUE)
  init_date <- as.character(min(as.Date(bars$ts_utc)) - 1L)
  portf <- paste0("peer_p_", tag); acct <- paste0("peer_a_", tag); st <- paste0("peer_s_", tag)
  suppressWarnings(try(FinancialInstrument::currency("USD"), silent = TRUE))
  for (sym in symbols) suppressWarnings(FinancialInstrument::stock(sym, currency = "USD", multiplier = 1))
  initPortf(portf, symbols = symbols, initDate = init_date, currency = "USD")
  initAcct(acct, portfolios = portf, initDate = init_date, initEq = 1e7)
  initOrders(portfolio = portf, symbols = symbols, initDate = init_date); strategy(st, store = TRUE)
  add.indicator(st, name = "SMA", arguments = list(x = quote(Cl(mktdata)), n = fast_n), label = "fast")
  add.indicator(st, name = "SMA", arguments = list(x = quote(Cl(mktdata)), n = slow_n), label = "slow")
  add.signal(st, name = "sigCrossover", arguments = list(columns = c("fast", "slow"), relationship = "gt"), label = "enter")
  add.signal(st, name = "sigCrossover", arguments = list(columns = c("fast", "slow"), relationship = "lt"), label = "exit")
  add.rule(st, name = "ruleSignal", arguments = list(sigcol = "enter", sigval = TRUE, orderqty = 1, ordertype = "market", orderside = "long", replace = FALSE), type = "enter")
  add.rule(st, name = "ruleSignal", arguments = list(sigcol = "exit", sigval = TRUE, orderqty = "all", ordertype = "market", orderside = "long", replace = FALSE), type = "exit")
  el <- system.time(invisible(capture.output({
    applyStrategy(st, portfolios = portf, verbose = FALSE); updatePortf(portf); updateAcct(acct); updateEndEq(acct)
  })))[["elapsed"]]
  fills <- tryCatch(sum(vapply(symbols, function(s) max(0L, nrow(getTxns(portf, s)) - 1L), integer(1))), error = function(e) NA_integer_)
  list(wall = el, fills = fills)
}

rows <- list()
for (w in WIDTHS) {
  bars <- as.data.frame(ledgr_sim_bars(n_instruments = w, n_days = DAYS, seed = SEED))
  utils::write.csv(bars, file.path(OUT, sprintf("peer3_bars_%d.csv", w)), row.names = FALSE)
  bc <- w * DAYS
  L <- run_ledgr(bars, FAST, SLOW)
  Q <- tryCatch(run_quantstrat(bars, FAST, SLOW, as.character(w)), error = function(e) { cat("QS ERR @", w, ":", conditionMessage(e), "\n"); list(wall = NA_real_, fills = NA_integer_) })
  rows[[length(rows) + 1L]] <- data.frame(engine = "ledgr", n_inst = w, n_days = DAYS, wall_sec = L$wall, bars_sec = bc / L$wall, fills = L$fills, stringsAsFactors = FALSE)
  rows[[length(rows) + 1L]] <- data.frame(engine = "quantstrat", n_inst = w, n_days = DAYS, wall_sec = Q$wall, bars_sec = bc / Q$wall, fills = Q$fills, stringsAsFactors = FALSE)
  cat(sprintf("[w=%d] ledgr %.2fs (%.0f b/s, %s fills) | quantstrat %.2fs (%.0f b/s, %s fills)\n", w, L$wall, bc / L$wall, L$fills, Q$wall, bc / Q$wall, Q$fills))
}
utils::write.csv(do.call(rbind, rows), file.path(OUT, "peer_three_way_results.csv"), row.names = FALSE)
cat("WROTE", file.path(OUT, "peer_three_way_results.csv"), "\n")
