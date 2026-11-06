# Edge-checks spike runner.
#
#   Rscript run.R --pkg=<pinned tree at d5b3a151> --trees=<scratch dir> --out=<dir> [--rounds=2] [--reps=3]
#
# Builds the edge and gut trees (patch.R), then runs worker.R for the pinned
# and the edge tree on both workloads, alternating tree by tree, for
# `rounds` rounds of `reps` timed runs each. Writes:
#   patches.csv  the checks the edge tree removes
#   parity.csv   ledger, equity and diagnostics of edge and gut against pinned
#   edge.csv     what a strategy returning a missing target raises, per tree
#   timing.csv   median fold loop us per pulse and run wall, per tree and workload

local({
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
  source(file.path(here, "..", "..", "bench", "v0_2_3_ws16_entry", "common.R"))
  assign("ec_here", here, envir = globalenv())
})
source(file.path(ec_here, "patch.R"))
pkg <- normalizePath(ws16_need("pkg"), winslash = "/")
trees <- ws16_out(ws16_need("trees"))
out <- ws16_out(ws16_need("out"))
rounds <- as.integer(ws16_arg("rounds", "2"))
reps <- as.integer(ws16_arg("reps", "3"))
if (!identical(readLines(file.path(pkg, "LEDGR_SOURCE_COMMIT"))[[1L]], "d5b3a151")) {
  stop("source tree is not the d5b3a151 pin", call. = FALSE)
}
edge <- ec_build(pkg, file.path(trees, "edge"), "edge")
gut <- ec_build(pkg, file.path(trees, "gut"), "gut")
ws16_write(ec_inventory(), file.path(out, "patches.csv"))

rscript <- file.path(R.home("bin"), "Rscript")
worker <- function(tree, workload, n, dir) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  log <- file.path(dir, paste0(basename(tree), "_", workload, ".log"))
  status <- system2(rscript, c(file.path(ec_here, "worker.R"), paste0("--tree=", tree),
                               paste0("--workload=", workload), paste0("--reps=", n),
                               paste0("--out=", dir)), stdout = log, stderr = log)
  if (!identical(status, 0L)) stop("worker failed: ", log, call. = FALSE)
}
for (r in seq_len(rounds)) {
  for (w in c("momentum", "fill_heavy")) for (t in c(pkg, edge)) {
    worker(t, w, reps, file.path(out, "rounds", r))
  }
}
worker(gut, "momentum", 1L, file.path(out, "gut"))

round1 <- file.path(out, "rounds", 1)
read_results <- function(dir, label) readRDS(file.path(dir, paste0(label, "_results.rds")))
parity <- do.call(rbind, lapply(list(
  list(tree = "edge", workload = "momentum", dir = round1),
  list(tree = "edge", workload = "fill_heavy", dir = round1),
  list(tree = "gut", workload = "momentum", dir = file.path(out, "gut"))
), function(x) {
  a <- read_results(round1, paste0("pinned_", x$workload))
  b <- read_results(x$dir, paste0(x$tree, "_", x$workload))
  data.frame(tree = x$tree, workload = x$workload, table = names(a),
             rows = vapply(a, nrow, 0L),
             identical_to_pinned = mapply(identical, a, b[names(a)]))
}))
ws16_write(parity, file.path(out, "parity.csv"))

edges <- do.call(rbind, lapply(list.files(round1, "_edge\\.csv$", full.names = TRUE), utils::read.csv))
ws16_write(edges[order(edges$workload, edges$tree), ], file.path(out, "edge.csv"))

raw <- do.call(rbind, lapply(list.files(file.path(out, "rounds"), "_timing\\.csv$", recursive = TRUE,
                                        full.names = TRUE), utils::read.csv))
ws16_write(raw, file.path(out, "timing_raw.csv"))
med <- aggregate(cbind(loop_us_per_pulse, run_wall_s) ~ tree + workload, data = raw, FUN = stats::median)
med$loop_us_per_pulse <- round(med$loop_us_per_pulse, 1)
med$run_wall_s <- round(med$run_wall_s, 3)
med$runs <- aggregate(rep ~ tree + workload, data = raw, FUN = length)$rep
ws16_write(med[order(med$workload, med$tree), ], file.path(out, "timing.csv"))
print(parity)
print(edges)
print(med)
