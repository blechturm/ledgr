# Prerequisite lane profile for the availability hot-path representation RFC.
#
# spike_protocol.md section 1 work. Not the comparative spike, not a charter,
# not implementation. Current production code only; no R/ file is modified.
#
# One question:
#   Which lane dominates wall time and allocation pressure in the current
#   availability-aware flat fold on a shortened, public, production-shaped
#   synthetic fixture?
#
# Driver usage, from the repository root:
#   "C:/Program Files/R/R-4.5.2/bin/x64/Rscript.exe" \
#     dev/spikes/availability-hot-path-representation/lane_profile_probe.R
#
# The driver runs one unmeasured warm-up, three measured profiled runs, and one
# unprofiled reference run used only as a sampling-independent cross-check.
# Each run is a fresh child Rscript process with its own scratch DuckDB store
# and run ID, sampled by an external PowerShell working-set sampler (no package
# dependency). A profiled child wraps ledgr_run() in Rprof(memory.profiling =
# TRUE, line.profiling = TRUE, gc.profiling = TRUE) and classifies every sample
# into a lane. Every child then replays the diagnostic lane deterministically
# from the persisted rows (constructor per row, then do.call(rbind, ...)) under
# proc.time(), after profiling has stopped. The driver prints raw values,
# medians, the pre-registered attribution rule, and the cross-check, then
# removes every scratch artifact. It writes nothing into the repository.
#
# Pre-registered attribution rule (median in-loop sampled shares, runs 1-3):
#   diag_lane     = diag_construct + diag_append_retain + final_rbind
#                   + duckdb_diag_append
#   provider_lane = provider_membership + provider_status_lifetime
#                   + provider_other
#   DIAGNOSTICS_DOMINANT if diag_lane is the largest group and exceeds
#     provider_lane; PROVIDER_DOMINANT if provider_lane is the largest;
#     OTHER_LANE_DOMINANT if valuation or residual_fold is the largest;
#     INCONCLUSIVE if the leading group differs across the three measured
#     runs or the leader's median share exceeds the runner-up by fewer than
#     five percentage points of in-loop samples.
#
# Distinctions preserved in the output:
#   sampled self time      one lane per sample, partition of in-loop samples;
#   sampled total time     samples with an entry function anywhere on the stack;
#   R allocation evidence  positive Vcell growth between samples (Rprof memory
#                          fields are current-size counters that fall after a
#                          collection, so this is a lower bound on allocation,
#                          never retained memory);
#   process working set    external sampler, per child process;
#   elapsed wall           proc.time() around ledgr_run(), and ledgr's t_loop.

args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args) >= 1L && identical(args[[1L]], "--child")) "child" else "driver"

script_path <- local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(file_arg) == 0L) stop("Run this script with Rscript.")
  normalizePath(sub("^--file=", "", file_arg[[1L]]), winslash = "/")
})
repo_root <- normalizePath(file.path(dirname(script_path), "..", "..", ".."), winslash = "/")

FIXTURE <- list(
  n_instruments = 563L,
  n_members = 505L,
  n_sessions = 40L,
  n_lists = 4L,
  first_session = as.Date("2021-01-04"),
  venue = "SYNTH",
  universe_id = "synthetic_members"
)
PROFILE_INTERVAL <- 0.01

`%||%` <- function(a, b) if (is.null(a)) b else a

# ---------------------------------------------------------------------------
# Fixture: fully public, deterministic, production-shaped.
# ---------------------------------------------------------------------------

lane_fixture <- function(spec) {
  ids <- sprintf("I%03d", seq_len(spec$n_instruments))
  members <- ids[seq_len(spec$n_members)]
  civil <- seq(spec$first_session, by = "day", length.out = 54L)
  open <- as.POSIXlt(civil)$wday %in% 1:5
  stopifnot(sum(open) == spec$n_sessions)
  session_dates <- civil[open]
  publish <- as.POSIXct("2021-01-01 00:00:00", tz = "UTC")

  sessions <- data.frame(
    session_date = civil,
    status = ifelse(open, "open", "closed"),
    session_open = ifelse(open, "14:30:00", NA_character_),
    session_close = ifelse(open, "21:00:00", NA_character_),
    knowledge_time = publish,
    source = "synthetic_calendar",
    stringsAsFactors = FALSE
  )

  n_inst <- spec$n_instruments
  inst_idx <- rep(seq_len(n_inst), times = spec$n_sessions)
  sess_idx <- rep(seq_len(spec$n_sessions), each = n_inst)
  close <- 100 + (inst_idx %% 7) + 0.01 * sess_idx
  bars <- data.frame(
    ts_utc = rep(as.POSIXct(paste(session_dates, "21:00:00"), tz = "UTC"), each = n_inst),
    instrument_id = rep(ids, times = spec$n_sessions),
    open = close, high = close + 0.5, low = close - 0.5, close = close,
    volume = 1e5,
    stringsAsFactors = FALSE
  )

  list_at <- session_dates[seq(1L, by = spec$n_sessions %/% spec$n_lists, length.out = spec$n_lists)]
  membership <- data.frame(
    instrument_id = rep(members, times = spec$n_lists),
    effective_from = rep(as.POSIXct(paste(list_at, "00:00:00"), tz = "UTC"), each = spec$n_members),
    knowledge_time = rep(as.POSIXct(paste(list_at - 1, "00:00:00"), tz = "UTC"), each = spec$n_members),
    source = "synthetic_membership",
    stringsAsFactors = FALSE
  )
  window_start <- as.POSIXct(paste(session_dates[[1L]], "00:00:00"), tz = "UTC")
  status <- data.frame(
    instrument_id = ids, effective_from = window_start, knowledge_time = publish,
    status = "active", source = "synthetic_status", stringsAsFactors = FALSE
  )
  lifetime <- data.frame(
    instrument_id = ids, effective_from = window_start, knowledge_time = publish,
    assertion = "known_active", source = "synthetic_lifetime", stringsAsFactors = FALSE
  )

  facts <- ledgr::ledgr_facts(
    ledgr::ledgr_facts_sessions(sessions, spec$venue, timezone = "UTC"),
    ledgr::ledgr_facts_membership_snapshots(membership, spec$universe_id, complete = TRUE),
    ledgr::ledgr_facts_trading_status(status),
    ledgr::ledgr_facts_lifetime(lifetime)
  )
  list(bars = bars, instruments = data.frame(instrument_id = ids, stringsAsFactors = FALSE),
       facts = facts, session_dates = session_dates, list_dates = list_at)
}

# ---------------------------------------------------------------------------
# Profile classification.
# ---------------------------------------------------------------------------

classify_sample <- function(fns) {
  has <- function(x) any(x %in% fns)
  if (!has("run_transaction")) return("outside_loop")
  if (has(c("ledgr_membership_resolve_at", "ledgr_availability_members_at"))) return("provider_membership")
  if (has(c("ledgr_availability_status_at", "ledgr_availability_lifetime_at",
            "ledgr_availability_terminal_event_at", "ledgr_availability_restrictions"))) {
    return("provider_status_lifetime")
  }
  if (has("ledgr_availability_valuation_marks")) return("valuation")
  if (has(c("write_run_diagnostics", "write_run_evidence"))) return("duckdb_diag_append")
  if (has("append_diagnostic")) {
    return(if (has("ledgr_availability_diagnostic_row")) "diag_construct" else "diag_append_retain")
  }
  if (has("append_decision_trace")) return("diag_construct")
  if (has(c("rbind", "rbind.data.frame")) && !has("flush_pending")) return("final_rbind")
  if (has("decision_view")) return("provider_other")
  "residual_fold"
}

LANES <- c("provider_membership", "provider_status_lifetime", "provider_other", "valuation",
           "diag_construct", "diag_append_retain", "final_rbind", "duckdb_diag_append",
           "residual_fold", "outside_loop")
TOTAL_FNS <- c("decision_view", "ledgr_availability_valuation_marks", "append_decision_trace",
               "append_diagnostic", "ledgr_availability_diagnostic_row", "rbind",
               "write_run_diagnostics", "run_transaction")

parse_rprof <- function(path) {
  lines <- readLines(path, warn = FALSE)
  interval_us <- as.numeric(sub(".*sample.interval=", "", lines[[1L]]))
  file_lines <- grep("^#File [0-9]+: ", lines, value = TRUE)
  file_map <- stats::setNames(
    basename(sub("^#File [0-9]+: ", "", file_lines)),
    sub("^#File ([0-9]+): .*$", "\\1", file_lines)
  )
  samples <- lines[startsWith(lines, ":")]
  prefix_re <- "^:[0-9]+:[0-9]+:[0-9]+:[0-9]+:"
  mem <- do.call(rbind, lapply(
    strsplit(sub(":$", "", sub("^:", "", regmatches(samples, regexpr(prefix_re, samples)))), ":"),
    as.numeric
  ))
  colnames(mem) <- c("small_vcells", "large_vcells", "nodes", "dups")
  tokens <- strsplit(trimws(sub(prefix_re, "", samples)), " +")
  # Rprof records qualified calls as "obj$fn" and "pkg::fn"; classify on the
  # bare name so "output_handler$run_transaction" matches "run_transaction"
  # and "provider$execution_view" cannot evade the check.
  fns <- lapply(tokens, function(t) sub("^.*[$:]", "", gsub('"', "", t[startsWith(t, '"')], fixed = TRUE)))
  cur_line <- vapply(tokens, function(t) {
    l <- t[grepl("^[0-9]+#[0-9]+$", t)]
    if (length(l) == 0L) return(NA_character_)
    parts <- strsplit(l[[1L]], "#", fixed = TRUE)[[1L]]
    label <- if (parts[[1L]] %in% names(file_map)) file_map[[parts[[1L]]]] else parts[[1L]]
    paste0(label, ":", parts[[2L]])
  }, character(1))
  lane <- vapply(fns, classify_sample, character(1))
  vcells <- mem[, "small_vcells"] + mem[, "large_vcells"]
  vcell_growth <- c(0, pmax(0, diff(vcells))) * 8
  gc_flag <- vapply(fns, function(f) any(f == "<GC>"), logical(1))
  ev_flag <- vapply(fns, function(f) any(f == "execution_view"), logical(1))
  per_lane <- lapply(LANES, function(l) {
    sel <- lane == l
    list(lane = l, samples = sum(sel), seconds = sum(sel) * interval_us / 1e6,
         vcell_growth_mib = sum(vcell_growth[sel]) / 1024^2,
         dups = sum(mem[sel, "dups"]), gc_samples = sum(gc_flag & sel))
  })
  totals <- vapply(TOTAL_FNS, function(fn) {
    sum(vapply(fns, function(f) fn %in% f, logical(1))) * interval_us / 1e6
  }, numeric(1))
  hot <- sort(table(cur_line[lane != "outside_loop"]), decreasing = TRUE)
  list(interval_us = interval_us, n_samples = length(samples),
       in_loop_samples = sum(lane != "outside_loop"), lanes = per_lane,
       totals = as.list(totals), gc_samples = sum(gc_flag),
       execution_view_in_stacks = sum(ev_flag), vcell_delta_min_cells = min(diff(vcells)),
       hotspots = as.list(stats::setNames(as.integer(head(hot, 12L)), names(head(hot, 12L)))))
}

# ---------------------------------------------------------------------------
# Deterministic replay of the diagnostic lane from the persisted rows. Runs
# after profiling stops. The constructor receives persisted scalars, so the
# fold's live named-vector lookups are excluded: a slight underestimate of the
# fold's construction cost. The bind is the identical expression on the
# identical shape (R/fold-engine.R:1093).
# ---------------------------------------------------------------------------

replay_diagnostic_lane <- function(diagnostics) {
  d <- as.data.frame(diagnostics)
  n <- nrow(d)
  rows <- vector("list", n)
  t_construct <- system.time({
    for (i in seq_len(n)) {
      rows[[i]] <- ledgr:::ledgr_availability_diagnostic_row(
        run_id = d$run_id[[i]], diagnostic_seq = d$diagnostic_seq[[i]], ts_utc = d$ts_utc[[i]],
        instrument_id = d$instrument_id[[i]], stage = d$stage[[i]], outcome = d$outcome[[i]],
        reason_code = d$reason_code[[i]], reasons = d$reasons[[i]], target = d$target[[i]],
        quantity = d$quantity[[i]], price = d$price[[i]], mark_source = d$mark_source[[i]],
        mark_age = d$mark_age[[i]], decision_ts_utc = d$decision_ts_utc[[i]],
        execution_ts_utc = d$execution_ts_utc[[i]], event_seq = d$event_seq[[i]],
        target_before_risk = d$target_before_risk[[i]], target_after_risk = d$target_after_risk[[i]],
        position_before = d$position_before[[i]], position_after = d$position_after[[i]],
        feature_identity_json = d$feature_identity_json[[i]], detail_json = d$detail_json[[i]]
      )
    }
  })[["elapsed"]]
  list_mib <- as.numeric(utils::object.size(rows)) / 1024^2
  t_bind <- system.time(bound <- do.call(rbind, rows))[["elapsed"]]
  list(rows = n, construct_seconds = as.numeric(t_construct), bind_seconds = as.numeric(t_bind),
       bound_rows = nrow(bound), retained_list_mib = list_mib,
       bound_frame_mib = as.numeric(utils::object.size(bound)) / 1024^2)
}

# ---------------------------------------------------------------------------
# Child: build fixture, run once, verify the path, classify, replay, write JSON.
# ---------------------------------------------------------------------------

run_child <- function(run_id, db_path, prof_path, result_path, profile = TRUE) {
  options(keep.source = TRUE, keep.source.pkgs = TRUE, warn = 1)
  pkgload::load_all(repo_root, quiet = TRUE, export_all = TRUE)
  fx <- lane_fixture(FIXTURE)
  snapshot <- ledgr::ledgr_snapshot_from_df(
    fx$bars, instruments_df = fx$instruments, db_path = db_path,
    snapshot_id = "lane-profile", facts = fx$facts
  )
  exp <- ledgr::ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    universe = ledgr::ledgr_universe_members(FIXTURE$universe_id),
    valuation_policy = ledgr::ledgr_valuation_stale(max_sessions = 2L),
    cost_model = ledgr::ledgr_cost_zero(),
    opening = ledgr::ledgr_opening(cash = 1e6)
  )
  plan_text <- utils::capture.output(print(ledgr::ledgr_experiment_plan(exp)))

  # Deterministic no-execution proof: execution_view() is reachable only inside
  # the loop over actionable_idx (R/availability-economics.R:225-251).
  assign("lane_actionable_total", 0L, envir = globalenv())
  suppressMessages(trace(
    "ledgr_fold_build_availability_pulse_plan", where = asNamespace("ledgr"), print = FALSE,
    tracer = quote(assign("lane_actionable_total",
                          get("lane_actionable_total", envir = globalenv()) + length(actionable_idx),
                          envir = globalenv()))
  ))
  on.exit(suppressMessages(untrace("ledgr_fold_build_availability_pulse_plan", where = asNamespace("ledgr"))), add = TRUE)

  invisible(gc(full = TRUE))
  if (profile) {
    Rprof(prof_path, interval = PROFILE_INTERVAL, memory.profiling = TRUE,
          line.profiling = TRUE, gc.profiling = TRUE)
  }
  t0 <- proc.time()[["elapsed"]]
  bt <- ledgr::ledgr_run(exp, run_id = run_id)
  wall <- proc.time()[["elapsed"]] - t0
  if (profile) Rprof(NULL)
  on.exit({ try(close(bt), silent = TRUE); try(ledgr::ledgr_snapshot_close(snapshot), silent = TRUE) }, add = TRUE)

  info <- ledgr::ledgr_run_info(snapshot, run_id)
  telemetry <- ledgr:::ledgr_get_run_telemetry(run_id)
  diagnostics <- ledgr::ledgr_results(bt, "diagnostics")
  fills <- ledgr::ledgr_results(bt, "fills")
  stage_table <- as.data.frame(table(stage = diagnostics$stage, outcome = diagnostics$outcome), stringsAsFactors = FALSE)
  stage_table <- stage_table[stage_table$Freq > 0L, , drop = FALSE]
  prof <- if (profile) parse_rprof(prof_path) else NULL
  replay <- replay_diagnostic_lane(diagnostics)

  checks <- list(
    status = as.character(info$status),
    completion_status = as.character(info$completion_status),
    pulse_count = as.integer(info$pulse_count %||% NA_integer_),
    decision_rows = sum(diagnostics$stage == "decision"),
    # The flat fold writes one portfolio-scope reconciliation row per pulse
    # (R/fold-engine.R, stage "reconciliation", reason "affordability_reconciled");
    # that row does not involve execution_view(). Execution-stage rows do.
    reconciliation_rows = sum(diagnostics$stage == "reconciliation" & diagnostics$outcome == "reconciled"),
    execution_stage_rows = sum(diagnostics$stage == "execution"),
    other_stage_rows = sum(!diagnostics$stage %in% c("decision", "reconciliation")),
    fill_rows = nrow(fills),
    actionable_total = get("lane_actionable_total", envir = globalenv()),
    execution_view_in_stacks = if (profile) prof$execution_view_in_stacks else NA_integer_,
    srcref_available = !is.null(utils::getSrcref(ledgr:::ledgr_availability_diagnostic_row))
  )
  expected_rows <- FIXTURE$n_sessions * FIXTURE$n_members
  failures <- c(
    if (!identical(checks$status, "DONE")) sprintf("status %s", checks$status),
    if (checks$decision_rows != expected_rows) sprintf("decision rows %d != %d", checks$decision_rows, expected_rows),
    if (checks$reconciliation_rows != FIXTURE$n_sessions) sprintf("reconciliation rows %d != %d pulses", checks$reconciliation_rows, FIXTURE$n_sessions),
    if (checks$execution_stage_rows != 0L) sprintf("%d execution-stage rows", checks$execution_stage_rows),
    if (checks$other_stage_rows != 0L) sprintf("%d rows in unexpected stages", checks$other_stage_rows),
    if (checks$fill_rows != 0L) sprintf("%d fills", checks$fill_rows),
    if (checks$actionable_total != 0L) sprintf("%d actionable targets reached the pulse plan", checks$actionable_total),
    if (profile && checks$execution_view_in_stacks != 0L) sprintf("execution_view in %d profiler samples", checks$execution_view_in_stacks),
    if (replay$bound_rows != nrow(diagnostics)) "replay bound a different row count"
  )
  result <- list(
    run_id = run_id, profiled = profile, wall_seconds = wall,
    t_loop_seconds = as.numeric(telemetry$t_loop %||% NA_real_),
    r_version = R.version.string, platform = R.version$platform,
    collapse = as.character(utils::packageVersion("collapse")),
    duckdb = as.character(utils::packageVersion("duckdb")),
    checks = checks, failures = failures, stage_table = stage_table,
    plan = plan_text, profile = prof, replay = replay,
    fixture = list(bars = nrow(fx$bars), instruments = nrow(fx$instruments),
                   list_dates = as.character(fx$list_dates), sessions = length(fx$session_dates))
  )
  yyjsonr::write_json_file(result, result_path, auto_unbox = TRUE)
  if (length(failures) > 0L) stop("Lane profile fixture failed its path checks: ", paste(failures, collapse = "; "))
  cat("child_ok run_id=", run_id, " profiled=", profile, " wall=", round(wall, 2), "\n", sep = "")
  invisible(NULL)
}

# ---------------------------------------------------------------------------
# Driver: launch children under the working-set sampler, aggregate, clean up.
# ---------------------------------------------------------------------------

sampler_ps1 <- '
param([string]$Exe, [string]$ChildArgsJoined, [int]$IntervalMs = 200)
$childArgs = $ChildArgsJoined.Split("|")
$p = Start-Process -FilePath $Exe -ArgumentList $childArgs -PassThru -NoNewWindow
$null = $p.Handle
$sampled = 0; $peak = 0; $n = 0
while (-not $p.HasExited) {
  try { $p.Refresh(); $ws = $p.WorkingSet64; $pk = $p.PeakWorkingSet64
        if ($ws -gt $sampled) { $sampled = $ws }; if ($pk -gt $peak) { $peak = $pk }; $n++ } catch {}
  Start-Sleep -Milliseconds $IntervalMs
}
$p.WaitForExit()
Write-Output ("PEAK_WS_BYTES=" + $peak)
Write-Output ("SAMPLED_MAX_WS_BYTES=" + $sampled)
Write-Output ("WS_SAMPLES=" + $n)
Write-Output ("CHILD_EXIT=" + $p.ExitCode)
'

run_driver <- function() {
  rscript <- file.path(R.home("bin"), "Rscript.exe")
  if (!file.exists(rscript)) rscript <- file.path(R.home("bin"), "x64", "Rscript.exe")
  ps1 <- tempfile("ws_sampler_", fileext = ".ps1")
  writeLines(sampler_ps1, ps1)
  scratch <- character()
  on.exit({ unlink(c(scratch, ps1), force = TRUE); unlink(paste0(scratch, ".wal"), force = TRUE) }, add = TRUE)

  cat("lane_profile_probe driver\n")
  cat("repo:     ", repo_root, "\n", sep = "")
  cat("branch:   ", system2("git", c("-C", shQuote(repo_root), "branch", "--show-current"), stdout = TRUE), "\n", sep = "")
  cat("HEAD:     ", system2("git", c("-C", shQuote(repo_root), "rev-parse", "HEAD"), stdout = TRUE), "\n", sep = "")
  cat("Rscript:  ", rscript, "\n", sep = "")
  fe <- readLines(file.path(repo_root, "R", "fold-engine.R"), warn = FALSE)
  for (i in grep("loop_start <- |run_transaction\\(run_loop\\)|telemetry\\$t_loop <- ", fe)) {
    cat(sprintf("t_loop bound  R/fold-engine.R:%d  %s\n", i, trimws(fe[[i]])))
  }
  cat(sprintf("profiler: Rprof interval %.3f s, memory + line + gc profiling; working set sampled every 200 ms\n", PROFILE_INTERVAL))
  cat(sprintf("fixture:  %d instruments, %d-member axis, %d sessions, %d complete lists, flat strategy, zero holdings\n\n",
              FIXTURE$n_instruments, FIXTURE$n_members, FIXTURE$n_sessions, FIXTURE$n_lists))

  runs <- c(warmup = TRUE, run1 = TRUE, run2 = TRUE, run3 = TRUE, reference = FALSE)
  results <- list()
  for (r in names(runs)) {
    db <- tempfile(paste0("lane_", r, "_"), fileext = ".duckdb")
    prof <- tempfile(paste0("lane_", r, "_"), fileext = ".prof")
    res <- tempfile(paste0("lane_", r, "_"), fileext = ".json")
    scratch <- c(scratch, db, prof, res)
    child_args <- c(script_path, "--child", paste0("lane-profile-", r), db, prof, res,
                    if (!runs[[r]]) "--no-profile")
    out <- system2("powershell", c("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", shQuote(ps1),
                                   "-Exe", shQuote(rscript), "-ChildArgsJoined", shQuote(paste(child_args, collapse = "|")),
                                   "-IntervalMs", "200"), stdout = TRUE, stderr = TRUE)
    grab <- function(key) as.numeric(sub(paste0("^", key, "="), "", grep(paste0("^", key, "="), out, value = TRUE))[1L])
    child_exit <- grab("CHILD_EXIT")
    if (!file.exists(res) || is.na(child_exit) || child_exit != 0) {
      cat(out, sep = "\n")
      stop(sprintf("Child run '%s' failed (exit %s).", r, child_exit))
    }
    x <- yyjsonr::read_json_file(res)
    if (length(x$failures) > 0L) { cat(out, sep = "\n"); stop("Child reported path-check failures.") }
    x$peak_ws_mib <- grab("PEAK_WS_BYTES") / 1024^2
    x$sampled_ws_mib <- grab("SAMPLED_MAX_WS_BYTES") / 1024^2
    results[[r]] <- x
    # Scratch store and profiler output go now; the small result JSON stays
    # until exit unless LANE_PROFILE_KEEP_JSON=1, a debugging aid that lets
    # the aggregation be rerun without repeating the measured runs.
    unlink(c(db, paste0(db, ".wal"), prof), force = TRUE)
    if (nzchar(Sys.getenv("LANE_PROFILE_KEEP_JSON"))) {
      scratch <- setdiff(scratch, res)
      cat("  retained result JSON: ", res, "\n", sep = "")
    }
    cat(sprintf("%-9s wall %7.2f s  t_loop %7.2f s  peak WS %7.1f MiB  %s  replay construct %6.2f s  bind %6.2f s  list %7.1f MiB\n",
                r, x$wall_seconds, x$t_loop_seconds, x$peak_ws_mib,
                if (runs[[r]]) sprintf("samples %5d in-loop %5d gc %4d", x$profile$n_samples, x$profile$in_loop_samples, x$profile$gc_samples)
                else "unprofiled                       ",
                x$replay$construct_seconds, x$replay$bind_seconds, x$replay$retained_list_mib))
  }

  w <- results[["warmup"]]
  cat("\nwarm-up experiment plan:\n"); cat(paste0("  ", w$plan), sep = "\n")
  cat("\nwarm-up diagnostic stage/outcome counts:\n")
  st <- w$stage_table
  for (i in seq_along(st$stage)) cat(sprintf("  %-14s %-10s %d\n", st$stage[[i]], st$outcome[[i]], st$Freq[[i]]))
  cat(sprintf("\nenvironment: %s, %s, collapse %s, duckdb %s, srcref available %s\n",
              w$r_version, w$platform, w$collapse, w$duckdb, w$checks$srcref_available))
  cat(sprintf("checks (every run): status DONE, %d decision rows, %d reconciliation rows (one per pulse), 0 execution-stage rows, 0 fills, 0 actionable targets; execution_view absent from every profiler sample\n",
              w$checks$decision_rows, w$checks$reconciliation_rows))
  cat(sprintf("Rprof memory counters fell between samples (min Vcell delta %s cells): allocation is reported as positive growth only\n\n",
              format(w$profile$vcell_delta_min_cells, big.mark = ",")))

  measured <- results[c("run1", "run2", "run3")]
  ref <- results[["reference"]]
  med <- function(f) stats::median(vapply(measured, f, numeric(1)))
  # yyjsonr reads an array of same-keyed objects back as a data.frame; accept
  # either that or the in-memory list-of-lists shape.
  lane_val <- function(x, lane, field) {
    lanes <- x$profile$lanes
    if (is.data.frame(lanes)) return(as.numeric(lanes[[field]][lanes$lane == lane]))
    for (l in lanes) if (identical(l$lane, lane)) return(as.numeric(l[[field]]))
    NA_real_
  }
  in_loop_med <- med(function(x) x$profile$in_loop_samples)
  cat("per-lane sampled self time (seconds; runs 1-3, median, share of in-loop samples), median positive Vcell growth, median GC samples:\n")
  cat(sprintf("  %-26s %8s %8s %8s %8s %8s %10s %6s\n", "lane", "run1", "run2", "run3", "median", "share", "growth_MiB", "gc"))
  for (lane in LANES) {
    v <- vapply(measured, lane_val, numeric(1), lane = lane, field = "seconds")
    s <- vapply(measured, lane_val, numeric(1), lane = lane, field = "samples")
    g <- stats::median(vapply(measured, lane_val, numeric(1), lane = lane, field = "vcell_growth_mib"))
    gc <- stats::median(vapply(measured, lane_val, numeric(1), lane = lane, field = "gc_samples"))
    share <- if (lane == "outside_loop") NA_real_ else stats::median(s) / in_loop_med
    cat(sprintf("  %-26s %8.2f %8.2f %8.2f %8.2f %8s %10.1f %6.0f\n", lane, v[[1]], v[[2]], v[[3]], stats::median(v),
                if (is.na(share)) "-" else sprintf("%5.1f%%", 100 * share), g, gc))
  }
  cat("\nsampled total time for entry functions (median seconds; overlapping, not a partition):\n")
  for (fn in TOTAL_FNS) cat(sprintf("  %-40s %8.2f\n", fn, med(function(x) as.numeric(x$profile$totals[[fn]]))))

  prof_t_loop <- med(function(x) x$t_loop_seconds)
  sampled_in_loop <- in_loop_med * PROFILE_INTERVAL
  cat("\nwall and working set (medians of runs 1-3, then the unprofiled reference run):\n")
  cat(sprintf("  profiled:   wall %.2f s   t_loop %.2f s   sampled in-loop %.2f s (%.0f%% of t_loop)   peak WS %.1f MiB\n",
              med(function(x) x$wall_seconds), prof_t_loop, sampled_in_loop, 100 * sampled_in_loop / prof_t_loop,
              med(function(x) x$peak_ws_mib)))
  cat(sprintf("  reference:  wall %.2f s   t_loop %.2f s   peak WS %.1f MiB   (profiler overhead on t_loop: %.2f s)\n",
              ref$wall_seconds, ref$t_loop_seconds, ref$peak_ws_mib, prof_t_loop - ref$t_loop_seconds))

  rp <- function(f) med(function(x) as.numeric(x$replay[[f]]))
  cat("\ndeterministic replay of the diagnostic lane (proc.time, after profiling; medians of runs 1-3 and the reference):\n")
  cat(sprintf("  rows %d   construct %.2f s / %.2f s   bind %.2f s / %.2f s   retained list %.1f MiB   bound frame %.1f MiB\n",
              as.integer(rp("rows")), rp("construct_seconds"), ref$replay$construct_seconds,
              rp("bind_seconds"), ref$replay$bind_seconds, rp("retained_list_mib"), rp("bound_frame_mib")))
  non_diag_bound <- ref$t_loop_seconds - (ref$replay$construct_seconds + ref$replay$bind_seconds)
  cat(sprintf("  cross-check: reference t_loop %.2f s minus replayed construct + bind %.2f s = %.2f s upper bound on all non-diagnostic in-loop wall (provider + valuation + append + persistence + residual)\n",
              ref$t_loop_seconds, ref$replay$construct_seconds + ref$replay$bind_seconds, non_diag_bound))

  cat("\ntop in-loop source lines by sample count (run1):\n")
  hs <- results[["run1"]]$profile$hotspots
  for (nm in names(hs)) cat(sprintf("  %-32s %d\n", nm, as.integer(hs[[nm]])))

  agg <- function(x, lanes) sum(vapply(lanes, function(l) lane_val(x, l, "samples"), numeric(1))) / x$profile$in_loop_samples
  groups <- list(
    diagnostics = c("diag_construct", "diag_append_retain", "final_rbind", "duckdb_diag_append"),
    provider = c("provider_membership", "provider_status_lifetime", "provider_other"),
    valuation = "valuation", residual_fold = "residual_fold"
  )
  per_run_leader <- vapply(measured, function(x) {
    g <- vapply(groups, function(l) agg(x, l), numeric(1)); names(g)[which.max(g)]
  }, character(1))
  gmed <- vapply(groups, function(l) stats::median(vapply(measured, agg, numeric(1), lanes = l)), numeric(1))
  ord <- sort(gmed, decreasing = TRUE)
  cat("\ngrouped median in-loop sampled shares:\n")
  for (nm in names(ord)) cat(sprintf("  %-14s %5.1f%%\n", nm, 100 * ord[[nm]]))
  cat(sprintf("per-run leader: %s\n", paste(per_run_leader, collapse = ", ")))
  verdict <- if (length(unique(per_run_leader)) > 1L || (ord[[1]] - ord[[2]]) < 0.05) {
    "INCONCLUSIVE"
  } else if (names(ord)[[1]] == "diagnostics") {
    "DIAGNOSTICS_DOMINANT"
  } else if (names(ord)[[1]] == "provider") {
    "PROVIDER_DOMINANT"
  } else {
    "OTHER_LANE_DOMINANT"
  }
  cat(sprintf("\nATTRIBUTION_RESULT: %s\n", verdict))
  cat("(rule: diagnostics = construct + append/retain + final rbind + DuckDB append; falsified as wall-first if not the largest group or if provider is larger; INCONCLUSIVE if leaders differ across runs or the margin is under 5 points)\n")
  invisible(verdict)
}

if (identical(mode, "child")) {
  if (length(args) < 5L) stop("--child requires run_id db_path prof_path result_path [--no-profile]")
  run_child(args[[2L]], args[[3L]], args[[4L]], args[[5L]], profile = !("--no-profile" %in% args))
} else {
  run_driver()
}
