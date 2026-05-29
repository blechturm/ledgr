# RFC Synthesis: v0.1.8.7 Optimization Round - Single-Core R Hot Path

**Stage:** Synthesis (stage 7, binding artifact)  
**Author:** Codex  
**Date:** 2026-05-29  
**Synthesizes:** `rfc_optimization_round_v0_1_8_7_seed.md`,
`rfc_optimization_round_v0_1_8_7_response.md`, and
`rfc_optimization_round_v0_1_8_7_seed_v2.md`.

**Final-review revision (Claude, 2026-05-29):** reconciled the sub-second
timestamp policy to the maintainer decision recorded in seed v2 — it is
**resolved** (whole-second contract; sub-second out of scope / not HFT), **not
pending**. Sections updated: Cycle Decision, Lane R, the former "Maintainer
Decision Pending" (now "Resolved"), Open Questions, Immediate cross-cycle
obligations, Stage Note. No other binding content changed. Load-bearing code
citations spot-checked and hold (`R/fold-core.R:72`, `R/pulse-context.R:619`,
`R/fold-core.R:688`); v2 ↔ synthesis consistent on all other bound positions.

**Maintainer legacy-cleanup revision (2026-05-29):** v0.1.8.7 explicitly
removes pre-snapshot / pre-function-strategy legacy execution surfaces from the
modern engine contract. Raw `bars` execution, run-time `data_hash` identity, and
R6 strategy support are not compatibility obligations in this cycle. The spec
must route any archival remnants as historical diagnostics or remove them; no
legacy path may remain load-bearing for fold-core execution.

## Cycle Decision

Proceed to synthesis. Role rotation is honored: Claude authored seed v1 and
seed v2; Codex authored the response and this synthesis. No additional response
round is needed.

The sub-second timestamp policy is **resolved** (maintainer decision,
2026-05-29): whole-second is the contract and sub-second is out of scope — ledgr
is not an HFT engine. No maintainer decision is pending. The only residual is a
spec-cut detail: whether the seal **rejects** sub-second input (preferred) or
**truncates** it; both honor the bound whole-second contract. Implementation must
preserve current observable whole-second bytes.

The legacy execution policy is also **resolved** (maintainer decision,
2026-05-29): v0.1.8.7 removes legacy gunk rather than carrying it through the
optimization round. Modern execution is snapshot-backed and function-strategy
based. Raw mutable `bars` execution and R6 strategy support are removed or fail
clearly before entering the fold.

## Decision Summary

Accept v0.1.8.7 as a single-core, pure-R optimization round focused on removing
hot-path boundary representation and event-emission waste from the existing
fold core, while also removing legacy execution surfaces that force hot-path
code to preserve obsolete invariants. Do not add a ledgr-authored compiled core,
do not add parallel dispatch, and do not claim sweep crossover.

The binding order is:

1. Bind primitive-in-core, sealed-snapshot-only execution, function-strategy-only
   execution, and emitted-event parity gates before implementation.
2. Remove or fail legacy raw-`bars` and R6 strategy paths before they can enter
   the fold.
3. Land Lane B0 first if it is surface-preserving.
4. Land Lane R next or in the same implementation arc, but measure it
   separately from Lane B.
5. Defer deeper typed event-emission changes that alter fill inputs or context
   surfaces until the primitive-contract binding is explicit.
6. Land Lane C as a read-back/reconstruction cleanup behind the value-bearing
   collapse determinism gate.

## Code Verification

The v2 load-bearing code references hold against current source.

- Buffer capacity is worst-case at [R/fold-core.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/fold-core.R:72):
  `length(pulses_posix) * length(instrument_ids)`.
- Durable event buffers allocate full columns at
  [R/backtest-runner.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R:365)
  and write one event field at a time at
  [R/backtest-runner.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R:385).
- Durable fill emission normalizes/parses timestamps, serializes metadata, and
  formats event IDs at
  [R/backtest-runner.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R:176),
  [R/backtest-runner.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R:188),
  and [R/backtest-runner.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R:190).
- Sweep memory append has the same event-field append shape at
  [R/sweep.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/sweep.R:750), called via
  [R/sweep.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/sweep.R:868).
- `ledgr_normalize_ts_utc()` formats POSIXt inputs and reparses strings at
  [R/pulse-context.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/pulse-context.R:619).
- Durable identity formatting exists in `canonical_json()`,
  `ledgr_feature_cache_key_from_parts()`, `ledgr_snapshot_hash()`, and
  `ledgr_run_data_subset_hash()` at
  [R/config-canonical-json.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/config-canonical-json.R:61),
  [R/feature-cache.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/feature-cache.R:101),
  [R/snapshots-hash.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/snapshots-hash.R:26),
  and [R/data-hash.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/data-hash.R:122).
- Reconstruction uses per-instrument `which()` scans at
  [R/fold-core.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/fold-core.R:500) and
  [R/fold-core.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/fold-core.R:841),
  per-row fill data.frames at
  [R/fold-core.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/fold-core.R:605),
  and `do.call(rbind, rows)` at
  [R/fold-core.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/fold-core.R:688).
- Sweep amortizes feature precompute/projection, not the per-candidate fold:
  one runtime projection is built at
  [R/sweep.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/sweep.R:115), passed into
  candidate execution at [R/sweep.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/sweep.R:189),
  installed into the fold object at
  [R/sweep.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/sweep.R:634), and the fold
  is rerun per candidate at [R/sweep.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/sweep.R:662).

## Bound Positions

### Lane B0 - Event Buffer / Emission

Accepted first if surface-preserving.

Bound scope:

- change capacity policy from worst-case preallocation to realistic sizing /
  grow-by-doubling;
- optionally use `collapse::setv(col, i, v, vind1 = TRUE)` for in-place writes;
- keep event rows, ordering, event IDs, timestamps, metadata JSON, and DB/memory
  event surfaces byte-identical.

This lane is value-neutral. It does not need the value-bearing floating-point
collapse gate, but it does need event-stream parity across durable run and
memory sweep paths, including POSIXct class and `tzone` preservation.

If the work changes fill-model inputs, next-bar shape, payload construction, or
strategy-visible context, it is no longer B0. It becomes B1 and waits for the
primitive-contract binding.

### Lane R - Representation / Formatting

Accepted as the cross-cutting low-turnover lane, with a durable-identity fence.

Bound scope:

- remove per-pulse/per-fill hot-path formatting where it is not durable
  identity;
- carry trusted POSIXct values through hot paths;
- preserve current observable whole-second timestamp bytes (sub-second is out of
  scope under the resolved whole-second contract);
- preserve exact event-id strings in this optimization round.

Non-scope:

- `canonical_json()` formatting;
- snapshot hashes;
- data-subset hashes;
- config/provenance hashes;
- feature definition fingerprints;
- strategy/config identity hashes.

If a Lane R change touches any of those identity paths, it is blocked until an
explicit accepted contract change updates the relevant hash or fingerprint pins.

### Lane C - Reconstruction / Read-Back

Accepted as a read-back/reconstruction cleanup, not a primary run-wall speed
claim.

Permitted implementation patterns:

- preallocated columns or `collapse::rowbind` for fills assembly;
- grouped collapse operations such as `fcumsum(x, g)` where value-bearing parity
  is proven.

Required parity fixtures cover real ledgr event semantics, not only synthetic
rows: CASHFLOW-before-fill, opening positions, partial close/open,
close-before-open split rows, invalid/missing rows, DB-backed and memory-backed
event tables, event order, column order, classes, and `event_seq`.

### Collapse Determinism Gate

Accepted and strengthened.

All value-bearing collapse operations must run inside a deterministic wrapper
that sets a full known collapse state and restores it on exit/error. The
minimum bound state is:

- `nthreads = 1L`;
- `na.rm = FALSE`;
- `sort = TRUE`;
- `stable.algo = TRUE`.

Other `set_collapse()` fields exposed on the host (`remove`, `digits`, `stub`,
`verbose`, `mask`) must either be pinned or documented as irrelevant for the
used operations. Hostile-setting fixtures must mutate at least `nthreads`,
`na.rm`, `sort`, and `stable.algo`.

### ADR 0004 Dependency Moves

Accepted for the v0.1.8.7 packet:

- drop `cli`;
- drop `R6` and consolidate on function strategies;
- add `collapse` under the deterministic-wrapper discipline;
- keep `tibble`.

The R6 mutation guard decision is resolved by removal: do not port the old
`LedgrStrategy` mutation guard. Replace it only with function-strategy contract
checks that apply uniformly to direct run, sweep, and replay paths.

### Legacy Execution Cleanup

Accepted as a binding v0.1.8.7 cleanup lane. The optimization round should not
carry pre-snapshot or pre-function-strategy compatibility paths through the fold
core.

Bound scope:

- all execution entries (`ledgr_run()`, `ledgr_sweep()`, `ledgr_backtest()`, and
  low-level `ledgr_backtest_run()`) require snapshot-backed configs before the
  fold;
- configs without `data.source = "snapshot"` and `data.snapshot_id` fail clearly
  before snapshot runtime views or fold state are constructed;
- raw mutable `bars` table execution is removed from modern execution identity;
- run-time `ledgr_run_data_subset_hash()` value rehashing is removed for sealed
  snapshot-backed runs and replaced by the already verified snapshot identity
  plus selector: `config_hash`, stored `snapshot_id`, verified `snapshot_hash`,
  ordered `instrument_ids`, `start_ts`, and `end_ts`;
- `runs.data_hash`, `ledgr_data_hash()`, and snapshot-adapter `data_hash`
  metadata are either removed or explicitly marked archival/historical in the
  spec; they must not be described as modern sealed-run identity;
- R6 strategy classes and R6-specific replay/mutation semantics are removed from
  modern execution.

The gate is not backward compatibility. The gate is fail-loud correctness:
legacy inputs must not silently run through a partially modernized engine, and
modern snapshot-backed runs must preserve deterministic event/equity/replay
bytes except where a separate ticket explicitly changes a documented identity.

### Projection And Matrix-Canonical Surface

Projection is not a v0.1.8.7 performance lane. The matrix-canonical strategy
surface remains a future contract/ergonomics RFC, not part of the hot-path
optimization tickets unless the v0.1.8.7 spec explicitly pulls a narrow piece
in as support work.

### Sweep Amortization

Sweep amortization remains open input, not a bound speed claim. The current
ledgr-side sweep measurement shows modest amortization (~1.18x on the measured
feature-heavy N=10 check) and no crossover result. It informs future benchmark
work but does not change the single-core single-run optimization scope.

## Wall-Effect Bounds

The synthesis binds ranges, not point predictions.

| Lane | Regime | Bound |
| --- | --- | --- |
| B0 | high turnover | about 1.7x-1.9x wall if production re-profile confirms removal of buffer/write-fill work |
| R | turnover | about 1.05x-1.15x unless the post-B0 profile attributes more wall to representation |
| R | low turnover / wide | likely large, because the empty-fold profile is formatting-heavy |
| C | read-back | meaningful for `ledgr_results(..., "fills")`, not a primary run-wall claim |

Do not multiply component speedups directly. B and R must be measured
separately because a deeper typed-emission rewrite may subsume payload work that
Lane R also claims.

"Backtrader-level" is a target/possibility, not an expected result. The release
gate should report the post-lane benchmark honestly, including whether ledgr
catches quantstrat or approaches Backtrader.

## Maintainer Decision (Resolved 2026-05-29)

**Sub-second timestamp policy → resolved.** Whole-second is the contract;
sub-second is **out of scope** — ledgr is not an HFT engine and sub-second
resolution is a deliberate non-goal. No maintainer decision is pending; this
synthesis is unblocked. The seal-level enforcement (reject vs truncate) is
demoted to a spec-cut detail (**reject preferred** — do not silently accept data
ledgr cannot faithfully represent). Implementation must preserve current
observable whole-second bytes.

## Open Questions Promoted To Spec-Cut

These are same-window implementation decisions for the v0.1.8.7 spec packet:

- **Buffer sizing policy:** initial capacity, growth factor, and cap behavior
  for the doubling event buffer.
- **Function-strategy guard replacement:** remove the old `LedgrStrategy` / R6
  mutation guard and decide which function-strategy checks, if any, replace it
  uniformly across direct run, sweep, and replay. The current inconsistency
  (replay yes, direct run no) must not survive accidentally.
- **Representation-site enumeration:** exact `formatC`/`sprintf`/`paste` sites
  that Lane R may vectorize/defer while preserving output bytes.
- **Lane boundaries in tickets:** separate B0, R, B1, and C tickets so that
  measurements can attribute wins without double counting.
- **Collapse wrapper placement:** define the wrapper helper and the allowed call
  sites before the first value-bearing collapse change lands.
- **Whole-second enforcement at the seal:** reject sub-second input (preferred)
  vs truncate to whole-second — both honor the bound whole-second contract; an
  implementation choice, not a product escalation.
- **Legacy-removal mechanics:** exact treatment of `ledgr_backtest_run()`,
  `ledgr_data_hash()`, `runs.data_hash`, snapshot metadata `data_hash`, old tests,
  and vignettes. The direction is removal from modern execution; the spec decides
  whether archival helpers remain exported, become internal, or are deleted.

## Future Obligations Recorded

These require later RFCs or later roadmap windows:

- **Compiled core:** C/Rcpp/Rust/native fold core remains the future single-run
  speed lever; out of scope for v0.1.8.7.
- **Sweep amortization and peer crossover:** continue as a benchmark/design
  track after the current open input lands; no crossover claim is bound here.
- **Matrix-canonical strategy surface:** contract/ergonomics RFC, separate from
  this performance round.
- **Parallel/multicore sweep dispatch:** deferred until single-core hot paths
  are cleaned up.
- **Durable identity format redesign:** any change to snapshot/config/provenance
  hash bytes requires its own explicit contract decision.

## Verification Gates For Ticket Cut

The v0.1.8.7 spec must include gates for:

- source-loaded benchmarks only, with installed-package mismatch guards;
- event-stream parity for B0 across durable run and memory sweep;
- timestamp parity for daily/minute/second/sub-second inputs across durable
  events, memory events, equity rows, replay, and reopen;
- durable hash/fingerprint pins staying green for Lane R;
- exact event-id string preservation;
- legacy raw-`bars` / non-snapshot configs fail clearly before fold entry, and
  snapshot-backed resume no longer depends on per-run value rehashing;
- hostile `set_collapse()` invariance for value-bearing collapse paths;
- real-ledgr reconstruction parity for Lane C;
- real-run re-profile after each major lane, especially B0 and R;
- post-lane peer benchmark remeasurement without claiming peer superiority
  unless the measured rows support it.

## Applied Horizon Entry

### 2026-05-29 [optimization] v0.1.8.7 post-synthesis direction

The accepted v0.1.8.7 optimization-round synthesis binds a single-core pure-R
hot-path cleanup and legacy-cleanup round: surface-preserving event-buffer
capacity/write fixes first, hot-path representation/formatting cleanup with
durable-identity bytes fenced off, read-back reconstruction cleanup behind a
deterministic collapse gate, and removal of pre-snapshot / R6 execution gunk
from the modern fold contract. It does not authorize a compiled core, parallel
dispatch, sweep crossover claims, or durable identity format changes.

Themes:

- **Native core later:** a compiled fold core remains the later lever for
  decisive single-run peer wins.
- **Sweep amortization:** current evidence is modest and open; continue
  same-host multi-candidate peer measurement before claiming architectural
  sweep advantage.
- **Strategy-surface cleanup:** matrix-canonical / primitive strategy surfaces
  need a separate contract RFC.
- **Identity-format discipline:** durable hashes and provenance bytes remain
  fenced from hot-path representation cleanup unless a separate contract
  changes them.
- **Legacy cleanup:** raw mutable `bars` execution, R6 strategy execution, and
  run-time value `data_hash` identity are removed from modern execution rather
  than carried as compatibility constraints.
- **Parallelism later:** parallel sweep dispatch waits until single-core costs
  are no longer dominated by removable R machinery.

Promoted roadmap hooks:

- v0.1.8.7 spec packet: legacy execution cleanup, B0, R, C, ADR 0004
  dependency/interface work, and re-profile gates.
- Later v0.1.8.x or v0.1.9.x: matrix-canonical contract RFC and sweep
  amortization benchmark/RFC.
- v0.2.x or later: compiled core and parallel dispatch.

Immediate cross-cycle obligations:

- sub-second policy resolved (whole-second / not HFT); only the seal enforcement
  (reject vs truncate) remains a spec-cut detail; preserve current whole-second
  bytes;
- legacy cleanup resolved: snapshot-backed function-strategy execution is the
  modern contract; raw `bars`, R6 strategy, and run-time `data_hash` identity
  paths must be removed or fail before fold entry;
- preserve event-id bytes in this round;
- keep sweep crossover as open input until peer rows prove it.

This horizon entry has been applied to `inst/design/horizon.md`. It records
direction only; it does not authorize later work.

## Stage Note

Stages run: research input, seed v1, response, seed v2, synthesis, final review
(Claude, 2026-05-29), and maintainer legacy-cleanup revision. Stage 6
maintainer decisions are **resolved** for sub-second timestamp policy
(whole-second / not HFT) and legacy execution cleanup (remove raw `bars`, R6,
and run-time `data_hash` identity from modern execution). Horizon application
has been completed.
