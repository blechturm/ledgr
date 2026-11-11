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
#     [--mutation=<name>]
#
# --mutation loads loop.R or loop_harness.R with one registered text patch
# (loop_mutations below; the production code holds no witness branch) and
# inverts the verdict: the patch must be CAUGHT by the evidence named in its
# `expect`. PASS* marks a workload whose public call stopped before any fold
# ran.

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

# Text mutations. Each edit names a file of dev/lean_core, one exact anchor
# line, and lines inserted before or after it or replacing it.
edit <- function(file, at, lines = character(), where = "replace") list(file = file, at = at, lines = lines, where = where)
loop_mutations <- list(
  fill_price_ulp = list(expect = "differ", edits = list(edit("loop.R", "    src <- fl",
    "    if (nf > 0L) src$price[[1L]] <- src$price[[1L]] * (1 + .Machine$double.eps)", "after"))),
  drop_hold = list(expect = "differ", edits = list(edit("loop.R", "      hc <- which(hold)",
    "      if (a == 1L && any(hold)) hold[which(hold)[[1L]]] <- FALSE", "before"))),
  hold_position = list(expect = "differ", edits = list(edit("loop.R", "      hpos <- lean_loop_positions_at(hk, hp, a, b, fr, carry)",
    "      if (a == 1L && length(hpos)) hpos[[1L]] <- hpos[[1L]] + 1", "after"))),
  write_in_loop = list(expect = "sink", edits = list(edit("loop.R",
    "        last_executed <<- max(last_executed, fill$exec_ts, na.rm = TRUE)",
    c("        if (nf == n_fill) output_handler$write_fill_events(fill = fill, i = seq_len(n_fill),",
      "          instrument_id = ids[fill$pos], event_seq = event_seq - n_fill, use_transaction = FALSE)"), "after"))),
  store_in_loop = list(expect = "store", edits = list(edit("loop.R",
    "        last_executed <<- max(last_executed, fill$exec_ts, na.rm = TRUE)",
    c("        if (nf == n_fill) {",
      "          scratch <- DBI::dbConnect(duckdb::duckdb())",
      "          DBI::dbExecute(scratch, \"CREATE TABLE probe (value INTEGER)\")",
      "          stmt <- DBI::dbSendStatement(scratch, \"INSERT INTO probe VALUES (?)\")",
      "          DBI::dbBind(stmt, list(7L)); DBI::dbClearResult(stmt)",
      "          DBI::dbGetQuery(scratch, \"INSERT INTO probe VALUES (2) RETURNING value\")",
      "          ledgr_store_append(scratch, \"probe\", data.frame(value = 1L))",
      "          DBI::dbDisconnect(scratch, shutdown = TRUE)",
      "        }"), "after"))),
  hold_in_loop = list(expect = "hold", edits = list(edit("loop.R", "      processed <<- processed + 1L",
    "      if (i == 1L) lean_loop_expand(1L, 1L, lean_loop_layout(), state0$positions)", "before"))),
  batch_fault = list(expect = "rollback", edits = list(edit("loop.R", "      live$batches <- live$batches + 1L",
    "      if (\"ledger_events\" %in% lean_entry$terminal_appends) stop(\"lean witness: batch fault\")", "after"))),
  fault_before_append = list(expect = "fault_without_append", edits = list(edit("loop.R",
    "      live$batches <- live$batches + 1L", "      stop(\"lean witness: early batch fault\")", "after"))),
  patch_container = list(expect = "differ", edits = list(edit("loop.R",
    "    if (!is.list(update) || is.data.frame(update)) {", "    if (FALSE) {"))),
  zero_pulse_completion = list(expect = "differ", edits = list(edit("loop.R", "    if (n_pulse == 0L) {", "    if (FALSE) {"))),
  read_fast_path = list(expect = "differ", edits = list(edit("loop.R",
    "  if (!is.character(name) || length(name) != 1L || is.na(name) || !nzchar(name)) return(lean_pin_ctx_dollar(x, name))",
    "  if (identical(name, \"\")) return(lean_pin_ctx_dollar(x, name))"))),
  entry_guard_off = list(expect = "unrefused", edits = list(edit("loop.R", "  if (!is.null(entry)) lean_not_covered(entry)"))),
  backstop_off = list(expect = "differ", edits = list(edit("loop_harness.R",
    "  if (length(lean_entry$backstop) > 0L) {", "  if (FALSE) {"))),
  capacity_late = list(expect = "differ", edits = list(edit("loop.R", "      if (nf > capacity) {", "      if (FALSE) {"))),
  commit_late = list(expect = "differ", edits = list(
    edit("loop.R", "      n_committed <<- nf                # the pin flushes the pulse's fills here, before reconciliation"),
    edit("loop.R", "      processed <<- processed + 1L", "      n_committed <<- nf", "before"))),
  expand_whole = list(expect = "unbounded", edits = list(edit("loop.R",
    "      b <- max(a, findInterval(cs[[a]] - lay$rows[[a]] + bound, cs))", "      b <- lay$np")))
)
if (nzchar(mutation) && is.null(loop_mutations[[mutation]])) stop("unknown --mutation: ", mutation, call. = FALSE)

source(file.path(here, "..", "load.R"))
lean <- lean_core_load(lib, debug = debug)
ns <- asNamespace("ledgr")
if (nzchar(mutation)) {
  m <- loop_mutations[[mutation]]
  for (file in unique(vapply(m$edits, `[[`, "", "file"))) {
    x <- readLines(file.path(lean_core_home, file))
    for (e in Filter(function(e) identical(e$file, file), m$edits)) {
      hit <- which(x == e$at)
      if (length(hit) != 1L) stop("mutation ", mutation, ": anchor not unique in ", file, ": ", e$at, call. = FALSE)
      x <- switch(e$where,
        replace = c(x[seq_len(hit - 1L)], e$lines, x[-seq_len(hit)]),
        before = c(x[seq_len(hit - 1L)], e$lines, x[hit:length(x)]),
        after = c(x[seq_len(hit)], e$lines, x[-seq_len(hit)]))
    }
    eval(parse(text = x, keep.source = FALSE), envir = lean)
  }
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
), loop_constructed, loop_witnesses)
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
rows <- list()
verdicts <- character()
for (id in ids) {
  t0 <- proc.time()[["elapsed"]]
  pinned <- tryCatch(run_tables(id), error = escaped)
  t1 <- proc.time()[["elapsed"]]
  attempt <- if (inert) {
    restore <- lean$lean_loop_install(hooks = FALSE)
    value <- tryCatch(run_tables(id), error = escaped, finally = restore())
    structure(list(value = value), lean = as.list(lean$lean_entry))
  } else tryCatch(lean$lean_loop_run(function() {
    lean$lean_entry$batch_rows <- batch_rows
    run_tables(id)
  }), error = function(e) structure(list(value = escaped(e)), lean = as.list(lean$lean_entry)))
  t2 <- proc.time()[["elapsed"]]
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
  rows <- c(rows, path_rows)
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
  verdict <- if (!nzchar(mutation)) {
    if (seen$differ || seen$sink || seen$store || seen$hold || seen$unrefused || seen$unbounded) "FAIL"
    else if (rec$lean_folds == 0L && !length(rec$refused)) "PASS*" else "PASS"
  } else {
    expect <- loop_mutations[[mutation]]$expect
    needs_lean <- !identical(expect, "unrefused")
    if (needs_lean && rec$lean_folds == 0L && !length(rec$backstop)) "NOT RUN"
    else if (isTRUE(seen[[expect]])) "CAUGHT" else "MISSED"
  }
  verdicts[[id]] <- verdict
  cat(sprintf("%-28s %-8s %s  lean %d  refused [%s]  backstop [%s]  store [%s]  sink [%s]  holds %d  append<=%d  range<=%d  pinned %.1f s  lean %.1f s\n",
              id, verdict, if (seen$differ) "DIFFERENT" else "identical", rec$lean_folds, show(rec$refused),
              show(rec$backstop), show(rec$store_access), show(rec$sink_calls), rec$hold_calls, rec$max_append_rows,
              rec$max_range_pulses, t1 - t0, t2 - t1))
}
res <- do.call(rbind, rows)
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(res, out, row.names = FALSE)
cat(sprintf("%d tables, %d different; verdicts: %s\n", nrow(res), sum(!res$identical),
            paste(names(table(verdicts)), table(verdicts), sep = " ", collapse = ", ")))
bad <- if (nzchar(mutation)) verdicts == "MISSED" else verdicts == "FAIL"
if (any(bad)) quit(status = 1L)
