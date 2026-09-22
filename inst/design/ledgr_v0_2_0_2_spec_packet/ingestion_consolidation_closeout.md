# Cut 3 Closeout: Ingestion Consolidation (workstream 7)

*Cut 3 has a second workstream, 9, closed out in
`ingestion_reader_closeout.md`. It ran as cut 5 and was folded in on
2026-09-22. Combined gate: 4 review invocations over 9 tickets, 0.44.*

**Workstream 7, tickets LDG-2786 through LDG-2791.**
**Opened 2026-09-22 at `cf94e02`, closed at `c43fe1a`.**
**Close review `close_review_7_9.md`: PASS_AFTER_PATCHES; patched, section 8.**
**Owner: the maintainer. This draft is agent-provisional.**

## 1. What shipped

| ticket | commit | outcome |
| --- | --- | --- |
| LDG-2788 | `bfb2304` | `ledgr_snapshot_from_csv()` gains `instruments_csv_path`, `facts`, `invalid_observations`. One contract, two input types. |
| LDG-2786 | `f63d2f5` | 27 importer calls migrated across eight test files. Four blocks deleted, four added, twelve mutations recorded. |
| LDG-2787 | `c0a2a32` | `ledgr_snapshot_import_bars_csv()` and `ledgr_snapshot_import_instruments_csv()` removed with five dead helpers. |
| LDG-2789 | `fab0158` | Timestamp normalization deduplicates and stops reformatting what it just parsed. Output identical, hash pinned. |
| LDG-2790 | `c43fe1a` | The peer harness prepares its snapshot through the public file surface. |
| LDG-2791 | this document | Closeout. |

Detail for LDG-2786 and LDG-2787 is in `ws7_migration_evidence.md`.

The package now has one CSV ingestion surface. `ledgr_snapshot_from_csv()` is
the file form of `ledgr_snapshot_from_df()`: same columns, same timestamp
forms, same point-in-time facts, same error vocabulary, same snapshot hash.

## 2. Clocks

Environment for every clock below: R 4.6.1 (2026-06-24 ucrt),
x86_64-w64-mingw32, duckdb 1.5.5, collapse 2.1.8, package loaded with
`pkgload::load_all(export_all = TRUE)`.

### Ingestion at the release shape

500 instruments by 1,260 sessions, 630,000 rows, one cold run each.
Before: `cf94e02`. After: `c43fe1a`.
Command: `Rscript dev/bench/v0_2_0_2_ingestion/ingestion_clocks.R`, checked in
under close review W7-F4, which found this section named no reproducible
command. The probe builds the frame, writes it to CSV, and times each entry
point once.

| path | before | after |
| --- | ---: | ---: |
| `ledgr_snapshot_from_df()`, POSIXct input | 10.39 s | 7.17 s |
| `ledgr_snapshot_from_df()`, ISO-Z character input | 12.09 s | 6.69 s |
| `ledgr_snapshot_from_csv()` | 20.07 s | 10.72 s |

These are two end-to-end clocks per path, not a distribution. They are
orientation for the closeout, not a promoted performance record.

### Timestamp normalization, component clocks

Same shape and commits, timing `ledgr_snapshot_normalize_ts_utc()` alone.
Before, the same work inline in `ledgr_snapshot_from_df()`.

| branch | before | after |
| --- | ---: | ---: |
| POSIXct | 4.32 s | 0.05 s |
| ISO-Z character (parse plus reformat) | 2.02 + 3.23 s | 0.04 s |
| date-only character | not isolated before | 0.03 s |
| ISO without Z | not isolated before | 0.09 s |

Component clocks. They do not sum to the end-to-end difference and must not
be quoted as a speedup for `ledgr_snapshot_from_df()`. The ISO-Z before figure
is the sum of two separately timed steps, parse then reformat; a second run of
the same pair measured 1.79 and 3.21, so treat these as one significant figure.

### Peer fixture

`dev/bench/results/peer_benchmark_shared_bars_record.csv`, 630,000 rows over
500 instruments, 2018-01-01 to 2022-10-28, at `c43fe1a`.

| ingestion phase | seconds | snapshot hash |
| --- | ---: | --- |
| old: `read.csv()` + `as.POSIXct()` + `from_df()` | 15.94 | `89ce4285...afdc` |
| new: `from_csv()` | 11.36 | `89ce4285...afdc` |

The sealed artifact is byte-identical. The phase changed definition, so a
record produced after this cut is not comparable with an earlier one on
`snapshot_prepare_sec`. No promoted record was edited.

### Test profiles

At `c43fe1a`, command `Rscript tools/run-test-profile.R --profile=<p>`.

| profile | blocks | seconds |
| --- | ---: | ---: |
| fast (gate run) | 439 | 87.99 |
| review | 229 | 346.27 |

Gate: `Rscript tools/check-test-gate.R --profile=fast --mode=ordinary`
returned `LEDGR_TEST_GATE_OK mode=ordinary runs=1 median=87.990 bound=90.000`.
One run is the protocol when the first run is under the bound. Heavy protocol
is unchanged at 190 blocks; this cut touched no heavy block and none was
re-run.

### A fast-lane regression this cut caused and fixed

Worth recording, because it was invisible in per-file runs and only appeared
under the gate. The migrated CSV contract blocks call
`ledgr_snapshot_from_csv()`, which creates a DuckDB file and seals it. The
importer blocks they replaced used an in-memory DuckDB and never sealed, so
four blocks that had been nearly free became about one second each.

Measured on the same machine, three runs of the fast profile each. Read the
cross-tree rows with care: they were taken sequentially, one tree then the
other, and a later interleaved comparison showed that method can invent a
five-second difference out of machine drift alone. See section 12 of
`ingestion_reader_closeout.md`. The lane decision does not rest on these
rows; it rests on the per-block measurement below them.

| tree | blocks | seconds | median |
| --- | ---: | --- | ---: |
| `cf94e02`, before the cut | 445 | 88.09, 86.74, 86.78 | 86.78 |
| after LDG-2790, all blocks `fast` | 443 | 88.74, 90.25, 90.91 | 90.25 |
| after moving four sealing blocks to `review` | 439 | 84.83, 85.05, 86.59 | 85.05 |

Two of three runs had crossed the 90-second bound. The four blocks that seal
a durable snapshot moved to `review` and the three rejection blocks that never
reach the seal stayed `fast`. The lane is now 1.7 seconds faster than the cut
found it.

**The criterion, stated after close review W7-F4.** The rule as first written
here, "durable sealing belongs in review", is too broad and the review was
right that the tree does not obey it: `AT2`, `AT3` and `AT12` in
`test-acceptance-v0.1.1.R` seal durable snapshots and stay `fast`. The
criterion that the tree does obey, and that a reviewer can check block by
block, is narrower:

> A block belongs in `review` when durable sealing dominates its cost and the
> contract it asserts is not itself the durable path. A block whose subject is
> the end-to-end durable path keeps its lane, because there the sealing is the
> thing under test rather than overhead.

Under that criterion the four moved blocks belong in `review`: each seals a
whole snapshot to assert one property of the reader or the adapter. The three
acceptance blocks keep `fast`: the v0.1.1 acceptance suite exists to exercise
the whole ingestion-to-seal path, so their sealing is intrinsic. Measured
cost of that exception: `AT2` 1.39 s, `AT3` 1.43 s, `AT12` 1.16 s against
`AT1` at 0.75 s for the same file with no sealing, so about 1.5 s of the fast
lane. If the maintainer prefers the broader rule, moving all three is a
one-line change per block and buys that 1.5 s.

**D5 questions for the four moved blocks.** What contract: the reader's
rounding, its acceptance of the no-Z form, instrument auto-generation, and BOM
tolerance, each on the kept file surface. Oracle independence: each asserts a
value read back out of the sealed database, not a value the adapter returned.
Smallest breaking change: recorded as M1, M3, M5 and M6 in section 5, all
detected. Cheapest adequate lane: `review`, because the assertion needs a
sealed snapshot and the fast lane is budgeted. Overlap: `AT2` overlaps the
rounding block and `AT3` overlaps the auto-generation block, both through the
same public call. That overlap is real and is the reason the acceptance
blocks were not also rewritten; merging by claim family was cut 1's
workstream 4 and is closed.

## 3. Census

| | total | fast | review | heavy |
| --- | ---: | ---: | ---: | ---: |
| before, cut 1 close | 850 | 445 | 215 | 190 |
| after cut 3 | 858 | 439 | 229 | 190 |

Twelve blocks added, four deleted. The additions are the two LDG-2788
surface blocks, the two new contract blocks in `test-snapshot-from-csv.R`,
and the eight blocks of `test-snapshot-timestamp-branches.R`. Six blocks
moved lane: four from `fast` to `review` for the reason above, and the
`test-snapshot-from-csv.R` file's remaining split.

One claim registered: **LCL-0015**, snapshot identity is independent of the
accepted `ts_utc` input form, detected by **LTB-0018**, promised profile
`review`.

## 4. Review invocations against the gate

| invocation | mode | artifact |
| --- | --- | --- |
| cut review | Type 1 and Type 2 | `cut_review_3_4.md`, `PASS_AFTER_PATCHES`, patched at `cf94e02` |
| close review | Type 1 | pending |

Two reviews over six completed tickets: **0.33**, at most the 0.5 gate.

## 5. Contract changes

Three, all deliberate, none of them a silent merge of the two surfaces.

1. **One error vocabulary.** `LEDGR_CSV_FORMAT_ERROR` no longer exists. A
   missing or unparseable file reaches a `from_csv()` caller as
   `ledgr_invalid_args`. Required by LDG-2787's acceptance, which keeps
   `ledgr_read_csv_strict()` while binding the class to disappear.
2. **The no-Z timestamp form is accepted by the file surface.** The removed
   importer rejected it; the kept surface normalizes it. This is the removal
   of a stricter surface, not a loosening of the kept one.
3. **`from_csv` normalizes integer price columns to double.** R's CSV reader
   infers integer columns for whole-number prices, and a quarantined row
   records the supplied row verbatim, so the same logical data sealed to a
   different hash depending on input form. Found by LDG-2788's own acceptance
   test. No existing identity moved, because quarantine was unreachable from
   `from_csv` before that ticket.

Two capabilities were removed with no replacement, both recorded in
`ws7_migration_evidence.md`: the caller-owned create-import-seal lifecycle
with its `CREATED`/`NOT_MUTABLE` guard, and `auto_generate_instruments =
FALSE`, which asked for neither a file nor generated instruments.

## 6. Declined, with reasons

| item | reason |
| --- | --- |
| `colClasses` on the bars reader | 0.9 s at the release shape, and it moves the malformed-numeric error from `ledgr_csv_parse_num()` to `read.csv()`, changing which error fires and what it says. Not worth a contract change. **Moot after cut 5**, which replaced the reader outright. |
| Widening the hash chunk window | A bounded-memory question for datasets whose timestamps are mostly unique, not a free change. Keeps its earlier disposition. |
| Raw-bytes canonical hashing | Changes durable identity; needs its own version-matrix RFC, not an optimization ticket. |
| Reading the CSV with DuckDB | **Superseded.** Not considered here at all, which was a gap rather than a decision; OPT-L03's rule had put a reader substitution on the RFC side of its line and the option was carried forward unmeasured. The maintainer asked after this cut closed, the measurement was run, and it became cut 5. See `ingestion_reader_closeout.md`. |
| Speeding the peer harness's own `read.csv()` for peer engines | Would improve a published peer number without improving ledgr. Declined in the durable-path note and still declined. |
| Deduplicating the adapter's duplicate-key check against the primary key | The two layers are both real and the app-level check gives a clear message before any write. Recorded, not changed. |

## 7. What this cut leaves open

- **The no-Z branch is redundant with the fallback.** Proved by mutation:
  breaking either alone leaves the form accepted. The fast branch is a speed
  path over a fallback that already handles the form. Collapsing them is a
  small later cleanup, not done here because it would change which code
  raises which error.
- **`dev/ledgr_v0.1.1_dryrun.R`** still names the removed importer. It has
  been broken since `ledgr_backtest_run()` was removed several versions ago.
  For the maintainer to delete or rewrite.
- **Event serialization** still needs the bounded spike the 2026-09-17
  durable-path note asked for. Untouched by this cut.

## 8. What the close review changed

`close_review_7_9.md` returned PASS_AFTER_PATCHES for this workstream. Four
findings, all verified before patching.

**W7-F1, the rejection matrix omitted a required input.** LDG-2789 binds a
non-time column and the matrix tested only character, Date and POSIXct
inputs. Added: a numeric `ts_utc` and a factor `ts_utc`, both asserted
against the frozen pre-change body for class and message.

**W7-F2, removal left contradictory operative documentation.**
`contracts.md` still promised the low-level create/import/seal workflow and
`man/ledgr_snapshot_from_csv.Rd` still named `LEDGR_CSV_FORMAT_ERROR`, a
class that no longer exists. Both corrected. The contract clause now names
`ledgr_snapshot_from_csv()` and records that `ledgr_snapshot_create()` and
`ledgr_snapshot_seal()` remain public with their status rules intact.

**W7-F3, M3 was not the smallest mutation.** Correct, and the correction is
recorded in `ws7_migration_evidence.md` section 5 with a three-row table. The
one-site mutation is the branch aborting; the two-site account applies only to
a reroute. A third mutation, a lowercase suffix, is detected only by the
frozen-body comparison, because the database re-parses the stored timestamp
and the hash re-derives its own canonical form. The positive block now also
asserts the stored instant.

**W7-F4, lane reason and clock reproduction.** The lane criterion is now
stated and applied in section 2, with the measured cost of the acceptance-suite
exception and the D5 questions for the four moved blocks. The clocks now name
a checked-in command.

**On the blind spot the review named.** It observed that a change zeroing
nonzero seconds in the ISO-Z branch would pass every literal in the matrix,
because they all end in `:00`. Correct. The matrix now carries ISO-Z, no-Z
and POSIXct literals ending in `:37`.
