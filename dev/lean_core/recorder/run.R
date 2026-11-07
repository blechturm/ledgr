# LDG-3212 runner: captures the ten workloads (and, with --src=, the history
# fixture from the pinned source archive), writes each capture to a
# caller-named directory, replays it in a fresh R process and writes the
# evidence CSVs and per-workload manifests.
#
#   Rscript dev/lean_core/recorder/run.R --lib=<pinned library> --captures=<dir>
#     [--src=<pinned source archive>] [--out=<dir>] [--manifests=<dir>] [--workloads=id,...]
#   Capture only (an omission): ... --workloads=dense_cost --by-reference=<services field>
#
# Captures are large and never committed. All data is simulated
# (dev/bench/v0_2_3_output_freeze/fixtures.R and dev/bench/v0_2_3_ws16_entry/workloads.R,
# reused, not copied; the history fixture is the pinned tests' own).

# Replay process: only the pinned build, the recorder and one capture; it
# defines nothing in the global environment.
if (any(startsWith(commandArgs(TRUE), "--replay="))) local({
  arg <- function(n) sub(paste0("^--", n, "="), "", grep(paste0("^--", n, "="), commandArgs(TRUE), value = TRUE)[[1L]])
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
  source(file.path(here, "..", "load.R"), local = TRUE)
  lean <- lean_core_load(arg("lib"))
  lean_core_source(lean, c(file.path(lean_core_home, "..", "bench", "v0_2_3_ws16_entry", "common.R"),
                           file.path(here, c("fields.R", "capture.R", "compare.R", "replay.R"))))
  stopifnot(!length(setdiff(ls(globalenv(), all.names = TRUE), ".Random.seed")))
  saveRDS(lean$lc_replay(lean$lc_read_capture(arg("replay"))), arg("result"))
  quit(save = "no", status = 0L)
})

lc_here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
lc_arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
lib <- lc_arg("lib") %||% stop("--lib= is required", call. = FALSE)
captures <- lc_arg("captures") %||% stop("--captures= is required", call. = FALSE)
out <- lc_arg("out", file.path(lc_here, "evidence"))
manifests <- lc_arg("manifests", file.path(lc_here, "manifests"))
for (d in c(captures, out, manifests)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

source(file.path(lc_here, "..", "load.R"))
lean <- lean_core_load(lib)
bench <- file.path(lean_core_home, "..", "bench")
lean_core_source(lean, c(file.path(bench, "v0_2_3_ws16_entry", "common.R"),
                         file.path(lc_here, c("fields.R", "capture.R", "compare.R", "replay.R"))))
# Workload code goes to the global environment, so strategy closures end
# their environment chain there and the recorder never freezes the recorder.
source(file.path(bench, "v0_2_3_ws16_entry", "workloads.R"))
source(file.path(bench, "v0_2_3_output_freeze", "lib.R"))
source(file.path(lc_here, "..", "parity", "prep_fixture.R"))
# Byte compilation would change a closure's serialization between pulses.
invisible(compiler::enableJIT(0L))
# Taken before any wrapper is installed.
lc_engine_version <- ledgr:::ledgr_feature_engine_version()

# Snapshots live in one fixed directory, so paths captured inside strategy
# closures and snapshot handles are the same on every run on this host.
work <- file.path(dirname(tempdir()), "ledgr_lean_core_work")
dir.create(work, showWarnings = FALSE)

lc_workloads <- c(
  stats::setNames(lapply(names(a0_workloads), function(id) function() a0_run_workload(id, work)), names(a0_workloads)),
  momentum_40x504 = function() {
    db <- file.path(work, "momentum.duckdb")
    if (file.exists(db)) unlink(db)
    snapshot <- ws16_momentum_snapshot(40L, 504L, db, "ws16_momentum")
    on.exit(ledgr::ledgr_snapshot_close(snapshot))
    bt <- ledgr::ledgr_run(ws16_momentum_experiment(snapshot, 63L), params = list(lookback = 63L, n = 10L),
                           run_id = "ws16-momentum", seed = 1L)
    close(bt)
  },
  fill_heavy_500x1260 = function() {
    db <- file.path(work, "fill.duckdb")
    if (file.exists(db)) unlink(db)
    snapshot <- ledgr::ledgr_snapshot_from_df(ws16_fill_heavy_bars(), db_path = db, snapshot_id = "ws16_fill")
    on.exit(ledgr::ledgr_snapshot_close(snapshot))
    bt <- suppressWarnings(ledgr::ledgr_run(ws16_fill_heavy_experiment(snapshot), run_id = "ws16-fill",
                                            seed = 20260530L))
    close(bt)
  },
  # The registered history reads: every public request shape on every
  # decision pulse of the pinned tests' WS42 fixture (as tile_probe.R in
  # dev/bench/v0_2_3_ws16_interface/). The fixture file is sourced unchanged;
  # only its temporary database path and clock-generated snapshot id are pinned.
  history_fixture = function() {
    helper <- file.path(lean$.lean_lib, "tests", "testthat", "helper-history-fixtures.R")
    if (!file.exists(helper)) stop("history_fixture needs --lib= to be the pinned source archive", call. = FALSE)
    db <- file.path(work, "history.duckdb")
    if (file.exists(db)) unlink(db)
    fx <- new.env(parent = globalenv())
    fx$tempfile <- function(...) db
    fx$ledgr_snapshot_from_df <- function(...) ledgr::ledgr_snapshot_from_df(..., snapshot_id = "lc_history")
    sys.source(helper, envir = fx, keep.source = FALSE)
    reader <- function(ctx) {
      ledgr::ledgr_history_matrix(ctx, bar = "close", lookback = 3)
      ledgr::ledgr_history_frame(ctx, bar = "close", lookback = Inf, layout = "wide")
      ledgr::ledgr_history_frame(ctx, bar = "close", lookback = Inf, layout = "long")
      ledgr::ledgr_history_matrix(ctx, feature = "fast", lookback = 2, min_observations = 1)
      ledgr::ledgr_history_frame(ctx, feature = "fast", lookback = Inf, layout = "long")
      ledgr::ledgr_history_frame(ctx, bar = "volume", lookback = 4, instruments = "decision_axis")
      ledgr::ledgr_history_frame(ctx, bar = "close", lookback = Inf, instruments = "CCC")
    }
    run <- fx$ws42_capture_run(reader = reader, run_id = "lc-history")
    close(run$bt)
    ledgr::ledgr_snapshot_close(run$fixture$snapshot)
  },
  # LDG-3215 preparation captures (parity/prep_fixture.R): the cross-edge
  # fixture, the three portable shapes and, with --state=, private H1, each
  # issuing the registered request set on every decided pulse.
  prep_fixture = function() {
    db <- file.path(work, "prep_fixture.duckdb")
    if (file.exists(db)) unlink(db)
    fx <- lc_prep_fixture(db)
    on.exit(ledgr::ledgr_snapshot_close(fx$snapshot))
    close(ledgr::ledgr_run(fx$exp, params = lc_prep_fixture_params, run_id = "lc-prep-fixture", seed = 1L))
  },
  prep_500x1260 = function() lc_prep_shape_run(1260L),
  prep_500x2520 = function() lc_prep_shape_run(2520L),
  prep_500x5040 = function() lc_prep_shape_run(5040L),
  prep_intraday_1x100k = function() lc_prep_intraday_run(1L, 1290L),
  prep_intraday_5x100k = function() lc_prep_intraday_run(5L, 1290L),
  prep_intraday_20x50k = function() lc_prep_intraday_run(20L, 645L),
  prep_h1 = function() {
    state <- jsonlite::read_json(lc_arg("state") %||% stop("prep_h1 needs --state=", call. = FALSE),
                                 simplifyVector = TRUE)
    db <- file.path(work, "prep_h1.duckdb")
    if (file.exists(db)) unlink(db)
    if (!file.copy(state$snapshot_path, db)) stop("could not copy the sealed snapshot", call. = FALSE)
    on.exit(unlink(db), add = TRUE)
    lc_prep_shape_open_run(db, state$snapshot_id, universe = state$universe_id)
  }
)

lc_prep_intraday_run <- function(n_inst, n_days) {
  id <- sprintf("lc_prep_intraday_%dx%d", n_inst, n_days)
  db <- file.path(work, paste0(id, ".duckdb"))
  if (file.exists(db)) unlink(db)
  ledgr::ledgr_snapshot_close(lc_prep_intraday_snapshot(n_inst, n_days, db, id))
  snapshot <- ledgr::ledgr_snapshot_open(db, id, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  close(ledgr::ledgr_run(lc_prep_intraday_experiment(snapshot), params = lc_prep_intraday_params,
                         run_id = "lc-prep", seed = 1L))
}

lc_prep_shape_run <- function(days) {
  db <- file.path(work, sprintf("prep_500x%d.duckdb", days))
  if (file.exists(db)) unlink(db)
  ledgr::ledgr_snapshot_close(ws16_momentum_snapshot(500L, days, db, sprintf("lc_prep_500x%d", days)))
  lc_prep_shape_open_run(db, sprintf("lc_prep_500x%d", days))
}

# Opens a sealed store with verification and runs the request-set strategy;
# the explicitly named instrument is the store's first ID (never printed).
lc_prep_shape_open_run <- function(db, snapshot_id, universe = NULL) {
  con <- DBI::dbConnect(duckdb::duckdb(), db, read_only = TRUE)
  first <- DBI::dbGetQuery(con, "SELECT min(instrument_id) AS id FROM snapshot_instruments WHERE snapshot_id = ?",
                           params = list(snapshot_id))$id
  DBI::dbDisconnect(con, shutdown = TRUE)
  snapshot <- ledgr::ledgr_snapshot_open(db, snapshot_id, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  close(ledgr::ledgr_run(lc_prep_shape_experiment(snapshot, universe), params = lc_prep_shape_params(first),
                         run_id = "lc-prep", seed = 1L))
}

# Captures one workload into <captures>/<name>.rds; returns its manifest.
# --boundaries=lot,packet captures only those boundaries (see capture.R lc_boundaries).
lc_only <- if (!is.null(lc_arg("boundaries"))) strsplit(lc_arg("boundaries"), ",")[[1L]]
lc_capture_workload <- function(id, by_reference = character(), name = id, only = lc_only) {
  set.seed(1L)
  lean$lc_capture_begin(by_reference = by_reference, only = only)
  on.exit(lean$lc_rec$on <- FALSE)
  lc_workloads[[id]]()
  # The wrappers must not change a value the pinned build computes from its
  # own function bodies (capture.R, ledgr_feature_engine_version()).
  if (!identical(ledgr:::ledgr_feature_engine_version(), lc_engine_version)) {
    stop("the recorder changed ledgr_feature_engine_version()", call. = FALSE)
  }
  cap <- lean$lc_capture_end()
  saveRDS(list(records = cap$records, folds = cap$folds, clock = cap$clock, blobs = as.list(cap$store$blob)),
          file.path(captures, paste0(name, ".rds")), compress = FALSE)
  lean$lc_manifest(cap)
}

lc_rscript <- function(args) {
  status <- system2(file.path(R.home("bin"), "Rscript"), c(file.path(lc_here, "run.R"), args))
  if (!identical(status, 0L)) stop("run.R ", paste(args, collapse = " "), " exited with status ", status, call. = FALSE)
}

if (sys.nframe() == 0L) {
  # The default is the table check's workload set; preparation captures are named explicitly.
  table_check <- setdiff(names(lc_workloads), c("history_fixture", grep("^prep_", names(lc_workloads), value = TRUE)))
  ids <- strsplit(lc_arg("workloads", paste(table_check, collapse = ",")), ",")[[1L]]
  by_reference <- lc_arg("by-reference")
  if (!is.null(by_reference)) {
    for (id in ids) lc_capture_workload(id, by_reference, name = paste0(id, "_byref"))
    quit(save = "no")
  }
  utils::write.csv(lean$lc_table_fields(), file.path(out, "table_fields.csv"), row.names = FALSE)
  rows <- list()
  for (id in ids) {
    t0 <- proc.time()[["elapsed"]]
    utils::write.csv(lc_capture_workload(id), file.path(manifests, paste0(id, ".csv")), row.names = FALSE)
    gc()
    t1 <- proc.time()[["elapsed"]]
    path <- file.path(captures, paste0(id, ".rds"))
    result <- file.path(captures, paste0(id, "_replay.rds"))
    lc_rscript(c(paste0("--lib=", lib), paste0("--replay=", path), paste0("--result=", result)))
    res <- readRDS(result)
    res$workload <- id
    rows[[id]] <- res
    cat(sprintf("%s: %d records, %d fail; capture %.0fs, replay %.0fs, %.0f MB\n", id, nrow(res), sum(!res$pass),
                t1 - t0, proc.time()[["elapsed"]] - t1, file.size(path) / 2^20))
    if (any(!res$pass)) print(utils::head(res[!res$pass, c("record", "boundary", "difference")], 10L), right = FALSE)
  }
  res <- do.call(rbind, rows)
  key <- paste(res$workload, res$boundary)
  summary <- data.frame(workload = tapply(res$workload, key, `[[`, 1L), boundary = tapply(res$boundary, key, `[[`, 1L),
                        calls = as.vector(table(key)[sort(unique(key))]), passed = tapply(res$pass, key, sum),
                        first_failure = tapply(ifelse(res$pass, NA, res$difference), key, function(v) c(v[!is.na(v)], "")[[1L]]),
                        row.names = NULL)
  summary <- summary[order(match(summary$workload, ids), summary$boundary, method = "radix"), ]
  # The history fixture needs the pinned source archive, which cannot load
  # beside the installed build: a child run appends its rows.
  src <- lc_arg("src")
  if (!is.null(src)) {
    part <- file.path(captures, "history_part")
    lc_rscript(c(paste0("--lib=", src), paste0("--captures=", captures), paste0("--out=", part),
                 paste0("--manifests=", manifests), "--workloads=history_fixture"))
    summary <- rbind(summary, utils::read.csv(file.path(part, "replay.csv"), na.strings = character(),
                                              colClasses = c(first_failure = "character")))
  }
  utils::write.csv(summary, file.path(out, "replay.csv"), row.names = FALSE)
  cat("replay evidence written to", out, "\n")
}
