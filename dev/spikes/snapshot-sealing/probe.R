# Prerequisite probe (spike_protocol.md section 1): where does sealing a
# snapshot spend its time?
#
# One question:
#   On the registered 757-pulse availability fixture (563 instruments, 426,191
#   bars, 60 complete membership lists, status and lifetime facts), which phase
#   of ledgr_snapshot_from_df() dominates wall time, and which functions carry
#   the self time inside that phase?
#
# Not a charter, comparison, or implementation. Production R/ code is not
# modified. The fixture is the writer spike's registered construction,
# evaluated from that runner's own definitions.
#
# Run from the repository root:
#   Rscript dev/spikes/snapshot-sealing/probe.R
# Optional: LEDGR_PROBE_LIB selects an isolated library (the provider spike
# used C:/tmp/ledgr-collapse-218-lib); the loaded versions are printed.
# Outputs beside this file: probe_phases.csv (inclusive wall per phase
# function, traced at entry and exit), probe_lanes.csv (Rprof samples by
# phase), probe_top_self.csv (innermost functions by self samples).

script_path <- local({
  f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(f) == 0L) stop("Run with Rscript.")
  normalizePath(sub("^--file=", "", f[[1L]]), winslash = "/")
})
probe_dir <- dirname(script_path)
repo_root <- normalizePath(file.path(probe_dir, "..", "..", ".."), winslash = "/")
lib <- Sys.getenv("LEDGR_PROBE_LIB", unset = "C:/tmp/ledgr-collapse-218-lib")
if (dir.exists(lib)) .libPaths(c(normalizePath(lib, winslash = "/"), .libPaths()))
options(keep.source = TRUE, keep.source.pkgs = TRUE, warn = 1)
pkgload::load_all(repo_root, quiet = TRUE, export_all = TRUE)

# Registered fixture from the writer spike runner (spike_fixture, FIXTURES).
writer_runner <- file.path(repo_root, "dev/spikes/availability-hot-path-representation/spike_runner.R")
env <- new.env(parent = globalenv())
for (e in parse(writer_runner)) {
  if (is.call(e) && identical(e[[1L]], as.name("<-")) && is.name(e[[2L]]) && as.character(e[[2L]]) %in% c("FIXTURES", "spike_fixture")) eval(e, env)
}
t0 <- proc.time()[["elapsed"]]
fx <- env$spike_fixture(env$FIXTURES$envelope757)
fixture_seconds <- proc.time()[["elapsed"]] - t0
cat(sprintf("fixture built in %.1f s: %d bars, %d instruments\n", fixture_seconds, nrow(fx$bars), nrow(fx$instruments)))

# Exact inclusive wall per phase function: entry and exit tracers.
phase_fns <- c("ledgr_availability_validate_inputs", "ledgr_snapshot_create", "ledgr_create_schema",
               "ledgr_snapshot_write_availability", "ledgr_snapshot_write_fact_family", "ledgr_snapshot_seal",
               "ledgr_snapshot_validate_for_seal", "ledgr_snapshot_validate_availability_for_seal",
               "ledgr_snapshot_metadata_for_seal", "ledgr_snapshot_hash", "ledgr_checkpoint_duckdb")
probe_times <- new.env()
assign("probe_times", probe_times, envir = globalenv())
for (fn in phase_fns) {
  suppressMessages(trace(fn, where = asNamespace("ledgr"), print = FALSE,
    tracer = quote(.probe_t0 <- proc.time()[["elapsed"]]),
    exit = bquote(assign(.(fn), c(get0(.(fn), envir = probe_times, inherits = FALSE, ifnotfound = numeric()), proc.time()[["elapsed"]] - .probe_t0), envir = probe_times))))
}

db <- tempfile("sealing_probe_", fileext = ".duckdb")
prof <- tempfile("sealing_probe_", fileext = ".prof")
invisible(gc(full = TRUE))
Rprof(prof, interval = 0.02, gc.profiling = TRUE)
t0 <- proc.time()[["elapsed"]]
snapshot <- ledgr::ledgr_snapshot_from_df(fx$bars, instruments_df = fx$instruments, db_path = db, snapshot_id = "probe", facts = fx$facts)
seal_seconds <- proc.time()[["elapsed"]] - t0
Rprof(NULL)
ledgr::ledgr_snapshot_close(snapshot)
for (fn in phase_fns) suppressMessages(untrace(fn, where = asNamespace("ledgr")))

phases <- do.call(rbind, lapply(phase_fns, function(fn) {
  v <- get0(fn, envir = probe_times, inherits = FALSE, ifnotfound = numeric())
  data.frame(phase = fn, calls = length(v), inclusive_seconds = sum(v), share_of_seal = sum(v) / seal_seconds, stringsAsFactors = FALSE)
}))
phases <- rbind(phases, data.frame(phase = "ledgr_snapshot_from_df (total)", calls = 1L, inclusive_seconds = seal_seconds, share_of_seal = 1, stringsAsFactors = FALSE))

# Rprof: lane by the phase function present in the stack; self time by the
# innermost frame.
lines <- readLines(prof, warn = FALSE)
interval_us <- as.numeric(sub(".*sample.interval=", "", lines[[1L]]))
samples <- lines[!startsWith(lines, "sample.interval") & !startsWith(lines, "#")]
tokens <- strsplit(trimws(samples), " +")
fns <- lapply(tokens, function(t) sub("^.*[$:]", "", gsub('"', "", t[startsWith(t, '"')], fixed = TRUE)))
lane_of <- function(f) {
  has <- function(x) any(x %in% f)
  if (has("ledgr_snapshot_hash")) return("seal_hash")
  if (has("ledgr_snapshot_validate_availability_for_seal")) return("seal_validate_fact_json")
  if (has("ledgr_snapshot_validate_for_seal")) return("seal_validate_bars")
  if (has("ledgr_snapshot_metadata_for_seal")) return("seal_metadata")
  if (has("ledgr_checkpoint_duckdb")) return("seal_checkpoint")
  if (has("ledgr_snapshot_seal")) return("seal_other")
  if (has("ledgr_availability_validate_inputs")) return("validate_inputs")
  if (has("bulk_copy_parquet")) return("duckdb_bulk_copy")
  if (has("ledgr_snapshot_write_availability")) return("write_facts")
  if (has(c("ledgr_snapshot_create", "ledgr_create_schema", "ledgr_db_init"))) return("create_schema")
  if (has("ledgr_snapshot_from_df")) return("adapter_other")
  "outside"
}
lane <- vapply(fns, lane_of, character(1))
lanes <- as.data.frame(table(lane = lane), stringsAsFactors = FALSE)
names(lanes)[2L] <- "samples"
lanes$seconds <- lanes$samples * interval_us / 1e6
lanes$share <- lanes$samples / length(lane)
lanes <- lanes[order(-lanes$samples), ]
self <- vapply(fns, function(f) { f <- f[f != "<GC>"]; if (length(f)) f[[1L]] else "<GC>" }, character(1))
top_self <- as.data.frame(sort(table(self), decreasing = TRUE)[seq_len(min(20L, length(unique(self))))], stringsAsFactors = FALSE)
names(top_self) <- c("innermost_function", "samples")
top_self$seconds <- top_self$samples * interval_us / 1e6
top_self$share <- top_self$samples / length(lane)
gc_share <- mean(vapply(fns, function(f) any(f == "<GC>"), logical(1)))

utils::write.csv(phases, file.path(probe_dir, "probe_phases.csv"), row.names = FALSE)
utils::write.csv(lanes, file.path(probe_dir, "probe_lanes.csv"), row.names = FALSE)
utils::write.csv(top_self, file.path(probe_dir, "probe_top_self.csv"), row.names = FALSE)
cat("PROBE_ENVIRONMENT\n")
cat("R=", R.version.string, " collapse=", as.character(utils::packageVersion("collapse")), " duckdb=", as.character(utils::packageVersion("duckdb")), "\n", sep = "")
cat(sprintf("seal wall %.1f s; Rprof samples %d (%.1f s at %.0f ms; gc in %.1f%% of samples)\n", seal_seconds, length(lane), length(lane) * interval_us / 1e6, interval_us / 1e3, 100 * gc_share))
cat("PHASES (inclusive, traced)\n"); print(phases, row.names = FALSE)
cat("LANES (Rprof)\n"); print(lanes, row.names = FALSE)
cat("TOP SELF (Rprof)\n"); print(top_self, row.names = FALSE)
unlink(c(db, paste0(db, ".wal"), prof), force = TRUE)
cat("PROBE_STATUS=PASS\n")
