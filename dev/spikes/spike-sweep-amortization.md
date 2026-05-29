# Spike Log: Sweep Amortization (ledgr_sweep vs naive)

**Date:** 2026-05-29 · **Host:** Intel Core i9-12900K, Windows 11 · R 4.5.2,
collapse 2.1.7, TTR · **Status:** v0.1.8.7 RFC **open input** (the "kick
Backtrader on sweeps" bet). **No crossover claim is bound either way.**

**Scripts:** `dev/bench/peer_sweep_three_way.R` (the curve),
`dev/bench/peer_sweep_verify.R` (the mechanism check). CSV (gitignored):
`dev/bench/results/peer_sweep_three_way_ledgr.csv`.

**Relates to:** `inst/design/rfc/rfc_optimization_round_v0_1_8_7_seed_v2.md`
(Open inputs), `inst/design/spikes/ledgr_optimization_round_spike/architecture_synthesis.md` (L7).

## Question

`ledgr_sweep` computes the feature union once and shares it across N candidates
(`R/sweep.R:115-126`), but re-runs the per-candidate fold (`:662`). The bet: does
that amortization let a multi-candidate sweep pull ahead of peers re-paying per
candidate? Uses TTR's **C** SMA (matching `bench_make_sma_features`) so the
feature-precompute cost is realistic — the built-in `ledgr_ind_sma` rolling mean
would inflate the amortizable precompute and rig the result.

## Results

**Curve** (`peer_sweep_three_way.R`, 30 inst × 504 days, strategy-param sweep =
vary `qty`, fixed features):

```
[sma, 2 features]    N=1 5.84s | N=5 3.67/cand | N=25 3.57/cand | N=50 3.66/cand   amortization ~1.2x
[heavy, 40 features] N=1 12.54s| N=5 11.62/cand| N=25 11.63/cand| N=50 11.87/cand  amortization ~1.0x
```

Per-candidate cost is **flat** and **scales with feature width** (≈3.6s/cand for 2
features, ≈11.9s/cand for 40).

**Mechanism check** (`peer_sweep_verify.R`, 40-feature heavy, N=10):

```
(1) ledgr_sweep internal          : 124.81s  (12.48s/cand)
(2) ledgr_sweep + precomputed      : 123.91s  (12.39s/cand)  [+ 9.92s precompute step]
(3) N x ledgr_run (true naive)     : 147.33s  (14.73s/cand)
=> internal amortization (3)/(1) = 1.18x ; explicit (3)/(2incl-pre) = 1.10x
```

## Findings

1. **Amortization is real but modest: ~1.18×.** The internal union-precompute is
   shared and saves ~2.25s of the ~14.7s naive per-candidate cost. The mechanism
   works; the magnitude is small.
2. **The per-candidate fold dominates (~12.5s/cand), not the precompute.** So
   amortization *cannot* be large here — it discounts only the (shared) precompute
   slice. Confirms the seed framing: `ledgr_sweep` amortizes feature
   precompute/projection, **not** the per-candidate fold.
3. **Explicit `ledgr_precompute_features()` adds no benefit over the internal
   path** (123.9s vs 124.8s); its separate 9.92s precompute step makes the total
   *worse*. The internal union-sharing already happens within a single sweep —
   passing `precomputed_features` only helps when sharing *across* sweep calls.
4. **Per-candidate cost scales with feature width**, because the per-pulse fold
   work (incl. building the full-width `features_wide` per pulse) is re-paid every
   candidate and is *not* amortized. Wide feature maps are expensive per-candidate.
5. **Bet implication:** a ~1.18× amortization discount is far below the ~2.7×
   single-run gap to Backtrader, so a crossover looks **unlikely on these
   workloads**. On the measured evidence the "kick Backtrader on sweeps" bet is
   **not won.** The lever is the per-candidate fold itself — which loops straight
   back to the single-core hot-path lanes (esp. Lane R / per-pulse representation).

## Caveats

- Two workloads only (cheap 2-feature SMA; 40-feature SMA "heavy"). A workload
  with genuinely *expensive* per-candidate feature precompute (not 40 cheap C
  SMAs) would shift more cost into the amortizable slice and could raise the
  ratio — untested. The SMA family does not get there.
- ledgr-internal only (sweep vs naive). The peer `optstrategy`/`apply.paramset`
  arms were not run: since ledgr loses the single run *and* amortizes only ~1.18×,
  the peer comparison would not change the conclusion on these workloads.
- Strategy-param sweep (vary `qty`, identical features) is the *most* favorable
  case for amortization (features fully shared); it still only reached ~1.18×.

## Implication for the RFC

Keep the sweep as **open input, no crossover claim** (the v2 seed does). The
honest read: amortization exists but is modest because the per-candidate fold
dominates — so the single-core fold optimization (Lanes B/R) is what would make
sweeps competitive, not a sweep-specific mechanism. A sweep-specific RFC is a
future obligation, gated on heavier-precompute evidence if pursued.
