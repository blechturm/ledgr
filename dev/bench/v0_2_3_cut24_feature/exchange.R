# Cut 24 decision 3 (cut review 24, R1): the decision statistics of protocol
# cut24-feature-1.
#
# --aa: from a base A/A attempt (raw.csv of dev/bench/timing), for every cell
#   compute all 2^8 = 256 within-pair label exchanges of the eight pairs (each
#   pair's two observations swap arms or not) of the shared checker's
#   statistic median(candidate) / median(base), and write the central 95%
#   interval [L, U] (quantile type 7) to intervals.csv, with every exchange
#   value to exchanges.csv. U is the frozen no-regression bound
#   (thresholds.csv); L is the saving test.
# --intervals=<csv>: for a comparison attempt, the per-cell verdict: ratio < L
#   "saving", ratio > U "regression", otherwise "no_saving_established";
#   written to verdicts.csv. Only rows with outcome ok and a finite positive
#   time count; a cell without exactly eight valid pairs is "invalid".
#
#   Rscript exchange.R --record=<attempt dir> --out=<dir> --aa
#   Rscript exchange.R --record=<attempt dir> --out=<dir> --intervals=<intervals.csv>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) {
    hit <- grep(paste0("^--", name, "(=|$)"), argv, value = TRUE)
    if (!length(hit)) return(NULL)
    if (!grepl("=", hit[[1L]], fixed = TRUE)) return(TRUE)
    sub(paste0("^--", name, "="), "", hit[[1L]])
  }
  raw <- utils::read.csv(file.path(arg("record"), "raw.csv"), colClasses = "character", na.strings = "NA")
  raw$secs <- suppressWarnings(as.numeric(raw$seconds))
  raw <- raw[raw$outcome == "ok" & is.finite(raw$secs) & raw$secs > 0, ]
  out <- arg("out")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  # One row per pair: base and candidate seconds.
  pairs_of <- function(cell) {
    x <- raw[raw$cell == cell, ]
    b <- x[x$arm == "base", c("pair", "secs")]
    k <- x[x$arm == "candidate", c("pair", "secs")]
    m <- merge(b, k, by = "pair", suffixes = c("_base", "_candidate"))
    m[order(as.integer(m$pair)), ]
  }
  cells <- unique(raw$cell)
  stat <- function(base, cand) stats::median(cand) / stats::median(base)
  if (isTRUE(arg("aa"))) {
    rows <- list(); ex <- list()
    for (cell in cells) {
      p <- pairs_of(cell)
      if (nrow(p) != 8L) stop("cell ", cell, " has ", nrow(p), " valid pairs, not 8")
      swaps <- as.matrix(expand.grid(rep(list(c(FALSE, TRUE)), 8L)))
      values <- apply(swaps, 1L, function(s) {
        base <- ifelse(s, p$secs_candidate, p$secs_base)
        cand <- ifelse(s, p$secs_base, p$secs_candidate)
        stat(base, cand)
      })
      q <- stats::quantile(values, c(0.025, 0.975), type = 7, names = FALSE)
      rows[[cell]] <- data.frame(cell = cell, observed_ratio = stat(p$secs_base, p$secs_candidate),
                                 L = q[[1L]], U = q[[2L]], median_base_s = stats::median(p$secs_base),
                                 stringsAsFactors = FALSE)
      ex[[cell]] <- data.frame(cell = cell, exchange = seq_along(values), ratio = values)
    }
    intervals <- do.call(rbind, rows)
    utils::write.csv(intervals, file.path(out, "intervals.csv"), row.names = FALSE)
    utils::write.csv(do.call(rbind, ex), file.path(out, "exchanges.csv"), row.names = FALSE)
    print(intervals, row.names = FALSE, digits = 6)
  } else {
    iv <- utils::read.csv(arg("intervals"), stringsAsFactors = FALSE)
    rows <- list()
    for (cell in iv$cell) {
      p <- pairs_of(cell)
      j <- iv$cell == cell
      if (nrow(p) != 8L) {
        rows[[cell]] <- data.frame(cell = cell, ratio = NA_real_, L = iv$L[j], U = iv$U[j], verdict = "invalid")
        next
      }
      r <- stat(p$secs_base, p$secs_candidate)
      verdict <- if (r < iv$L[j]) "saving" else if (r > iv$U[j]) "regression" else "no_saving_established"
      rows[[cell]] <- data.frame(cell = cell, ratio = r, L = iv$L[j], U = iv$U[j], verdict = verdict)
    }
    verdicts <- do.call(rbind, rows)
    utils::write.csv(verdicts, file.path(out, "verdicts.csv"), row.names = FALSE)
    print(verdicts, row.names = FALSE, digits = 6)
  }
})
