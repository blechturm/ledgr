# Cut 18 (LDG-3234): supported upper bounds for the worklist. Each row
# times the current code of a candidate site on representative inputs, in
# a compiled function, median of microbenchmark repetitions; removing or
# rewriting the site can save at most that. The share uses the plain lean
# loop per pulse of the comparison shapes (statement_cost's clock_loops.csv
# for 10x7200 and slice2; LDG-3231's cost map for 20x23400 and 500x1260).
#
#   Rscript dev/lean_core/parity/cut18_bounds.R --lib=<pinned library> --out=<csv>

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), args, value = TRUE)[[1L]])
suppressPackageStartupMessages(library(ledgr, lib.loc = normalizePath(opt("lib"), winslash = "/")))
ns <- asNamespace("ledgr")
mb <- function(f, times = 20000L) stats::median(microbenchmark::microbenchmark(f(), times = times, unit = "ns")$time) / 1e3
loop_us <- c("10x7200" = 285, "20x23400" = 341, "500x1260" = 571, slice2_10x7200 = 610)
rows <- list()
add <- function(item, n, us, note) rows[[length(rows) + 1L]] <<- data.frame(item = item, instruments = n, us = us, note = note)
for (n in c(10L, 500L)) {
  ids <- sprintf("P%04d", seq_len(n)); m <- min(n, 10L)
  cash_delta <- c(rep(5000, m %/% 2), rep(-4000, m - m %/% 2)); gen <- cash_delta >= 0; rank <- seq_len(m)
  add("W4 affordability priority: order(!generator, id_rank)", n,
      mb(compiler::cmpfun(function() { if (anyNA(gen)) 0 else if (m <= 1L) seq_len(m) else order(!gen, rank, method = "radix") })),
      "the candidates' priority order (m = 10 candidates)")
  st <- if (n == 10L) list(above = logical(n), usable = logical(n)) else list(k = 0L)
  nm <- names(st); fields <- st
  add("W5 state patch name predicate", n, mb(compiler::cmpfun(function() {
    length(st) == 0L || is.null(nm) || anyNA(nm) || !all(nzchar(nm)) || anyDuplicated(nm) ||
      !all(nm %in% names(st)) || !all(nm %in% names(fields)) })), "two asset fields (crossover) or one portfolio field (slice2)")
  q <- c(rep(1, n %/% 2), rep(0, n - n %/% 2)); mk <- seq(50, 60, length.out = n)
  gross <- compiler::cmpfun(function(q, m) { v <- abs(q * m); v[which(q == 0)] <- 0; if (anyNA(v) || !all(is.finite(v))) NA_real_ else sum(v) })
  add("F3 second gross of the strategy targets when no risk step runs", n, mb(function() gross(q, mk)), "lean_gross(sq, close) computed twice")
  add("W6 decode of empty fill reason segments", n,
      mb(compiler::cmpfun(function() ns$ledgr_carrier_segment_text(integer(m), integer(m), integer(), ns$.ledgr_plan_reason_levels))),
      "ledgr_carrier_segment_text() on m = 10 fills without codes")
  add("F1 plan() closure built per lean_plan_pulse call", n,
      mb(compiler::cmpfun(function() { plan <- function(groups, kinds, final_cash) list(groups, kinds, final_cash); plan })),
      "closure creation only")
  add("F2 execution packet list", n, mb(compiler::cmpfun(function() list(exec_ts = 1, has_next = TRUE, open = mk))), "list of three")
  add("F2 run constants rebuilt: seq_len(n), rep(TRUE, n)", n, mb(compiler::cmpfun(function() { seq_len(n); rep(TRUE, n) })), "")
}
out <- do.call(rbind, rows)
for (s in names(loop_us)) out[[paste0("share_", s)]] <- out$us / loop_us[[s]]
utils::write.csv(out, opt("out"), row.names = FALSE)
print(out, digits = 3, row.names = FALSE)
