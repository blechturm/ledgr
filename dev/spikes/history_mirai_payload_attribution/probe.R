#!/usr/bin/env Rscript

# Small public-path probe run before the spike charter. It captures the exact
# task objects built by ledgr_sweep() without changing their evaluation.

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all(".", quiet = TRUE, compile = FALSE)

inputs <- ledgr_sim_pit_inputs(
  instrument_ids = sprintf("E0_%03d", seq_len(8L)),
  from = "2020-01-01",
  to = "2020-04-30",
  seed = 1601L,
  venue_id = "E0_VENUE",
  universe_id = "E0_UNIVERSE",
  cases = c("missing_observation", "halt")
)

constructor_args <- function(family) {
  x <- inputs$recipe$constructors[[family]]
  x[names(x) != "enabled"]
}
facts <- do.call(ledgr_facts, list(
  do.call(ledgr_facts_sessions, c(list(df = inputs$sessions), constructor_args("sessions"))),
  do.call(
    ledgr_facts_membership_snapshots,
    c(list(df = inputs$membership), constructor_args("membership"))
  ),
  do.call(
    ledgr_facts_lifetime,
    c(list(df = inputs$lifetime), constructor_args("lifetime"))
  ),
  do.call(ledgr_facts_trading_status, c(list(df = inputs$trading_status), constructor_args("trading_status")))
))

db_path <- tempfile(fileext = ".duckdb")
snapshot <- ledgr_snapshot_from_df(
  inputs$bars,
  instruments_df = inputs$instruments,
  facts = facts,
  db_path = db_path,
  price_basis = inputs$recipe$price_basis
)
on.exit({
  try(ledgr_snapshot_close(snapshot), silent = TRUE)
  unlink(db_path)
}, add = TRUE)

strategy <- function(ctx, params) {
  scores <- ledgr_signal_return(ctx, lookback = 20L)
  selected <- ledgr_select_top_n(scores, n = params$n, partial = "allow")
  ledgr_weight_equal(selected) |>
    ledgr_target_rebalance(ctx, equity_fraction = params$invested)
}
experiment <- ledgr_experiment(
  snapshot,
  strategy,
  features = list(ledgr_ind_returns(20L)),
  universe = ledgr_universe_members(inputs$recipe$scopes$universe_id),
  valuation_policy = ledgr_valuation_stale(5L),
  cost_model = ledgr_cost_zero(),
  opening = ledgr_opening(cash = 1e6)
)
grid <- ledgr_param_grid(
  first = list(n = 3L, invested = 0.90),
  second = list(n = 5L, invested = 0.95)
)

capture <- new.env(parent = emptyenv())
ns <- asNamespace("ledgr")
name <- "ledgr_sweep_candidate_tasks"
original <- get(name, envir = ns, inherits = FALSE)
unlockBinding(name, ns)
assign(name, function(...) {
  out <- original(...)
  capture$tasks <- out
  out
}, envir = ns)
lockBinding(name, ns)
on.exit({
  unlockBinding(name, ns)
  assign(name, original, envir = ns)
  lockBinding(name, ns)
}, add = TRUE)

sequential <- ledgr_sweep(experiment, grid, seed = 1601L, workers = 1L)
tasks <- capture$tasks

serialized_bytes <- function(x) length(serialize(x, NULL, xdr = TRUE, version = 3L))
same <- vapply(names(tasks[[1L]]), function(field) {
  identical(tasks[[1L]][[field]], tasks[[2L]][[field]])
}, logical(1))

summary <- data.frame(
  measure = c(
    "bars", "instruments", "pulses", "task_count", "task_list_object_bytes",
    "task_1_serialized_bytes", "task_2_serialized_bytes",
    "invariant_field_count", "varying_field_count"
  ),
  value = c(
    nrow(inputs$bars), nrow(inputs$instruments),
    length(unique(inputs$bars$ts_utc)), length(tasks),
    as.numeric(object.size(tasks)), serialized_bytes(tasks[[1L]]),
    serialized_bytes(tasks[[2L]]), sum(same), sum(!same)
  )
)
print(summary, row.names = FALSE)
cat("invariant_fields=", paste(names(same)[same], collapse = ","), "\n", sep = "")
cat("varying_fields=", paste(names(same)[!same], collapse = ","), "\n", sep = "")
cat("statuses=", paste(sequential$status, collapse = ","), "\n", sep = "")
cat("result_columns=", paste(names(sequential), collapse = ","), "\n", sep = "")
key <- ledgr_candidate_reproduction_key(ledgr_candidate(sequential, "first"))
key$source_sweep$sweep_id <- "<sweep-id>"
cat("candidate_key=", ledgr:::canonical_json(key), "\n", sep = "")
