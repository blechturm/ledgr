# Spike Log: Inline Equity Accumulation In Memory Output Handler

**Date:** 2026-06-01 - **Host:** local development host (Windows, R 4.5.2,
collapse 2.1.7, yyjsonr 0.1.22) - **Status:** v0.1.8.10 spike-round
Batch A input (LDG-2505, Spike 1).

**Script:** `dev/spikes/spike-inline-equity-accumulation.R`. Raw CSV:
`dev/bench/results/spike_inline_equity_accumulation.csv`.

**Relates to:**
- `dev/spikes/spike-event-stream-reconstruction.{R,md}` (prior baseline
  measurement of the reconstruction pass)
- `R/fold-reconstruction.R:376-572`
  (`ledgr_sweep_summary_from_ordered_events` — the function this spike
  is trying to eliminate from the ephemeral hot path)
- `R/fold-engine.R:181-194` (where inline equity is already computed
  per pulse as `state$cash + positions_value`; the prototype handler
  just needs to capture it)
- `R/sweep.R:957-1190` (`ledgr_memory_output_handler` — the production
  baseline handler)
- LDG-2515 / Spike 11 (paired infrastructure; ephemeral subphase
  telemetry exposes the production-cell wall this spike's recovery
  estimate is calibrated against)
- LDG-2514 / Spike 10 (paired design; lot-state inline capture separates
  the lot-replay slice from the equity-recompute slice of reconstruction
  cost)

## Question

If we move per-pulse equity / cash / positions_value capture from a
post-fold reconstruction pass into the memory output handler (inline
during the fold), how much wall do we recover on the ephemeral path?

Decision rule from the spike spec: isolated wall recovery > 100s at 130k
events → proceed to v0.1.8.10 lead implementation. < 30s → park.

## Method

Mechanism isolation, not full ephemeral-pipeline reproduction. The fold
engine already computes equity per pulse at `R/fold-engine.R:189` as
`state$cash + positions_value`. So the savings are exactly:

    full reconstruction-pass cost
      MINUS the per-pulse vector-write overhead during the fold

Variant A: production baseline = full
  `ledgr_sweep_summary_from_ordered_events()` call.
Variant B: prototype = capture equity inline during fold (simulated by
  taking the equity tibble from Variant A and timing only the metrics +
  finalization step; the reconstruction pass is skipped).
Variant C: hybrid = inline equity + retained event log. Post-fold cost
  is identical to Variant B (event log is preserved but not replayed).
InlW: simulated per-pulse `equity_vec[i] <- ...` + 2 sibling vector
  writes (cash, positions_value), measured standalone with a 5-rep median.

Fixtures synthesize realistic FILL streams at LDG-2479 grid-cell scales:

| scale  | n_inst | n_pulses | n_fills | grid cell                          |
|:-------|-------:|---------:|--------:|:-----------------------------------|
| 13.5k  | 100    | 1260     | 13355   | `large_durable` (matches v0.1.8.9) |
| 30k    | 300    | 1260     | 30000   | mid-range                          |
| 68k    | 500    | 1260     | 68324   | `density_high` 500-inst            |
| 130k   | 1000   | 1260     | 130000  | `density_high_xlarge` 1000-inst    |

Each event has typed `cash_delta` / `position_delta` attached as attrs
(matches `ledgr_typed_event_metadata` output), so the reconstruction
takes the typed-meta fast path. Lot machinery runs per event (the
typed-meta path doesn't skip it; see `R/fold-reconstruction.R:468`).

Parity gate: an independently-derived inline equity curve (built from
the same primitives the fold engine would use inline:
`cumsum(cash_delta)` per pulse plus `colSums(positions_mat * close_mat)`)
must match Variant A's equity curve byte-for-byte at every scale.

## Results

```
scale    n_inst n_pulses  n_fills    VarA_s    VarB_s    InlW_s   recov_s  speedup
13.5k       100     1260    13355     1.190     0.000    0.0000     1.190    huge
30k         300     1260    30000     2.620     0.000    0.0000     2.620    huge
68k         500     1260    68324     7.000     0.000    0.0000     7.000    huge
130k       1000     1260   130000    14.000     0.000    0.0000    14.000    huge
```

VarA = `ledgr_sweep_summary_from_ordered_events()` median of 3 reps.
VarB = `ledgr_metrics_from_equity_fills()` only, median of 3 reps; below
proc.time() resolution (~10ms on Windows) at every scale.
InlW = simulated `equity_vec[i] <- v` x 3 cols x n_pulses; below
proc.time() resolution at all measured pulse counts (1260, 5000).

**Equity parity: PASS at all four scales.** An independently-computed
inline equity vector matches Variant A's reconstruction-derived equity
to within `all.equal()` tolerance 1e-9 at 13.5k, 30k, 68k, and 130k
fills.

### Per-fill cost in the reconstruction pass

| Scale | n_inst | n_fills | VarA_s | us/fill |
|------:|-------:|--------:|-------:|--------:|
| 13.5k |    100 |   13355 |   1.19 |    89.1 |
| 30k   |    300 |   30000 |   2.62 |    87.3 |
| 68k   |    500 |   68324 |   7.00 |   102.5 |
| 130k  |   1000 |  130000 |  14.00 |   107.7 |

Per-fill cost rises modestly from 89 us/fill to 108 us/fill as universe
size grows from 100 to 1000 instruments (n_pulses held at 1260). The
slope is the per-instrument `which(events$instrument_id == id)` loop at
`R/fold-reconstruction.R:514-526` paying O(n_inst x n_events)
character-equality comparisons; at 130k events x 1000 instruments
that's 130M comparisons. Spike 2 (LDG-2506) measures that bucket
operation standalone.

## Findings

**Mechanism confirmed.** Eliminating the reconstruction pass via inline
per-pulse equity / cash / positions_value capture recovers essentially
the entire `ledgr_sweep_summary_from_ordered_events()` wall on the
ephemeral path. Variant B's post-fold cost is below the timer
resolution at all measured scales; the per-pulse inline-write overhead
added during the fold (3 vector writes x n_pulses) is also below
timer resolution.

**Synthetic floor: 14s at 130k events.** This is well below the spike
spec's `150-200s expected recovery on density_high_xlarge_ephemeral`.
The gap is the fixture: synthetic FILLs alternate BUY/SELL on randomly-
selected instruments, so per-instrument lot state turns over fast and
doesn't accumulate the lot-list depth a real strategy produces.
`ledgr_lot_apply_event` is the per-event hot frame and its cost grows
with open-lot count per instrument; my fixture under-represents that.

Cross-evidence from LDG-2476 / 2026-05-31 closeout (horizon entry,
lines 192-200): the 68k-fill ephemeral row's reconstruction phase was
**40.9s** versus durable's pre-extracted state in production. That is
~6x my synthetic 68k cost (7.0s). Scaling LDG-2476's 40.9s @ 68k
linearly to 130k fills puts production recovery near **80s** at
`density_high_xlarge_ephemeral`, and the spike spec's 150-200s
estimate stays plausible if lot-depth scales with universe size as
well as fill count.

**Decision rule outcome.** The spike spec's "> 100s at 130k events =
proceed" rule cannot be settled from the synthetic fixture alone (14s
floor). LDG-2476 production evidence supports a recovery near or above
the threshold. Spike 11 (LDG-2515) ephemeral subphase telemetry is the
clean way to land a measured production-cell number; it's bundled with
this design in the spike DAG and is the prerequisite for cutting the
v0.1.8.10 implementation ticket.

**Variant disposition.**
- Variant B (pure inline) is the structural simplification. Replace
  `ledgr_sweep_summary_from_ordered_events()` with a memory output
  handler that captures equity / cash / positions_value per pulse plus
  per-fill rows. Fills tibble is emitted during the fold via
  `write_fill_events` already; only equity / running cost basis /
  realized PnL need new capture points.
- Variant C (hybrid) is the safer migration. Keep the event log
  preserved (downstream consumers may still query it); skip the
  reconstruction pass only when inline equity is captured. Lets
  sweep-mode candidates that don't enable inline capture stay on
  Variant A.

**Proceed to v0.1.8.10 lead implementation ticket**, contingent on
Spike 11 production-cell measurement confirming recovery > 100s at
`density_high_xlarge_ephemeral`. Bundle with Spike 10 (lot-state
inline capture) since both add inline state to the same memory
output handler and the design is one ticket.

## Implementation notes for the v0.1.8.10 ticket

1. Add `record_pulse_state(ts, cash, positions_value, equity,
   realized_pnl, cost_basis)` to `ledgr_memory_output_handler`.
2. Wire fold engine to call it once per pulse just after the equity
   computation at `R/fold-engine.R:189`.
3. Add `inline_equity_curve()` accessor on the handler returning the
   captured equity tibble in the same shape
   `ledgr_sweep_summary_from_ordered_events()` produces today.
4. In `ledgr_sweep_candidate_execute` (`R/sweep.R:919-934`): if the
   handler supports inline equity, skip the reconstruction call and
   build the summary directly from the captured tibble + fills tibble
   + metrics call.
5. Parity test: existing
   `ledgr_sweep_summary_from_ordered_events()` vs the inline path on
   every existing sweep fixture. The synthesis spike's parity gate
   becomes the regression test.
6. Variant C compatibility: keep the event log buffer populated by
   default; expose `use_inline_equity = TRUE` on the handler
   constructor. Sweep-summary fast-path checks the flag.

Source references for the ticket:

- `R/fold-reconstruction.R:376-572` (function being bypassed)
- `R/fold-engine.R:181-194` (equity computation site)
- `R/sweep.R:865, 919-934` (memory handler init + reconstruction call)
- `R/sweep.R:957-1190` (memory output handler constructor)
