# LDG-3217: runs memory.R in one or two worker processes at once (harness
# processes; no product transport) and samples the process tree.
#
#   Rscript launch.R --lib=<pinned library> --arm=pinned|lean --workers=1|2
#     (--db=<sealed store> | --state=<private build-state.json>) --out=<new dir>
#
# Each worker writes its own phases, components and exact lifetime peak to
# <out>/worker_<i>/. This parent samples the private commit of itself and
# every descendant; tree.csv holds the parent's lifetime peak, each worker's
# lifetime peak, the sampled peak of the tree's sum (a lower bound: it can
# miss a spike shorter than the interval) and the parent's plus the workers'
# lifetime peaks (an upper bound).

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
need <- function(name) arg(name) %||% stop("Missing --", name, "=.", call. = FALSE)
out <- need("out")
if (dir.exists(out) && length(list.files(out))) stop("The output directory must be new and empty.", call. = FALSE)
dir.create(out, recursive = TRUE, showWarnings = FALSE)
workers <- as.integer(need("workers"))
arm <- need("arm")
source_arg <- if (!is.null(arg("state"))) paste0("--state=", arg("state")) else paste0("--db=", need("db"))
rscript <- file.path(R.home("bin"), "Rscript.exe")
for (i in seq_len(workers)) {
  wout <- file.path(out, sprintf("worker_%d", i))
  system2(rscript, c(shQuote(file.path(here, "memory.R")), paste0("--lib=", need("lib")), paste0("--arm=", arm),
                     shQuote(source_arg), paste0("--out=", wout)),
          stdout = file.path(out, sprintf("worker_%d.log", i)), stderr = file.path(out, sprintf("worker_%d.log", i)),
          wait = FALSE)
}

me <- ps::ps_handle()
private_mib <- function(h) tryCatch(ps::ps_memory_info(h)[["pagefile"]] / 2^20, error = function(e) 0)
# Listing descendants is slow on Windows, so it runs once a second; the
# known handles are sampled every 20 ms in between.
handles <- list()
tree_peak <- 0
t0 <- proc.time()[["elapsed"]]
last_scan <- -Inf
repeat {
  now <- proc.time()[["elapsed"]]
  if (now - last_scan >= 1) {
    for (h in tryCatch(ps::ps_children(me, recursive = TRUE), error = function(e) list())) {
      handles[[as.character(ps::ps_pid(h))]] <- h
    }
    last_scan <- now
    alive <- Filter(function(h) tryCatch(ps::ps_is_running(h), error = function(e) FALSE), handles)
    if (length(handles) && !length(alive)) break
    if (!length(handles) && now - t0 > 60) stop("no worker process appeared", call. = FALSE)
  }
  total <- private_mib(me)
  for (h in handles) total <- total + private_mib(h)
  tree_peak <- max(tree_peak, total)
  Sys.sleep(0.02)
}
parent <- ps::ps_memory_info(me)
done <- vapply(seq_len(workers), function(i) file.exists(file.path(out, sprintf("worker_%d", i), "memory_run.csv")), TRUE)
worker_peaks <- vapply(seq_len(workers), function(i) {
  f <- file.path(out, sprintf("worker_%d", i), "memory_phases.csv")
  if (file.exists(f)) max(utils::read.csv(f)$peak_private_mib) else NA_real_
}, 0)
tree <- data.frame(arm = arm, workers = workers, workers_completed = sum(done),
                   parent_peak_private_mib = round(parent[["peak_pagefile"]] / 2^20),
                   worker_peak_private_mib = paste(round(worker_peaks), collapse = ";"),
                   tree_peak_sampled_mib = round(tree_peak),
                   tree_peak_bound_mib = round(parent[["peak_pagefile"]] / 2^20 + sum(worker_peaks)),
                   seconds = round(proc.time()[["elapsed"]] - t0, 1))
utils::write.csv(tree, file.path(out, "tree.csv"), row.names = FALSE)
print(tree, row.names = FALSE)
if (!all(done)) quit(save = "no", status = 1L)
