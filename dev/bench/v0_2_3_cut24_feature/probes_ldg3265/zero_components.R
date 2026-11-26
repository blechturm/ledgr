# LDG-3265 diagnostic probe (descriptive): stage-3 components on the
# zero-admission substrate with the ffe19415 library (gate signature of
# ffe19415: gate(substrate, certified, gated, finite, masks, i, calc),
# finite(substrate, fields, calc)). Per preparation: the finiteness pass once,
# the gate over all instruments, mask construction over all instruments,
# knowledge ranges over all instruments. Medians of 5 blocks; elapsed
# proc.time(); coarse at the 5-10 ms level (Windows clock resolution).
#
#   Rscript zero_components.R --lib=<ffe19415 library> --repo=<worktree>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  lib <- arg("lib"); repo <- arg("repo")
  suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
  ns <- asNamespace("ledgr")
  wl <- new.env()
  sys.source(file.path(repo, "dev/bench/timing/protocols/cut24-feature-1/workloads.R"), envir = wl)
  ns$local_ledgr_debug(FALSE)
  tm <- function(f, n) {
    f(); gc(FALSE); t <- numeric(5)
    for (k in 1:5) { t0 <- proc.time()[["elapsed"]]; for (i in seq_len(n)) f(); t[k] <- (proc.time()[["elapsed"]] - t0) / n }
    stats::median(t)
  }
  zero <- wl$cut24_gap_substrate(ns, keep = 0L)
  defs <- wl$cut24_sma_defs(ns, "run")
  named <- stats::setNames(defs, vapply(defs, function(d) d$id, ""))
  certified <- lapply(named, ns$ledgr_feature_certify)
  gated <- vapply(certified, function(c) c$certification %in% c("builtin", "catalogue"), TRUE)
  fields <- unique(unlist(lapply(certified[gated], function(c) c$declarations$required_fields)))
  start <- ns$ledgr_history_calculation_start(zero); end <- zero$axis[[length(zero$axis)]]
  b <- ns$ledgr_history_feature_bounds(zero, start, end)
  calc <- seq.int(b$from, b$to)
  n <- length(zero$instrument_ids)
  ranges <- lapply(seq_len(n), function(i) ns$ledgr_history_feature_ranges(zero, i, b$from, b$to))
  masks <- lapply(seq_len(n), function(i) {
    r <- ranges[[i]]; ns$ledgr_history_feature_masks(zero, i, r$end[[1]], zero$axis[[r$end[[1]]]])
  })
  finite <- ns$ledgr_history_feature_finite(zero, fields, calc)
  cat("lib", basename(lib), "n_inst", n, "n_ranges", sum(lengths(lapply(ranges, `[[`, "start"))), "defs", length(certified), "\n")
  cat("finite once (ms):", 1000 * tm(function() ns$ledgr_history_feature_finite(zero, fields, calc), 5), "\n")
  cat("gate x n (ms):", 1000 * tm(function() for (i in seq_len(n)) {
    r <- ranges[[i]]
    ns$ledgr_history_feature_gate(zero, certified, gated, finite, masks[[i]], i, seq.int(r$start[[1]], r$end[[1]]))
  }, 3), "\n")
  cat("masks x n (ms):", 1000 * tm(function() for (i in seq_len(n)) {
    r <- ranges[[i]]; ns$ledgr_history_feature_masks(zero, i, r$end[[1]], zero$axis[[r$end[[1]]]])
  }, 3), "\n")
  cat("ranges x n (ms):", 1000 * tm(function() for (i in seq_len(n)) ns$ledgr_history_feature_ranges(zero, i, b$from, b$to), 3), "\n")
})
