# Workstream 62 closeout: scheduler orchestration formats

## Outcome

LDG-3113 carries the accepted strategy-schedule identity through ledgr's
research orchestration formats. Saved and reopened sweeps, candidate
reproduction keys, promotion contexts, walk-forward candidate identity and
inspection, and one-, two- and three-worker sweeps now agree on the authored
declaration and the rule resolved from each candidate's strategy parameters.

The change is deliberately narrower than scheduled execution. Workers receive
the small declaration identity and compile against their own prepared axis.
No compiled pulse mask crosses a process boundary or enters a durable record.
Sweep summary columns remain unchanged, and decision and skip counts remain
run-information fields owned by Workstream 61.

## Current-only formats

The implementation changes five current formats atomically:

| Format | Superseded | Current |
| --- | --- | --- |
| saved sweep | schema 5 | schema 6 |
| sweep candidate provenance | `ledgr_provenance_v1` | `ledgr_provenance_v2` |
| candidate reproduction key | `ledgr_candidate_reproduction_key_v1` | `ledgr_candidate_reproduction_key_v2` |
| walk-forward candidate and inspection | v1 | v2 |
| promotion context | `ledgr_promotion_v2` | `ledgr_promotion_v3` |

Readers refuse superseded durable versions and name the received and required
values. No migration, old reader, fallback or compatibility alias was added.
Candidate reproduction keys are output-only values rather than stored inputs;
their public constructor emits only v2 and refuses a candidate carrying v1
sweep provenance before a key can be produced.

## Identity boundary

A scheduled candidate records four distinct values:

- `strategy_schedule`, the authored declaration;
- `schedule_hash`, the authored declaration hash;
- `resolved_schedule`, the fixed rule selected by this candidate's params;
  and
- `resolved_schedule_hash`, the resolved-rule hash.

This keeps a parameter menu stable as authored configuration while ensuring
that two menu choices cannot collide in saved-sweep, reproduction,
walk-forward or promotion identity. The inner strategy's source identity is
unchanged. An unscheduled strategy records none of these fields: generic
payload builders omit the schedule member rather than serializing an explicit
null, preserving the pre-scheduler unscheduled shape.

## Parallel boundary

Candidate tasks resolve the declaration from the candidate's strategy params
before dispatch and transport that small identity record. Each worker invokes
`ledgr_compile_strategy_schedule()` once inside candidate preparation against
its own authoritative sessions and pulses. The task contains neither
`decision_due` nor `schedule_mask`. One-, two- and three-worker runs produce
identical statuses, equity and provenance on the registered fixture.

## Detecting evidence

LCL-0499 / LTB-0508 runs a parameterized two-candidate schedule through one,
two and three workers, saves and reopens the result, reconstructs both
candidate keys, promotes the in-memory and durable candidate, and inspects a
real walk-forward fold. It proves that equal authored declarations retain one
hash while month-start and week-start resolutions have different hashes. It
also proves the unscheduled omission rule and the worker's single compile.

The block rewrites exact superseded values for saved sweep 5, sweep provenance
v1 and walk-forward candidate v1. LTB-0235 rewrites promotion v2. Each refuses
through its current-only condition and message. Removing the v2 provenance
check prevents reproduction-key construction from refusing an old candidate.
Existing persistence, promotion and walk-forward suites continue to own their
general format and economic oracles.

## Seven-shape walk

The changed orchestration paths add no row-at-a-time frame construction,
full-table subset inside a pulse or instrument loop, scalar timestamp parsing,
row-at-a-time JSON, discarded candidate-invariant recomputation, quadratic
validation or scalar write into an environment-held vector. Schedule identity
is four small list/scalar fields. Resolution is once per candidate; compilation
is once per execution owner. Save and reopen validate each candidate in one
linear pass over the candidate table. No work is added to the fold pulse loop.

## Verification before close review

Implementation commit `032e4c14` passes the strategy-schedule, PIT consistency,
promotion, sweep, parallel sweep, five sweep-persistence, three walk-forward,
current-only-records, availability-schema, documentation-contract and
test-control-plane suites. The non-writing codebase checker reports
`LEDGR_CODEBASE_CENSUS_OK`; the fold checker reports
`LEDGR_FOLD_PHASE_CONTRACT_OK`; tickets YAML parses; and `git diff --check` is
clean.

The independent Type 1 close review is the remaining workstream gate.
