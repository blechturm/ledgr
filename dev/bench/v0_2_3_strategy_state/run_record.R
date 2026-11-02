args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args) >= 1L) args[[1L]] else tempfile("ws17-state-")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all(".", quiet = TRUE)

n_pulses <- 500L
bars <- data.frame(
  instrument_id = "AAA",
  ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * (0:(n_pulses - 1L)),
  open = 100, high = 100, low = 100, close = 100, volume = 1000
)
snapshot <- ledgr_snapshot_from_df(bars)
on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

cases <- list(
  no_state = list(
    declaration = list(),
    strategy = function(ctx, params) ctx$hold()
  ),
  declared_unchanged = list(
    declaration = list(count = 0L),
    strategy = function(ctx, params) ctx$hold()
  ),
  raw_identical = list(
    declaration = list(count = 0L),
    strategy = function(ctx, params) {
      list(targets = ctx$hold(), state_update = list(count = 0L))
    }
  ),
  changed_every_pulse = list(
    declaration = list(count = 0L),
    strategy = function(ctx, params) {
      ledgr_strategy_result(ctx$hold(), count = ctx$state$count + 1L)
    }
  )
)

records <- lapply(seq_along(cases), function(i) {
  name <- names(cases)[[i]]
  case <- cases[[i]]
  experiment <- ledgr_experiment(
    snapshot, case$strategy,
    opening = ledgr_opening(cash = 1000),
    cost_model = ledgr_cost_zero(),
    portfolio_state = case$declaration
  )
  run_id <- paste0("ws17-state-", i)
  elapsed <- system.time({
    run <- ledgr_run(experiment, run_id = run_id)
  })[["elapsed"]]
  on.exit(close(run), add = TRUE)
  rows <- DBI::dbGetQuery(
    get_connection(snapshot),
    "SELECT state_json FROM strategy_state WHERE run_id = ?",
    params = list(run_id)
  )
  payload <- rows$state_json != ledgr:::ledgr_strategy_state_cursor_marker
  data.frame(
    case = name,
    pulses = n_pulses,
    cursor_rows = nrow(rows),
    payload_encodes = sum(payload),
    payload_bytes = sum(nchar(rows$state_json[payload], type = "bytes")),
    marker_bytes = sum(nchar(rows$state_json[!payload], type = "bytes")),
    elapsed_seconds = elapsed,
    stringsAsFactors = FALSE
  )
})

record <- do.call(rbind, records)
stopifnot(
  all(record$cursor_rows == n_pulses),
  all(record$payload_encodes[record$case != "changed_every_pulse"] == 0L),
  record$payload_encodes[record$case == "changed_every_pulse"] == n_pulses
)
utils::write.csv(record, file.path(out_dir, "record.csv"), row.names = FALSE)

meta <- data.frame(
  key = c("source_base", "source_state", "R", "platform", "pulses",
    "strategy_state_rule_version"),
  value = c(
    "d566de6e",
    "WS17 candidate working tree before implementation commit",
    R.version.string,
    R.version$platform,
    as.character(n_pulses),
    as.character(ledgr:::ledgr_strategy_state_rule_version)
  )
)
utils::write.csv(meta, file.path(out_dir, "meta.csv"), row.names = FALSE)
print(record)
