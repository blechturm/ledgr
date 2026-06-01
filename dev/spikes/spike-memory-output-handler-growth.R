# Spike: ledgr_memory_output_handler per-event append cost as a function of
# accumulated event count
#
# Context: LDG-2476 three-phase decomposition showed ephemeral ledgr's engine
# phase is +16.4s vs durable at 68k fills, and results phase is +40.9s. The
# memory output handler in R/sweep.R:957-1163 uses the same B0
# grow-by-doubling buffer (R/fold-event-buffer.R) but accumulates all events
# for the run before reconstruction. Hypothesis: per-event append cost grows
# with accumulated event count (O(n^2) signature) because base-R [[<-
# on the buffer columns still copies on each write, even with B0 sizing.
#
# Per the v0.1.8.7 collapse optimization map: "sizing (base R, no dep): stop
# over-allocating, grow by doubling -> 27-101x. Still copies fills-sized
# columns, so O(fills^2). setv (in-place by reference) -> 65-1300x vs current".
# Spike 6 measures whether the memory handler retains the O(fills^2) cost
# the v0.1.8.7 sizing fix only reduced.
#
# FAITHFULNESS: replicates the ledgr_memory_output_handler structure from
# R/sweep.R:957-1163. 14 columns matching the production schema. Uses the
# real ledgr_event_buffer_next_capacity logic for grow-by-doubling. The
# difference is the spike's append loop calls a stripped-down
# append_event_row_list directly to avoid handler wrapping overhead.
#
# Variants:
#   handler_baseR  : replica of current handler (base-R [[<- column writes)
#   buffer_only    : same column writes but no enclosing env wrapping
#   handler_setv   : same column writes via collapse::setv (in-place)
#
# CAVEAT: ephemeral peer benchmark uses ledgr:::ledgr_memory_output_handler
# directly. This spike replicates the structure but is not the production
# handler. Real-run gate is re-running the LDG-2479 ephemeral xlarge cell
# after a setv-based fix to the production handler.
#
# Usage:
#   Rscript dev/spikes/spike-memory-output-handler-growth.R

suppressWarnings(suppressMessages(library(collapse)))

`%||%` <- function(x, y) if (is.null(x)) y else x

# Replicate ledgr_event_buffer_next_capacity from R/fold-event-buffer.R
next_capacity <- function(current, required, max_events,
                          initial = 1024L, growth = 2) {
  if (required <= current) return(as.integer(current))
  capacity <- max(current, initial)
  while (capacity < required) {
    capacity <- min(max_events, max(required, ceiling(capacity * growth)))
  }
  as.integer(capacity)
}

# Pre-built row payload (matches handler buffer_event input shape).
# A fixed payload is reused so spike times BUFFER WRITE only, not payload
# construction.
ROW <- list(
  event_id = "run_x_00000001",
  run_id = "run_x",
  ts_utc = as.POSIXct("2026-01-01", tz = "UTC"),
  event_type = "FILL",
  instrument_id = "INST_00001",
  side = "BUY",
  qty = 1,
  price = 100,
  fee = 0,
  meta_json = '{"cash_delta":-100,"position_delta":1}',
  event_seq = 1L
)
CASH_DELTA <- -100
POSITION_DELTA <- 1
META <- list(cash_delta = -100, position_delta = 1, realized_pnl = NULL)

# Variant (a): faithful replica of ledgr_memory_output_handler buffer
make_handler_baser <- function(max_events) {
  state <- new.env(parent = emptyenv())
  state$event_count <- 0L
  state$event_capacity <- 0L
  state$event_max_capacity <- as.integer(max_events)
  state$event_cols <- NULL

  init_event_cols <- function(capacity) {
    state$event_capacity <- as.integer(max(0L, capacity))
    state$event_cols <- list(
      event_id = character(state$event_capacity),
      run_id = character(state$event_capacity),
      ts_utc = as.POSIXct(rep(NA_real_, state$event_capacity), tz = "UTC"),
      event_type = character(state$event_capacity),
      instrument_id = character(state$event_capacity),
      side = character(state$event_capacity),
      qty = numeric(state$event_capacity),
      price = numeric(state$event_capacity),
      fee = numeric(state$event_capacity),
      meta_json = character(state$event_capacity),
      event_seq = integer(state$event_capacity),
      cash_delta = numeric(state$event_capacity),
      position_delta = numeric(state$event_capacity),
      meta = vector("list", state$event_capacity)
    )
  }

  ensure_capacity <- function(required) {
    nc <- next_capacity(state$event_capacity, required, state$event_max_capacity)
    if (required <= state$event_capacity) return(invisible(TRUE))
    old_cols <- state$event_cols
    old_count <- state$event_count
    init_event_cols(nc)
    if (!is.null(old_cols) && old_count > 0L) {
      idx <- seq_len(old_count)
      for (name in names(old_cols)) {
        state$event_cols[[name]][idx] <- old_cols[[name]][idx]
      }
    }
  }

  init_event_cols(1024L)

  append <- function(row, cash_delta, position_delta, meta) {
    ensure_capacity(state$event_count + 1L)
    state$event_count <- state$event_count + 1L
    i <- state$event_count
    state$event_cols$event_id[[i]] <- row$event_id
    state$event_cols$run_id[[i]] <- row$run_id
    state$event_cols$ts_utc[[i]] <- row$ts_utc
    state$event_cols$event_type[[i]] <- row$event_type
    state$event_cols$instrument_id[[i]] <- row$instrument_id
    state$event_cols$side[[i]] <- row$side
    state$event_cols$qty[[i]] <- as.numeric(row$qty)
    state$event_cols$price[[i]] <- as.numeric(row$price)
    state$event_cols$fee[[i]] <- as.numeric(row$fee)
    state$event_cols$meta_json[[i]] <- row$meta_json
    state$event_cols$event_seq[[i]] <- as.integer(row$event_seq)
    state$event_cols$cash_delta[[i]] <- as.numeric(cash_delta)
    state$event_cols$position_delta[[i]] <- as.numeric(position_delta)
    state$event_cols$meta[i] <- list(meta)
    invisible(TRUE)
  }

  list(state = state, append = append)
}

# Variant (b): setv-based writes (in-place by C reference)
make_handler_setv <- function(max_events) {
  state <- new.env(parent = emptyenv())
  state$event_count <- 0L
  state$event_capacity <- 0L
  state$event_max_capacity <- as.integer(max_events)
  state$event_cols <- NULL

  init_event_cols <- function(capacity) {
    state$event_capacity <- as.integer(max(0L, capacity))
    state$event_cols <- list(
      event_id = character(state$event_capacity),
      run_id = character(state$event_capacity),
      ts_utc = as.POSIXct(rep(NA_real_, state$event_capacity), tz = "UTC"),
      event_type = character(state$event_capacity),
      instrument_id = character(state$event_capacity),
      side = character(state$event_capacity),
      qty = numeric(state$event_capacity),
      price = numeric(state$event_capacity),
      fee = numeric(state$event_capacity),
      meta_json = character(state$event_capacity),
      event_seq = integer(state$event_capacity),
      cash_delta = numeric(state$event_capacity),
      position_delta = numeric(state$event_capacity),
      meta = vector("list", state$event_capacity)
    )
  }

  ensure_capacity <- function(required) {
    nc <- next_capacity(state$event_capacity, required, state$event_max_capacity)
    if (required <= state$event_capacity) return(invisible(TRUE))
    old_cols <- state$event_cols
    old_count <- state$event_count
    init_event_cols(nc)
    if (!is.null(old_cols) && old_count > 0L) {
      idx <- seq_len(old_count)
      for (name in names(old_cols)) {
        state$event_cols[[name]][idx] <- old_cols[[name]][idx]
      }
    }
  }

  init_event_cols(1024L)

  append <- function(row, cash_delta, position_delta, meta) {
    ensure_capacity(state$event_count + 1L)
    state$event_count <- state$event_count + 1L
    i <- state$event_count
    collapse::setv(state$event_cols$event_id, i, row$event_id, vind1 = TRUE)
    collapse::setv(state$event_cols$run_id, i, row$run_id, vind1 = TRUE)
    collapse::setv(state$event_cols$ts_utc, i, row$ts_utc, vind1 = TRUE)
    collapse::setv(state$event_cols$event_type, i, row$event_type, vind1 = TRUE)
    collapse::setv(state$event_cols$instrument_id, i, row$instrument_id, vind1 = TRUE)
    collapse::setv(state$event_cols$side, i, row$side, vind1 = TRUE)
    collapse::setv(state$event_cols$qty, i, as.numeric(row$qty), vind1 = TRUE)
    collapse::setv(state$event_cols$price, i, as.numeric(row$price), vind1 = TRUE)
    collapse::setv(state$event_cols$fee, i, as.numeric(row$fee), vind1 = TRUE)
    collapse::setv(state$event_cols$meta_json, i, row$meta_json, vind1 = TRUE)
    collapse::setv(state$event_cols$event_seq, i, as.integer(row$event_seq), vind1 = TRUE)
    collapse::setv(state$event_cols$cash_delta, i, as.numeric(cash_delta), vind1 = TRUE)
    collapse::setv(state$event_cols$position_delta, i, as.numeric(position_delta), vind1 = TRUE)
    state$event_cols$meta[i] <- list(meta)
    invisible(TRUE)
  }

  list(state = state, append = append)
}

# Per-event timing: run N appends, measuring interval costs
run_with_intervals <- function(maker, n_total, interval = 5000L,
                               max_events_hint = 200000L) {
  h <- maker(max_events_hint)
  measure_points <- seq(interval, n_total, by = interval)
  results <- data.frame(
    accumulated = integer(),
    interval_elapsed_s = numeric(),
    us_per_event = numeric()
  )
  done <- 0L
  for (m in measure_points) {
    n_to_do <- m - done
    t <- system.time({
      for (k in seq_len(n_to_do)) {
        h$append(ROW, CASH_DELTA, POSITION_DELTA, META)
      }
    })[["elapsed"]]
    results <- rbind(results, data.frame(
      accumulated = m,
      interval_elapsed_s = t,
      us_per_event = t / n_to_do * 1e6
    ))
    done <- m
  }
  list(results = results, final_count = h$state$event_count,
       final_capacity = h$state$event_capacity)
}

# Parity check: both variants produce same row count
cat("=== parity check ===\n")
hb <- make_handler_baser(1000L)
hs <- make_handler_setv(1000L)
for (k in 1:100) {
  hb$append(ROW, CASH_DELTA, POSITION_DELTA, META)
  hs$append(ROW, CASH_DELTA, POSITION_DELTA, META)
}
cat(sprintf("handler_baser count = %d, handler_setv count = %d  [%s]\n\n",
            hb$state$event_count, hs$state$event_count,
            if (hb$state$event_count == hs$state$event_count) "OK" else "FAIL"))
if (hb$state$event_count != hs$state$event_count) stop("Parity failed.")

# Main timing: 130k events, measure per-event cost at intervals of 5000
n_total <- 130000L
interval <- 5000L

cat("=== handler_baser (replica of current memory handler) ===\n")
cat(sprintf("%-12s | %10s %12s\n", "accumulated", "interval_s", "us_per_event"))
baser_results <- run_with_intervals(make_handler_baser, n_total, interval, n_total + 100L)
for (i in seq_len(nrow(baser_results$results))) {
  r <- baser_results$results[i, ]
  cat(sprintf("%-12d | %9.4fs %12.2f\n",
              r$accumulated, r$interval_elapsed_s, r$us_per_event))
}
cat(sprintf("Final capacity: %d, final count: %d\n\n",
            baser_results$final_capacity, baser_results$final_count))

cat("=== handler_setv (collapse::setv writes) ===\n")
cat(sprintf("%-12s | %10s %12s\n", "accumulated", "interval_s", "us_per_event"))
setv_results <- run_with_intervals(make_handler_setv, n_total, interval, n_total + 100L)
for (i in seq_len(nrow(setv_results$results))) {
  r <- setv_results$results[i, ]
  cat(sprintf("%-12d | %9.4fs %12.2f\n",
              r$accumulated, r$interval_elapsed_s, r$us_per_event))
}
cat(sprintf("Final capacity: %d, final count: %d\n\n",
            setv_results$final_capacity, setv_results$final_count))

# Summary
cat("=== summary ===\n")
b_first <- baser_results$results$us_per_event[[1]]
b_last <- tail(baser_results$results$us_per_event, 1)
s_first <- setv_results$results$us_per_event[[1]]
s_last <- tail(setv_results$results$us_per_event, 1)
cat(sprintf("handler_baser:  first interval %.2f us/event, last %.2f us/event, growth %.2fx\n",
            b_first, b_last, b_last / b_first))
cat(sprintf("handler_setv :  first interval %.2f us/event, last %.2f us/event, growth %.2fx\n",
            s_first, s_last, s_last / s_first))
cat(sprintf("baser vs setv at last interval: %.2fx\n", b_last / s_last))

# Aggregate write to CSV
all_results <- rbind(
  cbind(variant = "handler_baser", baser_results$results),
  cbind(variant = "handler_setv", setv_results$results)
)
out <- "dev/bench/results/spike_memory_output_handler_growth.csv"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(all_results, out, row.names = FALSE)
cat(sprintf("\nWROTE %s\n", out))
