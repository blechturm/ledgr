# Replacement regression guts R1-R10 (LDG-3161; ws2_rng_design.md Section
# 8.3). Each gut undoes one shipped fix and must make its named predicate
# fail.
#
# Delivery: every gut, the control included, runs on a source copy. The
# committed tree (default HEAD) is archived into a scratch directory, one
# source edit is applied to the copy's R/ files, and the successor recorders
# run from the copy as fresh R processes. Workers started by the copy load the
# copy (R/parallel-workers.R loads the source path of the loaded package), so
# worker-sensitive guts such as R1 reach mirai daemons; no in-memory
# namespace patch is used. Each edit must match its source text exactly once.
# The comparators and the revert test runner run from this tree, unmutated,
# against the gut's records.
#
# Evidence per gut: the expected predicates (the Section 8.3 map), whether
# each failed, every other failing predicate, and errors counted apart:
# a recorder that exits non-zero, a comparator row that errored, or an
# erroring test block. A gut passes only when every expected predicate fails
# by its own check and no expected predicate failed through an error.
#
# Usage: Rscript guts.R [--guts=control,R1,...] [--commit=HEAD] [--work=<dir>] [--result=<csv>]

local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  here <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[[1L]])) else getwd()
  source(file.path(here, "lib.R"))
})
commit <- sr_arg("commit", "HEAD")
work <- sr_arg("work", file.path(tempdir(), "ldg3161_guts"))
result_file <- sr_arg("result", file.path(sr_dir, "guts.csv"))
rscript <- file.path(R.home("bin"), "Rscript")
reverts_runner <- file.path(sr_root, "dev", "bench", "v0_2_3_ws2_reverts", "runner.R")

# One edit: file, the exact original text, its replacement.
edit <- function(file, old, new) list(file = file, old = old, new = new)
# Expected predicates: rng comparator rows (table + predicate prefix), a0
# comparator predicate ids, or test blocks.
rng_pred <- function(table, prefix) list(kind = "rng", table = table, prefix = prefix)
a0_pred <- function(id) list(kind = "a0", id = id)
test_pred <- function(file, block) list(kind = "test", file = file, block = block)

guts <- list(
  control = list(what = "no edit (the delivery mechanism alone)", edits = list(),
    steps = c("rng", "a0", "test:rng-isolation", "test:pulse-seed-v2"), expect = list()),
  R1 = list(what = "kind_unpinned: ledgr_rng_seed_pinned seeds without a kind; the worker pin is a no-op",
    edits = list(
      edit("R/rng.R", 'set.seed(seed, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")', "set.seed(seed)"),
      edit("R/parallel-workers.R", 'quote(RNGkind("Mersenne-Twister", "Inversion", "Rejection")),', "quote(invisible(NULL)),")),
    steps = "rng",
    expect = list(rng_pred("worker_agreement", "statuses DONE; four agreement booleans TRUE"),
      rng_pred("stochastic_trades", "sweep_w2 rows equal sweep_w1 rows"))),
  R2 = list(what = "store_unguarded: ledgr_store_append calls DBI::dbAppendTable directly",
    edits = list(edit("R/rng.R", "ledgr_store_append <- function(con, name, value) {",
      "ledgr_store_append <- function(con, name, value) {\n  return(DBI::dbAppendTable(con, name, value))")),
    steps = "rng", expect = list(rng_pred("store_rng", "identical equities"))),
  R3 = list(what = "caller_unrestored: ledgr_rng_preserve_caller forces expr without restoring; storage neutrality kept",
    edits = list(edit("R/rng.R", "ledgr_rng_preserve_caller <- function(expr) {",
      "ledgr_rng_preserve_caller <- function(expr) {\n  return(expr)")),
    steps = c("rng", "test:rng-isolation"),
    expect = list(rng_pred("caller_rng", "every row unchanged"),
      test_pred("test-rng-isolation.R", "an unseeded run whose strategy draws leaves the caller's RNG unchanged"),
      test_pred("test-rng-isolation.R", "captured service expressions and returned helpers restore the caller's RNG"))),
  R4 = list(what = "wf_seed_na: ledgr_walk_forward_run_or_open passes the NA seed through again",
    edits = list(edit("R/walk-forward.R", "  if (length(seed) != 1L || is.na(seed)) {\n    seed <- NULL\n  }\n", "")),
    steps = "rng", expect = list(rng_pred("census", "operational outcomes ok; row 05"))),
  R5 = list(what = "pulse_shift: ledgr_pulse_seeds(s, p) returns v2 at p + 1",
    edits = list(edit("R/rng.R", "ledgr_rng_u32(as.numeric(pulse_idx))", "ledgr_rng_u32(as.numeric(pulse_idx) + 1)")),
    steps = c("rng", "a0:dense_risk_features"),
    expect = list(rng_pred("pulse_seeds", "keys identical; pulse_seed = independent v2 reference"), a0_pred("A4"))),
  R6 = list(what = "seed_ignoring: ledgr_pulse_seeds ignores the execution seed",
    edits = list(edit("R/rng.R", "ledgr_rng_u32(as.numeric(execution_seed))", "ledgr_rng_u32(7)")),
    steps = "rng",
    expect = list(rng_pred("pulse_seeds", "keys identical; pulse_seed = independent v2 reference"),
      rng_pred("stochastic_fills", "equal the pulse-rule model"),
      rng_pred("stochastic_trades", "run and sweep_w1 rows equal the pulse-rule model"))),
  R7 = list(what = "marker_stale: ledgr_seed_contract_current() returns v1",
    edits = list(edit("R/rng.R", 'paste0("ledgr_seed_v", ledgr_pulse_seed_rule_version)', '"ledgr_seed_v1"')),
    steps = "a0", expect = list(a0_pred("A1"), a0_pred("A2"))),
  # R8 as Section 8.3 writes it cannot reach A3: the unchanged validator
  # refuses every seeded configuration before a run row exists, and the A0
  # harness stops at the missing resumed run. R8v adds the validator's own
  # revert so the omitted field reaches config_json. R8v is an LDG-3161
  # proposal that needs a maintainer disposition; it is not counted for R8.
  R8 = list(what = "config_rule_dropped: the seeded config omits pulse_seed_rule (the configuration validator, unchanged, then refuses it)",
    edits = list(edit("R/backtest-config.R", "  if (!is.null(seed)) {\n    engine$pulse_seed_rule <- ledgr_pulse_seed_rule_version\n  }\n", "")),
    steps = "a0", expect = list(a0_pred("A3"))),
  R8v = list(what = "proposed variant of R8, pending maintainer disposition: the seeded config omits pulse_seed_rule and validation no longer requires it (the base configuration)",
    edits = list(edit("R/backtest-config.R", "  if (!is.null(seed)) {\n    engine$pulse_seed_rule <- ledgr_pulse_seed_rule_version\n  }\n", ""),
      edit("R/config-validate.R", "    if (!isTRUE(current_rule)) {", "    if (FALSE) {")),
    steps = "a0", expect = list(a0_pred("A3"))),
  R9 = list(what = "census_seed_caller: ledgr_fold_envelope calls set.seed directly again",
    edits = list(edit("R/fold-engine.R", "ledgr_rng_seed_pinned(as.integer(execution_seed))", "set.seed(as.integer(execution_seed))")),
    steps = "rng", expect = list(rng_pred("census", "set_seed_callers ledgr_rng_seed_pinned"))),
  R10 = list(what = "wf_marker_from_constant: the walk-forward candidate takes pulse_seed_contract from the constant",
    edits = list(edit("R/walk-forward-inspection.R", 'pulse_seed_contract = attr(results, "pulse_seed_contract", exact = TRUE)',
      "pulse_seed_contract = ledgr_seed_contract_current()")),
    steps = "test:pulse-seed-v2",
    expect = list(test_pred("test-pulse-seed-v2.R", "walk-forward candidates copy the results marker; old and missing are refused")))
)
selected <- sr_arg("guts")
selected <- if (is.null(selected)) names(guts) else strsplit(selected, ",", fixed = TRUE)[[1L]]
stopifnot(all(selected %in% names(guts)))

apply_edit <- function(tree, e) {
  path <- file.path(tree, e$file)
  txt <- paste(gsub("\r$", "", readLines(path, warn = FALSE)), collapse = "\n")
  hits <- gregexpr(e$old, txt, fixed = TRUE)[[1L]]
  if (sum(hits > 0L) != 1L) stop(sprintf("edit in %s matches %d times: %s", e$file, sum(hits > 0L), e$old), call. = FALSE)
  writeLines(sub(e$old, e$new, txt, fixed = TRUE), path)
}

run <- function(args, log) {
  t0 <- proc.time()[["elapsed"]]
  status <- suppressWarnings(system2(rscript, args, stdout = log, stderr = log))
  list(status = as.integer(status), secs = round(proc.time()[["elapsed"]] - t0))
}

rows <- list()
for (g in selected) {
  spec <- guts[[g]]
  gdir <- file.path(work, g)
  if (dir.exists(gdir)) stop("gut work directory exists: ", gdir, call. = FALSE)
  tree <- sr_archive(commit, file.path(gdir, "tree"), paths = c(sr_tree_paths, "dev/bench/v0_2_3_cut3_successors"))
  # Reuse this tree's compiled objects (src/ is never edited by a gut).
  built <- list.files(file.path(sr_root, "src"), pattern = "[.](o|dll|so)$", full.names = TRUE)
  file.copy(built, file.path(tree, "src"), overwrite = TRUE)
  for (e in spec$edits) apply_edit(tree, e)
  cat(sprintf("%s gut %s: %s\n", format(Sys.time(), "%H:%M:%S"), g, spec$what))
  errors <- character(); failing <- character(); rng_cmp <- NULL; a0_cmp <- NULL; tests <- NULL; captured <- character()
  for (step in spec$steps) {
    kind <- sub(":.*", "", step); arg <- if (grepl(":", step)) sub("^[^:]*:", "", step) else NULL
    log <- file.path(gdir, paste0(gsub("[^a-z0-9]+", "_", step), ".log"))
    if (kind == "rng") {
      out <- file.path(gdir, "rng")
      r <- run(c(shQuote(file.path(tree, "dev/bench/v0_2_3_cut3_successors/rng/probe.R")), paste0("--out=", shQuote(out))), log)
      if (r$status != 0L) { errors <- c(errors, sprintf("rng probe exit %d", r$status)); next }
      csv <- file.path(gdir, "rng_compare.csv")
      run(c(shQuote(file.path(sr_dir, "rng/compare.R")), paste0("--successor=", shQuote(out)), paste0("--result=", shQuote(csv))),
        file.path(gdir, "rng_compare.log"))
      rng_cmp <- utils::read.csv(csv, colClasses = "character")
      errors <- c(errors, sprintf("rng comparator error: %s", rng_cmp$detail[rng_cmp$predicate == "ERROR"]))
      failing <- c(failing, sprintf("rng %s: %s", rng_cmp$table, rng_cmp$predicate)[rng_cmp$status == "FAIL" & rng_cmp$predicate != "ERROR"])
      cen <- sr_read_csv(file.path(out, "census.csv")); cr <- sr_read_csv(file.path(out, "caller_rng.csv"))
      oc <- sr_value(cen$cells[, "outcome"]); co <- sr_value(cr$cells[, "outcome"])
      captured <- c(captured, sprintf("census %s: %s", sr_value(cen$cells[, "case"]), oc)[grepl("^ERROR", oc)],
        sprintf("caller_rng %s: %s", sr_value(cr$cells[, "case"]), co)[grepl("^ERROR", co)])
      changed <- sr_value(cr$cells[, "case"])[cr$cells[, "caller_rng_unchanged"] != '"TRUE"']
      if (length(changed)) captured <- c(captured, sprintf("caller_rng rows not unchanged: %s", paste(changed, collapse = ",")))
    } else if (kind == "a0") {
      out <- file.path(gdir, "a0")
      wl <- if (is.null(arg)) character() else paste0("--workloads=", arg)
      r <- run(c(shQuote(file.path(tree, "dev/bench/v0_2_3_cut3_successors/a0/record.R")), paste0("--out=", shQuote(out)), wl), log)
      if (r$status != 0L) { errors <- c(errors, sprintf("a0 record exit %d", r$status)); next }
      csv <- file.path(gdir, "a0_compare.csv")
      run(c(shQuote(file.path(sr_dir, "a0/compare.R")), paste0("--successor=", shQuote(out)), paste0("--result=", shQuote(csv)), wl),
        file.path(gdir, "a0_compare.log"))
      a0_cmp <- utils::read.csv(csv, colClasses = "character")
      errors <- c(errors, sprintf("a0 comparator error in %s: %s", a0_cmp$file, a0_cmp$detail)[a0_cmp$predicate == "ERROR"])
      fp <- unique(a0_cmp$predicate[a0_cmp$status == "FAIL" & a0_cmp$predicate != "ERROR"])
      failing <- c(failing, sprintf("a0 %s (%d files)", fp, vapply(fp, function(p) sum(a0_cmp$predicate == p & a0_cmp$status == "FAIL"), 1L)))
      conds <- list.files(out, pattern = "^run_conditions[.]csv$", recursive = TRUE)
      n_err <- sum(vapply(conds, function(f) {
        t <- sr_read_csv(file.path(out, f)); if (nrow(t$cells)) sum(t$cells[, "kind"] == '"error"') else 0L
      }, integer(1)))
      orig_err <- sum(vapply(conds, function(f) {
        p <- file.path(sr_root, "dev/bench/v0_2_3_output_freeze/records", f)
        if (!file.exists(p)) return(0L)
        t <- sr_read_csv(p); if (nrow(t$cells)) sum(t$cells[, "kind"] == '"error"') else 0L
      }, integer(1)))
      if (n_err > orig_err) captured <- c(captured, sprintf("a0 run errors recorded: %d (original %d)", n_err, orig_err))
    } else if (kind == "test") {
      csv <- file.path(gdir, paste0("test_", arg, ".csv"))
      r <- run(c(shQuote(reverts_runner), paste0("--root=", shQuote(tree)), "--mutation=none", paste0("--tests=", arg),
        paste0("--out=", shQuote(csv))), log)
      if (r$status != 0L || !file.exists(csv)) { errors <- c(errors, sprintf("test runner %s exit %d", arg, r$status)); next }
      t <- utils::read.csv(csv, stringsAsFactors = FALSE)
      t$error <- as.logical(t$error)
      tests <- rbind(tests, t)
      errors <- c(errors, sprintf("test block errored: %s / %s", t$file, t$test)[t$error])
      failing <- c(failing, sprintf("test %s: %s", t$file, t$test)[t$failed > 0L & !t$error])
    }
  }
  # Expected predicates: each must fail by its own check.
  status <- vapply(spec$expect, function(p) {
    if (p$kind == "rng") {
      if (is.null(rng_cmp)) return("not reached")
      hit <- rng_cmp$table == p$table & startsWith(rng_cmp$predicate, p$prefix)
      if (!any(hit)) return("not reached")
      if (any(rng_cmp$status[hit] == "FAIL")) "FAILED" else "held"
    } else if (p$kind == "a0") {
      if (is.null(a0_cmp)) return("not reached")
      hit <- startsWith(a0_cmp$predicate, p$id) | grepl(paste0("+", p$id), a0_cmp$predicate, fixed = TRUE)
      if (!any(hit)) return("not reached")
      if (any(a0_cmp$status[hit] == "FAIL")) "FAILED" else "held"
    } else {
      if (is.null(tests)) return("not reached")
      hit <- tests$file == p$file & tests$test == p$block
      if (!any(hit)) return("not reached")
      if (any(tests$error[hit])) "errored" else if (any(tests$failed[hit] > 0L)) "FAILED" else "held"
    }
  }, character(1))
  label <- vapply(spec$expect, function(p) switch(p$kind, rng = paste0("rng ", p$table, ": ", p$prefix),
    a0 = paste0("a0 ", p$id), test = paste0("test ", p$file, ": ", p$block)), character(1))
  verdict <- if (g == "control") {
    if (length(failing) == 0L && length(errors) == 0L) "PASS (nothing fails)" else "FAIL"
  } else if (length(status) && all(status == "FAILED") && length(errors) == 0L) "PASS" else "FAIL"
  rows[[length(rows) + 1L]] <- data.frame(gut = g, mutation = spec$what, steps = paste(spec$steps, collapse = " "),
    expected = paste(sprintf("%s [%s]", label, status), collapse = " | "),
    failing_checks = paste(failing, collapse = " | "),
    errors = length(errors), error_detail = paste(errors, collapse = " | "),
    captured_conditions = paste(captured, collapse = " | "), verdict = verdict, stringsAsFactors = FALSE)
  cat(sprintf("  -> %s; expected: %s; errors %d\n", verdict, paste(status, collapse = ","), length(errors)))
}
rep <- do.call(rbind, rows)
utils::write.csv(rep, result_file, row.names = FALSE)
cat(sprintf("guts: %d run, %d PASS -> %s\n", nrow(rep), sum(startsWith(rep$verdict, "PASS")), result_file))
