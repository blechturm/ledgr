# Codex Decision Review: Fold-Core FIFO Lot Accounting

**Verdict:** Framing B, with a hard event-preserving hybrid constraint.

Move FIFO lot accounting into the fold core as a substrate decision, not as a
telemetry-gated wall-recovery decision. The load-bearing reason is not the
R-side 7-10s recovery from Spike 12; it is accounting ownership. A compiled fold
core should measure and eventually own the same per-fill state transition that
the R fold core owns: cash, positions, and FIFO lots. The metric-extensibility
concern is real only if "inline capture" means eliding the event log or making
the fold engine the metric engine. That should be rejected. The event log must
remain canonical evidence; fold-produced lot facts are typed accounting outputs
and parity-checked caches. Reconstruction remains the verifier/fallback/readback
path, not the normal fresh-sweep source for facts that the fold already emitted.

## Framing A - Telemetry-Gated

### Arguments For

Framing A is empirically disciplined. Spike 12 shows that moving lot accounting
from reconstruction into fold time saves only the JSON/dispatcher slice, not the
FIFO work itself: `~22-27%` savings, or `~7-10s` synthetic xlarge wall
(`dev/spikes/spike-fold-time-lot-accounting.md:118-140`). The current Round-2
synthesis correctly gates Ticket 2 on production subphase telemetry at
`architecture_synthesis.md:302-329`.

That discipline is especially attractive because the post-v0.1.8.9 peer
ephemeral row already has only `9.63s` results time
(`v0_1_8_9_release_closeout.md:95-100`, cited in the synthesis). If the
workload-grid xlarge ephemeral results phase is similarly small, the direct
wall recovery does not justify a large parity surface.

Framing A also minimizes semantic churn. Today `R/fold-engine.R:295-361`
resolves fills and updates cash/positions, while FIFO lot accounting lives in
reconstruction (`R/fold-reconstruction.R:453-504`) and durable fill extraction
(`R/backtest.R:1091-1268`). Deferring lot movement until telemetry proves
materiality keeps that ownership split stable.

### Arguments Against

Framing A optimizes the decision for immediate R wall recovery, not for the
post-v0.1.8.10 substrate that K1 will measure. The horizon K1 entry says the
compiled spike measures per-pulse and per-fill costs, including "per-fill cost
with R output-handler callback" and "per-fill cost with inline event
accumulation" (`inst/design/horizon.md:474-491`). If R production still leaves
FIFO lot accounting outside the fold, the K1 fold-core measurement can avoid
the same accounting work and understate the real compiled-core opportunity.

It also preserves an awkward architecture: fresh ephemeral runs compute cash and
positions in the fold, then replay the same event stream post-fold to derive
FIFO accounting, fills, realized PnL, and cost basis. That split is tolerable as
an implementation stage, but it is not the ideal execution boundary. The
accounting state transition belongs with the fill that caused it.

### Empirical Evidence

The evidence supports Framing A's caution but not its gating criterion as the
final architecture rule.

- Current standard metrics only need equity + fills:
  `ledgr_metrics_from_equity_fills()` reads equity and closed fill rows at
  `R/fold-metrics.R:9-57`. `ledgr_compute_metrics_internal()` similarly reads
  equity and fills at `R/backtest.R:1496-1530`.
- Moving lot accounting is not a huge R recovery lane: Spike 12 bounds the
  synthetic net win to roughly `7-10s`.
- But K1's documented measurement scope is explicitly per-fill as well as
  per-pulse (`inst/design/horizon.md:481-484`). FIFO accounting is per-fill
  state transition work. It is naturally in the substrate if the substrate is
  meant to represent production execution rather than only target/fill-price
  mechanics.

## Framing B - Substrate Expansion

### Arguments For

The substrate-expansion claim is technically correct if the move is framed as
accounting ownership, not as metric emission. A fold core that owns cash,
positions, and lots gives K1 a larger and cleaner surface:

- the R baseline includes the same per-fill accounting work a compiled core
  would plausibly absorb;
- the compiled path can test one hot execution loop rather than a fold loop plus
  a separate reconstruction/replay loop;
- output handlers receive complete typed accounting facts from the state
  transition instead of reconstructing them later.

This aligns with the horizon's substrate doctrine. The 2026-06-01 entry says
R-side data structures are no-regret because they are both direct R
optimization and the substrate any future `ledgrcore` consumes
(`inst/design/horizon.md:572-582`). FIFO lot state is not just a metric; it is
the accounting state associated with fills. Treating it as fold-owned is a
stronger substrate than leaving it as post-hoc reconstruction.

The cleaner-compiled-architecture argument also holds. A compiled fold core
that produces equity but leaves fills/realized PnL/cost basis to an R
reconstruction replay would not be the production execution core; it would be a
partial accelerator. Moving FIFO into the R fold first clarifies the boundary
K1 should compare.

### Arguments Against

Framing B is only safe if it rejects event elision. The current reconstruction
pass is generic because it consumes ordered events and can derive equity, fills,
metrics, realized PnL, and cost basis (`R/fold-reconstruction.R:376-572`). If
Ticket 2 replaced that with a fixed set of inline aggregates and stopped
preserving events, metric extensibility and custom diagnostics would suffer.

Future roadmap items make that risk concrete:

- walk-forward diagnostic retention expects per-candidate per-fold return
  series, equity payload references, sufficient statistics, and partition/path
  identity (`inst/design/horizon.md:1892-1905`);
- cost/TCA work consumes cost-resolved fill rows and future order-lifecycle
  artifacts, and may retain cost component details in separate diagnostic
  tables (`inst/design/horizon.md:2057-2073`);
- baseline comparison surfaces depend on same-engine, same-snapshot runs and
  fixed comparison metrics (`inst/design/horizon.md:2107-2224`).

Those surfaces do not require the event log for current standard metrics, but
they do require ledgr not to close off diagnostic data just because a fresh
sweep can compute today's metrics from inline equity + fills.

There is also a K1 risk: if `ledgrcore-spike` reports "do not build," the
project has still paid the parity and implementation cost for moving FIFO into
the fold. That cost is acceptable only if the move is independently justified
as a cleaner accounting boundary, not merely as speculative compiled-core
prework.

### Empirical Evidence

The evidence supports Framing B under a hybrid constraint:

- All current standard metrics are derivable from inline equity and fills
  (`R/fold-metrics.R:9-57`; `R/backtest.R:1496-1530`).
- The current memory output handler already preserves the event table and typed
  metadata attributes (`R/sweep.R:957-1190`). Inline accounting facts can extend
  that typed metadata pattern without eliminating events.
- Durable extraction and readback still reconstruct fills from persisted
  `ledger_events` (`R/backtest.R:1021-1268`). That path should remain a
  compatibility/verifier path even after fresh ephemeral sweeps can use inline
  facts.
- The cost API synthesis says cost models consume `ledgr_fill_proposal +
  ledgr_fill_context` and see execution-bar OHLCV after strategy decision
  (`rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:145-155`,
  `292-305`). Fold-owned lots do not conflict with that boundary; they happen
  after fill resolution.

## Metric Extensibility Decision

Moving FIFO into the fold does **not** lock ledgr into a fixed metric set if
Ticket 2 obeys three rules:

1. **Events remain canonical.** `ledgr_results(bt, "events")` and materialized
   event rows remain available. Inline capture must not remove or weaken the
   event stream.
2. **Fold emits accounting facts, not metrics.** The fold may emit per-fill
   realized PnL, cost basis, OPEN/CLOSE split, and per-pulse equity/cash/position
   values. It should not emit Sharpe, win rate, baseline-relative statistics,
   TCA, or walk-forward diagnostics.
3. **Reconstruction remains a verifier/fallback.** Fresh sweeps may bypass
   reconstruction for speed, but the event-stream reconstruction path remains
   available for durable readback, parity checks, and future diagnostics.

With those rules, future metrics can still be added in metric-computation code
when they are functions of equity, fills, returns, costs, or future diagnostic
tables. Fold-engine changes are needed only when a future feature requires new
state transition facts, such as tax-lot policy, cost-component state, or
order-lifecycle artifacts. That is the correct boundary.

## Recommendation

**Strong recommendation:** adopt Framing B as a substrate decision, but specify
it as **event-preserving fold-owned accounting**, not pure inline aggregate
replacement.

Telemetry should still land first for attribution, but it should not decide
whether FIFO moves into the fold. The go/no-go for Ticket 2 should be semantic
and parity-based:

- if fold-time accounting can preserve the event stream and produce
  byte/equivalent accounting outputs, ship it;
- if preserving the event stream or durable readback contract requires schema
  churn beyond v0.1.8.10, ship inline equity now and move fold-owned lots to the
  next accounting-boundary ticket;
- do not park fold-owned lots solely because the production results phase is
  below `10s`.

The telemetry threshold from Framing A remains useful for release-note
attribution: if xlarge ephemeral results phase is under `10s`, describe the
ticket as substrate/accounting-boundary work with modest wall recovery, not as
an optimization headline. It should not be the implementation gate.

## Parity Gate Scope For Framing B

Ticket 2 should require these gates:

1. **Event log preserved.** Existing event rows, event order, event IDs,
   `cash_delta`, `position_delta`, and materialized `meta_json` behavior remain
   compatible unless a deliberate schema/version note is added. Custom metrics
   that consume events must not lose their source.
2. **Equity parity.** Inline equity time series byte-identical or within the
   existing Kahan-vs-cumsum tolerance, with the tolerance mechanism named.
3. **Fill table parity.** OPEN/CLOSE split rows, quantities, prices, fees,
   action labels, and realized PnL match `ledgr_sweep_summary_from_ordered_events()`.
4. **Lot-state parity.** Per-event cumulative `realized_pnl` and `cost_basis`
   vectors match reconstruction.
5. **Opening-position / CASHFLOW coverage.** The
   `ledgr_lot_meta_is_opening(meta)` branch at `R/lot-accounting.R:193-201`
   must be tested, because Spike 12 measured FILL events only.
6. **Invalid/semantic-violation coverage.** Existing behavior for invalid fill
   rows, unsupported sides, `BUY_TO_COVER` while long, and `SELL_SHORT` while
   short must match durable extraction logic at `R/backtest.R:1135-1251`.
7. **Durable readback compatibility.** Durable `ledgr_extract_fills_impl()` and
   `ledgr_compute_metrics()` continue to work from persisted events; fold-time
   lot facts may accelerate fresh runs but cannot become the only source needed
   to interpret a persisted run.
8. **No strategy lookahead.** Lot state is updated after fill resolution and
   output emission for that fill, not exposed to the strategy callback for the
   same pulse. The strategy callback still sees pulse-start context.

## Implementation Gates Beyond Round 2

- Add an explicit design note in the v0.1.8.10 spec: "events remain canonical;
  inline accounting facts are derived caches and verifier targets."
- Decide whether durable output stores fold-produced lot facts in `meta_json`,
  a sidecar, or only in in-session typed metadata. If `meta_json` bytes change,
  call it a deliberate identity/version change; otherwise keep materialized
  event bytes stable and use typed attributes for fresh-run acceleration.
- Keep reconstruction code in place after Ticket 2. Remove or simplify it only
  after a later release has parity evidence from durable, ephemeral, opening
  positions, short/cover cases, and cost-model paths.
- Report telemetry regardless of the substrate decision. It is still required
  for closeout honesty, even though it should not gate the accounting-boundary
  move.

## Bottom Line

The maintainer's substrate-expansion reframe is correct, but only under an
event-preserving hybrid architecture. Move FIFO lot accounting into the fold
core because it is accounting state transition work and therefore belongs in
the substrate K1 will measure. Do not eliminate the event log, do not turn the
fold engine into the metric engine, and do not use the 7-10s R-side recovery as
the main justification. The justification is canonical accounting ownership
plus a cleaner future compiled-core boundary.
