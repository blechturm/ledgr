# In-memory seam for the fill-event block-write spike. Sourced by probe.R,
# spike_runner.R and (through the runner) spike_checker.R.
#
# The block arm changes three loaded functions and nothing on disk:
#   ledgr_execute_fold              one flush call right after the per-fill loop;
#   ledgr_memory_output_handler     sweep writer: stage each fill (and its
#                                   accounting patch and inline-fill legs), flush
#                                   once per pulse with one setv() per column;
#   ledgr_persistent_output_handler run writer: stage rows, flush one setv() per
#                                   column into the pending buffer.
# Live event mode never reaches buffer_event(), so it is untouched.
# gut = "misorder" writes every staged column except event_seq in reverse order.

bw_replace <- function(expr, pred, replacement) {
  hits <- 0L
  walk <- function(e) {
    if (is.call(e)) {
      if (pred(e)) { hits <<- hits + 1L; return(replacement(e)) }
      for (i in seq_along(e)) if (!is.null(e[[i]])) e[[i]] <- walk(e[[i]])
    }
    e
  }
  out <- walk(expr)
  if (hits != 1L) stop(sprintf("seam: expected exactly one match, found %d", hits))
  out
}
bw_is_assign <- function(lhs) function(e) identical(e[[1L]], as.name("<-")) && identical(e[[2L]], lhs)

bw_block_functions <- function(ns, gut = c("none", "misorder")) {
  gut <- match.arg(gut)
  content_order <- if (identical(gut, "misorder")) quote(rev(seq_len(n))) else quote(seq_len(n))

  fold <- get("ledgr_execute_fold", envir = ns)
  body(fold) <- bw_replace(body(fold),
    function(e) identical(e[[1L]], as.name("for")) && identical(e[[2L]], as.name("entry")) &&
      identical(e[[3L]], quote(accounting_events$fills)),
    function(e) as.call(list(as.name("{"), e,
      quote(if (is.function(output_handler$flush_pulse_events)) output_handler$flush_pulse_events()))))

  memory_buffer <- bquote({
    state$bw_rows <- vector("list", 256L)
    state$bw_n <- 0L
    state$bw_legs <- vector("list", 256L)
    state$bw_leg_n <- 0L
    handler$buffer_event <- function(write_res) {
      if (inherits(write_res, "ledgr_ledger_write_result") && identical(write_res$status, "WROTE")) {
        k <- state$bw_n + 1L
        if (k > length(state$bw_rows)) state$bw_rows <- c(state$bw_rows, vector("list", length(state$bw_rows)))
        state$bw_rows[[k]] <- list(row = write_res$row, cash_delta = write_res$cash_delta,
          position_delta = write_res$position_delta, meta = write_res$meta,
          event_realized = NA_real_, event_cost_basis = NA_real_)
        state$bw_n <- k
      }
      invisible(TRUE)
    }
    handler$flush_pulse_events <- function() {
      n <- state$bw_n
      if (n > 0L) {
        staged <- state$bw_rows[seq_len(n)]
        content <- staged[.(content_order)]
        rows <- lapply(content, `[[`, "row")
        start <- state$event_count + 1L
        end <- state$event_count + n
        ensure_event_capacity(end)
        idx <- start:end
        put <- function(name, value) ledgr_event_buffer_setv(state$event_cols, name, idx, value)
        field <- function(name, type) vapply(rows, `[[`, type, name)
        put("event_id", field("event_id", character(1)))
        put("run_id", field("run_id", character(1)))
        put("ts_utc", .POSIXct(field("ts_utc", numeric(1)), tz = "UTC"))
        put("event_type", field("event_type", character(1)))
        put("instrument_id", field("instrument_id", character(1)))
        put("side", field("side", character(1)))
        put("qty", field("qty", numeric(1)))
        put("price", field("price", numeric(1)))
        put("fee", field("fee", numeric(1)))
        put("meta_json", field("meta_json", character(1)))
        put("event_seq", vapply(staged, function(s) s$row$event_seq, integer(1)))
        put("cash_delta", vapply(content, `[[`, numeric(1), "cash_delta"))
        put("position_delta", vapply(content, `[[`, numeric(1), "position_delta"))
        put("event_realized", vapply(content, `[[`, numeric(1), "event_realized"))
        put("event_cost_basis", vapply(content, `[[`, numeric(1), "event_cost_basis"))
        put("meta", lapply(content, `[[`, "meta"))
        state$event_count <- end
        state$bw_n <- 0L
      }
      m <- state$bw_leg_n
      if (m > 0L) {
        legs <- state$bw_legs[seq_len(m)]
        buf <- state$inline_fills
        start <- buf$n + 1L
        end <- buf$n + m
        ledgr_fill_row_buffer_grow(buf, end)
        idx <- start:end
        leg <- function(name, type) vapply(legs, `[[`, type, name)
        collapse::setv(buf$event_seq, idx, as.integer(leg("event_seq", integer(1))), vind1 = TRUE)
        collapse::setv(buf$ts_utc, idx, as.POSIXct(.POSIXct(leg("ts_utc", numeric(1)), tz = "UTC"), tz = "UTC"), vind1 = TRUE)
        collapse::setv(buf$instrument_id, idx, as.character(leg("instrument_id", character(1))), vind1 = TRUE)
        collapse::setv(buf$side, idx, as.character(leg("side", character(1))), vind1 = TRUE)
        collapse::setv(buf$qty, idx, as.numeric(leg("qty", numeric(1))), vind1 = TRUE)
        collapse::setv(buf$price, idx, as.numeric(leg("price", numeric(1))), vind1 = TRUE)
        collapse::setv(buf$fee, idx, as.numeric(leg("fee", numeric(1))), vind1 = TRUE)
        collapse::setv(buf$realized_pnl, idx, as.numeric(leg("realized_pnl", numeric(1))), vind1 = TRUE)
        collapse::setv(buf$action, idx, as.character(leg("action", character(1))), vind1 = TRUE)
        buf$n <- end
        state$bw_leg_n <- 0L
      }
      invisible(TRUE)
    }
  })
  memory_accounting <- quote(handler$record_accounting_fact <- function(write_res, lot_res, lot_state) {
    if (!inherits(write_res, "ledgr_ledger_write_result") ||
        !identical(write_res$status, "WROTE") ||
        state$bw_n == 0L) {
      return(invisible(FALSE))
    }
    k <- state$bw_n
    entry <- state$bw_rows[[k]]
    entry$event_realized <- as.numeric(lot_state$realized_pnl)[[1]]
    entry$event_cost_basis <- as.numeric(lot_state$total_cost_basis)[[1]]
    state$bw_rows[[k]] <- entry
    row <- write_res$row
    leg_fees <- ledgr_fill_leg_fees(row$fee, lot_res$close_qty, lot_res$open_qty)
    stage_leg <- function(qty, fee, realized, action) {
      j <- state$bw_leg_n + 1L
      if (j > length(state$bw_legs)) state$bw_legs <- c(state$bw_legs, vector("list", length(state$bw_legs)))
      state$bw_legs[[j]] <- list(event_seq = row$event_seq, ts_utc = row$ts_utc, instrument_id = row$instrument_id,
        side = row$side, qty = as.numeric(qty), price = row$price, fee = as.numeric(fee),
        realized_pnl = as.numeric(realized), action = action)
      state$bw_leg_n <- j
    }
    if (isTRUE(lot_res$close_qty > 0)) stage_leg(lot_res$close_qty, leg_fees[["close"]], lot_res$realized_close, "CLOSE")
    if (isTRUE(lot_res$open_qty > 0)) stage_leg(lot_res$open_qty, leg_fees[["open"]], 0, "OPEN")
    invisible(TRUE)
  })
  memory <- get("ledgr_memory_output_handler", envir = ns)
  body(memory) <- bw_replace(body(memory), bw_is_assign(quote(handler$buffer_event)), function(e) memory_buffer)
  body(memory) <- bw_replace(body(memory), bw_is_assign(quote(handler$record_accounting_fact)), function(e) memory_accounting)

  persistent_buffer <- bquote({
    state$bw_rows <- vector("list", 256L)
    state$bw_n <- 0L
    handler$buffer_event <- function(write_res) {
      if (!inherits(write_res, "ledgr_ledger_write_result") || !identical(write_res$status, "WROTE")) {
        return(invisible(FALSE))
      }
      if (is.null(state$pending_cols)) {
        rlang::abort("Ledger event buffer has not been initialized.", class = "ledgr_invalid_state")
      }
      k <- state$bw_n + 1L
      if (k > length(state$bw_rows)) state$bw_rows <- c(state$bw_rows, vector("list", length(state$bw_rows)))
      state$bw_rows[[k]] <- write_res$row
      state$bw_n <- k
      invisible(TRUE)
    }
    handler$flush_pulse_events <- function() {
      n <- state$bw_n
      if (n == 0L) return(invisible(TRUE))
      rows <- state$bw_rows[seq_len(n)]
      content <- rows[.(content_order)]
      start <- state$pending_idx + 1L
      end <- state$pending_idx + n
      ensure_pending_capacity(end)
      idx <- start:end
      put <- function(name, value) ledgr_event_buffer_setv(state$pending_cols, name, idx, value)
      field <- function(name, type) vapply(content, `[[`, type, name)
      put("event_id", field("event_id", character(1)))
      put("run_id", field("run_id", character(1)))
      put("ts_utc", .POSIXct(field("ts_utc", numeric(1)), tz = "UTC"))
      put("event_type", field("event_type", character(1)))
      put("instrument_id", field("instrument_id", character(1)))
      put("side", field("side", character(1)))
      put("qty", field("qty", numeric(1)))
      put("price", field("price", numeric(1)))
      put("fee", field("fee", numeric(1)))
      put("meta_json", field("meta_json", character(1)))
      put("event_seq", vapply(rows, `[[`, integer(1), "event_seq"))
      state$pending_idx <- end
      state$bw_n <- 0L
      invisible(TRUE)
    }
  })
  persistent <- get("ledgr_persistent_output_handler", envir = ns)
  body(persistent) <- bw_replace(body(persistent), bw_is_assign(quote(handler$buffer_event)), function(e) persistent_buffer)

  list(ledgr_execute_fold = fold, ledgr_memory_output_handler = memory,
    ledgr_persistent_output_handler = persistent)
}

# Bind a set of replacement functions in the loaded namespace for one call.
bw_with <- function(ns, functions, code) {
  if (is.null(functions)) return(force(code))
  old <- lapply(names(functions), get, envir = ns)
  names(old) <- names(functions)
  for (name in names(functions)) { unlockBinding(name, ns); assign(name, functions[[name]], envir = ns) }
  on.exit(for (name in names(old)) { assign(name, old[[name]], envir = ns); lockBinding(name, ns) }, add = TRUE)
  force(code)
}
