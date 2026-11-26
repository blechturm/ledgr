# Cut 25 decision 2 (LDG-3268): LTB-0566 must fail on two faulted rewrites
# of ledgr_utc_parse_character(): one without the hour/minute/second range
# check (--fault=hms), one parsing date-only strings in the session's local
# time (--fault=localdate; run under a non-UTC TZ). --fault=none runs the
# real function. Prints each block's result and WITNESS FAIL or PASS.
#
#   Rscript utc_witness.R --source=<tree> --fault=<none|hms|localdate>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  tree <- arg("source")
  fault <- arg("fault")
  if (identical(fault, "localdate")) Sys.setenv(TZ = "Europe/Vienna")
  pkgload::load_all(tree, quiet = TRUE, compile = FALSE)
  ns <- asNamespace("ledgr")
  src <- deparse(ns$ledgr_utc_parse_character, width.cutoff = 500L)
  edit <- function(pattern, replacement) {
    hit <- grep(pattern, src, fixed = TRUE)
    if (length(hit) != 1L) stop("fault anchor not found once: ", pattern)
    src[[hit]] <<- sub(pattern, replacement, src[[hit]], fixed = TRUE)
  }
  if (identical(fault, "hms")) {
    edit("any(h > 23L | m > 59L | s > 59L)", "FALSE")
  } else if (identical(fault, "localdate")) {
    edit("format(d, \"%Y-%m-%d\")", "format(as.POSIXct(x[date_only], format = \"%Y-%m-%d\"), \"%Y-%m-%d\")")
    edit("iso[date_only] <- sprintf(\"%sT00:00:00Z\", ", "iso[date_only] <- sprintf(\"%s\", ")
    edit("out <- as.POSIXct(iso, tz = \"UTC\", format = \"%Y-%m-%dT%H:%M:%SZ\")",
         "out <- as.POSIXct(ifelse(date_only, NA, iso), tz = \"UTC\", format = \"%Y-%m-%dT%H:%M:%SZ\"); out[date_only] <- as.POSIXct(iso[date_only], format = \"%Y-%m-%d\")")
  } else if (!identical(fault, "none")) {
    stop("unknown fault")
  }
  f <- eval(parse(text = src), envir = ns)
  environment(f) <- ns
  unlockBinding("ledgr_utc_parse_character", ns)
  assign("ledgr_utc_parse_character", f, envir = ns)
  cat("fault", fault, "TZ", Sys.getenv("TZ"), "\n")
  r <- testthat::test_file(file.path(tree, "tests", "testthat", "test-timestamp.R"),
                           reporter = "silent", package = "ledgr", load_package = "none")
  failed <- 0L
  for (res in r) {
    bad <- Filter(function(e) !inherits(e, c("expectation_success", "expectation_skip")), res$results)
    failed <- failed + length(bad)
    cat(sprintf("%s | %s | failed %d of %d\n", if (length(bad)) "FAIL" else "ok", res$test, length(bad), length(res$results)))
    for (e in utils::head(bad, 3L)) cat("   NOT OK:", substr(gsub("\\s+", " ", conditionMessage(e)), 1L, 160L), "\n")
  }
  cat(if (failed > 0L) "WITNESS FAIL" else "WITNESS PASS", "\n")
})
