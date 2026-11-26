# LDG-3265 diagnostic probe (descriptive): one process with the ffe19415
# library loaded; three function sets swapped into its namespace, each
# byte-compiled with compiler::cmpfun(): "base" (R/history-features.R at the
# cut base 2dee0f98), "cand" (R/debug.R and R/history-features.R at ffe19415)
# and "hybrid" (base, with the candidate's ledgr_history_feature_inputs() and
# ledgr_history_feature_masks()). Arms alternate base, cand, hybrid for 12
# rounds; each round times 5 calls of the custom-only and the zero-admission
# compute; medians per arm. Separates the compute code itself from library
# layout; coarse at the 5 ms level.
#
#   Rscript swap.R --lib=<ffe19415 library> --repo=<worktree>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  lib <- arg("lib"); repo <- arg("repo")
  suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
  ns <- asNamespace("ledgr")
  wl <- new.env()
  sys.source(file.path(repo, "dev/bench/timing/protocols/cut24-feature-1/workloads.R"), envir = wl)
  show <- function(rev, path) {
    f <- tempfile(fileext = ".R")
    writeLines(system2("git", c("-C", shQuote(repo), "show", paste0(rev, ":", path)), stdout = TRUE), f)
    f
  }
  load_set <- function(files) {
    e <- new.env(parent = ns)
    for (f in files) sys.source(f, envir = e)
    fns <- Filter(function(n) is.function(e[[n]]), ls(e, all.names = TRUE))
    out <- lapply(stats::setNames(fns, fns), function(n) { f <- e[[n]]; environment(f) <- ns; compiler::cmpfun(f) })
    list(fns = out, objs = mget(setdiff(ls(e, all.names = TRUE), fns), envir = e))
  }
  put <- function(set) {
    for (n in names(set$fns)) { if (exists(n, envir = ns, inherits = FALSE)) unlockBinding(n, ns); assign(n, set$fns[[n]], envir = ns) }
    for (n in names(set$objs)) { if (exists(n, envir = ns, inherits = FALSE)) unlockBinding(n, ns); assign(n, set$objs[[n]], envir = ns) }
  }
  base <- load_set(show("2dee0f98", "R/history-features.R"))
  cand <- load_set(c(show("ffe19415", "R/debug.R"), show("ffe19415", "R/history-features.R")))
  hyb <- base
  hyb$fns$ledgr_history_feature_inputs <- cand$fns$ledgr_history_feature_inputs
  hyb$fns$ledgr_history_feature_masks <- cand$fns$ledgr_history_feature_masks
  put(cand); ns$local_ledgr_debug(FALSE)
  wd <- tempfile("w"); dir.create(wd)
  fx <- wl$cut24_bar_native("500x1260", wd, ns); sub <- fx$substrate
  cdefs <- wl$cut24_custom_defs(ns); cid <- stats::setNames(cdefs, vapply(cdefs, function(d) d$id, ""))
  zero <- wl$cut24_gap_substrate(ns, keep = 0L)
  zdefs <- wl$cut24_sma_defs(ns, "run"); zid <- stats::setNames(zdefs, vapply(zdefs, function(d) d$id, ""))
  cs <- ns$ledgr_history_calculation_start(sub); ce <- sub$axis[[length(sub$axis)]]
  zs <- ns$ledgr_history_calculation_start(zero); ze <- zero$axis[[length(zero$axis)]]
  one <- function(f) { t0 <- proc.time()[["elapsed"]]; for (i in 1:5) f(); (proc.time()[["elapsed"]] - t0) / 5 }
  arms <- list(base = base, cand = cand, hybrid = hyb)
  res <- list()
  for (rep in 1:12) for (a in names(arms)) {
    put(arms[[a]])
    ns$ledgr_history_compute_feature_series(sub, cid, cs, ce)
    res[[length(res) + 1L]] <- data.frame(arm = a, rep = rep,
      custom = one(function() ns$ledgr_history_compute_feature_series(sub, cid, cs, ce)),
      zero = one(function() ns$ledgr_history_compute_feature_series(zero, zid, zs, ze)))
  }
  r <- do.call(rbind, res)
  print(stats::aggregate(cbind(custom, zero) ~ arm, r, stats::median))
  ledgr::ledgr_snapshot_close(fx$snapshot)
})
