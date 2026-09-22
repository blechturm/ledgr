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

## Re-review at 2b15563

**Mode and scope:** Type 1 re-review of workstream 9, with the requested
confirmation pass over workstream 7. The comparison base is `51a90ee`; the
reviewed tree is `2b15563`.

**Workstream 9 verdict: FAIL.** W9-F1 and W9-F4 are closed. W9-F2 is closed
for the canonical rule-1 bars and instrument columns, but its exhaustive hash
claim still omits the rule-2 quarantine path (W9-F5). W9-F3 pins its original
instrument-id example rather than the null-token rule across both CSV inputs
(W9-F6). The post-review `metadata` decision is right, but its failing case
does not pin the condition class (W9-F7).

**Workstream 7 confirmation:** all four patches are sufficient: the numeric
and factor rejection cases exercise the frozen and production bodies; the
contract clause and regenerated help describe the retained surface; the M3
table separates the one-site contract break from the two-site reroute; and
the lane criterion states, measures, and answers D5 for its acceptance-suite
exception.

### Patch disposition

| Prior finding | Re-review result |
| --- | --- |
| W9-F1, matrix failures | **Closed for the rows it enumerates.** The malformed-file cases bind the expected ledgr class and a stable, owned message fragment. The sniff-boundary case binds the ledgr class and the reader-stage prefix without pinning DuckDB's dependency-owned tail. The closeout's word `exact` is too strong; see W9-O3. |
| W9-F2, forced text and hashes | **Closed only for canonical rule-1 columns.** Mechanical schema/adapter enumeration gives the exact seven names now returned by `ledgr_csv_text_columns()`. Per-column old/new seals confirm the intended moves and the numeric exclusions. Quarantined original rows invalidate the broader “every persisted or hashed text” and moved-hash claims; see W9-F5. |
| W9-F3, null token | **Instance closed, defect not closed.** Empty and literal-`NA` bar instrument ids are pinned. The source and closeout state a general lexical rule, and the prior correction explicitly required both CSV inputs. Other forced text columns remain unpinned and have distinct consequences; see W9-F6. |
| W9-F4, clocks | **Closed.** `dev/bench/v0_2_0_2_ingestion/ingestion_clocks.R` is checked in, executable from the repository root, and builds its normalization inputs outside the clocks. I ran it successfully. On the current R 4.6.1 / DuckDB 1.5.2 installation it reported reader 0.22 s, `from_csv` 6.39 s, POSIXct `from_df` 6.69 s, and peer phase 7.18 s. |

### Forced set, derived and exercised

I parsed the two DDL blocks and mechanically extracted the adapter's
`bars_df$` and `instruments_df$` reads. Excluding generated
`snapshot_id`, the canonical source-derived partition is:

| Role | Columns |
| --- | --- |
| reader must leave as text for ledgr parsing or text persistence | `instrument_id`, `ts_utc`, `symbol`, `currency`, `asset_class`, `meta_json`; plus the `metadata` input alias |
| reader may infer numeric | `open`, `high`, `low`, `close`, `volume`, `multiplier`, `tick_size` |

That first row is identical to `ledgr_csv_text_columns()`. Old-reader versus
current-reader seals, one changed input column at a time, gave:

- leading-zero `instrument_id`, `symbol`, `currency`, `asset_class`,
  and `meta_json` preserve the lexical value now and move the rule-1 hash;
- valid `ts_utc` has identical persisted value and hash;
- `metadata=42` is identical; `metadata=0001` changes from silently sealed
  numeric JSON `1` to a loud invalid-JSON error;
- `multiplier=0002` and `tick_size=0000.05` have identical persisted
  doubles and hashes;
- each numeric bar column likewise has an identical persisted value and hash.

No member is missing from the canonical set and no included member should be
removed. That result does not make the cut's hash enumeration complete,
because `ledgr_availability_original_row_json()` consumes every column of a
quarantined bars row.

### W9-F5 - Gate: rule-2 quarantine hashes move outside the declared set

**What is wrong.** The closeout says the moved hash set is confined to
all-numeric leading-zero values in the seven forced text names. The source
has another persisted and hashed input family:
`snapshot_observation_quarantine.original_row_json` serializes every column
of an invalid bars row, including arbitrary extras. DuckDB changes both
inferred R types and colliding header names there.

**Evidence.** I sealed the same three-row file through the pre-swap reader
shape (including LDG-2788's canonical numeric coercion) and the current
reader, with one invalid OHLC row quarantined:

| Input shape | Old retained value | Current retained value | Hash |
| --- | --- | --- | --- |
| extra whole-number column `extra=1` | `"extra":1` | `"extra":1.0` | moved: `0699d35b...` to `35ad447f...` |
| extra leading-zero column `extra=0001` | `"extra":1` | `"extra":"0001"` | moved: `0699d35b...` to `4305e73c...` |
| extra literal `NA` | `"extra":null` | `"extra":"NA"` | moved: `0b335fd8...` to `612b5b59...` |
| duplicate `junk,junk` headers | two `junk` keys | `junk`, `junk_1` | moved: `3548b075...` to `04986fcc...` |
| `junk,JUNK` headers | `junk`, `JUNK` | `junk`, `JUNK_1` | moved: `e70df751...` to `9826a3fb...` |

The whole-number case is especially important: neither representation is a
corrupted leading-zero string, so the closeout's reason that every old moved
hash was wrong does not apply. The duplicate and case-only changes also mean
the retained field called `original_row_json` no longer carries the original
header spelling.

Quoted commas, quoted embedded newlines, values around `1e308` and
`1e-300`, overflow and underflow rejection/rounding, and a second seal from
the same path produced identical old/new public outcomes. Thus the observed
additional difference is localized to reader representation flowing into
quarantine, rather than a general CSV quoting or numeric defect.

**Smallest correction.** Extend the compatibility matrix and closeout to the
quarantine path before making another complete hash claim. Bind a treatment
for extra-column scalar types and for duplicate or case-colliding headers.
Rejecting colliding headers before snapshot creation is the smallest
fail-closed rule that avoids silently rewriting an “original” payload.
Whole-number and null extra fields need an explicit compatibility decision:
either normalize their quarantine representation independently of reader
types, or declare the additional rule-2 hash migration without claiming the
old value was corrupt. This identity decision is why the workstream remains
FAIL rather than passing on documentation alone.

### W9-F6 - Gate: the null-token witness covers only one forced text use

**What is wrong.** I accept the contract decision for an instrument id:
identifiers are opaque strings, `NA` is a real ticker, and CSV itself has no
standard null sentinel. Ledgr may define an empty field as missing and the
two-character token as data. The rationale should say this is ledgr's lexical
rule; “CSV says missing with an empty field” overstates the CSV standard.
The present test adequately pins that exact bars-`instrument_id` decision,
but the implementation comment and closeout state the rule generally and the
prior finding required both CSV inputs.

**Evidence.** Old/new public probes with literal `NA` showed:

- instruments `symbol`: rejected as missing before, accepted as `"NA"` now;
- `currency` and `asset_class`: stored missing before, stored `"NA"` now;
- `meta_json`: stored missing before, stored `"NA"` now;
- `metadata`: stored missing before, now rejects as invalid JSON;
- bars `ts_utc`: both reject with `ledgr_invalid_timestamp`, but with
  different messages because one input is missing and the other is text.

None is in the null-token test. The reader-shape block also does not enumerate
literal `NA` over the seven forced names.

**Smallest correction.** Make the null-token row table-driven over all seven
forced names in both CSV inputs, with each public outcome, stored value,
condition class/message, and hash consequence pinned. Amend sections 4 and 5
to name those consequences. Keep the accepted instrument-id rule.

### W9-F7 - Gate: the metadata rejection omits its condition class

**What is wrong.** I accept the `metadata` decision. That spelling already
routes through `canonical_json()`; JSON numbers cannot have leading zeros,
and letting the old reader turn `0001` into valid `1` was silent
corruption. The test is otherwise well chosen: it accepts `42` and an
object, rejects `0001` and `abc`, and distinguishes raw `meta_json`.
However, its `0001` failure asserts only the message fragment, while the
matrix and LDG-2800 require a class and message for each failing shape.

**Evidence.** The actual condition is
`ledgr_config_invalid_json, rlang_error, error, condition` with message
`canonical_json() received a character input that is not valid JSON.`.
The test's `expect_error()` has no `class` argument.

**Smallest correction.** Add
`class = "ledgr_config_invalid_json"` and retain the stable ledgr-owned
message expectation. The contract decision itself needs no change.

### W9-O3 - Message pinning uses the right stability boundary, but says otherwise

The strengthened matrix does not compare complete condition strings. It pins
ledgr-owned stable fragments with `fixed = TRUE`, and for the DuckDB
conversion failure pins only `Failed to read CSV`. That is the right trade:
full DuckDB diagnostics can drift with dependency versions and would create
false failures, while ledgr's wrapper stage and class should remain stable.
The test header and closeout call these “exact messages” and never state the
trade. Correct those descriptions to “stable ledgr-owned message or prefix”
and record that dependency-owned tails are deliberately excluded. This is an
observation because it matches the smallest correction requested in W9-F1
and does not weaken the executable oracle.

### Governance recommendation

Counting this re-review, cut 5 is **3 review invocations / 3 completed
tickets = 1.00**, above D8's 0.5 limit. The honest structural conclusion is
that a three-ticket cut which needs a cut review, a close review, and a
re-review should never have existed separately. Workstream 9 is a direct
continuation of workstream 7, depends on it, and changes the same CSV surface.

I recommend folding workstream 9 into cut 3 as its second workstream, giving
the stated combined count **4 / 9 = 0.44**, while retaining a durable note
that the original cut-5 shape reached 3 / 3 and prompted the correction.
The cost is a packet-topology patch to `tickets.yml`, README, and both
closeouts, plus care not to rewrite the actual chronology or present the
combined ratio as the ratio that guided the work at the time. Accepting the
breach instead preserves the current topology but records a D8 failure and
therefore triggers the synthesis's revise-or-abandon consequence. A silent
retroactive denominator change would be worse than either explicit choice.

### Re-review verification

Mechanically extracted schema columns and adapter reads; ran one-column
old/new sealing comparisons over every canonical bars and instrument input;
ran focused probes for both metadata spellings and literal `NA`; exercised
quoted commas, embedded newlines, duplicate and case-only header collisions,
large and small numerics, and a second call on the same path; and ran the
rule-2 quarantine comparisons reported in W9-F5. The focused
`csv-reader-compatibility|snapshot-timestamp-branches|snapshot-from-csv`
tests passed. The checked-in clock probe completed. Heavy was not run. Only
this section was appended; no source, test, ticket, closeout, stage, commit,
or push was changed.

## Review at ea227fa

**Mode and scope:** Type 1 review of the W9-F5 snapshot-identity change,
confirmation of the three prior patches, and confirmation of the cut fold.
The comparison base is `2b15563`; the reviewed tree is `ea227fa`.

**Verdict: PASS_AFTER_PATCHES.** The implementation is deterministic for
states produced by both ingestion surfaces, ignores extra columns without
losing any of the seven canonical bar values, and preserves the intended
tamper boundary. It does not fail closed when a quarantine saved row is valid
JSON of the wrong shape (W9-F8). Two statements added to the closeout are
also factually wrong or stale (W9-F9 and W9-F10).

### Determinism and retained identity

Repeated computation of one sealed snapshot returned one hash and matched
the stored hash. Repeated seals of the same file returned one hash, and a
close followed by `ledgr_snapshot_open(..., verify = TRUE)` succeeded with
that hash.

Exact duplicate invalid rows are rejected as
`ledgr_observation_quarantine_duplicate` before sealing. Two invalid rows
that differ only in an ignored extra column are admitted and can tie on all
five new ordering fields after projection. Their complete hashed rows are
then identical: `quarantine_id` and the differing extra value are the only
differences, and both have been removed. Reversing those rows produced the
same hash. The tie therefore has no unspecified-order consequence for the
payload.

The projected key set is the canonical bars set:
`instrument_id`, `ts_utc`, `open`, `high`, `low`, `close`, and optional
`volume`. I changed each field separately on an `ohlc_invalid` row while
keeping the same quarantine reason. Every change moved the hash. Changes to
`supplied_instrument_id`, `supplied_ts_utc`, `reason`, and `provenance_json`
also moved it.

### W9-F8 - Gate: a non-object saved row can seal without any bar value in identity

**What is wrong.** `ledgr_snapshot_quarantine_hashed_row()` returns the raw
string when parsed JSON is not a list. The seal validator checks that
`original_row_json` is canonical JSON, but it does not require a JSON object
or the canonical bar keys. Canonical scalars and arrays can therefore reach
the fallback or an empty projection. This violates property 3 for a state
that the seal boundary currently accepts.

**Evidence.** I replaced a quarantine row's saved object with the canonical
JSON scalar `42` and exercised the seal checks. `ledgr_snapshot_validate_availability_for_seal()`
returned successfully, `ledgr_snapshot_seal()` produced a `SEALED` snapshot,
and `ledgr_snapshot_validate()` then succeeded. The hash contained the raw
token `42` and none of the row's seven canonical bar fields. Direct helper
probes likewise returned raw `not-json`, `42`, and `null`; an empty JSON array
also passed the broad list test. The supported ingestion writers do emit
objects, but `ledgr_db_init()`, `ledgr_snapshot_create()`, and
`ledgr_snapshot_seal()` expose the lower-level store and seal boundary, so
the accepted state is reachable.

**Smallest correction.** Remove the raw fallback. Require
`original_row_json` to parse as a named JSON object with each of the six
required bar keys exactly once and optional `volume` at most once; abort with
the existing `ledgr_snapshot_fact_json_invalid` / `ledgr_invalid_state`
family otherwise. Apply the same shape check during seal validation, and add
scalar, array, malformed, and missing-required-key rejection cases. Extra
object keys should remain permitted and excluded from the hashed projection.

### W9-F9 - Gate record: the closeout gives W9-F5 two statuses

**What is wrong.** The opening status of `ingestion_reader_closeout.md` says
"W9-F5 is unresolved and is a maintainer decision." Section 10 says
"W9-F5 is resolved," and section 11 records its implementation. A closed
workstream cannot leave its gate finding in both states.

**Evidence.** Both statements are present in the reviewed file; the latter
matches commit `ea227fa` and the source change.

**Smallest correction.** Change the opening status to say that the second
FAIL was patched by the decisions and implementation recorded in sections
10 and 11.

### W9-F10 - Gate record: the duplicate-header correction describes the wrong old reader

**What is wrong.** Section 10 says the old reader renamed duplicate `junk`
headers to `junk.1` and calls the prior review's two-key result an error. The
old ledgr reader explicitly disabled that renaming.

**Evidence.** At `ac60941`, `ledgr_read_csv_strict()` called
`utils::read.csv(..., check.names = FALSE)`. Executing that call on
`instrument_id,junk,junk` returned names `instrument_id|junk|junk`; the
default `check.names = TRUE` call returned `instrument_id|junk|junk.1`.
Thus the prior review's two `junk` keys describe the actual old ledgr path,
and the closeout table and purported correction do not.

**Smallest correction.** Restore the old result to two `junk` keys and remove
the false correction. Retain the separate case-only observation and the
current DuckDB-renaming result.

### W9-O4 - The intended exclusion also excludes diagnostic spelling

Tamper detection is weaker exactly where the new identity rule makes the
saved copy diagnostic. A tamperer can change `quarantine_id`; add, remove,
rename, or change extra keys in `original_row_json`; or change the JSON's
lexical spelling while preserving the parsed retained values. In a probe,
adding surrounding whitespace to the stored JSON left the computed hash
unchanged and `ledgr_snapshot_validate()` still succeeded. Changes to every
canonical bar value and every other quarantine payload column moved the
hash. W9-F8 covers wrong JSON shapes, which are outside the intended
diagnostic exclusion and must fail closed.

### Prior patches and fold

All three prior patches are sufficient. The null-token block now exercises
`ts_utc` plus every forced instrument text name; the `metadata=0001`
rejection pins `ledgr_config_invalid_json`; and the matrix header accurately
describes stable ledgr-owned fragments and the DuckDB-tail trade. The complete
`test-csv-reader-compatibility.R` and `test-availability-facts.R` files passed.

The fold is bookkeeping only in implementation. `tickets.yml` assigns
workstreams 7 and 9 to cut 3, retains cut 5 as a folded record with its
historical 3 / 3, and computes the combined 4 / 9 = 0.44. No ticket body,
ticket completion state, or recorded measurement value was changed to obtain
that denominator. The closeout titles and cross-references were updated, and
the later measurement-method qualification was added without rewriting the
earlier measurements. W9-F9 and W9-F10 are closeout accuracy defects, not
runtime consequences of the fold.

### Verification

Inspected `2b15563..ea227fa` and the named source, tests, tickets, and
closeouts. Ran repeated-computation, repeated-seal, reopen-and-verify,
duplicate-invalid-row, reversed-tie, seven-field mutation, quarantine-column
tamper, JSON-shape, and reseal probes. Ran the complete focused compatibility
and availability-facts test files; both passed. Heavy was not run. Only this
review section was appended; no source, test, ticket, closeout, stage, commit,
or push was changed.
