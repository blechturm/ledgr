# Per-stage profile of the pinned fold (macro WS16 family method, point 2).
# Before the first family after the first checkpoint: how much of a run each
# fold stage takes, and how much the loop itself takes between stages, so
# the maintainer can order the P1-P3 families by measured cost and decide
# when the loop comes.
#
#   Rscript dev/bench/v0_2_3_ws16_stage_profile/stage_profile.R <pinned lib> <out dir> [rounds]
#
# Host per benchmark_methodology: High performance plan, affinity, no other R.
#
# The pinned loop (R/fold-engine.R, ledgr_fold_envelope's run_loop, pin
# d5b3a151) calls each stage through a namespace binding. Each binding is
# wrapped with a clock; the strategy callback (ledgr_call_strategy_fn) is
# timed separately and subtracted from P2. Per run:
#   setup     ledgr_fold_envelope entry to the first P1 call
#   P1..P5    ledgr_fold_stage_observe_settle, _decide (less strategy),
#             _plan, _apply, _commit
#   strategy  the user strategy callback
#   skip      ledgr_fold_scheduled_skip_decision/_plan (pulses not due)
#   loop      first P1 entry to last stage exit, less every timed stage:
#             the loop's own work between stages (staging, flushes,
#             telemetry, stop checks, block writes)
#   finalise  last stage exit to ledgr_fold_envelope exit
#   outside   ledgr_run wall less ledgr_fold_envelope (experiment checks,
#             preparation, features, store writes after the fold)
# Each wrapper costs a few microseconds per call; per-pulse figures carry
# about 2 us of clock overhead per timed call.

args <- commandArgs(TRUE)
lib <- args[[1L]]
out <- args[[2L]]
rounds <- if (length(args) >= 3L) as.integer(args[[3L]]) else 5L
dir.create(out, recursive = TRUE, showWarnings = FALSE)
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                              winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(repo, "dev/bench/v0_2_3_ws16_entry/common.R"))
pin <- ws16_load_installed(lib)
source(file.path(repo, "dev/bench/v0_2_3_ws16_entry/workloads.R"))
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))
ns <- asNamespace("ledgr")

work <- file.path(out, "stores")
dir.create(work, showWarnings = FALSE)
crossover_experiment <- function(snapshot) {
  strategy <- r_floor_transition
  environment(strategy) <- ns
  ledgr::ledgr_experiment(snapshot, strategy,
    features = ledgr::ledgr_feature_map(
      fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
    risk_chain = ledgr::ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE))
}
workloads <- list(
  crossover_10x7200 = list(
    build = function(db) ledgr::ledgr_snapshot_from_df(r_floor_fixture(10L, 7200L)$bars, db_path = db,
                                                       snapshot_id = "sp_10x7200", price_basis = "split_adjusted"),
    experiment = crossover_experiment, args = list(seed = 20260530L)),
  crossover_500x1260 = list(
    build = function(db) ledgr::ledgr_snapshot_from_df(r_floor_fixture(500L, 1260L)$bars, db_path = db,
                                                       snapshot_id = "sp_500x1260", price_basis = "split_adjusted"),
    experiment = crossover_experiment, args = list(seed = 20260530L)),
  momentum_40x504 = list(
    build = function(db) ws16_momentum_snapshot(40L, 504L, db, "sp_momentum"),
    experiment = function(snapshot) ws16_momentum_experiment(snapshot, 63L),
    args = list(params = list(lookback = 63L, n = 10L), seed = 1L))
)
for (w in names(workloads)) {
  db <- file.path(work, paste0(w, ".duckdb"))
  if (file.exists(db)) unlink(db)
  ledgr::ledgr_snapshot_close(workloads[[w]]$build(db))
}
ids <- c(crossover_10x7200 = "sp_10x7200", crossover_500x1260 = "sp_500x1260", momentum_40x504 = "sp_momentum")

now <- function() as.numeric(Sys.time())
stages <- c(P1 = "ledgr_fold_stage_observe_settle", P2 = "ledgr_fold_stage_decide",
            P3 = "ledgr_fold_stage_plan", P4 = "ledgr_fold_stage_apply", P5 = "ledgr_fold_stage_commit",
            skip_decision = "ledgr_fold_scheduled_skip_decision", skip_plan = "ledgr_fold_scheduled_skip_plan")
one_run <- function(w, r) {
  clk <- new.env()
  clk$t <- setNames(numeric(length(stages) + 1L), c(names(stages), "strategy"))
  clk$calls <- setNames(integer(length(stages)), names(stages))
  clk$first <- NA_real_; clk$last <- NA_real_; clk$env <- c(NA_real_, NA_real_)
  originals <- list()
  wrap <- function(name, make) {
    originals[[name]] <<- get(name, envir = ns)
    unlockBinding(name, ns); assign(name, make(originals[[name]]), envir = ns); lockBinding(name, ns)
  }
  on.exit(for (name in names(originals)) {
    unlockBinding(name, ns); assign(name, originals[[name]], envir = ns); lockBinding(name, ns)
  })
  for (k in names(stages)) local({
    key <- k
    wrap(stages[[key]], function(orig) function(...) {
      t0 <- now()
      if (is.na(clk$first)) clk$first <- t0
      on.exit({
        t1 <- now(); clk$t[[key]] <- clk$t[[key]] + (t1 - t0); clk$calls[[key]] <- clk$calls[[key]] + 1L
        clk$last <- t1
      })
      orig(...)
    })
  })
  wrap("ledgr_call_strategy_fn", function(orig) function(...) {
    t0 <- now(); on.exit(clk$t[["strategy"]] <- clk$t[["strategy"]] + (now() - t0)); orig(...)
  })
  wrap("ledgr_fold_envelope", function(orig) function(...) {
    clk$env[[1L]] <- now(); on.exit(clk$env[[2L]] <- now()); orig(...)
  })
  snapshot <- ledgr::ledgr_snapshot_open(file.path(work, paste0(w, ".duckdb")), ids[[w]], verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- workloads[[w]]$experiment(snapshot)
  t0 <- now()
  bt <- suppressWarnings(do.call(ledgr::ledgr_run, c(list(exp, run_id = paste0("sp-", r)), workloads[[w]]$args)))
  wall <- now() - t0
  n_fills <- nrow(ledgr::ledgr_results(bt, "fills"))
  close(bt)
  tt <- clk$t
  tt[["P2"]] <- tt[["P2"]] - tt[["strategy"]]
  span <- clk$last - clk$first
  timed <- sum(clk$t[names(stages)])
  data.frame(workload = w, round = r, pulses = clk$calls[["P1"]], decided = clk$calls[["P2"]], fills = n_fills,
             wall_s = wall, outside_s = wall - diff(clk$env), setup_s = clk$first - clk$env[[1L]],
             P1_s = tt[["P1"]], P2_s = tt[["P2"]], strategy_s = tt[["strategy"]], P3_s = tt[["P3"]],
             P4_s = tt[["P4"]], P5_s = tt[["P5"]], skip_s = tt[["skip_decision"]] + tt[["skip_plan"]],
             loop_s = span - timed, finalise_s = clk$env[[2L]] - clk$last)
}

rows <- list()
for (r in seq_len(rounds)) for (w in names(workloads)) {
  x <- one_run(w, r)
  rows[[length(rows) + 1L]] <- x
  cat(sprintf("round %d %-18s wall %6.2f s  pulses %d  decided %d  fills %d\n", r, w, x$wall_s, x$pulses,
              x$decided, x$fills))
}
raw <- do.call(rbind, rows)
parts <- c("outside", "setup", "P1", "P2", "strategy", "P3", "P4", "P5", "skip", "loop", "finalise")
summ <- do.call(rbind, lapply(split(raw, raw$workload), function(k) {
  med <- vapply(paste0(parts, "_s"), function(cl) stats::median(k[[cl]]), 0)
  wall <- stats::median(k$wall_s)
  pulses <- k$pulses[[1L]]
  data.frame(workload = k$workload[[1L]], part = parts, median_s = round(med, 4),
             share_pct = round(100 * med / wall, 1), us_per_pulse = round(1e6 * med / pulses, 1),
             pulses = pulses, decided = k$decided[[1L]], fills = k$fills[[1L]], wall_s = round(wall, 3))
}))
rownames(summ) <- NULL
print(summ, row.names = FALSE)
utils::write.csv(raw, file.path(out, "stage_profile_raw.csv"), row.names = FALSE)
utils::write.csv(cbind(pin = pin, summ), file.path(out, "stage_profile.csv"), row.names = FALSE)
