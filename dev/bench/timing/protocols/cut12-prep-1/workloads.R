# Cut 12 preparation and history-request clocks (LDG-3215 freezes the pinned
# clocks and noise; LDG-3217 gates lean preparation against them). Cut 12
# decision (5): preparation and each registered history read at most 1.0x
# pinned on 500 x 5,040 and private H1.
#
# One slot builds (or, for H1, copies) a sealed store in its work directory,
# opens it with verification and runs the registered request set
# (dev/lean_core/parity/prep_fixture.R, lc_prep_strategy, copied below so the
# protocol folder is self-contained) as monthly top-20 momentum. Wrappers on
# the pinned namespace time two endpoints in that one run:
#   prep  wall time inside the outermost calls of the preparation functions
#         (substrate from the snapshot, including bar hydration; feature
#         series; projection; feature binding; availability provider; fold
#         reader, including the read service; the fold's valuation state)
#         plus the history mask planes built on first read
#         (ledgr_history_prepare_masks, ledgr_history_prepare_positions),
#         wherever they run
#   r1-r6 wall time inside each public request call, by its position in the
#         set, minus mask-plane time inside it
# The work string pins decided pulses, fills, final equity, every request's
# call count and a digest of its results (format-2 serialization), so both
# arms of a record return the same values. Private runs report counts and
# digests only.

cut12_prep_strategy <- function(ctx, params) {
  if (!is.null(params$read_at) && !endsWith(ctx$ts_utc, params$read_at)) return(ctx$hold())
  ledgr::ledgr_history_matrix(ctx, bar = "close", lookback = params$long)
  ledgr::ledgr_history_matrix(ctx, feature = params$feature, lookback = params$long)
  ledgr::ledgr_history_frame(ctx, bar = "close", lookback = params$mid, instruments = "decision_axis",
                             layout = "long")
  ledgr::ledgr_history_frame(ctx, feature = params$feature, lookback = params$mid, layout = "wide")
  ledgr::ledgr_history_matrix(ctx, bar = "close", lookback = params$short, min_observations = params$min_obs)
  ledgr::ledgr_history_frame(ctx, bar = "close", lookback = params$short, instruments = params$off_axis,
                             layout = "long")
  if (isTRUE(params$all_history)) {
    ledgr::ledgr_history_frame(ctx, bar = "close", lookback = Inf, layout = "wide")
    ledgr::ledgr_history_matrix(ctx, feature = params$feature, lookback = Inf)
  }
  if (!isTRUE(params$trade)) return(ctx$hold())
  score <- ledgr::ledgr_signal_return(ctx, params$lookback)
  selected <- ledgr::ledgr_select_top(score, n = params$n, within = ctx$buyable)
  target <- ledgr::ledgr_target_rebalance(ctx, weights = ledgr::ledgr_weight_equal(selected), invest_fraction = 0.95,
                                          index_leavers = "keep", capital_base = "remaining_equity")
  list(targets = target)
}

# The WS16 entry momentum snapshot (dev/bench/v0_2_3_ws16_entry/workloads.R).
cut12_prep_snapshot <- function(n_inst, n_days, db_path, snapshot_id, seed = 20260530L) {
  bars <- ledgr::ledgr_sim_bars(n_inst, n_days, seed = seed, start = "2000-01-03", instrument_prefix = "P")
  dates <- as.Date(bars$ts_utc)
  bars$ts_utc <- as.POSIXct(paste(dates, "16:00:00"), tz = "UTC")
  for (name in c("open", "high", "low", "close", "volume")) bars[[name]] <- round(bars[[name]], 8L)
  days <- seq(min(dates), max(dates), by = "day")
  open <- days %in% dates
  sessions <- ledgr::ledgr_facts_sessions(data.frame(
    session_date = days, status = ifelse(open, "open", "closed"),
    session_open = ifelse(open, "09:30:00", NA_character_),
    session_close = ifelse(open, "16:00:00", NA_character_),
    knowledge_time = as.POSIXct(days, tz = "UTC") - 1, stringsAsFactors = FALSE
  ), venue_id = "XNYS")
  ledgr::ledgr_snapshot_from_df(bars, db_path = db_path, snapshot_id = snapshot_id,
                                facts = ledgr::ledgr_facts(sessions), price_basis = "split_adjusted")
}

# The long and thin intraday shapes (dev/lean_core/parity/prep_fixture.R,
# lc_prep_intraday_snapshot): rectangular 5-minute bars on the bar-native clock.
cut12_prep_intraday_snapshot <- function(n_inst, n_days, db_path, snapshot_id, seed = 20261107L) {
  days <- seq(as.Date("2015-01-05"), by = "day", length.out = ceiling(n_days * 7 / 5) + 7L)
  days <- days[!format(days, "%u") %in% c("6", "7")][seq_len(n_days)]
  ts <- as.POSIXct(paste(rep(days, each = 78L), "14:30:00"), tz = "UTC") + rep(300 * seq_len(78L), n_days)
  old <- if (exists(".Random.seed", globalenv())) get(".Random.seed", globalenv())
  on.exit(if (is.null(old)) rm(".Random.seed", envir = globalenv()) else assign(".Random.seed", old, globalenv()))
  set.seed(seed)
  ids <- sprintf("I%02d", seq_len(n_inst))
  bars <- do.call(rbind, lapply(seq_len(n_inst), function(i) {
    close <- round((50 + 10 * i) * exp(cumsum(stats::rnorm(length(ts), 0, 0.001))), 8L)
    data.frame(instrument_id = ids[[i]], ts_utc = ts, open = round(close * (1 - 0.0002), 8L),
               high = round(close * 1.0005, 8L), low = round(close * 0.9995, 8L), close = close,
               volume = round(1000 + 100 * stats::runif(length(ts)), 8L))
  }))
  ledgr::ledgr_snapshot_from_df(bars, db_path = db_path, snapshot_id = snapshot_id)
}

cut12_prep_intraday_shapes <- list(intraday_1x100k = c(1L, 1290L), intraday_5x100k = c(5L, 1290L),
                                   intraday_20x50k = c(20L, 645L))

cut12_prep <- function(args, work_dir) {
  ns <- asNamespace("ledgr")
  store <- file.path(work_dir, "store.duckdb")
  intraday <- cut12_prep_intraday_shapes[[args$shape]]
  if (!is.null(intraday)) {
    id <- sprintf("lc_prep_intraday_%dx%d", intraday[[1L]], intraday[[2L]])
    ledgr::ledgr_snapshot_close(cut12_prep_intraday_snapshot(intraday[[1L]], intraday[[2L]], store, id))
    universe <- NULL
  } else if (identical(args$shape, "500x5040")) {
    id <- "cut12_prep_500x5040"
    ledgr::ledgr_snapshot_close(cut12_prep_snapshot(500L, 5040L, store, id))
    universe <- NULL
  } else if (identical(args$shape, "h1")) {
    state <- jsonlite::read_json(args$state, simplifyVector = TRUE)
    if (!file.copy(state$snapshot_path, store)) stop("could not copy the sealed snapshot")
    id <- state$snapshot_id
    universe <- state$universe_id
  } else {
    stop("unknown shape ", args$shape)
  }
  con <- DBI::dbConnect(duckdb::duckdb(), store, read_only = TRUE)
  first <- DBI::dbGetQuery(con, "SELECT min(instrument_id) AS id FROM snapshot_instruments WHERE snapshot_id = ?",
                           params = list(id))$id
  DBI::dbDisconnect(con, shutdown = TRUE)
  snapshot <- ledgr::ledgr_snapshot_open(store, id, verify = TRUE)
  if (!is.null(intraday)) {
    exp <- ledgr::ledgr_experiment(snapshot, cut12_prep_strategy,
                                   features = ledgr::ledgr_feature_map(ret = ledgr::ledgr_ind_returns(78L)),
                                   opening = ledgr::ledgr_opening(cash = 1e6), cost_model = ledgr::ledgr_cost_zero())
    params <- list(long = 2340L, mid = 390L, short = 78L, min_obs = 60L, feature = "ret", off_axis = first,
                   all_history = FALSE, trade = FALSE, read_at = "T21:00:00Z")
  } else {
    exp_args <- list(snapshot, cut12_prep_strategy,
                     features = ledgr::ledgr_feature_map(ret = ledgr::ledgr_ind_returns(252L)),
                     schedule = ledgr::ledgr_schedule_month_start(), opening = ledgr::ledgr_opening(cash = 1e6),
                     cost_model = ledgr::ledgr_cost_zero())
    if (!is.null(universe)) {
      exp_args$universe <- ledgr::ledgr_universe_members(universe)
      exp_args$valuation_policy <- ledgr::ledgr_valuation_stale(5L)
    }
    exp <- do.call(ledgr::ledgr_experiment, exp_args)
    params <- list(long = 252L, mid = 63L, short = 21L, min_obs = 15L, feature = "ret", off_axis = first,
                   all_history = FALSE, trade = TRUE, lookback = 252L, n = 20L)
  }

  now <- function() as.numeric(Sys.time())
  sha <- function(x) digest::digest(serialize(x, NULL, version = 2L), algo = "sha256", serialize = FALSE)
  clk <- new.env()
  clk$prep <- 0
  clk$in_prep <- FALSE
  clk$masks_in_read <- 0
  clk$in_read <- FALSE
  clk$k <- 0L
  clk$valuation_seen <- FALSE
  clk$req <- numeric(6L)
  clk$digests <- replicate(6L, character(), simplify = FALSE)
  originals <- list()
  install <- function(name, make) {
    orig <- get(name, envir = ns)
    originals[[name]] <<- orig
    unlockBinding(name, ns)
    assign(name, make(orig), envir = ns)
    lockBinding(name, ns)
  }
  prep_fns <- c("ledgr_history_substrate_for_experiment", "ledgr_history_compute_feature_series",
                "ledgr_projection_from_feature_matrix", "ledgr_history_substrate_bind_features",
                "ledgr_availability_provider_from_substrate", "ledgr_history_substrate_fold_reader")
  for (name in prep_fns) install(name, function(orig) {
    force(orig)
    function(...) {
      if (clk$in_prep) return(orig(...))
      clk$in_prep <- TRUE
      t0 <- now()
      on.exit({ clk$prep <- clk$prep + (now() - t0); clk$in_prep <- FALSE })
      orig(...)
    }
  })
  # The fold's valuation state is its first call; results reads build their own.
  install("ledgr_availability_valuation_state", function(orig) {
    force(orig)
    function(...) {
      if (clk$valuation_seen || clk$in_prep) return(orig(...))
      clk$valuation_seen <- TRUE
      t0 <- now()
      on.exit(clk$prep <- clk$prep + (now() - t0))
      orig(...)
    }
  })
  for (name in c("ledgr_history_prepare_masks", "ledgr_history_prepare_positions")) install(name, function(orig) {
    force(orig)
    function(...) {
      if (clk$in_prep) return(orig(...))
      t0 <- now()
      on.exit({
        e <- now() - t0
        clk$prep <- clk$prep + e
        if (clk$in_read) clk$masks_in_read <- clk$masks_in_read + e
      })
      orig(...)
    }
  })
  for (name in c("ledgr_history_matrix", "ledgr_history_frame")) install(name, function(orig) {
    force(orig)
    function(...) {
      if (clk$in_read) return(orig(...))
      k <- clk$k %% 6L + 1L
      clk$k <- clk$k + 1L
      clk$in_read <- TRUE
      m0 <- clk$masks_in_read
      t0 <- now()
      res <- orig(...)
      clk$req[[k]] <- clk$req[[k]] + (now() - t0) - (clk$masks_in_read - m0)
      clk$in_read <- FALSE
      clk$digests[[k]] <- c(clk$digests[[k]], sha(res))
      res
    }
  })
  on.exit(for (name in names(originals)) {
    unlockBinding(name, ns)
    assign(name, originals[[name]], envir = ns)
    lockBinding(name, ns)
  }, add = TRUE)

  bt <- ledgr::ledgr_run(exp, params = params, run_id = "cut12-prep", seed = 1L)
  n_fills <- nrow(ledgr::ledgr_results(bt, "fills"))
  eq <- ledgr::ledgr_results(bt, "equity")
  close(bt)
  ledgr::ledgr_snapshot_close(snapshot)
  calls <- lengths(clk$digests)
  if (clk$k %% 6L != 0L || length(unique(calls)) != 1L) stop("request calls did not come in sets of six: ", clk$k)
  # The private H1 store reports its final equity as a digest prefix.
  equity <- format(eq$equity[nrow(eq)], digits = 17)
  if (identical(args$shape, "h1")) equity <- substr(sha(equity), 1L, 12L)
  work <- paste(args$shape, calls[[1L]], n_fills, equity,
                paste(vapply(clk$digests, function(d) substr(sha(d), 1L, 12L), ""), collapse = ","), sep = "|")
  list(seconds = c(prep = clk$prep, stats::setNames(clk$req, paste0("r", 1:6))), work = work)
}
