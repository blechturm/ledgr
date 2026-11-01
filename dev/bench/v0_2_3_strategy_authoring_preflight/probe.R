.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all(".", quiet = TRUE)

cat("CUT7_PRE_ACCEPTANCE_PROBE\n")
cat("product_source=14252ffb;governance_only_head=558d7eea\n")

# 1. Existing canonical JSON is not a declared-state codec.
values <- list(
  numeric = c(B = NA_real_, A = 1.5),
  integer = c(B = NA_integer_, A = 1L),
  logical = c(B = NA, A = TRUE),
  character = c(B = NA_character_, A = "x"),
  whole_double = c(B = 1, A = 2)
)
for (name in names(values)) {
  result <- tryCatch({
    json <- ledgr:::canonical_json(list(x = values[[name]]))
    decoded <- ledgr:::ledgr_json_read_nested(json)$x
    paste0(
      "ok;decoded_type=", typeof(decoded),
      ";decoded_names=", paste(names(decoded), collapse = "|"),
      ";missing_is_null=", is.null(decoded$B)
    )
  }, error = function(error) {
    paste0("error;class=", class(error)[[1L]], ";message=", conditionMessage(error))
  })
  cat("ROUNDTRIP\t", name, "\t", result, "\n", sep = "")
}

# 2. Resume uses MAX(strategy_state.ts_utc), so sparse state rows lose the
# completed-pulse cursor even when state itself is unchanged.
path <- tempfile(fileext = ".duckdb")
drv <- duckdb::duckdb()
con <- DBI::dbConnect(drv, dbdir = path)
on.exit({
  DBI::dbDisconnect(con, shutdown = TRUE)
  duckdb::duckdb_shutdown(drv)
  unlink(path)
}, add = TRUE)
ledgr_create_schema(con)

dates <- as.POSIXct("2020-01-01", tz = "UTC") + 0:4 * 86400
calendar <- list(
  pulses = as.list(dates),
  pulses_posix = dates,
  pulses_iso = format(dates, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
)
handler <- list(abort_run = function(message) stop(message, call. = FALSE))
resume_case <- function(run_id, completed) {
  DBI::dbExecute(
    con,
    "DELETE FROM strategy_state WHERE run_id = ?",
    params = list(run_id)
  )
  rows <- data.frame(
    run_id = rep(run_id, length(completed)),
    ts_utc = calendar$pulses_iso[completed],
    state_json = rep("{}", length(completed)),
    stringsAsFactors = FALSE
  )
  if (nrow(rows)) DBI::dbAppendTable(con, "strategy_state", rows)
  ledgr:::ledgr_run_resume(
    con = con,
    output_handler = handler,
    run_id = run_id,
    is_resume = TRUE,
    calendar = calendar,
    start_ts_utc = calendar$pulses_iso[[1L]],
    opening_positions = numeric(),
    opening_cost_basis = numeric()
  )
}
full_three <- resume_case("full-three", 1:3)
sparse_three <- resume_case("sparse-three", 1L)
full_final <- resume_case("full-final", 1:5)
sparse_final <- resume_case("sparse-final", 1L)
cat(
  "RESUME\tfull_three_start_idx=", full_three$start_idx,
  ";sparse_three_start_idx=", sparse_three$start_idx,
  ";full_finalization_only=", full_final$finalization_only_resume,
  ";sparse_finalization_only=", sparse_final$finalization_only_resume,
  "\n",
  sep = ""
)

# 3. Count current public-run work on a five-pulse, unchanged-state strategy.
bars <- data.frame(
  instrument_id = rep("AAA", 5L),
  ts_utc = dates,
  open = 100:104,
  high = 100:104,
  low = 100:104,
  close = 100:104,
  volume = rep(1, 5L),
  stringsAsFactors = FALSE
)
run_path <- tempfile(fileext = ".duckdb")
snapshot <- ledgr_snapshot_from_df(bars, db_path = run_path)
on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
experiment <- ledgr_experiment(
  snapshot = snapshot,
  strategy = function(ctx, params) ctx$flat(),
  opening = ledgr_opening(cash = 1000),
  cost_model = ledgr_cost_zero()
)
counts <- new.env(parent = emptyenv())
counts$context <- 0L
counts$state_encode <- 0L
original_context <- ledgr:::ledgr_update_pulse_context_helpers
original_json <- ledgr:::canonical_json
local({
  testthat::local_mocked_bindings(
    ledgr_update_pulse_context_helpers = function(...) {
      counts$context <- counts$context + 1L
      original_context(...)
    },
    canonical_json = function(x) {
      in_commit <- any(vapply(
        seq_len(sys.nframe()),
        function(i) identical(sys.function(i), ledgr:::ledgr_fold_stage_commit),
        logical(1)
      ))
      if (in_commit) counts$state_encode <- counts$state_encode + 1L
      original_json(x)
    },
    .package = "ledgr"
  )
  run <- ledgr_run(experiment, run_id = "cut7-call-counts")
  on.exit(close(run), add = TRUE)
})
opened <- ledgr:::ledgr_run_store_open(run_path)
on.exit(ledgr:::ledgr_run_store_close(opened), add = TRUE)
state_rows <- DBI::dbGetQuery(
  opened$con,
  "SELECT COUNT(*) AS n FROM strategy_state WHERE run_id = 'cut7-call-counts'"
)$n[[1L]]
cat(
  "CALLS\tpulses=5;context_builds=", counts$context,
  ";state_encodes=", counts$state_encode,
  ";strategy_state_rows=", state_rows,
  "\n",
  sep = ""
)
