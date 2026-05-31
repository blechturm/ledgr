# Spike: ledgr_equity_from_events() scaling at production fill counts
#
# Context: LDG-2476 three-phase decomposition showed ephemeral ledgr's
# results phase is +40.9s vs durable at 68k fills.
# ledgr_equity_from_events() is one of the two reconstruction functions
# the ephemeral path uses (the other is ledgr_fills_from_events covered
# by Spike 7). Hypothesis: super-linear scaling driven by per-event lot
# machinery + per-event meta lookups, similar to Spike 7.
#
# FAITHFULNESS: uses ledgr:::ledgr_equity_from_events directly via
# pkgload::load_all. Synthetic events table matches Spike 7's shape.
# pulses_posix and close_mat are constructed to span the events.
#
# Test scales: 13.5k, 30k, 68.5k, 130k fills.
# Held constant: n_inst = 500, n_pulses = 1260.
#
# CAVEAT: synthetic events use simplified meta_json. The scaling signature
# is the load-bearing claim.
#
# Usage:
#   Rscript dev/spikes/spike-event-stream-reconstruction.R

suppressWarnings(suppressMessages({
  if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("pkgload is required to load ledgr internals for the spike.")
  }
  pkgload::load_all(".", quiet = TRUE)
}))

mk_events <- function(n_inst, fills_per_inst, seed = 42L) {
  set.seed(seed)
  ids <- sprintf("INST_%05d", seq_len(n_inst))
  rows <- vector("list", n_inst)
  base_ts <- as.POSIXct("2026-01-01 00:00:00", tz = "UTC")
  for (j in seq_len(n_inst)) {
    inst <- ids[[j]]
    n_f <- fills_per_inst
    sides <- rep(c("BUY", "SELL"), length.out = n_f)
    ts <- base_ts + (seq_len(n_f) - 1L) * 86400L + (j - 1L)
    rows[[j]] <- data.frame(
      ts_utc = ts,
      instrument_id = rep(inst, n_f),
      side = sides,
      qty = rep(1, n_f),
      price = runif(n_f, 90, 110),
      fee = rep(0, n_f),
      stringsAsFactors = FALSE
    )
  }
  df <- do.call(rbind, rows)
  df <- df[order(df$ts_utc, df$instrument_id), , drop = FALSE]
  df$event_seq <- seq_len(nrow(df))
  df$event_id <- sprintf("run_x_%08d", df$event_seq)
  df$run_id <- "run_x"
  df$event_type <- "FILL"
  df$meta_json <- sprintf('{"cash_delta":%g,"position_delta":%g,"realized_pnl":null}',
                           ifelse(df$side == "BUY", -df$price, df$price),
                           ifelse(df$side == "BUY", 1, -1))
  df[, c("event_id", "run_id", "ts_utc", "event_type", "instrument_id",
         "side", "qty", "price", "fee", "meta_json", "event_seq")]
}

mk_pulses_and_close <- function(events, n_inst, n_pulses) {
  # Pulses span the event ts range plus a buffer.
  ts_range <- range(events$ts_utc)
  pulse_dt <- (as.numeric(ts_range[[2L]]) - as.numeric(ts_range[[1L]])) / n_pulses
  if (pulse_dt <= 0) pulse_dt <- 86400
  pulses_posix <- ts_range[[1L]] + seq(0, by = pulse_dt, length.out = n_pulses)
  close_mat <- matrix(runif(n_inst * n_pulses, 90, 110),
                     nrow = n_inst, ncol = n_pulses)
  list(pulses_posix = pulses_posix, close_mat = close_mat)
}

run_spike <- function() {
  shapes <- list(
    list(n_inst = 500L, fills_per_inst = 27L),
    list(n_inst = 500L, fills_per_inst = 60L),
    list(n_inst = 500L, fills_per_inst = 137L),
    list(n_inst = 500L, fills_per_inst = 260L)
  )
  n_pulses <- 1260L

  cat("=== timing ledgr:::ledgr_equity_from_events ===\n")
  cat(sprintf("%-7s %-8s | %9s %12s | %s\n",
              "n_inst", "n_fills", "wall_s", "us_per_fill", "output_rows"))

  res <- list()
  for (s in shapes) {
    events <- mk_events(s$n_inst, s$fills_per_inst)
    n_fills <- nrow(events)
    instrument_ids <- sprintf("INST_%05d", seq_len(s$n_inst))
    pc <- mk_pulses_and_close(events, s$n_inst, n_pulses)

    t <- system.time({
      out <- ledgr:::ledgr_equity_from_events(
        events = events,
        pulses_posix = pc$pulses_posix,
        close_mat = pc$close_mat,
        initial_cash = 1e7,
        instrument_ids = instrument_ids,
        run_id = "run_x"
      )
    })[["elapsed"]]

    n_out <- if (is.null(out)) 0L else nrow(out)
    cat(sprintf("%-7d %-8d | %8.3fs %12.1f | %d equity rows\n",
                s$n_inst, n_fills, t, t / n_fills * 1e6, n_out))

    res[[length(res) + 1L]] <- data.frame(
      n_inst = s$n_inst, fills_per_inst = s$fills_per_inst, n_fills = n_fills,
      wall_s = t, us_per_fill = t / n_fills * 1e6, n_output_rows = n_out
    )
  }

  res_df <- do.call(rbind, res)

  cat("\n=== scaling diagnostic ===\n")
  cat("If linear: per-fill cost should be flat across scales.\n")
  cat("If super-linear: per-fill cost grows with n_fills.\n\n")
  baseline_us <- res_df$us_per_fill[[1]]
  for (i in seq_len(nrow(res_df))) {
    r <- res_df[i, ]
    cat(sprintf("  n_fills = %6d : %7.1f us/fill (%.2fx baseline)\n",
                r$n_fills, r$us_per_fill, r$us_per_fill / baseline_us))
  }

  # Rprof at the largest scale
  cat("\n=== Rprof on largest cell (130k fills) ===\n")
  events <- mk_events(500L, 260L)
  instrument_ids <- sprintf("INST_%05d", seq_len(500L))
  pc <- mk_pulses_and_close(events, 500L, n_pulses)

  prof_file <- tempfile(fileext = ".out")
  Rprof(prof_file, interval = 0.005, line.profiling = TRUE)
  out <- ledgr:::ledgr_equity_from_events(
    events = events,
    pulses_posix = pc$pulses_posix,
    close_mat = pc$close_mat,
    initial_cash = 1e7,
    instrument_ids = instrument_ids,
    run_id = "run_x"
  )
  Rprof(NULL)
  summ <- summaryRprof(prof_file, lines = "both")

  cat("\n--- top 15 by self.time ---\n")
  print(head(summ$by.self[order(-summ$by.self$self.time), ], 15L))

  cat("\n--- top 15 by total.time ---\n")
  print(head(summ$by.total[order(-summ$by.total$total.time), ], 15L))

  cat("\n--- top 15 by line ---\n")
  if (!is.null(summ$by.line)) {
    bl <- summ$by.line[order(-summ$by.line$self.time), ]
    print(head(bl, 15L))
  } else {
    cat("(by-line profile not available)\n")
  }

  out_csv <- "dev/bench/results/spike_event_stream_reconstruction.csv"
  dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(res_df, out_csv, row.names = FALSE)
  cat(sprintf("\nWROTE %s\n", out_csv))

  unlink(prof_file)
}

run_spike()
