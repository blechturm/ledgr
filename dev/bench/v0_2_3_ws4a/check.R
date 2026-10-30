# WS4a case checker: reruns cases into a scratch directory and compares each
# with records/ exactly (CSV bytes and identical() on case.rds; observations
# are not compared). Guards that the product files equal --base and that the
# run left them unchanged. Exit 0 on PASS, 1 on FAIL.
#
# Usage: Rscript check.R [--out=<scratch>] [--records=<dir>] [--cases=C1,C2]
#                        [--gut=<name>] [--base=<git ref, default 953338df>]

source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])), "lib.R"))
source(file.path(ws_dir, "guts.R"))
records <- ws_arg("records", file.path(ws_dir, "records"))
out_dir <- ws_arg("out", file.path(tempdir(), "ws4a_check"))
gut <- ws4a_guts[[ws_arg("gut", "")]]
ids <- ws_arg("cases", gut$case)
ids <- if (is.null(ids)) names(ws_cases) else strsplit(ids, ",", fixed = TRUE)[[1L]]
product <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man")
guard <- function() {
  git <- function(...) system2("git", c("-C", ws_root, ...), stdout = TRUE, stderr = FALSE)
  c(git("diff", "--name-only", ws_arg("base", "953338df"), "--", product),
    grep("^[?][?]", git("status", "--porcelain", "--untracked-files=all", "--", product), value = TRUE))
}
before <- guard()
fails <- sprintf("product file differs from base: %s", before)
for (id in ids) {
  run <- function() ws_run_case(id, file.path(tempdir(), "ws4a_check_work", id))
  ws_write_case(if (is.null(gut)) run() else ws_patches(gut$patch, run()), file.path(out_dir, id))
  files <- function(d) setdiff(list.files(file.path(d, id)), "observed_not_oracle.rds")
  names <- union(files(records), files(out_dir))
  for (f in c(intersect("case_error.csv", names), setdiff(names, c("case_error.csv", "case.rds")), intersect("case.rds", names))) {
    e <- file.path(records, id, f)
    a <- file.path(out_dir, id, f)
    same <- file.exists(e) && file.exists(a) && if (f == "case.rds") identical(readRDS(e), readRDS(a)) else
      identical(readBin(e, "raw", file.size(e)), readBin(a, "raw", file.size(a)))
    if (same) next
    line <- if (grepl("csv$", f) && file.exists(e) && file.exists(a)) {
      el <- readLines(e, warn = FALSE)
      al <- readLines(a, warn = FALSE)
      i <- which(el[seq_len(min(length(el), length(al)))] != al[seq_len(min(length(el), length(al)))])[1L]
      if (is.na(i)) sprintf("rows %d vs %d", length(el), length(al)) else sprintf("line %d\n    expected: %s\n    actual:   %s", i, substr(el[i], 1, 160), substr(al[i], 1, 160))
    } else if (!file.exists(e)) paste("new file", readLines(a, warn = FALSE)[2L]) else if (!file.exists(a)) "missing file" else "objects differ"
    fails <- c(fails, sprintf("%s/%s: %s", id, f, line))
  }
}
fails <- c(fails, sprintf("product file changed during the check: %s", setdiff(guard(), before)))
if (length(fails) == 0L) {
  cat(sprintf("ws4a check: PASS, %d case(s) identical\n", length(ids)))
  quit(status = 0L)
}
cat(sprintf("ws4a check: FAIL%s\n", if (is.null(gut)) "" else paste(" under gut", ws_arg("gut"))), paste0("  ", fails, "\n"), sep = "")
quit(status = 1L)
