# Stage 3 probe: what ledgr's real strategy context does on a changing axis,
# before any lean code. Records the axis per pulse, whether a retained
# context stays frozen, what cutoff-bound history returns, how FIFO lots are
# exercised, and ledgr's per-pulse cost on this fixture.
# Usage: Rscript dev/spikes/r_floor/probe_axes.R <ledgr lib> [n_inst] [n_sessions]
args <- commandArgs(TRUE)
suppressPackageStartupMessages(library(ledgr, lib.loc = args[[1]]))
n_inst <- if (length(args) >= 2) as.integer(args[[2]]) else 30L
n_sess <- if (length(args) >= 3) as.integer(args[[3]]) else 250L
source(file.path("dev", "spikes", "r_floor", "axes_fixture.R"))

fx <- r_floor_axes_fixture(n_inst, n_sess)
seen <- new.env()
seen$axis <- integer(n_sess); seen$members <- integer(n_sess); seen$i <- 0L
seen$hist_s <- 0
strategy <- function(ctx, params) {
  i <- seen$i + 1L; seen$i <- i
  seen$axis[[i]] <- length(ctx$universe)
  if (i == 20L) {
    seen$kept <- ctx
    seen$kept_close <- ctx$close
    seen$kept_universe <- ctx$universe
  }
  t0 <- proc.time()[["elapsed"]]
  h <- ledgr_history_matrix(ctx, bar = "close", lookback = 10L)
  seen$hist_s <- seen$hist_s + proc.time()[["elapsed"]] - t0
  if (i == 30L) { seen$hist_dim <- dim(h); seen$hist_class <- class(h) }
  usable <- is.finite(ctx$fast) & is.finite(ctx$slow)
  targets <- ctx$hold()
  up <- usable & ctx$fast > ctx$slow
  # Varying quantities so sells consume FIFO lots partially.
  # Members may buy; held former members may only hold or reduce, so they
  # exit when their signal turns down.
  member <- ctx$member
  targets[up & member] <- 5 + (i %% 4) * 5
  targets[usable & !up] <- 0
  if (i == 1L) seen$fields <- c("member", "buyable", "held", "holding_value")
  targets
}
exp <- ledgr_experiment(fx$snapshot, strategy,
  features = ledgr_feature_map(
    fast = ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
    slow = ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
  opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero(),
  universe = ledgr_universe_members("U"), valuation_policy = ledgr_valuation_stale(5))
t0 <- proc.time()[["elapsed"]]
bt <- suppressWarnings(ledgr_run(exp, run_id = "axes_probe", seed = 1L))
run_s <- proc.time()[["elapsed"]] - t0
fills <- as.data.frame(ledgr_results(bt, "fills"))
d <- as.data.frame(ledgr_results(bt, "diagnostics"))
info <- ledgr_run_info(fx$snapshot, "axes_probe")
close(bt)

cat(sprintf("status %s; %d instruments, %d sessions, %d strategy calls\n",
  info$status, n_inst, n_sess, seen$i))
cat(sprintf("axis size per pulse: min %d, median %d, max %d; distinct sizes %d\n",
  min(seen$axis[seq_len(seen$i)]), stats::median(seen$axis[seq_len(seen$i)]),
  max(seen$axis[seq_len(seen$i)]), length(unique(seen$axis[seq_len(seen$i)]))))
cat(sprintf("retained context at pulse 20 still frozen after the run: close %s, universe %s\n",
  identical(seen$kept$close, seen$kept_close), identical(seen$kept$universe, seen$kept_universe)))
cat(sprintf("history matrix at pulse 30: %s, dim %s; %.1f us per call on average\n",
  paste(seen$hist_class, collapse = "/"), paste(seen$hist_dim, collapse = " x "),
  seen$hist_s / seen$i * 1e6))
cat(sprintf("fills %d (buys %d, sells %d, partial sells %d)\n", nrow(fills),
  sum(fills$side == "BUY"), sum(fills$side == "SELL"),
  sum(fills$side == "SELL" & fills$qty < 20)))
cat("fills columns:", paste(names(fills), collapse = ", "), "\n")
cat("diagnostic stage/outcome/reason counts:\n")
print(as.data.frame(table(paste(d$stage, d$outcome, d$reason_code))), row.names = FALSE)
cat("mark sources on decision rows:", paste(names(table(d$mark_source[d$stage == "decision"])),
  table(d$mark_source[d$stage == "decision"]), collapse = ", "), "\n")
cat(sprintf("ledgr run %.2f s, %.0f us per pulse (includes history calls in the strategy)\n",
  run_s, run_s / n_sess * 1e6))
