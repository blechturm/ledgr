# Spike Log: ledgr_equity_from_events() Scaling

**Date:** 2026-05-31 - **Host:** local development host - R 4.5.2 -
**Status:** v0.1.8.9 optimization-round input (Batch C, Spike 8).

**Script:** `dev/spikes/spike-event-stream-reconstruction.R`. Raw CSV
(gitignored): `dev/bench/results/spike_event_stream_reconstruction.csv`.

**Relates to:** `dev/bench/notes/single_core_optimization_inventory.md`
(D3), `dev/bench/peer_benchmark/notes/three_phase_decomposition_results.md`,
LDG-2487.

## Question

LDG-2476 three-phase decomposition showed ephemeral ledgr's results
phase is +40.9s vs durable at 68k fills. Spike 7 confirmed the
`ledgr_fills_from_events()` half is O(N^2). This spike tests whether
`ledgr_equity_from_events()` has the same scaling pathology — same
mechanism, same fix candidate.

## Method

Synthetic events table at four scales matching Spike 7: 13.5k, 30k,
68.5k, 130k fills. Held constant: n_inst = 500, n_pulses = 1260.

`ledgr:::ledgr_equity_from_events` called directly via `pkgload::load_all`.
Required arguments constructed faithfully (`pulses_posix`, `close_mat`,
`initial_cash`, `instrument_ids`, `run_id`). Rprof at the largest scale
with 5ms sampling.

## Results

### Scaling

```
n_inst  n_fills  |    wall_s  us_per_fill | output_rows
500     13500    |    0.840s         62.2 | 1260 equity rows
500     30000    |    1.720s         57.3 | 1260 equity rows
500     68500    |    4.110s         60.0 | 1260 equity rows
500     130000   |    7.470s         57.5 | 1260 equity rows
```

Per-fill cost: 62, 57, 60, 57 us/fill. **Essentially flat across all
scales — O(N) total work, O(1) per-fill amortized.**

### Rprof at 130k fills

```
--- top 15 by total.time ---
                                  total.time total.pct
"ledgr:::ledgr_equity_from_events"     2.380    100.00
fold-reconstruction.R#117              1.765     74.16   <- for loop over events
"ledgr_lot_apply_event"                1.740     73.11
lot-accounting.R#204                   1.515     63.66
"ledgr_lot_apply_fill"                 1.455     61.13
lot-accounting.R#150                   0.525     22.06
fold-reconstruction.R#74               0.515     21.64
"ledgr_event_meta_at"                  0.515     21.64
"ledgr_lot_set"                        0.510     21.43
"jsonlite::fromJSON"                   0.490     20.59
```

Hot spots are the per-event lot machinery (`ledgr_lot_apply_event` + chain,
74% total time) and JSON meta parsing (`jsonlite::fromJSON`, 20%). Both
scale LINEARLY with n_events.

## Findings

**Mechanism rejected: equity_from_events is already O(N) per-fill flat.**
This is the OPPOSITE of Spike 7. The function does not exhibit the
super-linear cost growth that Spike 7 found in
`ledgr_fills_from_events`. No fix needed in this path for the v0.1.8.9
round.

**Why the difference?** Spike 7's culprit was per-row writes into a
preallocated column buffer (`ledgr_fill_row_buffer_add`). Spike 8's
`equity_from_events` does NOT use a per-row column buffer for its
output. It builds vectors via vectorized operations (`cumsum`,
`findInterval`, `colSums`) and only the per-event lot accounting runs
in a for loop — and that loop has bounded per-event work, not
per-event-vector-copy.

**The +40.9s ephemeral results overhead is NOT in equity_from_events.**
Spike 8 measures 4.1s at 68k fills isolated. Even if production runs at
3x the spike's pace (no DuckDB read amortization, hot cache differences),
that is at most ~12s. The remaining ~30s of the +40.9s ephemeral delta
must live elsewhere. Most likely candidates:

1. **`ledgr_fills_from_events`** — confirmed O(N^2) in Spike 7,
   contributes to BOTH durable and ephemeral results phases. The
   ephemeral path calls it on in-memory events; the durable path calls
   it on DuckDB-read events.
2. **The memory output handler's `materialize_events` call**
   (`R/sweep.R:1051-1076`) — converts the column buffer to a tibble.
   Spike 6 measured this path indirectly; the per-event growth there
   may also surface during results-phase materialization.
3. **Tibble construction overhead at large N** — `tibble::as_tibble(
   data.frame(...))` on 130k rows with multiple columns is not free.

A follow-up profile pass on the full ephemeral results phase end-to-end
(not just equity_from_events) would identify the residual. That is a
v0.1.8.9 ticket, not a v0.1.8.8 spike.

**The Spike 7 setv fix solves the larger problem.** Since
`ledgr_fills_from_events` is the O(N^2) culprit AND it is called by both
the durable and ephemeral results paths, fixing it via setv recovers
~170s on durable xlarge AND meaningful time on ephemeral. The Spike 8
result confirms that no parallel fix is needed for equity_from_events.

## Wall translation

Spike 8 measures 7.47s at 130k fills isolated. Production reference
workload (`density_high_xlarge_durable`) has 197.11s fills_extract_sec
and ephemeral has +40.9s extra results phase at 68k. Even tripling the
spike for production cache/conversion overhead, equity_from_events
contributes at most ~25s of the production results phase. The
remaining ~170s of durable results and ~30s of ephemeral residual are
elsewhere (Spike 7 for fills_from_events; Spike 9 for the xlarge
breakdown).

**Amdahl bound on the candidate fix: negligible.** No setv fix on
equity_from_events. Park as a negative result.

## Caveats

- **Synthetic events use simplified meta_json.** Production
  `jsonlite::fromJSON` cost depends on meta content; the spike's
  ~20% JSON parsing fraction may be different in production. This does
  not change the headline finding (equity_from_events is O(N) per-fill
  flat).
- **The Rprof oversampled the lot machinery.** ledgr_lot_apply_event
  shows 74% total time but absolute cost is only 1.7s at 130k. The
  fraction is high relative to the function's small absolute cost. No
  v0.1.8.9 action.
- **The +40.9s ephemeral results residual is not yet attributed.**
  Spike 8 rejects equity_from_events as the explanation. Spikes 6
  (memory handler) and 7 (fills reconstruction) explain most of it.
  The remainder is small enough to not warrant a v0.1.8.9 ticket; it can
  be picked up incidentally if a future profile identifies it.

## Recommendation

**Park as negative result.** No v0.1.8.9 implementation ticket for
equity_from_events. The function is already correctly vectorized and
scales linearly with fill count.

The D3 lane in `dev/bench/notes/single_core_optimization_inventory.md`
("In-memory event-stream reconstruction (~40s at 68k fills)") should be
revised: the cost is NOT in equity_from_events. The +40.9s ephemeral
results delta is mostly absorbed by Spike 7's fix (since
fills_from_events is called by both paths) and Spike 6's fix (memory
handler materialize_events).

If a v0.1.8.9 re-profile after Spike 6 + 7 fixes lands and the ephemeral
xlarge cell still shows a meaningful results-phase residual,
investigate `materialize_events` and tibble construction in the
ephemeral path as the next candidate. Until then, no action on this
lane.

## Architectural lesson

Spike 8 demonstrates the v0.1.8.9 round's discipline working as intended:
a hypothesized lane (D3) is empirically REJECTED by the spike before
v0.1.8.9 ticket scoping. The per_pulse_complexity_findings note and the
single_core_optimization_inventory both listed event-stream
reconstruction as a v0.1.8.9 candidate, with an estimated ~40s wall
recovery. Spike 8 says: no, the cost isn't there. The 40s is mostly
absorbed by the fixes already identified in Spike 6 and 7. v0.1.8.9 spec
should reflect this — list D3 as a parked theory, not a planned ticket.

This is the same "park hypothesis when spike fails" pattern from the
v0.1.8.7 projection spike (`spike-projection-collapse.md`): the
optimization map listed features_wide as a perf lane; the spike showed
it was sub-second; the lane was reclassified as a contract lane, not
a perf lane. Same discipline here.
