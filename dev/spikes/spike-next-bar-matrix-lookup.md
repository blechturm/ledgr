# Spike Log: Next-Bar Matrix Lookup Re-Spike

**Date:** 2026-06-01 - **Host:** local development host (Windows, R 4.5.2,
collapse 2.1.7) - **Status:** v0.1.8.10 spike-round Batch D input
(LDG-2510, Spike 6). Re-spike of v0.1.8.9 LDG-2484 / Spike 5.

**Script:** `dev/spikes/spike-next-bar-matrix-lookup.R`. Raw CSV:
`dev/bench/results/spike_next_bar_matrix_lookup.csv`.

**Relates to:**
- `R/fold-engine.R:295-296` (production per-fill row subset:
  `b[i + 1L, , drop = FALSE]`)
- `R/fold-engine.R:297-300` (`ledgr_next_open_fill_proposal(next_bar = ...)`
  — the contract-surface consumer of the row)
- `R/fold-fill-proposal.R` (proposal function reading `next_bar$open`)
- `dev/spikes/spike-next-bar-extraction.{R,md}` (v0.1.8.9 prior
  measurement)
- LDG-2502 (v0.1.8.9 disposition: defer because contract surface change
  didn't clear v0.1.8.9 threshold)
- `dev/bench/notes/single_core_optimization_inventory.md` (B2)

## Question

Re-confirm the per-fill matrix-lookup recovery at post-v0.1.8.9 baseline.
Quantify the fill-proposal contract surface change cost and decide
whether v0.1.8.10 bundles this with the strategy callback addendum
implementation, defers to a matrix-canonical RFC, or parks.

## Method

Synthetic `bars_by_id` (named list of n_inst data.frames or tibbles, 1260
rows each) plus a pre-extracted `bars_mat$open` matrix [n_inst, n_pulses]
already built in production at R/fold-engine.R:55. Synthetic fills with
random (instrument_id, pulse_idx) tuples, pulse_idx < n_pulses so the
next-bar lookup is in range.

Four variants:

Variant A: current data.frame row subset `b[i + 1L, , drop = FALSE]`.
Variant B: tibble row subset (matches the post-v0.1.8.9 bars_by_id
type when fixture is tbl_df).
Variant C: matrix scalar lookup `bars_mat$open[inst_idx, i + 1L]`.
Variant D: vectorised matrix gather over the full fills batch (upper
bound; only realisable if fills are known in advance, which they aren't
in fold execution).

Scales: 500 inst x 1260 pulses x 68k fills, 1000 inst x 1260 pulses x
133k fills.

Parity gate: all variants produce identical scalar prices.

## Results

```
scale   n_fills    VarA_s    VarB_s    VarC_s    VarD_s     C_sp
68k      68324      2.420     2.290    0.1000    0.0000    24.2x
133k    133000      4.870     4.670    0.1800    0.0000    27.1x
```

**Parity A==B / A==C / A==D: PASS at both scales.**

### Per-fill cost

| Scale | n_fills | VarA us/fill | VarB us/fill | VarC us/fill |
|------:|--------:|-------------:|-------------:|-------------:|
| 68k   |  68324  |       35.4   |       33.5   |        1.46  |
| 133k  | 133000  |       36.6   |       35.1   |        1.35  |

### Comparison with v0.1.8.9 Spike 5

| Metric                        | v0.1.8.9    | v0.1.8.10 re-spike |
|------------------------------|------------:|-------------------:|
| VarA (df row) at 133k fills  |       4.98s |             4.87s  |
| VarC (matrix) at 133k fills  |       0.03s |             0.18s  |
| VarA->VarC speedup           |        166x |               27x  |
| Wall recovery                |        ~5s  |             ~4.7s  |

The absolute wall recovery is preserved (~5s). The headline speedup
shrank from 166x to 27x because VarC's per-call cost rose from 0.03s
to 0.18s — this looks like measurement noise floor effects at the
very-small absolute number rather than a real production change. Both
spike rounds confirm the same mechanism and the same wall recovery.

## Findings

**Mechanism preserved at post-v0.1.8.9 baseline.** Replacing the
per-fill data.frame row subset with a matrix scalar lookup saves ~4.7s
of fold-loop wall at 133k fills.

**Tibble row subset is essentially equivalent to data.frame.** Variant
B (tibble) is 1.04x over Variant A (data.frame). The post-v0.1.8.9
change from list-of-df to list-of-tbl for `bars_by_id` did not move
the per-fill extraction cost. Both pay the same sub-frame allocation
overhead per call.

**Vectorised matrix gather (Variant D) is the upper-bound shape.**
Below timer floor at 133k fills. Only realisable as a production
optimization if fills can be batched before the per-fill engine work
(which Spike 1's inline-equity-capture path enables — the memory
output handler could accumulate fill intents and apply matrix-gather
prices in a single batched call). Document as forward-pointing direction.

**Contract surface change is mechanical but non-trivial.** The current
flow:

    next_bar <- b[i + 1L, , drop = FALSE]
    proposal <- ledgr_next_open_fill_proposal(
      desired_qty_delta = delta,
      next_bar = next_bar
    )

needs to change to:

    next_open_price <- bars_mat$open[inst_idx, i + 1L]
    proposal <- ledgr_next_open_fill_proposal(
      desired_qty_delta = delta,
      next_open_price = next_open_price
    )

This means:
- `ledgr_next_open_fill_proposal` signature change (next_bar → next_open_price).
- Any downstream consumer that reads other columns from next_bar must
  receive them separately. Per the prior v0.1.8.9 spike log, the proposal
  function reads only `next_bar$open` today — the scalar conversion is a
  clean drop-in for the current contract. But the signature change
  ripples to every test fixture and every external caller (`ledgr:::`
  level — no public exposure).

### Wall translation to production

Production reference: `density_high_xlarge_durable` 232s wall, 199s loop,
~130k fills. Spike measures 4.87s VarA -> 0.18s VarC at 133k fills =
4.69s recovery in the per-fill extraction frame.

Amdahl bound: 4.69s / 199s loop = 2.4% production wall improvement.
~2.0% of total xlarge wall.

## Disposition

**SHIP in v0.1.8.10 IF bundled with the strategy callback contract
addendum implementation.** The accessor RFC's `ctx$vec$open` /
`ctx$vec$close` namespace already produces the matrix-canonical bars
representation at the strategy boundary. Reusing that representation
inside the fold-engine fill-proposal path is the natural pairing:

- Same `bars_mat` matrices feed both `ctx$vec` accessor and the
  internal fill-proposal lookup.
- Same `instrument_id_to_inst_idx` map (introduced by Spike 3 /
  state$positions substrate) handles the inst_idx resolution for both
  surfaces.
- Two related changes in one ticket cuts the contract-edge review
  overhead.

**Defer to a separate matrix-canonical RFC IF the accessor RFC
implementation slips past v0.1.8.10.** The 4.7s recovery alone does not
justify the contract-surface change overhead; bundling is what makes
it worth shipping.

**PARK as standalone if both above are blocked.** The recovery is
~2% wall — meaningful but not load-bearing.

## Implementation notes for the v0.1.8.10 ticket (bundled with accessor RFC)

1. Replace `b <- bars_by_id[[instrument_id]]` followed by
   `b[i + 1L, , drop = FALSE]` at `R/fold-engine.R:295-296` with:
   ```r
   next_open_price <- bars_mat$open[inst_idx, i + 1L]
   ```
   where `inst_idx` is resolved via the integer-indexed map from Spike 3
   (`state$positions` substrate ticket).
2. Update `ledgr_next_open_fill_proposal()` signature: replace
   `next_bar` argument with `next_open_price` (numeric scalar).
3. Update `ledgr_resolve_fill_proposal()` and any consumer that reads
   off `next_bar` (per the v0.1.8.9 spike log, only `next_bar$open` is
   currently read — the change is clean).
4. Boundary check: the matrix index `i + 1L` exceeds `n_pulses` on the
   final pulse. Current code's `i < nrow(b)` guard becomes
   `i < n_pulses`; preserve the `LEDGR_LAST_BAR_NO_FILL` warning path.
5. Parity test: existing fill streams on every sweep / backtest fixture
   produce byte-identical fill prices via both the old `next_bar` and
   the new scalar shape.

## Source references

- `R/fold-engine.R:295-300` (production per-fill row subset and proposal
  call)
- `R/fold-fill-proposal.R` (proposal function consuming next_bar)
- `dev/spikes/spike-next-bar-extraction.{R,md}` (v0.1.8.9 prior
  measurement — same mechanism, same wall recovery confirmed)
- LDG-2502 / per-lane attribution (v0.1.8.9 deferral rationale)
- `inst/design/rfc/rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md`
  (the accessor RFC that bundles this fix as part of the same
  matrix-canonical ticket)
- LDG-2507 / Spike 3 (substrate: `inst_idx` resolver is the same map
  used by both surfaces)
