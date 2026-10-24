# Spot-crypto readiness, prerequisite probe (Stage 0).
#
# Question: can the released package preserve (a) fractional quantities and
# (b) a complete 24/7 daily session clock on a synthetic BTC/USD + ETH/USD
# spot fixture, through ledgr_run() and a durable reopen?
#
# Usage: Rscript <abs path>/dev/spikes/crypto-readiness/probe.R [out_dir]
# Loads the package from this checkout with pkgload; never edits package code.
# Writes evidence CSVs and probe_log.txt into out_dir (default: tempdir()).

args <- commandArgs(trailingOnly = FALSE)
script <- normalizePath(sub("^--file=", "", args[grep("^--file=", args)][1]), winslash = "/")
repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), winslash = "/")
trail <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(trail) >= 1L) trail[[1L]] else file.path(tempdir(), "crypto_probe")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
setwd(repo)
suppressMessages(pkgload::load_all(repo, quiet = TRUE))

log_con <- file(file.path(out_dir, "probe_log.txt"), open = "wt")
sink(log_con, split = TRUE)
sink(log_con, type = "message")
options(width = 140, pillar.width = 140, tibble.width = 140, digits = 15)
section <- function(x) cat("\n==== ", x, " ====\n", sep = "")
try_obs <- function(label, expr) {
  out <- tryCatch(
    withCallingHandlers(expr, warning = function(w) {
      cat("[", label, "] WARNING <", paste(class(w), collapse = "/"), ">: ", conditionMessage(w), "\n", sep = "")
      invokeRestart("muffleWarning")
    }),
    error = function(e) {
      cat("[", label, "] ERROR <", paste(class(e), collapse = "/"), ">: ", conditionMessage(e), "\n", sep = "")
      NULL
    }
  )
  invisible(out)
}
write_ev <- function(df, name) {
  utils::write.csv(as.data.frame(df), file.path(out_dir, paste0(name, ".csv")), row.names = FALSE)
}
cat("git HEAD:", system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE), "\n")
cat("ledgr version:", as.character(utils::packageVersion("ledgr", lib.loc = NULL)), "\n")

# ---------------------------------------------------------------------------
section("Fixture: 120 consecutive UTC calendar days, every day a session")
days <- seq(as.Date("2024-01-01"), by = "day", length.out = 120L)
sessions_df <- data.frame(
  session_date = days,
  status = "open",
  session_open = "00:00:00",
  session_close = "23:59:59"
)
sessions <- ledgr_facts_sessions(sessions_df, venue_id = "SYNTH_SPOT", knowledge = "assume_effective", timezone = "UTC")
cat("weekdays covered:", paste(sort(unique(weekdays(days))), collapse = ", "), "\n")
cat("US-holiday dates in window present as open sessions:",
    paste(intersect(as.character(days), c("2024-01-01", "2024-01-15", "2024-02-19", "2024-03-29")), collapse = ", "), "\n")

# Deterministic synthetic closes; whole-feed gap on days 70..73 (both assets).
gap_days <- days[70:73]
ts <- as.POSIXct(paste(days, "23:59:59"), tz = "UTC")
mk <- function(id, base, drift) {
  close <- round(base * (1 + drift * seq_along(days) + 0.02 * sin(seq_along(days) / 5)), 2)
  open <- c(base, head(close, -1L))
  data.frame(instrument_id = id, ts_utc = ts, open = open,
             high = pmax(open, close) * 1.01, low = pmin(open, close) * 0.99,
             close = close, volume = 1000)
}
bars <- rbind(mk("BTCUSD", 42000, 0.002), mk("ETHUSD", 2300, 0.001))
bars <- bars[!as.Date(bars$ts_utc) %in% gap_days, ]
cat("bar rows:", nrow(bars), " gap days (no bar for either asset):", paste(gap_days, collapse = ", "), "\n")

db_path <- file.path(out_dir, "crypto_probe.duckdb")
if (file.exists(db_path)) unlink(db_path)
snapshot <- ledgr_snapshot_from_df(
  bars,
  instruments_df = data.frame(instrument_id = c("BTCUSD", "ETHUSD")),
  facts = ledgr_facts(sessions),
  price_basis = "split_adjusted",
  db_path = db_path,
  snapshot_id = "crypto_probe"
)
print(snapshot)
snapshot_hash <- ledgr_snapshot_info(snapshot)$snapshot_hash
cat("snapshot_hash:", snapshot_hash, "\n")

# ---------------------------------------------------------------------------
section("Strategy: fractional target quantities on a schedule")
# Decision day index -> targets. Fills at the next session open.
schedule <- list(
  `5`  = c(BTCUSD = 0.0371, ETHUSD = 1.2345),
  `30` = c(BTCUSD = 0.05, ETHUSD = 0.5),
  `50` = c(BTCUSD = 0.0123456789, ETHUSD = 2.000001),
  `69` = c(BTCUSD = 0.0200001, ETHUSD = 0.333333333),  # fill day 70 is in the gap
  `100` = c(BTCUSD = 0, ETHUSD = 0.1)
)
first_day <- days[[1L]]
frac_strategy <- function(ctx, params) {
  targets <- ctx$hold()
  i <- as.integer(as.Date(ledgr_utc(ctx$ts_utc)) - params$first_day) + 1L
  keys <- as.integer(names(params$schedule))
  active <- keys[keys <= i]
  if (length(active) == 0L) return(targets)
  want <- params$schedule[[as.character(max(active))]]
  ok <- intersect(names(want), ctx$tradable())  # tradable() returns IDs
  targets[ok] <- want[ok]
  targets
}

exp <- ledgr_experiment(
  snapshot, frac_strategy,
  opening = ledgr_opening(cash = 10000),
  cost_model = ledgr_cost_notional_bps_fee(10),
  metric_context = ledgr_metric_crypto()
)
print(ledgr_experiment_plan(exp))
bt <- try_obs("ledgr_run", ledgr_run(exp, params = list(schedule = schedule, first_day = first_day), run_id = "frac-247"))
if (is.null(bt)) stop("ledgr_run failed; see log above")
print(bt)
cfg_hash <- ledgr_run_info(snapshot, "frac-247")$config_hash
cat("config_hash:", cfg_hash, "\n")

read_all <- function(bt) {
  list(
    fills = ledgr_results(bt, "fills"),
    trades = ledgr_results(bt, "trades"),
    equity = ledgr_results(bt, "equity"),
    ledger = ledgr_results(bt, "ledger"),
    run_fills = ledgr_run_fills(bt),
    completion = capture.output(print(ledgr_run_completion(bt))),
    summary = capture.output(summary(bt))
  )
}
live <- read_all(bt)

section("(a) fills: requested target vs filled quantity")
print(as.data.frame(live$fills), digits = 15)
f <- as.data.frame(live$fills)
cat("fee - qty*price*10bps (max abs):", max(abs(f$fee - f$qty * f$price * 10 / 1e4)), "\n")
section("(a) ledger events")
print(as.data.frame(live$ledger), digits = 15)
section("(a) trades")
print(as.data.frame(live$trades), digits = 15)
section("(a) equity (rows around fills and the gap)")
eq <- as.data.frame(live$equity)
print(eq[as.Date(eq$ts_utc) %in% c(days[c(5:7, 30:32, 50:52, 68:76, 100:102)], days[120]), ], digits = 15)
section("(b) pulse count and calendar coverage")
cat("equity rows:", nrow(eq), " distinct dates:", length(unique(as.Date(eq$ts_utc))),
    " first:", format(min(eq$ts_utc)), " last:", format(max(eq$ts_utc)), "\n")
cat("weekend pulses:", sum(weekdays(as.Date(eq$ts_utc)) %in% c("Saturday", "Sunday")), "\n")
section("(b) whole-feed gap: explain BTCUSD and ETHUSD around days 68..76")
for (id in c("BTCUSD", "ETHUSD")) {
  ex <- as.data.frame(ledgr_run_explain(bt, id))
  keep <- as.Date(ex$ts_utc) %in% days[68:76]
  cols <- intersect(c("ts_utc", "mark_source", "mark_age", "target_before_risk", "execution_outcome",
                      "execution_reason", "resulting_position"), names(ex))
  print(ex[keep, cols], digits = 15)
}
section("valuation summary")
print(ledgr_valuation_summary(bt))
section("completion")
cat(live$completion, sep = "\n")
section("summary(bt) with experiment metric context ledgr_metric_crypto()")
cat(live$summary, sep = "\n")
section("summary(bt) with US-equity metric context (comparison)")
try_obs("summary_us_equity", print(summary(bt, metric_context = ledgr_metric_us_equity())))

# ---------------------------------------------------------------------------
section("Positions from the ledger (ledgr_state_reconstruct) before close")
con <- ledgr_db_init(db_path)
pos_live <- ledgr_state_reconstruct("frac-247", con)$positions
DBI::dbDisconnect(con, shutdown = TRUE)
print(as.data.frame(pos_live), digits = 17)
section("(a) FIFO lots replayed from the product's own fill rows vs realized_pnl")
# Independent FIFO replay over the fills table: lots are (qty, price) queues.
fifo <- function(fills) {
  out <- list()
  for (id in unique(fills$instrument_id)) {
    f <- fills[fills$instrument_id == id, ]
    lots <- data.frame(qty = numeric(), price = numeric())
    for (k in seq_len(nrow(f))) {
      if (f$side[k] == "BUY") {
        lots <- rbind(lots, data.frame(qty = f$qty[k], price = f$price[k]))
        next
      }
      left <- f$qty[k]
      pnl <- 0
      while (left > 0 && nrow(lots) > 0) {
        take <- min(left, lots$qty[1])
        pnl <- pnl + take * (f$price[k] - lots$price[1])
        lots$qty[1] <- lots$qty[1] - take
        left <- left - take
        if (lots$qty[1] <= 1e-12) lots <- lots[-1, , drop = FALSE]
      }
      out[[length(out) + 1L]] <- data.frame(event_seq = f$event_seq[k], instrument_id = id,
                                            replay_pnl = pnl, product_pnl = f$realized_pnl[k])
    }
    cat(id, "open lots after replay:", if (nrow(lots)) sprintf("%.17g@%.2f", lots$qty, lots$price) else "none", "\n")
  }
  do.call(rbind, out)
}
rp <- fifo(as.data.frame(live$fills))
print(rp, digits = 17)
cat("max |replay_pnl - product_pnl|:", max(abs(rp$replay_pnl - rp$product_pnl)), "\n")

# ---------------------------------------------------------------------------
section("Durable reopen: close everything, reopen from the store, read back")
close(bt)
ledgr_snapshot_close(snapshot)
rm(bt, snapshot)
invisible(gc())
snapshot2 <- ledgr_snapshot_open(db_path, snapshot_id = "crypto_probe", verify = TRUE)
cat("reopened snapshot_hash:", ledgr_snapshot_info(snapshot2)$snapshot_hash,
    " identical:", identical(ledgr_snapshot_info(snapshot2)$snapshot_hash, snapshot_hash), "\n")
bt2 <- ledgr_run_open(snapshot2, "frac-247")
cat("reopened config_hash identical:", identical(ledgr_run_info(snapshot2, "frac-247")$config_hash, cfg_hash), "\n")
reopened <- read_all(bt2)
for (nm in names(live)) {
  same <- isTRUE(all.equal(live[[nm]], reopened[[nm]], tolerance = 0, check.attributes = FALSE))
  cat(sprintf("reopen %-11s identical values: %s\n", nm, same))
  if (!same) print(all.equal(live[[nm]], reopened[[nm]], tolerance = 0, check.attributes = FALSE))
}
con <- ledgr_db_init(db_path)
pos_reopen <- ledgr_state_reconstruct("frac-247", con)$positions
DBI::dbDisconnect(con, shutdown = TRUE)
cat("reopen positions identical values:",
    isTRUE(all.equal(as.data.frame(pos_live), as.data.frame(pos_reopen), tolerance = 0, check.attributes = FALSE)), "\n")
section("Reopened final positions and raw ledger quantities (15 significant digits)")
fin <- as.data.frame(pos_reopen)
cat(sprintf("final position %s qty=%.17g\n", fin$instrument_id, fin$qty), sep = "")
cat(sprintf("%s %s qty=%.15g price=%.15g fee=%.15g\n", reopened$ledger$instrument_id, reopened$ledger$side,
            reopened$ledger$qty, reopened$ledger$price, reopened$ledger$fee), sep = "")
write_ev(reopened$fills, "fills")
write_ev(reopened$trades, "trades")
write_ev(reopened$equity, "equity")
write_ev(reopened$ledger, "ledger")
write_ev(pos_reopen, "positions")

# ---------------------------------------------------------------------------
section("Helper observation: ledgr_target_rebalance / ledgr_weights / ledgr_target_quantity")
helper_rows <- new.env()
helper_strategy <- function(ctx, params) {
  i <- as.integer(as.Date(ledgr_utc(ctx$ts_utc)) - params$first_day) + 1L
  if (i == 5L) {
    w <- ledgr_weights(c(BTCUSD = 0.5, ETHUSD = 0.5), universe = ctx$universe)
    tr <- ledgr_target_rebalance(w, ctx)
    sel <- ledgr_selection(stats::setNames(c(TRUE, TRUE), ctx$universe), universe = ctx$universe)
    tq <- ledgr_target_quantity(sel, ctx, qty = 0.0371)
    helper_rows$out <- data.frame(
      instrument_id = ctx$universe, equity = ctx$equity, close = as.numeric(ctx$vec$close),
      unfloored = 0.5 * ctx$equity / as.numeric(ctx$vec$close),
      rebalance_target = as.numeric(tr), target_quantity_0.0371 = as.numeric(tq)
    )
    return(tr)
  }
  ctx$hold()
}
snapshot3 <- ledgr_snapshot_open(db_path, snapshot_id = "crypto_probe")
for (cash in c(1000, 100000)) {
  bt_h <- try_obs("helper_run", ledgr_run(
    ledgr_experiment(snapshot3, helper_strategy, opening = ledgr_opening(cash = cash),
                     cost_model = ledgr_cost_notional_bps_fee(10), metric_context = ledgr_metric_crypto()),
    params = list(first_day = first_day), run_id = paste0("helper-", cash, "usd")))
  print(helper_rows$out, digits = 15)
  if (!is.null(bt_h)) {
    cat("helper run fills (", cash, " USD):\n", sep = "")
    print(as.data.frame(ledgr_results(bt_h, "fills"))[, c("instrument_id", "side", "qty", "price", "fee")], digits = 15)
    close(bt_h)
  }
}

section("Default metric context on the 24/7 clock (no metric_context supplied)")
bt_d <- try_obs("default_ctx_run", ledgr_run(
  ledgr_experiment(snapshot3, frac_strategy, opening = ledgr_opening(cash = 10000),
                   cost_model = ledgr_cost_notional_bps_fee(10)),
  params = list(schedule = schedule, first_day = first_day), run_id = "frac-247-default-ctx"))
if (!is.null(bt_d)) {
  try_obs("summary_default_ctx", print(summary(bt_d)))
  cat("default-context equity identical to crypto-context equity:",
      isTRUE(all.equal(as.data.frame(ledgr_results(bt_d, "equity")), as.data.frame(reopened$equity),
                       tolerance = 0, check.attributes = FALSE)), "\n")
  close(bt_d)
}
ledgr_snapshot_close(snapshot3)
close(bt2)
ledgr_snapshot_close(snapshot2)
cat("\nprobe complete; evidence in", out_dir, "\n")
sink(type = "message")
sink()
close(log_con)
