# One measurement in a fresh process: wall and process CPU time around the
# ws2-timing-1 timed section. Usage: Rscript child.R <lib> <workloads.R> <workload> <path> <seed_state> <work_dir> <out_csv>
a <- commandArgs(TRUE)
suppressPackageStartupMessages(library(ledgr, lib.loc = a[[1]]))
env <- new.env()
sys.source(a[[2]], envir = env)
cpu_now <- function() { p <- proc.time(); p[["user.self"]] + p[["sys.self"]] }
env$ws2_measure <- function(fixture, args, work_dir) {
  fx <- fixture(file.path(work_dir, sprintf("probe_%d.duckdb", Sys.getpid())))
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  seeded <- identical(args$seed_state, "seeded")
  retain <- ledgr_sweep_retention(returns = "completed", trades = "closed")
  options(ledgr.interrupt = FALSE)
  sweep_path <- function() ledgr_sweep(fx$exp, fx$grid, seed = if (seeded) fx$seed else NULL, retain = retain)
  sw <- suppressWarnings(sweep_path())
  run_path <- function(tag) {
    for (i in seq_len(nrow(sw))) {
      close(suppressWarnings(ledgr_run(fx$exp, params = sw$params[[i]], feature_params = sw$feature_params[[i]],
        run_id = paste("p", tag, sw$candidate_id[[i]], sep = "-"),
        seed = if (seeded) sw$execution_seed[[i]] else NULL)))
    }
  }
  run_path("warm")
  invisible(gc())
  c0 <- cpu_now(); t0 <- as.numeric(Sys.time())
  if (identical(args$path, "run")) run_path("timed") else invisible(suppressWarnings(sweep_path()))
  t1 <- as.numeric(Sys.time()); c1 <- cpu_now()
  c(wall = t1 - t0, cpu = c1 - c0)
}
r <- get(a[[3]], envir = env)(list(path = a[[4]], seed_state = a[[5]]), a[[6]])
write.csv(data.frame(wall = r[["wall"]], cpu = r[["cpu"]]), a[[7]], row.names = FALSE)
