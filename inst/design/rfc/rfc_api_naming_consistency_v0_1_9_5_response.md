# RFC Response: API Naming Consistency And Surface Tightening

**Status:** Response-stage review. Recommends seed v2 before synthesis.
**Date:** 2026-06-12
**Author:** Codex (response-stage reviewer)
**Input:** `rfc_api_naming_consistency_v0_1_9_5_seed.md`

This response pressure-tests the seed against current source, public docs,
contracts, and export locks. It does not redesign the API and does not edit the
seed in place.

---

## 1. Verification Results By Focus Question

### Q3. `ledgr_extract_fills()` vs `ledgr_results(bt, what = "fills")`

The eager ordinary case overlaps, but the streaming surface is not safely
covered by `ledgr_results()`.

Evidence:

- `ledgr_extract_fills()` is exported with public `lazy` and
  `stream_threshold` arguments (`R/backtest.R:1140-1168`).
- Its implementation counts fill rows and can force lazy mode above
  `stream_threshold` (`R/backtest.R:1185-1208`), returning a
  `ledgr_fills_cursor` when `lazy` is true (`R/backtest.R:1410-1412`).
- Cursor cleanup is a distinct lifecycle helper over `ledgr_fills_cursor`
  objects (`R/backtest.R:708-751`), and tests fetch from `cursor$res`
  directly (`tests/testthat/test-fills-streaming.R:150-158`).
- `ledgr_results()` exposes only `bt` and `what`; it has no `lazy` or
  `stream_threshold` parameters (`R/backtest.R:2392-2395`).
- `ledgr_results()` wraps `tibble::as_tibble(bt, what = what)` in
  `ledgr_result_table()` (`R/backtest.R:2392-2395`), and
  `ledgr_result_table()` immediately calls `tibble::as_tibble(x)`
  (`R/result-table.R:1-6`).
- `as_tibble.ledgr_backtest()` opens a read connection and closes it on exit
  (`R/backtest.R:2306-2308`), then routes `what = "fills"` through
  `ledgr_extract_fills_impl(x, con = con)` (`R/backtest.R:2310-2316`).

That last combination matters: if the internal threshold path returns a cursor
while called from `as_tibble.ledgr_backtest()`, the surrounding read connection
is scheduled for close on exit and `ledgr_results()` has no public cursor
lifecycle. There is also no `as_tibble.ledgr_fills_cursor` method in the
current source (`rg "as_tibble\\.ledgr_fills_cursor"` returned no matches).

Recommendation: do not fold this surface into `ledgr_results()` in the naming
pass. Rename `ledgr_extract_fills()` to a run-family accessor such as
`ledgr_run_fills()` and preserve the current lazy/streaming contract. Folding
can be reconsidered only as a separate semantic change that deliberately adds
lazy arguments and cursor lifecycle to `ledgr_results()`.

### Section 2.5. Unexport candidates

| Export | Verification | Response disposition |
| --- | --- | --- |
| `ledgr_backtest_run` | Its own docs say it is a low-level internal runner, most users should call `ledgr_backtest()`, and direct use is not recommended (`R/backtest-runner.R:12-15`). The example is gated under `if (FALSE)` (`R/backtest-runner.R:17-22`). | Confirm unexport direction. Teaching docs do not rely on it as a user door; manual implementation traces mention the internal runner and can keep using `ledgr_backtest_run_internal()` (`inst/design/manual/snapshots_data.qmd:219-222`). |
| `ledgr_backtest_bench` | The seed understates this. It is documented as a session-scoped diagnostic helper (`R/backtest.R:1728-1738`), has a runnable example (`R/backtest.R:1740-1757`), and contracts bind detailed telemetry as session-scoped through it (`inst/design/contracts.md:259-262`). | Do not treat as plain dev tooling. Escalate under D3: either keep public as a low-level diagnostic or unexport only with an explicit replacement/disposition for session-scoped detailed telemetry. |
| `ledgr_create_schema` | It is exported with direct DBI example docs (`R/db-schema-create.R:1-13`). Current teaching/manual surfaces mention it as implementation detail, not as ordinary workflow (`inst/design/manual/snapshots_data.qmd:150-154`). | Confirm unexport direction for public workflow, with docs/test cleanup. Internal tests and helpers use it heavily, so this is a surface cleanup, not a code deletion. |
| `ledgr_db_init` | It is exported with a direct DBI example (`R/public-api.R:45-58`) and used in the `ledgr_state_reconstruct()` example (`R/public-api.R:105-109`). `ledgr_snapshot_load()` uses it internally (`R/snapshots-list.R:189-190`). | Tie to Q4 recovery decision. Do not unexport independently unless the recovery-surface story for `ledgr_state_reconstruct()` is also decided. |
| `ledgr_metric_context_resolve` | Its own docs say it normalizes shortcuts for later run/comparison/sweep paths (`R/metric-context.R:288-297`). Grep found no README, vignette, manual, research-doc, or documentation-contract call site. Public callers can use `ledgr_metric_context()` or shortcut arguments. | Confirm unexport direction. Q5 can be settled: no documented workflow needs this export. |

### Collision check for proposed new names

Exact grep over `R/`, `tests/`, `inst/`, `README.md`, `vignettes/`, `man/`,
and `NAMESPACE` found one real collision:

- `ledgr_snapshot_open` already exists as the internal lazy connection helper
  for `ledgr_snapshot` objects (`R/snapshot.R:61-78`) and is called by
  `get_connection()` (`R/snapshot.R:80-83`).

No exact matches were found for `ledgr_run_compare`,
`ledgr_feature_cache_clear`, `ledgr_run_strategy`,
`ledgr_indicator_register`, `ledgr_indicator_remove`,
`ledgr_indicator_get`, `ledgr_indicator_list`, or
`ledgr_walk_forward_open`. Nearby `ledgr_walk_forward_opening_*` helpers exist
but are not exact collisions (`R/walk-forward.R:58`,
`R/walk-forward.R:517` from grep output).

Disposition: seed v2 must handle the `ledgr_snapshot_open` collision
explicitly. Either the public reopen name needs a different spelling, or the
internal helper needs to be renamed first. As written, the proposal would
collide with existing internal API.

### Section 4. `ledgr_candidate()` dispatch design

The seed is directionally coherent, but one of its premises is too strong:
current sweep results carry identity attributes, not a full locator precedent.

Evidence:

- `ledgr_sweep_results` carries identity attributes such as `sweep_id`,
  `snapshot_id`, `snapshot_hash`, scoring range, universe, seed, feature,
  metric, cost, and risk identity (`R/sweep.R:294-332`).
- `ledgr_candidate()` collects a fixed set of those attributes as
  `sweep_meta` (`R/sweep.R:691-703`), then packages the selected row
  (`R/sweep.R:393-408`).
- Those sweep attributes do not include a snapshot handle or `db_path`.
- The live walk-forward result object contains `session_id`, tables,
  selected rows, degradation, and `test_runs`, but no snapshot handle, db path,
  or snapshot hash attribute (`R/walk-forward.R:151-168`).
- The reopened walk-forward result object is built the same way: it returns
  tables and linked test `run_id` strings, not live backtest handles or a
  locator (`R/walk-forward-inspection.R:15-40`).
- Current walk-forward extraction requires the explicit snapshot and session
  id (`R/walk-forward-inspection.R:64-73`), reads the linked run config through
  that snapshot (`R/walk-forward-inspection.R:105-114`), and verifies session,
  cost, risk, and metric identity (`R/walk-forward-inspection.R:349-360`).
- The underlying reopen path validates the snapshot object and verifies the
  stored session snapshot hash against it (`R/walk-forward-inspection.R:209-240`,
  `R/walk-forward-inspection.R:263-270`).

The Amendment 2 extraction discipline is present in current code and tests:
`fold_seq` is required (`R/walk-forward-inspection.R:68-70`), `"latest"`
requires a rationale and uses class `ledgr_walk_forward_latest_without_rationale`
(`R/walk-forward-inspection.R:509-527`), and tests assert the missing
`fold_seq`, missing rationale, and successful latest extraction paths
(`tests/testthat/test-walk-forward-orchestrator.R:569-589`).

Disposition: a generic `ledgr_candidate(wf, ...)` can be good UX, but it is
not a pure rename. Seed v2 must bind how `ledgr_walk_forward_results` carries
or resolves a snapshot locator and how that survives reopen and closed-snapshot
lifecycle. The current explicit-locator posture is stronger than the seed
states.

### Q2. `ledgr_walk_forward_results()` vs `ledgr_walk_forward_open()`

I recommend `_open`, with a documentation caveat.

The function currently reopens persisted evidence and verifies linked runs:
its docs say it "reopen[s] compact walk-forward evidence from the experiment
store" (`R/walk-forward-inspection.R:1-4`), and implementation calls
`ledgr_walk_forward_read_session(snapshot, session_id, verify_runs = TRUE)`
(`R/walk-forward-inspection.R:15-17`). That matches the `run_open` and
`sweep_open` family more than an ordinary result-table accessor.

The counter-argument is real but manageable: the reopened object returns the
same class as live `ledgr_walk_forward()` (`R/walk-forward.R:151-168`,
`R/walk-forward-inspection.R:15-40`), and reopened `test_runs` are linked
run-id strings rather than live backtest handles (`R/walk-forward-inspection.R:8-13`).
If renamed to `_open`, the help page should preserve that caveat: it opens
compact evidence, not a live session handle.

### Inventory completeness

The seed did not miss any large family of inconsistent exports in the locked
surface (`tests/testthat/test-api-exports.R:4-131`). The named strays, the
indicator registry verbs, the reopen vocabulary, the replay vocabulary, and
the unprefixed six are the right main buckets.

Two details need tighter v2 treatment:

- `ledgr_compute_equity_curve()` is covered by the seed's replay-vocabulary
  question, but not in the Section 2.2 rename table. If R1/R3 later bind
  "zero verb-first artifact methods", the synthesis must resolve it rather
  than leave it implicit (`tests/testthat/test-api-exports.R:18`,
  `inst/design/contracts.md:577-582`).
- `ledgr_ttr_warmup_rules()` is covered by D2, but it is not just a cosmetic
  name. It is in the export lock, pkgdown groups, contracts, and indicator
  vignette (`tests/testthat/test-api-exports.R:118`, `_pkgdown.yml:139`,
  `inst/design/contracts.md:495`, `vignettes/indicators.qmd:739`). If D2 keeps
  `ledgr_ind_*`, this TTR helper still needs an explicit placement rule.

`ledgr_validate_schema()` is verb-first but is a genuine diagnostic over a
schema, not an artifact accessor. `ledgr_compute_metrics()` and
`ledgr_precompute_features()` match the seed's "operation verb earns its
place" carveout.

### Blast-radius accuracy

The seed is right that the blast radius is broad and mostly mechanical, but
some numbers/details need correction.

- `contracts.md` currently has 99 `ledgr_*` tokens across 84 matching lines,
  in a 691-line file. The seed's "~85 citations across 714 lines" is close in
  spirit but not exact.
- Direct contracts rename targets include `ledgr_snapshot_load`
  (`inst/design/contracts.md:199`, `inst/design/contracts.md:208`,
  `inst/design/contracts.md:251`), `ledgr_extract_strategy`
  (`inst/design/contracts.md:423`), `ledgr_clear_feature_cache`
  (`inst/design/contracts.md:519`), `ledgr_compare_runs`
  (`inst/design/contracts.md:563-566`), `ledgr_state_reconstruct`
  (`inst/design/contracts.md:573`), and the fills/equity helpers
  (`inst/design/contracts.md:577-582`).
- Documentation-contract tests lock several old names, including
  `ledgr_snapshot_load` (`tests/testthat/test-documentation-contracts.R:641`,
  `tests/testthat/test-documentation-contracts.R:1050`,
  `tests/testthat/test-documentation-contracts.R:1391`),
  `ledgr_compare_runs` (`tests/testthat/test-documentation-contracts.R:893-899`,
  `tests/testthat/test-documentation-contracts.R:917`,
  `tests/testthat/test-documentation-contracts.R:1043`), and
  `ledgr_extract_strategy` (`tests/testthat/test-documentation-contracts.R:1300`,
  `tests/testthat/test-documentation-contracts.R:1415-1424`).
- `_pkgdown.yml` has explicit entries for walk-forward extraction, fills,
  equity, state reconstruction, comparison, strategy extraction, indicator
  registry functions, TTR warmup rules, and feature cache clearing
  (`_pkgdown.yml:61-64`, `_pkgdown.yml:90-93`, `_pkgdown.yml:103-108`,
  `_pkgdown.yml:135-140`).
- README still teaches `ledgr_extract_strategy()` directly (`README.md:135-144`).

Disposition: the seed's "contracts.md is a first-class rework item" is
confirmed. The exact citation count and explicit drift gates should be
corrected in v2.

### D1 evidence: unprefixed strategy DSL

Do not decide D1 in the response stage, but the evidence is stronger on both
sides than the seed records.

Evidence for prefixing:

- The export lock has six unprefixed exports (`tests/testthat/test-api-exports.R:5`,
  `tests/testthat/test-api-exports.R:127-131`).
- `iso_utc()` is not DSL; it has a prefixed sibling `ledgr_utc()`
  (`R/timestamp.R:1-17`, `R/timestamp.R:80-95`).
- The helper definitions are public unprefixed exports
  (`R/strategy-helpers.R:47-76`, `R/strategy-helpers.R:93-121`,
  `R/strategy-helpers.R:151-167`, `R/strategy-helpers.R:181-215`).
- `passed_warmup()` is also unprefixed and documented as a strategy guard,
  not a signal-pipeline transformation (`R/feature-map.R:264-295`).

Evidence against prefixing:

- The strategy-development vignette explicitly teaches a four-stage economic
  helper pipeline (`vignettes/strategy-development.qmd:503-510`) and shows
  concise code using unprefixed helpers (`vignettes/strategy-development.qmd:519-528`,
  `vignettes/strategy-development.qmd:581-586`).
- Two user-facing articles use the same fluent helper chain as a readability
  signal (`vignettes/articles/why-r.qmd:47-56`,
  `vignettes/articles/who-ledgr-is-for.qmd:45-55`).
- `passed_warmup()` appears throughout shipped vignettes as the warmup guard,
  including the strategy-development and indicators teaching paths
  (`vignettes/strategy-development.qmd:647-677`,
  `vignettes/indicators.qmd:228`, `vignettes/indicators.qmd:369` from grep).

Assessment: prefixing improves namespace hygiene and consistency, but the
fluency loss is not small. It affects ledgr's front-facing "economic logic"
examples. D1 should remain a maintainer decision, and v2 should present this
as a real product tradeoff rather than a mostly mechanical preference.

---

## 2. Findings The Seed Missed

1. **`ledgr_snapshot_open` is already taken.** This is the clearest concrete
   miss. The proposed `ledgr_snapshot_load()` rename collides with the existing
   internal snapshot connection helper (`R/snapshot.R:61-78`).
2. **Folding fills into `ledgr_results()` would be semantic work.** The seed
   frames Q3 as mostly naming overlap. Current code has cursor lifecycle and
   threshold behavior that `ledgr_results()` does not publicly expose
   (`R/backtest.R:1168-1208`, `R/backtest.R:1410-1412`,
   `R/backtest.R:2392-2395`).
3. **Walk-forward candidate dispatch needs a locator contract.** Current
   `ledgr_walk_forward_results` objects do not carry the snapshot locator the
   proposed method would need (`R/walk-forward.R:151-168`,
   `R/walk-forward-inspection.R:15-40`).
4. **`ledgr_backtest_bench()` is contract-bound public diagnostic surface
   today.** The seed's "dev tooling" framing omits the contracts binding at
   `inst/design/contracts.md:259-262`.
5. **The contracts citation count should be corrected.** The first-class
   rework point stands, but the exact count is 99 tokens across 84 lines in a
   691-line file.

---

## 3. Disagreements With Seed Positions

- **Q3 disposition:** disagree with folding fills into `ledgr_results()` for
  this cycle. Rename to `ledgr_run_fills()` first; leave any `ledgr_results()`
  streaming extension for a separate semantic ticket.
- **Candidate generic premise:** partially disagree. The generic may be the
  right public shape, but the seed overstates existing sweep precedent. Sweep
  carries identity attrs, not a durable locator. Walk-forward would need a new
  locator contract before the generic can be implementation-safe.
- **Unexport `ledgr_backtest_bench()` as dev tooling:** disagree with the
  rationale. It may still be unexported pre-CRAN, but only after an explicit
  maintainer decision on detailed session telemetry.
- **`ledgr_snapshot_open` rename:** disagree as written because of the exact
  internal-name collision.

---

## 4. Items Confirmed As-Is

- The broad problem statement is correct: the export surface has real
  noun/verb drift, duplicate reopen vocabulary, and weak `extract` names.
- The pre-CRAN, no-alias, no-deprecation framing is appropriate for this
  naming cycle, provided internal docs and gates are updated deliberately.
- Indicator registry helpers are real verb-first strays and belong under a
  consistent indicator-family naming rule (`R/indicator.R:215`,
  `R/indicator.R:270`, `R/indicator.R:315`, `R/indicator.R:359`).
- `ledgr_metric_context_resolve()` can be removed from the public surface; no
  documented workflow depends on it.
- The rename batch must precede v0.1.9.5 teaching/documentation batches, or the
  new docs will teach names that immediately churn.
- Identity surfaces, condition classes, persisted schema columns, and hash
  bytes should remain out of scope.

---

## 5. Recommendation For Next Step

Revise to seed v2 before synthesis.

The findings are not fatal to the naming direction, but they are too material
for direct synthesis:

- resolve the `ledgr_snapshot_open` collision;
- bind Q3 to `ledgr_run_fills()` unless v2 explicitly scopes semantic
  streaming changes for `ledgr_results()`;
- revise Section 4 so walk-forward candidate dispatch has a concrete locator
  contract and preserves the current Amendment 2 extraction discipline;
- split the unexport list into confirmed removals, recovery-surface decisions,
  and `ledgr_backtest_bench()` telemetry decision;
- correct the contracts/doc blast-radius counts and gates;
- sharpen D1 as a real maintainer product decision, with the fluency evidence
  from shipped vignettes and articles.

After v2, the cycle likely needs maintainer decisions for D1, D2, and D3
before synthesis.
