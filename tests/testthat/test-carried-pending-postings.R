# Cut 17 LDG-3091 (decision 23): a carried opening validates many pending
# corporate-action posting instants at once, and the summary counts the
# unsupported-quantity report_only choice.

# AAA and BBB close at 10 + k and 20 + k on eight venue sessions (Jan 4-8
# and 11-13 2021, close 21:00 UTC); the book opens with AAA 2 and BBB 1 and
# the strategy holds. Two cash dividends of 0.5 per share, one on each
# instrument, are entitled and effective at session 4 and become known at
# session 7's open, so at the session-5 fold boundary both are bound and
# pending with a recorded posting instant (session 4's close).
ldg3091_two_pending_fixture <- function() {
  days <- as.Date("2021-01-04") + c(0:4, 7:9)
  utc <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
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
  actions <- data.frame(
    fact_id = c("div-aaa", "div-bbb"), subtype = "ordinary_cash_dividend",
    parent_instrument_id = c("AAA", "BBB"),
    entitlement_time = utc(days[[4]]), effective_time = utc(days[[4]]),
    knowledge_time = utc(days[[7]]) - 6.5 * 3600,
    complete = TRUE, provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = 0.5, gross_cash_validated = TRUE,
    source = "ldg3091", stringsAsFactors = FALSE
  )
  facts <- ledgr_facts(
    ledgr_facts_equity_corporate_actions(actions),
    ledgr_facts_sessions(sessions, venue_id = "V", knowledge = "assume_effective"),
    ledgr_facts_membership_snapshots(
      membership, universe_id = "u", complete = TRUE, knowledge = "assume_effective"
    )
  )
  snapshot <- ledgr_snapshot_from_df(
    bars, data.frame(instrument_id = c("AAA", "BBB")),
    db_path = tempfile(fileext = ".duckdb"), facts = facts, price_basis = "split_adjusted"
  )
  exp <- ledgr_experiment(
    snapshot, function(ctx, params) ctx$hold(), universe = ledgr_universe_members("u"),
    valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 2, BBB = 1), cost_basis = c(AAA = 10, BBB = 21)),
    corporate_action_policy = ledgr_corporate_actions_research()
  )
  list(snapshot = snapshot, exp = exp, days = days)
}

testthat::test_that("[LTB-0471] a walk-forward carries two pending dividend postings across a fold boundary", {
  fixture <- ldg3091_two_pending_fixture()
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  days <- fixture$days
  folds <- ledgr:::ledgr_fold_list(
    list(
      ledgr_fold(days[[1L]], days[[2L]], days[[3L]], days[[5L]], fold_seq = 1L),
      ledgr_fold(days[[1L]], days[[5L]], days[[6L]], days[[8L]], fold_seq = 2L)
    ),
    constructor = list(type_id = "explicit")
  )
  chain <- ledgr_walk_forward(
    fixture$exp, ledgr_param_grid(list(x = 1)), folds,
    selection_rule = ledgr_rule_argmax("annualized_return"), seed = 1L
  )
  on.exit(lapply(chain$test_runs, close), add = TRUE)
  testthat::expect_identical(chain$status, "DONE")
  testthat::expect_identical(length(chain$test_runs), 2L)

  # The second window opens with both rows pending, each bound at its
  # parent's held quantity (AAA 2, BBB 1) with session 4's close as its
  # recorded posting instant. Sealed fact ids are hashed, so rows are matched
  # to their parents through the snapshot.
  pending <- chain$test_runs[[2L]]$config$opening$carried$pending
  sealed <- DBI::dbGetQuery(
    ledgr:::get_connection(fixture$snapshot),
    "SELECT fact_id, parent_instrument_id FROM snapshot_equity_corporate_actions"
  )
  parent <- sealed$parent_instrument_id[match(as.character(unlist(pending$fact_id)), sealed$fact_id)]
  testthat::expect_identical(sort(parent), c("AAA", "BBB"))
  testthat::expect_identical(
    as.numeric(unlist(pending$quantity))[order(parent)],
    c(2, 1)
  )
  testthat::expect_identical(
    as.character(unlist(pending$posting_ts_utc)),
    rep("2021-01-07T21:00:00Z", 2L)
  )

  # Both post at session 7's close as late arrivals: 2 x 0.5 on AAA and
  # 1 x 0.5 on BBB, so final equity is 1000 + 2 x 18 + 28 + 1.5. One run
  # over the same pulses posts the same rows.
  dividends <- function(bt) {
    ledger <- as.data.frame(ledgr_results(bt, "ledger"))
    ledger <- ledger[ledger$event_type == "CASHFLOW" &
      grepl("corporate_action_cash", ledger$meta_json, fixed = TRUE), ]
    ledger <- ledger[order(ledger$instrument_id), ]
    data.frame(
      instrument_id = ledger$instrument_id, ts_utc = as.numeric(ledger$ts_utc),
      meta = ledger$meta_json, stringsAsFactors = FALSE
    )
  }
  cash <- dividends(chain$test_runs[[2L]])
  testthat::expect_identical(nrow(dividends(chain$test_runs[[1L]])), 0L)
  testthat::expect_identical(cash$instrument_id, c("AAA", "BBB"))
  testthat::expect_identical(
    cash$ts_utc,
    rep(as.numeric(as.POSIXct("2021-01-12 21:00:00", tz = "UTC")), 2L)
  )
  testthat::expect_true(grepl('"entitled_quantity":2', cash$meta[[1L]], fixed = TRUE))
  testthat::expect_true(grepl('"entitled_quantity":1', cash$meta[[2L]], fixed = TRUE))
  single <- ledgr:::ledgr_run_window(
    fixture$exp, params = list(x = 1),
    window = ledgr:::ledgr_experiment_window(fixture$exp, days[[3L]], days[[8L]]),
    run_id = "ldg3091-single"
  )
  on.exit(close(single), add = TRUE)
  testthat::expect_identical(cash, dividends(single))
  equity <- as.data.frame(ledgr_results(chain$test_runs[[2L]], "equity"))
  testthat::expect_identical(equity$equity[[nrow(equity)]], 1065.5)
  testthat::expect_identical(
    equity$equity,
    utils::tail(as.data.frame(ledgr_results(single, "equity"))$equity, nrow(equity))
  )
})

testthat::test_that("[LTB-0472] a carried opening validates many posting instants and refuses an invalid one among them", {
  normalize <- ledgr:::ledgr_opening_carried_normalize
  carried <- function(posting) {
    list(pending = list(
      fact_id = paste0("f", seq_along(posting)),
      quantity = as.list(seq_along(posting)),
      posting_ts_utc = as.list(posting)
    ))
  }
  # Three instants, one empty (settled by its effective or knowledge clock)
  # and one NA, which reads as empty.
  ok <- normalize(carried(c(
    "2021-01-07T21:00:00Z", "", "2021-01-08T21:00:00Z", NA, "2021-01-11T21:00:00Z"
  )))
  testthat::expect_identical(
    ok$pending$posting_ts_utc,
    c("2021-01-07T21:00:00Z", "", "2021-01-08T21:00:00Z", "", "2021-01-11T21:00:00Z")
  )
  testthat::expect_identical(ok$pending$quantity, as.numeric(1:5))

  # One invalid instant among valid ones refuses with the opening class:
  # wrong forms (strptime alone would accept the trailing text and the
  # unpadded fields), a date that does not exist and a time out of range.
  invalid <- c(
    "2021-01-08 21:00:00", "2021-01-08T21:00:00Z+01", "2021-1-8T21:00:00Z",
    "2021-02-30T21:00:00Z", "2021-01-08T25:00:00Z", "x"
  )
  for (bad in invalid) {
    testthat::expect_error(
      normalize(carried(c("2021-01-07T21:00:00Z", bad, "2021-01-11T21:00:00Z"))),
      class = "ledgr_invalid_opening",
      info = bad
    )
    testthat::expect_error(
      normalize(carried(c("2021-01-07T21:00:00Z", bad, "2021-01-11T21:00:00Z"))),
      class = "ledgr_invalid_config",
      info = bad
    )
  }
  # A single invalid instant refuses with the same class.
  testthat::expect_error(normalize(carried("2021-01-08")), class = "ledgr_invalid_opening")
})
