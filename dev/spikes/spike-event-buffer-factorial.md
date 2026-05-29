# Spike Log: Event-Buffer Factorial (isolate the bundled factors)

**Date:** 2026-05-29 · **Host:** Intel Core i9-12900K, Windows 11 · R 4.5.2,
collapse 2.1.7 · **Status:** v0.1.8.7 (Lane B) input. Resolves Codex review point
#3 (the `base_r` "structural fix" bundled three changes).

**Script:** `dev/spikes/spike-event-buffer-factorial.R`. CSV (gitignored):
`dev/bench/results/spike_event_buffer_factorial.csv`.

## Question

`spike-event-buffer-rewrite.R`'s base-R fix changed three things at once
(capacity policy, storage topology, write op). Which factor carries the 27-101x?

## Method

Five cells of the faithful replica, same cross-frame closure / 11 mixed-type cols
/ fixed `VALS` as the parent spike:
V1 nested+worstcase+base (current) · V2 nested+doubling+base · V3 direct+worstcase+base
· V4 direct+doubling+base (base_r) · V5 direct+doubling+setv (collapse).

## Results

```
max_evt  fills   |  V1 nwb  V2 ndb  V3 dwb  V4 ddb  V5 dds
100800   2099    |   5.13s   0.19s   5.11s   0.19s   0.08s
315000   6784    | 113.57s   1.29s  97.00s   1.36s   0.17s
```

| factor | contrast | 2099 fills | 6784 fills |
| --- | --- | ---: | ---: |
| **capacity** (worst-case -> doubling) | V1->V2 (nested) | **27.0x** | **88.0x** |
| **capacity** (worst-case -> doubling) | V3->V4 (direct) | **26.9x** | **71.3x** |
| topology (nested -> direct) | V1->V3 (worst-case) | 1.0x | 1.2x |
| topology (nested -> direct) | V2->V4 (doubling) | 1.0x | 0.9x |
| **write op** (base -> setv) | V4->V5 | 2.4x | 8.0x |

## Findings

1. **Capacity is the whole structural win: 27-88x.** Over-allocating columns to
   `max_events = n_inst * n_pulses` is the villain; right-sizing + grow-by-
   doubling recovers all of it. The original "it's the sizing" read was correct.
2. **Storage topology is noise: ~1.0-1.2x.** Nested list-in-env vs direct env
   columns barely matters for speed. The rewrite does **not** need a topology
   change *for performance* (it may still be worth it for clarity).
3. **`setv` is a real secondary lever, and it scales with turnover: 2.4x ->
   8.0x.** On top of the capacity fix, in-place write removes the residual
   per-write copy of the (now doubled, not worst-case) column, and its edge grows
   with fills.

## Recommendation

Lane B's must-do is the **capacity fix** (right-size + doubling) — base R, no
dependency, ~all of the win. Add **`setv`** as the turnover-scaling completion
(collapse is adopted anyway, ADR 0004). Do not change storage topology for perf
reasons. Same caveats as the parent spike: ~3x absolute overestimate; production
re-profile is the verdict; event-stream parity gate.
