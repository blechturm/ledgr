# Probe: why is PMwR::btest about 50x faster than ledgr on the peer suite's
# 500 x 1260 SMA 5/10 transition workload? Read-only against the package.
#
# One mode per process:
#   Rscript probe.R --mode=pmwr    --out=<dir> --peerlib=<lib>
#   Rscript probe.R --mode=prepare --out=<dir> --lib=<ledgr lib>
#   Rscript probe.R --mode=ledgr   --out=<dir> --lib=<ledgr lib> --variant=<v> --workflow=<w> [--profile=1]
# Variants: transition (the suite recipe), vecstate (same decisions, state as
# two unnamed logical vectors), nostate (hold only, no state, no fills).
# Workflows: durable (ledgr_run + fills/equity readers), memory (one-candidate
# sweep), memory_fifo (the same sweep with the compiled spot-FIFO accelerator).

args <- commandArgs(trailingOnly = TRUE)
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
mode <- arg("mode"); out <- arg("out")
csv <- arg("csv", "C:/Users/maxth/AppData/Local/Temp/ledgr-peer-suite-cut3-normalized-inputs/500x1260.csv")
dir.create(out, showWarnings = FALSE, recursive = TRUE)
clock <- function(f) { t0 <- proc.time()[["elapsed"]]; v <- f(); list(value = v, sec = proc.time()[["elapsed"]] - t0) }
record <- function(rows, file) {
  path <- file.path(out, file)
  utils::write.csv(rows, path, row.names = FALSE)
}

if (identical(mode, "pmwr")) {
  .libPaths(c(arg("peerlib"), .libPaths()))
  bars <- utils::read.csv(csv)
  ids <- sort(unique(bars$instrument_id), method = "radix")
  times <- sort(unique(bars$ts_utc))
  index <- match(bars$ts_utc, times) + (match(bars$instrument_id, ids) - 1L) * length(times)
  prices <- lapply(c("open", "high", "low", "close"), function(name) {
    value <- matrix(NA_real_, length(times), length(ids), dimnames = list(NULL, ids))
    value[index] <- bars[[name]]
    value
  })
  run <- function() {
    close <- prices[[4L]]
    fast <- apply(close, 2L, TTR::SMA, n = 5L)
    slow <- apply(close, 2L, TTR::SMA, n = 10L)
    above <- fast > slow
    signal <- function() {
      t <- Time(); target <- Portfolio()
      if (t > 1L) {
        usable <- is.finite(fast[t, ]) & is.finite(slow[t, ]) & is.finite(fast[t - 1L, ]) & is.finite(slow[t - 1L, ])
        change <- usable & above[t, ] != above[t - 1L, ]
        target[change] <- as.numeric(above[t, change])
      }
      target
    }
    PMwR::btest(prices, signal, timestamp = times, instrument = ids, initial.cash = 1e7,
      initial.position = 0, b = 1L, lag = 1L, tc = 0, trade.at.open = TRUE,
      final.position = FALSE, include.data = FALSE)
  }
  rows <- do.call(rbind, lapply(1:5, function(i) {
    r <- clock(run)
    data.frame(engine = "pmwr", rep = i, sec = r$sec, fills = length(PMwR::journal(r$value)),
      final_wealth = utils::tail(r$value$wealth, 1L))
  }))
  record(rows, "pmwr.csv"); print(rows)
  quit(save = "no")
}

.libPaths(c(arg("lib"), "C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressPackageStartupMessages(library(ledgr))
snapshot_db <- file.path(out, "snapshot.duckdb")

if (identical(mode, "prepare")) {
  r <- clock(function() ledgr_snapshot_from_csv(csv, db_path = snapshot_db,
    snapshot_id = "probe_transition", price_basis = "split_adjusted"))
  record(data.frame(step = "snapshot_from_csv", sec = r$sec), "prepare.csv")
  quit(save = "no")
}

# The suite's dense_transition recipe, copied verbatim (dense/recipes.R:48).
transition <- function(ctx, params) {
  fast <- ctx$vec$feature("fast")
  slow <- ctx$vec$feature("slow")
  ids <- ctx$universe
  usable <- is.finite(fast) & is.finite(slow)
  above <- usable & fast > slow
  prior_above <- prior_usable <- stats::setNames(rep(FALSE, length(ids)), ids)
  old_above <- unlist(ctx$state_prev$above)
  old_usable <- unlist(ctx$state_prev$usable)
  prior_above[names(old_above)] <- old_above
  prior_usable[names(old_usable)] <- old_usable
  targets <- ctx$hold()
  enter <- prior_usable & usable & above & !prior_above
  exit <- prior_usable & usable & !above & prior_above
  targets[enter] <- 1
  targets[exit] <- 0
  list(targets = targets, state_update = list(
    above = as.list(stats::setNames(above, ids)),
    usable = as.list(stats::setNames(usable, ids))
  ))
}
# Same decisions; state carried as two unnamed logical vectors in axis order.
vecstate <- function(ctx, params) {
  fast <- ctx$vec$feature("fast")
  slow <- ctx$vec$feature("slow")
  usable <- is.finite(fast) & is.finite(slow)
  above <- usable & fast > slow
  n <- length(usable)
  prior_above <- if (is.null(ctx$state_prev$above)) rep(FALSE, n) else as.logical(ctx$state_prev$above)
  prior_usable <- if (is.null(ctx$state_prev$usable)) rep(FALSE, n) else as.logical(ctx$state_prev$usable)
  targets <- ctx$hold()
  targets[prior_usable & usable & above & !prior_above] <- 1
  targets[prior_usable & usable & !above & prior_above] <- 0
  list(targets = targets, state_update = list(above = above, usable = usable))
}
# Reads both features, never trades, writes no state: the per-pulse floor.
nostate <- function(ctx, params) {
  fast <- ctx$vec$feature("fast")
  slow <- ctx$vec$feature("slow")
  ctx$hold()
}

variant <- arg("variant", "transition"); workflow <- arg("workflow", "durable")
profile <- identical(arg("profile", "0"), "1")
snapshot <- ledgr_snapshot_open(snapshot_db, snapshot_id = "probe_transition")
exp <- ledgr_experiment(snapshot, get(variant), features = ledgr_feature_map(
  fast = ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
  slow = ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
  opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero(), risk_chain = ledgr_risk_none())
tag <- paste(variant, workflow, if (profile) "prof" else "plain", sep = "_")
run_id <- paste0("probe_", tag, "_", format(Sys.time(), "%H%M%S"))
if (profile) utils::Rprof(file.path(out, paste0(tag, ".rprof")), interval = 0.01, line.profiling = FALSE)
steps <- list()
if (identical(workflow, "durable")) {
  r <- clock(function() suppressWarnings(ledgr_run(exp, run_id = run_id, seed = 20260530L)))
  bt <- r$value; steps$run <- r$sec
  r <- clock(function() as.data.frame(ledgr_results(bt, "fills"))); fills <- r$value; steps$fills_reader <- r$sec
  r <- clock(function() as.data.frame(ledgr_results(bt, "equity"))); equity <- r$value; steps$equity_reader <- r$sec
  n_fills <- nrow(fills); final_equity <- utils::tail(equity$equity, 1L)
  close(bt)
} else {
  r <- clock(function() suppressWarnings(ledgr_sweep(exp,
    do.call(ledgr_grid_named, stats::setNames(list(list()), run_id)),
    retain = ledgr_sweep_retention(returns = "completed", trades = "closed"),
    workers = 1L, seed = 20260530L, stop_on_error = TRUE,
    compiled_accounting_model = if (identical(workflow, "memory_fifo")) "spot_fifo" else NULL)))
  cand <- r$value; steps$sweep <- r$sec
  r <- clock(function() as.data.frame(ledgr_sweep_returns(cand))); steps$returns_reader <- r$sec
  equity <- r$value
  n_fills <- NA_integer_; final_equity <- utils::tail(equity$equity, 1L)
}
if (profile) utils::Rprof(NULL)
rows <- data.frame(tag = tag, step = names(steps), sec = unlist(steps), fills = n_fills,
  final_equity = final_equity, row.names = NULL)
record(rows, paste0(tag, ".csv")); print(rows)
if (profile) {
  s <- utils::summaryRprof(file.path(out, paste0(tag, ".rprof")))
  record(cbind(fn = rownames(s$by.self), s$by.self), paste0(tag, "_self.csv"))
  record(cbind(fn = rownames(s$by.total), s$by.total), paste0(tag, "_total.csv"))
}
