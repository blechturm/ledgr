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

**Promotion index (horizon → roadmap).** Where open entries have a planned
milestone. Entries not listed are pure direction with no committed home yet
(e.g. Shiny UIs, compiled fold core, strategy family guides, tidy/vectorized
authoring). When a milestone closes, sweep its entries to `## Resolved`.

- **v0.1.8.6** — DuckDB feature-storage spike; feature payload scale stress;
  feature projection materialization (5.0/5.1); structured benchmark and
  attribution closeout.
- **v0.1.8.7** (optimization round 2) — fold-core primitive contract; hot-path
  lanes (B0 buffer/emission via collapse, R representation/formatting with a
  durable-identity fence, C reconstruction read-back); ADR 0004 dependency moves
  (drop cli/R6, add collapse, keep tibble); legacy cleanup (raw `bars`
  execution, R6 strategy execution, and run-time `data_hash` identity removed
  from modern execution); per-lane real-run re-profile + parity gates.
- **v0.1.8.8** (parallel dispatch + determinism) — public parallel sweep
  backend; parallel worker setup / Tier-2 packages; mori transport;
  worker-local read-only DuckDB; parallel interrupt / partial-result
  semantics; **RNG resume non-determinism**; structured RNG preflight metadata;
  broader ambient RNG detection.
- **v0.1.8.x (pre-OMS/risk)** — fold-core structural debt (one replay kernel,
  typed execution spec, file split, explicit event types); peer-benchmark
  expansion (same-host zipline-reloaded, LEAN, NautilusTrader; VectorBT as a
  contextual paradigm row).
- **v0.1.9** — affordability / target-risk (incl. the phased-pulse
  restructure); primitive internals and collapse.
- **v0.1.9.x** — walk-forward post-direction; cost-model post-direction;
  randomized/blocked slice diagnostics; promotion-grade sweep artifacts;
  target-construction helper extensions; broker/exchange cost templates.
- **v0.2.x** — snapshot administration and research-loop ergonomics (sweep
  review + promotion recovery); point-in-time data tables / external regressor
  snapshots (unify in one RFC); corporate actions and instrument master;
  explicit accounting-critical event types RFC; liquidity and capacity; OMS
  semantics + snapshot lineage + live data logs; external benchmark / beta
  uses; external reference-data adapter provenance; provider risk-free
  divergence; reference strategy templates / baseline strategies.
- **v0.2.x → v0.3.0** — live bad-data resilience, ragged-universe
  (asset-lifetime) handling, and sim-to-real backtest fidelity (direction B;
  needs a dedicated RFC).

### 2026-05-29 [execution] v0.1.8.7 optimization-round post-synthesis direction

The accepted v0.1.8.7 synthesis
(`inst/design/rfc/rfc_optimization_round_v0_1_8_7_synthesis.md`) binds a
single-core pure-R hot-path cleanup: surface-preserving event-buffer
capacity/write fix (B0), hot-path representation/formatting cleanup with
durable-identity bytes fenced off (R), and read-back reconstruction behind a
deterministic collapse gate (C), plus ADR 0004 deps and explicit legacy
cleanup. The modern execution contract is snapshot-backed and function-strategy
based; raw `bars` execution, R6 strategy execution, and run-time `data_hash`
identity are removed or fail before the fold. It does **not** authorize a
compiled core, parallel dispatch (now v0.1.8.8), sweep crossover claims, or
durable identity-format changes. Whole-second timestamp contract reaffirmed;
sub-second out of scope (not HFT). Pure direction, no committed home: a
compiled/native fold core is the later lever for decisive single-run peer wins;
the sweep amortization / peer-crossover track stays open (measured modest ~1.18×,
the per-candidate fold dominates — needs heavier-precompute workloads before any
claim); the matrix-canonical strategy surface is a separate contract/ergonomics
RFC; the deeper typed event-emission rewrite (B1) waits on an explicit
primitive-contract binding; durable hash/provenance/fingerprint byte changes each
need their own contract decision.

### 2026-05-30 [optimization] Post-v0.1.8.7 remaining fold-loop levers

The v0.1.8.7 benchmark closeout leaves the main hot bucket as the pure-R
turnover fold loop: on the current local TTR-backed peer shape, the durable run
spends 15.70s of 25.91s in the loop while producing 13,355 fills. B0 removed the
pathological event-buffer cost, R/A removed the obvious timestamp/setup tax, and
C improved fills materialization/read-back. What remains is not one known bug; it
is the accumulation of interpreted per-pulse/per-instrument/per-fill mechanics.

Collapse can still help, but only in specific measured sub-operations. Candidate
uses to preserve for later profiling:

- use `collapse::setv()` for the remaining event-buffer column writes if POSIXct
  class/tzone and event-stream parity remain byte-identical;
- replace hot target/order selection idioms (`match`, `%in%`, repeated `which`,
  logical-vector allocation) with `collapse::fmatch()`, `collapse::whichv()`,
  and related vectorized operators where profiling shows lookup/selection cost;
- precompute integer instrument maps with `fmatch()`-style semantics rather than
  rematching character IDs inside turnover paths;
- batch state-delta or fill aggregation with grouped `fsum()`-style operations
  only if a future order/fill shape produces multiple same-pulse rows per
  instrument and parity is proven;
- keep `rowbind()`, `fcumsum()`, and summary-stat helpers as reconstruction and
  metric materialization levers, not as a claim on live fold-loop speed.

Weak collapse candidates: arbitrary strategy callbacks, branch-heavy fill-rule
logic, and direct matrix bar/feature reads. Those are either user code, already
cheap base-C indexing, or better addressed by the primitive-contract / compiled
core path. Lane R-style timestamp and string-formatting cleanup is also mostly
base-R representation discipline, not a collapse problem.

The practical next diagnostic, if this becomes active work, is an intra-loop
profile that splits context access, target/order conversion, fill resolution,
state update, and event emission after B0/R/A/C. Do not start another broad
collapse pass from package capability alone; require a named hot frame, a
deterministic-wrapper boundary for value-bearing operations, and parity fixtures
that cover durable and sweep event streams.

This entry records direction, not committed work.

### 2026-05-29 [research] Snapshot administration and research-loop helpers deferred

The v0.1.8.6 `LDG-2451` gate for snapshot administration, ETL provenance,
sweep-review helpers, and promotion-recovery-summary helpers was deferred by
maintainer decision during release closeout. The work remains useful, but it is
not required for the v0.1.8.6 materialization, benchmark, and attribution cycle,
and it should not distract from the v0.1.8.7 Optimization Round 2 hot-path
lanes.

When revived, likely in a v0.2.0-class RFC/spec cycle, keep the original shape:
separate engine-computed metadata, user-supplied descriptive metadata, and
administrative lifecycle state; preserve `snapshot_hash` independence from
mutable user metadata; keep sweep-review helpers explicit about ranking rules;
and keep promotion-recovery summaries factual rather than automated candidate
selection or validation.

This entry records direction, not committed work.

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

**Overlaps the 2026-05-25 "Point-in-time data tables" entry** — same v0.2.x
PIT external-data substrate from two angles (this one is the regressor/feature
use case; the other is the table/storage model). The eventual "External Data
And Point-In-Time Regressors" RFC should unify both, and also covers the
late/revised-tick axis of the 2026-05-28 live bad-data resilience entry.

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

### 2026-05-27 [risk] Affordability belongs in target risk

The research fold treats strategy output as desired target quantities and
applies deterministic next-open fills. Until the target-risk chain exists, raw
targets can request more exposure than available cash supports; the fold records
the fill and cash can go negative. That arithmetic is reproducible, but it is
not a declared margin model.

The v0.1.9 target-risk RFC should treat capital discipline as a first-class
risk adapter, alongside long-only and max-weight constraints. The minimum shape
should include an explicit capital floor or affordability rule inserted between
target validation and fill timing, preserving the strategy contract: strategies
declare desired holdings; risk transforms, rejects, or annotates targets before
execution.

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

### 2026-05-28 [optimization] Feature projection shape post-v0.1.8.x direction

The accepted synthesis
`rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md` binds the
next feature-projection materialization direction: v0.1.8.6 first removes
redundant cache-key fingerprint work, then stops building full-panel long
`ctx$feature_table` rows by default. Wide/projection-backed accessors are the
decision-time surface; long becomes inspection/export/research shape. This entry
uses no feature "v1" shorthand; work is assigned to v0.1.8.6, v0.1.9, or later.

#### Lookback and portfolio windows

- `ctx$window()` is accepted as the causal lookback primitive, but enters
  v0.1.9 only if target-risk or portfolio-risk work needs covariance windows.
- First public shape, when cut, is single-feature `n_inst x lookback` matrix
  with leading `NA_real_` warmup columns.
- Multi-feature/tensor/list window shapes are future API work after the first
  matrix contract exists.

#### Long research/export layer

- Runtime long `ctx$feature_table` is not the training-frame surface.
- Full-panel long feature export, ML training frames, and tidy EDA helpers need
  a separate research/export API cycle.
- PIT regressor and feature-store interchange belong with the later PIT/data
  provider track.

#### Persistent event schema and replay

- LDG-2410 typed memory events are complete and memory-scoped.
- Typed persistent columns for `cash_delta` and `position_delta` are the
  persistent counterpart and are preferred over a DuckDB-SQL-only replay patch
  if storage/schema work is accepted.
- Broader typed event metadata remains future event-schema work.

#### DuckDB-backed projection and storage

- v0.1.8.6 DuckDB/storage work should consume the simplified projection
  contract after schema-only `feature_table` is in place.
- DuckDB must remain a block/storage boundary, not a per-pulse runtime query
  engine.
- No future storage path should reintroduce full-panel long materialization by
  default.

#### Collapse and primitive internals

- Primitive-internals discipline applies broadly.
- No collapse Imports dependency is authorized by the feature-projection
  materialization directions.
- Collapse remains governed by
  `rfc_collapse_primitive_internals_v0_1_9_synthesis.md`: measured hot frames,
  deterministic wrapper, and parity gates only.

#### Promoted roadmap hooks

- v0.1.8.6: feature cache-key dedup for feature-definition fingerprint and
  feature-engine version.
- v0.1.8.6: schema-only `ctx$feature_table` default plus non-fast-path rebuild
  fix.
- v0.1.8.6: post-5.0/post-5.1 remeasurement and instrument x feature sweep.
- v0.1.8.6, if storage/schema work is explicitly accepted: typed persistent
  `cash_delta` and `position_delta` columns.
- v0.1.9, only if target-risk/portfolio-risk needs it: single-feature
  `ctx$window()` matrix API.
- Later: multi-feature/tensor windows.
- Later: full-panel long export/training APIs and PIT feature-store
  interchange.
- Later: broader typed event metadata beyond replay deltas.

#### Immediate cross-cycle obligations

- The v0.1.8.6 spec packet must cut 5.0 before 5.1 and remeasure after each.
- The v0.1.8.6 spec packet must not publish width-invariance or benchmark
  claims until an instrument x feature sweep runs in read/score and turnover
  modes.
- The v0.1.8.6 spec packet must decide whether storage/schema work is in scope
  before cutting any 5.6 typed persistent column ticket.
- If 5.6 is deferred, the packet should record it as designed future storage
  work, not as an incomplete SQL-only patch.

This entry does not authorize any of the above by itself; it records the
post-synthesis direction and deferrals. Concrete work remains governed by the
accepted synthesis and the relevant spec packets.

### 2026-05-28 [optimization] Persistent DB-replay reconstruction via DuckDB SQL

`ledgr_reconstruct_positions()`, `ledgr_reconstruct_cash()`, and
`ledgr_rebuild_derived_state()` (`R/derived-state.R`) replay the persisted
`ledger_events` table with `jsonlite::fromJSON(meta_json)` **per row** in an R
loop, plus named-vector grow-by-assignment. This is the reopen / resume /
rebuild-from-store path - NOT the main backtest reconstruction, which is already
vectorized via `findInterval` + `cumsum` in `ledgr_run_fold`. It is O(events)
with a JSON parse per event and bites when reloading large persisted runs.

This is a SEPARATE surface from LDG-2410 ("Typed Memory Event Representation",
shipped v0.1.8.3, `scope: sweep_memory_path`): LDG-2410 typed the *in-memory*
sweep events and never touched the persistent DB-replay path.

Fix without a schema change: push the delta aggregation into DuckDB SQL, e.g.
`SELECT instrument_id, SUM(CAST(json_extract(meta_json,'$.position_delta') AS
DOUBLE)) ... GROUP BY instrument_id` (cash is the ungrouped sum). DuckDB does the
JSON extract + grouped sum in C, eliminating the R loop and the per-row parse.
The typed-DB-columns alternative also works but requires a `ledger_events` schema
migration.

Secondary (reopen/resume) cost today, but O(events) with a per-row JSON parse;
the obvious next target once persisted-run reload or walk-forward replay becomes
load-bearing. Surfaced by the v0.1.8.5 feature-payload spike's collapse-alignment
review.

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
- defer any FFI feasibility spike until after the v0.1.8.7 single-core pure-R
  cleanup and the v0.1.8.8 parallel-dispatch window have produced an optimized
  baseline. When revived, the spike should port only an
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

### 2026-05-27 [evaluation] Baseline strategies and opinionated comparison

The roadmap (`inst/design/ledgr_roadmap.md`) lists "Reference strategy
templates as executable contract demonstrations" at v0.2.x. This horizon entry
refines that line into a concrete design direction so the eventual RFC author
starts from a known shape.

Two things already exist in v0.1.8.4: `ledgr_demo_sma_crossover_strategy()` as
a single teaching fixture, and `ledgr_compare_runs(snapshot, run_ids = ...)`
as a multi-run comparison surface that returns side-by-side metrics. What is
missing is the opinionated layer that connects them: a small library of
baseline strategies the user can run against the same sealed snapshot, plus a
comparison wrapper that produces a structured "does this beat the baseline"
report instead of two unannotated equity curves.

Three categories that must stay distinct in the design

The v0.2.x RFC must keep these three surfaces separately named. Conflating
them is the most likely failure mode:

- **Baseline strategy.** Runs *inside the engine on the same snapshot* as the
  user's strategy. Same data path, same fill semantics, same accounting.
  Produces an in-sample comparison. This horizon entry is about this
  category.
- **Benchmark return series.** An *external* time series (e.g., SPY total
  return, 60/40 model portfolio NAV) compared post-hoc to the strategy's
  equity curve. Different data path. This is what `PerformanceAnalytics`
  users expect and is a separate future RFC.
- **Reference / teaching strategy.** Same mechanical shape as a baseline,
  but the intent is education, not measurement.
  `ledgr_demo_sma_crossover_strategy()` is one of these. Useful for
  vignettes; not a measurement surface.

Sketch of the v2.x API (not bound)

```r
# Baseline constructors -- same engine, same snapshot, in-sample
ledgr_baseline_flat()                          # always flat (zero positions)
ledgr_baseline_buy_and_hold()                  # equal-weight long at t=0, hold
ledgr_baseline_equal_weight_monthly()          # rebalance to equal weights monthly
ledgr_baseline_random_walk(seed)               # random target per pulse -- sanity check

# Comparison wrapper -- opinionated about which stats matter
ledgr_compare_against_baseline(
  bt,                                          # your committed run
  baseline = ledgr_baseline_buy_and_hold()     # the baseline strategy to run
)
```

The wrapper runs the baseline on the same snapshot with the same opening
state and reports a fixed structured comparison.

The opinionated metric set

The wrapper reports a small fixed set of statistics, chosen because they
answer "does this add value over the baseline" rather than "what are this
strategy's performance attributes":

- difference in total return;
- Sharpe difference;
- max drawdown difference;
- tracking error (stdev of return difference);
- information ratio (return difference / tracking error);
- percent of pulses where the strategy outperformed.

The bounded metric set is itself a design decision. ledgr should refuse to be
a generic stats library here; the comparison surface should teach the
specific question "does my strategy add value relative to a known baseline,"
not enumerate every possible benchmark-adjusted metric.

Scope risks

- **Template library creep.** Ship "buy and hold," users will ask for
  "rebalanced 60/40," "equal-weight momentum," "minimum-variance," etc. Cap
  the core library at ~4-6 templates that genuinely teach the comparison
  discipline. Anything fancier belongs in a companion package or user code.
- **Baseline vs benchmark conflation.** Users will read "baseline" as
  "benchmark" and expect SPY-relative attribution. The API name and the
  documentation must make the distinction obvious — `ledgr_baseline_*`
  constructors run a real strategy inside the engine; a future
  `ledgr_benchmark_*` family (if added) would consume external return
  series.
- **Opinionated metrics still bind a research-method choice.** Picking five
  comparison stats teaches the user to optimize against those five stats.
  The metric selection should be informed by the same Bailey / Lopez de
  Prado / Harvey-Liu-Zhu literature that informed the walk-forward and
  selection-integrity work.
- **In-sample comparison is still in-sample.** If the user's strategy was
  selected from a sweep on the same snapshot the baseline runs against,
  "beats baseline by 3 bps" is in-sample evidence. The walk-forward
  synthesis already warns that single-snapshot evidence is exploratory; the
  baseline comparison surface inherits that caveat and must say so in
  user-facing docs.

Dependencies on prior cycles

This RFC lands well after the prerequisite work:

- walk-forward (v0.1.9.x) so comparisons can be made over OOS fold windows,
  not just full snapshots;
- target risk (v0.1.9) so baselines can be risk-adjusted comparable to
  risk-aware strategies;
- public cost API (v0.1.9.x/v0.2.0) so cost-aware comparisons are honest
  (baselines have different turnover; comparing without cost can mislead);
- selection-integrity diagnostics (v0.1.9.x) so the comparison can be paired
  with multiplicity-aware significance reporting if the user wants it.

The v0.2.x slot is the right window — after the prerequisites stabilize and
before paper/live shifts the question from "does this beat the baseline" to
"is this still working in production."

Promoted roadmap hooks

- baseline strategy library RFC (v0.2.x, after walk-forward and cost API
  stabilize);
- baseline-comparison API RFC (v0.2.x, coordinated with baseline library);
- benchmark-return-series adapter RFC (later, if external-time-series
  comparison surfaces user demand — distinct from baseline strategies);
- companion-package reference strategy library (out of core, when the
  in-core library hits maintenance-burden limit);
- statistical-significance layer for baseline comparisons (coordinated with
  selection-integrity diagnostics RFC).

Cross-cycle note

The v0.1.8.5 canonical workflow article (Batch 1, just shipped) intentionally
does not teach baseline comparison. A reader of that article is likely to
ask "but how do I know if my strategy is any good?" — and the honest answer
today is "you run a baseline yourself and compare manually." The v0.2.x
baseline-comparison API is what that answer should point to once it lands.

Until then, the strategy-development vignette's existing note that the demo
SMA crossover and the `single_instrument_strategy()` helper can be used as
ad-hoc comparison baselines is the user-facing guidance.

This horizon entry does not authorize any of the above. It records the
direction so that when each follow-up cycle opens, the seed author starts
from a known shape rather than re-deriving the boundary.

### 2026-05-27 [infrastructure] Snapshot administration surface and ETL provenance metadata

ledgr today stores a small set of snapshot fields plus a free-form
`meta_json` envelope on the `snapshots` DuckDB table
(`R/db-schema-create.R:233-242`). The engine writes `n_bars`,
`n_instruments`, `start_date`, and `end_date` into `meta_json` at seal time
(`R/snapshots-seal.R:199-253`), but the user-facing constructor
`ledgr_snapshot_from_df()` does not even expose the `meta = list(...)`
argument that `ledgr_snapshot_create()` accepts. There is no documented
place for ETL provenance, no notes field, no labels or tags, and no
listing or filtering surface beyond `ledgr_snapshot_info()` on a known ID.

This gap surfaced in v0.1.8.5: the canonical research-workflow article
teaches users to seal data into a project store but cannot teach the
companion discipline of recording *how* the data was prepared. A user can
reopen the exact sealed bytes, but cannot reopen the human reasoning that
produced them.

Three categories that must stay distinct in the design

The eventual RFC must keep these three surfaces separately named so the
schema and API do not collapse into a single freeform blob:

- **Engine-computed metadata.** Derived deterministically at seal time
  from the sealed contents: `n_bars`, `n_instruments`, `start_date`,
  `end_date`, `snapshot_hash`, instrument list, calendar. Reproducible
  from the snapshot and not user-editable.
- **User-supplied descriptive metadata.** Free-text notes, ETL provenance
  (source URL or vendor, retrieval timestamp, ETL script path and
  version, transformations applied), tags or labels, author. Human-
  authored documentation that ledgr stores faithfully but does not
  interpret.
- **Lifecycle and administrative state.** Existing `status`
  (`CREATED`/`SEALED`/`FAILED`) plus potential additions like
  `deprecated_at`, `superseded_by`, `archived_at`. State transitions
  managed through dedicated API rather than freeform edits.

Conflating any two is the most likely failure mode. ETL provenance is
not lifecycle state; engine-computed fields are not user metadata.

Sketch of the API (not bound)

```r
# Constructor surface -- both expose the same metadata fields
ledgr_snapshot_from_df(
  bars,
  db_path     = ...,
  snapshot_id = ...,
  notes       = NULL,    # free-text human notes
  source      = NULL,    # list: vendor, url, retrieved_at, etl_script, etl_version
  tags        = NULL,    # character vector of labels
  author      = NULL     # character scalar
)

ledgr_snapshot_create(con, snapshot_id, notes = NULL, source = NULL, ...)

# Inspection and listing
ledgr_snapshot_info(con, snapshot_id)          # returns all three categories
ledgr_snapshot_list(                           # navigates the store
  con,
  tags          = NULL,                        # filter by label
  author        = NULL,                        # filter by author
  status        = NULL,                        # filter by lifecycle state
  created_after = NULL
)

# Lifecycle administration
ledgr_snapshot_deprecate(con, snapshot_id, reason)
ledgr_snapshot_supersede(con, snapshot_id, by = new_snapshot_id, reason)

# Note administration (audit-logged, not silent overwrite)
ledgr_snapshot_note(con, snapshot_id, append = "...")
```

Schema direction

The cleanest shape is a dedicated set of `snapshot_meta` columns on the
`snapshots` table (or a sibling `snapshot_provenance` table for the
structured ETL fields), with engine-computed values remaining in
`meta_json` until the spike confirms which fields are stable enough to
promote to typed columns. A `snapshot_audit` append-only table can record
administrative edits to notes, tags, or lifecycle state.

Scope risks

- **Metadata creep.** Once the API exposes notes, users will ask for
  arbitrary key/value extension. Cap structured fields at a small
  defensible set and route everything else into one explicit
  `extra = list(...)` slot stored as JSON, not into ad-hoc top-level
  columns.
- **Lifecycle confusion.** "Deprecated" and "superseded" sound similar
  but mean different things; the RFC must define semantics precisely
  before exposing them. Avoid soft-delete unless audit and recovery
  semantics are clear.
- **Mutable metadata vs immutable provenance.** Notes are mutable by
  design (users learn things later). The `snapshot_hash` must not depend
  on mutable metadata, or the audit trail breaks. ETL provenance
  recorded at create-time should be append-only after seal, with later
  edits routed through a dedicated audit-logged path.
- **Listing API as a sweep substitute.** `ledgr_snapshot_list()` is a
  research-management tool, not a query engine. Resist filters that pull
  bar data ("snapshots containing instrument X") into the list surface;
  those belong in `ledgr_snapshot_info()` or a separate query API.
- **Migration burden.** A schema change to the `snapshots` table is a
  breaking change to existing project stores. The pre-CRAN window
  authorizes it, but the cycle must ship a migration script or an
  explicit "rerun your experiments" gate.
- **Intraday-readiness regression.** Schema additions must stay
  cadence-neutral. The snapshots table is timestamp-resolution-agnostic
  today: a user can seal 1-minute or 1-hour bars. Do not introduce
  columns, types, or `meta_json` conventions that imply one row per
  instrument per day, one snapshot per market session, or EOD-only
  frequency. The intraday support arc (2026-05-27 horizon entry) names
  this as a pre-v0.2.x footgun; the RFC author should confirm the
  proposed schema preserves the existing cadence-neutral posture.

Dependencies on prior cycles

- v0.1.8.5 canonical workflow article (Batch 3 / LDG-2437) surfaces the
  user-facing need and may already start teaching the convention on the
  existing `meta` argument as a documentation-only patch;
- pre-CRAN compatibility policy (2026-05-25 horizon) authorizes the
  breaking schema change without a deprecation cycle;
- the v0.1.8.6 DuckDB feature-storage spike runs in the same cycle but
  is independently scoped; its outcome does not gate the snapshot
  administration schema.

Promoted roadmap hooks

- snapshot administration and ETL provenance metadata RFC: seed-shape
  input for the v0.1.8.6 cycle; the RFC must conclude before the
  v0.1.8.6 spec is cut;
- `ledgr_snapshot_list()` filtering and listing API (coordinated with
  the metadata schema RFC);
- `ledgr_snapshot_deprecate()` and `ledgr_snapshot_supersede()`
  lifecycle API (coordinated with the metadata schema RFC; final scope
  decided in RFC synthesis);
- audit-log table for administrative edits (coordinated with the
  metadata schema RFC; final scope decided in RFC synthesis).

Cross-cycle note

The v0.1.8.5 workflow article should not teach a not-yet-existing notes
API. Until the RFC lands and v0.1.8.6 implementation ships, the
article's teaching path is "your store path is explicit, but the
discipline of recording ETL provenance belongs in your project README
or workflow_review.md report next to the store." That documentation-
only patch sits inside Batch 3 (LDG-2437) scope without expanding it.

This horizon entry is the seed-shape input for the snapshot
administration RFC. It does not replace the RFC cycle, and the RFC
synthesis (not this entry) is what authorizes the v0.1.8.6 spec scope.

This horizon entry does not authorize any of the above. It records the
direction so that when the snapshot administration RFC cycle opens, the
seed author starts from a known shape rather than re-deriving the
boundary.

### 2026-05-27 [ux] Research-loop ergonomics helpers surfaced by the v0.1.8.5 workflow vignette

The v0.1.8.5 canonical research workflow article
(`vignettes/research-workflow.qmd`) explicitly flags two API gaps in
user-visible callouts. They surfaced during teaching, not speculation:
the article had to fall back to lower-level patterns to keep the
research-loop story honest, and the callouts mark exactly where the
helpers should land.

Both gaps share a shape: ledgr already records the underlying data.
The gap is in the summary surface that exposes the data compactly
without flattening the visible selection rule or provenance reasoning.

This entry supersedes the earlier 2026-05-25 "Sweep candidate ranking views"
stub (the `ledgr_rank_candidates()` sketch). The sweep-review helper below is
the same idea, taken further and tied to the vignette gap that motivates it.

#### Gap 1: Sweep review helper

Vignette location: the "Inspect Before You Promote" section and its
"Design note" callout.

The article currently teaches:

```r
ranked <- sweep |>
  filter(status == "DONE") |>
  arrange(desc(sharpe_ratio))

candidate_columns <- c(
  "run_id", "status", "final_equity", "total_return",
  "sharpe_ratio", "params", "feature_params"
)
top_n <- ranked |> slice_head(n = 5) |> select(all_of(candidate_columns))

issue_columns <- c("run_id", "status", "error_class", "error_msg", "warnings")
issues <- sweep |> filter(status != "DONE") |> select(any_of(issue_columns))

candidate <- ledgr_candidate(ranked, 1)
```

What is missing: a helper that ranks completed candidates by an
explicit rule, returns a compact review table, separates issue rows
into their own table, and preserves the visible selection rule.

Critical design constraint: the helper must not hide the ranking
rule. The vignette's whole teaching arc is that the metric must be a
deliberate user choice, not a default the helper picks silently. A
shape such as
`ledgr_sweep_review(sweep, rank_by = desc(sharpe_ratio), n = 5)` keeps
the rule in the call site.

#### Gap 2: Promotion recovery summary

Vignette location: the "Reopen The Artifact" section and its
"API gap" callout-warning.

The article currently teaches users to inspect:

- `info$promotion_context$source`
- `info$promotion_context$selected_candidate$run_id`
- `info$promotion_context$selected_candidate$params_json`
- `info$promotion_context$selected_candidate$feature_params_json`

plus a separate `ledgr_extract_strategy()` call returning
`strategy_params`, `reproducibility_level`, and `hash_verified`.

What is missing: a single helper that summarizes a promoted run's
"what caused this result?" record in one compact object: promotion
source, selected candidate identity, strategy and feature parameters,
strategy source provenance, and hash-verification status, without
requiring nested-field navigation across multiple objects. A shape
such as `ledgr_promotion_summary(snapshot, run_id, trust = FALSE)`
returning a named list or compact tibble would fit.

#### Shared design constraints

- Helpers preserve the styleguide rule that selection or ranking rules
  stay visible to the reader. A "show me the best candidate" helper
  that picks Sharpe silently is exactly what the workflow article
  warns against.
- Helpers do not replace `ledgr_results()`, `ledgr_run_info()`,
  `ledgr_extract_strategy()`, or `ledgr_candidate()`. They are
  summary surfaces over those lower-level APIs, not parallel ones.
- Output is inspectable as a plain data frame or named list, never an
  opaque print-only object.
- The recovery summary distinguishes stored facts (parameters, hashes,
  note) from interpretation (reproducibility tier, hash-verification
  status, recovery limitations). Tier 1 and Tier 2 strategies must
  not collapse into a single "verified" status.

#### Scope risks

- **Selection-rule erasure.** Easiest failure mode for the sweep-review
  helper is shipping a sensible default ranking metric. The helper
  should require an explicit rank-by argument or return the chosen
  rule alongside the rows.
- **Provenance summary as truth.** Easiest failure mode for the
  recovery helper is collapsing tier-1 and tier-2 strategies into one
  "verified" status. Tier 2 strategies have real recovery limitations
  and the summary must surface them honestly.
- **Over-abstraction.** The current low-level paths are verbose but
  not user-hostile. The helpers should compress the common case
  without removing the lower-level paths from the public API.

#### Dependencies on prior cycles

- v0.1.8.4 active aliases and grid helpers shipped (precondition:
  `sweep` carries `feature_params` and `params` columns and `status`
  is canonical);
- v0.1.8.5 canonical workflow article (Batch 1 / LDG-2435) is the
  surface that demonstrates the gap and constrains the helper shape;
- v0.1.8.5 sweeps documentation (Batch 4 / LDG-2438) should teach
  the helpers if they ship in the same cycle, otherwise it should not
  pre-document them.

#### Promoted roadmap hooks

- sweep-review helper: scoped into v0.1.8.6 Workstream C; design folds
  into the snapshot administration RFC (Workstream A) since both touch
  "what does it mean to reopen this run?";
- promotion-recovery-summary helper: same;
- when the helpers ship, revise the vignette's "Design note" and
  "API gap" callouts to reference the new functions, or remove them
  if the helper makes the lower-level path unnecessary in the
  teaching arc.

#### Cross-cycle note

The vignette's "Design note" and "API gap" callouts are the user-
visible markers for these gaps. When the helpers land, the callouts
should be revised to reference the new functions, or removed if the
helper makes the lower-level path unnecessary in the teaching arc.
Leaving stale callouts in the article is a worse failure than the
gap itself.

This horizon entry does not authorize any of the above. It records
the direction so that when a research-loop ergonomics cycle opens,
the author starts from a known shape rather than re-deriving the
boundary.

### 2026-05-27 [execution] Intraday support arc and pre-v0.2.x architectural footguns

ledgr's roadmap permanently excludes high-frequency, sub-millisecond, and
tick-by-tick execution. It does not exclude minute-to-hour bar resolution.
User feedback during the v0.1.8.5 cycle indicates intraday is real future
demand: many users who would use ledgr for EOD research also want to use it
for intraday research, and "the same backtester for both" is a defensible
USP. This entry captures the multi-cycle arc to support intraday as a
first-class workflow, plus the architectural footguns the in-progress
v0.1.x cycles must avoid so the eventual flip is not a rewrite.

This entry supersedes the earlier 2026-05-13 "Intraday architecture
feasibility" stub. The parallelism-spike evidence it cited remains at
`inst/design/spikes/ledgr_parallelism_spike/summary_report.md` and
`.../architecture_synthesis.md`; that spike used intraday-like payloads only to
stress data movement and did not test intraday snapshot schema, pulse
calendars, sub-day fill timing, or metrics at intraday scale.

The user will initiate a design audit before committing to the intraday
arc. This entry is the audit's input shape.

#### Today's posture: EOD-first, intraday-tolerant

The snapshot schema is timestamp-resolution-agnostic. A user can seal
1-minute or 1-hour bars today, declare a feature map, and run a strategy
against them. The fold core, pulse model, ledger events, and accounting
mechanics are calendar-agnostic at the storage layer.

Every layer above storage assumes EOD shape, however:

- **Session calendars do not exist.** Warmup, annualization, and metric
  context all assume one bar equals one day. A 50-period SMA on 1-minute
  bars is 50 minutes, but annualization treats it as 50 days.
- **Fill timing is EOD-shaped.** The v0.1.8 internal cost boundary
  (`validated_targets -> next_open_timing -> fill_proposal -> cost ->
  fill_intent`) is swappable by design but ships with only `next_open`
  semantics. Intraday wants next-pulse-touch, mid-point, VWAP, or
  session-close policies that do not exist.
- **No OMS.** Strategies return target vectors. Intraday usually wants
  order lifecycle (place / modify / cancel, partial fills). That work is
  v0.2.x with an accepted synthesis at
  `inst/design/rfc/rfc_ledgr_oms_seed_synthesis.md`.
- **Cost / liquidity policy is not intraday-aware.** The v0.1.9.x/v0.2.0
  cost API works for intraday in principle, but participation, capacity,
  and minimum-ADV policy (also v0.2.x) is what intraday actually needs.
- **Storage scale changes.** The v0.1.8.6 feature-storage spike measures
  EOD workloads. Intraday changes the answer.

Users who run intraday today get coherent reproducibility on the data and
strategy axes and broken semantics on the metric and fill-timing axes. The
honest framing for v0.1.8.5 docs is "intraday bars seal fine but metric
annualization assumes EOD; treat results as exploratory until v0.2.x."

#### The required arc

First-class intraday is a multi-cycle endeavor:

1. **OMS semantics** (v0.2.x, accepted synthesis) — load-bearing for
   order lifecycle, partial fills, and the two-stream `order_events` /
   `ledger_events` separation.
2. **Session calendar infrastructure** (new RFC, post-OMS) — exchange
   sessions, holidays, half-days, lunch breaks, pre/post-market handling.
3. **Intraday fill-timing policy** (extends v0.1.9.x cost API arc) —
   next-pulse-touch, mid-point, VWAP, session-open / session-close, with
   the same swappable boundary the EOD `next_open_timing` already uses.
4. **Intraday-aware metric context** (extends v0.1.8.2 metric context
   work) — annualization factor parameterized by cadence and sessions,
   not hardcoded.
5. **Liquidity / capacity policy** (already v0.2.x roadmap) — execution
   feasibility separate from cost, with participation limits that mean
   something different intraday vs EOD.
6. **Storage scale evidence** (extends v0.1.8.6 spike) — the spike's
   exit-decision changes once intraday workloads enter the comparison.

The arc spans v0.2.x through v0.3.0 in the existing roadmap. The OMS
synthesis is the entry point. Calendar infrastructure is the missing RFC.

#### Architectural footguns the v0.1.x cycles must avoid

This is the operative section. The current cycles (v0.1.8.5 through
v0.1.9.x) must not paint the framework into corners that the intraday
flip will have to rip out. The list below is the audit checklist.

- **Pulse cadence is a snapshot-derived property, not a global constant.**
  Any code path that hardcodes "trading day" semantics in the fold core,
  metric annualization, or warmup teaching is a footgun. Cadence must be
  read from the snapshot.
- **Warmup is bar-count, never time-implied.** `passed_warmup()` and the
  active-alias warmup pipeline are bar-count today. Correct for both EOD
  and intraday. Preserve. The trap lives in metrics, not warmup itself.
- **Metric context must expose a cadence/annualization slot.** The v0.1.8.2
  metric-context templates (US equity, crypto) reserved this surface.
  Audit them to confirm `annualization_factor` is a parameter, not a
  constant. Intraday metric context shares the calendar; the cadence
  changes.
- **Fill timing stays a swappable internal boundary.** The v0.1.8 cost
  boundary already reserved this. Preserve. No v0.1.x ergonomics work
  should bake `next_open` into a code path that should be policy-pluggable.
- **Strategy contract preserves intraday signatures.** Strategies return
  full named numeric target vectors. That signature works for both EOD
  and intraday. Do not add EOD-flavored methods to the canonical strategy
  context (`ctx$today()`, `ctx$is_market_open()`) in v0.1.x — those
  belong on a future intraday-aware context, not on the existing one.
- **Risk-layer affordability check must be net across one pulse's
  proposed fills, not per-instrument sequential.** The fold core's fill
  loop iterates per instrument and updates cash sequentially
  (`R/fold-core.R:233-287`). When the v0.1.9 target-risk layer adds
  affordability adapters, they must check feasibility against the net
  cash delta from all proposed fills at one pulse, not per-instrument:
  a per-instrument check would reject rebalancing strategies depending
  on instrument iteration order (BUYs checking cash before paired SELLs
  free it up), even though both fill at the same `t+1` open in reality.
  Intraday rebalancing makes this acute because rebalances fire more
  often; an equity-EOD test won't surface it. This also threads into
  the v0.2.x OMS two-stream design — `order_events` recorded as a
  batch atomic at the fill bar makes "shared cash pool at one fill
  timestamp" structural rather than implicit.
- **Storage schema stays timestamp-resolution-agnostic.** Today it is.
  The snapshot-administration RFC (v0.1.8.6) must explicitly preserve
  this and must not introduce fields that imply one row per instrument
  per day.
- **Sweep result and run identity stay frequency-agnostic.** `run_id`,
  `snapshot_hash`, `config_hash`, and sweep candidate identity must not
  encode "EOD" anywhere. They do not today — preserve.
- **OMS-shaped target-decision storage from the start.** The accepted
  OMS synthesis explicitly warns that intraday-compatible target storage
  needs retention-dependent, batchable, potentially sparse / columnar /
  payload-reference shapes. v0.1.x EOD work can implement the simple
  per-decision shape but must not commit to a schema the OMS work will
  have to rip out destructively.
- **Cost API spread / participation assumptions stay EOD-neutral.** The
  accepted v0.1.9.x cost API synthesis keeps `cost_spread_bps()` as a
  quoted-spread function over a fill context. Intraday extends the
  context, not the cost API. Preserve that boundary.
- **Demo data and demo strategies stay EOD-shaped.** That is fine. The
  footgun is letting demo-data assumptions leak into runtime invariants.
  Already correct today — preserve.
- **Walk-forward window semantics generalize from EOD-day folds to
  intraday-session folds.** The accepted walk-forward synthesis represents
  scoring windows explicitly. Audit to confirm the window model does not
  hardcode day semantics.
- **Dense-panel fail-fast is a backtest seal-time gate, not a universal
  invariant.** `ledgr_missing_bars` aborts the run if any instrument lacks a
  bar at any pulse (verified: cross-join completeness check
  `backtest-runner.R:1541-1564`; per-instrument alignment
  `backtest-runner.R:1154-1159`). That is correct for sealed backtest data and
  wrong for live streaming, where missing/garbled ticks are routine. The
  v0.2.x data-model and live-data work must not treat the dense panel as
  permanent — see the 2026-05-28 live bad-data resilience entry.

#### Migration efficiency requirements

A clean migration to first-class intraday means:

- existing EOD users' runs remain reopenable after the intraday flip
  lands;
- the public strategy contract `function(ctx, params) -> target vector`
  survives intact; the context object gains intraday-aware methods but
  loses none;
- cost API stays additive — new timing/cost policies are opt-in
  constructors, not breaking changes;
- run identity hashes stay stable for unchanged EOD inputs after the
  intraday code lands;
- the snapshot administration schema accommodates intraday bars without
  schema migration on EOD stores.

The pre-CRAN compatibility policy authorizes breaking changes within
v0.1.x to clean up footguns before they become permanent. Use that
window deliberately. After CRAN, the migration becomes much more
expensive.

#### Design audit scope

The user will initiate a design audit. The audit's input is this entry
plus the affected code paths. Suggested audit scope:

- every code path that assumes "day" semantics: metric annualization,
  calendar inference, warmup teaching prose, demo data shape;
- every API boundary that could plausibly be cadence-aware but isn't:
  `metric_context`, fill timing, `ledgr_run_info()` cadence reporting,
  sweep candidate metadata;
- every place where session boundaries (open/close, lunch breaks,
  holidays, half-days) would matter once intraday lands: pulse calendar
  construction, opening/closing fill behavior, warmup hydration across
  sessions;
- the OMS synthesis target-decision-storage section, to confirm v0.1.x
  EOD storage decisions do not preclude the intraday-compatible shape;
- the cost API synthesis fill-context section, to confirm the context
  shape supports intraday extensions without API rewrite;
- the walk-forward synthesis window model, to confirm window semantics
  generalize from EOD folds to intraday session folds;
- the snapshot-administration RFC seed-shape (this horizon), to confirm
  the metadata model is cadence-neutral;
- demo data, vignette code, and contract tests for any place that
  conflates "one bar = one day" with "one pulse = one decision".

Audit output: a list of footguns that exist today, a list of footguns
the in-progress cycles must not introduce, and a list of decisions that
are already correct and worth pinning with contract tests so they do
not regress.

#### RFCs to revisit after the audit

The audit will read existing synthesis documents to check whether their
accepted designs survive an intraday flip. The list below is grouped by
how directly each RFC touches cadence, fill timing, target lifecycle,
or storage shape. A "revisit" outcome can be one of three: confirm the
design is already cadence-neutral and pin it; identify a specific clause
that needs to be amended before the corresponding implementation cycle
opens; or open a follow-up RFC to extend the existing synthesis.

**Tier A — load-bearing for intraday, must revisit:**

- `rfc/rfc_ledgr_oms_seed_synthesis.md` — the target-decision-storage
  section already mentions intraday-compatible storage shape (retention-
  dependent, batchable, potentially sparse/columnar/payload-reference).
  Confirm that any v0.1.x EOD per-decision storage work does not preclude
  the future shape destructively.
- `rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md` —
  confirm the `fill_context` shape supports intraday extension (next-
  pulse-touch, mid-point, VWAP, session-close timing) without breaking
  the public cost-model factory API.
- `rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md` —
  confirm `metric_context` exposes `annualization_factor` (or
  equivalent) as a parameter, not a hardcoded 252 anywhere downstream.
  Audit the US-equity and crypto templates for hidden EOD constants.
- `rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md` — confirm the
  training/test-window model represents windows in calendar terms that
  generalize to intraday session folds, not just EOD-day folds. The
  synthesis says windows are explicit; verify "explicit" includes the
  cadence axis.
- `rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md` — confirm
  the risk-step interface is cadence-neutral. Risk decisions intraday
  fire much more often; the boundary must not embed EOD-pulse-rate
  assumptions in the step semantics.

**Tier B — architectural foundations intraday inherits, recommend revisit:**

- `rfc/rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md` —
  confirm sealed-snapshot lineage and one-store topology decisions stay
  cadence-neutral. Intraday lineage (e.g., yesterday's session bars
  rolled forward into today's snapshot) is a v0.2.x roll-forward concern;
  the v0.1.8.5 topology should not preclude it.
- `rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md` —
  confirm the runtime projection interface and R-memory backend make no
  "one row per instrument per day" assumption. Intraday volume changes
  the memory profile; the projection contract should already handle this
  but worth pinning.
- `rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md` —
  confirm the consolidated pulse-context model does not embed EOD-flavored
  methods or shape assumptions. The strategy contract is the long-term
  intraday boundary.
- `rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis.md` and
  `rfc/rfc_sweep_promotion_context_v0_1_8_synthesis.md` — confirm
  candidate and promotion-context identity (seeds, hashes, params) is
  frequency-agnostic. Already believed to be true; pin with contract
  tests if so.

**Tier C — feature and storage shape, scan for footguns:**

- `rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md` —
  confirm feature-parameter semantics do not imply EOD frequency.
  `ledgr_param("fast_n")` is a count, not a calendar duration; preserve.
- `rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md` —
  scan for memory and volume assumptions tied to EOD bar counts. Wide
  runtime views at intraday scale are a v0.1.8.6 spike concern.
- `rfc/rfc_multi_output_indicator_ux_synthesis.md` — confirm bundle
  output shape is frequency-neutral.
- `rfc/rfc_indicator_codebase_simplification_v0_1_8_x_synthesis.md` —
  confirm indicator surface (series_fn contract, adapters) treats bar
  cadence as snapshot-derived, not global.

**Tier D — performance and measurement:**

- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md` —
  worker assumptions and serialization costs change at intraday volume;
  re-evaluate if intraday lands.
- `rfc/rfc_collapse_primitive_internals_v0_1_9_synthesis.md` — the
  primitive-internals decisions assume EOD-scale workloads. Intraday
  changes the cost/benefit math; the synthesis already conditions
  implementation on measurement, so this is mostly "rerun the
  measurement at intraday scale before promoting Phase B/C.1."

**Horizon entries (seed-shape inputs) that should also be re-read:**

- the snapshot administration entry (2026-05-27, this file) — already
  amended with an intraday-readiness scope risk;
- the research-loop ergonomics helpers entry (2026-05-27, this file) —
  helper output shape must be cadence-neutral;
- the walk-forward post-v0.1.9.x direction entry (2026-05-27, this file)
  — confirm follow-up directions extend cleanly to intraday folds;
- the cost-model post-v0.1.9.x direction entry (2026-05-27, this file)
  — confirm timing/cost extensions accommodate intraday fill policies.

The audit should record, for each RFC above, whether it is **pinned**
(design is cadence-neutral, add contract tests), **amend** (one or more
specific clauses need updating in the existing synthesis), or **extend**
(open a new RFC that extends the existing synthesis for intraday). The
audit output is itself an input for the v0.2.x intraday-arc cycle
planning.

#### Promoted roadmap hooks

- intraday support arc (v0.2.x through v0.3.0, multi-cycle) — depends
  on OMS, session calendars, intraday fill timing, liquidity/capacity,
  intraday-aware metric context, and intraday storage scale evidence;
- session calendar infrastructure RFC — new work, no current roadmap
  line; cut after OMS lands;
- intraday metric context extension — extends v0.1.8.2 metric context
  work; same calendar surface, parameterized cadence;
- intraday fill timing policy — extends v0.1.9.x/v0.2.0 cost API arc;
- intraday storage scale evidence — extends v0.1.8.6 feature-storage
  spike with intraday workload comparisons if the spike is rerun;
- design audit for intraday-readiness footguns — user-initiated, no
  committed cycle, but this entry provides the input shape.

#### Cross-cycle note

This entry does not authorize new cycles. Its operative effect is on
the in-progress v0.1.8.5 cycle and the planned v0.1.8.6, v0.1.8.7,
v0.1.9, and v0.1.9.x cycles: each must avoid the footguns named above.
The user-initiated design audit will produce a sharper list of "preserve
this" and "fix this before it becomes permanent" findings. Until the
audit lands, treat this entry as a soft constraint on architectural
decisions in cycles that touch metric context, fill timing, target
storage, pulse cadence, or sweep candidate identity.

The "EOD-first, intraday-tolerant" posture remains the right user-facing
framing for v0.1.8.5 documentation. Do not pre-document intraday
support; do not pre-commit to it in user-facing prose; do not let
intraday assumptions sneak into v0.1.x code that should be cadence-
neutral.

This horizon entry does not authorize the intraday arc itself. It
records direction so that when the arc opens, the seed authors start
from a known shape rather than re-deriving the boundary, and it
constrains the in-progress v0.1.x cycles to avoid footguns that would
make the eventual flip a rewrite.

### 2026-05-28 [data] Live bad-data resilience and sim-to-real backtest fidelity

The overall arc is backtest -> paper -> live. Live data is structurally
different from backtest data, and the difference is a fault line the
backtest-first design has not had to confront. Surfaced while reviewing the
fold core; the maintainer has flagged it as RFC-worthy.

The fault line

ledgr's backtest correctness rests on a **sealed dense panel**, enforced
fail-fast: every instrument must have a bar at every pulse or the run aborts
with `ledgr_missing_bars` (verified: cross-join completeness check
`backtest-runner.R:1541-1564`; per-instrument alignment
`backtest-runner.R:1154-1159`). Live data is the opposite posture — a
streaming partial feed where missing, garbled, late, duplicated, or revised
ticks are routine. You cannot abort a live session because one symbol's tick
did not arrive. "Validate everything upfront, fail fast" and "tolerate and
degrade per-tick" are structurally opposed.

Second fault line — offline ragged universes (not just live)

The dense-panel gate also blocks a purely *offline* case: a realistic surviving
universe is inherently ragged. IPOs / late listings, delistings, halts, and
exchange holidays mean a security legitimately has no bar at some pulses — yet
the coverage check (`backtest-runner.R:815-822`, `LEDGR_SNAPSHOT_COVERAGE_ERROR`,
plus the `ledgr_missing_bars` cross-join check) requires every instrument to
have a bar at every pulse, so survivorship-realistic research is impossible
without external pre-cleaning. This is independent of the live/streaming arc.

Peer evidence (2026-05-29 research): among multi-asset / panel backtesters,
hard-failing on any per-instrument gap is an **outlier**. The mainstream
tolerates ragged panels — Zipline and LEAN forward-fill and model **asset
lifetimes** (start/end/delist, masking outside the active window with NaN/zero;
`zipline data_portal.py:1018-1030`, LEAN fill-forward-until-delisted); `bt`
(Python) and VectorBT carry not-yet-listed / delisted assets as NaN columns and
object only on a *held* NaN position. The only hard-failers are *single-asset*
frameworks (backtesting.py) or per-symbol loops (quantstrat), where there is no
cross-sectional alignment to solve. So strict single-series rejection is
mainstream; strict *multi-asset-panel* rejection is not.

Design target: **per-instrument active windows** (asset lifetimes) — an
instrument is active over `[first_bar, last_bar]` and the fold tolerates its
absence outside that window — plus an **explicit, sealed** absence/imputation
policy. The ledgr-specific constraint vs peers: their ffill is *silent*; ledgr's
"evidence you can defend" USP requires the active-window and any
fill / NaN / staleness policy to be **declared and sealed into the snapshot**
(and visible in provenance), not silently imputed in the fold — otherwise the
backtest runs on a quietly different data world than the inputs claim. The
*where* matters: active windows + the ingest policy live at the seal boundary;
the fold then consumes a panel marked "present / absent-by-lifetime / imputed",
and never hard-fails on legitimate absence.

Failure taxonomy (each needs a different policy)

- **Missing tick** — skip the symbol, carry forward last value with a
  staleness flag, halt the symbol, or halt the session.
- **Garbled tick** — zero/negative/NaN price, OHLC violation, absurd spike.
  Backtest catches this at seal time; live must catch it at ingest time and
  quarantine/reject before it reaches a decision.
- **Late / out-of-order tick** — needs a watermark/lateness policy.
- **Duplicate tick** — idempotent ingest.
- **Revised tick** — vendor corrects a past bar after the decision was made;
  you cannot un-decide. Hardest case.

What carries over vs what breaks

Carries over: the event-sourced ledger (a live session is a longer append-only
event stream), the pulse model (a live pulse is information available at
decision time t; no-lookahead is trivially satisfied), and the v0.2.x OMS
two-stream design. Breaks: the dense-panel fail-fast, and snapshot
immutability (live appends as data arrives — an append-only data log, not a
sealed snapshot).

Chosen direction: B — the backtest must model degraded data

Two ways to close the sim-to-real gap:

- **(A)** force live into the dense-panel model — buffer/wait/skip. Simple,
  preserves the backtest model, adds latency, not always viable.
- **(B)** give the backtest the ability to model degraded data — gap
  injection, staleness, halts, bad-tick spikes — so strategies are validated
  against realistic data conditions before live.

**Decision: direction B.** The "evidence you can defend" USP collapses if the
evidence was gathered on a cleaner data world than the strategy will face live.
When paper trading is designed, the maintainer wants to simulate data streams
with all kinds of deficiencies, at a much higher frequency than EOD, to test
the seams — and the backtest engine must be able to swallow that bad data on
the same execution path. So the backtest data model has to grow a "this bar is
missing / stale / suspect" representation it does not have today.

Design principles

- **Strategy contract does not change.** A strategy sees "current pulse-known
  information" in both backtest and live. What changes is what the *data layer*
  decides "current" means when a tick is missing or suspect. Degradation
  policy must not leak into every strategy.
- **Late/revised ticks intersect Point-In-Time Data Tables** (v0.2.x:
  `known_at`, `available_at`, `revision_time`, source version). A PIT model
  keeps "the decision at t used the data available at t" true even after a
  later revision — the revision is a new vintage, not a rewrite of history.
- **Missing/garbled at ingest needs a live data-quality layer** with an
  explicit degradation policy (quarantine / reject / carry-forward-with-
  staleness / halt-symbol / halt-session), distinct from the backtest
  seal-time gate.

RFC scope (when it opens)

A unified data-quality model spanning sealed backtest and streaming live; the
degradation-policy surface; **per-instrument active windows (asset lifetimes) for
ragged offline universes, with an explicit sealed absence/imputation policy
(vs peers' silent ffill)**; the bad-data simulation harness for backtest
(deficient high-frequency streams); and the PIT-tables intersection.

Sequencing

Behind PIT tables and the live data log (v0.2.x) and the OMS work; lands around
v0.2.x -> v0.3.0 paper trading. The high-frequency deficient-stream simulation
is a v0.3.0 paper-trading design input. Near-term footgun is already recorded
in the intraday-readiness entry: the dense panel is a backtest gate, not a
universal invariant.

This horizon entry does not authorize the work. It records the direction and
the chosen approach (B) so the eventual RFC starts from a known shape.

### 2026-05-28 [execution] RNG resume is non-deterministic for stochastic strategies

Verified correctness gap (2026-05-28), found during the fold-core validation.

On resume, **state** is correct: cash and positions are reconstructed by
replaying events as-of the resume timestamp via `ledgr_state_asof()`
(`backtest-runner.R:1088-1099`). But the **RNG stream** is not restored. The
runner calls `set.seed(seed)` (`backtest-runner.R:589`) and the fold calls
`set.seed(execution_seed)` (`fold-core.R:69`); the loop then jumps to
`start_idx` without replaying pulses 1..start_idx-1, and there is no
`.Random.seed` checkpoint/restore anywhere (it exists only in `sim-bars.R`, the
unrelated bar simulator).

Consequence: a **deterministic** strategy resumes byte-identically (no RNG
dependence). A **stochastic** strategy (Tier 2, e.g. `runif()`) drawing at
pulse k on resume gets the *pulse-1* RNG draw, not the advanced stream a
continuous run would have at pulse k. The execution-seed contract guarantees
within-continuous-run repeatability, not resume equivalence for stochastic
strategies.

Decision needed (one of):

- checkpoint `.Random.seed` at each flushed pulse and restore it on resume;
- replay pulses 1..start_idx-1 on resume to re-advance the RNG (expensive);
- document the limitation and restrict resume guarantees to deterministic
  strategies (cheapest, honest).

Cross-link: the v0.1.8.8 parallel-dispatch work faces the same RNG-state
question - per-candidate seed derivation must not depend on worker scheduling
or global RNG state. Whatever resolves resume should align with that.

This entry records a verified gap, not a committed fix.

### 2026-05-28 [architecture] Fold-core structural debt surfaced by adversarial review

Two adversarial reviews of the fold-core workbook surfaced design debt that is
survivable today but should be addressed before OMS / risk / intraday land.
None is a correctness bug — the one alleged SELL cash-sign bug was a workbook
paraphrase typo, not a code bug; the code uses absolute `fill$qty` and is
correct (`fold-core.R:280-284`, `ledger-writer.R:66-71`). These are refactor
candidates.

- **One production replay kernel.** Two equity-reconstruction implementations
  share one algorithm: the inline run-path copy (`backtest-runner.R:1378-1478`)
  and the sweep reconstructor (`ledgr_sweep_summary_from_ordered_events`), with
  `ledgr_equity_from_events`/`ledgr_fills_from_events` as test-only parity
  twins. The split is perf-motivated (v0.1.8.3: sweep avoids the DB round-trip)
  and guarded by `test-sweep-parity`. End-state: one production replay kernel
  fed by DB or memory event sinks; everything else an adapter. Partial fills,
  dividends, borrow fees, or margin would multiply the drift risk.
- **Phased pulse for portfolio-level risk.** The per-pulse loop interleaves
  delta -> proposal -> cost -> event -> state-mutation per instrument. That
  shape resists portfolio-level risk and net affordability. Target shape: plan
  (targets -> deltas) -> batch proposals -> batch cost -> batch/portfolio risk
  + net affordability -> emit -> apply atomically. This is the structural
  prerequisite for the v0.1.9 affordability check (see the 2026-05-27
  affordability-in-target-risk entry) and is a v0.1.9 target-risk RFC input.
- **Typed execution spec.** The `execution` list is a large untyped bag; run
  and sweep hand-build equivalent-but-not-identical lists (verified divergences
  in seed derivation, `event_mode`, hardcoded vs config fields, metric-kernel
  timing). A typed `ledgr_execution_spec()` constructor with validation would
  prevent run/sweep drift.
- **Split `fold-core.R`.** It holds the engine, the reconstructors, and metrics
  helpers in one file. Split before OMS/risk/intraday add more concerns.
- **Explicit event types.** Opening positions are seeded as `CASHFLOW` events
  with meta flags. Accounting-critical semantics should not live only in
  `meta_json`; add a `POSITION_SEED` type (and reserve `FEE`, `DIVIDEND`,
  `SPLIT` for later) rather than overloading `CASHFLOW`. This is deferred from
  v0.1.8.8 and scheduled as a dedicated v0.2.x RFC coordinated with corporate
  actions / instrument-master work; do not slip it into fold-core documentation
  or parallel-dispatch tickets.
- **Batch-aware cost model.** The per-proposal `cost_resolver` cannot model
  batch/portfolio slippage or liquidity. Routes to the v0.2.x
  liquidity/capacity arc; the single-order resolver remains the default
  adapter.

Verified-and-fine (recorded so the design audit does not re-raise them): the
no-lookahead invariant holds; the `findInterval` equity mapping is correct for
next-open fills; the dense-panel fail-fast plus whole-run DuckDB transaction
(`run_transaction = dbWithTransaction`) make state/event consistency clean
(state is replayed from events, never separately persisted); open-position
drawdowns are captured by the equity curve, so there is no survivorship bias in
the headline return/drawdown metrics.

This entry records direction, not committed work.

### 2026-05-28 [adapters] External-package output adapters (PerformanceAnalytics first)

ledgr's stable public result tables (equity, fills, trades, ledger) plus the
stored metric context are the right substrate for thin, optional, output-only
adapters into the established R quant ecosystem. **Committed for v0.2.x** (see
the roadmap "External Package Adapters" entry); this horizon note records
direction, and an RFC synthesis — not this entry — authorizes any public API.

The first adapter is **PerformanceAnalytics**, scoped to its real strength — the
drawdown/return tables and long-tail risk/return stats, not its charts. It is a
pure output projection (equity -> return stream -> PA), so it touches no
causality, strategy-contract, determinism, or engine-mutation surface, and is
the cleanest public proof of the hexagonal pattern: ledgr owns the canonical
evidence, adapters enrich the analysis.

Charting is a separate, swappable renderer over the same return stream — not a
PA lock-in. PA's base-R graphics are a familiar/legacy option; the modern faces
are tidyquant (ggplot2 over the same PA metrics — distinct from the academic
tidyfinance) or a native ledgr ggplot tear-sheet (`R/plot.R` already exists).
The reusable port is the equity -> return conversion; many renderers consume it.

Why high-value: one stable result-table contract unlocks the whole
PerformanceAnalytics / PortfolioAnalytics / tidyfinance reporting and research
surface — a large host of additional capabilities (tear sheets, risk/return
tables, factor research, portfolio optimization) — without ledgr reimplementing
any of it.

Adapter ranking (later ones gated on their own readiness):

- PerformanceAnalytics — reporting / tear-sheet; first, output projection only.
- PortfolioAnalytics — portfolio construction / post-ledger optimization; after
  the v0.1.9 target-risk chain stabilizes.
- tidyfinance — factor / data research; with the v0.2.x PIT / vintage semantics.
- quantmod — data ingestion; useful but less differentiating.
- PMwR / quantstrat / blotter / fPortfolio — low priority or skip (accounting /
  engine overlap that would blur which engine is the source of truth).

Boundary the RFC must bind:

- output projection only — no second canonical metrics path;
- consume ledgr's OWN canonical return series (whatever `ledgr_compute_metrics`
  derives); never reinvent the return formula inside the adapter, or the base
  series silently diverges;
- PerformanceAnalytics metrics use PA conventions and can differ from ledgr's;
  scope PA to what ledgr does NOT already compute and label any overlap rather
  than presenting two conflicting Sharpe numbers as both authoritative;
- optional dependency (`Suggests` + `check_installed`), never `Imports`;
- adapters inspect, they do not select winners (no sweep ranking / promotion
  automation) — selection stays human, per the promotion-is-not-validation
  stance;
- benchmark-relative metrics coordinate with the v0.2.x benchmark-context layer
  so PA does not become the de-facto benchmark-metrics surface ahead of ledgr's
  own contract;
- one shared adapter namespace pattern (e.g. `ledgr_<pkg>_*`) decided up front;
- live `findInterval`+`cumsum` reconstruction and the reopened DB-replay path
  must yield identical adapter output.

Inside ledgr under `Suggests` for the first adapter (it proves the pattern
publicly); split into `ledgr.adapters` or per-package packages only if the
surface grows. Source: the 2026-05-28 maintainer review of an adapter-ecosystem
proposal.

This entry records direction, not committed work.

## Resolved

Entries move here when their idea has shipped or been answered. Each records
what resolved it. Sweep an idea here when its milestone closes — do not leave
shipped work in "Open."

### 2026-05-15 [adapters] Multi-output indicator authoring bundles — shipped v0.1.8.1

`ledgr_indicator_bundle` / `ledgr_ind_ttr_outputs()` shipped in v0.1.8.1 with
the accepted design: flatten-at-declaration to single-output indicators,
output-specific fingerprints, normalized prefix (`bbands_dn`), `prefix = NULL`
raw opt-in, instrument IDs never in feature IDs. See the v0.1.8.1 packet and
`rfc_multi_output_indicator_ux_synthesis.md`.

### 2026-05-15 [ux] Parameter-grid construction helpers — shipped (core) v0.1.8.4

`ledgr_feature_grid()`, `ledgr_strategy_grid()`, and `ledgr_grid_cross()`
shipped in v0.1.8.4 as candidate-set construction helpers with no
objective/ranking semantics. The `ledgr_grid_named()` /
`ledgr_grid_add_baseline()` variants were not built and remain low-priority
optional ideas if a future cycle wants them.

### 2026-05-25 [optimization] Grid-union shared pulse views — shipped v0.1.8.4

v0.1.8.4 adopted the grid-level concrete-feature-union: shared concrete
features computed once across a sweep grid, not once per candidate. See the
v0.1.8.4 packet.

### 2026-05-15 [execution] Single-core sweep hot-path optimization — shipped v0.1.8.3

v0.1.8.3 shipped the runtime projection + R-memory backend + fast context and
the summary-only in-memory accounting path
(`ledgr_sweep_summary_from_ordered_events`), addressing the pulse-context churn
and event-replay reconstruction costs this entry identified.

### 2026-05-13 [execution] Compact execution semantics article — shipped v0.1.8.5

`vignettes/execution-semantics.qmd` shipped in the v0.1.8.5 teachability cycle
(Batch 4) as the consolidated reference for next-open fills, targets-as-
holdings, decision-time sizing, final-bar no-fill, and open positions.

### 2026-05-13 [data] Data input and snapshot creation article — resolved v0.1.8.5

Resolved without a separate article: the v0.1.8.5 cycle moved the low-level CSV
bridge to the `?ledgr_snapshot_import_bars_csv` help page (reference boundary)
and kept experiment-store centered on run management, so the split this entry
proposed is no longer needed.
