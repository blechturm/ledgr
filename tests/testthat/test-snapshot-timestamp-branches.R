# ledgr-test-file-profile: review
#
# LDG-2789. ledgr_snapshot_normalize_ts_utc() deduplicates before it converts
# and, on two branches, returns the supplied strings instead of reformatting
# the parse. Every branch must be exact. The witness is the frozen pre-change
# body in helper-ldg2789-reference-ts.R, which converts every element.

ldg2789_cases <- function() {
  sessions <- as.POSIXct("2020-01-01", tz = "UTC") + (0:4) * 86400
  dates <- as.Date("2020-01-01") + 0:4
  iso_z <- format(sessions, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  no_z <- format(sessions, "%Y-%m-%dT%H:%M:%S", tz = "UTC")

  list(
    POSIXct = rep(sessions, times = 3L),
    Date = rep(dates, times = 3L),
    date_only_character = rep(format(dates, "%Y-%m-%d"), times = 3L),
    iso_with_Z = rep(iso_z, times = 3L),
    iso_without_Z = rep(no_z, times = 3L),
    # Mixed forms miss every fast branch and reach the scalar fallback.
    mixed_fallback = c(iso_z[1:2], format(dates[3:5], "%Y-%m-%d"))
  )
}

test_that("every producing timestamp branch is identical to the pre-change body", {
  for (nm in names(ldg2789_cases())) {
    input <- ldg2789_cases()[[nm]]
    got <- ledgr:::ledgr_snapshot_normalize_ts_utc(input)
    want <- ldg2789_reference_normalize_ts_utc(input)

    # Values compare unnamed: see the names block below, which pins the one
    # deliberate difference between the two bodies.
    expect_identical(got$ts_utc, unname(want$ts_utc), info = paste("ts_utc,", nm))
    expect_identical(got$ts_posix, unname(want$ts_posix), info = paste("ts_posix,", nm))
    expect_length(got$ts_utc, length(input))
    expect_length(got$ts_posix, length(input))
  }
})

# The one deliberate difference from the pre-change body, pinned so it cannot
# drift unnoticed. On the scalar fallback only, the old code built ts_utc with
# vapply() over the raw column, which labelled every element with its own input
# string, and those names flowed into ts_posix. Nothing read them: the names
# are dropped by paste() when the duplicate key is built, and by the DuckDB
# write, so no persisted value and no snapshot hash ever depended on them. The
# new body deduplicates before converting, so re-attaching per-element names
# would mean inventing them. It returns unnamed vectors on every branch.
test_that("the fallback branch no longer labels its output with the raw input", {
  input <- c("2020-01-02T00:00:00Z", "2020-01-01", "2020-01-01")

  old <- ldg2789_reference_normalize_ts_utc(input)
  expect_identical(names(old$ts_utc), input)
  expect_identical(names(old$ts_posix), input)

  new <- ledgr:::ledgr_snapshot_normalize_ts_utc(input)
  expect_null(names(new$ts_utc))
  expect_null(names(new$ts_posix))
  expect_identical(new$ts_utc, unname(old$ts_utc))

  # And the sealed snapshot is unaffected either way.
  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = c("2020-01-01", "2020-01-02T00:00:00Z", "2020-01-03"),
    open = 1, high = 1, low = 1, close = 1, volume = 1,
    stringsAsFactors = FALSE
  )
  snap <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)
  expect_identical(snap$metadata$start_date, "2020-01-01T00:00:00Z")
  expect_identical(snap$metadata$end_date, "2020-01-03T00:00:00Z")
})

# The fallback case carries literal expected values rather than a reference
# call, because the reference body and the production body both delegate to
# ledgr_iso_utc(). A change to that shared helper would move both together and
# leave the comparison above silent.
test_that("the mixed-form fallback produces literal canonical timestamps", {
  input <- c(
    "2020-01-02T00:00:00Z",
    "2020-01-01",
    "2020-01-03T14:30:00",
    "2020-01-01"
  )
  got <- ledgr:::ledgr_snapshot_normalize_ts_utc(input)

  expect_identical(
    got$ts_utc,
    c(
      "2020-01-02T00:00:00Z",
      "2020-01-01T00:00:00Z",
      "2020-01-03T14:30:00Z",
      "2020-01-01T00:00:00Z"
    )
  )
  expect_identical(
    got$ts_posix,
    as.POSIXct(
      c("2020-01-02 00:00:00", "2020-01-01 00:00:00",
        "2020-01-03 14:30:00", "2020-01-01 00:00:00"),
      tz = "UTC"
    )
  )
})

test_that("each fast branch produces literal canonical timestamps", {
  expect_identical(
    ledgr:::ledgr_snapshot_normalize_ts_utc(
      as.POSIXct(c("2020-01-01 00:00:00", "2020-01-02 14:30:00"), tz = "UTC")
    )$ts_utc,
    c("2020-01-01T00:00:00Z", "2020-01-02T14:30:00Z")
  )
  expect_identical(
    ledgr:::ledgr_snapshot_normalize_ts_utc(as.Date(c("2020-01-01", "2020-01-02")))$ts_utc,
    c("2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z")
  )
  expect_identical(
    ledgr:::ledgr_snapshot_normalize_ts_utc(c("2020-01-01", "2020-01-02"))$ts_utc,
    c("2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z")
  )
  # Nonzero seconds, so a change that zeroed the seconds field in the ISO-Z
  # branch could not pass. The close review named that blind spot: every other
  # ISO-Z literal here ends in :00.
  expect_identical(
    ledgr:::ledgr_snapshot_normalize_ts_utc(
      c("2020-01-01T00:00:00Z", "2020-01-02T14:30:37Z")
    )$ts_utc,
    c("2020-01-01T00:00:00Z", "2020-01-02T14:30:37Z")
  )
  expect_identical(
    ledgr:::ledgr_snapshot_normalize_ts_utc(
      c("2020-01-01T00:00:00", "2020-01-02T14:30:37")
    )$ts_utc,
    c("2020-01-01T00:00:00Z", "2020-01-02T14:30:37Z")
  )
  expect_identical(
    ledgr:::ledgr_snapshot_normalize_ts_utc(
      as.POSIXct(c("2020-01-01 00:00:00", "2020-01-02 14:30:37"), tz = "UTC")
    )$ts_utc,
    c("2020-01-01T00:00:00Z", "2020-01-02T14:30:37Z")
  )
  expect_identical(
    ledgr:::ledgr_snapshot_normalize_ts_utc(
      c("2020-01-01T00:00:00", "2020-01-02T14:30:00")
    )$ts_utc,
    c("2020-01-01T00:00:00Z", "2020-01-02T14:30:00Z")
  )
})

# The invalid branch has no output to compare, so it asserts the rejection
# itself: the same condition class and message as the pre-change body, and the
# same position in the order of checks.
test_that("invalid and mixed-type timestamp input is rejected as before", {
  args <- "ledgr_invalid_args"
  rejections <- list(
    list(input = c("2020-01-01", NA_character_), msg = "must be non-empty timestamps", cls = args),
    list(input = c("2020-01-01", ""), msg = "must be non-empty timestamps", cls = args),
    # Shaped like a date, so it reaches the date branch and fails there.
    list(input = c("2020-13-45", "2020-13-46"), msg = "contains invalid dates", cls = args),
    # No fast branch matches, so the scalar fallback rejects it with its own
    # class. That is pre-change behaviour and is pinned, not corrected here.
    list(input = c("not a time", "also not"), msg = "must be a UTC timestamp",
         cls = "ledgr_invalid_timestamp"),
    list(input = as.POSIXct(c("2020-01-01", NA), tz = "UTC"), msg = "must be valid POSIXt values", cls = args),
    list(input = as.Date(c("2020-01-01", NA)), msg = "must be valid Date values", cls = args),
    # W7-F1: a non-time column. The frozen body has an explicit final else for
    # it, and it must reject with the same class and message after the rewrite.
    list(input = c(1, 2), msg = "must be a non-empty ISO 8601 string",
         cls = "ledgr_invalid_timestamp"),
    list(input = factor(c("2020-01-01", "2020-01-02")),
         msg = "must be a non-empty ISO 8601 string", cls = "ledgr_invalid_timestamp")
  )

  for (case in rejections) {
    expect_error(
      ledgr:::ledgr_snapshot_normalize_ts_utc(case$input),
      case$msg,
      class = case$cls,
      info = case$msg
    )
    expect_error(
      ldg2789_reference_normalize_ts_utc(case$input),
      case$msg,
      class = case$cls,
      info = paste("reference,", case$msg)
    )
  }
})

# Order of checks: a bars frame missing a required column must fail on the
# column check before any timestamp work, both before and after the rewrite.
test_that("the missing-column check still fires before timestamp normalization", {
  bad <- data.frame(
    instrument_id = "AAA",
    ts_utc = "not a parseable timestamp",
    open = 1, high = 1, low = 1,
    stringsAsFactors = FALSE
  )
  expect_error(
    ledgr_snapshot_from_df(bad),
    "bars_df missing required column",
    class = "ledgr_invalid_args"
  )
})

# Sub-second POSIXct input must still be rejected by the whole-second
# contract, which the POSIXct branch applies before formatting.
test_that("sub-second POSIXct input is still rejected", {
  expect_error(
    ledgr:::ledgr_snapshot_normalize_ts_utc(
      as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + c(0, 0.5)
    ),
    class = "ledgr_invalid_args"
  )
})

# Snapshot identity pin. The hash below is a literal, computed at c0a2a32
# before the LDG-2789 rewrite and unchanged by it. The three input forms take
# three different branches of ledgr_snapshot_normalize_ts_utc() and must all
# seal to it. If a future change to timestamp normalization moves this value,
# it has changed durable snapshot identity and needs its own decision, not a
# new literal here. Registered as LCL-0015.
test_that("[LTB-0018] the checked-in bars fixture seals to its pinned snapshot hash", {
  pinned <- "58dd5b2c7cc5beb57b07130ec36d62fb47b3f61175e2e4e001f98b729dbf2bbd"

  hash_of <- function(snap) {
    con <- ledgr_db_init(snap$db_path)
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
    ledgr_snapshot_info(con, snap$snapshot_id)$snapshot_hash
  }

  # ISO-Z character input: the branch that now keeps the supplied strings.
  from_iso_z <- ledgr_snapshot_from_df(test_bars)
  on.exit(ledgr_snapshot_close(from_iso_z), add = TRUE)
  expect_identical(hash_of(from_iso_z), pinned)

  # Date-only character input: the branch that appends a constant suffix.
  date_only <- test_bars
  date_only$ts_utc <- substr(date_only$ts_utc, 1, 10)
  from_date_only <- ledgr_snapshot_from_df(date_only)
  on.exit(ledgr_snapshot_close(from_date_only), add = TRUE)
  expect_identical(hash_of(from_date_only), pinned)

  # The same bars through the file surface, which reads them back as
  # ISO-Z strings.
  csv_path <- tempfile(fileext = ".csv")
  on.exit(unlink(csv_path), add = TRUE)
  utils::write.csv(test_bars, csv_path, row.names = FALSE)
  from_csv <- ledgr_snapshot_from_csv(csv_path)
  on.exit(ledgr_snapshot_close(from_csv), add = TRUE)
  expect_identical(hash_of(from_csv), pinned)
})
