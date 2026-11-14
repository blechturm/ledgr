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
  edit("loop.R", "lean_fold_envelope", "  live$batches <- 0L", c(
    "  scratch <- DBI::dbConnect(duckdb::duckdb())",
    "  DBI::dbExecute(scratch, \"CREATE TABLE probe (value INTEGER)\")",
    if (prepare) "  stmt <- DBI::dbSendStatement(scratch, \"INSERT INTO probe VALUES (?)\")"), "after", mark = FALSE),
  edit("loop.R", "lean_p4_apply", "      last_executed <<- max(last_executed, fill$exec_ts, na.rm = TRUE)",
    paste0("      if (nf == n_fill) { lean_entry$variant_reached <- TRUE; ", if (!is.null(dead)) paste0("if (FALSE) ", dead, "; "),
           call, " }"), "after", mark = FALSE)), tables = "^$", path = path)
loop_mutations <- list(
  fill_price_ulp = variant("differ", list(edit("loop.R", "lean_loop_publish", "    src <- fl",
    "    if (nf > 0L) src$price[[1L]] <- src$price[[1L]] * (1 + .Machine$double.eps)", "after")),
    error = "FILL cash and position deltas do not reconcile"),
  drop_hold = variant("differ", list(edit("loop.R", "lean_loop_expand", "      hc <- which(hold)",
    "      if (a == 1L && any(hold)) hold[which(hold)[[1L]]] <- FALSE", "before")),
    error = "Diagnostic codec coverage is corrupt"),
  hold_position = variant("differ", list(edit("loop.R", "lean_loop_expand",
    "      hpos <- lean_loop_positions_at(hk, hp, a, b, fr, carry)",
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
  zero_pulse_align = variant("differ", list(edit("loop.R", "lean_fold_envelope",
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
  risk_not_applied = variant("differ", list(edit("loop.R", "lean_p2_decide",
    "        risked <- ledgr_apply_risk_plan(targets, risk_plan, ctx)", "        risked <- targets")),
    tables = "^fills$|^ledger_events$|^run_diagnostic"),
  implicit_row_old_rule = variant("differ", list(edit("loop.R", "lean_p4_apply",
    "    differs <- which(!(is.finite(sq) & sq == pos & tq == sq & is.finite(close)))      # LR-23",
    "    differs <- which(!(is.finite(sq) & sq == pos & is.finite(close)))")),
    error = "Diagnostic codec coverage is corrupt", tables = "^run_diagnostic"),
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
    "      add(lay$base[sp] + as.integer(!is.na(hd_intent[sp])) + within, sp, list(instrument_id = szr$id[sr],",
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
    "    if (.lean_debug && length(pulse_notes$sizing_skipped) > 0L) {",
    "    pulse_notes$sizing_skipped <- ids[[1L]]", "before")),
    error = "Lean sizing skipped an instrument"),
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

repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(repo, "dev/bench/v0_2_3_ws16_entry/workloads.R"))
source(file.path(repo, "dev/bench/v0_2_3_output_freeze/lib.R"))
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))
source(file.path(here, "prep_fixture.R"))
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
), loop_constructed, loop_witnesses, loop_slice2)
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
  entry_rng()
  pinned <- tryCatch(run_tables(id), error = escaped)
  t1 <- proc.time()[["elapsed"]]
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
  verdict <- if (!nzchar(mutation)) {
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
  res$lost_errors <- paste(lost_errors, collapse = " | ")
  res$new_errors <- paste(new_errors, collapse = " | ")
  res$verdict <- verdict
  rows <- c(rows, list(res))
  cat(sprintf("%-28s %-9s %s  lean %d  refused [%s]  backstop [%s]  store [%s]  sink [%s]  holds %d  append<=%d  range<=%d  pinned %.1f s  lean %.1f s%s\n",
              id, verdict, if (seen$differ) "DIFFERENT" else "identical", rec$lean_folds, show(rec$refused),
              show(rec$backstop), show(rec$store_access), show(rec$sink_calls), rec$hold_calls, rec$max_append_rows,
              rec$max_range_pulses, t1 - t0, t2 - t1,
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
bad <- if (nzchar(mutation)) verdicts != "CAUGHT" else verdicts %in% c("FAIL", "PATH", "BRANCH")
if (any(bad) || length(missing_frozen)) quit(status = 1L)
