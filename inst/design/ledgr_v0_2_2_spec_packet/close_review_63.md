# Workstream 63 Close Review

**Mode:** Type 1 with an independent input check.
**Range:** `97bf51fa..c7267173`.
**Reviewer:** Claude Opus, clean non-persistent session, high effort.
**Date:** 2026-10-26.
**Verdict:** CHANGES_REQUIRED.

The teaching direction is correct and the checked-in H1 arithmetic and input
identity hold. The review found no product defect and no Type 2 question. One
evidence gap blocks acceptance; five lower findings require documentation and
record corrections.

The review was static because the restricted reviewer session could not invoke
Bash. It read the sources and checked-in CSV evidence but did not rerun tests,
the H1 checker, rendering or package gates. The focused confirmation must run
the affected checks.

## Findings

### F1 - Medium: off-date diagnostic parity is not proved

The H1 record compares due-date diagnostics and counts scheduled-skip rows, but
does not compare the other diagnostics emitted on skipped dates. Manual arms
record 3,626,398 off-date rows and scheduled arms 195,553, of which 6,849 are
scheduled skips. The large intended difference is the P2 decision and risk
trace produced by explicit manual holds; the retained P1/P4/P5 rows should
still agree.

The correction must record off-date counts by stage, outcome and reason, remove
only manual P2 decision/risk rows, compare every retained row and count, and add
a failure-sensitivity mutation. The original timing record may remain; one
untimed manual/scheduled correction pair is sufficient.

### F2 - Medium-low: LTB-0509 overclaims its source pins

The detector can match prose after removal of the executable weekly decorator,
does not pin schema 124 in NEWS and rejects only the exact former guard text.
It must inspect the labelled executable chunks and pin the current store
version.

### F3 - Low-medium: schedule help is inaccurate and incomplete

Explicit dates refuse outside the parent axis, not merely outside the
executable window. The help omits the five accepted parameter tokens and does
not directly state that the first parent-axis session is not automatically a
boundary.

### F4 - Low-medium: strategy-authoring teaching contradicts its fixture

The article calls the context and panel dense even though the shared snapshot
declares session facts and is availability-aware. It also repeats the strategy
state lead-in and hides session-axis construction required by the visible
snapshot call.

### F5 - Low: NEWS omits the API names

NEWS describes behavior and formats without naming
`ledgr_strategy_schedule()` or the exported `ledgr_schedule_*()` family.

### F6 - Low: records are stale or incomplete

LCL-0421 names LTB-0437 instead of LTB-0509; the closeout does not explicitly
dispose of `research-workflow.qmd` and `causal-history.qmd`, does not distinguish
the 7,193-pulse H1 record from the earlier 7,213-pulse diagnostic arm, and two
benchmark scripts hard-code one user's R library.

## Checks that held

- The H1 strategy body matches the registered residual-performance workload;
  only the opening date moves to the first shared true boundary.
- Snapshot hash `e8cbb805...` matches the registered WS53 input.
- Pair ratios are 0.671, 0.670 and 0.664; their median is 0.670. Manual and
  scheduled medians are 64.94 and 43.14 seconds, a 21.80-second saving and
  1.54 times the earlier 14.17-second lower bound.
- 344 decisions plus 6,849 skips equal 7,193 pulses, with first due date
  1998-02-02.
- Checked-in economic, state and due-diagnostic hashes agree; identity-cost
  medians reproduce as 119 and 174 microseconds.
- No manual periodic guard remains in a vignette.

F1 blocks acceptance. F2 through F6 are bounded corrections within the
accepted design.
