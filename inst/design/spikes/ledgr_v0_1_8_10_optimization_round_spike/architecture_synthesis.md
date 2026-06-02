# v0.1.8.10 Optimization-Round Architecture Synthesis

**Date:** 2026-06-01 (Round 3 revision) - **Host:** local development host
(Windows, R 4.5.2, collapse 2.1.7, yyjsonr 0.1.22) - **Status:** v0.1.8.10
spec input (pre-RFC). Round-3 revision incorporating Codex's substrate-
decision peer review verdict (Framing B with event-preserving hybrid
constraint), Codex's Round-2 caveat findings, the Round-2 spike (Spike
12), and Codex's Round-1 adversarial review.

**Synthesises:** the original eleven Round-1 spikes (Spikes 1-11) plus
the Round-2 fold-time lot-accounting spike (Spike 12), the LDG-2476 /
LDG-2479 production baselines, the v0.1.8.9 release closeout, the
v0.1.8.9 architecture synthesis, the 2026-06-01 paired RFC cycle for
the strategy callback contract addendum + authoring helpers, the
horizon's 2026-06-01 substrate / K1 repo-split entries, and the Codex
Round-1 adversarial review (`architecture_synthesis_codex_review.md`)
that triggered Round 2.

**Why this exists:** the v0.1.8.10 round is the closing pass of the
v0.1.8.x single-core arc. The Round-1 synthesis over-bound two
implementation tickets from evidence that did not match current
production code. Round 2 corrects four blocking findings, adopts
Codex's caveats, and re-scopes the tickets.

K1 / `ledgrcore-spike` remains out of v0.1.8.10 scope per the horizon's
2026-06-01 repo-split decision. The substrate this round produces is
the post-v0.1.8.10 production-R baseline that K1 measurement compares
against.

## Revision History

**Round 1 synthesis (Spikes 1-11):** submitted to Codex for adversarial
review on 2026-06-01.

**Codex Round-1 adversarial review** (2026-06-01,
`architecture_synthesis_codex_review.md`): verdict **Reject pending
Round-2 synthesis**. Four blocking findings:

1. **Ticket 1's "fold engine already computes realized PnL / cost basis"
   claim is wrong.** The fold engine updates `state$positions` and
   `state$cash` at `R/fold-engine.R:354-361` but does NOT call
   `ledgr_lot_apply_event`. Lot machinery runs only in reconstruction.
   So Ticket 1's inline lot-state capture is not additive; it is a
   semantic MOVE of FIFO lot accounting into the fold engine. If the
   moved work costs as much as the eliminated reconstruction work, net
   wall recovery is much smaller than the Round-1 synthesis claimed.
2. **The Ticket 1 recovery projection used a stale pre-v0.1.8.9 anchor.**
   LDG-2476's 40.9s reconstruction at 68k events is pre-v0.1.8.9
   peer-benchmark; post-v0.1.8.9 peer ephemeral is 92.61s wall / 9.63s
   results phase (`v0_1_8_9_release_closeout.md:95-100`). LDG-2479
   workload-grid xlarge ephemeral baseline is 372.55s, not ~280s.
   Codex also replayed real peer SMA fills through
   `ledgr_lot_apply_event()` and measured max open lot depth of 1,
   contradicting the Round-1 caveat about "deeper production lots."
3. **The fill-proposal contract is wider than `next_open_price`, and
   the cited file does not exist.** `R/fold-fill-proposal.R` is not the
   right path — actual implementation is at `R/fill-model.R`.
   `ledgr_next_open_fill_proposal()` at `R/fill-model.R:18-96` reads
   `next_bar$instrument_id`, `next_bar$ts_utc`, and `next_bar$open`,
   then constructs an `execution_bar` with optional `high`, `low`,
   `close`, `volume` passed to cost resolvers. The simple "swap
   `next_bar` for `next_open_price`" framing was wrong; the contract
   needs explicit audit.
4. **The L10 wall projection table implied false precision.** Ticket 3
   was subtracted from the durable workload-grid cell without showing
   that cell exercises the reopen/DB-replay path Ticket 3 targets. The
   ~280s ephemeral baseline was wrong (372.55s actual). Ticket 1's
   ~80s recovery was not a current-source measured claim.

Codex's caveat-worthy findings:

- **The "93% lot replay" decomposition mixed two non-identical fixtures.**
  Spike 1's typed-meta 14s reconstruction vs Spike 10's untyped-meta
  16.5s lot replay. The split was directional, not decompositional.
- **Spike 6's 27x vs v0.1.8.9 anchor 166x is NOT timer-floor noise.**
  Codex re-ran a clean scalar matrix loop and measured 0.03s matching
  the v0.1.8.9 anchor. Spike 6's Variant C includes fixture overhead
  (`fills$inst_idx[[k]]` indexing per iteration). Wall recovery claim
  (~4.7s) still credible; explanation should be "fixture overhead"
  rather than "timer-floor noise."
- **Spike 2 should stay parked as fallback for the existing reconstruction
  path** if Ticket 1 becomes telemetry-gated.
- **Spike logs do not consistently include "test fails against unfixed
  implementation"** per the round README discipline rule (process note).

Codex's confirmed claims:

- Spike 7's options-hoist diagnosis verified by direct re-measurement
  (~0.95s constructing 50k opts vs ~0.11s parsing).
- Spike 2 faithfully measured production bucket loop.
- Spike 9's reframing supported by code path.
- Spike 4 parking correctly bounded as sub-surface measurement.
- v0.1.8.9 partial-setv doctrine preserved at
  `R/fold-reconstruction.R:439-450`.
- Accessor / helper RFC dependencies represented correctly.
- K1 correctly out of scope.

**Round-2 spike (Spike 12, LDG-2516):** spawned to close Finding 1.
Measured fold-time vs reconstruction-time lot accounting on shallow-
depth and deep-depth fixtures. **Result: lot machinery saves only
~22-27% when moved from reconstruction to fold.** The remaining
73-78% is intrinsic FIFO accounting work that runs wherever you put
it. Net synthetic Ticket 2 recovery at xlarge: ~7-10s, not 80-200s.

**Codex Round-2 review** (2026-06-01,
`architecture_synthesis_codex_review.md` round 2 section): verdict
**Approve With Caveats**. Five caveats: Spike 12's "shallow" / "deep"
fixture labels do not actually measure the lot-depth regimes they
claim (index-pairing bug; full-run depth unmeasured); peer-ratio
projection mixed workload-grid and peer-benchmark shapes; durable
math arithmetic slightly optimistic (220-227 should be 223-227);
"inline equity only, no parity gate" was too loose (still needs
equity-time-series gate; opening-position CASHFLOW coverage
required); parked-spike count inconsistent (was 5, should be 4).
All five patched into this revision.

**Maintainer substrate-expansion reframe** (2026-06-01, post-Codex-
Round-2): the maintainer raised "the more the fold core does, the
more things can get compiled" as a reframe of Ticket 2's gating —
substrate-decision rather than telemetry-conditional. The maintainer
also raised a specific concern about metric extensibility: "will we
be able to have other metrics if we do that?"

**Codex substrate-decision peer review** (2026-06-01,
`codex_substrate_decision_review.md`): verdict **Framing B with
event-preserving hybrid constraint**. Move FIFO lot accounting into
the fold core as a substrate decision, not a wall-recovery decision.
The load-bearing reason is accounting ownership (per-fill state
transitions belong with the fill that caused them) plus K1
substrate expansion. The metric-extensibility concern is resolved
under three architectural rules:

1. Events remain canonical (event log not elided).
2. Fold emits accounting facts, not metrics.
3. Reconstruction remains a verifier / fallback.

Codex specified eight parity gates and four implementation gates
beyond Round 2. All adopted in this revision (L7 Ticket 2,
Constraints section).

This Round-3 revision incorporates: Spike 12's numbers, all four
Round-1 Codex blocking findings, all five Round-2 Codex caveats, the
substrate-decision reframe verdict (Framing B with event-preserving
hybrid constraint), and Codex's eight + four gates. The ticket
roll-up (L7) is materially reshaped from Round 2: Ticket 2 changes
from telemetry-gated to substrate-decision committed under the
three architectural rules above. L9 is extended with the
substrate-expansion principle as the load-bearing reason for
Ticket 2.

---

## L1. Lot machinery is intrinsic FIFO work, not eliminable by moving the call site

Spike 12 measured the same lot machinery in three positions:

| Variant | Where lot machinery runs | Wall @ 130k xlarge | per-event |
|:--------|:-------------------------|------------------:|----------:|
| A (production)    | Reconstruction with meta_json parse  | 30.0s | 231 us |
| B (fold-time simple) | Fold engine with typed inputs       | 23.1s | 178 us |
| C (fold-time direct) | Fold engine, skip dispatcher        | 21.8s | 168 us |

**The savings of moving lot accounting from reconstruction to fold are
only ~22-27%** — the JSON-parse and dispatcher overhead. **The
remaining ~73-78% is intrinsic FIFO accounting work** (lot list
mutations, `ledgr_lot_set` cost-basis updates, realized PnL Kahan
accumulation) that runs whether the call site is reconstruction or
fold.

Parity passed (realized_pnl AND cost_basis byte-identical across all
variants at all measured fixture / scale combinations).

The Round-1 synthesis claim that "the fold engine already computes
realized_pnl / cost_basis" was wrong (per Codex Finding 1). The fold
engine has the typed *inputs* required to compute them inline (qty,
side, price); the computation itself is real work the fold does not
pay today.

The corrected sub-rule:

> **Inline lot-state capture is a semantic move of FIFO lot accounting
> into the fold path, not the elimination of FIFO accounting. The
> recoverable wall is the JSON-parse + dispatcher slice (~22-27% of
> reconstruction lot machinery cost), not the full lot-machinery cost.
> The remaining ~75% is intrinsic to FIFO semantics regardless of where
> the code runs.**

This reframes the v0.1.8.10 ephemeral lane from a headline recovery
(80-200s projected) to a small structural ticket (~7-10s synthetic,
production TBD via telemetry).

## L2. Matrix-canonical substrate is one architectural unit; the fill-proposal contract is wider than scalar `open`

Round-1 L2 stands: Spikes 3, 5, 6 converge on the matrix-canonical
substrate (integer-indexed `state$positions`, `ctx$vec` namespace,
scalar matrix lookup). But Codex Finding 3 corrects the scope:

- **The cited file `R/fold-fill-proposal.R` does not exist.** The actual
  implementation is `R/fill-model.R:18-96` (`ledgr_next_open_fill_proposal`).
- **The fill-proposal contract is wider than `next_open_price`.** The
  function reads `next_bar$instrument_id`, `next_bar$ts_utc`, and
  `next_bar$open`; constructs an `execution_bar` with optional
  `high`, `low`, `close`, `volume`; and passes that bar to cost
  resolvers. The default resolver currently reads only `open`
  (`R/fill-model.R:178`), but the contract supports OHLCV cost
  resolvers and the bound v0.1.9.x cost-API direction.

The corrected sub-rule:

> **Matrix-canonical substrate is one v0.1.8.10 implementation ticket.
> The signature change is not a simple `next_bar -> next_open_price`
> swap; it is a "construct a minimal execution-bar object from
> matrix-backed scalars" change that must preserve `instrument_id`,
> `ts_utc`, `open`, last-bar `NO_FILL` behavior, optional OHLCV
> semantics where observable, and the cost-resolver context shape.**

This requires an explicit fill-model contract audit before scope is
bound. The wall recovery (~4.7s) is preserved; the implementation
surface is wider than Round-1 claimed.

## L3. The reconstruction-pass bucket loop was wrongly hypothesised as a dominant cost

Spike 2's mechanism hypothesis was that 130M character-equality
comparisons would dominate. Measurement: 0.36s at xlarge — about 2.5%
of the reconstruction pass.

The disposition lesson (carried from Round 1, verified by Codex):

> **base-R's character-vector equality is implemented in highly optimised
> C. 130M comparisons execute in ~0.3s. Hot-loop hypotheses framed
> around "many comparisons" should be tested before scoping.**

Spike 2 re-confirmed the v0.1.8.7 collapse-vs-split doctrine
(`collapse::gsplit` 18x over current). Per Codex caveat 7, Spike 2
**stays parked but preserved as fallback** if Ticket 1 becomes
telemetry-gated below threshold. The collapse-doctrine continuity
finding is independent of Ticket 1's disposition.

## L4. Helper-indirection traps are a measurable cost class

Spike 7 finding stands and was independently verified by Codex
(local re-measurement: ~0.95s constructing 50k yyjsonr opts vs ~0.11s
parsing 50k payloads with prebuilt opts). The LDG-2501 regression
caveat is closeable by hoisting `yyjsonr::opts_read_json(...)` to a
package-level constant inside `ledgr_json_read_nested`.

The synthesis sub-rule:

> **Helper wrappers that construct option / config objects per call are
> a measurable cost class at production frequency. Audit for the pattern;
> hoist construction to package-level constants where the configuration
> is fixed.**

Companion sites to audit alongside the v0.1.8.10 patch:
`ledgr_json_read_config` (R/config-canonical-json.R:39-49) and
`ledgr_json_write_canonical_v2` (lines 51-62). All three deserve
the same hoist.

## L5. Two spikes had broken mechanism hypotheses, and the synthesis Round 1 had two more

Round-1 named two spike-spec hypothesis breaks (Spike 2 cost
hypothesis, Spike 9 per-pulse normalize location). Codex's adversarial
review found **two more in the Round-1 synthesis itself**:

- **The fold-time lot-accounting claim was wrong.** "Fold already
  computes realized_pnl / cost_basis" — verified false by inspecting
  `R/fold-engine.R:295-361`. The synthesis cited the inline-capture
  recovery as if the work was free; in reality the work has to happen
  in the fold instead.
- **The fill-proposal contract claim was wrong.** "The proposal
  function reads only `next_bar$open`" — verified false by inspecting
  `R/fill-model.R:18-96`. The contract is wider; the cited file was
  the wrong path entirely.

The discipline rule:

> **Synthesis claims that name what production code does should cite
> the exact line and verify. When the cited code is missing,
> mis-located, or doing something different from the claim, the
> synthesis is wrong about the implementation scope of the ticket it
> is recommending. Codex review is the safety net; spike numbers alone
> do not catch synthesis-level production-path mis-claims.**

This continues v0.1.8.9's L5 ("spike discipline rejects hypothesised
lanes before they get ticketed") but extends it: spike discipline
catches mis-scoped spikes; Codex review catches mis-scoped synthesis
claims about production code paths.

## L6. The Round-1 attribution split was directional, not decompositional

Per Codex caveat 5: Round-1 L1 split reconstruction cost as "93% lot
replay + 2.5% bucket + 3.5% other = ~14s". But Spike 1's reconstruction
was 14s on a typed-meta fixture; Spike 10's lot replay was 16.5s on
an untyped-meta fixture. A component cost larger than the total it
allegedly composes is a signal that the percentages are inferences
across fixtures, not a clean decomposition.

The corrected framing:

> **Lot machinery is the dominant candidate inside reconstruction
> cost.** Reconstruction has additional non-lot work (bucket loop,
> cash cumsum, fills tibble materialization, metrics) but the lot
> machinery line item is the largest single component. The exact share
> is not cleanly measurable from Round-1's two-fixture comparison;
> Spike 12 confirms the lot machinery is large enough that moving its
> call site saves ~22-27% of its cost (not 100% as Round 1 implied).

## L7. The v0.1.8.10 round's revised production tickets

The eleven Round-1 spikes plus Spike 12 produce a different ticket
roll-up than Round 1 claimed:

### Ticket 1 — Subphase telemetry (was: inline-state capture)

Spike 11 (LDG-2515) alone, decoupled from inline-state work.

The change from Round 1: Spike 11 was bundled into the inline-state
ticket as "infrastructure". Round 2 separates it because Spike 12
showed the inline lot-state recovery is small enough that telemetry
is now the GATE for whether the inline work ships at all.

Implementation: extend `ledgr_sweep_telemetry_env()` with three new
fields (`t_engine`, `t_results`, `t_fills_extract`); add proc.time
snapshots around the engine and reconstruction calls in
`ledgr_sweep_candidate_execute` (R/sweep.R:919-934); extend the
workload-grid harness CSV with three new columns. Six proc.time
calls + three env slots + three CSV columns.

Recovery: zero direct (this is infrastructure). Enables a production
measurement of how much the post-v0.1.8.9 ephemeral xlarge wall is
actually in the results / reconstruction phase. That measurement
gates Ticket 2 below.

### Ticket 2 — Fold-owned accounting (event-preserving hybrid)

Bundles Spikes 1 (inline equity) + Spike 10 / Spike 12 (fold-owned
lot accounting). **Substrate decision, not telemetry-gated** per
Codex's substrate-decision peer review.

The change from Round 2: this ticket is no longer gated on Ticket 1
producing the production measurement. The decision criterion is
semantic / parity-based, not wall-recovery-magnitude. The
load-bearing reason is **accounting ownership**: FIFO lot state is
per-fill state transition work; it belongs with the fill that caused
it. The fold engine owns cash and positions today; it should own
lots too. The R-side ~7-10s recovery from Spike 12 is incidental;
the load-bearing reasons are (i) cleaner accounting boundary, (ii)
larger and cleaner substrate for the post-v0.1.8.10 K1 measurement.

**Three architectural rules bound by the Codex substrate-decision
peer review:**

1. **Events remain canonical.** `ledgr_results(bt, "events")` and
   materialized event rows remain available. Inline accounting
   capture must not remove or weaken the event stream. Custom
   metrics that consume the event log retain their source.
2. **Fold emits accounting facts, not metrics.** The fold may emit
   per-fill realized PnL, cost basis, OPEN/CLOSE split, and per-pulse
   equity / cash / positions_value. It must NOT emit Sharpe, win
   rate, baseline-relative statistics, TCA, or walk-forward
   diagnostics. Those stay in metric-computation code (e.g.
   `ledgr_metrics_from_equity_fills` at `R/fold-metrics.R:9-50`).
3. **Reconstruction remains a verifier / fallback.** Fresh sweeps
   may bypass reconstruction for speed, but the event-stream
   reconstruction path stays available for durable readback, parity
   checks, and future diagnostics. Reconstruction code (
   `R/fold-reconstruction.R:376-572`) is NOT removed in v0.1.8.10;
   removal is a later release's decision after parity evidence from
   durable, ephemeral, opening positions, short/cover, and
   cost-model paths.

**Decision rule (semantic / parity-based, not wall-magnitude):**

- IF fold-time accounting can preserve the event stream and produce
  byte-equivalent accounting outputs against reconstruction: SHIP
  both inline equity and fold-owned lot accounting.
- IF preserving the event stream or durable readback contract
  requires schema churn beyond v0.1.8.10 scope: SHIP inline equity
  now (additive; fold already has cash + positions) and move
  fold-owned lots to the next accounting-boundary ticket.
- Do NOT park fold-owned lots solely because the production results
  phase is below ~10s. Telemetry magnitude is for release-note
  attribution, not for the implementation gate.

**Recovery (incidental, for release-note attribution only):**

- Synthetic xlarge: ~7-10s (Spike 12 net savings of moving lot
  machinery into fold). Production via Ticket 1 telemetry.
- Real load-bearing benefit: canonical accounting ownership and a
  larger / cleaner K1 measurement substrate.

**Parity gates (eight, per Codex substrate-decision peer review):**

1. **Event log preserved.** Existing event rows, event order,
   event IDs, `cash_delta`, `position_delta`, and materialized
   `meta_json` behavior remain compatible unless a deliberate
   schema/version note is added.
2. **Equity parity.** Inline equity time series byte-identical or
   within the existing Kahan-vs-cumsum tolerance, with the tolerance
   mechanism named (per v0.1.8.9 L4 attribution rule).
3. **Fill table parity.** OPEN/CLOSE split rows, quantities,
   prices, fees, action labels, and realized PnL match
   `ledgr_sweep_summary_from_ordered_events()`.
4. **Lot-state parity.** Per-event cumulative `realized_pnl` and
   `cost_basis` vectors match reconstruction (Spike 12 confirmed
   for FILL events; CASHFLOW opening separately required per gate 5).
5. **Opening-position / CASHFLOW coverage.** The
   `ledgr_lot_meta_is_opening(meta)` branch at
   `R/lot-accounting.R:193-201` must be tested.
6. **Invalid / semantic-violation coverage.** Existing behavior for
   invalid fill rows, unsupported sides, `BUY_TO_COVER` while long,
   and `SELL_SHORT` while short must match durable extraction logic
   at `R/backtest.R:1135-1251`.
7. **Durable readback compatibility.** Durable
   `ledgr_extract_fills_impl()` and `ledgr_compute_metrics()`
   continue to work from persisted events; fold-time lot facts may
   accelerate fresh runs but cannot become the only source needed
   to interpret a persisted run.
8. **No strategy lookahead.** Lot state is updated after fill
   resolution and output emission for that fill, not exposed to
   the strategy callback for the same pulse. The strategy callback
   still sees pulse-start context.

**Variant disposition.** Variant C (`ledgr_lot_apply_fill` direct,
skipping the `ledgr_lot_apply_event` dispatcher) is NOT recommended
per Spike 12: only ~4% additional savings over Variant B (~1-2s
extra wall), not worth the extra contract surface.

### Ticket 3 — Matrix-canonical substrate + accessor RFC implementation

Bundles Spikes 3, 5, 6. Same structure as Round 1's Ticket 2 with
two corrections per Codex Finding 3:

- File path corrected: `R/fill-model.R`, not `R/fold-fill-proposal.R`.
- Contract surface corrected: not a `next_bar -> next_open_price`
  signature swap. The implementation constructs a minimal
  execution-bar object from matrix-backed scalars (`instrument_id`,
  `ts_utc`, `open`, optional OHLCV) for the cost-resolver context.

Implementation surface:

- `state$positions` as bare `numeric()` + `id_to_idx` map (Spike 3).
- `ctx$vec` namespace bound by the accessor RFC synthesis (Spike 5).
- Matrix-backed scalar next-bar lookup with minimal execution-bar
  construction (Spike 6 + Codex Finding 3 contract audit).

Recovery: ~5-6s durable xlarge wall combined. Load-bearing for the
accessor RFC implementation, helpers RFC Pass 1, and post-v0.1.8.10
K1 baseline.

The contract audit required by Finding 3:

1. Identify every caller of `ledgr_next_open_fill_proposal()`.
2. Identify every cost resolver consuming the execution-bar context
   (default + any user-defined; check accepted v0.1.9.x cost-API
   synthesis for required fields).
3. Write down the minimum preserved contract: `instrument_id`,
   `ts_utc`, `open`, optional OHLCV, last-bar `NO_FILL` warning path,
   cost-resolver context shape.
4. Verify the matrix-backed implementation preserves that contract.
5. Add parity tests covering each contract element.

### Ticket 4 — yyjsonr helper options-hoist closeout patch

Spike 7 (LDG-2511) alone. Two-line patch hoisting
`yyjsonr::opts_read_json(...)` to a package-level constant.
Companion sites: `ledgr_json_read_config` and
`ledgr_json_write_canonical_v2` get the same hoist.

Recovery: ~2-3s production on reopen / DB-replay paths. Closes
LDG-2501 regression caveat.

The patch is small enough to ride along with any other ticket.

## L8. Parked spikes (4 of 12)

| Spike | Disposition | Why |
|:------|:------------|:----|
| Spike 2 (split bucket)        | Parked, preserved as fallback | If Ticket 2 (inline state) parks below threshold per Ticket 1 measurement, Spike 2's bucket optimization remains as small standalone reconstruction-path cleanup. Per Codex caveat 7. |
| Spike 4 (env reuse)           | Parked (sub-surface) | Measured pure list-allocation cost; production cost lives in helper attachment per L6 / Codex confirmed. |
| Spike 8 (pulse_seed mixer)    | Parked (below threshold) | 0.14s standalone at xlarge; preserve as v0.1.9+ candidate. Implementation caveat: 32-bit overflow requires `bit64` or C-implemented mixer. |
| Spike 9 (alias_map normalize) | Parked (subsumed) | The accessor RFC's bulk-read `ctx$vec$feature(feature_id)` collapses the per-accessor-call worst case. Codex confirmed reframing. |

None of these are negative findings about the architecture. All have
clear disposition rationales independent of Ticket 1's reshape.

## L9. Post-v0.1.8.10 R-side baseline is the K1 measurement substrate; substrate expansion is the load-bearing principle

L9 from Round 1 stands and extends to Ticket 2 per the Codex
substrate-decision peer review.

**Ticket 3 (matrix-canonical substrate + accessor RFC)** produces the
four boundary-crossing surfaces a compiled fold core would consume:

- The `id_to_idx` map at fold setup.
- The bare-numeric `state$positions` (no names, no list wrapping).
- The `ctx$vec` namespace with universe-aligned numeric accessors.
- The matrix-backed scalar next-bar lookup at fold-engine fill
  proposal.

**Ticket 2 (fold-owned accounting)** extends the substrate to include
per-fill FIFO state transitions. Per Codex substrate-decision review:

- The R fold engine IS the compiled-core substrate. Every operation
  it owns today becomes a candidate for compilation tomorrow.
- If FIFO lot accounting stays in reconstruction, the K1 measurement
  spike measures compiled fold (no lot) vs R fold (no lot) — same
  comparison surface, no improvement from moving the work.
- If FIFO lot accounting moves INTO the fold, K1 measures compiled
  fold + accounting vs R fold + accounting — strictly larger surface
  for compiled to demonstrate value on, AND a cleaner compiled
  architecture (one hot path with accounting work; no separate
  compiled reconstruction pass).
- The substrate-expansion principle is the load-bearing reason for
  Ticket 2, not the ~7-10s R-side recovery from Spike 12.

The substrate-expansion sub-rule:

> **Every operation the R fold engine owns becomes K1 measurement
> surface. The decision to move state-transition work into the fold
> is a substrate decision, not a wall-recovery decision. The
> load-bearing reasons are accounting boundary cleanliness (per-fill
> state transitions belong with the fill that caused them) and
> compiled-core comparison surface expansion (the K1 spike measures
> what the R fold owns, so moving work into the fold expands what
> K1 can compare).**

K1 / `ledgrcore-spike` measurement against post-v0.1.8.10 production
R remains the next conversation; this round produces the baseline
as a side effect of Tickets 2 and 3 combined.

**Counter-risk acknowledged.** If `ledgrcore-spike` reports "do not
build", the project has paid the parity-gate cost for Ticket 2's
fold-owned accounting work without K1 consuming the substrate. Per
Codex review: that cost is acceptable only because the accounting-
ownership argument is independently justified (cleaner per-fill
boundary; state transitions belong with the fill), not solely as
speculative compiled-core prework.

## L10. The v0.1.8.10 round closes the v0.1.8.x single-core arc with smaller ticket scope

v0.1.8.9 closed the durable-path wall (445s -> 232s). v0.1.8.10's
tickets are now substantially smaller than Round 1 projected:

| Ticket | Spikes | Recovery (range) | Gating |
|:-------|:-------|:----------------|:-------|
| 1. Subphase telemetry          | 11 | 0s direct (infrastructure) | None |
| 2. Fold-owned accounting       | 1 + 10 + 12 | ~5-10s ephemeral (synthetic; production via Ticket 1 telemetry — informational, not gating) | Substrate decision; bound by 8 parity gates per Codex substrate-decision review |
| 3. Matrix-canonical substrate  | 3 + 5 + 6 | ~5-6s durable | Bound; contract audit required |
| 4. yyjsonr opts hoist          | 7 | 0-3s reopen-paths | None |

Per the Codex substrate-decision peer review: Ticket 2's wall
recovery is informational, not gating. The decision to ship Ticket 2
is semantic / parity-based per L7 + L9. Production wall measurement
via Ticket 1 telemetry remains valuable for release-note attribution
honesty, but does not gate Ticket 2's implementation scope.

What can be said with current evidence:

- **Durable xlarge cell (232s post-v0.1.8.9)**: Ticket 3 lands ~5-6s
  recovery. Ticket 4 lands 0-3s recovery IF the durable workload-grid
  cell exercises the reopen / DB-replay path at sufficient frequency
  (currently unverified; the path is hit on result extraction but the
  hot-path frequency at the workload-grid cell needs confirmation).
  **Projected durable post-v0.1.8.10 wall: 223-227s** (rough range,
  arithmetic: 232 - 5.5 +/- 1.5 - 0..3).

- **Ephemeral xlarge cell (372.55s post-v0.1.8.9 workload-grid
  baseline per Codex citation)**: Ticket 2 recovery range is wide
  pending Ticket 1 measurement. Upper bound from Spike 12 synthetic
  (~10s) plus Ticket 3 shared recovery (~5s) plus Ticket 4 (~2s
  if applicable) is ~17s. Lower bound if Ticket 2 parks is ~5-7s
  (just Tickets 3 and 4). **Projected ephemeral post-v0.1.8.10 wall:
  355-368s** (rough range, conservative).

The arc closes with R-side optimization mostly exhausted to the extent
single-core mechanical fixes can reach. Further wall recovery requires
either compiled-core (`ledgrcore-spike` track) or architectural changes
outside the v0.1.8.x scope.

Post-v0.1.8.10 peer ratios vs Backtrader (rough projection — peer
benchmark shape only, NOT workload-grid shape; the two shapes are
not interchangeable per Codex Round-2 caveat):

- Durable engine ratio: 1.12x (largely unchanged from post-v0.1.8.9;
  Ticket 3 trims a few seconds of engine time).
- Durable total wall ratio: ~1.40-1.45x.
- Ephemeral total wall ratio at the PEER BENCHMARK shape: ~1.15-1.20x
  (post-v0.1.8.9 peer ephemeral 92.61s vs Backtrader 79.34s per
  `v0_1_8_9_release_closeout.md:95-100`, lightly improved by Tickets
  3 and 4).

Workload-grid xlarge wall is a separate (heavier) shape from peer
benchmark wall and the two should not be divided to produce a "ratio".
The workload-grid projected wall in the ranges above is the
load-bearing v0.1.8.10 release-gate number; the peer ratios above are
informational continuity with the v0.1.8.9 closeout.

---

## Constraints carried into v0.1.8.10

These are the gates v0.1.8.10 implementation must respect:

1. **Determinism gate** still mandatory for value-bearing collapse ops.
   None of the recommended fixes are value-bearing; they don't reorder
   floating-point reductions.
2. **Byte-identical event-stream parity** required for any fix touching
   the event log. Ticket 2's inline lot-state capture requires
   `event_realized` / `event_cost_basis` byte-identical between the
   moved fold-time computation and the existing reconstruction-time
   computation. Spike 12 confirmed parity at all measured fixtures.
3. **Strategy callback contract addendum binding from the 2026-06-01
   RFC synthesis** for Ticket 3.
4. **Helpers RFC Pass 1 for Ticket 3** (existing helpers consume
   `ctx$vec` internally, no public surface change). Pass 2 is v0.1.9.x.
5. **Snapshot semantics preserved for `state$positions`.** Spike 3
   env_positions (16x R-side win) is NOT the recommended variant
   because it changes `ctx$positions`-captured-at-pulse-start snapshot
   semantics. The recommended intvec_id_map variant preserves
   snapshot semantics.
6. **Workload-grid baseline re-measurement** after each ticket lands.
   Ticket 1 specifically requires the LDG-2479 xlarge_ephemeral cell
   to be rerun with subphase telemetry as the gate for Ticket 2.
7. **Fill-model contract audit** required for Ticket 3 before scope is
   bound (per L2). The minimum preserved contract: `instrument_id`,
   `ts_utc`, `open`, optional OHLCV, last-bar `NO_FILL` behavior,
   cost-resolver context shape.
8. **Eight parity gates for Ticket 2** (per Codex substrate-decision
   peer review). Listed in full at L7 Ticket 2. Summary: event log
   preserved; equity parity; fill table parity; lot-state parity;
   opening-position / CASHFLOW coverage; invalid / semantic-violation
   coverage; durable readback compatibility; no strategy lookahead.

### Implementation gates beyond Round 2 (per Codex substrate-decision review)

These gates apply to the v0.1.8.10 spec packet and the Ticket 2
implementation specifically:

A. **Explicit design note in the v0.1.8.10 spec.** State the rule:
   "events remain canonical; inline accounting facts are derived
   caches and verifier targets." The fold engine does not become the
   metric engine; the event log is not elided; reconstruction stays
   available as verifier / fallback.

B. **Durable lot-fact storage decision.** Decide whether durable
   output stores fold-produced lot facts in `meta_json`, a sidecar,
   or only in in-session typed metadata. If `meta_json` bytes change,
   call it a deliberate identity / version change in the v0.1.8.10
   spec packet. Otherwise keep materialized event bytes stable and
   use typed attributes for fresh-run acceleration. The default
   should preserve `meta_json` byte stability unless there is an
   explicit identity-version-bump justification.

C. **Reconstruction code retention.** Keep
   `ledgr_sweep_summary_from_ordered_events()` and adjacent
   reconstruction code in place after Ticket 2 lands. Remove or
   simplify only after a later release has parity evidence from
   durable, ephemeral, opening positions, short/cover cases, and
   cost-model paths. Reconstruction is the canonical fallback for
   any persisted-run readback that the inline path does not yet
   cover.

D. **Telemetry-reporting commitment.** Ship Ticket 1 (subphase
   telemetry) and report telemetry numbers regardless of Ticket 2's
   substrate decision. Telemetry is required for closeout honesty
   (release-note attribution; future workload-grid sweep
   diagnostics) even though it should not gate the
   accounting-boundary move.

## v0.1.8.10 spec inputs

The v0.1.8.10 spec packet, when cut, should pull from:

- This synthesis (Round 2, architectural lessons L1-L10).
- The Codex Round-1 adversarial review
  (`architecture_synthesis_codex_review.md`) for the findings that
  reshaped the tickets.
- The per-spike `.md` logs in `dev/spikes/`:
  - Round 1: spikes 1-11 (the original eleven).
  - Round 2: `spike-fold-time-lot-accounting.md` (Spike 12, the
    Round-2 spike that closed Codex Finding 1).
- The round `README.md` and `spike_tickets.md`.
- `inst/design/rfc/rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md`
  (binding for Ticket 3).
- `inst/design/rfc/rfc_strategy_authoring_helpers_v0_1_8_x_synthesis.md`
  (binding Pass 1 for Ticket 3; Pass 2 deferred to v0.1.9.x).
- `inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md`
  for current-source production anchors (post-v0.1.8.9 peer ephemeral
  92.61s wall / 9.63s results phase; workload-grid xlarge ephemeral
  372.55s).
- The v0.1.8.9 architecture synthesis for doctrine continuity.
- `inst/design/horizon.md` 2026-06-01 entries.

---

## Caveats and known limitations of this round's evidence

This synthesis acknowledges where the evidence is bounded:

- **Spike 12 measured synthetic fixtures.** Production measurement
  remains the only path to confirm Ticket 2's recovery range. Spike 11
  telemetry exposure (Ticket 1) is the prerequisite.

- **Spike 12's "deep" fixture does not actually measure deep lots**
  (Codex Round-2 caveat 1). The fixture pairs
  `ev_inst_idx <- rep(seq_len(n_inst), length.out = n_fills)` with
  `ev_side <- ifelse(seq_len(n_fills) %% 4L == 0L, "SELL", "BUY")`;
  because the measured `n_inst` values (500, 1000) are divisible by 4,
  each instrument receives a FIXED side pattern (all BUYs or all SELLs)
  rather than the intended 3:1 BUY:SELL per instrument. The same
  index-pairing issue affects the "shallow" fixture's BUY/SELL
  alternation. The reported "max depth = 2-4" measurements were
  computed on only the first 2000 events
  (`spike-fold-time-lot-accounting.R:257`), so they do not reflect
  full-run depth either. **Codex's lot-depth-of-1 finding on real peer
  SMA fills is the actual production anchor**, not Spike 12's
  fixtures. The per-event TIMING measurements in Spike 12 remain
  valid as cost evidence on whatever lot-state shapes the fixtures
  produced; the SHAPE labels ("shallow" / "deep") should not be read
  as representative-of-production-strategy-shapes. Deep-lot strategy
  shapes (long-hold accumulating positions over many pulses) are
  UNMEASURED this round.

- **The fill-model contract audit (per L2) has not been done.** Ticket
  3 cannot be scoped until that audit lands.

- **Spike 6 absolute speedup (27x) was lower than v0.1.8.9 anchor
  (166x).** Per Codex caveat 6 the difference is fixture overhead in
  the spike script, not a production change. Wall recovery (~4.7s)
  preserved.

- **Spike 1's reconstruction-pass measurement (14s) is bounded above
  by Spike 12's reconstruction-with-meta-parse (30s at xlarge)** —
  different fixtures pay different JSON-parse costs. Production cost
  sits somewhere between depending on the meta-typed vs meta-untyped
  share.

- **Round-1's "fold engine already computes realized_pnl / cost_basis"
  claim was wrong.** This synthesis explicitly retracts it; Codex
  Finding 1 is the canonical record.

- **The Round-1 ~80-200s Ticket 1 recovery projection was wrong.**
  Per Spike 12 the synthetic recovery is ~7-10s; production recovery
  is bounded above by the post-v0.1.8.9 results-phase share.

- **Spike logs do not consistently include a "test fails against
  unfixed implementation" line.** Per Codex caveat 8 this is a process
  note for future spike rounds; not blocking for v0.1.8.10 scope.

---

## Closing

The v0.1.8.10 round's revised architectural read is: **the residual
single-core cost after v0.1.8.9 is smaller than the Round-1 synthesis
claimed. Three of the four production tickets are bounded and
implementable (Ticket 1 telemetry, Ticket 3 substrate + accessor RFC,
Ticket 4 yyjsonr hoist); the fourth (Ticket 2 inline-state capture) is
gated on Ticket 1 production measurement and shrinks from headline to
small-structural-cleanup if telemetry shows the results phase is small.**

The discipline rules carried forward from v0.1.8.9 — spike to confirm
mechanism, direct timing measurement, Amdahl-bounded wall translation,
real-run re-profile as verdict, negative results park hypothesised
lanes — applied a third time and refined with three new rules:

- L3: "many comparisons" hot-loop hypotheses should be tested before
  scoping; base-R character-vector C ops are fast enough that the loop
  body usually dominates.
- L4: helper wrappers constructing per-call option / config objects are
  a measurable cost class; audit for the pattern.
- L5: synthesis claims that name what production code does must cite
  the exact line and verify. Codex review catches mis-scoped synthesis
  claims that spike numbers alone cannot. The Round-1 synthesis had
  TWO production-path mis-claims that Codex's review surfaced; both
  are corrected here.

The most important meta-lesson of this round: **Codex review caught
two wrong production-code claims in the Round-1 synthesis. Both would
have shipped as v0.1.8.10 tickets with broken implementation scope.
The Round-2 review pattern from v0.1.8.9 is now validated at three
synthesis cycles. It continues to work.**

This synthesis is Round-2 (post-Codex-Round-1-review). A Codex
Round-2 review is the appropriate next step before binding the
v0.1.8.10 spec packet. The Round-2 review should specifically check:

- Whether the L7 ticket reshape (especially Ticket 2's gating
  language) is consistent with the Spike 12 evidence.
- Whether the L2 contract audit description for Ticket 3 names all the
  necessary preserved contract elements.
- Whether the L10 wall projection ranges are appropriately
  uncommitted given Ticket 1's measurement gate.
- Whether any other Round-1 claim that was not flagged in Round-1
  review needs correction in light of Round 2's reshape.
