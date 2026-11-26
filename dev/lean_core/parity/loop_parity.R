# Whole-run parity of the compact-state lean loop (LDG-3219, interface
# Section 19.6; obligations in loop_checklist.md). Each workload runs on the
# pinned build, then through lean_loop_run() (the harness entry: lean loop
# installed, entry and pre-pulse refusals on the pin, a marked attempt rerun
# on the pin). Every run-store table (diagnostics decoded), the public
# readers, the conditions and the sweep results are compared in A0 canonical
# form (dev/bench/v0_2_3_output_freeze/lib.R, doubles at %.17g).
#
# A workload passes when its tables are identical and, on its lean arm:
# no store access and no output-handler call while pulses ran, no hold
# expansion inside the loop, every completed terminal append within the
# batch bound (and one pulse per expanded range at bound one), and its
# registered refusal (loop_expect_refused) named.
#
#   Rscript dev/lean_core/parity/loop_parity.R --lib=<pinned library>
#     --debug=0|1 --out=<csv> [--workloads=<id,...>] [--batch-rows=<n>]
#     [--mutation=<name>] [--inert=1] [--freeze=<loop_freeze.csv>] [--dump=<dir>]
#     [--witness=<file>] [--workdir=<dir>]
#
# Cut 26 (LDG-3271): the runner resolves its path arguments, then works in a
# fresh directory outside any ledgr source package, so sweep workers load the
# pinned library; every worker either arm starts must report the pinned
# build as its ledgr origin, or the workload fails as WORKER. --workdir=<dir>
# runs from <dir> instead: the source-package control, which must fail.
#
# --witness sources one test-only file into the lean environment after
# loading (Cut 20: the hashed-frame witness's adapter, which runs the
# compiled envelope body in its hashed frame with debug assertions on).
#
# --freeze checks each lean arm's execution path (lean folds, refusals,
# backstop marks) against the 4a3e08b8 freeze for this mode (gate, batch1
# at --batch-rows=1, inert) and debug setting; a different path, or no
# frozen row for the workload (Cut 16 R4), fails the workload, and a full
# run (no --workloads) fails if a frozen workload is missing. A workload with
# a branch predicate (loop_reach, loop_workloads_slice2.R) fails as BRANCH
# when the pin's tables do not show the branch it is named for.
#
# --mutation loads loop.R or loop_harness.R with one registered variant
# (loop_mutations below; loop_edits.R applies it, the tracked code holds no
# variant branch) and inverts the verdict. A variant is CAUGHT on a
# workload only if its patch was reached (a marker inserted with every
# edit), its expected signal fired, every condition message new against the
# pinned arm matches the variant's `error` pattern (none allowed by
# default), and, for a `tables` pattern, a matching table differs.
# Otherwise it is UNREACHED, UNRELATED (a new error the variant does not
# intend), MISSED or NOT RUN, and the run exits with status 1. PASS* marks
# a workload whose public call stopped before any fold ran.

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) return(default %||% stop("--", name, "= is required", call. = FALSE))
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
`%||%` <- function(a, b) if (is.null(a)) b else a
lib <- arg("lib")
debug <- identical(arg("debug", "0"), "1")
out <- arg("out")
batch_rows <- as.integer(arg("batch-rows", "65536"))
mutation <- arg("mutation", "")
inert <- identical(arg("inert", "0"), "1")   # bind the fold without the harness hooks (row 15)
freeze_file <- arg("freeze", "")
dump_dir <- arg("dump", "")                  # saves each workload's pin tables (slice2_reach_cross.R)
dump_lean <- identical(arg("dump-lean", "0"), "1")   # slice 4: also the lean arm, as <id>_lean.rds
witness_file <- arg("witness", "")           # Cut 20: a test-only file sourced into the lean environment (hashed_frame_witness.R)
workdir_control <- arg("workdir", "")          # Cut 26: run from this directory (the source-package control)
# Cut 26 (LDG-3271): path arguments are resolved before the working directory changes.
resolve <- function(path) if (nzchar(path)) normalizePath(path, winslash = "/", mustWork = FALSE) else path
lib <- resolve(lib)
out <- resolve(out)
freeze_file <- resolve(freeze_file)
dump_dir <- resolve(dump_dir)
witness_file <- resolve(witness_file)
workdir_control <- resolve(workdir_control)
source(file.path(here, "loop_edits.R"))

# Variants. `expect` names the signal that must fire; `error` is a pattern
# every new condition message must match (NULL: none may appear); `lost` a
# pattern one of the pin's messages missing from the lean arm must match
# (a pin refusal the variant removes); `tables` a pattern one differing
# table must match ("^$": no table may differ); `path` a pattern the
# detector record (store and sink calls while pulses ran) must match, so a
# detector variant is caught on its own path. Each variant names its
# intended fault through these.
edit <- lean_edit
variant <- function(expect, edits, error = NULL, lost = NULL, tables = NULL, path = NULL) {
  list(expect = expect, edits = edits, error = error, lost = lost, tables = tables, path = path)
}
# One store path per variant, its scratch store prepared before the pulses
# run (unmarked), the marker inside the branch that runs the fault, and the
# backend call that path must reach.
store_variant <- function(call, path, prepare = FALSE, dead = NULL) variant("store", list(
  edit("loop.R", "lean_fold_envelope_plain", "  live$batches <- 0L", c(   # Cut 20 re-anchor (rename)
    "  scratch <- DBI::dbConnect(duckdb::duckdb())",
    "  DBI::dbExecute(scratch, \"CREATE TABLE probe (value INTEGER)\")",
    if (prepare) "  stmt <- DBI::dbSendStatement(scratch, \"INSERT INTO probe VALUES (?)\")"), "after", mark = FALSE),
  edit("loop.R", "lean_p4_apply", "      last_executed <<- max(last_executed, fill$exec_ts, na.rm = TRUE)",
    paste0("      if (nf == n_fill) { lean_entry$variant_reached <- TRUE; ", if (!is.null(dead)) paste0("if (FALSE) ", dead, "; "),
           call, " }"), "after", mark = FALSE)), tables = "^$", path = path)
loop_mutations <- list(
  fill_price_ulp = variant("differ", list(edit("loop.R", "lean_loop_publish", "    ca <- lean_facts_rows(s4)   # accepted corporate-action rows (slice 4)",   # Cut 21 re-anchor
    "    if (nf > 0L) fl$price[[1L]] <<- fl$price[[1L]] * (1 + .Machine$double.eps)", "after")),
    error = "FILL cash and position deltas do not reconcile"),
  drop_hold = variant("differ", list(edit("loop.R", "lean_loop_expand", "      hc <- which(hold)",
    "      if (a == 1L && any(hold)) hold[which(hold)[[1L]]] <- FALSE", "before")),
    error = "Diagnostic codec coverage is corrupt"),
  hold_position = variant("differ", list(edit("loop.R", "lean_loop_expand",   # Cut 21 re-anchor
    "      hpos <- lean_facts_positions_at(ev, rk, hp, a, b, carry)",
    "      if (a == 1L && length(hpos)) hpos[[1L]] <- hpos[[1L]] + 1", "after")),
    tables = "^run_diagnostic_implicit$"),
  write_in_loop = variant("sink", list(edit("loop.R", "lean_p4_apply",
    "      last_executed <<- max(last_executed, fill$exec_ts, na.rm = TRUE)",
    c("      if (nf == n_fill) output_handler$write_fill_events(fill = fill, i = seq_len(n_fill),",
      "        instrument_id = ids[fill$pos], event_seq = event_seq - n_fill, use_transaction = FALSE)"), "after")),
    error = "event_seq values must be integral and strictly increasing", path = "write_fill_events"),
  store_execute = store_variant("DBI::dbExecute(scratch, \"INSERT INTO probe VALUES (1)\")", "rapi_execute"),
  store_bind = store_variant("DBI::dbBind(stmt, list(7L))", "rapi_bind", prepare = TRUE),
  store_query = store_variant("DBI::dbGetQuery(scratch, \"INSERT INTO probe VALUES (2) RETURNING value\")", "rapi_execute"),
  store_append = store_variant("ledgr_store_append(scratch, \"probe\", data.frame(value = 1L))", "ledgr::ledgr_store_append"),
  hold_in_loop = variant("hold", list(edit("loop.R", "lean_p5_commit", "    hd_has_recon[[i]] <<- TRUE",
    "    if (i == 1L) lean_loop_expand(1L, 1L, lean_loop_layout(), state0$positions)", "after")), tables = "^$"),
  batch_fault = variant("rollback", list(edit("loop.R", "tick", "      live$batches <- live$batches + 1L",
    "      if (\"ledger_events\" %in% lean_entry$terminal_appends) stop(\"lean witness: batch fault\")", "after")),
    error = "lean witness: batch fault"),
  fault_before_append = variant("fault_without_append", list(edit("loop.R", "tick",
    "      live$batches <- live$batches + 1L", "      stop(\"lean witness: early batch fault\")", "after")),
    error = "lean witness: early batch fault"),
  patch_container = variant("differ", list(edit("checks.R", "lean_state_apply",   # Cut 18 R5 re-anchor
    "  if (!is.list(update) || is.data.frame(update)) {", "  if (FALSE) {")),
    lost = "Strategy state update must be a uniquely named list"),
  zero_pulse_completion = variant("differ", list(edit("loop.R", "lean_loop_publish", "    if (n_pulse == 0L) {", "    if (FALSE) {")),
    tables = "^zero_pulses_aligned$"),
  read_fast_path = variant("differ", list(edit("loop.R", "lean_ctx_dollar",
    "  if (!is.character(name) || length(name) != 1L || is.na(name) || !nzchar(name)) return(lean_pin_ctx_dollar(x, name))",
    "  if (identical(name, \"\")) return(lean_pin_ctx_dollar(x, name))")),
    error = "Lean context field .* differs from the pin's"),
  entry_guard_off = variant("unrefused", list(edit("loop.R", "lean_loop_coverage", "  if (!is.null(entry)) lean_not_covered(entry)")),
    tables = "^$"),
  backstop_off = variant("differ", list(edit("loop_harness.R", "lean_loop_run",
    "  if (length(lean_entry$backstop) > 0L) {", "  if (FALSE) {")),
    error = "The lean loop does not cover .* [(]slice 1[)]"),
  capacity_late = variant("differ", list(edit("loop.R", "lean_p5_commit", "    if (nf > capacity) {", "    if (FALSE) {")),
    lost = "exceeded the run's maximum event capacity"),
  commit_late = variant("differ", list(
    edit("loop.R", "lean_p5_commit", "    n_committed <<- nf                # the pin flushes the pulse's fills here, before reconciliation"),
    edit("loop.R", "lean_p5_commit", "    invisible(NULL)", "    n_committed <<- nf", "before")),
    tables = "^prefix_reads$"),
  expand_whole = variant("unbounded", list(edit("loop.R", "lean_loop_publish",
    "      b <- max(a, findInterval(cs[[a]] - lay$rows[[a]] + bound, cs))", "      b <- lay$np")), tables = "^$"),
  # Round 4, finding 4: a whole-run expansion beside the bounded transfer.
  expand_extra = variant("unbounded", list(edit("loop.R", "lean_loop_publish", "    lay <- lean_loop_layout()",
    "    whole_run_temporary <- lean_loop_expand(1L, lay$np, lay, state0$positions)", "after")), tables = "^$"),
  # Round 4, finding 1: the rerun without the entry RNG restored.
  rng_restore_off = variant("differ", list(edit("loop_harness.R", "lean_loop_run", "    ledgr_rng_restore(rng)")),
    tables = "^rng_(entry|after)$|^sweep$"),
  # Round 4, finding 2: first-pulse state alignment on an empty execution.
  zero_pulse_align = variant("differ", list(edit("loop.R", "lean_fold_envelope_plain",   # Cut 20 re-anchor (rename)
    "  if (n_pulse > 0L && !identical(ids, state_axis)) {", "  if (!identical(ids, state_axis)) {")),
    tables = "^zero_pulses_reordered$"),
  # Cut 15 R2: the strategy error wrapped before the callback unwinds, and
  # the original condition lost as parent.
  early_wrap = variant("differ", list(edit("loop.R", "lean_p2_decide", "    result <- tryCatch({",
    "    result <- withCallingHandlers({")), error = "cleanup failure|Strategy error", tables = "^error_boundary$"),
  lost_parent = variant("differ", list(edit("loop.R", "lean_p2_decide", "      ledgr_abort_strategy_error(e, ctx)",
    "      ledgr_abort_strategy_error(simpleError(conditionMessage(e)), ctx)")), error = "Strategy error at",
    tables = "^error_boundary$"),
  # Cut 15 R3: a pulse lookup cache shared across pulses, and a retained
  # context whose positions follow later writes.
  reused_lookup = variant("differ", list(edit("loop.R", "lean_context",
    "      cache = new.env(parent = emptyenv())), parent = emptyenv())",
    paste("      cache = {lean_entry$variant_reached <- TRUE; lean_entry$shared_cache %||%",
          "(lean_entry$shared_cache <- new.env(parent = emptyenv()))}), parent = emptyenv())"), mark = FALSE)),
    error = "Lean context .* differs from the pin's", tables = "^run_diagnostic"),
  live_positions = variant("differ", list(edit("loop.R", "lean_context", "    lookup$preparation_counts <- counts$prep",
    c("    rm(\"positions\", envir = lookup)",
      "    makeActiveBinding(\"positions\", function() { p <- pos; names(p) <- ids; p }, lookup)"), "after")),
    tables = "^run_diagnostic"),
  # Cut 15 decision 2: the shared state view, wrong.
  state_view_fast = variant("differ", list(edit("loop.R", "lean_strategy_view",
    "    class(view) <- c(\"ledgr_strategy_state_view\", \"list\")", "    class(view) <- \"ledgr_strategy_state_view\"")),
    error = "Lean state view differs from the pin's"),
  # Cut 16, LDG-3226: the risk plan skipped, the implicit-row rule without
  # LR-23's post-risk equality, and the planner ignoring the resolved price
  # or the resolved fee.
  # Cut 18 R1 re-anchor: the lean risk steps not applied (post-risk targets
  # equal the strategy targets); with debug on the per-pulse comparison with
  # the pin reports it.
  risk_not_applied = variant("differ", list(edit("checks.R", "lean_risk_apply", "  for (s in steps) {", "  for (s in list()) {")),
    tables = "^fills$|^ledger_events$|^run_diagnostic", error = "Lean risk plan differs from the pin's"),
  implicit_row_old_rule = variant("differ", list(edit("loop.R", "lean_p4_apply",   # Cut 19, Cut 21 re-anchors
    "    differs <- if (isTRUE(v2$skip)) integer() else which(!(is.finite(sq) & sq == pc & tq == sq & cleanc))",
    "    differs <- if (isTRUE(v2$skip)) integer() else which(!(is.finite(sq) & sq == pc & cleanc))")),
    error = "Diagnostic codec coverage is corrupt", tables = "^run_diagnostic"),
  # Cut 18 R2: the resolver's output-shape check runs in debug only; a lean
  # cost column of the wrong length must raise its original refusal there.
  cost_columns_short = variant("differ", list(edit("checks.R", "lean_cost_resolve",
    "  list(price = round(price, digits = cost$digits), fee = fee)", "  list(price = round(price, digits = cost$digits), fee = fee[-1L])")),
    error = "The cost resolver must return one price and one fee per fill"),
  targets_wrong_refusal = variant("differ", list(edit("checks.R", "lean_targets",
    "  if (ids_ok && is.numeric(raw) && identical(attributes(raw), ids_attr) && all(is.finite(raw))) return(raw)",
    "  rlang::abort(\"wrong target refusal\", class = \"ledgr_invalid_strategy_result\")")),
    error = "Lean target validation differs from the pin's"),
  resolved_price_ignored = variant("differ", list(edit("plan.R", "lean_plan_pulse",
    "  price[passed] <- resolved$price", "  price[passed] <- open[passed]")),
    tables = "^fills$|^ledger_events$"),
  resolved_fees_ignored = variant("differ", list(edit("plan.R", "lean_plan_pulse",
    "  fee[passed] <- resolved$fee", "  fee[passed] <- 0 * resolved$fee")),
    tables = "^fills$|^ledger_events$"),
  # Cut 16, LDG-3227: sizing rows after the decision segment, the intent
  # reason dropped from them, the raw notice written on an evidenced pulse,
  # and a recorded sizing skip reaching the debug check. A misplaced or extra
  # row collides with another row's diagnostic sequence, and the store
  # aborts the run's transaction.
  sizing_rows_after_decisions = variant("differ", list(edit("loop.R", "lean_loop_expand",
    "      add(lay$pre0[sp] + as.integer(!is.na(hd_intent[sp])) + within, sp, list(instrument_id = szr$id[sr],",   # Cut 19 re-anchor
    "      add(lay$dec0[sp] + n + within, sp, list(instrument_id = szr$id[sr],")),
    error = "Current transaction is aborted", tables = "^run_diagnostic"),
  sizing_intent_dropped = variant("differ", list(edit("loop.R", "lean_loop_add_sizing",
    "    szr$reasons[rows] <<- if (is.null(intent)) \"\" else intent", "    szr$reasons[rows] <<- \"\"")),
    tables = "^run_diagnostics$"),
  raw_notice_with_evidence = variant("differ", list(edit("loop.R", "lean_p2_decide",
    "      lean_loop_add_sizing(sizing_evidence, intent_reason, i, m)",
    c("      if (!isTRUE(pulse_notes$raw_sizing_notice_written)) {",
      "        hd_sizing[[i]] <<- TRUE; pre <- pre + 1L; pulse_notes$raw_sizing_notice_written <- TRUE",
      "      }"), "before")),
    error = "Current transaction is aborted", tables = "^run_diagnostic"),
  sizing_skip_recorded = variant("differ", list(edit("loop.R", "lean_p2_decide",
    "    if (.lean_debug && is.null(marks) && length(pulse_notes$sizing_skipped) > 0L) {",   # Cut 19 re-anchor
    "    pulse_notes$sizing_skipped <- ids[[1L]]", "before")),
    error = "Lean sizing skipped an instrument"),
  # Cut 19, LDG-3238: marks, the valuation and risk-mark stops, stale-mark
  # risk rows, the clean-row rule, row reasons and order, the valuation
  # state's origin, mark metadata, affected exposure and record growth.
  marks_from_close = variant("differ", list(edit("loop.R", "lean_p1_value", "      mk <- m$columns$mark",
    "      mk <- close")), error = ".", tables = "."),
  frozen_restriction_dropped = variant("differ", list(edit("marks.R", "lean_marks_pulse",
    "  view <- ledgr_availability_restrict_frozen(view, valuation)")), lost = "Restricted targets must hold", error = "."),
  valuation_stop_counts_pulse = variant("differ", list(edit("loop.R", "lean_p1_value",
    "        stop_reason <<- st$reason", "        processed <<- processed + 1L", "before")),   # Cut 21 re-anchor
    tables = "^run_telemetry$|^runs$|^run_completion$"),
  stop_affected_unspecified = variant("differ", list(edit("marks.R", "lean_marks_stop", "  s3$affected <- s$affected")),
    tables = "^run_completion$"),
  stale_risk_rows_dropped = variant("differ", list(edit("loop.R", "lean_p2_decide", "        lean_marks_add_rows(s3, i, 2L, sr)")),
    tables = "^run_diagnostic", error = "."),
  clean_rule_ignores_marks = variant("differ", list(edit("marks.R", "lean_marks_clean",
    "  x <- d$source == \"current_close\" & !is.na(d$age) & d$age == 0L & is.finite(d$mark) &",
    "  x <- is.finite(d$mark) &")), tables = "^run_diagnostic", error = "."),
  reasons_not_defaulted = variant("differ", list(edit("marks.R", "lean_marks_group",
    "  c(list(instrument_id = ids, stage = stage, outcome = outcome, reason_code = reason_code, reasons = reasons), list(...))",
    "  c(list(instrument_id = ids, stage = stage, outcome = outcome, reason_code = reason_code, reasons = if (missing(reasons)) \"\" else reasons), list(...))")),
    tables = "^run_diagnostics$"),
  # Cut 21, LDG-3243 (cut review R1): the carried frozen set ignored, so the
  # window's first pulse records freeze entry a second time.
  frozen_opening_ignored = variant("differ", list(edit("marks.R", "lean_marks_run_state", "  s3$frozen <- frozen",
    "  s3$frozen <- character()")), tables = "^run_diagnostic"),
  # Cut 21, LDG-3244 (decision 11; cut review R3, R4, R6, R8): the plan's
  # post call omitted, and its cash not installed: with debug on the
  # settlement check names the fault at that pulse; with debug off the
  # economic tables differ.
  post_omitted = variant("differ", list(edit("loop.R", "lean_p1_value",
    "      posted <- lean_facts_post(s4, i, run_id, event_seq, cash, pos, book, ids, close)",
    "      posted <- list(state = list(cash = cash, positions = stats::setNames(pos, ids), lot_state = book), next_event_seq = event_seq)")),
    error = "Lean corporate-action settlement ran 0 post calls", tables = "^ledger_events$"),
  post_cash_not_installed = variant("differ", list(edit("loop.R", "lean_p1_value", "      lean_settle(posted$state, i)",
    "      lean_settle(utils::modifyList(posted$state, list(cash = cash)), i)")),
    error = "Lean corporate-action settlement was not installed", tables = "^equity_curve$"),
  # Captured rows lost or repeated after a correct installation: the event
  # tables, not the settlement check, catch them. The duplicate is the
  # captured tail after the last fill, written twice.
  captured_row_dropped = variant("differ", list(edit("facts.R", "lean_facts_accept", "  blocks[[s4$nb]] <- rows",
    "  blocks[[s4$nb]] <- rows[-1L, , drop = FALSE]")), tables = "^ledger_events$"),
  captured_row_duplicated = variant("differ", list(edit("loop.R", "lean_loop_publish",
    "    lean_facts_emit_ca(output_handler, ca, cur, .Machine$integer.max, bound, tick)   # rows after the last fill",
    "    if (!is.null(ca)) lean_facts_emit_ca(output_handler, ca, nrow(ca), .Machine$integer.max, bound, tick)", "after")),
    error = "strictly increasing", tables = "^ledger_events$"),
  # Publication order: captured rows after every fill, and fills numbered
  # as if no captured row came between them.
  corporate_rows_after_fills = variant("differ", list(edit("facts.R", "lean_facts_emit",
    "    cur <- lean_facts_emit_ca(h, ca, cur, ev[[r[[1L]]]], bound, tick)")),
    error = "strictly increasing", tables = "^ledger_events$"),
  fill_seq_contiguous = variant("differ", list(edit("loop.R", "lean_p4_apply",
    "      fl$evseq[rows] <<- event_seq + seq_len(n_fill) - 1L",
    "      fl$evseq[rows] <<- as.integer(execution$event_seq_start) + rows - 1L")),
    error = ".", tables = "^ledger_events$"),
  # The capture's acceptance check skipped: the pin's P1 refusal of an
  # overflowing cash delta is lost and a later failure takes its place.
  capture_validation_deferred = variant("differ", list(edit("facts.R", "lean_facts_accept",
    "  p <- ledgr_validate_accounting_append(rows, prior_event_seq = s4$bseq, prior_ts_utc = s4$bts)",
    "  p <- list(event_seq = rows$event_seq, ts_utc = rows$ts_utc)")),
    error = ".", tables = "^run_conditions$"),
  # Accepted corporate-action rows kept out of the committed prefix.
  nonfill_commit_late = variant("differ", list(
    edit("loop.R", "lean_fold_envelope_plain", "    count = function() NROW(pre_events) + retains * s4$nrows + n_committed,",
      "    count = function() NROW(pre_events) + n_committed,", mark = FALSE),   # inside list(): the next edit marks the reach
    edit("loop.R", "lean_fold_envelope_plain", "      ca <- lean_facts_rows(s4)", "      ca <- NULL")),
    tables = "^prefix_reads$"),
  # The capture's growth loses the blocks already held.
  capture_lost_at_growth = variant("differ", list(edit("facts.R", "lean_facts_accept", "    length(blocks) <- s4$cap",
    "    blocks <- vector(\"list\", s4$cap)")), error = ".", tables = "^ledger_events$"),
  # A captured block written whole, past the terminal batch bound.
  nonfill_block_unsplit = variant("unbounded", list(edit("facts.R", "lean_facts_emit_ca",
    "    e <- min(last, cur + bound - 1L)", "    e <- last")), tables = "^$"),
  # Close review round 1, F1: the retaining handler's room not checked at
  # the capture or the fill commit; the pin's capacity refusal is lost.
  capacity_check_dropped = variant("differ", list(edit("facts.R", "lean_facts_capacity",
    "  if (s4$retains && s4$nrows + incoming > 0L) {", "  if (FALSE) {")), error = ".", tables = "^sweep|^prefix_reads$"),
  # Cut 21, LDG-3246 (decision 11; cut review R5, R8): the context axis. The
  # constant execution view on a facts run; decision rows numbered by run
  # position, not context ordinal; decision_order on the run axis; the
  # strategy state not aligned to a changed context; the empty axis's
  # decision row dropped; P3 on run-axis positions (cells outside the
  # context actionable); a context record lost at growth.
  execution_view_fixed = variant("differ", list(edit("loop.R", "lean_p3_plan",
    "        lean_plan_execution_view(provider, exec_ts, ids[ctx_pos[actionable]])",
    "      if (!is.na(exec_ts)) view <- lean_exec_view(length(actionable))", "after")),
    error = ".", tables = "^run_diagnostic|^fills$|^ledger_events$"),
  decision_on_run_axis = variant("differ", list(edit("loop.R", "lean_loop_expand",
    "      add(lay$dec0[dp] + dk, dp, list(instrument_id = ids[lean_facts_rpos(s4, dk, dp)], stage = \"decision\", outcome = \"recorded\",",
    "      add(lay$dec0[dp] + lean_facts_rpos(s4, dk, dp), dp, list(instrument_id = ids[lean_facts_rpos(s4, dk, dp)], stage = \"decision\", outcome = \"recorded\",")),
    error = ".", tables = "^run_diagnostic"),
  decision_order_run_axis = variant("differ", list(edit("loop.R", "lean_loop_expand",
    "        decision_order = as.numeric((kk - 1) * n + rq),   # (ordinal - 1) x axis size + run position (R/fold-engine.R:1330)",
    "        decision_order = as.numeric((kk - 1) * n + kk + 0 * {lean_entry$variant_reached <- TRUE; 0}),", mark = FALSE)),
    error = "decision-order evidence is corrupt", tables = "^run_diagnostic"),
  state_not_aligned = variant("differ", list(edit("loop.R", "lean_p1_value",
    "      if (!identical(m$cids, s4$axis)) strategy_state <<- lean_facts_align(s4, strategy_state, state_declaration,",
    "      if (FALSE) strategy_state <<- lean_facts_align(s4, strategy_state, state_declaration,")), error = ".", tables = "."),
  empty_domain_row_dropped = variant("differ", list(edit("loop.R", "lean_p2_decide",
    "    if (n == 0L) lean_marks_add_rows(s3, i, 2L, lean_marks_group(\"\", \"decision\", \"recorded\", \"empty_public_domain\"))")),
    error = ".", tables = "^run_diagnostic"),
  outside_context_actionable = variant("differ", list(edit("loop.R", "lean_p3_plan",
    "      batch <- lean_plan_pulse(context_pos = ctx_pos, target_qty = tq, position = pos,",
    "      batch <- lean_plan_pulse(context_pos = seq_along(tq), target_qty = tq, position = pos,")),
    error = ".", tables = "^fills$|^ledger_events$"),
  context_lost_at_growth = variant("differ", list(edit("facts.R", "lean_facts_context",
    "  while (s4$ncx + m > length(cx)) length(cx) <- 2L * length(cx)",
    paste("  while (s4$ncx + m > length(cx)) { length(cx) <- 2L * length(cx); lean_entry$variant_reached <- TRUE;",
          "if (s4$ncx > 0L) cx[[s4$ncx]] <- NA_integer_ }"), mark = FALSE)),
    error = ".", tables = "^run_diagnostic"),
  # Cut 21, LDG-3247 (decision 11; cut review R2, R7, R8): dispositions and
  # terminal stops. The plan's scheduled dispositions skipped; a terminal
  # stop counting its pulse; the lifetime path run after a blocked scheduled
  # disposition; the disposable part of a blocked lifetime group posted; the
  # next entitlement boundary bound after the fills; P1 position changes
  # left out of the implicit records' history; a transition record lost at
  # growth.
  disposition_skipped = variant("differ", list(edit("facts.R", "lean_facts_dispose",
    "  if (!is.null(plan) && isTRUE(plan$has_disposition())) {", "  if (FALSE) {")), error = ".", tables = "^ledger_events$"),
  terminal_stop_counts_pulse = variant("differ", list(edit("loop.R", "lean_p1_value", "        stop_reason <<- st$reason",
    "        if (startsWith(st$reason, \"terminal\")) processed <<- processed + 1L", "after")),
    tables = "^run_telemetry$|^runs$|^run_completion$"),
  lifetime_after_blocked_scheduled = variant("differ", list(edit("facts.R", "lean_facts_dispose",
    "    if (!is.null(d$stopped)) return(stop(d$stopped$ids, d$stopped$reason_code, d$stopped$reasons))")),
    error = ".", tables = "^ledger_events$"),
  blocked_group_partial_disposal = variant("differ", list(edit("facts.R", "lean_facts_dispose",
    "    blocked <- r$outcome != \"dispose\"", c("    if (any(blocked) && any(!blocked)) {",
      "      keep <- !blocked; inactive <- inactive[keep]; labels <- labels[keep]",
      "      r <- lapply(r, function(v) if (length(v) == length(keep)) v[keep] else v); blocked <- blocked[keep]", "    }"),
    "after")), error = ".", tables = "^ledger_events$"),
  entitlement_bound_after_fills = variant("differ", list(
    edit("loop.R", "lean_p4_apply",
      "    if (!is.null(s4$plan) && i < n_pulse) s4$plan$bind_boundary(i + 1L, ledgr_fold_positions_snapshot(pos, ids))"),
    edit("loop.R", "lean_p4_apply", "    explicit_k <- if (length(clean_k)) differs[match(differs, clean_k, 0L) == 0L] else differs",
      "    if (!is.null(s4$plan) && i < n_pulse) s4$plan$bind_boundary(i + 1L, ledgr_fold_positions_snapshot(pos, ids))",
      "before", mark = FALSE)), error = ".", tables = "^ledger_events$"),
  nonfill_position_history_ignored = variant("differ", list(edit("loop.R", "lean_settle",
    "    lean_facts_moved(s4, i, pos, fs$positions)")), error = ".", tables = "^run_diagnostic"),
  moves_lost_at_growth = variant("differ", list(edit("facts.R", "lean_facts_moved",
    "  while (s4$nmv + length(k) > length(mv$pulse)) mv <- lapply(mv, function(v) { length(v) <- 2L * length(v); v })",
    c("  while (s4$nmv + length(k) > length(mv$pulse)) {",
      "    mv <- lapply(mv, function(v) { length(v) <- 2L * length(v); v })",
      "    lean_entry$variant_reached <- TRUE; mv$net[[s4$nmv]] <- NA_real_", "  }"), mark = FALSE)),
    error = ".", tables = "^run_diagnostic"),
  # Workstream 40 close review round 1, F1: a run with lifetime facts and no
  # corporate-action plan treated as one that cannot capture, so its fills
  # leave the capture's boundary and the retaining handler's population; and
  # the handler state read through init_buffers(), which a witness seam wraps.
  # Round 2 (F3) re-anchors that one to the public-surface route: retaining
  # decided by the state found in init_buffers()'s closure; adds the same
  # read through append_event_rows() (the reviewer's wrapped append), and
  # a room without the handler's entry events.
  lifetime_capture_population_dropped = variant("differ", list(edit("facts.R", "lean_facts_run_state",
    "  s4$captures <- !is.null(s4$plan) || \"lifetime\" %in% s4$provider$identity()$declared_families",
    "  s4$captures <- !is.null(s4$plan)")), error = ".", tables = "^sweep|^prefix_reads$"),
  handler_state_via_init = variant("differ", list(edit("facts.R", "lean_facts_run_state",
    "  s4$retains <- is.function(handler$events)",
    "  s4$retains <- is.function(handler$events) && is.environment(get0(\"state\", envir = environment(handler$init_buffers), inherits = FALSE))")),
    error = ".", tables = "^sweep|^prefix_reads$"),
  retains_via_append_closure = variant("differ", list(edit("facts.R", "lean_facts_run_state",
    "  s4$retains <- is.function(handler$events)",
    "  s4$retains <- is.function(handler$events) && is.environment(get0(\"state\", envir = environment(handler$append_event_rows), inherits = FALSE))")),
    error = ".", tables = "^sweep|^prefix_reads$"),
  room_without_entry = variant("differ", list(edit("facts.R", "lean_facts_run_state",
    "  s4$hmax <- s4$entry + as.integer(lean_hooks$capacity(max_events))",
    "  s4$hmax <- as.integer(lean_hooks$capacity(max_events))")),
    error = ".", tables = "^sweep|^prefix_reads$"),
  # the valuation state given scoring ordinals instead of prepared columns
  wrong_origin = variant("differ", list(edit("marks.R", "lean_marks_state",
    "  ledgr_availability_valuation_state(bars, ids, substrate$axis, as.integer(provider$valuation_policy$max_sessions),",
    "  history_reader$pulse_columns <- seq_along(history_reader$pulse_columns)", "before")),
    error = ".", tables = "."),
  mark_metadata = variant("differ", list(edit("marks.R", "lean_marks_decision_fields",
    "  list(mark = m$columns$mark, source = m$p2$mark_source, age = m$columns$mark_age, reason = reason, reasons = reasons)",
    "  list(mark = m$columns$mark, source = m$p2$mark_source, age = m$columns$mark_age + 1L, reason = reason, reasons = reasons)")),
    tables = "^run_diagnostics$", error = "."),
  transition_groups_interleaved = variant("differ", list(edit("marks.R", "lean_marks_frozen",
    "  list(set = now, groups = groups)", "  list(set = now, groups = rev(groups))")), tables = "^run_diagnostics$"),
  affected_contribution_dropped = variant("differ", list(edit("marks.R", "lean_marks_valuation_stop",
    "  list(reason = reason_code, affected = c(affected, list(ts_utc = ts_posix, specified = TRUE)),",   # Cut 21 re-anchor
    "  list(reason = reason_code, affected = c(ledgr_availability_affected_exposure(ids[-1L], m$full, v), list(ts_utc = ts_posix, specified = TRUE)),")),
    tables = "^run_completion$"),
  # The growth copy loses the last record already written (close review
  # round 1, F1): it takes the padding's NA in every column.
  record_lost_at_growth = variant("differ", list(edit("marks.R", "lean_marks_add_rows",
    "    xr <- lapply(xr, function(v) { length(v) <- s3$xcap; v })",
    "    xr <- lapply(xr, function(v) { v[[s3$nx]] <- v[[length(v)]]; v })", "after")),
    tables = "^run_diagnostic", error = "."),
  # Cut 19, LDG-3239: the strategy called on a pulse the schedule skips, and
  # the skip pulse's evidence rows dropped.
  skip_calls_strategy = variant("differ", list(edit("loop.R", "lean_p2_decide",
    "    if (!is.null(s3$due) && !isTRUE(s3$due[[i]])) {", "    if (FALSE) {")), tables = "^run_diagnostic", error = "."),
  skip_evidence_dropped = variant("differ", list(edit("marks.R", "lean_marks_skip_rows", "  if (length(ev) > 0L) {",
    "  if (FALSE) {")), tables = "^run_diagnostic", error = "."),
  # Round 4, finding 3: a sweep with workers not refused at entry.
  # Negative controls (loop_variants.R): each must NOT be caught.
  control_unrelated = variant("differ", list(edit("loop.R", "lean_p4_apply",
    "      last_executed <<- max(last_executed, fill$exec_ts, na.rm = TRUE)",
    "      stop(\"control: an unrelated error\")", "after"))),
  # declares the dbBind path, but its bind is dead code and dbExecute writes
  control_wrong_store_path = store_variant("DBI::dbExecute(scratch, \"INSERT INTO probe VALUES (3)\")", "rapi_bind",
    prepare = TRUE, dead = "DBI::dbBind(stmt, list(7L))"),
  control_unreached = variant("differ", list(edit("loop.R", "lean_loop_debug_packet",
    "  full <- stats::setNames(pos, ids)", "  stop(\"control: never reached with debug off\")", "before"))),
  workers_guard_off = variant("unrefused", list(edit("loop_harness.R", "lean_sweep_impl",
    "      lean_entry$refused <- c(lean_entry$refused, \"sweep workers\")")), tables = "^$")
)
if (nzchar(mutation) && is.null(loop_mutations[[mutation]])) stop("unknown --mutation: ", mutation, call. = FALSE)

source(file.path(here, "..", "load.R"))
lean <- lean_core_load(lib, debug = debug)
ns <- asNamespace("ledgr")
if (nzchar(mutation)) {
  lean_load_edited(lean, lean_core_home, loop_mutations[[mutation]]$edits,
                   marker = "lean_entry$variant_reached <- TRUE")
  lean$lean_entry$mutation <- mutation
}
if (nzchar(witness_file)) lean_core_source(lean, witness_file)

repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(repo, "dev/bench/v0_2_3_ws16_entry/workloads.R"))
source(file.path(repo, "dev/bench/v0_2_3_output_freeze/lib.R"))
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))
source(file.path(here, "prep_fixture.R"))
lean_harness_workdir(if (nzchar(workdir_control)) workdir_control else NULL)
worker_origin <- lean_worker_origin_install(file.path(lib, "ledgr"))
work <- file.path(tempdir(), "loop_parity")
dir.create(work, showWarnings = FALSE)

collect_open <- function(snapshot, db, run_id, exp, ...) {
  sink <- a0_new_sink()
  ok <- a0_run_or_record(close(ledgr::ledgr_run(exp, run_id = run_id, ...)), run_id, sink)
  # A reader refusal (an INCOMPLETE run) is itself compared.
  readers <- if (ok) tryCatch(a0_reader_tables(snapshot, run_id), error = function(e) {
    list(reader_refusal = data.frame(class = class(e)[[1L]], message = conditionMessage(e), stringsAsFactors = FALSE))
  })
  list(run = c(a0_store_tables(db, run_id), readers,
               list(run_conditions = a0_canon(sink$rows, "run_conditions", "seq"))))
}
collect <- function(db, snapshot_id, run_id, experiment, ...) {
  snapshot <- ledgr::ledgr_snapshot_open(db, snapshot_id, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  collect_open(snapshot, db, run_id, experiment(snapshot), ...)
}
build <- function(name, make) {
  db <- file.path(work, paste0(name, ".duckdb"))
  if (file.exists(db)) unlink(db)
  ledgr::ledgr_snapshot_close(make(db))
  db
}
crossover_exp <- function(snapshot) {
  strategy <- r_floor_transition
  environment(strategy) <- ns
  ledgr::ledgr_experiment(snapshot, strategy,
    features = ledgr::ledgr_feature_map(
      fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
    risk_chain = ledgr::ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE))
}
crossover <- function(n_inst, n_days) function() {
  name <- sprintf("crossover_%dx%d", n_inst, n_days)
  db <- build(name, function(db) ledgr::ledgr_snapshot_from_df(r_floor_fixture(n_inst, n_days)$bars, db_path = db,
                                                              snapshot_id = name, price_basis = "split_adjusted"))
  collect(db, name, "lp-crossover", crossover_exp, seed = 20260530L)
}
source(file.path(here, "loop_workloads.R"))
source(file.path(here, "loop_workloads_slice2.R"))
source(file.path(here, "loop_workloads_slice3.R"))
source(file.path(here, "loop_workloads_slice4.R"))
extra <- c(list(
  crossover_3x40 = crossover(3L, 40L),
  crossover_10x300 = crossover(10L, 300L),
  crossover_10x7200 = crossover(10L, 7200L),
  crossover_20x23400 = crossover(20L, 23400L),
  crossover_500x1260 = crossover(500L, 1260L),
  fill_heavy_500x1260 = function() {
    db <- build("fill", function(db) ledgr::ledgr_snapshot_from_df(ws16_fill_heavy_bars(), db_path = db,
                                                                   snapshot_id = "lp_fill"))
    collect(db, "lp_fill", "lp-fill", ws16_fill_heavy_experiment, seed = 20260530L)
  },
  momentum_40x504 = function() {
    db <- build("momentum", function(db) ws16_momentum_snapshot(40L, 504L, db, "lp_momentum"))
    collect(db, "lp_momentum", "lp-momentum", function(s) ws16_momentum_experiment(s, 63L),
            params = list(lookback = 63L, n = 10L), seed = 1L)
  },
  prep_fixture = function() {
    db <- file.path(work, "prep_fixture.duckdb")
    if (file.exists(db)) unlink(db)
    fx <- lc_prep_fixture(db)
    on.exit(ledgr::ledgr_snapshot_close(fx$snapshot))
    collect_open(fx$snapshot, db, "lp-prep-fixture", fx$exp, seed = 1L,
                 params = utils::modifyList(lc_prep_fixture_params, list(trade = TRUE, lookback = 10L, n = 3L)))
  }
), loop_constructed, loop_witnesses, loop_slice2, loop_slice3, loop_slice4)
all_ids <- c(names(a0_workloads), names(extra))
ids <- strsplit(arg("workloads", paste(all_ids, collapse = ",")), ",")[[1L]]
if (length(bad <- setdiff(ids, all_ids))) stop("unknown workload(s): ", paste(bad, collapse = ", "), call. = FALSE)
run_tables <- function(id) {
  if (id %in% names(a0_workloads)) a0_run_workload(id, work)$tables else extra[[id]]()
}
first_difference <- function(a, b) {
  if (!identical(names(a), names(b))) return("<columns>")
  if (nrow(a) != nrow(b)) return(sprintf("<rows %d vs %d>", nrow(a), nrow(b)))
  if (!identical(attr(a, "a0_types"), attr(b, "a0_types"))) return("<types>")
  for (col in names(a)) {
    d <- which(!(a[[col]] == b[[col]] | (is.na(a[[col]]) & is.na(b[[col]]))) | xor(is.na(a[[col]]), is.na(b[[col]])))
    if (length(d)) return(sprintf("row %d column %s: %s vs %s", d[[1L]], col, a[[col]][[d[[1L]]]], b[[col]][[d[[1L]]]]))
  }
  "<attributes>"
}
# An error escaping a whole workload is itself an output, compared as a table.
escaped <- function(e) list(escaped = list(error = data.frame(class = class(e)[[1L]], message = conditionMessage(e),
                                                              stringsAsFactors = FALSE)))
# Every condition message an arm's output carries: run conditions, escaped
# errors, sweep candidate errors and exception diagnostics.
cond_messages <- function(tables) {
  out <- character()
  for (p in tables) for (d in p) {
    if (!is.data.frame(d)) next
    for (col in intersect(names(d), c("message", "error_msg"))) out <- c(out, as.character(d[[col]]))
    if (all(c("outcome", "detail_json") %in% names(d))) out <- c(out, as.character(d$detail_json[d$outcome %in% "error"]))
  }
  unique(out[!is.na(out) & nzchar(out)])
}
freeze <- if (nzchar(freeze_file)) utils::read.csv(freeze_file, stringsAsFactors = FALSE, na.strings = character(),
  colClasses = c(refused = "character", backstop = "character")) else NULL
# The recorded changes to the freeze (loop_freeze_changes.csv, written by
# loop_freeze_changes.R): an update names an existing row, an add a new one.
if (!is.null(freeze)) {
  changes <- utils::read.csv(file.path(here, "loop_freeze_changes.csv"), stringsAsFactors = FALSE,
                             na.strings = character(), colClasses = c(refused = "character", backstop = "character"))
  fkey <- function(x) paste(x$mode, x$workload, x$debug, sep = "|")
  for (i in seq_len(nrow(changes))) {
    ch <- changes[i, ]
    hit <- which(fkey(freeze) == fkey(ch))
    if (ch$action == "update" && length(hit) == 1L) {
      freeze[hit, c("lean_folds", "refused", "backstop")] <- ch[, c("lean_folds", "refused", "backstop")]
    } else if (ch$action == "add" && length(hit) == 0L) {
      freeze <- rbind(freeze, ch[, names(freeze)])
    } else stop("freeze change ", i, " (", ch$action, " ", fkey(ch), ") does not apply", call. = FALSE)
  }
}
mode <- if (inert) "inert" else if (batch_rows == 1L) "batch1" else "gate"
frozen <- if (is.null(freeze)) NULL else freeze[freeze$mode == mode & freeze$debug == as.integer(debug), ]
rows <- list()
verdicts <- character()
for (id in ids) {
  # The caller's RNG state at entry, set outside the workload lean_loop_run()
  # reruns (loop_entry_rng), so a rerun that does not restore it differs.
  entry_rng <- loop_entry_rng[[id]] %||% function() NULL
  t0 <- proc.time()[["elapsed"]]
  worker_origin$read()
  entry_rng()
  pinned <- tryCatch(run_tables(id), error = escaped)
  t1 <- proc.time()[["elapsed"]]
  workers_pinned <- worker_origin$read()
  if (nzchar(dump_dir)) saveRDS(pinned, file.path(dump_dir, paste0(id, ".rds")))
  # The branch the workload is named for, on the pin's own tables (Cut 16
  # decision 4): NA without a predicate; a predicate error counts as not reached.
  branch <- if (is.null(loop_reach[[id]])) NA else tryCatch(isTRUE(loop_reach[[id]](pinned)), error = function(e) {
    cat(sprintf("%s: branch predicate error: %s
", id, conditionMessage(e))); FALSE
  })
  entry_rng()
  lean$lean_entry$variant_reached <- FALSE
  if (exists("capacity", envir = lean$lean_loop_last_times, inherits = FALSE)) rm("capacity", envir = lean$lean_loop_last_times)
  attempt <- if (inert) {
    restore <- lean$lean_loop_install(hooks = FALSE)
    value <- tryCatch(run_tables(id), error = escaped, finally = restore())
    structure(list(value = value), lean = as.list(lean$lean_entry))
  } else tryCatch(lean$lean_loop_run(function() {
    lean$lean_entry$batch_rows <- batch_rows
    run_tables(id)
  }), error = function(e) structure(list(value = escaped(e)), lean = as.list(lean$lean_entry)))
  t2 <- proc.time()[["elapsed"]]
  workers_lean <- worker_origin$read()
  # Slice 4: the lean arm too, for reach cross-checks and diagnosis.
  if (nzchar(dump_dir) && dump_lean) saveRDS(attempt$value, file.path(dump_dir, paste0(id, "_lean.rds")))
  if (!is.null(loop_entry_rng[[id]])) RNGkind("default", "default", "default")
  candidate <- attempt$value
  rec <- attr(attempt, "lean")
  show <- function(x) paste(unique(x), collapse = "; ")
  path_rows <- list()
  for (path in union(names(pinned), names(candidate))) {
    for (tab in union(names(pinned[[path]]), names(candidate[[path]]))) {
      a <- pinned[[path]][[tab]]; b <- candidate[[path]][[tab]]
      same <- identical(a, b)
      path_rows[[length(path_rows) + 1L]] <- data.frame(
        workload = id, path = path, table = tab, debug = as.integer(debug), batch_rows = batch_rows,
        mutation = mutation, lean_folds = rec$lean_folds, refused = show(rec$refused), backstop = show(rec$backstop),
        store_access = show(rec$store_access), sink_calls = show(rec$sink_calls), hold_calls = rec$hold_calls,
        max_append_rows = rec$max_append_rows, max_range_pulses = rec$max_range_pulses,
        rows = if (is.null(a)) NA_integer_ else nrow(a), identical = same,
        first_difference = if (same) "" else if (is.null(a) || is.null(b)) "<missing>" else first_difference(a, b),
        pinned_s = round(t1 - t0, 2), lean_s = round(t2 - t1, 2), stringsAsFactors = FALSE)
    }
  }
  res <- do.call(rbind, path_rows)
  events_left <- sum(vapply(candidate, function(p) if (is.data.frame(p$ledger_events)) nrow(p$ledger_events) else 0L, 0L))
  expected_refusal <- loop_expect_refused[[id]]
  seen <- list(
    differ = !all(res$identical),
    # Cut 26: a worker in either arm on another build than the pin
    worker = !workers_pinned$ok || !workers_lean$ok,
    sink = length(rec$sink_calls) > 0L,
    store = length(rec$store_access) > 0L,
    hold = rec$hold_calls > 0L,
    unrefused = !is.null(expected_refusal) && !expected_refusal %in% rec$refused,
    unbounded = rec$lean_folds > 0L && (rec$max_append_rows > batch_rows || (batch_rows == 1L && rec$max_range_pulses > 1L)),
    # a terminal fault after a completed events append, rolled back
    rollback = !all(res$identical) && events_left == 0L && "ledger_events" %in% rec$terminal_appends,
    # a fault with no completed events append before it: not a rollback witness
    fault_without_append = !all(res$identical) && !"ledger_events" %in% rec$terminal_appends)
  # The execution path against the freeze (R1).
  # With --freeze, a workload without a frozen row for this mode and debug
  # setting fails the path check (Cut 16 R4).
  fz <- if (is.null(frozen)) NULL else frozen[frozen$workload == id, ]
  path_ok <- is.null(fz) || (nrow(fz) == 1L &&
    fz$lean_folds[[1L]] == rec$lean_folds && fz$refused[[1L]] == show(rec$refused) && fz$backstop[[1L]] == show(rec$backstop))
  new_errors <- setdiff(cond_messages(candidate), cond_messages(pinned))
  lost_errors <- setdiff(cond_messages(pinned), cond_messages(candidate))
  # read live: the harness entry copies its record before deciding a rerun
  reached <- isTRUE(lean$lean_entry$variant_reached)
  verdict <- if (seen$worker) "WORKER" else if (!nzchar(mutation)) {
    if (seen$differ || seen$sink || seen$store || seen$hold || seen$unrefused || seen$unbounded) "FAIL"
    else if (identical(branch, FALSE)) "BRANCH"
    else if (!path_ok) "PATH"
    else if (rec$lean_folds == 0L && !length(rec$refused)) "PASS*" else "PASS"
  } else {
    v <- loop_mutations[[mutation]]
    needs_lean <- !identical(v$expect, "unrefused")
    unrelated <- if (is.null(v$error)) new_errors else new_errors[!grepl(v$error, new_errors)]
    differing <- res$table[!res$identical]
    tables_ok <- is.null(v$tables) || (identical(v$tables, "^$") && !length(differing)) ||
      any(grepl(v$tables, differing))
    lost_ok <- is.null(v$lost) || any(grepl(v$lost, lost_errors))
    path_ok <- is.null(v$path) || any(grepl(v$path, c(rec$store_access, rec$sink_calls)))
    if (needs_lean && rec$lean_folds == 0L && !length(rec$backstop)) "NOT RUN"
    else if (!reached) "UNREACHED"
    else if (length(unrelated)) "UNRELATED"
    else if (isTRUE(seen[[v$expect]]) && tables_ok && lost_ok && path_ok) "CAUGHT" else "MISSED"
  }
  verdicts[[id]] <- verdict
  # The verdict and every signal that fired, so the CSV shows what caught a variant.
  res$expect <- if (nzchar(mutation)) loop_mutations[[mutation]]$expect else ""
  res$signals <- paste(names(seen)[vapply(seen, isTRUE, logical(1L))], collapse = ";")
  res$reached <- reached
  res$branch_reached <- branch
  # The last lean fold's sizing record, used and allocated rows (R4).
  cap <- lean$lean_loop_last_times$capacity
  res$sizing_used <- if (is.null(cap) || is.na(cap["sizing_used"])) NA_integer_ else as.integer(cap[["sizing_used"]])
  res$sizing_allocated <- if (is.null(cap) || is.na(cap["sizing_allocated"])) NA_integer_ else as.integer(cap[["sizing_allocated"]])
  # Cut 19 (LDG-3238): the slice-3 row record and the explicit decision record.
  res$slice3_rows_used <- if (is.null(cap) || is.na(cap["slice3_rows_used"])) NA_integer_ else as.integer(cap[["slice3_rows_used"]])
  res$slice3_rows_allocated <- if (is.null(cap) || is.na(cap["slice3_rows_allocated"])) NA_integer_ else as.integer(cap[["slice3_rows_allocated"]])
  res$decisions_used <- if (is.null(cap) || is.na(cap["decisions_used"])) NA_integer_ else as.integer(cap[["decisions_used"]])
  res$decisions_allocated <- if (is.null(cap) || is.na(cap["decisions_allocated"])) NA_integer_ else as.integer(cap[["decisions_allocated"]])
  # Cut 21 (LDG-3244, cut review R8): the corporate-action capture's blocks.
  res$capture_blocks_used <- if (is.null(cap) || is.na(cap["capture_blocks_used"])) NA_integer_ else as.integer(cap[["capture_blocks_used"]])
  res$capture_blocks_allocated <- if (is.null(cap) || is.na(cap["capture_blocks_allocated"])) NA_integer_ else as.integer(cap[["capture_blocks_allocated"]])
  # Cut 21 (LDG-3246, LDG-3247; cut review R8): the typed context positions
  # and the P1 position-transition record.
  for (nm in c("context_used", "context_allocated", "moves_used", "moves_allocated")) {
    res[[nm]] <- if (is.null(cap) || is.na(cap[nm])) NA_integer_ else as.integer(cap[[nm]])
  }
  res$lost_errors <- paste(lost_errors, collapse = " | ")
  res$new_errors <- paste(new_errors, collapse = " | ")
  # Cut 26: worker setups and the origins the workers reported, per arm.
  worker_text <- function(w) if (!length(w$setups)) "" else sprintf("%d/%d %s", w$reported, w$workers, paste(w$origins, collapse = "; "))
  res$workers_pinned <- worker_text(workers_pinned)
  res$workers_lean <- worker_text(workers_lean)
  res$verdict <- verdict
  rows <- c(rows, list(res))
  cat(sprintf("%-28s %-9s %s  lean %d  refused [%s]  backstop [%s]  store [%s]  sink [%s]  holds %d  append<=%d  range<=%d  pinned %.1f s  lean %.1f s%s%s\n",
              id, verdict, if (seen$differ) "DIFFERENT" else "identical", rec$lean_folds, show(rec$refused),
              show(rec$backstop), show(rec$store_access), show(rec$sink_calls), rec$hold_calls, rec$max_append_rows,
              rec$max_range_pulses, t1 - t0, t2 - t1,
              if (length(workers_pinned$setups) || length(workers_lean$setups)) sprintf("  workers pin %d/%d lean %d/%d", workers_pinned$reported, workers_pinned$workers, workers_lean$reported, workers_lean$workers) else "",
              if (length(new_errors)) paste0("  new errors [", paste(substr(new_errors, 1L, 120L), collapse = " | "), "]") else ""))
}
full_run_requested <- !any(grepl("^--workloads=", commandArgs(TRUE)))
missing_frozen <- if (!is.null(frozen) && full_run_requested) setdiff(frozen$workload, ids) else character()
if (length(missing_frozen)) cat("frozen workloads not run:", paste(missing_frozen, collapse = ", "), "\n")
# A workload with no frozen row for this mode and debug setting had no path
# check; name them so a record never implies one (close review round 1,
# finding 5).
if (!is.null(frozen)) {
  unfrozen <- setdiff(ids, frozen$workload)
  cat(sprintf("frozen paths (%s, debug %d): %d of %d workloads checked%s\n", mode, as.integer(debug),
              length(ids) - length(unfrozen), length(ids),
              if (length(unfrozen)) paste0("; no frozen row: ", paste(unfrozen, collapse = ", ")) else ""))
}
res <- do.call(rbind, rows)
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(res, out, row.names = FALSE)
cat(sprintf("%d tables, %d different; verdicts: %s\n", nrow(res), sum(!res$identical),
            paste(names(table(verdicts)), table(verdicts), sep = " ", collapse = ", ")))
bad <- if (nzchar(mutation)) verdicts != "CAUGHT" else verdicts %in% c("FAIL", "PATH", "BRANCH", "WORKER")
if (any(bad) || length(missing_frozen)) quit(status = 1L)
