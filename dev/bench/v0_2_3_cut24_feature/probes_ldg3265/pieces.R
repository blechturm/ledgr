# LDG-3265 diagnostic probe (descriptive, not a decision statistic): the
# pieces of one zero-admission or custom-only preparation of protocol
# cut24-feature-1, timed with one installed library in one fresh process.
# Each figure is the median over 5 (zero) or 7 (custom) blocks of n calls,
# elapsed proc.time() per call; Windows' clock resolution is about 15 ms per
# block, so figures are coarse at the 5-10 ms level.
#
#   Rscript pieces.R --lib=<installed ledgr library> --case=<zero|custom> --repo=<worktree>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  lib <- arg("lib"); case <- arg("case"); repo <- arg("repo")
  suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
  ns <- asNamespace("ledgr")
  wl <- new.env()
  sys.source(file.path(repo, "dev/bench/timing/protocols/cut24-feature-1/workloads.R"), envir = wl)
  if (exists("local_ledgr_debug", envir = ns)) ns$local_ledgr_debug(FALSE)
  blocks <- if (identical(case, "zero")) 5L else 7L
  tm <- function(f, n) {
    f(); gc(FALSE); t <- numeric(blocks)
    for (k in seq_len(blocks)) { t0 <- proc.time()[["elapsed"]]; for (i in seq_len(n)) f(); t[k] <- (proc.time()[["elapsed"]] - t0) / n }
    stats::median(t)
  }
  if (identical(case, "zero")) {
    sub <- wl$cut24_gap_substrate(ns, keep = 0L)
    defs <- wl$cut24_sma_defs(ns, "run")
  } else {
    wd <- tempfile("w"); dir.create(wd)
    fx <- wl$cut24_bar_native("500x1260", wd, ns)
    sub <- fx$substrate
    defs <- wl$cut24_custom_defs(ns)
  }
  id <- stats::setNames(defs, vapply(defs, function(d) d$id, ""))
  start <- ns$ledgr_history_calculation_start(sub); end <- sub$axis[[length(sub$axis)]]
  m <- ns$ledgr_history_compute_feature_series(sub, id, start, end)
  v <- ns$ledgr_feature_engine_version()
  res <- c(
    version = tm(function() ns$ledgr_feature_engine_version(), 10),
    compute = tm(function() ns$ledgr_history_compute_feature_series(sub, id, start, end), 3),
    projection = tm(function() ns$ledgr_projection_from_feature_matrix(feature_matrix = m, universe = sub$instrument_ids,
      pulses_posix = sub$axis, feature_engine_version = v, alias_index = NULL), 3))
  if (identical(case, "custom")) {
    fp <- stats::setNames(defs, vapply(defs, ns$ledgr_feature_def_fingerprint, ""))
    res <- c(res,
      run_prep = tm(wl$cut24_prepare(ns, "run", sub, defs), 3),
      sweep_prep = tm(wl$cut24_prepare(ns, "sweep", sub, defs), 3),
      payload = tm(function() ns$ledgr_history_precompute_payload(fp, sub, calculation_start = start, calculation_end = end), 3))
    ledgr::ledgr_snapshot_close(fx$snapshot)
  }
  cat(case, basename(lib), sprintf("%s=%.4f", names(res), res), "\n")
})
