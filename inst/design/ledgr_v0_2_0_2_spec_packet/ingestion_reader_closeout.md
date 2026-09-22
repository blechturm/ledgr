# Cut 5 Closeout: Ingestion Reader

**Workstream 9, tickets LDG-2800 through LDG-2802.**
**Opened and closed 2026-09-22, from `ac60941`.**
**Close review `close_review_7_9.md` returned FAIL; patched, see section 8.**
**Owner: the maintainer. This draft is agent-provisional.**

## 1. What shipped

`ledgr_read_csv_strict()` reads with `duckdb::read_csv_auto()` instead of
`utils::read.csv()`. DuckDB was already an Import, so no dependency moved.

The reader stays a reader. Every column ledgr persists or hashes as text is
forced to VARCHAR, so ledgr keeps owning instrument identity, all six accepted
timestamp forms and every stored metadata string, and DuckDB never parses a
timestamp. That set is `instrument_id`, `ts_utc`, `symbol`, `currency`,
`asset_class`, `meta_json` and `metadata`; it was three columns until close
review W9-F2. Column names are sniffed
first so the type map names only columns that exist, which keeps ledgr's own
missing-column message instead of a DuckDB binder error. Every DuckDB failure
is caught and re-raised as `ledgr_invalid_args`, the class the surface already
used.

Two consequences were intended. An all-numeric leading-zero value in any
persisted text column is preserved instead of silently becoming a number,
which fixes a live defect. Numeric columns are always double, which made
`ledgr_csv_normalize_numeric_columns()` from LDG-2788 dead, and it is deleted.
A third was not intended and is now declared: a literal `NA` is text rather
than missing. See section 5.

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
Command: `Rscript dev/bench/v0_2_0_2_ingestion/ingestion_clocks.R`.

| item | before | after | after, re-run post-patch |
| --- | ---: | ---: | ---: |
| `ledgr_read_csv_strict()` | 4.91 s | 0.26 s | 0.22 s |
| `ledgr_snapshot_from_csv()` end to end | 10.72 s | 7.23 s | 6.56 s |
| `ledgr_snapshot_from_df()`, POSIXct | 7.17 s | 7.17 s | 7.01 s |
| peer fixture ingestion phase | 11.36 s | 7.91 s | 7.52 s |

Across cuts 3 and 5 together, `ledgr_snapshot_from_csv()` went from 20.07 s at
`cf94e02` to 7.23 s, and the reader is no longer the largest component of it.
These are single cold clocks, orientation for the closeout, not a promoted
performance record.

| profile | blocks | seconds |
| --- | ---: | ---: |
| fast | 439 | 87.52 |
| review | 237 | 362.11 |

Re-run after the close-review patches, which added two review blocks.

Heavy is unchanged at 190 and no heavy block was touched.

## 4. The compatibility matrix: what moved

LDG-2800 registered the matrix as a test before the swap, so every behaviour
change the matrix covered had to be declared. After the swap one registered
row failed and every other registered row held. The first version of this
section read that as "exactly one behaviour moved", which was the wrong
inference: the matrix only proves what it enumerates, and it enumerated
neither the instruments CSV nor null tokens. Close review W9-F2 and W9-F3
found two further moved behaviours in the gaps. The matrix now covers both
and the table below marks the rows it gained.

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
| **leading-zero `symbol`, `currency`, `asset_class`, `meta_json`** | **yes, fixed; row added under W9-F2** |
| **a literal `NA` field** | **yes, widened and declared; row added under W9-F3** |
| malformed numeric past DuckDB's type sample | rejects as before, at the reader with a different message; row added under W9-O1 |

### The one change

A CSV declaring instrument ids `0001` and `0002` sealed with ids `1` and `2`.
`utils::read.csv()` inferred an integer column for all-numeric ids and
`as.character()` dropped the zeros, silently, into a `snapshot_bars` column
the schema types `TEXT`. The snapshot sealed without error over the wrong
identifiers, and its hash was computed from them. DuckDB reads the identity
columns as VARCHAR, so the ids survive.

**Hashes that moved.** This section was wrong in the first version of this
closeout and is corrected under W9-F2 below. The defect is not confined to
`instrument_id`. It applies to every column ledgr persists as text, because
the old reader inferred a number for an all-numeric value and dropped its
leading zeros. Verified for `symbol`, `currency` and `asset_class` in an
instruments CSV: each seals a different hash before and after, with unchanged
bars. So the moved set is any snapshot sealed through
`ledgr_snapshot_from_csv()` from a file with an all-numeric leading-zero value
in `instrument_id`, `symbol`, `currency`, `asset_class`, `meta_json` or
`metadata`. Every such old hash was computed over a corrupted string, so the
old value was wrong.

`LTB-0018`, which pins a checked-in fixture through three timestamp branches,
is unchanged, and the peer benchmark fixture seals to `89ce4285...afdc` before
and after. Neither contains an all-numeric text field.

## 5. Contract changes

**Encoding.** `ledgr_read_csv_strict()` now rejects any `encoding` other than
`"UTF-8"` instead of passing it to `read.csv(fileEncoding = )`. DuckDB reads
UTF-8, and the only caller already passed `"UTF-8"`. A non-UTF-8 file is now
an explicit `ledgr_invalid_args` rejection rather than a silent mis-decode.
This narrows the accepted input, deliberately.

**Null tokens.** Added under W9-F3, which found this change undeclared in the
first version. `utils::read.csv()` read a literal `NA` field as missing;
DuckDB returns the two-character string. An instrument id of `NA` was
therefore rejected before and seals now. The rule is now explicit and tested:
an empty field is missing, and a literal `NA` is text. This widens the
accepted domain, deliberately, because `NA` is a real ticker and CSV says
missing with an empty field. Numeric columns are unaffected, since they stay
inferred and their `NA` is still missing, which ledgr's finite-value check
rejects.

## 6. Review invocations against the gate

| invocation | mode | artifact |
| --- | --- | --- |
| close review | Type 1 | `close_review_7_9.md`, FAIL, patched in place |
| cut review, owed | Type 1 and Type 2 | not run; see below |

**The compression was rejected and the gate is breached.** The close review
declined to accept the cut review folded into it, on the ground that the
missing review was a question about inputs that had to be asked before the
matrix could be treated as authority: does it cover both CSV inputs, every
persisted text field, null tokens and the sample-dependent error boundary?
That question was not asked, and W9-F1 through W9-F3 are exactly what it would
have caught.

Counting the owed cut review, cut 5 stands at **2 invocations over 3
completed tickets, 0.67**, above the 0.5 gate. That is recorded, not argued
away. The lesson for the pilot record is structural: a three-ticket cut cannot
carry the loop's two reviews and stay under D8. This work should have been a
second workstream inside cut 3, or cut 3 should have been reopened, rather
than becoming a cut of its own. The maintainer decides whether to accept the
breach for this cut or restructure it.

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

## 8. What the close review changed

`close_review_7_9.md` returned FAIL for this workstream. Four findings, all
verified against the tree before patching, all patched here.

**W9-F2, the hash claim was false.** Confirmed by reproduction: an
instruments CSV with `symbol`, `currency` or `asset_class` set to `0001`
sealed a different hash before and after, with unchanged bars. The forced-text
set was three identity columns; it is now every column ledgr persists or
hashes as text, `instrument_id`, `ts_utc`, `symbol`, `currency`,
`asset_class`, `meta_json` and `metadata`. The two numeric instrument
columns, `multiplier` and `tick_size`, stay inferred because they persist as
DOUBLE. Section 4's claim is corrected above, and so is the horizon entry.

**W9-F3, an undeclared boundary change.** Confirmed: an instrument id of `NA`
was rejected before and sealed after. The rule is now declared in section 5
and pinned by a matrix block.

**W9-F1, the matrix was weaker than the ticket required.** It captured
failure messages without asserting them and accepted either of two classes
for six shapes. Every shape now asserts an exact class and message, the
successful shapes assert full names and classes, and three families were
added: the instruments CSV, null tokens, and a malformed numeric past
DuckDB's type sample.

**W9-F4, the clocks had no reproduction command.** Added:
`Rscript dev/bench/v0_2_0_2_ingestion/ingestion_clocks.R`, checked in, which
reproduces every clock in section 3. Running it after the patches gives
reader 0.22 s, `from_csv` 6.56 s, `from_df` 7.01 s on POSIXct input, peer
phase 7.52 s. Writing that probe found a defect in my own scratch version: it
had timed the construction of each normalization input along with the call,
which is why two component clocks first came back near 3.4 s instead of 0.04.
The section 3 figures were never affected; they came from a probe that built
its inputs outside the clock.

**W9-O2, the redundant seam.** `ledgr_csv_read_bars_for_snapshot()` is kept
for now. It is the boundary the matrix tests, and inlining it would point the
matrix at `ledgr_read_csv_strict()` directly, which is a change to what the
witness covers rather than a cleanup. Left for the maintainer.

**W9-O1, the sniff boundary.** Accepted as a declared consequence and pinned
by its own matrix block. Both stages reject with `ledgr_invalid_args`; only
the message differs, and section 4 no longer implies message parity.
