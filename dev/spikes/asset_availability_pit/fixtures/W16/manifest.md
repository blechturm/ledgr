# W16 Fixture: Effective-Dated Revision

- Witness: `W16`; class: `semantic_oracle`; policy v4.
- Purpose: an open membership assertion is later closed. An as-of query
  before the amendment reproduces the earlier answer; an as-of query after
  it sees the revision. Both answers retain provenance.
- Cases: `c1` (four as-of queries over one fact history).

## Asset

`A03` (alias CCC), listed from 2023-01-02T00:00:00Z open-ended.

## Calendar (venue XSYN closes at 21:00:00Z)

S4 2024-01-05, S5 2024-01-08, S6 2024-01-09, S7 2024-01-10.

## Membership Assertion History (universe `inv`)

| assertion_id | asset_id | effective_from | effective_to | knowledge_time | supersedes |
| --- | --- | --- | --- | --- | --- |
| m_A03_v1 | A03 | 2024-01-04T00:00:00Z | (open) | 2024-01-03T22:00:00Z | |
| m_A03_v2 | A03 | 2024-01-04T00:00:00Z | 2024-01-08T00:00:00Z | 2024-01-09T22:00:00Z | m_A03_v1 |

## Queries

| query | knowledge cutoff | question |
| --- | --- | --- |
| q1 | 2024-01-05T21:00:00Z (S4 close) | is A03 a member at S4 (2024-01-05)? |
| q2 | 2024-01-05T21:00:00Z (S4 close) | is A03 a member at S5 (2024-01-08)? |
| q3 | 2024-01-10T21:00:00Z (S7 close) | is A03 a member at S5 (2024-01-08)? |
| q4 | 2024-01-10T21:00:00Z (S7 close) | is A03 a member at S4 (2024-01-05)? |

## Derivations

- q1: only `m_A03_v1` is knowable; effective and open; member true;
  provenance `m_A03_v1`.
- q2: the same open assertion covers 2024-01-08; member true; provenance
  `m_A03_v1`. This earlier answer is preserved regardless of the later
  amendment.
- q3: `m_A03_v2` is knowable (2024-01-09T22:00:00Z) and supersedes v1; it
  ends membership at 2024-01-08T00:00:00Z; member at S5 false; provenance
  `m_A03_v2`.
- q4: under `m_A03_v2` the interval still covers 2024-01-05; member true;
  provenance `m_A03_v2`.
