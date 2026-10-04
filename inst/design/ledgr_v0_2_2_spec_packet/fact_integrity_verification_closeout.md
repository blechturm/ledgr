# Workstream 10 Closeout: Exact Fact-Integrity Verification

**Status:** Agent-provisional; ready for independent Type 1 close review.
**Date:** 2026-10-04
**Implementation commit:** `22c0b3fec1076744cb885a074c0639b01aaecfca`
**Baseline commit:** `a9cd0a9f86b017aebfb2ad59a46ad4871aa66aab`
**Tickets:** LDG-2946 through LDG-2949

## A. Decision And Scope

Optimization ID: LDG-2948.

Old mechanism: every POSIXt value in a canonical fact column passed through
the scalar canonical timestamp formatter, including repeated instants.

New mechanism: each distinct non-missing instant passes once through the
unchanged scalar formatter and its exact token is matched back to every row.

Expected complexity change: `O(rows * timestamp-format cost)` to
`O(distinct instants * timestamp-format cost + rows)` per timestamp column.

Files and functions in scope:

- `R/availability-facts.R:ledgr_fact_canonical_frame()`;
- `R/availability-facts.R:ledgr_fact_time_tokens_distinct()`.

Explicit non-goals:

- no public API, fact schema, canonical token, hash or identity change;
- no verification-policy or stored-digest-trust change;
- no provider, resolver or accounting change;
- no DuckDB migration or new database index.

The public product boundary is a sealed snapshot followed by
`ledgr_facts_resolve()`. The supporting internal boundaries are exact fact
assertion and rule-2 snapshot-hash recomputation.

## B. Eligibility

| Eligibility statement | Result | Evidence |
| --- | --- | --- |
| One bounded internal mechanism | PASS | production diff adds one distinct-token helper and routes POSIXt columns through it |
| Reachable product workflow | PASS | three fresh pairs call public `ledgr_facts_resolve()` on sealed snapshots |
| Public API and defaults unchanged | PASS | production diff is internal and focused API tests pass |
| Inputs, errors and ordering unchanged | PASS | LTB-0149 through LTB-0152 and the semantic matrix below |
| Schema, hashes and identity unchanged | PASS | 20 frozen byte artifacts plus all family, bundle and snapshot hashes |
| Accounting and tolerance unchanged | PASS | accounting is outside the diff; all comparisons are exact |
| Dependencies, workers and caches unchanged | PASS | no dependency, worker, cache or persistence code changed |
| Retained oracle available | PASS | unchanged scalar `ledgr_fact_time_token()` plus frozen pre-change artifacts |
| Bounded rerun | PASS | runner, checker and fixtures are committed under `dev/bench` and `tests/testthat/fixtures` |
| Independent review possible | PASS | two production functions, four load-bearing blocks and machine-readable records |

## C. Baseline Attribution

The accepted pre-change production tree is `a9cd0a9`. LDG-2946 committed its
oracle before any gate or production work at
`0c0c6949ba04661b47e96b97cc1d5971865e67da`. LDG-2947 registered the
performance gates at `86723ba3e725905c74e09f7901d7257b6c202031`.
LDG-2948 changed production at
`22c0b3fec1076744cb885a074c0639b01aaecfca` and committed its evidence at
`3d2f50c75c3471aded91627021e20fbddef331ab`. LDG-2949 is the commit that
introduces this closeout; its exact SHA is supplied in the review request.

The reviewed spike is mechanism evidence only. Its fact-integrity result
passed independent review, while its separate DuckDB membership candidate
was invalidated and is not used here. The durable pre-implementation record
is `dev/bench/v0_2_2_workstream10/evidence/` as committed at `86723ba`.
The implementation record is its `implementation/` child as committed at
`3d2f50c`.

Fixture and clock boundaries:

- repeated-clock: 300,000 membership rows; clock one complete in-memory
  assertion;
- public path: 300,000 membership rows and 500 bars; clock one fresh public
  `ledgr_facts_resolve()` call, including rule-2 verification;
- low repetition: 40,000 rows each of sessions, trading status and lifetime,
  120,000 total; clock one complete in-memory assertion;
- supporting rule-2 clock: 300,000 membership rows and 500 bars; clock the
  snapshot hash only.

Each measured pair ran in alternating order after full garbage collection.
The large gates use three pairs; the calibrated low-repetition gate uses five.
The low shape was frozen only after an untimed doubling calibration placed
both arms above one second.

Resolved environment:

- R 4.6.1;
- ledgr 0.2.1.0 at the commits named above;
- duckdb 1.5.6.9000;
- digest 0.6.39 and yyjsonr 0.1.22;
- Windows x86-64 on the maintainer's ordinary host, one measurement process
  at a time.

Peak working set was not measured and no memory claim is made. The public
clock belongs to the product workflow because it calls the exported resolver
against a sealed snapshot. The internal clocks explain that result; they do
not replace it.

## D. Semantic Matrix

| Case | Old outcome | New outcome | Equality standard | Result |
| --- | --- | --- | --- | --- |
| membership snapshots, repeated and optional clocks | frozen rows, headers and family | same | byte identity | PASS |
| membership intervals with empty headers | frozen rows, empty headers and family | same | byte identity | PASS |
| trading status clocks | frozen rows, headers and family | same | byte identity | PASS |
| lifetime clocks | frozen rows, headers and family | same | byte identity | PASS |
| equity corporate-action four-clock shape | frozen rows, headers and family | same | byte identity | PASS |
| sessions, repeated knowledge clock | frozen rows, headers and family | same | byte identity | PASS |
| bundle of all six registered shapes | frozen canonical bundle | same | byte identity | PASS |
| missing optional clocks | canonical `NA` representation | same | exact semantic and byte identity | PASS |
| half-second required membership clock | `LEDGR_SUBSECOND_TIMESTAMP` and `ledgr_fact_invalid_time` | same | exact classes and message | PASS |
| one-second constructed timestamp tamper | untampered-object refusal | same | exact class and stable message | PASS |
| membership flag and every other family clock tamper | untampered-object refusal | same | exact class and stable message | PASS |
| persisted timestamp tamper | snapshot-hash mismatch refusal | same | exact class and stable message | PASS |
| large and calibrated performance fixtures | exact rows and hashes | same | exact semantic and byte identity | PASS |

No local locator or creation-time field is excluded from an identity claim.
The 20 frozen artifacts record every row, header, family and bundle byte
payload that exists for the six shapes, plus the rule-2 snapshot identity.

## E. Identity And Persistence

The frozen manifest records byte length and independent SHA-256 for all 20
artifacts. Post-implementation regeneration in
`C:/tmp/ledgr-ws10-oracle-post-22c0b3f` was byte-identical for all 20.

Every registered family hash remained exact. Representative identities are:

- all-family bundle:
  `281802052268cd65b7db878053b9096a48008e406dada58b9848b045839ed747`;
- fresh and reopened rule-2 snapshot:
  `ae3274ba4874afa492e688c776f34651b4a66fb5d48753380e230523bfa41363`;
- 300,000-row family, bundle and snapshot:
  `6c314bf3298f2bfc649ba2da8ffe32464ecebe7f742acbe204583a46ca65e546`,
  `4e24b575585074e87fbfce9626c89f23ac85b3f1689ffc34863bf2247390bef3`
  and
  `2ffc931eec666e7cce74fe9afce6a1d2936df2a85759132a8e23f2ee6895bf4e`.

Fresh construction and reopened resolution return identical rows, evidence
and rule-2 identity. A persisted one-second timestamp mutation fails public
resolution with `Snapshot hash mismatch; facts inspection refuses corrupted
evidence.` No migration exists or is required.

## F. Numerical Comparison

Authoritative numerical path: none. Canonical timestamp tokens, JSON bytes,
hashes, rows, errors and ordering require exact equality. No tolerance was
introduced or widened; maximum residuals are therefore not applicable.

## G. Structural Regression Gate

- forbidden shape: a POSIXt column passed in full to the scalar formatter;
- required shape: formatter elements are no greater than distinct non-missing
  instants for every registered timestamp column;
- operation bound: the 300,000-row membership `effective_from` column has
  600 distinct values and exactly 600 formatted elements;
- mutation: restoring full-column formatting reports 300,000 elements and
  fails LTB-0152 and the evidence checker;
- semantic mutation: mapping one instant to a wrong token raises
  `ledgr_invalid_facts` and fails the exact-byte and identity oracles;
- trust-boundary mutations: bypassing `ledgr_facts_assert()` caused 12
  oracle failures, while trusting the stored snapshot hash caused two public
  boundary failures.

This is a structural and mutation-sensitive gate, not a timing threshold.

## H. Performance Result

| Boundary | Old median | New median | Ratio | Registered gate | Result |
| --- | ---: | ---: | ---: | --- | --- |
| 300,000-row in-memory assertion | 3.00 s | 0.59 s | 5.085x old/new | at least 2.0x | PASS |
| public resolver, 300,000 facts and 500 bars | 6.20 s | 3.83 s | 1.625x old/new | at least 1.5x | PASS |
| 120,000-row low-repetition assertion | 1.92 s | 1.97 s | 1.026x new/old | at most 1.25x | PASS |
| supporting rule-2 snapshot hash | 3.17 s | 0.75 s | 4.227x old/new | supporting only | PASS |

Values are medians of paired measurements. The pairwise-median statistic is
the binding statistic and yields the displayed gate ratios. No peak-working-
set result or general DuckDB/data-layer speed claim is made.

## I. Verification

Reproduction commands, from the matching Git tree, are:

```text
Rscript --vanilla dev/bench/v0_2_2_workstream10/run_scaling_gates.R \
  <repo> <record-directory>
Rscript --vanilla dev/bench/v0_2_2_workstream10/check_scaling_gates.R \
  <record-directory>
```

Use commit `86723ba` for the pre-implementation record and the current tree
for the implementation record. The checker reports
`WORKSTREAM10_SCALING_GATE_RECORD_OK` for both checked-in records.

Focused oracle, persistence, fact-family, availability-fact and control-plane
suites passed. LTB-0149 through LTB-0152 own the exact artifact, constructed
corruption, persisted corruption and structural element-count claims. The
fresh-process availability-inspection review block resolved an older DuckDB
from its subprocess library path and did not run; no product assertion failed,
and that review-only environment issue is not used as evidence here.

The ordinary fast record at
`C:/tmp/ledgr-ws10-ldg2948-fast-22c0b3f` passed 509 of 509 blocks in 81.65
seconds against the 112-second bound. `git diff --check` is clean for the
workstream. Generated oracle output lives under `C:/tmp`; no temporary or
generated artifact is committed outside the named fixtures and evidence.

Seven-shape walk:

1. Repeated lookup: one distinct-value map is built per timestamp column.
2. Growing scans: no row triggers a new scan over prior rows; `unique()` and
   `match()` each consume the column once.
3. Per-element work: formatting is bounded by distinct non-missing instants,
   while the retained scalar formatter remains the semantic oracle.
4. Scale-growing collections: token and match vectors are linear in rows;
   no history-growing list, frame or registry is introduced.
5. Recomputed work: rule-2 verification still recomputes canonical evidence
   from persisted rows; only duplicate formatting within that proof is gone.
6. Frame construction: the existing canonical frame is constructed once;
   no per-row frame is added.
7. Mutation and copy shape: inputs are not mutated, cached or trusted by
   stored digest; returned vectors are locally owned.

## J. Independent Review

Reviewer: pending (Claude requested).

Reviewed commit: pending; the exact closeout commit is supplied in the review
request.

The Type 1 review must independently inspect or rerun exact semantic and byte
gates, perturb an identity artifact, gut the distinct-value mechanism, verify
the public clock and confirm the old scalar oracle was not weakened. It must
also confirm that no public API, schema, identity, verification policy or
stored-hash trust changed.

Findings: pending.

Verdict: pending.

One cut review has run. The planned close review will make two invocations
over four tickets, 0.500. The independent spike review qualified evidence and
is not a ticket-review invocation, as the accepted cut records.

EXACT_PARITY_PROOF_DISPOSITION: PENDING
