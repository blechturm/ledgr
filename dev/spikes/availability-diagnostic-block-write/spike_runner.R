# Comparative spike runner for the availability diagnostic-block spike,
# executed under Charter v2
# (rfc_availability_hot_path_representation_v0_2_0_x_diagnostic_block_spike_charter_v2.md).
#
# Two arms, one seam (the fold-side diagnostic interface behind the reviewed
# columnar writer, selected by options(ledgr.internal.spike_diagnostic_block)):
#   current  scalar ledgr_availability_diagnostic_fields() per row, one append per row;
#   block    one typed diagnostic block per pulse, appended through append_block().
# Both arms hold the prepared availability provider and the columnar writer
# constant. The semantic fixture and strategy are the provider spike's
# (imported from that runner's definitions) plus one missing bar for a held
# instrument; the fold fixture is the writer runner's spike_fixture(FIXTURES$envelope757).
#
# Usage, from the repository root:
#   Rscript dev/spikes/availability-diagnostic-block-write/spike_runner.R <mode> [--evidence <dir>]
#   modes: fixtures | semantic | tests | fold757 | fold757parity | all
#
# Evidence CSVs (deterministic ones are byte-diffed by the checker):
#   fixture.csv, environment.csv      registered fixtures, envelope, versions, HEAD
#   cases.csv                         fold scenarios per arm and chunk size: statuses, counts,
#                                     parity and reopen flags, attestation (stamped writer mode,
#                                     observed provider arm, traced constructor call counts)
#   diagnostics_reference.csv         current-arm direct-run diagnostics on the semantic fixture
#   coverage.csv                      persisted (stage, outcome, reason_code) census per scenario and arm
#   setv_trace.csv                    collapse::setv() calls per scenario and arm by origin and target type
#   regression_tests.csv              existing test-availability-*.R results under both arms
#   regression_optional.csv           the optional parallel-worker test's outcome per arm
#   regression_attestation.csv        stamped modes and constructor counts over the regression net
#   fold_757.csv, lanes_757.csv       757-pulse folds (wall, t_loop, peak WS, attestation); lane shares
#   fold_757_parity.csv               one non-measured 757-pulse pair with a shared run ID compared
#                                     table by table by DuckDB multiset difference
# Identity is ledgr's own (run IDs, snapshot hashes, run-store rows); no hash
# ledger, registry, or workspace gate.

args <- commandArgs(trailingOnly = TRUE)
script_path <- local({
  f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(f) == 0L) stop("Run with Rscript.")
  normalizePath(sub("^--file=", "", f[[1L]]), winslash = "/")
})
spike_dir <- dirname(script_path)
repo_root <- normalizePath(file.path(spike_dir, "..", "..", ".."), winslash = "/")
arg_value <- function(flag, default) { i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[[i + 1L]] }
evidence_dir <- normalizePath(arg_value("--evidence", file.path(spike_dir, "evidence")), winslash = "/", mustWork = FALSE)
`%||%` <- function(a, b) if (is.null(a)) b else a

# The same collapse library for every process, selected explicitly (Charter v2).
SPIKE_LIB <- Sys.getenv("LEDGR_SPIKE_LIB", unset = "C:/tmp/ledgr-collapse-218-lib")
if (dir.exists(SPIKE_LIB)) .libPaths(c(normalizePath(SPIKE_LIB, winslash = "/"), .libPaths()))

ARMS <- c("current", "block")
ENVELOPE <- list(fold_wall_s = 60, peak_ws_mib = 1024)
WALL_STOP_S <- 1800
WS_STOP_MIB <- 4096
SEMANTIC_CHUNK_ROWS <- 7L
DEFAULT_CHUNK_ROWS <- 4096L
MISSING_BAR <- list(instrument_id = "BBB", session = 4L)
WRITER_RUNNER <- file.path(repo_root, "dev/spikes/availability-hot-path-representation/spike_runner.R")
PROVIDER_RUNNER <- file.path(repo_root, "dev/spikes/availability-provider-preparation/spike_runner.R")
# Run identity comparison (Charter v2, claim 6): the same run ID is used in
# both arms' stores, so excluded exactly: the top-level creation time and the
# two scratch store locators the config JSON embeds. Nothing else.
IDENTITY_EXCLUDED <- "created_at_utc"
IDENTITY_JSON_EXCLUDED <- c("db_path", "data.snapshot_db_path")
OPTIONAL_TESTS <- "parallel availability sweeps return the same compact terminal evidence"

# Shared definitions imported verbatim from the provider spike runner: the
# public semantic fixture and strategy, the registered fold fixture loader,
# the external working-set sampler, and small helpers.
import_definitions <- function(path, names, env = globalenv()) {
  for (e in parse(path)) {
    if (is.call(e) && identical(e[[1L]], as.name("<-")) && is.name(e[[2L]]) && as.character(e[[2L]]) %in% names) eval(e, env)
  }
  invisible(NULL)
}
import_definitions(PROVIDER_RUNNER, c("weekday_sessions", "at", "sessions_df", "semantic_fixture", "semantic_status_df", "semantic_strategy",
                                      "experiment_for", "registered_fold_fixture", "open_snapshot", "iso", "strip_id", "same", "seq_ok",
                                      "pulse_iso", "sampler_ps1", "launch_child", "run_child_json", "rscript_path", "load_package", "environment_row"))

set_arm <- function(arm, chunk_rows = DEFAULT_CHUNK_ROWS) {
  options(ledgr.internal.spike_availability_provider = "prepared", ledgr.internal.spike_diagnostic_writer = "columnar",
          ledgr.internal.spike_diagnostic_chunk_rows = as.integer(chunk_rows),
          ledgr.internal.spike_diagnostic_block = if (identical(arm, "block")) "on" else "off")
}

# Attestation (Charter v2, claim 1): the mode stamped on the writer object the
# fold actually built, the arm stamped on the provider object, and traced call
# counts of the scalar field constructor and the block constructor. The
# post-rollback row keeps ledgr_availability_diagnostic_row() and is outside
# both counts.
spike_observed <- new.env()
reset_observed <- function() { spike_observed$modes <- character(); spike_observed$providers <- character(); spike_observed$scalar <- 0L; spike_observed$block <- 0L }
install_observer <- function() {
  reset_observed(); assign("spike_observed", spike_observed, envir = globalenv())
  ns <- asNamespace("ledgr")
  invisible(suppressMessages({
    trace("ledgr_fold_diagnostic_writer", where = ns, print = FALSE,
          exit = quote(spike_observed$modes <- c(spike_observed$modes, attr(returnValue(), "spike_diagnostic_mode") %||% NA_character_)))
    trace("ledgr_availability_provider_build", where = ns, print = FALSE,
          exit = quote(spike_observed$providers <- c(spike_observed$providers, attr(returnValue(), "spike_arm") %||% NA_character_)))
    trace("ledgr_availability_diagnostic_fields", where = ns, print = FALSE, tracer = quote(spike_observed$scalar <- spike_observed$scalar + 1L))
    trace("ledgr_availability_diagnostic_block", where = ns, print = FALSE, tracer = quote(spike_observed$block <- spike_observed$block + 1L))
  }))
}
join_unique <- function(x) { x <- unique(x); if (length(x) == 0L) NA_character_ else paste(x, collapse = "|") }
take_observed <- function() {
  out <- list(mode = join_unique(spike_observed$modes), provider = join_unique(spike_observed$providers),
              scalar_calls = spike_observed$scalar, block_calls = spike_observed$block)
  reset_observed()
  out
}

# collapse::setv() trace (Charter v2, claim 10), semantic scenarios only: each
# call is attributed by its call stack to the block path (append_block), the
# columnar writer's scalar put(), or unchanged package code, and the target's
# storage type is recorded per origin.
spike_setv <- new.env(); spike_setv$counts <- list()
install_setv_trace <- function() {
  assign("spike_setv", spike_setv, envir = globalenv())
  invisible(suppressMessages(trace("setv", where = asNamespace("collapse"), print = FALSE, tracer = quote({
    heads <- vapply(sys.calls(), function(cl) paste(deparse(cl[[1L]], nlines = 1L), collapse = ""), character(1))
    origin <- if (any(grepl("append_block", heads, fixed = TRUE))) "block_path" else if (any(heads == "put")) "columnar_scalar_put" else "other_package"
    key <- paste(origin, if (is.list(X)) "list" else typeof(X), sep = ":")
    spike_setv$counts[[key]] <- (if (is.null(spike_setv$counts[[key]])) 0L else spike_setv$counts[[key]]) + 1L
  }))))
}
remove_setv_trace <- function() invisible(suppressMessages(untrace("setv", where = asNamespace("collapse"))))
take_setv <- function() { out <- spike_setv$counts; spike_setv$counts <- list(); out }

# ---------------------------------------------------------------------------
# Fixtures.
# ---------------------------------------------------------------------------

# The provider spike's semantic fixture plus one missing bar for a held
# instrument (Charter v2): the stale mark yields risk rows and the fill
# attempted at that session's opening yields an execution_bar_missing no-fill.
block_semantic_fixture <- function() {
  fx <- semantic_fixture()
  drop <- fx$bars$instrument_id == MISSING_BAR$instrument_id & fx$bars$ts_utc == at(fx$dates[[MISSING_BAR$session]], "21:00:00")
  fx$bars <- fx$bars[!drop, , drop = FALSE]
  fx$counts <- c(fx$counts, missing_bars = sum(drop))
  fx
}

normalize_identity <- function(row) {
  out <- row[, setdiff(names(row), IDENTITY_EXCLUDED), drop = FALSE]
  cfg <- yyjsonr::read_json_str(as.character(row$config_json))
  cfg$db_path <- NULL; cfg$data$snapshot_db_path <- NULL
  out$config_json <- yyjsonr::write_json_str(cfg, auto_unbox = TRUE)
  out
}
read_store <- function(db_path, run_id) {
  con <- DBI::dbConnect(duckdb::duckdb(), db_path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  q <- function(sql) DBI::dbGetQuery(con, sql, params = list(run_id))
  identity <- q("SELECT * FROM runs WHERE run_id = ?")
  list(status = identity$status, identity = normalize_identity(identity),
       diagnostics = q("SELECT * FROM run_diagnostics WHERE run_id = ? ORDER BY diagnostic_seq"),
       events = q("SELECT * FROM ledger_events WHERE run_id = ? ORDER BY event_seq"),
       equity = q("SELECT * FROM equity_curve WHERE run_id = ? ORDER BY ts_utc"),
       state = q("SELECT * FROM strategy_state WHERE run_id = ? ORDER BY ts_utc"),
       completion = q("SELECT * FROM run_completion WHERE run_id = ?"))
}

# ---------------------------------------------------------------------------
# Fold scenarios on the semantic fixture (both arms, fresh store per run).
# ---------------------------------------------------------------------------

run_invocation <- function(exp, run_id) {
  bt <- NULL
  err <- tryCatch({ bt <- ledgr::ledgr_run(exp, run_id = run_id); NA_character_ }, error = function(e) paste(class(e)[[1L]], conditionMessage(e), sep = ": "))
  session <- if (!is.null(bt)) as.data.frame(ledgr::ledgr_results(bt, "diagnostics")) else NULL
  if (!is.null(bt)) close(bt)
  list(error = err, session_diagnostics = session)
}
reopen_read <- function(arm, db, run_id, cells, chunk_rows) {
  set_arm(arm, chunk_rows); reset_observed()
  snap <- ledgr::ledgr_snapshot_open(db, "spike", verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snap), add = TRUE)
  out <- list(error = NA_character_)
  bt <- tryCatch(ledgr::ledgr_run_open(snap, run_id), error = function(e) { out$error <<- paste(class(e)[[1L]], conditionMessage(e), sep = ": "); NULL })
  if (!is.null(bt)) {
    out$diagnostics <- as.data.frame(ledgr::ledgr_results(bt, "diagnostics"))
    out$availability <- as.data.frame(ledgr::ledgr_results(bt, "availability"))
    out$explained <- do.call(rbind, lapply(seq_len(nrow(cells)), function(i) as.data.frame(ledgr::ledgr_run_explain(bt, cells$instrument_id[[i]], cells$ts_utc[[i]]))))
    close(bt)
  }
  out$observed <- take_observed()
  out
}

run_case <- function(arm, fx, run_id, chunk_rows, interrupt_at = NULL, fail_at = NULL, increase_at = NULL, resume_fail_at = NULL, exit_iii_from = NULL) {
  set_arm(arm, chunk_rows); reset_observed(); take_setv()
  prior <- options(ledgr.interrupt = FALSE, ledgr.spike.interrupt_at = interrupt_at %||% "", ledgr.spike.fail_at = fail_at %||% "",
                   ledgr.spike.increase_nonmember_at = increase_at %||% "", ledgr.spike.exit_iii_from = exit_iii_from %||% "")
  on.exit(options(prior), add = TRUE)
  db <- tempfile(paste0("spike_", arm, "_"), fileext = ".duckdb")
  snapshot <- open_snapshot(fx, db)
  exp <- experiment_for(snapshot, fx$universe)
  first <- run_invocation(exp, run_id)
  after_first <- read_store(db, run_id)
  resume <- list(error = NA_character_, session_diagnostics = NULL)
  resumed <- NULL
  if (!is.null(interrupt_at)) {
    options(ledgr.interrupt = FALSE, ledgr.spike.interrupt_at = "", ledgr.spike.fail_at = resume_fail_at %||% "")
    resume <- run_invocation(exp, run_id)
    resumed <- read_store(db, run_id)
  }
  observed <- take_observed(); setv <- take_setv()
  final <- resumed %||% after_first
  session_diagnostics <- if (!is.null(interrupt_at)) resume$session_diagnostics else first$session_diagnostics
  ledgr::ledgr_snapshot_close(snapshot)
  reopened <- list()
  if (final$status %in% c("DONE", "INCOMPLETE")) {
    cells <- final$diagnostics[final$diagnostics$stage == "decision", , drop = FALSE]
    cells <- cells[unique(round(seq(1L, nrow(cells), length.out = 3L))), , drop = FALSE]
    for (reopen_arm in ARMS) reopened[[reopen_arm]] <- reopen_read(reopen_arm, db, run_id, cells, chunk_rows)
  }
  unlink(c(db, paste0(db, ".wal")), force = TRUE)
  list(arm = arm, run_id = run_id, chunk_rows = chunk_rows, first_error = first$error, after_first = after_first, resume_error = resume$error, final = final,
       session_diagnostics = session_diagnostics, reopened = reopened, observed = observed, setv = setv)
}

# Persisted (stage, outcome, reason_code) census of a run's diagnostics, in
# byte order so the CSV is host-independent.
census <- function(d, scenario, arm) {
  if (is.null(d) || nrow(d) == 0L) return(NULL)
  key <- paste(d$stage, d$outcome, d$reason_code, sep = "|")
  u <- !duplicated(key)
  out <- data.frame(scenario = scenario, selected_arm = arm, stage = d$stage[u], outcome = d$outcome[u], reason_code = d$reason_code[u],
                    rows = tabulate(match(key, key[u]), sum(u)), stringsAsFactors = FALSE)
  out <- out[order(out$stage, out$outcome, out$reason_code, method = "radix"), ]
  rownames(out) <- NULL
  out
}
setv_rows <- function(counts, scenario, arm) {
  if (length(counts) == 0L) return(NULL)
  keys <- names(counts); keys <- keys[order(keys, method = "radix")]
  parts <- strsplit(keys, ":", fixed = TRUE)
  data.frame(scenario = scenario, selected_arm = arm, origin = vapply(parts, `[[`, "", 1L), storage_type = vapply(parts, `[[`, "", 2L),
             calls = vapply(keys, function(k) as.integer(counts[[k]]), integer(1)), stringsAsFactors = FALSE, row.names = NULL)
}

semantic_phase <- function(evidence) {
  fx <- block_semantic_fixture()
  scenarios <- list(
    list(id = "S1_direct"),
    list(id = "S1_direct_chunk4096", chunk = DEFAULT_CHUNK_ROWS),
    list(id = "S2_interrupt_resume", interrupt = 13L),
    list(id = "S3_exception_rollback", fail = 17L),
    list(id = "S4_nonmember_increase_rollback", increase = 12L),
    list(id = "S5_resume_then_exception", interrupt = 8L, resume_fail = 20L),
    list(id = "S6_exit_before_terminal_direct", exit = 27L),
    list(id = "S7_exit_before_terminal_resume", interrupt = 13L, exit = 27L)
  )
  install_setv_trace(); on.exit(remove_setv_trace(), add = TRUE)
  results <- list()
  for (sc in scenarios) for (arm in ARMS) {
    cat(sprintf("scenario %-32s arm %-8s ... ", sc$id, arm)); t0 <- proc.time()[["elapsed"]]
    r <- run_case(arm, fx, run_id = paste0("spike-", sc$id), chunk_rows = sc$chunk %||% SEMANTIC_CHUNK_ROWS,
                  interrupt_at = if (!is.null(sc$interrupt)) pulse_iso(fx, sc$interrupt), fail_at = if (!is.null(sc$fail)) pulse_iso(fx, sc$fail),
                  increase_at = if (!is.null(sc$increase)) pulse_iso(fx, sc$increase), resume_fail_at = if (!is.null(sc$resume_fail)) pulse_iso(fx, sc$resume_fail),
                  exit_iii_from = if (!is.null(sc$exit)) pulse_iso(fx, sc$exit))
    results[[paste(sc$id, arm)]] <- r
    cat(sprintf("%.1f s status %s rows %d mode %s scalar %d block %d\n", proc.time()[["elapsed"]] - t0, r$final$status, nrow(r$final$diagnostics),
                r$observed$mode, r$observed$scalar_calls, r$observed$block_calls))
  }
  direct <- results[["S1_direct current"]]$final
  rows <- lapply(names(results), function(nm) {
    r <- results[[nm]]; sc_id <- sub(" .*$", "", nm); arm <- sub("^.* ", "", nm); f <- r$final
    peer <- results[[paste(sc_id, "current")]]
    direct_peer <- if (grepl("^S6|^S7", sc_id)) results[["S6_exit_before_terminal_direct current"]]$final else direct
    chunk_peer <- if (identical(sc_id, "S1_direct_chunk4096")) results[[paste("S1_direct", arm)]]$final else NULL
    ro <- r$reopened; po <- peer$reopened
    data.frame(scenario = sc_id, chunk_rows = r$chunk_rows, selected_arm = arm, observed_mode_run = r$observed$mode, observed_provider_run = r$observed$provider,
      scalar_calls = r$observed$scalar_calls, block_calls = r$observed$block_calls,
      observed_provider_reopen_current = ro$current$observed$provider %||% NA_character_, observed_provider_reopen_block = ro$block$observed$provider %||% NA_character_,
      reopen_error_current = ro$current$error %||% NA_character_, reopen_error_block = ro$block$error %||% NA_character_,
      first_status = r$after_first$status, final_status = f$status, first_error = r$first_error, resume_error = r$resume_error,
      diagnostic_rows = nrow(f$diagnostics), decision_rows = sum(f$diagnostics$stage == "decision"), execution_rows = sum(f$diagnostics$stage == "execution"),
      error_rows = sum(f$diagnostics$outcome == "error"), pulses_with_diagnostics = length(unique(f$diagnostics$ts_utc)),
      event_rows = nrow(f$events), fill_events = sum(f$events$event_type == "FILL"), equity_rows = nrow(f$equity), completion_rows = nrow(f$completion),
      seq_continuous = seq_ok(f$diagnostics),
      diagnostics_identical_to_direct = same(f$diagnostics, direct_peer$diagnostics), diagnostics_identical_to_current_arm = same(f$diagnostics, peer$final$diagnostics),
      diagnostics_identical_across_chunk = if (is.null(chunk_peer)) NA else same(f$diagnostics, chunk_peer$diagnostics),
      events_identical_to_current_arm = same(f$events, peer$final$events), equity_identical_to_current_arm = same(f$equity, peer$final$equity),
      state_identical_to_current_arm = same(f$state, peer$final$state), completion_identical_to_current_arm = same(f$completion, peer$final$completion),
      identity_identical_to_current_arm = same(f$identity, peer$final$identity),
      session_reader_matches_store = same(r$session_diagnostics, f$diagnostics),
      reopen_same_arm_matches_session = same(ro[[arm]]$diagnostics, r$session_diagnostics),
      availability_reopen_arms_identical = same(ro$current$availability, ro$block$availability),
      explain_reopen_arms_identical = same(ro$current$explained, ro$block$explained),
      availability_identical_to_current_arm = same(ro[[arm]]$availability, po$current$availability),
      explain_identical_to_current_arm = same(ro[[arm]]$explained, po$current$explained),
      stringsAsFactors = FALSE)
  })
  cases_df <- do.call(rbind, rows); rownames(cases_df) <- NULL
  utils::write.csv(cases_df, file.path(evidence, "cases.csv"), row.names = FALSE)
  ref <- direct$diagnostics
  for (nm in c("ts_utc", "decision_ts_utc", "execution_ts_utc")) ref[[nm]] <- iso(ref[[nm]])
  utils::write.csv(ref, file.path(evidence, "diagnostics_reference.csv"), row.names = FALSE)
  cov <- do.call(rbind, lapply(names(results), function(nm) census(results[[nm]]$final$diagnostics, sub(" .*$", "", nm), sub("^.* ", "", nm))))
  utils::write.csv(cov, file.path(evidence, "coverage.csv"), row.names = FALSE)
  sv <- do.call(rbind, lapply(names(results), function(nm) setv_rows(results[[nm]]$setv, sub(" .*$", "", nm), sub("^.* ", "", nm))))
  utils::write.csv(sv, file.path(evidence, "setv_trace.csv"), row.names = FALSE)
  print(cases_df[, c("scenario", "chunk_rows", "selected_arm", "observed_mode_run", "scalar_calls", "block_calls", "final_status", "diagnostic_rows",
                     "seq_continuous", "diagnostics_identical_to_current_arm", "diagnostics_identical_across_chunk", "identity_identical_to_current_arm",
                     "availability_reopen_arms_identical", "explain_reopen_arms_identical")], row.names = FALSE)
  print(sv, row.names = FALSE)
  invisible(cases_df)
}

# ---------------------------------------------------------------------------
# Child processes: regression tests and 757-pulse folds.
# ---------------------------------------------------------------------------

child_tests <- function(arm, out) {
  load_package(); set_arm(arm); install_observer()
  res <- as.data.frame(testthat::test_local(repo_root, filter = "^availability", reporter = "silent", stop_on_failure = FALSE, load_package = "none"))
  res <- res[, c("file", "test", "nb", "failed", "skipped", "error", "warning", "passed")]
  yyjsonr::write_json_file(list(arm = arm, observed = take_observed(), results = res, collapse = environment_row()$collapse,
                                mirai_available = requireNamespace("mirai", quietly = TRUE)), out)
}

child_fold <- function(arm, template_db, run_db, run_id, marker, out, prof = NULL) {
  load_package(); set_arm(arm); install_observer()
  file.copy(template_db, run_db, overwrite = TRUE)
  snapshot <- ledgr::ledgr_snapshot_open(run_db, "spike", verify = TRUE)
  exp <- ledgr::ledgr_experiment(snapshot, function(ctx, params) ctx$flat(), universe = ledgr::ledgr_universe_members("synthetic_members"),
    valuation_policy = ledgr::ledgr_valuation_stale(max_sessions = 2L), cost_model = ledgr::ledgr_cost_zero(), opening = ledgr::ledgr_opening(cash = 1e6))
  invisible(gc(full = TRUE)); reset_observed()
  if (!is.null(prof)) Rprof(prof, interval = 0.02, memory.profiling = TRUE, line.profiling = TRUE, gc.profiling = TRUE)
  writeLines(format(Sys.time()), marker)
  t0 <- proc.time()[["elapsed"]]
  bt <- ledgr::ledgr_run(exp, run_id = run_id)
  wall <- proc.time()[["elapsed"]] - t0
  if (!is.null(prof)) Rprof(NULL)
  observed <- take_observed()
  info <- ledgr::ledgr_run_info(snapshot, run_id)
  telemetry <- ledgr:::ledgr_get_run_telemetry(run_id)
  diagnostics <- ledgr::ledgr_results(bt, "diagnostics")
  lanes <- if (!is.null(prof)) parse_rprof(prof) else NULL
  result <- list(arm = arm, run_id = run_id, wall_seconds = wall, t_loop_seconds = as.numeric(telemetry$t_loop %||% NA_real_),
                 status = as.character(info$status), decision_rows = sum(diagnostics$stage == "decision"), diagnostic_rows = nrow(diagnostics),
                 pulses_with_diagnostics = length(unique(diagnostics$ts_utc)), observed_mode = observed$mode, observed_provider = observed$provider,
                 scalar_calls = observed$scalar_calls, block_calls = observed$block_calls, collapse = environment_row()$collapse, lanes = lanes)
  yyjsonr::write_json_file(result, out, auto_unbox = TRUE)
  close(bt); ledgr::ledgr_snapshot_close(snapshot)
  cat("child_ok", arm, run_id, round(wall, 2), "\n")
}

# Lane classifier: the provider spike's classifier with the block constructor,
# the segment accumulator, and append_block() in the diagnostic lanes.
classify_sample <- function(fns) {
  has <- function(x) any(x %in% fns)
  if (has(c("ledgr_availability_provider_build", "ledgr_availability_provider_build_prepared", "ledgr_availability_provider_build_current",
            "ledgr_availability_prepared_membership", "ledgr_availability_prepared_segments"))) return("provider_build")
  if (!has("run_transaction")) return("outside_loop")
  if (has(c("ledgr_membership_resolve_at", "ledgr_availability_members_at", "prepared_members_at", "members_at"))) return("provider_membership")
  if (has(c("ledgr_availability_status_at", "ledgr_availability_lifetime_at", "ledgr_availability_terminal_event_at", "ledgr_availability_restrictions",
            "prepared_facts", "prepared_seek", "prepared_read", "facts", "seek", "read"))) return("provider_status_lifetime")
  if (has("ledgr_availability_valuation_marks")) return("valuation")
  if (has(c("write_run_diagnostics", "write_run_evidence"))) return("duckdb_diag_append")
  if (has(c("ledgr_availability_diagnostic_block", "ledgr_availability_diagnostic_row", "ledgr_availability_diagnostic_fields", "diag_row",
            "add_segment", "append_decision_trace"))) return("diag_construct")
  if (has(c("append_diagnostic", "append_block", "flush_pulse_block", "put"))) return("diag_append_retain")
  if (has(c("rbind", "rbind.data.frame", "drain", "build")) && !has("flush_pending")) return("final_bind")
  if (has(c("decision_view", "execution_view"))) return("provider_other")
  "residual_fold"
}
LANES <- c("provider_build", "provider_membership", "provider_status_lifetime", "provider_other", "valuation", "diag_construct",
           "diag_append_retain", "final_bind", "duckdb_diag_append", "residual_fold", "outside_loop")
parse_rprof <- function(path) {
  lines <- readLines(path, warn = FALSE)
  interval_us <- as.numeric(sub(".*sample.interval=", "", lines[[1L]]))
  samples <- lines[startsWith(lines, ":")]
  prefix_re <- "^:[0-9]+:[0-9]+:[0-9]+:[0-9]+:"
  tokens <- strsplit(trimws(sub(prefix_re, "", samples)), " +")
  fns <- lapply(tokens, function(t) sub("^.*[$:]", "", gsub('"', "", t[startsWith(t, '"')], fixed = TRUE)))
  lane <- vapply(fns, classify_sample, character(1))
  per_lane <- do.call(rbind, lapply(LANES, function(l) { s <- lane == l
    data.frame(lane = l, samples = sum(s), seconds = sum(s) * interval_us / 1e6, stringsAsFactors = FALSE) }))
  list(interval_us = interval_us, n_samples = length(samples), in_loop_samples = sum(!lane %in% c("outside_loop", "provider_build")), lanes = per_lane)
}

# ---------------------------------------------------------------------------
# Parent phases.
# ---------------------------------------------------------------------------

tests_phase <- function(evidence) {
  rows <- list(); att <- list()
  for (arm in ARMS) {
    cat(sprintf("regression tests under %s ...\n", arm))
    r <- run_child_json(c("--child-tests", arm))
    res <- as.data.frame(r$result$results); res$arm <- arm
    rows[[arm]] <- res
    o <- r$result$observed
    att[[arm]] <- data.frame(arm = arm, observed_modes = o$mode %||% NA_character_, observed_providers = o$provider %||% NA_character_,
                             scalar_calls = o$scalar_calls, block_calls = o$block_calls, mirai_available = isTRUE(r$result$mirai_available), stringsAsFactors = FALSE)
    cat(sprintf("  %d tests, %d failed, %d errored, %d skipped; modes %s; scalar %d block %d\n", nrow(res), sum(res$failed > 0), sum(res$error), sum(res$skipped),
                o$mode, o$scalar_calls, o$block_calls))
  }
  df <- do.call(rbind, rows); rownames(df) <- NULL
  optional <- df$test %in% OPTIONAL_TESTS
  utils::write.csv(df[!optional, c("arm", "file", "test", "nb", "failed", "skipped", "error", "warning", "passed")], file.path(evidence, "regression_tests.csv"), row.names = FALSE)
  opt <- df[optional, , drop = FALSE]; opt$ran <- !opt$skipped
  utils::write.csv(opt[, c("arm", "file", "test", "ran", "nb", "failed", "skipped", "error", "passed")], file.path(evidence, "regression_optional.csv"), row.names = FALSE)
  utils::write.csv(do.call(rbind, att), file.path(evidence, "regression_attestation.csv"), row.names = FALSE)
  invisible(df)
}

# Persisted-output parity between two run stores holding the same run ID:
# DuckDB multiset difference per table with no column excluded; the identity
# row is compared in R after dropping exactly the creation time and the two
# embedded store locators.
compare_stores <- function(db_current, db_block, run_id) {
  con <- DBI::dbConnect(duckdb::duckdb(), ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(con, sprintf("ATTACH '%s' AS cur (READ_ONLY)", db_current))
  DBI::dbExecute(con, sprintf("ATTACH '%s' AS blk (READ_ONLY)", db_block))
  ident <- lapply(c("cur", "blk"), function(db) normalize_identity(DBI::dbGetQuery(con, sprintf("SELECT * FROM %s.runs WHERE run_id = ?", db), params = list(run_id))))
  same_identity <- nrow(ident[[1L]]) == 1L && nrow(ident[[2L]]) == 1L && identical(ident[[1L]], ident[[2L]])
  runs_row <- data.frame(table = "runs", columns_compared = ncol(ident[[1L]]), excluded = paste(c(IDENTITY_EXCLUDED, paste0("config_json.", IDENTITY_JSON_EXCLUDED)), collapse = "|"),
                         rows_current = nrow(ident[[1L]]), rows_block = nrow(ident[[2L]]), only_in_current = as.integer(!same_identity), only_in_block = as.integer(!same_identity),
                         identical = same_identity, stringsAsFactors = FALSE)
  rbind(runs_row, do.call(rbind, lapply(c("run_completion", "run_diagnostics", "ledger_events", "equity_curve", "strategy_state"), function(t) {
    cols <- DBI::dbGetQuery(con, "SELECT column_name FROM duckdb_columns() WHERE database_name = 'cur' AND table_name = ? ORDER BY column_index", params = list(t))$column_name
    sel <- paste(sprintf('"%s"', cols), collapse = ", ")
    n <- function(db) DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM %s.%s WHERE run_id = ?", db, t), params = list(run_id))$n
    only <- function(a, b) DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM (SELECT %s FROM %s.%s WHERE run_id = ? EXCEPT ALL SELECT %s FROM %s.%s WHERE run_id = ?)",
                                                        sel, a, t, sel, b, t), params = list(run_id, run_id))$n
    rc <- n("cur"); rb <- n("blk"); oc <- only("cur", "blk"); ob <- only("blk", "cur")
    data.frame(table = t, columns_compared = length(cols), excluded = "", rows_current = rc, rows_block = rb, only_in_current = oc, only_in_block = ob,
               identical = rc == rb && oc == 0L && ob == 0L, stringsAsFactors = FALSE)
  })))
}

# The registered store is sealed once per process (the cold clock, reported
# separately and outside the comparison) and copied per run.
TEMPLATE <- new.env()
seal_template <- function() {
  if (!is.null(TEMPLATE$path) && file.exists(TEMPLATE$path)) return(TEMPLATE$path)
  template <- tempfile("spike_template_", fileext = ".duckdb")
  cat("sealing the registered 757-pulse store once (cold clock, outside the comparison) ...\n"); t0 <- proc.time()[["elapsed"]]
  snapshot <- open_snapshot(registered_fold_fixture()$fixture, template); ledgr::ledgr_snapshot_close(snapshot)
  TEMPLATE$seconds <- proc.time()[["elapsed"]] - t0; TEMPLATE$path <- template
  cat(sprintf("  sealed in %.0f s\n", TEMPLATE$seconds))
  template
}
cleanup_template <- function() if (!is.null(TEMPLATE$path)) unlink(c(TEMPLATE$path, paste0(TEMPLATE$path, ".wal")), force = TRUE)

fold757_phase <- function(evidence) {
  template <- seal_template()
  runs <- list()
  for (arm in ARMS) for (rep in c("warmup", "run1", "run2", "run3", if (identical(arm, "block")) "profiled")) runs[[length(runs) + 1L]] <- list(arm = arm, rep = rep, profile = identical(rep, "profiled"))
  rows <- list(); lanes <- NULL
  for (rn in runs) {
    run_db <- tempfile("spike_fold_", fileext = ".duckdb"); marker <- tempfile("spike_marker_"); prof <- tempfile("spike_prof_", fileext = ".prof")
    run_id <- paste0("spike-757-", rn$arm, "-", rn$rep)
    cat(sprintf("fold757 %-8s %-9s ...\n", rn$arm, rn$rep))
    r <- run_child_json(c("--child-fold", rn$arm, template, run_db, run_id, marker, if (rn$profile) prof), wall_ceiling = WALL_STOP_S, ws_ceiling = WS_STOP_MIB, marker = marker)
    x <- r$result
    store <- if (file.exists(run_db)) tryCatch(read_store(run_db, run_id), error = function(e) NULL) else NULL
    rows[[length(rows) + 1L]] <- data.frame(arm = rn$arm, repetition = rn$rep, measured = rn$rep %in% c("run1", "run2", "run3"), profiled = rn$profile,
      killed = r$killed %||% "", run_elapsed_s = r$run_elapsed_s, wall_seconds = x$wall_seconds %||% NA_real_, t_loop_seconds = x$t_loop_seconds %||% NA_real_,
      peak_ws_mib = r$peak_ws_mib, status = x$status %||% (store$status %||% NA_character_), store_diagnostic_rows = if (is.null(store)) NA_integer_ else nrow(store$diagnostics),
      decision_rows = x$decision_rows %||% NA_integer_, pulses_with_diagnostics = x$pulses_with_diagnostics %||% NA_integer_,
      observed_mode = x$observed_mode %||% NA_character_, observed_provider = x$observed_provider %||% NA_character_,
      scalar_calls = x$scalar_calls %||% NA_integer_, block_calls = x$block_calls %||% NA_integer_, collapse = x$collapse %||% NA_character_,
      seal_seconds = TEMPLATE$seconds, within_stop = !nzchar(r$killed %||% ""), stringsAsFactors = FALSE)
    if (!is.null(x$lanes)) lanes <- x$lanes
    unlink(c(run_db, paste0(run_db, ".wal"), prof), force = TRUE)
    cat(sprintf("  killed='%s' wall %.1f s  t_loop %.1f s  peak WS %.1f MiB  status %s  mode %s  scalar %s block %s\n", r$killed %||% "", x$wall_seconds %||% NA_real_,
                x$t_loop_seconds %||% NA_real_, r$peak_ws_mib, x$status %||% NA_character_, x$observed_mode %||% NA_character_, x$scalar_calls %||% NA, x$block_calls %||% NA))
  }
  df <- do.call(rbind, rows); utils::write.csv(df, file.path(evidence, "fold_757.csv"), row.names = FALSE)
  if (!is.null(lanes)) {
    l <- as.data.frame(lanes$lanes); l$share_in_loop <- ifelse(l$lane %in% c("outside_loop", "provider_build"), 0, l$samples / lanes$in_loop_samples)
    utils::write.csv(l, file.path(evidence, "lanes_757.csv"), row.names = FALSE)
    print(l[order(-l$samples), ], row.names = FALSE)
  }
  for (arm in ARMS) {
    m <- df[df$measured & df$arm == arm, ]
    cat(sprintf("%s median wall %.2f s (spread %.2f), peaks %s MiB\n", arm, stats::median(m$wall_seconds), diff(range(m$wall_seconds)), paste(round(m$peak_ws_mib, 1), collapse = "/")))
  }
  invisible(df)
}

# One explicitly non-measured 757-pulse pair with a shared run ID whose stores
# are kept until every persisted table has been compared (Charter v2, claim 6).
fold757parity_phase <- function(evidence) {
  template <- seal_template()
  run_id <- "spike-757-block-parity"
  dbs <- list(); meta <- list()
  for (arm in ARMS) {
    run_db <- tempfile(paste0("spike_parity_", arm, "_"), fileext = ".duckdb"); marker <- tempfile("spike_marker_")
    cat(sprintf("fold757parity %-8s (not measured) ...\n", arm))
    r <- run_child_json(c("--child-fold", arm, template, run_db, run_id, marker), wall_ceiling = WALL_STOP_S, ws_ceiling = WS_STOP_MIB, marker = marker)
    dbs[[arm]] <- run_db
    meta[[arm]] <- list(status = r$result$status %||% NA_character_, mode = r$result$observed_mode %||% NA_character_, provider = r$result$observed_provider %||% NA_character_,
                        scalar_calls = r$result$scalar_calls %||% NA_integer_, block_calls = r$result$block_calls %||% NA_integer_, killed = r$killed %||% "")
    cat(sprintf("  status %s mode %s scalar %s block %s killed='%s'\n", meta[[arm]]$status, meta[[arm]]$mode, meta[[arm]]$scalar_calls, meta[[arm]]$block_calls, meta[[arm]]$killed))
  }
  on.exit(unlink(c(unlist(dbs), paste0(unlist(dbs), ".wal")), force = TRUE), add = TRUE)
  df <- compare_stores(dbs$current, dbs$block, run_id)
  df$run_id <- run_id
  for (arm in ARMS) for (k in c("status", "mode", "provider", "scalar_calls", "block_calls")) df[[paste(k, arm, sep = "_")]] <- meta[[arm]][[k]]
  utils::write.csv(df, file.path(evidence, "fold_757_parity.csv"), row.names = FALSE)
  print(df[, c("table", "columns_compared", "excluded", "rows_current", "rows_block", "only_in_current", "only_in_block", "identical")], row.names = FALSE)
  invisible(df)
}

write_fixture_csv <- function(evidence) {
  sem <- block_semantic_fixture(); reg <- registered_fold_fixture()
  row <- function(name, ...) data.frame(fixture = name, ..., stringsAsFactors = FALSE)
  fx <- rbind(
    row("semantic", n_instruments = length(sem$ids), n_sessions = length(sem$dates), universe = "U (snapshots)",
        formula = sprintf("provider spike semantic_fixture() and semantic_strategy(); bar of %s at session %d removed; chunk_rows %d (S1 also at %d)",
                          MISSING_BAR$instrument_id, MISSING_BAR$session, SEMANTIC_CHUNK_ROWS, DEFAULT_CHUNK_ROWS),
        counts = paste(names(sem$counts), sem$counts, sep = "=", collapse = " ")),
    row("fold757_static", n_instruments = reg$spec$n_instruments, n_sessions = reg$spec$n_sessions, universe = "synthetic_members (60 identical complete lists)",
        formula = paste("writer spike_fixture(FIXTURES$envelope757);", reg$formula, "; flat targets; chunk_rows", DEFAULT_CHUNK_ROWS),
        counts = sprintf("headers=%d membership_rows=%d status_facts=%d lifetime_facts=%d", reg$spec$n_lists, reg$spec$n_lists * reg$spec$n_members,
                         reg$spec$n_instruments, reg$spec$n_instruments)))
  fx$envelope <- sprintf("block median fold_wall_s<=%d and current_median - block_median > diff(range(current measured walls)); every measured peak_ws_mib<=%d; current-arm stop %d s / %d MiB",
                         ENVELOPE$fold_wall_s, ENVELOPE$peak_ws_mib, WALL_STOP_S, WS_STOP_MIB)
  utils::write.csv(fx, file.path(evidence, "fixture.csv"), row.names = FALSE)
  env <- environment_row(); env$head <- system2("git", c("-C", shQuote(repo_root), "rev-parse", "HEAD"), stdout = TRUE)
  utils::write.csv(env, file.path(evidence, "environment.csv"), row.names = FALSE)
  print(fx[, c("fixture", "n_instruments", "n_sessions", "counts")], row.names = FALSE)
}

# ---------------------------------------------------------------------------
# Entry.
# ---------------------------------------------------------------------------

if (length(args) >= 1L && startsWith(args[[1L]], "--child")) {
  switch(args[[1L]],
    "--child-tests" = child_tests(args[[2L]], args[[3L]]),
    "--child-fold" = child_fold(args[[2L]], args[[3L]], args[[4L]], args[[5L]], args[[6L]], out = args[[length(args)]], prof = if (length(args) >= 8L) args[[7L]] else NULL),
    stop("unknown child mode"))
} else {
  mode <- if (length(args) >= 1L) args[[1L]] else "all"
  dir.create(evidence_dir, recursive = TRUE, showWarnings = FALSE)
  load_package(); set_arm("current"); install_observer()
  cat("spike_runner", mode, "\n")
  cat("HEAD:", system2("git", c("-C", shQuote(repo_root), "rev-parse", "HEAD"), stdout = TRUE), "\n")
  cat("R:", R.version.string, " collapse:", as.character(utils::packageVersion("collapse")), " duckdb:", as.character(utils::packageVersion("duckdb")), "\n")
  write_fixture_csv(evidence_dir)
  if (mode %in% c("semantic", "all")) semantic_phase(evidence_dir)
  if (mode %in% c("tests", "all")) tests_phase(evidence_dir)
  if (mode %in% c("fold757", "all")) fold757_phase(evidence_dir)
  if (mode %in% c("fold757parity", "all")) fold757parity_phase(evidence_dir)
  cleanup_template()
  cat("spike_runner done:", mode, "\n")
}
