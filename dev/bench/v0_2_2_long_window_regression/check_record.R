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
  required <- c(
    "suite.json", "processes.csv", "measurements.csv",
    "fixture_probes.json", "summary.csv", "record_hashes.csv"
  )
  missing <- required[!file.exists(file.path(path, required))]
  if (length(missing)) return(paste("Missing", missing))
  suite <- jsonlite::read_json(file.path(path, "suite.json"),
                               simplifyVector = TRUE)
  processes <- utils::read.csv(file.path(path, "processes.csv"),
                               stringsAsFactors = FALSE)
  measurements <- utils::read.csv(file.path(path, "measurements.csv"),
                                  stringsAsFactors = FALSE)
  summary <- utils::read.csv(file.path(path, "summary.csv"),
                             stringsAsFactors = FALSE)
  recorded_hashes <- utils::read.csv(
    file.path(path, "record_hashes.csv"), stringsAsFactors = FALSE
  )
  normalized_hash <- function(file) {
    bytes <- readBin(file, "raw", n = file.info(file)$size)
    value <- gsub("\r\n", "\n", rawToChar(bytes), fixed = TRUE)
    digest::digest(charToRaw(value), algo = "sha256", serialize = FALSE)
  }
  hash_files <- file.path(path, recorded_hashes$path)
  if (any(!file.exists(hash_files)) || !identical(
    unname(vapply(hash_files, normalized_hash, character(1L))),
    recorded_hashes$sha256_lf
  )) {
    fail("Recorded LF-normalized file hashes do not match")
  }
  manifest <- lwreg_manifest(script)
  selected <- manifest[manifest$profile == suite$profile, , drop = FALSE]
  if (!suite$profile %in% c("ordinary", "release") || !nrow(selected)) {
    fail("Unknown or empty suite profile: ", suite$profile)
    return(errors)
  }
  if (any(processes$exit_status != 0L)) fail("A child process failed")
  if (identical(suite$profile, "ordinary") && suite$elapsed_s > 1200) {
    fail("Ordinary suite exceeded 1,200 seconds")
  }
  if (identical(suite$profile, "ordinary") && suite$pairs < 5L) {
    fail("Ordinary suite has fewer than five pairs")
  }
  tree_fields <- c("accepted_tree_status", "candidate_tree_status")
  if (!all(tree_fields %in% names(suite)) ||
      any(nzchar(unlist(suite[tree_fields])))) {
    fail("Product-tree cleanliness is absent or non-empty")
  }

  probes <- jsonlite::read_json(file.path(path, "fixture_probes.json"),
                                simplifyVector = FALSE)
  initial_shapes <- unique(measurements$shape_id[
    measurements$attempt == "initial"
  ])
  missing_shapes <- setdiff(selected$shape_id, initial_shapes)
  if (length(missing_shapes)) {
    fail("Missing ", suite$profile, " shape: ",
         paste(missing_shapes, collapse = ", "))
  }
  for (shape in selected$shape_id) {
    probe <- probes[[shape]]
    if (is.null(probe)) {
      fail("Missing fixture probe: ", shape)
      next
    }
    declared_status <- selected$expected_status[
      match(shape, selected$shape_id)
    ]
    if (!identical(probe$expected_status, declared_status)) {
      fail("Fixture status disagrees with manifest: ", shape)
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
  measurement_key <- function(shape, arm, pair, attempt) {
    paste(shape, arm, pair, attempt, sep = "|")
  }
  measured_keys <- measurement_key(
    measurements$shape_id,
    measurements$arm,
    measurements$pair,
    measurements$attempt
  )
  successful_cases <- processes[
    processes$kind == "case" & processes$exit_status == 0L,
    , drop = FALSE
  ]
  process_keys <- measurement_key(
    successful_cases$shape_id,
    successful_cases$arm,
    successful_cases$pair,
    successful_cases$attempt
  )
  missing_measurements <- setdiff(process_keys, measured_keys)
  if (length(missing_measurements)) {
    fail("Successful case process lacks measurement: ",
         paste(missing_measurements, collapse = ", "))
  }
  for (i in seq_len(nrow(measurements))) {
    value <- read_case(measurements$file[[i]])
    same_cold <- isTRUE(all.equal(
      as.numeric(measurements$cold_s[[i]]),
      as.numeric(value$cold$elapsed_s),
      tolerance = 1e-12
    ))
    same_warm <- isTRUE(all.equal(
      as.numeric(measurements$warm_s[[i]]),
      as.numeric(value$warm$elapsed_s),
      tolerance = 1e-12
    ))
    if (!same_cold || !same_warm) {
      fail("Measurement disagrees with raw elapsed_s: ",
           measurements$file[[i]])
    }
    if (!identical(value$shape_id, measurements$shape_id[[i]])) {
      fail("Measurement shape disagrees with raw case: ",
           measurements$file[[i]])
    }
    if (!identical(value$product_tree_status, "")) {
      fail("Case product tree is dirty or unrecorded: ",
           measurements$file[[i]])
    }
  }
  expected_pairs <- seq_len(as.integer(suite$pairs))
  for (shape in selected$shape_id) {
    shape_attempts <- unique(measurements$attempt[
      measurements$shape_id == shape
    ])
    if (!"initial" %in% shape_attempts) {
      fail("Missing initial attempt: ", shape)
      next
    }
    for (attempt in shape_attempts) {
      part <- measurements[
        measurements$shape_id == shape &
          measurements$attempt == attempt,
        , drop = FALSE
      ]
      for (arm in c("accepted", "candidate")) {
        observed <- sort(unique(part$pair[part$arm == arm]))
        if (!identical(observed, expected_pairs)) {
          fail("Attempt has fewer complete pairs: ", shape, " ", attempt,
               " ", arm)
        }
      }
    }
  }
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
        if (!identical(a$commit, suite$accepted_commit) ||
            !identical(c$commit, suite$candidate_commit)) {
          fail("Case commit does not match suite provenance: ", shape, " ",
               pair, " ", attempt)
        }
        environment_fields <- c(
          "package_version", "r_version", "duckdb_version", "collapse_version"
        )
        if (!identical(a[environment_fields], c[environment_fields])) {
          fail("Accepted and candidate environments differ: ", shape, " ",
               pair, " ", attempt)
        }
        expected_status <- manifest$expected_status[
          match(shape, manifest$shape_id)
        ]
        if (identical(expected_status, "returned")) expected_status <- "DONE"
        for (phase in c("cold", "warm")) {
          if (!identical(a[[phase]]$identities, c[[phase]]$identities)) {
            fail("Semantic drift: ", shape, " ", pair, " ", attempt,
                 " ", phase)
          }
          if (!identical(a[[phase]]$status, c[[phase]]$status)) {
            fail("Status drift: ", shape, " ", pair, " ", attempt,
                 " ", phase)
          }
          actual_status <- strsplit(a[[phase]]$status, "+", fixed = TRUE)[[1L]]
          if (!all(actual_status == expected_status)) {
            fail("Unexpected status: ", shape, " ", pair, " ", attempt,
                 " ", phase)
          }
        }
        if (identical(shape, "feature_gaps")) {
          for (phase in c("cold", "warm")) {
            identity <- a[[phase]]$identities
            if (identity$fills$rows == 0L || identity$trades$rows == 0L) {
              fail("Feature shape has vacuous fills or trades: ", phase)
            }
          }
        }
        if (identical(shape, "availability_sweep")) {
          for (phase in c("cold", "warm")) {
            if (a[[phase]]$identities$distinct_decision_outcomes < 2L) {
              fail("Sweep candidates do not change decisions: ", phase)
            }
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
    if (nrow(a) != suite$pairs || nrow(c) != suite$pairs) next
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
          if (nrow(ra) != suite$pairs || nrow(rc) != suite$pairs) next
          if (median(rc[[phase]] / ra[[phase]]) > 1.10) {
            fail("Performance regression stands: ", shape, " ", phase)
          }
        }
      }
    }
  }

  if (!setequal(summary$shape_id, selected$shape_id)) {
    fail("Summary shape set does not match suite profile")
  }
  for (shape in intersect(summary$shape_id, selected$shape_id)) {
    row <- summary[summary$shape_id == shape, , drop = FALSE]
    part <- initial[initial$shape_id == shape, , drop = FALSE]
    a <- part[part$arm == "accepted", ]; a <- a[order(a$pair), ]
    c <- part[part$arm == "candidate", ]; c <- c[order(c$pair), ]
    process_peaks <- processes$peak_rss_bytes[processes$shape_id == shape]
    if (nrow(a) != suite$pairs || nrow(c) != suite$pairs ||
        !length(process_peaks)) {
      next
    }
    expected_summary <- c(
      pairs = nrow(a),
      accepted_cold_median_s = median(a$cold_s),
      candidate_cold_median_s = median(c$cold_s),
      cold_pair_ratio_median = median(c$cold_s / a$cold_s),
      accepted_warm_median_s = median(a$warm_s),
      candidate_warm_median_s = median(c$warm_s),
      warm_pair_ratio_median = median(c$warm_s / a$warm_s),
      peak_rss_bytes = max(process_peaks)
    )
    observed_summary <- unlist(row[names(expected_summary)], use.names = TRUE)
    if (!isTRUE(all.equal(
      as.numeric(observed_summary), as.numeric(expected_summary),
      tolerance = 1e-12
    ))) {
      fail("Summary drift: ", shape)
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
  copy_record <- function() {
    scratch <- tempfile("lwreg-self-test-")
    dir.create(scratch)
    files <- list.files(record, recursive = TRUE, full.names = TRUE)
    relative <- substring(files, nchar(record) + 2L)
    for (i in seq_along(files)) {
      if (!dir.exists(files[[i]])) {
        target <- file.path(scratch, relative[[i]])
        dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
        file.copy(files[[i]], target)
      }
    }
    scratch
  }
  refresh_hashes <- function(path) {
    files <- list.files(path, recursive = TRUE, full.names = TRUE)
    files <- files[!dir.exists(files)]
    files <- files[basename(files) != "record_hashes.csv"]
    relative <- substring(normalizePath(files, winslash = "/"),
                          nchar(path) + 2L)
    hashes <- data.frame(
      path = relative,
      sha256_lf = vapply(files, function(file) {
        bytes <- readBin(file, "raw", n = file.info(file)$size)
        value <- gsub("\r\n", "\n", rawToChar(bytes), fixed = TRUE)
        digest::digest(charToRaw(value), algo = "sha256", serialize = FALSE)
      }, character(1L)),
      stringsAsFactors = FALSE
    )
    hashes <- hashes[order(hashes$path), , drop = FALSE]
    utils::write.csv(hashes, file.path(path, "record_hashes.csv"),
                     row.names = FALSE)
  }
  expect_mutation <- function(label, mutate, expected) {
    scratch <- copy_record()
    on.exit(unlink(scratch, recursive = TRUE, force = TRUE), add = TRUE)
    mutate(scratch)
    refresh_hashes(scratch)
    observed <- lwreg_check(scratch)
    if (!any(grepl(expected, observed, fixed = TRUE))) {
      stop("Self-test failed for ", label, "; expected: ", expected)
    }
  }
  read_measurements <- function(path) utils::read.csv(
    file.path(path, "measurements.csv"), stringsAsFactors = FALSE
  )
  write_measurements <- function(value, path) utils::write.csv(
    value, file.path(path, "measurements.csv"), row.names = FALSE
  )

  expect_mutation("semantic drift", function(path) {
    measurements <- read_measurements(path)
    candidate <- which(measurements$arm == "candidate" &
                       measurements$attempt == "initial")[[1L]]
    case_path <- file.path(path, "raw", measurements$file[[candidate]])
    case <- jsonlite::read_json(case_path, simplifyVector = FALSE)
    case$cold$identities$equity$hash <- "gutted"
    jsonlite::write_json(case, case_path, auto_unbox = TRUE, pretty = TRUE,
                         null = "null", digits = 16)
  }, "Semantic drift")

  if (identical(jsonlite::read_json(
    file.path(record, "suite.json"), simplifyVector = TRUE
  )$profile, "ordinary")) {
  expect_mutation("timing retry", function(path) {
    measurements <- read_measurements(path)
    target <- measurements$arm == "candidate" &
      measurements$attempt == "initial" &
      measurements$shape_id == "feature_gaps"
    measurements$cold_s[target] <- measurements$cold_s[target] * 10
    write_measurements(measurements, path)
  }, "Performance regression lacks retry: feature_gaps cold_s")

  expect_mutation("missing shape", function(path) {
    measurements <- read_measurements(path)
    removed <- measurements$file[
      measurements$shape_id == "availability_sweep"
    ]
    unlink(file.path(path, "raw", removed))
    measurements <- measurements[
      measurements$shape_id != "availability_sweep", , drop = FALSE
    ]
    write_measurements(measurements, path)
    processes <- utils::read.csv(file.path(path, "processes.csv"),
                                 stringsAsFactors = FALSE)
    processes <- processes[
      processes$shape_id != "availability_sweep", , drop = FALSE
    ]
    utils::write.csv(processes, file.path(path, "processes.csv"),
                     row.names = FALSE)
  }, "Missing ordinary shape: availability_sweep")

  expect_mutation("missing pair", function(path) {
    measurements <- read_measurements(path)
    remove <- measurements$shape_id == "feature_gaps" &
      measurements$pair == 5L & measurements$attempt == "initial"
    unlink(file.path(path, "raw", measurements$file[remove]))
    measurements <- measurements[!remove, , drop = FALSE]
    write_measurements(measurements, path)
    processes <- utils::read.csv(file.path(path, "processes.csv"),
                                 stringsAsFactors = FALSE)
    remove_process <- processes$kind == "case" &
      processes$shape_id == "feature_gaps" &
      processes$pair == 5L & processes$attempt == "initial"
    processes <- processes[!remove_process, , drop = FALSE]
    utils::write.csv(processes, file.path(path, "processes.csv"),
                     row.names = FALSE)
  }, "Attempt has fewer complete pairs: feature_gaps initial accepted")

  expect_mutation("partial retry", function(path) {
    measurements <- read_measurements(path)
    initial <- measurements$shape_id == "feature_gaps" &
      measurements$attempt == "initial"
    for (pair in seq_len(5L)) {
      a <- which(initial & measurements$arm == "accepted" &
                 measurements$pair == pair)
      c <- which(initial & measurements$arm == "candidate" &
                 measurements$pair == pair)
      measurements$cold_s[c] <- measurements$cold_s[a] * 1.2
      case_path <- file.path(path, "raw", measurements$file[c])
      case <- jsonlite::read_json(case_path, simplifyVector = FALSE)
      case$cold$elapsed_s <- measurements$cold_s[c]
      jsonlite::write_json(case, case_path, auto_unbox = TRUE, pretty = TRUE,
                           null = "null", digits = 16)
    }
    retry <- measurements[initial & measurements$pair == 1L, , drop = FALSE]
    retry$attempt <- "retry"
    for (i in seq_len(nrow(retry))) {
      source <- file.path(path, "raw", retry$file[[i]])
      retry$file[[i]] <- sub("_initial.json$", "_retry.json", retry$file[[i]])
      file.copy(source, file.path(path, "raw", retry$file[[i]]))
    }
    measurements <- rbind(measurements, retry)
    write_measurements(measurements, path)
    processes <- utils::read.csv(file.path(path, "processes.csv"),
                                 stringsAsFactors = FALSE)
    retry_processes <- processes[
      processes$kind == "case" &
        processes$shape_id == "feature_gaps" &
        processes$pair == 1L & processes$attempt == "initial",
      , drop = FALSE
    ]
    retry_processes$attempt <- "retry"
    processes <- rbind(processes, retry_processes)
    utils::write.csv(processes, file.path(path, "processes.csv"),
                     row.names = FALSE)
  }, "Attempt has fewer complete pairs: feature_gaps retry accepted")
  }

  expect_mutation("raw timing mismatch", function(path) {
    measurements <- read_measurements(path)
    row <- which(measurements$arm == "candidate" &
                 measurements$attempt == "initial")[[1L]]
    case_path <- file.path(path, "raw", measurements$file[[row]])
    case <- jsonlite::read_json(case_path, simplifyVector = FALSE)
    case$cold$elapsed_s <- case$cold$elapsed_s * 1.5
    jsonlite::write_json(case, case_path, auto_unbox = TRUE, pretty = TRUE,
                         null = "null", digits = 16)
  }, "Measurement disagrees with raw elapsed_s")

  expect_mutation("missing process measurement", function(path) {
    measurements <- read_measurements(path)
    remove <- which(measurements$arm == "candidate" &
                    measurements$attempt == "initial")[[1L]]
    measurements <- measurements[-remove, , drop = FALSE]
    write_measurements(measurements, path)
  }, "Successful case process lacks measurement")

  expect_mutation("summary resource drift", function(path) {
    summary_path <- file.path(path, "summary.csv")
    summary <- utils::read.csv(summary_path, stringsAsFactors = FALSE)
    summary$peak_rss_bytes[[1L]] <- summary$peak_rss_bytes[[1L]] + 1
    utils::write.csv(summary, summary_path, row.names = FALSE)
  }, "Summary drift")

  expect_mutation("dirty provenance", function(path) {
    suite_path <- file.path(path, "suite.json")
    suite <- jsonlite::read_json(suite_path, simplifyVector = FALSE)
    suite$candidate_tree_status <- " M R/backtest-runner.R"
    jsonlite::write_json(suite, suite_path, auto_unbox = TRUE, pretty = TRUE,
                         null = "null", digits = 16)
  }, "Product-tree cleanliness is absent or non-empty")
}
cat("LWREG_CHECK_OK\n")
