# Frozen pre-change reference for LDG-2789.
#
# A verbatim copy of the ts_utc branch block as it stood in
# R/snapshot_adapters.R at c0a2a32, before the deduplicating rewrite. The
# matrix test in test-snapshot-timestamp-branches.R asserts that the production
# function returns identical ts_utc and ts_posix for every branch.
#
# Do not "fix" or tidy this body. Its value is that it is the old code. It
# converts every element, which is exactly what the new code avoids.
ldg2789_reference_normalize_ts_utc <- function(ts_raw) {
  ts_posix <- NULL
  if (inherits(ts_raw, "POSIXt")) {
    ts_posix <- as.POSIXct(ts_raw, tz = "UTC")
    if (length(ts_posix) != length(ts_raw) || anyNA(ts_posix)) {
      rlang::abort("bars_df `ts_utc` must be valid POSIXt values.", class = "ledgr_invalid_args")
    }
    ts_posix <- ledgr:::ledgr_assert_whole_second_utc(
      ts_posix,
      label = "bars_df `ts_utc`",
      class = "ledgr_invalid_args"
    )
    ts_utc <- format(ts_posix, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  } else if (inherits(ts_raw, "Date")) {
    if (length(ts_raw) == 0 || anyNA(ts_raw)) {
      rlang::abort("bars_df `ts_utc` must be valid Date values.", class = "ledgr_invalid_args")
    }
    ts_posix <- as.POSIXct(ts_raw, tz = "UTC")
    ts_utc <- sprintf("%sT00:00:00Z", format(ts_raw, "%Y-%m-%d"))
  } else if (is.character(ts_raw)) {
    if (anyNA(ts_raw) || any(!nzchar(ts_raw))) {
      rlang::abort("bars_df `ts_utc` must be non-empty timestamps.", class = "ledgr_invalid_args")
    }
    pat_date <- "^\\d{4}-\\d{2}-\\d{2}$"
    pat_dt <- "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}$"
    pat_dt_z <- "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$"

    if (all(grepl(pat_date, ts_raw))) {
      d <- as.Date(ts_raw, format = "%Y-%m-%d")
      if (anyNA(d)) {
        rlang::abort("bars_df `ts_utc` contains invalid dates.", class = "ledgr_invalid_args")
      }
      ts_posix <- as.POSIXct(d, tz = "UTC")
      ts_utc <- sprintf("%sT00:00:00Z", format(d, "%Y-%m-%d"))
    } else if (all(grepl(pat_dt_z, ts_raw))) {
      ts_posix <- as.POSIXct(ts_raw, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
      if (anyNA(ts_posix)) {
        rlang::abort("bars_df `ts_utc` contains invalid timestamps.", class = "ledgr_invalid_args")
      }
      ts_utc <- format(ts_posix, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    } else if (all(grepl(pat_dt, ts_raw))) {
      ts_posix <- as.POSIXct(ts_raw, tz = "UTC", format = "%Y-%m-%dT%H:%M:%S")
      if (anyNA(ts_posix)) {
        rlang::abort("bars_df `ts_utc` contains invalid timestamps.", class = "ledgr_invalid_args")
      }
      ts_utc <- format(ts_posix, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    } else {
      ts_utc <- vapply(ts_raw, ledgr:::ledgr_iso_utc, character(1))
      ts_posix <- as.POSIXct(ts_utc, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
      if (anyNA(ts_posix)) {
        rlang::abort("bars_df `ts_utc` contains invalid timestamps.", class = "ledgr_invalid_args")
      }
    }
  } else {
    ts_utc <- vapply(ts_raw, ledgr:::ledgr_iso_utc, character(1))
    ts_posix <- as.POSIXct(ts_utc, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
    if (anyNA(ts_posix)) {
      rlang::abort("bars_df `ts_utc` contains invalid timestamps.", class = "ledgr_invalid_args")
    }
  }
  list(ts_utc = ts_utc, ts_posix = ts_posix)
}
