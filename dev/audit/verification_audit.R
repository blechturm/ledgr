# dev/audit/verification_audit.R
#
# Ad-hoc verification audit for ledgr.
#
# Walks the 12-point external verification checklist plus the five ledgr-
# specific USP checks. Uses tiny hand-checkable data so the whole script runs
# in a few seconds. Each check is sandboxed: failures don't crash the script,
# they just record a FAIL row and move on. The end prints a per-section
# summary.
#
# This is an ad-hoc scaffold. Some checks will succeed on first run, some will
# need API tweaks because I guessed at exact public signatures. Iterate from
# the failures: each FAIL line names what was attempted and the error.
#
# Sections:
#   1.  Hand-checkable arithmetic (flat strategy)
#   2.  Next-open fill timing (step prices)
#   3.  Final-bar no-fill discipline
#   4.  No-lookahead in pulse context
#   5.  Accounting identities every pulse
#   6.  Edge-case input rejection
#   7.  Same-session reproducibility
#   8.  Cross-session reproducibility via snapshot reopen
#   9.  Provenance changes when inputs change
#   10. Independent-backtester cross-check
#   11. Indicator value parity vs TTR
#   12. Metric oracles on a known equity curve
#   A.  Event-stream replay parity (durable round-trip)
#   B.  Sweep candidate parity vs direct run
#   C.  Snapshot hash stable across reopen
#   D.  Resume = continuous parity (deterministic strategy)
#   E.  pulse_seed derivation independent of ambient RNG
#   F.  Two runs same inputs -> byte-identical events
#   G.  Multi-instrument accounting
#   H.  Costs and fees
#   I.  Round-trip realized P&L
#   J.  Dirty input rejection
#
# Usage:
#   Rscript dev/audit/verification_audit.R
#   # or interactively:
#   source("dev/audit/verification_audit.R"); audit_main()

# ---- Bootstrap -------------------------------------------------------------

if (file.exists("DESCRIPTION") &&
    any(grepl("^Package: ledgr", readLines("DESCRIPTION", n = 5)))) {
  if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("pkgload is required to load ledgr from source. install.packages('pkgload')")
  }
  suppressMessages(pkgload::load_all(".", quiet = TRUE))
} else if (requireNamespace("ledgr", quietly = TRUE)) {
  suppressMessages(library(ledgr))
} else {
  stop("ledgr is not loadable. Run from the package root or install ledgr.")
}

suppressPackageStartupMessages({
  library(tibble)
})

if (!requireNamespace("TTR", quietly = TRUE)) {
  message("note: TTR not installed; indicator parity check (section 11) will SKIP.")
}

# ---- Result recorder -------------------------------------------------------

audit_state <- new.env(parent = emptyenv())
audit_state$rows <- list()
audit_state$current_section <- NA_character_

audit_record <- function(item, status, detail = "") {
  symbol <- switch(status, pass = "PASS", fail = "FAIL", skip = "SKIP")
  message(sprintf("  [%s] %s%s", symbol, item,
                  if (nzchar(detail)) paste0(" -- ", detail) else ""))
  audit_state$rows[[length(audit_state$rows) + 1L]] <- data.frame(
    section = audit_state$current_section,
    item = item,
    status = status,
    detail = detail,
    stringsAsFactors = FALSE
  )
  invisible(NULL)
}
audit_pass <- function(item, detail = "") audit_record(item, "pass", detail)
audit_fail <- function(item, detail = "") audit_record(item, "fail", detail)
audit_skip <- function(item, detail = "") audit_record(item, "skip", detail)

section_header <- function(label) {
  message("")
  message("== ", label, " ==")
  audit_state$current_section <- label
}

audit_try <- function(item, body) {
  tryCatch(body(), error = function(e) {
    audit_fail(item, sprintf("error: %s", conditionMessage(e)))
  })
}

audit_approx_equal <- function(a, b, tol = 1e-9) {
  isTRUE(all.equal(as.numeric(a), as.numeric(b), tolerance = tol))
}

audit_ts_label <- function(x) {
  format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

# Walk candidate paths where a seed might live in run_info / provenance.
audit_extract_seed <- function(info) {
  candidates <- list(
    info$execution_seed,
    info$seed,
    info$provenance$seed,
    info$provenance$execution_seed,
    info$reproduction_key$seed,
    info$reproduction_key$execution_seed,
    info$config$seed
  )
  for (c in candidates) {
    if (!is.null(c) && length(c) > 0) return(c[[1]])
  }
  NA
}

# Walk candidate paths for a snapshot hash field.
audit_extract_snapshot_hash <- function(snap) {
  fields <- c("snapshot_hash", "hash", "data_hash", "content_hash", "ledger_hash")
  for (k in fields) {
    v <- snap$metadata[[k]]
    if (!is.null(v) && length(v) > 0 && nzchar(as.character(v))) return(v)
  }
  NULL
}

# Print whatever schema ledgr is actually returning so we can iterate fast.
audit_introspect <- function() {
  section_header("0. API introspection (schema dump)")
  audit_try("ledgr surface shapes", function() {
    bars <- audit_make_simple_bars()
    db_path <- tempfile(fileext = ".duckdb")
    on.exit(unlink(db_path), add = TRUE)
    snap <- ledgr_snapshot_from_df(bars, db_path = db_path)
    on.exit(ledgr_snapshot_close(snap), add = TRUE)
    message("  snapshot$metadata fields: ",
            paste(names(snap$metadata), collapse = ", "))
    exp <- ledgr_experiment(snapshot = snap,
                            strategy = audit_strategy_buy_once(qty = 1))
    bt <- ledgr_run(exp, run_id = "audit-introspect", seed = 2026L)
    on.exit(close(bt), add = TRUE)
    eq <- audit_get_equity(bt)
    fills <- audit_get_fills(bt)
    ledger <- audit_get_ledger(bt)
    info <- audit_get_run_info(snap, "audit-introspect")
    message("  equity cols: ", paste(names(eq), collapse = ", "))
    message("  fills cols: ", paste(names(fills), collapse = ", "))
    message("  ledger cols: ", paste(names(ledger), collapse = ", "))
    message("  run_info fields: ", paste(names(info), collapse = ", "))
    if (!is.null(info$provenance)) {
      message("  run_info$provenance fields: ",
              paste(names(info$provenance), collapse = ", "))
    }
    message("  bt object fields: ", paste(names(bt), collapse = ", "))
    audit_pass("schema dump captured")
  })
}

# ---- Toy data builders -----------------------------------------------------
#
# Schema assumed: ts_utc (POSIXct UTC), instrument_id (chr), open/high/low/close
# (num), volume (num). If ledgr_snapshot_from_df expects different column names,
# adjust here.

audit_make_simple_bars <- function() {
  # AAA: 100 -> 110 -> 120 -> 90 -> 100. open == close so fill arithmetic
  # is trivial to hand-check.
  tibble::tibble(
    ts_utc = as.POSIXct(c(
      "2024-01-01", "2024-01-02", "2024-01-03",
      "2024-01-04", "2024-01-05"
    ), tz = "UTC"),
    instrument_id = "AAA",
    open  = c(100, 110, 120,  90, 100),
    high  = c(100, 110, 120,  90, 100),
    low   = c(100, 110, 120,  90, 100),
    close = c(100, 110, 120,  90, 100),
    volume = rep(1000, 5)
  )
}

audit_make_step_bars <- function() {
  # Day-1 close (100) vs day-2 open (150) differ sharply. If a target placed
  # at the close of day 1 fills at 100, that's a lookahead/timing bug. It must
  # fill at 150 (open of next bar).
  tibble::tibble(
    ts_utc = as.POSIXct(c(
      "2024-01-01", "2024-01-02", "2024-01-03",
      "2024-01-04", "2024-01-05"
    ), tz = "UTC"),
    instrument_id = "AAA",
    open  = c(100, 150, 150, 150, 150),
    high  = c(100, 150, 150, 150, 150),
    low   = c(100, 150, 150, 150, 150),
    close = c(100, 150, 150, 150, 150),
    volume = rep(1000, 5)
  )
}

audit_make_warmup_bars <- function(n = 8) {
  # Smooth varying close prices to exercise an SMA warmup.
  tibble::tibble(
    ts_utc = as.POSIXct("2024-01-01", tz = "UTC") + (seq_len(n) - 1L) * 86400L,
    instrument_id = "AAA",
    open  = 100 + seq_len(n),
    high  = 100 + seq_len(n) + 0.5,
    low   = 100 + seq_len(n) - 0.5,
    close = 100 + seq_len(n),
    volume = rep(1000, n)
  )
}

audit_make_two_instrument_bars <- function() {
  # AAA: 100 -> 110 -> 120 -> 90 -> 100. BBB: 50 -> 55 -> 60 -> 45 -> 50.
  # open == close to keep arithmetic hand-checkable.
  times <- as.POSIXct(c(
    "2024-01-01", "2024-01-02", "2024-01-03",
    "2024-01-04", "2024-01-05"
  ), tz = "UTC")
  rbind(
    tibble::tibble(
      ts_utc = times, instrument_id = "AAA",
      open  = c(100, 110, 120,  90, 100),
      high  = c(100, 110, 120,  90, 100),
      low   = c(100, 110, 120,  90, 100),
      close = c(100, 110, 120,  90, 100),
      volume = rep(1000, 5)
    ),
    tibble::tibble(
      ts_utc = times, instrument_id = "BBB",
      open  = c( 50,  55,  60,  45,  50),
      high  = c( 50,  55,  60,  45,  50),
      low   = c( 50,  55,  60,  45,  50),
      close = c( 50,  55,  60,  45,  50),
      volume = rep(1000, 5)
    )
  )
}

audit_with_snapshot <- function(bars, body) {
  db_path <- tempfile(fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  out <- tryCatch(body(snapshot, db_path),
                  finally = {
                    try(ledgr_snapshot_close(snapshot), silent = TRUE)
                    try(unlink(db_path), silent = TRUE)
                  })
  out
}

# ---- Strategy builders -----------------------------------------------------

audit_strategy_flat <- function() {
  function(ctx, params) ctx$flat()
}

audit_strategy_buy_once <- function(qty = 1, on_first = TRUE) {
  # Always wants qty=1 in AAA. ledgr will fill the delta once.
  function(ctx, params) {
    targets <- ctx$flat()
    targets[["AAA"]] <- qty
    targets
  }
}

audit_strategy_buy_on_final <- function(n_total, qty = 1, instrument = "AAA") {
  # Counter strategy: stays flat for all pulses except the last, where it
  # emits a real delta. Used to verify LEDGR_LAST_BAR_NO_FILL.
  env <- new.env(parent = emptyenv())
  env$count <- 0L
  function(ctx, params) {
    env$count <- env$count + 1L
    targets <- ctx$flat()
    if (env$count >= n_total) {
      targets[[instrument]] <- qty
    }
    targets
  }
}

audit_strategy_sma_recorder <- function(envir, feature_id = "sma_3",
                                        instrument = "AAA") {
  # Records ctx$feature(...) values per pulse for later TTR comparison.
  function(ctx, params) {
    val <- tryCatch(ctx$feature(instrument, feature_id),
                    error = function(e) NA_real_)
    envir$sma <- c(envir$sma, val)
    envir$ts <- c(envir$ts, as.character(ctx$ts_utc))
    ctx$flat()
  }
}

audit_strategy_two_instr_hold <- function(qty_a = 1, qty_b = 1) {
  function(ctx, params) {
    targets <- ctx$flat()
    targets[["AAA"]] <- qty_a
    targets[["BBB"]] <- qty_b
    targets
  }
}

audit_strategy_round_trip <- function(buy_pulse, sell_pulse,
                                      qty = 1, instrument = "AAA") {
  # Counter-driven: hold 0 before buy_pulse, qty between buy_pulse and
  # sell_pulse, 0 from sell_pulse onward.
  env <- new.env(parent = emptyenv())
  env$count <- 0L
  function(ctx, params) {
    env$count <- env$count + 1L
    targets <- ctx$flat()
    if (env$count >= buy_pulse && env$count < sell_pulse) {
      targets[[instrument]] <- qty
    } else {
      targets[[instrument]] <- 0
    }
    targets
  }
}

audit_strategy_ctx_recorder <- function(envir) {
  # Records what ctx contains at each pulse. Used to verify no-lookahead.
  function(ctx, params) {
    bars <- ctx$bars %||% data.frame()
    envir$ts <- c(
      envir$ts,
      format(as.POSIXct(ctx$ts_utc, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    )
    envir$bars_rows <- c(envir$bars_rows, nrow(bars))
    envir$bars_ts <- c(envir$bars_ts, if (nrow(bars) == 1L && "ts_utc" %in% names(bars)) {
      format(as.POSIXct(bars$ts_utc[[1]], tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    } else {
      NA_character_
    })
    envir$bars_close <- c(envir$bars_close, if (nrow(bars) == 1L && "close" %in% names(bars)) {
      as.numeric(bars$close[[1]])
    } else {
      NA_real_
    })
    envir$equity <- c(envir$equity, ctx$equity %||% NA_real_)
    ctx$flat()
  }
}

audit_strategy_seed_dependent <- function() {
  function(ctx, params) {
    targets <- ctx$flat()
    targets[["AAA"]] <- if (identical(as.integer(ctx$seed), 1L)) 1 else 2
    targets
  }
}

audit_strategy_pulse_seed_gate <- function() {
  function(ctx, params) {
    modulus <- as.integer(params$modulus %||% 3L)
    targets <- ctx$flat()
    targets[["AAA"]] <- if (!is.null(ctx$pulse_seed) && ctx$pulse_seed %% modulus == 0L) 1 else 0
    targets
  }
}

audit_strategy_unknown_target <- function() {
  function(ctx, params) {
    # ZZZ is not in the universe.
    c(ZZZ = 1)
  }
}

audit_strategy_na_target <- function() {
  function(ctx, params) {
    targets <- ctx$flat()
    targets[["AAA"]] <- NA_real_
    targets
  }
}

`%||%` <- function(x, y) if (is.null(x)) y else x

# ---- Helpers around ledgr_run / ledgr_results ------------------------------
#
# These wrap the public API I've seen used in tests. If signatures differ,
# adjust here; the individual sections call only these helpers.

audit_run <- function(snapshot, strategy, run_id, seed = NULL, params = list()) {
  exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy)
  ledgr_run(exp, run_id = run_id, seed = seed, params = params)
}

audit_get_equity <- function(bt) ledgr_results(bt, "equity")
audit_get_fills  <- function(bt) ledgr_results(bt, "fills")
audit_get_ledger <- function(bt) ledgr_results(bt, "ledger")

audit_get_run_info <- function(snapshot, run_id) ledgr_run_info(snapshot, run_id)

# ---- Section 1: Hand-checkable arithmetic ----------------------------------

audit_section_1 <- function() {
  section_header("1. Hand-checkable arithmetic (flat strategy)")
  audit_try("flat strategy emits no fills", function() {
    audit_with_snapshot(audit_make_simple_bars(), function(snap, db) {
      bt <- audit_run(snap, audit_strategy_flat(), run_id = "audit-flat")
      on.exit(close(bt), add = TRUE)
      fills <- audit_get_fills(bt)
      if (nrow(fills) == 0L) {
        audit_pass("flat -> no fills", sprintf("nrow(fills)=%d", nrow(fills)))
      } else {
        audit_fail("flat -> no fills", sprintf("nrow(fills)=%d", nrow(fills)))
      }
    })
  })
  audit_try("flat strategy preserves cash and equity", function() {
    audit_with_snapshot(audit_make_simple_bars(), function(snap, db) {
      bt <- audit_run(snap, audit_strategy_flat(), run_id = "audit-flat-2")
      on.exit(close(bt), add = TRUE)
      eq <- audit_get_equity(bt)
      initial_cash <- eq$cash[[1]]
      # all.equal() is strict about vector length; compare element-wise instead.
      cash_const <- all(abs(eq$cash - initial_cash) < 1e-9)
      eq_const <- all(abs(eq$equity - initial_cash) < 1e-9)
      if (cash_const && eq_const) {
        audit_pass("cash + equity == initial_cash at every pulse")
      } else {
        audit_fail("cash/equity drift on flat strategy",
                   sprintf("cash range [%g, %g], equity range [%g, %g]",
                           min(eq$cash), max(eq$cash),
                           min(eq$equity), max(eq$equity)))
      }
    })
  })
}

# ---- Section 2: Next-open fill timing --------------------------------------

audit_section_2 <- function() {
  section_header("2. Next-open fill timing (step prices)")
  audit_try("buy at bar 1 fills at day-2 open (150), not day-1 close (100)",
            function() {
    audit_with_snapshot(audit_make_step_bars(), function(snap, db) {
      bt <- audit_run(snap, audit_strategy_buy_once(qty = 1),
                      run_id = "audit-next-open")
      on.exit(close(bt), add = TRUE)
      fills <- audit_get_fills(bt)
      if (nrow(fills) == 0L) {
        audit_fail("next-open fill", "no fills emitted")
        return(invisible(NULL))
      }
      price_col <- intersect(c("fill_price", "price"), names(fills))
      if (length(price_col) == 0L) {
        audit_fail("next-open fill",
                   sprintf("no price column in fills; got: %s",
                           paste(names(fills), collapse = ",")))
        return(invisible(NULL))
      }
      first_price <- fills[[price_col[[1]]]][[1]]
      if (audit_approx_equal(first_price, 150)) {
        audit_pass("first fill price == 150 (open of next bar)",
                   sprintf("via fills$%s", price_col[[1]]))
      } else if (audit_approx_equal(first_price, 100)) {
        audit_fail("first fill price == 100 (LOOKAHEAD BUG: filled at current close)")
      } else {
        audit_fail("first fill price unexpected",
                   sprintf("expected 150, got %g (fills$%s)",
                           first_price, price_col[[1]]))
      }
    })
  })
}

# ---- Section 3: Final-bar no-fill discipline -------------------------------

audit_section_3 <- function() {
  section_header("3. Final-bar no-fill discipline")
  # Real test: strategy holds flat for pulses 1..N-1, emits qty=1 only at
  # pulse N. There is no bar N+1 to fill against, so ledgr must warn and
  # produce no fill.
  audit_try("strategy targeting position on final bar triggers no-fill warning",
            function() {
    bars <- audit_make_simple_bars()  # 5 bars
    audit_with_snapshot(bars, function(snap, db) {
      warnings_seen <- character()
      bt <- withCallingHandlers(
        audit_run(snap, audit_strategy_buy_on_final(n_total = 5, qty = 1),
                  run_id = "audit-last-bar-real"),
        warning = function(w) {
          warnings_seen <<- c(warnings_seen, conditionMessage(w))
          invokeRestart("muffleWarning")
        }
      )
      on.exit(close(bt), add = TRUE)
      fills <- audit_get_fills(bt)
      saw_warning <- any(grepl("LEDGR_LAST_BAR_NO_FILL",
                               warnings_seen, fixed = TRUE))
      n_fills <- nrow(fills)
      if (saw_warning && n_fills == 0L) {
        audit_pass("warning emitted AND no fill recorded for final-bar delta")
      } else if (n_fills == 0L && !saw_warning) {
        audit_fail("no fill emitted but no warning either",
                   "expected LEDGR_LAST_BAR_NO_FILL to surface")
      } else if (saw_warning && n_fills > 0L) {
        audit_fail("warning fired but a fill was still emitted",
                   sprintf("nrow(fills)=%d", n_fills))
      } else {
        audit_fail("final-bar delta produced a fill (no warning)",
                   sprintf("nrow(fills)=%d", n_fills))
      }
    })
  })
}

# ---- Section 4: No-lookahead in pulse context -------------------------------

audit_section_4 <- function() {
  section_header("4. No-lookahead in pulse context")
  audit_try("ctx$bars exposes only current pulse, never future bars", function() {
    audit_with_snapshot(audit_make_simple_bars(), function(snap, db) {
      env <- new.env(parent = emptyenv())
      env$ts <- character()
      env$bars_rows <- integer()
      env$bars_ts <- character()
      env$bars_close <- numeric()
      env$equity <- numeric()
      bt <- audit_run(snap, audit_strategy_ctx_recorder(env),
                      run_id = "audit-no-lookahead")
      on.exit(close(bt), add = TRUE)
      max_bar_rows <- if (length(env$bars_rows) > 0) max(env$bars_rows) else 0L
      expected_ts <- audit_ts_label(audit_make_simple_bars()$ts_utc)
      expected_close <- audit_make_simple_bars()$close
      ts_match <- identical(env$bars_ts, expected_ts)
      close_match <- audit_approx_equal(env$bars_close, expected_close, tol = 1e-12)
      if (max_bar_rows <= 1L && ts_match && close_match) {
        audit_pass("ctx$bars exposes exactly the current pulse row",
                   sprintf("max bars rows seen = %d", max_bar_rows))
      } else {
        audit_fail("ctx$bars does not match current pulse rows",
                   sprintf("max_rows=%d ts_match=%s close_match=%s",
                           max_bar_rows, ts_match, close_match))
      }
    })
  })
  # Real warmup check using SMA(3): bars 1..2 should produce NA; bar 3+
  # should produce the rolling mean of close[i-2:i].
  audit_try("SMA(3) feature is NA for bars 1..2 and finite from bar 3", function() {
    bars <- audit_make_warmup_bars(8)
    audit_with_snapshot(bars, function(snap, db) {
      env <- new.env(parent = emptyenv())
      env$sma <- numeric()
      env$ts <- character()
      exp <- ledgr_experiment(snapshot = snap,
                              strategy = audit_strategy_sma_recorder(env, "sma_3", "AAA"),
                              features = list(ledgr_ind_sma(3)))
      bt <- ledgr_run(exp, run_id = "audit-warmup", seed = 2026L)
      on.exit(close(bt), add = TRUE)
      vals <- env$sma
      if (length(vals) < 4) {
        audit_fail("fewer SMA recordings than expected",
                   sprintf("got %d values", length(vals)))
        return(invisible(NULL))
      }
      warmup_na <- all(is.na(vals[1:2]))
      stable_finite <- all(is.finite(vals[3:length(vals)]))
      if (warmup_na && stable_finite) {
        audit_pass("warmup NAs on bars 1-2; finite from bar 3 onward",
                   sprintf("vals = %s",
                           paste(formatC(vals, digits = 4), collapse = ", ")))
      } else {
        audit_fail("warmup pattern wrong",
                   sprintf("warmup_na=%s stable_finite=%s vals=[%s]",
                           warmup_na, stable_finite,
                           paste(formatC(vals, digits = 4), collapse = ",")))
      }
    })
  })
}

# ---- Section 5: Accounting identities --------------------------------------

audit_section_5 <- function() {
  section_header("5. Accounting identities every pulse")
  audit_try("equity == cash + positions_value at every pulse", function() {
    audit_with_snapshot(audit_make_simple_bars(), function(snap, db) {
      bt <- audit_run(snap, audit_strategy_buy_once(qty = 1),
                      run_id = "audit-identity")
      on.exit(close(bt), add = TRUE)
      eq <- audit_get_equity(bt)
      cols <- names(eq)
      if (!all(c("cash", "positions_value", "equity") %in% cols)) {
        audit_fail("equity df missing expected columns",
                   sprintf("got: %s", paste(cols, collapse = ", ")))
        return(invisible(NULL))
      }
      diffs <- eq$equity - (eq$cash + eq$positions_value)
      max_abs_diff <- max(abs(diffs), na.rm = TRUE)
      if (max_abs_diff < 1e-9) {
        audit_pass("equity == cash + positions_value identity holds",
                   sprintf("max |diff| = %g", max_abs_diff))
      } else {
        audit_fail("accounting identity violated",
                   sprintf("max |diff| = %g", max_abs_diff))
      }
    })
  })
  audit_try("flat strategy: drawdown is always zero", function() {
    audit_with_snapshot(audit_make_simple_bars(), function(snap, db) {
      bt <- audit_run(snap, audit_strategy_flat(), run_id = "audit-flat-dd")
      on.exit(close(bt), add = TRUE)
      eq <- audit_get_equity(bt)
      if (!"drawdown" %in% names(eq)) {
        audit_skip("no drawdown column in equity df",
                   sprintf("got: %s", paste(names(eq), collapse = ",")))
        return(invisible(NULL))
      }
      max_dd_abs <- max(abs(eq$drawdown), na.rm = TRUE)
      if (max_dd_abs < 1e-12) {
        audit_pass("flat strategy drawdown == 0 throughout")
      } else {
        audit_fail("flat strategy drawdown nonzero",
                   sprintf("max |dd| = %g", max_dd_abs))
      }
    })
  })
}

# ---- Section 6: Edge-case input rejection ----------------------------------

audit_section_6 <- function() {
  section_header("6. Edge-case input rejection")
  audit_try("strategy targeting unknown instrument fails loudly", function() {
    audit_with_snapshot(audit_make_simple_bars(), function(snap, db) {
      err <- tryCatch({
        bt <- audit_run(snap, audit_strategy_unknown_target(),
                        run_id = "audit-unknown")
        close(bt)
        NULL
      }, error = function(e) e)
      if (is.null(err)) {
        audit_fail("unknown-instrument target accepted silently")
      } else {
        audit_pass("unknown-instrument target rejected",
                   sprintf("error class: %s",
                           paste(class(err), collapse = ",")))
      }
    })
  })
  audit_try("strategy returning NA target fails loudly", function() {
    audit_with_snapshot(audit_make_simple_bars(), function(snap, db) {
      err <- tryCatch({
        bt <- audit_run(snap, audit_strategy_na_target(),
                        run_id = "audit-na-target")
        close(bt)
        NULL
      }, error = function(e) e)
      if (is.null(err)) {
        audit_fail("NA target accepted silently")
      } else {
        audit_pass("NA target rejected",
                   sprintf("error class: %s",
                           paste(class(err), collapse = ",")))
      }
    })
  })
}

# ---- Section 7: Same-session reproducibility -------------------------------

audit_section_7 <- function() {
  section_header("7. Same-session reproducibility")
  audit_try("two runs same inputs -> identical equity", function() {
    audit_with_snapshot(audit_make_simple_bars(), function(snap, db) {
      bt1 <- audit_run(snap, audit_strategy_buy_once(qty = 1),
                       run_id = "audit-repro-A", seed = 2026L)
      eq1 <- audit_get_equity(bt1)
      close(bt1)
      bt2 <- audit_run(snap, audit_strategy_buy_once(qty = 1),
                       run_id = "audit-repro-B", seed = 2026L)
      eq2 <- audit_get_equity(bt2)
      close(bt2)
      if (identical(eq1$equity, eq2$equity)) {
        audit_pass("equity vectors byte-identical across runs")
      } else if (audit_approx_equal(eq1$equity, eq2$equity)) {
        audit_pass("equity vectors approx-equal (not byte-identical)",
                   "may indicate float-ordering nondeterminism")
      } else {
        audit_fail("equity vectors differ across runs")
      }
    })
  })
}

# ---- Section 8: Cross-session reproducibility via snapshot reopen ----------

audit_section_8 <- function() {
  section_header("8. Cross-session reproducibility via snapshot reopen")
  audit_try("snapshot close + reopen produces identical run output", function() {
    bars <- audit_make_simple_bars()
    db_path <- tempfile(fileext = ".duckdb")
    on.exit(unlink(db_path), add = TRUE)

    snap1 <- ledgr_snapshot_from_df(bars, db_path = db_path)
    snapshot_id <- snap1$metadata$snapshot_id
    bt1 <- audit_run(snap1, audit_strategy_buy_once(qty = 1),
                     run_id = "audit-reopen-A", seed = 2026L)
    eq1 <- audit_get_equity(bt1)
    close(bt1)
    ledgr_snapshot_close(snap1)

    snap2 <- ledgr_snapshot_load(db_path, snapshot_id)
    on.exit(ledgr_snapshot_close(snap2), add = TRUE)
    bt2 <- audit_run(snap2, audit_strategy_buy_once(qty = 1),
                     run_id = "audit-reopen-B", seed = 2026L)
    eq2 <- audit_get_equity(bt2)
    close(bt2)

    if (identical(eq1$equity, eq2$equity)) {
      audit_pass("equity byte-identical after snapshot close/reopen")
    } else {
      audit_fail("equity differs after snapshot close/reopen")
    }
  })
}

# ---- Section 9: Provenance changes when inputs change ----------------------

audit_section_9 <- function() {
  section_header("9. Provenance changes when inputs change")
  audit_try("different seeds -> different seed-aware equity AND different run info", function() {
    audit_with_snapshot(audit_make_simple_bars(), function(snap, db) {
      bt_a <- audit_run(snap, audit_strategy_seed_dependent(),
                        run_id = "audit-prov-A", seed = 1L)
      eq_a <- audit_get_equity(bt_a)
      info_a <- audit_get_run_info(snap, "audit-prov-A")
      close(bt_a)
      bt_b <- audit_run(snap, audit_strategy_seed_dependent(),
                        run_id = "audit-prov-B", seed = 2L)
      eq_b <- audit_get_equity(bt_b)
      info_b <- audit_get_run_info(snap, "audit-prov-B")
      close(bt_b)
      # Two changes expected: run_id differs (obviously) and at least one
      # provenance field (seed) differs.
      run_id_differs <- !identical(info_a$run_id, info_b$run_id)
      seed_a <- audit_extract_seed(info_a)
      seed_b <- audit_extract_seed(info_b)
      seed_differs <- !identical(seed_a, seed_b)
      config_hash_differs <- !identical(info_a$config_hash, info_b$config_hash)
      equity_differs <- !identical(eq_a$equity, eq_b$equity)
      # Seed change should propagate to at least one provenance signal:
      # the seed field directly OR config_hash (which incorporates the seed).
      if (isTRUE(run_id_differs) &&
          (isTRUE(seed_differs) || isTRUE(config_hash_differs)) &&
          isTRUE(equity_differs)) {
        if (isTRUE(seed_differs)) {
          audit_pass("seed change reflected in run-info seed and output",
                     sprintf("seed_a=%s seed_b=%s", seed_a, seed_b))
        } else {
          audit_pass("seed change reflected via config_hash and output",
                     sprintf("hash_a=%s hash_b=%s",
                             substr(as.character(info_a$config_hash), 1, 12),
                             substr(as.character(info_b$config_hash), 1, 12)))
        }
      } else {
        audit_fail("seed change not reflected in provenance",
                   sprintf("run_id_differs=%s seed_differs=%s config_hash_differs=%s equity_differs=%s",
                           run_id_differs, seed_differs,
                           config_hash_differs, equity_differs))
      }
    })
  })
}

# ---- Section 10: Independent backtester cross-check ------------------------

audit_dumb_backtester <- function(bars, strategy_logic,
                                  initial_cash = 1e6,
                                  commission_per_share = 0) {
  # Minimal next-open fill emulator. strategy_logic is a function that takes
  # (i, prices_so_far, current_position, current_cash) and returns a desired
  # position quantity for AAA at pulse i. Fills happen at open[i+1]; no fill
  # if i == nrow(bars).
  n <- nrow(bars)
  cash <- initial_cash
  position <- 0
  equity <- numeric(n)
  fills <- list()
  for (i in seq_len(n)) {
    # Strategy sees bars[1..i] only.
    desired <- strategy_logic(i, bars[1:i, , drop = FALSE], position, cash)
    delta <- desired - position
    # equity uses current pulse close (mark-to-market).
    equity[i] <- cash + position * bars$close[[i]]
    if (abs(delta) > sqrt(.Machine$double.eps) && i < n) {
      fill_price <- bars$open[[i + 1L]]
      cash <- cash - delta * fill_price - abs(delta) * commission_per_share
      position <- desired
      fills[[length(fills) + 1L]] <- data.frame(
        ts = bars$ts_utc[[i]], price = fill_price, qty = delta,
        stringsAsFactors = FALSE
      )
    }
  }
  list(equity = equity, fills = do.call(rbind, fills) %||% data.frame(),
       final_cash = cash, final_position = position)
}

audit_section_10 <- function() {
  section_header("10. Independent backtester cross-check")
  audit_try("dumb-backtester equity matches ledgr on buy-once toy case", function() {
    bars <- audit_make_simple_bars()
    audit_with_snapshot(bars, function(snap, db) {
      bt <- audit_run(snap, audit_strategy_buy_once(qty = 1),
                      run_id = "audit-dumb-cross")
      on.exit(close(bt), add = TRUE)
      eq_ledgr <- audit_get_equity(bt)
      initial_cash <- eq_ledgr$cash[[1]]
      dumb <- audit_dumb_backtester(
        bars,
        strategy_logic = function(i, prices, pos, cash) 1,
        initial_cash = initial_cash
      )
      # ledgr's first pulse equity is initial_cash (position == 0 at start).
      # Dumb backtester also has equity[1] = initial_cash because position
      # before bar 1 is 0.
      diffs <- eq_ledgr$equity - dumb$equity
      max_abs_diff <- max(abs(diffs), na.rm = TRUE)
      if (max_abs_diff < 1e-6) {
        audit_pass("equity matches independent implementation",
                   sprintf("max |diff| = %g", max_abs_diff))
      } else {
        audit_fail("equity differs from independent implementation",
                   sprintf("ledgr=[%s] dumb=[%s] max|diff|=%g",
                           paste(round(eq_ledgr$equity, 2), collapse = ","),
                           paste(round(dumb$equity, 2), collapse = ","),
                           max_abs_diff))
      }
    })
  })
}

# ---- Section 11: Indicator parity vs TTR -----------------------------------

audit_section_11 <- function() {
  section_header("11. Indicator parity vs TTR")
  audit_try("ledgr SMA(3) matches TTR::SMA(close, 3) row-by-row", function() {
    if (!requireNamespace("TTR", quietly = TRUE)) {
      audit_skip("TTR not installed")
      return(invisible(NULL))
    }
    bars <- audit_make_warmup_bars(8)
    audit_with_snapshot(bars, function(snap, db) {
      env <- new.env(parent = emptyenv())
      env$sma <- numeric()
      exp <- ledgr_experiment(snapshot = snap,
                              strategy = audit_strategy_sma_recorder(env, "sma_3", "AAA"),
                              features = list(ledgr_ind_sma(3)))
      bt <- ledgr_run(exp, run_id = "audit-sma-parity", seed = 2026L)
      on.exit(close(bt), add = TRUE)
      ledgr_vals <- env$sma
      ttr_vals <- as.numeric(TTR::SMA(bars$close, n = 3))
      if (length(ledgr_vals) != length(ttr_vals)) {
        audit_fail("length mismatch ledgr vs TTR",
                   sprintf("ledgr=%d TTR=%d", length(ledgr_vals), length(ttr_vals)))
        return(invisible(NULL))
      }
      na_match <- all(is.na(ledgr_vals) == is.na(ttr_vals))
      finite_idx <- which(is.finite(ttr_vals))
      if (length(finite_idx) == 0L) {
        audit_fail("no finite TTR values to compare")
        return(invisible(NULL))
      }
      max_diff <- max(abs(ledgr_vals[finite_idx] - ttr_vals[finite_idx]))
      if (na_match && max_diff < 1e-9) {
        audit_pass(sprintf("SMA(3) byte-aligned with TTR (max |diff| = %g, N=%d)",
                           max_diff, length(finite_idx)))
      } else {
        audit_fail("SMA(3) diverges from TTR",
                   sprintf("na_match=%s max|diff|=%g", na_match, max_diff))
      }
    })
  })
}

# ---- Section 12: Metric oracles --------------------------------------------

audit_independent_metrics <- function(equity, bars_per_year = 252) {
  rets <- diff(equity) / head(equity, -1)
  total_return <- equity[length(equity)] / equity[[1]] - 1
  ann_return <- if (length(rets) > 0) {
    (1 + mean(rets, na.rm = TRUE))^bars_per_year - 1
  } else {
    NA_real_
  }
  ann_vol <- if (length(rets) > 0) {
    stats::sd(rets, na.rm = TRUE) * sqrt(bars_per_year)
  } else {
    NA_real_
  }
  sharpe <- if (is.finite(ann_vol) && ann_vol > 0) ann_return / ann_vol else NA_real_
  peak <- cummax(equity)
  drawdown <- (equity - peak) / peak
  max_dd <- min(drawdown, na.rm = TRUE)
  list(total_return = total_return, ann_return = ann_return,
       ann_vol = ann_vol, sharpe = sharpe, max_dd = max_dd)
}

audit_section_12 <- function() {
  section_header("12. Metric oracles on a known equity curve")
  audit_try("max drawdown on synthetic equity matches independent formula", function() {
    # Equity: 100, 120, 90, 150 -> peak 120 at i=2, trough 90 at i=3 -> DD = -25%.
    eq_vec <- c(100, 120, 90, 150)
    mets <- audit_independent_metrics(eq_vec)
    expected_dd <- (90 - 120) / 120
    if (audit_approx_equal(mets$max_dd, expected_dd, tol = 1e-12)) {
      audit_pass("synthetic max_dd = -25%",
                 sprintf("got %g", mets$max_dd))
    } else {
      audit_fail("max_dd formula wrong",
                 sprintf("expected %g, got %g", expected_dd, mets$max_dd))
    }
  })
  audit_try("ledgr run_info total_return matches independent computation", function() {
    audit_with_snapshot(audit_make_simple_bars(), function(snap, db) {
      bt <- audit_run(snap, audit_strategy_buy_once(qty = 1),
                      run_id = "audit-metrics")
      eq <- audit_get_equity(bt)
      close(bt)
      info <- audit_get_run_info(snap, "audit-metrics")
      # run_info carries final_equity, max_drawdown, total_return, n_trades.
      indep <- audit_independent_metrics(eq$equity)
      ledgr_total <- info$total_return
      ledgr_dd <- info$max_drawdown
      ledgr_final <- info$final_equity
      if (is.null(ledgr_total) || is.null(ledgr_dd) || is.null(ledgr_final)) {
        audit_skip("run_info missing one of total_return/max_drawdown/final_equity")
        return(invisible(NULL))
      }
      total_ok <- audit_approx_equal(ledgr_total, indep$total_return, tol = 1e-9)
      dd_ok <- audit_approx_equal(ledgr_dd, indep$max_dd, tol = 1e-9)
      final_ok <- audit_approx_equal(ledgr_final, eq$equity[[length(eq$equity)]], tol = 1e-9)
      if (total_ok && dd_ok && final_ok) {
        audit_pass(sprintf("run_info matches: total_return=%g max_dd=%g final=%g",
                           ledgr_total, ledgr_dd, ledgr_final))
      } else {
        audit_fail("run_info metrics diverge from independent",
                   sprintf("total ledgr=%g indep=%g (%s); max_dd ledgr=%g indep=%g (%s); final ledgr=%g indep=%g (%s)",
                           ledgr_total, indep$total_return, total_ok,
                           ledgr_dd, indep$max_dd, dd_ok,
                           ledgr_final, eq$equity[[length(eq$equity)]], final_ok))
      }
    })
  })
}

# ---- Section A: Event-stream replay parity (durable round-trip) ------------

audit_section_A <- function() {
  section_header("A. Event-stream replay parity (durable round-trip)")
  audit_try("results after backtest close + reopen match in-session results", function() {
    bars <- audit_make_simple_bars()
    db_path <- tempfile(fileext = ".duckdb")
    on.exit(unlink(db_path), add = TRUE)
    snap <- ledgr_snapshot_from_df(bars, db_path = db_path)
    snapshot_id <- snap$metadata$snapshot_id
    bt <- audit_run(snap, audit_strategy_buy_once(qty = 1),
                    run_id = "audit-replay", seed = 2026L)
    eq_in_session <- audit_get_equity(bt)
    ledger_in_session <- audit_get_ledger(bt)
    close(bt)
    ledgr_snapshot_close(snap)

    snap2 <- ledgr_snapshot_load(db_path, snapshot_id)
    on.exit(ledgr_snapshot_close(snap2), add = TRUE)
    # Try the Batch 3 test pattern: ledgr:::new_ledgr_backtest(run_id, db_path, cfg).
    # If that doesn't work, try the public ledgr_run with the same run_id
    # (some packages dedupe by run_id; if not, this will conflict and we SKIP).
    bt2 <- NULL
    bt2 <- tryCatch(
      ledgr:::new_ledgr_backtest("audit-replay", db_path, NULL),
      error = function(e) NULL
    )
    if (is.null(bt2)) {
      exp2 <- ledgr_experiment(snapshot = snap2,
                               strategy = audit_strategy_buy_once(qty = 1))
      bt2 <- tryCatch(ledgr_run(exp2, run_id = "audit-replay", seed = 2026L),
                      error = function(e) NULL)
    }
    if (is.null(bt2)) {
      audit_skip("could not reopen run by id; both new_ledgr_backtest and ledgr_run failed")
      return(invisible(NULL))
    }
    on.exit(close(bt2), add = TRUE)
    eq_replayed <- audit_get_equity(bt2)
    ledger_replayed <- audit_get_ledger(bt2)
    equity_ok <- identical(eq_in_session$equity, eq_replayed$equity)
    ledger_ok <- identical(ledger_in_session, ledger_replayed)
    if (equity_ok && ledger_ok) {
      audit_pass("equity and ledger byte-identical after durable round-trip")
    } else {
      audit_fail("durable round-trip replay differs",
                 sprintf("equity_ok=%s ledger_ok=%s max_equity_diff=%g ledger_rows=%d/%d",
                         equity_ok,
                         ledger_ok,
                         max(abs(eq_in_session$equity - eq_replayed$equity)),
                         nrow(ledger_in_session),
                         nrow(ledger_replayed)))
    }
  })
}

# ---- Section B: Sweep candidate parity vs direct run -----------------------

audit_section_B <- function() {
  section_header("B. Sweep candidate parity vs direct run")
  audit_try("promoted candidate equity matches direct run with same execution_seed",
            function() {
    audit_with_snapshot(audit_make_simple_bars(), function(snap, db) {
      exp <- ledgr_experiment(snapshot = snap,
                              strategy = audit_strategy_pulse_seed_gate())
      grid <- ledgr_param_grid(candidate = list(modulus = 3L))
      results <- ledgr_sweep(exp, grid, seed = 2026L)
      candidate <- ledgr_candidate(results, "candidate")
      promoted <- suppressWarnings(
        ledgr_promote(exp, candidate, run_id = "audit-sweep-promoted")
      )
      direct <- suppressWarnings(
        ledgr_run(exp, params = candidate$params,
                  run_id = "audit-sweep-direct",
                  seed = candidate$execution_seed)
      )
      eq_p <- audit_get_equity(promoted)
      eq_d <- audit_get_equity(direct)
      close(promoted); close(direct)
      if (identical(eq_p$equity, eq_d$equity)) {
        audit_pass("sweep promotion == direct run with execution_seed")
      } else {
        audit_fail("sweep promotion diverges from direct run")
      }
    })
  })
}

# ---- Section C: Snapshot hash stable across reopen -------------------------

audit_section_C <- function() {
  section_header("C. Snapshot hash stable across reopen")
  audit_try("snapshot_hash from run_info stable across snapshot reopen", function() {
    # snapshot$metadata doesn't carry the hash directly; run_info does.
    # So we run once per lifecycle to extract the hash.
    bars <- audit_make_simple_bars()
    db_path <- tempfile(fileext = ".duckdb")
    on.exit(unlink(db_path), add = TRUE)

    snap1 <- ledgr_snapshot_from_df(bars, db_path = db_path)
    snapshot_id <- snap1$metadata$snapshot_id
    bt1 <- audit_run(snap1, audit_strategy_flat(),
                     run_id = "audit-hash-A", seed = 2026L)
    close(bt1)
    info1 <- audit_get_run_info(snap1, "audit-hash-A")
    hash1 <- info1$snapshot_hash
    ledgr_snapshot_close(snap1)

    snap2 <- ledgr_snapshot_load(db_path, snapshot_id)
    on.exit(ledgr_snapshot_close(snap2), add = TRUE)
    bt2 <- audit_run(snap2, audit_strategy_flat(),
                     run_id = "audit-hash-B", seed = 2026L)
    close(bt2)
    info2 <- audit_get_run_info(snap2, "audit-hash-B")
    hash2 <- info2$snapshot_hash

    if (!is.null(hash1) && !is.null(hash2) && identical(hash1, hash2)) {
      audit_pass(sprintf("snapshot_hash stable across reopen: %s",
                         substr(as.character(hash1), 1, 20)))
    } else if (is.null(hash1) || is.null(hash2)) {
      audit_skip("snapshot_hash missing from run_info")
    } else {
      audit_fail(sprintf("snapshot_hash changed: %s -> %s",
                         substr(as.character(hash1), 1, 20),
                         substr(as.character(hash2), 1, 20)))
    }
  })
}

# ---- Section D: Resume = continuous parity ---------------------------------

audit_section_D <- function() {
  section_header("D. Resume == continuous parity (deterministic strategy)")
  audit_try("resumed run matches continuous run byte-identically", function() {
    # Two parallel paths: one continuous, one stopped at max_pulses=2 then
    # resumed to the end.
    bars <- audit_make_warmup_bars(8)
    db_clean <- tempfile(fileext = ".duckdb")
    db_resume <- tempfile(fileext = ".duckdb")
    on.exit(unlink(c(db_clean, db_resume)), add = TRUE)
    snap_clean <- ledgr_snapshot_from_df(bars, db_path = db_clean)
    snap_resume <- ledgr_snapshot_from_df(bars, db_path = db_resume)
    on.exit(ledgr_snapshot_close(snap_clean), add = TRUE)
    on.exit(ledgr_snapshot_close(snap_resume), add = TRUE)

    bt_clean <- audit_run(snap_clean, audit_strategy_buy_once(qty = 1),
                          run_id = "audit-resume-clean", seed = 2026L)
    eq_clean <- audit_get_equity(bt_clean)
    close(bt_clean)
    clean_initial_cash <- eq_clean$cash[[1]]

    # Start a partial run via ledgr:::ledgr_backtest_run_internal (per Batch 3
    # test pattern), then resume. Match initial_cash to the clean path so the
    # comparison isolates resume behavior, not initial-cash defaults.
    cfg_resume <- tryCatch(
      ledgr_config(
        snapshot = snap_resume,
        universe = "AAA",
        strategy = audit_strategy_buy_once(qty = 1),
        backtest = ledgr_backtest_config(
          start = snap_resume$metadata$start_date,
          end = snap_resume$metadata$end_date,
          initial_cash = clean_initial_cash
        ),
        db_path = db_resume,
        seed = 2026L
      ),
      error = function(e) NULL
    )
    if (is.null(cfg_resume)) {
      audit_skip("ledgr_config not callable as guessed; check API surface for partial-run path")
      return(invisible(NULL))
    }
    ledgr:::ledgr_backtest_run_internal(
      cfg_resume,
      run_id = "audit-resume-cont",
      control = list(max_pulses = 3L)
    )
    suppressWarnings(ledgr_backtest_run(cfg_resume, run_id = "audit-resume-cont"))
    bt_resumed <- ledgr:::new_ledgr_backtest(
      "audit-resume-cont", db_resume, cfg_resume
    )
    on.exit(close(bt_resumed), add = TRUE)
    eq_resumed <- audit_get_equity(bt_resumed)
    if (identical(eq_clean$equity, eq_resumed$equity)) {
      audit_pass("equity byte-identical for continuous vs resumed")
    } else {
      audit_fail("resumed run diverges from continuous",
                 sprintf("max |diff| = %g",
                         max(abs(eq_clean$equity - eq_resumed$equity))))
    }
  })
}

# ---- Section E: pulse_seed derivation independent of ambient RNG -----------

audit_section_E <- function() {
  section_header("E. pulse_seed derivation independent of ambient RNG")
  audit_try("ledgr:::ledgr_derive_pulse_seed stable across runif interleave",
            function() {
    set.seed(1)
    a <- ledgr:::ledgr_derive_pulse_seed(350931654L, 7L)
    stats::runif(20)
    b <- ledgr:::ledgr_derive_pulse_seed(350931654L, 7L)
    if (identical(a, b)) {
      audit_pass(sprintf("identical across ambient RNG state: %s", a))
    } else {
      audit_fail(sprintf("differ across ambient RNG: %s vs %s", a, b))
    }
  })
  audit_try("pulse_seed differs across pulse_idx", function() {
    s1 <- ledgr:::ledgr_derive_pulse_seed(2026L, 1L)
    s2 <- ledgr:::ledgr_derive_pulse_seed(2026L, 2L)
    if (!identical(s1, s2)) {
      audit_pass("adjacent pulse_idx produce different seeds")
    } else {
      audit_fail("adjacent pulse_idx produce identical seeds")
    }
  })
  audit_try("pulse_seed(NULL, ...) returns NULL", function() {
    res <- ledgr:::ledgr_derive_pulse_seed(NULL, 1L)
    if (is.null(res)) {
      audit_pass("NULL execution_seed -> NULL pulse_seed")
    } else {
      audit_fail("NULL execution_seed produced non-NULL pulse_seed")
    }
  })
}

# ---- Section F: Two runs same inputs -> byte-identical events --------------

audit_section_F <- function() {
  section_header("F. Two runs same inputs -> byte-identical event stream")
  audit_try("ledger contents identical modulo run_id and event_id", function() {
    audit_with_snapshot(audit_make_simple_bars(), function(snap, db) {
      bt1 <- audit_run(snap, audit_strategy_buy_once(qty = 1),
                       run_id = "audit-ledger-A", seed = 2026L)
      led1 <- audit_get_ledger(bt1)
      close(bt1)
      bt2 <- audit_run(snap, audit_strategy_buy_once(qty = 1),
                       run_id = "audit-ledger-B", seed = 2026L)
      led2 <- audit_get_ledger(bt2)
      close(bt2)
      strip_identity <- function(df) {
        df[, !names(df) %in% c("run_id", "event_id"), drop = FALSE]
      }
      a <- strip_identity(led1)
      b <- strip_identity(led2)
      if (identical(a, b)) {
        audit_pass(sprintf("ledger byte-identical (%d rows each)", nrow(a)))
      } else {
        audit_fail("ledger differs across runs with identical inputs",
                   sprintf("nrow A=%d B=%d", nrow(a), nrow(b)))
      }
    })
  })
}

# ---- Section G: Multi-instrument accounting --------------------------------

audit_section_G <- function() {
  section_header("G. Multi-instrument accounting")
  audit_try("two-instrument hold: positions_value = sum across instruments",
            function() {
    bars <- audit_make_two_instrument_bars()
    audit_with_snapshot(bars, function(snap, db) {
      bt <- audit_run(snap, audit_strategy_two_instr_hold(qty_a = 1, qty_b = 1),
                      run_id = "audit-multi-instr", seed = 2026L)
      on.exit(close(bt), add = TRUE)
      eq <- audit_get_equity(bt)
      # After bar-1 buy targets, AAA + BBB each held 1 share from pulse 2 onward.
      # close_A: 100, 110, 120, 90, 100; close_B: 50, 55, 60, 45, 50.
      # At pulse 1 there's no position yet, so positions_value=0.
      # At pulse i>=2: positions_value = close_A[i] + close_B[i].
      expected_pv <- c(0,
                       bars$close[bars$instrument_id == "AAA"][2] +
                         bars$close[bars$instrument_id == "BBB"][2],
                       bars$close[bars$instrument_id == "AAA"][3] +
                         bars$close[bars$instrument_id == "BBB"][3],
                       bars$close[bars$instrument_id == "AAA"][4] +
                         bars$close[bars$instrument_id == "BBB"][4],
                       bars$close[bars$instrument_id == "AAA"][5] +
                         bars$close[bars$instrument_id == "BBB"][5])
      diffs <- eq$positions_value - expected_pv
      max_diff <- max(abs(diffs), na.rm = TRUE)
      if (max_diff < 1e-9) {
        audit_pass("positions_value tracks AAA+BBB mark-to-market exactly",
                   sprintf("max |diff| = %g, expected=%s, got=%s",
                           max_diff,
                           paste(expected_pv, collapse = ","),
                           paste(eq$positions_value, collapse = ",")))
      } else {
        audit_fail("multi-instrument positions_value diverges",
                   sprintf("expected=%s got=%s max|diff|=%g",
                           paste(expected_pv, collapse = ","),
                           paste(eq$positions_value, collapse = ","),
                           max_diff))
      }
    })
  })
  audit_try("multi-instrument equity identity: equity = cash + positions_value",
            function() {
    bars <- audit_make_two_instrument_bars()
    audit_with_snapshot(bars, function(snap, db) {
      bt <- audit_run(snap, audit_strategy_two_instr_hold(qty_a = 1, qty_b = 1),
                      run_id = "audit-multi-identity", seed = 2026L)
      on.exit(close(bt), add = TRUE)
      eq <- audit_get_equity(bt)
      diffs <- eq$equity - (eq$cash + eq$positions_value)
      if (max(abs(diffs), na.rm = TRUE) < 1e-9) {
        audit_pass("equity == cash + positions_value across two instruments")
      } else {
        audit_fail("identity violated",
                   sprintf("max |diff| = %g", max(abs(diffs), na.rm = TRUE)))
      }
    })
  })
}

# ---- Section H: Costs and fees ---------------------------------------------

audit_section_H <- function() {
  section_header("H. Costs and fees (commission_fixed)")
  audit_try("fixed commission per fill is deducted from cash", function() {
    bars <- audit_make_simple_bars()
    audit_with_snapshot(bars, function(snap, db) {
      fee <- 5
      exp <- ledgr_experiment(
        snapshot = snap,
        strategy = audit_strategy_buy_once(qty = 1),
        fill_model = list(type = "next_open",
                          spread_bps = 0,
                          commission_fixed = fee)
      )
      bt <- ledgr_run(exp, run_id = "audit-fee", seed = 2026L)
      on.exit(close(bt), add = TRUE)
      eq <- audit_get_equity(bt)
      fills <- audit_get_fills(bt)
      if (nrow(fills) == 0L) {
        audit_fail("no fills emitted for fee test")
        return(invisible(NULL))
      }
      # ledgr default opening cash is 100,000. Buy 1 @ open[2] = 110 with fee 5
      # leaves cash = 100000 - 110 - 5 = 99885 from pulse 2 onward.
      initial_cash <- eq$cash[[1]]
      expected_post <- initial_cash - 110 - fee
      observed_post <- eq$cash[[length(eq$cash)]]
      if (audit_approx_equal(observed_post, expected_post, tol = 1e-9)) {
        audit_pass(sprintf("cash after fee deduction: %g (initial %g - 110 - %g)",
                           observed_post, initial_cash, fee))
      } else {
        audit_fail("cash after fee not matching",
                   sprintf("expected %g got %g", expected_post, observed_post))
      }
      # Also check that fills$fee column carries the fee value.
      if ("fee" %in% names(fills)) {
        fee_in_fill <- fills$fee[[1]]
        if (audit_approx_equal(fee_in_fill, fee, tol = 1e-9)) {
          audit_pass(sprintf("fills$fee column carries the configured fee: %g",
                             fee_in_fill))
        } else {
          audit_fail(sprintf("fills$fee = %g, expected %g",
                             fee_in_fill, fee))
        }
      }
    })
  })
  audit_try("spread_bps applies to fill price on buy leg", function() {
    bars <- audit_make_simple_bars()
    audit_with_snapshot(bars, function(snap, db) {
      bps <- 50  # 0.5% per leg
      exp <- ledgr_experiment(
        snapshot = snap,
        strategy = audit_strategy_buy_once(qty = 1),
        fill_model = list(type = "next_open",
                          spread_bps = bps,
                          commission_fixed = 0)
      )
      bt <- ledgr_run(exp, run_id = "audit-spread", seed = 2026L)
      on.exit(close(bt), add = TRUE)
      fills <- audit_get_fills(bt)
      if (nrow(fills) == 0L) {
        audit_fail("no fills for spread test")
        return(invisible(NULL))
      }
      # Per docs: buys fill at open * (1 + spread_bps/10000).
      expected_fill <- 110 * (1 + bps / 10000)
      observed_fill <- fills$price[[1]]
      if (audit_approx_equal(observed_fill, expected_fill, tol = 1e-6)) {
        audit_pass(sprintf("buy fill at open * (1 + bps/10000): %g",
                           observed_fill))
      } else {
        audit_fail(sprintf("spread fill price wrong: expected %g got %g",
                           expected_fill, observed_fill))
      }
    })
  })
}

# ---- Section I: Round-trip P&L ---------------------------------------------

audit_section_I <- function() {
  section_header("I. Round-trip realized P&L")
  audit_try("buy at bar 1, sell at bar 3: realized_pnl matches hand calc", function() {
    bars <- audit_make_simple_bars()
    audit_with_snapshot(bars, function(snap, db) {
      bt <- audit_run(snap, audit_strategy_round_trip(
        buy_pulse = 1, sell_pulse = 3, qty = 1),
        run_id = "audit-roundtrip", seed = 2026L)
      on.exit(close(bt), add = TRUE)
      fills <- audit_get_fills(bt)
      if (nrow(fills) < 2L) {
        audit_fail("expected 2 fills (buy + sell)",
                   sprintf("got %d", nrow(fills)))
        return(invisible(NULL))
      }
      # Bar 1: target 1, fills at open[2]=110 (BUY).
      # Bar 3: target 0, fills at open[4]=90 (SELL).
      # Realized P&L on sell = (sell_price - buy_price) * qty = (90 - 110) * 1 = -20.
      buy_row <- fills[fills$side == "BUY", ][1, ]
      sell_row <- fills[fills$side == "SELL", ][1, ]
      buy_ok <- audit_approx_equal(buy_row$price, 110, tol = 1e-9)
      sell_ok <- audit_approx_equal(sell_row$price, 90, tol = 1e-9)
      expected_pnl <- -20
      observed_pnl <- sell_row$realized_pnl
      pnl_ok <- audit_approx_equal(observed_pnl, expected_pnl, tol = 1e-9)
      if (buy_ok && sell_ok && pnl_ok) {
        audit_pass(sprintf("round-trip: buy@110 sell@90 realized_pnl=%g",
                           observed_pnl))
      } else {
        audit_fail(sprintf(
          "round-trip P&L mismatch (buy_ok=%s sell_ok=%s pnl_ok=%s)",
          buy_ok, sell_ok, pnl_ok),
          sprintf("buy_price=%g sell_price=%g realized_pnl=%g (expected %g)",
                  buy_row$price, sell_row$price,
                  observed_pnl, expected_pnl))
      }
    })
  })
  audit_try("cash after round-trip matches hand calc", function() {
    bars <- audit_make_simple_bars()
    audit_with_snapshot(bars, function(snap, db) {
      bt <- audit_run(snap, audit_strategy_round_trip(
        buy_pulse = 1, sell_pulse = 3, qty = 1),
        run_id = "audit-roundtrip-cash", seed = 2026L)
      on.exit(close(bt), add = TRUE)
      eq <- audit_get_equity(bt)
      initial_cash <- eq$cash[[1]]
      # Cash after buy: initial - 110.
      # Cash after sell: initial - 110 + 90 = initial - 20.
      expected_final_cash <- initial_cash - 20
      observed_final_cash <- eq$cash[[length(eq$cash)]]
      if (audit_approx_equal(observed_final_cash, expected_final_cash, tol = 1e-9)) {
        audit_pass(sprintf("final cash %g == initial %g - 20",
                           observed_final_cash, initial_cash))
      } else {
        audit_fail(sprintf("final cash %g != expected %g",
                           observed_final_cash, expected_final_cash))
      }
    })
  })
}

# ---- Section J: Dirty input rejection --------------------------------------

audit_section_J <- function() {
  section_header("J. Dirty input rejection")
  audit_try("duplicate timestamps in same instrument rejected", function() {
    bars <- tibble::tibble(
      ts_utc = as.POSIXct(c("2024-01-01", "2024-01-01", "2024-01-02"), tz = "UTC"),
      instrument_id = "AAA",
      open = c(100, 100, 110), high = c(100, 100, 110),
      low = c(100, 100, 110), close = c(100, 100, 110),
      volume = rep(1000, 3)
    )
    err <- tryCatch({
      db_path <- tempfile(fileext = ".duckdb")
      on.exit(unlink(db_path), add = TRUE)
      snap <- ledgr_snapshot_from_df(bars, db_path = db_path)
      try(ledgr_snapshot_close(snap), silent = TRUE)
      NULL
    }, error = function(e) e)
    if (is.null(err)) {
      audit_fail("duplicate timestamps accepted silently")
    } else {
      audit_pass("duplicate timestamps rejected",
                 sprintf("error class: %s",
                         paste(head(class(err), 3), collapse = ",")))
    }
  })
  audit_try("NA in price columns rejected", function() {
    bars <- tibble::tibble(
      ts_utc = as.POSIXct(c("2024-01-01", "2024-01-02", "2024-01-03"), tz = "UTC"),
      instrument_id = "AAA",
      open = c(100, NA_real_, 110), high = c(100, 110, 110),
      low = c(100, 110, 110), close = c(100, 110, 110),
      volume = rep(1000, 3)
    )
    err <- tryCatch({
      db_path <- tempfile(fileext = ".duckdb")
      on.exit(unlink(db_path), add = TRUE)
      snap <- ledgr_snapshot_from_df(bars, db_path = db_path)
      try(ledgr_snapshot_close(snap), silent = TRUE)
      NULL
    }, error = function(e) e)
    if (is.null(err)) {
      audit_fail("NA price accepted silently")
    } else {
      audit_pass("NA price rejected",
                 sprintf("error class: %s",
                         paste(head(class(err), 3), collapse = ",")))
    }
  })
  audit_try("missing required column rejected", function() {
    bars <- tibble::tibble(
      ts_utc = as.POSIXct(c("2024-01-01", "2024-01-02"), tz = "UTC"),
      instrument_id = "AAA",
      # missing 'close'
      open = c(100, 110), high = c(100, 110), low = c(100, 110),
      volume = c(1000, 1000)
    )
    err <- tryCatch({
      db_path <- tempfile(fileext = ".duckdb")
      on.exit(unlink(db_path), add = TRUE)
      snap <- ledgr_snapshot_from_df(bars, db_path = db_path)
      try(ledgr_snapshot_close(snap), silent = TRUE)
      NULL
    }, error = function(e) e)
    if (is.null(err)) {
      audit_fail("missing 'close' column accepted silently")
    } else {
      audit_pass("missing required column rejected",
                 sprintf("error class: %s",
                         paste(head(class(err), 3), collapse = ",")))
    }
  })
  audit_try("negative price rejected", function() {
    bars <- tibble::tibble(
      ts_utc = as.POSIXct(c("2024-01-01", "2024-01-02"), tz = "UTC"),
      instrument_id = "AAA",
      open = c(100, -110), high = c(100, 110),
      low = c(100, -110), close = c(100, -110),
      volume = c(1000, 1000)
    )
    err <- tryCatch({
      db_path <- tempfile(fileext = ".duckdb")
      on.exit(unlink(db_path), add = TRUE)
      snap <- ledgr_snapshot_from_df(bars, db_path = db_path)
      try(ledgr_snapshot_close(snap), silent = TRUE)
      NULL
    }, error = function(e) e)
    if (is.null(err)) {
      audit_skip("negative price accepted (not currently a hard input-rejection contract)",
                 "not a hard rejection; reasonable in some markets")
    } else {
      audit_pass("negative price rejected",
                 sprintf("error class: %s",
                         paste(head(class(err), 3), collapse = ",")))
    }
  })
}

# ---- Summary ---------------------------------------------------------------

audit_summary <- function() {
  rows <- do.call(rbind, audit_state$rows)
  if (is.null(rows) || nrow(rows) == 0L) {
    message("\n(no rows recorded)")
    return(invisible(NULL))
  }
  message("")
  message("==================== AUDIT SUMMARY ====================")
  totals <- table(factor(rows$status, levels = c("pass", "fail", "skip")))
  message(sprintf("  PASS: %d   FAIL: %d   SKIP: %d   (total: %d)",
                  totals[["pass"]], totals[["fail"]], totals[["skip"]],
                  nrow(rows)))
  message("")
  per_section <- by(rows, rows$section, function(g) {
    sprintf("  %-60s  pass=%d fail=%d skip=%d",
            unique(g$section),
            sum(g$status == "pass"),
            sum(g$status == "fail"),
            sum(g$status == "skip"))
  })
  for (line in per_section) message(line)
  if (any(rows$status == "fail")) {
    message("")
    message("---- FAILURES ----")
    fails <- rows[rows$status == "fail", , drop = FALSE]
    for (i in seq_len(nrow(fails))) {
      message(sprintf("  [FAIL] %s -- %s -- %s",
                      fails$section[[i]], fails$item[[i]], fails$detail[[i]]))
    }
  }
  invisible(rows)
}

# ---- Main runner -----------------------------------------------------------

audit_main <- function() {
  message("ledgr verification audit, ", format(Sys.time(), tz = "UTC"))
  message("loaded via: ",
          if (isNamespaceLoaded("ledgr") &&
              "pkgload" %in% loadedNamespaces()) "pkgload::load_all" else "library(ledgr)")
  audit_introspect()
  audit_section_1()
  audit_section_2()
  audit_section_3()
  audit_section_4()
  audit_section_5()
  audit_section_6()
  audit_section_7()
  audit_section_8()
  audit_section_9()
  audit_section_10()
  audit_section_11()
  audit_section_12()
  audit_section_A()
  audit_section_B()
  audit_section_C()
  audit_section_D()
  audit_section_E()
  audit_section_F()
  audit_section_G()
  audit_section_H()
  audit_section_I()
  audit_section_J()
  audit_summary()
}

if (sys.nframe() == 0L) {
  audit_main()
}
