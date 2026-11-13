# Cut 17 (LDG-3232): genuine pulse views and the representative helper
# arguments, shared by the oracle (oracle_run.R, oracle_cases.R), the
# measurement record (measure_helper.R) and the timing protocol
# cut17-helper-1 (workloads.R). Needs r_floor_fixture() from
# dev/spikes/r_floor/fixture.R.

# Runs `pulses` pulses on r_floor_fixture(n, pulses): on pulse 1 the strategy
# buys about 0.9 of the cash in equal value per instrument with plain
# quantity targets (no sizing helper, so the views do not depend on the code
# under test), then holds; returns the pulse views the strategy saw on the
# pulses in `keep` (untouched by the strategy), with their provenance.
helper_capture_views <- function(n, keep = 4L, pulses = 8L, db_path = tempfile(fileext = ".duckdb")) {
  fx <- r_floor_fixture(n, pulses)
  snap <- ledgr::ledgr_snapshot_from_df(fx$bars, db_path = db_path, snapshot_id = paste0("helper", n), price_basis = "split_adjusted")
  on.exit(ledgr::ledgr_snapshot_close(snap), add = TRUE)
  grab <- new.env()
  grab$views <- list()
  s <- function(ctx, params) {
    k <- ctx$state$k + 1L
    if (k %in% keep) grab$views[[length(grab$views) + 1L]] <- ctx
    targets <- ctx$hold()
    if (k == 1L) targets[] <- floor(0.9 * 1e7 / length(targets) / as.numeric(ctx$close))
    ledgr_strategy_result(targets, k = k)
  }
  environment(s) <- list2env(list(grab = grab, keep = keep), parent = asNamespace("ledgr"))
  exp <- ledgr::ledgr_experiment(snap, s, opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
                                 risk_chain = ledgr::ledgr_risk_none(), portfolio_state = list(k = 0L))
  bt <- suppressWarnings(ledgr::ledgr_run(exp, run_id = paste0("helper", n), seed = 1L))
  close(bt)
  v <- grab$views[[1L]]
  list(views = grab$views, provenance = data.frame(view = paste0("v", n), instruments = n, pulses = pulses,
    captured_pulse = paste(keep, collapse = ";"), fixture = "r_floor_fixture(n, pulses), seed 20260530",
    inputs_digest = digest::digest(list(as.vector(v$universe), as.numeric(v$position), as.numeric(v$close),
      as.numeric(v$equity), as.logical(v$buyable), as.logical(v$member), as.numeric(v$holding_value))),
    stringsAsFactors = FALSE))
}

# Representative arguments on a view: rebalance weights on a permuted subset
# (every other instrument, reversed) with keep for the first held
# instrument and capital_base total_equity; adjust weights, add_value
# (reversed order) and an exit mask on disjoint subsets.
helper_view_args <- function(ctx, verb) {
  ids <- as.vector(ctx$universe)
  n <- length(ids)
  pos <- as.numeric(ctx$position)
  held <- ids[pos != 0]
  out <- list(ctx = ctx)
  if (verb == "plain") return(out)
  pick <- ids[rev(seq(1L, n, by = 2L))]
  if (verb == "rebalance") {
    k <- if (length(held)) held[[1L]] else character()
    w_ids <- pick[!pick %in% k]
    out$w <- stats::setNames(rep(0.5 / length(w_ids), length(w_ids)), w_ids)
    out$k <- k
  } else {
    w_ids <- ids[seq(2L, n, by = 4L)]
    a_ids <- ids[seq(3L, n, by = 4L)]
    out$w <- stats::setNames(rep(0.3 / length(w_ids), length(w_ids)), w_ids)
    out$a <- stats::setNames(rep(1000, length(a_ids)), rev(a_ids))
    out$ex <- stats::setNames(seq_len(n) %% 4L == 0L, ids)
  }
  out
}

# The two timed calls.
helper_call <- function(verb, a) {
  if (verb == "rebalance") ledgr::ledgr_target_rebalance(a$ctx, weights = a$w, keep = a$k, capital_base = "total_equity")
  else ledgr::ledgr_target_adjust(a$ctx, weights = a$w, add_value = a$a, exit = a$ex)
}
