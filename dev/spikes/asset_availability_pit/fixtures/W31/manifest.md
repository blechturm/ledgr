# W31 Fixture: Combined Lifecycle And Exposure Stress

- Witness: `W31`; class: `semantic_oracle`; policy v4.
- Purpose: an asset leaves membership while held, loses its fresh mark,
  receives a post-risk reduction, and fails to fill. Requested and actual
  exposure stay separate. One branch resumes with a fresh explicit target;
  the other exhausts the valuation horizon and records incomplete evidence.
  No hidden order, fabricated fill, or terminal event is inferred.
- Cases: `c1` resumption branch; `c2` exhaustion branch. The two branches
  share every fact through the S3 decision and differ only in the S4 and S5
  bars listed below.
- Policy v4 boundary: at the S3 open the instrument is both halted and
  without an execution bar. The expected tables apply the ordered no-fill
  reason contract proposed in `witness_spec.md` clarification 12 (status
  resolution first, then execution-bar availability, then affordability;
  all applicable reasons retained in order).

## Assets And Aliases

| stable_id | alias | role |
| --- | --- | --- |
| A01 | AAA | member at S1 only, held 200 |
| A02 | BBB | member throughout |

## Calendar (venue XSYN, UTC)

| session | date | open_time | close_time |
| --- | --- | --- | --- |
| S1 | 2024-01-02 | 2024-01-02T14:30:00Z | 2024-01-02T21:00:00Z |
| S2 | 2024-01-03 | 2024-01-03T14:30:00Z | 2024-01-03T21:00:00Z |
| S3 | 2024-01-04 | 2024-01-04T14:30:00Z | 2024-01-04T21:00:00Z |
| S4 | 2024-01-05 | 2024-01-05T14:30:00Z | 2024-01-05T21:00:00Z |
| S5 | 2024-01-08 | 2024-01-08T14:30:00Z | 2024-01-08T21:00:00Z |

Intended horizon S5 close.

## Membership And Lifetime Facts

| kind | asset_id | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| membership inv | A01 | 2023-12-01T00:00:00Z | 2024-01-03T00:00:00Z | 2024-01-02T22:00:00Z |
| membership inv | A02 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| listed | A01 | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| listed | A02 | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |

## Trading-Status Facts

| asset_id | source | precedence | status | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | primary | 1 | active | 2023-01-02T14:30:00Z | 2024-01-04T14:00:00Z | 2023-01-02T14:30:00Z |
| A01 | primary | 1 | halted | 2024-01-04T14:00:00Z | 2024-01-05T14:00:00Z | 2024-01-03T22:00:00Z |
| A01 | primary | 1 | active | 2024-01-05T14:00:00Z | (open) | 2024-01-04T22:00:00Z |
| A02 | primary | 1 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |

## Bars (accepted; knowledge_time = close_time)

| asset_id | session | open | close | branch |
| --- | --- | --- | --- | --- |
| A01 | S1 | 100.00 | 100.00 | both |
| A01 | S2 | missing | missing | both |
| A01 | S3 | missing | missing | both |
| A01 | S4 | 100.00 | 100.00 | `c1` only (missing in `c2`) |
| A01 | S5 | 100.00 | 100.00 | `c1` only (missing in `c2`) |
| A02 | S1 to S5 | 50.00 | 50.00 | both |

## Opening State And Policies

Cash `80000.00`; `A01` 200 (lot basis 100.00); zero cost; risk chain
`ledgr_risk_max_weight(0.1)`; valuation v3. Target-vector order from S2:
`A02|A01`.

## Strategy Output (scripted)

| pulse | A02 | A01 | note |
| --- | --- | --- | --- |
| S1 | 100 | 200 | buy A02; A01 default hold |
| S2 | 100 | 200 | A01 default hold (not yet restricted) |
| S3 | 100 | 0 | A01 restricted; explicit fresh exit |
| S4 (c1) | 100 | 0 | A01 no longer held after the S4 fill |
| S4 (c2) | not invoked | not invoked | stop before strategy |

## Derivations

- S1: A02 target 100 fills at the S2 open at 50.00; cash 75000
  (`last_executed_event_ts` 2024-01-03T14:30:00Z in `c2`).
- S2 decision: A01 exited membership (held non-member); no S2 bar so stale
  mark 100.00 age 1; equity `75000 + 5000 + 20000 = 100000`; the halt is
  knowable only at 22:00, so A01 is unrestricted; hold 200; `max_weight`
  cap `0.1 * 100000 / 100 = 100`; post-risk 100 with
  `stale_mark_reduction`; requested exposure 10000 versus actual 20000;
  intent sell 100.
- S3 open: A01 is halted (effective 14:00, knowable 2024-01-03T22:00:00Z)
  and has no S3 execution bar. Under the ordered contract the primary reason
  is `trading_halted` and the retained ordered list is
  `trading_halted|execution_bar_missing`; position still 200; the risk
  reduction did not change the position.
- S3 decision: age 2; halt knowable, so restricted (admissible 200 or 0);
  strategy emits explicit 0; intent sell 200.
- `c1` S4 open: resumption effective 14:00 and knowable 2024-01-04T22:00;
  bar present; fill sell 200 at 100.00; cash 95000; position 0; equity at
  S4 close `95000 + 5000 = 100000`; evidence complete.
- `c2` S4 open: status resolves active but no execution bar exists; single
  reason `execution_bar_missing`. S4 pulse: third missing expected session;
  stop `valuation_horizon_exhausted` before strategy; achieved horizon S3
  close; affected exposure 20000; fills preserved 1; no terminal event; no
  pending order.
