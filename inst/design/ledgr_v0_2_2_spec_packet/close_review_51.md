# Workstream 51 close review

**Mode:** Type 1 close review  
**Range:** `0638d6b3..af42634e`  
**Verdict:** CHANGES_REQUIRED

The independent clean-context review found one detector gap. LCL-0471 claimed
that both availability and dense public walk-forward entry paths were guarded,
but LTB-0481 called public `ledgr_walk_forward()` only for availability and
called the private checker for dense. Restricting the production call to
availability left the owning test file green. The correction adds the dense
public refusal and its no-session-write witness.

Everything else passed. The repaired LTB-0393 tracer observes zero sequential
collections, and changing only the worker guard to `TRUE` produces one
collection and fails the intended count and placement assertions. Renaming any
of LTB-0204, LTB-0454, LTB-0481 or LTB-0482 fails LTB-0483. Old and new scanner
results are exact at 1,842 helpers, 1,581 private helpers, zero orphans and 388
condition classes; an inserted orphan fails LTB-0270. The codebase census,
focused suites, long-window checker and self-test, YAML parse and diff check
pass.

The committed timing record recomputes exactly: all three runs execute 574 of
574 blocks at 106.88, 106.74 and 107.32 seconds, median 106.88. The unchanged
112-second gate passes. The preregistered 106.4-second target misses by 0.48
seconds and still requires maintainer disposition.
