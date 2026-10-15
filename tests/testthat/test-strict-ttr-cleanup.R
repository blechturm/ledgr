workstream37_bars <- function(n = 12L) {
  values <- 100 + seq_len(n) + sin(seq_len(n))
  data.frame(
    ts_utc = as.POSIXct("2024-01-01", tz = "UTC") + 86400 * seq_len(n),
    instrument_id = "AAA",
    open = values - 0.5,
    high = values + 1,
    low = values - 1,
    close = values,
    volume = 1000,
    stringsAsFactors = FALSE
  )
}

workstream37_scalar_oracle <- function(bars, definition) {
  n <- nrow(bars)
  width <- as.integer(definition$stable_after)
  out <- rep(NA_real_, n)
  if (n < width) return(out)
  columns <- intersect(c("open", "high", "low", "close"), names(bars))
  for (i in seq.int(width, n)) {
    window <- bars[seq.int(i - width + 1L, i), , drop = FALSE]
    complete <- all(vapply(window[columns], function(x) {
      values <- suppressWarnings(as.numeric(x))
      !anyNA(values) && all(is.finite(values))
    }, logical(1)))
    if (!complete) next
    out[[i]] <- ledgr:::ledgr_normalize_feature_scalar_output(
      ledgr:::ledgr_call_feature_fn(
        definition$fn,
        window,
        if (is.null(definition$params)) list() else definition$params
      ),
      definition$id
    )
  }
  out
}

workstream37_custom_indicator <- function(n = 3L) {
  ledgr_indicator(
    id = paste0("custom_strict_", n),
    fn = function(window, params) mean(window$close),
    series_fn = function(bars, params) {
      c(rep(NA_real_, nrow(bars) - 1L), mean(bars$close))
    },
    requires_bars = n,
    params = list(n = n),
    gap_contract = "strict_window"
  )
}

workstream37_clone_function <- function(fn, env) {
  out <- fn
  environment(out) <- env
  out
}

workstream37_scalar_call_symbols <- function(fn) {
  all.names(body(fn), functions = TRUE, unique = TRUE)
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0276] strict TTR cleanup is exact and provenance-bounded", {
  testthat::skip_if_not_installed("TTR")
  dense <- workstream37_bars()
  gapped <- dense
  gap_rows <- c(1L, 7L, nrow(gapped))
  gapped[gap_rows, c("open", "high", "low", "close")] <- NA_real_

  ttr <- ledgr:::ledgr_precompute_feature_def_from_indicator(
    ledgr_ind_ttr("SMA", input = "close", n = 3L)
  )
  custom <- ledgr:::ledgr_precompute_feature_def_from_indicator(
    workstream37_custom_indicator(3L)
  )
  testthat::expect_identical(
    ledgr:::ledgr_strict_builtin_kind(ttr),
    "ttr_sma_scalar"
  )
  testthat::expect_null(ledgr:::ledgr_strict_builtin_kind(custom))
  dense_engine_version <- ledgr:::ledgr_feature_engine_version(FALSE)
  availability_engine_version <- ledgr:::ledgr_feature_engine_version(TRUE)

  fixtures <- list(
    empty = dense[0, , drop = FALSE],
    short = dense[1:2, , drop = FALSE],
    complete = dense,
    leading_internal_trailing = gapped,
    all_missing = transform(
      dense,
      open = NA_real_, high = NA_real_, low = NA_real_, close = NA_real_
    )
  )
  invalid_short <- dense[1:2, , drop = FALSE]
  invalid_short$open <- I(list(new.env(), new.env()))
  testthat::expect_identical(
    ledgr:::ledgr_compute_feature_series_strict(invalid_short, custom),
    rep(NA_real_, 2L)
  )
  for (i in seq_len(nrow(dense))) {
    fixture <- dense
    fixture[i, c("open", "high", "low", "close")] <- NA_real_
    fixtures[[paste0("missing_at_", i)]] <- fixture
  }

  old_mask <- function(bars, width) {
    out <- rep(FALSE, nrow(bars))
    if (nrow(bars) < width) return(out)
    columns <- intersect(c("open", "high", "low", "close"), names(bars))
    for (i in seq.int(width, nrow(bars))) {
      window <- bars[seq.int(i - width + 1L, i), , drop = FALSE]
      out[[i]] <- all(vapply(window[columns], function(x) {
        values <- suppressWarnings(as.numeric(x))
        !anyNA(values) && all(is.finite(values))
      }, logical(1)))
    }
    out
  }
  for (fixture_name in names(fixtures)) {
    testthat::expect_identical(
      ledgr:::ledgr_strict_complete_window_mask(fixtures[[fixture_name]], 3L),
      old_mask(fixtures[[fixture_name]], 3L),
      info = paste(fixture_name, "complete-window mask")
    )
  }

  for (fixture_name in c("complete", "leading_internal_trailing")) {
    bars <- fixtures[[fixture_name]]
    for (definition in list(ttr = ttr, custom = custom)) {
      expected <- workstream37_scalar_oracle(bars, definition)
      runtime <- ledgr:::ledgr_compute_feature_series_strict(bars, definition)
      fingerprint <- ledgr:::ledgr_feature_def_fingerprint(definition)
      precomputed <- ledgr:::ledgr_precompute_payload(
        stats::setNames(list(definition), fingerprint),
        list(AAA = bars),
        availability_active = TRUE
      )[[fingerprint]]$values$AAA
      testthat::expect_identical(runtime, expected, info = paste(
        fixture_name,
        definition$id,
        "runtime scalar oracle"
      ))
      testthat::expect_identical(precomputed, expected, info = paste(
        fixture_name,
        definition$id,
        "precompute scalar oracle"
      ))
    }
  }

  original_ttr_call <- ledgr:::ledgr_ttr_call
  original_mask <- ledgr:::ledgr_strict_complete_window_mask
  ttr_calls <- 0L
  mask_calls <- 0L
  testthat::local_mocked_bindings(
    ledgr_ttr_call = function(...) {
      ttr_calls <<- ttr_calls + 1L
      original_ttr_call(...)
    },
    ledgr_strict_complete_window_mask = function(...) {
      mask_calls <<- mask_calls + 1L
      original_mask(...)
    },
    .package = "ledgr"
  )
  ttr_kind <- "ttr_sma_scalar"
  expected_complete <- sum(old_mask(gapped, 3L))
  ledgr:::ledgr_compute_feature_series_strict(gapped, ttr, kind = ttr_kind)
  testthat::expect_identical(ttr_calls, as.integer(expected_complete))
  testthat::expect_identical(mask_calls, 1L)

  for (fixture_name in names(fixtures)) {
    mask_calls <- 0L
    ledgr:::ledgr_compute_feature_series_strict(
      fixtures[[fixture_name]],
      custom,
      kind = NULL
    )
    testthat::expect_identical(
      mask_calls,
      if (nrow(fixtures[[fixture_name]]) < 3L) 0L else 1L,
      info = paste(fixture_name, "computes completeness at most once")
    )
  }

  hand_built <- ledgr_indicator(
    id = "hand_built_ttr_label",
    fn = function(window, params) mean(window$close) + 1,
    series_fn = function(bars, params) {
      c(rep(NA_real_, nrow(bars) - 1L), mean(bars$close))
    },
    requires_bars = 3L,
    params = ttr$params,
    source = "TTR",
    gap_contract = "strict_window"
  )
  hand_built <- ledgr:::ledgr_precompute_feature_def_from_indicator(hand_built)
  testthat::expect_null(ledgr:::ledgr_strict_builtin_kind(hand_built))
  testthat::expect_error(
    ledgr:::ledgr_compute_feature_series_strict(dense, hand_built),
    class = "ledgr_indicator_gap_parity"
  )

  mismatched_body_env <- new.env(parent = asNamespace("ledgr"))
  mismatched_body <- ttr
  mismatched_body$fn <- workstream37_clone_function(
    mismatched_body$fn,
    mismatched_body_env
  )
  body(mismatched_body$fn) <- quote({
    selected <- ledgr_ttr_call(window, params)
    as.numeric(utils::tail(selected, 1L)) + 1
  })
  mismatched_body$series_fn <- workstream37_clone_function(
    mismatched_body$series_fn,
    mismatched_body_env
  )
  testthat::expect_true(
    identical(environment(mismatched_body$fn), mismatched_body_env) &&
      identical(environment(mismatched_body$series_fn), mismatched_body_env) &&
      identical(parent.env(mismatched_body_env), asNamespace("ledgr"))
  )
  mismatched_body_kind <- ledgr:::ledgr_strict_builtin_kind(mismatched_body)
  testthat::expect_null(mismatched_body_kind)
  testthat::expect_error(
    ledgr:::ledgr_compute_feature_series_strict(
      dense,
      mismatched_body,
      kind = mismatched_body_kind
    ),
    class = "ledgr_indicator_gap_parity"
  )

  non_namespace_parent <- new.env(parent = asNamespace("ledgr"))
  wrong_parent_env <- new.env(parent = non_namespace_parent)
  wrong_parent <- ttr
  wrong_parent$fn <- workstream37_clone_function(ttr$fn, wrong_parent_env)
  wrong_parent$series_fn <- workstream37_clone_function(
    ttr$series_fn,
    wrong_parent_env
  )
  wrong_parent_kind <- ledgr:::ledgr_strict_builtin_kind(wrong_parent)
  testthat::expect_null(wrong_parent_kind)
  ttr_calls <- 0L
  ledgr:::ledgr_compute_feature_series_strict(
    dense,
    wrong_parent,
    kind = wrong_parent_kind
  )
  testthat::expect_identical(
    ttr_calls,
    2L * as.integer(sum(old_mask(dense, 3L)))
  )

  distinct <- ttr
  distinct$series_fn <- workstream37_clone_function(
    distinct$series_fn,
    new.env(parent = asNamespace("ledgr"))
  )
  testthat::expect_false(identical(
    environment(distinct$fn),
    environment(distinct$series_fn)
  ))
  testthat::expect_null(ledgr:::ledgr_strict_builtin_kind(distinct))
  ttr_calls <- 0L
  ledgr:::ledgr_compute_feature_series_strict(dense, distinct, kind = NULL)
  testthat::expect_identical(
    ttr_calls,
    2L * as.integer(sum(old_mask(dense, 3L)))
  )

  template <- ledgr_ind_ttr("SMA", input = "close", n = 3L)
  call_symbols <- unique(c(
    codetools::findGlobals(template$fn, merge = FALSE)$functions,
    codetools::findGlobals(template$series_fn, merge = FALSE)$functions
  ))
  testthat::expect_true(all(c("ledgr_ttr_call", "as.numeric", "::") %in% call_symbols))
  for (symbol in c("ledgr_ttr_call", "as.numeric", "::")) {
    shadow_env <- new.env(parent = asNamespace("ledgr"))
    shadow_calls <- 0L
    value <- if (identical(symbol, "ledgr_ttr_call")) {
      function(...) {
        shadow_calls <<- shadow_calls + 1L
        original_ttr_call(...)
      }
    } else {
      get(symbol, envir = baseenv(), inherits = TRUE)
    }
    assign(symbol, value, envir = shadow_env)
    shadowed <- ttr
    shadowed$fn <- workstream37_clone_function(ttr$fn, shadow_env)
    shadowed$series_fn <- workstream37_clone_function(ttr$series_fn, shadow_env)
    testthat::expect_null(
      ledgr:::ledgr_strict_builtin_kind(shadowed),
      info = paste("local call-symbol binding", symbol)
    )
    if (identical(symbol, "ledgr_ttr_call")) {
      ledgr:::ledgr_compute_feature_series_strict(dense, shadowed, kind = NULL)
      testthat::expect_identical(
        shadow_calls,
        2L * as.integer(sum(old_mask(dense, 3L)))
      )
    }
  }

  for (indicator in list(
    ledgr_ind_ttr("EMA", input = "close", n = 3L),
    ledgr_ind_ttr("RSI", input = "close", n = 3L),
    ledgr_ind_ttr(
      "MACD",
      input = "close",
      output = "macd",
      nFast = 2L,
      nSlow = 3L,
      nSig = 2L
    )
  )) {
    testthat::expect_null(indicator$gap_contract)
  }

  scalar_source <- paste(deparse(
    body(ledgr:::ledgr_compute_feature_series_strict_scalar)
  ), collapse = "\n")
  strict_source <- paste(deparse(
    body(ledgr:::ledgr_compute_feature_series_strict)
  ), collapse = "\n")
  precompute_source <- paste(deparse(
    body(ledgr:::ledgr_precompute_payload)
  ), collapse = "\n")
  runtime_source <- paste(deparse(
    body(ledgr:::ledgr_run_fold_impl)
  ), collapse = "\n")
  sweep_source <- paste(deparse(
    body(ledgr:::ledgr_sweep_impl)
  ), collapse = "\n")
  testthat::expect_identical(
    lengths(regmatches(
      scalar_source,
      gregexpr("ledgr_strict_complete_window_mask", scalar_source, fixed = TRUE)
    )),
    1L
  )
  testthat::expect_length(
    intersect(
      c("is.finite", "anyNA", "complete.cases"),
      workstream37_scalar_call_symbols(
        ledgr:::ledgr_compute_feature_series_strict_scalar
      )
    ),
    0L
  )
  testthat::expect_match(strict_source, "check_series_parity = FALSE", fixed = TRUE)
  for (source in list(precompute_source, runtime_source)) {
    testthat::expect_match(source, "ledgr_strict_builtin_kind", fixed = TRUE)
    testthat::expect_match(source, "ledgr_compute_feature_series_strict", fixed = TRUE)
  }
  testthat::expect_match(sweep_source, "ledgr_precompute_payload", fixed = TRUE)
  testthat::expect_match(sweep_source, "feature_engine_version", fixed = TRUE)

  testthat::expect_identical(
    dense_engine_version,
    "80d1ae6d2165196044db3f0d1944d69f21b76e264d2df16df49e23f448a7c681"
  )
  testthat::expect_identical(
    availability_engine_version,
    "25d86252352ea2228c9b49cade9eb482e21adf41d01f1ec5ce4a8a7db5809281"
  )
})
