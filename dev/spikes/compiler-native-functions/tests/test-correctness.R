compiler_spike_equal <- function(actual, expected, tolerance = 1e-10) {
  if (!identical(dim(actual), dim(expected)) || length(actual) != length(expected)) {
    return(list(ok = FALSE, error = Inf, detail = "shape mismatch"))
  }
  finite <- is.finite(actual) & is.finite(expected)
  same_special <- identical(is.na(actual), is.na(expected)) &&
    identical(is.nan(actual), is.nan(expected)) &&
    identical(is.infinite(actual), is.infinite(expected)) &&
    identical(sign(actual[is.infinite(actual)]), sign(expected[is.infinite(expected)]))
  error <- if (any(finite)) max(abs(actual[finite] - expected[finite])) else 0
  list(
    ok = isTRUE(same_special) && is.finite(error) && error <= tolerance,
    error = error,
    detail = if (same_special) "special-value pattern agrees" else "special-value pattern differs"
  )
}

compiler_spike_case_row <- function(
  case,
  workload,
  variant,
  status,
  max_abs_error = NA_real_,
  detail = ""
) {
  data.frame(
    case = case,
    workload = workload,
    variant = variant,
    status = status,
    max_abs_error = max_abs_error,
    detail = detail,
    stringsAsFactors = FALSE
  )
}

compiler_spike_compare_variants <- function(
  case,
  workload,
  variants,
  args,
  expected,
  tolerance = 1e-10,
  gut = ""
) {
  rows <- list()
  for (name in names(variants)) {
    result <- tryCatch(do.call(variants[[name]], args), error = identity)
    if (inherits(result, "condition")) {
      rows[[length(rows) + 1L]] <- compiler_spike_case_row(
        case,
        workload,
        name,
        "fail",
        detail = compiler_spike_condition(result)
      )
      next
    }
    if (identical(gut, workload) && name == "rcpp") {
      result[length(result)] <- result[length(result)] - 1
    }
    comparison <- compiler_spike_equal(result, expected, tolerance)
    rows[[length(rows) + 1L]] <- compiler_spike_case_row(
      case,
      workload,
      name,
      if (comparison$ok) "pass" else "fail",
      comparison$error,
      comparison$detail
    )
  }
  do.call(rbind, rows)
}

compiler_spike_run_correctness <- function(compiled, gut = "") {
  variants <- compiled$variants
  rows <- list()

  x <- compiler_spike_make_matrix(40L, 3L, 11L)
  expected <- rolling_variance_reference(x, 5L)
  rows[[length(rows) + 1L]] <- compiler_spike_compare_variants(
    "C01_numerical_complete",
    "numerical",
    variants$numerical,
    list(x, 5L),
    expected,
    gut = gut
  )

  x <- compiler_spike_make_matrix(12L, 2L, 12L)
  expected <- rolling_variance_reference(x, 20L)
  rows[[length(rows) + 1L]] <- compiler_spike_compare_variants(
    "C02_numerical_window_exceeds_rows",
    "numerical",
    variants$numerical,
    list(x, 20L),
    expected,
    gut = gut
  )

  state <- compiler_spike_make_stateful_data(32L, 13L)
  state$signals[] <- 0
  state_args <- list(state$prices, state$signals, 1e6, 0.001, 0.95)
  expected <- do.call(stateful_reference, state_args)
  rows[[length(rows) + 1L]] <- compiler_spike_compare_variants(
    "C03_stateful_no_trades",
    "stateful",
    variants$stateful,
    state_args,
    expected,
    gut = gut
  )

  state <- compiler_spike_make_stateful_data(64L, 14L)
  state_args <- list(state$prices, state$signals, 1e6, 0.0015, 0.83)
  expected <- do.call(stateful_reference, state_args)
  rows[[length(rows) + 1L]] <- compiler_spike_compare_variants(
    "C04_stateful_trades_and_costs",
    "stateful",
    variants$stateful,
    state_args,
    expected,
    gut = gut
  )

  batch <- compiler_spike_make_batch_data(48L, 4L, 15L)
  batch_args <- list(
    batch$prices,
    batch$signals,
    1e6,
    0.001,
    batch$equity_fractions
  )
  expected <- do.call(batch_repeated_reference, batch_args)
  rows[[length(rows) + 1L]] <- compiler_spike_compare_variants(
    "C05_parameter_batch",
    "batch",
    variants$batch,
    batch_args,
    expected,
    gut = gut
  )

  special_cases <- list(
    C06_missing_NA = c(1, NA_real_, 3),
    C07_missing_NaN = c(1, NaN, 3),
    C08_missing_Inf = c(-Inf, 1, Inf)
  )
  for (case in names(special_cases)) {
    input <- special_cases[[case]]
    for (name in names(variants$special)) {
      result <- tryCatch(variants$special[[name]](input), error = identity)
      if (name == "quickr" && case == "C06_missing_NA") {
        observed <- if (inherits(result, "condition")) {
          paste("error:", compiler_spike_condition(result))
        } else {
          paste("observed", paste(format(result), collapse = ","))
        }
        rows[[length(rows) + 1L]] <- compiler_spike_case_row(
          case,
          "missing",
          name,
          "unsupported",
          detail = paste("quickr 0.3.0 documents NA values as unsupported;", observed)
        )
      } else if (inherits(result, "condition")) {
        rows[[length(rows) + 1L]] <- compiler_spike_case_row(
          case,
          "missing",
          name,
          "fail",
          detail = compiler_spike_condition(result)
        )
      } else {
        comparison <- compiler_spike_equal(result, input)
        rows[[length(rows) + 1L]] <- compiler_spike_case_row(
          case,
          "missing",
          name,
          if (comparison$ok) "pass" else "fail",
          comparison$error,
          comparison$detail
        )
      }
    }
  }

  masked <- matrix(c(1, 999, 3, 4, -777, 6, 7, 8, 9), nrow = 3L, byrow = TRUE)
  valid <- matrix(c(1L, 0L, 1L, 1L, 0L, 1L, 1L, 1L, 1L), nrow = 3L, byrow = TRUE)
  expected <- masked_row_mean_reference(masked, valid)
  rows[[length(rows) + 1L]] <- compiler_spike_compare_variants(
    "C09_explicit_validity_mask",
    "masked",
    variants$masked,
    list(masked, valid),
    expected,
    gut = gut
  )

  state <- compiler_spike_make_stateful_data(96L, 16L)
  args <- list(state$prices, state$signals, 1e6, 0.001, 0.9)
  for (name in names(variants$stateful)) {
    first <- tryCatch(do.call(variants$stateful[[name]], args), error = identity)
    second <- tryCatch(do.call(variants$stateful[[name]], args), error = identity)
    ok <- !inherits(first, "condition") && !inherits(second, "condition") &&
      identical(first, second)
    rows[[length(rows) + 1L]] <- compiler_spike_case_row(
      "C10_repeated_execution",
      "stateful",
      name,
      if (ok) "pass" else "fail",
      if (ok) 0 else NA_real_,
      if (ok) "byte-identical repeated result" else "repeat differed or errored"
    )
  }

  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  result
}
