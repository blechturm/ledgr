availability_v201_at <- function(day, time = "00:00:00") {
  date <- as.Date("2021-01-04") + as.integer(day) - 1L
  as.POSIXct(paste(date, time), tz = "UTC")
}

availability_v201_na_time <- function(n = 1L) {
  as.POSIXct(rep(NA_real_, n), origin = "1970-01-01", tz = "UTC")
}

availability_v201_provider_config <- function(ids, universe_id = "U") {
  list(
    data = list(snapshot_id = "witness"),
    universe = list(instrument_ids = ids),
    availability = list(
      active = TRUE,
      universe_rule = list(universe_id = universe_id),
      execution_timing_version = 2L,
      valuation_policy = NULL
    )
  )
}

availability_v201_provider_data <- function(empty_status = FALSE) {
  ids <- c("AAA", "BBB", "CCC", "DDD")
  headers <- data.frame(
    universe_id = "U",
    set_id = c("L1", "P1", "L2"),
    effective_from = availability_v201_at(c(1L, 3L, 5L)),
    knowledge_time = availability_v201_at(c(0L, 2L, 6L)),
    complete = c(TRUE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )
  set_rows <- data.frame(
    universe_id = "U",
    set_id = c("L1", "L1", "P1", "L2", "L2"),
    instrument_id = c("AAA", "BBB", "CCC", "BBB", "CCC"),
    fact_id = paste0("set_", seq_len(5L)),
    effective_from = availability_v201_at(c(1L, 1L, 3L, 5L, 5L)),
    effective_to = availability_v201_na_time(5L),
    knowledge_time = availability_v201_at(c(0L, 0L, 2L, 6L, 6L)),
    member = TRUE,
    stringsAsFactors = FALSE
  )
  interval_rows <- data.frame(
    universe_id = "U",
    set_id = NA_character_,
    instrument_id = c("DDD", "AAA"),
    fact_id = c("interval_ddd", "interval_aaa"),
    effective_from = availability_v201_at(c(2L, 7L)),
    effective_to = c(
      availability_v201_at(8L),
      availability_v201_na_time()
    ),
    knowledge_time = availability_v201_at(c(2L, 7L)),
    member = c(TRUE, FALSE),
    stringsAsFactors = FALSE
  )

  status <- data.frame(
    instrument_id = c("AAA", "AAA", "BBB", "BBB", "CCC", "CCC"),
    effective_from = availability_v201_at(c(1L, 3L, 1L, 1L, 4L, 4L)),
    effective_to = c(
      availability_v201_na_time(),
      availability_v201_at(5L),
      availability_v201_na_time(),
      availability_v201_na_time(),
      availability_v201_at(6L),
      availability_v201_at(6L)
    ),
    knowledge_time = availability_v201_at(c(0L, 2L, 0L, 4L, 3L, 3L)),
    status = c(
      "active", "halted", "halted", "active", "halted", "quotation_only"
    ),
    source = c("base", "venue", "venue", "venue", "venue", "alt"),
    precedence = c(0L, 5L, 5L, 5L, 5L, 5L),
    fact_id = c(
      "aaa_base", "aaa_halt", "bbb_halt", "bbb_lift",
      "ccc_halt", "ccc_quote"
    ),
    supersedes_fact_id = c(
      NA_character_, NA_character_, NA_character_, "bbb_halt",
      NA_character_, NA_character_
    ),
    stringsAsFactors = FALSE
  )
  if (isTRUE(empty_status)) status <- status[0, , drop = FALSE]

  lifetime <- data.frame(
    instrument_id = c("AAA", "BBB", "CCC", "DDD", "DDD"),
    effective_from = availability_v201_at(c(1L, 1L, 1L, 1L, 7L)),
    effective_to = c(
      availability_v201_na_time(3L),
      availability_v201_at(7L),
      availability_v201_na_time()
    ),
    knowledge_time = availability_v201_at(c(0L, 0L, 0L, 0L, 8L)),
    assertion = c(
      "known_active", "known_active", "known_active", "known_active",
      "known_inactive"
    ),
    terminal_event = c(
      NA_character_, NA_character_, NA_character_, NA_character_, "delisted"
    ),
    stringsAsFactors = FALSE
  )

  sessions <- data.frame(
    session_date = as.Date("2021-01-04") + 0:8,
    status = "open",
    session_open = availability_v201_at(1:9, "14:30:00"),
    session_close = availability_v201_at(1:9, "21:00:00"),
    knowledge_time = availability_v201_at(rep(0L, 9L)),
    stringsAsFactors = FALSE
  )

  list(
    ids = ids,
    data = list(
      families = data.frame(
        family = c("membership", "sessions", "trading_status", "lifetime"),
        scope_id = c("U", "SYNTH", "", ""),
        stringsAsFactors = FALSE
      ),
      membership_sets = headers,
      membership = rbind(set_rows, interval_rows),
      status = status,
      lifetime = lifetime,
      sessions = sessions
    )
  )
}

availability_v201_build_provider <- function(arm, data, config) {
  history <- function(...) stop("history is unreachable in provider witnesses")
  if (identical(arm, "reference")) {
    return(availability_reference_provider_build_current(
      data,
      config,
      "witness-hash",
      history
    ))
  }
  prior <- options(ledgr.internal.spike_availability_provider = arm)
  on.exit(options(prior), add = TRUE)
  ledgr:::ledgr_availability_provider_build(
    data,
    config,
    "witness-hash",
    history
  )
}

availability_v201_normalize_identity <- function(row) {
  out <- row[, setdiff(names(row), "created_at_utc"), drop = FALSE]
  cfg <- yyjsonr::read_json_str(as.character(row$config_json))
  cfg$db_path <- NULL
  cfg$data$snapshot_db_path <- NULL
  out$config_json <- yyjsonr::write_json_str(cfg, auto_unbox = TRUE)
  out
}

availability_v201_read_store <- function(path, run_id) {
  opened <- ledgr_test_open_duckdb(path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  query <- function(sql) {
    DBI::dbGetQuery(opened$con, sql, params = list(run_id))
  }
  identity <- query("SELECT * FROM runs WHERE run_id = ?")
  list(
    identity = availability_v201_normalize_identity(identity),
    diagnostics = query(
      "SELECT * FROM run_diagnostics WHERE run_id = ? ORDER BY diagnostic_seq"
    ),
    events = query(
      "SELECT * FROM ledger_events WHERE run_id = ? ORDER BY event_seq"
    ),
    equity = query(
      "SELECT * FROM equity_curve WHERE run_id = ? ORDER BY ts_utc"
    ),
    state = query(
      "SELECT * FROM strategy_state WHERE run_id = ? ORDER BY ts_utc"
    ),
    completion = query("SELECT * FROM run_completion WHERE run_id = ?")
  )
}

availability_v201_strip_run_id <- function(x) {
  if (is.data.frame(x) && "run_id" %in% names(x)) x$run_id <- NULL
  x
}

availability_v201_expect_frozen <- function(actual, expected) {
  testthat::expect_identical(actual, expected)
}

availability_v201_assert_frozen <- function(actual, expected) {
  if (!identical(actual, expected)) stop("frozen witness mismatch", call. = FALSE)
  invisible(TRUE)
}

availability_v201_fold_fixture <- function() {
  ids <- c("AAA", "BBB", "CCC", "DDD", "EEE", "FFF")
  dates <- as.Date("2021-01-04") + 0:11
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "14:30:00",
      session_close = "21:00:00",
      knowledge_time = availability_v201_at(rep(0L, length(dates))),
      stringsAsFactors = FALSE
    ),
    venue_id = "SYNTH"
  )
  membership <- data.frame(
    effective_from = availability_v201_at(c(1L, 5L, 7L)),
    knowledge_time = availability_v201_at(c(0L, 4L, 6L)),
    set_id = c("L1", "L2", "P1"),
    members = I(list(
      c("AAA", "BBB", "CCC", "DDD"),
      c("AAA", "CCC", "DDD", "EEE"),
      "FFF"
    )),
    source = "witness",
    stringsAsFactors = FALSE
  )
  status <- data.frame(
    instrument_id = c(ids, "AAA", "CCC", "CCC"),
    effective_from = c(
      availability_v201_at(rep(1L, length(ids))),
      availability_v201_at(c(3L, 6L, 6L))
    ),
    effective_to = c(
      availability_v201_na_time(length(ids)),
      availability_v201_at(5L),
      availability_v201_na_time(2L)
    ),
    knowledge_time = c(
      availability_v201_at(rep(0L, length(ids))),
      availability_v201_at(c(2L, 5L, 8L))
    ),
    status = c(rep("active", length(ids)), "halted", "halted", "active"),
    source = c(rep("base", length(ids)), "venue", "venue", "venue"),
    precedence = c(rep(0L, length(ids)), 5L, 5L, 5L),
    fact_id = c(
      paste0("base_", ids),
      "aaa_halt",
      "ccc_halt",
      "ccc_lift"
    ),
    supersedes_fact_id = c(
      rep(NA_character_, length(ids) + 2L),
      "ccc_halt"
    ),
    stringsAsFactors = FALSE
  )
  lifetime <- rbind(
    data.frame(
      instrument_id = setdiff(ids, "EEE"),
      effective_from = availability_v201_at(1L),
      effective_to = availability_v201_na_time(length(ids) - 1L),
      knowledge_time = availability_v201_at(0L),
      assertion = "known_active",
      terminal_event = NA_character_,
      source = "witness",
      stringsAsFactors = FALSE
    ),
    data.frame(
      instrument_id = c("EEE", "EEE"),
      effective_from = availability_v201_at(c(1L, 10L)),
      effective_to = c(
        availability_v201_at(10L),
        availability_v201_na_time()
      ),
      knowledge_time = availability_v201_at(c(0L, 10L)),
      assertion = c("known_active", "known_inactive"),
      terminal_event = c(NA_character_, "delisted"),
      source = "witness",
      stringsAsFactors = FALSE
    )
  )
  facts <- ledgr_facts(
    sessions,
    ledgr_facts_membership_snapshots(
      membership,
      "U",
      complete = c(TRUE, TRUE, FALSE)
    ),
    ledgr_facts_trading_status(status),
    ledgr_facts_lifetime(lifetime)
  )
  bars <- do.call(rbind, lapply(seq_along(dates), function(k) {
    close <- 100 + seq_along(ids) + k / 10
    data.frame(
      ts_utc = as.POSIXct(paste(dates[[k]], "21:00:00"), tz = "UTC"),
      instrument_id = ids,
      open = close,
      high = close + 1,
      low = close - 1,
      close = close,
      volume = 1e5,
      stringsAsFactors = FALSE
    )
  }))
  missing <- bars$instrument_id == "BBB" &
    bars$ts_utc == availability_v201_at(4L, "21:00:00")
  bars <- bars[!missing, , drop = FALSE]
  list(
    ids = ids,
    dates = dates,
    bars = bars,
    instruments = data.frame(instrument_id = ids),
    facts = facts
  )
}

availability_v201_fold_strategy <- function(ctx, params) {
  if (identical(ctx$ts_utc, getOption("ledgr.v201.interrupt_at", ""))) {
    options(ledgr.interrupt = TRUE)
  }
  if (identical(ctx$ts_utc, getOption("ledgr.v201.fail_at", ""))) {
    stop("injected v0.2.0.1 witness failure")
  }
  target <- ctx$hold()
  member <- ctx$vec$member
  restricted <- ctx$vec$target_restricted
  positions <- ctx$vec$positions
  pulse <- as.integer(substr(ctx$ts_utc, 9L, 10L))
  target[member & !restricted] <- 5 + pulse
  reduce <- !member & !restricted & positions != 0
  target[reduce] <- floor(positions[reduce] / 2)

  increase_at <- getOption("ledgr.v201.increase_nonmember_at", "")
  if (
    nzchar(increase_at) &&
      ctx$ts_utc >= increase_at &&
      any(!member & positions != 0)
  ) {
    index <- which(!member & positions != 0)[[1L]]
    target[[index]] <- positions[[index]] + 1
  }
  exit_from <- getOption("ledgr.v201.exit_eee_from", "")
  if (
    nzchar(exit_from) &&
      ctx$ts_utc >= exit_from &&
      "EEE" %in% names(target)
  ) {
    target[["EEE"]] <- 0
  }
  target
}

availability_v201_set_fold_arm <- function(arm, chunk_rows) {
  options(
    ledgr.internal.spike_availability_provider = "prepared",
    ledgr.internal.spike_diagnostic_writer = "columnar",
    ledgr.internal.spike_diagnostic_chunk_rows = as.integer(chunk_rows),
    ledgr.internal.spike_diagnostic_block =
      if (identical(arm, "block")) "on" else "off"
  )
}

availability_v201_run_invocation <- function(experiment, run_id) {
  handle <- NULL
  error <- tryCatch(
    {
      handle <- ledgr_run(experiment, run_id = run_id)
      NULL
    },
    error = identity
  )
  if (!is.null(handle)) close(handle)
  error
}

availability_v201_run_case <- function(arm,
                                       scenario,
                                       chunk_rows = 7L,
                                       interrupt_day = NULL,
                                       fail_day = NULL,
                                       increase_day = NULL,
                                       resume_fail_day = NULL,
                                       exit_day = NULL) {
  fixture <- availability_v201_fold_fixture()
  db <- tempfile(paste0("availability_v201_", arm, "_"), fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(
    fixture$bars,
    instruments_df = fixture$instruments,
    db_path = db,
    snapshot_id = "witness",
    facts = fixture$facts
  )
  on.exit({
    ledgr_snapshot_close(snapshot)
    unlink(c(db, paste0(db, ".wal")), force = TRUE)
  }, add = TRUE)
  availability_v201_set_fold_arm(arm, chunk_rows)
  timestamp <- function(day) {
    if (is.null(day)) "" else {
      format(
        availability_v201_at(day, "21:00:00"),
        "%Y-%m-%dT%H:%M:%SZ",
        tz = "UTC"
      )
    }
  }
  prior <- options(
    ledgr.interrupt = FALSE,
    ledgr.v201.interrupt_at = timestamp(interrupt_day),
    ledgr.v201.fail_at = timestamp(fail_day),
    ledgr.v201.increase_nonmember_at = timestamp(increase_day),
    ledgr.v201.exit_eee_from = timestamp(exit_day)
  )
  on.exit(options(prior), add = TRUE)
  experiment <- ledgr_experiment(
    snapshot,
    availability_v201_fold_strategy,
    universe = ledgr_universe_members("U"),
    valuation_policy = ledgr_valuation_stale(max_sessions = 2L),
    cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1e6)
  )
  run_id <- paste0("availability-v201-", scenario)
  first_error <- availability_v201_run_invocation(experiment, run_id)
  first <- availability_v201_read_store(db, run_id)
  final <- first
  resume_error <- NULL
  if (!is.null(interrupt_day)) {
    options(
      ledgr.interrupt = FALSE,
      ledgr.v201.interrupt_at = "",
      ledgr.v201.fail_at = timestamp(resume_fail_day)
    )
    resume_error <- availability_v201_run_invocation(experiment, run_id)
    final <- availability_v201_read_store(db, run_id)
  }
  list(
    first_error = first_error,
    resume_error = resume_error,
    first = first,
    final = final
  )
}

availability_v201_compare_store <- function(x, y) {
  surfaces <- c(
    "identity", "diagnostics", "events", "equity", "state", "completion"
  )
  vapply(surfaces, function(surface) {
    identical(
      availability_v201_strip_run_id(x[[surface]]),
      availability_v201_strip_run_id(y[[surface]])
    )
  }, logical(1))
}

availability_v201_case_summary <- function(result, scenario, arm, chunk_rows) {
  final <- result$final
  data.frame(
    scenario = scenario,
    arm = arm,
    chunk_rows = as.integer(chunk_rows),
    first_status = result$first$identity$status,
    final_status = final$identity$status,
    first_error_class = if (is.null(result$first_error)) {
      ""
    } else {
      class(result$first_error)[[1L]]
    },
    resume_error_class = if (is.null(result$resume_error)) {
      ""
    } else {
      class(result$resume_error)[[1L]]
    },
    diagnostics = nrow(final$diagnostics),
    decision = sum(final$diagnostics$stage == "decision"),
    execution = sum(final$diagnostics$stage == "execution"),
    errors = sum(final$diagnostics$outcome == "error"),
    events = nrow(final$events),
    equity = nrow(final$equity),
    state = nrow(final$state),
    completion = nrow(final$completion),
    sequence_continuous = identical(
      as.integer(final$diagnostics$diagnostic_seq),
      seq_len(nrow(final$diagnostics))
    ),
    stringsAsFactors = FALSE
  )
}

availability_v201_freeze_frame <- function(x) {
  out <- lapply(x, function(column) {
    if (inherits(column, "POSIXt")) {
      value <- format(
        as.POSIXct(column, tz = "UTC"),
        "%Y-%m-%dT%H:%M:%SZ",
        tz = "UTC"
      )
    } else if (is.numeric(column)) {
      value <- format(
        column,
        digits = 17L,
        scientific = FALSE,
        trim = TRUE
      )
    } else {
      value <- as.character(column)
    }
    value[is.na(column)] <- "<NA>"
    value
  })
  out <- as.data.frame(out, stringsAsFactors = FALSE, check.names = FALSE)
  rownames(out) <- NULL
  out
}
