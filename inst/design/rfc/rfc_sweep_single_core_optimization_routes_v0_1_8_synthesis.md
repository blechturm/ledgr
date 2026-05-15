# RFC Synthesis: Sweep Single-Core Optimization Routes

**Status:** Synthesis after Claude response and maintainer discussion.  
**Date:** 2026-05-15  
**Thread:**

- `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8.md`
- `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_response.md`
- `inst/design/audits/sweep_performance_measurement.md`
- `inst/design/audits/sweep_hot_path_profile.md`

---

## Decision Summary

Finish **v0.1.8.0** as planned. Do not add optimization work before
`LDG-2109`.

The optimization findings are real, but they should become **v0.1.8.x**
follow-up work after the first sweep contract ships. v0.1.8.0 must stabilize:

- sequential `ledgr_sweep()`;
- classed sweep result shape;
- execution seeds;
- row-level provenance;
- candidate selection;
- promotion context;
- semantic parity with `ledgr_run()`.

Optimization before these surfaces are stable would create avoidable parity and
API risk.

---

## What We Learned

LDG-2108A measured the memory-backed sweep implementation against the practical
baseline of calling `ledgr_run()` once per candidate. The speedup was real but
modest: roughly **1.6x-1.8x** on the 50-candidate EOD benchmark.

LDG-2108B showed why. The remaining cost is not primarily DuckDB persistence or
feature precompute. It is:

1. **Fold-core pulse-context churn**: about two thirds of measured sweep time.
2. **Post-candidate event-derived reconstruction**: about one third of measured
   sweep time.

These costs are not sweep-specific. They are general ledgr execution costs:

- `ledgr_execute_fold()` is shared by `ledgr_run()` and `ledgr_sweep()`;
- the per-pulse context work is paid by every `ledgr_run()`, just less visibly;
- persistent `ledgr_run()` also reconstructs derived state from events after the
  fold, with additional DuckDB I/O and JSON parsing.

Therefore, future optimization work improves `ledgr_run()` and `ledgr_sweep()`
together where it touches the shared fold core.

---

## Clarified Bottlenecks

### Fold-Core Churn

The current fold creates and updates substantial R object structure on every
pulse:

- `bars_current`;
- `features_current`;
- `ctx` as a fresh list;
- lookup environment;
- helper closures;
- feature accessor construction;
- `features_wide`;
- public helper fields such as `ctx$feature`, `ctx$features`, `ctx$flat`,
  `ctx$hold`, and bar accessors.

The causal chain matters for the future B1 ticket:

```text
fresh ctx list each pulse
  -> ctx$.pulse_lookup is NULL
  -> ledgr_ensure_pulse_context_accessors() allocates a new lookup env
  -> ledgr_ensure_pulse_context_accessors() constructs 11 helper closures
```

Even if a lookup environment already existed, the helper function currently
constructs the closures unconditionally on each call. The intended B1 fix is not
only "reuse closures"; it is "reuse the ctx lookup environment and helper
closures across pulses within a candidate fold, and mutate only the lookup
values and pulse-specific scalar fields."

The same churn applies to feature helper construction. `ledgr_attach_feature_helpers()`
constructs a new `ctx$feature` accessor each pulse, and
`ledgr_feature_accessor()` recomputes `available_features` through
`ledgr_feature_names()`. `ledgr_feature_bundle_accessor()` constructs another
feature accessor internally. B1 should include this accessor construction in the
lookup/closure reuse target list.

Claude's review identified an important detail: `use_fast_context` already
exists in the execution list, and the older runner path has partial proxy
structures, but `ledgr_execute_fold()` ignores the flag. This is a dead
optimization scaffold, not a completed feature.

The likely future fix is to initialize the lookup environment and helper
closures once per candidate fold, then mutate lookup values per pulse.

### Eager `features_wide`

`ledgr_features_wide()` is called on every pulse even when a strategy only uses
`ctx$feature()` and never accesses `ctx$features_wide`.

This is measurable overhead, but making `features_wide` lazy is API-sensitive.
It likely requires either active bindings or changing `ctx$features_wide` from a
field to a function, which is a public context-contract decision. It should not
be slipped into an optimization patch.

### Post-Fold Reconstruction

The memory sweep path currently does:

```text
events -> ledgr_equity_from_events()
events -> ledgr_fills_from_events()
equity + fills -> ledgr_metrics_from_equity_fills()
```

This means:

- the event stream is sorted exactly twice, and both sorts are redundant because
  events arrive from the fold in monotonically increasing `event_seq` order;
- `meta_json` is parsed more than once;
- lot/accounting replay is done more than once.

The future single-pass helper must not merely "sort once instead of twice." It
should consume the already-ordered event stream, assert or document the ordering
contract, parse metadata once, and thread one shared `ledgr_lot_state()` through
both equity and fill/trade accumulation.

The two current replay helpers use lot state for different outputs:

- `ledgr_equity_from_events()` uses lot state for per-pulse realized/unrealized
  PnL and position tracking;
- `ledgr_fills_from_events()` uses lot state for per-fill realized PnL
  attribution.

A single-pass helper has to preserve both outputs while avoiding duplicate lot
state replay.

The JSON round-trip starts inside the fold: memory events are created as row
objects with `meta_json` strings, then parsed back into R lists for
reconstruction. A better future design keeps typed memory events typed from
creation through summary reconstruction, while the persistent handler continues
to serialize to durable `meta_json` rows.

### Persistent And Memory Reconstruction Semantics

There is one semantic precondition for any v0.1.8.x D+C design: persistent and
memory reconstruction use different implementation shapes, and parity must
explicitly cover their derived accounting columns.

The persistent path in `backtest-runner.R` reconstructs equity with a vectorized
`findInterval + cumsum` approach over stored `cash_delta` and `position_delta`
arrays. This is used for:

```text
equity = cash + positions_value
```

The same persistent reconstruction block also runs a FIFO lot-accounting replay
with `ledgr_lot_apply_event()` to derive `realized_pnl` and cost-basis state.

The memory path's `ledgr_equity_from_events()` does call
`ledgr_lot_apply_event()` per event and derives realized/unrealized PnL through
FIFO lot state.

So the current issue is not a confirmed semantic divergence. The issue is that
the same derived accounting outputs are produced by separate implementations.
Before designing the typed single-pass summary helper, ledgr must make the
authoritative semantics explicit: `realized_pnl` and `unrealized_pnl` should be
defined by FIFO lot-tracking state, and any vectorized cash/position machinery
must remain a performance technique that preserves those lot-derived outputs.

LDG-2112 parity tests should explicitly compare `realized_pnl` and
`unrealized_pnl` columns between `ledgr_run()` and sweep candidate replay, not
only final equity or total return.

---

## Release-Line Placement

This work belongs in **v0.1.8.x**, not v0.1.9.

Reason: the optimization work is sweep/fold-engine work. v0.1.9 is reserved for
the target-risk layer and should not inherit sweep-performance debt unless the
optimization directly depends on risk semantics.

Recommended release arc:

```text
v0.1.8.0
  Baseline sequential sweep, provenance, promotion, parity.

v0.1.8.1
  Typed memory events + single-pass sweep summary reconstruction.

v0.1.8.2
  Fast context scaffold via use_fast_context, starting with lookup/closure
  initialization once per fold.

v0.1.8.3+
  Optional broader fast-context work, feature payload/cache improvements, or
  parallel-readiness refinements.

v0.1.9
  Target risk layer.
```

This is a proposed arc, not an already-ticketed plan. It should be specified in
the roadmap and cut into versioned tickets only after v0.1.8.0 ships.

---

## Recommended Optimization Order

### First: Typed Memory Events + Single-Pass Summary

This combines RFC Route D and Route C.

Goal:

- eliminate memory-mode JSON round-trip;
- avoid sorting the event stream more than once;
- avoid parsing the same event metadata twice;
- compute equity/fills/metrics from one typed replay pass where possible.

Why first:

- does not touch the strategy-facing context contract;
- directly addresses 31%-33% of measured sweep time;
- can be parity-tested against the existing reconstruction helpers;
- improves memory sweep without changing the strategy context contract.

Design constraint:

- must reconcile the existing persistent and memory reconstruction
  implementations and avoid adding a third accounting semantics path;
- typed memory events and durable `meta_json` rows must be proven equivalent.
- must resolve the persistent-path vs memory-path realized/unrealized PnL
  parity question before implementation.
- must treat the fold-to-memory-handler buffer contract as a real interface
  change, not a small local helper swap.

Expected change surface:

- `ledgr_fill_event_row()` or an adjacent typed-event constructor;
- `ledgr_opening_position_event_rows()` or an adjacent typed-opening-event
  constructor;
- memory output handler `buffer_event()` / `append_event_rows()` contract;
- persistent handler serialization to durable `meta_json` rows;
- replacement or bypass path for `ledgr_equity_from_events()`;
- replacement or bypass path for `ledgr_fills_from_events()`;
- `ledgr_sweep_run_candidate()` summary materialization.
- persistent post-fold reconstruction if v0.1.8.x chooses to unify both
  implementations in the same ticket; otherwise document the transition state
  and require parity tests before migration.

### Second: Fast Context B1

Use the existing `use_fast_context` scaffold as the activation mechanism.

Goal:

- initialize lookup environment once per candidate fold;
- initialize helper closures once per candidate fold;
- compute stable instrument/bar indexes once;
- update mutable lookup values per pulse.

Why second:

- targets the largest measured bucket;
- benefits both `ledgr_run()` and `ledgr_sweep()`;
- lower risk than changing `features_wide` API;
- still needs LDG-2112 parity tests before activation.

`use_fast_context` must remain `FALSE` in both paths until LDG-2112 exists and
passes. Activating the scaffold before parity gates would make correctness
drift difficult to detect.

### Third: Fast Context B2

Activate list-backed bars/features proxy structures after B1 is stable.

Goal:

- reduce `$<-.data.frame` churn in the per-pulse loop;
- keep public strategy behavior equivalent.

Why third:

- likely useful;
- more invasive than B1;
- should be gated on B1 results and parity tests.

### Separate Design: Lazy `features_wide`

Do not bundle this with B1/B2.

Reason:

- `ctx$features_wide` is part of strategy-facing context behavior;
- laziness may require active bindings or a field/function API decision;
- this should go through a design note or RFC before implementation.

### Later: Parallel Dispatch

Parallel dispatch remains the major wall-clock multiplier. It should come after
the sequential sweep contract is stable and preferably after at least B1 reduces
single-candidate overhead.

B1 is not an architectural prerequisite for parallelism. Candidate isolation is
already the key architectural prerequisite. B1 only makes each worker's unit of
work cheaper, so it is a scheduling preference rather than a hard dependency.

### Last: Rcpp

Rcpp is not justified now. The current bottleneck is R object allocation,
closure creation, data-frame churn, and metadata handling, not a clean numeric
kernel. Reconsider compiled code only after typed replay and fast context work
leave a narrow numerical bottleneck.

Fortran is not a good fit for the current bottlenecks.

---

## DuckDB's Future Role

DuckDB should remain a static preparation engine, not the sweep runtime.

Useful future DuckDB work:

- sort bars once;
- validate calendars;
- optionally assign stable integer pulse/instrument IDs if a future fast context
  or compiled kernel needs O(1) integer-index lookup instead of string matching;
- continue using `ledgr_precompute_features()` as the ordered feature-payload
  preparation path, and strengthen it only where future profiles justify it;
- precompute coverage metadata;
- create compact matrices/tables for R to consume.

Avoid:

- querying DuckDB every pulse;
- writing temporary candidate runs;
- using DuckDB as hidden sweep execution state.

The useful boundary is:

```text
DuckDB/snapshot/precompute:
  prepare static, ordered, indexed payloads

R fold:
  execute candidate semantics on that payload without DB round-trips
```

Snapshot generation may eventually expose stable static indexing metadata, but
runtime context lookup should remain a fold responsibility because cash,
positions, equity, strategy state, and candidate-specific features are runtime
state.

---

## Final Recommendation

For the current cycle:

1. Commit LDG-2108A/LDG-2108B evidence.
2. Continue with `LDG-2109`.
3. Do not add optimization work to v0.1.8.0.

For future v0.1.8.x:

1. Cut a design/implementation ticket for typed memory events plus single-pass
   summary reconstruction.
2. Then cut a fast-context ticket using the `use_fast_context` scaffold.
3. Treat lazy `features_wide` as a separate API-design issue.
4. Keep Rcpp and parallel dispatch deferred until the sequential contract is
   stable and the R-level bottlenecks are better isolated.
