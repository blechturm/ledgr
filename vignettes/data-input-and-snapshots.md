# Importing And Sealing Market Data


You have market data in memory or in a file. This article takes the
shortest path from that data to a sealed ledgr snapshot you can inspect
and reopen. Point-in-time facts are a separate concern; add them only
when your research question needs them.

By the end, you will have sealed a small bar panel, inspected its public
metadata, seen the equivalent CSV and Yahoo entry points, and made one
explicit decision about malformed observations.

> [!NOTE]
>
> ### Running this yourself
>
> The runnable examples use temporary DuckDB files. In real work, choose a
> project path such as `artifacts/ledgr_store.duckdb`.


``` r
library(ledgr)
library(dplyr)
data("ledgr_demo_bars", package = "ledgr")
```

## The Required Bar Shape

Bars are the only required input. Each row identifies one physical
instrument at one UTC observation time and supplies open, high, low, and
close. Volume is optional.

``` r
bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    between(ts_utc, ledgr_utc("2019-01-01"), ledgr_utc("2019-01-31"))
  )

bars |>
  select(instrument_id, ts_utc, open, high, low, close, volume) |>
  slice_head(n = 4)
```

    # A tibble: 4 x 7
      instrument_id ts_utc               open  high   low close volume
      <chr>         <dttm>              <dbl> <dbl> <dbl> <dbl>  <dbl>
    1 DEMO_01       2019-01-01 00:00:00  89.7  91.8  89.7  91.5 468600
    2 DEMO_01       2019-01-02 00:00:00  91.5  91.6  91.0  91.3 438315
    3 DEMO_01       2019-01-03 00:00:00  91.3  92.1  89.6  90.5 576390
    4 DEMO_01       2019-01-04 00:00:00  90.7  91.1  89.5  89.8 458921

The `(instrument_id, ts_utc)` pair must be unique. Timestamps are
whole-second UTC instants. If your source uses local exchange times,
normalize them before calling ledgr rather than leaving the timezone
implicit.

## Seal A Snapshot

`ledgr_snapshot_from_df()` validates, stores, and seals the data in one
call.

``` r
db_path <- ledgr_temp_store(file.path(tempdir(), "ledgr_import_demo.duckdb"))

snapshot <- ledgr_snapshot_from_df(
  bars,
  db_path = db_path,
  snapshot_id = "import_demo"
)
```

The returned handle is already sealed. Inspect the stable public fields
rather than the raw metadata envelope.

``` r
ledgr_snapshot_info(snapshot) |>
  select(
    status,
    snapshot_hash,
    bar_count,
    instrument_count,
    start_date,
    end_date
  )
```

    # A tibble: 1 x 6
      status snapshot_hash                      bar_count instrument_count start_date end_date
      <chr>  <chr>                                  <int>            <int> <chr>      <chr>
    1 SEALED 4f1bf4da9712ff45a0a7d8dae496b2851~        46                2 2019-01-0~ 2019-01~

Sealing gives you validated bar keys, an immutable snapshot hash, and a
stable physical instrument master. It does not invent missing sessions,
infer historical universe membership, or repair prices.

If the source evidence changes, create a new snapshot. Do not append
bars to a sealed snapshot or reseal different data under the same
identity.

## Choose The Smallest Honest Input Set

Most users should start with bars and add facts only when the question
requires them.

| Research shape | Minimum sealed inputs | Read next |
|----|----|----|
| Dense static panel | Bars | Continue below |
| Described physical panel | Bars plus instruments | Constructor help |
| Session-aware gaps | Bars plus sessions | Point-in-time inputs |
| Point-in-time universe | Bars, sessions, membership | Point-in-time inputs |
| Trading or lifetime restrictions | Bars, sessions, status or lifetime | Point-in-time inputs |
| Equity economic events | Bars, instruments, corporate actions | Point-in-time inputs |

Use `vignette("point-in-time-inputs", package = "ledgr")` when bars
alone cannot say what existed, what was eligible, or what was known.
That article owns the complete data dictionary and entity diagram.

## Start From A CSV Instead

`ledgr_snapshot_from_csv()` has the same snapshot contract as the
data-frame form. It requires `instrument_id`, `ts_utc`, `open`, `high`,
`low`, and `close`; `volume` is optional.

``` r
snapshot <- ledgr_snapshot_from_csv(
  "data/daily_bars.csv",
  db_path = "artifacts/ledgr_store.duckdb",
  snapshot_id = "eod_2019_h1"
)
```

Supply a separate instrument file when you have stable metadata. It
needs an `instrument_id`; `symbol`, `currency`, `asset_class`,
`multiplier`, and `tick_size` are optional.

``` r
snapshot <- ledgr_snapshot_from_csv(
  "data/daily_bars.csv",
  instruments_csv_path = "data/instruments.csv",
  db_path = "artifacts/ledgr_store.duckdb",
  snapshot_id = "eod_2019_h1"
)
```

## Or Fetch Yahoo Data

The Yahoo adapter downloads bars through `quantmod` and seals the
result.

``` r
snapshot <- ledgr_snapshot_from_yahoo(
  symbols = c("SPY", "QQQ"),
  from = "2019-01-01",
  to = "2019-06-30",
  db_path = "artifacts/ledgr_store.duckdb",
  snapshot_id = "yahoo_2019_h1"
)
```

> [!WARNING]
>
> ### Yahoo is a convenience source
>
> Yahoo and the remote endpoint are outside ledgr’s reproducibility
> boundary. The adapter seals the OHLCV values returned by `quantmod`; it
> does not rebuild adjusted OHLC bars from adjusted close. Prepare and
> seal your own panel when the research requires a different adjustment
> policy.


## Refuse Or Quarantine A Bad Observation

A malformed bar is not a missing bar. ledgr refuses it by default rather
than guess what it meant. This row has a high below its open.

``` r
session_dates <- as.Date("2019-01-01") + 0:4
invalid_bars <- tibble(
  instrument_id = "DEMO_01",
  ts_utc = session_dates,
  open = 100:104,
  high = 101:105,
  low = 99:103,
  close = 100:104,
  volume = 1000
)
invalid_bars$high[[3]] <- invalid_bars$open[[3]] - 5
```

Quarantine is meaningful only when an independent calendar says the
observation was expected. Otherwise a dropped row is indistinguishable
from a date that never existed.

``` r
session_facts <- ledgr_facts_sessions(
  tibble(
    session_date = session_dates,
    status = "open",
    session_open = "14:30:00",
    session_close = "21:00:00",
    knowledge_time = ledgr_utc("2018-12-01")
  ),
  venue_id = "DEMO_VENUE",
  timezone = "UTC"
)

strict <- tryCatch(
  ledgr_snapshot_from_df(
    invalid_bars,
    instruments_df = tibble(instrument_id = "DEMO_01"),
    facts = ledgr_facts(session_facts),
    db_path = ledgr_temp_store(file.path(tempdir(), "ledgr_strict.duckdb"))
  ),
  error = identity
)

conditionMessage(strict)
```

    [1] "Availability input cannot be sealed: ohlc_invalid."

Nothing was sealed. If you have decided that the source row should
remain in the audit record but must not reach runtime, ask for
quarantine explicitly.

``` r
quarantined <- ledgr_snapshot_from_df(
  invalid_bars,
  instruments_df = tibble(instrument_id = "DEMO_01"),
  facts = ledgr_facts(session_facts),
  db_path = ledgr_temp_store(file.path(tempdir(), "ledgr_quarantine.duckdb")),
  invalid_observations = "quarantine"
)

ledgr_snapshot_info(quarantined)$bar_count
```

    [1] 4

Four of five observations reached runtime. The invalid source row
remains bound into the snapshot evidence; quarantine is not deletion or
repair.

## Reopen The Same Artifact

Record the path and snapshot id, close the live handle, and reopen with
hash verification in a later session.

``` r
snapshot_id <- snapshot$snapshot_id
ledgr_snapshot_close(snapshot)

snapshot <- ledgr_snapshot_open(
  db_path,
  snapshot_id = snapshot_id,
  verify = TRUE
)

ledgr_snapshot_info(snapshot) |>
  select(status, snapshot_hash, bar_count)
```

    # A tibble: 1 x 3
      status snapshot_hash                                                    bar_count
      <chr>  <chr>                                                                <int>
    1 SEALED 4f1bf4da9712ff45a0a7d8dae496b285181e96ec2435aaccb6ba5a3a0090fc94        46

For backup, recovery, live handles, and stored runs, continue with
`vignette("experiment-store", package = "ledgr")`.

## Cleanup

``` r
ledgr_snapshot_close(quarantined)
ledgr_snapshot_close(snapshot)
```

## Where Next

- `vignette("point-in-time-inputs", package = "ledgr")` adds sessions,
  membership, trading status, lifetime, and economic events.
- `vignette("strategy-development", package = "ledgr")` uses a sealed
  snapshot in a complete backtest.
- `vignette("experiment-store", package = "ledgr")` covers stored runs,
  handles, backup, and recovery.
