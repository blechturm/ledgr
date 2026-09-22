ledgr_test_abort <- function(message, class) {
  stop(structure(
    list(message = message, call = NULL),
    class = c(class, "error", "condition")
  ))
}

ledgr_test_profiles <- function() {
  c("fast", "review", "heavy_protocol")
}

ledgr_test_heavy_protocols_read <- function(path) {
  if (!file.exists(path)) {
    ledgr_test_abort("Heavy-protocol registry is missing.", "ledgr_test_heavy_registry_invalid")
  }
  protocols <- yaml::read_yaml(path)$protocols
  required <- c("id", "owner", "profile", "invocation", "checker", "purpose")
  if (!is.list(protocols) || length(protocols) == 0L) {
    ledgr_test_abort("Heavy-protocol registry is empty.", "ledgr_test_heavy_registry_invalid")
  }
  for (protocol in protocols) {
    missing <- setdiff(required, names(protocol))
    values <- unlist(protocol[intersect(required, names(protocol))], use.names = FALSE)
    if (length(missing) > 0L || any(!nzchar(values))) {
      ledgr_test_abort(
        "Heavy protocol lacks its owner, invocation, checker, or purpose.",
        "ledgr_test_heavy_registry_invalid"
      )
    }
    if (!identical(protocol$profile, "heavy_protocol")) {
      ledgr_test_abort(
        sprintf("Heavy protocol %s has the wrong profile.", protocol$id),
        "ledgr_test_heavy_registry_invalid"
      )
    }
  }
  ids <- vapply(protocols, `[[`, character(1), "id")
  if (anyDuplicated(ids)) {
    ledgr_test_abort("Heavy-protocol IDs are duplicated.", "ledgr_test_heavy_registry_invalid")
  }
  protocols
}

ledgr_test_gate_decide <- function(seconds, bound, confirmation_runs = 2L) {
  if (!is.numeric(seconds) || anyNA(seconds) || any(seconds < 0) ||
      !is.numeric(bound) || length(bound) != 1L || is.na(bound) || bound <= 0) {
    ledgr_test_abort("Test timing evidence is invalid.", "ledgr_test_timing_invalid")
  }
  confirmation_runs <- as.integer(confirmation_runs)
  required <- if (seconds[[1L]] > bound) 1L + confirmation_runs else 1L
  if (length(seconds) != required) {
    ledgr_test_abort(
      sprintf("Timing gate requires %d run(s), received %d.", required, length(seconds)),
      "ledgr_test_timing_protocol_incomplete"
    )
  }
  median_seconds <- stats::median(seconds)
  if (median_seconds > bound) {
    ledgr_test_abort(
      sprintf("Fast test gate failed: median %.3f > %.3f seconds.", median_seconds, bound),
      "ledgr_test_timing_gate_failed"
    )
  }
  invisible(median_seconds)
}

ledgr_test_release_gate <- function(records) {
  required <- c("fast", "review")
  if (!is.data.frame(records) || !all(c("profile", "passed") %in% names(records))) {
    ledgr_test_abort("Release profile evidence is invalid.", "ledgr_test_release_gate_invalid")
  }
  missing <- setdiff(required, records$profile[records$passed %in% TRUE])
  if (length(missing) > 0L) {
    ledgr_test_abort(
      sprintf("Release gate lacks passing profile(s): %s.", paste(missing, collapse = ", ")),
      "ledgr_test_release_profile_missing"
    )
  }
  invisible(TRUE)
}

ledgr_test_is_block <- function(expr) {
  if (!is.call(expr)) return(FALSE)
  head <- expr[[1L]]
  if (is.symbol(head)) return(identical(as.character(head), "test_that"))
  is.call(head) &&
    identical(as.character(head[[1L]]), "::") &&
    identical(as.character(head[[3L]]), "test_that")
}

ledgr_test_block_title <- function(expr, path) {
  title <- expr[[2L]]
  if (!is.character(title) || length(title) != 1L || is.na(title)) {
    ledgr_test_abort(
      sprintf("Test block in %s does not have a literal scalar title.", path),
      "ledgr_test_profile_unclassified"
    )
  }
  title
}

ledgr_test_block_line <- function(ref) {
  if (is.null(ref)) NA_integer_ else as.integer(ref[[1L]])
}

ledgr_test_occurrence <- function(file, title) {
  group <- paste(file, title, sep = "\r")
  as.integer(ave(seq_along(group), group, FUN = seq_along))
}

ledgr_test_profile_declarations <- function(lines, path) {
  marker <- grepl("^\\s*#", lines) &
    grepl("ledgr-test-(file-)?profile:", lines)
  pattern <- "^\\s*#\\s*ledgr-test-(file-)?profile:\\s*([^[:space:]]+)\\s*$"
  matched <- regexec(pattern, lines, perl = TRUE)
  values <- regmatches(lines, matched)
  exact <- lengths(values) > 0L
  if (any(marker & !exact)) {
    ledgr_test_abort(
      sprintf("Malformed test profile metadata in %s.", path),
      "ledgr_test_profile_invalid_metadata"
    )
  }
  if (!any(exact)) {
    return(data.frame(
      line = integer(),
      kind = character(),
      profile = character(),
      stringsAsFactors = FALSE
    ))
  }
  declarations <- lapply(which(exact), function(i) {
    hit <- values[[i]]
    data.frame(
      line = i,
      kind = if (identical(hit[[2L]], "file-")) "file" else "block",
      profile = hit[[3L]],
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, declarations)
  unknown <- setdiff(unique(out$profile), ledgr_test_profiles())
  if (length(unknown) > 0L) {
    ledgr_test_abort(
      sprintf("Unknown test profile token(s) in %s: %s.", path, paste(unknown, collapse = ", ")),
      "ledgr_test_profile_unknown"
    )
  }
  out
}

ledgr_test_scan_file <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  expressions <- parse(path, keep.source = TRUE, encoding = "UTF-8")
  block_index <- which(vapply(expressions, ledgr_test_is_block, logical(1)))
  declarations <- ledgr_test_profile_declarations(lines, path)
  file_declarations <- declarations[declarations$kind == "file", , drop = FALSE]
  block_declarations <- declarations[declarations$kind == "block", , drop = FALSE]
  if (nrow(file_declarations) > 1L) {
    ledgr_test_abort(
      sprintf("Multiple file profile declarations in %s.", path),
      "ledgr_test_profile_contradictory"
    )
  }
  if (nrow(file_declarations) > 0L && nrow(block_declarations) > 0L) {
    ledgr_test_abort(
      sprintf("File and block profile declarations coexist in %s.", path),
      "ledgr_test_profile_contradictory"
    )
  }
  if (length(block_index) == 0L) {
    if (nrow(declarations) > 0L) {
      ledgr_test_abort(
        sprintf("Profile metadata in %s has no test block.", path),
        "ledgr_test_profile_unclassified"
      )
    }
    return(data.frame())
  }

  titles <- vapply(
    expressions[block_index],
    ledgr_test_block_title,
    character(1),
    path = path
  )
  references <- attr(expressions, "srcref", exact = TRUE)
  line <- vapply(references[block_index], ledgr_test_block_line, integer(1))
  if (anyNA(line)) {
    ledgr_test_abort(
      sprintf("Test block source locations are unavailable in %s.", path),
      "ledgr_test_profile_unclassified"
    )
  }
  attached <- match(line - 1L, block_declarations$line)
  if (anyDuplicated(block_declarations$line)) {
    ledgr_test_abort(
      sprintf("Duplicate block profile declaration in %s.", path),
      "ledgr_test_profile_contradictory"
    )
  }
  used <- na.omit(attached)
  if (nrow(block_declarations) > length(unique(used))) {
    ledgr_test_abort(
      sprintf("Orphan block profile declaration in %s.", path),
      "ledgr_test_profile_unclassified"
    )
  }
  file_profile <- if (nrow(file_declarations) == 1L) {
    file_declarations$profile[[1L]]
  } else {
    NA_character_
  }
  profile <- rep(if (is.na(file_profile)) "fast" else file_profile, length(titles))
  tagged <- !is.na(attached)
  profile[tagged] <- block_declarations$profile[attached[tagged]]
  id_match <- regexpr("^\\[LTB-[0-9]{4}\\]", titles, perl = TRUE)
  block_id <- ifelse(
    id_match > 0L,
    substr(titles, id_match, id_match + attr(id_match, "match.length") - 1L),
    NA_character_
  )
  block_id <- gsub("^\\[|\\]$", "", block_id)
  block_id[is.na(titles) | id_match < 0L] <- NA_character_
  file <- basename(path)
  occurrence <- ledgr_test_occurrence(rep(file, length(titles)), titles)
  data.frame(
    file = file,
    line = line,
    title = titles,
    occurrence = occurrence,
    block_id = block_id,
    key = paste(file, titles, occurrence, sep = "::"),
    profile = profile,
    stringsAsFactors = FALSE
  )
}

ledgr_test_preflight <- function(test_dir) {
  paths <- sort(list.files(
    test_dir,
    pattern = "^test.*[.][rR]$",
    full.names = TRUE
  ))
  rows <- lapply(paths, ledgr_test_scan_file)
  rows <- rows[vapply(rows, nrow, integer(1)) > 0L]
  out <- if (length(rows) == 0L) data.frame() else do.call(rbind, rows)
  rownames(out) <- NULL
  ids <- out$block_id[!is.na(out$block_id)]
  if (anyDuplicated(ids)) {
    duplicate <- unique(ids[duplicated(ids)])
    ledgr_test_abort(
      sprintf("Duplicate stable block ID(s): %s.", paste(duplicate, collapse = ", ")),
      "ledgr_test_block_id_duplicate"
    )
  }
  out
}

ledgr_test_select <- function(preflight, profile) {
  if (!is.character(profile) || length(profile) != 1L ||
      is.na(profile) || !profile %in% ledgr_test_profiles()) {
    ledgr_test_abort(
      sprintf("Unknown test profile token: %s.", paste(profile, collapse = ", ")),
      "ledgr_test_profile_unknown"
    )
  }
  preflight[preflight$profile == profile, , drop = FALSE]
}

ledgr_test_source_selected <- function(path, titles, env) {
  lines <- brio::read_lines(path)
  srcfile <- srcfilecopy(path, lines, file.info(path)[1L, "mtime"], isFile = TRUE)
  connection <- textConnection(lines, encoding = "UTF-8")
  on.exit(try(close(connection), silent = TRUE), add = TRUE)
  expressions <- parse(connection, n = -1L, srcfile = srcfile, encoding = "UTF-8")
  is_block <- vapply(expressions, ledgr_test_is_block, logical(1))
  block_titles <- rep(NA_character_, length(expressions))
  block_titles[is_block] <- vapply(
    expressions[is_block],
    ledgr_test_block_title,
    character(1),
    path = path
  )
  keep <- !is_block | block_titles %in% titles
  expressions <- expressions[keep]
  reporter <- testthat:::get_reporter()
  on.exit(testthat:::teardown_run(), add = TRUE)
  reporter$start_file(basename(path))
  on.exit({
    reporter$end_context_if_started()
    reporter$end_file()
  }, add = TRUE)
  old_dir <- setwd(dirname(path))
  on.exit(setwd(old_dir), add = TRUE)
  old_options <- options(testthat_topenv = env, testthat_path = path)
  on.exit(options(old_options), add = TRUE)
  invisible(testthat:::test_code(
    code = expressions,
    env = env,
    reporter = reporter
  ))
}

ledgr_test_actual_census <- function(results) {
  tabular <- as.data.frame(testthat:::testthat_results(results))
  if (nrow(tabular) == 0L) {
    return(data.frame(
      file = character(), title = character(), occurrence = integer(), key = character(),
      status = character(), seconds = double(), assertions = integer(),
      stringsAsFactors = FALSE
    ))
  }
  status <- ifelse(
    tabular$error,
    "error",
    ifelse(
      tabular$failed > 0L,
      "failed",
      ifelse(tabular$warning > 0L, "warning", ifelse(tabular$skipped, "skipped", "passed"))
    )
  )
  file <- basename(tabular$file)
  occurrence <- ledgr_test_occurrence(file, tabular$test)
  data.frame(
    file = file,
    title = tabular$test,
    occurrence = occurrence,
    key = paste(file, tabular$test, occurrence, sep = "::"),
    status = status,
    seconds = tabular$real,
    assertions = tabular$nb,
    stringsAsFactors = FALSE
  )
}

ledgr_test_reconcile_selection <- function(expected, selected) {
  missing <- setdiff(expected$key, selected$key)
  extra <- setdiff(selected$key, expected$key)
  if (length(missing) > 0L || length(extra) > 0L) {
    ledgr_test_abort(
      sprintf(
        "Profile selection differs from static preflight (missing=%d, extra=%d).",
        length(missing), length(extra)
      ),
      "ledgr_test_profile_selection_mismatch"
    )
  }
  invisible(TRUE)
}

ledgr_test_reconcile_execution <- function(expected, actual) {
  missing <- setdiff(expected$key, actual$key)
  extra <- setdiff(actual$key, expected$key)
  if (length(missing) > 0L || length(extra) > 0L) {
    ledgr_test_abort(
      sprintf(
        "Reported execution differs from static preflight (missing=%d, extra=%d).",
        length(missing), length(extra)
      ),
      "ledgr_test_profile_execution_mismatch"
    )
  }
  invisible(TRUE)
}

ledgr_test_claims_read <- function(path, preflight) {
  if (!file.exists(path)) {
    ledgr_test_abort("Claims registry is missing.", "ledgr_test_claims_invalid")
  }
  registry <- yaml::read_yaml(path)
  claims <- registry$claims
  if (!is.list(claims) || length(claims) == 0L) {
    ledgr_test_abort("Claims registry is empty.", "ledgr_test_claims_invalid")
  }
  required <- c(
    "id", "source", "scope", "oracle_class", "detecting_blocks",
    "promised_profile", "owner"
  )
  for (claim in claims) {
    missing <- setdiff(required, names(claim))
    if (length(missing) > 0L) {
      ledgr_test_abort(
        sprintf("Claim is missing field(s): %s.", paste(missing, collapse = ", ")),
        "ledgr_test_claims_invalid"
      )
    }
  }
  ids <- vapply(claims, `[[`, character(1), "id")
  if (anyDuplicated(ids)) {
    ledgr_test_abort("Claims registry has duplicate IDs.", "ledgr_test_claims_duplicate")
  }
  all_blocks <- preflight$block_id[!is.na(preflight$block_id)]
  for (claim in claims) {
    if (!nzchar(claim$owner)) {
      ledgr_test_abort(
        sprintf("Claim %s has no owner.", claim$id),
        "ledgr_test_claims_missing_owner"
      )
    }
    if (!claim$promised_profile %in% ledgr_test_profiles()) {
      ledgr_test_abort(
        sprintf("Claim %s has an unknown profile.", claim$id),
        "ledgr_test_claims_unknown_profile"
      )
    }
    blocks <- unlist(claim$detecting_blocks, use.names = FALSE)
    unresolved <- setdiff(blocks, all_blocks)
    if (length(unresolved) > 0L) {
      ledgr_test_abort(
        sprintf("Claim %s has unresolved block(s): %s.", claim$id, paste(unresolved, collapse = ", ")),
        "ledgr_test_claims_unresolved_block"
      )
    }
    actual_profiles <- unique(preflight$profile[match(blocks, preflight$block_id)])
    if (!identical(actual_profiles, claim$promised_profile)) {
      ledgr_test_abort(
        sprintf("Claim %s profile differs from its detecting blocks.", claim$id),
        "ledgr_test_claims_profile_mismatch"
      )
    }
  }
  claims
}

ledgr_test_claims_check <- function(claims, preflight, actual, profile) {
  promised <- Filter(function(claim) identical(claim$promised_profile, profile), claims)
  for (claim in promised) {
    blocks <- unlist(claim$detecting_blocks, use.names = FALSE)
    keys <- preflight$key[match(blocks, preflight$block_id)]
    observed <- actual$status[match(keys, actual$key)]
    if (anyNA(observed)) {
      ledgr_test_abort(
        sprintf("Claim %s did not execute where promised.", claim$id),
        "ledgr_test_claims_execution_missing"
      )
    }
    if (all(observed == "skipped")) {
      ledgr_test_abort(
        sprintf("Claim %s is guarded only by skipped blocks.", claim$id),
        "ledgr_test_claims_all_skipped"
      )
    }
  }
  invisible(TRUE)
}

ledgr_test_assert_cran_mode <- function(root, manifest_path) {
  if (!nzchar(manifest_path) || !file.exists(manifest_path)) {
    ledgr_test_abort(
      "CRAN mode requires a recorded isolated-library manifest.",
      "ledgr_test_cran_isolation_missing"
    )
  }
  if (file.access(getwd(), 2L) == 0L) {
    ledgr_test_abort(
      "CRAN mode requires a read-only working directory.",
      "ledgr_test_cran_workdir_writable"
    )
  }
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
  active <- normalizePath(.libPaths()[[1L]], winslash = "/", mustWork = TRUE)
  recorded <- normalizePath(dirname(manifest_path), winslash = "/", mustWork = TRUE)
  if (!identical(active, recorded)) {
    ledgr_test_abort(
      "CRAN mode did not resolve the recorded isolated library first.",
      "ledgr_test_cran_isolation_mismatch"
    )
  }
  description <- file.path(root, "DESCRIPTION")
  if (!file.exists(description)) {
    ledgr_test_abort(
      "CRAN mode cannot derive optional packages without DESCRIPTION.",
      "ledgr_test_cran_isolation_missing"
    )
  }
  suggests <- read.dcf(description, fields = "Suggests")[[1L]]
  suggests <- trimws(strsplit(suggests, ",", fixed = TRUE)[[1L]])
  suggests <- sub("[[:space:]]*\\(.*\\)$", "", suggests)
  infrastructure <- c(
    "brio", "covr", "knitr", "pkgload", "quarto", "rmarkdown",
    "testthat", "withr", "yaml"
  )
  optional <- setdiff(suggests, infrastructure)
  leaked <- optional[vapply(optional, requireNamespace, logical(1), quietly = TRUE)]
  if (length(leaked) > 0L) {
    ledgr_test_abort(
      sprintf("Optional package(s) leaked into CRAN mode: %s.", paste(leaked, collapse = ", ")),
      "ledgr_test_cran_optional_leak"
    )
  }
  invisible(list(root = root, manifest = manifest))
}

ledgr_test_write_census <- function(path, expected, actual) {
  if (is.null(path) || !nzchar(path)) return(invisible(NULL))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  out <- expected[, c("file", "line", "title", "occurrence", "block_id", "key", "profile"), drop = FALSE]
  out$status <- actual$status[match(out$key, actual$key)]
  out$seconds <- actual$seconds[match(out$key, actual$key)]
  out$assertions <- actual$assertions[match(out$key, actual$key)]
  utils::write.csv(out, path, row.names = FALSE, na = "")
  invisible(path)
}

ledgr_test_run_profile <- function(root,
                                   profile = "fast",
                                   mode = "ordinary",
                                   reporter = "summary",
                                   census_path = NULL,
                                   claims_path = file.path(root, "tests", "claims.yml"),
                                   load_package = "none",
                                   selector = identity,
                                   actual_filter = identity,
                                   stop_on_failure = TRUE) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  test_dir <- file.path(root, "tests", "testthat")
  preflight <- ledgr_test_preflight(test_dir)
  expected <- ledgr_test_select(preflight, profile)
  selected <- selector(expected)
  ledgr_test_reconcile_selection(expected, selected)
  if (identical(mode, "cran")) {
    ledgr_test_assert_cran_mode(
      root,
      Sys.getenv("LEDGR_CRAN_LIBRARY_MANIFEST", unset = "")
    )
  } else if (!identical(mode, "ordinary")) {
    ledgr_test_abort("Unknown test execution mode.", "ledgr_test_mode_unknown")
  }

  env <- testthat:::test_files_setup_env(
    "ledgr", test_dir, load_package = load_package, env = NULL
  )
  testthat:::local_testing_env(env)
  testthat:::test_files_setup_state(test_dir, "ledgr", TRUE, env)
  reporters <- testthat:::test_files_reporter(reporter, "serial")
  started <- proc.time()[[3L]]
  testthat::with_reporter(reporters$multi, {
    groups <- split(selected$title, selected$file)
    collection_checkpoint <- max(1L, floor(length(groups) * 0.4))
    for (index in seq_along(groups)) {
      # Keep one deterministic full collection inside the measured workload so
      # collector debt cannot drift into an arbitrary later test block.
      if (index == collection_checkpoint) invisible(gc(full = TRUE))
      file <- names(groups)[[index]]
      ledgr_test_source_selected(file.path(test_dir, file), groups[[file]], env)
    }
  })
  elapsed <- proc.time()[[3L]] - started
  results <- reporters$list$get_results()
  actual <- actual_filter(ledgr_test_actual_census(results))
  ledgr_test_reconcile_execution(expected, actual)
  claims <- ledgr_test_claims_read(claims_path, preflight)
  ledgr_test_claims_check(claims, preflight, actual, profile)
  ledgr_test_write_census(census_path, expected, actual)
  testthat:::test_files_check(results, stop_on_failure = stop_on_failure)
  list(
    profile = profile,
    mode = mode,
    elapsed_seconds = unname(elapsed),
    expected = expected,
    actual = actual,
    results = testthat:::testthat_results(results)
  )
}
