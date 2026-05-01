# ledgr v0.1.7.2 Tickets

**Version:** 0.1.7.2  
**Date:** May 1, 2026  
**Total Tickets:** 9  

---

## Ticket Organization

v0.1.7.2 has three coordinated tracks:

1. **Auditr UX stabilisation:** close the high-signal findings from the
   companion-package audit, especially comparison metric inconsistencies and
   installed-documentation friction.
2. **Strategy helper layer:** implement the minimal helper pipeline described in
   `ledgr_strategy_spec.md` without creating a second execution path.
3. **Strategy-development vignette overhaul:** rewrite the strategy article as
   ledgr's central teaching document.

Under `inst/design/model_routing.md`, version scoping, ticket generation,
contract changes, persistence lifecycle changes, strategy-result validation,
and release gates are Tier H. Documentation-only tickets may be Tier M
implementation with Tier H review when they teach public contracts.

### Dependency DAG

```text
LDG-1201 -> LDG-1202 -----------------------------> LDG-1207 -> LDG-1209
LDG-1201 -> LDG-1203 -----------------------------> LDG-1208 -> LDG-1209
LDG-1201 -> LDG-1204 -> LDG-1205 -----------------> LDG-1207 -> LDG-1209
LDG-1201 -> LDG-1206 -----------------------------> LDG-1207 -> LDG-1209
LDG-1201 -----------------------------------------> LDG-1208 -> LDG-1209
```

`LDG-1209` is the v0.1.7.2 release gate.

### Priority Levels

- **P0 (Blocker):** Required for correctness or release coherence.
- **P1 (Critical):** Required for the user story to work.
- **P2 (Important):** Required for discoverability or documentation quality.
- **P3 (Optional):** Useful, but not a release blocker.

---

## LDG-1201: Patch Scope, Metadata, And Non-Goal Guardrails

**Priority:** P0  
**Effort:** 1 day  
**Dependencies:** None  
**Status:** Done

**Description:**
Finalize the v0.1.7.2 release boundary before implementation begins. This
ticket makes the auditr UX track, strategy helper track, and strategy-vignette
track explicit while keeping sweep/tune and short-selling semantics out of
scope.

**Tasks:**
1. Review `v0_1_7_2_spec.md`, `ledgr_strategy_spec.md`, and
   `ledgr_triage_report.md` for internal consistency.
2. Confirm `inst/design/ledgr_roadmap.md` has a v0.1.7.2 entry matching the
   spec.
3. Confirm `ledgr_design_philosophy.md` is framed as non-binding guidance.
4. Create a draft `NEWS.md` v0.1.7.2 section with placeholders for the intended
   changes.
5. Confirm `DESCRIPTION` version handling is called out for the release gate.
6. Add an export/API inventory scan target that proves no sweep/tune APIs are
   exported in this cycle.
7. Confirm there is no stale `ledr_*` filename in the spec packet.

**Acceptance Criteria:**
- [x] v0.1.7.2 spec, roadmap, strategy spec, and triage report agree on scope.
- [x] `NEWS.md` has a v0.1.7.2 draft section.
- [x] No sweep/tune APIs are in scope.
- [x] No short-selling or leverage semantics are in scope.
- [x] No stale `ledr_*` files remain in the packet.
- [x] Ticket statuses and dependencies are internally consistent.

**Test Requirements:**
- Documentation consistency scan.
- Export/API inventory scan.
- Filename/package scan.

**Source Reference:** v0.1.7.2 spec sections 1, 2, 7, 8.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Version scoping, ticket generation, compatibility posture, and non-goal
  boundary definition are Tier H by rule.
invariants_at_risk:
  - release scope
  - public API boundary
  - non-goal boundary
  - documentation contract
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_2/v0_1_7_2_spec.md
  - inst/design/ledgr_v0_1_7_2/ledgr_strategy_spec.md
  - inst/design/ledgr_v0_1_7_2/ledgr_triage_report.md
  - inst/design/ledgr_roadmap.md
  - inst/design/contracts.md
  - NEWS.md
tests_required:
  - documentation consistency scan
  - export/API inventory scan
  - filename/package scan
escalation_triggers:
  - sweep/tune scope appears necessary
  - short-selling or leverage semantics appear necessary
  - helper layer requires a second execution path
forbidden_actions:
  - adding ledgr_sweep or ledgr_tune
  - adding strategy dependency-packaging arguments
  - adding short-selling semantics
  - changing execution behavior during scope setup
```

---

## LDG-1202: Comparison Metrics And Stable Result Schemas

**Priority:** P0  
**Effort:** 2-4 days  
**Dependencies:** LDG-1201  
**Status:** Done

**Description:**
Investigate and resolve the auditr high-priority finding that
`ledgr_compare_runs()` can report `n_trades = 0` while fills or summary output
show trading activity. This ticket also stabilizes zero-row result schemas so
flat runs return normal empty tables rather than `0 x 0` tibbles.

**Tasks:**
1. Reproduce the discrepancy in a targeted test before changing implementation.
2. Identify whether the zero comes from comparison SQL, telemetry,
   fill/trade reconstruction, or metric definition mismatch.
3. Define `n_trades` precisely for comparison output.
4. Align `ledgr_compare_runs()`, `summary()`, `ledgr_extract_fills()`, and
   `ledgr_results(bt, what = "trades")` with compatible definitions.
5. Ensure zero-trade and flat runs return stable zero-row schemas for trades,
   fills, ledger, and equity result paths where applicable.
6. Update result/metric documentation with the definition and edge cases.
7. Add regression tests for flat runs, open-only runs, closed round trips, and
   multi-fill runs.

**Acceptance Criteria:**
- [x] A targeted regression test reproduces or explicitly disproves the auditr
      metric discrepancy.
- [x] `n_trades` is defined in docs and tests.
- [x] Comparison output agrees with the documented definition.
- [x] Flat runs and zero-trade runs return stable schemas, not `0 x 0` tibbles.
- [x] Existing comparison no-recompute/no-mutation behavior is preserved.

**Test Requirements:**
- Targeted comparison metric regression test.
- Flat-run zero-row schema tests.
- Open-only run metric test.
- Closed round-trip metric test.
- Multi-fill metric test.
- Existing run-store/comparison tests.

**Source Reference:** v0.1.7.2 spec sections R2, R3, A1.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  Result metric semantics affect public comparison output and documented
  interpretation of ledger-derived artifacts. The work may touch run-store SQL,
  result reconstruction, and summary metrics, so Tier H implementation and
  review are required.
invariants_at_risk:
  - result metric definitions
  - comparison no-recompute contract
  - result table schemas
  - ledger-derived result interpretation
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_2/v0_1_7_2_spec.md
  - inst/design/ledgr_v0_1_7_2/ledgr_triage_report.md
  - inst/design/contracts.md (Result Contract, Persistence Contract)
  - R/run-store.R
  - R/backtest.R
  - tests/testthat/test-run-compare.R
  - tests/testthat/test-run-store.R
tests_required:
  - targeted comparison metric regression test
  - zero-row schema tests
  - flat/open-only/round-trip/multi-fill tests
  - existing comparison tests
escalation_triggers:
  - metric fix requires changing ledger or fill semantics
  - comparison would need to rerun strategy code
  - schema changes appear necessary
  - result definitions conflict with existing summary output
forbidden_actions:
  - recomputing strategies from comparison APIs
  - mutating stores from comparison APIs
  - changing fill or ledger semantics
  - hiding metric inconsistencies with print-only formatting
```

---

## LDG-1203: Result-Access Connection Lifecycle

**Priority:** P1  
**Effort:** 2-4 days  
**Dependencies:** LDG-1201  
**Status:** Pending

**Description:**
Evaluate and, if practical, implement per-operation read connections for
result-access APIs so ordinary result inspection does not keep durable DuckDB
files locked in long sessions. If implementation is deferred, document the
actual close semantics accurately and move the connection architecture work to
v0.1.8.

**Tasks:**
1. Audit result-access paths for cached DuckDB connections:
   `ledgr_results()`, `ledgr_run_list()`, `ledgr_run_info()`,
   `ledgr_compare_runs()`, `ledgr_run_open()`, `ledgr_extract_strategy()`,
   and interactive snapshot/pulse inspection paths.
2. Determine which paths can safely use open/read/close per operation.
3. If adopted, refactor practical result-access paths to avoid long-lived read
   locks.
4. If deferred, add explicit v0.1.8 deferral notes to the spec and roadmap.
5. Update docs so `close(bt)` and `ledgr_snapshot_close(snapshot)` are framed
   as resource management for long sessions, not data-loss prevention.
6. Add a regression test proving result inspection does not block a subsequent
   durable `ledgr_run()` against the same snapshot where practical.

**Acceptance Criteria:**
- [ ] The lifecycle decision is documented: implemented now or explicitly
      deferred.
- [ ] Docs do not teach close calls as data-safety requirements.
- [ ] If implemented, ordinary result-access APIs do not leave durable DuckDB
      files locked for later writes.
- [ ] If deferred, v0.1.8 owns the remaining architecture work.

**Test Requirements:**
- Connection lifecycle regression test where practical.
- Existing persistence/run-store tests.
- Documentation scan for close framing.

**Source Reference:** v0.1.7.2 spec sections R11, A7, A8.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  DuckDB connection lifecycle, checkpoint behavior, and persistent read/write
  locking are persistence hard-escalation areas. Even if the result is
  deferral, the investigation and documentation require Tier H review.
invariants_at_risk:
  - persistence lifecycle
  - DuckDB locking behavior
  - restart/readback safety
  - documentation accuracy
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_2/v0_1_7_2_spec.md
  - inst/design/contracts.md (Persistence Contract, Result Contract)
  - R/backtest.R
  - R/run-store.R
  - R/snapshot.R
  - R/db-connect.R
tests_required:
  - connection lifecycle regression test
  - existing persistence tests
  - close-framing documentation scan
escalation_triggers:
  - per-operation reads require schema or storage architecture changes
  - Windows or Ubuntu DuckDB locking differs materially
  - checkpoint behavior would need to change
forbidden_actions:
  - weakening runner checkpoint behavior
  - hiding connection failures
  - teaching close as data-loss prevention
  - changing result schemas while refactoring connections
```

---

## LDG-1204: Strategy Helper Types, Contracts, And Validator

**Priority:** P0  
**Effort:** 3-5 days  
**Dependencies:** LDG-1201  
**Status:** Pending

**Description:**
Implement the minimal public value types that make the strategy helper layer
possible and extend the strategy-result validator to accept `ledgr_target` as a
thin wrapper around the existing full named numeric target vector.

**Tasks:**
1. Implement classed value types:
   `ledgr_signal`, `ledgr_selection`, `ledgr_weights`, and `ledgr_target`.
2. Validate names, types, finiteness rules, and universe compatibility where
   the context is available.
3. Implement concise print methods for each type.
4. Extend the strategy-result validator to accept `ledgr_target` by unwrapping
   to the same full named numeric target vector required today.
5. Ensure direct strategy returns of `ledgr_signal`, `ledgr_selection`, and
   `ledgr_weights` fail loudly with classed errors.
6. Preserve plain named numeric target-vector behavior.
7. Update `contracts.md` to reflect the helper contract and validator support.
8. Add NEWS draft bullets for the helper layer if Track B ships.

**Acceptance Criteria:**
- [ ] `ledgr_target` is accepted by the validator and unwraps to a full named
      numeric target vector.
- [ ] Plain full named numeric target vectors still work.
- [ ] Returning signal, selection, or weights directly fails loudly.
- [ ] Helper types do not create a second execution path.
- [ ] `contracts.md` matches the implemented helper contract.

**Test Requirements:**
- Helper type constructor tests.
- Print method tests.
- Strategy validator tests for `ledgr_target`.
- Invalid direct return tests for signal/selection/weights.
- Existing strategy-result validation tests.

**Source Reference:** v0.1.7.2 spec sections R1, R8, R10, Track B;
`ledgr_strategy_spec.md` sections 2-5.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  This ticket changes public strategy return validation and updates the binding
  Strategy Contract. Strategy output validation is execution-adjacent and
  contract-sensitive, requiring Tier H implementation and review.
invariants_at_risk:
  - strategy output contract
  - target vector shape
  - canonical execution path
  - public helper API
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_2/v0_1_7_2_spec.md
  - inst/design/ledgr_v0_1_7_2/ledgr_strategy_spec.md
  - inst/design/contracts.md (Strategy Contract, Context Contract)
  - R/strategy-contracts.R
  - R/pulse-context.R
  - tests/testthat/test-backtest-wrapper.R
  - tests/testthat/test-experiment-run.R
tests_required:
  - helper type tests
  - validator tests
  - invalid direct return tests
  - existing strategy tests
escalation_triggers:
  - helper types require changing runner internals
  - target validation conflicts with existing numeric-vector behavior
  - contracts need broader weight/short-selling semantics
forbidden_actions:
  - accepting weights or signals as executable strategy outputs
  - changing target vector shape
  - adding short-selling semantics
  - forking the runner
```

---

## LDG-1205: Strategy Helper Reference Primitives

**Priority:** P1  
**Effort:** 3-5 days  
**Dependencies:** LDG-1204  
**Status:** Pending

**Description:**
Implement the minimal helper primitives needed to prove the strategy helper
design: return signal, top-n selection, equal weighting, and target
construction. Keep the helper set deliberately small.

**Tasks:**
1. Implement `signal_return(ctx, lookback = 20)` backed by
   `ledgr_ind_returns(lookback)` and feature ID `return_<lookback>`.
2. Implement `select_top_n(signal, n)` with deterministic tie-breaking by
   instrument ID.
3. Implement `weight_equal(selection)`.
4. Implement `target_rebalance(weights, ctx, equity_fraction = 1.0)`.
5. Reject negative weights with a classed error.
6. Reject leverage where `sum(abs(weights)) > 1`.
7. Ensure target construction returns a full-universe `ledgr_target`.
8. Implement `target_overlay()` only if its semantics are fully specified and
   tested; otherwise leave it deferred.
9. Add reference strategy tests in `tests/testthat/test-strategy-reference.R`.
10. Document the helpers if they ship.

**Acceptance Criteria:**
- [ ] The reference helper pipeline runs through `ledgr_run()`.
- [ ] `signal_return()` reads registered `return_<lookback>` features and fails
      clearly if missing.
- [ ] `select_top_n()` handles `NA`, fewer-than-n assets, no available assets,
      and ties deterministically.
- [ ] `weight_equal()` produces valid long-only weights.
- [ ] `target_rebalance()` returns a full-universe `ledgr_target`.
- [ ] Negative weights and leverage fail loudly.
- [ ] No helper zoo or sweep dependency arguments are added.

**Test Requirements:**
- Signal helper tests.
- Selection edge-case tests.
- Weight helper tests.
- Target construction tests.
- Reference strategy end-to-end test.
- Negative-weight/leverage tests.
- Export scan for no sweep/tune APIs.

**Source Reference:** v0.1.7.2 spec Track B; `ledgr_strategy_spec.md`
sections 6-13.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  Implements public strategy helper APIs that construct executable targets from
  feature data and current portfolio state. This touches strategy output
  semantics and user-facing helper contracts, so Tier H is required.
invariants_at_risk:
  - strategy helper semantics
  - target quantity construction
  - long-only contract
  - no-lookahead feature access
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_2/v0_1_7_2_spec.md
  - inst/design/ledgr_v0_1_7_2/ledgr_strategy_spec.md
  - inst/design/contracts.md (Strategy Contract, Context Contract, Indicator Contract)
  - R/pulse-context.R
  - R/indicators_builtin.R
  - R/strategy-contracts.R
tests_required:
  - helper primitive tests
  - reference strategy tests
  - no-lookahead relevant smoke tests
  - export scan
escalation_triggers:
  - helper requires unregistered feature auto-creation
  - target construction needs shorting or leverage semantics
  - current equity/price assumptions conflict with execution semantics
forbidden_actions:
  - auto-registering indicators from signal helpers
  - silently normalizing weights
  - allowing negative weights
  - adding broad helper zoo APIs
  - adding sweep/tune APIs
```

---

## LDG-1206: Warmup, Feature IDs, And Strategy Error Context

**Priority:** P1  
**Effort:** 2-4 days  
**Dependencies:** LDG-1201  
**Status:** Pending

**Description:**
Address auditr findings around feature ID discoverability, warmup/short-history
behavior, and raw strategy errors. This ticket combines documentation with a
bounded runtime improvement: wrapping strategy evaluation errors with useful
pulse context while preserving the original parent condition.

**Tasks:**
1. Add compact feature ID/TTR output reference tables to the relevant docs.
2. Emphasize `ledgr_feature_id()` before feature IDs are used in strategy code.
3. Document warmup guard patterns for known feature warmup `NA`.
4. Document behavior for short datasets with no valid post-warmup feature.
5. Add or update tests/docs for post-warmup invalid `NA` behavior.
6. Wrap strategy evaluation errors with timestamp and available
   feature/instrument context where practical.
7. Preserve the original error as the parent condition.
8. Do not add aliases that change feature fingerprint semantics.

**Acceptance Criteria:**
- [ ] Feature IDs used in examples are discoverable before use.
- [ ] TTR multi-output IDs are documented in compact tables.
- [ ] Warmup and short-history behavior are explained near strategy examples.
- [ ] Strategy errors include useful pulse context without hiding the original
      error.
- [ ] Fingerprint and feature ID semantics are unchanged.

**Test Requirements:**
- Strategy error wrapping test.
- Warmup/short-history documentation examples.
- Documentation scans for feature IDs before use.
- Existing indicator and feature tests.

**Source Reference:** v0.1.7.2 spec sections R6, R7, A4, A6.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  Documentation portions are bounded, but wrapping strategy evaluation errors
  touches execution callbacks and strategy failure behavior. Tier H is required.
invariants_at_risk:
  - strategy error semantics
  - feature ID/fingerprint contract
  - warmup behavior expectations
  - no-lookahead debugging context
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_2/v0_1_7_2_spec.md
  - inst/design/contracts.md (Strategy Contract, Context Contract, Indicator Contract)
  - R/backtest-runner.R
  - R/pulse-context.R
  - R/indicator.R
  - R/indicator-ttr.R
  - vignettes/ttr-indicators.Rmd
  - vignettes/strategy-development.Rmd
tests_required:
  - strategy error context test
  - documentation render/scans
  - existing feature/indicator tests
escalation_triggers:
  - wrapping changes error classes relied on by tests
  - useful context requires changing pulse semantics
  - feature ID aliases seem necessary
forbidden_actions:
  - changing feature fingerprints
  - adding feature ID aliases
  - swallowing original strategy errors
  - weakening post-warmup NA validation
```

---

## LDG-1207: Strategy Development Vignette Overhaul

**Priority:** P1  
**Effort:** 3-5 days  
**Dependencies:** LDG-1202, LDG-1204, LDG-1205, LDG-1206  
**Status:** Pending

**Description:**
Rewrite `vignettes/strategy-development.Rmd` as ledgr's central strategy
authoring chapter. It should teach the mental model, build a simple strategy
step by step, explain the economic logic of helpers or explicit target code,
and show interactive debugging against `ledgr_demo_bars`.

**Tasks:**
1. Build the article around a cumulative example:
   idea -> signal -> selection -> sizing -> target -> run -> inspect -> compare.
2. Explain sealed snapshots, pulses, `ctx`, target quantities, and next-open
   fills before advanced examples.
3. Explain why strategies are ordinary `function(ctx, params)` functions.
4. If Track B ships, teach `signal_return()`, `select_top_n()`,
   `weight_equal()`, and `target_rebalance()` through economic reasoning.
5. If Track B is deferred, teach the same mental model with explicit
   `ctx$feature()`, `ctx$flat()`, and target-vector code and include a short
   future-helper note.
6. Demonstrate interactive snapshot/pulse debugging for universe, bars/prices,
   available features, warmup `NA`, and target output at a chosen pulse.
7. Remove or clearly label conceptual `AAA` examples.
8. Ensure suggested-package assumptions are stated before loading suggested
   packages.
9. Render the vignette and generated markdown/html according to repo practice.

**Acceptance Criteria:**
- [ ] The article reads as a coherent teaching chapter, not a reference dump.
- [ ] Examples are runnable against `ledgr_demo_bars`.
- [ ] The article explains the design mental model and strategy contract.
- [ ] Interactive debugging is used to understand a strategy before running it.
- [ ] Helper examples are current if Track B ships, or clearly future-facing if
      Track B defers.
- [ ] No unexplained cleanup ceremony appears in the happy path.

**Test Requirements:**
- Vignette render.
- Documentation scans for old helper names and `ctx$params`.
- Documentation scan for conceptual symbols in runnable examples.
- Existing README/vignette checks.

**Source Reference:** v0.1.7.2 spec sections R12, Track C.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Documentation-heavy work, but it teaches the central public strategy contract
  and helper mental model. Implementation can be Tier M, with Tier H review for
  contract accuracy.
invariants_at_risk:
  - strategy contract comprehension
  - context mental model
  - target quantity semantics
  - helper API expectations
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_2/v0_1_7_2_spec.md
  - inst/design/ledgr_v0_1_7_2/ledgr_strategy_spec.md
  - inst/design/ledgr_design_document.md
  - inst/design/ledgr_design_philosophy.md
  - inst/design/contracts.md (Strategy Contract, Context Contract, Result Contract)
  - vignettes/strategy-development.Rmd
  - vignettes/getting-started.Rmd
tests_required:
  - vignette render
  - documentation scans
  - README/vignette checks
escalation_triggers:
  - docs need helper APIs that did not ship
  - examples expose missing runtime support
  - article cannot stay runnable with installed package dependencies
forbidden_actions:
  - teaching ctx$params
  - teaching old context helper names
  - presenting future helper APIs as current if Track B defers
  - using conceptual IDs in runnable examples
```

---

## LDG-1208: Installed Documentation And Background Articles

**Priority:** P2  
**Effort:** 2-4 days  
**Dependencies:** LDG-1201, LDG-1203  
**Status:** Pending

**Description:**
Improve installed-package documentation discovery, first-run expectations,
experiment-store operational guidance, and pkgdown positioning content. This
ticket includes the pkgdown-only background articles "Who ledgr is for" and
"Why ledgr is built in R".

**Tasks:**
1. Add a reliable noninteractive documentation discovery path for Rscript and
   audit-agent workflows.
2. Ensure installed vignettes remain focused on operational package use.
3. Keep positioning/background articles under `vignettes/articles/` so they are
   pkgdown-only.
4. Add the background articles to `_pkgdown.yml`.
5. Add a short README pointer to "Who ledgr is for".
6. State suggested-package expectations before code in runnable vignettes.
7. Clarify `tempfile()` examples versus durable project paths.
8. Improve experiment-store operational examples for persistent snapshot IDs,
   labels/tags, CSV seal/load/backtest, and handle lifecycle framing.
9. Verify relative links in pkgdown-only articles.

**Acceptance Criteria:**
- [ ] Noninteractive documentation discovery is documented.
- [ ] Positioning articles are pkgdown-only, not installed vignettes.
- [ ] README links to the audience-filter article.
- [ ] Suggested-package assumptions are stated before use.
- [ ] Durable examples distinguish temporary vignette storage from real project
      artifact paths.
- [ ] Experiment-store docs include labels/tags and persistent snapshot ID
      guidance.
- [ ] Article links work from pkgdown.

**Test Requirements:**
- README render/check.
- Changed article render.
- pkgdown build.
- Documentation scans for stale helper examples and mojibake.
- Installed vignette list review.

**Source Reference:** v0.1.7.2 spec sections R4, R5, A2, A3, A7; auditr
themes THEME-001, THEME-002, THEME-007.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Mostly documentation and pkgdown navigation, but it affects installed
  documentation discovery, first-run UX, and strategic positioning. Tier H
  review is required to prevent misleading claims or future API leakage.
invariants_at_risk:
  - documentation discoverability
  - installed-vs-pkgdown article boundary
  - public workflow expectations
  - strategic positioning accuracy
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_2/v0_1_7_2_spec.md
  - inst/design/ledgr_v0_1_7_2/ledgr_triage_report.md
  - README.Rmd
  - _pkgdown.yml
  - vignettes/getting-started.Rmd
  - vignettes/experiment-store.Rmd
  - vignettes/articles/
tests_required:
  - README render/check
  - article render
  - pkgdown build
  - documentation scans
escalation_triggers:
  - articles claim unavailable APIs
  - installed vignettes become noisy with positioning content
  - pkgdown-only article links fail from nested article paths
forbidden_actions:
  - adding positioning articles as installed vignettes
  - presenting future helper APIs as current
  - adding network-dependent examples
  - adding unreviewed competitor claims
```

---

## LDG-1209: v0.1.7.2 Release Gate

**Priority:** P0  
**Effort:** 1 day  
**Dependencies:** LDG-1201, LDG-1202, LDG-1203, LDG-1204, LDG-1205, LDG-1206, LDG-1207, LDG-1208  
**Status:** Pending

**Description:**
Final validation gate for v0.1.7.2.

**Tasks:**
1. Verify spec, tickets, contracts, roadmap, NEWS, DESCRIPTION, README, and
   pkgdown navigation agree.
2. Bump `DESCRIPTION` to version `0.1.7.2` during the release gate, not before
   implementation tickets are complete.
3. Run targeted v0.1.7.2 tests.
4. Run full package tests.
5. Run coverage gate if required by current release practice.
6. Render README and changed vignettes/articles.
7. Run package check.
8. Build pkgdown.
9. Confirm Ubuntu and Windows CI are green.
10. Confirm no sweep/tune APIs are exported.
11. Confirm no open P0/P1 review findings remain.
12. Confirm the local WSL/Ubuntu gate was run on the release branch after the
    final implementation changes.

**Acceptance Criteria:**
- [ ] Full tests pass.
- [ ] `R CMD check --no-manual --no-build-vignettes` passes with 0 errors and
      0 warnings.
- [ ] `DESCRIPTION` version is `0.1.7.2` before release tagging.
- [ ] pkgdown builds.
- [ ] README and changed articles render.
- [ ] Ubuntu and Windows CI are green.
- [ ] The local WSL/Ubuntu gate has passed on the release branch.
- [ ] Contracts and NEWS match the implemented v0.1.7.2 scope.
- [ ] No accidental v0.1.8 API exposure exists.
- [ ] No open P0/P1 review findings remain.

**Test Requirements:**
- Full package tests.
- R CMD check.
- README/article renders.
- pkgdown build.
- export/API inventory scan.
- CI green.
- Local WSL/Ubuntu gate.

**Source Reference:** v0.1.7.2 spec section 8.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Release gates are Tier H by routing rule. This ticket validates contracts,
  tests, documentation, CI, package metadata, and API boundary before merge and
  tag.
invariants_at_risk:
  - release correctness
  - package build health
  - public API export boundary
  - documentation accuracy
  - contract consistency
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_2/v0_1_7_2_spec.md
  - inst/design/ledgr_v0_1_7_2/v0_1_7_2_tickets.md
  - inst/design/ledgr_v0_1_7_2/tickets.yml
  - inst/design/contracts.md
  - inst/design/ledgr_roadmap.md
  - DESCRIPTION
  - NEWS.md
  - README.Rmd
  - _pkgdown.yml
tests_required:
  - full package tests
  - R CMD check
  - README/article renders
  - pkgdown build
  - export/API inventory scan
  - CI verification
escalation_triggers:
  - any CI failure remains unexplained
  - exported API inventory contains future-cycle APIs
  - R CMD check warnings require scope decisions
  - documentation examples cannot run offline
forbidden_actions:
  - tagging before CI is green
  - ignoring R CMD check warnings
  - shipping with known future-cycle API leaks
  - accepting the gate with open P0 or P1 issues
```

---

## Out Of Scope

Do not implement these in v0.1.7.2:

- `ledgr_sweep()`;
- `ledgr_precompute_features()`;
- `ledgr_tune()`;
- `strategy_helpers`, `strategy_packages`, or `strategy_globals_ok`;
- persistent feature-cache storage;
- short selling;
- leverage;
- broker integrations;
- paper trading;
- live trading;
- large helper zoo APIs;
- hard delete.
