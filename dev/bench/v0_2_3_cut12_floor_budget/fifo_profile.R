# Per-function profile of the lean FIFO kernel (LDG-3214: "per-function
# profile samples are reported"). Runs lean_lot_apply(book, lean_lot_input(...))
# over the captured fill-heavy calls, byte-compiled with the JIT off and
# debug off (as fifo_probe.R times it), under Rprof, and reports each
# function's self and total sample share.
#
#   Rscript dev/bench/v0_2_3_cut12_floor_budget/fifo_profile.R <pinned lib> <captures dir> [seconds] [out csv]
#
# <captures dir> holds fill_heavy_500x1260.rds from
# dev/lean_core/recorder/run.R --boundaries=lot. The profile repeats the
# calls until about `seconds` (default 10) of samples are taken. The default
# output is evidence/fifo_profile.csv.

args <- commandArgs(TRUE)
lib <- args[[1L]]
captures <- args[[2L]]
seconds <- if (length(args) >= 3L) as.numeric(args[[3L]]) else 10
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
out_csv <- if (length(args) >= 4L) args[[4L]] else file.path(here, "evidence", "fifo_profile.csv")

source(file.path(repo, "dev/lean_core/load.R"))
lean <- lean_core_load(lib, debug = FALSE)
for (f in ls(lean, all.names = TRUE)) {
  if (is.function(lean[[f]])) assign(f, compiler::cmpfun(lean[[f]]), envir = lean)
}
lean_core_source(lean, c(file.path(repo, "dev/bench/v0_2_3_ws16_entry/common.R"),
                         file.path(repo, "dev/lean_core/recorder", c("fields.R", "capture.R", "compare.R", "replay.R"))))
invisible(compiler::enableJIT(0L))

cap <- lean$lc_read_capture(file.path(captures, "fill_heavy_500x1260.rds"))
calls <- lapply(cap$records, function(r) {
  x <- lean$lc_thaw(r$input, cap$store)
  list(book = x[["arg:book"]], input = x[["arg:input"]], expected = lean$lc_thaw(r$output, cap$store)$value)
})
rm(cap)

# Bound by name so Rprof labels the frames.
lean_lot_input <- lean$lean_lot_input
lean_lot_apply <- lean$lean_lot_apply
one <- compiler::cmpfun(function(k) {
  i <- k$input
  lean_lot_apply(k$book, lean_lot_input(i$operation[[1L]], i$pos, i$side, i$qty, i$price, i$fee,
                                        i$position_before, i$realized_model_pnl))
})
drive <- compiler::cmpfun(function(n) for (r in seq_len(n)) for (k in calls) one(k))
stopifnot(all(vapply(calls, function(k) identical(one(k), k$expected), logical(1))))

t0 <- proc.time()[["elapsed"]]; drive(1L); pass <- proc.time()[["elapsed"]] - t0
reps <- max(1L, as.integer(ceiling(seconds / max(pass, 0.01))))
# Windows samples on its 15.625 ms timer tick (rounding a requested
# interval up to whole ticks) but labels each sample with the requested
# interval, so 2 ms reported an eighth of the time and 20 ms (two ticks)
# about two thirds. One tick keeps summaryRprof's seconds close to the
# elapsed time printed beside them; the shares are unaffected either way.
prof <- tempfile(fileext = ".out")
t0 <- proc.time()[["elapsed"]]
Rprof(prof, interval = 0.015625)
drive(reps)
Rprof(NULL)
elapsed <- proc.time()[["elapsed"]] - t0
s <- summaryRprof(prof)
unlink(prof)

self <- s$by.self
total <- s$by.total
fns <- union(rownames(total), rownames(self))
out <- data.frame(
  fn = gsub('"', "", fns),
  self_pct = round(ifelse(fns %in% rownames(self), self[fns, "self.pct"], 0), 1),
  total_pct = round(ifelse(fns %in% rownames(total), total[fns, "total.pct"], 0), 1)
)
out <- out[order(-out$self_pct, -out$total_pct), ]
out <- out[out$self_pct >= 0.5 | grepl("^lean_", out$fn), ]
# base::pmax() and pmin() are R closures that check their arguments with
# vapply(); their vapply, FUN, match.fun and isTRUE samples are that wrapper.
cat(sprintf("calls %d, reps %d, elapsed %.1f s, sampled %.1f s, interval %.3f s\n", length(calls), reps, elapsed,
            s$sampling.time, s$sample.interval))
print(out[c("fn", "self_pct", "total_pct")], row.names = FALSE)
dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(out[c("fn", "self_pct", "total_pct")], out_csv, row.names = FALSE)
