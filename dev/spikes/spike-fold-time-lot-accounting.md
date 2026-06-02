# Spike Log: Fold-Time Lot Accounting vs Reconstruction-Time

**Date:** 2026-06-01 (Round 2 spike) - **Host:** local development host
(Windows, R 4.5.2, collapse 2.1.7, yyjsonr 0.1.22) - **Status:** v0.1.8.10
spike-round Round-2 spike (LDG-2516, Spike 12). Spawned by Codex's
adversarial review of the Round-1 architecture synthesis.

## Codex Round-2 Errata (2026-06-01)

Codex's Round-2 review found that this spike's "shallow" and "deep"
fixtures do not actually measure the lot-depth regimes their labels
imply. The pairing of
`ev_inst_idx <- rep(seq_len(n_inst), length.out = n_fills)` with
`ev_side <- ifelse(seq_len(n_fills) %% K == 0L, "SELL", "BUY")`
gives each instrument a FIXED side pattern when `n_inst` divides
evenly into the period — at the measured scales (500 inst, 1000 inst)
both fixtures collapse to "BUY-only instruments + SELL-only
instruments" rather than the intended alternating or 3:1 per-instrument
patterns. The "max open lot depth" diagnostic was also measured on
only the first 2000 events (line 257 of the script), so full-run
depth is unknown.

**What this means for the findings below:**
- The per-event TIMING measurements (VarA/B/C wall, us/event) remain
  valid as cost evidence on whatever lot-state shapes the fixtures
  produced.
- The SHAPE labels ("shallow" / "deep") should not be read as
  representative-of-production-strategy-shapes.
- The "production lot machinery cost is well-approximated by these
  synthetic measurements" claim in the Findings section below is
  **retracted**. Codex's lot-depth-of-1 measurement on real peer SMA
  production fills is the actual production anchor.
- Deep-lot strategy shapes (long-hold accumulating positions across
  many pulses) are UNMEASURED.

The core fold-time-vs-reconstruction-time question (the spike's load-
bearing finding) is unaffected: VarB saves 22-27% over VarA at all
measured fixture/scale combinations, parity passed at all combinations.
That is the evidence the architecture synthesis uses to retract its
Round-1 "fold engine already computes realized_pnl / cost_basis"
claim.

**Script:** `dev/spikes/spike-fold-time-lot-accounting.R`. Raw CSV:
`dev/bench/results/spike_fold_time_lot_accounting.csv`.

**Relates to:**
- `R/lot-accounting.R:74-217` (`ledgr_lot_apply_fill` /
  `ledgr_lot_apply_event` — the lot machinery)
- `R/fold-engine.R:295-361` (fold engine; does NOT call lot machinery
  today — per Codex)
- `R/fold-reconstruction.R:454-504` (reconstruction lot replay — the
  current home of lot machinery)
- `dev/spikes/spike-inline-lot-state.{R,md}` (Spike 10 — measured
  reconstruction-time lot cost; this spike answers whether moving it
  into the fold saves wall)
- `architecture_synthesis_codex_review.md` Finding 1 (the review that
  prompted this spike)

## Question

Codex Finding 1 challenged the Round-1 synthesis claim that "the fold
engine already computes realized PnL / cost basis." Verification: the
fold engine does NOT call `ledgr_lot_apply_event` today; lot machinery
runs only in the reconstruction pass. So Ticket 1's "inline lot-state
capture" is not additive — it is a semantic move of FIFO lot accounting
INTO the fold engine.

The question Round-2 must answer: **does moving lot accounting from the
reconstruction pass into the fold engine actually save wall on the same
events?**

Decision rule:
- VarB savings > 50% at xlarge → simple PROCEED (Ticket 1 keeps headline
  character).
- VarC savings > 80% at xlarge → optimized PROCEED (skip dispatcher
  wrapper).
- Neither > 30% → PARK lot-state migration; ship inline equity only.

## Method

Three variants of the lot accounting work, applied to the same event
stream:

Variant A: reconstruction-time lot replay (production today). Parses
`meta_json` per event via `ledgr_json_read_nested`, then calls
`ledgr_lot_apply_event(state, event_type, instrument_id, side, qty,
price, fee, meta)`. Same code path as
`R/fold-reconstruction.R:454-504`.

Variant B: fold-time simple. Calls `ledgr_lot_apply_event(...)` per
fill with `meta = NULL` (the fold engine already has typed values
directly; no JSON parse needed).

Variant C: fold-time direct. Calls `ledgr_lot_apply_fill(...)` directly,
skipping the `ledgr_lot_apply_event` dispatcher overhead.

Two fixtures address Codex's lot-depth observation (Codex measured max
open lot depth = 1 on real peer SMA production fills):

- **Shallow**: alternating BUY/SELL per instrument; max depth = 1-2.
  Matches Codex's peer SMA evidence.
- **Deep**: 3 BUYs + 1 SELL repeating per instrument; max depth = 2-4
  at the measured scales. Approximates long-accumulate / buy-and-hold.

Note: even the "deep" fixture reaches only depth 2 at xlarge because
130k fills / 1000 inst = 130 fills per instrument; the 3:1 pattern
keeps the inventory shallow at that density. Production strategies
with sparse turnover would build deeper lots; that case is not
measured here.

Parity gate: `event_realized` + `event_cost_basis` vectors
byte-identical across variants.

## Results

```
fixture  scale  n_fills  depth   VarA_s   VarB_s   VarC_s  B_save%
shallow  68k     68324      4   13.795   10.770   10.130    21.9%
shallow  130k   130000      2   30.005   23.070   21.775    23.1%
deep     68k     68324      4   15.630   12.235   11.560    21.7%
deep     130k   130000      2   32.800   24.025   22.495    26.8%
```

**Parity (realized_pnl AND cost_basis): PASS at all four
fixture/scale combinations across A=B, A=C.**

### Per-event cost

| Fixture | Scale | VarA us/event | VarB us/event | VarC us/event |
|--------:|------:|--------------:|--------------:|--------------:|
| shallow |  68k  |        201.9  |        157.6  |        148.3  |
| shallow | 130k  |        230.8  |        177.5  |        167.5  |
| deep    |  68k  |        228.8  |        179.1  |        169.2  |
| deep    | 130k  |        252.3  |        184.8  |        173.0  |

Per-event cost grows with universe size in all variants — the per-
instrument lot-list state grows even at shallow depth because more
instruments mean more lot-list lookups per event sequence.

### Decision rule outcome at xlarge

```
Shallow (depth=2): VarB 23.1% savings, VarC 27.4% savings
Deep    (depth=2): VarB 26.8% savings, VarC 31.4% savings
```

**Neither VarB nor VarC reaches the 50% threshold; only deep/130k VarC
just barely clears the 30% PARK threshold.** Per the decision rule:
borderline PARK / small-PROCEED.

## Findings

**Codex Finding 1 is empirically confirmed.** Moving lot accounting
from reconstruction to fold engine saves the JSON-parse + dispatcher
overhead (~22-27% of lot machinery cost), but the remaining 73-79% is
intrinsic FIFO accounting work that runs wherever you put it. The
synthesis's Round-1 claim that the work "is already computed by the
fold engine" was wrong; lot machinery is a real cost that the fold
engine does not pay today.

**Net Ticket 1 recovery is much smaller than Round 1 claimed.** The
synthetic xlarge measurement:

- VarA reconstruction lot machinery: ~30s (this is what Ticket 1
  eliminates from the reconstruction pass).
- VarB fold-time lot machinery: ~23s (this is what Ticket 1 ADDS to
  the fold engine).
- **Net wall savings: ~7s** (Variant B) or ~8-10s (Variant C).

Plus eliminated non-lot reconstruction costs from Spike 1:
- Bucket loop (Spike 2): ~0.36s.
- Cash cumsum + fills tibble materialization + metrics: ~0.5-1s.

**Total synthetic Ticket 1 recovery on xlarge ephemeral: ~8-12s, not
the ~80-200s the Round-1 synthesis projected.**

**The Variant C optimization (skip dispatcher) is small.** ~4% extra
savings over VarB across all four cells. The per-event work in
`ledgr_lot_apply_fill` itself (FIFO state mutations,
`ledgr_lot_set` cost-basis updates) dominates over the dispatcher
overhead. Implementing VarC is not worth the extra contract surface
for ~1-2s extra wall recovery.

**Lot depth at xlarge does not reach Round-1's "deeper than synthetic"
hypothesis.** Both shallow and deep fixtures peak at depth 2 at 130k
fills / 1000 inst. Per-event cost differs by only ~5% between shallow
and deep at xlarge. Codex's observation that real peer SMA fills had
max depth 1 is consistent — at production densities the lot-list depth
stays shallow regardless of strategy shape. **Production lot machinery
cost is therefore well-approximated by these synthetic measurements;
the Round-1 caveat about "deeper production lots" was not supported.**

### Wall translation to production

The post-v0.1.8.9 peer ephemeral row (per Codex's review citing
`v0_1_8_9_release_closeout.md:95-100`) is **92.61s wall with 9.63s
results phase**. The synthetic VarA at 68k fills is 13.8s — slightly
above the production results phase. Scaling roughly linearly:

- Synthetic Ticket 1 net savings at 68k: ~3.0-3.7s.
- Production results phase at 68k peer shape: 9.63s total. Maximum
  Ticket 1 recovery is bounded above by that.
- LDG-2479 xlarge ephemeral baseline: 372.55s (Codex citation;
  workload-grid baseline, not peer). Without phase telemetry exposure
  we cannot attribute the share that is results phase vs engine.

**Net production Ticket 1 recovery is at most ~3-10s, conditional on
the results phase remaining a meaningful share of post-v0.1.8.9
ephemeral wall.** This is dramatically smaller than the Round-1
synthesis claim of 80-200s.

## Disposition

**Ticket 1 reshapes from "headline ephemeral recovery lane" to "small
structural ticket gated on telemetry."** The three sub-components have
different shapes now:

- **Inline equity capture (Spike 1)**: still additive. Fold engine has
  cash + positions; emit per-pulse equity vector. Recovery is
  modest (~1-2s eliminated reconstruction overhead).
- **Inline lot-state capture (Spike 10 + this spike)**: semantic
  move with parity gates. Net savings ~5-10s production at most.
  PROCEED-IF Spike 11 telemetry confirms results phase remains
  material on post-v0.1.8.9 workload-grid xlarge ephemeral.
- **Subphase telemetry (Spike 11)**: now the load-bearing prerequisite.
  Must land first to gate the inline lot-state decision.

**Variant C (skip dispatcher) is not worth shipping.** The ~1-2s extra
wall recovery does not justify the contract change (one more function
on the fold-engine hot path) and parity-test surface.

**Recommended Round-2 disposition for Ticket 1:**

1. SHIP Spike 11 subphase telemetry as an infrastructure ticket
   (independent of inline-state work).
2. Rerun LDG-2479 `density_high_xlarge_ephemeral` cell with
   subphase telemetry.
3. IF the results phase remains > ~10s on the production xlarge
   ephemeral cell after telemetry exposure, ticket inline equity +
   inline lot-state as one architectural change.
4. IF the results phase is < ~10s post-v0.1.8.9, ship inline equity
   only (additive; no parity gate needed); park inline lot-state as
   future structural cleanup with no wall justification.

## Source references

- `R/lot-accounting.R:74-96` (`ledgr_lot_apply_fill` — the FIFO
  accounting hot frame this spike measures)
- `R/lot-accounting.R:180-217` (`ledgr_lot_apply_event` — the
  dispatcher VarC skips)
- `R/fold-engine.R:295-361` (fold path WITHOUT lot machinery today;
  this is what Ticket 1's inline-lot variant would extend)
- `R/fold-reconstruction.R:454-504` (current lot machinery home; this
  is what Ticket 1 eliminates from reconstruction)
- `dev/spikes/spike-inline-lot-state.{R,md}` (Spike 10, prior
  measurement: ~16.5s reconstruction lot cost at xlarge with heavier
  meta-parse fixture)
- `inst/design/spikes/ledgr_v0_1_8_10_optimization_round_spike/architecture_synthesis_codex_review.md`
  Finding 1 (the review motivating this spike)
- `inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md`
  (post-v0.1.8.9 production anchors)
