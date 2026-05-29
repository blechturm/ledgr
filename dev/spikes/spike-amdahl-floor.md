# Spike Log: Amdahl (Irreducible) Loop Component

**Date:** 2026-05-29 · **Host:** Intel Core i9-12900K, Windows 11 · R 4.5.2 ·
**Status:** v0.1.8.7 input. Settles the "callback-bound vs machinery-bound"
question behind the backtrader bet.

**Script:** `dev/spikes/spike-amdahl-floor.R`. Raw CSV (gitignored):
`dev/bench/results/spike_amdahl_floor.csv`.

## Question

Of the per-pulse fold loop, how much is the IRREDUCIBLE strategy-callback + user
logic (which no engine optimization can remove for an event-driven,
path-dependent backtest) vs OPTIMIZABLE ledgr machinery? That decides whether
ledgr's single-run ceiling is pinned near backtrader by a shared callback floor,
or set by ledgr's own machinery (which we can grind down).

## Method

- **Part A (standalone):** the minimum per-pulse work — build an n_inst target
  vector + a vectorized decision — with no engine. The pulse loop is sequential
  (positions evolve), so the callback cannot be vectorized away; measured over
  REPS=2000 runs to clear the timer.
- **Part B (fold differential, via bench):** t_loop for empty -> read/score ->
  turnover at 200x504, splitting ctx-build / feature-access / fill-emission.

## Results (200 inst x 504 pulses)

```
Part A  irreducible floor : 0.00344s/run  (6.84 us/pulse)

Part B  fold loop decomposition (t_loop, differential)
        ctx-build + scaffold (empty)     : 1.040s   (57%)
        feature access (read - empty)    : 0.270s   (15%)
        fill emission (turnover - read)  : 0.520s   (28%, incl current buffer)
        total loop (turnover)            : 1.830s

Amdahl  irreducible floor : 0.19% of the loop
        optimizable machinery : 99.8%
```

## Findings

1. **ledgr is machinery-bound: no large measured callback floor.** The
   *user-decision* floor is ~0.1-0.2% of the loop (6.84 us/pulse; the % varies
   run-to-run with the differential). The loop is overwhelmingly optimizable
   ledgr machinery. **Scope caveat (Codex):** Part A does not call the real
   strategy through the ledgr path — it omits the R function call, `ctx` access,
   target validation, and the invocation wrapper. So this is a *user-decision/
   vector* floor, not the full strategy-callback floor; some irreducible
   machinery remains (strategy invocation, minimal ctx/primitive access, target
   validation, accounting). Read it as "no *large* floor," not "zero floor," and
   do not cite 0.2% as a hard constant.
2. **Two optimizable rocks, shape-dependent:**
   - **per-pulse empty-fold machinery (~half-to-most of the loop here)** — the
     "empty" baseline is *not* pure ctx-build. The line-level profile
     (`spike-empty-fold-profile.md`) split it: **~62% timestamp/string formatting**
     (`format.POSIXlt` #1 at 26.6% with zero trades), only **~13% the strategy/ctx
     callback**, ~10% `%||%`. So the low-turnover rock is the **representation /
     formatting lane**, not ctx-build — that is the next target after the buffer.
   - **fill emission (incl buffer)** — at HIGH turnover the buffer's O(fills^2)
     (suspected mechanism) pushes this to 72-82% (LDG-2457 real-run profile, the
     decisive evidence). This 200x504 snapshot under-represents emission; at the
     big turnover shape emission leads, at modest turnover the empty-fold bucket
     leads. Both real, both optimizable.
3. **Correction to the "shared callback floor" framing.** Earlier I argued ledgr
   and backtrader share a per-pulse callback floor that bounds both. The measured
   user-decision floor is negligible — so the binding constraint is *machinery*,
   which is optimizable. Single-run "beat backtrader" is a machinery race, not a
   floor-blocked impossibility: a compiled core would flip it, and even pure-R it
   is a question of how lean the machinery gets, not a wall.

## Caveats

- 200x504 is modest turnover; it under-weights emission relative to the
  500x1260 turnover run. The decomposition is shape-dependent (turnover shifts
  weight from ctx-build to the buffer).
- Floor measured via REPS averaging (per-run floor is below timer resolution).
- The differential attributes via t_loop deltas, not an in-fold profiler; good
  enough for the share question, not a line-level attribution.

## Implication for the bet

Machinery-bound means real headroom and no architectural wall: after the buffer,
**ctx-build is the next rock** (the primitive contract), and there is no callback
floor stopping ledgr from reaching / passing backtrader on machinery alone
(compiled core) or amortization (sweeps). The single-run pure-R fight is still
hard (backtrader's machinery is mature), but it is a grind, not a dead end.
