# Focused Re-review 1: Workstream 16 (Cut 7)

- Mode: Type 1, focused independent re-review, Claude Opus, 2026-11-02
- Original range: `bb7004b5..9e41d058`; corrections: `9e41d058..b92756d6`
- Source review: `close_review_16.md`
- Verdict: **CHANGES_REQUIRED** (one new finding, F10; F1-F9 closed)

No Type 2 concern. F10 is a defect introduced by the F8 correction and has
a small fix inside D6.

## Reproduced Here

- Three registered mutations, run with the existing `mutate.R` driver on
  isolated copies of `b92756d6`: `D3_target_verbs`, `D4_selection_weights`
  and `D6_D7_schedule_inputs` all apply (1 hit each). Each one fails only its
  intended block (LTB-0530, LTB-0529, LTB-0531).
- `dev/bench/v0_2_3_ws5/check.R` gives `WS5_INVENTORY_OK`.
- `git diff --check bb7004b5..b92756d6` is clean.
- Focused correction-relevant files: 65 blocks, 0 failures (details below).
- Not reproduced: fast 636/636, census, build and `R CMD check`. Those
  results exist only as LDG-3184 evidence, which was committed in the same
  candidate. They are consistent with that candidate, but this review did not
  re-execute them.

## Per-Finding Status

- **F1 closed.** One helper, `ledgr_strategy_schedule_sessions()`, returns an
  axis only for `declared_sessions`. It feeds both run compile and query
  (`R/backtest-runner.R:756,906`) and sweep (`R/sweep.R:1693`). In
  declared-session runs, `history_substrate$sessions` is the same axis that
  `availability_sessions` was, so query parity holds there. LTB-0531 shows
  that a bar-native run refuses (`ledgr_schedule_sessions_required`) and that
  the sweep records FAILED with the same declared-axis message. The
  D6_D7 mutation detects a regression.
- **F2 closed.** `ledgr_schedule_due()` validates once, and the query no
  longer validates. Distinct declarations are matched by `identical()` in a
  run-local list before the hash fallback. LTB-0531 counts eight alternating
  calls: 8 validations, 2 hashes, 2 compiles. The per-call `vapply` scans
  only the distinct declarations, not bars or instruments.
- **F3 closed.** The 3 x 0.5 fraction case fails under `ceiling`. The
  unguarded `AAA = 0.4` / unpriced `MISS = 0.2` case requires AAA = 40, and
  redistribution fails it. LCL-0519 now attributes locale ties to LTB-0229.
- **F4 closed.** The three ownership rows name the implementation files, the
  detecting test and the `mutations.R` commands. `check.R` treats D3, D4 and
  D6_D7 as implemented families. The gate evidence labels 211.540 s as
  exceeding the advisory hint, not as a timing pass.
- **F5 closed.** All four `ws16_*` shims are deleted, and no reference
  remains. Registered blocks call `ledgr_select_top()`,
  `ledgr_weight_equal()` and `ledgr_target_rebalance()` directly, writing
  `index_leavers` and `capital_base` at each call site where held leavers or
  preserved exposure make them matter. The remaining comparison helper,
  `strategy_target_values()`, only projects values for oracles and does not
  shape inputs. Target origin is asserted in LTB-0530. LTB-0095 now expects
  a plain flat read and the explicit signal's buyable plane, and LCL-0095 is
  restated to match. Nit: the LTB-0095 block title still reads "feature
  signals carry the admissibility plane".
- **F6 closed.** Both `.qmd` sources and their rendered `.md` use
  `within = ctx$buyable`. The original render did not abort, so no ineligible
  ID ranked top; the added pool therefore cannot change those outputs. The
  other teaching calls either already pass `within` or rank a standalone
  vector.
- **F7 closed.** Experiment and plan print `Strategy schedule: every pulse`
  when the schedule is omitted, and they print the `ledgr_cost_describe()`
  text. Both are pinned in LTB-0531.
- **F8 closed as asked, but it introduced F10.** `ledgr_experiment()` refuses
  an attached `ledgr_schedule` attribute or the `ledgr_scheduled_strategy`
  class. Test fixtures rebuild experiments through `schedule =`.
- **F9 closed.** The rebalance details no longer mention dense mode or
  availability-aware mode, and they state the chosen-base rule. `keep` states
  FR1 precedence. `ledgr_target_adjust` has `\value` and a runnable example.
  `ledgr_schedule_due` has an example. The EOF blank line is gone.
- **N1/N2 routing closed.** N1 is recorded in LDG-3189 evidence: the classed
  `ledgr_target_quantity()` entrance and WS11b pruning, with no adapter. N2 is
  attributed to WS15 in LDG-3190 evidence.

No compatibility path, no WS17+ scope and no new optimization antipattern
appear in the correction range.

## New Finding

### F10 (medium): a recovered scheduled strategy cannot be rebuilt into an experiment

`ledgr_run_strategy(trust = TRUE)` still attaches the stored schedule to the
recovered function (`R/strategy-extract.R:254-259`). It sets
`attr(, "ledgr_schedule")` and adds the class `ledgr_scheduled_strategy`. The
F8 correction makes `ledgr_experiment()` refuse exactly that shape
(`R/experiment.R:308-314`), and the refusal does not depend on whether
`schedule =` is supplied.

Probe at `b92756d6`, using `ws42_history_fixture(schedule =
ledgr_schedule_week_start())`. Run it, recover it with
`ledgr_run_strategy(trust = TRUE)`, then call `ledgr_experiment()` with
`rec$strategy_function`:

- `schedule = NULL` is refused with `ledgr_schedule_identity_mismatch`;
- `schedule = rec$strategy_schedule` is refused with the same error, whose
  message ("Supply strategy schedules through the `schedule` argument")
  tells the user to do what they already did.

The rerun pattern `vignettes/reproducibility.qmd` teaches (extract, then
`ledgr_experiment(strategy = trusted$strategy_function, ...)`) works only for
unscheduled runs. For a scheduled run, the public API now has no way to rebuild
the experiment unless the user strips the internal attributes by hand. Before
the correction, this round trip worked through the hidden entrance. No test
covers it: `test-strategy-schedule.R:997` and `:1820` read the attached
attribute, not a rebuild.

Fix: return the bare recovered function, keeping the declaration only in the
existing `strategy_schedule` field. Point the two schedule tests at
`recovered$strategy_schedule`. Add one LTB-0531 (or LTB-0506) witness:
extract a scheduled run, rebuild it with
`schedule = recovered$strategy_schedule`, and check that the schedule hash
matches the original. Owner: LDG-3184. No gate beyond the focused files, that
witness and the D6_D7 mutation is needed, unless `ledgr_run_strategy` help
text changes, in which case also rerun the package check.

## Focused Test Result

The six correction-relevant files (`strategy-authoring-ws16`, `strategy-schedule`,
`strategy-context-entrances`, `minimum-variance-proof`, `pulse-seed-v2`,
`position-facts-context`) ran 65 blocks: 0 failed, 0 skipped.
