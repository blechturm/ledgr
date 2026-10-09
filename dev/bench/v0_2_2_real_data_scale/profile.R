# Fold-time shares on the scale fixture (Cut 11 LDG-2986, LDG-2988, LDG-2990).
#
#   Rscript profile.R <repo> <out_dir> [--size=n_inst,n_days,n_mem]
#
# Profiles the fixture momentum run, the equal-weight run and the three-candidate
# sweep with Rprof and writes, per workload, the total and self time of every
# function (by_total.csv, by_self.csv) and the elapsed seconds (elapsed.csv).
# The shares decide subchanges the materiality rule would otherwise admit on
# aggregate: a subchange whose code is below 5 percent of its workload cannot
# improve that workload by 5 percent and closes as measured and rejected.

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[length(hit)]]) else default
}
repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
out_dir <- args[[2L]]
size <- as.integer(strsplit(opt("size", "800,1260,300"), ",", fixed = TRUE)[[1L]])
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
source(file.path(here, "fixture.R"))

work <- file.path(out_dir, "work")
dir.create(work, showWarnings = FALSE)
snap_path <- file.path(work, "scale.duckdb")
unlink(snap_path)
snapshot <- scale_fixture_snapshot(snap_path, size[[1L]], size[[2L]], size[[3L]])
experiment <- function(strategy, features = list()) {
  ledgr_experiment(snapshot, strategy, features = features, universe = ledgr_universe_members("U"),
                   valuation_policy = ledgr_valuation_stale(5), cost_model = ledgr_cost_zero(),
                   opening = ledgr_opening(cash = 1e6))
}

profile <- function(name, expr) {
  prof <- file.path(work, paste0(name, ".prof"))
  t0 <- Sys.time()
  Rprof(prof, interval = 0.005)
  force(expr)
  Rprof(NULL)
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  s <- summaryRprof(prof)
  write_tab <- function(tab, file) {
    utils::write.csv(data.frame(fn = rownames(tab), tab, row.names = NULL, check.names = FALSE),
                     file.path(out_dir, paste0(name, "_", file)), row.names = FALSE)
  }
  write_tab(s$by.total, "by_total.csv")
  write_tab(s$by.self, "by_self.csv")
  data.frame(workload = name, elapsed = elapsed, sampled = s$sampling.time)
}

elapsed <- rbind(
  profile("momentum", ledgr_run(experiment(scale_momentum, list(ledgr_ind_returns(60L))),
                                params = list(lookback = 60L, n = 20L), run_id = "p-momentum")),
  profile("equal_weight", ledgr_run(experiment(scale_equal_weight), params = list(f = 0.95), run_id = "p-ew")),
  profile("sweep", ledgr_sweep(experiment(scale_equal_weight), ledgr_strategy_grid(f = c(0.9, 0.95, 0.99)), seed = 1L))
)
utils::write.csv(elapsed, file.path(out_dir, "elapsed.csv"), row.names = FALSE)
unlink(work, recursive = TRUE)
cat("PROFILE_OK", out_dir, "\n")
