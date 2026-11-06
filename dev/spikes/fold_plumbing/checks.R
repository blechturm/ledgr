# Check-cost probe: today's per-pulse carrier checks against only the
# runtime checks the Type 2 response keeps
# (inst/design/rfc/rfc_lean_core_pulse_plumbing_v0_2_3_response.md, finding 2),
# on the same recorded pulses.
#
#   Rscript checks.R --pkg=<ledgr source tree at d5b3a151> --out=<dir> [--reps=5]
#
# Both variants run the append check unchanged (typed accounting synthesis
# 3.4 binds it). P3's internal execution view is not on the tape, so its
# check is in neither variant.

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

work <- file.path(tempdir(), "fold_plumbing_checks")
dir.create(work, showWarnings = FALSE)
fp_install_wrappers()
snapshot <- ws16_momentum_snapshot(40L, 504L, file.path(work, "momentum.duckdb"), "fp_momentum")
exp <- ws16_momentum_experiment(snapshot, 63L)
tapes <- list(momentum_40x504 = fp_capture(function() {
  close(ledgr_run(exp, params = list(lookback = 63L, n = 10L), run_id = "fp-chk-m", seed = 1L))
}))
ledgr_snapshot_close(snapshot)
snapshot <- ledgr_snapshot_from_df(ws16_fill_heavy_bars(), db_path = file.path(work, "fill.duckdb"),
                                   snapshot_id = "fp_fill")
exp <- ws16_fill_heavy_experiment(snapshot)
tapes$fill_heavy_500x1260 <- fp_capture(function() {
  close(suppressWarnings(ledgr_run(exp, run_id = "fp-chk-f", seed = 20260530L)))
})
ledgr_snapshot_close(snapshot)
# Time the pinned functions, not the tape wrappers.
commit <- ws16_load_source(pkg)

decision_fields <- names(ledgr:::.ledgr_carrier_fields$decision)
event_cols <- ledgr:::ledgr_output_event_columns

# Today: every group's full check, as the stages and the handler run them.
check_full <- function(p, n_run) {
  o <- p$P1$observation
  ledgr_carrier_packet(o$packet, "decision_packet", n_run)
  ledgr_carrier_packet(o$data, "decision_data", n_run)
  ledgr_carrier_packet(p$P1$execution, "execution_packet", n_run)
  d <- p$P2
  ledgr_carrier_decision(d[decision_fields], n_run)
  ledgr_carrier_plan(p$P3$batch, d$context_pos, d$actionable_k, n_run)
  for (call in p$payload) ledgr_carrier_new(call$block, "publication", NA_integer_)
  invisible(NULL)
}

refuse <- function(what) rlang::abort(paste0("Invalid internal ", what, "."), class = "ledgr_internal_error")
no_inf <- function(x) !any(is.infinite(x))

# The response's runtime column: values that are computed on this pulse
# and can be wrong on data. Everything else is established by construction.
check_targeted <- function(p, n_run) {
  k <- p$P1$observation$packet
  if (!is.finite(k$cash) || is.na(k$positions_value) ||
      !all(is.finite(k$position)) || !no_inf(k$mark) || !no_inf(k$reference) ||
      !no_inf(k$source_ts) || any(k$mark_age < 0L, na.rm = TRUE)) refuse("decision packet")
  # Provider codes come through a vocabulary mapping (response finding 2).
  if (any(k$status < 1L | k$status > 5L) || any(k$lifetime < 1L | k$lifetime > 3L) ||
      any(k$mark_source < 1L | k$mark_source > 5L)) refuse("decision packet")
  b <- p$P3$batch
  if (is.nan(b$expected_final_cash) || identical(b$expected_final_cash, -Inf)) refuse("plan")
  f <- b$fill
  if (length(f$k) && (any(f$qty <= 0) || any(f$price <= 0) || any(f$fee < 0, na.rm = TRUE) ||
      !all(is.finite(f$qty)) || !all(is.finite(f$price)) || !all(is.finite(f$position_before)) ||
      !all(is.finite(f$planned_position_after)) || any(is.na(f$fee) & !is.nan(f$fee)) ||
      any(is.na(f$cash_delta) & !is.nan(f$cash_delta)))) refuse("fill")
  j <- b$rejection
  if (length(j$k) && (any(j$resolved_price <= 0, na.rm = TRUE) || !no_inf(j$resolved_price) ||
      !no_inf(j$exec_ts) || !all(is.finite(j$position)))) refuse("rejection")
  for (call in p$payload) {
    if (call$event_seq + length(call$i) - 1 > .Machine$integer.max) refuse("publication")
  }
  invisible(NULL)
}

# Both variants: the append check over each published block.
check_append <- function(p, prior) {
  for (call in p$payload) {
    blk <- call$block
    if (!identical(blk$status, "WROTE")) next
    ledgr_validate_accounting_append(blk[event_cols], prior_event_seq = prior$seq, prior_ts_utc = prior$ts)
    prior$seq <- utils::tail(blk$event_seq, 1L)
    prior$ts <- utils::tail(blk$ts_utc, 1L)
  }
}

run_variant <- function(tape, variant) {
  n_run <- length(tape$services$instrument_ids)
  prior <- new.env()
  prior$seq <- NULL
  prior$ts <- NULL
  f <- switch(variant,
    full = function(p) { check_full(p, n_run); check_append(p, prior) },
    targeted = function(p) { check_targeted(p, n_run); check_append(p, prior) },
    full_only = function(p) check_full(p, n_run),
    targeted_only = function(p) check_targeted(p, n_run),
    append_only = function(p) check_append(p, prior))
  t0 <- ledgr_time_now()
  for (k in 1:10) {
    prior$seq <- NULL
    prior$ts <- NULL
    for (p in tape$pulses) f(p)
  }
  1e6 * ledgr_time_elapsed(t0, ledgr_time_now()) / (10 * length(tape$pulses))
}

variants <- c("full", "targeted", "full_only", "targeted_only", "append_only")
timing <- list()
for (w in names(tapes)) {
  for (v in variants) run_variant(tapes[[w]], v)
  for (r in seq_len(reps)) for (v in variants) {
    timing[[length(timing) + 1L]] <- data.frame(workload = w, variant = v, rep = r,
                                                us_per_pulse = run_variant(tapes[[w]], v))
  }
}
timing <- do.call(rbind, timing)
summary <- aggregate(us_per_pulse ~ workload + variant, data = timing, FUN = stats::median)
summary$us_per_pulse <- round(summary$us_per_pulse, 1)

# What each variant refuses: one planted fault per row, on the first pulse
# with at least two fills of the fill-heavy tape.
tape <- tapes$fill_heavy_500x1260
n_run <- length(tape$services$instrument_ids)
first <- tape$pulses[[which(vapply(tape$pulses, function(p) length(p$P3$batch$fill$k) >= 2L, logical(1)))[[1L]]]]
plant <- list(
  none = function(p) p,
  fill_price_negative = function(p) { p$P3$batch$fill$price[[1L]] <- -1; p },
  fill_cash_overflow = function(p) { p$P3$batch$fill$cash_delta[[1L]] <- NA_real_; p },
  packet_mark_infinite = function(p) { p$P1$observation$packet$mark[[1L]] <- Inf; p },
  packet_priced_flag_wrong = function(p) {
    p$P1$observation$packet$priced[[1L]] <- !p$P1$observation$packet$priced[[1L]]; p },
  decision_context_duplicate = function(p) { p$P2$context_pos[[2L]] <- p$P2$context_pos[[1L]]; p },
  fill_order_swapped = function(p) {
    f <- p$P3$batch$fill
    p$P3$batch$fill <- lapply(f, function(v) if (length(v) == length(f$k)) v[c(2L, 1L, seq_along(v)[-(1:2)])] else v)
    p })
refused <- function(f) {
  e <- tryCatch({ f(); NULL }, error = function(e) e)
  if (is.null(e)) "" else conditionMessage(e)
}
faults <- do.call(rbind, lapply(names(plant), function(nm) {
  # A tape entry is an environment; plant on a list copy so faults do not leak.
  p <- plant[[nm]](as.list(first, all.names = TRUE))
  data.frame(fault = nm,
             full = refused(function() check_full(p, n_run)),
             targeted = refused(function() check_targeted(p, n_run)))
}))

ws16_write(timing, file.path(out, "checks_timing_raw.csv"))
ws16_write(summary[order(summary$workload, summary$variant), ], file.path(out, "checks_timing.csv"))
ws16_write(faults, file.path(out, "checks_faults.csv"))
print(summary)
print(faults)
