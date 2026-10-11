# Off-session ingest clock (Cut 12 LDG-3011).
#
#   Rscript offsession_ingest.R <repo> <label> <out_csv>
#
# A New York calendar with every bar stamped 21:00Z, which is off-session
# through daylight time: 200 instruments over one year (52,200 bars, about
# 34,000 off-session). Two inputs: finite extra values, and an Inf in an extra
# column on every row (the exceptional-value path of the record serializer).
# One fresh process per call; appends label, case, bars, off-session count and
# ingest seconds to <out_csv>.
args <- commandArgs(trailingOnly = TRUE)
pkgload::load_all(args[[1L]], quiet = TRUE, compile = FALSE)
label <- args[[2L]]
out <- args[[3L]]
days <- seq(as.Date("2021-01-04"), by = "day", length.out = 365)
days <- days[as.integer(format(days, "%u")) <= 5L]
ids <- sprintf("I%03d", 1:200)
bars <- data.frame(
  instrument_id = rep(ids, each = length(days)),
  ts_utc = rep(as.POSIXct(paste(days, "21:00:00"), tz = "UTC"), length(ids)),
  open = 10, high = 10, low = 10, close = 10, volume = 1
)
calendar <- seq(min(days), max(days), by = "day")
open <- calendar %in% days
facts <- ledgr_facts(ledgr_facts_sessions(
  data.frame(session_date = calendar, status = ifelse(open, "open", "closed"),
             session_open = ifelse(open, "09:30:00", NA), session_close = ifelse(open, "16:00:00", NA)),
  venue_id = "XNYS", timezone = "America/New_York", knowledge = "assume_effective"
))
rows <- list()
for (case in c("finite_extra", "inf_extra")) {
  input <- bars
  input$vendor_score <- if (identical(case, "inf_extra")) Inf else 1
  gc()
  t0 <- proc.time()[["elapsed"]]
  s <- ledgr_snapshot_from_df(input, db_path = tempfile(fileext = ".duckdb"), facts = facts, price_basis = "split_adjusted")
  elapsed <- proc.time()[["elapsed"]] - t0
  off <- ledgr_snapshot_info(s)$off_session_bar_count
  ledgr_snapshot_close(s)
  rows[[case]] <- data.frame(label = label, case = case, bars = nrow(input),
                             off_session = if (is.null(off)) NA_integer_ else off, ingest_s = round(elapsed, 3))
}
res <- do.call(rbind, rows)
utils::write.table(res, out, sep = ",", row.names = FALSE, append = file.exists(out), col.names = !file.exists(out))
print(res, row.names = FALSE)
