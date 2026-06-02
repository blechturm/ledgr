## Spike 2 (LDG-2506) - split() / gsplit() Reconstruction Bucket
##
## Question: standalone wall recovery from replacing the per-instrument
## `which(events$instrument_id == id)` loop at
## R/fold-reconstruction.R:514-526 with a single-pass bucket operation.
## Compare base R `split()` against `collapse::gsplit()`.
##
## Mechanism: current loop runs O(n_inst x n_events) character-equality
## comparisons just to bucket events by instrument. At 1000 inst x 130k
## events that's 130M comparisons. Bucket-once via split() or
## collapse::gsplit() reduces to O(n_events) hash + O(n_inst) lookup.
##
## This spike is a fallback measurement for the case where Spike 1
## (LDG-2505) doesn't reach the decision threshold. Spike 1 eliminates
## the reconstruction pass entirely; Spike 2 only optimizes the bucket.

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

## ---- Isolate the per-instrument bucket loop ----
##
## Reproduce the exact production logic at R/fold-reconstruction.R:512-526
## then test alternative bucket strategies. All variants produce the same
## positions_mat output.

variant_a_current <- function(events, instrument_ids, position_delta,
                              event_ts_num, pulse_ts_num, n_pulses) {
  n_inst <- length(instrument_ids)
  positions_mat <- matrix(0, nrow = n_inst, ncol = n_pulses)
  for (j in seq_along(instrument_ids)) {
    id <- instrument_ids[[j]]
    ev_idx <- which(events$instrument_id == id)
    if (length(ev_idx) == 0L) next
    pos_cum <- cumsum(position_delta[ev_idx])
    idx_inst <- findInterval(pulse_ts_num, event_ts_num[ev_idx])
    has_inst_event <- idx_inst > 0L
    if (any(has_inst_event)) {
      positions_mat[j, has_inst_event] <- pos_cum[idx_inst[has_inst_event]]
    }
  }
  positions_mat
}

variant_b_base_split <- function(events, instrument_ids, position_delta,
                                 event_ts_num, pulse_ts_num, n_pulses) {
  n_inst <- length(instrument_ids)
  positions_mat <- matrix(0, nrow = n_inst, ncol = n_pulses)
  buckets <- split(seq_along(events$instrument_id),
                   factor(events$instrument_id, levels = instrument_ids))
  for (j in seq_along(instrument_ids)) {
    ev_idx <- buckets[[j]]
    if (length(ev_idx) == 0L) next
    pos_cum <- cumsum(position_delta[ev_idx])
    idx_inst <- findInterval(pulse_ts_num, event_ts_num[ev_idx])
    has_inst_event <- idx_inst > 0L
    if (any(has_inst_event)) {
      positions_mat[j, has_inst_event] <- pos_cum[idx_inst[has_inst_event]]
    }
  }
  positions_mat
}

variant_c_collapse_gsplit <- function(events, instrument_ids, position_delta,
                                      event_ts_num, pulse_ts_num, n_pulses) {
  n_inst <- length(instrument_ids)
  positions_mat <- matrix(0, nrow = n_inst, ncol = n_pulses)
  inst_factor <- factor(events$instrument_id, levels = instrument_ids)
  buckets <- collapse::gsplit(seq_along(events$instrument_id), inst_factor)
  for (j in seq_along(instrument_ids)) {
    ev_idx <- buckets[[j]]
    if (length(ev_idx) == 0L) next
    pos_cum <- cumsum(position_delta[ev_idx])
    idx_inst <- findInterval(pulse_ts_num, event_ts_num[ev_idx])
    has_inst_event <- idx_inst > 0L
    if (any(has_inst_event)) {
      positions_mat[j, has_inst_event] <- pos_cum[idx_inst[has_inst_event]]
    }
  }
  positions_mat
}

## ---- Fixture ----
make_fixture <- function(n_inst, n_pulses, n_fills) {
  pulses_posix <- as.POSIXct("2020-01-01", tz = "UTC") +
    as.difftime(seq_len(n_pulses) - 1L, units = "days")
  instrument_ids <- sprintf("INST%04d", seq_len(n_inst))
  ev_pulse_idx <- sort(sample.int(n_pulses, n_fills, replace = TRUE))
  events <- data.frame(
    instrument_id = instrument_ids[sample.int(n_inst, n_fills, replace = TRUE)],
    ts_utc = pulses_posix[ev_pulse_idx],
    stringsAsFactors = FALSE
  )
  position_delta <- ifelse(seq_len(n_fills) %% 2L == 0L, 1, -1)
  list(
    events = events,
    instrument_ids = instrument_ids,
    position_delta = position_delta,
    event_ts_num = as.numeric(events$ts_utc),
    pulse_ts_num = as.numeric(pulses_posix),
    n_pulses = n_pulses,
    n_inst = n_inst,
    n_fills = n_fills
  )
}

## ---- Sweep ----
scales <- list(
  list(n_inst = 100L,  n_pulses = 1260L, n_fills = 13355L, label = "13.5k"),
  list(n_inst = 300L,  n_pulses = 1260L, n_fills = 30000L, label = "30k"),
  list(n_inst = 500L,  n_pulses = 1260L, n_fills = 68324L, label = "68k"),
  list(n_inst = 1000L, n_pulses = 1260L, n_fills = 130000L, label = "130k")
)

results <- vector("list", length(scales))
for (k in seq_along(scales)) {
  sc <- scales[[k]]
  cat(sprintf("\n[scale %s] n_inst=%d n_pulses=%d n_fills=%d\n",
              sc$label, sc$n_inst, sc$n_pulses, sc$n_fills))
  fx <- make_fixture(sc$n_inst, sc$n_pulses, sc$n_fills)

  ## Time each variant 3 reps
  a <- bench_repeated(function() {
    variant_a_current(fx$events, fx$instrument_ids, fx$position_delta,
                       fx$event_ts_num, fx$pulse_ts_num, fx$n_pulses)
  })
  b <- bench_repeated(function() {
    variant_b_base_split(fx$events, fx$instrument_ids, fx$position_delta,
                         fx$event_ts_num, fx$pulse_ts_num, fx$n_pulses)
  })
  c <- bench_repeated(function() {
    variant_c_collapse_gsplit(fx$events, fx$instrument_ids, fx$position_delta,
                              fx$event_ts_num, fx$pulse_ts_num, fx$n_pulses)
  })

  ## Parity gate: all three variants produce identical positions_mat
  mat_a <- variant_a_current(fx$events, fx$instrument_ids, fx$position_delta,
                              fx$event_ts_num, fx$pulse_ts_num, fx$n_pulses)
  mat_b <- variant_b_base_split(fx$events, fx$instrument_ids, fx$position_delta,
                                fx$event_ts_num, fx$pulse_ts_num, fx$n_pulses)
  mat_c <- variant_c_collapse_gsplit(fx$events, fx$instrument_ids, fx$position_delta,
                                     fx$event_ts_num, fx$pulse_ts_num, fx$n_pulses)
  parity_ab <- identical(mat_a, mat_b)
  parity_ac <- identical(mat_a, mat_c)

  cat(sprintf("  Variant A (per-inst which) : median %.4fs\n", a$median))
  cat(sprintf("  Variant B (base split)     : median %.4fs (%.1fx speedup)\n",
              b$median, a$median / b$median))
  cat(sprintf("  Variant C (collapse gsplit): median %.4fs (%.1fx speedup)\n",
              c$median, a$median / c$median))
  cat(sprintf("  Parity A==B: %s, A==C: %s\n",
              if (parity_ab) "PASS" else "FAIL",
              if (parity_ac) "PASS" else "FAIL"))

  results[[k]] <- list(
    scale = sc$label,
    n_inst = sc$n_inst,
    n_pulses = sc$n_pulses,
    n_fills = sc$n_fills,
    a_median = a$median,
    b_median = b$median,
    c_median = c$median,
    a_speedup_b = a$median / b$median,
    a_speedup_c = a$median / c$median,
    parity_ab = parity_ab,
    parity_ac = parity_ac
  )
  rm(fx, mat_a, mat_b, mat_c); gc(FALSE)
}

cat("\n========== SPIKE 2 SUMMARY ==========\n")
cat(sprintf("%-6s %8s %8s %8s %10s %10s %10s %8s %8s\n",
            "scale", "n_inst", "n_pulses", "n_fills",
            "VarA_s", "VarB_s", "VarC_s", "B_sp", "C_sp"))
for (r in results) {
  cat(sprintf("%-6s %8d %8d %8d %10.4f %10.4f %10.4f %7.2fx %7.2fx\n",
              r$scale, r$n_inst, r$n_pulses, r$n_fills,
              r$a_median, r$b_median, r$c_median,
              r$a_speedup_b, r$a_speedup_c))
}
cat("\nVarA = current per-instrument which() loop (production baseline)\n")
cat("VarB = base R split() over factor(instrument_id)\n")
cat("VarC = collapse::gsplit() over factor(instrument_id)\n")

res_df <- do.call(rbind, lapply(results, function(r) data.frame(
  scale = r$scale, n_inst = r$n_inst, n_pulses = r$n_pulses,
  n_fills = r$n_fills,
  variant_a_s = r$a_median, variant_b_s = r$b_median, variant_c_s = r$c_median,
  speedup_b = r$a_speedup_b, speedup_c = r$a_speedup_c,
  parity_ab = r$parity_ab, parity_ac = r$parity_ac,
  stringsAsFactors = FALSE
)))
out_csv <- "c:/Users/maxth/Documents/GitHub/ledgr/dev/bench/results/spike_reconstruction_split_bucket.csv"
write.csv(res_df, out_csv, row.names = FALSE)
cat(sprintf("\nResults written to %s\n", out_csv))
