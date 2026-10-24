# ledgr-test-file-profile: review

ledgr_ws28_bars <- function() {
  data.frame(
    instrument_id = rep("AAA", 6L),
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:5,
    open = 100:105,
    high = 101:106,
    low = 99:104,
    close = c(100, 102, 101, 104, 103, 106),
    volume = 1000,
    stringsAsFactors = FALSE
  )
}

ledgr_ws28_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  if (ctx$ts_utc <= "2020-01-03T00:00:00Z") {
    targets[["AAA"]] <- params$qty
  }
  targets
}

ledgr_ws28_comparable_promotion_context <- function(x) {
  x[intersect(
    c("run_id", "promoted_at_utc", "source_sweep"),
    names(x)
  )] <- NULL
  x
}

ledgr_ws28_expect_roundtrip <- function(sweep, reopened, sweep_id) {
  fields <- c(
    "candidate_id", "candidate_row", "status", "completion_json",
    "final_equity", "total_return", "annualized_return", "volatility",
    "sharpe_ratio", "max_drawdown", "n_trades", "win_rate",
    "avg_trade", "time_in_market", "execution_seed", "error_class",
    "error_msg", "params", "feature_params", "risk_chain_hash"
  )
  for (field in fields) {
    testthat::expect_identical(reopened[[field]], sweep[[field]], info = field)
  }

  testthat::expect_identical(
    reopened$feature_fingerprints,
    sweep$feature_fingerprints
  )

  for (i in seq_len(nrow(sweep))) {
    testthat::expect_identical(
      as.character(canonical_json(reopened$provenance[[i]])),
      as.character(canonical_json(sweep$provenance[[i]]))
    )
    testthat::expect_identical(
      reopened$provenance[[i]]$feature_set_hash,
      sweep$provenance[[i]]$feature_set_hash
    )
  }

  original_returns <- ledgr_sweep_returns(sweep)
  original_returns$sweep_id <- sweep_id
  testthat::expect_identical(ledgr_sweep_returns(reopened), original_returns)

  original_trades <- ledgr_sweep_trades(sweep)
  original_trades$sweep_id <- sweep_id
  testthat::expect_identical(ledgr_sweep_trades(reopened), original_trades)
}

testthat::test_that("[LTB-0257] one-feature sweeps save, reopen and promote exactly", {
  snapshot <- ledgr_snapshot_from_df(
    ledgr_ws28_bars(),
    db_path = tempfile(fileext = ".duckdb"),
    snapshot_id = "single_feature_persistence"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  parameterized_features <- ledgr_feature_map(
    signal = ledgr_ind_sma(ledgr_param("n"))
  )
  cases <- list(
    parameterized = list(
      features = parameterized_features,
      grid = ledgr_grid_cross(
        features = ledgr_feature_grid(n = c(2L, 3L)),
        strategy = ledgr_strategy_grid(qty = 1)
      )
    ),
    concrete_map = list(
      features = ledgr_feature_map(signal = ledgr_ind_sma(2L)),
      grid = ledgr_grid_named(a = list(strategy = list(qty = 1)), b = list(strategy = list(qty = 2)))
    ),
    plain_list = list(
      features = list(ledgr_ind_sma(2L)),
      grid = ledgr_grid_named(a = list(strategy = list(qty = 1)), b = list(strategy = list(qty = 2)))
    )
  )

  reopened_cases <- list()
  experiments <- list()
  for (case_name in names(cases)) {
    case <- cases[[case_name]]
    experiment <- ledgr_experiment(
      snapshot,
      ledgr_ws28_strategy,
      features = case$features,
      cost_model = ledgr_cost_zero()
    )
    sweep <- ledgr_sweep(
      experiment,
      case$grid,
      seed = 28L,
      retain = ledgr_sweep_retention(returns = "completed", trades = "closed")
    )
    sweep_id <- paste0("single_feature_", case_name)

    testthat::expect_identical(
      vapply(sweep$feature_fingerprints, length, integer(1)),
      rep(1L, nrow(sweep)),
      info = case_name
    )
    testthat::expect_no_error(
      ledgr_sweep_save(sweep, snapshot, sweep_id = sweep_id)
    )
    reopened <- ledgr_sweep_open(snapshot, sweep_id)
    ledgr_ws28_expect_roundtrip(sweep, reopened, sweep_id)

    in_memory_candidate <- ledgr_candidate(sweep, 1L)
    reopened_candidate <- ledgr_candidate(reopened, 1L)
    in_memory_promoted <- testthat::expect_no_warning(
      ledgr_promote(
        experiment,
        in_memory_candidate,
        run_id = paste0("promoted_memory_", case_name)
      )
    )
    reopened_promoted <- testthat::expect_no_warning(
      ledgr_promote(
        experiment,
        reopened_candidate,
        run_id = paste0("promoted_reopened_", case_name)
      )
    )
    in_memory_context <- ledgr_promotion_context(in_memory_promoted)
    reopened_context <- ledgr_promotion_context(reopened_promoted)
    close(in_memory_promoted)
    close(reopened_promoted)
    testthat::expect_identical(
      ledgr_ws28_comparable_promotion_context(reopened_context),
      ledgr_ws28_comparable_promotion_context(in_memory_context),
      info = paste(case_name, "promotion context")
    )
    for (context in list(in_memory_context, reopened_context)) {
      testthat::expect_identical(
        context$identity_check$candidate,
        context$identity_check$promoting,
        info = case_name
      )
    }

    testthat::expect_identical(
      reopened_context$source_sweep$sweep_id,
      sweep_id,
      info = paste(case_name, "reopened source sweep")
    )

    reopened_cases[[case_name]] <- reopened
    experiments[[case_name]] <- experiment
  }

  mismatched <- ledgr_experiment(
    snapshot,
    ledgr_ws28_strategy,
    features = ledgr_feature_map(signal = ledgr_ind_returns(ledgr_param("n"))),
    cost_model = ledgr_cost_zero()
  )
  testthat::expect_warning(
    mismatch_run <- ledgr_promote(
      mismatched,
      ledgr_candidate(reopened_cases$parameterized, 1L),
      run_id = "promoted_feature_mismatch"
    ),
    class = "ledgr_promote_identity_mismatch"
  )
  mismatch <- ledgr_promotion_context(mismatch_run)$identity_check
  close(mismatch_run)
  testthat::expect_true("feature_set_hash" %in% mismatch$mismatched)

  featureless <- ledgr_experiment(
    snapshot,
    ledgr_ws28_strategy,
    cost_model = ledgr_cost_zero()
  )
  featureless_sweep <- ledgr_sweep(
    featureless,
    ledgr_grid_named(a = list(strategy = list(qty = 1)), b = list(strategy = list(qty = 2)))
  )
  ledgr_sweep_save(featureless_sweep, snapshot, sweep_id = "featureless")

  multi_feature <- ledgr_experiment(
    snapshot,
    ledgr_ws28_strategy,
    features = list(ledgr_ind_sma(2L), ledgr_ind_returns(1L)),
    cost_model = ledgr_cost_zero()
  )
  multi_sweep <- ledgr_sweep(
    multi_feature,
    ledgr_grid_named(a = list(strategy = list(qty = 1)), b = list(strategy = list(qty = 2)))
  )
  ledgr_sweep_save(multi_sweep, snapshot, sweep_id = "multi_feature")

  con <- ledgr:::get_connection(snapshot)
  stored <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT sweep_id, candidate_row, feature_fingerprints_json",
      "FROM sweep_candidates",
      "ORDER BY sweep_id, candidate_row"
    )
  )
  testthat::expect_true(all(stored$feature_fingerprints_json[
    stored$sweep_id == "featureless"
  ] == "[]"))
  testthat::expect_identical(
    stored$feature_fingerprints_json[stored$sweep_id == "multi_feature"],
    vapply(
      multi_sweep$feature_fingerprints,
      function(x) as.character(canonical_json(x)),
      character(1)
    )
  )

  DBI::dbExecute(
    con,
    paste(
      "UPDATE sweep_candidates",
      "SET feature_fingerprints_json = '{bad'",
      "WHERE sweep_id = 'multi_feature' AND candidate_row = 1"
    )
  )
  testthat::expect_error(
    ledgr_sweep_open(snapshot, "multi_feature"),
    "Error parsing JSON",
    fixed = TRUE
  )

  malformed <- multi_sweep
  attr(malformed, "risk_plan_json") <- "{bad"
  testthat::expect_error(
    ledgr_sweep_save(malformed, snapshot, sweep_id = "malformed_supplied"),
    class = "ledgr_config_invalid_json"
  )
})
