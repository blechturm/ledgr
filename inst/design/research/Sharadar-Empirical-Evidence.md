# Sharadar empirical evidence for asset availability and point-in-time universes

**Status:** non-binding empirical input to a future ledgr RFC  
**Evidence cycle:** Sharadar Evidence Promotion v0.1.0  
**Authoritative source repository:** `blechturm/ledgr-research` (private)  
**Authoritative source commit:** `e53bda3b108e51ad44720b9812c8072624b8820e`  
**Closeout:** `accepted / true / dense_static_method_validation_v001`  
**Prepared:** 2026-09-06

## Purpose

This note distils the non-reconstructive evidence produced by the Sharadar Data
MVP and Sharadar Evidence Promotion cycles. It is intended to inform a future
RFC concerning asset availability, point-in-time universes, missing
observations, valuation, execution, and feature preprocessing.

It is an empirical input, not a design decision. It does not authorize an
implementation, choose a snapshot schema, prescribe masks or interval tables,
or establish an imputation API. The eventual RFC seed must combine this
evidence with prior art and ledgr's existing contracts.

The strongest empirical result concerns changing point-in-time membership. The
cycle conclusively demonstrated that ledgr's current static instrument input
cannot preserve the tested reference population without distortion. The cycle
did **not** separately establish a confirmed missing expected-session bar
during a known active lifetime. That distinction is load-bearing throughout
this note.

## Evidence boundary and privacy

The underlying vendor data is licensed and remains outside this repository.
Tracked evidence contains aggregate counts, named policies, timings, statuses,
and non-reconstructive descriptions. It excludes instruments, selected dates,
raw rows, source locators, private paths, credentials, and private hashes.

The authoritative artifacts are preserved in the private research repository at
the source commit above. Principal files include:

- `docs/design/sharadar-evidence-promotion/v0.1.0/spec.md`
- `docs/design/sharadar-evidence-promotion/v0.1.0/decisions.md`
- `docs/design/sharadar-evidence-promotion/v0.1.0/test-matrix.md`
- `docs/design/sharadar-evidence-promotion/v0.1.0/batch2-verification-summary.md`
- `docs/design/sharadar-evidence-promotion/v0.1.0/batch3-verification-summary.md`
- `docs/design/sharadar-evidence-promotion/v0.1.0/batch4-verification-summary.md`
- `docs/design/sharadar-evidence-promotion/v0.1.0/batch5-verification-summary.md`
- `docs/design/sharadar-evidence-promotion/v0.1.0/batch6-verification-summary.md`
- `docs/design/sharadar-evidence-promotion/v0.1.0/batch6-review.md`
- `docs/design/sharadar-evidence-promotion/v0.1.0/performance-summary.md`
- `docs/design/sharadar-evidence-promotion/v0.1.0/integration-verification.md`
- `docs/design/sharadar-evidence-promotion/v0.1.0/evidence-scope-decision.md`
- `docs/design/sharadar-evidence-promotion/v0.1.0/rfc-evidence-handoff.md`

Authorized maintainers should consult those artifacts when checking an exact
claim. This public note deliberately does not reproduce enough information to
identify the private cases.

## Questions examined

The cycle tested five linked questions:

1. Can a qualified full-history vendor build support bounded export without
   moving or hashing the complete dataset in R?
2. Can a genuine dense, static slice cross the vendor-to-ledgr boundary, seal,
   reopen, execute, and reconcile?
3. What kinds of absence and lifecycle uncertainty appear in deliberately
   adversarial cases?
4. Can the current ledgr snapshot represent a complete point-in-time reference
   population without selection or repair?
5. Which source-quality and corporate-action states constrain the claims ledgr
   may make?

The evidence programme intentionally separated a successful dense seam from a
valid broad-equity universe. A working backtest over a convenient rectangle
was not accepted as proof that the rectangle represented the historical
population honestly.

## Gate structure

| Gate | Question | Result |
|---|---|---|
| 0 | Was the specification reviewed and the integrated baseline qualified? | Passed |
| 1 | Can a bounded export reuse qualified canonical identity without full-history R materialization or routine rehashing? | Passed |
| 2 | Can one frozen real dense/static case seal, reopen, run, and reconcile? | Passed narrowly |
| 3 | Can bounded adversarial cases preserve absence and lifecycle uncertainty without repair? | Measured; no evidence grade |
| 4 | Can the complete supported reference population enter ledgr without static-universe distortion? | Blocked on real data |
| 5 | Can quality and unsupported-action counts be reconciled without a new full scan or reconstructive output? | Measured |
| 6 | Does independent review permit any research scope? | Accepted only for `dense_static_method_validation_v001` |

A failed or blocked gate could not be repaired by a later gate. Earlier
attempts and failed private runs were retained as superseded evidence rather
than overwritten.

## Canonical data and bounded export

The accepted canonical stock table contains 45,350,378 daily bars. The pinned
source input contains 45,351,064 rows. The difference is exactly 686 rows, all
classified as outside accepted metadata bounds and retained as quarantined
evidence rather than exported.

Routine bounded export:

- looks up exactly one qualified canonical build and its persisted fingerprint;
- fails closed on zero, multiple, missing, or mismatched qualifying records;
- does not materialize the full canonical history in R;
- does not perform routine full-build row-wise hashing;
- fingerprints the bounded bars-and-instruments payload set-wise in DuckDB;
- keeps the capsule membership hash distinct from the bounded payload hash;
- treats ledgr's sealed `snapshot_hash` as authoritative after sealing.

The pre-seal payload fingerprint and the ledgr snapshot hash describe different
boundaries and are not expected to be equal. Query-plan hashes remain private
performance diagnostics and do not enter data identity.

For one measured 378,000-row bounded payload, set-wise hashing took 0.28
seconds. The previous row-wise R approach took roughly 80 seconds on the same
class of work. This supports the scalability of the revised export seam; it is
not a general vendor or backtesting benchmark.

## Dense/static seam

### Selection protocol

The frozen proof case contains five instruments over twenty consecutive
expected sessions, yielding an expected rectangle of 100 cells.

The case was selected from persisted point-in-time provider membership. The
selection procedure used:

- no price or return ranking;
- no survivor filter;
- no intersection of instrument histories;
- no forward fill or fabricated row;
- no future identity or membership visibility;
- a deterministic five-instrument prefix;
- the chronologically first qualifying window.

The selection funnel contained 738 candidate twenty-session windows:

| Selection stage | Windows |
|---|---:|
| Met the minimum instrument count | 738 |
| Had static membership over the window | 215 |
| Had complete density for the deterministic five-instrument prefix | 215 |
| Also met the target lifecycle/action constraint | 151 |

These are selection-funnel counts, not estimates of population prevalence.
They establish that a real dense/static slice exists and can be selected
without return-based cherry-picking. They do not establish that the broader
market is dense or static.

### Snapshot and execution result

All 100 expected cells had one accepted persisted bar and valid point-in-time
identity. The snapshot was sealed, closed, reopened, and verified before
execution.

The flat control produced zero fills and zero exposure on every valuation row.
The non-flat content-free round trip produced:

- two actionable target changes;
- two fills;
- eighteen non-zero valuation rows;
- exact independent reconciliation of final cash and equity from fills;
- an explicit zero-cost model.

The execution proof exposed only one of the five instruments. It did not test
simultaneous multi-instrument positions or non-zero fees and costs. The case
also does not authorize dividend-inclusive or terminal-event performance
claims.

### What Gate 2 proves

Gate 2 supports the narrow claim that the current vendor-to-ledgr storage and
execution seam works for a real, complete, static rectangle under the tested
conditions.

It does not support:

- historical validity of a static broad-equity universe;
- dynamic-membership strategies;
- multi-calendar operation;
- ordinary missing-bar handling;
- dividend-inclusive returns;
- terminal-event accounting;
- general transaction-cost behaviour;
- predictive strategy comparisons.

## Bounded absence and lifecycle diagnostics

Seven authoritative adversarial cases produced 101 classified cells across six
instruments. The cases were deliberately selected to pressure the taxonomy, so
their counts must not be interpreted as population rates.

| Classification | Cells | Denominator |
|---|---:|---:|
| `expected_observed_row` | 12 | 101 |
| `observed_row_missing_values` | 0 | 101 |
| `structural_nonexistence` | 34 | 101 |
| `outside_membership` | 0 | 101 |
| `outside_vendor_coverage` | 0 | 101 |
| `expected_session_absence` | 0 | 101 |
| `invalid_or_rejected_source_row` | 0 | 101 |
| `unresolved_absence` | 24 | 101 |
| `observed_row_outside_expectation` | 31 | 101 |
| **Total** | **101** | **101** |

Only two of the seven lifecycle adjudications obtained known direct lifetime
evidence. Five remained uncertain, generally because an accepted listing
boundary was absent or evidence conflicted with the policy requirements.

The accepted lifecycle policy was deliberately conservative:

- a known start requires an accepted listing boundary;
- a known end requires consistent accepted terminal evidence;
- first and last observed prices do not establish lifetime;
- metadata price bounds do not establish lifetime;
- membership bounds do not establish lifetime;
- weak, missing, duplicate, or contradictory evidence remains unknown.

No imputation was performed. Missing accepted bars did not become executable
prices. Unresolved cases remained unresolved.

Two earlier diagnostic attempts were retained as superseded failures. One
allowed an ambiguous mapping; another did not constrain its expected-absence
selector to known lifetime bounds. The authoritative run followed the corrected
policy.

### What Gate 3 does and does not prove

Gate 3 demonstrates that structural nonexistence, unresolved absence, and
observations outside the expected grid can occur and must not be collapsed
blindly into one generic missing value.

It does **not** demonstrate a confirmed `expected_session_absence`: the
authoritative casebook observed zero such cells. It also cannot estimate how
frequently any state occurs because the casebook was adversarial rather than
random or exhaustive.

## Exhaustive point-in-time universe pressure

Gate 4 evaluated the complete supported 2019-2021 XNYS reference population:

| Measure | Count |
|---|---:|
| Expected sessions | 757 |
| Distinct instruments | 563 |
| Expected point-in-time member/session rows | 382,288 |

The search predicates were frozen before the Gate 3 casebook was executed. A
case qualified when either:

1. point-in-time membership varied across adjacent expected sessions; or
2. an expected member/session cell lacked an accepted canonical bar.

A qualifying real shape was observed. The complete supported population entered
ledgr pressure without a secondary selector, survivor filtering, date
intersection, price filling, or fabricated rows.

ledgr could seal the available bars. Its static instrument table could not,
however, preserve the original daily membership stream or the corresponding
expected-absence semantics. The gate therefore persisted:

`data_mvp_rejected_static_universe_distortion`

with evidence state:

`blocked / false / none`.

The negative outcome is an accepted empirical result, not an execution failure.

### Critical interpretation

The tracked evidence does not disclose predicate-specific qualifying counts.
Because changing membership alone satisfies the gate, Gate 4 conclusively
demonstrates a real dynamic-membership problem but does not independently prove
that an expected in-lifetime market bar was absent.

Accordingly, this evidence supports the need to represent point-in-time
membership and unresolved availability explicitly. It does not establish the
prevalence of ordinary price gaps or justify any particular imputation policy.

## Quality and corporate-action census

The quality census reused persisted aggregates and completed without
reclassifying or hashing the complete history in R.

### Reconciled diagnostic totals

The reported 253,861 total is a sum of diagnostic counters, not a count of
distinct rejected records.

| Measure | Count |
|---|---:|
| Non-accepted diagnostic-counter sum | 253,861 |
| Declared duplicate view of unsupported actions by source family | 91,090 |
| Distinct affected source locators after removing that overlap | 162,771 |
| Distinct affected canonical records where a canonical record exists | 148,839 |

| Canonical scope | Distinct source locators | Distinct canonical records |
|---|---:|---:|
| Corporate actions | 91,090 | 91,090 |
| Daily bars | 686 | 0 |
| Identity | 13,246 | 0 |
| Reference membership | 57,749 | 57,749 |
| **Total** | **162,771** | **148,839** |

The 686 daily-bar exceptions exactly reconcile the source-to-canonical stock
difference. They are quarantined and excluded from export.

### Dispositions

| Scope | Disposition | Count | Runtime treatment |
|---|---|---:|---|
| Corporate actions | Accepted | 606,548 | Canonical evidence |
| Corporate actions | Unsupported | 91,090 | Retained as evidence only |
| Daily bars | Accepted | 45,350,378 | Export eligible |
| Daily bars | Outside metadata bounds | 686 | Quarantined |
| Identity | Accepted ticker rows | 60,875 | Canonical identity evidence |
| Identity | Missing identifier | 13,246 | Quarantined |
| Reference membership | Accepted | 1,214 | Canonical evidence |
| Reference membership | Accepted with warning | 57,697 | Evidence, not a runtime interval |
| Reference membership | Unknown | 6 | Excluded; retained as evidence |
| Reference membership | Unmapped | 46 | Excluded; retained as evidence |

No blocking conflicting or rejected cluster was reported at closeout.

The 91,090 unsupported corporate-action records span twenty-five source
families:

| Source family | Count | Source family | Count |
|---|---:|---|---:|
| `acquisitionby` | 8,266 | `acquisitioncash` | 5,268 |
| `acquisitionelectcash` | 175 | `acquisitionelectstock` | 156 |
| `acquisitionof` | 8,266 | `acquisitionstock` | 1,803 |
| `adrratiosplit` | 393 | `bankruptcyliquidation` | 3,334 |
| `initiated` | 8,406 | `mergerfrom` | 133 |
| `mergerto` | 133 | `namechangefrom` | 5,518 |
| `namechangeto` | 5,518 | `regulatorydelisting` | 909 |
| `relation` | 6,482 | `sicchangefrom` | 2,934 |
| `sicchangeto` | 2,934 | `spacmerger` | 818 |
| `spacunitseparation` | 1,400 | `spinoff` | 570 |
| `spinoffdividend` | 522 | `spunofffrom` | 570 |
| `tickerchangefrom` | 13,100 | `tickerchangeto` | 13,100 |
| `voluntarydelisting` | 382 | **Total** | **91,090** |

These are aggregate vendor source labels, not proposed ledgr event types. They
show that lifecycle, identity, distribution, and terminal-event evidence is
material and heterogeneous. They do not determine how ledgr should account for
those events.

## Performance and resource evidence

The final clean replay used the already frozen five-by-twenty case.

| Operation | Seconds |
|---|---:|
| Qualified canonical-fingerprint lookup and validation | < 0.01 |
| Universe-capsule construction | 0.31 |
| Bounded export, including its fingerprint | 1.15 |
| Bounded bars-and-instruments fingerprint alone | 0.13 |
| ledgr snapshot sealing | 0.45 |
| ledgr snapshot reopen and verification | 0.51 |
| Flat control run | 0.64 |
| Non-flat round-trip run | 0.54 |
| Seven authoritative absence diagnostics, combined | 0.15 |

Peak process working set was 3,092.4 MB, sampled externally every 20
milliseconds. This is the whole R, DuckDB, and ledgr process peak; it must not
be described as the incremental memory cost of exporting 100 bars.

Additional measurements were:

| Operation | Time | Recorded R allocation high-water |
|---|---:|---:|
| Gate 4 exhaustive enumeration | 11.59 seconds | 233.6 MB |
| Gate 4 set-wise membership comparison | 0.50 seconds | Included in pressure run |
| Gate 4 bounded payload fingerprint | 0.28 seconds | Included in 220.0 MB export high-water |
| Gate 5 quality census | 0.23 seconds | 78.5 MB |

The replay performed no full-history R materialization, routine canonical
fingerprint recomputation, row-wise full-history hashing, or all-history
instrument/session Cartesian allocation.

These measurements validate the bounded evidence path on the recorded
environment. They are not a Sharadar throughput benchmark, a comparison with
commercial engines, or a prediction of ragged-runtime performance.

## Verification and review

Final offline verification reported zero failures, warnings, or skips:

| Package | Assertions | Test blocks |
|---|---:|---:|
| `ledgr.universe` | 25 | 8 |
| `ledgr.sharadar` | 829 | 191 |
| `ledgr.fmp` compatibility | 544 | 123 |

The built-source R package check, schema-document rendering, redaction
validation, and final whitespace check passed.

The independent Batch 6 review returned
`PASS_WITH_LOW_OBSERVATIONS`. Before immutable closeout, the packet corrected
a reported test count, removed trailing whitespace, added the
single-exposed-instrument and zero-cost limitation, and changed the closeout
operator to require an externally supplied review digest. A successful but
dirty performance attempt and an interrupted attempt remain recorded as
superseded evidence; the authoritative replay is the clean matched run.

The closeout writer permits exactly three combinations:

| Evidence status | Grade | Approved scope |
|---|---:|---|
| `blocked` | `false` | `none` |
| `seam_proven` | `false` | `none` |
| `accepted` | `true` | `dense_static_method_validation_v001` |

Independent review selected the third row. The write-once closeout binds the
reviewed commit, review digest, limitations, and qualified full-history run.

## Claim ledger

| Claim | Assessment | Evidence |
|---|---|---|
| A qualified canonical build can support bounded export without full-history R materialization or routine rehashing. | Supported | Gates 1, 5, and 6 |
| A real complete static rectangle can be sealed, reopened, executed, and reconciled. | Supported narrowly | Gate 2 |
| The successful rectangle establishes historical validity for broad equities. | Not supported | Gate 2 scope limitation and Gate 4 |
| Point-in-time membership changes occur in the complete supported reference population. | Supported | Gate 4 |
| ledgr's current static instrument input preserves that membership stream. | Contradicted | Gate 4 static-universe distortion |
| Confirmed expected-session bar gaps occur in the tested population. | Not established by tracked evidence | Gate 3 observed zero; Gate 4 predicate counts are not separated |
| Common price or membership bounds always establish a reliable security lifetime. | Contradicted in the adversarial casebook | Five of seven lifecycle cases remained uncertain under the accepted policy |
| All unavailable cells have the same economic meaning. | Contradicted | Gate 3 taxonomy and lifecycle adjudication |
| Missing or stale data may safely become an executable price. | Not tested and not authorized | Gate 3 performed no imputation and invented no execution price |
| A particular masks, intervals, or event-stream architecture follows from the evidence. | Not established | Deferred to the RFC |
| A global post-snapshot imputation step is valid for walk-forward evaluation. | Not established | No imputation experiment was performed |
| The current snapshot contains complete external lineage and universe-construction policy. | Contradicted | Required lineage remained in the hash-bound sidecar |
| Current evidence supports dividend-inclusive or terminal-event performance claims. | Not supported | Closeout prohibition and unsupported-action census |
| Current evidence supports dense/static method validation. | Supported within explicit limits | Independent closeout |

## Supported design pressures

The evidence creates requirements and questions; it does not uniquely choose
solutions.

A future design must be able to consider:

- stable instrument identity separately from mutable vendor symbols;
- a computational instrument axis separately from point-in-time membership;
- expected sessions separately from observed rows;
- structural nonexistence separately from unresolved or invalid evidence;
- strategy visibility separately from valuation availability;
- valuation availability and staleness separately from execution eligibility;
- vendor facts separately from ledgr's inferred classifications;
- snapshot identity separately from external construction lineage;
- deterministic as-of transformations separately from statistically fitted
  fold-local preprocessing;
- dense legacy snapshots as a backward-compatible case.

The evidence also supports an explicit unknown state. When listing, terminal, or
coverage evidence is insufficient, the system must not infer a confident
lifetime merely to make the panel rectangular.

These pressures are compatible with sparse storage plus dense fold-local
materialization, dense arrays plus explicit state, dynamic matrices, or a
hybrid event/panel model. Choosing among those alternatives belongs to the RFC
cycle.

## Questions the RFC must resolve

1. What is the authoritative distinction among instrument lifetime,
   point-in-time membership, expected session, observed market data, data
   quality, valuation availability, and execution eligibility?
2. May the runtime retain a fixed internal superset axis without exposing
   future membership to strategies, indicators, or cross-sectional transforms?
3. What does a strategy receive for an instrument that is known but not
   currently eligible, and what target-vector contract applies?
4. How is a held position valued when no fresh eligible observation exists, and
   how are price age and staleness exposed?
5. What happens to a target whose next execution pulse lacks an eligible real
   bar, before ledgr has a persistent-order OMS?
6. Which external lineage, classification policy, and universe-construction
   fields enter snapshot identity?
7. How are existing complete dense snapshots interpreted and migrated?
8. What dependency graph delivers observed and transformed data to indicators
   and strategies without cycles or lookahead?
9. Which deterministic as-of transforms may be snapshot-bound and materialized
   once?
10. Which fitted transformations must instead be keyed to the training window,
    fold, recipe, and fitted state?
11. Which lifecycle and terminal states require coordination with the separate
    accounting-critical-event RFC?
12. What new empirical evidence is required for multi-calendar operation,
    actual expected-session gaps, multi-instrument accounting, non-zero costs,
    dividends, and terminal outcomes?

## Explicit non-conclusions

This evidence must not be cited to claim that:

- Sharadar defines ledgr's canonical schema;
- ordinary missing daily bars are common;
- absent rows should be forward-filled;
- a stale valuation price is executable;
- dense matrices are inherently invalid;
- dense matrices plus masks are already the accepted solution;
- imputation should be globally fitted after snapshot creation;
- dynamic membership alone solves survivorship or point-in-time leakage;
- provider membership is automatically a tradable universe;
- unsupported vendor action labels map one-to-one to ledgr event types;
- the measured timings establish competitive benchmark performance;
- broad-equity strategy research is authorized.

## Closeout assessment

The Sharadar cycle moved the discussion beyond hypothetical concerns. It
established a scalable, reproducible vendor-to-ledgr seam for bounded
dense/static cases and demonstrated, on a complete real point-in-time reference
population, that the current static-universe contract loses material historical
state.

The appropriate next step is therefore a seeded, adversarial RFC cycle. The
seed should cite this document and the corresponding prior-art review, audit
the current ledgr contracts, and propose a problem model before selecting a
schema or runtime representation. Additional empirical work should be targeted
at decisions the RFC cannot resolve from current evidence rather than launched
as another broad exploratory spike.
