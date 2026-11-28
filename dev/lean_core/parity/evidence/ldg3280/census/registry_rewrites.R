# LDG-3280, row review F2 and re-review 1 N2: every tests/claims.yml entry
# whose detecting block takes a c disposition, with the text Cut 28 writes
# (row R195). An entry either survives whole (the reason its text stays true)
# or is rewritten; a rewritten entry lists every field: rewritten (exact old
# text, new text) or surviving (with a reason). The script stops if a
# rewritten entry leaves a field unlisted. It also regenerates
# claims_registry_affected.csv from the final inventory.
#   Rscript registry_rewrites.R
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
root <- normalizePath(file.path(here, "..", "..", "..", "..", "..", ".."), winslash = "/")
cl <- yaml::read_yaml(file.path(root, "tests", "claims.yml"))$claims
names(cl) <- vapply(cl, function(e) e$id, "")
x <- utils::read.csv(file.path(here, "inventory.csv"), stringsAsFactors = FALSE, encoding = "UTF-8", colClasses = "character")
text_of <- function(lcl, field) paste(unlist(cl[[lcl]][[field]]), collapse = " ")
out <- list()
put <- function(lcl, rows, authority, action, field, old, new, reason) {
  out[[length(out) + 1L]] <<- data.frame(lcl = lcl, rows = rows, authority = authority, action = action, field = field,
    old = old, new = new, reason = reason, stringsAsFactors = FALSE)
}
whole <- function(lcl, rows, authority, field, new) put(lcl, rows, authority, "rewrite", field, text_of(lcl, field), new, "")
part <- function(lcl, rows, authority, field, old, new) {
  stopifnot(grepl(old, text_of(lcl, field), fixed = TRUE))
  put(lcl, rows, authority, "rewrite", field, old, new, "")
}
same <- function(lcl, rows, authority, fields, reason) for (f in fields) put(lcl, rows, authority, "field survives", f, "", "", reason)
keep <- function(lcl, rows, authority, reason) put(lcl, rows, authority, "survives", "", "", "", reason)

# Compiled parity: suspended until WS14 (LR-25); direct wrappers kept (decision 10).
A <- "LR-25; Cut 27 decision 10"
whole("LCL-0006", "R029 R030 R122", A, "scope",
  "Spot-FIFO selector equality: a spot_fifo run runs the lean R FIFO after the two admission checks (LR-25), so the fold-level comparisons show both selectors agree; compiled-kernel parity is suspended until WS14 installs or retires the compiled FIFO, and the direct ledgr_cpp_spot_fifo_batch-versus-R-kernel witnesses stay (decision 10)")
whole("LCL-0006", "R029 R030 R122", A, "oracle_class", "selector equality (compiled cross-path parity suspended until WS14)")
whole("LCL-0006", "R029 R030 R122", A, "protected_contract_or_defect",
  "Under spot_fifo the public path gives the canonical selector's events, lot state, fills, retained equity and returns across reversal, multi-instrument, open, reduce, close and open-horizon cases; the compiled kernel's own arithmetic stays witnessed directly until WS14.")
whole("LCL-0006", "R029 R030 R122", A, "oracle_independence",
  "The canonical-selector run is the oracle for the spot_fifo run; the direct ledgr_cpp_spot_fifo_batch witnesses compare the compiled kernel with the R kernel on literal inputs. LTB-0014's reconstruction of retained compiled candidates is suspended with the compiled arm until WS14.")
whole("LCL-0006", "R029 R030 R122", A, "smallest_failing_change",
  "Let the spot_fifo selector change one event, lot, fill or retained series relative to the canonical selector, or change one compiled transition in the direct kernel witnesses.")
same("LCL-0006", "R029 R030 R122", A, c("detecting_blocks", "cheapest_adequate_lane"), "The same blocks and lanes; only what they witness changes.")
whole("LCL-0006", "R029 R030 R122", A, "overlapping_evidence",
  "Review LTB-0017 keeps the eight-pulse flat, partial and open-end matrix as a selector-equality witness (LCL-0014); compiled-arm parity is suspended until WS14.")
whole("LCL-0014", "R121", "LR-25", "scope",
  "Release-only selector equality through persistence and the public sweep boundary; the compiled-arm claim is suspended until WS14 (LR-25)")
whole("LCL-0014", "R121", "LR-25", "oracle_class", "selector equality (compiled cross-path parity suspended until WS14)")
same("LCL-0014", "R121", "LR-25", "detecting_blocks", "The same blocks.")
whole("LCL-0489", "R021", "amendment_test_inventory (9); LR-25; decision 10", "scope",
  "Canonical R and the compiled spot-FIFO wrappers project position from the same post-transition FIFO state without altering literal events, cash or realized P&L (direct wrapper witnesses, kept until WS14 by decision 10); the public spot_fifo sweep half is a selector-equality witness under LR-25")
whole("LCL-0489", "R021", "amendment_test_inventory (9); LR-25; decision 10", "oracle_class",
  "Independent scalar R transitions and compiled batches over empty-book and live-book multi-lot fixtures and an exact partial close in one and successive native batches (direct wrapper witnesses), plus public spot_fifo selector-equality sweeps and structural pins at the lean position write")
whole("LCL-0489", "R021", "amendment_test_inventory (9); LR-25; decision 10", "protected_contract_or_defect",
  "The optional compiled accounting wrappers stay semantically identical to canonical R accounting at fractional close boundaries until WS14 decides them; the public spot_fifo path runs the lean R FIFO.")
same("LCL-0489", "R021", "decision 10", c("detecting_blocks", "oracle_independence", "smallest_failing_change", "cheapest_adequate_lane"),
  "These describe the direct wrapper witnesses, which stay unchanged until WS14, and the two short public sweeps, which still run.")
whole("LCL-0489", "R021", "LR-25", "overlapping_evidence",
  "LCL-0006 owns broad selector equality and the direct kernel witnesses; this claim owns the machine-epsilon close boundary.")

# Event kinds: LR-29; LCL-0054 gains LTB-0036 as its fold-entry witness.
whole("LCL-0022", "R028", "LR-29", "scope",
  "Every pulse plan declares only kinds its accounting handles: the planner takes its kinds from a literal (no kind, or FILL with fills), guarded by a structural witness; the fold does not check the kinds in production (LR-29), and corporate-action kinds are refused for spot_fifo at fold entry")
whole("LCL-0022", "R028", "LR-29", "oracle_class", "structural witness over the planner's parsed source")
same("LCL-0022", "R028", "LR-29", c("detecting_blocks", "protected_contract_or_defect"), "The same block, and the same protected property: no declared economic event may be lost.")
whole("LCL-0022", "R028", "LR-29", "oracle_independence",
  "The test parses the planner and compares every plan's kinds argument with two literal expressions written in the test, and checks that every exit goes through lean_plan_result; it uses no production kind predicate.")
whole("LCL-0022", "R028", "LR-29", "smallest_failing_change",
  "Let the planner declare any kind other than the two literals (for example CASHFLOW beside FILL), or return a plan without lean_plan_result; the structural witness fails and the production refusal must be restored.")
whole("LCL-0022", "R028", "LR-29", "cheapest_adequate_lane", "One parse of the planner's source; fast.")
whole("LCL-0022", "R028", "LR-29", "overlapping_evidence",
  "LCL-0054 owns the spot_fifo FILL-only check at fold entry; LCL-0006 covers selector equality and contains no non-FILL event.")
whole("LCL-0054", "R028", "LR-29; LR-25", "scope",
  "Compiled execution refuses every declared non-FILL corporate-action accounting event at fold entry, before accounting; pulse plans declare only FILL by construction (LR-29)")
whole("LCL-0054", "R028", "LR-29; LR-25", "oracle_class", "direct table of the FILL-only check plus a public spot_fifo sweep refusal")
whole("LCL-0054", "R028", "LR-29; LR-25", "detecting_blocks", "LTB-0026 LTB-0036")
same("LCL-0054", "R028", "LR-29; LR-25", "protected_contract_or_defect", "The protected property is unchanged.")
whole("LCL-0054", "R028", "LR-29; LR-25", "oracle_independence",
  "Literal kinds are passed to the FILL-only check directly, and a dividend corporate action runs through a public spot_fifo sweep; the predicate is not copied into the expected side.")
whole("LCL-0054", "R028", "LR-29; LR-25", "smallest_failing_change",
  "Special-case CASHFLOW, omit DISPOSITION or accept unknown kinds in ledgr_require_compiled_spot_fifo_event_kinds(), or stop calling it on the corporate-action plan at fold entry.")
whole("LCL-0054", "R028", "LR-29; LR-25", "cheapest_adequate_lane", "A direct table call and one short public sweep; fast.")
whole("LCL-0054", "R028", "LR-29; LR-25", "overlapping_evidence",
  "LCL-0022 guards the planner's kinds; LCL-0031 owns the public dividend posting that LTB-0036 also exercises.")

# Logical per-pulse commitment: LR-20.
A <- "LR-20; D3-A R7/R9/R10; D3-B max_pulses"
whole("LCL-0136", "R088", A, "scope",
  "Logical commitment is per pulse (LR-20): after each P5 the committed fill count covers that pulse's fills, two same-pulse fills publish as one block of two rows, and a two-pulse run publishes fills produced on its final processed pulse; physical writes are bounded terminal batches")
whole("LCL-0136", "R088", A, "oracle_class",
  "the committed fill count after each P5 (a Cut 28 observation point), the terminal batch count and the handler's write counters during a three-pulse, two-fill fold")
whole("LCL-0136", "R088", A, "protected_contract_or_defect",
  "A three-pulse fold commits each pulse's fills on that pulse, writes two same-pulse fills as one block (LDG-3167) ordered AAA then BBB, and a two-pulse run publishes fills produced on its final processed pulse; physical writes are bounded terminal batches (LR-20).")
whole("LCL-0136", "R088", A, "oracle_independence",
  "The expected committed counts per pulse, the write count and the order come from the strategy's two named targets on the three-entry pulse fixture, not from the fold.")
whole("LCL-0136", "R088", A, "smallest_failing_change",
  "Commit a pulse's fills on a later pulse, split a same-pulse block, or drop the final-pulse rows; the committed count, block count or published rows change.")
whole("LCL-0136", "R088", A, "cheapest_adequate_lane",
  "One internal three-pulse fold with the production memory handler; fast, because it proves logical commitment without a timing threshold.")
whole("LCL-0136", "R088", A, "overlapping_evidence",
  "LTB-0135 proves handler staging and ordering; this claim owns when the fold commits a pulse's fills.")
same("LCL-0136", "R088", A, "detecting_blocks", "The same block.")

# Carrier shape: LR-17.
A <- "LR-17; pulse plumbing R1/R2, Section 4"
whole("LCL-0276", "R043", A, "scope",
  "The kept stop result and diagnostic rows have one typed shape (ledgr_fold_stop_result, ledgr_fold_diagnostic_rows; direct tests run with suite debug on); the locked fold-state carrier and its state and equity assertions retire with the package fold (LR-17)")
whole("LCL-0276", "R043", A, "oracle_class", "Direct stop-result and diagnostic-row constructor witnesses with hostile shapes, run with suite debug on")
whole("LCL-0276", "R043", A, "protected_contract_or_defect",
  "Early stage exits and diagnostic rows keep one typed shape; the lean stages' state is guarded by LCL-0277's allowed-writes table, not by a locked carrier.")
whole("LCL-0276", "R043", A, "oracle_independence",
  "The test enumerates the stop-result fields directly and supplies independently malformed stop and row inputs.")
whole("LCL-0276", "R043", A, "smallest_failing_change",
  "Add or remove one stop-result field, or weaken one stop-result or diagnostic-row type; the block fails.")
same("LCL-0276", "R043", A, c("detecting_blocks", "cheapest_adequate_lane"), "The same block, still a small in-memory internal-contract test.")
whole("LCL-0276", "R043", A, "overlapping_evidence",
  "LCL-0277 owns the lean stages' read and write sets; this block owns the stop and diagnostic-row shapes.")

# Stage ownership: decision (5).
A <- "amendment_test_inventory (5)"
whole("LCL-0277", "R044 R196", A, "scope",
  "Each lean stage writes only the entries of its allowed-writes table over the stage_state.R read and write sets, service owners are called at their lean call sites, and each of the 13 mutation kinds is caught as a lean fixture")
whole("LCL-0277", "R044 R196", A, "oracle_class",
  "An allowed-writes table over the parsed lean stage read and write sets, plus one lean fixture per mutation kind (13)")
whole("LCL-0277", "R044 R196", A, "oracle_independence",
  "The rebuilt checker parses the lean stage sources into read and write sets (dev/lean_core/parity/stage_state.R) and compares them with a written allowed-writes table; each mutation kind is an independent lean fixture.")
whole("LCL-0277", "R044 R196", A, "smallest_failing_change",
  "Add an undeclared write to a lean stage, move a service-owner call to another stage, or introduce any registered mutation kind; the rebuilt checker names the finding.")
same("LCL-0277", "R044 R196", A, c("detecting_blocks", "protected_contract_or_defect", "cheapest_adequate_lane"),
  "The same blocks, the same protected defect (two state authorities or a moved stateful call) and the same source-parse lane.")
whole("LCL-0277", "R044 R196", A, "overlapping_evidence",
  "LCL-0279 owns the runtime stage order; LCL-0276 owns the stop and diagnostic-row shapes; the recorded pin outcomes own observable parity.")

# Stage order and plan fields: decision (6).
A <- "amendment_test_inventory (6)"
whole("LCL-0279", "R087", A, "scope",
  "A pulse traverses the lean stages P1 to P5 in order (a Cut 28 observation point), and the plan batch, fill and rejection groups lean_plan_pulse returns keep their frozen field sets; the observe, decide, apply and commit packet field sets retire as representation-only")
whole("LCL-0279", "R087", A, "oracle_class",
  "A runtime observation of the stage order per pulse (a Cut 28 seam) and a wrapper of lean_plan_pulse over a real three-pulse fold")
whole("LCL-0279", "R087", A, "oracle_independence",
  "The block observes the stage sequence at the seam and compares the returned plan batch, fill and rejection groups with literal field lists.")
whole("LCL-0279", "R087", A, "smallest_failing_change",
  "Reorder or skip a stage on a pulse, or add, drop or rename one plan-batch, fill or rejection field; the block fails.")
same("LCL-0279", "R087", A, c("detecting_blocks", "protected_contract_or_defect", "cheapest_adequate_lane", "overlapping_evidence"),
  "The same block and lane; static checks still cannot prove the runtime sequence, and LCL-0277 still owns source structure.")

# One history reader: decision (4).
A <- "amendment_test_inventory (4)"
part("LCL-0288", "R047", A, "scope", "and P1-only fold reads",
  "and one fold history reader built at entry, with the stages reading prepared planes by index")
part("LCL-0288", "R047", A, "smallest_failing_change", "move a substrate read into P2, pass the substrate into P3-P5,",
  "build a second fold history reader, pass the substrate object into a stage,")
same("LCL-0288", "R047", A, c("detecting_blocks", "oracle_class", "protected_contract_or_defect", "oracle_independence", "cheapest_adequate_lane", "overlapping_evidence"),
  "The substrate claims are unchanged; 'competing history authority', 'the sole reader' and 'source ownership mutations' hold for the one reader built at entry.")

# The three named in pulse plumbing Section 7.
A <- "pulse plumbing Section 7; LR-12"
part("LCL-0506", "R064 R065", A, "scope", "(buffered DuckDB, db_live and memory)", "(durable DuckDB and memory)")
part("LCL-0506", "R064 R065", A, "scope", ", and the db_live writer keeps its validation order, sequence choice and transactional behavior",
  ", and the durable fold transaction rolls back a failed pulse's rows (single-path and transaction witnesses: test-risk-fold.R LTB-0280, LTB-0137)")
part("LCL-0506", "R064 R065", A, "smallest_failing_change", ", or move it ahead of the db_live writer's validation", "")
part("LCL-0506", "R064 R065", A, "cheapest_adequate_lane", "three handlers", "two handlers")
whole("LCL-0506", "R064 R065", A, "overlapping_evidence",
  "The recorded pin outcomes (LDG-3282) freeze the bytes of every published row; this claim owns the single-computation routing.")
same("LCL-0506", "R064 R065", A, c("detecting_blocks", "oracle_class", "protected_contract_or_defect", "oracle_independence"),
  "LTB-0516 retires with the writer (R065) and LTB-0515 keeps the durable and memory arms; the oracle, the protected defect and the shifted-value witness are unchanged.")
part("LCL-0507", "R031", "LR-12; pulse plumbing Section 7", "scope",
  "a buffered DuckDB handler has no append_compiled_spot_batch binding and is refused, while the memory handler is admitted under the same buffered spec",
  "a DuckDB handler has no append_compiled_spot_batch binding and is refused, while the memory handler is admitted under the same spec (LR-12 drops the buffered-mode precondition)")
whole("LCL-0507", "R031", "LR-12", "overlapping_evidence",
  "test-execution-spec.R keeps the memory admission parity tests; this claim owns the DuckDB refusal.")
same("LCL-0507", "R031", "LR-12", c("detecting_blocks", "oracle_class", "protected_contract_or_defect", "oracle_independence", "smallest_failing_change", "cheapest_adequate_lane"),
  "The refusal, its class and message, and the memory admission stay (pulse plumbing Section 7); no field names a retired mode.")
part("LCL-0508", "R066", A, "scope", "exactly today's 20 methods on a DuckDB sink (audit_log and db_live) and 25 on a memory sink",
  "exactly the post-switch method sets on the durable DuckDB sink and the memory sink (recorded at Cut 28, with every method removed with db_live named)")
whole("LCL-0508", "R066", A, "oracle_independence",
  "The method lists are written out at Cut 28 from the post-switch handler, with each method removed with db_live named, and are not read from the implementation at test time.")
whole("LCL-0508", "R066", A, "overlapping_evidence",
  "LTB-0517 owns the compiled-dispatch consequence of the method set; the recorded pin outcomes own the bytes the handler produces.")
same("LCL-0508", "R066", A, c("detecting_blocks", "oracle_class", "protected_contract_or_defect", "smallest_failing_change", "cheapest_adequate_lane"),
  "Frozen sets and source-ownership predicates stay; only the sets' contents change.")
A <- "pulse plumbing Section 5 Question 4; R8"
part("LCL-0539", "R128", A, "scope", "Schema 125", "The current store schema (the successor of 125)")
same("LCL-0539", "R128", A, c("detecting_blocks", "oracle_class", "protected_contract_or_defect", "oracle_independence", "smallest_failing_change", "cheapest_adequate_lane", "overlapping_evidence"),
  "No other field names a schema version; 'change the schema version' stays true of the successor.")
# Identity-rule literals (pre-existing drift: the text says 4 while the shipped rule is 5).
A <- "pulse plumbing Section 5 Question 4"
part("LCL-0234", "R022 R071", A, "scope", "identity_rule_version 4", "the current identity_rule_version (6 after Cut 28)")
part("LCL-0234", "R022 R071", A, "smallest_failing_change", "identity rule 4", "the current identity rule")
same("LCL-0234", "R022 R071", A, c("detecting_blocks", "oracle_class", "protected_contract_or_defect", "oracle_independence", "cheapest_adequate_lane", "overlapping_evidence"), "No rule version in these fields.")
part("LCL-0262", "R022", A, "scope", "integer identity rule 4", "the current integer identity rule (6 after Cut 28)")
same("LCL-0262", "R022", A, c("detecting_blocks", "oracle_class", "protected_contract_or_defect", "oracle_independence", "smallest_failing_change", "cheapest_adequate_lane", "overlapping_evidence"),
  "No current rule version in these fields ('rule-2 identity' is a refused old rule; the schema-121 gate wording is pre-existing drift, not from a c disposition).")
part("LCL-0242", "R072", A, "scope", "records identity rule 4", "records the current identity rule (6 after Cut 28)")
same("LCL-0242", "R072", A, c("detecting_blocks", "oracle_class", "protected_contract_or_defect", "oracle_independence", "smallest_failing_change", "cheapest_adequate_lane", "overlapping_evidence"), "No rule version in these fields.")
# A b row's entry with a retired mode word (re-review N2, optional).
part("LCL-0135", "R052", "LR-12", "protected_contract_or_defect", "Buffered persistent and memory handlers", "Durable and memory handlers")
same("LCL-0135", "R052", "LR-12", c("detecting_blocks", "scope", "oracle_class", "oracle_independence", "smallest_failing_change", "cheapest_adequate_lane", "overlapping_evidence"),
  "The handler's staging and flush behaviour survives the switch (R052).")

# c entries whose text survives whole.
keep("LCL-0027", "R019", "pulse plumbing Section 5 Question 4", "Policy closure and identity participation are unchanged; only the expected hash value moves with the rule bump.")
keep("LCL-0064", "R012", "LR-12", "The completion-evidence claim names no execution-mode field; the printed label list loses one line.")
keep("LCL-0106", "R082", "LR-12", "Schema-selection claim unchanged; the fixture drops execution_mode.")
keep("LCL-0111", "R083", "LR-12", "Alignment and precision claim unchanged; the expected line count changes.")
keep("LCL-0256", "R103", "pulse plumbing Section 5 Question 4; R8", "The claim is stated for the current schema; Cut 28 regenerates its fixture.")
keep("LCL-0258", "R105", "pulse plumbing Section 5 Question 4; R8", "No version literal in the text; marker 125 joins the older markers.")
keep("LCL-0264", "R048", "pulse plumbing Section 5 Question 4", "Locale-invariance claim names no rule version.")
keep("LCL-0285", "R045", "pulse plumbing Section 5 Question 4", "History-policy identity claim names no rule version.")
rw <- do.call(rbind, out)

# Completeness: a rewritten entry lists every one of its fields.
skip <- c("id", "owner", "promised_profile", "source")
for (lcl in unique(rw$lcl[rw$action == "rewrite"])) {
  missing <- setdiff(setdiff(names(cl[[lcl]]), skip), rw$field[rw$lcl == lcl])
  if (length(missing)) stop(lcl, ": fields not listed: ", paste(missing, collapse = ", "))
}
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
n_rw <- sum(rw$action == "rewrite")
cat("registry rewrites:", n_rw, "fields in", length(unique(rw$lcl[rw$action == "rewrite"])), "entries,",
    sum(rw$action == "field survives"), "fields kept with a reason;",
    length(unique(rw$lcl[rw$action == "survives"])), "entries survive whole; affected entries", nrow(reg), "\n")
if (length(cmiss)) stop("c entries with no registry disposition: ", paste(cmiss, collapse = ", "))
