# Data Input And Snapshots


This article focuses on bringing data into ledgr and sealing it into a
snapshot. Runs, labels, reopening, and recovery evidence live in
`vignette("experiment-store", package = "ledgr")`.

<div class="ledgr-callout ledgr-callout-note">

**Running this yourself**

This article is evaluated when rendered. It writes to temporary DuckDB
stores so package builds and local previews do not leave project
artifacts behind. In real work, use a project-local path such as
`artifacts/ledgr_store.duckdb`.

</div>

<div class="ledgr-callout ledgr-callout-warning">

**Pre-CRAN compatibility**

ledgr is pre-CRAN. Store schemas, config hashes, provenance formats, and
experimental APIs may change before the first CRAN release. Treat stores
created with pre-CRAN ledgr as research artifacts for the version that
produced them, and expect to rerun experiments after upgrading.

</div>

The examples use `dplyr` for data preparation and compact display. It is
a suggested package used by the vignettes, not part of the
experiment-store contract.

``` r
library(ledgr)
library(dplyr)
data("ledgr_demo_bars", package = "ledgr")
```

## Snapshot Lifecycle And Data Input

Market data and derived data have different lifecycle rules in ledgr. A
sealed snapshot freezes the real market-data input and its hash. If you
need more instruments, more dates, corrected bars, or tick-derived bars,
create a new snapshot. Indicators, runs, labels, tags, comparisons, and
telemetry are derived from sealed market data and can be added later
without mutating the snapshot.

Snapshot lifecycle anti-patterns:

- appending bars to a sealed snapshot in place;
- resealing different data under the same snapshot ID;
- deleting snapshots that stored runs still reference;
- mixing live ticks into a backtest snapshot;
- filling data gaps with undocumented synthetic corrections.

If the evidence changes, create a new snapshot. That is what makes later
comparison meaningful.

This vignette uses `ledgr_temp_store()` so it can run without writing
into your project directory. For real research, use
`artifacts/ledgr_store.duckdb` and a snapshot ID you will recognize
later.

``` r
db_path <- ledgr_temp_store(file.path(tempdir(), "ledgr_store_demo.duckdb"))

bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    between(
      ts_utc,
      ledgr_utc("2019-01-01"),
      ledgr_utc("2019-06-30")
    )
  )

snapshot <- ledgr_snapshot_from_df(
  bars,
  db_path = db_path,
  snapshot_id = "store_demo_snapshot"
)
```

After snapshot creation, store operations take `snapshot`, not
`db_path`. In a new R session, recover the handle with
`ledgr_snapshot_open(db_path, snapshot_id)`.

If your market data starts in CSV, seal the CSV into the same kind of
durable store. The CSV must contain `instrument_id`, `ts_utc`, `open`,
`high`, `low`, and `close`; `volume` is optional. ledgr imports only
those canonical bar columns. Other CSV columns are ignored and do not
become part of the sealed snapshot or its hash.

``` r
snapshot <- ledgr_snapshot_from_csv(
  "data/daily_bars.csv",
  db_path = "artifacts/ledgr_store.duckdb",
  snapshot_id = "eod_2019_h1"
)
```

In any later session, recover the handle without re-sealing the data:

``` r
snapshot <- ledgr_snapshot_open(
  "artifacts/ledgr_store.duckdb",
  snapshot_id = "eod_2019_h1"
)
```

CSV and local data validation happens while the snapshot is created and
sealed, before a strategy can run. Missing columns, unparseable
timestamps, duplicate `instrument_id`/`ts_utc` rows, and OHLC violations
are snapshot import problems. They are not strategy execution errors.

Yahoo imports follow the same lifecycle, but the adapter downloads bars
before sealing the snapshot:

``` r
snapshot <- ledgr_snapshot_from_yahoo(
  symbols = c("SPY", "QQQ"),
  from = "2019-01-01",
  to = "2019-06-30",
  db_path = "artifacts/ledgr_store.duckdb",
  snapshot_id = "yahoo_2019_h1"
)
```

The returned handle is already sealed. Calling
`ledgr_snapshot_seal(snapshot)` again is an idempotent verification
step: on a snapshot handle it returns an invisible structured list with
`$hash` and `$snapshot`; on a low-level DBI connection plus
`snapshot_id` it returns the hash string. Use
`ledgr_snapshot_info(snapshot)` to inspect `status`, `snapshot_hash`,
`bar_count`, `instrument_count`, `start_date`, `end_date`, and raw
`meta_json`. The dates are ISO UTC values. `meta_json` is envelope
metadata; snapshot identity comes from normalized bars and instruments,
not from human descriptions.

<div class="ledgr-callout ledgr-callout-warning">

**Yahoo data boundary**

Yahoo support is a convenience adapter, not a data-vendor guarantee. It
uses `quantmod::getSymbols()` and therefore requires the suggested
`quantmod` package and network access. Package startup or S3
method-overwrite messages printed while quantmod loads are not ledgr
snapshot warnings. The adapter seals the Yahoo `.Open`, `.High`, `.Low`,
`.Close`, and `.Volume` columns as returned by quantmod; it does not
rewrite OHLC values from Yahoo’s adjusted-close column. If your research
requires split/dividend-adjusted OHLC bars, prepare those bars
explicitly and seal them with `ledgr_snapshot_from_df()` or
`ledgr_snapshot_from_csv()`.

</div>

``` r
yahoo_info <- ledgr_snapshot_info(snapshot)
yahoo_seal <- ledgr_snapshot_seal(snapshot)
yahoo_hash <- yahoo_seal$hash
stopifnot(identical(yahoo_info$snapshot_hash[[1]], yahoo_hash))
```

Snapshot metadata uses these public field names:

| Field | Meaning |
|----|----|
| `status` | snapshot lifecycle state, usually `SEALED` after helper creation |
| `snapshot_hash` | hash of normalized bars and instruments |
| `bar_count` | current count of rows in `snapshot_bars` |
| `instrument_count` | current count of rows in `snapshot_instruments` |
| `start_date`, `end_date` | seal-time date range parsed from metadata |
| `meta_json` | raw JSON envelope containing user metadata plus seal metadata |

Seal metadata inside `meta_json` may use internal names such as `n_bars`
and `n_instruments`. The structured columns from `ledgr_snapshot_info()`
are `bar_count` and `instrument_count`; use those names in programmatic
code.

## Backup Conventions

The store is an ordinary DuckDB file. Back it up when no ledgr process
has it open.

<div class="ledgr-callout ledgr-callout-warning">

**Back up closed stores**

Close run and snapshot handles, then copy or sync the closed store file.
A simple project pattern is:

``` r
dir.create("backups", showWarnings = FALSE)
file.copy(
  "artifacts/ledgr_store.duckdb",
  file.path("backups", paste0("ledgr_store_", Sys.Date(), ".duckdb")),
  overwrite = TRUE
)
```

For larger projects, use the same closed-file rule with your normal
backup or sync tool. Do not rely on the phrase “ordinary backup
discipline” without a specific copy/sync pattern for the store file.

</div>

## Cleanup

``` r
ledgr_snapshot_close(snapshot)
```

## Where Next

- `vignette("experiment-store", package = "ledgr")` shows how sealed
  snapshots are used by committed runs and recovery workflows.
- `vignette("research-workflow", package = "ledgr")` puts snapshots in
  the larger research project workflow.
- `vignette("strategy-development", package = "ledgr")` uses a sealed
  snapshot in a complete backtest.
