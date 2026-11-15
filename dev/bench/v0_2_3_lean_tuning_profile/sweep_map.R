# Whole-sweep cost map of the lean loop (after Cut 18). Measurement only.
# The sweep counterpart of cost_map.R, with the same cells (cells.R) plus the
# sweep's own.
#
#   Rscript dev/bench/v0_2_3_lean_tuning_profile/sweep_map.R --lib=<pinned library>
#     --out=<dir> [--shapes=10x7200,500x1260] [--reps=3] [--prof-reps=10x7200:1,500x1260:2]
#
# Workload: the crossover descriptor (descriptors.R) with its two SMA windows
# as feature parameters, swept over 8 candidates (fast 3, 5, 8, 12 x slow 20,
# 40) on one worker, default retention. A fresh copy of the sealed snapshot
# per sweep, gc() before each, one warm-up sweep. The pin runs each shape once
# first: its result signature is the reference and its clock is reported
# beside the lean one. Lean: debug off, inert hooks, byte-compiled.
# Clocks: the whole ledgr_sweep() call and the summed pulse loops of its
# candidates. Attribution: Rprof (5 ms) as in cost_map.R; each cell's estimate
# is its sample share times the sweep clock, loop cells reconcile to the
# summed loop clock. Samples that fall to "sweep: other" or "run: other" are
# also tallied by their innermost ledgr frame (other_frames.csv), so the
# residual is named.

args <- commandArgs(trailingOnly = TRUE)
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) { if (is.null(default)) stop("--", name, "= is required", call. = FALSE); return(default) }
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(repo, "dev/lean_core/load.R"))
lean <- lean_core_load(arg("lib"), debug = FALSE)
for (f in ls(lean, all.names = TRUE)) {
  g <- get(f, envir = lean)
  if (is.function(g) && identical(environment(g), lean)) assign(f, compiler::cmpfun(g), envir = lean)
}
ns <- asNamespace("ledgr")
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))
source(file.path(here, "descriptors.R"))
source(file.path(here, "cells.R"))
out <- arg("out")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
shapes <- strsplit(arg("shapes", "10x7200,500x1260"), ",")[[1L]]
reps <- as.integer(arg("reps", "3"))
kv <- strsplit(strsplit(arg("prof-reps", "10x7200:1,500x1260:2"), ",")[[1L]], ":")
prof_reps <- stats::setNames(as.integer(vapply(kv, `[[`, "", 2L)), vapply(kv, `[[`, "", 1L))
now <- function() proc.time()[["elapsed"]]
writeLines(c(
  paste("command:", paste(commandArgs(), collapse = " ")),
  paste("head:", system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE)),
  paste("dev/lean_core changes against head:", length(system2("git", c("-C", repo, "status", "--porcelain", "dev/lean_core"), stdout = TRUE))),
  paste("pin:", lean$.lean_pin), paste("R:", R.version.string),
  paste("power plan:", paste(tryCatch(system2("powercfg", "/getactivescheme", stdout = TRUE), error = function(e) "unknown"), collapse = " ")),
  paste("process affinity:", paste(tryCatch(system2("powershell", c("-NoProfile", "-Command",
    sprintf("(Get-Process -Id %d).ProcessorAffinity", Sys.getpid())), stdout = TRUE), error = function(e) "unknown"), collapse = " ")),
  paste("started:", format(Sys.time(), tz = "UTC", usetz = TRUE))), file.path(out, "identity.txt"))

work <- file.path(tempdir(), "sweep_map")
dir.create(work, showWarnings = FALSE)
desc <- lapply(stats::setNames(shapes, shapes), bench_descriptor)
sealed <- list()
for (s in shapes) {
  if (!identical(desc[[s]]$family, "crossover")) stop("sweep_map.R takes crossover descriptors only: ", s, call. = FALSE)
  sealed[[s]] <- file.path(work, paste0(s, ".duckdb"))
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(desc[[s]]$bars(),
    db_path = sealed[[s]], snapshot_id = paste0("sm_", s), price_basis = "split_adjusted"))
}
experiment <- function(snapshot) {
  strategy <- r_floor_transition
  environment(strategy) <- ns
  ledgr::ledgr_experiment(snapshot, strategy,
    features = ledgr::ledgr_feature_map(
      fast = ledgr::ledgr_ind_ttr("SMA", input = "close", n = ledgr::ledgr_param("fast_n")),
      slow = ledgr::ledgr_ind_ttr("SMA", input = "close", n = ledgr::ledgr_param("slow_n"))),
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
    risk_chain = ledgr::ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE))
}
grid <- ledgr::ledgr_grid_cross(features = ledgr::ledgr_feature_grid(fast_n = c(3L, 5L, 8L, 12L), slow_n = c(20L, 40L)))
# The result signature: every column but identifiers and clocks.
signature <- function(sw) {
  x <- as.data.frame(sw, stringsAsFactors = FALSE)
  x <- x[, !grepl("^t_|time|elapsed|sweep_id|^run_id$|_at$|_sec$|_ms$", names(x)), drop = FALSE]
  rlang::hash(x)
}

run_sweep <- function(arm, shape, profile = FALSE) {
  db <- file.path(work, "run.duckdb")
  if (file.exists(db)) unlink(db)
  file.copy(sealed[[shape]], db)
  snapshot <- ledgr::ledgr_snapshot_open(db, paste0("sm_", shape), verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  exp <- experiment(snapshot)
  clock <- new.env(parent = emptyenv())
  clock$pulses <- 0; clock$folds <- 0L
  if (!identical(get("ledgr_fold_envelope", envir = ns), lean$lean_pin_envelope)) stop("the pin's bindings are not in place", call. = FALSE)
  if (arm == "lean") {
    restore_lean <- lean$lean_loop_install(hooks = FALSE)
    on.exit(restore_lean(), add = TRUE)
    lean$lean_hooks <- utils::modifyList(lean$lean_hooks_inert(), list(fold_end = function(stats) {
      clock$pulses <- clock$pulses + stats$pulses; clock$folds <- clock$folds + 1L }))
  }
  prof <- file.path(work, "sweep.rprof")
  invisible(gc())
  if (profile) Rprof(prof, interval = 0.005)
  t0 <- now()
  sw <- ledgr::ledgr_sweep(exp, grid, seed = 20260530L)
  whole <- now() - t0
  if (profile) Rprof(NULL)
  if (arm == "lean" && clock$folds != nrow(sw)) stop("lean folds ", clock$folds, " for ", nrow(sw), " candidates", call. = FALSE)
  if (!all(as.character(sw$status) == "DONE")) stop(arm, " sweep on ", shape, ": a candidate did not complete", call. = FALSE)
  row <- data.frame(arm = arm, shape = shape, candidates = nrow(sw), sweep_s = whole,
    loop_s = if (arm == "lean") clock$pulses else NA_real_, signature = signature(sw), stringsAsFactors = FALSE)
  list(row = row, prof = if (profile) readLines(prof) else NULL)
}

# --- the pin once per shape: the reference signature and its clock -----------
pin <- do.call(rbind, lapply(shapes, function(s) { x <- run_sweep("pin", s)$row; cat(sprintf("pin %-9s sweep %.2f s\n", s, x$sweep_s)); x }))
for (s in shapes) run_sweep("lean", s)   # warm-up
clock <- list()
for (r in seq_len(reps)) for (s in shapes) {
  x <- run_sweep("lean", s)$row
  x$rep <- r
  clock[[length(clock) + 1L]] <- x
  cat(sprintf("rep %d %-9s sweep %.2f  loops %.2f s\n", r, s, x$sweep_s, x$loop_s))
}
clock <- do.call(rbind, clock)
bad <- shapes[vapply(shapes, function(s) any(clock$signature[clock$shape == s] != pin$signature[pin$shape == s]), logical(1L))]
if (length(bad)) stop("lean sweep results differ from the pin's on: ", paste(bad, collapse = ", "), call. = FALSE)
utils::write.csv(rbind(transform(pin, rep = 0L), clock), file.path(out, "clock_raw.csv"), row.names = FALSE)
med <- stats::aggregate(cbind(sweep_s, loop_s) ~ shape + candidates, clock, stats::median)
med$pin_sweep_s <- pin$sweep_s[match(med$shape, pin$shape)]

# --- attribution --------------------------------------------------------------
samples <- list(); others <- list()
for (s in shapes) for (r in seq_len(prof_reps[[s]])) {
  lines <- run_sweep("lean", s, profile = TRUE)$prof
  lines <- lines[!grepl("^sample.interval|^#", lines)]
  stacks <- lapply(strsplit(lines, " ", fixed = TRUE), function(x) gsub('"', "", x))
  cells <- vapply(stacks, cell_of, character(1L))
  keep <- cells != "outside the run"
  tab <- table(cells[keep])
  samples[[length(samples) + 1L]] <- data.frame(shape = s, cell = names(tab), samples = as.integer(tab))
  resid <- keep & cells %in% c("sweep: other", "run: other")
  if (any(resid)) {
    frame <- vapply(stacks[resid], function(x) { h <- x[startsWith(x, "ledgr_")]; if (length(h)) h[[1L]] else "(base only)" }, "")
    ft <- table(paste(cells[resid], frame, sep = " | "))
    others[[length(others) + 1L]] <- data.frame(shape = s, cell_frame = names(ft), samples = as.integer(ft))
  }
}
samples <- stats::aggregate(samples ~ shape + cell, do.call(rbind, samples), sum)
cells <- merge(samples, med, by = "shape")
cells$share_of_sweep <- cells$samples / stats::ave(cells$samples, cells$shape, FUN = sum)
cells$est_sweep_s <- cells$share_of_sweep * cells$sweep_s
in_loop <- is_loop_cell(cells$cell)
loop_samples <- stats::ave(ifelse(in_loop, cells$samples, 0L), cells$shape, FUN = sum)
cells$est_loop_s <- ifelse(in_loop, cells$samples / loop_samples * cells$loop_s, NA_real_)
cells$resolution <- ifelse(cells$samples < 10L, "rough", "measured")
cells <- cells[order(cells$shape, -cells$samples), c("shape", "cell", "samples", "resolution", "share_of_sweep", "est_sweep_s", "est_loop_s")]
utils::write.csv(cells, file.path(out, "cells.csv"), row.names = FALSE)
if (length(others)) {
  others <- stats::aggregate(samples ~ shape + cell_frame, do.call(rbind, others), sum)
  utils::write.csv(others[order(others$shape, -others$samples), ], file.path(out, "other_frames.csv"), row.names = FALSE)
}
reconcile <- do.call(rbind, lapply(split(cells, cells$shape), function(x) {
  m <- med[med$shape == x$shape[[1L]], ]
  loop_share <- sum(x$samples[is_loop_cell(x$cell)]) / sum(x$samples)
  data.frame(shape = m$shape, candidates = m$candidates, sweep_median_s = m$sweep_s, loop_median_s = m$loop_s,
    pin_sweep_s = m$pin_sweep_s, samples = sum(x$samples), loop_estimate_over_clock = loop_share * m$sweep_s / m$loop_s)
}))
utils::write.csv(reconcile, file.path(out, "reconcile.csv"), row.names = FALSE)
print(reconcile, row.names = FALSE)
cat("done\n")
