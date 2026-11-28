# R189 probe (row review F12): the remapped ws4a_3166_plan() returns a plan
# identical() to the pin's ledgr_fold_build_availability_pulse_plan() for
# every fixture call of test-ws4a-carrier.R (four calls, all with the default
# cash), and for two other cash values, with lean debug on and off. This
# replaces the earlier witness run, whose mutation crashed the fixture.
#   Rscript identity_probe.R --lib=<pin library> --pin=<pin source archive>
#     --lean=<candidate dev/lean_core>
argv <- commandArgs(TRUE)
arg <- function(n) sub(paste0("^--", n, "="), "", grep(paste0("^--", n, "="), argv, value = TRUE)[[1L]])
row <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
source(file.path(arg("lean"), "load.R"))
lean <- lean_core_load(arg("lib"), debug = TRUE)
txt <- paste(readLines(file.path(arg("pin"), "tests/testthat/test-ws4a-carrier.R"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
before <- paste(readLines(file.path(row, "before_1.R"), encoding = "UTF-8"), collapse = "\n")
after <- paste(readLines(file.path(row, "after_1.R"), encoding = "UTF-8"), collapse = "\n")
stopifnot(grepl(before, txt, fixed = TRUE))
helper_of <- function(text, parent) {
  env <- new.env(parent = parent)
  env$ws4a_ns <- function() asNamespace("ledgr")
  for (e in parse(text = text, keep.source = FALSE)) {
    if (is.call(e) && identical(e[[1L]], as.name("<-")) && identical(e[[2L]], as.name("ws4a_3166_plan"))) eval(e, env)
  }
  env$ws4a_3166_plan
}
old <- helper_of(txt, asNamespace("ledgr"))
new <- helper_of(sub(before, after, txt, fixed = TRUE), lean)
stopifnot(!identical(body(old), body(new)))
calls <- list(list(), list(cash = 100), list(cash = 1e6))
rows <- list()
for (debug in c(TRUE, FALSE)) {
  lean$.lean_debug <- debug
  for (a in calls) {
    rows[[length(rows) + 1L]] <- data.frame(call = paste(deparse(a), collapse = ""), debug = debug,
      fixture_call = length(a) == 0L, identical = identical(do.call(old, a), do.call(new, a)))
  }
}
out <- do.call(rbind, rows)
print(out)
utils::write.csv(out, file.path(row, "identity_probe.csv"), row.names = FALSE)
stopifnot(all(out$identical))
