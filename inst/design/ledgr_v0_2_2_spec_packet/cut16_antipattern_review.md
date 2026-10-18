# Cut 16 antipattern review: Workstreams 40 and 41

**Scope:** `1913fbba..38219a66`, product code under `R/`.

**Mode:** independent optimization-style review of the accepted causal-facts
and shared-substrate direction.

**Verdict:** CHANGES_REQUIRED.

The semantics mostly held. Six scale or correctness problems needed repair
before Workstream 42 could build on the substrate. The remaining findings were
routed rather than hidden. This file preserves the finding-bearing review under
the M2 rule; later dispositions are recorded at the end.

## High findings

1. **The segment compiler became effectively cubic after one instrument gained
   a second fact.** The family-wide fallback resolved every epoch/break cell by
   looping over every instrument. Status-fact probes took 3.3 seconds at 50 by
   250, 26.7 seconds at 100 by 500 and 91.4 seconds at 150 by 750; a
   lake-shaped lifetime probe took 353 seconds. Compile each instrument from
   only its own boundaries and facts.
2. **Sweep and walk-forward split one bars query and immediately rebound it.**
   At 800 instruments by 1,000 sessions, substrate construction rose from
   1.21 to 9.91 seconds; the `rbind` alone took 5.88 seconds. A larger probe
   measured 115 seconds for the rebind. Keep and pass the unsplit query frame.
3. **Every walk-forward window calculated features to the global final end.**
   The path computed 6.7 times the needed feature cells and was about 2.4 times
   slower than the pre-cut path. Bind calculation to both scoring start and
   scoring end.
4. **A supplied substrate was checked against default history treatment rather
   than the experiment policy.** A strict experiment could consume a carry-5
   substrate, while a matching strict walk-forward could refuse. Reconstruct
   the policy from current config identity and never infer an internal NULL.
5. **Incomplete membership snapshots still replayed their eligible prefix.**
   A 300-set probe rose from 0.12 to 2.85 seconds; a 580-set probe rose from
   0.25 to 64 seconds. Advance each newly eligible header once and update by
   instrument index.
6. **Rebundling resolved facts erased civil-time evidence.** The resolved
   instant survived but the evidence JSON became `{}` and the bundle hash
   changed. Preserve already-resolved civil evidence or refuse the input.

## Medium findings

7. About 41 percent of the lake-scale substrate was duplicated or unread:
   facts existed in both segments and the provider plan; several packet planes
   had no consumer; `gap_type` and `is_synthetic` restated other fields.
8. Second precedence implementations had appeared. In particular, terminal
   evidence remained sticky after a relisting, complete membership reordered
   headers itself and conflicting membership was inferred from reason text.
9. The cut added representation-switch branches across fold, runner, sweep and
   walk-forward paths. Some were redundant; removing the mode split needs the
   later execution-core consolidation rather than another local branch.
10. Availability constructed the complete `ctx$feature_table` every pulse,
    despite the contract permitting the pre-cut schema-only frame.
11. Correction-chain lineage used name lookup per node and was recomputed at
    multiple sites, including families with no corrections.
12. Civil-time resolution repeatedly formatted the same instants and repeated
    venue, calendar and timezone evidence per row and field.
13. Fact-family tamper detection depended on whether another family in the
    bundle happened to carry civil evidence.
14. The known-when-effective rule existed twice. For Date input, one path made
    a close-effective corporate action known at session open. The intended
    edge requires a maintainer decision.
15. Constructors validated and sorted mixed Date/POSIX facts using temporary
    UTC-midnight values that later resolution replaced.
16. The window validator retained a parallel bars/provider/aligned-frame
    representation predating Cut 16.
17. `ledgr_history_substrate_treated_field()` rematerialized and retreated the
    complete prefix on every call, making per-pulse use quadratic.

## Low findings

The review also identified dead substrate helpers and fields, repeated
segment-limit/civil/RNG/Date code, an environment-backed dictionary slower than
indexed matching, repeated packet and feature-mask construction, transient
feature-plane duplication, evidence-inventing fallbacks, inconsistent parent
conditions and a regression when inspecting a bare Date-backed family.

## Disposition

- Commit `1db8b675` repaired the six High findings, added failure-sensitive
  detectors and also aligned terminal state with the winning lifetime fact so
  relisting releases the terminal barrier.
- Commit `16825307` recorded the focused suites, mutations, differential
  checks, corrected fixture ladder and profiles. Workstream 41 was accepted in
  `a915ba66` after the quiet-host fast lane passed.
- Cut 16 decision (17), committed in `9b0b304d`, routes the remaining work:
  Workstream 45 owns fact-pipeline correctness and cost; Workstream 46 owns one
  fact representation, one membership compiler and removal of unread planes;
  Workstream 44 measures eager evidence and worker staging; execution-core
  consolidation owns availability/dense branch removal. The Date
  known-when-effective edge remains an explicit maintainer decision in
  LDG-3073.
