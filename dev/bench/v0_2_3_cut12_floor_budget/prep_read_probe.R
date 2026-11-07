# Cut 12 R11 budget probe for the preparation family (LDG-3215).
#
# Floor v1 (dev/spikes/fold_plumbing/lean.R, fp_compact_fold at 2885596e)
# stubs every stage and emits each pulse's packet from a tape, so the
# preparation family's per-pulse cost above floor v1 is its own reads at
# their call sites: the fold reader's packet and view per pulse, and the
# registered history request set (cut12-prep-1, r1-r6) per decided pulse.
# The tile design (lean_core_interface.md Section 12.3) serves both through
# the pinned read services on tiles, so its probe is the pinned cost of
# those calls; finding the tile and assembling a slice must fit in the 15%
# margin. Mask-plane construction inside a read is preparation, as in the
# protocol, and is not charged.
#
# Each round runs a reference workload once with the pinned library, its
# own strategy unchanged, and the six registered reads issued before it on
# every decided pulse; the reads use the workload's first feature. Microseconds
# are per run pulse (floor v1's unit). The median over rounds plus 15% is
# the budget.
#
# Usage (host set up per benchmark_methodology: High performance plan,
# P-core affinity, no other R):
#   Rscript dev/bench/v0_2_3_cut12_floor_budget/prep_read_probe.R <pinned lib> [rounds] [out csv]

args <- commandArgs(TRUE)
lib <- args[[1L]]
rounds <- if (length(args) >= 2L) as.integer(args[[2L]]) else 5L
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
out_csv <- if (length(args) >= 3L) args[[3L]] else file.path(here, "evidence", "prep_read_budget.csv")
library(ledgr, lib.loc = lib)
source(file.path(repo, "dev/bench/v0_2_3_ws16_entry/workloads.R"))
ns <- asNamespace("ledgr")
work <- file.path(tempdir(), "prep_read_probe")
dir.create(work, showWarnings = FALSE)

# Each registered strategy body (ws16_*_strategy) after the six reads,
# inline: strategy preflight refuses free symbols.
inner <- list(
  momentum_40x504 = function(ctx, params) {
    ledgr::ledgr_history_matrix(ctx, bar = "close", lookback = 252L)
    ledgr::ledgr_history_matrix(ctx, feature = params$feature, lookback = 252L)
    ledgr::ledgr_history_frame(ctx, bar = "close", lookback = 63L, instruments = "decision_axis", layout = "long")
    ledgr::ledgr_history_frame(ctx, feature = params$feature, lookback = 63L, layout = "wide")
    ledgr::ledgr_history_matrix(ctx, bar = "close", lookback = 21L, min_observations = 15L)
    ledgr::ledgr_history_frame(ctx, bar = "close", lookback = 21L, instruments = params$off_axis, layout = "long")
    score <- ledgr::ledgr_signal_return(ctx, params$lookback)
    selected <- ledgr::ledgr_select_top(score, n = params$n, within = ctx$buyable)
    target <- ledgr::ledgr_target_rebalance(ctx, weights = ledgr::ledgr_weight_equal(selected), invest_fraction = 0.95,
                                            index_leavers = "keep", capital_base = "remaining_equity")
    list(targets = target)
  },
  fill_heavy_500x1260 = function(ctx, params) {
    ledgr::ledgr_history_matrix(ctx, bar = "close", lookback = 252L)
    ledgr::ledgr_history_matrix(ctx, feature = params$feature, lookback = 252L)
    ledgr::ledgr_history_frame(ctx, bar = "close", lookback = 63L, instruments = "decision_axis", layout = "long")
    ledgr::ledgr_history_frame(ctx, feature = params$feature, lookback = 63L, layout = "wide")
    ledgr::ledgr_history_matrix(ctx, bar = "close", lookback = 21L, min_observations = 15L)
    ledgr::ledgr_history_frame(ctx, bar = "close", lookback = 21L, instruments = params$off_axis, layout = "long")
    fast <- ctx$fast
    slow <- ctx$slow
    usable <- is.finite(fast) & is.finite(slow)
    above <- usable & fast > slow
    targets <- ctx$hold()
    enter <- ctx$state$usable & usable & above & !ctx$state$above
    exit <- ctx$state$usable & usable & !above & ctx$state$above
    targets[enter] <- 1
    targets[exit] <- 0
    ledgr::ledgr_strategy_result(targets, above = above, usable = usable)
  }
)

# Each workload's sealed store, built once; its experiment is the registered
# one (dev/bench/v0_2_3_ws16_entry/workloads.R) with the strategy wrapped.
stores <- list(
  momentum_40x504 = function(db) ws16_momentum_snapshot(40L, 504L, db, "probe_momentum"),
  fill_heavy_500x1260 = function(db) ledgr::ledgr_snapshot_from_df(ws16_fill_heavy_bars(), db_path = db,
                                                                   snapshot_id = "probe_fill")
)
ids <- c(momentum_40x504 = "probe_momentum", fill_heavy_500x1260 = "probe_fill")
experiments <- list(
  momentum_40x504 = function(snapshot, strategy) ledgr::ledgr_experiment(
    snapshot, strategy, features = list(ledgr::ledgr_ind_returns(63L)),
    schedule = ledgr::ledgr_schedule_month_start(), opening = ledgr::ledgr_opening(cash = 1e6),
    cost_model = ledgr::ledgr_cost_zero()),
  fill_heavy_500x1260 = function(snapshot, strategy) ledgr::ledgr_experiment(
    snapshot, strategy,
    features = ledgr::ledgr_feature_map(
      fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
    risk_chain = ledgr::ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE))
)
run_args <- list(momentum_40x504 = list(params = list(lookback = 63L, n = 10L), seed = 1L),
                 fill_heavy_500x1260 = list(params = list(), seed = 20260530L))
feature <- c(momentum_40x504 = "return_63", fill_heavy_500x1260 = "fast")
off_axis <- character()
for (w in names(stores)) {
  db <- file.path(work, paste0(w, ".duckdb"))
  if (file.exists(db)) unlink(db)
  ledgr::ledgr_snapshot_close(stores[[w]](db))
  con <- DBI::dbConnect(duckdb::duckdb(), db, read_only = TRUE)
  off_axis[[w]] <- DBI::dbGetQuery(con, "SELECT min(instrument_id) AS id FROM snapshot_instruments WHERE snapshot_id = ?",
                                   params = list(ids[[w]]))$id
  DBI::dbDisconnect(con, shutdown = TRUE)
}

now <- function() as.numeric(Sys.time())
one_round <- function(w, round) {
  clk <- new.env()
  clk$packet <- 0; clk$req <- numeric(6L); clk$k <- 0L; clk$in_read <- FALSE
  clk$masks <- 0; clk$pulses <- 0L
  originals <- list()
  install <- function(name, make) {
    originals[[name]] <<- get(name, envir = ns)
    unlockBinding(name, ns); assign(name, make(originals[[name]]), envir = ns); lockBinding(name, ns)
  }
  on.exit(for (name in names(originals)) {
    unlockBinding(name, ns); assign(name, originals[[name]], envir = ns); lockBinding(name, ns)
  })
  install("ledgr_history_substrate_fold_reader", function(orig) function(...) {
    r <- orig(...)
    for (f in c("bars", "view")) local({
      g <- r[[f]]; is_bars <- f == "bars"
      r[[f]] <<- function(...) {
        t0 <- now(); on.exit(clk$packet <- clk$packet + (now() - t0))
        if (is_bars) clk$pulses <- clk$pulses + 1L
        g(...)
      }
    })
    r
  })
  for (name in c("ledgr_history_prepare_masks", "ledgr_history_prepare_positions")) install(name, function(orig) {
    function(...) {
      t0 <- now(); on.exit(if (clk$in_read) clk$masks <- clk$masks + (now() - t0)); orig(...)
    }
  })
  for (name in c("ledgr_history_matrix", "ledgr_history_frame")) install(name, function(orig) function(...) {
    if (clk$in_read) return(orig(...))
    k <- clk$k %% 6L + 1L; clk$k <- clk$k + 1L
    clk$in_read <- TRUE; m0 <- clk$masks; t0 <- now()
    res <- orig(...)
    clk$req[[k]] <- clk$req[[k]] + (now() - t0) - (clk$masks - m0)
    clk$in_read <- FALSE
    res
  })
  snapshot <- ledgr::ledgr_snapshot_open(file.path(work, paste0(w, ".duckdb")), ids[[w]], verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- experiments[[w]](snapshot, inner[[w]])
  a <- run_args[[w]]
  a$params <- c(a$params, list(feature = feature[[w]], off_axis = off_axis[[w]]))
  t0 <- now()
  close(suppressWarnings(do.call(ledgr::ledgr_run, c(list(exp, run_id = paste0("probe-", round)), a))))
  if (clk$k %% 6L != 0L || clk$pulses == 0L) stop("no fold ran, or history reads did not come in sets of six: ", clk$k)
  list(run_s = now() - t0, pulses = clk$pulses, decided = clk$k %/% 6L, packet = clk$packet, req = clk$req)
}

rows <- list()
for (r in seq_len(rounds)) for (w in names(stores)) {
  x <- one_round(w, r)
  rows[[length(rows) + 1L]] <- data.frame(round = r, workload = w, pulses = x$pulses, decided = x$decided,
                                          run_s = x$run_s, packet_us = 1e6 * x$packet / x$pulses,
                                          t(stats::setNames(1e6 * x$req / x$pulses, paste0("r", 1:6, "_us"))))
  cat(sprintf("round %d %s: %d pulses, %d decided, packet %.1f us, reads %.1f us per pulse\n", r, w, x$pulses,
              x$decided, 1e6 * x$packet / x$pulses, 1e6 * sum(x$req) / x$pulses))
}
raw <- do.call(rbind, rows)
cols <- c("packet_us", paste0("r", 1:6, "_us"))
raw$total_us <- rowSums(raw[cols])
summ <- do.call(rbind, lapply(split(raw, raw$workload), function(k) {
  med <- vapply(c(cols, "total_us"), function(cl) stats::median(k[[cl]]), 0)
  data.frame(workload = k$workload[[1L]], rounds = nrow(k), pulses = k$pulses[[1L]], decided = k$decided[[1L]],
             t(round(med, 1)), budget_us = round(1.15 * med[["total_us"]], 1),
             total_range_pct = round(100 * diff(range(k$total_us)) / med[["total_us"]], 1))
}))
print(summ, row.names = FALSE)
utils::write.csv(summ, out_csv, row.names = FALSE)
utils::write.csv(raw, sub("\\.csv$", "_raw.csv", out_csv), row.names = FALSE)
