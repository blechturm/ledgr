# Rebuilds every numeric table row of summary.md from the result CSVs and
# requires each row verbatim in summary.md (LDG-3221: every number in the
# summary reproduces from the runner's CSVs). Exits 1 on a missing row.
# LDG-3225 adds the Cut 15 section (Cut 14 and Cut 15 directories side by
# side, with input, staleness, signature and required-cell refusals) and
# the rows of cut15_close.md.
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
lc <- cells[cells$arm == "lean", ]
# a required cell without samples prints "unresolved", never a number
us <- function(s, cs) {
  x <- lc[lc$shape == s & lc$cell %in% cs, ]
  if (!nrow(x)) return("0")
  if (any(x$resolution == "unresolved")) return("unresolved")
  as.character(round(sum(x$est_us_per_pulse)))
}
named <- unique(lc$cell[startsWith(lc$cell, "loop: ") & lc$cell != "loop: residual"])
loop_rows <- list("P3 plan" = "P3", "strategy: ledgr callees" = "strategy: ledgr callees", "P2 context build" = "P2 context",
  "P4 FIFO" = "P4 FIFO", "P4 other (fill records, position facts)" = "P4 other", "P5 commit" = "P5",
  "P2 other (output checks)" = "P2 other", "strategy: own work" = "strategy: own work",
  "strategy: call wrapper" = "strategy: call wrapper", "P1 valuation" = "P1", "E advance" = "E advance",
  "loop body, named callees" = named, "loop body, base code (residual)" = "loop: residual")
if (!length(named)) loop_rows[["loop body, named callees"]] <- NULL
for (n in names(loop_rows)) expect <- c(expect, row(n, vapply(shapes, function(s) us(s, loop_rows[[n]]), "")))
for (s in shapes) {
  x <- rep[rep$arm == "lean" & rep$shape == s, ]
  expect <- c(expect, row(label[[s]], round(x$real_median_us), round(x$plain_median_us), f2(x$context_premium_us_per_instrument)))
}
missing <- expect[!expect %in% md]
h1_ok <- grepl(sprintf("%d instruments", h1$instruments), gsub(",", "", paste(md, collapse = " "))) &&
  any(grepl(sprintf("takes %s s against %s s", f2(h1$simple_pin_path_s), f2(h1$simple_bare_ttr_s)), md))
cat(sprintf("%d table rows checked, %d missing; H1 sentence %s\n", length(expect), length(missing), if (h1_ok) "ok" else "MISSING"))
if (length(missing)) cat(paste0("  ", missing, collapse = "\n"), "\n")

# --- Cut 15 close (LDG-3225): Cut 14 and Cut 15 lean cells side by side -------
# Both result directories are named here; each input must exist, the Cut 15
# rerun must be on the dev/lean_core of HEAD (not stale) and must reproduce
# the pin's recorded result signatures, and every required loop cell must be
# present in both. Rows of summary.md's Cut 15 section and of cut15_close.md
# are rebuilt from the two directories.
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
dirs <- c("Cut 14" = file.path(here, "results", "cost_map"), "Cut 15" = file.path(here, "results", "cost_map_cut15"))
fail <- character()
need <- c("cells.csv", "reconcile.csv", "clock_raw.csv", "identity.txt", "rank.csv")
for (v in names(dirs)) {
  gone <- need[!file.exists(file.path(dirs[[v]], need))]
  if (length(gone)) fail <- c(fail, sprintf("%s input missing: %s", v, paste(gone, collapse = ", ")))
}
if (length(fail)) { cat(paste0("  ", fail, collapse = "\n"), "\n"); quit(status = 1L) }
rv <- function(v, f) utils::read.csv(file.path(dirs[[v]], f), stringsAsFactors = FALSE)
ident <- lapply(names(dirs), function(v) {
  x <- readLines(file.path(dirs[[v]], "identity.txt"))
  get <- function(k) { h <- grep(paste0("^", k, ": "), x, value = TRUE); if (length(h)) sub(paste0("^", k, ": "), "", h[[1L]]) else NA_character_ }
  list(head = get("head"), changes = get("dev/lean_core changes against head"))
})
names(ident) <- names(dirs)
# Lean sources (dev/lean_core without the parity harness) of two commits, or
# of a commit and the checked-out tree, compared.
lean_same <- function(a, b = NULL) {
  identical(as.integer(system2("git", c("-C", repo, "diff", "--quiet", a, b, "--", "dev/lean_core",
                                        ":(exclude)dev/lean_core/parity"))), 0L)
}
# A historical record is verified against its recorded source (Cut 16,
# LDG-3229): the Cut 15 rerun ran on a clean dev/lean_core whose lean
# sources are those of workstream 32's final code, 4cdc01da (LDG-3225's
# evidence). Only the final Cut 16 rerun is checked against the checked-out
# tree (below).
if (!identical(ident[["Cut 15"]]$changes, "0")) fail <- c(fail, "Cut 15 rerun ran with uncommitted dev/lean_core changes")
if (!lean_same(ident[["Cut 15"]]$head, "4cdc01da")) {
  fail <- c(fail, "Cut 15 rerun is stale: its lean sources are not its recorded source 4cdc01da")
}
# signatures: every Cut 15 lean digest equals the recorded pin digest per shape
pin_raw <- rv("Cut 14", "clock_raw.csv"); new_raw <- rv("Cut 15", "clock_raw.csv")
for (s in shapes) {
  p <- unique(pin_raw$digest[pin_raw$arm == "pin" & pin_raw$shape == s])
  l <- unique(new_raw$digest[new_raw$arm == "lean" & new_raw$shape == s])
  if (length(p) != 1L || length(l) != 1L || !identical(p, l)) fail <- c(fail, sprintf("signature mismatch or missing on %s", s))
}
required <- c("P3 plan" = "P3", "strategy: ledgr callees" = "strategy: ledgr callees", "P2 context build" = "P2 context",
  "P4 FIFO" = "P4 FIFO", "P4 other (fill records, position facts)" = "P4 other", "P5 commit" = "P5",
  "P2 other (output checks)" = "P2 other", "strategy: own work" = "strategy: own work",
  "strategy: call wrapper" = "strategy: call wrapper", "P1 valuation" = "P1", "E advance" = "E advance",
  "loop body, base code (residual)" = "loop: residual")
vc <- lapply(names(dirs), function(v) { x <- rv(v, "cells.csv"); x[x$arm == "lean", ] })
vr <- lapply(names(dirs), function(v) { x <- rv(v, "reconcile.csv"); x[x$arm == "lean", ] })
names(vc) <- names(vr) <- names(dirs)
for (v in names(dirs)) {
  # rank.csv must be cost_rank.R's output on these cells and clocks: rebuilt
  # and compared whole (rows, owners, shares, order; close review round 1,
  # finding 4).
  rebuilt <- tempfile(fileext = ".csv")
  system2(file.path(R.home("bin"), "Rscript"), c(file.path(here, "cost_rank.R"), paste0("--in=", dirs[[v]]),
                                                 paste0("--out=", rebuilt)), stdout = FALSE)
  same_rank <- file.exists(rebuilt) &&
    identical(sub("$", "", readLines(rebuilt, warn = FALSE)), sub("$", "", readLines(file.path(dirs[[v]], "rank.csv"), warn = FALSE)))
  for (s in shapes) {
    if (!all(required %in% vc[[v]]$cell[vc[[v]]$shape == s])) fail <- c(fail, sprintf("%s lacks a required cell on %s", v, s))
    if (!s %in% vr[[v]]$shape) fail <- c(fail, sprintf("%s lacks the %s clocks", v, s))
  }
  if (!same_rank) fail <- c(fail, sprintf("%s rank.csv is not cost_rank.R's output on its cells", v))
}
if (length(fail)) { cat(paste0("  ", fail, collapse = "\n"), "\n"); quit(status = 1L) }
cell_text <- function(v, s, cell) {
  x <- vc[[v]][vc[[v]]$shape == s & vc[[v]]$cell == cell, ]
  c(if (x$resolution == "unresolved") "unresolved" else as.character(round(x$est_us_per_pulse)), x$samples, x$resolution)
}
us_pp <- function(v, s) round(1e6 * vr[[v]]$loop_median_s[vr[[v]]$shape == s] / pulses[[s]])
expect15 <- character()
for (s in shapes) {
  a <- vr[["Cut 14"]][vr[["Cut 14"]]$shape == s, ]; b <- vr[["Cut 15"]][vr[["Cut 15"]]$shape == s, ]
  expect15 <- c(expect15, row(label[[s]], f2(a$run_median_s), f2(b$run_median_s), f2(a$loop_median_s), f2(b$loop_median_s),
                              us_pp("Cut 14", s), us_pp("Cut 15", s), a$loop_samples, b$loop_samples))
  for (n in names(required)) expect15 <- c(expect15, row(label[[s]], n, cell_text("Cut 14", s, required[[n]]),
                                                         cell_text("Cut 15", s, required[[n]])))
}
for (v in names(dirs)) expect15 <- c(expect15, sprintf("- %s: `%s`, head %s, dev/lean_core changes against head %s", v,
  sub(paste0("^", repo, "/"), "", dirs[[v]]), substr(ident[[v]]$head, 1L, 8L), ident[[v]]$changes))
missing15 <- expect15[!expect15 %in% md]
# cut15_close.md: the final loop against Cut 14, the skeleton floor and R-floor stage 2
page <- readLines(file.path(here, "cut15_close.md"))
skel <- utils::read.csv(file.path(repo, "dev", "spikes", "skeleton_floor", "evidence", "timings.csv"), stringsAsFactors = FALSE)
rfloor <- c("10x7200" = 26, "20x23400" = 29, "500x1260" = 103)   # dev/spikes/r_floor/README.md, trace-difference row
rfloor_ok <- any(grepl("| or + trace difference only (WS15) | 26 | 29 | 103 |", readLines(file.path(repo, "dev", "spikes", "r_floor", "README.md")), fixed = TRUE))
expect_page <- character()
for (s in names(rfloor)) {
  sk <- round(skel$us_per_pulse[skel$shape == s & skel$variant == "skeleton"])
  expect_page <- c(expect_page, row(label[[s]], us_pp("Cut 14", s), us_pp("Cut 15", s), sk, rfloor[[s]],
                                    sprintf("%.1f", us_pp("Cut 15", s) / sk), sprintf("%.1f", us_pp("Cut 15", s) / rfloor[[s]])))
}
# PMwR: historical reference (published 2026-10-31, its own run boundary), against the Cut 15 lean run
pmwr <- c("10x7200" = "0.14", "20x23400" = "0.57", "1166x252" = "0.27")
for (s in names(pmwr)) expect_page <- c(expect_page, row(label[[s]], f2(vr[["Cut 15"]]$run_median_s[vr[["Cut 15"]]$shape == s]), pmwr[[s]]))
missing_page <- expect_page[!expect_page %in% page]
cat(sprintf("Cut 15 section: %d rows checked, %d missing; close page: %d rows checked, %d missing; R-floor source %s\n",
            length(expect15), length(missing15), length(expect_page), length(missing_page), if (rfloor_ok) "ok" else "CHANGED"))
if (length(missing15)) cat(paste0("  ", missing15, collapse = "\n"), "\n")
if (length(missing_page)) cat(paste0("  ", missing_page, collapse = "\n"), "\n")
if (length(missing) || !h1_ok || length(missing15) || length(missing_page) || !rfloor_ok) quit(status = 1L)

# --- Cut 16 (LDG-3229, LDG-3231): five workload descriptors ---------------------
# The LDG-3229 baseline is verified against its own recorded source
# (workstream 33's final lean code, bec26da9); the final rerun (LDG-3231)
# is also checked against the checked-out tree. Both must reproduce the
# pin's signatures: Cut 14's pin rows for the crossover shapes and the pin
# capture of results/cost_map_cut16_pin for slice2_10x7200, whose reach
# counts must all be positive.
shapes16 <- c(shapes, "slice2_10x7200")
label16 <- c(label, slice2_10x7200 = "slice2 10 x 7,200")
pulses16 <- c(pulses, slice2_10x7200 = 7200)
cut16 <- list("Cut 16 base" = list(dir = "cost_map_cut16_base", source = "bec26da9", live = FALSE),
              "Cut 16 final" = list(dir = "cost_map_cut16", source = "3998dd58", live = TRUE))
pin_dir <- file.path(here, "results", "cost_map_cut16_pin")
fail16 <- character()
for (v in names(cut16)) {
  gone <- need[!file.exists(file.path(here, "results", cut16[[v]]$dir, need))]
  if (length(gone)) fail16 <- c(fail16, sprintf("%s input missing: %s", v, paste(gone, collapse = ", ")))
}
gone <- c("clock_raw.csv", "identity.txt", "reach.csv")[!file.exists(file.path(pin_dir, c("clock_raw.csv", "identity.txt", "reach.csv")))]
if (length(gone)) fail16 <- c(fail16, sprintf("pin capture input missing: %s", paste(gone, collapse = ", ")))
if (length(fail16)) { cat(paste0("  ", fail16, collapse = "\n"), "\n"); quit(status = 1L) }
rd16 <- function(v, f) utils::read.csv(file.path(here, "results", cut16[[v]]$dir, f), stringsAsFactors = FALSE)
id16 <- function(dir) {
  x <- readLines(file.path(dir, "identity.txt"))
  get <- function(k) { h <- grep(paste0("^", k, ": "), x, value = TRUE); if (length(h)) sub(paste0("^", k, ": "), "", h[[1L]]) else NA_character_ }
  list(head = get("head"), changes = get("dev/lean_core changes against head"))
}
pin_cap <- utils::read.csv(file.path(pin_dir, "clock_raw.csv"), stringsAsFactors = FALSE)
pin_digest <- c(vapply(shapes, function(s) paste(unique(pin_raw$digest[pin_raw$arm == "pin" & pin_raw$shape == s]), collapse = "+"), ""),
                slice2_10x7200 = paste(unique(pin_cap$digest[pin_cap$arm == "pin" & pin_cap$shape == "slice2_10x7200"]), collapse = "+"))
reach <- utils::read.csv(file.path(pin_dir, "reach.csv"), stringsAsFactors = FALSE)
if (!nrow(reach) || !all(reach$count > 0)) fail16 <- c(fail16, "slice2_10x7200 reach not established on the pin")
required16 <- function(s) c(required, if (s == "slice2_10x7200") c("P2 risk" = "P2 risk", "P2 sizing" = "P2 sizing"))
for (v in names(cut16)) {
  dir <- file.path(here, "results", cut16[[v]]$dir)
  ii <- id16(dir)
  if (!identical(ii$changes, "0")) fail16 <- c(fail16, sprintf("%s ran with uncommitted dev/lean_core changes", v))
  if (is.na(ii$head) || !lean_same(ii$head, cut16[[v]]$source)) {
    fail16 <- c(fail16, sprintf("%s is stale: its lean sources are not its recorded source %s", v, cut16[[v]]$source))
  }
  if (isTRUE(cut16[[v]]$live) && !lean_same(ii$head)) fail16 <- c(fail16, sprintf("%s is stale: dev/lean_core changed since its head", v))
  raw <- rd16(v, "clock_raw.csv")
  for (s in shapes16) {
    l <- unique(raw$digest[raw$arm == "lean" & raw$shape == s])
    if (length(l) != 1L || !identical(l, pin_digest[[s]])) fail16 <- c(fail16, sprintf("%s signature mismatch or missing on %s", v, s))
  }
  x <- rd16(v, "cells.csv"); x <- x[x$arm == "lean", ]
  r <- rd16(v, "reconcile.csv"); r <- r[r$arm == "lean", ]
  for (s in shapes16) {
    if (!all(required16(s) %in% x$cell[x$shape == s])) fail16 <- c(fail16, sprintf("%s lacks a required cell on %s", v, s))
    if (!s %in% r$shape) fail16 <- c(fail16, sprintf("%s lacks the %s clocks", v, s))
  }
  rebuilt <- tempfile(fileext = ".csv")
  system2(file.path(R.home("bin"), "Rscript"), c(file.path(here, "cost_rank.R"), paste0("--in=", dir), paste0("--out=", rebuilt)),
          stdout = FALSE)
  if (!file.exists(rebuilt) || !identical(readLines(rebuilt, warn = FALSE), readLines(file.path(dir, "rank.csv"), warn = FALSE))) {
    fail16 <- c(fail16, sprintf("%s rank.csv is not cost_rank.R's output on its cells", v))
  }
}
if (length(fail16)) { cat(paste0("  ", fail16, collapse = "\n"), "\n"); quit(status = 1L) }
pct <- function(x) if (is.na(x)) "unresolved" else sprintf("%.1f", 100 * x)
expect16 <- character()
for (v in names(cut16)) {
  dir <- file.path(here, "results", cut16[[v]]$dir)
  ii <- id16(dir)
  expect16 <- c(expect16, sprintf("- %s: `%s`, head %s, dev/lean_core changes against head %s, lean sources of %s", v,
    sub(paste0("^", repo, "/"), "", dir), substr(ii$head, 1L, 8L), ii$changes, cut16[[v]]$source))
  x <- rd16(v, "cells.csv"); x <- x[x$arm == "lean", ]
  r <- rd16(v, "reconcile.csv"); r <- r[r$arm == "lean", ]
  for (s in shapes16) {
    rr <- r[r$shape == s, ]
    expect16 <- c(expect16, row(v, label16[[s]], f2(rr$run_median_s), f2(rr$loop_median_s),
                                round(1e6 * rr$loop_median_s / pulses16[[s]]), rr$loop_samples))
    for (n in names(required16(s))) {
      cx <- x[x$shape == s & x$cell == required16(s)[[n]], ]
      expect16 <- c(expect16, row(v, label16[[s]], n,
        if (cx$resolution == "unresolved") "unresolved" else as.character(round(cx$est_us_per_pulse)),
        pct(cx$share_of_loop), cx$samples, cx$resolution))
    }
  }
}
pc <- stats::aggregate(cbind(run_s, loop_s) ~ shape, pin_cap[pin_cap$arm == "pin", ], stats::median)
expect16 <- c(expect16, row("slice2 10 x 7,200, pin", f2(pc$run_s), f2(pc$loop_s), round(1e6 * pc$loop_s / 7200),
                            paste(sprintf("%s %d", reach$check, as.integer(reach$count)), collapse = ", ")))
missing16 <- expect16[!expect16 %in% md]
cat(sprintf("Cut 16 section: %d rows checked, %d missing\n", length(expect16), length(missing16)))
if (length(missing16)) { cat(paste0("  ", missing16, collapse = "\n"), "\n"); quit(status = 1L) }
