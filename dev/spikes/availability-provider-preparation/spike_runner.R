# Comparative spike runner for the availability provider-preparation spike,
# executed under Charter v2
# (rfc_availability_hot_path_representation_v0_2_0_x_provider_spike_charter_v2.md).
#
# Two arms, one seam (ledgr_availability_provider_build(), selected by
# options(ledgr.internal.spike_availability_provider)):
#   current   production provider closures at b0fe6b8 (default);
#   prepared  the one chartered prepared provider (R/availability-provider-prepared.R).
# Both arms hold the GREEN columnar diagnostic writer constant.
#
# Usage, from the repository root:
#   Rscript dev/spikes/availability-provider-preparation/spike_runner.R <mode> [--evidence <dir>]
#   modes: fixtures | parity | semantic | tests | provider757 | fold757 | fold757parity | all
#
# Evidence CSVs:
#   fixture.csv            registered fixtures, the eventful formula and its counts, envelope
#   environment.csv        R, collapse, duckdb, testthat versions and HEAD
#   cutoff_parity.csv      provider-only views at shuffled/repeated cutoffs, arm-to-arm and
#                          membership reference (ledgr_facts_resolve) flags
#   cases.csv              fold scenarios per arm: statuses, counts, parity and reopen flags,
#                          selected and observed arms
#   diagnostics_reference.csv  current-arm direct-run diagnostics on the semantic fixture
#   regression_tests.csv   existing test-availability-*.R results under both arms, without the
#                          explicitly out-of-scope optional parallel-worker test
#   regression_optional.csv  that optional test's outcome per arm: ran or skipped, honestly recorded
#   provider_pass.csv      provider-only passes (static and eventful facts) per arm
#   fold_757.csv           757-pulse fold runs: wall, t_loop, peak WS, status, observed arm
#   lanes_757.csv          lane shares of the profiled prepared fold run
#   fold_757_parity.csv    one non-measured 757-pulse pair: persisted outputs and identity compared
#                          arm-to-arm by DuckDB set difference (run_id and creation time excluded)
# Deterministic CSVs are byte-diffed by the checker; measurement CSVs are
# validated against the Charter's rules. Identity is ledgr's own (run IDs,
# snapshot hashes, run-store rows); no hash ledger, registry, or workspace gate.

args <- commandArgs(trailingOnly = TRUE)
script_path <- local({
  f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(f) == 0L) stop("Run with Rscript.")
  normalizePath(sub("^--file=", "", f[[1L]]), winslash = "/")
})
spike_dir <- dirname(script_path)
repo_root <- normalizePath(file.path(spike_dir, "..", "..", ".."), winslash = "/")
arg_value <- function(flag, default) { i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[[i + 1L]] }
evidence_dir <- normalizePath(arg_value("--evidence", file.path(spike_dir, "evidence")), winslash = "/", mustWork = FALSE)
`%||%` <- function(a, b) if (is.null(a)) b else a

# The same collapse library for every process, selected explicitly (Charter v2).
SPIKE_LIB <- Sys.getenv("LEDGR_SPIKE_LIB", unset = "C:/tmp/ledgr-collapse-218-lib")
if (dir.exists(SPIKE_LIB)) .libPaths(c(normalizePath(SPIKE_LIB, winslash = "/"), .libPaths()))

ARMS <- c("current", "prepared")
ENVELOPE <- list(fold_wall_s = 180, peak_ws_mib = 1024, eventful_pass_s = 82)
WALL_STOP_S <- 1800
WS_STOP_MIB <- 4096
WRITER_RUNNER <- file.path(repo_root, "dev/spikes/availability-hot-path-representation/spike_runner.R")
EXEC_SAMPLE_OPENINGS <- 40L
EXEC_SAMPLE_IDS <- c("I001", "I100", "I250", "I505", "I563")
# Identity columns excluded from arm-to-arm comparison: the local run ID and
# creation time, plus the local locators the config JSON embeds (the run ID
# and the scratch store paths, which differ per run by construction).
# Everything else in `runs` (config, hashes, status, mode) is compared directly.
IDENTITY_EXCLUDED <- c("run_id", "created_at_utc", "archived_at_utc")
IDENTITY_JSON_EXCLUDED <- c("run_id", "db_path", "data.snapshot_db_path")
normalize_identity <- function(row) {
  out <- row[, setdiff(names(row), IDENTITY_EXCLUDED), drop = FALSE]
  cfg <- yyjsonr::read_json_str(as.character(row$config_json))
  cfg$run_id <- NULL; cfg$db_path <- NULL; cfg$data$snapshot_db_path <- NULL
  out$config_json <- yyjsonr::write_json_str(cfg, auto_unbox = TRUE)
  out
}
# The one optional test in the regression net whose outcome depends on an
# optional package (mirai; parallel workers are outside this spike per Charter
# v2). It is recorded separately, never normalised, and kept out of the
# byte-diffed deterministic file (evidence review M1).
OPTIONAL_TESTS <- "parallel availability sweeps return the same compact terminal evidence"

# Eventful provider fixture formula (frozen before the first timing run).
EVENTFUL <- list(
  n_instruments = 563L, n_members = 505L, n_sessions = 757L, n_lists = 60L, rotate = 5L,
  list_sessions = "1 + (0:59) * 12",
  members = "list k: ids[((k - 1) * rotate + 0:504) %% 563 + 1]",
  membership_knowledge = "k %% 4 == 0: effective + 2 days (late); else effective - 1 day",
  halts = "instrument i, m in 0:4: halted from session s = (13 * i) %% 100 + 1 + 150 * m for 3 civil days, source venue, precedence 5",
  halt_knowledge = "even i: effective - 1 day; odd i: effective + 1 day (late)",
  conflicts = "i %% 50 == 0: alt quotation_only, precedence 5, from first halt + 1 day to + 2 days",
  supersession = "i %% 25 == 0: venue halted [session 400, session 410) superseded by venue active known at session 405",
  lifetime = "i %% 20 == 0: known_active ends and known_inactive starts at session 600 + i %% 100, known + 1 day; terminal delisted when i %% 40 == 0"
)

set_arm <- function(arm) options(ledgr.internal.spike_availability_provider = arm, ledgr.internal.spike_diagnostic_writer = "columnar")

# Observed arm: the attribute stamped on the provider object that ledgr actually
# built, captured by tracing the seam's return value.
spike_observed <- new.env()
spike_observed$arms <- character()
install_arm_observer <- function() {
  assign("spike_observed", spike_observed, envir = globalenv())
  suppressMessages(trace("ledgr_availability_provider_build", where = asNamespace("ledgr"), print = FALSE,
    exit = quote(assign("arms", c(get("arms", envir = spike_observed), attr(returnValue(), "spike_arm") %||% NA_character_), envir = spike_observed))))
}
take_observed <- function() { out <- spike_observed$arms; spike_observed$arms <- character(); paste(unique(out), collapse = "|") }

# ---------------------------------------------------------------------------
# Fixtures.
# ---------------------------------------------------------------------------

weekday_sessions <- function(first, n_sessions) {
  civil <- seq(first, by = "day", length.out = as.integer(ceiling(n_sessions * 7 / 5)) + 7L)
  open <- as.POSIXlt(civil)$wday %in% 1:5
  civil <- civil[seq_len(which(cumsum(open) == n_sessions)[[1L]])]
  open <- as.POSIXlt(civil)$wday %in% 1:5
  list(civil = civil, open = open, dates = civil[open])
}
at <- function(date, time = "00:00:00") {
  out <- rep(as.POSIXct(NA, tz = "UTC"), length(date))
  ok <- !is.na(date)
  if (any(ok)) out[ok] <- as.POSIXct(paste(date[ok], time), tz = "UTC")
  out
}
sessions_df <- function(cal, publish) data.frame(
  session_date = cal$civil, status = ifelse(cal$open, "open", "closed"),
  session_open = ifelse(cal$open, "14:30:00", NA_character_), session_close = ifelse(cal$open, "21:00:00", NA_character_),
  knowledge_time = publish, source = "synthetic_calendar", stringsAsFactors = FALSE)

# The registered 757-pulse fold fixture is the writer spike's construction,
# evaluated from that runner's own definitions (spike_fixture, FIXTURES).
registered_fold_fixture <- function() {
  env <- new.env(parent = globalenv())
  for (e in parse(WRITER_RUNNER)) {
    if (is.call(e) && identical(e[[1L]], as.name("<-")) && as.character(e[[2L]]) %in% c("FIXTURES", "spike_fixture", "LIST_FORMULA")) eval(e, env)
  }
  list(fixture = env$spike_fixture(env$FIXTURES$envelope757), spec = env$FIXTURES$envelope757, formula = env$LIST_FORMULA)
}

# Semantic fixture: small, public, every evidence category present so the fork can fail.
semantic_fixture <- function() {
  ids <- c("AAA", "BBB", "CCC", "DDD", "EEE", "FFF", "GGG", "HHH", "III", "JJJ", "KKK", "LLL", "aaa", "bbb")
  cal <- weekday_sessions(as.Date("2021-01-04"), 30L)
  d <- cal$dates
  publish <- at(d[[1L]] - 3)
  n_inst <- length(ids)
  sess_idx <- rep(seq_along(d), each = n_inst)
  close <- 100 + rep(seq_len(n_inst), times = length(d)) + 0.1 * sess_idx
  bars <- data.frame(ts_utc = rep(at(d, "21:00:00"), each = n_inst), instrument_id = rep(ids, times = length(d)),
                     open = close, high = close + 0.5, low = close - 0.5, close = close, volume = 1e5, stringsAsFactors = FALSE)
  lists <- list(
    list(set = "L1", eff = at(d[[1L]]), know = at(d[[1L]] - 1), complete = TRUE, ids = c("AAA", "BBB", "CCC", "DDD", "EEE", "FFF", "GGG", "HHH", "aaa")),
    list(set = "L2", eff = at(d[[11L]]), know = at(d[[10L]]), complete = TRUE, ids = c("AAA", "CCC", "DDD", "EEE", "FFF", "GGG", "HHH", "III", "aaa")),
    list(set = "P1", eff = at(d[[16L]]), know = at(d[[15L]]), complete = FALSE, ids = c("JJJ", "bbb")),
    list(set = "L3", eff = at(d[[21L]]), know = at(d[[24L]]), complete = TRUE, ids = c("AAA", "DDD", "EEE", "FFF", "GGG", "HHH", "III", "JJJ", "KKK", "aaa", "bbb")),
    list(set = "L4", eff = at(d[[26L]]), know = at(d[[26L]], "14:00:00"), complete = TRUE, ids = c("DDD", "EEE", "FFF", "GGG", "HHH", "III", "JJJ", "KKK", "aaa", "bbb"))
  )
  membership <- do.call(rbind, lapply(lists, function(l) data.frame(instrument_id = l$ids, effective_from = l$eff, knowledge_time = l$know,
    set_id = l$set, complete = l$complete, source = "synthetic_membership", stringsAsFactors = FALSE)))
  status <- semantic_status_df(ids, d, publish)
  life_ids <- setdiff(ids, c("HHH", "III", "JJJ"))
  lifetime <- rbind(
    data.frame(instrument_id = life_ids, effective_from = at(d[[1L]]), effective_to = at(NA), knowledge_time = publish, assertion = "known_active",
               terminal_event = NA_character_, source = "life", stringsAsFactors = FALSE),
    data.frame(instrument_id = c("HHH", "HHH", "III", "III", "JJJ"),
               effective_from = c(at(d[[1L]]), at(d[[22L]]), at(d[[1L]]), at(d[[30L]]), at(d[[16L]])),
               effective_to = c(at(d[[22L]]), at(NA), at(d[[30L]]), at(NA), at(NA)),
               knowledge_time = c(publish, at(d[[23L]]), publish, at(d[[29L]]), at(d[[15L]])),
               assertion = c("known_active", "known_inactive", "known_active", "known_inactive", "unknown"),
               terminal_event = c(NA, NA, NA, "delisted", NA), source = "life", stringsAsFactors = FALSE))
  facts <- ledgr::ledgr_facts(
    ledgr::ledgr_facts_sessions(sessions_df(cal, publish), "SYNTH", timezone = "UTC"),
    ledgr::ledgr_facts_membership_snapshots(membership, "U", complete = membership$complete),
    ledgr::ledgr_facts_trading_status(status),
    ledgr::ledgr_facts_lifetime(lifetime))
  list(name = "semantic", ids = ids, dates = d, bars = bars, instruments = data.frame(instrument_id = ids, stringsAsFactors = FALSE),
       facts = facts, universe = "U", counts = c(headers = length(lists), partial_headers = 1L, late_headers = 2L,
       membership_rows = nrow(membership), status_facts = nrow(status), lifetime_facts = nrow(lifetime)))
}

semantic_status_df <- function(ids, d, publish) {
  status_ids <- setdiff(ids, "aaa")
  rbind(
    data.frame(instrument_id = status_ids, effective_from = at(d[[1L]]), effective_to = at(NA), knowledge_time = publish, status = "active",
               source = "base", precedence = 0L, fact_id = paste0("base_", status_ids), supersedes_fact_id = NA_character_, stringsAsFactors = FALSE),
    data.frame(instrument_id = c("AAA", "DDD", "EEE", "EEE", "FFF", "GGG"),
               effective_from = c(at(d[[5L]]), at(d[[12L]]), at(d[[14L]]), at(d[[14L]]), at(d[[3L]]), at(d[[20L]])),
               effective_to = c(at(d[[8L]]), at(NA), at(NA), at(NA), at(d[[10L]]), at(NA)),
               knowledge_time = c(at(d[[4L]], "22:00:00"), at(d[[11L]]), at(d[[13L]]), at(d[[18L]]), at(d[[9L]]), at(d[[19L]])),
               status = c("halted", "quotation_only", "halted", "active", "halted", "quotation_only"),
               source = c("venue", "alt", "venue", "venue", "venue", "venue"), precedence = c(5L, 0L, 3L, 3L, 5L, 2L),
               fact_id = c("aaa_halt", "ddd_alt", "eee_halt", "eee_lift", "fff_halt", "ggg_quote"),
               supersedes_fact_id = c(NA, NA, NA, "eee_halt", NA, NA), stringsAsFactors = FALSE))
}

# Interval-assertion fixture (provider-only): membership intervals with
# effective_to and knowledge lags on a second universe.
interval_fixture <- function() {
  base <- semantic_fixture()
  d <- base$dates
  publish <- at(d[[1L]] - 3)
  cal <- weekday_sessions(as.Date("2021-01-04"), 30L)
  intervals <- data.frame(
    instrument_id = c("AAA", "BBB", "CCC", "CCC", "DDD", "EEE", "aaa", "bbb"),
    effective_from = c(at(d[[1L]]), at(d[[1L]]), at(d[[1L]]), at(d[[12L]]), at(d[[5L]]), at(d[[1L]]), at(d[[1L]]), at(d[[9L]])),
    effective_to = c(at(NA), at(d[[15L]]), at(d[[12L]]), at(NA), at(d[[20L]]), at(NA), at(NA), at(d[[25L]])),
    knowledge_time = c(publish, publish, publish, at(d[[14L]]), at(d[[4L]]), publish, at(d[[7L]]), at(d[[8L]])),
    member = c(TRUE, TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE), source = "synthetic_intervals", stringsAsFactors = FALSE)
  status <- semantic_status_df(base$ids, d, publish)
  facts <- ledgr::ledgr_facts(
    ledgr::ledgr_facts_sessions(sessions_df(cal, publish), "SYNTH", timezone = "UTC"),
    ledgr::ledgr_facts_membership_intervals(intervals, "V"),
    ledgr::ledgr_facts_trading_status(status))
  base$name <- "intervals"; base$facts <- facts; base$universe <- "V"
  base$counts <- c(headers = 0L, partial_headers = 0L, late_headers = 0L, membership_rows = nrow(intervals), status_facts = nrow(status), lifetime_facts = 0L)
  base
}

eventful_facts <- function() {
  E <- EVENTFUL
  ids <- sprintf("I%03d", seq_len(E$n_instruments))
  cal <- weekday_sessions(as.Date("2021-01-04"), E$n_sessions)
  d <- cal$dates
  publish <- as.POSIXct("2021-01-01 00:00:00", tz = "UTC")
  list_idx <- 1L + (seq_len(E$n_lists) - 1L) * 12L
  membership <- do.call(rbind, lapply(seq_len(E$n_lists), function(k) {
    members <- ids[((k - 1L) * E$rotate + 0:(E$n_members - 1L)) %% E$n_instruments + 1L]
    eff <- at(d[[list_idx[[k]]]])
    know <- if (k %% 4L == 0L) eff + 2 * 86400 else eff - 86400
    data.frame(instrument_id = members, effective_from = eff, knowledge_time = know, set_id = sprintf("L%02d", k),
               source = "synthetic_membership", stringsAsFactors = FALSE)
  }))
  i <- seq_len(E$n_instruments)
  base <- data.frame(instrument_id = ids, effective_from = at(d[[1L]]), effective_to = at(NA), knowledge_time = publish, status = "active",
                     source = "base", precedence = 0L, fact_id = paste0("base_", ids), supersedes_fact_id = NA_character_, stringsAsFactors = FALSE)
  halts <- do.call(rbind, lapply(0:4, function(m) {
    s <- (13L * i) %% 100L + 1L + 150L * m
    eff <- at(d[s])
    data.frame(instrument_id = ids, effective_from = eff, effective_to = eff + 3 * 86400,
               knowledge_time = ifelse(i %% 2L == 0L, eff - 86400, eff + 86400), status = "halted", source = "venue", precedence = 5L,
               fact_id = sprintf("halt_%d_%d", i, m), supersedes_fact_id = NA_character_, stringsAsFactors = FALSE)
  }))
  halts$knowledge_time <- as.POSIXct(halts$knowledge_time, origin = "1970-01-01", tz = "UTC")
  ci <- i[i %% 50L == 0L]
  s0 <- (13L * ci) %% 100L + 1L
  conflicts <- data.frame(instrument_id = ids[ci], effective_from = at(d[s0]) + 86400, effective_to = at(d[s0]) + 2 * 86400,
                          knowledge_time = at(d[s0]), status = "quotation_only", source = "alt", precedence = 5L,
                          fact_id = sprintf("conflict_%d", ci), supersedes_fact_id = NA_character_, stringsAsFactors = FALSE)
  si <- i[i %% 25L == 0L]
  supersession <- rbind(
    data.frame(instrument_id = ids[si], effective_from = at(d[[400L]]), effective_to = at(d[[410L]]), knowledge_time = at(d[[399L]]),
               status = "halted", source = "venue", precedence = 5L, fact_id = sprintf("sup_%d_a", si), supersedes_fact_id = NA_character_, stringsAsFactors = FALSE),
    data.frame(instrument_id = ids[si], effective_from = at(d[[400L]]), effective_to = at(d[[410L]]), knowledge_time = at(d[[405L]]),
               status = "active", source = "venue", precedence = 5L, fact_id = sprintf("sup_%d_b", si), supersedes_fact_id = sprintf("sup_%d_a", si), stringsAsFactors = FALSE))
  status <- rbind(base, halts, conflicts, supersession)
  li <- i[i %% 20L == 0L]
  end_s <- 600L + li %% 100L
  lifetime <- rbind(
    data.frame(instrument_id = ids[-li], effective_from = at(d[[1L]]), effective_to = at(NA), knowledge_time = publish, assertion = "known_active",
               terminal_event = NA_character_, source = "life", stringsAsFactors = FALSE),
    data.frame(instrument_id = ids[li], effective_from = at(d[[1L]]), effective_to = at(d[end_s]), knowledge_time = publish, assertion = "known_active",
               terminal_event = NA_character_, source = "life", stringsAsFactors = FALSE),
    data.frame(instrument_id = ids[li], effective_from = at(d[end_s]), effective_to = at(NA), knowledge_time = at(d[end_s]) + 86400, assertion = "known_inactive",
               terminal_event = ifelse(li %% 40L == 0L, "delisted", NA_character_), source = "life", stringsAsFactors = FALSE))
  facts <- ledgr::ledgr_facts(
    ledgr::ledgr_facts_sessions(sessions_df(cal, publish), "SYNTH", timezone = "UTC"),
    ledgr::ledgr_facts_membership_snapshots(membership, "synthetic_members", complete = TRUE),
    ledgr::ledgr_facts_trading_status(status),
    ledgr::ledgr_facts_lifetime(lifetime))
  counts <- c(headers = E$n_lists, membership_rows = nrow(membership), rotated_members = (E$n_lists - 1L) * E$rotate,
              late_headers = sum(seq_len(E$n_lists) %% 4L == 0L), status_facts = nrow(status), halts = nrow(halts),
              late_status = sum(i %% 2L == 1L) * 5L, conflict_facts = nrow(conflicts), supersession_pairs = length(si),
              lifetime_facts = nrow(lifetime), late_lifetime = length(li), terminal_events = sum(li %% 40L == 0L))
  list(ids = ids, dates = d, facts = facts, counts = counts, cutoffs = at(d, "21:00:00"), openings = at(d, "14:30:00"))
}

# ---------------------------------------------------------------------------
# Provider-only helpers.
# ---------------------------------------------------------------------------

provider_config <- function(ids, universe_id = NULL) list(
  data = list(snapshot_id = "spike"), universe = list(instrument_ids = ids),
  availability = list(active = TRUE, universe_rule = if (is.null(universe_id)) NULL else list(universe_id = universe_id),
                      execution_timing_version = 2L, valuation_policy = NULL))
history_unreachable <- function(...) stop("history() is unreachable in provider-only passes")
build_provider <- function(arm, data, config) { set_arm(arm); ledgr:::ledgr_availability_provider_build(data, config, "spike", history_unreachable) }
iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ")

open_snapshot <- function(fx, db_path) ledgr::ledgr_snapshot_from_df(fx$bars, instruments_df = fx$instruments, db_path = db_path, snapshot_id = "spike", facts = fx$facts)
snapshot_data <- function(db_path) {
  con <- DBI::dbConnect(duckdb::duckdb(), db_path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr:::ledgr_availability_provider_data(con, "spike")
}

# Shuffled and repeated cutoffs: closes, openings, midnights, and every fact
# boundary plus or minus one second, in two seeded orders with revisits.
parity_cutoffs <- function(fx, data) {
  boundaries <- unlist(lapply(list(data$membership_sets, data$membership, data$status, data$lifetime), function(t) {
    if (!is.data.frame(t) || nrow(t) == 0L) return(numeric())
    as.numeric(as.POSIXct(c(t$effective_from, t$knowledge_time, t$effective_to), tz = "UTC"))
  }))
  boundaries <- unique(boundaries[!is.na(boundaries)])
  base <- unique(c(as.numeric(at(fx$dates, "21:00:00")), as.numeric(at(fx$dates, "14:30:00")), as.numeric(at(fx$dates)), boundaries - 1, boundaries, boundaries + 1))
  set.seed(20260915L)
  order1 <- sample(base); order2 <- sample(base); revisit <- sample(base, 25L)
  as.POSIXct(c(order1, order2, revisit), origin = "1970-01-01", tz = "UTC")
}

parity_phase <- function(evidence) {
  rows <- list()
  for (fx in list(semantic_fixture(), interval_fixture())) {
    db <- tempfile(paste0("spike_parity_", fx$name, "_"), fileext = ".duckdb")
    snapshot <- open_snapshot(fx, db)
    data <- snapshot_data(db)
    configs <- list(membership = provider_config(fx$ids, fx$universe))
    if (identical(fx$name, "semantic")) configs$fixed <- provider_config(fx$ids)
    cutoffs <- parity_cutoffs(fx, data)
    held <- stats::setNames(numeric(length(fx$ids)), fx$ids); held[c("BBB", "LLL", "CCC", "aaa")] <- c(5, 3, 2, 1)
    zero <- stats::setNames(numeric(length(fx$ids)), fx$ids)
    exec_ids <- c("AAA", "BBB", "LLL", "aaa", "III")
    for (cfg_name in names(configs)) {
      cfg <- configs[[cfg_name]]
      providers <- lapply(ARMS, function(arm) { p <- build_provider(arm, data, cfg); list(provider = p, observed = attr(p, "spike_arm") %||% NA_character_) })
      names(providers) <- ARMS
      first_seen <- new.env()
      for (k in seq_along(cutoffs)) {
        cutoff <- cutoffs[[k]]
        for (kind in c("decision_zero", "decision_held", "execution", "facts")) {
          call_view <- function(p) switch(kind,
            decision_zero = p$decision_view(cutoff, zero), decision_held = p$decision_view(cutoff, held),
            execution = p$execution_view(cutoff, exec_ids), facts = p$facts(cutoff))
          cur <- call_view(providers$current$provider); prep <- call_view(providers$prepared$provider)
          key <- paste(kind, as.numeric(cutoff))
          consistent <- if (exists(key, envir = first_seen, inherits = FALSE)) identical(get(key, envir = first_seen), prep) else { assign(key, prep, envir = first_seen); NA }
          resolve_matches <- NA
          if (identical(kind, "decision_zero") && identical(cfg_name, "membership")) {
            resolved <- ledgr::ledgr_facts_resolve(snapshot, "membership", fx$universe, at = cutoff)
            resolve_matches <- identical(ledgr:::ledgr_availability_stable_ids(as.character(resolved$rows$instrument_id[resolved$rows$member %in% TRUE])), prep$members)
          }
          rows[[length(rows) + 1L]] <- data.frame(fixture = fx$name, config = cfg_name, order_index = k, cutoff = iso(cutoff), kind = kind,
            identical_between_arms = identical(cur, prep), prepared_consistent_on_revisit = consistent, resolve_matches_prepared_members = resolve_matches,
            observed_current = providers$current$observed, observed_prepared = providers$prepared$observed, stringsAsFactors = FALSE)
        }
      }
    }
    ledgr::ledgr_snapshot_close(snapshot); unlink(c(db, paste0(db, ".wal")), force = TRUE)
  }
  df <- do.call(rbind, rows)
  utils::write.csv(df, file.path(evidence, "cutoff_parity.csv"), row.names = FALSE)
  cat(sprintf("parity: %d queries, identical %d, revisits consistent %d/%d, resolve matches %d/%d\n", nrow(df), sum(df$identical_between_arms),
              sum(df$prepared_consistent_on_revisit, na.rm = TRUE), sum(!is.na(df$prepared_consistent_on_revisit)),
              sum(df$resolve_matches_prepared_members, na.rm = TRUE), sum(!is.na(df$resolve_matches_prepared_members))))
  invisible(df)
}

# ---------------------------------------------------------------------------
# Fold scenarios on the semantic fixture (both arms, fresh store per run).
# ---------------------------------------------------------------------------

# One strategy source: members get a growing target, restricted IDs hold,
# unrestricted held nonmembers halve each pulse; injections through options.
semantic_strategy <- function(ctx, params) {
  if (identical(ctx$ts_utc, getOption("ledgr.spike.interrupt_at", ""))) options(ledgr.interrupt = TRUE)
  if (identical(ctx$ts_utc, getOption("ledgr.spike.fail_at", ""))) stop("injected fold failure")
  target <- ctx$hold()
  k <- as.integer(substr(ctx$ts_utc, 9L, 10L)) + 31L * (as.integer(substr(ctx$ts_utc, 6L, 7L)) - 1L)
  member <- ctx$vec$member; restricted <- ctx$vec$target_restricted; pos <- ctx$vec$positions
  grow <- member & !restricted
  target[grow] <- 10 + k %/% 3
  reduce <- !member & !restricted & pos != 0
  target[reduce] <- floor(pos[reduce] / 2)
  increase_at <- getOption("ledgr.spike.increase_nonmember_at", "")
  if (nzchar(increase_at) && ctx$ts_utc >= increase_at && any(!member & pos != 0)) {
    j <- which(!member & pos != 0)[[1L]]; target[j] <- pos[j] + 1
  }
  exit_from <- getOption("ledgr.spike.exit_iii_from", "")
  if (nzchar(exit_from) && ctx$ts_utc >= exit_from && "III" %in% names(target)) target[["III"]] <- 0
  target
}

experiment_for <- function(snapshot, universe_id) ledgr::ledgr_experiment(snapshot, semantic_strategy,
  universe = ledgr::ledgr_universe_members(universe_id), valuation_policy = ledgr::ledgr_valuation_stale(max_sessions = 2L),
  cost_model = ledgr::ledgr_cost_zero(), opening = ledgr::ledgr_opening(cash = 1e6))

read_store <- function(db_path, run_id) {
  con <- DBI::dbConnect(duckdb::duckdb(), db_path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  q <- function(sql) DBI::dbGetQuery(con, sql, params = list(run_id))
  identity <- q("SELECT * FROM runs WHERE run_id = ?")
  list(status = identity$status, identity = normalize_identity(identity),
       diagnostics = q("SELECT * FROM run_diagnostics WHERE run_id = ? ORDER BY diagnostic_seq"),
       events = q("SELECT * FROM ledger_events WHERE run_id = ? ORDER BY event_seq"),
       equity = q("SELECT * FROM equity_curve WHERE run_id = ? ORDER BY ts_utc"),
       state = q("SELECT * FROM strategy_state WHERE run_id = ? ORDER BY ts_utc"),
       completion = q("SELECT * FROM run_completion WHERE run_id = ?"))
}
run_invocation <- function(exp, run_id) {
  bt <- NULL
  err <- tryCatch({ bt <- ledgr::ledgr_run(exp, run_id = run_id); NA_character_ }, error = function(e) paste(class(e)[[1L]], conditionMessage(e), sep = ": "))
  session <- if (!is.null(bt)) as.data.frame(ledgr::ledgr_results(bt, "diagnostics")) else NULL
  if (!is.null(bt)) close(bt)
  list(error = err, session_diagnostics = session, observed = take_observed())
}
reopen_read <- function(arm, db, run_id, cells) {
  set_arm(arm); take_observed()
  snap <- ledgr::ledgr_snapshot_open(db, "spike", verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snap), add = TRUE)
  out <- list(error = NA_character_)
  bt <- tryCatch(ledgr::ledgr_run_open(snap, run_id), error = function(e) { out$error <<- paste(class(e)[[1L]], conditionMessage(e), sep = ": "); NULL })
  if (!is.null(bt)) {
    out$diagnostics <- as.data.frame(ledgr::ledgr_results(bt, "diagnostics"))
    out$availability <- as.data.frame(ledgr::ledgr_results(bt, "availability"))
    out$explained <- do.call(rbind, lapply(seq_len(nrow(cells)), function(i) as.data.frame(ledgr::ledgr_run_explain(bt, cells$instrument_id[[i]], cells$ts_utc[[i]]))))
    close(bt)
  }
  out$observed <- take_observed()
  out
}
strip_id <- function(df) { if (is.data.frame(df)) { df$run_id <- NULL; attr(df, "ledgr_result_type") <- NULL }; df }
same <- function(a, b) if (is.null(a) || is.null(b)) NA else identical(strip_id(a), strip_id(b))
seq_ok <- function(d) identical(as.integer(d$diagnostic_seq), seq_len(nrow(d)))
pulse_iso <- function(fx, i) iso(at(fx$dates[[i]], "21:00:00"))

run_case <- function(arm, fx, run_id, interrupt_at = NULL, fail_at = NULL, increase_at = NULL, resume_fail_at = NULL, exit_iii_from = NULL) {
  set_arm(arm); take_observed()
  prior <- options(ledgr.interrupt = FALSE, ledgr.spike.interrupt_at = interrupt_at %||% "", ledgr.spike.fail_at = fail_at %||% "",
                   ledgr.spike.increase_nonmember_at = increase_at %||% "", ledgr.spike.exit_iii_from = exit_iii_from %||% "")
  on.exit(options(prior), add = TRUE)
  db <- tempfile(paste0("spike_", arm, "_"), fileext = ".duckdb")
  snapshot <- open_snapshot(fx, db)
  exp <- experiment_for(snapshot, fx$universe)
  first <- run_invocation(exp, run_id)
  after_first <- read_store(db, run_id)
  resume <- list(error = NA_character_, session_diagnostics = NULL, observed = "")
  resumed <- NULL
  if (!is.null(interrupt_at)) {
    options(ledgr.interrupt = FALSE, ledgr.spike.interrupt_at = "", ledgr.spike.fail_at = resume_fail_at %||% "")
    resume <- run_invocation(exp, run_id)
    resumed <- read_store(db, run_id)
  }
  final <- resumed %||% after_first
  session_diagnostics <- if (!is.null(interrupt_at)) resume$session_diagnostics else first$session_diagnostics
  ledgr::ledgr_snapshot_close(snapshot)
  reopened <- list()
  if (final$status %in% c("DONE", "INCOMPLETE")) {
    cells <- final$diagnostics[final$diagnostics$stage == "decision", , drop = FALSE]
    cells <- cells[unique(round(seq(1L, nrow(cells), length.out = 3L))), , drop = FALSE]
    for (reopen_arm in ARMS) reopened[[reopen_arm]] <- reopen_read(reopen_arm, db, run_id, cells)
  }
  unlink(c(db, paste0(db, ".wal")), force = TRUE)
  list(arm = arm, run_id = run_id, first_error = first$error, after_first = after_first, resume_error = resume$error, final = final,
       session_diagnostics = session_diagnostics, reopened = reopened, observed_run = paste(unique(c(first$observed, resume$observed)[nzchar(c(first$observed, resume$observed))]), collapse = "|"))
}

semantic_phase <- function(evidence) {
  fx <- semantic_fixture()
  scenarios <- list(
    list(id = "S1_direct"),
    list(id = "S2_interrupt_resume", interrupt = 13L),
    list(id = "S3_exception_rollback", fail = 17L),
    list(id = "S4_nonmember_increase_rollback", increase = 12L),
    list(id = "S5_resume_then_exception", interrupt = 8L, resume_fail = 20L),
    list(id = "S6_exit_before_terminal_direct", exit = 27L),
    list(id = "S7_exit_before_terminal_resume", interrupt = 13L, exit = 27L)
  )
  results <- list()
  for (sc in scenarios) for (arm in ARMS) {
    cat(sprintf("scenario %-32s arm %-9s ... ", sc$id, arm)); t0 <- proc.time()[["elapsed"]]
    r <- run_case(arm, fx, run_id = paste0("spike-", sc$id), interrupt_at = if (!is.null(sc$interrupt)) pulse_iso(fx, sc$interrupt),
                  fail_at = if (!is.null(sc$fail)) pulse_iso(fx, sc$fail), increase_at = if (!is.null(sc$increase)) pulse_iso(fx, sc$increase),
                  resume_fail_at = if (!is.null(sc$resume_fail)) pulse_iso(fx, sc$resume_fail), exit_iii_from = if (!is.null(sc$exit)) pulse_iso(fx, sc$exit))
    results[[paste(sc$id, arm)]] <- r
    cat(sprintf("%.1f s status %s rows %d observed %s\n", proc.time()[["elapsed"]] - t0, r$final$status, nrow(r$final$diagnostics), r$observed_run))
  }
  direct <- results[["S1_direct current"]]$final
  rows <- lapply(names(results), function(nm) {
    r <- results[[nm]]; sc_id <- sub(" .*$", "", nm); arm <- sub("^.* ", "", nm); f <- r$final
    peer <- results[[paste(sc_id, "current")]]
    direct_peer <- if (grepl("^S6|^S7", sc_id)) results[["S6_exit_before_terminal_direct current"]]$final else direct
    ro <- r$reopened; po <- peer$reopened
    data.frame(scenario = sc_id, selected_arm = arm, observed_arm_run = r$observed_run,
      observed_arm_reopen_current = ro$current$observed %||% NA_character_, observed_arm_reopen_prepared = ro$prepared$observed %||% NA_character_,
      reopen_error_current = ro$current$error %||% NA_character_, reopen_error_prepared = ro$prepared$error %||% NA_character_,
      first_status = r$after_first$status, final_status = f$status, first_error = r$first_error, resume_error = r$resume_error,
      diagnostic_rows = nrow(f$diagnostics), decision_rows = sum(f$diagnostics$stage == "decision"), execution_rows = sum(f$diagnostics$stage == "execution"),
      error_rows = sum(f$diagnostics$outcome == "error"), event_rows = nrow(f$events), fill_events = sum(f$events$event_type == "FILL"),
      equity_rows = nrow(f$equity), completion_rows = nrow(f$completion), seq_continuous = seq_ok(f$diagnostics),
      diagnostics_identical_to_direct = same(f$diagnostics, direct_peer$diagnostics), diagnostics_identical_to_current_arm = same(f$diagnostics, peer$final$diagnostics),
      events_identical_to_current_arm = same(f$events, peer$final$events), equity_identical_to_current_arm = same(f$equity, peer$final$equity),
      state_identical_to_current_arm = same(f$state, peer$final$state), completion_identical_to_current_arm = same(f$completion, peer$final$completion),
      identity_identical_to_current_arm = same(f$identity, peer$final$identity),
      session_reader_matches_store = same(r$session_diagnostics, f$diagnostics),
      reopen_same_arm_matches_session = same(ro[[arm]]$diagnostics, r$session_diagnostics),
      availability_reopen_arms_identical = same(ro$current$availability, ro$prepared$availability),
      explain_reopen_arms_identical = same(ro$current$explained, ro$prepared$explained),
      availability_identical_to_current_arm = same(ro[[arm]]$availability, po$current$availability),
      explain_identical_to_current_arm = same(ro[[arm]]$explained, po$current$explained),
      stringsAsFactors = FALSE)
  })
  cases_df <- do.call(rbind, rows); rownames(cases_df) <- NULL
  utils::write.csv(cases_df, file.path(evidence, "cases.csv"), row.names = FALSE)
  ref <- direct$diagnostics
  for (nm in c("ts_utc", "decision_ts_utc", "execution_ts_utc")) ref[[nm]] <- iso(ref[[nm]])
  utils::write.csv(ref, file.path(evidence, "diagnostics_reference.csv"), row.names = FALSE)
  print(cases_df[, c("scenario", "selected_arm", "observed_arm_run", "final_status", "diagnostic_rows", "execution_rows", "fill_events", "seq_continuous",
                     "diagnostics_identical_to_direct", "diagnostics_identical_to_current_arm", "equity_identical_to_current_arm",
                     "availability_reopen_arms_identical", "explain_reopen_arms_identical")], row.names = FALSE)
  invisible(cases_df)
}

# ---------------------------------------------------------------------------
# Child processes: regression tests, provider-only passes, 757-pulse folds.
# ---------------------------------------------------------------------------

rscript_path <- function() { p <- file.path(R.home("bin"), c("Rscript.exe", "x64/Rscript.exe", "Rscript")); p[file.exists(p)][[1L]] }
load_package <- function() { options(keep.source = TRUE, keep.source.pkgs = TRUE, warn = 1); pkgload::load_all(repo_root, quiet = TRUE, export_all = TRUE) }
environment_row <- function() data.frame(r = R.version.string, collapse = as.character(utils::packageVersion("collapse")),
  duckdb = as.character(utils::packageVersion("duckdb")), testthat = as.character(utils::packageVersion("testthat")),
  lib = normalizePath(SPIKE_LIB, winslash = "/", mustWork = FALSE), stringsAsFactors = FALSE)

child_tests <- function(arm, out) {
  load_package(); set_arm(arm); install_arm_observer()
  res <- as.data.frame(testthat::test_local(repo_root, filter = "^availability", reporter = "silent", stop_on_failure = FALSE, load_package = "none"))
  res <- res[, c("file", "test", "nb", "failed", "skipped", "error", "warning", "passed")]
  yyjsonr::write_json_file(list(arm = arm, observed = take_observed(), results = res, collapse = environment_row()$collapse,
                                mirai_available = requireNamespace("mirai", quietly = TRUE)), out)
}

child_provider <- function(facts_name, out) {
  load_package()
  fx <- if (identical(facts_name, "static")) registered_fold_fixture()$fixture else eventful_facts()
  cutoffs <- if (identical(facts_name, "static")) at(fx$session_dates, "21:00:00") else fx$cutoffs
  openings <- (if (identical(facts_name, "static")) at(fx$session_dates, "14:30:00") else fx$openings)[round(seq(2L, length(cutoffs), length.out = EXEC_SAMPLE_OPENINGS))]
  ids <- if (identical(facts_name, "static")) as.character(fx$instruments$instrument_id) else fx$ids
  data <- ledgr:::ledgr_facts_inspection_data(fx$facts)
  config <- provider_config(ids, "synthetic_members")
  zero <- stats::setNames(numeric(length(ids)), ids)
  views <- list(); rows <- list()
  for (arm in ARMS) {
    invisible(gc(full = TRUE))
    t0 <- proc.time()[["elapsed"]]; provider <- build_provider(arm, data, config); t_build <- proc.time()[["elapsed"]] - t0
    t0 <- proc.time()[["elapsed"]]; dv <- lapply(cutoffs, function(c) provider$decision_view(c, zero)); t_decision <- proc.time()[["elapsed"]] - t0
    t0 <- proc.time()[["elapsed"]]; ev <- lapply(openings, function(c) provider$execution_view(c, EXEC_SAMPLE_IDS)); t_exec <- proc.time()[["elapsed"]] - t0
    views[[arm]] <- list(dv = dv, ev = ev)
    rows[[arm]] <- data.frame(facts = facts_name, arm = arm, observed_arm = attr(provider, "spike_arm") %||% NA_character_, build_seconds = t_build,
      decision_views = length(cutoffs), decision_seconds = t_decision, execution_calls = length(openings), execution_seconds = t_exec,
      pass_seconds = t_build + t_decision + t_exec, axis_width_min = min(lengths(lapply(dv, `[[`, "axis"))), axis_width_max = max(lengths(lapply(dv, `[[`, "axis"))),
      stringsAsFactors = FALSE)
    cat(sprintf("provider %-8s %-8s build %.2f decision %.2f exec %.2f\n", facts_name, arm, t_build, t_decision, t_exec))
  }
  dv_identical <- sum(mapply(identical, views$current$dv, views$prepared$dv))
  ev_identical <- sum(mapply(identical, views$current$ev, views$prepared$ev))
  df <- do.call(rbind, rows); df$decision_views_identical <- dv_identical; df$execution_views_identical <- ev_identical
  df$collapse <- environment_row()$collapse
  yyjsonr::write_json_file(df, out)
}

sampler_ps1 <- '
param([string]$Exe, [string]$ChildArgsJoined, [string]$Marker, [double]$WallCeilingS, [double]$WsCeilingMiB, [int]$IntervalMs = 200)
$childArgs = $ChildArgsJoined.Split("|")
$p = Start-Process -FilePath $Exe -ArgumentList $childArgs -PassThru -NoNewWindow
$null = $p.Handle
$peak = 0; $killed = ""; $runStart = $null
while (-not $p.HasExited) {
  try { $p.Refresh(); $ws = $p.WorkingSet64; $pk = $p.PeakWorkingSet64; if ($pk -gt $peak) { $peak = $pk }
        if ($null -eq $runStart -and (Test-Path $Marker)) { $runStart = Get-Date }
        if ($WsCeilingMiB -gt 0 -and ($ws / 1MB) -gt $WsCeilingMiB) { $killed = "working_set"; $p.Kill() }
        if ($WallCeilingS -gt 0 -and $null -ne $runStart -and ((Get-Date) - $runStart).TotalSeconds -gt $WallCeilingS) { $killed = "wall"; $p.Kill() }
  } catch {}
  Start-Sleep -Milliseconds $IntervalMs
}
$p.WaitForExit()
$elapsedRun = if ($null -ne $runStart) { ((Get-Date) - $runStart).TotalSeconds } else { -1 }
Write-Output ("PEAK_WS_BYTES=" + $peak)
Write-Output ("KILLED=" + $killed)
Write-Output ("RUN_ELAPSED_S=" + $elapsedRun)
Write-Output ("CHILD_EXIT=" + $p.ExitCode)
'

launch_child <- function(child_args, wall_ceiling = 0, ws_ceiling = 0, marker = tempfile("spike_marker_")) {
  ps1 <- tempfile("ws_sampler_", fileext = ".ps1"); writeLines(sampler_ps1, ps1)
  on.exit(unlink(c(ps1, marker), force = TRUE), add = TRUE)
  out <- system2("powershell", c("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", shQuote(ps1), "-Exe", shQuote(rscript_path()),
                                 "-ChildArgsJoined", shQuote(paste(c(script_path, child_args), collapse = "|")), "-Marker", shQuote(marker),
                                 "-WallCeilingS", format(wall_ceiling), "-WsCeilingMiB", format(ws_ceiling), "-IntervalMs", "200"), stdout = TRUE, stderr = TRUE)
  grab <- function(key) sub(paste0("^", key, "="), "", grep(paste0("^", key, "="), out, value = TRUE))[1L]
  list(out = out, killed = grab("KILLED"), exit = as.numeric(grab("CHILD_EXIT")), run_elapsed_s = as.numeric(grab("RUN_ELAPSED_S")),
       peak_ws_mib = as.numeric(grab("PEAK_WS_BYTES")) / 1024^2)
}
run_child_json <- function(child_args, ...) {
  res <- tempfile("spike_child_", fileext = ".json"); on.exit(unlink(res, force = TRUE), add = TRUE)
  r <- launch_child(c(child_args, res), ...)
  result <- if (file.exists(res)) yyjsonr::read_json_file(res) else NULL
  if (is.null(result) && !nzchar(r$killed %||% "")) { cat(r$out, sep = "\n"); stop(sprintf("child failed (exit %s): %s", r$exit, paste(child_args, collapse = " "))) }
  c(r, list(result = result))
}

child_fold <- function(arm, template_db, run_db, run_id, marker, out, prof = NULL) {
  load_package(); set_arm(arm); install_arm_observer()
  file.copy(template_db, run_db, overwrite = TRUE)
  reg <- registered_fold_fixture()
  snapshot <- ledgr::ledgr_snapshot_open(run_db, "spike", verify = TRUE)
  exp <- ledgr::ledgr_experiment(snapshot, function(ctx, params) ctx$flat(), universe = ledgr::ledgr_universe_members("synthetic_members"),
    valuation_policy = ledgr::ledgr_valuation_stale(max_sessions = 2L), cost_model = ledgr::ledgr_cost_zero(), opening = ledgr::ledgr_opening(cash = 1e6))
  invisible(gc(full = TRUE))
  if (!is.null(prof)) Rprof(prof, interval = 0.02, memory.profiling = TRUE, line.profiling = TRUE, gc.profiling = TRUE)
  writeLines(format(Sys.time()), marker)
  t0 <- proc.time()[["elapsed"]]
  bt <- ledgr::ledgr_run(exp, run_id = run_id)
  wall <- proc.time()[["elapsed"]] - t0
  if (!is.null(prof)) Rprof(NULL)
  info <- ledgr::ledgr_run_info(snapshot, run_id)
  telemetry <- ledgr:::ledgr_get_run_telemetry(run_id)
  diagnostics <- ledgr::ledgr_results(bt, "diagnostics")
  lanes <- if (!is.null(prof)) parse_rprof(prof) else NULL
  result <- list(arm = arm, observed_arm = take_observed(), run_id = run_id, wall_seconds = wall, t_loop_seconds = as.numeric(telemetry$t_loop %||% NA_real_),
                 status = as.character(info$status), decision_rows = sum(diagnostics$stage == "decision"), execution_rows = sum(diagnostics$stage == "execution"),
                 diagnostic_rows = nrow(diagnostics), collapse = environment_row()$collapse, lanes = lanes)
  yyjsonr::write_json_file(result, out, auto_unbox = TRUE)
  close(bt); ledgr::ledgr_snapshot_close(snapshot)
  cat("child_ok", arm, run_id, round(wall, 2), "\n")
}

# Lane classifier: the writer spike's classifier plus the prepared provider's
# closures and a build lane for provider construction outside the loop.
classify_sample <- function(fns) {
  has <- function(x) any(x %in% fns)
  if (has(c("ledgr_availability_provider_build", "ledgr_availability_provider_build_prepared", "ledgr_availability_provider_build_current",
            "ledgr_availability_prepared_membership", "ledgr_availability_prepared_segments"))) return("provider_build")
  if (!has("run_transaction")) return("outside_loop")
  if (has(c("ledgr_membership_resolve_at", "ledgr_availability_members_at", "prepared_members_at", "members_at"))) return("provider_membership")
  if (has(c("ledgr_availability_status_at", "ledgr_availability_lifetime_at", "ledgr_availability_terminal_event_at", "ledgr_availability_restrictions",
            "prepared_facts", "prepared_seek", "prepared_read", "facts", "seek", "read"))) return("provider_status_lifetime")
  if (has("ledgr_availability_valuation_marks")) return("valuation")
  if (has(c("write_run_diagnostics", "write_run_evidence"))) return("duckdb_diag_append")
  if (has("append_diagnostic")) return(if (has(c("ledgr_availability_diagnostic_row", "ledgr_availability_diagnostic_fields", "diag_row"))) "diag_construct" else "diag_append_retain")
  if (has("append_decision_trace")) return("diag_construct")
  if (has(c("rbind", "rbind.data.frame", "drain", "build")) && !has("flush_pending")) return("final_bind")
  if (has(c("decision_view", "execution_view"))) return("provider_other")
  "residual_fold"
}
LANES <- c("provider_build", "provider_membership", "provider_status_lifetime", "provider_other", "valuation", "diag_construct",
           "diag_append_retain", "final_bind", "duckdb_diag_append", "residual_fold", "outside_loop")
parse_rprof <- function(path) {
  lines <- readLines(path, warn = FALSE)
  interval_us <- as.numeric(sub(".*sample.interval=", "", lines[[1L]]))
  samples <- lines[startsWith(lines, ":")]
  prefix_re <- "^:[0-9]+:[0-9]+:[0-9]+:[0-9]+:"
  tokens <- strsplit(trimws(sub(prefix_re, "", samples)), " +")
  fns <- lapply(tokens, function(t) sub("^.*[$:]", "", gsub('"', "", t[startsWith(t, '"')], fixed = TRUE)))
  lane <- vapply(fns, classify_sample, character(1))
  per_lane <- do.call(rbind, lapply(LANES, function(l) { s <- lane == l
    data.frame(lane = l, samples = sum(s), seconds = sum(s) * interval_us / 1e6, stringsAsFactors = FALSE) }))
  list(interval_us = interval_us, n_samples = length(samples), in_loop_samples = sum(!lane %in% c("outside_loop", "provider_build")), lanes = per_lane)
}

# ---------------------------------------------------------------------------
# Parent phases.
# ---------------------------------------------------------------------------

tests_phase <- function(evidence) {
  rows <- list()
  for (arm in ARMS) {
    cat(sprintf("regression tests under %s ...\n", arm))
    r <- run_child_json(c("--child-tests", arm))
    res <- as.data.frame(r$result$results)
    res$arm <- arm; res$observed_arm <- r$result$observed; res$mirai_available <- isTRUE(r$result$mirai_available)
    rows[[arm]] <- res
    cat(sprintf("  %d tests, %d failed, %d errored, %d skipped; observed arm %s; mirai %s\n", nrow(res), sum(res$failed > 0), sum(res$error), sum(res$skipped),
                r$result$observed, r$result$mirai_available))
  }
  df <- do.call(rbind, rows); rownames(df) <- NULL
  optional <- df$test %in% OPTIONAL_TESTS
  deterministic <- df[!optional, c("arm", "observed_arm", "file", "test", "nb", "failed", "skipped", "error", "warning", "passed")]
  utils::write.csv(deterministic, file.path(evidence, "regression_tests.csv"), row.names = FALSE)
  opt <- df[optional, , drop = FALSE]
  opt$ran <- !opt$skipped
  utils::write.csv(opt[, c("arm", "observed_arm", "file", "test", "mirai_available", "ran", "nb", "failed", "skipped", "error", "passed")],
                   file.path(evidence, "regression_optional.csv"), row.names = FALSE)
  invisible(df)
}

# Persisted-output parity between two run stores holding the same run ID:
# DuckDB multiset difference per table with run_id (and, for the identity row,
# creation time) excluded. Direct row comparison, no hash ledger.
compare_stores <- function(db_current, db_prepared, run_id) {
  con <- DBI::dbConnect(duckdb::duckdb(), ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(con, sprintf("ATTACH '%s' AS cur (READ_ONLY)", db_current))
  DBI::dbExecute(con, sprintf("ATTACH '%s' AS prep (READ_ONLY)", db_prepared))
  tables <- list(run_completion = "run_id", run_diagnostics = "run_id", ledger_events = "run_id", equity_curve = "run_id", strategy_state = "run_id")
  # The identity row is compared in R after the same normalisation the
  # scenarios use (local run ID, creation time, and config locators dropped).
  ident <- lapply(c("cur", "prep"), function(db) normalize_identity(DBI::dbGetQuery(con, sprintf("SELECT * FROM %s.runs WHERE run_id = ?", db), params = list(run_id))))
  same_identity <- nrow(ident[[1L]]) == 1L && nrow(ident[[2L]]) == 1L && identical(ident[[1L]], ident[[2L]])
  runs_row <- data.frame(table = "runs", columns_compared = ncol(ident[[1L]]), excluded = paste(c(IDENTITY_EXCLUDED, paste0("config_json.", IDENTITY_JSON_EXCLUDED)), collapse = "|"),
                         rows_current = nrow(ident[[1L]]), rows_prepared = nrow(ident[[2L]]), only_in_current = as.integer(!same_identity), only_in_prepared = as.integer(!same_identity),
                         identical = same_identity, stringsAsFactors = FALSE)
  rbind(runs_row, do.call(rbind, lapply(names(tables), function(t) {
    cols <- DBI::dbGetQuery(con, "SELECT column_name FROM duckdb_columns() WHERE database_name = 'cur' AND table_name = ? ORDER BY column_index", params = list(t))$column_name
    cols <- setdiff(cols, tables[[t]])
    sel <- paste(sprintf('"%s"', cols), collapse = ", ")
    n <- function(db) DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM %s.%s WHERE run_id = ?", db, t), params = list(run_id))$n
    only <- function(a, b) DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM (SELECT %s FROM %s.%s WHERE run_id = ? EXCEPT ALL SELECT %s FROM %s.%s WHERE run_id = ?)",
                                                        sel, a, t, sel, b, t), params = list(run_id, run_id))$n
    rc <- n("cur"); rp <- n("prep"); oc <- only("cur", "prep"); op <- only("prep", "cur")
    data.frame(table = t, columns_compared = length(cols), excluded = paste(tables[[t]], collapse = "|"), rows_current = rc, rows_prepared = rp,
               only_in_current = oc, only_in_prepared = op, identical = rc == rp && oc == 0L && op == 0L, stringsAsFactors = FALSE)
  })))
}

seal_template <- function() {
  template <- tempfile("spike_template_", fileext = ".duckdb")
  cat("sealing the registered 757-pulse store once ...\n"); t0 <- proc.time()[["elapsed"]]
  snapshot <- open_snapshot(registered_fold_fixture()$fixture, template); ledgr::ledgr_snapshot_close(snapshot)
  cat(sprintf("  sealed in %.0f s\n", proc.time()[["elapsed"]] - t0))
  template
}

# One explicitly non-measured 757-pulse pair whose stores are kept until their
# persisted outputs and identity rows have been compared (evidence review M2).
fold757parity_phase <- function(evidence) {
  template <- seal_template()
  on.exit(unlink(c(template, paste0(template, ".wal")), force = TRUE), add = TRUE)
  run_id <- "spike-757-parity"
  dbs <- list(); meta <- list()
  for (arm in ARMS) {
    run_db <- tempfile(paste0("spike_parity_", arm, "_"), fileext = ".duckdb"); marker <- tempfile("spike_marker_")
    cat(sprintf("fold757parity %-9s (not measured) ...\n", arm))
    r <- run_child_json(c("--child-fold", arm, template, run_db, run_id, marker), wall_ceiling = WALL_STOP_S, ws_ceiling = WS_STOP_MIB, marker = marker)
    dbs[[arm]] <- run_db
    meta[[arm]] <- list(status = r$result$status %||% NA_character_, observed_arm = r$result$observed_arm %||% NA_character_, killed = r$killed %||% "")
    cat(sprintf("  status %s observed %s killed='%s'\n", meta[[arm]]$status, meta[[arm]]$observed_arm, meta[[arm]]$killed))
  }
  on.exit(unlink(c(unlist(dbs), paste0(unlist(dbs), ".wal")), force = TRUE), add = TRUE)
  df <- compare_stores(dbs$current, dbs$prepared, run_id)
  df$run_id <- run_id; df$status_current <- meta$current$status; df$status_prepared <- meta$prepared$status
  df$observed_arm_current <- meta$current$observed_arm; df$observed_arm_prepared <- meta$prepared$observed_arm
  utils::write.csv(df, file.path(evidence, "fold_757_parity.csv"), row.names = FALSE)
  print(df[, c("table", "columns_compared", "excluded", "rows_current", "rows_prepared", "only_in_current", "only_in_prepared", "identical")], row.names = FALSE)
  invisible(df)
}

provider757_phase <- function(evidence) {
  rows <- list()
  for (facts_name in c("static", "eventful")) {
    cat(sprintf("provider-only pass on %s facts ...\n", facts_name))
    r <- run_child_json(c("--child-provider", facts_name))
    rows[[facts_name]] <- cbind(as.data.frame(r$result), child_peak_ws_mib = r$peak_ws_mib)
  }
  df <- do.call(rbind, rows); rownames(df) <- NULL
  utils::write.csv(df, file.path(evidence, "provider_pass.csv"), row.names = FALSE)
  print(df, row.names = FALSE)
  invisible(df)
}

fold757_phase <- function(evidence) {
  template <- seal_template()
  on.exit(unlink(c(template, paste0(template, ".wal")), force = TRUE), add = TRUE)
  runs <- list(list(arm = "current", rep = "run1", profile = FALSE),
               list(arm = "prepared", rep = "warmup", profile = FALSE), list(arm = "prepared", rep = "run1", profile = FALSE),
               list(arm = "prepared", rep = "run2", profile = FALSE), list(arm = "prepared", rep = "run3", profile = FALSE),
               list(arm = "prepared", rep = "profiled", profile = TRUE))
  rows <- list(); lanes <- NULL
  for (rn in runs) {
    run_db <- tempfile("spike_fold_", fileext = ".duckdb"); marker <- tempfile("spike_marker_"); prof <- tempfile("spike_prof_", fileext = ".prof")
    run_id <- paste0("spike-757-", rn$arm, "-", rn$rep)
    cat(sprintf("fold757 %-9s %-9s ...\n", rn$arm, rn$rep))
    r <- run_child_json(c("--child-fold", rn$arm, template, run_db, run_id, marker, if (rn$profile) prof), wall_ceiling = WALL_STOP_S, ws_ceiling = WS_STOP_MIB, marker = marker)
    x <- r$result
    store <- if (file.exists(run_db)) tryCatch(read_store(run_db, run_id), error = function(e) NULL) else NULL
    rows[[length(rows) + 1L]] <- data.frame(arm = rn$arm, repetition = rn$rep, measured = rn$rep %in% c("run1", "run2", "run3"), profiled = rn$profile,
      killed = r$killed %||% "", run_elapsed_s = r$run_elapsed_s, wall_seconds = x$wall_seconds %||% NA_real_, t_loop_seconds = x$t_loop_seconds %||% NA_real_,
      peak_ws_mib = r$peak_ws_mib, status = x$status %||% (store$status %||% NA_character_), store_diagnostic_rows = if (is.null(store)) NA_integer_ else nrow(store$diagnostics),
      decision_rows = x$decision_rows %||% NA_integer_, observed_arm = x$observed_arm %||% NA_character_, collapse = x$collapse %||% NA_character_,
      within_stop = !nzchar(r$killed %||% ""), stringsAsFactors = FALSE)
    if (!is.null(x$lanes)) lanes <- x$lanes
    unlink(c(run_db, paste0(run_db, ".wal"), prof), force = TRUE)
    cat(sprintf("  killed='%s' wall %.1f s  t_loop %.1f s  peak WS %.1f MiB  status %s  observed %s\n", r$killed %||% "", x$wall_seconds %||% NA_real_,
                x$t_loop_seconds %||% NA_real_, r$peak_ws_mib, x$status %||% NA_character_, x$observed_arm %||% NA_character_))
  }
  df <- do.call(rbind, rows); utils::write.csv(df, file.path(evidence, "fold_757.csv"), row.names = FALSE)
  if (!is.null(lanes)) {
    l <- as.data.frame(lanes$lanes); l$share_in_loop <- ifelse(l$lane %in% c("outside_loop", "provider_build"), 0, l$samples / lanes$in_loop_samples)
    utils::write.csv(l, file.path(evidence, "lanes_757.csv"), row.names = FALSE)
    print(l[order(-l$samples), ], row.names = FALSE)
  }
  m <- df[df$measured & df$arm == "prepared", ]
  cat(sprintf("prepared median wall %.2f s (spread %.2f), peaks %s MiB\n", stats::median(m$wall_seconds), diff(range(m$wall_seconds)), paste(round(m$peak_ws_mib, 1), collapse = "/")))
  invisible(df)
}

write_fixture_csv <- function(evidence) {
  sem <- semantic_fixture(); iv <- interval_fixture(); reg <- registered_fold_fixture()
  ev_counts <- eventful_facts()$counts
  row <- function(name, ...) data.frame(fixture = name, ..., stringsAsFactors = FALSE)
  fx <- rbind(
    row("semantic", n_instruments = length(sem$ids), n_sessions = length(sem$dates), universe = "U (snapshots)", formula = "fixed public facts in spike_runner.R",
        counts = paste(names(sem$counts), sem$counts, sep = "=", collapse = " ")),
    row("intervals", n_instruments = length(iv$ids), n_sessions = length(iv$dates), universe = "V (intervals)", formula = "fixed public facts in spike_runner.R",
        counts = paste(names(iv$counts), iv$counts, sep = "=", collapse = " ")),
    row("fold757_static", n_instruments = reg$spec$n_instruments, n_sessions = reg$spec$n_sessions, universe = "synthetic_members (60 identical complete lists)",
        formula = paste("writer spike_fixture(FIXTURES$envelope757);", reg$formula), counts = sprintf("headers=%d membership_rows=%d status_facts=%d lifetime_facts=%d",
        reg$spec$n_lists, reg$spec$n_lists * reg$spec$n_members, reg$spec$n_instruments, reg$spec$n_instruments)),
    row("eventful757", n_instruments = EVENTFUL$n_instruments, n_sessions = EVENTFUL$n_sessions, universe = "synthetic_members (rotating complete lists)",
        formula = paste(names(EVENTFUL)[-(1:5)], unlist(EVENTFUL[-(1:5)]), sep = ": ", collapse = "; "), counts = paste(names(ev_counts), ev_counts, sep = "=", collapse = " ")))
  fx$envelope <- sprintf("fold_wall_s<=%d peak_ws_mib<=%d eventful_pass_s<=%d; current-arm stop %d s / %d MiB", ENVELOPE$fold_wall_s, ENVELOPE$peak_ws_mib,
                         ENVELOPE$eventful_pass_s, WALL_STOP_S, WS_STOP_MIB)
  utils::write.csv(fx, file.path(evidence, "fixture.csv"), row.names = FALSE)
  env <- environment_row(); env$head <- system2("git", c("-C", shQuote(repo_root), "rev-parse", "HEAD"), stdout = TRUE)
  utils::write.csv(env, file.path(evidence, "environment.csv"), row.names = FALSE)
  print(fx[, c("fixture", "n_instruments", "n_sessions", "counts")], row.names = FALSE)
}

# ---------------------------------------------------------------------------
# Entry.
# ---------------------------------------------------------------------------

if (length(args) >= 1L && startsWith(args[[1L]], "--child")) {
  switch(args[[1L]],
    "--child-tests" = child_tests(args[[2L]], args[[3L]]),
    "--child-provider" = child_provider(args[[2L]], args[[3L]]),
    "--child-fold" = child_fold(args[[2L]], args[[3L]], args[[4L]], args[[5L]], args[[6L]], out = args[[length(args)]], prof = if (length(args) >= 8L) args[[7L]] else NULL),
    stop("unknown child mode"))
} else {
  mode <- if (length(args) >= 1L) args[[1L]] else "all"
  dir.create(evidence_dir, recursive = TRUE, showWarnings = FALSE)
  load_package(); set_arm("current"); install_arm_observer()
  cat("spike_runner", mode, "\n")
  cat("HEAD:", system2("git", c("-C", shQuote(repo_root), "rev-parse", "HEAD"), stdout = TRUE), "\n")
  cat("R:", R.version.string, " collapse:", as.character(utils::packageVersion("collapse")), " duckdb:", as.character(utils::packageVersion("duckdb")), "\n")
  write_fixture_csv(evidence_dir)
  if (mode %in% c("parity", "all")) parity_phase(evidence_dir)
  if (mode %in% c("semantic", "all")) semantic_phase(evidence_dir)
  if (mode %in% c("tests", "all")) tests_phase(evidence_dir)
  if (mode %in% c("provider757", "all")) provider757_phase(evidence_dir)
  if (mode %in% c("fold757", "all")) fold757_phase(evidence_dir)
  if (mode %in% c("fold757parity", "all")) fold757parity_phase(evidence_dir)
  cat("spike_runner done:", mode, "\n")
}
