# Charter stage 2a: the sweep path builds only the diagnostic rows its sink
# keeps. One rule, in the staging functions: before a segment's rows are
# built, the sink's own keep rule (ledgr_memory_diagnostic_keep for a sweep
# candidate; every row for a durable store) picks the rows to build; the
# others only reserve their logical positions, so diagnostic_seq is unchanged.
# No execution-mode branch: a durable store keeps every row and runs as before.
#
#   Rscript dev/spikes/diagnostic_records/fork.R <pinned lib> <out dir> [sweeps|a0] [workload,...] [--gut]
#
# sweeps: per workload, a one-candidate sweep (workers = 1) under three arms,
#   alternating over three rounds: pin, lean (lean P3, dev/lean_core/plan.R)
#   and strict (lean P3 plus the keep rule). Each arm's sweep tables and kept
#   memory diagnostics (A0 canonical form) must equal the pin's.
# a0: the eight A0 workloads, every path, pinned against strict.
# --gut: the strict arm keeps nothing; parity must fail where rows are kept.

args <- commandArgs(TRUE)
gut <- "--gut" %in% args
args <- setdiff(args, "--gut")
lib <- args[[1L]]
out <- args[[2L]]
mode <- if (length(args) >= 3L) args[[3L]] else "sweeps"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                              winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(repo, "dev/lean_core/load.R"))
lean <- lean_core_load(lib, debug = FALSE)
work <- file.path(tempdir(), "diag_fork")
dir.create(work, showWarnings = FALSE)
source(file.path(here, "workloads.R"))
ns <- asNamespace("ledgr")

# The keep rule the current fold's sink states, captured when E builds the
# writer: NULL keeps every row.
dr_state <- new.env()
dr_state$keep <- NULL
keep_rule <- function(output_handler) {
  k <- output_handler$diagnostic_keep
  if (gut && identical(mode, "sweeps")) return(function(diagnostics, n = NULL) logical(n %||% length(diagnostics$stage)))
  if (identical(k, ns$ledgr_memory_diagnostic_keep)) k else NULL
}
strict_bindings <- list(
  ledgr_fold_diagnostic_writer = function(orig) { force(orig); function(run_id, output_handler, ...) {
    dr_state$keep <- keep_rule(output_handler)
    orig(run_id, output_handler, ...)
  }},
  # P1, P2, P5 and E stage raw segments here.
  ledgr_fold_staging_add = function(orig) { force(orig); function(fold_state, segment, ts) {
    keep <- dr_state$keep
    if (is.null(keep)) return(orig(fold_state, segment, ts))
    n <- as.integer(segment$n)
    k <- which(keep(segment, n))
    start <- fold_state$pending_segments$logical_n
    if (length(k)) {
      seg <- ns$ledgr_fold_diagnostic_segment(segment, ts)
      ns$ledgr_fold_staging_write(fold_state, ns$ledgr_fold_diagnostic_rows(seg, index = k), start + k)
    }
    fold_state$pending_segments$logical_n <- start + n
    invisible(start + seq_len(n))
  }},
  # P2's and the pinned P3's residual staging of built segments.
  ledgr_fold_staging_add_residual = function(orig) { force(orig); function(fold_state, segment, index) {
    keep <- dr_state$keep
    if (!is.null(keep) && length(index)) index <- index[keep(segment, segment$n)[index]]
    orig(fold_state, segment, index)
  }}
)
# Lean P3's staging, the same rule.
lean_stage_inner <- lean$lean_plan_stage
lean_strict_stage <- function(fold_state, n, segment, index) {
  keep <- dr_state$keep
  if (!is.null(keep) && length(index)) {
    s <- segment()
    index <- index[keep(s, s$n)[index]]
    segment <- function() s
  }
  lean_stage_inner(fold_state, n, segment, index)
}
# Stage 2b (arm "records"): a durable run stores no clean-hold rows, only one
# count per decided pulse, and writes its diagnostics once, after the last
# pulse. The writer is handed a proxy of the output handler that buffers
# every diagnostic frame in memory, counts and drops the hold rows, and at
# the drain (write_diagnostic_coverage) makes one append per table, then the
# coverage row. The reader (reader.R) rebuilds the holds into ledgr's
# logical-trace view.
source(file.path(here, "reader.R"))
dr_proxy <- function(h, run_id) {
  buf <- new.env()
  buf$explicit <- list(); buf$fills <- list(); buf$holds <- list()
  p <- h
  p$write_run_diagnostics <- function(diagnostics) {
    if (!is.null(diagnostics) && nrow(diagnostics) > 0L) buf$explicit[[length(buf$explicit) + 1L]] <- diagnostics
    invisible(TRUE)
  }
  p$write_run_diagnostic_implicit <- function(rows) {
    if (is.null(rows) || nrow(rows) == 0L) return(invisible(TRUE))
    hold <- is.na(rows$execution_seq)
    if (any(hold)) buf$holds[[length(buf$holds) + 1L]] <- as.numeric(rows$ts_utc[hold])
    if (any(!hold)) buf$fills[[length(buf$fills) + 1L]] <- rows[!hold, , drop = FALSE]
    invisible(TRUE)
  }
  p$write_diagnostic_coverage <- function(logical_count) {
    if (length(buf$explicit)) h$write_run_diagnostics(do.call(rbind, buf$explicit))
    if (length(buf$fills)) h$write_run_diagnostic_implicit(do.call(rbind, buf$fills))
    con <- dr_state$con
    DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS spike_hold_counts(run VARCHAR, ts_utc TIMESTAMP, n INTEGER)")
    DBI::dbExecute(con, "DELETE FROM spike_hold_counts WHERE run = ?", params = list(run_id))
    ts <- unlist(buf$holds, use.names = FALSE)
    if (length(ts)) {
      tab <- table(ts)
      if (gut) tab[[1L]] <- tab[[1L]] - 1L
      DBI::dbAppendTable(con, "spike_hold_counts", data.frame(run = run_id,
        ts_utc = .POSIXct(as.numeric(names(tab)), tz = "UTC"), n = as.integer(tab)))
    }
    buf$explicit <- list(); buf$fills <- list(); buf$holds <- list()
    h$write_diagnostic_coverage(logical_count)
  }
  p
}
records_bindings <- list(
  ledgr_output_sink_duckdb = function(orig) { force(orig); function(con, run_id, ...) {
    dr_state$con <- con
    orig(con, run_id, ...)
  }},
  ledgr_fold_diagnostic_writer = function(orig) { force(orig); function(run_id, output_handler, ...) {
    dr_state$keep <- keep_rule(output_handler)
    if (is.function(output_handler$write_run_diagnostic_implicit)) output_handler <- dr_proxy(output_handler, run_id)
    orig(run_id, output_handler, ...)
  }},
  ledgr_diagnostic_logical_sql = function(orig) { force(orig); function() {
    paste(orig(), "UNION ALL SELECT * FROM spike_holds")
  }},
  ledgr_diagnostic_db_get_query = function(orig) { force(orig); function(con, statement, ...) {
    if (grepl("spike_holds", statement, fixed = TRUE)) dr_ensure_holds(con)
    orig(con, statement, ...)
  }}
)
install_arm <- function(arm) {
  if (identical(arm, "pin")) return(function() NULL)
  lean$lean_plan_stage <- if (arm %in% c("strict", "records")) lean_strict_stage else lean_stage_inner
  restore_plan <- lean$lean_plan_install()
  if (identical(arm, "lean")) return(restore_plan)
  bindings <- strict_bindings
  if (identical(arm, "records")) bindings[names(records_bindings)] <- records_bindings
  originals <- lapply(stats::setNames(names(bindings), names(bindings)), get, envir = ns)
  for (name in names(bindings)) {
    unlockBinding(name, ns)
    assign(name, bindings[[name]](originals[[name]]), envir = ns)
    lockBinding(name, ns)
  }
  function() {
    for (name in names(originals)) {
      unlockBinding(name, ns); assign(name, originals[[name]], envir = ns); lockBinding(name, ns)
    }
    dr_state$keep <- NULL
    restore_plan()
  }
}
with_arm <- function(arm, expr) {
  restore <- install_arm(arm)
  on.exit(restore())
  force(expr)
}
compare <- function(a, b) {
  same <- vapply(names(a), function(t) identical(a[[t]], b[[t]]), logical(1))
  c(tables = length(a), different = sum(!same) + length(setdiff(names(b), names(a))),
    first = if (all(same)) "" else names(a)[!same][[1L]])
}

rows <- list()
if (identical(mode, "runs")) {
  # Committed runs, fixed universes: pin, lean P3, records; three alternating
  # rounds. Round one's store tables (diagnostics decoded through the view),
  # readers and explain rows must equal the pin's; the physical implicit
  # table must equal the pin's fill rows. With --gut the records arm stores
  # one hold count one short, and the run must be refused.
  ids <- if (length(args) >= 4L) strsplit(args[[4L]], ",")[[1L]] else
    c("crossover_10x7200", "crossover_500x1260", "momentum_40x504", "momentum_500x1260", "dense_risk_features")
  run_arm <- function(id, round) {
    w <- dr_workloads[[id]]()
    on.exit(ledgr::ledgr_snapshot_close(w$snapshot))
    # The end-of-run summary reads the logical view, so the spike reader
    # rebuilds the holds inside the run; reported separately.
    dr_holds_cache$rebuild_s <- 0
    # The pulse loop's span: first P1 entry to last P5 exit, in every arm.
    span <- new.env(); span$first <- NA_real_; span$last <- NA_real_
    loop_names <- c("ledgr_fold_stage_observe_settle", "ledgr_fold_stage_commit")
    loop_orig <- lapply(stats::setNames(loop_names, loop_names), get, envir = ns)
    for (nm in loop_names) local({
      name <- nm; f <- loop_orig[[name]]
      unlockBinding(name, ns)
      assign(name, function(...) {
        if (is.na(span$first)) span$first <- proc.time()[["elapsed"]]
        on.exit(span$last <- proc.time()[["elapsed"]])
        f(...)
      }, envir = ns)
      lockBinding(name, ns)
    })
    on.exit(for (nm in loop_names) { unlockBinding(nm, ns); assign(nm, loop_orig[[nm]], envir = ns); lockBinding(nm, ns) },
            add = TRUE, after = FALSE)
    t0 <- proc.time()[["elapsed"]]
    bt <- tryCatch(suppressWarnings(ledgr::ledgr_run(w$exp, params = w$params, run_id = "fork", seed = w$seed)),
                   ledgr_diagnostic_corrupt = function(e) e)
    wall <- proc.time()[["elapsed"]] - t0
    out <- list(wall = wall - dr_holds_cache$rebuild_s, run_rebuild_s = dr_holds_cache$rebuild_s,
                loop_s = span$last - span$first)
    if (inherits(bt, "error")) return(c(out, list(refused = class(bt)[[1L]])))
    if (round == 1L) {
      dr_holds_cache$rebuild_s <- 0
      t0 <- proc.time()[["elapsed"]]
      trace <- ledgr::ledgr_results(bt, "diagnostics")
      out$read_s <- proc.time()[["elapsed"]] - t0
      out$rebuild_s <- dr_holds_cache$rebuild_s
      explain <- lapply(utils::head(sort(unique(trace$instrument_id[nzchar(trace$instrument_id)])), 2L),
                        function(i) as.data.frame(ledgr::ledgr_run_explain(bt, i)))
      close(bt)
      out$tables <- c(a0_store_tables(w$db, "fork"), a0_reader_tables(w$snapshot, "fork"), list(explain = explain))
    } else {
      close(bt)
    }
    out
  }
  if (gut) {
    for (id in ids) {
      r <- with_arm("records", run_arm(id, 2L))
      rows[[length(rows) + 1L]] <- data.frame(workload = id, path = "run", arm = "records", gut = TRUE,
                                              refused = r$refused %||% "not refused")
      cat(sprintf("%-20s %s\n", id, r$refused %||% "NOT REFUSED"))
    }
  } else {
    arms <- c("pin", "lean", "records")
    for (id in ids) {
      walls <- loops <- stats::setNames(vector("list", 3L), arms)
      tables <- list(); reads <- list()
      for (round in 1:3) for (arm in arms[(seq_along(arms) + round - 2L) %% 3L + 1L]) {
        r <- with_arm(arm, run_arm(id, round))
        walls[[arm]] <- c(walls[[arm]], r$wall)
        loops[[arm]] <- c(loops[[arm]], r$loop_s)
        if (round == 1L) {
          tables[[arm]] <- r$tables
          reads[[arm]] <- c(read_s = r$read_s, rebuild_s = r$rebuild_s, run_rebuild_s = r$run_rebuild_s)
        }
      }
      pin_implicit <- tables$pin$run_diagnostic_implicit
      fills_only <- pin_implicit[!is.na(pin_implicit$execution_seq), , drop = FALSE]
      rownames(fills_only) <- NULL
      med <- function(x) stats::median(x)
      for (arm in arms) {
        a <- tables$pin; b <- tables[[arm]]
        physical <- "run_diagnostic_implicit"
        implicit_ok <- NA
        if (identical(arm, "records")) {
          rec <- b[[physical]]; rownames(rec) <- NULL
          implicit_ok <- identical(rec, fills_only)
          a[[physical]] <- NULL; b[[physical]] <- NULL
        }
        cmp <- compare(a, b)
        rows[[length(rows) + 1L]] <- data.frame(workload = id, path = "run", arm = arm, gut = FALSE,
          tables = cmp[["tables"]], different = cmp[["different"]], first_difference = cmp[["first"]],
          implicit_is_pin_fills = implicit_ok, pin_implicit_rows = nrow(pin_implicit),
          stored_implicit_rows = nrow(tables[[arm]][[physical]]),
          median_wall_s = round(med(walls[[arm]]), 3), wall_ratio = round(med(walls[[arm]]) / med(walls$pin), 3),
          median_loop_s = round(med(loops[[arm]]), 3), loop_ratio = round(med(loops[[arm]]) / med(loops$pin), 3),
          diagnostics_read_s = round(reads[[arm]][["read_s"]], 3),
          in_run_rebuild_s = round(reads[[arm]][["run_rebuild_s"]], 3))
      }
      cat(sprintf("%-20s loop pin %.2f lean %.2f records %.2f s | identical %s, implicit = pin fills %s\n",
                  id, med(loops$pin), med(loops$lean), med(loops$records),
                  rows[[length(rows)]]$different == "0", rows[[length(rows)]]$implicit_is_pin_fills))
    }
  }
} else if (identical(mode, "a0")) {
  ids <- if (length(args) >= 4L) strsplit(args[[4L]], ",")[[1L]] else names(a0_workloads)
  for (id in ids) {
    base <- a0_run_workload(id, work)$tables
    strict <- with_arm("strict", a0_run_workload(id, work)$tables)
    for (path in union(names(base), names(strict))) {
      cmp <- compare(base[[path]], strict[[path]])
      rows[[length(rows) + 1L]] <- data.frame(workload = id, path = path, arm = "strict", gut = gut,
        tables = cmp[["tables"]], different = cmp[["different"]], first_difference = cmp[["first"]])
    }
    cat(sprintf("%-22s %s\n", id, if (all(vapply(rows, function(r) r$workload != id || r$different == "0", NA)))
      "identical" else "DIFFERENT"))
  }
} else {
  ids <- if (length(args) >= 4L) strsplit(args[[4L]], ",")[[1L]] else names(dr_workloads)
  arms <- c("pin", "lean", "strict")
  for (id in ids) {
    w <- dr_workloads[[id]]()
    grid <- ledgr::ledgr_grid_named(only = list(strategy = w$params))
    sweep_once <- function() {
      t0 <- proc.time()[["elapsed"]]
      obs <- a0_observe_memory(suppressWarnings(ledgr::ledgr_sweep(w$exp, grid, seed = w$seed, retain = a0_retain())))
      wall <- proc.time()[["elapsed"]] - t0
      list(wall = wall, tables = c(a0_sweep_tables(obs$value), a0_memory_tables(obs$observed, obs$value)))
    }
    walls <- stats::setNames(vector("list", 3L), arms)
    tables <- list()
    for (round in 1:3) for (arm in arms[(seq_along(arms) + round - 2L) %% 3L + 1L]) {
      r <- with_arm(arm, sweep_once())
      walls[[arm]] <- c(walls[[arm]], r$wall)
      if (round == 1L) tables[[arm]] <- r$tables
    }
    ledgr::ledgr_snapshot_close(w$snapshot)
    kept <- nrow(tables$pin$memory_diagnostics)
    for (arm in arms) {
      cmp <- compare(tables$pin, tables[[arm]])
      rows[[length(rows) + 1L]] <- data.frame(workload = id, path = "sweep_w1", arm = arm, gut = gut,
        tables = cmp[["tables"]], different = cmp[["different"]], first_difference = cmp[["first"]],
        kept_rows = kept, median_wall_s = round(stats::median(walls[[arm]]), 3),
        ratio_to_pin = round(stats::median(walls[[arm]]) / stats::median(walls$pin), 3))
    }
    cat(sprintf("%-20s kept %d  wall pin %.2f  lean %.2f  strict %.2f s  strict identical %s\n", id, kept,
                stats::median(walls$pin), stats::median(walls$lean), stats::median(walls$strict),
                rows[[length(rows)]]$different == "0"))
  }
}
res <- do.call(rbind, rows)
utils::write.csv(res, file.path(out, sprintf("fork_%s%s.csv", mode, if (gut) "_gut" else "")), row.names = FALSE)
