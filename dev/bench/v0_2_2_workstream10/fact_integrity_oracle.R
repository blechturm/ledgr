args <- commandArgs(trailingOnly = TRUE)
output_dir <- if (length(args) >= 1L) args[[1L]] else file.path(
  "tests", "testthat", "fixtures", "ws10-fact-integrity"
)

pkgload::load_all(".", quiet = TRUE, export_all = TRUE)
source(file.path("tests", "test-control-plane.R"), local = globalenv())
source(file.path("tests", "testthat", "helper-workstream14-facts.R"),
       local = globalenv())
source(file.path(
  "tests", "testthat", "helper-workstream10-fact-integrity.R"
), local = globalenv())

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

sha256_bytes <- function(value) {
  digest::digest(charToRaw(enc2utf8(value)), algo = "sha256", serialize = FALSE)
}

write_bytes <- function(value, file) {
  connection <- file(file.path(output_dir, file), open = "wb")
  on.exit(close(connection), add = TRUE)
  writeBin(charToRaw(enc2utf8(value)), connection)
}

environment_fields <- list(
  r_version = paste(R.version$major, R.version$minor, sep = "."),
  duckdb_version = as.character(utils::packageVersion("duckdb")),
  digest_version = as.character(utils::packageVersion("digest")),
  yyjsonr_version = as.character(utils::packageVersion("yyjsonr"))
)

records <- list()
add_record <- function(record_type,
                       artifact_id,
                       family,
                       shape,
                       file,
                       value,
                       identity_hash,
                       public_boundary,
                       oracle_independence) {
  write_bytes(value, file)
  records[[length(records) + 1L]] <<- data.frame(
    record_type = record_type,
    artifact_id = artifact_id,
    family = family,
    shape = shape,
    file = file,
    byte_length = length(charToRaw(enc2utf8(value))),
    sha256 = sha256_bytes(value),
    identity_hash = identity_hash,
    public_boundary = public_boundary,
    oracle_independence = oracle_independence,
    r_version = environment_fields$r_version,
    duckdb_version = environment_fields$duckdb_version,
    digest_version = environment_fields$digest_version,
    yyjsonr_version = environment_fields$yyjsonr_version,
    stringsAsFactors = FALSE
  )
}

shapes <- ws10_fact_shapes()
for (shape in names(shapes)) {
  family <- shapes[[shape]]
  boundary <- switch(
    family$family,
    membership = if (identical(shape, "membership_snapshots")) {
      "ledgr_facts_membership_snapshots()"
    } else {
      "ledgr_facts_membership_intervals()"
    },
    trading_status = "ledgr_facts_trading_status()",
    lifetime = "ledgr_facts_lifetime()",
    equity_corporate_actions =
      "ledgr_facts_equity_corporate_actions()",
    sessions = "ledgr_facts_sessions()"
  )
  independence <- paste(
    "Frozen before LDG-2948; exact bytes come from normalized public",
    "constructor output, not from the candidate timestamp mapper."
  )
  artifacts <- list(
    rows = ledgr:::ledgr_fact_frame_payload_json(family$rows),
    headers = ledgr:::ledgr_fact_frame_payload_json(family$headers),
    family = ledgr:::ledgr_fact_family_payload_json(
      family$family,
      family$scope_id,
      family$rows,
      family$headers,
      family$metadata
    )
  )
  for (kind in names(artifacts)) {
    file <- paste0(shape, "_", kind, ".json")
    add_record(
      record_type = kind,
      artifact_id = paste(shape, kind, sep = ":"),
      family = family$family,
      shape = shape,
      file = file,
      value = artifacts[[kind]],
      identity_hash = if (identical(kind, "family")) {
        family$fact_hash
      } else {
        ""
      },
      public_boundary = boundary,
      oracle_independence = independence
    )
  }
}

bundle <- ws10_fact_bundle()
bundle_payload <- as.character(ledgr:::canonical_json(list(
  schema = "ledgr_facts_v1",
  family_hashes = vapply(bundle$families, `[[`, character(1), "fact_hash")
)))
add_record(
  record_type = "bundle",
  artifact_id = "all_families:bundle",
  family = "all",
  shape = "six_registered_shapes",
  file = "bundle.json",
  value = bundle_payload,
  identity_hash = bundle$bundle_hash,
  public_boundary = "ledgr_facts()",
  oracle_independence = paste(
    "Frozen before LDG-2948 from six independently constructed family",
    "objects; the candidate does not supply expected hashes."
  )
)

db_path <- tempfile(fileext = ".duckdb")
snapshot <- ws10_fact_snapshot(db_path)
snapshot_id <- snapshot$snapshot_id
snapshot_hash <- ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
ledgr_snapshot_close(snapshot)
reopened <- ledgr_snapshot_open(db_path, snapshot_id, verify = FALSE)
reopened_hash <- ledgr_snapshot_info(reopened)$snapshot_hash[[1L]]
ledgr_snapshot_close(reopened)
unlink(db_path)
if (!identical(snapshot_hash, reopened_hash)) {
  stop("Fresh and reopened snapshot hashes differ.")
}

records[[length(records) + 1L]] <- data.frame(
  record_type = "snapshot",
  artifact_id = "rule2:fresh_and_reopened",
  family = "all",
  shape = "six_shapes_10_supplied_9_bars_1_quarantine",
  file = "",
  byte_length = NA_integer_,
  sha256 = snapshot_hash,
  identity_hash = snapshot_hash,
  public_boundary = paste(
    "ledgr_snapshot_from_df(); ledgr_snapshot_open();",
    "ledgr_facts_resolve()"
  ),
  oracle_independence = paste(
    "The stored rule-2 hash is recomputed from persisted rows on each public",
    "facts-resolution boundary; no stored component digest is trusted."
  ),
  r_version = environment_fields$r_version,
  duckdb_version = environment_fields$duckdb_version,
  digest_version = environment_fields$digest_version,
  yyjsonr_version = environment_fields$yyjsonr_version,
  stringsAsFactors = FALSE
)

manifest <- do.call(rbind, records)
utils::write.csv(
  manifest,
  file.path(output_dir, "manifest.csv"),
  row.names = FALSE,
  na = ""
)
message("FACT_INTEGRITY_ORACLE_WRITTEN: ", nrow(manifest), " records")
