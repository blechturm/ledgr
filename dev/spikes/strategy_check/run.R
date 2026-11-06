# Strategy-check spike runner.
#
#   Rscript run.R --pkg=<ledgr source tree at d5b3a151> --out=<dir> [--reps=5]
#
# 1. Parity: ten cases through the pinned check and both arms; each arm must
#    return an identical value or raise the same class and message. The
#    trusted-universe arm is expected to differ only on the invalid-universe
#    case. A gutted arm without the finiteness rule must differ.
# 2. Timing per universe size, targets in universe order and shuffled.

local({
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
  source(file.path(here, "..", "..", "bench", "v0_2_3_ws16_entry", "common.R"))
  assign("sc_here", here, envir = globalenv())
})
pkg <- normalizePath(ws16_need("pkg"), winslash = "/")
out <- ws16_out(ws16_need("out"))
reps <- as.integer(ws16_arg("reps", "5"))
commit <- ws16_load_source(pkg)
if (!identical(commit, "d5b3a151")) stop("source tree is not the d5b3a151 pin", call. = FALSE)
source(file.path(sc_here, "arms.R"))

pinned <- function(t, u) ledgr_validate_strategy_targets(t, u, allow_empty = TRUE)
arms <- list(
  same_rules = function(t, u) sc_check(t, u, allow_empty = TRUE),
  trusted_universe = function(t, u) sc_check(t, u, allow_empty = TRUE, trust_universe = TRUE),
  gut_no_finite_rule = function(t, u) sc_check(t, u, allow_empty = TRUE, gut = TRUE))

universe <- sprintf("P%04d", 1:500)
set.seed(1L)
qty <- round(stats::runif(500, -100, 100))
ordered <- stats::setNames(qty, universe)
shuffled <- ordered[sample(500)]
classed <- structure(ordered, class = "ledgr_target", sizing_evidence = list(n = 1L))
cases <- list(
  in_order = list(t = ordered, u = universe),
  shuffled = list(t = shuffled, u = universe),
  ledgr_target_with_attribute = list(t = classed, u = universe),
  missing_instrument = list(t = ordered[-7L], u = universe),
  extra_instrument = list(t = c(ordered, P9999 = 1), u = universe),
  duplicate_name = list(t = stats::setNames(qty, replace(universe, 2L, "P0001")), u = universe),
  missing_value = list(t = replace(ordered, 3L, NA_real_), u = universe),
  infinite_value = list(t = replace(ordered, 3L, Inf), u = universe),
  not_numeric = list(t = stats::setNames(as.character(qty), universe), u = universe),
  invalid_universe = list(t = ordered, u = replace(universe, 2L, "P0001"))
)
outcome <- function(f, case) {
  r <- tryCatch(f(case$t, case$u), error = function(e) e)
  if (inherits(r, "error")) {
    return(list(kind = "refused", detail = paste(paste(class(r), collapse = "/"), conditionMessage(r), sep = ": ")))
  }
  list(kind = "accepted", detail = "", value = r)
}
parity <- do.call(rbind, lapply(names(cases), function(nm) {
  pin <- outcome(pinned, cases[[nm]])
  do.call(rbind, lapply(names(arms), function(a) {
    got <- outcome(arms[[a]], cases[[nm]])
    data.frame(case = nm, arm = a, pinned = pin$kind, arm_outcome = got$kind,
               matches_pinned = identical(pin$kind, got$kind) && identical(pin$detail, got$detail) &&
                 identical(pin$value, got$value))
  }))
}))
ws16_write(parity, file.path(out, "parity.csv"))
print(parity)
expected <- !(parity$arm == "trusted_universe" & parity$case == "invalid_universe") &
  !(parity$arm == "gut_no_finite_rule" & parity$case %in% c("missing_value", "infinite_value"))
if (!all(parity$matches_pinned == expected)) stop("kill condition: unexpected parity outcome", call. = FALSE)

# Timing, microseconds per call.
time_per_call <- function(f, k) {
  t0 <- ledgr_time_now()
  for (i in seq_len(k)) f()
  1e6 * ledgr_time_elapsed(t0, ledgr_time_now()) / k
}
calls <- c(pinned = pinned, arms[c("same_rules", "trusted_universe")])
timing <- list()
for (n in c(10L, 40L, 500L, 5000L)) {
  u <- sprintf("P%05d", seq_len(n))
  t_in <- stats::setNames(round(stats::runif(n, -100, 100)), u)
  t_sh <- t_in[sample(n)]
  k <- c(`10` = 20000L, `40` = 10000L, `500` = 2000L, `5000` = 300L)[[as.character(n)]]
  for (order in c("in_order", "shuffled")) {
    t <- if (identical(order, "in_order")) t_in else t_sh
    fns <- lapply(calls, function(f) function() f(t, u))
    for (f in fns) for (i in 1:50) f()
    for (r in seq_len(reps)) for (a in names(fns)) {
      timing[[length(timing) + 1L]] <- data.frame(n = n, order = order, arm = a, rep = r,
                                                  us_per_call = time_per_call(fns[[a]], k))
    }
  }
}
timing <- do.call(rbind, timing)
summary <- aggregate(us_per_call ~ n + order + arm, data = timing, FUN = stats::median)
summary$us_per_call <- round(summary$us_per_call, 1)
summary <- summary[order(summary$n, summary$order, summary$arm), ]
ws16_write(timing, file.path(out, "timing_raw.csv"))
ws16_write(summary, file.path(out, "timing.csv"))
print(summary)
