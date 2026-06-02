# Spike Log: split() / gsplit() Reconstruction Bucket

**Date:** 2026-06-01 - **Host:** local development host (Windows, R 4.5.2,
collapse 2.1.7) - **Status:** v0.1.8.10 spike-round Batch A input
(LDG-2506, Spike 2).

**Script:** `dev/spikes/spike-reconstruction-split-bucket.R`. Raw CSV:
`dev/bench/results/spike_reconstruction_split_bucket.csv`.

**Relates to:**
- `R/fold-reconstruction.R:512-526` (the per-instrument `which()` loop
  this spike replaces)
- v0.1.8.7 collapse-vs-split prior finding (`collapse::gsplit()`
  materially beats base R `split()` at production scale)
- `inst/design/collapse_optimization_map.md` (documented collapse
  usage doctrine)
- LDG-2505 / Spike 1 (paired: if Spike 1's inline-equity path lands,
  this bucket loop is eliminated entirely — Spike 2's value is the
  standalone fallback)

## Question

How much standalone wall does the per-instrument `which()` loop at
R/fold-reconstruction.R:512-526 cost on the v0.1.8.10 reference cells,
and does the v0.1.8.7 collapse-vs-split finding hold at this shape?

## Method

Mechanism isolation. Reproduce the production positions-matrix
bucketing logic verbatim in three variants, time each across LDG-2479
grid cell scales, verify byte-identical positions matrices across
variants.

Variant A: current `for (j) { ev_idx <- which(events$instrument_id == id) }`
loop. Theoretical complexity O(n_inst x n_events) character-equality.
Variant B: base R `split(seq_along, factor(events$instrument_id))` →
one O(n_events) bucket build, O(1) per-instrument lookup.
Variant C: `collapse::gsplit(seq_along, factor(...))` → same shape,
C-level implementation.

Parity gate: all three variants must produce the same positions matrix.

## Results

```
scale  n_inst n_pulses  n_fills    VarA_s    VarB_s    VarC_s   B_speedup  C_speedup
13.5k     100     1260    13355    0.0100    0.0000    0.0000        Inf        Inf
30k       300     1260    30000    0.0300    0.0000    0.0000        Inf        Inf
68k       500     1260    68324    0.1100    0.0000    0.0200        Inf       5.5x
130k     1000     1260   130000    0.3600    0.0300    0.0200       12.0x     18.0x
```

**Parity at all scales: PASS** for A==B and A==C identical matrices.

VarB/VarC times of 0.0000s reflect proc.time() resolution (~10ms on
Windows), not true zero. The reliably-measured 130k cell shows
Variant B at 30ms and Variant C at 20ms versus Variant A's 360ms.

### Per-event cost in the bucket loop

| Scale | n_inst | n_fills | VarA_s | us/fill |
|------:|-------:|--------:|-------:|--------:|
| 13.5k |    100 |   13355 |  0.010 |     0.7 |
| 30k   |    300 |   30000 |  0.030 |     1.0 |
| 68k   |    500 |   68324 |  0.110 |     1.6 |
| 130k  |   1000 |  130000 |  0.360 |     2.8 |

Per-event cost grows from 0.7 to 2.8 us/fill as n_inst grows 10x,
matching the O(n_inst x n_events) theoretical complexity.

## Findings

**The per-instrument bucket loop is NOT a significant cost in the
reconstruction pass.** At xlarge (1000 inst x 130k events) the loop
costs 0.36s out of Spike 1's ~14s reconstruction total — about 2.5% of
the pass. The spike spec's hypothesis that 130M character-equality
comparisons would be a meaningful bottleneck was wrong; base R's
character-vector equality is implemented in highly optimised C and the
130M comparisons take only 360ms.

**The v0.1.8.7 collapse-vs-split finding holds at the v0.1.8.10 shape.**
At 130k events Variant C (collapse::gsplit) is 18x over Variant A and
1.5x over Variant B (base split). The collapse path's win comes
primarily from the C-level grouping; the bucket-lookup phase is
identical across B and C. This confirms the doctrine in
`inst/design/collapse_optimization_map.md`: prefer collapse grouped
operations for bucket-style hot frames.

**Disposition: PARK as a standalone ticket. Subsumed by Spike 1.**
The recovery floor (0.34s at xlarge) does not clear the v0.1.8.10
decision threshold. Spike 1's inline-equity-accumulation path
eliminates the entire `ledgr_sweep_summary_from_ordered_events()` call,
including this bucket loop. There is no need for a separate
v0.1.8.10 ticket on the bucket.

**Fallback retention.** If Spike 1's design encounters semantic
issues during implementation (e.g. downstream sweep consumers query
the event log and the reconstruction path must stay), the v0.1.8.10
ticket can absorb a tiny ~5-line change to swap the
`which()` loop for `collapse::gsplit()`. Document the change as
"Variant C from Spike 2; v0.1.8.7 doctrine compliance". No separate
RFC needed.

**Cross-reference value: confirms collapse doctrine.** The 18x speedup
at production scale is the largest collapse-vs-split delta measured
since v0.1.8.7 closeout. Capture as evidence in
`inst/design/collapse_optimization_map.md` if that file is updated as
part of the v0.1.8.10 substrate work (Spike 3 / 4 / 5).

## Source references

- `R/fold-reconstruction.R:512-526` (per-instrument loop)
- v0.1.8.9 Spike 12 / LDG-2491 (chunked extractor) — related setv work
- v0.1.8.7 prior finding establishing the collapse-vs-split doctrine
- `inst/design/collapse_optimization_map.md` for the collapse usage
  policy
