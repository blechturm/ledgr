terminal_outcome_day <- function(day, time = "16:00:00") {
  as.POSIXct(paste(as.Date("2020-01-01") + day - 1L, time), tz = "UTC")
}

# One session per element of each close vector; NA means no bar that session.
terminal_outcome_snapshot <- function(closes, lifetime = NULL, corporate = NULL) {
  days <- length(closes[[1L]])
  dates <- as.Date("2020-01-01") + seq_len(days) - 1L
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00",
      knowledge_time = as.POSIXct(dates, tz = "UTC") - 1,
      stringsAsFactors = FALSE
    ),
    venue_id = "XNYS"
  )
  families <- list(sessions)
  if (!is.null(lifetime)) families <- c(families, list(lifetime))
  if (!is.null(corporate)) families <- c(families, list(corporate))
  bars <- do.call(rbind, lapply(names(closes), function(id) {
    close <- closes[[id]]
    keep <- which(!is.na(close))
    if (length(keep) == 0L) return(NULL)
    data.frame(
      ts_utc = terminal_outcome_day(keep),
      instrument_id = id,
      open = close[keep],
      high = close[keep] + 1,
      low = close[keep] - 1,
      close = close[keep],
      volume = 1000,
      stringsAsFactors = FALSE
    )
  }))
  ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = names(closes)),
    facts = do.call(ledgr_facts, families),
    price_basis = "split_adjusted"
  )
}

terminal_outcome_lifetime <- function(id, day, label = "bankruptcy") {
  at <- terminal_outcome_day(day)
  ledgr_facts_lifetime(data.frame(
    instrument_id = id,
    effective_from = at,
    knowledge_time = at - 1,
    assertion = "known_inactive",
    terminal_event = label,
    stringsAsFactors = FALSE
  ))
}

terminal_outcome_acquisition <- function(id, day, fact_id = "acquisition-1") {
  at <- terminal_outcome_day(day)
  ledgr_facts_equity_corporate_actions(data.frame(
    fact_id = fact_id,
    subtype = "cash_acquisition",
    parent_instrument_id = id,
    entitlement_time = at,
    effective_time = at,
    knowledge_time = terminal_outcome_day(1L),
    complete = TRUE,
    provenance_tier = "snapshot_bound",
    gross_cash_validated = FALSE,
    recipient_identity_validated = FALSE,
    recipient_quantity_validated = FALSE,
    source = "terminal_outcome_fixture",
    stringsAsFactors = FALSE
  ))
}

terminal_outcome_experiment <- function(snapshot,
                                        strategy = function(ctx, params) ctx$hold(),
                                        policy = ledgr_corporate_actions_research(),
                                        valuation = ledgr_valuation_stale(1),
                                        positions = c(AAA = 2)) {
  ledgr_experiment(
    snapshot,
    strategy,
    opening = ledgr_opening(
      cash = 1000,
      positions = positions,
      cost_basis = stats::setNames(rep(100, length(positions)), names(positions))
    ),
    valuation_policy = valuation,
    corporate_action_policy = policy,
    cost_model = ledgr_cost_zero()
  )
}

terminal_outcome_tables <- function(bt) {
  opened <- ledgr_test_open_duckdb(bt$db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  query <- function(sql) DBI::dbGetQuery(opened$con, sql, params = list(bt$run_id))
  list(
    run = query("SELECT status, config_json FROM runs WHERE run_id = ?"),
    completion = query("SELECT * FROM run_completion WHERE run_id = ?"),
    diagnostics = query("SELECT * FROM run_diagnostics WHERE run_id = ? ORDER BY diagnostic_seq"),
    events = query("SELECT * FROM ledger_events WHERE run_id = ? ORDER BY event_seq"),
    equity = query("SELECT * FROM equity_curve WHERE run_id = ? ORDER BY ts_utc")
  )
}

terminal_outcome_dispositions <- function(tables) {
  events <- tables$events[tables$events$event_type == "DISPOSITION", , drop = FALSE]
  if (nrow(events) == 0L) return(list())
  lapply(seq_len(nrow(events)), function(i) {
    c(
      list(
        ts_utc = as.POSIXct(events$ts_utc[[i]], tz = "UTC"),
        instrument_id = events$instrument_id[[i]],
        price = events$price[[i]],
        qty = events$qty[[i]]
      ),
      ledgr:::ledgr_json_read_nested(events$meta_json[[i]])
    )
  })
}

terminal_outcome_trace <- function(tables, id) {
  d <- tables$diagnostics
  d[d$stage == "decision" & d$instrument_id == id, , drop = FALSE]
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0162] modeled terminal choices dispose once before the strategy decision", {
  label_fact <- terminal_outcome_lifetime("AAA", 2L, "bankruptcy")
  current <- terminal_outcome_snapshot(list(AAA = c(100, 102, 103)), lifetime = label_fact)
  on.exit(ledgr_snapshot_close(current), add = TRUE)
  expired <- terminal_outcome_snapshot(list(AAA = c(100, NA, 103)), lifetime = label_fact)
  on.exit(ledgr_snapshot_close(expired), add = TRUE)
  held_id <- function(choice) {
    unname(ledgr:::ledgr_corporate_action_policy_ids()$held_terminal_position[[choice]])
  }
  refuse_horizon <- ledgr_valuation_stale(0, exhausted = "refuse")
  cases <- list(
    research = list(policy = ledgr_corporate_actions_research(), price = 102,
                    choice = "last_permissible", basis = "default"),
    last_mark = list(policy = ledgr_corporate_actions(held_terminal_position = "last_mark"),
                     price = 102, choice = "last_mark", basis = "default"),
    haircut = list(policy = ledgr_corporate_actions(held_terminal_position = "haircut", haircut = 0.25),
                   price = 76.5, choice = "haircut", basis = "default"),
    write_off = list(policy = ledgr_corporate_actions(held_terminal_position = "write_off"),
                     price = 0, choice = "write_off", basis = "default"),
    refuse = list(policy = ledgr_corporate_actions(held_terminal_position = "refuse"),
                  stop = "terminal_settlement_unsupported"),
    label_override = list(
      policy = ledgr_corporate_actions(held_terminal_position = c(bankruptcy = "write_off", default = "last_permissible")),
      price = 0, choice = "write_off", basis = "label", matched = "bankruptcy"
    ),
    unmatched_default = list(
      policy = ledgr_corporate_actions(held_terminal_position = c(merger = "write_off", default = "haircut"), haircut = 0.5),
      price = 51, choice = "haircut", basis = "default"
    ),
    expired_last_mark = list(snapshot = expired, valuation = refuse_horizon,
                             policy = ledgr_corporate_actions(held_terminal_position = "last_mark"),
                             price = 100, choice = "last_mark", basis = "default",
                             mark_source = "expired_close", mark_age = 1L),
    expired_last_permissible = list(snapshot = expired, valuation = refuse_horizon,
                                    policy = ledgr_corporate_actions_research(),
                                    stop = "terminal_mark_unavailable")
  )
  for (name in names(cases)) {
    case <- cases[[name]]
    seen <- new.env(parent = emptyenv())
    strategy <- function(ctx, params) {
      seen[[ctx$ts_utc]] <- ctx$vec$position[match("AAA", ctx$universe)]
      ctx$hold()
    }
    bt <- ledgr_run(
      terminal_outcome_experiment(
        case$snapshot %||% current,
        strategy = strategy,
        policy = case$policy,
        valuation = case$valuation %||% ledgr_valuation_stale(1)
      ),
      run_id = paste0("terminal-", name)
    )
    tables <- terminal_outcome_tables(bt)
    close(bt)
    dispositions <- terminal_outcome_dispositions(tables)
    stored <- ledgr:::ledgr_json_read_config(tables$run$config_json[[1L]])$corporate_actions
    testthat::expect_identical(
      stored,
      ledgr:::ledgr_json_read_config(canonical_json(
        ledgr:::ledgr_corporate_action_policy_identity(case$policy)
      )),
      info = name
    )
    testthat::expect_false(any(tables$events$event_type == "FILL"), info = name)
    if (!is.null(case$stop)) {
      testthat::expect_identical(tables$run$status, "INCOMPLETE", info = name)
      testthat::expect_identical(tables$completion$stop_reason, case$stop, info = name)
      testthat::expect_length(dispositions, 0L)
      testthat::expect_identical(nrow(tables$equity), 1L, info = name)
      testthat::expect_identical(sort(ls(seen)), "2020-01-01T16:00:00Z", info = name)
      next
    }
    testthat::expect_identical(tables$run$status, "DONE", info = name)
    testthat::expect_length(dispositions, 1L)
    d <- dispositions[[1L]]
    testthat::expect_identical(d$ts_utc, terminal_outcome_day(2L), info = name)
    testthat::expect_identical(d$source, "lifetime_terminal_disposition", info = name)
    testthat::expect_identical(d$terminal_event, "bankruptcy", info = name)
    testthat::expect_identical(d$matched_label, case$matched %||% "default", info = name)
    testthat::expect_identical(d$disposition_choice, case$choice, info = name)
    testthat::expect_identical(d$disposition_basis, case$basis, info = name)
    testthat::expect_identical(d$disposition_policy_id, held_id(case$choice), info = name)
    testthat::expect_equal(d$price, case$price, info = name)
    testthat::expect_equal(d$qty, 2, info = name)
    testthat::expect_equal(d$quantity, 2, info = name)
    testthat::expect_equal(d$cash_delta, 2 * case$price, info = name)
    testthat::expect_equal(d$position_delta, -2, info = name)
    testthat::expect_equal(d$realized_model_pnl, 2 * (case$price - 100), info = name)
    if (!is.null(case$mark_source)) {
      testthat::expect_identical(d$mark_source, case$mark_source, info = name)
      testthat::expect_identical(d$mark_age, case$mark_age, info = name)
    }
    # The disposition precedes the terminal pulse's strategy call.
    testthat::expect_identical(seen[["2020-01-02T16:00:00Z"]], 0, info = name)
    testthat::expect_equal(
      tables$equity$equity,
      c(1200, rep(1000 + 2 * case$price, 2L)),
      info = name
    )
  }
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0163] supported settlement evidence pre-empts a modeled terminal", {
  acquisition <- terminal_outcome_acquisition("AAA", 2L)
  snapshot <- terminal_outcome_snapshot(
    list(AAA = c(100, 90, 91)),
    lifetime = terminal_outcome_lifetime("AAA", 2L, "acquired"),
    corporate = acquisition
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  # A declared loss default never applies to settlement evidence: the
  # scheduled acquisition settles at its evidenced mark, and the lifetime
  # label's write-off is never reached.
  policy <- ledgr_corporate_actions(
    held_terminal_position = c(acquired = "write_off", default = "write_off")
  )
  bt <- ledgr_run(terminal_outcome_experiment(snapshot, policy = policy), run_id = "evidence-first")
  tables <- terminal_outcome_tables(bt)
  close(bt)
  dispositions <- terminal_outcome_dispositions(tables)
  testthat::expect_identical(tables$run$status, "DONE")
  testthat::expect_length(dispositions, 1L)
  d <- dispositions[[1L]]
  testthat::expect_identical(d$source, "corporate_action_disposition")
  testthat::expect_identical(d$source_fact_id, acquisition$rows$fact_id[[1L]])
  testthat::expect_identical(d$disposition_choice, "last_permissible")
  testthat::expect_identical(d$disposition_basis, "evidence")
  testthat::expect_equal(d$price, 90)
  testthat::expect_equal(d$qty, d$quantity)
  testthat::expect_equal(tail(tables$equity$equity, 1L), 1180)

  # A refused scheduled settlement is a precedence barrier: the run stops
  # typed and the lifetime label cannot dispose the holding instead.
  refusing <- ledgr_corporate_actions(
    held_terminal_position = c(acquired = "write_off", default = "refuse")
  )
  bt <- ledgr_run(terminal_outcome_experiment(snapshot, policy = refusing), run_id = "evidence-refused")
  tables <- terminal_outcome_tables(bt)
  close(bt)
  testthat::expect_identical(tables$run$status, "INCOMPLETE")
  testthat::expect_identical(tables$completion$stop_reason, "terminal_settlement_unsupported")
  testthat::expect_length(terminal_outcome_dispositions(tables), 0L)
  testthat::expect_identical(nrow(tables$equity), 1L)
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0164] unsupported and unpriceable terminals stop typed", {
  unlabeled <- terminal_outcome_snapshot(
    list(AAA = c(100, 102, 103)),
    lifetime = terminal_outcome_lifetime("AAA", 2L, NA_character_)
  )
  on.exit(ledgr_snapshot_close(unlabeled), add = TRUE)
  bt <- ledgr_run(terminal_outcome_experiment(unlabeled), run_id = "terminal-unlabeled")
  tables <- terminal_outcome_tables(bt)
  close(bt)
  stop_row <- tables$diagnostics[tables$diagnostics$outcome == "stopped", , drop = FALSE]
  testthat::expect_identical(tables$run$status, "INCOMPLETE")
  testthat::expect_identical(tables$completion$stop_reason, "terminal_settlement_unsupported")
  testthat::expect_identical(stop_row$reasons, "terminal_settlement_unsupported|terminal_label_missing")
  testthat::expect_identical(tables$events$event_type, "CASHFLOW")
  testthat::expect_identical(nrow(tables$equity), 1L)

  # A choice that needs a qualifying mark stops typed when none exists; it
  # neither aborts nor writes the holding off.
  no_mark <- terminal_outcome_snapshot(
    list(AAA = c(100, NA, 103)),
    lifetime = terminal_outcome_lifetime("AAA", 2L, "bankruptcy")
  )
  on.exit(ledgr_snapshot_close(no_mark), add = TRUE)
  bt <- ledgr_run(
    terminal_outcome_experiment(no_mark, valuation = ledgr_valuation_stale(0, exhausted = "refuse")),
    run_id = "terminal-no-mark"
  )
  tables <- terminal_outcome_tables(bt)
  close(bt)
  stop_row <- tables$diagnostics[tables$diagnostics$outcome == "stopped", , drop = FALSE]
  testthat::expect_identical(tables$run$status, "INCOMPLETE")
  testthat::expect_identical(tables$completion$stop_reason, "terminal_mark_unavailable")
  testthat::expect_identical(stop_row$reasons, "terminal_mark_unavailable|last_permissible")
  testthat::expect_identical(tables$events$event_type, "CASHFLOW")
  testthat::expect_identical(nrow(tables$equity), 1L)

  # A holding that never had any mark stops typed instead of failing.
  never <- terminal_outcome_snapshot(list(AAA = rep(NA_real_, 3L), CLK = rep(10, 3L)))
  on.exit(ledgr_snapshot_close(never), add = TRUE)
  bt <- ledgr_run(terminal_outcome_experiment(never), run_id = "never-priced")
  tables <- terminal_outcome_tables(bt)
  close(bt)
  testthat::expect_identical(tables$run$status, "INCOMPLETE")
  testthat::expect_identical(tables$completion$stop_reason, "valuation_horizon_exhausted")
  testthat::expect_identical(tables$events$event_type, "CASHFLOW")
  testthat::expect_true(all(is.na(tables$equity$equity)))
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0165] an exhausted mark freezes without inventing transactions", {
  snapshot <- terminal_outcome_snapshot(list(
    AAA = c(100, NA, NA, NA, 80, 81),
    CLK = rep(10, 6L)
  ))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    target <- ctx$hold()
    if (ctx$ts_utc == "2020-01-03T16:00:00Z" ||
        (isTRUE(params$persistent) && ctx$ts_utc > "2020-01-03T16:00:00Z")) {
      target[["AAA"]] <- 0
    }
    target
  }
  exp <- terminal_outcome_experiment(snapshot, strategy = strategy)

  persistent <- ledgr_run(exp, params = list(persistent = TRUE), run_id = "freeze-persistent")
  p <- terminal_outcome_tables(persistent)
  close(persistent)
  one_shot <- ledgr_run(exp, params = list(persistent = FALSE), run_id = "freeze-one-shot")
  o <- terminal_outcome_tables(one_shot)
  close(one_shot)

  for (tables in list(p, o)) {
    trace <- terminal_outcome_trace(tables, "AAA")
    testthat::expect_identical(
      trace$mark_source[1:5],
      c("current_close", "stale_close", "frozen_close", "frozen_close", "current_close")
    )
    testthat::expect_identical(trace$mark_age[1:5], c(0L, 1L, 2L, 3L, 0L))
    testthat::expect_equal(trace$price[1:5], c(100, 100, 100, 100, 80))
    testthat::expect_identical(trace$reason_code[3:4], rep("valuation_frozen", 2L))
    testthat::expect_identical(tables$run$status, "DONE")
    testthat::expect_false(any(tables$events$event_type %in% c("DISPOSITION")))
    testthat::expect_identical(sum(tables$events$event_type == "CASHFLOW"), 1L)
    valuation <- tables$diagnostics[tables$diagnostics$stage == "valuation", , drop = FALSE]
    testthat::expect_identical(valuation$outcome, c("frozen", "exited"))
    testthat::expect_identical(
      as.POSIXct(valuation$ts_utc, tz = "UTC"),
      terminal_outcome_day(c(3L, 5L))
    )
    testthat::expect_equal(tables$equity$cash[1:4], rep(1000, 4L))
    testthat::expect_equal(tables$equity$equity[1:4], rep(1200, 4L))
    # The day-3 zero target found no bar at the day-4 opening.
    no_fill <- tables$diagnostics[tables$diagnostics$outcome == "no_fill", , drop = FALSE]
    testthat::expect_identical(no_fill$reason_code[[1L]], "execution_bar_missing")
  }
  # A persistent zero fills at the resumption bar and realizes the move.
  fills <- p$events[p$events$event_type == "FILL", , drop = FALSE]
  testthat::expect_identical(nrow(fills), 1L)
  testthat::expect_identical(as.POSIXct(fills$ts_utc, tz = "UTC"), terminal_outcome_day(5L, "09:30:00"))
  testthat::expect_equal(fills$price, 80)
  testthat::expect_equal(p$equity$equity[5:6], c(1160, 1160))
  # A one-shot zero is never queued.
  testthat::expect_false(any(o$events$event_type == "FILL"))
  testthat::expect_equal(o$equity$equity[5:6], c(1160, 1162))

  refused <- ledgr_run(
    terminal_outcome_experiment(
      snapshot,
      strategy = strategy,
      valuation = ledgr_valuation_stale(1, exhausted = "refuse")
    ),
    params = list(persistent = TRUE),
    run_id = "freeze-refused"
  )
  r <- terminal_outcome_tables(refused)
  close(refused)
  testthat::expect_identical(r$run$status, "INCOMPLETE")
  testthat::expect_identical(r$completion$stop_reason, "valuation_horizon_exhausted")
  testthat::expect_false(any(r$diagnostics$outcome == "frozen"))
  testthat::expect_identical(nrow(r$equity), 2L)
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0166] frozen holdings move independently and resume deterministically", {
  snapshot <- terminal_outcome_snapshot(list(
    AAA = c(100, NA, NA, NA, 90, 91, 92),
    BBB = c(50, 51, NA, NA, NA, NA, 40),
    CLK = rep(10, 7L)
  ))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  prior <- getOption("ledgr.interrupt")
  on.exit(options(ledgr.interrupt = prior), add = TRUE)
  strategy <- function(ctx, params) {
    if (isTRUE(params$interrupt) && identical(ctx$ts_utc, "2020-01-04T16:00:00Z")) {
      options(ledgr.interrupt = TRUE)
    }
    ctx$hold()
  }
  exp <- terminal_outcome_experiment(
    snapshot,
    strategy = strategy,
    positions = c(AAA = 2, BBB = 4)
  )
  options(ledgr.interrupt = FALSE)
  straight <- ledgr_run(exp, params = list(interrupt = FALSE), run_id = "freeze-straight")
  s <- terminal_outcome_tables(straight)
  close(straight)

  first <- ledgr_run(exp, params = list(interrupt = TRUE), run_id = "freeze-resumed")
  close(first)
  testthat::expect_identical(terminal_outcome_tables(first)$run$status, "RUNNING")
  options(ledgr.interrupt = FALSE)
  resumed <- ledgr_run(exp, params = list(interrupt = TRUE), run_id = "freeze-resumed")
  r <- terminal_outcome_tables(resumed)
  close(resumed)

  valuation <- s$diagnostics[s$diagnostics$stage == "valuation", , drop = FALSE]
  testthat::expect_identical(valuation$instrument_id, c("AAA", "BBB", "AAA", "BBB"))
  testthat::expect_identical(valuation$outcome, c("frozen", "frozen", "exited", "exited"))
  testthat::expect_identical(
    as.POSIXct(valuation$ts_utc, tz = "UTC"),
    terminal_outcome_day(c(3L, 4L, 5L, 7L))
  )
  testthat::expect_equal(s$equity$equity, c(1400, 1404, 1404, 1404, 1384, 1386, 1344))

  strip <- function(x) {
    x$run_id <- NULL
    x$event_id <- NULL
    rownames(x) <- NULL
    x
  }
  for (part in c("events", "equity", "diagnostics")) {
    testthat::expect_identical(strip(r[[part]]), strip(s[[part]]), info = part)
  }
  testthat::expect_identical(r$run$status, "DONE")
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0167] frozen holdings are preserved and reserved by strategy helpers", {
  snapshot <- terminal_outcome_snapshot(list(
    AAA = c(100, NA, NA, NA),
    BBB = c(50, 50, 50, 50)
  ))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  seen <- new.env(parent = emptyenv())
  strategy <- function(ctx, params) {
    if (identical(ctx$ts_utc, "2020-01-03T16:00:00Z")) {
      idx <- match("AAA", ctx$universe)
      seen$vec <- lapply(
        ctx$vec[c("held", "position", "risk_mark", "mark_source", "mark_age",
                  "target_restricted", "target_restriction_reason", "admissible", "priced")],
        function(v) v[[idx]]
      )
      seen$tradable <- ctx$tradable()
      seen$equity <- ctx$equity
      seen$target <- ledgr_target_rebalance(ledgr_weights(c(BBB = 1)), ctx)
      return(seen$target)
    }
    ctx$hold()
  }
  bt <- ledgr_run(terminal_outcome_experiment(snapshot, strategy = strategy), run_id = "frozen-context")
  tables <- terminal_outcome_tables(bt)
  close(bt)
  testthat::expect_identical(seen$vec$held, TRUE)
  testthat::expect_equal(seen$vec$position, 2)
  testthat::expect_equal(seen$vec$risk_mark, 100)
  testthat::expect_identical(seen$vec$mark_source, "frozen_close")
  testthat::expect_identical(seen$vec$mark_age, 2L)
  testthat::expect_identical(seen$vec$target_restricted, TRUE)
  testthat::expect_identical(seen$vec$target_restriction_reason, "valuation_frozen")
  testthat::expect_identical(seen$vec$admissible, FALSE)
  testthat::expect_identical(seen$vec$priced, TRUE)
  testthat::expect_identical(seen$tradable, "BBB")
  # Reported equity includes the frozen value; the helper reserves it once.
  testthat::expect_equal(seen$equity, 1200)
  testthat::expect_equal(unclass(seen$target)[["AAA"]], 2)
  testthat::expect_equal(unclass(seen$target)[["BBB"]], (1200 - 200) / 50)
  testthat::expect_identical(tables$run$status, "DONE")

  increase <- function(ctx, params) {
    target <- ctx$hold()
    if (identical(ctx$ts_utc, "2020-01-03T16:00:00Z")) target[["AAA"]] <- 3
    target
  }
  testthat::expect_error(
    ledgr_run(terminal_outcome_experiment(snapshot, strategy = increase), run_id = "frozen-increase"),
    class = "ledgr_restricted_target"
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0168] a terminal reached while frozen resolves its declared fallback", {
  label_fact <- terminal_outcome_lifetime("AAA", 4L, "bankruptcy")
  frozen <- terminal_outcome_snapshot(list(AAA = c(100, NA, NA, NA, NA), CLK = rep(10, 5L)), lifetime = label_fact)
  on.exit(ledgr_snapshot_close(frozen), add = TRUE)
  acquisition <- terminal_outcome_acquisition("AAA", 4L)
  evidence <- terminal_outcome_snapshot(
    list(AAA = c(100, NA, NA, NA, NA), CLK = rep(10, 5L)),
    lifetime = label_fact,
    corporate = acquisition
  )
  on.exit(ledgr_snapshot_close(evidence), add = TRUE)
  ids <- ledgr:::ledgr_corporate_action_policy_ids()
  cases <- list(
    research = list(policy = ledgr_corporate_actions_research(), price = 0, choice = "write_off",
                    basis = "frozen_fallback", id = ids$frozen_terminal_position[["write_off"]]),
    frozen_last_mark = list(policy = ledgr_corporate_actions(frozen_terminal_position = "last_mark"),
                            price = 100, choice = "last_mark", basis = "frozen_fallback",
                            id = ids$frozen_terminal_position[["last_mark"]]),
    haircut_falls_back = list(
      policy = ledgr_corporate_actions(held_terminal_position = "haircut", haircut = 0.5),
      price = 0, choice = "write_off", basis = "frozen_fallback",
      id = ids$frozen_terminal_position[["write_off"]]
    ),
    label_last_mark = list(
      policy = ledgr_corporate_actions(held_terminal_position = c(bankruptcy = "last_mark", default = "last_permissible")),
      price = 100, choice = "last_mark", basis = "label", id = ids$held_terminal_position[["last_mark"]]
    ),
    label_write_off = list(
      policy = ledgr_corporate_actions(
        held_terminal_position = c(bankruptcy = "write_off", default = "last_permissible"),
        frozen_terminal_position = "last_mark"
      ),
      price = 0, choice = "write_off", basis = "label", id = ids$held_terminal_position[["write_off"]]
    ),
    frozen_refuse = list(policy = ledgr_corporate_actions(frozen_terminal_position = "refuse"),
                         reasons = "terminal_settlement_unsupported|frozen_terminal_refuse"),
    evidence = list(snapshot = evidence, policy = ledgr_corporate_actions_research(), price = 100,
                    choice = "last_permissible", basis = "evidence",
                    id = ids$held_terminal_position[["last_permissible"]],
                    source = "corporate_action_disposition", fact = acquisition$rows$fact_id[[1L]]),
    evidence_loss_default = list(
      snapshot = evidence,
      policy = ledgr_corporate_actions(held_terminal_position = c(bankruptcy = "write_off", default = "haircut"), haircut = 0.5),
      price = 100, choice = "last_permissible", basis = "evidence",
      id = ids$held_terminal_position[["last_permissible"]],
      source = "corporate_action_disposition", fact = acquisition$rows$fact_id[[1L]]
    ),
    evidence_refused = list(
      snapshot = evidence,
      policy = ledgr_corporate_actions(held_terminal_position = c(bankruptcy = "write_off", default = "refuse")),
      reasons = "terminal_settlement_unsupported"
    )
  )
  for (name in names(cases)) {
    case <- cases[[name]]
    bt <- ledgr_run(
      terminal_outcome_experiment(case$snapshot %||% frozen, policy = case$policy),
      run_id = paste0("frozen-terminal-", name)
    )
    tables <- terminal_outcome_tables(bt)
    close(bt)
    dispositions <- terminal_outcome_dispositions(tables)
    valuation <- tables$diagnostics[tables$diagnostics$stage == "valuation", , drop = FALSE]
    testthat::expect_identical(valuation$outcome[[1L]], "frozen", info = name)
    testthat::expect_identical(
      as.POSIXct(valuation$ts_utc[[1L]], tz = "UTC"),
      terminal_outcome_day(3L),
      info = name
    )
    if (!is.null(case$reasons)) {
      stop_row <- tables$diagnostics[tables$diagnostics$outcome == "stopped", , drop = FALSE]
      testthat::expect_identical(tables$run$status, "INCOMPLETE", info = name)
      testthat::expect_identical(stop_row$reasons, case$reasons, info = name)
      testthat::expect_length(dispositions, 0L)
      testthat::expect_identical(nrow(tables$equity), 3L, info = name)
      next
    }
    testthat::expect_identical(tables$run$status, "DONE", info = name)
    testthat::expect_length(dispositions, 1L)
    d <- dispositions[[1L]]
    testthat::expect_identical(d$ts_utc, terminal_outcome_day(4L), info = name)
    testthat::expect_identical(d$source, case$source %||% "lifetime_terminal_disposition", info = name)
    if (!is.null(case$fact)) testthat::expect_identical(d$source_fact_id, case$fact, info = name)
    testthat::expect_identical(d$disposition_choice, case$choice, info = name)
    testthat::expect_identical(d$disposition_basis, case$basis, info = name)
    testthat::expect_identical(d$disposition_policy_id, unname(case$id), info = name)
    testthat::expect_equal(d$price, case$price, info = name)
    testthat::expect_equal(d$realized_model_pnl, 2 * (case$price - 100), info = name)
    testthat::expect_equal(d$affected_marked_exposure, 200, info = name)
    testthat::expect_equal(
      tables$equity$equity,
      c(rep(1200, 3L), rep(1000 + 2 * case$price, 2L)),
      info = name
    )
  }
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0169] memory, durable reopen and resume agree across freeze and terminal", {
  snapshot <- terminal_outcome_snapshot(
    list(
      AAA = c(100, NA, NA, NA, 90, 91),
      BBB = c(50, NA, NA, NA, NA, NA),
      CLK = rep(10, 6L)
    ),
    lifetime = terminal_outcome_lifetime("BBB", 5L, "bankruptcy")
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  prior <- getOption("ledgr.interrupt")
  on.exit(options(ledgr.interrupt = prior), add = TRUE)
  strategy <- function(ctx, params) {
    if (isTRUE(params$interrupt) && identical(ctx$ts_utc, "2020-01-03T16:00:00Z")) {
      options(ledgr.interrupt = TRUE)
    }
    target <- ctx$hold()
    if (ctx$ts_utc >= "2020-01-03T16:00:00Z" && "AAA" %in% names(target)) target[["AAA"]] <- 0
    target
  }
  exp <- terminal_outcome_experiment(
    snapshot,
    strategy = strategy,
    positions = c(AAA = 2, BBB = 4)
  )
  options(ledgr.interrupt = FALSE)
  straight <- ledgr_run(exp, params = list(interrupt = FALSE), run_id = "parity-straight")
  s <- terminal_outcome_tables(straight)
  straight_equity <- ledgr_results(straight, "equity")
  straight_fills <- ledgr_run_fills(straight)
  close(straight)

  first <- ledgr_run(exp, params = list(interrupt = TRUE), run_id = "parity-resumed")
  close(first)
  options(ledgr.interrupt = FALSE)
  resumed <- ledgr_run(exp, params = list(interrupt = TRUE), run_id = "parity-resumed")
  r <- terminal_outcome_tables(resumed)
  close(resumed)

  # The scenario exercises freeze entry, a frozen terminal write-off, and a
  # persistent exit at the resumption bar.
  dispositions <- terminal_outcome_dispositions(s)
  testthat::expect_length(dispositions, 1L)
  testthat::expect_identical(dispositions[[1L]]$instrument_id, "BBB")
  testthat::expect_identical(dispositions[[1L]]$disposition_basis, "frozen_fallback")
  testthat::expect_equal(straight_fills$price, 90)
  testthat::expect_equal(tail(s$equity$equity, 1L), 1000 + 2 * 90)

  strip <- function(x) {
    x$run_id <- NULL
    x$event_id <- NULL
    rownames(x) <- NULL
    x
  }
  for (part in c("events", "equity", "diagnostics", "completion")) {
    testthat::expect_identical(strip(r[[part]]), strip(s[[part]]), info = part)
  }

  reopened <- ledgr_run_open(snapshot, "parity-straight")
  on.exit(close(reopened), add = TRUE)
  testthat::expect_identical(ledgr_results(reopened, "equity"), straight_equity)
  testthat::expect_identical(ledgr_run_fills(reopened), straight_fills)
  opened <- ledgr_test_open_duckdb(snapshot$db_path)
  end_state <- ledgr:::ledgr_state_asof(
    opened$con, "parity-straight", 1000, terminal_outcome_day(6L),
    instrument_ids = c("AAA", "BBB", "CLK")
  )
  ledgr_test_close_duckdb(opened$con, opened$drv)
  testthat::expect_equal(unname(end_state$positions[c("AAA", "BBB")]), c(0, 0))
  testthat::expect_equal(end_state$cash, 1180)

  # The in-memory sweep fold reaches the same final equity and return path.
  sweep <- ledgr_sweep(
    exp,
    ledgr_param_grid(one = list(interrupt = FALSE)),
    retain = ledgr_sweep_retention("completed")
  )
  testthat::expect_identical(as.character(sweep$status), "DONE")
  testthat::expect_equal(sweep$final_equity, tail(s$equity$equity, 1L))
  memory_returns <- ledgr_sweep_returns(sweep)
  testthat::expect_identical(
    as.numeric(as.POSIXct(memory_returns$ts_utc, tz = "UTC")),
    as.numeric(as.POSIXct(s$equity$ts_utc, tz = "UTC"))
  )
  testthat::expect_equal(memory_returns$equity, s$equity$equity)
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0170] exact labels, the default entry and haircut arithmetic price one pulse", {
  lifetime <- ledgr_facts_lifetime(data.frame(
    instrument_id = c("AAA", "BBB"),
    effective_from = terminal_outcome_day(2L),
    knowledge_time = terminal_outcome_day(2L) - 1,
    assertion = "known_inactive",
    terminal_event = c("bankruptcy", "merger"),
    stringsAsFactors = FALSE
  ))
  snapshot <- terminal_outcome_snapshot(
    list(AAA = c(100, 102, 103), BBB = c(50, 60, 61)),
    lifetime = lifetime
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  policy <- ledgr_corporate_actions(
    held_terminal_position = c(bankruptcy = "write_off", default = "haircut"),
    haircut = 0.25
  )
  bt <- ledgr_run(
    terminal_outcome_experiment(snapshot, policy = policy, positions = c(AAA = 2, BBB = 4)),
    run_id = "terminal-canary"
  )
  tables <- terminal_outcome_tables(bt)
  close(bt)
  d <- terminal_outcome_dispositions(tables)
  testthat::expect_identical(tables$run$status, "DONE")
  testthat::expect_identical(vapply(d, `[[`, character(1), "instrument_id"), c("AAA", "BBB"))
  testthat::expect_identical(vapply(d, `[[`, character(1), "matched_label"), c("bankruptcy", "default"))
  testthat::expect_identical(vapply(d, `[[`, character(1), "disposition_choice"), c("write_off", "haircut"))
  testthat::expect_equal(vapply(d, `[[`, numeric(1), "price"), c(0, 0.75 * 60))
  testthat::expect_equal(vapply(d, `[[`, numeric(1), "qty"), c(2, 4))
  testthat::expect_equal(vapply(d, `[[`, numeric(1), "quantity"), c(2, 4))
  testthat::expect_equal(vapply(d, `[[`, numeric(1), "realized_model_pnl"), c(-200, 4 * (45 - 100)))
  testthat::expect_equal(d[[2L]]$haircut_fraction, 0.25)
  testthat::expect_null(d[[1L]]$haircut_fraction)
  testthat::expect_equal(tables$equity$equity, c(1400, 1180, 1180))
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0171] a failure before the terminal append commits nothing", {
  # An unrelated failure before the append fails the run rather than being
  # absorbed, and commits no disposition, lot or cash change.
  labeled <- terminal_outcome_snapshot(
    list(AAA = c(100, 102, 103)),
    lifetime = terminal_outcome_lifetime("AAA", 2L, "bankruptcy")
  )
  on.exit(ledgr_snapshot_close(labeled), add = TRUE)
  testthat::local_mocked_bindings(
    ledgr_terminal_mark_meta = function(...) stop("injected before append"),
    .package = "ledgr"
  )
  testthat::expect_error(
    ledgr_run(terminal_outcome_experiment(labeled), run_id = "terminal-injected"),
    "injected before append"
  )
  failed <- terminal_outcome_tables(list(db_path = labeled$db_path, run_id = "terminal-injected"))
  testthat::expect_identical(failed$run$status, "FAILED")
  testthat::expect_false(any(failed$events$event_type == "DISPOSITION"))
  opened <- ledgr_test_open_duckdb(labeled$db_path)
  state <- ledgr:::ledgr_state_asof(
    opened$con, "terminal-injected", 1000, terminal_outcome_day(3L),
    instrument_ids = "AAA"
  )
  ledgr_test_close_duckdb(opened$con, opened$drv)
  testthat::expect_equal(unname(state$positions[["AAA"]]), 2)
  testthat::expect_equal(state$cash, 1000)
  testthat::expect_identical(ledgr:::ledgr_lot_count(state$lot_state, "AAA"), 1L)
})
