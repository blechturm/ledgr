# One isolated installed-package process: prepare common inputs OR cold/warm pair.
entered_wall <- as.numeric(Sys.time())
entered_elapsed <- proc.time()[["elapsed"]]
file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
here <- dirname(normalizePath(file, winslash = "/"))
source(file.path(here, "native.R"))
mode <- dense_arg("mode")

# This process is outside either measured arm. It deliberately loads and calls
# the one shared host implementation rather than carrying a dense-local copy.
if (identical(mode, "host")) {
  repo <- normalizePath(dense_arg("repo"), winslash = "/", mustWork = TRUE)
  harness_dir <- file.path(repo, "dev", "bench", "timing")
  source(file.path(harness_dir, "host.R"))
  probe <- timing_host_probe(harness_dir = harness_dir)
  saveRDS(probe, dense_arg("probe-out"), version = 3L)
  root_pid <- as.numeric(dense_arg("root-pid"))
  root_chain <- timing_chain(probe$procs, root_pid)
  utils::write.csv(data.frame(
    at = probe$at,
    plan_guid = probe$plan_guid,
    cpu_percent = probe$cpu_percent,
    cpu_name = probe$cpu_name,
    root_chain = root_chain,
    foreign_r = timing_foreign_r(probe$procs, root_chain),
    stringsAsFactors = FALSE
  ), dense_arg("summary-out"), row.names = FALSE)
  problems <- timing_root_problems(probe, root_pid)
  if (length(problems)) stop(paste(names(problems), problems, collapse = "; "))
  quit(status = 0L)
}

lib <- normalizePath(dense_arg("library"), winslash = "/", mustWork = TRUE)
.libPaths(c(lib, .libPaths()))
suppressPackageStartupMessages(library(ledgr, lib.loc = lib, character.only = FALSE))
stopifnot(identical(normalizePath(getNamespaceInfo(asNamespace("ledgr"), "path")),
  normalizePath(file.path(lib, "ledgr"))))
source(file.path(here, "recipes.R"))
compiler::enableJIT(3L)
observed_jit <- compiler::enableJIT(3L)
clock <- function() proc.time()[["elapsed"]]
out <- dense_arg("out")
if (is.null(out)) stop("explicit --out required")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
if (identical(mode, "prepare")) {
  for (shape in list(c(12L, 90L), c(500L, 1260L))) {
    bars <- ledgr_sim_bars(shape[1L], shape[2L], seed = 20260530L,
      start = "2020-01-01", instrument_prefix = "P")
    bars$ts_utc <- bars$ts_utc + 21 * 3600
    stopifnot(max(tapply(bars$open, bars$ts_utc, sum)) < 1e7)
    saveRDS(bars, file.path(out, paste0(shape[1L], "x", shape[2L], ".rds")), version = 3L)
  }
  quit(status = 0L)
}
if (!identical(mode, "worker")) stop("--mode=host, prepare or worker required")
if (length(list.files(out, all.files = TRUE, no.. = TRUE))) stop("worker output must be new/empty")
source_revision <- dense_arg("source")
shape <- dense_arg("shape")
repetition <- as.integer(dense_arg("repetition"))
launch_wall <- as.numeric(dense_arg("launch"))
stopifnot(observed_jit == 3L, is.finite(launch_wall), launch_wall < entered_wall)
import_end <- clock()
bars <- readRDS(dense_arg("input"))
input_end <- clock()
n_instruments <- length(unique(bars$instrument_id))
n_pulses <- length(unique(bars$ts_utc))
stopifnot(shape == paste0(n_instruments, "x", n_pulses))
snapshot <- ledgr_snapshot_from_df(bars, db_path = file.path(out, "book.duckdb"),
  snapshot_id = "timing_transition", price_basis = "split_adjusted")
snapshot_end <- clock()

run_arm <- function(arm) {
  start <- clock()
  features <- ledgr_feature_map(
    fast = ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
    slow = ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L))
  exp <- ledgr_experiment(snapshot, dense_transition, features = features,
    opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero(),
    risk_chain = ledgr_risk_none())
  setup_end <- clock()
  warning_count <- 0L
  bt <- withCallingHandlers(ledgr_run(exp, run_id = paste0("timing_", arm), seed = 20260530L),
    warning = function(w) {
      warning_count <<- warning_count + 1L
      invokeRestart("muffleWarning")
    })
  on.exit(close(bt), add = TRUE)
  run_end <- clock()
  fills <- as.data.frame(ledgr_results(bt, "fills"))
  equity <- as.data.frame(ledgr_results(bt, "equity"))
  con <- ledgr_db_init(bt$db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  rebuilt <- ledgr_state_reconstruct(bt$run_id, con)
  # Required fills, equity, cash and asset holdings now exist in memory.
  finish <- clock()
  run <- DBI::dbGetQuery(con, "SELECT status, config_hash FROM runs WHERE run_id = ?",
    params = list(bt$run_id))
  state <- DBI::dbGetQuery(con,
    "SELECT ts_utc, state_json FROM strategy_state WHERE run_id = ? ORDER BY ts_utc",
    params = list(bt$run_id))
  threads <- DBI::dbGetQuery(con, "SELECT current_setting('threads') AS threads")$threads
  stopifnot(identical(run$status, "DONE"), nrow(equity) == n_pulses,
    nrow(state) == n_pulses, nrow(rebuilt$positions) == n_instruments,
    nrow(fills) > 0L, any(fills$side == "BUY"), any(fills$side == "SELL"),
    all(fills$qty == 1), all(fills$fee == 0), min(equity$cash) >= 0,
    equity$cash[1L] == 1e7, equity$positions_value[1L] == 0,
    identical(tail(equity$cash, 1L), tail(rebuilt$cash$cash, 1L)),
    identical(tail(equity$equity, 1L), tail(rebuilt$equity_curve$equity, 1L)))
  list(row = data.frame(shape = shape, repetition = repetition, arm = arm,
    pid = Sys.getpid(), source_revision = source_revision, status = run$status,
    clock_sec = finish - start, setup_sec = setup_end - start,
    run_sec = run_end - setup_end, results_sec = finish - run_end,
    startup_sec = NA_real_, import_sec = NA_real_, input_sec = NA_real_,
    snapshot_sec = NA_real_, residual_sec = 0,
    configured_jit = 3L, observed_jit = observed_jit,
    installed_path = normalizePath(file.path(lib, "ledgr"), winslash = "/"),
    n_instruments = n_instruments, n_pulses = n_pulses, instrument_bars = nrow(bars),
    persisted_callback_rows = nrow(state), equity_pulse_rows = nrow(equity),
    warning_count = warning_count, duckdb_threads = as.integer(threads),
    reuse = "unchanged_sealed_snapshot_and_first_use_only", precomputed_features = FALSE,
    required_outputs = "fills;equity;cash;asset_holdings"),
    controls = list(fill_count = nrow(fills), terminal_cash = tail(equity$cash, 1L),
      terminal_equity = tail(equity$equity, 1L), terminal_positions = rebuilt$positions,
      opening_cash = equity$cash[1L], opening_positions_value = equity$positions_value[1L],
      initial_state = state$state_json[1L], snapshot_hash = ledgr_snapshot_info(snapshot)$snapshot_hash,
      config_hash = run$config_hash), finish = finish)
}

cold <- run_arm("cold")
cold$row$clock_sec <- entered_wall - launch_wall + cold$finish - entered_elapsed
cold$row$startup_sec <- entered_wall - launch_wall
cold$row$import_sec <- import_end - entered_elapsed
cold$row$input_sec <- input_end - import_end
cold$row$snapshot_sec <- snapshot_end - input_end
cold$row$residual_sec <- cold$row$clock_sec - sum(cold$row[, c("startup_sec", "import_sec",
  "input_sec", "snapshot_sec", "setup_sec", "run_sec", "results_sec")])
saveRDS(cold, file.path(out, "cold.rds"), version = 3L)
# Do not retain old fills/equity or a feature payload across arms; only small
# native controls, raw common bars, verified snapshot and loaded first-use state.
invisible(gc())
warm <- run_arm("warm")
stopifnot(identical(cold$controls, warm$controls))
saveRDS(warm, file.path(out, "warm.rds"), version = 3L)
writeLines(c(paste("installed source:", source_revision),
  paste("installed namespace:", getNamespaceInfo(asNamespace("ledgr"), "path")),
  paste("configured R_ENABLE_JIT:", Sys.getenv("R_ENABLE_JIT")),
  paste("observed JIT:", observed_jit), capture.output(sessionInfo())),
  file.path(out, "environment.txt"))
ledgr_snapshot_close(snapshot)
cat("timing worker complete:", shape, repetition, "\n")
