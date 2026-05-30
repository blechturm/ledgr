# ledgr Optimization-Round Spike

**Status:** Pre-RFC investigation. Results feed the v0.1.8.7 optimization round
(ADR 0004; `inst/design/collapse_optimization_map.md`). Not a v0.1.8.6
deliverable.
**Scope:** Decompose ledgr's residual slowness vs. local peers (Backtrader,
quantstrat), locate the cost, and measure candidate fixes (right-sizing,
`collapse`, primitive contract) before committing them to a spec.
**Non-scope:** ledgr implementation work, fold-core refactor, the v0.1.8.7 spec
packet itself.

Each spike is a short, self-contained, *runnable* investigation. The runnable
scripts and raw logs live in `dev/spikes/` (CSV artifacts under
`dev/bench/results/` are gitignored scratch). This directory holds the
design-level writeup: the per-spike logs are linked below, and the cross-cutting
conclusions are in `architecture_synthesis.md`.

Host for all spikes: Intel Core i9-12900K, Windows 11, R 4.5.2, collapse 2.1.7.

## Spikes

| # | Spike | Runnable + log | Headline |
|---|---|---|---|
| 1 | Event-buffer rewrite | `dev/spikes/spike-event-buffer-rewrite.{R,md}` | The big rock (profile-decisive). Base-R capacity fix **27-101x**; `collapse::setv` **65-1300x** (edge grows with turnover). O(fills^2) is the suspected mechanism, pending production re-profile. |
| 1b | Event-buffer factorial | `dev/spikes/spike-event-buffer-factorial.{R,md}` | Isolates the bundled factors: **capacity (over-allocation) is the whole win, 27-88x**; storage topology is noise (~1x); `setv` is a turnover-scaling secondary (2.4-8x). |
| 2 | Reconstruction (collapse) + determinism gate | `dev/spikes/spike-reconstruction-collapse.{R,md}` | cumsum kernel minor; fills assembly `rowbind` **58x** (read-back); **determinism gate proven** (value-bearing collapse changes under hostile `set_collapse`; explicit-args + wrapper both fix). Synthetic parity is not final parity. |
| 3 | Projection / features_wide surface | `dev/spikes/spike-projection-collapse.{R,md}` | **Negative result**, scoped to `features_wide` manifestation — not a perf lane (~0.74s/run). `mctl` slower than base-R stamp; matrix-canonical surface = contract cleanliness, not speed. |
| 4 | Amdahl (irreducible) floor | `dev/spikes/spike-amdahl-floor.{R,md}` | **No large measured callback floor** (user-decision floor ~0.1-0.2% of the loop) -> ledgr is **machinery-bound**. A large per-pulse empty-fold machinery bucket at modest turnover; buffer dominates at high turnover. |
| 4b | Empty-fold line-level profile | `dev/spikes/spike-empty-fold-profile.{R,md}` | Splits the empty-fold bucket: **~62% is timestamp/string formatting** (`format.POSIXlt` #1 at 26.6% with zero trades), ~13% strategy/ctx, ~10% `%||%`. The low-turnover rock is the **representation lane, not ctx-build**. |
| 5 | Sweep amortization | `dev/spikes/spike-sweep-amortization.md` (scripts `dev/bench/peer_sweep_{three_way,verify}.R`) | **Open input, no crossover claim.** `ledgr_sweep` amortization is **real but modest (~1.18×)** — the per-candidate fold dominates; explicit `ledgr_precompute_features()` adds nothing over the internal path. Too small to close the ~2.7× single-run gap on these workloads. |

## Findings at a glance

- The peer gap is **localized, not diffuse**: two shape-dependent rocks — the
  event buffer/emission (72-82% of loop at high turnover, profile-decisive) and
  per-pulse **boundary representation** (timestamp/string formatting: ~62% of the
  empty fold, `format.POSIXlt` #1 with zero trades). The low-turnover rock is the
  representation lane, **not** ctx-build. Not death-by-a-thousand-cuts.
- The villain is **per-event machinery** — over-allocation *and* boundary
  representation (timestamp round-trip, JSON, event-id) — an implementation
  anti-pattern, **not** the event-sourcing model. The architecture is sound; the
  slowness is removable waste.
- ledgr is **machinery-bound**: no large measured callback floor (the
  user-decision floor is ~0.1-0.2%). No architectural wall pins the single-run
  ceiling near peers — but "no *large* floor," not "zero floor."
- Every value-bearing optimization carries a **determinism gate** (explicit
  collapse args + `ledgr_with_collapse_deterministic()` pinning **`nthreads=1L`**
  + byte-identical parity fixtures) — the reproducibility USP constrains *how* we
  optimize.

Cross-cutting architecture lessons and the optimization sequence:
`architecture_synthesis.md`.
