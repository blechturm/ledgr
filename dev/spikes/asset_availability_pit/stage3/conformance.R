stage3_observed_key <- function(x) {
  paste(x$case_id, x$step, x$event_time, x$asset_id, x$field, sep = "\034")
}

stage3_identity_reference <- function(expected_row, observed, sources) {
  reference <- expected_row$reference[[1L]]
  identity_name <- expected_row$identity_name[[1L]]
  if (startsWith(reference, "case:")) {
    endpoint <- sub("^case:", "", reference)
    parts <- strsplit(endpoint, "@", fixed = TRUE)[[1L]]
    row <- observed[
      observed$case_id == parts[[1L]] &
        observed$step == as.integer(parts[[2L]]) &
        observed$identity_name == identity_name,
      ,
      drop = FALSE
    ]
    if (nrow(row) != 1L) return(NA_character_)
    return(row$observed_value[[1L]])
  }
  if (startsWith(reference, "source:")) {
    source_name <- sub("^source:", "", reference)
    source <- sources[[source_name]]
    if (is.null(source)) return(NA_character_)
    row <- source[
      source$case_id == expected_row$case_id[[1L]] &
        source$field == expected_row$field[[1L]] &
        source$identity_name == identity_name,
      ,
      drop = FALSE
    ]
    if (nrow(row) != 1L) return(NA_character_)
    return(row$observed_value[[1L]])
  }
  NA_character_
}

stage3_check_semantic_invariants <- function(observed) {
  findings <- character()
  if (all(c("execution_bar_available", "fill_status", "fill_price") %in% observed$field)) {
    no_bar <- observed[observed$field == "execution_bar_available", , drop = FALSE]
    for (i in seq_len(nrow(no_bar))) {
      if (!identical(no_bar$observed_value[[i]], "false")) next
      case <- no_bar$case_id[[i]]
      asset <- no_bar$asset_id[[i]]
      time <- no_bar$event_time[[i]]
      status <- stage3_find_observed(observed, case, "fill_status", time, asset)
      price <- stage3_find_observed(observed, case, "fill_price", time, asset)
      if (nrow(status) == 1L && nrow(price) == 1L && status$observed_value[[1L]] == "filled") {
        findings <- c(findings, "stale_execution_price")
      }
    }
  }

  cases <- unique(observed$case_id)
  for (case in cases) {
    virtual <- stage3_find_observed(observed, case, "virtual_final_cash")
    cash <- stage3_find_observed(observed, case, "cash_after")
    tolerance <- stage3_find_observed(observed, case, "cash_tolerance")
    if (nrow(virtual) == 1L && nrow(cash) >= 1L) {
      cash <- cash[["observed_value"]][[nrow(cash)]]
      tol <- if (nrow(tolerance) == 1L) as.numeric(tolerance$observed_value[[1L]]) else 1e-8
      if (abs(as.numeric(virtual$observed_value[[1L]]) - as.numeric(cash)) > tol) {
        findings <- c(findings, "affordability_reconciliation_failed")
      }
    }
  }
  unique(findings)
}

stage3_check_conformance <- function(witness_id, observed, sources = list()) {
  expected <- stage3_read_expected(witness_id)
  findings <- character()
  surplus <- attr(observed, "stage3_surplus_evidence_keys", exact = TRUE)
  if (length(surplus) > 0L) {
    findings <- c(findings, paste0("surplus_evidence:", surplus))
  }

  expected_keys <- stage3_observed_key(expected)
  observed_keys <- stage3_observed_key(observed)
  if (nrow(observed) != nrow(expected) || !identical(observed_keys, expected_keys)) {
    findings <- c(findings, "evidence_schema_mismatch")
    unexpected <- observed$field[!observed_keys %in% expected_keys]
    missing <- expected$field[!expected_keys %in% observed_keys]
    if (length(unexpected) > 0L) {
      findings <- c(findings, paste0("unexpected_row:", unexpected))
    }
    if (length(missing) > 0L) {
      findings <- c(findings, paste0("missing_row:", missing))
    }
  }
  n <- min(nrow(observed), nrow(expected))
  if (n == 0L) {
    return(list(pass = FALSE, findings = unique(findings)))
  }

  for (i in seq_len(n)) {
    ex <- expected[i, , drop = FALSE]
    ob <- observed[i, , drop = FALSE]
    identity_expectation <- ex$identity_expectation[[1L]]
    is_identity <- identity_expectation %in% c("equal", "changed", "captured", "absent")

    if (!is_identity) {
      expected_observed_type <- ex$expected_type[[1L]]
      if (!identical(ob$observed_type[[1L]], expected_observed_type)) {
        findings <- c(findings, paste0("type_mismatch:", ex$field[[1L]]))
      }
      if (!identical(ob$reason_code[[1L]], ex$reason_code[[1L]])) {
        findings <- c(findings, paste0("reason_code_mismatch:", ex$field[[1L]]))
      }
      if (identical(ex$expected_type[[1L]], "double")) {
        tolerance <- as.numeric(ex$tolerance[[1L]])
        actual <- suppressWarnings(as.numeric(ob$observed_value[[1L]]))
        wanted <- as.numeric(ex$expected_value[[1L]])
        if (!is.finite(actual) || abs(actual - wanted) > tolerance) {
          findings <- c(findings, paste0("value_mismatch:", ex$field[[1L]]))
        }
      } else if (identical(ex$expected_type[[1L]], "absent")) {
        if (!is.na(ob$observed_value[[1L]]) && nzchar(ob$observed_value[[1L]])) {
          findings <- c(findings, paste0("value_mismatch:", ex$field[[1L]]))
        }
      } else if (!identical(ob$observed_value[[1L]], ex$expected_value[[1L]])) {
        findings <- c(findings, paste0("value_mismatch:", ex$field[[1L]]))
      }
      next
    }

    if (identity_expectation == "captured") next
    if (identity_expectation == "absent") {
      if (!is.na(ob$observed_value[[1L]]) && nzchar(ob$observed_value[[1L]])) {
        findings <- c(findings, paste0("identity_present:", ex$identity_name[[1L]]))
      }
      next
    }
    endpoint <- stage3_identity_reference(ex, observed, sources)
    if (is.na(endpoint)) {
      findings <- c(findings, paste0("identity_reference_missing:", ex$identity_name[[1L]]))
    } else {
      equal <- identical(ob$observed_value[[1L]], endpoint)
      if ((identity_expectation == "equal" && !equal) ||
          (identity_expectation == "changed" && equal)) {
        findings <- c(findings, paste0("identity_relation_mismatch:", ex$field[[1L]]))
      }
    }
  }

  findings <- c(findings, stage3_check_semantic_invariants(observed))
  findings <- unique(findings)
  list(pass = length(findings) == 0L, findings = findings)
}
