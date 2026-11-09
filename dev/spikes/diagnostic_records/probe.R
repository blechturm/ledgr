# Probe (spike protocol section 1) for the diagnostic-records spike: what the
# pinned build records, writes and spends on diagnostics, before any design.
#
#   Rscript dev/spikes/diagnostic_records/probe.R <pinned lib> <out dir> [workload,...]
#
# Per workload, one committed run (ledgr_run) and one one-candidate sweep
# (workers = 1) on the pinned build d5b3a151:
#   rows   logical diagnostic rows by kind (clean holds and clean fills from
#          the implicit codec, explicit rows by stage and outcome), physical
#          rows per table, and the in-memory size of the decoded trace
#   writes every ledgr_store_append() during the committed run, split into
#          appends before the first pulse, while pulses remain, and at or after the last
#   cost   wall time and time inside the diagnostic builders (outermost call
#          of each wrapped function, so nested calls are not counted twice),
#          and rows staged against rows the sweep's memory filter keeps

args <- commandArgs(TRUE)
lib <- args[[1L]]
out <- args[[2L]]
dir.create(out, recursive = TRUE, showWarnings = FALSE)
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                              winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(repo, "dev/bench/v0_2_3_ws16_entry/common.R"))
pin <- ws16_load_installed(lib)
source(file.path(repo, "dev/bench/v0_2_3_ws16_entry/workloads.R"))
source(file.path(repo, "dev/bench/v0_2_3_output_freeze/lib.R"))
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))
source(file.path(repo, "dev/lean_core/parity/prep_fixture.R"))
ns <- asNamespace("ledgr")
work <- file.path(tempdir(), "diag_probe")
dir.create(work, showWarnings = FALSE)

fresh <- function(name) {
  db <- file.path(work, paste0(name, ".duckdb"))
  if (file.exists(db)) unlink(db)
  db
}
crossover <- function(n_inst, n_days) function() {
  db <- fresh(sprintf("crossover_%dx%d", n_inst, n_days))
  snapshot <- ledgr::ledgr_snapshot_from_df(r_floor_fixture(n_inst, n_days)$bars, db_path = db,
                                            snapshot_id = "probe", price_basis = "split_adjusted")
  strategy <- r_floor_transition
  environment(strategy) <- ns
  exp <- ledgr::ledgr_experiment(snapshot, strategy,
    features = ledgr::ledgr_feature_map(
      fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
    risk_chain = ledgr::ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE))
  list(db = db, snapshot = snapshot, exp = exp, params = list(), seed = 20260530L)
}
momentum <- function(n_inst, n_days) function() {
  db <- fresh(sprintf("momentum_%dx%d", n_inst, n_days))
  snapshot <- ws16_momentum_snapshot(n_inst, n_days, db, "probe")
  list(db = db, snapshot = snapshot, exp = ws16_momentum_experiment(snapshot, 63L),
       params = list(lookback = 63L, n = 10L), seed = 1L)
}
workloads <- list(
  crossover_10x7200 = crossover(10L, 7200L),
  crossover_500x1260 = crossover(500L, 1260L),
  momentum_40x504 = momentum(40L, 504L),
  momentum_500x1260 = momentum(500L, 1260L),
  # membership exits, relisting, late-known inactivity, missing bars
  prep_fixture = function() {
    db <- fresh("prep_fixture")
    fx <- lc_prep_fixture(db)
    list(db = db, snapshot = fx$snapshot, exp = fx$exp, seed = 1L,
         params = utils::modifyList(lc_prep_fixture_params, list(trade = TRUE, lookback = 10L, n = 3L)))
  },
  # risk cuts, spread costs, an opening position
  dense_risk_features = function() {
    db <- fresh("dense_risk_features")
    fx <- a0_fx_dense_risk_features(db)
    list(db = db, snapshot = fx$snapshot, exp = fx$exp, seed = fx$seed,
         params = list(qty = 30, qty_b = 40, cap = 0.3))
  }
)
ids <- if (length(args) >= 3L) strsplit(args[[3L]], ",")[[1L]] else names(workloads)

now <- function() as.numeric(Sys.time())
clk <- new.env()
reset <- function() {
  clk$diag_s <- 0; clk$depth <- 0L; clk$staged <- 0; clk$kept <- 0; clk$p5 <- 0L
  clk$appends <- list()
}
wrap <- function(name, make) {
  orig <- get(name, envir = ns)
  unlockBinding(name, ns); assign(name, make(orig), envir = ns); lockBinding(name, ns)
}
diag_fns <- c("ledgr_fold_diagnostic_segment", "ledgr_fold_diagnostic_rows", "ledgr_fold_staging_write",
              "ledgr_fold_flush_pulse_block", "ledgr_diagnostic_clean_fill", "ledgr_diagnostic_clean_hold",
              "ledgr_diagnostic_implicit_block", "ledgr_diagnostic_implicit_hold_block")
for (name in diag_fns) wrap(name, function(orig) function(...) {
  if (clk$depth > 0L) return(orig(...))
  clk$depth <- 1L
  t0 <- now()
  on.exit({ clk$diag_s <- clk$diag_s + (now() - t0); clk$depth <- 0L })
  orig(...)
})
wrap("ledgr_fold_staging_write", function(orig) function(fold_state, rows, logical_offset) {
  clk$staged <- clk$staged + rows$n
  orig(fold_state, rows, logical_offset)
})
wrap("ledgr_memory_diagnostic_keep", function(orig) function(diagnostics, n = NULL) {
  k <- orig(diagnostics, n)
  clk$kept <- clk$kept + sum(k)
  k
})
wrap("ledgr_fold_stage_commit", function(orig) function(...) {
  clk$p5 <- clk$p5 + 1L
  orig(...)
})
wrap("ledgr_store_append", function(orig) function(con, name, value) {
  t0 <- now()
  r <- orig(con, name, value)
  clk$appends[[length(clk$appends) + 1L]] <- data.frame(table = name, rows = NROW(value), seconds = now() - t0,
                                                        after_pulse = clk$p5)
  r
})

rows_out <- list(); writes_out <- list(); cost_out <- list()
for (id in ids) {
  w <- workloads[[id]]()
  on.exit(ledgr::ledgr_snapshot_close(w$snapshot), add = TRUE)
  # one-candidate sweep, memory sink
  reset()
  grid <- ledgr::ledgr_grid_named(only = list(strategy = c(w$params, list(probe = 1))))
  t0 <- now()
  sw <- suppressWarnings(ledgr::ledgr_sweep(w$exp, grid, seed = w$seed))
  cost_out[[length(cost_out) + 1L]] <- data.frame(workload = id, path = "sweep_w1", wall_s = now() - t0,
    diag_s = clk$diag_s, staged_rows = clk$staged, kept_rows = clk$kept, pulses = clk$p5)
  # committed run, durable store
  reset()
  t0 <- now()
  bt <- suppressWarnings(ledgr::ledgr_run(w$exp, params = c(w$params, list(probe = 1)), run_id = "probe",
                                          seed = w$seed))
  wall <- now() - t0
  pulses <- clk$p5
  cost_out[[length(cost_out) + 1L]] <- data.frame(workload = id, path = "run", wall_s = wall,
    diag_s = clk$diag_s, staged_rows = clk$staged, kept_rows = NA_real_, pulses = pulses)
  ap <- do.call(rbind, clk$appends)
  if (!is.null(ap)) {
    ap$phase <- ifelse(ap$after_pulse == 0L, "before_first_pulse", ifelse(ap$after_pulse < pulses, "during_pulses", "at_end"))
    agg <- aggregate(cbind(appends = 1, rows = ap$rows, seconds = ap$seconds) ~ table + phase, data = ap, FUN = sum)
    writes_out[[length(writes_out) + 1L]] <- cbind(workload = id, agg)
  }
  trace <- ledgr::ledgr_results(bt, "diagnostics")
  close(bt)
  con <- DBI::dbConnect(duckdb::duckdb(), w$db, read_only = TRUE)
  q <- function(sql) DBI::dbGetQuery(con, sql)
  holds <- q("SELECT count(*) AS n FROM run_diagnostic_implicit WHERE run_id = 'probe' AND execution_seq IS NULL")$n
  fills <- q("SELECT count(*) AS n FROM run_diagnostic_implicit WHERE run_id = 'probe' AND execution_seq IS NOT NULL")$n
  explicit <- q("SELECT stage, outcome, count(*) AS n FROM run_diagnostics WHERE run_id = 'probe' GROUP BY 1, 2")
  implicit_tbl <- q("SELECT * FROM run_diagnostic_implicit WHERE run_id = 'probe'")
  explicit_tbl <- q("SELECT * FROM run_diagnostics WHERE run_id = 'probe'")
  DBI::dbDisconnect(con, shutdown = TRUE)
  decided <- length(unique(trace$ts_utc[trace$stage == "decision"]))
  kinds <- rbind(
    data.frame(kind = "clean_hold (implicit)", logical_rows = holds),
    data.frame(kind = "clean_fill (implicit, decision + execution)", logical_rows = 2 * fills),
    data.frame(kind = paste0("explicit ", explicit$stage, "/", explicit$outcome), logical_rows = explicit$n))
  kinds$share_pct <- round(100 * kinds$logical_rows / nrow(trace), 2)
  rows_out[[length(rows_out) + 1L]] <- cbind(workload = id, pulses = pulses, decided_pulses = decided,
    logical_total = nrow(trace), kinds,
    implicit_physical_rows = nrow(implicit_tbl), explicit_physical_rows = nrow(explicit_tbl),
    implicit_mb = round(as.numeric(utils::object.size(implicit_tbl)) / 2^20, 2),
    explicit_mb = round(as.numeric(utils::object.size(explicit_tbl)) / 2^20, 2),
    decoded_trace_mb = round(as.numeric(utils::object.size(trace)) / 2^20, 2))
  cat(sprintf("%-20s logical %d (holds %.1f%%), sweep staged %d kept %d, run diag %.2f of %.2f s\n", id,
              nrow(trace), 100 * holds / nrow(trace), cost_out[[length(cost_out) - 1L]]$staged_rows,
              cost_out[[length(cost_out) - 1L]]$kept_rows, clk$diag_s, wall))
}
utils::write.csv(do.call(rbind, rows_out), file.path(out, "probe_rows.csv"), row.names = FALSE)
utils::write.csv(do.call(rbind, writes_out), file.path(out, "probe_writes.csv"), row.names = FALSE)
utils::write.csv(do.call(rbind, cost_out), file.path(out, "probe_cost.csv"), row.names = FALSE)
