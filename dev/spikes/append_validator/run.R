# Append-validator spike runner.
#
#   Rscript run.R --pkg=<ledgr source tree at d5b3a151> --out=<dir> [--reps=5]
#
# 1. Parity: ten cases (one accepted block, eight single faults, the fill
#    mark_age gap) through the pinned check and both arms; each arm must
#    return the same value or the same condition class and message. A gutted
#    R arm (no forbidden-evidence rule) runs the same cases and must differ.
# 2. Timing: per block size, the pinned check and both arms, interleaved.

local({
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
  source(file.path(here, "..", "..", "bench", "v0_2_3_ws16_entry", "common.R"))
  assign("av_here", here, envir = globalenv())
})
pkg <- normalizePath(ws16_need("pkg"), winslash = "/")
out <- ws16_out(ws16_need("out"))
reps <- as.integer(ws16_arg("reps", "5"))
commit <- ws16_load_source(pkg)
if (!identical(commit, "d5b3a151")) stop("source tree is not the d5b3a151 pin", call. = FALSE)
source(file.path(av_here, "blocks.R"))
source(file.path(av_here, "arms.R"))
build <- file.path(tempdir(), "av_cpp")
dir.create(build, showWarnings = FALSE)
av_compile_cpp(build)

cols <- ledgr:::ledgr_output_event_columns
base <- av_block(54L)[cols]
prior_ts <- .POSIXct(base$ts_utc[[1L]] - 86400, tz = "UTC")
edit <- function(f) { x <- base; f(x) }
cases <- list(
  accepted = list(rows = base, seq = 1L, ts = prior_ts),
  seq_not_after_prior = list(rows = base, seq = base$event_seq[[1L]], ts = prior_ts),
  ts_before_prior = list(rows = base, seq = 1L, ts = .POSIXct(base$ts_utc[[1L]] + 1, tz = "UTC")),
  empty_instrument = list(rows = edit(function(x) { x$instrument_id[[3L]] <- ""; x }), seq = 1L, ts = prior_ts),
  infinite_cash = list(rows = edit(function(x) { x$cash_delta[[3L]] <- Inf; x }), seq = 1L, ts = prior_ts),
  bad_side = list(rows = edit(function(x) { x$side[[3L]] <- "HOLD"; x }), seq = 1L, ts = prior_ts),
  zero_qty = list(rows = edit(function(x) { x$qty[[3L]] <- 0; x }), seq = 1L, ts = prior_ts),
  cash_not_reconciled = list(rows = edit(function(x) { x$cash_delta[[3L]] <- x$cash_delta[[3L]] + 0.01; x }),
                             seq = 1L, ts = prior_ts),
  evidence_on_fill = list(rows = edit(function(x) { x$source[[3L]] <- "opening_position"; x }),
                          seq = 1L, ts = prior_ts),
  fill_mark_age_accepted = list(rows = edit(function(x) { x$mark_age[[3L]] <- 5L; x }), seq = 1L, ts = prior_ts)
)

outcome <- function(f, case) {
  r <- tryCatch(f(case$rows, prior_event_seq = case$seq, prior_ts_utc = case$ts), error = function(e) e)
  if (inherits(r, "error")) {
    return(list(kind = "refused", detail = paste(paste(class(r), collapse = "/"), conditionMessage(r), sep = ": ")))
  }
  list(kind = "accepted", detail = paste0("event_seq ", r$event_seq[[1L]], "..", utils::tail(r$event_seq, 1L)),
       value = list(r$event_seq, r$ts_utc))
}
arms <- list(r = av_check_r, cpp = av_check_cpp,
             r_gut_no_evidence_rule = function(...) av_check_r(..., gut = TRUE))
parity <- do.call(rbind, lapply(names(cases), function(nm) {
  pin <- outcome(av_pinned, cases[[nm]])
  do.call(rbind, lapply(names(arms), function(a) {
    got <- outcome(arms[[a]], cases[[nm]])
    data.frame(case = nm, arm = a, pinned = pin$kind, arm_outcome = got$kind,
               matches_pinned = identical(pin$kind, got$kind) && identical(pin$detail, got$detail) &&
                 identical(pin$value, got$value),
               pinned_detail = pin$detail)
  }))
}))
ws16_write(parity, file.path(out, "parity.csv"))
print(parity[, 1:5])
if (!all(parity$matches_pinned[parity$arm != "r_gut_no_evidence_rule"])) {
  stop("kill condition: an arm does not match the pinned check", call. = FALSE)
}

# Timing, microseconds per call.
time_per_call <- function(f, k) {
  t0 <- ledgr_time_now()
  for (i in seq_len(k)) f()
  1e6 * ledgr_time_elapsed(t0, ledgr_time_now()) / k
}
sizes <- c(1L, 10L, 54L, 86L, 500L)
calls <- list(pinned = av_pinned, r = av_check_r, cpp = av_check_cpp)
timing <- list()
for (n in sizes) {
  rows <- av_block(n)[cols]
  fns <- lapply(calls, function(f) function() f(rows, prior_event_seq = 1L, prior_ts_utc = prior_ts))
  for (f in fns) for (i in 1:200) f()
  for (r in seq_len(reps)) for (a in names(fns)) {
    timing[[length(timing) + 1L]] <- data.frame(rows = n, arm = a, rep = r,
                                                us_per_call = time_per_call(fns[[a]], 4000L))
  }
}
timing <- do.call(rbind, timing)
summary <- aggregate(us_per_call ~ rows + arm, data = timing, FUN = stats::median)
summary$us_per_call <- round(summary$us_per_call, 1)
ws16_write(timing, file.path(out, "timing_raw.csv"))
ws16_write(summary[order(summary$rows, summary$arm), ], file.path(out, "timing.csv"))
print(summary[order(summary$rows, summary$arm), ])
