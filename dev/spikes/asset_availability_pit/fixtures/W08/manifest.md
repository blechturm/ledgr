# W08 Fixture: Halted Member With A Usable Feature

- Witness: `W08`; class: `semantic_oracle`; policy v4.
- Purpose: a current member has a usable causal feature while its
  decision-time status restricts its target. The compliant strategy respects
  the restriction; a non-compliant target is rejected with the typed reason;
  risk and fill evidence carry the halt reason.
- Cases: `c1` compliant hold on a held halted member; `c2` non-compliant
  target rejected at validation; `c3` unheld halted member with a positive
  signal, compliant zero target.

## Assets And Aliases

| stable_id | alias | role |
| --- | --- | --- |
| A01 | AAA | member, held 100 (`c1`, `c2`) |
| A02 | BBB | member, not held (`c3`) |

## Calendar (venue XSYN, UTC)

| session | date | open_time | close_time | type |
| --- | --- | --- | --- | --- |
| S0 | 2023-12-29 | 2023-12-29T14:30:00Z | 2023-12-29T21:00:00Z | session (history) |
| S1 | 2024-01-02 | 2024-01-02T14:30:00Z | 2024-01-02T21:00:00Z | session |
| S2 | 2024-01-03 | 2024-01-03T14:30:00Z | 2024-01-03T21:00:00Z | session |

The S0 row exists only to supply feature history.

## Domains And Ordering

Investment universe `A01, A02`; target-vector order `A01|A02`; held-position
domain `A01`.

## Membership And Lifetime Facts

| kind | asset_id | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| membership inv | A01 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| membership inv | A02 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| listed | A01 | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| listed | A02 | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |

## Trading-Status Facts (source `primary`, precedence 1)

| asset_id | status | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| A01 | active | 2023-01-02T14:30:00Z | 2024-01-02T20:00:00Z | 2023-01-02T14:30:00Z |
| A01 | halted | 2024-01-02T20:00:00Z | 2024-01-04T14:00:00Z | 2024-01-02T20:00:00Z |
| A02 | active | 2023-01-02T14:30:00Z | 2024-01-02T20:00:00Z | 2023-01-02T14:30:00Z |
| A02 | halted | 2024-01-02T20:00:00Z | 2024-01-04T14:00:00Z | 2024-01-02T20:00:00Z |

Both halts are effective and knowable before the S1 decision at 21:00:00Z,
so both assets are target-restricted at that decision.

## Bars (accepted; knowledge_time = close_time)

| asset_id | session | open | high | low | close | volume |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | S0 | 98.00 | 98.00 | 98.00 | 98.00 | 1000 |
| A01 | S1 | 100.00 | 100.00 | 100.00 | 100.00 | 500 |
| A01 | S2 | 100.00 | 100.00 | 100.00 | 100.00 | 0 |
| A02 | S0 | 49.00 | 49.00 | 49.00 | 49.00 | 1000 |
| A02 | S1 | 50.00 | 50.00 | 50.00 | 50.00 | 500 |
| A02 | S2 | 50.00 | 50.00 | 50.00 | 50.00 | 0 |

## Feature

`ret1 = close(S1) / close(S0) - 1`, a causal one-session return using only
accepted closes. A01: `100/98 - 1 = 0.0204081633`; A02: `50/49 - 1 =
0.0204081633`. Both are usable for a scalar Boolean signal.

## Opening State

Cash `90000.00`; positions `A01` 100 (one lot at basis 100.00); no A02
position. Equity at S1 close `90000 + 100 * 100 = 100000`.

## Policies

Zero cost; risk chain `ledgr_risk_max_weight(0.5)`; valuation v3.

## Strategy Output (scripted, S1 decision)

| case | A01 | A02 | note |
| --- | --- | --- | --- |
| c1 | 100 | 0 | positive signal on A01 ignored because A01 is restricted |
| c2 | 150 | 0 | non-compliant increase on the restricted holding |
| c3 | 100 | 0 | positive signal on unheld A02 ignored; zero is the only admissible A02 target |

## Derivations

- Admissible sets at S1: A01 (held, restricted) `100|0`; A02 (unheld,
  restricted) `0`.
- `c1`: pre-risk 100 accepted; `max_weight` cap `0.5 * 100000 / 100 = 500`,
  so post-risk 100 (`max_weight_pass_through`); no intent; no execution
  attempt; the halt reason is carried on the risk row and the fill row.
- `c2`: pre-risk 150 exceeds the admissible set; strategy validation rejects
  with `target_restricted`, reason `trading_halted`; no risk pass, no fill
  proposal.
- `c3`: A02 target 0 accepted; no intent for A02; A01 hold as in `c1`.
