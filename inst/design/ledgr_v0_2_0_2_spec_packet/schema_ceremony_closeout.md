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
marker write site, hash rule or public API source changed. The shortcut relies
on two existing ordering invariants: create writes the current marker only
after its own DDL, and every public path that can write a marker into a fresh
store runs create first. The marker alone does not certify the create-owned
table set.

## Detecting Evidence

LCL-0034 registers three fast blocks.

- LTB-0039 traces DBI calls. Validation makes four catalogue reads, one marker
  read and zero DDL calls. Current-version creation makes two reads total and
  zero DDL calls.
- LTB-0040 deletes the marker, then presents a one-version-behind store missing
  both the migration-owned corporate-action table and the create-owned `bars`
  table. Both paths execute work, restore the current marker and converge to
  the exact current shape. It is the behavioral detector for exact-version
  shortcut selection.
- LTB-0041 structurally guards that exact `identical()` predicate, both
  create-then-validate caller boundaries, the unchanged migration body, and
  the rule that the marker write remains after the simulated migration-failure
  point. LTB-0040 pins the baseline schema-shape digest, so changing the schema
  definition also fails.

Existing schema and migration suites pass unchanged, including dropped-table,
dropped-column, markerless, future-version and older-store cases. LTB-0018
retains its pinned snapshot hash.

Two deliberate mutations demonstrated failure sensitivity:

- restoring a per-table columns query raised validation from four to 36
  catalogue reads and failed LTB-0039 twice;
- keying the shortcut on metadata-table presence produced three failures:
  current creation used three reads, a missing marker was not restored, and the
  structural exact-version guard failed.

The close-review correction tightened the exact-version source guard and added
the create-owned-table cases to LTB-0040. Replacing the exact predicate with
`schema_version > 0` then produced six failures across LTB-0040 and LTB-0041:
the older store did not restore either missing table or converge to the current
shape, and the structural predicate guard failed. Production was restored
before the passing runs.

## Exact Parity

The same baseline and optimized probes produced one schema-shape SHA-256 for a
fresh store and a one-version-behind migrated store:
`4f2a099ad5ddc3b205e54ae0d9e5bd435047c7df18cda7fa67c5d9e6457f79e0`.
Both implementations retained the exact damage results:

| Damage | Class | Message |
| --- | --- | --- |
| dropped `bars` table | `simpleError/error/condition` | `Missing table: bars` |
| dropped `runs.engine_version` | `simpleError/error/condition` | `Missing columns in runs: engine_version` |

One damaged-store behavior deliberately differs. With the current marker
present, dropping a create-owned table was silently repaired by the former
repeat-DDL path. Creation now takes the current-version shortcut and validation
fails closed with `Missing table: bars`. LTB-0040 pins that result. This does
not change healthy-store shape or outputs.

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
| fast profile | 115.16 / 116.70 / 87.82 | 75.73 / 75.35 / 70.77 | not comparable | not comparable |
| review profile | 420.6 / 418.8 / 418.0 | 305.2 / 305.0 / 305.3 | 418.8 | 305.2 |

The optimized fast profile ran 447 blocks versus the baseline's 444 because it
includes LTB-0039 through LTB-0041. All 447 passed. The six fast runs did not
share one load regime: unrelated blocks in the third baseline run were about
25 percent faster than in the first two. The honest effect comparison is the
matched quiet-end pair, 87.82 to 70.77 seconds, a 17.05-second or 19-percent
reduction. The optimized three-run median was 75.35 seconds, but it is not
compared with the loaded baseline median. The ordinary one-run gate passed at
75.73 seconds. Earlier Workstream 11 review runs were already 113 to 115
seconds, so this work restored the 90-second bound rather than merely adding
headroom to a lane still inside it.

The review profile had 255 blocks on both sides. Every run had 253 passes, one
skip and the same pre-existing failure in `test-availability-fold-witnesses.R`:
the frozen expected row says schema version 115 while this branch stores 116.
Workstream 13 did not change that status. Review clocks are therefore complete
lane measurements, not a claim that the pre-existing review lane is green.

Record directories are under `.tmp/ws13-{fast,review}-{before,after}` in
`C:/Users/maxth/ledgr-research`; the original fast gate record is
`.tmp/ws13-fast-gate`. After the close-review correction, all 447 fast blocks
passed again in 70.40 seconds and the ordinary gate passed from
`.tmp/ws13-correction-fast`.

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

Cut 7 has one ticket and compressed its cut review into this close review. At
the correction stage it has one completed review; focused re-review will make
two invocations over one completed ticket, 2.0, against the 0.5 gate. Adding
unrelated work now cannot make either review cover that work, so it would not
repair the ratio. The cut remains open pending the maintainer's explicit choice
either to record the honest historical exception, following Cut 5's precedent,
or to amend the cut for independently justified work. This closeout does not
silently count or implement LDG-2795.
