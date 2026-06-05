# peer_benchmark.R
#
# Repo-local peer benchmark and parity harness for v0.1.8.8 / LDG-2476.
# This is an internal same-host sanity check, not package documentation and not
# a public performance ranking.
#
# Usage:
#   Rscript dev/bench/peer_benchmark/peer_benchmark.R --preset smoke

`%||%` <- function(x, y) if (is.null(x)) y else x

peer_parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  out <- list(
    preset = "smoke",
    out_dir = file.path("dev", "bench", "results"),
    release = "v0.1.8.8",
    n_inst = NULL,
    n_days = NULL,
    fast = 5L,
    slow = 10L,
    seed = 20260530L,
    compiled_accounting_model = NULL,
    engine_set = "all"
  )
  i <- 1L
  while (i <= length(args)) {
    key <- args[[i]]
    val <- if (i < length(args)) args[[i + 1L]] else NA_character_
    if (identical(key, "--preset")) {
      out$preset <- val
      i <- i + 2L
    } else if (identical(key, "--out-dir")) {
      out$out_dir <- val
      i <- i + 2L
    } else if (identical(key, "--release")) {
      out$release <- val
      i <- i + 2L
    } else if (identical(key, "--n-inst")) {
      out$n_inst <- as.integer(val)
      i <- i + 2L
    } else if (identical(key, "--n-days")) {
      out$n_days <- as.integer(val)
      i <- i + 2L
    } else if (identical(key, "--fast")) {
      out$fast <- as.integer(val)
      i <- i + 2L
    } else if (identical(key, "--slow")) {
      out$slow <- as.integer(val)
      i <- i + 2L
    } else if (identical(key, "--seed")) {
      out$seed <- as.integer(val)
      i <- i + 2L
    } else if (identical(key, "--compiled-accounting-model")) {
      out$compiled_accounting_model <- if (identical(val, "NULL")) NULL else val
      i <- i + 2L
    } else if (identical(key, "--engine-set")) {
      out$engine_set <- val
      i <- i + 2L
    } else if (key %in% c("--help", "-h")) {
      cat(paste(
        "Usage: Rscript dev/bench/peer_benchmark/peer_benchmark.R [options]",
        "",
        "Options:",
        "  --preset smoke|record",
        "  --out-dir PATH",
        "  --release TAG",
        "  --n-inst N",
        "  --n-days N",
        "  --fast N",
        "  --slow N",
        "  --seed N",
        "  --compiled-accounting-model NULL|spot_fifo",
        "  --engine-set all|ledgr-cost",
        sep = "\n"
      ), "\n")
      quit(status = 0L)
    } else {
      stop("Unknown argument: ", key, call. = FALSE)
    }
  }
  if (!out$preset %in% c("smoke", "record")) {
    stop("`--preset` must be `smoke` or `record`.", call. = FALSE)
  }
  if (!is.null(out$compiled_accounting_model) &&
      !identical(out$compiled_accounting_model, "spot_fifo")) {
    stop("`--compiled-accounting-model` must be NULL or spot_fifo.", call. = FALSE)
  }
  if (!out$engine_set %in% c("all", "ledgr-cost")) {
    stop("`--engine-set` must be `all` or `ledgr-cost`.", call. = FALSE)
  }
  if (is.null(out$n_inst)) {
    out$n_inst <- if (identical(out$preset, "record")) 100L else 5L
  }
  if (is.null(out$n_days)) {
    out$n_days <- if (identical(out$preset, "record")) 252L else 40L
  }
  out
}

peer_load_ledgr_source <- function() {
  suppressWarnings(suppressMessages({
    desc_is_ledgr <- file.exists("DESCRIPTION") &&
      identical(unname(read.dcf("DESCRIPTION")[1L, "Package"]), "ledgr")
    if (desc_is_ledgr) {
      if (!requireNamespace("pkgload", quietly = TRUE)) {
        stop("Run from source with pkgload installed; refusing to benchmark a stale installed package.")
      }
      pkgload::load_all(".", quiet = TRUE)
    } else if (requireNamespace("ledgr", quietly = TRUE)) {
      library(ledgr)
    } else {
      stop("ledgr must be installed, or run this script from the package root.")
    }
  }))
  invisible(TRUE)
}

peer_hash_file <- function(path) {
  if (requireNamespace("digest", quietly = TRUE)) {
    return(digest::digest(file = path, algo = "sha256"))
  }
  paste0("md5:", unname(tools::md5sum(path)))
}

peer_sma_ttr <- function(id, n) {
  force(id); force(n)
  ledgr_indicator(
    id = id,
    fn = function(window) {
      x <- as.numeric(window$close)
      if (length(x) < n) return(NA_real_)
      as.numeric(TTR::SMA(x, n = n))[[length(x)]]
    },
    requires_bars = n,
    series_fn = function(bars, params) as.numeric(TTR::SMA(as.numeric(bars$close), n = n))
  )
}

peer_strategy <- function(fast_id, slow_id) {
  force(fast_id); force(slow_id)
  function(ctx, params) {
    targets <- ctx$hold()
    fw <- ctx$features_wide
    instruments <- as.character(fw$instrument_id)
    n <- length(instruments)
    fast <- if (fast_id %in% names(fw)) {
      suppressWarnings(as.numeric(fw[[fast_id]]))
    } else {
      rep(NA_real_, n)
    }
    slow <- if (slow_id %in% names(fw)) {
      suppressWarnings(as.numeric(fw[[slow_id]]))
    } else {
      rep(NA_real_, n)
    }
    current_above <- is.finite(fast) & is.finite(slow) & fast > slow
    prev_above <- ctx$state_prev$above %||% list()

    was_above <- rep(FALSE, n)
    prev_names <- names(prev_above)
    if (length(prev_above) > 0L && length(prev_names) > 0L) {
      idx <- match(instruments, prev_names)
      ok <- !is.na(idx)
      if (any(ok)) {
        was_above[ok] <- as.logical(unlist(prev_above[idx[ok]], use.names = FALSE))
        was_above[is.na(was_above)] <- FALSE
      }
    }

    cross_up <- current_above & !was_above
    cross_down <- !current_above & was_above
    if (any(cross_up)) targets[instruments[cross_up]] <- 1
    if (any(cross_down)) targets[instruments[cross_down]] <- 0

    list(
      targets = targets,
      state_update = list(above = as.list(stats::setNames(current_above, instruments)))
    )
  }
}

peer_metric_oracles <- function(equity) {
  equity <- as.numeric(equity)
  rets <- diff(equity) / head(equity, -1L)
  peak <- cummax(equity)
  drawdown <- (equity - peak) / peak
  ann_vol <- if (length(rets) > 0L) stats::sd(rets, na.rm = TRUE) * sqrt(252) else NA_real_
  ann_return <- if (length(rets) > 0L) (1 + mean(rets, na.rm = TRUE))^252 - 1 else NA_real_
  data.frame(
    total_return = tail(equity, 1L) / equity[[1L]] - 1,
    ann_return = ann_return,
    ann_vol = ann_vol,
    sharpe = if (is.finite(ann_vol) && ann_vol > 0) ann_return / ann_vol else NA_real_,
    max_drawdown = min(drawdown, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}

peer_phase_sec <- function(ingestion_sec = NA_real_,
                           engine_sec = NA_real_,
                           results_sec = NA_real_) {
  list(
    ingestion_sec = as.numeric(ingestion_sec),
    engine_sec = as.numeric(engine_sec),
    results_sec = as.numeric(results_sec)
  )
}

peer_phase_total <- function(phase_sec) {
  vals <- unlist(phase_sec[c("ingestion_sec", "engine_sec", "results_sec")], use.names = FALSE)
  if (length(vals) != 3L || any(!is.finite(vals))) return(NA_real_)
  as.numeric(sum(vals))
}

peer_check_phase_reconciliation <- function(res, tolerance = 0.5) {
  if (!identical(res$status, "DONE")) return(invisible(res))
  phase_sec <- res$phase_sec %||% res$metadata$phase_sec
  total <- peer_phase_total(phase_sec)
  if (!is.finite(total)) {
    stop(sprintf("%s is DONE but does not report finite ingestion/engine/results phase seconds.", res$engine), call. = FALSE)
  }
  wall <- as.numeric(res$wall_sec)
  if (!is.finite(wall) || abs(total - wall) > tolerance) {
    stop(sprintf(
      "%s phase seconds do not reconcile with wall_sec within %.3fs: phases=%.3f wall=%.3f",
      res$engine, tolerance, total, wall
    ), call. = FALSE)
  }
  invisible(res)
}

peer_canonical_equity <- function(engine, equity) {
  ts_col <- intersect(c("ts_utc", "timestamp", "ts"), names(equity))[[1L]]
  data.frame(
    engine = engine,
    ts_utc = format(as.POSIXct(equity[[ts_col]], tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    equity = as.numeric(equity$equity),
    cash = as.numeric(equity$cash %||% NA_real_),
    positions_value = as.numeric(equity$positions_value %||% NA_real_),
    position_proxy = as.numeric(equity$positions_value %||% NA_real_),
    stringsAsFactors = FALSE
  )
}

peer_cost_zero_model <- function() {
  ledgr_cost_zero()
}

peer_cost_realistic_model <- function() {
  ledgr_cost_chain(ledgr_cost_spread_bps(5), ledgr_cost_fixed_fee(1))
}

peer_cost_label <- function(cost_model, legacy = FALSE) {
  if (isTRUE(legacy)) {
    return("legacy_fill_model_spread_5_fixed_1")
  }
  steps <- ledgr_cost_steps(cost_model)
  if (!length(steps)) {
    return("cost_zero")
  }
  paste(vapply(steps, `[[`, character(1L), "type_id"), collapse = "+")
}

peer_run_ledgr <- function(engine, bars_path, features, strategy, seed,
                           cost_model = peer_cost_zero_model()) {
  t0 <- proc.time()[["elapsed"]]
  bars <- utils::read.csv(bars_path, stringsAsFactors = FALSE)
  bars$ts_utc <- as.POSIXct(bars$ts_utc, tz = "UTC")
  db_path <- tempfile(pattern = paste0("ledgr_peer_", engine, "_"), fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit({
    try(ledgr_snapshot_close(snapshot), silent = TRUE)
    try(unlink(db_path), silent = TRUE)
  }, add = TRUE)
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    features = features,
    opening = ledgr_opening(cash = 1e7),
    cost_model = cost_model,
    persist_features = FALSE
  )
  run_id <- paste0("peer_", engine, "_", paste(sample(c(0:9, letters), 6L, TRUE), collapse = ""))
  t1 <- proc.time()[["elapsed"]]
  bt <- ledgr_run(exp, run_id = run_id, seed = seed)
  on.exit(try(close(bt), silent = TRUE), add = TRUE)
  t2 <- proc.time()[["elapsed"]]
  equity <- as.data.frame(ledgr_results(bt, "equity"))
  fills <- as.data.frame(tryCatch(ledgr_results(bt, "fills"), error = function(e) data.frame()))
  out_eq <- peer_canonical_equity(engine, equity)
  t3 <- proc.time()[["elapsed"]]
  phase_sec <- peer_phase_sec(t1 - t0, t2 - t1, t3 - t2)
  elapsed <- peer_phase_total(phase_sec)
  list(
    status = "DONE",
    engine = engine,
    wall_sec = as.numeric(elapsed),
    phase_sec = phase_sec,
    equity = out_eq,
    fills = fills,
    trades = peer_trade_summary_from_fills(engine, fills),
    metrics = peer_metric_oracles(out_eq$equity),
    metadata = list(
      engine = engine,
      status = "DONE",
      wall_sec = as.numeric(elapsed),
      phase_sec = phase_sec,
      cost_model = peer_cost_label(cost_model),
      boundary_check = c("bars_csv_read", "snapshot_create", "engine_run", "canonical_equity_write", "fills_write")
    ),
    reason = NA_character_
  )
}

peer_ledgr_ephemeral_prepare <- function(bars_path, features) {
  bars <- utils::read.csv(bars_path, stringsAsFactors = FALSE)
  bars$ts_utc <- as.POSIXct(bars$ts_utc, tz = "UTC")
  universe <- sort(unique(as.character(bars$instrument_id)))
  bars_by_id <- stats::setNames(lapply(universe, function(id) {
    out <- bars[bars$instrument_id == id, , drop = FALSE]
    out[order(out$ts_utc), , drop = FALSE]
  }), universe)
  bars_by_id <- ledgr:::ledgr_sweep_normalize_bars_by_id(bars_by_id, universe)
  bars_mat <- ledgr:::ledgr_sweep_bars_matrix(bars_by_id, universe)
  pulses_posix <- as.POSIXct(bars_by_id[[universe[[1L]]]]$ts_utc, tz = "UTC")
  pulses_iso <- format(pulses_posix, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  static_bars_views <- ledgr:::ledgr_bars_pulse_views(
    bars_mat = bars_mat,
    instrument_ids = universe,
    pulses_posix = pulses_posix
  )
  if (inherits(features, "ledgr_feature_map")) {
    features <- ledgr:::ledgr_resolve_feature_map(features, feature_params = list())
    feature_defs <- ledgr:::ledgr_feature_map_indicators(features)
    active_alias_map <- ledgr:::ledgr_alias_map_from_feature_map(features)
  } else {
    feature_defs <- ledgr:::ledgr_flatten_feature_list(features, context = "`features`")
    active_alias_map <- NULL
  }
  feature_matrix <- ledgr:::ledgr_sweep_compute_feature_matrix(feature_defs, bars_by_id, universe)
  runtime_projection <- ledgr:::ledgr_projection_from_feature_matrix(
    feature_matrix = feature_matrix,
    universe = universe,
    pulses_posix = pulses_posix,
    feature_engine_version = ledgr:::ledgr_feature_engine_version(),
    alias_index = NULL
  )
  list(
    bars = bars,
    universe = universe,
    bars_by_id = bars_by_id,
    bars_mat = bars_mat,
    pulses_posix = pulses_posix,
    pulses_iso = pulses_iso,
    static_bars_views = static_bars_views,
    feature_defs = feature_defs,
    runtime_projection = runtime_projection,
    active_alias_map = active_alias_map
  )
}

peer_run_ledgr_ephemeral <- function(engine, bars_path, features, strategy, seed,
                                     compiled_accounting_model = NULL,
                                     cost_model = peer_cost_zero_model(),
                                     cost_resolver = NULL,
                                     legacy_cost = FALSE) {
  t0 <- proc.time()[["elapsed"]]
  prep <- peer_ledgr_ephemeral_prepare(bars_path, features)
  t1 <- proc.time()[["elapsed"]]
  run_id <- paste0("peer_", engine, "_", paste(sample(c(0:9, letters), 6L, TRUE), collapse = ""))
  output_handler <- ledgr:::ledgr_memory_output_handler(run_id)
  initial_positions <- stats::setNames(rep(0, length(prep$universe)), prep$universe)
  telemetry <- ledgr:::ledgr_sweep_telemetry_env()
  if (is.null(cost_resolver)) {
    cost_resolver <- ledgr:::ledgr_cost_resolver_from_model(cost_model)
  }
  execution <- ledgr:::ledgr_execution_spec(
    run_id = run_id,
    instrument_ids = prep$universe,
    strategy_fn = strategy,
    strategy_params = list(),
    strategy_call_signature = ledgr:::ledgr_strategy_signature(strategy),
    strategy_is_functional = TRUE,
    pulses_posix = prep$pulses_posix,
    pulses_iso = prep$pulses_iso,
    start_idx = 1L,
    max_pulses = Inf,
    checkpoint_every = 0L,
    telemetry_stride = 0L,
    state = list(cash = 1e7, positions = initial_positions),
    state_prev = NULL,
    bars_by_id = prep$bars_by_id,
    bars_mat = prep$bars_mat,
    static_bars_views = prep$static_bars_views,
    static_feature_views = NULL,
    feature_defs = prep$feature_defs,
    runtime_projection = prep$runtime_projection,
    active_alias_map = prep$active_alias_map,
    cost_resolver = cost_resolver,
    event_seq_start = 1L,
    telemetry = telemetry,
    seed = seed,
    event_mode = "buffered",
    use_fast_context = TRUE,
    compiled_accounting_model = compiled_accounting_model
  )
  ledgr:::ledgr_execute_fold(execution, output_handler)
  t2 <- proc.time()[["elapsed"]]
  events <- output_handler$typed_events()
  equity <- as.data.frame(ledgr:::ledgr_equity_from_events(
    events = events,
    pulses_posix = prep$pulses_posix,
    close_mat = prep$bars_mat$close,
    initial_cash = 1e7,
    instrument_ids = prep$universe,
    run_id = run_id
  ))
  fills <- as.data.frame(ledgr:::ledgr_fills_from_events(events))
  out_eq <- peer_canonical_equity(engine, equity)
  t3 <- proc.time()[["elapsed"]]
  phase_sec <- peer_phase_sec(t1 - t0, t2 - t1, t3 - t2)
  elapsed <- peer_phase_total(phase_sec)
  list(
    status = "DONE",
    engine = engine,
    wall_sec = as.numeric(elapsed),
    phase_sec = phase_sec,
    equity = out_eq,
    fills = fills,
    trades = peer_trade_summary_from_fills(engine, fills),
    metrics = peer_metric_oracles(out_eq$equity),
    metadata = list(
      engine = engine,
      status = "DONE",
      wall_sec = as.numeric(elapsed),
      phase_sec = phase_sec,
      cost_model = peer_cost_label(cost_model, legacy = legacy_cost),
      compiled_accounting_model = compiled_accounting_model,
      boundary_check = c("bars_csv_read", "in_memory_projection", "engine_run", "canonical_equity_write", "fills_write")
    ),
    reason = NA_character_
  )
}

peer_trade_summary_from_fills <- function(engine, fills) {
  if (is.null(fills) || nrow(fills) == 0L) {
    return(data.frame(
      engine = engine,
      trade_count = 0L,
      win_rate = NA_real_,
      average_trade = NA_real_,
      trade_level_status = "available_empty",
      stringsAsFactors = FALSE
    ))
  }
  pnl_col <- intersect(c("realized_pnl", "pnl", "trade_pnl"), names(fills))
  pnl <- if (length(pnl_col) > 0L) as.numeric(fills[[pnl_col[[1L]]]]) else numeric()
  pnl <- pnl[is.finite(pnl) & pnl != 0]
  data.frame(
    engine = engine,
    trade_count = length(pnl),
    win_rate = if (length(pnl) > 0L) mean(pnl > 0) else NA_real_,
    average_trade = if (length(pnl) > 0L) mean(pnl) else NA_real_,
    trade_level_status = if (length(pnl) > 0L) "available_realized_pnl" else "fills_available_no_closed_trade_pnl",
    stringsAsFactors = FALSE
  )
}

peer_run_quantstrat <- function(bars_path, fast, slow) {
  if (!requireNamespace("quantstrat", quietly = TRUE) ||
      !requireNamespace("xts", quietly = TRUE) ||
      !requireNamespace("FinancialInstrument", quietly = TRUE)) {
    return(peer_unavailable("quantstrat", "required R packages are not installed"))
  }
  suppressPackageStartupMessages({
    library(quantstrat)
    library(xts)
  })
  symbols <- character()
  old_tz <- Sys.getenv("TZ", unset = NA_character_)
  Sys.setenv(TZ = "UTC")
  on.exit({
    if (is.na(old_tz)) Sys.unsetenv("TZ") else Sys.setenv(TZ = old_tz)
    if (length(symbols) > 0L) suppressWarnings(rm(list = symbols, envir = globalenv()))
  }, add = TRUE)
  out <- new.env(parent = emptyenv())
  ok <- tryCatch({
    t0 <- proc.time()[["elapsed"]]
    bars <- utils::read.csv(bars_path, stringsAsFactors = FALSE)
    bars$ts_utc <- as.POSIXct(bars$ts_utc, tz = "UTC")
    symbols <- unique(bars$instrument_id)
    for (sym in symbols) {
      d <- bars[bars$instrument_id == sym, , drop = FALSE]
      x <- xts::xts(
        as.matrix(d[, c("open", "high", "low", "close", "volume")]),
        order.by = as.POSIXct(d$ts_utc, tz = "UTC")
      )
      colnames(x) <- c("Open", "High", "Low", "Close", "Volume")
      assign(sym, x, envir = globalenv())
    }
    tag <- paste(sample(c(0:9, letters), 8L, TRUE), collapse = "")
    init_date <- as.character(min(as.Date(bars$ts_utc)) - 1L)
    portf <- paste0("peer_p_", tag)
    acct <- paste0("peer_a_", tag)
    st <- paste0("peer_s_", tag)
    suppressWarnings(try(FinancialInstrument::currency("USD"), silent = TRUE))
    for (sym in symbols) {
      suppressWarnings(FinancialInstrument::stock(sym, currency = "USD", multiplier = 1))
    }
    initPortf(portf, symbols = symbols, initDate = init_date, currency = "USD")
    initAcct(acct, portfolios = portf, initDate = init_date, initEq = 1e7)
    initOrders(portfolio = portf, symbols = symbols, initDate = init_date)
    strategy(st, store = TRUE)
    add.indicator(st, name = "SMA", arguments = list(x = quote(Cl(mktdata)), n = fast), label = "fast")
    add.indicator(st, name = "SMA", arguments = list(x = quote(Cl(mktdata)), n = slow), label = "slow")
    add.signal(st, name = "sigCrossover", arguments = list(columns = c("fast", "slow"), relationship = "gt"), label = "enter")
    add.signal(st, name = "sigCrossover", arguments = list(columns = c("fast", "slow"), relationship = "lt"), label = "exit")
    add.rule(st, name = "ruleSignal", arguments = list(sigcol = "enter", sigval = TRUE, orderqty = 1, ordertype = "market", orderside = "long", replace = FALSE), type = "enter")
    add.rule(st, name = "ruleSignal", arguments = list(sigcol = "exit", sigval = TRUE, orderqty = "all", ordertype = "market", orderside = "long", replace = FALSE), type = "exit")
    t1 <- proc.time()[["elapsed"]]
    invisible(capture.output({
      applyStrategy(st, portfolios = portf, verbose = FALSE)
      updatePortf(portf)
      updateAcct(acct)
      updateEndEq(acct)
    }))
    t2 <- proc.time()[["elapsed"]]
    portfolio_obj <- tryCatch(getPortfolio(portf), error = function(e) NULL)
    if (is.null(portfolio_obj)) {
      stop("quantstrat portfolio object unavailable after applyStrategy")
    }
    account <- tryCatch(getAccount(acct), error = function(e) NULL)
    summary <- if (is.null(account)) NULL else account$summary
    if (is.null(summary) || nrow(summary) == 0L) {
      stop("quantstrat account summary unavailable")
    }
    equity_col <- intersect(c("End.Eq", "End.Eq."), colnames(summary))
    if (length(equity_col) == 0L) {
      stop("quantstrat End.Eq column unavailable")
    }
    out$eq <- data.frame(
      engine = "quantstrat",
      ts_utc = format(as.POSIXct(zoo::index(summary), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      equity = as.numeric(summary[, equity_col[[1L]]]),
      cash = NA_real_,
      positions_value = NA_real_,
      position_proxy = NA_real_,
      stringsAsFactors = FALSE
    )
    tx_list <- lapply(symbols, function(sym) {
      tx <- tryCatch(as.data.frame(getTxns(portf, sym)), error = function(e) data.frame())
      if (nrow(tx) <= 1L) return(data.frame())
      tx <- tx[-1L, , drop = FALSE]
      data.frame(
        engine = "quantstrat",
        ts_utc = format(as.POSIXct(rownames(tx), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
        instrument_id = sym,
        side = ifelse(as.numeric(tx$Txn.Qty) >= 0, "BUY", "SELL"),
        qty = abs(as.numeric(tx$Txn.Qty)),
        price = as.numeric(tx$Txn.Price),
        stringsAsFactors = FALSE
      )
    })
    out$fills <- do.call(rbind, tx_list)
    tx_counts <- vapply(tx_list, nrow, integer(1))
    out$trades <- data.frame(
      engine = "quantstrat",
      trade_count = sum(tx_counts),
      win_rate = NA_real_,
      average_trade = NA_real_,
      trade_level_status = "trade_count_available_only",
      stringsAsFactors = FALSE
    )
    t3 <- proc.time()[["elapsed"]]
    out$phase_sec <- peer_phase_sec(t1 - t0, t2 - t1, t3 - t2)
    TRUE
  }, error = function(e) e)
  if (inherits(ok, "error")) {
    return(peer_unavailable("quantstrat", conditionMessage(ok)))
  }
  elapsed <- peer_phase_total(out$phase_sec)
  list(
    status = "DONE",
    engine = "quantstrat",
    wall_sec = as.numeric(elapsed),
    phase_sec = out$phase_sec,
    equity = out$eq,
    fills = out$fills,
    trades = out$trades,
    metrics = peer_metric_oracles(out$eq$equity),
    metadata = list(
      engine = "quantstrat",
      status = "DONE",
      wall_sec = as.numeric(elapsed),
      phase_sec = out$phase_sec,
      boundary_check = c("bars_csv_read", "xts_construction", "globalenv_assignment", "engine_run", "canonical_equity_write", "fills_write")
    ),
    reason = NA_character_
  )
}

peer_unavailable <- function(engine, reason, metadata = list()) {
  phase_sec <- metadata$phase_sec %||% peer_phase_sec(NA_real_, NA_real_, NA_real_)
  list(
    status = "UNAVAILABLE",
    engine = engine,
    wall_sec = NA_real_,
    phase_sec = phase_sec,
    equity = data.frame(),
    fills = data.frame(),
    trades = data.frame(
      engine = engine,
      trade_count = NA_integer_,
      win_rate = NA_real_,
      average_trade = NA_real_,
      trade_level_status = "unavailable",
      stringsAsFactors = FALSE
    ),
    metrics = data.frame(),
    metadata = modifyList(list(engine = engine, status = "UNAVAILABLE", reason = reason), metadata),
    reason = reason
  )
}

peer_env_ready <- function(engine, reason, wall_sec = NA_real_) {
  list(
    status = "ENV_READY",
    engine = engine,
    wall_sec = wall_sec,
    phase_sec = peer_phase_sec(NA_real_, NA_real_, NA_real_),
    equity = data.frame(),
    fills = data.frame(),
    trades = data.frame(
      engine = engine,
      trade_count = NA_integer_,
      win_rate = NA_real_,
      average_trade = NA_real_,
      trade_level_status = "env_ready_no_canonical_trade_surface",
      stringsAsFactors = FALSE
    ),
    metrics = data.frame(),
    metadata = list(engine = engine, status = "ENV_READY", reason = reason),
    reason = reason
  )
}

peer_phase_from_metadata <- function(metadata) {
  phase <- metadata$phase_sec %||% list()
  peer_phase_sec(
    phase$ingestion_sec %||% NA_real_,
    phase$engine_sec %||% NA_real_,
    phase$results_sec %||% NA_real_
  )
}

peer_python_uv_available <- function() {
  out <- tryCatch(
    system2("python", c("-m", "uv", "--version"), stdout = TRUE, stderr = FALSE),
    error = function(e) character(),
    warning = function(w) character()
  )
  length(out) > 0L
}

peer_uv_runtime_dirs <- function(project_name) {
  root <- Sys.getenv("LEDGR_PEER_UV_HOME", unset = NA_character_)
  if (is.na(root) || !nzchar(root)) {
    root <- file.path(tempdir(), "ledgr-peer-uv")
  }
  if (!grepl("^([A-Za-z]:|/|\\\\)", root)) {
    root <- file.path(normalizePath(".", winslash = "/", mustWork = TRUE), root)
  }
  list(
    cache = normalizePath(file.path(root, project_name, "cache"), winslash = "/", mustWork = FALSE),
    python = normalizePath(file.path(root, project_name, "python"), winslash = "/", mustWork = FALSE),
    env = normalizePath(file.path(root, project_name, "venv"), winslash = "/", mustWork = FALSE)
  )
}

peer_with_uv_runtime <- function(project_name) {
  dirs <- peer_uv_runtime_dirs(project_name)
  dir.create(dirs$cache, recursive = TRUE, showWarnings = FALSE)
  dir.create(dirs$python, recursive = TRUE, showWarnings = FALSE)
  dir.create(dirname(dirs$env), recursive = TRUE, showWarnings = FALSE)
  old <- list(
    cache = Sys.getenv("UV_CACHE_DIR", unset = NA_character_),
    python = Sys.getenv("UV_PYTHON_INSTALL_DIR", unset = NA_character_),
    env = Sys.getenv("UV_PROJECT_ENVIRONMENT", unset = NA_character_),
    no_cache = Sys.getenv("UV_NO_CACHE", unset = NA_character_)
  )
  Sys.setenv(
    UV_CACHE_DIR = dirs$cache,
    UV_PYTHON_INSTALL_DIR = dirs$python,
    UV_PROJECT_ENVIRONMENT = dirs$env
  )
  Sys.unsetenv("UV_NO_CACHE")
  old
}

peer_restore_uv_runtime <- function(old) {
  if (is.na(old$cache)) Sys.unsetenv("UV_CACHE_DIR") else Sys.setenv(UV_CACHE_DIR = old$cache)
  if (is.na(old$python)) Sys.unsetenv("UV_PYTHON_INSTALL_DIR") else Sys.setenv(UV_PYTHON_INSTALL_DIR = old$python)
  if (is.na(old$env)) Sys.unsetenv("UV_PROJECT_ENVIRONMENT") else Sys.setenv(UV_PROJECT_ENVIRONMENT = old$env)
  if (is.na(old$no_cache)) Sys.unsetenv("UV_NO_CACHE") else Sys.setenv(UV_NO_CACHE = old$no_cache)
}

peer_python_run <- function(engine, project_name, script_name, bars_path, fast, slow) {
  project <- file.path("dev", "bench", "peer_benchmark", "python", project_name)
  script <- file.path(project, script_name)
  if (!file.exists(file.path(project, "pyproject.toml")) || !file.exists(script)) {
    return(peer_unavailable(engine, "uv project skeleton missing"))
  }
  if (!peer_python_uv_available()) {
    return(peer_unavailable(engine, "uv is not installed; run the documented uv project before including this peer row"))
  }
  prefix <- tempfile(pattern = paste0(project_name, "_peer_"))
  equity_path <- paste0(prefix, "_equity.csv")
  fills_path <- paste0(prefix, "_fills.csv")
  trades_path <- paste0(prefix, "_trades.csv")
  metadata_path <- paste0(prefix, "_metadata.json")
  args <- c(
    "-m", "uv", "run",
    "--project", project,
    "python", script,
    "--bars", normalizePath(bars_path, winslash = "/", mustWork = TRUE),
    "--equity-out", normalizePath(equity_path, winslash = "/", mustWork = FALSE),
    "--fills-out", normalizePath(fills_path, winslash = "/", mustWork = FALSE),
    "--trades-out", normalizePath(trades_path, winslash = "/", mustWork = FALSE),
    "--metadata-out", normalizePath(metadata_path, winslash = "/", mustWork = FALSE),
    "--fast", as.character(fast),
    "--slow", as.character(slow)
  )
  old_uv <- peer_with_uv_runtime(project_name)
  on.exit(peer_restore_uv_runtime(old_uv), add = TRUE)
  status <- system2("python", args, stdout = TRUE, stderr = TRUE)
  code <- attr(status, "status") %||% 0L
  if (!identical(as.integer(code), 0L)) {
    return(peer_unavailable(engine, paste(status, collapse = " | ")))
  }
  if (!file.exists(metadata_path)) {
    return(peer_unavailable(engine, sprintf("%s did not emit expected canonical artifacts", engine)))
  }
  metadata <- jsonlite::read_json(metadata_path, simplifyVector = TRUE)
  if (!is.null(metadata$status) && identical(metadata$status, "UNAVAILABLE")) {
    return(peer_unavailable(engine, metadata$reason %||% "engine reported unavailable", metadata = metadata))
  }
  boundary <- metadata$boundary_check %||% character()
  required_boundary <- c("bars_csv_read", "engine_run", "canonical_equity_write")
  if (!all(required_boundary %in% boundary)) {
    return(peer_unavailable(engine, sprintf(
      "%s metadata boundary_check missing required entries: %s",
      engine,
      paste(setdiff(required_boundary, boundary), collapse = ", ")
    ), metadata = metadata))
  }
  if (!file.exists(equity_path) || !file.exists(trades_path)) {
    return(peer_unavailable(engine, sprintf("%s did not emit expected canonical artifacts", engine)))
  }
  eq <- utils::read.csv(equity_path, stringsAsFactors = FALSE)
  for (col in intersect(c("equity", "cash", "positions_value", "position_proxy"), names(eq))) {
    eq[[col]] <- suppressWarnings(as.numeric(eq[[col]]))
  }
  fills <- if (file.exists(fills_path)) utils::read.csv(fills_path, stringsAsFactors = FALSE) else data.frame()
  trades <- utils::read.csv(trades_path, stringsAsFactors = FALSE)
  list(
    status = "DONE",
    engine = engine,
    wall_sec = as.numeric(metadata$wall_sec),
    phase_sec = peer_phase_from_metadata(metadata),
    equity = eq,
    fills = fills,
    trades = trades,
    metrics = peer_metric_oracles(eq$equity),
    metadata = metadata,
    reason = NA_character_
  )
}

peer_run_backtrader <- function(bars_path, fast, slow) {
  peer_python_run(
    engine = "backtrader",
    project_name = "backtrader",
    script_name = "peer_backtrader.py",
    bars_path = bars_path,
    fast = fast,
    slow = slow
  )
}

peer_run_zipline_full <- function(bars_path, fast, slow) {
  peer_python_run(
    engine = "zipline-reloaded-full",
    project_name = "zipline",
    script_name = "peer_zipline_full.py",
    bars_path = bars_path,
    fast = fast,
    slow = slow
  )
}

peer_run_lean <- function(bars_path, fast, slow) {
  peer_python_run(
    engine = "LEAN",
    project_name = "lean",
    script_name = "peer_lean.py",
    bars_path = bars_path,
    fast = fast,
    slow = slow
  )
}

peer_timed <- function(expr) {
  elapsed <- system.time(res <- force(expr))[["elapsed"]]
  res$row_wall_sec <- as.numeric(elapsed)
  peer_check_phase_reconciliation(res)
  res
}

peer_performance_boundary <- function(engine) {
  switch(
    engine,
    ledgr_ttr_canonical = "durable ledgr: ingestion=bars CSV read plus DuckDB snapshot plus experiment construction; engine=ledgr_run; results=ledgr_results equity/fills plus canonical materialization",
    ledgr_ttr_canonical_ephemeral = "ephemeral ledgr: ingestion=bars CSV read plus in-memory bars/features/projection; engine=ledgr_execute_fold with memory output handler; results=event-stream equity/fills reconstruction plus canonical materialization",
    ledgr_ttr_canonical_ephemeral_with_costs = "ephemeral ledgr with realistic public cost chain: same bars/projection/strategy surface as canonical ephemeral; engine uses ledgr_cost_chain(spread_bps=5, fixed_fee=1)",
    ledgr_ttr_canonical_ephemeral_legacy_costs = "ephemeral ledgr with legacy internal fill-model resolver: same bars/projection/strategy surface as canonical ephemeral; engine uses spread_bps=5 and commission_fixed=1 baseline resolver",
    ledgr_ttr_compiled_spot_fifo_ephemeral = "ephemeral ledgr with compiled_accounting_model=spot_fifo: same bars/projection/strategy surface as ledgr_ttr_canonical_ephemeral; engine uses compiled spot-FIFO fill/accounting batch; results=event-stream equity/fills canonical materialization",
    ledgr_builtin_sma = "durable ledgr built-in SMA: ingestion=bars CSV read plus DuckDB snapshot plus experiment construction; engine=ledgr_run; results=ledgr_results equity/fills plus canonical materialization",
    quantstrat = "ingestion=bars CSV read, xts/globalenv setup, initPortf/initAcct/initOrders/strategy setup; engine=applyStrategy plus account updates; results=equity/transaction extraction plus canonical writes",
    backtrader = "ingestion=bars CSV read, PandasData feed construction, cerebro.adddata loop; engine=cerebro.run; results=canonical equity/fill/trade writes",
    `zipline-reloaded-full` = "ingestion=bars CSV read, temporary csvdir construction, bundle registration and ingest; engine=zipline run_algorithm; results=canonical equity/fill/trade writes",
    LEAN = "LEAN CLI phase split is unavailable locally; if configured, the whole CLI subprocess is the measured boundary, otherwise the row is UNAVAILABLE",
    "boundary not classified"
  )
}

peer_performance_rows <- function(results, args) {
  n_bars <- as.integer(args$n_inst) * as.integer(args$n_days)
  do.call(rbind, lapply(results, function(res) {
    core <- as.numeric(res$wall_sec)
    row <- as.numeric(res$row_wall_sec %||% NA_real_)
    phase <- res$phase_sec %||% res$metadata$phase_sec %||% peer_phase_sec()
    phase_total <- peer_phase_total(phase)
    data.frame(
      engine = res$engine,
      status = res$status,
      n_instruments = as.integer(args$n_inst),
      n_days = as.integer(args$n_days),
      n_bars = n_bars,
      full_row_sec = row,
      reported_core_sec = core,
      ingestion_sec = as.numeric(phase$ingestion_sec %||% NA_real_),
      engine_sec = as.numeric(phase$engine_sec %||% NA_real_),
      results_sec = as.numeric(phase$results_sec %||% NA_real_),
      phase_total_sec = phase_total,
      harness_overhead_sec = if (is.finite(row) && is.finite(core)) row - core else NA_real_,
      core_bars_per_sec = if (is.finite(core) && core > 0) n_bars / core else NA_real_,
      full_row_bars_per_sec = if (is.finite(row) && row > 0) n_bars / row else NA_real_,
      boundary = peer_performance_boundary(res$engine),
      reason = res$reason,
      stringsAsFactors = FALSE
    )
  }))
}

peer_parity <- function(reference, peer) {
  if (!identical(peer$status, "DONE") || nrow(peer$equity) == 0L) {
    return(data.frame(
      peer = peer$engine,
      status = "UNAVAILABLE",
      tier1_equity_cor = NA_real_,
      tier1_max_single_bar_divergence_pct = NA_real_,
      tier1_daily_return_cor = NA_real_,
      tier1_cash_match = NA,
      tier1_position_match = NA,
      tier2_total_return_diff = NA_real_,
      tier2_sharpe_diff = NA_real_,
      tier2_max_drawdown_diff = NA_real_,
      tier3_trade_count_diff = NA_integer_,
      attribution = "unavailable peer surface",
      stringsAsFactors = FALSE
    ))
  }
  merged <- merge(
    reference$equity,
    peer$equity,
    by = "ts_utc",
    suffixes = c("_ledgr", "_peer"),
    all = FALSE,
    sort = TRUE
  )
  if (nrow(merged) < 2L) {
    eq_cor <- NA_real_
    ret_cor <- NA_real_
    max_div <- NA_real_
  } else {
    eq_cor <- suppressWarnings(stats::cor(merged$equity_ledgr, merged$equity_peer, use = "complete.obs"))
    ret_cor <- suppressWarnings(stats::cor(diff(merged$equity_ledgr), diff(merged$equity_peer), use = "complete.obs"))
    max_div <- max(abs(merged$equity_ledgr - merged$equity_peer) / pmax(abs(merged$equity_ledgr), 1), na.rm = TRUE)
  }
  ref_metrics <- reference$metrics
  peer_metrics <- peer$metrics
  ref_trades <- reference$trades
  peer_trades <- peer$trades
  tier1_pass <- is.finite(max_div) && max_div < 0.01 &&
    (!is.finite(eq_cor) || eq_cor > 0.999)
  attribution <- if (tier1_pass) {
    "passes Tier 1 tolerance"
  } else {
    "indicator initialization, fill timing, cost/margin defaults, position-sizing rounding, timestamp alignment, or float ordering"
  }
  data.frame(
    peer = peer$engine,
    status = "DONE",
    tier1_equity_cor = eq_cor,
    tier1_max_single_bar_divergence_pct = max_div,
    tier1_daily_return_cor = ret_cor,
    tier1_cash_match = if (all(is.finite(merged$cash_ledgr)) && all(is.finite(merged$cash_peer))) isTRUE(all.equal(merged$cash_ledgr, merged$cash_peer, tolerance = 1e-8)) else NA,
    tier1_position_match = if (all(is.finite(merged$position_proxy_ledgr)) && all(is.finite(merged$position_proxy_peer))) isTRUE(all.equal(merged$position_proxy_ledgr, merged$position_proxy_peer, tolerance = 1e-8)) else NA,
    tier2_total_return_diff = peer_metrics$total_return[[1L]] - ref_metrics$total_return[[1L]],
    tier2_sharpe_diff = peer_metrics$sharpe[[1L]] - ref_metrics$sharpe[[1L]],
    tier2_max_drawdown_diff = peer_metrics$max_drawdown[[1L]] - ref_metrics$max_drawdown[[1L]],
    tier3_trade_count_diff = peer_trades$trade_count[[1L]] - ref_trades$trade_count[[1L]],
    attribution = attribution,
    stringsAsFactors = FALSE
  )
}

peer_compare_ledgr_surfaces <- function(durable, ephemeral) {
  plain_df <- function(x) {
    out <- as.data.frame(x, stringsAsFactors = FALSE)
    for (nm in names(out)) {
      if (!inherits(out[[nm]], "POSIXct")) {
        attributes(out[[nm]]) <- NULL
      }
    }
    attr(out, "ledgr_result_type") <- NULL
    row.names(out) <- NULL
    out
  }
  eq_a <- durable$equity
  eq_b <- ephemeral$equity
  eq_a$engine <- "ledgr"
  eq_b$engine <- "ledgr"
  eq_a <- plain_df(eq_a)
  eq_b <- plain_df(eq_b)
  fills_a <- plain_df(durable$fills)
  fills_b <- plain_df(ephemeral$fills)
  eq_ok <- isTRUE(all.equal(eq_a, eq_b, tolerance = 1e-8, check.attributes = TRUE))
  fills_ok <- identical(fills_a, fills_b)
  if (!eq_ok || !fills_ok) {
    eq_msg <- if (eq_ok) "equity equal within 1e-8" else "equity differs"
    fills_msg <- if (identical(fills_a, fills_b)) "fills identical" else "fills differ"
    stop(sprintf(
      "ledgr ephemeral parity gate failed: %s; %s. The no-durable row must match durable ledgr before peer results are accepted.",
      eq_msg, fills_msg
    ), call. = FALSE)
  }
  invisible(TRUE)
}

peer_normalize_fills <- function(fills) {
  if (is.null(fills) || nrow(fills) == 0L) {
    return(data.frame(
      ts_utc = character(),
      instrument_id = character(),
      side = character(),
      qty = numeric(),
      price = numeric(),
      stringsAsFactors = FALSE
    ))
  }
  ts_col <- intersect(c("ts_utc", "timestamp", "ts", "date"), names(fills))
  inst_col <- intersect(c("instrument_id", "symbol", "asset"), names(fills))
  side_col <- intersect(c("side", "Side"), names(fills))
  qty_col <- intersect(c("qty", "quantity", "amount", "Txn.Qty"), names(fills))
  price_col <- intersect(c("price", "fill_price", "Txn.Price"), names(fills))
  if (!length(ts_col) || !length(inst_col) || !length(qty_col) || !length(price_col)) {
    return(data.frame(
      ts_utc = character(),
      instrument_id = character(),
      side = character(),
      qty = numeric(),
      price = numeric(),
      stringsAsFactors = FALSE
    ))
  }
  qty <- suppressWarnings(as.numeric(fills[[qty_col[[1L]]]]))
  side <- if (length(side_col)) as.character(fills[[side_col[[1L]]]]) else ifelse(qty >= 0, "BUY", "SELL")
  data.frame(
    ts_utc = format(as.POSIXct(fills[[ts_col[[1L]]]], tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    instrument_id = as.character(fills[[inst_col[[1L]]]]),
    side = toupper(side),
    qty = abs(qty),
    price = suppressWarnings(as.numeric(fills[[price_col[[1L]]]])),
    stringsAsFactors = FALSE
  )
}

peer_fill_events_at <- function(fills, ts) {
  fills[fills$ts_utc == ts, , drop = FALSE]
}

peer_classify_divergence <- function(ts, abs_div, ref_fills, peer_fills, ref_has_ts) {
  if (!isTRUE(ref_has_ts)) {
    return(c("calendar_skip", "peer bar has no matching ledgr canonical timestamp"))
  }
  if (!is.finite(abs_div) || abs_div <= 1e-9) {
    return(c("none", "equity matches within 1e-9"))
  }
  lf <- peer_fill_events_at(ref_fills, ts)
  pf <- peer_fill_events_at(peer_fills, ts)
  if (nrow(lf) > 0L && nrow(pf) == 0L) {
    return(c("ledgr_fill_not_in_peer", sprintf("ledgr fills=%d; peer fills=0", nrow(lf))))
  }
  if (nrow(lf) == 0L && nrow(pf) > 0L) {
    return(c("peer_fill_not_in_ledgr", sprintf("peer fills=%d; ledgr fills=0", nrow(pf))))
  }
  if (nrow(lf) > 0L && nrow(pf) > 0L) {
    key_l <- paste(lf$instrument_id, lf$side, lf$qty)
    key_p <- paste(pf$instrument_id, pf$side, pf$qty)
    common <- intersect(key_l, key_p)
    if (length(common) == 0L || nrow(lf) != nrow(pf)) {
      return(c("position_size_differs", sprintf("ledgr fills=%d; peer fills=%d", nrow(lf), nrow(pf))))
    }
    price_diffs <- vapply(common, function(k) {
      abs(lf$price[match(k, key_l)] - pf$price[match(k, key_p)])
    }, numeric(1))
    if (any(price_diffs > 1e-8, na.rm = TRUE)) {
      return(c("fill_price_differs", sprintf("max fill price diff=%g", max(price_diffs, na.rm = TRUE))))
    }
  }
  if (abs_div <= 1e-6) {
    return(c("float_rounding_only", sprintf("abs_div=%g", abs_div)))
  }
  c("position_size_differs", "no same-timestamp fill mismatch; equity path implies position/accounting divergence")
}

peer_divergence_category <- function(event) {
  switch(
    event,
    indicator_warmup_offset = "indicator_warmup",
    peer_fill_not_in_ledgr = "fill_timing",
    ledgr_fill_not_in_peer = "fill_timing",
    fill_price_differs = "fill_timing",
    calendar_skip = "calendar",
    position_size_differs = "position_size",
    float_rounding_only = "float_rounding",
    none = "float_rounding",
    "other"
  )
}

peer_divergence <- function(reference, peer) {
  ref_eq <- reference$equity
  peer_eq <- peer$equity
  ref_fills <- peer_normalize_fills(reference$fills)
  peer_fills <- peer_normalize_fills(peer$fills)
  ref_map <- match(peer_eq$ts_utc, ref_eq$ts_utc)
  equity_ledgr <- ref_eq$equity[ref_map]
  equity_peer <- peer_eq$equity
  abs_div <- abs(equity_ledgr - equity_peer)
  pct_div <- abs_div / pmax(abs(equity_ledgr), 1)
  event <- character(nrow(peer_eq))
  detail <- character(nrow(peer_eq))
  for (i in seq_len(nrow(peer_eq))) {
    classified <- peer_classify_divergence(
      peer_eq$ts_utc[[i]],
      abs_div[[i]],
      ref_fills,
      peer_fills,
      !is.na(ref_map[[i]])
    )
    event[[i]] <- classified[[1L]]
    detail[[i]] <- classified[[2L]]
  }
  div <- data.frame(
    ts_utc = peer_eq$ts_utc,
    equity_ledgr = equity_ledgr,
    equity_peer = equity_peer,
    abs_div = abs_div,
    pct_div = pct_div,
    cum_abs_div = cumsum(replace(abs_div, !is.finite(abs_div), 0)),
    contributing_event = event,
    event_detail = detail,
    stringsAsFactors = FALSE
  )
  weights <- tapply(replace(abs_div, !is.finite(abs_div), 0), vapply(event, peer_divergence_category, character(1)), sum)
  total <- sum(replace(abs_div, !is.finite(abs_div), 0))
  pct <- function(name) {
    if (total <= 0) return(if (identical(name, "float_rounding")) 1 else 0)
    if (name %in% names(weights)) as.numeric(weights[[name]]) / total else 0
  }
  summary <- data.frame(
    peer = peer$engine,
    total_abs_divergence = total,
    n_bars_diverging = sum(abs_div > 1e-9, na.rm = TRUE),
    first_divergence_ts = if (any(abs_div > 1e-9, na.rm = TRUE)) peer_eq$ts_utc[which(abs_div > 1e-9)[[1L]]] else NA_character_,
    pct_attributable_indicator_warmup = pct("indicator_warmup"),
    pct_attributable_fill_timing = pct("fill_timing"),
    pct_attributable_calendar = pct("calendar"),
    pct_attributable_position_size = pct("position_size"),
    pct_attributable_float_rounding = pct("float_rounding"),
    pct_attributable_other = pct("other"),
    stringsAsFactors = FALSE
  )
  list(rows = div, summary = summary)
}

peer_write_outputs <- function(results, parity, statuses, performance, bars_path, input_hash, args) {
  stamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  stem <- file.path(args$out_dir, sprintf("peer_benchmark_%s_%s", args$preset, stamp))
  env <- peer_environment(args, input_hash)
  dir.create(args$out_dir, recursive = TRUE, showWarnings = FALSE)
  for (res in results) {
    jsonlite::write_json(res$metadata %||% list(engine = res$engine, status = res$status),
                         sprintf("%s_%s_metadata.json", stem, res$engine),
                         auto_unbox = TRUE, pretty = TRUE, na = "null")
    if (identical(res$status, "DONE")) {
      utils::write.csv(res$equity, sprintf("%s_%s_equity.csv", stem, res$engine), row.names = FALSE)
      utils::write.csv(res$fills, sprintf("%s_%s_fills.csv", stem, res$engine), row.names = FALSE)
      utils::write.csv(res$trades, sprintf("%s_%s_trades.csv", stem, res$engine), row.names = FALSE)
    }
  }
  divergence_summaries <- list()
  reference <- results[[1L]]
  for (res in results[-1L]) {
    if (identical(res$status, "DONE")) {
      div <- peer_divergence(reference, res)
      utils::write.csv(div$rows, sprintf("%s_%s_divergence.csv", stem, res$engine), row.names = FALSE)
      utils::write.csv(div$summary, sprintf("%s_%s_divergence_summary.csv", stem, res$engine), row.names = FALSE)
      divergence_summaries[[length(divergence_summaries) + 1L]] <- div$summary
    }
  }
  divergence_summary <- if (length(divergence_summaries)) do.call(rbind, divergence_summaries) else data.frame()
  status_df <- do.call(rbind, lapply(statuses, as.data.frame, stringsAsFactors = FALSE))
  raw <- do.call(rbind, lapply(results, function(res) {
    phase <- res$phase_sec %||% peer_phase_sec()
    data.frame(
      engine = res$engine,
      status = res$status,
      wall_sec = res$wall_sec,
      ingestion_sec = as.numeric(phase$ingestion_sec %||% NA_real_),
      engine_sec = as.numeric(phase$engine_sec %||% NA_real_),
      results_sec = as.numeric(phase$results_sec %||% NA_real_),
      reason = res$reason,
      stringsAsFactors = FALSE
    )
  }))
  raw_path <- paste0(stem, "_status.csv")
  parity_path <- paste0(stem, "_parity.csv")
  performance_path <- paste0(stem, "_performance.csv")
  divergence_summary_path <- paste0(stem, "_divergence_summary.csv")
  status_path <- paste0(stem, "_surface_status.csv")
  env_path <- paste0(stem, "_environment.json")
  history_path <- peer_append_history(parity, env, args)
  utils::write.csv(raw, raw_path, row.names = FALSE)
  utils::write.csv(parity, parity_path, row.names = FALSE)
  utils::write.csv(performance, performance_path, row.names = FALSE)
  utils::write.csv(divergence_summary, divergence_summary_path, row.names = FALSE)
  utils::write.csv(status_df, status_path, row.names = FALSE)
  jsonlite::write_json(env, env_path, auto_unbox = TRUE, pretty = TRUE, na = "null")
  md_path <- paste0(stem, "_summary.md")
  peer_write_markdown(parity, raw, status_df, performance, env, bars_path, history_path, md_path)
  list(raw = raw_path, parity = parity_path, performance = performance_path, divergence_summary = divergence_summary_path, status = status_path, environment = env_path, markdown = md_path, history = history_path)
}

peer_environment <- function(args, input_hash) {
  git_head <- tryCatch(readLines(file.path(".git", "HEAD"), n = 1L, warn = FALSE), error = function(e) NA_character_)
  git_branch <- NA_character_
  git_sha <- NA_character_
  if (length(git_head) > 0L && grepl("^ref: ", git_head[[1L]])) {
    ref <- sub("^ref: ", "", git_head[[1L]])
    git_branch <- sub("^refs/heads/", "", ref)
    git_sha <- tryCatch(readLines(file.path(".git", ref), n = 1L, warn = FALSE), error = function(e) NA_character_)[[1L]]
  } else if (length(git_head) > 0L) {
    git_sha <- git_head[[1L]]
  }
  list(
    created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    release = args$release,
    preset = args$preset,
    engine_set = args$engine_set,
    R = R.version.string,
    platform = R.version$platform,
    git_sha = git_sha,
    git_branch = git_branch,
    ledgr_version = as.character(utils::packageVersion("ledgr")),
    input_hash = input_hash,
    packages = list(
      TTR = if (requireNamespace("TTR", quietly = TRUE)) as.character(utils::packageVersion("TTR")) else NA_character_,
      quantstrat = if (requireNamespace("quantstrat", quietly = TRUE)) as.character(utils::packageVersion("quantstrat")) else NA_character_,
      backtrader_uv = peer_python_uv_available() && file.exists(file.path("dev", "bench", "peer_benchmark", "python", "backtrader", "uv.lock")),
      zipline_uv = peer_python_uv_available() && file.exists(file.path("dev", "bench", "peer_benchmark", "python", "zipline", "uv.lock")),
      lean_uv = peer_python_uv_available() && file.exists(file.path("dev", "bench", "peer_benchmark", "python", "lean", "uv.lock"))
    ),
    claim_policy = "internal same-host parity sanity check; not a public speed ranking"
  )
}

peer_append_history <- function(parity, env, args) {
  dir <- file.path(args$out_dir, "parity_history")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  safe_release <- gsub("[^A-Za-z0-9_.-]+", "_", args$release)
  path <- file.path(dir, paste0(safe_release, "_", args$preset, ".json"))
  payload <- list(environment = env, parity = parity)
  tmp <- tempfile(pattern = basename(path), tmpdir = dir, fileext = ".tmp")
  jsonlite::write_json(payload, tmp, dataframe = "rows", auto_unbox = TRUE, pretty = TRUE, na = "null")
  file.rename(tmp, path)
  path
}

peer_write_markdown <- function(parity, raw, status, performance, env, bars_path, history_path, path) {
  con <- file(path, open = "w", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  writeLines(c(
    "# Peer Benchmark Summary",
    "",
    sprintf("- Created: `%s`", env$created_at),
    sprintf("- Release: `%s`", env$release),
    sprintf("- Input hash: `%s`", env$input_hash),
    sprintf("- Shared bars: `%s`", bars_path),
    sprintf("- Parity history: `%s`", history_path),
    "",
    "This is an internal same-host parity and performance benchmark under declared boundaries.",
    "",
    "## Engine Status",
    "",
    "| Engine | Status | Wall s | Reason |",
    "| --- | --- | ---: | --- |"
  ), con)
  for (i in seq_len(nrow(raw))) {
    writeLines(sprintf(
      "| `%s` | `%s` | %.4f | %s |",
      raw$engine[[i]], raw$status[[i]], raw$wall_sec[[i]], raw$reason[[i]] %||% ""
    ), con)
  }
  writeLines(c("", "## Parity", "", "| Peer | Status | Equity cor | Max div pct | Return cor | Attribution |", "| --- | --- | ---: | ---: | ---: | --- |"), con)
  for (i in seq_len(nrow(parity))) {
    writeLines(sprintf(
      "| `%s` | `%s` | %.6f | %.6f | %.6f | %s |",
      parity$peer[[i]], parity$status[[i]],
      parity$tier1_equity_cor[[i]], parity$tier1_max_single_bar_divergence_pct[[i]],
      parity$tier1_daily_return_cor[[i]], parity$attribution[[i]]
    ), con)
  }
  writeLines(c("", "## Performance", "", "| Engine | Full row s | Ingestion s | Engine s | Results s | Total s | Core bars/sec | Boundary |", "| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |"), con)
  for (i in seq_len(nrow(performance))) {
    writeLines(sprintf(
      "| `%s` | %.4f | %.4f | %.4f | %.4f | %.4f | %.1f | %s |",
      performance$engine[[i]], performance$full_row_sec[[i]],
      performance$ingestion_sec[[i]], performance$engine_sec[[i]],
      performance$results_sec[[i]], performance$reported_core_sec[[i]],
      performance$core_bars_per_sec[[i]],
      performance$boundary[[i]]
    ), con)
  }
  writeLines(c("", "## Surface Availability", "", "| Engine | Equity | Fills | Trades |", "| --- | --- | --- | --- |"), con)
  for (i in seq_len(nrow(status))) {
    writeLines(sprintf(
      "| `%s` | `%s` | `%s` | `%s` |",
      status$engine[[i]], status$equity[[i]], status$fills[[i]], status$trades[[i]]
    ), con)
  }
}

peer_surface_status <- function(res) {
  data.frame(
    engine = res$engine,
    equity = if (identical(res$status, "DONE") && nrow(res$equity) > 0L) "available" else "unavailable",
    fills = if (identical(res$status, "DONE") && nrow(res$fills) > 0L) "available" else "unavailable",
    trades = if (nrow(res$trades) > 0L) res$trades$trade_level_status[[1L]] else "unavailable",
    stringsAsFactors = FALSE
  )
}

peer_main <- function(args = peer_parse_args()) {
  peer_load_ledgr_source()
  if (!requireNamespace("TTR", quietly = TRUE)) {
    stop("The peer benchmark needs TTR for the canonical ledgr row.")
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("The peer benchmark needs jsonlite to write metadata.")
  }
  dir.create(args$out_dir, recursive = TRUE, showWarnings = FALSE)
  bars <- as.data.frame(ledgr_sim_bars(
    n_instruments = args$n_inst,
    n_days = args$n_days,
    seed = args$seed,
    instrument_prefix = "PEER_"
  ))
  bars_path <- file.path(args$out_dir, sprintf("peer_benchmark_shared_bars_%s.csv", args$preset))
  utils::write.csv(bars, bars_path, row.names = FALSE)
  input_hash <- peer_hash_file(bars_path)

  canonical_features <- ledgr_feature_map(
    fast = peer_sma_ttr("fast", args$fast),
    slow = peer_sma_ttr("slow", args$slow)
  )
  canonical_strategy <- peer_strategy("fast", "slow")
  zero_cost <- peer_cost_zero_model()
  realistic_cost <- peer_cost_realistic_model()
  canonical <- peer_timed(peer_run_ledgr(
    engine = "ledgr_ttr_canonical",
    bars_path = bars_path,
    features = canonical_features,
    strategy = canonical_strategy,
    seed = args$seed,
    cost_model = zero_cost
  ))
  canonical_ephemeral <- peer_timed(peer_run_ledgr_ephemeral(
    engine = "ledgr_ttr_canonical_ephemeral",
    bars_path = bars_path,
    features = canonical_features,
    strategy = canonical_strategy,
    seed = args$seed,
    cost_model = zero_cost
  ))
  peer_compare_ledgr_surfaces(canonical, canonical_ephemeral)
  with_costs_ephemeral <- NULL
  legacy_costs_ephemeral <- NULL
  if (identical(args$engine_set, "ledgr-cost")) {
    with_costs_ephemeral <- peer_timed(peer_run_ledgr_ephemeral(
      engine = "ledgr_ttr_canonical_ephemeral_with_costs",
      bars_path = bars_path,
      features = canonical_features,
      strategy = canonical_strategy,
      seed = args$seed,
      cost_model = realistic_cost
    ))
    legacy_costs_ephemeral <- peer_timed(peer_run_ledgr_ephemeral(
      engine = "ledgr_ttr_canonical_ephemeral_legacy_costs",
      bars_path = bars_path,
      features = canonical_features,
      strategy = canonical_strategy,
      seed = args$seed,
      cost_model = realistic_cost,
      cost_resolver = ledgr:::ledgr_cost_spread_commission_internal(spread_bps = 5, commission_fixed = 1),
      legacy_cost = TRUE
    ))
  }
  compiled_ephemeral <- NULL
  if (!is.null(args$compiled_accounting_model) && identical(args$engine_set, "all")) {
    compiled_ephemeral <- peer_timed(peer_run_ledgr_ephemeral(
      engine = "ledgr_ttr_compiled_spot_fifo_ephemeral",
      bars_path = bars_path,
      features = canonical_features,
      strategy = canonical_strategy,
      seed = args$seed,
      cost_model = zero_cost,
      compiled_accounting_model = args$compiled_accounting_model
    ))
    peer_compare_ledgr_surfaces(canonical, compiled_ephemeral)
  }
  results <- list(canonical, canonical_ephemeral)
  if (!is.null(with_costs_ephemeral)) {
    results <- c(results, list(with_costs_ephemeral, legacy_costs_ephemeral))
  }
  if (!is.null(compiled_ephemeral)) {
    results <- c(results, list(compiled_ephemeral))
  }
  if (identical(args$engine_set, "all")) {
    builtin <- peer_timed(peer_run_ledgr(
      engine = "ledgr_builtin_sma",
      bars_path = bars_path,
      features = ledgr_feature_map(fast = ledgr_ind_sma(args$fast), slow = ledgr_ind_sma(args$slow)),
      strategy = peer_strategy(sprintf("sma_%d", args$fast), sprintf("sma_%d", args$slow)),
      seed = args$seed,
      cost_model = zero_cost
    ))
    quantstrat <- peer_timed(peer_run_quantstrat(bars_path, args$fast, args$slow))
    backtrader <- peer_timed(peer_run_backtrader(bars_path, args$fast, args$slow))
    zipline_full <- peer_timed(peer_run_zipline_full(bars_path, args$fast, args$slow))
    lean <- peer_timed(peer_run_lean(bars_path, args$fast, args$slow))
    results <- c(results, list(builtin, quantstrat, backtrader, zipline_full, lean))
  }
  parity <- do.call(rbind, lapply(results[-1L], peer_parity, reference = canonical))
  statuses <- lapply(results, peer_surface_status)
  performance <- peer_performance_rows(results, args)
  paths <- peer_write_outputs(results, parity, statuses, performance, bars_path, input_hash, args)
  message("[peer-benchmark] wrote:")
  for (p in paths) message("  ", p)
  invisible(paths)
}

if (sys.nframe() == 0L) {
  peer_main()
}
