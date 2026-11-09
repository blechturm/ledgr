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
  if (gut) return(function(diagnostics, n = NULL) logical(n %||% length(diagnostics$stage)))
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
install_arm <- function(arm) {
  if (identical(arm, "pin")) return(function() NULL)
  lean$lean_plan_stage <- if (identical(arm, "strict")) lean_strict_stage else lean_stage_inner
  restore_plan <- lean$lean_plan_install()
  if (!identical(arm, "strict")) return(restore_plan)
  originals <- lapply(stats::setNames(names(strict_bindings), names(strict_bindings)), get, envir = ns)
  for (name in names(strict_bindings)) {
    unlockBinding(name, ns)
    assign(name, strict_bindings[[name]](originals[[name]]), envir = ns)
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
if (identical(mode, "a0")) {
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
