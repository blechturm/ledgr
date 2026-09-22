# Cut 5 Closeout: Ingestion Reader

**Workstream 9, tickets LDG-2800 through LDG-2802.**
**Opened and closed 2026-09-22, from `ac60941` to this commit.**
**Owner: the maintainer. This draft is agent-provisional.**

## 1. What shipped

`ledgr_read_csv_strict()` reads with `duckdb::read_csv_auto()` instead of
`utils::read.csv()`. DuckDB was already an Import, so no dependency moved.

The reader stays a reader. `instrument_id`, `ts_utc` and `symbol` are forced
to VARCHAR, so ledgr keeps owning instrument identity and all six accepted
timestamp forms and DuckDB never parses a timestamp. Column names are sniffed
first so the type map names only columns that exist, which keeps ledgr's own
missing-column message instead of a DuckDB binder error. Every DuckDB failure
is caught and re-raised as `ledgr_invalid_args`, the class the surface already
used.

Two consequences were intended. A leading-zero instrument id is preserved
instead of silently becoming an integer, which fixes a live defect. Numeric
columns are always double, which made `ledgr_csv_normalize_numeric_columns()`
from LDG-2788 dead, and it is deleted.

| ticket | outcome |
| --- | --- |
| LDG-2800 | The compatibility matrix, as a test, recording the pre-change behaviour of every input shape the swap could move. |
| LDG-2801 | The reader swap, the dead coercion removed, the defect fixed. |
| LDG-2802 | This closeout. |

## 2. Why this was not in cut 3

Cut 3's closeout lists five declined items and does not mention DuckDB. That
was a gap, not a decision. The v0.2.0.1 inventory's OPT-L03 had ruled that a
reader substitution needs an RFC if accepted inputs, inferred types or error
timing change, and all three change here, so the option was carried forward
unexamined rather than measured. The maintainer asked why after cut 3 closed,
the measurement was then run, and the decision was taken directly. Cut 3's
closeout now carries a pointer to this one.

## 3. Clocks

Environment: R 4.6.1 (2026-06-24 ucrt), x86_64-w64-mingw32, duckdb 1.5.5,
`pkgload::load_all(export_all = TRUE)`. Shape: 500 instruments by 1,260
sessions, 630,000 rows. Before: `ac60941`. After: this commit.

| item | before | after |
| --- | ---: | ---: |
| `ledgr_read_csv_strict()` | 4.91 s | 0.26 s |
| `ledgr_snapshot_from_csv()` end to end | 10.72 s | 7.23 s |
| peer fixture ingestion phase | 11.36 s | 7.91 s |

Across cuts 3 and 5 together, `ledgr_snapshot_from_csv()` went from 20.07 s at
`cf94e02` to 7.23 s, and the reader is no longer the largest component of it.
These are single cold clocks, orientation for the closeout, not a promoted
performance record.

| profile | blocks | seconds |
| --- | ---: | ---: |
| fast | 439 | 85.94 |
| review | 235 | 354.28 |

Heavy is unchanged at 190 and no heavy block was touched.

## 4. The compatibility matrix: exactly one row moved

LDG-2800 registered the matrix as a test before the swap, so every behaviour
change had to be declared. After the swap, one row failed and every other row
held.

| shape | moved? |
| --- | --- |
| columns and classes, with and without `volume` | no |
| extra column preserved | no |
| quoted field with an embedded comma | no |
| UTF-8 BOM header | no |
| malformed numeric stays text, rejected later by ledgr | no |
| nonexistent path, `ledgr_invalid_args` | no |
| whole-number prices reach ledgr as double | no, now provided by the reader rather than by the LDG-2788 coercion |
| each accepted `ts_utc` form seals: date-only, ISO-Z, no-Z, mixed | no |
| six malformed files fail with a ledgr class | no |
| ragged row fails with `ledgr_invalid_args` | no |
| **leading-zero instrument id** | **yes, fixed** |

### The one change

A CSV declaring instrument ids `0001` and `0002` sealed with ids `1` and `2`.
`utils::read.csv()` inferred an integer column for all-numeric ids and
`as.character()` dropped the zeros, silently, into a `snapshot_bars` column
the schema types `TEXT`. The snapshot sealed without error over the wrong
identifiers, and its hash was computed from them. DuckDB reads the identity
columns as VARCHAR, so the ids survive.

**Hashes that moved:** any snapshot sealed through `ledgr_snapshot_from_csv()`
from a file whose instrument ids are entirely numeric with leading zeros. Each
such old hash was computed over corrupted identifiers, so the old value was
wrong. No other hash moved: `LTB-0018`, which pins a checked-in fixture
through three timestamp branches, is unchanged, and the peer benchmark fixture
seals to `89ce4285...afdc` before and after.

## 5. One contract change

`ledgr_read_csv_strict()` now rejects any `encoding` other than `"UTF-8"`
instead of passing it to `read.csv(fileEncoding = )`. DuckDB reads UTF-8, and
the only caller already passed `"UTF-8"`. A non-UTF-8 file is now an explicit
`ledgr_invalid_args` rejection rather than a silent mis-decode. This narrows
the accepted input, deliberately.

## 6. Review invocations against the gate

| invocation | mode | artifact |
| --- | --- | --- |
| close review | Type 1 | pending |

One review over three completed tickets: **0.33**, at most the 0.5 gate.

The cut review was compressed into the close review. The cut implements a
maintainer decision already taken, it is three tickets long, and its witness
was registered as a test before any code moved. A reviewer who disagrees
should say so: the compression is recorded here and in `tickets.yml` precisely
so it can be rejected.

## 7. Declined and left open

| item | reason |
| --- | --- |
| Letting DuckDB parse timestamps | It would hand the accepted-timestamp-form contract to a dependency. ledgr owns six branches, including a mixed-form fallback DuckDB would resolve differently. Forcing `ts_utc` to VARCHAR keeps the contract where it is documented and tested. |
| `utils::read.csv()` at `R/indicator-adapters.R:125` | A different surface, indicator data rather than ingestion, with its own contract. Not examined here. |
| Reading bars straight into the snapshot database with DuckDB, skipping R | A larger change that would move validation as well as reading. Not attempted; the reader boundary was the point. |

The remaining cost in `ledgr_snapshot_from_csv()` is the seal, not the read.
Observation 4 of the durable-path note, chunk-local hash dedup, already
shipped in v0.2.0.1; widening that window keeps its earlier disposition as a
bounded-memory question.
