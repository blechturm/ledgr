args <- commandArgs(trailingOnly = TRUE)
package_root <- if (length(args) >= 1L) args[[1L]] else "."
output <- if (length(args) >= 2L) args[[2L]] else tempfile(fileext = ".csv")
n <- if (length(args) >= 3L) as.integer(args[[3L]]) else 20000L
repetitions <- if (length(args) >= 4L) as.integer(args[[4L]]) else 3L

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all(package_root, quiet = TRUE)

dates <- as.Date("2020-01-02") + rep(0:5, length.out = n)
sessions <- ledgr_facts_sessions(
  data.frame(
    session_date = as.Date("2020-01-02") + 0:5,
    status = "open",
    session_open = "09:30:00",
    session_close = "16:00:00",
    knowledge_time = as.POSIXct("2019-12-31", tz = "UTC")
  ),
  venue_id = "XNYS",
  timezone = "America/New_York"
)
session_index <- match(dates, sessions$rows$session_date)
membership <- function(clock) {
  ledgr_facts_membership_intervals(
    data.frame(
      instrument_id = sprintf("I%06d", seq_len(n)),
      effective_from = clock,
      knowledge_time = clock,
      member = TRUE,
      source = "fixture"
    ),
    universe_id = "research"
  )
}
families <- list(
  posix = membership(sessions$rows$session_open[session_index]),
  civil = membership(dates)
)

rows <- lapply(names(families), function(variant) {
  elapsed <- numeric(repetitions)
  for (i in seq_len(repetitions)) {
    gc()
    elapsed[[i]] <- unname(system.time(
      bundle <- ledgr_facts(sessions, families[[variant]])
    )[["elapsed"]])
    stopifnot(inherits(bundle, "ledgr_facts"))
  }
  data.frame(
    variant = variant,
    rows = n,
    repetition = seq_len(repetitions),
    elapsed_seconds = elapsed
  )
})

dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
write.csv(do.call(rbind, rows), output, row.names = FALSE)
