# LDG-3213 parity runner: the lean FIFO kernel (dev/lean_core/fifo.R)
# against the pinned ledgr_lot_apply(), with debug off and on.
#
#   Rscript dev/lean_core/parity/fifo_parity.R --lib=<pinned library>
#     --captures=<recorder.R --boundaries=lot captures> --tests=<fifo_capture_tests.R output>
#     --out=<evidence dir>
#
# 1. Captured calls: every ledgr_lot_apply call of the A0 workloads,
#    momentum and fill-heavy (recorder) and of the pinned test suite. The
#    whole result (book and the eight applied fields) or the condition's
#    class and message must be identical(); inputs must be unchanged
#    (serialized bytes); edits to results must not reach inputs and edits
#    to inputs must not reach results; fill rows' leg fees must match
#    ledgr_fill_leg_fees(). Calls made while a test had mocked a kernel
#    helper exercise the oracle's instrumentation and are counted, not
#    compared. The suite's ledgr_lot_input refusals are replayed through
#    lean_lot_input (shape-only violations must match with debug on).
# 2. Generated streams (fifo_streams.R), through the operation wrappers and
#    the block driver of both sides.
# 3. The six registered mutations of fifo.R: each must fail parity.
# 4. Static calls: the lean functions call no ledgr function but the shared
#    validators and condition constructors.

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) stop("--", name, "= is required", call. = FALSE)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
lib <- arg("lib")
out <- arg("out")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
source(file.path(here, "..", "load.R"))
lean <- lean_core_load(lib, debug = FALSE)
lean_dbg <- lean_core_load(lib, debug = TRUE)
lean_core_source(lean, c(file.path(lean_core_home, "..", "bench", "v0_2_3_ws16_entry", "common.R"),
                         file.path(lean_core_home, "recorder", c("fields.R", "capture.R", "compare.R", "replay.R"))))
source(file.path(here, "fifo_streams.R"))
ns <- asNamespace("ledgr")
fields <- c("position_before", "position_after", "close_qty", "open_qty", "realized_close",
            "realized_delta", "event_realized", "event_cost_basis")

outcome <- function(expr) {
  tryCatch(expr, error = function(e) list(class = class(e), message = conditionMessage(e)))
}
bytes <- function(x) serialize(x, NULL, version = 2L)
refused <- function(x) !is.null(x$class)

# Edits every column of x at its first element (ordinary R edits).
poke <- function(x) {
  for (f in names(x)) if (length(x[[f]]) > 0L) x[[f]][[1L]] <- x[[f]][[1L]] + 1L
  x
}

# One captured call against one lean environment; returns the checks.
check_call <- function(env, book, input, expected) {
  before <- bytes(list(book, input))
  got <- outcome(env$lean_lot_apply(book, input))
  same <- identical(got, expected)
  kept <- identical(bytes(list(book, input)), before)
  owned <- legs <- TRUE
  if (!refused(got)) {
    held <- bytes(got)
    book2 <- poke(book)
    input2 <- poke(input)
    got2 <- got
    got2$book <- poke(got2$book)
    got2$applied <- poke(got2$applied)
    owned <- identical(bytes(got), held) && identical(bytes(list(book, input)), before)
    if (all(input$operation == 1L) && !refused(expected)) {
      legs <- identical(env$lean_fill_leg_fees(input$fee, got$applied$close_qty, got$applied$open_qty),
                        ns$ledgr_fill_leg_fees(input$fee, expected$applied$close_qty, expected$applied$open_qty))
    }
  }
  c(same = same, kept = kept, owned = owned, legs = legs)
}

# Per source: calls, rows, refusals, mocked calls (not compared), and the
# number of compared calls that pass each check in each debug setting.
sources <- list()
first_failures <- list()
tally <- function(source, calls) {
  n <- length(calls)
  rows <- sum(vapply(calls, function(k) length(k$input$pos), integer(1)))
  mocked <- vapply(calls, function(k) length(k$mocked) > 0L, logical(1))
  refusals <- vapply(calls, function(k) refused(k$expected), logical(1))
  row <- data.frame(source = source, calls = n, rows = rows, refusals = sum(refusals),
                    mocked_not_compared = sum(mocked), refusals_compared = sum(refusals[!mocked]))
  for (mode in c("off", "on")) {
    env <- if (mode == "off") lean else lean_dbg
    res <- vapply(calls[!mocked], function(k) check_call(env, k$book, k$input, k$expected), logical(4))
    if (!length(res)) res <- matrix(TRUE, 4L, 0L, dimnames = list(c("same", "kept", "owned", "legs"), NULL))
    row[[paste0("identical_debug_", mode)]] <- sum(res["same", ])
    row[[paste0("refusals_identical_debug_", mode)]] <- sum(res["same", refusals[!mocked]])
    row[[paste0("inputs_kept_debug_", mode)]] <- sum(res["kept", ])
    row[[paste0("ownership_debug_", mode)]] <- sum(res["owned", ])
    row[[paste0("leg_fees_debug_", mode)]] <- sum(res["legs", ])
    bad <- which(!apply(res, 2L, all))
    if (length(bad)) first_failures[[paste(source, mode)]] <<- which(!mocked)[bad]
  }
  sources[[source]] <<- row
  invisible(calls)
}

# Recorder captures: arg:book, arg:input in, value or cond out.
recorder_calls <- function(workload) {
  cap <- lean$lc_read_capture(file.path(arg("captures"), paste0(workload, ".rds")))
  lapply(cap$records, function(r) {
    x <- lean$lc_thaw(r$input, cap$store)
    expected <- if (is.null(r$cond)) lean$lc_thaw(r$output, cap$store)$value else r$cond
    list(book = x[["arg:book"]], input = x[["arg:input"]], expected = expected, mocked = character())
  })
}
a0 <- c("dense_cost", "dense_risk_features", "dense_dividend_state", "avail_terminal_resume",
        "avail_acquisition", "avail_incomplete", "walk_forward", "failures")
tally("a0", do.call(c, lapply(a0, recorder_calls)))
tally("momentum_40x504", recorder_calls("momentum_40x504"))
fill_heavy <- tally("fill_heavy_500x1260", recorder_calls("fill_heavy_500x1260"))
test_calls <- do.call(c, lapply(sort(list.files(arg("tests"), "^tests_[0-9]+[.]rds$", full.names = TRUE)), readRDS))
# Refusals of the input boundary (ledgr_lot_input) the suite raised, with
# their arguments: lean_lot_input must refuse with the same class and message.
is_input <- vapply(test_calls, function(k) !is.null(k$input_args), logical(1))
input_refusals <- test_calls[is_input]
test_calls <- lapply(test_calls[!is_input], function(k) list(book = k$book, input = k$input, expected = k$value, mocked = k$mocked))
tally("tests", test_calls)
label <- function(k) paste(k$expected$class[[1L]], k$expected$message, sep = ": ")
test_refusals <- table(c(paste0("kernel ", vapply(Filter(function(k) refused(k$expected), test_calls), label, "")),
                         paste0("input ", vapply(input_refusals, function(k) label(list(expected = k$value)), ""))))
rm(test_calls)
# Shape, type and distinct-position violations are debug-only (LR-18): with
# debug off they must still match when an economic rule also refuses.
shape_bad <- function(operation, pos, side, qty, price, fee = 0, position_before = NA_real_,
                      realized_model_pnl = NA_real_) {
  m <- length(pos)
  shared <- list(fee, position_before, realized_model_pnl)
  !is.integer(operation) || length(operation) != 1L || !is.integer(pos) || !is.integer(side) ||
    length(side) != m || !is.double(qty) || length(qty) != m || !is.double(price) || length(price) != m ||
    !all(vapply(shared, is.double, logical(1))) || !all(lengths(shared) %in% unique(c(1L, m))) ||
    anyDuplicated(pos) > 0L
}
input_same <- function(env) vapply(input_refusals, function(k) {
  identical(outcome(do.call(env$lean_lot_input, k$input_args)), k$value)
}, logical(1))
shape <- vapply(input_refusals, function(k) do.call(shape_bad, k$input_args), logical(1))
off <- input_same(lean)
on <- input_same(lean_dbg)
input_out <- data.frame(kind = c("economic rule", "shape only (debug-only, LR-18)"),
                        calls = c(sum(!shape), sum(shape)),
                        identical_debug_off = c(sum(off[!shape]), sum(off[shape])),
                        identical_debug_on = c(sum(on[!shape]), sum(on[shape])))
utils::write.csv(input_out, file.path(out, "fifo_input_refusals.csv"), row.names = FALSE)
parity <- do.call(rbind, sources)
utils::write.csv(parity, file.path(out, "fifo_parity.csv"), row.names = FALSE)
utils::write.csv(data.frame(refusal = names(test_refusals), n = as.integer(test_refusals)),
                 file.path(out, "fifo_test_refusals.csv"), row.names = FALSE)

# 2. Generated streams, both debug settings.
streams <- fifo_streams(ns)
stream_rows <- lapply(names(streams), function(s) {
  r <- data.frame(stream = s, steps = length(streams[[s]]$steps))
  for (mode in c("off", "on")) {
    res <- fifo_run_stream(streams[[s]], ns, if (mode == "off") lean else lean_dbg)
    r$rows <- res$rows
    r$refusals <- res$refusals
    r[[paste0("identical_debug_", mode)]] <- res$same
  }
  r
})
streams_out <- do.call(rbind, stream_rows)
utils::write.csv(streams_out, file.path(out, "fifo_streams.csv"), row.names = FALSE)

# 3. Mutations (six, plus two for Cut 15's simple path): one textual change to fifo.R each, sourced into a fresh
# environment; each must make at least one generated stream or fill-heavy
# call differ, with debug off and with debug on. The two simple-path
# mutations must also be reached: with debug on, the simple path's comparator
# refuses at least one stream step (its result differs from the general
# kernel's). The control raises an unrelated error in the simple close and
# must not count as that signal (close review round 1, finding 3).
fifo_src <- readLines(file.path(lean_core_home, "fifo.R"))
mutations <- list(
  ordered_total_by_sum = c("total <- total - old_basis[[k]] + new_basis[[k]]",
                           "total <- book$total_cost_basis + sum(new_basis[seq_len(k)] - old_basis[seq_len(k)])"),
  no_dust_snap = c("left[abs(left) <= tol] <- 0", "left <- left"),
  swapped_fee_split = c("list(close = close_fee, open = open_fee)", "list(close = open_fee, open = close_fee)"),
  kahan_step_on_openings = c("if (consuming[[k]]) {", "if (TRUE) {"),
  merged_repeated_openings = c("block <- ledgr_lot_blocks(pos, new_run)", "block <- cumsum(new_run)"),
  last_row_refusal = c("k <- first[[1L]]", "k <- first[[length(first)]]"),
  # Cut 15, LDG-3223: the simple lot path admits an over-close, or books the
  # realized close with the wrong sign.
  simple_admits_over = c("lot * side < 0 & abs(lot) == quantity", "lot * side < 0 & abs(lot) <= quantity"),
  simple_close_sign = c("((price[k] - p[slot[k]]) * -s) * take", "((price[k] - p[slot[k]]) * s) * take"),
  control_simple_unrelated_error = c("((price[k] - p[slot[k]]) * -s) * take", "stop(\"control: unrelated failure\")")
)
simple_signal <- "Lean simple lot path differs from the general kernel."
mutation_env <- function(text, debug) {
  env <- new.env(parent = ns)
  env$.lean_debug <- debug
  eval(parse(text = text, keep.source = FALSE), envir = env)
  env
}
mutation_rows <- lapply(names(mutations), function(name) {
  mu <- mutations[[name]]
  hit <- grep(mu[[1L]], fifo_src, fixed = TRUE)
  stopifnot(length(hit) == 1L)
  text <- fifo_src
  text[hit] <- sub(mu[[1L]], mu[[2L]], text[hit], fixed = TRUE)
  r <- data.frame(mutation = name, line = hit)
  for (debug in c(FALSE, TRUE)) {
    env <- mutation_env(text, debug)
    runs <- lapply(streams, function(s) fifo_run_stream(s, ns, env))
    differing <- Filter(function(s) runs[[s]]$same < length(streams[[s]]$steps), names(runs))
    heavy <- sum(!vapply(fill_heavy, function(k) check_call(env, k$book, k$input, k$expected)[["same"]], logical(1)))
    tag <- if (debug) "debug_on" else "debug_off"
    r[[paste0("streams_differing_", tag)]] <- length(differing)
    r[[paste0("fill_heavy_calls_differing_", tag)]] <- heavy
    if (!debug) r$example_stream <- c(differing, "")[[1L]]
    if (debug) r$simple_comparator_refusals_debug_on <- sum(unlist(lapply(runs, `[[`, "messages")) == simple_signal)
  }
  r$fails_parity <- (r$streams_differing_debug_off > 0L || r$fill_heavy_calls_differing_debug_off > 0L) &&
    (r$streams_differing_debug_on > 0L || r$fill_heavy_calls_differing_debug_on > 0L)
  r$reached <- if (startsWith(name, "simple_") || startsWith(name, "control_simple_")) {
    r$simple_comparator_refusals_debug_on > 0L
  } else NA
  r
})
mutations_out <- do.call(rbind, mutation_rows)
utils::write.csv(mutations_out, file.path(out, "fifo_mutations.csv"), row.names = FALSE)

# 4. Static calls into the ledgr namespace from the lean FIFO functions
# (fifo.R). Cut 19: `^lean_state` narrowed to lean_state_invariant, the
# only fifo.R function of that prefix; since Cut 18 the prefix also matched
# checks.R's state fast paths (lean_state_apply, lean_state_value), which are
# not FIFO code and call the state validators they shadow.
allowed <- c("ledgr_lot_input", "ledgr_lot_applied", "ledgr_lot_book_problem", "ledgr_lot_book_validate",
             "ledgr_accounting_event_error", "ledgr_lot_blocks")
lean_fns <- Filter(function(f) is.function(get(f, envir = lean)), grep("^lean_lot_|^lean_fill|^lean_invalid|^lean_state_invariant$",
                                                                         ls(lean, all.names = TRUE), value = TRUE))
called <- sort(unique(unlist(lapply(lean_fns, function(f) {
  g <- codetools::findGlobals(get(f, envir = lean), merge = FALSE)$functions
  g[startsWith(g, "ledgr_") & vapply(g, exists, logical(1), envir = ns, inherits = FALSE)]
}))))
calls_out <- data.frame(ledgr_function = called, allowed = called %in% allowed)
utils::write.csv(calls_out, file.path(out, "fifo_calls.csv"), row.names = FALSE)

print(parity, row.names = FALSE)
print(streams_out, row.names = FALSE)
print(mutations_out, row.names = FALSE)
print(calls_out, row.names = FALSE)
if (length(first_failures)) {
  cat("first failing calls:\n")
  str(lapply(first_failures, utils::head, 5L))
  saveRDS(first_failures, file.path(tempdir(), "fifo_first_failures.rds"))
}
