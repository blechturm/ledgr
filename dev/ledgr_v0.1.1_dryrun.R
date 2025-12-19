# ledgr v0.1.1 — minimal “action” demo (adapted to your ledgr_db_init signature)

suppressPackageStartupMessages({
  library(DBI)
  library(duckdb)
  #library(ledgr)
})

devtools::load_all()

iso_utc <- function(x) {
  if (inherits(x, "Date")) x <- as.POSIXct(x, tz = "UTC")
  format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

write_tmp <- function(lines, prefix) {
  f <- tempfile(pattern = prefix, fileext = ".csv")
  writeLines(lines, f, useBytes = TRUE)
  f
}

cat_section <- function(title) cat("\n", "==== ", title, " ====\n", sep = "")

# 0) Fresh DB path (use a unique file to avoid Windows lock pain)
db_path <- tempfile(pattern = "ledgr_demo_v0_1_1_", fileext = ".duckdb")

cat_section("Init ledgr DB (db_path)")
# Your ledgr_db_init() expects a *path*, not a connection
ledgr_db_init(db_path)

# Open connection after init
con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

# 1) Create snapshot
cat_section("Create snapshot")
snap_id <- ledgr_snapshot_create(
  con,
  snapshot_id = NULL,
  meta = list(purpose = "v0.1.1 demo", source = "synthetic CSV")
)
cat("snapshot_id:", snap_id, "\n")

# 2) Create CSVs
instruments_csv <- write_tmp(
  c(
    "instrument_id,symbol,currency,asset_class,multiplier,tick_size,meta_json",
    "AAA,AAA,USD,EQUITY,1,0.01,\"{}\"",
    "BBB,BBB,USD,EQUITY,1,0.01,\"{}\""
  ),
  "ledgr_instruments_"
)

dates <- as.Date("2020-01-01") + 0:5
bars_lines <- c("instrument_id,ts_utc,open,high,low,close,volume")
for (i in seq_along(dates)) {
  d <- iso_utc(dates[i])
  aaa <- 100 + i
  bbb <- 200 - i
  bars_lines <- c(
    bars_lines,
    sprintf("AAA,%s,%.9f,%.9f,%.9f,%.9f,%d", d, aaa, aaa + 0.5, aaa - 0.5, aaa + 0.2, 1000 + i),
    sprintf("BBB,%s,%.9f,%.9f,%.9f,%.9f,%d", d, bbb, bbb + 0.5, bbb - 0.5, bbb - 0.2, 2000 + i)
  )
}
bars_csv <- write_tmp(bars_lines, "ledgr_bars_")

cat_section("Import instruments + bars")
#ledgr_snapshot_import_instruments_csv(con, snap_id, instruments_csv)

ledgr_snapshot_import_bars_csv(
  con,
  snapshot_id = snap_id,
  bars_csv_path = bars_csv,
  instruments_csv_path = instruments_csv,
  auto_generate_instruments = FALSE,
  validate = "fail_fast"
)

# 3) Seal snapshot
cat_section("Seal snapshot")
ledgr_snapshot_seal(con, snap_id)

# 4) Inspect snapshot
cat_section("Snapshot list + info")
print(ledgr_snapshot_list(con))
print(ledgr_snapshot_info(con, snap_id))

# 5) Backtest from snapshot
cat_section("Run backtest from SEALED snapshot")
config <- list(
  db_path = db_path,
  engine = list(seed = 42L, tz = "UTC"),
  data = list(source = "snapshot", snapshot_id = snap_id),
  universe = list(instrument_ids = c("AAA", "BBB")),
  backtest = list(
    start_ts_utc = iso_utc(min(dates)),
    end_ts_utc = iso_utc(max(dates)),
    pulse = "EOD",
    initial_cash = 100000
  ),
  fill_model = list(type = "next_open", spread_bps = 0, commission_fixed = 0),
  strategy = list(id = "hold_zero"),
features = list(
    enabled = TRUE,
    defs = list(
      list(id = "return_1"),       # Type is identified by id
      list(id = "sma_3")          # Shorthand for SMA with n=3
      # Alternatively: list(id = "sma_n", params = list(n = 3))
    )
  )
)

run_res <- ledgr_backtest_run(config)

cat_section("Backtest return value (str)")
str(run_res)

# Most likely patterns:
# 1) returns run_id as a string
# 2) returns list(run_id=..., status=..., warnings=..., ...)
run_id <- if (is.character(run_res) && length(run_res) == 1L) {
  run_res
} else if (is.list(run_res) && !is.null(run_res$run_id)) {
  run_res$run_id
} else {
  stop("Unexpected ledgr_backtest_run() return type; inspect str(run_res).")
}

cat("run_id:", run_id, "\n")


# 6) Query outputs
cat_section("equity_curve")
print(DBI::dbGetQuery(con, "
  SELECT ts_utc, cash, positions_value, equity
  FROM equity_curve
  WHERE run_id = ?
  ORDER BY ts_utc", params = list(run_id)
))

cat_section("features (sample)")
print(DBI::dbGetQuery(con, "
  SELECT instrument_id, ts_utc, feature_name, feature_value
  FROM features
  WHERE run_id = ?
  ORDER BY instrument_id, ts_utc, feature_name
  LIMIT 50", params = list(run_id)
))

cat_section("Done")
cat("DB:", db_path, "\n")


# What did the runner actually store?
DBI::dbGetQuery(con, "SELECT run_id, config_json FROM runs WHERE run_id = ?", params = list(run_id))
