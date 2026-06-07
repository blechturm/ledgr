# RFC Response: Sweep Artifact Persistence v0.1.9.x

**Status:** Response draft.
**Date:** 2026-06-06.
**RFC seed:** `inst/design/rfc/rfc_sweep_artifact_persistence_v0_1_9_x_seed.md`.
**Target release:** v0.1.9.2.
**Reviewer:** Codex.

## 0. Summary verdict

The seed is directionally correct and is close enough to move to seed v2, but
it needs amendment before synthesis. The core shape is right: v0.1.9.2 should
persist compact sweep artifacts, optionally retain net portfolio equity/return
series for completed candidates, inherit v0.1.9.1 cost identity, and avoid
ranking machinery, named selection views, broad retention modes, or
walk-forward diagnostic scope.

The blocking issues are semantic precision, not product direction. Seed v2
should fix five points:

- final-bar no-fill does not truncate the equity curve;
- equity rows and return rows need an explicit timestamp/alignment contract;
- canonical-series parity must cover both existing sweep summary paths;
- retention identity must be excluded by construction, not by convention;
- `returns = "completed"` versus `returns = "all"` is underdefined.

No R implementation work should start until seed v2 binds those points.

## 1. What the seed got right

The seed gets the release boundary right. It treats retention and persistence
as related but orthogonal concerns, keeps default sweep output compact, and
does not turn v0.1.9.2 into a validation or visualization release. That matches
the roadmap entry for v0.1.9.2 as compact sweep-result retention and promotion
audit infrastructure for later walk-forward, not full diagnostic retention
(`inst/design/ledgr_roadmap.md:110`, `inst/design/ledgr_roadmap.md:1623`).

The seed correctly keeps walk-forward in front of, but not inside, v0.1.9.2.
The four-tick roadmap says walk-forward consumes cost identity from v0.1.9.1,
sweep retention infrastructure from v0.1.9.2, and risk-chain identity from
v0.1.9.3 (`inst/design/ledgr_roadmap.md:1343`,
`inst/design/ledgr_roadmap.md:1353`). The seed's forward-obligation posture
preserves that order.

The seed correctly inherits cost identity rather than designing a second cost
surface. Current sweep results already carry `cost_model_hash` and
`cost_plan_json` as result attributes (`R/sweep.R:230`, `R/sweep.R:231`), pass
them into execution assumptions (`R/sweep.R:235`), include them in candidate
reproduction keys (`R/sweep.R:386`, `R/sweep.R:387`), and evaluate candidates
from the stored cost plan JSON (`R/sweep.R:919`).

The alpha-decay routing is mostly right. Net strategy return decay is the only
decay surface v0.1.9.2 can honestly support. Signal decay needs factor/signal
observation tables and a later research-validity design. Implementation/cost
decay needs cost-component or execution-quality diagnostics, which are already
routed outside v1 cost identity and default retention.

The seed also correctly rejects named selection views, ranking helpers,
top-N retention, and "save the interesting rows" semantics. Those would
accidentally couple persistence to candidate selection. v0.1.9.2 should store
what the sweep produced and what the caller explicitly retained, not bless a
winner or a validation protocol.

## 2. Findings requiring v2 amendment

### F1. Final-bar no-fill must not truncate retained equity

Seed Section 4.5 says a retained series "ends at the last bar that did fill" if
a candidate emits `LEDGR_LAST_BAR_NO_FILL`. That is not how the current fold
materializes equity.

The fold records an equity fact once per pulse before fill resolution:
`R/fold-engine.R:203` computes positions value, `R/fold-engine.R:208` checks
`output_handler$record_equity_fact`, and `R/fold-engine.R:209` through
`R/fold-engine.R:214` records `ts_utc`, cash, positions value, realized PnL,
and cost basis. The final-bar no-fill branch is later in fill resolution:
`R/fold-engine.R:368` and `R/fold-engine.R:371` emit the warning after a fill
proposal resolves to no fill. The durable equity reconstruction also emits one
row over `pulses_posix`: `R/backtest-runner.R:1428` computes equity,
`R/backtest-runner.R:1443` starts the non-empty equity frame, and
`R/backtest-runner.R:1445` uses `ts_utc = pulses_posix`. The memory event
reconstructor has the same shape at `R/fold-reconstruction.R:140` and
`R/fold-reconstruction.R:145`.

Seed v2 should bind this instead:

> Retained equity covers the same scoring-pulse timestamps as the public
> equity curve, including the final scoring pulse. `LEDGR_LAST_BAR_NO_FILL`
> affects fill/event emission and candidate warnings; it does not remove the
> final equity row.

This is a high-priority amendment because it changes what users see in equity
plots and return series after a final-pulse target change.

### F2. Equity/return row alignment needs an explicit contract

Seed Sections 4.1, 4.4, 4.6, and 4.7 jointly imply a long table with both
equity and return values, including an initial-equity row. They do not say how
the shorter period-return vector aligns to the equity timestamps.

The canonical return calculation is adjacent-row based and returns
`nrow(equity) - 1` values. `compute_period_returns()` returns `numeric(0)` when
fewer than two equity rows exist (`R/backtest.R:1423`), builds `prev` and `cur`
from adjacent equity values (`R/backtest.R:1424`, `R/backtest.R:1425`), and
stores `(cur / prev) - 1` (`R/backtest.R:1428`). Metrics then consume that
shorter vector at `R/backtest.R:1608`.

Seed v2 should pick one explicit convention. The most natural ledgr convention
is:

- one equity row per scoring pulse;
- `return` is the period return ending at that row's `ts_utc`;
- the first equity row has `return = NA_real_`;
- metric parity tests drop the first `NA_real_` before comparing to
  `ledgr_compute_metrics()`.

An alternative is separate equity and returns accessors/tables, with returns
omitting the first timestamp. Either is workable. The RFC must choose before
ticket cut because it affects the public accessor contract and all examples.

### F3. Canonical-series parity must cover both current sweep summary paths

The seed says the retained series should match the series consumed by
`ledgr_compute_metrics()` and by a promoted run. That is the right target, but
the implementation path is not one path today.

Current sweep candidate execution uses an inline summary if the output handler
provides one (`R/sweep.R:956`, `R/sweep.R:957`). Otherwise it falls back to
typed or generic events and calls
`ledgr_sweep_summary_from_ordered_events()` (`R/sweep.R:967`). The inline memory
handler builds an equity data frame directly from recorded facts
(`R/sweep.R:1341`, `R/sweep.R:1358`, `R/sweep.R:1360`,
`R/sweep.R:1363`) and returns final equity from that frame (`R/sweep.R:1378`).
The fallback event reconstructor builds equity from ordered events and
`pulses_posix` (`R/fold-reconstruction.R:140`, `R/fold-reconstruction.R:145`).
Committed runs materialize their durable equity curve through the runner's
event reconstruction path and append it to `equity_curve`
(`R/backtest-runner.R:1428`, `R/backtest-runner.R:1445`,
`R/backtest-runner.R:1481`, `R/backtest-runner.R:1483`).

Seed v2 should state that retention is sourced from the same per-candidate
summary object used for scalar metrics, regardless of whether that summary came
from the inline memory handler or from ordered-event reconstruction. Acceptance
tests should cover the default R accounting path and any public retained-series
path affected by `compiled_accounting_model`.

This is not a request for a new execution engine. It is a requirement that the
new retained artifact is plumbed from existing summary evidence, not recomputed
by a third path.

### F4. Retention identity must be excluded by construction

Seed Section 7.1 says retention policy must not enter candidate identity. That
is correct, but the current identity code will not enforce it automatically.

`config_hash()` hashes `canonical_json(config_hash_payload(config))`
(`R/config-hash.R:1`, `R/config-hash.R:2`). The payload helper excludes only
known non-identity fields such as `db_path`, `run_id`, `alias_map_order`,
snapshot DB path, and `features$feature_set_hash` (`R/config-hash.R:5` through
`R/config-hash.R:14`). Sweep result metadata also carries execution assumptions
as attributes (`R/sweep.R:232`), including timing mode, cost identity, opening
cash, compiled-accounting mode, precomputed-feature use, and `stop_on_error`
(`R/sweep.R:235` through `R/sweep.R:239`).

Seed v2 should bind an implementation rule:

- retention policy must not be inserted into execution config or candidate
  identity payloads;
- if implementation stores retention metadata near config or execution
  assumptions, `config_hash_payload()` or the candidate-key builder must
  explicitly exclude it;
- equality tests should compare identity fields and scalar results, not full
  result objects, because retained artifacts and result attributes are expected
  to differ.

Without that rule, a natural implementation can accidentally make
`retain = "none"` and `retain = "completed"` produce different identities.

### F5. `returns = "completed"` versus `returns = "all"` is underdefined

Seed Section 5.1 proposes
`ledgr_sweep_retention(returns = c("none", "completed", "all"))`, while
Section 6 says failed candidates do not receive retained return rows. Current
sweep rows explicitly distinguish completed and failed candidates:
documentation says failed candidates are retained as rows when
`stop_on_error = FALSE` (`R/sweep.R:51`), candidate extraction defaults to
rejecting failed candidates (`R/sweep.R:290`, `R/sweep.R:291`), success rows
set `status = "DONE"` (`R/sweep.R:1451`), and failed rows set
`status = "FAILED"` (`R/sweep.R:1487`).

If failed candidates have no return/equity artifact, then `returns = "all"`
cannot mean all candidate rows. If it means all completed candidates, it is
the same as `completed`. Seed v2 should collapse the enum to
`c("none", "completed")` or rename the second value to something unambiguous
such as `"all_completed"`. Broader modes can stay deferred.

## 3. Findings requiring spec-cut attention

`sweep_id` collision behavior should be bound at spec cut. The seed recommends
reject-on-collision, which is the right default. Silent overwrite would violate
artifact auditability; implicit versioning would create a larger lifecycle
surface than v0.1.9.2 needs.

The long-versus-wide accessor decision can remain a spec question after seed
v2 fixes row alignment. My recommendation is a long default plus a separate
wide helper. A pivot argument on the same function is a small convenience but
usually makes error messages and column naming less crisp.

Ticket cut should include one storage-size/performance smoke measurement for
retained returns. This does not need a new benchmark framework, but the packet
should know the approximate DuckDB/storage impact of retaining net equity and
returns for a representative completed sweep. That measurement protects v0.1.9.2
from accidentally shipping a "compact artifact" feature whose retained-series
mode is not compact enough in practice.

Documentation should name the distinction between "saved sweep" and "committed
run" directly. A saved sweep is candidate evidence and reproduction context. A
promoted run remains the full ledger/fill/trade/equity evidence path.

The public errors should use existing condition-class style and should be
separate enough for tests: no retained returns, requested candidate failed, and
requested candidate id absent are different user mistakes.

## 4. Findings requiring future-obligation routing

Benchmark-relative return decay must be routed to the benchmark-context and
active-metrics future work, not implied by v0.1.9.2. The roadmap puts aligned
benchmark/reference returns and active metrics in v0.2.x
(`inst/design/ledgr_roadmap.md:1775` through
`inst/design/ledgr_roadmap.md:1781`). Section 10 can say v0.1.9.2 enables net
strategy return decay over retained candidate returns. It should not imply
rolling alpha, beta, information ratio, or benchmark-relative diagnostics until
the benchmark substrate exists.

Capacity, liquidity, and crowding decay are not a new v0.1.9.2 alpha-decay
layer. They belong to later liquidity/capacity policy, target-risk, benchmark,
and point-in-time data work. The seed's three-layer routing remains adequate:
strategy return decay now, signal decay later, and implementation/cost decay
later. If capacity decay is named, it should be routed as a future liquidity
or market-structure obligation, not folded into sweep artifact persistence.

Cost-component attribution remains a future diagnostic-retention obligation.
The cost API synthesis explicitly keeps v1 retention at one cost identity per
run and one total fee per fill, with optional component detail only in
`meta_json` (`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:434`).
v0.1.9.2 should persist cost identity and net series, not introduce spread/fee
component decomposition.

Walk-forward per-fold retention remains owned by walk-forward. The walk-forward
synthesis already says scalar score rows are not enough for DSR, CPCV,
nonlinear metric reconstruction, or fold-aggregated path metrics, and routes
diagnostic retention tiers to future work
(`inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md:315`
through `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md:319`,
`inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md:555`
through `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md:563`).
v0.1.9.2 can choose an extensible artifact schema, but should not decide
walk-forward fold payload semantics.

## 5. Verification of the seed's external claims

The claim that v0.1.9.1 cost identity can be consumed by v0.1.9.2 is verified.
Cost model inspection is represented by canonical plan JSON and deterministic
hash helpers (`R/cost-model.R:286`, `R/cost-model.R:290`). Runtime cost
resolution uses the compiled plan to resolve fill price and fee
(`R/cost-model.R:396`, `R/cost-model.R:411`, `R/cost-model.R:412`,
`R/cost-model.R:425`, `R/cost-model.R:433`). Sweep candidates already pass
cost identity through attributes, task payloads, failure provenance, success
provenance, and reproduction keys (`R/sweep.R:230`, `R/sweep.R:231`,
`R/sweep.R:711`, `R/sweep.R:712`, `R/sweep.R:737`, `R/sweep.R:738`,
`R/sweep.R:995`, `R/sweep.R:996`).

The claim that `ledgr_sweep()` already produces enough internal evidence to
retain net equity is directionally verified, with the caveat in F3. The current
summary path builds an equity frame either inline from recorded equity facts or
from ordered events. The new release needs to retain and expose that evidence;
it does not need to change strategy or fill semantics.

The claim that retained series should be net of transaction costs is verified.
Cost resolution feeds fill price and total fee into fill intents, and equity is
then reconstructed from cash, positions value, realized PnL, and cost basis.
The retained equity curve therefore represents the same net portfolio path as
the scalar metrics, assuming it is sourced from the existing summary object.

The claim that v0.1.9.2 should not solve statistical validation is verified.
The roadmap keeps selection integrity diagnostics after the walk-forward window
model stabilizes (`inst/design/ledgr_roadmap.md:1595`,
`inst/design/ledgr_roadmap.md:1611`). Retained net returns are a substrate for
future validation, not a validation protocol by themselves.

The claim that the saved-sweep API should reopen saved sweeps as ordinary
sweep-like objects is coherent, but acceptance tests must be strict: reopened
summary rows, cost identity, metric context identity, feature identity,
candidate reproduction keys, warnings/errors, and retained return/equity rows
must match the saved artifact. Object attributes used only for storage handles
or connection state should not be compared as execution identity.

## 6. Recommendation on next stage

Cut seed v2 before synthesis. Seed v2 should keep the product shape and
non-scope boundaries, then incorporate the five required amendments from
Section 2. After that, synthesis can probably be narrow: bind the API names,
table shape, retention enum, `sweep_id` collision rule, and the parity tests.

Do not add a horizon entry for broad validation UX, alpha-decay decomposition,
or cost diagnostics as part of this response. Those are already routed by the
roadmap and existing RFCs. The only future-obligation clarification I would add
is benchmark-relative decay: v0.1.9.2 supports retained net strategy returns,
not benchmark-relative alpha/beta diagnostics.
