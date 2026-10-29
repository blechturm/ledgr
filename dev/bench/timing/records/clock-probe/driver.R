# Wall vs CPU clock probe under normal desktop load: A/A, one installed lib,
# 8 alternating pairs x 2 cells, fresh process per measurement.
dir <- "C:/Users/maxth/AppData/Local/Temp/claude/c--Users-maxth-Documents-GitHub-ledgr/78383ced-ac83-4579-b480-65f39660106d/scratchpad/clock_probe"
wt <- "C:/Users/maxth/ledgr-wt/ws2-rng"
commit <- "9b8ee18f"
rscript <- file.path(R.home("bin"), "Rscript.exe")
lib <- file.path(dir, "lib"); src <- file.path(dir, "src"); work <- file.path(dir, "work")
for (d in c(lib, src, work)) dir.create(d, showWarnings = FALSE, recursive = TRUE)
if (!dir.exists(file.path(lib, "ledgr"))) {
  tar <- file.path(dir, "src.tar")
  stopifnot(system2("git", c("-C", wt, "archive", "--format=tar", "-o", tar, commit)) == 0)
  untar(tar, exdir = src)
  stopifnot(system2(file.path(R.home("bin"), "R.exe"), c("CMD", "INSTALL", "--no-test-load", paste0("--library=", lib), src),
    stdout = FALSE, stderr = FALSE) == 0)
}
workloads <- file.path(wt, "dev/bench/timing/protocols/ws2-timing-1/workloads.R")
cells <- list(
  dense_run_seeded = c("dense_scale_50x1260", "run", "seeded"),
  timing_sweep_unseeded = c("timing_scale", "sweep", "unseeded"))
rows <- list()
for (pair in 1:8) {
  for (cell in names(cells)) {
    arms <- if (pair %% 2 == 1) c("A", "B") else c("B", "A")
    for (arm in arms) {
      out <- file.path(dir, sprintf("r_%d_%s_%s.csv", pair, cell, arm))
      code <- system2(rscript, c("--no-init-file", file.path(dir, "child.R"), lib, workloads, cells[[cell]], work, out))
      r <- if (code == 0 && file.exists(out)) read.csv(out) else data.frame(wall = NA, cpu = NA)
      rows[[length(rows) + 1L]] <- data.frame(pair = pair, cell = cell, arm = arm, wall = r$wall, cpu = r$cpu)
      cat(sprintf("%s pair %d %s %s wall %.3f cpu %.3f\n", format(Sys.time(), "%H:%M:%S"), pair, cell, arm, r$wall, r$cpu))
    }
  }
}
res <- do.call(rbind, rows)
write.csv(res, file.path(dir, "results.csv"), row.names = FALSE)
for (cell in names(cells)) {
  x <- res[res$cell == cell, ]
  for (clk in c("wall", "cpu")) {
    a <- x[x$arm == "A", clk]; b <- x[x$arm == "B", clk]
    pr <- x[x$arm == "B", clk][order(x$pair[x$arm == "B"])] / x[x$arm == "A", clk][order(x$pair[x$arm == "A"])]
    cat(sprintf("%-22s %-4s median A %.3f B %.3f ratio-of-medians %.4f | per-pair ratio min %.3f max %.3f sd %.4f | cv A %.3f\n",
      cell, clk, median(a), median(b), median(b) / median(a), min(pr), max(pr), sd(pr), sd(a) / mean(a)))
  }
}
