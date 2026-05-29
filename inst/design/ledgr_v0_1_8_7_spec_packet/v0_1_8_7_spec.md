# ledgr v0.1.8.7 Spec

**Status:** Draft implementation spec for v0.1.8.7.
**Target Branch:** `v0.1.8.7`.
**Scope:** Optimization Round 2 and legacy execution cleanup: fold-core
primitive contract, event-buffer/emission lane, representation/formatting lane,
cache-key/setup lane, reconstruction lane, run-artifact materialization policy,
ADR 0004 dependency/interface changes, and explicit removal of pre-snapshot /
R6 / run-time `data_hash` legacy execution paths.
**Non-scope for this pass:** a ledgr-authored compiled fold core, parallel
sweep dispatch, durable hash/provenance byte redesign, sweep crossover claims,
matrix-canonical public strategy surface, target risk, walk-forward evaluation,
public cost/liquidity APIs, OMS work, live data logs, point-in-time regressors,
public benchmark dashboards, and public hosted performance claims.

---

## 0. Source Inputs

Authoritative inputs:

- `inst/design/contracts.md`
- `inst/design/README.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/horizon.md`
- `inst/design/rfc_cycle.md`
- `inst/design/rfc/rfc_optimization_round_v0_1_8_7_synthesis.md`
- `inst/design/adr/0004-dependency-footprint-and-strategy-interface.md`

Optimization evidence and audits:

- `inst/design/spikes/ledgr_optimization_round_spike/README.md`
- `inst/design/spikes/ledgr_optimization_round_spike/architecture_synthesis.md`
- `dev/spikes/spike-event-buffer-rewrite.md`
- `dev/spikes/spike-event-buffer-factorial.md`
- `dev/spikes/spike-empty-fold-profile.md`
- `dev/spikes/spike-amdahl-floor.md`
- `dev/spikes/spike-reconstruction-collapse.md`
- `dev/spikes/spike-projection-collapse.md`
- `dev/spikes/spike-sweep-amortization.md`
- `inst/design/audits/fold_path_hotpath_audit.md`
- `inst/design/audits/v0_1_8_7_representation_site_enumeration.md`
- `inst/design/audits/v0_1_8_7_data_subset_hash_review_request_response.md`
- `inst/design/collapse_optimization_map.md`

Benchmark context:

- `dev/bench/run_benchmarks.R`
- `dev/bench/peer_sweep_three_way.R`
- `dev/bench/peer_sweep_verify.R`
- `dev/bench/lean_reference.csv`
- `dev/bench/ziplime_reference.csv`

This spec promotes only the work below. Horizon entries remain non-binding
unless explicitly named here or in follow-up tickets.

---

## 1. Thesis

v0.1.8.7 is a single-core, pure-R hot-path cleanup and legacy-removal release.

v0.1.8.6 established that ledgr's remaining slowness is localized. The fold is
not primarily blocked by an irreducible callback floor. It is dominated by
removable R machinery:

- high-turnover runs: event buffer/emission work;
- low-turnover / empty-fold runs: timestamp and string representation work;
- setup-heavy runs: cache-key and redundant validation/identity work;
- read-back paths: reconstruction loops and per-row frame assembly.

The architecture remains event-sourced and snapshot-backed. The work in this
cycle removes obsolete compatibility paths and hot-path boundary
representations so the modern engine contract is narrow:

```text
sealed snapshot + function strategy + primitive fold internals
  -> deterministic event/equity output
  -> optional durable materialization when explicitly requested
```

The cycle does **not** claim peer superiority. "Backtrader-level" is a target
to measure after the lanes land, not a promised result.

---

## 2. Release Goals

v0.1.8.7 has eleven release goals:

1. Make sealed snapshot-backed execution the only modern execution path.
   Raw mutable `bars` execution must be removed or fail clearly before fold
   entry.
2. Remove R6 strategy execution and consolidate on the function strategy
   contract.
3. Remove run-time `data_hash` as modern sealed-run identity. Snapshot-backed
   run/resume identity is `config_hash`, stored `snapshot_id`, verified
   `snapshot_hash`, ordered `instrument_ids`, and the inclusive selector
   boundaries `start_ts` and `end_ts` (`>= start_ts`, `<= end_ts`).
4. Bind the fold-core primitive contract for the work in this packet: hot fold
   internals should pass atomic vectors, matrices, lists, index maps, and
   functions, while data.frames are boundary artifacts only.
5. Land the surface-preserving event-buffer/emission fix first when it keeps
   event rows, ordering, ids, timestamps, metadata JSON, and DB/memory event
   surfaces byte-identical.
6. Remove hot-path timestamp/string round trips that are not durable identity,
   while preserving current observable whole-second timestamp bytes and exact
   event-id strings.
7. Hoist or remove setup work that repeats run-level normalization or
   session-local identity construction inside per-(instrument, feature) loops.
8. Rewrite read-back reconstruction hot spots behind real-ledgr parity gates,
   using preallocated columns and/or deterministic `collapse` where justified.
9. Adopt `collapse` only behind a deterministic wrapper for value-bearing
   operations, and remove `cli` and `R6` per ADR 0004.
10. Formalize the fast/slow run-artifact policy: sweeps and evaluation paths
    keep heavy artifacts ephemeral; promotion/inspection paths explicitly
    materialize durable views and pay that cost.
11. Re-profile and re-benchmark after each major lane, using current source and
    honest same-host peer comparisons without overstating comparability.

The release succeeds when every legacy path named above is either gone or
fail-loud, and the remaining hot-path cost is lower, attributed, and measured
against the same benchmark shapes used to motivate the cycle.

---

## 3. Binding Order

The implementation order is binding:

1. **Contract and legacy gates first.** Add tests and/or guards proving fold
   entry is sealed-snapshot-only and function-strategy-only.
2. **Legacy cleanup.** Remove or fail raw `bars` execution, R6 strategy
   execution, and run-time `data_hash` identity before those paths can constrain
   hot-path code.
3. **Lane B0.** Land the surface-preserving event-buffer/emission fix.
4. **Lane R and Lane A.** Remove addressable representation and setup waste,
   keeping durable identity bytes fenced.
5. **Lane C.** Rewrite reconstruction/read-back paths behind value-bearing
   parity gates.
6. **Run-artifact policy.** Ensure fast/sweep paths stay ephemeral for heavy
   artifacts and promotion/inspection materializes on demand.
7. **Release attribution.** Re-profile and re-run the matched peer benchmarks
   before release closeout.

If a proposed B0 change alters fill-model inputs, next-bar shape, strategy
context, or any strategy-visible surface, it is no longer B0. It becomes a
deeper typed-emission / primitive-contract change and must be ticketed
separately with explicit parity gates.

The primitive contract is a binding rule for v0.1.8.7 work, not a mandate to
rewrite the entire fold data model in one ticket. The implementation tickets
apply the rule where they touch B0, R/A, C, legacy cleanup, and artifact
materialization. A full matrix-canonical public strategy surface or deeper typed
event-emission redesign remains out of scope unless a narrow support ticket
explicitly pulls part of it into this packet.

---

## 4. Workstream L: Legacy Execution Cleanup

This workstream removes the compatibility paths that keep obsolete
representations load-bearing.

Binding policy:

- `ledgr_run()`, `ledgr_sweep()`, `ledgr_backtest()`, and low-level
  `ledgr_backtest_run()` must not enter the fold without a sealed snapshot
  source.
- Configs without `data.source = "snapshot"` and `data.snapshot_id` fail
  clearly before runtime views or fold state are constructed.
- The compatibility wrapper may still accept a data frame as user input only if
  it immediately converts it into a sealed snapshot before execution.
- Raw mutable `bars` table execution is removed from modern execution identity.
- `ledgr_run_data_subset_hash()` is not recomputed as a modern run/resume guard
  for sealed snapshot-backed runs.
- `runs.data_hash`, `ledgr_data_hash()`, and snapshot-adapter `data_hash`
  metadata are either removed or marked archival/historical by the implementation
  ticket. They must not be described as modern sealed-run identity.
- R6 strategy classes and R6-specific replay/mutation semantics are removed
  from modern execution.

Modern sealed-run identity:

```text
config_hash
snapshot_id
verified snapshot_hash
ordered instrument_ids
start_ts with inclusive lower bound (>= start_ts)
end_ts with inclusive upper bound (<= end_ts)
```

Acceptance gates:

- A raw/non-snapshot execution config fails before fold entry.
- A sealed snapshot-backed run can execute and resume without recomputing
  `ledgr_run_data_subset_hash()`.
- Tampering with sealed snapshot bars is still caught by snapshot-hash
  verification.
- Resume identity preserves the existing selector boundary semantics:
  `ts_utc >= start_ts` and `ts_utc <= end_ts`.
- Documentation and vignettes no longer teach `data_hash` as modern run data
  identity.
- If any archival `data_hash` column/helper remains, it is documented as
  archival and is not consulted during execution, resume, replay, sweep, or
  promotion.

---

## 5. Workstream D: Dependency And Strategy Interface Cleanup

ADR 0004 is binding for this packet:

- drop `cli`;
- drop `R6`;
- keep `tibble`;
- add `collapse`.

R6 mutation guard disposition:

- Drop the old `LedgrStrategy` runtime mutation guard.
- Do not port the R6 runtime guard to functions as a compatibility mechanism.
- Function strategies remain stateless by contract:

```text
function(ctx, params) -> full named numeric target vector
```

- Any replacement checks must be function-strategy contract checks that run
  uniformly across direct run, sweep, and replay paths.
- Static strategy preflight remains the preferred check for captured mutable
  objects, RNG mutation, and unsupported context mutation.

Acceptance gates:

- Package imports no longer include `cli` or `R6`.
- Built-in/reference strategies are function-based.
- Replay and direct run execute the same function strategy contract.
- Tests previously relying on `LedgrStrategy` or R6 mutation behavior are
  migrated to function-based equivalents or removed as obsolete.

---

## 6. Workstream B0: Event Buffer And Emission

Accepted source:

- `fold_path_hotpath_audit.md`
- `spike-event-buffer-rewrite.md`
- `spike-event-buffer-factorial.md`
- `rfc_optimization_round_v0_1_8_7_synthesis.md`

Binding scope:

- Replace worst-case event-buffer preallocation with realistic sizing /
  grow-by-doubling.
- Use direct primitive column storage and/or `collapse::setv(col, i, v,
  vind1 = TRUE)` if the real-run re-profile shows it helps.
- Preserve event rows, row order, event ids, timestamps, metadata JSON, and
  DB-backed vs memory-backed event surfaces.
- Apply the same event-surface parity discipline to durable `handler$buffer_event`
  and sweep `append_event_row_list`.

Buffer sizing:

- Initial defaults: capacity around 1024, doubling growth, hard cap at the
  worst-case `n_inst * n_pulses` ceiling.
- The B0 ticket may tune the initial capacity against the real-run re-profile.
  Tuning must not reintroduce worst-case over-allocation as the default.

Explicit parity constraints:

- `meta_json` may be deferred out of the per-fill payload, but it must remain
  per-row canonical JSON:

```r
vapply(meta_list, canonical_json, character(1))
```

- A single batched JSON array for the whole metadata column is rejected.
- Event-id strings must remain byte-identical in this cycle.
- POSIXct class and `tzone` must be preserved across durable and memory events.

Acceptance gates:

- Event-stream parity for durable run and memory sweep paths.
- Real-run re-profile on the LDG-2457 turnover workload after B0.
- Same-host peer benchmark re-run after B0.
- No public API or strategy-surface change unless a separate ticket explicitly
  scopes it.

---

## 7. Workstream R: Representation And Timestamp Formatting

Accepted source:

- `v0_1_8_7_representation_site_enumeration.md`
- `spike-empty-fold-profile.md`
- `fold_path_hotpath_audit.md`

Binding policy:

- Whole-second UTC is the timestamp contract.
- Sub-second input is out of scope. Snapshot seal/ingest rejects sub-second
  timestamps with a clear error rather than truncating silently.
- The fold carries trusted, already-normalized POSIXct values through hot paths.
- Formatting and validation happen at ingress/seal or durable output boundaries,
  not per event or per pulse.
- Current observable whole-second timestamp bytes must be preserved.

Addressable Lane R sites:

- per-pulse context timestamp normalization;
- per-fill timestamp round trip;
- per-row event-id construction, output byte-identical;
- one-time all-pulse ISO materialization;
- feature hydration/read-back formatting when it affects read-back cost.

Fenced identity sites:

- `canonical_json()` formatting for config/provenance identity;
- snapshot hashes;
- feature definition fingerprints;
- strategy/config identity hashes;
- durable hash/provenance bytes generally.

The run-time data-subset value hash is not a Lane R "faster formatter" target.
It is handled by Workstream L as legacy identity removal.

Acceptance gates:

- Timestamp parity for daily, minute, and second-resolution inputs across
  durable events, memory events, equity rows, replay, and reopen.
- Sub-second input rejection at seal/ingest.
- Durable hash/fingerprint pin tests stay green.
- Event-id string preservation fixtures stay green.
- Post-R real-run re-profile distinguishes B0 wins from R wins.

---

## 8. Workstream A: Cache-Key And Setup

Accepted source:

- `fold_path_hotpath_audit.md`
- `v0_1_8_7_data_subset_hash_review_request_response.md`

Binding scope:

- Hoist run-level timestamp normalization out of per-key loops.
- Replace JSON+SHA session-local feature cache keys with an unambiguous
  length-prefixed composite string if the implementation remains deterministic
  and collision-free at the string-encoding level.
- Do not use canonical JSON or cryptographic hashes for session-local lookup
  keys unless they are needed for durable identity.
- Do not change feature definition fingerprints, strategy/config identity
  hashes, snapshot hashes, or provenance bytes.

The feature cache is session-local. Its lookup key is not durable evidence.
Durable identity remains strong-hash / canonical JSON where the contracts
already require it.

Acceptance gates:

- Feature-cache behavior remains deterministic within a run/session.
- Persisted feature identity and feature-definition fingerprint tests remain
  green.
- The precompute/setup timing records the effect of the cache-key change.
- No durable hash bytes change.

---

## 9. Workstream C: Reconstruction And Read-Back

Accepted source:

- `spike-reconstruction-collapse.md`
- `collapse_optimization_map.md`
- `rfc_optimization_round_v0_1_8_7_synthesis.md`

Binding scope:

- Rewrite `ledgr_fills_from_events()` away from per-row `data.frame()` plus
  `do.call(rbind, rows)`.
- Prefer preallocated columns and `.subset2`/primitive column access.
- `collapse::rowbind` and grouped operations such as `fcumsum(x, g)` are
  permitted only behind the collapse determinism gate below.
- This is a read-back/reconstruction cleanup, not a primary run-wall speed
  claim.

Required parity fixtures cover real ledgr event semantics:

- CASHFLOW-before-fill ordering;
- opening positions;
- partial close/open;
- close-before-open split rows;
- invalid/missing rows;
- DB-backed and memory-backed event tables;
- event order and `event_seq`;
- output column order and classes;
- FIFO lot-state progression.

Acceptance gates:

- `ledgr_results(..., "fills")` parity against current behavior.
- Sweep summary parity where reconstruction paths share helpers.
- Hostile `collapse` settings cannot change value-bearing outputs.

---

## 10. Collapse Determinism Gate

`collapse` is allowed because the measured hot paths justify it and ADR 0004
accepts the dependency. Its use is still gated.

Value-neutral operations:

- `collapse::setv()` used only as an in-place write into preallocated event
  buffers is value-neutral.
- It requires event-stream parity, but not floating-point value parity.

Value-bearing operations:

- `fcumsum`, `fmean`, `fsd`, `rowbind` over value-bearing rows, grouped
  aggregations, and any other operation that can alter numeric, ordering, or
  class output must run inside `ledgr_with_collapse_deterministic()`.

The deterministic wrapper pins and restores at least:

- `nthreads = 1L`;
- `na.rm = FALSE`;
- `sort = TRUE`;
- `stable.algo = TRUE`.

Other `set_collapse()` fields exposed on the host (`remove`, `digits`, `stub`,
`verbose`, `mask`) must either be pinned or documented as irrelevant for each
used operation.

Acceptance gates:

- The wrapper restores caller settings on normal exit and error exit.
- Hostile-setting fixtures mutate at least `nthreads`, `na.rm`, `sort`, and
  `stable.algo`.
- Value-bearing outputs remain byte-identical under hostile caller settings.

---

## 11. Run-Artifact Materialization Policy

v0.1.8.7 formalizes the fast/slow split that v0.1.8.6 profiling exposed.

Fast/evaluation path:

- `ledgr_sweep()` and evaluation-style runs avoid durable heavy artifacts by
  default.
- They save compact results and the reproduction key needed to materialize
  heavy artifacts later.
- The reproduction key includes snapshot identity, selector, strategy/config
  identity, feature definitions/fingerprints, engine version, seed/RNG metadata
  where applicable, and candidate parameters.

Slow/promotion/inspection path:

- Promotion or explicit inspection materializes durable ledgers, equity,
  feature panels, or read-back views and pays that tax intentionally.
- Materialized artifacts must be reproducible from the stored key.

Acceptance gates:

- A sweep/evaluation result can be promoted or materialized without requiring
  the user to reconstruct the original experiment by hand.
- Ephemeral result vs promoted/materialized result parity is byte-identical for
  the reported metrics and event/equity surfaces covered by the promotion.
- The docs do not imply heavy durable feature/event panels are free or always
  produced by the fast path.

---

## 12. Benchmark And Measurement Policy

Measurements are part of every batch, not only the release gate. Each batch must
close with empirical evidence appropriate to its scope:

- contract/legacy batches close with targeted failure/parity tests and grep or
  schema evidence;
- dependency batches close with dependency/import/package-load evidence;
- optimization batches close with current-source before/after timing or a
  maintainer-recorded reason the prior current-source baseline is still valid;
- artifact-policy batches close with parity plus timing or artifact-size
  evidence for fast vs materialized paths;
- the release gate closes with a full benchmark/attribution summary.

No optimization ticket should close on code inspection alone.

Required benchmark discipline:

- Use current source only, with installed-package mismatch guards.
- Report wall time, phase timings where available, security-bars/sec,
  feature-cells/sec where applicable, events/sec for turnover paths, dimensions,
  event counts, and environment metadata.
- Keep LEAN/Ziplime/vendor rows caveated as orientation unless locally matched.
- Treat same-host Backtrader/quantstrat rows as comparable only for the stated
  shape and timing boundary.
- Do not claim sweep crossover until multi-candidate same-host measurements
  show it.

Required remeasurements:

- baseline before first implementation ticket if the branch has moved
  materially;
- after B0;
- after R/A;
- after C if read-back surfaces change;
- after run-artifact policy if fast/materialized path behavior changes;
- final release gate: matched peer benchmark and attribution summary.

The attribution should compare measured changes to the synthesis bounds, not as
promises but as a sanity check:

- B0 high-turnover wall: about 1.7x-1.9x if the production re-profile confirms
  removal of buffer/write-fill work;
- R turnover wall: about 1.05x-1.15x unless post-B0 profiling attributes more
  wall time to representation;
- R low-turnover / wide shapes: potentially larger, but measured separately;
- C read-back: report as result-materialization/read-back improvement, not as a
  primary run-wall claim.

The release note should report what improved and what remains, not just a
headline ratio.

---

## 13. Deferred Work

The following remain deferred:

- ledgr-authored compiled core (C/Rcpp/Rust/native);
- parallel/multicore sweep dispatch;
- matrix-canonical public strategy surface;
- sweep-amortization / peer-crossover claims beyond measured rows;
- durable identity format redesign for snapshot/config/provenance hashes;
- target risk;
- walk-forward evaluation;
- public cost/liquidity APIs;
- OMS and paper/live adapters;
- point-in-time regressors and external reference-data surfaces;
- public hosted benchmark dashboard.

The matrix-canonical strategy surface is especially important but separate. It
is a contract/ergonomics RFC, not a speed lane for this packet unless a narrow
support ticket explicitly pulls part of it in.

---

## 14. Proposed Ticket Cut

Ticket identifiers are assigned in `v0_1_8_7_tickets.md` and `tickets.yml`.
The intended ticket areas are below. `batch_plan.md` should group them into
review batches after the spec is accepted.

1. **LDG-2458 - Spec and planning alignment.** Keep README, roadmap, AGENTS,
   horizon, and the active packet aligned with the v0.1.8.7 scope.
2. **LDG-2459 - Legacy execution cleanup.** Require sealed snapshot-backed
   configs before fold entry, remove/fail raw `bars` execution, remove modern
   run-time `data_hash` identity, and update docs/tests/schema surfaces.
3. **LDG-2460 - ADR 0004 dependency/interface cleanup.** Drop `cli`, drop `R6`,
   migrate built-in/reference strategies to functions, add `collapse`, and
   retain `tibble`.
4. **LDG-2461 - Collapse deterministic wrapper.** Add the wrapper and
   hostile-setting fixtures before any value-bearing collapse adoption.
5. **LDG-2462 - B0 event buffer/emission.** Right-size/grow event buffers,
   optionally use `setv`, preserve event surfaces, and re-profile.
6. **LDG-2463 - R/A representation and setup cleanup.** Remove addressable
   timestamp/string and session-key hot-path waste while keeping durable
   identity bytes fenced.
7. **LDG-2464 - C reconstruction/read-back cleanup.** Rewrite fill/equity
   reconstruction hot spots behind real-ledgr parity fixtures.
8. **LDG-2465 - Run-artifact materialization policy.** Make fast/evaluation
   paths ephemeral for heavy artifacts and materialization
   explicit/reproducible.
9. **LDG-2466 - Post-lane benchmark and attribution.** Re-run the matched
   benchmarks and update the release attribution.
10. **LDG-2467 - Release gate.** Full targeted parity checks, full local tests,
    package checks as appropriate, documentation consistency, and cycle
    retrospective.

Ticket cutting should keep B0, R/A, and C separated so measured wins are not
double-counted.
