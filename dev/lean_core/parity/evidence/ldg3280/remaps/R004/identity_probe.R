# R004-R006 probe: the remapped diagnostic_production_block() returns a block
# identical() to the pin's (ledgr_fold_diagnostic_block) for every fixture
# call of test-availability-diagnostic-production.R.
pin <- "C:/Users/maxth/ledgr-wt/pin-src-7f65733f"
row <- "C:/Users/maxth/ledgr-wt/cut27-dev/dev/lean_core/parity/evidence/ldg3280/remaps/R004"
source("C:/Users/maxth/ledgr-wt/cut27-dev/dev/lean_core/load.R")
invisible(lean_core_load(pin, debug = TRUE))
txt <- paste(readLines(file.path(pin, "tests/testthat/test-availability-diagnostic-production.R"), warn = FALSE), collapse = "\n")
before <- paste(readLines(file.path(row, "before_1.R")), collapse = "\n")
after <- paste(readLines(file.path(row, "after_1.R")), collapse = "\n")
helper_of <- function(text) {
  env <- new.env(parent = globalenv())
  for (e in parse(text = text, keep.source = FALSE)) {
    if (is.call(e) && identical(e[[1L]], as.name("<-")) && identical(e[[2L]], as.name("diagnostic_production_block"))) eval(e, env)
  }
  env$diagnostic_production_block
}
old <- helper_of(txt)
new <- helper_of(sub(before, after, txt, fixed = TRUE))
stopifnot(!identical(body(old), body(new)))
calls <- list(list(2L), list(7L + 3L), list(4096L + 3L), list(1L, first_seq = 3L, id_offset = 2L))
ok <- vapply(calls, function(a) identical(do.call(old, a), do.call(new, a)), logical(1))
out <- data.frame(call = vapply(calls, function(a) paste(deparse(a), collapse = ""), ""), identical = ok)
print(out)
utils::write.csv(out, file.path(row, "identity_probe.csv"), row.names = FALSE)
