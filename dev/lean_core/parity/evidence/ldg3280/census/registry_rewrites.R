# LDG-3280, row review F2: every tests/claims.yml entry whose detecting block
# takes a c disposition, with the text Cut 28 writes (row R195). An entry is
# either rewritten (field, exact old text, new text) or survives (the reason
# its text stays true). Also regenerates claims_registry_affected.csv from the
# final inventory, with the rewrite status of each entry.
#   Rscript registry_rewrites.R
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
root <- normalizePath(file.path(here, "..", "..", "..", "..", "..", ".."), winslash = "/")
cl <- yaml::read_yaml(file.path(root, "tests", "claims.yml"))$claims
names(cl) <- vapply(cl, function(e) e$id, "")
x <- utils::read.csv(file.path(here, "inventory.csv"), stringsAsFactors = FALSE, encoding = "UTF-8", colClasses = "character")
out <- list()
whole <- function(lcl, rows, authority, field, new) {
  out[[length(out) + 1L]] <<- data.frame(lcl = lcl, rows = rows, authority = authority, action = "rewrite", field = field,
    old = cl[[lcl]][[field]], new = new, reason = "", stringsAsFactors = FALSE)
}
part <- function(lcl, rows, authority, field, old, new) {
  stopifnot(grepl(old, cl[[lcl]][[field]], fixed = TRUE))
  out[[length(out) + 1L]] <<- data.frame(lcl = lcl, rows = rows, authority = authority, action = "rewrite", field = field,
    old = old, new = new, reason = "", stringsAsFactors = FALSE)
}
keep <- function(lcl, rows, authority, reason) {
  out[[length(out) + 1L]] <<- data.frame(lcl = lcl, rows = rows, authority = authority, action = "survives", field = "",
    old = "", new = "", reason = reason, stringsAsFactors = FALSE)
}

# Compiled parity: suspended until WS14 (LR-25); direct wrappers kept (decision 10).
whole("LCL-0006", "R029 R030 R122", "LR-25; Cut 27 decision 10", "scope",
  "Spot-FIFO selector equality: a spot_fifo run runs the lean R FIFO after the two admission checks (LR-25), so the fold-level comparisons show both selectors agree; compiled-kernel parity is suspended until WS14 installs or retires the compiled FIFO, and the direct ledgr_cpp_spot_fifo_batch-versus-R-kernel witnesses stay (decision 10)")
whole("LCL-0006", "R029 R030 R122", "LR-25", "oracle_class", "selector equality (compiled cross-path parity suspended until WS14)")
whole("LCL-0014", "R121", "LR-25", "scope",
  "Release-only selector equality through persistence and the public sweep boundary; the compiled-arm claim is suspended until WS14 (LR-25)")
whole("LCL-0489", "R021", "amendment_test_inventory (9); LR-25; decision 10", "scope",
  "Canonical R and the compiled spot-FIFO wrappers project position from the same post-transition FIFO state without altering literal events, cash or realized P&L (direct wrapper witnesses, kept until WS14 by decision 10); the public spot_fifo sweep half is a selector-equality witness under LR-25")
# Event kinds: LR-29.
whole("LCL-0022", "R028", "LR-29", "scope",
  "Every pulse plan declares only kinds its accounting handles: the planner takes its kinds from a literal (no kind, or FILL with fills), guarded by a structural witness; the unsupported-kind refusal is debug-only (LR-29), and corporate-action kinds are refused for spot_fifo at fold entry")
whole("LCL-0022", "R028", "LR-29", "smallest_failing_change",
  "Let the planner declare any kind other than the two literals (for example CASHFLOW beside FILL); the structural witness fails and the production refusal must be restored.")
whole("LCL-0054", "R028", "LR-29", "scope",
  "Compiled execution refuses every declared non-FILL corporate-action accounting event at fold entry, before accounting; pulse plans declare only FILL by construction (LR-29)")
# Logical per-pulse commitment: LR-20.
whole("LCL-0136", "R088", "LR-20; D3-A R7/R9/R10; D3-B max_pulses", "scope",
  "Logical commitment is per pulse (LR-20): after each P5 the committed fill count covers that pulse's fills, two same-pulse fills publish as one block of two rows, and a two-pulse run publishes fills produced on its final processed pulse; physical writes are bounded terminal batches")
whole("LCL-0136", "R088", "LR-20", "oracle_class",
  "the committed fill count after each P5 (a Cut 28 observation point), the terminal batch count and the handler's write counters during a three-pulse, two-fill fold")
whole("LCL-0136", "R088", "LR-20", "smallest_failing_change",
  "Commit a pulse's fills on a later pulse, split a same-pulse block, or drop the final-pulse rows; the committed count, block count or published rows change.")
# Carrier shape: LR-17.
whole("LCL-0276", "R043", "LR-17; pulse plumbing R1/R2, Section 4", "scope",
  "The kept stop result and diagnostic rows have one typed shape (ledgr_fold_stop_result, ledgr_fold_diagnostic_rows; direct tests run with suite debug on); the locked fold-state carrier and its state and equity assertions retire with the package fold (LR-17)")
# Stage ownership: decision (5).
whole("LCL-0277", "R044 R196", "amendment_test_inventory (5)", "scope",
  "Each lean stage writes only the entries of its allowed-writes table over the stage_state.R read and write sets, service owners are called at their lean call sites, and each of the 13 mutation kinds is caught as a lean fixture")
whole("LCL-0277", "R044 R196", "amendment_test_inventory (5)", "smallest_failing_change",
  "Add an undeclared write to a lean stage, move a service-owner call to another stage, or introduce any registered mutation kind; the rebuilt checker names the finding.")
# Stage order and plan fields: decision (6).
whole("LCL-0279", "R087", "amendment_test_inventory (6)", "scope",
  "A pulse traverses the lean stages P1 to P5 in order (a Cut 28 observation point), and the plan batch, fill and rejection groups lean_plan_pulse returns keep their frozen field sets; the observe, decide, apply and commit packet field sets retire as representation-only")
whole("LCL-0279", "R087", "amendment_test_inventory (6)", "smallest_failing_change",
  "Reorder or skip a stage on a pulse, or add, drop or rename one plan-batch, fill or rejection field; the block fails.")
# One history reader: decision (4).
part("LCL-0288", "R047", "amendment_test_inventory (4)", "scope", "and P1-only fold reads",
  "and one fold history reader built at entry, with the stages reading prepared planes by index")
part("LCL-0288", "R047", "amendment_test_inventory (4)", "smallest_failing_change", "move a substrate read into P2, pass the substrate into P3-P5,",
  "build a second fold history reader, pass the substrate object into a stage,")
# The three named in pulse plumbing Section 7 (R195 as first written).
part("LCL-0506", "R064 R065", "pulse plumbing Section 7; LR-12", "scope", "(buffered DuckDB, db_live and memory)", "(durable DuckDB and memory)")
part("LCL-0506", "R064 R065", "pulse plumbing Section 7; LR-12", "scope", ", and the db_live writer keeps its validation order, sequence choice and transactional b",
  ", and the durable fold transaction rolls back a failed pulse's rows (single-path and transaction witnesses: test-risk-fold.R LTB-0280, LTB-0137); b")
part("LCL-0506", "R064 R065", "pulse plumbing Section 7; LR-12", "smallest_failing_change", ", or move it ahead of the db_live writer's validation", "")
part("LCL-0507", "R031", "LR-12; pulse plumbing Section 7", "scope", "a buffered DuckDB handler has no append_compiled_spot_batch binding and is refused, while the memory handler is admitted under the same buffered spec",
  "a DuckDB handler has no append_compiled_spot_batch binding and is refused, while the memory handler is admitted under the same spec (LR-12 drops the buffered-mode precondition)")
part("LCL-0508", "R066", "pulse plumbing Section 7; LR-12", "scope", "exactly today's 20 methods on a DuckDB sink (audit_log and db_live) and 25 on a memory sink",
  "exactly the post-switch method sets on the durable DuckDB sink and the memory sink (recorded at Cut 28, with every method removed with db_live named)")
part("LCL-0539", "R128", "pulse plumbing Section 5 Question 4; R8", "scope", "Schema 125", "The current store schema (the successor of 125)")
# Identity-rule literals: the rule number stated in the text (pre-existing drift: the text says 4 while the shipped rule is 5).
part("LCL-0234", "R022 R071", "pulse plumbing Section 5 Question 4", "scope", "identity_rule_version 4", "the current identity_rule_version (6 after Cut 28)")
part("LCL-0234", "R022 R071", "pulse plumbing Section 5 Question 4", "smallest_failing_change", "identity rule 4", "the current identity rule")
part("LCL-0262", "R022", "pulse plumbing Section 5 Question 4", "scope", "integer identity rule 4", "the current integer identity rule (6 after Cut 28)")
part("LCL-0242", "R072", "pulse plumbing Section 5 Question 4", "scope", "records identity rule 4", "records the current identity rule (6 after Cut 28)")

# c entries whose text survives.
keep("LCL-0027", "R019", "pulse plumbing Section 5 Question 4", "Policy closure and identity participation are unchanged; only the expected hash value moves with the rule bump.")
keep("LCL-0064", "R012", "LR-12", "The completion-evidence claim names no execution-mode field; the printed label list loses one line.")
keep("LCL-0106", "R082", "LR-12", "Schema-selection claim unchanged; the fixture drops execution_mode.")
keep("LCL-0111", "R083", "LR-12", "Alignment and precision claim unchanged; the expected line count changes.")
keep("LCL-0256", "R103", "pulse plumbing Section 5 Question 4; R8", "The claim is stated for the current schema; Cut 28 regenerates its fixture.")
keep("LCL-0258", "R105", "pulse plumbing Section 5 Question 4; R8", "No version literal in the text; marker 125 joins the older markers.")
keep("LCL-0264", "R048", "pulse plumbing Section 5 Question 4", "Locale-invariance claim names no rule version.")
keep("LCL-0285", "R045", "pulse plumbing Section 5 Question 4", "History-policy identity claim names no rule version.")
rw <- do.call(rbind, out)
utils::write.csv(rw, file.path(here, "registry_rewrites.csv"), row.names = FALSE, fileEncoding = "UTF-8")

# claims_registry_affected.csv from the final inventory (as merge_inventory.R
# built it), with each entry's rewrite status.
blocks <- x$claim[grepl("LTB-", x$claim)]
ltb <- unique(unlist(regmatches(blocks, gregexpr("LTB-[0-9]{4}", blocks))))
hit <- Filter(function(e) any(unlist(e$detecting_blocks) %in% ltb), cl)
reg <- data.frame(lcl = vapply(hit, function(e) e$id, ""),
  blocks = vapply(hit, function(e) paste(unlist(e$detecting_blocks), collapse = " "), ""), stringsAsFactors = FALSE)
reg$inventory_handling <- vapply(reg$blocks, function(bl) {
  ids <- strsplit(bl, " ")[[1L]]
  paste(vapply(ids, function(id) {
    w <- grep(id, x$claim, fixed = TRUE)
    paste0(id, ":", if (length(w)) paste0(x$row_id[w], "=", x$handling[w], collapse = "|") else "-")
  }, ""), collapse = " ")
}, "")
reg$registry <- ifelse(reg$lcl %in% rw$lcl[rw$action == "rewrite"], "rewrite",
  ifelse(reg$lcl %in% rw$lcl, "survives", "unchanged (no c disposition)"))
utils::write.csv(reg, file.path(here, "claims_registry_affected.csv"), row.names = FALSE)
cmiss <- reg$lcl[grepl("=[a-z,]*c", reg$inventory_handling) & reg$registry == "unchanged (no c disposition)"]
cat("registry rewrites:", sum(rw$action == "rewrite"), "fields in", length(unique(rw$lcl[rw$action == "rewrite"])), "entries;",
    length(unique(rw$lcl[rw$action == "survives"])), "survive; affected entries", nrow(reg), "\n")
if (length(cmiss)) stop("c entries with no registry disposition: ", paste(cmiss, collapse = ", "))
