# v0.2.3 RNG baseline probe (WS2 + C4 measurement step). Brief:
# inst/design/ledgr_v0_2_3_spec_packet/rng_probe_brief.md. No product change.
#
# Writes the deterministic record of today's stochastic behaviour to
# records/ (one canonical CSV per table plus manifest.csv with SHA-256), using
# the A0 canonical writer (dev/bench/v0_2_3_output_freeze/lib.R).
#
# Usage: Rscript probe.R [--out=<dir>] [--gut=<name>] [--cost]
#   --out   record directory (default: records/ next to this script)
#   --gut   apply one corruption from rp_guts (used by check.R and gut.R)
#   --cost  also write descriptive timing to cost/ (not deterministic, not in
#           the manifest, never compared by check.R)

local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  here <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[[1L]])) else getwd()
  for (i in rev(seq_len(sys.nframe()))) { # when source()d, use the sourced file
    f <- sys.frame(i)$ofile
    if (is.character(f)) { here <- dirname(f); break }
  }
  assign("rp_here", normalizePath(here, winslash = "/"), envir = globalenv())
})
rp_root <- normalizePath(file.path(rp_here, "..", "..", ".."), winslash = "/")
suppressMessages(pkgload::load_all(rp_root, quiet = TRUE))
source(file.path(rp_root, "dev", "bench", "v0_2_3_output_freeze", "lib.R"))
source(file.path(rp_root, "dev", "bench", "v0_2_3_ws1_timing", "matrix.R"))
rp_ns <- asNamespace("ledgr")
rp_fn <- function(name) get(name, envir = rp_ns) # resolved at call time, so guts apply

# ---------------------------------------------------------------------------
# Fixture: 6 instruments x 30 days, deterministic prices (no RNG)
# ---------------------------------------------------------------------------

rp_fx <- function(db_path, strategy) {
  days <- 30L
  ids <- sprintf("S%02d", 1:6)
  ts <- as.POSIXct("2021-01-01", tz = "UTC") + 86400 * (seq_len(days) - 1L)
  bars <- do.call(rbind, lapply(seq_along(ids), function(j) {
    close <- 50 + j + 0.5 * sin(seq_len(days) / (j + 1))
    data.frame(instrument_id = ids[[j]], ts_utc = ts, open = close, high = close + 1, low = close - 1,
      close = close, volume = 1e5, stringsAsFactors = FALSE)
  }))
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path, snapshot_id = "rng_probe")
  exp <- ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 1e5), cost_model = ledgr_cost_zero())
  list(snapshot = snapshot, exp = exp, ids = ids, ts = ts)
}

# The contract's recipe: draw from ctx$pulse_seed through withr::with_seed().
# pin = "none" is the plain form; "mt" and "lecuyer" pin all three kinds.
rp_stoch_strategy <- function(ctx, params) {
  if (is.null(ctx$pulse_seed)) stop("this strategy needs `seed =`")
  targets <- ctx$flat()
  n <- length(ctx$universe)
  idx <- if (identical(params$pin, "mt")) {
    withr::with_seed(ctx$pulse_seed, sample.int(n, params$k), .rng_kind = "Mersenne-Twister",
      .rng_normal_kind = "Inversion", .rng_sample_kind = "Rejection")
  } else if (identical(params$pin, "lecuyer")) {
    withr::with_seed(ctx$pulse_seed, sample.int(n, params$k), .rng_kind = "L'Ecuyer-CMRG",
      .rng_normal_kind = "Inversion", .rng_sample_kind = "Rejection")
  } else {
    withr::with_seed(ctx$pulse_seed, sample.int(n, params$k))
  }
  targets[ctx$universe[idx]] <- params$qty
  targets
}

rp_flat_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  targets[[1L]] <- params$qty
  targets
}

rp_stoch_grid <- function() {
  ledgr_grid_named(
    none = list(strategy = list(pin = "none", k = 2, qty = 10)),
    mt = list(strategy = list(pin = "mt", k = 2, qty = 10)),
    lecuyer = list(strategy = list(pin = "lecuyer", k = 2, qty = 10))
  )
}

rp_kinds <- c("Wichmann-Hill", "Marsaglia-Multicarry", "Super-Duper", "Mersenne-Twister", "Knuth-TAOCP",
  "user-supplied", "Knuth-TAOCP-2002", "L'Ecuyer-CMRG")
rp_seed_state <- function() {
  if (!exists(".Random.seed", envir = globalenv(), inherits = FALSE)) return(NULL)
  get(".Random.seed", envir = globalenv(), inherits = FALSE)
}
rp_kind_label <- function(s) {
  if (is.null(s)) return("absent")
  code <- s[[1L]]
  sprintf("%s/%d/%d", rp_kinds[[code %% 100L + 1L]], (code %/% 100L) %% 100L, code %/% 10000L)
}
rp_digest <- function(s) if (is.null(s)) NA_character_ else digest::digest(s, algo = "sha256")
rp_clear_seed <- function() {
  set.seed(1L, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
  rm(".Random.seed", envir = globalenv())
}

# ---------------------------------------------------------------------------
# Q3c: current pulse_seed values; C4 candidate rules on adjacent seeds
# ---------------------------------------------------------------------------

rp_pulse_seeds <- function() {
  g <- expand.grid(pulse_idx = c(1:10, 100L, 1000L, 7200L),
    execution_seed = c(-1L, 0L, 1L, 2L, 7L, 2591L, .Machine$integer.max), KEEP.OUT.ATTRS = FALSE)
  g$pulse_seed <- mapply(function(s, p) rp_fn("ledgr_derive_pulse_seed")(s, p), g$execution_seed, g$pulse_idx)
  a0_canon(g[c("execution_seed", "pulse_idx", "pulse_seed")], "pulse_seeds", c("execution_seed", "pulse_idx"))
}

# Candidate C4 rules, all vectorised over (s, p) and exact in doubles:
# add (s + p), stride (unit pulse step inside a 1000003-wide block per seed)
# and mixer (murmur3 fmix32 of the seed, xor the pulse, fmix32 again).
rp_u32 <- function(x) x %% 4294967296
rp_xor32 <- function(a, b) { # by 16-bit halves, so every operand fits an R integer
  bitwXor(as.integer(a %/% 65536), as.integer(b %/% 65536)) * 65536 +
    bitwXor(as.integer(a %% 65536), as.integer(b %% 65536))
}
rp_mul32 <- function(a, b) {
  al <- a %% 65536; ah <- a %/% 65536; bl <- b %% 65536; bh <- b %/% 65536
  (al * bl + ((ah * bl + al * bh) %% 65536) * 65536) %% 4294967296
}
rp_fmix32 <- function(h) {
  h <- rp_xor32(h, h %/% 65536); h <- rp_mul32(h, 2246822507)
  h <- rp_xor32(h, h %/% 8192); h <- rp_mul32(h, 3266489909)
  rp_xor32(h, h %/% 65536)
}
rp_rules <- list(
  current = function(s, p) mapply(function(a, b) rp_fn("ledgr_derive_pulse_seed")(a, b), s, p),
  add = function(s, p) as.integer(((s - 1 + p - 1) %% 2147483647) + 1),
  stride = function(s, p) as.integer((((s - 1) * 1000003 + (p - 1)) %% 2147483647) + 1),
  mixer = function(s, p) as.integer(rp_fmix32(rp_xor32(rp_fmix32(rp_u32(s)), rp_u32(p))) %% 2147483647 + 1)
)

rp_rule_overlap <- function() {
  seeds <- 1:20; pulses <- 1:500
  g <- expand.grid(p = pulses, s = seeds)
  rows <- list()
  add <- function(rule, metric, value) rows[[length(rows) + 1L]] <<- data.frame(rule = rule, metric = metric,
    value = as.character(value), stringsAsFactors = FALSE)
  for (rule in names(rp_rules)) {
    m <- matrix(rp_rules[[rule]](g$s, g$p), nrow = length(seeds), byrow = TRUE)
    owners <- tapply(rep(seeds, length(pulses)), as.vector(m), function(x) length(unique(x)))
    add(rule, "values (20 adjacent seeds x 500 pulses)", length(m))
    add(rule, "distinct values", length(unique(as.vector(m))))
    add(rule, "values shared by two or more execution seeds", sum(owners > 1L))
    add(rule, "seed s+1 is seed s shifted by one pulse", all(m[-1L, -length(pulses)] == m[-length(seeds), -1L]))
    add(rule, "all in 1..2147483647", all(m >= 1L & m <= 2147483647))
    add(rule, "sha256 of value matrix", digest::digest(m, algo = "sha256"))
    # Are consecutive pulses' streams related? First runif after
    # set.seed(pulse_seed) for pulses 1..5000 of execution seed 7, lag-1
    # correlation, per pinned kind (|r| > ~0.03 is beyond 2 SE at n = 5000).
    ps <- rp_rules[[rule]](rep(7, 5000L), 1:5000)
    for (kind in c("Mersenne-Twister", "L'Ecuyer-CMRG")) {
      u <- vapply(ps, function(s) {
        set.seed(s, kind = kind, normal.kind = "Inversion", sample.kind = "Rejection")
        stats::runif(1)
      }, numeric(1))
      add(rule, paste("lag-1 correlation of first runif, pulses 1..5000 of seed 7,", kind),
        sprintf("%.17g", stats::cor(u[-1L], u[-5000L])))
    }
  }
  rp_clear_seed()
  a0_canon(do.call(rbind, rows), "rule_overlap", c("rule", "metric"))
}

# ---------------------------------------------------------------------------
# Q2: seeding-path census, by execution (workers = 1; set.seed/RNGkind traced)
# ---------------------------------------------------------------------------

rp_log <- new.env(parent = emptyenv())
.rp_trace_log <- function(fn, seed, kind) {
  heads <- vapply(sys.calls(), function(cl) paste(deparse(cl[[1L]], nlines = 1L), collapse = ""), character(1))
  at <- max(which(heads == fn))
  rp_log$rng[[length(rp_log$rng) + 1L]] <- data.frame(fn = fn,
    seed = if (is.null(seed)) NA_character_ else as.character(seed),
    kind = if (is.null(kind)) "NULL" else as.character(kind),
    caller = if (at > 1L) substr(heads[[at - 1L]], 1L, 60L) else "<top>", stringsAsFactors = FALSE)
}

rp_census_case <- function(path, seed, expr_fn) {
  rp_log$rng <- list(); rp_log$pulse <- list()
  counter <- list(ledgr_derive_pulse_seed = function(orig) function(execution_seed, pulse_idx) {
    v <- orig(execution_seed, pulse_idx)
    rp_log$pulse[[length(rp_log$pulse) + 1L]] <- c(if (is.null(execution_seed)) NA else execution_seed, if (is.null(v)) NA else v)
    v
  })
  suppressMessages({
    trace("set.seed", tracer = quote(.rp_trace_log("set.seed", seed, kind)), where = baseenv(), print = FALSE)
    trace("RNGkind", tracer = quote(.rp_trace_log("RNGkind", NULL, kind)), where = baseenv(), print = FALSE)
  })
  value <- tryCatch(a0_with_patches(counter, suppressWarnings(expr_fn())), error = function(e) e,
    finally = suppressMessages({
      untrace("set.seed", where = baseenv()); untrace("RNGkind", where = baseenv())
    }))
  rng <- do.call(rbind, c(list(data.frame(fn = character(), seed = character(), kind = character(),
    caller = character())), rp_log$rng))
  pulse <- do.call(rbind, c(list(matrix(numeric(), 0L, 2L)), rp_log$pulse))
  ss <- rng[rng$fn == "set.seed", , drop = FALSE]
  u <- function(x) if (length(x)) paste(sort(unique(x), method = "radix"), collapse = ",") else ""
  list(value = value, row = data.frame(path = path, seed_arg = if (is.null(seed)) "NULL" else as.character(seed),
    outcome = if (inherits(value, "error")) sprintf("ERROR %s: %s", class(value)[[1L]], conditionMessage(value)) else "ok",
    set_seed_calls = nrow(ss), set_seed_seeds = u(ss$seed), set_seed_kind_args = u(ss$kind),
    set_seed_callers = u(ss$caller), rngkind_calls = sum(rng$fn == "RNGkind"),
    pulse_seed_calls = nrow(pulse), pulse_seed_nonnull = sum(!is.na(pulse[, 2L])),
    pulse_seed_execution_seeds = u(format(pulse[, 1L][!is.na(pulse[, 1L])], scientific = FALSE, trim = TRUE)),
    stringsAsFactors = FALSE))
}

rp_census <- function(work) {
  fx <- a0_fx_walk_forward(file.path(work, "census.duckdb"))
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  defaults <- c(ledgr_run = "ledgr_run", ledgr_sweep = "ledgr_sweep", ledgr_promote = NA,
    ledgr_walk_forward = "ledgr_walk_forward")
  rows <- list()
  for (seed in list(NULL, fx$seed)) {
    tag <- if (is.null(seed)) "null" else "seed"
    r <- rp_census_case("ledgr_run", seed, function() close(ledgr_run(fx$exp, params = list(qty = 2),
      run_id = paste0("census-run-", tag), seed = seed)))
    rows[[length(rows) + 1L]] <- r$row
    r <- rp_census_case("ledgr_sweep", seed, function() ledgr_sweep(fx$exp, fx$grid, seed = seed))
    rows[[length(rows) + 1L]] <- r$row
    sw <- r$value
    r$row$path <- "ledgr_sweep (stored candidate execution_seed)"
    r$row[, setdiff(names(r$row), c("path", "seed_arg"))] <- ""
    r$row$set_seed_seeds <- paste(ifelse(is.na(sw$execution_seed), "NA", sw$execution_seed), collapse = ",")
    rows[[length(rows) + 1L]] <- r$row
    r <- rp_census_case("ledgr_promote", seed, function() close(ledgr_promote(fx$exp, ledgr_candidate(sw, 1L),
      run_id = paste0("census-promote-", tag))))
    rows[[length(rows) + 1L]] <- r$row
    r <- rp_census_case("ledgr_walk_forward", seed, function() {
      wf <- ledgr_walk_forward(fx$exp, grid = fx$grid, folds = fx$folds,
        selection_rule = ledgr_rule_argmax("sharpe_ratio"), seed = seed)
      lapply(wf$test_runs, close)
    })
    rows[[length(rows) + 1L]] <- r$row
  }
  out <- do.call(rbind, rows)
  out$default_seed <- vapply(out$path, function(p) {
    f <- sub(" .*", "", p)
    if (f == "ledgr_promote") "<candidate$execution_seed>" else paste(deparse(formals(get(f, envir = rp_ns))$seed), collapse = "")
  }, character(1))
  out$case <- sprintf("%02d", seq_len(nrow(out)))
  a0_canon(out, "census", "case")
}

# ---------------------------------------------------------------------------
# Q3a: seeded stochastic strategy through ledgr_run, sweep w1 and sweep w2
# ---------------------------------------------------------------------------

rp_stochastic <- function(work) {
  fx <- rp_fx(file.path(work, "stoch.duckdb"), rp_stoch_strategy)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  grid <- rp_stoch_grid()
  sweep <- function(workers) suppressWarnings(ledgr_sweep(fx$exp, grid, seed = 7L, retain = a0_retain(), workers = workers))
  w1 <- sweep(1L)
  w2 <- tryCatch(sweep(2L), error = function(e) e)
  fills <- list(); trades <- list(); agree <- list()
  sweep_trades <- function(sw, cid) {
    if (inherits(sw, "error")) return(data.frame(close_ts_utc = as.POSIXct(character(), tz = "UTC"), realized_pnl = numeric()))
    t <- as.data.frame(ledgr_sweep_trades(sw))
    t <- t[t$candidate_id == cid, , drop = FALSE]
    t[order(t$trade_seq), c("close_ts_utc", "realized_pnl")]
  }
  sweep_equity <- function(sw, cid) {
    if (inherits(sw, "error")) return(numeric())
    r <- as.data.frame(ledgr_sweep_returns(sw))
    r$equity[r$candidate_id == cid]
  }
  fe <- function(sw, cid) if (inherits(sw, "error")) "<error>" else sprintf("%.17g", sw$final_equity[sw$candidate_id == cid])
  st <- function(sw, cid) if (inherits(sw, "error")) paste("ERROR", conditionMessage(sw)) else sw$status[sw$candidate_id == cid]
  for (i in seq_len(nrow(w1))) {
    cid <- as.character(w1$candidate_id[[i]])
    bt <- suppressWarnings(ledgr_run(fx$exp, params = w1$params[[i]], run_id = paste0("stoch-", cid), seed = w1$execution_seed[[i]]))
    f <- as.data.frame(ledgr_results(bt, "fills"))
    tr <- as.data.frame(ledgr_results(bt, "trades"))
    eq <- as.data.frame(ledgr_results(bt, "equity"))$equity
    close(bt)
    fills[[cid]] <- data.frame(candidate_id = cid, f[c("event_seq", "ts_utc", "instrument_id", "side", "qty", "price")])
    run_tr <- data.frame(close_ts_utc = tr$ts_utc, realized_pnl = tr$realized_pnl)
    t1 <- sweep_trades(w1, cid); t2 <- sweep_trades(w2, cid)
    for (p in list(list("run", run_tr), list("sweep_w1", t1), list("sweep_w2", t2))) {
      x <- p[[2L]]
      trades[[paste(p[[1L]], cid)]] <- data.frame(path = rep(p[[1L]], nrow(x)), candidate_id = rep(cid, nrow(x)),
        seq = seq_len(nrow(x)), close_ts_utc = x$close_ts_utc, realized_pnl = x$realized_pnl)
    }
    same <- function(a, b) identical(a0_fmt_atomic(a), a0_fmt_atomic(b))
    agree[[cid]] <- data.frame(candidate_id = cid, pin = w1$params[[i]]$pin, execution_seed = w1$execution_seed[[i]],
      status_w1 = st(w1, cid), status_w2 = st(w2, cid), n_trades_run = nrow(run_tr), n_trades_w1 = nrow(t1),
      n_trades_w2 = nrow(t2), final_equity_run = sprintf("%.17g", eq[[length(eq)]]), final_equity_w1 = fe(w1, cid),
      final_equity_w2 = fe(w2, cid),
      trades_run_vs_w1 = same(run_tr$realized_pnl, t1$realized_pnl) && same(run_tr$close_ts_utc, t1$close_ts_utc),
      trades_w1_vs_w2 = same(t1$realized_pnl, t2$realized_pnl) && same(t1$close_ts_utc, t2$close_ts_utc),
      equity_run_vs_w1 = same(eq, sweep_equity(w1, cid)), equity_w1_vs_w2 = same(sweep_equity(w1, cid), sweep_equity(w2, cid)),
      stringsAsFactors = FALSE)
  }
  # The kind a fresh mirai daemon runs, as ledgr starts them (daemons(n)).
  mirai::daemons(1L)
  daemon_kind <- tryCatch(paste(mirai::mirai(RNGkind())[], collapse = "/"), finally = mirai::daemons(0L))
  agree <- do.call(rbind, agree)
  agree$daemon_rng_kind <- daemon_kind
  list(
    stochastic_fills = a0_canon(do.call(rbind, fills), "stochastic_fills", c("candidate_id", "event_seq")),
    stochastic_trades = a0_canon(do.call(rbind, trades), "stochastic_trades", c("path", "candidate_id", "seq")),
    worker_agreement = a0_canon(agree, "worker_agreement", "candidate_id")
  )
}

# ---------------------------------------------------------------------------
# Q3b: the caller's .Random.seed and kind around ledgr_run / ledgr_sweep
# ---------------------------------------------------------------------------

rp_caller_rng <- function(work) {
  fx <- rp_fx(file.path(work, "caller.duckdb"), rp_flat_strategy)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  grid <- ledgr_grid_named(a = list(strategy = list(qty = 1)), b = list(strategy = list(qty = 2)))
  set_state <- function(state) {
    rp_clear_seed()
    if (state == "MT_123") set.seed(123L, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
    if (state == "LEcuyer_123") set.seed(123L, kind = "L'Ecuyer-CMRG", normal.kind = "Inversion", sample.kind = "Rejection")
  }
  cases <- rbind(
    expand.grid(seed = c(NA, 7L), path = c("run", "sweep_w1"), state = c("absent", "MT_123", "LEcuyer_123"), stringsAsFactors = FALSE),
    expand.grid(seed = c(NA, 7L), path = "sweep_w2", state = c("absent", "MT_123"), stringsAsFactors = FALSE)
  )
  rows <- list()
  for (k in seq_len(nrow(cases))) {
    seed <- if (is.na(cases$seed[[k]])) NULL else cases$seed[[k]]
    set_state(cases$state[[k]])
    before <- rp_seed_state()
    res <- tryCatch(suppressWarnings(switch(cases$path[[k]],
      run = close(ledgr_run(fx$exp, params = list(qty = 1), run_id = sprintf("caller-%02d", k), seed = seed)),
      sweep_w1 = ledgr_sweep(fx$exp, grid, seed = seed),
      sweep_w2 = ledgr_sweep(fx$exp, grid, seed = seed, workers = 2L))), error = function(e) e)
    after <- rp_seed_state()
    rows[[k]] <- data.frame(case = sprintf("%02d", k), caller_state = cases$state[[k]], path = cases$path[[k]],
      seed = if (is.null(seed)) "NULL" else as.character(seed),
      outcome = if (inherits(res, "error")) paste("ERROR", conditionMessage(res)) else "ok",
      before_kind = rp_kind_label(before), after_kind = rp_kind_label(after),
      caller_rng_unchanged = identical(before, after),
      # A state created from the clock is not reproducible; only a change from a
      # set state is recorded by digest.
      before_sha256 = rp_digest(before), after_sha256 = if (is.null(before)) NA_character_ else rp_digest(after),
      stringsAsFactors = FALSE)
  }
  rp_clear_seed()
  a0_canon(do.call(rbind, rows), "caller_rng", "case")
}

# ---------------------------------------------------------------------------
# Q5 follow-up: duckdb's dbAppendTable() names a temporary view with
# sample(letters, 10), so every persistent flush draws from the global RNG.
# Shown with an ambient-RNG strategy (Tier 2, sequential only).
# ---------------------------------------------------------------------------

rp_ambient_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  targets[ctx$universe[stats::runif(length(ctx$universe)) < 0.5]] <- params$qty
  targets
}

rp_store_rng <- function(work) {
  rows <- list()
  row <- function(case, n_pulses, a_label, a, b_label, b) {
    d <- which(a != b)
    data.frame(case = case, n_pulses = n_pulses, a = a_label, b = b_label, n_a = length(a), n_b = length(b),
      final_equity_a = sprintf("%.17g", a[[length(a)]]), final_equity_b = sprintf("%.17g", b[[length(b)]]),
      equity_identical = identical(a, b), first_differing_pulse = if (length(d)) d[[1L]] else NA_integer_,
      stringsAsFactors = FALSE)
  }
  # (a) Unseeded public API, same caller set.seed(1): only checkpoint_every differs.
  fx <- rp_fx(file.path(work, "store_a.duckdb"), rp_ambient_strategy)
  eq <- function(ck) {
    set.seed(1L, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
    bt <- suppressWarnings(ledgr_backtest(snapshot = fx$snapshot, strategy = rp_ambient_strategy,
      strategy_params = list(qty = 10), cost_model = ledgr_cost_zero(), checkpoint_every = ck, run_id = paste0("store-ck", ck)))
    on.exit(close(bt))
    as.data.frame(ledgr_results(bt, "equity"))$equity
  }
  rows[[1L]] <- row("ledgr_backtest, caller set.seed(1), no seed argument", length(fx$ts), "checkpoint_every = 10000", eq(10000L),
    "checkpoint_every = 5", eq(5L))
  ledgr_snapshot_close(fx$snapshot)
  # (b) Seeded fold past the default checkpoint (10000 pulses): committed run
  # vs memory sweep, same execution seed.
  days <- 10010L
  ts <- as.POSIXct("1990-01-01", tz = "UTC") + 86400 * (seq_len(days) - 1L)
  close <- 100 + 5 * sin(seq_len(days) / 50)
  bars <- data.frame(instrument_id = "L01", ts_utc = ts, open = close, high = close + 1, low = close - 1, close = close, volume = 1e5)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = file.path(work, "store_b.duckdb"), snapshot_id = "rng_probe_long")
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(snapshot, rp_ambient_strategy, opening = ledgr_opening(cash = 1e5), cost_model = ledgr_cost_zero())
  sw <- suppressWarnings(ledgr_sweep(exp, ledgr_grid_named(a = list(strategy = list(qty = 10))), seed = 7L,
    retain = ledgr_sweep_retention(returns = "completed")))
  bt <- suppressWarnings(ledgr_run(exp, params = sw$params[[1L]], run_id = "store-long", seed = sw$execution_seed[[1L]]))
  run_eq <- as.data.frame(ledgr_results(bt, "equity"))$equity
  close(bt)
  rows[[2L]] <- row("seeded fold, 10010 pulses, default checkpoint_every", days, "ledgr_run (persistent)", run_eq,
    "ledgr_sweep workers = 1 (memory)", as.data.frame(ledgr_sweep_returns(sw))$equity)
  rp_clear_seed()
  out <- do.call(rbind, rows)
  out$id <- c("a", "b")
  a0_canon(out, "store_rng", "id")
}

# ---------------------------------------------------------------------------
# Q4: preflight detection gap vs a runtime .Random.seed comparison
# ---------------------------------------------------------------------------

rp_gap_cases <- list(
  runif = function(ctx, params) { x <- runif(1); ctx$flat() },
  sample = function(ctx, params) { x <- sample(3); ctx$flat() },
  sample.int = function(ctx, params) { x <- sample.int(3); ctx$flat() },
  rbinom = function(ctx, params) { x <- rbinom(1, 1, 0.5); ctx$flat() },
  stats_rexp = function(ctx, params) { x <- stats::rexp(1); ctx$flat() },
  jitter = function(ctx, params) { x <- jitter(c(1, 2)); ctx$flat() },
  stats_kmeans = function(ctx, params) { x <- stats::kmeans(cbind(1:6, c(1, 2, 1, 5, 6, 5)), centers = 2); ctx$flat() },
  with_seed_pulse = function(ctx, params) { x <- withr::with_seed(ctx$pulse_seed, sample.int(3)); ctx$flat() },
  set_seed = function(ctx, params) { x <- set.seed(1); ctx$flat() }
)

rp_detection_gap <- function(work) {
  fx <- rp_fx(file.path(work, "gap.duckdb"), rp_flat_strategy)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  ctx <- ledgr_pulse_snapshot(fx$snapshot, universe = fx$ids, ts_utc = fx$ts[[10L]])
  ctx$pulse_seed <- 4242L
  changes <- function(f, absent) {
    if (absent) rp_clear_seed() else set.seed(99L, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
    before <- rp_seed_state()
    try(f(ctx, list()), silent = TRUE)
    !identical(before, rp_seed_state())
  }
  rows <- lapply(names(rp_gap_cases), function(name) {
    f <- rp_gap_cases[[name]]
    pf <- ledgr_strategy_preflight(f)
    data.frame(case = name, call = paste(deparse(body(f)[[2L]][[3L]]), collapse = " "), tier = pf$tier,
      allowed = isTRUE(pf$allowed), ambient_rng_symbols = paste(pf$ambient_rng_symbols, collapse = ","),
      refused_for_workers_gt_1 = rp_fn("ledgr_strategy_preflight_uses_ambient_rng")(pf),
      runtime_seed_changed = changes(f, FALSE), runtime_seed_changed_from_absent = changes(f, TRUE),
      stringsAsFactors = FALSE)
  })
  rp_clear_seed()
  a0_canon(do.call(rbind, rows), "detection_gap", "case")
}

# ---------------------------------------------------------------------------
# Corruptions for gut.R: each changes product behaviour during a rerun and
# names the record table(s) check.R must then report.
# ---------------------------------------------------------------------------

rp_guts <- list(
  pulse_shift = list(expect = c("pulse_seeds", "stochastic_fills", "stochastic_trades", "rule_overlap"),
    what = "ledgr_derive_pulse_seed uses pulse_idx + 1",
    patch = list(ledgr_derive_pulse_seed = function(orig) function(execution_seed, pulse_idx) orig(execution_seed, pulse_idx + 1L))),
  wf_seed = list(expect = "census", what = "walk-forward test windows reuse the train seed rule",
    patch = list(ledgr_walk_forward_execution_seed = function(orig) function(master_seed, fold_seq, window, candidate_key) {
      orig(master_seed, fold_seq, "train", candidate_key)
    })),
  worker_kind = list(expect = "worker_agreement", what = "workers pinned to Mersenne-Twister after daemon start (the WS2 fix shape)",
    patch = list(ledgr_parallel_mirai_start = function(orig) function(workers) {
      orig(workers)
      get("ledgr_parallel_mirai_everywhere_expr", envir = asNamespace("ledgr"))(
        quote(RNGkind("Mersenne-Twister", "Inversion", "Rejection")), workers = workers)
      invisible(TRUE)
    })),
  caller_leak = list(expect = "caller_rng", what = "the committed-run entry draws one number from the caller's RNG",
    patch = list(ledgr_run_experiment = function(orig) function(...) {
      out <- orig(...)
      stats::runif(1)
      out
    })),
  flush_keeps_rng = list(expect = "store_rng", what = "persistent flushes save and restore .Random.seed (one fix shape)",
    patch = list(ledgr_output_handler = function(orig) function(sink, ...) {
      h <- orig(sink, ...)
      flush <- h$flush_pending
      h$flush_pending <- function(...) {
        s <- get0(".Random.seed", envir = globalenv(), inherits = FALSE)
        on.exit(if (!is.null(s)) assign(".Random.seed", s, envir = globalenv()))
        flush(...)
      }
      h
    })),
  preflight_wide = list(expect = "detection_gap", what = "preflight counts sample.int, rbinom and rexp as ambient RNG",
    patch = list(ledgr_strategy_ambient_rng_functions = function(orig) function() c(orig(), "sample.int", "rbinom", "rexp")))
)

# ---------------------------------------------------------------------------
# Record writer
# ---------------------------------------------------------------------------

rp_write_records <- function(tables, out_dir) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  files <- paste0(names(tables), ".csv")
  for (i in seq_along(tables)) a0_write_table(tables[[i]], file.path(out_dir, files[[i]]))
  files <- sort(files, method = "radix")
  manifest <- data.frame(file = files,
    bytes = sprintf("%d", as.integer(file.size(file.path(out_dir, files)))),
    sha256 = vapply(file.path(out_dir, files), function(f) digest::digest(file = f, algo = "sha256"), character(1)),
    stringsAsFactors = FALSE)
  a0_write_table(manifest, file.path(out_dir, "manifest.csv"))
  manifest
}

rp_records <- function(work) {
  c(list(pulse_seeds = rp_pulse_seeds(), rule_overlap = rp_rule_overlap(), census = rp_census(work)),
    rp_stochastic(work),
    list(caller_rng = rp_caller_rng(work), store_rng = rp_store_rng(work), detection_gap = rp_detection_gap(work)))
}

if (sys.nframe() == 0L) {
  out_dir <- a0_arg("out", file.path(rp_here, "records"))
  gut <- a0_arg("gut")
  work <- file.path(tempdir(), "rng_probe_work")
  dir.create(work, showWarnings = FALSE)
  patches <- if (is.null(gut)) list() else {
    if (!gut %in% names(rp_guts)) stop("probe.R: unknown gut ", gut, call. = FALSE)
    rp_guts[[gut]]$patch
  }
  tables <- a0_with_patches(patches, rp_records(work))
  manifest <- rp_write_records(tables, out_dir)
  cat(sprintf("rng probe: %d tables, %s bytes -> %s%s\n", nrow(manifest), sum(as.numeric(manifest$bytes)), out_dir,
    if (is.null(gut)) "" else paste0(" (gut ", gut, ")")))
  if ("--cost" %in% commandArgs(trailingOnly = TRUE)) {
    source(file.path(rp_here, "cost.R"))
    rp_cost(file.path(rp_here, "cost"), work)
  }
}
