# Constructed slice-1 workloads and the Section 19.2 witnesses for the loop
# parity runner (LDG-3219; interface Sections 19.2, 19.4 and 19.6). Each
# entry builds its snapshot with public constructors and returns its tables;
# the pin is the oracle. Sourced by loop_parity.R after its helpers (build,
# collect, collect_open, ns, work).

# A daily fixed basket with deterministic prices; `px` gives each
# instrument's base price.
lw_bars <- function(px, n_days, drift = 0.01) {
  dates <- as.POSIXct("2021-01-04", tz = "UTC") + 86400 * (seq_len(n_days) - 1L)
  rows <- lapply(names(px), function(id) {
    step <- seq_len(n_days)
    close <- px[[id]] * (1 + drift * sin(step + match(id, names(px))))
    open <- px[[id]] * (1 + drift * cos(step + match(id, names(px))))
    data.frame(instrument_id = id, ts_utc = dates, open = open, high = pmax(open, close) * 1.001,
               low = pmin(open, close) * 0.999, close = close, volume = 1000, stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

lw_snapshot <- function(name, bars) {
  db <- build(name, function(db) ledgr::ledgr_snapshot_from_df(bars, db_path = db, snapshot_id = name))
  db
}

# A strategy whose targets come from a per-day table (ISO day -> named
# quantities); other days hold.
lw_schedule_strategy <- function(plan) {
  force(plan)
  strategy <- function(ctx, params) {
    targets <- ctx$hold()
    day <- substr(ctx$ts_utc, 1L, 10L)
    want <- plan[[day]]
    if (!is.null(want)) targets[names(want)] <- want
    targets
  }
  environment(strategy) <- list2env(list(plan = plan), parent = ns)
  strategy
}

lw_plain <- function(name, bars, plan, cash, ...) function() {
  db <- lw_snapshot(name, bars)
  exp <- function(snapshot) ledgr::ledgr_experiment(snapshot, lw_schedule_strategy(plan),
    opening = ledgr::ledgr_opening(cash = cash), cost_model = ledgr::ledgr_cost_zero(), ...)
  collect(db, name, paste0("lw-", name), exp, seed = 11L)
}

lw_days <- function(n) format(as.POSIXct("2021-01-04", tz = "UTC") + 86400 * (seq_len(n) - 1L), "%Y-%m-%d")

loop_constructed <- list(
  # Insufficient-cash rejections and the affordability order: a buy batch
  # larger than cash, then a cash-generating sale beside a buy.
  tight_cash = local({
    d <- lw_days(10L)
    plan <- stats::setNames(list(c(A = 3, B = 2, C = 2), c(A = 0, C = 3), c(A = 5, B = 4, C = 4), c(B = 0)),
                            d[c(2L, 4L, 6L, 8L)])
    lw_plain("lw_tight_cash", lw_bars(c(A = 10, B = 20, C = 30), 10L), plan, cash = 100)
  }),
  # A sell and a buy on the same pulse, then a partial reduction.
  sell_buy_same_pulse = local({
    d <- lw_days(8L)
    plan <- stats::setNames(list(c(A = 5), c(A = 0, B = 3), c(A = 2, B = 1)), d[c(1L, 3L, 5L)])
    lw_plain("lw_sell_buy", lw_bars(c(A = 40, B = 25), 8L), plan, cash = 1000)
  }),
  # Trades requested on the last two pulses: the final pulse has no next bar.
  final_pulse_trades = local({
    d <- lw_days(6L)
    plan <- stats::setNames(list(c(A = 2, B = 2), c(A = 1, B = 4), c(A = 0, B = 0)), d[c(2L, 5L, 6L)])
    lw_plain("lw_final", lw_bars(c(A = 15, B = 60), 6L), plan, cash = 500)
  }),
  # The affordability reconciliation stop (cut review R1): the probe of
  # cut_review_13 (cash-only, prices near 1e16), INCOMPLETE.
  reconciliation_stop = function() {
    dates <- as.POSIXct("2020-01-01 21:00:00", tz = "UTC") + 86400 * (0:3)
    bars <- expand.grid(instrument_id = c("A", "B", "C"), ts_utc = dates, stringsAsFactors = FALSE)
    bars$open <- bars$high <- bars$low <- bars$close <- ifelse(bars$instrument_id == "A", 1, 1e16)
    bars$volume <- 100
    db <- lw_snapshot("lw_recon_stop", bars)
    strategy <- function(ctx, params) {
      target <- if (ctx$state$n == 0L) c(A = 1, B = 1, C = 0) else c(A = 0, B = 0, C = 1)
      ledgr_strategy_result(target, n = ctx$state$n + 1L)
    }
    environment(strategy) <- ns
    exp <- function(snapshot) ledgr::ledgr_experiment(snapshot, strategy, opening = ledgr::ledgr_opening(cash = 1e16),
      cost_model = ledgr::ledgr_cost_zero(), portfolio_state = list(n = 0L))
    collect(db, "lw_recon_stop", "lw-recon-stop", exp)
  }
)

# --- Section 19.2 witnesses ---------------------------------------------------

lw_feature_map <- function() ledgr::ledgr_feature_map(
  fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "sma_3", n = 3L),
  slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "sma_5", n = 5L))

lw_witness_db <- function() lw_snapshot("lw_witness", lw_bars(c(A = 30, B = 45, C = 12), 14L, drift = 0.05))

# Return forms, state rules, intent reasons, every public context read,
# retained not-yet-forced fields, and seeded and unseeded RNG draws.
lw_surface_strategy <- function() {
  kept <- new.env(parent = emptyenv())
  strategy <- function(ctx, params) {
    # Values read, as one string: every double at 17 digits, NA as NA.
    lw_digest <- function(...) {
      parts <- vapply(list(...), function(x) {
        if (inherits(x, "POSIXct")) x <- as.numeric(x)
        v <- if (is.double(x)) sprintf("%.17g", x) else as.character(x)
        paste(names(x), v, sep = "=", collapse = ",")
      }, character(1L))
      paste(parts, collapse = ";")
    }
    i <- as.integer(as.Date(substr(ctx$ts_utc, 1L, 10L)) - as.Date("2021-01-04")) + 1L   # pulse number
    if (i == 1L) kept$first <- ctx
    reads <- lw_digest(
      ctx$open, ctx$high, ctx$low, ctx$close, ctx$volume, ctx$position, ctx$held, ctx$member, ctx$buyable,
      ctx$holding_value, ctx$entry_price, ctx$entry_at, ctx$exit_at, ctx$bars_since_entry, ctx$bars_since_exit,
      ctx$fast, ctx[["sma_5"]], ctx$cash, ctx$equity, ctx$flat(), ctx$flat(2), ctx$state$n, ctx$state$tag,
      draw = stats::runif(1L), seed = if (is.null(ctx$pulse_seed)) NA_real_ else ctx$pulse_seed)
    reads <- paste(reads, paste(names(ctx), collapse = ","), paste(ctx$universe, collapse = ","),
                   paste(utils::capture.output(str(ctx)), collapse = "|"), sep = "#")
    if (i >= 6L) reads <- paste(reads, lw_digest(kept$first$close, kept$first$slow, kept$first$entry_at), sep = "#")
    targets <- ctx$hold()
    targets[["A"]] <- (i %% 3L) + (params$k %||% 1)
    targets[["B"]] <- if (i %% 4L == 0L) 0 else 2
    targets[["C"]] <- floor(10 * stats::runif(1L))
    tag <- if (i %% 5L == 0L) NA_character_ else paste0("t", i)
    switch(as.character(i %% 6L),
      "0" = targets,                                                   # raw numeric, state kept
      "1" = ledgr::ledgr_target(targets),                              # ledgr_target form
      "2" = list(targets = targets, state_update = list(n = i, tag = tag), intent_reason = reads),
      "3" = ledgr::ledgr_strategy_result(targets, n = i, tag = tag, intent_reason = reads),
      "4" = ledgr::ledgr_strategy_result(targets, n = i, intent_reason = "patch n only"),
      "5" = if (i == 11L) ledgr::ledgr_strategy_result(targets, reset_state = TRUE) else
        ledgr::ledgr_strategy_result(targets, n = i, tag = NA_character_))
  }
  environment(strategy) <- list2env(list(kept = kept), parent = ns)
  strategy
}

lw_surface_exp <- function(snapshot) ledgr::ledgr_experiment(snapshot, lw_surface_strategy(),
  features = lw_feature_map(), opening = ledgr::ledgr_opening(cash = 5000), cost_model = ledgr::ledgr_cost_zero(),
  portfolio_state = list(n = 0L, tag = "start"))

# Trades every pulse with unseeded draws; from pulse 6 it reads history
# through a name the static scan does not see. With `caught`, the strategy
# wraps that read in its own error handler.
lw_backstop_exp <- function(snapshot, caught = FALSE, rethrow = FALSE) {
  strategy <- function(ctx, params) {
    i <- as.integer(as.Date(substr(ctx$ts_utc, 1L, 10L)) - as.Date("2021-01-04")) + 1L
    targets <- ctx$hold()
    targets[["A"]] <- floor(5 * stats::runif(1L)) + (params$k %||% 0)
    if (i >= 6L) {
      read <- getExportedValue("ledgr", paste0("ledgr_history", "_matrix"))
      m <- if (CAUGHT) tryCatch(read(ctx, bar = "close", lookback = 2L), error = function(e) if (RETHROW) stop("history read failed") else NA_real_)
           else read(ctx, bar = "close", lookback = 2L)
      targets[["B"]] <- if (is.finite(sum(m))) 1 else 0
    }
    targets
  }
  body(strategy) <- do.call(substitute, list(body(strategy), list(CAUGHT = isTRUE(caught), RETHROW = isTRUE(rethrow))))
  environment(strategy) <- ns
  ledgr::ledgr_experiment(snapshot, strategy, opening = ledgr::ledgr_opening(cash = 5000),
    cost_model = ledgr::ledgr_cost_zero())
}

# Cut 15 R3: contexts kept from pulse 1 and pulse 4, read on every later
# pulse after fills and declared-state updates. Each keeps some reads forced
# at its own pulse (cache hits later) and leaves others for the first time
# later (unforced): positions, cash, equity, declared portfolio and asset
# state, hold()/flat(), features, bars and lazy position-fact fields. The
# values read go out through the intent reason, so the decision rows carry
# them into the compared tables.
lw_retained_strategy <- function() {
  kept <- new.env(parent = emptyenv())
  strategy <- function(ctx, params) {
    dig <- function(...) paste(vapply(list(...), function(x) {
      if (inherits(x, "POSIXct")) x <- as.numeric(x)
      v <- if (is.double(x)) sprintf("%.17g", x) else as.character(x)
      paste(names(x), v, sep = "=", collapse = ",")
    }, character(1L)), collapse = ";")
    i <- as.integer(as.Date(substr(ctx$ts_utc, 1L, 10L)) - as.Date("2021-01-04")) + 1L
    if (i == 1L) {
      kept$a <- ctx
      invisible(list(ctx$fast, ctx$close, ctx$hold()))
    }
    if (i == 4L) {
      kept$b <- ctx
      invisible(list(ctx$slow, ctx$entry_at, ctx$position))
    }
    reads <- "first"
    for (nm in c("a", "b")) {
      k <- kept[[nm]]
      if (is.null(k) || identical(k, ctx)) next
      reads <- paste(reads, nm, dig(k$cash, k$equity, k$position, k$held, k$state$n, k$state$flag, k$hold(),
        k$flat(), k$flat(3), k$fast, k$slow, k$close, k$open, k$volume, k$entry_at, k$entry_price,
        k$bars_since_entry, k$holding_value), sep = "|")
    }
    targets <- ctx$hold()
    targets[["A"]] <- (i %% 3L) + 1
    targets[["B"]] <- if (i %% 2L == 0L) 2 else 0
    flag <- ctx$state$flag
    flag[] <- (seq_along(flag) + i) %% 2L == 0L
    ledgr::ledgr_strategy_result(targets, n = i, flag = flag, intent_reason = reads)
  }
  environment(strategy) <- list2env(list(kept = kept), parent = ns)
  strategy
}

# Cut 15 R2: the strategy-error boundary on pulse 5, after earlier fills:
# an error with an on.exit cleanup, a cleanup that itself errors, or a
# custom error class carrying data. The cleanup also rewrites the pulse
# lookup's available-feature message, which the wrapper reads when it builds
# its own message, so the final message shows whether the error was wrapped
# before or after the callback unwound. A calling handler inside the outer
# tryCatch logs every error signal that reaches the caller. Tables: the
# events, the final condition's classes, message, parent and original_error,
# the store and the caller's RNG state.
lw_error_boundary <- function(case, seed = NULL) {
  db <- lw_witness_db()
  log <- new.env(parent = emptyenv())
  log$events <- character()
  strategy <- function(ctx, params) {
    i <- as.integer(as.Date(substr(ctx$ts_utc, 1L, 10L)) - as.Date("2021-01-04")) + 1L
    targets <- ctx$hold()
    targets[["A"]] <- (i %% 3L) + 1
    cleanup <- function() {
      log$events <- c(log$events, "cleanup")
      lookup <- .subset2(ctx, paste0(".pulse", "_lookup"))   # a name the preflight scan does not see
      prepared <- lookup$feature_lookup
      prepared$available_message <- "after_cleanup"
      lookup$feature_lookup <- prepared
    }
    if (i == 5L) {
      log$events <- c(log$events, sprintf("draw:%.17g", stats::runif(1L)))
      if (identical(case, "cleanup")) {
        on.exit(cleanup())
        stop("primary failure")
      }
      if (identical(case, "cleanup_error")) {
        on.exit({
          cleanup()
          stop("cleanup failure")
        })
        stop("primary failure")
      }
      stop(structure(class = c("lw_custom_error", "error", "condition"),
                     list(message = "custom failure", call = NULL, data = 42L)))
    }
    targets
  }
  environment(strategy) <- list2env(list(log = log, case = case), parent = ns)
  run_id <- paste0("lw-error-", case, if (!is.null(seed)) "-seeded")
  snapshot <- ledgr::ledgr_snapshot_open(db, "lw_witness", verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  exp <- ledgr::ledgr_experiment(snapshot, strategy, opening = ledgr::ledgr_opening(cash = 5000),
    cost_model = ledgr::ledgr_cost_zero())
  set.seed(4250L)
  res <- tryCatch(withCallingHandlers(ledgr::ledgr_run(exp, run_id = run_id, seed = seed),
    error = function(e) log$events <- c(log$events, paste0("signal:", paste(class(e), collapse = "/")))),
    error = function(e) e)
  cnd <- if (inherits(res, "condition")) res else NULL
  if (is.null(cnd)) close(res)
  parent <- cnd$parent
  field <- c("events", "class", "message", "parent_class", "parent_message", "parent_data", "original_is_parent")
  value <- c(paste(log$events, collapse = " > "), paste(class(cnd), collapse = "/"),
             if (is.null(cnd)) "<none>" else conditionMessage(cnd),
             paste(class(parent), collapse = "/"), if (is.null(parent)) "<none>" else conditionMessage(parent),
             paste(format(parent$data), collapse = ","), as.character(identical(cnd$original_error, parent)))
  lw_rng_table(list(run = c(a0_store_tables(db, run_id),
    list(error_boundary = data.frame(field = field, value = value, stringsAsFactors = FALSE)))))
}

# Whether the lean loop is installed (the lean arm of a parity run).
lw_lean_installed <- function() identical(get("ledgr_fold_envelope", envir = ns), lean$lean_fold_envelope)

# Rebinds a ledgr namespace function; returns the restore.
lw_rebind <- function(name, value) {
  old <- get(name, envir = ns)
  unlockBinding(name, ns); assign(name, value, envir = ns); lockBinding(name, ns)
  function() { unlockBinding(name, ns); assign(name, old, envir = ns); lockBinding(name, ns) }
}

# Reads before each strategy call: the committed fill-event count and, for
# a memory sink, a digest of the committed event table. The pin is read
# through its handler (captured from the envelope), the lean loop through
# its committed-prefix reads.
lw_prefix_reads <- function(memory, workload = NULL) {
  seen <- new.env(parent = emptyenv())
  seen$rows <- list()
  installed <- lw_lean_installed()
  restore_env <- function() NULL
  if (!installed) {
    restore_env <- lw_rebind("ledgr_fold_envelope", local({
      inner <- get("ledgr_fold_envelope", envir = ns)
      function(execution, output_handler) { seen$h <- output_handler; inner(execution, output_handler) }
    }))
  }
  restore_call <- lw_rebind("ledgr_call_strategy_fn", local({
    inner <- get("ledgr_call_strategy_fn", envir = ns)
    function(fn, ctx, params, signature) {
      events <- if (!memory) NULL else if (installed) lean$lean_entry$committed$events() else seen$h$events()
      count <- if (memory) nrow(events) else if (installed) lean$lean_entry$committed$count() else seen$h$pending_event_count()
      seen$rows[[length(seen$rows) + 1L]] <- data.frame(ts_utc = unclass(ctx)$ts_utc, events = count,
        digest = if (memory) digest::digest(as.data.frame(events)) else "", stringsAsFactors = FALSE)
      inner(fn, ctx, params, signature)
    }
  }))
  restore_recon <- lw_rebind("ledgr_fold_reconciliation_check", local({
    inner <- get("ledgr_fold_reconciliation_check", envir = ns)
    function(...) {
      count <- if (installed) lean$lean_entry$committed$count() else if (memory) nrow(seen$h$events()) else
        seen$h$pending_event_count()
      seen$rows[[length(seen$rows) + 1L]] <- data.frame(ts_utc = "reconciliation", events = count, digest = "",
        stringsAsFactors = FALSE)
      inner(...)
    }
  }))
  on.exit({ restore_recon(); restore_call(); restore_env() })
  tables <- if (is.function(workload)) workload() else if (memory) loop_witnesses$witness_sweep() else loop_constructed$sell_buy_same_pulse()
  path <- if (memory) "sweep" else "run"
  tables[[path]]$prefix_reads <- do.call(rbind, seen$rows)
  tables
}

# Trades from pulse 2; on pulse 6 the declared-state patch has the wrong
# type, refused at P5 after that pulse's fills are committed.
lw_state_refusal <- function() {
  db <- lw_witness_db()
  strategy <- function(ctx, params) {
    i <- as.integer(as.Date(substr(ctx$ts_utc, 1L, 10L)) - as.Date("2021-01-04")) + 1L
    targets <- ctx$hold()
    targets[["A"]] <- i
    if (i == 6L) ledgr::ledgr_strategy_result(targets, n = "six") else ledgr::ledgr_strategy_result(targets, n = i)
  }
  environment(strategy) <- ns
  exp <- function(snapshot) ledgr::ledgr_experiment(snapshot, strategy, opening = ledgr::ledgr_opening(cash = 5000),
    cost_model = ledgr::ledgr_cost_zero(), portfolio_state = list(n = 0L))
  collect(db, "lw_witness", "lw-state-refusal", exp)
}

# The caller's RNG stream after the run, as a table (restoration rules).
lw_rng_table <- function(tables, path = "run", entry = NULL) {
  tables[[path]]$rng_after <- lw_rng_state()
  if (!is.null(entry)) tables[[path]]$rng_entry <- entry
  tables
}
# The caller's RNG state at workload entry, then one draw from the caller's
# stream outside ledgr: ledgr_run() and ledgr_sweep() restore the caller's
# state themselves, so only a workload's own draws show a rerun that does
# not restore the entry state (round 4, finding 1).
lw_entry_draw <- function() {
  entry <- lw_rng_state()
  entry$draw <- stats::runif(1L)
  entry
}
# The caller's RNG kinds and seed (or its absence), as a one-row table.
lw_rng_state <- function() {
  seed <- if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) get(".Random.seed", envir = globalenv())
  data.frame(kind = paste(RNGkind(), collapse = ","),
             seed = if (is.null(seed)) "<absent>" else paste(seed, collapse = ","), stringsAsFactors = FALSE)
}

# The caller's RNG state at workload entry, set by the runner before each
# arm, outside the workload a backstop reruns (round 4, finding 1).
loop_entry_rng <- list(
  witness_backstop = function() set.seed(4242L),
  witness_backstop_sweep = function() set.seed(4243L),
  witness_caught_backstop = function() set.seed(4244L),
  witness_caught_backstop_sweep = function() set.seed(4245L),
  witness_caught_rethrow = function() set.seed(4246L),
  witness_caught_rethrow_sweep = function() set.seed(4247L),
  witness_outer_handler = function() set.seed(4248L),
  # No seed and a non-default kind: the rerun must restore the kind too.
  witness_backstop_kind = function() {
    suppressWarnings(RNGkind("Wichmann-Hill", "Box-Muller", "Rounding"))
    if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) rm(".Random.seed", envir = globalenv())
  }
)

loop_witnesses <- list(
  witness_surface_seeded = function() {
    db <- lw_witness_db()
    set.seed(20261110L)
    lw_rng_table(collect(db, "lw_witness", "lw-surface-seeded", lw_surface_exp, seed = 5L))
  },
  witness_surface_unseeded = function() {
    db <- lw_witness_db()
    set.seed(20261111L)
    lw_rng_table(collect(db, "lw_witness", "lw-surface-unseeded", lw_surface_exp))
  },
  # Correctly named but non-finite targets: the pin's refusal, FAILED.
  witness_nonfinite = function() {
    db <- lw_witness_db()
    strategy <- function(ctx, params) {
      targets <- ctx$hold()
      targets[["A"]] <- if (substr(ctx$ts_utc, 1L, 10L) == "2021-01-08") NA_real_ else 1
      targets
    }
    environment(strategy) <- ns
    exp <- function(snapshot) ledgr::ledgr_experiment(snapshot, strategy, opening = ledgr::ledgr_opening(cash = 5000),
      cost_model = ledgr::ledgr_cost_zero())
    collect(db, "lw_witness", "lw-nonfinite", exp)
  },
  # max_pulses through the run control: a nonterminal prefix.
  witness_max_pulses = function() {
    db <- lw_witness_db()
    exp <- function(snapshot) {
      e <- lw_surface_exp(snapshot)
      e$control <- list(max_pulses = 7L)
      e
    }
    set.seed(3L)
    collect(db, "lw_witness", "lw-max-pulses", exp, seed = 9L)
  },
  # The backstop (19.2 point 1): a history read the static scan cannot see,
  # on pulse 6 after earlier fills and unseeded draws. The lean attempt
  # aborts, the RNG state at entry is restored and the complete workload
  # reruns on the pin under the same run_id.
  witness_backstop = function() {
    entry <- lw_entry_draw()
    db <- lw_witness_db()
    lw_rng_table(entry = entry, collect(db, "lw_witness", "lw-backstop", lw_backstop_exp))
  },
  witness_backstop_sweep = function() {
    entry <- lw_entry_draw()
    db <- lw_witness_db()
    snapshot <- ledgr::ledgr_snapshot_open(db, "lw_witness", verify = TRUE)
    on.exit(ledgr::ledgr_snapshot_close(snapshot))
    grid <- ledgr::ledgr_grid_named(a = list(strategy = list(k = 1)), b = list(strategy = list(k = 2)))
    obs <- a0_observe_memory(ledgr::ledgr_sweep(lw_backstop_exp(snapshot), grid, retain = a0_retain()))
    lw_rng_table(entry = entry, list(sweep = c(a0_sweep_tables(obs$value), a0_memory_tables(obs$observed, obs$value))), "sweep")
  },
  # D3 Section 2: an explicit control$checkpoint_every key is refused before
  # the first pulse, even at the default value; the pin runs it.
  witness_checkpoint_control = function() {
    db <- lw_witness_db()
    exp <- function(snapshot) {
      e <- lw_surface_exp(snapshot)
      e$control <- list(checkpoint_every = 10000L)
      e
    }
    collect(db, "lw_witness", "lw-checkpoint", exp, seed = 6L)
  },
  # Close review round 1, finding 1: the strategy catches the stub's
  # condition with its own handler; the attempt must still rerun on the pin.
  witness_caught_backstop = function() {
    entry <- lw_entry_draw()
    db <- lw_witness_db()
    lw_rng_table(entry = entry, collect(db, "lw_witness", "lw-caught-backstop", function(s) lw_backstop_exp(s, caught = TRUE)))
  },
  witness_caught_backstop_sweep = function() {
    entry <- lw_entry_draw()
    db <- lw_witness_db()
    snapshot <- ledgr::ledgr_snapshot_open(db, "lw_witness", verify = TRUE)
    on.exit(ledgr::ledgr_snapshot_close(snapshot))
    grid <- ledgr::ledgr_grid_named(a = list(strategy = list(k = 1)), b = list(strategy = list(k = 2)))
    obs <- a0_observe_memory(ledgr::ledgr_sweep(lw_backstop_exp(snapshot, caught = TRUE), grid, retain = a0_retain()))
    lw_rng_table(entry = entry, list(sweep = c(a0_sweep_tables(obs$value), a0_memory_tables(obs$observed, obs$value))), "sweep")
  },
  # Round 2, finding 1: the strategy catches the condition, then fails with
  # its own error; the attempt must still rerun on the pin.
  witness_caught_rethrow = function() {
    entry <- lw_entry_draw()
    db <- lw_witness_db()
    lw_rng_table(entry = entry, collect(db, "lw_witness", "lw-caught-rethrow", function(s) lw_backstop_exp(s, caught = TRUE, rethrow = TRUE)))
  },
  witness_caught_rethrow_sweep = function() {
    entry <- lw_entry_draw()
    db <- lw_witness_db()
    snapshot <- ledgr::ledgr_snapshot_open(db, "lw_witness", verify = TRUE)
    on.exit(ledgr::ledgr_snapshot_close(snapshot))
    grid <- ledgr::ledgr_grid_named(a = list(strategy = list(k = 1)), b = list(strategy = list(k = 2)))
    obs <- a0_observe_memory(ledgr::ledgr_sweep(lw_backstop_exp(snapshot, caught = TRUE, rethrow = TRUE), grid,
      retain = a0_retain()))
    lw_rng_table(entry = entry, list(sweep = c(a0_sweep_tables(obs$value), a0_memory_tables(obs$observed, obs$value))), "sweep")
  },
  # Round 2, finding 2: a refusal after P5's commitment (a declared-state
  # type error on pulse 6, after fills), with committed reads at each
  # reconciliation check up to it.
  witness_state_refusal = function() lw_prefix_reads(memory = FALSE, workload = lw_state_refusal),
  # Round 3, finding 1: a state patch whose container is not a list (a
  # classed atomic vector) is refused by the pin in production; portfolio
  # and asset fields.
  witness_state_container = function() {
    db <- lw_witness_db()
    patch <- function(field, value) {
      strategy <- function(ctx, params) {
        i <- as.integer(as.Date(substr(ctx$ts_utc, 1L, 10L)) - as.Date("2021-01-04")) + 1L
        targets <- ctx$hold()
        targets[["A"]] <- i
        update <- if (i == 3L) structure(stats::setNames(VALUE, FIELD), class = "ledgr_strategy_state_patch") else NULL
        list(targets = targets, state_update = update)
      }
      body(strategy) <- do.call(substitute, list(body(strategy), list(FIELD = field, VALUE = value)))
      environment(strategy) <- ns
      strategy
    }
    run <- collect(db, "lw_witness", "lw-state-container", function(s) ledgr::ledgr_experiment(s, patch("n", 1L),
      opening = ledgr::ledgr_opening(cash = 5000), cost_model = ledgr::ledgr_cost_zero(), portfolio_state = list(n = 0L)))
    asset <- collect(db, "lw_witness", "lw-state-container-asset", function(s) ledgr::ledgr_experiment(s,
      patch("flag", TRUE), opening = ledgr::ledgr_opening(cash = 5000), cost_model = ledgr::ledgr_cost_zero(),
      asset_state = list(flag = FALSE)))
    list(run = run$run, run_asset = asset$run)
  },
  # Round 3, finding 5: a validated execution spec with no pulses returns the
  # pin's empty result through the installed envelope.
  witness_zero_pulses = function() {
    db <- lw_witness_db()
    seen <- new.env(parent = emptyenv())
    restore <- lw_rebind("ledgr_fold_envelope", local({
      inner <- get("ledgr_fold_envelope", envir = ns)
      function(execution, output_handler) { seen$execution <- execution; seen$inner <- inner; inner(execution, output_handler) }
    }))
    on.exit(restore())
    tables <- collect(db, "lw_witness", "lw-zero-source", function(s) ledgr::ledgr_experiment(s,
      lw_schedule_strategy(list()), opening = ledgr::ledgr_opening(cash = 5000), cost_model = ledgr::ledgr_cost_zero(),
      asset_state = list(flag = FALSE)))
    e <- seen$execution
    e$pulses_posix <- e$pulses_posix[0L]
    e$pulses_iso <- character()
    e$execution_opportunities_posix <- e$execution_opportunities_posix[0L]
    # Round 4, finding 2: the full return (telemetry aside, an allowed
    # difference) on the fold's axis and on a reordered incoming state axis.
    reordered <- e
    reordered$strategy_state$axis <- rev(e$strategy_state$axis)
    reordered$strategy_state$values$flag <- e$strategy_state$values$flag[reordered$strategy_state$axis]
    for (case in c("aligned", "reordered")) {
      h <- ns$ledgr_output_handler(ns$ledgr_output_sink_memory("lw-zero"))
      spec <- ns$ledgr_validate_execution_spec(if (case == "aligned") e else reordered)
      res <- tryCatch(seen$inner(spec, h), error = function(err) err)
      tables$run[[paste0("zero_pulses_", case)]] <- if (inherits(res, "error")) {
        data.frame(field = "<error>", value = class(res)[[1L]], stringsAsFactors = FALSE)
      } else {
        fields <- setdiff(names(res), "telemetry")
        data.frame(field = c(fields, "diagnostics", "completion_null"),
                   value = c(vapply(res[fields], rlang::hash, ""), as.character(NROW(h$diagnostics())),
                             as.character(is.null(h$completion()))), stringsAsFactors = FALSE)
      }
    }
    tables
  },
  # Round 3, finding 2: the caller wraps the workload in its own handler; a
  # marked attempt still reruns on the pin.
  witness_outer_handler = function() {
    entry <- lw_entry_draw()
    db <- lw_witness_db()
    snapshot <- ledgr::ledgr_snapshot_open(db, "lw_witness", verify = TRUE)
    on.exit(ledgr::ledgr_snapshot_close(snapshot))
    tryCatch(close(ledgr::ledgr_run(lw_backstop_exp(snapshot), run_id = "lw-outer")),
             error = function(e) stop("job failed: ", conditionMessage(e), call. = FALSE))
    lw_rng_table(entry = entry, list(run = c(a0_store_tables(db, "lw-outer"), a0_reader_tables(snapshot, "lw-outer"))))
  },
  # Round 4, finding 1: the caller enters with no seed and a non-default
  # kind (loop_entry_rng), and the workload itself seeds under another kind.
  # A rerun that restores only the seed starts from the workload's kind.
  witness_backstop_kind = function() {
    entry <- lw_rng_state()
    set.seed(77L, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
    tables <- lw_rng_table(collect(lw_witness_db(), "lw_witness", "lw-backstop-kind", lw_backstop_exp))
    tables$run$rng_entry <- entry
    tables
  },
  # Round 4, finding 3: a sweep with workers. Since Cut 26 every worker
  # loads the lean fold (loop_workers.R); the workers load the pinned
  # library, not this source tree (the working directory is moved off it).
  witness_sweep_workers = function() {
    db <- lw_witness_db()
    snapshot <- ledgr::ledgr_snapshot_open(db, "lw_witness", verify = TRUE)
    on.exit(ledgr::ledgr_snapshot_close(snapshot))
    old <- setwd(work)
    on.exit(setwd(old), add = TRUE)
    strategy <- function(ctx, params) {
      targets <- ctx$hold()
      targets[["A"]] <- params$qty
      targets
    }
    environment(strategy) <- ns
    exp <- ledgr::ledgr_experiment(snapshot, strategy, opening = ledgr::ledgr_opening(cash = 5000),
      cost_model = ledgr::ledgr_cost_zero())
    grid <- ledgr::ledgr_grid_named(a = list(strategy = list(qty = 1)), b = list(strategy = list(qty = 2)))
    obs <- a0_observe_memory(ledgr::ledgr_sweep(exp, grid, seed = 5L, workers = 2L, retain = a0_retain()))
    list(sweep = c(a0_sweep_tables(obs$value), a0_memory_tables(obs$observed, obs$value)))
  },
  # Round 3, finding 3: walk-forward is refused at entry (slice 5) and runs
  # on the pin.
  witness_walk_forward = function() {
    db <- lw_witness_db()
    snapshot <- ledgr::ledgr_snapshot_open(db, "lw_witness", verify = TRUE)
    on.exit(ledgr::ledgr_snapshot_close(snapshot))
    strategy <- function(ctx, params) {
      targets <- ctx$hold()
      targets[["A"]] <- params$qty
      targets
    }
    environment(strategy) <- ns
    exp <- ledgr::ledgr_experiment(snapshot, strategy, opening = ledgr::ledgr_opening(cash = 5000),
      cost_model = ledgr::ledgr_cost_zero())
    grid <- ledgr::ledgr_grid_named(small = list(strategy = list(qty = 2)), large = list(strategy = list(qty = 4)))
    folds <- ns$ledgr_fold_list(list(
      ledgr::ledgr_fold("2021-01-04T00:00:00Z", "2021-01-07T00:00:00Z", "2021-01-08T00:00:00Z", "2021-01-11T00:00:00Z", fold_seq = 1L),
      ledgr::ledgr_fold("2021-01-08T00:00:00Z", "2021-01-11T00:00:00Z", "2021-01-12T00:00:00Z", "2021-01-17T00:00:00Z", fold_seq = 2L)
    ), constructor = list(type_id = "explicit"))
    wf <- ledgr::ledgr_walk_forward(exp, grid = grid, folds = folds, selection_rule = ledgr::ledgr_rule_argmax("sharpe_ratio"),
                                    seed = 24L)
    ids <- vapply(wf$test_runs, function(bt) bt$run_id, character(1L))
    lapply(wf$test_runs, close)
    list(walk_forward = c(list(
      wf_folds = a0_canon(as.data.frame(wf$folds), "wf_folds", "fold_seq"),
      wf_scores = a0_canon(as.data.frame(wf$scores), "wf_scores", c("fold_seq", "window", "candidate_key", "metric_name")),
      wf_status = a0_canon(data.frame(status = wf$status, test_run_ids = paste(ids, collapse = ","), stringsAsFactors = FALSE),
                           "wf_status", "status")), a0_store_tables(db, ids)))
  },
  # Finding 5: a control$checkpoint_every key is refused even when NULL.
  witness_checkpoint_null = function() {
    db <- lw_witness_db()
    exp <- function(snapshot) {
      e <- lw_surface_exp(snapshot)
      e$control <- list(checkpoint_every = NULL)
      e
    }
    collect(db, "lw_witness", "lw-checkpoint-null", exp, seed = 6L)
  },
  # Finding 2, D3-B: the P5 capacity refusal on its original pulse, forced to
  # two fill events: the pin through its handler's init_buffers() seam, the
  # lean loop through lean_entry$capacity. Run at several --batch-rows to
  # show the terminal bound cannot move it.
  witness_capacity = function() {
    k <- 2L
    if (lw_lean_installed()) {
      lean$lean_entry$capacity <- k
    } else {
      restore <- lw_rebind("ledgr_fold_envelope", local({
        inner <- get("ledgr_fold_envelope", envir = ns)
        function(execution, output_handler) {
          init <- output_handler$init_buffers
          output_handler$init_buffers <- function(max_events) init(k)
          inner(execution, output_handler)
        }
      }))
      on.exit(restore())
    }
    loop_constructed$sell_buy_same_pulse()
  },
  # Finding 2, D3 Section 1: before each strategy call a read sees the
  # committed prefix of fill events (the pin's handler; the lean records).
  witness_prefix_reads = function() lw_prefix_reads(memory = FALSE),
  witness_prefix_reads_sweep = function() lw_prefix_reads(memory = TRUE),
  # Cut 15 R3: retained contexts read after later fills and state updates.
  witness_retained_context = function() {
    db <- lw_witness_db()
    collect(db, "lw_witness", "lw-retained", function(s) ledgr::ledgr_experiment(s, lw_retained_strategy(),
      features = lw_feature_map(), opening = ledgr::ledgr_opening(cash = 5000), cost_model = ledgr::ledgr_cost_zero(),
      portfolio_state = list(n = 0L), asset_state = list(flag = FALSE)), seed = 12L)
  },
  # Cut 15 R2: the strategy-error boundary.
  witness_error_cleanup = function() lw_error_boundary("cleanup"),
  witness_error_cleanup_error = function() lw_error_boundary("cleanup_error"),
  witness_error_custom = function() lw_error_boundary("custom"),
  # the same boundary on a seeded run: the run's own stream and the caller's
  # state after the error
  witness_error_cleanup_seeded = function() lw_error_boundary("cleanup_error", seed = 31L),
  # A one-worker sweep over a covered experiment: the keep rule.
  witness_sweep = function() {
    db <- lw_witness_db()
    snapshot <- ledgr::ledgr_snapshot_open(db, "lw_witness", verify = TRUE)
    on.exit(ledgr::ledgr_snapshot_close(snapshot))
    exp <- lw_surface_exp(snapshot)
    grid <- ledgr::ledgr_grid_named(a = list(strategy = list(k = 1)), b = list(strategy = list(k = 2)))
    set.seed(8L)
    obs <- a0_observe_memory(ledgr::ledgr_sweep(exp, grid, seed = 17L, retain = a0_retain()))
    lw_rng_table(list(sweep = c(a0_sweep_tables(obs$value), a0_memory_tables(obs$observed, obs$value))), "sweep")
  }
)

# Workloads whose lean arm must name this refusal before the first pulse;
# a missing refusal fails the workload even when the outputs match.
loop_expect_refused <- list(
  witness_checkpoint_control = "a checkpoint_every control",
  witness_checkpoint_null = "a checkpoint_every control"
)
