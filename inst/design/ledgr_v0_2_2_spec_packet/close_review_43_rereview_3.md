# WS43 focused re-review 3 (Type 1), `32bb6525..61842494`

## Verdict: CHANGES_REQUIRED

Correction 3 fixes S1, and its S2 fix does what the maintainer asked. Runs,
sweeps, walk-forward and config building no longer write the session
indicator registry. Dispatch resolves custom definitions from the
experiment's own indicator objects. Config identity and the stored config
are byte-identical to the base tree. Decision (19) now holds in every
session and call order, in both modes. Every path that runs without the
attribute either reproduces the original definition or refuses with
`ledgr_run_hash_mismatch`. None of them silently computes a different
definition.

Two low findings remain. Both concern the test and claim record, and the
product is correct in both cases. LTB-0321 dropped its only built-in
`return_1` assertion without a stated reason, but the closeout says the
decision (19) value assertions are unchanged (T1). LCL-0313's run and sweep
counts do not match the block, so S3 is only partly fixed (T2). Neither
finding asks to reopen a decision, so this is not NEEDS_TYPE_2. This is the
final review of the maintainer-authorized third round, so disposition goes
to the maintainer.

Method:
- Read AGENTS.md, `close_review_43_rereview_2.md`, the Correction 3 section
  of `indicator_history_closeout.md`, Cut 16 decisions (19)-(21), the
  Strict Features and Inspection contract text, and
  `git diff 32bb6525..61842494` in full for `R/`, `tests/`,
  `tests/claims.yml`, the contract, NEWS, both Rd files and `tickets.yml`.
- Traced the attribute through every config path: `ledgr_config()`
  (`R/backtest-config.R:305`), `ledgr_run_experiment()`, `ledgr_backtest()`,
  `ledgr_run_config()`, `ledgr_run_fold()`, `ledgr_run_prepare_config()`,
  registration, `ledgr_feature_defs_from_config()` (the only consumer,
  `R/backtest-runner.R:912`), `ledgr_promote()`, walk-forward test runs
  (`ledgr_run_window()`), `ledgr_run_open()` and the walk-forward
  linked-run reader. `canonical_json()` and `config_hash_payload()` were
  read for identity.
- Probes on source copies (`ws43_rereview3/probes`), with the base tree
  `32bb6525` extracted beside them:
  - `m9.R`, `r1.R`, `r2.R`, `r3.R` (both orders) and `reasons.R`, reused
    from re-review 2.
  - `resume.R`: two stages in separate processes, run under three registry
    states.
  - `registry.R`: registry snapshots and traded feature values, including
    walk-forward.
  - `identity.R`: one process per case, on the base tree and on this tree.
- 4 mutations from the agent's list plus 4 of my own, each restored and
  checked by `cmp` (table below). The agent's CSV was not used.
- Full suite, `tools/check-codebase-contracts.R --mode=check` and
  `tools/check-fold-phase-contract.R` on a separate source copy. Results
  are below. `git diff --check` is clean. The changed lines are ASCII. The
  only non-ASCII file, `tickets.yml`, has the same 6 non-ASCII bytes as at
  base, in valid UTF-8.

## Findings

### T1 (low): LTB-0321 dropped the built-in `return_1` assertion without a stated reason

`tests/testthat/test-indicator-dispatch.R:70-71` (base `:58`);
`indicator_history_closeout.md:584-586`; `tests/claims.yml:3575-3576` (scope and `oracle_class`).

Verified facts:
- At `32bb6525` the block asserted
  `testthat::expect_false(any(builtin_dense$ret == -7))`. Correction 3
  rewrote the block as a per-mode loop. That loop asserts `theirs$sma_50`
  against the oracle but asserts nothing about `theirs$return_1` in either
  mode. Built-in `return_1` values are no longer checked anywhere in
  LTB-0321.
- The closeout says LTB-0321 "drops Correction 2's package-default
  replacement assertions ... its decision (19) value assertions are
  unchanged". The removed line is a decision (19) value assertion, not a
  package-default replacement assertion.
- LCL-0313 still claims it. Its scope says "the built-ins under the same
  ids still compute their own values", and its `oracle_class` lists
  "custom and built-in sma_50 and return_1".
- AGENTS.md requires a stated reason for every change to a registered
  oracle. The other removals have one, but this one does not.

Inference: the dropped line had little power to detect anything. A built-in
fingerprint takes the built-in fast path before any registry or attribute
lookup. The finding is the unstated weakening and the false record
sentence, not a product defect.

Fix: in the loop, add an assertion on `theirs$return_1`, for example the
literal one-session returns of the fixture closes or
`expect_false(any(theirs$return_1 == -7))`. Or state the reason in the
closeout and narrow LCL-0313.

### T2 (low, record): LCL-0313 counts do not match the block (S3 partly fixed)

`tests/claims.yml:3583`. The `cheapest_adequate_lane` reads "fourteen short
public runs and up to three short sweeps". LTB-0321 makes 11 public runs:
five per mode (custom, built-in, and built-in/custom/built-in `sma_3`) plus
the `sma_200` run. It makes at most two sweeps, a one-candidate sequential
sweep and a two-candidate two-worker sweep. The scope and `oracle_class`
now describe the 55-session fixture, the call orders, the registry
snapshots and the refusals correctly, apart from the T1 sentence.

Fix: "eleven short public runs and up to two short sweeps (three
candidates; the two-worker sweep when mirai is installed outside
coverage)".

## Item results

| Item | Result |
| --- | --- |
| S1 bounded reach | PASS. `ledgr_history_feature_width()` returns `max(requires_bars, stable_after)` for bounded definitions and `NA` for history-dependent ones. `m9.R`: the LTB-0322 `level` case is unchanged, and the readiness edge (`requires_bars = 2`, `stable_after = 4`, data from session 9, read of sessions 10-14) is now `TRUE`. `r2.R` against the base tree differs only in that case and in the custom width (2 to 4). Every catalogue width (SMA 3, BBands `up` 3, aroon 4, TTR SMA 3, returns 2, EMA and MACD `NA`) is unchanged. M9 is now detected (A1). Contract, `?ledgr_history_frame`, LCL-0314 and the closeout state the reach |
| S2 attribute paths | PASS. `ledgr_feature_defs_from_config()` is the only dispatch consumer, and every public execution path builds its config with `ledgr_config()` in the same call stack: `ledgr_run()`, `ledgr_backtest()`, `ledgr_promote()` (through `ledgr_run()`) and walk-forward test runs (through `ledgr_run_window()`). Nothing between `ledgr_config()` and the dispatch call rebuilds the list, so the attribute survives. Sweeps and two-worker sweeps do not use the config for dispatch; they run the experiment's resolved definitions directly. Paths that drop the attribute: `ledgr_run_open()` and the walk-forward linked-run reader rebuild the config from JSON, but neither executes features. Only the internal `ledgr_run_config()`/`ledgr_run_fold()` can execute such a config. `resume.R` ran stage A (custom `sma_50` = 42 and `sma_3` = 33, full and partial runs in both modes), then stage B in a fresh process under each registry state. (a) With only the package defaults registered, a rerun of the reopened config and a resume of the partial run from the parsed JSON config both refuse with `ledgr_run_hash_mismatch` ("Registered indicator 'sma_50' no longer matches the fingerprint stored in the run config"). (b) With a different definition (99) registered under both ids, the same calls refuse the same way. (c) With the identical definitions registered, they run and reproduce 42 and 33. In every state, a public `ledgr_run(exp, run_id = <partial>)` resume with a different definition refuses ("config_hash does not match stored run"), and with the same experiment it completes with 42 and 33. Mutation B3 (fold rebuilds the config with `[`) makes LTB-0321 fail through the classed refusal. No silent fallback was found |
| S2 identity | PASS. `identity.R` covered no features, built-ins (`sma_50`, `return_1`, `sma_3`), colliding customs and a fresh custom id, in both modes, with one process per case on the base and this tree. `config_hash` and the derived run id are identical in all 8 cases, and the stored `config_json` is byte-identical once the time-stamped `snapshot_id` is removed. `canonical_json()` ignores top-level attributes, so the two strips (`config-hash.R:29`, `run-registration.R:10`) are defensive: with both removed, the hashes are still identical. Every indicator in the attribute is bound by the def fingerprint in the hash, and dispatch re-checks that fingerprint (`R/backtest-runner.R:1669`), so nothing identity-relevant sits outside the hash |
| S2 no registry write | PASS. Only `.onLoad` and the exported `ledgr_indicator_register()`/`ledgr_indicator_remove()` write `.ledgr_indicator_registry`. `registry.R` covered both modes: the registry is identical after experiment construction, a run, a sequential sweep, a two-worker sweep, a promotion, and one-worker and two-worker walk-forward. Those paths also trade the custom feature sum: fill quantity 80 = 42 + 33 + 5 in the run and in every walk-forward test run, and 42/33/5 is observed in the run, the sweep and the promotion. That includes `brand_new`, an id absent from the registry |
| Decision (19) | PASS. `r3.R` in both orders: the custom run gives 42/-7, the built-in run 130.5/0.0065, and sequential and two-worker sweeps match. The user-user cross-experiment coupling of Correction 2 is gone (custom 43 after custom 42 runs, with no session coupling). Built-in and custom `sma_3` run in either order (102.., 33). After a built-in `sma_200` run, an explicit `sma_200` registration is still returned by `ledgr_indicator_get()`. LTB-0321 covers both modes |
| S3 LCL-0313 | Partly fixed: `oracle_class` and scope describe the current fixture; the lane counts are wrong (T2); the return_1 sentence is T1 |
| Changed oracle LTB-0321 | The registry-writing assertions were removed for a valid reason, since they tested behavior S2 removes. The replacements are stronger: registry snapshots, explicit-registration lookup, `sma_3` in both orders and both modes, and the index refusal. One built-in assertion was dropped without a reason (T1). LTB-0322 is only extended. LTB-0074 and every other registered block are untouched (`test-availability-features.R` is not in the diff) |
| Earlier PASS items | No regression. `r1.R` (decision (20)) and `reasons.R` (decision (21)) give byte-identical output on the base and this tree, and the full suite passes |

## Mutations (source copy, each restored)

Filter `indicator-dispatch|indicator-evidence` unless noted.

| ID | Mutation | Result |
| --- | --- | --- |
| A1 | bounded reach is `requires_bars` (re-review 2 M9) | LTB-0322 fails |
| A2 | `ledgr_config()` registers every indicator with overwrite | LTB-0321 fails |
| A3 | dispatch ignores the experiment's own definitions | LTB-0321 fails |
| A4 | two different definitions under one id accepted | LTB-0321 fails |
| B1 | dispatch reads the registry before the experiment's own definitions | LTB-0321 fails |
| B2 | the stored-fingerprint check for a registered or own indicator is skipped (filter adds `availability-features`, `runner`, `run-continuity`) | no block fails (see notes) |
| B3 | the fold rebuilds the config with `config[names(config)]`, dropping the attribute | LTB-0321 fails |
| B4 | the index never sees an earlier entry (last definition wins, no refusal) | LTB-0321 fails |

All 4 claimed detectors are reproduced.

## Cost and shape

No new loop over bars, pulses, cells or events. `ledgr_feature_indicator_index()`
loops once over the experiment's features at config time and fingerprints
only on a duplicate id, which construction already refuses. So the common
path computes no fingerprint, where Correction 2 computed up to three per
indicator. The S1 change is scalar per definition. The two attribute strips
are constant-cost, and they also keep closures out of `canonical_json()`'s
digest cache key.

## Suite and checkers

- Full suite on a separate source copy after `load_all()`: 1,140 blocks, 0
  failures, 0 errors, one optional skip (Yahoo missing-package path), 12.2
  min.
- `tools/check-codebase-contracts.R --mode=check`:
  `LEDGR_CODEBASE_CENSUS_OK` (helpers 1,807, which matches the committed
  census: two helpers and one environment removed, one helper added). The
  diff of `R/` adds no `availability_active` or other execution-mode branch.
- `tools/check-fold-phase-contract.R .`: `LEDGR_FOLD_PHASE_CONTRACT_OK`.

## Maintainer notes (not findings)

- B2 survives. Once the attribute is gone, the fingerprint check at
  `R/backtest-runner.R:1669` is the only thing that keeps a reopened or JSON
  config from silently running a different registered definition. With the
  check removed, `resume.R` state (b) reruns and resumes both modes with the
  registered 99 instead of 42/33. The product is correct today, and the
  check and its missing test both predate Correction 3. The path is
  internal-only (`ledgr_run_config()` and `ledgr_run_fold()` are not
  exported). One LTB-0321 assertion would pin it: register a different
  `sma_50` and expect `ledgr_run_hash_mismatch` from
  `ledgr_feature_defs_from_config()` on a config without the attribute.
- `R/backtest-runner.R:1620-1623` still says the custom definition "must be
  registered"; it now means resolvable from the attribute or the registry.
- Resuming from a raw JSON string through `ledgr_run_fold()` refuses on
  `alias_map_order` before dispatch. This predates the correction, is
  internal, and does not affect this review.

## Review ratio

Two findings (T1, T2) over three re-reviewed items (S1-S3): 2/3 = 0.667.
Both are low and record-level, and the product behavior they concern is
correct. This closes the maintainer-authorized third correction round, so
disposition of T1 and T2 goes to the maintainer.
