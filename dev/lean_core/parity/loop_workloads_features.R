# The feature routes end to end (Cut 27 decision 2, LDG-3281): the routes of
# feature_bridge.R, run as lean-versus-pin workloads on the advanced pin, so
# the lean loop consumes the package's feature engine on every route.
#
# Fixtures and features are the feature oracle's (dev/feature_parity/corpus.R):
# - clocks: the bar-native basket (fe_bar_native) and the declared-session
#   universe with gaps and a late known_inactive fact (fe_declared);
# - features: the oracle's e2e indicators plus two parameterised aliases
#   (signal = RSI(rsi_n), the BBands dn/up outputs with bb_n);
# - two candidates, rsi_n 3 and 5.
# Each workload runs four routes: implicit preparation, implicit with two
# workers, an explicit precompute reused, and that reuse with two workers.
#
# The strategy reads every current feature (ledgr_pulse_features()) and turns
# them into its targets: each instrument's finite feature values, weighted
# by their alias's rank, are summed, and the target is that sum's
# floor(|s| * 13) mod 3 shares. A wrong value, a swapped alias or an unused
# feature changes the trades, so a feature path cannot pass vacuously.
local({
  corpus <- file.path(here, "..", "..", "feature_parity", "corpus.R")
  sys.source(corpus, envir = globalenv(), keep.source = FALSE)
})
fe_features <- function() {
  e2e <- fx_e2e_features()
  names(e2e) <- paste0("x_", gsub("[^A-Za-z0-9_]", "_", vapply(e2e, function(f) f$id, "")))
  do.call(ledgr::ledgr_feature_map, c(e2e, list(
    signal = ledgr::ledgr_ind_ttr("RSI", input = "close", n = ledgr::ledgr_param("rsi_n")),
    ledgr::ledgr_ind_ttr_outputs("BBands", input = "close", outputs = c("dn", "up"), n = ledgr::ledgr_param("bb_n")))))
}
fe_grid <- function() ledgr::ledgr_grid_cross(features = ledgr::ledgr_feature_grid(rsi_n = c(3L, 5L), bb_n = 4L),
                                              strategy = ledgr::ledgr_strategy_grid(k = 1))
fe_strategy <- function() {
  f <- function(ctx, params) {
    ft <- ledgr_pulse_features(ctx)
    aliases <- sort(unique(ft$alias))
    w <- match(ft$alias, aliases)
    v <- ft$feature_value
    ok <- is.finite(v)
    t <- ctx$hold()
    s <- vapply(names(t), function(id) {
      k <- ok & ft$instrument_id == id
      sum(v[k] * w[k])
    }, numeric(1))
    t[] <- floor(abs(s) * 13) %% 3
    t
  }
  environment(f) <- ns
  f
}
fe_routes <- function(name, build_fx) function() {
  db <- file.path(work, paste0(name, ".duckdb"))
  if (file.exists(db)) unlink(db)
  restore <- s5_count_parallel()
  on.exit(restore())
  # The oracle's builders leave the snapshot id to ledgr, which stamps it with
  # the time; each arm builds its own store, so the id is fixed here instead
  # (the sweep attributes carry it). Nothing else about the fixture changes.
  make <- get("ledgr_snapshot_from_df", envir = ns)
  unfix <- lw_rebind("ledgr_snapshot_from_df", function(...) {
    a <- list(...)
    if (is.null(a$snapshot_id)) a$snapshot_id <- name
    do.call(make, a)
  })
  fx <- tryCatch(build_fx(db, fe_strategy(), fe_features()), finally = unfix())
  on.exit(ledgr::ledgr_snapshot_close(fx$snapshot), add = TRUE)
  grid <- fe_grid()
  pre <- ledgr::ledgr_precompute_features(fx$exp, grid)
  sweep <- function(...) a0_sweep_tables(ledgr::ledgr_sweep(fx$exp, grid, seed = 3L, retain = a0_retain(), ...))
  list(implicit = sweep(), implicit_w2 = sweep(workers = 2L),
       reuse = sweep(precomputed_features = pre), reuse_w2 = sweep(precomputed_features = pre, workers = 2L))
}
loop_features <- list(
  fe_bar_native = fe_routes("fe_bar_native", fx_bar_native),
  fe_declared = fe_routes("fe_declared", fx_declared)
)

# The route each workload is named for, on the pin's own tables: both worker
# routes dispatched their two candidates to workers (four tasks); every
# route ended both candidates with the fixture's status and with trades; the
# four routes agree, as preparation, workers and reuse must. On the
# bar-native fixture the two candidates also end differently, so the
# parameterised alias reaches the targets. The declared fixture's late
# known_inactive fact stops both candidates (INCOMPLETE) before RSI 3 and 5
# diverge there; the value and alias variants show its features drive the
# outputs.
fe_reach <- function(status, distinct) function(t) {
  routes <- c("implicit", "implicit_w2", "reuse", "reuse_w2")
  ok <- all(vapply(routes, function(r) {
    s <- t[[r]]$sweep
    NROW(s) == 2L && all(as.character(s$status) == status) && all(as.numeric(s$n_trades) > 0)
  }, logical(1)))
  eq <- function(r) as.character(t[[r]]$sweep$final_equity)
  ok && s5_staged(4L) && (!distinct || length(unique(eq("implicit"))) == 2L) &&
    all(vapply(routes[-1L], function(r) identical(eq(r), eq("implicit")), logical(1)))
}
loop_reach <- c(loop_reach, list(fe_bar_native = fe_reach("DONE", TRUE), fe_declared = fe_reach("INCOMPLETE", FALSE)))
