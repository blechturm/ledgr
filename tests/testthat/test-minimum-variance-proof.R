# ledgr-test-file-profile: review

# Cut 17 Workstream 48 (LDG-3082, LDG-3083): the long-only minimum-variance
# proof. The strategy under test is the `strategy` chunk of
# vignettes/minimum-variance.qmd, read from the source tree, so the blocks
# test exactly the function the article runs.

# The article's strategy function, evaluated from its source chunk.
ws48_strategy <- function() {
  root <- ledgr_test_source_root()
  path <- file.path(root, "vignettes", "minimum-variance.qmd")
  testthat::skip_if_not(file.exists(path), "article sources not available during installed-package tests")
  testthat::skip_if_not_installed("quadprog")
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  label <- grep("^#\\|\\s*label:\\s*strategy\\s*$", lines)
  testthat::expect_length(label, 1L)
  fence <- grep("^```\\s*$", lines)
  end <- fence[fence > label][1L]
  code <- lines[(label + 1L):(end - 1L)]
  code <- code[!startsWith(code, "#|")]
  env <- new.env(parent = globalenv())
  eval(parse(text = code, keep.source = FALSE), envir = env)
  env$min_variance
}

# Weekday sessions from Wednesday 13 January to Friday 9 April 2021. The
# month starts are 2021-01-13 (the data start), 2021-02-01, 2021-03-01 and
# 2021-04-01.
ws48_days <- function() {
  days <- seq(as.Date("2021-01-13"), as.Date("2021-04-09"), by = "day")
  days[!format(days, "%u") %in% c("6", "7")]
}

# Deterministic closes: each instrument compounds its own sine returns plus a
# common one, from 50, 60, 70 and 80.
ws48_closes <- function(days = ws48_days()) {
  k <- seq_along(days)
  common <- 0.004 * sin(0.31 * k)
  r <- cbind(
    AAA = 0.010 * sin(0.9 * k) + common,
    BBB = 0.012 * sin(1.7 * k + 1) + common,
    CCC = 0.015 * sin(2.3 * k + 2) + common,
    DDD = 0.020 * sin(0.55 * k + 3) + common
  )
  r[1L, ] <- 0
  closes <- exp(apply(log1p(r), 2L, cumsum))
  sweep(closes, 2L, c(50, 60, 70, 80), "*")
}

ws48_utc <- function(d) as.POSIXct(paste(d, "16:00:00"), tz = "UTC")

# One availability-aware experiment over the given closes (NA = no print).
ws48_fixture <- function(closes, strategy, days = ws48_days(),
                         opening = ledgr_opening(cash = 100000),
                         policy = ledgr_history_policy(), status = NULL,
                         valuation = NULL, membership = NULL) {
  ids <- colnames(closes)
  bars <- data.frame(
    instrument_id = rep(ids, each = length(days)),
    ts_utc = rep(ws48_utc(days), length(ids)),
    close = as.vector(closes),
    stringsAsFactors = FALSE
  )
  bars <- bars[!is.na(bars$close), , drop = FALSE]
  bars$open <- bars$high <- bars$low <- bars$close
  bars$volume <- 1000
  calendar <- seq(min(days), max(days), by = "day")
  open <- calendar %in% days
  sessions <- data.frame(
    session_date = calendar, status = ifelse(open, "open", "closed"),
    session_open = ifelse(open, "09:30:00", NA), session_close = ifelse(open, "16:00:00", NA)
  )
  if (is.null(membership)) {
    membership <- data.frame(
      effective_from = ws48_utc(days[[1L]] - 1), knowledge_time = ws48_utc(days[[1L]] - 1)
    )
    membership$members <- I(list(ids))
  }
  families <- list(
    ledgr_facts_sessions(sessions, venue_id = "V", knowledge = "assume_effective"),
    ledgr_facts_membership_snapshots(
      membership, universe_id = "u", complete = TRUE, knowledge = "assume_effective"
    )
  )
  if (!is.null(status)) {
    families <- c(families, list(ledgr_facts_trading_status(status, knowledge = "evidenced")))
  }
  snapshot <- ledgr_snapshot_from_df(
    bars, data.frame(instrument_id = ids),
    db_path = tempfile(fileext = ".duckdb"), facts = do.call(ledgr_facts, families),
    price_basis = "split_adjusted"
  )
  exp <- ledgr_experiment(
    snapshot, strategy,
    features = list(ledgr_ind_returns(1L)),
    universe = ledgr_universe_members("u"),
    cost_model = ledgr_cost_zero(),
    opening = opening,
    valuation_policy = valuation,
    history_policy = policy
  )
  list(snapshot = snapshot, exp = exp, days = days, closes = closes)
}

# Independent oracle. Daily returns of the window ending at `day`: a return
# exists only where the session and the previous session both printed.
ws48_window_returns <- function(closes, days, day, lookback, ids) {
  at <- match(as.Date(day), days)
  r <- closes[-1L, , drop = FALSE] / closes[-nrow(closes), , drop = FALSE] - 1
  r <- rbind(NA_real_, r)
  r[(at - lookback + 1L):at, ids, drop = FALSE]
}

# Long-only minimum variance by enumerating active sets: the solution is the
# set whose equality-constrained weights are all positive and whose excluded
# instruments have a marginal variance no lower than the multiplier.
ws48_long_only <- function(sigma) {
  n <- ncol(sigma)
  for (size in rev(seq_len(n))) {
    for (set in utils::combn(n, size, simplify = FALSE)) {
      x <- solve(sigma[set, set, drop = FALSE], rep(1, length(set)))
      if (any(x <= 0)) next
      w <- numeric(n)
      w[set] <- x / sum(x)
      lambda <- 1 / sum(x)
      gradient <- drop(sigma %*% w)
      if (all(gradient[-set] >= lambda - 1e-12)) return(stats::setNames(w, colnames(sigma)))
    }
  }
  stop("no long-only solution")
}

ws48_sigma <- function(x, shrink) {
  sigma <- stats::cov(x, use = "pairwise.complete.obs")
  (1 - shrink) * sigma + shrink * diag(diag(sigma))
}

# Expected share targets of the estimated instruments at `day` for a flat
# 100,000 book (or the allocatable equity given).
ws48_expected <- function(fx, day, ids, lookback, shrink, allocatable = 100000) {
  x <- ws48_window_returns(fx$closes, fx$days, day, lookback, ids)
  w <- ws48_long_only(ws48_sigma(x, shrink))
  price <- fx$closes[match(as.Date(day), fx$days), ids]
  floor(w * 0.95 * allocatable / price)
}

ws48_decide <- function(strategy, exp, day, params) {
  ctx <- ledgr_pulse_snapshot(exp, ts_utc = as.Date(day), params = params)
  on.exit(close(ctx), add = TRUE)
  target <- strategy(ctx, params)
  list(target = c(target), outcome = attr(target, "outcome"), hold = c(ctx$hold()))
}

ws48_fill_days <- function(bt, id = NULL) {
  fills <- as.data.frame(ledgr_results(bt, "fills"))
  if (!is.null(id)) fills <- fills[fills$instrument_id == id, , drop = FALSE]
  fills
}

testthat::test_that("[LTB-0431] the estimator decides on literal month starts, the data start included, and holds on every other pulse", {
  strategy <- ws48_strategy()
  fx <- ws48_fixture(ws48_closes(), strategy)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  params <- list(lookback = 10L, min_obs = 5L)

  outcomes <- character(length(fx$days))
  for (i in seq_along(fx$days)) {
    seen <- ws48_decide(strategy, fx$exp, fx$days[[i]], params)
    outcomes[[i]] <- seen$outcome
    if (identical(seen$outcome, "not_a_decision_date")) {
      testthat::expect_identical(seen$target, seen$hold, info = format(fx$days[[i]]))
    } else {
      testthat::expect_false(identical(seen$outcome, "solved") && identical(seen$target, seen$hold),
                             info = format(fx$days[[i]]))
    }
  }
  decisions <- format(fx$days[outcomes != "not_a_decision_date"])
  testthat::expect_identical(decisions, c("2021-01-13", "2021-02-01", "2021-03-01", "2021-04-01"))
  # The data start is a decision date that holds for want of ten sessions.
  testthat::expect_identical(
    outcomes[outcomes != "not_a_decision_date"],
    c("insufficient_history", "solved", "solved", "solved")
  )
  testthat::expect_identical(sum(outcomes == "not_a_decision_date"), length(fx$days) - 4L)

  # In a run, fills follow only the solved decisions, at the next open.
  bt <- ledgr_run(fx$exp, params = params, run_id = "ws48-dates")
  on.exit(close(bt), add = TRUE, after = FALSE)
  fills <- ws48_fill_days(bt)
  testthat::expect_identical(
    sort(unique(format(as.Date(fills$ts_utc)))),
    c("2021-02-02", "2021-03-02", "2021-04-02")
  )
})

testthat::test_that("[LTB-0432] the weights change when one instrument's carried share crosses the threshold, in both directions", {
  strategy <- ws48_strategy()
  closes <- ws48_closes()
  days <- ws48_days()
  # CCC has no print on 18, 22 and 24 February. The ten-session window that
  # ends on 1 March (16 February to 1 March) then holds three carried closes:
  # a carried share of 0.3. The windows ending 1 February and 1 April hold
  # none.
  closes[days %in% as.Date(c("2021-02-18", "2021-02-22", "2021-02-24")), "CCC"] <- NA
  fx <- ws48_fixture(closes, strategy)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  params <- list(lookback = 10L, min_obs = 3L, threshold = 0.2, shrink = 0.5)
  all_ids <- c("AAA", "BBB", "CCC", "DDD")

  share <- function(day) {
    ctx <- ledgr_pulse_snapshot(fx$exp, ts_utc = as.Date(day), params = params)
    on.exit(close(ctx), add = TRUE)
    selection <- ledgr_history_info(ledgr_history_frame(ctx, bar = "close", lookback = 10L))$selection
    stats::setNames(selection$carried_input_share, selection$instrument_id)[["CCC"]]
  }
  testthat::expect_identical(share("2021-02-01"), 0)
  testthat::expect_equal(share("2021-03-01"), 0.3)
  testthat::expect_identical(share("2021-04-01"), 0)

  # Below the threshold, CCC is estimated; above it, it is not and the other
  # weights are re-estimated without it; below it again, it returns.
  feb <- ws48_decide(strategy, fx$exp, "2021-02-01", params)
  mar <- ws48_decide(strategy, fx$exp, "2021-03-01", params)
  apr <- ws48_decide(strategy, fx$exp, "2021-04-01", params)
  testthat::expect_identical(c(feb$outcome, mar$outcome, apr$outcome), rep("solved", 3L))
  expect_targets <- function(seen, day, ids) {
    expected <- ws48_expected(fx, day, ids, lookback = 10L, shrink = 0.5)
    testthat::expect_lte(max(abs(seen$target[ids] - expected)), 1, label = day)
    testthat::expect_identical(unname(seen$target[setdiff(all_ids, ids)]),
                               rep(0, length(setdiff(all_ids, ids))))
  }
  expect_targets(feb, "2021-02-01", all_ids)
  expect_targets(mar, "2021-03-01", c("AAA", "BBB", "DDD"))
  expect_targets(apr, "2021-04-01", all_ids)
  testthat::expect_gt(feb$target[["CCC"]], 0)
  testthat::expect_identical(mar$target[["CCC"]], 0)
  testthat::expect_gt(apr$target[["CCC"]], 0)

  # Moving the threshold across the same share flips the same decision.
  loose <- ws48_decide(strategy, fx$exp, "2021-03-01", utils::modifyList(params, list(threshold = 0.35)))
  expect_targets(loose, "2021-03-01", all_ids)
  testthat::expect_gt(loose$target[["CCC"]], 0)
  testthat::expect_gt(max(abs(loose$target[c("AAA", "BBB", "DDD")] - mar$target[c("AAA", "BBB", "DDD")])), 1)
  # At the boundary the share (3/10) equals the threshold, and an instrument
  # whose share is at most the threshold is estimated (close review 48 F2).
  boundary <- ws48_decide(strategy, fx$exp, "2021-03-01", utils::modifyList(params, list(threshold = 0.3)))
  testthat::expect_identical(boundary$outcome, "solved")
  testthat::expect_gt(boundary$target[["CCC"]], 0)
  expect_targets(boundary, "2021-03-01", all_ids)
})

testthat::test_that("[LTB-0433] an instrument with fewer than min_obs valid returns is excluded and, if held, kept", {
  strategy <- ws48_strategy()
  closes <- ws48_closes()
  days <- ws48_days()
  # Without input carry, DDD's five missing sessions (17 to 23 February) and
  # the restart after them leave four valid returns in the ten-session window
  # ending 1 March: 16 February, 25 and 26 February and 1 March.
  closes[days %in% as.Date(c("2021-02-17", "2021-02-18", "2021-02-19", "2021-02-22", "2021-02-23")), "DDD"] <- NA
  no_carry <- ledgr_history_policy(price_carry = NULL)
  flat <- ws48_fixture(closes, strategy, policy = no_carry)
  on.exit(ledgr_snapshot_close(flat$snapshot), add = TRUE)
  held <- ws48_fixture(
    closes, strategy, policy = no_carry,
    opening = ledgr_opening(cash = 100000, positions = c(DDD = 100), cost_basis = c(DDD = 80))
  )
  on.exit(ledgr_snapshot_close(held$snapshot), add = TRUE)
  params <- list(lookback = 10L, min_obs = 5L, shrink = 0.5)

  ctx <- ledgr_pulse_snapshot(flat$exp, ts_utc = as.Date("2021-03-01"), params = params)
  returns <- ledgr_history_frame(ctx, feature = "return_1", lookback = 10L, na_action = "keep")
  valid <- colSums(is.finite(ledgr_history_matrix(returns)))
  close(ctx)
  testthat::expect_identical(unname(valid), c(10, 10, 10, 4))
  testthat::expect_identical(ledgr_history_info(returns)$included_ids, c("AAA", "BBB", "CCC", "DDD"))

  estimated <- c("AAA", "BBB", "CCC")
  expected <- ws48_expected(flat, "2021-03-01", estimated, lookback = 10L, shrink = 0.5)
  excluded <- ws48_decide(strategy, flat$exp, "2021-03-01", params)
  testthat::expect_identical(excluded$outcome, "solved")
  testthat::expect_lte(max(abs(excluded$target[estimated] - expected)), 1)
  testthat::expect_identical(excluded$target[["DDD"]], 0)

  # Held: DDD keeps its 100 shares, and the rest is sized on the equity left
  # after DDD's marked value, which is the same 100,000 cash.
  kept <- ws48_decide(strategy, held$exp, "2021-03-01", params)
  testthat::expect_identical(kept$outcome, "solved")
  testthat::expect_identical(kept$target[["DDD"]], 100)
  testthat::expect_lte(max(abs(kept$target[estimated] - expected)), 1)
  # Without keep, the held instrument is targeted to zero.
  sold <- ws48_decide(strategy, held$exp, "2021-03-01", utils::modifyList(params, list(keep_excluded = FALSE)))
  testthat::expect_identical(sold$target[["DDD"]], 0)
  # One valid return fewer required, and DDD is estimated again.
  included <- ws48_decide(strategy, flat$exp, "2021-03-01", utils::modifyList(params, list(min_obs = 4L)))
  testthat::expect_gt(included$target[["DDD"]], 0)
})

testthat::test_that("[LTB-0434] a held instrument outside the estimate keeps its quantity with keep and is liquidated without it", {
  strategy <- ws48_strategy()
  days <- ws48_days()
  # Screen exclusion: CCC's carried share is 0.3 on 1 March (as in LTB-0432).
  closes <- ws48_closes()
  closes[days %in% as.Date(c("2021-02-18", "2021-02-22", "2021-02-24")), "CCC"] <- NA
  fx <- ws48_fixture(closes, strategy)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  params <- list(lookback = 10L, min_obs = 3L, threshold = 0.2)
  kept <- ledgr_run(fx$exp, params = params, run_id = "ws48-keep")
  on.exit(close(kept), add = TRUE, after = FALSE)
  sold <- ledgr_run(fx$exp, params = utils::modifyList(params, list(keep_excluded = FALSE)),
                    run_id = "ws48-no-keep")
  on.exit(close(sold), add = TRUE, after = FALSE)
  ccc <- function(bt) {
    fills <- ws48_fill_days(bt, "CCC")
    data.frame(day = format(as.Date(fills$ts_utc)), side = fills$side, qty = fills$qty)
  }
  bought <- ccc(kept)$qty[ccc(kept)$day == "2021-02-02"]
  testthat::expect_length(bought, 1L)
  testthat::expect_identical(ccc(kept)$side[[1L]], "BUY")
  # With keep, CCC is not traded at the 1 March decision.
  testthat::expect_false("2021-03-02" %in% ccc(kept)$day)
  # Without keep, the whole position is sold at the next open and bought back
  # after the April decision.
  testthat::expect_identical(ccc(sold)$qty[ccc(sold)$day == "2021-02-02"], bought)
  march <- ccc(sold)[ccc(sold)$day == "2021-03-02", ]
  testthat::expect_identical(march$side, "SELL")
  testthat::expect_identical(march$qty, bought)
  testthat::expect_identical(ccc(sold)$side[ccc(sold)$day == "2021-04-02"], "BUY")

  # History exclusion: BBB is halted over 1 March, so it is not admissible and
  # not requested. It is held from February and keeps its quantity with keep;
  # without keep the rebalance preserves a restricted holding as well.
  halt <- data.frame(
    instrument_id = c("AAA", "BBB", "CCC", "DDD", "BBB"),
    effective_from = c(rep(ws48_utc(days[[1L]]), 4L), ws48_utc(as.Date("2021-02-26"))),
    effective_to = c(rep(as.POSIXct(NA, tz = "UTC"), 4L), ws48_utc(as.Date("2021-03-03"))),
    knowledge_time = rep(ws48_utc(days[[1L]] - 1), 5L),
    status = c(rep("active", 4L), "halted"),
    precedence = c(rep(0L, 4L), 1L),
    source = "ws48"
  )
  halted <- ws48_closes()
  halted[days %in% as.Date(c("2021-03-01", "2021-03-02")), "BBB"] <- NA
  hx <- ws48_fixture(halted, strategy, status = halt)
  on.exit(ledgr_snapshot_close(hx$snapshot), add = TRUE)
  ctx <- ledgr_pulse_snapshot(hx$exp, ts_utc = as.Date("2021-03-01"), params = params)
  testthat::expect_false(ctx$vec$admissible[match("BBB", ctx$universe)])
  close(ctx)
  for (keep_excluded in c(TRUE, FALSE)) {
    bt <- ledgr_run(hx$exp, params = utils::modifyList(params, list(keep_excluded = keep_excluded)),
                    run_id = paste0("ws48-halt-", keep_excluded))
    fills <- ws48_fill_days(bt, "BBB")
    close(bt)
    days_traded <- format(as.Date(fills$ts_utc))
    testthat::expect_true("2021-02-02" %in% days_traded, info = keep_excluded)
    testthat::expect_false(any(days_traded %in% c("2021-03-02", "2021-03-03")), info = keep_excluded)
  }
})

testthat::test_that("[LTB-0435] the constrained solution meets the long-only optimality conditions where clipping does not", {
  strategy <- ws48_strategy()
  days <- ws48_days()
  closes <- ws48_closes()
  # CCC moves as 1.5 times AAA's return plus a small independent term, so the
  # unconstrained minimum-variance portfolio sells CCC short.
  k <- seq_along(days)
  r_aaa <- c(0, closes[-1L, "AAA"] / closes[-nrow(closes), "AAA"] - 1)
  r_ccc <- 1.5 * r_aaa + 0.002 * sin(2.9 * k + 0.5)
  r_ccc[[1L]] <- 0
  closes[, "CCC"] <- 70 * cumprod(1 + r_ccc)
  fx <- ws48_fixture(closes, strategy)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  params <- list(lookback = 20L, min_obs = 10L, shrink = 0.05)
  ids <- c("AAA", "BBB", "CCC", "DDD")

  x <- ws48_window_returns(closes, days, "2021-03-01", 20L, ids)
  sigma <- ws48_sigma(x, 0.05)
  w <- ws48_long_only(sigma)
  unconstrained <- solve(sigma, rep(1, 4L))
  unconstrained <- unconstrained / sum(unconstrained)
  testthat::expect_lt(unconstrained[[3L]], 0)
  testthat::expect_identical(w[["CCC"]], 0)
  # Optimality conditions: equal marginal variance on the held set, no lower
  # on CCC, weights non-negative and summing to one.
  gradient <- drop(sigma %*% w)
  lambda <- gradient[w > 0][[1L]]
  testthat::expect_equal(unname(gradient[w > 0]), rep(lambda, sum(w > 0)), tolerance = 1e-10)
  testthat::expect_gte(gradient[["CCC"]], lambda)
  testthat::expect_equal(sum(w), 1)

  seen <- ws48_decide(strategy, fx$exp, "2021-03-01", params)
  testthat::expect_identical(seen$outcome, "solved")
  price <- closes[match(as.Date("2021-03-01"), days), ids]
  expected <- floor(w * 0.95 * 100000 / price)
  testthat::expect_lte(max(abs(seen$target[ids] - expected)), 1)
  testthat::expect_identical(seen$target[["CCC"]], 0)
  # Clipping the unconstrained solution would buy a different portfolio.
  clipped <- pmax(unconstrained, 0)
  clipped <- floor(clipped / sum(clipped) * 0.95 * 100000 / price)
  testthat::expect_gt(max(abs(seen$target[ids] - clipped)), 1)
})

testthat::test_that("[LTB-0436] estimation failures and unvalued holdings hold instead of erroring or returning a partial target", {
  strategy <- ws48_strategy()
  days <- ws48_days()
  params <- list(lookback = 10L, min_obs = 5L)

  # A covariance the eigenvalue floor cannot repair (Cut 17 decision 20):
  # without input carry, CCC has valid returns only on 24-26 February and
  # 1 March and DDD only on 16-22 February inside the ten-session window
  # ending 1 March, so the pair shares no return and its covariance is
  # missing. The decision holds and the run completes without a fill then.
  disjoint <- ws48_closes()
  disjoint[days %in% as.Date(c("2021-02-15", "2021-02-16", "2021-02-17", "2021-02-18",
                               "2021-02-19", "2021-02-22")), "CCC"] <- NA
  disjoint[days %in% as.Date(c("2021-02-23", "2021-02-24", "2021-02-25", "2021-02-26")), "DDD"] <- NA
  cx <- ws48_fixture(disjoint, strategy, policy = ledgr_history_policy(price_carry = NULL))
  on.exit(ledgr_snapshot_close(cx$snapshot), add = TRUE)
  missing_params <- list(lookback = 10L, min_obs = 4L)
  seen <- ws48_decide(strategy, cx$exp, "2021-03-01", missing_params)
  testthat::expect_identical(seen$outcome, "covariance_not_positive_definite")
  testthat::expect_identical(seen$target, seen$hold)
  bt <- ledgr_run(cx$exp, params = missing_params, run_id = "ws48-singular")
  on.exit(close(bt), add = TRUE, after = FALSE)
  testthat::expect_identical(ledgr_run_completion(bt)$completion_status, "DONE")
  testthat::expect_false("2021-03-02" %in% format(as.Date(ws48_fill_days(bt)$ts_utc)))

  # A solver that fails, or returns an unusable solution, holds.
  fx <- ws48_fixture(ws48_closes(), strategy)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  broken <- list(
    error = function(...) stop("solver failed"),
    not_finite = function(Dmat, ...) list(solution = rep(NaN, ncol(Dmat))),
    negative = function(Dmat, ...) list(solution = c(1.5, -0.5, rep(0, ncol(Dmat) - 2L)))
  )
  for (case in names(broken)) {
    local({
      testthat::local_mocked_bindings(solve.QP = broken[[case]], .package = "quadprog")
      seen <- ws48_decide(strategy, fx$exp, "2021-03-01", params)
      testthat::expect_identical(seen$outcome, "solver_failure", info = case)
      testthat::expect_identical(seen$target, seen$hold, info = case)
    })
  }
  # A solution inside the tolerances whose clipped weights would sum above
  # the rebalance's leverage limit is renormalised and solved, not an error
  # (close review 48 F6).
  local({
    testthat::local_mocked_bindings(
      solve.QP = function(Dmat, ...) {
        list(solution = c(0.5 + 0.9e-8, 0.5 + 0.9e-8, -0.9e-8, rep(0, ncol(Dmat) - 3L)))
      },
      .package = "quadprog"
    )
    seen <- ws48_decide(strategy, fx$exp, "2021-03-01", params)
    testthat::expect_identical(seen$outcome, "solved")
    testthat::expect_gt(seen$target[["AAA"]], 0)
  })

  # A holding the rebalance must value without a permissible mark. A run
  # never reaches the strategy with one (see the run below), so the context
  # is edited: DDD is held and kept (it fails min_obs as in LTB-0433), or AAA
  # is held and weighted without a current close; neither has a mark.
  gap <- ws48_closes()
  gap[days %in% as.Date(c("2021-02-17", "2021-02-18", "2021-02-19", "2021-02-22", "2021-02-23")), "DDD"] <- NA
  book <- ws48_fixture(
    gap, strategy, policy = ledgr_history_policy(price_carry = NULL),
    opening = ledgr_opening(cash = 100000, positions = c(AAA = 50, DDD = 100),
                            cost_basis = c(AAA = 50, DDD = 80))
  )
  on.exit(ledgr_snapshot_close(book$snapshot), add = TRUE)
  unvalued <- function(edit) {
    ctx <- ledgr_pulse_snapshot(book$exp, ts_utc = as.Date("2021-03-01"), params = params)
    on.exit(close(ctx), add = TRUE)
    ctx$vec <- edit(ctx$vec, match(c("AAA", "DDD"), ctx$universe))
    target <- strategy(ctx, params)
    list(outcome = attr(target, "outcome"), target = c(target), hold = c(ctx$hold()))
  }
  kept <- unvalued(function(vec, at) {
    vec$risk_mark[at[[2L]]] <- NA_real_
    vec
  })
  testthat::expect_identical(kept$outcome, "no_permissible_mark")
  testthat::expect_identical(kept$target, kept$hold)
  weighted <- unvalued(function(vec, at) {
    vec$close[at[[1L]]] <- NA_real_
    vec$risk_mark[at[[1L]]] <- NA_real_
    vec
  })
  testthat::expect_identical(weighted$outcome, "no_permissible_mark")
  testthat::expect_identical(weighted$target, weighted$hold)

  # In a run, a holding without any mark stops the run before the strategy
  # is asked: DDD has no print before 1 February.
  # A counting strategy shows the stop comes before the strategy is called
  # (close review 48 F3).
  late <- ws48_closes()
  late[days < as.Date("2021-02-01"), "DDD"] <- NA
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  counted <- function(ctx, params) {
    calls$n <- calls$n + 1L
    ctx$hold()
  }
  lx <- ws48_fixture(
    late, counted,
    opening = ledgr_opening(cash = 100000, positions = c(DDD = 100), cost_basis = c(DDD = 80))
  )
  on.exit(ledgr_snapshot_close(lx$snapshot), add = TRUE)
  stopped <- ledgr_run(lx$exp, params = params, run_id = "ws48-unvalued")
  on.exit(close(stopped), add = TRUE, after = FALSE)
  completion <- ledgr_run_completion(stopped)
  testthat::expect_identical(completion$completion_status, "INCOMPLETE")
  testthat::expect_identical(completion$stop_reason, "valuation_horizon_exhausted")
  testthat::expect_identical(calls$n, 0L)
})

# R chunks of a Quarto source: label, options and code.
ws48_qmd_chunks <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  opens <- grep("^```\\{r\\}\\s*$", lines)
  closes <- grep("^```\\s*$", lines)
  lapply(opens, function(open) {
    close <- closes[closes > open][1L]
    body <- if (close > open + 1L) lines[(open + 1L):(close - 1L)] else character()
    options <- body[startsWith(body, "#|")]
    label <- sub("^#\\|\\s*label:\\s*", "", grep("^#\\|\\s*label:", options, value = TRUE))
    list(
      label = if (length(label)) label[[1L]] else NA_character_,
      options = options,
      code = body[!startsWith(body, "#|")]
    )
  })
}

testthat::test_that("[LTB-0437] the minimum-variance article teaches the executed proof and the causal-history solver is relabelled", {
  strategy <- ws48_strategy()
  root <- ledgr_test_source_root()
  source <- file.path(root, "vignettes", "minimum-variance.qmd")
  chunks <- ws48_qmd_chunks(source)
  code <- function(label) {
    hit <- Filter(function(x) identical(x$label, label), chunks)
    testthat::expect_length(hit, 1L)
    paste(hit[[1L]]$code, collapse = "\n")
  }
  text <- paste(readLines(source, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  # Every chunk executes. The only conditional evaluation is on the
  # suggested solver (and on mirai for the two-worker sweep).
  options <- unlist(lapply(chunks, `[[`, "options"))
  allowed <- c(
    "#| eval: !expr requireNamespace(\"quadprog\", quietly = TRUE)",
    "#| eval: !expr requireNamespace(\"quadprog\", quietly = TRUE) && requireNamespace(\"mirai\", quietly = TRUE)"
  )
  testthat::expect_true(all(grep("^#\\|\\s*eval:", options, value = TRUE) %in% allowed))
  testthat::expect_false(any(grepl("error:\\s*true", options)))
  testthat::expect_false(grepl("eval\\s*=\\s*FALSE", text))

  # The strategy reads closes for the carried share, then returns of the
  # retained instruments with missing cells kept, screens by min_obs, reads
  # again and reaches targets through the alignment bridge with keep.
  body <- code("strategy")
  for (call in c(
    "ledgr_history_frame(bar = \"close\", lookback = 2L, instruments = character())",
    "format(axis$ts_utc, \"%Y-%m\", tz = \"UTC\")",
    "ledgr_history_frame(bar = \"close\", lookback = lookback)",
    "selection$carried_input_share <= threshold",
    "instruments = candidates, na_action = \"keep\"",
    "valid >= min_obs",
    "instruments = estimated, na_action = \"keep\"",
    "use = \"pairwise.complete.obs\"",
    "quadprog::solve.QP(",
    "ledgr_align_weights(returns)",
    "ledgr_target_rebalance(ctx, equity_fraction = 0.95, keep = held_excluded)",
    "ledgr_target_sizing_unavailable = function(e) NULL",
    "params$lookback %||% 252L", "params$threshold %||% 0.2",
    "params$shrink %||% 0.5", "params$min_obs %||% 60L"
  )) {
    testthat::expect_match(body, call, fixed = TRUE, info = call)
  }
  compact <- gsub("[[:space:]]+", "", body)
  for (forbidden in c("colnames(", "rownames(", "setNames(", "pmax(", "ledgr_results(",
                      "ctx$bars", "ctx$feature_table", "ctx$.", "ledgr_pulse_features(")) {
    testthat::expect_false(grepl(forbidden, compact, fixed = TRUE), info = forbidden)
  }
  testthat::expect_false(grepl("(^|[^[:alnum:]_.])(dim)?names\\(", compact), info = "names(")
  testthat::expect_identical(
    lengths(regmatches(body, gregexpr("feature = \"return_1\"", body, fixed = TRUE))), 2L
  )
  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_identical(preflight$tier, "tier_2")
  testthat::expect_identical(preflight$worker_dependencies$require_namespace, "quadprog")

  # Plain-language statements: the keep rule, the month rule and the demo's
  # dividend status.
  squished <- gsub("\\s+", " ", text)
  for (sentence in c(
    "The strategy therefore passes every holding outside the estimate in `keep`",
    "The very first session of the data has no previous session, so it counts as a month start.",
    "Months are taken in UTC.",
    "so no dividend is posted in this demo"
  )) {
    testthat::expect_match(squished, sentence, fixed = TRUE, info = sentence)
  }

  # The rendered article holds the executed outputs and effects.
  rendered <- file.path(root, "vignettes", "minimum-variance.md")
  testthat::skip_if_not(file.exists(rendered), "rendered article not available")
  md <- paste(readLines(rendered, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  testthat::expect_false(grepl("#> Error|\n    Error", md))
  output_after <- function(call) {
    at <- regexpr(call, md, fixed = TRUE)
    testthat::expect_true(at > 0L, info = call)
    rest <- substring(md, at + nchar(call))
    rest <- sub("^[^`]*```", "", rest)
    sub("``` r.*$", "", rest)
  }
  expected <- list(
    "outcome_on(\"2019-11-12\")" = "not_a_decision_date",
    "outcome_on(\"2018-06-01\")" = "insufficient_history",
    "outcome_on(\"2019-11-01\", list(min_obs = 300L))" = "too_few_instruments",
    # Cut 17 decision (20): the eigenvalue floor repairs this singular case.
    "outcome_on(\"2019-11-01\", list(lookback = 5L, min_obs = 2L, shrink = 1e-12))" = "solved",
    "attr(decision, \"outcome\")" = "solved",
    "check$tier" = "tier_2",
    "check$worker_dependencies$require_namespace" = "quadprog",
    "length(fill_days)" = "[1] 24",
    "completion$completion_status" = "INCOMPLETE",
    "completion$stop_reason" = "valuation_horizon_exhausted",
    "demo_05_fills(without_keep)" = "2019-11-04 09:30:00 SELL",
    "\nbt\n" = "Corporate actions: NONE",
    "\nsweep\n" = "4 candidates attempted: 4 done"
  )
  for (call in names(expected)) {
    testthat::expect_match(output_after(call), expected[[call]], fixed = TRUE, info = call)
  }
  # With keep, DEMO_05 is not sold at the November decision.
  testthat::expect_false(grepl("2019-11-04", output_after("demo_05_fills(bt)"), fixed = TRUE))

  # The causal-history stand-in solver is no longer called long-only minimum
  # variance, and that article links this one.
  causal <- paste(readLines(file.path(root, "vignettes", "causal-history.qmd"), warn = FALSE,
                            encoding = "UTF-8"), collapse = "\n")
  causal <- gsub("\\s+", " ", causal)
  testthat::expect_false(grepl("(?<!not a )long-only minimum-variance solver", causal, perl = TRUE))
  testthat::expect_false(grepl("min_variance <- function(sigma)", causal, fixed = TRUE))
  testthat::expect_match(causal, "vignette(\"minimum-variance\", package = \"ledgr\")", fixed = TRUE)

  # quadprog is suggested, and the article is in the site's reading flow.
  description <- read.dcf(file.path(root, "DESCRIPTION"))
  suggests <- trimws(sub("\\(.*$", "", trimws(unlist(strsplit(description[, "Suggests"], ",")))))
  testthat::expect_true("quadprog" %in% suggests)
  pkgdown <- readLines(file.path(root, "_pkgdown.yml"), warn = FALSE)
  testthat::expect_identical(
    pkgdown[match("      - strategy-authoring-tools", pkgdown) + 1L],
    "      - minimum-variance"
  )
})

testthat::test_that("[LTB-0438] a run that stops for a holding without a permissible mark prints the stop, not CURRENT", {
  hold <- function(ctx, params) ctx$hold()
  days <- ws48_days()
  lines_of <- function(bt, f) gsub("[ \t]+$", "", utils::capture.output(f(bt)))

  # DDD is held from the opening book but has no print before 1 February, so
  # the run stops at its first pulse, 13 January.
  never <- ws48_closes()
  never[days < as.Date("2021-02-01"), "DDD"] <- NA
  nx <- ws48_fixture(
    never, hold,
    opening = ledgr_opening(cash = 100000, positions = c(DDD = 100), cost_basis = c(DDD = 80))
  )
  on.exit(ledgr_snapshot_close(nx$snapshot), add = TRUE)
  unpriced <- ledgr_run(nx$exp, params = list(), run_id = "ws48-print-unpriced")
  on.exit(close(unpriced), add = TRUE, after = FALSE)
  expected <- paste(
    "Valuation: STOPPED - 1 holding without a permissible mark at 2021-01-13T16:00:00Z (DDD);",
    "the run is INCOMPLETE (valuation_horizon_exhausted)"
  )
  printed <- lines_of(unpriced, print)
  summarised <- lines_of(unpriced, summary)
  testthat::expect_true(expected %in% printed)
  testthat::expect_true(expected %in% summarised)
  for (out in list(printed, summarised)) {
    testthat::expect_false(any(grepl("Valuation: (CURRENT|STALE|FROZEN)", out)))
  }
  valuation <- ledgr_valuation_summary(unpriced)
  testthat::expect_identical(valuation$valuation_stop_reason, "valuation_horizon_exhausted")
  testthat::expect_identical(valuation$valuation_stop_instruments, "DDD")
  testthat::expect_identical(
    format(valuation$valuation_stop_ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    "2021-01-13T16:00:00Z"
  )

  # Under exhausted = "refuse" with a one-session horizon, AAA (held from the
  # opening book) has no print on 20 and 21 January: its mark is stale on the
  # 20th and expired on the 21st, where the run stops after earlier stale
  # pulses.
  gap <- ws48_closes()
  gap[days %in% as.Date(c("2021-01-20", "2021-01-21")), "AAA"] <- NA
  rx <- ws48_fixture(
    gap, hold,
    opening = ledgr_opening(cash = 100000, positions = c(AAA = 100), cost_basis = c(AAA = 50)),
    valuation = ledgr_valuation_stale(max_sessions = 1, exhausted = "refuse")
  )
  on.exit(ledgr_snapshot_close(rx$snapshot), add = TRUE)
  refused <- ledgr_run(rx$exp, params = list(), run_id = "ws48-print-refused")
  on.exit(close(refused), add = TRUE, after = FALSE)
  testthat::expect_identical(ledgr_run_completion(refused)$stop_reason, "valuation_horizon_exhausted")
  testthat::expect_identical(ledgr_valuation_summary(refused)$valuation_state, "stale")
  expected_refused <- paste(
    "Valuation: STOPPED - 1 holding without a permissible mark at 2021-01-21T16:00:00Z (AAA);",
    "the run is INCOMPLETE (valuation_horizon_exhausted)"
  )
  testthat::expect_true(expected_refused %in% lines_of(refused, print))
  testthat::expect_false(any(grepl("Valuation: STALE", lines_of(refused, print))))

  # The LTB-0164 terminal fixture (close review 48 F1): AAA closes 100, -,
  # 103 and is known inactive (bankruptcy) from day 2, where its terminal
  # choice needs a permissible mark under a zero-session refuse horizon and
  # has none, so the run stops with terminal_mark_unavailable.
  no_mark <- terminal_outcome_snapshot(
    list(AAA = c(100, NA, 103)),
    lifetime = terminal_outcome_lifetime("AAA", 2L, "bankruptcy")
  )
  on.exit(ledgr_snapshot_close(no_mark), add = TRUE)
  terminal <- ledgr_run(
    terminal_outcome_experiment(no_mark, valuation = ledgr_valuation_stale(0, exhausted = "refuse")),
    run_id = "ws48-print-terminal"
  )
  on.exit(close(terminal), add = TRUE, after = FALSE)
  testthat::expect_identical(ledgr_run_completion(terminal)$stop_reason, "terminal_mark_unavailable")
  expected_terminal <- paste(
    "Valuation: STOPPED - 1 holding without a permissible mark at 2020-01-02T16:00:00Z (AAA);",
    "the run is INCOMPLETE (terminal_mark_unavailable)"
  )
  for (out in list(lines_of(terminal, print), lines_of(terminal, summary))) {
    testthat::expect_true(expected_terminal %in% out)
    testthat::expect_false(any(grepl("Valuation: (CURRENT|STALE|FROZEN)", out)))
  }
  testthat::expect_identical(ledgr_valuation_summary(terminal)$valuation_stop_reason, "terminal_mark_unavailable")

  # A run without a valuation stop keeps its ordinary headline.
  cx <- ws48_fixture(ws48_closes(), hold)
  on.exit(ledgr_snapshot_close(cx$snapshot), add = TRUE)
  clean <- ledgr_run(cx$exp, params = list(), run_id = "ws48-print-clean")
  on.exit(close(clean), add = TRUE, after = FALSE)
  clean_lines <- lines_of(clean, print)
  testthat::expect_true("Valuation: CURRENT - every held mark was a current close" %in% clean_lines)
  testthat::expect_false(any(grepl("STOPPED", clean_lines)))
  testthat::expect_identical(ledgr_valuation_summary(clean)$valuation_stop_reason, NA_character_)
  testthat::expect_identical(ledgr_valuation_summary(clean)$valuation_stop_instruments, character())
})

# Eigenvalue floor of the strategy (Cut 17 decision 20), written out for the
# oracle: eigenvalues below floor times the largest are raised to it.
ws48_floor <- function(sigma, floor = 1e-6) {
  e <- eigen(sigma, symmetric = TRUE)
  values <- pmax(e$values, floor * max(e$values))
  out <- e$vectors %*% (values * t(e$vectors))
  dimnames(out) <- dimnames(sigma)
  (out + t(out)) / 2
}

# Five instruments over the WS48 calendar. In the ten-session window ending
# 1 March, AAA and BBB are calm for six sessions and swing for the last four;
# CCC, DDD and EEE enter (first print) on the sixth window session and follow
# the swing, so each has four valid returns. Their pairwise covariances with
# AAA and BBB rest on the swing alone while AAA's and BBB's variances span
# the whole window, so the pairwise matrix is indefinite even after
# shrinkage.
ws48_entrant_closes <- function(days = ws48_days()) {
  at <- match(as.Date("2021-03-01"), days)
  window <- (at - 9L):at
  k <- seq_along(days)
  ra <- 0.010 * sin(0.9 * k) + 0.004 * sin(0.31 * k)
  rb <- 0.012 * sin(1.7 * k + 1) + 0.004 * sin(0.31 * k)
  calm <- c(0.002, -0.0015, 0.001, -0.002, 0.0015, -0.001)
  swing <- c(0.03, -0.025, 0.028, -0.03)
  ra[window] <- c(calm, swing)
  rb[window] <- c(-calm, swing + 0.002 * cos(1:4))
  entrant <- function(phase) {
    r <- rep(0, length(days))
    r[window[7:10]] <- swing + 0.002 * sin(1:4 + phase)
    r
  }
  r <- cbind(AAA = ra, BBB = rb, CCC = entrant(1), DDD = entrant(2), EEE = entrant(3))
  r[1L, ] <- 0
  closes <- exp(apply(log1p(r), 2L, cumsum)) *
    matrix(c(50, 60, 70, 80, 90), nrow(r), 5L, byrow = TRUE)
  closes[seq_len(window[6] - 1L), c("CCC", "DDD", "EEE")] <- NA
  closes
}

testthat::test_that("[LTB-0439] an indefinite pairwise covariance from short-history entrants is repaired and solved, not held", {
  strategy <- ws48_strategy()
  days <- ws48_days()
  closes <- ws48_entrant_closes(days)
  fx <- ws48_fixture(closes, strategy)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  params <- list(lookback = 10L, min_obs = 4L, shrink = 0.5)
  ids <- c("AAA", "BBB", "CCC", "DDD", "EEE")

  # Precondition from the fixture closes: four valid returns for each
  # entrant, and a shrunk pairwise covariance with a negative eigenvalue.
  x <- ws48_window_returns(closes, days, "2021-03-01", 10L, ids)
  testthat::expect_identical(unname(colSums(is.finite(x))), c(10, 10, 4, 4, 4))
  sigma <- ws48_sigma(x, 0.5)
  testthat::expect_lt(min(eigen(sigma, symmetric = TRUE, only.values = TRUE)$values), 0)

  seen <- ws48_decide(strategy, fx$exp, "2021-03-01", params)
  testthat::expect_identical(seen$outcome, "solved")
  w <- ws48_long_only(ws48_floor(sigma))
  price <- closes[match(as.Date("2021-03-01"), days), ids]
  expected <- floor(w * 0.95 * 100000 / price)
  testthat::expect_lte(max(abs(seen$target[ids] - expected)), 1)
  testthat::expect_gt(sum(seen$target[ids]), 0)
})

testthat::test_that("[LTB-0440] a held index leaver is sold on the next decision date while a screened holding is kept", {
  strategy <- ws48_strategy()
  days <- ws48_days()
  # DDD leaves the universe with the snapshot effective 15 February.
  membership <- data.frame(
    effective_from = c(ws48_utc(days[[1L]] - 1), ws48_utc(as.Date("2021-02-15"))),
    knowledge_time = c(ws48_utc(days[[1L]] - 1), ws48_utc(as.Date("2021-02-15")))
  )
  membership$members <- I(list(c("AAA", "BBB", "CCC", "DDD"), c("AAA", "BBB", "CCC")))
  # CCC's carried share is 0.3 on 1 March (as in LTB-0432), so it is a
  # screened holding that keep preserves.
  closes <- ws48_closes()
  closes[days %in% as.Date(c("2021-02-18", "2021-02-22", "2021-02-24")), "CCC"] <- NA
  fx <- ws48_fixture(closes, strategy, membership = membership)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  params <- list(lookback = 10L, min_obs = 3L, threshold = 0.2)

  ctx <- ledgr_pulse_snapshot(fx$exp, ts_utc = as.Date("2021-03-01"), params = params)
  testthat::expect_true(all(c("AAA", "BBB", "CCC") %in% ctx$members))
  testthat::expect_false("DDD" %in% ctx$members)
  close(ctx)

  bt <- ledgr_run(fx$exp, params = params, run_id = "ws48-leaver")
  on.exit(close(bt), add = TRUE, after = FALSE)
  fills <- as.data.frame(ledgr_results(bt, "fills"))
  fill <- function(id, day) {
    hit <- fills[fills$instrument_id == id & format(as.Date(fills$ts_utc)) == day, , drop = FALSE]
    if (nrow(hit) == 0L) return(NULL)
    list(side = hit$side, qty = hit$qty)
  }
  bought <- fill("DDD", "2021-02-02")
  testthat::expect_identical(bought$side, "BUY")
  testthat::expect_gt(bought$qty, 0)
  # The leaver is sold in full at the open after the 1 March decision.
  sold <- fill("DDD", "2021-03-02")
  testthat::expect_identical(sold$side, "SELL")
  testthat::expect_identical(sold$qty, bought$qty)
  # Nothing of DDD is bought back, and the screened CCC is not traded on
  # 2 March.
  testthat::expect_null(fill("DDD", "2021-04-02"))
  testthat::expect_null(fill("CCC", "2021-03-02"))
})
