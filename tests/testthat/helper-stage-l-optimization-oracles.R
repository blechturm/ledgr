# Frozen before the v0.2.0.1 dense-axis and snapshot-hash optimizations.
# These helpers deliberately preserve the Stage L implementation shape so the
# later candidate paths have an independent current-arm oracle.

ledgr_stage_l_source_sha256 <- c(
  availability_ingest =
    "5d23be381943affbdce6f51bf61022723f01247ab9ae8012286109264eb46559",
  precompute_features =
    "cb9f6c8ed78084f9c4c1a3a2641e7335455dc8516d55ba484553de3032c6a311",
  snapshots_hash =
    "5eb67ec6663db24109df96d1e31ca45187618cbf703212c5181157d61a42547b"
)

ledgr_stage_l_normalized_source_sha256 <- function(path) {
  digest::digest(
    paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"),
    algo = "sha256",
    serialize = FALSE
  )
}

ledgr_stage_l_dense_ts_key_oracle <- function(x) {
  vapply(
    as.POSIXct(x, tz = "UTC"),
    ledgr_normalize_ts_utc,
    character(1L)
  )
}

ledgr_stage_l_validate_static_coverage_oracle <- function(bars_by_id, universe) {
  missing <- setdiff(universe, names(bars_by_id))
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf(
        "Precomputed feature scoring range is missing bars for instrument(s): %s.",
        paste(missing, collapse = ", ")
      ),
      class = "ledgr_precomputed_coverage_error"
    )
  }
  pulses <- NULL
  for (id in universe) {
    bars <- bars_by_id[[id]]
    if (is.null(bars) || nrow(bars) == 0L) {
      rlang::abort(
        sprintf(
          "Precomputed feature scoring range is missing bars for instrument: %s.",
          id
        ),
        class = "ledgr_precomputed_coverage_error"
      )
    }
    ts <- ledgr_stage_l_dense_ts_key_oracle(bars$ts_utc)
    if (is.null(pulses)) {
      pulses <- ts
    } else if (!identical(ts, pulses)) {
      rlang::abort(
        paste(
          "Precomputed feature scoring range has incomplete or misaligned",
          "per-instrument bars."
        ),
        class = "ledgr_precomputed_coverage_error"
      )
    }
  }
  invisible(TRUE)
}

ledgr_stage_l_snapshot_hash_ts_oracle <- function(x) {
  if (!inherits(x, "POSIXct")) {
    rlang::abort(
      "`ts_utc` must be a POSIXct vector while hashing snapshots.",
      class = c(
        "ledgr_snapshot_hash_invalid_timestamp",
        "ledgr_invalid_state"
      )
    )
  }
  format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}
