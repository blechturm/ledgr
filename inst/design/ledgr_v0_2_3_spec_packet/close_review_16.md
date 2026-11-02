# Close Review: Workstream 16 (Cut 7)

- Mode: Type 1, independent clean-context Claude Opus, 2026-11-02
- Range: `bb7004b5..9e41d058` on `codex/cut7-ws5`
- Tickets: LDG-3182, LDG-3183, LDG-3184
- Verdict: **CHANGES_REQUIRED**

No Type 2 concern. The accepted D3/D4/D6/D7 design is implementable as
written; every finding below is a product, detector, teaching or evidence
correction inside the accepted decisions.

## What Was Checked

- Hand-checked `ledgr_target_size()` (`R/strategy-helpers.R:369-602`)
  against synthesis D3: P/A/U reservation, both capital bases, required versus
  defaulted base, leaver precedence (character keep, then `index_leavers`, then
  logical keep), contradictions, zero weights without price lookup, unpriced
  preservation and the guard. The LTB-0530 oracles reproduce by hand (for
  example 810 remaining equity for the once-only case, 0.875 guard scale).
- `ledgr_select_*()` and `ledgr_weight_equal()` return plain `character` and
  plain named `double` values with the specified empty shapes and no wrapper
  class. `ledgr_select_held()` and `ledgr_weight_each()` did not exist at
  `bb7004b5`, so their retirement is vacuous. `ledgr_select_top_n()`,
  `ledgr_signal_feature()` and `ledgr_strategy_schedule()` are gone from
  NAMESPACE, R, man and vignettes. The LDG-3180 private vec adapter is gone.
- Investor inputs: missing `opening` and missing `cost_model` refuse with
  messages naming the constructors. Zero cash with holdings constructs and
  runs. A parse-data scan of all 75 `ledgr_experiment()` calls in vignette
  chunks and roxygen examples finds explicit `opening` and `cost_model`
  everywhere except the intentional missing-cost `try()` example in
  `R/cost-model.R`. The only internal construction is snapshot-form pulse
  inspection, whose synthetic cash is labelled inspection-only. The 305
  mechanical `cash = 100000` insertions keep the former default value. No
  insertion changes meaning; the few `cash = 1000` edits sit in tests that do
  not depend on cash.
- Gates reproduced here: focused `strategy-authoring-ws16`,
  `strategy-schedule` and `run-continuity` (26 blocks, 0 failures);
  `tools/check-codebase-contracts.R --mode=check` gives
  `LEDGR_CODEBASE_CENSUS_OK` (helpers 1980, conditions 2482);
  `dev/bench/v0_2_3_ws5/check.R` gives `WS5_INVENTORY_OK`.
- Mutations: I ran 11 isolated-copy source mutations through the existing
  `mutate.R` driver (specs are in the job scratch directory, not committed).
  Detected: double reservation, guard removal, default leaver keep, due answered
  from its own weekday calendar, removed plan cost disclosure, target-weight
  normalization, removed ineligible-buy check, and radix-to-shell tie order
  (caught by LTB-0229). Survived: fraction ceiling and weight redistribution
  (F3).
- Seven shapes: the target verbs are vectorized per call, with no R-level
  instrument loop and no per-pulse JSON. The fold adds one prepared query
  service per candidate and one small closure per pulse. F2 is the only
  repeated-work shape found.

## Findings

### F1 (high): `ledgr_schedule_due()` answers in a bar-native run but refuses in the same candidate's sweep

`R/backtest-runner.R:906` passes `schedule_sessions = availability_sessions`,
which is a synthesized bar-native session axis in fixed-basket runs.
`R/sweep.R:1693-1697` passes `NULL` unless the clock is `declared_sessions`.
Probe: `ws42_dense_snapshot()` with a strategy that calls
`ledgr_schedule_due(ctx, ledgr_schedule_weekday("wednesday"))`.
`ledgr_run()` completes and returns TRUE on 2021-01-06. `ledgr_sweep()` on the
same experiment FAILS with `ledgr_strategy_error` ("A strategy schedule
requires a declared venue-session axis"). So run and sweep diverge. The run
also answers from an axis that the contract and experiment construction do not
accept as an authoritative parent axis.

Fix: give the runner the sweep's rule. Pass sessions to the query only for
declared sessions, preferably through one shared expression. Add a
bar-native run-and-sweep refusal witness to LTB-0531.

### F2 (medium): the due query hashes on every pulse when a strategy uses two declarations

`R/strategy-schedule.R:126-169` caches only the last declaration. A callback
that checks a weekly and a monthly schedule alternates declarations, so every
call misses `identical()` and recomputes `ledgr_strategy_schedule_hash()`.
Measured on the 8-pulse declared fixture: 17 hash calls and 2 compiles. Each
call also validates the declaration twice, once in `ledgr_schedule_due()` and
once in the closure. The ticket brief requires no per-pulse hash or compile.

Fix: validate once, and keep the compiled masks in a small list matched by
`identical()` before falling back to the hash. Add a call-count witness with
two alternating declarations.

### F3 (medium): two named smallest-failing changes are not detected

- LCL-0519 names "round a fraction up". Mutating `floor` to `ceiling` in
  `ledgr_select_ranked()` passes LTB-0529, because the only fraction case is
  4 x 0.25, an exact integer (`tests/testthat/test-strategy-authoring-ws16.R:22-25`).
- LCL-0520 names "redistribute an unavailable request", and LDG-3183's
  acceptance requires the redistribution mutation to fail. Scaling priced
  requests by the skipped weight share passes LTB-0530. The only
  mixed priced/unpriced case (`:213-220`) is guard-bound, so redistribution
  and the guard give the same 70.
- LCL-0519 also says its oracle covers "mixed-case ties", but `A` versus `z`
  sorts the same under C and English collation. LTB-0229 is the block that
  actually detects locale order, so cite it or use a discriminating pair.

Fix: add a non-integer fraction case, such as 3 x 0.5, which must give 1.
Add an unguarded skip case, such as `AAA = 0.4` with unpriced unheld
`MISS = 0.2`, where AAA must stay at 40% of the base. Correct the LCL-0519
independence text.

### F4 (medium): WS16 detector and gate evidence is not registered

- `dev/bench/v0_2_3_ws5/ownership_matrix.csv` rows `D3_target_verbs`,
  `D4_selection_weights` and `D6_D7_schedule_inputs` still say
  `pending_WS16`, and their mutation command is the non-detecting `check.R`.
- `mutations.R` contains no WS16 family, and `check.R` requires real mutation
  commands only for `D1_*`/`D2_*`. Cut 7 states that "a source census alone is
  not detecting evidence".
- `tickets.yml` LDG-3182 through LDG-3184 have no evidence field. The gates
  the implementer reported are not in the ticket authority: focused tests, the
  fast run with its 216.92 s host timing miss, census, build, the
  infrastructure-incomplete review profile, and package check not rerun after
  three docs fixes.

Fix: register WS16 mutation families. The detected mutations above are ready
candidates once F3 adds blocks for the two that survived. Flip the three rows
to implementation and detector paths. Extend `check.R`'s implemented-family
set. Record the gates in the ticket evidence, with the timing labelled as
exceeded and descriptive, not passed.

### F5 (medium): registered blocks were migrated through test-local shims of the retired grammar

`tests/testthat/helper-history-fixtures.R:101-154` defines four shims:
`ws16_target_from_legacy_call`, `ws16_select_top_for_legacy_test`,
`ws16_weight_equal_from_legacy_selection` and
`ws16_attach_schedule_to_strategy_for_legacy_path_test`. They are used 55
times in `test-strategy-context-entrances.R` (LTB-0085/0087/0088/0095/0097),
16 times in `test-strategy-schedule.R`, and in the minimum-variance,
pulse-seed and position-facts files. The shims:

- swap a weights-first call into ctx-first;
- re-inject eligibility from a `ledgr_signal` attribute;
- fabricate `member = TRUE`, `position = 0` and `holding_value = 0` when the
  fixture lacks them;
- silently choose `index_leavers = "keep"` and
  `capital_base = "remaining_equity"`;
- strip `origin` and `sizing`.

Those registered blocks now prove the shims' implicit policy, which is the
hidden default D3 rejects, rather than the product's explicit API. The
AGENTS.md test-change rule requires a stated reason for each change, and none
is recorded. LTB-0095 also inverts its oracle: `attr(feature, "eligible")`
became `expect_null`. LCL-0095's scope still reads "Registered-feature
signals carry raw scores and the eligibility plane".

Fix: call the public verbs directly, with the explicit leaver and base choice
written at each call site. Delete the argument swap and the fabricated-field
defaults. Use `schedule =` instead of attribute attachment (see F8). Restate
or retire LCL-0095. Record the per-block reasons in LDG-3183/3184 evidence.

### F6 (low-medium): migrated teaching contradicts D4 and the new contract text

`vignettes/articles/why-r.qmd:51-55` and
`vignettes/causal-history.qmd:99-105` pipe `ledgr_signal_return()` into
`ledgr_select_top()` without `within = ctx$buyable`. `ledgr_select_top()`
ignores the signal's `eligible` attribute, so an ineligible top-ranked ID now
aborts at the rebalance buyable check. The retired `ledgr_select_top_n()`
excluded it. `contracts.md` now states "ranking examples state
`within = ctx$buyable`".

Fix: add `within = ctx$buyable` to both examples and re-render.

### F7 (low): the disclosure is narrower than the contract states

The contracts amendment says experiment and plan printing "disclose effective
scheduling and sizing defaults". In fact `print.ledgr_experiment` and
`print.ledgr_experiment_plan` (`R/experiment.R:677`,
`R/availability-policy.R:385-389`) print no schedule line when the schedule is
omitted. The every-pulse default is therefore undisclosed. Costs print only as
`type_id`, for example "supplied (chain)", which does not identify the model.

Fix: print the omitted-schedule default and the `ledgr_cost_describe()`
summary, and pin both in LTB-0531. Otherwise narrow the contract sentence to
what ships.

### F8 (low): a hidden schedule-attribute entrance survives `ledgr_strategy_schedule()` retirement

`ledgr_experiment()` honours a user strategy that already carries
`attr(, "ledgr_schedule")`. With `schedule = NULL`, the strategy skips the
declared-sessions construction check (`R/experiment.R:308-317`), and the runner
and sweep still read the attribute. With `schedule =` also supplied, the
attribute is silently overwritten. Tests rely on this path.

Fix: refuse a strategy that already carries a schedule attribute, so
`schedule =` is the only public entrance. The classed internal declaration
stays as D6 allows.

### F9 (low): stale or incomplete help

- `R/strategy-helpers.R:258-278` still contrasts "dense" with
  "availability-aware" runs. It says weights apply "after reservations"
  whatever the capital base, and it does not state FR1's lowest precedence for
  a logical keep where the leaver policy is taught.
- `ledgr_target_adjust` has no `\value` or example.
- `ledgr_schedule_due` has no example.
- `git diff --check` flags a blank line at EOF in `man/ledgr_target_adjust.Rd`.

## Non-Blocking Notes

- N1: `ledgr_target_quantity()` still requires a `ledgr_selection`, so it
  cannot consume `ledgr_select_top()` output. Context-mode
  `ledgr_selection(where =, missing =)`, the "context selection/missing-policy
  ceremony" D4 retires, has no Cut 7 owner: LDG-3182 lists only four helpers,
  and decision (5) defers broader pruning to WS11b. This is a routing decision
  for the maintainer (LDG-3189/3190 inventory or WS11b), not a design gap.
- N2: in the re-rendered `vignettes/causal-history.md`, row 8 of the returns
  matrix changes `status_unknown` to `target_restricted`. No WS16 R change
  touches those reasons. The article was last rendered at 29188f87, so the
  change most likely comes from the WS15 corrections. LDG-3190 should attribute
  it.

## Gate Decision (Brief Item 6)

Targeted verification is not enough for the correction candidate. Since the
last package check, NAMESPACE, Rd, examples and three docs fixes all changed,
and only `R CMD check` executes the examples. The minimal gate set on the
final correction candidate is:

1. the focused WS16 files and the registered WS16 mutations (F3/F4);
2. the ordinary fast profile;
3. the census;
4. `R CMD build` plus `R CMD check --no-manual --no-build-vignettes`;
5. the review-profile blocks in the test files this workstream changed, if
   the full review profile is still infrastructure-blocked.

The 216.92 s fast-profile timing is a descriptive host miss under macro rule
16, not a correctness failure. It must be recorded as exceeded.

## Per-Ticket Acceptance

- LDG-3182: semantics, return types and retirement pass. F3 (fraction
  detector) and F6 (teaching) are open.
- LDG-3183: D3 semantics pass on hand checking. The memory-sink pin exists in
  `test-run-continuity.R`, and the vec adapter is deleted. F3 (redistribution
  detector), F5 and F9 are open.
- LDG-3184: required inputs, zero-cash opening, pulse labelling and schedule
  identity pass. F1, F2, F7 and F8 are open.
- Workstream evidence: F4 is open.
