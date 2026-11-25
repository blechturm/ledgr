# Cut 24 (synthesis rule 7, cut review R5; LDG-3258): the calculated-count
# observation. ledgr_history_compute_feature_series() hands its
# calculated_count matrix (definitions x instruments: calculated, not carried,
# cells) to the sampled causality check; a wrong count can leave values,
# planes and even the probe's instrument choice unchanged. This script
# records the matrix at that seam (the namespace binding of
# ledgr_history_feature_causality(), wrapped for the run; no product counter)
# for fixed preparations: admitted (a dense substrate), fallback (the hostile
# corpus), mixed (the panels), short and empty histories, output carry, the
# default and a later calculation start, over a definition set with TTR and
# built-in rows of both input-carry families and history classes and one
# custom definition. --write-expected freezes the base general path's
# matrices (counts_expected.csv); otherwise they are compared exactly.
# --fault=count adds one to every positive count before the seam, keeping
# which.max and the sampled positions: the check must fail.
#
#   Rscript counts.R --lib=<library> --out=<dir> [--write-expected] [--fault=count]
local({
  argv <- commandArgs(TRUE)
  arg <- function(name, default = NULL) {
    hit <- grep(paste0("^--", name, "(=|$)"), argv, value = TRUE)
    if (!length(hit)) return(default)
    if (!grepl("=", hit[[1L]], fixed = TRUE)) return(TRUE)
    sub(paste0("^--", name, "="), "", hit[[1L]])
  }
  suppressPackageStartupMessages(library(ledgr, lib.loc = normalizePath(arg("lib"), winslash = "/")))
  ns <- asNamespace("ledgr")
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  source(file.path(here, "corpus.R"), local = TRUE)
  out <- arg("out")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  fault <- arg("fault", "none")

  seen <- new.env()
  seen$m <- NULL
  orig <- get("ledgr_history_feature_causality", envir = ns)
  unlockBinding("ledgr_history_feature_causality", ns)
  assign("ledgr_history_feature_causality", function(substrate, certified, bounds, calculated_count, values) {
    if (identical(fault, "count")) calculated_count[calculated_count > 0L] <- calculated_count[calculated_count > 0L] + 1L
    seen$m <- calculated_count
    orig(substrate, certified, bounds, calculated_count, values)
  }, envir = ns)
  lockBinding("ledgr_history_feature_causality", ns)

  dense <- local({
    sim <- ledgr::ledgr_sim_bars(4L, 60L, seed = 20261125L, start = "2020-01-01", instrument_prefix = "D")
    sim <- sim[order(sim$instrument_id, sim$ts_utc, method = "radix"), ]
    sim$ts_utc <- sim$ts_utc + 21 * 3600
    axis <- sort(unique(sim$ts_utc))
    fx_plain_substrate(sim, sort(unique(sim$instrument_id)), axis, "counts-dense", ledgr::ledgr_history_policy())
  })
  substrates <- c(list(dense = dense), fx_substrates())
  defs <- list(
    fx_ttr("SMA", input = "close", n = 3L, id = "ttr_sma_3"),
    fx_def(ledgr::ledgr_ind_sma(3)),
    fx_def(ledgr::ledgr_ind_ema(3)),
    fx_def(ledgr::ledgr_ind_returns(1)),
    fx_ttr("RSI", input = "close", n = 3L, id = "ttr_rsi_3"),
    fx_ttr("ATR", input = "hlc", output = "atr", n = 3L, id = "ttr_atr_3"),
    fx_def(ledgr::ledgr_indicator("custom_last", fn = function(w) as.numeric(utils::tail(w$close, 1L)),
                                  requires_bars = 2L, required_fields = "close")))
  names(defs) <- vapply(defs, function(d) d$id, "")
  rows <- list()
  for (k in names(substrates)) {
    sub <- substrates[[k]]
    n <- length(sub$axis)
    starts <- list(default = ns$ledgr_history_calculation_start(sub))
    if (n >= 4L) starts$later <- sub$axis[[max(2L, n %/% 2L)]]
    for (s in names(starts)) {
      seen$m <- NULL
      res <- tryCatch({
        ns$ledgr_history_compute_feature_series(sub, defs, calculation_start = starts[[s]])
        "ok"
      }, error = function(e) class(e)[[1L]])
      m <- seen$m
      if (is.null(m)) {
        rows[[length(rows) + 1L]] <- data.frame(case = k, start = s, outcome = res, definition = NA_character_,
          instrument = NA_character_, count = NA_integer_, stringsAsFactors = FALSE)
        next
      }
      rows[[length(rows) + 1L]] <- data.frame(case = k, start = s, outcome = res,
        definition = rep(names(defs), times = ncol(m)), instrument = rep(sub$instrument_ids, each = nrow(m)),
        count = as.integer(m), stringsAsFactors = FALSE)
    }
  }
  got <- do.call(rbind, rows)
  utils::write.csv(got, file.path(out, "counts.csv"), row.names = FALSE)
  expected_file <- file.path(here, "counts_expected.csv")
  if (isTRUE(arg("write-expected"))) {
    utils::write.csv(got, expected_file, row.names = FALSE)
    cat("counts written:", nrow(got), "rows,", sum(got$count > 0, na.rm = TRUE), "positive cells\n")
    return(invisible())
  }
  want <- utils::read.csv(expected_file, stringsAsFactors = FALSE)
  key <- function(x) paste(x$case, x$start, x$outcome, x$definition, x$instrument, sep = "|")
  ok <- identical(sort(key(want)), sort(key(got))) &&
    identical(want$count[order(key(want))], got$count[order(key(got))])
  cat(sprintf("calculated-count cells: expected %d, observed %d, positive %d\n", nrow(want), nrow(got),
              sum(got$count > 0, na.rm = TRUE)))
  if (!ok) {
    m <- merge(want, got, by = c("case", "start", "outcome", "definition", "instrument"), all = TRUE,
               suffixes = c("_expected", "_observed"))
    d <- m[!(m$count_expected %in% m$count_observed & m$count_expected == m$count_observed) |
             is.na(m$count_expected) != is.na(m$count_observed), ]
    print(utils::head(d, 10L), row.names = FALSE)
    cat("COUNTS CHECK FAIL\n")
    quit(save = "no", status = 1L)
  }
  cat("COUNTS CHECK PASS\n")
})
