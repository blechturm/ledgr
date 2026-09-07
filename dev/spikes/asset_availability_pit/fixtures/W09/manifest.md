# W09 Fixture: Quotation-Only And Resumption States

- Witness: `W09`; class: `semantic_oracle`; policy v4.
- Purpose: halted, quotation-only, resumed, conflicting, and absent status
  states remain distinct at EOD opens. Open eligibility uses the status
  effective at `open_time` from facts with `knowledge_time <= open_time`. A
  known future halt does not block an earlier open; an effective resumption
  supersedes an old halt; equal-precedence conflict and absent assertions
  produce typed no-fills.
- Cases: `c1` to `c6`, each an independent one-decision scenario on the same
  fact base.

## Assets And Aliases

| stable_id | alias | role |
| --- | --- | --- |
| A01 | AAA | member, held 100 (`c1` to `c5`) |
| A05 | EEE | member, held 100, no status assertion at all (`c6`) |

## Calendar (venue XSYN, UTC)

| session | date | open_time | close_time |
| --- | --- | --- | --- |
| S1 | 2024-01-02 | 2024-01-02T14:30:00Z | 2024-01-02T21:00:00Z |
| S2 | 2024-01-03 | 2024-01-03T14:30:00Z | 2024-01-03T21:00:00Z |
| S3 | 2024-01-04 | 2024-01-04T14:30:00Z | 2024-01-04T21:00:00Z |
| S4 | 2024-01-05 | 2024-01-05T14:30:00Z | 2024-01-05T21:00:00Z |
| S5 | 2024-01-08 | 2024-01-08T14:30:00Z | 2024-01-08T21:00:00Z |
| S6 | 2024-01-09 | 2024-01-09T14:30:00Z | 2024-01-09T21:00:00Z |

## Domains And Ordering

Investment universe `A01, A05`; target-vector order `A01|A05`.

## Membership And Lifetime Facts

| kind | asset_id | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| membership inv | A01 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| membership inv | A05 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| listed | A01 | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| listed | A05 | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |

## Trading-Status Facts

| asset_id | source | precedence | status | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | primary | 1 | active | 2023-01-02T14:30:00Z | 2024-01-04T14:00:00Z | 2023-01-02T14:30:00Z |
| A01 | primary | 1 | halted | 2024-01-04T14:00:00Z | 2024-01-05T14:00:00Z | 2024-01-02T20:00:00Z |
| A01 | primary | 1 | quotation_only | 2024-01-05T14:00:00Z | 2024-01-08T14:00:00Z | 2024-01-04T22:00:00Z |
| A01 | primary | 1 | active | 2024-01-08T14:00:00Z | (open) | 2024-01-05T22:00:00Z |
| A01 | secondary | 1 | halted | 2024-01-09T14:00:00Z | (open) | 2024-01-08T22:00:00Z |

`A05` has no status assertion.

## Bars (accepted; knowledge_time = close_time; all flat)

| asset_id | sessions | open | high | low | close | volume note |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | S1 to S6 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 except 0 on S3 and S4 |
| A05 | S1 to S2 | 200.00 | 200.00 | 200.00 | 200.00 | 1000 |

Later daily fields (high, low, close, volume) are present so the witness can
show they are not consulted for open eligibility.

## Opening State (each case)

Cash `90000.00`; `A01` held 100 (`c1` to `c5`) or `A05` held 100 (`c6`);
zero cost; no risk chain.

## Strategy Output (scripted)

| case | decision pulse | target | execution open |
| --- | --- | --- | --- |
| c1 | S1 close | A01 0 | S2 open 2024-01-03T14:30:00Z |
| c2 | S2 close | A01 0 | S3 open 2024-01-04T14:30:00Z |
| c3 | S3 close | A01 0 | S4 open 2024-01-05T14:30:00Z |
| c4 | S4 close | A01 0 | S5 open 2024-01-08T14:30:00Z |
| c5 | S5 close | A01 0 | S6 open 2024-01-09T14:30:00Z |
| c6 | S1 close | A05 0 | S2 open 2024-01-03T14:30:00Z |

## Derivations

- Decision-time restriction is the status resolved at the decision pulse.
  A halt that is known but effective only after the decision does not
  restrict the decision (bounded assumption, recorded for review).
- `c1`: at the S2 open the halt is known (since 2024-01-02T20:00:00Z) but
  effective only from 2024-01-04T14:00:00Z; resolved status active; fill
  sell 100 at 100.00; cash 100000.
- `c2`: at the S3 open the halt is effective; no-fill `trading_halted`.
- `c3`: at the S4 open quotation-only is effective and knowable
  (2024-01-04T22:00:00Z); no-fill `quotation_only`, distinct from the halt.
- `c4`: at the S5 open the resumption supersedes the earlier halt and the
  quotation-only interval; resolved active; fill sell 100 at 100.00.
- `c5`: at the S6 open two equal-precedence sources conflict (primary active
  open-ended, secondary halted from 2024-01-09T14:00:00Z, both knowable);
  no-fill `status_unknown_or_conflicting`.
- `c6`: `A05` has no assertion; status `status_unknown`; no-fill
  `status_unknown`; the accepted bar does not imply tradability.
