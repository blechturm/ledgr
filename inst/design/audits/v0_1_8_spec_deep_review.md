# v0.1.8 Spec Deep Review

**Status:** Accepted audit input for v0.1.8 ticket cut.
**Date:** 2026-05-13
**Reviewed artifact:** `inst/design/ledgr_v0_1_8_spec_packet/v0_1_8_spec.md`
**Compared against:**

- `inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md`
- `inst/design/architecture/ledgr_sweep_mode_ux.md`
- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`
- `inst/design/ledgr_roadmap.md`
- current R code under `R/`

## Overall

The v0.1.8 spec is structurally sound and close to ticket cut. The core
architecture is aligned with the roadmap: one fold core, separate output
handlers, sequential-first sweep, summary-only sweep results, no public
parallel/risk/cost/walk-forward scope, and strong same-platform parity
requirements.

The main risks are not architectural direction. They are scope and precision
issues where the spec either reopens decisions already settled elsewhere or
describes code that has already moved ahead.

## Disposition

All nine findings were confirmed and accepted on 2026-05-13. The v0.1.8 spec
was patched to:

- route the initial seed-scope ambiguity through the RNG RFC and response;
- correct the preflight dependency statement;
- reframe `ledgr_param_grid()` as existing code to audit/update;
- set `evaluation_scope = "exploratory"` without a user argument;
- split structural feature-factory errors from candidate-specific feature
  materialization failures;
- add `ledgr_tune()` to non-goals;
- reference `canonical_json()` for auto-label stability;
- distinguish candidate-level feature fingerprints from result-level feature
  union metadata;
- state that public sweep-local data slices are deferred.

The finding details remain below as the audit trail.

## Second-Pass Addendum

Claude's second pass on 2026-05-13 found additional precision issues after the
first patch. These were accepted and patched unless noted otherwise:

- Sweep results now retain the standard summary metric columns used by run
  comparison output: `annualized_return`, `volatility`, `sharpe_ratio`,
  `avg_trade`, and `time_in_market`.
- `warnings` is specified as a list column preserving warning condition
  objects/classes.
- Strategy preflight rejection, including Tier 3 classification, is listed as
  a contract error that aborts before candidate evaluation.
- The fold-core step list reserves a future target-risk slot between target
  validation and fill timing so v0.1.9 can insert
  `risk_fn(targets, ctx, params) -> targets` without redefining the parity
  boundary.
- The internal timing/cost chain now starts from `validated_targets`, not
  `targets_risked`, because risk is not applied in v0.1.8.
- The internal fold core is explicitly private and must not be exported,
  added to `NAMESPACE`, or listed in pkgdown.
- The precomputed-feature contract now names the v0.1.8 warmup representation:
  precompute coverage metadata records scoring range, warmup range, per-feature
  or per-candidate warmup requirements, and the union of resolved feature
  fingerprints. Public data-slice objects remain deferred.
- Feature coverage failure semantics now distinguish static precomputed object
  mismatches from candidate-specific warmup/feature infeasibility.
- Execution-bar reservation explicitly includes volume for future
  market-impact and liquidity diagnostics.
- `contracts.md` now points at the active v0.1.8 spec packet.

The separate RNG RFC and response were accepted as v0.1.8 spec input for the
fold-core seed boundary. Public non-`NULL` seed acceptance, fold-entry seeding,
and per-candidate sweep seed derivation are now in v0.1.8 scope. User-facing
`ctx$seed()` helpers, ambient RNG preflight expansion, and RNG contract-version
metadata remain separable v0.1.8.x work unless ticket cut promotes them.

Promotion and candidate-lineage follow-up was accepted on 2026-05-14 and
patched into the central design docs. The resolved v0.1.8 shape is:

- `execution_seed` is a visible row-level sweep column and is the actual fold
  seed used for promotion;
- compact row-level `provenance` carries
  `provenance_version = "ledgr_provenance_v1"`, snapshot hash,
  `strategy_hash`, feature-set hash, master seed, seed contract, and
  evaluation scope;
- `ledgr_candidate()` and `ledgr_promote()` are the canonical promotion helpers;
- promoted runs store durable `run_promotion_context` selection-audit metadata;
- full sweep artifact save/load/replay remains deferred.

## Material Findings

### 1. Seed support is ambiguous and may expand v0.1.8 scope

The spec requires seeded random behavior and per-candidate seed derivation, but
current `ledgr_run()` still rejects non-`NULL` seeds.

Evidence:

- Spec: `v0_1_8_spec.md`, R6 RNG Contract.
- Code: `R/backtest.R`, `ledgr_run_experiment()` rejects non-`NULL` `seed`.

Risk:

Ticket cut could accidentally pull stochastic workflow support into the
fold-core/sweep release.

Recommended disposition:

Decide explicitly before ticket cut:

- either v0.1.8 enables seed support in `ledgr_run()` and `ledgr_sweep()`; or
- non-`NULL` seed remains unsupported and the per-candidate seed boundary is
  reserved for future parallel/stochastic work only.

### 2. Preflight package-dependency statement is stale

The spec says the current preflight API does not provide package dependency
information. It does.

Evidence:

- Code: `R/strategy-preflight.R` documents and returns
  `package_dependencies`.
- Tests: `tests/testthat/test-strategy-preflight.R` asserts dependency
  extraction.

Risk:

The spec may create unnecessary implementation work or misdescribe the existing
preflight contract.

Recommended disposition:

Replace with:

> Current preflight exposes package-qualified dependencies, but does not yet
> define a complete parallel worker setup contract.

### 3. `ledgr_param_grid()` already exists

The spec treats `ledgr_param_grid()` as a new v0.1.8 object. It is already
implemented and exported.

Evidence:

- Code: `R/param-grid.R`.
- Namespace: `NAMESPACE` exports `ledgr_param_grid`.
- Tests: `tests/testthat/test-param-grid.R`.

Risk:

The ticket could duplicate existing work or miss the real task, which is to
audit and update the existing object for sweep execution.

Recommended disposition:

Change ticket framing from "add `ledgr_param_grid()`" to:

> Audit/update existing `ledgr_param_grid()` for sweep use.

Also update stale print/docs text that still says sweep/tune execution is not
exported in v0.1.7.

### 4. Evaluation scope has no API surface

The spec says users may label a result's `evaluation_scope`, but no
`ledgr_sweep()` argument or setter is defined.

Evidence:

- Spec: `ledgr_sweep_results` section defines an `evaluation_scope` attribute.
- Spec: `ledgr_sweep()` section has no corresponding argument.

Risk:

Implementation could invent an ad hoc attribute setter or silently ignore the
user-labeling sentence.

Recommended disposition:

Choose one:

- v0.1.8 always sets `evaluation_scope = "exploratory"` and user labeling is
  deferred; or
- add an explicit `evaluation_scope` argument with a constrained vocabulary and
  clear warning that ledgr does not validate holdout claims.

## Important Findings

### 5. Feature-factory failure classification is too broad

The spec classifies "feature factory fails before candidate execution" as a
contract error that aborts the whole sweep. But feature factories are
candidate-param-aware, so some failures should be candidate-level failures.

Evidence:

- Code: `R/experiment.R`, `ledgr_experiment_materialize_features()` evaluates
  `features(params)`.

Risk:

A single bad candidate such as `sma_n = 0` could abort an otherwise useful
sweep, contrary to the candidate-failure model.

Recommended disposition:

Split failures:

- structural feature-factory invalidity aborts the sweep;
- candidate-specific feature materialization or validation failure is recorded
  as a failed candidate when `stop_on_error = FALSE`.

### 6. `ledgr_tune()` deferral is missing from non-goals

The UX doc explicitly defers `ledgr_tune()`, but the spec non-goals do not name
it.

Evidence:

- UX doc: `inst/design/architecture/ledgr_sweep_mode_ux.md` defers
  `ledgr_tune()`.
- Spec: non-goals omit `ledgr_tune()`.

Risk:

Ticket cut could reopen tune implementation during the sweep release.

Recommended disposition:

Add `ledgr_tune()` execution API to v0.1.8 non-goals.

## Moderate Findings

### 7. Auto-label stability should reference `canonical_json()`

The spec says auto labels use `jsonlite::toJSON()` with sorted keys. The
package's actual stable serialization helper is `canonical_json()`, which wraps
JSON serialization and enforces deterministic supported types.

Evidence:

- Code: `R/config-canonical-json.R`.
- Code: `R/param-grid.R` already uses `canonical_json()`.

Risk:

An implementation following the spec literally could bypass existing
canonicalization and introduce subtle instability.

Recommended disposition:

State that labels use `canonical_json()` backed by `jsonlite::toJSON()`, then a
short SHA-256 hash prefix.

### 8. Feature identity metadata needs clearer levels

The spec has a visible per-row `feature_fingerprints` column and also says
result attributes retain "feature identity."

Risk:

Implementers may duplicate per-candidate feature identity into attributes, or
store only the union and lose candidate-level feature provenance.

Recommended disposition:

Clarify:

- `feature_fingerprints` column is candidate-specific;
- result-level feature identity attribute is the sweep/precompute union and
  engine metadata.

### 9. Public date/slice scope is implicit

The architecture uses `candidate + data slice + output policy`, but v0.1.8
`ledgr_sweep()` has no `start`, `end`, or data-slice argument.

Risk:

Implementation may add a premature slice API or users may assume the first
sweep can evaluate arbitrary subranges.

Recommended disposition:

State explicitly:

> v0.1.8 sweep evaluates the experiment snapshot/range. Public data-slice
> objects and sweep-local `start`/`end` are deferred.

## Positive Findings

- The fold-core/output-handler split is correctly centered.
- The spec preserves one execution semantics across `ledgr_run()` and future
  `ledgr_sweep()`.
- Failure semantics correctly distinguish contract errors from candidate
  execution failures, pending the feature-factory refinement above.
- Parallelism is scoped correctly: sequential-first, parallel-ready, no public
  parallel surface.
- Cost-model and risk-layer boundaries are reserved without exposing public
  APIs.
- Parity requirements are strong and include warmup, cost behavior, final-bar
  behavior, indicator-parameter sweeps, and `config_hash`.
- The Definition of Done correctly includes design index and AGENTS/doc sync.

## Recommended Pre-Ticket Fix List

Before cutting v0.1.8 tickets, update the spec to:

1. Resolve seed support scope.
2. Correct the preflight package-dependency statement.
3. Reframe `ledgr_param_grid()` as existing code to audit/update.
4. Decide the `evaluation_scope` API/default.
5. Split feature-factory failures into structural vs candidate-specific.
6. Add `ledgr_tune()` to non-goals.
7. Reference `canonical_json()` for auto-label stability.
8. Clarify candidate-level vs result-level feature identity metadata.
9. State that public sweep-local data slices are deferred.
