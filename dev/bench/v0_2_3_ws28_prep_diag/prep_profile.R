# LDG-3217 step 2: where the preparation gap comes from. Lean preparation
# replaces only the substrate step (ledgr_history_substrate_for_experiment:
# axis and bar hydration); features, projection and the fold reader are the
# pinned code on identical matrices. This times the substrate step alone,
# pinned and lean alternating in one process on cut12-prep-1's 500 x 5,040
# store and experiment, checks both substrates are identical, and writes one
# Rprof self-time table per arm.
#
#   Rscript dev/bench/v0_2_3_ws28_prep_diag/prep_profile.R --lib=<pinned lib>
#     --store=<sealed cut12_prep_500x5040 store> --out=<dir> [--rounds=10]

repo <- normalizePath(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE),
  value = TRUE)[[1L]]), winslash = "/")), "..", "..", ".."), winslash = "/")
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) return(default %||% stop("--", name, "= is required", call. = FALSE))
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
out <- arg("out")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
rounds <- as.integer(arg("rounds", "10"))
source(file.path(repo, "dev/lean_core/load.R"))
lean <- lean_core_load(arg("lib"), debug = FALSE)
source(file.path(repo, "dev/bench/timing/protocols/cut12-prep-1/workloads.R"))

store <- file.path(out, "store.duckdb")
if (!file.copy(arg("store"), store, overwrite = TRUE)) stop("could not copy the store")
snapshot <- ledgr::ledgr_snapshot_open(store, "cut12_prep_500x5040", verify = TRUE)
exp <- ledgr::ledgr_experiment(snapshot, cut12_prep_strategy,
                               features = ledgr::ledgr_feature_map(ret = ledgr::ledgr_ind_returns(252L)),
                               schedule = ledgr::ledgr_schedule_month_start(), opening = ledgr::ledgr_opening(cash = 1e6),
                               cost_model = ledgr::ledgr_cost_zero())
ns <- asNamespace("ledgr")
arms <- list(pinned = get("ledgr_history_substrate_for_experiment", envir = ns),
             lean = lean$lean_history_substrate_for_experiment)
strip <- function(x) x[setdiff(names(x), c("history_memo", "feature_projection"))]
ref <- strip(arms$pinned(exp))
stopifnot(identical(strip(arms$lean(exp)), ref))
rm(ref)

times <- list()
for (r in seq_len(rounds)) for (arm in if (r %% 2L) c("pinned", "lean") else c("lean", "pinned")) {
  gc()
  t0 <- proc.time()[["elapsed"]]
  s <- arms[[arm]](exp)
  times[[length(times) + 1L]] <- data.frame(round = r, arm = arm, seconds = proc.time()[["elapsed"]] - t0)
  rm(s)
}
times <- do.call(rbind, times)
utils::write.csv(times, file.path(out, "substrate_times.csv"), row.names = FALSE)
med <- stats::aggregate(seconds ~ arm, times, stats::median)
pairs <- merge(times[times$arm == "lean", c("round", "seconds")], times[times$arm == "pinned", c("round", "seconds")],
               by = "round", suffixes = c("_lean", "_pinned"))
cat("median seconds\n"); print(med, row.names = FALSE)
cat("lean / pinned per round:", round(pairs$seconds_lean / pairs$seconds_pinned, 3), "\n")

for (arm in names(arms)) {
  prof <- file.path(out, paste0("rprof_", arm, ".out"))
  gc()
  utils::Rprof(prof, interval = 0.005)
  for (i in 1:3) s <- arms[[arm]](exp)
  utils::Rprof(NULL)
  rm(s)
  self <- utils::summaryRprof(prof)$by.self
  self <- cbind(fn = rownames(self), self[, c("self.time", "self.pct")], row.names = NULL)
  utils::write.csv(utils::head(self, 20L), file.path(out, paste0("rprof_self_", arm, ".csv")), row.names = FALSE)
  cat("\n", arm, "self time, top 10\n")
  print(utils::head(self, 10L), row.names = FALSE)
}
ledgr::ledgr_snapshot_close(snapshot)
