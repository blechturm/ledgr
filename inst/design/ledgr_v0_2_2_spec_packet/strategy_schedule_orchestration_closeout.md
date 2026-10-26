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

Candidate tasks transport the classed strategy and its small authored
declaration, not a resolved identity or verdict. Resolution occurs inside the
candidate failure boundary so an invalid menu value becomes one failed row
rather than aborting its sweep or walk-forward session. Each worker invokes
`ledgr_compile_strategy_schedule()` once inside candidate preparation against
its own authoritative sessions and pulses. Actual task objects contain no
decision, verdict or mask field. One-, two- and three-worker runs produce
identical statuses, equity and provenance on the registered fixture.

## Detecting evidence

LCL-0499 / LTB-0508 runs a schedule-sensitive parameterized target through
one, two and three workers, saves and reopens the result, reconstructs both
candidate keys, and promotes in-memory, durable and schedule-mismatched
candidates. Fixed week and month declarations with identical params produce
different train and test keys while retaining the same inner strategy hash.
The block also proves invalid-menu candidate failure in sweep, save/reopen and
walk-forward; unscheduled omission; actual task-payload shape; one worker-local
compile; and independent parent and candidate hash validation.

The block rewrites exact superseded values for saved sweep 5, sweep provenance
v1 and walk-forward candidate v1. LTB-0235 rewrites promotion v2. Each refuses
through its current-only condition and message. Removing the v2 provenance
check prevents reproduction-key construction from refusing an old candidate.
Existing persistence, promotion and walk-forward suites continue to own their
general format and economic oracles.

## Seven-shape walk

The changed orchestration paths add no row-at-a-time frame construction,
full-table subset inside a pulse or instrument loop, scalar timestamp parsing,
row-at-a-time durable write, quadratic validation or scalar write into an
environment-held vector. Schedule identity is four small list/scalar fields.
It is canonically serialized and hashed once when candidate identity is built
and checked again on reopen; the review measured this bounded work at roughly
140 to 160 microseconds per candidate and routes any consolidation to WS63.
Resolution stays inside the candidate boundary; compilation is once per
execution owner. Save and reopen validate candidates in one linear pass. No
work is added to the fold pulse loop.

## Verification before close review

Implementation commit `032e4c14` passes the strategy-schedule, PIT consistency,
promotion, sweep, parallel sweep, five sweep-persistence, three walk-forward,
current-only-records, availability-schema, documentation-contract and
test-control-plane suites. The non-writing codebase checker reports
`LEDGR_CODEBASE_CENSUS_OK`; the fold checker reports
`LEDGR_FOLD_PHASE_CONTRACT_OK`; tickets YAML parses; and `git diff --check` is
clean.

## Close-review correction

The independent Type 1 review in `close_review_62.md` returned
`CHANGES_REQUIRED`. Correction `77ec5333`:

- treats scheduled versus unscheduled promotion as a real `schedule_hash`
  mismatch in both directions;
- accepts both current sweep and walk-forward provenance when constructing a
  reproduction key, while retaining exact old-provenance refusal;
- moves parameter-menu resolution inside the candidate failure boundary and
  stores authored-only identity for an unresolvable failed candidate;
- names received and required sweep-provenance versions;
- replaces source-text mask checks with actual task-object inspection and adds
  schedule-sensitive economics, fixed-rule train/test identity, both promotion
  presence directions and independent parent/candidate tamper witnesses; and
- corrects the promotion contract, LCL-0233 and the seven-shape record.

The corrected scheduler block and fifteen surrounding promotion, sweep,
persistence, walk-forward, current-format, documentation, control-plane and
codebase-contract suites pass. The fold-phase checker and YAML parse pass, and
`git diff --check` is clean.

## Focused confirmations

The first focused re-review is recorded in `close_review_62_rereview_1.md`.
It found all original product findings resolved and requested three low
detector or record patches. Corrections `762b551d` and `1c675c86` make the
task-field scan recursive through data frames, prove that every genuinely
unresolvable FAILED candidate can reopen regardless of its primary failure
class, prove that a resolvable FAILED candidate cannot use authored-only
identity, pin warning-free matching promotion and route the bounded identity
cost to LDG-3114 as an acceptance item.

A final fresh-context Claude Opus confirmation returned `PASS`. Its three
mutants independently showed that a nested data-frame `decision_due` field,
the former error-class-specific reader gate and acceptance of authored-only
identity for a resolvable FAILED candidate each fail LTB-0508. The schedule
suite, YAML parse and range diff check pass. No new product defect remains.
