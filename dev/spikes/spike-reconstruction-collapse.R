# Spike: event reconstruction (Lane C) -- base-R loops vs collapse grouped ops,
# with a byte-identical parity check and a determinism (hostile set_collapse) gate.
#
# Targets fold-core.R:445-901 (ledgr_equity_from_events / ledgr_fills_from_events
# / ..._sweep_summary): the per-instrument `which(events$instrument_id==id)` +
# `cumsum` loop (O(n_inst^2): which() re-scans all events per instrument) and the
# per-row data.frame() + do.call(rbind) fills assembly. See
# inst/design/collapse_optimization_map.md (Tier 1) and
# inst/design/audits/fold_path_hotpath_audit.md (findings #5/#6).
#
# This is the FIRST value-bearing collapse use, so the gate matters more than the
# speed: it must produce byte-identical output and be invariant to hostile caller
# collapse options. Usage:
#   Rscript dev/spikes/spike-reconstruction-collapse.R

suppressWarnings(suppressMessages(library(collapse)))

# Prototype of the mandated wrapper: pin ledgr's collapse config, restore on exit.
with_collapse_deterministic <- function(expr) {
  old <- collapse::set_collapse(nthreads = 1L, na.rm = FALSE, sort = TRUE)
  on.exit(collapse::set_collapse(old), add = TRUE)
  force(expr)
}

gen_events <- function(n_inst, per_inst = 26L, seed = 20260529L) {
  set.seed(seed)
  inst <- rep(sprintf("DEMO_%04d", seq_len(n_inst)), each = per_inst)
  n <- length(inst)
  data.frame(
    event_seq = seq_len(n),
    instrument_id = inst,
    position_delta = sample(c(-1, 1), n, TRUE),
    cash_delta = stats::rnorm(n, 0, 100),
    stringsAsFactors = FALSE
  )[sample(n), ][order(sample(n)), ]  # shuffle then keep event_seq order
}

# --- A. cumulative positions per instrument ----------------------------------
recon_current <- function(ev) {                  # per-instrument which()+cumsum loop
  pos <- numeric(nrow(ev)); cash <- numeric(nrow(ev))
  for (id in unique(ev$instrument_id)) {
    idx <- which(ev$instrument_id == id)
    pos[idx] <- cumsum(ev$position_delta[idx])
    cash[idx] <- cumsum(ev$cash_delta[idx])
  }
  list(pos = pos, cash = cash)
}
recon_collapse <- function(ev) {                 # grouped fcumsum (order-preserving)
  list(pos = collapse::fcumsum(ev$position_delta, g = ev$instrument_id, na.rm = FALSE),
       cash = collapse::fcumsum(ev$cash_delta, g = ev$instrument_id, na.rm = FALSE))
}

cat("== A. cumulative positions: per-instrument loop vs grouped fcumsum ==\n")
cat(sprintf("%-7s %-8s %9s %9s | %8s  %s\n", "n_inst", "events", "current", "collapse", "speedup", "parity"))
recA <- list()
for (ni in c(100L, 500L, 1000L)) {
  ev <- gen_events(ni)
  tc <- system.time(rc <- recon_current(ev))[["elapsed"]]
  tk <- system.time(rk <- with_collapse_deterministic(recon_collapse(ev)))[["elapsed"]]
  par <- isTRUE(all.equal(rc$pos, rk$pos)) && isTRUE(all.equal(rc$cash, rk$cash))
  cat(sprintf("%-7d %-8d %8.3fs %8.3fs | %7.1fx  %s\n", ni, nrow(ev), tc, tk, tc / tk, if (par) "IDENTICAL" else "*** MISMATCH ***"))
  recA[[length(recA) + 1L]] <- data.frame(n_inst = ni, events = nrow(ev), current_s = tc, collapse_s = tk, speedup = tc / tk, parity = par)
}

# --- B. fills table assembly: per-row data.frame + rbind vs rowbind -----------
cat("\n== B. fills assembly: per-row data.frame + do.call(rbind) vs rowbind ==\n")
ev <- gen_events(500L)
build_rbind <- function(ev) {
  rows <- vector("list", nrow(ev))
  for (i in seq_len(nrow(ev))) rows[[i]] <- data.frame(event_seq = ev$event_seq[[i]], instrument_id = ev$instrument_id[[i]], qty = abs(ev$position_delta[[i]]), stringsAsFactors = FALSE)
  do.call(rbind, rows)
}
build_rowbind <- function(ev) {
  rows <- vector("list", nrow(ev))
  for (i in seq_len(nrow(ev))) rows[[i]] <- list(event_seq = ev$event_seq[[i]], instrument_id = ev$instrument_id[[i]], qty = abs(ev$position_delta[[i]]))
  collapse::rowbind(rows)
}
tb <- system.time(b1 <- build_rbind(ev))[["elapsed"]]
tr <- system.time(b2 <- build_rowbind(ev))[["elapsed"]]
par_b <- isTRUE(all.equal(b1$event_seq, b2$event_seq)) && isTRUE(all.equal(b1$qty, b2$qty))
cat(sprintf("rbind %.3fs vs rowbind %.3fs | %.1fx | parity %s\n", tb, tr, tb / tr, if (par_b) "IDENTICAL" else "*** MISMATCH ***"))

# --- C. determinism gate: hostile set_collapse -------------------------------
cat("\n== C. determinism gate (hostile caller set_collapse) ==\n")
ev <- gen_events(200L); ev$position_delta[c(5, 50, 500)] <- NA   # inject NAs

# fcumsum: is it invariant to hostile settings?
base_pos <- with_collapse_deterministic(collapse::fcumsum(ev$position_delta, g = ev$instrument_id, na.rm = FALSE))
old <- collapse::set_collapse(nthreads = 4L, na.rm = TRUE, sort = FALSE)
hostile_unwrapped <- collapse::fcumsum(ev$position_delta, g = ev$instrument_id)          # relies on global na.rm
hostile_wrapped   <- with_collapse_deterministic(collapse::fcumsum(ev$position_delta, g = ev$instrument_id, na.rm = FALSE))
collapse::set_collapse(old)
cat(sprintf("fcumsum  unwrapped-under-hostile == baseline? %s\n", isTRUE(all.equal(base_pos, hostile_unwrapped))))
cat(sprintf("fcumsum  wrapped-under-hostile   == baseline? %s\n", isTRUE(all.equal(base_pos, hostile_wrapped))))

# fmean (a metric): the sensitive case -- relies-on-global vs explicit-arg vs wrapped
ret <- c(0.01, NA, -0.02, 0.03, NA, 0.005)
base_mean <- with_collapse_deterministic(collapse::fmean(ret, na.rm = FALSE))
old <- collapse::set_collapse(na.rm = TRUE)
relies_global <- collapse::fmean(ret)                 # DANGER: inherits caller na.rm=TRUE
explicit_arg  <- collapse::fmean(ret, na.rm = FALSE)  # SAFE: explicit arg wins
wrapped       <- with_collapse_deterministic(collapse::fmean(ret, na.rm = FALSE))
collapse::set_collapse(old)
cat(sprintf("fmean    relies-on-global == baseline? %s   (shows the DANGER)\n", isTRUE(all.equal(base_mean, relies_global))))
cat(sprintf("fmean    explicit-arg     == baseline? %s   (SAFE pattern)\n", isTRUE(all.equal(base_mean, explicit_arg))))
cat(sprintf("fmean    wrapped          == baseline? %s   (defense in depth)\n", isTRUE(all.equal(base_mean, wrapped))))

out <- "dev/bench/results/spike_reconstruction_collapse.csv"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(do.call(rbind, recA), out, row.names = FALSE)
cat("\nWROTE", out, "\n")
