# v0.2.0 Test Suite Audit: Initial Pass

**Date:** 2026-09-09

**Reviewer:** Codex

**Baseline:** `v0.1.9.8` at `2ee83e99039476b0243009cc3495a19ebd49cc00`;
package version `0.1.9.7`. The title identifies the planned hardening release,
not a released version or an approved spec packet.

**Status:** Open. Source review and existing CI evidence inspected; local R
execution, fault injection, and repeatability measurements remain pending.

**Purpose:** Inform API/representation hardening and fold modularization before
the accepted asset-availability implementation. This audit changes no runtime,
tests, API, CI policy, or accepted RFC decisions.

## 1. Assessment

The suite is substantial and contains useful independent arithmetic,
negative validation, persistence, and cross-path checks. Keep that foundation.
The main weakness is uneven protection of invariants across representations:
agreement between two ledgr paths can preserve a shared mistake, and a check
that accepts good input does not establish that it rejects bad input.

Do not use the green suite alone as permission for broad modularization.
First add focused regressions at the boundaries identified below and measure
whether deliberately broken paths fail for the intended reason. This is a
recommendation for the hardening packet, not a finding that all execution or
methodological claims are invalid.

| ID | Priority | Finding | Evidence status |
| --- | --- | --- | --- |
| T-1 | High | Derived fill fees lack an independent conservation assertion | Source-confirmed gap; known projection defect re-traced |
| T-2 | High | No-lookahead checker has positive examples but no rejection witness | Source-confirmed gap; mutant not executed |
| T-3 | Medium | Row-operation tests do not protect the full research identity | Source-confirmed gap; operation-specific effects need execution |
| T-4 | Medium | Integration cleanup and warning handling weaken failure diagnosis | Concrete omissions confirmed; timing/flakiness not measured here |
| T-5 | Medium | Documentation checks mix public contracts with editorial locks | Source-confirmed maintenance coupling |

## 2. What Was Checked

Repository-wide inventory and searches covered `tests/testthat`, test helpers,
CI workflows, and coverage tooling. Focused body review covered accounting,
fills, costs, RNG, snapshot guards, feature/cache validation, sweep parity and
retention, saved-sweep row operations, walk-forward orchestration/selection,
metrics/diagnostic oracles, lifecycle, and documentation tests. Corresponding
production paths were traced where a finding depends on implementation.
This is not a line-by-line audit of every test or a statistical review of every
diagnostic formula; those are not claimed complete.

Inputs include [contracts](../contracts.md), [roadmap](../ledgr_roadmap.md),
[horizon](../horizon.md), existing audits in this directory, and the
[accepted availability synthesis](../rfc/rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md).
The horizon's 2026-09-04 hardening findings and 2026-09-06 CI findings are
prior evidence, not discoveries attributed to this audit.

### Inventory and execution evidence

| Measure | Observed result |
| --- | --- |
| `test-*.R` files directly under `tests/testthat` | 112 |
| Source `test_that(` call sites | 756; not an executed-test or assertion count |
| Test-file source size | 1,128,641 bytes |
| Documentation contract file | 150,912 bytes; 59 `test_that(` call sites |
| Documentation text checks | 1,084 `expect_match(` and 100 `expect_no_match(` call sites |
| Local runtime | `Rscript` absent; no local test/check/coverage run |
| Existing CI at the audited SHA | Ubuntu and Windows jobs succeeded on 2026-09-08 |
| CI package check | Both reported 0 errors, 0 warnings, 1 NOTE for portable file paths |
| CI Linux coverage | 85.47%; configured threshold is 80% |

Counts are lexical source counts, including calls inside loops; they are not
coverage, fault-detection, or runtime estimates. Reproduce the inventory using
`tests/testthat/test-*.R`, summing file bytes and matching the named call sites.

Existing execution evidence:
[workflow run 34256299756](https://github.com/blechturm/ledgr/actions/runs/34256299756),
[Ubuntu job](https://github.com/blechturm/ledgr/actions/runs/34256299756/job/102162864954),
[Windows job](https://github.com/blechturm/ledgr/actions/runs/34256299756/job/102162865422).
Both used R 4.6.1. The Ubuntu acceptance preflight also printed a Tk/no-DISPLAY
warning; a successful job is not evidence of a warning-free preflight.
No complete per-test skip inventory or per-function coverage report was
examined. These CI results establish the existing baseline, not successful
execution of this audit's proposed probes.

## 3. Findings

### T-1. Fee conservation is missing at the ledger-to-fills boundary

**Evidence.** `R/backtest.R:1413-1426` passes the same event fee into both
`CLOSE` and `OPEN` rows when an execution reverses a position. For a nonzero
fee, their sum exceeds the original ledger fee. This is the known September 4
projection finding; it does not establish a second deduction from portfolio
cash.

`test-fifo-torture.R:1-66` exercises reversals with zero fees;
`test-fifo-opening-positions.R:239-270` also uses the zero-cost default.
`test-fills-streaming.R:114-211` compares eager and lazy reconstruction but
does not aggregate projected fees against source events. There **is** a
nonzero-fee split example in `test-sweep.R:196-274`: it compares inline and
reconstructed summaries and checks actions/quantities, without an independent
per-event fee total. Thus this is not a claim that the suite has no fee tests.

**Consequence.** Parity can stay green while a user summing fill-table fees
gets the wrong transaction-cost total. A cosmetic file split will not fix the
missing assertion.

**Disposition.** Strengthen the existing reversal fixtures with a manually
specified event, nonzero fee, partial close, and residual opening quantity.
Require grouped projected fees to equal the ledger fee by `event_seq`, and
check cash, position, and realized-PnL semantics separately. Specify fee
ownership before asserting its distribution between derived rows. Exercise
eager, streaming, and the supported memory path. Keep reversal accounting
tests explicitly separate from claims about margin or borrow support.

### T-2. The no-lookahead checker is not tested against leakage

**Evidence.** The only test calls to `ledgr_check_no_lookahead()` are
`test-features.R:388-400` and `test-acceptance-v0.1.0.R:205-222`. Both require
SMA/return features to pass. No test asserts
`ledgr_feature_lookahead_detected`, the rejection in
`R/features-engine.R:301-327`. Replacing this checker with `invisible(TRUE)`
would satisfy those particular expectations by construction. That is a source
deduction, not an executed mutation result for the full suite.

**Consequence.** The positive tests cannot establish the checker's ability to
detect a leaking vectorized feature. Existing bounded-window and cache-key
tests answer other useful questions; they do not replace this negative case.
The checker is a diagnostic helper, not an automatically invoked runtime
sandbox for arbitrary indicator code.

**Disposition.** Add one deliberately leaking `series_fn` whose early outputs
depend on the last available observation, with valid lengths and warmup so it
fails specifically for lookahead. Pair it with a causal control. Then probe a
public run/precompute path using two snapshots with identical history through
a cutoff and different later values: earlier decision inputs and outputs must
agree, while content-derived identities may differ. Do not demand an unchanged
fill after changing its execution bar, or compare boundary decisions whose
final-bar status differs. Extend this pattern to membership/status facts when
availability is implemented, following synthesis gates 2 and 10.

### T-3. Identity preservation is checked unevenly across row operations

**Evidence.** `ledgr_sweep_results_restore()` in
`R/sweep-retention.R:1245-1272` explicitly restores cost metadata but omits
`risk_chain_hash` and `risk_plan_json`. The survivability test in
`test-sweep-persistence-roundtrip.R:310-360` exercises filter, arrange, slice,
and base subsetting but checks sweep/candidate identity and retained returns,
not those risk attributes. In contrast, the full save/reopen check includes
both risk fields (`test-sweep-persistence-roundtrip.R:76-89`). The row-operation
test also places its base-R assertions behind `skip_if_not_installed("dplyr")`.

**Consequence.** An omitted restoration field is not necessarily lost by every
operation: tibble/dplyr may carry attributes independently. The exact affected
operations require a runtime probe. But the suite does not directly protect
that contract, and `ledgr_return_panel_sweep_identity()` reads risk from the
attribute, returning `NA` when absent (`R/sweep-retention.R:891-907`). Candidate
provenance surviving elsewhere does not guarantee that panel identity survives.

**Disposition.** Use a non-default risk chain and assert the relevant parent,
candidate, and downstream panel identity after each supported row operation,
for in-memory and reopened sweeps. Include empty and reordered selections;
preserve candidate IDs and intended exclusions. Keep base-R cases runnable
without dplyr. Feed this matrix into the hardening RFC's ownership decision;
do not add another independently maintained provenance registry to the tests.

### T-4. Some integration tests rely on implicit cleanup or hide extra warnings

**Evidence.** The walk-forward tests starting at
`test-walk-forward-orchestrator.R:525` and `:618` do not close the newly created
`wf$test_runs`; neighboring tests do. `test-backtest-audit-log-equivalence.R`
does not explicitly close its snapshot or either backtest. This matters because
the suite separately tests checkpoint/finalizer behavior in
`test-backtest-lifecycle.R`. These are cleanup omissions, not proof that every
handle holds an active connection or that CI currently fails.

The cadence test at `test-walk-forward-orchestrator.R:191-205` records the
expected class but unconditionally muffles **every** warning. An unrelated
warning during that call would disappear. Shared teardown also suppresses
disconnect/shutdown errors (`helper-fixtures.R:5-11`); that can be appropriate
for best-effort cleanup but cannot serve as a lifecycle assertion.

**Disposition.** Register cleanup immediately after acquiring each owned
resource, including failure-safe cleanup of returned walk-forward test runs.
Keep intentional finalizer tests. Muffle only expected condition classes in
behavioral tests and let unexpected warnings reach the reporter. Re-run the
affected tests in fresh sessions, alone and in the suite, before attributing
timing variation to a particular implementation. Do not replace isolated
DuckDB fixtures with shared mutable databases to save time.

### T-5. Documentation tests over-specify some editorial choices

**Evidence.** `test-documentation-contracts.R` mixes useful public-surface
checks with exact sentences, diagram HTML, and historical roadmap wording.
Examples are the `declare<br/>indicator or map` label near line 90 and the
v0.1.7.6-to-v0.1.8 roadmap wording at lines 865-880. Its 1,184 direct positive/
negative text-matching call sites do not execute the described claims.

**Consequence.** A clear rewrite can fail tests while an incorrect example
containing the expected sentence can pass them. This is maintenance coupling,
not evidence that all documentation checks are useless or dominate runtime.
The export allowlist in `test-api-exports.R` is a useful deliberate API gate;
do not remove it merely because the upcoming RFC changes exports.

**Disposition.** Keep checks for public names, links, schemas, migration errors,
and important limits on claims. Review historical/editorial locks individually
for retirement or a lighter docs check. Preserve the installed-package README
execution in `tools/check-readme-example.R` and vignette execution. Add workflow
acceptance checks for the actual recommended API journey where needed. Human
review must still judge explanation, discoverability, and the usefulness of
errors; regex counts do not measure teaching quality.

## 4. Invariant-to-Test Map

Paths below are under `tests/testthat/`; references describe inspected source,
not newly executed results. This is a focused map, not a completeness claim.

| Contract | Existing anchors and strength | Next action |
| --- | --- | --- |
| Snapshot trust and tamper detection | `test-runner-snapshots.R`; `test-acceptance-v0.1.1.R` force seal failure, mutate data, reject unsealed/ragged input | Keep; fault-inject public run and sweep entry guards before moving setup code |
| Decision/fill timing and full targets | `test-fill-model.R`, `test-strategy-contracts.R`, `test-risk-fold.R`; arithmetic, invalid names, phase ordering | Keep; future-data perturbation must respect decision versus execution cutoffs |
| Feature causality and warmup | `test-features.R`, `test-precompute-features.R`; bounded windows and incompatible precomputed objects | Strengthen with T-2 negative witness |
| Cash, positions, PnL, and derived fills | `test-accounting-consistency.R`, `test-derived-state.R`, `test-fifo-opening-positions.R`, `test-fifo-torture.R` | Keep independent arithmetic; add T-1 fee conservation |
| Costs and risk | `test-cost-model.R`, `test-fill-model.R`, `test-risk-fold.R`; literal spread/fee formulas and target transformations | Keep; label algebraic shorts separately from supported financing |
| Run, sweep, promotion, compiled parity | `test-sweep-parity.R`, `test-sweep.R`, `test-sweep-persistence-parity.R`; opening lots, stochastic seeds, features, supported compiled opt-in | Keep parity; pair it with independent economic witnesses |
| Resume and transaction failure | `test-acceptance-v0.1.0.R:291-363`, `test-runner.R`, `test-derived-state.R:170`; clean/resumed outputs, state order, preserved data on failure | Keep; probe failure inside a write sequence, beyond clean max-pulse interruption |
| Research identity across representations | `test-sweep-persistence-roundtrip.R`, `test-walk-forward-identity.R`, `test-promotion-context.R` | Strengthen row operations and downstream panels (T-3) |
| RNG behavior | `test-rng.R`, stochastic promotion and parallel-rejection tests | Distinguish reproducible seeds from preserving the caller's RNG state |
| Walk-forward selection and failures | `test-walk-forward-selection.R`, `test-walk-forward-orchestrator.R`; finite eligible scores, failure rows, partial sessions, carried state | Keep; test train-output invariance under changes confined to later data; fix cleanup |
| Metrics and selection diagnostics | `test-metric-oracles.R`, `test-validation-{pbo,dsr,min-track-record,k-ratio}.R` | Keep public-table/manual formulas and pinned PBO example; record which external comparisons actually run |
| Workflow and explanation | README cold-start script, lifecycle/reopen tests, vignettes, documentation contracts | Prefer executable journeys plus targeted explanation checks (T-5) |

Oracle independence is layered. `test-metric-oracles.R` independently computes
metrics **from ledgr's public tables**; it does not independently validate the
underlying fills/equity. `ledgr_test_next_open_fill()` calls production timing
and cost code, so it is a fixture builder rather than an independent pricing
oracle. That is fine when the assertion supplies its own arithmetic, as in
`test-derived-state.R:110-111` and `test-fill-model.R:138-139`. It is insufficient
when both expected and actual economics come from the same production helper.

## 5. Execution Follow-Up

The next audit pass should answer: **which economically or methodologically
incorrect changes can the current suite detect?** Use disposable mutations of
the existing package, one at a time, with a clean baseline and a specific
assertion failure. Compilation/setup failures, timeout, or unrelated test
failures do not count as successful defect detection. No mutation result is
claimed in this initial pass.

| Probe | Required evidence |
| --- | --- |
| Nonzero reversal fee | Reproduce the existing projection discrepancy; freeze the agreed conservation assertion before fixing it |
| Disabled no-lookahead checker | Causal control passes; a leaking feature is rejected normally and the negative test fails with the checker gutted |
| Lost risk metadata | Identify which supported row operations preserve/lose it; a deliberately omitted required field fails a downstream identity assertion |
| Caller RNG hygiene | With fixtures prepared first, compare the next random draw and RNG state around ingestion and nonempty fill inspection, including absent initial `.Random.seed` |
| Wide-name and threshold boundaries | Probe a candidate named `ts_utc`; probe `Inf`, `-Inf`, `NA`, length-two, and overflowing thresholds on populated and empty fill sets |
| Public future-data perturbation | Freeze earlier decision evidence, alter later data, compare economic prefixes without requiring identical snapshot/config hashes |
| Interrupted persistence | Inject failure during a write sequence; resumed results reconcile with clean execution and leave no alternate tail |
| Test cleanup | Repeat the affected integration files in fresh processes; report unexpected warnings, surviving handles, and file-lock behavior |

The RNG, wide-name, and threshold probes consume existing horizon leads.
Current source still uses `sample()` for temporary names in
`R/snapshot_adapters.R:329` and `R/backtest.R:1237`. Wide projection writes
`out[[id]]` beside `ts_utc` (`R/sweep-retention.R:277-284`). Threshold validation
casts to integer without a finiteness check and follows an empty-result return
(`R/backtest.R:1213-1220`). The suite-wide searches found no direct caller-RNG
state assertion or targeted `ts_utc`/nonfinite-threshold witness. These are
bounded follow-ups, not claims that a new experimental campaign ran here.

Start with the existing targeted suites using the repo's runner convention:

```sh
Rscript -e "pkgload::load_all('.', quiet = TRUE); testthat::test_local('.', filter = '^(accounting-consistency|fifo-torture|fifo-opening-positions|fills-streaming|features|rng|sweep-retention|sweep-persistence-roundtrip|walk-forward-orchestrator)$', reporter = 'summary', load_package = 'none')"
```

This command runs existing tests; it does not create or run the proposed
mutations. After strengthening tests and fixing scoped defects, use the full
suite, package check, README, and coverage gates from `AGENTS.md` and
`release_ci_playbook.md`. Append measured results, environment, skips, and
specific detecting assertions to this file. Do not commit generated coverage,
package-check directories, or a new test-evidence bureaucracy.

CI already serializes check, pkgdown, and coverage on Ubuntu, and main has a
second pkgdown owner. The September 6 horizon entry records this cost. Pursue
its independent-job/duplicate-work proposals after cleanup; retain the 80%
gate and realistic integration checks. Mirai tests deliberately skip under
covr (`test-sweep-parallel.R:56-64`); verify their ordinary-CI execution rather
than treating aggregate coverage as parallel-backend evidence. Optional
`pbo`/`quantstrat` comparisons may also skip; do not describe them as mandatory
independent validation without a run record.

## 6. Handoff To v0.2.0 Planning

**Keep:** independent arithmetic, failure/rollback tests, real sealed-snapshot
workflows, read-only reopen checks, cross-path parity, and deliberate API locks.
**Strengthen:** conservation, negative causality, complete identity restoration,
resource ownership, and caller RNG hygiene. **Replace or retire selectively:**
editorial assertions with no current contract value; expected economics derived
solely from the production calculation under test.

The hardening RFC should assign owners to these invariant families and state
which public workflows must survive modularization. Establish the strengthened
baseline first, move functions without semantic changes second, then implement
availability with its new tests. Avoid turning the audit into a redesign of
every helper or an arbitrary increase in test count.

Availability is not implemented at this baseline. Its 24 synthesis gates are
future acceptance obligations, not 24 existing regressions. Scope dense legacy
coverage tests to their retained mode; add active-mode tests for the independent
session clock, members-plus-held axis, stale valuation without stale execution,
no hidden orders, affordability, incomplete evidence, and reopening the same
explanation. Use synthesis Section 14 directly instead of copying its witness
registry. Imputation, ML fitting, and corporate-action settlement remain the
separate deferred work named by the accepted synthesis.

**Audit completion remains open** until the prioritized execution probes,
test-strengthening dispositions, and resulting hardening scope are recorded.

## 7. Measured Evidence (2026-09-09, `c78ab4f`)

Appended by the response author after running
`dev/spikes/api-representation-hardening/probe.R` (R 4.5.2 ucrt, Windows 11,
ledgr 0.1.9.7 via `pkgload::load_all()`, duckdb 1.4.3, dplyr 1.1.4). Ten
cases on a synthetic two-instrument, eight-bar sealed snapshot; full output
is summarized in the probe's `probe_findings.md`. These rows update the
Section 5 table; they do not close the audit.

| Section 5 probe | Measured result | Effect on the finding |
| --- | --- | --- |
| Nonzero reversal fee | `ledgr_cost_notional_bps_fee(10)` with a long/short flip: 7 fill events, 13 derived rows, derived fee total 13.045 against source 6.775; six of seven events carry the full fee on both `CLOSE` and `OPEN` rows | T-1 confirmed by execution; conservation assertion per `event_seq` is the detecting check; allocation rule is a maintainer decision |
| Lost risk metadata | `filter()`, `arrange()`, `slice_head()`, base `[`, and `ledgr_sweep_save()` / `ledgr_sweep_open()` all kept `risk_chain_hash` as attribute, column, and row provenance; candidates from a plain tibble and from an attribute-stripped data frame reconstructed the chain and promoted | T-3 is latent, not observed: dplyr and vctrs copy the attributes the restore list omits; fix is the two missing fields plus one assertion after base `[` |
| Wide-name and threshold boundaries (threshold half) | With fills: `Inf` untyped base error after a coercion warning; `NA` and `"100"` typed `ledgr_invalid_args`; `-1`, `0`, `1.5` accepted and return a cursor with `lazy = FALSE`. Without fills: every value returns an empty tibble | Validation-after-shortcut confirmed; the `ts_utc` wide-name half was not run |
| Not in Section 5: review helper lineage | `ledgr_sweep_review()$ranked` is a plain tibble; its candidate has zero `sweep_meta` fields and promotes with `source_sweep$sweep_id = NULL` | New finding; the research-workflow vignette's documented selection path loses lineage |
| Not in Section 5: reads after close | `close(bt)` then `ledgr_run_fills()` and `summary()` reopen by path and succeed | Contract or accident; routed to the response's open questions |

Unrun and unchanged by this appendix: disabled no-lookahead checker, caller
RNG hygiene, the `ts_utc` wide-name probe, public future-data perturbation,
interrupted persistence, and test cleanup.
