# Shared test helper for the LDG-3280 remaps (remap_demo.R copies it into
# every scratch tests/testthat). Cut 28 adds it to tests/ with the switch;
# its directory then becomes the package's R/.
#
# ledgr_test_candidate_source(name): the source of the one function named
# `name` in the candidate fold's files, defined at top level or nested (the
# lean stages are closures inside lean_fold_envelope_plain), deparsed without
# comments as deparse() of the function would give it.
ledgr_test_candidate_source <- function(name, dir = getOption("ledgr.candidate_lean")) {
  if (is.null(dir)) stop("ledgr_test_candidate_source: option ledgr.candidate_lean is not set", call. = FALSE)
  hits <- character()
  find <- function(e) {
    if (!is.call(e)) return(invisible(NULL))
    if (identical(e[[1L]], as.name("<-")) && identical(e[[2L]], as.name(name)) &&
        is.call(e[[3L]]) && identical(e[[3L]][[1L]], as.name("function"))) {
      hits <<- c(hits, paste(deparse(e[[3L]], width.cutoff = 500L), collapse = "\n"))
    }
    args <- as.list(e)[-1L]
    for (k in seq_along(args)) if (!identical(args[[k]], quote(expr = ))) find(args[[k]])
    invisible(NULL)
  }
  for (f in list.files(dir, pattern = "[.]R$", full.names = TRUE)) {
    for (e in parse(f, keep.source = FALSE)) find(e)
  }
  if (length(hits) != 1L) {
    stop("ledgr_test_candidate_source: ", name, " is defined ", length(hits), " times", call. = FALSE)
  }
  hits
}
