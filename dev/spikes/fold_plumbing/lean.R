# Lean floor probe: the fold in the proposed lean shape with stages that
# emit their data and do no work, checking only the strategy output.
#
#   Rscript lean.R --pkg=<ledgr source tree at d5b3a151> --out=<dir> [--reps=5]
#
# On each pulse of a recorded tape (tape.R) the stubs
#   P1  emit fresh decision packet, decision data and execution packet;
#       write the equity row;
#   P2  emit a fresh decision; on a decided pulse run the pinned strategy
#       target check (ledgr_validate_strategy_targets) on the strategy's
#       named targets;
#   P3  emit a fresh plan (fills, rejections);
#   P4  write the pulse's fill events straight into reserved event rows;
#   P5  commit the event count and write the pulse's diagnostic rows
#       straight into typed columns.
# Fixed services fields are read as locals. No other check runs. The lean
# fold must reproduce the real events, diagnostic rows and equity exactly.
# Today's skeleton (sim.R, variant `today`) runs interleaved for scale.

local({
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
  entry <- file.path(here, "..", "..", "bench", "v0_2_3_ws16_entry")
  source(file.path(entry, "common.R"))
  source(file.path(entry, "workloads.R"))
  assign("fp_here", here, envir = globalenv())
})
pkg <- normalizePath(ws16_need("pkg"), winslash = "/")
out <- ws16_out(ws16_need("out"))
reps <- as.integer(ws16_arg("reps", "5"))
commit <- ws16_load_source(pkg)
if (!identical(commit, "d5b3a151")) stop("source tree is not the d5b3a151 pin", call. = FALSE)
source(file.path(fp_here, "tape.R"))

work <- file.path(tempdir(), "fold_plumbing_lean")
dir.create(work, showWarnings = FALSE)
fp_install_wrappers()
snapshot <- ws16_momentum_snapshot(40L, 504L, file.path(work, "momentum.duckdb"), "fp_momentum")
exp <- ws16_momentum_experiment(snapshot, 63L)
tapes <- list(momentum_40x504 = fp_capture(function() {
  close(ledgr_run(exp, params = list(lookback = 63L, n = 10L), run_id = "fp-lean-m", seed = 1L))
}))
ledgr_snapshot_close(snapshot)
snapshot <- ledgr_snapshot_from_df(ws16_fill_heavy_bars(), db_path = file.path(work, "fill.duckdb"),
                                   snapshot_id = "fp_fill")
exp <- ws16_fill_heavy_experiment(snapshot)
tapes$fill_heavy_500x1260 <- fp_capture(function() {
  close(suppressWarnings(ledgr_run(exp, run_id = "fp-lean-f", seed = 20260530L)))
})
ledgr_snapshot_close(snapshot)
# Time the pinned functions, not the tape wrappers.
commit <- ws16_load_source(pkg)
source(file.path(fp_here, "sim.R"))
# The restructured strategy check (dev/spikes/strategy_check/arms.R).
source(file.path(fp_here, "..", "strategy_check", "arms.R"))

decision_fields <- names(ledgr:::.ledgr_carrier_fields$decision)
diag_cols <- names(tapes[[1L]]$oracle$diagnostics[[1L]])
diag_time <- c("ts_utc", "decision_ts_utc", "execution_ts_utc")

# Per pulse, the diagnostic rows its stages emit: the pulse's real block.
fp_pulse_blocks <- function(tape) {
  ts <- vapply(tape$pulses, function(p) as.numeric(p$P1$observation$ts), 0)
  by_pulse <- vector("list", length(ts))
  for (b in tape$oracle$diagnostics) {
    i <- match(as.numeric(b$ts_utc[[1L]]), ts)
    by_pulse[[i]] <- c(by_pulse[[i]], list(lapply(b, function(v) if (inherits(v, "POSIXct")) unclass(v) else v)))
  }
  by_pulse
}

fp_diag_store <- function(template, capacity = 4096L) {
  s <- new.env(parent = emptyenv())
  s$cols <- lapply(template, function(v) vector(typeof(v), capacity))
  s$capacity <- capacity
  s$count <- 0L
  s
}

fp_diag_write <- function(s, block) {
  n <- length(block$diagnostic_seq)
  need <- s$count + n
  if (need > s$capacity) {
    cap <- max(2L * s$capacity, need)
    used <- seq_len(s$count)
    s$cols <- lapply(s$cols, function(v) { w <- vector(typeof(v), cap); w[used] <- v[used]; w })
    s$capacity <- cap
  }
  idx <- s$count + seq_len(n)
  for (nm in names(block)) collapse::setv(s$cols[[nm]], idx, block[[nm]], vind1 = TRUE)
  s$count <- need
}

# A stage's output as a real stage builds it: one list() call with a newly
# allocated vector per field (opaque or `keep` fields passed on by reference).
fp_emitter <- function(fields, keep = character()) {
  f <- function(x) NULL
  args <- lapply(fields, function(nm) {
    get <- call("$", as.name("x"), as.name(nm))
    if (nm %in% keep) get else call("c", get)
  })
  names(args) <- fields
  body(f) <- as.call(c(as.name("list"), args))
  f
}

# Fill events into reserved rows; `ids = FALSE` leaves the event ID and run
# ID columns to be formatted at the output boundary instead.
fp_lean_event_write <- function(ev, idx, run_id, fill, i, instrument_id, event_seq, ids = TRUE) {
  if (ids) return(fp_event_write(ev, idx, run_id, fill, i, instrument_id, event_seq))
  seq <- as.integer(event_seq) + seq_along(i) - 1L
  c <- ev$cols
  collapse::setv(c$ts_utc, idx, fill$exec_ts[i], vind1 = TRUE)
  collapse::setv(c$event_type, idx, rep("FILL", length(i)), vind1 = TRUE)
  collapse::setv(c$instrument_id, idx, instrument_id, vind1 = TRUE)
  collapse::setv(c$side, idx, c("SELL", "BUY")[(fill$side[i] > 0L) + 1L], vind1 = TRUE)
  collapse::setv(c$qty, idx, fill$qty[i], vind1 = TRUE)
  collapse::setv(c$price, idx, fill$price[i], vind1 = TRUE)
  collapse::setv(c$fee, idx, fill$fee[i], vind1 = TRUE)
  collapse::setv(c$event_seq, idx, seq, vind1 = TRUE)
  collapse::setv(c$cash_delta, idx, fill$cash_delta[i], vind1 = TRUE)
  collapse::setv(c$position_delta, idx, fill$position_delta[i], vind1 = TRUE)
}

# Options, each removable for the breakdown:
#   copy   stages emit fresh outputs (TRUE) or pass references to data that
#          already exists, the bound for reading prepared data by index;
#   check  "pinned", "fast" (restructured, universe trusted) or "none";
#   fills, ids, diagnostics, equity, reads  as named.
fp_lean_fold <- function(tape, blocks, copy = TRUE, check = "pinned", fills = TRUE, ids = TRUE,
                         diagnostics = TRUE, equity_row = TRUE, reads = TRUE, gut = "") {
  pulses <- tape$pulses
  run_id <- tape$services$run_id
  inst_ids <- tape$services$instrument_ids
  plan <- fp_read_plan(tape)
  locals <- list2env(as.list(tape$services), parent = baseenv())
  for (f in setdiff(unlist(plan, use.names = FALSE), names(tape$services))) assign(f, NULL, envir = locals)
  read <- lapply(plan, fp_reader_local, env = locals)
  ev <- fp_event_buffer()
  ds <- fp_diag_store(blocks[[which(lengths(blocks) > 0L)[[1L]]]][[1L]])
  equity <- ledgr_fold_equity_record(length(pulses))
  event_seq <- tape$init$event_seq
  first <- pulses[[1L]]
  opaque <- c("history", "state_update", "intent_reason")
  emit_packet <- fp_emitter(names(first$P1$observation$packet))
  emit_data <- fp_emitter(names(first$P1$observation$data), keep = opaque)
  emit_execution <- fp_emitter(names(first$P1$execution))
  emit_decision <- fp_emitter(decision_fields, keep = opaque)
  emit_fill <- fp_emitter(names(first$P3$batch$fill))
  emit_rejection <- fp_emitter(names(first$P3$batch$rejection))

  t0 <- ledgr_time_now()
  for (i in seq_along(pulses)) {
    ent <- pulses[[i]]
    # P1: emit the observation; write the equity row.
    if (reads) read$P1()
    o <- ent$P1$observation
    observed <- if (copy) {
      list(packet = emit_packet(o$packet), data = emit_data(o$data),
           execution = emit_execution(ent$P1$execution))
    } else {
      list(packet = o$packet, data = o$data, execution = ent$P1$execution)
    }
    if (equity_row) {
      e <- ent$equity
      equity <- ledgr_fold_equity_append(equity, e$ts, e$cash, e$positions_value, e$realized_pnl, e$cost_basis)
    }
    # P2: emit the decision; check the strategy output on a decided pulse.
    decided <- "P2" %in% ent$labels
    if (reads) { if (decided) read$P2() else read$P2_skip() }
    decision <- if (copy) emit_decision(ent$P2) else ent$P2
    if (decided && !identical(check, "none")) {
      context_ids <- inst_ids[decision$context_pos]
      targets <- stats::setNames(decision$strategy_qty, context_ids)
      if (identical(check, "pinned")) {
        ledgr_validate_strategy_targets(targets, context_ids, allow_empty = TRUE)
      } else {
        sc_check(targets, context_ids, allow_empty = TRUE, trust_universe = TRUE)
      }
    }
    # P3: emit the plan.
    if (reads) { if (decided) read$P3() else read$P3_skip() }
    b <- ent$P3$batch
    planned <- if (copy) {
      list(expected_final_cash = b$expected_final_cash,
           economic_event_kinds = c(b$economic_event_kinds),
           fill = emit_fill(b$fill), rejection = emit_rejection(b$rejection))
    } else {
      b
    }
    # P4: write the fills into reserved event rows.
    if (reads) read$P4()
    if (fills) for (call in ent$payload) {
      n <- length(call$i)
      idx <- fp_event_reserve(ev, n)
      if (identical(gut, "reservation")) ev$reserved <- ev$reserved - n
      fp_lean_event_write(ev, idx, run_id, planned$fill, call$i, call$instrument_id, event_seq, ids)
      event_seq <- event_seq + n
    }
    # P5: commit the events; write the pulse's diagnostic rows.
    if (reads) read$P5()
    ev$count <- ev$reserved
    if (diagnostics) for (b in blocks[[i]]) fp_diag_write(ds, b)
  }
  elapsed <- ledgr_time_elapsed(t0, ledgr_time_now())
  cols <- ledgr:::ledgr_output_event_columns
  list(elapsed = elapsed, pulses = length(pulses),
       events = lapply(stats::setNames(cols, cols), function(nm) {
         v <- ev$cols[[nm]][seq_len(ev$count)]
         if (nm %in% c("ts_utc", "mark_source_ts_utc")) as.numeric(v) else v
       }),
       diagnostics = lapply(ds$cols, function(v) v[seq_len(ds$count)]),
       equity = ledgr_fold_equity_prefix(equity))
}


# The compact lean fold: references instead of copies, the restructured
# strategy check, each fill a compact typed record (sequence, instrument
# position, side, quantity, price, fee, execution time), each pulse's
# diagnostic rows kept as its typed block, equity written into local
# vectors. With `boundary = TRUE` the ledger columns, event IDs and the cash
# and position effects are built once after the loop, and the diagnostic
# blocks bound, as the output boundary would.
fp_compact_fold <- function(tape, blocks, boundary = TRUE) {
  pulses <- tape$pulses
  t_n <- length(pulses)
  run_id <- tape$services$run_id
  inst_ids <- tape$services$instrument_ids
  plan <- fp_read_plan(tape)
  locals <- list2env(as.list(tape$services), parent = baseenv())
  for (f in setdiff(unlist(plan, use.names = FALSE), names(tape$services))) assign(f, NULL, envir = locals)
  read <- lapply(plan, fp_reader_local, env = locals)
  cap <- 1024L
  f_seq <- integer(cap); f_pos <- integer(cap); f_side <- integer(cap)
  f_qty <- numeric(cap); f_price <- numeric(cap); f_fee <- numeric(cap); f_ts <- numeric(cap)
  n_fill <- 0L
  diag <- vector("list", t_n)
  eq_ts <- numeric(t_n); eq_cash <- numeric(t_n); eq_pv <- numeric(t_n)
  eq_rpnl <- numeric(t_n); eq_basis <- numeric(t_n)
  event_seq <- tape$init$event_seq

  t0 <- ledgr_time_now()
  for (i in seq_len(t_n)) {
    ent <- pulses[[i]]
    read$P1()
    o <- ent$P1$observation
    observed <- list(packet = o$packet, data = o$data, execution = ent$P1$execution)
    e <- ent$equity
    eq_ts[i] <- e$ts; eq_cash[i] <- e$cash; eq_pv[i] <- e$positions_value
    eq_rpnl[i] <- e$realized_pnl; eq_basis[i] <- e$cost_basis
    decided <- "P2" %in% ent$labels
    if (decided) read$P2() else read$P2_skip()
    decision <- ent$P2
    if (decided) {
      context_ids <- inst_ids[decision$context_pos]
      sc_check(stats::setNames(decision$strategy_qty, context_ids), context_ids,
               allow_empty = TRUE, trust_universe = TRUE)
    }
    if (decided) read$P3() else read$P3_skip()
    fill <- ent$P3$batch$fill
    read$P4()
    for (call in ent$payload) {
      rows <- call$i
      n <- length(rows)
      if (n_fill + n > cap) {
        cap <- max(2L * cap, n_fill + n)
        length(f_seq) <- cap; length(f_pos) <- cap; length(f_side) <- cap; length(f_qty) <- cap
        length(f_price) <- cap; length(f_fee) <- cap; length(f_ts) <- cap
      }
      idx <- n_fill + seq_len(n)
      full <- n == length(fill$k)
      f_seq[idx] <- as.integer(event_seq) + seq_len(n) - 1L
      f_pos[idx] <- if (full) fill$pos else fill$pos[rows]
      f_side[idx] <- if (full) fill$side else fill$side[rows]
      f_qty[idx] <- if (full) fill$qty else fill$qty[rows]
      f_price[idx] <- if (full) fill$price else fill$price[rows]
      f_fee[idx] <- if (full) fill$fee else fill$fee[rows]
      f_ts[idx] <- if (full) fill$exec_ts else fill$exec_ts[rows]
      n_fill <- n_fill + n
      event_seq <- event_seq + n
    }
    read$P5()
    if (length(blocks[[i]])) diag[[i]] <- blocks[[i]]
  }
  if (!boundary) {
    return(list(elapsed = ledgr_time_elapsed(t0, ledgr_time_now()), pulses = t_n))
  }

  # Output boundary, once per run.
  used <- seq_len(n_fill)
  seq <- f_seq[used]
  side <- f_side[used]
  d <- ledgr_fill_publication_deltas(side, f_qty[used], f_price[used], f_fee[used])
  events <- ledgr:::ledgr_accounting_empty_columns(n_fill)
  events$event_id <- paste0(run_id, "_", sprintf("%08d", seq))
  events$run_id <- rep(run_id, n_fill)
  events$ts_utc <- f_ts[used]
  events$event_type <- rep("FILL", n_fill)
  events$instrument_id <- inst_ids[f_pos[used]]
  events$side <- c("SELL", "BUY")[(side > 0L) + 1L]
  events$qty <- f_qty[used]
  events$price <- f_price[used]
  events$fee <- f_fee[used]
  events$event_seq <- seq
  events$cash_delta <- d$cash_delta
  events$position_delta <- d$position_delta
  events$mark_source_ts_utc <- as.numeric(events$mark_source_ts_utc)
  pulse_blocks <- unlist(diag, recursive = FALSE)
  diagnostics <- lapply(stats::setNames(diag_cols, diag_cols), function(nm) {
    unlist(lapply(pulse_blocks, function(b) b[[nm]]), use.names = FALSE)
  })
  elapsed <- ledgr_time_elapsed(t0, ledgr_time_now())
  list(elapsed = elapsed, pulses = t_n, events = events, diagnostics = diagnostics,
       equity = list(ts = eq_ts, cash = eq_cash, positions_value = eq_pv, realized_pnl = eq_rpnl,
                     cost_basis = eq_basis, n = t_n))
}

same <- function(a, b) isTRUE(identical(unname(a), unname(b)))
parity <- list()
timing <- list()
for (w in names(tapes)) {
  tape <- tapes[[w]]
  blocks <- fp_pulse_blocks(tape)
  o <- tape$oracle
  oracle_diag <- lapply(stats::setNames(diag_cols, diag_cols), function(nm) {
    v <- unlist(lapply(o$diagnostics, function(b) b[[nm]]), use.names = FALSE)
    if (nm %in% diag_time) as.numeric(v) else v
  })
  variants <- list(lean = list(), lean_fast_check = list(check = "fast"),
                   lean_fast_check_references = list(check = "fast", copy = FALSE),
                   lean_gut_reservation = list(gut = "reservation"))
  variants$lean_compact <- list(compact = TRUE)
  for (label in names(variants)) {
    res <- if (isTRUE(variants[[label]]$compact)) {
      fp_compact_fold(tape, blocks)
    } else {
      do.call(fp_lean_fold, c(list(tape, blocks), variants[[label]]))
    }
    parity[[length(parity) + 1L]] <- data.frame(
      workload = w, variant = label, output = c("events", "diagnostic_rows", "equity"),
      rows = c(length(o$events$event_seq), length(oracle_diag$diagnostic_seq), o$equity$n),
      identical = c(all(mapply(same, res$events[names(o$events)], o$events)),
                    all(mapply(same, res$diagnostics[diag_cols], oracle_diag)),
                    all(mapply(same, res$equity[c("ts", "cash", "positions_value", "realized_pnl", "cost_basis", "n")],
                               o$equity[c("ts", "cash", "positions_value", "realized_pnl", "cost_basis", "n")]))))
  }
  fast <- function(...) fp_lean_fold(tape, blocks, check = "fast", ...)
  arms <- list(
    today = function() fp_fold(tape, "today"),
    lean = function() fp_lean_fold(tape, blocks),
    lean_fast_check = function() fast(),
    fast_minus_copies = function() fast(copy = FALSE),
    fast_minus_strategy_check = function() fp_lean_fold(tape, blocks, check = "none"),
    fast_minus_fills = function() fast(fills = FALSE),
    fast_minus_event_ids = function() fast(ids = FALSE),
    fast_minus_diagnostics = function() fast(diagnostics = FALSE),
    fast_minus_equity = function() fast(equity_row = FALSE),
    fast_minus_field_reads = function() fast(reads = FALSE),
    compact_with_output_boundary = function() fp_compact_fold(tape, blocks),
    compact_loop_only = function() fp_compact_fold(tape, blocks, boundary = FALSE),
    loop_and_stage_calls_only = function() fp_lean_fold(tape, blocks, copy = FALSE, check = "none", fills = FALSE,
                                                        diagnostics = FALSE, equity_row = FALSE, reads = FALSE))
  for (a in names(arms)) for (k in 1:2) arms[[a]]()
  # Ten folds per measurement: one momentum fold takes about 30 ms, near
  # the 15.6 ms clock tick. The measurement includes each fold's E setup.
  folds <- 10L
  for (r in seq_len(reps)) for (a in names(arms)) {
    t0 <- ledgr_time_now()
    for (k in seq_len(folds)) res <- arms[[a]]()
    elapsed <- ledgr_time_elapsed(t0, ledgr_time_now())
    timing[[length(timing) + 1L]] <- data.frame(workload = w, arm = a, rep = r,
                                                us_per_pulse = 1e6 * elapsed / (folds * res$pulses))
  }
}
parity <- do.call(rbind, parity)
timing <- do.call(rbind, timing)
summary <- aggregate(us_per_pulse ~ workload + arm, data = timing, FUN = stats::median)
summary$us_per_pulse <- round(summary$us_per_pulse, 1)

# The data edge, once per run: finiteness and sign of six N x T bar planes
# at the fill-heavy size, as preparation would check them.
set.seed(1L)
planes <- lapply(1:6, function(k) { m <- matrix(stats::runif(500 * 1260, 1, 100), 500, 1260); m[sample(length(m), 5000)] <- NA; m })
prep <- system.time(for (k in 1:20) {
  for (m in planes) if (any(is.infinite(m)) || any(m <= 0, na.rm = TRUE)) stop("bad plane")
})[["elapsed"]] / 20
summary <- rbind(summary, data.frame(workload = "fill_heavy_500x1260", arm = "prep_data_check_ms_once",
                                     us_per_pulse = round(1e3 * prep, 1)))

ws16_write(parity, file.path(out, "lean_parity.csv"))
ws16_write(timing, file.path(out, "lean_timing_raw.csv"))
ws16_write(summary[order(summary$workload, summary$arm), ], file.path(out, "lean_timing.csv"))
print(parity)
print(summary)
if (!all(parity$identical[!grepl("gut", parity$variant)])) {
  stop("kill condition: the lean fold does not reproduce the real outputs", call. = FALSE)
}
