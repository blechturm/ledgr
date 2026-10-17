indicator_history_bars <- function(n = 80L, hostile = FALSE) {
  x <- seq_len(n)
  close <- 100 + cumsum(sin(x / 3) + cos(x / 7) / 2)
  if (isTRUE(hostile)) {
    # A 1e6-to-1 level shift: drift that is invisible on a smooth path
    # becomes visible, and retained state cannot hide behind small values.
    close <- ifelse(x <= n %/% 2, 1e6 + 1e4 * sin(x / 2), 1 + abs(sin(x / 3)))
  }
  data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * (x - 1L),
    instrument_id = "AAA",
    open = c(close[[1L]], close[-n]),
    high = close * 1.01 + 0.05,
    low = close * 0.99 - 0.05,
    close = close,
    volume = 1000 + 100 * (x %% 7),
    stringsAsFactors = FALSE
  )
}

indicator_history_variant_args <- function(variant) {
  switch(
    variant,
    default = list(),
    "maType=SMA" = list(maType = "SMA"),
    "maType=EMA" = list(maType = "EMA"),
    "wilder=TRUE" = list(wilder = TRUE),
    stop("unknown catalogue variant")
  )
}

indicator_history_ttr_args <- function(family) {
  if (identical(family, "MACD")) {
    return(list(nFast = 3L, nSlow = 6L, nSig = 3L))
  }
  list(n = 5L)
}

indicator_history_ttr_input <- function(required_fields) {
  switch(
    required_fields,
    "close" = "close",
    "high,low" = "hl",
    "high,low,close" = "hlc",
    "high,low,close,volume" = "hlcv",
    stop("unknown input shape")
  )
}

indicator_history_catalogue_indicator <- function(row) {
  if (identical(row$source, "ledgr")) {
    constructor <- switch(
      row$family,
      sma = ledgr_ind_sma,
      ema = ledgr_ind_ema,
      rsi = ledgr_ind_rsi,
      returns = ledgr_ind_returns
    )
    return(constructor(5L))
  }
  do.call(
    ledgr_ind_ttr,
    c(
      list(
        row$family,
        input = indicator_history_ttr_input(row$required_fields),
        output = if (identical(row$output, "value")) NULL else row$output
      ),
      indicator_history_ttr_args(row$family),
      indicator_history_variant_args(row$variant)
    )
  )
}

indicator_history_width <- function(row) {
  args <- c(list(n = 5L), list(nFast = 3L, nSlow = 6L, nSig = 3L))
  as.integer(eval(parse(text = row$width), envir = args))
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0297] indicator history declarations are exact and refuse contradictions", {
  testthat::skip_if_not_installed("TTR")
  catalogue <- ledgr:::ledgr_indicator_history_catalogue()
  testthat::expect_identical(
    sort(unique(catalogue$family[catalogue$source == "TTR"]), method = "radix"),
    sort(ledgr_ind_ttr_warmup_rules()$ttr_fn, method = "radix")
  )
  testthat::expect_false(anyDuplicated(
    catalogue[, c("source", "family", "output", "variant")]
  ) > 0L)

  # Every catalogue row is constructible from its public constructor and the
  # constructed declarations are exactly that row.
  for (i in seq_len(nrow(catalogue))) {
    row <- catalogue[i, , drop = FALSE]
    label <- paste(row$source, row$family, row$output, row$variant)
    indicator <- indicator_history_catalogue_indicator(row)
    testthat::expect_identical(indicator$history_class, row$history_class, info = label)
    testthat::expect_identical(indicator$history_source, "catalogue", info = label)
    testthat::expect_identical(
      paste(indicator$required_fields, collapse = ","),
      row$required_fields,
      info = label
    )
    testthat::expect_identical(indicator$input_carry, row$input_carry, info = label)
    testthat::expect_identical(indicator$requires_bars, indicator_history_width(row), info = label)
    testthat::expect_identical(
      indicator$gap_contract,
      if (identical(row$history_class, "bounded")) "strict_window" else NULL,
      info = label
    )
    testthat::expect_identical(indicator$tolerance, 0, info = label)
  }

  # Contradictions and invalid declarations refuse with classed conditions.
  window_mean <- function(window) mean(window$close)
  testthat::expect_error(
    ledgr_indicator("bad", window_mean, 2L,
      gap_contract = "strict_window", history_class = "history_dependent"),
    class = "ledgr_indicator_history_contradiction"
  )
  testthat::expect_error(
    ledgr_indicator("bad", window_mean, 3L, stable_after = 2L,
      history_class = "bounded"),
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_indicator("bad", window_mean, 0L, history_class = "bounded"),
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_indicator("bad", window_mean, 2L, history_class = "recursive"),
    class = "ledgr_invalid_indicator_declaration"
  )
  for (fields in list("adj_close", character(), c("close", "close"), NA_character_)) {
    testthat::expect_error(
      ledgr_indicator("bad", window_mean, 2L, required_fields = fields),
      class = "ledgr_invalid_indicator_declaration"
    )
  }
  testthat::expect_error(
    ledgr_indicator("bad", window_mean, 2L, tolerance = -1),
    class = "ledgr_invalid_indicator_declaration"
  )
  testthat::expect_error(
    ledgr_indicator("bad", window_mean, 2L, history_class = "bounded",
      tolerance = 1e-8),
    class = "ledgr_indicator_history_contradiction"
  )
  testthat::expect_error(
    ledgr_indicator("bad", window_mean, 2L,
      series_fn = function(bars, params) bars$close, tolerance = 1e-8),
    class = "ledgr_indicator_history_contradiction"
  )
  testthat::expect_error(
    ledgr_ind_ttr("EMA", input = "close", n = 5L, history_class = "bounded"),
    class = "ledgr_indicator_history_contradiction"
  )
  testthat::expect_error(
    ledgr_ind_ttr("SMA", input = "close", n = 5L, tolerance = 1e-8),
    class = "ledgr_indicator_history_contradiction"
  )
  testthat::expect_identical(
    ledgr_ind_ttr("SMA", input = "close", n = 5L, history_class = "bounded")$history_source,
    "catalogue"
  )

  # Undeclared custom definitions are disclosed as history-dependent; bounded
  # is declared, never inferred, even for a function that is in fact bounded.
  undeclared <- ledgr_indicator("custom_mean", window_mean, 2L)
  testthat::expect_identical(undeclared$history_class, "history_dependent")
  testthat::expect_identical(undeclared$history_source, "default")
  testthat::expect_identical(undeclared$required_fields, c("open", "high", "low", "close"))
  testthat::expect_null(undeclared$gap_contract)
  disclosure <- utils::capture.output(print(undeclared))
  testthat::expect_true(any(grepl(
    "History class: history_dependent (default for an undeclared definition)",
    disclosure,
    fixed = TRUE
  )))
  strict <- ledgr_indicator("custom_strict", window_mean, 2L,
    gap_contract = "strict_window")
  declared <- ledgr_indicator("custom_bounded", window_mean, 2L,
    history_class = "bounded", required_fields = c("close", "high"))
  testthat::expect_identical(strict$history_class, "bounded")
  testthat::expect_identical(declared$gap_contract, "strict_window")
  testthat::expect_identical(declared$required_fields, c("high", "close"))
  testthat::expect_identical(declared$history_source, "declared")

  # Unregistered TTR forms follow the custom rules, not the catalogue.
  unregistered <- list(
    ledgr_ind_ttr("RSI", input = "close", n = 5L, maType = "WMA"),
    ledgr_ind_ttr("SMA", input = "close", n = 5L, requires_bars = 6L),
    ledgr_ind_ttr("EMA", input = "close", n = 5L, wilder = 1),
    ledgr_ind_ttr("DEMA", input = "close", n = 5L, requires_bars = 10L),
    ledgr_ind_ttr("runMean", input = "close", n = 5L, cumulative = TRUE)
  )
  for (indicator in unregistered) {
    testthat::expect_identical(indicator$history_class, "history_dependent", info = indicator$id)
    testthat::expect_identical(indicator$history_source, "default", info = indicator$id)
    testthat::expect_identical(indicator$input_carry, "eligible", info = indicator$id)
  }
  declared_ttr <- ledgr_ind_ttr("SMA", input = "close", n = 5L,
    requires_bars = 6L, history_class = "bounded", tolerance = 1e-10)
  testthat::expect_identical(declared_ttr$history_source, "declared")
  testthat::expect_identical(declared_ttr$tolerance, 1e-10)
  neutral <- ledgr_ind_ttr("EMA", input = "close", n = 5L, wilder = FALSE)
  testthat::expect_identical(neutral$history_source, "catalogue")

  # Existing constructors stay usable and no convergence field exists.
  testthat::expect_s3_class(ledgr_indicator("plain", window_mean, 2L), "ledgr_indicator")
  testthat::expect_false(any(grepl("converg", names(undeclared))))

  # Required-field admission tests only declared fields and names each
  # blocking field.
  fields <- list(
    open = c(1, NA, 3, 4, 5),
    high = c(1, 2, 3, NA, 5),
    low = c(1, 2, 3, 4, 5),
    close = c(1, 2, NA, 4, NA),
    volume = c(NA, 2, 3, 4, 5)
  )
  close_only <- ledgr:::ledgr_history_required_field_admission(fields, "close")
  testthat::expect_identical(close_only$available, c(TRUE, TRUE, FALSE, TRUE, FALSE))
  testthat::expect_identical(close_only$blocking_field, c("", "", "close", "", "close"))
  hlc <- ledgr:::ledgr_history_required_field_admission(fields, c("close", "high", "low"))
  testthat::expect_identical(hlc$available, c(TRUE, TRUE, FALSE, FALSE, FALSE))
  testthat::expect_identical(hlc$blocking_field, c("", "", "close", "high", "close"))
  all_fields <- ledgr:::ledgr_history_required_field_admission(
    fields, c("open", "high", "low", "close", "volume")
  )
  testthat::expect_identical(
    all_fields$blocking_field,
    c("volume", "open", "close", "high", "close")
  )
  testthat::expect_error(
    ledgr:::ledgr_history_required_field_admission(fields["close"], "high"),
    class = "ledgr_invalid_feature_input"
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0298] catalogue rows are certified on hostile fixtures", {
  testthat::skip_if_not_installed("TTR")
  catalogue <- ledgr:::ledgr_indicator_history_catalogue()
  fixtures <- list(
    smooth = indicator_history_bars(80L),
    hostile = indicator_history_bars(80L, hostile = TRUE)
  )
  scaled <- function(a, b) abs(a - b) / pmax(1, abs(b))
  for (i in seq_len(nrow(catalogue))) {
    row <- catalogue[i, , drop = FALSE]
    label <- paste(row$source, row$family, row$output, row$variant)
    indicator <- indicator_history_catalogue_indicator(row)
    width <- indicator$requires_bars
    state_delta <- 0
    for (fixture_name in names(fixtures)) {
      bars <- fixtures[[fixture_name]]
      n <- nrow(bars)
      full <- ledgr:::ledgr_compute_feature_series(bars, indicator)
      positions <- unique(c(seq.int(indicator$stable_after, n, by = 7L), n))
      for (k in positions) {
        prefix <- ledgr:::ledgr_compute_feature_series(bars[seq_len(k), , drop = FALSE], indicator)
        testthat::expect_identical(prefix[[k]], full[[k]],
          info = paste(label, fixture_name, "exact prefix invariance at", k))
        window <- ledgr:::ledgr_compute_feature_series(
          bars[seq.int(k - width + 1L, k), , drop = FALSE],
          indicator
        )[[width]]
        delta <- scaled(window, full[[k]])
        if (identical(row$history_class, "bounded")) {
          testthat::expect_true(
            is.finite(delta) && delta <= 1e-4,
            info = paste(label, fixture_name, "bounded window equals the full series at", k)
          )
        } else if (is.finite(delta)) {
          state_delta <- max(state_delta, delta)
        }
      }
    }
    if (identical(row$history_class, "history_dependent")) {
      testthat::expect_gt(state_delta, 1e-3, label = paste(label, "retained state"))
    }
  }
})

indicator_history_active <- function(indicator) {
  ledgr:::ledgr_active_feature_fingerprint(
    ledgr:::ledgr_precompute_feature_def_from_indicator(indicator)
  )
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0299] rule-4 feature identity binds every history declaration", {
  testthat::skip_if_not_installed("TTR")
  window_mean <- function(window) mean(window$close)
  series_mean <- function(bars, params) {
    stats::filter(bars$close, rep(1 / 3, 3), sides = 1)
  }
  make <- function(...) {
    args <- utils::modifyList(
      list(
        id = "identity_probe",
        fn = window_mean,
        series_fn = series_mean,
        requires_bars = 3L,
        history_class = "bounded",
        required_fields = "close"
      ),
      list(...)
    )
    do.call(ledgr_indicator, args)
  }
  base <- make()
  base_active <- indicator_history_active(base)
  carry_excluded <- ledgr:::ledgr_indicator_apply_declarations(
    base,
    ledgr:::ledgr_indicator_declare(
      history_class = "bounded",
      required_fields = "close",
      input_carry = "excluded",
      has_series_fn = TRUE,
      history_source = "declared",
      required_fields_source = "declared"
    )
  )
  changed <- list(
    history_class = make(history_class = "history_dependent"),
    required_field = make(required_fields = c("close", "volume")),
    window = make(requires_bars = 4L),
    readiness = make(stable_after = 5L),
    tolerance = make(tolerance = 1e-9),
    input_carry = carry_excluded
  )
  for (name in names(changed)) {
    testthat::expect_false(
      identical(indicator_history_active(changed[[name]]), base_active),
      info = name
    )
  }
  # Gap behavior is fully determined by the class: strict windows are
  # bounded and history-dependent definitions restart per segment.
  testthat::expect_identical(
    ledgr:::ledgr_feature_def_declarations(changed$history_class)$gap_behavior,
    "segment_restart"
  )
  testthat::expect_identical(
    ledgr:::ledgr_feature_def_declarations(base)$gap_behavior,
    "strict_window"
  )
  # Dense identity omits the declarations (dense execution is frozen).
  testthat::expect_identical(
    ledgr:::ledgr_indicator_fingerprint(changed$history_class),
    ledgr:::ledgr_indicator_fingerprint(base)
  )

  # Display-only metadata does not enter identity.
  same <- list(
    gap_contract_spelling = make(history_class = NULL, gap_contract = "strict_window"),
    source_label = make(source = "TTR"),
    default_fields_spelling = ledgr_indicator(
      "undeclared_probe", window_mean, 3L,
      required_fields = c("open", "high", "low", "close")
    )
  )
  testthat::expect_identical(indicator_history_active(same$gap_contract_spelling), base_active)
  testthat::expect_identical(indicator_history_active(same$source_label), base_active)
  testthat::expect_identical(
    indicator_history_active(same$default_fields_spelling),
    indicator_history_active(ledgr_indicator("undeclared_probe", window_mean, 3L))
  )
  relabelled <- base
  relabelled$history_source <- "catalogue"
  relabelled$required_fields_source <- "default"
  testthat::expect_identical(indicator_history_active(relabelled), base_active)

  # TTR version and algorithm-changing arguments change identity.
  ttr <- ledgr_ind_ttr("RSI", input = "close", n = 5L)
  older <- ttr
  older$params$ttr_version <- "0.0.1"
  testthat::expect_false(identical(indicator_history_active(older), indicator_history_active(ttr)))
  testthat::expect_false(identical(
    indicator_history_active(ledgr_ind_ttr("RSI", input = "close", n = 5L, maType = "SMA")),
    indicator_history_active(ttr)
  ))

  # The stored availability config carries exactly the calculation-affecting
  # declarations, so changing one changes config identity.
  snapshot <- availability_runtime_fixture(days = 6L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  golden_bounded <- ledgr_indicator(
    "golden_bounded",
    function(window) mean(window$close),
    requires_bars = 3L,
    history_class = "bounded",
    required_fields = "close"
  )
  experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$hold(),
    features = list(ledgr_ind_sma(2L), ledgr_ind_returns(1L), golden_bounded),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(experiment, run_id = "golden-rule4")
  on.exit(close(bt), add = TRUE)
  stored <- bt$config$features$defs
  ids <- vapply(stored, `[[`, character(1), "id")
  stored_bounded <- stored[[match("golden_bounded", ids)]]
  testthat::expect_identical(
    sort(names(stored_bounded), method = "radix"),
    sort(c(
      "id", "params", "requires_bars", "stable_after", "fingerprint",
      "gap_contract", "history_class", "required_fields", "input_carry",
      "tolerance"
    ), method = "radix")
  )
  for (field in c("history_class", "required_fields", "input_carry", "tolerance")) {
    mutated <- bt$config
    position <- match("golden_bounded", ids)
    mutated$features$defs[[position]][[field]] <- switch(
      field,
      history_class = "history_dependent",
      required_fields = c("close", "volume"),
      input_carry = "excluded",
      tolerance = 1e-9
    )
    testthat::expect_false(
      identical(config_hash(mutated), config_hash(bt$config)),
      info = field
    )
  }

  # Final rule-4 feature and config golden fixtures (Workstream 43). The
  # literals are produced by the rule-4 identity payloads at this commit.
  if (!ledgr_test_in_coverage()) {
    golden <- c(
      sma_20 = indicator_history_active(ledgr_ind_sma(20L)),
      return_5 = indicator_history_active(ledgr_ind_returns(5L)),
      ema_10 = indicator_history_active(ledgr_ind_ema(10L)),
      rsi_14 = indicator_history_active(ledgr_ind_rsi(14L)),
      golden_custom = indicator_history_active(ledgr_indicator(
        "golden_custom", function(window) mean(window$close), requires_bars = 3L
      ))
    )
    testthat::expect_identical(golden, c(
      sma_20 = "e12f133395bfadbcd49fb2077ca6e38553d8926dce53f596b0385363636a98e4",
      return_5 = "f8af0b3d73692caef5fe5fae66d4f6a71a946e1cfed5644f9c76d9c784734c4e",
      ema_10 = "5438513a00599cdbebcca04e443f88a672f3ae8191b1753bb08ae586b8ade378",
      rsi_14 = "5a0f277d114d37e0f21d3a252df27657add5826fe5c36459595c7d6dc96ecb78",
      golden_custom = "f31d4b912ffccd148671fe724fb312e6c55c2e743d6df4e5fc67afdfb97749a6"
    ))
    if (identical(as.character(utils::packageVersion("TTR")), "0.24.4")) {
      testthat::expect_identical(
        indicator_history_active(ledgr_ind_ttr("EMA", input = "close", n = 10L)),
        "954ad303c233b3a69f66b10c5e996d3182eab61c6fe60369729239a228886a44"
      )
      testthat::expect_identical(
        indicator_history_active(
          ledgr_ind_ttr("RSI", input = "close", n = 14L, maType = "SMA")
        ),
        "3d4ac0edf6ee0c7f86be12517be7bbf20a294b24e352c4e105f1c9de4a51f381"
      )
    }
    testthat::expect_identical(
      bt$config$features$feature_set_hash,
      "3286cf4679b732aadc8b73f009e4c2f05806a04d92291cd609bfaf27e3cb3ea9"
    )
    testthat::expect_identical(
      config_hash(bt$config),
      "c470ce4f43c231ca01012e13345f82515392636c91a0d7e5fbe07195b8ac79cb"
    )
  }
})
