# Slice-3 probe: the pin's diagnostic rows of one dumped workload, selected days.
args <- commandArgs(TRUE)
t <- readRDS(args[[1L]])
d <- t$run$run_diagnostics
days <- strsplit(args[[2L]], ",")[[1L]]
d <- d[substr(d$ts_utc, 1L, 10L) %in% days, ]
cols <- intersect(c("diagnostic_seq", "ts_utc", "instrument_id", "stage", "outcome", "reason_code", "reasons", "target",
  "quantity", "price", "mark_source", "mark_age", "position_before", "detail_json"), names(d))
d$detail_json <- substr(d$detail_json, 1L, 60L)
print(d[order(as.integer(d$diagnostic_seq)), cols], row.names = FALSE, right = FALSE)
