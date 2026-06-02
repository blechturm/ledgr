# ledgr v0.1.8.10 Optimization-Round Spike

**Status:** Pre-RFC investigation. Results feed the v0.1.8.10 single-core
optimization round (the closing round of the v0.1.8.x single-core arc).
Not a v0.1.8.9 deliverable.
**Scope:** Decompose ledgr's remaining post-v0.1.8.9 optimization
candidates and measure each in isolation. The headline target is the
ephemeral xlarge cell (still ~60% slower than durable at the stress
shape) plus R-side substrate work that pays off as both direct
optimization and shared substrate for any future compiled core.
**Non-scope:** ledgr implementation work, fold-core refactor, the v0.1.8.10
spec packet itself, peer benchmark expansion (NautilusTrader, vectorbt,
Ziplime adapters), parallelism rewrites, K1 / `ledgrcore` compiled core
spike (moved to a dedicated `ledgrcore-spike` repo and timed after
v0.1.8.10 substrate landing — see the horizon's 2026-06-01 K1 entry
update), feature work (target risk, walk-forward, OMS, cost models).

Each spike is a short, self-contained, *runnable* investigation. The
runnable scripts and raw logs live in `dev/spikes/`. CSV artifacts under
`dev/bench/results/` are gitignored scratch. This directory holds the
design-level writeup: the per-spike logs are linked below, and the
cross-cutting conclusions will be synthesized in `architecture_synthesis.md`
once the spikes complete.

Host for all spikes: same local development host running R 4.5.2 at
`C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe`.

## Why this round exists

The v0.1.8.9 round delivered the headline structural wins (40% wall
reduction on xlarge durable, 47.9% on xlarge ephemeral) by removing the
O(N^2) per-row column-buffer write anti-pattern and vectorizing the
per-pulse loops. The v0.1.8.9 measurement closeout
(`inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md`)
identified the remaining work as four residuals plus one open
architectural question:

1. **Ephemeral path still pays a reconstruction-pass cost** at high fill
   counts. xlarge ephemeral runs 372.55s vs xlarge durable 232.03s
   (+60%). The mechanism — `ledgr_sweep_summary_from_ordered_events`
   re-deriving equity, positions matrix, and lot state from the event log
   — has an O(n_inst x n_events) per-instrument `which()` loop at
   `R/fold-reconstruction.R:514-526` and a per-event lot machinery replay
   at lines 454-504. Inline equity accumulation in the memory output
   handler eliminates both.
2. **R-side substrate** — typed primitive `state$positions`, reusable
   pulse-context env, integer-indexed strategy callback accessors —
   delivers bounded R-side recovery now and substrates any future K1
   build by removing R-side ctx construction overhead at the
   compiled-to-R boundary. The horizon entries at
   `inst/design/horizon.md` (2026-06-01 substrate framing and K1 spike
   gate) capture the framing.
3. **yyjsonr read-path regression** — LDG-2501 closed canonical write
   path at 5.61x speedup but production reads regressed by 2.3x. Possible
   recoveries include different yyjsonr option combinations, direct calls
   bypassing the helper indirection, or a thin jsonlite read-fallback.
4. **Per-pulse / per-fill micro-lanes deferred from v0.1.8.9** — Spike 5
   (next-bar matrix lookup) and inventory items A4 (pulse_seed mixer),
   A5/A6 (ctx reuse), A7 (alias map normalization). Individually small
   but may clear thresholds when bundled.
5. **Open architectural question: does a compiled fold core actually
   help post-substrate?** The horizon's 2026-06-01 K1 entry update set
   the build-authorization gate on a measurement spike running both
   C++ via cpp11 and Rust via extendr against post-substrate R, not
   against current production R. **The K1 spike is out of v0.1.8.10
   scope** — it moved to a dedicated `ledgrcore-spike` repo and is
   timed after v0.1.8.10 ships, so the comparison runs against
   post-v0.1.8.10 production R (the strongest possible fair baseline)
   rather than an emulation. This keeps the v0.1.8.10 round focused
   on R-side substrate + ephemeral redesign at R-spike cadence, and
   keeps the ledgr repo's build system clean of Rust / C++ toolchain
   requirements. See the horizon's 2026-06-01 K1 entry update for the
   repo-split decision.

The full inventory lives at
`dev/bench/notes/single_core_optimization_inventory.md` and now records
which candidates were taken in v0.1.8.9, which were deferred to v0.1.8.10+,
and which were parked as negative results.

This spike round mirrors the v0.1.8.9 round
(`inst/design/spikes/ledgr_v0_1_8_9_optimization_round_spike/`) and the
v0.1.8.7 cycle before it
(`inst/design/spikes/ledgr_optimization_round_spike/`): each suspected
mechanism gets an isolated reproducer that either confirms or rejects the
hypothesis, then the production re-profile is the wall-time verdict. The
discipline is captured in
`inst/design/maintainer_review/v0_1_8_7_optimization_round.qmd`.

## Spikes

Reference workload for the production re-profile gate is
`density_high_xlarge_ephemeral` from the LDG-2479 grid (1000 inst x 1260
pulses, SMA 5/10 crossover, ephemeral sweep candidate) for the ephemeral
lanes, and `density_high_xlarge_durable` for the substrate and per-pulse
lanes. Post-v0.1.8.9 baseline numbers (from the LDG-2503 closeout):

| Cell | Wall s | Loop s | Fills extract s | Engine us/fill |
| --- | ---: | ---: | ---: | ---: |
| `density_high_xlarge_durable` | 232.03 | 199.06 | 23.36 | 1494.95 |
| `density_high_xlarge_ephemeral` | 372.55 | NA | NA | NA |
| `density_high_large_durable` | 85.12 | 68.88 | 10.18 | 1011.48 |
| `density_high_large_ephemeral` | 101.58 | NA | NA | NA |

The ephemeral cells lack subphase telemetry because the workload-grid
harness does not expose loop_sec/results_sec for sweep rows. Spike 11
addresses that gap; without it, the ephemeral spikes (1, 2, 10) can only
attribute against total wall, not against the specific reconstruction
phase the fix targets.

Eleven spikes organized into four batches plus a measurement-infrastructure
prerequisite.

### Batch A: Ephemeral redesign (the headline lane)

| # | Spike | Runnable + log | Mechanism hypothesis | Headline |
|---|---|---|---|---|
| 1 | Inline equity accumulation in memory output handler | `dev/spikes/spike-inline-equity-accumulation.{R,md}` | `ledgr_sweep_summary_from_ordered_events` at `R/fold-reconstruction.R:376-572` runs a second pass over events to rebuild equity curve, positions matrix, and lot state — work the fold engine already did during execution. A memory output handler that accumulates equity per pulse inline (cash + sum(positions * close)) and captures fills directly to a tibble during fold execution eliminates the reconstruction pass entirely. Expected wall recovery on xlarge ephemeral: 150-200s. | TBD |
| 2 | `collapse::gsplit()` / `split()` over per-instrument `which()` in reconstruction | `dev/spikes/spike-reconstruction-split-bucket.{R,md}` | The per-instrument loop at `R/fold-reconstruction.R:514-526` runs `which(events$instrument_id == id)` for each instrument, an O(n_inst x n_events) scan. At xlarge (1000 inst x 133k events) that is 133M character-equality comparisons just to bucket events by instrument. A single bucket-by-instrument operation reduces this to one O(n_events) pass. Base R `split(seq_along(events$instrument_id), events$instrument_id)` is the obvious replacement; **prior collapse work in v0.1.8.7 showed `collapse::gsplit()` is materially faster than base R `split()` at production scale**, so the spike measures both. Subsumed if Spike 1 lands; worth measuring as a fallback if Spike 1 doesn't pan out, and worth confirming that the v0.1.8.7 collapse-vs-split finding still holds at the v0.1.8.10 reconstruction shape. | TBD |
| 10 | Inline lot-state capture in memory output handler | `dev/spikes/spike-inline-lot-state.{R,md}` | The reconstruction pass at `R/fold-reconstruction.R:454-504` replays lot machinery per event to derive `event_realized` and `event_cost_basis`. The fold engine already runs lot machinery during execution to emit fill events. Capturing per-pulse lot state in the memory output handler removes the replay entirely. Bundled with Spike 1 in the design but measured separately to attribute the lot-replay vs equity-recompute portions of the reconstruction cost. | TBD |
| 11 | Ephemeral sweep subphase telemetry exposure | `dev/spikes/spike-ephemeral-subphase-telemetry.{R,md}` | The workload-grid harness does not currently expose loop_sec, results_sec, or fills_extract_sec for sweep rows because the sweep flow doesn't capture them. Adding subphase telemetry to the memory output handler and sweep summary flow lets the harness report ephemeral subphases the same way durable rows do. This is infrastructure, not optimization, but it is a prerequisite for attributing Spike 1's win cleanly. Ship alongside Spike 1 implementation. | TBD |

### Batch B: Substrate / data structures

| # | Spike | Runnable + log | Mechanism hypothesis | Headline |
|---|---|---|---|---|
| 3 | `state$positions` primitive representation re-spike | `dev/spikes/spike-state-positions-primitive.{R,md}` | The v0.1.8.9 Spike 3 measured 1.9x for `intvec_id_map` and 1.9x for `collapse::setv` at 1000-element scale, both small. Re-spike at production xlarge shape (1000 inst x 1260 pulses x 133k fills) with full attention: replace named-vector `state$positions` with integer-indexed numeric + one-time `id_to_idx` map. Measure read side (used in Batches 4/5 vectorize), write side (per-fill `state$positions[[inst]] <- value` at R/fold-engine.R:360, the residual after Batches 4/5), and the substrate effect on a hypothetical compiled-core boundary cost. | TBD |
| 4 | Reusable pulse-context env across pulses | `dev/spikes/spike-pulse-context-env-reuse.{R,md}` | The pulse context constructor at `R/fold-engine.R:180-194` allocates a fresh list with 12+ slots per pulse. At 1260 pulses on xlarge that's 1260 list allocations plus per-slot binding work. A reusable env mutated slot-by-slot per pulse removes the allocation cost while preserving the strategy-observable shape (`ctx$cash`, `ctx$positions`, `ctx$bars`, etc.). Variants: current fresh-list; reusable-env with same slot names; reusable-env with class attribute restored per pulse. Per-pulse allocation reduction is the primary metric; secondary effect is the GC pressure reduction at long pulse counts. | TBD |
| 5 | Integer-indexed strategy callback accessors | `dev/spikes/spike-integer-indexed-accessors.{R,md}` | Strategies currently access bars and positions through data.frame and named-vector indexing patterns (`ctx$bars$close[ctx$bars$instrument_id == "AAA"]`). Adding integer-indexed accessors as a first-class API alongside the named patterns (`ctx$close[idx]`, `ctx$positions[idx]`) lets high-throughput strategies opt in to faster patterns. Spike measures per-pulse callback cost across patterns: current named-list access, integer-indexed atomic-vector access through a reusable env, integer-indexed env-slot access through `[[<-` and `setv` variants. This is partially a contract change so the spike is also a feasibility check for the strategy callback addendum RFC. | TBD |

### Batch C: Per-pulse / per-fill micro lanes

| # | Spike | Runnable + log | Mechanism hypothesis | Headline |
|---|---|---|---|---|
| 6 | Next-bar matrix lookup re-spike | `dev/spikes/spike-next-bar-matrix-lookup.{R,md}` | The v0.1.8.9 Spike 5 confirmed `b[i+1L, , drop=FALSE]` at `R/fold-engine.R:295` is 166x slower than `bars_mat$open[inst_idx, i+1L]` in isolation; deferred from LDG-2502 because the recovery (~5s) didn't clear the v0.1.8.9 threshold and the fix changes the fill-proposal contract from row-shaped `next_bar` to scalar `next_open_price`. Re-spike post-v0.1.8.9 to confirm the wall recovery and quantify the contract surface change. Bundles naturally with the strategy callback addendum (Spike 5) if both land in v0.1.8.10. | TBD |
| 8 | Cheap deterministic pulse_seed mixer | `dev/spikes/spike-pulse-seed-mixer.{R,md}` | `ledgr_derive_pulse_seed` at `R/rng.R:33-57` computes SHA-256 of canonical_json output per pulse to derive a deterministic pulse seed. Inventory item A4 estimates ~0.25s at 1260 pulses but never spiked. A cheap deterministic mixer (xoshiro128 seeded from `(execution_seed, pulse_idx)`, or splitmix64) should be 10x-100x faster while preserving deterministic replay. Decision rule: if total isolated cost < 1s at 1260 pulses, park as not v0.1.8.10 scope; if > 1s, ticket. | TBD |
| 9 | `active_alias_map` one-time normalization | `dev/spikes/spike-alias-map-normalize.{R,md}` | Inventory item A7: the active alias map is currently normalized inside the per-pulse loop at `R/fold-engine.R:61, 204-218`. Lifting normalization outside the loop should save per-pulse cost. Profile-needed first to confirm visible cost; if invisible, this is sub-second and parks. Decision rule: if isolated cost < 0.5s at 1260 pulses x 100-alias map, park; if > 0.5s, ticket. | TBD |

### Batch D: Read-path / dependency

| # | Spike | Runnable + log | Mechanism hypothesis | Headline |
|---|---|---|---|---|
| 7 | yyjsonr read-path recovery investigation | `dev/spikes/spike-yyjsonr-read-recovery.{R,md}` | LDG-2501 measured yyjsonr reads 2.3x slower than jsonlite on production metadata shapes (helper benchmark: 0.53s jsonlite vs 1.21s yyjsonr at 50k payloads). Multiple recovery candidates: (a) try `length1_array_asis = FALSE` for nested reads if downstream doesn't need AsIs preservation; (b) call `yyjsonr::read_json_str` directly without the `ledgr_json_read_nested` helper indirection; (c) try binary-mode read API if available; (d) thin jsonlite read-fallback while keeping yyjsonr for canonical writes. Spike measures each variant against the 50k-payload reference. Decision rule: any variant achieving 1.5x recovery over current helper proceeds to v0.1.8.10 ticket; otherwise the read-path stays as documented LDG-2501 trade-off. | TBD |

## Cross-cutting themes anticipated

Pending spike results. Three themes the v0.1.8.10 spike round expects to
clarify:

- **Ephemeral can become the fast path.** Spikes 1, 2, 10 together should
  invert the durable/ephemeral wall ordering at the xlarge stress shape.
  Today ephemeral is +60% slower; post-v0.1.8.10 the expected ordering is
  ephemeral slightly faster than durable on all measured shapes, matching
  the original ephemeral design intent before the reconstruction pass
  ate the savings.
- **Substrate work is no-regret per the horizon framing.** Spikes 3, 4, 5
  measure both immediate R-side wins and the R-to-compiled boundary cost
  any future K1 spike will inherit. The horizon's 2026-06-01 K1 spike
  entry explicitly gates compiled-core authorization on post-substrate
  measurement, so this batch's results inform both v0.1.8.10 substrate
  tickets and the eventual K1 spike scoping.
- **Micro-lanes either clear thresholds bundled or park cleanly.** Spikes
  6, 8, 9 each carry decision rules. If all three clear, bundle into one
  v0.1.8.10 batch. If only one clears, ticket it alone. If none clear,
  park them in the inventory with explicit "below v0.1.8.10 threshold"
  notes so they aren't re-spiked next cycle.

The round's architecture synthesis (written after all spikes complete)
elaborates these themes with full evidence references.

## Spikes that are deferred (conditional or not now)

These items from the optimization inventory are not in this round because
they need profile evidence first, are conditional on specific strategy
features, or are architectural decisions not amenable to isolated
simulation.

- A8 (telemetry zero-init skip): sub-second per the inventory; park unless
  a profile pass surfaces it.
- B3, B4, B6, B7 (per-fill function-call dispatch, lot-map update, event_seq
  bookkeeping): profile-needed; spike only if Rprof on the post-v0.1.8.9
  xlarge cell surfaces them.
- E1 inventory item (snapshot creation cost): profile-needed; spike on
  demand if snapshot creation becomes a research-loop bottleneck.
- F1, F2 (series_fn dual-API, feature cache): parked until a non-vectorized
  custom-R indicator workload exposes them.
- G1-G4 (strategy callback path overhead): same — Rprof first, spike if
  any appear top-10 on a post-v0.1.8.10 workload.
- H1 (state_update canonical_json cost): partial win taken by LDG-2501's
  yyjsonr migration; remaining surface is conditional on `state_update`
  strategies.
- Peer benchmark expansion (NautilusTrader, vectorbt, Ziplime, LEAN when
  CLI configures): not optimization; separate measurement track.
- **K1 measurement spike (compiled fold core in C++ via cpp11 + Rust via
  extendr):** moved to a dedicated `ledgrcore-spike` repo per the
  2026-06-01 horizon update. Out of v0.1.8.10 scope. Timed to run after
  v0.1.8.10 ships so the comparison runs against post-v0.1.8.10
  production R rather than a substrate-emulated baseline. Keeps the
  ledgr repo's build system clean of Rust / C++ toolchain requirements
  and lets K1 mature at its own multi-week cadence without blocking the
  v0.1.8.10 R-spike rhythm. The horizon's K1 entry remains the
  authoritative spec for what the spike must measure; results flow back
  to a future ledgr horizon update with the build/don't-build verdict.
- Full `ledgrcore` package build (production-grade C++ or Rust
  implementation of the full fold engine, output handler integration,
  byte-identity parity gate with R reference): conditional on the
  separate-repo K1 spike triggering "build authorized" per the horizon's
  decision rule.

## Method

Lifted from the v0.1.8.7 and v0.1.8.9 cycles. Three load-bearing
principles plus one v0.1.8.9-cycle-validated addition.

### 1. Spike to confirm mechanism, real-run to confirm magnitude

For every candidate in this round:

1. **Isolated simulation** (this spike): a small R script that reproduces
   the suspected mechanism in isolation. Output is per-call cost and a
   scaling signature.
2. **Mechanism confirmation**: the spike either confirms or rejects the
   hypothesis. If rejected, the candidate is parked and recorded as a
   negative result.
3. **Production prototype**: implement the fix in the relevant source
   file, preserving public APIs and byte-identical event stream.
4. **Real-run re-profile**: re-run `density_high_large_durable`,
   `density_high_xlarge_durable`, `density_high_large_ephemeral`, and
   `density_high_xlarge_ephemeral` on the workload grid. The wall delta
   on all four cells is the production verdict.
5. **Parity gate**: all `tests/testthat/` byte-identical. Peer benchmark
   Tier 1 within tolerance. Workload grid scenario definitions
   unchanged.

Steps 1-2 are the spike round. Steps 3-5 are the v0.1.8.10 implementation
tickets that follow.

### 2. Within-run share is more honest than wall-to-wall comparison

Local CPU power-profile drift can silently inflate or deflate apparent
speedup. Each spike log reports:

- The isolated component's before/after speedup ratio (the mechanism
  evidence).
- A wall-translation paragraph that applies Amdahl using the workload
  grid record numbers, capping the expected wall improvement.

### 3. Amdahl is non-negotiable

Each spike log includes a "Wall translation" section computing the maximum
possible wall improvement using:

```text
max_wall_speedup = 1 / ((1 - p) + p / s)
```

where `p` is the fraction of total wall the candidate addresses on the
reference cell and `s` is the spike's isolated speedup.

If the wall translation caps at < 5% improvement, the spike log explicitly
states whether to proceed (e.g., the architectural scaling win is the real
value, or the lane is substrate for K1 and not measured purely by R-side
recovery) or park.

### 4. Verify regression tests fail against pre-fix code (v0.1.8.9 addition)

The v0.1.8.9 Batch 2 record-scale character-vector corruption taught a
lesson: targeted suites passed against broken code because the regression
test wasn't running at scale yet. v0.1.8.10 adds an explicit gate:

> Each spike log explicitly verifies that the new regression test FAILS
> against the unfixed implementation, confirming it is a true regression
> gate rather than a passing test that happens to coexist with the fix.

For the ephemeral redesign spikes (1, 2, 10) this is especially important
because the reconstruction-pass elimination is a structural change with
broad blast radius. Add the regression-test-fails-against-pre-fix-code
verification to each ephemeral spike log.

## Spike log template

Each spike log under `dev/spikes/spike-<name>.md` follows the structure
established in `dev/spikes/spike-event-buffer-rewrite.md` from the v0.1.8.7
round:

```markdown
# Spike Log: <Title>

**Date:** YYYY-MM-DD - **Host:** <host info> - R 4.5.2 - **Status:** v0.1.8.10
optimization-round input.

**Script:** dev/spikes/spike-<name>.R. Raw CSV (gitignored):
dev/bench/results/spike_<name>.csv.

**Relates to:** dev/bench/notes/single_core_optimization_inventory.md
(candidate <ID>); inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md
(residual <N>).

## Question

The hypothesis being tested.

## Method

Faithfulness statement: how the spike replicates the real production code
path. Variants compared.

## Results

A small table of before/after numbers across at least two scales (to
expose super-linearity if present).

## Findings

Mechanism confirmed or rejected. Which variant wins. Whether the
super-linearity hypothesis matches the observed scaling.

## Wall translation

Amdahl-bounded wall improvement on the reference cell. Reference numbers
from the LDG-2503 closeout (post-v0.1.8.9 baseline):
- density_high_xlarge_durable: 232.03s wall, 199.06s loop.
- density_high_xlarge_ephemeral: 372.55s wall.
- density_high_large_durable: 85.12s wall, 68.88s loop.
- density_high_large_ephemeral: 101.58s wall.

## Caveats

The isolated overestimate factor (the v0.1.8.7 buffer spike overestimated
by ~3x; v0.1.8.9 batches mostly over-delivered against synthesis
projections). What the real-run re-profile must confirm.

## Regression-test verification

Confirm the new regression test FAILS against the unfixed implementation,
confirming it is a true regression gate.

## Recommendation

Proceed to v0.1.8.10 implementation ticket, or park as negative result.
```

## What this round is not

- Not authorization to change `R/fold-engine.R`, `R/fold-reconstruction.R`,
  `R/sweep.R`, or any other production source. Cut v0.1.8.10 implementation
  tickets first, with the spike log as the load-bearing source reference.
- Not a public performance claim. Numbers are local-host, current-source,
  ledgr-only.
- Not a benchmark. Spikes are isolated mechanism reproducers, not
  workload-level measurements. The workload grid is the
  workload-level measurement surface.
- Not a parity gate. Spikes use synthetic data and may not preserve
  byte-identical output of the real code path. The byte-identity gate
  applies to v0.1.8.10 implementation tickets, not to spike scripts.
- Not a K1/`ledgrcore` decision. The compiled-core spike is explicitly
  gated on this round's substrate work landing first per the horizon's
  2026-06-01 K1 entry update.

## Cross-cutting conclusions

After all spikes complete, the cross-cutting conclusions live in
`architecture_synthesis.md` in this directory. That synthesis is the input
to the v0.1.8.10 spec packet. Until the synthesis exists, this README is
the plan-of-record.

The v0.1.8.10 spec packet should match the v0.1.8.9 packet's structure:
spec doc, ticket markdown, machine-readable tickets YAML, batch plan,
per-lane attribution log, release closeout.

## Source evidence

- `inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md` —
  closeout artifact with the post-v0.1.8.9 baseline numbers this round
  measures against.
- `dev/bench/notes/single_core_optimization_inventory.md` — complete
  inventory with simulation/profile classification per item, updated with
  v0.1.8.9 dispositions.
- `dev/bench/results/ledgr_bench_record_20260601T065635Z_summary.csv` —
  v0.1.8.9 closeout workload grid record. Reference baseline for the
  v0.1.8.10 spikes.
- `dev/bench/results/peer_benchmark_record_20260601T073325Z_*` —
  v0.1.8.9 closeout peer benchmark record. Contextual reference.
- `inst/design/horizon.md` — 2026-06-01 entries: R-side substrate framing,
  K1 spike gate, disclaimer addition. Direction for v0.1.8.10 and beyond.
- `inst/design/spikes/ledgr_v0_1_8_9_optimization_round_spike/` —
  prior cycle's spike round, the precedent this round follows.
- `inst/design/spikes/ledgr_optimization_round_spike/` — v0.1.8.7 cycle's
  spike round, the original methodology reference.
- `inst/design/maintainer_review/v0_1_8_7_optimization_round.qmd` —
  per-lane attribution discipline reference.
