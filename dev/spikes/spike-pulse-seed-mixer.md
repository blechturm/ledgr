# Spike Log: Cheap Deterministic pulse_seed Mixer

**Date:** 2026-06-01 - **Host:** local development host (Windows, R 4.5.2,
collapse 2.1.7) - **Status:** v0.1.8.10 spike-round Batch C input
(LDG-2512, Spike 8).

**Script:** `dev/spikes/spike-pulse-seed-mixer.R`. Raw CSV:
`dev/bench/results/spike_pulse_seed_mixer.csv`.

**Relates to:**
- `R/rng.R:33-57` (`ledgr_derive_pulse_seed` — production SHA-256 +
  canonical_json path)
- `R/rng.R:15-31` (`ledgr_derive_seed` — the inner hash + truncation
  pipeline)
- `dev/bench/notes/single_core_optimization_inventory.md` (A4)

## Question

Measure per-pulse cost of `ledgr_derive_pulse_seed` (current SHA-256 +
canonical_json) versus cheap deterministic mixers (splitmix32,
xorshift32) and decide whether the inventory A4 candidate clears the
v0.1.8.10 threshold (> 1s at 1260 pulses).

## Method

Four variants, all deterministic-replay-safe within a single R session:

Variant A: production `ledgr_derive_pulse_seed(execution_seed,
pulse_idx)`. Builds a `list(scope = "pulse", pulse_idx = i)` payload,
serializes via `canonical_json`, SHA-256 hashes, truncates to integer.
Variant B: splitmix32-style mixer — XOR / multiply / XOR steps on the
32-bit seed.
Variant C: xorshift32 (Marsaglia) — three XOR-shift steps.
Variant D: precomputed seed vector at fold setup — same per-call cost
as Variant A but amortized to ~zero at the per-pulse boundary if
implemented as a single bulk canonical_json call (this spike implements
it as per-pulse production-equivalent for measurement honesty).

Scales: 1260 pulses (xlarge production), 5000 pulses (long-fold
projection).

Determinism check: each variant produces identical output across two
calls with the same inputs in the same R session.

## Results

**Determinism: A=PASS B=PASS C=PASS.**

```
scale     n_pulses    VarA_s    VarB_s    VarC_s    VarD_s
1260p         1260    0.1400    0.0300    0.0000    0.1400
5000p         5000    0.5700    0.1000    0.0200    0.5700
```

### Per-pulse cost

| Variant            | us/pulse |
|:-------------------|---------:|
| A (SHA-256 + canon) |    111  |
| B (splitmix32)      |     20  |
| C (xorshift32)      |     <4  |
| D (precomputed)     |    114  |

Variant A matches the spike spec's ~200 us/pulse hypothesis within a
factor of 2 (Spec said ~200; measured 111 on this host).

## Findings

**Variant A at 1260 pulses is 0.14s — well below the 1s decision
threshold.** Per the spike spec's decision rule: PARK.

**At 5000 pulses VarA is 0.57s — still below threshold.** Production
fold workloads do not exceed 5000 pulses in any current grid cell.

**Variant C (xorshift32) is ~30x faster than production**, well
specified for cross-platform determinism, and could land as a
v0.1.9 or later optimization. The 0.14s recovery on xlarge wall is
~0.06% of 232s — invisible.

**Variant D (precomputed) gives no per-pulse win when implemented
naively** — same total cost as VarA because canonical_json + SHA-256
work is identical. A truly precomputed variant would build all n_pulses
payloads into one canonical_json call (one JSON write, one SHA-256 over
the entire payload, split outputs into n_pulses seeds), saving the
per-pulse list-construction overhead. Not worth measuring further
because the standalone wall is too small to matter.

## Disposition

**PARK Spike 8 for v0.1.8.10.** 0.14s standalone recovery on xlarge
fails the decision rule and is below 0.1% of production wall.

**Preserve as v0.1.9 or later candidate.** Cross-platform-safe mixer
(xorshift32 or splitmix64 with 64-bit-safe arithmetic via `bit64`) is
a clean architectural simplification — removes a SHA-256 call per pulse
and removes the canonical_json dependency from the per-pulse hot path.
If the v0.1.9 substrate round revisits the per-pulse boundary cost,
this becomes a one-paragraph fix.

**Implementation caveat for any future ticket.** The 32-bit mixer
implemented in this spike uses base-R bitwise ops which trip integer
overflow warnings (50 warnings during the run). A production
implementation should use either:

- `bit64::as.integer64` for 64-bit modular arithmetic; or
- a C-implemented mixer exposed via the existing primitive layer.

Cross-platform determinism (the load-bearing property) requires the
mixer to produce identical output bit-for-bit across architectures.
xorshift32 and splitmix64 are well-specified for this; the R 32-bit
integer signed-overflow trap requires care.

## Source references

- `R/rng.R:33-57` (`ledgr_derive_pulse_seed`)
- `R/rng.R:15-31` (`ledgr_derive_seed` — the SHA-256 + canonical_json
  inner pipeline)
- `dev/bench/notes/single_core_optimization_inventory.md` (A4)
- Marsaglia, G. (2003). "Xorshift RNGs". Journal of Statistical
  Software 8(14). — xorshift32 reference specification.
- Steele, G. L., Lea, D., & Flood, C. H. (2014). "Fast Splittable
  Pseudorandom Number Generators". OOPSLA. — splitmix64 reference.
