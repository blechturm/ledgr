# Workstream 13: Schema Ceremony Closeout

**Status:** Agent-provisional; awaiting the compressed Cut 7 Type 1 close
review. **Ticket:** LDG-2819. **Baseline:** `8fa1184`.

## What Shipped

`ledgr_validate_schema()` now reads tables, columns, key constraints and CHECK
constraints once into a private catalogue. Its existing per-table loop filters
those frames in memory. Validation still runs on every call and still rejects
out-of-band damage.

`ledgr_create_schema()` reads the stored experiment-store schema version first.
It returns without DDL only when that value exactly equals the current version.
Absent, older, malformed and future markers retain their existing migration or
refusal paths. Non-current creation uses the same prepared catalogue for its
local table, column and CHECK decisions.

No caller, schema definition, migration rule, version value, marker meaning,
marker write site, hash rule or public API changed.

## Detecting Evidence

LCL-0034 registers three fast blocks.

- LTB-0039 traces DBI calls. Validation makes four catalogue reads, one marker
  read and zero DDL calls. Current-version creation makes two reads total and
  zero DDL calls.
- LTB-0040 deletes the marker, then presents a one-version-behind store missing
  the current corporate-action table. Both paths execute migration work,
  restore the current marker and converge to the exact current shape.
- LTB-0041 guards the exact-version predicate, both create-then-validate caller
  boundaries, the unchanged migration body, and the rule that the marker write
  remains after the simulated migration-failure point. LTB-0040 pins the
  baseline schema-shape digest, so changing the schema definition also fails.

Existing schema and migration suites pass unchanged, including dropped-table,
dropped-column, markerless, future-version and older-store cases. LTB-0018
retains its pinned snapshot hash.

Two deliberate mutations demonstrated failure sensitivity:

- restoring a per-table columns query raised validation from four to 36
  catalogue reads and failed LTB-0039 twice;
- keying the shortcut on metadata-table presence produced three failures:
  current creation used three reads, a missing marker was not restored, and the
  structural exact-version guard failed.

## Exact Parity

The same baseline and optimized probes produced one schema-shape SHA-256 for a
fresh store and a one-version-behind migrated store:
`4f2a099ad5ddc3b205e54ae0d9e5bd435047c7df18cda7fa67c5d9e6457f79e0`.
Both implementations retained the exact damage results:

| Damage | Class | Message |
| --- | --- | --- |
| dropped `bars` table | `simpleError/error/condition` | `Missing table: bars` |
| dropped `runs.engine_version` | `simpleError/error/condition` | `Missing columns in runs: engine_version` |

The registered five-pulse public run was identical in all six microbenchmark
runs: final equity 1003 and one fill.

## Performance Record

Clocks were interleaved before and after on R 4.6.1. `ledgr_run()` is the warm
research-iteration clock over a reused sealed snapshot. `ledgr_db_init()` is a
cold connection over an already-current reusable store. Times are seconds.

| Boundary | Before | After | Median before | Median after |
| --- | --- | --- | ---: | ---: |
| `ledgr_db_init()` | 0.84 / 0.72 / 0.70 | 0.28 / 0.28 / 0.28 | 0.72 | 0.28 |
| `ledgr_run()` | 1.79 / 1.75 / 1.81 | 1.14 / 1.21 / 1.22 | 1.79 | 1.21 |
| fast profile | 115.16 / 116.70 / 87.82 | 75.73 / 75.35 / 70.77 | 115.16 | 75.35 |
| review profile | 420.6 / 418.8 / 418.0 | 305.2 / 305.0 / 305.3 | 418.8 | 305.2 |

The optimized fast profile ran 447 blocks versus the baseline's 444 because it
includes LTB-0039 through LTB-0041. All 447 passed. Its median is 14.65 seconds
below the 90-second bound; the ordinary one-run gate passed at 75.73 seconds.

The review profile had 255 blocks on both sides. Every run had 253 passes, one
skip and the same pre-existing failure in `test-availability-fold-witnesses.R`:
the frozen expected row says schema version 115 while this branch stores 116.
Workstream 13 did not change that status. Review clocks are therefore complete
lane measurements, not a claim that the pre-existing review lane is green.

Record directories are under `.tmp/ws13-{fast,review}-{before,after}` in
`C:/Users/maxth/ledgr-research`; the fast gate record is
`.tmp/ws13-fast-gate`.

## Seven-Shape Audit And Declined Work

The new code performs four set-wise catalogue queries and filters bounded
schema metadata. It adds no iteration over bars, facts, instruments by pulses,
events, diagnostics or candidates; no one-row frame append; no element-wise
timestamp formatting or JSON; no pairwise validator; and no work computed then
discarded. The retained loop is over the fixed required-schema map and
preserves every check.

Declined: skipping validation on the version marker; keying creation on a
table; changing callers, DDL, migrations, hashes or marker semantics;
parallelizing tests; and any Workstream 14 or Workstream 12 behavior.

Cut 7 has one ticket and compresses its cut review into this close review. One
review invocation over one completed ticket is 1.0; the packet already names
LDG-2795 as the candidate that would make the cut satisfy the 0.5 gate. This
closeout does not silently count or implement that candidate.
