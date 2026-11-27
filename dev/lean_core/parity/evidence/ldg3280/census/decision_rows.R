# LDG-3280: writes the maintainer's amendment_test_inventory decisions
# (tickets.yml, Cut 27, 2026-11-27) into the inventory rows that census.md
# referred back (handling f). Each row keeps its question in `question`; the
# decision replaces handling, target_or_authority and justification.
# Handling g is new: kept unchanged until WS14 (decision 10). A row whose
# block splits across dispositions lists each letter, comma-separated.
#   Rscript decision_rows.R
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
p <- file.path(here, "inventory.csv")
x <- utils::read.csv(p, stringsAsFactors = FALSE, encoding = "UTF-8")
if (!"question" %in% names(x)) x$question <- ""
A <- "amendment_test_inventory"
set <- function(file, test, handling, target, why) {
  i <- which(x$file == file & x$test == test)
  if (length(i) != 1L) stop("no unique row: ", file, " / ", test)
  if (!startsWith(x$handling[[i]], "f") && !nzchar(x$question[[i]])) stop("not a referred row: ", test)
  if (startsWith(x$handling[[i]], "f")) x$question[[i]] <<- x$target_or_authority[[i]]
  x$handling[[i]] <<- handling
  x$target_or_authority[[i]] <<- target
  x$justification[[i]] <<- why
}
set("test-availability-state.R", "fixed baskets use the canonical valuation-state service", "b,c",
    paste(A, "(3): the claim splits. The owner half stays: a direct test that ledgr_availability_valuation_state values a fixed basket, with no fold (b, a remap that drops the fold run). The fold-calls-it half retires under lean_core_interface.md Section 19.11 (the constant fixed-basket packet on complete planes) (c)."),
    "The service keeps its owner witness; the fold no longer calls it on fixed baskets by accepted design, so asserting the call would test representation.")
set("test-cross-asset-corrections.R", "[LTB-0498] R and compiled FIFO share the dust boundary", "b,c,g",
    paste(A, "(9) with decision 10: the direct wrapper half (ledgr_run_compiled_spot_fifo_batch, ledgr_carrier_compiled_unpack) stays unchanged until WS14 (g). The public spot_fifo sweep comparisons become selector-equality witnesses under LR-25 (c). The ledgr_fold_stage_apply source anchor remaps to lean_p4_apply's position write (b)."),
    "Decision 10 keeps the compiled wrappers inert, so their direct witnesses stay; the public path runs fifo.R under LR-25.")
set("test-fold-phase-contract.R", "[LTB-0279] fold phase ownership rejects structural boundary drift", "c",
    paste(A, "(5): rebuilt in Cut 28 on the lean stages' read and write sets (dev/lean_core/parity/stage_state.R) with a written allowed-writes table per stage, the service-owner rules mapped to the lean call sites, and the 13 mutation kinds as lean fixtures, each shown caught. Cut 28 gate."),
    "The rebuild keeps the ownership guard from passing vacuously once the fold_state slots are gone.")
set("tools/check-fold-phase-contract.R", "<detector> tools/check-fold-phase-contract.R (ledgr_fold_phase_check, ledgr_fold_phase_source_findings, ledgr_fold_phase_function_sources)", "c",
    paste(A, "(5): rebuilt in Cut 28 with LTB-0279 (allowed-writes table over the stage_state.R read and write sets, 13 lean mutation fixtures). ledgr_fold_phase_function_sources() stays for ws4a_sources. Cut 28 gate."),
    "Same rebuild as LTB-0279.")
set("test-history-substrate.R", "[LTB-0293] availability fold ownership has one history reader", "c",
    paste(A, "(4): rebuilt as 'one history reader built at entry; stages read immutable planes by index': ledgr_history_substrate_fold_reader is built once in E, no stage receives the substrate object, and P1-P3 read prepared planes by index. Cut 28 gate."),
    "The lean ownership pattern differs from the pin's P1-owned packet; the decision states the new rule.")
set("test-risk-fold.R", "[LTB-0281] the envelope calls five typed stage packets in order", "a,b,c",
    paste(A, "(6): the stage order per pulse stays and needs a lean observation point (a, Cut 28 design item). The plan-batch, fill and rejection field sets stay, remapped to lean_plan_pulse's batch (identical names in plan.R) (b). The observe/decide/apply/commit packet field sets retire as representation-only (c)."),
    "The plan-batch fields map one to one; the packets have no lean counterpart.")
set("test-rng-isolation.R", "a seeded ambient-RNG fold agrees between ledgr_run and ledgr_sweep past the default checkpoint", "c",
    paste(A, "(8): resized to cross a terminal batch boundary (more than 65,536 rows, LR-20) so it guards the RNG neutrality of terminal store writes. Cut 28 gate."),
    "LR-20 moves the store write to the terminal batch; the block's witness target moves with it.")
set("test-run-telemetry.R", "diagnostic fold-loop telemetry records sampled buckets", "c",
    paste(A, "(2): sampled fold-loop telemetry and telemetry_stride retire with rules-ledger entry LR-27 (drafted for the maintainer's approval in LDG-3280); WS14's phase clocks replace them. test-api-exports.R's internal_boundaries entry for ledgr_run_prepare_telemetry_stride becomes a b row. Cut 28 gate."),
    "A real behaviour change, authorised by the decision and recorded as a ledger entry.")
set("test-ws4a-carrier.R", "[WS4a D7] openings take no Kahan step and keep a nonzero compensation", "a",
    paste(A, "(7): R/lot-accounting.R stays the owner for replay, import and recovery, and the block stays on it. The witness also covers lean_lot_opening (fifo.R) through a seam, which is a Cut 28 design item."),
    "Q3 names the no-opening-Kahan rule binding; after the switch the fold's openings run in fifo.R.")
set("test-ws4a-carrier.R", "[WS4a compiled boundary] pack and unpack gather typed lots and keep the Kahan state", "g",
    paste(A, "(9) with decision 10: kept unchanged until WS14; the compiled FIFO R wrappers stay inert."),
    "A direct test of functions decision 10 keeps.")
set("test-ws4a-carrier.R", "[WS4a V-book F4.12] aggregates are exact reductions at construction and exact zero when flat", "g",
    paste(A, "(9) with decision 10: the compiled-unpack assertion stays unchanged until WS14; the rest is a direct test of kept functions."),
    "A direct test of functions decision 10 keeps.")
set("test-ws4a-carrier.R", "[WS4a V-diagnostics V-equity V-stop U-3168] staging, equity and stop payloads are typed and refuse the controls", "c",
    paste(A, "(1): the reachability probe found no public input that reaches the staging-capacity refusal (dev/lean_core/parity/staging_reach_probe.R; evidence/ldg3280/staging: 235 workloads, smallest margin 6, no refusal). It retires with the staging buffer under rules-ledger entry LR-28, drafted for the maintainer's approval. The block's group-schema assertions are debug-only under LR-17, and its capture uses deleted functions. Cut 28 gate."),
    "Decision (1)'s 'none reaches it' branch; the refusal guarded the staging representation, not an input.")
utils::write.csv(x, p, row.names = FALSE, fileEncoding = "UTF-8")
cat("rows written; handling counts:\n")
print(table(x$handling))
