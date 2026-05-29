# v0.1.8.7 Batch Plan

**Status:** Review batching plan for the v0.1.8.7 optimization and legacy
cleanup cycle.
**Scope:** Groups the v0.1.8.7 tickets into implementation/review batches.

v0.1.8.7 is a single-core, pure-R hot-path cleanup and legacy-removal release.
The review posture is stricter than a normal optimization cycle: the packet
removes raw `bars` execution, R6 strategy execution, and run-time `data_hash`
identity from modern execution before optimizing the fold. Reviewers should
focus on fail-loud legacy removal, event/equity/replay parity, deterministic
`collapse` usage, and honest measurement.

Global review standards:

- Modern execution is sealed-snapshot-backed and function-strategy-based.
- Raw `bars` execution, R6 strategy execution, and run-time `data_hash` identity
  must not remain load-bearing for modern execution.
- Selector identity must preserve existing inclusive boundaries:
  `ts_utc >= start_ts` and `ts_utc <= end_ts`.
- Durable hash/provenance bytes are fenced. Snapshot hashes, config/provenance
  canonical JSON, feature fingerprints, and strategy/config identity hashes do
  not change in this packet.
- `collapse` value-bearing operations must run inside the deterministic wrapper.
  Value-neutral `setv` writes still require event-stream parity.
- B0, R/A, and C wins must be measured separately to avoid double counting.
- Every batch closes with empirical evidence appropriate to the work: targeted
  tests/grep/schema checks for contract cleanup, dependency/import/package-load
  checks for dependency cleanup, and before/after current-source timing for
  optimization lanes.
- Measurements must run against current source, not an installed stale package.
- Same-host peer comparisons are scoped comparisons, not broad speed rankings.
- No compiled core, parallel dispatch, matrix-canonical public strategy surface,
  durable identity redesign, target risk, walk-forward, cost/liquidity, OMS, or
  public benchmark dashboard ships in this cycle.

---

## Batch 0: Scope And Packet Alignment

Tickets:

- `LDG-2458` Packet Alignment And v0.1.8.7 Planning State

Purpose:

Finalize the active packet and make the v0.1.8.7 scope unambiguous before
runtime or benchmark work starts. This batch prevents the cycle from becoming a
general performance, dependency, identity, or roadmap cleanup bucket.

Review focus:

- `v0_1_8_7_spec.md`, `v0_1_8_7_tickets.md`, `tickets.yml`, and this
  `batch_plan.md` agree.
- README, roadmap, horizon, and AGENTS point to v0.1.8.7 as the active packet.
- Legacy cleanup is explicitly scoped: raw `bars`, R6 strategy execution, and
  run-time `data_hash` identity are removed from modern execution.
- Non-scope remains deferred: compiled core, parallel dispatch, durable identity
  byte redesign, matrix-canonical public surface, target risk, walk-forward,
  cost/liquidity, OMS, and peer-crossover claims.
- Ticket dependencies form the intended DAG and do not allow value-bearing
  collapse work before the deterministic wrapper.
- Empirical closeout is the packet review itself: stale-scope `rg` checks and a
  diff review showing all active planning entry points agree.

---

## Batch 1: Legacy Execution Cleanup

Tickets:

- `LDG-2459` Legacy Execution Cleanup

Purpose:

Remove pre-snapshot execution gunk from the modern engine contract before
hot-path optimizations have to preserve obsolete invariants.

Review focus:

- All execution entries fail before fold entry unless they have a sealed
  snapshot-backed config.
- `ledgr_backtest()` may keep data-frame convenience only by converting the
  input into a sealed snapshot before execution.
- Raw mutable `bars` execution no longer reaches runtime views or fold state.
- Sealed snapshot-backed run/resume identity uses `config_hash`,
  `snapshot_id`, verified `snapshot_hash`, ordered `instrument_ids`, and
  inclusive `start_ts` / `end_ts` selector bounds.
- `ledgr_run_data_subset_hash()` is not recomputed as a modern sealed-run
  resume guard.
- `runs.data_hash`, `ledgr_data_hash()`, and snapshot-adapter `data_hash`
  metadata are deleted or marked archival/historical; none is consulted during
  modern execution, resume, replay, sweep, or promotion.
- Snapshot tampering is still caught by `snapshot_hash` verification.
- Docs and vignettes no longer teach `data_hash` as modern run data identity.
- Empirical closeout includes targeted raw-path failure, snapshot tamper, and
  resume tests.

---

## Batch 2: Dependency And Function-Strategy Cleanup

Tickets:

- `LDG-2460` ADR 0004 Dependency And Function-Strategy Cleanup

Purpose:

Implement ADR 0004's dependency and interface cleanup before the optimization
lanes depend on `collapse` or on a narrowed strategy contract.

Review focus:

- `cli` is removed from `DESCRIPTION`, `NAMESPACE`, roxygen/import declarations,
  and any stale generated docs.
- `R6` is removed from imports and from modern strategy execution.
- Built-in/reference strategies and strategy-key resolution are function-based.
- R6-specific replay/mutation semantics are removed.
- Direct run, sweep, and replay use the same function strategy contract.
- Static/function-strategy checks apply uniformly where retained.
- `tibble` result surfaces remain intact.
- `collapse` is added for scoped v0.1.8.7 hot-path use, not as a broad rewrite
  license.
- Empirical closeout includes dependency/import grep output and package-load or
  namespace checks proving `cli`/`R6` are gone and `collapse` is present.

---

## Batch 3: B0 Event Buffer And Emission

Tickets:

- `LDG-2462` B0 Event Buffer And Emission

Purpose:

Land the surface-preserving event-buffer/emission fix once legacy execution and
dependency cleanup are in place. This is the first measured hot-path lane.

Review focus:

- Event buffers no longer default to worst-case `n_inst * n_pulses`
  preallocation.
- Grow-by-doubling uses sensible defaults and a hard worst-case cap.
- Durable `handler$buffer_event` and sweep `append_event_row_list` preserve the
  same event surface.
- Optional `collapse::setv()` use is value-neutral and limited to in-place
  buffer writes.
- Event rows, event ordering, event ids, timestamps, `meta_json`, and DB/memory
  event surfaces are byte-identical.
- Deferred `meta_json` serialization, if used, remains per-row canonical JSON
  with `vapply(meta_list, canonical_json, character(1))`.
- A single JSON array for the metadata column is rejected.
- Real-run re-profile records the B0 effect and compares it to the expected
  high-turnover range.
- Empirical closeout includes a before/after or explicitly reused current-source
  baseline for the turnover shape.

---

## Batch 4: Collapse Deterministic Wrapper

Tickets:

- `LDG-2461` Collapse Deterministic Wrapper

Purpose:

Install the deterministic wrapper before any value-bearing `collapse` operation
ships. This batch is a determinism gate, not a performance change.

Review focus:

- The wrapper pins at least `nthreads = 1L`, `na.rm = FALSE`, `sort = TRUE`, and
  `stable.algo = TRUE`.
- Other host-exposed `set_collapse()` fields are pinned or explicitly shown
  irrelevant for the used operations.
- Caller settings are restored on normal exit and error exit.
- Hostile-setting fixtures mutate at least `nthreads`, `na.rm`, `sort`, and
  `stable.algo`.
- Value-bearing outputs are invariant under hostile caller settings.
- The wrapper exists before `fcumsum`, `rowbind`, grouped aggregations, metrics,
  or any other value-bearing collapse operation lands.
- Empirical closeout is hostile-setting and restore-on-error test output; no
  speedup is claimed for this gate.

---

## Batch 5: Representation And Setup Cleanup

Tickets:

- `LDG-2463` Representation And Setup Cleanup

Purpose:

Remove addressable timestamp/string and session-key setup waste while keeping
durable identity bytes fenced. This batch combines Lane R and Lane A because
both are boundary-representation cleanup and both must avoid durable identity
changes.

Review focus:

- Sub-second timestamp input is rejected at snapshot seal/ingest.
- Daily, minute, and second-resolution timestamp bytes remain equivalent across
  durable events, memory events, equity rows, replay, and reopen.
- Trusted whole-second POSIXct values are carried through hot paths without
  repeated normalize/format/parse round trips.
- Event-id strings remain byte-identical.
- `canonical_json()`, snapshot hashes, feature fingerprints, strategy/config
  identity hashes, and provenance bytes do not change.
- Run-level timestamp normalization is hoisted out of per-key cache loops.
- Session-local feature cache keys may move away from JSON+SHA only if the new
  encoding is unambiguous and deterministic.
- Feature-cache behavior remains deterministic within a run/session.
- Post-change re-profile distinguishes R/A effects from B0 effects.
- Empirical closeout includes before/after or post-B0 baseline comparison for
  setup/representation timing.

---

## Batch 6: Reconstruction And Read-Back Cleanup

Tickets:

- `LDG-2464` Reconstruction And Read-Back Cleanup

Purpose:

Rewrite read-back reconstruction hot spots behind real-ledgr parity fixtures.
This batch improves result materialization/read-back; it is not a primary
run-wall speed claim.

Review focus:

- `ledgr_fills_from_events()` no longer uses per-row `data.frame()` plus
  `do.call(rbind, rows)`.
- Primitive column access and preallocated columns are preferred.
- Value-bearing `collapse` operations run inside the deterministic wrapper.
- CASHFLOW-before-fill ordering is preserved.
- FIFO lot-state progression is preserved.
- Partial close/open and close-before-open split row ordering are preserved.
- Invalid/missing rows are handled as before.
- DB-backed and memory-backed event tables produce equivalent fills/results.
- Output column order, classes, event order, and `event_seq` are preserved.
- Read-back timing is reported as reconstruction/materialization timing, not as
  a primary run-wall claim.
- Empirical closeout includes read-back before/after timing.

---

## Batch 7: Run-Artifact Materialization Policy

Tickets:

- `LDG-2465` Run-Artifact Materialization Policy

Purpose:

Formalize the fast/slow artifact split. Evaluation and sweep paths should avoid
heavy durable artifacts by default, while retaining the compact reproduction key
needed to promote or materialize later.

Review focus:

- Fast/evaluation paths save compact results rather than durable heavy feature
  or event panels by default.
- The reproduction key is sufficient for later materialization: snapshot
  identity, selector, strategy/config identity, feature definitions or
  fingerprints, engine version, seed/RNG metadata where applicable, and
  candidate parameters.
- Promotion/materialization helpers let users explicitly pay the durable
  artifact cost later.
- Ephemeral result vs promoted/materialized result parity is proven for covered
  metrics and event/equity surfaces.
- Docs distinguish fast/evaluation paths from promotion/inspection paths and do
  not imply heavy artifacts are free or always produced.
- Empirical closeout includes parity plus timing or artifact-size evidence for
  fast/evaluation vs materialized paths.

---

## Batch 8: Post-Lane Benchmark And Attribution

Tickets:

- `LDG-2466` Post-Lane Benchmark And Attribution

Purpose:

Rerun benchmarks and attribution after the major lanes land. This batch records
what moved, compares measured changes against bounded expectations, and keeps
peer comparisons honest.

Review focus:

- Benchmarks run from current source with installed-package mismatch guards.
- Outputs are machine-readable where practical and include environment metadata.
- Results include wall time, phase timings where available, bars/sec,
  feature-cells/sec where applicable, events/sec, dimensions, and event counts.
- B0 measured effect is compared against the expected high-turnover range.
- R/A measured effect is reported separately from B0.
- C is reported as read-back/materialization improvement, not run-wall speed.
- Same-host Backtrader/quantstrat rows state timing-boundary differences.
- LEAN/Ziplime/vendor rows remain orientation-only unless locally matched.
- No sweep crossover or peer-superiority claim appears without supporting
  same-host multi-candidate measurements.
- Remaining large buckets are named and assigned ownership or accepted-overhead
  status.

---

## Batch 9: Release Gate

Tickets:

- `LDG-2467` v0.1.8.7 Release Gate And Closeout

Purpose:

Verify the shipped v0.1.8.7 work, close the packet, and record final
complete/defer outcomes for all scoped tickets.

Review focus:

- All ticket statuses are completed or explicitly deferred with maintainer
  rationale.
- `tickets.yml` and `v0_1_8_7_tickets.md` agree.
- No legacy raw `bars`, R6 strategy, or run-time `data_hash` path remains
  load-bearing for modern execution.
- Targeted parity tests cover snapshot, event-stream, timestamp, feature cache,
  reconstruction, sweep, and artifact materialization surfaces.
- Full tests and package checks required for the release gate pass or have
  maintainer-recorded disposition.
- Docs/vignettes do not contain stale legacy identity, R6, or raw-bars teaching.
- Benchmark and attribution results are recorded with peer-comparison caveats.
- NEWS/release notes describe shipped behavior only and do not claim peer
  superiority or public benchmark status.
- `cycle_retrospective.md` or equivalent closeout note records outcomes,
  carry-forward items, benchmark decisions, and any RFC-cycle deviations.

---

## Recommended Execution Order

```text
Batch 0
  -> Batch 1
      -> Batch 2
          |-- Batch 3
          |     -> Batch 5
          |           -> Batch 6
          |                 -> Batch 7
          |                       -> Batch 8
          |                             -> Batch 9
          |
          `-- Batch 4
                `-- Batch 6
```

Batch 0 is the planning gate. Batch 1 removes legacy execution constraints.
Batch 2 applies dependency and function-strategy cleanup, including dropping
`cli` and `R6`. Batch 3 can land before the deterministic wrapper because B0 is
value-neutral when it only changes buffer capacity/write mechanics. Batch 4 must
land before Batch 6 because reconstruction may use value-bearing collapse
operations. Batch 5 removes addressable representation/setup waste after B0 so
the measured effects stay separable. Batch 7 formalizes artifact materialization
after the core event/reconstruction surfaces are stable. Batch 8 measures the
whole packet, and Batch 9 closes it.
