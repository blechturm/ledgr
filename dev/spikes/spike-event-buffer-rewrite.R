# Spike: event-buffer write anti-pattern vs proposed fixes (base R and collapse)
#
# Context: the LDG-2456/2457 real-run profile attributes ~72-82% of fold-loop R
# time to the per-event ledger buffer write (`handler$buffer_event`, sweep
# `append_event_row_list`). See inst/design/audits/fold_path_hotpath_audit.md
# finding #1. This spike isolates that write and compares the current
# anti-pattern against two fixes, timing everything.
#
# FAITHFULNESS: this replicates the REAL handler structure -- a factory builds a
# `state` env; a separate closure mutates it per event (cross-frame, the
# condition that reproduces the cost). 11 mixed-type columns like the real
# ledger buffer. A fixed `VALS` is reused so we time the BUFFER WRITE only (not
# per-fill payload construction, a separate lane).
#
# Two independent levers:
#   * allocation size:  current over-allocates columns to max_events
#                       (= n_inst*n_pulses); the fix sizes to ~fills (doubling).
#   * write op:         base-R `col[[i]] <- v` COPIES the column each write
#                       (tracemem-confirmed); collapse::setv(col, i, v,
#                       vind1=TRUE) writes IN PLACE by reference.
#
# Variants:
#   current  : nested list-in-env, over-allocated, base-R write   (anti-pattern)
#   base_r   : flat env cols, doubling (realistic size), base-R write   (no dep)
#   collapse : flat env cols, doubling, collapse::setv in-place write   (dep)
#
# CAVEAT: an isolated replica OVERESTIMATES absolute cost vs the real handler
# (~2-3x: it copies on every write; the real refcounting copies somewhat less).
# Trust the RELATIVE speedups and the mechanism, not the absolute seconds. The
# final verdict is a real-run re-profile after implementing in the handler.
#
# Usage:
#   Rscript dev/spikes/spike-event-buffer-rewrite.R          # fast shapes
#   Rscript dev/spikes/spike-event-buffer-rewrite.R --big    # + 630k x 13k

suppressWarnings(suppressMessages(library(collapse)))

COLS <- c("event_id","run_id","ts_utc","event_type","instrument_id","side","qty","price","fee","meta_json","event_seq")
VALS <- list(event_id="run_00000001", run_id="run", ts_utc=as.POSIXct(1e9, origin="1970-01-01", tz="UTC"),
             event_type="FILL", instrument_id="DEMO_01", side="BUY", qty=1, price=100, fee=0,
             meta_json='{"cash_delta":-100,"position_delta":1}', event_seq=1L)
new_cols <- function(n) list(
  event_id=character(n), run_id=character(n),
  ts_utc=as.POSIXct(rep(NA_real_,n), origin="1970-01-01", tz="UTC"),
  event_type=character(n), instrument_id=character(n), side=character(n),
  qty=numeric(n), price=numeric(n), fee=numeric(n), meta_json=character(n), event_seq=integer(n))

# --- current: nested list-in-env, over-allocated, base-R scatter write --------
make_current <- function(max_events) {
  state <- new.env(parent=emptyenv()); state$cols <- new_cols(max_events); state$n <- 0L
  function(v) {
    state$n <- state$n + 1L; i <- state$n
    state$cols$event_id[[i]] <- v$event_id; state$cols$run_id[[i]] <- v$run_id
    state$cols$ts_utc[[i]] <- v$ts_utc; state$cols$event_type[[i]] <- v$event_type
    state$cols$instrument_id[[i]] <- v$instrument_id; state$cols$side[[i]] <- v$side
    state$cols$qty[[i]] <- v$qty; state$cols$price[[i]] <- v$price; state$cols$fee[[i]] <- v$fee
    state$cols$meta_json[[i]] <- v$meta_json; state$cols$event_seq[[i]] <- v$event_seq
  }
}

# --- base_r: flat env columns, grow-by-doubling, base-R write -----------------
make_base_r <- function(initial_cap=1024L) {
  state <- new.env(parent=emptyenv()); state$cap <- initial_cap; state$n <- 0L
  cc <- new_cols(initial_cap); for (nm in COLS) state[[nm]] <- cc[[nm]]
  grow <- function() { ex <- new_cols(state$cap); for (nm in COLS) state[[nm]] <- c(state[[nm]], ex[[nm]]); state$cap <- state$cap * 2L }
  function(v) {
    state$n <- state$n + 1L; i <- state$n; if (i > state$cap) grow()
    state$event_id[[i]] <- v$event_id; state$run_id[[i]] <- v$run_id
    state$ts_utc[[i]] <- v$ts_utc; state$event_type[[i]] <- v$event_type
    state$instrument_id[[i]] <- v$instrument_id; state$side[[i]] <- v$side
    state$qty[[i]] <- v$qty; state$price[[i]] <- v$price; state$fee[[i]] <- v$fee
    state$meta_json[[i]] <- v$meta_json; state$event_seq[[i]] <- v$event_seq
  }
}

# --- collapse: flat env columns, grow-by-doubling, setv in-place write --------
make_collapse <- function(initial_cap=1024L) {
  state <- new.env(parent=emptyenv()); state$cap <- initial_cap; state$n <- 0L
  cc <- new_cols(initial_cap); for (nm in COLS) state[[nm]] <- cc[[nm]]
  grow <- function() { ex <- new_cols(state$cap); for (nm in COLS) state[[nm]] <- c(state[[nm]], ex[[nm]]); state$cap <- state$cap * 2L }
  function(v) {
    state$n <- state$n + 1L; i <- state$n; if (i > state$cap) grow()
    collapse::setv(state$event_id, i, v$event_id, vind1=TRUE); collapse::setv(state$run_id, i, v$run_id, vind1=TRUE)
    collapse::setv(state$ts_utc, i, v$ts_utc, vind1=TRUE); collapse::setv(state$event_type, i, v$event_type, vind1=TRUE)
    collapse::setv(state$instrument_id, i, v$instrument_id, vind1=TRUE); collapse::setv(state$side, i, v$side, vind1=TRUE)
    collapse::setv(state$qty, i, v$qty, vind1=TRUE); collapse::setv(state$price, i, v$price, vind1=TRUE)
    collapse::setv(state$fee, i, v$fee, vind1=TRUE); collapse::setv(state$meta_json, i, v$meta_json, vind1=TRUE)
    collapse::setv(state$event_seq, i, v$event_seq, vind1=TRUE)
  }
}

time_variant <- function(buffer, fills) system.time(for (k in seq_len(fills)) buffer(VALS))[["elapsed"]]

shapes <- list(c(100800L, 2099L), c(315000L, 6784L))
if ("--big" %in% commandArgs(trailingOnly = TRUE)) shapes <- c(shapes, list(c(630000L, 13000L)))

cat(sprintf("%-9s %-9s %8s %8s %8s | %9s %9s\n", "max_evt", "fills", "current", "base_r", "collapse", "cur/baseR", "cur/coll"))
res <- list()
for (s in shapes) {
  me <- s[1]; nf <- s[2]
  tc <- time_variant(make_current(me), nf)
  tb <- time_variant(make_base_r(1024L), nf)
  tk <- time_variant(make_collapse(1024L), nf)
  cat(sprintf("%-9d %-9d %7.2fs %7.2fs %7.2fs | %8.1fx %8.1fx\n", me, nf, tc, tb, tk, tc/tb, tc/tk))
  res[[length(res)+1L]] <- data.frame(max_events=me, fills=nf, current_s=tc, base_r_s=tb, collapse_s=tk,
                                      speedup_base_r=tc/tb, speedup_collapse=tc/tk, base_r_vs_collapse=tb/tk)
}

cat("\nMechanism (tracemem on one column over 3 writes; lines => copies):\n")
cat("current  : "); cm <- make_current(100000L); { e <- environment(cm)$state; tracemem(e$cols$qty); for (k in 1:3) cm(VALS) }
cat("base_r   : "); bm <- make_base_r(100000L);  { e <- environment(bm)$state; tracemem(e$qty);      for (k in 1:3) bm(VALS) }
cat("collapse : "); km <- make_collapse(100000L);{ e <- environment(km)$state; tracemem(e$qty);      for (k in 1:3) km(VALS) }

out <- "dev/bench/results/spike_event_buffer_rewrite.csv"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(do.call(rbind, res), out, row.names = FALSE)
cat("\nWROTE", out, "\n")
