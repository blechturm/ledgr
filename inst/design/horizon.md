# ledgr Horizon

**Status:** Active parking lot.
**Authority:** Non-binding design memory.

This file holds design observations that are not ready for the roadmap, an ADR,
or a versioned spec packet. It is not a backlog and does not imply commitment.

Use lightweight entries only:

```text
### YYYY-MM-DD [area] Short title

Freeform note.
```

Area tags:

```text
execution, ux, data, risk, cost, research, infrastructure, adapters
```

Do not add owners, due dates, priorities, acceptance criteria, or ticket
statuses. If an item becomes planned work, promote it into the roadmap, an RFC,
an architecture note, or a spec packet.

## Open

**Current packet note (2026-06-11):** v0.1.9.4 walk-forward has closed.
v0.1.9.5 is cut and active at
`inst/design/ledgr_v0_1_9_5_spec_packet/`. Horizon entries below remain
non-binding unless a future active packet, roadmap, contracts, or an accepted
RFC promotes them.

**Promotion index (horizon → roadmap).** Where open entries have a planned
milestone. Entries not listed are pure direction with no committed home yet
(e.g. Shiny UIs, compiled fold core, strategy family guides, tidy/vectorized
authoring). When a milestone closes, sweep its entries to `## Resolved`.

- **v0.1.8.x (closed 2026-06-05).** Fold-core structural debt,
  peer-benchmark expansion, parallel dispatch, substrate / optimization
  arc, B2 spot-FIFO accelerator, and the v0.1.8.11 documentation / cleanup
  release all shipped across v0.1.8.1 through v0.1.8.11. See `## Resolved`
  for entry-by-entry closeouts.
- **v0.1.9** — affordability / target-risk layer (incl. the phased-pulse
  restructure); primitive internals and collapse planning gates.
- **v0.1.9.x** -- walk-forward (RFC accepted 2026-06-04 with Amendment 1 +
  Amendment 2 + Section 17 ticket-cut gates); validation toolkit
  (formerly "selection-integrity diagnostics"; RFC accepted 2026-06-12,
  scheduled v0.1.9.6); intraday-readiness code audit (scheduled
  v0.1.9.6, audit only); cost-model post-direction; randomized / blocked
  slice diagnostics; promotion-grade sweep artifacts; target
  construction helper extensions (Pass 2 per-stage helpers); broker /
  exchange cost templates; crypto-readiness spike; spot-FIFO as default
  for ephemeral spot workloads (candidate; see 2026-06-05 entry).
- **v0.2.x** — snapshot administration and research-loop ergonomics (sweep
  review + promotion recovery); point-in-time data tables / external regressor
  snapshots (unify in one RFC); corporate actions and instrument master;
  explicit accounting-critical event types RFC; liquidity and capacity; OMS
  semantics + snapshot lineage + live data logs; external benchmark / beta
  uses; external reference-data adapter provenance; provider risk-free
  divergence; reference strategy templates / baseline strategies; external
  package adapters (PerformanceAnalytics first); non-spot accounting
  models (futures / margin / options / FX) once derivatives architecture
  work begins.
- **v0.2.x to v0.3.0** -- live bad-data resilience, ragged-universe
  (asset-lifetime) handling, and sim-to-real backtest fidelity (direction B;
  needs a dedicated RFC).
- **Post-K1 / B2 gates** -- compiled fold core (`ledgrcore` sister
  package) functionally parked. The K1 measurement spike completed and
  the scoped v0.1.8.10 B2 spot-FIFO accelerator shipped with
  peer-validated 5x engine speedup (see
  `dev/bench/peer_benchmark/peer_benchmark.md` and the 2026-06-05
  post-LDG-2522 entry). Architecture A authorization now requires a
  workload where engine dominates more than 42% of B2-row wall AND
  results / ingestion phases approach their floors; neither condition
  currently holds. Incremental B2 expansion (per-pulse equity, durable
  path, non-spot accounting models) remains available as a v0.1.9.x+
  forward direction.

### 2026-06-13 [docs] Deferred v0.1.9.5 vignette-audit items

The 2026-06-13 vignette audit
(`inst/design/audits/v0_1_9_5_vignette_audit.md`) pulled its stale-fact fixes,
the two highest-value helpers (`ledgr_sweep_review()`, `ledgr_temp_store()`),
and the editorial cleanups into v0.1.9.5 (Batches 8A/8B/8C). The following are
deferred to a later packet:

- **Vignette splits (audit Section 6).** `sweeps.qmd` (717 lines) should split
  off its retention / save-reopen / external-metrics cluster into a companion;
  `metric-contexts-and-conventions.qmd` should split off its diagnostic
  playbook. Both are pinned in `_pkgdown.yml` navigation and
  `tests/testthat/test-documentation-contracts.R`, so a split must update those
  pins -- real work, not a drive-by patch.
- **Residual strategy-development trim (audit Section 6).** If the
  post-v0.1.9.5 "Strategy Basics" article still carries helper-pipeline
  strategy material after the Batch 8C de-duplication pass, move that material
  to the companion strategy-authoring article and leave a pointer. The v0.1.9.5
  in-scope fix is only the duplicated opening/setup and cross-link cleanup.
- **Lower-value helpers (audit Sections 3.4-3.6).** A `ledgr_target` value
  accessor (to retire `unclass(target)[["id"]]`); a `ledgr_annualization(bt)`
  accessor so hand-recomputes provably match `ledgr_compute_metrics()`; a
  vectorized feature-read / set-targets-where helper to shorten the
  `for (id in ctx$universe)` strategy loop. Take these only when the relevant
  surface is naturally touched.
- **Trades entry/exit pairing (audit Section 3.3).** A "trade" is currently a
  single close-action fill row with no paired entry/exit timestamp. Decide
  between documenting that shape clearly or adding an entry/exit-paired trades
  view. The v0.1.9.5 fix is only to correct the `execution-semantics` example
  to the real columns.

Non-commitments: these are recorded direction, not roadmap commitments; helper
names and the trades-pairing decision are illustrative.

### 2026-06-13 [execution] v0.1.9.6 intraday-readiness code audit

Scheduled for the next packet after v0.1.9.5: run a deep code review to check
whether the v0.1.x architecture is still EOD-first but intraday-tolerant, or
whether recent work introduced architectural footguns that would make future
intraday support expensive.

Scope:

- code and contract audit only; no intraday runtime implementation;
- inspect snapshot sealing, timestamp precision, pulse calendars, fold
  windows, metric annualization, feature warmup/hydration, timing/cost
  contexts, target-risk boundaries, retained return panels, sweep/walk-forward
  identity, and generated documentation examples;
- identify assumptions that are merely EOD teaching choices versus assumptions
  that have become runtime invariants;
- check whether validation-toolkit work over retained panels introduces
  cadence-specific shapes that would block later intraday windows or
  session-aware folds;
- assess the refactor size for each footgun: documentation-only, small local
  patch, packet-sized refactor, or architecture/RFC-sized refactor;
- name contract tests or audits that would prevent the same footgun from
  reappearing.

Audit output should be a versioned audit document, not a feature patch:

```text
finding -> affected surface -> why it matters for intraday ->
current severity -> refactor size -> recommended disposition
```

The expected outcome is a footgun register and refactor-size estimate that can
inform v0.1.9.x/v0.2.x scheduling. It should explicitly answer whether ledgr can
still honestly say "EOD-first, intraday-tolerant" after the v0.1.9.x arc.

Related entry: 2026-05-27 [execution] Intraday support arc and pre-v0.2.x
architectural footguns. This entry schedules the audit promised there; it does
not authorize the intraday support arc itself.

### 2026-06-13 [risk] User-defined cost and risk steps: extensibility against the identity and bounded-stance constraints

Raised during the v0.1.9.5 risk-and-cost vignette work: should ledgr give
users tooling to build their own cost and risk steps, beyond composing the
built-in allowlist?

First, a distinction the "More steps are planned" vignette callout blurs.
Shipping more **built-in** steps (the closed allowlist grows, ledgr owns and
serializes each step) is different from **user-defined** steps (the user
supplies the function). The callout promises the former; this entry is about
the latter.

The precedent exists. Indicators are already user-extensible via
`ledgr_indicator()` + the `series_fn` contract + `ledgr_indicator_register()`
/ `ledgr_indicator_dev()` + the custom-indicators vignette, with feature
fingerprints preserving identity. Custom cost/risk steps would reuse that
machinery, not invent it.

The crux is identity. Cost and risk are hash-bearing: `cost_plan_json`,
`cost_model_hash`, and `risk_chain_hash` are consumed downstream by sweep
persistence and walk-forward candidate/session identity. A built-in step
serializes to canonical `{type_id, args}`; a user closure needs
source-capture plus fingerprinting (as strategy source already does) and its
tunables forced through `ledgr_param()` so they land in the plan JSON. This is
the hard 80 percent of the work. Cost is heavier than risk because its
identity surface fans out across more consumers.

The bounded-stance tension is the deeper issue. The v0.1.9.5 risk-and-cost
vignette now teaches a sharp boundary -- risk is not portfolio optimization,
cost is not liquidity or capacity. An open function interface is the backdoor
through which a "risk step" becomes a solver and a "cost step" becomes a
market-impact model, making the deliberately bounded layers unbounded.
Indicators do not have this problem (any feature is fair game); cost and risk
are narrow on purpose. Any extensibility RFC must answer this with a
constrained contract (pure `targets -> targets` for risk; pure
`(proposal, fill_context) -> price/fee` for cost) plus preflight-style tiering
to fail closed on non-deterministic or lookahead-violating steps.

Recommended sequencing (a recommendation, not a decision):

- **Risk-step extensibility is the more natural first member.** A custom risk
  step is a strategy-shaped pure transform with `ctx` access, and the real
  long tail (sector caps, turnover, vol-targeting, gross/net exposure) is
  legitimately target transforms.
- **Cost-step extensibility is heavier; expand the built-in vocabulary
  first.** Tiered/maker-taker fees, borrow cost on shorts, and simple slippage
  are a finite set that may cover most demand without source-capture. A
  user-defined-cost API only if built-ins prove insufficient.

Related horizon entries: 2026-06-09 [risk] Palomar risk-chain constraint
expansion (the built-in convex-constraint track); 2026-06-07 portfolio
optimization scaffolding (solver dispatch); 2026-06-09 [ux] weight-strategy
wrapper (authoring surface).

Non-commitments:

- not a roadmap commitment; no public API is bound;
- the constrained-contract and preflight-tiering sketches are illustrative;
- the risk-first / cost-built-ins-first sequencing is a recommendation, not a
  resolved fork.

### 2026-06-13 [risk] Portfolio optimization placement: optimizers emit intent, but optimization is risk-flavored

Maintainer note (2026-06-13) while reviewing the risk-and-cost vignette.
Portfolio optimization is planned as a first-class capability (see the
2026-06-09 Palomar adapter family and 2026-06-07 portfolio optimization
scaffolding entries). The maintainer leans toward placing a full optimizer in
the **strategy** layer rather than the risk step, because an optimizer outputs
an intent -- target weights or holdings -- which is the strategy's job. But
many portfolio-optimization algorithms (mean-variance, minimum-variance,
risk-parity) are inherently about risk, which muddies the sharp
strategy-is-intent / risk-is-constraint distinction the vignette now teaches.

The resolution is to notice that the word "risk" is doing double duty:
risk-as-constraint-layer versus risk-as-optimization-objective. Those are
different things. A coherent architecture keeps them separate:

- the risk **chain** stays a post-intent constraint transform (what am I
  allowed to hold?), and the "risk is not portfolio optimization" boundary in
  the vignette holds verbatim;
- an **optimizer is a strategy** that produces intent, even when its objective
  is risk-derived. Its natural authoring home is the weight-strategy surface
  (2026-06-09 [ux] entry), which already outputs weights as strategy intent.

That preserves the four-layer model instead of breaking it: optimization is
intent generation that happens to use risk math, not a new optimization layer
bolted onto the risk chain.

What still needs design before the v0.2.x optimization arc:

- **Where do convex constraints live when an optimizer is the strategy?**
  Inside the optimizer's objective (the strategy), still as a post-hoc risk
  chain, or both. This interacts directly with the Palomar entry's
  convex-as-risk-step versus solver-dispatch fork.
- **Doc reconciliation.** The vignette's "risk is not portfolio optimization"
  line likely needs a companion sentence clarifying that an optimizer is a
  strategy whose intent is risk-derived, so readers do not conclude
  optimization is unsupported.
- **Vocabulary.** Avoid letting "risk step" and "risk objective" collide in
  the public API surface.

Recommendation: do not flip the risk chain into an optimization layer; place
optimizers as intent-producing strategies via the weight-strategy authoring
surface; reserve the risk chain for post-intent constraints; reconcile the
vignette framing when the optimization capability is scoped. This is the key
placement/vocabulary fork for the v0.2.x portfolio-optimization arc, named here
but not resolved.

Related horizon entries: 2026-06-09 [risk] Palomar risk-chain constraint
expansion; 2026-06-07 portfolio optimization scaffolding; 2026-06-09 [ux]
weight-strategy wrapper; and the v0.1.9.5 risk-and-cost vignette as the
bounded-layer framing to reconcile.

Non-commitments:

- not a roadmap commitment; no public API is bound;
- the optimizer-is-a-strategy placement is a recommendation, not a resolved
  decision;
- the constraint-placement and doc-reconciliation items are open design forks.

### 2026-06-13 [ux] Walk-forward degradation table curated print (shipped v0.1.9.5)

Shipped as a maintainer-directed UX fix following the vignette styleguide
Section 5 "clutter signals a missing helper" note. `wf$degradation` is now
classed `ledgr_walk_forward_degradation` with a `print` method that shows the
core train-versus-test columns -- fold, selection metric, train/test value,
absolute diff, warning flags, selected candidate -- while the object stays a
full tibble so `as_tibble()` and dplyr verbs still see every column. The
v0.1.9.5 walk-forward vignette dropped its manual `select()` boilerplate, and
`ledgr_fold_list` gained a per-fold train/test window print in the same change.

Sweep this entry to `## Resolved` at the v0.1.9.5 closeout.

### 2026-06-13 [ux] Walk-forward fold visualization helper and plotting dependency posture

The v0.1.9.5 walk-forward article added an article-local ggplot timeline that
made the train/test window contract much easier to inspect: blue train sweep
window, green selected-candidate test run, and a thin selection-boundary line.
That is a real UX signal, not just decoration. Users need a fast way to see
whether fold windows, step sizes, anchored/rolling behavior, gaps, and overlap
match what they intended before they trust walk-forward output.

Potential future surface:

```r
ledgr_plot_folds(folds)
ledgr_plot_folds(walk_forward_result)
```

This should stay non-binding until a visualization / reporting surface is
scoped. Open design choices:

- whether ledgr exports plotting helpers at all, or keeps returning plain data
  frames and teaches plots in articles;
- whether `ggplot2` stays in `Suggests` with `rlang::check_installed()` at
  plotting entry points, or becomes a core dependency because plotting and
  tables are part of the expected research workflow;
- whether interactive output such as `plotly` belongs only in optional adapter
  surfaces rather than core;
- whether the first plotting family is folds only, or includes equity curves,
  drawdowns, sweep heatmaps, degradation tables, retained-return panels, and
  run-inspection tear sheets;
- whether plotting helpers return ordinary `ggplot` objects so users can add
  themes, scales, and labels without ledgr owning a closed charting system.

Current bias: native ggplot helpers are likely the right R-native default once
visualization is scoped, with optional adapters for richer or interactive
surfaces. That does not imply promoting `ggplot2` to `Imports` yet. Treat the
dependency posture as part of the future visualization/reporting RFC, alongside
table output and the existing external-package adapter plan.

### 2026-06-12 [evaluation] Per-fold train-sweep PBO column in the walk-forward degradation table

Parked at maintainer request during the validation-toolkit D1 resolution
(2026-06-12): "honestly pretty interesting in its own right."

Every walk-forward fold runs a sweep internally -- the train-window
sweep IS the selection event. Once two predecessors land, CSCV/PBO can
run per fold on each train window's candidate return panel, yielding a
per-fold selection-fragility score surfaced as a degradation-table
column (indicatively `train_pbo`):

```text
fold_seq  selected     train_metric  test_metric  train_pbo
1         fast_10_40   1.31          0.94         0.18
2         fast_10_40   1.42          1.10         0.22
3         fast_5_20    1.55          1.21         0.81   <- distrust:
                                                            winner came
                                                            from a noisy
                                                            selection
```

The degradation table then carries not just IS -> OOS metric drift but
the trustworthiness of each fold's selection event. Diagnoses two
things nothing else surfaces: folds whose good test results came from
fragile selections (lucky picks from noise), and regime windows where
the candidate space loses structure (train_pbo rising across
consecutive folds is a regime-shift signal on the SELECTION layer, not
the returns).

Dependencies, in order:

1. **Validation toolkit ships** (in-flight cycle): the CSCV/PBO
   machinery over retained panels, per the D1 A-prime resolution --
   sweep-level PBO is the per-fold building block.
2. **Walk-forward `fold_seq` return retention** (the deferred half of
   the original Option A; recorded fast-follow of the toolkit cycle):
   per-candidate per-period returns per train window.
3. **Degradation-table extension**: Amendment 2 Section 16.5 binds the
   operational table fields; adding `train_pbo` is additive but the
   print contract should be extended deliberately (small amendment or
   an additive-columns allowance), not silently.

Indicative slot: a small evaluation tick after the validation toolkit
ships, bundled with the `fold_seq` retention fast-follow it depends on.

Non-commitments: not a roadmap commitment; no public API or column name
bound; the sketch is illustrative; per-fold PBO interpretation caveats
(few folds, short train windows -> wide PBO uncertainty) are a design
question for the eventual cycle, not assumed away here.

### 2026-06-11 [audit] Vignette screening for the v0.1.9.5 teaching cycle

A full screening of all twelve installed vignettes (~6,400 lines) completed
at v0.1.9.4 close, reviewed against `vignette_styleguide.md`, the v0.1.8.5 /
v0.1.8.11 teachability precedents, and the R for Data Science north star.
Full verdicts, split designs, missing-vignette list, and consumption order
are recorded in `inst/design/audits/v0_1_9_4_vignette_screening_audit.md`.

Routing summary:

- **v0.1.9.4 release gate (Batch 9 / LDG-2626), not v0.1.9.5:** three stale
  vignette references, including one actively wrong callout in
  `execution-semantics.qmd` that tells readers the public cost API is still
  planned while the chunk below it uses the shipped v0.1.9.1 API. These are
  exactly the styleguide Section 12 release-gate checks.
- **v0.1.9.5 split pairs (concept + technical details):**
  strategy-development, indicators, metrics-and-accounting, and
  experiment-store each split into a concept article plus a
  technical-details article; the sweeps split is a borderline cut-line
  candidate. The experiment-store split also creates the "Data Input And
  Snapshots" article the v0.1.8.5 reading flow named but never built.
- **Missing vignettes confirmed or proposed:** risk-and-cost execution
  policy (largest hole - v0.1.9.3 target-risk shipped with no vignette
  home), executable walk-forward research arc, a ~150-line quickstart
  ("whole game" on-ramp), and an optional consolidated debugging article.
- **Sequencing constraint:** the API-naming-consistency rename batch
  (`rfc/rfc_api_naming_consistency_v0_1_9_5_seed.md`) must land before the
  vignette batches so new articles teach the final vocabulary exactly once.
- **R4DS assessment:** the teaching surface can match the north star; the
  styleguide already encodes the load-bearing R4DS principles, and the
  split plan IS the R4DS whole-game -> tools -> deeper-topics architecture.

This entry records direction and routing; the v0.1.9.5 spec packet binds
final shape. Sweep this entry to `## Resolved` when the v0.1.9.5 packet
consumes the audit.

### 2026-06-11 [audit] Deep code review findings for the next release cycle

A deep code review pass over the engine core, accounting, identity, and
persistence layers completed at v0.1.9.4 close. Full findings, severities,
file/line references, and suggested fixes are recorded in
`inst/design/audits/v0_1_9_4_deep_code_review_audit.md`. None block the
v0.1.9.4 release gate; all are tracked for the next release cycle
(v0.1.9.5 is the natural home for most).

Severity summary:

- **Blocker (1).** B-1: unprotected SEXP during string-vector construction
  in `src/spot_fifo.cpp` output assembly -- GC use-after-free risk under
  allocation pressure, exactly the large-batch workloads the compiled
  spot-FIFO accelerator targets. Ten-line fix (anchor vectors in the
  protected output list before filling). Should land before any benchmark
  re-record that exercises the compiled path at scale.
- **High (3).** H-1: single-pulse runs crash with a bare unclassed
  subscript error in `backtest-runner.R`. H-2: R lot accounting fails
  silent-open on invalid fill input while the C++ kernel fails closed;
  align R to fail-closed. H-3: `ledgr_time_elapsed` magnitude heuristic
  divides by 1e9 for any run longer than ~1000 seconds, corrupting
  persisted `run_telemetry.elapsed_sec` for multi-hour sweeps.
- **Medium (7).** Legacy full-spread resolver deletion (M-1), C++ scalar
  TYPEOF hardening (M-2), `cpp11::stop` instead of `Rf_error` (M-3),
  fractional-quantity dust lots as a contract decision (M-4, pairs with
  the whole-second contract precedent), per-fill DB roundtrips in db_live
  mode (M-5), snapshot-hash timestamp representation pinning (M-6, hash
  stability across driver upgrades), notional-fee rounding-order binding
  (M-7).
- **Nits (6).** Double meta_json parse in replay, O(n^2) lot packing,
  int32 event_seq bound, absolute delta tolerance, JSON cache eviction
  accounting, slow-path features_wide loop.

The audit also records do-not-regress positives: four-path accounting
parity (canonical durable / ephemeral / compiled / replay) with identical
Kahan summation in R and C++, the validate-then-reorder target contract
that makes the R and C++ fill loops provably equivalent, chunk-invariant
streaming snapshot hashing, and the marked no-lookahead boundary in the
fold engine.

Promotion path: B-1/H-1/H-2/H-3 plus the kernel-hygiene mediums (M-1, M-2,
M-3) fit a small hardening batch early in v0.1.9.5. M-4 and M-6 are
contract-binding decisions that belong in the v0.1.9.5 contracts audit
proper. M-5, M-7, and the nits ride along as entropy items.

### 2026-06-11 [strategy] Unscheduled strategy-family gaps: intra-bar exits, lot-selection policies, time-accrual costs, and the unscoped shorting contract

A 2026-06-11 sweep of the horizon, roadmap, and RFC corpus against a
strategy-family taxonomy asked: which strategy classes are neither
architecturally supported nor scheduled for an RFC? Most families are
covered, deliberately excluded, or already parked (weight strategies,
ML-first, portfolio optimization, multi-strategy allocation, PIT
regressors, derivatives/futures/FX under the non-spot umbrella, ragged
universes, crypto spike; intraday/HFT is a permanent non-goal). Four
genuine gaps remain. This entry parks them with routing so the relevant
future cycles inherit them instead of rediscovering them.

### Gap 1 -- Intra-bar protective-exit semantics (the stop-loss family)

The largest unscheduled family. Strategies whose definition includes hard
intra-bar exits -- trend-following with stops, breakout strategies with
bracket exits, take-profit and trailing-stop families -- cannot be
expressed honestly today. Pulse-granularity approximation (observe breach
at close, exit at next open) is a materially different strategy when the
economics live in the stop discipline. The pieces exist around the gap:
OHLC bars support the standard conservative intra-bar trigger simulation
(worst-case fill within the bar range); the execution-policy north star
(`rfc/rfc_execution_policy_pipeline_audit_signal_north_star.md`) has an
"order policy / sizing" pipeline stage where this belongs; and the
2026-06-07 MAE/MFE excursion entry plans stop *calibration* analytics
with no stop *execution* semantics to calibrate for. The OMS synthesis
correctly keeps strategies as target-vector functions, which means
protective exits must be an execution-policy declaration, not strategy
code -- and that declaration surface is undesigned.

**Routing:** scope inside the execution-policy pipeline arc (order-policy
stage), not as a fresh seam. Conservative intra-bar fill bounds and their
determinism contract are the core design questions.

### Gap 2 -- Lot-selection and tax-aware accounting policies

FIFO is hardcoded into both accounting paths (it is in the kernel's
name). Strategies and workflows that depend on which lots close -- HIFO,
specific-lot identification, tax-loss harvesting -- are unsupported and
appear nowhere in the corpus. The closed accounting enum's error message
says future accounting models require a separate RFC, but no entry
records lot-selection policy as a candidate family. For the retail / PM
audience, tax-aware rebalancing is a strategy class, not an accounting
nicety.

**Routing:** the accounting-model RFC family (the same seam the closed
`compiled_accounting_model` enum reserves). Lot-selection policy is an
accounting-policy axis orthogonal to the compiled-vs-canonical axis; an
RFC must decide whether policy is per-run identity (hash-bearing) and
how R/C++ parity extends to non-FIFO policies.

### Gap 3 -- Time-accrual cost events (interest, borrow, funding)

The cost API is fill-event-based by design: costs resolve on accepted
fill proposals. An entire cost family accrues on balances over time
instead: interest on idle cash, borrow fees on short positions,
perpetual-futures funding payments, margin interest. No entry names the
accrual family, and two scheduled items collide with it head-on: the
crypto-readiness spike (perps are economically defined by funding
payments) and the shorting gate (short backtests without borrow costs
systematically flatter every market-neutral result). This is an
event-grammar question -- a ledger event type driven by time rather than
fills.

**Routing:** the v0.2.x "explicit accounting-critical event types" RFC
is the natural home; the crypto-readiness spike and the shorting
contract RFC (Gap 4) must both name it as a dependency when they open.

### Gap 4 -- The shorting/leverage contract RFC is a gate without a seed

Referenced three times as a predecessor gate (long-short authoring
helpers; Palomar dollar-neutral / market-neutral / leverage
constraints), but it has no entry of its own scoping what it must bind.
The engine mechanically tolerates negative targets and the FIFO kernel
already handles short lots correctly, so the temptation will be to
"just allow it" -- when the actual contract questions are: short
proceeds cash treatment, borrow availability and cost (Gap 3), margin /
maintenance semantics for equities distinct from the derivatives arc,
and what `ledgr_risk_long_only()` defaulting means once shorting is
legal. Risk if left unscoped: v0.2.x Palomar constraint scoping arrives
and finds its named predecessor is an empty pointer. Pairs / statistical
arbitrage -- a headline strategy family -- sits entirely behind this
gap plus Gap 3.

**Routing:** give the shorting/leverage contract RFC its own seed-shape
entry (or seed) before v0.2.x Palomar constraint scoping begins; bind
the Gap 3 dependency explicitly in that seed.

### Non-commitments

- this entry authorizes nothing; it records gaps and routing;
- no public API, event schema, or accounting semantics are bound here;
- gap priority ordering is left to the cycles that consume them
  (execution-policy arc, accounting-model RFC family, accounting-event
  RFC, v0.2.x Palomar scoping);
- "not scheduled" claims are as of 2026-06-11; sweep this entry against
  the corpus before citing it in a future packet.

### 2026-06-11 [adapters] Canonical run return stream helper before reporting adapters

The v0.1.9.2 retained-sweep surface gives sweeps a canonical return-series
projection through `ledgr_sweep_returns()` and `ledgr_sweep_returns_wide()`.
Single committed runs do not yet have the symmetric helper; users derive
adjacent returns manually from `ledgr_results(bt, what = "equity")`.

This is an API ergonomics gap, not an execution gap. A future helper such as
`ledgr_returns(bt)` or `ledgr_run_returns(bt)` could return the canonical
single-run portfolio stream:

```text
ts_utc
equity
period_return
```

Design constraints if promoted:

- do not invent a second return formula; consume the same equity / adjacent
  return semantics used by `ledgr_compute_metrics()` and retained sweep
  returns;
- keep metrics out of the result-table surface: `ledgr_results()` remains
  evidence tables, `ledgr_compute_metrics()` remains metric values, and this
  helper is only the canonical return stream;
- use `period_return` to match sweep retention naming;
- treat the `ledgr_ind_returns()` name collision as acceptable if the run
  helper is `ledgr_returns()`, or choose `ledgr_run_returns()` if explicitness
  matters more than elegance;
- keep this separate from first-class position / exposure time-series helpers,
  which imply larger semantics around weights, shorts, leverage, margin,
  missing prices, multi-currency, and later derivatives;
- keep this out of v0.1.9.4 unless a walk-forward ticket explicitly promotes
  it. Walk-forward can continue to use internal score rows and retained test
  run artifacts without adding a new public return API.

Relationship to existing roadmap entries:

- this is a likely predecessor seam for the v0.2.x PerformanceAnalytics /
  external-package adapter work, where adapters should consume ledgr's own
  canonical return stream rather than reimplementing return math;
- this does not commit to a tear sheet, charting API, `what = "metrics"`,
  `what = "returns"`, position-level result table, or adapter package.

### 2026-06-09 [research] Selection-session archive / evaluation registry is parked, not committed

Discussion around a snapshot-scoped "candidate graveyard" surfaced a real
future substrate idea but not a current product commitment. The strong version
is not a generic auto-persisted table of every evaluation keyed only by
`snapshot_hash`; it is a selection-session archive that records which
candidates were considered together, under which scoring / validation protocol,
on which snapshot, slice, fold, metric context, cost model, risk chain, and
seed surface.

Possible future use:

- reopen the research decision that produced a promoted run;
- support selection-integrity diagnostics that need the candidate family and
  validation protocol, not just the winning candidate;
- connect walk-forward sessions, retained sweep evidence, and promotion
  lineage into one inspectable audit trail;
- preserve enough trial-count evidence for later PBO / CSCV / DSR style
  diagnostics without pretending provenance itself proves statistical validity.

Reasons not to promote now:

- user demand for an explicit evaluation registry is speculative;
- v0.1.9.2 already provides explicit sweep persistence for saved exploratory
  evidence;
- v0.1.9.4 walk-forward should first establish the operational session shape;
- auto-persisting scalar evaluation rows by default would change ledgr's
  side-effect model and create cleanup, schema, privacy, migration, and
  parallel-write obligations;
- snapshot-level row accumulation can overstate selection families by mixing
  unrelated research sessions against the same data.

If this comes back, the entry point should be a dedicated RFC after the
walk-forward MVP and first selection-diagnostics scoping work. The RFC should
start from session identity rather than snapshot identity, make persistence
defaults explicit, and decide whether the feature is an index over existing
sweep / walk-forward artifacts or a new always-on write path. Until then,
existing packets should only preserve identities and promotion lineage that keep
such an archive possible later.

### 2026-06-09 [research] ML-first capability shape for v0.2.x

A 2026-06-09 review of whether ledgr is usable with ML models concluded the
existing strategy contract, walk-forward windowing, sweep candidate identity,
and feature path are sufficient for a useful class of ML strategies today:
pre-trained model loaded into closure, `predict()` called per pulse,
hyperparameter sweeps under future PBO / CSCV / DSR correction. That is enough
to honestly describe ledgr as ML-compatible. It is not enough to describe ledgr
as ML-first.

Closing the gap needs four pieces named explicitly so a v0.2.x packet can scope
them as one coherent cycle rather than discovering the need ad hoc:

1. **Model artifact identity (`model_artifact_hash`).** `strategy_hash`
   captures source bytes, not the bytes of a pre-trained model loaded from
   disk. Two runs with the same strategy code but different trained models
   currently produce the same `strategy_hash`. Honest ML reproducibility wants
   a first-class `model_artifact_hash` that threads into `config_hash` the
   way `cost_model_hash` does. Constructor sketch:
   `ledgr_strategy_artifact(model)` wraps a model with its serialized-bytes
   hash; the hash flows into identity composition as a sibling of cost / risk
   / metric-context hashes.

2. **Train hook distinct from inference loop.** ML workflows fit on a train
   window and predict on a test window. Today training has to happen inside
   the strategy callback on the first pulse, which misattributes telemetry
   and conflates contracts. A `ledgr_strategy_ml(train = , predict = )`
   constructor would let walk-forward call `train()` once per fold's test
   window and cache the trained model under the fold's `candidate_key`. Fold
   core unchanged; only the strategy-contract wrapper.

3. **Prediction-table provenance with PIT semantics.** A common ML pattern is
   generating predictions ahead of time and storing them as a table; the
   strategy then queries `predictions_at(ts_utc, instrument_id)` rather than
   running inference per pulse. Requires the v0.2.x PIT data tables RFC plus
   a prediction-store with hash-bound provenance back to (model artifact +
   feature set + training window). Also unlocks heavy-compute / Python-GPU
   models via precompute-and-query rather than per-pulse roundtrips.

4. **Label-leakage instrumentation.** ML backtests systematically have labels
   accidentally derived from future data. The feature-level no-lookahead
   checks do not catch this because labels are a different surface from
   features. A label-PIT contract would bind that labels are visible during
   training only, not during the pulse loop, and would name a classed
   condition for the runtime-visible-label case.

Sequencing dependencies:

- Selection-integrity diagnostics (PBO / CSCV / DSR / CPCV) should ship before
  ML-first capability. The hyperparameter-sweep selection-bias problem is the
  hardest part of honest ML backtesting; solving it first makes ledgr's ML
  story differentiating rather than "another backtester with `predict()`."
- v0.2.x PIT data tables are a hard predecessor for items 3 and 4.
- Item 2's `ledgr_strategy_ml()` constructor sits cleanly on top of the
  existing strategy helper layer; it does not require its own helper-layer
  cycle.

Indicative minimum-viable v0.2.x cycle:

```text
v0.2.x PIT data tables RFC
  -> model_artifact_hash + ledgr_strategy_artifact() helper
  -> ledgr_strategy_ml(train, predict) constructor
  -> prediction-store with PIT-bound provenance
  -> label-PIT contract + classed leakage condition
```

Total scope is roughly comparable to the v0.1.9.1 cost-API arc if the four
pieces are scoped together.

The earlier inline note in this file ("ML strategy artifact management
depends on stable walk-forward windows, point-in-time feature tables, model
artifact identity, prediction-table provenance, and selection diagnostics.
Do not bolt it on as 'call `predict()` inside a strategy.'") stands; this
entry names the concrete pieces that would operationalize it. The roadmap
"Deferred Strategy And Integration Families" row for ML strategy artifact
management already records the deferral; this entry stays in horizon until a
v0.2.x packet promotes it.

Non-commitments:

- this is not a roadmap commitment;
- no public API is bound by this entry;
- naming sketches are illustrative, not contractual;
- if v0.2.x sequencing pulls PIT data tables later than expected, the ML-first
  capability cycle slides with it.

### 2026-06-09 [research] Post-sweep candidate clustering as selection-integrity input

A 2026-06-09 conversation about cross-sectional features surfaced a low-risk
immediate-value capability worth naming separately from the harder
cross-sectional indicator design: clustering sweep candidates by return-stream
similarity AFTER a sweep completes, as a diagnostic over the candidate space.

The proposition is simple. Sweep candidates carry retained return series
under the v0.1.9.2 retention contract. Clustering those return streams
identifies which candidates are effectively running the same bet wearing
different parameter clothes. A 240-candidate sweep that clusters into 12
groups has 12 effective independent trials, not 240, which directly informs
PBO / CSCV / DSR multiplicity-correction methodology when the
validation-toolkit cycle opens.

This capability is risk-free because it lives entirely on the analysis side:

- does not affect trading decisions, so no leakage path back into the
  backtest;
- consumes already-stored sweep artifacts, no new precomputation surface
  needed;
- does not enter the fold core, the strategy callback, the risk chain, the
  cost model, or the persistence schema;
- composes with selection-integrity diagnostics as the natural
  effective-trial-count input, but does not pre-empt their design.

Indicative public shape (illustrative, not contractual):

```r
clusters <- ledgr_sweep_cluster(
  sweep_results,
  method = "kmeans",
  k = 12L,
  signal = "period_return"
)
# returns a tibble mapping candidate_id to cluster_id with cluster centroids
# and effective-independent-trial-count summary
```

Sequencing dependencies:

- v0.1.9.2 sweep retention infrastructure must be present (it is);
- selection-integrity diagnostics RFC scoping should reference this capability
  as the effective-trial-count input rather than redefining it;
- this is independent of the cross-sectional indicators question (see paired
  entry below); it is a pure post-hoc analyzer over sweep return matrices and
  reuses no fit machinery.

Indicative slot: v0.1.9.x post-walk-forward, or rolled into the
selection-integrity diagnostics packet when that lands. Could ship earlier
if a focused doc-and-helper packet has bandwidth.

Non-commitments:

- this is not a roadmap commitment;
- no public API is bound by this entry;
- the constructor sketch is illustrative;
- clustering method selection (kmeans vs hierarchical vs Gaussian mixture)
  is a v0.2.x design choice, not a horizon commitment.

### 2026-06-09 [research] Cross-sectional indicators are a v0.2.x capability cluster

A 2026-06-09 conversation about clustering as a strategy feature surfaced
that ledgr's feature engine is instrument-local: one instrument's series in,
one series out. Cross-sectional features (clustering by trailing
characteristics, factor exposures, ranks within universe, beta against
universe mean, cross-sectional residuals) need whole-universe-at-t in, one
value per instrument out. ledgr has no native surface for this. This is a
real architectural gap.

But cross-sectional indicators are not a standalone feature-engine
extension. They sit at the intersection of four pieces, three of which are
already on the roadmap or in horizon:

- feature engine architecture (current instrument-local shape);
- PIT data tables (v0.2.x roadmap: `known_at`, `available_at`,
  `effective_at`, alignment policy);
- ML strategy artifact management (the 2026-06-09 ML-first capability shape
  entry above);
- walk-forward (v0.1.9.4) with its `hydration_start` / `scoring_start` /
  `execution_start` / `opening_state_policy` window semantics.

Cross-sectional fitted indicators are functionally "ML strategy artifact
management applied to a model that produces per-instrument output." Same
machinery, same identity discipline.

Hard design problems this surface raises that need RFC-level attention before
any public API is bound:

- **Fit schedule semantics.** "Refit monthly" is gestural. Precise binding
  needs: does the refit fire at the start of the test window or mid-window?
  Does it trigger warmup hydration? Does the fit at time t use data through
  t-1 (strict) or through t (inclusive)? How does the schedule interact with
  walk-forward fold boundaries?
- **Identity composition.** The feature value at time t depends on (fit window
  + fit method + fit params + input feature set + universe + fit schedule).
  Needs a `fit_artifact_hash` analogous to the `model_artifact_hash` in the
  ML-first entry. Without it, two runs with identical strategy / features /
  params / risk / cost can produce different feature values if the underlying
  fits drift, and `config_hash` will not catch it.
- **Dependency graph among features.** Cross-sectional indicators commonly
  consume per-instrument scalar indicators (k-means on rolling volatility,
  ranks within universe by momentum, PCA on returns correlation matrix).
  This is a layered feature engine, not the current flat shape. Needs:
  declared input dependencies on cross-sectional constructors; topological
  sort for precompute order; identity composition where cross-sectional hash
  includes input indicator hashes; cache invalidation across layers when an
  upstream indicator changes.
- **Seed management for stochastic fits.** k-means initialization, SGD
  embeddings, random projections, RANSAC-like procedures all introduce
  non-determinism. Needs: per-fit seed derivation from `master_seed`; seed
  isolation across candidates (a `k = 4` fit must not leak entropy into a
  `k = 8` fit); possible multi-seed averaging for robust fits; integration
  with the existing `execution_seed` machinery.
- **Precomputation and fit-artifact storage.** Pulse-time refitting is
  prohibitive. Realistic workflows refit sparsely (monthly / quarterly) and
  look up cached fitted artifacts per pulse. Needs a fit-artifact store with
  PIT lookup semantics, same shape as the prediction-store named in the
  ML-first entry.

Related but worth noting separately: cross-sectional features could be
consumed by the risk chain, not just the strategy callback. A
`ledgr_risk_one_per_cluster(cluster_feature_id, n_per_cluster)` step that
reads cluster_id and zeros targets exceeding a per-cluster cap fits the
chainable risk architecture naturally. Cluster-id-as-portfolio-constraint is
structurally cleaner than cluster-id-as-alpha and avoids the methodology
question of whether clusters predict returns. Same observation applies to
factor exposures, sector caps, and beta-neutrality.

Sequencing dependencies:

- PIT data tables (v0.2.x) are a hard predecessor;
- ML-first capability shape (v0.2.x, see 2026-06-09 ML-first entry) shares
  most of the load-bearing machinery; cross-sectional indicators should be a
  named workstream inside that packet, not a separate cycle;
- walk-forward (v0.1.9.4) must be stable so fold-boundary semantics for refit
  scheduling are bound;
- a layered feature engine architecture is a predecessor for any
  cross-sectional surface that consumes other indicators.

Indicative slot: v0.2.x ML-first capability packet as a named workstream.
Not earlier, not standalone.

Non-commitments:

- this is not a roadmap commitment;
- no public API is bound by this entry;
- the `ledgr_xs_indicator()` and `ledgr_ind_cluster()` constructor sketches
  discussed are illustrative, not contractual;
- the cluster-as-risk-step note is a downstream application, not a separate
  cycle.

### 2026-06-09 [risk] Risk-chain constraint expansion RFC family (Palomar-anchored)

A 2026-06-09 review of Palomar (2024) Chapter 6 against ledgr's current
risk-chain step set found that ledgr ships 1.5 of 10 canonical portfolio
constraints: long-only fully via `ledgr_risk_long_only()`, and the upper
half of a symmetric box via `ledgr_risk_max_weight()`. The remaining 8 are
intentionally deferred per the v0.1.9.3 chainable-risk synthesis Section 2
minimum-adapter-set scope. See `inst/design/methodology_references.md`
Palomar entry for the full coverage table and citation anchors.

The gap is strategic, not accidental. But it will define ledgr's positioning
ceiling as the package moves toward CRAN and beyond: serious quantitative
portfolio research expects at minimum long-only, capital budget, asymmetric
box, turnover, and some form of risk constraint (sector cap, beta, or
tracking error). That is 5 of 10. Until ledgr covers most of those, the
honest framing is "research framework for simple strategies," not "research
framework for portfolio research."

Closing the gap is not one RFC. Different constraints need different
machinery and predecessors:

- **Long-only / asymmetric box / max-weight refinements.** In-place
  additions to the current risk-step model, no new context fields, no
  solver dispatch. Could open as a focused v0.1.9.x or v0.2.x cycle once
  v0.1.9.5 docs land.
- **Cardinality `||w||_0 <= K`.** Non-convex constraint. Either
  select-top-k-style heuristic (cheap, in the risk chain) or solver
  dispatch (out-of-fold, in portfolio optimization scaffolding). First
  design fork future RFCs will hit.
- **Turnover `||w - w_0||_1 <= u`.** Needs current-position state exposed
  to the risk context. The v0.1.9.3 spec §14 standing future-context
  obligation must land first.
- **Market-neutral / beta / tracking error.** Needs v0.2.x benchmark
  context plus the beta substrate (see the 2026-05-24 beta-as-three-uses
  horizon entry). Far downstream.
- **Dollar-neutral / leverage `||w||_1 <= u`.** Needs long-short authoring
  support (gated on the shorting / leverage contract RFC per the
  2026-06-01 horizon entry).
- **Margin.** v0.2.x derivatives arc territory; permanently out of scope
  for v0.1.x per the whole-second / spot-only contract bindings.

This implies the constraint expansion is a multi-cycle family of RFCs at
different points in the roadmap, not a single packet. Trying to scope them
all together would mix near-term (asymmetric box, cardinality heuristic)
with far-future (margin, dollar-neutral) and produce a packet that cannot
ship.

Cross-cutting decisions any expansion RFC in this family must bind:

- **Quantity-space vs weight-space translation.** Palomar writes
  constraints in weight-space (`w` summing to 1 or zero). ledgr's risk
  chain operates in quantity-space. The translation
  `quantity = weight * decision_equity / decision_price` is mechanical for
  long-only fractional workflows and is what `ledgr_risk_max_weight()`
  already does internally. Any expansion RFC must bind the translation
  explicitly so "max weight 0.20" interpreted on `|w|` versus on
  `|w * P / E|` does not silently drift.
- **Convex vs non-convex partition.** Most Palomar constraints are convex
  (long-only, box, turnover via L1, market-neutral, dollar-neutral,
  leverage via L1) and can live as chainable risk-step adapters.
  Cardinality is non-convex; future risk-step extensions must decide
  between heuristic in-chain implementation and solver dispatch out-of-
  fold. This decision also tells future portfolio-optimization-scaffolding
  work which Palomar constraints become risk-step adapters versus
  PortfolioAnalytics / CVXR adapter targets.
- **Vocabulary stability.** Future risk-step names should follow Palomar's
  labels where they fit naturally. `ledgr_risk_box_weight()`,
  `ledgr_risk_cardinality()`, `ledgr_risk_turnover()`,
  `ledgr_risk_market_neutral()` are the anchored names. Do not coin
  alternatives.

Sequencing dependencies:

- the asymmetric box and minimum-weight cycle has no hard predecessor
  beyond the v0.1.9.3 risk-chain architecture (shipped);
- turnover needs the v0.1.9.3 spec §14 future-context obligation bound;
- cardinality needs an explicit heuristic-vs-solver decision; if heuristic
  is chosen, it can ship near-term, if solver is chosen, it sits in
  portfolio optimization scaffolding;
- market-neutral / tracking error sit behind the v0.2.x benchmark
  substrate; not earlier;
- dollar-neutral / leverage sit behind the long-short contract RFC; not
  earlier;
- margin / leverage with derivatives sits in the v0.2.x derivatives arc.

Indicative slot for the first member of the family: an
asymmetric-box-plus-cardinality-heuristic cycle could open as a focused
v0.2.x packet once the v0.1.9.x arc closes and v0.1.9.5 docs land. Later
members slot in as their predecessors come online.

Related horizon entries that share the same v0.2.x cluster and should
coordinate at scoping time:

- 2026-06-07 portfolio optimization scaffolding (four-level decomposition
  and architectural footguns);
- 2026-05-24 beta as three distinct uses;
- 2026-06-01 strategy callback contract + authoring helpers
  (long-short / hedged / levered authoring helpers gating);
- 2026-06-09 ML-first capability shape (model artifact identity + PIT
  data tables that this family shares predecessors with);
- 2026-06-09 cross-sectional indicators are a v0.2.x capability cluster
  (cluster-as-risk-step is a downstream application of this family).

Non-commitments:

- this is not a roadmap commitment;
- no public API is bound by this entry;
- the `ledgr_risk_box_weight()` / `ledgr_risk_cardinality()` /
  `ledgr_risk_turnover()` / `ledgr_risk_market_neutral()` constructor
  sketches are illustrative, not contractual;
- the cardinality heuristic-vs-solver decision is named here as the first
  design fork; it is not resolved here;
- which constraint cycle opens first is a v0.2.x scoping decision, not a
  horizon commitment.

### 2026-06-09 [research] Business-objective constructor RFC (Pardo-anchored)

Paired with the 2026-06-09 Palomar constraint expansion family entry above:
Pardo (2008) Chapter 11's nine-criterion robust-strategy checklist deserves
operationalization as a `ledgr_business_objective()` constructor that filters
sweep candidates by intrinsic strategy quality before selection. Already
recorded in `inst/design/methodology_references.md` as a deferred citation
anchor; this entry promotes it to a planning seed.

Pardo's nine criteria:

1. relatively even distribution of trades over time;
2. relatively even distribution of trading profit;
3. relative balance between long and short profit;
4. a large group of contiguous, profitable strategy parameters;
5. acceptable trading performance across a wide range of markets;
6. acceptable risk;
7. relatively stable winning and losing runs;
8. a large and statistically valid number of trades;
9. a positive performance trajectory.

This is a different kind of taxonomy from Palomar's constraints. Palomar
names what a portfolio is allowed to do at decision time. Pardo names what
makes a strategy worth keeping after a sweep. They are complementary: a
strategy passes Palomar's constraints at every pulse, then is judged against
Pardo's checklist on its full run-history evidence. Both should anchor on
their respective vocabularies.

The Pardo checklist is also distinct from selection-integrity diagnostics
(Bailey / Lopez de Prado). Selection-integrity asks "did I pick the wrong
winner because of multiple testing?" -- DSR / PBO / CSCV adjust the
selected candidate's metrics after the fact. Pardo's checklist asks "is
THIS strategy worth promoting on its own merits?" -- it filters candidates
by intrinsic quality before selection. Both surfaces apply at the
sweep-result level and answer different questions. The combination is
stronger than either alone.

### Computability against existing ledgr artifacts

Seven of nine criteria are computable from v0.1.9.2+ retained artifacts
today:

- **Even trade distribution over time** -- from trade timestamps in
  retained results; needs a temporal-uniformity metric (Gini, Herfindahl,
  or Kolmogorov-Smirnov against uniform).
- **Even profit distribution** -- from retained returns; needs a
  concentration metric over per-period profits.
- **Stable parameter region** -- from sweep results; needs parameter-grid
  topology awareness. Pardo's strongest single methodology contribution
  per the existing methodology_references.md entry.
- **Acceptable risk** -- broad; could map to drawdown, vol, VaR, or
  composite. The exact metric choice needs an RFC decision.
- **Stable winning / losing runs** -- from trade outcomes; streak
  analysis.
- **Statistically valid number of trades** -- minimum sample-size check.
- **Positive performance trajectory** -- from equity curve; trend slope
  or the K-Ratio from Kestner cited by Pardo.

Two criteria are deferred:

- **Long-short balance** -- gated on the shorting / leverage contract
  RFC (2026-06-01 horizon entry). Until long-short authoring lands this
  criterion is structurally inapplicable.
- **Acceptable performance across markets** -- requires multi-snapshot
  evaluation. A single-snapshot proxy across non-overlapping time slices
  of one snapshot could ship earlier; full cross-snapshot evaluation
  needs v0.2.x snapshot lineage.

### Indicative public shape (illustrative, not contractual)

```r
business_objective <- ledgr_business_objective(
  ledgr_pardo_even_trade_distribution(max_concentration = 0.3),
  ledgr_pardo_even_profit_distribution(max_concentration = 0.4),
  ledgr_pardo_stable_region(min_neighbors = 5),
  ledgr_pardo_acceptable_risk(max_drawdown = 0.20),
  ledgr_pardo_stable_runs(max_streak = 10),
  ledgr_pardo_min_trades(n = 30),
  ledgr_pardo_positive_trajectory(slope_min = 0)
)

filtered <- ledgr_sweep_filter(sweep_results, business_objective)
```

Each criterion is a classed step that consumes sweep candidate evidence
(metrics, trade list, equity curve, retained return series) and returns a
boolean or graded score per candidate. The chain composes them into a
single filter. The constructor produces a serializable plan with a
`business_objective_hash` that participates in selection identity
alongside the walk-forward `selection_rule_hash`.

### Sequencing dependencies

- v0.1.9.2 retained returns and sweep artifact persistence (shipped) --
  needed for criteria 2, 7, 9;
- v0.1.9.4 walk-forward (planned) -- not strictly required, but the
  business objective should compose cleanly with walk-forward selection
  rules. The selection rule picks the winner from the eligible pool; the
  business objective narrows the eligible pool;
- selection-integrity diagnostics RFC (planned v0.2.x) -- natural
  companion; both apply at the sweep-result level for different purposes;
- long-short contract RFC (2026-06-01 horizon entry) -- predecessor for
  criterion 3;
- snapshot lineage (v0.2.x roadmap) -- predecessor for the full version
  of criterion 5.

### Indicative slot

A focused v0.2.x cycle, plausibly paired with the selection-integrity
diagnostics RFC since both operate on sweep results and serve
complementary purposes. The seven computable-today criteria could ship in
a single packet; the two deferred criteria slot in as their predecessors
come online.

Earlier than the Palomar constraint expansion family because:

- no architectural predecessors beyond v0.1.9.2 (shipped);
- no fold-core touch;
- no quantity-space vs weight-space translation work;
- the criteria are mostly metric calculations over existing artifacts.

### Non-commitments

- this is not a roadmap commitment;
- no public API is bound by this entry;
- the `ledgr_pardo_*()` constructor sketches are illustrative, not
  contractual;
- which v0.2.x packet this cycle joins (selection-integrity standalone,
  paired with portfolio optimization scaffolding, or its own cycle) is a
  scoping decision, not a horizon commitment;
- the specific composition rule (all criteria must pass vs scored
  composite vs threshold majority) is left to the RFC;
- the `business_objective_hash` participation in selection identity is
  named here as a coordination requirement, not bound semantics.

### 2026-06-09 [ux] Weight-strategy wrapper as alternative authoring surface

**Status update 2026-06-12: rebalancing schedule policy -- generalized
to ALL strategies, not wrapper-only.** A 2026-06-12 design conversation
added rebalancing intervals to this surface's design space, then
generalized them on a maintainer observation: "in general all
strategies could use that -- hold until the next date." The eventual
RFC inherits the following considerations instead of rediscovering
them.

- **General schedule decorator, weight wrapper as consumer.** The
  calendar policy is a strategy-level concept applicable to any
  `function(ctx, params)` strategy: a decorator (indicative shape
  `ledgr_strategy_schedule(strategy, rebalance = "monthly")`) that on
  non-scheduled pulses emits hold-shaped targets WITHOUT calling the
  inner strategy. `ledgr_weight_strategy()` consumes the same schedule
  machinery rather than owning it; one schedule concept, two authoring
  surfaces.
- **Skip-callback semantics must be bound.** "Hold until next date"
  means the inner strategy is not called on non-scheduled pulses: its
  `state_prev` does not advance and its features are not read. That is
  the honest semantics and the cheap one (a monthly EOD strategy skips
  ~95% of strategy callbacks), but stateful strategies that expect
  per-pulse state updates behave differently under a schedule --
  document, do not paper over. MVP shape is a pure strategy-layer
  decorator (zero fold-core touch; ctx is still constructed).
  Skipping ctx construction entirely on held pulses is a later
  fold-core optimization lever with its own gate.
- **Separate `optimize` from `rebalance` (weight wrapper only).**
  portfolioBacktest's most useful knob split: re-running the optimizer
  (re-estimates mu/Sigma from a lookback window; expensive) is a
  different decision from re-trading back to existing target weights
  (drift correction). Monthly-rebalance, quarterly-reoptimize is a
  standard institutional pattern; conflating the knobs forecloses it.
  Re-estimation is a weights concept and stays wrapper-level.
- **Drift bands compose with the calendar and are already parked.**
  Band-triggered rebalancing ("trade only when a weight drifts more
  than x% from target") is computable at pulse time from ctx
  (positions, prices, equity -> current weights) and is already named
  in the Pass 2 target-construction helper extensions ("rebalance
  bands"). Calendar and bands AND-compose: check on schedule, trade
  only outside bands. Bands are weight-shaped and stay at the
  weight/helper layer; the calendar schedule is general.
- **Identity and sweepability come free at this layer.** Schedule
  parameters are strategy/wrapper params, so they flow into
  params_hash and candidate identity with zero new machinery -- and
  rebalance frequency becomes a sweepable grid axis for free.
  Frequency-vs-cost is one of the most legitimate sweeps a cost-aware
  backtester offers.
- **Calendar semantics need one bound deterministic rule.** "monthly"
  must mean something exact against the pulse calendar (e.g. first
  pulse of each calendar month), defined without market-calendar
  dependencies, EOD/whole-second clean. One paragraph in the RFC, but
  a bound paragraph: it is result-affecting.
- **Boundary: turnover constraints are not schedules.** The Palomar
  turnover constraint (`||w - w0||_1 <= u`) limits how much is traded
  WHEN a rebalance happens and belongs to the risk-chain constraint
  family; the schedule decides WHEN. The RFC names the distinction so
  users do not reach for the wrong knob.

Non-commitments unchanged; the decorator shape is illustrative, not
contractual. The general schedule decorator now has a staged seed
(`rfc/rfc_strategy_schedule_decorator_v0_1_9_x_seed.md`, written
2026-06-12 as design preservation; cycle deliberately not opened --
see the rfc/README.md pipeline). The wrapper-level knobs (`optimize`,
`bands`) remain with this entry.

A 2026-06-09 conversation about strategy contract space (weights vs
quantities) concluded ledgr should not flip its quantity-space strategy
contract, but should add a `ledgr_weight_strategy()` wrapper constructor as
an alternative authoring surface for users who prefer to think in weights.

### The question

Today's strategy contract is `function(ctx, params) -> named numeric target
quantities`. Textbook portfolio construction (Palomar, Markowitz, Lopez de
Prado) operates in weight-space (`w` summing to 1 or zero). The chainable
risk layer (v0.1.9.3) operates in quantity-space with internal weight
translation -- `ledgr_risk_max_weight()` does
`abs(qty * decision_price) <= max_weight * decision_equity`. The question
raised was whether to flip the strategy contract to weight-space to align
with the literature.

### Decision: do not flip the contract

Keep quantity-space as the canonical execution contract:

- **Substrate uniformity.** Fills, ledger events, opening positions,
  snapshots, and the fold core are in quantity-space. The strategy contract
  matching them 1:1 means no translation lives in the middle of the
  execution path.
- **Internal translation already works.** Every Palomar weight-space
  constraint can be expressed in the existing quantity-space chainable
  risk-step pattern (see the 2026-06-09 Palomar constraint expansion family
  entry above for the convention). The math IS in weight-space at the
  constraint level; only the user-facing contract is quantity-space. The
  pattern is established and scales to the rest of the Palomar taxonomy
  without contract changes.
- **Quantity-space is execution-honest.** Crypto fractional quantities,
  equity round-lot semantics, opening positions, and multi-currency
  accounting are all natural in quantity-space and would need a translation
  boundary if the strategy contract were weight-space.
- **Migration cost would be substantial.** Vignettes, examples, tests,
  helpers, demo strategies, and the v0.1.9.3 chainable risk layer all assume
  quantity-space. Pre-CRAN posture authorizes the break but the
  artifact-rewriting cost is real and would set up a second migration
  immediately after the v0.1.9.3 target-risk migration.

### Add a wrapper constructor instead

The cleaner answer is a `ledgr_weight_strategy()` constructor that wraps a
weight-space strategy and translates to quantities at the boundary:

```r
my_strategy <- ledgr_weight_strategy(function(ctx, params) {
  weights <- c(AAA = 0.30, BBB = 0.20, CCC = 0.10, CASH = 0.40)
  weights
})
```

The wrapper handles `quantity = weight * decision_equity / decision_price`
and emits a normal quantity-space target vector. The fold core never sees
weights. Strategy preflight, identity hashing, and the chainable risk layer
all see a normal quantity-space strategy.

Users who want weight-space write weight-space; users who want quantity-
space (especially crypto fractional or explicit-share workflows) write
quantities. Strategy helpers like `target_rebalance(equity_fraction = ...)`
already do something like this implicitly; making the pattern a first-class
wrapper constructor surfaces it.

### Why this is better than flipping

- **Substrate identity preserved.** Quantity-space stays the canonical
  contract; nothing else needs to know about the wrapper.
- **Palomar risk-chain expansion stays clean.** Each new constraint
  (`ledgr_risk_box_weight`, `ledgr_risk_turnover`, etc.) does its own
  weight-to-quantity translation at constructor time. That is already the
  established pattern from `max_weight`. The Palomar entry from 2026-06-09
  explicitly bound this translation as a load-bearing convention; this
  approach honors it.
- **Multi-strategy meta-allocation gets a natural home later.** When the
  portfolio optimization scaffolding lands (2026-06-07 horizon entry), it
  consumes weight-strategy artifacts. The wrapper makes that surface
  composable from day one without retrofitting the strategy contract.
- **Existing artifacts unaffected.** Vignettes, examples, and demo
  strategies all continue to work. The wrapper is additive.

### Indicative constructor sketch (illustrative, not contractual)

```r
ledgr_weight_strategy(
  fn,
  cash_target_id = "CASH",
  normalize = c("none", "to_one", "to_one_with_cash"),
  ...
)
```

Design questions an eventual RFC must bind:

- whether the wrapper validates that weights sum to a constant or trusts
  the user;
- how a cash weight is represented (reserved name, attribute, return-value
  contract);
- whether negative weights are accepted (gated on long-short authoring per
  the 2026-06-01 horizon entry);
- whether the wrapper produces a fully-named target vector or only the
  non-zero weights with the engine completing the rest;
- how decision-time price normalization handles instruments with NA or
  zero prices, consistent with the risk-chain context discipline from
  v0.1.9.3 Batch 5.

### Sequencing dependencies

- v0.1.9.3 chainable risk layer (shipped) -- the established
  weight-to-quantity translation convention this wrapper extends;
- v0.1.9.x decision-time `ctx$equity` and `ctx$vec$close` surfaces
  (shipped) -- the context the wrapper consumes;
- portfolio optimization scaffolding (v0.2.x, 2026-06-07 horizon entry) --
  the future surface that benefits most from this wrapper;
- strategy callback + authoring helpers (2026-06-01 horizon entry) -- this
  wrapper is naturally a member of that helper family;
- Palomar constraint expansion family (2026-06-09 horizon entry above) --
  every constraint added there benefits from a weight-space strategy
  authoring surface that does not require contract changes.

### Indicative slot

A focused v0.2.x cycle, plausibly bundled with either the portfolio
optimization scaffolding or the strategy authoring helpers Pass 2 work.
Small surface (one constructor + tests + docs), no fold-core touch, no
identity-bytes change.

### Non-commitments

- this is not a roadmap commitment;
- no public API is bound by this entry;
- the `ledgr_weight_strategy()` constructor name and signature are
  illustrative, not contractual;
- whether the wrapper validates weight-sum semantics is left to the RFC;
- the cash-weight representation question is left to the RFC;
- which packet this lands in (helpers, scaffolding, or its own cycle) is a
  v0.2.x scoping decision.

### 2026-06-09 [adapters] Palomar adapter family for portfolio optimization scaffolding

**Status update 2026-06-11:** a follow-up ecosystem sweep extended the
candidate list and added one architectural category. None of this changes
the entry's non-commitments; the additions record candidates for v0.2.x
scoping alongside the original three.

- **`RiskPortfolios` (Ardia, Boudt et al.)** -- CRAN, lightweight,
  deterministic closed-form/QP implementations of min-variance,
  inverse-vol, equal-risk-contribution, max-diversification, and
  risk-efficient portfolios. Two roles: the cheapest possible
  proof-of-pattern adapter for the `ledgr_weight_strategy()` wrapper
  (one function, weights out) before the larger Palomar /
  PortfolioAnalytics lifts, and the baseline-portfolio menu
  (equal-weight, inverse-vol) every optimized-candidate comparison
  needs. Indicative implementation order: before the Palomar trio,
  even though the Palomar family stays the headline.
- **`NMOF` (Schumann)** -- actively maintained, book-backed
  (Gilli/Maringer/Schumann) heuristic optimization (Threshold Accepting
  and related) covering non-convex objectives the convex stack cannot:
  cardinality without a specialized solver, drawdown-shaped objectives,
  integer lots. ledgr-specific angle: heuristic optimizers are
  stochastic, and ledgr's execution-seed contract is exactly the
  machinery that makes a stochastic optimizer auditable. An NMOF adapter
  would be the first demonstration that the determinism discipline
  extends to stochastic optimization.
- **`parma` (Ghalanos)** -- scenario-based LP/QP/NLP formulations for
  CVaR, CDaR (drawdown-at-risk), LPM, and minimax portfolios; risk
  measures not covered by the Palomar trio or RiskPortfolios.
  Maintenance is sporadic (watch item); methods-driven medium priority.
- **Estimator adapters as a named second category.** Every optimizer
  above consumes `(mu, Sigma)`, and the weights are only as reproducible
  as the estimator that produced the inputs. The Peterson entry's
  `momentFUN` note already gestures at this; binding it as a category is
  worth more than any single package: estimator adapters carry
  fingerprinted identity (estimator, window, parameters -- the indicator
  fingerprint pattern reused), optimizer adapters consume them.
  Candidates: **`fitHeavyTail`** (convexfi -- already in
  `methodology_references.md` but previously absent from this entry; it
  is the estimator-side member of the same Palomar family),
  **`corpcor`** (Ledoit-Wolf linear shrinkage), **`nlshrink`**
  (nonlinear shrinkage), **`covFactorModel`** (convexfi, GitHub-only,
  factor-structured Sigma).
- **CVXR clarification** -- not an adapter target; it is the authoring
  escape hatch. A user writes a weight strategy directly in CVXR inside
  `ledgr_weight_strategy()`; convex solvers are deterministic, so this
  composes with the identity model without any adapter. Palomar's book
  formulates in CVXR, so the future scaffolding vignette should show the
  pattern once.
- **Cross-cutting determinism gate for the scaffolding RFC:**
  solver-backed adapters fingerprint solver name, version, and tolerance
  settings, and parity-test with tolerance bounds rather than
  byte-equality -- third-party solvers do not owe bit-reproducibility
  across versions, unlike the in-repo spot-FIFO kernel.
- **Routing notes:** `portsort` (cross-sectional double sorts) belongs
  to the cross-sectional indicators entry, not this family;
  `rugarch`/`rmgarch` (vol forecasting for vol-targeting weight
  strategies) and `FactorAnalytics` (factor exposures; GitHub-only) are
  later-cycle candidates adjacent to this family. Confirmed skips
  consistent with existing dispositions: `fPortfolio` / Rmetrics
  (stale), `tseries::portfolio.optim`, `PortfolioOptim`, `MarkowitzR`
  (inference, complementary), `PMwR` (already marked skip).

A 2026-06-09 review of Palomar's GitHub package family at the `convexfi`
organization identified three R packages as coordinated adapter targets
for the v0.2.x portfolio optimization scaffolding (2026-06-07 horizon
entry) and the Palomar constraint expansion family (2026-06-09 horizon
entry above). All three share Palomar's notation conventions and accept
the same Chapter 6 constraint vocabulary, so adapting one de-risks
adapting the other two.

### Adapter targets

- **`riskParityPortfolio`** -- equal-risk-contribution portfolio
  construction. Maps to portfolio optimization scaffolding's risk-parity
  objective (Level 2 of the four-level decomposition per the 2026-06-07
  horizon entry).
- **`highOrderPortfolios`** -- mean-variance-skewness-kurtosis
  optimization. Maps to scaffolding's higher-moment objective. Useful for
  workflows that want to consider beyond second-moment risk.
- **`sparseIndexTracking`** -- index tracking with cardinality constraint
  `||w||_0 <= K`. Direct implementation by Palomar of the cardinality
  constraint defined in his own Chapter 6.2; the reference solver when
  the Palomar risk-chain expansion family opens cardinality. The
  cardinality heuristic-vs-solver decision named in that horizon entry
  could be answered by "adapt sparseIndexTracking" for the solver branch.

All three are convex-optimization-backed (consistent with the `convexfi`
organization name) and follow Palomar's textbook notation:

- adapting one teaches the patterns needed for the other two (shared
  argument naming, shared constraint specification format, shared output
  shape);
- the adapter pattern matches the v0.2.x External Package Adapters
  roadmap entry's "thin, optional, output-only" discipline;
- vocabulary stays anchored on Palomar's terminology, honoring the
  Palomar constraint expansion family entry's "Do not coin alternatives"
  binding.

### Comparison point, not adapter

- **`portfolioBacktest`** -- automated portfolio backtesting over
  multiple datasets. Closest peer in the R portfolio research ecosystem.
  Portfolio-optimization-first where ledgr is identity-and-determinism-
  first. Worth a focused comparison read for the v0.1.9.5 positioning
  narrative or the eventual scaffolding RFC seed; the canonical
  alternative ledgr should understand the way it understands Backtrader
  and quantstrat. Not an adapter target -- adapting it would create a
  second backtester surface inside ledgr, violating the no-second-
  execution-engine invariant.

### Coordination with existing planning artifacts

The v0.2.x External Package Adapters roadmap entry already names
PerformanceAnalytics, PortfolioAnalytics, tidyfinance, and quantmod as
adapter targets. The Palomar adapter family extends that list with three
portfolio-optimization-specific adapters that sit alongside
PortfolioAnalytics. Indicative ranking when the cycle opens:

```text
v0.2.x External Package Adapters (existing roadmap entry)
  -> PerformanceAnalytics (reporting; ranked first)
  -> Palomar family (portfolio construction; this entry)
       riskParityPortfolio + highOrderPortfolios + sparseIndexTracking
  -> PortfolioAnalytics (portfolio construction; alternative to Palomar)
  -> tidyfinance (factor / data research)
  -> quantmod (data ingestion)
```

Palomar family vs PortfolioAnalytics is not either-or. PortfolioAnalytics
is more established and has broader objective coverage; Palomar packages
are newer, more focused, and share notation with the canonical textbook.
Both are adapter candidates; sequencing depends on user demand when the
scaffolding cycle opens.

### Sequencing dependencies

- portfolio optimization scaffolding (v0.2.x, 2026-06-07 horizon entry)
  must be scoped before any adapter target is selected;
- Palomar constraint expansion family (2026-06-09 horizon entry above)
  should be coordinated with the cardinality adapter decision since
  `sparseIndexTracking` covers the solver branch of cardinality;
- v0.2.x External Package Adapters roadmap entry's "thin, optional,
  output-only" discipline applies to each adapter;
- adapter ranking depends on user demand at v0.2.x scoping time; this
  entry records the candidates, not the order.

### Indicative slot

Inside the v0.2.x portfolio optimization scaffolding packet or the
v0.2.x External Package Adapters packet, depending on whether the
scaffolding ships with its own adapters or routes adapters to the
dedicated adapter packet. Either is defensible; the entry stays in
horizon until that scoping decision lands.

### Non-commitments

- this is not a roadmap commitment;
- no public API is bound by this entry;
- the adapter selection order among the three Palomar packages is left
  to v0.2.x scoping;
- the Palomar-vs-PortfolioAnalytics adapter ranking is left to user-
  demand evidence at scoping time, not pre-decided here;
- `portfolioBacktest`'s role as comparison-only-not-adapter is bound
  here, but the depth of the comparison study is a v0.1.9.5 or v0.2.x
  packet scoping decision.

### 2026-06-05 [infrastructure] Release-gate harness around playbook checks

The v0.1.9.1 release gate exposed a process gap: the release CI playbook
contained the right shape of guidance, but the final gate still depended on
the agent remembering which CI-equivalent local commands mattered. In
particular, the README cold-start check
(`Rscript --vanilla tools/check-readme-example.R`) was not run locally before
the first branch push, even though CI treats it as its own gate and it caught
installed-package example drift that full tests, package check, vignette
renders, and pkgdown did not catch.

Future release work needs a lightweight harness around release-gate evidence,
not just prose instructions. Possible shape: a repo-local script or R helper
that reads the active release-gate ticket / packet, verifies that the playbook
is referenced, prints the exact local gate checklist, runs or records the
README cold-start check, full tests, package check, coverage, pkgdown, and
WSL/Ubuntu gates as applicable, and emits a compact closeout block for the
ticket. This should remain a release-process aid, not a new execution or
package-runtime surface.

The important design point is automatic context loading and inspectable
evidence. Future agents should not need to remember the playbook from prior
turns; the harness should make the required gates visible before work starts
and make omissions obvious in review.

### 2026-06-05 [infrastructure] Release-gate tickets must not absorb executable doc/example migration

The v0.1.9.1 Batch 8 release-gate commit absorbed a broad executable
documentation and example migration for the required `cost_model` contract.
That migration belonged in an earlier reviewed docs/example batch alongside
the public API change, not in the final release-gate commit. The release gate
should verify readiness with the smallest possible closeout / metadata change;
it should not become the place where required-argument migrations are first
landed across README, vignettes, examples, rendered docs, and reference pages.

Defense: every release-gate ticket should point at
`inst/design/release_ci_playbook.md`, include the explicit local-gate
checklist, and treat executable-doc drift as a signal to cut a new pre-release
batch instead of expanding the gate. If a release gate uncovers broad
example/API migration work, pause the release sequence, split the work, and
review that migration on its own surface before merge/tag resumes.

### 2026-06-04 [infrastructure] Installed design-tree footprint review

The v0.1.8.11 `inst/` audit kept `inst/design/architecture/` package-included
as installed design authority and removed only reviewed dead placeholders under
`inst/diagrams/`, `inst/examples/`, and `inst/schemas/`. A larger question
remains uncommitted: how much of the full `inst/design/` governance tree should
ship in installed packages, especially spec packets, RFCs, ADRs, audits, and
contracts. The current package treats installed design material as part of the
research-software evidence surface, but that may carry unnecessary install
footprint for end users. Future work should audit the installed design tree as
a whole, decide which documents are package authority versus source-repo
provenance only, and update `.Rbuildignore` only with an explicit contract for
what installed users can rely on.

### 2026-05-29 [execution] v0.1.8.7 optimization-round post-synthesis direction

The accepted v0.1.8.7 synthesis
(`inst/design/rfc/rfc_optimization_round_v0_1_8_7_synthesis.md`) binds a
single-core pure-R hot-path cleanup: surface-preserving event-buffer
capacity/write fix (B0), hot-path representation/formatting cleanup with
durable-identity bytes fenced off (R), and read-back reconstruction behind a
deterministic collapse gate (C), plus ADR 0004 deps and explicit legacy
cleanup. The modern execution contract is snapshot-backed and function-strategy
based; raw `bars` execution, R6 strategy execution, and run-time `data_hash`
identity are removed or fail before the fold. It does **not** authorize a
compiled core, parallel dispatch (now v0.1.8.8), sweep crossover claims, or
durable identity-format changes. Whole-second timestamp contract reaffirmed;
sub-second out of scope (not HFT). Pure direction, no committed home: a
compiled/native fold core is the later lever for decisive single-run peer wins;
the sweep amortization / peer-crossover track stays open (measured modest ~1.18×,
the per-candidate fold dominates — needs heavier-precompute workloads before any
claim); the matrix-canonical strategy surface is a separate contract/ergonomics
RFC; the deeper typed event-emission rewrite (B1) waits on an explicit
primitive-contract binding; durable hash/provenance/fingerprint byte changes each
need their own contract decision.

### 2026-05-30 [optimization] Post-v0.1.8.7 remaining fold-loop levers

The v0.1.8.7 benchmark closeout leaves the main hot bucket as the pure-R
turnover fold loop: on the current local TTR-backed peer shape, the durable run
spends 15.70s of 25.91s in the loop while producing 13,355 fills. B0 removed the
pathological event-buffer cost, R/A removed the obvious timestamp/setup tax, and
C improved fills materialization/read-back. What remains is not one known bug; it
is the accumulation of interpreted per-pulse/per-instrument/per-fill mechanics.

Collapse can still help, but only in specific measured sub-operations. Candidate
uses to preserve for later profiling:

- use `collapse::setv()` for the remaining event-buffer column writes if POSIXct
  class/tzone and event-stream parity remain byte-identical;
- replace hot target/order selection idioms (`match`, `%in%`, repeated `which`,
  logical-vector allocation) with `collapse::fmatch()`, `collapse::whichv()`,
  and related vectorized operators where profiling shows lookup/selection cost;
- precompute integer instrument maps with `fmatch()`-style semantics rather than
  rematching character IDs inside turnover paths;
- batch state-delta or fill aggregation with grouped `fsum()`-style operations
  only if a future order/fill shape produces multiple same-pulse rows per
  instrument and parity is proven;
- keep `rowbind()`, `fcumsum()`, and summary-stat helpers as reconstruction and
  metric materialization levers, not as a claim on live fold-loop speed.

Weak collapse candidates: arbitrary strategy callbacks, branch-heavy fill-rule
logic, and direct matrix bar/feature reads. Those are either user code, already
cheap base-C indexing, or better addressed by the primitive-contract / compiled
core path. Lane R-style timestamp and string-formatting cleanup is also mostly
base-R representation discipline, not a collapse problem.

The practical next diagnostic, if this becomes active work, is an intra-loop
profile that splits context access, target/order conversion, fill resolution,
state update, and event emission after B0/R/A/C. Do not start another broad
collapse pass from package capability alone; require a named hot frame, a
deterministic-wrapper boundary for value-bearing operations, and parity fixtures
that cover durable and sweep event streams.

v0.1.8.8 Batch 2 ran that first diagnostic locally with per-pulse telemetry
sampling (`control$telemetry_stride = 1`). Treat the numbers as local,
current-source, machine-specific attribution only; the full-stride telemetry
adds overhead, so this is not a new speed claim. On the TTR-backed
`peer_sma_crossover` shape (500 instruments x 1260 pulses x 2 features),
measured fold-loop bucket shares were: target/order conversion about 34.6%,
event emission about 27.6%, unattributed loop overhead about 22.9%,
bar-read/mark-to-market about 10.0%, fill resolution about 2.0%, state update
about 1.7%, context build about 0.9%, strategy callback about 0.3%, and feature
view read effectively zero. On the wide no-feature/no-trade shape, the visible
cost was mostly target/order conversion (~41.9%), unattributed loop overhead
(~43.6%), and bar-read/mark-to-market (~14.1%).

Implications to preserve for future work: target/order conversion needs a named
profile of target validation, per-instrument delta scanning, next-bar lookup,
and proposal construction before any rewrite; event emission remains the main
turnover-specific R bucket after B0, but further handler work must prove exact
event-stream parity; and the wide no-trade result points at interpreted
per-instrument scanning/loop overhead, which is more likely a primitive-contract
or compiled-core lever than a small collapse substitution. Context construction
and the strategy callback are not the lead buckets on these shapes.

This entry records direction, not committed work.

### 2026-05-31 [optimization] LDG-2476 peer-benchmark turnover cost decomposition

The LDG-2476 follow-up peer benchmark initially looked like a severe ledgr
regression: on a 500 x 1260 shape, the current apples-to-apples peer harness
reported ledgr_ttr_canonical at 240.64s versus Backtrader at 80.30s. The
current-source A/B evidence in
`dev/bench/peer_benchmark/notes/ledgr_regression_source_analysis.md` changes the
interpretation. The v0.1.8.7/current-source reference row used SMA 20/50
continuous-target semantics and produced 13,355 fills; the current parity row
uses SMA 5/10 crossover-event semantics and produced 68,324 fills. Re-running
the old-shape style on current source landed at 31.60s with 13,355 fills,
matching the 30.75s class from the previous closeout. That rules out a broad
"fold core got 9x slower" diagnosis for the historical workload.

Supporting local artifacts:

- `dev/bench/peer_benchmark/notes/backtrader_scale_check.md`
- `dev/bench/peer_benchmark/notes/ledgr_regression_source_analysis.md`
- `dev/bench/peer_benchmark/notes/three_phase_decomposition_design.md`
- `dev/bench/peer_benchmark/notes/three_phase_decomposition_results.md`
- `dev/bench/results/peer_benchmark_record_20260531T053230Z_performance.csv`
- `dev/bench/results/peer_benchmark_record_20260531T114451Z_performance.csv`
- `dev/bench/results/ledgr_regression_continuous_20260531T101455Z.csv`
- `dev/bench/results/ledgr_regression_continuous_20_50_20260531T101945Z.csv`

Read these as local, current-source, machine-specific evidence only. They are
not a public speed claim and are not a release benchmark ranking.

The later three-phase decomposition refined the interpretation again. On the
same 500 x 1260 SMA 5/10 crossover workload, Backtrader engine time was
79.704s and durable ledgr engine time was 138.370s, so the direct engine-loop
gap is 1.74x rather than the roughly 3x bundled wall-clock gap. The remaining
wall-clock gap is mostly results materialization: durable ledgr results took
83.000s, while Backtrader results took 0.153s because its fills are captured
inline during `notify_order`.

The ephemeral ledgr diagnostic row was the important surprise. It uses the same
fold core with a memory output handler and produced parity with the durable
row, but it was slower overall: durable ledgr was 242.080s and ephemeral ledgr
was 289.620s. Removing the durable snapshot saved 9.740s of ingestion, but the
memory output handler added 16.380s during engine execution and in-memory
event-stream reconstruction added 40.900s during results materialization. In
this high-fill-density regime, the durable DuckDB-backed path is currently the
efficient ledgr path, not an avoidable cost wrapper around a faster ephemeral
engine.

The exposed optimization targets are narrower, in expected impact order:

- **Fills read-back reconstruction.** On the 500 x 1260 diagnostic,
  `ledgr_results(bt, "fills")` took 6.75s for 13,355 fills and 82.28s for
  68,324 fills. This scales worse than linearly and is the clearest post-run
  bottleneck.
- **Memory output-handler per-fill cost.** The parity-matched ephemeral row was
  16.380s slower than durable during engine execution at 68k fills. The memory
  handler is not currently the cheap write path on high-turnover workloads.
- **In-memory event-stream reconstruction.** The ephemeral results phase was
  40.900s slower than durable `ledgr_results()` reconstruction on the same
  event stream. This is a separate optimization lane from DuckDB read-back.
- **Fill/event throughput during the run.** Moving from 13,355 to 68,324 fills
  raised loop time from about 20s to about 122s. Event/fill turnover remains a
  main runtime pressure point, and durable ledgr's engine loop was 1.74x
  Backtrader on the boundary-equivalent row.
- **Data ingestion and snapshot creation.** Snapshot creation on the 500 x 1260
  shape is visible but no longer the lead target: durable ledgr ingestion was
  20.710s and ephemeral ledgr ingestion was 10.970s in the three-phase record.
  CSV parsing, validation, DuckDB insert, sealing, and hash work should still be
  separated before optimization.
- **Strategy-state persistence.** The crossover `state_update` path wrote 1,260
  rows and about 10.3 MB of JSON. It added measurable overhead, but it is
  secondary to fill/event volume and fills reconstruction on this workload.
- **Target/state vector copying.** The peer strategy is now vectorized, but the
  engine still scans named target/position surfaces and computes deltas every
  pulse. Keep this as a lower-confidence target tied to prior fold-loop
  diagnostics.

Feature precompute is not a lead target for this specific SMA workload: `t_pre`
remained about 0.9s in both the old-shape and no-state control rows. Future
work should start from a decomposition that separates ingestion, fold loop,
event emission, fills read-back, and strategy-state persistence instead of
comparing aggregate peer rows across different SMA windows and turnover levels.

Benchmark interpretation caveat to preserve: ledgr rows include durable
DuckDB-backed event/equity persistence and result reconstruction, while Python
peer rows in the harness generally write only canonical CSV artifacts. That is
part of ledgr's product contract, but it must be separated from pure engine
loop time when diagnosing performance.

This entry records the optimization target stack, not committed work. A future
v0.1.8.9 optimization packet should start from phase-separated timing for
ingestion, fold-loop fill/event work, state persistence, and result
reconstruction before choosing a fix.

The v0.1.8.8 contribution is `LDG-2479` (Self-Profiling Workload Grid
Extension), which captures the cost-surface scaling behavior across universe
size, history length, fill density, and persistence mode that this single-point
peer benchmark could not see. The grid output is the planned baseline for the
v0.1.8.9 optimization spec.

**Per-pulse complexity finding (post-LDG-2479 grid run).** The grid revealed
per-fill engine cost growing with universe size on the same strategy and
density: 931 us/fill at 100 instruments, 2,040 at 500, 3,107 at 1000, all on
the 1260-pulse SMA 5/10 crossover. Fills per instrument is constant at ~135
across these rows, so total fills scale linearly with `n_inst`. A correctly
implemented event-driven engine should have flat per-fill cost; ledgr's is
super-linear. Architecture is correct; implementation has R-idiom debt.
Three specific suspects in `R/fold-engine.R`, all mechanical to fix:

- Per-pulse position valuation loop at `R/fold-engine.R:164-170` iterates
  `seq_along(instrument_ids)` per pulse to mark positions to market. O(n_inst)
  per pulse with no fill dependency. Vectorizing to
  `sum(as.numeric(state$positions) * bars_mat$close[, i])` is expected to
  recover ~9s of 413s loop time on the xlarge cell.
- Per-target early-skip loop at `R/fold-engine.R:277-359` iterates
  `names(targets)` per pulse and does per-instrument lookups even when no
  fill will fire. Computing a delta vector once and iterating only over
  `which(abs(delta_vec) > tol)` is expected to recover ~12s on the xlarge
  cell.
- Named-vector copy-on-write on `state$positions` at `R/fold-engine.R:354-355`
  may force whole-vector copies because the pulse-context constructor holds a
  reference. Switching `state` to an environment, or `state$positions` to
  integer-indexed numeric with a one-time id-to-idx map, is expected to
  recover ~1.5s.

Combined cheap recovery on `density_high_xlarge_durable`: ~22.5s of 413s loop
time. The bigger architectural win is that the per-fill cost curve flattens —
the apparent "ledgr scales with universe" symptom is the artifact of R loops,
not a deep engine problem.

After these three fixes, the next-largest target is per-fill
`output_handler$write_fill_events()` batching: the current path inserts one
DuckDB row per fill, and at 133k fills per-fill DuckDB cost is sizable.
Chunked writes of 100-1000 fills should give the next big win after the
per-pulse fixes land.

Full diagnosis with code excerpts, fix sketches, risk notes, alignment
caveats, and verification discipline is in
`dev/bench/notes/per_pulse_complexity_findings.md`. That note is the
load-bearing input for the v0.1.8.9 single-core optimization spec.

**v0.1.8.9 Batch 7 cleanup triage (2026-06-01).** After the main
optimization lanes landed, the high-density xlarge durable cell was down to
267.84s wall and 231.17s loop. The optional cleanup lanes no longer clear the
v0.1.8.9 threshold:

- Spike 5 next-bar matrix lookup is deferred to v0.1.8.10+ or a broader
  matrix-canonical/compiled-core pass. It still has a valid mechanism, but the
  projected ~5s recovery is now less than 2% of wall and requires changing the
  fill-proposal boundary from row-shaped `next_bar` to scalar
  `next_open_price`.
- Spike 3 `state$positions` representation is deferred to v0.1.8.10+ or a
  state-representation audit. The semantic-preserving id-map option projects
  less than 1s recovery, while the faster env/setv variants risk changing
  pulse-context snapshot semantics.
- The LDG-2479 fills row-count fallback is treated as resolved by the
  LDG-2496 fills-buffer rewrite: post-main-lane xlarge durable runs materialize
  fills directly with zero failures and no ledger-count fallback.
- Spike 10's Kahan-vs-cumsum finding is documentation fallout, not a runtime
  lane. Durable-vs-ephemeral sub-1e-8 equity noise should be attributed to
  Kahan compensated summation versus naive `cumsum()`, not DuckDB double
  round-trip precision.

**v0.1.8.9 Batch 8 measurement closeout (2026-06-01).** The full record
workload-grid rerun closed the round with the high-density xlarge durable cell
at 232.03s wall, 199.06s loop, and 23.36s fills extraction, down from the
v0.1.8.8 baseline of 445.02s wall, 413.47s loop, and 197.11s fills
extraction. Per-fill engine cost fell from 3107.33 to 1494.95 us/fill and
per-fill extraction cost fell from 1481.33 to 175.43 us/fill. The comparable
large durable cell moved 153.76s -> 85.12s wall.

The peer benchmark rerun at the LDG-2476 shape shows ledgr's phase-separated
engine row much closer to Backtrader: durable ledgr engine time moved from
138.37s to 88.00s while Backtrader stayed essentially flat at 79.70s -> 78.53s.
That changes the local engine-only ratio from 1.74x to 1.12x. Total ledgr wall
is still 118.79s versus Backtrader's 79.34s because ledgr retains ingestion and
results surfaces that Backtrader mostly avoids.

Residual optimization direction changes accordingly. The next productive work
is not another per-row buffer-write patch; it is R-side substrate work
(typed/state vectors, matrix-canonical next-bar access, pulse-context data
structures), better ephemeral phase telemetry, and a yyjsonr read-path
investigation. Any future `ledgrcore` build should be gated by a post-substrate
measurement spike rather than assumed from the pre-v0.1.8.9 gap.

### 2026-05-30 [architecture] Compiled fold core as `ledgrcore` sister package

The 2026-05-25 entry above records that a compiled fold core remains future
direction and lists the minimum gates before a port RFC. Batch 4 of v0.1.8.8
(typed execution spec, LDG-2472) and Batch 3 (deterministic-only RNG with
`ctx$pulse_seed`, LDG-2471) have now closed two of the structural prerequisites
the 2026-05-25 entry called out. With those in place, the assumed architecture
becomes concrete enough to document:

Pattern:

- compiled fold core ships as a separate `ledgrcore` sister package;
- ledgr declares `ledgrcore` as `Suggests`, not `Imports` — pure-R ledgr
  remains the CRAN-friendly reference;
- both implementations consume the same `ledgr_execution_spec_v1` payload
  through `ledgr_execution_spec()`;
- both implementations emit events through the same output-handler interface
  (`write_fill_events`, `buffer_strategy_state`, etc.);
- strategy callbacks remain R-side (the Batch 2 diagnostic measured strategy
  callback at 0.3% of loop time, so the cross-language callback overhead is
  negligible against the buckets a compiled core would attack);
- byte-identical event-stream parity against the pure-R reference is the
  release contract for any `ledgrcore` version.

The R fold core stays the reference implementation. `ledgrcore` is bound to
match it byte-for-byte; spec drift becomes a failing parity test, not a silent
divergence. This is the same discipline that gated v0.1.8.7's optimization
lanes and the v0.1.8.8 cross-engine parity benchmark (LDG-2476).

Trade-offs to keep visible:

- two implementations to maintain — parity gate enforces equivalence;
- `Suggests` becomes "everyone installs anyway" once `ledgrcore` ships —
  accept it; document that pure-R is the fallback;
- pure-R path rots silently if nobody runs it — keep pure-R as the test
  default; run `ledgrcore` in a separate CI matrix;
- versioning matrix grows — `spec_version` on the typed spec is the
  compatibility gate.

Language choice (C++ via cpp11 vs Rust via extendr) is deferred. The
ecosystem-alignment argument favours C++ (ledgr already depends on duckdb,
which is bundled C++); the memory-safety argument favours Rust. Decide when
the build is authorized, not before.

The decision to build was originally gated on:

- the v0.1.8.9 single-core optimization round (shipped: xlarge wall
  445.02s → 232.03s, peer engine ratio 1.74x → 1.12x Backtrader);
- the LDG-2476 LEAN-Python parity row as the empirical anchor for the
  compiled-core scoping question.

Post-v0.1.8.9 ledgr is within ~1.5x Backtrader on the peer-matched
workload, so by the original "within ~2x → maintenance overhead with
marginal payoff" rule the build is no longer the automatic next step.
Subsequent updates below (2026-06-01 measurement-spike gate,
`ledgrcore-spike` repo-split, R-side substrate framing) replace this
rule with the substrate-then-measure path. The 2026-05-25 entry's
minimum gates (target risk stability, walk-forward workloads,
cost/liquidity boundaries, typed value objects) remain binding alongside
the new empirical gate.

**Canonical JSON encoder/decoder belongs in `ledgrcore` (2026-05-31 update,
from v0.1.8.9 round LDG-2493 / LDG-2494 work).** The v0.1.8.9 round investigates
`yyjsonr` as a faster replacement for `jsonlite::fromJSON` (read-side hot
path) and potentially for `jsonlite::toJSON` in `canonical_json` (write-side
durable identity). If those spikes land in v0.1.8.9, they are a bridge solution,
not the end state. The end state is: `ledgrcore` exposes
`ledgrcore::canonical_json()` and `ledgrcore::parse_event_meta()` backed by
the compiled core's host-language JSON library (rapidjson for C++,
serde_json for Rust, or yyjson directly). Three reasons this lives in
`ledgrcore` rather than ledgr:

- **Determinism is owned by the compiled contract.** `ledgrcore`'s release
  contract is byte-identical event-stream parity. JSON output bytes ARE
  part of the event stream (event meta_json columns). The compiled core
  pins the JSON encoder version and options inside its parity gate, which
  is stricter than anything ledgr's pure-R surface can guarantee via
  third-party R packages whose version defaults may drift across CRAN
  releases.
- **The hot path eliminates the R-level call entirely.** With `ledgrcore`
  owning the encoder, the per-event meta parse and the per-pulse
  state_update serialization happen inside compiled code, bypassing the
  R interpreter for JSON I/O entirely. That is larger than the v0.1.8.9
  yyjsonr win because it removes the R↔C transition cost as well.
- **Reproducibility surface narrows.** Today ledgr's durable identity
  depends on `jsonlite`'s byte stability across versions; tomorrow it
  could depend on `yyjsonr`'s. With `ledgrcore` owning the encoder, the
  durable identity contract has one bound binary, not a moving third-party
  R-package surface.

Scope note: this is a `ledgrcore` deliverable when K1 lands, not a
v0.1.8.9 line item. v0.1.8.9's yyjsonr work (if it lands) is the bridge —
correct byte format chosen so the eventual `ledgrcore` encoder can match it,
or with a documented format version bump if yyjsonr differs from jsonlite.
v0.1.8.9 spec should not over-promise compiled-core JSON as imminent.

**Build authorization is gated on a measurement spike (2026-06-01 update,
from v0.1.8.9 closeout discussion).** The trigger conditions above are
necessary but not sufficient. Before any `ledgrcore` build is authorized,
a minimum-viable measurement spike runs two compiled fold cores — one in
C++ via cpp11, one in Rust via extendr — and measures four load-bearing
numbers:

- per-pulse cost with R strategy callback (realistic boundary case);
- per-pulse cost with an inline static strategy (compiled-only ceiling);
- per-fill cost with R output-handler callback (realistic boundary case);
- per-fill cost with inline event accumulation (compiled-only ceiling).

The gap between realistic and inline numbers measures how much K1 actually
buys. Small gap means K1 is bounded by the R-callback boundary and is not
worth the complexity. Large gap means K1 has real headroom. The spike
does not reimplement the fold engine; it implements a minimum-viable
per-pulse loop (bars matrix in, equity vector out) and produces an
apples-to-apples per-language comparison plus a build/don't-build verdict.

**The spike is scoped after the v0.1.9 substrate round** (per the
2026-06-01 R-side data structures entry below). If the spike runs against
pre-substrate R, it overstates the compiled-core win because R-side
per-pulse work is still in the substrate-debt regime; post-substrate that
drops materially and the boundary-crossing overhead becomes proportionally
larger. The fair comparison is post-substrate R vs compiled, not current R
vs compiled.

Decision shape from the spike:

- compiled vs post-substrate-R gaps < 1.5x on both per-pulse and per-fill:
  `ledgrcore` stays parked; substrate absorbed most of the structural win;
- gaps 2-3x: `ledgrcore` is worth scoping with explicit cost/benefit math
  against the substrate-round residual;
- gaps 5x+: the compiled story is empirically load-bearing and the build
  is authorized, with the language choice driven by the spike's measured
  boundary-cost differential between extendr and cpp11 (not by the
  ecosystem/memory-safety priors the original entry listed).

**ANSWERED 2026-06-01** — K1 measurement spike complete. Verdict at
`ledgrcore-spike` repo
(`inst/design/spikes/k1_measurement_spike/verdict.md`). Headline:
build authorized only for the inline-output design (xlarge inline
cells: Rust 47-151x, C++ 10-33x); parked for R-handler-per-fill
designs (xlarge R-handler cells ~1x). Decision-shape rule above is
SPLIT-MET: ceiling cells exceed 5x by orders of magnitude; realistic
R-handler-per-fill cells fall under 1.5x. Build authorization is
narrowly conditional on inline-output architecture; see the 2026-06-01
[architecture] K1 measurement-spike verdict horizon entry below for
the full disposition and the gates that remain binding.

**Repo-split decision (2026-06-01 evening update, from v0.1.8.10 spike
round scoping).** The K1 measurement spike was initially scoped into the
v0.1.8.10 spike round
(`inst/design/spikes/ledgr_v0_1_8_10_optimization_round_spike/`). It was
moved out of that round and into a dedicated `ledgrcore-spike` repo for
three reasons:

- **Cadence mismatch.** R-side spikes iterate at 1-3 day cycles; Rust /
  C++ FFI development iterates at week-scale cycles. Bundling them would
  make v0.1.8.10 closeout wait on the K1 spike, defeating the
  fast-iteration intent of staying in the v0.1.8.x single-core arc.
- **Build-system hygiene.** Adding `Cargo.toml` plus a C++ toolchain to
  the ledgr repo would force every R contributor to install Rust or
  full C++ tooling just to clone and run tests, a tax that delivers
  nothing to R-side contributors. The separate repo keeps ledgr's build
  surface clean.
- **Stronger measurement baseline.** Timing the spike to run after
  v0.1.8.10 ships lets the comparison use post-v0.1.8.10 production R as
  the baseline rather than a substrate-emulated R variant. That is the
  strongest possible fair comparison and exactly what this entry's
  original "fair comparison is post-substrate R vs compiled" framing
  intended.

Repo name: `ledgrcore-spike` (clearer intent than `ledgrcore` until the
spike concludes "build authorized"; renamed to `ledgrcore` at that point
as a one-time GitHub operation if the verdict goes that way).

The horizon's K1 spike specification (the four load-bearing numbers, the
decision-rule thresholds, the C++ vs Rust language comparison) remains
authoritative. The separate-repo spike implements that spec against
post-v0.1.8.10 production R and feeds results back to a future ledgr
horizon update.

**Result fed back 2026-06-01:** the K1 measurement spike completed all
36 cells in the `ledgrcore-spike` repo. Verdict authored at
`inst/design/spikes/k1_measurement_spike/verdict.md` (commit
`7618230`). The repo-split decision is validated by the outcome — the
spike ran the full Stage 1 spec → Stage 2 R reference → Stage 3 Rust
extendr → Stage 4 C++ cpp11 → Stage 5 measurement → Stage 6 verdict
cadence without entangling ledgr's R-side cadence or build surface.
The repo remains named `ledgrcore-spike` for now; the
`ledgrcore` rename is conditional on the maintainer accepting the
verdict's narrow build authorization (inline-output design only) and
on the additional ledgr-side gates landing (per the 2026-06-01
Architecture B and ephemeral-attribution entries below). See the
2026-06-01 [architecture] K1 measurement-spike verdict horizon entry
below for the full disposition.

This entry records direction, not committed work.

### 2026-06-01 [architecture] R-side data structures as shared substrate for compiled-core path

Source-code analysis of Backtrader (`mementum/backtrader` on GitHub) during
v0.1.8.9 closeout discussion: Backtrader runs ~127 us/bar at the LDG-2476
peer-benchmark shape (500 inst x 1260 bars) in pure Python — no Cython, no
compiled core. Its lead over ledgr at that shape (~1.6-2x post-v0.1.8.9)
comes from architectural choices that do not require leaving the host
language:

- `array.array('d')` C-level contiguous double storage for all price and
  indicator series, indexed by integer offset (`backtrader/linebuffer.py`,
  `self.array = array.array(str('d'))` and `__getitem__` as
  `self.array[self.idx + ago]`).
- Integer-cursor advance per bar (`self.idx += size`) rather than per-bar
  context object construction.
- Vectorized indicator precompute via the `once()` method, with strategy
  callbacks running event-based against the precomputed C arrays.
- Inline fill emission to in-memory Python lists, no event-log
  reconstruction phase.

ledgr already matches indicator precompute (TTR fast path + series_fn).
The other three are R-addressable through data-structure work, not
compilation. That changes the framing of the v0.2.x compiled-core
conversation.

**Substrate framing.** Better R-side data structures pay off twice. Once
as direct R-side optimization in v0.1.9 (typed primitive `state$positions`
matching inventory A3, reusable pulse-context env matching A5/A6,
matrix-canonical next-bar matching B2, ephemeral memory-handler inline
equity accumulation removing the sweep-summary reconstruction pass). And
again as the substrate any future `ledgrcore` would have to consume across
the R-to-compiled boundary. Bad data structures cap a compiled core's
per-pulse ceiling at the strategy-callback boundary, because the compiled
core still pays R-side ctx construction per call. Good data structures
remove that cap. So data-structure investment is no-regret regardless of
whether K1 follows.

**K1 trigger reframing.** The K1 entry above gates the compiled-core build
on "if ledgr is within ~2x peer comparator after v0.1.8.9, ledgrcore is
maintenance overhead with marginal payoff." v0.1.8.9 shipped with the
phase-separated peer benchmark at 1.12x Backtrader on engine time and 1.50x
on total wall (per the LDG-2476 Batch 8 closeout addendum above). By the
K1 entry's own gate, the compiled-core build is no longer the
empirically-supported automatic next step.

A cleaner gating shape going forward:

- v0.1.8.10 invests in the residual single-core lanes (sweep-ephemeral
  reconstruction, R-side substrate, read-path). The strategy callback
  contract addendum (`ctx$vec`, `ctx$idx()`, bulk
  `ctx$vec$feature(feature_id)`) is bound by the 2026-06-01 strategy
  callback synthesis and lands in this cycle.
- v0.1.9 invests in target-risk layer plus post-optimization primitive-
  internals / substrate planning gates per the roadmap.
- K1 is reframed from "automatic v0.2.x next step" to "ambition-tier
  choice triggered by either (a) post-v0.1.8.10 / post-v0.1.9 measurement
  via the `ledgrcore-spike` external repo showing R-side has reached its
  ceiling and the residual gap to Backtrader is still material, or (b)
  demand for Polars/Rust-class throughput that pure-R cannot reach
  (Ziplime's 12.4s on M3 vendor reference is the orientation number for
  that tier)."

The maintainer's stance during v0.1.8.9 closeout: exhaust R-side
optimizations, especially data structures, before committing to a
compiled core. The Backtrader source-code evidence supports the stance —
they got their lead from data structures, not compilation.

This entry records direction, not committed work. `ledgrcore` remains
parked behind the gates listed in the 2026-05-30 entry above, plus
the addition of "R-side substrate must be exhausted first" as a new
gate informed by the Backtrader analysis.

### 2026-06-01 [architecture] Architecture B: in-place hot-frame compilation as alternative to ledgrcore

The K1 measurement spike in the external `ledgrcore-spike` repo
measures **Architecture A**: a separate compiled fold core that owns
the loop and calls back into R for the strategy. Preliminary K1 data
(15 of 36 cells at the time of writing) surfaces an architectural
alternative the horizon's K1 framing did not name explicitly:
**Architecture B — keep the fold loop in R; compile the hot inner
work; call from R per pulse rather than per fill**.

Architecture B has two distinct sub-paths with very different costs.
They must not be conflated:

**B1: extend the existing collapse-doctrine pattern (no new language).**
ledgr's `Imports: collapse` (v0.1.8.7 ADR 0004) gives ledgr access to
C-level routines via an R-callable API. Examples already in
production: `collapse::setv()` for event buffer writes (v0.1.8.9 L2/L3);
`collapse::gsplit()` for per-instrument bucketing (v0.1.8.10 Spike 2's
re-confirmed doctrine). B1 means writing more ledgr R code to use
collapse primitives wherever they fit. **Strictly no new compiled
source in ledgr's tree.** Bounded by what collapse expresses: parallel
array operations, grouped reductions, in-place writes. Weak at
serial-state-dependent loops (FIFO lot accounting cannot be expressed
in collapse primitives directly). Most of the obvious B1 wins are
already captured by v0.1.8.7 and v0.1.8.9.

**B2: add custom compiled hot frames inside ledgr via cpp11.**
ledgr today has no `src/` directory and no C++ source. B2 would add
`LinkingTo: cpp11` to `DESCRIPTION` and write per-pulse hot frames as
C++ functions called from the R fold loop. **This is new compiled
source in ledgr's own tree.** Pattern is mature: cpp11 is what
tidyverse uses (vctrs, readr, dplyr internals); CRAN-distributable
without additional friction; requires only the standard R-package C++
toolchain (Rtools on Windows; system compiler elsewhere — what every
R developer already has if they install any compiled CRAN package).

The architectural cost ladder:

| | New language in ledgr tree | Build toolchain | Distribution |
|---|---|---|---|
| B1 (more collapse)        | No  | None new (collapse is an R `Imports`) | None new |
| B2 (cpp11 hot frames)     | Yes (C++) | Standard R-package C++ build | One package, one CRAN release |
| A (separate `ledgrcore`)  | Yes (Rust or C++) | Cross-platform compiled package, potentially Rust | Two packages, two release cycles, cross-package version management |

**B2 is genuinely cheaper than A** — same language work in scope, but
inside the existing ledgr package rather than as a separate sister
repo with its own cross-platform build and release lifecycle. B2 is
NOT free: it adds compiled source to ledgr's tree and a build
requirement for contributors. But it is much less than A.

The key insight from K1's preliminary data motivating B2: the per-fill
FFI boundary cost is roughly 1 ms per call. K1's `*_handler_R`
variants pay ~130k × 1ms = ~130s at xlarge — the per-fill R callback
dominates total wall regardless of whether the surrounding fold loop
is R, Rust, or C++. **B2 avoids the same trap by batching: don't call
the compiled function per fill; call it per pulse with a vector of
fills.** At xlarge that is ~1260 FFI hops per run, not ~130k.

Concrete shape of B2 (the R fold loop calling a cpp11 hot frame per
pulse):

```r
for (t in seq_len(n_pulses)) {
  prices  <- bars[, t]
  targets <- strategy_callback(ctx)
  deltas  <- targets - state$positions
  fill_idx <- which(deltas != 0)
  if (length(fill_idx) > 0) {
    # ONE compiled call per pulse; all fills for this pulse batched.
    # Implemented as a cpp11 function in ledgr/src/.
    pulse <- ledgr_apply_pulse_fills(
      state         = state, lots = lots,
      instrument_idx = fill_idx,
      deltas        = deltas[fill_idx],
      prices        = prices[fill_idx],
      pulse_idx     = t
    )
    state <- pulse$state
    lots  <- pulse$lots
    # event buffer extended inside the compiled call
  }
  equity[t] <- state$cash + sum(state$positions * prices)
}
```

Inside the compiled per-pulse call, the serial dependency between
fills (lot machinery, position mutation, cash mutation, event
emission) runs at C-speed without crossing the FFI boundary. The R
fold loop's per-pulse overhead is small (~6 us/pulse per
`dev/spikes/spike-amdahl-floor.md`); over 1260 pulses that is ~7.5 ms
total — negligible.

What B2 avoids vs Architecture A:

- No separate package to maintain (ledgrcore is its own
  cross-platform build target with its own release lifecycle).
- No Rust toolchain (cpp11 is C++-only; ledgr already requires the
  standard R-package C++ toolchain for any CRAN-installable
  compiled-package dependency, including collapse).
- Smaller blast radius per hot frame; each cpp11 function is
  independently scopeable and ships in normal ledgr releases.
- No strategy-FFI boundary at all (strategies stay R-to-R as today;
  the strategy callback is just an R function call from the R fold
  loop).

What B2 does not buy vs Architecture A:

- Architecture A's compiled fold loop can do per-pulse work (bars
  column read, equity sum, ctx construction) in compiled code; B2
  keeps that in R. Per the Amdahl-floor spike's empty-fold
  decomposition, the per-pulse machinery share is non-trivial but
  bounded. Architecture A's ceiling on this slice is higher.
- Architecture A produces a substrate the eventual production-grade
  compiled fold could consume across the FFI boundary. B2's compiled
  hot frames ARE that substrate, just packaged differently.

The K1 spike's four variants do NOT include Architecture B (neither
B1 nor B2). The closest is `strat_R_handler_inline`, but that is
Architecture A (compiled fold loop calling R only for the strategy
callback). It does not measure "R fold loop + compiled per-pulse fill
batching."

Implications for the K1 verdict and ledgr's compiled-core direction:

- The K1 verdict in `ledgrcore-spike` answers Architecture A's
  question; Architecture B remains unmeasured.
- If K1's `strat_R_handler_inline` lands at 5-10x at xlarge
  (Architecture A's realistic ceiling), B2 may capture 60-90% of the
  same wall recovery at a fraction of the architectural cost. Build
  authorization for `ledgrcore` should weigh this against B2's lower
  cost rather than treating Architecture A's threshold-cross as
  automatic.
- The v0.1.8.10 Round-3 substrate decision (fold-owned FIFO
  accounting per L7 Ticket 2) is no-regret for either architecture.
  It positions the substrate cleanly for both an external compiled
  fold core AND for an R fold loop calling compiled per-pulse fill
  processors.

> **Status update 2026-06-05.** The B2 "simplest first cut" has
> partially shipped: LDG-2522 in v0.1.8.10 implemented FIFO lot
> machinery + event buffer extension + cash / position update in cpp11
> for spot-asset accounting on the ephemeral / memory-backed boundary.
> The peer benchmark at `dev/bench/peer_benchmark/peer_benchmark.md`
> records the result: 5x engine speedup vs canonical R, 0.20x of
> Backtrader engine time, parity validated against canonical ledgr at
> zero diff across equity, cash, and position proxy on the
> 500-instrument SMA-crossover fixture. The "B2 measurement spike"
> promoted hook below is stale: B2 was measured AND shipped for
> spot-FIFO scope, not pending measurement. The forward B2 scope is
> incremental expansion -- per-pulse equity compilation, fully compiled
> event buffer extension at remaining write sites, bars column read in
> compiled code, non-spot accounting models when derivatives / FX /
> margin work begins, and durable-path integration -- all scoped
> against the closed `compiled_accounting_model` enum (2026-06-02
> scope-guard entry). See the 2026-06-05 post-LDG-2522 entry for the
> current optimization picture and the Architecture A status update.

Promoted roadmap hook (superseded 2026-06-05): the original
"v0.1.9.x or v0.2.x -- Architecture B2 measurement spike" hook has been
replaced by two forward items:

- **Shipped (v0.1.8.10).** B2 spot-FIFO accelerator (LDG-2522). See the
  peer benchmark for measurement.
- **v0.1.9.x or later -- Incremental B2 expansion.** Per-pulse equity
  compilation, fully compiled event buffer extension, bars column
  read, durable-path integration, additional
  `compiled_accounting_model` values for non-spot asset classes (each
  requiring its own RFC, parity suite, and closeout per 2026-06-02
  scope-guard entry).

The B2 spike scoping question (inside ledgr vs separate spike repo)
was answered by LDG-2522 in favor of "inside ledgr": `LinkingTo: cpp11`
and `src/` are now part of the package build. Incremental B2 expansion
follows the same production-grade approach.

This entry does not authorize Architecture B beyond what LDG-2522 has
already shipped; it records the architectural option, the
post-LDG-2522 status, and the incremental forward scope. The
2026-05-30 ledgrcore entry's "R-side substrate must be exhausted
first" gate (closed by v0.1.8.10) was joined by an "Architecture B2
must be measured before Architecture A is authorized" gate, which is
itself closed for spot-FIFO scope by LDG-2522 (see K1 verdict gate 2
status update).

### 2026-06-02 [architecture] B2 spot-FIFO accelerator is not a derivatives accounting model

The v0.1.8.10 LDG-2522 B2 gate is scoped to a spot-asset FIFO
fill-batch accelerator. The internal ledgr gate is a closed
`compiled_accounting_model` enum, not a generic boolean compiled-fill
switch: `NULL` means the canonical R fold path, and `"spot_fifo"` is
the only compiled accounting model v0.1.8.10 may measure.

This scope guard exists to preserve future derivatives and margin
accounting work. The spot-FIFO kernel must not be extended into futures,
options, derivatives, margin, or other instrument-accounting semantics
by accretion. A future non-spot accounting model needs its own model
value, RFC, parity suite, and closeout language. Unsupported
`compiled_accounting_model` values should fail closed with a named error
rather than silently falling back after partial compiled execution or
pretending the spot-FIFO kernel is a general instrument engine.

Closeout and attribution language should therefore say "spot-asset FIFO
fill-batch accelerator" or equivalent. It should not describe LDG-2522
as shipping a general compiled fold core, a public compiled execution
mode, or a derivatives-capable accounting engine.

### 2026-06-02 [verification] macOS parity gate for B2 spot-FIFO opt-in

LDG-2526 can expose the scoped B2 spot-FIFO accelerator as a public
memory-backed sweep opt-in on the platforms verified in the current workspace,
but this Windows workspace cannot close Apple hardware parity. Before any
future default-promotion or CRAN-readiness decision, rerun the small FIFO parity
suite and the peer/workload-grid smoke with
`compiled_accounting_model = "spot_fifo"` on macOS, including a source install
with the local C++ toolchain. Failure UX should also be checked on a macOS
install where the compiled kernel is unavailable.

### 2026-06-02 [documentation] Documentation, structure, and cleanup release before v0.1.9 features

The v0.1.8.x optimization arc plus the v0.1.8.10 substrate work plus the B2
compiled spot-FIFO accelerator land a substantial codified architecture that
is captured in RFCs, decision logs, contracts, and spec packets but is not
synthesized in any human-discoverable form. The governance pattern is
working: every load-bearing decision is ratified, recorded, and traceable.
But the volume has grown past what the maintainer can hold in head, and
reviewing the codified architecture currently requires mining the governance
archive.

The next release should be documentation, structure, and cleanup only,
before any new feature work resumes. The goal is entropy reduction: extract
codified architectural decisions from RFCs and decision logs, synthesize
them into a human- and agent-readable form, and make them discoverable
without mining seven RFCs and thirty decision-log entries.

This expands the previously planned v0.1.9.x maintainer manual scope (see
the 2026-05-30 [documentation] entry below), which explicitly excluded
"rewrite of RFC/ADR/spec-packet governance records into articles." That
exclusion was correct for the v0.1.8.8 window; it is no longer correct
after the v0.1.8.10 / B2 arc multiplied the codified-decision surface.
Synthesis is now part of the scope.

Scope additions over the 2026-05-30 maintainer manual entry:

- RFC synthesis pass: extract load-bearing decisions from accepted RFCs
  into a discoverable index that says "if you are trying to understand X,
  the binding decisions are these and the others are scaffolding."
- ADR population: many architectural decisions live as RFC bindings
  without dedicated ADR records. The ADR directory should be populated
  where the decision has stabilized.
- Decision-log synthesis: the sister-repo decision-log pattern is great
  archaeology; the equivalent ledger-side synthesis should be a
  discoverable artifact, not a chronological dump.
- Vignette refresh: who-ledgr-is-for, why-r, strategy-development, and
  research-workflow articles need updates reflecting the post-v0.1.8.10 /
  B2 reality. Ephemeral sweep is now a real sweep mode at scale; the
  parameter-exploration economics shifted from "expensive but possible" to
  "feasible at serious-research scale." The articles should say so.
- User-facing financial research-software disclaimer: add a plain-English
  disclaimer surface and modest links from README / introductory docs if the
  review accepts the 2026-06-01 disclaimer entry.
- Performance-arc narrative: a coherent v0.1.8.x story that names what got
  faster and how to attribute it. Internal-facing first; external
  publication (R/Finance talk, blog post) is a follow-on decision.
- `contracts.md` audit and structural pass: first check whether the contract
  file is stale after v0.1.8.10, then organize by surface (execution-spec,
  fold-engine, output-handler, lot-accounting, ctx, etc.) rather than
  chronologically if that preserves or clarifies current semantics.
- Internal compiled-accounting documentation
  (`compiled_accounting_model` enum scope guard) for future contributors
  and future-self.

Tone target: the documentation should be human-readable AND agent-readable
AND a little fun to read. Not dry reference material. Prose with a point of
view, examples that teach, a maintainer voice that signals "this was
thought about, here is why." Dry reference is what RFCs and contracts.md
already do; the synthesis layer earns its place by being more readable than
the source.

Sequencing rationale: features can wait; entropy management cannot. The
risk of deferring is that the next architectural decision is made against a
codified surface the maintainer no longer has full visibility on, which is
exactly the failure mode the RFC discipline was built to prevent. v0.1.9
target risk, v0.1.9.x crypto-readiness, walk-forward, and other planned
feature work sit behind this release.

Active planning packet: v0.1.8.11, modeled on v0.1.8.00 as a prep-release
that precedes the next feature cycle. The roadmap entry expands and
re-sequences the existing v0.1.9.x maintainer manual milestone.

### 2026-06-01 [optimization] Ephemeral-mode xlarge wall attribution as gate for ledgrcore / Architecture B2 commit

**Maintainer goal:** ephemeral mode should be fast. The current xlarge
ephemeral baseline is ~372.55s per the workload-grid measurement
(post-v0.1.8.9; cited by Codex in the v0.1.8.10 Round-2 review against
`v0_1_8_9_release_closeout.md`). Reducing this is the user-facing
optimization target for v0.1.9-class work.

The K1 measurement spike (Architecture A) and the Architecture B2
spike (above) both attack the **fold-loop slice** of ledgr's wall:
FIFO lot accounting + position / cash updates + event emission +
per-pulse equity. Per the v0.1.8.10 Round-3 Spike 12 measurement,
the lot-machinery slice at xlarge synthetic was ~30s. Adopting a
compiled fold core would compress that slice from ~30s to single-
digit milliseconds — a **~30-50s wall recovery on the ~372s xlarge
ephemeral cell**, roughly **8-15% wall reduction**. Meaningful but
not transformative.

The **other ~85% of ledgr's xlarge ephemeral wall is unmeasured.**
Candidates for where it lives, in order of suspicion based on prior
spike evidence:

- **Per-pulse ctx construction with helper attachment**
  (`ledgr_update_fast_pulse_context_helpers` at `R/fold-engine.R:196-221`).
  v0.1.8.10 Round-3 L6 (Spike 4 disposition) identified this as the
  actual cost surface — Spike 4 measured only bare `list()` allocation
  (~7.5ms total at xlarge, invisible), but v0.1.8.8 Batch 2 telemetry
  attributed ~0.9% of fold-loop time to ctx construction (~1.8s at
  xlarge), which means the helper attachment is where the cost lives.
  Direct profiling required.

- **Feature engine per-pulse cost.** Runtime projection lookup,
  feature-table materialization, alias-map resolution (per accessor
  call until the v0.1.8.10 accessor RFC bulk-read lands). Unmeasured
  directly; share could be substantial on feature-heavy strategies.

- **Memory output handler `meta` list column residual** (v0.1.8.9 L8).
  The setv fix recovered most of the buffer cost but the `meta` list
  column bounds setv's win. Quantified roughly in v0.1.8.9 (~75s
  ephemeral-specific recovery from the memory handler fix); residual
  unclear.

- **Strategy callback per-pulse cost.** Strategy is user code so this
  is partially uncompressible, but the surrounding R-side invocation
  machinery (target validation, signature handling, etc.) may be
  larger than the Amdahl-floor spike's ~6 us/pulse suggests on
  production strategies.

- **Telemetry collection** when enabled. Per-pulse sampling stride
  affects this; default-off in production but worth knowing the cost
  envelope.

- **Reconstruction pass non-lot work.** Per Round-3 L1 the lot machinery
  is the dominant share (synthesised at ~93%, with Codex's caveat that
  the decomposition was inferred across two fixtures). The remaining
  ~5-10% includes cash cumsum, fills tibble materialization, metrics
  computation. Small but worth quantifying.

- **Pulse-seed RNG derivation.** v0.1.8.10 Spike 8 measured this at
  0.14s standalone at xlarge — below v0.1.8.10 threshold but
  non-zero.

What this spike must do:

- Run an attribution spike against the LDG-2479 `density_high_xlarge_ephemeral`
  cell with Spike 11-shaped subphase telemetry exposing both engine
  and results phases.
- Within the engine phase, decompose per-pulse cost into ctx
  construction (with helper attachment isolated), strategy callback,
  fill loop, lot machinery (separately attributable post-Ticket 2
  fold-owned accounting), event emission, and equity computation.
- Within the results phase (whatever remains after Ticket 1 / Spike 11
  measurement), attribute to fills materialization, metrics
  computation, and any other residual.
- Produce a Pareto attribution: which 3-5 sub-frames account for 80%
  of xlarge ephemeral wall?
- Output: `inst/design/spikes/ephemeral_wall_attribution_spike/attribution_synthesis.md`
  with concrete per-frame us/pulse and us/fill numbers, plus
  recommended sequencing for v0.1.9 optimization tickets.

This spike is a **gate on both ledgrcore and Architecture B2 commitments.**
Specifically:

- IF the fold-loop slice is < ~15% of xlarge ephemeral wall: neither
  Architecture A nor B2 is the highest-leverage v0.1.9 optimization.
  The maintainer should prioritise whichever sub-frame the attribution
  spike identifies as dominant. K1 verdict still informs the
  compiled-core question but does not justify immediate build
  authorization.
- IF the fold-loop slice is 30-50%+ of xlarge ephemeral wall:
  Architecture B2 spike runs next, then A vs B2 decision per the
  B2 horizon entry above.
- IF the attribution spike surfaces a clear larger lever (e.g. ctx
  helper attachment at ~40% of wall): that lever takes v0.1.9
  precedence; ledgrcore and B2 both defer.

The v0.1.8.10 Round-3 constraints carry forward: this attribution
spike runs post-v0.1.8.10 (so it measures against the substrate-
decision shape including fold-owned accounting), uses the same
LDG-2479 grid cells, follows the same parity / determinism gates,
and produces a verdict in the same shape as v0.1.8.9's
architecture_synthesis.

> **Status update 2026-06-05.** This entry's "gate on both ledgrcore and
> Architecture B2 commitments" framing is stale. LDG-2522 shipped the
> B2 spot-FIFO accelerator in v0.1.8.10 with peer-validated 5x engine
> speedup; the B2 commitment is no longer pending. The engine-dominance
> assumption that justified the gate framing (engine ~85% of wall) is
> also wrong: post-LDG-2522 measurement shows engine is 42.5% of B2-row
> wall, with results (26.6%) and ingestion (30.8%) larger combined. The
> "v0.1.9 promoted hook" below is demoted: this attribution spike is now
> reference forensic work, available when a real perf push needs sub-
> frame decomposition (e.g. results-phase decomposition before attacking
> the 9.89s reconstruction lever). It is not a v0.1.9 release headline,
> not a calendar milestone, and the gate cited in the K1 verdict entry
> below has been reframed accordingly. See the 2026-06-05 post-LDG-2522
> entry for the current optimization picture and the Architecture A
> status.

Promoted roadmap hooks (superseded 2026-06-05):

- **Reference forensic work, no scheduled trigger.** Run an attribution
  spike when a specific perf push needs sub-frame decomposition (e.g.
  before attacking the results-phase 9.89s reconstruction lever or the
  ingestion-phase `read.csv` lever). The original v0.1.9 promotion has
  been demoted: this spike's findings inform but do not gate any
  specific release.
- **v0.1.9.x or later -- Highest-leverage attack on dominant
  attribution finding.** Per the 2026-06-05 post-LDG-2522 entry, the
  top candidates by absolute wall saving are: results phase canonical
  materialization (9.89s), ingestion phase (11.43s with
  `data.table::fread` or arrow), and engine remaining R machinery
  (15.77s via R-side substrate). Scoping a v0.1.9.x perf packet
  against any of these may or may not require this attribution spike
  as input.

This entry does not authorize the attribution spike scope or the
follow-on optimization work; it records the original (now reframed)
gate framing and preserves the analysis of where post-LDG-2522 wall
likely lives. The 2026-05-30 ledgrcore entry's gates and the
Architecture B2 entry's gates are now joined by an "xlarge ephemeral
wall attribution should be run when an actual compiled-core
authorization decision is on the table" cue -- a conditional cue, not
a v0.1.9 calendar gate (see K1 verdict gate 3 status update for the
current framing).

### 2026-06-01 [architecture] K1 measurement-spike verdict: compiled fold core authorized for inline-output design only

The K1 measurement spike in the external `ledgrcore-spike` repo
completed all 36 cells (4 boundary variants × 3 implementations ×
3 scales) on 2026-06-01. Verdict authored at
`ledgrcore-spike` `inst/design/spikes/k1_measurement_spike/verdict.md`
(commit `7618230`).

**Headline numbers (xlarge cells, ratios of compiled vs R median wall):**

| Boundary variant            | Rust vs R | C++ vs R |
|:----------------------------|----------:|---------:|
| `strat_static_handler_inline` (ceiling) | 151.20× | 32.73× |
| `strat_R_handler_inline` (realistic inline-output) | 47.33× | 10.14× |
| `strat_static_handler_R` (R handler per fill) | 1.00× | 1.08× |
| `strat_R_handler_R` (both R callbacks) | 0.97× | 1.02× |

**Decision-rule outcome (split-met):** the horizon's 5× build-authorized
threshold is exceeded by orders of magnitude on the two inline-output
cells; the two R-handler-per-fill cells fall under 1.5× (park
threshold). The K1 verdict is therefore **conditional build
authorization**: build is justified only for a production ledgrcore
design that keeps fill-event accumulation inside the compiled loop
and materializes the event frame once. A production design that calls
an R output handler per fill is parked by the verdict — the per-fill
R callback dominates total wall regardless of whether the surrounding
fold loop is R, Rust, or C++.

**Language verdict (with caveat):** Rust extendr is the measured
runtime winner on the viable inline-output cells (Rust 4.6× over C++
on `strat_static_handler_inline` xlarge; Rust 4.7× over C++ on
`strat_R_handler_inline` xlarge). C++ cpp11 retains lower R-package
integration friction (cleaner `R CMD INSTALL .` path; the Rust path
required a custom dev-DLL loader during spike Stage 3).

**Build-flag asymmetry caveat (open).** The Rust crate was built with
`cargo --release` (opt-level=3 + ThinLTO defaults). The C++ path went
through `R CMD INSTALL .` which inherits R's Makevars defaults
(typically -O2, no LTO). The methodology note records the toolchain
versions but does not equalize the optimization flags. A C++ rebuild
with `PKG_CXXFLAGS = -O3 -flto` in `src/Makevars` may close most or
all of the Rust-vs-C++ gap on the inline cells, in which case the
language verdict compresses to "essentially tied; C++ has lower
integration friction." The build-flag check is a precondition for any
production language decision; the verdict's narrow build
authorization is independent of which language wins.

**What the verdict does NOT authorize:**

- It does not authorize an immediate `ledgrcore` build. The
  authorization is narrow (inline-output design only) and is gated by
  two further ledgr-side decisions (Architecture B2 measurement and
  xlarge ephemeral wall attribution per the 2026-06-01 entries above).
- It does not authorize the `ledgrcore-spike` → `ledgrcore` repo
  rename. That happens only if Architecture A is chosen over
  Architecture B2 AND the attribution spike confirms the fold-loop
  slice warrants the compiled-core architectural cost.
- It does not address ~85% of ledgr's xlarge ephemeral wall. The K1
  spike measured the minimum-viable fold loop (FIFO lot accounting,
  position/cash updates, event emission, equity computation). The
  remaining ~85% of ledgr's xlarge ephemeral wall lives in machinery
  the K1 charter deliberately excluded (cost resolver, feature
  engine, ctx helper attachment, durable I/O, telemetry, runtime
  projection). The 2026-06-01 ephemeral attribution entry above is
  the path to surfacing those.

**Gates that remain binding** (from prior horizon entries):

1. **R-side substrate must be exhausted first** (2026-05-30 ledgrcore
   entry). v0.1.8.10 shipped the substrate closeout and the scoped B2
   spot-FIFO opt-in; this gate is no longer pending.
   *Status: closed.*
2. **Architecture B2 must be measured before Architecture A is
   authorized** (2026-06-01 Architecture B entry above). The B2
   spot-FIFO gate ran in v0.1.8.10 for memory-backed sweeps, but that does
   not authorize a general compiled fold core or durable compiled integration.
   K1 verdict does not substitute for the remaining A-vs-B2 product
   comparison.
   *Status update 2026-06-05: closed for spot-FIFO scope by LDG-2522
   (peer-validated 5x engine speedup; see 2026-06-05 post-LDG-2522
   entry). Remaining B2 surface scope -- per-pulse equity compilation,
   non-spot accounting models (futures / margin / FX), full durable-path
   integration -- requires its own measurement when those decisions are
   on the table.*
3. **Xlarge ephemeral wall attribution must complete before either
   compiled-core path is authorized** (2026-06-01 attribution entry
   above). The K1 verdict explicitly anticipates this in its
   "lower leverage than the dominant ledgr-side residual" caveat.
   *Status update 2026-06-05: reframed as conditional-on-Architecture-A-
   decision. Architecture A is functionally parked (see 2026-06-05
   post-LDG-2522 entry) because engine is now 42.5% of B2-row wall, not
   the ~85% the original gate framing assumed. This gate is not a
   v0.1.9 calendar obligation; it fires only when an A authorization is
   actually being considered, which is not currently scoped.*

**Sequencing forward:**

- Next ledgr-side spike: the ephemeral xlarge wall attribution spike
  per the 2026-06-01 attribution entry. Output decides whether the
  fold-loop slice (K1's domain) is even the right v0.1.9 optimization
  target.
- IF the attribution surfaces the fold-loop slice as a meaningful
  share of wall: the Architecture B2 spike runs next. K1 verdict +
  B2 verdict + attribution verdict combine into the A-vs-B2 decision.
- IF the attribution surfaces a different dominant lever (e.g. ctx
  helper attachment, feature engine cost, durable I/O): both K1 and
  B2 defer; the dominant lever takes v0.1.9 precedence.
- IF the attribution surfaces no single dominant lever (e.g. wall is
  diffuse across many sub-frames): the maintainer makes a
  cost/benefit judgment that may include Architecture B2 as one of
  several v0.1.9.x lanes.

**Other findings from the spike worth preserving:**

- The pure-R fold loop at the v0.1.8.10 substrate shape is genuinely
  fast on the compiled-ceiling case (R `strat_static_handler_inline`
  large = 80ms; xlarge = 720ms). The compiled gap is "merely" 30-150×,
  not 1000×+. R-side substrate work is competitive with compiled
  cores in absolute terms; the gap remains because compiled fold
  loops have no R interpreter overhead per pulse.
- The per-fill R callback boundary cost is roughly 1ms per call (~135s
  / 130k fills at xlarge). This is the cost ceiling that any compiled
  architecture pays if it calls R per fill — and it is the same cost
  Architecture B2 would pay R→compiled per pulse (~1260 hops/run
  instead of ~130k). The boundary direction is symmetric; the
  frequency is the decision variable.
- The K1 spike validated the spec packet → R reference → Rust extendr
  → C++ cpp11 → measurement → verdict cadence with explicit per-stage
  hand-offs and parity gates. This cadence is portable to future
  cross-language measurement work if any is scoped.

This entry does not authorize work; it records that the K1
measurement spike is complete with a narrow build authorization, that
two further ledgr-side gates remain binding, and that the ephemeral
attribution spike is the appropriate next move.

### 2026-06-05 [optimization] Post-LDG-2522 ephemeral wall picture and Architecture A status

The v0.1.8.10 B2 spot-FIFO accelerator (LDG-2522) shipped with
peer-validated engine speedup. Numbers from
`dev/bench/peer_benchmark/peer_benchmark.md` v0.1.8.10 record bundle,
same fixture, same seed, 500-instrument 5-year SMA crossover:

```text
B2 spot-FIFO ephemeral:
  Ingestion:  11.43s  (30.8%)
  Engine:     15.77s  (42.5%)
  Results:     9.89s  (26.6%)
  Total:      37.13s

Canonical ephemeral baseline:
  Engine:     79.39s  (B2 cut to 15.77s -- 5.0x engine speedup)

Backtrader same fixture:
  Engine:     78.54s  (B2 is 5.0x faster)
  Results:     0.15s  (B2 is 66x slower here)
  Ingestion:   0.67s  (B2 is 17x slower here)
```

The wall composition has flipped: engine is no longer the dominant
share. Results plus ingestion together are 21.32s -- larger than
engine. That reframes the post-LDG-2522 optimization picture and the
Architecture A business case.

**Realistic optimization options after the FIFO compilation:**

1. Results phase canonical materialization (9.89s). Event-stream to
   equity / fills / trades reconstruction in R. Backtrader does its
   results phase in 0.15s (66x gap), reflecting that ledgr materializes
   canonical tibbles while Backtrader writes raw CSV -- but the ratio is
   far beyond that justification alone. Fills read-back super-linearity
   at xlarge (flagged in prior horizon entries) lives here. Compiled
   materialization or vectorized event-stream collapse looks like the
   biggest absolute lever in the stack.

2. Ingestion phase (11.43s). `read.csv` plus timestamp normalization
   plus in-memory bars / features / projection. Backtrader does the
   equivalent in 0.67s. `data.table::fread` or arrow CSV would cut the
   `read.csv` chunk by roughly 10x. Cheap fix, large absolute payoff.

3. Engine remaining R machinery (15.77s). Per-pulse ctx construction
   with helper attachment, feature engine alias / vector reads,
   per-pulse equity, target validation. R-side substrate work (integer
   cursors, matrix-canonical access, ephemeral inline equity
   accumulation) named in prior horizon as no-regret addresses most of
   this without needing more cpp11.

4. Compiled spot-FIFO on the durable path. Currently ephemeral-only.
   Canonical durable runs at 115.12s; durable users see none of the B2
   win. Extending the accelerator to durable is a real product gap.

5. Incremental B2 surfaces. Per-pulse equity computation in compiled,
   fully compiled event buffer extension, bars column read. Smaller
   incremental wins; each shaves seconds off the 15.77s engine slice.

The top two (results plus ingestion) together represent ~21s of the 37s
total. There is a credible path to a ~15s total wall (~2.5x further
speedup) without needing Architecture A at all.

**Architecture A status: parked.** Marginal ROI after B2: K1's
realistic-case R-handler-inline numbers suggest 10-47x R on the
inline-output cells; B2 is already 5x R on engine. A's marginal speedup
over B2 is maybe 2-10x on the engine slice (15.77s to 2-5s), cutting
~10-13s off total wall, taking 37s to 24-27s -- a 1.4-1.5x total-wall
reduction. The fixed cost of A (separate Rust / C++ package, two release
cycles, Rust toolchain on users, version coordination, blast radius
across both packages) is unchanged. A also does not touch results phase
(9.89s) or ingestion phase (11.43s), which are larger absolute slices
than what A could improve. Reconsider only when a workload surfaces
where engine dominates more than 42% of B2-row wall AND results /
ingestion phases approach their floors. Neither condition holds today.

**Attribution spike reframed.** Earlier horizon entries promoted the
ephemeral xlarge wall attribution spike as a v0.1.9 gate. That framing
assumed engine was ~85% of wall; reality after LDG-2522 is 42.5%. The
spike is reference forensic work -- useful when a real perf push needs
sub-frame decomposition (e.g. results phase decomposition before
attacking the 9.89s reconstruction lever) -- not a release headline and
not a calendar gate. See the 2026-06-01 attribution entry's status
update for the demoted hook framing.

**Distribution argument retracted.** Earlier framings of the opt-in
spot-FIFO design listed "users need a C++ toolchain" as a reason to
keep the compiled path opt-in. CRAN and R-universe ship pre-built
Windows / Mac binaries that include compiled `.dll` / `.so` artifacts;
GitHub source installs require the standard R-package C++ toolchain
(Rtools on Windows) regardless of whether spot-FIFO is the runtime
default, because the cpp11 code is in the build either way.
Distribution is independent of the runtime default. See the 2026-06-05
spot-FIFO-default candidate entry for the remaining load-bearing
reasons.

**Park status (2026-06-05).** All five optimization options above are
parked as forward direction: available when a real perf push needs
scope, no scheduled trigger. None are promoted to v0.1.9.x candidates
in this pass. The v0.1.9 window is target-risk per roadmap; the
v0.1.9.x slate already carries walk-forward (RFC accepted), the
spot-FIFO-default candidate (see 2026-06-05 entry below),
crypto-readiness, target-helper Pass 2, sweep artifact persistence,
and cost-model API direction. The v0.1.8.x single-core perf arc closed
with LDG-2522; re-opening it is a maintainer decision against the menu
above, not a default sequencing assumption. Promoting one or more of
these options into a v0.1.9.x or later packet is appropriate when (a)
a specific user-facing wall-time target is named, or (b) a workload
surfaces that exposes one of the named slices (results / ingestion /
engine residual / durable / incremental B2) as a binding bottleneck.
Same park vocabulary as Architecture A: available, no scheduled
trigger, reconsider on named conditions.

This entry does not authorize any of the five optimization options. It
records direction so the next perf-tick scopes against accurate
numbers. The peer benchmark file at
`dev/bench/peer_benchmark/peer_benchmark.md` is the validation
reference for further work.

### 2026-06-05 [execution] Spot-FIFO as default for ephemeral spot workloads (v0.1.9.x candidate)

The compiled spot-FIFO accelerator (LDG-2522, v0.1.8.10) ships today as
an explicit opt-in: `compiled_accounting_model = "spot_fifo"` on the
ephemeral / memory-backed sweep boundary. Default ledgr execution
remains canonical R. The peer benchmark established that the compiled
path matches canonical R outputs exactly on the SMA-crossover fixture
(zero diff on equity, cash, and position proxy across 1260 bars).
Reading the benchmark result alongside the cpp11 build maturity (one
release cycle, internal parity infrastructure in place), the question
"should this be the default for ephemeral spot workloads in v0.1.9.x"
is worth surfacing as a candidate.

**Why this is a v0.1.9.x candidate, not a decision:**

The opt-in design was deliberate. Three of the original reasons are
still load-bearing:

1. Scope guard. `compiled_accounting_model` is a closed enum;
   `"spot_fifo"` is the one valid value v0.1.8.10 ships. Default-on
   would silently apply spot-FIFO semantics to non-spot users when
   other asset classes land. The 2026-06-02 scope-guard entry binds
   this explicitly: "Spot-FIFO kernel must not be extended into
   futures, options, derivatives, margin by accretion."
2. Parity coverage. The peer benchmark validated parity on ONE fixture
   (500 instruments, 5y daily, SMA crossover, high-turnover). That is
   not the same as parity across all strategy shapes, instrument
   counts, and corner cases (sparse trading, fractional positions,
   tiny lots, exact-zero fills, ties at fill prices).
3. Audit-trail intermediate differences. Even with identical final
   outputs (which the benchmark validates), intermediate diagnostics
   or event ordering inside the compiled hot frame may differ from
   the R path. Until those are documented, "different audit shape" is
   a real reason to keep R canonical for users who introspect
   intermediate state.

One previously-cited reason is no longer load-bearing: **distribution**.
CRAN and R-universe ship pre-built Windows / Mac binaries; GitHub source
installs already require the standard R-package C++ toolchain (Rtools
on Windows) regardless of whether spot-FIFO is the runtime default,
because the cpp11 code is in the build. Distribution is independent of
the runtime default. See the 2026-06-05 post-LDG-2522 entry above for
the retraction in context.

**Asset-class expansion context (load-bearing):**

The ledgr engine currently supports spot assets only. The long-term
design intends to support other asset classes: derivatives (futures,
options, perpetuals), foreign exchange, and potentially margin-traded
spot products. Each of these requires its own accounting model
(futures mark-to-market with margin, options valuation with Greeks, FX
with cross-currency cash management). The closed-enum design of
`compiled_accounting_model` is the architectural anchor that keeps
this expansion path clean. The 2026-06-02 entry already names this:
"Future non-spot accounting models need own model value, RFC, parity
suite, closeout language."

Making spot-FIFO the default must not erode this architectural anchor.
Specifically, the default semantics must be:

- **Default = `"spot_fifo"` when the instrument set is spot-only**,
  where "spot-only" is determined by an asset-class metadata field on
  instruments (or by the absence of any non-spot instrument) rather
  than by user opt-in.
- **Fail closed with named error when the instrument set contains any
  non-spot asset**, with the error pointing the user at the explicit
  `compiled_accounting_model` argument once the relevant non-spot
  model ships.
- **Never silent fallback or accretion** -- the closed enum stays
  closed, and silently broadening spot-FIFO semantics to cover
  derivatives by accident is the failure mode this design prevents.

This means the "default = spot_fifo" decision is not a single
configuration flip. It is: (a) an asset-class detection mechanism on
instruments; (b) a default-resolution path that consults that
mechanism; (c) a fail-closed error path for non-spot detection; (d)
documentation that names the asset-class expansion intent so future
maintainers do not treat the default-on behavior as license to extend
spot semantics to other classes. (a) and (b) are v0.1.9.x scope; (c)
and (d) are pure design.

**Prerequisites before flipping the default in v0.1.9.x:**

- Broader parity sweep across strategy shapes (mean-reversion,
  momentum, rebalanced index, pair-trading), instrument counts (10 /
  100 / 500 / 2000), and corner cases (sparse trading, fractional
  positions, tiny lots, ties at fill prices, exact-zero quantity
  fills).
- Audit-trail documentation comparing intermediate event ordering and
  diagnostic shape between the R and compiled paths.
- Asset-class metadata mechanism on instruments plus default-resolution
  path consulting it.
- Named-error failure path for non-spot detection
  (`ledgr_compiled_accounting_model_unsupported` or similar).
- An ADR or RFC binding the default-resolution semantics so the
  closed-enum architectural anchor is documented in the same place as
  the default-on flip.
- A deliberate version tick (v0.1.9.x packet) flipping the default
  with release notes naming the prerequisites above.

This is a v0.1.9.x candidate, not a committed milestone. It belongs in
the v0.1.9.x slate alongside walk-forward and the other candidate
slots; promotion depends on maintainer scoping.

This entry does not authorize the work. It records the candidate and
the load-bearing asset-class expansion context that must be preserved
through any default-on decision.

### 2026-06-05 [planning] v0.1.9.x line sequencing -- four-tick arc culminating in walk-forward

Following the maintainer decision to scope each v0.1.9.x feature into
its own sub-tick rather than bundle into a single packet, the v0.1.9.x
line is a four-tick arc culminating in walk-forward:

- **v0.1.9.1** -- public transaction-cost API
  (`rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`,
  accepted, no amendments, spec-cut ready).
- **v0.1.9.2** -- sweep artifact persistence (RFC cycle accepted
  2026-06-07; see accepted sweep RFC entry below).
- **v0.1.9.3** -- target-risk layer + per-pulse fill-loop restructure
  (`rfc_chainable_risk_oms_policy_boundary_synthesis.md` plus the
  per-pulse restructure prereq named in the v0.1.9 roadmap section).
- **v0.1.9.4** -- walk-forward evaluation (culmination;
  `rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md` with
  Amendments 1 + 2 + Section 17 ticket-cut gates).

**Status update 2026-06-07:** the v0.1.9.2 sweep persistence RFC cycle
is accepted and the spec packet has opened from
`inst/design/rfc/rfc_sweep_artifact_persistence_v0_1_9_x_synthesis.md`.
The cost-identity consumption obligation from v0.1.9.1 is satisfied by
the accepted synthesis: retention remains non-identity in Section 4, and
`cost_model_hash` / `cost_plan_json` are persisted on saved sweep
artifacts in Section 6.

**Arc rationale: forward-dependency discipline.** Each tick produces
identity or infrastructure that walk-forward consumes when it
ticket-cuts at v0.1.9.4:

- v0.1.9.1 cost-API binds `cost_model_hash` and `cost_plan_json` on
  run config (synthesis Section 6.1). Walk-forward must include
  `cost_model_hash` in `candidate_key` and `session_id` per cost-API
  synthesis Section 6.4 + 14:560 future obligation.
- v0.1.9.2 sweep persistence ships candidate-level retention
  infrastructure; sweep persistence also records `cost_model_hash`
  and `cost_plan_json` per candidate (carries v0.1.9.1 identity).
- v0.1.9.3 target-risk produces the risk-chain identity that
  walk-forward synthesis Section 3 + Amendment 2 binds as required
  for fold / session / candidate provenance.
- v0.1.9.4 walk-forward ticket-cuts with every identity surface and
  infrastructure prereq already real in code. No stubbed identity
  slots, no schema migrations, no late-binding obligations to absorb.

**What this reshapes.** The previous roadmap framing had target-risk
as the v0.1.9 headline and walk-forward as a v0.1.9.x candidate. The
arc puts target-risk at v0.1.9.3 (still v0.1.9, sequenced within the
line rather than as the .0 headline) and walk-forward at v0.1.9.4
with all prereqs satisfied. Target-risk is not pushed to v0.2.x; it
remains v0.1.9 work.

**Scope-discipline acknowledgment.** Walk-forward could ship earlier
with stubbed risk-chain and cost-identity slots (one or two schema
migrations later as target-risk and costs land). The maintainer
declined the early-ship option in favor of clean sequencing -- each
tick ships a complete forward dependency before walk-forward
consumes it. No rebends, no retroactive Section 17 gate additions,
no v1 schema that needs to be re-migrated pre-CRAN.

**Other v0.1.9.x roadmap candidates** (crypto-readiness spike,
target-construction-helper Pass 2 extensions, spot-FIFO-default
candidate per 2026-06-05 entry above, selection-integrity
diagnostics) are not yet sequenced into this arc. They slot in as
either small parallel releases between the four named ticks or get
absorbed into one of them at scoping time. Each is its own scoping
decision when its window opens.

**Cross-cycle obligations recorded by this sequencing:**

- v0.1.9.2 sweep persistence consumed v0.1.9.1 cost-identity bindings
  in the accepted synthesis: retention is non-identity, while
  `cost_model_hash` and `cost_plan_json` are persisted on saved sweep
  artifacts.
- v0.1.9.3 target-risk spec packet must produce risk-chain identity
  that walk-forward's Section 17 gate matrix already references in
  its current bindings (matrix is set up, needs target-risk to
  deliver the identity surface it gates).
- v0.1.9.4 walk-forward ticket-cut packet picks up both cost-identity
  (from .1, currently a cost-API synthesis Section 14:560 future
  obligation) and risk-chain identity (from .3) as concrete
  acceptance criteria on Section 17 gate rows. The current
  Section 17 gate matrix does not yet name `cost_model_hash`; this
  must be added at walk-forward packet-cut time, either by amending
  the walk-forward synthesis or by the spec-cut writer treating the
  cost-API synthesis Section 14:560 as authoritative.

This entry records the sequencing decision and the cross-cycle
identity handoffs. Future tickets in v0.1.9.x should respect the arc
shape; deviations require explicit maintainer override (e.g., a
parallel small release for target-helper Pass 2 between named ticks).

### 2026-06-05 [research] v0.1.9.2 sweep artifact persistence RFC cycle accepted

**Status update 2026-06-07:** the scheduled RFC cycle is complete.
Maintainer accepted the synthesis and closed the cycle after final review.
The accepted cycle artifacts are:

- `inst/design/rfc/rfc_sweep_artifact_persistence_v0_1_9_x_seed.md`;
- `inst/design/rfc/rfc_sweep_artifact_persistence_v0_1_9_x_response.md`;
- `inst/design/rfc/rfc_sweep_artifact_persistence_v0_1_9_x_seed_v2.md`;
- `inst/design/rfc/rfc_sweep_artifact_persistence_v0_1_9_x_synthesis.md`.

The v0.1.9.2 spec packet opens from the synthesis. Bound scope is durable
sweep artifact persistence plus optional retained net portfolio equity/return
series for completed candidates. The accepted surface includes
`ledgr_sweep_retention()`, `retain = ledgr_sweep_retention()` on
`ledgr_sweep()`, save/open/list/info helpers, long and wide retained-series
accessors, cost identity persistence, reopened-sweep candidate compatibility,
and a compact DuckDB schema over `sweeps`, `sweep_candidates`, and
`sweep_returns`.

Explicit non-scope remains load-bearing: no ranking helpers, named selection
views, winner-picking, automatic promotion, full ledger/fill/trade retention
for every candidate, benchmark-relative diagnostics, signal decay tooling,
implementation/cost decay tooling, gross-vs-net cost attribution, or
walk-forward integration in v0.1.9.2. Promotion from reopened sweeps still
re-executes the selected candidate from its reproduction key instead of
committing stored scalar or retained-return rows as a full run.

The cycle also preserves the forward dependency shape from the 2026-06-05
v0.1.9.x sequencing entry: v0.1.9.4 walk-forward may consume the v0.1.9.2
sweep-retention substrate, but walk-forward owns fold/window semantics,
selected-candidate test execution, per-fold provenance, and any per-fold
retention dimensions.

This entry records acceptance and closure. The synthesis is authoritative for
ticket-cut gates; this horizon entry does not authorize implementation beyond
the v0.1.9.2 spec packet.

### 2026-06-07 [research] Post-synthesis sweep persistence future obligations

The accepted v0.1.9.2 sweep persistence synthesis deliberately leaves several
directions out of the first packet. These are future obligations, not active
scope:

- walk-forward per-fold/per-candidate return-series retention;
- signal decay substrate;
- implementation/cost-decay substrate and gross-vs-net definition;
- selection-integrity diagnostic helpers over retained returns;
- PerformanceAnalytics adapter;
- per-instrument and per-trade retention;
- cross-sweep comparison helpers;
- sweep extension/append semantics;
- structured sweep notes;
- `persist =` narrower than `retain =`;
- benchmark-relative return decay;
- snapshot-decoupled sweep reopening;
- saved-sweep schema migration;
- pushed-down or lazy wide-return pivots for very large saved sweeps.

The benchmark-relative return-decay item belongs with the v0.2.x benchmark
context and active-metrics substrate. It should not be implemented in v0.1.9.2,
because v0.1.9.2 stores net strategy equity/returns only and does not define
aligned benchmark/reference returns.

This entry is non-authorizing. It keeps the post-synthesis obligations visible
for later RFC/spec windows without expanding the active sweep persistence
packet.

### 2026-06-07 [research] Peterson (2017) methodology reference added

Added an external methodology reference at
`inst/design/methodology_references.md` covering Brian Peterson's
*Developing & Backtesting Systematic Trading Strategies* (2017). Peterson
is the maintainer of the load-bearing R quantitative-finance ecosystem
(`quantstrat`, `blotter`, `PerformanceAnalytics`, `PortfolioAnalytics`);
the paper is his methodological doctrine for systematic strategy
development.

The reference file maps Peterson's framework to ledgr surfaces, identifies
strong / partial / non-alignments, and names specific sections that future
RFC cycles should cite as priors. Three citation targets are most
load-bearing:

- the **selection-integrity diagnostics RFC seed** (v0.1.9.x slot) should
  anchor in Peterson's "Probability of Overfitting" section and its cited
  Bailey / Lopez de Prado, Bailey / Borwein / Lopez de Prado / Zhu,
  Sullivan / Timmermann / White, Hansen, and Harvey / Liu papers;
- the **benchmark context RFC seed** (v0.2.x) should anchor in
  "Choosing a benchmark" -- archetypal / alternative indices /
  custom tracking portfolios / market observables;
- the **portfolio optimization scaffolding** future obligation (see entry
  below) should anchor in "Rebalancing and asset allocation" -- Kelly,
  optimal-f, LSPM (Vince 2009) -- and the implicit `constrained_objective()`
  FIXME from quantstrat that Peterson flags on page 4.

The reference document is not user-facing and does not promote to pkgdown;
it is a maintainer-level methodology prior cited from RFC seeds.

This entry is non-authorizing. It records the methodology lineage so the
next adjacent RFC cycle has a known citation anchor.

### 2026-06-07 [research] Hypothesis recording as a first-class identity artifact

Peterson (2017) treats the testable hypothesis as the load-bearing
artifact of strategy development: declarative conjecture, predictive
content, expected outcome, verification test. ledgr today has no
structured equivalent. Strategy code expresses *how* a strategy acts;
nothing records *why* the strategy was hypothesized, what its expected
direction or magnitude was, or how the result will be tested.

The closest existing surface is the v0.1.9.2 sweep `note` argument
(synthesis Q4 binding: free-text character scalar). The sweep persistence
synthesis already routes "structured sweep notes" to its F9 future
obligation. That F9 obligation should expand to cover hypothesis-shaped
structured notes specifically:

- declared dependent variable (the predicted measurable outcome);
- declared independent variables (the inputs to the prediction);
- expected direction / range of the outcome;
- verification test the maintainer plans to apply;
- optional links to upstream literature.

A hypothesis recorded this way could travel with the sweep (and any
promoted run derived from it) as a non-identity attribute. It is
audit-only: the framework does not act on the hypothesis or verify it
automatically; it preserves the maintainer's a-priori intent so post-hoc
HARKing is detectable on review.

Recommended path: defer until v0.2.x and bundle into the structured sweep
notes RFC; do not pull into v0.1.9.2 scope.

Adjacent surface: a structured hypothesis is related to but distinct from
a structured *business objective* (which would constrain optimization
ranges for return, risk, leverage, drawdown). The business-objective
constructor is named separately in the portfolio optimization scaffolding
entry below; the two surfaces should land together if and when they ship.

This entry is non-authorizing.

### 2026-06-07 [research] MAE / MFE per-trade excursion analytics

Peterson (2017) treats Maximum Adverse Excursion and Maximum Favorable
Excursion as core per-trade analytics: empirical-risk-stop calibration,
trailing-take-profit identification, and per-trade-quantile diagnostics.
The substrate already exists on ledgr promoted runs (lots + fills
retained, durable equity curve recorded); no public helper computes the
excursions today.

A future `ledgr_run_excursions()` helper would consume the existing fills
and per-pulse OHLC (or higher-frequency data when available) and emit a
per-trade tibble with MAE / MFE / time-to-MAE / time-to-MFE columns. The
flat-to-flat trade definition is the natural groupwork; multi-asset and
non-spot accounting would extend the helper once the trade-definition RFC
(flat-to-reduced vs increased-to-reduced) opens.

This is a small future helper, not a major architectural addition. It
fits naturally inside the v0.2.x diagnostic-retention surface or as a
standalone parallel release between named ticks. The promotion-context
surface (v0.1.8.x) already exposes the trade-extraction interface
`ledgr_closed_trade_rows()`; MAE / MFE would compose on top of it.

Defer until the spot-FIFO multi-asset accounting question is settled --
otherwise the trade-definition contract is in flux and the excursion
semantics would shift.

This entry is non-authorizing.

### 2026-06-07 [planning] Portfolio optimization scaffolding -- four-level decomposition and architectural footguns

The maintainer plans to build portfolio optimization scaffolding later in
the roadmap, after the multi-asset / non-spot accounting work and
intraday support land. This entry records the four-level framing,
substrate prerequisites, and architectural footguns so the eventual RFC
cycle starts with a clean foundation.

Peterson's "portfolio optimization" covers at least four distinct problems
with different substrate requirements:

**Level 1 -- within-strategy weight construction.** Rank-weighting,
inverse-vol weighting, normalization, rebalance bands. Already on the
roadmap as v0.1.9.x Target Construction Helper Extensions (Pass 2 of the
`signal_*()` -> `select_*()` -> `weight_*()` -> `target_*()` pipeline).
Not really "optimization" in Peterson's sense; deterministic weight
construction inside a single strategy. No new architecture.

**Level 2 -- single-strategy multi-asset per-pulse optimization.**
Mean-variance, minimum-variance, max-Sharpe, risk-parity solved inside
the strategy function for the current asset universe per pulse. Fits
inside the existing strategy contract (return full named numeric target
quantities); the optimizer is a deterministic transform from features to
targets. Needs care on solver determinism (seeded initialization for
`DEoptim`, `GenSA`, `pso`) and on identity surface (solver choice and
tolerance enter identity).

**Level 3 -- multi-strategy capital allocation post-hoc.** Take N
committed runs (or N retained sweep candidates), solve for capital
weights across them. Kelly, optimal-f, LSPM (Vince 2009), mean-variance
over strategy return streams. This is meta-level: the optimization input
is the *output* of ledgr execution, not part of it. Needs substantial
new substrate (see below).

**Level 4 -- per-strategy position sizing / Kelly-style leverage.** Given
a strategy with Sharpe X and drawdown distribution Y, what is the right
Kelly fraction or LSPM allocation? Closest existing analogue is the
v0.1.9.3 chainable risk layer (target-risk pre-strategy hook), which is
structurally similar to optimal-f rescaling. The accepted
`rfc_chainable_risk_oms_policy_boundary_synthesis.md` is the substrate
prior; Level 4 would extend it with stats-driven sizing rules.

#### Substrate prerequisites

Most prerequisites are already on the roadmap or in flight:

- v0.1.9.1 cost identity (`cost_model_hash`, `cost_plan_json`) -- done.
  Net returns are well-defined; cost-model swaps do not drift identity.
- v0.1.9.2 retained net returns -- the input series for any
  returns-based optimizer.
- v0.1.9.3 chainable risk layer -- Level 4 substrate and a pre-strategy
  hook other optimizers can reuse.
- v0.1.9.4 walk-forward -- rolling estimation window for Level 2 and
  Level 3 optimizers.
- v0.1.9.x selection-integrity diagnostics -- the *hard prerequisite*.
  Peterson's strongest warning is that optimization on overfit inputs is
  worse than no optimization. CSCV / PBO / DSR confirm the optimizer
  inputs are not noise.
- v0.2.x benchmark context -- active-portfolio constraints
  (tracking-error budgets, IR-maximization objectives).
- v0.2.x point-in-time data -- factor-model / risk-model inputs without
  look-ahead.
- v0.2.x corporate actions and instrument master -- equity-data
  substrate for serious multi-asset optimization.
- v0.2.x explicit accounting-critical event types -- needed for capital
  flow events (deposit, withdraw, rebalance trade) at the portfolio
  layer.
- v0.2.x multi-asset / non-spot accounting (futures, margin, FX) -- the
  flat-to-reduced or increased-to-reduced trade-definition RFC must
  precede Level 3.
- Intraday support (sub-daily-pulse, still whole-second) -- for
  higher-frequency optimization use cases.

Genuinely new substrate that is *not* yet on the roadmap:

- **Multi-snapshot return-stream alignment.** Each ledgr snapshot has
  its own time base. Multi-strategy allocation over committed runs
  needs aligned return series across snapshots -- different inception
  dates, possibly different session calendars if instruments differ,
  different scoring pulses if strategies disagree on rebalance
  frequency. Identity-bearing substrate; deserves its own RFC.
- **Joint return distribution modeling.** Mean / covariance estimation,
  shrinkage (Ledoit-Wolf), factor-model decomposition (Fama-French,
  Barra-style), Factor Model Monte Carlo (Jiang 2007, Zivot 2011/2012
  per Peterson). PortfolioAnalytics has `momentFUN` hooks; ledgr would
  need either an adapter or its own helpers.
- **Constrained-objective constructor as a first-class identity
  artifact.** Peterson is explicit: business objectives should be
  specified as ranges with min / target / max for return, risk,
  leverage, drawdown. ledgr has no `ledgr_business_objective()`
  constructor today. Related to but distinct from the structured
  hypothesis-recording surface (entry above): business objectives
  constrain the optimizer; hypotheses describe the predicted outcome.
- **Capital flow event types.** Deposit / withdraw / rebalance-trade
  events that change account equity outside the strategy's own fill
  stream. v0.2.x "explicit accounting-critical event types" likely
  covers some of this; the portfolio-level aggregation layer is its
  own surface.
- **Portfolio-level identity surface.** A new hash
  (`portfolio_composition_hash` or similar) capturing which strategies
  are included, at what weights, with what rebalance rule, against
  what objective. Same identity discipline as `cost_model_hash` and
  `candidate_key`.
- **Rebalance scheduling.** Calendar-period / cash-flow-triggered /
  threshold-triggered rebalancing. Peterson explicitly cautions against
  continuous-rebalancing assumptions. The schedule becomes an
  identity-bound artifact.

#### Architectural constraints to preserve

The same load-bearing invariants the rest of ledgr observes, plus a few
specific to portfolio optimization:

- **No second execution engine.** The optimizer outputs weights /
  targets; execution still goes through the fold core. For Level 2 this
  is natural (optimizer is a deterministic transform inside the
  strategy). For Level 3 the multi-strategy execution is closer to
  "scenario analysis on saved retained-return series" than "run a new
  backtest" -- the fold core is not invoked at the portfolio layer.
- **Identity-bound.** Every optimization output hashes deterministically
  from its inputs. Solver choice, solver tolerance, random seeds (if
  any), shrinkage parameters, and constrained-objective parameters all
  enter identity.
- **Snapshot-sealed inputs.** Returns going into the optimizer come from
  sealed snapshots (or sealed saved sweeps); the optimizer cannot reach
  back into the input data.
- **Deterministic solvers.** Random-init solvers (`DEoptim`, `GenSA`,
  `pso`) get explicit seeds derived from the optimization's master
  seed. PortfolioAnalytics has a precedent here.
- **Whole-second timestamps.** Rebalance schedules are whole-second; no
  sub-second portfolio rebalancing.
- **Adapter over reimplementation.** `PortfolioAnalytics` and
  `PerformanceAnalytics` already solve the core optimization and
  risk-statistics problems competently. ledgr should ship the
  *substrate* (aligned return streams, business-objective constructor,
  capital-flow accounting, portfolio identity) and adapt to PortA /
  `pbo` / custom optimizers rather than reimplementing them. This
  matches the v0.1.9.2 sweep persistence synthesis F5 obligation
  (PerformanceAnalytics adapter) extended to the optimizer surface.

#### Architectural footguns to avoid

- **Putting portfolio optimization in the fold core.** Levels 3 and 4
  are meta-level. Smuggling multi-strategy semantics into single-strategy
  run identity breaks the "one snapshot -> one run -> one identity"
  contract. Multi-strategy allocation must compose committed runs; it
  must not extend them.
- **Shipping the optimizer before selection-integrity diagnostics
  land.** Optimization on overfit inputs is worse than no optimization.
  CSCV / PBO / DSR / White's Reality Check are the safety pin on the
  portfolio-optimization grenade. They must ship first.
- **Continuous-rebalancing assumptions.** Most academic literature
  assumes continuous rebalancing; production reality is discrete and
  expensive. The rebalance schedule must be a first-class
  identity-bearing artifact.
- **Reimplementing PortfolioAnalytics or FRAPO.** Peterson and Bernhard
  Pfaff have spent two decades on these solvers. ledgr does not need to
  compete; the adapter pattern is the right architectural posture.
- **Hand-crafting joint-return models inside the strategy function.**
  Joint-return distribution modeling belongs at the portfolio layer or
  in a feature-engine extension, not inside individual strategy
  callables. Strategies remain deterministic functions of features and
  state.
- **Treating Level 1 as Level 3.** Within-strategy weight construction
  (`signal_*()` -> `weight_*()`) is not portfolio optimization. The
  v0.1.9.x Target Construction Helper Extensions deliberately do not
  cross into Level 2-4 territory.
- **Skipping the business-objective constructor.** Optimization without
  ranges of acceptable / target / maximum return, risk, leverage, and
  drawdown produces unstable parameter choices. Without an
  identity-bound `ledgr_business_objective()` the optimizer has nothing
  to constrain against.

#### Sequencing

```text
v0.1.9.2  Retained net returns         [Tier 2 substrate]
v0.1.9.3  Chainable risk layer         [Level 4 substrate]
v0.1.9.4  Walk-forward                 [rolling-window substrate]
v0.1.9.x  Selection-integrity diag.    [hard prerequisite for optimization]
v0.2.x    Benchmark context            [active-portfolio prerequisite]
v0.2.x    Point-in-time data           [factor-model prerequisite]
v0.2.x    Multi-asset / non-spot acct  [accounting prerequisite]
v0.2.x    Corporate actions / IM       [equity-data prerequisite]
v0.2.x    Intraday support             [optional frequency prerequisite]
v0.2.x    PA / PortA adapter           [returns-analytics surface]
v0.2.x+   Portfolio optimization       [Levels 3 / 4 ship after prerequisites]
v0.3.0    Paper trading                [production calibration]
v1.0.0    Small-scale live trading
```

Levels 1 and 2 can ship earlier (Level 1 already roadmapped; Level 2
could compose into the strategy contract via helpers without new
identity surface). Levels 3 and 4 are deferred behind the prerequisite
substrate.

#### Permanent non-goals

- Sub-second / HFT portfolio rebalancing: out per the whole-second
  timestamp contract.
- Replacing `PortfolioAnalytics` / `FRAPO` solvers: not the right scope.
- Live multi-strategy order management before v0.3.0+ paper trading.

#### Citations

- Peterson (2017), "Rebalancing and asset allocation" section -- Kelly,
  optimal-f, LSPM (Vince 2009), layered objectives, rebalance frequency.
- Peterson's implicit `constrained_objective()` FIXME from quantstrat
  (page 4 footnote).
- Bailey / Lopez de Prado for drawdown-based stop-outs and the "Triple
  Penance" rule (cited in Peterson's risk-rules section).
- Vince (2009), *The Leverage Space Trading Model*.

See `inst/design/methodology_references.md` for the full Peterson
reference.

This entry is non-authorizing. It records the architectural shape so the
eventual RFC cycle opens with a clean foundation. It does not authorize
implementation, does not commit to a specific version slot, and does not
pre-bind any of the substrate prerequisites. The intent is to make the
architectural footguns visible now so they do not surface as last-minute
surprises once the product arc completes.

### 2026-06-07 [planning] Validation toolkit -- bundling selection-integrity diagnostics with the business-objective constructor under an adapter-first posture

**Status update 2026-06-12: consumed by the accepted validation-toolkit
synthesis.** The RFC cycle this entry anticipated ran to completion on
2026-06-11/12 (seed v1 -> response -> seed v2 with maintainer decisions
D1-D4 in-line -> synthesis -> final review APPROVED WITH PATCHES ->
maintainer acceptance). Binding artifact:
`rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md`. The roadmap slot
this entry rescoped is now the scheduled v0.1.9.6 milestone row. The
open questions previously listed here were answered by the cycle
(license posture: MIT core / Suggests adapters; per-period return
vectors: A-prime sweep-level with the `fold_seq` extension parked;
stable-region detector and Triple Penance: promoted to v0.1.9.6
spec-cut as Q1/Q2). Keep this entry visible until the v0.1.9.6 release
closeout, then sweep to `## Resolved`.

This entry rescopes the v0.1.9.x "selection integrity diagnostics"
roadmap slot (currently `ledgr_roadmap.md:113`) into a single validation
toolkit packet that lands after v0.1.9.4 walk-forward closes. The toolkit
bundles two literatures that share substrate and target the same
"should this candidate be promoted?" question from complementary angles:

- **Selection-bias correction (Bailey / Borwein / Lopez de Prado / Zhu
  2014-):** Deflated Sharpe Ratio, Probability of Backtest Overfitting,
  Combinatorially Symmetric Cross Validation, Triple Penance drawdown
  rule. The methodology priors are recorded in
  `inst/design/methodology_references.md`.
- **Robust strategy evaluation (Pardo 2008):** the nine-characteristic
  robust-strategy checklist (even trade distribution over time, even
  profit distribution, long/short balance, stable parameter regions,
  multi-regime acceptable performance, acceptable risk, stable streak
  distributions, sufficient n_trades, positive equity trajectory).

#### Adapter-first posture

The toolkit's design stance is *connect to the R ecosystem rather than
replace it*. Peterson, Lopez de Prado, Pfaff, and Hyndman have spent
decades building the R substrate for trading strategy evaluation;
ledgr ships substrate plus orchestration and adapts to existing packages
for the canonical compute.

The split (subject to verification during the research-input stage):

**Adapter targets:**

- `PerformanceAnalytics` (Peterson, Carl, et al.) -- canonical R
  performance metrics. Sharpe, Sortino, Calmar, drawdown statistics,
  VaR, ES, rolling performance, rolling regression. The v0.1.9.2 sweep
  persistence synthesis Section 11 F5 obligation (PerformanceAnalytics
  adapter) is pulled forward from generic v0.2.x to land alongside the
  validation toolkit, since the toolkit depends on PA as a substrate.
- `pbo` (Matt Barry) for PBO + CSCV computation, if current. The
  algorithm is also well-specified in the Bailey / Borwein / Lopez de
  Prado / Zhu *Notices of the AMS* paper, so a native fallback is
  feasible if the package has decayed.
- `RPESE` (Chen / Martin et al.) for serial-dependence-aware confidence
  intervals on performance metrics.
- `changepoint` (Killick) and `MSwM` for regime-detection adapters if
  the regime work (currently unscheduled per the regime-detection
  research slot) is ever promoted to scope.

**Native implementation (no adapter exists or adaptation is wrong-shape):**

- Deflated Sharpe Ratio orchestration (PA may provide precursors but the
  full deflation step is small).
- K-Ratio (Kestner via Pardo).
- Triple Penance drawdown-based stop-out rule.
- Pardo trade-distribution criteria (1, 2, 3, 7) computed from ledgr
  fills directly, since `blotter::tradeStats()` consumes blotter's
  account / portfolio state model and adapting that to ledgr fills
  would conflict with ledgr's deterministic event-sourced invariants.
- Stable-region parameter analysis (criterion 4); no R package, small
  native algorithm.
- `ledgr_business_objective()` constructor; must be ledgr-native
  because it is identity-bound and orchestrates the nine criterion
  checks against ledgr's substrate.

**Deliberately deferred or skipped:**

- Purged k-fold cross validation and embargo (Lopez de Prado 2018,
  *Advances in Financial Machine Learning*). No R port at production
  quality; not load-bearing for v0.1.9.x scope since PBO/CSCV plus
  ledgr's native walk-forward cover the substantive territory.
- Hierarchical Risk Parity (Lopez de Prado 2016). Routed to the
  portfolio optimization scaffolding entry above as a Level 3
  adapter target, not to the validation toolkit.

#### Why bundle selection-integrity and business-objective

The two layers answer the same question from complementary angles:
Bailey / Lopez de Prado ask "is this candidate's reported Sharpe corrected
for selection bias?" and Pardo asks "even with bias correction, does the
underlying structure hold up?" Shipping the business-objective constructor
without the bias-correction layer is exactly the *Pseudo-Mathematics*
warning case (Bailey / Borwein / Lopez de Prado / Zhu 2014). Shipping
selection-integrity without the structural checks leaves the maintainer
with corrected metrics but no canonical way to threshold them. Bundling
enforces both at once.

The same Pardo nine-criterion checklist that informs the business-objective
constructor is also the natural source for the named-constraint taxonomy
in any future portfolio optimization scaffolding (per the
2026-06-07 portfolio optimization entry above). The validation toolkit
is therefore not just a v0.1.9.x deliverable; it is the substrate prior
that later v0.2.x+ scaffolding consumes.

#### Substrate completion timeline

Walking through the nine Pardo criteria against substrate availability:
criteria 1, 2, 3, 6, 7, 8 are computable today from promoted-run fills
and metric kernel outputs; criteria 4 and 9 complete when v0.1.9.2 sweep
persistence closes; criterion 5 (multi-regime acceptable performance)
requires v0.1.9.4 walk-forward. The validation toolkit therefore floors
at v0.1.9.4 close, which aligns with the existing v0.1.9.x slot's
"after the walk-forward window model stabilizes" framing.

#### Sequencing

```text
v0.1.9.1  cost-API                  [DONE]
v0.1.9.2  sweep persistence         [in flight]
v0.1.9.3  target-risk               [planned]
v0.1.9.4  walk-forward              [planned; substrate completion]
v0.1.9.x  validation toolkit        [bundle: Bailey + Pardo; adapter-first]
v0.1.9.5  docs / teaching cycle     [teaches the full v0.1.9.x arc]
```

The v0.1.9.5 documentation cycle's coverage expands accordingly. The
existing 2026-06-05 v0.1.9.5 horizon entry frames it as documenting the
v0.1.9.x arc; adding validation toolkit to that arc means v0.1.9.5
teaches strategy validation as a coherent workflow alongside cost-API,
sweep persistence, target-risk, and walk-forward.

#### Ecosystem citizenship

The adapter-first posture is a deliberate social choice in addition to
a technical one. ledgr is a citizen of the R quantitative-finance
ecosystem, not a replacement for it. Peterson maintains
`PerformanceAnalytics`, `PortfolioAnalytics`, `quantstrat`, `blotter`;
Pfaff maintains `FRAPO` and the Rmetrics suite; Hyndman maintains
`forecast`. ledgr's value-add is the deterministic event-sourced
substrate that makes those packages' analytical layers tractable, not a
re-implementation of analytics they already ship at production quality.
Adapter-first signals coalition rather than competition and avoids the
maintenance debt of duplicating mature code.

#### Research input completed

The deep-research input for the validation toolkit cycle landed at
`inst/design/research/Validation-Toolkit.md` (2026-06-07). Five
load-bearing findings move the eventual RFC seed's design space:

1. **`PerformanceAnalytics` 2.1.0 + `RPESE` 1.2.7 are the canonical
   adapter pairing.** Both maintained, current under Peterson / Carl /
   Martin stewardship, and the pairing is the natural ecosystem-
   citizenship choice. RPESE's influence-function methods are
   deterministic by construction; bootstrap modes are opt-in and
   seedable, which fits ledgr's determinism invariants.
2. **DSR and Harvey-Liu haircut already exist in `quantstrat`, not
   `PerformanceAnalytics`.** Surface names `SharpeRatio.deflated` and
   `SharpeRatio.haircut`. But `quantstrat` depends transitively on
   `FinancialInstrument`, which was removed from CRAN on 2025-06-12.
   Right architectural posture: treat quantstrat code as a *formula
   donor* (inspect the implementation, write native helpers against
   ledgr's canonical retained returns) rather than as a dependency.
3. **`pbo`'s input shape is incompatible with fold-level scalar scores.**
   It expects a T x N panel of raw returns and performs CSCV internally.
   The architectural choice is binary: either preserve per-period return
   vectors per candidate (and feed `pbo` directly as an optional
   adapter), or accept that walk-forward produces fold-level summaries
   (and implement PBO/CSCV over scores natively). Cannot coerce.
4. **Purged K-fold, embargo, and CPCV have no production-grade R
   adapter.** `PortfolioTesteR` has a helper inside a broader framework
   but is too narrow to use as canonical. Algorithms are deterministic
   index construction and leakage exclusion -- fits ledgr's invariants
   well; native implementation is the right call. AGPL-licensed
   `pypbo` is the only verified Python comparator and should be avoided
   entirely.
5. **HRP via `HierPortfolios` is a clean adapter route** if HRP is ever
   in scope (per the portfolio optimization scaffolding entry above
   Level 3 substrate). `PortfolioAnalytics` doesn't expose HRP directly
   in current CRAN docs.

The research also confirmed that a single `Validation-Toolkit.md`
research file is the right shape at this stage; the seed and synthesis
may split selection-integrity and business-objective concerns later at
implementation-spec time once interfaces stabilize.

#### Open questions for the RFC seed

The research-input stage answered the questions previously listed here
about package maintenance status (PA 2.1.0 2026-04-11, RPESE 1.2.7
2026-01-08, `pbo` 1.3.5 May 2022 quiet), PA's lack of direct DSR (it
lives in quantstrat instead), and `pbo`'s input-shape compatibility
(incompatible with fold-level scores). Remaining items for the seed
author:

- Triple Penance original-paper specification (the research did not
  source-verify the formula; paper-first verification needed before
  engineering sizing).
- License posture for ledgr's downstream: if ledgr core must remain
  outside the GPL family, keep small native formulas (DSR, K-Ratio,
  Triple Penance) in core and place GPL adapters in optional
  boundaries; if ledgr is already GPL-compatible, the PA + RPESE
  adapters are technically and politically the cleanest path. Bind at
  seed time.
- Whether ledgr's walk-forward should preserve per-period candidate
  return vectors (to feed `pbo` directly as an optional adapter) or
  collapse to fold-level scalar scores (requiring native PBO/CSCV over
  scores). Substrate question that touches the v0.1.9.4 walk-forward
  packet's output shape.
- Stable-region parameter analysis: which detector (2D Gaussian
  smoothing / local-mean stability / neighborhood SD); the research
  notes the gap but doesn't propose a methodology.
- Verification of Hudson & Thames `mlfinlab` successor landscape (the
  research covered `skfolio` and `pypbo` directionally, not
  exhaustively); useful for the seed's Python comparison appendix.

#### Non-authorizing closure

This entry rescopes a roadmap slot, records the adapter-first posture,
and anchors the research input so the eventual RFC cycle opens with a
clean foundation. It does not authorize implementation, does not commit
to a specific batch count, and does not pre-bind which packages will be
adapted (subject to current maintenance verification at seed-cut time).
When the RFC cycle opens, the roadmap line at `ledgr_roadmap.md:113`
should be re-scoped from "selection integrity diagnostics" to
"validation toolkit" at packet-open time per the roadmap-maintenance
discipline.

### 2026-06-07 [planning] Walk-forward fold output -- preserve per-period candidate return vectors for validation-toolkit PBO adapter optionality

**Status update 2026-06-11:** carried forward. The v0.1.9.4 walk-forward
packet chose the operational scalar-score MVP plus selected-candidate test-run
evidence; it did not add per-period return vectors for every candidate/fold.
The substrate question remains parked for the validation-toolkit /
selection-integrity diagnostics RFC, where native PBO/CSCV-over-scores versus
adapter-oriented return-panel retention can be decided with the first
walk-forward session model in hand.

This entry records a substrate observation for the v0.1.9.4 walk-forward
spec-cut writer, surfaced by the 2026-06-07 validation toolkit entry's
Finding 3 (the deep-research review found that `pbo`'s CSCV
implementation requires a T x N panel of raw returns, not fold-level
scalar scores; see
`inst/design/research/Validation-Toolkit.md`).

The accepted walk-forward synthesis
(`rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`, Amendments 1 + 2
and Section 17 ticket-cut gates) binds the operational degradation
table data contract at Section 16.5 -- per-fold scalar metric values
for the default print method. That contract is correct as-is for the
operational reporting surface. The question this entry records is
whether the v0.1.9.4 spec-cut writer should additionally preserve
per-period candidate return vectors per fold as a separate retention
surface.

#### The two options

**Option A -- preserve per-period candidate return vectors per fold.**
The fold-level scalar metrics from Amendment 2 Section 16.5 remain the
operational surface; per-period return vectors are an additional
retention artifact, naturally implemented as an extension of the
v0.1.9.2 retained-net-returns substrate with `fold_seq` added as the
new dimension. The validation toolkit's `pbo` adapter route is
preserved -- ledgr can feed `pbo` directly via the T x N panel
`pbo()` expects.

**Option B -- collapse to fold-level scalar scores.** Operational
surface only; no per-period return vectors per fold. The validation
toolkit must implement PBO and CSCV natively over fold-level scalar
scores. The algorithm is well-specified but moves entirely onto
ledgr's plate; no `pbo` adapter is available because the input shape
mismatch is conceptual, not just type-level.

#### Why this matters

Both options are defensible. The choice has practical consequences:

- **Storage cost.** Option A increases the v0.1.9.4 retention surface
  roughly proportionally to `(n_candidates x n_folds x n_pulses_per_fold)`.
  For realistic walk-forward configurations (say 10 candidates x 20
  folds x 252 pulses), that is on the order of 50K doubles per metric
  -- not free but well within the v0.1.9.2 storage smoke ratio scale.
- **Adapter vs native scope.** Option A reduces the validation
  toolkit's native scope (one fewer algorithm to own); Option B
  expands it (native PBO / CSCV over scores becomes a v0.1.9.x
  deliverable).
- **Future flexibility.** Option A enables future research-stage
  analyses that want per-fold per-candidate return distributions
  (signal decay over time, regime decomposition per fold, per-fold
  attribution). Option B forecloses these without later substrate
  expansion.

The v0.1.9.2 sweep persistence synthesis Section 11 future obligations
list already includes "walk-forward per-fold / per-candidate
return-series retention" (F1 in the post-synthesis direction entry
above). Option A is the natural implementation of that obligation;
Option B is the natural avoidance. The validation toolkit research
surfaces this trade-off earlier than it would otherwise have surfaced,
while the walk-forward packet is still pre-cut.

#### Recommendation

Lean toward Option A -- preserve per-period candidate return vectors
per fold as a separate retention surface. Reasons:

- Aligns with the v0.1.9.2 sweep persistence synthesis's three-tier
  evidence framing (scalar / return-series / promoted run) and extends
  it naturally with a `fold_seq` dimension.
- Reduces the validation toolkit's native-implementation scope by
  preserving the `pbo` adapter route, consistent with the adapter-first
  posture bound in the 2026-06-07 validation toolkit entry above.
- Enables future signal-decay, regime-decomposition, and per-fold
  attribution work without later substrate expansion.
- Storage cost is bounded and within the v0.1.9.2 storage smoke ratio
  scale.

Option A's main cost is the additional retention surface on v0.1.9.4;
if walk-forward retention complexity is already substantial at the
v0.1.9.4 spec packet, Option B remains defensible. The choice is for
the v0.1.9.4 spec-cut writer to make at packet-open time with the
trade-off visible.

#### Process note

This entry is NOT a walk-forward synthesis amendment. The accepted
synthesis Amendment 2 Section 16.5 is correct as-is; the operational
degradation table contract stands. This entry is a substrate
observation that informs the spec-cut writer's choice on whether the
v0.1.9.4 packet additively preserves per-period vectors as a separate
retention surface. If the spec-cut writer chooses Option A, the
additive retention is an additive packet scope decision; if the writer
chooses Option B, the validation toolkit picks up native PBO and CSCV
over scores. Either path is consistent with the accepted synthesis.

If the spec-cut writer reads this entry, decides Option B is correct,
and ships v0.1.9.4 without per-period vectors per fold, the validation
toolkit retains the option to implement native PBO / CSCV over scores
as the canonical path. Nothing here forecloses that.

This entry is non-authorizing. It records the substrate trade-off so
it does not surface as a last-minute decision at validation-toolkit
seed time after v0.1.9.4 has already shipped.

### 2026-06-05 [planning] v0.1.9.5 documentation, teaching, and contracts release after v0.1.9.x arc

After v0.1.9.4 walk-forward closes the v0.1.9.x arc, ledgr will have
shipped: public cost-API and identity surfaces (v0.1.9.1), sweep
artifact persistence (v0.1.9.2), target-risk plus per-pulse restructure
(v0.1.9.3), and walk-forward evaluation (v0.1.9.4). The codified-
architecture surface will have grown to roughly the same scale as
v0.1.8.7-10 did before v0.1.8.11, with the same discoverability-decay
risk. v0.1.9.5 should mirror the v0.1.8.11 pattern: entropy-management
release before v0.2.x feature work begins.

**Authoritative inputs at spec-cut time (indicative):**

- The four completed v0.1.9.x packets and their release closeouts.
- `rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`.
- `rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md` with Amendments
  1 + 2 and Section 17 ticket-cut gates.
- `rfc_chainable_risk_oms_policy_boundary_synthesis.md`.
- The v0.1.9.2 sweep persistence synthesis (when it lands).
- Accumulated horizon entries from the v0.1.9.x arc.

**Workstreams (indicative; spec packet binds final shape):**

- **Workstream A -- Contracts audit and structural pass.**
  `contracts.md` needs target-risk layer language, walk-forward
  identity language, and sweep persistence shape. Same
  "audit first, route findings, edit only after routing" discipline
  as v0.1.8.11.

- **Workstream B -- User-facing vignette refresh.**
  - `strategy-development.qmd`: simplified to target authoring; remove
    what migrates to the new risk-and-cost vignette.
  - `metrics-and-accounting.qmd`: cost-aware metric-interpretation
    touch (the substantive cost rewrite shipped in v0.1.9.1 Batch 6).
  - `research-workflow.qmd`: walk-forward integration.
  - `research-to-production.qmd`: depth pass beyond the v0.1.9.1
    release-gate surface migration.

- **Workstream C -- New vignettes.**
  - **Walk-forward research arc** (headline). Anchors the v0.1.9.4
    evaluation surface: snapshot to folds to train sweep to
    selection rule to test execution to candidate extraction to
    promotion.
  - **Risk-and-cost execution policy**. Teaches the v0.1.9.1 cost-API
    plus v0.1.9.3 target-risk layers as the strategy-to-fill
    in-between. Diagram and narrative of the pipeline
    (targets -> risk -> timing -> cost -> fill), why each layer
    exists, what each does not do. Worked examples for cost
    composition (quoted-spread convention, chain order rule) and
    classed risk-step authoring. Explicit non-goals named to bound
    teaching scope: pre-trade alpha-vs-cost filtering, liquidity,
    OMS, broker reconciliation, financing, taxes, TCA.

- **Workstream D -- Maintainer manual articles with Implementation
  Trace.** Cost resolver, target-risk layer, walk-forward fold
  machinery. Each gets both Synthesis and Implementation Trace per
  the v0.1.8.11 Section 3.7 two-layer standard.

- **Workstream E -- Identity contract reference v2.** Extend the
  Batch 4 `?ledgr_identity_fields` substrate to cover risk-chain
  identity and walk-forward `candidate_key` / `session_id`
  composition. Pull the cost-API forward-obligation rows
  (synthesis Section 14:560) and the walk-forward Section 17
  gate-row obligations (2026-06-05 horizon entry above) into the
  canonical reference.

- **Workstream F -- v0.1.9.x performance and decisions internal
  arc.** Narrative covering target-risk's per-pulse restructure,
  walk-forward's wrapper-not-engine choice, the cost-API spec-cut
  discipline, and the LDG-2575 measurement-spike methodology
  refinement (row-total measurement + focused-loop attribution).
  Same internal-first-not-marketing posture v0.1.8.11 used.

- **Workstream G -- Release surfaces.** NEWS, roadmap, horizon
  housekeeping, design index, RFC index, performance-arc index
  update.

**Naming rationale (risk-and-cost vs execution-policy):**

The v0.2.x roadmap has an `Execution Policy Pipeline` north-star RFC
planned (broader scope: OMS, liquidity, order policy, paper / live).
The v0.1.9.5 vignette is bounded to risk plus cost as the
in-between layer between strategy targets and fills; timing stays in
`execution-semantics.qmd` with a forward-reference. The
`risk-and-cost` name avoids collision with the future v0.2.x
execution-policy work.

**Sequencing:**

- Spec scoping starts during v0.1.9.4 ticket-cut so target-risk
  decisions (v0.1.9.3 shipped earlier) and walk-forward decisions
  (Section 17 gates) are absorbed as they bind. Lead time analogous
  to the v0.1.8.10 to v0.1.8.11 transition.
- Implementation starts after v0.1.9.4 ships.
- Auditr cycle runs against the refreshed v0.1.9.5 surface; findings
  absorb into v0.1.9.6 or v0.2.x feature packets. Same auditr-after
  pattern the v0.1.8.11 to v0.1.9.1 flow established.

**Non-scope:**

- Marketing or external benchmark claims.
- New public APIs (the docs cycle surfaces what shipped; if a doc
  surfaces a real contract bug, route to a follow-on ticket).
- Execution-semantics changes.
- v0.2.x feature work (liquidity, OMS, snapshot lineage, paper /
  live).
- Walk-forward Section 17 gate-row additions to the synthesis
  (those bind at v0.1.9.4 ticket-cut, not in the docs cycle).

**Relationship to the existing roadmap placeholder:**

The roadmap currently carries a `v0.1.9.x Follow-On Documentation
After v0.1.8.11` entry, which was the bounded-remainder placeholder
in case v0.1.8.11 left documentation work undone. v0.1.9.5
supersedes that placeholder: it is the substantive teaching-and-
entropy cycle for the v0.1.9.x arc, not a remainder cleanup. The
roadmap entry should be updated when v0.1.9.5 reaches active
planning (per the roadmap discipline that next-planned milestones
carry detail and later ones carry intent bullets only).

This entry records the intent. The actual spec packet binds the
workstream details when v0.1.9.4 closes; the auditr cycle that
follows v0.1.9.5 will produce the next round of THEME-style findings.

### 2026-06-01 [strategy] Strategy callback contract + authoring helpers post-v0.1.8.x direction

The paired RFC cycle for the v0.1.8.10 strategy callback contract addendum
(`rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md`, final
review approved) and the v0.1.8.x strategy authoring helpers
(`rfc_strategy_authoring_helpers_v0_1_8_x_synthesis.md`, final review
approved) closes the cross-sectional strategy authoring direction for the
v0.1.8.x arc. The accessor synthesis binds the `ctx$vec` universe-aligned
vector namespace, the `ctx$idx()` instrument-id-to-position resolver, and
bulk `ctx$vec$feature(feature_id)` reads. The helpers synthesis binds
extension (not replacement) of the existing exported pipeline
(`signal_return`, `select_top_n`, `weight_equal`, `target_rebalance` plus
value types `ledgr_signal`, `ledgr_selection`, `ledgr_weights`,
`ledgr_target`) across two passes: Pass 1 internal optimization in
v0.1.8.10 where existing helpers consume `ctx$vec` with no public surface
change, Pass 2 per-stage public helper additions in v0.1.9.x (per the
roadmap's `v0.1.9.x Target Construction Helper Extensions` slot).

Feature-engine vector extensions
- Bulk multi-feature reads beyond the single-feature
  `ctx$vec$feature(feature_id)` surface — separate feature-engine RFC if
  the single-feature surface proves insufficient in practice.
- Feature-map vector output and alias-map vector interactions — same
  feature-engine RFC.
- Lookback-window vector access (per-instrument history through
  `ctx$vec`) — same feature-engine RFC.
- Public scalar `ctx$feature_at(feature_id, idx)` sugar over
  `ctx$feature(ctx$vec$id[idx], feature_id)` — same RFC.

Long-short, hedged, and levered authoring helpers
- Short, market-neutral, pair-helper families. Currently gated by the
  negative/levered-weights rejection at `R/strategy-helpers.R:226-231`;
  cannot be promoted to public helpers without first binding
  shorting/leverage contract semantics in a separate RFC.
- Hedge-ratio constructors and beta-neutral target builders — same gate.

Cost-aware sizing
- Strategies do not receive cost-related state today; the cost-API
  synthesis (prior horizon entries) puts cost wiring downstream of the
  strategy callback. Any helper that estimates or optimizes transaction
  costs inside the strategy callback needs a read-only estimator RFC
  after the public cost API lands.

Declarative strategy constructor
- A `ledgr_strategy()` constructor composing signal / selection /
  weighting / sizing / triggers as named arguments — larger DSL, future
  RFC if the helper family grows enough to justify it. Not in scope for
  Pass 2.

Stronger read-only enforcement
- v0.1.8.10 enforces `ctx$vec` and `ctx$idx()` read-only semantics
  through documented convention plus mutation-leak tests. If post-CRAN
  use surfaces drift, a contract-hardening RFC evaluates locked
  bindings, active bindings, copy-on-access, or R6-style read-only
  context objects.

Compiled-strategy callback boundary
- The `ledgrcore-spike` external repo will report whether a compiled
  fold core changes strategy-callback economics. A compiled-strategy
  callback contract RFC is downstream of the spike report and out of
  scope until then.

Promoted roadmap hooks
- **v0.1.8.10**: accessor synthesis implementation (`ctx$vec`
  namespace, `ctx$idx()` resolver, bulk
  `ctx$vec$feature(feature_id)`); helpers synthesis Pass 1 internal
  optimization (existing exported helpers consume `ctx$vec` where it
  helps, no public surface change).
- **v0.1.9.x Target Construction Helper Extensions** (canonical roadmap
  slot; paired with the 2026-05-25 horizon entry): Pass 2 per-stage
  extensions per the helpers synthesis — rank-weight, inverse-vol,
  normalization, rebalance bands, target diagnostics.
- **v0.1.9.x or later — Feature-engine vector extensions**: bulk
  multi-feature reads, lookback vectors, alias-map vector interactions.
- **v0.1.9.x+ or v0.2.x — Long-short / hedged / levered authoring
  helpers**: gated on shorting/leverage contract RFC.
- **Post cost-API GA — Cost-aware sizing read-only estimator**: gated
  on the public cost API landing.
- **v0.2.x or later — Declarative strategy constructor**: larger DSL,
  conditional on helper family growth.
- **Post-CRAN or on user demand — Stronger read-only enforcement**:
  contract-hardening RFC for ctx immutability.
- **Post-`ledgrcore-spike` report — Compiled-strategy callback boundary
  contract**: gated on the external K1 spike comparison.

Immediate cross-cycle obligations

- The v0.1.8.10 spec packet listed both synthesis artifacts as binding design
  inputs and shipped the accessor / Pass 1 scope. v0.1.8.11 (shipped
  2026-06-04) made the resulting strategy-author surface discoverable in
  docs via the maintainer manual articles without promoting Pass 2
  helpers early; this obligation is closed.
- The negative/levered weights rejection block in `target_rebalance()`
  lives at `R/strategy-helpers.R:226-231` (precision over the helpers
  synthesis's `:226-230` citation); future RFCs and tickets citing
  this gate should use the corrected range.
- The v0.1.8.11 documentation pass collected horizon entries created
  during the v0.1.8.10 RFC closeouts, the same way this entry pairs the
  accessor and helpers cycles; this obligation is closed.

This entry does not authorize any of the above; it records the
direction. The accessor synthesis is binding for v0.1.8.10
implementation; the helpers synthesis is binding for v0.1.8.10 Pass 1
implementation and for v0.1.9.x Pass 2 design. Tickets cut from either
synthesis must respect that binding language and treat the deferrals
above as separate downstream RFCs.

### 2026-05-29 [research] Snapshot administration and research-loop helpers deferred

The v0.1.8.6 `LDG-2451` gate for snapshot administration, ETL provenance,
sweep-review helpers, and promotion-recovery-summary helpers was deferred by
maintainer decision during release closeout. The work remains useful, but it is
not required for the v0.1.8.6 materialization, benchmark, and attribution cycle,
and it should not distract from the v0.1.8.7 Optimization Round 2 hot-path
lanes.

When revived, likely in a v0.2.0-class RFC/spec cycle, keep the original shape:
separate engine-computed metadata, user-supplied descriptive metadata, and
administrative lifecycle state; preserve `snapshot_hash` independence from
mutable user metadata; keep sweep-review helpers explicit about ranking rules;
and keep promotion-recovery summaries factual rather than automated candidate
selection or validation.

This entry records direction, not committed work.

### 2026-05-26 [execution] Accepted OMS direction and intraday-safe target-decision storage

The accepted OMS synthesis is
`inst/design/rfc/rfc_ledgr_oms_seed_synthesis.md`. It binds a future v0.2.x
two-stream design: `order_events` records engine-owned order lifecycle, while
`ledger_events` remains accounting truth. The strategy contract stays
`function(ctx, params) -> full named numeric target vector`; paper/live adapters
remain deferred to v0.3.0+; and no sweep-to-live path is allowed.

The important long-horizon storage lesson is that target-decision persistence
must bind identity and reconstructability, not a universal full-JSON payload per
decision row. First EOD implementations may store full vectors directly, but
intraday-compatible designs need retention-dependent, batchable, and
potentially deduplicated/sparse/columnar/payload-reference storage without
destructive migration from the EOD shape.

### 2026-05-25 [infrastructure] Pre-CRAN compatibility policy

Until ledgr is released on CRAN, stored artifacts, database schemas, config
hashes, provenance formats, and experimental APIs may change without backward
compatibility or a deprecation cycle. Pre-CRAN artifacts are development
artifacts; users should expect to rerun experiments after upgrading when a
cycle changes storage, hashing, or execution contracts.

This does not weaken current-version trust. Fingerprint pins, release gates,
contract tests, hash verification, and reproducibility discipline remain
load-bearing for agent containment and within-cycle correctness. Once ledgr
reaches CRAN, revisit this policy and define explicit compatibility and
deprecation rules.

### 2026-05-13 [ux] Future tune-wrapper naming

After `ledgr_sweep()` exists and the fold core is stable, revisit whether a
convenience wrapper such as `ledgr_tune()` is useful. This should remain parked
until sweep result shape, objective/ranking ownership, and candidate promotion
are stable.

### 2026-05-26 [ux] Tidy/vectorized strategy authoring layer

Active parameterized feature aliases give strategies stable column names such
as `fast` and `slow`. That may eventually support a tidy or vectorized
strategy-authoring layer for stateless, cross-sectional pulse logic.

Possible future shape:

```r
strategy <- ledgr_vector_strategy(function(features, ctx, params) {
  transform(features, target = ifelse(fast > slow, params$qty, 0))
})
```

or a more ledgr-native signal wrapper that maps row-wise feature predicates to
a full named target vector.

This should not replace the core `function(ctx, params)` strategy contract.
It is only appropriate for strategies that read current pulse data, compute
row-wise instrument targets, and do not require arbitrary per-instrument
control flow, order-dependent allocation, or custom state mutation. Active
aliases and grid helpers have since stabilized (v0.1.8.4); the 2026-06-01
paired strategy callback contract + authoring helpers synthesis (this file)
binds a different surface for the same authoring intent: the `ctx$vec`
universe-aligned vector namespace plus the existing `signal_return` /
`select_top_n` / `weight_equal` / `target_rebalance` exported pipeline.
Treat this entry as a superseded earlier sketch of the same direction; the
two RFC synthesis documents are the binding designs going forward.

### 2026-05-13 [ux] Research workflow scaffolds and companion templates

ledgr may eventually benefit from templates, but the first core-owned template
surface should be research workflow scaffolding rather than alpha/strategy
cookbooks. The useful core template is a complete reproducible study scaffold:
snapshot creation, feature registration, strategy file, feature and strategy
parameter grids, sweep script, held-out validation, report skeleton,
assumptions log, and candidate-promotion checklist.

Possible future core helper:

```r
ledgr_new_research_project(
  path = "research/sma-crossover",
  template = "active-alias-sweep"
)
```

Possible first core scaffold:

```text
my-ledgr-study/
  README.md
  data-raw/
  snapshots/
  R/
    strategy.R
    features.R
    params.R
  scripts/
    01_make_snapshot.R
    02_single_run.R
    03_sweep_train.R
    04_validate_test.R
    05_promote_candidate.R
  reports/
    sweep_review.qmd
    validation_report.qmd
  ledgr.yml
```

The point would be to encode the boring correct workflow: sealed data,
registered features, explicit feature and strategy params, train/sweep/evaluate
discipline, review artifacts, and promotion decisions. Tiny example strategies
such as flat baseline or SMA crossover can appear in core only as contract
demonstrations, not as profitable-strategy templates.

A companion repository can own richer strategy templates after the v0.1.8.4
active-alias and grid-helper UX stabilizes. That repository should be framed as
educational templates or recipes, not official strategies. It can contain
copyable examples such as SMA crossover, RSI threshold, breakout,
mean-reversion, and volatility-filter studies, each with its feature map,
feature grid, strategy grid, sweep script, and explanation. Keeping these
outside the core package lets examples be richer without turning ledgr into a
strategy library.

Suggested split:

- core `ledgr`: `ledgr_new_research_project()` or equivalent scaffold command,
  plus one or two minimal built-in workflow templates;
- companion repo: opinionated educational strategy templates and longer
  walkthroughs;
- core docs: link to the companion repo once it exists, but continue to teach
  the canonical workflow through package-owned examples.

This fits the agentic-research thesis because agents can work more safely in a
known structure with explicit files such as `hypothesis.md`, `strategy.R`,
`params.R`, `sweep_results.rds`, `validation_report.qmd`, and
`promotion_decision.md`.

Do not pull this into v0.1.8.4. Active aliases, grid helpers, pulse-debug
inspection, and the single demo strategy should land first; scaffolding should
encode that stabilized workflow rather than shape it.

The accepted research workflow synthesis places canonical workflow
documentation in v0.1.8.5. Treat that as the prerequisite for any scaffold
helper: first teach the workflow, then generate it only if review evidence
shows project setup remains too costly.

When the v0.1.8.5 spec packet is cut, carry these synthesis-review notes into
acceptance criteria:

- the workflow article should be runnable end to end and should produce or
  walk through a review/report shape matching the synthesis outline:
  hypothesis and data window, snapshot hash and source assumptions, feature and
  strategy declarations, candidate-grid summary, top-N candidate table,
  warning/failure review, equity/drawdown plots, promotion note, and rejection
  rationale for alternatives;
- any small helper admitted by the spec must be documentation-supporting
  inspection or summary ergonomics only. It must not add storage layers,
  dispatch paths, identity surfaces, scaffold generation, or execution
  semantics;
- the spec should name the auditr tasks that exercise the canonical workflow
  and route findings against those surfaces;
- the spec should make visible that point-in-time regressor design is a
  prerequisite for broad ML/factor strategy workflows.

### 2026-05-26 [storage] Snapshot lineage and live data logs

Long-running research and production use different data lifecycle contracts.
Research snapshots are immutable replay inputs. New historical data, vendor
corrections, universe changes, and multi-vendor comparisons should create new
sealed snapshots rather than mutating old snapshots in place.

Future research-facing snapshot lineage should likely be lightweight metadata,
not a full versioning subsystem:

- `family`: logical group for related snapshots;
- `family_version`: monotonic or date-stamped version inside the family;
- `extends`: previous snapshot when the new snapshot adds later data;
- `supersedes`: previous snapshot when the new snapshot replaces corrected
  history;
- `lineage_note`: human-readable reason for the reseal.

A helper such as `ledgr_snapshot_family()` could make quarterly reseals,
vendor-correction reseals, universe expansion, and walk-forward snapshot
families inspectable without introducing split stores yet.

Production live data is a separate future surface. A promoted algorithm runs
against append-only ticks or bars that arrive after the backtest snapshot. That
surface needs feed identity, session/calendar policy, gap detection, repair or
backfill policy, correction policy, and linkage back to the promotion evidence.
Live ticks or bars should not be appended to the sealed snapshot that justified
the promotion. If live history becomes research evidence, the future workflow
should seal a historical range from the live log into a new immutable snapshot.

Do not implement this in v0.1.8.4. Keep it as production/paper-trading and
long-horizon storage design input. The important near-term rule is the
boundary: immutable snapshots for replay, append-only logs for live observation.

### 2026-05-26 [data] External point-in-time regressor snapshots

Serious quant research eventually needs point-in-time external data beyond
OHLCV bars: fundamentals, macro releases, analyst estimates, vendor factors,
and alternative data. These inputs have vintage semantics. A replay must use
what was known at the historical decision time, not later-revised values.

**Overlaps the 2026-05-25 "Point-in-time data tables" entry** — same v0.2.x
PIT external-data substrate from two angles (this one is the regressor/feature
use case; the other is the table/storage model). The eventual "External Data
And Point-In-Time Regressors" RFC should unify both, and also covers the
late/revised-tick axis of the 2026-05-28 live bad-data resilience entry.

DuckDB is the right default backbone for this in ledgr's foreseeable roadmap.
It is local-first, R-friendly, columnar, and supports ASOF-style lookup patterns
that fit point-in-time joins. That should cover daily, moderate intraday,
fundamental, macro, and many research-scale alternative-data workflows. The
breakpoints are large single-file stores, tick-scale data, and multi-writer
team platforms; those remain split-store or external-backend questions.

Future design should likely introduce sealed regressor snapshots with their
own lineage and hashes, then expose PIT-correct lookup/projection into the
existing pulse context:

```text
regressor source data
  -> sealed regressor snapshot with vintage metadata
  -> PIT-correct projection at pulse timestamps
  -> ctx feature/regressor values
```

Do not implement this opportunistically inside active aliases, ML, or adapter
work. It deserves a dedicated "External Data And Point-In-Time Regressors" RFC
covering schema, vintage fields, ASOF lookup semantics, leakage prevention,
lineage, feature-map integration, and storage scale breakpoints.

This should precede broad ML/factor strategy workflows. Those workflows depend
on vintage-correct external inputs, so model artifact provenance alone is not
enough.

### 2026-05-25 [education] Strategy family field guides

Future documentation should include literature-informed field guides for major
EOD trading strategy families. These are broader than reference strategy
templates: the goal is to teach the economic rationale, data requirements,
implementation shape, leakage risks, validation protocol, metrics, and
cost/capacity caveats for each family.

Possible families:

- time-series momentum;
- cross-sectional momentum;
- mean reversion;
- trend following and moving-average systems;
- carry or yield;
- value;
- quality;
- low volatility or defensive equity;
- sector or asset rotation;
- pairs or spread trading;
- event or earnings drift;
- volatility targeting;
- benchmark-aware active equity.

Each field guide should be literature-informed, with recognizable sources for
the economic rationale and known critiques. User-facing articles should stay
readable and practical, but they should not be winged. They should include a
short further-reading section and make clear that ledgr examples are
educational implementations, not trading advice or profitability claims.

Suggested article shape:

```text
1. Economic idea
2. Literature anchor
3. Data requirements
4. Causality/leakage traps
5. Minimal ledgr implementation
6. Variants
7. Metrics that matter
8. Validation protocol
9. Costs, capacity, and failure modes
10. Further reading
```

This depends on several future roadmap layers: target construction helper
extensions, benchmark context and active metrics, walk-forward and selection
integrity diagnostics, liquidity/capacity policy, point-in-time data tables,
corporate actions/instrument master, and reference strategy templates. It is
therefore a v0.2.x+ documentation/education arc, not near-term v0.1.8 work.

### 2026-05-13 [research] Deferred strategy and integration families

The shortened roadmap no longer carries detailed scope for portfolio
optimization support, calendar/event-driven strategies, pairs and spread
trading, reporting adapters, additional indicator backends, ML strategy
artifact management, or expanded asset-class support. Keep these families
parked until the research-to-paper arc is stable enough for focused RFCs.

Do not confuse full portfolio optimization with the existing helper pipeline
(`signal_*()` -> `select_*()` -> `weight_*()` -> `target_*()`). The roadmap now
names `v0.1.9.x Target Construction Helper Extensions` for small additions to
that helper surface. Full solver-style portfolio optimization remains deferred.

ML strategy artifact management depends on stable walk-forward windows,
point-in-time feature tables, model artifact identity, prediction-table
provenance, and selection diagnostics. Do not bolt it on as "call `predict()`
inside a strategy."

The likely long-term abstraction is still pulse-based. An ML strategy should
make decisions at the same no-lookahead pulse boundary as every other ledgr
strategy:

```text
current pulse context -> model prediction or prediction lookup -> target vector
```

Naively calling `predict()` inside every pulse will be expensive, especially
for cross-sectional models, wide universes, and large sweeps. That cost should
be handled with implementation choices rather than by changing the abstraction:
load models once per run/candidate, precompute prediction matrices when the
model and feature set are fixed, cache prediction artifacts by snapshot hash,
feature-set hash, alias-map hash, and model artifact hash, and let strategies
read prediction values from the pulse context when that is the chosen mode.

Future ML design should distinguish:

- live pulse prediction: clearest semantics, highest cost;
- precomputed prediction artifacts: faster for sweeps and replay, still causal
  if generated from point-in-time features and immutable model artifacts.

Do not lock this API now. The insight to preserve is that ML decisions remain
pulse decisions; optimization should move model loading and prediction
materialization out of the hot path when possible.

When ledgr reaches ML strategy workflows, `pins` and `vetiver` are likely the
right boundary tools for model artifacts. `pins` can version and share R
objects or files on local, Posit Connect, S3, and related boards with metadata,
versions, and hashes. `vetiver` builds on that model-artifact layer for trained
models, input prototypes, deployment, model cards, environment checks, and
monitoring.

Future policy should likely be:

- ledgr DuckDB store remains the source of truth for sealed snapshots, runs,
  sweeps, fills, metrics, promotion notes, and references to external model
  artifacts;
- `pins` / `vetiver` own trained model objects, model metadata, input
  prototypes, renv lockfiles, model cards, and monitoring artifacts;
- ledgr provenance records exact model artifact references such as board,
  name, version, pin hash, training snapshot hash, feature-set hash, alias-map
  hash, and strategy hash;
- ledgr must not depend on "latest model" lookup for deterministic replay. A
  backtest or promotion record should identify an immutable model version or
  hash;
- live vetiver endpoints are production-serving surfaces, not replay evidence,
  unless they resolve back to a specific pinned model artifact.

Do not turn this into a near-term dependency decision. The relevant ledgr API
surfaces are not stable yet, and pins/vetiver integration deserves its own RFC
when ML workflows become active scope. For now, workflow/artifact-topology RFCs
may mention pins/vetiver as future-compatible tools, but should not lock a
production API around them.

### 2026-05-16 [research] Randomized and blocked slice diagnostics

Walk-forward should ship before randomized slice protocols. For time series,
"random slices" must not mean arbitrary row-level train/test splits that violate
causality. Future designs should build on the walk-forward window model and
make slice semantics explicit.

Possible future protocols:

- random contiguous train/test windows;
- random anchored train/test windows;
- blocked or bootstrapped windows with no-lookahead constraints;
- combinatorial symmetric cross-validation;
- PBO/CSCV-style selection-bias diagnostics.

These should remain separate from the first `ledgr_walk_forward()` release.
They require stable sweep result shapes, metric context, grid ergonomics,
parallel dispatch, slice-aware feature validation, and a clear explanation that
provenance records what happened but does not prove selection integrity.

The accepted first walk-forward design is
`inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`
(with Amendment 1 dated 2026-06-04 in Section 14, Amendment 2 dated 2026-06-04
in Section 16, and Section 17 ticket-cut gates; final-review artifact and
closure update at
`inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_final_review.md`).
Amendment 2 strengthens four Amendment 1 routings from procedural constraints
on open spec-cut questions to substantive defaults: opening-state policy
defaults to `carry_test_state` with a warned `flat_test_state` opt-in;
selection rules fail closed for level metrics with metric-registry
classification; extraction has no implicit fold default and requires a
`selection_rationale` when `"latest"` is used; and default print method's data
contract is an operational per-fold degradation table with named fields and a
render-order contract. Section 17 binds a two-gate ticket-cut matrix
(packet-open and release-gate enforcement) over Amendments 1 and 2. Future
diagnostic work should consume its fold/session/score artifacts rather than
reopening the v1 wrapper-over-run/sweep architecture, and must not assume
per-fold independence under the `carry_test_state` default (see synthesis
Section 16.6 path-dependency obligation).

Promoted roadmap hook: `v0.1.9.x Selection Integrity Diagnostics`.

### 2026-05-13 [infrastructure] Public parallel sweep backend

The v0.1.8 architecture should stay parallel-ready, but a public parallel sweep
feature remains unscheduled. Before promotion, ledgr needs decisions on worker
package setup, `workers > 1` failure modes, worker-local output isolation,
interrupt semantics beyond discard-all, and whether mirai remains the backend
or becomes one backend behind a small internal abstraction.

Evidence and design breadcrumbs:

- `inst/design/spikes/ledgr_parallelism_spike/summary_report.md`
- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`
- `inst/design/rfc/rfc_parallelism_spike_architecture_consequences.md`
- `inst/design/rfc/rfc_parallelism_spike_architecture_consequences_response.md`
- `inst/design/manual/sweep.qmd`

Known spike findings to preserve: mirai is viable on Windows native R and
Ubuntu/WSL as an optional backend; sequential sweep must not depend on mirai;
`workers > 1` without mirai should fail loudly rather than silently fall back;
parallelism belongs at candidate dispatch, not inside one candidate's fold; and
workers should return candidate results to the orchestrator rather than writing
shared DuckDB state.

### 2026-05-13 [infrastructure] Parallel worker setup and Tier 2 packages

SPIKE-8 showed that package-qualified calls can work on workers when the
package is installed, but unqualified calls such as `mutate()` or `SMA()` need
explicit setup such as `everywhere({ library(dplyr); library(TTR) })`. Helper
objects assigned in setup did not persist under mirai's default cleanup, which
is useful because it prevents arbitrary `.GlobalEnv` helper smuggling.

Future parallel sweep design should revisit whether dependency information
comes from an explicit `worker_packages` argument, strategy preflight output, a
companion dependency check, or a combination. A tier label alone is not enough
for parallel Tier 2 execution.

Evidence:

- `inst/design/spikes/ledgr_parallelism_spike/summary_report.md`
- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`
- `inst/design/manual/sweep.qmd`

### 2026-05-13 [infrastructure] mori as transport, not hot lookup

SPIKE-7 showed that `mori::share()` crosses the mirai worker boundary on
Windows and Ubuntu/WSL and can shrink serialized payload handles dramatically.
The same spike showed slower lookup than plain in-process matrices for
fold-like feature access. Treat mori as a future transport/memory-pressure tool,
not the default representation for hot per-pulse feature lookup.

Cases where mori may matter later: walk-forward or CSCV redispatches where
large payloads are re-sent often, very high worker counts where `workers x
payload_size` creates memory pressure, or remote/slow transport environments.

Evidence:

- `inst/design/spikes/ledgr_parallelism_spike/summary_report.md`
- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`
- `inst/design/rfc/rfc_parallelism_spike_architecture_consequences_response.md`

### 2026-05-13 [infrastructure] Worker-local read-only DuckDB transport

SPIKE-4 showed that concurrent worker-local read-only DuckDB access to a sealed
snapshot worked on Windows and Ubuntu/WSL and did not create WAL, temp, lock, or
other side files in the targeted probe. This keeps worker-local snapshot reads
available as a future transport path.

Future design should remember the interface consequence: the fold core must not
take a live DBI connection from the orchestrator. It should accept an abstract
input source that can represent either an in-memory precomputed payload or a
sealed snapshot path plus metadata for worker-local read-only lookup.

Evidence:

- `inst/design/spikes/ledgr_parallelism_spike/summary_report.md`
- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`
- `inst/design/manual/sweep.qmd`

### 2026-05-13 [infrastructure] Parallel interrupt and partial-result semantics

The v0.1.8 architecture currently recommends discard-all interrupt semantics
for the first sweep implementation. Returning partial sweep results later would
need a polling collector, checkpoint semantics, cancellation rules, and clear
atomicity guarantees. Do not add partial-result behavior casually as a UX patch;
it is a parallel output contract.

Evidence:

- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`
- `inst/design/manual/sweep.qmd`

### 2026-05-13 [data] Feature payload scale and indicator-width stress

The parallelism spike deliberately tested feature-width payloads because
indicator sweeps multiply columns per instrument. Plain R serialized payloads
were acceptable for v0.1.8 EOD-scale sweep when preloaded once, but larger
universes, intraday-like pulse counts, walk-forward folds, CSCV/PBO partitions,
and indicator-parameter sweeps can multiply payload size quickly.

Future feature-transport work should preserve three paths: explicit in-memory
precomputed payloads, worker-local read-only snapshot lookup, and future
shared-memory payloads. Do not bake in a pre-fetch-only design.

Evidence:

- `inst/design/spikes/ledgr_parallelism_spike/summary_report.md`
- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`
- `inst/design/manual/sweep.qmd`

### 2026-05-13 [cost] Broker and exchange cost templates

Core ledgr should own stable cost primitives before any broker/exchange-like
templates are considered. Real fee schedules are account-specific,
jurisdiction-specific, and change over time. If templates are added later, they
should likely live in adapter packages or be clearly labelled approximations.

### 2026-05-25 [execution] Liquidity and capacity are not transaction cost

Future liquidity and capacity policy should be named separately from
transaction-cost modeling. Cost models answer "what price and fee did this
proposed fill receive?" Liquidity/capacity policy answers "is this proposed
quantity feasible, should it be clipped, or should it be refused?"

Possible future concepts:

- participation limits;
- ADV/volume filters;
- minimum price and minimum volume constraints;
- turnover and capacity diagnostics;
- liquidity refusal or quantity clipping.

These policies require execution-bar data such as next-bar volume and may
change quantities. They therefore belong in execution/liquidity policy, not in
cost application. Promoted roadmap hook: `v0.2.x Liquidity And Capacity Policy`.

### 2026-05-14 [sweep] Promotion-grade sweep artifacts

Future design: save/load complete sweep result bundles with manifest, snapshot
locator hints, strategy/feature recovery metadata, and verification helpers.
Useful for expensive sweeps and offline audit. Deferred because v0.1.8 stores
selection context on promoted runs instead.

Bounded first shape: persist grid definition, candidate summaries,
warnings/errors, metric context, feature-set hashes, execution seeds, ranking or
selection view, manifest data, and snapshot locator hints. Do not persist full
ledger, fill, trade, or equity artifacts for every candidate by default.

Promoted roadmap hook: `v0.1.9.x Sweep Artifact Persistence`.

### 2026-05-14 [execution] Structured RNG preflight metadata

LDG-2104 added human-readable strategy preflight notes for RNG state mutation
and ambient RNG use. Future sweep audit/provenance work may want structured
fields such as `ambient_rng_symbols` and `rng_mutation_symbols` instead of
parsing notes or reasons.

Source: LDG-2104 code review.

### 2026-05-14 [execution] Broader ambient RNG detection

LDG-2104 classifies `runif()`, `rnorm()`, and `sample()` as ambient RNG Tier 2
calls. Future preflight hardening should consider the broader `stats` RNG
family, such as `rbinom()`, `rpois()`, `rexp()`, and `rgamma()`, so stochastic
strategies are not accidentally classified Tier 1.

Source: LDG-2104 code review.

### 2026-05-25 [strategy] Target construction helper extensions

The public helper pipeline already includes `signal_return()`,
`select_top_n()`, `weight_equal()`, and `target_rebalance()`. Future work should
extend that pipeline conservatively instead of introducing a separate portfolio
construction engine.

Potential additions:

- rank-weight helpers;
- inverse-volatility weighting;
- explicit normalization helpers;
- rebalance bands or no-trade zones where semantics are target-construction
  rather than execution policy;
- small diagnostics that explain how weights became full target quantities.

Keep this separate from target risk, liquidity/capacity, transaction cost, and
full portfolio optimization. Promoted roadmap hook:
`v0.1.9.x Target Construction Helper Extensions` (per the canonical roadmap
entry; the paired-cycle synthesis in
`rfc_strategy_authoring_helpers_v0_1_8_x_synthesis.md` binds Pass 2 per-stage
helper extensions to that window. See the 2026-06-01 post-synthesis horizon
entry below.).

### 2026-05-27 [risk] Affordability belongs in target risk

The research fold treats strategy output as desired target quantities and
applies deterministic next-open fills. Until the target-risk chain exists, raw
targets can request more exposure than available cash supports; the fold records
the fill and cash can go negative. That arithmetic is reproducible, but it is
not a declared margin model.

The v0.1.9 target-risk RFC should treat capital discipline as a first-class
risk adapter, alongside long-only and max-weight constraints. The minimum shape
should include an explicit capital floor or affordability rule inserted between
target validation and fill timing, preserving the strategy contract: strategies
declare desired holdings; risk transforms, rejects, or annotates targets before
execution.

### 2026-05-24 [research] Beta as three distinct uses

Beta is semantically important and architecturally complex partly because the
"same" beta means three different things at different layers:

```text
1. beta as post-run diagnostic
   Did the strategy just load on the market?
2. beta as strategy feature
   Did this instrument have high/low rolling beta at the decision time?
3. beta as target-risk constraint
   Should the target portfolio be scaled/hedged to a beta exposure?
```

Each use has a different complexity profile and different upstream
dependencies. Diagnostic beta needs benchmark returns only. Feature beta also
needs point-in-time alignment with the strategy's decision time and would
interact with feature fingerprinting (the determinism module extracted in
LDG-2212). Constraint beta needs both of the above plus the v0.1.8.9
target-risk chain.

When beta work eventually opens, keep these three uses as separately scoped
sub-questions rather than collapsing them into one design pass. Each use
unblocks on different upstream work:

```text
diagnostic beta : after benchmark/reference-return substrate
                  (`ledgr_metric_context$benchmark` per the accepted
                  v0.1.8.2 synthesis).
feature beta    : after benchmark substrate plus a point-in-time
                  feature/reference alignment design that defines whether
                  rolling beta at pulse t may use returns ending at t or
                  must use returns strictly before t.
constraint beta : after benchmark substrate, feature-alignment design, and
                  the v0.1.9 target-risk chain.
```

Do not gate diagnostic beta on the risk chain; the dependency is
benchmark-only.

### 2026-05-24 [data] External benchmark first, universe-derived later

Future benchmark reference-return support should start with explicit external
series (for example SPY total returns, Fama-French market return, or a CRSP
value-weighted market series) rather than benchmarks derived from the ledgr
trading universe.

Universe-derived benchmarks require point-in-time membership semantics,
introduce survivorship-bias risk depending on snapshot construction, and
depend on market-cap or other reference data that ledgr does not own.
External benchmarks are cleaner and let benchmark work proceed without
resolving universe-membership semantics first.

This aligns with the accepted v0.1.8.2 metric-context synthesis, which
reserves `benchmark` as a NULL field with an "aligned return provider"
contract and prohibits ticker-symbol hidden lookup.

A future `ledgr_benchmark_from_universe()` may still be useful but should be
designed after external benchmarks ship and after point-in-time universe
semantics are explicit.

Promoted roadmap hook: `v0.2.x Benchmark Context And Active Metrics`.

### 2026-05-25 [data] Point-in-time data tables

Future external observations and reference data need point-in-time semantics
before ledgr can honestly support fundamentals, earnings, macro, index
membership, factor features, or universe-derived benchmarks.

Concepts to define:

- `known_at`;
- `available_at`;
- `effective_at`;
- `event_time`;
- `revision_time`;
- provider/source/version metadata;
- alignment policy to strategy decision timestamps.

This is distinct from adapter provenance. Provenance says where data came from;
point-in-time tables say when a strategy was allowed to know it. Promoted
roadmap hook: `v0.2.x Point-In-Time Data Tables`.

### 2026-05-25 [data] Corporate actions and instrument master

Sealed snapshots are reproducible, but reproducible survivorship-biased data
can still be wrong for many research claims. Serious equity research eventually
needs explicit handling for:

- raw versus adjusted price policy;
- splits and dividends;
- delistings and delisting returns;
- symbol changes;
- stable instrument identifiers;
- point-in-time universe membership.

This should coordinate with point-in-time data tables and benchmark/reference
data design. Promoted roadmap hook:
`v0.2.x Corporate Actions And Instrument Master`.

### 2026-05-24 [adapters] External reference-data adapter provenance pattern

Any future external reference-data adapter (tidyfinance, FRED, central-bank
providers, broker APIs) should record provenance fields beyond the
data-identity hash:

```text
source            = "<provider name>"
function          = "<provider function called>"
provider_version  = packageVersion(...)
download_args     = <serialized args>
retrieved_at      = <ISO8601 UTC>
upstream_domain   = <provider-specific>
upstream_dataset  = <provider-specific>
date_range        = <ISO8601 UTC>
symbols           = <if applicable>
```

These fields let a future audit reproduce or at least verify what was
downloaded when. They should not enter the reference object's identity hash
unless they change the data interpretation; they are reproducibility
metadata, not execution identity.

Adapter shape conventions to preserve when adapter work eventually opens:

- `Suggests:` not `Imports:` for the upstream package;
- `rlang::check_installed(...)` at adapter entry;
- empirical verification of upstream unit/format semantics before the
  adapter ships (see `spikes/ledgr_tidyfinance_unit_probe/`);
- no hidden downloads inside metric, strategy, indicator, or fold-core paths.

Per the accepted v0.1.8.2 metric-context synthesis, external adapters are
deferred until the substrate they produce (`ledgr_metric_context` fields
with aligned-provider contracts) is stable.

### 2026-05-24 [data] Provider risk-free source divergence

The `ledgr_tidyfinance_unit_probe` spike found that tidyfinance's standalone
`download_data_risk_free()` endpoint and its Fama-French factor endpoint do
not return interchangeable `risk_free` values for the same calendar period.
For example, tidyfinance 0.5.0 returned January 2010 standalone monthly
`risk_free = 0.000016898`, while the Fama-French 3-factor monthly endpoint
returned `risk_free = 0` for the same month.

This is not necessarily a provider bug. The standalone endpoint is
FRED-derived and converted by tidyfinance; the Fama-French endpoint reflects
the factor dataset's own rounded file. A future factor or reference-data
adapter must preserve this distinction instead of silently treating every
column named `risk_free` as the same source.

Future RFCs that expose multiple risk-free sources should require explicit
source selection and provenance fields for endpoint, dataset, provider
version, and frequency. Metric-context construction must reject ambiguous
"risk-free from provider" requests when more than one provider endpoint could
produce the series.

### 2026-05-25 [infrastructure] DuckDB-backed feature storage and out-of-core projection

The v0.1.8.3 grid-level feature artifacts synthesis intentionally starts with
an R-memory runtime projection because the measured hot path is per-pulse R
object churn, not persistent feature storage. DuckDB is still the natural future
backing for precomputed feature libraries once parameterized indicator grids,
parallel sweep workers, and ML/export workflows need persistence and shared
feature storage.

Future direction:

- `ledgr_precompute_features()` computes feature values through the existing R
  indicator engine (`series_fn()`, TTR adapters, custom indicators) and writes
  concrete feature values to DuckDB-backed feature tables;
- the fold consumes the same projection interface introduced in v0.1.8.3, with
  a DuckDB-backed implementation that loads pulse blocks into memory;
- DBI access happens at block boundaries, not per pulse;
- layer 4 research/export artifacts and out-of-core runtime projection share
  the same DuckDB storage rather than introducing separate schemas;
- parallel workers can read shared DuckDB-backed feature storage instead of
  each materializing the same feature library.

Do not turn this into a DuckDB indicator-computation engine by default. The
authoritative indicator extension surface remains the R `series_fn()` contract
and the planned TTR/custom-indicator path. SQL-native built-in indicators may
be explored later as an opt-in fast path, but only with a separate RFC covering
feature identity, determinism, DuckDB-version sensitivity, mixed R/SQL feature
maps, and parity against the R implementation.

Dependencies before promotion:

- v0.1.8.3 runtime projection interface and R-memory backend have landed;
- v0.1.8.4 active aliases have fixed the alias-map identity and grid-level
  concrete-feature-union contract;
- the post-v0.1.8.3 residual report shows memory scaling, repeated precompute,
  ML/export, or parallel-worker sharing as the next load-bearing bottleneck.

### 2026-05-28 [optimization] Feature projection shape post-v0.1.8.x direction

The accepted synthesis
`rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md` binds the
next feature-projection materialization direction: v0.1.8.6 first removes
redundant cache-key fingerprint work, then stops building full-panel long
`ctx$feature_table` rows by default. Wide/projection-backed accessors are the
decision-time surface; long becomes inspection/export/research shape. This entry
uses no feature "v1" shorthand; work is assigned to v0.1.8.6, v0.1.8.9, or later.

#### Lookback and portfolio windows

- `ctx$window()` is accepted as the causal lookback primitive, but enters
  v0.1.9 only if target-risk or portfolio-risk work needs covariance windows.
- First public shape, when cut, is single-feature `n_inst x lookback` matrix
  with leading `NA_real_` warmup columns.
- Multi-feature/tensor/list window shapes are future API work after the first
  matrix contract exists.

#### Long research/export layer

- Runtime long `ctx$feature_table` is not the training-frame surface.
- Full-panel long feature export, ML training frames, and tidy EDA helpers need
  a separate research/export API cycle.
- PIT regressor and feature-store interchange belong with the later PIT/data
  provider track.

#### Persistent event schema and replay

- LDG-2410 typed memory events are complete and memory-scoped.
- Typed persistent columns for `cash_delta` and `position_delta` are the
  persistent counterpart and are preferred over a DuckDB-SQL-only replay patch
  if storage/schema work is accepted.
- Broader typed event metadata remains future event-schema work.

#### DuckDB-backed projection and storage

- v0.1.8.6 DuckDB/storage work should consume the simplified projection
  contract after schema-only `feature_table` is in place.
- DuckDB must remain a block/storage boundary, not a per-pulse runtime query
  engine.
- No future storage path should reintroduce full-panel long materialization by
  default.

#### Collapse and primitive internals

- Primitive-internals discipline applies broadly.
- No collapse Imports dependency is authorized by the feature-projection
  materialization directions.
- Collapse remains governed by
  `rfc_collapse_primitive_internals_v0_1_9_synthesis.md`: measured hot frames,
  deterministic wrapper, and parity gates only.

#### Promoted roadmap hooks

- v0.1.8.6: feature cache-key dedup for feature-definition fingerprint and
  feature-engine version.
- v0.1.8.6: schema-only `ctx$feature_table` default plus non-fast-path rebuild
  fix.
- v0.1.8.6: post-5.0/post-5.1 remeasurement and instrument x feature sweep.
- v0.1.8.6, if storage/schema work is explicitly accepted: typed persistent
  `cash_delta` and `position_delta` columns.
- v0.1.9, only if target-risk/portfolio-risk needs it: single-feature
  `ctx$window()` matrix API.
- Later: multi-feature/tensor windows.
- Later: full-panel long export/training APIs and PIT feature-store
  interchange.
- Later: broader typed event metadata beyond replay deltas.

#### Immediate cross-cycle obligations

These obligations were directed at the v0.1.8.6 spec packet (now shipped):

- 5.0 was cut before 5.1 and remeasured after each — landed.
- Width-invariance and benchmark claims were withheld until the instrument
  x feature sweep ran in read/score and turnover modes — landed.
- Typed persistent `cash_delta` and `position_delta` columns (5.6) were
  evaluated against scope; 5.6 was deferred and recorded as designed future
  storage work rather than shipped as an incomplete SQL-only patch.

This entry does not authorize any of the above by itself; it records the
post-synthesis direction and deferrals. Concrete work remains governed by the
accepted synthesis and the relevant spec packets. The remaining open items
in the hooks list above (multi-feature/tensor windows, long export/training
APIs, broader typed event metadata) carry to later v0.1.x/v0.2.x cycles.

### 2026-05-28 [optimization] Persistent DB-replay reconstruction via DuckDB SQL

`ledgr_reconstruct_positions()`, `ledgr_reconstruct_cash()`, and
`ledgr_rebuild_derived_state()` (`R/derived-state.R`) replay the persisted
`ledger_events` table with `jsonlite::fromJSON(meta_json)` **per row** in an R
loop, plus named-vector grow-by-assignment. This is the reopen / resume /
rebuild-from-store path - NOT the main backtest reconstruction, which is already
vectorized via `findInterval` + `cumsum` in `ledgr_run_fold`. It is O(events)
with a JSON parse per event and bites when reloading large persisted runs.

This is a SEPARATE surface from LDG-2410 ("Typed Memory Event Representation",
shipped v0.1.8.3, `scope: sweep_memory_path`): LDG-2410 typed the *in-memory*
sweep events and never touched the persistent DB-replay path.

Fix without a schema change: push the delta aggregation into DuckDB SQL, e.g.
`SELECT instrument_id, SUM(CAST(json_extract(meta_json,'$.position_delta') AS
DOUBLE)) ... GROUP BY instrument_id` (cash is the ungrouped sum). DuckDB does the
JSON extract + grouped sum in C, eliminating the R loop and the per-row parse.
The typed-DB-columns alternative also works but requires a `ledger_events` schema
migration.

Secondary (reopen/resume) cost today, but O(events) with a per-row JSON parse;
the obvious next target once persisted-run reload or walk-forward replay becomes
load-bearing. Surfaced by the v0.1.8.5 feature-payload spike's collapse-alignment
review.

### 2026-05-25 [architecture] Primitive internals and collapse acceleration

The LDG-2413 pulse-view construction spike found that the important design
lesson is broader than any single package choice: ledgr should prefer primitive
internal shapes (vectors, matrices, lists, and index maps) and treat
data.frames as public boundary views rather than hot-path state.

Spike artifact:

- `dev/spikes/ledgr_v0_1_8_3_pulse_view_construction/`;
- `inst/design/spikes/ledgr_v0_1_8_3_pulse_view_construction/pulse_view_construction_report.md`.

Reference-shape median timings from the spike:

| construction path | median |
| --- | ---: |
| current feature views, 50 candidates | 8.03s |
| base `split()` feature views, 50 candidates | 1.96s |
| `tidyr` feature views, 50 candidates | 3.64s |
| `data.table` data-frame feature views, 50 candidates | 6.27s |
| `data.table` native feature views, 50 candidates | 5.06s |
| `collapse` feature views, 50 candidates | 0.68s |

All tested alternatives preserved the current `ctx$feature_table` and
`ctx$features_wide` schemas in the equality checks. `collapse::rsplit()` was
the fastest tested implementation, but importing `collapse` only for LDG-2413
would make a broad dependency decision from a narrow optimization surface.

Accepted planning authority:

- `inst/design/rfc/rfc_collapse_primitive_internals_v0_1_9_synthesis.md`.

Near-term policy:

- v0.1.8.3 should use base R split/nest-style construction where it is enough
  to recover the measured pulse-view setup cost;
- do not add `collapse` as an `Imports` dependency during v0.1.8.3 solely for
  pulse-view construction;
- preserve the spike results as evidence for the v0.1.9 primitive-internals
  planning gates (canonical roadmap slot
  `v0.1.9 Primitive Internals Planning Gates`).

Promoted v0.1.9 planning direction (status of each item shown):

- write a primitive-internals developer guide before broad implementation
  work — open;
- deterministic `collapse` wrapping with scoped `collapse::set_collapse()`
  state restoration — shipped v0.1.8.7 (commit "Add deterministic collapse
  wrapper") and bound by ADR 0004;
- micro-profile event-boundary output buffer path — diagnostics landed in
  v0.1.8.8 Batch 2 (per-pulse telemetry sampling) and the `setv` rewrite
  shipped in v0.1.8.9 Batches 5-7;
- decide whether `collapse` becomes the package's R-side acceleration layer
  — bound by ADR 0004 (collapse added as `Imports` in v0.1.8.7); future
  micro-passes follow the deterministic-wrapper rules above;
- keep FIFO redesign, arbitrary strategy callback compilation, and a
  compiled fold core as separate decisions with their own parity gates —
  preserved (compiled core is now the `ledgrcore-spike` external repo per
  the 2026-05-30 entry).

This direction also supports the longer-term DuckDB and compiled-core horizon
items. Primitive matrices/lists map more cleanly to DuckDB columns, block
buffers, and eventual FFI boundaries than repeatedly constructed data.frame
objects.

### 2026-05-25 [api] Future ctx$feature_table deprecation review

The LDG-2413 usage audit found `ctx$feature_table` usage in internal
validation/inspection helpers and test scaffolds, but no documented vignette or
example strategy pattern that depends on the long-form feature table. v0.1.8.3
therefore preserves and prebuilds the field to avoid a context-contract change,
but the field is a plausible future simplification target.

A later RFC can decide whether `ctx$feature_table` should remain a public
strategy-facing field, move behind an inspection helper, or enter a formal
pre-CRAN deprecation path. That decision should be based on strategy-author
usage evidence and must not be folded into LDG-2413.

### 2026-05-25 [infrastructure] Compiled fold core after pipeline stabilization

The v0.1.8.3 sweep baseline shows that R-side fold execution dominates the
reference workload after v0.1.8.2. A future C, Fortran, C++, or Rust fold core
may become worthwhile if R-only optimizations leave walk-forward and large
sweep workloads too slow.

Do not start this rewrite while the fold pipeline is still moving. A compiled
core should wait until the surrounding execution contracts are stable enough
that the port can be contract-following rather than contract-setting.

Minimum gates before a serious port RFC:

- v0.1.8.4 active parameterized feature aliases have landed or been abandoned;
- the v0.1.9 target-risk chain has stabilized, including second-pass target
  validation and risk identity;
- walk-forward has produced real large-sweep workloads that justify native
  fold speed;
- public cost/liquidity/order-policy boundaries are stable enough that the
  compiled core will not immediately need structural rewrites;
- parity tests cover persistent versus memory accounting, typed events,
  metric-kernel behavior, target validation, promotion context, risk policy,
  and cost/liquidity semantics;
- fold-core values are represented by typed, serializable value objects where
  possible rather than loose ad hoc lists.

Near-term work that helps without committing to a port:

- keep expanding parity tests so a future port has a clear acceptance suite;
- formalize event, fill, lot-state, and fill-proposal shapes as typed value
  objects when touched by ordinary tickets;
- defer any FFI feasibility spike until after the v0.1.8.7 single-core pure-R
  cleanup and the v0.1.8.8 parallel-dispatch window have produced an optimized
  baseline. When revived, the spike should port only an
  isolated helper such as `ledgr_lot_apply_event()` via `extendr`, measure
  per-call FFI overhead against the LDG-2402 harness, reuse the LDG-2403 parity
  fixtures, and document Windows/Linux build friction. It must not introduce a
  production Rust path.

The port should not be treated as a v0.1.8.x optimization. The v0.1.8.x path
remains R-side optimization first: typed memory events, single-pass summaries,
fast context, and lazy context payloads.

### 2026-05-26 [ui] Shiny research-store exploration UI (opt-in companion package)

ledgr's store is a DuckDB file containing snapshots, sweeps, runs, promotion
context, and metrics. A read-only Shiny UI over that store is the obvious
shape for visual exploration when the API surface alone is not enough.

Likely shape:

- A companion package such as `ledgr.ui` rather than a core dependency. Shiny
  pulls in a meaningful dep tree that core should not require for headless
  research, scripted execution, or auditr probes.
- Local-first: `ledgr_ui()` reads a project's `artifacts/ledgr_store.duckdb`
  with no hosted server, no auth surface, no tracking infrastructure.
- Read-only: the UI never writes to the store. Concurrency and locking stay
  the responsibility of the writing scripts.
- Pure inspection scope. No strategy authoring, no run launch, no promotion
  decision recording from the UI in the first pass; those remain script-driven
  and audit-traceable.

Plausible first-version views:

- project view: list snapshots, sweep results, promoted runs;
- snapshot inspector: bars summary, instruments, time range, hash, sealed_at;
- sweep results browser: candidate ranking by metric, sort/filter;
- candidate detail: feature params, strategy params, alias map, metrics;
- run inspector: equity curve, fills table, events stream, warnings,
  telemetry;
- run comparison: side-by-side equity, key metrics, ranking deltas;
- promotion timeline with decision notes (depends on the future promotion
  notes API);
- cross-snapshot view of the same strategy or feature map across data
  windows.

This is correctly deferred. Reasons not to start now:

- v0.1.x speed and workflow work has higher leverage per engineering hour;
- the API surface is still moving (active aliases, alias-map storage, future
  promotion notes, future walk-forward); a UI built against a moving target
  requires constant rework;
- the most valuable screen (promotion decision timeline with rationale)
  cannot exist before the promotion notes API does;
- the gap versus MLflow's web UI is not a real disadvantage for ledgr's
  current target user, who is comfortable with R REPL inspection.

Realistic timing: not before v0.2.x. A short personal-tool prototype during
v0.1.x is fine and may be useful for the author; a release-quality companion
package belongs after the workflow has stabilized and after promotion notes
have an API home.

### 2026-05-26 [ui] Shiny operations dashboard for production deployments

Much further out than the research-store UI. Once ledgr has live trading or
paper trading via OMS adapters, a separate Shiny operations dashboard becomes
useful for monitoring deployed strategies:

- promotion record browser linking each deployed algorithm to its training and
  validation snapshots, strategy hash, alias map, and approval record;
- live position and equity monitoring against the broker or paper account;
- drift indicators comparing live execution to the promoted backtest;
- alert surface for cost, slippage, or risk breaches;
- retraining trigger view linking each new promotion record to the prior one.

This is a v0.2.x or later product. It depends on:

- production promotion record schema landing in its own RFC;
- OMS/paper-trading adapters existing as a public API;
- a live execution layer with deterministic linkage back to the backtest
  identity surfaces;
- a stable view of what "deployed" and "approved" mean in ledgr terms.

Until those pieces exist, the operations dashboard is a sketch, not a design.
Record it here so the eventual UI work has a target shape rather than being
invented under deployment pressure.

### 2026-05-27 [evaluation] Walk-forward post-v0.1.9.x direction

The accepted v0.1.9.x walk-forward synthesis
(`inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`, with
Amendment 1 dated 2026-06-04 in Section 14, Amendment 2 dated 2026-06-04 in
Section 16, Section 17 ticket-cut gates, and the final-review artifact and
closure update at
`inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_final_review.md`) binds
the first walk-forward implementation: rolling and anchored folds,
calendar-time boundaries, single sealed snapshot, classed selection rules,
scalar score matrix, and extraction-for-promotion. Amendment 1 corrected the
Section 3 train-fold scoring binding (now `scoring_start = train_start_utc`,
scoring the full fold window with overlap accepted across folds for rolling)
and bound procedural constraints on Section 11 Open Questions Q1/Q5/Q7/Q10
(opening-state cold-start distortion, rate/annualized selection metrics,
extract_candidate default discipline, train-vs-test degradation as primary
print signal), plus a survivorship disclosure obligation, two additional
tests, and a compute-scaling caveat. Amendment 2 strengthened four of those
routings into substantive defaults and operational contracts: v1 default
`opening_state_policy = carry_test_state` with warned `flat_test_state` opt-in
(Section 16.2); fail-closed selection-rule behavior for level metrics via a
metric-classification registry field (Section 16.3); no-default
`fold_seq` on `ledgr_walk_forward_extract_candidate()` with a required
`selection_rationale` when `"latest"` is used (Section 16.4); an operational
per-fold degradation table data contract for the default print method
(Section 16.5); and a path-dependency obligation for the
`carry_test_state` default (Section 16.6 -- diagnostic RFCs must not assume
per-fold statistical independence). Section 17 added a two-gate ticket-cut
matrix (packet-open and release-gate enforcement) binding the v0.1.9.x
ticket packet's acceptance criteria for every Amendment 1 and Amendment 2
obligation. The closure rule recorded in `rfc_cycle.md` is now: a
post-synthesis amendment that routes only procedural constraints is
insufficient closure; either substantive defaults or ticket-cut gates or
both must land. The synthesis uses "v1" as shorthand
for that first implementation; ledgr's roadmap does not have a "walk-forward
v2" milestone. The post-v0.1.9.x direction lives in named follow-up RFCs at
their own roadmap windows. This entry records the shape of that direction so
the
follow-up work has a target rather than being invented under pressure.

Diagnostic retention and selection-integrity diagnostics:

- the v1 scalar score matrix is sufficient for inspection, scalar-metric PBO
  approximation, and a CRAN `pbo`-compatible pivot; it is explicitly
  insufficient for DSR, CPCV, nonlinear-metric recomputation, or per-candidate
  equity reconstruction;
- richer diagnostic retention tiers (per-candidate per-fold return series,
  equity payload references, sufficient statistics, partition/path identity,
  family/effective-trial metadata) belong in a future diagnostic-retention RFC;
- selection-integrity diagnostic implementation (PBO/CSCV/CPCV/DSR/Holm-BH,
  Harvey-Liu-Zhu thresholds, MinTRL) belongs in a separate diagnostics RFC and
  must consume the score matrix and future retention tiers, not redefine them;
- both RFCs land after the first walk-forward release ships and produces
  operational evidence.

Fold-definition extensions:

- purged and embargoed folds activate the v1 schema's reserved `gap` field;
  the embargo RFC must include explicit label-interval overlap test fixtures
  (mlfinlab's public purge-logic bugs are the right regression set);
- combinatorial purged CV adds path identity (`path_id`) to the score schema,
  multiple chronology-respecting train/test partitions, and pathwise return
  artifacts;
- trading-time, market-state, and regime-aware folds require a market-calendar
  abstraction ledgr does not currently have; regime-aware folds also need
  explicit treatment of the regime-classifier-as-look-ahead hazard;
- cross-snapshot walk-forward (one fold = one snapshot) coordinates with
  snapshot-lineage work and changes the snapshot identity story; v1's
  single-snapshot binding is deliberately the simpler shape.

Composition and policy:

- a selection-rule DSL would admit composite multi-metric selection,
  stability-region selection ("plateau wins, not spike"), and top-N robust
  selection; the v1 `ledgr_select_argmax` / `ledgr_select_argmin` interface
  is the smallest useful surface and the DSL is its natural extension once
  user demand for composite selection surfaces;
- walk-forward nested inside `ledgr_sweep()` as candidate inputs is a v1
  non-goal; future composition must address how walk-forward identity
  participates in sweep candidate identity without exploding artifact counts;
- per-fold universe restriction coordinates with PIT data and survivorship-
  aware universe construction; the v1 "experiment universe applies uniformly"
  default is correct until the PIT data RFC binds the universe-at-time-T
  contract;
- promoting a parameter path (a schedule of candidates per future period) or
  promoting a selection rule (commit a process, not a candidate) are
  promotion-semantics extensions beyond the v1 extract-then-`ledgr_promote()`
  baseline; both need their own design rounds.

Paper/live walk-forward and OMS interaction:

- v1 research walk-forward writes no OMS lifecycle artifacts; paper/live
  walk-forward must revisit OMS streams and target-decision persistence per
  the accepted OMS synthesis;
- each fold's test run as its own `order_events` stream is the natural shape
  but creates artifact multiplication that the paper/live walk-forward RFC
  must address;
- fold definitions translate to a retraining schedule in paper/live (LEAN's
  `train()` pattern); the schedule artifact is a future-RFC concern, not a
  v1 walk-forward shape.

Promoted roadmap hooks (named follow-up RFCs):

- diagnostic retention tiers RFC (v0.1.9.x or later);
- selection-integrity diagnostics RFC (v0.1.9.x, after retention tiers
  stabilize enough to consume);
- purged and embargoed folds RFC (v0.1.9.x or v0.2.x);
- combinatorial purged CV RFC (after purging);
- trading-time / state-fold RFC (v0.2.x, coordinated with market-calendar
  work);
- cross-snapshot walk-forward RFC (v0.2.x, coordinated with snapshot lineage);
- selection-rule DSL RFC (when user demand for composite selection surfaces);
- survivorship-aware universe RFC (v0.2.x, coordinated with PIT data and
  instrument master work);
- paper/live walk-forward RFC (v0.3.0+, coordinated with OMS implementation);
- OMS interaction RFC for walk-forward (between OMS data-model implementation
  and paper/live walk-forward).

This horizon entry does not authorize any of the above. It records the
direction so that when each follow-up cycle opens, the seed author can start
from a known shape rather than re-deriving the boundary.

### 2026-05-27 [execution] Cost-model post-v0.1.9.x direction

The accepted v0.1.9.x/v0.2.0 public transaction-cost API synthesis
(`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`)
binds the first public cost API: classed `ledgr_cost_*` objects, ordered
`ledgr_cost_chain()` composition with two-stage discipline (price transforms
then fee adders), four v1 primitives (`spread_bps`, `fixed_fee`,
`notional_bps_fee`, `zero`), `timing_model` argument replacing `fill_model`,
quoted-spread semantics for `spread_bps`, single account currency, one total
fee per fill, cost identity via `cost_model_hash` + `cost_plan_json`, and
experiment-level (non-per-candidate) cost in v1. The synthesis explicitly
defers ~18 cost-adjacent capabilities and records 10 future-RFC obligations.
This entry groups the post-v0.1.9.x direction so each follow-up cycle starts
from a known shape.

Cost-model expressiveness extensions:

- asymmetric price-adjustment constructor (`ledgr_cost_price_adjust_bps(bps,
  side = ...)`) is reserved as a future constructor for users who need per-leg
  markup/markdown semantics distinct from quoted-spread; both can coexist
  under clearly different names;
- side-filtered fee steps (apply only to BUY, only to SELL, or only to
  specific instrument groups);
- min/max fee caps (per-step semantics; the chain-level interaction was the
  reason v1 deferred them);
- per-share and per-contract fee primitives (currently aliasable from
  `notional_bps_fee` via user calculation but lack the asset-class vocabulary
  users expect).

Stateful fee modeling:

- rolling-volume fee tiers (IBKR-style monthly-share-volume tiers, Binance-
  style rolling-30-day tiers, CME participant-status tiers) — require a
  cost-state envelope that v1's stateless per-fill contract deliberately
  excludes;
- maker/taker fee inference from order aggressiveness — requires either an
  explicit user convention (which v1 cost API rejects) or a liquidity layer
  that can classify fills as passive vs aggressive;
- rebates (negative fees) — admitted only via explicit rebate or maker/taker
  classes, not as arbitrary negative outputs from any fee step.

Multi-asset and multi-venue cost assignment:

- per-instrument cost-model assignment (LEAN-style per-security models);
- per-asset-class cost templates (equity / futures / crypto / FX / options
  defaults with fallback rules);
- per-venue cost objects (NautilusTrader-style venue-level fee models for
  multi-venue portfolios);
- assignment-rule ordering (fallback from per-instrument → per-asset-class →
  experiment-default).

Cost sweep and parameterization:

- `ledgr_cost_grid()` or `ledgr_grid_cross(..., cost = ...)` for sweeping cost
  assumptions across candidates;
- `ledgr_cost_param("spread_bps")` parameter references inside cost objects
  for cost-varying sweep candidates;
- both require explicit namespace and identity rules to keep cost-varying
  candidates distinguishable from strategy-param-varying candidates in
  provenance, reporting, and promotion context.

Cost-adjacent families that are not cost:

- borrow cost, margin interest, carry, and perpetual funding — stateful
  position or calendar cashflows; belong in a separate financing/margin RFC
  family, not in the cost API;
- multi-currency fee accounting and conversion — once fees can be denominated
  in something other than the account currency, conversion, missing FX data,
  and multi-currency ledger semantics enter scope; a separate RFC;
- tax-lot and capital-gains policy — stateful accounting-policy problem, not
  a fill-time cost transform; transaction taxes (stamp duty, FTT) can be
  modeled as fee adders in v1, but realized-tax accounting waits;
- broker-certified fee schedules in core — adapter packages own these;
  core ships primitives and educational approximations only.

Cost in OMS and paper/live:

- broker-reported fee ingestion for paper/live reconciliation — requires the
  OMS event-stream layer to exist first;
- live cost calibration against actual broker-reported fees — v0.3.0+ work;
- broker-fee schedules versioned per account/date — coordinates with
  snapshot lineage and live-data-log work.

TCA and reporting:

- implementation-shortfall computation;
- delay cost and opportunity cost;
- benchmark-relative shortfall (VWAP/TWAP comparison);
- venue analysis and pre/intra/post-trade workflow reporting;
- all belong to a future TCA/reporting layer that consumes cost-resolved fill
  rows plus future order-lifecycle artifacts; the cost API need not become a
  full benchmark engine.

Cost component diagnostic retention:

- v1 sums chain-fee components into one total `fee` per fill in
  `ledger_events`; component breakdowns may live in `meta_json` when retained;
- a future diagnostic retention tier may add a `cost_details` table with
  per-step attribution rows for inspection and TCA-style analysis;
- the same pattern as the walk-forward "diagnostic retention tier" deferral.

Promoted roadmap hooks (named follow-up RFCs):

- asymmetric price-adjustment constructor RFC (when concrete demand
  surfaces);
- stateful fee tiers RFC (after operational experience with v1);
- maker/taker and rebates RFC (coordinated with liquidity layer);
- per-instrument / per-asset / per-venue assignment RFC (v0.2.x, when
  multi-asset portfolios become common);
- cost sweep / parameterization RFC (after sweep + walk-forward
  artifact-multiplication patterns stabilize);
- financing and margin-interest RFC (v0.2.x, separate from cost);
- multi-currency fee accounting RFC (coordinated with multi-currency ledger
  work);
- TCA / reporting layer RFC (v0.2.x or later, consumes cost + future OMS
  data);
- broker-reported fee reconciliation RFC (v0.3.0+, with OMS implementation);
- cost component diagnostic retention RFC (coordinated with walk-forward
  diagnostic tiers).

Immediate cross-cycle obligations recorded by the synthesis (not horizon
material, just noted for follow-on cycles):

- v0.1.9.x walk-forward spec packet must extend `candidate_key` and
  `session_id` to include `cost_model_hash`;
- v0.1.9.x cost-API spec packet must update
  `vignettes/metrics-and-accounting.Rmd` which currently teaches the legacy
  full-per-leg spread convention.

This horizon entry does not authorize any of the above. It records the
direction so that when each follow-up cycle opens, the seed author starts
from a known shape rather than re-deriving the boundary.

### 2026-05-27 [evaluation] Baseline strategies and opinionated comparison

The roadmap (`inst/design/ledgr_roadmap.md`) lists "Reference strategy
templates as executable contract demonstrations" at v0.2.x. This horizon entry
refines that line into a concrete design direction so the eventual RFC author
starts from a known shape.

Two things already exist in v0.1.8.4: `ledgr_demo_sma_crossover_strategy()` as
a single teaching fixture, and `ledgr_compare_runs(snapshot, run_ids = ...)`
as a multi-run comparison surface that returns side-by-side metrics. What is
missing is the opinionated layer that connects them: a small library of
baseline strategies the user can run against the same sealed snapshot, plus a
comparison wrapper that produces a structured "does this beat the baseline"
report instead of two unannotated equity curves.

Three categories that must stay distinct in the design

The v0.2.x RFC must keep these three surfaces separately named. Conflating
them is the most likely failure mode:

- **Baseline strategy.** Runs *inside the engine on the same snapshot* as the
  user's strategy. Same data path, same fill semantics, same accounting.
  Produces an in-sample comparison. This horizon entry is about this
  category.
- **Benchmark return series.** An *external* time series (e.g., SPY total
  return, 60/40 model portfolio NAV) compared post-hoc to the strategy's
  equity curve. Different data path. This is what `PerformanceAnalytics`
  users expect and is a separate future RFC.
- **Reference / teaching strategy.** Same mechanical shape as a baseline,
  but the intent is education, not measurement.
  `ledgr_demo_sma_crossover_strategy()` is one of these. Useful for
  vignettes; not a measurement surface.

Sketch of the v2.x API (not bound)

```r
# Baseline constructors -- same engine, same snapshot, in-sample
ledgr_baseline_flat()                          # always flat (zero positions)
ledgr_baseline_buy_and_hold()                  # equal-weight long at t=0, hold
ledgr_baseline_equal_weight_monthly()          # rebalance to equal weights monthly
ledgr_baseline_random_walk(seed)               # random target per pulse -- sanity check

# Comparison wrapper -- opinionated about which stats matter
ledgr_compare_against_baseline(
  bt,                                          # your committed run
  baseline = ledgr_baseline_buy_and_hold()     # the baseline strategy to run
)
```

The wrapper runs the baseline on the same snapshot with the same opening
state and reports a fixed structured comparison.

The opinionated metric set

The wrapper reports a small fixed set of statistics, chosen because they
answer "does this add value over the baseline" rather than "what are this
strategy's performance attributes":

- difference in total return;
- Sharpe difference;
- max drawdown difference;
- tracking error (stdev of return difference);
- information ratio (return difference / tracking error);
- percent of pulses where the strategy outperformed.

The bounded metric set is itself a design decision. ledgr should refuse to be
a generic stats library here; the comparison surface should teach the
specific question "does my strategy add value relative to a known baseline,"
not enumerate every possible benchmark-adjusted metric.

Scope risks

- **Template library creep.** Ship "buy and hold," users will ask for
  "rebalanced 60/40," "equal-weight momentum," "minimum-variance," etc. Cap
  the core library at ~4-6 templates that genuinely teach the comparison
  discipline. Anything fancier belongs in a companion package or user code.
- **Baseline vs benchmark conflation.** Users will read "baseline" as
  "benchmark" and expect SPY-relative attribution. The API name and the
  documentation must make the distinction obvious — `ledgr_baseline_*`
  constructors run a real strategy inside the engine; a future
  `ledgr_benchmark_*` family (if added) would consume external return
  series.
- **Opinionated metrics still bind a research-method choice.** Picking five
  comparison stats teaches the user to optimize against those five stats.
  The metric selection should be informed by the same Bailey / Lopez de
  Prado / Harvey-Liu-Zhu literature that informed the walk-forward and
  selection-integrity work.
- **In-sample comparison is still in-sample.** If the user's strategy was
  selected from a sweep on the same snapshot the baseline runs against,
  "beats baseline by 3 bps" is in-sample evidence. The walk-forward
  synthesis already warns that single-snapshot evidence is exploratory; the
  baseline comparison surface inherits that caveat and must say so in
  user-facing docs.

Dependencies on prior cycles

This RFC lands well after the prerequisite work:

- walk-forward (v0.1.9.x) so comparisons can be made over OOS fold windows,
  not just full snapshots;
- target risk (v0.1.9) so baselines can be risk-adjusted comparable to
  risk-aware strategies;
- public cost API (v0.1.9.x/v0.2.0) so cost-aware comparisons are honest
  (baselines have different turnover; comparing without cost can mislead);
- selection-integrity diagnostics (v0.1.9.x) so the comparison can be paired
  with multiplicity-aware significance reporting if the user wants it.

The v0.2.x slot is the right window — after the prerequisites stabilize and
before paper/live shifts the question from "does this beat the baseline" to
"is this still working in production."

Promoted roadmap hooks

- baseline strategy library RFC (v0.2.x, after walk-forward and cost API
  stabilize);
- baseline-comparison API RFC (v0.2.x, coordinated with baseline library);
- benchmark-return-series adapter RFC (later, if external-time-series
  comparison surfaces user demand — distinct from baseline strategies);
- companion-package reference strategy library (out of core, when the
  in-core library hits maintenance-burden limit);
- statistical-significance layer for baseline comparisons (coordinated with
  selection-integrity diagnostics RFC).

Cross-cycle note

The v0.1.8.5 canonical workflow article (Batch 1, just shipped) intentionally
does not teach baseline comparison. A reader of that article is likely to
ask "but how do I know if my strategy is any good?" — and the honest answer
today is "you run a baseline yourself and compare manually." The v0.2.x
baseline-comparison API is what that answer should point to once it lands.

Until then, the strategy-development vignette's existing note that the demo
SMA crossover and the `single_instrument_strategy()` helper can be used as
ad-hoc comparison baselines is the user-facing guidance.

This horizon entry does not authorize any of the above. It records the
direction so that when each follow-up cycle opens, the seed author starts
from a known shape rather than re-deriving the boundary.

### 2026-05-27 [infrastructure] Snapshot administration surface and ETL provenance metadata

ledgr today stores a small set of snapshot fields plus a free-form
`meta_json` envelope on the `snapshots` DuckDB table
(`R/db-schema-create.R:233-242`). The engine writes `n_bars`,
`n_instruments`, `start_date`, and `end_date` into `meta_json` at seal time
(`R/snapshots-seal.R:199-253`), but the user-facing constructor
`ledgr_snapshot_from_df()` does not even expose the `meta = list(...)`
argument that `ledgr_snapshot_create()` accepts. There is no documented
place for ETL provenance, no notes field, no labels or tags, and no
listing or filtering surface beyond `ledgr_snapshot_info()` on a known ID.

This gap surfaced in v0.1.8.5: the canonical research-workflow article
teaches users to seal data into a project store but cannot teach the
companion discipline of recording *how* the data was prepared. A user can
reopen the exact sealed bytes, but cannot reopen the human reasoning that
produced them.

Three categories that must stay distinct in the design

The eventual RFC must keep these three surfaces separately named so the
schema and API do not collapse into a single freeform blob:

- **Engine-computed metadata.** Derived deterministically at seal time
  from the sealed contents: `n_bars`, `n_instruments`, `start_date`,
  `end_date`, `snapshot_hash`, instrument list, calendar. Reproducible
  from the snapshot and not user-editable.
- **User-supplied descriptive metadata.** Free-text notes, ETL provenance
  (source URL or vendor, retrieval timestamp, ETL script path and
  version, transformations applied), tags or labels, author. Human-
  authored documentation that ledgr stores faithfully but does not
  interpret.
- **Lifecycle and administrative state.** Existing `status`
  (`CREATED`/`SEALED`/`FAILED`) plus potential additions like
  `deprecated_at`, `superseded_by`, `archived_at`. State transitions
  managed through dedicated API rather than freeform edits.

Conflating any two is the most likely failure mode. ETL provenance is
not lifecycle state; engine-computed fields are not user metadata.

Sketch of the API (not bound)

```r
# Constructor surface -- both expose the same metadata fields
ledgr_snapshot_from_df(
  bars,
  db_path     = ...,
  snapshot_id = ...,
  notes       = NULL,    # free-text human notes
  source      = NULL,    # list: vendor, url, retrieved_at, etl_script, etl_version
  tags        = NULL,    # character vector of labels
  author      = NULL     # character scalar
)

ledgr_snapshot_create(con, snapshot_id, notes = NULL, source = NULL, ...)

# Inspection and listing
ledgr_snapshot_info(con, snapshot_id)          # returns all three categories
ledgr_snapshot_list(                           # navigates the store
  con,
  tags          = NULL,                        # filter by label
  author        = NULL,                        # filter by author
  status        = NULL,                        # filter by lifecycle state
  created_after = NULL
)

# Lifecycle administration
ledgr_snapshot_deprecate(con, snapshot_id, reason)
ledgr_snapshot_supersede(con, snapshot_id, by = new_snapshot_id, reason)

# Note administration (audit-logged, not silent overwrite)
ledgr_snapshot_note(con, snapshot_id, append = "...")
```

Schema direction

The cleanest shape is a dedicated set of `snapshot_meta` columns on the
`snapshots` table (or a sibling `snapshot_provenance` table for the
structured ETL fields), with engine-computed values remaining in
`meta_json` until the spike confirms which fields are stable enough to
promote to typed columns. A `snapshot_audit` append-only table can record
administrative edits to notes, tags, or lifecycle state.

Scope risks

- **Metadata creep.** Once the API exposes notes, users will ask for
  arbitrary key/value extension. Cap structured fields at a small
  defensible set and route everything else into one explicit
  `extra = list(...)` slot stored as JSON, not into ad-hoc top-level
  columns.
- **Lifecycle confusion.** "Deprecated" and "superseded" sound similar
  but mean different things; the RFC must define semantics precisely
  before exposing them. Avoid soft-delete unless audit and recovery
  semantics are clear.
- **Mutable metadata vs immutable provenance.** Notes are mutable by
  design (users learn things later). The `snapshot_hash` must not depend
  on mutable metadata, or the audit trail breaks. ETL provenance
  recorded at create-time should be append-only after seal, with later
  edits routed through a dedicated audit-logged path.
- **Listing API as a sweep substitute.** `ledgr_snapshot_list()` is a
  research-management tool, not a query engine. Resist filters that pull
  bar data ("snapshots containing instrument X") into the list surface;
  those belong in `ledgr_snapshot_info()` or a separate query API.
- **Migration burden.** A schema change to the `snapshots` table is a
  breaking change to existing project stores. The pre-CRAN window
  authorizes it, but the cycle must ship a migration script or an
  explicit "rerun your experiments" gate.
- **Intraday-readiness regression.** Schema additions must stay
  cadence-neutral. The snapshots table is timestamp-resolution-agnostic
  today: a user can seal 1-minute or 1-hour bars. Do not introduce
  columns, types, or `meta_json` conventions that imply one row per
  instrument per day, one snapshot per market session, or EOD-only
  frequency. The intraday support arc (2026-05-27 horizon entry) names
  this as a pre-v0.2.x footgun; the RFC author should confirm the
  proposed schema preserves the existing cadence-neutral posture.

Dependencies on prior cycles

- v0.1.8.5 canonical workflow article (Batch 3 / LDG-2437) surfaced the
  user-facing need and started teaching the convention on the existing
  `meta` argument as a documentation-only patch — shipped;
- pre-CRAN compatibility policy (2026-05-25 horizon) authorizes the
  breaking schema change without a deprecation cycle;
- the v0.1.8.6 DuckDB feature-storage spike shipped independently; its
  outcome does not gate the snapshot administration schema.

Status: the v0.1.8.6 cycle deferred the snapshot administration planning
(LDG-2451) per the 2026-05-29 "Snapshot administration and research-loop
helpers deferred" entry. The work is now a v0.2.0-class RFC/spec cycle
candidate, not a near-term v0.1.x slot. This entry stays the binding
seed-shape input for whenever that cycle opens.

Promoted roadmap hooks

- snapshot administration and ETL provenance metadata RFC: v0.2.0-class
  cycle when revived; this entry is its seed-shape input.
- `ledgr_snapshot_list()` filtering and listing API (coordinated with
  the metadata schema RFC).
- `ledgr_snapshot_deprecate()` and `ledgr_snapshot_supersede()`
  lifecycle API (coordinated with the metadata schema RFC; final scope
  decided in RFC synthesis).
- audit-log table for administrative edits (coordinated with the
  metadata schema RFC; final scope decided in RFC synthesis).

Cross-cycle note

Until the RFC lands and ships, the v0.1.8.5 workflow article's teaching
path remains "your store path is explicit, but the discipline of
recording ETL provenance belongs in your project README or
workflow_review.md report next to the store." That documentation-only
guidance was landed inside the v0.1.8.5 Batch 3 (LDG-2437) scope.

This horizon entry is the seed-shape input for the snapshot
administration RFC. It does not replace the RFC cycle, and the RFC
synthesis (not this entry) is what authorizes any future spec scope.

This horizon entry does not authorize any of the above. It records the
direction so that when the snapshot administration RFC cycle opens, the
seed author starts from a known shape rather than re-deriving the
boundary.

### 2026-05-27 [ux] Research-loop ergonomics helpers surfaced by the v0.1.8.5 workflow vignette

The v0.1.8.5 canonical research workflow article
(`vignettes/research-workflow.qmd`) explicitly flags two API gaps in
user-visible callouts. They surfaced during teaching, not speculation:
the article had to fall back to lower-level patterns to keep the
research-loop story honest, and the callouts mark exactly where the
helpers should land.

Both gaps share a shape: ledgr already records the underlying data.
The gap is in the summary surface that exposes the data compactly
without flattening the visible selection rule or provenance reasoning.

This entry supersedes the earlier 2026-05-25 "Sweep candidate ranking views"
stub (the `ledgr_rank_candidates()` sketch). The sweep-review helper below is
the same idea, taken further and tied to the vignette gap that motivates it.

#### Gap 1: Sweep review helper (promoted to v0.1.9.5)

Disposition update (2026-06-13): this helper is promoted into the v0.1.9.5
packet as LDG-2642. Sweep this subsection to `## Resolved` at v0.1.9.5
closeout, or leave only any residual follow-up discovered during implementation.

Vignette location: the "Inspect Before You Promote" section and its
"Design note" callout.

The article currently teaches:

```r
ranked <- sweep |>
  filter(status == "DONE") |>
  arrange(desc(sharpe_ratio))

candidate_columns <- c(
  "run_id", "status", "final_equity", "total_return",
  "sharpe_ratio", "params", "feature_params"
)
top_n <- ranked |> slice_head(n = 5) |> select(all_of(candidate_columns))

issue_columns <- c("run_id", "status", "error_class", "error_msg", "warnings")
issues <- sweep |> filter(status != "DONE") |> select(any_of(issue_columns))

candidate <- ledgr_candidate(ranked, 1)
```

What is missing: a helper that ranks completed candidates by an
explicit rule, returns a compact review table, separates issue rows
into their own table, and preserves the visible selection rule.

Critical design constraint: the helper must not hide the ranking
rule. The vignette's whole teaching arc is that the metric must be a
deliberate user choice, not a default the helper picks silently. A
shape such as
`ledgr_sweep_review(sweep, rank_by = desc(sharpe_ratio), n = 5)` keeps
the rule in the call site.

#### Gap 2: Promotion recovery summary

Vignette location: the "Reopen The Artifact" section and its
"API gap" callout-warning.

The article currently teaches users to inspect:

- `info$promotion_context$source`
- `info$promotion_context$selected_candidate$run_id`
- `info$promotion_context$selected_candidate$params_json`
- `info$promotion_context$selected_candidate$feature_params_json`

plus a separate `ledgr_extract_strategy()` call returning
`strategy_params`, `reproducibility_level`, and `hash_verified`.

What is missing: a single helper that summarizes a promoted run's
"what caused this result?" record in one compact object: promotion
source, selected candidate identity, strategy and feature parameters,
strategy source provenance, and hash-verification status, without
requiring nested-field navigation across multiple objects. A shape
such as `ledgr_promotion_summary(snapshot, run_id, trust = FALSE)`
returning a named list or compact tibble would fit.

#### Shared design constraints

- Helpers preserve the styleguide rule that selection or ranking rules
  stay visible to the reader. A "show me the best candidate" helper
  that picks Sharpe silently is exactly what the workflow article
  warns against.
- Helpers do not replace `ledgr_results()`, `ledgr_run_info()`,
  `ledgr_extract_strategy()`, or `ledgr_candidate()`. They are
  summary surfaces over those lower-level APIs, not parallel ones.
- Output is inspectable as a plain data frame or named list, never an
  opaque print-only object.
- The recovery summary distinguishes stored facts (parameters, hashes,
  note) from interpretation (reproducibility tier, hash-verification
  status, recovery limitations). Tier 1 and Tier 2 strategies must
  not collapse into a single "verified" status.

#### Scope risks

- **Selection-rule erasure.** Easiest failure mode for the sweep-review
  helper is shipping a sensible default ranking metric. The helper
  should require an explicit rank-by argument or return the chosen
  rule alongside the rows.
- **Provenance summary as truth.** Easiest failure mode for the
  recovery helper is collapsing tier-1 and tier-2 strategies into one
  "verified" status. Tier 2 strategies have real recovery limitations
  and the summary must surface them honestly.
- **Over-abstraction.** The current low-level paths are verbose but
  not user-hostile. The helpers should compress the common case
  without removing the lower-level paths from the public API.

#### Dependencies on prior cycles

- v0.1.8.4 active aliases and grid helpers shipped (precondition:
  `sweep` carries `feature_params` and `params` columns and `status`
  is canonical);
- v0.1.8.5 canonical workflow article (Batch 1 / LDG-2435) is the
  surface that demonstrates the gap and constrains the helper shape;
- v0.1.8.5 sweeps documentation (Batch 4 / LDG-2438) should teach
  the helpers if they ship in the same cycle, otherwise it should not
  pre-document them.

#### Promoted roadmap hooks

- sweep-review helper: promoted into v0.1.9.5 as LDG-2642. Sweep this bullet to
  `## Resolved` at closeout if the helper lands.
- promotion-recovery-summary helper: remains deferred with the snapshot
  administration / research-loop helpers path.
- when the helpers ship, revise the vignette's "Design note" and
  "API gap" callouts to reference the new functions, or remove them
  if the helper makes the lower-level path unnecessary in the
  teaching arc.

#### Cross-cycle note

The vignette's "Design note" and "API gap" callouts are the user-
visible markers for these gaps. When the helpers land, the callouts
should be revised to reference the new functions, or removed if the
helper makes the lower-level path unnecessary in the teaching arc.
Leaving stale callouts in the article is a worse failure than the
gap itself.

This horizon entry does not authorize any of the above. It records
the direction so that when a research-loop ergonomics cycle opens,
the author starts from a known shape rather than re-deriving the
boundary.

### 2026-05-27 [execution] Intraday support arc and pre-v0.2.x architectural footguns

ledgr's roadmap permanently excludes high-frequency, sub-millisecond, and
tick-by-tick execution. It does not exclude minute-to-hour bar resolution.
User feedback during the v0.1.8.5 cycle indicates intraday is real future
demand: many users who would use ledgr for EOD research also want to use it
for intraday research, and "the same backtester for both" is a defensible
USP. This entry captures the multi-cycle arc to support intraday as a
first-class workflow, plus the architectural footguns the in-progress
v0.1.x cycles must avoid so the eventual flip is not a rewrite.

This entry supersedes the earlier 2026-05-13 "Intraday architecture
feasibility" stub. The parallelism-spike evidence it cited remains at
`inst/design/spikes/ledgr_parallelism_spike/summary_report.md` and
`.../architecture_synthesis.md`; that spike used intraday-like payloads only to
stress data movement and did not test intraday snapshot schema, pulse
calendars, sub-day fill timing, or metrics at intraday scale.

The user will initiate a design audit before committing to the intraday
arc. This entry is the audit's input shape.

#### Today's posture: EOD-first, intraday-tolerant

The snapshot schema is timestamp-resolution-agnostic. A user can seal
1-minute or 1-hour bars today, declare a feature map, and run a strategy
against them. The fold core, pulse model, ledger events, and accounting
mechanics are calendar-agnostic at the storage layer.

Every layer above storage assumes EOD shape, however:

- **Session calendars do not exist.** Warmup, annualization, and metric
  context all assume one bar equals one day. A 50-period SMA on 1-minute
  bars is 50 minutes, but annualization treats it as 50 days.
- **Fill timing is EOD-shaped.** The v0.1.8 internal cost boundary
  (`validated_targets -> next_open_timing -> fill_proposal -> cost ->
  fill_intent`) is swappable by design but ships with only `next_open`
  semantics. Intraday wants next-pulse-touch, mid-point, VWAP, or
  session-close policies that do not exist.
- **No OMS.** Strategies return target vectors. Intraday usually wants
  order lifecycle (place / modify / cancel, partial fills). That work is
  v0.2.x with an accepted synthesis at
  `inst/design/rfc/rfc_ledgr_oms_seed_synthesis.md`.
- **Cost / liquidity policy is not intraday-aware.** The v0.1.9.x/v0.2.0
  cost API works for intraday in principle, but participation, capacity,
  and minimum-ADV policy (also v0.2.x) is what intraday actually needs.
- **Storage scale changes.** The v0.1.8.6 feature-storage spike measures
  EOD workloads. Intraday changes the answer.

Users who run intraday today get coherent reproducibility on the data and
strategy axes and broken semantics on the metric and fill-timing axes. The
honest framing for v0.1.8.5 docs is "intraday bars seal fine but metric
annualization assumes EOD; treat results as exploratory until v0.2.x."

#### The required arc

First-class intraday is a multi-cycle endeavor:

1. **OMS semantics** (v0.2.x, accepted synthesis) — load-bearing for
   order lifecycle, partial fills, and the two-stream `order_events` /
   `ledger_events` separation.
2. **Session calendar infrastructure** (new RFC, post-OMS) — exchange
   sessions, holidays, half-days, lunch breaks, pre/post-market handling.
3. **Intraday fill-timing policy** (extends v0.1.9.x cost API arc) —
   next-pulse-touch, mid-point, VWAP, session-open / session-close, with
   the same swappable boundary the EOD `next_open_timing` already uses.
4. **Intraday-aware metric context** (extends v0.1.8.2 metric context
   work) — annualization factor parameterized by cadence and sessions,
   not hardcoded.
5. **Liquidity / capacity policy** (already v0.2.x roadmap) — execution
   feasibility separate from cost, with participation limits that mean
   something different intraday vs EOD.
6. **Storage scale evidence** (extends v0.1.8.6 spike) — the spike's
   exit-decision changes once intraday workloads enter the comparison.

The arc spans v0.2.x through v0.3.0 in the existing roadmap. The OMS
synthesis is the entry point. Calendar infrastructure is the missing RFC.

#### Architectural footguns the v0.1.x cycles must avoid

This is the operative section. The completed v0.1.8.10 cycle, the active
v0.1.8.11 documentation/cleanup cycle, and the planned v0.1.9/v0.1.9.x cycles
must not paint the framework into corners that the intraday flip will have to
rip out. The list below is the audit checklist.

- **Pulse cadence is a snapshot-derived property, not a global constant.**
  Any code path that hardcodes "trading day" semantics in the fold core,
  metric annualization, or warmup teaching is a footgun. Cadence must be
  read from the snapshot.
- **Warmup is bar-count, never time-implied.** `passed_warmup()` and the
  active-alias warmup pipeline are bar-count today. Correct for both EOD
  and intraday. Preserve. The trap lives in metrics, not warmup itself.
- **Metric context must expose a cadence/annualization slot.** The v0.1.8.2
  metric-context templates (US equity, crypto) reserved this surface.
  Audit them to confirm `annualization_factor` is a parameter, not a
  constant. Intraday metric context shares the calendar; the cadence
  changes.
- **Fill timing stays a swappable internal boundary.** The v0.1.8 cost
  boundary already reserved this. Preserve. No v0.1.x ergonomics work
  should bake `next_open` into a code path that should be policy-pluggable.
- **Strategy contract preserves intraday signatures.** Strategies return
  full named numeric target vectors. That signature works for both EOD
  and intraday. Do not add EOD-flavored methods to the canonical strategy
  context (`ctx$today()`, `ctx$is_market_open()`) in v0.1.x — those
  belong on a future intraday-aware context, not on the existing one.
- **Risk-layer affordability check must be net across one pulse's
  proposed fills, not per-instrument sequential.** The fold core's fill
  loop iterates per instrument and updates cash sequentially
  (`R/fold-core.R:233-287`). When the v0.1.9 target-risk layer adds
  affordability adapters, they must check feasibility against the net
  cash delta from all proposed fills at one pulse, not per-instrument:
  a per-instrument check would reject rebalancing strategies depending
  on instrument iteration order (BUYs checking cash before paired SELLs
  free it up), even though both fill at the same `t+1` open in reality.
  Intraday rebalancing makes this acute because rebalances fire more
  often; an equity-EOD test won't surface it. This also threads into
  the v0.2.x OMS two-stream design — `order_events` recorded as a
  batch atomic at the fill bar makes "shared cash pool at one fill
  timestamp" structural rather than implicit.
- **Storage schema stays timestamp-resolution-agnostic.** Today it is.
  The snapshot-administration RFC (v0.1.8.6) must explicitly preserve
  this and must not introduce fields that imply one row per instrument
  per day.
- **Sweep result and run identity stay frequency-agnostic.** `run_id`,
  `snapshot_hash`, `config_hash`, and sweep candidate identity must not
  encode "EOD" anywhere. They do not today — preserve.
- **OMS-shaped target-decision storage from the start.** The accepted
  OMS synthesis explicitly warns that intraday-compatible target storage
  needs retention-dependent, batchable, potentially sparse / columnar /
  payload-reference shapes. v0.1.x EOD work can implement the simple
  per-decision shape but must not commit to a schema the OMS work will
  have to rip out destructively.
- **Cost API spread / participation assumptions stay EOD-neutral.** The
  accepted v0.1.9.x cost API synthesis keeps `cost_spread_bps()` as a
  quoted-spread function over a fill context. Intraday extends the
  context, not the cost API. Preserve that boundary.
- **Demo data and demo strategies stay EOD-shaped.** That is fine. The
  footgun is letting demo-data assumptions leak into runtime invariants.
  Already correct today — preserve.
- **Walk-forward window semantics generalize from EOD-day folds to
  intraday-session folds.** The accepted walk-forward synthesis represents
  scoring windows explicitly. Audit to confirm the window model does not
  hardcode day semantics.
- **Dense-panel fail-fast is a backtest seal-time gate, not a universal
  invariant.** `ledgr_missing_bars` aborts the run if any instrument lacks a
  bar at any pulse (verified: cross-join completeness check
  `backtest-runner.R:1541-1564`; per-instrument alignment
  `backtest-runner.R:1154-1159`). That is correct for sealed backtest data and
  wrong for live streaming, where missing/garbled ticks are routine. The
  v0.2.x data-model and live-data work must not treat the dense panel as
  permanent — see the 2026-05-28 live bad-data resilience entry.

#### Migration efficiency requirements

A clean migration to first-class intraday means:

- existing EOD users' runs remain reopenable after the intraday flip
  lands;
- the public strategy contract `function(ctx, params) -> target vector`
  survives intact; the context object gains intraday-aware methods but
  loses none;
- cost API stays additive — new timing/cost policies are opt-in
  constructors, not breaking changes;
- run identity hashes stay stable for unchanged EOD inputs after the
  intraday code lands;
- the snapshot administration schema accommodates intraday bars without
  schema migration on EOD stores.

The pre-CRAN compatibility policy authorizes breaking changes within
v0.1.x to clean up footguns before they become permanent. Use that
window deliberately. After CRAN, the migration becomes much more
expensive.

#### Design audit scope

The user will initiate a design audit. The audit's input is this entry
plus the affected code paths. Suggested audit scope:

- every code path that assumes "day" semantics: metric annualization,
  calendar inference, warmup teaching prose, demo data shape;
- every API boundary that could plausibly be cadence-aware but isn't:
  `metric_context`, fill timing, `ledgr_run_info()` cadence reporting,
  sweep candidate metadata;
- every place where session boundaries (open/close, lunch breaks,
  holidays, half-days) would matter once intraday lands: pulse calendar
  construction, opening/closing fill behavior, warmup hydration across
  sessions;
- the OMS synthesis target-decision-storage section, to confirm v0.1.x
  EOD storage decisions do not preclude the intraday-compatible shape;
- the cost API synthesis fill-context section, to confirm the context
  shape supports intraday extensions without API rewrite;
- the walk-forward synthesis window model, to confirm window semantics
  generalize from EOD folds to intraday session folds;
- the snapshot-administration RFC seed-shape (this horizon), to confirm
  the metadata model is cadence-neutral;
- demo data, vignette code, and contract tests for any place that
  conflates "one bar = one day" with "one pulse = one decision".

Audit output: a list of footguns that exist today, a list of footguns
the in-progress cycles must not introduce, and a list of decisions that
are already correct and worth pinning with contract tests so they do
not regress.

#### RFCs to revisit after the audit

The audit will read existing synthesis documents to check whether their
accepted designs survive an intraday flip. The list below is grouped by
how directly each RFC touches cadence, fill timing, target lifecycle,
or storage shape. A "revisit" outcome can be one of three: confirm the
design is already cadence-neutral and pin it; identify a specific clause
that needs to be amended before the corresponding implementation cycle
opens; or open a follow-up RFC to extend the existing synthesis.

**Tier A — load-bearing for intraday, must revisit:**

- `rfc/rfc_ledgr_oms_seed_synthesis.md` — the target-decision-storage
  section already mentions intraday-compatible storage shape (retention-
  dependent, batchable, potentially sparse/columnar/payload-reference).
  Confirm that any v0.1.x EOD per-decision storage work does not preclude
  the future shape destructively.
- `rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md` —
  confirm the `fill_context` shape supports intraday extension (next-
  pulse-touch, mid-point, VWAP, session-close timing) without breaking
  the public cost-model factory API.
- `rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md` —
  confirm `metric_context` exposes `annualization_factor` (or
  equivalent) as a parameter, not a hardcoded 252 anywhere downstream.
  Audit the US-equity and crypto templates for hidden EOD constants.
- `rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md` — confirm the
  training/test-window model represents windows in calendar terms that
  generalize to intraday session folds, not just EOD-day folds. The
  synthesis says windows are explicit; verify "explicit" includes the
  cadence axis.
- `rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md` — confirm
  the risk-step interface is cadence-neutral. Risk decisions intraday
  fire much more often; the boundary must not embed EOD-pulse-rate
  assumptions in the step semantics.

**Tier B — architectural foundations intraday inherits, recommend revisit:**

- `rfc/rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md` —
  confirm sealed-snapshot lineage and one-store topology decisions stay
  cadence-neutral. Intraday lineage (e.g., yesterday's session bars
  rolled forward into today's snapshot) is a v0.2.x roll-forward concern;
  the v0.1.8.5 topology should not preclude it.
- `rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md` —
  confirm the runtime projection interface and R-memory backend make no
  "one row per instrument per day" assumption. Intraday volume changes
  the memory profile; the projection contract should already handle this
  but worth pinning.
- `rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md` —
  confirm the consolidated pulse-context model does not embed EOD-flavored
  methods or shape assumptions. The strategy contract is the long-term
  intraday boundary.
- `rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis.md` and
  `rfc/rfc_sweep_promotion_context_v0_1_8_synthesis.md` — confirm
  candidate and promotion-context identity (seeds, hashes, params) is
  frequency-agnostic. Already believed to be true; pin with contract
  tests if so.

**Tier C — feature and storage shape, scan for footguns:**

- `rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md` —
  confirm feature-parameter semantics do not imply EOD frequency.
  `ledgr_param("fast_n")` is a count, not a calendar duration; preserve.
- `rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md` —
  scan for memory and volume assumptions tied to EOD bar counts. Wide
  runtime views at intraday scale are a v0.1.8.6 spike concern.
- `rfc/rfc_multi_output_indicator_ux_synthesis.md` — confirm bundle
  output shape is frequency-neutral.
- `rfc/rfc_indicator_codebase_simplification_v0_1_8_x_synthesis.md` —
  confirm indicator surface (series_fn contract, adapters) treats bar
  cadence as snapshot-derived, not global.

**Tier D — performance and measurement:**

- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md` —
  worker assumptions and serialization costs change at intraday volume;
  re-evaluate if intraday lands.
- `rfc/rfc_collapse_primitive_internals_v0_1_9_synthesis.md` — the
  primitive-internals decisions assume EOD-scale workloads. Intraday
  changes the cost/benefit math; the synthesis already conditions
  implementation on measurement, so this is mostly "rerun the
  measurement at intraday scale before promoting Phase B/C.1."

**Horizon entries (seed-shape inputs) that should also be re-read:**

- the snapshot administration entry (2026-05-27, this file) — already
  amended with an intraday-readiness scope risk;
- the research-loop ergonomics helpers entry (2026-05-27, this file) —
  helper output shape must be cadence-neutral;
- the walk-forward post-v0.1.9.x direction entry (2026-05-27, this file)
  — confirm follow-up directions extend cleanly to intraday folds;
- the cost-model post-v0.1.9.x direction entry (2026-05-27, this file)
  — confirm timing/cost extensions accommodate intraday fill policies.

The audit should record, for each RFC above, whether it is **pinned**
(design is cadence-neutral, add contract tests), **amend** (one or more
specific clauses need updating in the existing synthesis), or **extend**
(open a new RFC that extends the existing synthesis for intraday). The
audit output is itself an input for the v0.2.x intraday-arc cycle
planning.

#### Promoted roadmap hooks

- intraday support arc (v0.2.x through v0.3.0, multi-cycle) — depends
  on OMS, session calendars, intraday fill timing, liquidity/capacity,
  intraday-aware metric context, and intraday storage scale evidence;
- session calendar infrastructure RFC — new work, no current roadmap
  line; cut after OMS lands;
- intraday metric context extension — extends v0.1.8.2 metric context
  work; same calendar surface, parameterized cadence;
- intraday fill timing policy — extends v0.1.9.x/v0.2.0 cost API arc;
- intraday storage scale evidence — extends v0.1.8.6 feature-storage
  spike with intraday workload comparisons if the spike is rerun;
- design audit for intraday-readiness footguns — user-initiated, no
  committed cycle, but this entry provides the input shape.

#### Cross-cycle note

This entry does not authorize new cycles. Its operative effect is on the
completed v0.1.8.10 cycle, the active v0.1.8.11 documentation/cleanup cycle,
and the planned v0.1.9 and v0.1.9.x cycles: each must avoid the footguns named
above.
The user-initiated design audit will produce a sharper list of "preserve
this" and "fix this before it becomes permanent" findings. Until the
audit lands, treat this entry as a soft constraint on architectural
decisions in cycles that touch metric context, fill timing, target
storage, pulse cadence, or sweep candidate identity.

The "EOD-first, intraday-tolerant" posture remains the right user-facing
framing for v0.1.8.5 documentation. Do not pre-document intraday
support; do not pre-commit to it in user-facing prose; do not let
intraday assumptions sneak into v0.1.x code that should be cadence-
neutral.

This horizon entry does not authorize the intraday arc itself. It
records direction so that when the arc opens, the seed authors start
from a known shape rather than re-deriving the boundary, and it
constrains the in-progress v0.1.x cycles to avoid footguns that would
make the eventual flip a rewrite.

### 2026-05-28 [data] Live bad-data resilience and sim-to-real backtest fidelity

The overall arc is backtest -> paper -> live. Live data is structurally
different from backtest data, and the difference is a fault line the
backtest-first design has not had to confront. Surfaced while reviewing the
fold core; the maintainer has flagged it as RFC-worthy.

The fault line

ledgr's backtest correctness rests on a **sealed dense panel**, enforced
fail-fast: every instrument must have a bar at every pulse or the run aborts
with `ledgr_missing_bars` (verified: cross-join completeness check
`backtest-runner.R:1541-1564`; per-instrument alignment
`backtest-runner.R:1154-1159`). Live data is the opposite posture — a
streaming partial feed where missing, garbled, late, duplicated, or revised
ticks are routine. You cannot abort a live session because one symbol's tick
did not arrive. "Validate everything upfront, fail fast" and "tolerate and
degrade per-tick" are structurally opposed.

Second fault line — offline ragged universes (not just live)

The dense-panel gate also blocks a purely *offline* case: a realistic surviving
universe is inherently ragged. IPOs / late listings, delistings, halts, and
exchange holidays mean a security legitimately has no bar at some pulses — yet
the coverage check (`backtest-runner.R:815-822`, `LEDGR_SNAPSHOT_COVERAGE_ERROR`,
plus the `ledgr_missing_bars` cross-join check) requires every instrument to
have a bar at every pulse, so survivorship-realistic research is impossible
without external pre-cleaning. This is independent of the live/streaming arc.

Peer evidence (2026-05-29 research): among multi-asset / panel backtesters,
hard-failing on any per-instrument gap is an **outlier**. The mainstream
tolerates ragged panels — Zipline and LEAN forward-fill and model **asset
lifetimes** (start/end/delist, masking outside the active window with NaN/zero;
`zipline data_portal.py:1018-1030`, LEAN fill-forward-until-delisted); `bt`
(Python) and VectorBT carry not-yet-listed / delisted assets as NaN columns and
object only on a *held* NaN position. The only hard-failers are *single-asset*
frameworks (backtesting.py) or per-symbol loops (quantstrat), where there is no
cross-sectional alignment to solve. So strict single-series rejection is
mainstream; strict *multi-asset-panel* rejection is not.

Design target: **per-instrument active windows** (asset lifetimes) — an
instrument is active over `[first_bar, last_bar]` and the fold tolerates its
absence outside that window — plus an **explicit, sealed** absence/imputation
policy. The ledgr-specific constraint vs peers: their ffill is *silent*; ledgr's
"evidence you can defend" USP requires the active-window and any
fill / NaN / staleness policy to be **declared and sealed into the snapshot**
(and visible in provenance), not silently imputed in the fold — otherwise the
backtest runs on a quietly different data world than the inputs claim. The
*where* matters: active windows + the ingest policy live at the seal boundary;
the fold then consumes a panel marked "present / absent-by-lifetime / imputed",
and never hard-fails on legitimate absence.

Failure taxonomy (each needs a different policy)

- **Missing tick** — skip the symbol, carry forward last value with a
  staleness flag, halt the symbol, or halt the session.
- **Garbled tick** — zero/negative/NaN price, OHLC violation, absurd spike.
  Backtest catches this at seal time; live must catch it at ingest time and
  quarantine/reject before it reaches a decision.
- **Late / out-of-order tick** — needs a watermark/lateness policy.
- **Duplicate tick** — idempotent ingest.
- **Revised tick** — vendor corrects a past bar after the decision was made;
  you cannot un-decide. Hardest case.

What carries over vs what breaks

Carries over: the event-sourced ledger (a live session is a longer append-only
event stream), the pulse model (a live pulse is information available at
decision time t; no-lookahead is trivially satisfied), and the v0.2.x OMS
two-stream design. Breaks: the dense-panel fail-fast, and snapshot
immutability (live appends as data arrives — an append-only data log, not a
sealed snapshot).

Chosen direction: B — the backtest must model degraded data

Two ways to close the sim-to-real gap:

- **(A)** force live into the dense-panel model — buffer/wait/skip. Simple,
  preserves the backtest model, adds latency, not always viable.
- **(B)** give the backtest the ability to model degraded data — gap
  injection, staleness, halts, bad-tick spikes — so strategies are validated
  against realistic data conditions before live.

**Decision: direction B.** The "evidence you can defend" USP collapses if the
evidence was gathered on a cleaner data world than the strategy will face live.
When paper trading is designed, the maintainer wants to simulate data streams
with all kinds of deficiencies, at a much higher frequency than EOD, to test
the seams — and the backtest engine must be able to swallow that bad data on
the same execution path. So the backtest data model has to grow a "this bar is
missing / stale / suspect" representation it does not have today.

Design principles

- **Strategy contract does not change.** A strategy sees "current pulse-known
  information" in both backtest and live. What changes is what the *data layer*
  decides "current" means when a tick is missing or suspect. Degradation
  policy must not leak into every strategy.
- **Late/revised ticks intersect Point-In-Time Data Tables** (v0.2.x:
  `known_at`, `available_at`, `revision_time`, source version). A PIT model
  keeps "the decision at t used the data available at t" true even after a
  later revision — the revision is a new vintage, not a rewrite of history.
- **Missing/garbled at ingest needs a live data-quality layer** with an
  explicit degradation policy (quarantine / reject / carry-forward-with-
  staleness / halt-symbol / halt-session), distinct from the backtest
  seal-time gate.

RFC scope (when it opens)

A unified data-quality model spanning sealed backtest and streaming live; the
degradation-policy surface; **per-instrument active windows (asset lifetimes) for
ragged offline universes, with an explicit sealed absence/imputation policy
(vs peers' silent ffill)**; the bad-data simulation harness for backtest
(deficient high-frequency streams); and the PIT-tables intersection.

Sequencing

Behind PIT tables and the live data log (v0.2.x) and the OMS work; lands around
v0.2.x -> v0.3.0 paper trading. The high-frequency deficient-stream simulation
is a v0.3.0 paper-trading design input. Near-term footgun is already recorded
in the intraday-readiness entry: the dense panel is a backtest gate, not a
universal invariant.

This horizon entry does not authorize the work. It records the direction and
the chosen approach (B) so the eventual RFC starts from a known shape.

### 2026-05-28 [execution] RNG resume is non-deterministic for stochastic strategies

Verified correctness gap (2026-05-28), found during the fold-core validation.

On resume, **state** is correct: cash and positions are reconstructed by
replaying events as-of the resume timestamp via `ledgr_state_asof()`
(`backtest-runner.R:1088-1099`). But the **RNG stream** is not restored. The
runner calls `set.seed(seed)` (`backtest-runner.R:589`) and the fold calls
`set.seed(execution_seed)` (`fold-core.R:69`); the loop then jumps to
`start_idx` without replaying pulses 1..start_idx-1, and there is no
`.Random.seed` checkpoint/restore anywhere (it exists only in `sim-bars.R`, the
unrelated bar simulator).

Consequence: a **deterministic** strategy resumes byte-identically (no RNG
dependence). A **stochastic** strategy (Tier 2, e.g. `runif()`) drawing at
pulse k on resume gets the *pulse-1* RNG draw, not the advanced stream a
continuous run would have at pulse k. The execution-seed contract guarantees
within-continuous-run repeatability, not resume equivalence for stochastic
strategies.

Decision needed (one of):

- checkpoint `.Random.seed` at each flushed pulse and restore it on resume;
- replay pulses 1..start_idx-1 on resume to re-advance the RNG (expensive);
- document the limitation and restrict resume guarantees to deterministic
  strategies (cheapest, honest).

Cross-link: the v0.1.8.8 parallel-dispatch work faces the same RNG-state
question - per-candidate seed derivation must not depend on worker scheduling
or global RNG state. Whatever resolves resume should align with that.

This entry records a verified gap, not a committed fix.

### 2026-05-28 [architecture] Fold-core structural debt surfaced by adversarial review

Two adversarial reviews of the fold-core workbook surfaced design debt that is
survivable today but should be addressed before OMS / risk / intraday land.
None is a correctness bug — the one alleged SELL cash-sign bug was a workbook
paraphrase typo, not a code bug; the code uses absolute `fill$qty` and is
correct (`fold-core.R:280-284`, `ledger-writer.R:66-71`). These are refactor
candidates.

- **One production replay kernel.** Two equity-reconstruction implementations
  share one algorithm: the inline run-path copy (`backtest-runner.R:1378-1478`)
  and the sweep reconstructor (`ledgr_sweep_summary_from_ordered_events`), with
  `ledgr_equity_from_events`/`ledgr_fills_from_events` as test-only parity
  twins. The split is perf-motivated (v0.1.8.3: sweep avoids the DB round-trip)
  and guarded by `test-sweep-parity`. End-state: one production replay kernel
  fed by DB or memory event sinks; everything else an adapter. Partial fills,
  dividends, borrow fees, or margin would multiply the drift risk.
- **Phased pulse for portfolio-level risk.** The per-pulse loop interleaves
  delta -> proposal -> cost -> event -> state-mutation per instrument. That
  shape resists portfolio-level risk and net affordability. Target shape: plan
  (targets -> deltas) -> batch proposals -> batch cost -> batch/portfolio risk
  + net affordability -> emit -> apply atomically. This is the structural
  prerequisite for the v0.1.9 affordability check (see the 2026-05-27
  affordability-in-target-risk entry) and is a v0.1.9 target-risk RFC input.
- **Typed execution spec.** The `execution` list is a large untyped bag; run
  and sweep hand-build equivalent-but-not-identical lists (verified divergences
  in seed derivation, `event_mode`, hardcoded vs config fields, metric-kernel
  timing). A typed `ledgr_execution_spec()` constructor with validation would
  prevent run/sweep drift.
- **Split `fold-core.R`.** It holds the engine, the reconstructors, and metrics
  helpers in one file. Split before OMS/risk/intraday add more concerns.
- **Explicit event types.** Opening positions are seeded as `CASHFLOW` events
  with meta flags. Accounting-critical semantics should not live only in
  `meta_json`; add a `POSITION_SEED` type (and reserve `FEE`, `DIVIDEND`,
  `SPLIT` for later) rather than overloading `CASHFLOW`. This is deferred from
  v0.1.8.8 and scheduled as a dedicated v0.2.x RFC coordinated with corporate
  actions / instrument-master work; do not slip it into fold-core documentation
  or parallel-dispatch tickets.
- **Batch-aware cost model.** The per-proposal `cost_resolver` cannot model
  batch/portfolio slippage or liquidity. Routes to the v0.2.x
  liquidity/capacity arc; the single-order resolver remains the default
  adapter.

Verified-and-fine (recorded so the design audit does not re-raise them): the
no-lookahead invariant holds; the `findInterval` equity mapping is correct for
next-open fills; the dense-panel fail-fast plus whole-run DuckDB transaction
(`run_transaction = dbWithTransaction`) make state/event consistency clean
(state is replayed from events, never separately persisted); open-position
drawdowns are captured by the equity curve, so there is no survivorship bias in
the headline return/drawdown metrics.

This entry records direction, not committed work.

### 2026-05-28 [adapters] External-package output adapters (PerformanceAnalytics first)

ledgr's stable public result tables (equity, fills, trades, ledger) plus the
stored metric context are the right substrate for thin, optional, output-only
adapters into the established R quant ecosystem. **Committed for v0.2.x** (see
the roadmap "External Package Adapters" entry); this horizon note records
direction, and an RFC synthesis — not this entry — authorizes any public API.

The first adapter is **PerformanceAnalytics**, scoped to its real strength — the
drawdown/return tables and long-tail risk/return stats, not its charts. It is a
pure output projection (equity -> return stream -> PA), so it touches no
causality, strategy-contract, determinism, or engine-mutation surface, and is
the cleanest public proof of the hexagonal pattern: ledgr owns the canonical
evidence, adapters enrich the analysis.

Charting is a separate, swappable renderer over the same return stream — not a
PA lock-in. PA's base-R graphics are a familiar/legacy option; the modern faces
are tidyquant (ggplot2 over the same PA metrics — distinct from the academic
tidyfinance) or a native ledgr ggplot tear-sheet (`R/plot.R` already exists).
The reusable port is the equity -> return conversion; many renderers consume it.

Why high-value: one stable result-table contract unlocks the whole
PerformanceAnalytics / PortfolioAnalytics / tidyfinance reporting and research
surface — a large host of additional capabilities (tear sheets, risk/return
tables, factor research, portfolio optimization) — without ledgr reimplementing
any of it.

Adapter ranking (later ones gated on their own readiness):

- PerformanceAnalytics — reporting / tear-sheet; first, output projection only.
- PortfolioAnalytics — portfolio construction / post-ledger optimization; after
  the v0.1.9 target-risk chain stabilizes.
- tidyfinance — factor / data research; with the v0.2.x PIT / vintage semantics.
- quantmod — data ingestion; useful but less differentiating.
- PMwR / quantstrat / blotter / fPortfolio — low priority or skip (accounting /
  engine overlap that would blur which engine is the source of truth).

Boundary the RFC must bind:

- output projection only — no second canonical metrics path;
- consume ledgr's OWN canonical return series (whatever `ledgr_compute_metrics`
  derives); never reinvent the return formula inside the adapter, or the base
  series silently diverges;
- PerformanceAnalytics metrics use PA conventions and can differ from ledgr's;
  scope PA to what ledgr does NOT already compute and label any overlap rather
  than presenting two conflicting Sharpe numbers as both authoritative;
- optional dependency (`Suggests` + `check_installed`), never `Imports`;
- adapters inspect, they do not select winners (no sweep ranking / promotion
  automation) — selection stays human, per the promotion-is-not-validation
  stance;
- benchmark-relative metrics coordinate with the v0.2.x benchmark-context layer
  so PA does not become the de-facto benchmark-metrics surface ahead of ledgr's
  own contract;
- one shared adapter namespace pattern (e.g. `ledgr_<pkg>_*`) decided up front;
- live `findInterval`+`cumsum` reconstruction and the reopened DB-replay path
  must yield identical adapter output.

Inside ledgr under `Suggests` for the first adapter (it proves the pattern
publicly); split into `ledgr.adapters` or per-package packages only if the
surface grows. Source: the 2026-05-28 maintainer review of an adapter-ecosystem
proposal.

This entry records direction, not committed work.

## Resolved

Entries move here when their idea has shipped or been answered. Each records
what resolved it. Sweep an idea here when its milestone closes — do not leave
shipped work in "Open."

### 2026-06-05 [planning] v0.1.9.4 walk-forward Section 17 gate-row obligations from the v0.1.9.x arc -- resolved by v0.1.9.4

Resolved by the v0.1.9.4 walk-forward packet. The packet treated the horizon
entry as the cross-cycle enforcement record, named both `cost_model_hash` and
`risk_chain_hash` in `candidate_key` and `session_id`, and shipped identity
tests exercising those components.

The accepted obligations remain traceable through:

- `inst/design/ledgr_v0_1_9_4_spec_packet/v0_1_9_4_spec.md`;
- `inst/design/ledgr_v0_1_9_4_spec_packet/v0_1_9_4_tickets.md`;
- `tests/testthat/test-walk-forward-identity.R`.

### 2026-06-05 [planning] v0.1.9.1 cost-API spec-cut decisions on synthesis Section 13 open questions -- resolved by v0.1.9.1

The accepted cost-API synthesis
(`rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`)
left five questions to the spec-cut writer in Section 13. The v0.1.9.1 packet
bound and implemented them with the aggressive pre-CRAN-no-users posture:
reject legacy shapes, no transitional auto-translation, no silent defaults.

**Decision 1: legacy `fill_model = list(...)` shape.** Reject with classed
error.

Rationale: the API restructures (`fill_model` splits into `timing_model` +
`cost_model`) AND the spread semantics shift from full-bps-per-leg to
quoted-spread (half-bps-per-leg). Auto-translation would silently halve
`spread_bps` values -- a numeric footgun. Forcing users to re-author surfaces
the semantic shift explicitly. Pre-CRAN policy makes this affordable.

Implementation shape:

- `ledgr_experiment(... fill_model = list(...))` raises
  `ledgr_legacy_fill_model_shape` at construction.
- Error message points at `timing_model = ledgr_timing_next_open()` and
  `cost_model = ledgr_cost_chain(ledgr_cost_spread_bps(...),
  ledgr_cost_fixed_fee(...))`.
- Error message explicitly names the quoted-spread convention shift:
  "spread_bps in the new API is quoted-spread (half per leg); divide your old
  value by 2".

**Decision 2: cost plan execution shape.** Confirm "implementer's choice with
stable outputs and identity."

Rationale: synthesis already notes "likely defer to implementer." Spec-cut just
confirms. Implementation gated on:

- identity stability tests pass;
- `cost_plan_json` reconstruction parity tests pass;
- no per-pulse DB writes in cost resolution (already in synthesis Section 9).

Row-wise resolver, vectorized per-pulse, or hybrid is the implementer's call
subject to those gates.

**Decision 3: cost component diagnostic retention.** `meta_json` only in v1.

Rationale: reserving a future diagnostic table shape pre-commits to schema
without binding text -- the exact pattern the closed `compiled_accounting_model`
enum scope-guard discipline rejects. `meta_json` is the flexible v1 surface.
Structured diagnostic tables, if needed, get their own RFC (alongside the
diagnostic-retention RFC that walk-forward already defers to in its Section 12
Future Obligations).

**Decision 4: reopen-path compatibility for stored configs.** Reject with
classed error.

Rationale: matches the pre-CRAN policy in horizon's 2026-05-25 entry:
"users should expect to rerun experiments after upgrading when the cycle
changes storage/hashing/execution contracts." No translation logic for zero
current users.

Implementation shape:

- `ledgr_run_open()` reading a stored `config_json` containing `fill_model`
  raises `ledgr_legacy_config_shape`.
- Error message points at recreating the experiment with the new API surface.

**Decision 5: `cost_model = NULL` default.** Require explicit argument; no
implicit default.

Rationale: cost is part of run identity, not an afterthought. Three lenses
converge:

- Walk-forward synthesis Section 3 binding for `opening_state_policy`:
  "no hidden hardcoded behavior is allowed." Same principle for cost.
- An implicit `ledgr_cost_zero()` default is a real footgun: user runs backtest,
  sees great Sharpe, does not realize the experiment had zero costs.
- ledgr's broader pattern is explicit-at-construction for
  identity-participating arguments.

Implementation shape:

- `ledgr_experiment()` without explicit `cost_model` raises
  `ledgr_cost_model_unspecified` at construction.
- Error message hints at `ledgr_cost_zero()` for users who genuinely want
  zero-cost (must be explicit).

**Resolution:** v0.1.9.1 implemented the five decisions through the public
cost API, explicit timing / required cost model surface, classed legacy-shape
rejections, cost identity (`cost_model_hash`, `cost_plan_json`), and
documentation / NEWS closeout. The v0.1.9.x sequencing entry, v0.1.9.2 sweep
RFC schedule, and v0.1.9.4 walk-forward gate-row obligations remain open
because they are forward dependencies, not v0.1.9.1 implementation claims.

### 2026-06-04 [documentation] Documentation, structure, and cleanup release shipped v0.1.8.11

v0.1.8.11 shipped the planned documentation and cleanup pass before v0.1.9:
maintainer manual, RFC decision index, contract audit and structure pass,
post-B2 documentation refresh, user-facing disclaimer, internal performance arc,
benchmark methodology, roadmap / horizon / design-index housekeeping, and the
`adr/` + `architecture/` + `maintainer_review/` wind-down. No v0.1.8.12
documentation follow-on is planned; future bounded documentation belongs in
v0.1.9.x only if a later packet cuts it explicitly.

### 2026-05-15 [adapters] Multi-output indicator authoring bundles — shipped v0.1.8.1

`ledgr_indicator_bundle` / `ledgr_ind_ttr_outputs()` shipped in v0.1.8.1 with
the accepted design: flatten-at-declaration to single-output indicators,
output-specific fingerprints, normalized prefix (`bbands_dn`), `prefix = NULL`
raw opt-in, instrument IDs never in feature IDs. See the v0.1.8.1 packet and
`rfc_multi_output_indicator_ux_synthesis.md`.

### 2026-05-15 [ux] Parameter-grid construction helpers — shipped (core) v0.1.8.4

`ledgr_feature_grid()`, `ledgr_strategy_grid()`, and `ledgr_grid_cross()`
shipped in v0.1.8.4 as candidate-set construction helpers with no
objective/ranking semantics. The `ledgr_grid_named()` /
`ledgr_grid_add_baseline()` variants were not built and remain low-priority
optional ideas if a future cycle wants them.

### 2026-05-25 [optimization] Grid-union shared pulse views — shipped v0.1.8.4

v0.1.8.4 adopted the grid-level concrete-feature-union: shared concrete
features computed once across a sweep grid, not once per candidate. See the
v0.1.8.4 packet.

### 2026-05-15 [execution] Single-core sweep hot-path optimization — shipped v0.1.8.3

v0.1.8.3 shipped the runtime projection + R-memory backend + fast context and
the summary-only in-memory accounting path
(`ledgr_sweep_summary_from_ordered_events`), addressing the pulse-context churn
and event-replay reconstruction costs this entry identified.

### 2026-05-13 [execution] Compact execution semantics article — shipped v0.1.8.5

`vignettes/execution-semantics.qmd` shipped in the v0.1.8.5 teachability cycle
(Batch 4) as the consolidated reference for next-open fills, targets-as-
holdings, decision-time sizing, final-bar no-fill, and open positions.

### 2026-05-13 [data] Data input and snapshot creation article — resolved v0.1.8.5

Resolved without a separate article: the v0.1.8.5 cycle moved the low-level CSV
bridge to the `?ledgr_snapshot_import_bars_csv` help page (reference boundary)
and kept experiment-store centered on run management, so the split this entry
proposed is no longer needed.

### 2026-06-01 [optimization] Feature projection materialization + storage spike + benchmark closeout — shipped v0.1.8.6

The v0.1.8.6 cycle shipped per the feature projection synthesis: 5.0 feature
cache-key dedup (fingerprint + engine-version), 5.1 schema-only
`ctx$feature_table` default with non-fast-path rebuild fix, and the
post-5.0/5.1 remeasurement + instrument x feature sweep. The DuckDB feature
storage spike ran independently and informed direction. Structured benchmark
+ attribution closeout established the LDG-2476 baseline for v0.1.8.9. Typed
persistent `cash_delta` / `position_delta` columns (5.6) were deliberately
deferred to a later storage RFC; LDG-2451 snapshot administration was
deferred to v0.2.0-class per the 2026-05-29 entry. See the v0.1.8.6 packet
and `rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`.

### 2026-06-01 [optimization] v0.1.8.7 Optimization Round 2 — shipped v0.1.8.7

The v0.1.8.7 cycle shipped per the optimization-round synthesis: surface-
preserving event-buffer capacity/write fix (B0), hot-path representation /
formatting cleanup with durable-identity bytes fenced off (R), read-back
reconstruction behind a deterministic collapse gate (C), ADR 0004
dependency moves (drop cli + R6, add collapse, keep tibble), and explicit
legacy cleanup (raw `bars` execution, R6 strategy execution, run-time
`data_hash` identity removed from modern execution). Per-lane real-run
re-profile and parity gates landed alongside. See the v0.1.8.7 packet and
`rfc_optimization_round_v0_1_8_7_synthesis.md`.

### 2026-06-01 [infrastructure] Parallel sweep dispatch + typed execution spec — shipped v0.1.8.8

The v0.1.8.8 cycle shipped public parallel sweep dispatch, parallel worker
setup with Tier-2 packages, mori transport, worker-local read-only DuckDB,
parallel interrupt + measurement contract, typed `ledgr_execution_spec_v1`
(LDG-2472), deterministic-only RNG with `ctx$pulse_seed` (LDG-2471), and
the `inst/design/manual/` skeleton (without authoring the full internal
manual - that work moves to v0.1.8.11 per the 2026-05-30 maintainer-manual
backlog entry). LDG-2479 self-profiling workload grid extension landed as
the v0.1.8.9 baseline. See the v0.1.8.8 packet.

### 2026-06-01 [optimization] v0.1.8.9 single-core optimization round — shipped v0.1.8.9

The v0.1.8.9 cycle shipped the single-core optimization round per the
LDG-2476 / LDG-2479 per-pulse complexity finding. Highlights: fills
extractor `setv` (Batch 5 wins per LDG-2496), durable + memory output
handler `setv` rewrites, durable handler character-write fix, vectorized
fold position valuation and target-delta scan, canonical JSON migration to
yyjsonr (LDG-2493 / LDG-2494). High-density xlarge durable cell moved
445.02s → 232.03s wall, 413.47s → 199.06s loop, 197.11s → 23.36s fills
extraction. Per-fill engine cost fell 3107 → 1495 us/fill; per-fill
extraction cost fell 1481 → 175 us/fill. Phase-separated peer-benchmark
engine ratio 1.74x → 1.12x Backtrader; total wall ratio 1.50x. See the
v0.1.8.9 packet and the 2026-05-31 LDG-2476 entry's Batch 8 closeout
addendum for the substrate / read-path / ephemeral-mode residuals that
forward into the v0.1.8.10 spike round.

### 2026-06-03 [optimization] v0.1.8.10 single-core substrate and B2 closeout - shipped v0.1.8.10

The v0.1.8.10 cycle closed the v0.1.8.x single-core arc with ephemeral
subphase telemetry, matrix-canonical fold substrate and strategy accessors,
event-preserving fold-owned FIFO accounting, yyjsonr options hoisting, a B2
compiled spot-FIFO measurement gate, scoped public memory-backed sweep opt-in,
per-lane attribution, and workload-grid / peer-benchmark measurement closeout.
Default execution remains canonical R. Durable compiled integration,
non-spot compiled accounting, target risk, walk-forward, cost/liquidity, OMS,
and public benchmark claims remain deferred. See the v0.1.8.10 packet.
