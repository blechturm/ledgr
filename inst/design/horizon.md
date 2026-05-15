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

## Resolved

No resolved horizon entries yet.
