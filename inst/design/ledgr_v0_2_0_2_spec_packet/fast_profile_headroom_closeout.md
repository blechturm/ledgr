# Workstream 19: Fast-Profile Headroom Closeout

**Status:** Agent-provisional; awaiting independent Type 1 close review.
**Tickets:** LDG-2845 through LDG-2849. **Baseline:** `c83e4dc`.

## What Changed

The fast lane keeps the smallest failure-sensitive evidence needed on an
ordinary edit. Three rare recovery integrations now run in review, which is
selected nightly and at release:

- LTB-0069 preserves incomplete terminal evidence when prefix metrics fail;
- LTB-0070 closes completed walk-forward handles without masking the original
  terminal error; and
- LTB-0072 rebuilds deleted derived state through the low-level
  `ledgr_state_reconstruct()` boundary and verifies the persisted equity rows.

The scalar-accessor claim was split rather than moved wholesale. Fast
LTB-0067 retains warning multiplicity, payload and false-positive controls.
Review LTB-0071 owns the full durable differential over fills, equity and run
identity. Fast LTB-0014 retains canonical-R versus compiled spot-FIFO parity
over partial and open-ended accounting transitions with a smaller six-pulse,
two-candidate fixture. Review LTB-0017 retains the removed flat candidate and
the full eight-pulse retained-series matrix. LTB-0046 remains fast at 20 and
200 fact rows because smaller populations did not make its fixed-work detector
cheaper.

No production file, test gate, timeout or public contract changed. No oracle
was deleted. Claims LCL-0069 through LCL-0072 register the moved and split
evidence.

## Failure Sensitivity

The registered mutations were observed, not inferred:

- replacing prefix metric classification with a generic error failed
  LTB-0069's exact class assertion;
- allowing close failure to escape failed LTB-0070 by masking the original
  interrupt;
- resetting or lowering the scalar-warning guard, counting a plane read, or
  restoring unnecessary small-universe tracking failed fast LTB-0067;
- changing scalar execution after warning emission failed review LTB-0071's
  output differential;
- truncating retained sweep returns failed all four LTB-0014 comparisons;
- restoring row-wise rule-2 payload work failed both LTB-0046 call-count
  assertions; and
- returning one rather than two reconstructed positions failed LTB-0072.

The low-level recovery fixture and all five assertions in LTB-0072 are
unchanged. Its direct SQL row count remains an independent persistence oracle.

## Block Clocks And Census

Representative final clocks were 4.59 seconds for fast LTB-0067, 2.75 for
fast LTB-0014 and 3.24 for fast LTB-0046. The final review run clocked
LTB-0069 at 1.92 seconds, LTB-0070 at 2.51, LTB-0071 at 4.49, LTB-0072 at
0.25 and the full retained-series LTB-0017 at 1.17.

The final fast census selected and passed 453 of 453 blocks, with no skip or
failure. The final review profile selected 270 blocks and completed in 403.00
seconds: 269 passed and one optional missing-package path was skipped because
`quantmod` was installed. That skip is declared by the test and is unrelated
to every moved claim. Nightly CI and the release backstop both select review.

## Ordinary And CRAN Gates

The same-session `c83e4dc` ordinary baseline was 175.20, 104.69 and 100.74
seconds, median 104.69. The first run included a 67.48-second finalizer stall;
it is retained in the record and is not used as an effect estimate. Final
ordinary runs were 79.46, 79.72 and 79.23 seconds, median 79.46. The median
improvement is 24.1 percent, and the result meets both the binding 90-second
gate and the non-binding 75-to-80-second engineering target. The independent
ordinary checker passed its registered one-run rule at 79.46 seconds.

The first isolated CRAN-mode record was green but missed its time gate at
108.56, 107.61 and 107.68 seconds, median 107.68. About 29 seconds was charged
to LTB-0072 even though that block took 0.32 seconds alone and 0.24 seconds in
an instrumented full run. A broad explicit connection-and-driver cleanup was
tested and rejected: it did not reliably remove the stall. That experiment
does not ship.

The maintainer authorized one bounded second pass. Routing only LTB-0072 to
review removed the charge without moving it to another block. Against the
newly prepared isolated library at
`C:/tmp/ledgr-ws19-cran-lib-final`, CRAN-mode runs were 78.94, 79.44 and
79.42 seconds, median 79.42. The independent CRAN checker passed its one-run
rule at 78.94 seconds against the unchanged 105-second bound.

The baseline record is at
`C:/tmp/ledgr-ws19-baseline/.tmp/ws19-baseline`. Final records are in
`.tmp/ws19-route-only-probe`, `.tmp/ws19-final-ordinary-gate-route`,
`.tmp/ws19-final-cran-route`, `.tmp/ws19-final-cran-gate-route` and
`.tmp/ws19-final-review` in the implementation worktree. The failed CRAN
record remains at `.tmp/ws19-final-cran`.

## Antipattern Audit And Declined Work

This work changes test selection and two bounded fixtures only. It adds no
production iteration over bars, facts, instruments by pulses, events,
diagnostics or candidates; no one-row frame append; no row-wise timestamp or
JSON work; and no repeated production validation. The smaller sweep fixture
still uses the public execution boundary. LTB-0046 deliberately keeps its
fixed-work contrast rather than replacing behavior with source inspection.

Declined: deleting any oracle; moving migration, compiled parity, hashing,
schema or event-buffer guards out of fast; raising either bound; treating the
first CRAN failure as noise; shipping the unsuccessful driver-cleanup
experiment; and routing any additional test after seeing the final clocks.

Cut 12 has one independent cut review and this planned close review over five
completed tickets, 2/5 = 0.400. A correction re-review would make the count
3/5 = 0.600 and must be recorded rather than hidden.
