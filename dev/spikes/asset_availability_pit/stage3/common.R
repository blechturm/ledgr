stage3_root <- function() {
  normalizePath(
    file.path("dev", "spikes", "asset_availability_pit"),
    winslash = "/",
    mustWork = TRUE
  )
}

stage3_read_expected <- function(witness_id) {
  path <- file.path(stage3_root(), "expected", paste0(witness_id, ".csv"))
  utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = "character",
    na.strings = character()
  )
}

stage3_iso <- function(x) {
  format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

stage3_hash <- function(payload) {
  canonical_json <- getFromNamespace("canonical_json", "ledgr")
  digest::digest(canonical_json(payload), algo = "sha256")
}

stage3_hash_file <- function(path) {
  size <- file.info(path)$size
  bytes <- readBin(path, what = "raw", n = size)
  if (any(bytes == as.raw(0))) stop("Frozen input is not a text file: ", path, call. = FALSE)
  contents <- rawToChar(bytes)
  if (!validUTF8(contents)) stop("Frozen input is not valid UTF-8: ", path, call. = FALSE)
  contents <- gsub("\r\n", "\n", contents, fixed = TRUE)
  contents <- gsub("\r", "\n", contents, fixed = TRUE)
  digest::digest(charToRaw(contents), algo = "sha256", serialize = FALSE)
}

stage3_verify_frozen_inputs <- function(gate_commit = "c82c485",
                                        require_commit_anchor = FALSE) {
  old_home <- Sys.getenv("HOME")
  on.exit(Sys.setenv(HOME = old_home), add = TRUE)
  user_profile <- Sys.getenv("USERPROFILE")
  if (nzchar(user_profile)) Sys.setenv(HOME = user_profile)
  git_status <- function(args) {
    suppressWarnings(system2("git", args, stdout = FALSE, stderr = FALSE))
  }
  ancestry <- suppressWarnings(system2(
    "git",
    c("merge-base", "--is-ancestor", gate_commit, "HEAD"),
    stdout = FALSE,
    stderr = FALSE
  ))
  stage3_assert(as.integer(ancestry) == 0L, "HEAD does not descend from the Stage 2 gate-record commit.")

  registry <- utils::read.csv(
    file.path(stage3_root(), "evidence", "frozen_hashes.csv"),
    stringsAsFactors = FALSE
  )
  actual <- vapply(registry$path, stage3_hash_file, character(1L))
  bad <- registry$path[actual != registry$sha256]
  stage3_assert(
    length(bad) == 0L,
    paste("Frozen Stage 2 input changed:", paste(bad, collapse = ", "))
  )

  if (isTRUE(require_commit_anchor)) {
    manifest <- paste(readLines(
      file.path(stage3_root(), "evidence", "manifest.md"),
      warn = FALSE
    ), collapse = "\n")
    matched <- regmatches(
      manifest,
      regexec("- Active Stage 2 evidence commit: `([0-9a-f]{40})`\\.", manifest)
    )[[1L]]
    stage3_assert(
      length(matched) == 2L,
      "The active Stage 2 evidence commit is not recorded."
    )
    freeze_commit <- matched[[2L]]
    stage3_assert(
      git_status(c("merge-base", "--is-ancestor", gate_commit, freeze_commit)) == 0L,
      "The active Stage 2 evidence commit predates the Stage 3 authorization."
    )
    stage3_assert(
      git_status(c("merge-base", "--is-ancestor", freeze_commit, "HEAD")) == 0L,
      "The active Stage 2 evidence commit is not an ancestor of HEAD."
    )
    frozen_paths <- c(
      file.path(stage3_root(), "evidence", "frozen_hashes.csv"),
      registry$path
    )
    repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
    frozen_paths <- gsub("\\\\", "/", normalizePath(
      frozen_paths,
      winslash = "/",
      mustWork = TRUE
    ))
    frozen_paths <- sub(paste0("^", repo_root, "/"), "", frozen_paths)
    stage3_assert(
      git_status(c("diff", "--quiet", freeze_commit, "HEAD", "--", frozen_paths)) == 0L &&
        git_status(c("diff", "--quiet", "--", frozen_paths)) == 0L,
      "The active frozen evidence differs from its recorded commit."
    )
  }
  invisible(TRUE)
}

stage3_scalar <- function(value, reason_code = "") {
  list(value = value, reason_code = reason_code)
}

stage3_identity <- function(value) {
  list(identity = as.character(value))
}

stage3_key <- function(case_id, field, event_time = "", asset_id = "") {
  paste(case_id, field, event_time %||% "", asset_id %||% "", sep = "\034")
}

stage3_evidence <- function() {
  state <- new.env(parent = emptyenv())
  state$values <- list()
  state$identities <- list()

  put <- function(case_id,
                  field,
                  value,
                  event_time = "",
                  asset_id = "",
                  reason_code = "") {
    key <- stage3_key(case_id, field, event_time, asset_id)
    if (!is.null(state$values[[key]])) {
      stop("Duplicate Stage 3 evidence key: ", key, call. = FALSE)
    }
    state$values[[key]] <- stage3_scalar(value, reason_code)
    invisible(NULL)
  }

  put_identity <- function(case_id,
                           field,
                           identity_name,
                           value,
                           step = NULL) {
    key <- stage3_key(case_id, field)
    state$identities[[key]] <- stage3_identity(value)
    if (!is.null(step)) {
      endpoint <- paste0("case:", case_id, "@", as.integer(step))
      state$identities[[paste(identity_name, endpoint, sep = "\034")]] <-
        stage3_identity(value)
    }
    invisible(NULL)
  }

  list(state = state, put = put, put_identity = put_identity)
}

stage3_value_type <- function(value) {
  if (is.null(value) || (length(value) == 1L && is.na(value))) {
    return("absent")
  }
  if (is.logical(value)) return("logical")
  if (is.integer(value)) return("integer")
  if (is.numeric(value)) return("double")
  if (inherits(value, "POSIXct")) return("timestamp")
  "character"
}

stage3_value_string <- function(value, expected_type) {
  if (is.null(value) || identical(expected_type, "absent")) return("")
  if (identical(expected_type, "logical")) {
    return(if (isTRUE(value)) "true" else "false")
  }
  if (identical(expected_type, "integer")) return(as.character(as.integer(value)))
  if (identical(expected_type, "double")) {
    return(format(as.numeric(value), scientific = FALSE, trim = TRUE, digits = 17L))
  }
  if (identical(expected_type, "timestamp")) return(stage3_iso(value))
  as.character(value)
}

stage3_materialize_observed <- function(witness_id, evidence, source = "fork") {
  expected <- stage3_read_expected(witness_id)
  rows <- vector("list", nrow(expected))
  identity_rows <- expected$identity_expectation %in%
    c("equal", "changed", "captured", "absent")
  expected_value_keys <- vapply(which(!identity_rows), function(i) {
    stage3_key(
      expected$case_id[[i]], expected$field[[i]],
      expected$event_time[[i]], expected$asset_id[[i]]
    )
  }, character(1L))
  expected_identity_keys <- vapply(which(identity_rows), function(i) {
    stage3_key(expected$case_id[[i]], expected$field[[i]])
  }, character(1L))

  for (i in seq_len(nrow(expected))) {
    row <- expected[i, , drop = FALSE]
    is_identity <- row$identity_expectation[[1L]] %in%
      c("equal", "changed", "captured", "absent")
    key <- stage3_key(
      row$case_id[[1L]],
      row$field[[1L]],
      row$event_time[[1L]],
      row$asset_id[[1L]]
    )
    item <- if (is_identity) {
      evidence$state$identities[[stage3_key(row$case_id[[1L]], row$field[[1L]])]]
    } else {
      evidence$state$values[[key]]
    }
    if (is.null(item)) {
      stop(
        sprintf(
          "%s %s step %s has no observed value for %s.",
          witness_id,
          row$case_id[[1L]],
          row$step[[1L]],
          key
        ),
        call. = FALSE
      )
    }
    value <- if (is_identity) item$identity else item$value
    reason <- if (is_identity) "" else item$reason_code
    observed_type <- if (is_identity) "identity" else stage3_value_type(value)
    rows[[i]] <- data.frame(
      witness_id = witness_id,
      case_id = row$case_id[[1L]],
      step = as.integer(row$step[[1L]]),
      event_time = row$event_time[[1L]],
      asset_id = row$asset_id[[1L]],
      field = row$field[[1L]],
      observed_type = observed_type,
      observed_value = if (is_identity) {
        as.character(value)
      } else {
        stage3_value_string(value, observed_type)
      },
      reason_code = reason,
      identity_name = row$identity_name[[1L]],
      source = source,
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows)
  observed_identity_keys <- names(evidence$state$identities)
  case_prefix <- sub("\034.*$", "", observed_identity_keys)
  observed_case_identity_keys <- observed_identity_keys[
    case_prefix %in% unique(expected$case_id)
  ]
  attr(out, "stage3_surplus_evidence_keys") <- c(
    setdiff(names(evidence$state$values), expected_value_keys),
    setdiff(observed_case_identity_keys, expected_identity_keys)
  )
  out
}

stage3_find_observed <- function(observed,
                                 case_id,
                                 field,
                                 event_time = NULL,
                                 asset_id = NULL) {
  keep <- observed$case_id == case_id & observed$field == field
  if (!is.null(event_time)) keep <- keep & observed$event_time == event_time
  if (!is.null(asset_id)) keep <- keep & observed$asset_id == asset_id
  observed[keep, , drop = FALSE]
}

stage3_set_observed <- function(observed,
                                case_id,
                                field,
                                value,
                                event_time = NULL,
                                asset_id = NULL,
                                reason_code = NULL) {
  keep <- observed$case_id == case_id & observed$field == field
  if (!is.null(event_time)) keep <- keep & observed$event_time == event_time
  if (!is.null(asset_id)) keep <- keep & observed$asset_id == asset_id
  if (sum(keep) != 1L) {
    stop("Mutation selector must identify exactly one observed row.", call. = FALSE)
  }
  observed$observed_value[keep] <- as.character(value)
  if (!is.null(reason_code)) observed$reason_code[keep] <- reason_code
  observed
}

stage3_assert <- function(ok, message) {
  if (!isTRUE(ok)) stop(message, call. = FALSE)
  invisible(TRUE)
}

`%||%` <- function(x, y) if (is.null(x)) y else x
