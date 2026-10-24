# ledgr-test-profile: review
testthat::test_that("[LTB-0297] history frame, matrix and scalar reads agree with fixture arithmetic", {
  captured <- ws42_capture_run(reader = function(ctx) {
    list(
      close = ledgr_history_frame(ctx, bar = "close", lookback = Inf),
      close_long = ledgr_history_frame(ctx, bar = "close", lookback = Inf, layout = "long"),
      fast = ledgr_history_frame(ctx, feature = "fast", lookback = 2L),
      concrete = ledgr_history_frame(ctx, feature = "sma_2", lookback = 2L, layout = "long"),
      decision = ledgr_history_frame(ctx, bar = "close", lookback = 1L,
        instruments = "decision_axis", min_observations = 0L),
      explicit = ledgr_history_frame(ctx, bar = "close", lookback = 2L,
        instruments = c("CCC", "AAA"), min_observations = 0L),
      empty = ledgr_history_frame(ctx, bar = "close", lookback = 0L),
      empty_long = ledgr_history_frame(ctx, bar = "close", lookback = 0L, layout = "long"),
      none = ledgr_history_frame(ctx, bar = "close", lookback = 2L, instruments = character()),
      scalar = list(
        close = ctx$close("AAA"), vec_close = ctx$vec$close, ids = ctx$universe,
        feature = ctx$feature("AAA", "fast"), vec_fast = ctx$vec$feature("fast")
      ),
      ctx = ctx
    )
  })
  on.exit({
    close(captured$bt)
    ledgr_snapshot_close(captured$fixture$snapshot)
  }, add = TRUE)
  axis <- captured$fixture$axis
  at5 <- captured$seen[[ws42_iso(axis[[5L]])]]
  at7 <- captured$seen[[ws42_iso(axis[[7L]])]]

  # Default read: full causal lookback, admissible instruments, wide.
  close5 <- at5$close
  testthat::expect_s3_class(close5, "ledgr_history")
  testthat::expect_identical(names(close5), c("ts_utc", "AAA", "BBB", "CCC"))
  testthat::expect_identical(as.numeric(close5$ts_utc), as.numeric(axis[1:5]))
  testthat::expect_identical(close5$AAA, c(11, 12, 13, 14, 15))
  testthat::expect_identical(close5$BBB, c(21, 22, 22, 22, 25))
  testthat::expect_identical(close5$CCC, c(31, 32, 33, 34, 35))
  meta5 <- attr(close5, "ledgr_history")
  long5 <- at5$close_long
  testthat::expect_identical(meta5$source$id, "close")
  testthat::expect_identical(as.numeric(meta5$data_start_utc), as.numeric(axis[[1L]]))
  testthat::expect_identical(as.numeric(meta5$window_start_utc), as.numeric(axis[[1L]]))
  testthat::expect_identical(as.numeric(meta5$cutoff_utc), as.numeric(axis[[5L]]))
  testthat::expect_identical(meta5$requested_lookback, Inf)
  testthat::expect_identical(meta5$available_lookback, 5L)
  testthat::expect_identical(meta5$policy_identity$price_carry, 5L)
  testthat::expect_identical(
    long5$input_carried[long5$instrument_id == "BBB"],
    c(FALSE, FALSE, TRUE, TRUE, FALSE)
  )
  testthat::expect_identical(
    long5$carry_age_sessions[long5$instrument_id == "BBB"],
    c(0L, 0L, 1L, 2L, 0L)
  )
  testthat::expect_identical(
    as.numeric(long5$source_ts_utc[long5$instrument_id == "BBB"])[3:4],
    rep(as.numeric(axis[[2L]]), 2L)
  )
  testthat::expect_identical(
    long5$is_missing[long5$instrument_id == "BBB"],
    c(FALSE, FALSE, TRUE, TRUE, FALSE)
  )
  testthat::expect_identical(meta5$selection$carried_input_count, c(0L, 2L, 0L))
  testthat::expect_identical(meta5$selection$carried_input_share, c(0, 0.4, 0))

  # The matrix adapter keeps time and instrument identity without a reader.
  matrix5 <- ledgr_history_matrix(close5)
  testthat::expect_identical(
    dimnames(matrix5),
    list(ws42_iso(axis[1:5]), c("AAA", "BBB", "CCC"))
  )
  testthat::expect_identical(unname(matrix5[, "BBB"]), c(21, 22, 22, 22, 25))
  testthat::expect_identical(ledgr_history_matrix(at5$close_long), matrix5)
  direct5 <- ledgr_history_matrix(at5$ctx, bar = "close", lookback = Inf)
  testthat::expect_identical(direct5, matrix5)
  testthat::expect_s3_class(direct5, "ledgr_history_matrix")
  testthat::expect_true(is.matrix(direct5))
  testthat::expect_true(is.double(direct5))
  testthat::expect_identical(ledgr_history_info(direct5), ledgr_history_info(matrix5))

  # Long layout carries the same values, source identity and evidence.
  testthat::expect_identical(
    names(long5)[1:4], c("ts_utc", "instrument_id", "source", "value")
  )
  testthat::expect_identical(long5$instrument_id[1:3], c("AAA", "BBB", "CCC"))
  testthat::expect_identical(unique(long5$source), "bar:close")
  testthat::expect_identical(long5$value[long5$instrument_id == "BBB"], c(21, 22, 22, 22, 25))
  testthat::expect_identical(
    long5$input_carried[long5$instrument_id == "BBB"],
    c(FALSE, FALSE, TRUE, TRUE, FALSE)
  )

  # Scalar and vector reads agree with the last returned observed row.
  testthat::expect_identical(at5$scalar$close, 15)
  testthat::expect_identical(at5$scalar$ids, c("AAA", "BBB", "CCC"))
  testthat::expect_identical(at5$scalar$vec_close, unname(matrix5[5L, ]))

  # Features resolve active alias first, then concrete ID, and agree with the
  # scalar feature reads: SMA(2) of 10 + k is 9.5 + k.
  fast5 <- at5$fast
  testthat::expect_identical(names(fast5), c("ts_utc", "AAA", "BBB", "CCC"))
  testthat::expect_identical(fast5$AAA, c(13.5, 14.5))
  # V12 Section 5 (LDG-3066): SMA consumes BBB's carried session-3/4 close.
  testthat::expect_identical(fast5$BBB, c(22, 23.5))
  testthat::expect_identical(fast5$CCC, c(33.5, 34.5))
  testthat::expect_identical(attr(fast5, "ledgr_history")$source$id, "sma_2")
  testthat::expect_identical(at5$scalar$feature, 14.5)
  testthat::expect_identical(at5$scalar$vec_fast, c(14.5, 23.5, 34.5))
  testthat::expect_identical(
    as.matrix(ledgr_history_matrix(at5$concrete)),
    as.matrix(ledgr_history_matrix(fast5))
  )
  testthat::expect_identical(unique(at5$concrete$source), "feature:sma_2")
  testthat::expect_error(
    ledgr_history_frame(at5$ctx, feature = "slow", lookback = Inf),
    class = "ledgr_unknown_feature_id"
  )
  testthat::expect_error(
    ledgr_history_frame(at5$ctx, bar = "close", feature = "fast", lookback = Inf),
    class = "ledgr_invalid_history_request"
  )
  testthat::expect_error(
    ledgr_history_frame(at5$ctx, bar = "vwap", lookback = Inf),
    class = "ledgr_invalid_history_field"
  )

  # Selectors at session 7, where CCC is a known-inactive member: admissible
  # omits it, the decision axis keeps it, and an explicit request keeps it
  # requested and included with its reason, in request order.
  testthat::expect_identical(names(at7$close), c("ts_utc", "AAA", "BBB"))
  testthat::expect_identical(names(at7$decision), c("ts_utc", "AAA", "BBB", "CCC"))
  testthat::expect_identical(at7$decision$CCC, NA_real_)
  explicit <- at7$explicit
  testthat::expect_identical(names(explicit), c("ts_utc", "CCC", "AAA"))
  testthat::expect_identical(explicit$AAA, c(16, 17))
  explicit_selection <- attr(explicit, "ledgr_history")$selection
  ccc <- explicit_selection[explicit_selection$instrument_id == "CCC", ]
  testthat::expect_true(ccc$requested)
  testthat::expect_true(ccc$included)
  testthat::expect_false(ccc$admissible)
  testthat::expect_identical(ccc$admissibility_reason, "lifetime_inactive")
  bbb <- explicit_selection[explicit_selection$instrument_id == "BBB", ]
  testthat::expect_false(bbb$requested)
  testthat::expect_identical(bbb$exclusion_reason, "not_requested")
  testthat::expect_error(
    ledgr_history_frame(at7$ctx, bar = "close", lookback = Inf,
      instruments = c("AAA", "ZZZ")),
    class = "ledgr_history_unknown_instrument"
  )
  testthat::expect_error(
    ledgr_history_frame(at7$ctx, bar = "close", lookback = Inf,
      instruments = c("AAA", "AAA")),
    class = "ledgr_invalid_history_request"
  )

  # A cutoff outside the prepared axis refuses.
  outside <- at5$ctx
  outside$.history <- ledgr:::ledgr_history_view(outside$.history$service, length(axis) + 1L)
  testthat::expect_error(
    ledgr_history_frame(outside, bar = "close", lookback = Inf),
    class = "ledgr_history_outside_axis"
  )

  # Bound empty shapes.
  empty <- at5$empty
  testthat::expect_identical(nrow(empty), 0L)
  testthat::expect_identical(names(empty), c("ts_utc", "AAA", "BBB", "CCC"))
  testthat::expect_s3_class(empty$ts_utc, "POSIXct")
  testthat::expect_true(all(vapply(empty[-1L], is.double, logical(1))))
  # R stores a zero-length dimname as NULL.
  testthat::expect_identical(dim(ledgr_history_matrix(empty)), c(0L, 3L))
  testthat::expect_identical(
    dimnames(ledgr_history_matrix(empty)),
    list(NULL, c("AAA", "BBB", "CCC"))
  )
  empty_long <- at5$empty_long
  testthat::expect_identical(nrow(empty_long), 0L)
  testthat::expect_s3_class(empty_long$ts_utc, "POSIXct")
  testthat::expect_type(empty_long$instrument_id, "character")
  testthat::expect_type(empty_long$source, "character")
  testthat::expect_type(empty_long$value, "double")
  testthat::expect_identical(dim(ledgr_history_matrix(empty_long)), c(0L, 3L))
  none <- at5$none
  testthat::expect_identical(names(none), "ts_utc")
  testthat::expect_identical(as.numeric(none$ts_utc), as.numeric(axis[4:5]))
  testthat::expect_identical(dim(ledgr_history_matrix(none)), c(2L, 0L))
  testthat::expect_identical(
    dimnames(ledgr_history_matrix(none)),
    list(ws42_iso(axis[4:5]), NULL)
  )

  # History is availability-only: a dense pulse context refuses.
  dense <- ledgr_pulse_snapshot(
    captured$fixture$snapshot, universe = "AAA", ts_utc = axis[[2L]]
  )
  on.exit(close(dense), add = TRUE)
  testthat::expect_error(
    ledgr_history_frame(dense, bar = "close", lookback = Inf),
    class = "ledgr_history_unavailable"
  )
  testthat::expect_error(
    ledgr_history_matrix(data.frame(ts_utc = axis)),
    class = "ledgr_invalid_history_result"
  )
})

ws42_hostile_substrate <- function(policy = ledgr_history_policy(price_carry = 2L)) {
  axis <- as.POSIXct("2021-03-01 21:00:00", tz = "UTC") + 0:9 * 86400
  # CCC has two late-known facts (inactive sessions 3-4 known at 4, relisted
  # from 8 known at 9) and, between them, a delisting effective and known at
  # session 6, so its epoch answers must use every fact known before the next
  # late instant.
  lifetime <- ledgr_facts_lifetime(data.frame(
    instrument_id = c("AAA", "AAA", "AAA", "BBB", "BBB", "CCC", "CCC", "CCC", "CCC", "CCC"),
    effective_from = axis[c(1L, 4L, 8L, 1L, 6L, 1L, 3L, 5L, 6L, 8L)] - 3600,
    effective_to = as.POSIXct(
      c(axis[[4L]], axis[[8L]], NA, axis[[6L]], NA, axis[[3L]], axis[[5L]], axis[[6L]], axis[[8L]], NA) - 3600,
      origin = "1970-01-01", tz = "UTC"
    ),
    knowledge_time = axis[c(1L, 6L, 9L, 1L, 6L, 1L, 4L, 5L, 6L, 9L)] - 3600,
    assertion = c(
      "known_active", "known_inactive", "known_active", "known_active", "known_inactive",
      "known_active", "known_inactive", "known_active", "known_inactive", "known_active"
    ),
    terminal_event = c(NA, NA, NA, NA, "delisting", NA, NA, NA, "delisting", NA),
    source = "test",
    stringsAsFactors = FALSE
  ))
  bars <- expand.grid(
    instrument_id = c("AAA", "BBB", "CCC"), ts_utc = axis,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  bars$close <- 100 + seq_len(nrow(bars))
  bars$open <- bars$close - 0.5
  bars$high <- bars$close + 1
  bars$low <- bars$close - 1
  bars$volume <- 1000 + seq_len(nrow(bars))
  drop <- (bars$instrument_id == "AAA" & bars$ts_utc %in% axis[c(2L, 3L, 6L, 9L)]) |
    (bars$instrument_id == "BBB" & bars$ts_utc %in% axis[c(4L, 5L)]) |
    (bars$instrument_id == "CCC" & bars$ts_utc %in% axis[c(2L, 7L)])
  bars <- bars[!drop, , drop = FALSE]
  bars$volume[bars$instrument_id == "AAA" & bars$ts_utc == axis[[5L]]] <- NA_real_
  data <- list(
    families = data.frame(family = c("lifetime", "sessions"), stringsAsFactors = FALSE),
    lifetime = lifetime$rows,
    sessions = data.frame(
      venue_id = "V", session_date = as.Date(axis), status = "open",
      session_open = axis - 6 * 3600, session_close = axis,
      knowledge_time = axis - 6 * 3600, stringsAsFactors = FALSE
    )
  )
  config <- list(
    universe = list(instrument_ids = c("AAA", "BBB", "CCC")),
    availability = list(valuation_policy = unclass(ledgr_valuation_stale())),
    history_policy = policy
  )
  list(
    axis = axis,
    substrate = ledgr:::ledgr_history_substrate(
      bars = bars, instrument_ids = c("AAA", "BBB", "CCC"), axis = axis,
      availability_data = data, availability_config = config, snapshot_hash = "ws42"
    )
  )
}

ws42_read <- function(service, cutoff_col, field, lookback = Inf, ids = c("AAA", "BBB", "CCC"),
                      layout = "wide", min_observations = 0L) {
  plan <- ledgr:::ledgr_history_read_plan(
    view = ledgr:::ledgr_history_view(service, cutoff_col),
    kind = "bar", name = field, lookback = lookback, instruments = ids,
    min_observations = min_observations, min_instruments = 1L, decision_ids = ids,
    decision_planes = list(
      member = rep(TRUE, length(ids)), admissible = rep(TRUE, length(ids)),
      target_restriction_reason = rep("", length(ids))
    ),
    diagnostic = identical(layout, "long"),
    manifestation = if (identical(layout, "long")) "long" else "wide"
  )
  ledgr:::ledgr_history_plan_frame(plan, layout)
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0298] history results are cutoff-exact suffixes and stay immutable", {
  # Every cutoff of a hostile substrate (late-known inactivity, a late-known
  # terminal, a relisting, field-local gaps and a volume gap) matches the
  # whole-prefix treatment primitive cell for cell, whatever order the
  # cutoffs are read in.
  for (policy in list(ledgr_history_policy(price_carry = 2L), ledgr_history_policy(price_carry = NULL))) {
    hostile <- ws42_hostile_substrate(policy)
    service <- ledgr:::ledgr_history_read_service(hostile$substrate)
    n <- length(hostile$axis)
    for (cutoff_col in c(n:1L, 1:n)) {
      for (field in c("close", "open", "volume")) {
        oracle <- ledgr:::ledgr_history_substrate_treated_field(
          hostile$substrate, field, cutoff = hostile$axis[[cutoff_col]],
          observation_idx = seq_len(cutoff_col)
        )
        read <- ws42_read(service, cutoff_col, field, layout = "long")
        for (plane in setdiff(ledgr:::ledgr_history_cell_fields(), "source_ts_utc")) {
          testthat::expect_identical(
            unname(read[[plane]]), unname(as.vector(oracle[[plane]])),
            info = paste(field, cutoff_col, plane)
          )
        }
        testthat::expect_identical(
          unname(as.numeric(read$source_ts_utc)),
          unname(as.vector(oracle$source_ts_utc)),
          info = paste(field, cutoff_col, "source_ts_utc")
        )
        print_cell <- !oracle$expected & oracle$observed
        value <- t(oracle$value)
        raw <- hostile$substrate$bars[[field]][, seq_len(cutoff_col), drop = FALSE]
        value[t(print_cell)] <- t(raw)[t(print_cell)]
        testthat::expect_identical(
          unname(as.matrix(ledgr_history_matrix(read))), unname(value),
          info = paste(field, cutoff_col, "value")
        )
      }
    }
  }

  # The hostile literal: AAA closes at 98 + 3s on session s, has no print on
  # sessions 2, 3, 6 and 9, becomes known inactive for sessions 4-7 at session
  # 6 and relists at session 8 (known at 9). At cutoff 5 sessions 2-3 carry 101
  # and 4-5 are ordinary prints; at cutoff 6 they are flagged inactive prints.
  hostile <- ws42_hostile_substrate()
  service <- ledgr:::ledgr_history_read_service(hostile$substrate)
  before <- ws42_read(service, 5L, "close", ids = "AAA")
  before_bytes <- serialize(before, NULL)
  after <- ws42_read(service, 6L, "close", ids = "AAA")
  after_long <- ws42_read(service, 6L, "close", ids = "AAA", layout = "long")
  testthat::expect_identical(before$AAA, c(101, 101, 101, 110, 113))
  testthat::expect_identical(after$AAA, c(101, 101, 101, 110, 113, NA))
  testthat::expect_identical(
    after_long$missing_reason[4:6],
    c("inactive_interval_print", "inactive_interval_print", "not_expected")
  )
  testthat::expect_identical(after_long$expected[4:6], rep(FALSE, 3L))
  testthat::expect_identical(after_long$calculation_valid[4:6], rep(FALSE, 3L))
  testthat::expect_identical(
    after_long$barrier_reason[4:6],
    rep("lifetime_inactive", 3L)
  )
  testthat::expect_identical(serialize(before, NULL), before_bytes)
  testthat::expect_identical(ws42_read(service, 5L, "close", ids = "AAA"), before)

  # Public runs: a finite lookback is the exact values-and-evidence suffix of
  # Inf, used_before_window reports carried or windowed dependence, future
  # rows never appear and the late-known fact changes only later reads.
  captured <- ws42_capture_run(reader = function(ctx) {
    list(
      inf = ledgr_history_frame(ctx, bar = "close", lookback = Inf,
        instruments = "decision_axis", min_observations = 0L),
      inf_long = ledgr_history_frame(ctx, bar = "close", lookback = Inf,
        instruments = "decision_axis", min_observations = 0L, layout = "long"),
      tail3 = ledgr_history_frame(ctx, bar = "close", lookback = 3L, instruments = "decision_axis"),
      tail3_long = ledgr_history_frame(ctx, bar = "close", lookback = 3L,
        instruments = "decision_axis", layout = "long"),
      tail1 = ledgr_history_frame(ctx, bar = "close", lookback = 1L, instruments = "decision_axis"),
      fast_inf = ledgr_history_frame(ctx, feature = "fast", lookback = Inf,
        min_observations = 0L),
      fast1 = ledgr_history_frame(ctx, feature = "fast", lookback = 1L),
      ctx = ctx
    )
  })
  on.exit({
    close(captured$bt)
    ledgr_snapshot_close(captured$fixture$snapshot)
  }, add = TRUE)
  axis <- captured$fixture$axis
  at5 <- captured$seen[[ws42_iso(axis[[5L]])]]
  at6 <- captured$seen[[ws42_iso(axis[[6L]])]]
  at7 <- captured$seen[[ws42_iso(axis[[7L]])]]
  inf <- attr(at5$inf, "ledgr_history")
  tail3 <- attr(at5$tail3, "ledgr_history")
  testthat::expect_identical(
    as.matrix(ledgr_history_matrix(at5$tail3)),
    ledgr_history_matrix(at5$inf)[3:5, , drop = FALSE]
  )
  for (plane in ledgr:::ledgr_history_cell_fields()) {
    testthat::expect_identical(
      at5$tail3_long[[plane]],
      at5$inf_long[[plane]][at5$inf_long$ts_utc %in% at5$tail3_long$ts_utc]
    )
  }
  testthat::expect_false(inf$used_before_window)
  testthat::expect_true(tail3$used_before_window)
  testthat::expect_false(attr(at5$tail1, "ledgr_history")$used_before_window)
  testthat::expect_false(attr(at5$fast_inf, "ledgr_history")$used_before_window)
  testthat::expect_true(attr(at5$fast1, "ledgr_history")$used_before_window)
  testthat::expect_identical(max(as.numeric(at5$inf$ts_utc)), as.numeric(axis[[5L]]))
  testthat::expect_identical(nrow(at5$inf), 5L)

  # Session 6 sees CCC's carried close; session 7 knows the inactivity and
  # rewrites only the later read. The earlier object is unchanged.
  six_bytes <- serialize(at6$inf, NULL)
  testthat::expect_identical(at6$inf$CCC[[6L]], 35)
  testthat::expect_true(at6$inf_long$input_carried[
    at6$inf_long$instrument_id == "CCC" & at6$inf_long$ts_utc == axis[[6L]]
  ])
  testthat::expect_identical(at7$inf$CCC[6:7], c(NA_real_, NA_real_))
  testthat::expect_identical(
    at7$inf_long$missing_reason[
      at7$inf_long$instrument_id == "CCC" & at7$inf_long$ts_utc %in% axis[6:7]
    ],
    c("not_expected", "not_expected")
  )
  testthat::expect_identical(serialize(at6$inf, NULL), six_bytes)
  reread6 <- at7$ctx
  reread6$.history <- ledgr:::ledgr_history_view(reread6$.history$service, 6L)
  reread6$universe <- at6$ctx$universe
  reread6$vec <- at6$ctx$vec
  testthat::expect_identical(
    ledgr_history_frame(reread6, bar = "close", lookback = Inf,
      instruments = "decision_axis", min_observations = 0L),
    at6$inf
  )

  # Mutating a returned result leaves later reads unchanged.
  mutated <- at5$inf
  mutated$AAA[] <- -1
  testthat::expect_identical(
    ledgr_history_frame(at5$ctx, bar = "close", lookback = Inf,
      instruments = "decision_axis", min_observations = 0L),
    at5$inf
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0299] recorded readiness and estimation exclusion create no execution intent", {
  # A return feature never consumes BBB's carried close (v12 Section 5,
  # LDG-3066), so BBB stays excluded from the estimator sample; an SMA would
  # now be calculated from the carried price.
  returns <- ledgr_feature_map(fast = ledgr_ind_returns(1L))
  captured <- ws42_capture_run(fixture_args = list(features = returns), reader = function(ctx) {
    list(
      close = ledgr_history_frame(ctx, bar = "close", lookback = 3L),
      close4 = ledgr_history_frame(ctx, bar = "close", lookback = 3L,
        min_instruments = 4L),
      fast = ledgr_history_frame(ctx, feature = "fast", lookback = 2L),
      fast3 = ledgr_history_frame(ctx, feature = "fast", lookback = 2L,
        min_instruments = 3L),
      warmup = ledgr_history_frame(ctx, feature = "fast", lookback = 1L,
        min_observations = 0L, min_instruments = 3L)
    )
  })
  on.exit({
    close(captured$bt)
    ledgr_snapshot_close(captured$fixture$snapshot)
  }, add = TRUE)
  axis <- captured$fixture$axis
  at5 <- captured$seen[[ws42_iso(axis[[5L]])]]
  at1 <- captured$seen[[ws42_iso(axis[[1L]])]]
  testthat::expect_true(ledgr_passed_warmup(at5$close))
  testthat::expect_false(ledgr_passed_warmup(at5$close4))
  testthat::expect_identical(names(at5$fast), c("ts_utc", "AAA", "CCC"))
  selection <- attr(at5$fast, "ledgr_history")$selection
  testthat::expect_identical(
    selection$exclusion_reason[selection$instrument_id == "BBB"],
    "insufficient_observations"
  )
  testthat::expect_true(ledgr_passed_warmup(at5$fast))
  testthat::expect_false(ledgr_passed_warmup(at5$fast3))
  # An explicit zero-observation requirement is recorded once; readiness does
  # not rescan the warm-up NA cells.
  testthat::expect_true(all(is.na(unlist(at1$warmup[-1L]))))
  testthat::expect_true(ledgr_passed_warmup(at1$warmup))
  testthat::expect_error(
    ledgr:::ledgr_history_requirements(2L, 3L, 1L, 2L),
    class = "ledgr_invalid_history_request"
  )
  testthat::expect_error(
    ledgr_passed_warmup(data.frame()),
    class = "ledgr_invalid_warmup_input"
  )
  testthat::expect_error(
    ledgr_history_info(ledgr_history_matrix(at5$close)[, 1L, drop = FALSE]),
    class = "ledgr_invalid_history_result"
  )

  # Estimation exclusion is not execution intent. BBB is held (5 shares) and
  # dropped from the return estimator sample on sessions 3-5, yet its target
  # stays its current quantity, and the run equals one that never reads
  # history: one AAA fill of one share at session 4's open (14).
  decided <- new.env()
  reads_history <- function(ctx, params) {
    h <- ledgr_history_frame(ctx, feature = "fast", lookback = 2L)
    target <- ctx$hold()
    if (identical(substr(ctx$ts_utc, 1, 10), "2021-01-06")) target[["AAA"]] <- 1
    decided[[ctx$ts_utc]] <- list(ids = names(h)[-1L], bbb = target[["BBB"]])
    target
  }
  ignores_history <- function(ctx, params) {
    target <- ctx$hold()
    if (identical(substr(ctx$ts_utc, 1, 10), "2021-01-06")) target[["AAA"]] <- 1
    target
  }
  opening <- ledgr_opening(cash = 1000, positions = c(BBB = 5), cost_basis = c(BBB = 21))
  with_history <- ws42_history_fixture(
    strategy = reads_history, opening = opening, features = returns
  )
  on.exit(ledgr_snapshot_close(with_history$snapshot), add = TRUE)
  bt_history <- ledgr_run(with_history$exp, run_id = "reads_history")
  on.exit(close(bt_history), add = TRUE)
  without <- ledgr_experiment(
    with_history$snapshot, ignores_history, universe = ledgr_universe_members("u"),
    features = returns,
    valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
    opening = opening
  )
  bt_plain <- ledgr_run(without, run_id = "ignores_history")
  on.exit(close(bt_plain), add = TRUE)
  for (day in 3:5) {
    testthat::expect_identical(decided[[ws42_iso(axis[[day]])]]$ids, c("AAA", "CCC"))
    testthat::expect_identical(decided[[ws42_iso(axis[[day]])]]$bbb, 5)
  }
  fills <- ledgr_results(bt_history, "fills")
  testthat::expect_identical(fills$instrument_id, "AAA")
  testthat::expect_identical(fills$qty, 1)
  testthat::expect_identical(fills$price, 14)
  strip <- function(x, drop) as.data.frame(x)[, setdiff(names(x), drop), drop = FALSE]
  for (what in c("fills", "equity", "ledger", "diagnostics")) {
    testthat::expect_identical(
      strip(ledgr_results(bt_history, what), c("run_id", "event_id")),
      strip(ledgr_results(bt_plain, what), c("run_id", "event_id")),
      info = what
    )
  }
  # The reads add no snapshot row and no durable artifact.
  con <- ledgr:::get_connection(with_history$snapshot)
  counts <- function(run_id) {
    vapply(
      c("ledger_events", "equity_curve", "strategy_state", "run_diagnostics"),
      function(table) {
        DBI::dbGetQuery(
          con, sprintf("SELECT COUNT(*) AS n FROM %s WHERE run_id = ?", table),
          params = list(run_id)
        )$n
      },
      numeric(1)
    )
  }
  testthat::expect_identical(counts("reads_history"), counts("ignores_history"))
  snapshot_tables <- c(
    "snapshot_bars", "snapshot_instruments", "snapshot_sessions",
    "snapshot_membership", "snapshot_membership_sets", "snapshot_lifetime",
    "snapshot_fact_families", "snapshot_observation_quarantine"
  )
  snapshot_rows <- function() {
    vapply(snapshot_tables, function(table) {
      DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM %s", table))$n
    }, numeric(1))
  }
  rows_before <- snapshot_rows()
  close(ledgr_run(with_history$exp, run_id = "reads_history_again"))
  testthat::expect_identical(snapshot_rows(), rows_before)
})
