# WS45 identity comparison runner. Builds the same fact corpus, snapshots and
# runs in one tree and writes every observable to an RDS file.
# Rscript compare_runner.R <tree> <out.rds>
args <- commandArgs(trailingOnly = TRUE)
tree <- args[[1L]]
out_path <- args[[2L]]
suppressMessages(pkgload::load_all(tree, quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")
utc <- function(x) as.POSIXct(x, tz = "UTC")

# ---- inputs -------------------------------------------------------------
days <- seq(as.Date("2021-01-04"), as.Date("2021-02-26"), by = "day")
wday <- as.POSIXlt(days)$wday
open_day <- !wday %in% c(0L, 6L) & !days %in% as.Date(c("2021-01-18", "2021-02-15"))
open_dates <- days[open_day]
sessions_df <- data.frame(
  session_date = days,
  status = ifelse(open_day, "open", "closed"),
  session_open = ifelse(open_day, "09:30:00", NA),
  session_close = ifelse(open_day, "16:00:00", NA),
  knowledge_time = utc("2020-12-01"),
  source = "calendar",
  stringsAsFactors = FALSE
)
stamp <- function(d, hms) {
  out <- rep(utc(NA), length(d))
  keep <- !is.na(d)
  out[keep] <- utc(paste(d[keep], hms))
  out
}
close_utc <- function(d) stamp(d, "21:00:00")
open_utc <- function(d) stamp(d, "14:30:00")
inst <- c("AAA", "BBB", "CCC", "DDD")

membership_date <- data.frame(
  instrument_id = rep(inst, each = 3),
  effective_from = rep(open_dates[c(1, 10, 20)], 4),
  effective_to = rep(open_dates[c(10, 20, 30)], 4),
  knowledge_time = rep(open_dates[c(1, 9, 19)], 4),
  member = rep(c(TRUE, FALSE, TRUE), 4),
  source = "vendor",
  stringsAsFactors = FALSE
)
membership_posix <- membership_date
for (f in c("effective_from", "effective_to", "knowledge_time")) {
  membership_posix[[f]] <- open_utc(membership_posix[[f]])
}
membership_mixed_ok <- membership_date
membership_mixed_ok$knowledge_time <- open_utc(open_dates[c(1, 9, 19)]) - 3600
snapshots_rows <- data.frame(
  effective_from = rep(open_dates[c(1, 15)], c(3, 2)),
  instrument_id = c("AAA", "BBB", "CCC", "AAA", "DDD"),
  source = "index",
  stringsAsFactors = FALSE
)
snapshots_list <- data.frame(
  effective_from = open_utc(open_dates[c(1, 15, 25)]),
  knowledge_time = open_utc(open_dates[c(1, 14, 24)]),
  source = "index",
  stringsAsFactors = FALSE
)
snapshots_list$members <- I(list(c("AAA", "BBB"), character(), c("CCC", "DDD")))
status_posix <- data.frame(
  instrument_id = c("AAA", "AAA", "AAA", "AAA", "BBB", "BBB"),
  effective_from = close_utc(open_dates[c(3, 3, 3, 12, 5, 5)]),
  effective_to = close_utc(open_dates[c(8, 8, 8, 14, 9, 9)]),
  knowledge_time = close_utc(open_dates[c(2, 4, 6, 11, 4, 4)]),
  status = c("halted", "active", "halted", "quotation_only", "halted", "halted"),
  source = c("venue", "venue", "venue", "venue", "venue", "vendor"),
  precedence = c(1L, 1L, 1L, 1L, 1L, 2L),
  fact_id = c("s1", "s2", "s3", "s4", "s5", "s6"),
  supersedes_fact_id = c(NA, "s1", "s2", NA, NA, NA),
  stringsAsFactors = FALSE
)
status_date_knowledge <- status_posix
status_date_knowledge$knowledge_time <- open_dates[c(2, 4, 6, 11, 4, 4)]
status_date <- status_posix
status_date$effective_from <- open_dates[c(3, 3, 3, 12, 5, 5)]
status_date$effective_to <- open_dates[c(8, 8, 8, 14, 9, 9)]
status_date$knowledge_time <- open_dates[c(2, 4, 6, 11, 4, 4)]
lifetime_date <- data.frame(
  instrument_id = c("AAA", "BBB", "CCC", "CCC"),
  effective_from = open_dates[c(1, 1, 1, 25)],
  effective_to = as.Date(c(NA, NA, open_dates[25], NA)),
  knowledge_time = open_dates[c(1, 1, 1, 24)],
  assertion = c("known_active", "known_active", "known_active", "known_inactive"),
  terminal_event = c(NA, NA, NA, "delisted"),
  source = "vendor",
  stringsAsFactors = FALSE
)
ca_common <- function(n) {
  data.frame(
    complete = rep(TRUE, n),
    provenance_tier = "snapshot_bound",
    source = "vendor",
    stringsAsFactors = FALSE
  )
}
ca_date <- cbind(ca_common(5), data.frame(
  subtype = c("ordinary_cash_dividend", "ordinary_cash_dividend", "cash_acquisition", "spin_off", "ordinary_cash_dividend"),
  parent_instrument_id = c("AAA", "BBB", "DDD", "BBB", "CCC"),
  entitlement_time = open_dates[c(6, 8, 28, 21, NA)],
  effective_time = open_dates[c(7, 9, 28, 22, NA)],
  payment_time = open_dates[c(9, 11, NA, NA, NA)],
  gross_cash_per_parent_unit = c(0.5, 0.25, NA, NA, NA),
  gross_cash_validated = c(TRUE, TRUE, FALSE, FALSE, FALSE),
  recipient_instrument_id = c(NA, NA, NA, "CCC", NA),
  recipient_identity_validated = c(FALSE, FALSE, FALSE, TRUE, FALSE),
  recipient_quantity_per_parent_unit = c(NA, NA, NA, 0.5, NA),
  recipient_quantity_validated = c(FALSE, FALSE, FALSE, TRUE, FALSE),
  stringsAsFactors = FALSE
))
ca_date$knowledge_time <- as.Date(c(NA, open_dates[5], NA, NA, NA))
ca_date$complete[[5L]] <- FALSE
ca_date$refusal_reason <- c(NA, NA, NA, NA, "terms_unvalidated")
ca_posix <- ca_date
for (f in c("entitlement_time", "effective_time", "payment_time")) {
  ca_posix[[f]] <- close_utc(ca_posix[[f]])
}
ca_posix$knowledge_time <- open_utc(ca_date$knowledge_time)
ca_mixed_ok <- ca_date
ca_mixed_ok$knowledge_time <- as.Date(c(open_dates[c(5, 7, 27, 20)], NA))
ca_mixed_ok$entitlement_time <- close_utc(open_dates[c(6, 8, 27, 21, NA)])
ca_mixed_knowledge <- ca_date
ca_mixed_knowledge$knowledge_time <- c(open_utc(open_dates[c(5, 7, 27, 20)]) - 7200, utc(NA))

# Intended-difference inputs (outside BASE's correct behaviour).
ca_supplied_knowledge <- ca_date[1L, ]
ca_supplied_knowledge$knowledge_time <- utc(paste(open_dates[[8]], "12:00:00"))
ca_posix_effective <- ca_date[1L, ]
ca_posix_effective$effective_time <- close_utc(open_dates[[7]])
ca_false_accept <- ca_date[1L, ]
ca_false_accept$payment_time <- as.Date(NA)
ca_false_accept$entitlement_time <- open_dates[[7]]
ca_false_accept$effective_time <- utc(paste(open_dates[[7]], "15:00:00"))
ca_false_refusal <- ca_date[1L, ]
ca_false_refusal$payment_time <- as.Date(NA)
ca_false_refusal$entitlement_time <- utc(paste(open_dates[[7]], "15:00:00"))
ca_false_refusal$effective_time <- open_dates[[7]]
membership_false_refusal <- membership_date[1L, ]
membership_false_refusal$effective_from <- utc(paste(open_dates[[10]], "10:00:00"))
membership_false_refusal$knowledge_time <- membership_false_refusal$effective_from

# ---- capture helpers -----------------------------------------------------
plain <- function(df) {
  if (is.null(df)) return(NULL)
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  for (n in names(df)) {
    if (inherits(df[[n]], "POSIXt")) df[[n]] <- as.numeric(df[[n]])
    if (inherits(df[[n]], "Date")) df[[n]] <- as.character(df[[n]])
    if (is.list(df[[n]])) df[[n]] <- vapply(df[[n]], function(x) paste(x, collapse = "|"), "")
  }
  rownames(df) <- NULL
  df
}
capture <- function(expr) {
  tryCatch(expr, error = function(e) list(error = class(e)[[1L]], message = conditionMessage(e)))
}
family_view <- function(family) {
  list(
    family = family$family, scope_id = family$scope_id,
    rows = plain(family$rows), headers = plain(family$headers),
    metadata = family$metadata, fact_hash = family$fact_hash
  )
}
bundle_view <- function(bundle) {
  if (!inherits(bundle, "ledgr_facts")) return(bundle)
  list(
    bundle_hash = bundle$bundle_hash,
    families = lapply(bundle$families, family_view)
  )
}
sessions <- function() ledgr_facts_sessions(sessions_df, "XNYS", timezone = "America/New_York")
membership <- function(df, ...) ledgr_facts_membership_intervals(df, universe_id = "u", ...)
ca <- function(df) ledgr_facts_equity_corporate_actions(df)

cases <- list(
  membership_date = function() ledgr_facts(sessions(), membership(membership_date)),
  membership_posix = function() ledgr_facts(sessions(), membership(membership_posix)),
  membership_mixed_ok = function() ledgr_facts(sessions(), membership(membership_mixed_ok)),
  membership_assume = function() {
    df <- membership_date
    df$knowledge_time <- as.Date(c(NA, open_dates[9], NA, NA, NA, NA, open_dates[1], NA, NA, NA, NA, NA))
    ledgr_facts(sessions(), membership(df, knowledge = "assume_effective"))
  },
  snapshots_rows = function() ledgr_facts(sessions(), ledgr_facts_membership_snapshots(snapshots_rows, "idx", knowledge = "assume_effective")),
  snapshots_list = function() ledgr_facts(sessions(), ledgr_facts_membership_snapshots(snapshots_list, "idx", complete = c(TRUE, TRUE, FALSE))),
  status_posix = function() ledgr_facts(sessions(), ledgr_facts_trading_status(status_posix)),
  status_date_knowledge = function() ledgr_facts(sessions(), ledgr_facts_trading_status(status_date_knowledge)),
  status_date = function() ledgr_facts(sessions(), ledgr_facts_trading_status(status_date)),
  status_bare = function() ledgr_facts(ledgr_facts_trading_status(status_posix)),
  lifetime_date = function() ledgr_facts(sessions(), ledgr_facts_lifetime(lifetime_date)),
  ca_date = function() ledgr_facts(sessions(), ca(ca_date)),
  ca_posix = function() ledgr_facts(sessions(), ca(ca_posix)),
  ca_posix_bare = function() ledgr_facts(ca(ca_posix)),
  ca_mixed_ok = function() ledgr_facts(sessions(), ca(ca_mixed_ok)),
  all_families = function() ledgr_facts(
    sessions(), membership(membership_date), ledgr_facts_trading_status(status_date_knowledge),
    ledgr_facts_lifetime(lifetime_date), ca(ca_date)
  ),
  rebundle = function() {
    b <- ledgr_facts(sessions(), membership(membership_date), ca(ca_date))
    do.call(ledgr_facts, b$families)
  },
  qlcal_sessions = function() {
    cal <- qlcal::getCalendar("UnitedStates/NYSE")
    s <- ledgr_facts_sessions_qlcal(cal, as.Date("2021-01-04"), as.Date("2021-02-26"), "XNYS",
      "America/New_York", "09:30:00", "16:00:00")
    ledgr_facts(s, membership(membership_date))
  },
  # Intended differences.
  diff_ca_supplied_knowledge = function() ledgr_facts(sessions(), ca(ca_supplied_knowledge)),
  diff_ca_mixed_knowledge = function() ledgr_facts(sessions(), ca(ca_mixed_knowledge)),
  diff_ca_posix_effective = function() ledgr_facts(sessions(), ca(ca_posix_effective)),
  diff_ca_false_accept = function() ledgr_facts(sessions(), ca(ca_false_accept)),
  diff_ca_false_refusal = function() ledgr_facts(sessions(), ca(ca_false_refusal)),
  diff_membership_false_refusal = function() ledgr_facts(sessions(), membership(membership_false_refusal)),
  # Decision (32): supplied POSIXct knowledge beside a Date effective time
  # under assume_effective is kept (BASE replaced it with the session open).
  diff32_membership_assume = function() {
    df <- membership_date
    df$knowledge_time <- c(open_utc(open_dates[c(1, 9)]) + 3600, rep(utc(NA), 10))
    ledgr_facts(sessions(), membership(df, knowledge = "assume_effective"))
  },
  diff32_status_assume = function() {
    df <- status_date
    df$knowledge_time <- c(close_utc(open_dates[c(2, 4, 6)]), rep(utc(NA), 3))
    ledgr_facts(sessions(), ledgr_facts_trading_status(df, knowledge = "assume_effective"))
  },
  diff32_lifetime_assume = function() {
    df <- lifetime_date
    df$knowledge_time <- c(utc(NA), close_utc(open_dates[1]), utc(NA), close_utc(open_dates[24]))
    ledgr_facts(sessions(), ledgr_facts_lifetime(df, knowledge = "assume_effective"))
  },
  diff32_snapshots_assume = function() {
    df <- data.frame(
      effective_from = open_dates[c(2, 2, 2, 2, 5)],
      knowledge_time = utc(paste(open_dates[c(2, 2, 2, 2, 5)], c("23:00:00", "23:00:00", "12:00:00", "12:00:00", "01:00:00"))),
      instrument_id = c("AAA", "BBB", "AAA", "CCC", "DDD"),
      set_id = c("set_a", "set_a", "set_z", "set_z", "set_m"),
      source = "idx", stringsAsFactors = FALSE
    )
    ledgr_facts(sessions(), ledgr_facts_membership_snapshots(df, "idx", knowledge = "assume_effective"))
  },
  # Decision (34) (close review 45 F1): headers ordered by resolved knowledge.
  diff34_snapshot_header_order = function() {
    df <- data.frame(
      effective_from = utc(paste(open_dates[[2]], "10:00:00")),
      instrument_id = c("AAA", "BBB", "AAA", "CCC"),
      set_id = c("set_x", "set_x", "set_y", "set_y"),
      source = "idx", stringsAsFactors = FALSE
    )
    df$knowledge_time <- as.Date(c(NA, NA, open_dates[[2]], open_dates[[2]]))
    ledgr_facts(sessions(), ledgr_facts_membership_snapshots(df, "idx", knowledge = "assume_effective"))
  }
)
out <- list(facts = lapply(cases, function(f) bundle_view(capture(f()))))

# ---- snapshots and runs ---------------------------------------------------
bars_for <- function(ids) {
  k <- seq_along(open_dates)
  do.call(rbind, lapply(seq_along(ids), function(i) data.frame(
    instrument_id = ids[[i]], ts_utc = close_utc(open_dates),
    open = 10 * i + k, high = 10 * i + k + 1, low = 10 * i + k - 1, close = 10 * i + k + 0.5,
    volume = 1000, stringsAsFactors = FALSE
  )))
}
strategy <- function(ctx, params) {
  target <- ctx$hold()
  day <- substr(ctx$ts_utc, 1L, 10L)
  if (identical(day, "2021-02-03")) target[["AAA"]] <- target[["AAA"]] + 3
  if (identical(day, "2021-02-04")) target[["BBB"]] <- target[["BBB"]] + 2
  target
}
run_view <- function(bt) {
  drop <- c("event_id", "run_id", "event_seq")
  ledger <- plain(ledgr_results(bt, "ledger"))
  list(
    ledger = ledger[, setdiff(names(ledger), drop), drop = FALSE],
    equity = plain(ledgr_results(bt, "equity")),
    fills = plain(ledgr_results(bt, "fills")),
    summary = capture(plain(ns$ledgr_corporate_action_summary(bt)$terminal_outcomes))
  )
}
snapshot_view <- function(facts_fn, policy, label) {
  facts <- facts_fn()
  snapshot <- ledgr_snapshot_from_df(
    bars_for(inst), data.frame(instrument_id = inst),
    db_path = tempfile(fileext = ".duckdb"), facts = facts, price_basis = "split_adjusted"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  info <- ledgr_snapshot_info(snapshot)
  con <- ns$get_connection(snapshot)
  tables <- c("snapshot_membership", "snapshot_membership_sets", "snapshot_trading_status",
    "snapshot_lifetime", "snapshot_equity_corporate_actions", "snapshot_sessions", "snapshot_fact_families")
  stored <- lapply(tables, function(t) {
    df <- DBI::dbGetQuery(con, sprintf("SELECT * FROM %s WHERE snapshot_id = ?", t), params = list(snapshot$snapshot_id))
    df$snapshot_id <- NULL
    df <- plain(df)
    if (nrow(df) > 0L) df <- df[do.call(order, unname(as.list(df))), , drop = FALSE]
    rownames(df) <- NULL
    df
  })
  names(stored) <- tables
  exp <- ledgr_experiment(
    snapshot, strategy, universe = ledgr_universe_members("u"),
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 2, BBB = 1, DDD = 1), cost_basis = c(AAA = 11, BBB = 21, DDD = 41)),
    cost_model = ledgr_cost_zero(), corporate_action_policy = policy
  )
  bt <- capture(ledgr_run(exp, run_id = paste0("cmp-", label)))
  run <- if (inherits(bt, "ledgr_backtest")) { v <- run_view(bt); close(bt); v } else bt
  folds <- ns$ledgr_fold_list(list(
    ledgr_fold(open_dates[[1]], open_dates[[10]], open_dates[[11]], open_dates[[20]], fold_seq = 1L),
    ledgr_fold(open_dates[[1]], open_dates[[20]], open_dates[[21]], open_dates[[35]], fold_seq = 2L)
  ), constructor = list(type_id = "explicit"))
  wf <- capture(suppressWarnings(ledgr_walk_forward(
    exp, ledgr_param_grid(list()), folds,
    selection_rule = ledgr_rule_argmax("annualized_return"), seed = 1L
  )))
  chain <- if (is.list(wf) && !is.null(wf$test_runs)) {
    v <- list(status = wf$status, runs = lapply(wf$test_runs, run_view))
    lapply(wf$test_runs, close)
    v
  } else wf
  list(
    snapshot_hash = info$snapshot_hash, hash_rule_version = info$hash_rule_version,
    stored = stored, run = run, chain = chain
  )
}
# Status cover for the run fixtures: every instrument active at precedence
# 0 from the first session, so instruments without venue rows are tradable.
with_cover <- function(df) {
  cover <- data.frame(
    instrument_id = inst,
    effective_from = close_utc(open_dates[[1]]) - 86400,
    effective_to = utc(NA),
    knowledge_time = close_utc(open_dates[[1]]) - 86400,
    status = "active", source = "cover", precedence = 0L,
    fact_id = paste0("cover-", inst), supersedes_fact_id = NA_character_,
    stringsAsFactors = FALSE
  )
  if (inherits(df$knowledge_time, "Date")) cover$knowledge_time <- open_dates[[1]]
  if (inherits(df$effective_from, "Date")) {
    cover$effective_from <- open_dates[[1]]
    cover$effective_to <- as.Date(NA)
  }
  rbind(df, cover)
}
out$snapshots <- list(
  all_families = snapshot_view(function() ledgr_facts(
    sessions(), membership(membership_date), ledgr_facts_trading_status(with_cover(status_date_knowledge)),
    ledgr_facts_lifetime(lifetime_date), ca(ca_date)
  ), ledgr_corporate_actions_research(), "all"),
  posix_families = snapshot_view(function() ledgr_facts(
    sessions(), membership(membership_posix), ledgr_facts_trading_status(with_cover(status_posix)), ca(ca_posix)
  ), ledgr_corporate_actions_research(), "posix"),
  mixed_ok = snapshot_view(function() ledgr_facts(
    sessions(), membership(membership_mixed_ok), ledgr_facts_trading_status(with_cover(status_date)), ca(ca_mixed_ok)
  ), ledgr_corporate_actions(cash_posting = "next_open"), "mixed"),
  # Intended difference (decision 28): DDD's cash acquisition loses its
  # entitlement clock.
  diff_d28_effective_only = snapshot_view(function() {
    unentitled <- ca_date
    unentitled$entitlement_time[[3L]] <- as.Date(NA)
    ledgr_facts(
      sessions(), membership(membership_date), ledgr_facts_trading_status(with_cover(status_date_knowledge)),
      ledgr_facts_lifetime(lifetime_date), ca(unentitled)
    )
  }, ledgr_corporate_actions_research(), "d28"),
  # Intended difference (decision 33): AAA's dividend loses its entitlement
  # clock (BASE never posted it).
  diff_d33_dividend_effective_only = snapshot_view(function() {
    unentitled <- ca_date
    unentitled$entitlement_time[[1L]] <- as.Date(NA)
    ledgr_facts(
      sessions(), membership(membership_date), ledgr_facts_trading_status(with_cover(status_date_knowledge)),
      ledgr_facts_lifetime(lifetime_date), ca(unentitled)
    )
  }, ledgr_corporate_actions_research(), "d33")
)
saveRDS(out, out_path)
cat("written", out_path, "\n")
