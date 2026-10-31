# LDG-3167 refusal-order probe: public finite inputs that fail in two rows of
# one pulse. Usage: Rscript probe_multi.R base|candidate <out.rds>
args <- commandArgs(TRUE)
mode <- args[[1L]]
if (identical(mode, "base")) {
  library(ledgr, lib.loc = "E:/ledgr-data/r-lib/ledgr-v0.2.3-base-953338df")
} else {
  suppressMessages(pkgload::load_all("C:/Users/maxth/ledgr-wt/ws4a-impl", quiet = TRUE))
}
days <- as.POSIXct("2020-01-01 16:00:00", tz = "UTC") + 86400 * 0:3
bars <- function(prices) do.call(rbind, lapply(names(prices), function(id) data.frame(ts_utc = days, instrument_id = id,
  open = prices[[id]], high = prices[[id]], low = prices[[id]], close = prices[[id]], volume = 1000, stringsAsFactors = FALSE)))
outcome <- function(expr) {
  w <- 0L
  e <- withCallingHandlers(tryCatch({ force(expr); NULL }, error = identity),
    warning = function(x) { w <<- w + 1L; invokeRestart("muffleWarning") })
  if (is.null(e)) return(c("none", "", w))
  c(paste(class(e), collapse = "/"), conditionMessage(e), w)
}
scenario <- function(prices, opening, targets, cost, mode = "audit_log") {
  snap <- ledgr_snapshot_from_df(bars(prices), db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snap))
  exp <- ledgr_experiment(snap, function(ctx, params) {
    t <- ctx$hold()
    if (identical(substr(ctx$ts_utc, 1, 10), "2020-01-01")) for (id in names(params$t)) t[[id]] <- params$t[[id]]
    t
  }, cost_model = cost, opening = opening, execution_mode = mode)
  list(
    run = outcome(close(ledgr_run(exp, params = list(t = targets), run_id = "p", seed = 1L))),
    sweep = outcome({
      s <- ledgr_sweep(exp, ledgr_grid_named(c = list(strategy = list(t = targets))), seed = 1L)
      if (s$status[[1L]] != "DONE") stop(structure(class = c(s$error_class[[1L]], "error", "condition"),
        list(message = paste("sweep", s$status[[1L]], s$error_msg[[1L]] %||% ""), call = NULL)))
    })
  )
}
`%||%` <- function(a, b) if (is.null(a)) b else a
big <- 1e308
res <- list(
  # Row 1 (AAA) publishes a cash effect of +Inf (sell 1e308 at 1.9, finite lot
  # facts); row 2 (BBB) buys 1e308 at 10 (infinite basis, a lot refusal).
  pub1_lot2 = scenario(list(AAA = 1.9, BBB = 10), ledgr_opening(cash = 1000, positions = c(AAA = big), cost_basis = c(AAA = 1)),
    list(AAA = 0, BBB = big), ledgr_cost_zero()),
  pub1_lot2_live = scenario(list(AAA = 1.9, BBB = 10), ledgr_opening(cash = 1000, positions = c(AAA = big), cost_basis = c(AAA = 1)),
    list(AAA = 0, BBB = big), ledgr_cost_zero(), mode = "db_live"),
  # Reversed rows: row 1 (AAA) is the lot refusal, row 2 (BBB) the Inf cash.
  lot1_pub2 = scenario(list(AAA = 10, BBB = 1.9), ledgr_opening(cash = 1000, positions = c(BBB = big), cost_basis = c(BBB = 1)),
    list(AAA = big, BBB = 0), ledgr_cost_zero()),
  # Single rows of each kind.
  pub_only = scenario(list(AAA = 1.9, BBB = 10), ledgr_opening(cash = 1000, positions = c(AAA = big), cost_basis = c(AAA = 1)),
    list(AAA = 0), ledgr_cost_zero()),
  lot_only = scenario(list(AAA = 10, BBB = 1.9), ledgr_opening(cash = 1000), list(AAA = big), ledgr_cost_zero()),
  # Fee overflow on row 2 only (fixed 1.79e308 plus 100% notional on a large row).
  ok1_fee2 = scenario(list(AAA = 10, BBB = 10), ledgr_opening(cash = 1000),
    list(AAA = 1, BBB = 1e307), ledgr_cost_chain(ledgr_cost_fixed_fee(1.79e308), ledgr_cost_notional_bps_fee(10000))),
  # NaN fees on both rows (zero notional on an infinite notional).
  nan1_nan2 = scenario(list(AAA = 10, BBB = 10), ledgr_opening(cash = 1000), list(AAA = big, BBB = big), ledgr_cost_notional_bps_fee(0)),
  # Row 1 NaN fee, row 2 Inf cash sell.
  nan1_pub2 = scenario(list(AAA = 10, BBB = 1.9), ledgr_opening(cash = 1000, positions = c(BBB = big), cost_basis = c(BBB = 1)),
    list(AAA = big, BBB = 0), ledgr_cost_notional_bps_fee(0))
)
saveRDS(res, args[[2L]])
for (n in names(res)) for (p in names(res[[n]])) cat(sprintf("%-16s %-6s %s | %s | w=%s\n", n, p, res[[n]][[p]][[1]], substr(res[[n]][[p]][[2]], 1, 90), res[[n]][[p]][[3]]))
