# Tape capture: one real fold at the pin, recorded pulse by pulse.
#
# The pinned stage functions and the write helpers they call are wrapped
# from outside. For every pulse the tape keeps what each stage handed on
# (its result), every diagnostic staging call, every fill publication call
# and the equity append. It also keeps the outputs that the skeleton fold
# must reproduce: the published fill blocks, the diagnostic blocks handed to
# the writer and the equity prefix. Nothing in R/ changes.

fp_rec <- new.env()
fp_rec$on <- FALSE
fp_rec$blocks <- NULL

# A copy that owns its atomic vectors, so a later in-place write (setv) in
# the fold cannot change the tape. Environments and functions stay
# references; `keep` names list fields kept by reference (the history view).
fp_snap <- function(x, keep = character()) {
  if (is.null(x) || is.environment(x) || is.function(x)) return(x)
  if (is.list(x)) {
    a <- attributes(x)
    y <- x
    for (k in seq_along(x)) {
      nm <- names(x)[k]
      if (!is.null(nm) && nm %in% keep) next
      y[k] <- list(fp_snap(x[[k]], keep))
    }
    attributes(y) <- a
    return(y)
  }
  if (is.atomic(x) && length(x)) {
    y <- x
    y[1L] <- y[1L]
    return(y)
  }
  x
}

fp_count <- function(table, key) {
  table[[key]] <- (table[[key]] %||% 0) + 1
}

`$.fp_services` <- function(x, name) {
  if (isTRUE(fp_rec$on)) fp_count(fp_rec$reads, paste(fp_rec$stage, name, sep = "\t"))
  .subset2(x, name)
}
`[[.fp_services` <- function(x, i, ...) {
  if (isTRUE(fp_rec$on)) fp_count(fp_rec$reads, paste(fp_rec$stage, as.character(i), sep = "\t"))
  .subset2(x, i)
}
.S3method("$", "fp_services", `$.fp_services`)
.S3method("[[", "fp_services", `[[.fp_services`)

fp_stages <- c(
  P1 = "ledgr_fold_stage_observe_settle", P2 = "ledgr_fold_stage_decide",
  P2_skip = "ledgr_fold_scheduled_skip_decision", P3 = "ledgr_fold_stage_plan",
  P3_skip = "ledgr_fold_scheduled_skip_plan", P4 = "ledgr_fold_stage_apply",
  P5 = "ledgr_fold_stage_commit"
)

fp_install_wrappers <- function() {
  for (label in names(fp_stages)) local({
    lab <- label
    ws16_wrap(fp_stages[[lab]], function(orig) {
      force(orig)
      function(...) {
        a <- list(...)
        if (!isTRUE(fp_rec$on)) return(do.call(orig, a))
        if (identical(lab, "P1")) {
          if (is.null(fp_rec$services)) {
            fp_rec$services <- a$services
            fp_rec$init <- fp_snap(as.list.environment(a$fold_state, all.names = TRUE))
          }
          cur <- new.env()
          cur$pulse <- a$pulse_idx
          cur$staging <- list()
          cur$payload <- list()
          cur$labels <- character()
          fp_rec$cur <- cur
          fp_rec$tape[[a$pulse_idx]] <- cur
        }
        if (!is.null(a$services)) {
          class(a$services) <- c("fp_services", class(a$services))
        }
        prev <- fp_rec$stage
        fp_rec$stage <- lab
        on.exit(fp_rec$stage <- prev)
        out <- do.call(orig, a)
        cur <- fp_rec$cur
        cur$labels <- c(cur$labels, lab)
        slot <- sub("_skip$", "", lab)
        cur[[slot]] <- if (identical(slot, "P1")) {
          o <- out
          history <- o$observation$data$history
          o <- fp_snap(o, keep = "history")
          o$observation$data["history"] <- list(history)
          o
        } else {
          fp_snap(out)
        }
        if (identical(lab, "P4")) {
          cur$positions <- fp_snap(a$fold_state$positions)
          cur$cash <- a$fold_state$cash
        }
        out
      }
    })
  })

  ws16_wrap("ledgr_fold_staging_add", function(orig) {
    force(orig)
    function(fold_state, segment, ts) {
      if (isTRUE(fp_rec$on) && !is.null(fp_rec$cur)) {
        n <- length(fp_rec$cur$staging)
        fp_rec$cur$staging[[n + 1L]] <- list(stage = fp_rec$stage, fn = "add",
                                             segment = fp_snap(segment), ts = ts)
      }
      orig(fold_state, segment, ts)
    }
  })
  ws16_wrap("ledgr_fold_staging_add_residual", function(orig) {
    force(orig)
    function(fold_state, segment, index) {
      if (isTRUE(fp_rec$on) && !is.null(fp_rec$cur)) {
        n <- length(fp_rec$cur$staging)
        fp_rec$cur$staging[[n + 1L]] <- list(stage = fp_rec$stage, fn = "residual",
                                             segment = fp_snap(segment), index = fp_snap(index))
      }
      orig(fold_state, segment, index)
    }
  })
  ws16_wrap("ledgr_fold_equity_append", function(orig) {
    force(orig)
    function(record, ts, cash, positions_value, realized_pnl, cost_basis) {
      if (isTRUE(fp_rec$on) && !is.null(fp_rec$cur)) {
        fp_rec$cur$equity <- list(ts = ts, cash = cash, positions_value = positions_value,
                                  realized_pnl = realized_pnl, cost_basis = cost_basis)
      }
      orig(record, ts, cash, positions_value, realized_pnl, cost_basis)
    }
  })
  ws16_wrap("ledgr_fill_event_payload", function(orig) {
    force(orig)
    function(run_id, fill, i, instrument_id, event_seq) {
      out <- orig(run_id, fill, i, instrument_id, event_seq)
      if (isTRUE(fp_rec$on) && !is.null(fp_rec$cur)) {
        n <- length(fp_rec$cur$payload)
        fp_rec$cur$payload[[n + 1L]] <- list(i = fp_snap(i), instrument_id = fp_snap(instrument_id),
                                             event_seq = event_seq, block = fp_snap(out))
      }
      out
    }
  })
  # The diagnostic block of every pulse flush, for the tape and for the
  # skeleton folds alike: whoever sets fp_rec$blocks receives them.
  ws16_wrap("ledgr_fold_diagnostic_block", function(orig) {
    force(orig)
    function(rows, run_id, ts, first_seq, keep = NULL) {
      out <- orig(rows, run_id, ts, first_seq, keep = keep)
      if (!is.null(fp_rec$blocks)) {
        n <- length(fp_rec$blocks$list)
        fp_rec$blocks$list[[n + 1L]] <- fp_snap(out)
      }
      out
    }
  })
  # Validation census: every carrier check, by stage and group.
  ws16_wrap("ledgr_carrier_problem", function(orig) {
    force(orig)
    function(x, group, n_run, plan_axis = NULL) {
      if (!is.null(fp_rec$checks)) fp_count(fp_rec$checks, paste(fp_rec$stage, group, sep = "\t"))
      orig(x, group, n_run, plan_axis)
    }
  })
  ws16_wrap("ledgr_fold_envelope", function(orig) {
    force(orig)
    function(execution, output_handler) {
      out <- orig(execution, output_handler)
      if (isTRUE(fp_rec$on)) fp_rec$equity <- fp_snap(out$equity_facts)
      out
    }
  })
  invisible(TRUE)
}

# Records one fold of `run` (a function that runs the workload) and returns
# its tape.
fp_capture <- function(run) {
  fp_rec$tape <- list()
  fp_rec$reads <- new.env()
  fp_rec$checks <- new.env()
  fp_rec$services <- NULL
  fp_rec$init <- NULL
  fp_rec$cur <- NULL
  fp_rec$stage <- "E"
  fp_rec$equity <- NULL
  fp_rec$blocks <- new.env()
  fp_rec$blocks$list <- list()
  fp_rec$on <- TRUE
  on.exit({
    fp_rec$on <- FALSE
  })
  run()
  fp_rec$on <- FALSE
  services <- fp_rec$services
  class(services) <- setdiff(class(services), "fp_services")
  tape <- list(
    pulses = fp_rec$tape,
    services = services,
    init = fp_rec$init,
    reads = fp_table(fp_rec$reads, c("stage", "field")),
    checks = fp_table(fp_rec$checks, c("stage", "group")),
    oracle = list(
      events = fp_events_from_blocks(unlist(lapply(fp_rec$tape, function(p) {
        lapply(p$payload, function(x) x$block)
      }), recursive = FALSE)),
      diagnostics = fp_rec$blocks$list,
      equity = fp_rec$equity
    )
  )
  fp_rec$blocks <- NULL
  fp_rec$checks <- NULL
  if (isTRUE(services$use_compiled_spot_fifo)) {
    stop("the workload runs the compiled FIFO path; the skeleton covers the R path only", call. = FALSE)
  }
  tape
}

fp_table <- function(counts, cols) {
  keys <- ls(counts)
  if (!length(keys)) {
    out <- as.data.frame(setNames(rep(list(character()), length(cols)), cols))
    out$n <- numeric()
    return(out)
  }
  parts <- do.call(rbind, strsplit(keys, "\t", fixed = TRUE))
  out <- as.data.frame(parts, stringsAsFactors = FALSE)
  names(out) <- cols
  out$n <- vapply(keys, function(k) counts[[k]], numeric(1), USE.NAMES = FALSE)
  out[do.call(order, out[cols]), , drop = FALSE]
}

# The published event stream of a list of WROTE blocks, as columns.
fp_events_from_blocks <- function(blocks) {
  cols <- ledgr:::ledgr_output_event_columns
  blocks <- Filter(function(b) identical(b$status, "WROTE"), blocks)
  out <- lapply(cols, function(name) {
    v <- unlist(lapply(blocks, function(b) b[[name]]), use.names = FALSE)
    if (is.null(v)) v <- vector(typeof(ledgr_accounting_empty_columns(0L)[[name]]), 0L)
    if (identical(name, "ts_utc")) as.numeric(v) else v
  })
  names(out) <- cols
  out
}
