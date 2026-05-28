# Response: Walk-Forward Evaluation RFC Seed

**Status:** Reviewer response; design input for a future walk-forward synthesis.
**Respondent:** Codex
**Date:** 2026-05-27
**Responds to:** `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_seed.md`

**Revision note:** This response was written by Codex as the response-stage
reviewer for a seed authored separately. I did not edit the seed. The seed
should remain the author's artifact until a later synthesis or revised seed
round explicitly incorporates response-stage findings.

---

## Summary Verdict

The seed's central direction is right: walk-forward should be a wrapper over
the existing run and sweep semantics, not a second execution engine. The
strategy contract should remain `function(ctx, params) -> named numeric target
vector`. Fold definitions should be durable artifacts, the first release should
stay research-only, and purging, CPCV, paper/live, OMS event streams, and
selection-integrity diagnostics should remain deferred.

The seed is not synthesis-ready as written. The issues are fixable, but several
claims are currently stronger than the codebase and literature support:

- the current public `ledgr_run(exp)` and `ledgr_sweep(exp, ...)` paths do not
  support fold-local train/test windows through a small helper alone;
- the proposed scalar `walk_forward_scores` table is not sufficient input for
  all downstream PBO, DSR, and CPCV work without richer retained artifacts or
  sufficient statistics;
- the anti-pattern cannot be rejected globally at the API level because
  `ledgr_sweep()` remains a public full-snapshot exploratory tool;
- fold-local warmup, hydration, scoring, and opening-state semantics are not
  separated, which is a real no-lookahead and comparability footgun;
- walk-forward identity must not depend on current nondeterministic
  `sweep_id`, and after v0.1.9 it must include target-risk identity;
- the selection-rule contract needs deterministic tie, NA, failure, and
  train-only-input semantics before it can be treated like a reproducible
  ledgr-owned object.

The right next step is a focused seed revision, not synthesis. The revision can
be small if it narrows overclaims instead of expanding v1 scope.

---

## Accepted Direction

The response accepts these design directions and recommends they not be
re-litigated during synthesis:

- Walk-forward is a wrapper over existing run/sweep semantics; the fold core
  must not split.
- The strategy contract remains invariant, and strategies do not see fold
  boundaries or retraining state.
- v1 is research-only, single-snapshot, rolling/anchored, and calendar-time by
  default.
- Cross-snapshot walk-forward, purging, embargoes, CPCV, trading-time folds,
  paper/live walk-forward, and per-fold OMS streams are correctly deferred.
- Selection rules should be ledgr-owned classed objects in v1.
- Inspection helpers should be read-only.
- Walk-forward results should be evidence artifacts, not automatic ranking or
  tuning machinery.

The roadmap placement is also basically correct:

```text
v0.1.9       target risk
v0.1.9.x     walk-forward evaluation
v0.1.9.x     selection-integrity diagnostics after walk-forward
v0.2.x       OMS semantics and adjacent data-model work
v0.3.0+      paper/live adapters
```

That order matches `inst/design/ledgr_roadmap.md`. The seed does not pull OMS
or paper/live implementation forward, and it treats walk-forward as the bridge
between exploratory sweeps and later selection-integrity diagnostics. That is
the right high-level sequence.

---

## Blocking Corrections

### 1. The Wrapper Architecture Is Feasible, But Under-Scoped

The no-second-engine architecture is feasible. The current runner already has
date-window execution internally: `ledgr_backtest_config(start, end, ...)`
flows into `cfg$backtest$start_ts_utc` and `cfg$backtest$end_ts_utc`, and
`ledgr_run_fold()` uses those values to prepare snapshot runtime views and
pulse timestamps.

The public experiment-first surfaces do not expose the same window contract:

- `ledgr_run(exp, ...)` has no `start` or `end` argument.
- `ledgr_run_experiment()` derives `start` from `exp$opening$date` or snapshot
  metadata, but always derives `end` from `exp$snapshot$metadata$end_date`.
- `ledgr_experiment()` has no scoring-window or run-window field.
- `ledgr_sweep()` computes `range <- ledgr_precompute_scoring_range(meta)`
  without passing start/end, so sweep scoring defaults to the full snapshot.
- ranged precompute exists, but `ledgr_sweep()` currently validates
  `precomputed_features` without a requested start/end.

So the seed's `ledgr_experiment_window(exp, start_utc, end_utc)` helper is not
just a small adapter unless it also establishes a shared window contract
consumed by `ledgr_run_experiment()`, `ledgr_sweep()`,
`ledgr_precompute_features()`, and precomputed-feature validation.

The fold core itself need not change, but the public and internal wrapper
surface does need meaningful work.

Recommendation:

Revise Section 10.1 and Section 10.2 to bind this more precise statement:

```text
Walk-forward must not introduce a second fold core. It may require a shared
experiment-window contract consumed by ledgr_run(), ledgr_sweep(), and
precomputed-feature validation. The first implementation must prove parity
between a fold-window walk-forward call and a direct start/end run over the
same snapshot, params, feature_params, risk config, and seed.
```

Do not leave the impression that one helper can wrap the current code without
touching sweep and run surfaces.

### 2. The Scalar Score Matrix Is Not Sufficient For PBO, DSR, And CPCV

The seed repeatedly claims that the v1 long `walk_forward_scores` table is
sufficient input for downstream PBO, DSR, and CPCV "without re-execution."
That is too strong.

The literature supports preserving per-candidate evidence, but it does not
support the specific conclusion that scalar `(fold, candidate, window, metric)`
rows are enough for every later diagnostic.

Source check:

- Bailey, Borwein, Lopez de Prado, and Zhu describe CSCV/PBO in terms of a
  performance matrix over trials and subsamples, with rankings derived across
  in-sample and out-of-sample recombinations. The paper explicitly relies on
  subsample performance estimates and notes limitations when performance
  measures are sensitive to sample structure. See "The Probability of Backtest
  Overfitting": https://www.davidhbailey.com/dhbpapers/backtest-prob.pdf
- The CRAN `pbo` vignette consumes a trials matrix and applies a function such
  as Sharpe over the matrix, rather than accepting only pre-computed long
  scalar metric rows: https://mirrors.nics.utk.edu/cran/web/packages/pbo/vignettes/pbo.html
- Bailey and Lopez de Prado's DSR paper says PBO is non-parametric and
  "requires a large amount of information." It also states that DSR depends on
  selected-strategy Sharpe, sample length, skewness, kurtosis, variance across
  trials' Sharpe ratios, and number of independent trials. A generic metric row
  does not guarantee those inputs. See "The Deflated Sharpe Ratio":
  https://www.davidhbailey.com/dhbpapers/deflated-sharpe.pdf
- CPCV is path-oriented and combinatorial. Public mlfinlab documentation
  describes CPCV as generating multiple train/test split combinations and
  backtest paths, from which path-level Sharpe distributions are derived:
  https://random-docs.readthedocs.io/en/latest/implementations/cross_validation.html

The seed is closest for a simple PBO approximation when the score matrix
contains fold-level performance for every candidate on comparable partitions
and the downstream diagnostic accepts that reduced representation. It is not
enough for:

- recomputing nonlinear metrics over different CSCV/CPCV recombinations;
- DSR unless return moments, sample length, and effective trial count metadata
  are preserved;
- CPCV path-level diagnostics unless path membership and path-level return or
  sufficient-stat artifacts exist;
- any diagnostic that needs per-pulse return series, equity curves, or
  sufficient statistics rather than final scalar metrics.

Recommendation:

Replace "the score matrix is sufficient input" with a narrower claim:

```text
The v1 score table is sufficient for v1 fold/candidate inspection, train/test
ranking, selected-candidate OOS review, and some downstream diagnostics that
operate directly on scalar fold metrics. It is not, by itself, a universal
artifact for PBO, DSR, or CPCV.
```

Then reserve richer optional artifacts without pulling them into v1:

```text
Future diagnostic retention may add per-candidate/fold return payload
references, equity payload references, sufficient-stat rows
(n_obs, mean, variance, skewness, kurtosis, drawdown inputs), partition_id,
path_id, and family/effective-trial metadata.
```

Do not promise no re-execution for all diagnostics unless the retention tier
actually preserves the required inputs.

### 3. The Anti-Pattern Cannot Be Globally Prevented By The API

The seed says:

```text
The engine does not expose a path that runs all candidates on the full snapshot
and selects retrospectively.
```

That is not true in ledgr, and it should not become true. `ledgr_sweep()` is a
public exploratory API that intentionally runs a parameter grid over the full
experiment range. The v0.1.8.5 spec explicitly teaches sweeps as exploratory
evidence and promotion as a recorded choice, not validation.

What ledgr can prevent is narrower:

- `ledgr_walk_forward()` should not accept a precomputed full-snapshot sweep as
  evidence for fold-local selection.
- `ledgr_walk_forward()` should not accept a preselected winner and then report
  fold tests as if the winner had been chosen fold-locally.
- `ledgr_walk_forward()` should record its own fold-local train, select, and
  test sequence as the only source of walk-forward evidence.

Users can still run arbitrary exploratory sweeps outside the walk-forward API.
The framework cannot prevent that, and pretending otherwise creates a false
safety claim.

Recommendation:

Reframe Section 7.3:

```text
The walk-forward API does not facilitate or accept sweep-then-test-the-winner
as walk-forward evidence. It may reject precomputed sweep-result objects as
selection inputs unless those objects were produced by the same session and
fold train window. ledgr_sweep() remains an exploratory full-range API.
```

This preserves the procedural honesty rule without overstating enforceability.

### 4. Warmup, Hydration, Scoring, And Opening State Are Not Separated

The seed repeatedly says "restricted scoring range" but does not distinguish:

- the data range used to hydrate indicators;
- the first pulse that counts toward metrics;
- the execution start timestamp;
- the opening cash and opening positions for the test run;
- whether an indicator may use pre-test bars for warmup.

This is a serious design gap.

Current precompute already hints at the needed separation:

```text
scoring_range = start/end
warmup_range  = snapshot start to scoring start
```

But `ledgr_sweep()` currently builds pulses over the whole fetched range. The
runner also computes feature series over the configured start/end range. For a
test fold, those two facts matter:

- If the test run starts exactly at `test_start`, long-lookback features may be
  cold and the fold will contain artificial warmup behavior.
- If the feature hydration range includes train bars before `test_start`, ledgr
  must make clear that those bars are used only for indicator state, not for
  scoring or target evaluation before the test window.
- If the fold starts with flat positions and configured cash, results answer a
  different question than if the fold carries state from a prior train or
  previous test period.

The roadmap expects walk-forward to represent training/scoring windows
explicitly. The seed does not yet bind enough to implement that safely.

Recommendation:

Add a blocking design decision before synthesis:

```text
Each fold must distinguish hydration_start, scoring_start, scoring_end,
execution_start, and opening_state.
```

For v1, bind the simplest safe version:

```text
Train and test metrics score only inside their train/test scoring windows.
Indicator hydration may use earlier bars from the same sealed snapshot when
needed for warmup, but those bars do not contribute to fold metrics and are not
visible as pre-window strategy pulses. Test folds start from the experiment's
configured opening cash and an explicit opening-position policy.
```

The exact opening-position policy can be open, but the dimensions must be named
now. Otherwise the wrapper can leak train-window state or produce incomparable
cold-start folds.

### 5. Walk-Forward Identity Must Not Depend On Current `sweep_id`

The seed says walk-forward identity carries forward from sweep promotion and
reuses sweep identity. That needs narrowing.

Current `ledgr_sweep()` assigns a `sweep_id` using process ID, an in-session
counter, and `Sys.time()`. That is appropriate as an ephemeral result label,
but it is not a deterministic identity component.

Walk-forward can reuse row-level sweep candidate provenance:

- strategy hash;
- snapshot hash;
- feature_set_hash;
- alias_map_hash;
- candidate params and feature_params;
- execution seed;
- metric context.

It should not use the current `sweep_id` as part of `candidate_id`,
`session_id`, `fold_id`, or replay identity.

There is a second identity issue: walk-forward sits after v0.1.9 target risk.
The accepted target-risk synthesis requires risk identity in run and candidate
provenance where applicable. A v0.1.9.x walk-forward session that selects
candidates based on post-risk realized metrics must include risk-chain identity
in session and candidate identity.

Recommendation:

Add this binding:

```text
Walk-forward candidate identity is deterministic from candidate params,
feature_params, strategy identity, feature identity, metric context, target-risk
identity when present, and execution seed. It must not depend on the current
ephemeral sweep_id.
```

Also add `risk_chain_hash` or the eventual v0.1.9 equivalent to the proposed
session and score schemas where relevant.

### 6. Selection Rules Need A Deterministic Contract

The seed correctly borrows the "classed ledgr object only" discipline from the
target-risk synthesis. The analogy is useful for surface safety, but selection
rules are not risk steps.

Risk steps transform target vectors during execution. Selection rules consume
fold-local sweep results and choose a candidate. That means selection rules
must have their own contract:

- they only see train-window evidence for the current fold;
- they cannot read test-window rows;
- they name the required metric(s);
- missing metrics fail loudly;
- `NA`, `NaN`, and infinite metric values have explicit behavior;
- ties have deterministic behavior;
- no surviving candidates produces a classed failure;
- selected candidate identity is stable and reproducible.

Without those details, `ledgr_select_argmax(metric)` is not deterministic
enough to be a provenance component.

Recommendation:

Bind a minimal v1 selection rule contract:

```text
ledgr_select_argmax(metric) and ledgr_select_argmin(metric) consume only
train-window score rows for the current fold. They drop or reject non-finite
values according to an explicit policy, fail if no eligible candidate remains,
and break ties by deterministic candidate_key ordering.
```

Composite selection can remain future work.

---

## Non-Blocking Findings

### 1. Roadmap Alignment Is Good

The seed correctly places walk-forward after v0.1.9 target risk and before OMS
or paper/live. It does not invent a v0.1.10 milestone, and it does not pull
v0.2.x OMS semantics into v0.1.9.x.

Keep this sequencing.

### 2. OMS Alignment Is Mostly Correct

The accepted OMS synthesis records walk-forward interaction as a future
obligation, especially around per-fold order-event streams. The seed correctly
keeps v1 research-only and does not require order_events or target_decisions.

One sentence would make the boundary sharper:

```text
Research-mode walk-forward writes ordinary run artifacts and walk-forward
diagnostic artifacts only; it does not write OMS lifecycle artifacts unless a
future OMS/paper/live RFC binds that behavior.
```

### 3. The Train/Test Score Wording Is Ambiguous

Section 6.6 says the score matrix is "the union of per-candidate train-window scores."
Section 8.4 has a `window` field containing both `train` and `test`. Section 9.1 says only
the selected candidate's test scores are written.

That is a defensible v1 retention policy, but the terms need to be explicit:

```text
train: all candidates
test: selected candidate only by default
```

If future diagnostics need top-N or all-candidate test rows, that should be a
retention tier rather than an implicit promise in the core score schema.

### 4. Failure Rows Need A Session-Level State Model

The seed records candidate and fold failures, but session state needs a small
vocabulary:

```text
done
failed
partial
interrupted
```

This is not a blocker for the seed, but it should be bound before tickets. It
will affect restart/replay behavior and release-gate tests.

### 5. Calendar-Time Defaults Are Fine, But Q3 Should Be Narrowed

Calendar time is already bound in Section 7.6. Open Question #3 reopens it by asking
whether v1 should default to calendar time, trading-day count, or both.

Recommendation:

Keep calendar time as v1. Narrow Q3 to:

```text
What exact calendar-time API spelling should fold constructors use, and how do
they handle weekends, holidays, and missing bars?
```

Trading-day-count and market-calendar folds should remain future work.

### 6. Walk-Forward Inside Sweep Is Mostly A Future Non-Goal

Open Question #13 asks whether a user can run `ledgr_sweep()` where each
candidate is itself a walk-forward session. The current sweep API evaluates a
strategy over a parameter grid on one experiment; it does not naturally accept
walk-forward sessions as candidates.

This is more of a future composition concern than a v1 design question.

Recommendation:

Move it to explicit non-goals:

```text
v1 does not support nesting walk-forward sessions inside sweeps or sweeps over
fold-list definitions.
```

### 7. Promotion Should Probably Stay Narrow In v1

Promotion semantics are genuinely difficult. Existing `ledgr_promote()` commits
one selected candidate as a normal run. A walk-forward session is not one
candidate:

- the latest selected candidate is a normal candidate;
- the per-fold parameter path is a backward-looking schedule;
- the selection rule is a future process, not a run.

The safest v1 stance is:

```text
Walk-forward v1 does not add ledgr_promote_walk_forward().
It exposes inspection and extraction helpers. Users may extract a selected
candidate, usually the latest fold's candidate or a manually justified stable
candidate, and promote that through existing ledgr_promote() with an explicit
note.
```

Parameter-path promotion and selection-rule promotion should remain future
RFCs. This prevents a research diagnostic artifact from sounding deployable.

---

## Open Questions You'd Add Or Remove

### Remove Or Bind From The Seed's Current List

1. **Public API shape.** Bind `ledgr_walk_forward()` as the v1 entry point.
   Modifiers passed into `ledgr_run()` or `ledgr_sweep()` would blur the
   procedural ordering.

2. **Calendar vs trading-time defaults.** Already bound. Keep calendar time.
   Move trading-time folds to future obligations.

3. **Multi-metric selection.** Bind single-metric `argmax`/`argmin` for v1.
   Composite selection is useful but should be a future selection-rule DSL.

4. **Gap field default.** Bind `gap = NULL` as "no gap semantics active" for
   v1, or bind `gap = 0` as "zero-duration gap." Do not leave this open if the
   constructor is public. My preference is `gap = NULL` with non-NULL gap values
   reserved until the embargo RFC binds semantics.

5. **Fold-list identity.** Bind content-addressed identity over ordered
   `fold_id`s plus constructor metadata. Call-addressed identity is too brittle.

6. **Walk-forward inside sweep.** Move to non-goals or future obligations.

7. **Experiment-window helper public or internal.** Keep it internal for v1.
   The code review above shows it is not a trivial helper yet. Expose it only
   after the run/sweep/precompute window contract is stable.

### Keep As Real Spec-Cut Questions

1. **Promotion semantics.** Keep, but narrow the v1 default as described above.

2. **Top-N artifact retention.** Keep, but frame as retention tier and
   diagnostic readiness, not just reporting convenience.

3. **Per-fold telemetry budget.** Keep. A 50-candidate by 20-fold session is
   1000 train candidate runs plus test runs; the implementation must batch
   writes and avoid per-pulse DB writes.

4. **Partial session recovery.** Keep. Restart-only is simpler; resumable
   sessions need idempotent write semantics and should not be assumed.

5. **Failed-fold accounting.** Keep, but likely bind a small status vocabulary
   before implementation.

6. **Reporting defaults.** Keep as spec-cut, not synthesis. Reporting should
   not drive core schema.

### Add Missing Open Questions

1. **Warmup and hydration range.** Does a fold use pre-scoring bars to hydrate
   indicators, and how are those bars kept out of scoring?

2. **Opening state for test folds.** Do test folds start flat with configured
   cash, carry experiment positions, or carry state from a prior fold?

3. **Candidate key.** What deterministic candidate key identifies the same grid
   candidate across folds independent of `run_id`, row order, and `sweep_id`?

4. **Risk identity after v0.1.9.** Which risk-chain fields participate in
   `session_id`, `candidate_id`, and score provenance?

5. **Selection-rule failure semantics.** What happens when the required metric
   is missing, all values are non-finite, or candidates tie?

6. **Diagnostic retention tier.** Which optional artifacts are retained for
   future PBO/DSR/CPCV work: returns, equity, sufficient stats, top-N test
   runs, all-candidate test runs, or payload references?

7. **Train metric versus test metric naming.** Are train and test scores stored
   under the same metric names with `window`, or separately named?

8. **Metric-context identity.** How does the walk-forward session record the
   metric context used for both train sweeps and test runs, especially if risk
   or benchmark context changes after v0.1.9?

---

## Editorial Notes

These are not blocking.

- Some research-input excerpts display mojibake in the current console output.
  Verify the seed file is UTF-8 clean before committing or rendering the RFC.
- Section 7.5 says "the matrix is the truth." After the score-matrix correction, use a
  less absolute phrase such as "the matrix is the default v1 evidence artifact."
- When linking to local files from the seed, use repo-root-relative paths rather
  than Markdown links that may resolve relative to the RFC directory.
- The term `candidate_id` should be reserved for deterministic identity. If it
  is just a sweep row label, call it `candidate_label`.

---

## Recommended Next Step

Do not move to synthesis yet.

Revise the seed around the six blocking corrections:

1. make windowing scope match the current run/sweep/precompute code;
2. narrow the score-matrix sufficiency claim and reserve richer diagnostic
   retention;
3. reframe anti-pattern prevention as a property of `ledgr_walk_forward()`, not
   of the entire engine;
4. bind or open the warmup/hydration/scoring/opening-state contract;
5. make walk-forward identity deterministic and independent of current
   `sweep_id`, with v0.1.9 risk identity included;
6. define deterministic v1 selection-rule semantics.

After those revisions, the seed should be close to synthesis-ready. The
architecture is directionally good. The main work is tightening overclaims so
the future spec packet does not inherit false guarantees.

