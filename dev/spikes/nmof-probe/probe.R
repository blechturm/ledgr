# NMOF as the estimator inside a ledgr strategy -- spike probe.
#
# Question: can NMOF serve as the estimator inside a ledgr v0.2.2 strategy,
# cleanly and reproducibly? Prerequisite: does NMOF::minvar() give the same
# long-only minimum-variance weights as the quadprog::solve.QP() block in
# vignettes/minimum-variance.qmd? Kill: disagreement > 1e-6 that we cannot
# explain.
#
# Usage (from any directory):
#   Rscript dev/spikes/nmof-probe/probe.R           # record evidence CSVs
#   Rscript dev/spikes/nmof-probe/probe.R --check   # rerun to tempdir, diff
#   Rscript dev/spikes/nmof-probe/probe.R --gut     # gut: drop with_seed
#
# NMOF lives in a dedicated library, prepended below. Sweep workers inherit
# the parent's .libPaths() through ledgr's worker load expression.

args <- commandArgs(trailingOnly = TRUE)
mode <- if ("--check" %in% args) "check" else if ("--gut" %in% args) "gut" else "record"
root <- "C:/Users/maxth/ledgr-wt/nmof-probe"
recorded_dir <- file.path(root, "dev", "spikes", "nmof-probe", "evidence")
out_dir <- if (mode == "record") recorded_dir else file.path(tempdir(), "nmof-probe-rerun")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

.libPaths(c("E:/ledgr-data/r-lib/extra", .libPaths()))
for (p in c("NMOF", "quadprog", "withr", "mirai", "pkgload")) {
  if (!requireNamespace(p, quietly = TRUE)) stop("missing package: ", p)
}
pkgload::load_all(root, quiet = TRUE)
cat("NMOF", format(packageVersion("NMOF")), "| quadprog", format(packageVersion("quadprog")),
    "| withr", format(packageVersion("withr")), "| mirai", format(packageVersion("mirai")), "\n")

write_evidence <- function(x, name) {
  utils::write.csv(x, file.path(out_dir, name), row.names = FALSE)
}
section <- function(title) cat("\n==== ", title, " ====\n", sep = "")

# ---------------------------------------------------------------------------
# Fixture: the vignette's simulated PIT inputs, widened to 20 instruments and
# five years. A schedule needs declared sessions, so bare ledgr_sim_bars()
# output cannot carry the vignette's monthly schedule (probed: classed error
# ledgr_schedule_sessions_required).
# ---------------------------------------------------------------------------
ids <- sprintf("DEMO_%02d", 1:20)
pit <- ledgr_sim_pit_inputs(ids, from = "2017-01-01", to = "2021-12-31", seed = 7L)
facts <- ledgr_facts(
  ledgr_facts_sessions(pit$sessions, venue_id = "DEMO_VENUE",
                       knowledge = "evidenced", timezone = "UTC"),
  ledgr_facts_membership_snapshots(pit$membership, universe_id = "DEMO_UNIVERSE",
                                   complete = TRUE, knowledge = "evidenced"),
  ledgr_facts_trading_status(pit$trading_status, knowledge = "evidenced"),
  ledgr_facts_lifetime(pit$lifetime, knowledge = "evidenced"),
  ledgr_facts_equity_corporate_actions(pit$corporate_actions)
)
db <- file.path(tempdir(), "nmof-probe.duckdb")
if (file.exists(db)) unlink(db)
built <- ledgr_snapshot_from_df(pit$bars, instruments_df = pit$instruments, facts = facts,
                                db_path = db, snapshot_id = "nmof_probe",
                                price_basis = "split_adjusted")
ledgr_snapshot_close(built)
snapshot <- ledgr_snapshot_open(db)

make_exp <- function(strategy) {
  ledgr_experiment(
    snapshot,
    ledgr_strategy_schedule(strategy, ledgr_schedule_month_start()),
    features = list(ledgr_ind_returns(1L)),
    universe = ledgr_universe_members("DEMO_UNIVERSE"),
    cost_model = ledgr_cost_zero()
  )
}
params <- list(lookback = 252L, min_instruments = 2L,
               covariance_shrinkage = 0.5, equity_fraction = 0.95)

# ---------------------------------------------------------------------------
# Strategies. A: the vignette verbatim. B: identical except the solve.QP()
# call is NMOF::minvar(). C: cardinality-constrained minimum variance
# (at most max_names) by NMOF::LSopt() asset selection, seeded from
# ctx$pulse_seed. Helpers live inside the body: an unqualified user helper
# is Tier 3.
# ---------------------------------------------------------------------------
mv_qp <- function(ctx, params) {
  returns <- ctx |>
    ledgr_history_matrix(feature = "return_1", lookback = params$lookback,
                         min_instruments = params$min_instruments)
  if (!ledgr_passed_warmup(returns)) {
    return(list(targets = ctx$hold(), intent_reason = "insufficient_sample"))
  }
  sigma <- cov(returns)
  diagonal <- diag(diag(sigma), nrow = nrow(sigma))
  sigma <- (1 - params$covariance_shrinkage) * sigma +
    params$covariance_shrinkage * diagonal
  if (any(!is.finite(sigma)) || any(diag(sigma) <= 0)) {
    return(list(targets = ctx$hold(), intent_reason = "insufficient_sample"))
  }

  n <- ncol(sigma)
  solution <- quadprog::solve.QP(
    Dmat = sigma,
    dvec = rep(0, n),
    Amat = cbind(rep(1, n), diag(n)),
    bvec = c(1, rep(0, n)),
    meq = 1L
  )$solution
  if (any(!is.finite(solution)) || any(solution < -1e-8) ||
      abs(sum(solution) - 1) > 1e-8) {
    stop("The optimizer returned invalid long-only weights.")
  }
  solution[solution < 0] <- 0
  solution <- solution / sum(solution)

  targets <- solution |>
    ledgr_align_weights(returns) |>
    ledgr_target_rebalance(ctx, equity_fraction = params$equity_fraction)
  targets[!ctx$vec$member] <- 0
  list(targets = targets, intent_reason = "rebalanced")
}

mv_nmof <- function(ctx, params) {
  returns <- ctx |>
    ledgr_history_matrix(feature = "return_1", lookback = params$lookback,
                         min_instruments = params$min_instruments)
  if (!ledgr_passed_warmup(returns)) {
    return(list(targets = ctx$hold(), intent_reason = "insufficient_sample"))
  }
  sigma <- cov(returns)
  diagonal <- diag(diag(sigma), nrow = nrow(sigma))
  sigma <- (1 - params$covariance_shrinkage) * sigma +
    params$covariance_shrinkage * diagonal
  if (any(!is.finite(sigma)) || any(diag(sigma) <= 0)) {
    return(list(targets = ctx$hold(), intent_reason = "insufficient_sample"))
  }

  solution <- NMOF::minvar(sigma)
  if (any(!is.finite(solution)) || any(solution < -1e-8) ||
      abs(sum(solution) - 1) > 1e-8) {
    stop("The optimizer returned invalid long-only weights.")
  }
  solution[solution < 0] <- 0
  solution <- solution / sum(solution)

  targets <- solution |>
    ledgr_align_weights(returns) |>
    ledgr_target_rebalance(ctx, equity_fraction = params$equity_fraction)
  targets[!ctx$vec$member] <- 0
  list(targets = targets, intent_reason = "rebalanced")
}

mv_card <- function(ctx, params) {
  returns <- ctx |>
    ledgr_history_matrix(feature = "return_1", lookback = params$lookback,
                         min_instruments = params$min_instruments)
  if (!ledgr_passed_warmup(returns)) {
    return(list(targets = ctx$hold(), intent_reason = "insufficient_sample"))
  }
  sigma <- cov(returns)
  diagonal <- diag(diag(sigma), nrow = nrow(sigma))
  sigma <- (1 - params$covariance_shrinkage) * sigma +
    params$covariance_shrinkage * diagonal
  if (any(!is.finite(sigma)) || any(diag(sigma) <= 0)) {
    return(list(targets = ctx$hold(), intent_reason = "insufficient_sample"))
  }
  if (is.null(ctx$pulse_seed)) {
    stop("This strategy is stochastic: pass `seed =` to ledgr_run() or ledgr_sweep().")
  }

  n <- ncol(sigma)
  k <- min(params$max_names, n)
  selected <- rep(TRUE, n)
  if (n > k) {
    # Objective: variance of the long-only minimum-variance portfolio of the
    # selected names. Neighbour: swap one selected name for an unselected one.
    variance_of <- function(x, data) {
      attr(NMOF::minvar(data$sigma[x, x, drop = FALSE]), "variance")
    }
    swap_one <- function(x, data) {
      inside <- which(x)
      outside <- which(!x)
      x[inside[sample.int(length(inside), 1L)]] <- FALSE
      x[outside[sample.int(length(outside), 1L)]] <- TRUE
      x
    }
    # Pin the RNG kinds: mirai sweep workers run L'Ecuyer-CMRG, and
    # with_seed() otherwise keeps whatever kind is active.
    selected <- withr::with_seed(ctx$pulse_seed, {
      x0 <- logical(n)
      x0[sample.int(n, k)] <- TRUE
      algo <- list(x0 = x0, neighbour = swap_one, nS = params$n_steps,
                   printDetail = FALSE, printBar = FALSE)
      NMOF::LSopt(variance_of, algo, list(sigma = sigma))$xbest
    }, .rng_kind = "Mersenne-Twister", .rng_normal_kind = "Inversion",
       .rng_sample_kind = "Rejection")
  }
  solution <- numeric(n)
  solution[selected] <- NMOF::minvar(sigma[selected, selected, drop = FALSE])
  solution[solution < 0] <- 0
  solution <- solution / sum(solution)

  targets <- solution |>
    ledgr_align_weights(returns) |>
    ledgr_target_rebalance(ctx, equity_fraction = params$equity_fraction)
  targets[!ctx$vec$member] <- 0
  list(targets = targets, intent_reason = "rebalanced")
}

# Variants of mv_card, derived by rewriting its withr::with_seed() call so the
# rest of the body stays byte-for-byte the same:
# - mv_card_naive: with_seed(ctx$pulse_seed, ...) without pinned RNG kinds;
# - mv_card_gut: no with_seed() at all (ambient .Random.seed). --gut only.
rewrite_with_seed <- function(e, f) {
  if (!is.call(e)) return(e)
  if (identical(e[[1L]], quote(withr::with_seed))) return(f(e))
  as.call(lapply(as.list(e), rewrite_with_seed, f = f))
}
rng_kind_args <- c(".rng_kind", ".rng_normal_kind", ".rng_sample_kind")
mv_card_naive <- mv_card
body(mv_card_naive) <- rewrite_with_seed(body(mv_card), function(call) {
  call[!names(call) %in% rng_kind_args]
})
mv_card_gut <- mv_card
body(mv_card_gut) <- rewrite_with_seed(body(mv_card), function(call) call[[3L]])
stopifnot(!identical(body(mv_card_naive), body(mv_card)),
          !grepl("with_seed", paste(deparse(body(mv_card_gut)), collapse = "")))

card_params <- c(params, list(max_names = 5L, n_steps = 500L))

key_table <- function(x) {
  x <- as.data.frame(x)
  x <- x[, !grepl("run_id|event_id|fill_id|sweep_id", names(x)), drop = FALSE]
  rownames(x) <- NULL
  x
}
fills_of <- function(bt) key_table(ledgr_results(bt, "fills"))
equity_of <- function(bt) key_table(ledgr_results(bt, "equity"))

grid <- data.frame(lookback = 252L, min_instruments = 2L, covariance_shrinkage = 0.5,
                   equity_fraction = 0.95, max_names = c(4L, 5L), n_steps = 500L)
retain <- ledgr_sweep_retention(returns = "completed", trades = "closed")
sweep_table <- function(s) {
  d <- as.data.frame(s)
  d <- d[, vapply(d, is.atomic, logical(1L)), drop = FALSE]
  # Wall-clock telemetry is not execution output.
  d <- d[, !grepl("^t_", names(d)), drop = FALSE]
  key_table(d)
}
differing <- function(a, b) {
  if (!identical(names(a), names(b)) || nrow(a) != nrow(b)) return("<shape>")
  names(a)[!vapply(names(a), function(nm) identical(a[[nm]], b[[nm]]), logical(1L))]
}
sweep_pair <- function(strategy, label) {
  exp <- make_exp(strategy)
  t1 <- system.time(s1 <- ledgr_sweep(exp, grid, seed = 1L, workers = 1L,
                                      retain = retain))[["elapsed"]]
  t2 <- system.time(s2 <- ledgr_sweep(exp, grid, seed = 1L, workers = 2L,
                                      retain = retain))[["elapsed"]]
  d_rows <- differing(sweep_table(s1), sweep_table(s2))
  d_ret <- differing(key_table(ledgr_sweep_returns(s1)), key_table(ledgr_sweep_returns(s2)))
  d_trd <- differing(key_table(ledgr_sweep_trades(s1)), key_table(ledgr_sweep_trades(s2)))
  cat(label, "workers 1 vs 2 differing columns -- rows:", paste(d_rows, collapse = " "),
      "| returns:", paste(d_ret, collapse = " "), "| trades:", paste(d_trd, collapse = " "),
      "| secs w1", t1, "w2", t2, "\n")
  w <- sweep_table(s1)
  print(w[, c("candidate_id", "status", "execution_seed", "total_return", "sharpe_ratio")])
  list(table = w, rows = !length(d_rows), returns = !length(d_ret), trades = !length(d_trd),
       differing = paste(unique(c(d_rows, d_ret, d_trd)), collapse = " "))
}

if (mode == "gut") {
  # Gut: drop withr::with_seed(). The sequential check cannot catch this, because
  # the fold itself calls set.seed(execution_seed) once per run; the parallel
  # check must.
  section("GUT: heuristic without with_seed (ambient RNG)")
  exp_gut <- make_exp(mv_card_gut)
  g1 <- ledgr_run(exp_gut, card_params, run_id = "gut-1", seed = 42L)
  g2 <- ledgr_run(exp_gut, card_params, run_id = "gut-2", seed = 42L)
  cat("sequential seeded runs identical without with_seed:",
      identical(fills_of(g1), fills_of(g2)), "(not discriminating)\n")
  close(g1); close(g2)
  gut <- sweep_pair(mv_card_gut, "gut (ambient RNG):")
  caught <- !(gut$rows && gut$returns && gut$trades)
  cat(if (caught) "GUT CAUGHT: workers 1 vs 2 differ\n" else "GUT NOT CAUGHT: check is hollow\n")
  ledgr_snapshot_close(snapshot)
  quit(save = "no", status = if (caught) 0L else 1L)
}

# ---------------------------------------------------------------------------
# 0. Prerequisite: minvar vs the vignette solve.QP block, same covariance.
# ---------------------------------------------------------------------------
section("0. prerequisite: NMOF::minvar vs quadprog::solve.QP")
qp_raw <- function(sigma) {
  n <- ncol(sigma)
  quadprog::solve.QP(Dmat = sigma, dvec = rep(0, n), Amat = cbind(rep(1, n), diag(n)),
                     bvec = c(1, rep(0, n)), meq = 1L)$solution
}
set.seed(20261027L)
prereq <- do.call(rbind, lapply(seq_len(25L), function(i) {
  n <- sample(3:30, 1L)
  mix <- diag(n) + matrix(rnorm(n * n, sd = 0.4), n)
  x <- matrix(rnorm(300L * n, sd = 0.01), 300L) %*% mix
  s <- cov(x)
  a <- qp_raw(s)
  b <- as.numeric(NMOF::minvar(s))
  data.frame(case = i, n = n, n_zero_qp = sum(a < 1e-10),
             max_abs_diff = max(abs(a - b)))
}))
print(summary(prereq$max_abs_diff))
write_evidence(prereq, "prereq_random.csv")
if (max(prereq$max_abs_diff) > 1e-6) stop("KILL: minvar and solve.QP disagree beyond 1e-6")

# ---------------------------------------------------------------------------
# 1. Per-decision parity on the scheduled decisions (pulse snapshots).
# ---------------------------------------------------------------------------
section("1. per-decision parity")
exp_qp <- make_exp(mv_qp)
exp_nmof <- make_exp(mv_nmof)
exp_card <- make_exp(mv_card)

session_days <- sort(unique(as.Date(pit$bars$ts_utc)))
month_first <- session_days[!duplicated(format(session_days, "%Y-%m"))]
decisions <- do.call(rbind, lapply(as.list(month_first), function(d) {
  ctx <- tryCatch(ledgr_pulse_snapshot(exp_qp, ts_utc = d, params = params),
                  error = function(e) NULL)
  if (is.null(ctx)) return(NULL)
  on.exit(close(ctx))
  returns <- ledgr_history_matrix(ctx, feature = "return_1", lookback = params$lookback,
                                  min_instruments = params$min_instruments)
  if (!ledgr_passed_warmup(returns)) return(NULL)
  sigma <- cov(returns)
  sigma <- 0.5 * sigma + 0.5 * diag(diag(sigma), nrow = nrow(sigma))
  a <- qp_raw(sigma)
  b <- as.numeric(NMOF::minvar(sigma))
  ta <- mv_qp(ctx, params)$targets
  tb <- mv_nmof(ctx, params)$targets
  data.frame(decision = format(d), n_instruments = ncol(sigma),
             n_zero_weights = sum(a < 1e-10),
             min_weight_qp = min(a), min_weight_minvar = min(b),
             max_abs_weight_diff = max(abs(a - b)),
             targets_identical = identical(unname(ta), unname(tb)) &&
               identical(names(ta), names(tb)))
}))
print(decisions[, c("decision", "n_instruments", "n_zero_weights",
                    "max_abs_weight_diff", "targets_identical")])
write_evidence(decisions, "decisions.csv")
if (max(decisions$max_abs_weight_diff) > 1e-6) stop("KILL: per-decision weights differ beyond 1e-6")

# ---------------------------------------------------------------------------
# 1b. Whole-run parity: fills.
# ---------------------------------------------------------------------------
section("1b. run parity: quadprog vs minvar")
t_qp <- system.time(bt_qp <- ledgr_run(exp_qp, params, run_id = "mv-qp"))[["elapsed"]]
t_nmof <- system.time(bt_nmof <- ledgr_run(exp_nmof, params, run_id = "mv-nmof"))[["elapsed"]]
fills_qp <- fills_of(bt_qp)
fills_nmof <- fills_of(bt_nmof)
cat("fill columns:", paste(names(fills_qp), collapse = ", "), "\n")
fills_identical <- identical(fills_qp, fills_nmof)
cat("fills:", nrow(fills_qp), "vs", nrow(fills_nmof), "| identical:", fills_identical,
    "| run secs qp", t_qp, "nmof", t_nmof, "\n")
write_evidence(fills_qp, "fills_qp.csv")

# ---------------------------------------------------------------------------
# 3. Heuristic: reproducibility of sequential runs and of a parallel sweep.
# ---------------------------------------------------------------------------
section("3. heuristic: sequential runs")
t_card <- system.time(
  c1 <- ledgr_run(exp_card, card_params, run_id = "card-1", seed = 42L)
)[["elapsed"]]
c2 <- ledgr_run(exp_card, card_params, run_id = "card-2", seed = 42L)
c3 <- ledgr_run(exp_card, card_params, run_id = "card-3", seed = 43L)
fills_c1 <- fills_of(c1)
seq_identical <- identical(fills_c1, fills_of(c2)) && identical(equity_of(c1), equity_of(c2))
other_seed_differs <- !identical(fills_c1, fills_of(c3))
qty_col <- intersect(c("qty", "quantity"), names(fills_c1))[[1L]]
held <- stats::aggregate(fills_c1[[qty_col]] * ifelse(toupper(fills_c1$side) == "SELL", -1, 1),
                         by = list(instrument_id = fills_c1$instrument_id, ts = fills_c1$ts_utc),
                         FUN = sum)
held <- held[order(held$ts), ]
pos <- stats::setNames(numeric(length(ids)), ids)
max_names_held <- 0L
for (ts in unique(held$ts)) {
  rows <- held[held$ts == ts, ]
  pos[rows$instrument_id] <- pos[rows$instrument_id] + rows$x
  max_names_held <- max(max_names_held, sum(abs(pos) > 1e-9))
}
cat("seed 42 twice identical:", seq_identical, "| seed 43 differs:", other_seed_differs,
    "| max names held:", max_names_held, "| run secs:", t_card, "\n")
write_evidence(fills_c1, "fills_card_seed42.csv")

no_seed <- tryCatch({
  b <- ledgr_run(exp_card, card_params, run_id = "card-noseed")
  status <- paste("ran; status", format(b$status %||% NA))
  close(b)
  status
}, error = function(e) paste(class(e)[[1L]], conditionMessage(e)))
cat("run without seed:", substr(no_seed, 1L, 200L), "\n")

section("3b. heuristic: sweep workers = 1 vs workers = 2")
pinned <- sweep_pair(mv_card, "pinned RNG kind:")
naive <- sweep_pair(mv_card_naive, "naive with_seed:")
same_metrics <- identical(pinned$table[, c("execution_seed", "total_return", "sharpe_ratio")],
                          naive$table[, c("execution_seed", "total_return", "sharpe_ratio")])
cat("workers = 1: pinned and naive metrics identical:", same_metrics, "\n")
sweeps <- data.frame(
  variant = c("pinned_rng_kind", "naive_with_seed"),
  rows_identical = c(pinned$rows, naive$rows),
  returns_identical = c(pinned$returns, naive$returns),
  trades_identical = c(pinned$trades, naive$trades),
  differing_columns = c(pinned$differing, naive$differing)
)
write_evidence(sweeps, "sweep_workers_1_vs_2.csv")
write_evidence(pinned$table, "sweep_pinned_workers1.csv")

# Heuristic quality at the last decision: LSopt (5 seeds) vs exhaustive search.
section("3c. heuristic quality at the last decision")
ctx <- ledgr_pulse_snapshot(exp_card, ts_utc = max(as.Date(decisions$decision)), params = card_params)
returns <- ledgr_history_matrix(ctx, feature = "return_1", lookback = 252L, min_instruments = 2L)
close(ctx)
sigma <- cov(returns)
sigma <- 0.5 * sigma + 0.5 * diag(diag(sigma), nrow = nrow(sigma))
n <- ncol(sigma)
var_of <- function(x, data) attr(NMOF::minvar(data$sigma[x, x, drop = FALSE]), "variance")
swap_one <- function(x, data) {
  inside <- which(x); outside <- which(!x)
  x[inside[sample.int(length(inside), 1L)]] <- FALSE
  x[outside[sample.int(length(outside), 1L)]] <- TRUE
  x
}
t_exh <- system.time(
  exhaustive <- min(apply(utils::combn(n, 5L), 2L, function(idx) {
    attr(NMOF::minvar(sigma[idx, idx]), "variance")
  }))
)[["elapsed"]]
ls_best <- vapply(1:5, function(seed) withr::with_seed(seed, {
  x0 <- logical(n); x0[sample.int(n, 5L)] <- TRUE
  NMOF::LSopt(var_of, list(x0 = x0, neighbour = swap_one, nS = 500L,
                           printDetail = FALSE, printBar = FALSE),
              list(sigma = sigma))$OFvalue
}), numeric(1L))
quality <- data.frame(n_instruments = n, n_subsets = choose(n, 5L),
                      exhaustive_variance = exhaustive,
                      lsopt_seed = 1:5, lsopt_variance = ls_best,
                      rel_gap = ls_best / exhaustive - 1)
print(quality)
cat("exhaustive secs:", t_exh, "\n")
write_evidence(quality, "heuristic_quality.csv")

# ---------------------------------------------------------------------------
# 4. Preflight.
# ---------------------------------------------------------------------------
section("4. preflight")
flat <- function(x) if (length(x)) paste(sort(x), collapse = " ") else ""
# Minimal probes of the RNG classification next to the real strategies.
probe_sample <- function(ctx, params) list(targets = ctx$hold() * sample(1L), intent_reason = "x")
probe_sample_int <- function(ctx, params) list(targets = ctx$hold() * sample.int(1L), intent_reason = "x")
probe_set_seed <- function(ctx, params) {
  set.seed(ctx$pulse_seed, kind = "Mersenne-Twister")
  list(targets = ctx$hold(), intent_reason = "x")
}
preflight <- do.call(rbind, lapply(
  list(mv_qp = mv_qp, mv_nmof = mv_nmof, mv_card = mv_card, mv_card_naive = mv_card_naive,
       mv_card_gut = mv_card_gut, probe_sample = probe_sample,
       probe_sample_int = probe_sample_int, probe_set_seed = probe_set_seed),
  function(f) {
    p <- ledgr_strategy_preflight(f)
    data.frame(tier = p$tier, allowed = p$allowed,
               package_dependencies = flat(p$package_dependencies),
               ambient_rng_symbols = flat(p$ambient_rng_symbols),
               worker_require_namespace = flat(p$worker_dependencies$require_namespace),
               worker_attach = flat(p$worker_dependencies$attach),
               unresolved = flat(p$unresolved_symbols))
  }
))
preflight <- cbind(strategy = rownames(preflight), preflight)
rownames(preflight) <- NULL
print(preflight)
write_evidence(preflight, "preflight.csv")
print(ledgr_strategy_preflight(mv_card)$notes)

summary_rows <- data.frame(
  item = c("prereq_max_abs_diff", "decisions_compared", "decision_max_abs_weight_diff",
           "decision_targets_identical", "fills_rows", "fills_identical_qp_vs_minvar",
           "card_seq_identical_seed42", "card_seed43_differs", "card_max_names_held",
           "card_run_without_seed", "sweep_w1_vs_w2_identical_pinned_kind",
           "sweep_w1_vs_w2_identical_naive_with_seed",
           "sweep_w1_pinned_equals_naive_metrics"),
  value = c(format(max(prereq$max_abs_diff)), nrow(decisions),
            format(max(decisions$max_abs_weight_diff)), all(decisions$targets_identical),
            nrow(fills_qp), fills_identical, seq_identical, other_seed_differs,
            max_names_held, sub(" .*", "", no_seed),
            pinned$rows && pinned$returns && pinned$trades,
            naive$rows && naive$returns && naive$trades, same_metrics)
)
write_evidence(summary_rows, "summary.csv")
print(summary_rows)

for (b in list(bt_qp, bt_nmof, c1, c2, c3)) close(b)
ledgr_snapshot_close(snapshot)

# ---------------------------------------------------------------------------
# Checker: rerun output vs recorded evidence, plus package-scope guard.
# ---------------------------------------------------------------------------
if (mode == "check") {
  section("check: diff against recorded evidence")
  ok <- TRUE
  for (f in list.files(recorded_dir, pattern = "[.]csv$")) {
    same <- identical(readLines(file.path(recorded_dir, f)), readLines(file.path(out_dir, f)))
    cat(sprintf("%-28s %s\n", f, if (same) "same" else "DIFFERS"))
    ok <- ok && same
  }
  scope <- system2("git", c("-C", root, "status", "--porcelain", "--", "R", "src", "tests",
                            "NAMESPACE", "DESCRIPTION", "man", "inst/design"), stdout = TRUE)
  scope <- scope[!grepl("R/cpp11[.]R$|src/cpp11[.]cpp$", scope)]
  cat("package scope changes (excluding regenerated cpp11 glue):",
      if (length(scope)) paste(scope, collapse = "; ") else "none", "\n")
  quit(save = "no", status = if (ok && !length(scope)) 0L else 1L)
}
