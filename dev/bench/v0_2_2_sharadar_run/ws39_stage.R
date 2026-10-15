# LDG-3055 worker. It uses the public adapter and ledgr APIs for construction,
# cold verification and experiments. Read-only SQL touches only the newly built
# current store for the format marker and aggregates not exposed publicly; the
# lifetime count follows the already-registered LFB-021 workaround.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 5L) {
  stop(
    "Usage: ws39_stage.R <stage> <ledgr_repo> <adapter_repo> <work_dir> <result_dir>",
    call. = FALSE
  )
}

stage <- args[[1L]]
ledgr_repo <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
adapter_repo <- normalizePath(args[[3L]], winslash = "/", mustWork = TRUE)
work_dir <- normalizePath(args[[4L]], winslash = "/", mustWork = TRUE)
result_dir <- normalizePath(args[[5L]], winslash = "/", mustWork = TRUE)

allowed_stages <- c("build", "cold_verify", "full_membership", "availability")
if (!stage %in% allowed_stages) {
  stop("Unknown WS39 stage.", call. = FALSE)
}

root_value <- Sys.getenv("SHARADAR_DATA_ROOT", unset = "")
if (!nzchar(root_value)) {
  stop("SHARADAR_DATA_ROOT must name the guarded private root.", call. = FALSE)
}
root <- normalizePath(root_value, winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(root, ".ledgr-sharadar-private-root"))) {
  stop("The configured private root has no sentinel.", call. = FALSE)
}
if (!startsWith(tolower(work_dir), paste0(tolower(root), "/"))) {
  stop("work_dir must be a child of the guarded private root.", call. = FALSE)
}

support_library <- file.path(dirname(root), "r-lib", "ledgr-0.2.1.0")
if (dir.exists(support_library)) {
  .libPaths(c(support_library, .libPaths()))
}
suppressMessages(pkgload::load_all(ledgr_repo, quiet = TRUE, compile = FALSE))
suppressMessages(pkgload::load_all(
  file.path(adapter_repo, "packages", "ledgr.sharadar"),
  quiet = TRUE,
  compile = FALSE
))

`%||%` <- function(x, y) if (is.null(x)) y else x
snapshot_path <- file.path(work_dir, "sp500-1998-2026-schema120.duckdb")
state_path <- file.path(work_dir, "ws39-state.json")
from <- as.Date("1998-01-02")
to <- as.Date("2026-09-04")

write_result <- function(value) {
  jsonlite::write_json(
    value,
    file.path(result_dir, paste0(stage, ".json")),
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null"
  )
}

read_state <- function() {
  if (!file.exists(state_path)) stop("The private WS39 state is missing.", call. = FALSE)
  jsonlite::read_json(state_path, simplifyVector = TRUE)
}

git_commit <- function(repo) {
  out <- suppressWarnings(system2(
    "git",
    c(
      "-c", shQuote(paste0("safe.directory=", repo)),
      "-C", shQuote(repo), "rev-parse", "HEAD"
    ),
    stdout = TRUE,
    stderr = FALSE
  ))
  if (length(out) != 1L || !grepl("^[0-9a-f]{40}$", out)) {
    stop("Could not resolve one package commit.", call. = FALSE)
  }
  out[[1L]]
}

connect_lake <- function() {
  lake <- ledgr.sharadar::sharadar_connect_lake(
    file.path(root, "lake", "ledgr-research.duckdb"),
    read_only = TRUE,
    require_sentinel = TRUE
  )
  DBI::dbExecute(lake, "SET threads = 1")
  lake
}

query_threads <- function(con) {
  as.integer(DBI::dbGetQuery(
    con,
    "SELECT current_setting('threads') AS threads"
  )$threads[[1L]])
}

default_duckdb_threads <- function() {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  query_threads(con)
}

scalar_text <- function(x) {
  if (is.null(x) || !length(x) || is.na(x[[1L]])) return(NA_character_)
  as.character(x[[1L]])
}

require_identical <- function(actual, expected, label) {
  if (!identical(as.character(actual), as.character(expected))) {
    stop(label, " did not match its accepted WS39 value.", call. = FALSE)
  }
}

if (identical(stage, "build")) {
  if (file.exists(snapshot_path) || file.exists(paste0(snapshot_path, ".wal"))) {
    stop("The fresh WS39 destination already exists; it will not be deleted.", call. = FALSE)
  }
  started <- Sys.time()
  ledgr_commit <- git_commit(ledgr_repo)
  adapter_commit <- git_commit(adapter_repo)
  duckdb_default_threads <- default_duckdb_threads()
  lake <- connect_lake()
  on.exit(DBI::dbDisconnect(lake, shutdown = TRUE), add = TRUE)

  build_rows <- DBI::dbGetQuery(lake, paste(
    "SELECT DISTINCT f.canonical_build_id FROM audit.full_history_runs f",
    "JOIN audit.data_mvp_closeouts c USING (full_history_run_id)",
    "WHERE f.reproducibility_status = 'matched'"
  ))
  if (nrow(build_rows) != 1L) {
    stop("WS39 requires exactly one qualified frozen canonical build.", call. = FALSE)
  }
  canonical_build_id <- as.character(build_rows$canonical_build_id[[1L]])
  canonical_identity <- ledgr.sharadar::sharadar_qualified_canonical_fingerprint(
    lake,
    canonical_build_id
  )
  universe_rows <- DBI::dbGetQuery(lake, paste(
    "SELECT DISTINCT reference_id FROM core.reference_membership",
    "WHERE canonical_build_id = ? AND quality_status = 'accepted'"
  ), params = list(canonical_build_id))
  if (nrow(universe_rows) != 1L) {
    stop("WS39 requires exactly one accepted membership universe.", call. = FALSE)
  }
  universe_id <- as.character(universe_rows$reference_id[[1L]])

  audit_counts <- DBI::dbGetQuery(lake, paste(
    "SELECT source_row_count, canonical_bar_count FROM audit.full_history_runs",
    "WHERE canonical_build_id = ? AND reproducibility_status = 'matched'"
  ), params = list(canonical_build_id))
  if (nrow(audit_counts) != 1L) {
    stop("WS39 could not resolve the frozen source aggregates.", call. = FALSE)
  }

  build_started <- Sys.time()
  snapshot <- ledgr.sharadar::sharadar_ledgr_snapshot(
    lake,
    canonical_build_id,
    from,
    to,
    snapshot_path
  )
  snapshot_build_elapsed_s <- round(as.numeric(difftime(
    Sys.time(), build_started, units = "secs"
  )), 2)
  info <- ledgr::ledgr_snapshot_info(snapshot)

  membership <- ledgr::ledgr_facts_history(
    snapshot,
    "membership",
    universe_id
  )
  sessions <- ledgr::ledgr_facts_history(snapshot, "sessions", "XNYS")
  membership_rows <- sum(
    membership$evidence$evidence_type == "membership_assertion"
  )
  membership_sets <- sum(membership$evidence$evidence_type == "set_header")
  open_sessions <- sum(sessions$rows$status == "open")

  provenance_json <- unique(c(
    as.character(membership$evidence$provenance_json),
    as.character(sessions$evidence$provenance_json)
  ))
  provenance_json <- provenance_json[!is.na(provenance_json) & nzchar(provenance_json)]
  provenance <- lapply(provenance_json, jsonlite::fromJSON)
  lineage_value <- function(value, field) {
    direct <- value[[field]]
    payload <- value[["payload"]]
    scalar_text(direct %||% if (is.list(payload)) payload[[field]] else NULL)
  }
  provenance_policy <- unique(vapply(
    provenance,
    lineage_value,
    character(1),
    field = "adapter_policy_version"
  ))
  provenance_build <- unique(vapply(
    provenance,
    lineage_value,
    character(1),
    field = "canonical_build_id"
  ))
  provenance_policy <- provenance_policy[!is.na(provenance_policy)]
  provenance_build <- provenance_build[!is.na(provenance_build)]
  if (length(provenance_policy) != 1L || length(provenance_build) != 1L) {
    stop("Adapter lineage was not singular in public fact evidence.", call. = FALSE)
  }
  require_identical(provenance_build, canonical_build_id, "Adapter build lineage")

  snapshot_id <- as.character(info$snapshot_id[[1L]])
  snapshot_hash <- as.character(info$snapshot_hash[[1L]])
  ledgr::ledgr_snapshot_close(snapshot)

  store <- DBI::dbConnect(
    duckdb::duckdb(config = list(threads = "1")),
    dbdir = snapshot_path,
    read_only = TRUE
  )
  on.exit(DBI::dbDisconnect(store, shutdown = TRUE), add = TRUE)
  markers <- DBI::dbGetQuery(store, paste(
    "SELECT key, value FROM ledgr_schema_metadata",
    "WHERE key IN ('experiment_store_schema_version', 'format_fingerprint')"
  ))
  marker <- stats::setNames(as.character(markers$value), as.character(markers$key))
  schema_version <- as.integer(marker[["experiment_store_schema_version"]])
  format_fingerprint <- marker[["format_fingerprint"]]
  identity_rule <- as.integer(
    jsonlite::fromJSON(format_fingerprint)$ledgr_identity_rule_version
  )
  lifetime_rows <- as.integer(DBI::dbGetQuery(
    store,
    "SELECT COUNT(*) AS n FROM snapshot_lifetime WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )$n[[1L]])
  fact_families <- as.integer(DBI::dbGetQuery(
    store,
    "SELECT COUNT(*) AS n FROM snapshot_fact_families WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )$n[[1L]])
  feature_table_present <- DBI::dbGetQuery(store, paste(
    "SELECT COUNT(*) AS n FROM information_schema.tables",
    "WHERE lower(table_name) = 'features'"
  ))$n[[1L]] > 0
  retired_telemetry_columns <- as.integer(DBI::dbGetQuery(store, paste(
    "SELECT COUNT(*) AS n FROM information_schema.columns",
    "WHERE lower(table_name) = 'run_telemetry' AND lower(column_name) IN",
    "('persist_features', 'feature_cache_hits', 'feature_cache_misses')"
  ))$n[[1L]])
  snapshot_ids <- DBI::dbGetQuery(
    store,
    "SELECT instrument_id FROM snapshot_instruments WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )

  duckdb::duckdb_register(lake, "ws39_snapshot_axis", snapshot_ids)
  on.exit(try(duckdb::duckdb_unregister(lake, "ws39_snapshot_axis"), silent = TRUE), add = TRUE)
  source <- DBI::dbGetQuery(lake, paste(
    "SELECT COUNT(*) AS bars, COUNT(DISTINCT b.instrument_id) AS instruments,",
    "MIN(b.trade_date) AS start_date, MAX(b.trade_date) AS end_date",
    "FROM core.daily_bars b JOIN ws39_snapshot_axis a",
    "ON a.instrument_id = b.instrument_id",
    "WHERE b.canonical_build_id = ? AND b.trade_date BETWEEN ? AND ?",
    "AND b.adjustment_policy = 'split_adjusted'",
    "AND b.quality_status = 'accepted'",
    "AND (b.volume IS NULL OR b.volume > 0)"
  ), params = list(canonical_build_id, from, to))
  dropped <- DBI::dbGetQuery(lake, paste(
    "SELECT COUNT(*) AS bars, COUNT(DISTINCT b.instrument_id) AS instruments",
    "FROM core.daily_bars b JOIN ws39_snapshot_axis a",
    "ON a.instrument_id = b.instrument_id",
    "WHERE b.canonical_build_id = ? AND b.trade_date BETWEEN ? AND ?",
    "AND b.adjustment_policy = 'split_adjusted'",
    "AND b.quality_status = 'accepted' AND b.volume = 0"
  ), params = list(canonical_build_id, from, to))

  prior_path <- file.path(
    ledgr_repo,
    "dev", "bench", "v0_2_2_sharadar_run", "evidence",
    "ws30_locale_identity", "build_summary.csv"
  )
  prior <- utils::read.csv(prior_path, stringsAsFactors = FALSE)
  prior_value <- function(key) {
    value <- prior$value[match(key, prior$key)]
    if (length(value) != 1L || is.na(value)) {
      stop("The accepted schema-119 aggregate record is incomplete.", call. = FALSE)
    }
    as.character(value)
  }

  require_identical(schema_version, 120L, "Store schema version")
  require_identical(identity_rule, 3L, "Identity rule version")
  require_identical(info$hash_rule_version[[1L]], 3L, "Snapshot hash rule")
  require_identical(info$status[[1L]], "SEALED", "Snapshot status")
  require_identical(info$bar_count[[1L]], source$bars[[1L]], "Frozen-source bar count")
  require_identical(info$instrument_count[[1L]], source$instruments[[1L]], "Frozen-source instrument count")
  require_identical(
    substr(info$start_date[[1L]], 1L, 10L),
    source$start_date[[1L]],
    "Frozen-source start date"
  )
  require_identical(
    substr(info$end_date[[1L]], 1L, 10L),
    source$end_date[[1L]],
    "Frozen-source end date"
  )
  require_identical(info$bar_count[[1L]], prior_value("bars"), "Prior-record bar count")
  require_identical(info$instrument_count[[1L]], prior_value("instruments_with_bars"), "Prior-record instrument count")
  require_identical(open_sessions, prior_value("open_sessions"), "Prior-record session count")
  require_identical(membership_rows, prior_value("membership_rows"), "Prior-record membership count")
  require_identical(membership_sets, prior_value("membership_sets"), "Prior-record membership-set count")
  require_identical(lifetime_rows, prior_value("lifetime_rows"), "Prior-record lifetime count")
  require_identical(snapshot_hash, prior_value("snapshot_hash"), "Prior-record snapshot hash")
  require_identical(fact_families, 3L, "Declared fact-family count")
  if (isTRUE(feature_table_present) || retired_telemetry_columns != 0L) {
    stop("The fresh store retained schema-119 feature persistence surfaces.", call. = FALSE)
  }

  host_info <- Sys.info()
  result <- list(
    ledgr_commit = ledgr_commit,
    adapter_commit = adapter_commit,
    canonical_build_id = canonical_build_id,
    canonical_fingerprint = canonical_identity$canonical_fingerprint,
    adapter_policy = provenance_policy[[1L]],
    snapshot_id = snapshot_id,
    snapshot_hash = snapshot_hash,
    snapshot_status = as.character(info$status[[1L]]),
    experiment_store_schema_version = schema_version,
    identity_rule_version = identity_rule,
    snapshot_hash_rule_version = as.integer(info$hash_rule_version[[1L]]),
    format_fingerprint = format_fingerprint,
    snapshot_build_elapsed_s = snapshot_build_elapsed_s,
    worker_elapsed_s = round(as.numeric(difftime(Sys.time(), started, units = "secs")), 2),
    bars = as.integer(info$bar_count[[1L]]),
    instruments = as.integer(info$instrument_count[[1L]]),
    open_sessions = as.integer(open_sessions),
    membership_rows = as.integer(membership_rows),
    membership_sets = as.integer(membership_sets),
    lifetime_rows = lifetime_rows,
    fact_families = fact_families,
    off_session_bars = as.integer(info$off_session_bar_count[[1L]]),
    start_date = as.character(info$start_date[[1L]]),
    end_date = as.character(info$end_date[[1L]]),
    source_bars = as.integer(source$bars[[1L]]),
    source_instruments = as.integer(source$instruments[[1L]]),
    source_start_date = as.character(source$start_date[[1L]]),
    source_end_date = as.character(source$end_date[[1L]]),
    untraded_bars_dropped = as.integer(dropped$bars[[1L]]),
    untraded_bar_instruments = as.integer(dropped$instruments[[1L]]),
    vendor_source_rows = as.numeric(audit_counts$source_row_count[[1L]]),
    canonical_bar_rows = as.numeric(audit_counts$canonical_bar_count[[1L]]),
    feature_table_present = feature_table_present,
    retired_telemetry_columns_present = retired_telemetry_columns,
    prior_bars = as.integer(prior_value("bars")),
    prior_instruments = as.integer(prior_value("instruments_with_bars")),
    prior_open_sessions = as.integer(prior_value("open_sessions")),
    prior_membership_rows = as.integer(prior_value("membership_rows")),
    prior_membership_sets = as.integer(prior_value("membership_sets")),
    prior_lifetime_rows = as.integer(prior_value("lifetime_rows")),
    prior_snapshot_hash = prior_value("snapshot_hash"),
    host = paste(host_info[["sysname"]], host_info[["release"]], host_info[["machine"]]),
    r_version = R.version.string,
    duckdb_version = as.character(utils::packageVersion("duckdb")),
    duckdb_threads = paste0(
      "adapter lake=", query_threads(lake),
      "; ledgr default=", duckdb_default_threads,
      "; aggregate inspection=", query_threads(store)
    )
  )
  jsonlite::write_json(
    list(
      snapshot_path = snapshot_path,
      snapshot_id = snapshot_id,
      snapshot_hash = snapshot_hash,
      universe_id = universe_id
    ),
    state_path,
    auto_unbox = TRUE,
    pretty = TRUE
  )
  write_result(result)
}

if (identical(stage, "cold_verify")) {
  state <- read_state()
  started <- Sys.time()
  snapshot <- ledgr::ledgr_snapshot_open(
    state$snapshot_path,
    state$snapshot_id,
    verify = TRUE
  )
  verification_elapsed_s <- round(as.numeric(difftime(
    Sys.time(), started, units = "secs"
  )), 2)
  info <- ledgr::ledgr_snapshot_info(snapshot)
  ledgr::ledgr_snapshot_close(snapshot)

  store <- DBI::dbConnect(
    duckdb::duckdb(config = list(threads = "1")),
    dbdir = state$snapshot_path,
    read_only = TRUE
  )
  on.exit(DBI::dbDisconnect(store, shutdown = TRUE), add = TRUE)
  schema_valid <- tryCatch(
    {
      ledgr::ledgr_validate_schema(store)
      TRUE
    },
    error = function(error) FALSE
  )
  require_identical(info$snapshot_id[[1L]], state$snapshot_id, "Cold-open snapshot ID")
  require_identical(info$snapshot_hash[[1L]], state$snapshot_hash, "Cold-open snapshot hash")
  if (!isTRUE(info$verified_in_process[[1L]]) || !schema_valid) {
    stop("Cold rule-3 verification or public schema validation failed.", call. = FALSE)
  }
  write_result(list(
    snapshot_id = as.character(info$snapshot_id[[1L]]),
    snapshot_hash = as.character(info$snapshot_hash[[1L]]),
    verification_result = "pass",
    verified_in_process = isTRUE(info$verified_in_process[[1L]]),
    verification_elapsed_s = verification_elapsed_s,
    schema_validation = "pass"
  ))
}

run_probe <- function(dynamic) {
  state <- read_state()
  snapshot <- ledgr::ledgr_snapshot_open(
    state$snapshot_path,
    state$snapshot_id,
    verify = FALSE
  )
  on.exit(ledgr::ledgr_snapshot_close(snapshot), add = TRUE)
  universe <- if (isTRUE(dynamic)) {
    ledgr::ledgr_universe_members(state$universe_id)
  } else {
    NULL
  }
  experiment <- ledgr::ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$hold(),
    universe = universe,
    opening = ledgr::ledgr_opening(cash = 1000000, date = "2026-08-03"),
    valuation_policy = ledgr::ledgr_valuation_stale(5L),
    cost_model = ledgr::ledgr_cost_zero()
  )
  run_id <- if (isTRUE(dynamic)) {
    "ws39-dynamic-membership"
  } else {
    "ws39-full-membership"
  }
  backtest <- ledgr::ledgr_run(experiment, params = list(), run_id = run_id)
  on.exit(close(backtest), add = TRUE)
  info <- ledgr::ledgr_run_info(snapshot, run_id)
  snapshot_info <- ledgr::ledgr_snapshot_info(snapshot)
  equity <- ledgr::ledgr_results(backtest, "equity")
  fills <- ledgr::ledgr_results(backtest, "fills")
  require_identical(info$snapshot_id, state$snapshot_id, "Experiment snapshot ID")
  require_identical(info$snapshot_hash, state$snapshot_hash, "Experiment snapshot hash")
  require_identical(info$schema_version, 120L, "Experiment schema version")
  require_identical(info$status, "DONE", "Experiment status")
  if (!isTRUE(experiment$availability$active) ||
      !isTRUE(snapshot_info$verified_in_process[[1L]])) {
    stop("Representative experiment did not use verified availability execution.", call. = FALSE)
  }
  list(
    run_id = run_id,
    status = as.character(info$status),
    snapshot_id = as.character(info$snapshot_id),
    snapshot_hash = as.character(info$snapshot_hash),
    schema_version = as.integer(info$schema_version),
    config_hash = as.character(info$config_hash),
    availability_active = isTRUE(experiment$availability$active),
    pulse_count = as.integer(info$pulse_count),
    elapsed_sec = as.numeric(info$elapsed_sec),
    equity_rows = nrow(equity),
    fill_rows = nrow(fills)
  )
}

if (identical(stage, "full_membership")) {
  write_result(run_probe(dynamic = FALSE))
}

if (identical(stage, "availability")) {
  write_result(run_probe(dynamic = TRUE))
}

cat("STAGE_DONE ", stage, "\n", sep = "")
