# D3 Section 2 record for the compact-state lean loop (LDG-3219): used and
# allocated record capacity and the R heap peak during terminal
# materialization, on covered workloads including an exception-heavy one.
# Observations, not a gate (D3: no memory ceiling).
#
#   Rscript dev/lean_core/parity/loop_memory.R --lib=<pinned library> --out=<csv>

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)[[1L]])
source(file.path(here, "..", "load.R"))
lean <- lean_core_load(arg("lib"))
ns <- asNamespace("ledgr")
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))
source(file.path(repo, "dev/bench/v0_2_3_ws16_entry/workloads.R"))
work <- file.path(tempdir(), "loop_memory")
dir.create(work, showWarnings = FALSE)

crossover <- function(snapshot) {
  strategy <- r_floor_transition
  environment(strategy) <- ns
  ledgr::ledgr_experiment(snapshot, strategy,
    features = ledgr::ledgr_feature_map(
      fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
    risk_chain = ledgr::ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE))
}
# Exception-heavy: every target differs from the position by less than the
# trade threshold, so every decision cell is an explicit row and no hold or
# fill is built.
exception_heavy <- function(snapshot) {
  strategy <- function(ctx, params) {
    targets <- ctx$hold()
    targets[] <- targets + 1e-12
    targets
  }
  environment(strategy) <- ns
  ledgr::ledgr_experiment(snapshot, strategy, opening = ledgr::ledgr_opening(cash = 1e7),
    cost_model = ledgr::ledgr_cost_zero())
}
cases <- list(
  crossover_10x7200 = list(bars = function() r_floor_fixture(10L, 7200L)$bars, exp = crossover),
  crossover_500x1260 = list(bars = function() r_floor_fixture(500L, 1260L)$bars, exp = crossover),
  fill_heavy_500x1260 = list(bars = ws16_fill_heavy_bars, exp = ws16_fill_heavy_experiment),
  exception_heavy_200x500 = list(bars = function() r_floor_fixture(200L, 500L)$bars, exp = exception_heavy)
)
rows <- list()
for (id in names(cases)) {
  db <- file.path(work, paste0(id, ".duckdb"))
  if (file.exists(db)) unlink(db)
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(cases[[id]]$bars(), db_path = db, snapshot_id = id,
                                                            price_basis = "split_adjusted"))
  snapshot <- ledgr::ledgr_snapshot_open(db, id, verify = TRUE)
  attempt <- lean$lean_loop_run(function() {
    lean$lean_entry$measure <- TRUE
    close(suppressWarnings(ledgr::ledgr_run(cases[[id]]$exp(snapshot), run_id = id, seed = 1L)))
  })
  ledgr::ledgr_snapshot_close(snapshot)
  if (attr(attempt, "lean")$lean_folds != 1L) stop(id, ": the lean loop did not run")
  t <- lean$lean_loop_last_times
  rows[[id]] <- data.frame(workload = id, t(t$capacity), batch_rows = 65536L,
                           publish_peak_mb = round(t$publish_peak_mb, 1), stringsAsFactors = FALSE)
  print(rows[[id]])
}
out <- do.call(rbind, rows)
utils::write.csv(out, arg("out"), row.names = FALSE)
