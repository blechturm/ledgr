# R-floor stage 2b contract parity (charter, "Parity"): small crossover runs
# (4 instruments x 30 pulses) on the lean loop and the full reference. A
# refusal must carry the same class on both; an accepted run must give the
# same records. Written after the reference ran (protocol section 3).
#
#   Rscript dev/spikes/r_floor/stage2b/fixtures.R --lib=<pin library> --out=<dir>
#
# The affordability reconciliation stop has no fixture: it compares the
# accepted cash effects summed at once with the same effects summed one by
# one, at a relative tolerance of 1e-8, and no constructible input separates
# them. Its reference branch is exercised by the checker's gutted path.

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), args, value = TRUE)[[1L]])
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", "..", ".."), winslash = "/")
lib <- normalizePath(opt("lib"), winslash = "/", mustWork = TRUE)
source(file.path(here, "lean_clocks.R"))
env <- spk_lean_env(lib, repo, clocks = FALSE)
ns <- env$ns; defs <- env$defs; lean <- env$lean
sys.source(file.path(repo, "dev/spikes/r_floor/floor.R"), envir = defs, keep.source = FALSE)
ref <- new.env(parent = ns); ref$.lean_debug <- FALSE
sys.source(file.path(repo, "dev/lean_core/fifo.R"), envir = ref, keep.source = FALSE)
sys.source(file.path(here, "reference.R"), envir = ref, keep.source = FALSE)

base <- ref$s2b_workload("4x30", defs)
on12 <- base$iso[[12L]]
# The strategy preflight refuses captured variables, so each fixture is the
# crossover body with one statement spliced in before its result, the pulse
# time as a literal.
stmts <- as.list(body(defs$r_floor_transition))[-1L]
mk <- function(extra) {
  f <- function(ctx, params) NULL
  body(f) <- as.call(c(as.name("{"), stmts[-length(stmts)], do.call(substitute, list(extra, list(ON = on12))), stmts[length(stmts)]))
  environment(f) <- ns
  f
}
fixtures <- list(
  nonfinite_target = list(strategy = mk(quote(if (identical(ctx$ts_utc, ON)) targets[[1L]] <- NA_real_))),
  cost_rejects_sells = list(cost = list(list(type = "spread_bps", bps = 30000)), cost_model = ledgr::ledgr_cost_spread_bps(30000)),
  insufficient_cash = list(cash = 150),
  short_target = list(strategy = mk(quote(if (identical(ctx$ts_utc, ON)) targets[[2L]] <- -1))),
  malformed_sizing = list(strategy = mk(quote(if (identical(ctx$ts_utc, ON)) {
    t <- ctx$hold(); attr(t, "sizing_evidence") <- structure(list(instrument_id = "P01"), class = "ledgr_sizing_evidence")
    return(t) }))),
  stale_sizing = list(strategy = mk(quote(if (identical(ctx$ts_utc, ON)) {
    t <- ledgr_target_rebalance(ctx, weights = stats::setNames(rep(0.2, 4L), ctx$universe), invest_fraction = 0.5)
    t[[1L]] <- t[[1L]] + 1; return(t) }))))

outcome <- function(expr) tryCatch(list(value = force(expr)), error = function(e) list(class = class(e), message = conditionMessage(e)))
rows <- list()
for (name in names(fixtures)) {
  fx <- fixtures[[name]]
  w <- base
  if (!is.null(fx$strategy)) w$strategy <- fx$strategy
  if (!is.null(fx$cost)) w$steps <- fx$cost
  if (!is.null(fx$cash)) w$cash <- fx$cash
  r <- outcome(ref$s2b_run(w))
  store <- tempfile(fileext = ".duckdb")
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(defs$r_floor_fixture(4L, 30L)$bars, db_path = store, snapshot_id = "fx",
                                                            price_basis = "split_adjusted"))
  snapshot <- ledgr::ledgr_snapshot_open(store, "fx", verify = TRUE)
  exp <- ledgr::ledgr_experiment(snapshot, w$strategy,
    features = ledgr::ledgr_feature_map(fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
                                        slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    opening = ledgr::ledgr_opening(cash = w$cash), cost_model = fx$cost_model %||% ledgr::ledgr_cost_zero(),
    risk_chain = ledgr::ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE))
  restore <- lean$lean_loop_install(); spk_reset(env)
  folds0 <- lean$lean_entry$lean_folds
  l <- outcome(suppressWarnings(ledgr::ledgr_run(exp, run_id = name, seed = 20260530L)))
  ran_lean <- lean$lean_entry$lean_folds - folds0 == 1L
  restore(); ledgr::ledgr_snapshot_close(snapshot)
  if (!is.null(l$value)) {
    fr <- lean$.spk$frame; keep <- function(x, n) lapply(x, function(v) v[seq_len(n)])
    l$records <- list(fills = keep(fr$fl, fr$nf), equity = keep(fr$eq, fr$n_eq), decisions = keep(fr$dr, fr$nd),
                      sizing = keep(fr$szr, fr$nsz), rejections = fr$rj, recon = fr$hd_recon, pre = fr$hd_pre,
                      sizing_notice = fr$hd_sizing, strategy_state = fr$strategy_state, status = fr$status)
    close(l$value)
  }
  same <- if (!is.null(r$class) && !is.null(l$class)) r$class[[1L]] %in% l$class else if (!is.null(r$value) && !is.null(l$value)) {
    a <- r$value; b <- l$records
    all(vapply(c("fills", "equity", "decisions", "sizing", "rejections"), function(p)
      all(vapply(names(a[[p]]), function(f) identical(unname(a[[p]][[f]]), unname(b[[p]][[f]])), TRUE)), TRUE)) &&
      identical(unname(a$recon), unname(b$recon)) && identical(a$pre, b$pre) && identical(a$sizing_notice, b$sizing_notice) &&
      identical(a$strategy_state, b$strategy_state) && identical(a$status, b$status)
  } else FALSE
  desc <- function(o) if (!is.null(o$class)) paste0("refused: ", o$class[[1L]]) else
    sprintf("accepted: %d fills, %d rejections (%s)", length(o$value$fills$qty %||% o$records$fills$qty),
            length(o$value$rejections$k %||% o$records$rejections$k),
            paste(unique(o$value$rejections$primary %||% o$records$rejections$primary), collapse = "|"))
  rows[[name]] <- data.frame(fixture = name, lean_loop_ran = ran_lean, lean = desc(l), reference = desc(r), same_outcome = same)
}
res <- do.call(rbind, rows)
utils::write.csv(res, file.path(opt("out"), "contract.csv"), row.names = FALSE)
print(res, row.names = FALSE)
quit(status = if (all(res$same_outcome & res$lean_loop_ran)) 0L else 1L)
