# Stage 3 runner, second seam: parity and cost of lean P1 and P3-P5 with
# ledgr's own lot kernel, on a changing axis.
# Usage: Rscript dev/spikes/r_floor/run4.R <ledgr lib> <out dir> [n_inst] [n_sessions]
args <- commandArgs(TRUE)
suppressPackageStartupMessages(library(ledgr, lib.loc = args[[1]]))
out <- args[[2]]
n_inst <- if (length(args) >= 3) as.integer(args[[3]]) else 30L
n_sess <- if (length(args) >= 4) as.integer(args[[4]]) else 250L
dir.create(out, recursive = TRUE, showWarnings = FALSE)
here <- file.path("dev", "spikes", "r_floor")
for (f in c("axes_fixture.R", "seam_p2.R", "seam_p35.R")) source(file.path(here, f))

fx <- r_floor_axes_fixture(n_inst, n_sess)
rec <- r_floor_p35_record(fx, "p35")
p <- r_floor_p2_prepare(fx, rec$fills)
lean <- r_floor_p35_fold(p, fx, rec)
led <- r_floor_p35_ledgr_frames(rec)
same <- function(a, b) vapply(names(b), function(c) identical(a[[c]], b[[c]]), TRUE)
fills_ok <- same(lean$fills, led$fills); equity_ok <- same(lean$equity, led$equity)

reps <- 20L
lean_s <- stats::median(vapply(1:3, function(r) system.time(
  for (rr in seq_len(reps)) r_floor_p35_fold(p, fx, rec))[["elapsed"]], 1)) / reps

# Matched ledgr cost: every fold stage except decide (P2), and the envelope,
# from profile samples scaled to wall time, same strategy without recording.
counter <- new.env(); counter$i <- 0L
strategy <- function(ctx, params) {
  counter$i <- counter$i + 1L
  usable <- is.finite(ctx$fast) & is.finite(ctx$slow)
  targets <- ctx$hold()
  up <- usable & ctx$fast > ctx$slow
  targets[up & ctx$member] <- 5 + (counter$i %% 4) * 5
  targets[usable & !up] <- 0
  targets
}
e <- ledgr_experiment(fx$snapshot, strategy,
  features = ledgr_feature_map(fast = ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
                               slow = ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
  opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero(),
  universe = ledgr_universe_members("U"), valuation_policy = ledgr_valuation_stale(5))
counter$i <- 0L; close(suppressWarnings(ledgr_run(e, run_id = "warm", seed = 1L)))
prof <- tempfile(fileext = ".out"); Rprof(prof, interval = 0.005)
wall <- system.time(for (r in 1:4) {
  counter$i <- 0L; close(suppressWarnings(ledgr_run(e, run_id = paste0("t", r), seed = 1L)))
})[["elapsed"]] / 4
Rprof(NULL)
st <- lapply(strsplit(readLines(prof)[-1], " "), function(x) gsub('"', "", x))
share <- function(pred) mean(vapply(st, pred, TRUE))
in_fold <- share(function(x) "ledgr_fold_envelope" %in% x)
in_decide <- share(function(x) "ledgr_fold_stage_decide" %in% x)
ledgr_p35_us <- (in_fold - in_decide) * wall / n_sess * 1e6
ledgr_decide_us <- in_decide * wall / n_sess * 1e6
book_kb <- as.numeric(object.size(ledgr:::ledgr_lot_book(n_inst))) / 1024

res <- data.frame(n_inst = n_inst, n_sessions = n_sess, fills = nrow(led$fills),
  partial_sells = sum(led$fills$side == "SELL" & led$fills$qty < 20),
  fills_columns_identical = sum(fills_ok), fills_columns = length(fills_ok),
  equity_columns_identical = sum(equity_ok), equity_columns = length(equity_ok),
  lean_p35_us_per_pulse = lean_s / n_sess * 1e6,
  ledgr_fold_without_decide_us_per_pulse = ledgr_p35_us,
  ledgr_decide_us_per_pulse = ledgr_decide_us,
  ledgr_run_us_per_pulse = wall / n_sess * 1e6, empty_book_kb = book_kb)
utils::write.csv(res, file.path(out, sprintf("p35_seam_%dx%d.csv", n_inst, n_sess)), row.names = FALSE)
print(res, row.names = FALSE)
