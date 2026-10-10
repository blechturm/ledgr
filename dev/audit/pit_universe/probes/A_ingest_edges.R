# Stage 1 probe (reader A): ingest edge behavior at the frozen commit.
# Description only: prints what happens; asserts nothing.
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/A_ingest_edges.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")

say <- function(case, value) cat(sprintf("[%s] %s\n", case, paste(value, collapse = " | ")))
try_class <- function(expr) {
  tryCatch({ force(expr); "no error" }, error = function(e) paste(class(e)[1:2], collapse = ","))
}

fx <- pit_audit_fixture("announcement")
facts <- do.call(ledgr_facts, unname(fx$families))

# A1: a bar stamped at 16:00 ET on an ad hoc closed weekday, and a bar at a
# non-close time on an open session.
closed_day <- fx$closed_adhoc[[1L]]
extra <- fx$bars[fx$bars$instrument_id == "AAA", , drop = FALSE][1:2, ]
extra$ts_utc <- c(pit_audit_at(closed_day, "16:00:00"), pit_audit_at(fx$sessions[[3L]], "12:00:00"))
bars_a1 <- rbind(fx$bars, extra)
rep_a1 <- ledgr_facts_validate(facts, bars_a1)
obs <- rep_a1$observations[rep_a1$observations$row > nrow(fx$bars), ]
say("A1 closed-day and intraday bars: can_seal", rep_a1$can_seal)
say("A1 outcomes", paste(obs$outcome, obs$reason))
snap_a1 <- ledgr_snapshot_from_df(bars_a1, fx$instruments, facts = facts, price_basis = "split_adjusted")
say("A1 sealed bars stored", ledgr_snapshot_info(snap_a1)$n_bars %||% "n/a")
say("A1 quarantine rows", nrow(ledgr_snapshot_quarantine(snap_a1)))
ledgr_snapshot_close(snap_a1)

# A2: zero and negative closes (finite) with and without facts.
bars_a2 <- fx$bars
bars_a2$close[bars_a2$instrument_id == "MMM"][2] <- 0
bars_a2$low[bars_a2$instrument_id == "MMM"][2] <- 0
bars_a2$open[bars_a2$instrument_id == "MMM"][3] <- -1
bars_a2$low[bars_a2$instrument_id == "MMM"][3] <- -1
rep_a2 <- ledgr_facts_validate(facts, bars_a2)
say("A2 zero/negative OHLC with facts: can_seal", rep_a2$can_seal)
dense <- data.frame(instrument_id = "Z", ts_utc = as.POSIXct("2021-01-04", tz = "UTC") + 86400 * 0:2,
                    open = c(1, 0, -1), high = c(1, 0, 0), low = c(1, 0, -1), close = c(1, 0, -1))
say("A2 zero/negative OHLC dense from_df", try_class(ledgr_snapshot_close(ledgr_snapshot_from_df(dense))))

# A3: exact duplicate rows per family.
ca_rows <- fx$families$corporate_actions$rows
raw_ca <- ca_rows[1, setdiff(names(ca_rows), c("fact_id", "provenance_json")), drop = FALSE]
say("A3 duplicate corporate-action rows", try_class(ledgr_facts_equity_corporate_actions(rbind(raw_ca, raw_ca))))
lt <- data.frame(instrument_id = "KKK", effective_from = as.POSIXct("2021-03-18", tz = "UTC"),
                 knowledge_time = as.POSIXct("2021-03-17", tz = "UTC"), assertion = "known_inactive",
                 terminal_event = "delisting")
lt2 <- ledgr_facts_lifetime(rbind(lt, lt))
say("A3 duplicate lifetime rows -> rows kept", nrow(lt2$rows))
mi <- data.frame(instrument_id = "AAA", effective_from = as.POSIXct("2021-03-01", tz = "UTC"), member = TRUE,
                 knowledge_time = as.POSIXct("2021-02-28", tz = "UTC"))
say("A3 duplicate membership rows -> rows kept", nrow(ledgr_facts_membership_intervals(rbind(mi, mi), "U")$rows))

# A4: a later-known revision of membership over the same effective interval.
rev <- rbind(mi, transform(mi, member = FALSE, knowledge_time = as.POSIXct("2021-03-10", tz = "UTC")))
say("A4 membership revision (TRUE then later-known FALSE)", try_class(ledgr_facts_membership_intervals(rev, "U")))
lrev <- rbind(transform(lt, assertion = "known_active", terminal_event = NA),
              transform(lt, knowledge_time = as.POSIXct("2021-03-20", tz = "UTC")))
say("A4 lifetime revision (active then later-known inactive)", try_class(ledgr_facts_lifetime(lrev)))

# A5: Date-labelled bars with declared sessions; one on a closed date.
bars_a5 <- fx$bars[fx$bars$instrument_id == "AAA", c("instrument_id", "open", "high", "low", "close", "volume")]
bars_a5$ts_utc <- fx$sessions
bars_a5 <- rbind(bars_a5, transform(bars_a5[1, ], ts_utc = closed_day))
sess_only <- ledgr_facts(fx$families$sessions)
rep_a5 <- ledgr_facts_validate(sess_only, bars_a5)
say("A5 first mapped ts", rep_a5$observations$ts_utc[[1L]])
say("A5 closed-date label", paste(tail(rep_a5$observations$outcome, 1), tail(rep_a5$observations$reason, 1)))
say("A5 can_seal", rep_a5$can_seal)
nofact <- bars_a5[1:2, ]
s5 <- ledgr_snapshot_from_df(nofact)
say("A5 Date bars without facts -> start_date", ledgr_snapshot_info(s5)$start_date)
ledgr_snapshot_close(s5)

# A6: a member with no bars and no instrument master.
mem_nobar <- ledgr_facts(ledgr_facts_membership_intervals(
  data.frame(instrument_id = c("AAA", "ZZZ"), effective_from = as.POSIXct("2021-03-01", tz = "UTC"),
             member = TRUE, knowledge_time = as.POSIXct("2021-02-28", tz = "UTC")), "U"))
rep_a6 <- ledgr_facts_validate(mem_nobar, fx$bars[fx$bars$instrument_id == "AAA", ])
say("A6 member without bars, no master", paste(rep_a6$can_seal, paste(rep_a6$facts$outcome, rep_a6$facts$reason, collapse = ";")))
rep_a6b <- ledgr_facts_validate(mem_nobar, fx$bars[fx$bars$instrument_id == "AAA", ],
                                data.frame(instrument_id = c("AAA", "ZZZ")))
say("A6 member without bars, with master", rep_a6b$can_seal)

# A7: lifetime label edge cases; evidenced corporate action without knowledge_time.
l7 <- ledgr_facts_lifetime(data.frame(instrument_id = c("AAA", "BBB"),
  effective_from = as.POSIXct("2021-03-05", tz = "UTC"), knowledge_time = as.POSIXct("2021-03-04", tz = "UTC"),
  assertion = c("known_active", "known_inactive"), terminal_event = c("delisting", "")))
say("A7 known_active with label kept; empty label stored as", paste(l7$rows$assertion, l7$rows$terminal_event))
ca7 <- raw_ca
ca7$knowledge_time <- as.POSIXct(NA)
ca7f <- ledgr_facts_equity_corporate_actions(ca7)
say("A7 CA provenance when knowledge_time missing", ca7f$rows$provenance_json)
rep_a7 <- ledgr_facts_validate(ledgr_facts(ca7f), fx$bars)
say("A7 CA missing knowledge outcome", paste(rep_a7$facts$outcome, rep_a7$facts$reason))
say("A7 unknown subtype seals", try_class(ledgr_facts_equity_corporate_actions(transform(raw_ca, subtype = "cash_dividend"))))

# A8: a second sessions family (another venue) in one bundle.
sess2 <- ledgr_facts_sessions(fx$families$sessions$rows[, c("session_date", "status")] |>
  transform(session_open = ifelse(status == "open", "09:00:00", NA), session_close = ifelse(status == "open", "17:00:00", NA)),
  venue_id = "XLON", timezone = "Europe/London", knowledge = "assume_effective")
b8 <- ledgr_facts(fx$families$sessions, sess2)
say("A8 ledgr_facts() with two venues", "built")
say("A8 validate with two venues", try_class(ledgr_facts_validate(b8, fx$bars)))

# A9: Date-only effective_from for a non-session fact becomes UTC midnight.
d9 <- ledgr_facts_membership_intervals(data.frame(instrument_id = "AAA", effective_from = as.Date("2021-03-10"),
                                                   member = TRUE), "U", knowledge = "assume_effective")
say("A9 Date effective_from token", format(d9$rows$effective_from, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
c9 <- ledgr_facts_membership_intervals(data.frame(instrument_id = "AAA", effective_from = "2021-03-10 09:30:00",
                                                   member = TRUE), "U", knowledge = "assume_effective")
say("A9 character local-looking effective_from token", format(c9$rows$effective_from, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
