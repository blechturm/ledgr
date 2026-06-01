# Spike Log: Per-Fill Next-Bar Extraction

**Date:** 2026-05-31 - **Host:** local development host - R 4.5.2 -
**Status:** v0.1.8.9 optimization-round input (Batch D, Spike 5).

**Script:** `dev/spikes/spike-next-bar-extraction.R`. Raw CSV (gitignored):
`dev/bench/results/spike_next_bar_extraction.csv`.

**Relates to:** `dev/bench/notes/single_core_optimization_inventory.md`
(B2), LDG-2484.

## Question

`R/fold-engine.R:290` does `b[i + 1L, , drop = FALSE]` per fill where `b`
is a data.frame fetched from `bars_by_id[[instrument_id]]`. The row
subset allocates a new sub-frame per fill with class-dispatch overhead.
How much does replacing with a matrix scalar lookup
(`bars_mat$open[inst_idx, i + 1L]`) save at production fill scale?

## Method

Synthetic `bars_by_id` as a named list of 1000 data.frames (1260 rows
each), plus the tibble equivalent. A pre-extracted `bars_mat$open` matrix
of shape [1000, 1260] for the matrix lookup variant. 133,000 synthetic
fills with random (instrument, pulse) tuples matching production xlarge.

Three variants:

- `df_row_subset`: current pattern `b[i + 1L, , drop = FALSE]` on a
  data.frame.
- `tibble_subset`: same on a tibble (`tbl_df` dispatch).
- `matrix_scalar`: `bars_mat$open[inst_idx, i + 1L]` — O(1) scalar lookup.

## Results

```
=== parity check ===
df=13299434.829554  tibble=13299434.829554  matrix=13299434.829554  [OK]

=== timing (133k fills) ===
variant             wall_s  us_per_fill
df_row_subset       4.980s        37.44
tibble_subset       4.730s        35.56
matrix_scalar       0.030s         0.23

Speedup df_row_subset -> matrix_scalar: 166.0x
Speedup tibble_subset -> matrix_scalar: 157.7x
```

## Findings

**Mechanism confirmed, but the absolute saving is small.** Matrix scalar
lookup is 166x faster per call than the data.frame row subset. At 133k
fills the wall saving is ~5 seconds.

**Tibble is marginally faster than data.frame here.** Surprising — usually
`[.tbl_df` is slower than `[.data.frame` due to tibble's stricter checks.
At this access pattern (single row, all columns, drop=FALSE), they are
indistinguishable. Both are dominated by the per-call sub-frame
allocation cost.

**The fix requires upstream restructuring.** Production currently passes
`b` as the per-instrument data.frame from `bars_by_id[[instrument_id]]`.
Switching to matrix lookup requires:

1. Pre-extracting `bars_mat$open` (already exists per
   `R/fold-engine.R:55`).
2. Maintaining an `instrument_id -> inst_idx` map (already implicit via
   `seq_along(instrument_ids)`).
3. Replacing the `next_bar` usage downstream
   (`ledgr_next_open_fill_proposal` and `ledgr_resolve_fill_proposal`)
   to accept a scalar `next_open_price` instead of a full row.

The downstream changes touch the fill-proposal contract surface — small
but non-trivial. The fix is mechanical but requires careful
contract-edge review.

## Wall translation

Reference workload: `density_high_xlarge_durable` runs in 445.02s wall.
The spike measures ~5s recovery at 133k fills. Production fold-engine
overhead beyond just this extraction includes the surrounding proposal
and resolve calls, which may add small additional cost.

Amdahl bound: p = 0.011, max wall speedup = 1.011x (~5s of 445s wall).

**Small lane.** Compared to Spike 4 (~75s), Spike 7 (~170s), Spike 6
(~75s), this is an order of magnitude smaller. Not a headline lane.

## Caveats

- **The downstream fill-proposal contract surface needs review** before
  switching to scalar prices. The current `next_bar` is a data.frame row
  consumed by `ledgr_next_open_fill_proposal(next_bar = next_bar)`. The
  proposal function reads `next_bar$open` to get the price. Replacing
  next_bar with just `next_open_price` requires changing that signature
  too. Not a clean drop-in fix.
- **The synthetic bars use uniform-random prices.** Production bars
  have ordering and price patterns that may slightly affect cache
  behavior. The relative speedup should hold.
- **Real-run re-profile is the verdict.** Apply the fix, re-run xlarge
  and large cells, confirm `t_loop_sec` drops by ~5s and proposal
  resolution behavior is unchanged.

## Recommendation

**Proceed but de-prioritize.** This is a small lane (~5s wall) but with
moderate blast radius (touches the fill-proposal contract surface).
Recommend landing AFTER the headline lanes (Spikes 4, 6, 7) when the
v0.1.8.9 work is in a polish phase.

Alternative framing: this is a v0.1.8.10 cleanup lane, not a v0.1.8.9
release-gating lane. The mechanism is confirmed, the fix is mechanical,
but the wall payoff is small and the contract change is non-trivial.

Expected real-run signature: `t_loop_sec` on xlarge drops by ~5s.
`mus_per_fill_engine` drops by ~5 us. No structural metric change.

## Architectural note

The matrix-canonical surface is also one of the recurring v0.1.8.7
optimization-round themes (see
`inst/design/spikes/ledgr_optimization_round_spike/spike-projection-collapse.md`).
The same architectural principle applies here: data.frame row access in
hot loops is a smell; pre-extract to typed matrices where possible. The
v0.1.8.9 round can fold this into the broader matrix-canonical surface
discussion if/when that becomes a v0.2.x contract RFC.
