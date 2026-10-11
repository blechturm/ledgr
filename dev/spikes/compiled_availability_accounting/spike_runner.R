# LDG-2992 compiled availability-accounting spike runner.
#
# Rscript spike_runner.R <ledgr_tree> <out_dir> [--gut]
#
# The tree must contain the runnable spike fork. The runner writes one row per
# case and arm, derived from the actual in-memory fold output. `--gut` corrupts
# one compiled event quantity after the C++ batch returns; the checker requires
# that corruption to change the recorded evidence.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) stop("usage: spike_runner.R <ledgr_tree> <out_dir> [--gut]")
tree <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
out_dir <- args[[2L]]
gut <- "--gut" %in% args
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all(
  tree,
  quiet = TRUE,
  compile = !file.exists(file.path(tree, "src", "ledgr.dll"))
))

day <- function(value, time = "16:00:00") {
  as.POSIXct(paste(as.Date("2020-01-01") + value - 1L, time), tz = "UTC")
}

session_facts <- function(days) {
  dates <- as.Date("2020-01-01") + seq_len(days) - 1L
  ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00",
      knowledge_time = as.POSIXct(dates, tz = "UTC") - 1,
      stringsAsFactors = FALSE
    ),
    venue_id = "XNYS"
  )
}

snapshot_from_closes <- function(closes, extra_families = list()) {
  days <- length(closes[[1L]])
  bars <- do.call(rbind, lapply(names(closes), function(id) {
    values <- closes[[id]]
    keep <- which(!is.na(values))
    if (length(keep) == 0L) return(NULL)
    data.frame(
      ts_utc = day(keep), instrument_id = id,
      open = values[keep], high = values[keep] + 1,
      low = ifelse(values[keep] > 1, values[keep] - 1, values[keep] / 2),
      close = values[keep], volume = 1000,
      stringsAsFactors = FALSE
    )
  }))
  families <- c(list(session_facts(days)), extra_families)
  ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = names(closes)),
    facts = do.call(ledgr_facts, families),
    price_basis = "split_adjusted"
  )
}

cash_fact <- function() {
  ledgr_facts_equity_corporate_actions(data.frame(
    fact_id = "dividend-1",
    subtype = "ordinary_cash_dividend",
    parent_instrument_id = "AAA",
    entitlement_time = day(2L),
    effective_time = day(4L),
    knowledge_time = day(1L),
    complete = TRUE,
    provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = 1.25,
    gross_cash_validated = TRUE,
    recipient_identity_validated = FALSE,
    recipient_quantity_validated = FALSE,
    source = "compiled_availability_spike",
    stringsAsFactors = FALSE
  ))
}

lifetime_fact <- function() {
  ledgr_facts_lifetime(data.frame(
    instrument_id = "BBB",
    effective_from = day(5L),
    knowledge_time = day(5L) - 1,
    assertion = "known_inactive",
    terminal_event = "bankruptcy",
    source = "compiled_availability_spike",
    stringsAsFactors = FALSE
  ))
}

case_simple <- function() {
  snapshot <- snapshot_from_closes(list(AAA = 100:105))
  strategy <- function(ctx, params) {
    target <- ctx$hold()
    target[["AAA"]] <- if (ctx$ts_utc < "2020-01-04T16:00:00Z") params$qty else 0
    target
  }
  list(
    snapshot = snapshot,
    experiment = ledgr_experiment(
      snapshot, strategy,
      valuation_policy = ledgr_valuation_stale(1),
      cost_model = ledgr_cost_zero()
    ),
    params = list(qty = 3)
  )
}

case_cashflow <- function() {
  snapshot <- snapshot_from_closes(
    list(AAA = c(100, 90, 45, 46)),
    list(cash_fact())
  )
  strategy <- function(ctx, params) {
    target <- ctx$hold()
    target[["AAA"]] <- 0
    target
  }
  list(
    snapshot = snapshot,
    experiment = ledgr_experiment(
      snapshot, strategy,
      opening = ledgr_opening(
        cash = 1000, positions = c(AAA = 2), cost_basis = c(AAA = 100)
      ),
      valuation_policy = ledgr_valuation_stale(1),
      cost_model = ledgr_cost_zero()
    ),
    params = list()
  )
}

case_terminal <- function() {
  snapshot <- snapshot_from_closes(
    list(
      AAA = c(100, NA, NA, NA, 90, 91),
      BBB = c(50, NA, NA, NA, NA, NA),
      CLK = rep(10, 6L)
    ),
    list(lifetime_fact())
  )
  strategy <- function(ctx, params) {
    target <- ctx$hold()
    if (ctx$ts_utc >= "2020-01-03T16:00:00Z" && "AAA" %in% names(target)) {
      target[["AAA"]] <- 0
    }
    target
  }
  list(
    snapshot = snapshot,
    experiment = ledgr_experiment(
      snapshot, strategy,
      opening = ledgr_opening(
        cash = 1000,
        positions = c(AAA = 2, BBB = 4),
        cost_basis = c(AAA = 100, BBB = 100)
      ),
      valuation_policy = ledgr_valuation_stale(1),
      cost_model = ledgr_cost_zero()
    ),
    params = list()
  )
}

capture_env <- new.env(parent = emptyenv())
assign(".ldg2992_capture", capture_env, envir = .GlobalEnv)
trace(
  "ledgr_memory_output_handler",
  exit = quote(assign(
    "handler", returnValue(), envir = get(".ldg2992_capture", envir = .GlobalEnv)
  )),
  print = FALSE,
  where = asNamespace("ledgr")
)
trace(
  "ledgr_execute_fold",
  exit = quote(assign(
    "fold", returnValue(), envir = get(".ldg2992_capture", envir = .GlobalEnv)
  )),
  print = FALSE,
  where = asNamespace("ledgr")
)
on.exit({
  untrace("ledgr_memory_output_handler", where = asNamespace("ledgr"))
  untrace("ledgr_execute_fold", where = asNamespace("ledgr"))
}, add = TRUE)

if (gut) {
  compiled_batch <- get("ledgr_run_compiled_spot_fifo_batch", asNamespace("ledgr"))
  assignInNamespace(
    "ledgr_run_compiled_spot_fifo_batch",
    function(...) {
      batch <- compiled_batch(...)
      if (length(batch$event_qty) > 0L) {
        batch$event_qty[[1L]] <- batch$event_qty[[1L]] + 1
      }
      batch
    },
    ns = "ledgr"
  )
}

as_iso <- function(value) {
  if (inherits(value, "POSIXt")) format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC") else value
}

normalize_frame <- function(value) {
  if (is.null(value)) return(NULL)
  value <- as.data.frame(value, stringsAsFactors = FALSE)
  value$run_id <- NULL
  value$event_id <- NULL
  value$sweep_id <- NULL
  for (name in names(value)) value[[name]] <- as_iso(value[[name]])
  rownames(value) <- NULL
  unclass(value)
}

event_evidence <- function(events) {
  list(
    rows = normalize_frame(events),
    cash_delta = as.numeric(attr(events, "ledgr_event_cash_delta")),
    position_delta = as.numeric(attr(events, "ledgr_event_position_delta")),
    realized = as.numeric(attr(events, "ledgr_event_realized")),
    cost_basis = as.numeric(attr(events, "ledgr_event_cost_basis"))
  )
}

state_evidence <- function(state) {
  lot <- state$lot_state
  ids <- names(state$positions)
  lots <- lapply(ids, function(id) {
    i <- unname(lot$instrument_index[[id]])
    if (is.null(i) || is.na(i) || lot$lot_tail[[i]] < lot$lot_head[[i]]) {
      return(list(qty = numeric(), price = numeric()))
    }
    live <- seq.int(lot$lot_head[[i]], lot$lot_tail[[i]])
    list(qty = as.numeric(lot$lot_qty[[i]][live]), price = as.numeric(lot$lot_price[[i]][live]))
  })
  names(lots) <- ids
  list(
    cash = as.numeric(state$cash),
    positions = as.list(state$positions[ids]),
    lots = lots,
    cost_basis_by_instrument = as.list(lot$cost_basis_by_inst[ids]),
    total_cost_basis = as.numeric(lot$total_cost_basis),
    realized_pnl = as.numeric(lot$realized_pnl)
  )
}

evidence_value <- function(value) {
  if (is.data.frame(value)) return(lapply(unclass(value), evidence_value))
  if (inherits(value, "POSIXt")) {
    return(format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  }
  if (is.numeric(value)) {
    return(vapply(value, function(x) {
      if (is.na(x)) return("NA")
      if (is.nan(x)) return("NaN")
      if (is.infinite(x)) return(if (x > 0) "Inf" else "-Inf")
      sprintf("%.17g", x)
    }, character(1)))
  }
  if (is.list(value)) return(lapply(value, evidence_value))
  value
}
json <- function(value) ledgr:::canonical_json(evidence_value(value))
run_arm <- function(case_name, fixture, arm) {
  compiled <- identical(arm, "hybrid")
  options(ledgr.spike.compiled_availability = compiled)
  capture_env$handler <- NULL
  capture_env$fold <- NULL
  start <- proc.time()[["elapsed"]]
  sweep <- ledgr_sweep(
    fixture$experiment,
    ledgr_param_grid(one = fixture$params),
    retain = ledgr_sweep_retention(returns = "completed", trades = "closed"),
    compiled_accounting_model = if (compiled) "spot_fifo" else NULL,
    stop_on_error = TRUE
  )
  elapsed <- proc.time()[["elapsed"]] - start
  handler <- capture_env$handler
  fold <- capture_env$fold
  if (is.null(handler) || is.null(fold)) stop("fold capture failed for ", case_name, "/", arm)
  economic <- sweep[1L, c(
    "status", "completion_json", "final_equity", "total_return",
    "annualized_return", "volatility", "sharpe_ratio", "max_drawdown",
    "n_trades", "win_rate", "avg_trade", "time_in_market",
    "valuation_state", "frozen_instrument_sessions",
    "max_frozen_equity_weight", "frozen_at_end_value",
    "assumed_terminal_outcomes"
  )]
  events <- handler$events()
  data.frame(
    case = case_name,
    arm = arm,
    economic_json = json(normalize_frame(economic)),
    events_json = json(event_evidence(events)),
    returns_json = json(normalize_frame(ledgr_sweep_returns(sweep))),
    trades_json = json(normalize_frame(ledgr_sweep_trades(sweep))),
    diagnostics_json = json(normalize_frame(handler$diagnostics())),
    completion_json = json(normalize_frame(handler$completion())),
    final_state_json = json(state_evidence(fold$state)),
    stringsAsFactors = FALSE
  ) -> evidence
  clock <- data.frame(
    case = case_name,
    arm = arm,
    elapsed_seconds = round(elapsed, 3),
    engine_seconds = round(as.numeric(sweep$t_engine[[1L]]), 3),
    stringsAsFactors = FALSE
  )
  list(evidence = evidence, clock = clock)
}

cases <- list(
  fill_round_trip = case_simple,
  cashflow_with_sale = case_cashflow,
  terminal_with_sale = case_terminal
)
evidence <- list()
clocks <- list()
for (case_name in names(cases)) {
  fixture <- cases[[case_name]]()
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  for (arm in c("canonical", "hybrid")) {
    result <- run_arm(case_name, fixture, arm)
    evidence[[length(evidence) + 1L]] <- result$evidence
    clocks[[length(clocks) + 1L]] <- result$clock
  }
  ledgr_snapshot_close(fixture$snapshot)
}
options(ledgr.spike.compiled_availability = NULL)

evidence <- do.call(rbind, evidence)
clocks <- do.call(rbind, clocks)
utils::write.csv(evidence, file.path(out_dir, "cases.csv"), row.names = FALSE)
utils::write.csv(clocks, file.path(out_dir, "clocks.csv"), row.names = FALSE)
print(evidence[, c("case", "arm")], row.names = FALSE)
print(clocks, row.names = FALSE)
