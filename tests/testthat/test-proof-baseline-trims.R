# Cut 16 Workstream 47: the four wastes the external architecture audit
# measured (cut16_architecture_audit.md, F01-F04) stay removed.

# Bindings of `frame` that hold a feature payload: a non-empty list whose
# entries each carry a fingerprint and per-instrument values. The shape, not
# the variable name, is the detector.
ws47_payload_bindings <- function(frame) {
  payload_like <- function(x) {
    is.list(x) && !is.data.frame(x) && length(x) > 0L &&
      all(vapply(x, function(entry) {
        is.list(entry) && all(c("fingerprint", "values") %in% names(entry))
      }, logical(1)))
  }
  held <- ls(frame, all.names = TRUE)
  held[vapply(held, function(name) {
    payload_like(tryCatch(get(name, envir = frame, inherits = FALSE), error = function(e) NULL))
  }, logical(1))]
}

ws47_projection_bindings <- function(frame) {
  held <- ls(frame, all.names = TRUE)
  held[vapply(held, function(name) {
    inherits(
      tryCatch(get(name, envir = frame, inherits = FALSE), error = function(e) NULL),
      "ledgr_runtime_projection"
    )
  }, logical(1))]
}

# ledgr-test-profile: fast
testthat::test_that("[LTB-0391] unread membership columns and per-field barrier copies stay removed", {
  # F03: the prepared membership plan keeps only the columns its cursor and
  # attached resolver read, and still answers. Set s1 (complete, AAA and
  # BBB) is known at session 1; incomplete s2 (BBB) takes effect at session
  # 3 and is known at session 4; a CCC interval runs from session 2 until
  # session 5.
  axis <- as.POSIXct("2021-03-01 21:00:00", tz = "UTC") + 0:5 * 86400
  sets <- ledgr_facts_membership_snapshots(
    data.frame(
      effective_from = axis[c(1L, 3L)], knowledge_time = axis[c(1L, 4L)],
      set_id = c("s1", "s2"), members = I(list(c("AAA", "BBB"), "BBB")),
      source = "test", stringsAsFactors = FALSE
    ),
    universe_id = "U", complete = c(TRUE, FALSE)
  )
  intervals <- ledgr_facts_membership_intervals(
    data.frame(
      instrument_id = "CCC", effective_from = axis[[2L]], effective_to = axis[[5L]],
      knowledge_time = axis[[2L]], member = TRUE, source = "test",
      stringsAsFactors = FALSE
    ),
    universe_id = "U"
  )
  plan <- ledgr:::ledgr_availability_prepared_membership_plan(
    list(membership_sets = sets$headers, membership = rbind(sets$rows, intervals$rows)),
    "U",
    c("AAA", "BBB", "CCC")
  )
  testthat::expect_identical(names(plan$set_index$rows), c("instrument_id", "fact_id"))
  testthat::expect_identical(names(plan$headers), "set_id")
  testthat::expect_identical(names(plan$interval), "fact_id")
  members_at <- ledgr:::ledgr_availability_prepared_membership_from_plan(plan)
  resolve <- attr(members_at, "resolve")
  at <- function(k) as.numeric(axis[[k]])
  testthat::expect_identical(members_at(at(1L)), c("AAA", "BBB"))
  testthat::expect_identical(members_at(at(4L)), c("AAA", "BBB", "CCC"))
  testthat::expect_identical(members_at(at(5L)), c("AAA", "BBB"))
  fact <- function(set, id) sets$rows$fact_id[sets$rows$set_id == set & sets$rows$instrument_id == id]
  testthat::expect_identical(
    resolve(at(4L))$winner,
    c(
      paste0("set:s1|fact:", fact("s1", "AAA")),
      paste0("set:s2|fact:", fact("s2", "BBB")),
      paste0("fact:", intervals$rows$fact_id)
    )
  )

  # F04: ordinary manifestation reads the prepared masks directly and builds
  # neither whole-history carry-source nor patch caches. AAA is inactive from
  # session 6, known only at session 7, so cutoff 6 reads a late overlay.
  close <- c(10, 11, NA, 13, 14, 15, 16, 17)
  late <- ledgr_facts_lifetime(data.frame(
    instrument_id = "AAA",
    effective_from = ws43_history_axis(8L)[[6L]] - 6.5 * 3600,
    knowledge_time = ws43_history_axis(8L)[[7L]] - 6.5 * 3600,
    assertion = "known_inactive", terminal_event = NA_character_,
    source = "test", stringsAsFactors = FALSE
  ))
  substrate <- ws43_history_substrate(close, lifetime = late)
  service <- ledgr:::ledgr_history_read_service(substrate)
  read <- function(field, col, layout = "wide") {
    plan <- ledgr:::ledgr_history_read_plan(
      view = ledgr:::ledgr_history_view(service, col),
      kind = "bar", name = field, lookback = Inf, instruments = "AAA",
      min_observations = 0L, min_instruments = 1L, decision_ids = "AAA",
      decision_planes = list(
        member = TRUE, admissible = TRUE, target_restriction_reason = ""
      ),
      diagnostic = identical(layout, "long"),
      manifestation = if (identical(layout, "long")) "long" else "wide"
    )
    ledgr:::ledgr_history_plan_frame(plan, layout)
  }
  for (field in c("close", "open", "volume")) {
    read(field, 6L)
    read(field, 8L)
  }
  memo <- substrate$history_memo
  keys <- ls(memo)
  field_keys <- grep("_(open|high|low|close|volume)$", keys, value = TRUE)
  field_keys <- field_keys[!grepl("_patch_", field_keys, fixed = TRUE)]
  patch_keys <- grep("_patch_(open|high|low|close|volume)$", keys, value = TRUE)
  mask_keys <- c("base_masks", grep("^overlay_[0-9]+_[0-9]+$", keys, value = TRUE))
  testthat::expect_identical(field_keys, character())
  testthat::expect_identical(patch_keys, character())
  testthat::expect_identical(sort(mask_keys), c("base_masks", "overlay_1_0"))
  for (key in field_keys) {
    testthat::expect_identical(names(memo[[key]]), "source", info = key)
  }
  for (key in mask_keys) {
    testthat::expect_false("last_barrier" %in% names(memo[[key]]), info = key)
  }

  # Each mask's own barrier decides the reasons. AAA has no print before
  # session 4 and a late-known inactive session 2 (known at session 6):
  # read at cutoff 8 the gap after it is a lifetime restart; read at cutoff
  # 4, before the fact is known, it is leading missingness (read in that
  # order, so the base mask's barrier exists when the overlay is read).
  restart <- ledgr_facts_lifetime(data.frame(
    instrument_id = "AAA",
    effective_from = ws43_history_axis(8L)[[2L]] - 6.5 * 3600,
    effective_to = ws43_history_axis(8L)[[3L]] - 6.5 * 3600,
    knowledge_time = ws43_history_axis(8L)[[6L]] - 6.5 * 3600,
    assertion = "known_inactive", terminal_event = NA_character_,
    source = "test", stringsAsFactors = FALSE
  ))
  service <- ledgr:::ledgr_history_read_service(
    ws43_history_substrate(c(NA, NA, NA, 13, 14, 15, 16, 17), lifetime = restart)
  )
  barrier_reason <- function(col) {
    as.character(read("close", col, "long")$barrier_reason)
  }
  testthat::expect_identical(
    barrier_reason(8L),
    c("", "lifetime_inactive", "lifetime_restart", "", "", "", "", "")
  )
  testthat::expect_identical(barrier_reason(4L), c("", "", "", ""))
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0392] feature inputs take the narrow carry calculation and keep carry disclosure", {
  # F02: the canonical carry rule is one calculation; ledgr_history_input_carry()
  # manifests its evidence for reads and output carry, and feature inputs take
  # only the calculation. Close is missing at session 3, within the default
  # five-session carry horizon.
  substrate <- ws43_history_substrate(c(10, 11, NA, 13, 14))
  calculation <- ledgr:::ledgr_history_input_carry_calculation
  testthat::expect_identical(
    names(calculation(c(10, NA, 12), rep(TRUE, 3L), max_sessions = 5L)),
    c("value", "input_carried", "observed", "source", "last_barrier", "age", "can_carry")
  )
  calls <- new.env(parent = emptyenv())
  calls$full <- 0L
  calls$calculation <- 0L
  full <- ledgr:::ledgr_history_input_carry
  testthat::local_mocked_bindings(
    ledgr_history_input_carry = function(...) {
      calls$full <- calls$full + 1L
      full(...)
    },
    ledgr_history_input_carry_calculation = function(...) {
      calls$calculation <- calls$calculation + 1L
      calculation(...)
    },
    .package = "ledgr"
  )
  defs <- list(sma = ledgr_ind_sma(2L), ret = ledgr_ind_returns(1L))
  values <- ledgr:::ledgr_history_compute_feature_series(substrate, defs)
  testthat::expect_identical(calls$full, 0L)
  testthat::expect_true(calls$calculation > 0L)

  # Carry disclosure survives on the production evidence path: SMA(2)
  # consumes the carried 11 and flags it; the return family refuses it and
  # reports the excluded carried input.
  projection <- ledgr:::ledgr_projection_from_feature_matrix(
    values, universe = substrate$instrument_ids,
    pulses_posix = substrate$axis, feature_engine_version = "test"
  )
  bound <- ledgr:::ledgr_history_substrate_bind_features(substrate, projection)
  evidence <- function(id) {
    ledgr:::ledgr_history_feature_evidence(bound, id, 1L, 1:5, 5L)
  }
  sma <- evidence("sma")
  testthat::expect_identical(as.vector(sma$value), c(NA, 10.5, 11, 12, 13.5))
  testthat::expect_identical(as.vector(sma$input_carried), c(FALSE, FALSE, TRUE, FALSE, FALSE))
  testthat::expect_identical(as.vector(sma$missing_reason), c("not_ready", "", "", "", ""))
  ret <- evidence("ret")
  testthat::expect_identical(as.vector(ret$value), c(NA, (11 - 10) / 10, NA, NA, (14 - 13) / 13))
  testthat::expect_identical(as.vector(ret$input_carried), rep(FALSE, 5L))
  testthat::expect_identical(
    as.vector(ret$missing_reason),
    c("not_ready", "", "carried_input_excluded", "not_ready", "")
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0393] a fresh sweep and a pulse inspection release the feature payload", {
  # F01: once the runtime projection exists, the caller holds it and no
  # feature payload.
  fx <- ws42_history_fixture()
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  ns <- asNamespace("ledgr")
  seen <- new.env(parent = emptyenv())
  original_tasks <- get("ledgr_sweep_candidate_tasks", envir = ns)
  original_execution <- get("ledgr_sweep_candidate_execution", envir = ns)
  testthat::local_mocked_bindings(
    ledgr_sweep_candidate_tasks = function(...) {
      frame <- parent.frame()
      seen$sweep_payloads <- ws47_payload_bindings(frame)
      seen$sweep_projections <- ws47_projection_bindings(frame)
      original_tasks(...)
    },
    .package = "ledgr"
  )
  # Cut 16 decision (26), amended after close review 47 F1: a sequential
  # sweep stages no workers and runs no collection.
  collections <- new.env(parent = emptyenv())
  collections$n <- 0L
  old_counter <- options(ledgr.test.gc.counter = collections)
  on.exit(options(old_counter), add = TRUE)
  collection_tracer <- quote({
    counter <- getOption("ledgr.test.gc.counter")
    counter$n <- counter$n + 1L
  })
  suppressMessages(trace(
    "gc", tracer = collection_tracer,
    where = baseenv(), print = FALSE
  ))
  on.exit(suppressMessages(untrace("gc", where = baseenv())), add = TRUE)
  sweep <- ledgr_sweep(fx$exp, ledgr_param_grid(a = list(x = 1)))
  suppressMessages(untrace("gc", where = baseenv()))
  testthat::expect_identical(collections$n, 0L)
  testthat::expect_identical(sweep$status, "DONE")
  testthat::expect_identical(seen$sweep_payloads, character())
  testthat::expect_identical(seen$sweep_projections, "runtime_projection")
  # A sweep that stages two or more workers collects right after the
  # release, before staging.
  # The placement check reads the deparsed function body, a normal-runtime
  # invariant: covr instruments closures and inserts counters between the
  # statements, so it is skipped under coverage only.
  if (!ledgr_test_in_coverage()) {
    sweep_body <- vapply(as.list(body(get("ledgr_sweep_impl", envir = ns))), function(e) {
      paste(deparse(e), collapse = "\n")
    }, character(1))
    fresh <- sweep_body[grepl("rm(payload)", sweep_body, fixed = TRUE)]
    testthat::expect_length(fresh, 1L)
    testthat::expect_match(
      fresh,
      "rm(payload)\n    if (workers > 1L) \n        invisible(gc(verbose = FALSE))",
      fixed = TRUE
    )
  }

  testthat::local_mocked_bindings(
    ledgr_sweep_candidate_execution = function(...) {
      frame <- parent.frame()
      seen$inspect_payloads <- ws47_payload_bindings(frame)
      seen$inspect_projections <- ws47_projection_bindings(frame)
      original_execution(...)
    },
    .package = "ledgr"
  )
  ctx <- ledgr_pulse_snapshot(fx$exp, ts_utc = fx$axis[[3L]])
  testthat::expect_s3_class(ctx, "ledgr_pulse_context")
  testthat::expect_identical(seen$inspect_payloads, character())
  testthat::expect_identical(seen$inspect_projections, "projection")
})
