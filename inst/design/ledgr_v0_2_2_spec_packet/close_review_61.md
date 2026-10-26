# Workstream 61 close review

**Mode:** Type 1 close review with independent input check
**Range:** `e95e966f..5e834841`
**Reviewer:** fresh-context Claude Opus, high effort
**Verdict:** `CHANGES_REQUIRED`

The fold architecture held. A not-due pulse skipped exactly P2 and P3 while
P1, P4 and P5 preserved the tested economics, entitlement binding, state,
resume and explicit-hold behavior. Schema 124 landed atomically and remained
current-only. Two durable-reader defects blocked the close, followed by bounded
detector, contract and record findings. No design question required Type 2.

## Findings

### F1: terminal recovery overwrote schedule counts (medium, product)

The terminal-recovery return in `R/backtest-runner.R` ran finalization before
the output handler received the compiled decision and skip counts. Finalization
therefore replaced correct telemetry with `NA`. A scheduled run with one
decision and seven skips reopened as `Decision pulses: NA; scheduled skips:
NA`; an unscheduled run took the same path.

Required: compile or otherwise restore the counts before terminal recovery and
add a detecting recovery witness.

### F2: result readers did not verify the complete schedule record (medium,
product)

`ledgr_strategy_schedule_from_json()` treated a missing JSON marker as an
unscheduled run even when a hash remained. Run information, print and summary
trusted the provenance row without comparing it to the schedule in
`config_json`, while `ledgr_run_open()` did not inspect schedule provenance.
The reviewer observed four failures:

- deleting `schedule_json` hid the schedule from information and output;
- changing the declaration and recomputing its hash mislabelled the run;
- malformed JSON escaped as an unclassed error; and
- a missing count printed `NA`.

Required: validate JSON/hash presence as a pair, class parse failures, compare
provenance with the canonical config declaration at every current reader and
refuse missing counts for scheduled terminal runs.

### F3: registered detectors missed six relevant mutations (low-medium)

The schedule suite did not detect rebuilding the history view on skipped
pulses, omitting the reconciliation row, removing the config cross-check from
trusted strategy recovery or printing either count incorrectly. It also lacked
a carried-position zero-decision witness, an assertion excluding extra decision
rows on skipped pulses and a non-vacuous resume ledger/lot witness.

Required: exact output lines, history-reader and reconciliation counters, a
config/provenance mismatch witness, a carried zero-decision resume and a resume
fixture with holdings and a dividend.

### F4: unscheduled print performed an unnecessary schedule read (low)

`print.ledgr_backtest()` queried schedule provenance unconditionally although
`summary()` already guarded on the in-memory declaration. Guard the print path
the same way and pin it.

### F5: contracts and NEWS omitted shipped disclosure (low)

The result and run-discovery clauses did not name the plan field, exact print
lines or the four physical schedule/count columns returned by
`ledgr_run_list()`. NEWS did not name those inventory columns.

### F6: fixture provenance was not durable (low)

Both fixture `meta.csv` files contained a Git unsafe-directory error instead of
a commit. The candidate record also preceded the product commit it purported
to identify. Retake both arms from committed, clean worktrees and correct the
claim that LTB-0506 already covered malformed schedule markers.

### F7: dead counts and one repeated normalization (nit)

The fold returned decision/skip counts that no caller read. A skipped decision
also passed the already-normalized prior state as a new update, causing P5 to
normalize it again. Remove the unused return fields and use the existing null
update branch to persist the carried state.

## Independent checks

- The schedule suite passed before mutation; the ordinary fast profile
  reproduced 577 blocks in 107.700 seconds.
- Twenty-one of 26 mutations were detected. The missed mutations were the
  history-view read, reconciliation row, trusted-recovery cross-check, two
  printed counts and unused fold-return counts.
- A richer read-only probe with holdings and a dividend showed product resume
  parity; the weakness was in the registered oracle.
- The recorded fixture family deltas themselves were exact: only the two
  run-info families changed, by the intended schema and fields.
- Dense execution, explicit holds, current-only refusal, condition aliases,
  the seven-shape walk and unrelated-file isolation were clean.
- The optional-`tidyr` review-profile miss was recorded honestly and did not
  block this workstream, but it was not a passing profile gate.

## Per-ticket result

LDG-3111 passed in product semantics, with the detector corrections in F3
required before close. LDG-3112 remained blocked by F1 and F2; F4 through F6
also belonged to its evidence and disclosure boundary. The required changes
were corrections inside the accepted design, not new product decisions.
