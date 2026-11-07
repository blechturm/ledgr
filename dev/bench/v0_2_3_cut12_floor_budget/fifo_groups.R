# Operation-group check for the FIFO family (LDG-3214, Cut 12 decision (5):
# "no captured operation group slower than pinned in total"). Descriptive,
# not a harness gate: the per-bucket fill-heavy gate is the timing protocol
# dev/bench/timing/protocols/cut12-fifo-1/.
#
# Groups every captured ledgr_lot_apply call by operation (opening, fill,
# disposition) and block bucket (1-9, 10-49, 50+): the recorder captures of
# the A0 workloads, momentum and fill-heavy, and the pinned test suite's
# unmocked calls. Refused calls are left out (they time a condition), and so
# is any call either arm does not reproduce exactly (counted). Each arm is
# kernel plus input validation:
#   pinned  ledgr_lot_apply(book, ledgr_lot_input(...))   installed, byte-compiled
#   lean    lean_lot_apply(book, lean_lot_input(...))     dev/lean_core/fifo.R, debug off, cmpfun
# with the JIT off. Per group and round the arms alternate (pinned first in
# odd rounds), each repeated so one timing spans at least 0.5 s; a group's
# seconds are the median time of one pass over its calls.
#
# Usage (host set up per benchmark_methodology: High performance plan,
# P-core affinity, no other R):
#   Rscript dev/bench/v0_2_3_cut12_floor_budget/fifo_groups.R <pinned lib> <captures dir> <tests dir> [rounds] [out csv]
# <captures dir>: dev/lean_core/recorder/run.R --boundaries=lot output;
# <tests dir>: dev/lean_core/parity/fifo_capture_tests.R output. Default
# output: evidence/fifo_groups.csv.

args <- commandArgs(TRUE)
lib <- args[[1L]]
captures <- args[[2L]]
tests <- args[[3L]]
rounds <- if (length(args) >= 4L) as.integer(args[[4L]]) else 7L
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
out_csv <- if (length(args) >= 5L) args[[5L]] else file.path(here, "evidence", "fifo_groups.csv")

source(file.path(repo, "dev/lean_core/load.R"))
lean <- lean_core_load(lib, debug = FALSE)
for (f in ls(lean, all.names = TRUE)) {
  if (is.function(lean[[f]])) assign(f, compiler::cmpfun(lean[[f]]), envir = lean)
}
rec <- new.env(parent = asNamespace("ledgr"))
lean_core_source(rec, c(file.path(repo, "dev/bench/v0_2_3_ws16_entry/common.R"),
                        file.path(repo, "dev/lean_core/recorder", c("fields.R", "capture.R", "compare.R", "replay.R"))))
ns <- asNamespace("ledgr")
invisible(compiler::enableJIT(0L))
refused <- function(x) is.list(x) && !is.null(x$class) && !is.null(x$message) && is.null(x$book)

# Every captured call: book, input, expected result.
workloads <- c("dense_cost", "dense_risk_features", "dense_dividend_state", "avail_terminal_resume",
               "avail_acquisition", "avail_incomplete", "walk_forward", "failures", "momentum_40x504",
               "fill_heavy_500x1260")
calls <- list()
for (w in workloads) {
  cap <- rec$lc_read_capture(file.path(captures, paste0(w, ".rds")))
  calls <- c(calls, lapply(Filter(function(r) is.null(r$cond), cap$records), function(r) {
    x <- rec$lc_thaw(r$input, cap$store)
    list(book = x[["arg:book"]], input = x[["arg:input"]], expected = rec$lc_thaw(r$output, cap$store)$value)
  }))
  rm(cap)
}
for (f in sort(list.files(tests, "^tests_[0-9]+[.]rds$", full.names = TRUE))) {
  chunk <- Filter(function(k) is.null(k$input_args) && !length(k$mocked) && !refused(k$value), readRDS(f))
  calls <- c(calls, lapply(chunk, function(k) list(book = k$book, input = k$input, expected = k$value)))
}
rm(rec)

pinned <- compiler::cmpfun(function(k) {
  i <- k$input
  ns$ledgr_lot_apply(k$book, ns$ledgr_lot_input(i$operation[[1L]], i$pos, i$side, i$qty, i$price, i$fee,
                                                i$position_before, i$realized_model_pnl))
})
lean_input <- lean$lean_lot_input
lean_apply <- lean$lean_lot_apply
leaner <- compiler::cmpfun(function(k) {
  i <- k$input
  lean_apply(k$book, lean_input(i$operation[[1L]], i$pos, i$side, i$qty, i$price, i$fee,
                                i$position_before, i$realized_model_pnl))
})
try_same <- function(fn, k) isTRUE(tryCatch(identical(fn(k), k$expected), error = function(e) FALSE))
kept <- vapply(calls, function(k) try_same(pinned, k) && try_same(leaner, k), logical(1))

op_name <- c("1" = "fill", "3" = "opening", "4" = "disposition")
op <- vapply(calls, function(k) as.character(k$input$operation[1L]), "")
op <- ifelse(op %in% names(op_name), op_name[op], paste0("op", op))
m <- vapply(calls, function(k) length(k$input$pos), integer(1))
bucket <- ifelse(m >= 50L, "50+", ifelse(m >= 10L, "10-49", ifelse(m >= 1L, "1-9", "0")))
group <- paste(op, bucket)

drive <- compiler::cmpfun(function(fn, group_calls, reps) {
  t0 <- proc.time()[["elapsed"]]
  for (r in seq_len(reps)) for (k in group_calls) fn(k)
  proc.time()[["elapsed"]] - t0
})
rows <- list()
for (g in sort(unique(group))) {
  in_g <- group == g
  gc_calls <- calls[in_g & kept]
  n <- length(gc_calls)
  row <- data.frame(group = g, calls = n, rows = sum(m[in_g & kept]), dropped = sum(in_g & !kept),
                    rounds = rounds, reps = NA_integer_, pinned_s = NA_real_, lean_s = NA_real_, ratio = NA_real_)
  if (n > 0L) {
    one <- max(drive(leaner, gc_calls, 1L), 0.001)
    reps <- max(1L, as.integer(ceiling(0.5 / one)))
    t_pin <- t_lean <- numeric(rounds)
    for (i in seq_len(rounds)) {
      if (i %% 2L == 1L) {
        t_pin[i] <- drive(pinned, gc_calls, reps)
        t_lean[i] <- drive(leaner, gc_calls, reps)
      } else {
        t_lean[i] <- drive(leaner, gc_calls, reps)
        t_pin[i] <- drive(pinned, gc_calls, reps)
      }
    }
    row$reps <- reps
    row$pinned_s <- signif(stats::median(t_pin) / reps, 4)
    row$lean_s <- signif(stats::median(t_lean) / reps, 4)
    row$ratio <- round(stats::median(t_lean) / stats::median(t_pin), 3)
  }
  rows[[g]] <- row
}
out <- do.call(rbind, rows)
print(out, row.names = FALSE)
dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(out, out_csv, row.names = FALSE)
