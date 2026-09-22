# ledgr-test-file-profile: review
#
# LDG-2800. The registered compatibility matrix for the ingestion CSV reader.
#
# Every row records what the reader and the file surface actually do for one
# input shape. It exists so that LDG-2801's reader substitution has to declare
# each behaviour it moves instead of inheriting it. A row that changes must be
# listed with a reason in the cut 5 closeout; an unlisted change fails here.
#
# Recorded at c0a2a32 with utils::read.csv(), re-recorded after the swap.

csvc_file <- function(lines, bom = FALSE) {
  path <- tempfile(fileext = ".csv")
  if (isTRUE(bom) && length(lines) > 0L) {
    lines[[1]] <- paste0("﻿", lines[[1]])
  }
  writeLines(lines, path, useBytes = TRUE)
  path
}

csvc_header <- "instrument_id,ts_utc,open,high,low,close,volume"

# What the reader returns: column names and storage classes, or the condition
# class it raises.
csvc_read_shape <- function(lines, bom = FALSE, path = NULL) {
  p <- if (is.null(path)) csvc_file(lines, bom = bom) else path
  tryCatch(
    {
      d <- ledgr:::ledgr_read_csv_strict(p, encoding = "UTF-8", strict = TRUE)
      list(
        ok = TRUE,
        names = names(d),
        classes = unname(vapply(d, function(x) class(x)[[1L]], character(1))),
        first_id = if ("instrument_id" %in% names(d) && nrow(d) > 0L) {
          as.character(d$instrument_id)[[1L]]
        } else NA_character_
      )
    },
    error = function(e) list(ok = FALSE, class = class(e)[[1L]])
  )
}

# What the public file surface does with the same shape.
csvc_seal_outcome <- function(lines, bom = FALSE, path = NULL) {
  p <- if (is.null(path)) csvc_file(lines, bom = bom) else path
  tryCatch(
    {
      snap <- ledgr_snapshot_from_csv(p)
      on.exit(ledgr_snapshot_close(snap), add = TRUE)
      con <- ledgr_db_init(snap$db_path)
      on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
      ids <- DBI::dbGetQuery(
        con,
        "SELECT DISTINCT instrument_id FROM snapshot_bars WHERE snapshot_id = ? ORDER BY 1",
        params = list(snap$snapshot_id)
      )$instrument_id
      list(ok = TRUE, n_bars = snap$metadata$n_bars, ids = ids,
           start = snap$metadata$start_date)
    },
    error = function(e) {
      list(ok = FALSE, class = class(e)[[1L]],
           msg = substr(conditionMessage(e), 1, 40))
    }
  )
}

test_that("the reader's column and class contract is what the matrix records", {
  chr <- "character"
  num <- "numeric"

  shape <- csvc_read_shape(c(csvc_header, "AAA,2020-01-01T00:00:00Z,1.5,2.5,0.5,1.5,10.5"))
  expect_true(shape$ok)
  expect_identical(shape$names, c("instrument_id", "ts_utc", "open", "high", "low", "close", "volume"))
  expect_identical(shape$classes, c(chr, chr, num, num, num, num, num))

  no_volume <- csvc_read_shape(c(
    "instrument_id,ts_utc,open,high,low,close", "AAA,2020-01-01T00:00:00Z,1.5,2.5,0.5,1.5"
  ))
  expect_identical(no_volume$names, c("instrument_id", "ts_utc", "open", "high", "low", "close"))

  extra <- csvc_read_shape(c(paste0(csvc_header, ",junk"), "AAA,2020-01-01T00:00:00Z,1.5,2.5,0.5,1.5,10.5,hello"))
  expect_true("junk" %in% extra$names)

  quoted <- csvc_read_shape(c(csvc_header, "\"A,B\",2020-01-01T00:00:00Z,1.5,2.5,0.5,1.5,10.5"))
  expect_identical(quoted$first_id, "A,B")

  bom <- csvc_read_shape(c(csvc_header, "AAA,2020-01-01T00:00:00Z,1.5,2.5,0.5,1.5,10.5"), bom = TRUE)
  expect_identical(bom$names[[1L]], "instrument_id")

  # A malformed numeric leaves the column as text; ledgr rejects it later.
  malformed <- csvc_read_shape(c(csvc_header, "AAA,2020-01-01T00:00:00Z,abc,2.5,0.5,1.5,10.5"))
  expect_identical(malformed$classes[[3L]], chr)

  missing_path <- csvc_read_shape(NULL, path = file.path(tempdir(), "no-such-ledgr-file.csv"))
  expect_false(missing_path$ok)
  expect_identical(missing_path$class, "ledgr_invalid_args")
})

test_that("whole-number price columns reach ledgr as numeric, not integer", {
  # LDG-2788 added a coercion for this on the from_csv path because R's CSV
  # reader infers integer columns for whole-number prices, and a quarantined
  # row records the supplied row verbatim. The matrix records the contract,
  # whichever layer provides it.
  csv <- csvc_file(c(csvc_header, "AAA,2020-01-01T00:00:00Z,100,100,100,100,10"))
  bars <- ledgr:::ledgr_csv_read_bars_for_snapshot(csv)
  expect_identical(
    unname(vapply(bars[c("open", "high", "low", "close", "volume")],
                  function(x) class(x)[[1L]], character(1))),
    rep("numeric", 5L)
  )
})

test_that("every accepted timestamp form seals through the file surface", {
  iso_z <- csvc_seal_outcome(c(
    csvc_header,
    "AAA,2020-01-01T00:00:00Z,1,1,1,1,10",
    "AAA,2020-01-02T00:00:00Z,1,1,1,1,10"
  ))
  expect_true(iso_z$ok)
  expect_identical(iso_z$start, "2020-01-01T00:00:00Z")

  date_only <- csvc_seal_outcome(c(
    csvc_header, "AAA,2020-01-01,1,1,1,1,10", "AAA,2020-01-02,1,1,1,1,10"
  ))
  expect_true(date_only$ok)
  expect_identical(date_only$start, "2020-01-01T00:00:00Z")

  no_z <- csvc_seal_outcome(c(
    csvc_header,
    "AAA,2020-01-01T00:00:00,1,1,1,1,10",
    "AAA,2020-01-02T00:00:00,1,1,1,1,10"
  ))
  expect_true(no_z$ok)
  expect_identical(no_z$start, "2020-01-01T00:00:00Z")

  mixed <- csvc_seal_outcome(c(
    csvc_header,
    "AAA,2020-01-01,1,1,1,1,10",
    "AAA,2020-01-02T00:00:00Z,1,1,1,1,10"
  ))
  expect_true(mixed$ok)
  expect_identical(mixed$start, "2020-01-01T00:00:00Z")
})

test_that("malformed files fail through the file surface with a ledgr class", {
  cases <- list(
    missing_required = c("instrument_id,ts_utc,open,high,low", "AAA,2020-01-01T00:00:00Z,1,1,1"),
    no_instrument_id = c("ts_utc,open,high,low,close", "2020-01-01T00:00:00Z,1,1,1,1"),
    no_ts_utc = c("instrument_id,open,high,low,close", "AAA,1,1,1,1"),
    malformed_numeric = c(csvc_header, "AAA,2020-01-01T00:00:00Z,abc,1,1,1,10"),
    header_only = csvc_header,
    empty_file = character(0)
  )
  for (nm in names(cases)) {
    out <- csvc_seal_outcome(cases[[nm]])
    expect_false(out$ok, info = nm)
    expect_true(
      out$class %in% c("ledgr_invalid_args", "LEDGR_SNAPSHOT_EMPTY"),
      info = paste(nm, "->", out$class)
    )
  }
})

test_that("a ragged row fails through the file surface", {
  out <- csvc_seal_outcome(c(csvc_header, "AAA,2020-01-01T00:00:00Z,1"))
  expect_false(out$ok)
  expect_identical(out$class, "ledgr_invalid_args")
})

# The one matrix row LDG-2801 moved, and the reason the swap was worth making
# on correctness grounds alone. utils::read.csv() inferred an integer column
# for all-numeric instrument ids, so "0001" was read as 1 and as.character()
# sealed it as "1", silently, over a snapshot_bars column the schema types
# TEXT. DuckDB reads the identity columns as VARCHAR, so the ids survive.
# Snapshots sealed from such a file before LDG-2801 carry wrong instrument ids
# and a hash computed from them.
test_that("leading-zero instrument ids survive to the sealed snapshot", {
  out <- csvc_seal_outcome(c(
    csvc_header,
    "0001,2020-01-01T00:00:00Z,1,1,1,1,10",
    "0001,2020-01-02T00:00:00Z,1,1,1,1,10",
    "0002,2020-01-01T00:00:00Z,2,2,2,2,10",
    "0002,2020-01-02T00:00:00Z,2,2,2,2,10"
  ))
  expect_true(out$ok)
  expect_identical(out$ids, c("0001", "0002"))
})
