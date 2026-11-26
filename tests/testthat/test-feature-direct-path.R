# Cut 24 stage 3 (LDG-3263; feature-engine stages synthesis rules 5-8 and
# 12): the gated direct path. Every value, record, count and refusal here is
# compared with the general path, which is the normative calculator: the
# same preparation with the gate returning no admission. Choices are
# observed at the direct calculator's seam, never reported by the product.

cut24_axis <- function(n) as.POSIXct("2021-01-04 21:00:00", tz = "UTC") + (seq_len(n) - 1L) * 86400

# Instruments on one axis. `close` holds one close vector per instrument (NA
# drops the bar); `volume` overrides volumes; `lifetime` rows are
# data.frame(instrument_id, from, to, known, assertion, terminal) in
# session positions (to NA for open-ended).
cut24_panel <- function(close, volume = list(), lifetime = NULL,
                        policy = ledgr_history_policy(price_carry = 2L, output_carry = 2L)) {
  n <- length(close[[1L]])
  axis <- cut24_axis(n)
  ids <- names(close)
  bars <- do.call(rbind, lapply(ids, function(id) {
    x <- close[[id]]
    v <- volume[[id]] %||% rep(1000, n)
    keep <- is.finite(x)
    data.frame(instrument_id = id, ts_utc = axis[keep], open = x[keep] - 0.5,
               high = x[keep] + 1 + cos(seq_len(n))[keep]^2, low = x[keep] - 1, close = x[keep],
               volume = v[keep], stringsAsFactors = FALSE)
  }))
  families <- "sessions"
  rows <- NULL
  if (!is.null(lifetime)) {
    families <- c("lifetime", "sessions")
    rows <- ledgr_facts_lifetime(data.frame(
      instrument_id = lifetime$instrument_id,
      effective_from = axis[lifetime$from] - 3600,
      effective_to = as.POSIXct(ifelse(is.na(lifetime$to), NA, as.numeric(axis[pmax(lifetime$to, 1L)]) - 3600),
                                origin = "1970-01-01", tz = "UTC"),
      knowledge_time = axis[lifetime$known] - 3600,
      assertion = lifetime$assertion,
      terminal_event = lifetime$terminal,
      source = "test", stringsAsFactors = FALSE))$rows
  }
  data <- list(
    families = data.frame(family = families, stringsAsFactors = FALSE),
    lifetime = rows,
    sessions = data.frame(venue_id = "V", session_date = as.Date(axis), status = "open",
                          session_open = axis - 6 * 3600, session_close = axis,
                          knowledge_time = axis - 6 * 3600, stringsAsFactors = FALSE))
  config <- list(universe = list(instrument_ids = ids),
                 availability = list(universe_rule = NULL, valuation_policy = unclass(ledgr_valuation_stale())),
                 history_policy = policy)
  ledgr:::ledgr_history_substrate(bars = bars, instrument_ids = ids, axis = axis, availability_data = data,
                                  availability_config = config, snapshot_hash = "cut24-direct")
}

cut24_close <- function(n, k = 1) 100 * k + seq_len(n) + 2 * sin(seq_len(n) * k)

# Six instruments, each isolating one outcome of the gate on a 16-session
# axis: DENSE passes; VOLNA has one NA volume (passes for close-only
# definitions, fails for those requiring volume); GAP misses one close;
# LATE has a fact learned late, which splits its preparation into two
# knowledge ranges while every column stays expected; INACT has two
# known-inactive sessions; TERM has a delisting and relisting before
# session 6 (terminal asserted in the prefix only when the calculation
# starts later, see the tests).
cut24_gate_panel <- function(policy = ledgr_history_policy(price_carry = 2L, output_carry = 2L)) {
  n <- 16L
  close <- list(DENSE = cut24_close(n, 1), VOLNA = cut24_close(n, 2), GAP = cut24_close(n, 3),
                LATE = cut24_close(n, 4), INACT = cut24_close(n, 5), TERM = cut24_close(n, 6))
  close$GAP[[9L]] <- NA_real_
  close$INACT[c(7L, 8L)] <- NA_real_
  close$TERM[c(3L, 4L)] <- NA_real_
  volume <- list(VOLNA = replace(rep(1000, n), 11L, NA_real_))
  lifetime <- data.frame(
    instrument_id = c("LATE", "INACT", "INACT", "INACT", "TERM", "TERM", "TERM"),
    from = c(1L, 1L, 7L, 9L, 1L, 3L, 5L),
    to = c(NA, 7L, 9L, NA, 3L, 5L, NA),
    known = c(10L, 1L, 1L, 1L, 1L, 3L, 5L),
    assertion = c("known_active", "known_active", "known_inactive", "known_active",
                  "known_active", "known_inactive", "known_active"),
    terminal = c(NA, NA, NA, NA, NA, "delisting", NA),
    stringsAsFactors = FALSE)
  cut24_panel(close, volume = volume, lifetime = lifetime, policy = policy)
}

cut24_defs <- function(...) {
  lapply(list(...), function(x) ledgr:::ledgr_precompute_feature_def_from_indicator(x))
}

# Every built-in and catalogue row, two definitions with stable_after above
# requires_bars, an unregistered form and an ohlc mapping (custom fallback)
# and a custom definition reading a non-required field.
cut24_direct_defs <- function() {
  rows <- unname(cut24_catalogue_witnesses())
  c(rows, cut24_defs(
    ledgr_ind_ttr("SMA", input = "close", n = 3L, stable_after = 6L, id = "ttr_sma_late"),
    ledgr_ind_sma(4L),
    ledgr_ind_ttr("SMA", input = "close", n = 3L, requires_bars = 5L, id = "ttr_sma_unreg"),
    ledgr_ind_ttr("volatility", input = "ohlc", n = 3L, calc = "garman.klass", requires_bars = 3L, id = "ttr_vol_gk"),
    ledgr_indicator("custom_volume", fn = function(bars) as.numeric(utils::tail(bars$close, 1L)), requires_bars = 1L,
                    series_fn = function(bars) as.numeric(bars$close) + ifelse(is.finite(bars$volume), bars$volume * 1e-6, 0),
                    required_fields = "close")))
}

# The preparation with the gate refusing every cell: the general path.
cut24_general <- function(substrate, defs, ...) {
  testthat::local_mocked_bindings(
    ledgr_history_feature_gate = function(finite, ...) finite & FALSE,
    .package = "ledgr")
  ledgr:::ledgr_history_compute_feature_series(substrate, defs, ...)
}

cut24_prepare <- function(substrate, defs, debug, ...) {
  ledgr:::local_ledgr_debug(debug)
  ledgr:::ledgr_history_compute_feature_series(substrate, defs, ...)
}

# Production preparation with every direct choice recorded as
# "<feature id> <instrument>"; debug off unless asked.
cut24_choices <- function(substrate, defs, debug = FALSE, ...) {
  seen <- character()
  direct <- ledgr:::ledgr_history_feature_direct
  testthat::local_mocked_bindings(
    ledgr_history_feature_direct = function(cert, inputs, ...) {
      seen <<- c(seen, paste(cert$def$id, inputs$instrument_id))
      direct(cert, inputs, ...)
    },
    .package = "ledgr")
  value <- cut24_prepare(substrate, defs, debug, ...)
  list(value = value, seen = seen)
}

# Certifies once and serves those results to every preparation in the
# calling test, so call counters see calculation only (certification runs
# TTR's synthetic validation).
cut24_certified_once <- function(defs, frame = parent.frame()) {
  certified <- lapply(defs, ledgr:::ledgr_feature_certify)
  ids <- vapply(defs, function(d) d$id, "")
  testthat::local_mocked_bindings(
    ledgr_feature_certify = function(def) certified[[match(def$id, ids)]],
    .package = "ledgr", .env = frame)
  invisible(certified)
}

cut24_refusal <- function(expr) {
  e <- tryCatch({
    force(expr)
    NULL
  }, error = function(e) e)
  if (is.null(e)) return(NULL)
  fields <- unclass(e)[setdiff(names(unclass(e)), c("call", "trace", "parent", "rlang"))]
  list(class = class(e), message = conditionMessage(e), fields = fields[order(names(fields), method = "radix")])
}

testthat::test_that("[Cut 24 direct] the gate admits only complete single-range certified cells", {
  substrate <- cut24_gate_panel()
  defs <- cut24_defs(ledgr_ind_sma(3L), ledgr_ind_ttr("MFI", input = "hlcv", n = 3L),
                     ledgr_indicator("custom_close", fn = function(bars) as.numeric(utils::tail(bars$close, 1L)),
                                     requires_bars = 1L, required_fields = "close"))
  ids <- vapply(defs, function(d) d$id, "")
  got <- cut24_choices(substrate, defs)
  # DENSE passes for both certified definitions; VOLNA only for the
  # close-only one; GAP (a missing close), LATE (two knowledge ranges) and
  # INACT (unexpected columns) for none; TERM's terminal columns are
  # unexpected inside the calculation, so it fails too. The custom
  # definition never takes the direct path.
  testthat::expect_setequal(got$seen, c(paste(ids[[1L]], "DENSE"), paste(ids[[2L]], "DENSE"),
                                        paste(ids[[1L]], "VOLNA")))
  testthat::expect_identical(got$value, cut24_general(substrate, defs))

  # A terminal asserted in the prefix before a later calculation start, with
  # every calculation column expected: rejected by the terminal clause alone.
  late <- cut24_choices(substrate, defs, calculation_start = substrate$axis[[7L]])
  testthat::expect_false(any(grepl(" TERM$", late$seen)))
  testthat::expect_true(any(grepl(" DENSE$", late$seen)))
  testthat::expect_identical(late$value, cut24_general(substrate, defs, calculation_start = substrate$axis[[7L]]))
  term <- ledgr:::ledgr_history_feature_masks(substrate, 6L, 16L, substrate$axis[[16L]])
  testthat::expect_true(all(term$expected[7:16]))
  testthat::expect_true(any(term$terminal_asserted))

  # LATE's two ranges keep every column expected: the range clause alone.
  ranges <- ledgr:::ledgr_history_feature_ranges(substrate, 4L, 1L, 16L)
  testthat::expect_length(ranges$start, 2L)
  testthat::expect_true(all(ledgr:::ledgr_history_feature_masks(substrate, 4L, 16L, substrate$axis[[16L]])$expected))
})

testthat::test_that("[Cut 24 direct] admitted cells equal the general path on every catalogue row and policy", {
  defs <- cut24_direct_defs()
  policies <- list(ledgr_history_policy(price_carry = 2L, output_carry = 2L),
                   ledgr_history_policy(price_carry = 2L, output_carry = NULL),
                   ledgr_history_policy(price_carry = NULL))
  for (policy in policies) {
    substrate <- cut24_gate_panel(policy)
    general <- suppressWarnings(cut24_general(substrate, defs))
    off <- suppressWarnings(cut24_choices(substrate, defs, debug = FALSE))
    on <- suppressWarnings(cut24_prepare(substrate, defs, debug = TRUE))
    testthat::expect_identical(off$value, general)
    testthat::expect_identical(on, general)
    # Every certified row was admitted on DENSE; the unregistered, ohlc and
    # custom forms never were.
    certified <- vapply(defs, function(d) ledgr:::ledgr_feature_certify(d)$certification != "custom", logical(1))
    ids <- vapply(defs, function(d) d$id, "")
    testthat::expect_setequal(off$seen[grepl(" DENSE$", off$seen)], paste(ids[certified], "DENSE"))
    testthat::expect_false(any(c("ttr_sma_unreg", "ttr_vol_gk", "custom_volume") %in% sub(" .*$", "", off$seen)))
  }
})

testthat::test_that("[Cut 24 direct] later, short and never-ready slices and empty preparations", {
  substrate <- cut24_gate_panel()
  defs <- cut24_defs(ledgr_ind_sma(5L), ledgr_ind_ttr("SMA", input = "close", n = 3L, stable_after = 6L, id = "late6"),
                     ledgr_ind_ttr("MACD", input = "close", output = "histogram", nFast = 2L, nSlow = 3L, nSig = 2L))
  cut24_certified_once(defs)
  calls <- 0L
  raw_call <- ledgr:::ledgr_ttr_raw_call
  testthat::local_mocked_bindings(
    ledgr_ttr_raw_call = function(...) {
      calls <<- calls + 1L
      raw_call(...)
    }, .package = "ledgr")
  for (start in c(4L, 12L, 15L)) {
    calls <- 0L
    got <- cut24_choices(substrate, defs, calculation_start = substrate$axis[[start]])
    testthat::expect_identical(got$value, cut24_general(substrate, defs, calculation_start = substrate$axis[[start]]))
    if (start == 15L) {
      # Two sessions: shorter than every stable_after, so admitted cells
      # never become ready and no adapter call is made.
      testthat::expect_true(length(got$seen) > 0L)
      testthat::expect_identical(calls, 0L)
      planes <- attr(got$value, "ledgr_feature_planes")[[1L]]
      testthat::expect_true(all(is.na(planes$segment_ready)))
    }
  }

  # Empty bounds and zero definitions return before any gate or mask.
  testthat::local_mocked_bindings(
    ledgr_history_feature_gate = function(...) stop("gate built"),
    ledgr_history_feature_masks = function(...) stop("masks built"),
    .package = "ledgr")
  empty <- ledgr:::ledgr_history_compute_feature_series(substrate, defs,
    calculation_start = substrate$axis[[10L]], calculation_end = substrate$axis[[9L]])
  testthat::expect_true(all(vapply(empty, function(m) all(is.na(m)), logical(1))))
  none <- ledgr:::ledgr_history_compute_feature_series(substrate, list())
  testthat::expect_length(none, 0L)
})

testthat::test_that("[Cut 24 direct] a custom-only preparation builds no gate", {
  substrate <- cut24_gate_panel()
  defs <- cut24_defs(ledgr_indicator("custom_close", fn = function(bars) as.numeric(utils::tail(bars$close, 1L)),
                                     requires_bars = 1L, required_fields = "close"))
  general <- cut24_general(substrate, defs)
  testthat::local_mocked_bindings(ledgr_history_feature_gate = function(...) stop("gate built"), .package = "ledgr")
  testthat::expect_identical(cut24_prepare(substrate, defs, debug = TRUE), general)
  testthat::expect_identical(cut24_prepare(substrate, defs, debug = FALSE), general)
})

testthat::test_that("[Cut 24 direct] raw sharing: MACD and BBands outputs share one call per instrument", {
  n <- 14L
  substrate <- cut24_panel(list(AAA = cut24_close(n, 1), BBB = cut24_close(n, 2)))
  macd <- ledgr:::ledgr_indicator_bundle_indicators(
    ledgr_ind_ttr_outputs("MACD", input = "close", nFast = 2L, nSlow = 3L, nSig = 2L))
  bb <- ledgr:::ledgr_indicator_bundle_indicators(ledgr_ind_ttr_outputs("BBands", input = "close", n = 3L))
  defs <- do.call(cut24_defs, c(macd, bb))
  # Outputs share a call only within one input-carry family (BBands' outputs
  # span more than one): the expected calls per instrument.
  families <- vapply(cut24_certified_once(defs), function(cert) {
    paste(cert$def$params$ttr_fn, cert$declarations$input_carry)
  }, "")
  per_instrument <- sort(sub(" .*$", "", unique(families)))
  testthat::expect_identical(sum(per_instrument == "MACD"), 1L)
  # The sampled causality check recomputes prefixes with calls of its own;
  # it is the same on both paths (tested above) and left out here.
  testthat::local_mocked_bindings(ledgr_history_feature_causality = function(...) invisible(NULL), .package = "ledgr")
  calls <- character()
  raw_call <- ledgr:::ledgr_ttr_raw_call
  testthat::local_mocked_bindings(
    ledgr_ttr_raw_call = function(bars, params, ...) {
      calls <<- c(calls, params$ttr_fn)
      raw_call(bars, params, ...)
    }, .package = "ledgr")
  got <- cut24_choices(substrate, defs)
  testthat::expect_length(got$seen, length(defs) * 2L)
  # One call per family, carry family and instrument, as on the general path.
  testthat::expect_identical(sort(calls), sort(rep(per_instrument, 2L)))
  calls <- character()
  testthat::expect_identical(got$value, cut24_general(substrate, defs))
  testthat::expect_identical(sort(calls), sort(rep(per_instrument, 2L)))
  # Debug: the shadow has its own cache, so each call is made once more per
  # instrument, never served from the product's cache.
  calls <- character()
  cut24_prepare(substrate, defs, debug = TRUE)
  testthat::expect_identical(sort(calls), sort(rep(per_instrument, 4L)))
})

testthat::test_that("[Cut 24 direct] production keeps the causality probe on the same counts", {
  substrate <- cut24_gate_panel()
  defs <- cut24_defs(ledgr_ind_sma(3L), ledgr_ind_ttr("ATR", input = "hlc", output = "atr", n = 3L))
  seen <- list()
  causality <- ledgr:::ledgr_history_feature_causality
  testthat::local_mocked_bindings(
    ledgr_history_feature_causality = function(substrate, certified, bounds, calculated_count, values) {
      seen[[length(seen) + 1L]] <<- calculated_count
      causality(substrate, certified, bounds, calculated_count, values)
    }, .package = "ledgr")
  cut24_prepare(substrate, defs, debug = FALSE)
  cut24_prepare(substrate, defs, debug = TRUE)
  cut24_general(substrate, defs)
  testthat::expect_length(seen, 3L)
  testthat::expect_identical(seen[[1L]], seen[[3L]])
  testthat::expect_identical(seen[[2L]], seen[[3L]])
})

testthat::test_that("[Cut 24 direct] refusals keep the general path's class, payload and order", {
  substrate <- cut24_gate_panel()
  sd1 <- cut24_defs(ledgr_ind_ttr("runSD", input = "close", n = 1L))[[1L]]
  bad <- cut24_defs(ledgr_indicator("custom_refuses", fn = function(bars) 0, requires_bars = 1L,
                                    series_fn = function(bars) rep(NA_real_, nrow(bars)),
                                    required_fields = "close"))[[1L]]
  # The admitted runSD(n = 1) cell refuses like the general path, with debug
  # off and on (an agreed refusal re-raises the product condition).
  for (defs in list(list(sd1), list(sd1, bad), list(bad, sd1))) {
    expected <- suppressWarnings(cut24_refusal(cut24_general(substrate, defs)))
    testthat::expect_false(is.null(expected))
    for (debug in c(FALSE, TRUE)) {
      testthat::expect_identical(suppressWarnings(cut24_refusal(cut24_prepare(substrate, defs, debug))), expected)
    }
  }
  # Within DENSE (admitted), the definition order decides.
  testthat::expect_match(suppressWarnings(cut24_refusal(cut24_prepare(substrate, list(sd1, bad), FALSE)))$message,
                         "ttr_runsd_1")
  testthat::expect_match(suppressWarnings(cut24_refusal(cut24_prepare(substrate, list(bad, sd1), FALSE)))$message,
                         "custom_refuses")
  # Across instruments the instrument order decides: a custom definition
  # refusing only on VOLNA, listed first, loses to runSD's admitted refusal
  # on DENSE, the first instrument.
  volna <- cut24_defs(ledgr_indicator("volna_refuses", fn = function(bars) 0, requires_bars = 1L,
    series_fn = function(bars) if (identical(bars$instrument_id[[1L]], "VOLNA")) rep(NA_real_, nrow(bars)) else as.numeric(bars$close),
    required_fields = "close"))[[1L]]
  defs <- list(volna, sd1)
  expected <- suppressWarnings(cut24_refusal(cut24_general(substrate, defs)))
  testthat::expect_match(expected$message, "ttr_runsd_1")
  for (debug in c(FALSE, TRUE)) {
    testthat::expect_identical(suppressWarnings(cut24_refusal(cut24_prepare(substrate, defs, debug))), expected)
  }
  # Across ranges: on LATE (two knowledge ranges, general path) a refusal in
  # its second range only, after the admitted cells before it succeeded.
  only_late <- cut24_defs(ledgr_indicator("late_range_refuses", fn = function(bars) 0, requires_bars = 1L,
    series_fn = function(bars) {
      if (identical(bars$instrument_id[[1L]], "LATE") && nrow(bars) > 12L) rep(NA_real_, nrow(bars)) else as.numeric(bars$close)
    },
    required_fields = "close"))[[1L]]
  defs <- list(cut24_defs(ledgr_ind_sma(3L))[[1L]], only_late)
  expected <- cut24_refusal(cut24_general(substrate, defs))
  testthat::expect_match(expected$message, "late_range_refuses")
  for (debug in c(FALSE, TRUE)) {
    testthat::expect_identical(cut24_refusal(cut24_prepare(substrate, defs, debug)), expected)
  }
})

testthat::test_that("[Cut 24 direct] the debug comparison fails closed on any single disagreement", {
  substrate <- cut24_panel(list(AAA = cut24_close(12L, 1)))
  defs <- cut24_defs(ledgr_ind_sma(3L))
  direct <- ledgr:::ledgr_history_feature_direct
  perturb <- function(change) {
    testthat::local_mocked_bindings(
      ledgr_history_feature_direct = function(...) change(direct(...)), .package = "ledgr")
    cut24_refusal(cut24_prepare(substrate, defs, debug = TRUE))
  }
  for (change in list(
    one_value = function(x) { x$value[[8L]] <- x$value[[8L]] + 1e-12; x },
    one_count = function(x) { x$count <- x$count + 1L; x },
    one_segment_ready = function(x) { x$exceptions$segment_ready <- x$exceptions$segment_ready + 1L; x },
    one_record = function(x) { x$exceptions$input_col <- 5L; x })) {
    refusal <- perturb(change)
    testthat::expect_identical(refusal$class[1:2], c("ledgr_feature_debug_mismatch", "ledgr_internal_error"))
  }
  # With debug off the same perturbation passes unnoticed: the comparison is
  # debug's, production trusts the gate.
  testthat::local_mocked_bindings(
    ledgr_history_feature_direct = function(...) { x <- direct(...); x$count <- x$count + 1L; x }, .package = "ledgr")
  testthat::expect_null(cut24_refusal(cut24_prepare(substrate, defs, debug = FALSE)))

  # A refusal differing only in one identifying field, or only in class.
  sd1 <- cut24_defs(ledgr_ind_ttr("runSD", input = "close", n = 1L))
  for (change in list(
    field = function(e) { e$feature_id <- "other"; e },
    class = function(e) { class(e) <- c("ledgr_other_refusal", class(e)); e })) {
    testthat::local_mocked_bindings(
      ledgr_history_feature_direct = function(...) {
        tryCatch(direct(...), error = function(e) stop(change(e)))
      }, .package = "ledgr")
    refusal <- suppressWarnings(cut24_refusal(cut24_prepare(substrate, sd1, debug = TRUE)))
    testthat::expect_identical(refusal$class[1:2], c("ledgr_feature_debug_mismatch", "ledgr_internal_error"))
  }
  # Success against refusal.
  testthat::local_mocked_bindings(
    ledgr_history_feature_direct = function(...) stop("direct refused"), .package = "ledgr")
  refusal <- cut24_refusal(cut24_prepare(substrate, defs, debug = TRUE))
  testthat::expect_identical(refusal$class[1:2], c("ledgr_feature_debug_mismatch", "ledgr_internal_error"))
})

testthat::test_that("[Cut 24 direct] an admitted preparation refusal precedes candidates and writes nothing", {
  snapshot <- availability_runtime_fixture(days = 8L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  ran <- new.env(parent = emptyenv())
  ran$n <- 0L
  experiment <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot,
    function(ctx, params) {
      ran$n <- ran$n + 1L
      ctx$hold()
    },
    features = list(ledgr_ind_ttr("runSD", input = "close", n = 1L)),
    valuation_policy = ledgr_valuation_stale(1L), cost_model = ledgr_cost_zero())
  con <- get_connection(snapshot)
  store_rows <- function(table, run_id = NULL) {
    if (!DBI::dbExistsTable(con, table)) return(0)
    sql <- sprintf("SELECT COUNT(*) AS n FROM %s", table)
    if (!is.null(run_id)) sql <- paste0(sql, sprintf(" WHERE run_id = '%s'", run_id))
    DBI::dbGetQuery(con, sql)$n
  }
  seen <- 0L
  direct <- ledgr:::ledgr_history_feature_direct
  testthat::local_mocked_bindings(
    ledgr_history_feature_direct = function(...) {
      seen <<- seen + 1L
      direct(...)
    }, .package = "ledgr")
  grid <- ledgr_grid_named(one = list(strategy = list()))
  for (debug in c(FALSE, TRUE)) {
    local({
      ledgr:::local_ledgr_debug(debug)
      testthat::expect_error(suppressWarnings(ledgr_precompute_features(experiment, grid)),
                             class = "ledgr_invalid_feature_output")
      testthat::expect_error(suppressWarnings(ledgr_sweep(experiment, grid, stop_on_error = TRUE)),
                             class = "ledgr_invalid_feature_output")
    })
  }
  testthat::expect_true(seen > 0L)
  for (table in c("runs", "ledger_events", "equity_curve")) {
    testthat::expect_identical(store_rows(table), 0, info = table)
  }
  testthat::expect_error(suppressWarnings(ledgr_run(experiment, run_id = "cut24-direct-refusal")),
                         class = "ledgr_invalid_feature_output")
  testthat::expect_identical(ran$n, 0L)
  testthat::expect_identical(ledgr_run_info(snapshot, "cut24-direct-refusal")$status, "FAILED")
  for (table in c("ledger_events", "equity_curve")) {
    testthat::expect_identical(store_rows(table, "cut24-direct-refusal"), 0, info = table)
  }
})
