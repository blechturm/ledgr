# Focused hot-path complexity audit for ledgr v0.2.0.1.
#
# This is a read-only package probe. It writes CSV evidence beside this file
# and keeps transient bars, databases, and profiler output under C:/tmp.

options(warn = 1)

repo <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script <- if (length(script_arg)) sub("^--file=", "", script_arg[[1L]]) else {
  file.path(repo, "dev/spikes/v0_2_0_1_hot_path_complexity_audit/probe.R")
}
script <- normalizePath(script, winslash = "/", mustWork = TRUE)
out_dir <- dirname(script)
scratch <- file.path("C:/tmp", sprintf("ledgr-complexity-audit-%s", Sys.getpid()))
dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(scratch, recursive = TRUE, force = TRUE), add = TRUE)

primary_library <- "C:/Users/maxth/Documents/R/win-library/4.6"
.libPaths(c(primary_library, .libPaths()))
suppressPackageStartupMessages(pkgload::load_all(repo, quiet = TRUE))

peer_env <- new.env(parent = globalenv())
sys.source(
  file.path(repo, "dev/bench/peer_benchmark/peer_benchmark.R"),
  envir = peer_env,
  chdir = FALSE
)

source_commit <- system2("git", c("-C", shQuote(repo), "rev-parse", "HEAD"), stdout = TRUE)
started_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

metadata <- data.frame(
  source_commit = source_commit,
  started_at_utc = started_at,
  r = R.version.string,
  platform = R.version$platform,
  os = paste(Sys.info()[c("sysname", "release", "version")], collapse = " "),
  logical_cores = parallel::detectCores(logical = TRUE),
  duckdb = as.character(utils::packageVersion("duckdb")),
  testthat = as.character(utils::packageVersion("testthat")),
  collapse = as.character(utils::packageVersion("collapse")),
  primary_library = normalizePath(.libPaths()[[1L]], winslash = "/"),
  concurrency = "serial probe; no R or Rscript process observed before launch",
  stringsAsFactors = FALSE
)
utils::write.csv(metadata, file.path(out_dir, "environment.csv"), row.names = FALSE)

canonical_features <- ledgr_feature_map(
  fast = peer_env$peer_sma_ttr("fast", 5L),
  slow = peer_env$peer_sma_ttr("slow", 10L)
)
canonical_strategy <- peer_env$peer_strategy("fast", "slow")
zero_cost <- peer_env$peer_cost_zero_model()
no_risk <- peer_env$peer_risk_none_model()

max_n <- 350L
n_days <- 1260L
bars_all <- as.data.frame(ledgr_sim_bars(
  n_instruments = max_n,
  n_days = n_days,
  seed = 20260530L,
  instrument_prefix = "AUDIT_"
))
all_ids <- sort(unique(as.character(bars_all$instrument_id)))

write_bars <- function(n) {
  path <- file.path(scratch, sprintf("bars_%04d.csv", n))
  rows <- bars_all$instrument_id %in% all_ids[seq_len(n)]
  utils::write.csv(bars_all[rows, , drop = FALSE], path, row.names = FALSE)
  path
}

finalize_times <- new.env(parent = emptyenv())
finalize_times$seconds <- numeric()
assign("complexity_audit_finalize_times", finalize_times, envir = globalenv())
suppressMessages(trace(
  "ledgr_run_finalize",
  where = asNamespace("ledgr"),
  print = FALSE,
  tracer = quote(.complexity_audit_finalize_t0 <- proc.time()[["elapsed"]]),
  exit = quote({
    complexity_audit_finalize_times$seconds <- c(
      complexity_audit_finalize_times$seconds,
      proc.time()[["elapsed"]] - .complexity_audit_finalize_t0
    )
  })
))
on.exit(suppressMessages(untrace("ledgr_run_finalize", where = asNamespace("ledgr"))), add = TRUE)

run_event_shape <- function(engine_kind, n, profile = FALSE) {
  bars_path <- write_bars(n)
  profile_path <- file.path(scratch, sprintf("profile_%s_%04d.out", engine_kind, n))
  if (profile) Rprof(profile_path, interval = 0.01, memory.profiling = TRUE, gc.profiling = TRUE)
  finalize_before <- length(finalize_times$seconds)
  result <- if (identical(engine_kind, "memory")) {
    peer_env$peer_run_ledgr_ephemeral(
      engine = sprintf("audit_memory_%d", n),
      bars_path = bars_path,
      features = canonical_features,
      strategy = canonical_strategy,
      seed = 20260530L,
      cost_model = zero_cost,
      risk_chain = no_risk
    )
  } else {
    peer_env$peer_run_ledgr(
      engine = sprintf("audit_durable_%d", n),
      bars_path = bars_path,
      features = canonical_features,
      strategy = canonical_strategy,
      seed = 20260530L,
      cost_model = zero_cost,
      risk_chain = no_risk
    )
  }
  if (profile) Rprof(NULL)
  finalization <- if (length(finalize_times$seconds) > finalize_before) {
    tail(finalize_times$seconds, 1L)
  } else {
    NA_real_
  }
  row <- data.frame(
    engine_kind = engine_kind,
    instruments = n,
    sessions = n_days,
    bars = n * n_days,
    fills = nrow(result$fills),
    snapshot_prepare_seconds = result$phase_sec$snapshot_prepare_sec,
    experiment_setup_seconds = result$phase_sec$experiment_setup_sec,
    engine_seconds = result$phase_sec$engine_sec,
    results_seconds = result$phase_sec$results_sec,
    finalize_inclusive_seconds = finalization,
    microseconds_per_fill = 1e6 * result$phase_sec$engine_sec / max(1L, nrow(result$fills)),
    bars_per_engine_second = n * n_days / result$phase_sec$engine_sec,
    final_equity = utils::tail(result$equity$equity, 1L),
    stringsAsFactors = FALSE
  )
  profile_rows <- NULL
  if (profile) {
    prof <- summaryRprof(profile_path, memory = "both")
    top <- head(prof$by.self, 30L)
    profile_rows <- data.frame(
      engine_kind = engine_kind,
      instruments = n,
      sessions = n_days,
      function_name = rownames(top),
      self_seconds = top[, "self.time"],
      self_percent = top[, "self.pct"],
      total_seconds = top[, "total.time"],
      total_percent = top[, "total.pct"],
      stringsAsFactors = FALSE,
      row.names = NULL
    )
  }
  list(row = row, profile = profile_rows)
}

event_rows <- list()
profile_rows <- list()
for (n in c(50L, 100L, 200L, 350L)) {
  message("memory eventful shape: ", n)
  ans <- run_event_shape("memory", n, profile = identical(n, 200L))
  event_rows[[length(event_rows) + 1L]] <- ans$row
  if (!is.null(ans$profile)) profile_rows[[length(profile_rows) + 1L]] <- ans$profile
}
for (n in c(50L, 100L, 200L)) {
  message("durable eventful shape: ", n)
  ans <- run_event_shape("durable", n, profile = identical(n, 200L))
  event_rows[[length(event_rows) + 1L]] <- ans$row
  if (!is.null(ans$profile)) profile_rows[[length(profile_rows) + 1L]] <- ans$profile
}
event_scaling <- do.call(rbind, event_rows)
rownames(event_scaling) <- NULL
utils::write.csv(event_scaling, file.path(out_dir, "eventful_scaling.csv"), row.names = FALSE)
profile_top <- do.call(rbind, profile_rows)
rownames(profile_top) <- NULL
utils::write.csv(profile_top, file.path(out_dir, "eventful_profile_top.csv"), row.names = FALSE)

# Direct valuation scaling. The current function scans close[, 1:pulse] for
# every axis member at every pulse, so cells_scanned is exact, not inferred.
valuation_run <- function(n, p) {
  ids <- sprintf("V%05d", seq_len(n))
  close <- matrix(100, nrow = n, ncol = p)
  bars_mat <- list(close = close)
  pulses <- as.POSIXct("2020-01-01", tz = "UTC") + seq_len(p) * 86400
  invisible(gc(full = TRUE))
  started <- proc.time()[["elapsed"]]
  for (i in seq_len(p)) {
    ledgr:::ledgr_availability_valuation_marks(
      bars_mat = bars_mat,
      instrument_ids = ids,
      axis = ids,
      pulse_idx = i,
      pulses_posix = pulses,
      max_sessions = 2L
    )
  }
  elapsed <- proc.time()[["elapsed"]] - started
  scanned <- as.double(n) * as.double(p) * as.double(p + 1L) / 2
  data.frame(
    instruments = n,
    pulses = p,
    output_cells = as.double(n) * p,
    cells_scanned = scanned,
    seconds = elapsed,
    nanoseconds_per_scanned_cell = elapsed * 1e9 / scanned,
    microseconds_per_output_cell = elapsed * 1e6 / (as.double(n) * p),
    stringsAsFactors = FALSE
  )
}

valuation_rows <- list()
for (p in c(252L, 504L, 756L, 1260L)) {
  message("valuation pulse scaling: 200 x ", p)
  valuation_rows[[length(valuation_rows) + 1L]] <- valuation_run(200L, p)
}
for (n in c(50L, 100L, 350L, 500L)) {
  message("valuation instrument scaling: ", n, " x 504")
  valuation_rows[[length(valuation_rows) + 1L]] <- valuation_run(n, 504L)
}
valuation_scaling <- do.call(rbind, valuation_rows)
rownames(valuation_scaling) <- NULL
utils::write.csv(valuation_scaling, file.path(out_dir, "valuation_scaling.csv"), row.names = FALSE)

# The lot path is not a release blocker, but this bounded probe demonstrates
# its open-lot dependence. Repeated same-side fills accumulate one lot each.
lot_run <- function(n_lots) {
  state <- ledgr:::ledgr_lot_state("LOT")
  invisible(gc(full = TRUE))
  started <- proc.time()[["elapsed"]]
  for (i in seq_len(n_lots)) {
    state <- ledgr:::ledgr_lot_apply_fill(
      state,
      instrument_id = "LOT",
      side = "BUY",
      qty = 1,
      price = 100 + i / 1000,
      fee = 0
    )$state
  }
  elapsed <- proc.time()[["elapsed"]] - started
  data.frame(
    lots = n_lots,
    seconds = elapsed,
    microseconds_per_added_lot = elapsed * 1e6 / n_lots,
    final_lot_count = length(state$lots$LOT),
    stringsAsFactors = FALSE
  )
}
lot_scaling <- do.call(rbind, lapply(c(100L, 250L, 500L, 1000L, 2000L), lot_run))
rownames(lot_scaling) <- NULL
utils::write.csv(lot_scaling, file.path(out_dir, "lot_scaling.csv"), row.names = FALSE)

# Copy only concise rows from the already-recorded zero-fill availability run.
availability_dir <- file.path(
  repo, "dev/bench/results/v0_2_0_1_batch8_availability_6b09a1b"
)
availability_record <- data.frame()
if (dir.exists(availability_dir)) {
  warm <- utils::read.csv(file.path(availability_dir, "warm_runs.csv"), stringsAsFactors = FALSE)
  lanes <- utils::read.csv(file.path(availability_dir, "warm_lanes.csv"), stringsAsFactors = FALSE)
  cold <- utils::read.csv(file.path(availability_dir, "cold_seal.csv"), stringsAsFactors = FALSE)
  availability_record <- data.frame(
    source_commit = source_commit,
    fixture = "563 instruments; 505-member axis; 757 pulses; flat targets; zero fills",
    warm_median_seconds = stats::median(warm$wall_seconds[warm$measured]),
    warm_spread_seconds = diff(range(warm$wall_seconds[warm$measured])),
    valuation_profile_share = lanes$share_in_loop[lanes$lane == "valuation"],
    event_count = 0L,
    cold_end_to_end_seconds = cold$cold_end_to_end_seconds,
    stringsAsFactors = FALSE
  )
}
utils::write.csv(
  availability_record,
  file.path(out_dir, "availability_record_extract.csv"),
  row.names = FALSE
)

unlink(scratch, recursive = TRUE, force = TRUE)
if (dir.exists(scratch)) {
  stop("Audit scratch directory could not be removed: ", scratch, call. = FALSE)
}
message("COMPLEXITY_AUDIT_EVIDENCE_DIR=", normalizePath(out_dir, winslash = "/"))
