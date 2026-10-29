# Pulse-seed rule v2, its version constant and candidate validation (LDG-3159;
# inst/design/ledgr_v0_2_3_spec_packet/ws2_rng_design.md Sections 2, 6 and 7).
# The golden table is a fixed fixture derived independently (exact Python
# integers, Section 2.5); it is never regenerated from the production routine.
# Same-calendar equality only: no assertion compares overlapping bars of
# calendars of different length (Section 2.3, reading (i)).

ps2_golden <- function() {
  utils::read.csv(
    testthat::test_path("fixtures", "pulse-seed-v2-golden.csv"),
    colClasses = c("numeric", "numeric", "integer")
  )
}

# Bound statistics of Section 2.4, over a rule `fn(s, p)` vectorised in `p`.
ps2_S <- c(7L, 2591L, -1L, 2147483647L)
ps2_E <- c(-2147483647L, -1L, 0L, 1L, 2L, 7L, 2591L, 2147483646L, 2147483647L)

ps2_first_draws <- function(values, kind) {
  vapply(values, function(v) {
    set.seed(v, kind = kind, normal.kind = "Inversion", sample.kind = "Rejection")
    stats::runif(1)
  }, numeric(1))
}

ps2_bounds <- function(fn) {
  ledgr_rng_test_local_restore()
  pulses <- 1:5000
  per_seed <- lapply(ps2_S, function(s) fn(s, pulses))
  b1 <- max(vapply(per_seed, function(v) {
    max(vapply(c("Mersenne-Twister", "L'Ecuyer-CMRG"), function(kind) {
      x <- ps2_first_draws(v, kind)
      abs(stats::cor(x[-length(x)], x[-1L]))
    }, numeric(1)))
  }, numeric(1)))
  ks <- function(x) unname(suppressWarnings(stats::ks.test(x, "punif"))$statistic)
  b2 <- max(vapply(per_seed, function(v) ks((v - 1) / 2147483646), numeric(1)))
  b3 <- max(vapply(per_seed, function(v) ks(ps2_first_draws(v, "Mersenne-Twister")), numeric(1)))
  m <- do.call(rbind, lapply(1:20, function(s) fn(s, 1:500)))
  b4_distinct <- length(unique(as.vector(m)))
  owners <- tapply(rep(1:20, times = 500), as.vector(m), function(x) length(unique(x)))
  b4_shared <- sum(owners >= 2L)
  b5 <- 0L
  for (s in 1:19) {
    for (k in 1:5) {
      p <- 1:(500 - k)
      b5 <- b5 + sum(m[s + 1L, p] == m[s, p + k]) + sum(m[s, p] == m[s + 1L, p + k])
    }
  }
  e <- lapply(ps2_E, function(s) fn(s, 1:1000))
  pairs <- utils::combn(length(ps2_E), 2L)
  b6 <- min(apply(pairs, 2L, function(ij) sum(e[[ij[[1L]]]] != e[[ij[[2L]]]])))
  stats <- c(B1 = b1, B2 = b2, B3 = b3, B4_distinct = b4_distinct, B4_shared = b4_shared, B5 = b5, B6 = b6)
  pass <- c(
    B1 = b1 <= 0.045, B2 = b2 <= 0.0276, B3 = b3 <= 0.0276,
    B4 = b4_distinct >= 9999 && b4_shared <= 1, B5 = b5 <= 1, B6 = b6 >= 999
  )
  list(stats = stats, pass = pass)
}

# Records (ts, pulse_seed) at every decision; `rec$log` is cleared per call.
ps2_recorder <- function() {
  rec <- new.env(parent = emptyenv())
  rec$ts <- character()
  rec$seed <- integer()
  rec$tag <- character()
  rec
}

ps2_clear <- function(rec) {
  rec$ts <- character()
  rec$seed <- integer()
  rec$tag <- character()
  invisible(rec)
}

ps2_recording_strategy <- function(rec) {
  force(rec)
  function(ctx, params) {
    rec$ts <- c(rec$ts, ctx$ts_utc)
    rec$seed <- c(rec$seed, if (is.null(ctx$pulse_seed)) NA_integer_ else ctx$pulse_seed)
    rec$tag <- c(rec$tag, if (is.null(params$tag)) "" else params$tag)
    targets <- ctx$flat()
    targets[[1L]] <- params$qty
    targets
  }
}

ps2_seeds_by_ts <- function(rec, tag = NULL) {
  keep <- if (is.null(tag)) rep(TRUE, length(rec$ts)) else rec$tag == tag
  stats::setNames(rec$seed[keep], rec$ts[keep])
}

# ---------------------------------------------------------------------------
# Section 2: the rule
# ---------------------------------------------------------------------------

testthat::test_that("rule v2 reproduces the independent golden table", {
  golden <- ps2_golden()
  testthat::expect_identical(nrow(golden), 63L)
  testthat::expect_setequal(unique(golden$execution_seed), ps2_E)
  testthat::expect_setequal(unique(golden$pulse_idx), c(1, 2, 3, 65535, 65536, 65537, 2147483647))
  for (s in unique(golden$execution_seed)) {
    rows <- golden[golden$execution_seed == s, , drop = FALSE]
    got <- ledgr:::ledgr_pulse_seeds(as.integer(s), rows$pulse_idx)
    testthat::expect_type(got, "integer")
    testthat::expect_identical(got, rows$pulse_seed, info = paste("execution_seed", s))
  }
  # The vector equals its elementwise reads, and a double seed equals the integer.
  vec <- ledgr:::ledgr_pulse_seeds(7L, 1:3)
  one <- vapply(1:3, function(p) ledgr:::ledgr_pulse_seeds(7L, p), integer(1))
  testthat::expect_identical(vec, one)
  testthat::expect_identical(ledgr:::ledgr_pulse_seeds(7, 1:3), vec)
  testthat::expect_identical(vec, c(373418371L, 879019655L, 530954868L))
})

testthat::test_that("rule v2 edge cases: seeds, pulse indices and refusals", {
  limit_seeds <- c(-2147483647L, -1L, 0L, 2147483647L)
  for (s in limit_seeds) {
    v <- ledgr:::ledgr_pulse_seeds(s, c(1, 65535, 65536, 65537, 2147483646, 2147483647))
    testthat::expect_false(anyNA(v), info = s)
    testthat::expect_true(all(v >= 1L & v <= 2147483647L), info = s)
  }
  testthat::expect_null(ledgr:::ledgr_pulse_seeds(NULL, 1:3))
  testthat::expect_identical(ledgr:::ledgr_pulse_seeds(7L, integer()), integer())
  # Seed -2147483648 is NA_integer_ and is refused, as is NA.
  testthat::expect_error(ledgr:::ledgr_pulse_seeds(-2147483648, 1L), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr:::ledgr_pulse_seeds(NA_integer_, 1L), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr:::ledgr_pulse_seeds(1.5, 1L), class = "ledgr_invalid_args")
  # Pulse index 0 is not on the axis; non-integer, missing and out-of-range
  # indices are refused.
  for (bad in list(0L, -1L, 1.5, NA_integer_, 2147483648, c(1, Inf), "1")) {
    testthat::expect_error(ledgr:::ledgr_pulse_seeds(7L, bad), class = "ledgr_invalid_args",
      info = paste(format(bad), collapse = " "))
  }
  # The accessor returns NULL for an unseeded fold and one element otherwise.
  testthat::expect_null(ledgr:::ledgr_pulse_seed_at(list(pulse_seeds = NULL), 3L))
  testthat::expect_identical(ledgr:::ledgr_pulse_seed_at(list(pulse_seeds = vec <- ledgr:::ledgr_pulse_seeds(7L, 1:5)), 3L), vec[[3L]])
})

testthat::test_that("rule v2 meets the frozen bounds B1-B6 and every control fails", {
  v2 <- ledgr_bounds_v2 <- ps2_bounds(function(s, p) ledgr:::ledgr_pulse_seeds(s, p))
  testthat::expect_true(all(v2$pass), info = paste(names(v2$stats), signif(v2$stats, 4), collapse = "; "))
  testthat::expect_identical(unname(v2$stats[c("B4_distinct", "B4_shared", "B5", "B6")]), c(10000, 0, 0, 1000))
  m <- 2147483647
  controls <- list(
    add = function(s, p) as.integer(((s - 1 + p - 1) %% m) + 1),
    stride = function(s, p) as.integer((((s - 1) * 1000003 + (p - 1)) %% m) + 1),
    seed_ignoring = function(s, p) ledgr:::ledgr_pulse_seeds(7L, p)
  )
  expected_failures <- list(
    add = c("B1", "B2", "B4", "B5", "B6"),
    stride = c("B1", "B2", "B6"),
    seed_ignoring = c("B4", "B6")
  )
  for (name in names(controls)) {
    out <- ps2_bounds(controls[[name]])
    failed <- names(out$pass)[!out$pass]
    testthat::expect_true(length(failed) >= 1L, info = name)
    testthat::expect_identical(failed, expected_failures[[name]],
      info = paste(name, paste(names(out$stats), signif(out$stats, 4), collapse = "; ")))
  }
})

# ---------------------------------------------------------------------------
# Section 2.2: no per-pulse canonical JSON or SHA-256 on the pulse-seed path
# ---------------------------------------------------------------------------

testthat::test_that("the pulse-seed path computes one vector per fold with no hashing", {
  ns <- asNamespace("ledgr")
  testthat::expect_false(exists("ledgr_derive_pulse_seed", envir = ns, inherits = FALSE))
  root <- ledgr_test_source_root()
  if (dir.exists(file.path(root, "R"))) {
    src <- unlist(lapply(list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE), readLines, warn = FALSE))
    testthat::expect_false(any(grepl("ledgr_derive_pulse_seed", src, fixed = TRUE)))
  }

  # Everything reachable from the rule owner and its accessor, within the
  # namespace, calls no JSON writer, digest or derived-seed hash.
  reach <- function(start) {
    seen <- character()
    todo <- start
    while (length(todo) > 0L) {
      name <- todo[[1L]]
      todo <- todo[-1L]
      if (name %in% seen) next
      seen <- c(seen, name)
      fn <- get0(name, envir = ns, inherits = FALSE)
      if (!is.function(fn)) next
      called <- unique(all.names(body(fn)))
      todo <- c(todo, setdiff(called[vapply(called, function(n) is.function(get0(n, envir = ns, inherits = FALSE)), logical(1))], seen))
      seen <- c(seen, setdiff(called, ls(ns, all.names = TRUE)))
    }
    unique(seen)
  }
  reached <- reach(c("ledgr_pulse_seeds", "ledgr_pulse_seed_at"))
  forbidden <- c("canonical_json", "ledgr_canonical_json_encode", "ledgr_json_write_canonical_v2",
    "digest", "sha256", "ledgr_derive_seed", "serialize")
  testthat::expect_identical(intersect(reached, forbidden), character())

  # The context reads one element by index; the envelope builds the vector
  # once, outside any loop.
  decide <- paste(deparse(body(ns$ledgr_fold_stage_decide), width.cutoff = 500L), collapse = "\n")
  testthat::expect_match(decide, "pulse_seed = ledgr_pulse_seed_at(services, pulse_idx)", fixed = TRUE)
  loops <- c("for", "while", "repeat", "lapply", "vapply", "sapply", "Map", "mapply")
  hits <- list()
  walk <- function(e, in_loop) {
    if (!is.call(e)) return(invisible(NULL))
    head <- e[[1L]]
    head_name <- if (is.name(head)) as.character(head) else ""
    if (identical(head_name, "ledgr_pulse_seeds")) hits[[length(hits) + 1L]] <<- in_loop
    now_loop <- in_loop || head_name %in% loops
    for (part in as.list(e)[-1L]) if (!missing(part)) walk(part, now_loop)
    invisible(NULL)
  }
  walk(body(ns$ledgr_fold_envelope), FALSE)
  testthat::expect_identical(unlist(hits), FALSE)

  # At run time: one vector per seeded fold, none unseeded, one indexed read
  # per decision pulse, and no derived-seed hash; JSON work does not grow with
  # pulses when a seed is added.
  calls <- new.env(parent = emptyenv())
  calls$vectors <- 0L
  calls$reads <- 0L
  calls$derive <- 0L
  calls$json <- 0L
  orig_seeds <- ns$ledgr_pulse_seeds
  orig_at <- ns$ledgr_pulse_seed_at
  orig_derive <- ns$ledgr_derive_seed
  orig_json <- ns$canonical_json
  testthat::local_mocked_bindings(
    ledgr_pulse_seeds = function(...) { calls$vectors <- calls$vectors + 1L; orig_seeds(...) },
    ledgr_pulse_seed_at = function(...) { calls$reads <- calls$reads + 1L; orig_at(...) },
    ledgr_derive_seed = function(...) { calls$derive <- calls$derive + 1L; orig_derive(...) },
    canonical_json = function(...) { calls$json <- calls$json + 1L; orig_json(...) },
    .package = "ledgr"
  )
  count_run <- function(n, seed, id) {
    fx <- ledgr_rng_test_experiment(ledgr_rng_test_flat_strategy, n = n, snapshot_id = paste0("ps2_cost_", id))
    on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
    for (field in c("vectors", "reads", "derive", "json")) calls[[field]] <- 0L
    bt <- suppressWarnings(ledgr_run(fx$exp, params = list(qty = 1), run_id = paste0("ps2-cost-", id), seed = seed))
    close(bt)
    c(vectors = calls$vectors, reads = calls$reads, derive = calls$derive, json = calls$json)
  }
  s10 <- count_run(10L, 7L, "s10")
  u10 <- count_run(10L, NULL, "u10")
  s30 <- count_run(30L, 7L, "s30")
  u30 <- count_run(30L, NULL, "u30")
  testthat::expect_identical(unname(s10[c("vectors", "reads", "derive")]), c(1L, 10L, 0L))
  testthat::expect_identical(unname(s30[c("vectors", "reads", "derive")]), c(1L, 30L, 0L))
  testthat::expect_identical(unname(u10[c("vectors", "derive")]), c(0L, 0L))
  testthat::expect_identical(unname(u30[c("vectors", "derive")]), c(0L, 0L))
  testthat::expect_identical(s30[["json"]] - u30[["json"]], s10[["json"]] - u10[["json"]])
})

# ---------------------------------------------------------------------------
# Section 2.3: the same pulse seeds as a straight run on the same calendar
# ---------------------------------------------------------------------------

testthat::test_that("a straight run reads the v2 vector over its own calendar", {
  rec <- ps2_recorder()
  fx <- ledgr_rng_test_experiment(ps2_recording_strategy(rec), n = 12L, snapshot_id = "ps2_straight")
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  bt <- suppressWarnings(ledgr_run(fx$exp, params = list(qty = 1), run_id = "ps2-straight", seed = 7L))
  on.exit(close(bt), add = TRUE)
  testthat::expect_length(rec$seed, 12L)
  testthat::expect_identical(rec$seed, ledgr:::ledgr_pulse_seeds(7L, seq_len(12L)))
  ps2_clear(rec)
  unseeded <- suppressWarnings(ledgr_run(fx$exp, params = list(qty = 1), run_id = "ps2-straight-unseeded"))
  on.exit(close(unseeded), add = TRUE)
  testthat::expect_true(all(is.na(rec$seed)))
})

testthat::test_that("resume reads the same pulse seeds as a straight run on the same calendar", {
  rec <- ps2_recorder()
  # Strategy state is checkpointed every pulse, so a resume starts after the
  # last checkpoint rather than at the first pulse.
  strategy <- function(ctx, params) {
    rec$ts <- c(rec$ts, ctx$ts_utc)
    rec$seed <- c(rec$seed, if (is.null(ctx$pulse_seed)) NA_integer_ else ctx$pulse_seed)
    rec$tag <- c(rec$tag, "")
    n <- if (is.null(ctx$state_prev$n)) 0L else ctx$state_prev$n
    targets <- ctx$flat()
    targets[[1L]] <- params$qty
    list(targets = targets, state_update = list(n = n + 1L))
  }
  bars <- ledgr_rng_test_bars("AAA", 8L)
  make_cfg <- function(db_path, snapshot_id) {
    snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path, snapshot_id = snapshot_id)
    cfg <- ledgr_config(
      snapshot = snapshot,
      universe = "AAA",
      strategy = strategy,
      strategy_params = list(qty = 1),
      backtest = ledgr_backtest_config(
        start = snapshot$metadata$start_date,
        end = snapshot$metadata$end_date,
        initial_cash = 1e5
      ),
      db_path = db_path,
      checkpoint_every = 1L,
      seed = 7L,
      cost_model_hash = ledgr:::ledgr_cost_model_hash(ledgr_cost_zero()),
      cost_plan_json = ledgr:::ledgr_cost_plan_json(ledgr_cost_zero())
    )
    list(snapshot = snapshot, cfg = cfg)
  }
  clean <- make_cfg(tempfile(fileext = ".duckdb"), "ps2_resume_clean")
  resume <- make_cfg(tempfile(fileext = ".duckdb"), "ps2_resume_resumed")
  on.exit(ledgr_snapshot_close(clean$snapshot), add = TRUE)
  on.exit(ledgr_snapshot_close(resume$snapshot), add = TRUE)
  testthat::expect_identical(clean$cfg$engine$pulse_seed_rule, 2L)

  suppressWarnings(ledgr:::ledgr_run_config(clean$cfg, run_id = "ps2-resume-clean"))
  straight <- ps2_seeds_by_ts(rec)
  ps2_clear(rec)
  ledgr:::ledgr_run_fold(resume$cfg, run_id = "ps2-resume", control = list(max_pulses = 3L))
  first_part <- ps2_seeds_by_ts(rec)
  ps2_clear(rec)
  suppressWarnings(ledgr:::ledgr_run_config(resume$cfg, run_id = "ps2-resume"))
  second_part <- ps2_seeds_by_ts(rec)

  testthat::expect_length(straight, 8L)
  testthat::expect_identical(straight, stats::setNames(ledgr:::ledgr_pulse_seeds(7L, 1:8), names(straight)))
  testthat::expect_length(first_part, 3L)
  # The resume starts at calendar index 4 and keeps the run's indices: the
  # vector is read from `start_idx`, it never restarts at 1.
  testthat::expect_identical(names(second_part), names(straight)[4:8])
  testthat::expect_identical(first_part, straight[names(first_part)])
  testthat::expect_identical(second_part, straight[names(second_part)])
  testthat::expect_identical(unname(second_part), ledgr:::ledgr_pulse_seeds(7L, 4:8))
  testthat::expect_false(identical(unname(second_part), ledgr:::ledgr_pulse_seeds(7L, 1:5)))
})

testthat::test_that("a run window reads the same pulse seeds as a straight run on the same calendar", {
  rec <- ps2_recorder()
  strategy <- ps2_recording_strategy(rec)
  bars <- ledgr_rng_test_bars("AAA", 12L)
  window_start <- as.POSIXct("2021-01-05", tz = "UTC")
  window_end <- as.POSIXct("2021-01-10", tz = "UTC")
  slice <- bars[bars$ts_utc >= window_start & bars$ts_utc <= window_end, , drop = FALSE]
  snapshot_full <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"), snapshot_id = "ps2_window_full")
  snapshot_slice <- ledgr_snapshot_from_df(slice, db_path = tempfile(fileext = ".duckdb"), snapshot_id = "ps2_window_slice")
  on.exit(ledgr_snapshot_close(snapshot_full), add = TRUE)
  on.exit(ledgr_snapshot_close(snapshot_slice), add = TRUE)
  exp_full <- ledgr_experiment(snapshot_full, strategy, opening = ledgr_opening(cash = 1e5), cost_model = ledgr_cost_zero())
  exp_slice <- ledgr_experiment(snapshot_slice, strategy, opening = ledgr_opening(cash = 1e5), cost_model = ledgr_cost_zero())
  window <- ledgr:::ledgr_experiment_window(exp_full, "2021-01-05", "2021-01-10")

  run_window <- suppressWarnings(ledgr:::ledgr_run_window(exp_full, params = list(qty = 1), window = window,
    run_id = "ps2-window", seed = 11L))
  on.exit(close(run_window), add = TRUE)
  windowed <- ps2_seeds_by_ts(rec)
  ps2_clear(rec)
  run_direct <- suppressWarnings(ledgr_run(exp_slice, params = list(qty = 1), run_id = "ps2-window-direct", seed = 11L))
  on.exit(close(run_direct), add = TRUE)
  direct <- ps2_seeds_by_ts(rec)

  testthat::expect_length(direct, nrow(slice))
  testthat::expect_identical(windowed, direct)
  testthat::expect_identical(unname(windowed), ledgr:::ledgr_pulse_seeds(11L, seq_len(nrow(slice))))
})

testthat::test_that("scheduled skips keep their index on the run's calendar", {
  rec <- ps2_recorder()
  record <- function(ctx, params) {
    rec$ts <- c(rec$ts, ctx$ts_utc)
    rec$seed <- c(rec$seed, if (is.null(ctx$pulse_seed)) NA_integer_ else ctx$pulse_seed)
    rec$tag <- c(rec$tag, "")
    ctx$hold()
  }
  fixture <- ws42_history_fixture(strategy = record, features = list())
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  straight_run <- suppressWarnings(ledgr_run(fixture$exp, run_id = "ps2-schedule-straight", seed = 5L))
  on.exit(close(straight_run), add = TRUE)
  straight <- ps2_seeds_by_ts(rec)
  ps2_clear(rec)

  due_idx <- c(3L, 6L)
  scheduled_exp <- fixture$exp
  scheduled_exp$strategy <- ledgr_strategy_schedule(record, ledgr_schedule_dates(fixture$days[due_idx]))
  scheduled_run <- suppressWarnings(ledgr_run(scheduled_exp, run_id = "ps2-schedule-due", seed = 5L))
  on.exit(close(scheduled_run), add = TRUE)
  scheduled <- ps2_seeds_by_ts(rec)

  testthat::expect_identical(names(straight), ws42_iso(fixture$axis))
  testthat::expect_identical(unname(straight), ledgr:::ledgr_pulse_seeds(5L, seq_along(fixture$axis)))
  testthat::expect_identical(names(scheduled), ws42_iso(fixture$axis[due_idx]))
  testthat::expect_identical(scheduled, straight[names(scheduled)])
  testthat::expect_identical(unname(scheduled), ledgr:::ledgr_pulse_seeds(5L, due_idx))
})

testthat::test_that("sweep (one and two workers) and promotion read a straight run's pulse seeds", {
  rec <- ps2_recorder()
  fx <- ledgr_rng_test_experiment(ps2_recording_strategy(rec), n = 15L, snapshot_id = "ps2_sweep")
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  grid <- ledgr_grid_named(a = list(strategy = list(tag = "a", qty = 1)), b = list(strategy = list(tag = "b", qty = 2)))
  sw <- suppressWarnings(ledgr_sweep(fx$exp, grid, seed = 7L))
  testthat::expect_identical(attr(sw, "seed_contract"), "ledgr_seed_v2")
  in_sweep <- list(a = ps2_seeds_by_ts(rec, "a"), b = ps2_seeds_by_ts(rec, "b"))
  for (label in c("a", "b")) {
    candidate <- ledgr_candidate(sw, label)
    testthat::expect_identical(candidate$provenance$seed_contract, "ledgr_seed_v2")
    ps2_clear(rec)
    straight <- suppressWarnings(ledgr_run(fx$exp, params = candidate$params, run_id = paste0("ps2-sweep-straight-", label),
      seed = candidate$execution_seed))
    close(straight)
    straight_seeds <- ps2_seeds_by_ts(rec)
    ps2_clear(rec)
    promoted <- suppressWarnings(ledgr_promote(fx$exp, candidate, run_id = paste0("ps2-sweep-promoted-", label)))
    close(promoted)
    promoted_seeds <- ps2_seeds_by_ts(rec)
    testthat::expect_length(straight_seeds, 15L)
    testthat::expect_identical(in_sweep[[label]], straight_seeds, info = label)
    testthat::expect_identical(promoted_seeds, straight_seeds, info = label)
    testthat::expect_identical(unname(straight_seeds), ledgr:::ledgr_pulse_seeds(candidate$execution_seed, 1:15), info = label)
  }

  # Two workers cannot write back to a recorder, so the witness is economic:
  # targets follow the pulse seed, and one worker, two workers and a straight
  # run agree.
  testthat::skip_if_not_installed("mirai")
  seed_targets <- function(ctx, params) {
    targets <- ctx$flat()
    if (!is.null(ctx$pulse_seed)) targets[[1L]] <- (ctx$pulse_seed %% 5L) + params$qty
    targets
  }
  econ <- ledgr_rng_test_experiment(seed_targets, n = 15L, snapshot_id = "ps2_sweep_econ")
  on.exit(ledgr_snapshot_close(econ$snapshot), add = TRUE)
  grid2 <- ledgr_grid_named(a = list(strategy = list(qty = 1)), b = list(strategy = list(qty = 3)))
  retain <- ledgr_sweep_retention(returns = "completed", trades = "closed")
  w1 <- suppressWarnings(ledgr_sweep(econ$exp, grid2, seed = 7L, retain = retain, workers = 1L))
  w2 <- suppressWarnings(ledgr_sweep(econ$exp, grid2, seed = 7L, retain = retain, workers = 2L))
  testthat::expect_identical(w2$execution_seed, w1$execution_seed)
  testthat::expect_identical(w2$final_equity, w1$final_equity)
  testthat::expect_identical(w2$n_trades, w1$n_trades)
  testthat::expect_true(all(w1$n_trades >= 1L))
  for (label in c("a", "b")) {
    candidate <- ledgr_candidate(w1, label)
    straight <- suppressWarnings(ledgr_run(econ$exp, params = candidate$params, run_id = paste0("ps2-econ-", label),
      seed = candidate$execution_seed))
    equity <- ledgr_results(straight, "equity")
    testthat::expect_equal(w1$final_equity[w1$candidate_id == label], equity$equity[[nrow(equity)]], tolerance = 1e-10)
    close(straight)
  }
})

# Optional review item: actual draws through the recipe agree between a
# continuous run and a resumed run, and between a windowed run and a straight
# run on the window's own calendar.
testthat::test_that("actual draws agree for continuous, resumed and windowed runs on the same calendar", {
  testthat::skip_if_not_installed("withr")
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  drawing <- function(ctx, params) {
    calls$n <- calls$n + 1L
    targets <- ctx$flat()
    if (is.null(ctx$pulse_seed)) stop("this strategy needs `seed =`")
    targets[[1L]] <- withr::with_seed(ctx$pulse_seed, sample.int(10L, 1L))
    n <- if (is.null(ctx$state_prev$n)) 0L else ctx$state_prev$n
    list(targets = targets, state_update = list(n = n + 1L))
  }
  bars <- ledgr_rng_test_bars("AAA", 12L)
  make_cfg <- function(snapshot_id) {
    db_path <- tempfile(fileext = ".duckdb")
    snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path, snapshot_id = snapshot_id)
    cfg <- ledgr_config(
      snapshot = snapshot, universe = "AAA", strategy = drawing, strategy_params = list(),
      backtest = ledgr_backtest_config(start = snapshot$metadata$start_date, end = snapshot$metadata$end_date,
        initial_cash = 1e5),
      db_path = db_path, checkpoint_every = 1L, seed = 13L,
      cost_model_hash = ledgr:::ledgr_cost_model_hash(ledgr_cost_zero()),
      cost_plan_json = ledgr:::ledgr_cost_plan_json(ledgr_cost_zero())
    )
    list(snapshot = snapshot, cfg = cfg, db_path = db_path)
  }
  clean <- make_cfg("ps2_draw_clean")
  resume <- make_cfg("ps2_draw_resume")
  on.exit(ledgr_snapshot_close(clean$snapshot), add = TRUE)
  on.exit(ledgr_snapshot_close(resume$snapshot), add = TRUE)
  suppressWarnings(ledgr:::ledgr_run_config(clean$cfg, run_id = "ps2-draw"))
  ledgr:::ledgr_run_fold(resume$cfg, run_id = "ps2-draw", control = list(max_pulses = 5L))
  calls$n <- 0L
  suppressWarnings(ledgr:::ledgr_run_config(resume$cfg, run_id = "ps2-draw"))
  # The resume executed only pulses 6 to 12 of the same calendar.
  testthat::expect_identical(calls$n, 7L)
  clean_bt <- ledgr:::new_ledgr_backtest("ps2-draw", clean$db_path, clean$cfg)
  resumed_bt <- ledgr:::new_ledgr_backtest("ps2-draw", resume$db_path, resume$cfg)
  on.exit(close(clean_bt), add = TRUE)
  on.exit(close(resumed_bt), add = TRUE)
  clean_fills <- ledgr_rng_test_fills(clean_bt)
  testthat::expect_true(length(unique(clean_fills$qty)) >= 2L)
  testthat::expect_equal(ledgr_rng_test_fills(resumed_bt), clean_fills)

  window_start <- as.POSIXct("2021-01-04", tz = "UTC")
  window_end <- as.POSIXct("2021-01-10", tz = "UTC")
  slice <- bars[bars$ts_utc >= window_start & bars$ts_utc <= window_end, , drop = FALSE]
  snapshot_full <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"), snapshot_id = "ps2_draw_full")
  snapshot_slice <- ledgr_snapshot_from_df(slice, db_path = tempfile(fileext = ".duckdb"), snapshot_id = "ps2_draw_slice")
  on.exit(ledgr_snapshot_close(snapshot_full), add = TRUE)
  on.exit(ledgr_snapshot_close(snapshot_slice), add = TRUE)
  exp_full <- ledgr_experiment(snapshot_full, drawing, opening = ledgr_opening(cash = 1e5), cost_model = ledgr_cost_zero())
  exp_slice <- ledgr_experiment(snapshot_slice, drawing, opening = ledgr_opening(cash = 1e5), cost_model = ledgr_cost_zero())
  window <- ledgr:::ledgr_experiment_window(exp_full, "2021-01-04", "2021-01-10")
  windowed <- suppressWarnings(ledgr:::ledgr_run_window(exp_full, window = window, run_id = "ps2-draw-window", seed = 13L))
  direct <- suppressWarnings(ledgr_run(exp_slice, run_id = "ps2-draw-direct", seed = 13L))
  on.exit(close(windowed), add = TRUE)
  on.exit(close(direct), add = TRUE)
  window_fills <- ledgr_rng_test_fills(windowed)
  testthat::expect_true(length(unique(window_fills$qty)) >= 2L)
  testthat::expect_equal(window_fills, ledgr_rng_test_fills(direct))
})

# ---------------------------------------------------------------------------
# Section 6: the constant, its records and validation
# ---------------------------------------------------------------------------

testthat::test_that("one constant names the rule in bindings, markers and seeded configs", {
  testthat::expect_identical(ledgr:::ledgr_pulse_seed_rule_version, 2L)
  testthat::expect_identical(ledgr:::ledgr_seed_contract_current(), "ledgr_seed_v2")
  testthat::expect_identical(ledgr:::ledgr_store_format_bindings()[["ledgr_pulse_seed_rule_version"]], 2L)

  fx <- ledgr_rng_test_experiment(ledgr_rng_test_flat_strategy, n = 6L, snapshot_id = "ps2_config")
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  seeded <- suppressWarnings(ledgr_run(fx$exp, params = list(qty = 1), run_id = "ps2-config-seeded", seed = 7L))
  unseeded <- suppressWarnings(ledgr_run(fx$exp, params = list(qty = 1), run_id = "ps2-config-unseeded"))
  on.exit(close(seeded), add = TRUE)
  on.exit(close(unseeded), add = TRUE)
  testthat::expect_identical(seeded$config$engine$pulse_seed_rule, 2L)
  testthat::expect_false("pulse_seed_rule" %in% names(unseeded$config$engine))
  info <- ledgr_run_info(fx$snapshot, "ps2-config-seeded")
  stored <- ledgr:::ledgr_json_read_config(info$config_json)
  testthat::expect_identical(as.integer(stored$engine$pulse_seed_rule), 2L)
  testthat::expect_identical(info$config_hash, ledgr:::config_hash(stored))
  unseeded_info <- ledgr_run_info(fx$snapshot, "ps2-config-unseeded")
  testthat::expect_false(grepl("pulse_seed_rule", unseeded_info$config_json, fixed = TRUE))

  # Validation refuses a seeded configuration with an old or missing rule.
  cfg <- seeded$config
  testthat::expect_error(ledgr:::validate_ledgr_config(cfg), NA)
  old <- cfg
  old$engine$pulse_seed_rule <- 1L
  err <- testthat::expect_error(ledgr:::validate_ledgr_config(old), class = "ledgr_seed_rule_mismatch")
  testthat::expect_s3_class(err, "ledgr_invalid_config")
  missing_rule <- cfg
  missing_rule$engine$pulse_seed_rule <- NULL
  testthat::expect_error(ledgr:::validate_ledgr_config(missing_rule), class = "ledgr_seed_rule_mismatch")
  testthat::expect_error(ledgr:::validate_ledgr_config(unseeded$config), NA)
})

ps2_expect_refused <- function(exp, candidate, run_id) {
  holds <- 0L
  runs <- 0L
  orig_hold <- ledgr:::ledgr_snapshot_hold
  orig_run <- ledgr:::ledgr_run
  testthat::local_mocked_bindings(
    ledgr_snapshot_hold = function(...) { holds <<- holds + 1L; orig_hold(...) },
    ledgr_run = function(...) { runs <<- runs + 1L; orig_run(...) },
    .package = "ledgr"
  )
  before <- ledgr_run_list(exp$snapshot)$run_id
  err <- testthat::expect_error(ledgr_promote(exp, candidate, run_id = run_id), class = "ledgr_seed_rule_mismatch")
  testthat::expect_s3_class(err, "ledgr_invalid_args")
  testthat::expect_identical(holds, 0L, info = run_id)
  testthat::expect_identical(runs, 0L, info = run_id)
  testthat::expect_identical(ledgr_run_list(exp$snapshot)$run_id, before, info = run_id)
  invisible(err)
}

testthat::test_that("sweep candidates: current markers promote, old and missing are refused", {
  fx <- ledgr_rng_test_experiment(ledgr_rng_test_flat_strategy, n = 8L, snapshot_id = "ps2_sweep_candidates")
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  grid <- ledgr_grid_named(a = list(strategy = list(qty = 1)))
  for (seed in list(7L, NULL)) {
    label <- if (is.null(seed)) "unseeded" else "seeded"
    sw <- suppressWarnings(ledgr_sweep(fx$exp, grid, seed = seed))
    candidate <- ledgr_candidate(sw, "a")
    testthat::expect_identical(candidate$provenance$seed_contract, "ledgr_seed_v2")
    testthat::expect_null(candidate$provenance$pulse_seed_contract)
    key <- ledgr_candidate_reproduction_key(candidate)
    testthat::expect_identical(key$seed$seed_contract, "ledgr_seed_v2")
    testthat::expect_false("pulse_seed_contract" %in% names(key$seed))

    old <- candidate
    old$provenance$seed_contract <- "ledgr_seed_v1"
    ps2_expect_refused(fx$exp, old, paste0("ps2-sweep-old-", label))
    missing_marker <- candidate
    missing_marker$provenance$seed_contract <- NULL
    ps2_expect_refused(fx$exp, missing_marker, paste0("ps2-sweep-missing-", label))

    promoted <- suppressWarnings(ledgr_promote(fx$exp, candidate, run_id = paste0("ps2-sweep-current-", label)))
    expected_seed <- if (is.null(seed)) NULL else candidate$execution_seed
    testthat::expect_identical(promoted$config$engine$seed, expected_seed)
    testthat::expect_identical(promoted$config$engine$pulse_seed_rule, if (is.null(seed)) NULL else 2L)
    context <- ledgr_promotion_context(promoted)
    testthat::expect_identical(context$source_sweep$seed_contract, "ledgr_seed_v2")
    testthat::expect_null(context$source_sweep$pulse_seed_contract)
    close(promoted)
  }

  # A saved and reopened sweep keeps the current marker and promotes.
  sw <- suppressWarnings(ledgr_sweep(fx$exp, grid, seed = 7L))
  ledgr_sweep_save(sw, fx$snapshot, sweep_id = "ps2-saved")
  reopened <- ledgr_sweep_open(fx$snapshot, "ps2-saved")
  testthat::expect_identical(attr(reopened, "seed_contract"), "ledgr_seed_v2")
  reopened_candidate <- ledgr_candidate(reopened, "a")
  testthat::expect_identical(reopened_candidate$provenance$seed_contract, "ledgr_seed_v2")
  promoted <- suppressWarnings(ledgr_promote(fx$exp, reopened_candidate, run_id = "ps2-sweep-reopened"))
  close(promoted)
})

testthat::test_that("walk-forward candidates copy the results marker; old and missing are refused", {
  for (seed in list(7L, NULL)) {
    label <- if (is.null(seed)) "unseeded" else "seeded"
    wf_fx <- ledgr_rng_test_walk_forward(db_path = tempfile(fileext = ".duckdb"))
    wf <- suppressWarnings(ledgr_walk_forward(wf_fx$exp, wf_fx$grid, wf_fx$folds, ledgr_rule_argmax("sharpe_ratio"),
      seed = seed))
    lapply(wf$test_runs, close)
    testthat::expect_identical(attr(wf, "pulse_seed_contract"), "ledgr_seed_v2")

    current <- ledgr_candidate(wf, fold_seq = 1L)
    testthat::expect_identical(current$provenance$seed_contract, "ledgr_walk_forward_seed_v1")
    testthat::expect_identical(current$provenance$pulse_seed_contract, "ledgr_seed_v2")
    testthat::expect_identical(current$sweep_meta$pulse_seed_contract, "ledgr_seed_v2")
    testthat::expect_identical(is.na(current$execution_seed), is.null(seed), info = label)
    key <- ledgr_candidate_reproduction_key(current)
    testthat::expect_identical(key$seed$seed_contract, "ledgr_walk_forward_seed_v1")
    testthat::expect_identical(key$seed$pulse_seed_contract, "ledgr_seed_v2")

    # The fixture of Section 6: corrupt the results attribute, then extract.
    old_wf <- wf
    attr(old_wf, "pulse_seed_contract") <- "ledgr_seed_v1"
    old <- ledgr_candidate(old_wf, fold_seq = 1L)
    testthat::expect_identical(old$provenance$pulse_seed_contract, "ledgr_seed_v1")
    testthat::expect_identical(old$sweep_meta$pulse_seed_contract, "ledgr_seed_v1")
    ps2_expect_refused(wf_fx$exp, old, paste0("ps2-wf-old-", label))

    missing_wf <- wf
    attr(missing_wf, "pulse_seed_contract") <- NULL
    missing_marker <- ledgr_candidate(missing_wf, fold_seq = 1L)
    testthat::expect_false("pulse_seed_contract" %in% names(missing_marker$provenance))
    testthat::expect_null(missing_marker$sweep_meta$pulse_seed_contract)
    ps2_expect_refused(wf_fx$exp, missing_marker, paste0("ps2-wf-missing-", label))

    # A changed derivation marker is refused too.
    derivation <- current
    derivation$provenance$seed_contract <- "ledgr_seed_v2"
    ps2_expect_refused(wf_fx$exp, derivation, paste0("ps2-wf-derivation-", label))

    promoted <- suppressWarnings(ledgr_promote(wf_fx$exp, current, run_id = paste0("ps2-wf-current-", label)))
    context <- ledgr_promotion_context(promoted)
    testthat::expect_identical(context$source_sweep$seed_contract, "ledgr_walk_forward_seed_v1")
    testthat::expect_identical(context$source_sweep$pulse_seed_contract, "ledgr_seed_v2")
    close(promoted)

    # Reopening stamps the marker from the constant after the store gate.
    reopened <- ledgr_walk_forward_open(wf_fx$snapshot, wf$session_id)
    testthat::expect_identical(attr(reopened, "pulse_seed_contract"), "ledgr_seed_v2")
    testthat::expect_identical(ledgr_candidate(reopened, fold_seq = 1L)$provenance$pulse_seed_contract, "ledgr_seed_v2")
    ledgr_snapshot_close(wf_fx$snapshot)
  }
})

testthat::test_that("a store written under the old rule is refused when opened", {
  db_path <- tempfile(fileext = ".duckdb")
  fx <- ledgr_rng_test_experiment(ledgr_rng_test_flat_strategy, n = 6L, db_path = db_path, snapshot_id = "ps2_old_store")
  bt <- suppressWarnings(ledgr_run(fx$exp, params = list(qty = 1), run_id = "ps2-old-store", seed = 7L))
  close(bt)
  ledgr_snapshot_close(fx$snapshot)

  prior <- ledgr:::ledgr_store_format_bindings()
  prior[["ledgr_pulse_seed_rule_version"]] <- NULL
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
  DBI::dbExecute(con, "UPDATE ledgr_schema_metadata SET value = ? WHERE key = 'format_fingerprint'",
    params = list(as.character(ledgr:::ledgr_store_format_json(prior))))
  DBI::dbDisconnect(con, shutdown = TRUE)

  err <- testthat::expect_error(ledgr_snapshot_open(db_path), class = "ledgr_store_rebuild_required")
  testthat::expect_identical(err$cause, "fingerprint_mismatch")
  testthat::expect_identical(err$differing_constants, "ledgr_pulse_seed_rule_version")
})

# ---------------------------------------------------------------------------
# Section 7: identity
# ---------------------------------------------------------------------------

testthat::test_that("identical canonical input keeps its snapshot hash", {
  bars <- ledgr_rng_test_bars("AAA", 10L)
  a <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"), snapshot_id = "ps2_hash_a")
  b <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"), snapshot_id = "ps2_hash_b")
  on.exit(ledgr_snapshot_close(a), add = TRUE)
  on.exit(ledgr_snapshot_close(b), add = TRUE)
  hash_a <- ledgr_snapshot_info(a)$snapshot_hash[[1L]]
  testthat::expect_identical(hash_a, ledgr_snapshot_info(b)$snapshot_hash[[1L]])
  # The same canonical input hashed to this value on the base tree 7353594b,
  # before the rule change; the content hash rule is unchanged.
  testthat::expect_identical(hash_a, "b54a78e3c666400c17a9670addcd2b51212ad1adef8519e6e72a045361d515d4")
  testthat::expect_identical(ledgr:::ledgr_snapshot_content_hash_rule_version, 4L)
})

testthat::test_that("seeded configuration identity changes by the rule field only; unseeded is unchanged", {
  # Values measured on the base tree 7353594b with the same fixture and
  # strategy text (ldg3159 identity probe). The unseeded configuration and
  # its generated run id are unchanged; the seeded configuration gains
  # engine.pulse_seed_rule = 2, so its hash and generated run id change.
  base_unseeded_hash <- "5946f113bd75b1c1ad748a408e7310aa3142bd56c7cbdb2cd79d5c71dcd8d2b5"
  base_seeded_hash <- "a64da03069f964fd525f43bfb3cd95719563d093e16cf9d61b42905d5894574c"
  strategy <- function(ctx, params) { targets <- ctx$flat(); targets[[1L]] <- params$qty; targets }
  snapshot <- ledgr_snapshot_from_df(ledgr_rng_test_bars("AAA", 12L), db_path = tempfile(fileext = ".duckdb"),
    snapshot_id = "id_cfg")
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 1e5), cost_model = ledgr_cost_zero())
  seeded <- suppressWarnings(ledgr_run(exp, params = list(qty = 1), seed = 7L))
  unseeded <- suppressWarnings(ledgr_run(exp, params = list(qty = 1)))
  on.exit(close(seeded), add = TRUE)
  on.exit(close(unseeded), add = TRUE)
  unseeded_hash <- ledgr_run_info(snapshot, unseeded$run_id)$config_hash
  seeded_hash <- ledgr_run_info(snapshot, seeded$run_id)$config_hash
  testthat::expect_identical(unseeded_hash, base_unseeded_hash)
  testthat::expect_identical(unseeded$run_id, "run_ddacac4bf6b7b5b3")
  testthat::expect_false(identical(seeded_hash, base_seeded_hash))
  testthat::expect_identical(seeded_hash, "91229b23572f76045711dc380427cd875a15a2704a25829a3e9333a04a317f72")
  testthat::expect_identical(seeded$run_id, "run_e9c5c0be332eabfa")
  # Removing the one field restores the base seeded hash.
  base_form <- seeded$config
  base_form$engine$pulse_seed_rule <- NULL
  testthat::expect_identical(ledgr:::config_hash(base_form), base_seeded_hash)
})
