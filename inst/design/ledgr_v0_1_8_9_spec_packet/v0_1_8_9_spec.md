# ledgr v0.1.8.9 Spec

**Status:** Implementation packet approved for Batch 1 after Batch 0 ticket-cut
review closeout.
**Target Branch:** `v0.1.8.9`.
**Scope:** Single-core optimization round driven by the v0.1.8.9 spike
synthesis: remove measured pure-R implementation debt in durable and
ephemeral fold/output paths, consolidate JSON handling onto yyjsonr while
ledgr is pre-CRAN, and re-measure the workload grid and peer benchmark after
the fixes land.
**Non-scope for this pass:** target risk, walk-forward evaluation, public cost
or OMS APIs, compiled fold core / `ledgrcore`, public benchmark marketing,
new public ephemeral execution API, memory-handler `meta_json` structural
refactor, event-schema redesign beyond the explicit canonical JSON byte-format
version bump, and any implementation ticket not cut from this spec after peer
review.

---

## 0. Source Inputs

Authoritative inputs:

- `inst/design/contracts.md`
- `inst/design/README.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/horizon.md`
- `inst/design/rfc_cycle.md`
- `inst/design/collapse_optimization_map.md`
- `inst/design/adr/0004-dependency-footprint-and-strategy-interface.md`

Optimization-round inputs:

- `inst/design/spikes/ledgr_v0_1_8_9_optimization_round_spike/architecture_synthesis.md`
- `inst/design/spikes/ledgr_v0_1_8_9_optimization_round_spike/README.md`
- `dev/bench/notes/single_core_optimization_inventory.md`
- `dev/bench/notes/per_pulse_complexity_findings.md`
- `dev/bench/notes/workload_grid_baseline_closeout.md`
- `dev/bench/peer_benchmark/notes/backtrader_scale_check.md`
- `dev/bench/peer_benchmark/notes/three_phase_decomposition_design.md`
- `dev/bench/peer_benchmark/notes/three_phase_decomposition_results.md`
- `inst/design/ledgr_v0_1_8_8_spec_packet/peer_benchmark_parity_closeout.md`
- `inst/design/ledgr_v0_1_8_8_spec_packet/parallel_sweep_measurement_closeout.md`

Spike logs feeding this packet:

- `dev/spikes/spike-position-valuation-vectorize.md`
- `dev/spikes/spike-target-delta-vectorize.md`
- `dev/spikes/spike-state-positions-representation.md`
- `dev/spikes/spike-batch-fill-writes.md`
- `dev/spikes/spike-next-bar-extraction.md`
- `dev/spikes/spike-memory-output-handler-growth.md`
- `dev/spikes/spike-fills-reconstruction-scaling.md`
- `dev/spikes/spike-event-stream-reconstruction.md`
- `dev/spikes/spike-fills-extract-xlarge-breakdown.md`
- `dev/spikes/spike-duckdb-equity-roundtrip.md`
- `dev/spikes/spike-persistent-handler-buffer.md`
- `dev/spikes/spike-chunked-extractor-wall-recovery.md`
- `dev/spikes/spike-yyjsonr-readpath-parity.md`
- `dev/spikes/spike-yyjsonr-write-byte-identity.md`

The spike synthesis is the source of scope. The pre-RFC spike-ticket markdown
is evidence, not implementation scope. Implementation tickets are cut in
`v0_1_8_9_tickets.md` and `tickets.yml`. `LDG-2495` records the completed
ticket-cut review; implementation lanes remain pending until their batches
start.

---

## 1. Thesis

v0.1.8.8 made the remaining performance problem measurable. The v0.1.8.9 spike
round showed that the problem is not the event-sourced architecture. It is
implementation debt in a small number of pure-R hot paths:

1. per-row writes into scale-growing column buffers through base-R replacement;
2. per-pulse R-interpreted loops over all instruments;
3. per-fill row extraction through data-frame subsetting;
4. historical JSON-library and canonical JSON byte-format choices.

The highest-leverage lanes are mechanical:

- replace scale-growing per-row column-buffer writes with `collapse::setv`;
- keep chunking and `setv` together in fills extraction;
- vectorize the two per-pulse instrument loops;
- consolidate ledgr JSON handling onto yyjsonr while ledgr is pre-CRAN;
- preserve event-stream parity and re-measure on the workload grid after each
  substantive lane.

The release should make ledgr materially faster on the
`density_high_xlarge_durable` stress cell without adding a second execution
engine, weakening snapshot/event contracts, or claiming public performance
leadership. The target is current-source engineering improvement with
measured before/after evidence.

---

## 2. Release Goals

v0.1.8.9 has eight release goals:

1. Land the column-buffer coding rule: any per-row write into a scale-growing
   preallocated column buffer uses `collapse::setv`, not base-R `[[<-`.
2. Remove the measured O(N^2) output-handler buffer costs in the persistent
   durable handler and the memory output handler, with separate durable and
   ephemeral measurement gates.
3. Remove the measured O(N^2) fills-reconstruction buffer cost in the chunked
   extractor path used by `ledgr_results(bt, "fills")`.
4. Remove the measured O(n_inst) interpreted per-pulse loop cost in position
   valuation and target-delta handling.
5. Consolidate JSON handling from jsonlite to yyjsonr, explicitly versioning
   the canonical JSON byte format and updating contracts, tests, dependency
   metadata, and release notes.
6. Correct parity-gate attribution language from "DuckDB float round-trip" to
   the measured "Kahan compensated summation vs naive cumsum" mechanism.
7. Re-run the ledgr-only workload grid and repo-local peer benchmark after the
   optimization lanes land, using the existing same-host, current-source,
   non-public-claim framing.
8. Preserve the v0.1.8.8 run/sweep, parallel, resume, snapshot, and
   deterministic-event contracts throughout.

The release succeeds when the high-density xlarge durable cell improves
materially, event-stream parity is preserved, JSON identity changes are
intentional and documented, and the before/after measurement record is
discoverable for future v0.2.x compiled-core decisions.

---

## 3. Workstream A: Column-Buffer Write Rule

### 3.1 Binding Rule

Any per-row write into a scale-growing preallocated column buffer must use:

```r
collapse::setv(buffer$column, i, value, vind1 = TRUE)
```

instead of:

```r
buffer$column[[i]] <- value
```

or nested equivalents such as:

```r
state$pending_cols$column[[i]] <- value
```

The rule applies where the buffer grows with fill count, event count, history
length, or extraction row count. It does not apply to small fixed-size state
vectors where Spike 3 showed `setv` does not materially improve the current
path and may complicate snapshot semantics.

### 3.2 Rationale

The v0.1.8.9 spike round confirmed the same copy/materialization trap at four
sites:

- v0.1.8.7 event buffer rewrite precedent;
- memory output handler in `R/sweep.R`;
- fills reconstruction buffer in `R/fold-reconstruction.R`;
- persistent durable handler pending-column buffer in `R/backtest-runner.R`.

The outer container shape is not the important property. The hot-path failure
is the repeated base-R complex replacement into a vector reached through a
list/env chain. `collapse::setv` writes by reference into atomic vectors and is
value-neutral for these column stores.

### 3.3 Determinism Boundary

`collapse::setv` is not a reduction and does not reorder floating-point
operations. It does not require `ledgr_with_collapse_deterministic()`.

If a later implementation uses value-bearing collapse primitives such as
`fsum`, `fcumsum`, grouped reductions, or order-sensitive cumulative
operations, the deterministic wrapper remains mandatory.

---

## 4. Workstream B: Output Handler Buffers

This workstream has two path-specific lanes. Both are instances of the same
column-buffer write rule, but they live in different handlers and must be
ticketed and measured separately.

### 4.1 Durable Output Handler Buffer

Spike 11 replaces the earlier Spike 4 default-durable interpretation. Spike 4
measured live-mode per-row DBI inserts; default durable runs already batch
through the persistent output handler. The measured default-durable problem is
the per-row base-R writes into `state$pending_cols`.

Required work:

- replace pending-column writes in the persistent durable handler with
  `collapse::setv`;
- preserve the existing buffered flush behavior and `DBI::dbAppendTable`
  semantics;
- preserve event ordering, event sequence continuity, timestamp values, and
  metadata bytes;
- add parity tests against representative event rows across all affected
  columns;
- re-run at least the high-density large and xlarge durable grid cells.

Acceptance gates:

- byte-identical ledger events for representative durable runs before and
  after the change;
- no change to public `ledgr_run()` output semantics;
- no regression in final-bar no-fill warning behavior;
- high-density xlarge durable grid shows the expected durable-handler recovery
  direction, with the exact wall recovery recorded rather than assumed.

### 4.2 Memory Output Handler Buffer

Spike 6 confirmed the same per-row column-buffer write anti-pattern in the
memory output handler used by ephemeral sweep/candidate execution. This is a
real v0.1.8.9 lane if ephemeral performance remains in scope. It is distinct
from the later `meta` list-column to `meta_json` refactor, which remains
deferred.

Required work:

- replace atomic-column writes in the memory output handler with
  `collapse::setv`;
- replace the same per-row inline fill-buffer writes in
  `ledgr_sweep_summary_from_ordered_events()` or explicitly measure and defer
  that site;
- preserve the current memory-handler event schema and `meta` list-column
  behavior;
- do not introduce a public ephemeral fast-path API;
- do not write durable artifacts from the memory path;
- keep sweep candidate results and warning/error association unchanged.

Acceptance gates:

- byte-identical in-memory event records for representative sweep candidates
  before and after the change;
- byte-identical sweep-summary fills for the inline fill-buffer path, if it is
  patched in this release;
- sequential and parallel sweep candidate parity unchanged;
- no durable writes from worker/candidate memory paths;
- high-density large and xlarge ephemeral grid cells record the measured
  before/after recovery for the memory-handler lane;
- any remaining `meta` list-column residual is documented as the deferred
  v0.1.8.10 `meta_json` polish lane, not silently folded into v0.1.8.9.

---

## 5. Workstream C: Fills Reconstruction And Chunked Extractor

Spike 12 validated that the fills-reconstruction lane applies to the real
durable chunked extractor path, not just to the monolithic in-memory
reconstruction spike.

Required work:

- replace the per-row writes in `ledgr_fill_row_buffer_add()` with
  `collapse::setv`;
- keep the chunked extractor architecture intact;
- verify the fix through the public `ledgr_results(bt, "fills")` path, not
  only by direct internal helper invocation;
- preserve fill classification, side, price, quantity, fee, realized PnL,
  event sequence, and timestamp values.

Acceptance gates:

- full-output fill parity on representative fixtures, not only first-row or
  first-100-row parity;
- xlarge fills extraction no longer requires the workload-grid row-count
  fallback;
- `ledgr_results(bt, "fills")` handles rows above `stream_threshold` with
  correct row counts and stable materialization;
- high-density xlarge durable grid records the measured before/after
  `fills_extract_sec` recovery.

---

## 6. Workstream D: Per-Pulse Vectorization

Spikes 1 and 2 confirmed measurable per-pulse R-interpreted loop costs that
scale with universe size.

Required work:

- vectorize position valuation using an alignment-safe ordering strategy;
- vectorize target-delta computation so the fold iterates over real deltas
  instead of all target names where possible;
- preserve named-vector strategy target semantics;
- preserve the rule that missing strategy targets are not silently treated as
  zero;
- keep the public strategy contract unchanged.

Acceptance gates:

- byte-identical fills and equity for deterministic SMA crossover fixtures;
- tests with intentionally shuffled target/instrument order prove alignment
  safety;
- unknown instrument and malformed target errors remain loud;
- high-density large and xlarge grid cells show flattened per-pulse scaling
  direction.

Ticket-cut note:

- split position valuation vectorization and target-delta vectorization into
  separate implementation tickets. They touch different fold-engine regions
  and should be measured/bisected independently even though they share one
  workstream in this spec.

Lower-priority follow-up:

- `state$positions` representation changes remain audit-gated. Spike 3
  recommended `intvec_id_map` as the semantic-preserving direction, but this is
  a smaller lane and should be sequenced after Spikes 1 and 2 unless the
  post-fix profile moves it up.

---

## 7. Workstream E: JSON Dependency Consolidation

v0.1.8.9 intentionally uses ledgr's pre-CRAN state to consolidate JSON handling
onto yyjsonr and drop jsonlite.

This is a versioned identity-format change, not a transparent refactor.

Required work:

- replace jsonlite read/write call sites across `R/` with yyjsonr equivalents;
- verify yyjsonr parity for both `simplifyVector = FALSE` metadata shapes
  covered by Spike 13 and `simplifyVector = TRUE` config/strategy/provenance
  shapes not covered by Spike 13;
- update `DESCRIPTION`: remove jsonlite from Imports and add
  `yyjsonr (>= 0.1.22)`;
- update `inst/design/contracts.md` to name yyjsonr as the canonical JSON
  serializer and document the exact write options;
- regenerate the hard-coded `config_hash()` literal in
  `tests/testthat/test-sweep-parity.R`;
- add or update tests that pin canonical JSON byte-format v2;
- update NEWS / release notes to state that pre-v0.1.8.9 hashes do not match
  v0.1.8.9 hashes;
- update NEWS / release notes to state that strategy provenance fingerprints
  can change because the package dependency list moves from jsonlite to
  yyjsonr;
- audit all jsonlite references with `rg "jsonlite|fromJSON|toJSON"`.

Expected yyjsonr canonical write options:

```r
yyjsonr::opts_write_json(
  pretty = FALSE,
  auto_unbox = TRUE,
  digits = -1L,
  null = "null",
  num_specials = "null"
)
```

Acceptance gates:

- canonical JSON fixtures are deterministic and byte-stable on the local host;
- a CI-visible canonical JSON byte-identity smoke test stores expected bytes
  for the Spike 14 fixture shapes and fails on any yyjsonr formatting drift;
- per-site read parity covers `simplifyVector = FALSE` and
  `simplifyVector = TRUE` equivalents, with the yyjsonr option set documented
  for each class;
- config hashes, snapshot hashes, strategy fingerprints, and reproduction keys
  change only where expected;
- no remaining jsonlite call site exists in production R code;
- contracts and tests agree on the canonical JSON byte-format version;
- release notes explicitly call out the format bump.

---

## 8. Workstream F: Smaller Cleanup And Robustness Lanes

These are scoped only if the main lanes land cleanly and post-fix profiles
still justify them.

### 8.1 Per-Fill Next-Bar Extraction

Spike 5 confirmed the data-frame row subset is mechanically slow but has small
wall recovery on the reference grid. It may be folded into the optimization
round if it naturally follows from matrix-canonical fill proposal work.

Guardrails:

- do not change next-open fill timing semantics;
- preserve final-bar no-fill discipline;
- keep fill proposal fields explicit enough for later cost-model work.

### 8.2 Fills Extraction Robustness

Spike 9 narrowed the xlarge row-count fallback to the stream-threshold path,
not DuckDB query correctness. The Workstream C implementation should remove
or narrow this symptom. If it persists after `ledgr_fill_row_buffer_add()` is
fixed, cut a focused robustness ticket against the lazy/materialization
boundary.

### 8.3 Parity Attribution Correction

Spike 10 showed that the durable-vs-ephemeral 1e-8 equity tolerance comes from
Kahan compensated summation vs naive cumsum, not DuckDB double round-trip.
Unlike the optional performance cleanup lanes above, this documentation fix is
a mandatory release-gate item because it is one of the release goals and has no
implementation-risk dependency on the post-main-lane profile.

Required documentation updates:

- peer benchmark closeout attribution language;
- relevant parity gate comments/tests;
- any future note that references the tolerance.

---

## 9. Deferred Scope

The following are intentionally out of v0.1.8.9 unless separately promoted by
maintainer decision after ticket cut:

- public ephemeral fast path;
- memory output handler `meta` list-column to `meta_json` character-column
  refactor;
- compiled fold core / `ledgrcore`;
- one replay kernel rewrite;
- target risk, affordability, or OMS policy;
- walk-forward evaluation;
- public transaction cost or liquidity API;
- paper/live order lifecycle;
- new event schema beyond canonical JSON byte-format v2;
- public benchmark claims or performance marketing;
- Ziplime, vectorbt, or any new peer benchmark engine;
- maintainer-manual skeleton work deferred from v0.1.8.8.

The memory handler `meta_json` refactor is recorded as an obvious v0.1.8.10
polish lane because L8 shows list columns bound the `setv` win. It is not a
v0.1.8.9 release goal.

---

## 10. Measurement Gates

Every implementation lane must be followed by targeted measurement before it
is treated as successful. v0.1.8.9 inherits the v0.1.8.7 measurement
discipline: adjacent hot-path lanes must be measured separately so one
compounded wall-time number cannot hide an under-delivering change.

Required measurements:

- targeted micro/fixture timing for the touched helper where the spike gave a
  direct baseline;
- `dev/bench/shared/run_benchmarks.R --preset smoke` after any fold/output
  change that affects benchmark harness execution;
- high-density large and xlarge durable grid cells after each durable lane
  (fills extractor, persistent handler, position valuation, target delta,
  yyjsonr migration where measurable);
- high-density large and xlarge ephemeral grid cells after each shared or
  memory-path lane (fills extractor, memory output handler, yyjsonr migration
  where measurable);
- the repo-local peer benchmark after the main durable lanes land and again at
  round closeout;
- per-lane before/after attribution table entries before the next lane starts.

Adjacent lanes that target related hot paths, such as fills extraction and the
persistent handler, must land in separate commits or clearly separated review
units with intervening measurement. A bundled commit that changes two
headline hot paths is not acceptable unless the maintainer explicitly waives
attribution for a documented reason.

Within-run share is the load-bearing claim per lane:

- `t_loop_sec / t_wall_sec` for engine hot paths;
- `fills_extract_sec / t_wall_sec` for fills reconstruction;
- handler-specific event-write share where available;
- canonical JSON call share where measurable.

Wall-to-wall deltas remain useful sanity checks, but CPU power-state and local
host drift make them direction-only unless supported by within-run shares.

Required metrics:

- `t_wall_sec`;
- `t_loop_sec` where available;
- `fills_extract_sec`;
- `equity_extract_sec`;
- `ledger_extract_sec`;
- fill count;
- `mus_per_fill_engine`;
- `mus_per_fill_extract`;
- warning and failure counts;
- parity status.

Measurement language must remain local-host, current-source, and
machine-specific. No public speed ranking or hosted benchmark claim is allowed
from this release.

### 10.1 Per-Lane Attribution Table

The closeout must include a per-lane attribution table with at least:

| Lane | Spike | Pre-lane baseline | Post-lane result | Delta | Within-run share delta | Parity |
| --- | --- | --- | --- | --- | --- | --- |
| Fills extractor `setv` | 12 | pre-lane large/xlarge durable | post-lane | measured | `fills_extract_sec` share | full fill parity |
| Persistent handler `setv` | 11 | post-fills-extractor | post-lane | measured | handler / `t_loop_sec` share | event-stream parity |
| Memory handler `setv` | 6 | pre-lane large/xlarge ephemeral | post-lane | measured | memory event-write share | sweep parity |
| Position valuation vectorize | 1 | post-handler | post-lane | measured | engine share | event/equity parity |
| Target-delta vectorize | 2 | post-position-valuation | post-lane | measured | engine share | event/equity parity |
| yyjsonr migration | 13+14 | post-fold lanes | post-lane | measured | JSON call share where available | canonical v2 hash gate |

Each row should be filled before the next lane starts. The final closeout
aggregates these rows; it must not reconstruct lane attribution only from the
end-of-round wall delta.

### 10.2 Round Closeout Benchmark Suite

v0.1.8.9 must produce a release closeout artifact:

`inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md`

The closeout compares v0.1.8.9 headline figures against the v0.1.8.8
baseline on the same host and same workload definitions.

Baseline sources:

- LDG-2479 workload-grid record cited by the optimization inventory
  (`density_high_xlarge_durable` baseline: 445.02s wall,
  413.47s loop);
- LDG-2476 peer benchmark / three-phase peer closeout for ledgr vs
  Backtrader comparison framing.

Closeout run:

- re-run the full LDG-2479 workload grid on post-v0.1.8.9 source;
- re-run the LDG-2476 peer benchmark on post-v0.1.8.9 source;
- preserve the same scenario definitions and same local-host,
  current-source caveat language;
- compare v0.1.8.8 vs v0.1.8.9 for wall time, within-run shares,
  per-fill engine cost, per-fill extraction cost, parity status, and warning
  / failure counts.

Required headline rows:

- `density_high_xlarge_durable`;
- `density_high_large_durable`;
- `density_high_xlarge_ephemeral`;
- low-density cells as regression checks for small/low-turnover workloads;
- peer benchmark ledgr vs Backtrader ratio at the xlarge shape.

The closeout is a release-gate artifact, not optional documentation.

---

## 11. Verification Gates

Release-ticket work must include targeted tests for:

- byte-identical ledger event streams for output-handler changes;
- full fill-table parity for reconstruction changes;
- deterministic equity/cash/positions parity within the existing tolerance
  where Kahan-vs-cumsum accumulation order is the named mechanism;
- ordered target alignment under shuffled instrument names;
- malformed and missing targets still fail loudly;
- unknown instrument targets still fail loudly;
- final-bar no-fill warnings still surface;
- run/sweep fold-core parity unchanged;
- sequential and parallel sweep behavior unchanged by optimization work;
- resume behavior unchanged;
- canonical JSON byte-format v2 fixtures;
- regenerated config hash literal with explicit history comment;
- no production jsonlite call sites remain after JSON consolidation;
- contracts, DESCRIPTION, NEWS, and tests all agree on yyjsonr;
- high-density xlarge grid no longer requires the fills row-count fallback
  after the extractor fix, or documents a narrowed residual robustness issue.
- each headline lane has its own before/after attribution table entry before
  the next lane starts;
- no implementation ticket bundles two headline hot-path fixes unless the
  maintainer explicitly waives per-lane attribution in writing.

Full package tests and package check remain release-gate requirements, but
ticket cut should prefer small targeted checks first.

---

## 12. Settled Spec-Cut Decisions

These decisions are bound for ticket cut unless peer review blocks the packet:

| # | Decision | Bound answer |
| --- | --- | --- |
| 1 | Architecture diagnosis | Scale regression is implementation debt, not a second-engine or compiled-core blocker. |
| 2 | Lead durable lanes | Spike 12 fills extractor `setv`, then Spike 11 persistent durable handler `setv`. |
| 3 | Per-row buffer rule | Scale-growing column-buffer writes use `collapse::setv`; small fixed vectors are exempt unless re-profiled. |
| 4 | Chunking and `setv` | They are complementary and both remain in the design. |
| 5 | JSON library | Drop jsonlite and consolidate on yyjsonr because ledgr is pre-CRAN. |
| 6 | Canonical JSON | v0.1.8.9 introduces canonical JSON byte-format v2 and documents hash invalidation. |
| 7 | Ephemeral path | Optimize shared reconstruction paths and the memory output handler, but do not create a public ephemeral fast path in this release. |
| 8 | `meta` list column | Convert-memory-handler `meta` to `meta_json` is v0.1.8.10 polish, not v0.1.8.9 scope. |
| 9 | Compiled core | Defer until after v0.1.8.9 re-measures the residual gap. |
| 10 | Public benchmark claim | No public speed claim; only repo-local current-source evidence. |

---

## 13. Proposed Sequencing For Ticket Cut

This is implementation sequencing guidance only. It is not a ticket list.

1. **Packet and source hygiene.** Finalize this spec, update design index,
   verify stale spike-log recommendations have correction headers, and get
   peer review approval.
2. **Fills extractor `setv` -> measure -> attribute.** Land the shared
   reconstruction hot-path fix first because it has the largest measured
   durable recovery and affects both durable and ephemeral paths. Record its
   per-lane attribution row before moving on.
3. **Persistent durable handler `setv` -> measure -> attribute.** Land the
   durable output-handler buffer fix, preserving current flush semantics.
4. **Memory output handler `setv` -> measure -> attribute.** Land this only
   as an internal ephemeral-path optimization; preserve memory-handler schema
   and keep the `meta_json` structural refactor deferred.
5. **Position valuation vectorization -> measure -> attribute.** Land the
   Spike 1 fold-engine change with alignment tests.
6. **Target-delta vectorization -> measure -> attribute.** Land the Spike 2
   fold-engine change as a separate ticket/change from position valuation.
7. **yyjsonr migration -> measure -> attribute.** Drop jsonlite, add yyjsonr,
   version canonical JSON byte format, update contracts/tests/NEWS, and record
   the identity-format bump separately from fold hot-path wins.
8. **Optional cleanup -> measure -> attribute.** Land next-bar matrix lookup
   and/or narrowed fills extraction robustness only if the post-main-lane
   profile still supports it.
9. **Round closeout benchmark suite.** Aggregate the per-lane attribution
   table, re-run the full workload grid and peer benchmark, write
   `v0_1_8_9_release_closeout.md`, and update horizon with residual v0.2.x /
   v0.1.8.10 targets.
10. **Release gate.** Full tests, package check, release notes, tag
    preparation.

Ticket cut should split these into reviewable batches with one measurement
gate per batch. Do not combine all hot-path changes into one commit.

---

## 14. Future Obligations Recorded

Later work, not authorized here:

- `ledgrcore` compiled fold core and compiled canonical JSON encoder/decoder;
- public ephemeral execution API;
- memory output handler `meta_json` column refactor;
- target-risk affordability chain;
- walk-forward evaluation;
- public transaction-cost and liquidity API;
- OMS lifecycle / order-events stream;
- paper/live adapters;
- promotion-grade sweep artifact persistence;
- public performance dashboard;
- full maintainer manual article tree.

The v0.1.8.9 closeout should explicitly decide whether the residual
Backtrader/ledgr xlarge gap is small enough to keep optimizing in R, or large
enough to start the `ledgrcore` v0.2.x design thread.
