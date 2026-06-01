# Spike: ledgr_fills_from_events() scaling at production fill counts
#
# Context: LDG-2479 grid showed `ledgr_results(bt, "fills")` is super-linear:
# 6.75s at 13k fills, 82.28s at 68k fills (13.5x slower for 5.1x more
# fills). v0.1.8.7 Batch 6 (Lane C) already rewrote `ledgr_fills_from_events`
# to use a primitive-column buffer + .subset2 reads, eliminating the
# list-of-data.frames + rbind anti-pattern. So the super-linearity must be
# elsewhere.
#
# Hypothesis candidates inside the post-Lane-C path
# (R/fold-reconstruction.R:255-360 and R/lot-accounting.R):
#   1. ledgr_lot_apply_event per-event lot machinery (O(n_lots) per fill)
#   2. data.frame row subsetting / order() at large N
#   3. .subset2 column reads OK but type conversion (as.numeric/as.character)
#      per iteration
#   4. ledgr_event_meta_at + ledgr_typed_event_metadata lookups
#   5. ledgr_lot_set's call to ledgr_lot_basis on lot updates
#
# FAITHFULNESS: uses ledgr:::ledgr_fills_from_events directly via
# pkgload::load_all so the production code path is exercised, not a replica.
# Synthetic events table is constructed to match the LDG-2479 SMA 5/10
# crossover pattern: alternating BUY/SELL fills per instrument so lots
# close cleanly (net-flat at end of each crossover pair).
#
# Test scales: 13.5k, 30k, 68.5k, 130k fills (matching grid cells).
# Held constant: n_inst = 500. Varied: fills_per_inst.
#
# CAVEAT: synthetic events use simplified meta_json. Production events
# carry more metadata which may affect parsing cost. The scaling signature
# (linear vs super-linear) is the load-bearing claim; absolute seconds
# may differ from production.
#
# Usage:
#   Rscript dev/spikes/spike-fills-reconstruction-scaling.R

suppressWarnings(suppressMessages({
  if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("pkgload is required to load ledgr internals for the spike.")
  }
  pkgload::load_all(".", quiet = TRUE)
}))

mk_events <- function(n_inst, fills_per_inst, seed = 42L) {
  set.seed(seed)
  n_fills <- n_inst * fills_per_inst
  ids <- sprintf("INST_%05d", seq_len(n_inst))
  # Build events: each instrument has fills_per_inst alternating BUY/SELL
  # fills at monotonically increasing timestamps.
  rows <- vector("list", n_inst)
  base_ts <- as.POSIXct("2026-01-01 00:00:00", tz = "UTC")
  for (j in seq_len(n_inst)) {
    inst <- ids[[j]]
    n_f <- fills_per_inst
    sides <- rep(c("BUY", "SELL"), length.out = n_f)
    # Stagger timestamps within instrument; cross instruments randomly.
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
  # Global ordering by ts then by instrument (mimics event ordering by
  # event_seq in production).
  df <- df[order(df$ts_utc, df$instrument_id), , drop = FALSE]
  df$event_seq <- seq_len(nrow(df))
  df$event_id <- sprintf("run_x_%08d", df$event_seq)
  df$run_id <- "run_x"
  df$event_type <- "FILL"
  df$meta_json <- sprintf('{"cash_delta":%g,"position_delta":%g,"realized_pnl":null}',
                           ifelse(df$side == "BUY", -df$price, df$price),
                           ifelse(df$side == "BUY", 1, -1))
  df <- df[, c("event_id", "run_id", "ts_utc", "event_type", "instrument_id",
               "side", "qty", "price", "fee", "meta_json", "event_seq")]
  df
}

run_spike <- function() {
  shapes <- list(
    list(n_inst = 500L, fills_per_inst = 27L),   # ~13.5k
    list(n_inst = 500L, fills_per_inst = 60L),   # ~30k
    list(n_inst = 500L, fills_per_inst = 137L),  # ~68.5k
    list(n_inst = 500L, fills_per_inst = 260L)   # ~130k
  )

  cat("=== timing ledgr:::ledgr_fills_from_events ===\n")
  cat(sprintf("%-7s %-8s | %9s %12s | %s\n",
              "n_inst", "n_fills", "wall_s", "us_per_fill", "output_rows"))

  res <- list()
  for (s in shapes) {
    events <- mk_events(s$n_inst, s$fills_per_inst)
    n_fills <- nrow(events)

    t <- system.time({
      out <- ledgr:::ledgr_fills_from_events(events)
    })[["elapsed"]]

    n_out <- if (is.null(out)) 0L else nrow(out)
    cat(sprintf("%-7d %-8d | %8.3fs %12.1f | %d output rows\n",
                s$n_inst, n_fills, t, t / n_fills * 1e6, n_out))

    res[[length(res) + 1L]] <- data.frame(
      n_inst = s$n_inst, fills_per_inst = s$fills_per_inst, n_fills = n_fills,
      wall_s = t, us_per_fill = t / n_fills * 1e6, n_output_rows = n_out
    )
  }

  res_df <- do.call(rbind, res)

  # Scaling diagnostic
  cat("\n=== scaling diagnostic ===\n")
  cat("If linear: per-fill cost should be flat across scales.\n")
  cat("If super-linear: per-fill cost grows with n_fills.\n\n")
  baseline_us <- res_df$us_per_fill[[1]]
  for (i in seq_len(nrow(res_df))) {
    r <- res_df[i, ]
    cat(sprintf("  n_fills = %6d : %7.1f us/fill (%.2fx baseline)\n",
                r$n_fills, r$us_per_fill, r$us_per_fill / baseline_us))
  }

  # Rprof at the largest scale to find the hot spot
  cat("\n=== Rprof on largest cell (130k fills) ===\n")
  events <- mk_events(500L, 260L)
  prof_file <- tempfile(fileext = ".out")
  Rprof(prof_file, interval = 0.005, line.profiling = TRUE)
  out <- ledgr:::ledgr_fills_from_events(events)
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

  out_csv <- "dev/bench/results/spike_fills_reconstruction_scaling.csv"
  dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(res_df, out_csv, row.names = FALSE)
  cat(sprintf("\nWROTE %s\n", out_csv))

  unlink(prof_file)
}

run_spike()
