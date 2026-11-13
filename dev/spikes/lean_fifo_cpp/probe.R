# Spike lean_fifo_cpp, probe (spike protocol section 1): what the lean FIFO
# kernel is asked to do on slice2_10x7200, and what one call costs in R.
# Runs the lean loop on the pin library with lean_lot_apply() wrapped: every
# call's (book, input) is kept, and the R kernel is timed per call.
#
#   Rscript dev/spikes/lean_fifo_cpp/probe.R --lib=<pin library> --out=<dir> [--shape=slice2_10x7200]
# Writes <out>/calls_<shape>.rds (the captured calls) and prints the findings.

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
lib <- normalizePath(opt("lib"), winslash = "/", mustWork = TRUE)
out <- opt("out"); dir.create(out, recursive = TRUE, showWarnings = FALSE)
shape <- opt("shape", "slice2_10x7200")
source(file.path(here, "lean_env.R"))
env <- spike_lean_env(lib, repo)
calls <- list()
orig <- env$lean$lean_lot_apply
clock <- function() as.numeric(Sys.time())
acc <- new.env(); acc$s <- 0; acc$simple <- 0L
env$lean$lean_lot_apply <- function(book, input) {
  t0 <- clock(); r <- orig(book, input); acc$s <- acc$s + (clock() - t0)
  calls[[length(calls) + 1L]] <<- list(book = book, input = input)
  r
}
res <- spike_run(env, shape)
saveRDS(calls, file.path(out, paste0("calls_", shape, ".rds")), version = 3L)
m <- vapply(calls, function(x) length(x$input$pos), 1L)
ops <- vapply(calls, function(x) x$input$operation[[1L]], 1L)
simple <- vapply(calls, function(x) !is.null(env$lean$lean_lot_simple(x$book, x$input)), TRUE)
cat(sprintf("%s: %d pulses, %d kernel calls (%d served by the simple path), rows per call median %d max %d, operations %s\n",
            shape, res$pulses, length(calls), sum(simple), as.integer(stats::median(m)), max(m),
            paste(names(table(ops)), table(ops), sep = ":", collapse = " ")))
cat(sprintf("R kernel time in the run %.3f s: %.1f us per call, %.1f us per pulse; fold %.2f s, fills %d\n",
            acc$s, 1e6 * acc$s / length(calls), 1e6 * acc$s / res$pulses, res$fold_s, res$fills))
