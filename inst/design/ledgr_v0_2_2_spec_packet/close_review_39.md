# WS39 / LDG-3055 close review (Type 1), `043a5ce1..7c9edee4`

## Verdict: PASS_AFTER_PATCHES

The rebuilt store holds up. The harness uses public adapter and ledgr APIs,
refuses an existing destination and contains no delete, rename or old-store
access. Every stage runs in a fresh process and checks the same snapshot
identity. The rule-3 hash matches the hash recorded independently in
LDG-3036. The four findings concern only the written record; no private
rebuild is required.

## Findings

### F1 (medium): the frozen-source reconciliation column is partly circular

`ws39_record.R:217-221`, `reconciliation.csv:4-8`, the evidence README and
LDG-3055 acceptance 3 copy current-build values into the frozen-source column
for open sessions, membership rows, membership sets, lifetime rows and the
snapshot hash. Only bars, instruments and first/last dates are independently
checked against the frozen lake. All counts and the hash do independently
match LDG-3036, so acceptance holds in substance. Mark the five cells as not
independently projected (or rename the column) and narrow the prose.

### F2 (low): the WS39 workstream row remains pending

LDG-3055 is complete, but `tickets.yml` still gives WS39 `status: pending`
and empty integration evidence. Set it to `review_pending` and point one
integration-evidence line at the WS39 evidence README.

### F3 (low): one intended format difference is omitted

The README says the intended differences are exactly the deleted features
table and three telemetry columns, but identity rule changes from 2 to 3.
Add an `identity_rule_version` reconciliation row (current 3, expected 3,
prior 2, owner LDG-3050) and name it in the README.

### F4 (low): failed attempts and harness commit timing are undisclosed

The record does not mention the two rejected recorder attempts or that their
stores remain unopened under the private root. It records ledgr commit
`043a5ce1` while the harness itself was committed afterward at `7c9edee4`,
and the helper does not reject a dirty tree. Product code was unchanged and
stage result directories cannot mix. Add one sentence saying both rejected
attempts failed only in the recorder, remain untouched and were not inputs,
and that the successful harness was committed unchanged at `7c9edee4`.

## Acceptance assessment

| Item | Result |
| --- | --- |
| Fresh build, current schema/fingerprint/hash rule | PASS |
| Cold verify and representative experiments on one identity | PASS |
| Aggregate reconciliation | PASS, with F1/F3 wording patches |
| Time/RSS/verify/host/thread/commit/privacy evidence | PASS |
| Macro/register/dividend routing | PASS, with F2 record patch |

Checks run: both harness scripts parse; YAML loads; all evidence CSVs read;
`git diff --check` is clean; new links resolve; privacy and destructive-action
scans are clean; no product, contract or test file changed. The reviewer did
not rerun the private build or read vendor rows, old stores or rejected stores.

WS39 is ready for maintainer acceptance after F1-F4 are applied. One expensive
run is sufficient because correctness is pinned by the exact hash against the
independent prior build; timing is descriptive rather than comparative.
