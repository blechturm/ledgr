# Workstream 29 Closeout: One Current Schema And One Store Gate

**Status:** Agent-provisional; awaiting independent Type 1 review and
maintainer adjudication of the ordinary fast-profile timing miss.
**Date:** 2026-10-13
**Baseline commit:** `24bcc161`
**Implementation range:** `24bcc161..48f447df`
**Tickets:** LDG-3024 through LDG-3027

## A. Claim And Boundary

Every package-owned persistent ledgr store is now created or opened through
one current schema, one marker-pair gate and one strict catalogue authority.
The current experiment-store schema is 119. There is no migration, legacy
reader, missing-marker fallback or compatibility argument.

The workstream changed four related boundaries in dependency order:

- LDG-3024 defines the current tables, columns, defaults, constraints and
  indexes once in `R/db-schema-current.R`;
- LDG-3025 binds schema 119 and its format fingerprint through
  `ledgr_store_open()` and `ledgr_store_assert_current()`;
- LDG-3026 routes every persistent connection family through that gate and
  deletes the legacy creation and upgrade layer; and
- LDG-3027 replaces the hand validator and saved-sweep allowlist with one
  strict normalized-catalogue comparison.

The workstream does not redesign the schema, change current result meaning or
provide backward compatibility. Workstream 30 owns deletion of remaining
record-level and public-call legacy branches.

## B. Ticket Commits

| Ticket | Commits | Result |
| --- | --- | --- |
| LDG-3024 | `6f426d46`, `eb638589` | one independent current-schema definition and recorded golden |
| LDG-3025 | `a265b6aa` | schema 119, typed marker-pair gate and transactional create |
| LDG-3026 | `0a3f2d29` | all persistent connection families gated; legacy schema machinery deleted |
| LDG-3027 | `73403097`, `7baa434f`, `93a63d59`, `48f447df` | strict catalogue validation, evidence corrections and profile alignment |

## C. Schema And Store-Gate Evidence

LTB-0258 / LCL-0256 renders the new definition into a fresh store and
compares it with a store built by the pre-cut path, closed and reopened before
comparison. The committed golden names baseline `24bcc161`, DuckDB
1.5.6.9000 and the following normalized population:

- 32 table rows;
- 2,058 ordered-column attribute rows;
- 378 constraint attribute rows; and
- 54 index attribute rows.

The index count was corrected after strict validation exposed that public
snapshot creation had added `idx_snapshot_bars_ts` outside the old schema
builder. The index now belongs to the sole current definition. A successfully
sealed public snapshot created at the pre-cut baseline has the corrected
golden's exact four digests.

LTB-0259 through LTB-0261 / LCL-0257 through LCL-0259 pin:

- the literal list and scalar types of the twenty format bindings;
- locale-independent radix serialization of the fingerprint payload;
- older, newer, missing, invalid and mismatched marker causes;
- the exact `ledgr_store_rebuild_required` condition family;
- empty-only creation and refusal of non-empty unmarked files;
- both markers as the final durable transaction step; and
- rollback after an injected creation failure.

No old timing or rule-3 constant alias survives. The newer-store condition is
folded into the closed rebuild-required vocabulary as the accepted synthesis
requires.

## D. Opener And Compatibility Census

LTB-0262 / LCL-0260 checks the source-derived opener boundary. The final
report at
`C:/Users/maxth/ledgr-research/.tmp/ws29-census-final` contains 69 connection
entries and zero ungated persistent-store findings. It includes path openers,
held and cached connections, caller-supplied connections, ATTACH, snapshot
adapters and hand-built run configurations.

The executable tree contains no legacy schema builder, experiment-store
migration or upgrade pass, lazy schema ensure helper, schema template, trigger
probe or tolerant diagnostic open. The low-level connection primitive remains
private beneath the two current-store gates. In-memory schema references and
non-store CSV parsing remain direct and classified.

The four creation-boundary claims were rewritten with LDG-3025. The blocks
that directly called deleted internals were rewritten with LDG-3026. The
registered suite remained green after each ticket rather than relying on a
later repair commit.

## E. Strict Catalogue Validation

LTB-0263 / LCL-0261 uses the same normalized catalogue for public validation,
the validation cache and saved-sweep compatibility. It detects:

- a missing table or column;
- an extra column;
- a changed default;
- a weakened CHECK constraint;
- a missing index; and
- a cache key that omits the index dimension.

Existing validator defect shapes retain their exact unclassed messages. New
default and index differences have pinned unclassed messages. A non-current
store refuses first at the marker-pair gate.

The current reference catalogue is rendered into an in-memory store once per
session. Successful fresh-store creation skips a redundant immediate
validation because the same exact DDL has just committed; later opens and the
public validator compare the full catalogue. Failures are never cached.

The registered cache mutation removed the index component from the key and
made two LTB-0263 assertions fail after same-path replacement.

## F. Exactness

The complete vendor-neutral fixture ladder compares `0a3f2d29` with
`73403097` under
`dev/bench/v0_2_2_real_data_scale/evidence/ladder22/`. It reports 51 of 51
families identical, including the identity family. The later commits change
only tests, census evidence and test-profile annotations.

The intended store-format changes landed earlier with LDG-3025: schema 119
and the format-fingerprint marker. Snapshot rows, roots and IDs, run configs,
ledger, fills, equity, positions, metrics and current public results remain
exact. No tolerance was added.

## G. Performance

The preregistered A/A record uses six pairs at `0a3f2d29`. Median B/A ratios
are 1.008 for open plus uncached validation, 0.984 for `ledgr_db_init()` and
1.021 for a small `ledgr_snapshot_from_df()`.

Three alternating candidate/pre-cut pairs then measured:

| Boundary | Candidate/pre-cut median ratio | Result |
| --- | ---: | --- |
| open plus uncached validation | 0.648 | PASS |
| `ledgr_db_init()` | 0.773 | PASS |
| small snapshot construction | 0.984 | PASS |

The raw record and method are in
`dev/bench/v0_2_2_pre_cran_removal/schema_validation/`. Package loading is
outside the clocks.

The ordinary fast lane is correctness-clean but does not meet its unchanged
112-second bound. The unpinned record at
`C:/Users/maxth/ledgr-research/.tmp/ws29-fast-48f447df` ran 562 of 562 blocks
three times in 118.04, 119.74 and 118.51 seconds, median 118.51. The controlled
P-core record at
`C:/Users/maxth/ledgr-research/.tmp/ws29-fast-pcores-48f447df` ran the same
562 blocks in 114.53, 114.16 and 114.28 seconds, median 114.28. Both gate
checks fail and are recorded as failures, not passes.

Against the accepted P-core WS28 retry, fast membership falls from 566 to 562
blocks. Twenty-two retired legacy and migration blocks with a 4.81-second
median sum are replaced by eighteen current-format blocks with a 1.52-second
sum, saving 3.29 seconds in the directly changed set. The two new fast opener
blocks account for about 0.18 seconds.

Common-block medians rose by about 5.46 seconds across unrelated files, while
the complete controlled lane nevertheless improved from the accepted WS28
retry median of 115.05 seconds to 114.28 seconds. Workstream 29 therefore
reduces the lane but does not erase its inherited miss. This evidence does not
authorize an exception; the maintainer must accept one or require a correction
after independent review.

## H. The Seven Shapes And Their Replacements

1. One-row frame per element, bound at the end: schema rows arise from a
   fixed 40-statement definition or four whole-catalogue queries, not data
   rows. Difference rows materialize once at the comparison boundary.
2. Full-table subset inside a loop over IDs: no changed function loops over
   instruments, events, facts, pulses or candidates. Catalogue grouping uses
   whole vectors and fixed schema objects.
3. Per-element parsing or formatting: the fingerprint serializes twenty
   fixed typed scalars once per process. No data-row parser or formatter was
   added.
4. Per-row JSON on repetitive strings: no product data collection is encoded
   row by row. The private fingerprint payload is fixed-size metadata.
5. Recomputed work: the format fingerprint and reference catalogue are each
   cached once per process. Fresh creation does not immediately re-read the
   catalogue it just created.
6. Quadratic validators: strict validation performs fixed catalogue queries,
   normalization and keyed comparison. It has no pairwise row scan.
7. Scalar writes into an environment-held vector: the caches assign one
   completed fingerprint or catalogue object; no scale-growing vector is
   mutated element by element.

The workstream removes scale-growing compatibility code rather than moving it
behind another helper. All new collections are bounded by schema size, not by
bars, facts, instruments, events, pulses, diagnostics or candidates.

## I. Verification And Review Boundary

Focused schema, store-gate, snapshot, sweep-persistence, connection,
control-plane and documentation suites pass. Lintr reports no finding on the
changed R and test files. `git diff --check` is clean. The source census, six
registered claims, failure-sensitive mutations, fixture ladder, A/A record,
paired clocks and both fast-profile records are available to the reviewer.

The Workstream 29 Type 1 review also confirms the Workstream 31 preparatory
checkpoint corrections recorded at `d85ec87e` and `a8416492`, as the packet
requires. It is the fourth Cut 14 review invocation. If it closes without a
correction review, accounting becomes 4/14 = 0.286 against the 0.5 gate.

No review result is claimed here. LDG-3027 and Workstream 29 remain
`review_pending` until the independent review and maintainer acceptance.
