# Freeze the Stage L current-arm inputs before LDG-2742 or LDG-2743 changes
# dense timestamp validation or snapshot hashing. This is evidence capture, not
# an optimization benchmark or a release claim.

options(warn = 1)

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(repo_root, "DESCRIPTION"))) {
  stop("Run this script from the ledgr repository root.", call. = FALSE)
}
pkgload::load_all(repo_root, quiet = TRUE)

packet_dir <- file.path(
  repo_root,
  "inst",
  "design",
  "ledgr_v0_2_0_1_spec_packet"
)
record_prefix <- file.path(
  repo_root,
  "dev",
  "bench",
  "results",
  "peer_benchmark_record_20260917T231851Z"
)

source_sha256 <- function(path) {
  digest::digest(
    paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"),
    algo = "sha256",
    serialize = FALSE
  )
}

elapsed <- function(expr) {
  unname(system.time(force(expr))[["elapsed"]])
}

axis <- as.POSIXct("2019-01-01 00:00:00", tz = "UTC") +
  seq.int(0, length.out = 1260L) * 86400
universe <- sprintf("STAGE_L_%04d", seq_len(500L))
bars_by_id <- stats::setNames(
  rep(list(data.frame(ts_utc = axis)), length(universe)),
  universe
)

invisible(ledgr:::ledgr_precompute_validate_static_coverage(
  bars_by_id,
  universe
))
dense_sec <- vapply(seq_len(3L), function(i) elapsed(
  ledgr:::ledgr_precompute_validate_static_coverage(bars_by_id, universe)
), numeric(1L))

bars <- as.data.frame(ledgr_sim_bars(
  n_instruments = 500L,
  n_days = 1260L,
  seed = 20260530L,
  instrument_prefix = "STAGE_L_"
))
db_path <- tempfile(pattern = "ledgr-stage-l-", fileext = ".duckdb")
snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
con <- ledgr:::get_connection(snapshot)

warm_hash <- ledgr:::ledgr_snapshot_hash(con, snapshot$snapshot_id)
hash_sec <- numeric(3L)
hash_value <- character(3L)
for (i in seq_len(3L)) {
  t0 <- proc.time()[["elapsed"]]
  hash_value[[i]] <- ledgr:::ledgr_snapshot_hash(con, snapshot$snapshot_id)
  hash_sec[[i]] <- proc.time()[["elapsed"]] - t0
}
if (!identical(unique(c(warm_hash, hash_value)), warm_hash)) {
  stop("Stage L hash repetitions were not byte-identical.", call. = FALSE)
}

environment <- paste0(
  "R ", getRversion(), "; ledgr ", utils::packageVersion("ledgr"),
  "; duckdb ", utils::packageVersion("duckdb"),
  "; collapse ", utils::packageVersion("collapse")
)
prefixes <- rbind(
  data.frame(
    mechanism = "dense_static_coverage",
    repetition = seq_len(3L),
    wall_sec = dense_sec,
    row_count = length(axis) * length(universe),
    semantic_fingerprint = digest::digest(
      list(universe = universe, axis = as.numeric(axis)),
      algo = "sha256"
    ),
    environment = environment,
    stringsAsFactors = FALSE
  ),
  data.frame(
    mechanism = "snapshot_hash_rule_1",
    repetition = seq_len(3L),
    wall_sec = hash_sec,
    row_count = nrow(bars),
    semantic_fingerprint = hash_value,
    environment = environment,
    stringsAsFactors = FALSE
  )
)
utils::write.csv(
  prefixes,
  file.path(packet_dir, "batch11-current-arm-prefixes.csv"),
  row.names = FALSE,
  na = ""
)

performance_path <- paste0(record_prefix, "_performance.csv")
if (!file.exists(performance_path)) {
  stop("The corrected public-sweep diagnostic record is unavailable.", call. = FALSE)
}
performance <- utils::read.csv(performance_path, stringsAsFactors = FALSE)
engines <- c(
  "ledgr_ttr_canonical_sweep",
  "ledgr_ttr_compiled_spot_fifo_sweep"
)
public_prefix <- performance[performance$engine %in% engines, , drop = FALSE]
public_prefix <- public_prefix[match(engines, public_prefix$engine), , drop = FALSE]
if (nrow(public_prefix) != 2L || anyNA(public_prefix$engine)) {
  stop("The corrected record lacks both public-sweep rows.", call. = FALSE)
}
public_prefix$equity_sha256 <- vapply(public_prefix$engine, function(engine) {
  digest::digest(
    file = paste0(record_prefix, "_", engine, "_equity.csv"),
    algo = "sha256",
    serialize = FALSE
  )
}, character(1L))
public_prefix$fills_sha256 <- vapply(public_prefix$engine, function(engine) {
  digest::digest(
    file = paste0(record_prefix, "_", engine, "_fills.csv"),
    algo = "sha256",
    serialize = FALSE
  )
}, character(1L))
public_prefix$trades_sha256 <- vapply(public_prefix$engine, function(engine) {
  digest::digest(
    file = paste0(record_prefix, "_", engine, "_trades.csv"),
    algo = "sha256",
    serialize = FALSE
  )
}, character(1L))
public_prefix$record_role <- "diagnostic_current_arm_prefix"
utils::write.csv(
  public_prefix,
  file.path(packet_dir, "batch11-public-sweep-prefixes.csv"),
  row.names = FALSE,
  na = ""
)

source_paths <- c(
  "R/availability-ingest.R",
  "R/precompute-features.R",
  "R/snapshots-hash.R"
)
source_guard <- data.frame(
  path = source_paths,
  normalized_sha256 = vapply(
    file.path(repo_root, source_paths),
    source_sha256,
    character(1L)
  ),
  role = c(
    "immutable_NEITHER_guard",
    "dense_current_arm_source",
    "hash_current_arm_source"
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(
  source_guard,
  file.path(packet_dir, "batch11-source-prefixes.csv"),
  row.names = FALSE
)

ledgr_snapshot_close(snapshot)
unlink(db_path)
message("BATCH11_CURRENT_PREFIXES_WRITTEN")
