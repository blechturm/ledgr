# Point-in-time universe audit: shared semantic fixture.
#
# Builds the audit's spine dataset (charter: inst/design/audits/
# v0_2_2_pit_universe_audit/charter.md) through ledgr's public fact
# constructors only. It follows the frozen yardstick's section B dataset
# (yardstick.md): 40 sessions s1..s40 on a sealed New York calendar with two
# ad hoc closed weekdays between s20 and s21 and an early close on s30, and
# fifteen instruments in the yardstick's roles, adapted to what ledgr's
# inputs can express. What cannot be expressed is recorded in
# `pit_audit_fixture()$not_expressible`, never faked; coverage.csv maps
# every yardstick scenario.
#
# This file builds inputs only. Strategies, paths and observations belong to
# Stage 1, which runs on the commit frozen after Cut 11 Workstream 22.
#
#   source("dev/audit/pit_universe/fixture.R")
#   fx <- pit_audit_fixture()                       # announcement knowledge
#   fx <- pit_audit_fixture(knowledge = "effective_only")
#   snapshot <- pit_audit_snapshot(fx)

pit_audit_tz <- "America/New_York"

# Calendar: weekdays from 2021-03-01; the two weekdays after s20 are closed
# ad hoc; s30 closes early at 13:00. Sessions are numbered s1..s40.
pit_audit_calendar <- function() {
  days <- seq(as.Date("2021-03-01"), by = "day", length.out = 80L)
  weekday <- as.integer(format(days, "%u")) <= 5L
  candidates <- days[weekday]
  closed_adhoc <- candidates[21:22]
  open_days <- setdiff(candidates, closed_adhoc)[1:40]
  open_days <- as.Date(open_days, origin = "1970-01-01")
  last <- max(open_days)
  calendar <- days[days <= last]
  open <- calendar %in% open_days
  early <- calendar == open_days[[30]]
  list(
    calendar = calendar,
    open_days = open_days,
    closed_adhoc = as.Date(closed_adhoc, origin = "1970-01-01"),
    sessions = data.frame(
      session_date = calendar,
      status = ifelse(open, "open", "closed"),
      session_open = ifelse(open, "09:30:00", NA),
      session_close = ifelse(open, ifelse(early, "13:00:00", "16:00:00"), NA),
      stringsAsFactors = FALSE
    )
  )
}

# Local New York clock time on a session date, as UTC POSIXct.
pit_audit_at <- function(date, hms) {
  as.POSIXct(format(as.POSIXct(paste(as.Date(date), hms), tz = pit_audit_tz), tz = "UTC"), tz = "UTC")
}

pit_audit_fixture <- function(knowledge = c("announcement", "effective_only")) {
  knowledge <- match.arg(knowledge)
  cal <- pit_audit_calendar()
  s <- cal$open_days
  close_at <- function(k) pit_audit_at(s[k], if (k == 30L) "13:00:00" else "16:00:00")
  open_at <- function(k) pit_audit_at(s[k], "09:30:00")

  # Bars: one row per instrument and listed session, stamped at the session
  # close. `close` gives the as-provided close per session; `open` defaults
  # to the close. ledgr's bars are split-adjusted by contract.
  bars <- list()
  add_bars <- function(id, k, close, open = close, volume = 1000) {
    k <- as.integer(k)
    close <- rep_len(close, length(k))
    open <- rep_len(open, length(k))
    volume <- rep_len(volume, length(k))
    bars[[length(bars) + 1L]] <<- data.frame(
      instrument_id = id,
      ts_utc = do.call(c, lapply(k, close_at)),
      open = open, high = pmax(open, close), low = pmin(open, close), close = close,
      volume = volume, stringsAsFactors = FALSE
    )
  }
  aaa_close <- ifelse(seq_len(40) <= 24L, 40, 44)
  aaa_open <- aaa_close
  aaa_open[[11]] <- 42
  add_bars("AAA", 1:40, aaa_close, aaa_open)                        # continuous; stock acquirer
  add_bars("BBB", 1:40, 30)                                          # added s10, announced s5
  add_bars("CCC", 1:18, c(rep(49, 17), 49.80))                       # $50 cash acquisition
  add_bars("DDD", 1:24, 30)                                          # 0.75 AAA per DDD from s25
  add_bars("EEE", 1:22, c(rep(3, 21), 2))                            # removed s21, exchange exit s22
  add_bars("EEE", 23:26, 1.5)                                        # OTC prints (quotation_only)
  add_bars("FFF", c(1:13, 16:40), c(rep(20, 13), rep(14, 25)))       # halted s14-s15, reopens -30%
  add_bars("GGG", 1:40, 60)                                          # adjusted only: splits not events
  add_bars("HHH", 1:40, c(rep(50, 14), rep(49, 26)))                 # $1 dividend ex s15, paid s25
  add_bars("III", 1:40, c(rep(40, 16), rep(35, 24)))                 # spins off JJJ, ex s17
  add_bars("JJJ", 17:40, 10, open = 10)                              # spun-off child, never a member
  add_bars("KKK", 1:12, 25)                                          # delisted after s12
  add_bars("KKK2", 25:40, 70)                                        # unrelated reuse of ticker KKK
  add_bars("LLL", 8:40, 15)                                          # listed s8, added s20
  add_bars("MMM", c(1:7, 9, 11:40), 12, volume = c(rep(1000, 7), 0, rep(1000, 30)))  # s8 padded, s9 zero volume, s10 midpoint
  add_bars("NNN", 1:40, 18)                                          # removed s15, re-added s30
  add_bars("OOO", 1:25, 22)                                          # redomiciled as OOO2 on s26
  add_bars("OOO2", 26:40, 22)
  bars <- do.call(rbind, bars)

  instruments <- data.frame(
    instrument_id = c("AAA", "BBB", "CCC", "DDD", "EEE", "FFF", "GGG", "HHH", "III", "JJJ",
                      "KKK", "KKK2", "LLL", "MMM", "NNN", "OOO", "OOO2"),
    stringsAsFactors = FALSE
  )

  # Membership intervals (half-open, effective_from included). The index
  # count changes only where the scenarios say so.
  member_rows <- function(id, from_k, to_k = NA_integer_) {
    data.frame(instrument_id = id,
               effective_from = open_at(from_k),
               effective_to = if (is.na(to_k)) as.POSIXct(NA, tz = "UTC") else open_at(to_k),
               member = TRUE, stringsAsFactors = FALSE)
  }
  membership <- rbind(
    member_rows("AAA", 1), member_rows("BBB", 10), member_rows("CCC", 1, 19),
    member_rows("DDD", 1, 25), member_rows("EEE", 1, 21), member_rows("FFF", 1),
    member_rows("GGG", 1), member_rows("HHH", 1), member_rows("III", 1),
    member_rows("KKK", 1, 13), member_rows("LLL", 20), member_rows("MMM", 1),
    member_rows("NNN", 1, 15), member_rows("NNN", 30), member_rows("OOO", 1, 26),
    member_rows("OOO2", 26)
  )
  if (identical(knowledge, "announcement")) {
    # Known when announced: BBB at 17:15 ET on s5; everything else known one
    # second before it takes effect.
    membership$knowledge_time <- membership$effective_from - 1
    membership$knowledge_time[membership$instrument_id == "BBB"] <- pit_audit_at(s[5], "17:15:00")
  }

  lifetime <- data.frame(
    instrument_id = c("CCC", "DDD", "EEE", "KKK", "OOO", "LLL"),
    effective_from = c(open_at(19), open_at(25), open_at(23), open_at(13), open_at(26), open_at(8)),
    assertion = c("known_inactive", "known_inactive", "known_inactive", "known_inactive", "known_inactive", "known_active"),
    terminal_event = c("cash_acquisition", "stock_acquisition", "regulatory_delisting", "delisting",
                       "identifier_change", NA),
    stringsAsFactors = FALSE
  )
  lifetime$knowledge_time <- lifetime$effective_from - 1

  status <- data.frame(
    instrument_id = c("FFF", "FFF", "EEE"),
    effective_from = c(open_at(14), open_at(16), open_at(23)),
    effective_to = c(open_at(16), as.POSIXct(NA, tz = "UTC"), as.POSIXct(NA, tz = "UTC")),
    status = c("halted", "active", "quotation_only"),
    source = "audit_fixture",
    stringsAsFactors = FALSE
  )
  status$knowledge_time <- status$effective_from - 1

  # Corporate-action clocks must land on run pulses (session closes); a clock
  # between pulses refuses the run (ledgr_corporate_action_clock_mismatch,
  # observed while building this fixture). Entitlement is the close before
  # the ex-date, effective the ex-date close, payment the payment-date close.
  ca_row <- function(fact_id, subtype, parent, effective_k, payment_k = NA_integer_, cash = NA_real_,
                     recipient = NA_character_, quantity = NA_real_) {
    data.frame(
      fact_id = fact_id, subtype = subtype, parent_instrument_id = parent,
      entitlement_time = close_at(effective_k - 1L), effective_time = close_at(effective_k),
      knowledge_time = open_at(1) - 1,
      payment_time = if (is.na(payment_k)) close_at(effective_k) else close_at(payment_k),
      complete = TRUE, provenance_tier = "snapshot_bound",
      gross_cash_per_parent_unit = cash, gross_cash_validated = !is.na(cash),
      recipient_instrument_id = recipient, recipient_identity_validated = !is.na(recipient),
      recipient_quantity_per_parent_unit = quantity, recipient_quantity_validated = !is.na(quantity),
      source = "audit_fixture", stringsAsFactors = FALSE
    )
  }
  corporate_actions <- rbind(
    ca_row("ccc-cash", "cash_acquisition", "CCC", 19, 20, cash = 50),
    ca_row("ddd-stock", "stock_acquisition", "DDD", 25, recipient = "AAA", quantity = 0.75),
    ca_row("hhh-div", "ordinary_cash_dividend", "HHH", 15, 25, cash = 1),
    ca_row("iii-spin", "spin_off", "III", 17, recipient = "JJJ", quantity = 0.5)
  )

  mem_knowledge <- if (identical(knowledge, "announcement")) "evidenced" else "assume_effective"
  if (identical(knowledge, "effective_only")) membership$knowledge_time <- NULL
  families <- list(
    sessions = ledgr::ledgr_facts_sessions(cal$sessions, venue_id = "XNYS", timezone = pit_audit_tz,
                                           knowledge = "assume_effective"),
    membership = ledgr::ledgr_facts_membership_intervals(membership, universe_id = "AUDIT500",
                                                         knowledge = mem_knowledge),
    lifetime = ledgr::ledgr_facts_lifetime(lifetime, knowledge = "evidenced"),
    status = ledgr::ledgr_facts_trading_status(status, knowledge = "evidenced"),
    corporate_actions = ledgr::ledgr_facts_equity_corporate_actions(corporate_actions)
  )

  list(
    knowledge = knowledge,
    sessions = cal$open_days,
    closed_adhoc = cal$closed_adhoc,
    bars = bars,
    instruments = instruments,
    families = families,
    universe_id = "AUDIT500",
    not_expressible = data.frame(
      yardstick_role = c("GGG split and reverse split as events", "GGG renamed GGH",
                         "KKK ticker reuse", "MMM padded bar on s8", "MMM quote midpoint on s10",
                         "EEE delisting-return sentinel -55", "AAA vendor sentinel dates",
                         "DDD/CCC election and mixed variants"),
      fixture_choice = c("split-adjusted bars only (ledgr price_basis contract)",
                         "no symbol history; instrument IDs are permanent",
                         "separate instrument IDs KKK and KKK2",
                         "no bar (the adapter drops padded bars)",
                         "no bar (OHLC must be positive)",
                         "no delisting-return field; terminal row without settlement terms",
                         "membership intervals carry no vendor sentinels",
                         "not built yet; one cash and one stock acquisition only"),
      stringsAsFactors = FALSE
    )
  )
}

pit_audit_snapshot <- function(fx, db_path = tempfile(fileext = ".duckdb")) {
  ledgr::ledgr_snapshot_from_df(
    fx$bars, fx$instruments, db_path = db_path,
    facts = do.call(ledgr::ledgr_facts, unname(fx$families)),
    price_basis = "split_adjusted"
  )
}
