# Exact-Parity Internal Optimization Proof Template

Status: reviewable draft proposed as a v0.2.0.1 documentation deliverable.
It is non-binding until accepted through the active packet. It defines an
evidence shape, not authority to bypass an RFC, specification, ticket, or
maintainer scope decision.

## 1. Purpose

Use this template to prove a bounded internal optimization whose intended
observable behavior is unchanged.

The template exists to make exact-parity work cheaper to evaluate without
making it easier to smuggle in a contract change. It packages the minimum
evidence a maintainer and one independent reviewer need to answer:

1. Was the old cost measured on a reachable product workflow?
2. Is the replacement genuinely internal and contract-preserving?
3. Do old and new paths agree over the relevant semantic domain?
4. Does a structural check prevent the removed mechanism from returning?
5. Is the speed or scaling improvement material enough to keep?

This template does not replace the spike protocol when the mechanism, semantic
boundary, or expected outcome is unknown. It does not replace the RFC cycle
when a public or identity decision is required.

## 2. Eligibility Gate

All statements below must be true before this template is used.

- The change has one bounded internal mechanism and one named product path.
- The measured baseline is reachable through a public workflow, or is clearly
  labelled as an internal diagnostic that supports a public-path claim.
- No public function, argument, return shape, class, default, or supported mode
  is added, removed, or reinterpreted.
- No accepted input, rejection, quarantine classification, error class,
  warning, row order, missing-value rule, or point-in-time rule changes.
- No database schema, persisted field, hash bytes, identity version, manifest,
  or migration changes.
- No accounting authority, valuation policy, reconstruction authority,
  numerical tolerance, or comparison reference changes.
- No dependency, dependency floor, worker protocol, cache lifecycle, or
  cross-process ownership rule changes.
- The old implementation can remain available to the proof harness or be
  reconstructed as an independent oracle until review is complete.
- The semantic fixture and performance fixture can be rerun at bounded cost.
- One independent reviewer can inspect the complete change and evidence.

If any statement is false or cannot be established, stop. Route the work to a
normal specification change, bounded spike, or RFC as appropriate.

An optimization at a hash, timestamp, accounting, recovery, or quarantine
boundary may still qualify, but only when the artifact or behavior on the far
side of that boundary is demonstrably unchanged. Short code is not evidence.

## 3. Equality Standard

Choose the strongest applicable standard before implementation.

### 3.1 Byte identity

Required for hashes, canonical JSON, serialized payloads, IDs, manifests,
ordered evidence rows, and other identity-bearing artifacts.

Record:

- byte length;
- old and new digest;
- first differing byte or line on failure; and
- all rule versions, chunk boundaries, and platform-sensitive encodings used.

### 3.2 Exact semantic identity

Required for classes, names, dimensions, row order, integer, logical, string,
date/time, missingness, errors, warnings, and categorical outcomes.

Use `identical()` or an equally strict table multiset comparison when physical
row order is not part of the contract. Name every deliberately excluded local
locator or creation-time field. Do not silently normalize values for the diff.

### 3.3 Registered numerical tolerance

Permitted only where the existing contract already defines a tolerance for
floating-point results. The proof must not introduce or widen one.

Record:

- the authoritative result path;
- the existing predicate and tolerance;
- maximum absolute and relative residuals;
- the rows and columns on which residuals occur; and
- exact checks for all non-floating outputs.

Passing within tolerance is not byte identity. Say which standard passed.

## 4. Required Proof Artifact

Copy the following headings into the optimization evidence document. Replace
every bracketed field. Do not delete an inapplicable section; mark it `none`
and explain why.

---

# [Optimization Name] - Exact-Parity Proof

Status: [draft / ready for independent review / accepted / rejected]

Implementation commit: `[full SHA]`

Baseline commit: `[full SHA]`

Public workflow: `[entry point and invocation]`

## A. Decision And Scope

Optimization ID: `[ticket or inventory ID]`

Old mechanism: `[one precise sentence]`

New mechanism: `[one precise sentence]`

Expected complexity change: `[old expression] -> [new expression]`

Files and functions in scope:

- `[path:function]`

Explicit non-goals:

- `[nearby behavior not changed]`

## B. Eligibility

For every eligibility statement in the governing template, record `PASS` and
the evidence anchor. Any `FAIL` or `UNKNOWN` stops this lane.

| Eligibility statement | Result | Evidence |
| --- | --- | --- |
| One bounded internal mechanism | [PASS] | [anchor] |
| Reachable product workflow | [PASS] | [anchor] |
| Public API and defaults unchanged | [PASS] | [diff/test] |
| Inputs, errors, and ordering unchanged | [PASS] | [matrix] |
| Schema, hashes, and identity unchanged | [PASS] | [diff/test] |
| Accounting and tolerance unchanged | [PASS] | [comparison] |
| Dependencies, workers, and caches unchanged | [PASS] | [diff] |
| Retained oracle available | [PASS] | [harness] |
| Bounded rerun | [PASS] | [clock/budget] |
| Independent review possible | [PASS] | [scope summary] |

## C. Baseline Attribution

Fixture ID and construction: `[fixture]`

Clock boundary: `[exact start and stop]`

Warm or cold state: `[state]`

Repetitions and statistic: `[runs and statistic]`

Resolved environment:

- R: `[version]`
- ledgr: `[commit and package version]`
- duckdb: `[version]`
- collapse: `[version]`
- operating system and architecture: `[value]`
- hardware and concurrent load: `[value]`

Measured baseline:

| Measure | Value | Method |
| --- | ---: | --- |
| Public workflow wall | [seconds] | [method] |
| Attributed mechanism wall | [seconds] | [method] |
| Peak working set | [MiB] | [method] |
| Rows or operations | [count] | [method] |

Explain why the attributed work belongs to the public workflow and is not
merely harness-private work.

## D. Semantic Matrix

List normal, boundary, missing, malformed, reordered, duplicated, empty, and
failure cases relevant to the mechanism. Trust-boundary work must include the
input that established each upstream guarantee and a direct/internal misuse
case where applicable.

| Case | Old outcome | New outcome | Equality standard | Result |
| --- | --- | --- | --- | --- |
| [case] | [outcome] | [outcome] | [standard] | [PASS] |

For error cases compare class, stable metadata, and the contract-bearing
message fragment. Do not require volatile call stacks or local paths.

## E. Identity And Persistence

Identity-bearing artifacts compared: `[list or none]`

Old/new hashes: `[values or none]`

Fresh artifact result: `[result or none]`

Existing artifact reopen result: `[result or none]`

Tamper-detection result: `[result or none]`

Migration result: `[none, otherwise this lane is normally ineligible]`

## F. Numerical Comparison

Authoritative path: `[path or none]`

Registered predicate: `[predicate or none]`

Registered tolerance: `[value or none]`

Maximum absolute residual: `[value or none]`

Maximum relative residual: `[value or none]`

Exact non-floating comparisons: `[result or none]`

## G. Structural Regression Gate

Name the check that fails if the removed complexity or anti-pattern returns.

- forbidden source shape or call: `[check]`
- required prepared representation or grouped operation: `[check]`
- operation counter or complexity bound: `[check]`
- mutation demonstrating failure sensitivity: `[mutation and result]`

A timing threshold alone is not a structural regression gate.

## H. Performance Result

Use the same fixture, clock, environment, warm/cold state, repetition rule, and
host-load disclosure as the baseline.

| Measure | Old | New | Change |
| --- | ---: | ---: | ---: |
| Public workflow wall | [value] | [value] | [value] |
| Mechanism wall | [value] | [value] | [value] |
| Peak working set | [value] | [value] | [value] |
| Scale-normalized measure | [value] | [value] | [value] |

Decision threshold registered before the final run: `[threshold]`

Threshold result: `[PASS / FAIL / INCONCLUSIVE]`

Do not publish a speedup if the semantic or structural gates fail.

## I. Verification

- focused tests: `[command and result]`
- complete affected suite: `[command and result]`
- package check required: `[yes/no and result]`
- deterministic evidence rerun: `[result]`
- `git diff --check`: `[result]`
- tracked and untracked containment: `[result]`
- generated or temporary artifacts removed: `[result]`

## J. Independent Review

Reviewer: `[identity]`

Reviewed commit: `[full SHA]`

The reviewer must independently:

1. rerun or inspect every semantic equality gate;
2. perturb at least one identity or semantic artifact and observe failure;
3. gut or bypass the optimized mechanism and observe the structural gate fail;
4. verify the public workflow and clock boundary;
5. verify the old path was not silently weakened to manufacture parity; and
6. verify containment and the claimed dependency/API/schema boundary.

Findings: `[none or list]`

Verdict: `[ACCEPT / CORRECT / RECLASSIFY / REJECT]`

`RECLASSIFY` means the work needs a normal specification, spike, or RFC. It is
not a failed optimization.

EXACT_PARITY_PROOF_DISPOSITION: `[ACCEPT / CORRECT / RECLASSIFY / REJECT]`

---

## 5. Stop And Reclassification Conditions

Stop this lane immediately if any of the following occurs:

- an accepted, rejected, quarantined, warned, or errored case changes;
- an identity-bearing byte, hash, ID, row order, or schema changes;
- a new numerical tolerance or authoritative path must be chosen;
- a public API, default, execution mode, dependency, cache, worker transfer, or
  migration is needed;
- the old path cannot serve as a trustworthy oracle;
- the measured gain exists only in a private harness;
- the final public-path gain misses its preregistered materiality threshold;
- the proof requires a new fixture family or design question wider than the
  bounded mechanism; or
- independent review cannot reproduce the evidence.

Reclassification routes:

- unknown mechanism or performance attribution -> prerequisite probe;
- two plausible internal designs -> spike Charter;
- bounded observable change -> normal specification amendment;
- public, identity, policy, or authority change -> RFC cycle;
- immaterial gain -> reject or retain only as cleanup backlog.

## 6. Relationship To Existing Process

The spike protocol remains binding when experimentation is needed. The RFC
cycle remains binding for product and identity decisions. Release tickets and
accepted specifications remain the source of implementation authority.

This template may reduce duplicated evidence prose, but it does not determine
how many reviews, tickets, or status updates governance requires. The planned
post-v0.2.0.1 governance review decides whether an accepted version becomes a
standing exact-parity lane and how that lane is represented in roadmap,
packet, and documentation contracts.

