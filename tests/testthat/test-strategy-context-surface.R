testthat::test_that("[LTB-0084] retired context names stay absent and rule hashes stay stable", {
  universe <- c("AAA", "BBB")
  bars <- data.frame(
    instrument_id = universe,
    ts_utc = as.POSIXct(rep("2026-01-02 21:00:00", 2L), tz = "UTC"),
    open = c(10, 20),
    high = c(11, 21),
    low = c(9, 19),
    close = c(10.5, 20.5),
    volume = c(100, 200),
    stringsAsFactors = FALSE
  )
  ctx <- ledgr:::ledgr_pulse_context(
    run_id = "surface",
    ts_utc = bars$ts_utc[[1L]],
    universe = universe,
    bars = bars,
    positions = c(AAA = 0, BBB = 3),
    cash = 100,
    equity = 161.5
  )

  testthat::expect_null(ctx$positions)
  testthat::expect_null(ctx$targets)
  testthat::expect_null(ctx$current_targets)
  testthat::expect_null(ctx$safety_state)
  testthat::expect_identical(ctx$vec$position, c(0, 3))
  testthat::expect_identical(
    vapply(universe, ctx$position, numeric(1)),
    stats::setNames(ctx$vec$position, universe)
  )
  intent <- ctx$hold()
  intent[["BBB"]] <- 0
  testthat::expect_identical(ctx$position("BBB"), 3)
  testthat::expect_identical(ctx$vec$position[[2L]], 3)

  exports <- getNamespaceExports("ledgr")
  testthat::expect_true(all(c("ledgr_rule_argmax", "ledgr_rule_argmin") %in% exports))
  testthat::expect_false(any(c("ledgr_select_argmax", "ledgr_select_argmin") %in% exports))
  rule <- ledgr_rule_argmax("sharpe_ratio")
  testthat::expect_identical(
    ledgr:::ledgr_selection_rule_payload(rule),
    list(
      type_id = "argmax",
      schema_version = "v1",
      metric = "sharpe_ratio",
      direction = "max"
    )
  )
  testthat::expect_identical(
    rule$selection_rule_hash,
    "cc82a9145ed03d08af24c05dbca0dadc824af9772131386868e335a2e28bbd57"
  )
})

strategy_context_surface_capture <- function(ctx, params) {
  classify <- function(value, name, scope) {
    if (is.null(value)) return("NULL")
    if (is.function(value)) return("function")
    if (is.data.frame(value)) return("data_frame")
    if (is.list(value)) return("list")
    prefix <- if (is.character(value)) {
      "character"
    } else if (is.logical(value)) {
      "logical"
    } else if (is.integer(value)) {
      "integer"
    } else if (is.numeric(value)) {
      "numeric"
    } else {
      typeof(value)
    }
    vector_shape <- identical(scope, "plane") ||
      name %in% c("universe", "members")
    paste0(prefix, if (vector_shape || length(value) != 1L) {
      "_vector"
    } else {
      "_scalar"
    })
  }
  public <- names(ctx)[!startsWith(names(ctx), ".")]
  plane <- names(ctx$vec)
  encode <- function(names, values, scope) {
    paste(
      paste(names, vapply(
        seq_along(values),
        function(index) classify(values[[index]], names[[index]], scope),
        character(1)
      ),
            sep = "="),
      collapse = ";"
    )
  }
  previous <- ctx$state_prev$surface_history
  if (is.null(previous)) previous <- list()
  entry <- list(
    top = encode(public, ctx[public], "top"),
    plane = encode(plane, ctx$vec[plane], "plane"),
    plane_lengths = paste(vapply(
      ctx$vec[plane],
      function(value) if (is.function(value)) -1L else length(value),
      integer(1)
    ), collapse = ","),
    plane_named = paste(vapply(
      ctx$vec[plane],
      function(value) is.function(value) || is.null(names(value)),
      logical(1)
    ), collapse = ","),
    universe = paste(ctx$universe, collapse = ","),
    members = paste(
      if (is.null(ctx$members)) ctx$universe else ctx$members,
      collapse = ","
    )
  )
  target <- ctx$hold()
  step <- length(previous) + 1L
  if (step == 1L && "AAA" %in% names(target)) target[["AAA"]] <- 1
  if (step == 2L && "AAA" %in% names(target)) target[["AAA"]] <- 0
  list(
    targets = target,
    state_update = list(surface_history = c(previous, list(entry)))
  )
}

strategy_context_surface_table <- function() {
  root <- ledgr_test_source_root()
  lines <- trimws(readLines(
    file.path(root, "man", "ledgr_strategy_context.Rd"),
    warn = FALSE
  ))
  rows <- lines[grepl("^(top|plane) \\|", lines)]
  fields <- strsplit(rows, "|", fixed = TRUE)
  out <- as.data.frame(do.call(rbind, lapply(fields, trimws)),
                       stringsAsFactors = FALSE)
  names(out) <- c(
    "scope", "member", "applies", "shape", "axis", "units",
    "missingness", "counterpart"
  )
  out
}

strategy_context_surface_shape_matches <- function(observed, documented) {
  if (documented == "nullable_scalar") return(observed %in% c("NULL", "integer_scalar", "numeric_scalar"))
  if (documented == "nullable_list") return(observed %in% c("NULL", "list"))
  identical(observed, documented)
}

testthat::test_that("[LTB-0091] authored surface table matches real callback contexts", {
  table <- strategy_context_surface_table()
  testthat::expect_identical(anyDuplicated(table[, c("scope", "member")]), 0L)
  testthat::expect_true(all(table$applies %in% c("all", "availability")))

  dates <- as.Date("2026-02-01") + 0:3
  bars <- data.frame(
    ts_utc = as.POSIXct(paste(dates, "16:00:00"), tz = "UTC"),
    instrument_id = "AAA",
    open = 10:13, high = 10:13, low = 10:13, close = 10:13,
    volume = 1000,
    stringsAsFactors = FALSE
  )
  dense_snapshot <- ledgr_snapshot_from_df(bars)
  membership_input <- data.frame(
    effective_from = as.POSIXct(paste(dates[1:2], "16:00:00"), tz = "UTC"),
    knowledge_time = as.POSIXct(paste(dates[1:2], "16:00:00"), tz = "UTC") - 1,
    source = "surface",
    stringsAsFactors = FALSE
  )
  membership_input$members <- list("AAA", character())
  membership <- ledgr_facts_membership_snapshots(
    membership_input,
    universe_id = "surface",
    complete = TRUE
  )
  availability_snapshot <- availability_runtime_fixture(
    days = 4L,
    membership = membership
  )
  on.exit(ledgr_snapshot_close(dense_snapshot), add = TRUE)
  on.exit(ledgr_snapshot_close(availability_snapshot), add = TRUE)
  features <- ledgr_feature_map(signal = ledgr_ind_sma(2))
  dense_run <- ledgr_run(ledgr_experiment(
    dense_snapshot,
    strategy_context_surface_capture,
    features = features,
    cost_model = ledgr_cost_zero()
  ))
  availability_run <- ledgr_run(ledgr_experiment(
    availability_snapshot,
    strategy_context_surface_capture,
    universe = ledgr_universe_members("surface"),
    features = features,
    opening = ledgr_opening(
      cash = 1e5,
      positions = c(AAA = 1),
      cost_basis = c(AAA = 10)
    ),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  ))
  on.exit(close(dense_run), add = TRUE)
  on.exit(close(availability_run), add = TRUE)
  dense <- availability_last_state(dense_run)$surface_history[[1L]]
  availability_history <- availability_last_state(availability_run)$surface_history
  held <- availability_history[[2L]]
  empty <- availability_history[[3L]]
  testthat::expect_identical(held$members, "")
  testthat::expect_identical(held$universe, "AAA")
  testthat::expect_identical(empty$members, "")
  testthat::expect_identical(empty$universe, "")

  decode <- function(value) {
    pieces <- strsplit(value, ";", fixed = TRUE)[[1L]]
    stats::setNames(
      sub("^[^=]*=", "", pieces),
      sub("=.*$", "", pieces)
    )
  }
  assert_surface <- function(observed, mode) {
    expected <- table[table$applies == "all" |
                        (mode == "availability" & table$applies == "availability"), ]
    for (scope in c("top", "plane")) {
      actual <- decode(observed[[scope]])
      wanted <- expected[expected$scope == scope, ]
      testthat::expect_identical(names(actual), wanted$member)
      testthat::expect_true(all(vapply(
        seq_len(nrow(wanted)),
        function(index) strategy_context_surface_shape_matches(
          actual[[wanted$member[[index]]]], wanted$shape[[index]]
        ),
        logical(1)
      )))
    }
    plane <- expected[expected$scope == "plane", ]
    lengths <- as.integer(strsplit(observed$plane_lengths, ",", fixed = TRUE)[[1L]])
    unnamed <- as.logical(strsplit(observed$plane_named, ",", fixed = TRUE)[[1L]])
    vector <- plane$shape != "function"
    axis_length <- if (identical(observed$universe, "")) {
      0L
    } else {
      length(strsplit(observed$universe, ",", fixed = TRUE)[[1L]])
    }
    testthat::expect_true(all(lengths[vector] == axis_length))
    testthat::expect_true(all(unnamed))
  }
  assert_surface(dense, "dense")
  assert_surface(held, "availability")
  assert_surface(empty, "availability")
})

eligibility_plane_capture <- function(ctx, params) {
  masked <- ctx$flat()
  masked[ctx$vec$admissible & ctx$vec$close > 0] <- 1
  entry <- list(
    members = as.list(ctx$members),
    member = as.list(ctx$vec$member),
    target_restricted = as.list(ctx$vec$target_restricted),
    target_restriction_reason = as.list(ctx$vec$target_restriction_reason),
    admissible = as.list(ctx$vec$admissible),
    masked = as.list(unname(masked))
  )
  list(
    targets = ctx$hold(),
    state_update = list(planes = c(ctx$state_prev$planes, list(entry)))
  )
}

testthat::test_that("[LTB-0119] every context exposes the eligibility planes, built once per dense run", {
  dates <- as.Date("2026-02-01") + 0:3
  bars <- data.frame(
    ts_utc = rep(as.POSIXct(paste(dates, "16:00:00"), tz = "UTC"), each = 2L),
    instrument_id = rep(c("AAA", "BBB"), times = 4L),
    open = 10, high = 10, low = 10, close = 10, volume = 1000,
    stringsAsFactors = FALSE
  )
  dense_snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(dense_snapshot), add = TRUE)

  dense_expected <- list(
    members = list("AAA", "BBB"),
    member = list(TRUE, TRUE),
    target_restricted = list(FALSE, FALSE),
    target_restriction_reason = list("", ""),
    admissible = list(TRUE, TRUE),
    masked = list(1, 1)
  )

  builds <- 0L
  build_planes <- ledgr:::ledgr_dense_eligibility_planes
  testthat::local_mocked_bindings(
    ledgr_dense_eligibility_planes = function(n) {
      builds <<- builds + 1L
      build_planes(n)
    },
    .package = "ledgr"
  )
  dense_run <- ledgr_run(ledgr_experiment(
    dense_snapshot,
    eligibility_plane_capture,
    cost_model = ledgr_cost_zero()
  ))
  on.exit(close(dense_run), add = TRUE)
  plain <- function(entry) {
    out <- lapply(entry, function(value) as.vector(unlist(value)))
    out[order(names(out))]
  }
  dense_seen <- availability_last_state(dense_run)$planes
  testthat::expect_length(dense_seen, 4L)
  for (entry in dense_seen) testthat::expect_identical(plain(entry), plain(dense_expected))
  testthat::expect_identical(builds, 1L)

  pulse <- ledgr_pulse_snapshot(
    dense_snapshot,
    universe = c("AAA", "BBB"),
    ts_utc = as.POSIXct(paste(dates[[2L]], "16:00:00"), tz = "UTC")
  )
  on.exit(close(pulse), add = TRUE)
  testthat::expect_identical(pulse$members, c("AAA", "BBB"))
  testthat::expect_identical(pulse$vec$member, c(TRUE, TRUE))
  testthat::expect_identical(pulse$vec$target_restricted, c(FALSE, FALSE))
  testthat::expect_identical(pulse$vec$target_restriction_reason, c("", ""))
  testthat::expect_identical(pulse$vec$admissible, c(TRUE, TRUE))
  pulse_masked <- pulse$flat()
  pulse_masked[pulse$vec$admissible & pulse$vec$close > 0] <- 1
  testthat::expect_identical(pulse_masked, c(AAA = 1, BBB = 1))

  membership_input <- data.frame(
    effective_from = as.POSIXct(paste(as.Date("2020-01-01") + 0:1, "16:00:00"), tz = "UTC"),
    knowledge_time = as.POSIXct(paste(as.Date("2020-01-01") + 0:1, "16:00:00"), tz = "UTC") - 1,
    source = "eligibility",
    stringsAsFactors = FALSE
  )
  membership_input$members <- list("AAA", character())
  availability_snapshot <- availability_runtime_fixture(
    days = 3L,
    membership = ledgr_facts_membership_snapshots(
      membership_input,
      universe_id = "eligibility",
      complete = TRUE
    )
  )
  on.exit(ledgr_snapshot_close(availability_snapshot), add = TRUE)
  availability_run <- ledgr_run(ledgr_experiment(
    availability_snapshot,
    eligibility_plane_capture,
    universe = ledgr_universe_members("eligibility"),
    opening = ledgr_opening(cash = 1e5, positions = c(AAA = 1), cost_basis = c(AAA = 100)),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  ))
  on.exit(close(availability_run), add = TRUE)
  ragged_seen <- availability_last_state(availability_run)$planes
  first <- plain(ragged_seen[[1L]])
  second <- plain(ragged_seen[[2L]])
  testthat::expect_identical(first$admissible, TRUE)
  testthat::expect_identical(first$masked, 1)
  testthat::expect_null(second$members)
  testthat::expect_identical(second$member, FALSE)
  testthat::expect_identical(second$admissible, FALSE)
  testthat::expect_identical(second$masked, 0)
})
