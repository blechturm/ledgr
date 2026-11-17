# Cut 22 decision 8 (LDG-3254): compares two independent test-suite FIFO
# captures (fifo_capture_tests.R) call by call. Every recorded call is keyed
# by its test file, its test, its kind (a lot call or an input refusal) and
# the xxhash64 digest of its call-time book and input (an input refusal: of
# its arguments). The two ordered key sequences must be identical: the same
# calls in the same order, so an omitted deterministic call or a changed key
# refuses even when the totals agree. Writes, from the first capture, the
# population by test file (calls, input refusals, mocked calls, errors,
# distinct keys) and a digest of the whole ordered key sequence.
#
#   Rscript dev/lean_core/parity/fifo_population.R --a=<capture dir> --b=<capture dir> --out=<csv>
#
# Exits with status 1 when the populations differ.

arg <- function(name) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) stop("--", name, "= is required", call. = FALSE)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
keys <- function(dir) {
  files <- sort(list.files(dir, "^tests_[0-9]+[.]rds$", full.names = TRUE))
  if (!length(files)) stop("no capture chunks in ", dir, call. = FALSE)
  calls <- do.call(c, lapply(files, readRDS))
  field <- function(name) vapply(calls, function(k) as.character(k[[name]] %||% NA_character_), "")
  if (anyNA(field("digest")) || anyNA(field("file"))) stop(dir, " was not captured with call-time keys", call. = FALSE)
  input <- vapply(calls, function(k) !is.null(k$input_args), logical(1))
  error <- vapply(calls, function(k) is.list(k$value) && !is.null(k$value$class) && !is.null(k$value$message) &&
                    is.null(k$value$book), logical(1))
  data.frame(file = field("file"), test = field("test"), kind = ifelse(input, "input", "lot"),
             digest = field("digest"), mocked = vapply(calls, function(k) length(k$mocked) > 0L, logical(1)),
             error = error, stringsAsFactors = FALSE)
}
`%||%` <- function(a, b) if (is.null(a)) b else a
a <- keys(arg("a"))
b <- keys(arg("b"))
key <- function(x) paste(x$file, x$test, x$kind, x$digest, sep = "\r")
ka <- key(a)
kb <- key(b)
problems <- character()
if (length(ka) != length(kb)) problems <- c(problems, sprintf("totals differ: %d against %d calls", length(ka), length(kb)))
n <- min(length(ka), length(kb))
first <- which(ka[seq_len(n)] != kb[seq_len(n)])
if (length(first)) {
  i <- first[[1L]]
  problems <- c(problems, sprintf("first differing call %d: %s | %s against %s | %s", i, a$file[[i]], a$test[[i]],
                                  b$file[[i]], b$test[[i]]))
}
ta <- table(ka)
tb <- table(kb)
all_keys <- union(names(ta), names(tb))
multiplicity <- sum(as.integer(ta[all_keys]) %in% NA | as.integer(tb[all_keys]) %in% NA |
                      as.integer(ta[all_keys]) != as.integer(tb[all_keys]), na.rm = TRUE)
if (multiplicity > 0L) problems <- c(problems, sprintf("%d keys differ in multiplicity", multiplicity))
excluded <- "test-rng-isolation.R"
if (any(c(a$file, b$file) %in% excluded)) problems <- c(problems, "a capture holds calls of an excluded file")
by_file <- do.call(rbind, lapply(split(a, a$file), function(x) data.frame(
  file = x$file[[1L]], lot_calls = sum(x$kind == "lot"), input_refusals = sum(x$kind == "input"),
  mocked = sum(x$mocked), errors = sum(x$error & x$kind == "lot"), distinct_keys = length(unique(key(x))),
  stringsAsFactors = FALSE)))
by_file <- by_file[order(by_file$file, method = "radix"), ]
total <- data.frame(file = "<all>", lot_calls = sum(a$kind == "lot"), input_refusals = sum(a$kind == "input"),
                    mocked = sum(a$mocked), errors = sum(a$error & a$kind == "lot"), distinct_keys = length(unique(ka)),
                    stringsAsFactors = FALSE)
total$file <- paste0("<all: ", digest::digest(ka, algo = "sha256"), ">")
utils::write.csv(rbind(total, by_file), arg("out"), row.names = FALSE)
if (length(problems)) {
  cat("POPULATIONS DIFFER\n", paste0("- ", problems, "\n"), sep = "")
  quit(status = 1L)
}
cat(sprintf("POPULATIONS IDENTICAL: %d calls (%d lot calls, %d input refusals), %d distinct keys, %d files\n",
            length(ka), sum(a$kind == "lot"), sum(a$kind == "input"), length(unique(ka)), nrow(by_file)))
