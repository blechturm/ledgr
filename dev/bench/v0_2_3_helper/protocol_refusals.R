# Cut 17 (LDG-3232): demonstrates that the shared checker, with
# cut17-helper-1's thresholds, still refuses what decision (6) requires it to
# refuse, and lets only the descriptive whole-run cell's ratio through.
#
#   Rscript dev/bench/v0_2_3_helper/protocol_refusals.R --record=<attempt dir> --out=<csv>
#
# Each case copies the committed attempt to a scratch directory, applies one
# change and runs dev/bench/timing/check.R on the copy:
#   clean                    unchanged copy                         exit 0
#   helper_over_bound        reb_10 candidate seconds x 1.10        exit 1
#   descriptive_slower       run_slice2 candidate seconds x 10      exit 0 (ratio reported, not gated)
#   raw_missing              raw.csv deleted                        exit 1
#   helper_work_differs      one reb_500 slot's work string changed exit 1
#   descriptive_work_differs one run_slice2 slot's work changed     exit 1

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), args, value = TRUE)[[1L]])
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
record <- normalizePath(opt("record"), winslash = "/", mustWork = TRUE)
protocol <- file.path(repo, "dev/bench/timing/protocols/cut17-helper-1")
rscript <- file.path(R.home("bin"), "Rscript.exe")
edit_raw <- function(dir, f) {
  p <- file.path(dir, "raw.csv")
  r <- utils::read.csv(p, colClasses = "character", na.strings = "NA", stringsAsFactors = FALSE)
  utils::write.csv(f(r), p, row.names = FALSE, na = "NA")
}
scale <- function(cell, k) function(r) { i <- r$cell == cell & r$arm == "candidate"; r$seconds[i] <- sprintf("%.17g", as.numeric(r$seconds[i]) * k); r }
rework <- function(cell) function(r) { i <- which(r$cell == cell)[[1L]]; r$work[i] <- paste0(r$work[i], "|changed"); r }
cases <- list(
  clean = list(0L, function(d) NULL),
  helper_over_bound = list(1L, function(d) edit_raw(d, scale("reb_10", 1.10))),
  descriptive_slower = list(0L, function(d) edit_raw(d, scale("run_slice2_10x7200", 10))),
  raw_missing = list(1L, function(d) file.remove(file.path(d, "raw.csv"))),
  helper_work_differs = list(1L, function(d) edit_raw(d, rework("reb_500"))),
  descriptive_work_differs = list(1L, function(d) edit_raw(d, rework("run_slice2_10x7200"))))
rows <- list()
for (n in names(cases)) {
  d <- file.path(tempfile("refusal_"), basename(dirname(record)), basename(record))
  dir.create(dirname(d), recursive = TRUE)
  file.copy(record, dirname(d), recursive = TRUE)
  cases[[n]][[2L]](d)
  log <- tempfile()
  status <- system2(rscript, c(file.path(repo, "dev/bench/timing/check.R"), paste0("--protocol=", protocol), paste0("--record=", d)),
                    stdout = log, stderr = log)
  out <- readLines(log, warn = FALSE)
  verdict <- grep("^CHECK|FAIL|differs|missing", out, value = TRUE)
  rows[[n]] <- data.frame(case = n, expected_exit = cases[[n]][[1L]], exit = status, ok = status == cases[[n]][[1L]],
    output = substr(paste(trimws(utils::head(verdict, 3L)), collapse = " | "), 1L, 300L), stringsAsFactors = FALSE)
  cat(sprintf("%-26s exit %d (want %d) %s\n", n, status, cases[[n]][[1L]], if (status == cases[[n]][[1L]]) "ok" else "WRONG"))
}
res <- do.call(rbind, rows)
utils::write.csv(res, opt("out"), row.names = FALSE)
if (!all(res$ok)) quit(status = 1L)
