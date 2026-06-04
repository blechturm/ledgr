# ADR 0004: Lean Dependency Footprint And Function-Only Strategy Interface

## Status

Accepted for v0.1.8.7. Decision recorded during v0.1.8.6 closeout; implementation
is v0.1.8.7 and does not touch the v0.1.8.6 packet. Amends the v0.1.9
collapse-adoption gate in `ledgr_roadmap.md`. Historical record; rationale
slated to migrate across `execution_fold_core` (function-only strategy
interface) and `performance_arc_v0_1_8_x` (cli/R6/tibble/collapse dependency
posture) maintainer manual articles. See `README.md` in this directory for the
ADR wind-down policy.

## Context

- The LDG-2457 matched local peer benchmark (same-host i9-12900K, 500 x 1,260
  daily SMA crossover) put ledgr at 2.74x (durable run) / 3.33x (one-candidate
  sweep) of Backtrader.
- The LDG-2456/LDG-2457 real-run profile (`inst/design/audits/fold_path_hotpath_audit.md`)
  attributes ~72-82% of loop R time to the per-event buffer/append path
  (`handler$buffer_event`; sweep `append_event_row_list`). The feature path
  (`t_pre` ~3s) and the durable-persistence asymmetry are not the explanation
  (sweep, which drops persistence, is slower).
- Dependency audit: `cli` is 100% unused (only a stale `@importFrom cli cli_abort`
  in `imports.R`; no `cli_*` call anywhere). `R6` survives only as a legacy OO
  strategy interface (an early exploration, superseded by plain functions) plus
  four reference/test strategies and a key-resolver wrapper.
- `collapse` is pure C with **zero transitive dependencies**. `collapse::setv`
  is an in-place-by-reference scatter write that directly targets the buffer hot
  path; `qDF`/`get_vars`/`.subset2` target the reconstruction path.

## Decision

1. **Drop `cli`** — verified unused; remove the `@importFrom` and the Imports
   entry. Free.
2. **Drop `R6`** — consolidate to the canonical function `(ctx, params) ->
   targets` interface. Reimplement the four built-ins (`hold_zero`, `echo`,
   `ts_rule`, `state_prev`), `ledgr_strategy_fn_from_key`, and `TsRuleStrategy`
   as functions; migrate the contract/provenance tests. Make a conscious call on
   the `LedgrStrategy` mutation-detection guard (drop, or port a uniform
   function-based check) — it is currently applied inconsistently (replay yes,
   direct run no).
3. **Keep `tibble`** — retained deliberately as a tidyverse-compatibility signal
   for the R-native quant audience; results stay tibble-classed. `collapse::qTBL`
   / `qDF` may accelerate construction without replacing the public type. Do not
   drop `tibble` for dependency minimalism.
4. **Add `collapse`** — for the event-buffer/emission lane (and reconstruction).
   Adoption is **gated on the existing roadmap safeguard**: a
   `ledgr_with_collapse_deterministic()` wrapper with scoped
   `collapse::set_collapse()` plus on-exit / error-path restore, such that
   hostile caller-side `collapse` settings cannot change ledgr outputs. The
   "clear measured value on a production surface" half of the v0.1.9 gate is
   satisfied by the LDG-2457 profile. Try the base-R alternative first
   (direct env-bound buffer columns + realistic sizing); take `collapse::setv`
   if base R cannot reliably guarantee the in-place write.

Net Imports: 9 -> 8.

## Consequences

- One fewer Imports; the dependency graph shrinks (collapse has zero transitive
  deps; `cli` and `R6` are removed outright, both effectively dependency-free).
- The peer-gap bottleneck (buffer/append, ~72-82% of loop R time) gets a direct
  tool. The fix must be validated by **re-profiling the real run**, not isolated
  micro-benchmarks (a micro-benchmark already misled this analysis once; the
  real-run profile is authoritative).
- Removing `R6` makes the original run and replay execute the **same bare
  function**, eliminating a latent original-vs-replay execution-path divergence
  and tightening the determinism/replay guarantee.
- The tidyverse-facing result surface (`tibble`) is preserved.
- This pulls `collapse` buffer-lane adoption forward from the v0.1.9.x
  primitive-internals plan into the v0.1.8.7 fold-core primitive-contract work;
  the deterministic-wrapper precondition from that plan still applies.
- All of this is v0.1.8.7+ work; the v0.1.8.6 closeout is unaffected.
