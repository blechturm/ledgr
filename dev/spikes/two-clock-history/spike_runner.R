# Two-clock history spike runner.
#
# Rscript dev/spikes/two-clock-history/spike_runner.R <ledgr_repo> <out_dir> [--gut]
#
# Charter: inst/design/spikes/two_clock_history_spike/charter.md. Builds the
# bitemporal segments of spike_core.R for eight case shapes and answers
# (s, t) queries; writes cases.csv and shape.csv. `--gut` answers every query
# with the shipped diagonal provider instead. Binds nothing; changes no
# package file.
args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
out_dir <- args[[2L]]
gut <- "--gut" %in% args
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
source(file.path(script_dir, "spike_core.R"))

day <- function(d, h = 0) as.POSIXct(as.Date("2020-01-01") + d - 1L, tz = "UTC") + h * 3600
noon <- function(d) spike_seconds(day(d, 12))
ids <- c("AAA", "BBB")
status <- function(...) ledgr_facts_trading_status(data.frame(..., source = "spike", stringsAsFactors = FALSE))

cases <- list(
  list(id = 1L, name = "retracted halt", plane = "status", key = "AAA",
       facts = ledgr_facts(status(instrument_id = "AAA", effective_from = day(3), effective_to = day(6),
                                  knowledge_time = c(day(3), day(8)), status = c("halted", "active"),
                                  precedence = 1L, fact_id = c("halt", "retract"),
                                  supersedes_fact_id = c(NA, "halt"))),
       queries = list(c(4, 5), c(4, 8), c(5, 9))),
  # Supersession must stay within one source, and a three-status chain from one
  # source is refused because its first and third facts conflict (recorded
  # below). The expressible chain reverts: halted, corrected to active,
  # corrected back to halted.
  list(id = 2L, name = "supersession chain", plane = "status", key = "AAA",
       facts = ledgr_facts(status(instrument_id = "AAA", effective_from = day(3), effective_to = day(6),
                                  knowledge_time = c(day(3), day(5), day(8)),
                                  status = c("halted", "active", "halted"), precedence = 1L,
                                  fact_id = c("f1", "f2", "f3"), supersedes_fact_id = c(NA, "f1", "f2"))),
       queries = list(c(4, 4), c(4, 6), c(4, 9))),
  list(id = 3L, name = "precedence tie", plane = "status", key = "AAA",
       facts = ledgr_facts(ledgr_facts_trading_status(data.frame(
         instrument_id = "AAA", effective_from = day(3), effective_to = day(6),
         knowledge_time = c(day(3), day(6)), status = c("halted", "active"),
         source = c("vendor_a", "vendor_b"), precedence = 1L, fact_id = c("a", "b")))),
       queries = list(c(4, 4), c(4, 7))),
  list(id = 4L, name = "membership snapshot correction", plane = "membership", key = "u",
       facts = ledgr_facts(local({
         df <- data.frame(effective_from = day(1), knowledge_time = c(day(1) - 1, day(7)),
                          set_id = c("orig", "corr"), source = "spike")
         df$members <- I(list(c("AAA", "BBB"), "AAA"))
         ledgr_facts_membership_snapshots(df, universe_id = "u", complete = TRUE)
       })),
       queries = list(c(3, 5), c(3, 8))),
  list(id = 5L, name = "late-known membership interval", plane = "membership", key = "v",
       facts = ledgr_facts(ledgr_facts_membership_intervals(data.frame(
         instrument_id = c("AAA", "BBB"), effective_from = c(day(1), day(2)),
         knowledge_time = c(day(1) - 1, day(6)), member = TRUE, source = "spike"), universe_id = "v")),
       queries = list(c(3, 4), c(3, 7))),
  list(id = 6L, name = "incomplete snapshot completed", plane = "membership", key = "w",
       facts = ledgr_facts(local({
         df <- data.frame(effective_from = day(1), knowledge_time = c(day(1) - 1, day(6)),
                          set_id = c("partial", "full"), source = "spike")
         df$members <- I(list("AAA", "AAA"))
         ledgr_facts_membership_snapshots(df, universe_id = "w", complete = c(FALSE, TRUE))
       })),
       queries = list(c(3, 4), c(3, 7))),
  list(id = 7L, name = "late-known lifetime", plane = "lifetime", key = "BBB",
       facts = ledgr_facts(ledgr_facts_lifetime(data.frame(
         instrument_id = "BBB", effective_from = day(4), knowledge_time = day(9),
         assertion = "known_inactive", fact_id = "bbb-inactive"))),
       queries = list(c(5, 6), c(5, 9)))
)

rows <- list()
shape <- list()
same_source_chain <- tryCatch({
  status(instrument_id = "AAA", effective_from = day(3), effective_to = day(6),
         knowledge_time = c(day(3), day(5), day(8)), status = c("halted", "active", "quotation_only"),
         precedence = 1L, fact_id = c("f1", "f2", "f3"), supersedes_fact_id = c(NA, "f1", "f2"))
  "accepted"
}, error = function(e) paste("refused:", class(e)[[1L]]))
rows[[1L]] <- data.frame(case = 2L, shape = "one-source supersession chain (constructor)", plane = "status",
  key = "AAA", s_day = NA_integer_, t_day = NA_integer_, answer = same_source_chain,
  diagonal_at_s = "public constructor", stringsAsFactors = FALSE)
for (case in cases) {
  data <- ledgr:::ledgr_facts_inspection_data(case$facts)
  shipped <- spike_provider(data, ids)
  segments <- spike_build(data, case$plane, case$key, ids)
  answer <- function(s, t) {
    if (gut) return(as.character(spike_state(shipped, data, case$plane, case$key, ids, s)))
    spike_query(segments, s, t)
  }
  diagonal <- function(s) as.character(spike_state(shipped, data, case$plane, case$key, ids, s))
  for (q in case$queries) {
    s <- noon(q[[1L]]); t <- noon(q[[2L]])
    rows[[length(rows) + 1L]] <- data.frame(case = case$id, shape = case$name, plane = case$plane,
      key = case$key, s_day = q[[1L]], t_day = q[[2L]], answer = answer(s, t), diagonal_at_s = diagonal(s),
      stringsAsFactors = FALSE)
  }
  # Case 8: the diagonal (d, d) must equal the shipped provider for every day.
  diag_ok <- vapply(1:10, function(d) identical(answer(noon(d), noon(d)), diagonal(noon(d))), logical(1))
  rows[[length(rows) + 1L]] <- data.frame(case = 8L, shape = paste("diagonal of", case$name), plane = case$plane,
    key = case$key, s_day = NA_integer_, t_day = NA_integer_, answer = paste(sum(diag_ok), "of 10 days equal"),
    diagonal_at_s = "shipped provider", stringsAsFactors = FALSE)
  fact_rows <- sum(vapply(c("status", "lifetime", "membership"), function(tab) {
    df <- data[[tab]]; if (is.data.frame(df)) nrow(df) else 0L
  }, integer(1)))
  spike_lookups$n <- 0L
  invisible(lapply(seq(9, 5), function(d) spike_query(segments, noon(d), noon(10))))
  shape[[length(shape) + 1L]] <- data.frame(case = case$id, plane = case$plane, fact_rows = fact_rows,
    epochs = length(spike_epochs(data)), segments_written = nrow(segments),
    bound_twice_fact_rows = nrow(segments) <= 2L * fact_rows,
    lookups_per_window_read_k5 = spike_lookups$n, stringsAsFactors = FALSE)
}
cases_out <- do.call(rbind, rows)
shape_out <- do.call(rbind, shape)
cases_out$mode <- if (gut) "gut_diagonal" else "bitemporal"
utils::write.csv(cases_out, file.path(out_dir, "cases.csv"), row.names = FALSE)
utils::write.csv(shape_out, file.path(out_dir, "shape.csv"), row.names = FALSE)
print(cases_out[, c("case", "plane", "s_day", "t_day", "answer", "diagonal_at_s")], row.names = FALSE, right = FALSE)
print(shape_out, row.names = FALSE)
