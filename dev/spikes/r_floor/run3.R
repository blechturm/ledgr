# Stage 3 runner: parity and cost of the lean P2 seam on a changing axis.
# Usage: Rscript dev/spikes/r_floor/run3.R <ledgr lib> <out dir> [n_inst] [n_sessions]
args <- commandArgs(TRUE)
suppressPackageStartupMessages(library(ledgr, lib.loc = args[[1]]))
out <- args[[2]]
n_inst <- if (length(args) >= 3) as.integer(args[[3]]) else 30L
n_sess <- if (length(args) >= 4) as.integer(args[[4]]) else 250L
dir.create(out, recursive = TRUE, showWarnings = FALSE)
here <- file.path("dev", "spikes", "r_floor")
for (f in c("axes_fixture.R", "seam_p2.R")) source(file.path(here, f))

fx <- r_floor_axes_fixture(n_inst, n_sess)
fields <- c("universe", "member", "held", "buyable", "open", "high", "low", "close",
            "volume", "fast", "slow", "hold", "history", "history_cols", "targets")
rows <- list()
for (with_history in c(FALSE, TRUE)) {
  rec <- r_floor_p2_record(fx, with_history, paste0("p2_", with_history))
  p <- r_floor_p2_prepare(fx, rec$fills)
  # Pulses ledgr invoked the strategy on, by decision time.
  pulses <- match(rec$ts, format(p$ts, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  mismatch <- stats::setNames(integer(length(fields)), fields); first <- character()
  for (k in seq_along(pulses)) {
    lv <- r_floor_p2_lean_view(p, pulses[[k]], with_history)
    lv$targets <- r_floor_p2_rule(lv)
    rv <- rec$views[[k]]
    for (f in intersect(fields, names(rv))) {
      # Values are compared without names: the strategy receives the axis in
      # `universe`, and names are a presentation of that same vector.
      if (!identical(unname(lv[[f]]), unname(rv[[f]]))) {
        mismatch[[f]] <- mismatch[[f]] + 1L
        if (!length(first) || !f %in% names(first)) first[[f]] <- as.character(pulses[[k]])
      }
    }
  }
  # Cost: building the lean view plus the strategy rule, every pulse,
  # repeated so the run is far above the timer's resolution.
  reps <- 40L
  lean_s <- stats::median(vapply(1:3, function(r) system.time(for (rr in seq_len(reps)) for (t in pulses) {
    v <- r_floor_p2_lean_view(p, t, with_history); r_floor_p2_rule(v)
  })[["elapsed"]], 1)) / reps
  # A retained lean view cannot change: views are fresh lists.
  kept <- r_floor_p2_lean_view(p, pulses[[20L]], with_history); kept_copy <- kept
  invisible(lapply(pulses, function(t) r_floor_p2_lean_view(p, t, with_history)))
  frozen <- identical(kept, kept_copy)
  # Matched ledgr cost: its decide stage (P2) per pulse, from samples scaled
  # to the run's wall time, with the same rule and no recording.
  rule <- if (with_history) function(ctx, params) {
    h <- ledgr_history_matrix(ctx, bar = "close", lookback = 10L)
    usable <- is.finite(ctx$fast) & is.finite(ctx$slow); targets <- ctx$hold()
    up <- usable & ctx$fast > ctx$slow
    targets[up & ctx$member] <- 10; targets[usable & !up] <- 0; targets
  } else function(ctx, params) {
    usable <- is.finite(ctx$fast) & is.finite(ctx$slow); targets <- ctx$hold()
    up <- usable & ctx$fast > ctx$slow
    targets[up & ctx$member] <- 10; targets[usable & !up] <- 0; targets
  }
  e <- ledgr_experiment(fx$snapshot, rule,
    features = ledgr_feature_map(fast = ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
                                 slow = ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero(),
    universe = ledgr_universe_members("U"), valuation_policy = ledgr_valuation_stale(5))
  close(suppressWarnings(ledgr_run(e, run_id = paste0("warm_", with_history), seed = 1L)))
  prof <- tempfile(fileext = ".out"); Rprof(prof, interval = 0.005)
  wall <- system.time(for (r in 1:4) close(suppressWarnings(
    ledgr_run(e, run_id = paste0("t_", with_history, r), seed = 1L))))[["elapsed"]] / 4
  Rprof(NULL)
  st <- lapply(strsplit(readLines(prof)[-1], " "), function(x) gsub('"', "", x))
  in_decide <- mean(vapply(st, function(x) "ledgr_fold_stage_decide" %in% x, TRUE))
  ledgr_decide_us <- in_decide * wall / length(pulses) * 1e6
  plane_mb <- sum(vapply(p, function(x) if (is.matrix(x)) as.numeric(object.size(x)) else 0, 1)) / 2^20
  rows[[length(rows) + 1L]] <- data.frame(n_inst = n_inst, n_sessions = n_sess,
    history = with_history, pulses = length(pulses),
    fields_identical = sum(mismatch == 0L & fields %in% names(rec$views[[1]])),
    fields_compared = sum(fields %in% names(rec$views[[1]])),
    mismatches = paste(sprintf("%s:%d@%s", names(mismatch)[mismatch > 0],
      mismatch[mismatch > 0], first[names(mismatch)[mismatch > 0]]), collapse = " "),
    lean_us_per_pulse = lean_s / length(pulses) * 1e6,
    ledgr_decide_us_per_pulse = ledgr_decide_us, retained_view_frozen = frozen,
    prepared_planes_mb = plane_mb)
}
res <- do.call(rbind, rows)
utils::write.csv(res, file.path(out, sprintf("p2_seam_%dx%d.csv", n_inst, n_sess)), row.names = FALSE)
print(res, row.names = FALSE)
