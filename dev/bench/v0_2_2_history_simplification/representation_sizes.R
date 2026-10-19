# Workstream 46 (LDG-3074) history representation size probe.
#
#   Rscript representation_sizes.R <tree> <h1_db_path> <out_csv> [--build]
#
# Measures every history representation the LDG-3074 map lists at the H1
# shape (1,166 instruments by 7,213 sessions, 580 complete membership sets),
# using the vendor-neutral fixture in dev/bench/v0_2_2_public_history. Each
# row records R's object.size() and the serialized length (what a worker
# transport or saveRDS would carry) in bytes. Run sequentially, one process,
# nothing else loading R on the host; sizes do not depend on host load.
#
# --build builds the fixture snapshot at <h1_db_path> first (about four
# minutes and 1.5 GB on disk).

args <- commandArgs(trailingOnly = TRUE)
tree <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
db_path <- args[[2L]]
out_csv <- args[[3L]]
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all(tree, quiet = TRUE))
source(file.path(tree, "dev", "bench", "v0_2_2_public_history", "fixture.R"))

if ("--build" %in% args) {
  if (file.exists(db_path)) unlink(db_path)
  snap <- public_history_snapshot(db_path)
  ledgr_snapshot_close(snap)
}

rows <- list()
record <- function(group, name, x, note = "") {
  bytes <- as.numeric(utils::object.size(x))
  serialized <- as.numeric(length(serialize(x, NULL)))
  rows[[length(rows) + 1L]] <<- data.frame(
    group = group, name = name, object_bytes = bytes,
    serialized_bytes = serialized, note = note, stringsAsFactors = FALSE
  )
  cat(sprintf("%-22s %-44s %10.1f MB %10.1f MB %s\n", group, name,
              bytes / 2^20, serialized / 2^20, note))
  invisible(NULL)
}

snapshot <- ledgr_snapshot_open(db_path, "public-history-scale")
exp <- ledgr_experiment(
  snapshot, public_history_equal_weight, universe = ledgr_universe_members("U"),
  features = function(params) list(ledgr_ind_returns(params$n)),
  valuation_policy = ledgr_valuation_stale(5), cost_model = ledgr_cost_zero(),
  opening = ledgr_opening(cash = 1e6)
)
cat("universe", length(exp$universe), "\n")

## Substrate ---------------------------------------------------------------
t0 <- Sys.time()
substrate <- ledgr:::ledgr_history_substrate_for_experiment(exp)
cat("substrate built in", format(Sys.time() - t0), "\n")
cat("axis", length(substrate$axis), "instruments", length(substrate$instrument_ids), "\n")
record("substrate", "total (no features bound)", substrate)
for (field in names(substrate$bars)) {
  record("substrate_bars", field, substrate$bars[[field]])
}
for (field in c("expected", "halted", "missing_expected_bar", "inactive_print")) {
  record("substrate_planes", field, substrate[[field]])
}
for (family in names(substrate$segments)) {
  seg <- substrate$segments[[family]]
  record("substrate_segments", family, seg,
         sprintf("segments=%d facts=%d", length(seg$instrument), sum(seg$fact_count)))
}
if (!is.null(substrate$segment_counts)) {
  record("substrate", "segment_counts (membership, status)", substrate$segment_counts)
}
plan <- substrate$provider_plan
record("provider_plan", "total", plan)
if (!is.null(plan$membership)) {
  record("provider_plan", "membership", plan$membership)
  for (field in c("headers", "set_index", "interval")) {
    record("provider_plan_membership", field, plan$membership[[field]])
  }
}
record("provider_plan", "status_segments", plan$status_segments)
record("provider_plan", "lifetime_segments", plan$lifetime_segments)
record("provider_plan", "sessions", plan$sessions)
record("substrate", "sessions", substrate$sessions)
record("substrate", "families", substrate$families)
record("substrate", "axis+indexes", list(substrate$axis, substrate$instrument_index, substrate$pulse_index))
all_planes <- c(substrate$bars[c("gap_type", "is_synthetic")],
                list(substrate$expected, substrate$halted,
                     substrate$missing_expected_bar, substrate$inactive_print))
record("flag", "unread+restating planes", all_planes,
       "gap_type, is_synthetic, expected, halted, missing_expected_bar, inactive_print")
record("flag", "facts held twice (segments+plan)", list(substrate$segments, plan))

## Provider and valuation built from the substrate ------------------------
provider <- ledgr:::ledgr_availability_provider_from_substrate(
  substrate, ledgr:::ledgr_sweep_availability_config(exp), "probe"
)
record("provider", "from substrate (closures)", provider,
       "serialized length includes captured environments")

## Feature projection and precompute payload ------------------------------
defs <- list(ledgr_ind_returns(20L))
def_list <- lapply(defs, ledgr:::ledgr_precompute_feature_def_from_indicator)
names(def_list) <- vapply(def_list, function(d) d$fingerprint, character(1))
payload <- ledgr:::ledgr_history_precompute_payload(
  def_list, substrate,
  calculation_start = ledgr:::ledgr_history_calculation_start(substrate)
)
record("features", "payload, one feature (per-instrument vectors)", payload)
projection <- ledgr:::ledgr_projection_from_payload(
  payload = payload, universe = exp$universe, pulses_posix = substrate$axis,
  feature_engine_version = ledgr:::ledgr_feature_engine_version(TRUE)
)
record("features", "runtime projection, one feature", projection)
bound <- ledgr:::ledgr_history_substrate_bind_features(substrate, projection)
record("substrate", "total (one feature bound)", bound)
rm(payload)

grid <- ledgr_param_grid(list(f = 0.9, n = 20L), list(f = 0.95, n = 60L))
pre <- ledgr_precompute_features(exp, grid)
record("precompute", "ledgr_precomputed_features, two features", pre)
record("precompute", "  projection", pre$projection)
record("precompute", "  payload", pre$payload)

## History read memo -------------------------------------------------------
service <- ledgr:::ledgr_history_read_service(bound, feature_defs = def_list)
ids <- bound$instrument_ids
planes <- list(
  member = rep(TRUE, length(ids)), admissible = rep(TRUE, length(ids)),
  target_restriction_reason = rep("", length(ids))
)
n_axis <- length(bound$axis)
read <- function(col, lookback) {
  ledgr:::ledgr_history_read(
    ledgr:::ledgr_history_view(service, col), "bar", "close", lookback,
    "decision_axis", "keep", "wide", ids, planes
  )
}
r252 <- read(n_axis, 252L)
memo <- bound$history_memo
for (key in c("late_epochs", "base_masks", "base_close")) {
  record("history_memo", key, memo[[key]])
}
late <- memo$late_epochs
late_n <- sum(lengths(late) > 0L)
epoch_cols <- unique(unlist(lapply(late[lengths(late) > 0L], function(e) {
  findInterval(e, as.numeric(bound$axis))
})))
for (col in sort(epoch_cols)) {
  if (col >= 1L && col <= n_axis) invisible(read(col, 21L))
}
overlay_keys <- grep("^overlay_", ls(memo), value = TRUE)
record("history_memo", sprintf("overlays (%d keys)", length(overlay_keys)),
       mget(overlay_keys, envir = memo),
       sprintf("instruments_with_late_facts=%d", late_n))
record("history_memo", "whole memo after reads", as.list(memo))
record("history_read", "result close lookback 252 wide", r252)
rInf <- read(n_axis, Inf)
record("history_read", "result close lookback Inf wide", rInf)
rm(r252, rInf)

## Staged worker invariant -------------------------------------------------
original <- ledgr:::ledgr_sweep_candidate_tasks
captured <- new.env()
capture_tasks <- function(precomputed) {
  testthat::with_mocked_bindings(
    tryCatch(
      ledgr_sweep(exp, grid, precomputed_features = precomputed),
      probe_captured = function(e) NULL
    ),
    ledgr_sweep_candidate_tasks = function(...) {
      captured$tasks <- original(...)
      rlang::abort("captured", class = "probe_captured")
    },
    .package = "ledgr"
  )
  captured$tasks
}
for (arm in c("fresh", "precomputed")) {
  tasks <- capture_tasks(if (identical(arm, "precomputed")) pre else NULL)
  staged <- ledgr:::ledgr_sweep_stage_history_tasks(tasks, paste0("probe-", arm))
  record("staged_invariant", paste0(arm, ": invariant"), staged$invariant)
  record("staged_invariant", paste0(arm, ": invariant$history_substrate"),
         staged$invariant$history_substrate)
  record("staged_invariant", paste0(arm, ": invariant$precomputed_features"),
         staged$invariant$precomputed_features)
  record("staged_invariant", paste0(arm, ": one compact task"), staged$tasks[[1L]])
  rm(tasks, staged)
}

## Dense representations at the same shape (synthetic, complete) ----------
n_inst <- length(ids)
dense_axis <- bound$axis
values <- matrix(50, nrow = n_inst, ncol = n_axis)
bars_mat <- list(
  open = values, high = values, low = values, close = values, volume = values,
  gap_type = matrix("NONE", nrow = n_inst, ncol = n_axis),
  is_synthetic = matrix(FALSE, nrow = n_inst, ncol = n_axis)
)
record("dense", "bars_mat", bars_mat)
views <- ledgr:::ledgr_bars_pulse_views(bars_mat, ids, dense_axis)
record("dense", "static_bars_views", views)
rm(views)
bars_by_id <- lapply(seq_len(n_inst), function(i) {
  data.frame(
    instrument_id = ids[[i]], ts_utc = dense_axis, open = 50, high = 50,
    low = 50, close = 50, volume = 50, gap_type = "NONE",
    is_synthetic = FALSE, stringsAsFactors = FALSE
  )
})
record("dense", "bars_by_id", bars_by_id)

out <- do.call(rbind, rows)
utils::write.csv(out, out_csv, row.names = FALSE)
ledgr_snapshot_close(snapshot)
cat("done\n")
