# One mechanical remap row demonstrated on scratch candidate code (Cut 27,
# LDG-3280). tests/ is never written: the pin's tests/testthat is copied to a
# scratch package root and the remap is applied there.
#
# A row directory holds:
# - row.csv: `file` (the file patched), optional `run_file` (the test file
#   whose blocks prove it, when `file` is a helper), `note`, `pass` (the
#   remapped block titles that must pass on the candidate, " || "-separated)
#   and `witness` (the titles that must fail on the mutated candidate; empty
#   means no witness run);
# - before_<k>.R and after_<k>.R (k = 1, 2, ...): exact pin text and its
#   replacement; each before text must occur exactly once in the file;
# - mutation.csv (when `witness` is set): `file`, `old`, `new`, one exact
#   whole-line replacement per row in a copy of the candidate's lean files,
#   which breaks the row's claim.
#
# Steps: copy and patch the tests; write remap.patch (git diff --no-index of
# the pin file and the patched file); run suite_driver.R on the candidate
# (its guard included) for that file; then, with a mutation, write the
# mutated candidate and run suite_driver.R --witness=1 on it. result.csv
# records both runs. Exit status 1 if a required pass or failure is missing.
#
#   Rscript remap_demo.R --pin=<pin source archive> --row=<row dir> --out=<dir>
#     [--lean=<candidate dev/lean_core>]
local({
  argv <- commandArgs(TRUE)
  arg <- function(n, d = NULL) { v <- grep(paste0("^--", n, "="), argv, value = TRUE); if (length(v)) sub(paste0("^--", n, "="), "", v[[1L]]) else d }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
  assign("rd", list(here = here, pin = normalizePath(arg("pin"), winslash = "/", mustWork = TRUE),
                    row = normalizePath(arg("row"), winslash = "/", mustWork = TRUE), out = arg("out"),
                    lean = normalizePath(arg("lean", file.path(here, "..")), winslash = "/", mustWork = TRUE)), globalenv())
})
rscript <- file.path(R.home("bin"), "Rscript.exe")
meta <- utils::read.csv(file.path(rd$row, "row.csv"), stringsAsFactors = FALSE, na.strings = character(),
                        colClasses = "character")
stopifnot(nrow(meta) == 1L)
split_titles <- function(s) if (nzchar(s)) trimws(strsplit(s, " || ", fixed = TRUE)[[1L]]) else character()
pass <- split_titles(meta$pass)
witness <- split_titles(meta$witness)
row_id <- basename(rd$row)
work <- file.path(rd$out, row_id)
unlink(work, recursive = TRUE)
dir.create(file.path(work, "root"), recursive = TRUE)

# 1. the scratch tests, patched
invisible(file.copy(file.path(rd$pin, "tests"), file.path(work, "root"), recursive = TRUE))   # tests/ whole: helpers source ../ files
# The shared remap helper (remaps/helper-candidate.R), a Cut 28 test helper.
shared <- file.path(dirname(rd$row), "helper-candidate.R")
if (file.exists(shared)) invisible(file.copy(shared, file.path(work, "root", "tests", "testthat", "helper-candidate.R")))
target <- file.path(work, "root", "tests", "testthat", meta$file)
txt <- paste(readLines(target, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
k <- 1L
while (file.exists(file.path(rd$row, sprintf("before_%d.R", k)))) {
  before <- paste(readLines(file.path(rd$row, sprintf("before_%d.R", k)), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  after <- paste(readLines(file.path(rd$row, sprintf("after_%d.R", k)), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  hits <- gregexpr(before, txt, fixed = TRUE)[[1L]]
  if (sum(hits > 0L) != 1L) stop(row_id, ": before_", k, ".R occurs ", sum(hits > 0L), " times in ", meta$file)
  txt <- sub(before, after, txt, fixed = TRUE)
  k <- k + 1L
}
if (k == 1L) stop(row_id, ": no before_1.R")
writeLines(txt, target, useBytes = TRUE)
patch <- suppressWarnings(system2("git", c("diff", "--no-index", shQuote(file.path(rd$pin, "tests", "testthat", meta$file)),
                                           shQuote(target)), stdout = TRUE))
# Header paths relative to the package root, so the patch applies there.
patch <- gsub(file.path(rd$pin, "tests", "testthat"), "tests/testthat", patch, fixed = TRUE)
patch <- gsub(file.path(work, "root", "tests", "testthat"), "tests/testthat", patch, fixed = TRUE)
writeLines(patch, file.path(rd$row, "remap.patch"))

# 2. the candidate run, then the witness run on a mutated copy
run_file <- if (!is.null(meta$run_file) && nzchar(meta$run_file)) meta$run_file else meta$file
stem <- sub("^test-", "", sub("[.][Rr]$", "", run_file))
drive <- function(lean, out, extra = character()) {
  status <- system2(rscript, c(shQuote(file.path(rd$here, "suite_driver.R")), paste0("--pin=", rd$pin), paste0("--lean=", lean),
                               paste0("--tests=", file.path(work, "root", "tests", "testthat")),
                               paste0("--files=^", stem, "$"), paste0("--out=", out), extra),
                    stdout = file.path(work, paste0(basename(out), ".log")), stderr = file.path(work, paste0(basename(out), ".log")))
  res <- if (file.exists(file.path(out, "tests.csv"))) utils::read.csv(file.path(out, "tests.csv"), stringsAsFactors = FALSE) else NULL
  list(status = status, res = res, smoke = if (file.exists(file.path(out, "smoke.txt"))) readLines(file.path(out, "smoke.txt"))[[1L]] else "")
}
outcome <- function(res, titles) {
  vapply(titles, function(t) {
    r <- res[res$test == t, , drop = FALSE]
    if (nrow(r) != 1L) return(sprintf("missing (%d rows)", nrow(r)))
    if (r$skipped) return("skipped")
    if (r$failed > 0L || isTRUE(r$error)) return("fail")
    if (r$passed > 0L) "pass" else "empty"
  }, character(1))
}
cand <- drive(rd$lean, file.path(work, "candidate"))
cand_out <- if (is.null(cand$res)) rep("no run", length(pass)) else outcome(cand$res, pass)
wit_out <- character()
wit_smoke <- ""
if (length(witness)) {
  mut <- utils::read.csv(file.path(rd$row, "mutation.csv"), stringsAsFactors = FALSE, na.strings = character())
  mroot <- file.path(work, "mutated")
  dir.create(file.path(mroot, "dev", "lean_core"), recursive = TRUE)
  dir.create(file.path(mroot, "dev", "bench", "v0_2_3_ws16_entry"), recursive = TRUE)
  invisible(file.copy(list.files(rd$lean, pattern = "[.]R$", full.names = TRUE), file.path(mroot, "dev", "lean_core")))
  invisible(file.copy(file.path(rd$lean, "..", "bench", "v0_2_3_ws16_entry", "common.R"), file.path(mroot, "dev", "bench", "v0_2_3_ws16_entry")))
  for (j in seq_len(nrow(mut))) {
    p <- file.path(mroot, "dev", "lean_core", mut$file[[j]])
    x <- readLines(p, warn = FALSE, encoding = "UTF-8")
    i <- which(x == mut$old[[j]])
    if (length(i) != 1L) stop(row_id, ": mutation line ", j, " matches ", length(i), " lines of ", mut$file[[j]])
    x[[i]] <- mut$new[[j]]
    writeLines(x, p, useBytes = TRUE)
  }
  wit <- drive(file.path(mroot, "dev", "lean_core"), file.path(work, "witness"), "--witness=1")
  wit_out <- if (is.null(wit$res)) rep("no run", length(witness)) else outcome(wit$res, witness)
  wit_smoke <- wit$smoke
}
ok <- all(cand_out == "pass") && all(wit_out == "fail")
result <- data.frame(row = row_id, file = meta$file,
                     candidate = paste(paste(pass, cand_out, sep = ": "), collapse = " || "),
                     candidate_smoke = cand$smoke,
                     witness = paste(paste(witness, wit_out, sep = ": "), collapse = " || "),
                     witness_smoke = wit_smoke, verdict = if (!ok) "NOT DEMONSTRATED" else if (length(witness)) "DEMONSTRATED" else "DEMONSTRATED (no witness run)",
                     stringsAsFactors = FALSE)
utils::write.csv(result, file.path(rd$row, "result.csv"), row.names = FALSE)
cat(sprintf("%s: %s\n  candidate: %s\n  witness:   %s\n", row_id, result$verdict, result$candidate, result$witness))
quit(save = "no", status = if (ok) 0L else 1L)
