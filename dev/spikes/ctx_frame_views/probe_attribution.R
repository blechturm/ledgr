# Attribution probe: live R heap at fold entry, fold exit and finalization entry,
# and the largest objects reachable from the fold spec and the runner frame.
#
# Rscript dev/spikes/ctx_frame_views/probe_attribution.R <ledgr_repo> <fixture_dir>
args <- commandArgs(TRUE)
repo <- normalizePath(args[[1L]], winslash = "/")
fixture <- args[[2L]]
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
source(file.path(repo, "dev/bench/v0_2_2_long_window_regression/helpers.R"))
ns <- asNamespace("ledgr")
live <- function() sum(gc(full = TRUE)[, 2L])
max_used <- function() sum(gc()[, 6L])
mib <- function(x) round(as.numeric(object.size(x)) / 2^20, 1)
probe_log <- new.env(); probe_log$rows <- list(); probe_log$objects <- NULL
note <- function(point) {
  probe_log$rows[[length(probe_log$rows) + 1L]] <- data.frame(point = point, live_heap_mib = live(), max_used_mib = max_used())
}
trace("ledgr_execute_fold", where = ns, print = FALSE, tracer = quote({
  note("fold_entry")
  runner <- Filter(function(e) exists("fold_execution", envir = e, inherits = FALSE), sys.frames())[[1L]]
  locals <- ls(runner)
  sizes <- vapply(locals, function(n) as.numeric(object.size(get(n, envir = runner))), numeric(1)) / 2^20
  spec <- vapply(names(execution), function(n) as.numeric(object.size(execution[[n]])), numeric(1)) / 2^20
  probe_log$objects <- rbind(
    data.frame(where = "runner_frame", object = locals, mib = round(sizes, 1)),
    data.frame(where = "fold_spec", object = names(execution), mib = round(spec, 1)))
}), exit = quote(note("fold_exit")))
trace("ledgr_run_finalize", where = ns, print = FALSE, tracer = quote(note("finalize_entry")))

row <- data.frame(shape_id = "probe_avail", profile = "orientation", mode = "run",
  sessions = 757L, instruments = 600L, members = 500L, sets = 12L, churn = 0.02,
  terminals = 0L, terminal_ownership = "none", gap_pattern = "none", stale_budget = 2L,
  features = "returns_63+returns_126+returns_252", strategy = "momentum",
  expected_status = "DONE", stringsAsFactors = FALSE)
snap <- ledgr_snapshot_open(file.path(fixture, "snapshot.duckdb"))
gc(reset = TRUE, full = TRUE)
note("before_run")
bt <- ledgr_run(lwreg_experiment(snap, row), run_id = "attr")
note("after_run")
close(bt); ledgr_snapshot_close(snap)
phases <- do.call(rbind, probe_log$rows)
print(phases, row.names = FALSE)
objs <- probe_log$objects[order(-probe_log$objects$mib), ]
print(head(objs[objs$mib >= 1, ], 25), row.names = FALSE)
cat("feature cache MiB:", mib(as.list(ns$.ledgr_feature_cache_registry)), "\n")
