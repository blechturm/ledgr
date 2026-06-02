## Spike 12 (LDG-2516) - Fold-Time Lot Accounting vs Reconstruction-Time
##
## Round 2 spike spawned by Codex's adversarial review of the v0.1.8.10
## architecture synthesis. Codex Finding 1: Ticket 1's inline lot-state
## capture is NOT additive (no lot machinery runs in the fold today); it is
## a semantic move of FIFO lot accounting INTO the fold path. If the
## moved work costs as much as the eliminated reconstruction work, there
## is no net wall recovery.
##
## Question: does moving lot accounting from the reconstruction pass into
## the fold engine actually save wall on the same events?
##
## Codex also measured max open lot depth = 1 on real peer SMA production
## fills (post-v0.1.8.9). Spike 10's random-BUY/SELL fixture matched this
## shape accidentally; the synthesis caveat that "production has deeper
## lots" was not supported for the cited workload. This spike measures BOTH
## a shallow-depth fixture (SMA-like alternating, matching Codex's peer
## evidence) AND a deeper-depth fixture (long-accumulate strategy) to bound
## the recovery range.

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

## ---- Variant A: reconstruction-time lot replay (production today) ----
##
## Reconstruction parses meta_json per event (typed-meta fast path skips
## this; untyped path pays it) and calls ledgr_lot_apply_event with the
## parsed meta dict. We model the realistic production case where some
## events arrive with meta_json strings and the reconstruction has to
## parse them.

variant_a_reconstruction_with_meta_parse <- function(events, instrument_ids) {
  n_events <- nrow(events)
  state <- ledgr_lot_state(instrument_ids)
  event_realized <- numeric(n_events)
  event_cost_basis <- numeric(n_events)
  for (i in seq_len(n_events)) {
    event_type <- as.character(events$event_type[[i]])
    inst <- as.character(events$instrument_id[[i]])
    side <- as.character(events$side[[i]])
    qty <- suppressWarnings(as.numeric(events$qty[[i]]))
    price <- suppressWarnings(as.numeric(events$price[[i]]))
    fee <- suppressWarnings(as.numeric(events$fee[[i]]))
    meta_json <- events$meta_json[[i]]
    meta <- if (is.na(meta_json) || !nzchar(meta_json)) NULL
            else tryCatch(ledgr:::ledgr_json_read_nested(meta_json),
                          error = function(e) NULL)
    lot_res <- ledgr_lot_apply_event(
      state,
      event_type = event_type,
      instrument_id = inst,
      side = side, qty = qty, price = price, fee = fee,
      meta = meta
    )
    state <- lot_res$state
    event_realized[[i]] <- state$realized_pnl
    event_cost_basis[[i]] <- state$total_cost_basis
  }
  list(event_realized = event_realized, event_cost_basis = event_cost_basis)
}

## ---- Variant B: fold-time lot accounting (simple move) ----
##
## What Ticket 1 would actually do: call ledgr_lot_apply_event during the
## fold per fill, with typed inputs already available (no meta_json parse).
## The non-FILL events (CASHFLOW seeds) get applied at fold setup, not
## per-event, so the per-fill loop only handles FILL events.
##
## Same lot machinery, same per-call dispatch overhead, just no JSON parse.

variant_b_fold_time_simple <- function(events, instrument_ids) {
  n_events <- nrow(events)
  state <- ledgr_lot_state(instrument_ids)
  event_realized <- numeric(n_events)
  event_cost_basis <- numeric(n_events)
  for (i in seq_len(n_events)) {
    event_type <- as.character(events$event_type[[i]])
    inst <- as.character(events$instrument_id[[i]])
    side <- as.character(events$side[[i]])
    qty <- as.numeric(events$qty[[i]])
    price <- as.numeric(events$price[[i]])
    fee <- as.numeric(events$fee[[i]])
    ## NO meta parse -- fold has typed values directly
    lot_res <- ledgr_lot_apply_event(
      state,
      event_type = event_type,
      instrument_id = inst,
      side = side, qty = qty, price = price, fee = fee,
      meta = NULL
    )
    state <- lot_res$state
    event_realized[[i]] <- state$realized_pnl
    event_cost_basis[[i]] <- state$total_cost_basis
  }
  list(event_realized = event_realized, event_cost_basis = event_cost_basis)
}

## ---- Variant C: fold-time lot accounting, direct apply_fill ----
##
## Skip the ledgr_lot_apply_event dispatcher; call ledgr_lot_apply_fill
## directly for FILL events. Saves the dispatch + event_type check
## overhead per event.

variant_c_fold_time_direct_fill <- function(events, instrument_ids) {
  n_events <- nrow(events)
  state <- ledgr_lot_state(instrument_ids)
  event_realized <- numeric(n_events)
  event_cost_basis <- numeric(n_events)
  for (i in seq_len(n_events)) {
    inst <- as.character(events$instrument_id[[i]])
    side <- as.character(events$side[[i]])
    qty <- as.numeric(events$qty[[i]])
    price <- as.numeric(events$price[[i]])
    fee <- as.numeric(events$fee[[i]])
    lot_res <- ledgr:::ledgr_lot_apply_fill(
      state,
      instrument_id = inst,
      side = side, qty = qty, price = price, fee = fee
    )
    state <- lot_res$state
    event_realized[[i]] <- state$realized_pnl
    event_cost_basis[[i]] <- state$total_cost_basis
  }
  list(event_realized = event_realized, event_cost_basis = event_cost_basis)
}

## ---- Fixtures ----
##
## Shallow-depth (matches Codex's measurement on real peer SMA fills):
##   alternating BUY then SELL on each instrument; max open lot depth = 1.
##
## Deep-depth (upward bound):
##   long-accumulate; BUYs build to depth, SELLs close from FIFO front.
##   Approximates a buy-and-hold-then-rebalance strategy.

make_shallow_events <- function(n_inst, n_fills) {
  ## alternating BUY/SELL pattern per instrument
  ev_inst_idx <- rep(seq_len(n_inst), length.out = n_fills)
  ev_side <- ifelse(seq_len(n_fills) %% 2L == 0L, "SELL", "BUY")
  ev_qty <- as.numeric(rep(10L, n_fills))
  ev_price <- 100 + rnorm(n_fills, 0, 0.5)
  events <- data.frame(
    event_seq = seq_len(n_fills),
    event_type = "FILL",
    instrument_id = sprintf("INST%04d", ev_inst_idx),
    side = ev_side,
    qty = ev_qty,
    price = ev_price,
    fee = 0.5,
    meta_json = NA_character_,
    stringsAsFactors = FALSE
  )
  ## attach realistic meta_json (cash/position deltas) for Variant A's
  ## JSON-parse path. The fold already has typed values so Variants B/C
  ## skip this.
  events$meta_json <- vapply(seq_len(n_fills), function(k) {
    ledgr:::canonical_json(list(
      cash_delta = if (events$side[[k]] == "BUY")
        -events$qty[[k]] * events$price[[k]] - events$fee[[k]]
        else events$qty[[k]] * events$price[[k]] - events$fee[[k]],
      position_delta = if (events$side[[k]] == "BUY")
        events$qty[[k]] else -events$qty[[k]],
      realized_pnl = NULL
    ))
  }, character(1))
  list(events = events, instrument_ids = sprintf("INST%04d", seq_len(n_inst)))
}

make_deep_events <- function(n_inst, n_fills) {
  ## long-accumulate: 3 BUYs then 1 SELL per instrument, repeating.
  ## Average lot depth grows toward ~2-3 over the run.
  ev_inst_idx <- rep(seq_len(n_inst), length.out = n_fills)
  ev_side <- ifelse(seq_len(n_fills) %% 4L == 0L, "SELL", "BUY")
  ev_qty <- as.numeric(rep(10L, n_fills))
  ev_price <- 100 + rnorm(n_fills, 0, 0.5)
  events <- data.frame(
    event_seq = seq_len(n_fills),
    event_type = "FILL",
    instrument_id = sprintf("INST%04d", ev_inst_idx),
    side = ev_side,
    qty = ev_qty,
    price = ev_price,
    fee = 0.5,
    meta_json = NA_character_,
    stringsAsFactors = FALSE
  )
  events$meta_json <- vapply(seq_len(n_fills), function(k) {
    ledgr:::canonical_json(list(
      cash_delta = if (events$side[[k]] == "BUY")
        -events$qty[[k]] * events$price[[k]] - events$fee[[k]]
        else events$qty[[k]] * events$price[[k]] - events$fee[[k]],
      position_delta = if (events$side[[k]] == "BUY")
        events$qty[[k]] else -events$qty[[k]],
      realized_pnl = NULL
    ))
  }, character(1))
  list(events = events, instrument_ids = sprintf("INST%04d", seq_len(n_inst)))
}

## ---- Helper: measure max open lot depth (verify fixture matches intent) ----

measure_max_lot_depth <- function(events, instrument_ids) {
  state <- ledgr_lot_state(instrument_ids)
  max_depth <- 0L
  for (i in seq_len(nrow(events))) {
    lot_res <- ledgr_lot_apply_event(
      state,
      event_type = events$event_type[[i]],
      instrument_id = events$instrument_id[[i]],
      side = events$side[[i]],
      qty = events$qty[[i]],
      price = events$price[[i]],
      fee = events$fee[[i]],
      meta = NULL
    )
    state <- lot_res$state
    for (lots in state$lots) {
      d <- length(lots)
      if (d > max_depth) max_depth <- d
    }
  }
  max_depth
}

## ---- Sweep ----

scales <- list(
  list(n_inst = 500L,  n_fills = 68324L, label = "68k"),
  list(n_inst = 1000L, n_fills = 130000L, label = "130k")
)

results <- list()
for (fixture_name in c("shallow", "deep")) {
  cat(sprintf("\n========== Fixture: %s ==========\n", fixture_name))
  for (k in seq_along(scales)) {
    sc <- scales[[k]]
    cat(sprintf("\n[%s/%s] n_inst=%d n_fills=%d\n",
                fixture_name, sc$label, sc$n_inst, sc$n_fills))
    fx <- if (fixture_name == "shallow")
            make_shallow_events(sc$n_inst, sc$n_fills)
          else
            make_deep_events(sc$n_inst, sc$n_fills)

    max_depth <- measure_max_lot_depth(fx$events[1:min(2000L, nrow(fx$events)), ],
                                       fx$instrument_ids)
    cat(sprintf("  Max open lot depth (first 2k events): %d\n", max_depth))

    a <- bench_repeated(
      function() variant_a_reconstruction_with_meta_parse(fx$events, fx$instrument_ids),
      n_reps = 2L)
    b <- bench_repeated(
      function() variant_b_fold_time_simple(fx$events, fx$instrument_ids),
      n_reps = 2L)
    c <- bench_repeated(
      function() variant_c_fold_time_direct_fill(fx$events, fx$instrument_ids),
      n_reps = 2L)

    ## Parity: realized_pnl + cost_basis vectors identical
    pa <- variant_a_reconstruction_with_meta_parse(fx$events, fx$instrument_ids)
    pb <- variant_b_fold_time_simple(fx$events, fx$instrument_ids)
    pc <- variant_c_fold_time_direct_fill(fx$events, fx$instrument_ids)
    parity_ab_realized <- isTRUE(all.equal(pa$event_realized, pb$event_realized, tolerance = 1e-9))
    parity_ac_realized <- isTRUE(all.equal(pa$event_realized, pc$event_realized, tolerance = 1e-9))
    parity_ab_basis <- isTRUE(all.equal(pa$event_cost_basis, pb$event_cost_basis, tolerance = 1e-9))
    parity_ac_basis <- isTRUE(all.equal(pa$event_cost_basis, pc$event_cost_basis, tolerance = 1e-9))

    savings_b <- a$median - b$median
    savings_c <- a$median - c$median
    pct_savings_b <- savings_b / a$median * 100
    pct_savings_c <- savings_c / a$median * 100

    cat(sprintf("  VarA (recon + meta parse): %.3fs (%.2f us/event)\n",
                a$median, a$median * 1e6 / sc$n_fills))
    cat(sprintf("  VarB (fold-time simple)  : %.3fs (%.2f us/event, savings %.3fs = %.1f%%)\n",
                b$median, b$median * 1e6 / sc$n_fills, savings_b, pct_savings_b))
    cat(sprintf("  VarC (fold-time direct)  : %.3fs (%.2f us/event, savings %.3fs = %.1f%%)\n",
                c$median, c$median * 1e6 / sc$n_fills, savings_c, pct_savings_c))
    cat(sprintf("  Parity realized A==B: %s, A==C: %s\n",
                if (parity_ab_realized) "PASS" else "FAIL",
                if (parity_ac_realized) "PASS" else "FAIL"))
    cat(sprintf("  Parity cost_basis A==B: %s, A==C: %s\n",
                if (parity_ab_basis) "PASS" else "FAIL",
                if (parity_ac_basis) "PASS" else "FAIL"))

    results[[length(results) + 1L]] <- list(
      fixture = fixture_name,
      scale = sc$label, n_inst = sc$n_inst, n_fills = sc$n_fills,
      max_depth = max_depth,
      a_median = a$median, b_median = b$median, c_median = c$median,
      savings_b = savings_b, savings_c = savings_c,
      pct_savings_b = pct_savings_b, pct_savings_c = pct_savings_c,
      parity_ab_realized = parity_ab_realized,
      parity_ac_realized = parity_ac_realized,
      parity_ab_basis = parity_ab_basis,
      parity_ac_basis = parity_ac_basis
    )
    rm(fx, pa, pb, pc); gc(FALSE)
  }
}

cat("\n\n========== SPIKE 12 SUMMARY ==========\n")
cat(sprintf("%-8s %-6s %8s %8s %8s %8s %8s %8s\n",
            "fixture", "scale", "n_fills", "depth",
            "VarA_s", "VarB_s", "VarC_s", "B_save%"))
for (r in results) {
  cat(sprintf("%-8s %-6s %8d %8d %8.3f %8.3f %8.3f %7.1f%%\n",
              r$fixture, r$scale, r$n_fills, r$max_depth,
              r$a_median, r$b_median, r$c_median, r$pct_savings_b))
}

cat("\nDecision rule:\n")
cat("  VarB savings > 50%% at xlarge -> simple PROCEED\n")
cat("  VarC savings > 80%% at xlarge -> optimized PROCEED (skip dispatcher)\n")
cat("  Neither > 30%% -> PARK lot-state migration, ship inline equity only\n")

xlarge_shallow <- results[[which(vapply(results,
  function(r) r$fixture == "shallow" && r$scale == "130k",
  logical(1)))]]
xlarge_deep <- results[[which(vapply(results,
  function(r) r$fixture == "deep" && r$scale == "130k",
  logical(1)))]]

cat(sprintf("\nAt xlarge (130k events):\n"))
cat(sprintf("  Shallow (depth=%d): VarB %.1f%% savings, VarC %.1f%% savings\n",
            xlarge_shallow$max_depth,
            xlarge_shallow$pct_savings_b, xlarge_shallow$pct_savings_c))
cat(sprintf("  Deep    (depth=%d): VarB %.1f%% savings, VarC %.1f%% savings\n",
            xlarge_deep$max_depth,
            xlarge_deep$pct_savings_b, xlarge_deep$pct_savings_c))

res_df <- do.call(rbind, lapply(results, function(r) data.frame(
  fixture = r$fixture, scale = r$scale, n_inst = r$n_inst,
  n_fills = r$n_fills, max_depth = r$max_depth,
  variant_a_s = r$a_median, variant_b_s = r$b_median, variant_c_s = r$c_median,
  savings_b_s = r$savings_b, savings_c_s = r$savings_c,
  pct_savings_b = r$pct_savings_b, pct_savings_c = r$pct_savings_c,
  parity_ab_realized = r$parity_ab_realized,
  parity_ac_realized = r$parity_ac_realized,
  parity_ab_basis = r$parity_ab_basis,
  parity_ac_basis = r$parity_ac_basis,
  stringsAsFactors = FALSE
)))
out_csv <- "c:/Users/maxth/Documents/GitHub/ledgr/dev/bench/results/spike_fold_time_lot_accounting.csv"
write.csv(res_df, out_csv, row.names = FALSE)
cat(sprintf("\nResults written to %s\n", out_csv))
