# ledgr-test-file-profile: review

# New York sessions on 2021-01-04..08 (open 14:30 UTC, close 21:00 UTC).
ws45_sessions <- function(dates = as.Date("2021-01-04") + 0:4) {
  ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00",
      knowledge_time = as.POSIXct("2020-12-31", tz = "UTC"),
      stringsAsFactors = FALSE
    ),
    venue_id = "XNYS",
    timezone = "America/New_York"
  )
}

ws45_utc <- function(x) as.POSIXct(x, tz = "UTC")

ws45_action <- function(...) {
  base <- data.frame(
    fact_id = "ca-1",
    subtype = "ordinary_cash_dividend",
    parent_instrument_id = "AAA",
    complete = TRUE,
    provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = 1,
    gross_cash_validated = TRUE,
    source = "ws45",
    stringsAsFactors = FALSE
  )
  extra <- list(...)
  for (name in names(extra)) base[[name]] <- extra[[name]]
  base
}

ws45_action_row <- function(bundle) {
  ledgr:::ledgr_facts_family(bundle, "equity_corporate_actions")[[1L]]$rows
}

# Literal ancestry: walk each row's supersession links to the root.
ws45_ancestry_oracle <- function(rows) {
  parent <- match(rows$supersedes_fact_id, rows$fact_id)
  n <- nrow(rows)
  out <- matrix(FALSE, n, n)
  for (d in seq_len(n)) {
    a <- parent[[d]]
    steps <- 0L
    while (!is.na(a) && steps <= n) {
      out[a, d] <- TRUE
      a <- parent[[a]]
      steps <- steps + 1L
    }
  }
  out
}

ws45_random_forest <- function(acyclic = TRUE) {
  at <- function(day) ws45_utc("2020-01-01") + day * 86400
  n <- sample.int(12L, 1L)
  ids <- sprintf("f%02d", seq_len(n))
  parent <- rep(NA_character_, n)
  for (i in seq_len(n)) {
    if (i > 1L && stats::runif(1) < 0.55) parent[[i]] <- ids[[sample.int(i - 1L, 1L)]]
  }
  if (!acyclic) {
    # A closed chain f01 <- f02 <- ... <- f0k <- f01 among the rows.
    k <- max(2L, sample.int(n, 1L))
    if (n < k) {
      n <- k
      ids <- sprintf("f%02d", seq_len(n))
      parent <- c(parent, rep(NA_character_, k - length(parent)))
    }
    parent[seq_len(k)] <- ids[c(k, seq_len(k - 1L))]
  }
  from <- sample(0:9, n, replace = TRUE)
  to <- at(from + sample(1:5, n, replace = TRUE))
  to[stats::runif(n) < 0.2] <- ws45_utc(NA)
  rows <- data.frame(
    fact_id = ids,
    instrument_id = sample(c("AAA", "BBB"), n, replace = TRUE, prob = c(0.8, 0.2)),
    source = sample(c("venue", "vendor"), n, replace = TRUE, prob = c(0.85, 0.15)),
    precedence = sample(1:2, n, replace = TRUE, prob = c(0.85, 0.15)),
    status = sample(c("active", "halted", "quotation_only"), n, replace = TRUE),
    effective_from = at(from),
    effective_to = to,
    knowledge_time = at(from),
    supersedes_fact_id = parent,
    stringsAsFactors = FALSE
  )
  rows[sample.int(n), , drop = FALSE]
}

testthat::test_that("[LTB-0351] correction lineage is built once per family and read by index", {
  withr::local_seed(20261021)
  for (i in seq_len(300L)) {
    rows <- ws45_random_forest()
    lineage <- ledgr:::ledgr_status_lineage(rows)
    n <- nrow(rows)
    pairs <- expand.grid(a = seq_len(n), d = seq_len(n))
    observed <- matrix(
      ledgr:::ledgr_status_is_ancestor(lineage, pairs$a, pairs$d),
      n,
      n
    )
    testthat::expect_identical(observed, ws45_ancestry_oracle(rows), info = i)
    testthat::expect_setequal(lineage$entry, seq_len(n))
  }
  for (i in seq_len(20L)) {
    testthat::expect_error(
      ledgr:::ledgr_status_lineage(ws45_random_forest(acyclic = FALSE)),
      class = "ledgr_fact_invalid_supersession"
    )
  }

  plain <- data.frame(
    fact_id = c("a", "b", "c"),
    supersedes_fact_id = NA_character_,
    stringsAsFactors = FALSE
  )
  trivial <- ledgr:::ledgr_status_lineage(plain)
  testthat::expect_identical(trivial$entry, 1:3)
  testthat::expect_identical(trivial$exit, 1:3)

  at <- function(day) ws45_utc("2021-01-01") + day * 86400
  status <- data.frame(
    instrument_id = "AAA",
    effective_from = at(c(1, 1, 1, 5)),
    effective_to = at(c(4, 4, 4, 8)),
    knowledge_time = at(c(1, 2, 3, 5)),
    status = c("halted", "active", "quotation_only", "active"),
    source = "venue",
    fact_id = c("a", "b", "c", "d"),
    supersedes_fact_id = c(NA, "a", "b", NA),
    stringsAsFactors = FALSE
  )
  calls <- 0L
  lineage_fn <- ledgr:::ledgr_status_lineage
  testthat::local_mocked_bindings(
    ledgr_status_lineage = function(rows) {
      calls <<- calls + 1L
      lineage_fn(rows)
    },
    .package = "ledgr"
  )
  ledgr_facts_trading_status(status)
  testthat::expect_identical(calls, 1L)
  calls <- 0L
  ledgr_facts_trading_status(status[c(1L, 4L), setdiff(names(status), "supersedes_fact_id")])
  testthat::expect_identical(calls, 0L)
  calls <- 0L
  dated <- status
  dated$knowledge_time <- as.Date("2021-01-04") + c(0L, 1L, 2L, 3L)
  family <- ledgr_facts_trading_status(dated)
  testthat::expect_identical(calls, 0L)
  ledgr_facts(ws45_sessions(), family)
  testthat::expect_identical(calls, 1L)
})

testthat::test_that("[LTB-0352] tied-source conflicts with corrections equal a pairwise ancestry oracle", {
  withr::local_seed(20261022)
  oracle <- function(rows) {
    related <- ws45_ancestry_oracle(rows)
    related <- related | t(related)
    starts <- as.numeric(rows$effective_from)
    ends <- as.numeric(rows$effective_to)
    ends[is.na(ends)] <- Inf
    n <- nrow(rows)
    for (i in seq_len(n)) for (j in seq_len(n)) {
      if (i < j && !related[i, j] &&
          rows$instrument_id[[i]] == rows$instrument_id[[j]] &&
          rows$source[[i]] == rows$source[[j]] &&
          rows$precedence[[i]] == rows$precedence[[j]] &&
          rows$status[[i]] != rows$status[[j]] &&
          starts[[i]] < ends[[j]] && starts[[j]] < ends[[i]]) {
        return("conflict")
      }
    }
    "ok"
  }
  outcomes <- character()
  for (i in seq_len(400L)) {
    rows <- ws45_random_forest()
    observed <- tryCatch(
      {
        ledgr:::ledgr_fact_validate_source_conflicts(rows)
        "ok"
      },
      ledgr_fact_structural_conflict = function(e) "conflict"
    )
    testthat::expect_identical(observed, oracle(rows), info = i)
    outcomes <- c(outcomes, observed)
  }
  testthat::expect_true(all(c("ok", "conflict") %in% outcomes))
})

testthat::test_that("[LTB-0353] civil resolution formats and encodes each session once", {
  sessions <- ws45_sessions()
  dates <- as.Date("2021-01-04") + rep(0:3, length.out = 1200L)
  membership <- ledgr_facts_membership_intervals(
    data.frame(
      instrument_id = sprintf("I%04d", seq_along(dates)),
      effective_from = dates,
      effective_to = dates + 1L,
      knowledge_time = dates,
      member = TRUE,
      source = "ws45"
    ),
    universe_id = "u"
  )
  token_lengths <- integer()
  frame_rows <- integer()
  token <- ledgr:::ledgr_fact_time_token
  writer <- ledgr:::ledgr_json_write_canonical_ndjson
  testthat::local_mocked_bindings(
    ledgr_fact_time_token = function(x) {
      token_lengths <<- c(token_lengths, length(x))
      token(x)
    },
    ledgr_json_write_canonical_ndjson = function(frame) {
      frame_rows <<- c(frame_rows, nrow(frame))
      writer(frame)
    },
    .package = "ledgr"
  )
  bundle <- ledgr_facts(sessions, membership)
  # Five sessions: every formatting call and every evidence write covers at
  # most the five sessions, never the 1,200 rows.
  testthat::expect_lte(max(token_lengths), 5L)
  testthat::expect_lte(max(frame_rows), 5L)
  testthat::expect_identical(length(frame_rows), 2L)
  row <- ledgr:::ledgr_facts_family(bundle, "membership")[[1L]]$rows[1L, ]
  testthat::expect_identical(
    row$civil_time_json,
    paste0(
      '{"effective_from":{"calendar_id":"XNYS","civil_date":"2021-01-04",',
      '"resolved_ts_utc":"2021-01-04T14:30:00Z","timezone":"America/New_York",',
      '"venue_id":"XNYS"},"effective_to":{"calendar_id":"XNYS",',
      '"civil_date":"2021-01-05","resolved_ts_utc":"2021-01-05T14:30:00Z",',
      '"timezone":"America/New_York","venue_id":"XNYS"},"knowledge_time":',
      '{"calendar_id":"XNYS","civil_date":"2021-01-04",',
      '"resolved_ts_utc":"2021-01-04T14:30:00Z","timezone":"America/New_York",',
      '"venue_id":"XNYS"}}'
    )
  )
  testthat::expect_identical(
    as.numeric(row$effective_to),
    as.numeric(ws45_utc("2021-01-05 14:30:00"))
  )
})

testthat::test_that("[LTB-0354] an edited family is refused whatever else the bundle holds", {
  at <- function(day) ws45_utc("2021-01-01") + day * 86400
  status <- ledgr_facts_trading_status(data.frame(
    instrument_id = "AAA", effective_from = at(3), effective_to = at(6),
    knowledge_time = at(3), status = "halted", source = "venue",
    stringsAsFactors = FALSE
  ))
  edited <- status
  edited$rows$status <- "active"
  civil <- ledgr_facts_membership_intervals(
    data.frame(
      instrument_id = "AAA", effective_from = as.Date("2021-01-04"),
      knowledge_time = as.Date("2021-01-04"), member = TRUE, source = "ws45"
    ),
    universe_id = "u"
  )
  refusal <- function(bundle) {
    tryCatch(
      {
        ledgr:::ledgr_facts_assert(bundle)
        "accepted"
      },
      ledgr_invalid_facts = function(e) conditionMessage(e)
    )
  }
  without_civil <- refusal(ledgr_facts(edited))
  with_civil <- refusal(ledgr_facts(ws45_sessions(), civil, edited))
  testthat::expect_identical(
    without_civil,
    "`facts` must be an untampered ledgr_facts object."
  )
  testthat::expect_identical(with_civil, without_civil)
  testthat::expect_identical(
    refusal(ledgr_facts(ws45_sessions(), civil, status)),
    "accepted"
  )

  edited_civil <- civil
  edited_civil$rows$member <- FALSE
  testthat::expect_error(
    ledgr_facts(ws45_sessions(), edited_civil),
    class = "ledgr_invalid_facts"
  )

  # Close review 45 F2: a sessions family edited after construction cannot
  # lend its shifted instants to a family resolved against it.
  shifted <- ws45_sessions()
  shifted$rows$session_open <- shifted$rows$session_open - 3600
  testthat::expect_error(
    ledgr_facts(shifted, civil),
    class = "ledgr_invalid_facts"
  )
})

testthat::test_that("[LTB-0355] mixed Date and POSIXct clocks are validated on resolved instants", {
  sessions <- ws45_sessions()
  # Entitlement 2021-01-05 is that session's close, 21:00 UTC, so an
  # effective instant of 15:00 UTC the same day precedes it: refused. The
  # UTC-midnight stand-in (00:00) used to accept it.
  late_entitlement <- ledgr_facts_equity_corporate_actions(ws45_action(
    entitlement_time = as.Date("2021-01-05"),
    effective_time = ws45_utc("2021-01-05 15:00:00")
  ))
  testthat::expect_error(
    ledgr_facts(sessions, late_entitlement),
    class = "ledgr_fact_invalid_clock_order"
  )
  # Effective 2021-01-05 is 21:00 UTC, after an entitlement at 15:00 UTC the
  # same day: accepted. The stand-in (00:00) used to refuse it.
  early_entitlement <- ledgr_facts_equity_corporate_actions(ws45_action(
    entitlement_time = ws45_utc("2021-01-05 15:00:00"),
    effective_time = as.Date("2021-01-05")
  ))
  row <- ws45_action_row(ledgr_facts(sessions, early_entitlement))
  testthat::expect_identical(
    as.numeric(row$entitlement_time),
    as.numeric(ws45_utc("2021-01-05 15:00:00"))
  )
  testthat::expect_identical(
    as.numeric(row$effective_time),
    as.numeric(ws45_utc("2021-01-05 21:00:00"))
  )

  # A Date end resolves to its session open, 14:30 UTC: after a 10:00 UTC
  # start (accepted; the stand-in refused it), before a 15:00 UTC start
  # (refused once resolved).
  interval <- function(from) {
    ledgr_facts_membership_intervals(
      data.frame(
        instrument_id = "AAA", effective_from = ws45_utc(from),
        effective_to = as.Date("2021-01-05"),
        knowledge_time = ws45_utc(from), member = TRUE, source = "ws45"
      ),
      universe_id = "u"
    )
  }
  accepted <- ledgr:::ledgr_facts_family(
    ledgr_facts(sessions, interval("2021-01-05 10:00:00")),
    "membership"
  )[[1L]]$rows
  testthat::expect_identical(
    as.numeric(accepted$effective_to),
    as.numeric(ws45_utc("2021-01-05 14:30:00"))
  )
  testthat::expect_error(
    ledgr_facts(sessions, interval("2021-01-05 15:00:00")),
    class = "ledgr_fact_invalid_interval"
  )
})

testthat::test_that("[LTB-0356] one known-when-effective rule follows decisions 11 and 27", {
  sessions <- ws45_sessions()
  resolve <- function(...) {
    ws45_action_row(ledgr_facts(
      sessions,
      ledgr_facts_equity_corporate_actions(ws45_action(...))
    ))
  }
  # A Date event without knowledge is known at its session's open (14:30
  # UTC) and stays effective at its close (21:00 UTC).
  dated <- resolve(
    entitlement_time = as.Date("2021-01-05"),
    effective_time = as.Date("2021-01-06")
  )
  testthat::expect_identical(
    as.numeric(dated$knowledge_time),
    as.numeric(ws45_utc("2021-01-06 14:30:00"))
  )
  testthat::expect_identical(
    as.numeric(dated$effective_time),
    as.numeric(ws45_utc("2021-01-06 21:00:00"))
  )
  testthat::expect_identical(
    ledgr:::ledgr_json_read_nested(dated$civil_time_json)$knowledge_time$civil_date,
    "2021-01-06"
  )
  entitled <- resolve(entitlement_time = as.Date("2021-01-05"))
  testthat::expect_identical(
    as.numeric(entitled$knowledge_time),
    as.numeric(ws45_utc("2021-01-05 14:30:00"))
  )
  # A supplied knowledge time is kept, whatever the event clock's type.
  supplied <- resolve(
    effective_time = as.Date("2021-01-06"),
    knowledge_time = ws45_utc("2021-01-07 12:00:00")
  )
  testthat::expect_identical(
    as.numeric(supplied$knowledge_time),
    as.numeric(ws45_utc("2021-01-07 12:00:00"))
  )
  testthat::expect_null(
    ledgr:::ledgr_json_read_nested(supplied$civil_time_json)$knowledge_time
  )
  # A POSIXct effective clock is the event: known at that instant, not at the
  # Date entitlement's session open.
  exact <- resolve(
    entitlement_time = as.Date("2021-01-05"),
    effective_time = ws45_utc("2021-01-06 21:00:00")
  )
  testthat::expect_identical(
    as.numeric(exact$knowledge_time),
    as.numeric(ws45_utc("2021-01-06 21:00:00"))
  )

  # Timing: known within the effective session, not at the previous close.
  pulses <- ws45_utc(paste(as.Date("2021-01-04") + 0:4, "21:00:00"))
  testthat::expect_identical(
    ledgr:::ledgr_corporate_action_knowledge_index(dated$knowledge_time, pulses),
    3L
  )
  testthat::expect_true(dated$knowledge_time > pulses[[2L]])

  # The sealed row keeps those instants, and a run posts the dividend on its
  # entitlement session without a late arrival.
  bars <- data.frame(
    instrument_id = "AAA", ts_utc = pulses,
    open = 10, high = 10, low = 10, close = 10, volume = 100
  )
  membership <- data.frame(
    effective_from = ws45_utc("2021-01-03"), knowledge_time = ws45_utc("2021-01-03"),
    source = "ws45"
  )
  membership$members <- I(list("AAA"))
  snapshot <- ledgr_snapshot_from_df(
    bars,
    data.frame(instrument_id = "AAA"),
    db_path = tempfile(fileext = ".duckdb"),
    facts = ledgr_facts(
      sessions,
      ledgr_facts_equity_corporate_actions(ws45_action(
        entitlement_time = as.Date("2021-01-06"),
        effective_time = as.Date("2021-01-06")
      )),
      ledgr_facts_membership_snapshots(membership, universe_id = "u")
    ),
    price_basis = "split_adjusted"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  stored <- ledgr:::ledgr_corporate_action_rows(
    ledgr:::get_connection(snapshot),
    snapshot$snapshot_id
  )
  testthat::expect_identical(
    as.numeric(stored$knowledge_time),
    as.numeric(ws45_utc("2021-01-06 14:30:00"))
  )
  run <- ledgr_run(
    ledgr_experiment(
      snapshot, function(ctx, params) ctx$hold(),
      universe = ledgr_universe_members("u"),
      opening = ledgr_opening(cash = 100, positions = c(AAA = 2), cost_basis = c(AAA = 10)),
      cost_model = ledgr_cost_zero()
    ),
    run_id = "ws45-dated-dividend"
  )
  on.exit(close(run), add = TRUE)
  ledger <- as.data.frame(ledgr_results(run, "ledger"))
  cash <- ledger[grepl("corporate_action_cash", ledger$meta_json, fixed = TRUE), , drop = FALSE]
  testthat::expect_identical(nrow(cash), 1L)
  testthat::expect_identical(
    as.numeric(cash$ts_utc),
    as.numeric(ws45_utc("2021-01-06 21:00:00"))
  )
  testthat::expect_true(grepl('"late_arrival":false', cash$meta_json, fixed = TRUE))
  testthat::expect_true(grepl('"cash_delta":2', cash$meta_json, fixed = TRUE))
})

# Two instruments over eight sessions (2021-01-04..08, 11..13; close 21:00
# UTC) holding AAA 2 and BBB 1. One BBB corporate action without an
# entitlement clock, effective at session `effective` and known at session
# `known`'s open (NA: known when effective).
ws45_unentitled_fixture <- function(subtype, effective, known = NA_integer_) {
  days <- as.Date("2021-01-04") + c(0:4, 7:9)
  utc <- function(d) ws45_utc(paste(d, "21:00:00"))
  k <- seq_along(days)
  bars <- rbind(
    data.frame(instrument_id = "AAA", ts_utc = utc(days), close = 10 + k),
    data.frame(instrument_id = "BBB", ts_utc = utc(days), close = 20 + k)
  )
  bars$open <- bars$high <- bars$low <- bars$close
  bars$volume <- 100
  calendar <- seq(min(days), max(days), by = "day")
  open <- calendar %in% days
  sessions <- data.frame(
    session_date = calendar, status = ifelse(open, "open", "closed"),
    session_open = ifelse(open, "14:30:00", NA), session_close = ifelse(open, "21:00:00", NA)
  )
  membership <- data.frame(
    effective_from = utc(days[[1]] - 1), knowledge_time = utc(days[[1]] - 1), source = "t"
  )
  membership$members <- I(list(c("AAA", "BBB")))
  action <- data.frame(
    fact_id = "ca-unentitled", subtype = subtype, parent_instrument_id = "BBB",
    effective_time = utc(days[[effective]]),
    knowledge_time = if (is.na(known)) ws45_utc(NA) else utc(days[[known]]) - 6.5 * 3600,
    complete = TRUE, provenance_tier = "snapshot_bound",
    recipient_identity_validated = FALSE, recipient_quantity_validated = FALSE,
    source = "ws45", stringsAsFactors = FALSE
  )
  snapshot <- ledgr_snapshot_from_df(
    bars, data.frame(instrument_id = c("AAA", "BBB")),
    db_path = tempfile(fileext = ".duckdb"),
    facts = ledgr_facts(
      ledgr_facts_equity_corporate_actions(action),
      ledgr_facts_sessions(sessions, venue_id = "V", knowledge = "assume_effective"),
      ledgr_facts_membership_snapshots(
        membership, universe_id = "u", complete = TRUE, knowledge = "assume_effective"
      )
    ),
    price_basis = "split_adjusted"
  )
  exp <- ledgr_experiment(
    snapshot, function(ctx, params) ctx$hold(), universe = ledgr_universe_members("u"),
    valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 2, BBB = 1), cost_basis = c(AAA = 10, BBB = 21)),
    corporate_action_policy = ledgr_corporate_actions_research()
  )
  folds <- ledgr:::ledgr_fold_list(
    list(
      ledgr_fold(days[[1L]], days[[2L]], days[[3L]], days[[5L]], fold_seq = 1L),
      ledgr_fold(days[[1L]], days[[5L]], days[[6L]], days[[8L]], fold_seq = 2L)
    ),
    constructor = list(type_id = "explicit")
  )
  list(snapshot = snapshot, exp = exp, days = days, folds = folds)
}

testthat::test_that("[LTB-0357] an effective-only disposition or quantity effect refuses (decision 28)", {
  refusal <- function(expr) {
    tryCatch(
      {
        force(expr)
        NULL
      },
      ledgr_corporate_action_entitlement_missing = function(e) e
    )
  }
  disposition_events <- function(fixture, run_id) {
    DBI::dbGetQuery(
      ledgr:::get_connection(fixture$snapshot),
      "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ? AND event_type = 'DISPOSITION'",
      params = list(run_id)
    )$n
  }
  # Effective at session 4 (first test window), known at session 7 (second).
  late <- ws45_unentitled_fixture("cash_acquisition", effective = 4L, known = 7L)
  on.exit(ledgr_snapshot_close(late$snapshot), add = TRUE)
  one <- refusal(ledgr:::ledgr_run_window(
    late$exp, params = list(),
    window = ledgr:::ledgr_experiment_window(late$exp, late$days[[3L]], late$days[[8L]]),
    run_id = "ws45-unentitled-single"
  ))
  testthat::expect_s3_class(one, "ledgr_invalid_corporate_action_event")
  testthat::expect_identical(one$subtype, "cash_acquisition")
  testthat::expect_identical(one$parent_instrument_id, "BBB")
  testthat::expect_identical(
    as.numeric(one$effective_time),
    as.numeric(ws45_utc("2021-01-07 21:00:00"))
  )
  testthat::expect_identical(
    as.numeric(one$knowledge_time),
    as.numeric(ws45_utc("2021-01-12 14:30:00"))
  )
  testthat::expect_identical(disposition_events(late, "ws45-unentitled-single"), 0)
  # The first test window alone reaches the effective clock but not the
  # knowledge clock, so it completes; the carried chain refuses in the
  # second window, as the single run does.
  first <- ledgr:::ledgr_run_window(
    late$exp, params = list(),
    window = ledgr:::ledgr_experiment_window(late$exp, late$days[[3L]], late$days[[5L]]),
    run_id = "ws45-unentitled-first"
  )
  on.exit(close(first), add = TRUE)
  chain <- refusal(suppressWarnings(ledgr_walk_forward(
    late$exp, ledgr_param_grid(list()), late$folds,
    selection_rule = ledgr_rule_argmax("annualized_return"), seed = 1L
  )))
  testthat::expect_s3_class(chain, "ledgr_corporate_action_entitlement_missing")
  testthat::expect_identical(chain$fact_id, one$fact_id)

  # Effective (and known) inside the second window: a spin-off refuses there.
  inside <- ws45_unentitled_fixture("spin_off", effective = 7L)
  on.exit(ledgr_snapshot_close(inside$snapshot), add = TRUE)
  inside_one <- refusal(ledgr_run(inside$exp, run_id = "ws45-unentitled-spin-off"))
  testthat::expect_identical(inside_one$subtype, "spin_off")
  testthat::expect_identical(
    as.numeric(inside_one$knowledge_time),
    as.numeric(ws45_utc("2021-01-12 21:00:00"))
  )
  inside_chain <- refusal(suppressWarnings(ledgr_walk_forward(
    inside$exp, ledgr_param_grid(list()), inside$folds,
    selection_rule = ledgr_rule_argmax("annualized_return"), seed = 1L
  )))
  testthat::expect_identical(inside_chain$fact_id, inside_one$fact_id)

  # Dense execution follows the same rule.
  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = ws45_utc("2021-01-04 21:00:00") + 86400 * 0:3,
    open = 10, high = 10, low = 10, close = 10, volume = 100
  )
  dense <- ledgr_snapshot_from_df(
    bars,
    facts = ledgr_facts(ledgr_facts_equity_corporate_actions(data.frame(
      subtype = "stock_acquisition", parent_instrument_id = "AAA",
      effective_time = bars$ts_utc[[3L]], complete = TRUE,
      provenance_tier = "snapshot_bound", source = "ws45",
      stringsAsFactors = FALSE
    ))),
    price_basis = "split_adjusted"
  )
  on.exit(ledgr_snapshot_close(dense), add = TRUE)
  dense_refusal <- refusal(ledgr_run(
    ledgr_experiment(
      dense, function(ctx, params) ctx$hold(),
      opening = ledgr_opening(cash = 100, positions = c(AAA = 1), cost_basis = c(AAA = 10)),
      cost_model = ledgr_cost_zero()
    ),
    run_id = "ws45-unentitled-dense"
  ))
  testthat::expect_identical(dense_refusal$subtype, "stock_acquisition")
})

testthat::test_that("[LTB-0358] assume_effective fills only missing knowledge times (decision 32)", {
  sessions <- ws45_sessions()
  # Effective 2021-01-05 resolves to 14:30 UTC. Row 1 supplies a POSIXct
  # knowledge time of 2021-01-06 18:00 UTC (later than the open); row 2
  # supplies none, so it is known at the effective session's open.
  supplied <- ws45_utc(c("2021-01-06 18:00:00", NA))
  resolved <- function(family, kind = "membership") {
    ledgr:::ledgr_facts_family(ledgr_facts(sessions, family), kind)[[1L]]
  }
  expected <- as.numeric(ws45_utc(c("2021-01-06 18:00:00", "2021-01-05 14:30:00")))
  intervals <- resolved(ledgr_facts_membership_intervals(
    data.frame(
      instrument_id = c("AAA", "BBB"), effective_from = as.Date("2021-01-05"),
      knowledge_time = supplied, member = TRUE, source = "ws45"
    ),
    universe_id = "u", knowledge = "assume_effective"
  ))
  rows <- intervals$rows[order(intervals$rows$instrument_id), ]
  testthat::expect_identical(as.numeric(rows$knowledge_time), expected)
  testthat::expect_null(ledgr:::ledgr_json_read_nested(rows$civil_time_json[[1L]])$knowledge_time)
  testthat::expect_identical(
    ledgr:::ledgr_json_read_nested(rows$civil_time_json[[2L]])$knowledge_time$civil_date,
    "2021-01-05"
  )
  status <- resolved(ledgr_facts_trading_status(
    data.frame(
      instrument_id = c("AAA", "BBB"), effective_from = as.Date("2021-01-05"),
      knowledge_time = supplied, status = "halted", source = "ws45"
    ),
    knowledge = "assume_effective"
  ), "trading_status")
  rows <- status$rows[order(status$rows$instrument_id), ]
  testthat::expect_identical(as.numeric(rows$knowledge_time), expected)
  lifetime <- resolved(ledgr_facts_lifetime(
    data.frame(
      instrument_id = c("AAA", "BBB"), effective_from = as.Date("2021-01-05"),
      knowledge_time = supplied, assertion = "known_active", source = "ws45"
    ),
    knowledge = "assume_effective"
  ), "lifetime")
  rows <- lifetime$rows[order(lifetime$rows$instrument_id), ]
  testthat::expect_identical(as.numeric(rows$knowledge_time), expected)
  snapshots <- resolved(ledgr_facts_membership_snapshots(
    data.frame(
      effective_from = as.Date("2021-01-05"), knowledge_time = supplied,
      instrument_id = c("AAA", "BBB"), set_id = c("s1", "s2"), source = "ws45"
    ),
    universe_id = "u", knowledge = "assume_effective"
  ))
  headers <- snapshots$headers[order(snapshots$headers$set_id), ]
  testthat::expect_identical(as.numeric(headers$knowledge_time), expected)
})

testthat::test_that("[LTB-0359] an effective-only cash dividend refuses in every mode (decisions 33, 35)", {
  refusal <- function(expr) {
    tryCatch(
      {
        force(expr)
        NULL
      },
      ledgr_corporate_action_entitlement_missing = function(e) e
    )
  }
  # Effective at session 4 (first test window), known at session 7 (second).
  late <- ws45_unentitled_fixture("ordinary_cash_dividend", effective = 4L, known = 7L)
  on.exit(ledgr_snapshot_close(late$snapshot), add = TRUE)
  one <- refusal(ledgr:::ledgr_run_window(
    late$exp, params = list(),
    window = ledgr:::ledgr_experiment_window(late$exp, late$days[[3L]], late$days[[8L]]),
    run_id = "ws45-unentitled-dividend"
  ))
  testthat::expect_identical(one$subtype, "ordinary_cash_dividend")
  testthat::expect_identical(
    as.numeric(one$knowledge_time),
    as.numeric(ws45_utc("2021-01-12 14:30:00"))
  )
  chain <- refusal(suppressWarnings(ledgr_walk_forward(
    late$exp, ledgr_param_grid(list()), late$folds,
    selection_rule = ledgr_rule_argmax("annualized_return"), seed = 1L
  )))
  testthat::expect_identical(chain$fact_id, one$fact_id)

  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = ws45_utc("2021-01-04 21:00:00") + 86400 * 0:3,
    open = 10, high = 10, low = 10, close = 10, volume = 100
  )
  dense <- ledgr_snapshot_from_df(
    bars,
    facts = ledgr_facts(ledgr_facts_equity_corporate_actions(data.frame(
      subtype = "ordinary_cash_dividend", parent_instrument_id = "AAA",
      effective_time = bars$ts_utc[[3L]], complete = TRUE,
      provenance_tier = "snapshot_bound", gross_cash_per_parent_unit = 1,
      gross_cash_validated = TRUE, source = "ws45", stringsAsFactors = FALSE
    ))),
    price_basis = "split_adjusted"
  )
  on.exit(ledgr_snapshot_close(dense), add = TRUE)
  dense_refusal <- refusal(ledgr_run(
    ledgr_experiment(
      dense, function(ctx, params) ctx$hold(),
      opening = ledgr_opening(cash = 100, positions = c(AAA = 1), cost_basis = c(AAA = 10)),
      cost_model = ledgr_cost_zero()
    ),
    run_id = "ws45-unentitled-dividend-dense"
  ))
  testthat::expect_identical(dense_refusal$subtype, "ordinary_cash_dividend")
  testthat::expect_identical(
    as.numeric(dense_refusal$effective_time),
    as.numeric(bars$ts_utc[[3L]])
  )
})

testthat::test_that("[LTB-0360] snapshot headers follow resolved knowledge times (decision 34)", {
  # Two sets effective 2021-01-05 10:00 UTC. set_a supplies the Date
  # 2021-01-05 (resolves to its 14:30 UTC open); set_z supplies none, so it
  # is known at 10:00. Input lists set_a first; resolved order is z, a. The
  # UTC-midnight stand-in for set_a's Date ordered a before z, and so does an
  # alphabetical order, so only the resolved knowledge time yields z, a.
  input <- data.frame(
    effective_from = ws45_utc("2021-01-05 10:00:00"),
    instrument_id = c("AAA", "CCC", "AAA", "BBB"),
    set_id = c("set_a", "set_a", "set_z", "set_z"),
    source = "ws45",
    stringsAsFactors = FALSE
  )
  input$knowledge_time <- as.Date(c("2021-01-05", "2021-01-05", NA, NA))
  family <- ledgr:::ledgr_facts_family(
    ledgr_facts(
      ws45_sessions(),
      ledgr_facts_membership_snapshots(input, "u", knowledge = "assume_effective")
    ),
    "membership"
  )[[1L]]
  testthat::expect_identical(family$headers$set_id, c("set_z", "set_a"))
  testthat::expect_identical(
    as.numeric(family$headers$knowledge_time),
    as.numeric(ws45_utc(c("2021-01-05 10:00:00", "2021-01-05 14:30:00")))
  )
})
