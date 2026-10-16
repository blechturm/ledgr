#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[[1L]] else ".", winslash = "/", mustWork = TRUE)
runner <- file.path(repo, "inst/design/spikes/history_correction_chain_spike/run.R")
rscript <- file.path(R.home("bin"), "Rscript.exe")
if (!file.exists(rscript)) rscript <- file.path(R.home("bin"), "Rscript")
normal <- tempfile("history-chain-gut-normal-")
gutted <- tempfile("history-chain-gut-broken-")
dir.create(normal)
dir.create(gutted)
on.exit(unlink(c(normal, gutted), recursive = TRUE, force = TRUE), add = TRUE)

run <- function(output, gut) {
  result <- system2(rscript, c(
    shQuote(runner),
    paste0("--package-root=", shQuote(repo)),
    paste0("--output=", shQuote(output)),
    paste0("--gut=", gut)
  ))
  if (!identical(result, 0L)) stop("runner failed", call. = FALSE)
}

run(normal, "none")
run(gutted, "drop_private_supersession")
left <- utils::read.csv(file.path(normal, "timeline.csv"), stringsAsFactors = FALSE)
right <- utils::read.csv(file.path(gutted, "timeline.csv"), stringsAsFactors = FALSE)
changed <- left$state != right$state
cat("GUT_DEMO changed timeline rows:", sum(changed), "\n")
print(left[changed, c("case_id", "day", "state")], row.names = FALSE)
cat("Gutted states:\n")
print(right[changed, c("case_id", "day", "state")], row.names = FALSE)
if (!any(changed)) quit(status = 1L)
