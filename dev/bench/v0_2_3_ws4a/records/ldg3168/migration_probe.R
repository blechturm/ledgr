# LDG-3168 migrated-test controls (decision 10; ws4a_carrier_design.md
# Section 5): each migrated block passes on the product and fails under the
# violation its migration entry names. Prints one line per (control, block).
# Usage: Rscript migration_probe.R <worktree>
root <- commandArgs(TRUE)[[1L]]
suppressMessages(pkgload::load_all(root, quiet = TRUE))
ns <- asNamespace("ledgr")
fields <- c("ts", "cash", "positions_value", "realized_pnl", "cost_basis")
# Bare-name test calls resolve through the attached package copies.
put <- function(name, f) {
  utils::assignInNamespace(name, f, ns = ns)
  pe <- as.environment("package:ledgr")
  if (exists(name, pe, inherits = FALSE)) {
    unlockBinding(name, pe)
    assign(name, f, pe)
  }
}
block <- function(file, desc) {
  r <- as.data.frame(testthat::test_file(file.path(root, "tests", "testthat", file), reporter = "silent", desc = desc))
  sum(r$failed) + sum(r$error)
}
mutants <- list(
  drop_used_equity_row = list(ledgr_fold_equity_prefix = function(o) function(record) {
    record$n <- max(0L, record$n - 1L)
    o(record)
  }),
  expose_unused_equity_row = list(ledgr_fold_equity_prefix = function(o) function(record) {
    out <- record[fields]
    out$n <- length(record$ts)
    out
  }),
  equity_record_grows = list(ledgr_fold_equity_append = function(o) function(record, ...) {
    if (record$n >= length(record$ts)) for (f in fields) record[[f]] <- c(record[[f]], 0)
    o(record, ...)
  }),
  sink_equity_method = list(ledgr_output_handler = function(o) function(sink, ...) {
    h <- o(sink, ...)
    if (inherits(sink, "ledgr_output_sink_memory")) h$record_equity_fact <- function(...) invisible(TRUE)
    h
  }),
  plan_returns_segments = list(ledgr_fold_stage_plan = function(o) function(...) {
    out <- o(...)
    if (ledgr_is_fold_stop_result(out)) out else c(out[1L], list(diagnostic_segments = list()), out[-1L])
  }),
  block_missing_column = list(ledgr_fold_diagnostic_block = function(o) function(...) {
    b <- o(...)
    b$detail_json <- NULL
    b
  })
)
blocks <- list(
  drop_used_equity_row = list(c("test-ledger-writer.R", "[LTB-0521] typed state, equity and diagnostic stores keep values, classes and order across growth"),
    c("test-sweep.R", "inline accounting summary matches reconstruction with opening and split fill"),
    c("test-fold-phase-contract.R", "[LTB-0278] fold state and stop results have one closed typed shape")),
  expose_unused_equity_row = list(c("test-ledger-writer.R", "[LTB-0521] typed state, equity and diagnostic stores keep values, classes and order across growth")),
  equity_record_grows = list(c("test-fold-phase-contract.R", "[LTB-0278] fold state and stop results have one closed typed shape")),
  sink_equity_method = list(c("test-ledger-writer.R", "[LTB-0518] one output handler exposes exactly each storage kind's methods and owns the shared mechanisms")),
  plan_returns_segments = list(c("test-risk-fold.R", "[LTB-0281] the envelope calls five typed stage packets in order")),
  block_missing_column = list(c("test-availability-diagnostic-production.R", "the production diagnostic path defaults to one typed block"),
    c("test-availability-diagnostic-production.R", "typed diagnostic blocks split across injected chunks"))
)
for (m in names(mutants)) for (b in blocks[[m]]) {
  clean <- block(b[[1L]], b[[2L]])
  originals <- lapply(names(mutants[[m]]), function(n) get(n, ns))
  for (k in seq_along(originals)) put(names(mutants[[m]])[[k]], mutants[[m]][[k]](originals[[k]]))
  mutated <- block(b[[1L]], b[[2L]])
  for (k in seq_along(originals)) put(names(mutants[[m]])[[k]], originals[[k]])
  cat(sprintf("%-26s %-44s product %d failures, control %d -> %s\n", m, substr(b[[2L]], 1L, 44L), clean, mutated,
    if (clean == 0L && mutated > 0L) "FAILS AS REQUIRED" else "NOT SHOWN"))
}
