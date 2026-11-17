# Workstream 40 close review round 1, F2: a census of the pinned test suite's
# ledgr_lot_apply() calls by test file and test, with the capture's own
# wrapper semantics (fifo_capture_tests.R: a call is recorded once per
# return or error; mocked kernel helpers noted), counting instead of saving
# books, plus a digest of each call's book and input so two runs can be
# compared call by call.
#   Rscript fifo_census.R --src=<pinned source archive> --out=<csv>
local({
  arg <- function(n) sub(paste0("^--", n, "="), "", grep(paste0("^--", n, "="), commandArgs(TRUE), value = TRUE)[[1L]])
  assign("src", normalizePath(arg("src"), winslash = "/"), globalenv())
  assign("out", arg("out"), globalenv())
  source("C:/Users/maxth/ledgr-wt/ws40/dev/lean_core/load.R")
  source("C:/Users/maxth/ledgr-wt/ws40/dev/bench/v0_2_3_ws16_entry/common.R")
  lean_core_load(src)
})
ns <- asNamespace("ledgr")
helpers <- c("ledgr_lot_dust_tolerance_rows", "ledgr_lot_add_realized", "ledgr_lot_book_problem",
             "ledgr_accounting_event_error", "ledgr_lot_applied")
originals <- mget(helpers, envir = ns)
skip <- c("ledgr_lot_apply", "ledgr_lot_fill", "ledgr_lot_opening", "ledgr_lot_disposition", "ledgr_lot_apply_blocks")
cur <- new.env()
cur$file <- ""
cur$test <- ""
cols <- c("file", "test", "caller", "mocked", "error", "digest", "time")
rows <- new.env()
rows$n <- 0L
for (cc in cols) assign(cc, character(250000L), envir = rows)
record <- function(book, input, value, error) {
  mocked <- any(!vapply(helpers, function(h) identical(get(h, envir = ns), originals[[h]]), logical(1)))
  k <- rows$n + 1L
  rows$n <- k
  rows$file[k] <- cur$file
  rows$test[k] <- cur$test
  rows$caller[k] <- paste(ws16_caller(skip), collapse = "/")
  rows$mocked[k] <- as.character(mocked)
  rows$error[k] <- as.character(error)
  rows$digest[k] <- digest::digest(list(book, input), algo = "xxhash64")
  rows$time[k] <- format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3")
}
ws16_wrap("ledgr_lot_apply", function(orig) {
  force(orig)
  function(book, input) {
    force(book)
    force(input)
    res <- withCallingHandlers(orig(book, input), error = function(e) record(book, input, NULL, TRUE))
    record(book, input, res, FALSE)
    res
  }
})
Census <- R6::R6Class("Census", inherit = testthat::Reporter, public = list(
  start_file = function(filename) { cur$file <- basename(filename) },
  start_test = function(context, test) { cur$test <- test },
  end_test = function(context, test) { cur$test <- "" }))
res <- testthat::test_dir(file.path(src, "tests", "testthat"), load_package = "none",
  reporter = testthat::MultiReporter$new(list(testthat::SummaryReporter$new(), Census$new())),
  stop_on_failure = FALSE, stop_on_warning = FALSE)
d <- as.data.frame(lapply(stats::setNames(cols, cols), function(cc) get(cc, envir = rows)[seq_len(rows$n)]),
                   stringsAsFactors = FALSE)
utils::write.csv(d, out, row.names = FALSE)
cat("census:", nrow(d), "calls,", sum(d$mocked == "TRUE"), "mocked,", sum(d$error == "TRUE"), "errors, written to", out, "\n")
