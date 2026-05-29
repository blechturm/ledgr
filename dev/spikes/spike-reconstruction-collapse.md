# Spike Log: Reconstruction Lane (collapse) + Determinism Gate

**Date:** 2026-05-29 · **Host:** Intel Core i9-12900K, Windows 11 · R 4.5.2,
collapse 2.1.7 · **Status:** v0.1.8.7 optimization-round (Lane C + collapse
determinism gate) input.

**Script:** `dev/spikes/spike-reconstruction-collapse.R`. Raw CSV (gitignored):
`dev/bench/results/spike_reconstruction_collapse.csv`.

**Relates to:** `inst/design/collapse_optimization_map.md` (Tier 1),
`inst/design/audits/fold_path_hotpath_audit.md` (findings #5/#6), ADR 0004.

## Question

Lane C reconstruction (`ledgr_equity_from_events` / `ledgr_fills_from_events` /
`..._sweep_summary`, fold-core.R:445-901) uses per-instrument
`which(events$instrument_id==id)` + `cumsum` loops and per-row `data.frame()` +
`do.call(rbind)`. How much do collapse grouped ops recover, do they stay
byte-identical, and -- since this is the first value-bearing collapse use -- does
the determinism gate hold under hostile caller `set_collapse()`?

## Results

```
A. cumulative positions (per-instrument loop vs grouped fcumsum)
   n_inst  events   current  collapse  speedup  parity
   100     2600     0.020s   ~0s       large    IDENTICAL
   500     13000    0.050s   0.020s    2.5x     IDENTICAL
   1000    26000    0.170s   ~0s       large    IDENTICAL

B. fills assembly (per-row data.frame + do.call(rbind) vs collapse::rowbind)
   2.900s  vs  0.050s  ->  58x   IDENTICAL   (13k rows)

C. determinism gate (hostile set_collapse + injected NAs)
   fcumsum unwrapped-under-hostile == baseline?  FALSE
   fcumsum wrapped-under-hostile   == baseline?  TRUE
   fmean   relies-on-global        == baseline?  FALSE
   fmean   explicit-arg            == baseline?  TRUE
   fmean   wrapped                 == baseline?  TRUE
```

## Findings

1. **Cumulative-position kernel: minor.** `fcumsum(x, g)` is byte-identical to the
   per-instrument loop and faster, but the absolute cost is sub-second even at
   26k events. The loop's O(n_inst^2) `which()` re-scan only starts to show at
   high instrument counts; not a big rock (consistent with LDG-2454).
2. **Fills assembly: the real win -- 58x.** Per-row `data.frame()` + `do.call(rbind)`
   = 2.9s for 13k rows; `collapse::rowbind` = 0.05s, byte-identical. On the
   READ-BACK path (`ledgr_results(bt,"fills")`), not the run wall -- but a
   genuine results-access cost. (A preallocated-column rewrite, like the sweep
   summary already uses, is the no-dependency alternative; `rowbind` is the
   collapse one.)
3. **Determinism gate PROVEN (the main outcome).** Value-bearing collapse ops
   (`fcumsum`, `fmean`) DO change under a hostile caller
   `set_collapse(na.rm=...)` -- the risk is real, not theoretical. Both defenses
   are validated and each makes results invariant:
   - **explicit args** (`na.rm=FALSE` in the call) -- explicit beats the global;
   - **the `with_collapse_deterministic()` wrapper** -- pins the global, restores
     on exit.

## Mandate for value-bearing collapse (Tier 1/2)

Defense in depth, required before any value-bearing collapse op ships:
- pass collapse arguments **explicitly** (never rely on the global default);
- run inside **`ledgr_with_collapse_deterministic()`** (scoped `set_collapse` +
  `on.exit` restore; hostile-settings-safe);
- gate with a **byte-identical** event/equity/fills parity fixture, and a hostile
  `set_collapse` invariance test (this spike is the template).

## Caveats

- B is read-back, not run wall. A is minor. So Lane C is a *correctness/cleanup +
  gate-proving* lane, not a buffer-scale speed lane.
- Events are synthesized at realistic scale; the kernel parity and the gate are
  structure-independent. Real-handler integration + a real-run re-profile remain
  the verdict.
- **Synthetic parity is not final parity (Codex review).** The spike proves the
  kernel and the determinism hazard, not full `ledgr_fills_from_events()` parity.
  Before shipping a rewrite, gate with real-ledgr fixtures covering: CASHFLOW
  before fill rows; opening positions; partial close/open; close-before-open
  split rows from one event; invalid/missing fill rows; DB- and memory-backed
  event tables; exact output column order, classes, and `event_seq` order.
- The wrapper must pin `nthreads = 1L` — required for byte-identity (threaded FP
  reductions can reorder accumulation even with `na.rm` pinned).

## RFC recommendation

Lane C value is primarily (a) the `rowbind`/preallocated fills rewrite (58x on
read-back, byte-identical), and (b) establishing the collapse determinism gate
(explicit args + wrapper + parity fixture) that the rest of the value-bearing
collapse map depends on. The cumsum kernel is a nice-to-have, not a priority.
