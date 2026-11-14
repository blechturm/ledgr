# Cut 18 (LDG-3234): the reviewed classification of every census statement
# (decision 3), written to evidence/cut18/statements.csv. A row covers a
# whole statement, or with `lines` ("from-to") the sites of a compound
# statement on those lines; the narrowest row containing a site applies.
#
#   Rscript dev/lean_core/parity/cut18_classify.R
#
# kind: invariant (owns a rule the loop must keep), contract (isolates a
# contracted behaviour: a refusal, a record, the context service, a stage
# interface), forwards (only repackages or recomputes data), package (a
# call into the pin), record (writes run-long state by index), local (binds
# or tests an existing value; allocates nothing a removal would save),
# debug (runs with debug on only). disposition: keep, remove, rewrite (a
# changed computation, kept only by the 0.02 rule), debug_move,
# out_of_scope (with routing).

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
ev <- file.path(here, "evidence", "cut18")
st <- utils::read.csv(file.path(ev, "census_statements.csv"), stringsAsFactors = FALSE)

rows <- list()
cl <- function(statement, cell, kind, owner, disp = "keep", routing = "-", lines = "") {
  rows[[length(rows) + 1L]] <<- data.frame(statement = statement, lines = lines, stage_cell = cell, kind = kind,
    owner_guarantee = owner, disposition = disp, routing = routing, stringsAsFactors = FALSE)
}
L <- function(fn, k) sprintf("loop.R|%s|%d", fn, k)
P <- function(fn, k) sprintf("plan.R|%s|%d", fn, k)

# Debug-only functions: one row per statement.
for (s in st$statement[st$debug_fn]) cl(s, "debug", "debug", "debug comparison with the pin (Cut 15 decision 2)")

# P1 valuation
for (k in 1:16) cl(L("lean_p1_value", k), "p1", "local", "binding")
cl(L("lean_p1_value", 2), "p1", "contract", "live$cur_ts: the error diagnostic row's timestamp (loop.R:1195)")
cl(L("lean_p1_value", 3), "p1", "contract", "live$cur_stage: the error diagnostic row's stage (loop.R:1196)")
cl(L("lean_p1_value", 5), "p1", "invariant", "valuation reads the pulse's close column")
cl(L("lean_p1_value", 7), "p1", "invariant", "positions value at the close (equity)")
for (k in 8:15) cl(L("lean_p1_value", k), "p1", "record", "equity row and run-long counters by index")
cl(L("lean_p1_value", 16), "p1", "contract", "P1's output to P2-P5 (macro point 1, stage interface)")
rows <- rows[!duplicated(vapply(rows, function(r) paste(r$statement, r$lines), ""), fromLast = TRUE)]

# P2 decide
for (k in 1:3) cl(L("lean_p2_decide", k), "p2_residual", "local", "binding of P1's output")
cl(L("lean_p2_decide", 4), "p2_residual", "invariant", "pos_start: the decision-time position for explicit decision rows")
cl(L("lean_p2_decide", 5), "p2_residual", "invariant", "positions snapshot: a decision-time copy the context keeps (fresh context)")
cl(L("lean_p2_decide", 6), "p2_residual", "contract", "named .positions in the pin's context")
for (k in 7:9) cl(L("lean_p2_decide", k), "p2_residual", "contract", "the availability view in the context and the risk plan (pin's view shape)")
cl(L("lean_p2_decide", 10), "debug", "debug", "debug packet and context comparison with the pin")
cl(L("lean_p2_decide", 11), "p2_context", "contract", "fresh pulse context (Cut 15 decision 3; lean_context)")
cl(L("lean_p2_decide", 12), "p2_residual", "contract", "per-pulse notes reset (sizing_skipped)")
cl(L("lean_p2_decide", 13), "p2_strategy", "contract", "strategy call, its error wrapping and stage label")
cl(L("lean_p2_decide", 14), "p2_residual", "contract", "harness coverage backstop: a stub outranks the callback's end")
for (k in 15:17) cl(L("lean_p2_decide", k), "p2_residual", "contract", "strategy result shape refusals (contracts: strategy outputs)")
cl(L("lean_p2_decide", 18), "p2_residual", "package", "intent reason validation (pin)")
for (k in 19:20) cl(L("lean_p2_decide", k), "p2_residual", "local", "binding of the strategy's return")
cl(L("lean_p2_decide", 21), "p2_residual", "contract", "target validation: plain fast path or the pin's validator (Cut 15 decision 2)")
cl(L("lean_p2_decide", 22), "debug", "debug", "debug comparison with the pin's target validator")
cl(L("lean_p2_decide", 23), "p2_residual", "invariant", "strategy quantities as plain doubles")
cl(L("lean_p2_decide", 24), "p2_residual", "local", "counter")
cl(L("lean_p2_decide", 25), "p2_residual", "record", "intent row header")
cl(L("lean_p2_decide", 26), "p2_sizing", "package", "sizing-evidence validation (pin, Cut 16 decision 2)")
cl(L("lean_p2_decide", 27), "debug", "debug", "debug: no sizing skip in slice 2")
cl(L("lean_p2_decide", 28), "p2_residual", "local", "binding")
cl(L("lean_p2_decide", 29), "p2_residual", "record", "sizing rows and the raw-sizing notice")
cl(L("lean_p2_decide", 30), "p2_residual", "record", "pre-decision row count")
cl(L("lean_p2_decide", 31), "p2_residual", "local", "binding")
cl(L("lean_p2_decide", 32), "p2_risk", "contract", "risk plan (pin), post-risk admissibility and the short-exposure refusal")
cl(L("lean_p2_decide", 32), "debug", "debug", "debug: availability target check and post-risk quantity recheck (LR-16)", lines = "641-641")
cl(L("lean_p2_decide", 32), "debug", "debug", "debug: post-risk quantity recheck (LR-16)", lines = "645-645")
cl(L("lean_p2_decide", 33), "p2_residual", "contract", "P2's output (stage interface)")

# The context and its read boundary
cl(L("lean_context", 1), "p2_context", "contract", "the pulse's feature accessor (fresh per pulse)")
cl(L("lean_context", 2), "p2_context", "contract", "the pin's lookup service, every entry name the pin's (debug comparison)")
for (k in 3:4) cl(L("lean_context", k), "p2_context", "contract", "lookup service counters (pin's entry names)")
cl(L("lean_context", 5), "p2_context", "contract", "flat()/hold() bound to this pulse's lookup (fresh context)")
for (k in 6:7) cl(L("lean_context", k), "p2_context", "contract", "the pin's context class and raw-field order")
cl(L("lean_context", 8), "p2_context", "local", "return")
for (k in 1:2) cl(L("feature_fn", k), "p2_context", "contract", "feature accessor closure (pin's projection accessor and filter)")
for (k in 1:2) cl(L("schedule_fn", k), "p2_context", "contract", "schedule query closure (pin's)")
for (k in 1:2) cl(L("lean_ctx_helpers", k), "p2_context", "contract", "flat()/hold() closures (pin's semantics)")
for (k in 1:2) cl(L("lean_strategy_view", k), "p2_context", "contract", "the state view (pin's class)")
for (k in 1:7) cl(L("lean_ctx_dollar", k), "p2_strategy", "contract", "context read boundary: the pin's values and refusals for every name (checklist row 4)")
for (k in 1:2) cl(L("check_uncovered", k), "p2_residual", "contract", "harness coverage backstop")
cl(L("lean_not_covered", 1), "p2_residual", "contract", "coverage refusal")

# P3 plan
for (k in 1:3) cl(L("lean_p3_plan", k), "p3_residual", "local", "binding of P1/P2 outputs")
cl(L("lean_p3_plan", 4), "p3_residual", "contract", "live$cur_stage for the error row")
cl(L("lean_p3_plan", 5), "p3_residual", "invariant", "actionable instruments (tolerance act_tol)")
cl(L("lean_p3_plan", 6), "p3_residual", "invariant", "the execution epoch of the pulse")
cl(L("lean_p3_plan", 7), "p3_residual", "local", "binding")
cl(L("lean_p3_plan", 8), "p3_residual", "invariant", "next execution bar")
cl(L("lean_p3_plan", 8), "p3_residual", "forwards",
   "execution_packet only carries exec_ts and the open column into lean_plan_pulse(), which reads those two fields",
   "remove", "pass exec_ts and the open column as arguments (lean_plan_pulse and its other caller lean_stage_plan)", lines = "668-669")
cl(L("lean_p3_plan", 8), "p3_residual", "contract", "the execution view seam (slice 4 restrictions; debug compares it with the provider)", lines = "670-670")
cl(L("lean_p3_plan", 8), "debug", "debug", "debug: execution view against the provider", lines = "671-676")
cl(L("lean_p3_plan", 8), "p3_plan", "contract", "the order plan (lean_plan_pulse)", lines = "677-680")
cl(L("lean_p3_plan", 8), "p3_plan", "forwards",
   "context_pos = seq_len(n) and member = rep(TRUE, n) rebuild run constants every pulse (ctx_pos and the fixed-basket membership)",
   "remove", "pass the run's ctx_pos and a run-long membership vector", lines = "677-678")
cl(L("lean_p3_plan", 8), "p3_residual", "contract", "affordability reconciliation stop (cut review R1)", lines = "681-694")
cl(L("lean_p3_plan", 9), "p3_residual", "contract", "P3's output (stage interface)")

# The planner (plan.R)
for (k in 1:45) cl(P("lean_plan_pulse", k), "p3_plan", "local", "binding")
for (k in c(3, 4, 5, 7)) cl(P("lean_plan_pulse", k), "p3_plan", "invariant", "plan quantities from targets and positions")
cl(P("lean_plan_pulse", 6), "p3_plan", "package", "order side (pin's ledgr_plan_side)")
cl(P("lean_plan_pulse", 9), "p3_plan", "forwards",
   "a closure built on every call only to assemble the plan list (and its debug check) at two return points",
   "remove", "one function defined once, outside lean_plan_pulse")
cl(P("lean_plan_pulse", 11), "p3_plan", "contract", "final-pulse requests rejected (final_pulse_no_execution)")
for (k in 12:13) cl(P("lean_plan_pulse", k), "p3_plan", "contract", "informational membership-change reason (slice 4 seam)")
for (k in 14:17) cl(P("lean_plan_pulse", k), "p3_plan", "invariant", "execution-bar and finite-delta screens")
cl(P("lean_plan_pulse", 18), "p3_plan", "package", "the pin's cost resolver and its output-shape refusal (Cut 16 decision 2)")
for (k in 19:24) cl(P("lean_plan_pulse", k), "p3_plan", "invariant", "resolved prices and fees; non-positive price rejection")
cl(P("lean_plan_pulse", 25), "p3_plan", "package", "fill cash and position effects (pin's publication formula)")
for (k in 26:31) cl(P("lean_plan_pulse", k), "p3_plan", "invariant", "short-exposure screen on the planned fills")
cl(P("lean_plan_pulse", 32), "p3_plan", "contract", "delta, epoch and short-exposure refusals in the pin's order")
cl(P("lean_plan_pulse", 33), "p3_plan", "invariant", "early rejections")
for (k in 34:37) cl(P("lean_plan_pulse", k), "p3_plan", "invariant", "affordability scan (sells that free cash first, radix ID order)")
cl(P("lean_plan_pulse", 38), "debug", "debug", "debug: affordability against the pin's scan")
for (k in 39:42) cl(P("lean_plan_pulse", k), "p3_plan", "invariant", "accepted and rejected candidates")
cl(P("lean_plan_pulse", 43), "p3_plan", "contract", "rejection and fill reason codes (the plan's reason segments)")
cl(P("lean_plan_pulse", 44), "p3_plan", "contract", "the plan's fill and rejection groups (P3 to P4 interface; debug validates the carrier)")
cl(P("lean_plan_pulse", 45), "p3_plan", "contract", "the plan (P3 to P4 interface)")
for (k in 1:2) cl(P("plan", k), "p3_plan", "contract", "the plan list and its debug carrier check")
cl(P("plan", 2), "p3_plan", "contract", "the plan list and its debug carrier check")
for (k in 1:7) cl(P("lean_plan_affordability", k), "p3_plan", "invariant", "affordability scan")
cl(P("lean_plan_empty_segments", 1), "p3_plan", "contract", "an empty reason segment set")
for (k in 1:3) cl(P("lean_plan_groups", k), "p3_plan", "contract", "fill and rejection groups gathered by index (P3 to P4 interface)")
for (k in 1:2) cl(P("lean_plan_id_rank", k), "p3_plan", "invariant", "radix rank of the run's IDs, computed once per axis")
for (k in 1:2) cl(P("lean_plan_segment_rows", k), "p3_plan", "contract", "reason segment rows")
for (k in 1:2) cl(P("lean_plan_segments", k), "p3_plan", "contract", "reason segments")
cl(L("lean_exec_view", 1), "p3_residual", "contract", "the fixed-basket execution view (slice 4 seam)")

# P4 apply
for (k in 1:3) cl(L("lean_p4_apply", k), "p4_residual", "local", "binding of P1/P2 outputs")
cl(L("lean_p4_apply", 4), "p4_residual", "invariant", "explicit decision rows (LR-23)")
for (k in 5:7) cl(L("lean_p4_apply", k), "p4_residual", "local", "counts and binding")
cl(L("lean_p4_apply", 8), "p4_residual", "record", "fill records by index into run-long columns")
cl(L("lean_p4_apply", 8), "p4_residual", "package",
   "decoding the fills' reason segments to text every pulse with fills; on a fixed basket the segments are empty",
   "rewrite", "decode only when a fill carries a reason code (predicate, comparator and fallback under Cut 15 decision 2)", lines = "712-712")
cl(L("lean_p4_apply", 8), "p4_residual", "invariant", "clean-fill certification (the pin's codec rule)", lines = "714-720")
cl(L("lean_p4_apply", 8), "p4_residual", "contract", "live$cur_stage for the error row", lines = "721-721")
cl(L("lean_p4_apply", 8), "p4_fifo", "invariant", "the one FIFO kernel (fifo.R; internals out of scope)", "keep",
   "FIFO internals: a later cut (compiled FIFO stays a WS14 decision)", lines = "722-723")
cl(L("lean_p4_apply", 8), "p4_facts", "package", "position facts (pin's ledgr_position_facts_apply)", lines = "724-728")
cl(L("lean_p4_apply", 8), "p4_residual", "invariant", "cash booked fill by fill (pin's cash scan)", lines = "761-761")
cl(L("lean_p4_apply", 9), "p4_residual", "record", "rejection records (rare: final pulse, cash, missing bars)")
for (k in 10:11) cl(L("lean_p4_apply", k), "p4_residual", "invariant", "explicit decision rows without clean fills (LR-23)")
cl(L("lean_p4_apply", 12), "p4_residual", "contract", "P4's output (fill count)")
for (k in 1:9) cl(L("lean_loop_add_decisions", k), "p4_residual", "record", "decision rows by index")
for (k in 1:12) cl(L("lean_loop_add_sizing", k), "p2_residual", "record", "sizing rows by index")
cl(L("grow", 1), "p4_residual", "record", "capacity doubling of a record")

# P5 commit
for (k in 1:3) cl(L("lean_p5_commit", k), "p5_residual", "local", "binding of P1/P2 outputs")
cl(L("lean_p5_commit", 4), "p5_residual", "contract", "live$cur_stage for the error row")
cl(L("lean_p5_commit", 5), "p5_residual", "contract", "event capacity refusal (D3-B)")
cl(L("lean_p5_commit", 6), "p5_residual", "record", "committed prefix (D3 Section 1)")
cl(L("lean_p5_commit", 7), "p5_residual", "contract", "recorded-cash reconciliation refusal")
for (k in 8:9) cl(L("lean_p5_commit", k), "p5_residual", "local", "binding")
cl(L("lean_p5_commit", 10), "p5_residual", "record", "the reconciliation record (marked gross exposures, cash)")
cl(L("lean_p5_commit", 10), "p5_residual", "forwards",
   "without a risk step the post-risk gross recomputes the strategy targets' gross already in the record",
   "remove", "reuse the strategy targets' gross", lines = "810-810")
cl(P("lean_plan_affordability", 2), "p3_plan", "invariant",
   "affordability priority: generators first, then the radix ID order (pin's scan)", "rewrite",
   "the same order without order(): walk a run-long radix permutation of the IDs (W4)")
cl(L("lean_p5_commit", 11), "p5_residual", "package", "the reconciliation record's finiteness refusal (pin)")
cl(L("lean_p5_commit", 12), "debug", "debug", "debug: gross exposure against the pin")
for (k in 13:14) cl(L("lean_p5_commit", k), "p5_residual", "record", "reconciliation record by index")
cl(L("lean_p5_commit", 15), "p5_state", "local", "binding")
cl(L("lean_p5_commit", 16), "p5_state", "contract", "declared-state reset, patch and replacement (pulse plumbing R3: acceptance at P5)")
cl(L("lean_p5_commit", 16), "debug", "debug", "debug: state patch against the pin", lines = "825-828")
cl(L("lean_p5_commit", 17), "p5_residual", "local", "return")
cl(L("lean_state_patch", 1), "p5_state", "contract", "unusual updates go to the pin's apply_values")
for (k in 2:3) cl(L("lean_state_patch", k), "p5_state", "contract", "patch names checked before the field validator (pin's acceptance order)")
for (k in 4:6) cl(L("lean_state_patch", k), "p5_state", "package",
   "each patched field through the pin's ledgr_strategy_state_validate_value", "out_of_scope",
   "the validator's own cost: WS14a or a focused package cut, by the maintainer")
for (k in 1:3) cl(L("lean_gross", k), "p5_residual", "invariant", "marked gross exposure (pin's rule, zero contributes 0)")

cl(L("lean_state_patch", 3), "p5_state", "contract",
   "patch names checked before the field validator (pin's acceptance order)", "rewrite",
   "accept a patch whose names are exactly the declared field names in order before the full check (W5)")

# E and the run loop
for (k in 1:3) cl(L("lean_e_advance", k), "e", "invariant", "pulse count and max_pulses prefix")
for (k in 1:10) cl(L("run_loop", k), "run_loop", "contract", "the pulse loop, its live flags, clocks and the terminal transfer (after the loop)")
cl(L("run_loop", 4), "run_loop", "contract", "the pulse loop: stages in order (macro point 1)")

out <- do.call(rbind, rows)
out <- out[!duplicated(paste(out$statement, out$lines), fromLast = TRUE), ]
missing <- setdiff(st$statement, out$statement)
if (length(missing)) stop("unclassified statements: ", paste(missing, collapse = ", "))
utils::write.csv(out[order(out$statement, out$lines), ], file.path(ev, "statements.csv"), row.names = FALSE)
cat(nrow(out), "classification rows for", length(unique(out$statement)), "statements\n")
print(table(out$kind, out$disposition))

# The inventory: every census site joined with its classification row.
source(file.path(here, "cut18_census.R"))
cs <- utils::read.csv(file.path(ev, "census.csv"), stringsAsFactors = FALSE, colClasses = "character")
inv <- cut18_inventory(cs, utils::read.csv(file.path(ev, "statements.csv"), stringsAsFactors = FALSE, colClasses = "character"))
utils::write.csv(inv, file.path(ev, "inventory.csv"), row.names = FALSE)
cat(nrow(inv), "inventory rows\n")
