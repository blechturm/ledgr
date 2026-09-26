# RFC Seed: Point-in-Time Historical Projection For Multivariate And Fitted Methods

**Status:** Seed v1, staged as design preservation; not ready for response.
No decision, public API, implementation, release scope, or ticket is authorized
by this document.

**Date:** 2026-09-25

**Author:** ChatGPT (Seed v1). Per `../rfc_cycle.md`, the response stage should
use a different author.

**Proposed window:** v0.2.x after v0.2.0.1. This names a planning window, not an
approved release packet.

**Source baseline:** `main` at `4350e655095fb708a1b3c5e990095bc7ac5617cc`
(`Merge v0.2.0.1`); package version `0.2.0.1`.

**Cycle trigger:** several previously parked directions now depend on the same
missing capability: the accepted-but-unimplemented feature lookback primitive,
cross-sectional fitted indicators, Level-2 portfolio optimization, and the
general ML training/refit substrate. v0.2.0.0 and v0.2.0.1 have also made
point-in-time membership, session, admissibility, valuation, and availability
semantics substantially more concrete than when those directions were first
recorded.

**Evidence limitation:** the completed 2026-09-25 external prior-art research
over Qlib, zipline/zipline-reloaded, LEAN, PyBroker, vectorbt, Jesse, and
portfolioBacktest is not yet checked into `inst/design/research/`. It must be
preserved there before response-stage review if its findings are to become
load-bearing. An earlier ad-hoc strategy-state/history probe was executed during
design discussion, but it is likewise not a substitute for the prerequisite
probe required by `../spike_protocol.md`.

The response stage therefore remains closed until Section 11's probe is
recorded in the repository.

**Binding predecessors and context:**

- `../contracts.md`;
- `../spike_protocol.md`;
- `../manual/optimization_coding_style.qmd`;
- `rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`;
- `rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`;
- `rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md`;
- `rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md`;
- `../horizon.md`, especially the 2026-06-01 strategy-callback,
  2026-06-07 portfolio-optimization, 2026-06-09 cross-sectional/weight-strategy,
  2026-06-14 ML-preparedness, and 2026-09 availability entries;
- current feature/runtime-projection and availability implementations.

> This RFC uses "v1" as shorthand for a possible first implementation of the
> historical-projection capability. It does not mean ledgr v1.0.0 and does not
> create a roadmap milestone.

---

## 1. Problem And Intended Outcome

ledgr deliberately gives a strategy a point-in-time decision context. Current
bars, current feature values, current availability state, positions, cash, and
equity are exposed at one causal pulse. Instrument-local historical transforms
are normally computed as registered features and projected into that context.

Several important research methods need a different numerical shape:

```text
historical time x instruments
```

or, for model training:

```text
historical time x instruments x features
```

Examples include:

- covariance and correlation estimation;
- minimum-variance, risk-parity, and related portfolio construction;
- correlation or distance clustering and representative selection;
- PCA and other fitted cross-sectional transforms;
- cross-sectional regressions and residual models;
- rolling multivariate statistical models;
- supervised-ML training panels;
- causal expanding-window fitted transforms.

The mathematical methods are not the missing ledgr capability. R packages
already implement covariance estimators, optimizers, clustering, PCA, forests,
boosting, and other learners.

The missing architectural question is:

```text
How should ledgr project bounded historical information from the same sealed,
point-in-time world used by execution into matrix-friendly inputs for
multivariate and fitted methods, without creating a second causal data path,
silently filling absence, repeatedly querying storage, persisting large market
panels as strategy state, or moving statistical methodology into the engine?
```

Success is not "add a history dataframe." Success is one causal historical
substrate that can support several consumers while preserving ledgr's existing
execution, availability, identity, and performance boundaries.

---

## 2. This Is Not Greenfield: The Deferred `ctx$window()` Decision

The accepted
`rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md` already
decided that a lookback primitive is needed.

Its Direction 5.4 accepted, but did not implement, a first contract with:

- one feature per call;
- an `n_inst x lookback` numeric matrix;
- rows in `ctx$universe` order;
- columns oldest to current;
- leading `NA_real_` at early pulses;
- feature `stable_after` semantics retained rather than duplicated;
- no first-pass multi-feature tensor.

It explicitly named covariance, risk parity, PCA, and policy state as intended
uses. Direction 5.5 separately deferred full-panel export and training surfaces
to a later research-layer cycle.

That split is now the direct predecessor of this RFC.

This cycle must not silently replace it. The eventual synthesis must either:

1. preserve the accepted strategy-facing lookback contract as a thin view over
   the broader historical substrate; or
2. explicitly supersede it before implementation because point-in-time
   availability, training parity, or the shared-substrate design requires a
   different public contract.

The absence of a shipped `ctx$window()` makes revision affordable under the
pre-CRAN posture. The accepted predecessor still has to be dispositioned
explicitly.

---

## 3. Binding Architectural Inputs

### 3.1 One causal world

Historical consumers must derive from the same sealed snapshot and
point-in-time fact semantics as execution. An optimizer, clusterer, or training
export must not reconstruct a parallel market history with different universe,
session, or availability rules.

No second execution engine is introduced. Statistical methods ultimately
produce features, predictions, weights, or targets; fills still pass through
the existing fold core.

### 3.2 Availability remains semantic, not rectangular

v0.2.0.0 established that the economic world is not defined by whether a
numeric matrix cell happens to exist.

Relevant distinctions include, depending on the consumer:

- point-in-time membership;
- expected session;
- actual observation;
- admissibility/restriction;
- feature validity;
- valuation eligibility and mark age;
- execution eligibility.

A rectangular historical view may use `NA` numerically, but rectangular shape
or `NA` alone must not become the source of those meanings.

### 3.3 Statistical treatment is not an engine policy

ledgr may expose that a historical value is absent or unavailable and why.

It must not silently choose:

- complete-case deletion;
- pairwise covariance;
- shrinkage;
- imputation;
- normalization;
- minimum-history thresholds;
- clustering method;
- optimizer;
- learner.

Those choices belong to estimator/model/research code or adapters.

### 3.4 Fitting regime remains the important boundary

The 2026-06-14 ML-preparedness direction distinguishes:

- **causally re-estimated transforms**, whose state is recomputed from trailing
  or expanding admissible history and may belong to ledgr's
  feature/historical substrate; and
- **frozen-on-train transforms**, whose fitted state belongs to the model recipe
  and must be applied unchanged out of sample.

The same mathematical operation may belong to either side depending on its
fitting regime.

This RFC must preserve that distinction rather than classifying algorithms by
name.

---

## 4. Prior-Art Direction, Without Importing Competitor Semantics

The completed prior-art pass found no single architecture suitable for ledgr.

The useful patterns are complementary:

- Zipline Pipeline demonstrates declared lookback dependencies,
  date-by-asset workspaces, masks, dependency-directed computation, and bounded
  materialization.
- Qlib demonstrates separation of raw, learning, and inference views together
  with fitted processing state.
- LEAN demonstrates why repeated history retrieval in a runtime callback is a
  performance anti-pattern and why bounded maintained history is useful.
- PyBroker demonstrates explicit training/test and lookahead boundaries around
  fitted models.
- vectorbt demonstrates that rolling matrix-wide numerical computation is a
  natural and efficient consumer shape once the panel is valid.
- Jesse demonstrates modern preloaded/warm-up historical arrays and
  event-oriented handling of irregular per-route histories, while also showing
  that symbol-local event history is not itself a cross-asset statistical
  panel.
- portfolioBacktest demonstrates a useful separation between optimization
  cadence and rebalance cadence.

The research does **not** authorize copying any framework's missing-data,
fill-forward, dataset, or execution policy.

The common implication to challenge in this RFC is narrower:

```text
causal source evidence
        |
        v
bounded prepared historical projection
        |
        +--> current/rolling statistical computation
        +--> fitted cross-sectional artifact
        +--> portfolio estimator / optimizer
        +--> training-panel materialization
```

Model libraries remain external.

---

## 5. Current Substrate And The Architectural Question

The accepted feature-projection work already treats registered feature values
as matrix-like runtime projections rather than rebuilding a full long table per
pulse. Current decision-time feature APIs consume those projections.

The first architectural question is therefore **not** whether ledgr can invent
a matrix type.

It is:

> Can the existing runtime feature-projection machinery become the numerical
> backing for historical multivariate views under both dense and
> availability-aware execution, or does availability require a lower shared
> historical projector beneath the current feature engine?

This question must be answered before public history or training-panel APIs are
designed.

Two coherent directions are in scope:

### Direction A -- extend/reuse the existing projection substrate

Registered features remain the prepared historical numerical planes.
A lookback view slices those planes by pulse and instrument axis. Training and
other full-history consumers use the same prepared values through separate
export/materialization surfaces.

This is the lower-machinery direction and preserves the accepted
feature-projection architecture if availability semantics can be represented
without rebuilding a second history path.

### Direction B -- introduce one lower shared historical projector

If the current projection cannot represent point-in-time ragged history
without duplicating availability logic or reconstructing bars/features, create
one lower projection owner used by both:

- current feature projection; and
- future historical/training consumers.

This is not permission for parallel "feature history" and "ML history"
subsystems. The lower projector would exist precisely to prevent them.

The RFC should reject an architecture in which each consumer independently
queries or reconstructs snapshot history.

---

## 6. Proposed Consumer Boundaries

The seed proposes three consumer classes to keep distinct even if they share
one internal projection.

### 6.1 Strategy-time bounded lookback

Small or scheduled statistical strategies may need a historical matrix at a
decision point:

```text
registered return feature
        |
        v
last 252 sessions x current eligible assets
        |
        v
covariance / clustering / PCA
        |
        v
weights or target intent
```

The accepted `ctx$window()` direction is the starting public shape for this
consumer.

The RFC must decide whether availability metadata accompanies that matrix
directly, through a companion view, or through another bounded contract. The
numeric matrix alone must not silently encode all availability meanings.

### 6.2 Fitted cross-sectional artifacts

Clustering, PCA, fitted factor transforms, and similar procedures may refit
monthly or quarterly and then emit current-pulse values until the next fit.

Their fitted state is distinct from the raw historical window and may depend
on:

- fit cutoff/window;
- eligible population;
- input feature fingerprints;
- method and parameters;
- random seed where applicable;
- refit schedule.

The artifact identity/lifecycle belongs to the fitted-method or future ML
cycle. This RFC owns only the historical projection it consumes and the
handoff boundary.

### 6.3 Training-panel materialization

Supervised ML needs a flat or otherwise model-ready historical panel containing
multiple feature planes and, separately, training-only forward labels.

Training export must reuse the same causal feature/history semantics as
runtime prediction so train/predict skew is not created by separate
implementations.

Forward-label construction, embargo, overlapping-label weighting, model
storage, and model deployment remain in the dedicated ML architecture cycle.
This RFC must not absorb them merely because they consume history.

---

## 7. Historical Cell And Axis Semantics

A future rectangular view needs two separate questions answered:

```text
What numeric value is present?
What did that cell mean at that historical instant?
```

The first implementation must not infer the second from the first.

The response should test whether existing availability evidence is sufficient
to derive the historical distinctions required by consumers without adding a
second availability vocabulary.

At minimum the design must account for the difference between:

- outside the applicable point-in-time member/decision domain;
- inside the domain with an accepted observation;
- inside the domain without usable observation;
- feature unavailable because its causal warm-up/history is incomplete;
- value usable only under a valuation/staleness policy.

The exact encoding is deliberately open. This seed does not choose multiple
boolean matrices, packed flags, reason codes, sparse coordinates, or another
representation.

The asset axis is also open. The RFC must bind how a historical view relates to:

- the current strategy decision axis;
- current members;
- held nonmembers;
- a fixed user-declared basket; and
- assets that were historically members but are not current members.

No option may reveal future membership merely because a stable internal
superset exists.

---

## 8. Scheduling: Observe, Fit, Optimize, Rebalance

Historical data advances with the session clock. Expensive fitted work need not
run at every pulse.

Preserve the existing distinction between:

- **history update** -- causal observations/features become available;
- **fit / re-estimate / optimize** -- fitted state or target weights are
  recomputed;
- **rebalance** -- current holdings are traded toward already-selected target
  weights;
- **execution** -- ledgr's existing timing, risk, affordability, and cost
  machinery handles the requested change.

The 2026-06-09 weight-strategy direction already records that
"quarterly optimize, monthly rebalance" is a legitimate shape.

This RFC need not ship the schedule decorator or weight-strategy wrapper. It
must avoid a historical API that makes sparse refitting impossible or forces
matrix/model work on every pulse.

---

## 9. Identity And Reproducibility Boundary

A historical view that is purely derived from a sealed snapshot, current
point-in-time facts, registered feature definitions, a causal cutoff, and a
declared lookback should not become an independent mutable source of truth.

The RFC must nevertheless bind where result-affecting declarations enter
identity.

Questions include:

- Is lookback length ordinary strategy/feature parameter identity, a declared
  historical-input identity, or both depending on consumer?
- Does selecting a historical asset domain add identity beyond the existing
  universe/fact configuration?
- What projection/cache identity is needed so a prepared view cannot be reused
  across incompatible snapshot, feature, range, or availability semantics?
- Which fields belong only to a later fitted-artifact identity: estimator or
  model package/version, solver, tolerance, seed, fit window, preprocessing
  state, and refit schedule?

Do not solve model identity by hashing a large materialized training matrix if
the same identity can be expressed from canonical inputs and a deterministic
materialization contract.

Stochastic fitted methods remain subject to the existing seed discipline.
Stored-model replay versus exact retraining remains the dedicated ML cycle's
decision.

---

## 10. Performance And Representation Constraints

The optimization coding style and accepted feature-projection direction apply.

The first implementation must not normalize any of these as the ordinary
runtime path:

- database history queries from every strategy pulse;
- R-level iteration over instruments x pulses to rebuild windows;
- full-panel long-data materialization merely to recover a matrix;
- carrying market history inside `state_update`;
- serializing the same rolling market panel as strategy state every pulse;
- independent history caches for portfolio, clustering, and ML consumers.

Prepare and index once where practical. Numeric matrices or similarly compact
primitive arrays are appropriate consumer boundaries for R statistical code.

This seed deliberately does **not** decide the physical representation behind
that boundary. Full prepared arrays, bounded maintained state, or another
prepared representation require measurement rather than intuition.

Cold snapshot preparation and warm research iteration must remain separately
measurable under `../spike_protocol.md`.

---

## 11. Required Pre-Response Probe

The cycle does not advance to response until the spike-protocol prerequisite is
recorded.

Use:

```text
dev/spikes/historical-projection/probe.R
dev/spikes/historical-projection/probe_findings.md
```

The probe answers exactly one question:

> **Can the current runtime feature-projection path supply the numerical backing
> for a causal single-feature lookback under both current dense execution and
> availability-aware execution without per-pulse database access, persisted
> strategy-history state, or a second independently computed feature series?**

The cheaper prerequisite is already bound by the accepted projection
synthesis: registered feature series are the canonical prepared numerical
feature path. The probe tests whether the availability implementation preserved
a reusable seam for historical slicing.

The probe should use the smallest executable dense and availability-aware
fixtures capable of exposing a disagreement. Do not pre-author a storage
comparison, benchmark matrix, or expected-answer catalogue.

**Kill condition:** if availability-aware execution cannot derive the historical
lookback from the existing prepared projection without reconstructing a
parallel bar/feature history or losing required availability meaning, stop.
Do not compare storage representations. Recharter the later spike around the
lower shared-projector question.

If the answer is yes, record that finding and open the response stage. The RFC
can then focus on the public consumer/identity contract instead of inventing a
new storage architecture.

This seed does not charter the subsequent comparative spike. Any later spike
follows `../spike_protocol.md` after this prerequisite is answered.

---

## 12. Response-Stage Brief

After Section 11 closes green, the different-author response should challenge
at most these five questions:

1. **Predecessor disposition:** can the accepted single-feature
   `ctx$window()` contract survive as the strategy-facing view over the shared
   historical substrate, including availability-aware runs, or must it be
   superseded before implementation?

2. **One substrate, several consumers:** can strategy lookback,
   cross-sectional fitted methods, and later training-panel export share one
   causal projection implementation without forcing their public APIs or
   artifact lifecycles to be identical?

3. **Historical semantics:** does the proposed value-plus-semantic-evidence
   boundary preserve membership, observation, warm-up, staleness, and
   admissibility distinctions without making ledgr choose statistical
   missing-data policy?

4. **Identity boundary:** are projection, cache, strategy-parameter, and
   fitted-artifact identities separated cleanly enough that a different fit,
   solver, window, universe, or dependency version cannot masquerade as the
   same research result?

5. **Minimum first implementation:** what is the smallest public surface that
   enables a real multivariate statistical strategy without prematurely
   shipping ML lifecycle, portfolio-optimizer adapters, multi-feature tensors,
   or a general history-query language?

The response should verify load-bearing claims against current code and
accepted syntheses. It should record disagreements rather than writing
implementation code or a spec packet.

---

## 13. Scope Boundaries And Non-Goals

In scope for this RFC:

- the shared point-in-time historical projection boundary;
- disposition of the deferred `ctx$window()` direction;
- historical value/availability semantics;
- strategy-time bounded lookback;
- common substrate for later fitted-artifact and training-panel consumers;
- projection/cache identity boundaries;
- fit/rebalance compatibility at the substrate level;
- performance constraints on historical materialization.

Out of scope:

- native portfolio optimizers;
- native covariance, clustering, PCA, or ML algorithms;
- a general solver dispatch system;
- a model registry or MLOps platform;
- forward-label/embargo implementation;
- imputation defaults or fitted preprocessing implementations;
- external PIT regressor snapshot design;
- corporate-action or terminal-event accounting;
- Level-3 multi-strategy capital allocation;
- short financing, leverage, margin, liquidity, OMS, or order-lifecycle work;
- live-feed storage and streaming bad-data policy;
- a generic arbitrary SQL/history query language in strategy callbacks.

This RFC may create a predecessor for the parked portfolio-construction and ML
clusters. It does not pull those clusters into the same implementation packet.

---

## 14. Proposed Acceptance Shape

A later synthesis should be considered successful only if it leaves the spec
writer with a bounded architecture rather than a list of aspirations.

At minimum it should bind:

- the owner of causal historical projection;
- the relationship to existing feature/runtime projection;
- the fate of the accepted `ctx$window()` direction;
- the numerical and semantic contract of a bounded strategy lookback;
- how the design behaves with availability-aware changing universes;
- what training/fitted-method consumers reuse and what remains outside scope;
- identity/cache ownership;
- the forbidden runtime anti-patterns;
- the prerequisite evidence for any physical-representation optimization.

Physical storage choice, fitted-model implementation, and statistical
missing-data policy should remain outside the synthesis unless evidence in this
cycle makes one of them necessary to the minimum contract.

---

## 15. Next Action

Do not implement a history API and do not request the response yet.

First:

1. preserve the completed external prior-art review as a durable
   `inst/design/research/` artifact and link it from this seed; and
2. run and record the single prerequisite probe in Section 11.

If that probe closes green, request the response-stage adversarial review using
Section 12.

If it closes red, the result is not "history is unsupported." It means the
current feature projection is not the correct shared owner. Re-scope the next
probe around the lower historical-projector seam before adding public API.

No current release is blocked by this staged seed.