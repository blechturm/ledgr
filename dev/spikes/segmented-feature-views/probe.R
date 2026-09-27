# Probe for the segmented-feature-views charter (spike protocol section 1).
#
# One job: establish by execution, not by reading, the three facts a charter
# about segmented feature preparation would otherwise assert.
#
#   P1  a late-known bounded fact is invisible before its knowledge time and
#       visible after it, through the public run surface;
#   P2  the prepared fact provider already stores per-instrument
#       piecewise-constant segments, and how large that store is;
#   P3  how large the retained feature projection is by comparison, since a
#       segmented feature view would hold one of those per segment.
#
# Writes dev/spikes/segmented-feature-views/probe_evidence.csv.
# Binds nothing. No package file is modified.

suppressMessages(pkgload::load_all(".", quiet = TRUE, export_all = TRUE))

out_dir <- "dev/spikes/segmented-feature-views"
rows <- list()
record <- function(key, value, unit, how) {
  rows[[length(rows) + 1L]] <<- data.frame(
    key = key, value = as.character(value), unit = unit, derived_from = how,
    stringsAsFactors = FALSE
  )
}

# ---------------------------------------------------------------- fixture
inputs <- ledgr_sim_pit_inputs(
  instrument_ids = paste0("PB", 1:4),
  from = "2020-01-01",
  to = "2020-01-31",
  seed = 23L,
  venue_id = "PROBE_VENUE",
  universe_id = "PROBE_UNIVERSE"
)

args_for <- function(family) {
  spec <- inputs$recipe$constructors[[family]]
  keep <- setdiff(names(spec), "enabled")
  spec[keep]
}
facts <- ledgr_facts(
  do.call(ledgr_facts_sessions, c(list(df = inputs$sessions), args_for("sessions"))),
  do.call(ledgr_facts_membership_snapshots,
          c(list(df = inputs$membership), args_for("membership"))),
  do.call(ledgr_facts_lifetime, c(list(df = inputs$lifetime), args_for("lifetime"))),
  do.call(ledgr_facts_trading_status,
          c(list(df = inputs$trading_status), args_for("trading_status")))
)

db_path <- tempfile(fileext = ".duckdb")
t_seal <- system.time({
  snapshot <- ledgr_snapshot_from_df(
    inputs$bars,
    instruments_df = inputs$instruments,
    facts = facts,
    db_path = db_path,
    price_basis = inputs$recipe$price_basis
  )
})[["elapsed"]]
record("seal_seconds", round(t_seal, 3), "s", "system.time around ledgr_snapshot_from_df")

experiment <- ledgr_experiment(
  snapshot,
  function(ctx, params) ctx$flat(),
  universe = ledgr_universe_members(inputs$recipe$scopes$universe_id),
  valuation_policy = ledgr_valuation_stale(2),
  cost_model = ledgr_cost_zero()
)
record("availability_active", ledgr_experiment_plan(experiment)$availability_active,
       "logical", "ledgr_experiment_plan")

t_run <- system.time({ run <- ledgr_run(experiment, run_id = "probe-segmented") })[["elapsed"]]
record("run_seconds", round(t_run, 3), "s", "system.time around ledgr_run")
record("completion_status", ledgr_run_completion(run)$completion_status,
       "status", "ledgr_run_completion")

# ------------------------------------------------- P1 late-known behaviour
halted <- inputs$trading_status[inputs$trading_status$status == "halted", , drop = FALSE]
stopifnot(nrow(halted) == 1L)
record("halt_effective_from", format(halted$effective_from[[1L]], "%Y-%m-%d %H:%M:%S"),
       "utc", "generator output")
record("halt_knowledge_time", format(halted$knowledge_time[[1L]], "%Y-%m-%d %H:%M:%S"),
       "utc", "generator output")
record("halt_knowledge_after_effective",
       halted$knowledge_time[[1L]] > halted$effective_from[[1L]], "logical",
       "comparison of generator columns")

explain_at <- function(ts) {
  ledgr_run_explain(run, halted$instrument_id[[1L]], ts)
}
before <- explain_at(halted$effective_from[[1L]])
at_known <- explain_at(halted$knowledge_time[[1L]])
record("restricted_at_effective_from", before$target_restricted[[1L]], "logical",
       "ledgr_run_explain at the halt effective instant")
record("restricted_at_knowledge_time", at_known$target_restricted[[1L]], "logical",
       "ledgr_run_explain at the halt knowledge instant")
record("reason_at_knowledge_time",
       if (is.null(at_known$target_restriction_reason)) NA_character_
       else at_known$target_restriction_reason[[1L]],
       "reason", "ledgr_run_explain at the halt knowledge instant")

# ------------------------------------ P2 prepared fact segment store size
con <- DBI::dbConnect(duckdb::duckdb(), snapshot$db_path, read_only = TRUE)
prov_data <- ledgr_availability_provider_data(con, snapshot$snapshot_id)
for (nm in c("status", "lifetime", "membership", "sessions")) {
  record(paste0("fact_rows_", nm),
         if (is.data.frame(prov_data[[nm]])) nrow(prov_data[[nm]]) else 0L,
         "count", "ledgr_availability_provider_data")
}
key <- ledgr_availability_stable_ids(as.character(inputs$instruments$instrument_id))

seg_bytes <- 0L
for (nm in c("status", "lifetime")) {
  rws <- prov_data[[nm]]
  if (!is.data.frame(rws) || nrow(rws) == 0L) next
  n_planes <- if (identical(nm, "lifetime")) 2L else 1L
  segs <- ledgr_availability_prepared_segments(
    rws, key, n_planes, rep(1L, n_planes), function(applicable) rep(1L, n_planes)
  )
  b <- as.numeric(object.size(segs$bound)) + as.numeric(object.size(segs$codes))
  seg_bytes <- seg_bytes + b
  record(paste0("segments_", nm, "_boundaries"), length(segs$bound), "count",
         "ledgr_availability_prepared_segments output")
  record(paste0("segments_", nm, "_bytes"), round(b), "bytes",
         "object.size of bound plus codes")
}
record("segments_total_bytes", round(seg_bytes), "bytes", "sum of family segment stores")

# ---------------------------------------- P3 retained feature payload size
n_inst <- length(key)
n_pulse <- sum(inputs$sessions$status == "open")
record("instruments", n_inst, "count", "stable id key length")
record("pulses", n_pulse, "count", "declared open sessions in the sealed calendar")
record("one_feature_plane_bytes", n_inst * n_pulse * 8, "bytes",
       "arithmetic: instruments times pulses times 8")
record("segments_bytes_per_feature_plane",
       round(seg_bytes / max(1, n_inst * n_pulse * 8), 6), "ratio",
       "segment store divided by one feature plane")

DBI::dbDisconnect(con, shutdown = TRUE)
close(run)
ledgr_snapshot_close(snapshot)
unlink(db_path)

evidence <- do.call(rbind, rows)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(evidence, file.path(out_dir, "probe_evidence.csv"), row.names = FALSE)
print(evidence, right = FALSE)
