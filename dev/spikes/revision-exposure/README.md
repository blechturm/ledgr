# Revision-exposure investigation: preserved evidence

Preserved under synthesis v11 section 7, which makes retention of this report, its
scripts and its evidence CSVs an owned ticket-cut obligation, together with their
source and workload provenance. This file supplies that provenance so the numbers
in the synthesis can be traced without access to the machine that produced them.

**Not a spike.** No charter, no fork, no candidate implementation. These are
read-only queries, which is what the commissioning brief asked for. They are
deliberately outside `spike_checker.R`'s reproducible set, because they read data
that does not travel with the repository.

## What produced which number

| Script | Evidence | Question |
| --- | --- | --- |
| `fact_clock_census.R` | `fact_clock_evidence.csv` | can any built fact become knowable after a session it affects? |
| `declared_absence_census.R` | `declared_absence_evidence.csv` | absent expected sessions against a declared calendar and declared lifetimes, by lifecycle location |
| `source_change_attribution.R` | `source_change_attribution_evidence.csv` | added, removed and changed source rows between two captures, and their traced consequence |
| `no_trade_identifiability.R` | `no_trade_identifiability_evidence.csv` | is a no-trade session identifiable from shipped fields, and how concentrated is it? |
| `pit_liquidity_filter.R` | `pit_liquidity_evidence.csv` | the same exposure under a liquidity filter known at the decision |
| `fdmlq_and_fills.R` | `fdmlq_and_fills_evidence.csv` | the attributed correction's downstream reach, and realised fills |

`revision_exposure_report.md` is the narrative, including the withdrawn claims and
the corrections that produced them.

## Source provenance

**Not in this repository.** Both live on one machine and neither travels with it.

- **Raw vendor lake:** `C:/Users/maxth/ledgr-data/sharadar/parquet`, Sharadar
  SEP/ACTIONS/TICKERS/SF1/SP500 as Hive-partitioned parquet by `acquisition_id`.
  Acquisitions used: **`20260905T092008Z`** throughout, with
  **`20260904T164505Z`** as the older capture in the source comparison. Both are
  full-table dumps of the same scope, 17 hours apart. Price window
  **2020-01-01 to 2024-12-31** unless a script states otherwise.
- **Built ledgr snapshots:** `C:/Users/maxth/ledgr-data/sharadar/ledgr-baselines`,
  14 sealed DuckDB snapshots from the v0.1.1 baseline work. Ten carry 562
  instruments and 413,532 bars over 2019-01-02 to 2021-12-31; four are controls
  with 5 instruments and 100 bars over 2019-04-03 to 2019-05-01. Eight carry
  persisted `FILL` events, 10,486 in total.
- **Adapter:** `ledgr-research/packages/ledgr.sharadar`, read at source for the
  clock-assignment claims rather than inferred from a governance record.

## Workload provenance

The measurements describe US equities from one vendor, and the built snapshots
trade large permatickers. They do not bound other asset classes, other vendors,
illiquid strategies, or field-level gaps. The zeros describe what this adapter
constructs, not when the market first knew anything.

## Re-running

Each script is standalone and needs `DBI`, `duckdb` and the paths above. Rerunning
against a new acquisition is the exposure assessment synthesis v11 section 9 asks
for when a source with genuine knowledge clocks or missing sessions appears; it is
not approval to build optimization machinery.
