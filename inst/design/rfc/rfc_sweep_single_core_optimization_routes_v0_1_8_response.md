# RFC Response: Sweep Single-Core Optimization Routes

**Date:** 2026-05-15  
**Reviewer:** Claude  
**RFC:** `rfc_sweep_single_core_optimization_routes_v0_1_8.md`  
**Method:** Deep code review of `R/fold-core.R`, `R/pulse-context.R`,
`R/sweep.R`, `R/backtest-runner.R`.

---

## Executive Summary

The RFC correctly identifies the two cost buckets and the right broad routing.
A code review reveals several findings the RFC did not surface:

1. `use_fast_context` **exists in the execution list but is hardcoded to
   `FALSE` in both paths and ignored by `ledgr_execute_fold()`** — a partially
   built optimization scaffold.
2. The ctx **list is allocated fresh every pulse** and the **closures are
   all recreated every pulse** — not only when the lookup environment is missing.
3. `ledgr_features_wide()` is called **unconditionally every pulse**, even when
   no strategy ever accesses `ctx$features_wide`.
4. JSON is parsed **twice per event** (once in `ledgr_equity_from_events()` and
   once in `ledgr_fills_from_events()`), and the event stream is **sorted
   twice** — both are eliminated by Route C.
5. The memory path creates `meta_json` strings **inside the fold** (in
   `ledgr_opening_position_event_rows()` and `ledgr_fill_event_row()`), then
   parses them back. The JSON round-trip starts inside the fold, not just in
   the post-fold helpers.
6. The persistent path equity reconstruction uses vectorized
   `findInterval + cumsum` rather than an event-loop, which is faster for
   equity but diverges from lot-accounting semantics — a latent parity
   question worth surfacing before Route E is designed.

These findings change the priority ordering and the risk assessment for Route B.

---

## Answers To RFC Questions

### Q1: Are these inefficiencies general, not sweep-specific?

Yes, confirmed by code. `ledgr_execute_fold()` is called identically by both
`ledgr_run_fold()` and `ledgr_sweep_run_candidate()`. The per-pulse context
churn exists in every `ledgr_run()` call — it is just invisible there because
users see one candidate at a time. The post-fold reconstruction inefficiency
also exists in the persistent path, where it additionally pays a DuckDB
round-trip and JSON deserialization on top of the same R loop logic.

Fold refactoring improves `ledgr_run()` directly. This is the strongest
argument for doing it.

### Q2: Is Route C, Route E, or Route B the best first optimization route?

None alone. The right post-v0.1.8 order is D → C together, then B-narrow,
then B-wider, then I. Route E follows naturally from the same work as C+D.
See dependency graph below.

### Q3: Is there a small low-risk Route B subset before LDG-2109?

No. The code review shows that the fold churn is deeper than the RFC describes,
and the `use_fast_context` scaffold that could provide a narrow entry point is
untested dead code. Activating it before parity gates would be unsafe. Do not
optimize before LDG-2109.

### Q4: Typed events before single-pass replay, or together?

Together. Route D as a standalone delivers no measurable benefit; it is an
enabler. Pair them: type the events, build the single-pass helper, ship one
ticket.

### Q5: Rcpp before replay/context contracts are clean?

No. The bottleneck is R object allocation and closure creation — not a
numerical kernel. Rcpp does not help with list copying, closure construction,
or data.frame pivot work. The preconditions for Rcpp (typed, contiguous numeric
data from a pure replay function) do not exist yet. Leave it off the table
until D+C+B are done and profiling still points to a remaining numerical
bottleneck.

---

## Code Review Findings

### Finding 1: `use_fast_context` is a dead scaffold

`backtest-runner.R:1086` sets `use_fast_context <- FALSE`. `sweep.R:257` passes
`use_fast_context = FALSE` into the execution list. Both paths pass the field
into `ledgr_execute_fold()`, but `ledgr_execute_fold()` never reads it — the
field is present in the execution list and silently ignored.

The scaffold was partially built: `bars_proxy` (a list, not a data.frame) and
`features_proxy` are constructed when `use_fast_context = TRUE`
(`backtest-runner.R:1176`, `1240`), but the fold core never selects the
proxy path. The intent — to feed list-backed structures instead of data.frames
to avoid `$<-.data.frame` — exists in the code but has never been activated or
tested.

This is the clearest optimization entry point for Route B after parity gates:
wire `use_fast_context` through `ledgr_execute_fold()`, activate it for the
sweep path, and measure. It is not safe to activate before LDG-2112 exists,
but it is a narrower change than the RFC suggests.

### Finding 2: ctx list and closures are both recreated every pulse

The RFC correctly identifies closure recreation as a problem, but does not name
the root cause: `ctx` itself is a new list allocated on every iteration
(`fold-core.R:157-170`). Because ctx starts as a fresh list with `NULL` in
`.pulse_lookup`, `ledgr_ensure_pulse_context_accessors()` detects
`!is.environment(lookup)` and allocates a new environment — and then
unconditionally constructs 11 new closures regardless:

```r
bar    <- function(id) ledgr_pulse_context_bar(lookup, id)
open   <- function(id) ledgr_pulse_context_scalar(lookup, id, "open")
# ... 9 more
```

These closures close over `lookup` (environment semantics), so they would work
correctly if `lookup` were reused across pulses. The problem is that a new list
creates a new NULL `.pulse_lookup` every pulse, forcing `new.env()` and all 11
closures to be re-created.

The fix is to initialize the lookup env and its closures once per candidate
fold, then only mutate `lookup$bars`, `lookup$positions`, `lookup$bar_index`,
and the few mutable scalar fields of ctx each pulse. Strategies would see
identical behavior because the closures close over the mutable env.

Additionally: `ledgr_pulse_context_bar_index()` validates universe consistency
and computes `stats::setNames(seq_len(n), instrument_id)` on every pulse. The
universe does not change within a candidate fold. This can be computed once and
stored in lookup before the loop.

### Finding 3: `ledgr_features_wide()` is unconditionally eager

`ledgr_attach_feature_helpers()` (`pulse-context.R:177-191`) calls
`ledgr_features_wide(features)` on every pulse and stores the result as
`ctx$features_wide`. This builds a pivot data.frame — string coercions,
`unique()` calls, matrix allocation, a per-element loop, `cbind(out, as.data.frame(values))`.

For a strategy that only calls `ctx$feature("AAA", "returns_20")` and never
accesses `ctx$features_wide`, this is pure waste on every pulse. For the
50-candidate EOD benchmark (4 instruments, 1 feature per candidate), it is a
4-row × 1-column data.frame built 12,600 times. For wider feature sets it
grows quadratically.

The lazy option — compute `features_wide` only on access — requires either
active bindings (which need ctx to be an environment) or changing `ctx$features_wide`
from a field to a zero-argument function, which is an API break. This is the
one fix in Route B that genuinely cannot be done safely without an API decision.
It should be decided as part of the Route B design, not slipped in.

### Finding 4: The JSON round-trip starts inside the fold

The RFC frames Route D as "store typed events in the handler instead of
`meta_json`." The actual situation is earlier: the fold itself creates JSON
strings. `ledgr_opening_position_event_rows()` (`fold-core.R:361-381`)
serializes event metadata to `meta_json = canonical_json(meta)`. Fill events
from `ledgr_fill_event_row()` similarly produce `meta_json` rows. These JSON
strings are then parsed back by `jsonlite::fromJSON()` in both
`ledgr_equity_from_events()` and `ledgr_fills_from_events()`.

In the memory path the data moves: R list → JSON string → buffered row →
`jsonlite::fromJSON()` → R list. The information is available as a typed R
object at the moment of creation and does not need to be serialized at all
before post-fold reconstruction. Typed events means eliminating the JSON step
from the memory fold path entirely, not just from the handler's internal
storage.

### Finding 5: Double JSON parse and double sort in the reconstruction path

`ledgr_equity_from_events()` and `ledgr_fills_from_events()` both:

- call `events[order(events$event_seq), , drop = FALSE]` — sorting the full
  event data.frame independently;
- call `jsonlite::fromJSON(ev$meta_json[[1]], simplifyVector = FALSE)` for
  every event they touch.

The events are already sorted when buffered (event_seq is monotonically
increasing during the fold), so both sorts are redundant. And parsing the same
JSON twice is avoidable. Route C addresses both. The combined saving for the
50-candidate EOD benchmark is modest (the event count per candidate is small
with cheap indicators), but for active strategies with many fills it compounds
linearly.

### Finding 6: Persistent path equity reconstruction diverges from lot-accounting

The persistent path (`backtest-runner.R:1322-1468`) reconstructs equity using
vectorized `findInterval + cumsum` over parsed `cash_delta` and
`position_delta` arrays. It does not call `ledgr_lot_apply_event()` during
equity reconstruction — it relies on the already-accurate `cash_delta` and
`position_delta` stored in `meta_json`.

`ledgr_equity_from_events()` in the memory path does call
`ledgr_lot_apply_event()` per event for FIFO lot tracking and realized/unrealized
PnL decomposition.

These are not the same algorithm. The persistent path equity curve is
correct for `equity = cash + positions_value`, but the `realized_pnl` and
`unrealized_pnl` columns depend on which lot-accounting path is taken. This
latent semantic question should be resolved before Route E designs a shared
equity reconstruction helper — the shared helper must agree on lot semantics,
not just on the vectorized equity total.

---

## Route Reassessment

### Route A (do nothing in v0.1.8)

Correct. Do not change anything before LDG-2109. The parity test suite
(LDG-2112) does not exist yet, and the fold churn is deeper than the RFC
describes. Any pre-LDG-2109 optimization is untestable against the parity
contract. Confirmed.

### Route B (fast pulse context)

Risk is higher than the RFC states for the `features_wide` laziness problem,
but **lower** than it states for the closure/lookup problem — the existing
`use_fast_context` scaffold provides a real, bounded entry point. The RFC
undersells the dead scaffold.

Revised Route B plan (post-LDG-2112):

**B1 — Closure and lookup initialization (lower risk):**
- Before the pulse loop, create `lookup` env once, create all bar/position
  closures once, compute `bar_index` once.
- Each pulse: update only mutable values in lookup and ctx scalars (ts_utc,
  cash, equity, positions, bars_df fields, feature_df fields).
- Gate on LDG-2112 parity tests passing.
- Wire `use_fast_context` through `ledgr_execute_fold()`.

**B2 — List-backed bars/features proxy (medium risk):**
- The `bars_proxy` and `features_proxy` list structures in backtest-runner.R are
  the intended vehicle. Activate them in `ledgr_execute_fold()` under
  `use_fast_context = TRUE`.
- Eliminates `$<-.data.frame` per-pulse field assignments.
- Gate on B1 passing parity tests.

**B3 — Lazy `features_wide` (requires API decision):**
- Requires deciding whether `ctx$features_wide` becomes a zero-argument
  function or ctx becomes an environment with active bindings.
- This is a public API change. It must go through a design doc, not a
  performance ticket.
- Do not combine with B1 or B2.

### Route C (single-pass event summary)

Correct direction. Route C eliminates the double-sort and double-JSON-parse.
The implementation is straightforward: one function that processes events in
order, parses JSON once per event, accumulates equity state and fill records in
one pass, and returns the combined outputs.

However: Route C on its own still parses `meta_json`. Its full benefit requires
combining with Route D (typed events), which eliminates JSON from the memory
path entirely. Design C and D as one ticket.

### Route D (typed memory events)

The RFC correctly identifies the direction but locates the serialization step
at the handler boundary. Code review shows it starts inside the fold in
`ledgr_fill_event_row()` and `ledgr_opening_position_event_rows()`. The typed
event representation must survive from creation (inside fold) through buffering
(output handler) to consumption (single-pass summary helper). This is a
coherent change but touches the buffer contract between fold and handler.

The persistent handler still serializes to `meta_json` for DuckDB durability —
only the memory handler would use the typed representation. This is correct:
the two handlers have different output contracts.

### Route E (extract vectorized equity)

Do not design Route E independently of Finding 6. The persistent vectorized
path and the memory lot-tracking path compute `realized_pnl` differently. A
shared equity helper must first establish which semantics are authoritative.
Route E is downstream of that decision.

Likely correct outcome: the memory lot-tracking path is semantically richer and
should become authoritative. The persistent path's vectorized `findInterval +
cumsum` approach can remain as a performance technique applied to typed event
data after Route D types the events. Route E then becomes "extract the
vectorized numeric core of equity reconstruction and feed it typed event data
from either path."

### Route F (metrics from fold state)

Confirmed: do not do this. The event log is the audit trail. A second
accounting path inside the output handler would be hard to keep synchronized
and would undermine the parity contract that LDG-2112 is meant to enforce.

### Route G (feature matrix cache)

Confirmed: correct direction, not justified by current evidence. The 50-candidate
EOD benchmark shows 0.05s for feature matrix build across 50 candidates. Cache
is relevant for heavier indicators and wider universes. Re-evaluate after D+C
are done and profiling still points to feature construction.

### Route H (Rcpp)

Confirmed: not appropriate now. The bottleneck is R object allocation and
closure creation — a class of problem Rcpp cannot help with without first
making the interface typed, contiguous, and numeric. Do D+C+B first.

### Route I (parallel dispatch)

Confirmed: the correct wall-clock multiplier. Does not reduce single-core cost
but amortizes it across available cores. Should proceed after sequential parity
and promotion semantics are stable (i.e., after v0.1.8 and after B1/B2 reduce
the single-core baseline).

---

## Dependency Graph (Post-v0.1.8)

```
D+C  ─────────────────────────────────> (typed events + single-pass summary)
  └──> E  (shared vectorized equity, after lot-semantics decision)
B1   ─────────────────────────────────> (lookup/closure init once per fold)
  └──> B2 (list-backed proxy)
       └──> B3 (lazy features_wide, API decision gate)
I    ─────────────────────────────────> (parallel dispatch, after B1 stable)
H    ─────────────────────────────────> (Rcpp, after D+C+B1+B2, if still needed)
```

D+C and B1/B2 are independent and can be designed in parallel after v0.1.8
ships. D+C is lower risk (post-fold change only). B1/B2 is higher surface
but has the `use_fast_context` scaffold to reduce novelty.

---

## Updated Comparative Table

| Route | Likely payoff | Risk | Benefits `ledgr_run()` | v0.1.8? | Post-v0.1.8 order |
|---|---|---|---|---|---|
| A: Do nothing | 0 | Low | No | Yes | — |
| B1: Closures once per fold | Medium | Low-Medium | Yes | No | 2 |
| B2: List-backed proxy | Medium | Medium | Yes | No | 3 |
| B3: Lazy features_wide | High | High (API) | Yes | No | Needs own design |
| C+D: Single-pass typed events | Medium | Low-Medium | Yes | No | 1 |
| E: Unified equity reconstruction | Medium | Medium | Yes | No | 4 (after C+D) |
| F: Metrics from fold state | 0 net | High | No | No | Never |
| G: Feature matrix cache | Workload-dep | Low | No | No | 5 |
| H: Rcpp | Unknown | High | Maybe | No | Last |
| I: Parallel dispatch | High wall-clock | High | No | No | After B1 stable |

---

## Summary

The Codex recommendation to do nothing before LDG-2109 is correct and
confirmed. The RFC's route analysis is sound. This response adds:

1. A dead `use_fast_context` scaffold that is the correct Route B entry point,
   not a greenfield rewrite.
2. A clearer root cause for Route B: ctx list recreation, not just closure
   recreation.
3. A more precise Route C target: double-sort and double-JSON-parse, both
   eliminatable.
4. Route D belongs inside the fold, not only at the handler boundary.
5. A latent semantic question in Route E: resolve lot-semantics ownership
   before designing a shared equity helper.
6. B3 (`features_wide` laziness) requires a public API decision and must not
   be bundled with B1/B2.

Recommended first post-v0.1.8 ticket: C+D together (single-pass typed event
summary). Clearest boundary, lowest parity risk, directly supported by the
profiler, improves both paths.

Second ticket: B1 (closures/lookup init once per fold), using `use_fast_context`
as the activation mechanism. Gate on LDG-2112 passing.
