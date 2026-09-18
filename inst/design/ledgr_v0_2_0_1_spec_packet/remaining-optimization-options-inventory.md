# Remaining Optimization Options Inventory

Status: non-binding maintainer decision aid. This file does not amend the
accepted v0.2.0.1 specification, cut tickets, or authorize implementation.

Date: 2026-09-18

## 1. Purpose And Boundary

This inventory collects the optimization options found during the current
availability, sealing, complexity-audit, and Batch 10 benchmark work that are
not already part of v0.2.0.1.

It answers two separate questions:

1. Is the change small enough in semantics and proof burden to enter the
   current release through a focused specification amendment?
2. If not, does it need a full RFC cycle, or only a later bounded spike and
   specification packet?

The inventory covers named and evidenced options. The discovery estimate in
`dev/spikes/snapshot-sealing/loop_audit.md` is not treated as a reconstructive
census and does not turn every loop it lists into a candidate ticket.

Times below come from different fixtures and clocks. They are orientation,
not additive forecasts. In particular, warm experiment time, cold snapshot
time, strict-import time, result reconstruction time, and profiler inclusive
time must not be summed.

## 2. Decision Rules

### 2.1 Blast radius

- **BR0 - local:** one private operation or representation; no public input,
  persisted identity, accounting, or error-contract change.
- **BR1 - workflow:** several private operations or one public workflow, but
  no intended API, schema, identity, or accounting change.
- **BR2 - contract-sensitive:** ingestion acceptance, quarantine, recovery,
  accounting, persistence, worker transfer, or several public workflows are
  involved even if the requested output is nominally unchanged.
- **BR3 - product or identity:** public API, execution policy, snapshot or run
  identity, canonical accounting authority, cache semantics, or a separate
  product/repository is involved.

### 2.2 What qualifies as a cheap amendment

A change is cheap only if both its code and its proof are cheap. It must:

1. remove measured material work from an accepted release workflow;
2. preserve public API, accepted inputs, errors, schema, hashes, row order,
   accounting, and fail-closed behavior;
3. have a small, explicit semantic matrix rather than an inferred promise;
4. need no migration, compatibility policy, new cache, or worker protocol;
5. be independently reviewable and rerunnable before the release gate; and
6. leave enough time to repeat the affected record benchmark honestly.

A one-line edit at a trust or identity boundary is not a cheap change.

### 2.3 When an RFC is mandatory

Use the RFC cycle when a proposal changes or creates any of the following:

- a public execution or ingestion surface;
- a persisted hash or identity rule;
- the canonical accounting or reconstruction authority;
- cross-run caches and their invalidation or worker semantics;
- a default compiled path or supported execution mode;
- feature-authoring obligations or public error behavior; or
- a cross-repository benchmark product and its governance.

An internal algorithm with exact observable parity does not need an RFC merely
because it is difficult. It may still need a probe, Charter, and later spec.

## 3. Executive Disposition

The present evidence supports this boundary:

- **The dense-axis comparison should enter this release.** It removes measured
  work from the warm public workflow whose record must already be rerun after
  the benchmark-boundary correction.
- **The two availability timestamp changes form one conditional work item.**
  Session-close comparison and observation-time normalization share the same
  ingest boundary, fixture family, quarantine matrix, review, and cold-record
  rerun. Probe normalization first; if exact row-level classification cannot
  be preserved cheaply, defer it and consider the comparison alone.
- **Byte-identical hash timestamp deduplication deserves a bounded cost
  check.** It joins the amendment only if rule-version, chunk, memory, reopen,
  and tamper proof remains compact and every hash is unchanged.
- **Everything else should be deferred.** Some items need an RFC. The rest
  need a later bounded spike or compatibility matrix and are not cheap merely
  because their likely implementation is short.
- **Low-value cleanliness work should not extend this release.** The duplicate
  strategy preflight and one-row strategy-state frames are real, but their
  measured cost does not justify another late-cycle gate.
- **The exact-parity proof template is a release deliverable.** It records a
  reusable evidence shape and stop conditions, but does not itself authorize a
  fast governance lane. Process adoption remains a post-release governance
  decision.

This is a technical disposition, not maintainer acceptance. No item below is
in v0.2.0.1 until a reviewed amendment explicitly places it there.

## 4. Current-Cycle Amendment Candidates

### OPT-C01 - Compare dense-axis timestamps as instants

- **Evidence:** `setup-orchestration-optimization-note.md`.
- **Current work:** the dense static coverage validator formats about 630,000
  POSIXct values before comparing an already aligned, sealed-snapshot axis.
- **Measured orientation:** 13.94 seconds unprofiled at the registered shape;
  the numeric comparison prototype was about 0.0049 seconds.
- **Blast radius:** BR0 to BR1. The production change is local, but NA and
  sub-second behavior are defensive error-contract concerns.
- **RFC:** no.
- **Current-cycle disposition:** candidate for a focused amendment.
- **Required proof:** retain the explicit aligned-NA failure; prove exact
  equality, ordering, timezone, duplicate, missing, and sub-second cases; keep
  the dense rectangular-axis check; run the public canonical and compiled
  sweep records again.
- **Reason it is not automatic:** the current string comparison and numeric
  comparison diverge for sub-second values. The supported sealed path rejects
  such values, but direct/internal misuse must still fail closed rather than
  acquire a silent new acceptance rule.
- **Why it still qualifies:** the semantic proof and accepted-commit record
  rerun are bundled with work already required for the benchmark-boundary
  correction. The local edit alone would not make a trust-boundary change
  cheap.

### OPT-C02 - Compare session closes as normalized instants

- **Evidence:** `dev/spikes/snapshot-sealing/loop_audit.md` and the sealing
  probe findings.
- **Current work:** availability ingestion formats all observation and session
  close timestamps into strings before membership comparison.
- **Measured orientation:** about 9 seconds at the registered availability
  fixture.
- **Blast radius:** BR0 to BR1.
- **RFC:** no.
- **Current-cycle disposition:** candidate after a small reproducible probe.
- **Required proof:** numeric-instant comparison must agree with the retained
  token implementation over timezone aliases, missing values, duplicates,
  unsorted rows, invalid rows, whole-second boundaries, and sub-second input;
  the same rows must be accepted or quarantined; rerun the full cold
  availability record.
- **Reason it is plausible:** this changes comparison representation, not the
  session-close contract, and removes formatting already paid for upstream.

### OPT-C03 - Vectorize availability observation-time normalization

- **Evidence:** `dev/spikes/snapshot-sealing/loop_audit.md`.
- **Current work:** `ledgr_availability_observation_times()` calls the time
  normalizer through a rowwise loop and catches each error as a missing value
  for later quarantine.
- **Measured orientation:** about 17 seconds for 426,191 rows versus roughly
  0.02 seconds for the simple vectorized mechanism.
- **Blast radius:** BR1, with a trust-boundary caveat.
- **RFC:** no if row-level behavior is exactly preserved.
- **Current-cycle disposition:** borderline; do not put it in the amendment
  before a focused probe.
- **Admission rule:** the probe must cover every accepted timestamp form,
  missing and malformed values, mixed valid/invalid vectors, timezone and
  sub-second rules, and exact quarantine locators. If preserving row-level
  recovery needs a new parser or changes errors, defer it.
- **Reason for caution:** the apparent loop is also the mechanism that turns a
  bad individual value into evidence instead of aborting the whole vector.

### OPT-C04 - Reuse the first strategy preflight result

- **Evidence:** `setup-orchestration-optimization-note.md`.
- **Current work:** public sweep orchestration performs overlapping strategy
  preflight work twice.
- **Measured orientation:** about 0.09 seconds warm.
- **Blast radius:** BR0.
- **RFC:** no.
- **Current-cycle disposition:** do not amend. Preserve as later cleanup.
- **Reason:** the saving is real but immaterial beside the release record and
  does not justify another implementation and review surface.

### OPT-L01 - Deduplicate timestamp formatting inside snapshot hashing

- **Evidence:** `dev/bench/notes/durable_path_observations.md`.
- **Mechanism:** format unique timestamp values per production hash chunk and
  map them back, while preserving the exact byte stream.
- **Measured orientation:** 3.20 seconds to 0.410 seconds inside the shipped
  10,000-row chunk shape, about 7.8 times faster; the hash path is paid at seal
  and again at the run guard.
- **Blast radius:** BR1 because snapshot identity is touched even though the
  target bytes are unchanged.
- **RFC:** no, provided hashes remain byte-identical under every rule version.
- **Current-cycle disposition:** cost before deciding. Include it only if the
  rule-1/rule-2, chunk-boundary, memory, old-snapshot, reopen, and tamper proof
  is compact. Whole-column microbenchmarks overstate the gain.

## 5. Later Internal Optimizations That Do Not Need An RFC Yet

These items preserve the product contract in their currently stated form, but
their proof or implementation radius is too large for a cheap late amendment.
They belong in a later probe or specification packet.

### OPT-L02 - Optimize `from_df()` timestamp branches

- **Evidence:** `dev/bench/notes/durable_path_observations.md`.
- **Mechanism:** reuse validated ISO-Z strings, append the defined suffix for
  date-only and no-Z branches, and reserve scalar fallback for genuinely
  irregular input.
- **Measured orientation:** the current POSIXct formatting pass is about
  3.25 seconds at 630,000 rows; the vector branch is about 0.02 seconds.
- **Blast radius:** BR1 to BR2 because this is a public ingestion surface.
- **RFC:** no if the complete accepted-input and error matrix is unchanged.
- **Why later:** the date-only conversion is not an identity operation, the
  no-Z branch needs explicit coverage, and the three public ingestion surfaces
  must not be accidentally conflated.

### OPT-L03 - Optimize the strict CSV importer without merging contracts

- **Evidence:** `dev/bench/notes/durable_path_observations.md`.
- **Mechanisms:** numeric tuple duplicate detection; parse unique timestamp
  strings once; supply exact safe column classes where compatible.
- **Measured orientation:** duplicate detection about 3.38 to 0.02 seconds;
  timestamp parsing about 1.85 to 0.02 seconds; base CSV reading about 4.02 to
  0.67 seconds in the measured shape.
- **Blast radius:** BR1 to BR2.
- **RFC:** no for exact compatibility; yes if accepted inputs, inferred types,
  or error timing change.
- **Why later:** the strict importer is not reached by `from_csv()` or the
  current peer workflow. Reader substitutions such as DuckDB or `fread()` are
  product-contract choices, not interchangeable implementation details.

### OPT-L04 - Vectorize seal-time fact payload and provenance work

- **Evidence:** `dev/spikes/snapshot-sealing/loop_audit.md`.
- **Mechanism:** build typed payload columns in blocks, canonicalize unique
  repeated provenance once, and reuse family hashes within a seal invocation.
- **Measured orientation:** about 7 seconds for fact payload work and about
  1 second for provenance JSON in the registered availability shape.
- **Blast radius:** BR1 to BR2 because IDs and evidence hashes must remain
  byte-identical.
- **RFC:** no for transient, byte-identical reuse; yes if stored identity or
  cache authority changes.
- **Why later:** several call sites currently recompute the same evidence, and
  the proof must cover every fact family, order, missing value, and collision
  boundary rather than only the common fixture.

### OPT-L05 - Batch durable event payload construction

- **Evidence:** `dev/bench/notes/durable_path_observations.md`.
- **Mechanism:** compute repetitive timestamp, canonical JSON, event ID, and
  payload fields in typed blocks while retaining immediately consumed cash,
  position, and sequence values.
- **Measured orientation:** about 2.10 seconds, or 14.3 percent of the measured
  durable event phase at 27,668 events.
- **Blast radius:** BR1 to BR2.
- **RFC:** no if event rows and identities remain exact.
- **Why later:** a flush-only design is not established; some fields are read
  immediately by fold accounting. The split between immediate state and
  deferred serialization needs a bounded spike.

### OPT-L06 - Fuse feature payload conversion with matrix construction

- **Evidence:** `setup-orchestration-optimization-note.md`.
- **Mechanism:** avoid creating an intermediate data frame only to coerce it
  into the same dense matrix needed by the feature path.
- **Measured orientation:** roughly 0.5 seconds at the registered shape.
- **Blast radius:** BR0 to BR1.
- **RFC:** no.
- **Why later:** useful, but below the threshold for extending this release;
  exact dimnames, storage modes, missing values, and feature order still need
  parity tests.

### OPT-L07 - Remove redundant setup sorting, splitting, and view materializing

- **Evidence:** `setup-orchestration-optimization-note.md`.
- **Mechanism:** consume the sealed snapshot's established order and reuse one
  prepared index instead of sorting or splitting the same rows repeatedly.
- **Measured orientation:** individually below about 0.3 seconds in the
  registered setup profile.
- **Blast radius:** BR0 to BR1.
- **RFC:** no.
- **Why later:** combine only after an explicit sealed-snapshot guarantee
  ledger proves which order and uniqueness properties each consumer may rely
  on.

### OPT-L08 - Build `execution_view()` once per pulse

- **Evidence:** `dev/spikes/snapshot-sealing/loop_audit.md`.
- **Mechanism:** construct the execution view once and index targets from that
  prepared view instead of reconstructing it for each target.
- **Measured orientation:** mechanism identified, not yet isolated at the
  release shape.
- **Blast radius:** BR1.
- **RFC:** no if all target-level visibility and error behavior remain exact.
- **Why later:** needs an eventful fixture, target-order parity, zero-target
  and failure cases, and an actual attribution before becoming a ticket.

### OPT-L09 - Optimize scalar feature-window fallbacks internally

- **Evidence:** the complexity audit and loop audit.
- **Mechanism:** prepare feature inputs once, use indexed primitive windows,
  and avoid subsetting a data frame for every bar and feature. Cover both the
  ordinary fallback used when `series_fn` is absent and the strict-window
  scalar/parity path.
- **Complexity:** both current fallback shapes are approximately O(B * F * W);
  the internal target is O(B * F) where the feature contract permits it.
- **Blast radius:** BR2 because parity checks and author functions are
  involved.
- **RFC:** no for an internal exact implementation; see OPT-R05 for changing
  the authoring contract.
- **Why later:** needs a dedicated fixture family for warm-up, missing values,
  multi-output features, scalar/series parity, and failure localization.

### OPT-L10 - Share and index fallback result reconstruction

- **Evidence:** `results-path-and-benchmark-boundary-note.md`.
- **Mechanisms:** sort and type events once; share one replay between equity
  and fills; consume precomputed realized P&L and cost-basis attributes when
  valid; replace per-instrument vector scans with one `collapse::fmatch()` plus
  grouped indices.
- **Measured orientation:** the private reconstruction path was about 9.99
  seconds at 68,201 events; `fmatch()` plus grouping was 8 to 9 times faster
  than repeated `which()` in its isolated comparison.
- **Blast radius:** BR1 to BR2.
- **RFC:** no while production inline results remain authoritative, fills and
  trades stay exact, and equity remains within the already registered
  tolerance without widening it; see OPT-R04 for changing that authority.
- **Why later:** memory production already uses `inline_summary()`. This work
  primarily serves durable-sweep fallback, recovery, and reference paths, so
  it must be measured on a reachable public workflow before implementation.
  The proof must report the maximum equity residual caused by compensated
  production accumulation versus reconstruction rather than calling the two
  paths byte-identical.

### OPT-L11 - Use integer lot indices and incremental basis state

- **Evidence:** `results-path-and-benchmark-boundary-note.md` and the
  complexity audit.
- **Mechanisms:** map instruments once instead of named-list lookup per event;
  carry the known basis delta instead of re-summing every open lot.
- **Complexity:** removes an O(instruments) lookup and an O(lot depth) re-sum
  from each affected event; accumulating strategies can otherwise approach
  quadratic total work in lot depth.
- **Blast radius:** BR2 because this is accounting state.
- **RFC:** no if exact accounting and error behavior are retained.
- **Why later:** requires deep-lot, partial-close, fee, reversal, missing-cost,
  resume, and durable/memory parity fixtures. The registered crossover fixture
  keeps lot depth shallow and is not enough proof.

### OPT-L12 - Avoid repeated compiled FIFO pack and unpack work

- **Evidence:** the complexity audit and loop audit.
- **Mechanism:** retain indexed flat lot state between batches rather than
  packing every open lot into the compiled kernel and unpacking it again.
- **Complexity:** current packing can grow with both batch count and open lot
  depth.
- **Blast radius:** BR2.
- **RFC:** no for an unchanged opt-in kernel and exact state; yes if the
  compiled path becomes canonical or default.
- **Why later:** needs deep-lot and batch-boundary evidence, not the current
  shallow crossover workload.

### OPT-L13 - Remove discarded finalization reconstruction

- **Evidence:** the complexity audit and the availability RFC synthesis.
- **Mechanism:** when the fold has supplied complete equity facts, do not also
  replay event history to compute values that finalization discards.
- **Complexity:** current dense and availability finalization contain terms
  that grow with instruments, events, pulses, and lot depth.
- **Blast radius:** BR2 because completion, resume, and terminal evidence are
  involved.
- **RFC:** no for an exact internal specialization.
- **Why later:** the resumed-run prefix repair has just changed this boundary;
  optimize only after DONE, INCOMPLETE, resume, rollback, and reopen invariants
  are stable and independently tested.

### OPT-L14 - Batch terminal recovery and availability result views

- **Evidence:** the complexity audit and loop audit.
- **Mechanisms:** replace per-pulse state recovery queries and per-instrument,
  per-timestamp history queries with prepared ranges and set-wise reads.
- **Complexity:** observed shapes include O(P * E + N * P^2), O(P) database
  queries, and O(T * E + T * N * P).
- **Blast radius:** BR2.
- **RFC:** no for exact read-side reconstruction.
- **Why later:** recovery and historical inspection are correctness oracles.
  Each needs independent point-in-time, terminal-event, reopen, and missing
  evidence cases before changing query shape.

### OPT-L15 - Index fill-to-evidence reconciliation

- **Evidence:** the complexity audit.
- **Mechanism:** prepare decision and pulse keys once instead of scanning them
  for each fill.
- **Complexity:** current candidate is O(E * (D + P)); target is indexed linear
  assembly plus output size.
- **Blast radius:** BR1 to BR2.
- **RFC:** no.
- **Why later:** not isolated in the accepted record and tightly coupled to
  evidence ordering and failure diagnostics.

### OPT-L16 - Replace remaining one-row strategy-state frames with blocks

- **Evidence:** `dev/spikes/snapshot-sealing/loop_audit.md`.
- **Mechanism:** typed block accumulation followed by one boundary frame.
- **Measured orientation:** identified but small at 1,260 pulses.
- **Blast radius:** BR0.
- **RFC:** no.
- **Why later:** cleanliness and scaling resilience, not a current bottleneck.

### OPT-L17 - Audit the remaining Tier-2 reader and sweep clusters

- **Evidence:** `dev/spikes/snapshot-sealing/loop_audit.md`.
- **Candidates:** repeated config JSON parsing, sweep filtering and
  persistence, walk-forward one-row frames, and repeated per-pulse view
  materialization.
- **Blast radius:** unknown until attributed.
- **RFC:** undecided; depends on the chosen boundary.
- **Why later:** these are discovery leads, not measured optimization tickets.
  Apply the probe-before-prose rule separately to each reachable workflow.

## 6. Options That Require An RFC Cycle

### OPT-R01 - Change the snapshot hash payload or hash-rule version

- **Evidence:** `dev/bench/notes/durable_path_observations.md`.
- **Proposal:** replace textual canonical payload construction with a binary or
  raw-byte encoding.
- **Measured orientation:** about 7.283 seconds to 0.173 seconds in the
  reconstruction experiment.
- **Blast radius:** BR3.
- **Why RFC:** every snapshot hash changes. Encoding, endianness, missing
  values, strings, floats, version negotiation, old-snapshot verification,
  and cross-platform reproducibility become product identity decisions.
- **Disposition:** next version or later; do not amend v0.2.0.1.

### OPT-R02 - Add a public single-evaluation memory-backed run

- **Evidence:** `inst/design/horizon.md` and
  `results-path-and-benchmark-boundary-note.md`.
- **Proposal:** a public `ledgr_evaluate()`-style capability between committed
  `ledgr_run()` and multi-candidate `ledgr_sweep()`.
- **Blast radius:** BR3.
- **Why RFC:** creates a public workflow and requires decisions about identity,
  retention, metrics, failure evidence, interruption, and relation to the one
  execution core.
- **Disposition:** future RFC; current peer records must use public workflows
  that exist today.

### OPT-R03 - Persist prepared snapshot state across experiments

- **Evidence:** `setup-orchestration-optimization-note.md`.
- **Proposal:** cache matrices, instrument indices, provider state, or feature
  preparation across warm experiment calls on the same sealed snapshot.
- **Blast radius:** BR3.
- **Why RFC:** cache key, invalidation, memory ownership, process and worker
  transfer, snapshot tamper checks, lifecycle, and observability are all new
  product semantics.
- **Disposition:** future RFC after the no-cache public path is optimized.

### OPT-R04 - Make a compiled kernel canonical or expand compiled execution

- **Evidence:** the result-path note, complexity audit, and peer record.
- **Proposal:** route canonical fallback reconstruction or broader fold work
  through `ledgr_cpp_spot_fifo_batch()`, make compiled FIFO the default, or
  support availability-aware compiled experiments.
- **Blast radius:** BR3.
- **Why RFC:** changes the accounting authority, supported execution envelope,
  portability, fallback rules, dependency/toolchain burden, and equivalence
  standard.
- **Disposition:** future RFC. Internal packing improvements to the existing
  opt-in path remain OPT-L12.

### OPT-R05 - Change the strict feature-authoring contract

- **Evidence:** the complexity audit and feature-path manuals.
- **Proposal:** require a series function, remove scalar/series parity work, or
  otherwise change what feature authors must supply.
- **Blast radius:** BR3.
- **Why RFC:** changes public authoring and failure semantics.
- **Disposition:** future RFC. Exact internal strict-window acceleration
  remains possible under OPT-L09.

### OPT-R06 - Merge ingestion surfaces or adopt a different reader contract

- **Evidence:** `dev/bench/notes/durable_path_observations.md`.
- **Proposal:** make `from_csv()`, `from_df()`, and the strict bars importer
  share one acceptance/error contract, or adopt DuckDB/`fread()` parsing as
  observable product behavior.
- **Blast radius:** BR3.
- **Why RFC:** the surfaces currently have distinct reachable checks, inferred
  types, timestamp branches, and error timing. Faster reading alone does not
  authorize merging those contracts.
- **Disposition:** future RFC if unification is desired; exact local
  optimizations remain OPT-L02 and OPT-L03.

### OPT-R07 - Remove or weaken per-run snapshot hash verification

- **Evidence:** the durable-path observations.
- **Proposal:** trust an earlier seal or cached hash instead of recomputing the
  snapshot hash at the run guard.
- **Blast radius:** BR3.
- **Why RFC:** changes the tamper-detection and provenance guarantee.
- **Disposition:** do not pursue as an optimization. Optimize the
  byte-identical hash computation under OPT-L01 instead.

### OPT-R08 - Build the external Docker benchmark laboratory

- **Evidence:** `inst/design/horizon.md`.
- **Proposal:** a separate repository with pinned ledgr regression tasks and
  standardized peer containers.
- **Blast radius:** BR3, cross-repository governance.
- **Why RFC or equivalent design cycle:** workload ownership, licensed data,
  peer versioning, clocks, hardware normalization, CI budget, and publication
  rules must be designed together.
- **Disposition:** valuable future infrastructure, not v0.2.0.1 package work.

## 7. Measurement Corrections And Research Leads

These items should not be misreported as current package optimizations.

### OPT-M01 - Use the public CSV workflow in a future peer record

The current benchmark manually reads the fixture before calling `from_df()`.
Calling public `from_csv()` would make the end-to-end boundary more faithful,
but changes the phase definition. It is a benchmark-method correction and must
be declared and rerun, not booked as an engine speedup.

### OPT-M02 - Explain the built-in SMA versus canonical TTR gap

The Batch 10 record observes that the built-in SMA path is faster. No current
evidence attributes the difference to indicator arithmetic rather than payload
shape, adapter work, allocations, or orchestration. Keep the controlled study
in Horizon; do not cut an optimization ticket from the aggregate gap.

### OPT-M03 - Profile valuation only if a later workload makes it material

Prepared valuation is already part of v0.2.0.1 and reduced its former hot path.
The provider spike left valuation as a possible next lane, but the later writer
and provider results changed the profile. A new optimization requires a fresh,
eventful attribution rather than extrapolation from the old lane share.

## 8. Measured Non-Candidates And Rejected Shortcuts

The following observations should prevent repeated work:

- Replacing `paste()` with `sprintf()` was slower in the measured hash path.
- Deduplicating numeric columns did not improve snapshot hashing.
- `collapse::qF()` and `collapse::qG()` were slower than base
  `unique()` plus `match()` for timestamp deduplication in the measured hash
  shape.
- `collapse::timeid()` is unsuitable for content hashing: it failed on the
  measured prices and produces dataset-relative timestamp identifiers.
- Rewriting the already-cheap chronology check with collapse was slower.
- Removing numeric rounding saves only about 20 to 70 milliseconds beside the
  roughly 2,540-millisecond textual formatting step and is not material.
- Weakening timestamp comparisons changes semantics and is not an
  optimization.
- Moving an already materialized dense-axis aggregate into DuckDB does not
  remove the dominant formatting work and is not justified by the profile.
- Optimizing the old private ephemeral benchmark harness would improve a
  published number without improving the public product. That boundary has
  already been corrected to public `ledgr_sweep()`.
- The loop audit's approximate HIGH and MEDIUM counts are discovery evidence,
  not a backlog. Broad loop cleanup is not a release ticket.
- The 60-to-90-second post-validator seal estimate was a forecast, not a gate;
  the actual Batch 10 record supersedes it.

## 9. Already In v0.2.0.1 And Therefore Excluded

This inventory does not reopen work already implemented in the current packet:

- the prepared availability provider and cursor-based fact resolution;
- typed diagnostic blocks and the columnar diagnostic writer;
- grouped, pairwise-exact seal validators;
- linear memory and durable event buffers under collapse 2.1.8;
- prepared valuation with its structural complexity gate;
- availability-aware resumed-run equity-prefix repair;
- the corrected public-workflow peer benchmark boundary; and
- the existing canonical and compiled spot-FIFO peer rows.

Any defect in those implementations follows the current ticket correction
path. It is not a new optimization option.

## 10. Proposed Current-Cycle Boundary

The accepted technical boundary for one final amendment is:

1. Admit OPT-C01 after its NA and sub-second decisions and semantic matrix are
   written into the amendment.
2. Treat OPT-C02 and OPT-C03 as one availability-ingestion work item with one
   fixture family. Probe OPT-C03 first. If exact row-level quarantine cannot be
   preserved cheaply, defer it and consider OPT-C02 alone.
3. Cost OPT-L01 against its complete byte-identity and bounded-memory proof.
   Admit it only if that proof remains compact and every old/new hash matches.
4. Do not add OPT-C04, OPT-L02 through OPT-L17, or any OPT-R item.
5. Deliver and independently review the exact-parity internal-optimization
   proof template. The template is evidence infrastructure, not authority to
   bypass an RFC, specification, or maintainer scope decision.
6. Give every admitted optimization a structural regression test, semantic
   mutation or identity test, recorded before/after clock, and independent
   code review.
7. Land the public-workflow benchmark correction and bind the compensated
   production inline result as the memory equity reference: fills and trades
   exact, equity under the existing tolerance, and no tolerance widening.
8. Rerun the affected cold availability, durable, and warm peer records once,
   at the accepted commit, before Batch 11.

This bundles proof that shares fixtures and the already-required record rerun,
while excluding work that would create a second optimization RFC.

If either accepted candidate exposes a wider compatibility question, stop and
move it to the next version. The purpose of this inventory is to prevent a
late release from becoming an unreviewed second optimization RFC.

## 11. Evidence Sources

- `inst/design/ledgr_v0_2_0_1_spec_packet/`
  `setup-orchestration-optimization-note.md`
- `inst/design/ledgr_v0_2_0_1_spec_packet/`
  `results-path-and-benchmark-boundary-note.md`
- `dev/bench/notes/durable_path_observations.md`
- `dev/spikes/snapshot-sealing/loop_audit.md`
- `dev/spikes/snapshot-sealing/probe_findings.md`
- `dev/spikes/v0_2_0_1_hot_path_complexity_audit/`
  `complexity_inventory.csv`
- `inst/design/manual/optimization_coding_style.qmd`
- `inst/design/exact_parity_internal_optimization_proof_template.md`
- `inst/design/horizon.md`
- the accepted v0.2.0.1 specification, hot-path amendment, tickets, and batch
  plan
