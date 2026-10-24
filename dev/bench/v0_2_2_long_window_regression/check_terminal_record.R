args <- commandArgs(TRUE)
if (!length(args)) {
  stop("Usage: check_terminal_record.R <terminal_release.json> [--self-test]")
}
record_path <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
self_test <- "--self-test" %in% args
script <- dirname(normalizePath(sub("^--file=", "", grep(
  "^--file=", commandArgs(FALSE), value = TRUE
)[[1L]]), winslash = "/"))
expected_path <- file.path(script, "evidence", "terminal_release", "expected.json")

check_terminal <- function(record) {
  errors <- character()
  fail <- function(message) errors <<- c(errors, message)
  expected <- jsonlite::read_json(expected_path, simplifyVector = FALSE)
  observed <- record[c("snapshot", "native_identities", "outputs")]
  if (!identical(observed, expected)) fail("Terminal record differs from its oracle")
  required_arms <- c("straight", "reopened", "interrupted", "resumed")
  if (!identical(names(record$native_identities), required_arms)) {
    fail("Terminal native identity arms are incomplete")
  } else {
    required <- c("kind", "run_id", "snapshot_id", "snapshot_hash",
                  "config_hash", "feature_set_hash")
    for (arm in required_arms) {
      value <- record$native_identities[[arm]]
      if (!all(required %in% names(value)) ||
          any(!nzchar(unlist(value[required], use.names = FALSE)))) {
        fail(paste("Terminal native identity is incomplete:", arm))
      }
      if (!identical(value$snapshot_id, record$snapshot$snapshot_id) ||
          !identical(value$snapshot_hash, record$snapshot$snapshot_hash)) {
        fail(paste("Terminal snapshot identity is inconsistent:", arm))
      }
    }
    if (!identical(record$native_identities$straight,
                   record$native_identities$reopened)) {
      fail("Straight and reopened native identities differ")
    }
    if (!identical(record$native_identities$interrupted,
                   record$native_identities$resumed)) {
      fail("Interrupted and resumed native identities differ")
    }
  }
  errors
}

record <- jsonlite::read_json(record_path, simplifyVector = FALSE)
errors <- check_terminal(record)
if (length(errors)) stop(paste(errors, collapse = "\n"))
if (self_test) {
  mutated <- record
  mutated$native_identities$straight$config_hash <- "gutted"
  errors <- check_terminal(mutated)
  if (!any(grepl("differs", errors, fixed = TRUE))) {
    stop("Terminal checker self-test failed for native identity drift")
  }
  mutated <- record
  mutated$outputs$events[[1L]] <- "gutted"
  errors <- check_terminal(mutated)
  if (!any(grepl("differs", errors, fixed = TRUE))) {
    stop("Terminal checker self-test failed for economic drift")
  }
}
cat("LWREG_TERMINAL_CHECK_OK\n")
