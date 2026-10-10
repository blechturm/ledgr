# Stage 1 probe B: availability provider resolution (subsystem 3).
# Description only. Prints what the prepared provider resolves; asserts nothing.
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/B_provider_resolution.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE)
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")
options(width = 200)

utc <- function(x) as.POSIXct(x, tz = "UTC")

# --- Part 1: fixture provider views -------------------------------------
fx <- pit_audit_fixture("announcement")
snap <- pit_audit_snapshot(fx, db_path = file.path(tempdir(), "B_provider.duckdb"))
con <- get_connection(snap)
data <- ledgr_availability_provider_data(con, snap$snapshot_id)
cat("declared families:", paste(unique(data$families$family), collapse = ","), "\n")
ids_all <- fx$instruments$instrument_id
cfg <- list(
  universe = list(instrument_ids = ids_all),
  availability = list(active = TRUE, universe_rule = list(universe_id = "AUDIT500"))
)
prov <- ledgr_availability_provider_build(data, cfg, "hash", history = NULL)
s <- fx$sessions
close_at <- function(k) pit_audit_at(s[k], if (k == 30L) "13:00:00" else "16:00:00")
open_at <- function(k) pit_audit_at(s[k], "09:30:00")
no_pos <- stats::setNames(numeric(0), character(0))
show_view <- function(label, k, positions = no_pos) {
  v <- prov$decision_view(close_at(k), positions)
  cat(sprintf("\n[%s] decision at s%d close: axis=%s\n", label, k, paste(v$axis, collapse = ",")))
  print(data.frame(id = v$axis, member = unname(v$member), held = unname(v$held),
                   status = unname(v$status), lifetime = unname(v$lifetime),
                   restricted = unname(v$target_restricted),
                   reason = unname(v$target_restriction_reason),
                   reasons = unname(v$target_restriction_reasons)), row.names = FALSE)
}
show_view("P1a", 5)
show_view("P1b", 14)
show_view("P1c", 16)
show_view("P1d held nonmember NNN and EEE", 24, c(NNN = 5, EEE = 3, JJJ = 2))
# BBB is announced at s5 17:15 ET and effective s10 09:30: member at s9 close?
v9 <- prov$decision_view(close_at(9), no_pos)
cat("\n[P1e] BBB member at s9 close:", "BBB" %in% v9$members, "; at s10 close:",
    "BBB" %in% prov$decision_view(close_at(10), no_pos)$members, "\n")
# Execution view at s15 open for FFF (halted s14-s15) and membership change NNN (removed s15 open)
ev <- prov$execution_view(open_at(15), c("FFF", "NNN", "AAA"))
cat("\n[P1f] execution view at s15 open:\n")
print(data.frame(id = names(ev$status), status = unname(ev$status), member = unname(ev$member),
                 restricted = unname(ev$restricted), reasons = unname(ev$reasons)), row.names = FALSE)

# Runtime calendar ignores session knowledge? Show session rows' knowledge columns.
cat("\n[P1g] session columns:", paste(names(data$sessions), collapse = ","), "\n")

# Public resolver vs provider membership at s9 close and s15 open
res <- ledgr_facts_resolve(snap, "membership", "AUDIT500", at = close_at(9), instruments = c("BBB", "JJJ", "NNN"))
cat("\n[P1h] ledgr_facts_resolve at s9 close for BBB, JJJ, NNN:\n")
print(res$rows[, c("instrument_id", "member", "reason")], row.names = FALSE)
ledgr_snapshot_close(snap)

# --- Part 2: synthetic precedence cases (no DB) --------------------------
t <- function(d) utc(sprintf("2021-01-%02d 21:00:00", d))
families <- data.frame(family = c("membership", "sessions", "trading_status", "lifetime"),
                       scope_id = c("U", "V", "", ""), stringsAsFactors = FALSE)
membership_sets <- data.frame(universe_id = "U", set_id = "S1", effective_from = t(5),
                              knowledge_time = t(5), complete = TRUE, stringsAsFactors = FALSE)
membership <- data.frame(
  universe_id = "U",
  set_id = c("S1", NA),
  instrument_id = c("AAA", "BBB"),
  effective_from = c(t(5), t(1)),
  effective_to = utc(c(NA, NA)),
  knowledge_time = c(t(5), t(1)),
  member = c(TRUE, TRUE),
  fact_id = c("m1", "m2"),
  stringsAsFactors = FALSE
)
status <- data.frame(
  instrument_id = c("AAA", "AAA"),
  status = c("halted", "active"),
  precedence = c(1L, 2L),
  fact_id = c("st1", "st2"),
  supersedes_fact_id = c(NA, "st1"),
  effective_from = c(t(2), t(3)),
  effective_to = utc(c(NA, format(t(6), "%Y-%m-%d %H:%M:%S"))),
  knowledge_time = c(t(2), t(3)),
  stringsAsFactors = FALSE
)
lifetime <- data.frame(instrument_id = character(), assertion = character(), terminal_event = character(),
                       fact_id = character(), effective_from = utc(character()),
                       effective_to = utc(character()), knowledge_time = utc(character()),
                       stringsAsFactors = FALSE)
syn <- list(families = families, membership_sets = membership_sets, membership = membership,
            status = status, lifetime = lifetime, sessions = data.frame())
cfg2 <- list(universe = list(instrument_ids = c("AAA", "BBB", "CCC")),
             availability = list(active = TRUE, universe_rule = list(universe_id = "U")))
p2 <- ledgr_availability_provider_build(syn, cfg2, "h", history = NULL)
for (d in c(2, 4, 5, 7)) {
  v <- p2$decision_view(t(d), no_pos)
  f <- p2$facts(t(d), c("AAA", "BBB", "CCC"))
  cat(sprintf("\n[P2 day %d] members=%s | status AAA=%s BBB=%s CCC=%s\n", d,
              paste(v$members, collapse = ","), f$status[["AAA"]], f$status[["BBB"]], f$status[["CCC"]]))
}
# Resolver on the same synthetic data, BBB interval vs complete set S1 omitting BBB
r <- ledgr_membership_resolve_at(syn, "U", t(7), instruments = c("AAA", "BBB", "CCC"))
cat("\n[P2 resolver day 7]\n")
print(r$rows, row.names = FALSE)
