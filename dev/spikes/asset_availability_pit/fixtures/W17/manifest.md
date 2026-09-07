# W17 Fixture: Future-Fact Perturbation

- Witness: `W17`; class: `representation_discriminating`; policy v4.
- Purpose: adding a fact not knowable before the comparison cutoff leaves
  earlier strategy-visible state, feature values, targets, fills, and
  economic outputs unchanged, while the snapshot and every snapshot-keyed
  artifact identity change. After the announcement the declared strategy
  may consume the new member.
- Cases: `c1` baseline snapshot; `c2` perturbed snapshot, sealed separately
  with its own `snapshot_id` and `snapshot_hash`.

## Assets And Aliases

| stable_id | alias | role |
| --- | --- | --- |
| A01 | AAA | member |
| A02 | BBB | member, bought at S2 open |
| A04 | DDD | present only in `c2`; listed and admitted from S5 |

## Calendar (venue XSYN, UTC)

| session | date | open_time | close_time |
| --- | --- | --- | --- |
| S1 | 2024-01-02 | 2024-01-02T14:30:00Z | 2024-01-02T21:00:00Z |
| S2 | 2024-01-03 | 2024-01-03T14:30:00Z | 2024-01-03T21:00:00Z |
| S3 | 2024-01-04 | 2024-01-04T14:30:00Z | 2024-01-04T21:00:00Z |
| S4 | 2024-01-05 | 2024-01-05T14:30:00Z | 2024-01-05T21:00:00Z |
| S5 | 2024-01-08 | 2024-01-08T14:30:00Z | 2024-01-08T21:00:00Z |

Comparison cutoff: S3 close 2024-01-04T21:00:00Z.

## Baseline Facts (`c1`)

| kind | asset_id | source | precedence | value | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- | --- | --- | --- |
| membership inv | A01 | | | member | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| membership inv | A02 | | | member | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| lifetime | A01 | | | listed | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| lifetime | A02 | | | listed | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| status | A01 | primary | 1 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |
| status | A02 | primary | 1 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |

Bars at all five sessions: `A01` open and close 100.00, `A02` open and
close 50.00 (high and low equal, volume 1000). The `A02` fill at the S2
open relies on the `A02` status row.

## Perturbation (`c2` adds these facts; nothing else changes)

| kind | asset_id | source | precedence | value | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- | --- | --- | --- |
| lifetime | A04 | | | listed | 2024-01-08T00:00:00Z | (open) | 2024-01-05T22:00:00Z |
| membership inv | A04 | | | member | 2024-01-08T00:00:00Z | (open) | 2024-01-05T22:00:00Z |
| status | A04 | primary | 1 | active | 2024-01-08T14:30:00Z | (open) | 2024-01-05T22:00:00Z |
| bar | A04 | | | S5 only: open 10.00 high 10.00 low 10.00 close 10.00 volume 1000 | | | 2024-01-08T21:00:00Z |

## Opening State And Strategy

Cash `100000.00`; no positions; zero cost; no risk chain. Scripted targets:
S1 `A02` 100; S2 to S4 hold; S5 (`c2` only, `A04` visible) `A04` 50.

## Identities Compared

| identity | ledgr field | why it changes or not |
| --- | --- | --- |
| snapshot content | `snapshot_hash` | hashed source facts changed |
| feature cache key | `feature_cache_key` | key includes `snapshot_hash` (`R/feature-cache.R`) |
| logical config | `config_hash` | payload keeps `data$snapshot_id`, which differs for the separately sealed snapshot |
| feature values through the cutoff | value rows, not identities | same admissible inputs through S3 |

## Derivations

- Through the cutoff (S1 to S3) both snapshots yield: visible domain
  `A01|A02`; `A02` target 100; fill at the S2 open at 50.00; cash 95000;
  equity 100000; identical feature values.
- The perturbation is knowable at 2024-01-05T22:00:00Z, after the S4
  decision, so the S4 visible domain is also `A01|A02` in both.
- At S5 the perturbed snapshot shows `A01|A02|A04`; the declared strategy
  emits a 50-share `A04` target (intent only within this fixture).
- `snapshot_hash`, `feature_cache_key`, and `config_hash` change in `c2`;
  feature values through the cutoff stay equal.

## Synthetic Assumptions

The perturbed snapshot is a separately sealed snapshot. Re-sealing in place
is not a supported operation; sealed snapshots are immutable.
