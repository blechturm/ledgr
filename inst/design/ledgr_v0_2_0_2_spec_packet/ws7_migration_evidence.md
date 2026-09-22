# Workstream 7 Migration Evidence (LDG-2786, LDG-2787)

**Scope:** the 27 calls to `ledgr_snapshot_import_bars_csv()` and
`ledgr_snapshot_import_instruments_csv()` across eight test files, migrated to
the kept ingestion surface before LDG-2787 deletes the old one.

## 1. Census

| | total | fast | review | heavy |
| --- | ---: | ---: | ---: | ---: |
| before (cut 1 close) | 850 | 445 | 215 | 190 |
| after LDG-2788 and LDG-2786 | 850 | 443 | 217 | 190 |

Four blocks deleted, four added. The two added by LDG-2788 are `review`; the
two added here are `fast`; all four deleted were `fast`. No registry entry in
`tests/claims.yml`, `tests/heavy-protocols.yml` or `tests/test-gates.yml`
names any of the affected files, so no registry edit was required.

`tests/testthat/test-snapshots-import-csv.R` is renamed to
`test-snapshot-from-csv.R`: it now holds the `ledgr_snapshot_from_csv()`
contract and its old name referred to a function that no longer exists.

## 2. Deleted blocks, with the contract each held

| block | file | contract | why it has no kept-surface equivalent |
| --- | --- | --- | --- |
| `AT6: Immutability guard (SEALED snapshot rejects writes)` | test-acceptance-v0.1.1.R | importing into a `SEALED` snapshot raises `LEDGR_SNAPSHOT_NOT_MUTABLE` | **Removed contract.** The CREATED-then-import-then-seal lifecycle is removed with the importer. `from_df` and `from_csv` always create and seal one snapshot in a single call, so no public caller can reach a mutable snapshot. |
| `attempted import after sealing is rejected (code-level guard)` | test-snapshots-seal.R | the same guard, asserted through the seal surface, plus an unchanged bar count | **Removed contract**, same reason. It is the second witness of the same guard. |
| `CSV import succeeds for CREATED snapshots and rejects SEALED snapshots` | test-snapshots-import-csv.R | `ledgr_snapshot_import_instruments_csv()` fills a `CREATED` snapshot; a `SEALED` one rejects a bars import | **Removed contract.** Both halves are lifecycle. The instruments-from-a-file capability itself survives as `from_csv(instruments_csv_path=)`, covered by a new block in test-snapshot-adapters.R under LDG-2788. |
| `bad timestamp (no Z) fails` | test-snapshots-import-csv.R | a `ts_utc` without a trailing `Z` is rejected with `LEDGR_CSV_FORMAT_ERROR` | **Changed contract.** The kept surface accepts the no-Z form by design and normalizes it. Replaced by a positive block, listed as new evidence below. |

## 3. Migrated blocks

Each moved from the removed importer to `ledgr_snapshot_from_csv()`, with the
error class changing from `LEDGR_CSV_FORMAT_ERROR` to `ledgr_invalid_args`
where the block asserts a rejection.

| block | file |
| --- | --- |
| `bars CSV rounds OHLCV to 8 decimals` | test-snapshot-from-csv.R |
| `bars CSV missing required column fails` | test-snapshot-from-csv.R |
| `OHLC violation fails` | test-snapshot-from-csv.R |
| `instruments are generated from the bars` | test-snapshot-from-csv.R |
| `UTF-8 BOM in bars CSV header is tolerated` | test-snapshot-from-csv.R |
| `AT2: bars CSV format contract: rounding and missing column failure` | test-acceptance-v0.1.1.R |
| `AT3: instruments are generated from the bars when no instruments file is given` | test-acceptance-v0.1.1.R |
| `AT12: UTF-8 BOM tolerated` | test-acceptance-v0.1.1.R |

`AT3` lost its second half, `auto_generate_instruments = FALSE`, which is a
removed contract: `from_csv` generates instruments unless a file supplies
them, and has no way to ask for neither.

Nine further calls were fixture builders, not contract witnesses: they needed
an unsealed snapshot carrying data so they could test the seal, the hash, the
info view, the runner, or reopening. They now call
`ledgr_test_fill_snapshot()`, a new helper at
`tests/testthat/helper-snapshot-store-fixtures.R` that writes the canonical
bar and instrument columns directly. It persists exactly what the removed
importer persisted: `ts_utc` as POSIXct UTC, OHLCV rounded to eight decimals,
and instruments generated from the bars when none are given. The affected
files are test-snapshots-seal.R, test-snapshots-hash.R, test-snapshots-info.R,
test-runner-snapshots.R, test-persistence-fresh-connection.R,
test-snapshot-adapters.R, and the AT7 and AT8 blocks of
test-acceptance-v0.1.1.R.

## 4. Newly added evidence

Labelled as new, not preserved. Neither contract was tested on either surface
before.

| block | file | why |
| --- | --- | --- |
| `a timestamp without a trailing Z is accepted and normalized` | test-snapshot-from-csv.R | pins the changed contract at the point of change. LDG-2789 owns the full branch matrix. |
| `duplicate instrument and timestamp rows fail` | test-snapshot-from-csv.R | the kept surface holds the duplicate-key contract the removed importer also held; nothing exercised it here. |
| `ledgr_snapshot_from_csv accepts an instruments CSV` | test-snapshot-adapters.R | LDG-2788; the capability that would otherwise have been lost. |
| `ledgr_snapshot_from_csv quarantines exactly as ledgr_snapshot_from_df does` | test-snapshot-adapters.R | LDG-2788; the two surfaces must seal the same input to the same hash. |

## 5. Mutation record

One mutation per block, applied to the production function body in a loaded
namespace, the block run, then the original restored. Every mutation was
detected. Harness:
`scratchpad/mutate2786.R` and `mutate2.R`, not checked in.

| id | block | mutation | verdict |
| --- | --- | --- | --- |
| M1 | bars CSV rounds OHLCV to 8 decimals | drop the 8-decimal rounding of `open` | DETECTED |
| M2 | bars CSV missing required column fails | stop requiring the `close` column | DETECTED |
| M3 | a timestamp without a trailing Z is accepted | reject the no-Z form on both accepting paths | DETECTED |
| M4 | OHLC violation fails | drop the OHLC bound check | DETECTED |
| M5 | instruments are generated from the bars | auto-generate only the first instrument | DETECTED |
| M6 | UTF-8 BOM tolerated | stop stripping the BOM from the first column name | DETECTED |
| M7 | duplicate rows fail | drop the duplicate `(instrument_id, ts_utc)` check | DETECTED |
| M8 | AT2 | drop the 8-decimal rounding of `volume` | DETECTED |
| M9 | AT3 | auto-generate a non-USD currency | DETECTED |
| M10 | AT12 | stop stripping the BOM | DETECTED |
| M11 | from_csv accepts an instruments CSV | ignore the supplied instruments file | DETECTED |
| M12 | from_csv quarantines as from_df does | drop the numeric-column normalization | DETECTED |

Two mutations needed a correction before they detected, and both are findings
rather than harness noise.

**M3 needs two sites, not one.** The no-Z form is accepted independently by
the fast branch at `R/snapshot_adapters.R:132` and by the scalar fallback
through `ledgr_iso_utc()`. Breaking either alone leaves the form accepted, so
the branch is a speed path over a fallback that already handles it. That is
the redundancy LDG-2789 collapses, and it is recorded here so the mutation
count is not read as one site.

**M7 was blind until the message was pinned.** The block first asserted any
error whose message contained "duplicate". With the adapter's own check at
`R/snapshot_adapters.R:193` deleted, the `snapshot_bars` primary key still
rejects the rows, and the adapter reports that as
`Bars insert failed (likely duplicate PKs)` with the same
`ledgr_invalid_args` class, so the loose assertion passed. The block now pins
the adapter's exact message. The two layers are both real; the test says
which one it holds.

## 6. Removal (LDG-2787)

Deleted: `ledgr_snapshot_import_bars_csv()` and
`ledgr_snapshot_import_instruments_csv()` with their two files and two help
pages; the five `R/csv-utils.R` helpers that had no other caller
(`ledgr_csv_snapshot_failure_hint`, `ledgr_csv_require_columns`,
`ledgr_csv_parse_ts_utc`, `ledgr_csv_parse_num`,
`ledgr_snapshot_require_created`); both exports; both API-lock entries; the
documentation-contract map entry; the `experiment-store` vignette row. No
deprecation shim: the package is pre-release with no external consumers.

`ledgr_read_csv_strict()` stays, and `ledgr_snapshot_from_csv()` is its only
caller. `ledgr_snapshot_create()` and `ledgr_snapshot_seal()` stay, because
`ledgr_snapshot_from_df()` calls them.

### One contract change the acceptance criteria required

LDG-2787 binds "`LEDGR_CSV_FORMAT_ERROR` appears nowhere in `R/`" while
keeping `ledgr_read_csv_strict()`, which raised that class in four places.
Those four are now `ledgr_invalid_args`, so the kept surface speaks one error
vocabulary, which is what the cut's rationale asked for. This is a visible
change: a missing file, an unreadable file, or a CSV that does not parse into
a data frame now reaches a `ledgr_snapshot_from_csv()` caller as
`ledgr_invalid_args` rather than `LEDGR_CSV_FORMAT_ERROR`. No test asserted
the old class on the kept surface. The class is gone from the package
entirely, so nothing can catch it.

### The seal help page

`?ledgr_snapshot_seal`'s example imported bars through the removed function.
It now writes the instrument and bar rows with `DBI::dbAppendTable()` before
sealing, which is what a caller driving the low-level lifecycle must do. The
example was executed and seals two bars for one instrument.

### One stale file left in place

`dev/ledgr_v0.1.1_dryrun.R` still names the removed importer. It is a v0.1.1
scratch script that already called `ledgr_backtest_run()`, an export that was
removed several versions ago, so it has been broken since long before this
cut and is not a regression introduced here. `dev/` is outside this ticket's
acceptance list. It is recorded for the maintainer to delete or rewrite.
