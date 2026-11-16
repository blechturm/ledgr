# Hashed-frame witness (Cut 20, decision 5; LDG-3241). Three parts:
#
# A. Frame checks on crossover_3x40's data and experiment through the
#    installed lean loop, with debug off and on: debug off never enters
#    lean_fold_envelope_plain (a trace() counter stays 0) and the body runs in
#    a hashed environment (env.profile() of the frame fold_start sees is not
#    NULL); debug on enters the plain function once per fold (so debug() and
#    debugonce() stop there) in an unhashed frame; lean_envelope_code is
#    bytecode; a static scan finds none of missing(), sys.call(),
#    sys.function(), match.call(), nargs(), parent.frame() at the plain
#    body's top level outside the functions it defines (called by name or as
#    base:: / base:::). Four faults, applied as text edits (loop_edits.R),
#    must each fail: the wrapper ignoring the flag (debug on), an unhashed
#    environment (debug off), a top-level sys.call() and a top-level
#    base::sys.call() (both). A control, base::sys.call() inside a function
#    the body defines, must fail no check.
# B. The test-only adapter (cut review R1): loop_parity.R --witness=
#    hashed_frame_adapter.R with debug on runs the production-loaded compiled
#    body in its hashed frame with the debug assertions on, on
#    crossover_3x40, s2_sizing_rebalance and s3_freeze_exit against the
#    freeze; hashed_frame_adapter_fault.R (.safety_state RED in the hashed
#    code only) must fail on the context comparison on each.
# C. Semantics probe (cut review R4): a plain function against the same body
#    compiled and evaluated in a hashed child of a wrapper's frame, on
#    on.exit() (several, conditional, during unwinding), early and normal
#    returns, <<- from stage closures, stop() and rlang::abort() at the top
#    level and in a called function under calling and exiting handlers.
#    Return values, cleanup and signalling order and semantic condition
#    fields must be equal; top-level condition calls and caller inspection
#    are recorded as expected differences.
#
#   Rscript dev/lean_core/parity/hashed_frame_witness.R --lib=<pinned library> --out=<dir>
#
# Writes frame_checks.csv, adapter.csv (with one log per run) and
# semantics.csv to <dir>; exits 1 unless every expectation holds.

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) stop("--", name, "= is required", call. = FALSE)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
lib <- arg("lib")
out <- arg("out")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(here, "loop_edits.R"))
source(file.path(here, "..", "load.R"))
fixture <- new.env()
sys.source(file.path(repo, "dev/spikes/r_floor/fixture.R"), envir = fixture)

# --- A. frame checks ---------------------------------------------------------

forbidden <- c("missing", "sys.call", "sys.function", "match.call", "nargs", "parent.frame")
# A call head names a function either as a symbol or as base::f / base:::f
# (close review round 1, F2: a qualified call is a direct call too).
head_name <- function(h) {
  if (is.symbol(h)) return(as.character(h))
  if (is.call(h) && length(h) == 3L && is.symbol(h[[1L]]) && as.character(h[[1L]]) %in% c("::", ":::") &&
      identical(as.character(h[[2L]]), "base")) return(as.character(h[[3L]]))
  NA_character_
}
scan_body <- function(x) {
  if (!is.call(x)) return(character())
  h <- head_name(x[[1L]])
  if (identical(h, "function")) return(character())
  c(if (!is.na(h) && h %in% forbidden) h,
    unlist(lapply(as.list(x)[-1L], scan_body), use.names = FALSE))
}
faults <- list(
  none = list(),
  flag = list(lean_edit("loop.R", "lean_fold_envelope",
    "  if (.lean_debug) return(lean_fold_envelope_plain(execution, output_handler))", mark = FALSE)),
  unhashed = list(lean_edit("loop.R", "lean_fold_envelope",
    "  eval(lean_envelope_code, new.env(hash = TRUE, parent = environment()))",
    "  eval(lean_envelope_code, new.env(hash = FALSE, parent = environment()))", mark = FALSE)),
  syscall = list(lean_edit("loop.R", "lean_fold_envelope_plain",
    "  execution <- ledgr_validate_execution_spec(execution)", "  sys.call()", "after", mark = FALSE)),
  syscall_qualified = list(lean_edit("loop.R", "lean_fold_envelope_plain",
    "  execution <- ledgr_validate_execution_spec(execution)", "  base::sys.call()", "after", mark = FALSE)),
  # Control: a forbidden call inside a function the body defines is out of
  # the scan's scope and must not fail it.
  nested_control = list(lean_edit("loop.R", "lean_fold_envelope_plain",
    "  execution <- ledgr_validate_execution_spec(execution)", "  witness_nested <- function() base::sys.call()", "after", mark = FALSE))
)
# Which checks each fault must break, by debug setting (none: no check).
expect_fail <- list(none = list(off = character(), on = character()),
                    flag = list(off = character(), on = c("plain_entries", "frame_hashed")),
                    unhashed = list(off = "frame_hashed", on = character()),
                    syscall = list(off = "scan", on = "scan"),
                    syscall_qualified = list(off = "scan", on = "scan"),
                    nested_control = list(off = character(), on = character()))

frame_run <- function(fault, debug) {
  lean <- lean_core_load(lib, debug = debug)
  if (length(faults[[fault]])) lean_load_edited(lean, lean_core_home, faults[[fault]])
  ns <- asNamespace("ledgr")
  seen <- new.env()
  seen$count <- 0L
  lean$witness_seen <- seen
  suppressMessages(trace("lean_fold_envelope_plain", quote(witness_seen$count <- witness_seen$count + 1L),
                         where = lean, print = FALSE))
  restore <- lean$lean_loop_install()   # installs the harness hooks; wrapped below
  on.exit(restore(), add = TRUE)
  start <- lean$lean_hooks$fold_start
  lean$lean_hooks$fold_start <- function(live) {
    seen$frame <- parent.frame()   # the frame the envelope body runs in
    start(live)
  }
  db <- tempfile(fileext = ".duckdb")
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(fixture$r_floor_fixture(3L, 40L)$bars, db_path = db,
    snapshot_id = "crossover_3x40", price_basis = "split_adjusted"))
  snapshot <- ledgr::ledgr_snapshot_open(db, "crossover_3x40", verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- fixture$r_floor_transition
  environment(strategy) <- ns
  exp <- ledgr::ledgr_experiment(snapshot, strategy,
    features = ledgr::ledgr_feature_map(
      fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
    risk_chain = ledgr::ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE))
  folds0 <- lean$lean_entry$lean_folds %||% 0L
  bt <- suppressWarnings(ledgr::ledgr_run(exp, run_id = "witness", seed = 20260530L))
  close(bt)
  folds <- lean$lean_entry$lean_folds - folds0
  checks <- c(lean_fold = folds == 1L,
              plain_entries = seen$count == if (debug) folds else 0L,
              frame_hashed = !is.null(seen$frame) && (!is.null(env.profile(seen$frame)) == !debug),
              bytecode = identical(typeof(lean$lean_envelope_code), "bytecode"),
              scan = length(scan_body(body(lean$lean_fold_envelope_plain))) == 0L)
  data.frame(fault = fault, debug = as.integer(debug), check = names(checks), ok = unname(checks),
             expect_ok = !names(checks) %in% expect_fail[[fault]][[if (debug) "on" else "off"]],
             plain_entries = seen$count, stringsAsFactors = FALSE)
}
frame <- do.call(rbind, lapply(names(faults), function(f) rbind(frame_run(f, FALSE), frame_run(f, TRUE))))
frame$as_expected <- frame$ok == frame$expect_ok
utils::write.csv(frame, file.path(out, "frame_checks.csv"), row.names = FALSE)
for (f in names(faults)) for (d in 0:1) {
  r <- frame[frame$fault == f & frame$debug == d, ]
  failed <- r$check[!r$ok]
  cat(sprintf("A %-9s debug %d: %s -> %s\n", f, d,
              if (length(failed)) paste("fails", paste(failed, collapse = ",")) else "all checks pass",
              if (all(r$as_expected)) "as expected" else "NOT AS EXPECTED"))
}

# --- B. the adapter ---------------------------------------------------------

rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
adapter_workloads <- c("crossover_3x40", "s2_sizing_rebalance", "s3_freeze_exit")
adapter_run <- function(label, file, workloads, expect_exit) {
  csv <- file.path(out, paste0("adapter_", label, ".csv"))
  log <- file.path(out, paste0("adapter_", label, ".log"))
  status <- system2(rscript, c(file.path(here, "loop_parity.R"), paste0("--lib=", lib), "--debug=1",
    paste0("--workloads=", paste(workloads, collapse = ",")), paste0("--freeze=", file.path(here, "loop_freeze.csv")),
    paste0("--witness=", file.path(here, file)), paste0("--out=", csv)), stdout = log, stderr = log)
  r <- if (file.exists(csv)) utils::read.csv(csv, stringsAsFactors = FALSE) else NULL
  text <- paste(readLines(log, warn = FALSE), collapse = "\n")
  context_hit <- grepl("Lean context .safety_state differs from the pin's", text, fixed = TRUE)
  data.frame(label = label, file = file, workloads = paste(workloads, collapse = ","), exit = status,
             tables = NROW(r), different = if (is.null(r)) NA_integer_ else sum(!r$identical),
             context_failure = context_hit, frozen_paths_line = sub("^.*\n(frozen paths[^\n]*).*$", "\\1", text),
             as_expected = if (expect_exit == 0L) status == 0L && !is.null(r) && all(r$identical) && !context_hit
                           else status != 0L && context_hit,
             stringsAsFactors = FALSE)
}
adapter <- rbind(
  adapter_run("pass", "hashed_frame_adapter.R", adapter_workloads, 0L),
  do.call(rbind, lapply(adapter_workloads, function(w) adapter_run(paste0("fault_", w), "hashed_frame_adapter_fault.R", w, 1L))))
utils::write.csv(adapter, file.path(out, "adapter.csv"), row.names = FALSE)
for (i in seq_len(nrow(adapter))) cat(sprintf("B %-26s exit %d, %d tables, %s different, context failure %s -> %s\n",
  adapter$label[[i]], adapter$exit[[i]], adapter$tables[[i]], adapter$different[[i]], adapter$context_failure[[i]],
  if (adapter$as_expected[[i]]) "as expected" else "NOT AS EXPECTED"))

# --- C. semantics probe ------------------------------------------------------

# The production pattern on a toy body: compile once, evaluate in a hashed
# child of the wrapper's frame.
hashed_of <- function(plain) {
  code <- compiler::compile(body(plain), env = environment(plain))
  f <- function(x, log) eval(code, new.env(hash = TRUE, parent = environment()))
  environment(f) <- list2env(list(code = code), parent = environment(plain))
  f
}
helper_stop <- function(msg) stop(msg)
helper_abort <- function(msg) rlang::abort(msg, class = "witness_error", detail = 7L)
helper_caller <- function() deparse(sys.call(-1L))[[1L]]
toy <- function(x, log) {
  push <- function(s) log$v <- c(log$v, s)
  on.exit(push("exit1"), add = TRUE)
  if (x$early) return("early")
  if (x$cond) on.exit(push("exit_cond"), add = TRUE)
  n <- 0L
  bump <- function() n <<- n + 1L          # a stage closure updating envelope state
  for (i in 1:3) bump()
  push(paste0("n=", n))
  if (identical(x$raise, "top_stop")) stop("top-level stop")
  if (identical(x$raise, "top_abort")) rlang::abort("top-level abort", class = "witness_error", detail = 7L)
  if (identical(x$raise, "helper_stop")) helper_stop("helper stop")
  if (identical(x$raise, "helper_abort")) helper_abort("helper abort")
  if (identical(x$raise, "caller")) return(helper_caller())
  on.exit(push("exit_last"), add = TRUE)
  paste0("done:", n)
}
toy_hashed <- hashed_of(toy)
call_text <- function(cnd) if (is.null(conditionCall(cnd))) "<none>" else deparse(conditionCall(cnd))[[1L]]
observe <- function(f, x, handler) {
  log <- new.env()
  log$v <- character()
  res <- switch(handler,
    none = tryCatch(list(value = f(x, log)), error = function(e) list(error = e)),
    exiting = tryCatch(list(value = f(x, log)), error = function(e) { log$v <- c(log$v, "exiting_handler"); list(error = e) }),
    calling = tryCatch(withCallingHandlers(list(value = f(x, log)),
                                            error = function(e) log$v <- c(log$v, "calling_handler")),
                       error = function(e) list(error = e)))
  e <- res$error
  list(value = if (is.null(e)) as.character(res$value) else "<error>",
       order = paste(log$v, collapse = ","),
       class = if (is.null(e)) "<none>" else paste(class(e), collapse = "/"),
       message = if (is.null(e)) "<none>" else conditionMessage(e),
       fields = if (is.null(e)) "<none>" else paste0("detail=", format(e$detail %||% NA)),
       call = if (is.null(e)) "<none>" else call_text(e))
}
cases <- list(
  normal = list(x = list(early = FALSE, cond = FALSE, raise = ""), handler = "none"),
  conditional_exit = list(x = list(early = FALSE, cond = TRUE, raise = ""), handler = "none"),
  early_after_on_exit = list(x = list(early = TRUE, cond = FALSE, raise = ""), handler = "none"),
  top_stop_exiting = list(x = list(early = FALSE, cond = TRUE, raise = "top_stop"), handler = "exiting"),
  top_stop_calling = list(x = list(early = FALSE, cond = TRUE, raise = "top_stop"), handler = "calling"),
  top_abort_exiting = list(x = list(early = FALSE, cond = TRUE, raise = "top_abort"), handler = "exiting"),
  top_abort_calling = list(x = list(early = FALSE, cond = TRUE, raise = "top_abort"), handler = "calling"),
  helper_stop_calling = list(x = list(early = FALSE, cond = TRUE, raise = "helper_stop"), handler = "calling"),
  helper_abort_exiting = list(x = list(early = FALSE, cond = TRUE, raise = "helper_abort"), handler = "exiting"),
  caller_inspection = list(x = list(early = FALSE, cond = FALSE, raise = "caller"), handler = "none")
)
# Expected differences (cut review R4): the condition call of a top-level
# stop(), and what a helper sees as its caller. rlang::abort() records its
# caller's call too; a helper's own stop() records the helper's call.
expected_diff <- function(case, field) {
  (field == "call" && case %in% c("top_stop_exiting", "top_stop_calling", "top_abort_exiting", "top_abort_calling")) ||
    (field == "value" && case == "caller_inspection")
}
sem <- do.call(rbind, lapply(names(cases), function(k) {
  p <- observe(toy, cases[[k]]$x, cases[[k]]$handler)
  h <- observe(toy_hashed, cases[[k]]$x, cases[[k]]$handler)
  do.call(rbind, lapply(names(p), function(fld) data.frame(case = k, field = fld, plain = p[[fld]], hashed = h[[fld]],
    equal = identical(p[[fld]], h[[fld]]), expected_equal = !expected_diff(k, fld), stringsAsFactors = FALSE)))
}))
sem$as_expected <- sem$equal == sem$expected_equal
utils::write.csv(sem, file.path(out, "semantics.csv"), row.names = FALSE)
cat(sprintf("C %d cases, %d fields: %d equal, %d expected differences (%s); %s\n", length(cases), nrow(sem), sum(sem$equal),
            sum(!sem$expected_equal), paste(unique(sem$case[!sem$expected_equal]), collapse = ", "),
            if (all(sem$as_expected)) "as expected" else "NOT AS EXPECTED"))

ok <- all(frame$as_expected) && all(adapter$as_expected) && all(sem$as_expected)
cat(if (ok) "hashed-frame witness: PASS\n" else "hashed-frame witness: FAIL\n")
quit(status = if (ok) 0L else 1L)
