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

### 2026-05-13 [ux] Research workflow templates

ledgr may eventually benefit from templates, but the first templates should be
research workflow templates rather than alpha/strategy cookbooks. The useful
template is a complete reproducible study scaffold: snapshot creation, feature
registration, strategy file, parameter grid, sweep script, held-out validation,
report skeleton, assumptions log, and candidate-promotion checklist.

Possible first scaffold:

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
registered features, explicit params, train/sweep/evaluate discipline, review
artifacts, and promotion decisions. Tiny example strategies such as flat
baseline, SMA crossover, or top-N momentum can appear only as contract
demonstrations, not as profitable-strategy templates.

This fits the agentic-research thesis because agents can work more safely in a
known structure with explicit files such as `hypothesis.md`, `strategy.R`,
`params.R`, `sweep_results.rds`, `validation_report.qmd`, and
`promotion_decision.md`.

### 2026-05-13 [research] Deferred strategy and integration families

The shortened roadmap no longer carries detailed scope for portfolio
optimization support, calendar/event-driven strategies, pairs and spread
trading, reporting adapters, additional indicator backends, ML strategy
artifact management, or expanded asset-class support. Keep these families
parked until the research-to-paper arc is stable enough for focused RFCs.

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

### 2026-05-14 [sweep] Promotion-grade sweep artifacts

Future design: save/load complete sweep result bundles with manifest, snapshot
locator hints, strategy/feature recovery metadata, and verification helpers.
Useful for expensive sweeps and offline audit. Deferred because v0.1.8 stores
selection context on promoted runs instead.

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

## Resolved

No resolved horizon entries yet.
