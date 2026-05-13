# ledgr v0.1.8 Sweep Architecture Note

**Status:** Pre-spec architecture input.
**Scope:** Internal execution contracts for v0.1.8 sweep mode and the future
research-validation layers built on top of sweep.
**Non-scope:** Final v0.1.8 API, ticket cut, parallel implementation,
walk-forward implementation, PBO/CSCV implementation, and
`ledgr_snapshot_split()`.

This note is intentionally separate from `inst/design/architecture/ledgr_sweep_mode_ux.md`.
The UX note describes the user-facing sweep workflow. This architecture note
describes the internal constraints that must hold so sweep does not become a
dead-end execution path. It uses the same provenance boundary as the UX note:
sweep does not create durable experiment-store run provenance, but it may carry
in-memory candidate identity metadata needed to promote, rerun, or reject a
candidate deliberately.

## Thesis

v0.1.8 sweep may be sequential and modest. It must not entrench runner/output
coupling that blocks later parallel sweep, walk-forward analysis, or PBO/CSCV
diagnostics.

The target stack is:

```text
fold core
  -> ledgr_run()           single persisted run
  -> ledgr_sweep()         candidate evaluation with lighter output
  -> ledgr_walk_forward()  repeated train/sweep/test protocol
  -> PBO/CSCV diagnostic   combinatorial selection-bias measurement
```

The internal primitive should be closer to:

```text
evaluate(candidate, data_slice, output_policy)
```

than to:

```text
for each params row, run the whole snapshot and write less to DuckDB
```

## Core Principle

Reproducibility and selection integrity are orthogonal. Provenance records what
happened. It does not prove that the candidate-selection process was sound.

This principle must appear in the v0.1.8 sweep documentation. Sweep results are
exploratory unless the selected candidate is evaluated on data held out from
development.

## Fold Core And Output Handler Split

The UX proposal names the shared private fold core `ledgr_run_fold()`. The final
function name can be settled in the v0.1.8 spec, but the contract is clear: the
fold core is a private shared execution primitive, not an exported user API.

The fold core is the deterministic per-bar execution engine:

- pulse calendar order;
- pulse context construction;
- registered feature lookup;
- strategy invocation;
- target validation;
- fill timing;
- cost resolution;
- final-bar no-fill behavior;
- cash, position, and state transitions;
- event-stream meaning.

Strategy preflight is a pre-fold gate. It classifies the strategy before normal
execution begins and must feed its result into the output handler. It should not
be hidden inside candidate ranking or persistence code. The v0.1.8 spec must
decide whether preflight is implemented as fold setup or as a separate pre-fold
step, but it must happen before any candidate fold is evaluated.

For the v0.1.8 sweep shape, the strategy function is fixed across candidates and
only `params` varies. That means strategy preflight can run once per sweep and
its result can be attached to the sweep result object. Candidate-specific
feature factories affect feature identity and precompute validation, not the
strategy preflight tier, unless a future API introduces candidate-specific
strategy factories. This assumes `ledgr_strategy_preflight()` classifies only
the strategy function body and its referenced symbols, not the registered
feature definitions for a particular params set; verify that assumption before
finalizing the once-per-sweep preflight contract.

The output handler is the layer that receives fold events and decides what to
retain or persist:

- full DuckDB ledger rows for `ledgr_run()`;
- in-memory summary rows for sweep;
- top-N or selected-candidate event streams;
- failure records;
- worker-local output for future parallel execution.

Future `ledgr_run()` and `ledgr_sweep()` must call the same fold core. Sweep may
use a cheaper output handler, but it must not change strategy semantics, feature
values, pulse order, fill timing, state transitions, final-bar behavior, random
draws, or event-stream meaning.

This parity must be enforced by tests. The v0.1.8 suite should run the same
strategy, params, snapshot, features, opening state, and execution assumptions
through `ledgr_run()` and `ledgr_sweep()` and compare the quantities listed in
`inst/design/architecture/ledgr_sweep_mode_ux.md`: final equity, cash, positions, trades,
fills, equity curve, fill timing, warmup behavior, costs, long-only
enforcement, and random-draw semantics.

The internal cost boundary is part of that parity contract. If v0.1.8 extracts
fill timing and cost resolution into separate internal steps, the refactor must
produce identical fill prices, fees, cash deltas, ledger rows, equity curves,
metrics, comparison outputs, and `config_hash` values to the current scalar
`spread_bps` / `commission_fixed` implementation.

## Current Coupling Points

The pre-sweep code review in `inst/design/architecture/sweep_mode_code_review.md` identified
two closures inside `ledgr_backtest_run_internal()` that currently capture the
DuckDB connection from the outer runner frame:

- `write_persistent_telemetry`
- `fail_run`

Those closures are the concrete coupling points that prevent a clean fold-only
path. They mean there is no current execution path that can run the fold without
DuckDB writes or persistent-run status mutation.

The telemetry coupling also includes the session-global side channel:

- `.ledgr_telemetry_registry`
- `ledgr_store_run_telemetry()`
- `ledgr_get_run_telemetry()`

The related `.ledgr_preflight_registry` is a weaker but still real shared-state
coupling. It currently tracks preflight timing metadata. Running preflight once
per sweep reduces the risk for sequential v0.1.8 sweep, but future concurrent
sweeps must not let preflight timing from one sweep leak into another.

The current runner stores telemetry into `.ledgr_telemetry_registry` keyed by
`run_id`, then `write_persistent_telemetry()` reads back from that registry and
writes telemetry to DuckDB. That is acceptable for sequential persisted runs,
but it is the wrong boundary for sweep. Sweep needs telemetry to travel through
the candidate result/output-handler path, not through a package-global
side-channel.

For v0.1.8, the runner refactor must make these responsibilities output-handler
concerns. If they remain fold-core concerns, sweep will either duplicate the
runner or carry hidden persistence side effects.

## Requirement 1: Sweep Is An Evaluation Primitive

`ledgr_sweep()` evaluates candidates through the shared fold core. It is not a
second execution engine.

The v0.1.8 user API may look like a simple parameter-grid runner, but the
implementation must preserve a reusable evaluation unit:

```text
candidate + data slice + output policy -> candidate result
```

This keeps future walk-forward and PBO/CSCV workflows from reimplementing
strategy execution.

## Requirement 2: Output Policy Is A Contract

Sweep output is lightweight, not throwaway.

Even when sweep does not persist full ledger rows for every candidate, each
candidate result must retain enough identity to reproduce the candidate with a
committed `ledgr_run()` later.

This is in-memory candidate identity metadata, not durable run provenance. The
durable provenance record is created only when the user deliberately promotes a
candidate through `ledgr_run()`.

The always-kept candidate record should include at least:

- candidate label;
- params;
- status;
- objective value, when computed. This is absent in the v0.1.8 summary-only
  design when ranking is caller-owned, and is reserved for a future default or
  user-supplied objective;
- core summary metrics used for ranking;
- error class and message on failure;
- warnings relevant to interpretation;
- snapshot id and snapshot hash;
- strategy fingerprint or stored-source identity;
- feature fingerprints or feature-contract identity;
- opening state and execution assumptions;
- reproducibility tier, meaning the `ledgr_strategy_preflight()` classification
  such as `tier_1`, `tier_2`, or `tier_3`;
- random seed and pulse-level random-draw contract.

The exact v0.1.8 result shape can be narrower than a full run object, but it
must not be disposable. A sweep result should tell the user enough to promote,
re-run, or reject a candidate deliberately.

Open design decision for v0.1.8:

- The UX proposal resolves v0.1.8 as summary-only for all candidates. When, and
  for which workflows, should event-stream retention be introduced later?
- How are failed candidates represented and sorted?

This decision affects future walk-forward OOS stitching and whether PBO/CSCV
can be computed from sweep outputs without re-running candidates.

## Requirement 3: Objective Function Is Pluggable

The candidate ranking rule must not be hard-coded into the sweep engine.

v0.1.8 may satisfy this requirement by not owning ranking at all: sweep can
return a tibble and let users rank with `dplyr::arrange()` or other ordinary R
code. If v0.1.8 does provide a default objective, the objective should be a
user-visible or at least internally pluggable function that maps a candidate
result to a scalar ranking value.

The hard constraint is that the sweep engine must not embed ranking logic that
would resist a future objective argument.

Future walk-forward needs to call the same ranking rule inside each training
fold:

```text
train slice -> evaluate candidates -> rank by objective -> select params
test slice  -> evaluate selected params
```

If ranking is baked into `ledgr_sweep()` rather than passed into or separated
from it, walk-forward will either duplicate sweep logic or require a later
contract rewrite.

Open design decision for v0.1.8:

- What is the default objective?
- Is the objective supplied as a function, a metric name, or both?
- What candidate-result fields are guaranteed available to the objective?
- How are objective errors represented?
- Is an objective error a candidate failure, a sweep-level failure, or a
  separate ranking failure distinct from strategy-execution failure?

## Requirement 4: Data Slice Is An Internal Concept

The v0.1.8 public API may initially sweep the full snapshot. The internal
evaluation unit must not assume that "full snapshot" is the only possible pulse
range.

Future workflows need slice-aware evaluation:

- manual train/test snapshots;
- rolling or expanding walk-forward folds;
- CSCV/PBO block partitions;
- narrower date ranges inside a larger sealed snapshot.

A data slice should eventually carry at least:

- start timestamp;
- end timestamp;
- universe, if narrower than the experiment universe;
- warmup policy;
- feature/precompute coverage requirements;
- whether the slice is training, testing, or exploratory metadata.

The first v0.1.8 implementation does not need to export a data-slice object, but
it should avoid APIs or internals that make slice-aware evaluation awkward.

The sweep result should also leave room to label evaluation scope. Because a
single `ledgr_sweep_results` object evaluates one experiment/snapshot/scope,
this label belongs on the result object as metadata or a printed annotation, not
as a per-row column. At minimum, the v0.1.8 spec should decide whether a sweep
result is unlabeled, `exploratory`, `in_sample`, `holdout`, or something else.
The label does not make the process honest by itself, but it prevents sweep
output from implying that all evaluated objects have the same evidentiary role.

## Requirement 5: Indicator Parameter Sweeps Are First-Class

Sweep candidates are not limited to strategy constants. Indicator lookbacks,
TTR adapter parameters, and other feature-construction parameters are ordinary
candidate parameters when `ledgr_experiment(features = function(params) ...)`
uses them to build feature definitions.

This is a core research workflow, not a convenience extension. Users will
naturally sweep values such as `sma_n`, `rsi_n`, volatility lookbacks, and
feature thresholds together. The v0.1.8 sweep architecture must support that
without a separate "indicator sweep" API.

The architectural consequences are:

- candidate identity includes both strategy-use parameters and feature-factory
  parameters;
- feature factories are evaluated against each candidate params list before
  fold evaluation;
- candidate rows retain the original `params` and the resolved
  `feature_fingerprints`;
- precompute validation uses the union of all resolved feature fingerprints
  across the param grid;
- warmup feasibility is candidate-specific when feature factories produce
  different indicators for different params;
- parity tests must include at least one sweep where changing params changes
  the registered feature set, not only the strategy threshold.

This requirement does not imply a new exported API. `ledgr_param_grid()`,
`features = function(params)`, `ledgr_precompute_features()`, and
`ledgr_sweep()` are sufficient if they preserve the identity and validation
rules above.

## Requirement 6: Fill Timing And Cost Resolution Are Separable

v0.1.8 does not export a public cost-model API. It should still avoid locking
the fold core to `spread_bps` and `commission_fixed` as primitive fold
arguments.

The fold core should preserve this internal chain:

```text
targets_risked
  -> next_open_timing()
  -> ledgr_fill_proposals for the pulse
  -> internal cost resolver
  -> ledgr_fill_intent
  -> fold event
```

The current public fill configuration remains unchanged:

```r
fill_model = list(
  type = "next_open",
  spread_bps = 0,
  commission_fixed = 0
)
```

v0.1.8 may represent that configuration internally as the default cost
resolver. The resolver must wrap the current behavior exactly: buys fill at
`open * (1 + spread_bps / 10000)`, sells fill at
`open * (1 - spread_bps / 10000)`, and fixed commission is recorded as the fill
fee.

The current `ledgr_fill_next_open()` helper may remain as a compatibility or
internal helper used by the default resolver. The architecture constraint is
that the fold core must not be locked to its scalar signature as the primitive
execution boundary.

This boundary keeps execution timing and cost application distinct:

```text
timing model: decides when and at what reference bar a fill can occur
cost model:   resolves price and fees for an already proposed fill
ledger:       validates and records the resulting event
```

The ordinary strategy context remains decision-time only. A future
function-valued cost model must not receive the same `ctx` object that strategy
code sees, because cost resolution may legitimately need execution-bar data
such as next-bar open or volume. That data is post-strategy execution
information and must not leak into the strategy decision boundary.

The future cost signature should therefore use a separate fill context:

```r
cost_model <- function(fill_proposals, fill_context, params) {
  # returns fill intents with resolved fill_price and fee
}
```

The fill context may carry decision timestamp, execution timestamp, current-bar
data, next-bar execution data, current cash/positions/equity before the fill,
universe, and execution assumptions. It is an execution-pricing context, not a
strategy authoring context.

The execution-bar payload should reserve full OHLCV fields, not only `open`.
The current scalar cost model only needs next-bar open, but market-impact,
participation-rate, and liquidity diagnostics require execution-bar volume, and
some future cost policies may need high/low/close. In `audit_log` mode the full
bar is already available in the cached bar payload; in `db_live` mode the
current next-bar query must be widened when the proposal boundary is extracted.

The first cost-model contract should preserve instrument, side, quantity, and
execution timestamp. The initial internal resolver is stateless across pulses
and receives the batch of proposals generated for one pulse. This batch shape
leaves room for same-pulse fee allocation later, but it does not support daily
turnover budgets, cumulative commission budgets, soft-dollar tracking, or
cross-pulse liquidity state.

Quantity-changing behavior is not cost. Minimum trade filters, volume clipping,
partial fills, liquidity refusal, and participation limits change what fills
happen and must be deferred to a separate execution or liquidity contract
unless they are expressed as a target/risk transform before fill timing.

Pre-trade cost filters belong before timing, usually in the risk layer. A rule
such as "trade only when expected alpha exceeds estimated cost" must suppress
or alter targets before fill proposals exist. The v0.1.9 risk-layer spec should
record the future bridge: either cost factories expose an estimation function,
or risk helpers receive a cost-estimation helper that mirrors the chosen cost
policy without committing a fill.

Function-valued public cost models also require identity work before they can
be exported: source capture, fingerprinting, captured-object representation,
and preflight or contract classification. v0.1.8 avoids that unresolved public
API surface by keeping the resolver private and derived from scalar config.

Cost resolution happens inside the fold before output handlers receive events.
Output handlers must not compute, reinterpret, or rewrite costs. This preserves
the sweep parity guarantee:

```text
same proposal + same cost resolver -> same fold event
```

whether the output handler writes DuckDB rows for `ledgr_run()` or in-memory
summary rows for `ledgr_sweep()`.

The internal refactor must not alter run identity. The canonical config
serialization for the existing scalar fill model must remain byte-identical so
stored run resume, run comparison, and experiment identity keep working across
the fold-core extraction.

## Precomputed Feature Input

The UX proposal defines `ledgr_precompute_features()` as the intended mechanism
for computing shared feature series once across a parameter grid. The returned
`ledgr_precomputed_features` object is expected to carry snapshot hash, universe,
date range, indicator fingerprints, and feature-engine version.

The architecture consequence is that sweep's fold path must validate a
precomputed feature object against the experiment snapshot, universe, requested
date/slice range, and feature definitions before evaluating candidates. A
mismatched precompute object is an execution-contract error, not a cache miss.

For `features = function(params) list(...)`, validation must cover the union of
all indicator fingerprints that any candidate in the parameter grid may request.
It is not enough to validate one nominal feature definition or one candidate's
feature set. Changing the grid after precompute must trigger a loud mismatch if
the precomputed object does not cover the new union.

For concrete feature lists or feature maps, the union is just the fixed feature
set. For feature factories, the union is discovered by evaluating the factory
for each params row, normalizing the returned feature objects, and computing
their fingerprints. Deduplication may avoid repeated computation, but it must
not collapse candidate identity: two candidates with identical strategy
thresholds and different indicator fingerprints remain different candidates.

This object is also the natural future input for parallel workers: compute and
validate once, then share or copy the validated feature payload into candidate
evaluation.

## Slice-Aware Warmup And Feature Feasibility

`ledgr_feature_contract_check(snapshot, features)` is intentionally
snapshot-scoped. It answers:

```text
Does this instrument have enough history in the full sealed snapshot?
```

Walk-forward and CSCV/PBO need a different question:

```text
Does this instrument have enough usable history for this evaluation slice?
```

Those are not equivalent. An instrument can have enough history in the full
snapshot while still being unwarmed at the start of a fold. Conversely, a fold
may need pre-slice warmup history that is not part of the scored training or
test interval.

The practical rule is:

```text
scoring/pulse range != warmup lookback range
```

For example, a walk-forward fold scored from 2017-01-01 may need late-2016 bars
to compute `sma_10` at the first scored pulse. Those warmup bars are required
for feature correctness, but they are not part of the fold's scored P&L range.
Any slice-aware design must represent both intervals.

The v0.1.8 design packet must decide how the fold core represents effective
bars available at a slice boundary. This does not require exporting a
slice-aware `ledgr_feature_contract_check()` in v0.1.8, but the internal design
must leave room for one of these patterns:

- an internal `feature_contract_check(snapshot, features, data_slice)`;
- a data-slice object with explicit warmup lookback metadata;
- sealed train/test snapshots for simple holdout workflows plus internal slice
  metadata for walk-forward and PBO/CSCV;
- precomputed feature coverage checks that are aware of both scoring range and
  warmup range.

This is a design decision, not a late implementation detail.

The existing feature cache is a useful building block because its key already
includes `start_ts_utc` and `end_ts_utc` along with snapshot hash, instrument,
indicator fingerprint, and feature-engine version. That makes it range-aware,
but it does not by itself define which range is the scoring range and which
range is the warmup lookback range.

## Evaluation Discipline

Sweep makes selection leakage easier:

```text
full snapshot -> sweep -> pick best params -> committed run on same snapshot
```

The resulting artifact may be perfectly reproducible and still be an in-sample
selection artifact.

The v0.1.8 sweep documentation must teach the manual holdout workflow:

```text
source bars
  -> train snapshot
  -> test snapshot
  -> sweep on train snapshot
  -> lock selected params
  -> evaluate locked params on test snapshot with ledgr_run()
```

`ledgr_snapshot_split()` is useful future UX, but it is not a v0.1.8
prerequisite. Users can already create separate sealed train and test snapshots
by filtering bars before snapshot creation.

## Parallel Sweep Prerequisites

Parallel sweep is not required for the first v0.1.8 sweep release. The
architecture must still avoid choices that make it harder.

Known prerequisites from `inst/design/architecture/sweep_mode_code_review.md`:

1. **Telemetry side-channel removal.**
   `.ledgr_telemetry_registry` is a shared mutable environment keyed by
   `run_id`. It is unsafe for concurrent worker writes. Telemetry should travel
   through the result/output-handler path rather than a package-global
   side-channel.

2. **DuckDB write isolation.**
   Parallel candidates must not write to the same DuckDB file concurrently.
   Future options include per-worker temp databases with orchestrated merge, or
   a serialized write queue. v0.1.8 sequential sweep can defer this, but must
   not deepen the current fold/output coupling.

3. **Feature cache strategy.**
   Two future sharing patterns are plausible:
   - pre-dispatch cache population: compute all shared feature series before
     spawning workers, then distribute via `everywhere()` pre-load (mirai) or
     copy-on-write pages (fork-based backends such as `future::multicore`);
   - explicit shared-memory feature payloads, such as the `mori::share()` /
     `future.mirai::mirai_multisession` pattern sketched in
     `inst/design/architecture/ledgr_sweep_mode_ux.md`.

   The pre-fork copy-on-write pattern applies only to fork-based backends.
   mirai workers are separate processes with no shared heap; the mirai
   equivalent is `everywhere()` pre-population, whose cache-survival semantics
   must be confirmed by SPIKE-5 before the design can rely on it.

   v0.1.8 sequential sweep does not need to choose between these. The common
   requirement is that workers must not concurrently write to session-global R
   environments or shared DuckDB files.

## mirai Process Model Constraints

This section records findings from a focused mirai analysis conducted during
v0.1.7.9. The analysis informs the v0.1.8 spec before the parallel design is
finalized and must be read alongside the platform spike results at
`inst/design/spikes/ledgr_parallelism_spike.md`.

### Workers are separate processes, not threads or forks

mirai workers are separate R processes. Every object that crosses the worker
boundary must be serialized over an NNG socket. There is no shared heap, no
shared R environment, and no shared file handle between the orchestrating
session and any worker. This makes several design choices concrete that were
previously left open.

### Fold core signature must not take a live DuckDB connection

DuckDB connections hold external pointers and cannot be serialized to a worker
process. The fold core must accept either a pre-fetched bar payload (R matrices
or data frames) or a snapshot file path so the worker can open its own
read-only connection locally.

The pre-fetch approach — materialize all required bars before dispatch, send as
plain R objects — is simpler and works for remote workers without filesystem
access to the snapshot file. The path approach requires every worker environment
to have filesystem access to the snapshot. The v0.1.8 spec must choose one; this
is a forced decision before the fold core signature is finalized.

### Dependency classification

**mirai: `Suggests` at most, not `Imports`.**
Parallel sweep is optional; sequential sweep must work without mirai installed.
mirai's NNG-backed socket infrastructure has platform-specific build
requirements that must not gate `library(ledgr)`. Whether mirai reaches
`Suggests` is conditional on SPIKE-1 confirming reliable daemon lifecycle on
Windows (native) and Ubuntu/WSL.

**mori: not a declared dependency until cross-process serialization is
verified.**
The UX doc states that mori objects are "indistinguishable from plain R objects
at the API boundary." This holds at the ledgr API surface but may not hold at
mirai's NNG serialization layer. mori objects backed by external shared-memory
pointers require either a confirmed native serialization path or explicit
`register_serial()` registration in mirai's serialization registry. This is
unverified. Until SPIKE-3 confirms the cross-process behavior on both platforms,
mori is documented as an optional user-managed pattern only, not a `Suggests`
dependency.

### Per-candidate seed derivation

mirai daemons support L'Ecuyer-CMRG independent random streams via
`daemons(n, seed = L)`. The current fold core calls `set.seed(runtime_seed)`
unconditionally at entry, which overrides the daemon's stream and breaks the
reproducibility guarantee in a parallel context.

For parallel sweep, the fold core must accept a per-candidate seed derived from
`(master_seed, candidate_label)` and apply it explicitly, rather than calling
`set.seed()` globally at entry. The roadmap's per-candidate seed design —
derive from candidate label when `seed = NULL` — is compatible with this
requirement. The implementation must pass the derived seed into the fold core
explicitly.

### Feature cache cross-task survival

mirai's `cleanup = TRUE` (default) restores the global R environment after each
task. Package-level environments (created at load time and stored in a package
binding) are generally not affected by this cleanup and persist across tasks
within the same daemon's lifetime.

If `.ledgr_feature_cache_registry` survives between tasks on the same daemon,
candidates sharing feature configurations (the common case in a param grid) will
reuse cached feature series without resending the payload per task. This is the
"daemon cache warming" optimization.

**This must be verified by SPIKE-5 before the parallel design relies on it.**
If cleanup wipes package-level environments, the optimization does not exist
and precomputed feature payloads must be pre-loaded via `everywhere()` at daemon
startup or resent with each task.

### Partial result collection on interrupt

mirai's `x[.progress]` blocks until all tasks complete and does not return
partial results on Ctrl-C. The interrupt semantics requirement — return a classed
partial `ledgr_sweep_results` object on user interrupt — requires a polling loop
over `unresolved()` rather than delegating to mirai's built-in collection:

```r
# pattern only
while (any(vapply(tasks, unresolved, logical(1)))) {
  newly_done <- !vapply(tasks, unresolved, logical(1)) & !already_collected
  completed <- c(completed, tasks[newly_done])
  already_collected[newly_done] <- TRUE
  Sys.sleep(poll_interval)
}
```

The v0.1.8 spec must decide between this pattern and discarding in-flight
results on interrupt (see Design Checklist item 26). The architecture
recommendation is to return a classed partial `ledgr_sweep_results` object with
completed candidates marked clearly as partial and in-flight candidates
discarded; if the v0.1.8 spec rejects that direction, it must explicitly choose
discard-all semantics instead.

### Telemetry side-channel failure mode

The code review correctly flags `.ledgr_telemetry_registry` as unsafe for
parallel sweep. In mirai specifically, the failure mode is different from
fork-based parallelism: each daemon is an isolated process with its own copy of
the registry, so cross-worker contamination of registry entries cannot occur.
The actual failure is that `write_persistent_telemetry` and `fail_run` capture
a DuckDB `con` from the outer runner frame, which cannot cross the process
boundary. The worker errors before telemetry corruption is possible. The
fold/output-handler split resolves both the fork-model concern and the
mirai-model concern through the same refactor.

## Memory And Interrupt Semantics

Summary-only sweep output limits the size of the returned result object, but it
does not eliminate in-flight memory pressure during evaluation. The current
`audit_log` path buffers data proportional to pulses and universe size. Large
grids multiply that pressure across candidates, and future parallel execution
multiplies it across workers. v0.1.8 does not need a full memory model, but the
spec should state the expected peak-memory behavior for sequential sweep and
avoid retaining full event streams by default.

Long sweeps also need explicit interrupt semantics. The v0.1.8 spec should
return a classed partial `ledgr_sweep_results` object on `Ctrl-C` / user
interrupt after collecting completed candidates and discarding in-flight
candidates. The object must be marked partial in class, metadata, and print
output so an incomplete sweep is never presented as complete. If this proves too
complex for v0.1.8, the spec must explicitly choose discard-all semantics
instead of leaving interrupt behavior accidental.

## Roadmap Placement

| Milestone | Scope |
|---|---|
| v0.1.8 | Fold core/output-handler split; private fill-timing/cost-resolution boundary; sequential `ledgr_sweep()` as modular evaluation primitive; evaluation-discipline docs with manual holdout workflow |
| v0.1.9 | Risk layer; `ledgr_snapshot_split()` once sweep UX is stable |
| v0.1.9 or v0.2.x | `ledgr_walk_forward()` built on sweep plus run |
| v0.1.9.x or v0.2.x | Public cost-model API after risk/function identity work stabilizes |
| later | PBO/CSCV diagnostic; parallel sweep after telemetry and DuckDB write isolation are solved |

## Non-Goals For v0.1.8

- No walk-forward API.
- No PBO/CSCV API.
- No required `ledgr_snapshot_split()` helper.
- No mandatory parallel sweep.
- No persisted feature-series retrieval API.
- No new execution semantics that differ from `ledgr_run()`.
- No exported cost-model factories.
- No exchange or broker fee templates.
- No market-impact models.
- No liquidity clipping, partial-fill, or volume-participation model.
- No separate sweep execution grid for cost assumptions.

## Design Checklist For The v0.1.8 Spec

Before v0.1.8 tickets are cut, the spec must answer:

1. What is the fold-core boundary?
2. What is the output-handler boundary?
3. What exact candidate summary fields does sweep always keep?
4. How does a user promote a sweep candidate to a committed `ledgr_run()`?
5. What is the default objective, and how can it be replaced?
6. What does the objective receive as input?
7. How are candidate errors represented?
8. How are strategy preflight results recorded in sweep output?
9. Where does preflight live: fold setup, separate pre-fold gate, or output
   handler input?
10. How are objective errors represented, and are they distinct from
    strategy-execution errors?
11. What is the sweep result's evaluation-scope label: exploratory, in-sample,
    holdout, committed, or unlabeled?
12. What date/slice assumptions are hard-coded in v0.1.8, and which are left
   deliberately flexible?
13. How are scoring range and warmup lookback range represented separately?
14. How will slice-aware warmup checks be represented later?
15. How does `ledgr_precompute_features()` validate snapshot, universe, feature,
    and date/slice identity?
16. How are indicator-parameter sweeps represented: candidate params,
    feature-factory evaluation, per-candidate feature fingerprints, and
    candidate-specific warmup feasibility?
17. How does the fold core separate next-open fill timing from cost resolution
    without changing current spread/commission behavior?
18. What typed internal fields does `ledgr_fill_proposal` carry?
19. What fields are available in `fill_context`, and how is it kept separate
    from the no-lookahead strategy `ctx`?
20. What parity assertions prove the internal cost-boundary refactor is
    behavior-preserving: fill prices, fees, cash deltas, ledger rows, equity
    curves, metrics, comparison outputs, and `config_hash` values?
21. Which current runner closures and telemetry side channels must move into
    output-handler responsibility?
22. What does the parity test suite cover, including at least one candidate
    grid where params change the registered feature set?
23. What parallel prerequisites are explicitly deferred?
24. Does strategy preflight run once per sweep or once per candidate, and under
    what future API would that change?
25. What are the memory expectations for large sequential sweeps?
26. What are the interrupt semantics, and are partial results returned or
    discarded?
27. Before locking in the once-per-sweep preflight contract: does
    `ledgr_strategy_preflight()` inspect feature definitions or candidate-varying
    referenced symbols, or does it classify only the strategy function body and
    its non-candidate-specific environment? If preflight is not strategy-body-only,
    it must run once per candidate.
28. Where does per-candidate seed derivation happen: inside the fold core, in the
    sweep dispatcher before dispatch, or in the output handler? This determines
    whether `ctx$seed` comes from the fold-core input signature directly or is
    injected by the sweep layer. The spec must state the derivation boundary
    explicitly.
29. What is the write-isolation pattern for future parallel sweep: per-worker temp
    databases with orchestrated merge, or a serialized write queue? No spike covers
    this; the v0.1.8 spec must take a position from first principles, even if
    parallel write isolation itself is deferred.
