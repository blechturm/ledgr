# Spike 11: persistent durable output handler pending_cols buffer scaling
#
# Context: Codex peer review of the v0.1.8.9 spike round (Finding 1) showed
# Spike 4 (LDG-2483, per-row DBI INSERT) is not faithful to the default
# durable production path. Default durable runs use audit_log mode through
# `ledgr_persistent_output_handler` which buffers events into a
# `state$pending_cols` list of typed vectors and flushes via
# `DBI::dbAppendTable`. The per-row column-buffer writes at
# R/backtest-runner.R:425-435 look identical to the memory output handler
# pattern that Spike 6 (LDG-2485) confirmed as O(N^2).
#
# Hypothesis: persistent handler's `pending_cols` writes exhibit the same
# O(N^2) per-event growth as Spike 6's memory handler. Fix is the same
# `collapse::setv` replacement applied to 11 column writes.
#
# FAITHFULNESS: replicates the persistent handler structure from
# R/backtest-runner.R:288-437. 11 columns matching the production schema.
# Uses the same `ledgr_event_buffer_next_capacity` logic from
# R/fold-event-buffer.R. The spike's append loop calls a stripped-down
# `buffer_event` directly to avoid handler-wrapping overhead.
#
# Variants:
#   handler_baser  : replica of current handler (base-R [[<- column writes)
#   handler_setv   : same column writes via collapse::setv (in-place)
#
# CAVEAT: production handler also unpacks `write_res$row` per event and
# does a status check (R/backtest-runner.R:416-421). The spike skips that
# wrapping but uses the same per-column write pattern. Real-run gate is
# the LDG-2479 grid xlarge cell after the production handler is patched.

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

# Pre-built event row payload matching write_res$row shape.
# A fixed payload is reused so spike times the BUFFER WRITE only.
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

# Variant (a): faithful replica of persistent handler buffer
make_handler_baser <- function(max_events) {
  state <- new.env(parent = emptyenv())
  state$pending_idx <- 0L
  state$pending_capacity <- 0L
  state$pending_max_events <- as.integer(max_events)
  state$pending_cols <- NULL

  init_pending_cols <- function(capacity) {
    state$pending_capacity <- as.integer(max(0L, capacity))
    state$pending_cols <- list(
      event_id = character(state$pending_capacity),
      run_id = character(state$pending_capacity),
      ts_utc = as.POSIXct(rep(NA_real_, state$pending_capacity), tz = "UTC"),
      event_type = character(state$pending_capacity),
      instrument_id = character(state$pending_capacity),
      side = character(state$pending_capacity),
      qty = numeric(state$pending_capacity),
      price = numeric(state$pending_capacity),
      fee = numeric(state$pending_capacity),
      meta_json = character(state$pending_capacity),
      event_seq = integer(state$pending_capacity)
    )
  }

  ensure_capacity <- function(required) {
    nc <- next_capacity(state$pending_capacity, required, state$pending_max_events)
    if (!is.null(state$pending_cols) && nc <= state$pending_capacity) return(invisible(TRUE))
    old_cols <- state$pending_cols
    old_count <- state$pending_idx
    init_pending_cols(nc)
    if (!is.null(old_cols) && old_count > 0L) {
      idx <- seq_len(old_count)
      for (name in names(old_cols)) {
        state$pending_cols[[name]][idx] <- old_cols[[name]][idx]
      }
    }
  }

  init_pending_cols(1024L)

  append <- function(row) {
    i <- state$pending_idx + 1L
    ensure_capacity(i)
    state$pending_idx <- i
    state$pending_cols$event_id[[i]] <- row$event_id
    state$pending_cols$run_id[[i]] <- row$run_id
    state$pending_cols$ts_utc[[i]] <- row$ts_utc
    state$pending_cols$event_type[[i]] <- row$event_type
    state$pending_cols$instrument_id[[i]] <- row$instrument_id
    state$pending_cols$side[[i]] <- row$side
    state$pending_cols$qty[[i]] <- as.numeric(row$qty)
    state$pending_cols$price[[i]] <- as.numeric(row$price)
    state$pending_cols$fee[[i]] <- as.numeric(row$fee)
    state$pending_cols$meta_json[[i]] <- row$meta_json
    state$pending_cols$event_seq[[i]] <- as.integer(row$event_seq)
    invisible(TRUE)
  }

  list(state = state, append = append)
}

# Variant (b): setv-based writes (in-place by C reference)
make_handler_setv <- function(max_events) {
  state <- new.env(parent = emptyenv())
  state$pending_idx <- 0L
  state$pending_capacity <- 0L
  state$pending_max_events <- as.integer(max_events)
  state$pending_cols <- NULL

  init_pending_cols <- function(capacity) {
    state$pending_capacity <- as.integer(max(0L, capacity))
    state$pending_cols <- list(
      event_id = character(state$pending_capacity),
      run_id = character(state$pending_capacity),
      ts_utc = as.POSIXct(rep(NA_real_, state$pending_capacity), tz = "UTC"),
      event_type = character(state$pending_capacity),
      instrument_id = character(state$pending_capacity),
      side = character(state$pending_capacity),
      qty = numeric(state$pending_capacity),
      price = numeric(state$pending_capacity),
      fee = numeric(state$pending_capacity),
      meta_json = character(state$pending_capacity),
      event_seq = integer(state$pending_capacity)
    )
  }

  ensure_capacity <- function(required) {
    nc <- next_capacity(state$pending_capacity, required, state$pending_max_events)
    if (!is.null(state$pending_cols) && nc <= state$pending_capacity) return(invisible(TRUE))
    old_cols <- state$pending_cols
    old_count <- state$pending_idx
    init_pending_cols(nc)
    if (!is.null(old_cols) && old_count > 0L) {
      idx <- seq_len(old_count)
      for (name in names(old_cols)) {
        state$pending_cols[[name]][idx] <- old_cols[[name]][idx]
      }
    }
  }

  init_pending_cols(1024L)

  append <- function(row) {
    i <- state$pending_idx + 1L
    ensure_capacity(i)
    state$pending_idx <- i
    collapse::setv(state$pending_cols$event_id, i, row$event_id, vind1 = TRUE)
    collapse::setv(state$pending_cols$run_id, i, row$run_id, vind1 = TRUE)
    collapse::setv(state$pending_cols$ts_utc, i, row$ts_utc, vind1 = TRUE)
    collapse::setv(state$pending_cols$event_type, i, row$event_type, vind1 = TRUE)
    collapse::setv(state$pending_cols$instrument_id, i, row$instrument_id, vind1 = TRUE)
    collapse::setv(state$pending_cols$side, i, row$side, vind1 = TRUE)
    collapse::setv(state$pending_cols$qty, i, as.numeric(row$qty), vind1 = TRUE)
    collapse::setv(state$pending_cols$price, i, as.numeric(row$price), vind1 = TRUE)
    collapse::setv(state$pending_cols$fee, i, as.numeric(row$fee), vind1 = TRUE)
    collapse::setv(state$pending_cols$meta_json, i, row$meta_json, vind1 = TRUE)
    collapse::setv(state$pending_cols$event_seq, i, as.integer(row$event_seq), vind1 = TRUE)
    invisible(TRUE)
  }

  list(state = state, append = append)
}

# Column-value parity check: both variants produce byte-identical columns
cat("=== column-value parity check ===\n")
hb <- make_handler_baser(1000L)
hs <- make_handler_setv(1000L)
for (k in seq_len(100L)) {
  # Vary the payload so parity actually checks something
  row <- ROW
  row$event_id <- sprintf("run_x_%08d", k)
  row$qty <- as.numeric(k)
  row$event_seq <- as.integer(k)
  hb$append(row)
  hs$append(row)
}
idx <- seq_len(100L)
parity_ok <- TRUE
for (name in names(hb$state$pending_cols)) {
  if (!identical(hb$state$pending_cols[[name]][idx], hs$state$pending_cols[[name]][idx])) {
    cat(sprintf("  PARITY FAIL on column %s\n", name))
    parity_ok <- FALSE
  }
}
cat(sprintf("Result: %s (100 events x 11 columns)\n\n",
            if (parity_ok) "OK - all 11 columns byte-identical" else "FAIL"))
if (!parity_ok) stop("Parity check failed.")

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
        h$append(ROW)
      }
    })[["elapsed"]]
    results <- rbind(results, data.frame(
      accumulated = m,
      interval_elapsed_s = t,
      us_per_event = t / n_to_do * 1e6
    ))
    done <- m
  }
  list(results = results, final_count = h$state$pending_idx,
       final_capacity = h$state$pending_capacity)
}

n_total <- 130000L
interval <- 5000L

cat("=== handler_baser (replica of persistent handler buffer_event) ===\n")
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
cat(sprintf("\nCumulative baser:  %.2fs\n", sum(baser_results$results$interval_elapsed_s)))
cat(sprintf("Cumulative setv :  %.2fs\n", sum(setv_results$results$interval_elapsed_s)))
cat(sprintf("Cumulative delta:  %.2fs (recovery from setv fix on 130k events)\n",
            sum(baser_results$results$interval_elapsed_s) -
            sum(setv_results$results$interval_elapsed_s)))

# Aggregate write to CSV
all_results <- rbind(
  cbind(variant = "handler_baser", baser_results$results),
  cbind(variant = "handler_setv", setv_results$results)
)
out <- "dev/bench/results/spike_persistent_handler_buffer.csv"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(all_results, out, row.names = FALSE)
cat(sprintf("\nWROTE %s\n", out))
