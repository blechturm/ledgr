# The skeleton fold: E's loop with stub stages that do no work. Each stub
# reads the `services` fields its real stage read (as often per call), hands
# on the objects its real stage produced on that pulse (from the tape), and
# writes the pulse's fills, diagnostics and equity row. Two variants:
#
#   today    fresh objects every pulse, checked by the pinned carrier
#            constructors; fills go through the pinned output handler (block,
#            hold, copy into the event buffer at P5); `services$field` reads.
#   prealloc E allocates every stage output once at its largest tape size and
#            the stubs overwrite it in place; P4 writes fills straight into
#            the event buffer at reserved rows and P5 commits the count;
#            fields are bound once as locals; no per-pulse checks.
#
# Both variants stage diagnostics and append equity through the pinned
# functions, which already preallocate. Fill legs (record_accounting_fact)
# are left out of both.

fp_flags_all <- c(services = TRUE, groups = TRUE, validate = TRUE, fills = TRUE,
                  diagnostics = TRUE, equity = TRUE)

# Per stage label: the fields read on one call, repeated as often as the real
# stage read them per call (rounded mean over the fold).
fp_read_plan <- function(tape) {
  labels <- unlist(lapply(tape$pulses, function(p) p$labels), use.names = FALSE)
  calls <- table(labels)
  out <- list()
  for (lab in names(fp_stages)) {
    r <- tape$reads[tape$reads$stage == lab, , drop = FALSE]
    n_calls <- if (lab %in% names(calls)) as.numeric(calls[[lab]]) else 0
    times <- if (n_calls > 0) round(r$n / n_calls) else integer(nrow(r))
    out[[lab]] <- rep(r$field, times)
  }
  out
}

fp_reader_list <- function(fields) {
  f <- function(services) NULL
  body(f) <- as.call(c(as.name("{"), lapply(fields, function(x) call("$", as.name("services"), as.name(x))),
                       list(NULL)))
  f
}

fp_reader_local <- function(fields, env) {
  f <- function() NULL
  body(f) <- as.call(c(as.name("{"), lapply(fields, as.name), list(NULL)))
  environment(f) <- env
  f
}

fp_fold_state <- function(tape) {
  s <- new.env(parent = emptyenv())
  for (slot in names(tape$init)) assign(slot, fp_snap(tape$init[[slot]]), envir = s)
  lockEnvironment(s)
  s
}

fp_replay_staging <- function(fold_state, ops, lab) {
  for (op in ops) {
    if (!identical(op$stage, lab)) next
    if (identical(op$fn, "add")) {
      ledgr_fold_staging_add(fold_state, op$segment, op$ts)
    } else {
      ledgr_fold_staging_add_residual(fold_state, op$segment, op$index)
    }
  }
}

# A preallocated group: every atomic field at its largest tape length.
fp_alloc <- function(objects) {
  buf <- new.env(parent = emptyenv())
  for (nm in names(objects[[1L]])) {
    vals <- lapply(objects, function(o) o[[nm]])
    if (all(vapply(vals, function(v) is.atomic(v) && !is.null(v), logical(1)))) {
      assign(nm, vector(typeof(vals[[1L]]), max(lengths(vals))), envir = buf)
    } else {
      assign(nm, NULL, envir = buf)
    }
    assign(paste0(nm, ".n"), 0L, envir = buf)
  }
  buf
}

fp_overwrite <- function(buf, x) {
  for (nm in names(x)) {
    v <- x[[nm]]
    if (is.atomic(v) && !is.null(v)) {
      n <- length(v)
      if (n) collapse::setv(get(nm, envir = buf, inherits = FALSE), seq_len(n), v, vind1 = TRUE)
      assign(paste0(nm, ".n"), n, envir = buf)
    } else {
      assign(nm, v, envir = buf)
    }
  }
}

fp_used <- function(buf, nm) {
  n <- get(paste0(nm, ".n"), envir = buf, inherits = FALSE)
  get(nm, envir = buf, inherits = FALSE)[seq_len(n)]
}

# Event columns written by index, grown by doubling like the handler's.
fp_event_buffer <- function(capacity = 1024L) {
  ev <- new.env(parent = emptyenv())
  ev$cols <- ledgr_accounting_empty_columns(capacity)
  ev$cols$ts_utc <- rep(NA_real_, capacity)
  ev$cols$mark_source_ts_utc <- rep(NA_real_, capacity)
  ev$capacity <- capacity
  ev$count <- 0L
  ev$reserved <- 0L
  ev
}

fp_event_reserve <- function(ev, n) {
  need <- ev$reserved + n
  if (need > ev$capacity) {
    cap <- max(2L * ev$capacity, need)
    new <- fp_event_buffer(cap)$cols
    used <- seq_len(ev$reserved)
    if (length(used)) for (nm in names(new)) collapse::setv(new[[nm]], used, ev$cols[[nm]][used], vind1 = TRUE)
    ev$cols <- new
    ev$capacity <- cap
  }
  start <- ev$reserved
  ev$reserved <- need
  start + seq_len(n)
}

fp_event_write <- function(ev, idx, run_id, fill, i, instrument_id, event_seq) {
  seq <- as.integer(event_seq) + seq_along(i) - 1L
  c <- ev$cols
  collapse::setv(c$event_id, idx, paste0(run_id, "_", sprintf("%08d", seq)), vind1 = TRUE)
  collapse::setv(c$run_id, idx, rep(run_id, length(i)), vind1 = TRUE)
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

# Runs one skeleton fold. `gut = "reservation"` drops P4's reservation
# advance (fills overwrite each other); `keep_refs` records P2's output
# handle on every pulse, as a recorder holding references would.
fp_fold <- function(tape, variant = c("today", "prealloc"), flags = fp_flags_all,
                    gut = "", keep_refs = FALSE) {
  variant <- match.arg(variant)
  on <- as.list(flags)
  pulses <- tape$pulses
  run_id <- tape$services$run_id
  n_run <- length(tape$services$instrument_ids)
  plan <- fp_read_plan(tape)
  # The memory sink, with the durable sink's keep rule (R/output-handler.R:88):
  # the tape is a durable run, which keeps every staged diagnostic row.
  sink <- ledgr_output_sink_memory(run_id)
  sink$diagnostic_keep <- function(diagnostics, n = NULL) {
    if (is.null(n)) n <- if (is.data.frame(diagnostics)) nrow(diagnostics) else length(diagnostics$stage)
    rep(TRUE, n)
  }
  handler <- ledgr_output_handler(sink)
  total_fills <- sum(vapply(pulses, function(p) sum(vapply(p$payload, function(x) length(x$i), 0)), 0))
  handler$init_buffers(max_events = total_fills + 1024L)
  writer <- ledgr_fold_diagnostic_writer(run_id, handler)
  services <- tape$services
  services$output_handler <- handler
  services$diagnostic_writer <- writer
  fold_state <- fp_fold_state(tape)
  refs <- list()

  if (identical(variant, "today")) {
    read <- lapply(plan, fp_reader_list)
  } else {
    locals <- list2env(as.list(services), parent = baseenv())
    # A field read but absent from the list (a NULL entry) reads as NULL.
    for (f in setdiff(unlist(plan, use.names = FALSE), names(services))) assign(f, NULL, envir = locals)
    read <- lapply(plan, fp_reader_local, env = locals)
    buf <- list(
      packet = fp_alloc(lapply(pulses, function(p) p$P1$observation$packet)),
      data = fp_alloc(lapply(pulses, function(p) p$P1$observation$data)),
      execution = fp_alloc(lapply(pulses, function(p) p$P1$execution)),
      decision = fp_alloc(lapply(pulses, function(p) p$P2[names(ledgr:::.ledgr_carrier_fields$decision)])),
      fill = fp_alloc(lapply(pulses, function(p) p$P3$batch$fill)),
      rejection = fp_alloc(lapply(pulses, function(p) p$P3$batch$rejection))
    )
    ev <- fp_event_buffer()
  }
  if (!isTRUE(on$validate) && identical(variant, "today")) {
    # The today variant without its checks: carrier checks and the event
    # append check return at once.
    restore <- list(
      ws16_wrap("ledgr_carrier_problem", function(orig) function(x, group, n_run, plan_axis = NULL) NULL),
      ws16_wrap("ledgr_validate_accounting_append", function(orig) {
        function(rows, prior_event_seq = NULL, prior_ts_utc = NULL) rows
      })
    )
    on.exit({
      ws16_wrap("ledgr_carrier_problem", function(x) restore[[1L]])
      ws16_wrap("ledgr_validate_accounting_append", function(x) restore[[2L]])
    }, add = TRUE)
  }

  t0 <- ledgr_time_now()
  for (i in seq_along(pulses)) {
    ent <- pulses[[i]]
    labels <- ent$labels
    ts <- ent$P1$observation$ts

    # P1 observe and settle.
    fp_rec$stage <- "P1"
    if (isTRUE(on$services)) if (identical(variant, "today")) read$P1(services) else read$P1()
    if (identical(variant, "today")) {
      observed <- if (isTRUE(on$groups)) fp_snap(ent$P1, keep = "history") else ent$P1
      if (isTRUE(on$validate)) {
        ledgr_carrier_packet(observed$observation$packet, "decision_packet", n_run)
        ledgr_carrier_packet(observed$observation$data, "decision_data", n_run)
        ledgr_carrier_packet(observed$execution, "execution_packet", n_run)
      }
    } else if (isTRUE(on$groups)) {
      fp_overwrite(buf$packet, ent$P1$observation$packet)
      fp_overwrite(buf$data, ent$P1$observation$data)
      fp_overwrite(buf$execution, ent$P1$execution)
    }
    if (isTRUE(on$diagnostics)) fp_replay_staging(fold_state, ent$staging, "P1")
    if (isTRUE(on$equity)) {
      e <- ent$equity
      fold_state$equity_facts <- ledgr_fold_equity_append(fold_state$equity_facts, e$ts, e$cash,
                                                          e$positions_value, e$realized_pnl, e$cost_basis)
    }

    # P2 decide, or the scheduled skip, whose skip row E stages first
    # (R/fold-engine.R:1969).
    lab2 <- if ("P2" %in% labels) "P2" else "P2_skip"
    fp_rec$stage <- "E"
    if (isTRUE(on$diagnostics)) fp_replay_staging(fold_state, ent$staging, "E")
    fp_rec$stage <- lab2
    if (isTRUE(on$services)) if (identical(variant, "today")) read[[lab2]](services) else read[[lab2]]()
    if (identical(variant, "today")) {
      decision <- if (isTRUE(on$groups)) fp_snap(ent$P2) else ent$P2
      if (isTRUE(on$validate)) ledgr_carrier_decision(decision[names(ledgr:::.ledgr_carrier_fields$decision)], n_run)
    } else if (isTRUE(on$groups)) {
      fp_overwrite(buf$decision, ent$P2[names(ledgr:::.ledgr_carrier_fields$decision)])
      if (keep_refs) refs[[i]] <- buf$decision
    }
    if (isTRUE(on$diagnostics)) fp_replay_staging(fold_state, ent$staging, lab2)

    # P3 plan, or the scheduled skip.
    lab3 <- if ("P3" %in% labels) "P3" else "P3_skip"
    fp_rec$stage <- lab3
    if (isTRUE(on$services)) if (identical(variant, "today")) read[[lab3]](services) else read[[lab3]]()
    if (identical(variant, "today")) {
      planned <- if (isTRUE(on$groups)) fp_snap(ent$P3) else ent$P3
      if (isTRUE(on$validate)) {
        ledgr_carrier_plan(planned$batch, decision$context_pos, decision$actionable_k, n_run)
      }
    } else if (isTRUE(on$groups)) {
      fp_overwrite(buf$fill, ent$P3$batch$fill)
      fp_overwrite(buf$rejection, ent$P3$batch$rejection)
    }
    if (isTRUE(on$diagnostics)) fp_replay_staging(fold_state, ent$staging, lab3)

    # P4 apply: publish the pulse's fills.
    fp_rec$stage <- "P4"
    if (isTRUE(on$services)) if (identical(variant, "today")) read$P4(services) else read$P4()
    if (isTRUE(on$fills)) {
      for (call in ent$payload) {
        n <- length(call$i)
        if (identical(variant, "today")) {
          fill <- if (isTRUE(on$groups)) planned$batch$fill else ent$P3$batch$fill
          handler$write_fill_events(fill = fill, i = call$i, instrument_id = call$instrument_id,
                                    event_seq = fold_state$event_seq, use_transaction = FALSE)
        } else {
          fill <- if (isTRUE(on$groups)) {
            list(exec_ts = fp_used(buf$fill, "exec_ts"), side = fp_used(buf$fill, "side"),
                 qty = fp_used(buf$fill, "qty"), price = fp_used(buf$fill, "price"),
                 fee = fp_used(buf$fill, "fee"), cash_delta = fp_used(buf$fill, "cash_delta"),
                 position_delta = fp_used(buf$fill, "position_delta"))
          } else {
            ent$P3$batch$fill
          }
          idx <- fp_event_reserve(ev, n)
          if (identical(gut, "reservation")) ev$reserved <- ev$reserved - n
          fp_event_write(ev, idx, run_id, fill, call$i, call$instrument_id, fold_state$event_seq)
        }
        fold_state$event_seq <- fold_state$event_seq + n
      }
    }
    fold_state$positions <- ent$positions
    fold_state$cash <- ent$cash

    # P5 commit: the pulse's events and diagnostics land.
    fp_rec$stage <- "P5"
    if (isTRUE(on$services)) if (identical(variant, "today")) read$P5(services) else read$P5()
    if (isTRUE(on$fills)) {
      if (identical(variant, "today")) handler$flush_pulse_events() else ev$count <- ev$reserved
    }
    if (isTRUE(on$diagnostics)) {
      fp_replay_staging(fold_state, ent$staging, "P5")
      ledgr_fold_flush_pulse_block(fold_state, writer, run_id, ts)
    }
    fold_state$processed <- fold_state$processed + 1L
  }
  elapsed <- ledgr_time_elapsed(t0, ledgr_time_now())
  fp_rec$stage <- "E"

  events <- if (identical(variant, "today")) {
    st <- environment(handler$flush_pulse_events)$state
    lapply(setNames(ledgr:::ledgr_output_event_columns, ledgr:::ledgr_output_event_columns), function(nm) {
      v <- st$event_cols[[nm]][seq_len(st$event_count)]
      if (nm %in% c("ts_utc", "mark_source_ts_utc")) as.numeric(v) else v
    })
  } else {
    lapply(setNames(ledgr:::ledgr_output_event_columns, ledgr:::ledgr_output_event_columns), function(nm) {
      v <- ev$cols[[nm]][seq_len(ev$count)]
      if (nm %in% c("ts_utc", "mark_source_ts_utc")) as.numeric(v) else v
    })
  }
  list(elapsed = elapsed, pulses = length(pulses), events = events,
       equity = ledgr_fold_equity_prefix(fold_state$equity_facts), refs = refs)
}
