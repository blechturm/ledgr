# Workstream 59 close review

Mode: Type 1 with an independent input check.

Verdict: CHANGES_REQUIRED.

The independent reviewer found the three product directions sound but rejected
the first accounting implementation and parts of its evidence.

## Findings

1. The one-lot arithmetic correction did not govern the actual FIFO book.
   Adversarial multi-lot fills could leave an empty book with a nonzero
   position, or a live residual lot with a zero position; ordinary R and
   compiled accounting could disagree. Canonical position must come from the
   actual post-transition FIFO state.
2. Rendered vignette siblings and README output were stale after adding the
   metric-calendar disclosure.
3. One availability fixture copied the expected metric-context JSON wholesale
   and could hide extra record members. It must normalize only the accepted
   display-label delta.
4. The registered detectors did not cover shorthand metric contexts,
   non-flat annualization, the MODELED headline after reopen or public compiled
   multi-lot accounting.
5. A lot-free position helper and one corporate-action recount created second
   cleanup rules outside canonical FIFO replay.
6. The first helper allocated a position-scale vector on each replayed event
   and caused a measured slowdown. The correction must avoid a new scan or
   per-event allocation.

The review found the display-only calendar marker, four asset-neutral headline
states, unchanged identity boundary and lack of crypto-specific policy clean.
The focused correction review owns confirmation of these six findings.
