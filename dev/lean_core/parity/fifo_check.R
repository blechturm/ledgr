# LDG-3213 checker: reruns the FIFO parity runner into a scratch directory,
# diffs its CSVs against the committed evidence, requires every compared
# call and stream step to be identical in both debug settings, every
# mutation to fail parity and every static call to be allowed, and guards
# package scope.
#
#   Rscript dev/lean_core/parity/fifo_check.R --lib=<pinned library>
#     --captures=<recorder lot captures> --tests=<test-suite captures> --scratch=<empty dir>
#
# Exits with status 1 on any difference or failure.

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) stop("--", name, "= is required", call. = FALSE)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
scratch <- arg("scratch")
dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
if (length(list.files(scratch))) stop("--scratch= must be empty", call. = FALSE)
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
problems <- character()
status <- system2(file.path(R.home("bin"), "Rscript"),
                  c(file.path(here, "fifo_parity.R"), paste0("--lib=", arg("lib")), paste0("--captures=", arg("captures")),
                    paste0("--tests=", arg("tests")), paste0("--out=", scratch)))
if (!identical(status, 0L)) problems <- c(problems, paste("fifo_parity.R exited with status", status))

evidence <- file.path(here, "evidence")
for (f in list.files(evidence, pattern = "^fifo_.*[.]csv$")) {
  a <- readLines(file.path(evidence, f), warn = FALSE)
  b <- if (file.exists(file.path(scratch, f))) readLines(file.path(scratch, f), warn = FALSE) else "<missing>"
  if (!identical(a, b)) problems <- c(problems, paste(f, "differs from the committed evidence"))
}
read <- function(f) utils::read.csv(file.path(scratch, f), stringsAsFactors = FALSE)
if (file.exists(file.path(scratch, "fifo_mutations.csv"))) {
  p <- read("fifo_parity.csv")
  compared <- p$calls - p$mocked_not_compared
  for (col in grep("_debug_", names(p), value = TRUE)) {
    want <- if (startsWith(col, "refusals_")) p$refusals_compared else compared
    short <- p$source[p[[col]] != want]
    if (length(short)) problems <- c(problems, paste(col, "short on", short))
  }
  i <- read("fifo_input_refusals.csv")
  if (i$identical_debug_off[[1L]] != i$calls[[1L]] || any(i$identical_debug_on != i$calls)) {
    problems <- c(problems, "an input refusal differs (economic rules with debug off, all with debug on)")
  }
  s <- read("fifo_streams.csv")
  for (col in c("identical_debug_off", "identical_debug_on")) {
    short <- s$stream[s[[col]] != s$steps]
    if (length(short)) problems <- c(problems, paste("stream", short, col))
  }
  m <- read("fifo_mutations.csv")
  if (nrow(m) != 8L || !all(m$fails_parity))   # six, plus Cut 15's two simple-path mutations problems <- c(problems, paste("mutation passes parity:", m$mutation[!m$fails_parity]))
  k <- read("fifo_calls.csv")
  if (!all(k$allowed)) problems <- c(problems, paste("lean code calls", k$ledgr_function[!k$allowed]))
}

# Content changes against HEAD and new files in package scope; nothing in R/
# may reference dev/lean_core.
paths <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man")
git <- function(...) suppressWarnings(system2("git", c("-C", repo, ...), stdout = TRUE, stderr = FALSE))
scope <- c(git("diff", "--name-only", "HEAD", "--", paths), git("ls-files", "--others", "--exclude-standard", "--", paths))
if (length(scope)) problems <- c(problems, paste("package scope changed:", scope))
if (length(git("grep", "-l", "lean_core", "--", "R"))) problems <- c(problems, "R/ references dev/lean_core")

if (length(problems)) {
  cat("CHECK FAILED\n", paste0("- ", problems, "\n"), sep = "")
  quit(status = 1L)
}
cat("CHECK PASSED: evidence reproduces, every compared call and stream step is identical with debug off and on,",
    "every mutation fails parity, the lean code calls only shared validators, package scope clean\n")
