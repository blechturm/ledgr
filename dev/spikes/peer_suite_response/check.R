root <- "C:/Users/maxth/Documents/GitHub/ledgr"
base <- file.path(root, "dev/spikes/peer_suite_response")
scratch <- tempfile("peer-response-check-"); dir.create(scratch)
scope <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design")
state <- function() system2("C:/Program Files/Git/cmd/git.exe", c("-C", root,
  "diff", "HEAD", "--", scope), stdout = TRUE)
before <- state()
run <- function(dest, gut = FALSE) system2(file.path(R.home("bin"), "Rscript.exe"),
  c(shQuote(file.path(base, "probe.R")), shQuote(dest), if (gut) "--gut"))
stopifnot(run(scratch) == 0L)
for (file in list.files(file.path(base, "evidence"), pattern = "[.]csv$"))
  stopifnot(identical(readLines(file.path(base, "evidence", file)), readLines(file.path(scratch, file))))
mutant <- file.path(scratch, "gut")
stopifnot(run(mutant, TRUE) == 0L)
stopifnot(!identical(readLines(file.path(base, "evidence/observations.csv")),
  readLines(file.path(mutant, "observations.csv"))), identical(before, state()))
writeLines("Recorded CSVs reproduce; removing the prior-usable-state requirement from the transition-only rule changes the observations diff and is detected; tracked package/design scope unchanged.",
  file.path(base, "evidence/check.txt"))
message("Rerun matches; gutting the transition-only decision rule is detected.")
