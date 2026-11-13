# Cut 15 measured input: inside each lean stage, which direct callees hold
# the samples. Profiles the lean arm (debug off, byte-compiled, inert hooks)
# on the crossover fixture and writes aggregate shares only.
#
#   Rscript dev/bench/v0_2_3_lean_tuning_profile/stage_drill.R --lib=<pinned library> --out=<csv>
#
# Each row: shape, the frame drilled, a direct callee ("<self>" for the
# frame's own body), samples and share of the samples containing the frame.
# Rprof estimates at 2 ms; the cost map (cost_map.R) holds the clocks.
#
# Cut 16 (LDG-3229): --runs=<descriptor:runs,...> picks workload descriptors
# (descriptors.R; default Cut 15's 10x7200:4,500x1260:12), and the drilled
# frames add the risk plan, the sizing helpers and validator and the FIFO.

arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) { if (is.null(default)) stop("--", name, "= is required", call. = FALSE); return(default) }
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
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
kv <- strsplit(strsplit(arg("runs", "10x7200:4,500x1260:12"), ",")[[1L]], ":")
runs <- stats::setNames(as.integer(vapply(kv, `[[`, "", 2L)), vapply(kv, `[[`, "", 1L))
frames <- c("lean_p2_decide", "lean_context", "ledgr_call_strategy_fn", "lean_p3_plan", "lean_plan_pulse",
            "lean_p4_apply", "lean_lot_apply", "lean_p5_commit", "lean_state_patch",
            "ledgr_apply_risk_plan", "ledgr_apply_risk_step_max_weight", "ledgr_target_rebalance",
            "ledgr_validate_sizing_evidence", "lean_lot_fill", "lean_lot_general", "fn")
work <- file.path(tempdir(), "stage_drill")
dir.create(work, showWarnings = FALSE)
experiment <- function(snapshot, s) bench_descriptor(s)$experiment(snapshot)
# The strategy call's own callees sit two frames below the wrapper (wrapper > fn > callee).
drill <- function(stacks, frame) {
  depth <- if (identical(frame, "ledgr_call_strategy_fn")) 2L else 1L
  stacks <- Filter(function(s) frame %in% s, stacks)
  if (!length(stacks)) return(NULL)   # a frame the workload never reaches
  key <- vapply(stacks, function(s) {
    j <- match(frame, s)
    if (j <= depth) return("<self>")
    s[[j - depth]]
  }, character(1L))
  tab <- sort(table(key), decreasing = TRUE)
  data.frame(frame = frame, callee = names(tab), samples = as.integer(tab),
             share = round(as.numeric(tab) / length(stacks), 3), stringsAsFactors = FALSE)
}
restore <- lean$lean_loop_install(hooks = FALSE)
rows <- list()
for (s in names(runs)) {
  dsc <- bench_descriptor(s)
  sealed <- file.path(work, paste0(s, ".duckdb"))
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(dsc$bars(),
    db_path = sealed, snapshot_id = paste0("sd_", s), price_basis = "split_adjusted"))
  stacks <- list()
  for (r in 0:runs[[s]]) {                # run 0 warms up and is not profiled
    db <- file.path(work, "run.duckdb")
    if (file.exists(db)) unlink(db)
    file.copy(sealed, db)
    snap <- ledgr::ledgr_snapshot_open(db, paste0("sd_", s), verify = TRUE)
    prof <- file.path(work, "run.rprof")
    invisible(gc())
    if (r > 0L) Rprof(prof, interval = 0.002)
    bt <- ledgr::ledgr_run(experiment(snap, s), run_id = "sd", seed = 20260530L)
    if (r > 0L) {
      Rprof(NULL)
      l <- readLines(prof)
      l <- l[!grepl("^sample.interval|^#", l)]
      stacks <- c(stacks, lapply(strsplit(l, " ", fixed = TRUE), function(x) gsub('"', "", x)))
    }
    close(bt)
    ledgr::ledgr_snapshot_close(snap)
  }
  for (f in frames) { d <- drill(stacks, f); if (!is.null(d)) rows[[length(rows) + 1L]] <- cbind(shape = s, d) }
}
restore()
out <- do.call(rbind, rows)
utils::write.csv(out, arg("out"), row.names = FALSE)
print(out[out$share >= 0.05, ], row.names = FALSE)
