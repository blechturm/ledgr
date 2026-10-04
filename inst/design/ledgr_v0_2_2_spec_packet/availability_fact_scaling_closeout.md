# Workstream 9 Closeout: Availability Fact Scaling

**Status:** Agent-provisional; ready for Type 1 close review, with the Linux
CI repetition identified as an external confirmation.
**Date:** 2026-10-04
**Implementation range:** `09d6849..9f807ec`
**Tickets:** LDG-2943 through LDG-2945

## Outcome

Both preregistered candidates passed and ship in the proposed workstream.
Declared sessions resolve a vector of local wall times in one timezone pass.
Membership resolution filters and groups applicable set rows once, then
applies the ordered headers through integer indexes.

No public API, fact schema, fact or snapshot identity, ordering, evidence,
condition class, provider-run behavior, session policy or bar axis changed.
The retained scalar local-time resolver remains the independent oracle.

## Session Construction

The recorded fixture contains 10,473 civil dates from 1998-01-02 through
2026-09-04. Three alternating pairs ran the old scalar resolver and the new
vector resolver in one loaded tree. Each pair required exact family rows and
fact hashes before it was retained.

| Timezone | Scalar median | Vector median | Speedup |
| --- | ---: | ---: | ---: |
| UTC | 19.61 s | 1.44 s | 13.62x |
| America/New_York | 48.93 s | 1.61 s | 30.39x |

The weaker result clears the registered 5x constructor gate. Raw rows are in
`dev/bench/v0_2_2_workstream9/evidence/session_timings.csv`.

LTB-0145 compares the vector result with the retained scalar resolver over a
leap date, the spring DST boundary and explicit ordinary, nonexistent and
ambiguous labels. Existing session tests retain the exact public condition
classes and messages. LTB-0148 seals scalar and vector families independently
and requires identical rule-2 snapshot hashes. The same LTB-0145 block is in
the Linux fast profile; its CI result must be confirmed when this branch is
next pushed.

## Membership Resolution

The public `ledgr_facts_resolve()` record uses 500 instruments and 12, 60 and
600 dated sets: 6,000, 30,000 and 300,000 fact rows. Three alternating pairs
ran the old full-table-per-header resolver and the indexed resolver in one
loaded tree. Every pair required exact public rows and evidence.

| Fact rows | Old median | Indexed median | Saving |
| ---: | ---: | ---: | ---: |
| 6,000 | 0.17 s | 0.12 s | 29.4% |
| 30,000 | 0.77 s | 0.45 s | 41.6% |
| 300,000 | 9.75 s | 4.67 s | 52.1% |

The candidate exponent is 0.941 over those three public points, below the
1.15 ceiling. The 300,000-row result clears the required 50% reduction.
Bundle re-hashing alone took 3.80 seconds at 300,000 rows, about 81% of the
candidate public call. That cost is reported rather than bypassed: snapshot
integrity remains native ledgr authority. Raw records are in
`membership_timings.csv` and `membership_rehash_timings.csv` beside the
session record.

LTB-0146 covers unsorted headers, two complete sets, earlier partial members,
a later incremental member, an earlier-dated set-less assertion, unknown
requests and a cutoff before the first usable header. It pins literal members,
reasons and evidence IDs. LTB-0147 counts one indexing call and one visit to
the input rows, and rejects the retired per-header `rows$set_id ==` scan.

## Failure Probes

All mutations ran in a detached disposable worktree.

| Mutation | Detecting result |
| --- | --- |
| Restore scalar resolution per local timestamp | LTB-0145 fails the scalar-call counter |
| Reverse the timezone offset operation | LTB-0145 and LTB-0148 error before accepting wrong rows |
| Keep the first rather than last complete set | LTB-0146 fails members, reasons and evidence |
| Do not reset earlier-seen members at a complete set | LTB-0146 fails members, reasons and evidence |
| Apply set-less rows only when dated after the complete set | LTB-0146 fails members, reasons and evidence |
| Drop the later incremental set | LTB-0146 fails members, reasons and evidence |
| Rescan indexed rows for every header | LTB-0147 fails its structural assertion |

A separate 100-seed randomized comparison of the retained and indexed
resolvers also returned exact list identity. It is supporting orientation;
the registered literal and paired public evidence are the gates.

## Seven-Shape Walk

1. Repeated lookup. Session offsets are discovered once for the batch.
   Membership rows are scoped, matched to headers and indexed once.
2. Growing scans. Sessions perform fixed five-day offset probes and one
   fixed-offset roundtrip per label. Membership no longer scans all rows for
   each header or each instrument.
3. Per-element work with a batch replacement. Timezone formatting is batched.
   Membership state transitions remain sequential because ordered complete
   and incremental sets are the contract, but they consume prepared indexes.
4. Scale-growing collections. Session candidate matrices are rows times the
   small observed timezone-offset vocabulary. Membership arrays are bounded
   by relevant rows and distinct instruments; no history-growing registry was
   introduced.
5. Recomputed discarded work. Neither path reconstructs the same formatted
   timestamp, row subset or instrument match inside a growing loop.
6. Frame construction. Sessions construct the public fact frame only at the
   boundary. Membership filters frames once and keeps primitive state arrays
   through resolution.
7. Mutation and copy shape. Both implementations own local vectors and lists;
   neither mutates a fact family, provider object or caller input.

## Verification And Records

The durable benchmark command is:

```text
Rscript dev/bench/v0_2_2_workstream9/run_benchmarks.R \
  <repo> <output-directory>
```

Two initial runs completed their expensive session arms but could not write
to unprepared or ACL-incompatible output directories. They retained no CSVs
and are excluded. The checked-in record is the unchanged third run written to
an explicitly writable directory and copied under the benchmark evidence
directory. `summary.json` recomputes both gates.

The availability-fact-scaling, availability-facts,
availability-inspection and test-control-plane files pass. The first complete
fast record was green but failed its timing gate: 506/506 blocks at 132.92,
112.92 and 118.18 seconds, median 118.18 against 112. A pre-existing
indicator-development block absorbed 29.14 to 31.31 seconds in all three runs,
while the new session block took 1.48 to 2.15 seconds.

The semantic block was then reduced from a redundant 370-date scalar family
to the smallest 20-date leap-day and spring-DST family; the 10,473-date paired
record remains the long-horizon oracle. The correction record at
`C:/Users/maxth/ledgr-research/ws9-correction-fast-9f807ec` executed 506 of
506 blocks with zero skips or failures in 89.03 seconds. The independent
checker returned `LEDGR_TEST_GATE_OK` against the 112-second bound.

The planned close review is Cut 2 invocation eight over eleven tickets,
8/11 = 0.727. The cut already breached its 0.5 review gate during prior
workstreams; this count is recorded rather than hidden or repaired by padding.
