stage4_evidence_key <- function(x) {
  paste(x$case_id, x$event_time, x$asset_id, x$field, sep = "\034")
}

stage4_compare_value <- function(expected, observed) {
  type <- expected$expected_type[[1L]]
  if (!identical(type, observed$observed_type[[1L]])) return(FALSE)
  if (type %in% c("double", "integer")) {
    target <- as.numeric(expected$expected_value[[1L]])
    actual <- as.numeric(observed$observed_value[[1L]])
    tolerance <- suppressWarnings(as.numeric(expected$tolerance[[1L]]))
    if (!is.finite(tolerance)) tolerance <- 0
    if (identical(expected$comparison[[1L]], "abs_tol")) {
      return(is.finite(actual) && is.finite(target) &&
        abs(actual - target) <= tolerance)
    }
    return(isTRUE(all.equal(actual, target, tolerance = tolerance)))
  }
  identical(observed$observed_value[[1L]], expected$expected_value[[1L]])
}

stage4_identity_reference <- function(expected_row, expected, observed) {
  reference <- expected_row$reference[[1L]]
  if (!startsWith(reference, "case:")) return(NA_character_)
  parts <- strsplit(sub("^case:", "", reference), "@", fixed = TRUE)[[1L]]
  ref <- expected[
    expected$case_id == parts[[1L]] &
      expected$step == as.integer(parts[[2L]]) &
      expected$identity_name == expected_row$identity_name[[1L]],
    , drop = FALSE
  ]
  if (nrow(ref) != 1L) return(NA_character_)
  actual <- observed[stage4_evidence_key(observed) == stage4_evidence_key(ref), , drop = FALSE]
  if (nrow(actual) != 1L) return(NA_character_)
  actual$observed_value[[1L]]
}

stage4_check_conformance <- function(observed) {
  witness_id <- unique(observed$witness_id)
  stage4_assert(length(witness_id) == 1L, "Conformance input mixes witnesses.")
  expected <- stage3_read_expected(witness_id)
  expected_keys <- stage4_evidence_key(expected)
  observed_keys <- stage4_evidence_key(observed)
  stage4_assert(!anyDuplicated(observed_keys), "Observed evidence has duplicate keys.")
  at <- match(observed_keys, expected_keys)
  stage4_assert(
    !anyNA(at),
    paste(witness_id, "emitted evidence absent from its frozen expected table.")
  )
  selected <- expected[at, , drop = FALSE]
  rows <- vector("list", nrow(observed))
  for (i in seq_len(nrow(observed))) {
    ex <- selected[i, , drop = FALSE]
    ob <- observed[i, , drop = FALSE]
    identity_rule <- ex$identity_expectation[[1L]]
    is_identity <- identity_rule %in% c("captured", "equal", "changed", "absent")
    pass <- if (is_identity) {
      if (identity_rule == "captured") {
        nzchar(ob$observed_value[[1L]])
      } else if (identity_rule == "absent") {
        !nzchar(ob$observed_value[[1L]])
      } else {
        reference <- stage4_identity_reference(ex, expected, observed)
        if (startsWith(ex$reference[[1L]], "source:package_fold")) {
          identity_rule == "equal" &&
            ob$evidence_role[[1L]] == "package_control" &&
            nzchar(ob$observed_value[[1L]])
        } else {
          !is.na(reference) && identical(ob$observed_value[[1L]], reference) ==
            (identity_rule == "equal")
        }
      }
    } else {
      stage4_compare_value(ex, ob) &&
        identical(ob$reason_code[[1L]], ex$reason_code[[1L]])
    }
    rows[[i]] <- data.frame(
      provider = ob$provider[[1L]],
      witness_id = witness_id,
      case_id = ob$case_id[[1L]],
      step = as.integer(ex$step[[1L]]),
      event_time = ob$event_time[[1L]],
      asset_id = ob$asset_id[[1L]],
      field = ob$field[[1L]],
      expected_type = ex$expected_type[[1L]],
      expected_value = ex$expected_value[[1L]],
      observed_type = ob$observed_type[[1L]],
      observed_value = ob$observed_value[[1L]],
      reason_code = ob$reason_code[[1L]],
      evidence_role = ob$evidence_role[[1L]],
      pass = pass,
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

stage4_checker_mutations <- function(baselines) {
  rows <- lapply(names(stage3_mutations()), function(id) {
    mutation <- stage3_mutations()[[id]]
    baseline <- baselines[[mutation$witness]]
    stage4_assert(!is.null(baseline), paste("Missing mutation baseline", mutation$witness))
    mutated <- mutation$apply(baseline)
    check <- stage4_check_conformance(mutated)
    data.frame(
      mutation_id = id,
      witness_id = mutation$witness,
      baseline_pass = all(stage4_check_conformance(baseline)$pass),
      mutated_pass = all(check$pass),
      failed_fields = paste(unique(check$field[!check$pass]), collapse = "|"),
      evidence_role = "fork_derived",
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  stage4_assert(all(out$baseline_pass), "A checker-mutation baseline failed.")
  stage4_assert(!any(out$mutated_pass), "A checker mutation survived conformance.")
  out
}

stage4_assert_w20_path_identity <- function(observed) {
  all_provider_ids <- observed$observed_value[
    observed$field == "provider_identity"
  ]
  stage4_assert(
    length(all_provider_ids) == 18L && length(unique(all_provider_ids)) == 1L,
    "W20 recovered-row identity changed by representation or path."
  )
  for (provider in unique(observed$provider)) {
    x <- observed[observed$provider == provider, , drop = FALSE]
    provider_ids <- x$observed_value[x$field == "provider_identity"]
    prototype_ids <- x$observed_value[x$field == "prototype_identity"]
    stage4_assert(
      length(provider_ids) == 6L && length(unique(provider_ids)) == 1L,
      paste(provider, "W20 provider identity changed across paths.")
    )
    stage4_assert(
      length(prototype_ids) == 4L && length(unique(prototype_ids)) == 1L,
      paste(provider, "W20 prototype identity changed across fork paths.")
    )
  }
  invisible(TRUE)
}

stage4_psock_case <- function(provider, case_spec) {
  cluster <- parallel::makePSOCKcluster(1L)
  on.exit(parallel::stopCluster(cluster), add = TRUE)
  root <- stage4_root()
  payload <- stage4_serialize(provider)
  parallel::clusterCall(cluster, function(root, payload, case_spec) {
    source(file.path(root, "stage3", "common.R"), local = .GlobalEnv)
    source(file.path(root, "stage3", "reference_provider.R"), local = .GlobalEnv)
    source(file.path(root, "stage3", "shared_fold.R"), local = .GlobalEnv)
    source(file.path(root, "stage4", "common.R"), local = .GlobalEnv)
    source(file.path(root, "stage4", "providers.R"), local = .GlobalEnv)
    source(file.path(root, "stage4", "policy_engine.R"), local = .GlobalEnv)
    source(file.path(root, "stage4", "fork.R"), local = .GlobalEnv)
    stage4_run_case(stage4_restore(payload), case_spec)
  }, root, payload, case_spec)[[1L]]
}
