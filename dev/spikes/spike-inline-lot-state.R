## Spike 10 (LDG-2514) - Inline Lot-State In Memory Output Handler
##
## Question: does capturing lot state inline during fold execution (in the
## memory output handler) eliminate the per-event lot-machinery replay in
## `ledgr_sweep_summary_from_ordered_events` at R/fold-reconstruction.R:454-504?
##
## Mechanism: the reconstruction pass replays `ledgr_lot_apply_event` per
## event to derive `event_realized` and `event_cost_basis`. The fold engine
## already runs the same lot machinery during execution to emit fill events.
## Capturing per-pulse (or per-event) lot state in the memory output handler
## removes the replay entirely.
##
## This spike isolates the lot-replay slice of reconstruction cost from the
## equity-recompute slice (which Spike 1 / LDG-2505 measures together as
## the full reconstruction pass).

suppressPackageStartupMessages({
  pkgload::load_all("c:/Users/maxth/Documents/GitHub/ledgr", quiet = TRUE)
})

set.seed(20260601L)

bench_repeated <- function(expr_fn, n_reps = 3L) {
  reps <- replicate(n_reps, {
    gc(FALSE)
    t0 <- proc.time()[["elapsed"]]
    expr_fn()
    proc.time()[["elapsed"]] - t0
  })
  list(median = median(reps), min = min(reps), max = max(reps), reps = reps)
}

## ---- Variant A: production lot-replay loop ----
## Mirror lines 453-504 of fold-reconstruction.R verbatim, isolated from
## the cash/positions/fills work measured in Spike 1.
variant_a_lot_replay <- function(events, instrument_ids, typed_meta = NULL) {
  n_events <- nrow(events)
  reconstruction_lots <- ledgr_lot_state(instrument_ids)
  event_realized <- numeric(n_events)
  event_cost_basis <- numeric(n_events)
  event_ts <- if (n_events > 0L) {
    as.POSIXct(events$ts_utc, tz = "UTC")
  } else {
    as.POSIXct(character(0), tz = "UTC")
  }
  for (i in seq_len(n_events)) {
    event_type <- as.character(events$event_type[[i]])
    inst <- as.character(events$instrument_id[[i]])
    side <- as.character(events$side[[i]])
    qty <- suppressWarnings(as.numeric(events$qty[[i]]))
    price <- suppressWarnings(as.numeric(events$price[[i]]))
    fee <- suppressWarnings(as.numeric(events$fee[[i]]))
    meta <- ledgr_event_meta_at(events, typed_meta, i)
    lot_res <- ledgr_lot_apply_event(
      reconstruction_lots,
      event_type = event_type,
      instrument_id = inst,
      side = side,
      qty = qty,
      price = price,
      fee = fee,
      meta = meta
    )
    reconstruction_lots <- lot_res$state
    event_realized[[i]] <- reconstruction_lots$realized_pnl
    event_cost_basis[[i]] <- reconstruction_lots$total_cost_basis
  }
  list(event_realized = event_realized, event_cost_basis = event_cost_basis)
}

## ---- Variant B: pre-captured per-event lot state read ----
## What the inline-capture path would actually do: read two pre-computed
## numeric vectors (event_realized, event_cost_basis) that the fold engine
## emitted during execution. No replay.
variant_b_pre_captured <- function(n_events) {
  event_realized <- numeric(n_events)
  event_cost_basis <- numeric(n_events)
  ## emulate a single tibble-style read from the memory output handler
  list(event_realized = event_realized, event_cost_basis = event_cost_basis)
}

## ---- Variant C: per-pulse capture (sparser) ----
## The handler captures lot state once per pulse rather than per event.
## Reconstruction reads n_pulses scalars and projects onto pulse boundary
## via findInterval (already needed for cash curve).
variant_c_per_pulse <- function(n_pulses) {
  realized_at <- numeric(n_pulses)
  cost_basis_at <- numeric(n_pulses)
  list(realized_at = realized_at, cost_basis_at = cost_basis_at)
}

## ---- Cost of the lot-machinery work that happens during the fold ----
## In production, the fold engine already calls lot machinery during fill
## emission. The "additional cost" of inline capture is just the vector
## writes that propagate realized_pnl / cost_basis into the output handler.
## Measure that overhead with realistic event counts.
measure_inline_capture_cost <- function(n_events, n_reps = 5L) {
  bench_repeated(function() {
    realized_vec <- numeric(n_events)
    cost_basis_vec <- numeric(n_events)
    for (i in seq_len(n_events)) {
      realized_vec[[i]] <- i * 0.001
      cost_basis_vec[[i]] <- i * 0.001
    }
    invisible(NULL)
  }, n_reps = n_reps)
}

## ---- Fixture (matches Spike 1's events shape) ----
make_events_fixture <- function(n_inst, n_pulses, n_fills) {
  pulses_posix <- as.POSIXct("2020-01-01", tz = "UTC") +
    as.difftime(seq_len(n_pulses) - 1L, units = "days")
  instrument_ids <- sprintf("INST%04d", seq_len(n_inst))
  ev_pulse_idx <- sort(sample.int(n_pulses, n_fills, replace = TRUE))
  ev_ts <- pulses_posix[ev_pulse_idx]
  ev_inst <- instrument_ids[sample.int(n_inst, n_fills, replace = TRUE)]
  ev_side <- ifelse(seq_len(n_fills) %% 2L == 0L, "BUY", "SELL")
  ev_qty <- as.numeric(sample.int(50L, n_fills, replace = TRUE))
  ev_price <- 100 + rnorm(n_fills, mean = 0, sd = 0.5)
  ev_fee <- rep(0.5, n_fills)
  meta_json_vec <- vapply(seq_len(n_fills), function(i) {
    canonical_json(list(
      cash_delta = if (ev_side[[i]] == "BUY") -ev_qty[[i]] * ev_price[[i]] - ev_fee[[i]] else ev_qty[[i]] * ev_price[[i]] - ev_fee[[i]],
      position_delta = if (ev_side[[i]] == "BUY") ev_qty[[i]] else -ev_qty[[i]],
      realized_pnl = NULL
    ))
  }, character(1))
  events <- tibble::tibble(
    event_seq = seq_len(n_fills) + 1L,
    event_id = sprintf("evt_%07d", seq_len(n_fills) + 1L),
    run_id = "spike_run",
    ts_utc = ev_ts,
    event_type = "FILL",
    instrument_id = ev_inst,
    side = ev_side,
    qty = ev_qty,
    price = ev_price,
    fee = ev_fee,
    meta_json = meta_json_vec
  )
  list(
    events = events,
    instrument_ids = instrument_ids,
    n_inst = n_inst, n_pulses = n_pulses, n_fills = n_fills
  )
}

## ---- Sweep ----
## Smaller scales than Spike 1 because the lot-replay loop is heavy and we
## time three reps per scale. 130k fills with full lot machinery is slow
## standalone; cap at one rep there.
scales <- list(
  list(n_inst = 100L,  n_pulses = 1260L, n_fills = 13355L, label = "13.5k", reps = 3L),
  list(n_inst = 300L,  n_pulses = 1260L, n_fills = 30000L, label = "30k",   reps = 3L),
  list(n_inst = 500L,  n_pulses = 1260L, n_fills = 68324L, label = "68k",   reps = 2L),
  list(n_inst = 1000L, n_pulses = 1260L, n_fills = 130000L, label = "130k", reps = 1L)
)

results <- vector("list", length(scales))
for (k in seq_along(scales)) {
  sc <- scales[[k]]
  cat(sprintf("\n[scale %s] n_inst=%d n_pulses=%d n_fills=%d (reps=%d)\n",
              sc$label, sc$n_inst, sc$n_pulses, sc$n_fills, sc$reps))
  fx <- make_events_fixture(sc$n_inst, sc$n_pulses, sc$n_fills)

  ## Variant A: full lot replay
  a_times <- numeric(sc$reps)
  for (rep in seq_len(sc$reps)) {
    gc(FALSE)
    t0 <- proc.time()[["elapsed"]]
    a_out <- variant_a_lot_replay(fx$events, fx$instrument_ids, typed_meta = NULL)
    a_times[rep] <- proc.time()[["elapsed"]] - t0
    cat(sprintf("  VarA rep %d : %.3fs\n", rep, a_times[rep]))
  }
  a_med <- if (length(a_times) >= 3) median(a_times) else min(a_times)

  ## Variant B: pre-captured read
  b <- bench_repeated(function() variant_b_pre_captured(sc$n_fills), n_reps = 5L)

  ## Inline capture overhead during fold
  inline_cost <- measure_inline_capture_cost(sc$n_fills, n_reps = 5L)

  recovery <- a_med - b$median - inline_cost$median
  results[[k]] <- list(
    scale = sc$label, n_inst = sc$n_inst, n_pulses = sc$n_pulses,
    n_fills = sc$n_fills,
    a_median = a_med, a_reps = a_times,
    b_median = b$median,
    inline_capture_median = inline_cost$median,
    recovery_s = recovery,
    us_per_event = a_med * 1e6 / sc$n_fills
  )

  cat(sprintf("  VarA median        : %.3fs\n", a_med))
  cat(sprintf("  VarB (pre-captured): %.4fs\n", b$median))
  cat(sprintf("  Inline capture     : %.4fs\n", inline_cost$median))
  cat(sprintf("  Standalone recovery: %.3fs (%.2f us/event)\n",
              recovery, results[[k]]$us_per_event))

  rm(fx, a_out); gc(FALSE)
}

cat("\n========== SPIKE 10 SUMMARY ==========\n")
cat(sprintf("%-6s %8s %8s %8s %10s %10s %10s %10s %10s\n",
            "scale", "n_inst", "n_pulses", "n_fills",
            "VarA_s", "VarB_s", "InlCap_s", "recov_s", "us/event"))
for (r in results) {
  cat(sprintf("%-6s %8d %8d %8d %10.3f %10.4f %10.4f %10.3f %10.2f\n",
              r$scale, r$n_inst, r$n_pulses, r$n_fills,
              r$a_median, r$b_median, r$inline_capture_median,
              r$recovery_s, r$us_per_event))
}
cat("\nVarA = full per-event ledgr_lot_apply_event replay loop (production)\n")
cat("VarB = pre-captured event_realized / event_cost_basis vector read\n")
cat("InlCap = simulated per-fill realized_pnl / cost_basis vector-write overhead during fold\n")
cat("recov_s = VarA - (VarB + InlCap)\n")

res_df <- do.call(rbind, lapply(results, function(r) data.frame(
  scale = r$scale, n_inst = r$n_inst, n_pulses = r$n_pulses,
  n_fills = r$n_fills,
  variant_a_s = r$a_median, variant_b_s = r$b_median,
  inline_capture_s = r$inline_capture_median,
  recovery_s = r$recovery_s, us_per_event = r$us_per_event,
  stringsAsFactors = FALSE
)))
out_csv <- "c:/Users/maxth/Documents/GitHub/ledgr/dev/bench/results/spike_inline_lot_state.csv"
write.csv(res_df, out_csv, row.names = FALSE)
cat(sprintf("\nResults written to %s\n", out_csv))
