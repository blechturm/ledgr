# LDG-2992 prerequisite probe: what share of fold time is accounting after
# Workstream 22 on the Sharadar momentum and equal-weight runs?
#
#   Rscript probe.R <tree> <work_dir> <snapshot> <universe> <out_csv>
#
# Runs both LDG-2976 strategies on a copy of the private snapshot (made in
# <work_dir>, removed afterwards) with fold telemetry sampled on every pulse,
# and writes aggregate seconds per telemetry component. "Accounting" is the
# span the compiled spot-FIFO batch would replace: t_state (lot, position and
# cash application) plus t_event (fill event rows). The kill condition is an
# accounting share below 10 percent of summed pulse time.

args <- commandArgs(trailingOnly = TRUE)
tree <- args[[1L]]; work <- args[[2L]]; source_snapshot <- args[[3L]]; universe <- args[[4L]]; out_csv <- args[[5L]]
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all(tree, quiet = TRUE, compile = FALSE))
source(file.path(tree, "dev/bench/v0_2_2_real_data_scale/fixture.R"))
# Probe-only seam: sample every pulse instead of every 100th.
utils::assignInNamespace("ledgr_run_prepare_telemetry_stride", function(control) 1L, "ledgr")

dir.create(work, recursive = TRUE, showWarnings = FALSE)
snap_path <- file.path(work, "sharadar.duckdb")
stopifnot(file.copy(source_snapshot, snap_path, overwrite = TRUE))
snapshot <- ledgr_snapshot_open(snap_path)
experiment <- function(strategy, features = list()) {
  ledgr_experiment(snapshot, strategy, features = features, universe = ledgr_universe_members(universe),
                   valuation_policy = ledgr_valuation_stale(5), cost_model = ledgr_cost_zero(),
                   opening = ledgr_opening(cash = 1e6))
}
runs <- list(
  momentum = function() ledgr_run(experiment(scale_momentum, list(ledgr_ind_returns(252L))),
                                  params = list(lookback = 252L, n = 20L), run_id = "probe-momentum"),
  equal_weight = function() ledgr_run(experiment(scale_equal_weight), params = list(f = 0.95), run_id = "probe-ew")
)
components <- c("t_pulse", "t_bars", "t_ctx", "t_strat", "t_fill", "t_state", "t_event")
rows <- list()
for (name in names(runs)) {
  bt <- runs[[name]]()
  telemetry <- ledgr:::ledgr_get_run_telemetry(bt$run_id)
  fills <- nrow(ledgr_results(bt, "fills"))
  close(bt)
  sums <- vapply(components, function(k) sum(telemetry[[k]], na.rm = TRUE), numeric(1))
  rows[[name]] <- data.frame(run = name, samples = telemetry$telemetry_samples, fills = fills,
                             component = components, seconds = round(sums, 3),
                             share_of_pulse = round(sums / sums[["t_pulse"]], 4))
}
ledgr_snapshot_close(snapshot)
out <- do.call(rbind, rows)
acc <- do.call(rbind, lapply(split(out, out$run), function(d) {
  data.frame(run = d$run[[1L]], samples = d$samples[[1L]], fills = d$fills[[1L]], component = "accounting",
             seconds = sum(d$seconds[d$component %in% c("t_state", "t_event")]),
             share_of_pulse = round(sum(d$seconds[d$component %in% c("t_state", "t_event")]) /
                                      d$seconds[d$component == "t_pulse"], 4))
}))
out <- rbind(out, acc)
utils::write.csv(out, out_csv, row.names = FALSE)
unlink(work, recursive = TRUE)
print(out[out$component %in% c("t_pulse", "t_fill", "t_state", "t_event", "accounting"), ], row.names = FALSE)
