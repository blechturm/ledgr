# Comparative spike runner for the availability hot-path representation RFC,
# executed under Charter v2 (rfc_availability_hot_path_representation_v0_2_0_x_spike_charter_v2.md).
#
# Two arms, one seam (R/availability-diagnostic-writer.R selected by
# options(ledgr.internal.spike_diagnostic_writer)):
#   rows      current production list-of-one-row-data-frames path (default);
#   columnar  the one chartered bounded columnar/chunked writer.
#
# Usage, from the repository root:
#   Rscript dev/spikes/availability-hot-path-representation/spike_runner.R semantic
#   Rscript dev/spikes/availability-hot-path-representation/spike_runner.R measure40
#   Rscript dev/spikes/availability-hot-path-representation/spike_runner.R envelope757
#   Rscript dev/spikes/availability-hot-path-representation/spike_runner.R all
#   Rscript ... spike_runner.R <mode> --evidence <dir>   (default: evidence/ beside this file)
#
# Evidence CSVs written to the evidence directory:
#   fixture.csv          registered fixture shapes and the list-distribution formula
#   cases.csv            one row per semantic case and arm: statuses, row counts, equality flags
#   diagnostics_40_rows.csv   the rows-arm 40-pulse direct-run diagnostics (reference table)
#   measurements_40.csv  per-run wall, t_loop, peak working set at 40 pulses
#   envelope_757.csv     per-arm 757-pulse envelope run: wall, peak WS, killed, status
#   lanes_757.csv        lane shares of the profiled columnar run at 757 pulses
# Timing columns vary between hosts and runs; the checker diffs the semantic
# evidence exactly and the measurement evidence structurally.
#
# Case history (spike_protocol.md section 3): the first fork run generated four
# harness corrections, none of them writer defects: tables are compared with
# run_id removed because each case carries its own run ID; the reopen claim is
# compared through the public reader path on both sides; the resume-then-fail
# case keeps one strategy source and injects through options, because a
# changed strategy changes config_hash and ledgr refuses to resume; and the
# interrupt/resume case compares the resumed run to the rows arm for tables
# ledgr writes per invocation.
#
# Identity is ledgr's own: run IDs, snapshot hashes, and run-store rows.
# No hash ledger, registry, or workspace gate.

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

ARMS <- c("rows", "columnar")
CHUNK_ROWS <- 4096L
SMALL_CHUNK <- 100L
WALL_CEILING_S <- 1800
WS_CEILING_MIB <- 4096
LIST_FORMULA <- "session_index = 1 + (0:(n_lists - 1)) * (n_sessions %/% n_lists)"

FIXTURES <- list(
  compare40 = list(n_instruments = 563L, n_members = 505L, n_sessions = 40L, n_lists = 4L),
  envelope757 = list(n_instruments = 563L, n_members = 505L, n_sessions = 757L, n_lists = 60L)
)

`%||%` <- function(a, b) if (is.null(a)) b else a

# ---------------------------------------------------------------------------
# Fixture: public, deterministic, production-shaped (lane-profile construction).
# ---------------------------------------------------------------------------

spike_fixture <- function(spec) {
  ids <- sprintf("I%03d", seq_len(spec$n_instruments))
  members <- ids[seq_len(spec$n_members)]
  first <- as.Date("2021-01-04")
  civil <- seq(first, by = "day", length.out = as.integer(ceiling(spec$n_sessions * 7 / 5)) + 7L)
  open <- as.POSIXlt(civil)$wday %in% 1:5
  civil <- civil[seq_len(which(cumsum(open) == spec$n_sessions)[[1L]])]
  open <- as.POSIXlt(civil)$wday %in% 1:5
  stopifnot(sum(open) == spec$n_sessions)
  session_dates <- civil[open]
  publish <- as.POSIXct("2021-01-01 00:00:00", tz = "UTC")
  sessions <- data.frame(
    session_date = civil, status = ifelse(open, "open", "closed"),
    session_open = ifelse(open, "14:30:00", NA_character_),
    session_close = ifelse(open, "21:00:00", NA_character_),
    knowledge_time = publish, source = "synthetic_calendar", stringsAsFactors = FALSE
  )
  n_inst <- spec$n_instruments
  inst_idx <- rep(seq_len(n_inst), times = spec$n_sessions)
  sess_idx <- rep(seq_len(spec$n_sessions), each = n_inst)
  close <- 100 + (inst_idx %% 7) + 0.01 * sess_idx
  bars <- data.frame(
    ts_utc = rep(as.POSIXct(paste(session_dates, "21:00:00"), tz = "UTC"), each = n_inst),
    instrument_id = rep(ids, times = spec$n_sessions),
    open = close, high = close + 0.5, low = close - 0.5, close = close, volume = 1e5,
    stringsAsFactors = FALSE
  )
  list_idx <- 1L + (seq_len(spec$n_lists) - 1L) * (spec$n_sessions %/% spec$n_lists)
  list_at <- session_dates[list_idx]
  membership <- data.frame(
    instrument_id = rep(members, times = spec$n_lists),
    effective_from = rep(as.POSIXct(paste(list_at, "00:00:00"), tz = "UTC"), each = spec$n_members),
    knowledge_time = rep(as.POSIXct(paste(list_at - 1, "00:00:00"), tz = "UTC"), each = spec$n_members),
    source = "synthetic_membership", stringsAsFactors = FALSE
  )
  window_start <- as.POSIXct(paste(session_dates[[1L]], "00:00:00"), tz = "UTC")
  status <- data.frame(instrument_id = ids, effective_from = window_start, knowledge_time = publish,
                       status = "active", source = "synthetic_status", stringsAsFactors = FALSE)
  lifetime <- data.frame(instrument_id = ids, effective_from = window_start, knowledge_time = publish,
                         assertion = "known_active", source = "synthetic_lifetime", stringsAsFactors = FALSE)
  facts <- ledgr::ledgr_facts(
    ledgr::ledgr_facts_sessions(sessions, "SYNTH", timezone = "UTC"),
    ledgr::ledgr_facts_membership_snapshots(membership, "synthetic_members", complete = TRUE),
    ledgr::ledgr_facts_trading_status(status),
    ledgr::ledgr_facts_lifetime(lifetime)
  )
  list(bars = bars, instruments = data.frame(instrument_id = ids, stringsAsFactors = FALSE),
       facts = facts, session_dates = session_dates, list_idx = list_idx)
}

# One strategy source for every semantic run so config_hash is stable across
# interruption and resume; interruption and failure are injected through
# options, as the package's own interruption test does.
spike_strategy <- function(ctx, params) {
  if (identical(ctx$ts_utc, getOption("ledgr.spike.interrupt_at", ""))) options(ledgr.interrupt = TRUE)
  if (identical(ctx$ts_utc, getOption("ledgr.spike.fail_at", ""))) stop("injected fold failure")
  ctx$flat()
}
flat_strategy <- function(ctx, params) ctx$flat()

set_arm <- function(arm, chunk = CHUNK_ROWS) {
  options(ledgr.internal.spike_diagnostic_writer = arm, ledgr.internal.spike_diagnostic_chunk_rows = chunk)
}

open_snapshot <- function(fx, db_path) {
  ledgr::ledgr_snapshot_from_df(fx$bars, instruments_df = fx$instruments, db_path = db_path,
                                snapshot_id = "spike", facts = fx$facts)
}

experiment_for <- function(snapshot, strategy = flat_strategy) {
  ledgr::ledgr_experiment(snapshot, strategy,
    universe = ledgr::ledgr_universe_members("synthetic_members"),
    valuation_policy = ledgr::ledgr_valuation_stale(max_sessions = 2L),
    cost_model = ledgr::ledgr_cost_zero(), opening = ledgr::ledgr_opening(cash = 1e6))
}

read_store <- function(db_path, run_id) {
  con <- DBI::dbConnect(duckdb::duckdb(), db_path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  q <- function(sql) DBI::dbGetQuery(con, sql, params = list(run_id))
  list(
    status = q("SELECT status FROM runs WHERE run_id = ?")$status,
    diagnostics = q("SELECT * FROM run_diagnostics WHERE run_id = ? ORDER BY diagnostic_seq"),
    events = q("SELECT * FROM ledger_events WHERE run_id = ? ORDER BY event_seq"),
    equity = q("SELECT * FROM equity_curve WHERE run_id = ? ORDER BY ts_utc"),
    state = q("SELECT * FROM strategy_state WHERE run_id = ? ORDER BY ts_utc"),
    completion = q("SELECT * FROM run_completion WHERE run_id = ?")
  )
}

# ---------------------------------------------------------------------------
# Semantic cases (in-process, both arms, fresh scratch store per run).
# ---------------------------------------------------------------------------

sessions_iso <- function(fx, i) format(as.POSIXct(paste(fx$session_dates[[i]], "21:00:00"), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ")

run_invocation <- function(exp, run_id) {
  bt <- NULL
  err <- tryCatch({ bt <- ledgr::ledgr_run(exp, run_id = run_id); NA_character_ }, error = function(e) conditionMessage(e))
  session <- if (!is.null(bt)) as.data.frame(ledgr::ledgr_results(bt, "diagnostics")) else NULL
  if (!is.null(bt)) close(bt)
  list(error = err, session_diagnostics = session)
}

run_case <- function(arm, fx, run_id, chunk = CHUNK_ROWS, interrupt_at = NULL, resume_fail_at = NULL, fail_at = NULL) {
  set_arm(arm, chunk)
  prior <- options(ledgr.interrupt = FALSE, ledgr.spike.interrupt_at = interrupt_at %||% "", ledgr.spike.fail_at = fail_at %||% "")
  on.exit(options(prior), add = TRUE)
  db <- tempfile(paste0("spike_", arm, "_"), fileext = ".duckdb")
  snapshot <- open_snapshot(fx, db)
  exp <- experiment_for(snapshot, spike_strategy)
  first <- run_invocation(exp, run_id)
  after_first <- read_store(db, run_id)
  resumed <- NULL; resume <- list(error = NA_character_, session_diagnostics = NULL)
  if (!is.null(interrupt_at)) {
    options(ledgr.interrupt = FALSE, ledgr.spike.interrupt_at = "", ledgr.spike.fail_at = resume_fail_at %||% "")
    resume <- run_invocation(exp, run_id)
    resumed <- read_store(db, run_id)
  }
  final <- resumed %||% after_first
  # The public reader output belongs to the invocation that produced the final
  # state; a failed invocation has no handle, so the flag is NA rather than a
  # comparison against the earlier invocation's output.
  session_diagnostics <- if (!is.null(interrupt_at)) resume$session_diagnostics else first$session_diagnostics
  reopened <- NULL; explained <- NULL
  ledgr::ledgr_snapshot_close(snapshot)
  if (identical(final$status, "DONE")) {
    snap2 <- ledgr::ledgr_snapshot_open(db, "spike", verify = TRUE)
    bt2 <- ledgr::ledgr_run_open(snap2, run_id)
    reopened <- as.data.frame(ledgr::ledgr_results(bt2, "diagnostics"))
    # ledgr_run_explain() rebuilds the full availability table per call, so
    # three cells across the horizon (first, middle, last decision row) carry
    # the equality claim at a bounded cost.
    cells <- final$diagnostics[final$diagnostics$stage == "decision", , drop = FALSE]
    pick <- unique(round(seq(1L, nrow(cells), length.out = 3L)))
    explained <- do.call(rbind, lapply(pick, function(i) as.data.frame(ledgr::ledgr_run_explain(bt2, cells$instrument_id[[i]], cells$ts_utc[[i]]))))
    close(bt2); ledgr::ledgr_snapshot_close(snap2)
  }
  unlink(c(db, paste0(db, ".wal")), force = TRUE)
  list(arm = arm, run_id = run_id, first_error = first$error, after_first = after_first, resume_error = resume$error,
       final = final, session_diagnostics = session_diagnostics, reopened = reopened, explained = explained)
}

# Comparisons drop run_id (each case has its own run ID) and the reader-only
# ledgr_result_type attribute that ledgr_results() attaches; values, types,
# order, and row counts are compared exactly.
strip_id <- function(df) {
  if (is.data.frame(df)) { if ("run_id" %in% names(df)) df$run_id <- NULL; attr(df, "ledgr_result_type") <- NULL }
  df
}
same <- function(a, b) if (is.null(a) || is.null(b)) NA else identical(strip_id(a), strip_id(b))
seq_ok <- function(d) identical(as.integer(d$diagnostic_seq), seq_len(nrow(d)))

semantic_phase <- function(fx, evidence) {
  cases <- list(
    list(id = "C1_direct", chunk = CHUNK_ROWS),
    list(id = "C2_direct_small_chunk", chunk = SMALL_CHUNK, arms = "columnar"),
    list(id = "C3_interrupt_resume", interrupt = 20L, chunk = CHUNK_ROWS),
    list(id = "C4_exception_rollback", fail = 25L, chunk = CHUNK_ROWS),
    list(id = "C5_resume_then_exception", interrupt = 10L, resume_fail = 25L, chunk = CHUNK_ROWS)
  )
  results <- list()
  for (cs in cases) for (arm in cs$arms %||% ARMS) {
    cat(sprintf("case %-26s arm %-8s ... ", cs$id, arm)); t0 <- proc.time()[["elapsed"]]
    r <- run_case(arm, fx, run_id = paste0("spike-", cs$id), chunk = cs$chunk,
                  interrupt_at = if (!is.null(cs$interrupt)) sessions_iso(fx, cs$interrupt),
                  resume_fail_at = if (!is.null(cs$resume_fail)) sessions_iso(fx, cs$resume_fail),
                  fail_at = if (!is.null(cs$fail)) sessions_iso(fx, cs$fail))
    results[[paste(cs$id, arm)]] <- r
    cat(sprintf("%.1f s status %s rows %d\n", proc.time()[["elapsed"]] - t0, r$final$status, nrow(r$final$diagnostics)))
  }
  direct <- results[["C1_direct rows"]]$final
  rows <- lapply(names(results), function(nm) {
    r <- results[[nm]]; cs_id <- sub(" .*$", "", nm); arm <- sub("^.* ", "", nm); f <- r$final
    peer <- results[[paste(cs_id, "rows")]]
    data.frame(
      case = cs_id, arm = arm, first_status = r$after_first$status, final_status = f$status,
      first_error = r$first_error, resume_error = r$resume_error,
      diagnostic_rows = nrow(f$diagnostics), decision_rows = sum(f$diagnostics$stage == "decision"),
      error_rows = sum(f$diagnostics$outcome == "error"), event_rows = nrow(f$events), equity_rows = nrow(f$equity),
      completion_rows = nrow(f$completion), seq_continuous = seq_ok(f$diagnostics),
      diagnostics_identical_to_direct = same(f$diagnostics, direct$diagnostics),
      diagnostics_identical_to_rows_arm = same(f$diagnostics, peer$final$diagnostics),
      events_identical_to_rows_arm = same(f$events, peer$final$events),
      equity_identical_to_rows_arm = same(f$equity, peer$final$equity),
      state_identical_to_rows_arm = same(f$state, peer$final$state),
      completion_identical_to_rows_arm = same(f$completion, peer$final$completion),
      session_reader_matches_store = same(r$session_diagnostics, f$diagnostics),
      reopened_matches_session = same(r$reopened, r$session_diagnostics),
      reopened_identical_to_rows_arm = same(r$reopened, peer$reopened),
      explained_identical_to_rows_arm = same(r$explained, peer$explained),
      stringsAsFactors = FALSE)
  })
  cases_df <- do.call(rbind, rows); rownames(cases_df) <- NULL
  utils::write.csv(cases_df, file.path(evidence, "cases.csv"), row.names = FALSE)
  ref_out <- direct$diagnostics
  for (nm in c("ts_utc", "decision_ts_utc", "execution_ts_utc")) ref_out[[nm]] <- format(ref_out[[nm]], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  utils::write.csv(ref_out, file.path(evidence, "diagnostics_40_rows.csv"), row.names = FALSE)
  print(cases_df[, c("case", "arm", "final_status", "diagnostic_rows", "error_rows", "equity_rows", "seq_continuous",
                     "diagnostics_identical_to_direct", "diagnostics_identical_to_rows_arm", "equity_identical_to_rows_arm",
                     "completion_identical_to_rows_arm", "reopened_matches_session", "explained_identical_to_rows_arm")], row.names = FALSE)
  invisible(cases_df)
}

# ---------------------------------------------------------------------------
# Sampled measurement in child processes (external working-set sampler).
# ---------------------------------------------------------------------------

sampler_ps1 <- '
param([string]$Exe, [string]$ChildArgsJoined, [string]$Marker, [double]$WallCeilingS, [double]$WsCeilingMiB, [int]$IntervalMs = 200)
$childArgs = $ChildArgsJoined.Split("|")
$p = Start-Process -FilePath $Exe -ArgumentList $childArgs -PassThru -NoNewWindow
$null = $p.Handle
$sampled = 0; $peak = 0; $n = 0; $killed = ""; $runStart = $null
while (-not $p.HasExited) {
  try { $p.Refresh(); $ws = $p.WorkingSet64; $pk = $p.PeakWorkingSet64
        if ($ws -gt $sampled) { $sampled = $ws }; if ($pk -gt $peak) { $peak = $pk }; $n++
        if ($null -eq $runStart -and (Test-Path $Marker)) { $runStart = Get-Date }
        if ($WsCeilingMiB -gt 0 -and ($ws / 1MB) -gt $WsCeilingMiB) { $killed = "working_set"; $p.Kill() }
        if ($WallCeilingS -gt 0 -and $null -ne $runStart -and ((Get-Date) - $runStart).TotalSeconds -gt $WallCeilingS) { $killed = "wall"; $p.Kill() }
  } catch {}
  Start-Sleep -Milliseconds $IntervalMs
}
$p.WaitForExit()
$elapsedRun = if ($null -ne $runStart) { ((Get-Date) - $runStart).TotalSeconds } else { -1 }
Write-Output ("PEAK_WS_BYTES=" + $peak)
Write-Output ("SAMPLED_MAX_WS_BYTES=" + $sampled)
Write-Output ("KILLED=" + $killed)
Write-Output ("RUN_ELAPSED_S=" + $elapsedRun)
Write-Output ("CHILD_EXIT=" + $p.ExitCode)
'

launch_child <- function(arm, fixture, run_id, profile = FALSE, wall_ceiling = 0, ws_ceiling = 0) {
  rscript <- file.path(R.home("bin"), "Rscript.exe")
  if (!file.exists(rscript)) rscript <- file.path(R.home("bin"), "x64", "Rscript.exe")
  ps1 <- tempfile("ws_sampler_", fileext = ".ps1"); writeLines(sampler_ps1, ps1)
  db <- tempfile("spike_child_", fileext = ".duckdb"); res <- tempfile("spike_child_", fileext = ".json")
  prof <- tempfile("spike_child_", fileext = ".prof"); marker <- tempfile("spike_child_", fileext = ".start")
  on.exit(unlink(c(ps1, db, paste0(db, ".wal"), res, prof, marker), force = TRUE), add = TRUE)
  child_args <- c(script_path, "--child", arm, fixture, run_id, db, res, marker, if (profile) c("--profile", prof))
  out <- system2("powershell", c("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", shQuote(ps1),
                                 "-Exe", shQuote(rscript), "-ChildArgsJoined", shQuote(paste(child_args, collapse = "|")),
                                 "-Marker", shQuote(marker), "-WallCeilingS", format(wall_ceiling), "-WsCeilingMiB", format(ws_ceiling),
                                 "-IntervalMs", "200"), stdout = TRUE, stderr = TRUE)
  grab <- function(key) sub(paste0("^", key, "="), "", grep(paste0("^", key, "="), out, value = TRUE))[1L]
  killed <- grab("KILLED"); exit <- as.numeric(grab("CHILD_EXIT"))
  result <- if (file.exists(res)) yyjsonr::read_json_file(res) else NULL
  if (is.null(result) && !nzchar(killed %||% "")) { cat(out, sep = "\n"); stop(sprintf("child %s/%s failed (exit %s)", arm, fixture, exit)) }
  store <- if (file.exists(db)) tryCatch(read_store(db, run_id), error = function(e) NULL) else NULL
  list(arm = arm, fixture = fixture, run_id = run_id, result = result, killed = killed,
       run_elapsed_s = as.numeric(grab("RUN_ELAPSED_S")), peak_ws_mib = as.numeric(grab("PEAK_WS_BYTES")) / 1024^2,
       store_status = store$status %||% NA_character_, store_diagnostic_rows = if (is.null(store)) NA_integer_ else nrow(store$diagnostics))
}

child_main <- function(arm, fixture, run_id, db, res, marker, prof = NULL) {
  options(keep.source = TRUE, keep.source.pkgs = TRUE, warn = 1)
  pkgload::load_all(repo_root, quiet = TRUE, export_all = TRUE)
  set_arm(arm)
  fx <- spike_fixture(FIXTURES[[fixture]])
  snapshot <- open_snapshot(fx, db)
  exp <- experiment_for(snapshot)
  assign("spike_actionable_total", 0L, envir = globalenv())
  suppressMessages(trace("ledgr_fold_build_availability_pulse_plan", where = asNamespace("ledgr"), print = FALSE,
    tracer = quote(assign("spike_actionable_total", get("spike_actionable_total", envir = globalenv()) + length(actionable_idx), envir = globalenv()))))
  invisible(gc(full = TRUE))
  if (!is.null(prof)) Rprof(prof, interval = if (identical(fixture, "envelope757")) 0.02 else 0.01,
                            memory.profiling = TRUE, line.profiling = TRUE, gc.profiling = TRUE)
  writeLines(format(Sys.time()), marker)
  t0 <- proc.time()[["elapsed"]]
  bt <- ledgr::ledgr_run(exp, run_id = run_id)
  wall <- proc.time()[["elapsed"]] - t0
  if (!is.null(prof)) Rprof(NULL)
  info <- ledgr::ledgr_run_info(snapshot, run_id)
  telemetry <- ledgr:::ledgr_get_run_telemetry(run_id)
  diagnostics <- ledgr::ledgr_results(bt, "diagnostics")
  fills <- ledgr::ledgr_results(bt, "fills")
  lanes <- if (!is.null(prof)) parse_rprof(prof) else NULL
  result <- list(arm = arm, fixture = fixture, run_id = run_id, wall_seconds = wall,
                 t_loop_seconds = as.numeric(telemetry$t_loop %||% NA_real_), status = as.character(info$status),
                 decision_rows = sum(diagnostics$stage == "decision"),
                 reconciliation_rows = sum(diagnostics$stage == "reconciliation"),
                 execution_rows = sum(diagnostics$stage == "execution"), fills = nrow(fills),
                 actionable_total = get("spike_actionable_total", envir = globalenv()),
                 execution_view_in_stacks = if (is.null(lanes)) NA_integer_ else lanes$execution_view_in_stacks,
                 lanes = lanes, r_version = R.version.string, collapse = as.character(utils::packageVersion("collapse")),
                 duckdb = as.character(utils::packageVersion("duckdb")))
  yyjsonr::write_json_file(result, res, auto_unbox = TRUE)
  close(bt); ledgr::ledgr_snapshot_close(snapshot)
  cat("child_ok", arm, fixture, run_id, round(wall, 2), "\n")
}

# Lane classifier extended for the writer seam (Charter v2 review note 1):
# the columnar writer's closures (append, put, flush, build, drain) and
# ledgr_availability_diagnostic_fields() stay in the diagnostic lane.
classify_sample <- function(fns) {
  has <- function(x) any(x %in% fns)
  if (!has("run_transaction")) return("outside_loop")
  if (has(c("ledgr_membership_resolve_at", "ledgr_availability_members_at"))) return("provider_membership")
  if (has(c("ledgr_availability_status_at", "ledgr_availability_lifetime_at", "ledgr_availability_terminal_event_at", "ledgr_availability_restrictions"))) return("provider_status_lifetime")
  if (has("ledgr_availability_valuation_marks")) return("valuation")
  if (has(c("write_run_diagnostics", "write_run_evidence"))) return("duckdb_diag_append")
  if (has("append_diagnostic")) return(if (has(c("ledgr_availability_diagnostic_row", "ledgr_availability_diagnostic_fields", "diag_row"))) "diag_construct" else "diag_append_retain")
  if (has("append_decision_trace")) return("diag_construct")
  if (has(c("rbind", "rbind.data.frame", "drain", "build")) && !has("flush_pending")) return("final_bind")
  if (has("decision_view")) return("provider_other")
  "residual_fold"
}
LANES <- c("provider_membership", "provider_status_lifetime", "provider_other", "valuation", "diag_construct",
           "diag_append_retain", "final_bind", "duckdb_diag_append", "residual_fold", "outside_loop")
parse_rprof <- function(path) {
  lines <- readLines(path, warn = FALSE)
  interval_us <- as.numeric(sub(".*sample.interval=", "", lines[[1L]]))
  samples <- lines[startsWith(lines, ":")]
  prefix_re <- "^:[0-9]+:[0-9]+:[0-9]+:[0-9]+:"
  mem <- do.call(rbind, lapply(strsplit(sub(":$", "", sub("^:", "", regmatches(samples, regexpr(prefix_re, samples)))), ":"), as.numeric))
  tokens <- strsplit(trimws(sub(prefix_re, "", samples)), " +")
  fns <- lapply(tokens, function(t) sub("^.*[$:]", "", gsub('"', "", t[startsWith(t, '"')], fixed = TRUE)))
  lane <- vapply(fns, classify_sample, character(1))
  growth <- c(0, pmax(0, diff(mem[, 1] + mem[, 2]))) * 8
  gc_flag <- vapply(fns, function(f) any(f == "<GC>"), logical(1))
  per_lane <- do.call(rbind, lapply(LANES, function(l) { s <- lane == l
    data.frame(lane = l, samples = sum(s), seconds = sum(s) * interval_us / 1e6, vcell_growth_mib = sum(growth[s]) / 1024^2,
               gc_samples = sum(gc_flag & s), stringsAsFactors = FALSE) }))
  list(interval_us = interval_us, n_samples = length(samples), in_loop_samples = sum(lane != "outside_loop"),
       lanes = per_lane, execution_view_in_stacks = sum(vapply(fns, function(f) any(f == "execution_view"), logical(1))))
}

measure40_phase <- function(evidence) {
  rows <- list()
  for (arm in ARMS) for (rep in c("warmup", "run1", "run2", "run3")) {
    r <- launch_child(arm, "compare40", paste0("spike-m40-", arm, "-", rep))
    x <- r$result
    stopifnot(identical(x$status, "DONE"), x$actionable_total == 0L, x$execution_rows == 0L, x$fills == 0L)
    rows[[length(rows) + 1L]] <- data.frame(arm = arm, repetition = rep, measured = rep != "warmup",
      wall_seconds = x$wall_seconds, t_loop_seconds = x$t_loop_seconds, peak_ws_mib = r$peak_ws_mib,
      status = x$status, decision_rows = x$decision_rows, reconciliation_rows = x$reconciliation_rows, stringsAsFactors = FALSE)
    cat(sprintf("measure40 %-8s %-7s wall %7.2f  t_loop %7.2f  peak WS %7.1f MiB\n", arm, rep, x$wall_seconds, x$t_loop_seconds, r$peak_ws_mib))
  }
  df <- do.call(rbind, rows); utils::write.csv(df, file.path(evidence, "measurements_40.csv"), row.names = FALSE)
  m <- df[df$measured, ]
  for (arm in ARMS) { s <- m[m$arm == arm, ]
    cat(sprintf("  %-8s median wall %7.2f (spread %5.2f)  median t_loop %7.2f  median peak WS %7.1f MiB (spread %5.1f)\n", arm,
      stats::median(s$wall_seconds), diff(range(s$wall_seconds)), stats::median(s$t_loop_seconds), stats::median(s$peak_ws_mib), diff(range(s$peak_ws_mib)))) }
  invisible(df)
}

envelope757_phase <- function(evidence) {
  rows <- list()
  for (arm in ARMS) {
    cat(sprintf("envelope757 %-8s unprofiled, ceilings %d s wall / %d MiB ...\n", arm, WALL_CEILING_S, WS_CEILING_MIB))
    r <- launch_child(arm, "envelope757", paste0("spike-e757-", arm), wall_ceiling = WALL_CEILING_S, ws_ceiling = WS_CEILING_MIB)
    x <- r$result
    rows[[length(rows) + 1L]] <- data.frame(arm = arm, profiled = FALSE, killed = r$killed %||% "",
      run_elapsed_s = r$run_elapsed_s, wall_seconds = x$wall_seconds %||% NA_real_, t_loop_seconds = x$t_loop_seconds %||% NA_real_,
      peak_ws_mib = r$peak_ws_mib, store_status = r$store_status, store_diagnostic_rows = r$store_diagnostic_rows,
      decision_rows = x$decision_rows %||% NA_integer_, within_envelope = !nzchar(r$killed %||% ""), stringsAsFactors = FALSE)
    cat(sprintf("  killed='%s' run_elapsed %.0f s  peak WS %.0f MiB  store status %s  stored diagnostics %s\n",
                r$killed %||% "", r$run_elapsed_s, r$peak_ws_mib, r$store_status, r$store_diagnostic_rows))
  }
  cat("envelope757 columnar profiled ...\n")
  r <- launch_child("columnar", "envelope757", "spike-e757-columnar-profiled", profile = TRUE, wall_ceiling = WALL_CEILING_S, ws_ceiling = WS_CEILING_MIB)
  x <- r$result
  rows[[length(rows) + 1L]] <- data.frame(arm = "columnar", profiled = TRUE, killed = r$killed %||% "", run_elapsed_s = r$run_elapsed_s,
    wall_seconds = x$wall_seconds %||% NA_real_, t_loop_seconds = x$t_loop_seconds %||% NA_real_, peak_ws_mib = r$peak_ws_mib,
    store_status = r$store_status, store_diagnostic_rows = r$store_diagnostic_rows, decision_rows = x$decision_rows %||% NA_integer_,
    within_envelope = !nzchar(r$killed %||% ""), stringsAsFactors = FALSE)
  df <- do.call(rbind, rows); utils::write.csv(df, file.path(evidence, "envelope_757.csv"), row.names = FALSE)
  if (!is.null(x$lanes)) {
    lanes <- as.data.frame(x$lanes$lanes); lanes$share_in_loop <- lanes$samples / x$lanes$in_loop_samples
    utils::write.csv(lanes, file.path(evidence, "lanes_757.csv"), row.names = FALSE)
    print(lanes[order(-lanes$samples), ], row.names = FALSE)
    groups <- list(diagnostics = c("diag_construct", "diag_append_retain", "final_bind", "duckdb_diag_append"),
                   provider = c("provider_membership", "provider_status_lifetime", "provider_other"), valuation = "valuation", residual_fold = "residual_fold")
    g <- sort(vapply(groups, function(l) sum(lanes$share_in_loop[lanes$lane %in% l]), numeric(1)), decreasing = TRUE)
    cat("grouped in-loop shares at 757 pulses (columnar):", paste(sprintf("%s %.1f%%", names(g), 100 * g), collapse = ", "), "\n")
    cat("largest lane group:", names(g)[[1L]], "\n")
  }
  print(df, row.names = FALSE)
  invisible(df)
}

# ---------------------------------------------------------------------------
# Entry.
# ---------------------------------------------------------------------------

if (length(args) >= 1L && identical(args[[1L]], "--child")) {
  prof <- if ("--profile" %in% args) args[[match("--profile", args) + 1L]] else NULL
  child_main(args[[2L]], args[[3L]], args[[4L]], args[[5L]], args[[6L]], args[[7L]], prof)
} else {
  mode <- if (length(args) >= 1L) args[[1L]] else "all"
  dir.create(evidence_dir, recursive = TRUE, showWarnings = FALSE)
  options(warn = 1)
  pkgload::load_all(repo_root, quiet = TRUE, export_all = TRUE)
  cat("spike_runner", mode, "\n")
  cat("HEAD:", system2("git", c("-C", shQuote(repo_root), "rev-parse", "HEAD"), stdout = TRUE), "\n")
  cat("R:", R.version.string, " collapse:", as.character(utils::packageVersion("collapse")), " duckdb:", as.character(utils::packageVersion("duckdb")), "\n")
  fixture_df <- do.call(rbind, lapply(names(FIXTURES), function(nm) { f <- FIXTURES[[nm]]
    data.frame(fixture = nm, n_instruments = f$n_instruments, n_members = f$n_members, n_sessions = f$n_sessions, n_lists = f$n_lists,
               list_session_indices = paste(1L + (seq_len(f$n_lists) - 1L) * (f$n_sessions %/% f$n_lists), collapse = " "),
               list_formula = LIST_FORMULA, chunk_rows = CHUNK_ROWS, small_chunk_rows = SMALL_CHUNK,
               wall_ceiling_s = WALL_CEILING_S, ws_ceiling_mib = WS_CEILING_MIB, stringsAsFactors = FALSE) }))
  utils::write.csv(fixture_df, file.path(evidence_dir, "fixture.csv"), row.names = FALSE)
  if (mode %in% c("semantic", "all")) semantic_phase(spike_fixture(FIXTURES$compare40), evidence_dir)
  if (mode %in% c("measure40", "all")) measure40_phase(evidence_dir)
  if (mode %in% c("envelope757", "all")) envelope757_phase(evidence_dir)
  cat("spike_runner done:", mode, "\n")
}
