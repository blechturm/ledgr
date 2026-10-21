# LDG-3072 probe: which values beyond the pulse can a strategy reach through
# the private context carrier and the closure environments behind public
# context functions? Synthetic data only.
#
#   Rscript dev/bench/v0_2_2_history_proof/ctx_reach_probe.R <repo> [out.txt]
#
# The probe runs one availability-aware experiment whose strategy hands its
# context at one early pulse to an environment captured by the strategy
# closure, then lists, for the captured context, the dot-prefixed fields and
# the objects reachable from public function closures that hold values for
# pulses after the captured one. It prints the reached paths and the shapes
# of the future-bearing objects; it changes nothing in the package.

args <- commandArgs(TRUE)
root <- if (length(args) >= 1L) args[[1L]] else "."
out <- if (length(args) >= 2L) args[[2L]] else NULL
suppressMessages(pkgload::load_all(root, quiet = TRUE))

ids <- sprintf("DEMO_%02d", 1:8)
pit <- ledgr_sim_pit_inputs(ids, from = "2020-01-01", to = "2020-12-31", seed = 7L)
facts <- ledgr_facts(
  ledgr_facts_sessions(pit$sessions, venue_id = "DEMO_VENUE", knowledge = "evidenced", timezone = "UTC"),
  ledgr_facts_membership_snapshots(pit$membership, universe_id = "DEMO_UNIVERSE", complete = TRUE, knowledge = "evidenced"),
  ledgr_facts_trading_status(pit$trading_status, knowledge = "evidenced"),
  ledgr_facts_lifetime(pit$lifetime, knowledge = "evidenced"),
  ledgr_facts_equity_corporate_actions(pit$corporate_actions)
)
snapshot <- ledgr_snapshot_from_df(
  pit$bars, instruments_df = pit$instruments, facts = facts,
  db_path = tempfile(fileext = ".duckdb"), snapshot_id = "ctx_probe", price_basis = "split_adjusted"
)
captured_at <- "2020-03-02T16:00:00Z"
sink_env <- new.env()
make_strategy <- function(sink_env, at) {
  force(sink_env)
  force(at)
  function(ctx, params) {
    if (identical(ctx$ts_utc, at)) sink_env$ctx <- ctx
    ctx$hold()
  }
}
exp <- ledgr_experiment(
  snapshot, make_strategy(sink_env, captured_at),
  features = ledgr_feature_map(daily_return = ledgr_ind_returns(1L)),
  universe = ledgr_universe_members("DEMO_UNIVERSE"), cost_model = ledgr_cost_zero()
)
bt <- ledgr_run(exp, run_id = "ctx-probe")
close(bt)
ctx <- sink_env$ctx
cutoff <- as.POSIXct(captured_at, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

lines <- c(
  sprintf("captured pulse: %s", captured_at),
  sprintf("context fields: %s", paste(names(ctx), collapse = ", ")),
  sprintf("dot-prefixed fields: %s", paste(grep("^[.]", names(ctx), value = TRUE), collapse = ", "))
)
view <- ctx$.history
axis <- view$service$substrate$axis
lines <- c(lines, sprintf(
  "ctx$.history: substrate axis %d sessions, last %s, cutoff column %d; %d sessions after the pulse",
  length(axis), format(max(axis), "%Y-%m-%d"), view$cutoff_col, sum(axis > cutoff)
))

closure <- environment(ctx$feature)
lines <- c(lines, sprintf("environment(ctx$feature): %s", paste(ls(closure, all.names = TRUE), collapse = ", ")))
lines <- c(lines, sprintf(
  "environment(ctx$feature)$ctx is the context, so $.history is reachable: %s",
  inherits(closure$ctx$.history, "ledgr_history_view")
))
inner <- environment(closure$feature_vector)
values <- inner$feature_values
for (name in names(values)) {
  pulses <- as.POSIXct(colnames(values[[name]]), format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  lines <- c(lines, sprintf(
    "environment(environment(ctx$feature)$feature_vector)$feature_values$%s: %d x %d, %d columns after the pulse, %d finite future values",
    name, nrow(values[[name]]), ncol(values[[name]]), sum(pulses > cutoff),
    sum(is.finite(values[[name]][, pulses > cutoff]))
  ))
}
lookup <- environment(ctx$bar)$lookup
lines <- c(lines, sprintf(
  "environment(ctx$bar)$lookup: %s; its feature_vector closure reaches the context again: %s",
  paste(ls(lookup, all.names = TRUE), collapse = ", "),
  inherits(environment(lookup$feature_vector)$ctx$.history, "ledgr_history_view")
))

strategies <- list(
  carrier = function(ctx, params) { x <- ctx$.history$service$substrate$bars; ctx$hold() },
  closure = function(ctx, params) { x <- environment(environment(ctx$feature)$feature_vector)$feature_values; ctx$hold() },
  lookup = function(ctx, params) { x <- environment(ctx$bar)$lookup; ctx$hold() }
)
for (name in names(strategies)) {
  preflight <- ledgr_strategy_preflight(strategies[[name]])
  lines <- c(lines, sprintf("preflight %s: %s - %s", name, preflight$tier, preflight$reason))
}
ledgr_snapshot_close(snapshot)
cat(lines, sep = "\n")
if (!is.null(out)) writeLines(lines, out)
