# LDG-3280: the correction round after the independent Type 1 row review
# (inst/design/ledgr_v0_2_3_spec_packet/inventory_row_review.md, 2026-11-27,
# CHANGES_REQUIRED). Each edit names the finding it answers. The maintainer
# agreed the routing on 2026-11-28, including R013 option (a) and R028
# probe-first. Rerunning is safe: each edit checks the text it replaces or
# that it has already been applied.
#   Rscript review_corrections.R
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
p <- file.path(here, "inventory.csv")
x <- utils::read.csv(p, stringsAsFactors = FALSE, encoding = "UTF-8", colClasses = "character")
row <- function(id) { i <- which(x$row_id == id); if (length(i) != 1L) stop("no unique row ", id); i }
# Replace one exact fragment of a field (no-op if `new` is already there).
fix <- function(id, field, old, new) {
  i <- row(id); v <- x[[field]][[i]]
  if (grepl(new, v, fixed = TRUE)) return(invisible())
  if (!grepl(old, v, fixed = TRUE)) stop(id, " ", field, ": text not found: ", old)
  x[[field]][[i]] <<- sub(old, new, v, fixed = TRUE)
}
set <- function(id, field, new) x[[field]][[row(id)]] <<- new
add <- function(id, field, text) { i <- row(id); if (!grepl(text, x[[field]][[i]], fixed = TRUE)) x[[field]][[i]] <<- paste(x[[field]][[i]], text) }

# F1: LR-27 (approved 2026-11-27) retires telemetry_stride and its validator.
fix("R026", "asserts", "including checkpoint_every and event_mode", "including checkpoint_every, event_mode and telemetry_stride")
fix("R026", "depends_on", "(checkpoint_every, event_mode)", "(checkpoint_every, event_mode, telemetry_stride)")
fix("R026", "target_or_authority", "LR-12 (execution_mode/event mode removed) and LR-20 (checkpoint_every retired): the frozen list loses checkpoint_every and event_mode;",
    "LR-12 (execution_mode/event mode removed), LR-20 (checkpoint_every retired) and LR-27 (telemetry_stride retired; row review F1): the frozen list loses checkpoint_every, event_mode and telemetry_stride;")
for (id in c("R182", "R186")) {
  fix(id, "asserts", "with checkpoint_every = 0L and event_mode = \"buffered\"", "with checkpoint_every = 0L, event_mode = \"buffered\" and telemetry_stride = 0L")
  fix(id, "depends_on", "ledgr_execution_spec(checkpoint_every =, event_mode =) fields retired", "ledgr_execution_spec(checkpoint_every =, event_mode =, telemetry_stride =) fields retired")
}
fix("R182", "target_or_authority", "Drop the two retired arguments when Cut 28 removes the spec fields;",
    "Drop the three retired arguments (checkpoint_every and event_mode: LR-12, LR-20; telemetry_stride: LR-27, row review F1) when Cut 28 removes the spec fields;")
fix("R186", "target_or_authority", "Drop the checkpoint_every and event_mode arguments when Cut 28 removes the spec fields (LR-12, LR-20);",
    "Drop the checkpoint_every, event_mode and telemetry_stride arguments when Cut 28 removes the spec fields (LR-12, LR-20, LR-27; row review F1);")
fix("R101", "target_or_authority", "(drafted for the maintainer's approval in LDG-3280)", "(approved by the maintainer 2026-11-27)")
fix("R101", "target_or_authority", "test-api-exports.R's internal_boundaries entry for ledgr_run_prepare_telemetry_stride becomes a b row.",
    "test-api-exports.R's internal_boundaries entry for ledgr_run_prepare_telemetry_stride is row R197.")
if (!"R197" %in% x$row_id) {
  x <- rbind(x, data.frame(row_id = "R197", file = "test-api-exports.R", test = "exported API surface is locked", claim = "",
    asserts = "The export list is frozen, retired runners are absent, and each name in internal_boundaries exists in the namespace, ledgr_run_prepare_telemetry_stride among them.",
    depends_on = "ledgr_run_prepare_telemetry_stride (retired with telemetry_stride by LR-27)", in_seed = "no", probe_status = "pass",
    handling = "c",
    target_or_authority = "LR-27 (approved 2026-11-27): drop \"ledgr_run_prepare_telemetry_stride\" from internal_boundaries; the other nine boundaries and every other assertion are unchanged. Cut 28 gate: the validator exists until Cut 28 deletes it.",
    justification = "Row review F1; census.md's exclusion of test-api-exports.R named this condition. Labelled c, not b: the entry is dropped because an authorized retirement removes the function, as R026 drops retired spec fields.",
    question = "", stringsAsFactors = FALSE))
}

# F2: the claims registry follows every c disposition (registry_rewrites.csv).
fix("R195", "test", "LCL-0506 (LTB-0515, LTB-0516), LCL-0508 (LTB-0518), LCL-0539 (LTB-0550) registry entries",
    "claims.yml entries whose text a block disposition changes (registry_rewrites.csv: LCL-0006, LCL-0014, LCL-0022, LCL-0054, LCL-0136, LCL-0234, LCL-0242, LCL-0262, LCL-0276, LCL-0277, LCL-0279, LCL-0288, LCL-0489, LCL-0506, LCL-0507, LCL-0508, LCL-0539)")
add("R195", "target_or_authority", "Row review F2: Section 7's examples are not a blanket waiver, so every registry entry whose text a c disposition changes is rewritten at Cut 28, each by its row's own authority; census/registry_rewrites.csv lists the entries, the fragment and its replacement, and the entries whose text survives with the reason. Cut 28 gate: the registry text describes shipped behaviour until the switch.")

# F3: R013 option (a), the maintainer 2026-11-28.
set("R013", "handling", "c")
set("R013", "target_or_authority", paste(
  "amendment_test_inventory (3) with row review F3, option (a) (maintainer 2026-11-28): the owner witness is the existing test-ws4a-carrier.R block",
  "\"[WS4a F4.19] the provider adapter keeps unpriced provenance field by field\", which calls ledgr_availability_valuation_state with no fold and asserts its values",
  "(BBB's reference 20 and age 4, the stale/frozen/current mark sources) and passes on the candidate (census part_ws4a_excluded.txt).",
  "The fold-calls-it half retires under lean_core_interface.md Section 19.11. The block is deleted at Cut 28: its remaining DONE check alone would be near vacuous (census finding 2). Cut 28 gate."))
set("R013", "justification", "The pin block's only oracles were DONE and the call count (remaps/R013/finding.md); F4.19 already owns the service's values, so no new test is needed.")

# F4: rows that need a stage seam join the design item.
set("R147", "handling", "a,b")
set("R147", "target_or_authority", paste(
  "Empty-plan half (b): through R194's remapped helper ws4b_test_build_pulse_plan (lean_plan_pulse), demonstrated in remaps/R194.",
  "Skip half (a, row review F4; cut28_design_item.md): observe that a skipped pulse reconciles against the fold cash, with the +1 mutant injected at P5's skip reconciliation",
  "(expected <- if (is.null(batch)) cash, in lean_p5_commit). A source-text anchor instead would be a weakening (remaps/R147/finding.md)."))
set("R088", "handling", "a,c")
add("R088", "target_or_authority", "The committed-count witness needs an observation of n_committed after each P5 (an envelope variable that lean_p5_commit writes), listed in cut28_design_item.md (row review F4).")

# F5: R087's b part and R091 are named Cut 28 gates.
fix("R087", "target_or_authority", "The plan-batch, fill and rejection field sets stay, remapped to lean_plan_pulse's batch (identical names in plan.R) (b).",
    "The plan-batch, fill and rejection field sets stay, remapped to lean_plan_pulse's batch (identical names in plan.R) (b): wrap lean_plan_pulse with the same capture, take its last returned batch and keep the three frozen name lists (names(batch), names(batch$fill), names(batch$rejection)). Cut 28 gate (row review F5): the capture must wrap lean_plan_pulse inside a running fold, which local_mocked_bindings() reaches only once it is a package function; a direct call would replace the fold fixture.")
add("R091", "target_or_authority", "Cut 28 gate (row review F5), as R092: the merged long-only step exists only after the deletion-readiness 4.3 merge.")

# F6: R028 resolved by the reachability probe and LR-29 (drafted).
set("R028", "handling", "b,c")
set("R028", "target_or_authority", paste(
  "LR-29 (approved by the maintainer 2026-11-28; row review F6): both planners declare their kinds only from a literal, no kind or FILL when the plan has fills",
  "(dev/lean_core/parity/event_kind_reach_probe.R; evidence/ldg3280/event_kinds), so no public input reaches the unsupported pulse-plan kind refusal. The switched fold does not check it in production.",
  "Today only the harness adapter lean_stage_plan checks it, in debug; Cut 28 adds the same debug-only calls (ledgr_fold_plan_event_kinds, and the FILL-only check when the selector is spot_fifo) to lean_p3_plan, as lean_core_interface.md's P3 placement ('Event kinds | debug-only | P4') states (re-review N1). ledgr_fold_plan_event_kinds is defined in R/fold-engine.R, which the switch deletes, so Cut 28 moves it unchanged beside lean P3 (re-review 2, M3).",
  "LR-29 reconciles that placement with pulse-plumbing Section 4's 'unsupported-kind' refusal under R3.",
  "c: the mocked-planner runs retire; the replacement witness checks that every plan lean_plan_pulse returns declares one of the two literal kinds, that every exit goes through lean_plan_result, which passes the kinds on unchanged, and that `none` is the empty integer (re-review N6), so a planner that declares another kind fails first and must restore the production refusal.",
  "The spot_fifo refusal of corporate-action kinds stays at fold entry (ledgr_require_compiled_spot_fifo_event_kinds on the corporate-action plan). Its public witness, [LTB-0036] in test-corporate-action-cash.R, reaches only CASHFLOW, so the remapped block keeps a direct, mock-free table of that check for CASHFLOW, DISPOSITION and an unknown kind (re-review N3).",
  "b: the P4 source anchors move to lean_p4_apply (fill <- batch$fill; applied <- lean_lot_fill_checked(book, fill); no per-fill loop); the 'fills = fill' anchor was the compiled arm's hand-off (LR-25). Demonstrated in remaps/R028."))
set("R028", "justification", "Row review F6 (NEEDS_TYPE_2). The pin's refusal was reachable only through the test's mocked planner: both planners build kinds from literals. The decision-(1) pattern (LR-28) applies.")

# F7: R060 keeps its chained oracle; R073/R074 count the service preparer; R077 relabelled.
fix("R060", "target_or_authority", "Call-site remap: publish the same one-row fill group through the surviving durable path",
    "Call-site remap (row review F7): publish the same one-row fill groups through the surviving durable path, chaining the second write's event_seq from the first write's returned next_event_seq (the handler's write_fill_events() returns the payload block, R/backtest-runner.R ledgr_fill_event_payload: next_event_seq = seq[[n]] + 1L), keeping expect_identical(r2$event_seq, 2L) and the stored c(1L, 2L);")
fix("R060", "justification", "On the surviving path the sequence comes from the handler's event_seq argument, so the remap passes 1 then 2 and reads the stored rows.",
    "Passing 2 in directly would make the 2L oracle a tautology; chaining through next_event_seq keeps it able to fail.")
for (id in c("R023", "R049", "R059", "R060", "R061")) {
  fix(id, "target_or_authority", "Cut 28 gate: applies only if Cut 28 deletes ledgr_write_fill_events under R8 ('delete live dispatch/writer paths'); if it is kept the block is unchanged",
      "Cut 28 gate: Cut 28 deletes ledgr_write_fill_events (pulse plumbing Section 7: 'Delete live dispatch/writer paths rather than preserve an ignored mode'; row review F9)")
}
for (id in c("R073", "R074")) {
  fix(id, "target_or_authority", if (id == "R073") "service -> one lean envelope entry per run (or ledgr_strategy_schedule_query, loop.R:266)." else "and lean envelope entries:",
      if (id == "R073") "service -> ledgr_strategy_schedule_query (row review F7: the pin's 'service' increment follows that call, R/fold-engine.R:1842-1847; lean E calls it once, loop.R:266; remaps/<row>/witness_service shows a per-pulse schedule query caught)." else
        "and ledgr_strategy_schedule_query (row review F7, as R073):")
}
set("R077", "handling", "b,c")
add("R077", "target_or_authority", "The dropped runtime 'reads' count is a semantic change (c), approved by the maintainer on 2026-11-27 with the row ('accepted all'); the rest is b (row review F7).")

# F8: the README's approved corrections written into their rows.
add("R131", "target_or_authority", "Census allowances (approved 2026-11-27): lean_p4_apply's ordinal match(differs, clean_k, 0L); in lean_fold_envelope_plain, P2's named positions snapshot, the debug-only setNames(tq, ids) and execution-view field comparison, P4's ordinal match and the named result state; none in the lean kernel. The compiled-FIFO wrappers stay in the scanned set (decision 10).")
add("R133", "target_or_authority", "Census allowances (approved 2026-11-27): the write predicate's variable set gains lean's name pos; two lean named sources, fl$pos[rows] <<- fill$pos and rj$pos <<- c(rj$pos, rejection$pos), which write no position.")
add("R144", "target_or_authority", "Census allowances (approved 2026-11-27): P2's positions-snapshot names and the debug-only setNames(tq, ids), P3's debug view comparison by field name, and the skip's mark-source token test; the exactness check applies the block's full predicate (name-keyed plus %in%).")
add("R150", "target_or_authority", "Census allowances (approved 2026-11-27): lean_plan_affordability's match(id_perm, axis_pos, 0L) (integer axis positions) and lean_p3_plan's debug-only field-name comparison; ledgr_fold_scheduled_skip_plan leaves the planner set.")
add("R135", "target_or_authority", "Kernel scan (row review F8, restated after re-review N5): after the switch the fold's kernel is fifo.R. The remapped D25 set already holds lean_p4_apply and lean_lot_first_failure, and its ops list already bans lean_lot_* calls inside loops; fifo.R's other kernel functions (lean_lot_apply, lean_lot_simple, lean_lot_general, lean_lot_apply_blocks) are not in it. D3 (R131) scans indexing, not loops. Decided by the maintainer 2026-11-28, option (a): D25 scans the whole fold kernel. With the kernel merge in Cut 28 (deletion-readiness addendum 1, Section 3 (b)), fifo.R's kernel becomes the body of the package's ledgr_lot_apply and its operations, so D25's existing kernel names cover it; each of its loops (fifo.R:266, :339, :422, :606, :618 on 867a93ac) is either listed by its header as an approved exception, with its reason, or rewritten. Cut 28 gate for this addition: the merged kernel exists only after the merge.")
for (id in c("R157", "R173")) {
  set(id, "target_or_authority", "No remap of its own (row review F8): the block's only dependence is the fixture helper ws4a_3166_plan, row R189, whose remap keeps the plan identical() to the pin's (remaps/R189/identity_probe.csv); the block text and its validator assertions are unchanged.")
}
fix("R158", "target_or_authority", "drop write_fill_live (deleted under LR-12) and flush_pulse_events (deleted under LR-20) from the closure list",
    "keep handler$flush_pulse_events in the closure list (the lean terminal transfer calls it, lean_facts_emit; row review F8); sink$write_fill_live leaves the list when Cut 28 removes db_live (LR-12; Cut 28 gate for that entry). Exceptions (approved 2026-11-27), all per batch of at most `bound` rows, never per fill: lean P4's capacity-doubling loop; lean_loop_publish's range and batch loops, its lapply() column cuts and batch ranges, the implicit batch count list() and the completion row's two .POSIXct epochs; lean_facts_emit's run and batch loops and its applied-columns list per batch; lean_facts_emit_ca's batch loop")
fix("R159", "target_or_authority", "census entries for flush_pulse_events dropped with the closure (LR-20)",
    "the census entry for handler$flush_pulse_events stays (the lean terminal transfer calls it; row review F8); sink$write_fill_live leaves the closure list when Cut 28 removes db_live (LR-12; Cut 28 gate for that entry). Census allowance (approved 2026-11-27): lean_p4_apply's ordinal match(differs, clean_k, 0L)")
for (id in c("R180", "R185")) {
  add(id, "target_or_authority", "Cut 28 gate on the deletion-readiness 4.4 cost merge (row review F8): the demonstrated patch calls lean_plan_pulse with cost_steps = NULL, which resolves through ledgr_plan_resolve(), deleted at the merge; Cut 28 reapplies the remap against the merged resolver.")
}
add("R180", "target_or_authority", "If the merged resolve takes only package resolvers, this helper's closure resolver (unrounded prices) becomes a fixture finding for the maintainer.")
for (id in c("R189", "R194")) {
  add(id, "target_or_authority", "The patch passes cost_steps = lean_cost_steps(cost_resolver); lean_cost_steps goes at the 4.4 cost merge, so Cut 28 reapplies the call against the merged resolver (row review F8).")
}
add("R189", "target_or_authority", "Witness: identity probe (row review F12): the remapped helper's plan is identical() to the pin's for the file's four fixture calls, debug on and off (remaps/R189/identity_probe.csv).")

# F9: handling letters and texts after the decisions.
set("R165", "handling", "e,c")
add("R165", "target_or_authority", "Packet half (c, LR-13, as R138; row review F9): drop the ws4a_v201_groups capture and the .ledgr_carrier_field_parts sweep control that expects ledgr_internal_error; the overflow witnesses stay. Cut 28 gate: the capture's functions are deleted at the switch.")
set("R166", "handling", "b,c,g")
set("R166", "target_or_authority", paste(
  "Row review F9. g (decision 10, as R021): the direct ledgr_run_compiled_spot_fifo_batch wrapper assertions stay unchanged until WS14.",
  "c (LR-25): the appended > 0 count observes the compiled publication arm, which the public spot_fifo path no longer reaches, and is dropped; the DONE/1000 sweep assertion stays.",
  "b: the canonical-candidate line moves from the deleted ledgr_fold_fill_candidate to lean_lot_fill then lean_lot_first_failure (fifo.R), as R163. Demonstrated in remaps/R166."))
fix("R169", "target_or_authority", "rules-ledger entry LR-28, drafted for the maintainer's approval.", "rules-ledger entry LR-28, approved by the maintainer 2026-11-27.")

# Re-review 1 (inventory_row_review_rereview_1.md, CHANGES_REQUIRED): N1, N3
# and N6 are in R028's text above, N5 in R135's, N4 and N7 here.
fix("R073", "justification", "The 'service' bundle has no lean object; mapping it to one envelope entry is the representation choice the maintainer approves.",
    "The 'service' count follows ledgr_strategy_schedule_query, the call the pin's increment follows (re-review N4).")
add("R166", "target_or_authority", "The c half drops the counted() handler mock with the count (re-review N7): the mock attached an append_compiled_spot_batch method to every handler, a capability the compiled dispatch guard reads.")

# The maintainer's decisions of 2026-11-28 after the reviews: the lot kernels
# merge in Cut 28 (deletion-readiness addendum 1, Section 3 (b)).
set("R132", "handling", "d")
set("R132", "target_or_authority", paste(
  "Resolved by the switch (maintainer 2026-11-28: the lot kernels merge in Cut 28, deletion-readiness addendum 1, rule 8 and Section 3 (b)).",
  "fifo.R's kernel becomes the body of the package's ledgr_lot_opening/ledgr_lot_fill/ledgr_lot_disposition and ledgr_lot_apply, under the package names,",
  "so the block's direct calls of ledgr_lot_opening and its body<- mutants witness the fold's one kernel; amendment_test_inventory (7)'s seam into lean_lot_opening is no longer needed. The block is unchanged.",
  "Cut 28 gate: the merged kernel exists only after the merge."))

utils::write.csv(x, p, row.names = FALSE, fileEncoding = "UTF-8")
letters_n <- table(unlist(strsplit(x$handling, ",")))
cat("rows", nrow(x), "; letters:", paste(names(letters_n), letters_n, sep = " ", collapse = ", "), "\n")
