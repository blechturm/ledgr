# Protocol ws2-timing-1 (LDG-3156): workload smoke. NOT TIMING EVIDENCE.
#
# Shows that every cell's workload runs on an installed ledgr: installs one
# commit (git archive, R CMD INSTALL into a temporary library, commit stamp,
# as runner.R does), then runs the harness's own measure.R once per cell,
# one arm, no pairing and no host enforcement. The harness requires at least
# eight pairs for a window, so a one-pair window is not possible; this
# exercises the same measurement process instead. Writes
# demo/ws2_timing_1_smoke.csv; exits 1 unless every cell is ok.
#
# Usage: Rscript dev/bench/timing/demo/ws2_timing_1_smoke.R [--commit=<ref>]

here <- normalizePath(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])),
  winslash = "/")
harness <- dirname(here)
source(file.path(harness, "host.R"))
source(file.path(harness, "protocol.R"))
repo <- normalizePath(file.path(harness, "..", "..", ".."), winslash = "/")
opt <- timing_args()
commit <- system2("git", c("-C", shQuote(repo), "rev-parse", paste0(opt("commit", "HEAD"), "^{commit}")), stdout = TRUE)
protocol <- timing_read_protocol(file.path(harness, "protocols", "ws2-timing-1"))
stopifnot(!length(protocol$problems))

dir <- file.path(tempdir(), "arm")
dir.create(file.path(dir, "lib"), recursive = TRUE)
system2("git", c("-C", shQuote(repo), "archive", "--format=zip", "-o", shQuote(file.path(dir, "tree.zip")), commit))
utils::unzip(file.path(dir, "tree.zip"), exdir = file.path(dir, "src"))
status <- system2(file.path(R.home("bin"), "R"), c("CMD", "INSTALL", "--no-docs", "--no-html",
  paste0("--library=", shQuote(file.path(dir, "lib"))), shQuote(file.path(dir, "src"))),
  stdout = file.path(dir, "install.log"), stderr = file.path(dir, "install.log"))
stopifnot(identical(as.integer(status), 0L))
writeLines(commit, file.path(dir, "lib", "timing_arm.txt"))

rows <- lapply(seq_len(nrow(protocol$cells)), function(i) {
  out <- file.path(tempdir(), sprintf("row_%02d.csv", i))
  started <- as.numeric(Sys.time())
  system2(file.path(R.home("bin"), "Rscript"), c("--no-init-file", shQuote(file.path(harness, "measure.R")),
    shQuote(paste0("--protocol=", protocol$dir)), shQuote(paste0("--lib=", file.path(dir, "lib"))),
    paste0("--slot=", i), "--pair=1", "--arm=base", shQuote(paste0("--cell=", protocol$cells$cell[[i]])),
    shQuote(paste0("--work=", tempdir())), shQuote(paste0("--out=", out))), stdout = FALSE, stderr = FALSE)
  row <- if (file.exists(out)) timing_read_csv(out) else data.frame(cell = protocol$cells$cell[[i]], outcome = "no row")
  data.frame(cell = protocol$cells$cell[[i]], clock = row$clock %||% NA, outcome = row$outcome,
    timed_seconds = row$seconds %||% NA, process_seconds = sprintf("%.1f", as.numeric(Sys.time()) - started),
    work = row$work %||% NA, error = row$error %||% NA, ledgr_commit = row$ledgr_commit %||% NA)
})
smoke <- do.call(rbind, rows)
smoke$note <- "not timing evidence: one process per cell, no pairing, host not enforced"
utils::write.csv(smoke, file.path(here, "ws2_timing_1_smoke.csv"), row.names = FALSE, fileEncoding = "UTF-8")
print(smoke[c("cell", "outcome", "timed_seconds", "process_seconds", "work")], row.names = FALSE, right = FALSE)
quit(save = "no", status = if (all(smoke$outcome == "ok")) 0L else 1L)
