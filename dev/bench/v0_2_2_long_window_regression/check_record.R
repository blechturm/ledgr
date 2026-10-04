args <- commandArgs(TRUE)
if (!length(args)) stop("Usage: check_record.R <record_dir> [--self-test]")
record <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
self_test <- "--self-test" %in% args
script <- dirname(normalizePath(sub("^--file=", "", grep(
  "^--file=", commandArgs(FALSE), value = TRUE
)[[1L]]), winslash = "/"))
source(file.path(script, "helpers.R"), local = TRUE)

lwreg_check <- function(path) {
  errors <- character()
  fail <- function(...) errors <<- c(errors, paste0(...))
  required <- c("suite.json", "processes.csv", "measurements.csv",
                "fixture_probes.json")
  missing <- required[!file.exists(file.path(path, required))]
  if (length(missing)) return(paste("Missing", missing))
  suite <- jsonlite::read_json(file.path(path, "suite.json"),
                               simplifyVector = TRUE)
  processes <- utils::read.csv(file.path(path, "processes.csv"),
                               stringsAsFactors = FALSE)
  measurements <- utils::read.csv(file.path(path, "measurements.csv"),
                                  stringsAsFactors = FALSE)
  manifest <- lwreg_manifest(script)
  if (any(processes$exit_status != 0L)) fail("A child process failed")
  if (identical(suite$profile, "ordinary") && suite$elapsed_s > 1200) {
    fail("Ordinary suite exceeded 1,200 seconds")
  }
  if (identical(suite$profile, "ordinary") && suite$pairs < 5L) {
    fail("Ordinary suite has fewer than five pairs")
  }

  probes <- jsonlite::read_json(file.path(path, "fixture_probes.json"),
                                simplifyVector = FALSE)
  ordinary <- manifest[manifest$profile == "ordinary", , drop = FALSE]
  for (shape in ordinary$shape_id) {
    probe <- probes[[shape]]
    if (is.null(probe)) {
      fail("Missing fixture probe: ", shape)
      next
    }
    if (!identical(probe$expected_status, "DONE")) {
      fail("Ordinary fixture is not declared DONE: ", shape)
    }
    if (probe$terminal_member_overlap != 0L) {
      fail("Terminal entered membership: ", shape)
    }
    if (!isTRUE(probe$gaps_within_budget)) {
      fail("Gap exceeds stale budget: ", shape)
    }
  }

  read_case <- function(file) jsonlite::read_json(
    file.path(path, "raw", file), simplifyVector = FALSE
  )
  attempts <- unique(measurements$attempt)
  for (attempt in attempts[attempts != "orientation"]) {
    part_attempt <- measurements[measurements$attempt == attempt, , drop = FALSE]
    for (shape in unique(part_attempt$shape_id)) {
      part <- part_attempt[part_attempt$shape_id == shape, , drop = FALSE]
      for (pair in unique(part$pair)) {
        rows <- part[part$pair == pair, , drop = FALSE]
        if (!setequal(rows$arm, c("accepted", "candidate"))) {
          fail("Incomplete pair: ", shape, " ", pair, " ", attempt)
          next
        }
        a <- read_case(rows$file[rows$arm == "accepted"])
        c <- read_case(rows$file[rows$arm == "candidate"])
        for (phase in c("cold", "warm")) {
          if (!identical(a[[phase]]$identities, c[[phase]]$identities)) {
            fail("Semantic drift: ", shape, " ", pair, " ", attempt,
                 " ", phase)
          }
          if (!identical(a[[phase]]$status, c[[phase]]$status)) {
            fail("Status drift: ", shape, " ", pair, " ", attempt,
                 " ", phase)
          }
        }
        a_resolve <- a$facts_resolve
        c_resolve <- c$facts_resolve
        if (!is.null(a_resolve)) a_resolve[c("cold_s", "warm_s")] <- NULL
        if (!is.null(c_resolve)) c_resolve[c("cold_s", "warm_s")] <- NULL
        if (!identical(a_resolve, c_resolve)) {
          fail("Fact-resolution drift: ", shape, " ", pair, " ", attempt)
        }
      }
    }
  }

  initial <- measurements[measurements$attempt == "initial", , drop = FALSE]
  for (shape in unique(initial$shape_id)) {
    part <- initial[initial$shape_id == shape, , drop = FALSE]
    a <- part[part$arm == "accepted", ]; a <- a[order(a$pair), ]
    c <- part[part$arm == "candidate", ]; c <- c[order(c$pair), ]
    for (phase in c("cold_s", "warm_s")) {
      ratio <- median(c[[phase]] / a[[phase]])
      if (ratio > 1.10) {
        retry <- measurements[
          measurements$attempt == "retry" & measurements$shape_id == shape,
          , drop = FALSE
        ]
        if (!nrow(retry)) {
          fail("Performance regression lacks retry: ", shape, " ", phase)
        } else {
          ra <- retry[retry$arm == "accepted", ]; ra <- ra[order(ra$pair), ]
          rc <- retry[retry$arm == "candidate", ]; rc <- rc[order(rc$pair), ]
          if (median(rc[[phase]] / ra[[phase]]) > 1.10) {
            fail("Performance regression stands: ", shape, " ", phase)
          }
        }
      }
    }
  }

  orientation <- measurements[measurements$attempt == "orientation", , drop = FALSE]
  if (identical(suite$profile, "ordinary")) {
    if (nrow(orientation) != 1L) {
      fail("Missing accepted baseline orientation run")
    } else {
      value <- read_case(orientation$file[[1L]])$cold$identities
      expected <- c(equity = 757L, fills = 300L,
                    diagnostics = 379873L, strategy_state = 757L)
      actual <- vapply(names(expected), function(name) {
        as.integer(value[[name]]$rows)
      }, integer(1L))
      if (!identical(actual, expected)) {
        fail("The 757-pulse orientation counts do not match d08c8f4")
      }
    }
  }
  errors
}

errors <- lwreg_check(record)
if (length(errors)) stop(paste(errors, collapse = "\n"))
if (self_test) {
  scratch <- tempfile("lwreg-self-test-")
  dir.create(scratch)
  files <- list.files(record, recursive = TRUE, full.names = TRUE)
  dirs <- files[dir.exists(files)]
  if (length(dirs)) dir.create(file.path(scratch, substring(
    dirs, nchar(record) + 2L
  )), recursive = TRUE, showWarnings = FALSE)
  relative <- substring(files, nchar(record) + 2L)
  for (i in seq_along(files)) {
    if (!dir.exists(files[[i]])) {
      dir.create(dirname(file.path(scratch, relative[[i]])), recursive = TRUE,
                 showWarnings = FALSE)
      file.copy(files[[i]], file.path(scratch, relative[[i]]))
    }
  }
  measurements <- utils::read.csv(file.path(scratch, "measurements.csv"),
                                  stringsAsFactors = FALSE)
  candidate <- which(measurements$arm == "candidate" &
                     measurements$attempt == "initial")[[1L]]
  case_path <- file.path(scratch, "raw", measurements$file[[candidate]])
  case <- jsonlite::read_json(case_path, simplifyVector = FALSE)
  case$cold$identities$equity$hash <- "gutted"
  jsonlite::write_json(case, case_path, auto_unbox = TRUE, pretty = TRUE,
                       null = "null", digits = 16)
  if (!any(grepl("Semantic drift", lwreg_check(scratch), fixed = TRUE))) {
    stop("Self-test failed to detect semantic drift")
  }
}
cat("LWREG_CHECK_OK\n")
