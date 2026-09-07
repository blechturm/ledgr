# W25 Fixture: Transform Graph And Cache Invalidation

- Witness: `W25`; class: `representation_discriminating`; policy v4.
- Purpose: two causal graphs over the same sealed series answer different
  questions with exact values and distinct graph identities; a warm cache
  invalidates affected descendants while preserving ancestors whose full
  semantic identity is unchanged; neither graph creates an observed or
  executable bar.
- Cases: `g1` carry-then-roll; `g2` roll-then-carry; `m_cal`, `m_cls`,
  `m_pop`, `m_cut` targeted mutations against the `g1`/`g2`/`fit` baseline.

## Sealed Series

Asset `A01` (alias AAA), member and listed. A sealed signal table `sig`
(not a bar):

| session | date | close_time | sig |
| --- | --- | --- | --- |
| S1 | 2024-01-02 | 2024-01-02T21:00:00Z | 1 |
| S2 | 2024-01-03 | 2024-01-03T21:00:00Z | 3 |
| S3 | 2024-01-04 | 2024-01-04T21:00:00Z | NA (no observation) |
| S4 | 2024-01-05 | 2024-01-05T21:00:00Z | 9 |

Bars exist at all four sessions (100.00 flat) and are unaffected by the
graphs.

## Graphs

- `g1` = `carry_forward(sig)` then `rolling_mean(window = 2)`.
- `g2` = `rolling_mean(sig, window = 2)` then `carry_forward`.
- `fit` = the `W15` fitted transform `label_mean_v1` (population `A01`,
  cutoff 2024-01-05T21:00:00Z, RNG `fixed:20240105`) consumed as a
  downstream node whose identity includes calendar, classifier, estimation
  population, and training cutoff.

Each node's semantic identity includes its inputs, declared rules, calendar,
classification policy, admissible-history rule, and, for `fit`, the
estimation population and training cutoff.

## Derivations

- `g1`: carried series `1, 3, 3, 9`; rolling means `NA, 2, 3, 6`.
- `g2`: rolling means on raw `NA, 2, NA, NA`; carried `NA, 2, 2, 2`.
- `graph_identity(g1) != graph_identity(g2)`.
- Mutations (warm cache, baseline identities from the unmutated run):
  - `m_cal` adds a declared scheduled closure: `g1`, `g2`, and `fit`
    identities change (history rule depends on the calendar); the raw `sig`
    node identity is equal.
  - `m_cls` changes the observation classifier version: `g1`, `g2`, `fit`
    change; raw equal.
  - `m_pop` changes the estimation population: `fit` changes; `g1`, `g2`,
    raw equal (they do not depend on the estimation population).
  - `m_cut` changes the training cutoff: `fit` changes; `g1`, `g2`, raw
    equal.
- No graph creates a bar: bars created 0 in every case.
