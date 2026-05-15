# RFC: Sweep Single-Core Optimization Routes

**Status:** Draft RFC for Claude review.  
**Date:** 2026-05-15  
**Author:** Codex  
**Related documents:**

- `inst/design/audits/sweep_performance_measurement.md`
- `inst/design/audits/sweep_hot_path_profile.md`
- `dev/spikes/ledgr_sweep_performance/run_benchmark.R`
- `dev/spikes/ledgr_sweep_performance/profile_hot_path.R`
- `inst/design/ledgr_v0_1_8_spec_packet/v0_1_8_spec.md`
- `inst/design/ledgr_v0_1_8_spec_packet/v0_1_8_tickets.md`
- `R/fold-core.R`
- `R/sweep.R`
- `R/backtest-runner.R`
- `R/pulse-context.R`

---

## Purpose

LDG-2108 replaced the rejected ephemeral-DuckDB sweep implementation with a
memory-backed sweep path that shares the same private fold core as
`ledgr_run()`. LDG-2108A then measured only a modest speedup over a persistent
`ledgr_run()` loop, and LDG-2108B profiled where the remaining time goes.

This RFC asks Claude to review the optimization routes now visible from those
measurements and help decide what should happen next:

1. leave all optimization out of v0.1.8;
2. cut a small low-risk optimization ticket before `LDG-2109`;
3. park all optimization in `horizon.md`;
4. promote one or more routes into the roadmap after the v0.1.8 sweep/promotion
   contract is stable.

The default Codex recommendation is still conservative: **do not optimize before
`LDG-2109` unless Claude identifies a small isolated fix with very low parity
risk.**

---

## Evidence Baseline

### LDG-2108A Result

The memory-backed sweep path is faster than a persistent run loop, but not by an
order of magnitude.

| Scenario | Candidates | Plain sweep | `ledgr_run()` loop | Speedup |
|---|---:|---:|---:|---:|
| Small | 5 | 2.97s | 5.13s | 1.73x |
| Local | 50 | 26.67s | 45.25s | 1.70x |

With precomputed features:

| Scenario | Precompute + sweep | Speedup vs run loop |
|---|---:|---:|
| Small | 2.88s | 1.78x |
| Local | 28.22s | 1.60x |

This tells us that removing persistent run writes is valuable, but not the main
remaining single-core bottleneck.

### LDG-2108B Profile

The 50-candidate memory sweep profile showed:

| Phase | Calls | Elapsed | Share |
|---|---:|---:|---:|
| `ledgr_sweep_run_candidate()` | 50 | 27.85s | 97.0% |
| `ledgr_execute_fold()` | 50 | 18.30s | 63.8% |
| `ledgr_equity_from_events()` | 50 | 5.73s | 20.0% |
| `ledgr_fills_from_events()` | 50 | 3.11s | 10.8% |
| Feature matrix build | 50 | 0.05s | 0.2% |
| Feature resolution | 1 | 0.09s | 0.3% |

`Rprof()` pointed to repeated R object churn rather than a single arithmetic
kernel:

- `ledgr_update_pulse_context_helpers()`
- `ledgr_attach_feature_helpers()`
- `ledgr_features_wide()`
- `data.frame()`
- `$<-.data.frame`
- `as.data.frame()`
- `%in%`
- `deparse()`
- `format.POSIXlt()`
- `rbind()`
- list/data-frame indexing

The profile shows two broad buckets:

1. **Fold-core churn:** roughly 64% of sweep runtime.
2. **Post-fold reconstruction:** roughly 31%-33% of sweep runtime.

---

## Important Clarification: These Are Not Sweep-Only Inefficiencies

### Fold-Core Churn Is Fully Shared

`ledgr_execute_fold()` is called by both paths:

- persistent `ledgr_run_fold()`;
- memory-backed `ledgr_sweep_run_candidate()`.

The per-pulse work inside `ledgr_execute_fold()` is therefore common:

- build/update `bars_current`;
- build/update `features_current`;
- compute positions/equity for the decision-time context;
- build a `ledgr_pulse_context`;
- attach helpers via `ledgr_update_pulse_context_helpers()`;
- run strategy;
- validate targets;
- resolve fills and mutate state.

Any fold hot-path improvement benefits both `ledgr_run()` and `ledgr_sweep()`.
The cost is only more visible in sweep because 50 candidates pay it back to back.

### Post-Fold Reconstruction Exists In Both Paths

The persistent path also reconstructs derived state after the fold. In
`backtest-runner.R`, after `ledgr_execute_fold()` completes, persistent
`ledgr_run()`:

- reads events back from DuckDB;
- parses `meta_json`;
- applies lot accounting;
- builds `equity_curve`;
- writes `equity_curve` back to DuckDB;
- later, `ledgr_extract_fills()` separately replays `ledger_events` to derive
  fills/trades.

The memory sweep path does:

- `ledgr_equity_from_events()`;
- `ledgr_fills_from_events()`;
- `ledgr_metrics_from_equity_fills()`.

It avoids DuckDB read/write round trips, but still replays events and parses
`meta_json`. It also replays the event stream twice: once for equity and once
for fills.

So the reconstruction inefficiency is general. The persistent path may pay more
I/O and serialization overhead, while the memory path exposes the pure-R replay
cost more directly.

---

## Optimization Routes

### Route A: Do Nothing In v0.1.8

Keep the v0.1.8 release focused on:

- stable `ledgr_sweep()` output shape;
- provenance;
- candidate selection;
- promotion context;
- semantic parity;
- documentation.

Park the measured performance findings in `horizon.md`.

**Pros**

- Lowest release risk.
- Preserves focus on correctness and UX.
- Avoids perturbing the fold core before parity gates.

**Cons**

- Leaves known single-core inefficiencies in place.
- Users may perceive sweep as slower than expected.
- Future optimization work will need another focused cycle.

**Codex view**

This is the safest default unless a route below has a very small blast radius.

---

### Route B: Fast Sweep Pulse Context Path

The profile suggests a large share of fold time is spent building data-frame
views and helper structures every pulse.

Current pattern inside `ledgr_execute_fold()`:

- mutate `bars_df`;
- mutate `features_df`;
- call `ledgr_update_pulse_context_helpers()`;
- call `ledgr_attach_feature_helpers()`;
- rebuild `features_wide`;
- attach `ctx$feature`, `ctx$features`, `ctx$bar`, `ctx$close`, etc.

Potential improvement:

- add an internal fast context path for sweep/persistent run;
- precompute stable helper closures once;
- update a small lookup environment each pulse;
- make `ctx$feature()` read directly from `run_feature_matrix` using pulse index,
  instrument index, and feature ID;
- avoid rebuilding `features_wide` unless a user explicitly asks for wide
  feature tables.

This aligns with the current `use_fast_context` field already present in the
fold execution list, but currently not used by `ledgr_execute_fold()`.

**Pros**

- Attacks the largest measured bucket.
- Benefits both `ledgr_run()` and `ledgr_sweep()`.
- Keeps single execution core.

**Cons**

- High semantic risk: strategy context is public-facing.
- Must preserve `ctx$bars`, `ctx$feature_table`, `ctx$features_wide`,
  `ctx$feature()`, `ctx$features()`, `ctx$bar()`, `ctx$flat()`, `ctx$hold()`.
- Must be tested against existing strategy/indicator docs and no-lookahead
  semantics.
- Could accidentally expose mutable internal state to strategies.

**Possible safe subset**

Only avoid rebuilding `features_wide` unless accessed. Make it lazy:

- `ctx$features_wide` becomes either a delayed field or helper-backed accessor;
- `ctx$feature()` remains fast path over `features_current`;
- public surface remains equivalent.

But R list fields are not naturally lazy without active bindings or an
environment-backed context, both of which need careful API compatibility review.

**Codex view**

High payoff, but not a v0.1.8 quick fix unless Claude sees a narrow safe entry
point. Better as a post-v0.1.8 profiling/optimization ticket.

---

### Route C: Single-Pass Event-Derived Summary

Sweep currently computes summary metrics through:

```text
events -> ledgr_equity_from_events()
events -> ledgr_fills_from_events()
equity + fills -> ledgr_metrics_from_equity_fills()
```

This replays the event stream twice and parses `meta_json` repeatedly.

Potential improvement:

- introduce one internal replay helper:

```text
ledgr_replay_events_summary(events, pulses, close_mat, initial_cash, instruments)
  -> list(equity, fills, metrics)
```

or a narrower sweep helper:

```text
ledgr_sweep_summary_from_events(...)
```

The helper would:

- parse each event's metadata once;
- apply lot accounting once;
- build equity and fill summary in one pass where possible;
- return the existing equity/fill/metric shapes required by tests.

**Pros**

- Attacks 31%-33% of measured sweep runtime.
- Mostly internal to post-candidate materialization.
- Lower risk than changing strategy context.
- Can be parity-tested directly against current `ledgr_equity_from_events()` +
  `ledgr_fills_from_events()` + `ledgr_metrics_from_equity_fills()`.

**Cons**

- Still touches accounting and lot semantics.
- Care required for opening-position `CASHFLOW`, partial fills, realized/unrealized
  PnL, fees, final-bar behavior, and empty-event cases.
- If used only by sweep, may create another accounting path unless explicitly
  tested as equivalent.

**Codex view**

This is the most plausible first optimization route after v0.1.8 parity is
stable. It is more bounded than context refactoring and directly supported by
the profile.

---

### Route D: Typed In-Memory Events Instead Of `meta_json`

The memory output handler owns the events before they become durable rows. Today
it stores row-shaped objects including `meta_json`, then later parses that JSON
again.

Potential improvement:

- memory handler stores typed event objects with fields:
  - `cash_delta`;
  - `position_delta`;
  - `realized_pnl`;
  - `opening_position`;
  - `cost_basis`;
  - event type, side, qty, price, fee, event seq, timestamp.
- persistent handler still serializes to `meta_json`;
- sweep summary replay consumes typed memory events directly;
- conversion to durable row shape happens only when needed.

**Pros**

- Removes JSON serialization/deserialization from sweep hot path.
- Makes memory-mode semantics explicit.
- Could feed Route C's single-pass summary helper.

**Cons**

- Risk of divergence between typed memory events and durable ledger rows.
- Must prove typed events and `meta_json` rows are semantically identical.
- Requires careful event schema/version thinking.

**Codex view**

Good direction, but should follow or pair with Route C. Do not do this casually
inside v0.1.8 unless required for promotion context correctness, which it is not.

---

### Route E: Reuse Persistent Path's Vectorized Equity Reconstruction

The persistent path already does some optimized reconstruction:

- parse `meta_json` once into arrays;
- compute `cash_at` with `findInterval()`;
- compute instrument positions with per-instrument cumulative sums;
- compute `positions_value` via `colSums(positions_mat * close_mat)`.

The memory path's `ledgr_equity_from_events()` currently uses a more direct loop
over pulses and events.

Potential improvement:

- extract the persistent vectorized equity reconstruction into a DB-free helper;
- make both persistent and sweep paths call it;
- feed it either DB-loaded event rows or memory event rows.

**Pros**

- Reuses an existing algorithm.
- Improves sweep equity reconstruction and reduces duplicate code.
- Can also simplify persistent runner post-fold code.

**Cons**

- Persistent path reconstruction includes details coupled to DB-loaded row
  shape.
- Does not solve fills/trades replay.
- Still parses `meta_json` unless combined with typed metadata.

**Codex view**

This is attractive as a refactor route if we want to improve both paths without
changing fold behavior. It should be evaluated against Route C: single-pass
summary may be cleaner for sweep, while extracted vectorized equity may be
cleaner for shared persistent/sweep reconstruction.

---

### Route F: Summary Metrics From Fold State Without Event Replay

The fold already knows state transitions as they happen:

- cash;
- positions;
- fill side/qty/price/fee;
- event sequence;
- decision timestamp;
- execution timestamp.

Potential improvement:

- memory output handler accumulates enough summary state during fold execution
  to compute final equity, trade count, win rate, exposure, and risk metrics
  without replaying event rows after the candidate.

**Pros**

- Potentially avoids most post-fold reconstruction.
- Could produce sweep summaries faster.

**Cons**

- High risk of producing metrics by a different path than durable ledgers.
- Could undermine the event-sourced design.
- Hard to preserve full parity for realized/unrealized PnL and closed-trade
  semantics.
- Likely needs duplicate accounting state inside the output handler.

**Codex view**

Not recommended unless the event replay path remains the authoritative parity
oracle and this becomes a carefully verified cache. Too risky for v0.1.8.

---

### Route G: Feature Matrix Cache By `feature_set_hash`

The original performance hypothesis suspected repeated feature construction.
LDG-2108B did not support that hypothesis for the benchmark: feature matrix
build/hydration was near zero.

Still, for heavier indicators and larger universes, caching candidate feature
matrices by `feature_set_hash` may matter.

Potential improvement:

- inside `ledgr_sweep()`, maintain an internal cache:

```text
feature_set_hash -> run_feature_matrix
```

- candidates with identical feature sets reuse the same matrix;
- precomputed-feature path can similarly cache hydrated matrices.

**Pros**

- Conceptually simple.
- Helps grids with many strategy parameter changes but few feature parameter
  changes.
- Low semantic risk if keyed by candidate-specific feature fingerprints/hash.

**Cons**

- Not useful in the measured benchmark.
- Memory use can rise with large feature sets.
- Cache invalidation must include feature fingerprints, universe, date range,
  and feature engine version.

**Codex view**

Probably a good future optimization, but not the first route based on current
evidence.

---

### Route H: Rcpp/Fortran Kernel

Candidate targets:

- event replay / equity reconstruction;
- position valuation;
- maybe target delta/fill loops.

Fortran is a poor fit for metadata-heavy, branchy event semantics. Rcpp is more
realistic.

**Pros**

- Can speed up tight loops once the input representation is numeric/typed.
- Could help very large event streams.

**Cons**

- Adds compiled-code/toolchain complexity.
- Risks creating a second accounting implementation.
- Hard to handle `meta_json`, POSIX time, arbitrary event metadata, and FIFO lot
  state cleanly without first making the R-side replay contract typed and pure.
- CRAN/build complexity increases.

**Codex view**

Do not start here. First make the replay input typed and the replay contract
single-pass/pure. If profiling still points to a narrow numeric kernel, then
consider Rcpp. Fortran is not a good match.

---

### Route I: Parallel Candidate Dispatch

Parallelism is already parked for after sequential sweep is stable.

**Pros**

- Candidate evaluations are naturally isolated.
- Existing parallelism spike suggests `mirai` is viable as an optional backend.
- Can deliver large wall-clock gains without changing single-candidate
  semantics.

**Cons**

- Requires worker setup, dependency handling, transport choices, interrupt
  semantics, and result collection design.
- Does not reduce total CPU cost.
- Should not ship before sequential sweep/provenance/promotion semantics are
  stable.

**Codex view**

Likely the most impactful wall-clock route later, but not a substitute for
cleaning up avoidable single-core churn.

---

## Comparative Summary

| Route | Likely payoff | Risk | Benefits `ledgr_run()` | Benefits sweep | v0.1.8 candidate? |
|---|---:|---:|---:|---:|---|
| A: Do nothing | 0 | Low | No | No | Yes |
| B: fast pulse context | High | High | Yes | Yes | Probably no |
| C: single-pass event summary | Medium | Medium | Maybe | Yes | Probably no |
| D: typed memory events | Medium | Medium | Maybe | Yes | Probably no |
| E: extract vectorized equity replay | Medium | Medium | Yes | Yes | Maybe later |
| F: metrics from fold state | Medium | High | Maybe | Yes | No |
| G: feature matrix cache | Workload-dependent | Low-Medium | No | Yes | Maybe later |
| H: Rcpp/Fortran | Unknown | High | Maybe | Maybe | No |
| I: parallel dispatch | High wall-clock | High | No | Yes | No |

---

## Codex Recommendation

For v0.1.8:

1. **Do not optimize before `LDG-2109`.**
2. Continue with sweep result/provenance/promotion work.
3. Keep the LDG-2108A/2108B findings in `horizon.md`.

After v0.1.8 parity and promotion are stable:

1. First consider **Route C** or **Route E**:
   - bounded post-fold reconstruction improvement;
   - easier to test against existing outputs than changing strategy context.
2. Then consider **Route B**:
   - biggest measured bucket;
   - benefits both `ledgr_run()` and `ledgr_sweep()`;
   - but requires careful public context compatibility tests.
3. Defer **Route H** until the replay contract is typed and pure.
4. Keep **Route I** on the roadmap as the main wall-clock scaling route.

---

## Questions For Claude

1. Do you agree that these inefficiencies are general, not sweep-specific?
2. Is Route C, Route E, or Route B the best first post-v0.1.8 optimization
   route?
3. Is there a very small, low-risk subset of Route B that should be considered
   before `LDG-2109`, or should all optimization wait?
4. Should typed in-memory events be introduced before single-pass summary
   replay, or only as part of it?
5. Is any Rcpp work justified before the replay/context contracts are made
   cleaner, or should compiled code remain off the table for now?
