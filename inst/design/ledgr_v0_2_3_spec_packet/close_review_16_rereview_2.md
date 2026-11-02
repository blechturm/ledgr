# Focused Re-review 2: Workstream 16 (Cut 7)

- Mode: Type 1, focused independent confirmation, Claude Opus, 2026-11-02
- Correction range: `b92756d6..2a7296cd`
- Source finding: F10 in `close_review_16_rereview_1.md`
- Verdict: **CHANGES_REQUIRED** (F10 closed in code and tests; one new
  low-severity finding, F11, on the public help surface)

No Type 2 concern. F11 is a documentation fix inside LDG-3184.

## Checks Run Here

- `git diff b92756d6..2a7296cd` read in full: `R/strategy-extract.R`
  (7 lines removed), `tests/testthat/test-strategy-schedule.R`,
  `tests/claims.yml` (LCL-0497), `tickets.yml` (WS16 and LDG-3184 evidence),
  and the re-review 1 file.
- `git diff --check b92756d6..2a7296cd`: clean.
- Focused tests: `test_local(filter = '^strategy-schedule$|^strategy-authoring-ws16$')`
  ran 14 blocks (11 + 3): 0 failed, 0 skipped.
- Registered mutation: `Rscript dev/bench/v0_2_2_indicator_history/scripts/mutate.R
  dev/bench/v0_2_3_ws5/mutations.R D6_D7_schedule_inputs <out>` on an isolated
  copy of `2a7296cd`. It applied with 1 hit and was detected. Only the intended
  block failed: `[LTB-0531] construction requires investor inputs and schedule
  queries are pure`.
- Not run: full suite, census, build, `R CMD check`, timing clocks.

## F10 Status: Closed

- `ledgr_run_strategy(trust = TRUE)` now assigns the evaluated function
  unchanged (`R/strategy-extract.R:253`). It has no `ledgr_schedule`
  attribute and no `ledgr_scheduled_strategy` class.
- The verified declaration is still read once through
  `ledgr_strategy_schedule_from_record()` and returned as `strategy_schedule`
  (`R/strategy-extract.R:215-220`). That reader still checks it against the
  stored hash and `config_json`.
- LTB-0506 (`test-strategy-schedule.R:995-1010`) reads the separate field and
  asserts the bare function. It then rebuilds through
  `ws42_with_schedule()`, which calls public `ledgr_experiment(schedule =
  recovered$strategy_schedule, strategy = recovered$strategy_function)`
  (`helper-history-fixtures.R:92-114`). It also requires
  `ledgr_strategy_schedule_hash(rebuilt$schedule)` to equal the durable
  `provenance$schedule_hash`. This is the same hash function that run
  provenance applies to `x$schedule` (`R/availability-policy.R:353`,
  `R/strategy-provenance.R:124`).
- The test fails if the change is reverted, in two ways. The `expect_null` and
  `expect_false` assertions fail directly. The rebuild also fails, because
  `ledgr_experiment()` refuses an attached attribute or class
  (`R/experiment.R:308-314`).
- LTB-0511 (`:1830`) reads `recovered$strategy_schedule`. This makes two old
  attribute readers now use the explicit field.
- LCL-0497 matches the tests. Its scope names the bare function and the
  separate declaration. Its `smallest_failing_change` adds reattachment and a
  blocked public rebuild. LTB-0506 detects both.
- The change adds no compatibility path. It does not change identity, because
  recovery is read-only and the run-side hash inputs are untouched. It
  introduces no optimization antipattern (it only removes code) and adds no
  WS17+ scope.

## New Finding

### F11 (low): the only public route for rebuilding a scheduled run is undocumented

F10's fix makes `extracted$strategy_schedule` the only public way to recover a
run's schedule for a rebuild. LCL-0497 now claims that recovery returns "the
separate declaration needed to rebuild publicly". However, the
`ledgr_run_strategy()` `@return` list (`R/strategy-extract.R:107-126`,
`man/ledgr_run_strategy.Rd`) lists every field except `strategy_schedule`. No
`.Rd` file and no article names the field on this function. The omission
existed before this range. It mattered less while the recovered function
carried the schedule.

Consequence: a user who follows the documented rerun pattern
(`vignettes/reproducibility.qmd:212-227`) on a scheduled run calls
`ledgr_experiment(strategy = trusted$strategy_function, ...)` without
`schedule =`. Per `R/experiment.R:308-324`, that now builds an unscheduled
experiment without any error, which changes the decision cadence and the run's
identity. Before Cut 7, the hidden attribute kept the schedule. At
`b92756d6`, the same call was refused. The intended explicit path is correct,
but the reference documentation does not show it.

Fix: add `\item{strategy_schedule}{...}` to the `@return` list. Say that it is
the verified canonical declaration, or `NULL` for unscheduled runs, and that a
rerun passes it as `ledgr_experiment(schedule = ...)`. Regenerate the `.Rd`.
Optionally, add one sentence to the reproducibility rerun section. Per
re-review 1, a help-text change reruns the package check. Owner: LDG-3184.

## Gate For Closure

- Make the F11 help change and regenerate `man/`.
- Rerun the focused `strategy-schedule` and `strategy-authoring-ws16` files.
- Run `R CMD check --no-manual --no-build-vignettes`.

The code and tests need no further change.
