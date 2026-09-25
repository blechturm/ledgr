# Workstream 14 Closeout: Fact-Family Scaling

**Status:** Agent-provisional; awaiting one Type 1 close review and maintainer
acceptance. **Tickets:** LDG-2821 through LDG-2823. **Baseline:** `af5bdc6`.

## What Shipped

Canonical fact preparation now converts each typed column once and writes one
set-wise JSON array. Family identity embeds those arrays without parsing them
back into one R object per row. Deduplication compares the same prepared typed
columns directly. Fact IDs supplied by an adapter keep their exact historical
hashes while avoiding the general config cache, which the registered profile
showed was material at 100,000 distinct identities.

Snapshot hash rule 2 uses the same renderer over its eight ordered persisted
tables. It still reads the actual rows from DuckDB on every seal, validation
and public run start. It does not trust the stored hash, a cached payload or a
persisted helper column. R still renders every byte that enters identity.

The public data-frame snapshot path now validates the facts bundle once and
passes a private validated value to ingest and persistence. Calling either
private boundary with an ordinary facts object still performs its own
assertion and rejects tampering.

No schema, hash-rule version, public API, family vocabulary, canonical byte,
condition contract or persisted representation changed. No Workstream 12
settlement behavior was implemented.

## Exact Identity And Negative Evidence

LCL-0035 through LCL-0038 register eight blocks.

| Claim | Blocks | Protected result |
| --- | --- | --- |
| LCL-0035 | LTB-0042 to LTB-0044 | exact family identity, duplicates and constructor error order |
| LCL-0036 | LTB-0045, LTB-0048, LTB-0049 | exact persisted identity, all-table corruption detection and order independence |
| LCL-0037 | LTB-0046 | fixed column-and-table rendering work across a tenfold row-count change |
| LCL-0038 | LTB-0047 | one full-path assertion and fail-closed standalone boundaries |

The five af5bdc6 family hashes, bundle hash and generated membership fact IDs
are literal expected values in LTB-0042. The rule-2 scale hashes are likewise
literal expected values in LTB-0045:

| Corporate-action rows | Frozen rule-2 snapshot hash |
| ---: | --- |
| 0 | `d148f57b818a615db3cb9a1a4ae78db9b972b537ba20e1528dbc5c3596b088f9` |
| 20,000 | `5f612f017cfefcb503833342acb1082e9c8ca5cfe3ad05f2bb029c474fa26148` |
| 100,000 | `d03a9d7f7faac4d87de0d421c92f4afaf23c7795049e5084abb739032a00fe68` |

The complete six-input matrix, including one quarantined observation, retains
`c4b2aea914f46e4ff97b6eead3fe7a42d618f56a8e948b4f256ab5cd03e4aa85`.
Compatible duplicates retain the first row. Every identity-bearing family
keeps its exact incompatible-duplicate class, message and `fact_ids` field.
Membership, status and lifetime still reject invalid intervals before shared
deduplication. Corporate actions retain their pre-existing explicit-ID
uniqueness check, and sessions retain their duplicate-date check.

LTB-0048 independently changes one hashed value in each of
`snapshot_fact_families`, `snapshot_membership_sets`, `snapshot_membership`,
`snapshot_trading_status`, `snapshot_lifetime`,
`snapshot_equity_corporate_actions`, `snapshot_sessions` and
`snapshot_observation_quarantine`. The stored hash is left untouched. Every
public `ledgr_run()` rejects with `LEDGR_SNAPSHOT_CORRUPTED`. LTB-0049 deletes
and reinserts every table in reverse physical order; the recomputed identity
and public validation remain unchanged.

## Failure Sensitivity

Four isolated guts were run against `d93314e`, then discarded.

- Restoring one row slice and `ledgr_fact_row_payload()` call per family row
  made LTB-0043 fail twice: observed calls became 20 and 200 instead of zero
  and the tenfold counts no longer matched.
- Omitting `snapshot_lifetime` from rule-2 identity made exactly its LTB-0048
  public-run mutation escape; the other seven table mutations still failed.
- Passing the raw bundle from the public adapter to ingest and persistence
  changed LTB-0047's assertion count from one to three and failed it.
- Removing persisted-table `ORDER BY` keys made LTB-0049 produce two failures:
  the hash moved after reverse insertion and snapshot validation rejected it.

These guts cover the old preparation shape, omission from identity, repeated
validation and physical-order dependence. Frozen literal hashes separately
detect any byte-level identity drift.

## Registered Performance Record

The runner is `dev/bench/workstream14_fact_scaling.R`; the raw record is
`dev/bench/results/workstream14_fact_scaling_20260925.csv`. R 4.6.1 ran three
repetitions with arm order alternated between the detached `af5bdc6` worktree
and the exact implementation. Every public run reached `DONE`, and hashes
matched between arms in every repetition.

Constructor is a cold in-memory fact construction clock. Seal is a cold
`ledgr_snapshot_from_df()` clock with the already-built facts supplied, so it
does not include constructor time. Run is the complete warm `ledgr_run()` call
over the reused sealed snapshot. These three clocks are separate boundaries
and are not summed. `-1` means a genuinely fact-free rule-1 control; zero in
the identity table above means rule 2 with sessions and no corporate actions.

| Rows | Arm | Constructor runs | Seal runs | Public-run runs |
| ---: | --- | --- | --- | --- |
| no facts | before | 0 / 0 / 0 | 0.67 / 0.67 / 0.69 | 1.82 / 1.79 / 1.78 |
| no facts | after | 0 / 0 / 0 | 0.58 / 0.61 / 0.58 | 1.39 / 1.37 / 1.38 |
| 20,000 | before | 16.98 / 17.01 / 16.91 | 22.83 / 22.95 / 22.67 | 5.98 / 6.07 / 6.00 |
| 20,000 | after | 2.20 / 2.21 / 2.20 | 2.34 / 2.32 / 2.31 | 2.80 / 2.81 / 2.81 |
| 100,000 | before | 95.93 / 94.51 / 95.99 | 110.08 / 110.44 / 111.75 | 18.61 / 18.97 / 19.11 |
| 100,000 | after | 9.01 / 9.09 / 9.08 | 7.40 / 7.40 / 7.60 | 4.61 / 4.67 / 4.64 |

All values are seconds. At 100,000 rows, median construction is 95.93 versus
9.08 seconds, 10.56 times faster. Median seal is 110.44 versus 7.40 seconds,
14.92 times faster. The fact-attributable public-run overhead is the populated
median minus the same arm's no-fact median: 17.18 seconds before and 3.26
after, 5.27 times faster. The three binding ceilings therefore pass:

- construction 9.08 <= 95.93 / 10;
- seal 7.40 <= 110.44 / 10;
- run-start fact overhead 3.26 <= 17.18 / 5.

The no-fact run moved from 1.79 to 1.38 seconds across commits that include the
independent Workstream 13 schema optimization. The fact-overhead comparison
subtracts each arm's own control, so that separate gain is not attributed to
Workstream 14. The raw whole-call clocks remain reported and are not replaced
by the subtraction.

The final exact-tree fast gate record is `.tmp/ws14-close-fast-final`. It
passed 451 of 451 blocks in 78.630 seconds, and the ordinary gate passed
against the 90-second one-run bound. The LDG-2822 gate separately passed 451
of 451 blocks in 73.390 seconds. The full Workstream 14 file, including all
review blocks and the 100,000-row identity witness, passed before closeout.

An earlier exact-tree attempt wrote through an elevated filesystem execution
context and produced three all-green records at 97.31, 94.56 and 96.85 seconds;
their median failed the timing gate. The slowdown was suite-wide rather than
concentrated in Workstream 14: block-time totals were 91.98 to 94.32 seconds,
versus 71.07 in the LDG-2822 record. Repeating the unchanged tree in the
ordinary execution context produced the binding 78.630-second record above.
Both outcomes are disclosed; no threshold or test assignment changed.

## Seven-Shape Audit And Declined Work

The changed preparation path has one loop over columns and one over the fixed
eight-table map. JSON receives one typed frame per family or table. Timestamp
formatting is vectorized once per timestamp column. There is no one-row frame,
row-wise JSON, growing-vector append, pairwise validator, or work computed and
discarded.

`ledgr_fact_ids()` necessarily retains one SHA-256 per distinct fact identity;
the supplied-ID branch no longer performs the second cache-key digest or a row
slice. Provenance normalization retains one encoding per distinct source row
because provenance is itself a per-fact identity input. Quarantine projection
retains one parse per quarantined row because each saved JSON object has to be
validated and reduced to canonical bar keys. Both are linear, materially below
the registered ceilings and not nested inside another data-scale loop.

Declined: changing schemas or hash versions; DuckDB-side JSON rendering;
persisted canonical helper columns; treating a stored hash as proof of rows;
an O(1) open cache; weakening any validator; changing public or error
contracts; and implementing disposition, composition or recovery from
Workstream 12.

Workstream 10's bars-only performance clock did not measure construction,
seal or run startup with the populated fact family. That review miss remains
recorded rather than being rewritten as prior coverage.

## Governance

The accepted amendment accidentally carried LDG-2821 as `review_pending` and
LDG-2822 as `complete` before either implementation existed. The LDG-2821
commit corrected both status fields, then each ticket was marked complete only
with its own evidence. Those inherited labels are not treated as evidence.

Six reviews covered the original fifteen cut-6 tickets. The amendment ticket
review is the seventh invocation against eighteen active tickets. This close
review will be the eighth; the planned Workstream 12 review will be the ninth.
The projected final ratio remains 9/18 = 0.500. A correction round would exceed
the gate and must be recorded rather than hidden.
