# ledgr-test-file-profile: review

# Cut 19 Workstream 58: executable proof for the focused long-only
# minimum-variance article. The strategy is evaluated from the article's real
# source chunk so these checks protect the code readers see.

ws58_qmd_chunk <- function(label_name) {
  root <- ledgr_test_source_root()
  path <- file.path(root, "vignettes", "minimum-variance.qmd")
  testthat::skip_if_not(file.exists(path), "article sources not available during installed-package tests")
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  label <- grep(
    paste0("^#\\|\\s*label:\\s*", label_name, "\\s*$"),
    lines
  )
  testthat::expect_length(label, 1L)
  fence <- grep("^```\\s*$", lines)
  end <- fence[fence > label][1L]
  code <- lines[(label + 1L):(end - 1L)]
  code[!startsWith(code, "#|")]
}

ws58_strategy <- function() {
  testthat::skip_if_not_installed("quadprog")
  code <- ws58_qmd_chunk("strategy")
  env <- new.env(parent = globalenv())
  eval(parse(text = code, keep.source = FALSE), envir = env)
  env$min_variance
}

ws58_days <- function() {
  days <- seq(as.Date("2021-01-13"), as.Date("2021-04-09"), by = "day")
  days[!format(days, "%u") %in% c("6", "7")]
}

ws58_closes <- function(days = ws58_days()) {
  k <- seq_along(days)
  common <- 0.004 * sin(0.31 * k)
  returns <- cbind(
    AAA = 0.010 * sin(0.9 * k) + common,
    BBB = 0.012 * sin(1.7 * k + 1) + common,
    CCC = 0.015 * sin(2.3 * k + 2) + common,
    DDD = 0.020 * sin(0.55 * k + 3) + common
  )
  returns[1L, ] <- 0
  closes <- exp(apply(log1p(returns), 2L, cumsum))
  sweep(closes, 2L, c(50, 60, 70, 80), "*")
}

ws58_utc <- function(date) as.POSIXct(paste(date, "16:00:00"), tz = "UTC")

ws58_fixture <- function(closes, strategy, days = ws58_days(),
                         opening = ledgr_opening(cash = 100000),
                         membership = NULL) {
  ids <- colnames(closes)
  bars <- data.frame(
    instrument_id = rep(ids, each = length(days)),
    ts_utc = rep(ws58_utc(days), length(ids)),
    close = as.vector(closes),
    stringsAsFactors = FALSE
  )
  bars <- bars[!is.na(bars$close), , drop = FALSE]
  bars$open <- bars$high <- bars$low <- bars$close
  bars$volume <- 1000

  calendar <- seq(min(days), max(days), by = "day")
  is_open <- calendar %in% days
  sessions <- data.frame(
    session_date = calendar,
    status = ifelse(is_open, "open", "closed"),
    session_open = ifelse(is_open, "09:30:00", NA),
    session_close = ifelse(is_open, "16:00:00", NA)
  )
  if (is.null(membership)) {
    membership <- data.frame(
      effective_from = ws58_utc(days[[1L]] - 1),
      knowledge_time = ws58_utc(days[[1L]] - 1)
    )
    membership$members <- I(list(ids))
  }
  facts <- ledgr_facts(
    ledgr_facts_sessions(
      sessions,
      venue_id = "V",
      knowledge = "assume_effective"
    ),
    ledgr_facts_membership_snapshots(
      membership,
      universe_id = "u",
      complete = TRUE,
      knowledge = "assume_effective"
    )
  )
  snapshot <- ledgr_snapshot_from_df(
    bars,
    data.frame(instrument_id = ids),
    db_path = tempfile(fileext = ".duckdb"),
    facts = facts,
    price_basis = "split_adjusted"
  )
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    features = list(ledgr_ind_returns(1L)),
    universe = ledgr_universe_members("u"),
    cost_model = ledgr_cost_zero(),
    opening = opening
  )
  list(snapshot = snapshot, exp = experiment, days = days, closes = closes)
}

ws58_params <- function(values = list()) {
  utils::modifyList(
    list(
      lookback = 10L,
      min_instruments = 2L,
      covariance_shrinkage = 0.5,
      equity_fraction = 0.95
    ),
    values
  )
}

ws58_decide <- function(strategy, experiment, day, params = list()) {
  params <- ws58_params(params)
  ctx <- ledgr_pulse_snapshot(experiment, ts_utc = as.Date(day), params = params)
  on.exit(close(ctx), add = TRUE)
  result <- strategy(ctx, params)
  structured <- is.list(result) && !is.null(result$targets)
  list(
    target = if (structured) c(result$targets) else c(result),
    reason = if (structured && !is.null(result$intent_reason)) {
      result$intent_reason
    } else {
      NA_character_
    },
    hold = c(ctx$hold())
  )
}

ws58_window_returns <- function(closes, days, day, lookback, ids) {
  at <- match(as.Date(day), days)
  returns <- closes[-1L, , drop = FALSE] / closes[-nrow(closes), , drop = FALSE] - 1
  returns <- rbind(NA_real_, returns)
  returns[(at - lookback + 1L):at, ids, drop = FALSE]
}

ws58_long_only <- function(sigma) {
  n <- ncol(sigma)
  for (size in rev(seq_len(n))) {
    for (set in utils::combn(n, size, simplify = FALSE)) {
      inverse_one <- solve(sigma[set, set, drop = FALSE], rep(1, length(set)))
      if (any(inverse_one <= 0)) next
      weights <- numeric(n)
      weights[set] <- inverse_one / sum(inverse_one)
      lambda <- 1 / sum(inverse_one)
      gradient <- drop(sigma %*% weights)
      if (all(gradient[-set] >= lambda - 1e-12)) {
        return(stats::setNames(weights, colnames(sigma)))
      }
    }
  }
  stop("no long-only solution")
}

ws58_sigma <- function(returns, shrinkage) {
  sample <- stats::cov(returns)
  (1 - shrinkage) * sample + shrinkage * diag(diag(sample))
}

ws58_fill <- function(run, id, day) {
  fills <- as.data.frame(ledgr_results(run, "fills"))
  hit <- fills[
    fills$instrument_id == id & format(as.Date(fills$ts_utc)) == day,
    ,
    drop = FALSE
  ]
  if (nrow(hit) == 0L) return(NULL)
  list(side = hit$side, qty = hit$qty)
}

testthat::test_that("[LTB-0431] the strategy acts on month starts and writes sparse decision reasons", {
  strategy <- ws58_strategy()
  fixture <- ws58_fixture(ws58_closes(), strategy)
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  params <- ws58_params()

  seen <- lapply(fixture$days, function(day) {
    ws58_decide(strategy, fixture$exp, day, params)
  })
  reasons <- vapply(seen, `[[`, character(1L), "reason")
  decisions <- !is.na(reasons)
  testthat::expect_identical(
    format(fixture$days[decisions]),
    c("2021-01-13", "2021-02-01", "2021-03-01", "2021-04-01")
  )
  testthat::expect_identical(
    reasons[decisions],
    c("insufficient_sample", "rebalanced", "rebalanced", "rebalanced")
  )
  for (i in which(!decisions)) {
    testthat::expect_identical(seen[[i]]$target, seen[[i]]$hold)
  }

  run <- ledgr_run(fixture$exp, params = params, run_id = "ws58-schedule")
  on.exit(close(run), add = TRUE, after = FALSE)
  fills <- as.data.frame(ledgr_results(run, "fills"))
  testthat::expect_identical(
    sort(unique(format(as.Date(fills$ts_utc)))),
    c("2021-02-02", "2021-03-02", "2021-04-02")
  )

  read_reasons <- function(x) {
    diagnostics <- as.data.frame(ledgr_results(x, "diagnostics"))
    intent <- diagnostics[diagnostics$reason_code == "strategy_intent", , drop = FALSE]
    vapply(
      intent$detail_json,
      function(json) ledgr:::ledgr_json_read_nested(json)$intent_reason,
      character(1L)
    )
  }
  live <- read_reasons(run)
  testthat::expect_identical(
    unname(live),
    c("insufficient_sample", "rebalanced", "rebalanced", "rebalanced")
  )
  reopened <- ledgr_run_open(fixture$snapshot, "ws58-schedule")
  on.exit(close(reopened), add = TRUE, after = FALSE)
  testthat::expect_identical(read_reasons(reopened), live)
})

testthat::test_that("[LTB-0433] incomplete return windows are excluded and receive zero targets", {
  strategy <- ws58_strategy()
  days <- ws58_days()
  closes <- ws58_closes(days)
  closes[days %in% as.Date(c("2021-02-18", "2021-02-22")), "DDD"] <- NA
  fixture <- ws58_fixture(closes, strategy)
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)

  decision <- ws58_decide(strategy, fixture$exp, "2021-03-01")
  testthat::expect_identical(decision$reason, "rebalanced")
  testthat::expect_identical(unname(decision$target[["DDD"]]), 0)
  testthat::expect_gt(sum(decision$target[c("AAA", "BBB", "CCC")]), 0)

  ctx <- ledgr_pulse_snapshot(
    fixture$exp,
    ts_utc = as.Date("2021-03-01"),
    params = ws58_params()
  )
  on.exit(close(ctx), add = TRUE)
  returns <- ledgr_history_matrix(
    ctx,
    feature = "return_1",
    lookback = 10L,
    min_instruments = 2L
  )
  testthat::expect_identical(ledgr_history_info(returns)$included_ids, c("AAA", "BBB", "CCC"))
})

testthat::test_that("[LTB-0435] the article solves the constrained long-only minimum", {
  strategy <- ws58_strategy()
  closes <- ws58_closes()
  leader_return <- c(0, diff(log(closes[, "AAA"])))
  redundant_return <- 3 * leader_return +
    0.0001 * sin(seq_along(leader_return))
  closes[, "CCC"] <- closes[1L, "CCC"] * exp(cumsum(redundant_return))
  fixture <- ws58_fixture(closes, strategy)
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  params <- ws58_params()

  decision <- ws58_decide(strategy, fixture$exp, "2021-03-01", params)
  testthat::expect_identical(decision$reason, "rebalanced")

  ids <- colnames(fixture$closes)
  returns <- ws58_window_returns(
    fixture$closes,
    fixture$days,
    "2021-03-01",
    params$lookback,
    ids
  )
  sigma <- ws58_sigma(returns, params$covariance_shrinkage)
  weights <- ws58_long_only(sigma)
  unconstrained <- solve(sigma, rep(1, ncol(sigma)))
  unconstrained <- unconstrained / sum(unconstrained)
  clipped <- pmax(unconstrained, 0)
  clipped <- clipped / sum(clipped)
  prices <- fixture$closes[match(as.Date("2021-03-01"), fixture$days), ids]
  expected <- floor(weights * params$equity_fraction * 100000 / prices)
  clipped_target <- floor(clipped * params$equity_fraction * 100000 / prices)
  testthat::expect_lte(max(abs(decision$target[ids] - expected)), 1)
  testthat::expect_lt(unconstrained[["CCC"]], 0)
  testthat::expect_equal(unname(weights[["CCC"]]), 0, tolerance = 1e-12)
  testthat::expect_gt(max(abs(decision$target[ids] - clipped_target)), 1)
  testthat::expect_true(all(weights >= 0))
  testthat::expect_equal(sum(weights), 1, tolerance = 1e-12)
})

testthat::test_that("[LTB-0436] sample insufficiency holds and genuine optimizer errors are not swallowed", {
  strategy <- ws58_strategy()
  fixture <- ws58_fixture(ws58_closes(), strategy)
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)

  early <- ws58_decide(strategy, fixture$exp, "2021-01-13")
  testthat::expect_identical(early$reason, "insufficient_sample")
  testthat::expect_identical(early$target, early$hold)

  membership <- data.frame(
    effective_from = ws58_utc(ws58_days()[[1L]] - 1),
    knowledge_time = ws58_utc(ws58_days()[[1L]] - 1)
  )
  membership$members <- I(list("AAA"))
  one <- ws58_fixture(ws58_closes(), strategy, membership = membership)
  on.exit(ledgr_snapshot_close(one$snapshot), add = TRUE)
  one_decision <- ws58_decide(
    strategy,
    one$exp,
    "2021-03-01",
    list(min_instruments = 1L)
  )
  testthat::expect_identical(one_decision$reason, "rebalanced")
  testthat::expect_gt(one_decision$target[["AAA"]], 0)

  body <- paste(deparse(body(strategy)), collapse = "\n")
  testthat::expect_false(grepl("tryCatch", body, fixed = TRUE))
  testthat::expect_match(body, "stop(\"The optimizer returned invalid long-only weights.\")", fixed = TRUE)
})

testthat::test_that("[LTB-0437] the article teaches one focused causal optimization path", {
  root <- ledgr_test_source_root()
  qmd_path <- file.path(root, "vignettes", "minimum-variance.qmd")
  md_path <- file.path(root, "vignettes", "minimum-variance.md")
  horizon_path <- file.path(root, "inst", "design", "horizon.md")
  testthat::skip_if_not(file.exists(qmd_path), "article sources not available during installed-package tests")
  qmd <- paste(readLines(qmd_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  markdown <- paste(readLines(md_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  horizon <- paste(readLines(horizon_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  strategy <- ws58_strategy()
  symbols <- all.names(body(strategy), functions = TRUE, unique = FALSE)
  testthat::expect_identical(sum(symbols == "ledgr_history_matrix"), 1L)
  testthat::expect_identical(sum(symbols == "ledgr_history_info"), 0L)
  testthat::expect_identical(sum(symbols == "ledgr_passed_warmup"), 1L)
  testthat::expect_identical(sum(symbols == "ledgr_align_weights"), 1L)
  testthat::expect_identical(sum(symbols == "ledgr_target_rebalance"), 1L)

  choices <- c(
    "lookback",
    "min_instruments",
    "covariance_shrinkage",
    "equity_fraction"
  )
  body <- paste(deparse(body(strategy)), collapse = "\n")
  for (choice in choices) {
    testthat::expect_match(body, paste0("params$", choice), fixed = TRUE)
  }
  params_env <- new.env(parent = baseenv())
  eval(parse(text = ws58_qmd_chunk("strategy-params")), envir = params_env)
  testthat::expect_named(params_env$strategy_params, choices, ignore.order = FALSE)

  forbidden <- c(
    "carry_threshold",
    "keep_excluded",
    "held_excluded",
    "not_a_decision_date",
    "too_few_instruments",
    "solver_failure",
    "insufficient_history"
  )
  for (word in forbidden) testthat::expect_false(grepl(word, qmd, fixed = TRUE), info = word)
  for (word in c(
    "intent_reason = \"insufficient_sample\"",
    "intent_reason = \"rebalanced\"",
    "ledgr_align_weights(returns)",
    "targets[!ctx$vec$member] <- 0",
    "Amat = cbind(rep(1, n), diag(n))",
    "bvec = c(1, rep(0, n))",
    "meq = 1L",
    "vignette(\"execution-semantics\", package = \"ledgr\")",
    "`DEMO_08` has",
    "a zero target"
  )) {
    testthat::expect_match(qmd, word, fixed = TRUE)
  }
  testthat::expect_match(qmd, "This\\s+is exploration, not validation")
  testthat::expect_match(markdown, "[1] 252   7", fixed = TRUE)
  testthat::expect_match(markdown, "[1] 24", fixed = TRUE)
  testthat::expect_match(horizon, "Advanced portfolio-construction teaching arc", fixed = TRUE)

  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_identical(preflight$tier, "tier_2")
  testthat::expect_identical(preflight$worker_dependencies$require_namespace, "quadprog")
})

testthat::test_that("[LTB-0440] a held index leaver is sold on the next solved decision", {
  strategy <- ws58_strategy()
  days <- ws58_days()
  membership <- data.frame(
    effective_from = c(ws58_utc(days[[1L]] - 1), ws58_utc(as.Date("2021-02-15"))),
    knowledge_time = c(ws58_utc(days[[1L]] - 1), ws58_utc(as.Date("2021-02-15")))
  )
  membership$members <- I(list(c("AAA", "BBB", "CCC", "DDD"), c("AAA", "BBB", "CCC")))
  fixture <- ws58_fixture(ws58_closes(days), strategy, membership = membership)
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)

  run <- ledgr_run(fixture$exp, params = ws58_params(), run_id = "ws58-leaver")
  on.exit(close(run), add = TRUE, after = FALSE)
  bought <- ws58_fill(run, "DDD", "2021-02-02")
  sold <- ws58_fill(run, "DDD", "2021-03-02")
  testthat::expect_identical(bought$side, "BUY")
  testthat::expect_gt(bought$qty, 0)
  testthat::expect_identical(sold$side, "SELL")
  testthat::expect_identical(sold$qty, bought$qty)
  testthat::expect_null(ws58_fill(run, "DDD", "2021-04-02"))
})
