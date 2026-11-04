# Close review 25, re-review 1: WS25 correction (ce749805, ecf8efd6)

Mode: independent focused Type 1 re-review. Scope: the correction `ce749805`
and the evidence commit `ecf8efd6` against `close_review_25.md` (F1-F10).
Concurrent RFC/horizon commits were ignored. E:, private data, the LDG-3209
private rebuild, the rule-16 milestone and the paired H1 gate were not
touched.

## Verdict: CHANGES_REQUIRED

The product corrections are sound. All ten original findings are resolved in
`R/`. Focused suites, the public A0 check, the typed-accounting checker and
the codebase census all pass when executed. Three evidence defects remain:

- The re-recorded A0 freeze records the dividend workload as a failure. That
  silently drops dividend posting and declared-state coverage.
- The F2 witness passes with both production fixes removed. Its registered
  claim states otherwise.
- Several registered tests were changed without a recorded reason.

No Type 2 question arises. The patches are small.

## Original findings

| Finding | Status | Evidence |
| --- | --- | --- |
| F1 censuses/red suite | Resolved | LTB-0259 (31 bindings), LTB-0518 (23 methods), LTB-0550 restart seam, preflight helper test retired, `source_census.csv` regenerated; typed-accounting `check.R` PASS (90/30/22/297). See N3 for unrecorded companion test changes. |
| F2 orphan listing | Resolved in product; witness not failure-sensitive (N2) | Coverage 0 and the empty summary are published at registration (`R/run-registration.R:88`, in the insert transaction) and in the restart transaction (`R/run-resume.R:44`). A real hard-killed RUNNING run (`base::quit()` inside the strategy, then a fresh process) lists and reports `ledgr_run_info()` status RUNNING with `valuation_state` NA. The summary/coverage errors name the run. |
| F3 opening seed | Resolved | `R/backtest-runner.R:582-584`. Mutation: dropping the call fails LTB-0555. |
| F4 fill/session scan | Resolved | `R/execution-timing.R:148-153` uses `match()` plus a duplicate mask, with the same semantics as the loop (NA and duplicate cases checked by reading; LTB-0210 oracle green). The shape detector is an unregistered test (N7). |
| F5 witnesses/evidence | Mostly resolved | The writer-order, P2 next-bar, doc-phrase and lazy-allocation witnesses exist. The P2 branch fires (probe: the first pulse sees close 10, the next bar is 999). The tickets carry evidence. Gaps: N2, N3. |
| F6 stale teaching | Resolved for the named items | Remaining residue is listed in N4. |
| F7 store-wide revalidation | Resolved | `flag_counts`, `sizing_summary` and `completion_info_many` read hashed summaries or physical `stopped` rows. Mutation: restoring `require_coverage` in `flag_counts` fails LTB-0554. Tampered or missing summaries refuse (LTB-0554 at lines 160-189). Detail decodes still validate fully. |
| F8 eager buffer | Resolved | `can_encode` gates allocation. Mutation: forcing `can_encode <- TRUE` fails LTB-0554. Durable writers still allocate at construction, which is acceptable. |
| F9 in-pulse permutation | Resolved for the stated mutations | The window check is at `R/diagnostic-decoder.R:138-158`. Mutation: disabling it fails LTB-0558. Probe: swapping `execution_seq` refuses, and a legitimate three-fill pulse decodes. See N5 for a residual case. |
| F10 split-store reads | Resolved | `ledgr_backtest_read_connection()` attaches the snapshot READ_ONLY with TEMP views. This is the normal split-store path, not a fallback. Mutation: removing the attach fails the runner-snapshots test. |

## New findings

### N1. High (LDG-3209 readiness): the A0 dividend workload now freezes a fixture error

`dev/bench/v0_2_3_output_freeze/fixtures.R:91-95` still returns
`state_update = list(observed_cash = ctx$cash)` without declaring the field.
The `hold` and `add` candidates both fail at the first pulse on the run and
sweep paths with `ledgr_invalid_strategy_state` ("Strategy state update
contains undeclared fields: observed_cash."). The evidence is in
`records/dense_dividend_state/run/runs.csv`, `run_conditions.csv` and
`run_diagnostics.csv`. `ce749805` re-recorded this as the frozen truth:

- the equity, fills, trades and metrics records were deleted;
- no dividend CASHFLOW remains;
- `agreement.csv:75-82` counts failure agreement.

The workload's declared purpose (`fixtures.R:260-261`, `inventory.md:84`) is
cash-dividend posting plus fold-local state, and that is no longer frozen. The
`swap_events` gut moved off this workload. The A0 closeout's gut table also
disagrees with `guts.R` and `gut_results.csv`:

- `closeout.md:117` should name the `<error>` refusal;
- `closeout.md:118` should name dense_cost;
- `closeout.md:120` should name the dense_cost FILL swap;
- `closeout.md:130` should name the `<error>` refusal;
- `closeout.md:133` should name the failures run, not run_abort.

`check.R` passes (190 checks, 2 differ, byte-identical) only because the
failure itself is what was recorded.

Fix: declare the state field in the fixture, then re-record. Add a harness
guard so that a workload whose candidates are not meant to fail cannot freeze
FAILED. Correct the closeout gut table, then re-run `check.R` and `gut.R`.

### N2. Medium: the F2 witness passes with both production fixes removed

LTB-0557 (`tests/testthat/test-diagnostic-decoder.R`, "registered nonterminal
runs publish empty evidence") calls `ledgr_diagnostic_initialize_run()` itself
after deleting the evidence. It never exercises registration or restart.

In-memory mutation: replace the call at `R/run-registration.R:88` and the call
at `R/run-resume.R:44` with `NULL`. `test-diagnostic-decoder.R`,
`test-run-continuity.R` and `test-experiment-run.R` all stay green. Under the
same mutation, a real hard-killed run makes `ledgr_run_list()` refuse with
"Run diagnostic summary evidence is missing or duplicated for run
`orphan-mutant`". So LCL-0543's `smallest_failing_change` ("omit birth-time
summary evidence") is false.

Fix: create the orphans through production, then list:

- CREATED: call `ledgr:::ledgr_run_registration()` directly.
- RUNNING after a restart: call `ledgr:::ledgr_run_restart_nonterminal(is_restart = TRUE)`
  on a finished run, then set `status = 'RUNNING'`.

Do not call the initializer from the test.

### N3. Medium: registered test changes without a recorded reason (AGENTS.md test rule)

`ce749805` changed these tests. None of them appears in
`per_pulse_restart_decoder_closeout.md#retired-and-migrated-tests` or in the
ticket evidence:

- **LTB-0138** (`test-ledger-writer.R:170-174`). The setup now forces
  `sink$preserve_diagnostic_seq <- FALSE`. No production sink has that
  setting: both the DuckDB and memory sinks set TRUE
  (`R/output-handler.R:88,223`). The test now protects a dead branch
  (`R/output-handler.R:623-629`), and LCL-0138's "durable allocation" claim no
  longer describes shipped behavior.
- **LTB-0190** (`test-selection-visibility.R:349-352`). The query-count oracle
  changed from 3 to 7. The count is still constant in the number of runs, but
  the reason is recorded only inline.
- **LTB-0281** (`test-risk-fold.R:205-206`). The P3 packet census gained
  `diagnostic_decision` and `diagnostic_risk`.
- **The ambient-RNG restart test** (`test-experiment-run.R:275-291`). Handles
  are now rebuilt with `new_ledgr_backtest()`, and the equity comparison now
  strips `run_id`, `event_id` and rownames.

Fix: delete the dead generic sequencing branch, then retire or migrate
LTB-0138, for example to the exception-row sequence after rollback. Record
every listed change with its reason in the closeout and `tickets.yml`.

### N4. Low: residual continuation wording and dead residue not caught by LTB-0555

- **User-facing conditions.** `R/run-registration.R:120,129,132,135` still say
  "Refusing to resume: ...". LDG-3206 asks condition searches to detect this.
- **Stale comments.**
  - `R/fold-engine.R:195,1699,1895-1896`;
  - `R/availability-economics.R:189-192`;
  - `R/corporate-action-settlement.R:23`;
  - `R/output-handler.R:383`;
  - `R/walk-forward.R:1350`.
- **Dead after restart.**
  - `existing_postings`/`existing_events` reads and `start_idx` at
    `R/backtest-runner.R:815-817`. The ledger holds only opening events, and
    `start_idx` is always 1.
  - The `start_idx > length(pulses_posix)` arm at `R/fold-engine.R:1894`.
  - The exit guard's "publish empty evidence" arm at
    `R/backtest-runner.R:297-322`. Registered runs now always have coverage.

### N5. Low (maintainer choice): `decision_order` is self-anchored

Execution order is anchored to `ledger_events` through `event_seq`. Decision
order is not anchored to any other table. Probe: swapping `decision_seq` and
`decision_order` together between two implicit fills of one pulse decodes
silently, and the in-pulse decision order changes. Either anchor
`decision_order` to an external ordinal (context/universe position) or record
that a coordinated rewrite of a row's own ordinal is out of scope.

### N6. Low: corruption errors can misname or omit the run

The sequence error names `run_ids[[1L]]`, not the offending run
(`R/diagnostic-decoder.R:155`). The association error names no run
(`R/diagnostic-decoder.R:135`). Multi-run decodes (frozen runs in
`ledgr_run_assumption_flags_many()`) can misattribute.

### N7. Low: detector attribution

The closeout says LTB-0210 owns "its vectorized shape". The shape assertion is
in the unregistered test at `test-availability-execution-timing.R:256-261`.
LTB-0210 owns the semantics only.

Info, no action: `run_diagnostic_implicit` gained `decision_order` under codec
rule 1 between two unreleased commits. A store from `aadd2fc3` is refused by
catalogue validation, so this is not a compatibility gap.

## Commands and mutations

Executed with plain `Rscript` and `pkgload::load_all()`. Mutations were
applied in memory to the namespace; no repository file was edited.

- **Focused files, all green.** Decoder, run-continuity, store-gate,
  ledger-writer, execution-timing, runner-snapshots, typed-accounting-boundary
  and strategy-preflight.
- **Mutations, detected.**
  - seed call removed: LTB-0555 fails;
  - order check disabled: LTB-0558 fails;
  - eager buffer forced: LTB-0554 fails;
  - split-store attach removed: runner-snapshots fails;
  - `require_coverage` restored in `flag_counts`: LTB-0554 fails.
- **Mutation, not detected.** Both birth-evidence calls removed (N2).
- **Probes.**
  - real RUNNING orphan from a hard quit lists cleanly (unmutated), and breaks
    listing under the N2 mutation;
  - execution_seq swap refuses;
  - the coordinated decision swap decodes (N5);
  - the LTB-0556 P2 branch fires.
- **Checkers.**
  - `dev/bench/v0_2_3_typed_accounting/check.R`: PASS (90 seams, 30
    accounting, 22 diagnostic, 297 frozen files);
  - `dev/bench/v0_2_3_output_freeze/check.R --agreement=<scratch>`: PASS, 190
    checks, 2 differ, byte-identical;
  - `tools/check-codebase-contracts.R --mode=check --output=<scratch>`: OK
    (2,008 helpers, 2,485 conditions, 89 findings).
- **Full suite.** 1,347 blocks. Under the Git Bash C locale, 4 blocks failed:
  LTB-0408 and LTB-0416 (a YAML encoding parse error), LTB-0247 (latin1),
  and the sweep-retention UTF-8 id escape test. All four pass when rerun with
  `Sys.setlocale("LC_ALL", "English_United States.utf8")`, so they come from
  the reviewer's environment, not the candidate. This agrees with the claimed
  green 1,347.
- **Not run.** R CMD build and R CMD check, and `gut.R`. Its committed
  results were compared against `guts.R` by reading.

## LDG-3209 readiness

Not ready. The public A0 record must first freeze a completing dividend
workload, and the closeout gut table must match the code (N1). The F2 witness
must be made failure-sensitive (N2), and the test-change record completed
(N3). After that, the public candidate is ready for the maintainer's private
rebuild, the rule-16 milestone and the paired H1 gate. None of those were
assessed here.
