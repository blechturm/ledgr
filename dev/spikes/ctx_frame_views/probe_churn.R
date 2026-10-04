# Churn attribution probe: which allocations make up the gap between peak R
# heap (gc max used) and live state in a durable availability ledgr_run()?
#
# Rscript dev/spikes/ctx_frame_views/probe_churn.R <ledgr_repo> <fixture_dir> <out_dir>
#
# Run A (phase markers): trace() markers at top-level steps of ledgr_run_fold()
#   record live heap (after a full gc) and the max-used peak reached inside each
#   phase (gc reset at every marker). Markers force collections, so phase peaks
#   are attribution, not production peaks.
# Run B (no markers): utils::Rprofmem() logs every allocation >= 64 KiB with its
#   call stack; bytes are attributed to the innermost ledgr frame.
args <- commandArgs(TRUE)
repo <- normalizePath(args[[1L]], winslash = "/")
fixture <- args[[2L]]
out_dir <- args[[3L]]
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
source(file.path(repo, "dev/bench/v0_2_2_long_window_regression/helpers.R"))
ns <- asNamespace("ledgr")
fresh_snapshot <- function(tag) {
  db <- file.path(out_dir, paste0("work_", tag, ".duckdb"))
  unlink(c(db, paste0(db, ".wal")))
  stopifnot(file.copy(file.path(fixture, "snapshot.duckdb"), db))
  ledgr_snapshot_open(db)
}

row <- data.frame(shape_id = "probe_avail", profile = "orientation", mode = "run",
  sessions = 757L, instruments = 600L, members = 500L, sets = 12L, churn = 0.02,
  terminals = 0L, terminal_ownership = "none", gap_pattern = "none", stale_budget = 2L,
  features = "returns_63+returns_126+returns_252", strategy = "momentum",
  expected_status = "DONE", stringsAsFactors = FALSE)

# ---- Run A: phase markers ---------------------------------------------------
churn_log <- new.env(); churn_log$rows <- list()
mark <- function(label) {
  g <- gc(full = TRUE)
  churn_log$rows[[length(churn_log$rows) + 1L]] <- data.frame(
    marker = label, live_mib = sum(g[, 2L]), peak_since_last_mib = sum(g[, 6L]))
  gc(reset = TRUE, full = TRUE)
  invisible(NULL)
}
steps <- vapply(as.list(body(ns$ledgr_run_fold)), function(s) {
  paste(deparse(s, width.cutoff = 500L), collapse = "
")
}, character(1))
find_step <- function(pattern) {
  hit <- which(grepl(pattern, steps, fixed = TRUE))
  if (length(hit) != 1L) stop("Marker pattern not unique: ", pattern, " (", length(hit), ")")
  hit
}
markers <- c(
  bars_hydration = find_step("raw_bars_by_id <- split(bars_all"),
  feature_series = find_step("run_feature_series <- list()"),
  runtime_projection = find_step("runtime_projection <- ledgr_projection_from_feature_matrix("),
  strategy_and_spec = find_step("strategy <- ledgr_strategy_from_config(cfg)"),
  fold = find_step("fold_result <- tryCatch("),
  finalize = find_step("finalized <- ledgr_run_finalize(")
)
# One trace() with every step; the tracer pops labels in step order. Each marker
# ends the previous phase and starts the named one. (Repeated trace() calls on
# one function replace each other.)
markers <- sort(markers)
churn_log$pending <- paste0("start_", names(markers))
churn_mark_next <- function() {
  label <- churn_log$pending[[1L]]
  churn_log$pending <- churn_log$pending[-1L]
  mark(label)
}
trace("ledgr_run_fold", where = ns, print = FALSE, at = unname(markers),
      tracer = quote(churn_mark_next()))
snap <- fresh_snapshot("a")
ledgr_feature_cache_clear()
mark("before_run")
bt <- ledgr_run(lwreg_experiment(snap, row), run_id = paste0("churn_a_", Sys.getpid()))
mark("after_run")
close(bt); ledgr_snapshot_close(snap)
untrace("ledgr_run_fold", where = ns)
phases <- do.call(rbind, churn_log$rows)
# peak_since_last belongs to the phase that ended at this marker.
phases$phase_ending_here <- c(NA, head(phases$marker, -1L))
phases$churn_above_start_live_mib <- round(phases$peak_since_last_mib - c(NA, head(phases$live_mib, -1L)), 1)
utils::write.csv(phases, file.path(out_dir, "churn_phases.csv"), row.names = FALSE)

# ---- Run B: Rprofmem allocation attribution ----------------------------------
prof <- file.path(out_dir, "rprofmem.txt")
snap <- fresh_snapshot("b")
ledgr_feature_cache_clear()
gc(full = TRUE)
utils::Rprofmem(prof, threshold = 65536)
bt <- ledgr_run(lwreg_experiment(snap, row), run_id = paste0("churn_b_", Sys.getpid()))
utils::Rprofmem(NULL)
close(bt)
ledgr_snapshot_close(snap)

lines <- readLines(prof, warn = FALSE)
lines <- lines[grepl("^[0-9]+ ?:", lines)]
bytes <- as.numeric(sub("^([0-9]+) ?:.*$", "\\1", lines))
stacks <- sub("^[0-9]+ ?:", "", lines)
ledgr_fns <- ls(ns, all.names = TRUE)
frame_of <- function(stack) {
  calls <- regmatches(stack, gregexpr('"[^"]+"', stack))[[1L]]
  calls <- gsub('"', "", calls)
  own <- calls[calls %in% ledgr_fns]
  inner <- if (length(own)) own[[1L]] else "(outside ledgr)"
  outer <- if (length(calls)) calls[[1L]] else "(none)"
  c(inner = inner, top = outer)
}
frames <- t(vapply(stacks, frame_of, character(2)))
alloc <- data.frame(bytes = bytes, ledgr_frame = frames[, "inner"], innermost_call = frames[, "top"],
                    stringsAsFactors = FALSE)
by_frame <- aggregate(bytes ~ ledgr_frame, alloc, sum)
by_frame$n <- aggregate(bytes ~ ledgr_frame, alloc, length)$bytes
by_frame$mib <- round(by_frame$bytes / 2^20, 1)
by_frame <- by_frame[order(-by_frame$bytes), c("ledgr_frame", "n", "mib")]
utils::write.csv(by_frame, file.path(out_dir, "churn_by_ledgr_frame.csv"), row.names = FALSE)
by_call <- aggregate(bytes ~ ledgr_frame + innermost_call, alloc, sum)
by_call$mib <- round(by_call$bytes / 2^20, 1)
by_call <- by_call[order(-by_call$bytes), c("ledgr_frame", "innermost_call", "mib")]
utils::write.csv(by_call, file.path(out_dir, "churn_by_call.csv"), row.names = FALSE)
unlink(prof)

cat("\n== phases (Run A)\n"); print(phases, row.names = FALSE)
cat(sprintf("\n== Rprofmem (Run B): %.1f MiB allocated in %d large allocations\n",
            sum(bytes) / 2^20, length(bytes)))
print(head(by_frame, 20), row.names = FALSE)
cat("\n== top (ledgr frame, innermost call)\n"); print(head(by_call, 20), row.names = FALSE)

# ---- Run C: Rprof memory profiling (all allocation sizes) ----------------------
# summaryRprof(memory = "both") attributes allocated vector memory (MiB) to the
# functions on the stack. Totals overlap through nesting; self values do not.
snap <- fresh_snapshot("c")
ledgr_feature_cache_clear()
rp <- file.path(out_dir, "rprof_mem.out")
gc(full = TRUE)
Rprof(rp, interval = 0.005, memory.profiling = TRUE)
bt <- ledgr_run(lwreg_experiment(snap, row), run_id = paste0("churn_c_", Sys.getpid()))
Rprof(NULL)
close(bt); ledgr_snapshot_close(snap)
s <- summaryRprof(rp, memory = "both")
tot <- s$by.total; tot$fn <- gsub('"', "", rownames(tot))
self <- s$by.self; self$fn <- gsub('"', "", rownames(self))
keep_tot <- tot[tot$fn %in% c("ledgr_snapshot_hash", "ledgr_run_fold", "ledgr_execute_fold",
  "ledgr_compute_feature_series_strict", "ledgr_run_finalize", "ledgr_bars_pulse_views",
  "ledgr_projection_pulse_views", "ledgr_update_pulse_context_helpers", "ledgr_attach_feature_helpers",
  "ledgr_pulse_context_vec") | grepl("^ledgr_", tot$fn), c("fn", "total.time", "mem.total")]
keep_tot <- keep_tot[order(-keep_tot$mem.total), ]
utils::write.csv(keep_tot, file.path(out_dir, "churn_rprof_total.csv"), row.names = FALSE)
self <- self[order(-self$mem.total), c("fn", "self.time", "mem.total")]
utils::write.csv(head(self, 40), file.path(out_dir, "churn_rprof_self.csv"), row.names = FALSE)
unlink(rp)
cat("\n== Rprof memory, ledgr functions by total allocated MiB (nested, overlapping)\n")
print(head(keep_tot, 30), row.names = FALSE)
cat("\n== Rprof memory, self allocated MiB (top 25)\n")
print(head(self, 25), row.names = FALSE)
