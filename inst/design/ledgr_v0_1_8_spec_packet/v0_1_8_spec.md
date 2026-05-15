# ledgr v0.1.8 Spec

**Status:** Draft for ticket cut.
**Target Branch:** `v0.1.8`
**Scope:** Lightweight sweep mode, shared fold-core extraction, and internal
execution boundaries needed for future validation workflows.
**Non-scope:** Public parallel sweep, walk-forward analysis, PBO/CSCV,
public target-risk layer, public transaction-cost model API, paper/live
adapters, intraday semantics.

---

## 0. Source Inputs

This spec is based on the accepted sweep and architecture inputs:

- `inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md`
- `inst/design/architecture/ledgr_sweep_mode_ux.md`
- `inst/design/architecture/sweep_mode_code_review.md`
- `inst/design/spikes/ledgr_parallelism_spike/README.md`
- `inst/design/spikes/ledgr_parallelism_spike/summary_report.md`
- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`
- `inst/design/rfc/rfc_cost_model_architecture_response.md`
- `inst/design/rfc/rfc_parallelism_spike_architecture_consequences.md`
- `inst/design/rfc/rfc_parallelism_spike_architecture_consequences_response.md`
- `inst/design/rfc/rfc_rng_contract_v0_1_8.md`
- `inst/design/rfc/rfc_rng_contract_v0_1_8_response.md`
- `inst/design/rfc/rfc_sweep_candidate_promotion_contract_v0_1_8.md`
- `inst/design/rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis.md`
- `inst/design/rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis_response.md`
- `inst/design/rfc/rfc_sweep_promotion_context_v0_1_8_decision.md`
- `inst/design/audits/v0_1_8_spec_deep_review.md`
- `inst/design/contracts.md`
- `inst/design/ledgr_roadmap.md`

The spec does not reopen those design decisions unless explicitly called out as
an open decision below.

---

## 1. Thesis

v0.1.8 introduces sweep as a lightweight candidate-evaluation workflow without
creating a second execution engine.

The core architecture is:

```text
candidate + data slice + output policy -> candidate result
```

The long-term stack is:

```text
fold core
  -> ledgr_run()
  -> ledgr_sweep()
  -> ledgr_walk_forward()
  -> PBO/CSCV diagnostics
```

v0.1.8 may be sequential and modest. It must still preserve the internal
boundaries needed for future parallel sweep, walk-forward analysis, and
selection-bias diagnostics.

The central implementation requirement is a shared private fold core with
separate output handlers:

```text
ledgr_run()    -> fold core -> persistent DuckDB output handler
ledgr_sweep()  -> fold core -> in-memory summary output handler
```

Sweep explores candidates. `ledgr_run()` commits one selected candidate to the
experiment store with durable provenance.

---

## 2. Release Goals

v0.1.8 has seven goals:

1. Extract or define a private shared fold core used by both `ledgr_run()` and
   `ledgr_sweep()`.
2. Separate execution semantics from output persistence through an output
   handler boundary.
3. Add lightweight sequential `ledgr_sweep()` over typed parameter grids,
   reusing and updating the existing `ledgr_param_grid()` object.
4. Add precomputed feature support that deduplicates indicator work across
   candidates and validates snapshot/feature/warmup coverage.
5. Preserve exact parity between `ledgr_run()` and `ledgr_sweep()` for
   deterministic strategies on the same platform and R version.
6. Teach explicit in-sample/out-of-sample evaluation discipline in sweep docs.
7. Reserve, but do not publicly expose, the internal boundaries needed for
   parallel sweep and future cost-model/risk-layer work.

---

## 3. Evidence Baseline

| Evidence | Classification | v0.1.8 handling |
| --- | --- | --- |
| Current runner couples fold execution to DuckDB persistence through `write_persistent_telemetry` and `fail_run` closures | Architecture blocker | Move persistence/status mutation behind output-handler responsibilities. |
| Telemetry and preflight use package-global registries | Future parallelism risk | Keep sweep telemetry/preflight data in candidate results/output-handler flow, not hidden side channels. |
| `ledgr_run()` is the authoritative execution path | Contract invariant | Sweep must call the same fold core and must not duplicate execution semantics. |
| Sweep UX needs candidate tables, not durable run records | UX requirement | `ledgr_sweep()` returns `ledgr_sweep_results`; it does not write run artifacts. |
| Parameter selection on full snapshots creates selection leakage | Research correctness risk | Docs must teach manual train/sweep/evaluate workflow. |
| Indicator parameter sweeps multiply feature configurations | UX/architecture requirement | Feature factories must be params-aware and fingerprint/deduplicate resolved indicators. |
| Slice-aware warmup needs scoring range separate from lookback range | Future walk-forward constraint | v0.1.8 must not confuse first scored pulse with first warmup bar. |
| Parallelism spike shows plain payloads are good enough for first EOD sweep | Implementation guidance | Implement sequential-first and keep parallel transport optional/future. |
| `mirai` works on Windows and Ubuntu/WSL but is not needed for first release | Dependency discipline | Keep `mirai` out of mandatory dependencies unless public parallel sweep is added later. |
| `mori` reduces transport size but slows hot lookup by 2.6-3.3x in tested loops | Future transport constraint | Do not use `mori` as default v0.1.8 feature lookup representation. |
| Worker-local read-only DuckDB fanout did not create WAL/temp/lock side files in spike | Future transport evidence | Reserve fold input abstraction that can support snapshot-path lookup later. |
| Tier 2 parallel workers need package setup beyond tier label | Future parallelism constraint | Record worker package/dependency setup as future design input, not v0.1.8 public API. |
| Cost-model RFC requires timing and cost boundaries | Future cost API constraint | Reserve internal fill proposal/cost resolver boundary without exporting cost-model factories. |

---

## 4. User-Facing Scope

### 4.1 `ledgr_param_grid()`

Audit and update the existing typed parameter-grid constructor for sweep use.
`ledgr_param_grid()` already exists and is exported before v0.1.8; this release
does not need a second grid object.

Required behavior:

- returns a `ledgr_param_grid` object;
- accepts named and unnamed candidate parameter lists;
- preserves user-supplied candidate labels verbatim;
- generates stable labels for unnamed candidates from a short hash of
  canonical params JSON;
- errors loudly on duplicate candidate labels;
- treats the params list as candidate identity;
- supports ordinary strategy params and indicator params used by feature
  factories.

Example:

```r
param_grid <- ledgr_param_grid(
  conservative = list(threshold = 0.010, qty = 10, sma_n = 20),
  moderate     = list(threshold = 0.005, qty = 10, sma_n = 20),
  aggressive   = list(threshold = 0.002, qty = 20, sma_n = 10)
)
```

The sweep label is not a committed `run_id`. When promoting a candidate, users
must supply an explicit `run_id` to `ledgr_run()`.

Auto-generated labels must use ledgr's existing `canonical_json()` helper,
which recursively sorts keys and serializes with `jsonlite::toJSON()`, followed
by a short SHA-256 hash prefix. The label contract must not depend on
`deparse()`, list insertion order, or platform-specific object printing.

The existing print/help text that says v0.1.7 stores the grid only and no
sweep/tune execution is exported must be updated for v0.1.8. The updated text
should still state that grid labels are not committed run IDs.

### 4.2 `ledgr_precompute_features()`

Add a typed precompute helper for sweep feature payloads.

Required behavior:

- returns a `ledgr_precomputed_features` object;
- records snapshot hash, universe, scoring range, feature engine version, and
  indicator fingerprints;
- validates the object against the experiment snapshot at sweep time;
- supports concrete feature lists/maps shared by all candidates;
- supports `features = function(params) list(...)`;
- evaluates feature factories across the full grid;
- deduplicates identical indicator configurations by fingerprint;
- validates feature coverage per candidate, not just for the first grid row;
- treats `start` and `end` as scoring range bounds;
- extends or records warmup lookback requirements separately from scoring
  range.

v0.1.8 uses a precompute-coverage representation rather than a public
data-slice object. A `ledgr_precomputed_features` object must record:

- scoring range metadata derived from `start` and `end` or the full snapshot
  range;
- the warmup range required to make the first scored pulse valid;
- per-feature or per-candidate warmup requirements sufficient to explain why a
  candidate is infeasible;
- the union of resolved feature fingerprints across the parameter grid.

Static coverage mismatches in this object are contract errors. Candidate-level
warmup infeasibility discovered after resolving a candidate's params is a
candidate execution failure.

Indicator parameter sweeps are ordinary sweep params. v0.1.8 must not introduce
a separate indicator-sweep API.

Example:

```r
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = momentum,
  features = function(params) list(
    ledgr_ind_sma(params$sma_n),
    ledgr_ind_rsi(params$rsi_n)
  )
)

param_grid <- ledgr_param_grid(
  list(sma_n = 20, rsi_n = 14, threshold = 0.010, qty = 10),
  list(sma_n = 50, rsi_n = 14, threshold = 0.010, qty = 10),
  list(sma_n = 50, rsi_n = 21, threshold = 0.005, qty = 10)
)

features <- ledgr_precompute_features(exp, param_grid)
```

### 4.3 `ledgr_sweep()`

Add a lightweight exploratory sweep runner.

Required behavior:

- accepts an experiment and `ledgr_param_grid`;
- optionally accepts `ledgr_precomputed_features`;
- accepts `seed = NULL` or an integer-like scalar execution seed;
- evaluates the experiment snapshot/range; public sweep-local `start`, `end`,
  or data-slice arguments are deferred;
- warns when the grid exceeds the v0.1.8 threshold of 20 combinations and no
  precomputed features are supplied;
- runs candidates through the shared fold core;
- returns a `ledgr_sweep_results` object;
- does not write DuckDB run artifacts;
- does not auto-promote candidates to the experiment store;
- captures candidate-level execution failures without aborting the entire sweep
  by default;
- supports `stop_on_error = TRUE` for sequential debugging;
- aborts unconditionally for contract validation errors such as invalid grids,
  mismatched precomputed features, snapshot mismatch, or invalid experiment
  shape;
- keeps underlying rows in param-grid order;
- may use a print method that displays a curated subset or default display
  order, but must document any display-only sorting clearly.

Candidate ranking is caller-owned in v0.1.8. `ledgr_sweep()` does not take an
`objective` argument and does not impose a ranking rule.

Example:

```r
results <- exp |>
  ledgr_sweep(
    param_grid = param_grid,
    precomputed_features = features,
    stop_on_error = FALSE
  )

candidate <- results |>
  dplyr::filter(status == "DONE") |>
  dplyr::arrange(dplyr::desc(total_return)) |>
  ledgr_candidate(1)

bt <- exp |>
  ledgr_promote(candidate, run_id = "momentum_v1")
```

### 4.4 `ledgr_sweep_results`

`ledgr_sweep()` returns a classed tibble-like object.

Required visible columns:

- `run_id`;
- `status`;
- `final_equity`;
- `total_return`;
- `annualized_return`;
- `volatility`;
- `sharpe_ratio`;
- `max_drawdown`;
- `n_trades`;
- `win_rate`;
- `avg_trade`;
- `time_in_market`;
- `execution_seed`;
- `error_class`;
- `error_msg`;
- `params`;
- `warnings`;
- `feature_fingerprints`;
- `provenance`;

`run_id` is the sweep candidate label from `ledgr_param_grid()` or the
auto-hash label for unnamed candidates. It is not a committed experiment-store
run ID until the user promotes the candidate through `ledgr_promote()` or
`ledgr_run()`.

`execution_seed` is the actual fold seed used by the candidate. It is
`NA_integer_` when `ledgr_sweep(seed = NULL)`. Promotion maps
`NA_integer_` to `seed = NULL`; otherwise the value is passed as the committed
run's `seed`.

The metric columns intentionally include the standard summary metrics used by
run comparison output so caller-owned ranking can be done directly on the sweep
table. Failed candidate rows set metric columns to `NA` while preserving
failure status and error fields.

`warnings` is a list column. It stores candidate-level warning conditions and
non-fatal ledgr interpretation warnings without flattening condition classes
into display strings.

`provenance` is a row-level list column of typed named lists. Each row must
include:

- `provenance_version = "ledgr_provenance_v1"`;
- `snapshot_hash`;
- `strategy_hash`;
- `feature_set_hash`;
- `master_seed`;
- `seed_contract`;
- `evaluation_scope`.

The row-level provenance bundle is compact lineage, not full durable run
provenance. It exists so a candidate row remains understandable after filtering,
sorting, slicing, RDS save/load, or handoff to another agent. The
`feature_set_hash` is candidate-specific and is derived from that row's resolved
`feature_fingerprints`.

Identity metadata lives in object attributes, not repeated visible columns, as
specified in the UX proposal. At minimum it must retain:

- snapshot identity;
- strategy identity;
- strategy preflight classification;
- feature identity;
- opening state and execution assumptions;
- RNG contract metadata, including master seed and seed derivation
  contract/version.

The per-candidate derived seed is the row-level `execution_seed` column.
`master_seed` is intentionally duplicated in result-level attributes and in the
row-level `provenance` list so a standalone candidate row remains
self-contained.

The strategy preflight classification is retained as an attribute for candidate
promotion and audit support. Field naming can be settled during implementation,
but the value must remain available from the `ledgr_sweep_results` object.

The result object also carries an `evaluation_scope` attribute. v0.1.8 always
sets this to `exploratory`. User-supplied evaluation-scope labels are deferred
until ledgr has a clearer data-slice or split-snapshot surface. The default must
not imply out-of-sample evidence.

The visible `feature_fingerprints` column is candidate-specific. The
result-level feature identity attribute records the sweep/precompute union,
feature engine version, and related metadata needed to validate or rerun the
sweep object.

This metadata is compact candidate identity. It is not full durable
experiment-store run provenance. Durable run provenance is created by a
promoted `ledgr_run()`, and v0.1.8 promotion context records the selected
candidate and selection view that led to that run.

The default print method must be curated. It should show scalar selection and
ranking fields, including `execution_seed`, and hide the four list columns
(`params`, `feature_fingerprints`, `warnings`, and `provenance`) unless the
user requests a verbose print or explicitly selects those columns. The footer
must note that the hidden list columns exist.

### 4.5 Evaluation Discipline Documentation

The first sweep docs must teach this promotion path:

```text
source bars
  -> train snapshot
  -> test snapshot
  -> sweep on train snapshot
  -> lock selected params
  -> optionally commit selected params on the train snapshot
  -> evaluate locked params on the test snapshot with ledgr_run()
```

Docs must state:

```text
Reproducibility and selection integrity are orthogonal. Provenance records what
happened. It does not prove that the candidate-selection process was sound.
```

`ledgr_snapshot_split()` is not required in v0.1.8. Users can create train and
test snapshots manually by filtering source bars before snapshot creation.

### 4.6 Candidate Selection And Promotion

`ledgr_candidate()` extracts one promotion-ready candidate from a sweep result
or from a tibble-like object that retains the required candidate columns.

Required behavior:

- accepts a `ledgr_sweep_results` object or any tibble-like input containing
  `run_id`, `params`, `execution_seed`, and `provenance`;
- accepts a character scalar to select by `run_id` or an integer-like scalar to
  select by row position, defaulting to the first row of the input;
- errors by default when the selected candidate has `status = "FAILED"`;
- supports `allow_failed = TRUE` for diagnostic extraction only;
- returns a `ledgr_sweep_candidate` object containing the selected row plus any
  available sweep-level metadata;
- emits a one-line message, not a warning or error, when the input is not a
  classed `ledgr_sweep_results` object and sweep-level metadata is absent;
- fails lazily when a later metadata-dependent operation requires missing
  metadata.

`ledgr_promote()` is the ergonomic path from candidate to committed run. Users
must not need to remember how to extract `params[[1]]` or the candidate seed.

Required public shape:

```r
ledgr_promote(exp, candidate, run_id, note = NULL, require_same_snapshot = TRUE)
```

Required behavior:

- calls `ledgr_run()` with `params = candidate$params` and
  `seed = candidate$execution_seed`;
- maps `execution_seed = NA_integer_` to `seed = NULL`;
- writes a durable `run_promotion_context` record after the committed run
  succeeds;
- returns the committed `ledgr_backtest`;
- if the promotion-context write fails, emits a warning and returns the
  committed run without rollback;
- when `require_same_snapshot = TRUE`, verifies that the candidate
  `provenance$snapshot_hash` matches the target experiment snapshot hash and
  errors clearly if the field is missing or mismatched.
- `require_same_snapshot` defaults to `TRUE`; train/test promotion and other
  cross-snapshot evaluations must opt in explicitly with
  `require_same_snapshot = FALSE`.

Primary train/test promotion example:

```r
candidate <- train_results |>
  dplyr::filter(status == "DONE") |>
  dplyr::arrange(dplyr::desc(sharpe_ratio)) |>
  ledgr_candidate(1)

bt_test <- test_exp |>
  ledgr_promote(
    candidate,
    run_id = "momentum_v1_test",
    note = "Selected highest Sharpe candidate from train sweep.",
    require_same_snapshot = FALSE
  )
```

Same-snapshot replay is supported when the user wants to reproduce the sweep
candidate exactly on the same snapshot:

```r
bt_replay <- train_exp |>
  ledgr_promote(
    candidate,
    run_id = "momentum_v1_train_replay",
    require_same_snapshot = TRUE
  )
```

The `ledgr_sweep_candidate` print method should show the selected candidate's
status, params, execution seed, strategy name plus hash when available, snapshot
hash, feature-set hash, evaluation scope, and promotion note status. If strategy
name is not available, fall back to hash only rather than printing an empty
field.

### 4.7 Promotion Context Storage

v0.1.8 stores durable selection-audit metadata for runs created through
`ledgr_promote()`. This is promotion context, not full sweep persistence.

Add a dedicated experiment-store table using schema version `107`:

```sql
CREATE TABLE IF NOT EXISTS run_promotion_context (
  run_id                    TEXT NOT NULL PRIMARY KEY,
  promotion_context_version TEXT NOT NULL,
  source                    TEXT NOT NULL,
  promoted_at_utc           TIMESTAMP NOT NULL,
  note                      TEXT,
  selected_candidate_json   TEXT NOT NULL,
  source_sweep_json         TEXT NOT NULL,
  candidate_summary_json    TEXT NOT NULL
)
```

Use `promotion_context_version = "ledgr_promotion_v1"`.

`ledgr_sweep()` generates a `sweep_id` at sweep start. The ID identifies a
research event, not a deterministic input hash. Two identical sweeps should get
different IDs. Generation must not touch `.Random.seed` or strategy RNG state;
use an internal helper, tentatively `ledgr_generate_sweep_id()`, based on
non-RNG process/session/counter information. `sweep_id` is stored on
`ledgr_sweep_results`, copied into `ledgr_sweep_candidate`, and written into
`source_sweep_json`.

Nested durable fields are canonical JSON strings:

- `selected_candidate_json`;
- `source_sweep_json`;
- `candidate_summary_json`.

`candidate_summary_json` stores the compact summary of the table passed to
`ledgr_candidate()`. If the user filtered and sorted before candidate
selection, the stored summary records that filtered/sorted selection view and
preserves row order. It does not try to recover the original full sweep universe
in v0.1.8.

Candidate summary records include the scalar fields from the sweep result,
`execution_seed`, `params_json`, `provenance_json`, `n_warnings`,
`warning_classes`, `error_class`, and `error_msg`.

Candidate summaries must be converted to JSON-compatible records before
calling `canonical_json()`. Do not pass tibbles, list-column condition objects,
or arbitrary R objects directly to `canonical_json()`. Store warning summaries
as `n_warnings` and `warning_classes`; do not store full R condition objects in
durable promotion context.

Expose read-only helpers:

```r
ledgr_promotion_context(bt)
ledgr_run_promotion_context(exp, run_id)
ledgr_run_info(... )$promotion_context
```

Direct `ledgr_run()` calls return `NULL` promotion context. The helpers must
not execute strategy code or mutate store state.

---

## 5. Internal Architecture Requirements

### R1. Shared Fold Core

Define or extract a private fold core, tentatively `ledgr_run_fold()`.

The final function name is internal. The contract is mandatory.

The fold core must not be exported, added to `NAMESPACE`, or listed in pkgdown.

The fold core owns deterministic execution:

- pulse calendar order;
- pulse context construction;
- registered feature lookup;
- strategy invocation;
- target validation;
- reserved future target-risk step, a no-op in v0.1.8;
- fill timing;
- cost resolution;
- final-bar no-fill behavior;
- cash, position, and state transitions;
- event-stream meaning.

`ledgr_run()` and `ledgr_sweep()` must both execute candidates through this
same fold core.

The v0.1.9 risk layer is expected to occupy the reserved slot between target
validation and fill timing with `risk_fn(targets, ctx, params) -> targets`.
The v0.1.8 extraction must not collapse target validation and fill timing into
a single step that forecloses this insertion point.

### R2. Output Handler Boundary

Separate fold execution from output retention/persistence.

Output handlers decide what to keep:

- full DuckDB ledger, run status, provenance, and telemetry for `ledgr_run()`;
- in-memory candidate summaries for `ledgr_sweep()`;
- failure records and warnings;
- future worker-local or selected-candidate outputs.

The fold core must not directly depend on:

- persistent DuckDB run writes;
- experiment-store status mutation;
- package-global telemetry side channels;
- sweep result formatting.

The current runner coupling points that must be routed through the output
boundary are:

- `write_persistent_telemetry`;
- `fail_run`;
- `.ledgr_telemetry_registry`;
- `ledgr_store_run_telemetry()`;
- `ledgr_get_run_telemetry()`;
- `.ledgr_preflight_registry`, to the extent it carries timing data that could
  leak across concurrent evaluations later.

### R3. Strategy Preflight Boundary

Strategy preflight is a pre-fold gate. It classifies the strategy before normal
execution begins and feeds the result into the output handler.

For v0.1.8:

- the strategy function is fixed across candidates;
- params vary across candidates;
- preflight may run once per sweep if current preflight classification depends
  only on the strategy function body and non-candidate-specific referenced
  symbols;
- if preflight inspects feature definitions or other candidate-varying state,
  it must run once per candidate instead.

The current preflight API already exposes package-qualified dependencies in its
`package_dependencies` field. That is useful input for future parallel Tier 2
worker setup, but it is not yet a complete worker setup contract. v0.1.8 does
not expose `worker_packages` or any public parallel dependency-management API.

### R4. Feature Lookup Boundary

The fold core must support feature lookup from a precomputed payload rather
than forcing live feature computation through the existing registry path.

The fold input abstraction should be compatible with two shapes:

- a precomputed in-memory R payload;
- a sealed snapshot path plus metadata for future worker-local read-only
  lookup.

v0.1.8 should implement the in-memory payload path first. It must not make the
fold interface payload-only in a way that prevents future snapshot-path lookup.

Feature lookup correctness must not depend on cache warmth or daemon
assignment. Cache warming is an optimization only.

### R5. Fill Timing And Cost Boundary

Reserve a private timing/cost boundary.

Internal chain:

```text
validated_targets
  -> future risk step, no-op in v0.1.8
  -> next_open_timing()
  -> ledgr_fill_proposal
  -> cost resolver
  -> ledgr_fill_intent
  -> fold event
```

The internal `ledgr_fill_proposal` type must carry, at minimum:

- instrument ID;
- side;
- quantity;
- decision timestamp;
- execution timestamp;
- execution price source, initially next open;
- execution-bar data needed by the default resolver and reserved for future
  OHLCV-aware cost models, including volume for future market-impact and
  liquidity diagnostics.

v0.1.8 may keep the existing helper implementation internally, but the fold
core must not treat scalar `spread_bps` and `commission_fixed` as the only
architectural primitive.

Hard constraints:

- strategy `ctx` remains decision-time only;
- cost resolution uses a separate fill/execution context;
- execution context may reserve next-bar open/high/low/close/volume for future
  cost models;
- quantity mutation is out of scope for the first cost contract;
- output handlers must not compute or reinterpret costs;
- existing scalar `spread_bps` and `commission_fixed` behavior must remain
  unchanged;
- `config_hash` must remain byte-identical for unchanged scalar execution
  config.

No public cost-model factories are exported in v0.1.8.

### R6. RNG Contract

v0.1.8 makes seed an explicit first-class execution input.

For `ledgr_run()`:

- `seed = NULL`: no `set.seed()` call at fold entry; no stochastic
  reproducibility claim; deterministic strategies are unaffected;
- `seed = integer`: applied via `set.seed()` inside the fold core at fold
  entry, stored in `config_json` and `config_hash`, and exposed in run
  provenance.

For `ledgr_sweep()`:

- `seed = NULL`: no candidate seed is derived; the fold core receives
  `seed = NULL`;
- `seed = integer`: the sweep dispatcher derives one seed per candidate before
  candidate dispatch and passes the derived seed into the fold core as an
  explicit candidate input.

The internal derivation helper, tentatively `ledgr_derive_seed(base_seed,
salt)`, must be deterministic, platform-stable, and independent of R's current
RNG state. The sweep derivation salt is:

```text
paste("candidate", candidate_label, sep = "::")
```

The fold core must not read `.Random.seed`, daemon RNG state, worker assignment,
or ambient session state to determine its seed. The explicit fold-core seed is
the only source of truth. Future parallel sweep must therefore produce the same
candidate result regardless of daemon assignment.

Candidate result metadata records `master_seed` in result attributes and
row-level `provenance`; the per-candidate derived seed is recorded as the
visible row-level `execution_seed` column.

`ctx$seed(stream = "default")` is recommended but separable. It may be deferred
to v0.1.8.x if stochastic strategies are not part of the v0.1.8 public strategy
surface. The fold-core seed threading must support adding `ctx$seed()` later
without interface changes. If `ctx$seed()` ships, calling it with `seed = NULL`
must be a strategy contract error.

Strategy bodies that call `set.seed()` or `RNGkind()` are Tier 3 because they
mutate global RNG state. Strategy bodies that call ambient RNG functions such
as `runif()`, `rnorm()`, or `sample()` without a ledgr seed helper are Tier 2
with a loud preflight note, not Tier 3 by default.

### R7. Interrupt Semantics

v0.1.8 uses discard-all interrupt semantics for sweep.

If the user interrupts a sweep, ledgr does not promise a partial
`ledgr_sweep_results` object. Partial result checkpointing is deferred.

---

## 6. Parity Contract

The v0.1.8 test suite must prove that `ledgr_run()` and `ledgr_sweep()` agree
for deterministic strategies on the same platform/R version.

At minimum, compare:

- target validation;
- feature values;
- pulse order;
- fill timing;
- fill prices;
- fees;
- cash deltas;
- final cash;
- final positions;
- final equity;
- equity curve values where retained;
- fills and trades where retained or reconstructable;
- retained standard summary metric columns;
- long-only behavior;
- final-bar no-fill behavior;
- warmup behavior;
- preflight tier;
- deterministic `seed = NULL` behavior;
- seeded random behavior under explicit non-`NULL` seeds;
- `config_hash` for unchanged scalar execution config.

Numeric equality is exact within the same platform/R version for deterministic
strategies. Cross-platform floating-point differences are out of scope unless a
specific failure appears.

---

## 7. Failure Semantics

`ledgr_sweep()` distinguishes contract errors from candidate execution
failures.

Contract errors abort the sweep unconditionally:

- invalid `ledgr_param_grid`;
- duplicate candidate labels;
- invalid experiment shape;
- strategy preflight rejects the strategy, including `tier_3` classification;
- precomputed feature object does not match snapshot hash;
- precomputed feature object does not cover static universe/date/scoring-range
  needs;
- precomputed feature object is missing required scoring or warmup metadata;
- structural feature-factory invalidity that prevents the grid from being
  interpreted at all;
- unsupported public API combination.

Candidate execution failures are recorded per candidate when
`stop_on_error = FALSE`:

- strategy error;
- target validation failure for that candidate;
- candidate-specific warmup infeasibility;
- candidate-specific feature lookup failure;
- candidate-specific feature materialization or validation failure, such as one
  params row producing an invalid indicator configuration;
- candidate-specific feature coverage failure after resolving params, such as a
  warmup requirement that cannot be satisfied on the snapshot range;
- fill/execution error.

When `stop_on_error = TRUE`, sequential sweep aborts and rethrows the
candidate-level condition. If future parallel sweep is added, first-error
semantics must be specified separately because worker completion order is not
deterministic.

---

## 8. Parallelism Position

v0.1.8 is sequential-first. Public parallel sweep is not required.

Sequential sweep retains one candidate's in-flight event state at a time.
Audit-log-style buffering is proportional to universe size and pulse count for
the current candidate, not the full grid. The final `ledgr_sweep_results`
object grows with the number of candidates because it retains one summary row
per candidate plus result-level metadata.

The implementation must still preserve these constraints:

- parallelism belongs at the candidate dispatch loop, not inside the fold core;
- `mirai` remains optional and at most a `Suggests` dependency;
- `workers > 1` without the required backend should fail loudly if a parallel
  API is later exposed;
- large feature payloads should be preloaded once during worker setup, not sent
  per candidate;
- plain in-memory matrices are the preferred v0.1.8 hot feature lookup
  representation;
- `mori` is reserved for future transport/memory-pressure use cases;
- worker-local read-only DuckDB lookup is reserved as a future transport path;
- Tier 2 package-dependent strategy code needs explicit worker setup before
  future parallel dispatch;
- worker output must return to the orchestrator; workers must not write shared
  persistent run outputs.

No public `workers`, `backend`, `worker_packages`, or parallel output policy
surface is required in v0.1.8 unless ticket cut explicitly adds it.

---

## 9. Non-Goals

v0.1.8 must not include:

- walk-forward API;
- PBO/CSCV diagnostics;
- `ledgr_tune()` execution API;
- public parallel sweep feature;
- partial sweep result checkpointing;
- public target-risk layer;
- public cost-model factories;
- exchange/broker fee templates;
- market-impact models;
- liquidity clipping or quantity mutation;
- separate sweep execution grid;
- mandatory `ledgr_snapshot_split()`;
- paper/live adapter behavior;
- intraday execution semantics;
- workflow/project template generator;
- broad strategy cookbook.

Items deferred from this spec should be recorded in `inst/design/horizon.md` or
the roadmap only when they are supported by evidence or a concrete design
constraint.

---

## 10. Documentation Requirements

v0.1.8 documentation must include:

- sweep mental model: explore with `ledgr_sweep()`, commit with `ledgr_run()`;
- manual train/sweep/evaluate workflow;
- warning that committed full-snapshot reruns after parameter selection remain
  in-sample artifacts;
- examples for ordinary strategy params;
- examples for indicator parameter sweeps through feature factories;
- explanation of precomputed features and feature deduplication;
- explanation of candidate status/failure handling;
- promotion example through `ledgr_candidate()` and `ledgr_promote()`;
- explanation of `execution_seed` and compact row-level `provenance`;
- note that promotion context is durable selection-audit metadata, not full
  sweep persistence or full run provenance;
- note that ranking is caller-owned in v0.1.8.

The docs should avoid implying that sweep results are ranked by ledgr unless
the display method performs display-only sorting and says so explicitly.

---

## 11. Test Requirements

The v0.1.8 implementation must add tests for:

- `ledgr_param_grid()` named and unnamed labels;
- stable generated labels from canonical params JSON;
- existing `ledgr_param_grid()` print/help text updated for sweep while still
  clarifying that grid labels are not committed run IDs;
- duplicate label errors;
- concrete-feature precompute across multiple candidates;
- feature-factory precompute across multiple candidates;
- feature deduplication by fingerprint;
- candidate-specific feature fingerprint recording;
- candidate-specific warmup infeasibility;
- precomputed-feature scoring range and warmup range metadata;
- snapshot hash mismatch in precomputed feature object;
- static universe/date/scoring-range coverage mismatch;
- basic successful sequential sweep;
- warning when grid size exceeds 20 and no precomputed features are supplied;
- candidate failure capture with `stop_on_error = FALSE`;
- candidate error rethrow with `stop_on_error = TRUE`;
- contract errors aborting regardless of `stop_on_error`;
- Tier 3 strategy preflight aborting before any candidate evaluation;
- candidate-specific feature materialization failures recorded per candidate;
- `ledgr_sweep_results` columns/metadata;
- standard sweep metric columns including `annualized_return`, `volatility`,
  `sharpe_ratio`, `avg_trade`, and `time_in_market`;
- `warnings` as a list column preserving condition objects/classes;
- `ledgr_sweep_results` identity metadata stored as attributes, not visible
  duplicate columns;
- default `evaluation_scope = "exploratory"` attribute;
- result row order matching parameter-grid order;
- `execution_seed` as a visible row-level column, with `NA_integer_` for
  unseeded candidates;
- `provenance` as a row-level list column with
  `provenance_version = "ledgr_provenance_v1"`;
- default sweep print showing `execution_seed` and hiding the four list columns
  with a footer note;
- `ledgr_candidate()` preserving params, execution seed, provenance, and
  available sweep metadata;
- `ledgr_candidate()` degraded-mode behavior on tibble-like inputs that are not
  classed `ledgr_sweep_results`;
- failed-candidate extraction error by default, and diagnostic
  `allow_failed = TRUE`;
- `ledgr_promote()` forwarding params and execution seed to `ledgr_run()`;
- `ledgr_promote(require_same_snapshot = TRUE)` mismatch and missing-field
  errors;
- `run_promotion_context` table creation and schema version `107`;
- `sweep_id` generated at sweep start without touching `.Random.seed`;
- successful promotion context write after committed run success;
- promotion-context write failure warning without rolling back the committed
  run;
- promotion-context read helpers returning parsed context for promoted runs and
  `NULL` for direct runs;
- `candidate_summary_json` preserving the filtered/sorted selection view passed
  to `ledgr_candidate()`;
- promotion context serializing warnings as `n_warnings` and
  `warning_classes`, not full R condition objects;
- public non-`NULL` seed accepted by `ledgr_run()` and stored in existing
  execution identity;
- `ledgr_sweep(seed = integer)` deriving stable per-candidate seeds before
  candidate dispatch;
- `ledgr_derive_seed()` fixture stability and independence from ambient RNG
  state;
- `seed = NULL` causing no fold-entry `set.seed()` side effect;
- sweep candidate metadata recording `master_seed` and `execution_seed`;
- parity between `ledgr_run()` and `ledgr_sweep()` for deterministic strategy;
- parity for at least one params grid where changing params changes the
  registered feature set, not only strategy thresholds;
- parity for fees/spread/cash deltas;
- parity for the retained standard summary metric columns;
- parity for final-bar no-fill behavior;
- parity for warmup behavior;
- parity for deterministic `seed = NULL` behavior;
- parity for seeded random behavior under explicit non-`NULL` seeds;
- `config_hash` stability after internal cost-boundary refactor.

Full package tests and package check are required before release gate.

---

## 12. Ticket-Cut Guidance

Suggested implementation tickets:

1. Fold-core/output-handler extraction.
2. Existing `ledgr_param_grid()` audit/update for sweep.
3. Precomputed feature object and validation.
4. Basic sequential `ledgr_sweep()` and `ledgr_sweep_results`.
5. Feature-factory indicator sweep support.
6. Parity test suite.
7. RNG boundary and per-candidate seed derivation.
8. Sweep output provenance columns and print curation.
9. Candidate selection/promotion API.
10. Promotion-context storage and read helpers.
11. Evaluation-discipline documentation.
12. Internal timing/cost boundary preservation.
13. Release gate and docs/index sync.

The fold-core/output-handler extraction should be reviewed before broadening
the public sweep surface. If this boundary is wrong, every later ticket becomes
harder to verify.

---

## 13. Definition Of Done

v0.1.8 is complete when:

- `ledgr_run()` and `ledgr_sweep()` share the same private fold core;
- persistence/status/telemetry behavior is routed through output handlers;
- existing `ledgr_param_grid()` has been updated for sweep and has stable
  candidate identity semantics;
- `ledgr_precompute_features()` exists and validates snapshot/feature/warmup
  coverage;
- indicator parameter sweeps work through params-aware feature factories;
- `ledgr_sweep()` returns summary-only `ledgr_sweep_results`;
- `ledgr_sweep_results` uses visible `run_id` candidate labels and stores
  identity metadata plus `evaluation_scope = "exploratory"` in attributes;
- `ledgr_sweep_results` stores row-level `execution_seed` and compact
  `provenance` so candidates remain promotion-ready after filtering, sorting,
  slicing, or RDS save/load;
- `ledgr_sweep_results` retains the standard summary metrics needed for
  caller-owned ranking;
- `ledgr_candidate()` and `ledgr_promote()` provide the public promotion path
  without requiring users to manually extract `params[[1]]` or seed values;
- promoted runs created by `ledgr_promote()` store durable
  `run_promotion_context` selection-audit metadata;
- candidate failures are captured without losing the whole sweep by default;
- contract failures abort loudly;
- Tier 3 strategies abort before candidate evaluation;
- public execution seeds are accepted, stored in execution identity, and used as
  explicit fold-core inputs;
- sweep candidate seeds are derived by the dispatcher from master seed and
  candidate label, not from ambient RNG state;
- ranking is caller-owned;
- sweep docs teach train/sweep/evaluate discipline;
- parity tests prove same-platform deterministic equivalence with
  `ledgr_run()`;
- scalar spread/commission behavior and `config_hash` remain unchanged;
- no public parallel, risk-layer, cost-model, walk-forward, PBO/CSCV, or
  paper/live API has been added;
- no `ledgr_tune()` execution API has been added;
- `inst/design/README.md`, `AGENTS.md`, `docs/AGENTS.md`, and the roadmap point
  at the current packet and current design status;
- local tests, package check, pkgdown checks, and CI release gates pass.
