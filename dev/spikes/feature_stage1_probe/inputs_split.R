# Where input treatment goes, pin vs c2: Rprof samples inside
# ledgr_history_feature_inputs split into the cutoff masks (expected-session
# and terminal planes) and the per-field carry and extraction, for the run's
# SMA 5/10 compute step on one crossover shape.
#   Rscript inputs_split.R --lib=<pinned library> --shape=crossover_1166x252 --reps=5 --out=<csv>
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) return(default)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
.libPaths(c(arg("lib"), .libPaths()))
library(ledgr)
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(here, "patches.R"))
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))
shape <- arg("shape", "crossover_1166x252")
reps <- as.integer(arg("reps", "5"))
work <- file.path(tempdir(), "feature_stage1_split")
dir.create(work, showWarnings = FALSE)
dims <- as.integer(strsplit(sub("^crossover_", "", shape), "x")[[1L]])
db <- file.path(work, paste0(shape, ".duckdb"))
ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(r_floor_fixture(dims[[1L]], dims[[2L]])$bars,
  db_path = db, snapshot_id = "p", price_basis = "split_adjusted"))
snapshot <- ledgr::ledgr_snapshot_open(db, "p", verify = TRUE)
sma <- function(n) ledgr::ledgr_ind_ttr("SMA", input = "close", id = paste0("sma_", n), n = as.integer(n))
exp <- ledgr::ledgr_experiment(snapshot, function(ctx, params) ctx$hold(),
  features = ledgr::ledgr_feature_map(sma_5 = sma(5), sma_10 = sma(10)),
  opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero())
substrate <- ns$ledgr_history_substrate_for_experiment(exp)
start <- ns$ledgr_history_calculation_start(substrate)
defs <- lapply(c(5, 10), function(n) ns$ledgr_precompute_feature_def_from_indicator(sma(n)))
names(defs) <- c("sma_5", "sma_10")
buckets <- c(masks = "ledgr_history_substrate_expected_at|ledgr_history_substrate_terminal_planes",
             carry = "ledgr_history_input_carry_calculation",
             inputs_rest = "ledgr_history_feature_inputs|c2_inputs")
rows <- list()
for (arm in c("pin", "c2")) {
  use_arm(arm)
  ns$ledgr_history_compute_feature_series(substrate, defs, calculation_start = start)
  prof <- file.path(work, paste0(arm, ".out"))
  utils::Rprof(prof, interval = 0.002)
  t0 <- proc.time()[["elapsed"]]
  for (r in seq_len(reps)) ns$ledgr_history_compute_feature_series(substrate, defs, calculation_start = start)
  wall <- (proc.time()[["elapsed"]] - t0) / reps
  utils::Rprof(NULL)
  lines <- readLines(prof)[-1L]
  cat_of <- vapply(lines, function(s) {
    for (k in names(buckets)) if (grepl(paste0("\"(", buckets[[k]], ")\""), s)) return(k)
    "outside inputs"
  }, "", USE.NAMES = FALSE)
  share <- table(factor(cat_of, levels = c(names(buckets), "outside inputs"))) / length(cat_of)
  rows[[arm]] <- data.frame(shape = shape, arm = arm, bucket = names(share), share = round(as.numeric(share), 3),
                            seconds = round(as.numeric(share) * wall, 3), wall_s = round(wall, 3),
                            samples = length(cat_of), stringsAsFactors = FALSE)
}
use_arm("pin")
ledgr::ledgr_snapshot_close(snapshot)
out <- do.call(rbind, rows)
print(out, row.names = FALSE)
utils::write.csv(out, arg("out"), row.names = FALSE)
