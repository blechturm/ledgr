# ledgr-test-file-profile: review

# Cut 16 Workstream 44 (LDG-3068): integrated causal-history proof.

# Eight venue sessions (Jan 4-8 and 11-13 2021, open 14:30 and close 21:00
# UTC). AAA closes at 10 + k on session k. DDD closes 41, 43, -, 50, 55, 61,
# 68, 76: it has no print on session 3, and sessions 5 and 6 are later
# learned to be a lifetime-inactive interval (a known_inactive fact effective
# from session 5's open to session 7's open) whose knowledge arrives at
# session 7's open. Its prints on sessions 5 and 6 stay in the snapshot.
ws44_late_fixture <- function(strategy = function(ctx, params) ctx$hold(),
                              policy = ledgr_history_policy()) {
  days <- as.Date("2021-01-04") + c(0:4, 7:9)
  utc <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  session_open <- function(d) as.POSIXct(paste(d, "14:30:00"), tz = "UTC")
  ddd <- c(41, 43, NA, 50, 55, 61, 68, 76)
  k <- seq_along(days)
  bars <- rbind(
    data.frame(instrument_id = "AAA", ts_utc = utc(days), close = 10 + k),
    data.frame(instrument_id = "DDD", ts_utc = utc(days[!is.na(ddd)]), close = ddd[!is.na(ddd)])
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
    effective_from = utc(days[[1L]] - 1), knowledge_time = utc(days[[1L]] - 1), source = "ws44"
  )
  membership$members <- I(list(c("AAA", "DDD")))
  facts <- ledgr_facts(
    ledgr_facts_sessions(sessions, venue_id = "V", knowledge = "assume_effective"),
    ledgr_facts_membership_snapshots(
      membership, universe_id = "u", complete = TRUE, knowledge = "assume_effective"
    ),
    ledgr_facts_lifetime(data.frame(
      instrument_id = "DDD",
      effective_from = session_open(days[[5L]]),
      effective_to = session_open(days[[7L]]),
      knowledge_time = session_open(days[[7L]]),
      assertion = "known_inactive",
      terminal_event = NA_character_
    ))
  )
  snapshot <- ledgr_snapshot_from_df(
    bars, data.frame(instrument_id = c("AAA", "DDD")),
    db_path = tempfile(fileext = ".duckdb"), facts = facts, price_basis = "split_adjusted"
  )
  exp <- ledgr_experiment(
    snapshot, strategy, universe = ledgr_universe_members("u"),
    features = ledgr_feature_map(sma = ledgr_ind_sma(2)),
    valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000), history_policy = policy
  )
  list(snapshot = snapshot, exp = exp, days = days, axis = utc(days))
}

ws44_iso <- function(x) format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

# Evidence columns of one instrument in a wide history result, as a data frame.
ws44_cells <- function(result, id) {
  evidence <- attr(result, "ledgr_history")$evidence
  out <- data.frame(value = result[[id]], stringsAsFactors = FALSE)
  for (field in names(evidence)) out[[field]] <- unname(evidence[[field]][, id])
  out
}

testthat::test_that("[LTB-0408] the Cut 16 evidence-owner map resolves to registered detecting blocks", {
  root <- ledgr_test_source_root()
  if (!ledgr_test_design_source_context(root)) return(invisible(NULL))
  packet <- yaml::read_yaml(file.path(
    root, "inst", "design", "ledgr_v0_2_2_spec_packet", "tickets.yml"
  ))
  cut <- Filter(function(x) identical(as.integer(x$id), 16L), packet$cuts)
  testthat::expect_length(cut, 1L)
  tickets <- packet$tickets
  ticket_ids <- vapply(tickets, function(t) t$id, character(1))
  ticket <- function(id) tickets[[match(id, ticket_ids)]]
  cited <- function(id) {
    text <- paste(unlist(ticket(id)$evidence), collapse = " ")
    unique(regmatches(text, gregexpr("LTB-[0-9]{4}", text))[[1L]])
  }
  claims <- yaml::read_yaml(file.path(root, "tests", "claims.yml"))$claims
  registered <- unique(unlist(lapply(claims, function(claim) claim$detecting_blocks)))
  test_text <- unlist(lapply(
    list.files(file.path(root, "tests", "testthat"), pattern = "^test-.*[.]R$", full.names = TRUE),
    readLines, warn = FALSE
  ))
  defined <- regmatches(test_text, regexpr("^testthat::test_that\\(\"\\[LTB-[0-9]{4}\\]", test_text))
  defined <- sub("^.*\\[(LTB-[0-9]{4})\\]$", "\\1", defined)

  # The expected map: v12 Section 10 item -> primary owner and its detecting
  # blocks, with contributing owners and the blocks they supply. Items whose
  # owner has not closed are pending: their owner must still be open.
  expected <- list(
    "1" = list(owner = "LDG-3057", blocks = "LTB-0288"),
    "2" = list(owner = "LDG-3062", blocks = "LTB-0297"),
    "3" = list(owner = "LDG-3059", blocks = "LTB-0291"),
    "4" = list(owner = "LDG-3057", blocks = "LTB-0284"),
    "5" = list(owner = "LDG-3060", blocks = "LTB-0292"),
    "6" = list(owner = "LDG-3060", blocks = "LTB-0292",
               contributing = list("LDG-3065" = "LTB-0307", "LDG-3066" = "LTB-0311")),
    "7" = list(owner = "LDG-3066", blocks = "LTB-0310"),
    "8" = list(owner = "LDG-3067", blocks = c("LTB-0315", "LTB-0316", "LTB-0317")),
    "9" = list(owner = "LDG-3064", blocks = c("LTB-0303", "LTB-0304"),
               contributing = list("LDG-3063" = "LTB-0300")),
    "10" = list(owner = "LDG-3057", blocks = "LTB-0285"),
    "11" = list(owner = "LDG-3064", blocks = "LTB-0305"),
    "12" = list(owner = "LDG-3057", blocks = "LTB-0286"),
    "13" = list(owner = "LDG-3061", blocks = "LTB-0294",
                contributing = list("LDG-3059" = "LTB-0293")),
    # LDG-3070's real-data proof relies on the default segment guard; the
    # registered detector it cites is the guard's refusal block.
    "14" = list(owner = "LDG-3070", blocks = "LTB-0291"),
    "15" = list(owner = "LDG-3068", blocks = c("LTB-0409", "LTB-0410", "LTB-0413")),
    "16" = list(owner = "LDG-3063", blocks = "LTB-0301",
                contributing = list("LDG-3058" = "LTB-0290")),
    # LDG-3069 reran LDG-3061's transport oracle on the H1 workload; the
    # registered detector it cites is that oracle.
    "17" = list(owner = "LDG-3069", blocks = "LTB-0295",
                contributing = list("LDG-3061" = "LTB-0295")),
    # The helper deletion is recorded in LDG-3067's evidence without a
    # registered block; LDG-3068 adds the structural integration detector.
    "18a" = list(owner = "LDG-3067", integration = list("LDG-3068" = "LTB-0412")),
    "18b" = list(owner = "LDG-3071", routed = TRUE, pending = TRUE)
  )

  text <- sub("[.]$", "", sub("^V12 Section 10: ", "", cut[[1L]]$evidence_owners))
  entries <- strsplit(text, "; ", fixed = TRUE)[[1L]]
  items <- sub("^([^ ]+) .*$", "\\1", entries)
  # Every item appears exactly once, so no item lacks or doubles a primary owner.
  testthat::expect_identical(items, names(expected))
  owners <- regmatches(entries, gregexpr("LDG-[0-9]{4}", entries))
  for (i in seq_along(entries)) {
    item <- items[[i]]
    spec <- expected[[item]]
    info <- paste("item", item)
    # The first ticket named is the one primary owner; the others contribute.
    testthat::expect_identical(owners[[i]][[1L]], spec$owner, info = info)
    testthat::expect_setequal(owners[[i]][-1L], as.character(names(spec$contributing)))
    testthat::expect_identical(grepl("routed to", entries[[i]], fixed = TRUE), isTRUE(spec$routed), info = info)
    testthat::expect_false(is.na(match(spec$owner, ticket_ids)), info = info)
    status <- ticket(spec$owner)$status
    if (isTRUE(spec$pending)) {
      # A pending owner is still open; when it closes, this map must name
      # its detecting blocks.
      testthat::expect_identical(status, "open", info = info)
    }
    supplied <- c(
      if (length(spec$blocks) > 0L) stats::setNames(list(spec$blocks), spec$owner),
      spec$contributing,
      spec$integration
    )
    if (!isTRUE(spec$pending) && is.null(spec$integration)) {
      testthat::expect_true(length(spec$blocks) > 0L, info = info)
    }
    for (supplier in names(supplied)) {
      for (block in supplied[[supplier]]) {
        where <- paste(info, supplier, block)
        testthat::expect_true(block %in% cited(supplier), info = where)
        testthat::expect_true(block %in% registered, info = where)
        testthat::expect_identical(sum(defined == block), 1L, info = where)
      }
    }
  }
  # A routed item names its destination; 18a's deletion is recorded by its owner.
  testthat::expect_true(grepl("routed to WS7", entries[[match("18b", items)]], fixed = TRUE))
  testthat::expect_true(any(grepl(
    paste0("ledgr_sweep_compute", "_feature_matrix is removed"), unlist(ticket("LDG-3067")$evidence),
    fixed = TRUE
  )))
})

testthat::test_that("[LTB-0409] a late-known lifetime fact changes later reads only, against a hand oracle", {
  read <- function(ctx) {
    list(
      close = ledgr_history_frame(ctx, bar = "close", instruments = "DDD"),
      sma = ledgr_history_frame(ctx, feature = "sma", instruments = "DDD"),
      bytes = serialize(list(
        ledgr_history_frame(ctx, bar = "close", instruments = "DDD"),
        ledgr_history_frame(ctx, feature = "sma", instruments = "DDD")
      ), NULL),
      scalar = ctx$feature("DDD", "sma"),
      vec = ctx$vec$feature("sma")
    )
  }
  capture <- function(policy) {
    seen <- new.env()
    spy <- function(ctx, params) {
      seen[[ctx$ts_utc]] <- NULL
      ctx$hold()
    }
    body(spy)[[2L]][[3L]] <- body(read)
    fixture <- ws44_late_fixture(strategy = spy, policy = policy)
    bt <- ledgr_run(fixture$exp, run_id = "late")
    close(bt)
    ledgr_snapshot_close(fixture$snapshot)
    list(at = function(session) seen[[ws44_iso(fixture$axis[[session]])]], axis = fixture$axis)
  }
  na <- NA_real_

  # Default policy (price carry 5). Hand oracle for DDD:
  # - before the fact is known (cutoff session 6) every session is expected;
  #   session 3 carries session 2's close (43, age 1, source session 2), and
  #   SMA(2) is NA (warm-up), 42, (43 + 43) / 2 = 43, (43 + 50) / 2 = 46.5,
  #   52.5 and 58;
  # - from session 7, sessions 5 and 6 are structural absences: their prints
  #   (55, 61) stay readable, flagged inactive and never valid, and SMA(2) at
  #   session 7 counts DDD's expected sessions, so its window is sessions 4
  #   and 7 across the interval (Cut 16 decision 15): (50 + 68) / 2 = 59. At
  #   session 8 it is (68 + 76) / 2 = 72;
  # - feature history is a vintage view (Cut 16 decision 29): sessions 1-6
  #   keep the values and the evidence they had at their own pulses, so after
  #   the fact is known sessions 5 and 6 still read 52.5 and 58, expected and
  #   valid, while bar history restates them as inactive prints.
  default <- capture(ledgr_history_policy())
  axis <- default$axis
  at6 <- default$at(6L)
  close6 <- ws44_cells(at6$close, "DDD")
  testthat::expect_identical(close6$value, c(41, 43, 43, 50, 55, 61))
  testthat::expect_identical(close6$expected, rep(TRUE, 6L))
  testthat::expect_identical(close6$observed, c(TRUE, TRUE, FALSE, TRUE, TRUE, TRUE))
  testthat::expect_identical(close6$input_carried, c(FALSE, FALSE, TRUE, FALSE, FALSE, FALSE))
  testthat::expect_identical(close6$carry_age_sessions, c(0L, 0L, 1L, 0L, 0L, 0L))
  testthat::expect_identical(close6$source_ts_utc[[3L]], as.numeric(axis[[2L]]))
  testthat::expect_identical(close6$barrier_reason, rep("", 6L))
  sma6 <- ws44_cells(at6$sma, "DDD")
  testthat::expect_identical(sma6$value, c(na, 42, 43, 46.5, 52.5, 58))
  testthat::expect_identical(sma6$calculation_valid, c(FALSE, TRUE, TRUE, TRUE, TRUE, TRUE))
  testthat::expect_identical(sma6$input_carried, c(FALSE, FALSE, TRUE, FALSE, FALSE, FALSE))
  testthat::expect_identical(sma6$missing_reason[[1L]], "not_ready")
  testthat::expect_identical(at6$scalar, 58)
  testthat::expect_identical(at6$vec, c(15.5, 58))

  for (session in 7:8) {
    after <- default$at(session)
    close <- ws44_cells(after$close, "DDD")
    shown <- c(41, 43, 43, 50, 55, 61, 68, 76)[seq_len(session)]
    testthat::expect_identical(close$value, shown, info = paste("cutoff", session))
    expected_mask <- c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, TRUE)[seq_len(session)]
    testthat::expect_identical(close$expected, expected_mask, info = paste("cutoff", session))
    testthat::expect_identical(close$calculation_valid, expected_mask, info = paste("cutoff", session))
    testthat::expect_identical(close$missing_reason[5:6], rep("inactive_interval_print", 2L))
    testthat::expect_identical(close$barrier_reason[5:6], rep("lifetime_inactive", 2L))
    testthat::expect_identical(close$input_carried[[3L]], TRUE)
    sma <- ws44_cells(after$sma, "DDD")
    # Sessions 1-6 keep their at-pulse values and evidence (decision 29):
    # every cell equals the session-6 read's cell.
    testthat::expect_identical(sma$value[1:6], c(na, 42, 43, 46.5, 52.5, 58), info = paste("cutoff", session))
    testthat::expect_identical(sma[1:6, ], ws44_cells(at6$sma, "DDD"), info = paste("cutoff", session))
    testthat::expect_identical(sma$expected, rep(TRUE, session), info = paste("cutoff", session))
    testthat::expect_identical(sma$calculation_valid[5:6], c(TRUE, TRUE), info = paste("cutoff", session))
    testthat::expect_identical(sma$missing_reason[5:6], c("", ""), info = paste("cutoff", session))
    testthat::expect_identical(sma$barrier_reason[5:6], c("", ""), info = paste("cutoff", session))
    testthat::expect_identical(sma$value[7L], 59, info = paste("cutoff", session))
    testthat::expect_true(sma$calculation_valid[[7L]])
  }
  testthat::expect_identical(default$at(7L)$scalar, 59)
  testthat::expect_identical(default$at(8L)$scalar, 72)
  testthat::expect_identical(default$at(8L)$vec, c(17.5, 72))
  testthat::expect_identical(ws44_cells(default$at(8L)$sma, "DDD")$value[[8L]], 72)

  # The session-6 objects were returned before the fact was known; later
  # reads changed neither their values nor a byte of them.
  testthat::expect_identical(serialize(list(at6$close, at6$sma), NULL), at6$bytes)
  testthat::expect_identical(ws44_cells(at6$close, "DDD")$expected, rep(TRUE, 6L))

  # Input carry disabled (price_carry = NULL): session 3 is raw missing, the
  # session-3 SMA lacks its input, session 4 starts a new segment and is not
  # ready, and the values from session 5 on equal the default run's.
  strict <- capture(ledgr_history_policy(price_carry = NULL))
  strict6 <- strict$at(6L)
  close6 <- ws44_cells(strict6$close, "DDD")
  testthat::expect_identical(close6$value, c(41, 43, na, 50, 55, 61))
  testthat::expect_identical(close6$input_carried, rep(FALSE, 6L))
  testthat::expect_identical(close6$missing_reason[[3L]], "raw_missing")
  sma6 <- ws44_cells(strict6$sma, "DDD")
  testthat::expect_identical(sma6$value, c(na, 42, na, na, 52.5, 58))
  testthat::expect_identical(sma6$missing_reason[3:4], c("required_input_missing", "not_ready"))
  testthat::expect_identical(sma6$input_carried, rep(FALSE, 6L))
  strict7 <- ws44_cells(strict$at(7L)$sma, "DDD")
  testthat::expect_identical(strict7$value, c(na, 42, na, na, 52.5, 58, 59))
  testthat::expect_identical(strict7$expected, rep(TRUE, 7L))
  testthat::expect_identical(strict7[1:6, ], ws44_cells(strict6$sma, "DDD"))
  testthat::expect_identical(strict$at(7L)$scalar, 59)
  testthat::expect_identical(ws44_cells(strict$at(7L)$close, "DDD")$value[[3L]], na)

  # Output carry alone (price_carry = NULL, output_carry = 2): only the
  # session whose own input is missing (3) is filled, from session 2's valid
  # SMA (42, age 1); session 4 is warm-up, not a fillable gap.
  output <- capture(ledgr_history_policy(price_carry = NULL, output_carry = 2L))
  sma6 <- ws44_cells(output$at(6L)$sma, "DDD")
  testthat::expect_identical(sma6$value, c(na, 42, 42, na, 52.5, 58))
  testthat::expect_identical(sma6$output_carried, c(FALSE, FALSE, TRUE, FALSE, FALSE, FALSE))
  testthat::expect_identical(sma6$input_carried, rep(FALSE, 6L))
  testthat::expect_identical(sma6$carry_age_sessions[[3L]], 1L)
  testthat::expect_identical(sma6$source_ts_utc[[3L]], as.numeric(axis[[2L]]))
  testthat::expect_identical(sma6$missing_reason[3:4], c("output_carried", "not_ready"))
  testthat::expect_identical(ws44_cells(output$at(6L)$close, "DDD")$value[[3L]], na)
  output7 <- ws44_cells(output$at(7L)$sma, "DDD")
  testthat::expect_identical(output7$value, c(na, 42, 42, na, 52.5, 58, 59))
  testthat::expect_identical(output7[1:6, ], ws44_cells(output$at(6L)$sma, "DDD"))
  testthat::expect_identical(output7$output_carried[[3L]], TRUE)
})

testthat::test_that("[LTB-0410] every entry point and read surface agrees with the hand oracle at one cutoff", {
  seen <- new.env()
  reader <- function(ctx) {
    sma <- ledgr_history_frame(ctx, feature = "sma", lookback = 1L, instruments = c("AAA", "DDD"))
    list(
      close = ledgr_history_frame(ctx, bar = "close", instruments = "DDD")$DDD,
      sma = c(AAA = sma$AAA, DDD = sma$DDD),
      matrix = ledgr_history_matrix(sma),
      scalar = c(ctx$feature("AAA", "sma"), ctx$feature("DDD", "sma")),
      vec = ctx$vec$feature("sma"),
      bar = ctx$close("DDD")
    )
  }
  spy <- function(ctx, params) {
    seen[[paste(params$tag, ctx$ts_utc)]] <- NULL
    ctx$hold()
  }
  body(spy)[[2L]][[3L]] <- body(reader)
  fixture <- ws44_late_fixture(strategy = spy)
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  exp <- fixture$exp
  axis <- fixture$axis
  days <- fixture$days

  close(ledgr_run(exp, params = list(tag = "run"), run_id = "agree-run"))
  ledgr_sweep(exp, ledgr_param_grid(list(tag = "sweep")))
  pre_grid <- ledgr_param_grid(list(tag = "precompute"))
  ledgr_sweep(exp, pre_grid, precomputed_features = ledgr_precompute_features(exp, pre_grid))
  folds <- ledgr:::ledgr_fold_list(
    list(
      ledgr_fold(days[[1L]], days[[2L]], days[[3L]], days[[5L]], fold_seq = 1L),
      ledgr_fold(days[[1L]], days[[5L]], days[[6L]], days[[8L]], fold_seq = 2L)
    ),
    constructor = list(type_id = "explicit")
  )
  wf <- ledgr_walk_forward(
    exp, ledgr_param_grid(list(tag = "wf")), folds,
    selection_rule = ledgr_rule_argmax("annualized_return"), seed = 1L
  )
  on.exit(lapply(wf$test_runs, close), add = TRUE)

  # The hand oracle (see LTB-0409): DDD's close history is carried at session
  # 3 and, from session 7, flags sessions 5 and 6 as inactive prints; SMA(2)
  # is 9.5 + k for AAA and 58, 59, 72 for DDD at sessions 6, 7 and 8.
  oracle <- list(
    "6" = list(close = c(41, 43, 43, 50, 55, 61), sma = c(AAA = 15.5, DDD = 58), bar = 61),
    "7" = list(close = c(41, 43, 43, 50, 55, 61, 68), sma = c(AAA = 16.5, DDD = 59), bar = 68),
    "8" = list(close = c(41, 43, 43, 50, 55, 61, 68, 76), sma = c(AAA = 17.5, DDD = 72), bar = 76)
  )
  check <- function(got, session, surface) {
    want <- oracle[[as.character(session)]]
    info <- paste(surface, session)
    testthat::expect_identical(got$close, want$close, info = info)
    testthat::expect_identical(got$sma, want$sma, info = info)
    testthat::expect_identical(
      got$matrix,
      matrix(unname(want$sma), nrow = 1L, dimnames = list(ws44_iso(axis[[session]]), c("AAA", "DDD"))),
      info = info
    )
    testthat::expect_identical(got$scalar, unname(want$sma), info = info)
    testthat::expect_identical(got$vec, unname(want$sma), info = info)
    testthat::expect_identical(got$bar, want$bar, info = info)
  }
  for (session in 6:8) {
    for (tag in c("run", "sweep", "precompute", "wf")) {
      check(seen[[paste(tag, ws44_iso(axis[[session]]))]], session, tag)
    }
    check(reader(ledgr_pulse_snapshot(exp, ts_utc = axis[[session]])), session, "inspection")
  }
})

testthat::test_that("[LTB-0411] a cash dividend is credited per split-adjusted share across a split", {
  # AAA trades at 100 until a 2:1 split effective at session 4's open and at
  # 50 after it. Split-adjusted bars back-adjust: 50 on every session. The
  # issuer declares $1.00 per as-traded (pre-split) share with entitlement
  # and payment at session 2's close, which is $0.50 per split-adjusted share.
  # The opening position is 10 split-adjusted shares (5 pre-split shares), so
  # the economic dividend is 10 x 0.50 = 5.
  days <- as.Date("2021-01-04") + c(0:4, 7L)
  utc <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  calendar <- seq(min(days), max(days), by = "day")
  open <- calendar %in% days
  sessions <- data.frame(
    session_date = calendar, status = ifelse(open, "open", "closed"),
    session_open = ifelse(open, "14:30:00", NA), session_close = ifelse(open, "21:00:00", NA)
  )
  bars <- data.frame(instrument_id = "AAA", ts_utc = utc(days), close = 50)
  bars$open <- bars$high <- bars$low <- bars$close
  bars$volume <- 100
  run_with <- function(amount, run_id) {
    facts <- ledgr_facts(
      ledgr_facts_sessions(sessions, venue_id = "V", knowledge = "assume_effective"),
      ledgr_facts_equity_corporate_actions(data.frame(
        fact_id = "dividend-units",
        subtype = "ordinary_cash_dividend",
        parent_instrument_id = "AAA",
        entitlement_time = utc(days[[2L]]),
        effective_time = utc(days[[2L]]),
        knowledge_time = utc(days[[1L]]) - 6.5 * 3600,
        complete = TRUE,
        provenance_tier = "snapshot_bound",
        gross_cash_per_parent_unit = amount,
        gross_cash_validated = TRUE,
        recipient_identity_validated = FALSE,
        recipient_quantity_validated = FALSE,
        source = "ws44",
        stringsAsFactors = FALSE
      ))
    )
    snapshot <- ledgr_snapshot_from_df(
      bars, data.frame(instrument_id = "AAA"),
      db_path = tempfile(fileext = ".duckdb"), facts = facts, price_basis = "split_adjusted"
    )
    exp <- ledgr_experiment(
      snapshot, function(ctx, params) ctx$hold(), universe = "AAA",
      valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
      opening = ledgr_opening(cash = 1000, positions = c(AAA = 10), cost_basis = c(AAA = 50))
    )
    bt <- ledgr_run(exp, run_id = run_id)
    ledger <- as.data.frame(ledgr_results(bt, "ledger"))
    cash <- ledger[ledger$event_type == "CASHFLOW" & grepl("corporate_action_cash", ledger$meta_json, fixed = TRUE), ]
    out <- list(
      equity = as.data.frame(ledgr_results(bt, "equity"))[, c("cash", "positions_value", "equity")],
      cash_ts = as.numeric(cash$ts_utc),
      meta = lapply(cash$meta_json, ledgr:::ledgr_json_read_nested),
      fills = nrow(ledgr_results(bt, "fills"))
    )
    close(bt)
    ledgr_snapshot_close(snapshot)
    out
  }

  # Supplied in split-adjusted units, the amount is credited exactly: 0.50 x
  # 10 = 5 at session 2, and nothing acts on the position at the split.
  adjusted <- run_with(0.5, "dividend-adjusted")
  testthat::expect_identical(adjusted$cash_ts, as.numeric(utc(days[[2L]])))
  testthat::expect_identical(adjusted$meta[[1L]]$entitled_quantity, 10)
  testthat::expect_identical(adjusted$meta[[1L]]$gross_cash_per_parent_unit, 0.5)
  testthat::expect_identical(adjusted$meta[[1L]]$cash_delta, 5)
  testthat::expect_identical(adjusted$equity$cash, c(1000, 1005, 1005, 1005, 1005, 1005))
  testthat::expect_identical(adjusted$equity$positions_value, rep(500, 6L))
  testthat::expect_identical(adjusted$fills, 0L)
  # Supplied in as-traded units ($1.00 per pre-split share), ledgr cannot
  # tell: it credits the amount per split-adjusted share held, 1.00 x 10 =
  # 10, twice the economic dividend. Converting the amount is the adapter's
  # job (contracts.md, Units, Price Basis And Universe).
  as_traded <- run_with(1, "dividend-as-traded")
  testthat::expect_identical(as_traded$meta[[1L]]$entitled_quantity, 10)
  testthat::expect_identical(as_traded$meta[[1L]]$cash_delta, 10)
  testthat::expect_identical(as_traded$equity$cash, c(1000, 1010, 1010, 1010, 1010, 1010))
})

testthat::test_that("[LTB-0412] the test-only sweep feature matrix stays deleted and its fixtures use production precompute", {
  root <- ledgr_test_source_root()
  if (!ledgr_test_checkout_context(root)) return(invisible(NULL))
  helper <- paste0("ledgr_sweep_compute", "_feature_matrix")
  files <- c(
    list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE),
    list.files(file.path(root, "tests", "testthat"), pattern = "[.]R$", full.names = TRUE)
  )
  named <- files[vapply(files, function(path) {
    any(grepl(helper, readLines(path, warn = FALSE), fixed = TRUE))
  }, logical(1))]
  testthat::expect_identical(named, character())
  testthat::expect_false(exists(helper, envir = asNamespace("ledgr"), inherits = FALSE))
  sweep_tests <- readLines(file.path(root, "tests", "testthat", "test-sweep.R"), warn = FALSE)
  builder <- grep("^ledgr_sweep_test_precomputed <- function", sweep_tests)
  testthat::expect_length(builder, 1L)
  body_end <- builder + grep("^}", sweep_tests[builder:length(sweep_tests)])[[1L]] - 1L
  testthat::expect_true(any(grepl("ledgr_precompute_features(", sweep_tests[builder:body_end], fixed = TRUE)))
  testthat::expect_identical(
    length(grep("runtime_projection <- ledgr_sweep_test_precomputed(", sweep_tests, fixed = TRUE)),
    3L
  )
})

# Two-instrument fixture over `days` with DDD closes `ddd` (NA = no print)
# and the given lifetime facts for DDD.
ws44_lifetime_fixture <- function(days, ddd, lifetime, strategy, policy = ledgr_history_policy()) {
  utc <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  k <- seq_along(days)
  bars <- rbind(
    data.frame(instrument_id = "AAA", ts_utc = utc(days), close = 10 + k),
    data.frame(instrument_id = "DDD", ts_utc = utc(days[!is.na(ddd)]), close = ddd[!is.na(ddd)])
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
    effective_from = utc(days[[1L]] - 1), knowledge_time = utc(days[[1L]] - 1), source = "ws44"
  )
  membership$members <- I(list(c("AAA", "DDD")))
  facts <- ledgr_facts(
    ledgr_facts_sessions(sessions, venue_id = "V", knowledge = "assume_effective"),
    ledgr_facts_membership_snapshots(
      membership, universe_id = "u", complete = TRUE, knowledge = "assume_effective"
    ),
    ledgr_facts_lifetime(lifetime)
  )
  snapshot <- ledgr_snapshot_from_df(
    bars, data.frame(instrument_id = c("AAA", "DDD")),
    db_path = tempfile(fileext = ".duckdb"), facts = facts, price_basis = "split_adjusted"
  )
  exp <- ledgr_experiment(
    snapshot, strategy, universe = ledgr_universe_members("u"),
    features = ledgr_feature_map(sma = ledgr_ind_sma(2)),
    valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000), history_policy = policy
  )
  list(snapshot = snapshot, exp = exp, axis = utc(days))
}

testthat::test_that("[LTB-0413] vintage feature evidence follows each pulse's knowledge at a pulse-instant fact, a relisting and the bounded reach", {
  # Close review 44a F5. Twelve sessions. DDD closes 40, -, 44, 46, 50, 54,
  # 60, 66, 70, 80, 90, 100. Lifetime facts: an inactive interval at
  # sessions 3-4 learned at session 5's open; a delisting from session 7's
  # open to session 10's open learned exactly at session 8's close (the
  # pulse instant); a relisting from session 10 learned at session 11's open.
  days <- as.Date("2021-01-04") + c(0:4, 7:11, 14:15)
  session_open <- function(d) as.POSIXct(paste(d, "14:30:00"), tz = "UTC")
  session_close <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  lifetime <- data.frame(
    instrument_id = "DDD",
    effective_from = c(session_open(days[[3L]]), session_open(days[[7L]]), session_open(days[[10L]])),
    effective_to = c(session_open(days[[5L]]), session_open(days[[10L]]), as.POSIXct(NA, tz = "UTC")),
    knowledge_time = c(session_open(days[[5L]]), session_close(days[[8L]]), session_open(days[[11L]])),
    assertion = c("known_inactive", "known_inactive", "known_active"),
    terminal_event = c(NA, "delisting", NA),
    stringsAsFactors = FALSE
  )
  seen <- new.env()
  spy <- function(ctx, params) {
    seen[[ctx$ts_utc]] <- list(
      sma = ledgr_history_frame(ctx, feature = "sma", instruments = "DDD"),
      close = ledgr_history_frame(ctx, bar = "close", instruments = "DDD")
    )
    ctx$hold()
  }
  fixture <- ws44_lifetime_fixture(days, c(40, NA, 44, 46, 50, 54, 60, 66, 70, 80, 90, 100), lifetime, spy)
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  close(ledgr_run(fixture$exp, run_id = "vintage-terminal"))
  at <- function(session) seen[[ws44_iso(fixture$axis[[session]])]]
  na <- NA_real_

  # Feature cells as computed at their own pulses (Cut 16 decision 29):
  # session 2 averages a close carried from session 1 (40); sessions 3-4 were
  # computed before their interval was known ((40 + 44) / 2, (44 + 46) / 2);
  # session 5 knows it and spans it to session 2 ((40 + 50) / 2); session 7
  # was computed before the delisting was known ((54 + 60) / 2); from
  # session 8, where the knowledge instant equals the pulse instant, the
  # delisting is known, so sessions 8-9 are not expected and the terminal
  # barrier is sticky; the relisting restarts the window, so session 10 is
  # warm-up and sessions 11-12 read (80 + 90) / 2 and (90 + 100) / 2.
  sma <- ws44_cells(at(12L)$sma, "DDD")
  testthat::expect_identical(sma$value, c(na, 40, 42, 45, 45, 52, 57, na, na, na, 85, 95))
  testthat::expect_identical(sma$expected, c(rep(TRUE, 7L), FALSE, FALSE, TRUE, TRUE, TRUE))
  testthat::expect_identical(
    sma$missing_reason,
    c("not_ready", rep("", 6L), "not_expected", "not_expected", "not_ready", "", "")
  )
  testthat::expect_identical(sma$barrier_reason, c(rep("", 7L), rep("terminal", 5L)))
  testthat::expect_identical(sma$input_carried, c(FALSE, TRUE, rep(FALSE, 10L)))
  for (session in seq_len(12L)) {
    testthat::expect_identical(
      sma[session, ], ws44_cells(at(session)$sma, "DDD")[session, ],
      info = paste("own pulse", session)
    )
  }
  # Bar history is restated with the cutoff's knowledge: the prints inside
  # both intervals are inactive-interval prints.
  close12 <- ws44_cells(at(12L)$close, "DDD")
  testthat::expect_identical(close12$value, c(40, 40, 44, 46, 50, 54, 60, 66, 70, 80, 90, 100))
  testthat::expect_identical(
    close12$expected,
    c(TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, TRUE)
  )

  # Bounded reach under each cell's own mask: no prints at sessions 5-6, an
  # interval there learned at session 7, no input carry. At cutoff 7 a
  # three-session read holds sessions 5 and 6 as computed at their pulses
  # (expected, required input missing) and session 7's SMA (50 + 68) / 2 =
  # 59, whose window is sessions 4 and 7: it used session 4, before the
  # returned window.
  short <- data.frame(
    instrument_id = "DDD",
    effective_from = session_open(days[[5L]]),
    effective_to = session_open(days[[7L]]),
    knowledge_time = session_open(days[[7L]]),
    assertion = "known_inactive",
    terminal_event = NA_character_,
    stringsAsFactors = FALSE
  )
  reach <- ws44_lifetime_fixture(
    days[1:8], c(41, 43, 45, 50, NA, NA, 68, 76), short,
    function(ctx, params) ctx$hold(), policy = ledgr_history_policy(price_carry = NULL)
  )
  on.exit(ledgr_snapshot_close(reach$snapshot), add = TRUE)
  window <- ledgr_history_frame(
    ledgr_pulse_snapshot(reach$exp, ts_utc = reach$axis[[7L]]),
    feature = "sma", lookback = 3L, instruments = "DDD"
  )
  cells <- ws44_cells(window, "DDD")
  testthat::expect_identical(cells$value, c(na, na, 59))
  testthat::expect_identical(cells$expected, c(TRUE, TRUE, TRUE))
  testthat::expect_identical(cells$missing_reason, c("required_input_missing", "required_input_missing", ""))
  testthat::expect_true(ledgr_history_info(window)$used_before_window)
})
