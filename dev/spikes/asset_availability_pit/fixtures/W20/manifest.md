# W20 Fixture: Prototype Reconstruction, Cache, And Parallel Parity

- Witness: `W20`; class: `representation_discriminating`; policy v4.
- Purpose: two scopes with distinct evidence. Provider-only scope: direct
  materialization, fork-local serialized reconstruction, cold and warm cache
  paths, and sequential and parallel provider-only calls recover the same
  fork-only inputs and evidence planes. Full-fork scope: separate direct and
  parallel full-fork tasks recover the same targets, quantities, economic
  results, evidence status, and declared prototype identity. No package
  sweep, reopen, walk-forward, or promotion integration is claimed.
- Cases: `c1_provider_<path>` and `c1_fork_<task>` on the complete fixture;
  `c2_provider_<path>` and `c2_fork_<task>` on the incomplete fixture.
  Provider paths: `direct`, `restore`, `cold`, `warm`, `seq`, `par`. Fork
  tasks: `direct`, `par`. The `direct` case of each scope captures the
  identity baseline.
- Every provider path asserts the identical bundle listed below; every fork
  task asserts the identical outcome bundle. Identity equality of
  `proto:provider_id` and `proto:prototype_id` is additional to those value
  assertions and never replaces them; their payload minimums are defined in
  `witness_spec.md`.

## Complete Fixture (`c1_*`)

| item | value |
| --- | --- |
| asset | `A02` (alias BBB), member, listed, status active |
| membership inv | 2023-12-01T00:00:00Z to (open), knowledge 2023-11-30T21:00:00Z |
| lifetime | listed 2023-01-02T00:00:00Z to (open), knowledge 2023-01-02T21:00:00Z |
| status | primary, precedence 1, active 2023-01-02T14:30:00Z to (open), knowledge 2023-01-02T14:30:00Z |
| calendar | S1 2024-01-02 and S2 2024-01-03; opens 14:30:00Z, closes 21:00:00Z |
| bars | A02 S1 and S2: open 50.00 high 50.00 low 50.00 close 50.00 volume 1000 |
| opening state | cash 100000.00; no positions; zero cost; no risk chain |
| strategy | S1 target A02 100 |

Outcome: fill 100 at the S2 open at 50.00; cash 95000; position 100;
equity 100000; evidence complete.

## Incomplete Fixture (`c2_*`)

| item | value |
| --- | --- |
| assets | `A01` (AAA) former member held 100; `A02` (BBB) member |
| membership inv | A01 2023-12-01T00:00:00Z to 2024-01-02T00:00:00Z (knowledge 2023-12-29T21:00:00Z); A02 open-ended (knowledge 2023-11-30T21:00:00Z) |
| lifetime | both listed 2023-01-02T00:00:00Z to (open), knowledge 2023-01-02T21:00:00Z |
| status | both primary, precedence 1, active 2023-01-02T14:30:00Z to (open), knowledge 2023-01-02T14:30:00Z |
| calendar | S1 2024-01-02, S2 2024-01-03, S3 2024-01-04, S4 2024-01-05, S5 2024-01-08 |
| bars | A01 S1 only (100.00 flat); A02 S1 to S5 (50.00 flat) |
| opening state | cash 90000.00; A01 100 (lot basis 100.00); zero cost; no risk chain |
| strategy | S1 target A02 100; hold afterwards |

Outcome: A02 fill at the S2 open; cash 85000; A01 ages 0, 1, 2; the S4
pulse has no permissible mark and stops with `valuation_horizon_exhausted`;
achieved horizon 2024-01-04T21:00:00Z; affected exposure 10000; evidence
incomplete.

## Provider-Only Bundle (asserted identically on all six paths)

| fixture | fields |
| --- | --- |
| c1 | `axis_ids`; `pulse_axis`; `decision_view` at S1 and S2; `close_plane_value` A02 at S1 and S2; `observation_state` A02 at S1 and S2; `mark_age` A02 at S1 and S2; `evidence_row_count` 2; `provider_identity` |
| c2 | `axis_ids`; `pulse_axis`; `decision_view` at S1 and S3; `close_plane_value` A01 and A02 at S1; `observation_state` A01 at S1 to S4 and A02 at S3; `mark_value` and `mark_age` A01 at S2; `mark_age` A01 at S3; `mark_permissible` A01 at S4; `evidence_row_count` 10; `provider_identity` |

## Full-Fork Bundle (asserted identically on both tasks)

| fixture | fields |
| --- | --- |
| c1 | `pre_risk_target`; `fill_qty`; `fill_price`; `cash_after`; `position_after`; `equity`; `evidence_status`; `prototype_identity`; `package_integration_claimed` |
| c2 | `fill_qty`; `cash_after`; `equity` at S3; `stop_reason`; `achieved_horizon`; `affected_exposure`; `evidence_status`; `prototype_identity` |

## Derivations

All values restate the complete and incomplete fixture outcomes above; the
witness asserts recovered values and identity equality, never timing.
