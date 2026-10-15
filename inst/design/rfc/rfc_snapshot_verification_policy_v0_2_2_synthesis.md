# Synthesis: Snapshot Verification Policy For v0.2.2

Role: record; amended RFC-cycle synthesis and durable decision record.
Status: amended 2026-10-13
Authority: accepted synthesis as amended; binds only its stated scope.
Amendments: 2026-10-13 [pre-CRAN legacy removal](rfc_pre_cran_legacy_removal_v0_2_2_synthesis.md) replaced the temporary legacy-readability boundary.

**Status:** Accepted by the maintainer on 2026-10-12 after Codex's Type 1
final review returned PASS_AFTER_PATCHES and all three patches were applied.
Binding for WS5-A; implements as two ordered direct tickets; no further RFC.
**Author/date:** Claude (Fable 5.1), 2026-10-12. Author of the Type 2
response and the seed-v2 review; not author of either seed.
**Inputs:** seed v1, the response and its review, seed v2 as revised
2026-10-12 and its review, the rule-3 conformance spike (charter, closeout,
inventory, recorded evidence), the cited `contracts.md` clauses, macro plan
WS5, `rfc_cycle.md`, `spike_protocol.md`, and the cited production code.
**Baseline:** `a90f372a`; every cited production path is unchanged since
`1c8df889` except one comment in `R/derived-state.R`.

This RFC uses "v1" as shorthand for the first implementation of this
verification policy; ledgr's roadmap has no verification v1 milestone.
Post-v1 work lives in the obligations of Section 9 at their own windows.

## 1. Decision

- **D1. Rule 3 is bound as the exact bytes of seed v2 Section 5** (5.1 to
  5.4, revision of 2026-10-12): R-owned, column-major 10,000-row blocks,
  presence byte on every field, little-endian fixed widths, signed 64-bit
  whole-second timestamps, `round(x, 8)` doubles with negative zero folded,
  bytewise ordering asserted by the encoder, the fact record bound by
  reference to `ledgr_snapshot_availability_hash_payload()` with its three
  named changes, and the domain-separated block, section and root digests.
  The spike's ten recorded roots become pinned fixtures; the production
  encoder must reproduce them on both CI platforms.
- **D2. The proof carrier is a private process-local verified set.** The
  review's held-store, call-scoped alternative loses (Section 4 states why).
  This is decided here on the merits; it is not promoted to the maintainer.
- **D3. Key, population, invalidation and generation** are bound in 3.2:
  key = snapshot store key + snapshot id + stored root + rule, under a
  process generation checked by PID on every lookup; populated only by a
  committed seal or a successful complete recomputation; cleared per entry
  on any failed check; never serialized; `:memory:` never entered.
- **D4. Three read classes** (3.4): metadata-only reads need no proof and
  claim none; durable-result-only reads need no snapshot proof; every read
  whose output depends on snapshot rows ensures the set first. Aggregates
  (counts, timestamp ranges) are metadata; row values are not.
- **D5. Compatibility (amended by the accepted pre-CRAN legacy-removal
  synthesis):** the store gate refuses any non-current store before a snapshot
  row is read. Inside a current store, the rule marker is mandatory and only
  rule 3 is valid; no migration, legacy reader or missing-marker fallback.
- **D6. UX:** `verify = FALSE` opens metadata; the first trust-bearing use
  verifies cold; `verify = TRUE` and `ledgr_snapshot_validate()` always
  recompute; no public trust, scope or skip switch; snapshot information
  reports root, rule and current-process verified state.
- **D7. Sequence:** ticket 1 implements rule 3 and keeps every current
  complete-verification call; ticket 2 adds the verified set from a
  source-derived consumer census. Each is independently reviewable.
- **D8. Gates** (Section 6) are retained by the ticket cut as written.
- **D9. Scope:** WS5-A only. WS5-B, DuckDB placement, the retained
  fact-projection memory and the `ledgr_sweep_open()` universe read are
  obligations in Section 9, not decisions here.

## 2. Executed Evidence And Its Limits

The conformance spike closed GREEN and reran through its checker on Windows
and Ubuntu. Charter and closeout live under
`inst/design/spikes/snapshot_hash_rule_3_conformance_spike/`; the harness
and recorded CSVs under `dev/spikes/snapshot_hash_rule_3_conformance/`.

| Evidence | Windows | Ubuntu |
| --- | ---: | ---: |
| Ten deterministic case roots | identical | identical |
| Insertion order, fetch size, DuckDB threads, 10,000-row boundary | root unchanged | root unchanged |
| Covered-value mutation (`close` + 0.01) | root changed | root changed |
| Hostile instrument order | refused | refused |
| Gut (order assertion disabled) | detected by checker | detected by checker |
| Encoder median, 5M bars, one thread | 0.676 us/bar | 0.999 us/bar |
| Endpoint growth exponent, 0.5M to 5M | 1.038 | 1.001 |
| Peak RSS, 5M-bar streaming path | 149 MB | 130 MB |
| Retained 300,000-row fact projection | 65.7 MB JSON, 418 MB peak | 65.7 MB JSON, 474 MB peak |

Supporting measurements from the response stage, not the spike: the current
text hash costs about 10.3 us per bar (56.6 s at 5.5M rows), retrieval alone
about 0.15 us per row, and at the peer shape (630,000 bars) the current hash
is 5.3 s against 0.4 s; the rehash note records 55 s per Sharadar run.

Limits. The spike validates bytes, portability, cost shape and block
boundedness of a scratch encoder over scratch retrieval. It does not
validate production seal or guard integration, the complete read-surface
census, old-rule refusal, verified-set invalidation, or the fact-projection
memory at a full production population. Ubuntu's encoder median sits at the
1 us limit, so a production gate that includes retrieval must be wider than
the spike's encoder-only gate (Section 6).

## 3. Bound Architecture

### 3.1 Rule 3

Seed v2 Section 5 is the normative byte definition and is copied into the
Snapshot Contract at ticket cut without reinterpretation. Four properties
carry the weight. Identity is defined and computed in R; DuckDB retrieves
and orders rows but never defines a byte, and the encoder refuses a stream
whose composite keys are not strictly increasing by radix order. Blocks are
fixed logical units, so fetch chunking, thread count and cadence cannot
move the root, and the bar path retains at most one block. The fact record
is the existing exact projection with byte ordering and a new label, so its
exactness evidence from the Cut 3 spike carries over and its textual
double identity is admitted. The rule number is inside the root, and the
marker column records it; the pair is the hash-rule version.

### 3.2 The verified set

A namespace-private environment holds one generation record (PID and an
opaque nonce) and entries keyed by the snapshot store key, snapshot id,
stored root and rule. The store key is `ledgr_store_key()` of the snapshot
store (`R/snapshot.R:98-104`); in split mode that is `snapshot_db_path`
(`R/run-prepare.R:68-69`), never the run store; a `NULL` key (`:memory:`)
is never entered. Every lookup first compares `Sys.getpid()` with the
generation; a mismatch discards all entries and starts a new generation.

Population: `ledgr_snapshot_seal()` inserts after its in-transaction
`SEALED` check passes and its `COMMIT` returns (`R/snapshots-seal.R:160-202`),
using the root it computed inside the transaction; a complete recomputation
that equals the stored root inserts; nothing else does. Adapters that seal
through a raw connection register from the connection's store path.

Ensure: a content-consuming call reads status, root and rule from the
`snapshots` row, refuses if the status is not `SEALED` or the rule is not
3, looks the tuple up, and recomputes on a miss. A hit performs no row
read for proof. A failed recomputation or a failed status check removes
the entry and fails closed with the existing corruption class.

Invalidation: entry removal on failure; whole-set reset on generation
change; nothing else. Locator close, connection close and object copies
do not touch the set. The set is never written to a locator, config,
experiment, result, worker payload or store.

### 3.3 Trust boundary

The proof covers corruption present when it was established and every
mutation reachable through supported ledgr APIs, none of which mutates
sealed rows: sealing requires `CREATED` (`R/snapshots-seal.R:107`), and
schema migrations add columns to `snapshot_*` tables without rewriting rows
(`R/db-schema-create.R:465-487`). After proof, an ordinary ensure rechecks
only status, root and rule. A row mutation by any process that preserves
those three is undetected until `ledgr_snapshot_validate()`, an eager open,
or a new process verifies completely. No cross-call DuckDB lock is claimed:
`ledgr_snapshot_hold()` releases the connection after each public call
(`R/snapshot.R:159-172`). Raw DBI writes and external mutation after proof
are outside the contract and the contract text says so.

### 3.4 Read classes

| Class | Rule | Examples at baseline |
| --- | --- | --- |
| 1 Metadata only | reads status, root, rule, counts and timestamp ranges cold; never claims rows verified | `ledgr_snapshot_info()`, `ledgr_snapshot_list()` |
| 2 Durable result only | reads run-store rows and compares the stored root to the recorded one; no snapshot proof | `ledgr_run_open()`, `ledgr_walk_forward_open()`, `ledgr_candidate()`, `ledgr_sweep_save()` (`R/sweep-persistence.R:389`) |
| 3 Snapshot dependent | ensures the set before rows affect execution, identity, metrics, marks, reports or returned data | `ledgr_experiment()` (`R/experiment.R:371`), run, resume, promotion, precompute, sweep evaluation (`R/sweep.R:224`), walk-forward, `ledgr_sweep_open()` (`:98`), facts and quarantine inspection, derived-state recovery, `summary()`/`print()` of a backtest through corporate-action and availability readers (`R/backtest-results.R:723`, `R/availability-results.R:435`), `summary()` of a snapshot (returns `instrument_id` values from bars, `R/snapshot.R:327`), `ledgr_pulse_snapshot()`, `ledgr_indicator_dev()`, `ledgr_feature_contract_check()` |

The classification is semantic; ticket 2 derives the census from source
(every reader of a `snapshot_*` table and its enclosing public entry), not
from this table. A stored-root comparison never stands in for proof when
rows are about to affect an output. Verification happens once per outer
sweep or walk-forward call; each fold's guard hits the entry the outer
call established. The first class-3 call in a process, usually
`ledgr_experiment()`, pays the cold verification.

### 3.5 Compatibility

`hash_rule_version` becomes mandatory on `SEALED` rows written by rule 3.
The accepted pre-CRAN legacy-removal synthesis supersedes this section's
temporary readability boundary at its Cut 14 ticket cut. A store whose schema
marker and format fingerprint are not current refuses before metadata or row
reads. Within a current store, a missing snapshot rule or any value other than
3 is invalid stored evidence and refuses; no rule-1 or rule-2 reader or encoder
remains executable.
Package fixtures are rebuilt from source at test time; the LTB-0018 literal
is re-pinned to the rule-3 root by decision; identity rule 2 already folds
the root into `config_hash` and `session_id`, so run and session identity
fork as the contracts foresee. Legacy run and sweep rows are unreachable after
the store gate; current rows retain the three read classes from Section 3.4.
The Sharadar lake is rebuilt in ledgr-research after the removal cut under
rule 3 without dividends, and that cut records the rebuild time.

### 3.6 UX

Unchanged from seed v2 Section 8. Snapshot information gains the stored
rule and a current-process verified flag; durable provenance records root
and rule only. No progress message is bound; ticket 1 may add one only if
its end-to-end clocks show a pause that needs explaining.

## 4. Rejected, One Line Each

- DuckDB-computed typed text: no R oracle, 7.1 s against 2.6 s at 5.5M rows
  on one thread, and the migration the parked placement RFC gates.
- Locator-scoped lease: the guard never receives the locator, adapters build
  fresh locators, and the state environment survives `saveRDS()`.
- Held-store, call-scoped proof: simpler and covers the walk-forward, but
  `ledgr_run()` holds nothing today and every later public call, including
  `ledgr_experiment()`, each `ledgr_run()` and each `summary()` on a
  Sharadar-scale snapshot, would pay 5 to 7 s again; recovering that needs a
  durable rewrite of every class-3 reader, which is larger than one
  PID-guarded environment. Equal safety, worse UX, more code.
- Stored component hashes or a Merkle tree: no supported path needs a subset
  proof after a complete one (B5 upheld).
- Live row counts as guarantee: data-scale work on every warm lookup that
  detects only insertion and deletion.
- Row-major record framing: 0.96 us per row with no gate margin against
  0.32 column-major.
- A public trust, scope or skip switch; an annual rehash cadence; a second
  canonicalizer; DuckDB-owned identity: none demonstrated necessary.
- In-place migration of old roots: blurs two content contracts.

## 5. Contract Changes Authorized By Acceptance

Applied at ticket cut, not before implementation:

- Snapshot Contract: replace the rule-1/rule-2 coverage and missing-marker
  clauses with rule 3 (bytes by reference to seed v2 Section 5), the
  mandatory marker and the legacy refusal; keep the POSIXct input clause;
  rewrite the `verify = TRUE` clause as eager complete verification; add a
  clause distinguishing content identity, complete verification, a
  current-process verified entry and possession of a stored root; rewrite
  the split-store clause to ensure keyed by the snapshot store.
- Execution Contract: "committed runs recompute and compare the sealed
  snapshot hash" becomes "committed runs ensure a current-process verified
  entry for the snapshot; a miss recomputes completely"; sweep evaluation
  ensures once before reading bars and still carries the stored root.
- Availability Contract: facts inspection "verify sealed state and artifact
  hash on every call" (`contracts.md:597`) becomes an ensure.
- Persistence Contract: derived-state reconstruction ensures; "existing
  sealed snapshots retain their stored hashes and are never resealed"
  stays. The later pre-CRAN store gate makes non-current stores unreachable.
- Verification Contract: the fold-core guard regression clause stays; add
  that the production encoder reproduces the spike's golden roots on both
  CI platforms.

## 6. Implementation Sequence And Detecting Gates

**Ticket 1, rule 3.** Replace the encoder in `ledgr_snapshot_hash()`
(`R/snapshots-hash.R`), bind the marker, refuse legacy rules, fix every
R-side `order()` on the fact path to radix, and leave every current
complete-verification call in place: seal (`R/snapshots-seal.R:164`), the
run guard (`R/run-snapshot.R:55`), open with verify, facts inspection
(`R/availability-inspection.R:292`), reconstruction (`R/derived-state.R:60`)
and `ledgr_snapshot_validate()`. Coverage is unchanged; only cost moves.

**Ticket 2, verified set.** Add the set, the ensure helper and the
source-derived census; replace each full recomputation listed above with an
ensure except explicit validation and eager open; change `ledgr_backtest()`
from forced validation (`R/backtest.R:153`) to an ensure; add ensures to
class-3 readers the census finds without one. Frequency changes; coverage
does not.

Detecting gates, retained by the cut:

1. Golden roots: the ten spike roots reproduce through production seal on
   ubuntu-latest and windows-latest; the fixture is the recorded `cases.csv`.
2. Failure sensitivity: a covered-value mutation moves the root and refuses
   at the guard; a hostile-order stream refuses at seal; disabling the order
   assertion is caught by the golden fixture.
3. Cost, on the registered one-thread benchmark host of the WS8 regression
   suite, not hosted CI, whose timing the macro plan calls too noisy to gate
   on: complete verification of the bar population (instruments and bars,
   encoder plus retrieval) at most 1.5 us per bar, with the encoder share
   reported against the spike's 0.68 and 1.00; endpoint growth exponent at
   most 1.10 over 0.5M, 1M, 2M and 5M bars; the fact projection timed
   separately on the fixed 300,000-row fact fixture and at the Sharadar
   population. CI runs the golden-root checks only; its clocks are advisory.
4. Memory: the bar path retains at most one logical block; whole-process
   peak RSS and the fact-projection peak are reported separately at the
   fixture and at the Sharadar fact population; neither is hidden in the
   other.
5. End-to-end clocks on the fixture and the Sharadar record: seal, cold open
   with verify, one run, a three-candidate sweep and the 26-fold
   walk-forward, after ticket 1 and again after ticket 2.
6. Verified-set counters (ticket 2): run, sweep, walk-forward, inspection and
   reconstruction show exactly one complete verification per fresh process,
   none per candidate or fold; serialization and a fresh worker start cold;
   explicit validation recomputes on a warm entry; a failed check removes it.
7. Census completeness: every `snapshot_*` reader is classified; a reader
   without a class fails the review.
8. Current-store enforcement (amended by the accepted pre-CRAN legacy-removal
   synthesis): older, newer, unmarked, invalid and fingerprint-mismatched
   stores refuse before every read class. In a current store, a missing or
   non-3 snapshot rule refuses as invalid stored evidence.

## 7. Failure Scenarios

| Scenario | Bound behaviour | Failure of this design |
| --- | --- | --- |
| Serialized locator or experiment reaches another process or worker | set not carried; worker verifies cold | an entry travels in a payload |
| Fork, PID reuse or generation reset | PID compare discards entries | a child reuses a parent's proof |
| Two locators address one snapshot in one process | second hits the same tuple | a second locator forces a rehash |
| Split run and snapshot stores | key is the snapshot store | run-store key reuses across snapshot files |
| In-memory store | never entered; verifies on every use | a `NULL` key collides |
| Supported API changes sealed content | none exists; seal needs `CREATED` | a new API mutates rows under an old root |
| External write preserves the stored root | undetected until explicit validation or a new process, as declared | the contract implies lock protection |
| Result reopened or summarized after the creating call | class 2 reopen needs no proof; class 3 summary hits the entry, or verifies cold in a new process | a stored-root compare substitutes for proof |
| Sweep or walk-forward with many candidates or folds | one complete verification per outer call; folds hit | per-fold rehash returns |
| Explicit validation on a warm entry | always recomputes and refreshes | a hit short-circuits `verify = TRUE` |
| Fact projection dominates retained memory | reported separately; Section 9 obligation | the bar result hides it |

## 8. Open Questions Promoted To Spec-Cut

- Names of the classed conditions: legacy rule refused, hostile order at
  seal, verified-set invalidation; corruption keeps `LEDGR_SNAPSHOT_CORRUPTED`.
- Column names in `ledgr_snapshot_info()` for the rule and the
  current-process verified flag, and the `print()` line.
- Whether the generation nonce is kept for diagnostics; PID is binding.
- How `ledgr_state_reconstruct(run_id, con)` derives its key from a raw
  connection (`dbGetInfo(con)$dbname` was confirmed to return the path) or
  always verifies.
- Where the ensure sits in sweep and walk-forward: at the outer hold or at
  the first bar read; either satisfies gate 6.

## 9. Future Obligations Recorded

- **WS5-B feature-artifact policy:** after WS3 and WS4 bind history and
  recursive-indicator semantics; reuse keys per macro plan WS5.
- **Persisted-data execution placement RFC:** any DuckDB reproduction of
  rule 3 is an optimization that must match the R oracle byte for byte and
  is routed there; it never redefines identity.
- **Post-v0.2.2 memory release:** reduce the retained fact-projection peak
  (418 to 474 MB at 300,000 rows) without changing rule-3 bytes; the
  verification ticket's reported peak is the input.
- **Sweep persistence follow-ups:** `ledgr_sweep_open()` may become class 2
  if the universe is persisted with the sweep and the row read removed.

## 10. Acceptance Routing

On maintainer acceptance, in one step: set the RFC pipeline row
`snapshot-verification-policy` to `Obligations open`, latest artifact this
synthesis, next action the WS5-A two-ticket cut and WS5-B after WS3/WS4;
add a decisions-bridge row pointing at Sections 1, 3, 5 and 6 with the
Snapshot, Execution, Availability, Persistence and Verification contracts
as the missing consolidation; at ticket cut, remove the WS5-A obligation
from the pipeline because `tickets.yml` owns it, and apply Section 5 to the
contracts. No horizon entry: every deferral above has an owner.

## 11. Final Review Boundary

Final review was Type 1 and passed after patches: line numbers resolve at
the baseline, the bytes equal seed v2 Section 5, the evidence table equals
the recorded CSVs, and no ticket adds a component hash, a knob, a second
canonicalizer or a DuckDB-defined byte. A design finding routes to
`NEEDS_TYPE_2`.

## Revision History

- 2026-10-12 - Initial synthesis after the conformance spike closed GREEN.
- 2026-10-12 - Accepted after final-review patches (Codex,
  PASS_AFTER_PATCHES): snapshot
  `summary()` moved to class 3; legacy-run readability narrowed to
  durable-result-only surfaces; cost gates bound to the registered benchmark
  host with CI advisory and the bar population named.
- 2026-10-13 - Cut 14 applies the accepted pre-CRAN legacy-removal amendment:
  non-current stores now refuse at one store gate, so the temporary legacy
  snapshot and run readability clauses are unreachable.
