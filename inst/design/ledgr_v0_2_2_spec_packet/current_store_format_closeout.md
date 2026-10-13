# Workstream 29 Closeout: One Current Schema And One Store Gate

**Status:** Agent-provisional after close-review corrections; awaiting focused
Type 1 re-review and maintainer adjudication of the cold-open clock.
**Date:** 2026-10-13
**Baseline commit:** `24bcc161`
**Implementation and correction range:** `24bcc161..0699ba3c`
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
| Review corrections | `1377977d`, `d68aae4b`, `0699ba3c` | split-store repair, full golden rows, stronger detectors and corrected evidence |

## C. Schema And Store-Gate Evidence

LTB-0258 / LCL-0256 renders the new definition into a fresh store and compares
it row by row with a committed normalized fixture built by the pre-cut path,
closed and reopened before normalization. The fixture names baseline
`24bcc161`, DuckDB 1.5.6.9000 and this population:

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
- rollback after injected DDL failure and rejection of the actual
  format-fingerprint insert.

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
original commits did not leave every registered route green: the split-store
result-reader regression and the frozen schema-118 witness were corrected at
`1377977d`. This closeout does not claim otherwise.

## E. Strict Catalogue Validation

LTB-0263 / LCL-0261 uses the same normalized catalogue for public validation,
the validation cache and saved-sweep compatibility. It detects:

- a missing table or column;
- an extra column;
- a changed default;
- a weakened CHECK constraint;
- a missing index; and
- a cache signature that omits the index dimension.

Existing validator defect shapes retain their exact unclassed messages. New
default and index differences have pinned unclassed messages. A non-current
store refuses first at the marker-pair gate.

The current reference catalogue is rendered into an in-memory store once per
session. A successful validation caches a single DuckDB-side signature over
the current database's complete table DDL and index DDL; cache misses compare
the full normalized catalogue. Successful fresh-store creation skips a
redundant immediate validation because the same exact DDL has just committed.
Failures are never cached.

The registered cache mutation removed the index component from the key and
made two LTB-0263 assertions fail after same-path replacement.

## F. Exactness

The reconstructed per-ticket ladder is under
`dev/bench/v0_2_2_real_data_scale/evidence/ladder23/`. At LDG-3025, 49 of 51
families and the identity family are byte-identical; the only two differences
are the declared `schema_version` move from 118 to 119 in the momentum and
equal-weight run-information families. LDG-3026 is then 51 of 51 identical,
and the correction implementation at `1377977d` is 51 of 51 identical to
LDG-3026. Ladder22 separately records 51 of 51 exact for LDG-3027.

The intended store-format changes landed earlier with LDG-3025: schema 119
and the format-fingerprint marker. Snapshot rows, roots and IDs, run configs,
ledger, fills, equity, positions, metrics and current public results remain
exact. No tolerance was added.

## G. Performance

The original A/A and candidate records compared against `0a3f2d29`, after the
store gate had already landed. They remain historical evidence but are not a
pre-cut effect estimate. The correction record uses the actual Workstream 29
baseline `24bcc161` and five alternating fresh processes:

| Boundary | Pre-cut median | Candidate median | Ratio | Result |
| --- | ---: | ---: | ---: | --- |
| cold open plus close | 0.02429 s | 0.03672 s | 1.512 | MISS |
| primed open plus validation | 0.02724 s | 0.02360 s | 0.866 | PASS |
| validation-cache hit | 0.00349 s | 0.00299 s | 0.856 | PASS |
| existing-store `ledgr_db_init()` | 0.02885 s | 0.03009 s | 1.043 | PASS |
| five-row snapshot build | 0.19420 s | 0.19190 s | 0.988 | PASS |

The cold opener adds one mandatory marker query to a pre-cut path that did not
verify a store. Its 12.43 ms median increase is recorded as a miss under the
reviewer's expanded 1.05 comparison, not hidden in package loading. The other
four boundaries meet the rule. The raw record and method are in
`dev/bench/v0_2_2_pre_cran_removal/schema_validation/`.

The correction fast record at `.tmp/ws29-correction-fast` ran all 562 blocks
three times in 107.03, 105.96 and 108.04 seconds. Its 107.03-second median
passes the unchanged 112-second gate. The successful review record at
`.tmp/ws29-correction-review-r3` ran all 336 review blocks in 290.18 seconds
with one pre-existing optional-path skip. Two earlier review attempts are not
evidence: both stopped in the peer benchmark because its fresh child selected
an older DuckDB from the user profile. The successful record pins the required
1.5.6.9000 library for parent and child processes.

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
   cached once per process. A validation call makes one fixed-schema
   table/index signature query; only a changed signature triggers full
   normalization. Fresh creation does not re-read its just-committed schema.
6. Quadratic validators: strict validation performs fixed catalogue queries,
   normalization and keyed comparison. It has no pairwise row scan.
7. Scalar writes into an environment-held vector: the caches assign one
   completed fingerprint or catalogue object; no scale-growing vector is
   mutated element by element.

The workstream removes scale-growing compatibility code rather than moving it
behind another helper. All new collections are bounded by schema size, not by
bars, facts, instruments, events, pulses, diagnostics or candidates.

## I. Verification And Review Boundary

Focused schema, store-gate, snapshot-verification and frozen-witness suites
pass. The ordinary fast and review profiles pass as recorded above. The
fingerprint-write, held-connection, ungated-ATTACH, attached-catalogue and
named-type mutations each fail their owning block. `git diff --check` is
clean. The source census, six registered claims, full row golden, per-ticket
fixture ladder and corrected paired clocks are available to the reviewer.

The Workstream 29 Type 1 review also confirms the Workstream 31 preparatory
checkpoint corrections recorded at `d85ec87e` and `a8416492`, as the packet
requires. The close review was invocation four. The requested focused
re-review is invocation five, making 5/14 = 0.357 against the 0.5 gate; the
planned Workstream 30 and 31 close reviews would bring the cut to 7/14 = 0.5.

No re-review result is claimed here. LDG-3027 and Workstream 29 remain
`review_pending` until focused independent review and maintainer acceptance.
