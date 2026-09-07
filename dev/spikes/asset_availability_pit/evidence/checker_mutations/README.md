# Checker Mutations

This file defines the deliberate mutations the conformance checker must
reject. It is a frozen Stage 2 input (freeze role `mutation_definitions`).
The executables that apply these mutations to prototype output are Stage 3
code: they cannot exist before the gate opens because there is no prototype
output to mutate. They are registered in `evidence/stage3_code.csv`, created
after the gate-record commit, and the later-stage checker verifies that each
first-appearance commit descends from that gate-record commit and that the
registered executables implement exactly `M1` to `M5` as frozen here.

## Mutation Definitions (approved 2026-09-07)

Each mutation is applied to prototype output after the shared fork runs the
named witness. The checker must reject the mutated output against the frozen
expected table with the named finding.

| id | mutation | witness | expected checker finding |
| --- | --- | --- | --- |
| M1 | replace the S3 open fill price of `A02` with its stale valuation mark and report the fill as executed at that mark on a session without an execution bar | W22 `c1` (bar removed at S3) | `fill_price` and `fill_status` rows fail: stale mark passed as an execution price |
| M2 | keep the halt effective at the S5 open after the resumption assertion supersedes it | W09 `c4` | `resolved_status` and `fill_status` rows fail: superseded halt left active |
| M3 | omit the carried holding `A01` from the fold-2 opening axis and state | W24 `c1` | `opening_axis`, `held_qty`, and `held_nonmember_count` rows fail: carried holding omitted |
| M4 | drop the estimation-population dependency from the `fit` node identity so `m_pop` reports `fit_identity` equal | W25 `m_pop` | `fit_identity` row fails: required dependency removed |
| M5 | drop the virtually credited `A01` sale from the final accepted fill set while keeping the `A02` purchase it funded | W02 `c2` | `affordability_reconciliation_failed`: virtual final cash 0.00 versus recorded final cash -30000.00 outside `cash_tolerance`; pulse completion invalidated |

`M5` exists because a virtual/event-order mismatch cannot arise from valid
inputs under the approved policy; it must be injected to prove the checker
detects it.
