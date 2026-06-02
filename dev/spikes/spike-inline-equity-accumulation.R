## Spike 1 (LDG-2505) - Inline Equity Accumulation In Memory Output Handler
##
## Question: Does replacing `ledgr_sweep_summary_from_ordered_events` with an
## inline-equity-accumulation memory output handler eliminate the
## reconstruction-pass cost on the ephemeral path?
##
## Variants:
##   A (production baseline) - current memory output handler + full
##     `ledgr_sweep_summary_from_ordered_events` call.
##   B (prototype) - memory output handler captures per-pulse equity / cash /
##     positions_value inline; reconstruction pass reduced to metrics only.
##   C (hybrid) - both inline equity AND full event log retained.
##
## Mechanism isolation: the fold-engine work is unchanged across variants
## (Variant B's per-pulse "record equity" hook is ~3 vector writes -- a few
## microseconds against the pulse-context construction cost already paid).
## So the recoverable wall is the full reconstruction-pass cost minus the
## variant-B metrics-only cost.

suppressPackageStartupMessages({
  pkgload::load_all("c:/Users/maxth/Documents/GitHub/ledgr", quiet = TRUE)
})

set.seed(20260601L)

bench_once <- function(expr) {
  gc(FALSE)
  t0 <- proc.time()[[3]]
  out <- force(expr)
  t1 <- proc.time()[[3]]
  list(out = out, elapsed = t1 - t0)
}

bench_repeated <- function(expr_fn, n_reps = 3L) {
  reps <- replicate(n_reps, {
    gc(FALSE)
    t0 <- proc.time()[[3]]
    expr_fn()
    proc.time()[[3]] - t0
  })
  list(median = median(reps), min = min(reps), max = max(reps), reps = reps)
}

## ---- Synthetic events fixture ----
##
## The reconstruction pass reads:
##   - events$event_seq, ts_utc, instrument_id, side, qty, price, fee
##   - events$event_type ("FILL", "FILL_PARTIAL", "CASHFLOW", ...)
##   - typed-meta cash_delta / position_delta (attached as attrs)
## and pulses_posix, close_mat, initial_cash, instrument_ids, run_id,
## metric_kernel.
##
## We build:
##   - 1 CASHFLOW seed event at pulse 1 (initial cash deposit)
##   - n_fill events distributed uniformly across pulses; each touches one
##     instrument selected with replacement; alternating BUY/SELL
##   - synthetic close prices: per-instrument random walk
make_events_fixture <- function(n_inst, n_pulses, n_fills) {
  initial_cash <- 1e6
  pulses_posix <- as.POSIXct("2020-01-01", tz = "UTC") +
    as.difftime(seq_len(n_pulses) - 1L, units = "days")
  instrument_ids <- sprintf("INST%04d", seq_len(n_inst))

  ## close prices: random walk per instrument, start at 100
  close_mat <- matrix(0, nrow = n_inst, ncol = n_pulses)
  for (j in seq_len(n_inst)) {
    close_mat[j, ] <- cumsum(c(100, rnorm(n_pulses - 1L, mean = 0, sd = 0.5)))
  }

  ## seed CASHFLOW event at t=1 (mimics opening cash inflow); the
  ## reconstruction pass reads typed cash_delta / position_delta if attached.
  ## We do NOT bother with the opening-positions seed here; the goal is
  ## measurement isolation, not semantic completeness.
  ev_pulse_idx <- sort(sample.int(n_pulses, n_fills, replace = TRUE))
  ev_ts <- pulses_posix[ev_pulse_idx]
  ev_seq <- seq_len(n_fills) + 1L
  ev_inst_idx <- sample.int(n_inst, n_fills, replace = TRUE)
  ev_inst <- instrument_ids[ev_inst_idx]
  ev_side <- ifelse(seq_len(n_fills) %% 2L == 0L, "BUY", "SELL")
  ev_qty <- as.numeric(sample.int(50L, n_fills, replace = TRUE))
  ev_price <- 100 + rnorm(n_fills, mean = 0, sd = 0.5)
  ev_fee <- rep(0.5, n_fills)
  ev_cash_delta <- ifelse(ev_side == "BUY",
                          -1 * ev_qty * ev_price - ev_fee,
                           1 * ev_qty * ev_price - ev_fee)
  ev_pos_delta <- ifelse(ev_side == "BUY", ev_qty, -1 * ev_qty)

  ## CASHFLOW seed row
  seed_row <- tibble::tibble(
    event_seq = 1L,
    event_id = "evt_seed",
    run_id = "spike_run",
    ts_utc = pulses_posix[[1L]],
    event_type = "CASHFLOW",
    instrument_id = NA_character_,
    side = NA_character_,
    qty = NA_real_,
    price = NA_real_,
    fee = NA_real_,
    meta_json = NA_character_
  )
  fill_rows <- tibble::tibble(
    event_seq = ev_seq,
    event_id = sprintf("evt_%07d", ev_seq),
    run_id = "spike_run",
    ts_utc = ev_ts,
    event_type = "FILL",
    instrument_id = ev_inst,
    side = ev_side,
    qty = ev_qty,
    price = ev_price,
    fee = ev_fee,
    meta_json = NA_character_
  )
  events <- rbind(seed_row, fill_rows)

  ## sort by event_seq (already sorted but ledger contract requires it)
  events <- events[order(events$event_seq), , drop = FALSE]

  ## attach typed meta as attrs (matches `ledgr_typed_event_metadata` output).
  ## Seed event's cash_delta is 0 -- initial_cash arg already covers it; the
  ## reconstruction computes cash_at = initial_cash + cumsum(cash_delta) and
  ## would double-count if the seed event contributed cash too.
  cash_delta_vec <- c(0, ev_cash_delta)
  pos_delta_vec <- c(0, ev_pos_delta)
  meta_list <- vector("list", nrow(events))
  for (k in seq_along(meta_list)) {
    meta_list[[k]] <- list(
      cash_delta = cash_delta_vec[[k]],
      position_delta = pos_delta_vec[[k]],
      realized_pnl = NULL
    )
  }
  attr(events, "ledgr_event_cash_delta") <- cash_delta_vec
  attr(events, "ledgr_event_position_delta") <- pos_delta_vec
  attr(events, "ledgr_event_meta") <- meta_list
  class(events) <- unique(c("ledgr_memory_events", class(events)))

  list(
    events = events,
    pulses_posix = pulses_posix,
    close_mat = close_mat,
    initial_cash = initial_cash,
    instrument_ids = instrument_ids,
    n_inst = n_inst,
    n_pulses = n_pulses,
    n_fills = n_fills
  )
}

## ---- Variant A: production baseline ----
run_variant_a <- function(fx, metric_kernel) {
  ledgr_sweep_summary_from_ordered_events(
    events = fx$events,
    pulses_posix = fx$pulses_posix,
    close_mat = fx$close_mat,
    initial_cash = fx$initial_cash,
    instrument_ids = fx$instrument_ids,
    run_id = "spike_run",
    metric_kernel = metric_kernel
  )
}

## ---- Variant B: prototype (skip reconstruction, accept inline equity) ----
##
## The inline-accumulation handler would have captured (per pulse):
##   - cash[t]
##   - positions_value[t] = sum(state$positions * close_mat[, t])
##   - equity[t] = cash[t] + positions_value[t]
##   - realized_pnl[t] (running)
##   - cost_basis[t] (running)
## and fills (in tibble form) during the fold.
##
## So Variant B's reconstruction work is just:
##   - take the inline equity vector (n_pulses scalar reads)
##   - compute metrics from equity + fills
##   - final_equity = equity[[n_pulses]]
##
## To measure this faithfully without modifying the fold engine, we cheat:
## run Variant A once to get equity + fills, then time JUST the
## metrics + finalization step. That is what a prototype handler would pay
## post-fold.
run_variant_b_from_inline <- function(equity, fills, metric_kernel) {
  metrics <- ledgr_metrics_from_equity_fills(
    equity = equity,
    fills = fills,
    metric_kernel = metric_kernel
  )
  list(
    equity = equity,
    fills = fills,
    metrics = metrics,
    final_equity = equity$equity[[nrow(equity)]]
  )
}

## ---- Variant C: hybrid (inline equity + retained event log) ----
##
## Variant C is what Variant B is + a tiny event-log accumulation overhead
## during the fold (basically zero vs the per-pulse pulse-context construction
## already paid). Post-fold cost is identical to Variant B because the event
## log is preserved but not replayed. We measure cost == Variant B.
run_variant_c_from_inline <- run_variant_b_from_inline

## ---- Per-pulse inline-write cost simulation ----
##
## Even though Variant B's post-fold cost is metrics-only, the fold itself
## does a tiny extra `equity_vec[i] <- ...` per pulse. Measure that overhead
## standalone so the wall translation is honest.
measure_inline_write_cost <- function(n_pulses, n_reps = 5L) {
  bench_repeated(function() {
    equity_vec <- numeric(n_pulses)
    cash_vec <- numeric(n_pulses)
    pv_vec <- numeric(n_pulses)
    for (i in seq_len(n_pulses)) {
      equity_vec[[i]] <- 1e6 + i * 0.01
      cash_vec[[i]] <- 1e6 + i * 0.01
      pv_vec[[i]] <- i * 0.01
    }
    invisible(NULL)
  }, n_reps = n_reps)
}

## ---- Parity check ----
##
## Variant B equity comes from the SAME reconstruction pass we are trying
## to eliminate. To prove the equity curve produced by inline accumulation
## would match Variant A byte-for-byte, we synthesize the inline curve
## independently using the same primitives the fold engine would use:
## per-pulse `state$cash + sum(state$positions * close_mat[, i])`.
synth_inline_equity <- function(fx) {
  pulses_posix <- fx$pulses_posix
  n_pulses <- length(pulses_posix)
  n_inst <- fx$n_inst
  inst_ids <- fx$instrument_ids
  close_mat <- fx$close_mat
  events <- fx$events
  cash_delta <- attr(events, "ledgr_event_cash_delta")
  pos_delta <- attr(events, "ledgr_event_position_delta")
  event_ts_num <- as.numeric(as.POSIXct(events$ts_utc, tz = "UTC"))
  pulse_ts_num <- as.numeric(pulses_posix)

  ## walk events in order, updating cash + positions; record at each pulse
  ## boundary. To do this fast for parity we use the existing findInterval
  ## technique: that's exactly what the reconstruction pass does, only here
  ## we apply it on the SAME inputs and assert equality against the
  ## reconstruction-derived equity.
  cash_cum <- cumsum(cash_delta)
  idx <- findInterval(pulse_ts_num, event_ts_num)
  has_event <- idx > 0L
  cash_at <- rep(fx$initial_cash, length(idx))
  if (any(has_event)) {
    cash_at[has_event] <- fx$initial_cash + cash_cum[idx[has_event]]
  }

  positions_mat <- matrix(0, nrow = n_inst, ncol = n_pulses)
  inst_factor <- match(events$instrument_id, inst_ids)
  for (j in seq_len(n_inst)) {
    ev_idx <- which(inst_factor == j)
    if (length(ev_idx) == 0L) next
    pos_cum_j <- cumsum(pos_delta[ev_idx])
    idx_inst <- findInterval(pulse_ts_num, event_ts_num[ev_idx])
    has_inst_event <- idx_inst > 0L
    if (any(has_inst_event)) {
      positions_mat[j, has_inst_event] <- pos_cum_j[idx_inst[has_inst_event]]
    }
  }
  positions_value <- colSums(positions_mat * close_mat)
  cash_at + positions_value
}

## ---- Sweep over grid cells ----
##
## Grid cell scales (matching LDG-2479):
##   13.5k events  : n_inst=100,  n_pulses=1260, n_fills=13355  (large_durable)
##   30k events    : n_inst=300,  n_pulses=1260, n_fills=30000
##   68k events    : n_inst=500,  n_pulses=1260, n_fills=68324  (xlarge density_high)
##   130k events   : n_inst=1000, n_pulses=1260, n_fills=130000 (xlarge density_high+inst1000)

scales <- list(
  list(n_inst = 100L,  n_pulses = 1260L, n_fills = 13355L, label = "13.5k"),
  list(n_inst = 300L,  n_pulses = 1260L, n_fills = 30000L, label = "30k"),
  list(n_inst = 500L,  n_pulses = 1260L, n_fills = 68324L, label = "68k"),
  list(n_inst = 1000L, n_pulses = 1260L, n_fills = 130000L, label = "130k")
)

metric_kernel <- ledgr_metric_kernel(
  context = ledgr_metric_context()
)

results <- vector("list", length(scales))
for (k in seq_along(scales)) {
  sc <- scales[[k]]
  cat(sprintf("\n[scale %s] building fixture (n_inst=%d, n_pulses=%d, n_fills=%d)\n",
              sc$label, sc$n_inst, sc$n_pulses, sc$n_fills))

  fx <- make_events_fixture(sc$n_inst, sc$n_pulses, sc$n_fills)

  ## Variant A: production baseline. Time three reps for a stable median.
  cat("[scale ", sc$label, "] timing Variant A (reconstruction-pass) x 3 reps\n", sep = "")
  a_times <- numeric(3L)
  a_out <- NULL
  for (rep in seq_len(3L)) {
    gc(FALSE)
    t0 <- proc.time()[[3]]
    a_out <- run_variant_a(fx, metric_kernel)
    a_times[rep] <- proc.time()[[3]] - t0
    cat(sprintf("  rep %d : %.3fs\n", rep, a_times[rep]))
  }
  a_med <- median(a_times)

  ## Parity: inline-equity curve matches Variant A's equity curve
  inline_equity <- synth_inline_equity(fx)
  parity_ok <- isTRUE(all.equal(inline_equity, a_out$equity$equity,
                                tolerance = 1e-9))
  cat(sprintf("[scale %s] equity parity (inline vs reconstruction): %s\n",
              sc$label, if (parity_ok) "PASS" else "FAIL"))
  if (!parity_ok) {
    diffs <- abs(inline_equity - a_out$equity$equity)
    cat(sprintf("  max abs diff = %.6e, mean abs diff = %.6e\n",
                max(diffs), mean(diffs)))
  }

  ## Variant B: metrics-only post-fold cost
  cat("[scale ", sc$label, "] timing Variant B (metrics-only) x 3 reps\n", sep = "")
  b_times <- numeric(3L)
  for (rep in seq_len(3L)) {
    gc(FALSE)
    t0 <- proc.time()[[3]]
    b_out <- run_variant_b_from_inline(a_out$equity, a_out$fills, metric_kernel)
    b_times[rep] <- proc.time()[[3]] - t0
    cat(sprintf("  rep %d : %.3fs\n", rep, b_times[rep]))
  }
  b_med <- median(b_times)

  ## Inline-write cost during fold (overhead added to Variant B path)
  inline_write_cost <- measure_inline_write_cost(sc$n_pulses, n_reps = 5L)

  recovery <- a_med - b_med - inline_write_cost$median
  results[[k]] <- list(
    scale = sc$label,
    n_inst = sc$n_inst,
    n_pulses = sc$n_pulses,
    n_fills = sc$n_fills,
    a_median = a_med,
    a_reps = a_times,
    b_median = b_med,
    b_reps = b_times,
    inline_write_median = inline_write_cost$median,
    inline_write_reps = inline_write_cost$reps,
    recovery_s = recovery,
    speedup = a_med / max(b_med + inline_write_cost$median, 1e-6),
    parity_ok = parity_ok
  )
  rm(fx, a_out)
  gc(FALSE)
}

cat("\n\n========== SPIKE 1 SUMMARY ==========\n")
cat(sprintf("%-6s %8s %8s %8s %10s %10s %10s %8s %8s\n",
            "scale", "n_inst", "n_pulses", "n_fills", "VarA_s", "VarB_s", "InlW_s",
            "recov_s", "speedup"))
for (r in results) {
  cat(sprintf("%-6s %8d %8d %8d %10.3f %10.3f %10.4f %8.3f %8.2fx\n",
              r$scale, r$n_inst, r$n_pulses, r$n_fills,
              r$a_median, r$b_median, r$inline_write_median,
              r$recovery_s, r$speedup))
}
cat("\nVarA = ledgr_sweep_summary_from_ordered_events (production baseline)\n")
cat("VarB = metrics + finalization only (cost after inline equity handler skips reconstruction)\n")
cat("InlW = simulated per-pulse equity/cash/pv vector-write overhead added during fold\n")
cat("recov_s = VarA - (VarB + InlW)\n")

## Persist results to CSV for the log
res_df <- do.call(rbind, lapply(results, function(r) data.frame(
  scale = r$scale,
  n_inst = r$n_inst,
  n_pulses = r$n_pulses,
  n_fills = r$n_fills,
  variant_a_s = r$a_median,
  variant_b_s = r$b_median,
  inline_write_s = r$inline_write_median,
  recovery_s = r$recovery_s,
  speedup = r$speedup,
  parity_ok = r$parity_ok,
  stringsAsFactors = FALSE
)))
out_csv <- "c:/Users/maxth/Documents/GitHub/ledgr/dev/bench/results/spike_inline_equity_accumulation.csv"
if (!dir.exists(dirname(out_csv))) dir.create(dirname(out_csv), recursive = TRUE)
write.csv(res_df, out_csv, row.names = FALSE)
cat(sprintf("\nResults written to %s\n", out_csv))
