# Design-review probes for D2 (supersession chains) and D5 (interval end clock).
# Read-only against the package; writes nothing under the repo.
suppressMessages(pkgload::load_all("C:/Users/maxth/Documents/GitHub/ledgr", quiet = TRUE, compile = FALSE))
day <- function(d, h = 0) as.POSIXct(as.Date("2020-01-01") + d - 1L, tz = "UTC") + h * 3600
noon <- function(d) day(d, 12)

status_rows <- function(fact_id, from, to, known, status, precedence, supersedes) {
  data.frame(
    fact_id = fact_id, instrument_id = "AAA",
    effective_from = from, effective_to = to, knowledge_time = known,
    status = status, source = "s", precedence = as.integer(precedence),
    revision_id = NA_character_, supersedes_fact_id = supersedes,
    provenance_json = "{}", stringsAsFactors = FALSE
  )
}
provider_for <- function(rows) {
  data <- list(
    families = data.frame(family = "trading_status", scope_id = "instrument", stringsAsFactors = FALSE),
    status = rows, lifetime = data.frame(), membership = data.frame(), membership_sets = data.frame(),
    sessions = NULL
  )
  config <- list(universe = list(instrument_ids = "AAA"), availability = list(universe_rule = NULL))
  ledgr:::ledgr_availability_provider_build_prepared(data, config, "probe", function(...) NULL)
}
status_at <- function(p, d) unname(p$facts(noon(d), ids = "AAA")$status)

cat("== D2-a: constructor today refuses a same-precedence 3-chain (expected, 4.2 direct-pair rule)\n")
r <- tryCatch({
  ledgr_facts_trading_status(data.frame(
    instrument_id = "AAA", effective_from = day(3), effective_to = day(9),
    knowledge_time = c(day(3), day(5), day(7)), status = c("halted", "active", "quotation_only"),
    source = "s", precedence = 1L, fact_id = c("f1", "f2", "f3"), supersedes_fact_id = c(NA, "f1", "f2")))
  "accepted"
}, error = function(e) paste("refused:", class(e)[[1L]]))
cat(r, "\n")

cat("\n== D2-b: what the resolver does with a same-precedence 3-chain if D2 admits it (monotone knowledge)\n")
rows <- status_rows(c("f1", "f2", "f3"), day(3), day(9), c(day(3), day(5), day(7)),
                    c("halted", "active", "quotation_only"), 1L, c(NA, "f1", "f2"))
p <- provider_for(rows)
for (d in c(4, 6, 8)) cat(sprintf("  diagonal day %d: %s\n", d, status_at(p, d)))

cat("\n== D2-c: same chain, but the MIDDLE link becomes known last (f2 known day 8)\n")
rows2 <- status_rows(c("f1", "f2", "f3"), day(3), day(9), c(day(3), day(8), day(5)),
                     c("halted", "active", "quotation_only"), 1L, c(NA, "f1", "f2"))
p2 <- provider_for(rows2)
for (d in c(4, 6, 7, 8.5)) cat(sprintf("  diagonal day %.1f: %s\n", d, status_at(p2, d)))
cat("  (f1 and f3 are chain-linked, so D2 exempts the pair; at t in [5, 8) only f1 and f3 are knowable,\n",
    "   f3 names an unknown f2, and the resolver returns the tied-precedence answer.)\n")

cat("\n== D2-d: fork: f2 and f3 both directly supersede f1, and disagree with each other\n")
rows3 <- status_rows(c("f1", "f2", "f3"), day(3), day(9), c(day(3), day(5), day(6)),
                     c("halted", "active", "quotation_only"), 1L, c(NA, "f1", "f1"))
r3 <- tryCatch({ ledgr:::ledgr_fact_validate_source_conflicts(rows3); "accepted by today's validator" },
               error = function(e) paste("refused today:", class(e)[[1L]]))
cat("  today's pairwise validator:", r3, "\n")
p3 <- provider_for(rows3)
for (d in c(4, 5.5, 7)) cat(sprintf("  diagonal day %.1f: %s\n", d, status_at(p3, d)))
cat("  (a connected-component exemption would exempt (f2, f3); an ancestor-only exemption would not.)\n")

cat("\n== D2-e: ingest-time runtime-conflict helper reads supersession differently (predecessor truncated)\n")
rows4 <- status_rows(c("f1", "f2"), c(day(3), day(3)), c(day(9), day(9)), c(day(3), day(6)),
                     c("halted", "active"), 1L, c(NA, "f1"))
cat("  ledgr_status_runtime_conflicts:", paste(ledgr:::ledgr_status_runtime_conflicts(rows4), collapse = ","), "\n")
p4 <- provider_for(rows4)
for (d in c(4, 7)) cat(sprintf("  prepared diagonal day %d: %s\n", d, status_at(p4, d)))

cat("\n== D5-a: interval membership: TRUE [1,10) known day 2; FALSE [10,inf) known day 11\n")
iv <- ledgr_facts(ledgr_facts_membership_intervals(data.frame(
  instrument_id = "X", effective_from = day(c(1, 10)), effective_to = as.POSIXct(c(day(10), NA), tz = "UTC"),
  knowledge_time = day(c(2, 11)), member = c(TRUE, FALSE), source = "probe"), universe_id = "u"))
cat("  constructor: accepted (touching half-open intervals)\n")
data <- ledgr:::ledgr_facts_inspection_data(iv)
members_at <- ledgr:::ledgr_availability_prepared_membership(data, "u", "X")
for (d in c(9, 10, 11)) {
  res <- ledgr_facts_resolve(iv, "membership", "u", at = noon(d), instruments = "X")$rows
  cat(sprintf("  day %d noon: fold members_at = {%s}; ledgr_facts_resolve member = %s (%s)\n",
              d, paste(members_at(as.numeric(noon(d))), collapse = ","), res$member, res$reason))
}
cat("  (the exit on day 10 is visible on day 10 although its only encoding is knowable on day 11;\n",
    "   the end date rides on the day-2 row, so the diagonal shows the exit one day before it is knowable.)\n")

cat("\n== D5-b: the honest encoding (open TRUE known day 2, open FALSE known day 11) is refused\n")
r5 <- tryCatch({
  ledgr_facts_membership_intervals(data.frame(
    instrument_id = "X", effective_from = day(c(1, 10)), effective_to = as.POSIXct(c(NA, NA), tz = "UTC"),
    knowledge_time = day(c(2, 11)), member = c(TRUE, FALSE), source = "probe"), universe_id = "u")
  "accepted"
}, error = function(e) paste("refused:", class(e)[[1L]]))
cat(" ", r5, "\n")

cat("\n== D3/D4-a: TTR SMA is certified strict_window today (so a 'TTR defaults history_dependent' rule contradicts it)\n")
if (requireNamespace("TTR", quietly = TRUE)) {
  s <- ledgr_ind_ttr("SMA", input = "close", n = 5L)
  cat("  ledgr_ind_ttr('SMA', n=5)$gap_contract =", s$gap_contract %||% "NULL", "\n")
}

cat("\n== D4-b: bounded built-ins are not bit-stable across starts on the dense path (cumsum rolling mean)\n")
set.seed(7)
x <- round(100 + cumsum(rnorm(3000)), 4)
bars <- data.frame(ts_utc = day(seq_along(x)), close = x)
full <- ledgr:::ledgr_compute_feature_series(bars, ledgr_ind_sma(20L))
late <- ledgr:::ledgr_compute_feature_series(bars[1001:3000, ], ledgr_ind_sma(20L))
cat(sprintf("  SMA(20) dense path: max |full - restart@1001| on common rows = %.3g; identical = %s\n",
            max(abs(full[1020:3000] - late[20:2000])), identical(full[1020:3000], late[20:2000])))
strict_full <- ledgr:::ledgr_strict_sma_series(x, 20L)
strict_late <- ledgr:::ledgr_strict_sma_series(x[1001:3000], 20L)
cat(sprintf("  SMA(20) strict built-in path: identical across starts = %s\n",
            identical(strict_full[1020:3000], strict_late[20:2000])))
if (requireNamespace("TTR", quietly = TRUE)) {
  tf <- as.numeric(TTR::SMA(x, 20)); tl <- as.numeric(TTR::SMA(x[1001:3000], 20))
  cat(sprintf("  TTR::SMA(20): max gap across starts = %.3g; identical = %s\n",
              max(abs(tf[1020:3000] - tl[20:2000])), identical(tf[1020:3000], tl[20:2000])))
  bf <- as.numeric(TTR::BBands(x, n = 20)[, "up"]); bl <- as.numeric(TTR::BBands(x[1001:3000], n = 20)[, "up"])
  cat(sprintf("  TTR::BBands up(20): max gap across starts = %.3g\n", max(abs(bf[1020:3000] - bl[20:2000]))))
  rf <- as.numeric(TTR::RSI(x, 14)); rl <- as.numeric(TTR::RSI(x[1001:3000], 14))
  cat(sprintf("  TTR::RSI(14): max gap across starts after 500 bars = %.3g (recursive, decays)\n",
              max(abs(rf[1520:3000] - rl[520:2000]))))
  wf <- as.numeric(TTR::WMA(x, 20)); wl <- as.numeric(TTR::WMA(x[1001:3000], 20))
  cat(sprintf("  TTR::WMA(20): max gap across starts = %.3g\n", max(abs(wf[1020:3000] - wl[20:2000]))))
}
