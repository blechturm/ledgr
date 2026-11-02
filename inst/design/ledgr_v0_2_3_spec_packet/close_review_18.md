# Close Review 18: Workstream 18 (WS5 D8/D9 and integrated close)

Mode: Type 1, independent clean-context close review (Claude Opus).
Range: `8086b288..ece1edde` on `codex/cut7-ws5`.
Authority: `tickets.yml` Workstream 18, LDG-3187..LDG-3190; the WS5
synthesis D8/D9; `contracts.md`; the macro plan JSON-audit amendment;
`optimization_coding_style.qmd`; `strategy_authoring_closeout.md`;
`dev/bench/v0_2_3_ws5/`; `dev/bench/timing/records/ws5-timing-1/`.

## Verdict

**CHANGES_REQUIRED.** No Type 2 issue. The design holds: typed sizing
evidence in preallocated vectors, one bounded staging segment, no pulse-loop
JSON, a current-only rule binding, durable-only coverage. The timing
disposition is recorded honestly. Six bounded defects fail acceptance items or
the test-change rule. Each has a small fix.

All probes below used public APIs on the exact head, or a disposable worktree
for mutations. Scripts lived in the job scratch directory. Nothing in the
review tree was changed except this file.

## Blocking findings

### B1 (High). Modifying a helper target now aborts the run

- Location: `R/sizing-evidence.R:85-91`, called from `R/fold-engine.R:918`.
- Failure: the helper attaches `sizing_evidence` to its `ledgr_target`.
  Ordinary subassignment and `pmin()` keep that attribute. The fold then
  compares `rounded_quantity` with the returned target and aborts. Probe on
  head:
  `t <- ledgr_target_rebalance(ctx, weights = c(AAA = .5, BBB = .5)); t["BBB"] <- 0; t`
  and `pmin(t, 10)` both stop the run with `ledgr_invalid_strategy_result`
  "Strategy sizing evidence does not match the accepted decision boundary."
  The same strategies run at base `8086b288`. `c(t)` drops the attribute and
  runs, so the outcome depends on which base-R function the author used. The
  error names an internal object the author never created. `strategy-development`
  teaches `targets[down] <- 0` on `ctx$hold()`, and this is the obvious
  extension to helper targets.
- Why evidence misses it: every D8 fixture returns the helper value unchanged.
  No ticket, contract line or NEWS entry authorizes refusing a modified helper
  target. The condition contract reserves `ledgr_invalid_strategy_result` for
  invalid or contradictory targets, and these targets are neither.
- Minimal fix: at the return boundary, treat a mismatch as the target no
  longer carrying helper intent. Drop the evidence for that pulse and count
  the decision as unavailable intent, using the raw-notice path. Keep the
  structural checks (shape, class, IDs, reason codes) as refusals. Add one
  LTB-0540 case each for an overridden target and a `pmin()` target. If the
  maintainer prefers refusal, that is a new user-facing rule. It then needs
  contract text and a corrective message naming the helper.

### B2 (High). Swapping requested and post-guard quantities is not detected

- Location: `tests/testthat/test-strategy-sizing-evidence.R:55-56,134-135`;
  `dev/bench/v0_2_3_ws5/ownership_matrix.csv:25`;
  `dev/bench/v0_2_3_ws5/mutations.R:175-181`;
  `strategy_authoring_closeout.md:82`.
- Failure: every fixture has requested quantity equal to the post-guard
  pre-floor quantity, because the helper's scale stays 1 throughout. A
  disposable-worktree mutant swapped `target` and `target_before_risk` in the
  fold segment at `R/fold-engine.R:930-936`. It passed all 481 expectations in
  strategy-sizing-evidence, backtest-s3, result-output and
  strategy-context-entrances. The same blind spot covers a helper that sets
  requested = scaled quantity, and a summary denominator that uses requested
  value instead of post-guard value. The synthesis D8 rule ("distinguish the
  author's requested exposure, post-guard pre-floor sizing exposure, and
  rounded exposure") is therefore unprotected. LDG-3187 acceptance item 1
  ("omission or swapping any boundary fails a registered detector") is unmet.
- Inaccurate record: the ownership matrix says the D8 mutation will "swap
  requested and post-guard typed sizing fields". The registered mutation
  actually overwrites `reason_code` with `sizing_rounded`. The closeout's
  description is accurate, so the matrix and closeout disagree.
- Minimal fix: add one fixture where the guard binds. An unavailable held
  instrument's reserved value plus priced requests must exceed the base
  (`R/strategy-helpers.R:620-624`), so `scale < 1`. Pin distinct
  `target_before_risk` and `target`, at helper level (LTB-0539) and on durable
  rows plus the pooled denominator (LTB-0540). Register the swap as a second
  D8 mutation and correct the matrix text.

### B3 (Medium). Summary mislabels helper decisions and exits

- Location: `R/sizing-evidence.R:144-145,175-183`;
  `R/strategy-helpers.R:519-525`.
- Failure 1: a helper pulse that sizes nothing writes no sizing row, for
  example `ledgr_target_adjust()` with no entry and no exit, or a flat empty
  rebalance. The summary counts every decision time without a sizing row as
  "Decisions with unavailable intent". Probe: the article's own pattern-6
  trailing stop, run with its parameters, uses only the helper. Its summary
  reports `Evidenced decisions: 10` and
  `Decisions with unavailable intent: 119` of 129. Every one of those 119 had
  fully observable helper intent (hold). This is the mislabeling that
  LDG-3187 acceptance item 3 and the synthesis forbid. The once-per-run raw
  notice cannot recover which decisions were raw.
- Failure 2: `ledgr_target_adjust(exit = mask)` tags every masked instrument
  `sizing_liquidation`, including those with `position_before == 0`. The
  weighted path distinguishes `sizing_zero_target` from `sizing_liquidation`
  by position; the exit path does not. A natural mask such as
  `exit = ctx$close < x` also writes a sizing row for every non-held masked
  instrument on every pulse.
- Why evidence misses it: LTB-0540 rebalances with weights on every pulse, and
  no fixture has a helper no-op pulse or an exit mask over a flat instrument.
- Minimal fix: (a) count unavailable decisions only from `sizing_unavailable`
  rows. Treat decision times without sizing rows as unavailable only when the
  run's raw notice exists. Otherwise report them as decisions with no sizing
  instruction, or exclude them, and say so in the label. (b) Use the existing
  `position != 0` `ifelse()` for exit rows, or emit exit rows only for held
  instruments. Add one helper no-op pulse and one flat-exit case to LTB-0540.

### B4 (Medium). Article pattern 6 does not run as taught

- Location: `vignettes/strategy-authoring-tools.qmd:877-915`.
- Failure: `trailing_stop()` reads `params$stop` and `params$wait`, but the
  article never supplies them. It builds `trailing_experiment` and never runs
  it or calls the strategy on a pulse. I purled the article; every chunk
  through pattern 6 executes. Running
  `ledgr_run(trailing_experiment)` then fails on the first pulse:
  `1 - params$stop` is `numeric(0)`, so `exit` becomes `logical(0)`, and the
  run stops with "Unnamed `exit` must cover the decision axis."
  With `params = list(stop = 0.05, wait = 5L)` it runs (10 fills). The
  "61 executed chunks" claim is true, but pattern 6, the one pattern carrying
  position facts, declared memory and reset, is never exercised.
- Acceptance impact: LDG-3189 item 1 ("each example is a complete readable
  strategy with its meaningful setup") and the D9 rule "execute the whole
  recipe" are not met. LTB-0544 and `check.R` only look for strings.
- Minimal fix: run it in the article, e.g.
  `trailing_run <- ledgr_run(trailing_experiment, params = list(stop = 0.05, wait = 5L), run_id = "pattern_trailing")`,
  show a few fills, and close it. Add `ledgr_run(trailing_experiment` to the
  LTB-0544 needles.

### B5 (Medium). Sizing-row `reasons` mapping differs from LDG-3187 and is unrecorded

- Location: `R/fold-engine.R:932`;
  `tickets.yml` LDG-3187 scope ("typed sizing categories to reason_code,
  intent_reason to reasons and the constant empty object to detail_json");
  `strategy_authoring_closeout.md:23` ("`reason_code` and `reasons` carry the
  typed sizing category"); `contracts.md` D8 paragraph, which is silent on it.
- Failure: sizing rows store the category twice. The ticket's field list maps
  `reasons` to `intent_reason`. The closeout redefines the mapping without
  recording a deviation. No test pins sizing-row `reasons` either way, so any
  change there is undetected. Acceptance item 1 requires every field and
  reason mapping to be exact.
- Minimal fix: one maintainer choice. Either write the pulse's
  `intent_reason`, or `NA` when absent, to sizing `reasons`. Or amend the
  LDG-3187 scope and the contract to say sizing `reasons` repeats the category
  and intent stays only on the single `strategy_intent` row. The second option
  avoids N copies per pulse and is my recommendation. In both cases, pin
  `reasons` in LTB-0540.

### B6 (Low, rule). Two oracle repins lack a true stated reason

- Location: `tests/testthat/test-indicator-history.R:468-473`;
  `tests/testthat/test-history-frame.R:145`.
- Failure 1: the comment and commit attribute the new golden config hash
  `6cde2b07...` to "LDG-3187 added the sizing-evidence store-format binding".
  `config_hash()` (`R/config-hash.R:1-63`) never reads store-format bindings.
  Re-executing the exact test fixture at base `8086b288` already gives
  `6cde2b07...`, the same as head. The oracle was stale before this range.
  The cause is the earlier Cut 7 configuration-identity change: the payload
  now carries `strategy_state` and `opening`, which the cut's
  identity-impact statement intends.
- Failure 2: LTB-0297 changes `admissibility_reason` for a lifetime-inactive
  member from `lifetime_inactive` to `target_restricted`. This follows from
  `R/history-frame.R:1033-1035`: the flat context exposes only `buyable`, so
  every restriction collapses to the generic reason. LDG-3190 evidence
  attributes only `status_unknown -> target_restricted` (the article row), not
  this oracle. `contracts.md:1929` still promises "the target-restriction
  reason". In practice that is now a single value.
- Rule: AGENTS.md requires each test change to state its own reason. The
  first reason is false and the second is missing.
- Minimal fix: correct the hash comment to the real cause. Add one evidence
  sentence for the LTB-0297 reason change, routing the lost restriction
  specificity to WS6's inspection handoff. Either amend `contracts.md:1929`
  ("`target_restricted` until WS6 restores the specific reason") or restore
  the reason from the prepared availability view.

## Non-blocking notes

- N1. Raw-quantity runs print the decision-exposure diagnostics as `0`
  instead of `NA`, which the test-backtest-s3 snapshot pins as "Requested
  value: 0". That is because the notice row makes `nrow(rows) > 0`
  (`R/sizing-evidence.R:196-199`). A sum over no priced rows is undefined
  intent, not zero intent. Return `NA` when `!any(priced)`.
- N2. "Evidenced decisions" and "Decisions with unavailable intent" overlap.
  A decision with one priced and one unavailable row counts in both. In my
  availability probe, 6 decisions gave 6 + 2. Say so in the label or document
  it.
- N3. The Turtle witness is count-only (741 fills, 1,045 state rows, 691
  payload rows). The trailing port reproduces the frozen `ee377f31`
  `6_baseline.csv` exactly: 58 rows, with side, qty, price and timestamp
  identical. No frozen Turtle fill table exists, so pin a digest of the
  current Turtle fill rows. Then a sizing regression that keeps 741 fills is
  caught.
- N4. The long-window runners (`dev/bench/long_window/lw_run.R:46`,
  `lw_sweepwf.R`) moved from an every-pulse callback with an in-state month
  gate to `ledgr_schedule_month_start()`. Callback and context-build counts
  drop roughly 21x. The first partial month is no longer decided, because
  month-start needs a provable boundary. The closeout says "Their clocks and
  economic purposes are unchanged" (`strategy_authoring_closeout.md:49`).
  Record both as intentional measurement and policy differences under
  LDG-3188 ("list every intentional policy ... difference"), so later
  long-window records are not compared with earlier ones.
- N5. `ledgr_validate_sizing_evidence()` defines a closure and makes three
  `all.equal()` calls on every sizing pulse. That cost is constant per pulse
  and negligible, but `identical()` on unnamed doubles is cheaper and
  stricter.
- N6. Article: pattern 1 hard-codes `DEMO_01`/`DEMO_02` without a `buyable`
  guard, so in an availability run it aborts once either ID is unbuyable.
  Patterns 2 and 3 have no code of their own and refer back to earlier
  functions. LTB-0544's `sub("^### ", "### ", heading)` does nothing.
- N7. `tools/check-codebase-contracts.R --mode=check` rewrites the tracked
  `census/metadata.csv` `source_commit` to `working-tree`. A check mode should
  not dirty the tree. This predates the range.

## Checked and clean

- D8 trace. Helper preallocated vectors, through the validator, through one
  `add_segment` at stage `sizing`, to `run_diagnostics` columns
  `target_before_risk`/`target`/`quantity`/`price`/`position_before`/`reason_code`
  with `detail_json = "{}"`, and on to summary and print. Correct for:
  ordinary rounding; rounded-to-zero addition and liquidation; zero target
  vs liquidation in the weighted path; unavailable (NA intent, held rounded
  quantity); and dense and availability paths. The availability probe with
  `ledgr_valuation_stale(3L)` and a two-session gap matched the accepted
  marks and wrote `sizing_unavailable` rows with NA intent. Omitted segment
  columns take schema defaults (`R/fold-carrier.R:795-818`), so no row
  inherits values. Risk and cash rejection do not relabel sizing (LTB-0542).
  Sweep memory sinks retain no sizing row; promotion reports coverage; resume
  keeps one raw notice; the notice flag is seeded once per run.
- Intent row. `reasons = intent_reason`, `detail_json = "{}"`;
  `ledgr_run_explain()` reads the column with no JSON parse; the old parser
  is removed.
- Store rule. `ledgr_sizing_evidence_rule_version = 1L` is discovered by the
  fingerprint census. A missing marker refuses with `fingerprint_mismatch`
  (LTB-0260). There is no migration or fallback. Schema stays 124 and WS8's
  schema 125 is untouched.
- Hot path. All seven shapes walked on `ledgr_target_size`,
  `ledgr_fold_stage_decide`, the envelope flag, the runner seed query, the
  diagnostic capacity (6N+4, allocated once) and the summary (grouped
  `rowsum`, outside the fold). There is no per-instrument JSON, repeated
  normalization, growing append, per-decision frame or full-axis scan beyond
  the helper's existing full-axis build.
- Migration. The peer dense recipe, the peer report recipe and the internal
  oracle use flat columns, declared `asset_state` and
  `ledgr_strategy_result()`; their crossover semantics are unchanged.
  `semantic_ports.R` runs in 25 s, and the trailing fills are
  exact against the frozen baseline. No `ctx$vec`, `state_prev`,
  `features_wide`, `ledgr_select_top_n` or `ledgr_weight_each` remains on a
  maintained or shipped strategy surface. `ledgr_target_quantity()` keeps its
  classed entrance and refuses plain selections with a class. WS11b routing
  is recorded.
- History fix. `ledgr_history_context_view()` reads the private `.history`
  through `unclass()` only for pulse contexts. A pulse without history still
  raises `ledgr_history_unavailable` (LTB-0302).
- Frozen availability witness. It removes exactly the one D8 notice, asserts
  contiguous `diagnostic_seq`, and validates the typed empty state payloads
  before replacing them. No economic or fill oracle is edited.
- Exports. The exact export inventory (`test-api-exports.R`) and NAMESPACE are
  unchanged in range. The allowlist for `ledgr_passed_warmup()` and
  `ledgr_align_weights()` is in contracts.
- Timing. Both checkers rerun and reproduce the README to three decimals:
  v0.2.2 base PASS, 0.926..1.024; post-WS4a FAIL on five fixed-basket cells,
  1.600..2.762. 144/144 slots per base have identical economic controls. The
  FAIL is recorded as FAIL and routed to the existing macro WS14 owner (macro
  plan lines 330-332 and 460) with no duplicate owner. The fast-profile
  214.22 s is recorded as a miss in tickets and closeout, never called a
  pass. No `ledgr-test-profile` marker changed in range, and new blocks
  match their claims.
- Gates rerun here. Targeted suites on head pass 3,314 expectations
  (strategy-sizing-evidence, store-gate, documentation-contracts,
  availability-fold-witnesses, history-frame, history-continuity,
  strategy-intent-evidence, api-exports, one-execution-path,
  demo-strategies). `check.R` prints `WS5_INVENTORY_OK`; the codebase and
  mode-branch census report OK.
- Not rerun, by instruction: the full review/heavy/fast profiles, the source
  build and R CMD check. I accept their recorded results.
- Scope. No WS6/WS7 implementation, no compatibility reader or alias, no
  unrelated product change. Join J is left open and WS6 receives one flat
  layout.

## Probe record

- Override probe (B1): runs `plain`, `override_one`, `pmin_cap` and `c_drop`
  on head and on base `8086b288`.
- Mutation (B2): swap `target` and `target_before_risk` at
  `R/fold-engine.R:930-936`, then run the four D8/summary/print files. Result:
  0 failures.
- Summary probe (B3): purled article plus the pattern-6 run with parameters
  gave 129 decisions, 10 evidenced, 119 unavailable.
- Article probe (B4): purled `strategy-authoring-tools.qmd`, then
  `ledgr_run(trailing_experiment)` stops with "Unnamed `exit` must cover the
  decision axis".
- Hash probe (B6): the LTB-0309 fixture yields `6cde2b07...` at both
  `8086b288` and `ece1edde`.
