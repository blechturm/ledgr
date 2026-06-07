# RFC Seed v2: Sweep Artifact Persistence For ledgr

**Status:** RFC seed v2 -- incorporates response-stage findings. Planning
input for the v0.1.9.2 packet, not accepted.
**Author:** Claude, incorporating Codex response.
**Date:** 2026-06-06
**Supersedes:** `inst/design/rfc/rfc_sweep_artifact_persistence_v0_1_9_x_seed.md`.
**Response incorporated:** `inst/design/rfc/rfc_sweep_artifact_persistence_v0_1_9_x_response.md`.
**Target window:** v0.1.9.2.
**Primary research input:** maintainer discussion threads 2026-06-05 and
2026-06-06; competitor research embedded in seed v1 Section 14.
**Constrained by:**
- `inst/design/contracts.md`
- `inst/design/ledgr_roadmap.md` (v0.1.9.x Line Sequencing preamble; v0.1.9.2 Sweep Artifact Persistence section; v0.2.x benchmark-context line at 1775-1781)
- `inst/design/horizon.md`
- `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md` (Section 6 cost identity; Section 14:560 forward obligation; Section 434 cost-component retention deferral)
- `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md` (Section 10 Minimum Scope; Section 12 Future Obligations on richer diagnostic retention)

> **v1 naming convention.** This RFC uses "v1" as shorthand for "the first
> implementation of sweep artifact persistence in ledgr." ledgr's roadmap
> does not have a sweep-persistence v1 milestone; v1 here means the
> v0.1.9.2 ticket-cut. Post-v1 work lives in named follow-up RFCs at their
> own roadmap windows.

---

## 0. Revision Notes vs Seed v1

Seed v2 incorporates five amendments from Codex's response and one
narrowing from the response's Section 4. The seed v1 product shape,
non-scope boundaries, three-tier framing, and retention-vs-persistence
distinction are preserved unchanged.

### A1. Final-bar no-fill no longer truncates retained equity (was Section 4.5)

Seed v1 said retained equity "ends at the last bar that did fill" under
`LEDGR_LAST_BAR_NO_FILL`. Verified against `R/fold-engine.R:208-216`
(equity fact recorded before fill resolution) and
`R/backtest-runner.R:1428-1453` (durable equity built across every
`pulses_posix` entry): the equity row at the final scoring pulse exists
regardless of whether the next-open fill resolves. The warning is about
the missing fill, not a missing equity row. Section 5.5 in v2 binds the
correct shape: retention preserves the final equity row; the warning
travels in the candidate summary row.

### A2. Equity/return row alignment now explicit (was Sections 4.1, 4.4, 4.6, 4.7)

Seed v1 jointly implied a long table carrying both equity and return
without binding alignment. Verified against `R/backtest.R:1421-1430`
(`compute_period_returns()` returns `nrow(equity) - 1` adjacent-diff
values consumed at `R/backtest.R:1608`): returns are one shorter than
equity. Section 5.1 in v2 binds: one row per scoring pulse; `equity` is
portfolio equity at that timestamp; `return` is the period return
ending at that timestamp; the first row has `return = NA_real_`; parity
tests drop the first NA before comparing to `ledgr_compute_metrics()`.

### A3. Canonical-series parity sourced from the same summary path (was Section 4.6)

Seed v1 called for "byte-equivalent" parity without naming which
internal summary path is the retention source. Two paths exist today:
the inline-memory handler (`R/sweep.R:956-957`, `R/sweep.R:1341-1378`)
and the ordered-event reconstructor
(`R/sweep.R:967`, `R/fold-reconstruction.R:140-145`). Section 5.6 in v2
binds: retention is sourced from the same per-candidate summary object
the scalar metrics consume; no third path. Section 12.4 in v2 names the
fixture matrix that exercises both summary paths under both
`compiled_accounting_model` settings.

### A4. Retention identity excluded by construction (was Section 7.1)

Seed v1 said retention policy must not enter identity. Verified against
`R/config-hash.R:5-28` (the exclusion list does not contain retention)
and `R/sweep.R:232-240` (`execution_assumptions` is identity-bearing
and is the natural place a careless implementer would attach retention
metadata). Section 8.1 in v2 binds a two-layer enforcement: retention
metadata is stored on a separate side-channel attribute distinct from
`execution_assumptions`, AND `config_hash_payload()` explicitly excludes
retention metadata as defense in depth. Section 12.5 in v2 names the
identity-orthogonality test fixture.

### A5. Retention enum collapsed to `c("none", "completed")` (was Section 5.1)

Seed v1 proposed `returns = c("none", "completed", "all")`. Verified
against the FAILED/DONE status distinction at `R/sweep.R:290-291,
1451, 1487`: failed candidates have no retention by Section 7 contract,
so `"all"` either collapses to `"completed"` or requires NA-padded
failed rows the seed explicitly rejects. Section 6.1 in v2 binds the
enum to `c("none", "completed")`. The third value is removed; broader
modes (per-instrument, per-trade, cost-component) remain deferred to
their respective future RFCs without a misleading enum slot.

### A6. Strategy return decay narrowed to single-stream diagnostics (was Section 10.1)

Seed v1's Section 10.1 listed "rolling alpha/beta against benchmark" as
a v0.1.9.2 capability. Benchmark substrate is roadmapped at v0.2.x
(`inst/design/ledgr_roadmap.md:1775-1781`); ledgr does not yet have
aligned benchmark/reference returns or active-metric machinery.
Section 11.1 in v2 narrows the claim: v0.1.9.2 enables single-stream
strategy return decay (rolling Sharpe, rolling volatility, regime
decomposition, distributional shape, drawdown statistics). Section
14.F11 in v2 records benchmark-relative decay (rolling alpha, beta,
information ratio, active return decomposition) as a future obligation
tied to the v0.2.x benchmark-context RFC.

---

## 1. Scope And Non-Scope

This seed v2 addresses the first public sweep artifact persistence API.

The unresolved question is:

```text
How should users save sweep results durably, reopen them later, retain
enough evidence to do honest single-stream statistical validation
before committing to promotion, and do all of that without ledgr
inventing a ranking-rule system, a diagnostic-retention platform, a
statistical-method library, or a benchmark-context substrate?
```

### Scope

- Saving sweep results to the same DuckDB store that holds runs.
- Reopening saved sweeps as objects that behave like in-session
  `ledgr_sweep()` results.
- Listing and inspecting saved sweeps.
- An explicit retention knob with values `c("none", "completed")` that
  controls whether the in-memory sweep result carries net portfolio
  equity / returns per completed candidate.
- Retaining net portfolio equity and returns per completed candidate
  when the user opts in, with explicit semantic bindings on what "net
  portfolio equity" and "net portfolio returns" mean (Section 5).
- Surfacing the retained returns through an accessor that does not
  invent ranking, selection, or comparison machinery.

### Non-scope for v1

- Full ledger, fill, trade, or per-instrument retention for any
  candidate by default. Those remain accessible only after promotion.
- Cost-component attribution, per-trade cost decomposition, or
  spread / fee component time series. Cost identity (`cost_model_hash`,
  `cost_plan_json`) lives on candidate rows per the cost-API §14:560
  forward obligation; component decomposition is routed to the
  cost-API's component-retention future obligation
  (synthesis Section 434).
- Gross-vs-net portfolio return decomposition.
- Signal decay / factor IC analysis.
- Benchmark-relative diagnostics (rolling alpha, beta, information
  ratio, active return, active risk, tracking error). These require
  benchmark-context substrate roadmapped at v0.2.x. See Section 14.F11.
- Statistical-method helpers (DSR, PBO, CSCV, bootstrap, robustness
  slicing).
- PerformanceAnalytics or pyfolio adapter.
- Ranking-rule machinery, named selection views, retention modes that
  bake metric-based selection into persistence (no `top_n` retention,
  no "save the interesting rows" semantics).
- Cross-sweep comparison helpers, sweep-diff utilities, sweep extension
  or append semantics.
- Walk-forward per-fold per-candidate return-series retention.
- Automatic winner selection of any kind. Promotion remains explicit.
- Weakening of `ledgr_promote()`, `ledgr_candidate()`, or
  `run_promotion_context`.

The seed assumes ledgr remains pre-CRAN with no external users.
Storage schemas and saved-artifact compatibility may break across
cycles per the horizon's 2026-05-25 pre-CRAN compatibility policy.

---

## 2. Current Code And Contract Baseline

`ledgr_sweep()` is documented in `R/sweep.R`. The result is a classed
tibble (`ledgr_sweep_results`) with attributes for `cost_model_hash`,
`cost_plan_json`, `execution_assumptions`, `metric_context`,
`metric_context_hash`, `metric_context_version`, and execution-mode
metadata. See `R/sweep.R:220-243`. Each row carries identity
sufficient for `ledgr_candidate()` extraction and `ledgr_promote()`
commitment.

What ends with the R session today: the in-memory result, all
candidate scalar metrics, all warnings, all identity attributes, all
underlying data ledgr computed during fold execution. What survives:
nothing. The next `ledgr_sweep()` call re-runs all candidates.

Cost identity from v0.1.9.1 is already on sweep result rows
(`R/sweep.R:230-231`, `R/sweep.R:711-712`, `R/sweep.R:737-738`,
`R/sweep.R:995-996`). v0.1.9.2 inherits this and persists it per the
cost-API §14:560 forward obligation.

Existing surfaces v0.1.9.2 does NOT change:
- `ledgr_sweep()` signature and return shape, except for the addition
  of a `retain` argument with a default that preserves current
  behavior;
- `ledgr_candidate()` extraction;
- `ledgr_promote()` commitment;
- `ledgr_run_open()`, `ledgr_run_info()`, `ledgr_run_list()`;
- the fold core, cost resolver, identity surfaces from v0.1.9.1.

---

## 3. The Load-Bearing Architectural Distinction

> **Retention and persistence are orthogonal concerns. Retention
> controls what the in-memory sweep result object carries; persistence
> controls what gets written to durable storage.**

A user may want returns retained in memory for in-session validation
without writing them to DuckDB. A different user may want the same
returns written durably for later reopening. A third user may want
scalar-only retention and scalar-only persistence (the cheap default).
The three workflows compose freely once retention and persistence are
separated:

```r
# Workflow A: fast screening, scalar-only
sweep <- ledgr_sweep(exp, grid)
ranked <- sweep |> dplyr::arrange(dplyr::desc(sharpe_annualized))

# Workflow B: in-session statistical validation, no durable storage
sweep <- ledgr_sweep(exp, grid,
  retain = ledgr_sweep_retention(returns = "completed"))
returns <- ledgr_sweep_returns(sweep)

# Workflow C: durable validation, returns persisted with the sweep
sweep <- ledgr_sweep(exp, grid,
  retain = ledgr_sweep_retention(returns = "completed"))
ledgr_sweep_save(sweep, snapshot = snap, sweep_id = "sma-grid-q1")
record <- ledgr_sweep_open(snap, "sma-grid-q1")
returns <- ledgr_sweep_returns(record)
```

The same retention specification flows through both the in-memory
object and (optionally) durable storage. v1 binds the simplest
contract: save persists exactly what was retained.
Narrower-persistence-than-retention is a future obligation if real
demand surfaces.

---

## 4. Three-Tier Evidence Framing

Sweep persistence does not solve every analytical question. It solves
one layer of a three-layer framing:

| Tier | Data | Question it answers | Lives in |
| --- | --- | --- | --- |
| 1 | Scalar metrics per candidate | "which candidates merit further inspection?" | sweep result row (today; persisted in v0.1.9.2) |
| 2 | Net portfolio equity / returns per completed candidate | "which candidates survive single-stream distributional analysis?" | retained in memory and optionally persisted (new in v0.1.9.2) |
| 3 | Full event-sourced ledger, fills, trades, per-instrument equity | "what is the complete record of this strategy's behavior?" | promoted run (today; unchanged by v0.1.9.2) |

Tier 1 enables coarse screening via dplyr. Tier 2 enables single-stream
distributional analysis via external tools (PerformanceAnalytics, the
`pbo` package, custom bootstrap and DSR computations) operating on
strategy-return-only data. Tier 3 enables the full audit-trail surface
and post-hoc decomposition.

Tier 2 explicitly does not enable benchmark-relative analysis (alpha,
beta, active return, information ratio); that requires aligned
benchmark / reference return series, which are scoped to a v0.2.x
benchmark-context RFC.

ledgr's potential differentiator is that the same fold core produces
all three tiers consistently, with shared identity surfaces. v0.1.9.2
ships Tier 2 explicitly while preserving cross-tier identity
coherence.

---

## 5. Bound Semantic Shape: The Retained Series

The load-bearing semantic decisions for what "net portfolio equity /
returns per completed candidate" mean. These are contracts every
downstream consumer (PA users, future walk-forward integration, the
diagnostic-retention substrate) depends on.

### 5.1 Equity and return aligned to scoring pulses

The retained artifact is a long-format tibble keyed by
`(sweep_id, candidate_id, ts_utc)` with two value columns:

```
sweep_id | candidate_id | ts_utc | equity | return
```

- One row per scoring pulse for each completed candidate.
- `equity` is the portfolio equity at `ts_utc` (cash + positions value
  + realized PnL settled, in the same units `ledgr_results(run,
  "equity")$equity` returns).
- `return` is the period return ending at `ts_utc`, computed as
  `(equity[i] / equity[i-1]) - 1` for `i >= 2`.
- The first row for each candidate has `return = NA_real_` because no
  prior equity exists.
- Parity tests against `ledgr_compute_metrics()` drop the leading
  `NA_real_` before comparing return-derived scalars.

This matches the canonical convention in `compute_period_returns()` at
`R/backtest.R:1421-1430`: returns are one shorter than equity, computed
by adjacent-row diff. v0.1.9.2 makes the leading boundary explicit by
emitting `NA_real_` rather than dropping the row, so equity and return
share a row index per pulse without alignment ambiguity.

### 5.2 Net of transaction costs

Costs are applied at the cost resolver per the v0.1.9.1 cost-API
contract. The retained series reflects post-cost portfolio equity:
fill_price is post-spread, fee is deducted from cash, all accounting
events flow through with costs applied. This is the same definition
`ledgr_results()` returns on promoted runs.

Gross-equivalent alternatives (reference price before spread,
fee-removed, counterfactual zero-cost) are out of scope and routed to
a separate execution-attribution RFC.

### 5.3 Scoring pulses only; no warmup

Warmup pulses have no positions taken and meaningless portfolio equity
(`equity = initial_cash` by construction). Retention covers only the
scoring window. This matches the existing scoring contract.

### 5.4 Include initial scoring-pulse row

The first retained row for each completed candidate is the equity
state at the snapshot's first scoring timestamp, with `return =
NA_real_`. This is consistent with `ledgr_results(run, "equity")`
shape and matches the canonical scoring-window boundary.

### 5.5 Final-bar no-fill preserves the final equity row

If a candidate emits `LEDGR_LAST_BAR_NO_FILL`, retention does NOT
truncate. The fold writes an equity fact at the top of every scoring
pulse before fill resolution (`R/fold-engine.R:208-216`); the durable
reconstructor builds equity across every pulse in `pulses_posix`
(`R/backtest-runner.R:1428-1453`). The warning relates to fill
emission, not equity emission. The final equity row exists; the
candidate's summary row carries the warning.

This was the seed v1 §4.5 wording error. v2 binds the correct
shape:

> Retained equity covers the same scoring-pulse timestamps as the
> public equity curve, including the final scoring pulse, regardless of
> whether the candidate emitted `LEDGR_LAST_BAR_NO_FILL`. The warning
> travels with the candidate summary row, not with the equity series.

### 5.6 Canonical-series parity sourced from one summary path

The retained series is sourced from the same per-candidate summary
object that produces the scalar metrics on the candidate row. There is
no third path.

Today two summary paths exist (Codex F3, verified):

- inline-memory handler: builds equity from recorded equity facts
  (`R/sweep.R:956-957`, `R/sweep.R:1341-1378`).
- ordered-event reconstructor: builds equity from typed or generic
  events plus `pulses_posix` (`R/sweep.R:967`,
  `R/fold-reconstruction.R:140-145`).

v0.1.9.2 retention plumbs whichever summary object the candidate used.
The retention does not recompute the series via a third path. The
parity contract is:

> For a given candidate run, the retained equity / return series is
> byte-equivalent (under canonical ordering and existing accounting
> tolerances) to the series the scalar metrics on the same candidate
> row were computed from.

Section 12.4 names the fixture matrix that exercises both paths under
both `compiled_accounting_model` settings.

### 5.7 Long tibble default; wide accessor as separate function

The default accessor returns the long-format tibble described in
Section 5.1. A wide accessor (`ledgr_sweep_returns_wide()`) provides a
matrix-shaped bridge for PA and matrix-tooling consumers.

Q2 in Section 13 records this as a spec-cut question with the
recommended binding "separate function, not `pivot` argument," matching
Codex's response Section 3.

---

## 6. Minimum API Surface

### 6.1 Retention specification

```r
ledgr_sweep_retention(
  returns = c("none", "completed")
)
```

A classed retention specification object analogous to
`ledgr_cost_chain()` from v0.1.9.1: small, identity-bearing,
inspectable. The argument names a single dimension in v1; the enum has
exactly two values.

Default is `returns = "none"`. The retention object is passed to
`ledgr_sweep()` and consumed by `ledgr_sweep_save()`.

The seed v1 third enum value (`"all"`) was removed (Codex F5). It was
not distinguishable from `"completed"` given the Section 7 contract
that failed candidates have no retained rows. Broader retention modes
(per-instrument, per-trade, cost-component, downsampled equity,
metric-based filtering) remain deferred to their respective future
RFCs without a misleading enum slot.

### 6.2 Sweep with retention

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

### 6.3 Save and reopen

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
`ledgr_run(run_id = NULL)` pattern.

`ledgr_sweep_save()` persists exactly what `ledgr_sweep()` retained:
if returns were retained, they are written; if not, only scalar
summary rows. No separate `persist =` argument in v1.

`ledgr_sweep_open()` returns a handle that behaves like an in-session
`ledgr_sweep()` result for `dplyr::filter()`, `dplyr::arrange()`,
`ledgr_candidate()`, and printing. Sweep-class attributes (identity
hashes, retention metadata) survive dplyr operations so
`ledgr_candidate()` works on filtered handles.

### 6.4 Returns accessor

```r
ledgr_sweep_returns(
  x,
  candidates = NULL
)

ledgr_sweep_returns_wide(
  x,
  candidates = NULL
)
```

`x` is an in-memory sweep or a reopened sweep handle. `candidates =
NULL` returns all retained candidate return series. `candidates`
accepts a character vector of `candidate_id` values that filters
strictly by ID (no metric, no ranking, no top-N).

Long shape per Section 5.1: `sweep_id | candidate_id | ts_utc | equity
| return`. Wide shape: candidates as columns, `ts_utc` as the row
index, one wide tibble per value column (equity or returns -- the
synthesis binds which is the primary wide return shape and whether
both are exposed).

When called on a sweep with `retain = ledgr_sweep_retention(returns =
"none")`, raises `ledgr_sweep_returns_unretained` with a message
pointing at the `retain` argument and the workflow alternatives.

When called with explicit `candidates` that include a failed candidate
ID, raises `ledgr_sweep_returns_candidate_not_completed` with the
failed candidate IDs named and a pointer to the sweep summary status
column.

When called with explicit `candidates` that include a candidate_id not
present in the sweep at all, raises `ledgr_sweep_returns_candidate_not_found`.
Three classed conditions distinguish the three different user
mistakes (Codex response Section 3 recommendation).

### 6.5 Unchanged surfaces

`ledgr_candidate()` and `ledgr_promote()` are not modified. The
existing candidate-to-run workflow continues to operate on both
in-memory sweeps and reopened sweeps.

### 6.6 Surface count

Nine new exported functions plus one new argument:
- `ledgr_sweep_retention()` (constructor)
- `ledgr_sweep_save()`
- `ledgr_sweep_open()`
- `ledgr_sweep_list()`
- `ledgr_sweep_info()` (or print method only)
- `ledgr_sweep_returns()`
- `ledgr_sweep_returns_wide()`
- print and close methods on the sweep handle class
- `retain` argument on `ledgr_sweep()`

This is the smallest surface that delivers the three workflows.

---

## 7. Failed Candidate Semantics

A sweep candidate can complete with metrics (`status == "DONE"`),
complete with metrics and warnings (`status == "DONE"` with non-empty
warnings column), or fail (`status == "FAILED"`) per `R/sweep.R:1451`
and `R/sweep.R:1487`. v1 binds:

- The sweep summary tibble continues to carry one row per candidate
  with `status` reflecting completion / warning / error. Unchanged
  from today.
- The retained equity / return series is present only for candidates
  with `status == "DONE"` (with or without warnings).
- Failed candidates have no retained equity / return rows at all. Not
  NA-padded, not zero-padded, not phantom-rowed. Absent.
- `ledgr_sweep_returns()` with no `candidates` filter returns rows
  for completed candidates only.
- `ledgr_sweep_returns()` with `candidates = c(...)` that includes
  failed candidate IDs raises
  `ledgr_sweep_returns_candidate_not_completed`.
- The accessor's docs explicitly point users at the sweep summary
  `status` column to filter completed candidates first if they want
  NA-padded behavior via `dplyr::left_join`.

This avoids the surface-creep risk of a `keep = "all"` mode that
would NA-pad failed candidates. Users who want that shape join the
returns tibble against the summary tibble themselves.

---

## 8. Identity And Reproducibility

### 8.1 Retention metadata excluded from identity by construction

Two-layer enforcement (Codex F4):

**Layer 1 (structural).** Retention metadata is stored on a separate
side-channel attribute distinct from `execution_assumptions`. The
existing `execution_assumptions` attribute on `ledgr_sweep_results`
(`R/sweep.R:232-240`) participates in identity through downstream
hashing. v0.1.9.2 introduces a separate attribute (recommended name:
`retention_spec` or `sweep_retention`) carried alongside but not
inside execution_assumptions. The retention attribute is non-identity
by location.

**Layer 2 (defensive).** `config_hash_payload()` at
`R/config-hash.R:5-28` is extended to explicitly exclude the
retention attribute key, mirroring the existing exclusions of
`db_path`, `run_id`, `alias_map_order`, snapshot db_path, and
`feature_set_hash`. Even if a future implementer accidentally attaches
retention metadata in the wrong attribute, the hash payload excludes
it by name.

The contract this enforces:

> Running the same candidate twice with `retain =
> ledgr_sweep_retention(returns = "none")` and `retain =
> ledgr_sweep_retention(returns = "completed")` MUST produce identical
> `cost_model_hash`, `cost_plan_json`, `candidate_key`, `config_hash`,
> identical scalar metrics on the candidate row, identical execution
> seed, and identical fold execution path. The only difference is
> whether the retained equity / return series is sitting in memory.

Section 12.5 names the parity test fixture.

### 8.2 Sweep-level identity

Saved sweeps carry a `sweep_id` (user-supplied or auto-generated) that
is the durable lookup key. The sweep_id is not derived from the grid
or the candidates; collisions are detected at save time per Section
13.Q1.

### 8.3 Reopen parity

A sweep saved with `returns = "completed"` and reopened with
`ledgr_sweep_open()` must produce:

- identical sweep summary rows under canonical ordering and existing
  accounting tolerances;
- identical retained equity / return series (same byte representation
  modulo storage tolerances and canonical ordering);
- identical sweep-level identity attributes;
- identical cost identity (`cost_model_hash`, `cost_plan_json`);
- identical metric context (`metric_context_hash`,
  `metric_context_version`);
- identical feature identity (`feature_set_hash` per the existing
  attribute);
- identical candidate reproduction keys.

Equality tests compare identity fields and scalar results, not full
result objects. Object attributes used only for storage handles or
connection state are not compared as execution identity (Codex
response Section 5 guidance).

---

## 9. Cross-Sweep And Ephemeral ID Handling

### 9.1 sweep_id column in retained returns

The returns tibble carries a `sweep_id` column to disambiguate when
users stack returns across multiple sweeps:

```r
returns_q1 <- ledgr_sweep_returns(ledgr_sweep_open(snap, "sma-grid-q1"))
returns_q2 <- ledgr_sweep_returns(ledgr_sweep_open(snap, "sma-grid-q2"))
all_returns <- dplyr::bind_rows(returns_q1, returns_q2)
# candidate_id may collide across q1 and q2; sweep_id keeps them distinct
```

### 9.2 Ephemeral sweeps

An in-memory sweep that has never been saved has no durable sweep_id.
v1 binds: the `sweep_id` column for ephemeral sweeps is
`NA_character_`. On save, the column is populated to match the
assigned sweep_id; values returned by the accessor before save do not
retroactively update (they reflect the state at the time of accessor
call).

### 9.3 Reopen-without-snapshot is out of scope for v1

Reopening a saved sweep requires the original snapshot to be present.
If the snapshot is absent, `ledgr_sweep_open()` raises
`ledgr_sweep_snapshot_not_found`. Snapshot-decoupled reopening (i.e.,
reopening a sweep when the original snapshot is gone but the saved
sweep persists) is out of scope; deferred to a future obligation if
real demand surfaces.

---

## 10. Walk-Forward Forward Obligation

The walk-forward synthesis Section 12 defers richer diagnostic
retention (per-candidate per-fold return series, equity payload
references, sufficient statistics, partition / path identity, family /
effective-trial metadata) to a future RFC. v0.1.9.4 walk-forward ships
its v1 with the scalar score matrix only.

v0.1.9.2 sweep persistence MAY become a substrate that walk-forward
consumes for per-fold return-series retention. The seed binds:

**v0.1.9.2 does not bind walk-forward integration. v0.1.9.2 must not
foreclose it.**

Three reasons:

1. Walk-forward has identity dimensions v0.1.9.2 does not have:
   `fold_seq`, train vs test window split, fold-list identity. Whether
   the v0.1.9.2 returns shape extends naturally to per-fold or
   requires a richer shape is for the walk-forward §12 RFC to answer.
2. Pulling walk-forward integration into v0.1.9.2's scope balloons
   the packet. The discipline learned from the v0.1.8.11 -> v0.1.9.1
   flow says: solve the immediate substrate cleanly; route forward
   integration to its own RFC.
3. The v0.1.9.4 walk-forward synthesis already has Section 12 Future
   Obligations as the home for this question.

What v0.1.9.2 MUST do for walk-forward: design the retention shape
extensibly. The retention spec is a classed constructor whose argument
set can grow (e.g., adding a `folds` retention dimension in v0.1.9.4
without breaking v0.1.9.2's surface). The returns tibble can gain a
`fold_seq` column later as an additive change. The architectural
intent is "v0.1.9.2 returns shape is an instance of a more general
candidate x [optional dimensions] x time-series shape" without
binding the generalization.

---

## 11. Alpha Decay Three-Layer Routing

"Alpha decay analysis" is not one feature; it is three distinct
analytical layers that competitor frameworks ship separately.
v0.1.9.2 addresses part of one of them; the seed routes the others to
future RFCs.

### 11.1 Strategy return decay, single-stream only (addressed by v0.1.9.2)

Question: is the strategy's net return path stable across regimes,
windows, and snapshots, as a single time series? Substrate: net
portfolio return series over time. Tools: rolling Sharpe, rolling
volatility, regime decomposition, distributional shape (skew, kurt,
tail ratios), drawdown statistics, single-stream bootstrap.
Comparable surfaces: PA's `Return.rolling`,
`chart.RollingPerformance`, `chart.RollingDrawdown`,
`table.DownsideRisk`; pyfolio's single-strategy tear-sheets.

v0.1.9.2's retained net returns are the substrate for this
single-stream layer. PA, `pbo`, custom bootstrap, and DSR
computations operating only on the strategy return series operate on
this.

### 11.2 Benchmark-relative return decay (deferred to v0.2.x benchmark substrate)

Question: how does the strategy's return path move relative to a
benchmark or reference return series? Substrate: strategy returns
aligned to benchmark returns. Tools: rolling alpha, rolling beta,
information ratio, active return decomposition, active risk, tracking
error, beta-adjusted distributional analysis. Comparable surfaces:
PA's `chart.RollingRegression`, `CAPM.alpha`, `CAPM.beta`,
`InformationRatio`, `ActivePremium`.

ledgr does not yet have a benchmark-context substrate. The roadmap
places aligned benchmark / reference returns and active metrics at
v0.2.x (`inst/design/ledgr_roadmap.md:1775-1781`). v0.1.9.2 ships
strategy-return retention; benchmark-relative diagnostics require the
benchmark substrate as a precondition.

Future obligation: benchmark-context RFC. See Section 14.F11.

### 11.3 Signal decay (deferred)

Question: does the underlying feature or factor still predict future
returns? Substrate: feature values + forward returns, by quantile,
turnover, IC. Comparable surfaces: Alphalens, QuantRocket's factor
analysis.

This requires ledgr's feature engine to expose forward-return
computation against feature values, IC analysis, quantile returns,
and factor rank autocorrelation. It requires a feature-engine
extension and is its own substantial RFC.

Future obligation: signal-decay substrate RFC. See Section 14.F2.

### 11.4 Implementation / cost decay (deferred)

Question: is execution friction growing? Substrate: gross vs net
decomposition, per-trade cost attribution, per-instrument breakdown.
Comparable surfaces: blotter's gross-vs-net P&L tracking,
QuantConnect's live execution analytics.

This requires binding the "gross return" definition and extending
`fill_intent` to carry reference price alongside fill price and fee,
propagating through accounting events, and binding semantic
equivalence under v0.1.9.3 target-risk and future liquidity policies.

Future obligation: execution-attribution / cost-decay substrate RFC.
See Section 14.F3.

### 11.5 Why this routing matters

Every competitor framework ships one or two of these layers and
gestures at the others. Forcing all four into one RFC would be more
confusing than the natural split. ledgr's structural advantage --
shared identity surfaces, snapshot semantics, event sourcing -- means
each layer can be delivered as a clean tier rather than as a leaky
abstraction. The delivery happens across multiple RFCs in their own
windows, not as v0.1.9.2 scope creep.

---

## 12. Minimum Scope For v1

v0.1.9.2 Minimum Scope:

### 12.1 API surface

1. `ledgr_sweep_retention()` constructor with `returns` argument
   accepting `c("none", "completed")` exactly. Default `"none"`.
2. `retain` argument on `ledgr_sweep()`, default
   `ledgr_sweep_retention()`.
3. `ledgr_sweep_save()` / `ledgr_sweep_open()` / `ledgr_sweep_list()`
   / `ledgr_sweep_info()` (or print method on the handle).
4. `ledgr_sweep_returns()` long accessor with `candidates` ID filter.
5. `ledgr_sweep_returns_wide()` wide accessor with `candidates` ID
   filter.
6. Classed conditions:
   - `ledgr_sweep_returns_unretained` (called on a sweep with `returns
     = "none"`);
   - `ledgr_sweep_returns_candidate_not_completed` (filter includes a
     FAILED candidate_id);
   - `ledgr_sweep_returns_candidate_not_found` (filter includes a
     candidate_id absent from the sweep);
   - `ledgr_sweep_id_exists` (save on collision; see Q1);
   - `ledgr_sweep_snapshot_not_found` (open against missing snapshot).
7. Cost identity (`cost_model_hash`, `cost_plan_json`) propagated to
   persisted candidates per the v0.1.9.1 forward obligation.

### 12.2 Storage and persistence

8. DuckDB tables for sweep summary rows and (when retained) candidate
   equity / return series. Schema bound at spec cut.
9. Round-trip parity: a saved sweep round-trips through
   `ledgr_sweep_save()` and `ledgr_sweep_open()` to byte-equivalent
   identity attributes and scalar rows.

### 12.3 Retention storage smoke measurement

10. The packet runs one storage smoke measurement: take a
    representative completed sweep (recommended: the SMA-grid example
    from the sweeps vignette, scaled to a canonical pulse count) and
    measure actual DuckDB / on-disk bytes added by `returns =
    "completed"` retention vs `returns = "none"`. Acceptance: actual
    storage cost is within a factor of two of the expected cost
    computed from `n_candidates * n_pulses * (8 bytes equity + 8 bytes
    return + storage overhead)`. The smoke measurement is documented
    in the release notes; it is not a perf gate, but the packet must
    not ship without the number.

### 12.4 Canonical-series parity fixture matrix (Codex F3)

11. Parity tests cover the matrix:

    | Path source | compiled_accounting_model | Expected outcome |
    | --- | --- | --- |
    | inline-memory handler | FALSE (default R) | retained equity = summary-object equity (byte-equivalent under canonical ordering) |
    | inline-memory handler | TRUE | retained equity = summary-object equity (byte-equivalent under canonical ordering) |
    | ordered-event reconstructor | FALSE | retained equity = summary-object equity (byte-equivalent under canonical ordering) |
    | ordered-event reconstructor | TRUE | retained equity = summary-object equity (byte-equivalent under canonical ordering) |

    All four cells must pass. Retention does not introduce a third
    summary path; it plumbs the same object.

### 12.5 Identity-orthogonality parity fixture (Codex F4)

12. Parity test: run the same candidate twice, once with `retain =
    ledgr_sweep_retention(returns = "none")` and once with `retain =
    ledgr_sweep_retention(returns = "completed")`. Assert:

    - identical `cost_model_hash`;
    - identical `cost_plan_json`;
    - identical `candidate_key`;
    - identical `config_hash`;
    - identical scalar metrics on the candidate row;
    - identical execution seed;
    - identical canonical event stream up to the equity-fact emission
      point (verified through the existing event-recorder
      infrastructure if available, or through the per-pulse equity
      facts otherwise).

    Layer-1 structural check: assert the retention attribute lives on
    a key OTHER than `execution_assumptions`.

    Layer-2 defensive check: assert that
    `config_hash_payload(config_with_retention)` excludes the
    retention key, even when retention is forced into the payload via
    a fixture (regression guard against future attribute reshuffling).

### 12.6 Final-bar no-fill fixture (Codex F1)

13. Parity test: construct a candidate that emits
    `LEDGR_LAST_BAR_NO_FILL` on its last scoring pulse. Assert:

    - the retained equity series has `n_pulses` rows (NOT `n_pulses -
      1`);
    - the final equity row's `ts_utc` matches the final scoring pulse;
    - the candidate summary row carries the warning;
    - the retained `return` for the final row is computed from the
      adjacent-row diff (it may be 0 or non-zero depending on positions
      and price behavior; this is observed, not asserted to a specific
      value).

### 12.7 Failed-candidate absence fixture

14. Parity test: construct a sweep with `stop_on_error = FALSE` and
    a candidate that fails. Assert:

    - the sweep summary row exists with `status = "FAILED"`;
    - no rows in the retained returns tibble carry the failed
      candidate_id;
    - `ledgr_sweep_returns(sweep, candidates = "<failed_id>")` raises
      `ledgr_sweep_returns_candidate_not_completed`.

### 12.8 Documentation

15. Sweep vignette section on the three workflows.
16. Sweep vignette section on the three-tier evidence framing.
17. Sweep vignette section explicitly naming the deferred layers and
    routing each to its future RFC: benchmark-relative diagnostics
    (v0.2.x benchmark substrate), signal decay (v0.2.x feature-engine
    extension), implementation / cost decay (v0.2.x
    execution-attribution).
18. Sweep vignette section explaining why a user computing PA's
    `SharpeRatio` on retained returns may see a different number than
    the candidate row's `sharpe_annualized` (annualization and
    return-shape convention divergence, not two definitions of "the
    candidate's net return series").
19. `?ledgr_sweep_retention` and accessor help pages with runnable
    examples.
20. NEWS entry naming the new surface as additive (no breakage on
    existing scalar-only sweep semantics; the `retain` argument
    defaults preserve today's behavior).

### 12.9 Tests

21. Classed-error coverage for the five new conditions (item 6 above).
22. PA-compatibility round-trip: compute Sharpe via ledgr's metric
    kernel and via PA on retained returns; document the expected
    divergence pattern in the same vignette section as item 18.

---

## 13. Open Questions Promoted To Spec-Cut

### Q1: `sweep_id` collision behavior

When `ledgr_sweep_save()` is called with a `sweep_id` that already
exists in the snapshot's store, behavior options:

- (a) Reject with `ledgr_sweep_id_exists` classed error; user must
  pass a different ID or explicit `overwrite = TRUE` (which would
  itself be spec-cut scope).
- (b) Overwrite silently.
- (c) Append a suffix.

Recommendation: (a). Matches the cost-API §13 aggressive-rejection
posture. Codex response Section 3 confirms.

### Q2: Wide returns accessor shape

Two surface options for the wide-format bridge:

- (a) Separate function `ledgr_sweep_returns_wide()`.
- (b) `pivot = c("long", "wide")` argument on `ledgr_sweep_returns()`.

Recommendation: (a). Symmetric with how ledgr surfaces are typically
discovered. Codex response Section 3 confirms.

### Q3: Wide accessor value-column scope

If the wide accessor is a separate function, does it return one
wide tibble per value column (equity vs returns), accept a `value`
argument, or return both as a list?

Recommendation: synthesis binds. The most natural choice is a `value
= c("returns", "equity")` argument defaulting to `"returns"`, since
returns are the primary input to PA-style consumers.

### Q4: `note` argument shape

Free-text character string vs structured (named list with
maintainer / hypothesis / etc.)?

Recommendation: free-text character scalar in v1. Structured notes
are an obvious future obligation that would benefit from auditr
evidence about what users actually want to capture.

### Q5: Retention attribute key name

The Section 8.1 Layer-1 binding requires retention metadata to live
on an attribute distinct from `execution_assumptions`. Recommended
name: `sweep_retention`. Synthesis binds the exact key.

### Q6: Storage schema

Two DuckDB tables or a single returns table keyed by `(sweep_id,
candidate_id, ts_utc)` plus a sweep-summary table? Synthesis or
spec-cut binds. The smoke measurement (item 12.10) is a sanity check
on whichever choice is made.

---

## 14. Future Obligations Recorded

### F1: Walk-forward per-fold per-candidate return-series retention

The v0.1.9.4 walk-forward packet may extend the shape with `fold_seq`
and train-vs-test window dimensions. v0.1.9.2 must not foreclose this
extension; the walk-forward §12 RFC is the binding home for the
extension itself.

### F2: Signal decay substrate (Alphalens-equivalent)

Feature-engine extension for forward-return computation, IC analysis,
quantile returns, factor rank autocorrelation. Target window v0.2.x.

### F3: Execution / cost-decay substrate (gross vs net)

Reference-price tracking in `fill_intent`; cost-component attribution
in accounting events; binding the gross-return definition under
target-risk and future liquidity policy. Target window v0.2.x.

### F4: Selection-integrity diagnostics method library

DSR, PBO, CSCV, CPCV, bootstrap CIs, robustness slicing as
ledgr-owned helpers operating on the v0.1.9.2 retained series.
Currently routed to external libraries. Target window v0.1.9.x slot
per roadmap.

### F5: PerformanceAnalytics adapter

Output adapter over ledgr's stable result tables. Target window
v0.2.x.

### F6: Per-instrument and per-trade retention

For implementation-decay analysis and per-instrument alpha
attribution. Target window v0.2.x diagnostic-retention RFC.

### F7: Cross-sweep comparison helpers

`ledgr_sweep_diff()`, named cross-sweep stacking, sweep-of-sweeps
analysis. Defer until auditr surfaces a real workflow that dplyr
cannot cleanly serve.

### F8: Sweep extension / iterative grid append

Defer. Identity questions make this nontrivial.

### F9: Structured `note` shape

Defer until auditr surfaces consistent structure.

### F10: `persist =` narrower than `retain =` on save

Defer until demand is proven.

### F11: Benchmark-relative return decay (new in v2)

Rolling alpha, rolling beta, information ratio, active return
decomposition, active risk, tracking error, beta-adjusted
distributional analysis. Requires a benchmark-context substrate
(aligned benchmark or reference return series, active-metric
machinery). Roadmapped at v0.2.x
(`inst/design/ledgr_roadmap.md:1775-1781`). The v0.1.9.2 retained
returns become an input to this substrate without v0.1.9.2 having to
implement any benchmark machinery itself.

### F12: Snapshot-decoupled sweep reopening (new in v2)

Reopening a saved sweep when the original snapshot is no longer
present. v1 raises `ledgr_sweep_snapshot_not_found` on this case.
Defer until demand is proven.

### F13: Saved-sweep schema migration (new in v2)

As future RFCs extend retention (per-fold, per-instrument,
cost-component), the DuckDB schema for saved sweeps will change. v1
relies on the pre-CRAN no-external-users posture: schema changes are
permitted across cycles, and reopening an old saved sweep on a newer
ledgr may error rather than auto-migrate. Defer schema migration
machinery to a future window if ledgr's user base grows.

---

## 15. Comparable Surfaces In Other Frameworks

Unchanged from seed v1 Section 14. Summary: no competitor unifies all
three alpha-decay layers. Each ships one substrate cleanly and
gestures at the others. v0.1.9.2 ships strategy return decay
(single-stream) at the same standard, with explicit routing of the
other layers to future RFCs.

Sources retained:

- QuantConnect / LEAN: `https://www.quantconnect.com/docs/v2/cloud-platform/optimization/results`
- Backtrader: `https://www.backtrader.com/docu/analyzers/analyzers/`
- vectorbt: `https://vectorbt.dev/api/portfolio/base/`
- quantstrat: `https://rdrr.io/rforge/quantstrat/man/apply.paramset.html`
- PerformanceAnalytics: `https://www.rdocumentation.org/packages/PerformanceAnalytics/`
- Alphalens: `https://alphalens.ml4trading.io/notebooks/overview.html`

---

## 16. Acceptance Criteria For This RFC Cycle

The synthesis is ready to accept when:

- The Section 5 semantic bindings are bound, with parity tests named
  as Minimum Scope (items 11-14 in Section 12).
- The Section 6 API surface is bound (function set, retention
  constructor shape with two-value enum, classed-condition names).
- The Section 8.1 two-layer identity exclusion is bound and Section
  12.5 fixture is named.
- The Section 13 open questions are resolved at spec-cut time, not
  RFC-bound here.
- The Section 14 future obligations are named and routed to their
  destination RFCs / windows; none of them are silently absorbed into
  v0.1.9.2 scope.
- The three-layer alpha-decay routing in Section 11 (now four-layer
  with benchmark-relative split out) is explicit in the sweep
  vignette obligation, and the synthesis records that v0.1.9.5 docs
  cycle will absorb the teaching of why PA Sharpe and ledgr Sharpe may
  differ.
- Walk-forward forward obligation in Section 10 is preserved without
  binding integration: the synthesis does not pre-empt the
  walk-forward §12 RFC's design space.
- Section 12.3 storage smoke measurement is named as a Minimum Scope
  acceptance criterion.

The synthesis is ready to escalate to maintainer decisions if:

- An additional load-bearing workflow surfaces that the nine-function
  surface cannot serve;
- The Section 11.2 benchmark-relative routing is contested in a way
  that forces a binary product decision;
- The Section 13 spec-cut questions surface a binary that the
  synthesis author cannot resolve from the seed and response.

---

## 17. Notes For The Synthesis Stage

This seed v2 has absorbed Codex's response. The synthesis stage author
should treat the Section 5 semantic bindings, the Section 6 API
surface, the Section 8.1 identity exclusion, and the Section 12
Minimum Scope (especially items 11-14) as v2-bound contract surfaces.
The synthesis binds the spec-cut-level questions in Section 13 and the
remaining surface decisions (storage schema shape, retention attribute
key name, wide-accessor value-column scope).

The synthesis should NOT:

- reopen the retention-vs-persistence split (Section 3);
- reopen the three-tier evidence framing (Section 4);
- reopen the alpha-decay routing (Section 11);
- reopen the walk-forward forward-obligation framing (Section 10);
- introduce additional retention enum values;
- introduce ranking, selection, or comparison machinery;
- introduce benchmark-relative diagnostics or any v0.2.x material
  pulled forward.

The synthesis should:

- bind the Section 13 spec-cut questions to specific recommendations
  (the seed v2 already names recommendations; the synthesis confirms
  or overrides);
- name the DuckDB schema shape (Q6);
- name the retention attribute key (Q5);
- name the wide-accessor value-column scope (Q3);
- name the NEWS entry shape;
- bind the test fixtures at file-path-and-name granularity for the
  spec-cut writer to consume directly.

Per cycle rotation (rfc_cycle.md:72-78), Codex authors the synthesis.
The final review (different author from the synthesis) will be Claude.
