# Decision-Focused Learning UX Probe

**Status:** Completed non-binding ML-architecture evidence.

**Date:** 2026-10-05

**Related baseline:**
[`research_strategy_ux_brief.md`](research_strategy_ux_brief.md)

## 1. Question

Can decision-focused or differentiable portfolio learning consume ledgr's
proposed causal history and return identified portfolio intent without making
the portfolio-construction boundary responsible for trained-model lifecycle?

This probe is separate from
[`portfolio_method_ux_exercises.md`](portfolio_method_ux_exercises.md).
Training or model-management gaps do not count as failures of the portfolio
method UX.

## 2. Baseline Kept Under Test

At decision time, the preferred boundary remains:

```text
causal ledgr input -> external fitted model -> identified weights
                   -> ledgr targets -> execution and accounting
```

Do not redesign the history object, matrix bridge, external schedule or target
conversion unless a concrete decision-time failure requires it.

## 3. ML-Specific Questions

The probe must distinguish:

1. observation and knowledge time for predictors;
2. labels that become knowable only later;
3. training, validation and final evaluation intervals;
4. refit schedule and embargo;
5. model, solver and preprocessing identity;
6. fitted-artifact storage or reconstruction;
7. worker reconstruction and random seeds;
8. differentiation through constraints and solver failures; and
9. decision-time estimation exclusion, allocation output and execution intent.

The primary source and one concrete maintained implementation, if one exists,
must be verified before writing a workflow.

The starting source is [Decision-Focused Learning for Mean-Variance Portfolio
Optimization via KKT-Based Reformulation](https://arxiv.org/abs/2609.21427).
It is a discovery input, not an accepted description of the method or its
implementation.

## 4. Probe Shape

Record:

- the shortest honest training workflow;
- the shortest honest decision-time strategy;
- which inputs ledgr can supply through accepted or proposed public surfaces;
- which lifecycle facts belong to a later ML contract;
- which ordinary package objects remain outside ledgr;
- the smallest public API failure, if any; and
- whether that failure belongs to history, portfolio construction or ML.

Do not propose a model registry, fitted-imputer system, training-frame type or
generic differentiable-solver API merely because one implementation exposes
one.

## 5. Verdict And Routing

Use one result:

- decision-time portfolio boundary succeeds; ML lifecycle remains later;
- history or identity boundary fails for a concrete reason;
- target conversion fails for a concrete reason; or
- the method is outside current product scope.

Route training, refitting, preprocessing, embargo, fitted-model identity and
artifact lifecycle to the parked ML architecture RFC. Route only a demonstrated
decision-time allocation problem to portfolio construction.

This probe changes no contract, ticket or release commitment.

## 6. Verified Source And Implementation

The primary source is Nosaka, Ikeda and Takano,
[Decision-Focused Learning for Mean-Variance Portfolio Optimization via
KKT-Based Reformulation](https://arxiv.org/abs/2609.21427), arXiv v1 submitted
2026-09-18 and accepted at PRICAI 2026. It was retrieved on 2026-10-05.

The paper trains asset-wise linear expected-return models by minimizing the
downstream constrained MVO decision loss. It replaces each lower-level
long-only, fully invested MVO problem with necessary and sufficient KKT
conditions under a positive-definite covariance assumption. The resulting
single-level problem is nonconvex because of complementarity. A squared
regularizer anchors model parameters to a reference solution.

The reported implementation uses Pyomo, KNITRO 15.0 for DFL-KKT, Clarabel
0.11.1 for decision-time MVO, and qpth for one comparator. The paper reports a
20,000-iteration and 500-second cap per DFL-KKT solve and warm-starts from its
IPO-CF comparator. These are concrete solver choices, not ledgr surfaces.

No author-maintained code repository or package for this exact method was
linked from the arXiv record as retrieved. The paper is therefore the
implementation specification for this probe; no invented package API is used.

## 7. Shortest Honest Training Workflow

The paper uses monthly ETF returns from January 2003 through December 2025.
Predictors at a rebalance are 1-, 3- and 12-month average returns and 12-month
volatility. Each model uses the most recent 48 months, explicitly excludes the
current period's not-yet-known target, refits monthly, selects regularization
on January 2011 through December 2015, and evaluates finally on January 2016
through December 2025. These details are reported in the paper's
[experimental setup](https://arxiv.org/html/2609.21427v1#S3.SS1).

The honest workflow is outside `ledgr_run()`:

```r
# ORDINARY ML/SOLVER WORKFLOW. NONE OF THESE ARE LEDGR HELPERS.
# 1. For each historical training decision, build predictors at that cutoff.
# 2. Attach the next-period return only after its label-availability time.
# 3. Split training, validation and final evaluation chronologically.
# 4. Fit DFL-KKT with fixed solver, initialization and regularization policy.
# 5. Freeze the fitted artifact and the facts ledgr cannot know.
fitted <- fit_dfl_kkt_placeholder(training_rows, validation_rows,
                                  solver_policy, seed_policy)
```

`fit_dfl_kkt_placeholder()` is descriptive pseudocode. It does not name a
package function or proposed ledgr API.

### Predictor and label clocks

The feature row for historical decision `s` must use information knowable at
`s`. Its one-period-ahead return label becomes knowable only after the next
period closes. Merely shifting a return column is not enough unless the
builder also enforces those knowledge times.

The proposed decision-time history object is evaluated at its invoking cutoff.
At a later training cutoff it may legitimately expose a correction that was not
knowable at an earlier sample decision. Therefore an exact causal training set
cannot blindly treat one current-cutoff history panel as all historical
decision-time feature rows. It needs either:

1. a later ML training-frame facility that evaluates each row at its own
   cutoff; or
2. an external, frozen causal training dataset with equivalent evidence.

This is a concrete training-lifecycle requirement. It does not invalidate the
decision-time portfolio history or justify changing its matrix bridge.

### Embargo and splitting

The paper excludes the current-period label and separates validation from final
evaluation chronologically. It does not specify a generic embargo contract.
Its one-month, non-overlapping labels need at least the stated label delay. A
different target horizon, overlapping labels or cross-validation scheme may
require a longer embargo. That interval is ML research policy and must be part
of the training identity; it is not a strategy schedule.

### Fitted identity and reconstruction

Reconstruction needs the training/validation intervals, per-row cutoff rule,
feature and label definitions, universe, covariance procedure, risk-aversion
and regularization values, reference/warm-start solution, solver versions and
tolerances, code identity, and any random seeds. ledgr's snapshot and run
hashes should be referenced, not duplicated. Artifact storage, loading, worker
reconstruction and compatibility belong to the parked ML architecture route.

## 8. Shortest Honest Decision-Time Strategy

At a decision date, the fitted model only needs causal predictors, then returns
predicted expected returns to an ordinary constrained MVO solver. The paper's
covariance is an oracle-approximating shrinkage estimate over an exponentially
weighted 48-month return window. That calculation remains ordinary estimator
code.

```r
# PROPOSED v0.2.2: causal history, identity and exclusion evidence.
h <- ledgr_history_frame(ctx, feature = "monthly_return", lookback = 48L,
                         na_action = "drop_instruments")
x <- ledgr_history_matrix(h)

# EXTERNAL FITTED ARTIFACT AND ORDINARY SOLVER; NOT LEDGR HELPERS.
features <- make_dfl_predictors_placeholder(x)
mu_hat <- predict(fitted_model, newdata = features)
w <- solve_long_only_mvo_placeholder(h, mu_hat, params$risk_aversion)

# SHIPPED: execution conversion from already identified weights.
w |> ledgr_target_rebalance(ctx, keep = held_excluded)
```

The two `_placeholder()` functions are descriptive adapter boundaries. The
solver adapter validates its result against the history identity and returns
`ledgr_weights`; strategy code does not recover names manually. The history
and matrix names remain proposed v0.2.2 surfaces.
`ledgr_target_rebalance()` is shipped. `held_excluded` is an ordinary explicit
execution-policy result; no exclusion accessor is claimed.

The fitted model predicts only for included instruments. Estimation exclusion
is retained from history. Returned optimizer zeros are allocation outputs.
Keeping, liquidating or refusing a held excluded instrument remains a separate
execution decision. An absent weight is not silently interpreted as an
estimation judgment.

## 9. Findings By Owner

### History and decision-time portfolio boundary

The proposed causal history and identity-preserving matrix are sufficient for
decision-time predictors, covariance estimation and named long-only output.
The fitted model and solver can remain ordinary external objects. No concrete
decision-time history, matrix or target-conversion failure was found.

Exact historical training rows do expose the per-row knowledge-cutoff issue
above. That is a training-frame requirement, not a reason to make the ordinary
decision-time history object carry labels or fitted state.

### Training and refit lifecycle

Monthly refitting, 48-month samples, validation selection, label availability,
embargo, warm starts and failure policy belong to ML orchestration. Training
inside the strategy callback would repeat expensive nonconvex work and obscure
which fitted parameters were used. It is outside the ledgr run boundary.

### Solver and differentiation

DFL-KKT does not require ledgr to differentiate through execution or through a
portfolio helper. Its KKT reformulation is solved as a nonconvex nonlinear
program. The paper's IPO-GRAD comparator differentiates through qpth, which is
also an ML/package concern. Complementarity residuals, local minima,
initialization, smoothing and solver failure belong with the fitted artifact
and training evidence.

### Artifact and resource lifecycle

The paper reports no convergence failures in its tested windows, but that does
not define a production fallback. Training may consume up to the reported
500-second per-solve cap and should be reconstructed or loaded before the run.
Parallel training, solver licensing and worker loading remain external ML
resource concerns. ledgr continues to own execution, accounting, run identity
and result persistence after identified weights enter the current context.

### Abstractions not justified

This one method does not justify a ledgr model registry, generic
training-frame type, fitted-imputer system, differentiable-solver API, label
store or universal embargo object. Those choices need the later ML architecture
comparison. It also does not justify a richer portfolio allocation result:
decision-time
weights plus explicit history exclusions and execution policy are sufficient.

## 10. Verdict And Routing

**Decision-time portfolio boundary succeeds; ML lifecycle remains later.**

The method consumes causal named history, an external fitted model and an
ordinary MVO solver, then returns identified weights through the existing
target path. The concrete unresolved work is causal training-row construction,
label and embargo policy, refit orchestration, fitted-artifact identity and
storage, solver reconstruction and training-failure behavior. Route all of it
to the parked ML architecture RFC.

Do not count those findings as portfolio-UX failures. Reopen the history route
only if the eventual ML training design proves that per-row causal cutoffs
cannot be supplied without changing the accepted two-clock semantics. Reopen
portfolio construction only if a real decision-time weight or omitted-holding
case cannot be expressed explicitly.

## 11. Progress

**State:** complete. Primary source, experimental workflow and named solver
stack verified on 2026-10-05; no maintained implementation for the exact method
was linked. Decision-time and training-time ownership were exercised
separately.
