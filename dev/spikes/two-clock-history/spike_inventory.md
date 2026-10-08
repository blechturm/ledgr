# Spike inventory: two-clock history

Executor deliverables for
`inst/design/spikes/two_clock_history_spike/charter.md`. Run on 2026-10-08
against the unchanged package code of `9452e9e`.

## What ran

| Artifact | What it does | Evidence |
| --- | --- | --- |
| `probe.R` | section 1 probe, before the charter | `probe_evidence.csv` |
| `spike_core.R` | bitemporal segments: per knowledge epoch, filter facts known by the epoch, hand them to the unchanged prepared provider and membership resolver, write a segment only when an epoch changes it | |
| `spike_runner.R` | builds segments for the seven fixtures, answers the `(s, t)` queries with the facts that decided them, checks the diagonal over ten days, records shape, measures growth under restatement (case 9); `--gut` answers with the shipped diagonal | `evidence/cases.csv`, `evidence/shape.csv`, `evidence/growth.csv`, `evidence/gut/` |
| `spike_checker.R` | reruns both modes into scratch, diffs, compares with `expected.csv`, asserts the gut's named rows, reports the size bound and growth, guards scope | prints `SPIKE CHECK OK` |
| `expected.csv` | sixteen frozen `(s, t)` answers with their v11 basis | |

Harness: `probe.R` 147 lines, `spike_core.R` 133, `spike_runner.R` 199,
`spike_checker.R` 91; 570 in all, within the 1,500-line budget.

## Deviations from the charter

- **No source copy.** Section 3 allowed a scratch copy with one added
  function. None was needed: `spike_core.R` calls the unchanged internals
  (`ledgr_availability_provider_build_prepared`, `ledgr_membership_resolve_at`,
  `ledgr_availability_prepared_membership`) through `ledgr:::`.
- **Case 2 lowers the last fact's precedence.** Three statuses at one
  precedence in one source are refused at construction (recorded as an
  evidence row), and supersession across sources is refused too. With f3 at
  precedence 1 under f1 and f2 at 2, the chain is accepted and
  distinguishing: `(4, 9)` is `quotation_only` if the chain holds, `halted` if
  f1 revived once f2 was superseded.
- **Deciding facts are hashed.** The inspection data replaces supplied fact
  IDs with content hashes, so `deciding_facts` lists hashes for status and
  lifetime; membership lists set IDs and interval instruments.
- **Case 9 added** after the size kill fired, at the maintainer's go-ahead
  (2026-10-08), with three kinds of fixture. Nine shapes, within the cap.
- **Shape omits bytes and revisions;** segment counts decide the size question.

## Gutted path

With the shipped diagonal answering every query, the historical rows collapse
to today's answer: case 1 at `(4, 8)` and `(5, 9)`, case 2 at `(4, 6)` and
case 4 at `(3, 8)` fail, and so do the late-knowledge rows of cases 3, 5, 6
and 7. Under the gut, case 8 compares the diagonal with itself and passes
trivially; it is the normal run's case 8 that tests the representation. The
diagonal stores no segments, so case 9 records `NA`.

## Demoted

- Window-read cost: counting the runner's own lookups said nothing about the
  package and was removed. Seek cost on the real cursor is left to WS3.
- `probe_at = start + 12h` (in `spike_build`) assumes intervals of at least a
  day and knowledge-rank offsets well under 12 hours; true for every fixture.

## Deleted

Nothing in the package. `spike_checker.R` diffs `R`, `src`, `tests`,
`NAMESPACE`, `DESCRIPTION` and `man` against `9452e9e`, and checks those plus
`inst/design` are untouched by the rerun.

## Learned about the package

- Filtering facts by both clocks and handing them to the unchanged rules gives
  every v11 answer: 16 of 16 historical rows and the diagonal on all seven
  fixtures, including the fold's prepared membership for members.
- **Size.** Append-only: about three segments per fact. Long facts that
  outrank many short ones: 22 per fact, 2.1 after merging adjacent equal
  states. Long facts under many short ones: 12 per fact (483 for 40), and
  merging does not help.
- **Default status keys on row presence**, as the v0.2.0.1 spec requires;
  safe in shipped code because empty families are refused; a history filter
  needs the declaration carried separately (`spike_state()` override).
- **Chains.** The conflict check exempts only direct supersession pairs, as
  the v0.2.0.1 spec (section 4.2) specifies; the resolver handles chains. The
  spec does not address chains.
- Membership knowledge time cannot be rewritten (probe P2), but it can be
  re-expressed as effective time plus a global knowledge rank, which keeps
  every knowledge-ordered rule intact inside one epoch.
