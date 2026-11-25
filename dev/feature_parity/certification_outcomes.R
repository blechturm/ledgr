# Cut 24 stage 2 (LDG-3259): records the certification outcome of every
# witness in tests/testthat/helper-cut24-certification.R on one installed
# library. Run on the cut base to freeze the expected outcomes in
# tests/testthat/fixtures/cut24-certification-outcomes.csv (--write); run on
# a candidate to write its outcomes beside it (--out) for review.
#
#   Rscript certification_outcomes.R --lib=<library> (--write | --out=<csv>)
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) {
    hit <- grep(paste0("^--", name, "(=|$)"), argv, value = TRUE)
    if (!length(hit)) return(NULL)
    if (!grepl("=", hit[[1L]], fixed = TRUE)) return(TRUE)
    sub(paste0("^--", name, "="), "", hit[[1L]])
  }
  suppressPackageStartupMessages(library(ledgr, lib.loc = normalizePath(arg("lib"), winslash = "/")))
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  repo <- normalizePath(file.path(here, "..", ".."), winslash = "/")
  source(file.path(repo, "tests/testthat/helper-cut24-certification.R"), local = TRUE)
  out <- cut24_certification_outcomes()
  path <- if (isTRUE(arg("write"))) file.path(repo, "tests/testthat/fixtures/cut24-certification-outcomes.csv") else arg("out")
  utils::write.csv(out, path, row.names = FALSE)
  print(table(out$outcome, out$certification, useNA = "ifany"))
  print(out[!grepl("^row:", out$witness), c("witness", "outcome", "certification", "kind", "refusal_class")], row.names = FALSE)
})
