# Spike lean_plan_cpp, probe (spike protocol section 1): what the lean
# planner (lean_plan_pulse(), dev/lean_core/plan.R) is asked to do on a
# workload, and what one call costs in R. Runs the lean loop on the pin
# library with lean_plan_pulse() wrapped: every call's arguments and result
# are kept, and the R planner is timed per call.
#
#   Rscript dev/spikes/lean_plan_cpp/probe.R --lib=<pin library> --out=<dir> [--shape=slice2_10x7200]
# Writes <out>/plan_calls_<shape>.rds and prints the findings.

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
lib <- normalizePath(opt("lib"), winslash = "/", mustWork = TRUE)
out <- opt("out", tempdir()); dir.create(out, recursive = TRUE, showWarnings = FALSE)
shape <- opt("shape", "slice2_10x7200")
source(file.path(repo, "dev/spikes/lean_fifo_cpp/lean_env.R"))
env <- spike_lean_env(lib, repo)
calls <- list()
orig <- env$lean$lean_plan_pulse
clock <- function() as.numeric(Sys.time())
acc <- new.env(); acc$s <- 0
env$lean$lean_plan_pulse <- function(...) {
  a <- list(...)
  t0 <- clock(); r <- orig(...); acc$s <- acc$s + (clock() - t0)
  calls[[length(calls) + 1L]] <<- list(args = a, result = r)
  r
}
res <- spike_run(env, shape)
saveRDS(calls, file.path(out, paste0("plan_calls_", shape, ".rds")), version = 3L)
n <- vapply(calls, function(x) length(x$args$actionable_k), 1L)
fills <- vapply(calls, function(x) length(x$result$fill$k), 1L)
rej <- vapply(calls, function(x) length(x$result$rejection$k), 1L)
attrs <- unique(unlist(lapply(calls[seq_len(min(50L, length(calls)))], function(x) {
  c(vapply(x$args[c("context_pos", "target_qty", "position", "actionable_k", "member", "cash", "instrument_ids")],
           function(v) paste(names(attributes(v)), collapse = "+"), ""),
    exec_ts = paste(class(x$args$execution$exec_ts), collapse = "+"))
})))
cat(sprintf("%s: %d pulses, %d planner calls, actionable per call median %d max %d, fills per call median %d, rejections total %d\n",
            shape, res$pulses, length(calls), as.integer(stats::median(n)), max(n), as.integer(stats::median(fills)), sum(rej)))
cat(sprintf("R planner time in the run %.3f s: %.1f us per call, %.1f us per pulse; fold %.2f s\n",
            acc$s, 1e6 * acc$s / max(1L, length(calls)), 1e6 * acc$s / res$pulses, res$fold_s))
cat("argument attributes seen:", paste(attrs, collapse = " | "), "\n")
