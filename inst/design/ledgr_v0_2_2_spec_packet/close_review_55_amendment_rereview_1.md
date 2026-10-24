# Workstream 55 amendment focused re-review 1

Mode: independent focused Type 1 re-review of the LDG-3105 corrections at
`97252d6a`.

Verdict: **CHANGES_REQUIRED**.

## Closed from the first review

- Excluded ordinary reads no longer rebuild diagnostic cell evidence.
- Owner preparation is explicit before the first public read and the benchmark
  no longer pre-warms either ordinary manifestation.
- The compiled path exposes an exact test trace of source-value accesses.

## Remaining findings

1. **High: lifetime-restart classification diverged by requested width.** A
   compact request beginning after an inactive interval could report
   `insufficient_observations` while the equivalent explicit-long request
   reported `structural_exclusion`. Carry policy and non-price fields exposed
   the same missing boundary.
2. **Medium: two supposedly bounded structures still grew with omitted input.**
   Missing-cell handling could scan backward through a long source gap, and a
   late-known override allocated over the full source axis rather than its
   dependency columns.
3. **Medium: the benchmark's memo and source-history witnesses were too weak.**
   It compared memo key names rather than values, and the fixed-window source
   check did not bind both complete and adversarial long-gap contexts.
4. **Medium: the source-access detector admitted a compiled bypass.** A direct
   raw source read outside the traced accessor could pass the detector.

No Type 2 decision was required. The accepted correction direction was sparse
lifetime-barrier lookup, dependency-width late overlays, semantic memo-state
comparison, complete plus long-gap source clocks, and one prepared compiled
source handle through which every value read is traced.
