# Cut 25 measuring step: ledgr_utc() character parsing.
#
# Times the character branch on 1, 500 and 5,000 strings and writes the
# frozen per-element results the vectorised rewrite must reproduce
# (tests/testthat/fixtures/ledgr-utc-oracle.csv). Run on the base commit:
#
#   Rscript dev/bench/v0_2_3_cut25_chores/utc_probe.R --source=<tree> --out=<dir> [--write-fixture=<csv>]
local({
  argv <- commandArgs(TRUE)
  arg <- function(name, default = NULL) {
    hit <- grep(paste0("^--", name, "="), argv, value = TRUE)
    if (length(hit) == 0L) return(default)
    sub(paste0("^--", name, "="), "", hit[[1L]])
  }
  source_tree <- arg("source")
  out <- arg("out")
  fixture <- arg("write-fixture")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  pkgload::load_all(source_tree, quiet = TRUE, export_all = FALSE)
  commit <- system2("git", c("-C", source_tree, "rev-parse", "HEAD"), stdout = TRUE)

  # The fixed input population: 500 accepted strings over the four accepted
  # forms, then edge cases (each also checked alone).
  set.seed(20261126L)
  days <- sample(seq(as.Date("1900-01-01"), as.Date("2099-12-31"), by = "day"), 500L, replace = TRUE)
  secs <- sample.int(86400L, 500L, replace = TRUE) - 1L
  hms <- sprintf("%02d:%02d:%02d", secs %/% 3600L, (secs %/% 60L) %% 60L, secs %% 60L)
  form <- rep_len(1:4, 500L)
  d <- format(days, "%Y-%m-%d")
  valid500 <- ifelse(form == 1L, d,
              ifelse(form == 2L, paste0(d, "T", hms),
              ifelse(form == 3L, paste0(d, "T", hms, "Z"), paste(d, hms))))
  edges <- c(
    "0000-01-01", "0001-01-01", "9999-12-31", "1970-01-01", "1969-12-31T23:59:59Z",
    "2000-02-29", "2100-02-28", "2020-02-29T12:00:00", "1999-12-31 23:59:59",
    "2020-01-01T00:00:00Z", "2020-12-31T23:59:59",
    # refusals
    "2021-02-29", "2020-02-30", "2020-13-01", "2020-00-10", "2020-01-32",
    "2020-01-01T24:00:00", "2020-01-01T23:60:00", "2020-01-01T23:59:60Z",
    "2020-01-01 24:00:00", "2020-02-30T00:00:00Z", "2020-1-01", "20200101",
    "2020-01-01T00:00", "2020-01-01T00:00:00+01:00", "2020-01-01T00:00:00.5Z",
    "2020-01-01  00:00:00", " 2020-01-01", "2020-01-01 ", "2020-01-01t00:00:00",
    "2020-01-01T00:00:00z", "abcd-ef-gh"
  )
  one <- function(v) {
    r <- tryCatch(ledgr_utc(v), error = identity)
    if (inherits(r, "error")) {
      data.frame(input = v, seconds = NA_real_, class = class(r)[[1L]], message = conditionMessage(r))
    } else {
      data.frame(input = v, seconds = as.numeric(r), class = "", message = "")
    }
  }
  oracle <- do.call(rbind, lapply(c(valid500, edges), one))
  oracle$set <- c(rep("valid500", 500L), rep("edge", length(edges)))
  whole <- ledgr_utc(valid500)
  stopifnot(identical(as.numeric(whole), oracle$seconds[oracle$set == "valid500"]),
            identical(attr(whole, "tzone"), "UTC"))
  if (!is.null(fixture)) {
    utils::write.csv(oracle, fixture, row.names = FALSE, fileEncoding = "UTF-8")
  }

  # Timing: medians of repeated blocks, elapsed seconds per call.
  time_call <- function(x, reps) {
    blocks <- vapply(1:7, function(b) {
      t0 <- proc.time()[["elapsed"]]
      for (r in seq_len(reps)) ledgr_utc(x)
      (proc.time()[["elapsed"]] - t0) / reps
    }, numeric(1))
    stats::median(blocks)
  }
  x5000 <- rep(valid500, 10L)
  base <- function(x) as.POSIXct(x, tz = "UTC", format = "%Y-%m-%dT%H:%M:%S")
  t5000 <- paste0(rep(d, 10L), "T", rep(hms, 10L))
  base_t <- stats::median(vapply(1:7, function(b) {
    t0 <- proc.time()[["elapsed"]]
    for (r in 1:20) base(t5000)
    (proc.time()[["elapsed"]] - t0) / 20
  }, numeric(1)))
  timing <- data.frame(
    commit = commit,
    case = c("n1", "n500", "n5000", "as_posixct_n5000"),
    seconds_per_call = c(time_call(valid500[[3L]], 2000L), time_call(valid500, 10L),
                         time_call(x5000, 1L), base_t)
  )
  utils::write.csv(timing, file.path(out, "utc_timing.csv"), row.names = FALSE)
  print(timing)
  cat("oracle rows:", nrow(oracle), "refusals:", sum(nzchar(oracle$class)), "\n")
})
