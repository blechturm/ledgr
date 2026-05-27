# ledgr Horizon

**Status:** Active parking lot.
**Authority:** Non-binding design memory.

This file holds design observations that are not ready for the roadmap, an ADR,
or a versioned spec packet. It is not a backlog and does not imply commitment.

Use lightweight entries only:

```text
### YYYY-MM-DD [area] Short title

Freeform note.
```

Area tags:

```text
execution, ux, data, risk, cost, research, infrastructure, adapters
```

Do not add owners, due dates, priorities, acceptance criteria, or ticket
statuses. If an item becomes planned work, promote it into the roadmap, an RFC,
an architecture note, or a spec packet.

## Open

### 2026-05-26 [execution] Accepted OMS direction and intraday-safe target-decision storage

The accepted OMS synthesis is
`inst/design/rfc/rfc_ledgr_oms_seed_synthesis.md`. It binds a future v0.2.x
two-stream design: `order_events` records engine-owned order lifecycle, while
`ledger_events` remains accounting truth. The strategy contract stays
`function(ctx, params) -> full named numeric target vector`; paper/live adapters
remain deferred to v0.3.0+; and no sweep-to-live path is allowed.

The important long-horizon storage lesson is that target-decision persistence
must bind identity and reconstructability, not a universal full-JSON payload per
decision row. First EOD implementations may store full vectors directly, but
intraday-compatible designs need retention-dependent, batchable, and
potentially deduplicated/sparse/columnar/payload-reference storage without
destructive migration from the EOD shape.

### 2026-05-25 [infrastructure] Pre-CRAN compatibility policy

Until ledgr is released on CRAN, stored artifacts, database schemas, config
hashes, provenance formats, and experimental APIs may change without backward
compatibility or a deprecation cycle. Pre-CRAN artifacts are development
artifacts; users should expect to rerun experiments after upgrading when a
cycle changes storage, hashing, or execution contracts.

This does not weaken current-version trust. Fingerprint pins, release gates,
contract tests, hash verification, and reproducibility discipline remain
load-bearing for agent containment and within-cycle correctness. Once ledgr
reaches CRAN, revisit this policy and define explicit compatibility and
deprecation rules.

### 2026-05-15 [adapters] Multi-output indicator authoring bundles

Consider a v0.1.8.x adapter/indicator UX slice for multi-output indicator
authoring bundles. The accepted RFC direction is an explicit
`ledgr_indicator_bundle` class that flattens at feature declaration boundaries
and materializes to ordinary single-output `ledgr_indicator` objects. This
should improve TTR and future talib multi-output ergonomics without changing
the core `series_fn()` contract, feature provenance, or strategy feature
lookup.

Key design decisions to preserve: bundle UX first, grouped precompute batching
later; no polymorphic `ledgr_ind_ttr()` return type; output-specific
fingerprints remain the external identity; default multi-output feature IDs use
a normalized function-family prefix such as `bbands_dn`; `prefix = NULL` is an
explicit raw-output-name opt-in; instrument IDs never enter feature IDs.

RFC thread:

- `inst/design/rfc/rfc_multi_output_indicator_ux.md`
- `inst/design/rfc/rfc_multi_output_indicator_ux_response.md`
- `inst/design/rfc/rfc_multi_output_indicator_ux_maintainer_response.md`
- `inst/design/rfc/rfc_multi_output_indicator_ux_synthesis.md`

### 2026-05-13 [data] Data input and snapshot creation article

The experiment-store article currently carries some advanced low-level CSV
snapshot material. A future documentation pass may split this into a focused
"Data Input And Snapshot Creation" article so the experiment-store article can
stay centered on run management, labels, tags, comparisons, recovery, and
reopening.

### 2026-05-13 [execution] Compact execution semantics article

Several public articles explain next-open fills, targets-as-holdings,
decision-time close sizing, final-bar no-fill warnings, and open-position
handling. Consider a short consolidated article once sweep design stabilizes,
so users have one compact reference for decisions, targets, fills, and
last-bar behavior.

### 2026-05-13 [ux] Future tune-wrapper naming

After `ledgr_sweep()` exists and the fold core is stable, revisit whether a
convenience wrapper such as `ledgr_tune()` is useful. This should remain parked
until sweep result shape, objective/ranking ownership, and candidate promotion
are stable.

### 2026-05-26 [ux] Tidy/vectorized strategy authoring layer

Active parameterized feature aliases give strategies stable column names such
as `fast` and `slow`. That may eventually support a tidy or vectorized
strategy-authoring layer for stateless, cross-sectional pulse logic.

Possible future shape:

```r
strategy <- ledgr_vector_strategy(function(features, ctx, params) {
  transform(features, target = ifelse(fast > slow, params$qty, 0))
})
```

or a more ledgr-native signal wrapper that maps row-wise feature predicates to
a full named target vector.

This should not replace the core `function(ctx, params)` strategy contract.
It is only appropriate for strategies that read current pulse data, compute
row-wise instrument targets, and do not require arbitrary per-instrument
control flow, order-dependent allocation, or custom state mutation. Keep it
out of v0.1.8.4; active aliases and grid helpers should stabilize first.

### 2026-05-15 [ux] Parameter-grid construction helpers

`ledgr_param_grid()` is the right explicit base contract, but larger studies
will need ergonomic helpers for constructing grids without turning sweep into
an objective/ranking API.

Possible future helpers:

```r
ledgr_grid_cross(
  sma_n = c(20, 50, 100),
  threshold = c(0.005, 0.010),
  qty = c(10, 20)
)

ledgr_grid_named(
  conservative = list(...),
  balanced = list(...),
  aggressive = list(...)
)

ledgr_grid_add_baseline(
  grid,
  flat = list(qty = 0)
)
```

These should only create candidate parameter sets. They should not rank,
optimize, tune, choose objectives, select winners, or imply strategy-cookbook
semantics. Keep the distinction sharp: grid-construction ergonomics are useful;
`ledgr_tune()` and ledgr-owned objective semantics remain separate deferred
questions.

### 2026-05-25 [ux] Sweep candidate ranking views

Users will write small helpers to order sweep results before calling
`ledgr_candidate()`. ledgr should not own automatic winner selection or a
full objective DSL, but a transparent ranking view may be useful once sweep
ergonomics are revisited.

Possible future shape:

```r
ranked <- ledgr_rank_candidates(
  results,
  by = "sharpe_ratio",
  direction = "desc",
  na_rm = TRUE
)

candidate <- ledgr_candidate(ranked, 1)
```

Filtering should remain ordinary data-frame work, via base R, dplyr, or user
code before ranking. The helper would own ordering mechanics, classed
validation, printability, and selection provenance. It should not call the
result "best" or promote a candidate automatically.

### 2026-05-13 [ux] Research workflow scaffolds and companion templates

ledgr may eventually benefit from templates, but the first core-owned template
surface should be research workflow scaffolding rather than alpha/strategy
cookbooks. The useful core template is a complete reproducible study scaffold:
snapshot creation, feature registration, strategy file, feature and strategy
parameter grids, sweep script, held-out validation, report skeleton,
assumptions log, and candidate-promotion checklist.

Possible future core helper:

```r
ledgr_new_research_project(
  path = "research/sma-crossover",
  template = "active-alias-sweep"
)
```

Possible first core scaffold:

```text
my-ledgr-study/
  README.md
  data-raw/
  snapshots/
  R/
    strategy.R
    features.R
    params.R
  scripts/
    01_make_snapshot.R
    02_single_run.R
    03_sweep_train.R
    04_validate_test.R
    05_promote_candidate.R
  reports/
    sweep_review.qmd
    validation_report.qmd
  ledgr.yml
```

The point would be to encode the boring correct workflow: sealed data,
registered features, explicit feature and strategy params, train/sweep/evaluate
discipline, review artifacts, and promotion decisions. Tiny example strategies
such as flat baseline or SMA crossover can appear in core only as contract
demonstrations, not as profitable-strategy templates.

A companion repository can own richer strategy templates after the v0.1.8.4
active-alias and grid-helper UX stabilizes. That repository should be framed as
educational templates or recipes, not official strategies. It can contain
copyable examples such as SMA crossover, RSI threshold, breakout,
mean-reversion, and volatility-filter studies, each with its feature map,
feature grid, strategy grid, sweep script, and explanation. Keeping these
outside the core package lets examples be richer without turning ledgr into a
strategy library.

Suggested split:

- core `ledgr`: `ledgr_new_research_project()` or equivalent scaffold command,
  plus one or two minimal built-in workflow templates;
- companion repo: opinionated educational strategy templates and longer
  walkthroughs;
- core docs: link to the companion repo once it exists, but continue to teach
  the canonical workflow through package-owned examples.

This fits the agentic-research thesis because agents can work more safely in a
known structure with explicit files such as `hypothesis.md`, `strategy.R`,
`params.R`, `sweep_results.rds`, `validation_report.qmd`, and
`promotion_decision.md`.

Do not pull this into v0.1.8.4. Active aliases, grid helpers, pulse-debug
inspection, and the single demo strategy should land first; scaffolding should
encode that stabilized workflow rather than shape it.

The accepted research workflow synthesis places canonical workflow
documentation in v0.1.8.5. Treat that as the prerequisite for any scaffold
helper: first teach the workflow, then generate it only if review evidence
shows project setup remains too costly.

When the v0.1.8.5 spec packet is cut, carry these synthesis-review notes into
acceptance criteria:

- the workflow article should be runnable end to end and should produce or
  walk through a review/report shape matching the synthesis outline:
  hypothesis and data window, snapshot hash and source assumptions, feature and
  strategy declarations, candidate-grid summary, top-N candidate table,
  warning/failure review, equity/drawdown plots, promotion note, and rejection
  rationale for alternatives;
- any small helper admitted by the spec must be documentation-supporting
  inspection or summary ergonomics only. It must not add storage layers,
  dispatch paths, identity surfaces, scaffold generation, or execution
  semantics;
- the spec should name the auditr tasks that exercise the canonical workflow
  and route findings against those surfaces;
- the spec should make visible that point-in-time regressor design is a
  prerequisite for broad ML/factor strategy workflows.

### 2026-05-26 [storage] Snapshot lineage and live data logs

Long-running research and production use different data lifecycle contracts.
Research snapshots are immutable replay inputs. New historical data, vendor
corrections, universe changes, and multi-vendor comparisons should create new
sealed snapshots rather than mutating old snapshots in place.

Future research-facing snapshot lineage should likely be lightweight metadata,
not a full versioning subsystem:

- `family`: logical group for related snapshots;
- `family_version`: monotonic or date-stamped version inside the family;
- `extends`: previous snapshot when the new snapshot adds later data;
- `supersedes`: previous snapshot when the new snapshot replaces corrected
  history;
- `lineage_note`: human-readable reason for the reseal.

A helper such as `ledgr_snapshot_family()` could make quarterly reseals,
vendor-correction reseals, universe expansion, and walk-forward snapshot
families inspectable without introducing split stores yet.

Production live data is a separate future surface. A promoted algorithm runs
against append-only ticks or bars that arrive after the backtest snapshot. That
surface needs feed identity, session/calendar policy, gap detection, repair or
backfill policy, correction policy, and linkage back to the promotion evidence.
Live ticks or bars should not be appended to the sealed snapshot that justified
the promotion. If live history becomes research evidence, the future workflow
should seal a historical range from the live log into a new immutable snapshot.

Do not implement this in v0.1.8.4. Keep it as production/paper-trading and
long-horizon storage design input. The important near-term rule is the
boundary: immutable snapshots for replay, append-only logs for live observation.

### 2026-05-26 [data] External point-in-time regressor snapshots

Serious quant research eventually needs point-in-time external data beyond
OHLCV bars: fundamentals, macro releases, analyst estimates, vendor factors,
and alternative data. These inputs have vintage semantics. A replay must use
what was known at the historical decision time, not later-revised values.

DuckDB is the right default backbone for this in ledgr's foreseeable roadmap.
It is local-first, R-friendly, columnar, and supports ASOF-style lookup patterns
that fit point-in-time joins. That should cover daily, moderate intraday,
fundamental, macro, and many research-scale alternative-data workflows. The
breakpoints are large single-file stores, tick-scale data, and multi-writer
team platforms; those remain split-store or external-backend questions.

Future design should likely introduce sealed regressor snapshots with their
own lineage and hashes, then expose PIT-correct lookup/projection into the
existing pulse context:

```text
regressor source data
  -> sealed regressor snapshot with vintage metadata
  -> PIT-correct projection at pulse timestamps
  -> ctx feature/regressor values
```

Do not implement this opportunistically inside active aliases, ML, or adapter
work. It deserves a dedicated "External Data And Point-In-Time Regressors" RFC
covering schema, vintage fields, ASOF lookup semantics, leakage prevention,
lineage, feature-map integration, and storage scale breakpoints.

This should precede broad ML/factor strategy workflows. Those workflows depend
on vintage-correct external inputs, so model artifact provenance alone is not
enough.

### 2026-05-25 [education] Strategy family field guides

Future documentation should include literature-informed field guides for major
EOD trading strategy families. These are broader than reference strategy
templates: the goal is to teach the economic rationale, data requirements,
implementation shape, leakage risks, validation protocol, metrics, and
cost/capacity caveats for each family.

Possible families:

- time-series momentum;
- cross-sectional momentum;
- mean reversion;
- trend following and moving-average systems;
- carry or yield;
- value;
- quality;
- low volatility or defensive equity;
- sector or asset rotation;
- pairs or spread trading;
- event or earnings drift;
- volatility targeting;
- benchmark-aware active equity.

Each field guide should be literature-informed, with recognizable sources for
the economic rationale and known critiques. User-facing articles should stay
readable and practical, but they should not be winged. They should include a
short further-reading section and make clear that ledgr examples are
educational implementations, not trading advice or profitability claims.

Suggested article shape:

```text
1. Economic idea
2. Literature anchor
3. Data requirements
4. Causality/leakage traps
5. Minimal ledgr implementation
6. Variants
7. Metrics that matter
8. Validation protocol
9. Costs, capacity, and failure modes
10. Further reading
```

This depends on several future roadmap layers: target construction helper
extensions, benchmark context and active metrics, walk-forward and selection
integrity diagnostics, liquidity/capacity policy, point-in-time data tables,
corporate actions/instrument master, and reference strategy templates. It is
therefore a v0.2.x+ documentation/education arc, not near-term v0.1.8 work.

### 2026-05-13 [research] Deferred strategy and integration families

The shortened roadmap no longer carries detailed scope for portfolio
optimization support, calendar/event-driven strategies, pairs and spread
trading, reporting adapters, additional indicator backends, ML strategy
artifact management, or expanded asset-class support. Keep these families
parked until the research-to-paper arc is stable enough for focused RFCs.

Do not confuse full portfolio optimization with the existing helper pipeline
(`signal_*()` -> `select_*()` -> `weight_*()` -> `target_*()`). The roadmap now
names `v0.1.9.x Target Construction Helper Extensions` for small additions to
that helper surface. Full solver-style portfolio optimization remains deferred.

ML strategy artifact management depends on stable walk-forward windows,
point-in-time feature tables, model artifact identity, prediction-table
provenance, and selection diagnostics. Do not bolt it on as "call `predict()`
inside a strategy."

The likely long-term abstraction is still pulse-based. An ML strategy should
make decisions at the same no-lookahead pulse boundary as every other ledgr
strategy:

```text
current pulse context -> model prediction or prediction lookup -> target vector
```

Naively calling `predict()` inside every pulse will be expensive, especially
for cross-sectional models, wide universes, and large sweeps. That cost should
be handled with implementation choices rather than by changing the abstraction:
load models once per run/candidate, precompute prediction matrices when the
model and feature set are fixed, cache prediction artifacts by snapshot hash,
feature-set hash, alias-map hash, and model artifact hash, and let strategies
read prediction values from the pulse context when that is the chosen mode.

Future ML design should distinguish:

- live pulse prediction: clearest semantics, highest cost;
- precomputed prediction artifacts: faster for sweeps and replay, still causal
  if generated from point-in-time features and immutable model artifacts.

Do not lock this API now. The insight to preserve is that ML decisions remain
pulse decisions; optimization should move model loading and prediction
materialization out of the hot path when possible.

When ledgr reaches ML strategy workflows, `pins` and `vetiver` are likely the
right boundary tools for model artifacts. `pins` can version and share R
objects or files on local, Posit Connect, S3, and related boards with metadata,
versions, and hashes. `vetiver` builds on that model-artifact layer for trained
models, input prototypes, deployment, model cards, environment checks, and
monitoring.

Future policy should likely be:

- ledgr DuckDB store remains the source of truth for sealed snapshots, runs,
  sweeps, fills, metrics, promotion notes, and references to external model
  artifacts;
- `pins` / `vetiver` own trained model objects, model metadata, input
  prototypes, renv lockfiles, model cards, and monitoring artifacts;
- ledgr provenance records exact model artifact references such as board,
  name, version, pin hash, training snapshot hash, feature-set hash, alias-map
  hash, and strategy hash;
- ledgr must not depend on "latest model" lookup for deterministic replay. A
  backtest or promotion record should identify an immutable model version or
  hash;
- live vetiver endpoints are production-serving surfaces, not replay evidence,
  unless they resolve back to a specific pinned model artifact.

Do not turn this into a near-term dependency decision. The relevant ledgr API
surfaces are not stable yet, and pins/vetiver integration deserves its own RFC
when ML workflows become active scope. For now, workflow/artifact-topology RFCs
may mention pins/vetiver as future-compatible tools, but should not lock a
production API around them.

### 2026-05-16 [research] Randomized and blocked slice diagnostics

Walk-forward should ship before randomized slice protocols. For time series,
"random slices" must not mean arbitrary row-level train/test splits that violate
causality. Future designs should build on the walk-forward window model and
make slice semantics explicit.

Possible future protocols:

- random contiguous train/test windows;
- random anchored train/test windows;
- blocked or bootstrapped windows with no-lookahead constraints;
- combinatorial symmetric cross-validation;
- PBO/CSCV-style selection-bias diagnostics.

These should remain separate from the first `ledgr_walk_forward()` release.
They require stable sweep result shapes, metric context, grid ergonomics,
parallel dispatch, slice-aware feature validation, and a clear explanation that
provenance records what happened but does not prove selection integrity.

The accepted first walk-forward design is
`inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`; future
diagnostic work should consume its fold/session/score artifacts rather than
reopening the v1 wrapper-over-run/sweep architecture.

Promoted roadmap hook: `v0.1.9.x Selection Integrity Diagnostics`.

### 2026-05-13 [infrastructure] Public parallel sweep backend

The v0.1.8 architecture should stay parallel-ready, but a public parallel sweep
feature remains unscheduled. Before promotion, ledgr needs decisions on worker
package setup, `workers > 1` failure modes, worker-local output isolation,
interrupt semantics beyond discard-all, and whether mirai remains the backend
or becomes one backend behind a small internal abstraction.

Evidence and design breadcrumbs:

- `inst/design/spikes/ledgr_parallelism_spike/summary_report.md`
- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`
- `inst/design/rfc/rfc_parallelism_spike_architecture_consequences.md`
- `inst/design/rfc/rfc_parallelism_spike_architecture_consequences_response.md`
- `inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md`

Known spike findings to preserve: mirai is viable on Windows native R and
Ubuntu/WSL as an optional backend; sequential sweep must not depend on mirai;
`workers > 1` without mirai should fail loudly rather than silently fall back;
parallelism belongs at candidate dispatch, not inside one candidate's fold; and
workers should return candidate results to the orchestrator rather than writing
shared DuckDB state.

### 2026-05-13 [infrastructure] Parallel worker setup and Tier 2 packages

SPIKE-8 showed that package-qualified calls can work on workers when the
package is installed, but unqualified calls such as `mutate()` or `SMA()` need
explicit setup such as `everywhere({ library(dplyr); library(TTR) })`. Helper
objects assigned in setup did not persist under mirai's default cleanup, which
is useful because it prevents arbitrary `.GlobalEnv` helper smuggling.

Future parallel sweep design should revisit whether dependency information
comes from an explicit `worker_packages` argument, strategy preflight output, a
companion dependency check, or a combination. A tier label alone is not enough
for parallel Tier 2 execution.

Evidence:

- `inst/design/spikes/ledgr_parallelism_spike/summary_report.md`
- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`
- `inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md`

### 2026-05-13 [infrastructure] mori as transport, not hot lookup

SPIKE-7 showed that `mori::share()` crosses the mirai worker boundary on
Windows and Ubuntu/WSL and can shrink serialized payload handles dramatically.
The same spike showed slower lookup than plain in-process matrices for
fold-like feature access. Treat mori as a future transport/memory-pressure tool,
not the default representation for hot per-pulse feature lookup.

Cases where mori may matter later: walk-forward or CSCV redispatches where
large payloads are re-sent often, very high worker counts where `workers x
payload_size` creates memory pressure, or remote/slow transport environments.

Evidence:

- `inst/design/spikes/ledgr_parallelism_spike/summary_report.md`
- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`
- `inst/design/rfc/rfc_parallelism_spike_architecture_consequences_response.md`

### 2026-05-13 [infrastructure] Worker-local read-only DuckDB transport

SPIKE-4 showed that concurrent worker-local read-only DuckDB access to a sealed
snapshot worked on Windows and Ubuntu/WSL and did not create WAL, temp, lock, or
other side files in the targeted probe. This keeps worker-local snapshot reads
available as a future transport path.

Future design should remember the interface consequence: the fold core must not
take a live DBI connection from the orchestrator. It should accept an abstract
input source that can represent either an in-memory precomputed payload or a
sealed snapshot path plus metadata for worker-local read-only lookup.

Evidence:

- `inst/design/spikes/ledgr_parallelism_spike/summary_report.md`
- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`
- `inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md`

### 2026-05-13 [infrastructure] Parallel interrupt and partial-result semantics

The v0.1.8 architecture currently recommends discard-all interrupt semantics
for the first sweep implementation. Returning partial sweep results later would
need a polling collector, checkpoint semantics, cancellation rules, and clear
atomicity guarantees. Do not add partial-result behavior casually as a UX patch;
it is a parallel output contract.

Evidence:

- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`
- `inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md`

### 2026-05-13 [execution] Intraday architecture feasibility

The parallelism spike used intraday-like synthetic payloads only to stress data
movement. It did not test intraday snapshot schema, pulse calendars, sub-day
fill timing, event volume, warmup/scoring boundaries, or metrics at intraday
scale. Keep intraday as a future architecture feasibility topic, not a planned
v0.1.x feature.

Evidence:

- `inst/design/spikes/ledgr_parallelism_spike/summary_report.md`
- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`

### 2026-05-13 [data] Feature payload scale and indicator-width stress

The parallelism spike deliberately tested feature-width payloads because
indicator sweeps multiply columns per instrument. Plain R serialized payloads
were acceptable for v0.1.8 EOD-scale sweep when preloaded once, but larger
universes, intraday-like pulse counts, walk-forward folds, CSCV/PBO partitions,
and indicator-parameter sweeps can multiply payload size quickly.

Future feature-transport work should preserve three paths: explicit in-memory
precomputed payloads, worker-local read-only snapshot lookup, and future
shared-memory payloads. Do not bake in a pre-fetch-only design.

Evidence:

- `inst/design/spikes/ledgr_parallelism_spike/summary_report.md`
- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`
- `inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md`

### 2026-05-13 [cost] Broker and exchange cost templates

Core ledgr should own stable cost primitives before any broker/exchange-like
templates are considered. Real fee schedules are account-specific,
jurisdiction-specific, and change over time. If templates are added later, they
should likely live in adapter packages or be clearly labelled approximations.

### 2026-05-25 [execution] Liquidity and capacity are not transaction cost

Future liquidity and capacity policy should be named separately from
transaction-cost modeling. Cost models answer "what price and fee did this
proposed fill receive?" Liquidity/capacity policy answers "is this proposed
quantity feasible, should it be clipped, or should it be refused?"

Possible future concepts:

- participation limits;
- ADV/volume filters;
- minimum price and minimum volume constraints;
- turnover and capacity diagnostics;
- liquidity refusal or quantity clipping.

These policies require execution-bar data such as next-bar volume and may
change quantities. They therefore belong in execution/liquidity policy, not in
cost application. Promoted roadmap hook: `v0.2.x Liquidity And Capacity Policy`.

### 2026-05-14 [sweep] Promotion-grade sweep artifacts

Future design: save/load complete sweep result bundles with manifest, snapshot
locator hints, strategy/feature recovery metadata, and verification helpers.
Useful for expensive sweeps and offline audit. Deferred because v0.1.8 stores
selection context on promoted runs instead.

Bounded first shape: persist grid definition, candidate summaries,
warnings/errors, metric context, feature-set hashes, execution seeds, ranking or
selection view, manifest data, and snapshot locator hints. Do not persist full
ledger, fill, trade, or equity artifacts for every candidate by default.

Promoted roadmap hook: `v0.1.9.x Sweep Artifact Persistence`.

### 2026-05-14 [execution] Structured RNG preflight metadata

LDG-2104 added human-readable strategy preflight notes for RNG state mutation
and ambient RNG use. Future sweep audit/provenance work may want structured
fields such as `ambient_rng_symbols` and `rng_mutation_symbols` instead of
parsing notes or reasons.

Source: LDG-2104 code review.

### 2026-05-14 [execution] Broader ambient RNG detection

LDG-2104 classifies `runif()`, `rnorm()`, and `sample()` as ambient RNG Tier 2
calls. Future preflight hardening should consider the broader `stats` RNG
family, such as `rbinom()`, `rpois()`, `rexp()`, and `rgamma()`, so stochastic
strategies are not accidentally classified Tier 1.

Source: LDG-2104 code review.

### 2026-05-15 [execution] Single-core sweep hot-path optimization

LDG-2108A/LDG-2108B showed that memory-backed sweep is faster than looping
`ledgr_run()` calls, but the remaining single-core cost is dominated by
pulse-context/data-frame churn and post-candidate event-derived reconstruction.
On the 50-candidate EOD benchmark, feature matrix construction and hydration
were negligible; `ledgr_execute_fold()` accounted for roughly two thirds of
measured sweep time, while `ledgr_equity_from_events()` and
`ledgr_fills_from_events()` together accounted for roughly one third.

Future optimization work should investigate a faster sweep pulse context path
that avoids rebuilding `features_wide` and helper closures every pulse, and a
summary-only in-memory accounting path that avoids replaying the event stream
multiple times per candidate while preserving ledger parity.

Evidence:

- `inst/design/audits/sweep_performance_measurement.md`
- `inst/design/audits/sweep_hot_path_profile.md`
- `dev/spikes/ledgr_sweep_performance/run_benchmark.R`
- `dev/spikes/ledgr_sweep_performance/profile_hot_path.R`

### 2026-05-25 [strategy] Target construction helper extensions

The public helper pipeline already includes `signal_return()`,
`select_top_n()`, `weight_equal()`, and `target_rebalance()`. Future work should
extend that pipeline conservatively instead of introducing a separate portfolio
construction engine.

Potential additions:

- rank-weight helpers;
- inverse-volatility weighting;
- explicit normalization helpers;
- rebalance bands or no-trade zones where semantics are target-construction
  rather than execution policy;
- small diagnostics that explain how weights became full target quantities.

Keep this separate from target risk, liquidity/capacity, transaction cost, and
full portfolio optimization. Promoted roadmap hook:
`v0.1.9.x Target Construction Helper Extensions`.

### 2026-05-24 [research] Beta as three distinct uses

Beta is semantically important and architecturally complex partly because the
"same" beta means three different things at different layers:

```text
1. beta as post-run diagnostic
   Did the strategy just load on the market?
2. beta as strategy feature
   Did this instrument have high/low rolling beta at the decision time?
3. beta as target-risk constraint
   Should the target portfolio be scaled/hedged to a beta exposure?
```

Each use has a different complexity profile and different upstream
dependencies. Diagnostic beta needs benchmark returns only. Feature beta also
needs point-in-time alignment with the strategy's decision time and would
interact with feature fingerprinting (the determinism module extracted in
LDG-2212). Constraint beta needs both of the above plus the v0.1.9
target-risk chain.

When beta work eventually opens, keep these three uses as separately scoped
sub-questions rather than collapsing them into one design pass. Each use
unblocks on different upstream work:

```text
diagnostic beta : after benchmark/reference-return substrate
                  (`ledgr_metric_context$benchmark` per the accepted
                  v0.1.8.2 synthesis).
feature beta    : after benchmark substrate plus a point-in-time
                  feature/reference alignment design that defines whether
                  rolling beta at pulse t may use returns ending at t or
                  must use returns strictly before t.
constraint beta : after benchmark substrate, feature-alignment design, and
                  the v0.1.9 target-risk chain.
```

Do not gate diagnostic beta on the risk chain; the dependency is
benchmark-only.

### 2026-05-24 [data] External benchmark first, universe-derived later

Future benchmark reference-return support should start with explicit external
series (for example SPY total returns, Fama-French market return, or a CRSP
value-weighted market series) rather than benchmarks derived from the ledgr
trading universe.

Universe-derived benchmarks require point-in-time membership semantics,
introduce survivorship-bias risk depending on snapshot construction, and
depend on market-cap or other reference data that ledgr does not own.
External benchmarks are cleaner and let benchmark work proceed without
resolving universe-membership semantics first.

This aligns with the accepted v0.1.8.2 metric-context synthesis, which
reserves `benchmark` as a NULL field with an "aligned return provider"
contract and prohibits ticker-symbol hidden lookup.

A future `ledgr_benchmark_from_universe()` may still be useful but should be
designed after external benchmarks ship and after point-in-time universe
semantics are explicit.

Promoted roadmap hook: `v0.2.x Benchmark Context And Active Metrics`.

### 2026-05-25 [data] Point-in-time data tables

Future external observations and reference data need point-in-time semantics
before ledgr can honestly support fundamentals, earnings, macro, index
membership, factor features, or universe-derived benchmarks.

Concepts to define:

- `known_at`;
- `available_at`;
- `effective_at`;
- `event_time`;
- `revision_time`;
- provider/source/version metadata;
- alignment policy to strategy decision timestamps.

This is distinct from adapter provenance. Provenance says where data came from;
point-in-time tables say when a strategy was allowed to know it. Promoted
roadmap hook: `v0.2.x Point-In-Time Data Tables`.

### 2026-05-25 [data] Corporate actions and instrument master

Sealed snapshots are reproducible, but reproducible survivorship-biased data
can still be wrong for many research claims. Serious equity research eventually
needs explicit handling for:

- raw versus adjusted price policy;
- splits and dividends;
- delistings and delisting returns;
- symbol changes;
- stable instrument identifiers;
- point-in-time universe membership.

This should coordinate with point-in-time data tables and benchmark/reference
data design. Promoted roadmap hook:
`v0.2.x Corporate Actions And Instrument Master`.

### 2026-05-24 [adapters] External reference-data adapter provenance pattern

Any future external reference-data adapter (tidyfinance, FRED, central-bank
providers, broker APIs) should record provenance fields beyond the
data-identity hash:

```text
source            = "<provider name>"
function          = "<provider function called>"
provider_version  = packageVersion(...)
download_args     = <serialized args>
retrieved_at      = <ISO8601 UTC>
upstream_domain   = <provider-specific>
upstream_dataset  = <provider-specific>
date_range        = <ISO8601 UTC>
symbols           = <if applicable>
```

These fields let a future audit reproduce or at least verify what was
downloaded when. They should not enter the reference object's identity hash
unless they change the data interpretation; they are reproducibility
metadata, not execution identity.

Adapter shape conventions to preserve when adapter work eventually opens:

- `Suggests:` not `Imports:` for the upstream package;
- `rlang::check_installed(...)` at adapter entry;
- empirical verification of upstream unit/format semantics before the
  adapter ships (see `spikes/ledgr_tidyfinance_unit_probe/`);
- no hidden downloads inside metric, strategy, indicator, or fold-core paths.

Per the accepted v0.1.8.2 metric-context synthesis, external adapters are
deferred until the substrate they produce (`ledgr_metric_context` fields
with aligned-provider contracts) is stable.

### 2026-05-24 [data] Provider risk-free source divergence

The `ledgr_tidyfinance_unit_probe` spike found that tidyfinance's standalone
`download_data_risk_free()` endpoint and its Fama-French factor endpoint do
not return interchangeable `risk_free` values for the same calendar period.
For example, tidyfinance 0.5.0 returned January 2010 standalone monthly
`risk_free = 0.000016898`, while the Fama-French 3-factor monthly endpoint
returned `risk_free = 0` for the same month.

This is not necessarily a provider bug. The standalone endpoint is
FRED-derived and converted by tidyfinance; the Fama-French endpoint reflects
the factor dataset's own rounded file. A future factor or reference-data
adapter must preserve this distinction instead of silently treating every
column named `risk_free` as the same source.

Future RFCs that expose multiple risk-free sources should require explicit
source selection and provenance fields for endpoint, dataset, provider
version, and frequency. Metric-context construction must reject ambiguous
"risk-free from provider" requests when more than one provider endpoint could
produce the series.

### 2026-05-25 [infrastructure] DuckDB-backed feature storage and out-of-core projection

The v0.1.8.3 grid-level feature artifacts synthesis intentionally starts with
an R-memory runtime projection because the measured hot path is per-pulse R
object churn, not persistent feature storage. DuckDB is still the natural future
backing for precomputed feature libraries once parameterized indicator grids,
parallel sweep workers, and ML/export workflows need persistence and shared
feature storage.

Future direction:

- `ledgr_precompute_features()` computes feature values through the existing R
  indicator engine (`series_fn()`, TTR adapters, custom indicators) and writes
  concrete feature values to DuckDB-backed feature tables;
- the fold consumes the same projection interface introduced in v0.1.8.3, with
  a DuckDB-backed implementation that loads pulse blocks into memory;
- DBI access happens at block boundaries, not per pulse;
- layer 4 research/export artifacts and out-of-core runtime projection share
  the same DuckDB storage rather than introducing separate schemas;
- parallel workers can read shared DuckDB-backed feature storage instead of
  each materializing the same feature library.

Do not turn this into a DuckDB indicator-computation engine by default. The
authoritative indicator extension surface remains the R `series_fn()` contract
and the planned TTR/custom-indicator path. SQL-native built-in indicators may
be explored later as an opt-in fast path, but only with a separate RFC covering
feature identity, determinism, DuckDB-version sensitivity, mixed R/SQL feature
maps, and parity against the R implementation.

Dependencies before promotion:

- v0.1.8.3 runtime projection interface and R-memory backend have landed;
- v0.1.8.4 active aliases have fixed the alias-map identity and grid-level
  concrete-feature-union contract;
- the post-v0.1.8.3 residual report shows memory scaling, repeated precompute,
  ML/export, or parallel-worker sharing as the next load-bearing bottleneck.

### 2026-05-25 [optimization] Grid-union shared pulse views

The v0.1.8.3 pulse-context data model consolidation synthesis accepts
candidate-specific prebuilt feature views as the safest first pass for
LDG-2413. This preserves exact candidate-facing `ctx$features_wide` and
`ctx$feature_table` schemas, but duplicates view materialization when many
sweep candidates share the same concrete features.

Future optimization work can investigate grid-union pulse views with
per-candidate column selection:

```text
grid-level concrete feature union
  -> shared per-pulse feature view over all concrete feature IDs
  -> candidate-specific column selection / alias naming at fold setup
```

This belongs after v0.1.8.3 measurement, and likely after v0.1.8.4 active
aliases clarify alias-name versus concrete-feature-name schemas. It should not
change the public context contract or introduce per-pulse DBI traffic.

Promotion trigger:

- LDG-2414 or a later residual report shows candidate-specific view
  materialization is a material memory or setup-time cost;
- active aliases have fixed the candidate alias-map semantics;
- state-leak tests can prove candidate column selection does not allow one
  candidate's mutation to corrupt another candidate's view.

### 2026-05-25 [architecture] Primitive internals and collapse acceleration

The LDG-2413 pulse-view construction spike found that the important design
lesson is broader than any single package choice: ledgr should prefer primitive
internal shapes (vectors, matrices, lists, and index maps) and treat
data.frames as public boundary views rather than hot-path state.

Spike artifact:

- `dev/spikes/ledgr_v0_1_8_3_pulse_view_construction/`;
- `inst/design/spikes/ledgr_v0_1_8_3_pulse_view_construction/pulse_view_construction_report.md`.

Reference-shape median timings from the spike:

| construction path | median |
| --- | ---: |
| current feature views, 50 candidates | 8.03s |
| base `split()` feature views, 50 candidates | 1.96s |
| `tidyr` feature views, 50 candidates | 3.64s |
| `data.table` data-frame feature views, 50 candidates | 6.27s |
| `data.table` native feature views, 50 candidates | 5.06s |
| `collapse` feature views, 50 candidates | 0.68s |

All tested alternatives preserved the current `ctx$feature_table` and
`ctx$features_wide` schemas in the equality checks. `collapse::rsplit()` was
the fastest tested implementation, but importing `collapse` only for LDG-2413
would make a broad dependency decision from a narrow optimization surface.

Accepted planning authority:

- `inst/design/rfc/rfc_collapse_primitive_internals_v0_1_9_synthesis.md`.

Near-term policy:

- v0.1.8.3 should use base R split/nest-style construction where it is enough
  to recover the measured pulse-view setup cost;
- do not add `collapse` as an `Imports` dependency during v0.1.8.3 solely for
  pulse-view construction;
- preserve the spike results as evidence for v0.1.9 planning gates.

Promoted v0.1.9 planning direction:

- write a primitive-internals developer guide before broad implementation
  work;
- spike deterministic `collapse` wrapping with scoped `collapse::set_collapse()`
  state restoration rather than mutating caller sessions at package load;
- micro-profile the event-boundary output buffer path and spike safe
  cumulative-reconstruction parity before any production `collapse` dependency
  decision;
- decide whether `collapse` becomes the package's R-side acceleration layer
  only after a non-Phase-A production surface shows measured value under
  hostile caller-side settings;
- keep FIFO redesign, arbitrary strategy callback compilation, and a compiled
  fold core as separate decisions with their own parity gates.

This direction also supports the longer-term DuckDB and compiled-core horizon
items. Primitive matrices/lists map more cleanly to DuckDB columns, block
buffers, and eventual FFI boundaries than repeatedly constructed data.frame
objects.

### 2026-05-25 [api] Future ctx$feature_table deprecation review

The LDG-2413 usage audit found `ctx$feature_table` usage in internal
validation/inspection helpers and test scaffolds, but no documented vignette or
example strategy pattern that depends on the long-form feature table. v0.1.8.3
therefore preserves and prebuilds the field to avoid a context-contract change,
but the field is a plausible future simplification target.

A later RFC can decide whether `ctx$feature_table` should remain a public
strategy-facing field, move behind an inspection helper, or enter a formal
pre-CRAN deprecation path. That decision should be based on strategy-author
usage evidence and must not be folded into LDG-2413.

### 2026-05-25 [infrastructure] Compiled fold core after pipeline stabilization

The v0.1.8.3 sweep baseline shows that R-side fold execution dominates the
reference workload after v0.1.8.2. A future C, Fortran, C++, or Rust fold core
may become worthwhile if R-only optimizations leave walk-forward and large
sweep workloads too slow.

Do not start this rewrite while the fold pipeline is still moving. A compiled
core should wait until the surrounding execution contracts are stable enough
that the port can be contract-following rather than contract-setting.

Minimum gates before a serious port RFC:

- v0.1.8.4 active parameterized feature aliases have landed or been abandoned;
- the v0.1.9 target-risk chain has stabilized, including second-pass target
  validation and risk identity;
- walk-forward has produced real large-sweep workloads that justify native
  fold speed;
- public cost/liquidity/order-policy boundaries are stable enough that the
  compiled core will not immediately need structural rewrites;
- parity tests cover persistent versus memory accounting, typed events,
  metric-kernel behavior, target validation, promotion context, risk policy,
  and cost/liquidity semantics;
- fold-core values are represented by typed, serializable value objects where
  possible rather than loose ad hoc lists.

Near-term work that helps without committing to a port:

- keep expanding parity tests so a future port has a clear acceptance suite;
- formalize event, fill, lot-state, and fill-proposal shapes as typed value
  objects when touched by ordinary tickets;
- optionally run a small FFI feasibility spike in the v0.1.8.7 window, after
  typed memory events, single-pass reconstruction, and fast-context R-side
  optimization have produced an optimized baseline but before the v0.1.9 target
  risk chain starts changing fold contracts. The spike should port only an
  isolated helper such as `ledgr_lot_apply_event()` via `extendr`, measure
  per-call FFI overhead against the LDG-2402 harness, reuse the LDG-2403 parity
  fixtures, and document Windows/Linux build friction. It must not introduce a
  production Rust path.

The port should not be treated as a v0.1.8.x optimization. The v0.1.8.x path
remains R-side optimization first: typed memory events, single-pass summaries,
fast context, and lazy context payloads.

### 2026-05-26 [ui] Shiny research-store exploration UI (opt-in companion package)

ledgr's store is a DuckDB file containing snapshots, sweeps, runs, promotion
context, and metrics. A read-only Shiny UI over that store is the obvious
shape for visual exploration when the API surface alone is not enough.

Likely shape:

- A companion package such as `ledgr.ui` rather than a core dependency. Shiny
  pulls in a meaningful dep tree that core should not require for headless
  research, scripted execution, or auditr probes.
- Local-first: `ledgr_ui()` reads a project's `artifacts/ledgr_store.duckdb`
  with no hosted server, no auth surface, no tracking infrastructure.
- Read-only: the UI never writes to the store. Concurrency and locking stay
  the responsibility of the writing scripts.
- Pure inspection scope. No strategy authoring, no run launch, no promotion
  decision recording from the UI in the first pass; those remain script-driven
  and audit-traceable.

Plausible first-version views:

- project view: list snapshots, sweep results, promoted runs;
- snapshot inspector: bars summary, instruments, time range, hash, sealed_at;
- sweep results browser: candidate ranking by metric, sort/filter;
- candidate detail: feature params, strategy params, alias map, metrics;
- run inspector: equity curve, fills table, events stream, warnings,
  telemetry;
- run comparison: side-by-side equity, key metrics, ranking deltas;
- promotion timeline with decision notes (depends on the future promotion
  notes API);
- cross-snapshot view of the same strategy or feature map across data
  windows.

This is correctly deferred. Reasons not to start now:

- v0.1.x speed and workflow work has higher leverage per engineering hour;
- the API surface is still moving (active aliases, alias-map storage, future
  promotion notes, future walk-forward); a UI built against a moving target
  requires constant rework;
- the most valuable screen (promotion decision timeline with rationale)
  cannot exist before the promotion notes API does;
- the gap versus MLflow's web UI is not a real disadvantage for ledgr's
  current target user, who is comfortable with R REPL inspection.

Realistic timing: not before v0.2.x. A short personal-tool prototype during
v0.1.x is fine and may be useful for the author; a release-quality companion
package belongs after the workflow has stabilized and after promotion notes
have an API home.

### 2026-05-26 [ui] Shiny operations dashboard for production deployments

Much further out than the research-store UI. Once ledgr has live trading or
paper trading via OMS adapters, a separate Shiny operations dashboard becomes
useful for monitoring deployed strategies:

- promotion record browser linking each deployed algorithm to its training and
  validation snapshots, strategy hash, alias map, and approval record;
- live position and equity monitoring against the broker or paper account;
- drift indicators comparing live execution to the promoted backtest;
- alert surface for cost, slippage, or risk breaches;
- retraining trigger view linking each new promotion record to the prior one.

This is a v0.2.x or later product. It depends on:

- production promotion record schema landing in its own RFC;
- OMS/paper-trading adapters existing as a public API;
- a live execution layer with deterministic linkage back to the backtest
  identity surfaces;
- a stable view of what "deployed" and "approved" mean in ledgr terms.

Until those pieces exist, the operations dashboard is a sketch, not a design.
Record it here so the eventual UI work has a target shape rather than being
invented under deployment pressure.

### 2026-05-27 [evaluation] Walk-forward post-v0.1.9.x direction

The accepted v0.1.9.x walk-forward synthesis
(`inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`) binds the
first walk-forward implementation: rolling and anchored folds, calendar-time
boundaries, single sealed snapshot, classed selection rules, scalar score
matrix, and extraction-for-promotion. The synthesis uses "v1" as shorthand for
that first implementation; ledgr's roadmap does not have a "walk-forward v2"
milestone. The post-v0.1.9.x direction lives in named follow-up RFCs at their
own roadmap windows. This entry records the shape of that direction so the
follow-up work has a target rather than being invented under pressure.

Diagnostic retention and selection-integrity diagnostics:

- the v1 scalar score matrix is sufficient for inspection, scalar-metric PBO
  approximation, and a CRAN `pbo`-compatible pivot; it is explicitly
  insufficient for DSR, CPCV, nonlinear-metric recomputation, or per-candidate
  equity reconstruction;
- richer diagnostic retention tiers (per-candidate per-fold return series,
  equity payload references, sufficient statistics, partition/path identity,
  family/effective-trial metadata) belong in a future diagnostic-retention RFC;
- selection-integrity diagnostic implementation (PBO/CSCV/CPCV/DSR/Holm-BH,
  Harvey-Liu-Zhu thresholds, MinTRL) belongs in a separate diagnostics RFC and
  must consume the score matrix and future retention tiers, not redefine them;
- both RFCs land after the first walk-forward release ships and produces
  operational evidence.

Fold-definition extensions:

- purged and embargoed folds activate the v1 schema's reserved `gap` field;
  the embargo RFC must include explicit label-interval overlap test fixtures
  (mlfinlab's public purge-logic bugs are the right regression set);
- combinatorial purged CV adds path identity (`path_id`) to the score schema,
  multiple chronology-respecting train/test partitions, and pathwise return
  artifacts;
- trading-time, market-state, and regime-aware folds require a market-calendar
  abstraction ledgr does not currently have; regime-aware folds also need
  explicit treatment of the regime-classifier-as-look-ahead hazard;
- cross-snapshot walk-forward (one fold = one snapshot) coordinates with
  snapshot-lineage work and changes the snapshot identity story; v1's
  single-snapshot binding is deliberately the simpler shape.

Composition and policy:

- a selection-rule DSL would admit composite multi-metric selection,
  stability-region selection ("plateau wins, not spike"), and top-N robust
  selection; the v1 `ledgr_select_argmax` / `ledgr_select_argmin` interface
  is the smallest useful surface and the DSL is its natural extension once
  user demand for composite selection surfaces;
- walk-forward nested inside `ledgr_sweep()` as candidate inputs is a v1
  non-goal; future composition must address how walk-forward identity
  participates in sweep candidate identity without exploding artifact counts;
- per-fold universe restriction coordinates with PIT data and survivorship-
  aware universe construction; the v1 "experiment universe applies uniformly"
  default is correct until the PIT data RFC binds the universe-at-time-T
  contract;
- promoting a parameter path (a schedule of candidates per future period) or
  promoting a selection rule (commit a process, not a candidate) are
  promotion-semantics extensions beyond the v1 extract-then-`ledgr_promote()`
  baseline; both need their own design rounds.

Paper/live walk-forward and OMS interaction:

- v1 research walk-forward writes no OMS lifecycle artifacts; paper/live
  walk-forward must revisit OMS streams and target-decision persistence per
  the accepted OMS synthesis;
- each fold's test run as its own `order_events` stream is the natural shape
  but creates artifact multiplication that the paper/live walk-forward RFC
  must address;
- fold definitions translate to a retraining schedule in paper/live (LEAN's
  `train()` pattern); the schedule artifact is a future-RFC concern, not a
  v1 walk-forward shape.

Promoted roadmap hooks (named follow-up RFCs):

- diagnostic retention tiers RFC (v0.1.9.x or later);
- selection-integrity diagnostics RFC (v0.1.9.x, after retention tiers
  stabilize enough to consume);
- purged and embargoed folds RFC (v0.1.9.x or v0.2.x);
- combinatorial purged CV RFC (after purging);
- trading-time / state-fold RFC (v0.2.x, coordinated with market-calendar
  work);
- cross-snapshot walk-forward RFC (v0.2.x, coordinated with snapshot lineage);
- selection-rule DSL RFC (when user demand for composite selection surfaces);
- survivorship-aware universe RFC (v0.2.x, coordinated with PIT data and
  instrument master work);
- paper/live walk-forward RFC (v0.3.0+, coordinated with OMS implementation);
- OMS interaction RFC for walk-forward (between OMS data-model implementation
  and paper/live walk-forward).

This horizon entry does not authorize any of the above. It records the
direction so that when each follow-up cycle opens, the seed author can start
from a known shape rather than re-deriving the boundary.

### 2026-05-27 [execution] Cost-model post-v0.1.9.x direction

The accepted v0.1.9.x/v0.2.0 public transaction-cost API synthesis
(`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`)
binds the first public cost API: classed `ledgr_cost_*` objects, ordered
`ledgr_cost_chain()` composition with two-stage discipline (price transforms
then fee adders), four v1 primitives (`spread_bps`, `fixed_fee`,
`notional_bps_fee`, `zero`), `timing_model` argument replacing `fill_model`,
quoted-spread semantics for `spread_bps`, single account currency, one total
fee per fill, cost identity via `cost_model_hash` + `cost_plan_json`, and
experiment-level (non-per-candidate) cost in v1. The synthesis explicitly
defers ~18 cost-adjacent capabilities and records 10 future-RFC obligations.
This entry groups the post-v0.1.9.x direction so each follow-up cycle starts
from a known shape.

Cost-model expressiveness extensions:

- asymmetric price-adjustment constructor (`ledgr_cost_price_adjust_bps(bps,
  side = ...)`) is reserved as a future constructor for users who need per-leg
  markup/markdown semantics distinct from quoted-spread; both can coexist
  under clearly different names;
- side-filtered fee steps (apply only to BUY, only to SELL, or only to
  specific instrument groups);
- min/max fee caps (per-step semantics; the chain-level interaction was the
  reason v1 deferred them);
- per-share and per-contract fee primitives (currently aliasable from
  `notional_bps_fee` via user calculation but lack the asset-class vocabulary
  users expect).

Stateful fee modeling:

- rolling-volume fee tiers (IBKR-style monthly-share-volume tiers, Binance-
  style rolling-30-day tiers, CME participant-status tiers) — require a
  cost-state envelope that v1's stateless per-fill contract deliberately
  excludes;
- maker/taker fee inference from order aggressiveness — requires either an
  explicit user convention (which v1 cost API rejects) or a liquidity layer
  that can classify fills as passive vs aggressive;
- rebates (negative fees) — admitted only via explicit rebate or maker/taker
  classes, not as arbitrary negative outputs from any fee step.

Multi-asset and multi-venue cost assignment:

- per-instrument cost-model assignment (LEAN-style per-security models);
- per-asset-class cost templates (equity / futures / crypto / FX / options
  defaults with fallback rules);
- per-venue cost objects (NautilusTrader-style venue-level fee models for
  multi-venue portfolios);
- assignment-rule ordering (fallback from per-instrument → per-asset-class →
  experiment-default).

Cost sweep and parameterization:

- `ledgr_cost_grid()` or `ledgr_grid_cross(..., cost = ...)` for sweeping cost
  assumptions across candidates;
- `ledgr_cost_param("spread_bps")` parameter references inside cost objects
  for cost-varying sweep candidates;
- both require explicit namespace and identity rules to keep cost-varying
  candidates distinguishable from strategy-param-varying candidates in
  provenance, reporting, and promotion context.

Cost-adjacent families that are not cost:

- borrow cost, margin interest, carry, and perpetual funding — stateful
  position or calendar cashflows; belong in a separate financing/margin RFC
  family, not in the cost API;
- multi-currency fee accounting and conversion — once fees can be denominated
  in something other than the account currency, conversion, missing FX data,
  and multi-currency ledger semantics enter scope; a separate RFC;
- tax-lot and capital-gains policy — stateful accounting-policy problem, not
  a fill-time cost transform; transaction taxes (stamp duty, FTT) can be
  modeled as fee adders in v1, but realized-tax accounting waits;
- broker-certified fee schedules in core — adapter packages own these;
  core ships primitives and educational approximations only.

Cost in OMS and paper/live:

- broker-reported fee ingestion for paper/live reconciliation — requires the
  OMS event-stream layer to exist first;
- live cost calibration against actual broker-reported fees — v0.3.0+ work;
- broker-fee schedules versioned per account/date — coordinates with
  snapshot lineage and live-data-log work.

TCA and reporting:

- implementation-shortfall computation;
- delay cost and opportunity cost;
- benchmark-relative shortfall (VWAP/TWAP comparison);
- venue analysis and pre/intra/post-trade workflow reporting;
- all belong to a future TCA/reporting layer that consumes cost-resolved fill
  rows plus future order-lifecycle artifacts; the cost API need not become a
  full benchmark engine.

Cost component diagnostic retention:

- v1 sums chain-fee components into one total `fee` per fill in
  `ledger_events`; component breakdowns may live in `meta_json` when retained;
- a future diagnostic retention tier may add a `cost_details` table with
  per-step attribution rows for inspection and TCA-style analysis;
- the same pattern as the walk-forward "diagnostic retention tier" deferral.

Promoted roadmap hooks (named follow-up RFCs):

- asymmetric price-adjustment constructor RFC (when concrete demand
  surfaces);
- stateful fee tiers RFC (after operational experience with v1);
- maker/taker and rebates RFC (coordinated with liquidity layer);
- per-instrument / per-asset / per-venue assignment RFC (v0.2.x, when
  multi-asset portfolios become common);
- cost sweep / parameterization RFC (after sweep + walk-forward
  artifact-multiplication patterns stabilize);
- financing and margin-interest RFC (v0.2.x, separate from cost);
- multi-currency fee accounting RFC (coordinated with multi-currency ledger
  work);
- TCA / reporting layer RFC (v0.2.x or later, consumes cost + future OMS
  data);
- broker-reported fee reconciliation RFC (v0.3.0+, with OMS implementation);
- cost component diagnostic retention RFC (coordinated with walk-forward
  diagnostic tiers).

Immediate cross-cycle obligations recorded by the synthesis (not horizon
material, just noted for follow-on cycles):

- v0.1.9.x walk-forward spec packet must extend `candidate_key` and
  `session_id` to include `cost_model_hash`;
- v0.1.9.x cost-API spec packet must update
  `vignettes/metrics-and-accounting.Rmd` which currently teaches the legacy
  full-per-leg spread convention.

This horizon entry does not authorize any of the above. It records the
direction so that when each follow-up cycle opens, the seed author starts
from a known shape rather than re-deriving the boundary.

## Resolved

No resolved horizon entries yet.
