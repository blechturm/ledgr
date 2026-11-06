# Probe: what the append check costs per fill block, and where the time goes.
#
#   Rscript probe.R --pkg=<ledgr source tree at d5b3a151> --out=<dir>
#
# Builds real fill publication blocks with the pinned payload builder at
# several sizes, times the pinned append check on each, and line-profiles
# one 54-row block (the fill-heavy median).

options(keep.source = TRUE, keep.source.pkgs = TRUE)
local({
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
  source(file.path(here, "..", "..", "bench", "v0_2_3_ws16_entry", "common.R"))
  source(file.path(here, "blocks.R"))
})
pkg <- normalizePath(ws16_need("pkg"), winslash = "/")
out <- ws16_out(ws16_need("out"))
commit <- ws16_load_source(pkg)
if (!identical(commit, "d5b3a151")) stop("source tree is not the d5b3a151 pin", call. = FALSE)

cols <- ledgr:::ledgr_output_event_columns
time_per_call <- function(f, k = 2000L) {
  for (i in 1:50) f()
  t0 <- ledgr_time_now()
  for (i in seq_len(k)) f()
  1e6 * ledgr_time_elapsed(t0, ledgr_time_now()) / k
}

sizes <- c(1L, 10L, 54L, 86L, 500L)
timing <- do.call(rbind, lapply(sizes, function(n) {
  blk <- av_block(n)
  rows <- blk[cols]
  data.frame(rows = n,
             append_check_us = round(time_per_call(function() {
               ledgr_validate_accounting_append(rows, prior_event_seq = 1L, prior_ts_utc = 0)
             }), 1),
             payload_build_us = round(time_per_call(function() av_block(n)), 1))
}))
ws16_write(timing, file.path(out, "probe_timing.csv"))
print(timing)

# Where the time goes on one 54-row block (shares only: Rprof on Windows
# undercounts wall time, pitfall 8).
rows <- av_block(54L)[cols]
f <- tempfile()
Rprof(f, interval = 0.001, line.profiling = TRUE)
for (i in 1:20000) ledgr_validate_accounting_append(rows, prior_event_seq = 1L, prior_ts_utc = 0)
Rprof(NULL)
s <- summaryRprof(f, lines = "show")$by.self
s <- s[grepl("accounting-replay", rownames(s)), , drop = FALSE]
lines <- data.frame(line = rownames(s), self_pct = round(s$self.pct, 1))
lines <- lines[order(-lines$self_pct), ]
ws16_write(head(lines, 25), file.path(out, "probe_lines.csv"))
print(head(lines, 25))
