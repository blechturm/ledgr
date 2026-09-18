# Availability Hot-Path Representation - Charter v2 Review

**Status:** Second and final pre-execution structural review.
**Reviewer:** Codex; not the Charter author or lane-profile executor.

## Reviewed source state

- Branch `v0.2.0.1`; HEAD `cb3047b8b45c64e34589b58ef2e8bfb33f5b2cc2`.
- Charter v2 is a new historical successor; Charter v1 and Charter Review v1
  remain present and unchanged.
- Charter v2: exactly 150 lines, ASCII-only, one question, two arms, one kill
  heading, five evidence categories, and one review disposition.
- `git diff --no-index --check` is clean and every cited repository file exists.
- No spike code or evidence was executed in this structural review.

## Verdict

**PASS_WITH_LOW_OBSERVATIONS. Spike execution is unlocked.** Charter v2 closes
B1, B2, M1, and L1 without widening the question, adding an alternative, or
pre-authoring witnesses. This is the second and final Charter review round.

## Prior findings

| Finding | Result | Deciding evidence |
| --- | --- | --- |
| B1: wrong envelope clock | CLOSED | Lines 88-92 bind 1,800 seconds to wall around `ledgr_run()`, identify the external clock correctly, make `t_loop` secondary, and label 4,096 MiB a new Charter stop. |
| B2: undefined 757-pulse fixture | CLOSED | Lines 52-60 bind 563 instruments, 505 members, complete bars, fact families, flat/zero behavior, 757 pulses, and 60 evenly distributed complete lists. |
| M1: conflicting repetitions | CLOSED | Lines 107-120 separate the three-run 40-pulse comparison from one run per arm at 757 pulses, permit the current arm to stop at either ceiling, and add one profiled alternative run. |
| L1: review phases conflated | CLOSED | Lines 135-141 distinguish this Sections 2/4/8 review from the post-execution Section 7 rerun/gut/diff review. |

## Final smell test

- **One question:** PASS. Lines 13-16 reproduce Seed v2's question verbatim.
- **Cheaper prerequisite:** PASS. Lines 20-26 name the lane-profile question,
  answer `DIAGNOSTICS_DOMINANT`, and prohibit 40-to-757 extrapolation.
- **One kill condition:** PASS. Lines 82-92 bind one conditional close-and-route
  outcome, with one conjunctive wall/memory envelope.
- **Two alternatives:** PASS. Lines 49-50 contain only current production and
  one bounded columnar/chunked writer. Base assignment and `setv()` remain
  internal details, not extra arms.
- **Runnable core before cases:** PASS. Lines 30-45 bind one seam, keep provider
  and economics unchanged, cap later failure-derived cases at ten, and contain
  no expected answers, witness rows, or checker.
- **No provenance machinery:** PASS. Lines 94-103 require the protocol's three
  executor deliverables and expressly forbid hash ledgers and workspace gates.
- **Budget:** PASS at the 150-line maximum. The exact-budget result is not itself
  a defect; any execution-stage expansion must remain in its own budget.

## Low observations for execution

### L1 - Alternative profiler attribution must remain complete

Lines 116-119 say the alternative profile uses the lane-profile classifier.
That classifier recognizes current diagnostic functions by name
(`lane_profile_probe.R:139-160`). A new writer helper would otherwise fall into
`residual_fold`. The executor must extend only the classifier's function-to-lane
mapping so every alternative writer sample remains in the diagnostic group.
This implements the Charter's requirement to identify the largest lane; it does
not add an alternative or require a Charter revision.

### L2 - Persist the exact 60-list placement formula

"Evenly spaced sessions from session 1" is sufficiently bounded for the
Charter, but more than one rounding rule can implement it over 757 pulses. The
runner must use one deterministic formula and print the resulting 60 session
indices in its evidence. That is fixture reproducibility, not a new witness or
gate.

## Decision

Charter v2 is the operative spike authority. The executor may now build the
smallest runnable fork and follow the Charter. Charter v1 remains historical.
Do not cut implementation tickets or alter production package code outside the
reviewed spike fork.

After execution, an independent reviewer who did not execute the spike must
perform `spike_protocol.md` Section 7: rerun, gut one path, and diff the
evidence. The brief must contain at most five verifiable items, and a third
review round returns to the maintainer rather than expanding the ask.

## Commands and evidence

```text
git branch --show-current -> v0.2.0.1
git rev-parse HEAD -> cb3047b8b45c64e34589b58ef2e8bfb33f5b2cc2
lines / non-ASCII -> 150 / 0
question headings / arms / kill headings / evidence claims -> 1 / 2 / 1 / 5
Charter disposition count -> 1
git diff --no-index --check -> clean
referenced repository files -> present
```

## Revision history

- 2026-09-15 - Final structural review of Charter v2 at `cb3047b`; all Charter
  Review v1 findings closed. No spike execution or package implementation.

CHARTER_REVIEW_DISPOSITION: PASS_WITH_LOW_OBSERVATIONS
