# Research Strategy UX Brief

**Status:** Active, non-binding design direction for v0.2.2. Input to the
owning RFC cycles; not an execution contract or implementation authority.

**Date:** 2026-10-05

**Purpose:** Preserve one coherent account of the research UX and supporting
architecture while separate RFCs settle feature addressing, causal history,
recursive indicators and scheduling. An accepted synthesis may adopt, change
or reject any proposed surface here. `contracts.md` becomes authoritative only
after those decisions are accepted and implemented.

## 1. Product direction

An ordinary portfolio-research strategy should be able to:

1. declare the features it needs;
2. request a causal, multi-instrument history frame on a decision date;
3. pass that frame to an estimator written in ordinary R;
4. turn the resulting weights into ledgr targets; and
5. declare its execution schedule outside the strategy body.

The simple path remains available. This direction adds a trustworthy research
ladder; it does not make point-in-time facts, availability policy or portfolio
optimization mandatory for a basic run.

## 2. UX principles

### Context carries primitives, not every derived question

`ctx` exposes the causal values needed at the current pulse: time, axis,
prices, features, holdings, admissibility and state. New convenience methods
are not added to `ctx` merely because a useful answer can be derived from
those primitives.

Exported helpers construct research-facing values explicitly:

```r
history <- ctx |>
  ledgr_history_frame(
    feature = "daily_return",
    lookback = 252L
  )
```

`ledgr_pulse_snapshot()` is not part of this callback flow. It is an external
development helper that constructs one pulse context so an author can invoke a
strategy manually. For availability-aware inspection, the experiment supplies
the snapshot, universe, features, history policy, data start and opening state;
the strategy itself still reads history only from `ctx` through
`ledgr_history_frame()`.

`ledgr_history_frame()` is a proposed surface, not a bound name. Its owning
history RFC must decide the exact arguments and semantics.

The proposed helper reads either one prepared feature or one sealed bar field
per call. The namespaces stay explicit:

```r
close <- ctx |>
  ledgr_history_frame(
    bar = "close",
    lookback = 252L
  )

returns <- ctx |>
  ledgr_history_frame(
    feature = "daily_return",
    lookback = 252L
  )
```

Exactly one of `bar` and `feature` is supplied. Bar fields use the sealed
snapshot's declared basis and closed bar-field vocabulary; feature names use
the accepted alias and concrete-ID resolution rule. Both inputs share the same
causal cutoff, axis, lookback, layout and missingness machinery. The first
surface deliberately returns one numeric series per call rather than adding a
multi-feature tensor or implicit join.

### One prepared representation, frames at the boundary

The engine prepares one canonical typed representation for a feature. Scalar,
vector and historical reads slice that representation. A wide or long data
frame is constructed only when a caller requests it; equivalent matrices,
per-instrument frames, wide frames and long frames are not retained together
for convenience.

The current measured orientation is:

- the prepared feature matrix is instruments by pulses;
- a requested wide frame is pulses by instruments with an explicit `ts_utc`
  column; and
- a requested long frame contains `ts_utc`, `instrument_id`, `feature` and
  `value`.

Wide is the proposed default because it is the ordinary estimator input and
has roughly the retained size of the source numeric matrix. Long is explicit
because it is materially larger.

### History keeps identity through the estimator boundary

A requested history is a classed research object, not an anonymous data
frame that immediately loses its axis. It retains the time axis, instrument
identity, requested and available lookback, causal cutoff and missingness
treatment. Ordinary tabular operations may still inspect it.

An explicit adapter supplies packages that require a numeric matrix:

```r
x <- returns |>
  ledgr_history_matrix()
```

The adapter operates only on the supplied history result; it is not a second
reader and owns no cutoff, axis or missingness logic. It excludes the time key
by contract and preserves instrument identity. Teaching must not require users
to remove `ts_utc`, call
`colnames()` and reconstruct names around solver output. An estimator written
for ledgr history should return a `ledgr_weights` object; a general solver may
use a small identity-preserving bridge decided by the history implementation.

The history object also retains which requested instruments were excluded and
why. The matrix adapter contains only the included estimation sample. Exclusion
from that sample is evidence about estimator input, not an instruction to set
the instrument's execution target to zero.

### Causal history is explicit

`lookback` counts the accepted history unit through the current causal cutoff.
`lookback = Inf` requests all history prepared and permitted at that pulse. It
does not fetch future rows or silently extend before the run's accepted history
boundary.

The proposed ordinary defaults are:

- `instruments = "admissible"`;
- `na_action = "keep"`; and
- `layout = "wide"`.

Dropping incomplete instruments is explicit, for example
`na_action = "drop_instruments"`. The history RFC owns the final vocabulary,
the distinction between missing observations and inactive sessions, and the
two-clock cutoff.

Dropping an instrument settles only the shape of the research input. A later
portfolio-construction contract must choose whether an omitted held instrument
is kept, liquidated or makes the rebalance refuse. Until then, teaching must
not present omission from an estimator matrix as an implicit sell decision.

Structural history completeness is separate from indicator readiness. A
history helper may answer whether the requested finite lookback and minimum
instrument count are present. WS4 separately owns first-valid output,
convergence and post-gap readiness for recursive indicators. The final helper
name is open; `ledgr_history_ready()` must not ship if it obscures that
distinction.

The history object also supports an explicit bridge into the existing typed
selection pipeline. The preferred verb-shaped direction is:

```r
returns |>
  ledgr_select_instruments() |>
  ledgr_weight_equal()
```

The middle value is a `ledgr_selection`; `ledgr_weight_equal()` keeps its
existing single contract. The exact selector name and whether later evidence
justifies tidyselect-style selectors remain open. A full selection DSL is not
part of the first history implementation.

### Scheduling is orchestration

A strategy should not contain a schedule predicate followed by an early
`ctx$hold()`. Scheduling belongs outside the callback so the engine can avoid
unnecessary callback, context and history work while still processing fills,
accounting, valuation and economic events.

The proposed composition is a strategy decorator:

```r
strategy <- portfolio_strategy |>
  ledgr_on_schedule(ledgr_month_end())
```

These names are illustrative. The scheduler RFC owns the schedule vocabulary,
identity, held-pulse semantics and whether measurement earns implementation in
v0.2.2. An undecorated strategy continues to run under the ordinary current
behavior.

### Weights return to the current context

Estimation and execution remain separate. The estimator receives an ordinary
research object and returns weights. ledgr applies those weights within the
current execution context:

```r
weights <- ctx |>
  ledgr_history_frame(
    feature = "daily_return",
    lookback = params$lookback,
    na_action = "drop_instruments"
  ) |>
  estimate_minimum_variance()

weights |>
  ledgr_target_rebalance(
    ctx,
    equity_fraction = params$equity_fraction
  )
```

The estimator is deliberately ordinary R. A generic optimizer catalogue,
solver adapters and trained-model lifecycle are not implied.

Turnover-aware estimators also need pre-trade portfolio weights. A proposed
derived helper such as:

```r
current <- ctx |>
  ledgr_current_weights(instruments = returns)
```

cannot be specified from syntax alone. Its contract must settle cash,
invested-capital denominators, ineligible and held nonmembers, reserved
exposure, stale and frozen marks, unavailable closes and rounding drift. It
therefore belongs to the later portfolio-construction RFC, not to the minimum
v0.2.2 history implementation.

### Allocation and execution risk stay distinct

An optimizer is strategy-layer intent generation even when its objective is
risk-derived. Constraints that determine the optimum, such as non-negative
weights, participate inside that optimizer. The target-risk chain remains the
independent post-intent transformation and enforcement layer:

```text
causal history -> allocation model -> weights -> target quantities
               -> target-risk chain -> fills
```

Post-hoc clipping is not a substitute for solving the constrained problem.
The risk chain may still enforce the same hard boundary independently. A
future ledgr allocation-model surface belongs to the parked
portfolio-construction RFC; it does not broaden the current risk chain.

### Reusable user code needs an explicit declaration boundary

The current tier model rejects an unqualified user helper outside the
strategy body as Tier 3. Nesting every estimator inside `strategy` is safe but
works against reusable research code; requiring a package for every emerging
helper is too large a jump.

A later RFC should reconsider the previously deferred `strategy_helpers`
idea as an explicit source bundle, approximately:

```r
strategy <- ledgr_strategy(
  portfolio_strategy,
  helpers = list(
    compute_portfolio_weights = compute_portfolio_weights,
    solve_long_only = solve_long_only
  )
)
```

This is illustrative, not a bound name. The RFC must own helper-source
capture, recursive preflight, identity and hashing, stored-source recovery,
package dependencies, resume and worker reconstruction, and rejection of
mutable closure state. It is not part of v0.2.2.

## 3. Illustrative complete flow

The following is a design target, not executable documentation:

```r
features <- ledgr_feature_map(
  daily_return = ledgr_ind_return()
)

portfolio_strategy <- function(ctx, params) {
  weights <- ctx |>
    ledgr_history_frame(
      feature = "daily_return",
      lookback = params$lookback,
      na_action = "drop_instruments"
    ) |>
    estimate_minimum_variance()

  weights |>
    ledgr_target_rebalance(
      ctx,
      equity_fraction = params$equity_fraction
    )
}

strategy <- portfolio_strategy |>
  ledgr_on_schedule(ledgr_month_end())

experiment <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  features = features,
  params = list(
    lookback = 252L,
    equity_fraction = 0.95
  )
)
```

### Acceptance scenario: constrained portfolio backtesting

The Tidy Finance constrained-optimization chapter is a useful product test,
not an implementation prescription. A strategy should be able to request a
causal 120-period multi-instrument return history, pass it to ordinary R or
`nloptr`, receive identified long-only weights and rebalance without manually
removing a timestamp column, recovering column names, manufacturing named
zero vectors or replaying portfolio accounting in research code.

The v0.2.2 proof needs only one representative long-only estimator. Current
portfolio weights, turnover-aware allocation, shorting, leverage, a generic
optimizer catalogue and helper-source bundles retain their later owners.

### Acceptance scenario: Schur complementary allocation

Schur complementary allocation is a useful frontier-method test. On each
explicit decision date, a strategy requests a causal return history, converts
it through the identity-preserving matrix adapter, fits an external batch
estimator over a fixed sample, converts its identified long-only output to
`ledgr_weights`, and returns targets through `ledgr_target_rebalance()`.
`gamma` and lookback are ordinary candidate parameters. Selection of `gamma`
must use the accepted sweep or walk-forward evidence rather than the interval
reported as final performance.

This scenario does not put Schur, covariance estimation or clustering inside
the ledgr engine. A package-qualified adapter is the current reproducible
route; a declared user-helper bundle remains later work. The scenario is
successful only if no code manually removes a timestamp column, rebuilds
instrument names, constructs a private history panel or replays accounting.

The scenario also supplies a negative product test: an admissible held
instrument dropped for incomplete estimation history must not silently become
a zero target. The later portfolio-construction RFC owns the explicit keep,
liquidate or refuse policy and whether weights need a small allocation result
carrying exclusions and deterministic estimator diagnostics. A native R port
or locked external implementation, parity evidence and effective-parameter
reporting are integration questions, not v0.2.2 engine requirements.

### Cross-method design exercise

The companion
[`portfolio_method_ux_exercises.md`](portfolio_method_ux_exercises.md)
tested this boundary against MVO, equal risk contribution, Black-Litterman,
HRP, NCO, sparse tracking, Schur allocation and marginal-and-copula
Wasserstein DRO. At the design boundary, none requires a new ledgr portfolio
abstraction. Each fits causal history, an identity-preserving ordinary-R
adapter, validated `ledgr_weights` and target conversion.

That result is deliberately negative and conditional. It depends on WS3
shipping the proposed history identity and exclusion evidence.
Black-Litterman also needs frozen causal view inputs, and the exact DRO method
has no maintained public implementation identified by the exercise. WS7
therefore remains the required runnable public-path proof.

The separate
[DFL UX probe](decision_focused_learning_ux_probe.md) found that the
decision-time boundary also fits a trained method. Per-row
historical cutoffs, delayed labels, embargo, refitting and fitted-artifact
identity belong to the later ML architecture, not to portfolio construction.

## 4. Measured implementation orientation

The measurements guide later RFCs but bind no implementation:

- constructing an ordinary 600-instrument pulse frame from prepared vectors
  is in the tens of microseconds;
- constructing a 1,150-instrument by 7,470-pulse wide frame directly from a
  prepared matrix took about 55 milliseconds and retained about 66 MiB;
- the equivalent long frame retained about 197 MiB;
- `collapse::pivot()` is useful for genuinely long input, but a direct matrix
  transpose plus `collapse::qDF()` is faster for the proposed wide boundary;
  and
- repeatedly building expanding full-history frames on every pulse would
  still create quadratic cumulative work, so expensive history belongs after
  a decision guard or an engine-level schedule.

Parallel memory is a separate question. WS3 will run a bounded local-worker
spike using `mori` with the existing `mirai` path. The candidate architecture
shares immutable prepared bars and feature matrices across workers, while each
worker constructs only the requested transient frame. The spike does not
share DuckDB connections or mutable run state and does not preselect a package
dependency.

## 5. Ownership

| Concern | Owning route |
| --- | --- |
| Alias and concrete feature-ID reads | Feature-map read-surface RFC |
| Historical feature and bar reads, clocks, cutoff, layout and missingness | WS3 historical-projection implementation route |
| Recursive readiness, convergence and gap behavior | WS4 recursive-indicator RFC |
| Schedule decorator and skipped-pulse behavior | WS6 scheduler RFC, if promoted by measurement |
| Shared immutable worker inputs | WS3 `mori`/`mirai` spike; RFC only if architecture changes |
| Representative estimator and teaching | WS7 public long-only estimator proof |
| History object, matrix adapter and selection bridge | WS3 history route, exercised by WS7 |
| Structural completeness versus indicator readiness | WS3 and WS4 jointly; do not conflate the contracts |
| Estimation exclusions and omitted-target policy | Parked portfolio-construction RFC after history ships |
| Current portfolio weights, allocation results and model diagnostics | Parked portfolio-construction RFC after history ships |
| Declared user-written strategy helpers | Separate post-v0.2.2 strategy-helper-bundle RFC |
| Executable current behavior | `contracts.md`, after accepted decisions and implementation |

The feature-map RFC supplies the naming rule used by current vector reads and
future historical reads. It does not design history. The history RFC supplies
the causal frame. It does not design scheduling. The scheduler may skip work;
it does not change the economic pulse sequence.

## 6. Open choices

The owning RFCs still need to decide:

- the final history-helper name and argument vocabulary;
- the classed history object's matrix and solver bridge;
- the structural-completeness helper name;
- the history-to-selection verb;
- the representation of included and excluded instruments and their exclusion
  reasons;
- selector vocabulary beyond `"admissible"` and explicit instrument IDs;
- whether one request may carry more than one feature;
- the exact missingness and disclosure policy;
- feature alias resolution shared by vector and historical reads;
- recursive history, convergence, resets and walk-forward hydration;
- schedule identity and parameterization;
- whether a later allocation result must carry exclusions and deterministic
  estimator diagnostics in addition to weights; and
- whether shared memory saves enough representative parallel RSS to warrant a
  dependency.

## 7. Resolution and staleness

Each owning synthesis records whether it adopts, changes or rejects the
applicable direction. Update this table at acceptance rather than rewriting
the original discussion:

| Direction | State | Authority |
| --- | --- | --- |
| Singular alias-aware feature read | proposed | feature-map RFC cycle |
| On-demand causal history frame | resolved by accepted v12, 2026-10-16 | [Historical-projection v12](../rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v12.md) Sections 3 and 8 |
| Identity-preserving history and matrix bridge | resolved by accepted v12, 2026-10-16 | [Historical-projection v12](../rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v12.md) Sections 3 and 8 |
| History-to-selection bridge | proposed | WS3 and WS7 |
| Strategy schedule decorator | proposed, conditional | WS6 scheduler route |
| Shared prepared inputs through `mori` | resolved: rejected for v1 | [Historical-projection v12](../rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v12.md) Sections 7 and 11 |
| Estimation exclusion versus execution target | parked | portfolio-construction RFC |
| Current weights, allocation result and model diagnostics | parked | portfolio-construction RFC |
| Declared user strategy-helper bundle | parked | separate post-v0.2.2 RFC |

When every row is resolved, mark this brief `Resolved` and link the accepted
authorities. The brief then remains a readable architectural narrative, while
accepted syntheses and `contracts.md` carry the binding rules.
