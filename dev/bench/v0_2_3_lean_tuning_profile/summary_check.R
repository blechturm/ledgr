# Rebuilds every numeric table row of summary.md from the result CSVs and
# requires each row verbatim in summary.md (LDG-3221: every number in the
# summary reproduces from the runner's CSVs). Exits 1 on a missing row.
#
#   Rscript dev/bench/v0_2_3_lean_tuning_profile/summary_check.R

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
res <- file.path(here, "results", "cost_map")
md <- readLines(file.path(here, "summary.md"))
rd <- function(f) utils::read.csv(file.path(res, f), stringsAsFactors = FALSE)
rec <- rd("reconcile.csv"); cells <- rd("cells.csv"); rank <- rd("rank.csv"); rep <- rd("replay.csv")
h1 <- utils::read.csv(file.path(here, "results", "features_h1.csv"), stringsAsFactors = FALSE)
shapes <- c("10x7200", "20x23400", "500x1260", "1166x252")
label <- c("10x7200" = "10 x 7,200", "20x23400" = "20 x 23,400", "500x1260" = "500 x 1,260", "1166x252" = "1,166 x 252")
pulses <- c("10x7200" = 7200, "20x23400" = 23400, "500x1260" = 1260, "1166x252" = 252)
f2 <- function(x) formatC(x, format = "f", digits = 2)
row <- function(...) paste0("| ", paste(c(...), collapse = " | "), " |")
expect <- character()

for (s in shapes) {
  l <- rec[rec$arm == "lean" & rec$shape == s, ]; p <- rec[rec$arm == "pin" & rec$shape == s, ]
  expect <- c(expect, row(label[[s]], f2(l$run_median_s), f2(l$loop_median_s), round(1e6 * l$loop_median_s / pulses[[s]]),
                          f2(p$run_median_s), f2(p$loop_median_s), f2(l$snapshot_open_median_s)))
}
own <- stats::aggregate(est_run_s ~ shape + owner, rank, sum)
owners <- c("Cut 15 (loop tuning)" = "Cut 15, loop tuning (P1-P5, E, ledgr's strategy work, expansion)",
            "store-write RFC" = "store-write RFC (terminal write, envelope setup and commit)",
            "feature-engine RFC" = "feature-engine RFC (features, projection)",
            "none" = "none (bars substrate, registration, guard, finalise)",
            "none (the strategy's own code)" = "none, the strategy's own code")
for (o in names(owners)) {
  v <- vapply(shapes, function(s) {
    x <- own$est_run_s[own$shape == s & own$owner == o]
    if (o == "none") x <- x - rec$snapshot_open_median_s[rec$arm == "lean" & rec$shape == s]   # the open is outside the run
    f2(x)
  }, "")
  expect <- c(expect, row(owners[[o]], v))
}
lc <- cells[cells$arm == "lean" & !is.na(cells$est_us_per_pulse), ]
us <- function(s, cs) round(sum(lc$est_us_per_pulse[lc$shape == s & lc$cell %in% cs]))
loop_rows <- list("P3 plan" = "P3", "strategy: ledgr callees" = "strategy: ledgr callees", "P2 context build" = "P2 context",
  "P4 FIFO" = "P4 FIFO", "P4 other (fill records, position facts)" = "P4 other", "P5 commit" = "P5",
  "P2 other (output checks)" = "P2 other", "strategy: own work" = "strategy: own work",
  "strategy: call wrapper" = "strategy: call wrapper", "P1, E, residual" = c("P1", "E advance", "loop: residual"))
for (n in names(loop_rows)) expect <- c(expect, row(n, vapply(shapes, function(s) us(s, loop_rows[[n]]), 0)))
for (s in shapes) {
  x <- rep[rep$arm == "lean" & rep$shape == s, ]
  expect <- c(expect, row(label[[s]], round(x$real_median_us), round(x$plain_median_us), f2(x$context_premium_us_per_instrument)))
}
missing <- expect[!expect %in% md]
h1_ok <- grepl(sprintf("%d instruments", h1$instruments), gsub(",", "", paste(md, collapse = " "))) &&
  any(grepl(sprintf("takes %s s against %s s", f2(h1$simple_pin_path_s), f2(h1$simple_bare_ttr_s)), md))
cat(sprintf("%d table rows checked, %d missing; H1 sentence %s\n", length(expect), length(missing), if (h1_ok) "ok" else "MISSING"))
if (length(missing)) cat(paste0("  ", missing, collapse = "\n"), "\n")
if (length(missing) || !h1_ok) quit(status = 1L)
