pfb_assert <- function(ok, message) {
  if (!isTRUE(ok)) stop(message, call. = FALSE)
}

pfb_case <- function(id, label, code) {
  tryCatch({
    force(code)
    data.frame(case_id = id, label = label, status = "pass", detail = "", stringsAsFactors = FALSE)
  }, error = function(e) {
    data.frame(case_id = id, label = label, status = "fail", detail = conditionMessage(e), stringsAsFactors = FALSE)
  })
}

pfb_run_correctness <- function(spike_root, repo_root, gut = FALSE, run_parallel = TRUE) {
  source(file.path(spike_root, "R", "core.R"))
  source(file.path(spike_root, "R", "loops.R"))
  source(file.path(spike_root, "R", "parallel.R"))
  rows <- list()
  add <- function(id, label, code) rows[[length(rows) + 1L]] <<- pfb_case(id, label, code)

  add("C01", "signal common: loop ordering and sharing", {
    p <- pfb_make_params(6L, "signal", "common", 0)
    x <- pfb_prepare(pfb_generate_market(40L, 8L), p)
    a <- pfb_run_strategy_first(x, p, "full")
    b <- pfb_run_pulse_first(x, p, "full", FALSE)
    c <- pfb_run_pulse_first(x, p, "full", TRUE, gut = gut)
    pfb_assert(pfb_results_identical(a$results, b$results), "loop ordering changed outputs")
    pfb_assert(pfb_results_identical(a$results, c$results), "shared pulse preparation changed outputs")
  })
  add("C02", "signal varying: fee path", {
    p <- pfb_make_params(8L, "signal", "varying", 0.0002)
    x <- pfb_prepare(pfb_generate_market(50L, 12L), p)
    a <- pfb_run_strategy_first(x, p, "full")
    b <- pfb_run_pulse_first(x, p, "full", TRUE)
    pfb_assert(pfb_results_identical(a$results, b$results), "fee path differs")
  })
  add("C03", "stateful drawdown: candidate-local state", {
    p <- pfb_make_params(7L, "stateful", "varying", 0.0001)
    x <- pfb_prepare(pfb_generate_market(60L, 10L), p)
    a <- pfb_run_strategy_first(x, p, "full")
    b <- pfb_run_pulse_first(x, p, "full", TRUE)
    pfb_assert(pfb_results_identical(a$results, b$results), "stateful path differs")
  })
  add("C04", "deterministic repeated execution", {
    p <- pfb_make_params(5L, "stateful", "common", 0.0001)
    x <- pfb_prepare(pfb_generate_market(45L, 9L), p)
    a <- pfb_run_pulse_first(x, p, "full", TRUE)
    b <- pfb_run_pulse_first(x, p, "full", TRUE)
    pfb_assert(identical(a$results, b$results), "repeat changed outputs")
  })
  add("C05", "serial batch partition invariance", {
    p <- pfb_make_params(11L, "signal", "varying", 0.0001)
    x <- pfb_prepare(pfb_generate_market(35L, 7L), p)
    expected <- pfb_run_pulse_first(x, p, "full", TRUE)$results
    for (size in c(1L, 4L, 11L)) {
      pieces <- lapply(pfb_batches(nrow(p), size), function(idx) {
        pfb_run_pulse_first(x, p[idx, , drop = FALSE], "full", TRUE)$results
      })
      actual <- unlist(pieces, recursive = FALSE)
      pfb_assert(pfb_results_identical(expected, actual), sprintf("batch size %d differs", size))
    }
  })
  add("C06", "worker count and result-order invariance", {
    if (run_parallel && requireNamespace("mirai", quietly = TRUE)) {
      p <- pfb_make_params(8L, "stateful", "common", 0.0001)
      x <- pfb_prepare(pfb_generate_market(35L, 7L), p)
      expected <- pfb_run_pulse_first(x, p, "full", TRUE)$results
      actual <- pfb_run_parallel(x, p, 2L, 4L, spike_root, retention = "full")$results
      pfb_assert(pfb_results_identical(expected, actual), "two-worker result differs")
    }
  })
  add("C07", "candidate state isolation", {
    p <- pfb_make_params(2L, "stateful", "varying", 0.0001)
    x <- pfb_prepare(pfb_generate_market(45L, 9L), p)
    together <- pfb_run_pulse_first(x, p, "full", TRUE)$results[[2L]]
    alone <- pfb_run_pulse_first(x, p[2L, , drop = FALSE], "full", TRUE)$results[[1L]]
    pfb_assert(identical(together, alone), "candidate state leaked across portfolios")
  })
  add("C08", "no fill after final session", {
    p <- pfb_make_params(1L, "constant", "common", 0)
    p$constant_qty <- 1
    x <- pfb_prepare(pfb_generate_market(8L, 2L), p)
    result <- pfb_run_pulse_first(x, p, "full", TRUE)$results[[1L]]
    fills <- do.call(rbind, result$fills)
    pfb_assert(is.null(fills) || max(fills$pulse) <= x$n_sessions, "fill crossed final session")
    pfb_assert(is.null(result$fills[[x$n_sessions]]), "final pulse created a new decision fill")
  })
  add("C09", "canonical ledgr constant-target subset", {
    pkgload::load_all(repo_root, quiet = TRUE, compile = FALSE)
    sessions <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:5
    bars <- data.frame(
      ts_utc = sessions, instrument_id = "AAA", open = 100:105,
      high = 101:106, low = 99:104, close = 100.5:105.5, volume = 1000
    )
    snapshot <- ledgr_snapshot_from_df(bars)
    on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
    strategy <- function(ctx, params) stats::setNames(params$qty, "AAA")
    exp <- ledgr_experiment(
      snapshot, strategy, opening = ledgr_opening(cash = 1e6),
      cost_model = ledgr_cost_zero()
    )
    bt <- ledgr_run(exp, params = list(qty = 1), seed = 41L)
    equity <- ledgr_compute_equity_curve(bt)
    ledger <- ledgr_results(bt, what = "ledger")
    market <- list(
      open = matrix(100:105, ncol = 1L, dimnames = list(NULL, "AAA")),
      close = matrix(100.5:105.5, ncol = 1L, dimnames = list(NULL, "AAA")),
      instrument_ids = "AAA"
    )
    p <- pfb_make_params(1L, "constant", "common", 0)
    p$constant_qty <- 1
    result <- pfb_run_strategy_first(pfb_prepare(market, p), p, "full")$results[[1L]]
    fills <- do.call(rbind, result$fills)
    pfb_assert(isTRUE(all.equal(result$cash_history, equity$cash, tolerance = 1e-12)), "cash differs from ledgr")
    pfb_assert(isTRUE(all.equal(result$equity_history, equity$equity, tolerance = 1e-12)), "equity differs from ledgr")
    pfb_assert(identical(as.numeric(fills$quantity), ledger$qty), "fill quantity differs from ledgr")
    pfb_assert(identical(as.numeric(fills$price), ledger$price), "fill price differs from ledgr")
    pfb_assert(identical(as.numeric(fills$fee), ledger$fee), "fill fee differs from ledgr")
  })
  do.call(rbind, rows)
}
