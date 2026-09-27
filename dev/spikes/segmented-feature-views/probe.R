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


# =====================================================================
# P4  Is a late-known *barrier* constructible and causally resolved?
#
# The accepted barriers are an inactive lifetime interval, a corporate action
# under an undeclared price basis, and a terminal assertion. The halt measured
# above is `trading_status`, which is none of them, and the generator sets the
# terminal assertion's knowledge time equal to its effective time. So the
# default bundle contains no late-known barrier. This asks whether one can be
# built through the public constructor at all.
# =====================================================================

life <- inputs$lifetime
inactive_row <- which(life$assertion == "known_inactive")
stopifnot(length(inactive_row) == 1L)
lag_to <- ledgr_sim_pit_time_for_date(
  inputs$sessions$session_date[inputs$sessions$status == "open"][20L],
  ledgr_session_times(inputs$sessions$session_close, inputs$sessions$session_date,
                      "UTC", "session_close"),
  inputs$sessions
)
life$knowledge_time[inactive_row] <- lag_to
record("barrier_effective_from",
       format(life$effective_from[inactive_row], "%Y-%m-%d %H:%M:%S"), "utc",
       "generator lifetime row, unchanged")
record("barrier_knowledge_time", format(lag_to, "%Y-%m-%d %H:%M:%S"), "utc",
       "knowledge_time moved later by the probe")

built <- tryCatch(
  do.call(ledgr_facts_lifetime, c(list(df = life), args_for("lifetime"))),
  error = function(e) e
)
record("late_known_barrier_constructs", !inherits(built, "error"), "logical",
       "ledgr_facts_lifetime on the edited frame")
if (inherits(built, "error")) {
  record("late_known_barrier_error", class(built)[[1L]], "class",
         "condition class from ledgr_facts_lifetime")
} else {
  facts2 <- ledgr_facts(
    do.call(ledgr_facts_sessions, c(list(df = inputs$sessions), args_for("sessions"))),
    do.call(ledgr_facts_membership_snapshots,
            c(list(df = inputs$membership), args_for("membership"))),
    built,
    do.call(ledgr_facts_trading_status,
            c(list(df = inputs$trading_status), args_for("trading_status")))
  )
  db2 <- tempfile(fileext = ".duckdb")
  snap2 <- tryCatch(
    ledgr_snapshot_from_df(inputs$bars, instruments_df = inputs$instruments,
                           facts = facts2, db_path = db2,
                           price_basis = inputs$recipe$price_basis),
    error = function(e) e
  )
  record("late_known_barrier_seals", !inherits(snap2, "error"), "logical",
         "ledgr_snapshot_from_df with the late-known barrier")
  if (!inherits(snap2, "error")) {
    run2 <- ledgr_run(
      ledgr_experiment(snap2, function(ctx, params) ctx$flat(),
                       universe = ledgr_universe_members(inputs$recipe$scopes$universe_id),
                       valuation_policy = ledgr_valuation_stale(2),
                       cost_model = ledgr_cost_zero()),
      run_id = "probe-late-barrier"
    )
    bid <- life$instrument_id[inactive_row]
    e_eff <- ledgr_run_explain(run2, bid, life$effective_from[inactive_row])
    e_kno <- ledgr_run_explain(run2, bid, lag_to)
    record("barrier_restricted_at_effective_from", e_eff$target_restricted[[1L]],
           "logical", "ledgr_run_explain on the late-known-barrier run")
    record("barrier_restricted_at_knowledge_time", e_kno$target_restricted[[1L]],
           "logical", "ledgr_run_explain on the late-known-barrier run")
    pick <- function(x, field) {
      if (is.null(x[[field]])) NA_character_ else as.character(x[[field]][[1L]])
    }
    record("barrier_reason_at_effective_from", pick(e_eff, "target_restriction_reason"),
           "reason", "ledgr_run_explain, singular reason field")
    record("barrier_reasons_at_effective_from", pick(e_eff, "target_restriction_reasons"),
           "reasons", "ledgr_run_explain, complete reasons field")
    record("barrier_reason_at_knowledge_time", pick(e_kno, "target_restriction_reason"),
           "reason", "ledgr_run_explain, singular reason field")
    record("barrier_reasons_at_knowledge_time", pick(e_kno, "target_restriction_reasons"),
           "reasons", "ledgr_run_explain, complete reasons field")
    close(run2)
    ledgr_snapshot_close(snap2)
  }
  unlink(db2)
}

# =====================================================================
# P5  Exercise the backward re-seek with a test that can fail.
#
# An earlier version seeked over boundaries where every instrument resolved to
# the same code, so skipping the backward seek would also have passed. This
# picks the halt's own start and end, where the resolved value differs, and
# guards that it differs before trusting the comparison.
# =====================================================================

rws <- prov_data$status
segs <- ledgr_availability_prepared_segments(
  rws, key, 1L, 1L, function(applicable) as.integer(length(applicable))
)
halt_rows <- rws[rws$status == "halted" & !is.na(rws$effective_to), , drop = FALSE]
stopifnot(nrow(halt_rows) == 1L)
# The halted row's segment starts at pmax(effective_from, knowledge_time), so the
# inside point is its knowledge time rather than its effective time.
t_in <- max(
  ledgr_availability_prepared_seconds(halt_rows$effective_from[[1L]]),
  ledgr_availability_prepared_seconds(halt_rows$knowledge_time[[1L]])
)
t_out <- ledgr_availability_prepared_seconds(halt_rows$effective_to[[1L]])

fresh <- function(at) {
  cur <- ledgr_availability_prepared_cursor(segs)
  cur$seek(at)
  cur$read(1L, seq_len(length(key)))
}
v_in <- fresh(t_in)
v_out <- fresh(t_out)
record("reseek_values_differ_at_the_two_boundaries", !identical(v_in, v_out),
       "logical", "two fresh cursors, the guard against a vacuous test")

walked <- ledgr_availability_prepared_cursor(segs)
walked$seek(t_out)
walked$seek(t_in)
record("cursor_backward_reseek_matches_fresh",
       identical(walked$read(1L, seq_len(length(key))), v_in), "logical",
       "one cursor seeked forward then backward, against a fresh forward seek")
record("cursor_without_reseek_would_differ", !identical(v_out, v_in), "logical",
       "a cursor left at the later boundary reads the later value")

evidence <- do.call(rbind, rows)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(evidence, file.path(out_dir, "probe_evidence.csv"), row.names = FALSE)
print(evidence, right = FALSE)
