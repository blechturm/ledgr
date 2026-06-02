# Spike Log: Inline Lot-State In Memory Output Handler

**Date:** 2026-06-01 - **Host:** local development host (Windows, R 4.5.2,
collapse 2.1.7, yyjsonr 0.1.22) - **Status:** v0.1.8.10 spike-round
Batch A input (LDG-2514, Spike 10). Paired with LDG-2505 / Spike 1.

**Script:** `dev/spikes/spike-inline-lot-state.R`. Raw CSV:
`dev/bench/results/spike_inline_lot_state.csv`.

**Relates to:**
- `R/fold-reconstruction.R:454-504` (the per-event lot-replay loop this
  spike eliminates)
- `R/lot-accounting.R` (`ledgr_lot_apply_event` — the per-event hot
  function)
- `R/fold-engine.R:354-361` (where the fold engine already runs lot
  machinery during execution to emit fill events)
- LDG-2505 / Spike 1 (paired design: lot-state inline capture is the
  same architectural ticket as inline equity)
- LDG-2515 / Spike 11 (paired infrastructure: subphase telemetry is
  the prerequisite for measuring production lot-replay cost on the
  workload grid)

## Question

Does capturing lot state inline during fold execution (in the memory
output handler) eliminate the per-event lot-machinery replay in
`ledgr_sweep_summary_from_ordered_events` at
R/fold-reconstruction.R:454-504, and how much wall does that recover
standalone (separate from Spike 1's equity-recompute slice)?

## Method

Isolate the lot-replay slice of reconstruction cost. The reconstruction
loop calls `ledgr_lot_apply_event` per event to derive `event_realized`
and `event_cost_basis`. Spike 10 times that loop standalone, separate
from the cash-curve + bucket + fills-emission work in Spike 1.

Variant A: production lot-replay loop mirrored verbatim from
fold-reconstruction.R:453-504 with `typed_meta = NULL` so the path
includes JSON parsing per event (the realistic shape for events
written by the memory output handler before typed-meta optimization).
Variant B: pre-captured `event_realized` / `event_cost_basis` numeric
vectors (what the inline-capture handler would already have ready).
Inline-capture cost: simulated `realized_vec[i] <- ...` + sibling
`cost_basis_vec[i] <- ...` writes per fill, measured standalone.

Fixture: same shape as Spike 1's events fixture (uniform random FILLs
over n_inst x n_pulses) with real `meta_json` strings (not the typed-
meta fast path) so lot machinery exercises its full JSON parse +
lot-application code path.

## Results

```
scale  n_inst n_pulses  n_fills    VarA_s    VarB_s   InlCap_s   recov_s   us/event
13.5k     100     1260    13355     1.090    0.0000     0.0000     1.090      81.62
30k       300     1260    30000     2.690    0.0000     0.0000     2.690      89.67
68k       500     1260    68324     7.120    0.0000     0.0000     7.120     104.21
130k     1000     1260   130000    16.520    0.0000     0.0000    16.520     127.08
```

VarA = full per-event `ledgr_lot_apply_event` replay loop; this is
~93% of Spike 1's full reconstruction-pass cost (Spike 1 measured 14s
at xlarge; Spike 10 measures 16.5s standalone with a heavier JSON-parse
path).

VarB = pre-captured vector reads; below proc.time() resolution at
every scale because it's two numeric() allocations + index-by-name
read.

InlCap = simulated per-fill realized_pnl / cost_basis vector writes
inside the fold loop; below proc.time() resolution at every scale
(at 130k writes ~5 us per write x 130k ≈ 0.6ms; the simulated cost
is dominated by GC noise and rounds to zero).

### Per-event lot-replay cost

| Scale | n_fills | VarA_s | us/event |
|------:|--------:|-------:|---------:|
| 13.5k |   13355 |   1.09 |    81.6  |
| 30k   |   30000 |   2.69 |    89.7  |
| 68k   |   68324 |   7.12 |   104.2  |
| 130k  |  130000 |  16.52 |   127.1  |

Per-event cost grows from 82 to 127 us/event as universe size grows
10x. The growth is the per-instrument lot-list depth: in this fixture
BUY/SELL alternates randomly across instruments, so lot lists
accumulate before being torn down by closes. Production strategies
with longer holding periods would build deeper lots and run more
expensive lot machinery per event; production cost is bounded above
by these synthetic numbers, not below.

## Findings

**Lot-replay is the dominant cost in the reconstruction pass.** At
xlarge (1000 inst x 130k events) the lot-replay loop alone is 16.52s.
Spike 1 measured the full reconstruction pass at 14s on a similar
fixture (the typed-meta fast path saved ~2.5s by skipping JSON parse).
The bucket loop (Spike 2) is 0.36s. So:

- Lot replay:        ~13-16s  (~93% of reconstruction)
- Bucket loop:       ~0.36s   (~3%)
- Cash cumsum + fills tibble + metrics: ~0.5s  (~3%)

This confirms Spike 1's recovery story: the wall recovered by
eliminating the reconstruction pass is overwhelmingly the lot-replay
slice. The cost-basis and realized_pnl values the loop produces are
already computed by the fold engine during fill emission
(R/fold-engine.R:354-361 + R/lot-accounting.R) — they just aren't
emitted to the output handler today.

**Standalone recovery: 16.5s at xlarge ephemeral.** Per-event capture
overhead during fold is below timer resolution; net recovery equals
full VarA cost.

**Disposition: ship as part of the Spike 1 v0.1.8.10 ticket.** Both
spikes add inline state to the same memory output handler; the
design is one ticket. Splitting them would require two passes over
the handler interface and two parity-gate cycles.

### Variant disposition

- **Variant C (per-event capture in handler, no replay)**: this is the
  natural inline-capture shape — `handler$buffer_event()` already runs
  per fill (R/sweep.R:1157) and is the right place to capture
  `realized_pnl` + `cost_basis` directly from the lot result the fold
  engine produces at R/fold-engine.R:354-361. Reconstruction reads two
  numeric vectors of length `n_events` without replay.
- **Variant B (per-pulse capture)**: not separately measured. Sparser
  capture (n_pulses scalars vs n_events scalars), but requires
  reconstruction to project per-pulse state via findInterval, which is
  cheaper than per-event reads but loses the per-event realized PnL
  values that the public fills tibble surfaces. Per-event capture
  (Variant C) is the right default.

## Implementation notes for the v0.1.8.10 ticket (bundled with Spike 1)

1. Extend `ledgr_memory_output_handler`'s `buffer_event` (R/sweep.R:1157):
   accept and capture `realized_pnl` and `cost_basis_after` per fill.
   The fold engine already produces these in `lot_res$state` at
   R/fold-engine.R:354-361.

2. Extend the typed-events output to expose `event_realized` and
   `event_cost_basis` as columns or attributes.

3. In `ledgr_sweep_summary_from_ordered_events`, gate the lot-replay
   loop (lines 453-504) on whether the input events carry pre-captured
   realized/cost values. If so, read them; if not, fall back to replay
   (for backward compatibility with persisted DuckDB events).

4. Parity test: existing reconstruction-pass output vs inline-capture
   output on every existing sweep fixture; the `event_realized` and
   `event_cost_basis` numeric vectors must match byte-for-byte.

5. Cross-reference: the durable path's lot machinery already runs
   during fold execution and writes to `ledger_events.meta_json`.
   Spike 10's inline capture changes the ephemeral path; the durable
   path's persistent identity is unaffected.

## Source references

- `R/fold-reconstruction.R:454-504` (the loop being eliminated)
- `R/fold-engine.R:354-361` (where lot machinery already runs in
  production)
- `R/lot-accounting.R` (lot machinery itself)
- `R/sweep.R:1157-1168` (`buffer_event` — the capture hook for
  Variant C)
- LDG-2505 / Spike 1 (paired design: bundle into one v0.1.8.10
  ticket)
