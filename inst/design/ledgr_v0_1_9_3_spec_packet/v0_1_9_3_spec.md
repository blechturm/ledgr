# ledgr v0.1.9.3 Spec

**Status:** Draft for Claude / maintainer review.
**Target Branch:** `v0.1.9.3`.
**Scope:** Third packet in the v0.1.9.x four-tick arc. Ship the target-risk
boundary: phased pulse planning needed for portfolio-level decisions, a classed
chainable risk-step surface, worker-safe risk plans, deterministic risk-chain
identity, and run/sweep/promotion provenance that v0.1.9.4 walk-forward can
consume.
**Ticket state:** Draft tickets `LDG-2597` through `LDG-2611` are cut for
Claude / maintainer review. Implementation has not started.
**Non-scope for this pass:** Arbitrary user-supplied risk functions, public or
private net-affordability / cash-floor enforcement, research order-policy
chains, liquidity/capacity policy, partial fills, no-fill rules, round lots,
minimum trade value, participation limits, broker/exchange policy, OMS
lifecycle semantics, walk-forward implementation, selection-integrity
diagnostics, target-construction helper expansion, covariance/beta constraints,
benchmark-relative risk, cost-grid sweep composition, financing, margin,
short-selling semantics, taxes, non-spot accounting models, and compiled-core
architecture changes.

---

## 0. Source Inputs

Authoritative inputs:

- `inst/design/contracts.md`
- `inst/design/README.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/horizon.md`
- `inst/design/rfc_cycle.md`
- `inst/design/release_ci_playbook.md`

Accepted target-risk design:

- `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`

Forward dependencies and cross-cycle obligations:

- `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`
- `inst/design/rfc/rfc_sweep_artifact_persistence_v0_1_9_x_synthesis.md`
- `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`
- `inst/design/rfc/rfc_execution_policy_pipeline_audit_signal_north_star.md`

Relevant horizon entries:

- `2026-05-27 [risk] Affordability belongs in target risk`
- `2026-06-05 [planning] v0.1.9.x line sequencing -- four-tick arc culminating in walk-forward`
- `2026-06-05 [planning] v0.1.9.4 walk-forward Section 17 gate-row obligations from the v0.1.9.x arc`
- `2026-05-28 [execution] Fold-core structural debt before OMS/risk/intraday`
- `2026-06-09 [research] Selection-session archive / evaluation registry is parked, not committed`

Completed packet inputs:

- `inst/design/ledgr_v0_1_8_8_spec_packet/`
- `inst/design/ledgr_v0_1_8_9_spec_packet/`
- `inst/design/ledgr_v0_1_8_10_spec_packet/`
- `inst/design/ledgr_v0_1_8_11_spec_packet/`
- `inst/design/ledgr_v0_1_9_1_spec_packet/`
- `inst/design/ledgr_v0_1_9_2_spec_packet/`

---

## 1. Thesis

v0.1.9.3 introduces the target-risk layer without turning risk into portfolio
optimization, liquidity policy, cost application, or OMS behavior.

The strategy contract remains:

```text
strategy(ctx, params) -> full named numeric target quantities
```

Target risk is a deterministic transform and validation boundary over those
target quantities:

```text
strategy targets
  -> target validation
  -> risk chain
  -> target validation
  -> fill timing
  -> cost resolution
  -> canonical events
```

This packet also pays down the per-pulse structural debt that blocks
portfolio-level decisions. The current instrument-by-instrument fill loop is
too interleaved for risk and affordability:

```text
instrument delta -> proposal -> cost -> event -> state mutation
```

The target execution shape is phased at pulse scope:

```text
strategy targets
  -> target validation
  -> risk chain over targets
  -> target validation
  -> plan deltas for all instruments
  -> build all timing proposals
  -> resolve all costs
  -> net feasibility / diagnostics
  -> emit events
  -> apply state changes atomically
```

The phased pulse is required even when the first public risk steps are simple.
It prevents future portfolio-level decisions from depending on instrument
iteration order and gives v0.1.9.4 walk-forward a stable `risk_chain_hash`
identity component rather than a stubbed placeholder.

---

## 2. Release Goals

v0.1.9.3 has seven planning goals.

### Phased Pulse Substrate

1. Restructure the fold's per-pulse fill path so the engine can plan all
   instrument deltas before emitting events or mutating cash/positions. This is
   a behavior-preserving substrate when no risk chain is supplied.

2. Preserve run/sweep parity. `ledgr_run()` and `ledgr_sweep()` must still
   share one fold core and agree on target validation, pulse order, fill timing,
   cost resolution, event semantics, final-bar no-fill behavior, accounting, and
   metric summaries.

### Public Target-Risk Surface

3. Add classed ledgr risk-step objects and `ledgr_risk_chain()`. v1 accepts
   ledgr-owned classed objects only. Arbitrary risk functions remain deferred
   until source/captured-object fingerprinting and preflight-equivalent
   classification are designed.

4. Ship the minimum public adapter set from the accepted synthesis:

   - `ledgr_risk_long_only()`
   - `ledgr_risk_max_weight(max_weight)`

5. Treat risk steps as target transforms. They receive complete named target
   quantities and return complete named target quantities. The final post-risk
   target vector is validated before timing or cost resolution.

### Identity And Provenance

6. Add deterministic risk-chain identity:

   - `risk_chain_hash`
   - `risk_plan_json`

   These fields are execution identity. They belong in committed run config,
   sweep candidate provenance, saved sweep artifacts, promotion context, and
   future walk-forward candidate/session identity.

7. Add worker-safe compiled risk plans resolved once per candidate fold. Plans
   are plain serializable value objects, safe for Windows PSOCK workers, with no
   live DB connections, external pointers, active bindings, or mutable reference
   state.

---

## 3. Public API

### Constructors

The public v1 surface is:

```r
ledgr_risk_chain(...)
ledgr_risk_long_only()
ledgr_risk_max_weight(max_weight)
ledgr_risk_none()
```

`ledgr_risk_none()` is the explicit identity constructor for no risk transform.
It is equivalent to omitting `risk_chain` for execution behavior, but its hash
and legacy/null semantics are specified in Section 5.

Example:

```r
risk <- ledgr_risk_chain(
  ledgr_risk_long_only(),
  ledgr_risk_max_weight(0.20)
)

exp <- ledgr_experiment(
  store = "artifacts/ledgr_store.duckdb",
  snapshot = snapshot,
  strategy = strategy,
  features = features,
  timing_model = ledgr_timing_next_open(),
  cost_model = ledgr_cost_zero(),
  risk_chain = risk
)
```

### Parameterized Risk

Risk constructors may accept `ledgr_param("name")` for scalar arguments where
the implementation already has established parameter-grid semantics.

Example:

```r
grid <- ledgr_param_grid(max_weight = c(0.10, 0.20))

risk <- ledgr_risk_chain(
  ledgr_risk_max_weight(ledgr_param("max_weight"))
)
```

Candidate-varying values remain in the existing candidate `params` payload.
The risk plan records the chain structure and parameter references; resolved
candidate values are not duplicated into a separate `risk_params` column.

### Experiment Entry Point

`ledgr_experiment()` gains:

```r
risk_chain = ledgr_risk_none()
```

The default must preserve current behavior except for additional explicit
identity/provenance fields. There is no implicit max-weight, long-only, or
cash-floor behavior.

---

## 4. Risk-Step Semantics

### Common Contract

Every v1 risk step compiles to:

```text
type_id
schema_version
fixed arguments
parameter references
ordered child steps where applicable
```

At execution time each step behaves as:

```r
risk_step(targets, ctx, params) -> targets
```

The engine validates:

- `targets` is a named numeric vector;
- names exactly match the experiment universe in canonical order;
- no missing, extra, duplicate, unnamed, non-finite, or non-numeric entries;
- the returned vector is complete and aligned after every chain application.

The post-risk validation error class must be distinguishable from the original
strategy-output validation error.

### `ledgr_risk_long_only()`

`ledgr_risk_long_only()` enforces the v0.1.x no-short public posture by mapping
negative target quantities to zero before fill timing.

If the current target validator already rejects negative targets on all public
paths by implementation time, this step is still retained as an explicit
portable risk-chain identity component. It may become a no-op for ordinary
long-only workflows but must continue to validate deterministically.

### `ledgr_risk_max_weight(max_weight)`

`ledgr_risk_max_weight(max_weight)` constrains target exposure per instrument
using decision-time portfolio state. The v1 definition is:

```text
abs(target_quantity * decision_price) <= max_weight * decision_equity
```

where:

- `decision_price` is the current pulse decision-time price already available
  to strategy helpers;
- `decision_equity` is the decision-time equity surface already exposed to
  strategy helpers;
- `max_weight` is a finite scalar in `(0, 1]`;
- quantities are capped by reducing absolute target quantity only as needed to
  satisfy the cap, preserving the strategy's intended target direction;
- the step must not introduce negative quantities when combined with
  `ledgr_risk_long_only()`.

The step is a target transform, not a fill allocator. It must not inspect
next-bar OHLCV, execution prices, cost resolver outputs, retained returns,
candidate rankings, or future fold data.

### Review Decision: Affordability

The horizon and roadmap identify affordability as a real risk concern:
negative cash after deterministic fills is reproducible but not a declared
margin model. They also identify a structural constraint: a cash feasibility
check must be net across one pulse's proposed fills, not sequential per
instrument, because same-pulse sells can fund same-pulse buys.

This draft deliberately separates two concepts for review:

1. **Public target-risk transforms** remain pure `targets -> targets` per the
   accepted synthesis.
2. **Pulse-level net feasibility** is an execution guard over the batched
   fill-intent plan after timing and cost have been resolved, before events are
   emitted and state is mutated.

The v0.1.9.3 draft recommendation is:

- ship the phased-pulse substrate required for net feasibility;
- reserve an internal net-feasibility hook over the batch plan, implemented as
  a no-op in this packet;
- do not expose `ledgr_risk_cash_floor()` as a public constructor in the first
  ticket cut;
- do not ship a private net-cash feasibility gate in this packet;
- preserve current default behavior with `risk_chain = ledgr_risk_none()` until
  a caller opts into public risk steps.

A future affordability RFC must decide whether affordability is:

- a public v0.1.9.3 risk step;
- a private fail-closed feasibility gate only;
- a warning-only diagnostic;
- a proportional buy-scaling rule;
- a documented deferral after the phased-pulse substrate lands.

For v0.1.9.3, affordability enforcement is deferred after the phased-pulse
substrate lands. No ticket should implement a private cash gate, silent
buy-scaling, or sequential per-instrument cash checks. Any of those would encode
misleading behavior at the most load-bearing part of the release.

---

## 5. Identity

Risk identity follows the same object-plan discipline as the v0.1.9.1 cost API.

```text
risk_chain_hash      deterministic SHA-256 hash of the public risk object
risk_plan_json       canonical JSON of the compiled worker-safe risk plan
```

`risk_chain_hash` is derived from canonical JSON of:

```text
risk_schema_version
top-level type_id
ordered risk steps
per-step type_id
per-step schema_version
fixed arguments
parameter references by name
```

Candidate-specific parameter values participate in existing candidate parameter
identity. They are not duplicated as a separate risk-parameter identity layer.

### Null And Legacy Rule

The v0.1.9.3 identity rule is:

- omitted `risk_chain`;
- explicit `risk_chain = NULL`; and
- explicit `risk_chain = ledgr_risk_none()`

all resolve to the same compiled no-op risk plan and the same
`risk_chain_hash` for new configs.

Pre-v0.1.9.3 stored configs without any risk fields reopen as this no-op risk
plan. The compatibility normalizer runs at reopen time and modern comparison
time, not by rewriting stored historical rows. It inserts the no-op plan before
hashing so pre-v0.1.9.3 stored `config_hash` values remain historically honest,
while modern hash comparisons see "no risk" as the same logical execution
configuration.

All compiled `risk_plan_json` values must be byte-stable and reconstructable
from package code, canonical plan metadata, candidate params where referenced,
and the experiment universe. The no-op plan is the compatibility floor, not a
special case with weaker requirements for non-empty chains.

### Config Hash

Risk identity is execution identity. `config_hash` must include
`risk_chain_hash` after v0.1.9.3 normalization.

Metric context remains orthogonal: metric context affects analysis, not fills
or events. Cost identity remains separate: cost models price fill proposals and
fees; risk chains transform targets before timing/cost. The reserved
net-feasibility hook is a no-op in v0.1.9.3 and does not participate in
identity until a future design accepts concrete feasibility behavior.

### Walk-Forward Handoff

v0.1.9.4 walk-forward must consume the exact risk identity defined here. It
must not redesign risk identity.

After v0.1.9.3, the walk-forward identity recipes use:

```text
walk_forward candidate_key includes risk_chain_hash
walk_forward session_id    includes risk_chain_hash
```

The v0.1.9.4 packet also has a recorded cost-identity obligation from
v0.1.9.1. Risk and cost are distinct identity components and both must
participate in walk-forward candidate/session identity.

---

## 6. Fold-Core Integration

### Current Problem

The old per-instrument loop interleaves event construction and state mutation:

```text
for each instrument:
  delta
  timing proposal
  cost resolution
  event
  apply cash/position state
```

This makes portfolio-level risk and net feasibility sensitive to instrument
order. It also prevents clean batch diagnostics because no complete pulse plan
exists before some state has already mutated.

### Target Shape

v0.1.9.3 introduces a pulse plan value object, private to the fold core:

```text
pulse_plan
  pulse timestamp
  pre-risk targets
  post-risk targets
  per-instrument deltas
  timing proposals
  cost-resolved fill intents
  net cash delta
  warnings / diagnostics
```

The plan is ephemeral. It is not a new persisted artifact. Events remain the
canonical evidence.

The fold must:

1. construct strategy context using decision-time data only;
2. call the strategy;
3. validate strategy targets;
4. apply the risk plan;
5. validate post-risk targets;
6. compute all target deltas;
7. produce timing proposals;
8. resolve costs;
9. pass through the reserved net-feasibility hook, which is a no-op in
   v0.1.9.3;
10. emit all events for the pulse;
11. apply cash, position, lot, and state changes atomically.

If the final pulse has no next bar, no fill proposals are produced and no
fill/cost/risk feasibility work should create events.

### Parity Gate

The phased-pulse substrate must land first with `ledgr_risk_none()` and pass
reference parity before behavior-changing risk steps are enabled.

Parity evidence must cover:

- committed run path;
- sequential sweep path;
- parallel sweep path where available;
- memory-backed sweep path;
- ordinary R accounting and any enabled compiled-spot-FIFO accounting path
  under `compiled_accounting_model`, with Section 10 fail-closed posture if
  parity cannot be preserved;
- retained sweep returns from v0.1.9.2;
- ordinary cost models from v0.1.9.1;
- final-bar no-fill behavior;
- warnings and candidate failure association;
- event stream reconstruction for fills, trades, equity, and metrics.

---

## 7. Sweep, Saved Sweeps, And Promotion

Risk-chain identity must be present wherever candidate/run identity is already
carried.

### Sweep Result Rows

Sweep candidate rows must include or carry through provenance:

```text
risk_chain_hash
risk_plan_json
```

For v0.1.9.3, both `risk_chain_hash` and `risk_plan_json` are scalar
`sweep_candidates` columns. `risk_chain_hash` is also stored on the parent
`sweeps` row when the sweep uses one experiment-level risk chain, mirroring the
v0.1.9.1 cost-identity placement. If a future release admits candidate-varying
risk-chain structure beyond parameter references, it must revisit this storage
shape rather than overloading v0.1.9.3 columns.

Risk-chain construction or application failures become candidate failures when
`stop_on_error = FALSE`. Row order remains grid order. Seed derivation remains
independent of risk execution order.

### Saved Sweep Artifacts

`ledgr_sweep_save()` must persist risk identity for every candidate in the
saved sweep artifact. Optional retained returns remain non-identity and do not
alter risk identity.

v0.1.9.3 saved sweeps use `sweep_schema_version = 2`. Schema 2 adds
`risk_chain_hash` and `risk_plan_json` to `sweeps` and `sweep_candidates`.
`risk_plan_json` is one of the canonical JSON columns governed by the same
byte-equivalent round-trip rule as the v0.1.9.2 `*_json` columns.

v0.1.9.2 schema-1 saved sweeps reopen under the no-op risk compatibility
normalizer. Missing risk fields are interpreted as the no-op risk plan at reopen
time; stored schema-1 artifacts are not rewritten. If a schema-1 saved sweep
cannot be normalized unambiguously, `ledgr_sweep_open()` must fail closed with
the existing schema-incompatibility path rather than inventing risk identity.

`ledgr_sweep_open()` must reconstruct candidate objects with the same
`risk_chain_hash` and enough plan/provenance to call `ledgr_promote()` through
the ordinary re-execution path.

### Promotion

`ledgr_promote()` must pass the selected candidate's risk chain into
`ledgr_run()`. Promotion context must record:

- source sweep identity;
- selected candidate identity;
- `risk_chain_hash`;
- `risk_plan_json` or a canonical reference to it;
- provenance JSON round-trip confirmation when a reopened-sweep candidate
  carrying `risk_plan_json` is promoted through `ledgr_promote()` to
  `ledgr_run()`;
- the user note / selection view fields already required by the promotion
  contract.

Promotion still re-executes. Stored scalar rows or retained return rows do not
become committed runs.

---

## 8. Worker And Parallel Safety

Risk plans must be safe to serialize into sweep workers. The plan may be
compiled once per candidate setup, but not rebuilt per pulse.

Worker-safe means:

- plain R lists/vectors/scalars only;
- no closures in durable identity;
- no DBI connections;
- no external pointers;
- no active bindings;
- no mutable environments;
- deterministic reconstruction from package code, candidate params, and the
  serialized plan.

Parallel candidate dispatch remains candidate-level dispatch over the shared
fold core. Workers must not write durable risk artifacts directly. The
orchestrator owns result binding, row order, warning/error association, saved
sweep writes, and promotion artifacts.

---

## 9. Failure Classes

v0.1.9.3 must distinguish risk-chain failures through R condition classes and
candidate `error_class` / `error_msg` fields. It does not add a schema-level
`failure_type` enum column. A failure-type column is deferred to a coordinated
failure-schema RFC so it can align with later walk-forward classification
surfaces instead of creating a second ad hoc taxonomy.

Error classes should include:

- `ledgr_invalid_risk_chain`
- `ledgr_invalid_risk_step`
- `ledgr_invalid_risk_param`
- `ledgr_risk_step_error`
- `ledgr_risk_validation_error`
- `ledgr_risk_plan_reconstruction_error`
- `ledgr_risk_identity_mismatch`

The post-risk validation error class must be distinguishable from the original
strategy-output validation error. Risk-chain condition classes must survive
ordinary run errors, sweep candidate failures with `stop_on_error = FALSE`, and
saved-sweep reopen / promotion paths.

---

## 10. Compiled Accounting And Hot-Path Constraints

v0.1.9.3 does not add a new compiled fold core and does not expand
`compiled_accounting_model`. The scoped v0.1.8.10 B2 spot-FIFO accelerator
remains an optional memory-backed sweep accounting path. The canonical R fold
path remains the reference.

Risk-chain behavior must be tested against the canonical R path first. If a
compiled accounting path cannot preserve risk-chain parity, the compiled path
must fail closed or opt out for risk-enabled sweeps until parity exists. It must
not silently skip risk or apply a different risk plan.

Performance goals are secondary to semantic correctness. The phased-pulse
substrate should avoid obvious per-pulse allocation mistakes, but this packet is
not a broad primitive-internals or collapse optimization release.

---

## 11. Documentation

Documentation must teach layer boundaries:

- strategies declare desired target quantities;
- target risk transforms target quantities;
- timing models decide when fills are proposed;
- cost models price fill proposals and fees;
- liquidity/capacity can later refuse or mutate fill quantities;
- OMS later owns order lifecycle and broker reconciliation.

Required docs:

- risk-chain help page with examples;
- long-only and max-weight help pages;
- metrics-and-accounting or execution article update explaining risk versus
  cost and liquidity;
- sweep docs update showing risk identity in sweep candidates and saved sweeps;
- reproducibility / identity docs update for `risk_chain_hash` and
  `risk_plan_json`;
- NEWS entry explaining the new risk boundary and explicit non-scope.

Docs must not imply:

- portfolio optimization;
- broker-grade risk controls;
- leverage/margin model;
- short-selling support;
- liquidity/capacity modeling;
- OMS/paper/live readiness;
- automatic candidate selection or validation.

---

## 12. Test Requirements

The ticket cut must include tests for:

- no-op risk chain preserves existing run/sweep parity;
- phased pulse emits the same canonical events as the old loop on reference
  workloads;
- risk chain validates classed steps only;
- arbitrary functions are rejected;
- `ledgr_risk_long_only()` transforms or validates negative targets as bound;
- `ledgr_risk_max_weight()` caps target exposure deterministically;
- post-risk target validation rejects missing, extra, duplicate, unnamed,
  non-finite, or misordered targets;
- `risk_chain_hash` is deterministic across reconstruction;
- `risk_plan_json` is canonical and reconstructable;
- omitted/NULL/no-op risk identity normalizes as specified;
- config hash includes risk identity for modern configs;
- pre-v0.1.9.3 no-risk configs reopen through the compatibility normalizer;
- sweep candidate rows and saved sweeps retain risk identity;
- v0.1.9.3 saved sweeps write `sweep_schema_version = 2` and persist
  `risk_chain_hash` / `risk_plan_json` on `sweeps` and `sweep_candidates`;
- v0.1.9.2 schema-1 saved sweeps reopen with no-op risk identity through the
  compatibility normalizer or fail closed when normalization is ambiguous;
- promotion re-executes with the selected candidate's risk chain;
- reopened-sweep promotion round-trips risk provenance JSON through
  `ledgr_promote()` to `ledgr_run()`;
- `stop_on_error = FALSE` records risk failures as candidate failures;
- parallel sweep serialization works or fails loudly if backend support is
  unavailable;
- memory-backed sweep either preserves risk parity or fails closed for
  unsupported compiled/accounting modes;
- final-bar no-fill behavior does not emit risk/cost/fill artifacts;
- same-pulse rebalancing tests prove the phased-pulse substrate is
  order-independent and no sequential per-instrument feasibility rejection is
  introduced.

---

## 13. Release Gate

The release-gate ticket must read and cite:

- `inst/design/release_ci_playbook.md`;
- `inst/design/contracts.md`;
- this spec;
- the active `v0_1_9_3_tickets.md` and `tickets.yml` once cut.

Local release-gate evidence must include:

- targeted risk tests;
- full `testthat::test_local()` run;
- README cold-start check;
- coverage check;
- package build and `R CMD check --no-manual --no-build-vignettes`;
- pkgdown build if docs or examples changed;
- CI branch checks before merge/tag.

If the release gate discovers broad docs/example/API migration work, the gate
must pause and route that work into a reviewed pre-release batch instead of
absorbing it into the release-gate commit.

---

## 14. Explicit Deferrals

Deferred out of v0.1.9.3:

- arbitrary user-supplied risk callbacks;
- custom risk contexts exposed as public API;
- public or private net-affordability / cash-floor enforcement;
- order-policy chains;
- liquidity/capacity policy;
- min trade value and round-lot helpers;
- participation caps;
- partial fills;
- no-fill policy rows;
- broker/exchange templates;
- OMS lifecycle semantics;
- walk-forward implementation;
- selection-integrity diagnostics;
- evaluation registry / selection-session archive;
- target-construction helper expansion;
- covariance, beta, and benchmark-aware risk constraints;
- PortfolioAnalytics or PerformanceAnalytics adapters;
- cost-estimation helper public API;
- cost/liquidity/risk grid composition;
- margin, leverage, financing, taxes, and short-selling semantics;
- durable compiled fold-core expansion.

Standing future-context obligation: if ledgr later introduces a risk-specific
context, that design must specify field by field which strategy-context fields
are exposed, which are excluded, and how helpers such as `ctx$hold()` behave
under the narrower context. This carries forward
`rfc_chainable_risk_oms_policy_boundary_synthesis.md` Section 6 item 10.

---

## 15. Review Decisions Before Ticket Cut

The first Claude review found no architectural blocker and bound these
amendments before ticket cut:

1. v0.1.9.3 remains one packet after narrowing scope. It ships phased-pulse
   substrate, classed risk-chain API, long-only / max-weight adapters,
   deterministic risk identity, worker-safe risk plans, and condition classes.

2. Affordability enforcement is deferred. The packet reserves the pulse-level
   hook but does not ship a public `ledgr_risk_cash_floor()`, a private
   net-cash gate, silent buy scaling, or sequential per-instrument cash checks.

3. `risk_chain_hash` and `risk_plan_json` are the accepted two-field identity
   pattern, mirroring `cost_model_hash` and `cost_plan_json`.

4. Omitted `risk_chain`, `risk_chain = NULL`, and
   `risk_chain = ledgr_risk_none()` normalize to the same no-op risk plan for
   new configs. Pre-v0.1.9.3 stored configs are normalized at reopen/modern
   comparison time, not rewritten.

5. All compiled `risk_plan_json` values, not only the no-op plan, must be
   byte-stable and reconstructable.

6. v0.1.9.3 saved sweeps use `sweep_schema_version = 2` and store
   `risk_chain_hash` / `risk_plan_json` on `sweeps` and `sweep_candidates`.
   Schema-1 v0.1.9.2 saved sweeps reopen through the no-op risk normalizer or
   fail closed if normalization is ambiguous.

7. Risk failures ship as R condition classes and existing `error_class` /
   `error_msg` values. A schema-level `failure_type` enum column is deferred to
   a coordinated failure-schema RFC.

8. Compiled spot-FIFO / memory-backed paths must preserve risk parity or fail
   closed for risk-enabled sweeps. They must not silently skip risk.

9. `ledgr_risk_max_weight()` ticket cut must verify that the existing
   decision-time price/equity surfaces are sufficient; if they are not, the
   ticket must narrow or defer the adapter rather than invent a public
   risk-specific context in implementation.

10. Ticket cut should proceed from this narrowed spec; no new RFC cycle is
    required unless implementation wants to reopen affordability enforcement,
    arbitrary user callbacks, risk-specific context, liquidity, OMS, or
    failure-schema design.
