# Builds patched copies of the pinned source tree. Nothing in the
# repository's R/ changes.
#
#   edge  removes the internal re-checks on the per-pulse path and keeps every
#         check where data or code enters from outside (response review D1-D4).
#   gut   the edge tree plus one change to a staged diagnostic value; the
#         parity comparison must catch it.
#
# Every patch is an exact text replacement that must match exactly once.

ec_patches <- list(
  list(id = "carrier_group_checks", file = "R/fold-carrier.R",
       why = "internal: every carrier group a stage hands on, the publication block, legs, staging and equity",
       old = "  problem <- ledgr_carrier_problem(x, group, n_run, plan_axis)\n  if (!is.null(problem)) {",
       new = "  problem <- NULL\n  if (!is.null(problem)) {"),
  list(id = "append_check_on_write", file = "R/output-handler.R",
       why = "internal under D4: every producer of a fold event is a ledgr module; the read check stays",
       old = paste0("    prepared <- ledgr_validate_accounting_append(\n      rows,\n",
                    "      prior_event_seq = state$last_event_seq,\n",
                    "      prior_ts_utc = state$last_event_ts_utc\n    )"),
       new = paste0("    prepared <- list(event_seq = as.integer(rows$event_seq),\n",
                    "                     ts_utc = .POSIXct(as.numeric(rows$ts_utc), tz = \"UTC\"))")),
  list(id = "fill_payload_input_checks", file = "R/backtest-runner.R",
       why = "internal: P3's fill group and E's checked execution epochs",
       old = paste0("  if (n > 0L) ledgr_fill_input_check(fill, i)\n"),
       new = ""),
  list(id = "fill_payload_epoch_check", file = "R/backtest-runner.R",
       why = "internal: execution epochs are prepared and checked once in E",
       old = paste0("  ts_exec <- ledgr_assert_whole_second_utc(\n",
                    "    .POSIXct(fill$exec_ts[i], tz = \"UTC\"),\n",
                    "    label = \"`fill_intent$ts_exec_utc`\",\n",
                    "    class = \"ledgr_invalid_fill_intent\"\n  )"),
       new = "  ts_exec <- .POSIXct(fill$exec_ts[i], tz = \"UTC\")"),
  list(id = "lot_applied_self_check", file = "R/lot-accounting.R",
       why = "internal: the kernel re-checking its own applied rows",
       old = "  m <- length(input$pos)\n  opening <- input$operation == .ledgr_lot_opening\n  cons <- !opening\n  steps <- lots$steps",
       new = "  return(out)\n  m <- length(input$pos)\n  opening <- input$operation == .ledgr_lot_opening\n  cons <- !opening\n  steps <- lots$steps"),
  list(id = "p5_cash_reconciliation", file = "R/fold-engine.R",
       why = "internal: P5 compares two of ledgr's own cash computations; the staged reconciliation row stays",
       old = "    if (!isTRUE(all.equal(\n      as.numeric(fold_state$cash),",
       new = "    if (FALSE && !isTRUE(all.equal(\n      as.numeric(fold_state$cash),"),
  list(id = "p5_reconciliation_check", file = "R/fold-engine.R",
       why = "internal: the gross-exposure reconciliation of the same values",
       old = "    do.call(ledgr_fold_reconciliation_check, reconciliation_values)\n",
       new = "")
)

ec_gut <- list(id = "gut_reconciliation_outcome", file = "R/fold-engine.R",
               why = "gut: changes one staged diagnostic value",
               old = "      outcome = \"reconciled\",", new = "      outcome = \"gutted\",")

ec_build <- function(pinned, dest, kind = c("edge", "gut")) {
  kind <- match.arg(kind)
  if (dir.exists(dest)) unlink(dest, recursive = TRUE)
  dir.create(dest, recursive = TRUE)
  for (entry in list.files(pinned, all.files = TRUE, no.. = TRUE)) {
    file.copy(file.path(pinned, entry), dest, recursive = TRUE, copy.date = TRUE)
  }
  patches <- if (identical(kind, "gut")) c(ec_patches, list(ec_gut)) else ec_patches
  for (p in patches) {
    path <- file.path(dest, p$file)
    text <- paste(readLines(path, warn = FALSE), collapse = "\n")
    hits <- lengths(regmatches(text, gregexpr(p$old, text, fixed = TRUE)))
    if (hits != 1L) stop("patch ", p$id, " matched ", hits, " times", call. = FALSE)
    text <- sub(p$old, p$new, text, fixed = TRUE)
    writeLines(text, path)
    Sys.setFileTime(path, file.info(file.path(pinned, p$file))$mtime)
  }
  writeLines(paste0("d5b3a151+", kind), file.path(dest, "LEDGR_SOURCE_COMMIT"))
  invisible(dest)
}

ec_inventory <- function() {
  do.call(rbind, lapply(ec_patches, function(p) data.frame(patch = p$id, file = p$file, removes = p$why)))
}
