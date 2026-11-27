# LDG-3280 census: every test_that block and helper function in the pin's
# tests/testthat, with its hits per pattern family. Read only.
#   Rscript census_blocks.R <pin tests/testthat dir> <probe dir> <out dir>
args <- commandArgs(TRUE)
tdir <- args[[1L]]; pdir <- args[[2L]]; odir <- args[[3L]]

old_only <- c("ledgr_fold_build_availability_pulse_plan", "ledgr_carrier_compiled_pack",
  "ledgr_carrier_compiled_unpack", "ledgr_compiled_spot_fifo_suspect", "ledgr_run_compiled_spot_fifo_batch",
  "ledgr_diagnostic_clean_fill", "ledgr_diagnostic_clean_hold", "ledgr_carrier_decision", "ledgr_carrier_packet",
  "ledgr_fold_diagnostic_block", "ledgr_fold_diagnostic_capacity", "ledgr_fold_diagnostic_staging",
  "ledgr_fold_equity_append", "ledgr_fold_equity_prefix", "ledgr_fold_staging_add", "ledgr_fold_staging_add_residual",
  "ledgr_plan_groups", "ledgr_carrier_result_state", "ledgr_context_preparation_increment",
  "ledgr_fold_fill_candidate", "ledgr_fold_flush_pulse_block", "ledgr_fold_scheduled_skip_decision",
  "ledgr_fold_scheduled_skip_plan", "ledgr_fold_stage_apply", "ledgr_fold_stage_commit", "ledgr_fold_stage_decide",
  "ledgr_fold_stage_observe_settle", "ledgr_fold_stage_plan", "ledgr_fold_apply_stop", "ledgr_fold_state_new",
  "ledgr_fold_state_validate", "ledgr_is_fold_stop_result", "ledgr_pulse_seed_at", "ledgr_fold_envelope")

pats <- c(
  old_fold = paste0("\\b(", paste(old_only, collapse = "|"), ")\\b"),
  fold_internal = paste0("ledgr_fold_stage_|ledgr_carrier_[a-z_]+|ledgr_fold_(equity|diagnostic|staging|state|stop|",
    "reconciliation|positions|plan_event|target_changed|scheduled|apply|flush|fill_candidate|build|availability_mark|",
    "warn_final|pulse_plan|phase)|ledgr_plan_(groups|resolve|refuse|epoch|side|kind|reason)|ledgr_execute_fold|",
    "ledgr_run_fold\\b|fold-engine|fold-carrier|fold-phase-contract"),
  mock = "with_mocked_bindings|local_mocked_bindings|\\btrace\\(|untrace\\(|assignInNamespace|unlockBinding",
  source_text = "readLines|parse\\(file|parse\\(text|deparse\\(|\\bbody\\(|check-fold-phase|tools/check|file\\.path\\([^)]*\"R\"",
  mode = "execution_mode|db_live|checkpoint_every|event_mode",
  debug_class = paste0("ledgr_internal_error|ledgr_invalid_fold_execution|ledgr_invalid_post_risk_targets|",
    "ledgr_invalid_pulse_plan|ledgr_invalid_state\\b|ledgr_invalid_fill_intent|ledgr_invalid_fill_input|",
    "ledgr_invalid_accounting_event|ledgr_invalid_ledger_meta|ledgr_ledger_write_result|",
    "ledgr_event_buffer_capacity_exceeded|ledgr_invalid_lot_fill|ledgr_lot_state_invariant|",
    "ledgr_diagnostic_resource_exhausted|ledgr_invalid_event_order|ledgr_risk_application_error"),
  flush = "flush",
  compiled = "spot_fifo|compiled_accounting_model|ledgr_compiled",
  ctx_method = "\\$\\.ledgr_pulse_context|t_pulse|fold_telemetry|telemetry_samples",
  seed = "pulse_seed",
  merged = paste0("ledgr_validate_strategy_targets|ledgr_unwrap_strategy_target|ledgr_validate_sizing_evidence|",
    "ledgr_apply_risk_plan|ledgr_apply_risk_step|ledgr_risk_context_equity|ledgr_risk_context_prices|",
    "ledgr_cost_model_resolve|ledgr_strategy_state_apply_values|ledgr_strategy_state_field\\b|",
    "ledgr_strategy_state_validate_value|ledgr_validate_post_risk_quantities|ledgr_unsupported_risk_step|",
    "ledgr_plan_resolve"),
  handler = "write_fill_events|run_transaction|ledgr_output_handler|output_handler\\$",
  worker = "ledgr_parallel_worker_setup|ledgr_sweep_eval_candidate_tasks_parallel|worker_load|load_expr")

is_tt <- function(f) {
  if (is.symbol(f)) return(identical(as.character(f), "test_that"))
  is.call(f) && identical(as.character(f[[1L]]), "::") && identical(as.character(f[[3L]]), "test_that")
}
blocks <- list()
walk <- function(e, file, lines, sr) {
  if (!is.call(e)) return(invisible())
  if (is_tt(e[[1L]])) {
    title <- tryCatch(eval(e[[2L]], baseenv()), error = function(err) paste(deparse(e[[2L]]), collapse = " "))
    blocks[[length(blocks) + 1L]] <<- list(file = file, test = as.character(title)[1L],
      first = sr[1L], last = sr[3L])
    return(invisible())
  }
  for (k in seq_along(e)) if (!missing(e[[k]]) && is.call(e[[k]])) walk(e[[k]], file, lines, NULL)
}
files <- list.files(tdir, pattern = "\\.R$", full.names = TRUE)
for (f in files) {
  ex <- parse(f, keep.source = TRUE)
  srs <- attr(ex, "srcref")
  pd <- utils::getParseData(ex)
  for (i in seq_along(ex)) {
    e <- ex[[i]]
    # locate nested test_that calls with their own srcrefs via parse data
  }
  calls <- pd[pd$token == "SYMBOL_FUNCTION_CALL" & pd$text == "test_that", ]
  for (j in seq_len(nrow(calls))) {
    # the expr node two levels up is the call
    p <- pd$parent[pd$id == calls$id[j]]
    p <- pd$parent[pd$id == p]
    if (pd$token[pd$id == p] != "expr") next
    node <- pd[pd$id == p, ]
    txt <- utils::getParseText(pd, p)
    ce <- tryCatch(parse(text = txt)[[1L]], error = function(err) NULL)
    title <- if (is.null(ce)) NA_character_ else
      tryCatch(as.character(eval(ce[[2L]], baseenv()))[1L], error = function(err) paste(deparse(ce[[2L]]), collapse = " "))
    blocks[[length(blocks) + 1L]] <- list(file = basename(f), test = title, first = node$line1, last = node$line2)
  }
}
b <- do.call(rbind, lapply(blocks, as.data.frame, stringsAsFactors = FALSE))
b <- b[!duplicated(b[c("file", "first")]), ]
src <- lapply(stats::setNames(files, basename(files)), readLines, warn = FALSE)
for (nm in names(pats)) {
  b[[nm]] <- vapply(seq_len(nrow(b)), function(i) {
    l <- src[[b$file[i]]][b$first[i]:b$last[i]]
    sum(grepl(pats[[nm]], l, perl = TRUE))
  }, 0L)
}
lean <- utils::read.csv(file.path(pdir, "b_suite_lean_tests.csv"), stringsAsFactors = FALSE)
seed <- utils::read.csv(file.path(pdir, "e_suite_classification.csv"), stringsAsFactors = FALSE)
key <- function(d) paste(d$file, d$test, sep = "\r")
m <- match(key(b), key(lean))
b$probe_failed <- lean$failed[m]; b$probe_error <- lean$error[m]; b$probe_skipped <- lean$skipped[m]
b$probe_matched <- !is.na(m)
b$in_seed <- key(b) %in% key(seed)
b$any_hit <- rowSums(b[names(pats)]) > 0L
utils::write.csv(b, file.path(odir, "census_hits.csv"), row.names = FALSE)
cat("blocks", nrow(b), "matched to probe", sum(b$probe_matched), "seed rows found", sum(b$in_seed), "of", nrow(seed), "\n")
cat("blocks with any hit", sum(b$any_hit), "\n")
for (nm in names(pats)) cat(nm, "blocks", sum(b[[nm]] > 0L), "lines", sum(b[[nm]]), "\n")
# helper files: hits outside test blocks (top level), per file
for (f in names(src)) {
  inb <- logical(length(src[[f]]))
  for (i in which(b$file == f)) inb[b$first[i]:b$last[i]] <- TRUE
  out <- src[[f]][!inb]
  h <- vapply(pats, function(p) sum(grepl(p, out, perl = TRUE)), 0L)
  if (any(h > 0L)) cat("TOPLEVEL", f, paste(names(h)[h > 0L], h[h > 0L], sep = "=", collapse = " "), "\n")
}
