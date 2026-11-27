# Captures every ledgr_lot_apply() call the pinned test suite makes (LDG-3213).
#
#   Rscript dev/lean_core/parity/fifo_capture_tests.R --src=<pinned source archive> --out=<dir>
#
# Loads the pinned source archive (lean_core_load refuses any other build),
# wraps the namespace's ledgr_lot_apply as the WS16 FIFO census did
# (dev/bench/v0_2_3_ws16_entry/fifo_census.R), runs the whole suite in this
# process and writes the calls in chunks: book, input, the value or the
# condition's class and message, the caller, and the names of kernel helpers
# a test had mocked at that moment (those calls test the oracle's own
# instrumentation and are reported, not compared). Tests that start other R
# processes are not observed. Captures are large and never committed.
#
# Cut 22 decision 8 (the maintainer's disposition of Cut 21 F2): the capture
# leaves out test-rng-isolation.R (its tests check unseeded runs and sweeps,
# so their lot calls change from run to run; the file is excluded here only,
# never from package testing), copies each book and input at the call (a
# test may write a book by reference after the call), and records with every
# call its test file, its test and the xxhash64 digest of the call-time book
# and input, so fifo_population.R can compare two captures key by key.

local({
  arg <- function(n) sub(paste0("^--", n, "="), "", grep(paste0("^--", n, "="), commandArgs(TRUE), value = TRUE)[[1L]])
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
  assign("src", normalizePath(arg("src"), winslash = "/"), globalenv())
  assign("out", arg("out"), globalenv())
  source(file.path(here, "..", "load.R"))
  source(file.path(here, "..", "..", "bench", "v0_2_3_ws16_entry", "common.R"))
  lean_core_load(src)
})
dir.create(out, recursive = TRUE, showWarnings = FALSE)
ns <- asNamespace("ledgr")
helpers <- c("ledgr_lot_dust_tolerance_rows", "ledgr_lot_add_realized", "ledgr_lot_book_problem",
             "ledgr_accounting_event_error", "ledgr_lot_applied")
originals <- mget(helpers, envir = ns)
skip <- c("ledgr_lot_apply", "ledgr_lot_fill", "ledgr_lot_opening", "ledgr_lot_disposition",
          "ledgr_lot_apply_blocks")

excluded_files <- "test-rng-isolation.R"
rec <- new.env()
rec$calls <- list()
rec$chunk <- 0L
rec$file <- ""
rec$test <- ""
call_time <- function(x) unserialize(serialize(x, NULL))
flush <- function() {
  if (!length(rec$calls)) return(invisible())
  rec$chunk <- rec$chunk + 1L
  saveRDS(rec$calls, file.path(out, sprintf("tests_%03d.rds", rec$chunk)))
  rec$calls <- list()
}
record <- function(book, input, value) {
  mocked <- helpers[!vapply(helpers, function(h) identical(get(h, envir = ns), originals[[h]]), logical(1))]
  book <- call_time(book)
  input <- call_time(input)
  rec$calls[[length(rec$calls) + 1L]] <- list(book = book, input = input, value = value,
                                              caller = ws16_caller(skip), mocked = mocked,
                                              file = rec$file, test = rec$test,
                                              digest = digest::digest(list(book, input), algo = "xxhash64"))
  if (length(rec$calls) >= 20000L) flush()
}

# The arguments are forced first: an operation wrapper's input is a promise
# whose own refusal (ledgr_lot_input) is not a kernel call. Those refusals
# are recorded by the second wrapper, with their arguments, as `input` calls.
ws16_wrap("ledgr_lot_apply", function(orig) {
  force(orig)
  function(book, input) {
    force(book)
    force(input)
    res <- withCallingHandlers(orig(book, input), error = function(e) {
      record(book, input, list(class = class(e), message = conditionMessage(e)))
    })
    record(book, input, res)
    res
  }
})
ws16_wrap("ledgr_lot_input", function(orig) {
  force(orig)
  function(...) {
    args <- list(...)
    withCallingHandlers(do.call(orig, args), error = function(e) {
      rec$calls[[length(rec$calls) + 1L]] <- list(input_args = args, value = list(class = class(e), message = conditionMessage(e)),
                                                  caller = ws16_caller(skip), mocked = character(),
                                                  file = rec$file, test = rec$test,
                                                  digest = digest::digest(args, algo = "xxhash64"))
    })
  }
})

# The current file and test, from the reporter (as the Cut 21 F2 census did).
Where <- R6::R6Class("Where", inherit = testthat::Reporter, public = list(
  start_file = function(filename) { rec$file <- basename(filename) },
  start_test = function(context, test) { rec$test <- test },
  end_test = function(context, test) { rec$test <- "" }))
t0 <- proc.time()[["elapsed"]]
res <- testthat::test_dir(file.path(src, "tests", "testthat"), load_package = "none",
                          filter = paste0("^(?!", sub("^test-(.*)[.]R$", "\\1", excluded_files), "$)"), perl = TRUE,
                          reporter = testthat::MultiReporter$new(list(testthat::SummaryReporter$new(), Where$new())),
                          stop_on_failure = FALSE, stop_on_warning = FALSE)
flush()
df <- as.data.frame(res)
if (any(basename(df$file) %in% excluded_files)) stop("an excluded file ran: ", paste(excluded_files, collapse = ", "))
utils::write.csv(data.frame(files = length(unique(df$file)), tests = nrow(df), failed = sum(df$failed),
                            errors = sum(df$error), skipped = sum(df$skipped), excluded = paste(excluded_files, collapse = ";"),
                            chunks = rec$chunk,
                            seconds = round(proc.time()[["elapsed"]] - t0)),
                 file.path(out, "tests_outcome.csv"), row.names = FALSE)
cat("captured test-suite lot calls in", rec$chunk, "chunks to", out, "\n")
