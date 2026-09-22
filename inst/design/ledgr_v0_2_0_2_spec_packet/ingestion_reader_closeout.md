# Cut 3, Workstream 9 Closeout: Ingestion Reader

*Ran as cut 5; folded into cut 3 by maintainer decision, 2026-09-22.*

**Workstream 9, tickets LDG-2800 through LDG-2802.**
**Opened and closed 2026-09-22, from `ac60941`.**
**Close review returned FAIL twice, `close_review_7_9.md` and its re-review
at `2b15563`, then PASS_AFTER_PATCHES at `ea227fa`. Every finding is
patched. Sections 8, 10, 11 and 13.**
**Accepted by the maintainer, 2026-09-22.**

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
| **an all-numeric `metadata` value** | **yes, now a loud error; found while answering the re-review question, see section 9** |
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

## 9. A third change, found after the close review was patched

Checking the new forced-text set exhaustively, column by column, turned up one
more behaviour the W9-F2 patch moved and did not declare.

`ledgr_snapshot_from_df()` accepts `metadata` as an alternative spelling of
`meta_json` and runs `canonical_json()` over it. Forcing that column to text
changed what it accepts:

| `metadata` value | before | after |
| --- | --- | --- |
| `0001` | sealed as `1` | rejected, not valid JSON |
| `42` | sealed as `42` | sealed as `42` |
| `"{}"` | sealed as `{}` | sealed as `{}` |
| `abc` | rejected | rejected |

The new behaviour is the right one. JSON does not allow leading zeros in a
number, so `0001` was never valid content for that column, and the old path
silently turned it into `1`. But this is the third undeclared change in a cut
whose whole witness was a matrix meant to make changes declare themselves, and
the second found after the close review. It is now pinned by its own matrix
block. `meta_json`, which is stored verbatim with no JSON requirement, keeps
`0001` as text.

The enumeration itself held: of the seven instrument columns
`ledgr_snapshot_from_df()` reads, the five text ones move with the reader and
`multiplier` and `tick_size` do not, confirmed by sealing each in turn.

## 10. The re-review, and what is still open

The re-review at `2b15563` closed W9-F1 and W9-F4, closed W9-F2 for the
canonical bars and instrument columns, and returned **FAIL** again on three
further findings. It confirmed all four workstream 7 patches.

**Closed here.** W9-F6, the null-token rule was stated generally and pinned
only for a bars instrument id; it is now table-driven over every forced text
name in both CSV inputs. W9-F7, the `metadata` rejection asserted a message
without its class; it now pins `ledgr_config_invalid_json`. W9-O3, the matrix
called its expectations "exact messages" when it deliberately pins only
ledgr-owned fragments and, for a DuckDB failure, only the wrapper prefix;
that trade is now stated where the claim was.

The re-review also confirmed the forced set independently, by deriving it
from the schema and the adapter's reads and sealing one column at a time. No
member is missing and none should be removed.

**W9-F5 is resolved. Maintainer decision, 2026-09-22: a quarantined row's
saved copy is a diagnostic, not part of the snapshot's identity.** What
follows is what was found; section 11 records what was done.

Quarantined rows persist
`original_row_json`, which serializes *every* column of the offending bars
row, and the rule-2 hash covers the whole quarantine table. So reader type
inference reaches snapshot identity through columns outside the forced set.
Reproduced:

| input | old | new | rule-2 hash |
| --- | --- | --- | --- |
| extra column `extra=1` | `"extra":1` | `"extra":1.0` | moved |
| extra column `extra=0001` | `"extra":1` | `"extra":"0001"` | moved |
| extra column `extra=NA` | `"extra":null` | `"extra":"NA"` | moved |
| headers `junk,junk` | `junk`, `junk.1` | `junk`, `junk_1` | moved |
| headers `junk,JUNK` | `junk`, `JUNK` | `junk`, `JUNK_1` | moved |

One note on the duplicate-header row. An earlier revision of this section
claimed the old reader also renamed, to `junk.1`, and called the re-review's
two-`junk` result an error. That claim was wrong and is withdrawn: the probe
behind it called `utils::read.csv()` with the default `check.names = TRUE`,
while ledgr's reader passed `check.names = FALSE` and preserved both keys.
So the re-review was right, and DuckDB's renaming is new, as is the
case-only collision where `JUNK` survived before and becomes `JUNK_1` now.
Recorded because the mistake was a probe that did not replicate the code it
claimed to measure, which is the same error as the sequential timing in
section 12.

**The finding underneath is older than this cut.** Both
`ledgr_snapshot_from_df()` and `ledgr_snapshot_from_csv()` document that extra
columns "are ignored and do not become part of the sealed snapshot or its
hash". That is false whenever a row is quarantined: the extra column is
serialized into `original_row_json` and hashed. The reader swap changed how
those values are rendered; it did not create the exposure. Either the
documented contract or the hash payload is wrong, and that is a durable
identity question, so it goes to the maintainer rather than into another
patch round. The options are in the handover note; the smallest of them,
excluding `original_row_json` from the rule-2 payload while keeping it in the
table for diagnostics, is one line but changes rule-2 identity for every
quarantine snapshot.

**Governance. Maintainer decision, 2026-09-22: fold.** Workstream 9 is now
cut 3's second workstream, giving 4 invocations over 9 completed tickets,
0.44. `tickets.yml` keeps cut 5 as a `folded` record carrying its historical
3-over-3 ratio and the reason, so the chronology is not rewritten: this work
did run as its own cut, and that shape is what the gate caught.

## 11. The two maintainer decisions, as implemented

### A quarantined row's saved copy is a diagnostic, not identity

Implemented in `ledgr_snapshot_availability_hash_payload()`. The hashed view
of `snapshot_observation_quarantine` keeps only the canonical bar keys of
`original_row_json` and drops `quarantine_id`; rows are ordered on stable
fields rather than on that id. The stored row is untouched, so a user still
reads every column they supplied.

Three things had to be true at once, and the first attempt only got two:

1. An extra column must not reach the hash. That is what both ingestion
   surfaces already promise.
2. `quarantine_id` must not carry it back in. It is a digest of the whole
   quarantine row and it is also the read's `ORDER BY` key, so leaving it in
   leaked the same values twice, once directly and once through row order.
3. **A quarantined row's own bar values must still reach the hash.** They are
   not in `snapshot_bars`, because the row was excluded, so `original_row_json`
   is the only record of them.

The first attempt dropped `original_row_json` wholesale and satisfied 1 and 2
while breaking 3: changing a quarantined bar's `high` from 8 to 7 no longer
moved the snapshot hash, which is an identity hole, not a fix. An existing
block, `explicit quarantine persists` in `test-availability-facts.R`, caught
it. The shipped version projects the saved row down to the canonical keys
instead of discarding it.

Pinned by `a quarantined row's extra columns do not reach the snapshot hash`
in the compatibility matrix, which asserts both directions: four extra-column
shapes leave the hash unchanged, and a file with no quarantined row hashes
differently from one with.

This changes the rule-2 hash of any snapshot with a quarantined row whose
file carried columns beyond the canonical set. Those old values were computed
over data the documentation said was ignored.

### The fold

Recorded above and in `tickets.yml`. Nothing in the code depends on it.

## 12. A measurement method that was wrong

Worth carrying forward, because it affected a decision in workstream 7 too.

After the identity fix the fast gate reported a 92.16 s median against a 90 s
bound, and a three-run comparison against the previous commit appeared to
confirm a 5.6 s regression. It was not one. Running the two trees
**interleaved**, alternating one run each, gave 84.69, 84.70, 84.67 for the
patched tree against 84.67, 84.38, 85.03 for the baseline. Identical. The
apparent regression was machine state drifting across a long session, and
sequential A-then-B blocks cannot separate that from a real change.

The gate was then re-run on a quiet machine and passed at 86.72 s.

The same sequential method produced workstream 7's claim that moving four
sealing blocks took the fast median from 86.78 s to 90.25 s. That framing is
unreliable for the same reason. The lane decision itself still stands,
because it rests on a direct per-block measurement, about 1.0 s of sealing
per block against a 0.15 s baseline in the same file, which is not a
cross-tree comparison. Cut 3's closeout section 2 should be read with that
distinction in mind.

## 13. The third review, at `ea227fa`

`PASS_AFTER_PATCHES`. It confirmed what the identity change was supposed to
do, by probe rather than by reading: one hash across repeated computation,
repeated seals and reopen-with-verify; every one of the seven canonical bar
fields moves the hash when changed; two invalid rows differing only in an
ignored column tie on the new ordering fields but hash identically, so the
tie has no consequence; and the three earlier patches and the fold are
sufficient. Three findings.

**W9-F8, a real hole, patched.** The projection returned the saved copy raw
when it did not parse as a list. The review reached that state through the
lower-level store and seal boundary by replacing a saved row with the
canonical scalar `42`: the snapshot sealed, `ledgr_snapshot_validate()`
succeeded, and the hash contained `42` and none of the row's bar values. So
a verified snapshot could have a quarantined bar absent from its identity.

The raw fallback is gone. A saved copy must now parse as a JSON object with
named, non-repeating keys including the six required bar keys; `volume` stays
optional and extra keys stay allowed and excluded. The same shape check runs
at seal validation, so the state is rejected before it can seal rather than
only where the hash is computed. Both raise
`ledgr_snapshot_fact_json_invalid`. Pinned by a block covering scalars,
arrays, `null`, a quoted string, malformed text, empty, `NA`, and an object
missing a required key.

**W9-F9, patched.** The opening status said W9-F5 was unresolved while
sections 10 and 11 recorded its resolution. Corrected.

**W9-F10, patched, and my error not the review's.** Section 10 had claimed
the old reader also renamed duplicate headers and called the re-review's
two-`junk` result wrong. The probe behind that claim called
`utils::read.csv()` with the default `check.names = TRUE`, while ledgr's
reader passed `check.names = FALSE`. The re-review was right. The claim is
withdrawn.

**W9-O4, accepted as the intended boundary.** A tamperer can now change
`quarantine_id`, alter extra keys, or reformat the saved JSON's whitespace
without moving the hash. That is what "the saved copy is a diagnostic"
means. Every canonical bar value and every other quarantine column still
moves it, and W9-F8 closes the shapes that fall outside the intended
exclusion.

Two of the three findings were defects in this document rather than in the
code, and both came from a probe that did not replicate what it claimed to
measure: `check.names` here, and the sequential timing in section 12. That
is the pattern worth carrying out of this workstream.
