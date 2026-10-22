# Differential: candidate lineage and status conflict validation against the
# BASE implementations on randomized correction forests.
# Rscript diff_lineage.R <candidate tree> <base tree> <n_sets>
args <- commandArgs(trailingOnly = TRUE)
suppressMessages(pkgload::load_all(args[[1L]], quiet = TRUE, compile = FALSE, export_all = TRUE))
ns <- asNamespace("ledgr")
base_env <- new.env(parent = ns)
sys.source(file.path(args[[2L]], "R", "availability-facts.R"), envir = base_env)
n_sets <- as.integer(args[[3L]])
set.seed(20261021)
at <- function(day) as.POSIXct("2020-01-01", tz = "UTC") + day * 86400
capture <- function(f, rows) {
  tryCatch({ f(rows); "ok" }, error = function(e) paste(class(e)[[1L]], conditionMessage(e)))
}
random_rows <- function() {
  n <- sample.int(14L, 1L)
  ids <- sprintf("f%02d", seq_len(n))
  parent <- rep(NA_character_, n)
  for (i in seq_len(n)) {
    if (i > 1L && runif(1) < 0.5) parent[[i]] <- ids[[sample.int(i - 1L, 1L)]]
  }
  if (n > 1L && runif(1) < 0.08) parent[[1L]] <- ids[[n]]  # occasional cycle
  if (runif(1) < 0.05) parent[[sample.int(n, 1L)]] <- "missing"
  from <- sample(0:10, n, replace = TRUE)
  len <- sample(1:6, n, replace = TRUE)
  to <- at(from + len)
  to[runif(n) < 0.2] <- as.POSIXct(NA, tz = "UTC")
  data.frame(
    fact_id = ids,
    instrument_id = sample(c("AAA", "BBB"), n, replace = TRUE, prob = c(0.8, 0.2)),
    source = sample(c("venue", "vendor"), n, replace = TRUE, prob = c(0.85, 0.15)),
    precedence = sample(c(1L, 2L), n, replace = TRUE, prob = c(0.85, 0.15)),
    status = sample(c("active", "halted", "quotation_only"), n, replace = TRUE),
    effective_from = at(from),
    effective_to = to,
    knowledge_time = at(from),
    supersedes_fact_id = parent,
    stringsAsFactors = FALSE
  )
}
lineage_mismatch <- 0L
conflict_mismatch <- 0L
outcomes <- table(character())
for (k in seq_len(n_sets)) {
  rows <- random_rows()
  rows <- rows[sample.int(nrow(rows)), , drop = FALSE]
  a <- tryCatch(base_env$ledgr_status_lineage(rows), error = function(e) class(e)[[1L]])
  b <- tryCatch(ns$ledgr_status_lineage(rows), error = function(e) class(e)[[1L]])
  if (!identical(a, b)) lineage_mismatch <- lineage_mismatch + 1L
  ca <- capture(base_env$ledgr_fact_validate_source_conflicts, rows)
  cb <- capture(ns$ledgr_fact_validate_source_conflicts, rows)
  if (!identical(ca, cb)) {
    conflict_mismatch <- conflict_mismatch + 1L
    if (conflict_mismatch <= 3L) { print(rows); cat(ca, "\n", cb, "\n") }
  }
  outcomes <- table(c(rep(names(outcomes), outcomes), substr(cb, 1L, 40L)))
}
print(outcomes)
cat(sprintf("SETS=%d LINEAGE_MISMATCH=%d CONFLICT_MISMATCH=%d\n", n_sets, lineage_mismatch, conflict_mismatch))
