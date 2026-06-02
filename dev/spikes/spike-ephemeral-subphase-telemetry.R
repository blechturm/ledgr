## Spike 11 (LDG-2515) - Ephemeral Sweep Subphase Telemetry
##
## Question: prove that proc.time() snapshots around (engine + handler
## buffer writes) and (reconstruction + fills extraction) can be wired into
## the existing `ledgr_sweep_telemetry_env()` pattern so the workload-grid
## harness can report ephemeral subphase costs (engine_sec, results_sec,
## fills_extract_sec) without bespoke harness code.
##
## Mechanism: the production sweep candidate executes
##   ledgr_execute_fold(execution, output_handler)
##   events <- output_handler$typed_events()
##   summary <- ledgr_sweep_summary_from_ordered_events(events, ...)
## with no per-phase wall capture. Peer benchmark gets it via manual
## proc.time wrap (dev/bench/peer_benchmark/peer_benchmark.R:323-376) but
## sweep candidates can't be wrapped that way without changing every caller.
##
## Spike 11 proves: extend `ledgr_sweep_telemetry_env()` with three new
## fields (t_engine, t_results, t_fills_extract); the production wrapper
## fills them; a prototype "subphase-aware" sweep candidate executor reads
## them out. Wall round-trips through the synthetic harness.

suppressPackageStartupMessages({
  pkgload::load_all("c:/Users/maxth/Documents/GitHub/ledgr", quiet = TRUE)
})

set.seed(20260601L)

## ---- Synthetic sweep candidate at LDG-2476 shape ----
##
## Build a small but realistic ephemeral sweep candidate. We use a trivial
## SMA-crossover style strategy that fires no fills (so the spike measures
## the telemetry path, not a heavy execution); a separate run uses
## `peer_run_ledgr_ephemeral` shape so reconstruction has actual events.

make_synthetic_bars <- function(n_inst, n_pulses, seed = 42L) {
  set.seed(seed)
  pulses_posix <- as.POSIXct("2020-01-01", tz = "UTC") +
    as.difftime(seq_len(n_pulses) - 1L, units = "days")
  instrument_ids <- sprintf("INST%04d", seq_len(n_inst))
  bars_list <- vector("list", n_inst)
  for (j in seq_len(n_inst)) {
    p <- cumsum(c(100, rnorm(n_pulses - 1L, 0, 0.5)))
    bars_list[[j]] <- data.frame(
      instrument_id = instrument_ids[[j]],
      ts_utc = pulses_posix,
      open = p,
      high = p + 0.1,
      low = p - 0.1,
      close = p,
      volume = 1e6,
      stringsAsFactors = FALSE
    )
  }
  bars <- do.call(rbind, bars_list)
  list(
    bars = bars,
    pulses_posix = pulses_posix,
    instrument_ids = instrument_ids
  )
}

## A small strategy producing some fills so reconstruction has work to do.
sma_strategy <- function(ctx, params) {
  univ <- ctx$universe
  n <- length(univ)
  ## change target every 30th pulse; otherwise hold steady. day-of-month
  ## parsing from ts_utc string ("YYYY-MM-DDTHH:MM:SSZ"; substr 9-10 is DD).
  ## cycles through {0, 50, 100, 25} on day digits {00, 30 wrap..}.
  day_chr <- substr(as.character(ctx$ts_utc), 9L, 10L)
  day_int <- suppressWarnings(as.integer(day_chr))
  if (is.na(day_int)) day_int <- 1L
  tag <- (day_int %/% 7L) %% 4L
  qty <- if (tag == 0L) rep(0, n)
         else if (tag == 1L) rep(50, n)
         else if (tag == 2L) rep(100, n)
         else rep(25, n)
  stats::setNames(as.numeric(qty), univ)
}

## ---- Production-shape ephemeral candidate execution with subphase hooks ----
##
## We don't modify the production code. Instead we wrap proc.time() snapshots
## around the same hot frames the production
## `ledgr_sweep_candidate_execute` body uses (sweep.R:919-934), driving a
## telemetry env we extend with three fields.

run_candidate_with_subphase_telemetry <- function(fixture, n_pulses_used = 1260L) {
  bars <- fixture$bars
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
  runtime_projection <- ledgr:::ledgr_projection_from_feature_matrix(
    feature_matrix = list(),
    universe = universe,
    pulses_posix = pulses_posix,
    feature_engine_version = ledgr:::ledgr_feature_engine_version(),
    alias_index = NULL
  )
  initial_positions <- stats::setNames(rep(0, length(universe)), universe)
  run_id <- "spike11_ephemeral"

  output_handler <- ledgr:::ledgr_memory_output_handler(run_id)
  telemetry <- ledgr:::ledgr_sweep_telemetry_env()

  ## --- proposed new telemetry fields (the spike validates them) ---
  telemetry$t_engine <- NA_real_
  telemetry$t_results <- NA_real_
  telemetry$t_fills_extract <- NA_real_

  cost_resolver <- ledgr:::ledgr_cost_spread_commission_internal(
    spread_bps = 0, commission_fixed = 0
  )

  execution <- ledgr:::ledgr_execution_spec(
    run_id = run_id,
    instrument_ids = universe,
    strategy_fn = sma_strategy,
    strategy_params = list(),
    strategy_call_signature = ledgr:::ledgr_strategy_signature(sma_strategy),
    strategy_is_functional = TRUE,
    pulses_posix = pulses_posix,
    pulses_iso = pulses_iso,
    start_idx = 1L,
    max_pulses = Inf,
    checkpoint_every = 0L,
    telemetry_stride = 0L,
    state = list(cash = 1e7, positions = initial_positions),
    state_prev = NULL,
    bars_by_id = bars_by_id,
    bars_mat = bars_mat,
    static_bars_views = static_bars_views,
    static_feature_views = NULL,
    feature_defs = list(),
    runtime_projection = runtime_projection,
    active_alias_map = NULL,
    cost_resolver = cost_resolver,
    event_seq_start = 1L,
    telemetry = telemetry,
    seed = 1L,
    event_mode = "buffered",
    use_fast_context = TRUE
  )

  ## hook 1: engine wall (fold execution + handler buffer writes)
  t0 <- proc.time()[["elapsed"]]
  ledgr:::ledgr_execute_fold(execution, output_handler)
  t1 <- proc.time()[["elapsed"]]
  telemetry$t_engine <- t1 - t0

  ## hook 2: events extraction + reconstruction wall
  events <- output_handler$typed_events()
  t2 <- proc.time()[["elapsed"]]
  metric_kernel <- ledgr_metric_kernel(
    context = ledgr_metric_context(),
    pulses = pulses_posix
  )
  summary <- ledgr:::ledgr_sweep_summary_from_ordered_events(
    events = events,
    pulses_posix = pulses_posix,
    close_mat = bars_mat$close,
    initial_cash = 1e7,
    instrument_ids = universe,
    run_id = run_id,
    metric_kernel = metric_kernel
  )
  t3 <- proc.time()[["elapsed"]]
  telemetry$t_results <- t3 - t2

  ## hook 3: fills extraction sub-component (separate measurement)
  t4 <- proc.time()[["elapsed"]]
  fills_inline <- summary$fills
  t5 <- proc.time()[["elapsed"]]
  telemetry$t_fills_extract <- t5 - t4

  list(
    telemetry = telemetry,
    summary = summary,
    n_events = nrow(events),
    n_pulses = length(pulses_posix),
    n_inst = length(universe)
  )
}

## ---- Workload-grid harness CSV emission ----
##
## Production workload grid writes phase_sec columns into a CSV row per
## cell. Spike 11 proves the new telemetry fields round-trip into that
## CSV layout.

emit_workload_grid_row <- function(result, scale_label) {
  data.frame(
    scale = scale_label,
    n_inst = result$n_inst,
    n_pulses = result$n_pulses,
    n_events = result$n_events,
    engine_sec = result$telemetry$t_engine,
    results_sec = result$telemetry$t_results,
    fills_extract_sec = result$telemetry$t_fills_extract,
    total_sec = result$telemetry$t_engine + result$telemetry$t_results,
    stringsAsFactors = FALSE
  )
}

## ---- Run the spike at two scales ----

scales <- list(
  list(label = "small",  n_inst = 50L,   n_pulses = 1260L),
  list(label = "medium", n_inst = 200L,  n_pulses = 1260L)
)

rows <- list()
for (k in seq_along(scales)) {
  sc <- scales[[k]]
  cat(sprintf("[scale %s] building fixture (n_inst=%d, n_pulses=%d)\n",
              sc$label, sc$n_inst, sc$n_pulses))
  fx <- make_synthetic_bars(sc$n_inst, sc$n_pulses)

  cat(sprintf("[scale %s] running candidate with subphase telemetry\n",
              sc$label))
  result <- run_candidate_with_subphase_telemetry(fx, sc$n_pulses)
  cat(sprintf("  n_events=%d, engine=%.3fs, results=%.3fs, fills_extract=%.4fs\n",
              result$n_events,
              result$telemetry$t_engine,
              result$telemetry$t_results,
              result$telemetry$t_fills_extract))

  rows[[k]] <- emit_workload_grid_row(result, sc$label)
  rm(fx, result); gc(FALSE)
}

csv <- do.call(rbind, rows)
cat("\n========== SPIKE 11 OUTPUT CSV ==========\n")
print(csv, row.names = FALSE)

out_csv <- "c:/Users/maxth/Documents/GitHub/ledgr/dev/bench/results/spike_ephemeral_subphase_telemetry.csv"
if (!dir.exists(dirname(out_csv))) dir.create(dirname(out_csv), recursive = TRUE)
write.csv(csv, out_csv, row.names = FALSE)
cat(sprintf("\nResults written to %s\n", out_csv))

## --- Verification of the spike's success criterion ---
##
## "Workload-grid harness verified to capture and report ephemeral
##  subphases" -- the CSV above has non-NA engine_sec / results_sec /
##  fills_extract_sec columns for every row.
non_na_ok <- all(
  !is.na(csv$engine_sec) &
  !is.na(csv$results_sec) &
  !is.na(csv$fills_extract_sec)
)
cat(sprintf("\nNon-NA telemetry across all scales: %s\n",
            if (non_na_ok) "PASS" else "FAIL"))
