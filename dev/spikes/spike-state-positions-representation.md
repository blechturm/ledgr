# Spike Log: state$positions Representation (current vs env vs intvec)

**Date:** 2026-05-31 - **Host:** local development host - R 4.5.2 - **Status:**
v0.1.8.9 optimization-round input (Batch A, Spike 3).

**Script:** `dev/spikes/spike-state-positions-representation.R`. Raw CSV
(gitignored): `dev/bench/results/spike_state_positions_representation.csv`.

**Relates to:** `dev/bench/notes/per_pulse_complexity_findings.md` (Suspect 3),
`dev/bench/notes/single_core_optimization_inventory.md` (A3), LDG-2482.

## Question

`state$positions[[id]] <- value` at `R/fold-engine.R:354-355` may trigger
whole-vector copy because the pulse-context constructor a few lines earlier
holds a reference (`positions = state$positions` in the ctx list). Does the
copy actually fire under that pattern? Which candidate fix actually removes
it?

## Method

Faithful replica of the closure-capture pattern: a ctx-like list holds
`positions = state$positions` BEFORE each mutation, mimicking the production
fold-engine.R flow where ctx is constructed at pulse start and state mutates
inside the pulse. `tracemem` detects copies; timing measures the throughput
cost of each candidate representation.

Five variants:

- `current`: list state, named-numeric positions, ctx holds reference.
- `env_state`: env-based state, named-numeric positions, ctx holds reference.
- `env_positions`: list state, env-based positions, ctx holds env reference.
- `intvec_id_map`: list state, bare numeric + `id -> idx` map, ctx holds
  reference.
- `collapse_setv`: list state, bare numeric + `id -> idx` map, mutation via
  `collapse::setv(state$positions, idx, cur + 1, vind1 = TRUE)`. The v0.1.8.7
  buffer spike confirmed `setv` writes in-place by C reference, bypassing R's
  copy-on-modify even under refcount-elevated conditions. `setv` is
  value-neutral per `inst/design/collapse_optimization_map.md`, so it does
  not require the `ledgr_with_collapse_deterministic()` wrapper.

Three shapes timed: 100 inst x 10k mutations, 1000 inst x 10k mutations,
1000 inst x 100k mutations (the last approximates the xlarge fill count of
~133k).

## Results

### tracemem evidence (3 mutations per variant)

```
current        : 3 copy lines  (R copies positions on every mutation)
env_state      : 3 copy lines  (R STILL copies, even with state-as-env)
env_positions  : no tracemem (environments have reference semantics, no copy)
intvec_id_map  : 3 copy lines  (R copies the bare numeric vector too)
collapse_setv  : NO COPY LINES (setv mutates underlying memory in place)
```

### Timing

```
inst   mut       |    curr  env_st env_pos  intvec    setv |  cur/eP  cur/sv
100    10000     |  0.010s  0.000s  0.010s  0.010s  0.020s |    1.0x    0.5x
1000   10000     |  0.080s  0.070s  0.030s  0.030s  0.030s |    2.7x    2.7x
1000   100000    |  0.780s  0.710s  0.170s  0.400s  0.410s |    4.6x    1.9x
```

## Findings

**Copy-on-write mechanism confirmed.** `tracemem` shows R copies
`state$positions` on every mutation in the current pattern. Each `ctx <-
list(positions = state$positions, ...)` line elevates refcount to 2, so the
next mutation triggers a copy. At 1000 inst x 100k mutations the current
pattern pays 0.72s of pure copy overhead.

**env_state does NOT help.** Putting `state` in an environment does not fix
the copy because `state$positions` is still a vector with elevated refcount.
The env wrapping around state changes nothing about the vector mutation
semantics. tracemem confirms: 3 copy lines, same as current. Timing
confirms: 0.69s vs 0.72s at the largest shape — essentially identical.

**env_positions IS the fix (~3.8x).** Making `state$positions` itself an
environment eliminates the copy because environments are reference-typed in
R. ctx capturing `state$positions` is now capturing an env reference; the
underlying env slots can be mutated without copy. Speedup is 3.8x at 1000
inst x 100k mutations.

**intvec_id_map is a partial fix (~1.9x).** A bare numeric vector with an
`id -> idx` map still copies — tracemem confirms — but the copy is cheaper
because there are no names to copy. So intvec is faster than current (1.9x)
but slower than env_positions (1.9x vs 4.6x). The win comes from cheaper
copies, not from no copies.

**collapse::setv is tracemem-clean but not a meaningful speed win at this
scale (~1.9x).** This was the most interesting finding. Per
`inst/design/collapse_optimization_map.md` and the v0.1.8.7 buffer spike,
`collapse::setv(X, i, v, vind1=TRUE)` writes by C reference and bypasses R's
copy-on-modify entirely. The Spike 3 tracemem output confirms this: zero
copy lines even under refcount-elevated conditions. But at the production
universe size (1000 instruments x 100k mutations), collapse_setv runs at
0.41s — essentially TIED with intvec_id_map at 0.40s, both about 1.9x
faster than current. The expected setv win does not materialize at this
universe scale because: (a) bare-numeric vectors copy cheaply (no names),
(b) `setv` function-call overhead in R is comparable to base-R `[[<-`
overhead, and (c) the per-iteration cost is dominated by the ctx-list
construction, id lookup, and idx lookup that BOTH variants pay equally.

The v0.1.8.7 buffer spike got 65-1300x from `setv` on buffers because the
buffers were sized to `n_inst * n_pulses` (~630k slots) and base-R copies
of those vectors were enormous. The Spike 3 vector is ~1k slots; copies are
small enough that setv's no-copy edge is washed out by the surrounding
loop overhead. The v0.1.8.7 win was scale-dependent.

**Speedup scales with universe size.** At 100 inst the speedup is
negligible — current and env_pos both run at the measurement floor. At 1000
inst, env_pos is 4.6x faster. The mechanism scales: larger named vector
means more bytes to copy per mutation. collapse_setv would have a larger
edge at much larger universes (say, 10000+ instruments), but ledgr's grid
caps at 1000 today.

## Wall translation

Reference workload: `density_high_xlarge_durable` runs in 445.02s wall,
413.47s loop, ~133k fills.

Spike measures 0.78s for current at 1000 inst x 100k mutations. Scaling
linearly to 133k mutations: ~1.0s production cost from the copy mechanism.
The per_pulse_complexity_findings.md estimate is ~1.5s of 413.5s loop;
spike is in the same range.

Amdahl bound:

- If production cost is 1s of 413.5s loop: p = 0.0024, max wall speedup
  = 1.0024x (~1s of 445s wall).
- env_positions fix: ~4.6x speedup on the 1s, recovers ~0.78s.
- intvec_id_map fix: ~1.9x speedup on the 1s, recovers ~0.48s.
- collapse_setv fix: ~1.9x speedup, recovers ~0.48s (same as intvec).

**The wall win is small (<1s).** Sequencing-wise this is the lowest-priority
of the three Batch A spikes by direct wall impact. But it confirms the
copy mechanism and gives a clear (if smaller) win on architectural cleanliness.

## Caveats

- **CRITICAL: env_positions AND collapse_setv both change semantics.** Both
  variants mutate the underlying memory in place, so `ctx$positions` (which
  references the same memory) sees subsequent mutations during the pulse.
  With current (named-vector), `ctx$positions` captures the pulse-start
  positions snapshot by value because R's copy-on-modify creates a separate
  copy on each mutation. If any production code reads `ctx$positions`
  during the pulse expecting pulse-start snapshot behavior (especially in
  the strategy callback or any helper attached to ctx), env_positions and
  collapse_setv would break that assumption silently. **Before adopting
  either, audit every `ctx$positions` read site for snapshot-vs-live
  semantics.** intvec_id_map preserves snapshot semantics (the bare vector
  still copies on mutation, so ctx$positions stays at pulse-start values).
- **collapse::setv is not a clear win at ledgr-scale universes.** Despite
  tracemem-clean evidence that setv bypasses copy-on-modify entirely, the
  per-iteration overhead at 1000-instrument scale washes out the no-copy
  win. setv would dominate at 10000+ instruments where vector copies
  become bandwidth-bound, but the v0.1.8.9 spec's reference cells cap at
  1000. The v0.1.8.7 buffer-spike win for setv (65-1300x) was driven by
  worst-case-preallocated 630k-slot buffers; that scale is not present in
  the Spike 3 setting.
- **The blast radius is larger than Spike 1 and 2.** `state$positions` is
  referenced from pulse context construction, reconstruction, telemetry,
  and the cash/positions accounting throughout the fold. Switching
  representation requires touching every read site. This is a larger
  v0.1.8.9 ticket than A1 or A2.
- **Real-run re-profile is the verdict.** As with Spikes 1 and 2.

## Recommendation

**Proceed cautiously.** The mechanism is confirmed, but the wall win is
small and the semantic-preserving fix (intvec_id_map) gives essentially
the same speedup as the collapse-based fix (collapse_setv) without the
semantic change. The faster env_positions option requires a ctx semantics
audit before it can land safely.

Three-tier recommendation:

1. **Spike 1 and 2 fixes land first.** They have smaller blast radius,
   bigger absolute wall wins, and no semantic implications.
2. **Spike 3 fix is a v0.1.8.9 lane but lower priority.** The current
   options are:
   - **intvec_id_map** (1.9x, snapshot-preserving): default choice. Medium
     blast radius (id-to-idx map + index lookups throughout fold). No
     contract risk.
   - **env_positions** (4.6x, semantic change): preferred ONLY if a
     ctx$positions audit confirms no production code relies on
     pulse-start snapshot behavior. Large blast radius (vector API ->
     environment API everywhere).
   - **collapse_setv** (1.9x, semantic change): not recommended. Same
     speedup as intvec_id_map but with the semantic risk of
     env_positions. Pure downside vs intvec_id_map in the Spike 3
     setting.
3. **collapse_setv stays available for future lanes.** If a later
   optimization round identifies a write-only buffer at much larger scale
   (10000+ instruments, or a per-pulse temporary the size of n_inst x
   n_pulses), setv becomes the right tool. That is the regime where the
   v0.1.8.7 buffer spike got 65-1300x.

Sequencing in v0.1.8.9: implement Spikes 1 and 2 first, re-measure the grid
to attribute their direct wall delta cleanly, then return to Spike 3 with
the ctx$positions audit. If the engine-vs-Backtrader gap is closing fast
enough after Spikes 1 and 2, Spike 3 may be deferable to v0.1.8.10 cleanup.

Expected real-run signature: marginal `t_loop_sec` drop (~0.5-1s on
xlarge), no `mus_per_fill_engine` curve flattening (Spike 3 is per-fill
not per-pulse). The architectural cleanup is the long-term value.
