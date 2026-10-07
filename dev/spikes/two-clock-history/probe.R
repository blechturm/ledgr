# Two-clock history probe (spike protocol section 1).
#
# Rscript dev/spikes/two-clock-history/probe.R <ledgr_repo> <out_dir>
#
# Records what the shipped prepared availability provider answers for three
# late-known corrections, and whether the cheapest reuse idea (keep facts known
# by t, pretend each was known when it became effective, resolve at s with the
# unchanged provider) reproduces the historical answer. Binds nothing; changes
# no package file. Internal provider calls are labelled `internal`.
args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
out_dir <- args[[2L]]
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))

day <- function(d, time = "00:00:00") as.POSIXct(paste(as.Date("2020-01-01") + d - 1L, time), tz = "UTC")
dates <- as.Date("2020-01-01") + 0:9
sessions <- ledgr_facts_sessions(
  data.frame(session_date = dates, status = "open", session_open = "09:30:00",
             session_close = "16:00:00", knowledge_time = as.POSIXct(dates, tz = "UTC") - 1),
  venue_id = "XNYS"
)
# Halt on AAA for days 3-5, known on day 3; retracted on day 8 by a fact that
# supersedes it for the same effective interval.
status <- ledgr_facts_trading_status(data.frame(
  instrument_id = "AAA", effective_from = day(3), effective_to = day(6),
  knowledge_time = c(day(3), day(8)), status = c("halted", "active"),
  source = "probe", precedence = 1L, fact_id = c("halt-orig", "halt-corr"),
  supersedes_fact_id = c(NA, "halt-orig")
))
# A lifetime correction (inactive from day 4 known day 4, reversed by an active
# assertion for the same time known day 9) is attempted and its outcome kept.
# The fixture then uses a plain late-known fact: BBB inactive from day 4,
# learned only on day 9.
lifetime_correction <- tryCatch(
  ledgr_facts_lifetime(data.frame(
    instrument_id = "BBB", effective_from = day(4), knowledge_time = c(day(4), day(9)),
    assertion = c("known_inactive", "known_active"), terminal_event = NA_character_,
    fact_id = c("bbb-inactive", "bbb-active")
  )),
  error = function(e) e
)
lifetime <- ledgr_facts_lifetime(data.frame(
  instrument_id = "BBB", effective_from = day(4), knowledge_time = day(9),
  assertion = "known_inactive", terminal_event = NA_character_, fact_id = "bbb-inactive"
))
# Universe snapshot {AAA, BBB} from day 1; a corrected complete snapshot {AAA}
# for the same effective day, known on day 7.
membership_input <- data.frame(effective_from = day(1, "00:00:00"), knowledge_time = c(day(1) - 1, day(7)),
                               set_id = c("set-orig", "set-corr"), source = "probe")
membership_input$members <- I(list(c("AAA", "BBB"), "AAA"))
membership <- tryCatch(
  ledgr_facts_membership_snapshots(
    membership_input,
    universe_id = "u", complete = TRUE
  ),
  error = function(e) e
)
membership_ok <- !inherits(membership, "error")

bars <- data.frame(
  instrument_id = rep(c("AAA", "BBB"), each = 10), ts_utc = rep(day(1:10, "16:00:00"), 2),
  open = 100, high = 101, low = 99, close = 100, volume = 1000
)
families <- if (membership_ok) ledgr_facts(sessions, status, lifetime, membership) else ledgr_facts(sessions, status, lifetime)
snapshot <- ledgr_snapshot_from_df(bars, facts = families, price_basis = "split_adjusted",
                                   db_path = tempfile(fileext = ".duckdb"))
on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

provider_for <- function(snap) {
  exp <- ledgr_experiment(
    snap, function(ctx, params) ctx$hold(),
    universe = if (membership_ok) ledgr_universe_members("u") else NULL,
    valuation_policy = ledgr_valuation_stale(1L), cost_model = ledgr_cost_zero()
  )
  con <- ledgr:::get_connection(snap)
  data <- ledgr:::ledgr_availability_provider_data(con, snap$snapshot_id)
  ledgr:::ledgr_availability_provider_portable(
    data, ledgr:::ledgr_sweep_availability_config(exp),
    ledgr:::ledgr_precompute_snapshot_meta(snap)$snapshot_hash, list()
  )
}
answer <- function(provider, cutoff) {
  f <- provider$facts(cutoff, ids = c("AAA", "BBB"))
  members <- if (membership_ok) {
    paste(sort(as.character(ledgr_facts_resolve(snapshot, "membership", "u", at = cutoff)$rows$instrument_id[
      ledgr_facts_resolve(snapshot, "membership", "u", at = cutoff)$rows$member %in% TRUE])), collapse = "+")
  } else NA_character_
  c(aaa_status = f$status[["AAA"]], bbb_lifetime = f$lifetime[["BBB"]], members = members)
}

rows <- list()
add <- function(probe, s, t, value, note) {
  rows[[length(rows) + 1L]] <<- data.frame(probe = probe, s_day = s, t_day = t, observable = names(value),
                                           value = unname(value), note = note, stringsAsFactors = FALSE)
}
add("setup", NA, NA, c(membership_constructor = if (membership_ok) "accepted" else conditionMessage(membership)),
    "public constructor")
add("setup", NA, NA, c(lifetime_correction_constructor = if (inherits(lifetime_correction, "error")) paste(class(lifetime_correction)[[1L]], conditionMessage(lifetime_correction)) else "accepted"),
    "public constructor")

# P1: the shipped prepared provider answers only the diagonal (s = t).
provider <- provider_for(snapshot)
for (d in c(2L, 4L, 5L, 8L, 9L)) add("P1 diagonal", d, d, answer(provider, day(d, "12:00:00")), "internal provider + public ledgr_facts_resolve")

# P2: the cheapest reuse idea. Keep facts known by t, set each one's knowledge
# time to its effective time, rebuild, and resolve at s with unchanged code.
retimed_answer <- function(s, t) {
  keep <- function(df) df[df$knowledge_time <= day(t, "12:00:00"), , drop = FALSE]
  st <- keep(status$rows); st$knowledge_time <- st$effective_from
  lt <- keep(lifetime$rows); lt$knowledge_time <- lt$effective_from
  fams <- list(sessions)
  if (nrow(st) > 0L) fams <- c(fams, list(ledgr_facts_trading_status(st[, intersect(names(st), c("instrument_id", "effective_from", "effective_to", "knowledge_time", "status", "source", "precedence", "fact_id", "supersedes_fact_id"))])))
  mi <- membership_input[membership_input$knowledge_time <= day(t, "12:00:00"), , drop = FALSE]
  mi$knowledge_time <- mi$effective_from
  if (membership_ok && nrow(mi) > 0L) fams <- c(fams, list(ledgr_facts_membership_snapshots(mi, universe_id = "u", complete = TRUE)))
  if (nrow(lt) > 0L) fams <- c(fams, list(ledgr_facts_lifetime(lt[, intersect(names(lt), c("instrument_id", "effective_from", "knowledge_time", "assertion", "terminal_event", "fact_id"))])))
  snap <- ledgr_snapshot_from_df(bars, facts = do.call(ledgr_facts, fams), price_basis = "split_adjusted",
                                 db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snap), add = TRUE)
  exp <- ledgr_experiment(snap, function(ctx, params) ctx$hold(), valuation_policy = ledgr_valuation_stale(1L),
                          cost_model = ledgr_cost_zero())
  con <- ledgr:::get_connection(snap)
  p <- ledgr:::ledgr_availability_provider_portable(
    ledgr:::ledgr_availability_provider_data(con, snap$snapshot_id), ledgr:::ledgr_sweep_availability_config(exp),
    ledgr:::ledgr_precompute_snapshot_meta(snap)$snapshot_hash, list())
  f <- p$facts(day(s, "12:00:00"), ids = c("AAA", "BBB"))
  resolved <- ledgr_facts_resolve(snap, "membership", "u", at = day(s, "12:00:00"))$rows
  c(aaa_status = f$status[["AAA"]], bbb_lifetime = f$lifetime[["BBB"]],
    members = paste(sort(as.character(resolved$instrument_id[resolved$member %in% TRUE])), collapse = "+"))
}
for (st in list(c(4L, 5L), c(4L, 8L), c(5L, 9L))) {
  value <- tryCatch(retimed_answer(st[[1L]], st[[2L]]), error = function(e) c(error = conditionMessage(e)))
  add("P2 retimed reuse", st[[1L]], st[[2L]], value, "public constructors + internal provider")
}

out <- do.call(rbind, rows)
utils::write.csv(out, file.path(out_dir, "probe_evidence.csv"), row.names = FALSE)
print(out[, c("probe", "s_day", "t_day", "observable", "value")], row.names = FALSE, right = FALSE)
