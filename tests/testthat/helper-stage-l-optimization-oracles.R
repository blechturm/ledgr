# Frozen before the v0.2.0.1 dense-axis and snapshot-hash optimizations.
# These helpers deliberately preserve the Stage L implementation shape so the
# later candidate paths have an independent current-arm oracle.

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
