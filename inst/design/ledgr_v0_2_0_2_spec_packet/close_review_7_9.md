# Type 1 Close Review: Workstreams 7 and 9

**Tree reviewed:** `51a90ee` on `v0.2.0.2`, 2026-09-22.  
**Scope:** LDG-2786 through LDG-2791 and LDG-2800 through LDG-2802.  
**Review mode:** Type 1, including the independent question whether the inputs and witnesses are right. This is a review artifact, not a change to either cut.

## Verdicts and gate

| Workstream | Verdict | D8 invocations / completed tickets | Gate |
| --- | --- | ---: | --- |
| 7, cut 3 | **PASS_AFTER_PATCHES** | 2 / 6 = **0.333** | Numerically within 0.5; closeout's 0.33 is correct. Findings W7-F1 through W7-F4 block acceptance. |
| 9, cut 5 | **FAIL** | 1 / 3 = **0.333** as recorded | Numerically within 0.5, so the closeout's 0.33 arithmetic is correct. The compressed cut review is rejected below; an independent cut review would make this 2 / 3 = **0.667**, above the gate. Findings W9-F1 through W9-F4 block acceptance. |

The ratio counts invocations, not the number of findings or correction rounds. The numeric D8 gate does not cure an unsupported compatibility or hash claim.

## Workstream 7: acceptance and findings

| Ticket | Acceptance at this tree |
| --- | --- |
| LDG-2786 | The 27-call migration, four deleted blocks, four additions, two-sided census, and absence of test references are recorded and consistent with the tree. M3's claimed minimum mutation is not established (W7-F3). |
| LDG-2787 | Both importers, their exports, and the five named helpers are gone; `ledgr_read_csv_strict()` has a caller; no importer reference remains in the ticket's specified source and documentation paths; `LEDGR_CSV_FORMAT_ERROR` is absent from `R/`. The public help and authoritative contract still describe removed behavior (W7-F2). |
| LDG-2788 | The signature, instruments-file metadata, quarantine parity witness, and source roxygen contract are present. The file and frame routes share `ledgr_snapshot_from_df()`. |
| LDG-2789 | The six producing branches, frozen pre-change body, literal branch outputs, and LTB-0018 hash pin are present. The specified non-time-column rejection is missing from the rejection matrix (W7-F1). The claimed end-to-end identity has the narrow blind spot described below. |
| LDG-2790 | The durable peer paths call `ledgr_snapshot_from_csv()`; the benchmark note discloses the changed phase definition and says promoted records were not edited. The closeout records a peer-fixture run and an unchanged hash. |
| LDG-2791 | The closeout names shipped scope, declined options, counters, before/after results, and the roadmap/horizon decision. Its release-shape and component clocks describe a scratch probe but do not give an executable reproduction command for each clock, as its acceptance and governance D4 require (W7-F4). |

### W7-F1 — Gate: the invalid timestamp matrix omits a required input

**Evidence.** LDG-2789 requires rejection class, message, and check order for an unsupported form **and a non-time column**, before and after. `test-snapshot-timestamp-branches.R` tests invalid character strings, missing character values, invalid Date/POSIXct values, and a missing bars column. It never supplies a numeric or other non-time `ts_utc` vector to the production and frozen bodies. The frozen body has an explicit final `else` for that path.

**Smallest correction.** Add one numeric `ts_utc` case with literal class and message expectations against both bodies, plus its order against the required-column check. Keep the existing six producing cases and pin.

### W7-F2 — Gate: removal left contradictory operative documentation

**Evidence.** The four deleted blocks are correctly characterized **for the removed importer**: two test import into a sealed snapshot, one tests CREATED instrument import and SEALED bar import, and one tests the old no-Z rejection. The no-Z case is replaced positively. `auto_generate_instruments = FALSE` has no kept file-surface equivalent and is explicitly declared removed. Yet `inst/design/contracts.md:507-510` still promises a low-level CSV create/import/seal workflow that survives reopen, and `man/ledgr_snapshot_from_csv.Rd` still says its low-level reader raises `LEDGR_CSV_FORMAT_ERROR`. Both statements are false at this tree. Public `ledgr_snapshot_create()` and `ledgr_snapshot_seal()` still expose CREATED and SEALED states, so the state vocabulary itself did not become unreachable; only the importer-specific mutation guard did. The remaining seal behavior has separate witnesses in `test-snapshots-seal.R`.

**Smallest correction.** Update the obsolete contract clause to the retained sealed `from_csv`/reopen workflow, preserving the still-live create/seal status rules, and regenerate the stale help page from its current roxygen. No importer or old error class needs restoration.

### W7-F3 — Gate: M3 is a detected mutation, but not the smallest one

**Evidence.** The twelve recorded mutations each report DETECTED, and M7 now pins the adapter's own duplicate-row message. That pin is necessary: deleting the adapter check otherwise reaches the database primary key and still produces a duplicate error of the same class. M3's two-site account is narrower than it says. A predicate change that *routes* an all-no-Z column to `ledgr_iso_utc()` is indeed masked by the fallback. But an error or a changed `ts_posix` in the already-selected all-no-Z branch of `ledgr_snapshot_normalize_ts_utc()` is a one-site change that breaks the positive block. The branch returns directly; the fallback is not run after it fails. Thus the reported two-site mutation proves branch redundancy under one particular reroute, not that two sites are required to break the contract.

**Smallest correction.** Record the one-site failing mutation for M3 and retain the two-site reroute as the distinct redundancy observation. M1, M2, M4-M6, and M8-M12 target one production decision each; no larger-than-needed change is evident in their recorded descriptions. M12 is historical to LDG-2788: LDG-2801 subsequently removed the coercion, while the current matrix pins the resulting numeric class.

### W7-F4 — Gate: lane reason and clock reproduction are incomplete

**Evidence.** Four sealing blocks in `test-snapshot-from-csv.R` moved from fast to review after the fast median crossed 90 seconds. The review lane runs at release, so this preserves execution. The stated rule that durable sealing belongs in review is not applied consistently: `AT2` and `AT3` in `test-acceptance-v0.1.1.R` still call `ledgr_snapshot_from_csv()`, seal durable files, and remain fast. Other fast seal tests remain in `test-snapshots-seal.R`. AT2 overlaps the rounding and missing-column blocks; AT3 overlaps generated-instrument coverage. The closeout does not answer the testing synthesis's D5 questions about this overlap and the cheapest adequate lane. Separately, LDG-2791 asks that each clock name a command, but the release-shape and component-clock sections say only “a scratch probe” and do not provide that command.

**Smallest correction.** State a consistent, testable lane criterion for the retained detecting blocks, adjudicate AT2/AT3 overlap against the moved blocks, and apply the criterion to those blocks. Add an executable command or checked-in probe path and invocation for the reported clocks. The measurements themselves need not be rerun merely to repair the record.

### Identity, names, and deletions

The LDG-2789 witness is adequate for the six exercised paths: the reference body is frozen, each producing path has an `identical()` comparison and a literal `ts_utc` expectation, fallback has literal `ts_posix`, rejection cases check class and message, and LTB-0018 pins one fixture through ISO-Z, date-only, and CSV routes. It is not exhaustive. A one-line change that zeroes **nonzero seconds only** in the ISO-Z branch's returned `ts_utc` would pass all those cases: their ISO-Z strings have seconds `00`, while the hash pin persists the separate parsed `ts_posix` value. A nonzero-seconds ISO-Z literal would close this blind spot. This is an observation about witness reach, not evidence of a present timestamp defect.

The one named-output difference is real and limited. The old fallback's `vapply()` named `ts_utc` with raw inputs, and `as.POSIXct()` carried those names into `ts_posix`; the new `USE.NAMES = FALSE` path returns unnamed vectors. The adapter uses `ts_utc` in `paste0(instrument_id, "\n", ts_utc)`, which drops names, and puts `ts_posix` in a data frame before database insertion. Neither name vector is read as data by those paths, and the pinned sealed hash is unchanged. The dedicated names block verifies this difference. No persisted value or hash dependence on those names was found.

## Workstream 9: acceptance and findings

| Ticket | Acceptance at this tree |
| --- | --- |
| LDG-2800 | A pre-swap test was committed, and it records the leading-zero instrument-id corruption. It does not record and assert every listed shape's outcome, class, and failure message as written (W9-F1), nor the metadata and NA-token shapes that plausibly diverge (W9-F2/W9-F3). |
| LDG-2801 | The reader uses `duckdb::read_csv_auto()`, forces the three named columns to VARCHAR, catches DuckDB failures as `ledgr_invalid_args`, removes the old numeric coercion, and has a release-shape clock. The leading-zero bar ID fix is correct: the old reader sealed `1` for `0001`; this one seals `0001`. LTB-0018 remains green. The claims that only one matrix shape and only one class of hash moved are false (W9-F2/W9-F3). |
| LDG-2802 | The closeout gives results, environment, before/after commits, and the cut-3 pointer, but omits an executable reproduction command for either clock (W9-F4) and omits the other moved hashes (W9-F2). The 0.33 arithmetic is correct only for the one recorded review invocation. |

`git diff a06100e a6ccb33 -- tests/testthat/test-csv-reader-compatibility.R` confirms that exactly one **registered expectation** changed: `c("1", "2")` became `c("0001", "0002")`. The fix is correct for a text instrument identifier. It does not establish that exactly one input behavior or hash family changed, because the matrix omitted the cases below.

### W9-F1 — Gate: the registered matrix is weaker than the ticket requires

**Evidence.** `test-csv-reader-compatibility.R` captures `csvc_seal_outcome()$msg` but never asserts it. Its six malformed cases accept either `ledgr_invalid_args` or `LEDGR_SNAPSHOT_EMPTY` without fixing which case gets which class; the reader helper likewise captures no failure message. Several successful shapes assert only one property (extra column present, first BOM name, or start date), rather than their full returned names and classes. Therefore a change to the specified message, class assignment, or another inferred class can pass. The known malformed-numeric-after-sniff-sample case is another distinct row: it fails as a DuckDB conversion error instead of ledgr's OHLC validation error, though both are `ledgr_invalid_args`.

**Smallest correction.** Make each listed shape a named, asserted result with exact stable class and message or stable message prefix at the public boundary, and assert the reader's returned names/classes where relevant. Add the out-of-sample numeric row with both its class and its distinct message stage. The message difference is acceptable as a documented reader consequence because both inputs reject with the contracted class; it must not be described as message parity.

### W9-F2 — Gate: the “only leading-zero instrument IDs move hashes” claim is false

**Evidence.** The matrix has no instruments-CSV metadata case. A small local reproduction used unchanged bars with instrument ID `AAA` and an instruments CSV with `symbol=0001`. The old-reader equivalent (`utils::read.csv()` followed by `ledgr_snapshot_from_df()`) sealed symbol `1`, hash `0ea4532b25a4896c501be129b44c6dc20e5a3fa2999ff0c9356a69ba9f2edfb6`. Current `ledgr_snapshot_from_csv()` sealed symbol `0001`, hash `1387b5f3c86c7e1b4e0648f09c055d8f01048999dde0661f175177b7b8bce1f2`. Bar IDs contain no leading zeros. The same probe, changing only `currency`, `asset_class`, or `meta_json` to `0001`, produced different old/new hashes in each case: old `read.csv()` inferred a number while DuckDB returned text, and `from_df()` persists their character forms. `symbol` is forced to text as intended; the other three are presently inferred. These accepted columns are part of rule-1 snapshot identity.

**Smallest correction.** Extend the matrix to both CSV inputs and all persisted text metadata columns; record each moved hash family and why the old value was wrong, then correct the closeout and horizon's overbroad “only” claim through the packet's normal decision record. Keep the chosen DuckDB reader. A policy for whether `currency`, `asset_class`, and `meta_json` should be forced to VARCHAR should be explicit before treating their inferred types as stable.

### W9-F3 — Gate: a changed accepted-input boundary is undeclared

**Evidence.** `utils::read.csv()` treats the literal field `NA` as missing; DuckDB's current forced VARCHAR identity read returns `"NA"`. In a local probe, a bars CSV with `instrument_id=NA` failed on the old path with “bars_df `instrument_id` must be non-empty strings.” Current `ledgr_snapshot_from_csv()` accepted and sealed one bar with ID `NA`. An instruments CSV `symbol=NA` likewise changes from missing (rejected by `from_df()`) to literal text (accepted). With `ts_utc=NA`, both paths reject as `ledgr_invalid_timestamp`, but the message changes because the old reader supplies a missing logical value and DuckDB supplies literal text. These are separate from the declared leading-zero repair and change the accepted domain or error message. The matrix has no NA-token row. The forced VARCHAR boundary is right for ID and timestamp ownership, but it is incomplete without an explicit null-token rule.

**Smallest correction.** Decide and pin the intended treatment of literal `NA` in both CSV inputs, then add reader and public-surface matrix cases and amend the compatibility closeout. Preserve ledgr's timestamp parser and the chosen DuckDB reader.

### W9-F4 — Gate: the closeout clocks lack reproduction commands

**Evidence.** LDG-2802 requires each clock to name commit, environment, command, and result. `ingestion_reader_closeout.md` names the first, second, and fourth, but supplies no executable command or checked-in probe invocation for the 4.91-to-0.26-second reader clock or the 10.72-to-7.23-second file-surface clock.

**Smallest correction.** Add the exact probe command or a checked-in probe path and invocation for both clocks. No new benchmark run is required merely to make the existing record reproducible.

### W9 observations

- **W9-O1, known sample boundary.** An invalid OHLC token within DuckDB's type sample reaches ledgr's finite-numeric validation; the same token beyond the sample reaches DuckDB's conversion error. Both are `ledgr_invalid_args`. The message difference is acceptable if explicitly recorded as in W9-F1; the second row is needed because error timing is part of this cut's compatibility question.
- **W9-O2, redundant seam.** `ledgr_csv_read_bars_for_snapshot()` is now a one-line call to `ledgr_read_csv_strict()`. Its temporary LDG-2800 role was useful before the swap; inline it into `ledgr_snapshot_from_csv()` and point the matrix at the reader/public boundary directly. This is a cleanup observation, not a gate condition.

## Compressed cut review

**Reject the compression.** The missing review was an independent question about **inputs**, before treating the fourteen-shape matrix as authority: does it include both the bars and instruments CSV, every persisted text field, null tokens, and the sample-dependent error boundary, and does it pin the error messages the ticket itself promises? This close review can identify those defects but cannot retroactively supply the pre-swap scope decision or establish the claim that only one row moved. A separate cut review at this point would add one invocation, producing 2/3 for cut 5 and missing D8's 0.5 gate; that process consequence should be recorded rather than hidden by the compressed 0.33.

## Verification

Read the named packet, authorities, contract, source, tests, and relevant commits. Ran the focused `testthat::test_local()` filter for `csv-reader-compatibility|snapshot-timestamp-branches|snapshot-from-csv`: all expectations passed, with two existing min/max warnings in the malformed-file block. Ran small in-memory reader and sealing probes for `NA` tokens and instrument metadata, including the hashes above. No heavy protocol was run. Only this review file was written; no implementation, ticket state, source, test, or promoted record was edited, staged, committed, or pushed.
