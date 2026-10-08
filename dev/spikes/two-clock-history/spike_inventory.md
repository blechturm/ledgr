# Spike inventory: two-clock history

Executor deliverables for
`inst/design/spikes/two_clock_history_spike/charter.md`. Run on 2026-10-08
against the unchanged package code of `9452e9e`.

## What ran

| Artifact | What it does | Evidence |
| --- | --- | --- |
| `probe.R` | section 1 probe, before the charter | `probe_evidence.csv` |
| `spike_core.R` | bitemporal segments: per knowledge epoch, filter facts known by the epoch, hand them to the unchanged prepared provider and membership resolver, write a segment only when an epoch changes it | |
| `spike_runner.R` | builds segments for the seven fixtures, answers the `(s, t)` queries, checks the diagonal over ten days, records shape, measures growth under restatement (case 9); `--gut` answers with the shipped diagonal | `evidence/cases.csv`, `evidence/shape.csv`, `evidence/growth.csv`, `evidence/gut/` |
| `spike_checker.R` | reruns both modes into scratch, diffs, compares with `expected.csv`, asserts the gut's named rows, reports the size bound, guards scope | prints `SPIKE CHECK OK` |
| `expected.csv` | sixteen frozen `(s, t)` answers with their v11 basis | |

Harness: `probe.R` 147 lines, `spike_core.R` 133, `spike_runner.R` 143,
`spike_checker.R` 88; 511 in all, within the 1,500-line budget.

## Deviations from the charter

- **No source copy.** Section 3 allowed a scratch copy with one added
  function. None was needed: `spike_core.R` calls the unchanged internals
  (`ledgr_availability_provider_build_prepared`, `ledgr_membership_resolve_at`)
  through `ledgr:::` from a `load_all()` of the repo.
- **Case 2 reverts.** The charter's chain (three different statuses, one
  source) is refused at construction with `ledgr_fact_structural_conflict`,
  and supersession across sources is refused too. The runner records the
  refusal as an evidence row and runs the expressible chain: halted, then
  active, then halted again.
- **Case 9 added** after the first closeout, at the maintainer's go-ahead, to
  test the size bound on a fixture built to stress it. Nine shapes, within the
  cap of ten.
- **Shape omits bytes and revisions.** Bytes and the revision count were not
  measured; segment counts already decide the size question.

## Gutted path

With the shipped diagonal answering every query, the historical rows collapse
to today's answer: case 1 at `(4, 8)` and `(5, 9)`, case 2 at `(4, 6)` and
case 4 at `(3, 8)` fail, and so do the late-knowledge rows of cases 3, 5, 6
and 7. Case 8 (the diagonal) stays 10 of 10 for every fixture. The diagonal
stores no segments, so case 9 records `NA`. The checker asserts the named rows.

## Demoted

- Cursor seeks as a cost measure: the spike's lookup is a vectorized interval
  match, not the shipped cursor. A `k`-column window read costs `k` lookups;
  seek cost on the real cursor is left to WS3.

## Deleted

Nothing in the package. `spike_checker.R` diffs `R`, `src`, `tests`,
`NAMESPACE`, `DESCRIPTION` and `man` against `9452e9e`, and checks those plus
`inst/design` are untouched by the rerun.

## Learned about the package

- Filtering facts by both clocks and handing them to the unchanged rules gives
  every v11 answer: 16 of 16 historical rows and the diagonal on all seven
  fixtures.
- **The default status depends on row presence.** `facts()` answers
  `unknown` when the family has rows and `active` when it has none
  (`R/availability-provider-prepared.R`, `has_status`), while restrictions use
  the declared-families list. Shipped code never sees the difference, because
  the constructor refuses an empty trading-status family. A history filter
  creates the empty case, so `spike_state()` carries the declaration (a
  labelled override). A representation need, not a rule change.
- **Size is not linear in facts.** Facts that only append cost about three
  segments each, because a new fact splits the open tail interval into three.
  Facts that restate a long span rewrite every interval under it: with `n`
  short and `k` long facts, segments grow about as `n * k` (883 segments for
  40 fact rows, 22 per row).
- Supersession must stay within one source. A one-source chain of three
  different statuses is refused because the conflict check
  (`ledgr_fact_validate_source_conflicts`) excuses only direct supersession
  pairs, while the resolver drops every superseded fact and handles the chain.
  The two disagree; this looks like a validation defect. The check is also a
  pairwise validator, one of the seven named shapes.
- Membership knowledge time cannot be rewritten (probe P2), but it can be
  re-expressed as effective time plus a global knowledge rank, which keeps
  every knowledge-ordered rule intact inside one epoch.
