# Spike Log: Projection / features_wide Surface (collapse)

**Date:** 2026-05-29 · **Host:** Intel Core i9-12900K, Windows 11 · R 4.5.2,
collapse 2.1.7 · **Status:** v0.1.8.7 input. **Negative result** — confirms the
projection lane is not a performance priority.

**Script:** `dev/spikes/spike-projection-collapse.R`. Raw CSV (gitignored):
`dev/bench/results/spike_projection_collapse.csv`.

**Relates to:** `inst/design/collapse_optimization_map.md` (Tier 1, projection);
LDG-2453/2455 (features_wide already cheap to build).

## Question

The strategy reads `ctx$features_wide` (a data.frame) and usually converts it
back to a matrix (`as.matrix(fw[FEATURE_COLS])`). How much does that df
round-trip cost vs a matrix-canonical surface, and do `mctl`/`qM` help?

## Results (500 inst x 1260 pulses x 50 feat, over all pulses)

```
strategy-facing matrix per pulse:
  1. df + as.matrix   (current round-trip)  : 0.740s
  2. df + qM          (faster convert)      : 0.370s   (2.0x vs #1)
  3. matrix-canonical (no df; RFC change)   : 0.320s   (2.3x vs #1)
  parity: TRUE (identical matrix values across paths)

df build: base-R stamp 0.250s  vs  collapse::mctl 0.410s  (0.6x -- mctl SLOWER)
```

## Findings

- **Not a perf lane.** The entire features_wide build + df->matrix round-trip is
  ~0.74s for a whole run -- negligible vs the buffer (~137s) or the wall
  (hundreds of s). LDG-2453/2455 already made the build cheap; there is no
  meaningful perf left here.
- **matrix-canonical saves ~0.4s/run** (0.74 -> 0.32). Worth doing for
  **API/contract cleanliness** (strategies get a matrix and skip the round-trip;
  primitives-in-core), **not for speed**. Belongs in the v0.1.8.7 primitive
  *contract* RFC, not the perf lanes.
- **`mctl` is slower than the base-R stamp** (0.41 vs 0.25) -- drop it; the
  existing `ledgr_fast_data_frame` stamp wins.
- **`qM` is 2x faster than `as.matrix`** for the conversion, but on a sub-second
  component -- immaterial.

## Recommendation for the RFC

Treat projection as a *contract* decision, not a perf lane: a matrix-canonical
strategy surface is justified by cleaner ergonomics (and feeds the
primitives-in-core direction), not throughput. Do not adopt `mctl` for the build.
`qM` is optional if the df surface is retained.

**Scope (Codex review):** this negative result is scoped narrowly to the
`features_wide` *manifestation* and df->matrix conversion. It does **not** cover
feature cache-key construction, persistent feature storage, DuckDB projection IO,
or the full-long export path — none of which were measured here.
