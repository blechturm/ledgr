# RFC Seed: Sweep Artifact Persistence For ledgr

**Status:** RFC seed -- planning input for the v0.1.9.2 packet, not accepted.
**Author:** Claude draft for maintainer review.
**Date:** 2026-06-06
**Target window:** v0.1.9.2, sequenced as the second tick of the v0.1.9.x
arc (cost-API -> sweep persistence -> target-risk -> walk-forward).
**Primary research input:** maintainer discussion threads 2026-06-05 and
2026-06-06; competitor research embedded in the v0.1.9.2 planning thread
(QuantConnect, Backtrader, vectorbt, quantstrat, PerformanceAnalytics,
Alphalens / QuantRocket, blotter).
**Predecessor RFC thread:** none for sweep persistence specifically; this
cycle starts from the roadmap entry and the older "Promotion-grade sweep
artifacts" horizon entry.
**Constrained by:**
- `inst/design/contracts.md`
- `inst/design/ledgr_roadmap.md` (v0.1.9.x Line Sequencing preamble; v0.1.9.2 Sweep Artifact Persistence section)
- `inst/design/horizon.md` (2026-06-05 v0.1.9.x sequencing entry; 2026-06-05 sweep RFC schedule entry)
- `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md` (Section 6 cost identity; Section 14:560 forward obligation to walk-forward identity recipes)
- `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md` (Section 10 v0.1.9.x Minimum Scope; Section 12 Future Obligations on richer diagnostic retention)
- `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md` (cross-reference for v0.1.9.3 target-risk; not consumed by v0.1.9.2)

> **v1 naming convention.** This RFC uses "v1" as shorthand for "the first
> implementation of sweep artifact persistence in ledgr." ledgr's roadmap
> does not have a sweep-persistence v1 milestone; v1 here means the
> v0.1.9.2 ticket-cut. Post-v1 work lives in named follow-up RFCs at their
> own roadmap windows.

---

## 0. Scope And Non-Scope

This seed addresses the first public sweep artifact persistence API.

The unresolved question is:

```text
How should users save sweep results durably, reopen them later, retain
enough evidence to do honest statistical validation before committing to
promotion, and do all of that without ledgr inventing a ranking-rule
system, a diagnostic-retention platform, or a statistical-method library?
```

### Scope

- Saving sweep results to the same DuckDB store that holds runs.
- Reopening saved sweeps as objects that behave like in-session
  `ledgr_sweep()` results.
- Listing and inspecting saved sweeps.
- An explicit retention knob that controls what non-scalar artifacts the
  in-memory sweep result carries (default: scalar only).
- Retaining net portfolio equity / returns per completed candidate when
  the user opts in, with explicit semantic bindings on what "net portfolio
  equity / returns" means.
- Surfacing the retained returns through an accessor that does not invent
  ranking, selection, or comparison machinery.

### Non-scope for v1

- Full ledger, fill, trade, or per-instrument retention for any candidate
  by default. Those remain accessible only after promotion.
- Cost-component attribution or per-trade cost decomposition. The cost
  identity surface (`cost_model_hash`, `cost_plan_json`) lives on
  candidate rows, but cost component time series are out of scope.
- Gross-vs-net portfolio return decomposition. The "gross return"
  definition has multiple non-equivalent candidates and requires a
  separate execution-attribution RFC. See Section 11.
- Signal decay / factor IC analysis. Alphalens-equivalent forward-return
  computation against feature values is a separate factor-decay RFC. See
  Section 11.
- Statistical-method helpers (DSR, PBO, CSCV, bootstrap, robustness
  slicing). v0.1.9.2 ships the retention substrate; method libraries
  belong in the selection-integrity-diagnostics RFC at the v0.1.9.x slot.
- PerformanceAnalytics or pyfolio adapter. PA adapters belong in the
  v0.2.x External Package Adapters RFC per the roadmap.
- Ranking-rule machinery, named selection views, retention modes that
  bake metric-based selection into persistence (e.g., `top_n` retention).
- Cross-sweep comparison helpers, sweep-diff utilities, sweep extension
  or append semantics.
- Walk-forward per-fold per-candidate return-series retention. v0.1.9.4
  walk-forward consumes the v0.1.9.2 substrate but may require richer
  shape (fold_seq dimension, train vs test window split). The walk-forward
  synthesis Section 12 defers this and the v0.1.9.4 packet binds it. See
  Section 10.
- Automatic winner selection of any kind. Promotion remains explicit.
- Weakening of `ledgr_promote()`, `ledgr_candidate()`, or
  `run_promotion_context`.

The seed assumes ledgr remains pre-CRAN with no external users. Storage
schemas and saved-artifact compatibility may break across cycles per the
horizon's 2026-05-25 pre-CRAN compatibility policy.

---

## 1. Current Code And Contract Baseline

The current public surface produces sweep results entirely in memory:

```r
sweep <- ledgr_sweep(exp, grid, seed = 123L)
sweep
# A tibble: N x M with candidate_id, params, scalar metrics,
# warnings/errors, identity hashes, execution seed, ...
```

`ledgr_sweep()` is documented in `R/sweep.R`. The result is a classed
tibble with attributes for cost_model_hash, cost_plan_json,
execution_assumptions, metric_context, metric_context_hash,
metric_context_version, and execution-mode metadata. Each row carries
identity sufficient for `ledgr_candidate()` extraction and
`ledgr_promote()` commitment.

What ends with the R session: the in-memory result object, all candidate
scalar metrics, all warnings, all identity attributes, all underlying
data ledgr computed during fold execution. The fold engine ran every
candidate, produced events through the memory output handler, computed
equity / fills / trades during execution, materialized the canonical
metric scalars, then discarded everything except the summary tibble.

What survives the session today: nothing. The next `ledgr_sweep()` call
re-runs all candidates from scratch.

Existing surfaces that v0.1.9.2 does NOT change:

- `ledgr_sweep()` signature and return shape, except for the addition of
  a `retain` argument with a default that preserves current behavior;
- `ledgr_candidate()` extraction;
- `ledgr_promote()` commitment;
- `ledgr_run_open()`, `ledgr_run_info()`, `ledgr_run_list()` for
  promoted-run inspection;
- the fold core, cost resolver, identity surfaces from v0.1.9.1.

Cost identity from v0.1.9.1 is already on sweep result rows
(`cost_model_hash`, `cost_plan_json` per candidate); v0.1.9.2 inherits
these and persists them per the cost-API synthesis Section 14:560
forward obligation.

---

## 2. The Load-Bearing Architectural Distinction

The discussion that produced this seed converged on one insight that
resolves what initially looked like a scope balloon:

> **Retention and persistence are orthogonal concerns. Retention
> controls what the in-memory sweep result object carries; persistence
> controls what gets written to durable storage.**

These are different decisions. A user may want returns retained in
memory for in-session validation without writing them to DuckDB. A
different user may want the same returns written durably for later
reopening. A third user may want scalar-only retention and scalar-only
persistence (the cheap default). The three workflows compose freely once
retention and persistence are separated:

```r
# Workflow A: fast screening, scalar-only
sweep <- ledgr_sweep(exp, grid)
ranked <- sweep |> dplyr::arrange(dplyr::desc(sharpe_annualized))

# Workflow B: in-session statistical validation, no durable storage
sweep <- ledgr_sweep(exp, grid, retain = ledgr_sweep_retention(returns = "all"))
returns <- ledgr_sweep_returns(sweep)
# DSR / PBO / bootstrap via external tools; decide nothing is worth saving

# Workflow C: durable validation, returns persisted with the sweep
sweep <- ledgr_sweep(exp, grid, retain = ledgr_sweep_retention(returns = "all"))
ledgr_sweep_save(sweep, snapshot = snap, sweep_id = "sma-grid-q1")
record <- ledgr_sweep_open(snap, "sma-grid-q1")
returns <- ledgr_sweep_returns(record)
```

The same retention specification flows through both the in-memory object
and (optionally) durable storage. v1 binds the simplest contract: save
persists exactly what was retained. Narrower-persistence-than-retention
is a future obligation if it surfaces real demand.

---

## 3. Three-Tier Evidence Framing

Sweep persistence does not solve every analytical question. It solves
one specific layer in a three-layer framing the discussion crystallized:

| Tier | Data | Question it answers | Lives in |
| --- | --- | --- | --- |
| 1 | Scalar metrics per candidate | "which candidates merit further inspection?" | sweep result row (today; persisted in v0.1.9.2) |
| 2 | Net portfolio returns / equity per completed candidate | "which candidates survive distributional analysis?" | retained in memory and optionally persisted (new in v0.1.9.2) |
| 3 | Full event-sourced ledger, fills, trades, per-instrument equity | "what is the complete record of this strategy's behavior?" | promoted run (today; unchanged by v0.1.9.2) |

Tier 1 enables coarse screening via dplyr. Tier 2 enables statistical
validation via external tools (PerformanceAnalytics, the `pbo` package,
custom bootstrap and DSR computations). Tier 3 enables the full
audit-trail surface and post-hoc decomposition.

The competitor pattern validates this split. None of QuantConnect,
Backtrader, vectorbt, quantstrat, PerformanceAnalytics, Alphalens, or
QuantRocket unifies all three. Each ships one tier and gestures at the
others. The split is not arbitrary; each tier has different analytical
conventions, different time scales, and different consumers. Forcing
them into one surface would be more confusing than the natural split.

ledgr's potential differentiator is that the same fold core produces all
three tiers consistently, with shared identity surfaces. v0.1.9.2 ships
Tier 2 explicitly while preserving the cross-tier identity coherence.

---

## 4. Bound Semantic Shape: The Retained Series

Before API design, the seed binds the load-bearing semantic decisions
for what "net portfolio returns / equity per completed candidate" means.
These are not implementer's-choice; they bind the contract every
downstream consumer (PA users, future walk-forward integration, the
diagnostic-retention substrate) depends on.

### 4.1 Both equity and returns retained, derived from the same fold output

The retained series is the same data path that produces
`ledgr_results(promoted_run, "equity")$equity` and its per-row return.
The fold engine computes net portfolio equity per scoring pulse during
execution; v0.1.9.2 retains it instead of discarding it. The return
series is the standard one-row-difference transform on equity.

Retaining both is one numeric column per pulse for each: not a 2x
storage cost. Users compute either from the other if they want, but
having both available avoids forcing every user through the same
derivation.

### 4.2 Net of transaction costs

Costs are applied at the cost resolver per the v0.1.9.1 cost-API
contract. The retained series reflects the post-cost portfolio equity:
fill_price is post-spread, fee is deducted from cash, all accounting
events flow through with costs applied. This is the same definition
`ledgr_results()` returns on promoted runs.

"Gross" alternatives (reference price before spread, fee-removed,
counterfactual zero-cost) are out of scope and routed to a separate
execution-attribution RFC. See Section 11.

### 4.3 Scoring pulses only; no warmup

Warmup pulses have no positions taken and meaningless portfolio equity
(`equity = initial_cash` by construction). Retention covers only the
scoring window. This matches the existing scoring contract from v0.1.8.x
sweep semantics.

### 4.4 Include initial-equity row

Consistent with `ledgr_results(run, "equity")`: the first retained row
is `initial_cash` at the snapshot's first scoring timestamp. This lets
users compute returns from row 1 without dropping or padding boundary
behavior, and matches the existing equity contract surface.

### 4.5 Final-bar no-fill semantics preserved as observed

If the candidate hit `LEDGR_LAST_BAR_NO_FILL`, the retained series ends
at the last bar that did fill, same as scalar metrics observed during
the sweep. No phantom row. No extrapolation. The warning travels with
the candidate row in the sweep summary; retention does not invent a
parallel signal.

### 4.6 Canonical series matches `ledgr_compute_metrics()` consumption

The retained series is byte-equivalent under existing accounting
tolerances and canonical ordering to the series `ledgr_compute_metrics()`
would compute against a promoted run with identical identity. This is
the parity contract.

Implication: when a user computes `PerformanceAnalytics::SharpeRatio()`
on retained returns and gets a different number than the candidate
row's `sharpe_annualized`, the difference comes entirely from PA's own
annualization, scaling, or return-shape conventions -- not from ledgr
having two definitions of "the candidate's net return series." The v0.1.9.5
docs cycle absorbs the teaching obligation of explaining this divergence
to users.

### 4.7 Long tibble default; wide accessor as optional bridge

The default accessor returns a long-format tibble:

```
sweep_id | candidate_id | ts_utc | equity | return
```

(`sweep_id` may be `NA_character_` for unsaved ephemeral sweeps; see
Section 7.)

Long is dplyr- and ggplot-native, matching ledgr's existing public
surfaces. A wide accessor (or a `pivot = "wide"` argument) provides a
matrix-shaped bridge for PA and matrix-tooling consumers. The synthesis
binds whether wide is a separate function or a parameter.

---

## 5. Minimum API Surface

The proposed v1 surface is intentionally narrow.

### 5.1 Retention specification

```r
ledgr_sweep_retention(
  returns = c("none", "completed", "all")
)
```

A classed retention specification object analogous to
`ledgr_cost_chain()` from v0.1.9.1: small, identity-bearing,
inspectable. The argument names a single dimension in v1. Future modes
(per-instrument, per-trade, cost-component, downsampled equity, top-N
metric-based filtering) are deferred to their respective future RFCs.

Default is `returns = "none"`. The retention object is passed to
`ledgr_sweep()` and consumed by `ledgr_sweep_save()`.

### 5.2 Sweep with retention

```r
ledgr_sweep(
  exp,
  grid,
  ...,
  retain = ledgr_sweep_retention()    # default: returns = "none"
)
```

Existing arguments unchanged. The new `retain` argument has a default
that preserves today's scalar-only behavior.

### 5.3 Save and reopen

```r
ledgr_sweep_save(
  sweep,
  snapshot,
  sweep_id = NULL,
  note = NULL
)

ledgr_sweep_open(snapshot, sweep_id)
ledgr_sweep_list(snapshot)
ledgr_sweep_info(handle)   # or print method on the handle
close(handle)
```

`sweep_id = NULL` triggers auto-generation, matching the existing
`ledgr_run(run_id = NULL)` pattern. Auto-generated IDs use the same
naming convention runs use today.

`ledgr_sweep_save()` persists exactly what `ledgr_sweep()` retained: if
returns were retained, they are written; if not, only scalar summary
rows. No separate `persist = ` argument in v1.

`ledgr_sweep_open()` returns a handle that behaves like an in-session
`ledgr_sweep()` result for `dplyr::filter()`, `dplyr::arrange()`,
`ledgr_candidate()`, and printing. Sweep-class attributes (identity
hashes, retention metadata) survive dplyr operations so
`ledgr_candidate()` works on filtered handles.

### 5.4 Returns accessor

```r
ledgr_sweep_returns(
  x,
  candidates = NULL
)
```

`x` is an in-memory sweep or a reopened sweep handle. `candidates =
NULL` returns all retained candidate return series. `candidates` accepts
a character vector of `candidate_id` values that filters strictly by ID
(no metric, no ranking, no top-N).

Returns the long-format tibble described in Section 4.7. The wide form
is either a sibling function (`ledgr_sweep_returns_wide()`) or a
`pivot` argument on this accessor; the synthesis binds which.

When called on a sweep with `retain = ledgr_sweep_retention(returns =
"none")`, raises `ledgr_sweep_returns_unretained` with a message
pointing at the `retain` argument and the workflow alternatives.

When called with explicit `candidates` that include a failed candidate
ID, raises `ledgr_sweep_returns_candidate_not_completed` with the
failed candidate IDs named and a pointer to the sweep summary status
column.

### 5.5 Unchanged surfaces

`ledgr_candidate()` and `ledgr_promote()` are not modified. The existing
candidate-to-run workflow continues to operate on both in-memory sweeps
and reopened sweeps.

### 5.6 Surface count

Eight new exported functions plus one constructor:
- `ledgr_sweep_retention()` (constructor)
- `ledgr_sweep_save()`
- `ledgr_sweep_open()`
- `ledgr_sweep_list()`
- `ledgr_sweep_info()` (or print method only)
- `ledgr_sweep_returns()`
- `ledgr_sweep_returns_wide()` (or `pivot` argument on returns; bind in synthesis)
- print/close methods on the sweep handle class

Plus `retain` as a new argument on `ledgr_sweep()`.

This is the smallest surface that delivers the three workflows.

---

## 6. Failed Candidate Semantics

A sweep candidate can complete with metrics, complete with warnings, or
fail with errors. v1 binds:

- The sweep summary tibble continues to carry one row per candidate with
  `status` reflecting completion / warning / error.
- The retained return series is present only for candidates with
  `status == "completed"` (with or without warnings).
- Failed candidates have no retained return series at all. Not
  NA-padded, not zero-padded, not phantom-rowed. Absent.
- `ledgr_sweep_returns()` with no `candidates` filter returns rows for
  completed candidates only.
- `ledgr_sweep_returns()` with `candidates = c(...)` that includes
  failed candidate IDs raises `ledgr_sweep_returns_candidate_not_completed`.
- The accessor's docs explicitly point users at the sweep summary
  `status` column to filter completed candidates first if they want
  NA-padded behavior via `dplyr::left_join`.

This avoids the surface-creep risk of a `keep = "all"` mode that would
NA-pad failed candidates. Users who want that shape join the returns
tibble against the summary tibble themselves.

---

## 7. Identity And Reproducibility

### 7.1 Retention policy is orthogonal to execution identity

Running the same candidate twice with `retain = ledgr_sweep_retention(returns
= "none")` and `retain = ledgr_sweep_retention(returns = "all")` MUST
produce:

- identical `cost_model_hash`;
- identical `cost_plan_json`;
- identical `candidate_key`;
- identical `config_hash`;
- identical scalar metrics on the candidate row;
- identical execution seed;
- identical fold execution path.

The only difference is whether the return series is sitting in memory.

Retention policy MUST NOT enter any identity surface. It MUST NOT appear
in canonical JSON for config or candidate hashing. It is a side-channel
storage decision orthogonal to the execution contract.

This binding requires a parity test as a Minimum Scope item: same
candidate, two retention specs, byte-equivalent identity outputs.

### 7.2 Sweep-level identity

Saved sweeps carry a `sweep_id` (user-supplied or auto-generated) that
is the durable lookup key. The sweep_id is not derived from the grid or
the candidates; collisions are detected at save time.

Open question for spec-cut: on `sweep_id` collision, does
`ledgr_sweep_save()` raise a classed error (`ledgr_sweep_id_exists`),
overwrite silently, or append a suffix? See Section 12.

### 7.3 Reopen parity

A sweep saved with `returns = "all"` and reopened with
`ledgr_sweep_open()` must produce:

- identical sweep summary rows under canonical ordering and existing
  accounting tolerances;
- identical retained return series (same byte representation modulo
  storage tolerances and canonical ordering);
- identical sweep-level identity attributes.

Reproducibility is a binding contract, not a best-effort claim.

---

## 8. Cross-Sweep And Ephemeral ID Handling

### 8.1 sweep_id column in retained returns

The returns tibble carries a `sweep_id` column to disambiguate when
users stack returns across multiple sweeps:

```r
returns_q1 <- ledgr_sweep_returns(ledgr_sweep_open(snap, "sma-grid-q1"))
returns_q2 <- ledgr_sweep_returns(ledgr_sweep_open(snap, "sma-grid-q2"))
all_returns <- dplyr::bind_rows(returns_q1, returns_q2)
# candidate_id may collide across q1 and q2; sweep_id keeps them distinct
```

### 8.2 Ephemeral sweeps

An in-memory sweep that has never been saved has no durable sweep_id.
v1 binds: the `sweep_id` column for ephemeral sweeps is
`NA_character_`. On save, the column is populated to match the assigned
sweep_id; if a user retrieved returns before save, the previously-NA
values do not retroactively update (they reflect the state at the time
of accessor call).

Alternative considered and rejected: ephemeral sweeps get a
session-local UUID. This adds identity surface for a small ergonomic
gain; users who want stable IDs across the session can call
`ledgr_sweep_save()` once and they have one.

---

## 9. Walk-Forward Forward Obligation

The walk-forward synthesis (Section 12) defers "richer diagnostic
retention tiers (per-candidate per-fold return series, equity payload
references, sufficient statistics, partition/path identity,
family/effective-trial metadata)" to a future RFC. v0.1.9.4 walk-forward
ships its v1 with the scalar score matrix only.

v0.1.9.2 sweep persistence MAY become a substrate that walk-forward
consumes for per-fold return-series retention, but the seed binds
explicitly that **v0.1.9.2 does not bind walk-forward integration**.
Three reasons:

1. Walk-forward has identity dimensions v0.1.9.2 does not have:
   `fold_seq`, train vs test window split, fold-list identity.
   Whether the v0.1.9.2 returns shape extends naturally to per-fold or
   requires a richer shape is for the walk-forward §12 RFC to answer.
2. Pulling walk-forward integration into v0.1.9.2's scope balloons the
   packet. The discipline learned from the v0.1.8.11 -> v0.1.9.1 flow
   says: solve the immediate substrate cleanly; route forward
   integration to its own RFC.
3. The v0.1.9.4 walk-forward synthesis already has Section 12 Future
   Obligations as the home for this question. v0.1.9.2 should not
   pre-empt that scope.

What v0.1.9.2 MUST do for walk-forward: design the retention shape so
that it does not foreclose walk-forward's per-fold extension. The
retention spec is a classed constructor whose argument set can grow
(e.g., adding a `folds` retention dimension in v0.1.9.4's Amendment 3
without breaking v0.1.9.2's surface). The returns tibble can gain a
`fold_seq` column later as an additive change. The architectural intent
is "v0.1.9.2 returns shape is an instance of a more general candidate ×
[optional dimensions] × time-series shape" without binding the
generalization.

---

## 10. Alpha Decay Three-Layer Routing

The discussion that produced this seed identified that "alpha decay
analysis" is not one feature; it is three distinct analytical layers
that competitor frameworks ship separately. v0.1.9.2 addresses one of
them, and the seed routes the other two explicitly to future RFCs
rather than pretending v0.1.9.2 is solving them all.

### 10.1 Strategy return decay (addressed by v0.1.9.2)

Question: is the strategy's net return path stable across regimes,
windows, and snapshots? Substrate: net portfolio return series over time.
Tools: rolling Sharpe, regime decomposition, rolling alpha/beta against
benchmark, distributional analysis. Comparable surfaces: PA's
`Return.rolling`, `chart.RollingPerformance`, `chart.RollingRegression`;
pyfolio's tear-sheets.

v0.1.9.2's retained net returns are the substrate for this layer. PA,
`pbo`, custom bootstrap, and DSR computations all operate on this
series.

### 10.2 Signal decay (deferred)

Question: does the underlying feature or factor still predict future
returns? Substrate: feature values + forward returns, by quantile,
turnover, IC. Comparable surfaces: Alphalens, QuantRocket's factor
analysis.

This requires ledgr's feature engine to expose forward-return
computation against feature values, IC analysis, quantile returns, and
factor rank autocorrelation. None of that exists today. It requires a
feature-engine extension and is its own substantial RFC.

Future obligation: signal-decay substrate RFC, target window v0.2.x.

### 10.3 Implementation / cost decay (deferred)

Question: is execution friction growing? Substrate: gross vs net
decomposition, per-trade cost attribution, per-instrument breakdown.
Comparable surfaces: blotter's gross-vs-net P&L tracking, QuantConnect's
live execution analytics.

This requires binding the "gross return" definition (multiple
non-equivalent candidates: same-timing-zero-cost, reference-price-pre-spread,
fill-price-minus-fee, counterfactual-zero-cost rerun, post-target-risk
desired-vs-feasible). The cost-API v0.1.9.1 did not bind a reference
price concept. Adding gross tracking is an execution / evidence contract
change, not a persistence column. It requires extending `fill_intent` to
carry `reference_price` alongside `fill_price` and `fee`, propagating
through accounting events, and binding semantic equivalence under
v0.1.9.3 target-risk and future liquidity policies.

Future obligation: execution-attribution / cost-decay substrate RFC,
target window v0.2.x.

### 10.4 Why this routing matters

The competitor pattern (every framework ships one layer, gestures at
others) suggests forcing all three into one RFC is more confusing than
the natural split. ledgr's structural advantage -- shared identity
surfaces, snapshot semantics, event sourcing -- means each layer can be
delivered as a clean tier rather than as a leaky abstraction. But the
delivery happens across multiple RFCs in their own windows, not as
v0.1.9.2 scope creep.

---

## 11. Minimum Scope For v1

The v0.1.9.1 packet is the model: smallest defensible surface, explicit
deferrals, parity tests on the identity binding, NEWS-level breaking
changes named explicitly.

v0.1.9.2 Minimum Scope:

1. `ledgr_sweep_retention()` constructor with `returns` argument
   accepting `"none"` / `"completed"` / `"all"` (synthesis binds the
   exact enum).
2. `retain` argument on `ledgr_sweep()`, default
   `ledgr_sweep_retention()` (which itself defaults to `returns = "none"`).
3. `ledgr_sweep_save()` / `ledgr_sweep_open()` / `ledgr_sweep_list()` /
   `ledgr_sweep_info()` (or print method) on the sweep handle.
4. `ledgr_sweep_returns()` accessor with `candidates` ID filter.
5. Wide-format accessor (`ledgr_sweep_returns_wide()` or pivot arg);
   synthesis binds which.
6. Classed conditions: `ledgr_sweep_returns_unretained`,
   `ledgr_sweep_returns_candidate_not_completed`, `ledgr_sweep_id_exists`
   (if collision is the bound spec-cut decision; see Section 12).
7. Cost identity (`cost_model_hash`, `cost_plan_json`) propagated to
   persisted candidates per the v0.1.9.1 forward obligation.
8. Determinism tests:
   - Retention parity (Section 7.1): identical execution outputs across
     retention specs.
   - Reopen parity (Section 7.3): identical reopen data under canonical
     ordering and accounting tolerances.
   - Canonical-series parity (Section 4.6): retained returns equal to
     `ledgr_results(promoted, "equity")` derived returns.
   - Failed-candidate absence test.
9. Documentation:
   - Sweep vignette section on the three workflows.
   - Sweep vignette section on the three-tier evidence framing.
   - Sweep vignette section explicitly naming the deferred alpha-decay
     layers and routing each to its future RFC.
   - `?ledgr_sweep_retention` and accessor help pages with runnable
     examples.
   - NEWS entry naming the new surface as additive (no breakage on
     existing scalar-only sweep semantics).
10. Tests: classed-error coverage for all three new conditions;
    identity-parity test fixtures; PA-compatibility round-trip
    (compute Sharpe via ledgr's metric kernel and via PA on retained
    returns, document the expected divergence pattern).

---

## 12. Open Questions Promoted To Spec-Cut

These are decisions the spec-cut writer binds when tickets are cut.
They are not RFC work for this cycle.

### Q1: `sweep_id` collision behavior

When `ledgr_sweep_save()` is called with a `sweep_id` that already
exists in the snapshot's store, behavior options:

- (a) Reject with `ledgr_sweep_id_exists` classed error; user must pass
  a different ID or explicit `overwrite = TRUE` (which would itself be
  spec-cut scope).
- (b) Overwrite silently; matches some R-data-saving conventions but
  loses prior provenance.
- (c) Append a suffix (`sma-grid-q1` -> `sma-grid-q1-2`); preserves both
  but introduces an unpredictable ID.

Recommendation: (a). Matches the cost-API §13 aggressive-rejection
posture and forces explicit decisions.

### Q2: Wide returns accessor shape

Two surface options for the wide-format bridge:

- (a) Separate function `ledgr_sweep_returns_wide()`.
- (b) `pivot = c("long", "wide")` argument on `ledgr_sweep_returns()`.

Recommendation: (a). Symmetric with how ledgr surfaces are typically
discovered (one function, one shape), and avoids passing presentation
arguments through an identity-bearing accessor.

### Q3: Default value of `ledgr_sweep_retention()` constructor

Either:

- (a) `returns = "none"` is the default; users must opt in to retain.
- (b) `returns = "completed"` is the default; opt out for cheap mode.

Recommendation: (a). Matches the cost-API §13 explicit-required posture
and keeps the default cheap. Opt-in for the heavier surface is consistent
with "no hidden hardcoded behavior is allowed" from walk-forward
synthesis Section 3.

### Q4: `note` argument shape

Free-text character string vs structured (named list with
maintainer / hypothesis / etc.)?

Recommendation: free-text character scalar in v1. Structured notes are
an obvious future obligation that would benefit from auditr evidence
about what users actually want to capture.

### Q5: `retain` and `ledgr_sweep_save()` interaction edge cases

If a user passes a fresh retention spec to save (different from the
sweep's retention), what happens?

Options:

- (a) Save errors with a clear message: "retention spec mismatch between
  sweep and save."
- (b) Save uses the sweep's retention spec; the save arg (if any) is
  ignored or rejected as unused.
- (c) Save admits a `persist = ` arg that narrows what's written.

Recommendation: v1 does not admit a `persist = ` arg on save (Section
2). Save uses the sweep's retention spec. If users want save-narrower,
they re-sweep with narrower retention. The decision is recorded as a
future obligation if real demand surfaces.

---

## 13. Future Obligations Recorded

These are concerns that require separate RFC cycles in later roadmap
windows. They are not v0.1.9.2 work.

### F1: Walk-forward per-fold per-candidate return-series retention

The v0.1.9.4 walk-forward packet (Amendment 3 candidate) consumes
v0.1.9.2's retention substrate but may extend the shape with `fold_seq`
and train-vs-test window dimensions. v0.1.9.2 should not foreclose this
extension; the walk-forward §12 RFC is the binding home for the
extension itself.

### F2: Signal decay substrate (Alphalens-equivalent)

Feature-engine extension for forward-return computation, IC analysis,
quantile returns, factor rank autocorrelation. Target window v0.2.x.

### F3: Execution / cost-decay substrate (gross vs net)

Reference-price tracking in `fill_intent`; cost-component attribution
in accounting events; binding the gross-return definition under
target-risk and future liquidity policy. Target window v0.2.x. Must
coordinate with v0.1.9.3 target-risk and the eventual liquidity-policy
RFC.

### F4: Selection-integrity diagnostics method library

DSR, PBO, CSCV, CPCV, bootstrap CIs, robustness slicing as ledgr-owned
helpers operating on the v0.1.9.2 retained series. Currently routed to
external libraries (PA, `pbo` package, custom code). Target window
v0.1.9.x slot per roadmap.

### F5: PerformanceAnalytics adapter

Output adapter over ledgr's stable result tables (equity, fills,
trades). Already roadmapped at v0.2.x; the v0.1.9.2 retention shape
must be compatible with PA's expected input shape (return series, xts
or matrix) but the adapter itself is out of scope.

### F6: Per-instrument and per-trade retention

For implementation-decay analysis and per-instrument alpha
attribution. Requires storage tier decisions (compression,
downsampling, lazy loading) and identity questions (per-instrument
equity hash). Target window v0.2.x diagnostic-retention RFC.

### F7: Cross-sweep comparison helpers

`ledgr_sweep_diff()`, named cross-sweep stacking, sweep-of-sweeps
analysis. Defer until auditr surfaces a real workflow that dplyr
cannot cleanly serve.

### F8: Sweep extension / iterative grid append

Add candidates to an existing saved sweep without rerunning. Identity
questions (is the same candidate id semantically identical in the
original sweep and the extension?) make this nontrivial. Defer.

### F9: Structured `note` shape

If auditr surfaces consistent structure in how users use the v1
free-text note, a future RFC can bind a typed note schema (hypothesis,
maintainer, related-sweep, etc.).

### F10: `persist = ` narrower than `retain = ` on save

If real demand surfaces for "validate in session, save cheap," admit a
`persist` argument on `ledgr_sweep_save()`. Defer until demand is
proven.

---

## 14. Comparable Surfaces In Other Frameworks

This research input is captured here rather than as a separate research
artifact because it is short and the synthesis will need to cite it.

### QuantConnect / LEAN

Optimization results show a candidate table, parameter charts, and
individual backtest equity per candidate. Each candidate is a full
backtest stored separately; users can open any one. Cost: heavy storage,
heavy compute (full backtest per candidate). Source:
`https://www.quantconnect.com/docs/v2/cloud-platform/optimization/results`.

### Backtrader

Single-run-oriented. `cerebro.plot()` for individual backtests,
analyzers (`Analyzer`, `PyFolio`) for derived stats. Sweep results
require user assembly. Source:
`https://www.backtrader.com/docu/analyzers/analyzers/`.

### vectorbt

Vectorized; sweep results are pandas DataFrames where columns are
parameter combinations. Plotting many candidates is natural because
the data is already columnar. Different paradigm from ledgr's
event-driven model. Source: `https://vectorbt.dev/api/portfolio/base/`.

### quantstrat / blotter

`apply.paramset()` returns parameter-combination results with knobs
(`verbose`, `audit`) that control how much per-combination
portfolio / orderbook state is preserved. Closest R analogue to what
v0.1.9.2 is solving. Source:
`https://rdrr.io/rforge/quantstrat/man/apply.paramset.html`.

### PerformanceAnalytics

Operates on return series. Provides `SharpeRatio`,
`maxDrawdown`, `chart.RollingPerformance`,
`chart.RollingRegression`, `table.Stats`. Does not handle
signal-level or implementation-level decay. Source:
`https://www.rdocumentation.org/packages/PerformanceAnalytics/`.

### Alphalens / QuantRocket

Factor / signal layer: forward returns by quantile, IC, turnover,
factor rank autocorrelation. Explicitly says it does not cover
transaction costs, capacity, or portfolio construction. Source:
`https://alphalens.ml4trading.io/notebooks/overview.html`.

### Key pattern

No competitor unifies all three alpha-decay layers. Each ships one
substrate cleanly and gestures at the others. v0.1.9.2 ships Tier 2
(strategy return decay) at the same standard.

---

## 15. Acceptance Criteria For This RFC Cycle

The synthesis is ready to accept when:

- The seven semantic decisions in Section 4 are bound, with parity
  tests named as Minimum Scope.
- The API surface in Section 5 is bound (function set, retention
  constructor shape, classed-condition names).
- The Section 12 open questions are resolved at spec-cut time, not
  RFC-bound here.
- The Section 13 future obligations are named and routed to their
  destination RFCs / windows; none of them are silently absorbed into
  v0.1.9.2 scope.
- The three-layer alpha-decay routing in Section 10 is explicit in the
  sweep vignette obligation, and the synthesis records that v0.1.9.5
  docs cycle will absorb the teaching of why scalar-Sharpe and
  PA-Sharpe may differ.
- Walk-forward forward obligation in Section 9 is preserved without
  binding integration: the synthesis does not pre-empt the walk-forward
  §12 RFC's design space.
- Identity orthogonality (Section 7.1) is bound as a Minimum Scope
  test fixture, not just prose.

The synthesis is ready to escalate to maintainer decisions if:

- The response stage surfaces a fundamental disagreement on what "net
  portfolio return series" means (Section 4 decisions);
- The response stage surfaces a workflow that the eight-function
  surface cannot serve and that an external library cannot fill;
- The response stage proposes pulling walk-forward integration into
  v0.1.9.2's scope and the maintainer needs to confirm the routing.

---

## 16. Notes For The Response Stage

This seed deliberately:

- Binds semantic shape before API decoration. The "what is the retained
  series" question is the load-bearing work; the API is downstream.
- Avoids walk-forward bindings. Walk-forward integration is a future
  obligation, not a v0.1.9.2 deliverable.
- Routes alpha-decay layers explicitly. Three layers, three future
  RFCs, one substrate in v0.1.9.2.
- Keeps the API surface minimum (eight functions). Codex's adversarial
  read of the planning thread tightened this from a larger sketch; the
  seed honors that tightening.
- Explicitly defers `top_n` retention, `persist = ` on save, NA-padded
  failed-candidate semantics, and `keep = "all"` accessor modes. Each
  was considered and routed to a future obligation or a spec-cut
  question rather than pulled into v1.

What the response stage should attack:

- Whether the seven semantic decisions in Section 4 are right.
  Especially: is the canonical-series parity (Section 4.6) achievable
  without engine changes? If not, what does retention identity mean?
- Whether the identity orthogonality binding (Section 7.1) is
  achievable. Does the existing canonical config JSON exclude the
  retention spec naturally, or does it need an explicit
  config-hash-payload exclusion analogous to how store-path and
  alias_map_order were excluded in v0.1.9.1?
- Whether the eight-function surface has a load-bearing gap. The
  workflow review captured five workflows; if a sixth surfaces that
  the surface cannot serve, the surface needs expansion or the workflow
  needs explicit deferral.
- Whether the walk-forward forward-obligation framing in Section 9
  forecloses any walk-forward §12 RFC design space. If yes, the
  binding needs to relax.
- Whether the alpha-decay three-layer routing in Section 10 misses a
  fourth layer (e.g., capacity decay, regime decay, sizing decay) that
  competitors handle separately.

What the response stage should not attack:

- The retention-vs-persistence split. This is bound architectural
  insight, not a v1 spec-cut question.
- The decision to defer signal-decay and implementation-decay
  substrates to separate future RFCs. Routing is the right
  architectural posture per competitor research.
- The decision to keep ranking, selection, and statistical methods
  out of v0.1.9.2 surface. These belong in their own future RFCs.

This seed expects a substantial response. The Section 4 semantic
bindings and the Section 7 identity orthogonality binding are the
two surfaces most worth adversarial pressure.
