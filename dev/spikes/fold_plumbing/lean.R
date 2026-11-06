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

fp_lean_fold <- function(tape, blocks, strategy_check = TRUE, gut = "") {
  pulses <- tape$pulses
  run_id <- tape$services$run_id
  ids <- tape$services$instrument_ids
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
    read$P1()
    o <- ent$P1$observation
    observed <- list(packet = emit_packet(o$packet), data = emit_data(o$data),
                     execution = emit_execution(ent$P1$execution))
    e <- ent$equity
    equity <- ledgr_fold_equity_append(equity, e$ts, e$cash, e$positions_value, e$realized_pnl, e$cost_basis)
    # P2: emit the decision; check the strategy output on a decided pulse.
    decided <- "P2" %in% ent$labels
    if (decided) read$P2() else read$P2_skip()
    decision <- emit_decision(ent$P2)
    if (decided && strategy_check) {
      context_ids <- ids[decision$context_pos]
      ledgr_validate_strategy_targets(stats::setNames(decision$strategy_qty, context_ids), context_ids,
                                      allow_empty = TRUE)
    }
    # P3: emit the plan.
    if (decided) read$P3() else read$P3_skip()
    b <- ent$P3$batch
    planned <- list(expected_final_cash = b$expected_final_cash,
                    economic_event_kinds = c(b$economic_event_kinds),
                    fill = emit_fill(b$fill), rejection = emit_rejection(b$rejection))
    # P4: write the fills into reserved event rows.
    read$P4()
    for (call in ent$payload) {
      n <- length(call$i)
      idx <- fp_event_reserve(ev, n)
      if (identical(gut, "reservation")) ev$reserved <- ev$reserved - n
      fp_event_write(ev, idx, run_id, planned$fill, call$i, call$instrument_id, event_seq)
      event_seq <- event_seq + n
    }
    # P5: commit the events; write the pulse's diagnostic rows.
    read$P5()
    ev$count <- ev$reserved
    for (b in blocks[[i]]) fp_diag_write(ds, b)
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
  for (label in c("lean", "lean_gut_reservation")) {
    res <- fp_lean_fold(tape, blocks, gut = if (grepl("gut", label)) "reservation" else "")
    parity[[length(parity) + 1L]] <- data.frame(
      workload = w, variant = label, output = c("events", "diagnostic_rows", "equity"),
      rows = c(length(o$events$event_seq), length(oracle_diag$diagnostic_seq), o$equity$n),
      identical = c(all(mapply(same, res$events[names(o$events)], o$events)),
                    all(mapply(same, res$diagnostics[diag_cols], oracle_diag)),
                    all(mapply(same, res$equity[c("ts", "cash", "positions_value", "realized_pnl", "cost_basis", "n")],
                               o$equity[c("ts", "cash", "positions_value", "realized_pnl", "cost_basis", "n")]))))
  }
  arms <- list(
    today = function() fp_fold(tape, "today"),
    lean = function() fp_lean_fold(tape, blocks),
    lean_without_strategy_check = function() fp_lean_fold(tape, blocks, strategy_check = FALSE))
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
