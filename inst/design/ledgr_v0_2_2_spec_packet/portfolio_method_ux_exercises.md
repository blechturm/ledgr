# Portfolio Method UX Exercises

**Status:** Completed non-binding design evidence for v0.2.2 planning.

**Date:** 2026-10-05

**Baseline under test:**
[`research_strategy_ux_brief.md`](research_strategy_ux_brief.md)

## 1. Question

Can materially different portfolio methods be expressed honestly through the
proposed ledgr research boundary without method-specific engine machinery?

The bound baseline for this exercise is:

```text
external schedule
    -> causal classed history
    -> identity-preserving matrix or ordinary R object
    -> ordinary R or package estimator
    -> identified ledgr weights
    -> ledgr_target_rebalance()
    -> ledgr-owned execution and accounting
```

The exercise tests this architecture. It does not re-derive it from blank
design space.

## 2. Negative Success Criterion

The preferred result for a method is:

> No new ledgr abstraction is required.

Do not redesign `ledgr_history_frame()`, the identity-preserving matrix bridge,
external scheduling or the weights-to-target flow unless a concrete method
demonstrates a failure. Ordinary method arguments, data frames, matrices,
lists, formulas and package objects remain ordinary R unless repeated evidence
shows that ledgr must own something more.

A new general ledgr abstraction requires either:

1. the same gap across materially different methods; or
2. one concrete correctness, causality, identity or execution ambiguity that
   ordinary R and the proposed public boundaries cannot resolve.

Method-specific inconvenience, diagnostics or dependency setup stays in the
method adapter.

In the sketches below, `fit_*()` and `solve_*()` names denote ordinary
research-package adapters. They are illustrative, not proposed ledgr APIs.
Each adapter consumes an identity-bearing history object or matrix, validates
the package result against that identity, and returns `ledgr_weights`. Strategy
code must not recover identity manually with `colnames()` and `setNames()`.

## 3. Three Layers That Must Not Collapse

Every method exercise separates:

1. **Estimation exclusion:** an instrument is omitted from the statistical
   sample and the reason is retained.
2. **Allocation output:** the method states weights or another decision for
   the included instruments.
3. **Execution intent:** ledgr chooses whether an omitted held instrument is
   kept, liquidated or makes the rebalance refuse.

An absent weight is not silently interpreted as a zero target. The history
surface owns inclusion and exclusion evidence. The later
portfolio-construction contract owns the execution consequence.

## 4. Scope

The portfolio synthesis covers:

- global minimum variance and Markowitz mean-variance optimization;
- equal risk contribution or risk parity;
- Black-Litterman;
- hierarchical risk parity;
- nested clustered optimization;
- sparse index tracking through majorization-minimization;
- Schur complementary allocation or the Schur bridge; and
- Wasserstein distributionally robust portfolio optimization.

Decision-focused or differentiable portfolio optimization is a separate ML
probe in `decision_focused_learning_ux_probe.md`.
Its trained-model findings do not count as failures of this portfolio boundary.

The exercise evaluates product expression and ownership. It does not reproduce
the papers, certify numerical implementations or commit any method to ledgr.

## 5. Starting References

These links start source discovery. The analyst verifies the primary claim,
publication version and maintained implementation independently.

| Method | Starting reference |
| --- | --- |
| Global minimum variance and MVO | [60 years of portfolio optimization](https://www.sciencedirect.com/science/article/pii/S0377221713008898) |
| Equal risk contribution | [Maillard, Roncalli and Teiletche](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1271972) |
| Black-Litterman | [Walters](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1314585) |
| Hierarchical risk parity | [Lopez de Prado](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2708678) |
| Nested clustered optimization | [Lopez de Prado](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3469961) |
| Sparse index tracking | [Benidis, Feng and Palomar](https://palomar.home.ece.ust.hk/papers/2018/BenidisFengPalomar-TSP2018%20-%20index_tracking.pdf) |
| Schur complementary allocation | [Schur complementary portfolios](https://schur.microprediction.org/) |
| Wasserstein DRO | [Marginal and copula ambiguity](https://link.springer.com/article/10.1007/s10957-024-02550-y) |

## 6. Execution Waves

### Wave 1: common matrix-to-weights spine

1. Global minimum variance and Markowitz MVO
2. Equal risk contribution
3. Hierarchical risk parity
4. Schur complementary allocation

Synthesize the shared result before continuing.

### Wave 2: additional inputs and composition

5. Black-Litterman
6. Nested clustered optimization
7. Sparse index tracking through majorization-minimization

Synthesize again before opening the frontier method.

### Wave 3: distributional frontier

8. Wasserstein distributionally robust portfolio optimization

The clean-context analyst verifies the primary source and chooses one concrete,
maintained implementation where one exists. A paper-only method receives a
design sketch, not an invented package API. Current ledgr behavior is probed
through the smallest public API when relevant. Proposed helpers are labelled
as proposed and are not presented as executable.

## 7. Method Card

Each method records the following fields.

### Economic intent

What decision does the method produce, and how often is it normally refit?

### Concrete reference

Name the primary source, the implementation inspected and their versions or
retrieval dates. Separate a mathematical method from one library's API.

### Causal inputs and ownership

List returns, prices, benchmark, market capitalization, prior, views,
scenarios, current weights, labels and other inputs. For each, name the owner:
ledgr snapshot/history, upstream adapter, method adapter or research policy.

### Shortest honest proposed strategy

Show the strategy through the bound baseline. Do not hide timestamp removal,
name recovery, exclusion handling, fitted state or current-weight plumbing.

### Adapter boundary

State the narrow ordinary-R or package function contract between ledgr history
and the method. Decide whether identified `ledgr_weights` are sufficient; do
not assume a richer result.

### Exclusion, allocation and execution

Record the three layers separately. Include changing-universe and held-omitted
cases.

### Schedule and lifecycle

Classify the method as a stateless refit, iterative solver, warm-started
estimator, persistent online state or trained model. Scheduling remains outside
the strategy callback.

### Parameters and selection

Separate method configuration from selection. State whether sweep,
walk-forward or an external nested procedure selects it, and identify any
same-sample selection trap.

### Outputs, failures and diagnostics

Name convergence, fallback, exclusion, cluster, risk, effective-parameter or
solver evidence needed to understand the decision. Persist only evidence that
ledgr cannot reproduce from native inputs and identity.

### Reproducibility and resources

Record package and solver dependencies, randomness, parallel reconstruction,
large representations and the likely memory boundary. Do not create a second
manifest for guarantees ledgr already owns.

### Verdict

Use one primary result:

- cleanly expressible now;
- expressible under the proposed v0.2.2 history surface;
- needs the parked portfolio-construction RFC;
- needs the parked helper-bundle RFC;
- method-specific integration only; or
- incompatible with current product scope.

Name the smallest concrete failure behind any non-clean verdict.

## 8. Completed Method Cards

All implementation versions below were checked on 2026-10-05. Package calls
inside adapters are illustrative contracts. They are not ledgr APIs and are
not executable R snippets unless the named adapter is implemented.

### Wave 1: common matrix-to-weights spine

#### 8.1 Global minimum variance and Markowitz MVO

**Economic intent and lifecycle.** GMV minimizes estimated portfolio variance.
MVO trades expected return against covariance risk. Both are batch estimators
normally refit on each decision date; neither needs persistent online state.
The schedule remains outside the callback.

**Concrete reference.** The primary source is Markowitz's 1952
[Portfolio Selection](https://doi.org/10.1111/j.1540-6261.1952.tb01525.x).
The maintained implementation inspected is
[skfolio 1.4.11](https://pypi.org/project/skfolio/1.4.11/): its
[`MeanRisk`](https://skfolio.org/generated/skfolio.optimization.MeanRisk.html)
accepts observations by assets, exposes minimum-variance and mean-risk
objectives, and returns `weights_`. This is one implementation, not the
definition of MVO.

**Causal inputs and ownership.** Causal returns and their included/excluded
instrument evidence belong to ledgr history. The covariance estimator,
expected-return estimator, constraints and risk-aversion parameter are method
policy. No benchmark, current weights or external state is required for the
plain long-only cases.

**Shortest honest proposed strategy.** The orientation conversion and Python
call belong to a package adapter:

```r
# PROPOSED v0.2.2: history object, matrix bridge, exclusion evidence.
h <- ledgr_history_frame(ctx, feature = "daily_return", lookback = 252L,
                         na_action = "drop_instruments")

# ORDINARY ADAPTER, NOT A SHIPPED LEDGR HELPER.
w <- fit_skfolio_mean_risk(h, objective = "minimum_variance")

# SHIPPED: target conversion from already identified weights.
w |> ledgr_target_rebalance(ctx, keep = held_excluded)
```

`held_excluded` is an ordinary policy result derived from the proposed history
exclusion evidence and current context; no accessor name is assumed. Omitting
it means liquidation under the shipped target helper. Refusal is an ordinary
`stop()` before target construction.

**Adapter, exclusion and execution.** The adapter obtains the named numeric
observations-by-assets matrix from `h` and returns validated `ledgr_weights`.
Estimation exclusion is the history decision. Zero weights produced by the
optimizer are allocation decisions. Keeping, liquidating or refusing a held
excluded instrument is a separate execution choice. `ledgr_weights` is
sufficient.

**Parameters, diagnostics and resources.** Lookback, moment estimators,
constraints and risk aversion are configuration. Candidate selection belongs
to a sweep or temporally valid walk-forward process, never the final evaluation
sample. Record solver status and any covariance repair only if the package
result cannot be reconstructed. CVXPY and its selected solver are adapter
dependencies; matrix storage is the dominant ledgr-facing representation.

**Verdict.** **Expressible under the proposed v0.2.2 history surface.** The
only current product absence is the already-owned WS3 history and identity
bridge, not an MVO abstraction.

#### 8.2 Equal risk contribution

**Economic intent and lifecycle.** ERC chooses long-only weights whose assets
make equal contributions to portfolio volatility. It is a stateless batch
refit on each decision date, although its solver is iterative.

**Concrete reference.** Maillard, Roncalli and Teiletche define the portfolio
and its properties in the
[2010 ERC paper](https://doi.org/10.3905/jpm.2010.36.4.060).
The maintained implementation inspected is
[skfolio 1.4.11](https://pypi.org/project/skfolio/1.4.11/)
[`RiskBudgeting`][skfolio-risk-budgeting].
Its official documentation accepts observations by assets, defaults to
variance risk budgeting and returns fitted `weights_`.

**Causal inputs and ownership.** ledgr supplies causal returns and exclusion
evidence. Ordinary R computes the covariance matrix. Risk budgets, box
constraints and any covariance regularization belong to the method adapter.
Plain ERC needs neither expected returns nor current portfolio weights.

**Shortest honest proposed strategy.** Reuse the MVO history sketch, replacing
the ordinary adapter line with:

```r
# ORDINARY ADAPTER AROUND skfolio; NOT A LEDGR HELPER.
w <- fit_skfolio_risk_budgeting(h, risk_budget = "equal")
w |> ledgr_target_rebalance(ctx, keep = held_excluded)
```

**Adapter, exclusion and execution.** The adapter contract is an
identity-bearing return history, or a covariance-bearing package prior, to
validated `ledgr_weights` plus optional method diagnostics.
Statistical exclusions, returned allocation weights and the held-omitted
execution choice remain distinct. No richer result than `ledgr_weights` is
required.

**Parameters, diagnostics and resources.** Risk budgets and solver tolerances
are configuration. Select covariance and constraints out of sample.
Feasibility, convergence and realized relative risk contributions are useful
adapter diagnostics, not a generic ledgr schema. The package's compiled and
nonlinear solver dependencies are reproducibility inputs owned by the adapter.

**Verdict.** **Expressible under the proposed v0.2.2 history surface.** ERC
adds no engine requirement beyond the same causal matrix and identity bridge.

#### 8.3 Hierarchical risk parity

**Economic intent and lifecycle.** HRP clusters assets by dependence,
quasi-diagonalizes the hierarchy and recursively allocates risk. It is a
stateless batch refit on each decision date.

**Concrete reference.** López de Prado introduced HRP in
[Building Diversified Portfolios that Outperform
Out-of-Sample](https://ssrn.com/abstract=2708678).
The maintained implementation inspected is
[skfolio 1.4.11](https://pypi.org/project/skfolio/1.4.11/)
[`HierarchicalRiskParity`][skfolio-hrp],
whose `fit()` input is observations by assets and whose fitted output preserves
feature names.

**Causal inputs and ownership.** ledgr owns causal return history and exclusion
evidence. Distance choice, linkage, covariance estimator and leaf constraints
are method configuration. No current weights or trained state is intrinsic.

**Shortest honest proposed strategy.** Use the MVO history sketch, then:

```r
# ORDINARY ADAPTER AROUND skfolio; NOT A LEDGR HELPER.
w <- fit_skfolio_hrp(h, linkage = params$linkage)
w |> ledgr_target_rebalance(ctx, keep = held_excluded)
```

**Adapter, exclusion and execution.** A named return matrix to named weights is
enough. A changing included universe legitimately changes the dendrogram; that
is estimation behavior, not an execution instruction for held exclusions.

**Parameters, diagnostics and resources.** Linkage, distance and covariance
choices require out-of-sample selection. Cluster labels and ordering aid
explanation but remain reconstructible package output unless a research claim
depends on preserving them. Dendrogram and clustering objects are ordinary
package objects.

**Verdict.** **Expressible under the proposed v0.2.2 history surface.** A
hierarchy object inside ledgr is not justified.

#### 8.4 Schur complementary allocation

**Economic intent and lifecycle.** Schur allocation uses damped cross-cluster
information to bridge a hierarchical allocation and minimum variance. The
batch form is a stateless decision-date refit.

**Concrete reference.** The primary source is Cotton's
[Schur Complementary Allocation](https://arxiv.org/abs/2411.05807).
The maintained implementation inspected is
[skfolio 1.4.11](https://pypi.org/project/skfolio/1.4.11/)
[`SchurComplementary`][skfolio-schur];
the official
[tutorial](https://skfolio.org/auto_examples/clustering/plot_6_schur.html)
documents observations-by-assets input, `gamma`, failure behavior and the
conditioning issue near the minimum-variance endpoint.

**Causal inputs and ownership.** ledgr owns causal returns and exclusions.
Covariance, distance, clustering, `gamma`, conditioning and monotonicity policy
belong to the adapter. Current weights are optional only for a separate
turnover-aware variant.

**Shortest honest proposed strategy.** Use the common history sketch, then:

```r
# ORDINARY ADAPTER AROUND skfolio; NOT A LEDGR HELPER.
w <- fit_skfolio_schur(h, gamma = params$gamma)
w |> ledgr_target_rebalance(ctx, keep = held_excluded)
```

**Adapter, exclusion and execution.** Identified weights are sufficient.
Estimation exclusions cannot be collapsed into zero allocation weights. The
same explicit keep, liquidation or refusal choice applies.

**Parameters, diagnostics and resources.** `gamma` and lookback are candidate
parameters and must be chosen by sweep or walk-forward evidence, not the final
performance interval. Effective `gamma`, covariance conditioning, monotonicity
fallback and solver failure are adapter diagnostics. Package locking and parity
evidence are integration concerns.

**Verdict.** **Method-specific integration only.** The method fits the proposed
history-to-weights boundary; no Schur engine surface or solver adapter is
justified.

#### Wave 1 synthesis

All four methods use the same causal named return matrix, ordinary estimator
call, identified weights and ledgr target conversion. Iterative optimization,
clustering and Schur conditioning remain local package behavior. The repeated
product need is the already-planned WS3 history object with matrix identity and
exclusion evidence. Ordinary R plus the shipped `keep` argument can express the
three execution choices, so repetition does not yet justify an
allocation-result class. No method requires current weights, nested engine
state or a catalogue.

### Wave 2: additional inputs and composition

#### 8.5 Black-Litterman

**Economic intent and lifecycle.** Black-Litterman combines an equilibrium or
other prior with absolute or relative views, then sends posterior moments to a
portfolio optimizer. It is a composed, stateless decision-date refit.

**Concrete reference.** Black and Litterman's primary published account is
[Global Portfolio Optimization](https://doi.org/10.2469/faj.v48.n5.28).
The maintained implementation inspected is
[skfolio 1.4.11](https://pypi.org/project/skfolio/1.4.11/)
[`BlackLitterman`][skfolio-black-litterman],
which fits returns, named views and confidences and produces a posterior return
distribution for an optimizer.

**Causal inputs and ownership.** ledgr supplies causal returns and exclusions.
Point-in-time market capitalizations, benchmark/risk-aversion inputs and view
publication or model times belong to upstream adapters. View construction,
confidence, prior choice and asset-group mappings are research policy. The
adapter must not admit a view known after the decision cutoff.

**Shortest honest proposed strategy.** After constructing `x` as in Wave 1:

```r
# ORDINARY POINT-IN-TIME INPUTS from a frozen upstream adapter.
bl_inputs <- views_known_at(ctx$ts_utc, history = h)

# ORDINARY PACKAGE ADAPTER; NOT A LEDGR HELPER.
w <- fit_skfolio_black_litterman(h, views = bl_inputs$views,
                                 confidence = bl_inputs$confidence)
w |> ledgr_target_rebalance(ctx, keep = held_excluded)
```

`views_known_at()` is an adapter sketch, not a shipped or proposed ledgr name.
It must freeze acquisition provenance and apply the decision-time knowledge
cutoff before the method adapter aligns views to the included identities.

**Adapter, exclusion and execution.** Named returns, prior inputs and views go
in; named weights come out. A view naming an excluded asset must be explicitly
removed, remapped or rejected by policy. That estimation choice does not choose
what happens to a held excluded asset at execution.

**Parameters, diagnostics and resources.** Prior, `tau`, confidence and the
downstream objective are configuration. Select them on temporally separate
evidence. Preserve vendor acquisition and view timestamps because ledgr cannot
know them; posterior moments and picking matrices are reproducible diagnostics.

**Verdict.** **Expressible under the proposed v0.2.2 history surface.** The
additional clocks belong to the data/view adapter, not a multi-input history
object or ledgr Black-Litterman type.

#### 8.6 Nested clustered optimization

**Economic intent and lifecycle.** NCO clusters assets, estimates
within-cluster portfolios and then estimates an across-cluster portfolio. It
is a nested but still batch estimator, normally refit on each decision date.

**Concrete reference.** López de Prado introduced NCO in
[A Robust Estimator of the Efficient
Frontier](https://ssrn.com/abstract=3469961).
The maintained implementation inspected is
[skfolio 1.4.11](https://pypi.org/project/skfolio/1.4.11/)
[`NestedClustersOptimization`][skfolio-nco].
It composes inner and outer estimators and can use out-of-sample inner
estimates for the outer fit.

**Causal inputs and ownership.** ledgr supplies one causal named return matrix
and exclusions. Clustering, inner and outer estimators, fold construction and
constraints are method configuration. The fitted nested objects remain package
objects.

**Shortest honest proposed strategy.** Use the common history sketch, then:

```r
# ORDINARY ADAPTER; it constructs chronological folds and estimators.
w <- fit_skfolio_nco(h, n_splits = params$n_splits,
                     inner_method = params$inner_method,
                     outer_method = params$outer_method)
w |> ledgr_target_rebalance(ctx, keep = held_excluded)
```

**Adapter, exclusion and execution.** The nested composition stays behind the
same named-matrix-to-named-weights contract. Exclusions change cluster
membership but remain estimation evidence. Allocation output and held-omitted
execution policy remain separate.

**Parameters, diagnostics and resources.** Random `KFold` is not automatically
valid for ordered returns; the adapter must supply chronological or purged
splits. Tune cluster count and inner/outer choices outside final evaluation.
Cluster labels, fold failures, fallback chain and inner/outer solver status are
method diagnostics. Parallel nested fitting is a package resource concern.

**Verdict.** **Method-specific integration only.** A ledgr nested-estimator
abstraction is not justified.

#### 8.7 Sparse index tracking through majorization-minimization

**Economic intent and lifecycle.** Sparse tracking jointly selects a subset of
constituents and weights them to track a benchmark with few positions. The MM
solver is iterative inside a stateless decision-date refit.

**Concrete reference.** Benidis, Feng and Palomar describe the method in the
[2018 sparse-tracking paper](https://doi.org/10.1109/TSP.2017.2762286).
The maintained R implementation inspected is CRAN package
[`sparseIndexTracking`](https://cran.r-project.org/package=sparseIndexTracking)
0.1.1. Its linked official vignette documents `spIndexTrack(X, r, ...)`, an
assets-return matrix, a benchmark-return vector and MM-based long-only sparse
weights.

**Causal inputs and ownership.** ledgr supplies causal constituent returns
and, when the benchmark is sealed as an instrument or fact, its causal return
series. An external benchmark otherwise belongs to an upstream adapter with
acquisition provenance. Timestamp alignment, tracking measure, sparsity
penalty and upper bounds are method policy.

**Shortest honest proposed strategy.** The one-series-per-call history boundary
is sufficient:

```r
# PROPOSED v0.2.2, called separately and joined explicitly on time.
assets <- ledgr_history_frame(ctx, feature = "daily_return",
                              lookback = 252L, na_action = "keep")
benchmark <- ledgr_history_frame(ctx, feature = "daily_return",
                                 instruments = params$benchmark_id,
                                 lookback = 252L, na_action = "keep")

# ORDINARY ADAPTER around sparseIndexTracking; NOT A LEDGR HELPER.
w <- fit_sparse_tracking(assets, benchmark, lambda = params$lambda)
w |> ledgr_target_rebalance(ctx, keep = held_excluded)
```

The adapter performs the explicit time join and validates result identities.

**Adapter, exclusion and execution.** Package-produced zeros mean deliberate
allocation exclusion. Missing-history exclusions are different and retain their
reasons. A zero selected by sparsity may liquidate; an absent held instrument
still requires explicit keep, liquidate or refuse policy.

**Parameters, diagnostics and resources.** Select `lambda`, cap, loss and
lookback with nested or walk-forward evidence; choosing sparsity on the final
tracking period is leakage. Iteration count, convergence, active-set size and
tracking loss are adapter diagnostics. No current weights are needed unless a
separate turnover penalty is added.

**Verdict.** **Expressible under the proposed v0.2.2 history surface.** Two
explicit histories plus an ordinary time join are enough; a tensor or benchmark
channel is not justified.

#### Wave 2 synthesis

Black-Litterman adds point-in-time views and priors, NCO adds estimator
composition, and sparse tracking adds a benchmark series. None breaks the
baseline. The extra inputs remain named ordinary objects with explicit clocks;
the one-series history rule plus an ordinary timestamp join handles tracking.
Nested fitted objects and MM iterations stay inside adapters. The recurring
identity and exclusion need is still WS3. The recurring execution-policy
plumbing is expressible with ordinary R and the shipped target helper, so there
is still no demonstrated need for a portfolio allocation result.

### Wave 3: distributional frontier

#### 8.8 Wasserstein DRO under marginal and copula ambiguity

**Economic intent and lifecycle.** The method chooses a long-only Mean-CVaR
portfolio robust to Wasserstein ambiguity in both marginal distributions and
their copula. It is a decision-date batch solve; cutting surfaces or inner
approximations are iterative solver internals, not persistent model state.

**Concrete reference.** Fan, Ji and Lejeune's version of record is
[Distributionally Robust Portfolio Optimization under Marginal and Copula
Ambiguity](https://doi.org/10.1007/s10957-024-02550-y). It uses separate
marginal and overlapping dependence samples and proposes exact MILP,
McCormick-relaxation and inner-approximation solution routes. No maintained
public implementation of that exact marginal-and-copula model was identified.
[skfolio 1.4.11](https://pypi.org/project/skfolio/1.4.11/)
[`DistributionallyRobustCVaR`][skfolio-dro-cvar]
is a maintained regular-Wasserstein comparator, not an implementation of this
paper. The card therefore uses a paper-level adapter sketch.

**Causal inputs and ownership.** ledgr owns the causal return panel, cutoff,
identity and missingness evidence. Ambiguity radii, marginal estimators,
copula, support, CVaR level, risk aversion and approximation choice belong to
the method adapter. Solver licenses and tolerances are external dependencies.

**Shortest honest proposed strategy.** This method challenges the rectangular
matrix but does not defeat it:

```r
# PROPOSED v0.2.2: keep the common causal axis and explicit NAs.
h <- ledgr_history_frame(ctx, feature = "daily_return", lookback = Inf,
                         na_action = "keep")

# ORDINARY PAPER-LEVEL ADAPTER; NO PACKAGE OR LEDGR HELPER IS CLAIMED.
# It uses each available marginal and the aligned copula overlap.
w <- solve_marginal_copula_dro(h, radii = params$radii,
                               approximation = params$approximation)
w |> ledgr_target_rebalance(ctx, keep = held_excluded)
```

**Adapter, exclusion and execution.** `na_action = "keep"` lets ordinary R use
longer per-asset marginal samples while deriving the copula from overlapping
rows. This avoids the paper's criticized shortest-series truncation without a
ragged ledgr object. Insufficient marginal or overlap data is estimation
exclusion, not a zero target. Identified weights remain sufficient.

**Parameters, diagnostics and resources.** Radius and approximation selection
must be nested outside final evaluation. Preserve approximation gap, separation
failure, solver status and effective sample counts when they support a research
claim. The potentially large transport/MILP representation is adapter-owned;
ledgr need only supply the causal numeric panel.

**Verdict.** **Method-specific integration only.** The exact method lacks a
maintained public implementation and can be expensive, but no history,
allocation or execution failure is demonstrated.

#### Wave 3 synthesis

The frontier method's unequal marginal histories are the strongest challenge
to the matrix bridge. A common time axis with explicit missing values
preserves all observations needed for per-column marginals and overlapping
copula estimation. Ordinary R derives those samples. The specialist solver,
approximation and large transport representation remain method-local. No new
ledgr abstraction is required.

## 9. Comparative Matrix

This table records the completed cards rather than package marketing claims.

| Dimension | MVO | ERC | BL | HRP | NCO | Sparse | Schur | DRO |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Return history | required | required | required | required | required | assets + derived cluster returns | required | required, NAs retained |
| Additional point-in-time inputs | expected-return policy optional | risk budgets optional | prior, views, confidence, possibly caps | none | temporal folds | benchmark returns | none | radii, support and ambiguity policy |
| Current weights | no | no | no | no | no | no; only turnover extension | no; only turnover extension | no |
| Nested estimator | no | no | posterior then optimizer | no | yes, adapter-owned | iterative MM, not nested lifecycle | no | separation/approximation loop |
| Persistent or trained state | no | no | no | no | no | no | no | no |
| Specialist solver | convex/QP adapter | package nonlinear/convex solver | posterior plus optimizer | clustering implementation | inner and outer solvers | package MM solver | package conditioning/solver | MILP or nonlinear approximation |
| Exclusion policy material | yes | yes | yes, views must align | yes | yes, cluster membership changes | yes; sparse zero differs from absent | yes | yes, marginal and overlap counts differ |
| Diagnostics beyond weights | solver and covariance repair | feasibility and risk contributions | posterior/view alignment | clusters/order | clusters, folds and fallbacks | convergence, support size, tracking loss | effective gamma and conditioning | approximation gap, solver and sample counts |
| Fits proposed v0.2.2 boundary | yes | yes | yes | yes | yes | yes, with explicit join | yes | yes, with `na_action = "keep"` |

## 10. Cross-Method Synthesis

### Capabilities already handled

The proposed WS3 history boundary supplies every method's common need: causal
single-feature history, an identity-preserving numeric bridge, explicit
missingness and included/excluded instruments with reasons. Ordinary R is
enough to estimate moments, join a benchmark on time, split unequal marginal
samples, compose nested estimators and prepare point-in-time views. All eight
methods can return a finite identified long-only vector through shipped
`ledgr_weights()` and `ledgr_target_rebalance()`.

Scheduling remains orchestration. A current `ctx$hold()` guard is sufficient
for the WS7 proof; a scheduler decorator may avoid work if WS6 independently
earns promotion. No method requires a second execution fold.

### Recurring findings

1. **History identity and exclusion evidence recur in every method.** This is
   evidence for the already-owned WS3 surface, not a new portfolio abstraction.
2. **Held estimation exclusions require an explicit execution policy.** In a
   minimal public-function probe at commit `00b6887`, weights containing only
   `BBB` produced targets `AAA = 0, BBB = 10`; the same call with
   `keep = "AAA"` produced `AAA = 2, BBB = 9`. Thus liquidation and keep are
   already expressible, and refusal is an ordinary precondition failure. The
   missing piece is teaching and policy plumbing after history exposes the
   excluded IDs, not silent absent-weight semantics.
3. **Solver and estimator diagnostics recur, but their shapes do not.** Risk
   contributions, clusters, effective gamma, sparse support and DRO gaps are
   method-specific. Persist a diagnostic only when the research claim cannot be
   reproduced from ledgr identity plus frozen adapter inputs and code.
4. **Additional inputs recur without a common product shape.** BL views and
   caps, sparse benchmarks and DRO ambiguity policy have different owners and
   clocks. Named ordinary objects and explicit joins resolve them.

The public probe used an archived clean tree because the worktree was dirty.
Namespace installation was blocked by the local `duckdb` 1.5.2 being below the
package's 1.5.6 requirement, so the two exported functions were loaded from the
archive source. The result is narrow evidence for target semantics, not a full
package or history probe.

### Abstractions considered but not justified

- **A generic optimizer or solver catalogue:** rejected; package adapters own
  solver APIs, dependencies, tolerances and failures.
- **A ledgr covariance, clustering, hierarchy or nested-estimator type:**
  rejected; ordinary matrices and package objects carry these values.
- **A multi-feature tensor or benchmark channel:** rejected; explicit
  one-series histories and timestamp joins handle the only concrete case.
- **A ragged history representation:** rejected; the DRO method uses a common
  causal axis with explicit NAs, then ordinary per-column and overlap subsets.
- **A mandatory allocation-result class:** not justified by these methods.
  Identified weights plus history exclusion evidence and explicit `keep`,
  liquidate or refuse policy are sufficient. Reopen only if repeated shipped
  code cannot carry required exclusions or deterministic diagnostics safely.
- **A current-weights helper:** not justified by the base methods. It remains a
  later portfolio-construction question for turnover-aware variants.
- **A generic diagnostics schema:** rejected because the repeated need has no
  repeated stable shape.
- **Persistent estimator state or a model registry:** rejected for all eight
  batch methods. The separate DFL probe owns trained-model questions.
- **A method-specific Schur, NCO, sparse or DRO engine surface:** rejected;
  each is ordinary adapter integration.
- **A reusable-helper bundle as a v0.2.2 prerequisite:** rejected. It may
  improve ergonomics later, but package-qualified adapters or strategy-local
  functions can produce the next research result.

### Product verdict

**No new ledgr portfolio abstraction is required by the eight methods at the
design boundary.** The shared dependency is the already-planned WS3 causal
history, matrix identity and exclusion boundary. WS7 should prove one
long-only estimator through that path.

This is design evidence, not runnable proof of the proposed history surface.
Black-Litterman additionally depends on a frozen causal source of views. No
maintained public implementation of the exact marginal-and-copula DRO method
was identified. The only executed package-behavior probe here covered the
shipped target helper's `keep` semantics against archived source. Those limits
keep the WS7 public-path proof necessary.

The Momento application case below supplies the first concrete case in which
ordinary R can produce safe full targets but the shipped full-rebalance helper
cannot express the intended transition policy by itself. That satisfies the
portfolio-construction route's capability-evidence half. The RFC remains
parked until the public historical surface ships; this case does not make it a
v0.2.2 dependency.

The separate decision-focused-learning probe is not counted as a ninth vote.

### Application case: Momento cross-sectional momentum

The external Momento application combines a one-to-three-stage momentum
cascade, equal or inverse-volatility sizing, separate handling of entrants,
leavers, winners and losers, a ratcheting notional watermark, profit allocation
to benchmark and risk-free sleeves, separate signal and execution weekdays,
costs and application-specific diagnostics. Its current implementation is
[`momentr_app.py`][momento-app]
with the economic policy in
[`momentum_backend.py`][momento-backend].

Most of the economic policy fits the intended ledgr boundary without a
momentum-specific engine surface: causal history, ordinary R selection and
weighting, current context primitives, full targets, strategy state, the cost
chain and ledgr accounting. The cascade and dashboard remain application code.
Exact numerical reproduction is not a goal. Momento's dollar-return ledger and
same-row return application differ from ledgr's quantity, fill and next-open
chronology.

The case adds three durable inputs:

1. A full-rebalance weight helper is insufficient for selective transitions
   that sell leavers, optionally trim winners, optionally top up losers and cap
   entrants. A strategy can express these safely by starting from `ctx$hold()`
   and returning a complete target, but it must reconstruct marked exposure and
   transition policy. The portfolio-construction RFC owns whether a small
   current-portfolio or allocation-to-target boundary is justified.
2. Separate signal and execution weekdays are a two-clock scheduling case. A
   stateful strategy can preserve a signal and emit its target before the
   configured execution open, but the staged scheduler seed currently owns
   decision pulses only. The scheduler RFC must consider this case without
   making it a v1 requirement unless its own evidence justifies the scope.
3. Benchmark and risk-free buckets need no new type when they are ordinary
   tradable instruments. If one instrument must remain separately attributable
   to an active mandate and a harvested-profit sleeve, instrument-level net
   positions lose that ownership. This non-fungible-sleeve question remains in
   horizon until another workflow requires it.

Momento's current-constituent Wikipedia universe, Yahoo adjustment, price-gap
forward fill and lack of point-in-time membership are upstream adapter and data
preparation concerns, not ledgr API gaps. A ledgr application must replace them
with canonical bars and point-in-time facts. The case opens no ingestion ticket
and does not authorize silent price filling.

## 11. Routing

| Finding | Existing owner |
| --- | --- |
| Causal clocks, history identity, matrix bridge and exclusion evidence | WS3 historical-projection route |
| Recursive readiness and gap state | WS4 recursive-indicator RFC |
| One public long-only product proof | WS7 estimator proof |
| Selective transitions, current weights, allocation composition or recurring diagnostics | Parked portfolio-construction RFC after the public history surface ships; Momento supplies the concrete capability evidence |
| Separate signal and execution schedules | Parked scheduler RFC as an acceptance case, not an automatic v1 requirement |
| Non-fungible mandate or sleeve attribution | Horizon until a second workflow needs ownership beyond instrument-level net positions |
| Reusable unpackaged user estimators | Parked strategy-helper-bundle RFC |
| Package, solver or method integration | Horizon unless it becomes committed scope |
| Training, refitting, labels, embargoes and fitted-model identity | Separate ML architecture route |
| Accepted executable behavior | `contracts.md`, only after implementation |

This document changes no contract, ticket or release commitment.

## 12. Progress

| Wave | State | Evidence |
| --- | --- | --- |
| Wave 1 | complete | MVO, ERC, HRP and Schur cards plus synthesis |
| Wave 2 | complete | BL, NCO and sparse-tracking cards plus synthesis |
| Wave 3 | complete | Marginal-and-copula Wasserstein DRO card plus synthesis |

[skfolio-risk-budgeting]: https://skfolio.org/generated/skfolio.optimization.RiskBudgeting.html
[skfolio-hrp]: https://skfolio.org/generated/skfolio.optimization.HierarchicalRiskParity.html
[skfolio-schur]: https://skfolio.org/generated/skfolio.optimization.SchurComplementary.html
[skfolio-black-litterman]: https://skfolio.org/generated/skfolio.prior.BlackLitterman.html
[skfolio-nco]: https://skfolio.org/generated/skfolio.optimization.NestedClustersOptimization.html
[skfolio-dro-cvar]: https://skfolio.org/generated/skfolio.optimization.DistributionallyRobustCVaR.html
[momento-app]: https://github.com/gladio-analytics/momento/blob/b7264cd290d717b7bb3fe4f7f8a861c09529a4f4/momentr_app.py
[momento-backend]: https://github.com/gladio-analytics/momento/blob/b7264cd290d717b7bb3fe4f7f8a861c09529a4f4/momentum_backend.py
| Cross-method synthesis | complete | Recurring findings tested; rejected abstractions named |
