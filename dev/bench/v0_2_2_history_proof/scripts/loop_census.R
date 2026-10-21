# Loop census for the LDG-3069 seven-shape walk: every R-level iteration
# construct inside functions that Cut 16 added or changed in the history
# preparation, fold, transport and reader files. Output: one row per loop with
# the function, the construct and the iterated expression.
args <- commandArgs(trailingOnly = TRUE)
repo <- args[[1L]]
base <- args[[2L]]
out <- args[[3L]]
files <- c("R/history-substrate.R", "R/history-frame.R", "R/history-features.R",
           "R/history-treatment.R", "R/indicator-history.R", "R/availability-facts.R",
           "R/availability-provider-prepared.R", "R/availability-provider.R",
           "R/backtest-runner.R", "R/sweep.R", "R/parallel-workers.R", "R/fold-engine.R",
           "R/walk-forward.R", "R/precompute-features.R", "R/pulse-snapshot.R",
           "R/features-engine.R", "R/runtime-projection.R", "R/history-policy.R")
changed_lines <- function(file) {
  d <- system2("git", c("-C", repo, "diff", "-U0", base, "HEAD", "--", file), stdout = TRUE)
  h <- grep("^@@", d, value = TRUE)
  m <- regmatches(h, regexec("\\+([0-9]+)(,([0-9]+))?", h))
  unlist(lapply(m, function(x) {
    start <- as.integer(x[[2L]]); n <- if (nzchar(x[[4L]])) as.integer(x[[4L]]) else 1L
    if (n == 0L) integer() else seq(start, length.out = n)
  }))
}
loop_fns <- c("for", "while", "repeat", "lapply", "vapply", "sapply", "Map", "mapply",
              "Reduce", "Filter", "do.call")
rows <- list()
for (file in files) {
  path <- file.path(repo, file)
  if (!file.exists(path)) next
  exprs <- parse(path, keep.source = TRUE)
  pd <- utils::getParseData(exprs)
  changed <- changed_lines(file)
  for (i in seq_along(exprs)) {
    e <- exprs[[i]]
    if (!is.call(e) || !identical(e[[1L]], as.name("<-")) || !is.call(e[[3L]]) ||
        !identical(e[[3L]][[1L]], as.name("function"))) next
    sr <- attr(exprs, "srcref")[[i]]
    lines <- sr[[1L]]:sr[[3L]]
    if (!any(lines %in% changed)) next
    fn <- as.character(e[[2L]])
    sub <- pd[pd$line1 >= sr[[1L]] & pd$line2 <= sr[[3L]], , drop = FALSE]
    hits <- sub[(sub$token %in% c("FOR", "WHILE", "REPEAT")) |
                  (sub$token == "SYMBOL_FUNCTION_CALL" & sub$text %in% loop_fns), , drop = FALSE]
    src <- readLines(path, warn = FALSE)
    for (j in seq_len(nrow(hits))) {
      rows[[length(rows) + 1L]] <- data.frame(
        file = file, fn = fn, line = hits$line1[[j]],
        construct = tolower(hits$text[[j]]),
        changed_line = hits$line1[[j]] %in% changed,
        source = trimws(substr(src[[hits$line1[[j]]]], 1L, 160L)),
        stringsAsFactors = FALSE)
    }
  }
}
res <- do.call(rbind, rows)
utils::write.csv(res, out, row.names = FALSE)
cat(nrow(res), "loops in", length(unique(paste(res$file, res$fn))), "functions\n")
