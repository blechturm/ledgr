# Workstream 61 focused re-review 1

**Mode:** focused Type 1 re-review
**Correction range:** `5e834841..846ea532`
**Reviewer:** fresh-context Claude Opus, high effort
**Verdict:** `CHANGES_REQUIRED`

All seven original close-review findings were resolved. The correction
introduced one medium run-discovery regression, plus two nits. No design issue
required Type 2.

## Original findings

- F1 resolved: schedule counts are prepared before terminal recovery and the
  recovery path invokes neither the strategy nor P2.
- F2 resolved: every current reader requires a complete JSON/hash pair,
  classifies malformed schedule evidence, cross-checks the canonical config
  declaration and requires valid counts for scheduled terminal rows.
- F3 resolved: the registered blocks now detect history-view work on a skip,
  omitted reconciliation, extra decision rows, trusted-recovery disagreement,
  either incorrect printed count and all three zero-decision branches. The
  resume oracle carries a real holding and dividend.
- F4 resolved: unscheduled backtest printing does not call the schedule-evidence
  reader.
- F5 resolved: contracts and NEWS name the plan field, exact output and four
  physical run-list columns.
- F6 resolved: the clean records name full commits `e95e966f` and `3c488bc4`,
  reproduce the intended two family deltas and detect 51/51 isolated
  corruptions; the corrected fast record is 577/577 in 108.040 seconds.
- F7 resolved: unused fold-return counts and redundant carried-state
  normalization are gone.

## N1: run information rejected failed and unfinished scheduled runs

**Severity:** medium, product

`ledgr_run_info_from_row()` validated schedule counts for every scheduled row,
regardless of status. A schedule-parameter failure before compilation correctly
stored a `FAILED` run with missing counts, but `ledgr_run_info()` replaced its
real diagnostic with `ledgr_schedule_identity_mismatch`. A manufactured
crashed `RUNNING` row without telemetry failed the same way. This contradicted
the run-discovery contract that missing unfinished telemetry is typed missing,
not corruption.

Required: validate counts only for completed `DONE` or `INCOMPLETE` rows while
retaining provenance/config verification for every status. Add real FAILED and
RUNNING witnesses with verified declarations and missing counts.

## N2: invalid-count detector boundary

**Severity:** nit

The product rejected negative, fractional and infinite counts, but LTB-0506
only covered missing counts. Add at least one negative-count mutation witness.

## N3: review-file whitespace

**Severity:** nit

The first review artifact used Markdown hard-break trailing spaces on three
header lines, so `git diff --check` was not clean. Use plain line endings.

## Record-only observation

The strengthened resume oracle interrupted before the first scheduled decision,
so its ledger and lot evidence was non-vacuous but its strategy state at the
resume boundary was still empty. The general resume suites may own that rule;
making this schedule witness interrupt after its first decision would also pin
the carried-state boundary locally.

## Checks

The reviewer reran the schedule suite, nine targeted persistence/result suites,
26 mutations, both fixture checkers and the fast record. The schedule suite and
targeted suites passed. Two equivalent mutations still failed closed through
other checks; the only relevant survivors were the negative-count detector and
empty-state resume boundary recorded above.
