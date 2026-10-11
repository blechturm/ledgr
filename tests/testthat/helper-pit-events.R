# Three instruments over fifteen sessions with a membership universe "u":
# BBB has no bar on the sixth session, CCC stops after the ninth and becomes
# known_inactive (bankruptcy) on the tenth. Shared by the Cut 11 and Cut 12
# tests; `second_members` adds a later complete membership set. Sessions and
# membership assume their knowledge clocks unless `knowledge = "evidenced"`.
scale_test_events_snapshot <- function(second_members = NULL, edit_bars = identity, sessions_from = NULL, sessions_to = NULL,
                                       price_basis = "split_adjusted", corporate_actions = NULL,
                                       knowledge = "assume_effective", extra_facts = NULL, ...) {
  days <- as.Date("2021-01-04") + c(0:4, 7:11, 14:18)
  utc <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  ids <- c("AAA", "BBB", "CCC")
  bars <- do.call(rbind, lapply(seq_along(ids), function(k) {
    keep <- if (ids[[k]] == "CCC") days[1:9] else days
    data.frame(instrument_id = ids[[k]], ts_utc = utc(keep), open = 10 * k + seq_along(keep) / 10,
               high = 10 * k + seq_along(keep) / 10, low = 10 * k + seq_along(keep) / 10,
               close = 10 * k + seq_along(keep) / 10, volume = 100)
  }))
  bars <- bars[!(bars$instrument_id == "BBB" & bars$ts_utc == utc(days[[6]])), , drop = FALSE]
  bars <- edit_bars(bars)
  calendar <- seq(sessions_from %||% min(days), sessions_to %||% max(days), by = "day")
  open <- calendar %in% days
  sessions <- data.frame(session_date = calendar, status = ifelse(open, "open", "closed"),
                         session_open = ifelse(open, "14:30:00", NA), session_close = ifelse(open, "21:00:00", NA))
  if (identical(knowledge, "evidenced")) sessions$knowledge_time <- utc(min(calendar) - 1)
  membership <- data.frame(effective_from = utc(days[[1]] - 1), knowledge_time = utc(days[[1]] - 1), source = "t")
  membership$members <- I(list(ids))
  if (!is.null(second_members)) {
    later <- data.frame(effective_from = utc(days[[4]]), knowledge_time = utc(days[[4]]), source = "t")
    later$members <- I(list(second_members))
    membership <- rbind(membership, later)
  }
  facts <- do.call(ledgr_facts, Filter(Negate(is.null), list(
    ledgr_facts_sessions(sessions, venue_id = "V", knowledge = knowledge),
    ledgr_facts_membership_snapshots(membership, universe_id = "u", complete = TRUE, knowledge = knowledge),
    ledgr_facts_lifetime(data.frame(instrument_id = "CCC", effective_from = utc(days[[10]]),
                                    knowledge_time = utc(days[[10]]) - 1, assertion = "known_inactive",
                                    terminal_event = "bankruptcy")),
    corporate_actions,
    extra_facts
  )))
  ledgr_snapshot_from_df(bars, data.frame(instrument_id = ids), db_path = tempfile(fileext = ".duckdb"), facts = facts,
                         price_basis = price_basis, ...)
}
