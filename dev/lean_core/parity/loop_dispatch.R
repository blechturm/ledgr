# Dispatch of Cut 15's state-view fast path (decision 2): which side of its
# predicate is taken, counted by load-time edits (loop_edits.R; the tracked
# code holds no counter), against the side established independently.
#
# lean_strategy_view() is fast for a list whose only attribute is its names.
# The fold's declared state is such a list, empty when nothing is declared,
# so every fold takes the fast side; the pin's side is reached by direct
# inputs below.
#
# Workloads run on the lean loop with debug off (production dispatch) and on
# the pin; their fills must match. Direct cases compare lean_strategy_view()
# with ledgr_strategy_state_view() on inputs on both sides of its predicate
# and at its boundaries, and two inputs outside its upstream guarantee that
# the debug comparator must refuse.
#
#   Rscript dev/lean_core/parity/loop_dispatch.R --lib=<pinned library> --out=<csv>

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)[[1L]])
source(file.path(here, "loop_edits.R"))
source(file.path(here, "..", "load.R"))
lean <- lean_core_load(arg("lib"), debug = FALSE)
ns <- asNamespace("ledgr")
count <- function(tag) sprintf("lean_entry$dispatch <- c(lean_entry$dispatch, %s)", tag)
lean_load_edited(lean, lean_core_home, list(
  lean_edit("loop.R", "lean_strategy_view", "    view <- values", count("\"state_view:fast\""), "before", mark = FALSE),
  lean_edit("loop.R", "lean_strategy_view", "  ledgr_strategy_state_view(values)", count("\"state_view:pin\""), "before",
            mark = FALSE)))
branches <- c("state_view:fast", "state_view:pin")
tally <- function() as.integer(table(factor(lean$lean_entry$dispatch, levels = branches)))

bars <- local({
  dates <- as.POSIXct("2021-01-04", tz = "UTC") + 86400 * (0:11)
  rows <- lapply(c(A = 30, B = 45), function(px) px * (1 + 0.05 * sin(seq_along(dates))))
  do.call(rbind, lapply(names(rows), function(id) data.frame(instrument_id = id, ts_utc = dates, open = rows[[id]],
    high = rows[[id]] * 1.01, low = rows[[id]] * 0.99, close = rows[[id]], volume = 100, stringsAsFactors = FALSE)))
})
db <- tempfile(fileext = ".duckdb")
ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(bars, db_path = db, snapshot_id = "dispatch"))

# A workload: whether it declares state (portfolio or asset).
strategy_of <- function(declared) {
  s <- function(ctx, params) {
    targets <- ctx$hold()
    targets[["A"]] <- if (substr(ctx$ts_utc, 9L, 10L) > "07") 1 else 0
    if (DECLARED) ledgr::ledgr_strategy_result(targets, n = 1L, flag = ctx$state$flag) else targets
  }
  body(s) <- do.call(substitute, list(body(s), list(DECLARED = declared)))
  environment(s) <- ns
  s
}
workloads <- list(declared_state = list(declared = TRUE, expect = c(TRUE, FALSE)),
                  no_declared_state = list(declared = FALSE, expect = c(TRUE, FALSE)))
run <- function(id, w, lean_arm) {
  snapshot <- ledgr::ledgr_snapshot_open(db, "dispatch", verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  exp <- ledgr::ledgr_experiment(snapshot, strategy_of(w$declared), opening = ledgr::ledgr_opening(cash = 1000),
    cost_model = ledgr::ledgr_cost_zero(), portfolio_state = if (w$declared) list(n = 0L) else list(),
    asset_state = if (w$declared) list(flag = FALSE) else list())
  if (lean_arm) {
    restore <- lean$lean_loop_install(hooks = FALSE)
    on.exit(restore(), add = TRUE)
  }
  bt <- ledgr::ledgr_run(exp, run_id = paste0("dispatch-", id, "-", lean_arm))
  on.exit(close(bt), add = TRUE)
  as.data.frame(ledgr::ledgr_results(bt, "fills"))[, c("instrument_id", "ts_utc", "side", "qty", "price")]
}
rows <- list()
for (id in names(workloads)) {
  w <- workloads[[id]]
  lean$lean_entry$dispatch <- character()
  lean_fills <- run(id, w, TRUE)
  calls <- tally()
  rows[[id]] <- data.frame(case = id, branch = branches, calls = calls, expected = w$expect,
    matches_pin = identical(lean_fills, run(id, w, FALSE)), stringsAsFactors = FALSE)
}
# Direct cases: the fast side, its boundaries, the pin's side.
direct <- list(
  named_atomic = list(above = c(A = TRUE, B = FALSE), n = 3L),
  named_empty = stats::setNames(list(), character()),
  named_with_list_field = list(a = list(1, 2), b = "x"),
  named_with_blank_name = stats::setNames(list(1, 2), c("a", "")),
  unnamed = list(1, 2),
  empty_unnamed = list(),
  extra_attribute = structure(list(a = 1), note = "x"),
  classed = structure(list(a = 1), class = "foo"),
  not_a_list = c(a = 1)
)
expect_fast <- c(named_atomic = TRUE, named_empty = TRUE, named_with_list_field = TRUE, named_with_blank_name = TRUE,
                 unnamed = FALSE, empty_unnamed = FALSE, extra_attribute = FALSE, classed = FALSE, not_a_list = FALSE)
caught <- function(expr) tryCatch(expr, error = function(e) list(class(e), conditionMessage(e)))
for (id in names(direct)) {
  lean$lean_entry$dispatch <- character()
  got <- caught(lean$lean_strategy_view(direct[[id]]))
  calls <- tally()
  rows[[paste0("direct_", id)]] <- data.frame(case = paste0("direct_", id), branch = branches, calls = calls,
    expected = c(expect_fast[[id]], !expect_fast[[id]]),
    matches_pin = identical(got, caught(ns$ledgr_strategy_state_view(direct[[id]]))), stringsAsFactors = FALSE)
}
# Outside the upstream guarantee (Section 19.8): the fold's declared state is
# an ordinary list of unclassed atomic fields, so these never reach the view
# from the loop. They pass the outer test and differ from the pin; the debug
# comparator must refuse each (close review round 1, finding 2).
`[.ldgr_review_atomic` <- function(x, ...) 99
outside <- list(pairlist = pairlist(a = 1), classed_field = list(a = structure(1, class = "ldgr_review_atomic")))
for (id in names(outside)) {
  lean$lean_entry$dispatch <- character()
  got <- caught(lean$lean_strategy_view(outside[[id]]))
  calls <- tally()
  lean$.lean_debug <- TRUE
  refused <- caught(lean$lean_strategy_view(outside[[id]]))
  lean$.lean_debug <- FALSE
  rows[[paste0("outside_", id)]] <- data.frame(case = paste0("outside_guarantee_", id), branch = branches,
    calls = calls, expected = c(TRUE, FALSE),
    matches_pin = identical(got, caught(ns$ledgr_strategy_state_view(outside[[id]]))), stringsAsFactors = FALSE,
    debug_refused = identical(refused[[2L]], "Lean state view differs from the pin's."))
}
out <- do.call(rbind, lapply(rows, function(r) { if (is.null(r$debug_refused)) r$debug_refused <- NA; r }))
inside <- !startsWith(out$case, "outside_guarantee_")
out$ok <- (out$calls > 0L) == out$expected & ifelse(inside, out$matches_pin, !out$matches_pin & out$debug_refused)
utils::write.csv(out, arg("out"), row.names = FALSE)
print(out, row.names = FALSE)
if (!all(out$ok)) quit(status = 1L)
