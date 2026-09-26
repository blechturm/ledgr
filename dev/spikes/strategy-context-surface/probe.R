# Read-only source-level probes, not ledgr_run() or a package benchmark.
# From repository root: Rscript dev/spikes/strategy-context-surface/probe.R OUT [gut]
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 1L, requireNamespace("rlang", quietly = TRUE))
out <- args[[1L]]
gut <- length(args) > 1L && identical(args[[2L]], "gut")
env <- new.env(parent = globalenv())
for (file in c("pulse-context.R", "feature-alias-map.R", "strategy-types.R",
               "strategy-helpers.R", "walk-forward-selection.R", "timestamp.R", "runtime-projection.R",
               "features-engine.R")) {
  sys.source(file.path("R", file), envir = env)
}
# Import the same standard null-coalescing operator; no ledgr functions are stubbed.
env$`%||%` <- rlang::`%||%`
if (gut) {
  # Deliberately remove the held-nonmember budget reservation in this local copy.
  fn <- env$ledgr_target_rebalance
  drop_reservation <- function(x) {
    if (!is.call(x)) return(x)
    if (identical(x[[1L]], as.name("<-")) &&
        identical(x[[2L]], as.name("held_nonmembers"))) {
      return(quote(held_nonmembers <- character()))
    }
    for (i in seq_along(x)) x[[i]] <- drop_reservation(x[[i]])
    x
  }
  body(fn) <- drop_reservation(body(fn))
  env$ledgr_target_rebalance <- fn
}
rows <- list()
record <- function(case, observation, expr) {
  value <- tryCatch(paste(capture.output(dput(force(expr))), collapse = " "),
    error = function(e) paste0("ERROR[", class(e)[[1L]], "]: ", conditionMessage(e)))
  rows[[length(rows) + 1L]] <<- data.frame(case, observation, value)
  invisible(NULL)
}
with(env, {
  ts <- "2020-01-02T00:00:00Z"
  make_ctx <- function(ids = c("AAA", "BBB"), prices = c(10, 20),
                       positions = stats::setNames(c(0, 0), ids), equity = 300) {
    bars <- data.frame(instrument_id = ids, ts_utc = rep(ts, length(ids)),
      open = prices, high = prices, low = prices, close = prices,
      volume = rep(100, length(ids)), gap_type = rep("NONE", length(ids)),
      is_synthetic = rep(FALSE, length(ids)))
    features <- data.frame(instrument_id = character(), ts_utc = character(),
      feature_name = character(), feature_value = double())
    ledgr_pulse_context("probe", ts, ids, bars, features, positions,
      cash = equity - sum(positions * prices), equity = equity, seed = 1,
      pulse_seed = 2)
  }
  ctx <- make_ctx()
  public <- ctx[!startsWith(names(ctx), ".")]
  record("census", "top_level_count", length(public))
  record("census", "function_count", sum(vapply(public, is.function, logical(1))))
  record("census", "members", names(public))
  record("census", "vec_members", names(ctx$vec))
  record("census", "tradable_present", is.function(ctx$tradable))
  record("state", "hold_identical_full_positions", identical(ctx$hold(), ctx$positions))
  target <- ctx$hold(); target[["AAA"]] <- 99
  record("state", "editing_hold_leaves_positions", ctx$positions)
  sparse <- make_ctx(positions = c(AAA = 2))
  record("state", "hold_identical_sparse_constructor_positions",
    identical(sparse$hold(), sparse$positions))
  record("lookup", "bar_names", names(ctx$bar("AAA")))
  record("lookup", "positions_not_in_bar", !"positions" %in% names(ctx$bar("AAA")))
  record("lookup", "plane_names", names(ctx$vec$close))
  record("lookup", "character_single_bracket", ctx$vec$close["AAA"])
  record("lookup", "character_double_bracket", ctx$vec$close[["AAA"]])
  record("lookup", "idx_bridge", ctx$vec$close[[ctx$idx("AAA")]])
  record("lookup", "tombstone_targets", ctx$targets())
  record("lookup", "tombstone_current_targets", ctx$current_targets())
  record("features", "empty_table", dim(ctx$feature_table))
  record("features", "no_alias_map", ctx$features("AAA"))
  features <- data.frame(instrument_id = rep(c("AAA", "BBB"), each = 2),
    ts_utc = ts, feature_name = rep(c("sma_2", "return_2"), 2),
    feature_value = c(10.25, NA_real_, 20.25, .05))
  fx <- ledgr_update_pulse_context_helpers(ctx, features = features,
    active_alias_map = c(trend = "sma_2", ret = "return_2"))
  record("features", "populated_long_table", dim(fx$feature_table))
  record("features", "populated_wide_table", dim(fx$features_wide))
  record("features", "active_alias_bundle", fx$features("AAA"))
  record("features", "explicit_alias_bundle",
    fx$features("BBB", c(trend = "sma_2", ret = "return_2")))
  record("features", "feature_plane", fx$vec$feature("return_2"))
  record("features", "exact_scalar", fx$feature("BBB", "return_2"))
  projection <- ledgr_runtime_projection(
    list(sma_2 = matrix(c(10.25, 20.25), ncol = 1),
         return_2 = matrix(c(NA_real_, .05), ncol = 1)), ctx$universe,
    as.POSIXct(ts, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    feature_engine_version = "proto:context-response")
  px <- ledgr_update_pulse_context_helpers(ctx, projection = projection,
    pulse_idx = 1L, features_wide = fx$features_wide,
    active_alias_map = c(trend = "sma_2", ret = "return_2"))
  record("features", "projection_empty_long_table", dim(px$feature_table))
  record("features", "projection_active_alias_bundle", px$features("AAA"))

  A <- function(x) ledgr_selection(stats::setNames(rep(TRUE, length(x$universe)),
    x$universe)) |> ledgr_weight_equal() |> ledgr_target_rebalance(x)
  B <- function(x) ledgr_selection(x$flat() == 0) |>
    ledgr_weight_equal() |> ledgr_target_rebalance(x)
  C <- function(x) ledgr_signal(x$flat() + 1) |>
    ledgr_select_top_n(length(x$universe)) |>
    ledgr_weight_equal() |> ledgr_target_rebalance(x)
  D <- function(x) { y <- x$flat(); y[] <- floor(x$equity / length(y) / x$vec$close); y }
  record("pipeline", "dense_A_B_C_D_quantities", lapply(list(A, B, C, D),
    function(f) { x <- f(ctx); stats::setNames(as.numeric(x), names(x)) }))
  record("pipeline", "sparse_selection_explicit_exit",
    ledgr_selection(c(AAA = TRUE)) |> ledgr_weight_equal() |> ledgr_target_rebalance(ctx))
  record("pipeline", "candidate_argmax_formals", names(formals(ledgr_select_argmax)))
  av <- make_ctx(c("AAA", "OLD"), c(10, 20), c(AAA = 0, OLD = 2), 100)
  av$availability_active <- TRUE; av$members <- "AAA"
  av$vec$member <- c(TRUE, FALSE); av$vec$held <- c(FALSE, TRUE)
  av$vec$admissible <- c(TRUE, FALSE); av$vec$risk_mark <- c(10, 20)
  record("membership", "full_axis_A", A(av))
  record("membership", "member_allocation",
    ledgr_selection(c(AAA = TRUE)) |> ledgr_weight_equal() |> ledgr_target_rebalance(av))
  record("membership", "manual_D", D(av))
  record("membership", "unselected_member_preserved_nonmember",
    ledgr_selection(c(AAA = FALSE)) |> ledgr_weight_equal() |> ledgr_target_rebalance(av))
  missing <- make_ctx(positions = c(AAA = 0, BBB = 3), equity = 100)
  missing$availability_active <- TRUE; missing$members <- c("AAA", "BBB")
  missing$vec$close <- c(10, NA_real_); missing$vec$risk_mark <- c(10, 20)
  missing$vec$priced <- c(TRUE, TRUE); missing$vec$admissible <- c(TRUE, TRUE)
  record("missing", "priced_and_admissible_but_sizing_fails", A(missing))
  record("missing", "filtering_missing_creates_zero_target",
    ledgr_selection(c(AAA = TRUE)) |> ledgr_weight_equal() |>
      ledgr_target_rebalance(missing))
  record("missing", "NA_selection_rejected", ledgr_selection(c(AAA = TRUE, BBB = NA)))
  record("empty", "interactive_constructor",
    make_ctx(character(), double(), stats::setNames(double(), character()), 100))
  empty <- ctx
  empty$universe <- character()
  empty$positions <- stats::setNames(double(), character())
  empty$bars <- ctx$bars[FALSE, ]
  empty <- ledgr_update_pulse_context_helpers(empty)
  empty$availability_active <- TRUE; empty$members <- character()
  record("empty", "hold", empty$hold())
  record("empty", "target_constructor", ledgr_target(empty$hold()))
  record("empty", "rebalance", ledgr_target_rebalance(ledgr_weights(numeric()), empty))
})
dir.create(out, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(do.call(rbind, rows), file.path(out, "observations.csv"), row.names = FALSE)
cat(R.version.string, "; rlang ", as.character(utils::packageVersion("rlang")), "\n", sep = "")
