# ledgr v0.2.0.1 Tickets

Version: v0.2.0.1
Date: 2026-09-16
Total Tickets: 17

## Ticket Organization

v0.2.0.1 productionizes the three reviewed availability hot-path
representations, corrects the quadratic seal-time conflict validators, repairs
resumed-run equity finalization, and closes with separated cold, warm, and peer
benchmark records. The maintainer accepted the spec on 2026-09-16 after the
first independent review, the focused re-review, and the in-place N1 patch.

Ticket IDs begin at LDG-2719 after the v0.2.0.0 packet.

The release spine follows the spec's Section 6 stages:

```text
LDG-2719 packet alignment (stage A)
  -> LDG-2720..2721 witnesses and test-only references (stage B)
  -> LDG-2722..2723 prepared provider and consumers (stage C)
  -> LDG-2724 diagnostic writer and per-pulse block (stage D)
  -> LDG-2725..2726 production parity record, then retirement (C/D closure)
  -> LDG-2727 resumed-run equity-prefix merge (stage E)
  -> LDG-2728..2730 seal validators and complete-set bypass (stage F)
  -> LDG-2731..2732 benchmark phases and manuals (stage G)
  -> LDG-2733..2735 closeout records and release gate (stage H)
```

Ticket dependencies are the hard readiness gate. Batch order is the default
review sequence. Stages E and F are independent of the warm seams and may run
beside Batches 2 to 4; Stage G follows the production and correctness stages
and Stage H follows Stage G, and the hard edges below enforce that order.
Every batch keeps its own independent review stop and no benchmark number can
unlock a failed correctness stage.

## Priority Levels

- P0: release-blocking correctness, parity, identity, persistence, or gate work.
- P1: required benchmark, documentation, or maintainability work.
- P2: optional polish that may defer without changing the release contract.

## Dependency DAG

```text
2719 -> {2720, 2721}
{2720, 2721} -> 2722 -> 2723
{2720, 2721} -> 2724
{2723, 2724} -> 2725 -> 2726
2720 -> 2727
2721 -> 2728 -> {2729, 2730}
{2726, 2727, 2729, 2730} -> 2731 -> 2732
{2726, 2727, 2729, 2730, 2732} -> 2733
{2726, 2727, 2731, 2732} -> 2734
{2719..2734} -> 2735
```

## Gate Ownership

| Spec gate | Owning tickets |
| --- | --- |
| 3.1 production switch, oracle retirement, no hidden fallback | LDG-2721, LDG-2725, LDG-2726 |
| 3.2 prepared provider shapes, tie and default rules, consumers | LDG-2722, LDG-2723 |
| 3.3 writer capacity, block construction, error row outside the block path | LDG-2724 |
| 3.4 resumed-run equity-prefix merge | LDG-2727 |
| 3.5 membership and lifetime sweeps | LDG-2728 |
| 3.5 status supersession-exact hybrid | LDG-2729 |
| 3.5 complete-set setwise validation and bypass | LDG-2730 |
| 3.6 dependency and telemetry posture (collapse 2.1.7 and 2.1.8, no floor; unchanged telemetry names; no new schema column, hash input, public telemetry API, or durable lane name) | LDG-2724, LDG-2735 |
| 3.7 benchmark clocks and peer workload | LDG-2731, LDG-2734 |
| 4.1 provider-only views | LDG-2720, LDG-2722 |
| 4.1 fold scenarios | LDG-2720, LDG-2723, LDG-2724 |
| 4.1 full 757-pulse fold | LDG-2725 |
| 4.1 writer | LDG-2724 |
| 4.1 rollback and resume | LDG-2724 |
| 4.1 mechanism and source guard | LDG-2726 |
| 4.2 seal-validator matrix | LDG-2728, LDG-2729, LDG-2730 |
| 4.3 finalization matrix | LDG-2727 |
| 4.4 identity and compatibility matrix | LDG-2723, LDG-2724, LDG-2726, LDG-2735 |
| 7.1 availability warm record | LDG-2725 (pre-retirement pair), LDG-2733 (stage H) |
| 7.2 cold seal record | LDG-2733 |
| 7.3 peer record | LDG-2734 |
| 7.4 permitted release claims | LDG-2732, LDG-2734, LDG-2735 |
| 8 documentation and governance closeout | LDG-2732 (manuals and methodology), LDG-2734 (peer README and tracked report after the record), LDG-2735 |
| 9 release gates 1-10 | LDG-2735 (gate 2 evidence from LDG-2726; gate 6 from LDG-2724 and LDG-2735; gate 7 from LDG-2733 and LDG-2734) |
| Re-review N1 (status default keyed on row presence) | LDG-2719 (spec patch), LDG-2720 (test) |

## LDG-2719 - Packet Alignment And Ticket Cut

Priority: P0
Effort: M
Dependencies: None
Status: Review Pending

### Description

Accept the reviewed v0.2.0.1 spec, apply the re-review's N1 patch, create the
synchronized execution artifacts, and promote the packet into active
governance without claiming implementation.

### Tasks

- Record the maintainer's acceptance of the spec on 2026-09-16 after the first
  review (`REVISE_SPEC_FIRST`, all findings closed) and the focused re-review
  (`READY_TO_CUT_TICKETS`).
- Patch Section 3.2 so the status default is keyed on row presence, and add
  the declared-but-empty status family to the Section 4.1 provider-only tests.
- Allocate LDG-2719 through LDG-2735 and bind the dependency DAG.
- Create the packet README, Markdown tickets, YAML tickets, and batch plan.
- Record the ticket-cut baseline: `f0b847d02c2cf66a9871fdda119f55e0ccfd7e42`,
  package `0.2.0.1`, R 4.5.2 ucrt on `x86_64-w64-mingw32`, duckdb 1.4.3,
  testthat 3.3.1, collapse 2.1.7 default and 2.1.8 isolated.
- Align design index, roadmap, horizon, AGENTS, NEWS, and the
  documentation-contract assertions.
- Make no runtime, public-API, schema, or test-result change.

### Acceptance Criteria

- Every spec section, Section 4 matrix row, Section 9 release gate, and the
  N1 patch has a ticket owner.
- Markdown and YAML IDs, statuses, dependencies, and batch mappings agree.
- Active governance points to v0.2.0.1 and v0.2.0.0 is historical.
- No implementation or gate is claimed complete.

### Verification

- Manual spec-to-ticket coverage review
- Ticket ID and dependency DAG validation
- YAML parse and cross-artifact consistency
- `tests/testthat/test-documentation-contracts.R`

### Source Reference

- Spec Sections 0, 6, 9, 10; re-review N1

### Classification

```yaml
type: planning
surface: design-packet
scope: packet-alignment
```

## LDG-2720 - Port Spike Witnesses Into Durable Tests

Priority: P0
Effort: L
Dependencies: LDG-2719
Status: Pending

### Description

Turn the reviewed spike scenarios into durable package tests with frozen
expected rows so every later stage is measured against the same evidence.

### Tasks

- Port the eight diagnostic-block scenarios (direct at 7-row and 4,096-row
  chunks, interrupt and resume, injected rollback, classed nonmember-increase
  rollback, resume then exception, early terminal exit, interrupt and resume
  with early exit) and the missing-bar semantic fixture as testthat fixtures.
- Freeze expected diagnostics, events, equity, strategy state, completion, and
  normalized run-identity rows from the reviewed evidence, in git, with the
  reviewer named in the commit message.
- Port the provider-only parity coverage: changing complete and partial lists,
  interval assertions, status precedence, supersession, lifetime and terminal
  events, backward re-seek, repeated and shuffled cutoffs, and a declared status
  family with zero persisted rows.
- Add the `ledgr_facts_resolve()` agreement test over the membership cutoffs
  the provider spike compared.
- Run the ported tests against the baseline seams under both arms.

### Acceptance Criteria

- Each ported test fails against a deliberately perturbed expected value.
- The ported tests pass against the baseline under both spike arms.
- The identity comparison excludes exactly `created_at_utc`,
  `config_json.db_path`, and `config_json.data.snapshot_db_path`.

### Verification

- New `test-availability-*.R` scenario and provider-parity files
- Perturbation check on frozen rows
- Existing `test-availability-*.R` net

### Source Reference

- Spec Sections 0.2, 3.1, 4.1; re-review N1

### Classification

```yaml
type: test
surface: availability-regression
scope: spike-witness-port
```

## LDG-2721 - Retain Test-Only References And Baseline Checker Run

Priority: P0
Effort: M
Dependencies: LDG-2719
Status: Pending

### Description

Preserve the reference logic the packet needs after retirement where installed
package execution cannot source it, and record the baseline checker results.

### Tasks

- Relocate copies of the pairwise membership, status, and lifetime validators
  into test helpers as the retained equivalence references.
- Keep the current provider builder, its resolvers, and the row-list and
  scalar diagnostic writers available to tests only until LDG-2726 retires
  them from `R/`; record where each reference lives.
- Run the writer, provider, and diagnostic-block checkers against the baseline
  and record their results and evidence prefixes in the packet.
- Draft the source-guard symbol list (options, arm stamps, retired functions,
  row-list bind) that LDG-2726 activates.

### Acceptance Criteria

- No retained reference is reachable from installed package code.
- All three checkers pass against the baseline with their recorded counts.
- The guard list names every retired symbol and every retained public helper.

### Verification

- Spike checkers against baseline
- Helper-location review

### Source Reference

- Spec Sections 0.2, 3.1, 4.1, 6 stage B

### Classification

```yaml
type: test
surface: availability-regression
scope: reference-retention
```

## LDG-2722 - Production Prepared Provider Compile And Queries

Priority: P0
Effort: L
Dependencies: LDG-2720, LDG-2721
Status: Pending

### Description

Make the prepared provider the production build with exactly the two measured
membership shapes, the CSR family planes, and the stated tie and default rules.

### Tasks

- Keep complete and partial set headers in processing order
  `(effective_from, knowledge_time, set_id)` with a separate eligibility order
  over `max(effective_from, knowledge_time)` driving one advance-and-re-seek
  cursor; the last eligible complete header in processing order resets state
  and every later eligible header contributes; all eligible partial headers
  contribute when no complete header is eligible.
- Keep interval assertions as flat start, end, member, and instrument-index
  vectors in `(effective_from, knowledge_time, fact_id)` order with
  last-applicable-wins override.
- Compile status, lifetime, and terminal events into per-instrument CSR
  segment tables with monotone advance and vectorised backward re-seek; resolve
  each segment at compile time with supersession removal, top precedence,
  `conflicting` on tied distinct statuses, and lifetime last-applicable order
  `(effective_from, knowledge_time, original read order)`.
- Key the status default on row presence: `active` with no persisted rows,
  `unknown` with rows but none applicable.
- Own cursor state per provider instance; never share it across runs or
  sweep candidates.
- Preserve fixed-universe configured order, stable-ID membership order, held
  former members after members, inclusive start and exclusive `effective_to`,
  and query-order independence.
- Rename or split the file for bounded ownership without a second pipeline.

### Acceptance Criteria

- The Section 4.1 provider-only durable tests pass.
- The provider checker's 3,676-cutoff parity and 602-cutoff public agreement
  pass against the production candidate.
- No CSR membership representation or unmeasured cursor design is introduced.

### Verification

- Ported provider-parity tests (LDG-2720)
- Provider spike checker parity phase
- `test-availability-*.R`

### Source Reference

- Spec Sections 3.2, 4.1, 5; synthesis Section 4 item 2

### Classification

```yaml
type: feature
surface: availability-provider
scope: prepared-compile
```

## LDG-2723 - Provider-Build Consumers And Result/Reopen Parity

Priority: P0
Effort: M
Dependencies: LDG-2722
Status: Pending

### Description

Route every true provider-build consumer through the production build and
prove result and reopen parity before the old provider is retired.

### Tasks

- Fold decision and execution views build once per experiment.
- The `availability` result view builds once per public result call and reuses
  the build for every cutoff; `ledgr_run_explain()` consumes that view.
- `ledgr_run_open()` builds once when validating an `INCOMPLETE` availability
  run and uses the prepared provider's session calendar.
- Parallel workers build their provider through the production constructor
  without process options; verify with the optional mirai coverage when
  installed.
- Leave `ledgr_facts_resolve()` and `ledgr_facts_history()` on the direct
  public path; assert no provider consumer calls it.
- Add result/reopen parity tests across direct, resumed, and reopened runs.

### Acceptance Criteria

- Fold scenario parity holds for diagnostics, events, equity, strategy state,
  completion, and normalized identity.
- `availability` and `ledgr_run_explain()` results are identical whichever
  build serves the reopen.
- Independent review accepts the provider boundary before Batch 4.

### Verification

- Ported scenario tests
- Result/reopen parity tests
- Optional mirai availability-parity test
- Independent review stop

### Source Reference

- Spec Sections 3.2, 4.1, 4.4, 5, 6 stage C

### Classification

```yaml
type: feature
surface: availability-provider
scope: consumer-routing
```

## LDG-2724 - Production Diagnostic Writer And Per-Pulse Block

Priority: P0
Effort: L
Dependencies: LDG-2720, LDG-2721
Status: Pending

### Description

Make the typed column writer and the per-pulse diagnostic block the production
diagnostic path with the chartered chunk, rollback, resume, and dependency
behavior.

### Tasks

- Give the writer a production capacity of 4,096 rows through an unexported
  constructor whose internal test-only capacity argument ordinary fold calls
  omit; forbid any option, public argument, config field, or identity input.
- Construct at most one ordinary diagnostic block per pulse from primitive
  vectors in emission order and append it in one operation; use
  `collapse::setv()` only on numeric, integer, and POSIXct columns and base
  block replacement on character columns.
- Flush full chunks without `do.call(rbind, ...)`; release a chunk only after
  its append succeeds; preserve committed prefixes across interruption and
  resume; roll back and keep the single post-rollback error row constructed
  outside the block-writer path.
- Add tests at 7-row and 4,096-row chunks, multi-chunk flush, injected append
  failure, fold failure, deliberate interrupt and resume, and resume then
  error.
- Run the parity suite under collapse 2.1.7 and 2.1.8.

### Acceptance Criteria

- Byte-exact deterministic fixture, case, and diagnostic files reproduce.
- Every rollback and resume case leaves the committed prefix plus exactly one
  error row with a continuous sequence and no partial active block.
- Outputs are identical under both collapse versions with no floor change.
- Independent review accepts the writer boundary before Batch 4.

### Verification

- Chunk, rollback, and resume tests
- Diagnostic-block checker deterministic phases
- Dual collapse-version run
- Independent review stop

### Source Reference

- Spec Sections 3.3, 3.6, 4.1, 4.4, 6 stage D

### Classification

```yaml
type: feature
surface: availability-diagnostics
scope: writer-and-block
```

## LDG-2725 - Pre-Retirement Production Parity And Paired Warm Record

Priority: P0
Effort: M
Dependencies: LDG-2723, LDG-2724
Status: Pending

### Description

Prove the production candidate against the old paths on the full 757-pulse
fixture and record the only same-session relative comparison the packet will
have.

### Tasks

- Run the final two-arm checkers against the production candidate.
- Compare all six persisted tables of one shared-run-ID pair by DuckDB multiset
  difference with exactly the three registered exclusions.
- Run one quiet-host session: one warm-up and at least three measured runs per
  arm; record medians, `diff(range())` spreads, and externally sampled peaks.
- Record the evidence prefix; the production candidate must beat the reference
  median by more than the reference's run-to-run spread.

### Acceptance Criteria

- Every persisted table is identical between arms.
- The relative-spread criterion holds and is recorded by prefix.
- No public performance claim is made.

### Verification

- Diagnostic-block and provider checkers
- `fold_757_parity`-style DuckDB comparison
- Paired measurement record

### Source Reference

- Spec Sections 3.1, 4.1, 7.1

### Classification

```yaml
type: parity
surface: availability-fold
scope: production-parity-record
```

## LDG-2726 - Retire Old Paths And Activate The Source Guard

Priority: P0
Effort: M
Dependencies: LDG-2725
Status: Pending

### Description

Remove the old runtime paths and the spike selection machinery from installed
code while keeping the public inspection engine intact.

### Tasks

- Remove `ledgr.internal.spike_diagnostic_writer`,
  `ledgr.internal.spike_diagnostic_chunk_rows`,
  `ledgr.internal.spike_diagnostic_block`, and
  `ledgr.internal.spike_availability_provider`.
- Remove `spike_arm` and every arm-observation field from runtime objects.
- Remove the row-list writer, scalar per-row diagnostic construction,
  `ledgr_availability_provider_build_current()`, its per-pulse view assembly,
  `ledgr_availability_members_at()`, and the status, lifetime, and
  terminal-event resolvers that lose their last caller.
- Keep `ledgr_membership_resolve_at()`, `ledgr_membership_evidence()`, and
  their helpers as the unchanged public inspection engine.
- Activate the source-guard test from LDG-2721 and prove no provider consumer
  calls the retained public path.

### Acceptance Criteria

- Installed code contains no spike option, arm stamp, row-list bind, retired
  builder, view assembly, or unused family resolver.
- `ledgr_facts_resolve()` and `ledgr_facts_history()` behave unchanged.
- The full availability regression net passes.

### Verification

- Source-guard test
- Public inspection tests
- `test-availability-*.R`

### Source Reference

- Spec Sections 3.1, 4.1 mechanism row, 9 gate 2

### Classification

```yaml
type: cleanup
surface: availability-runtime
scope: old-path-retirement
```

## LDG-2727 - Resumed-Run Equity-Prefix Merge

Priority: P0
Effort: M
Dependencies: LDG-2720
Status: Pending

### Description

Repair finalization so interrupted-then-resumed availability-aware runs keep
their complete achieved equity prefix and reopen under the strict validator.

### Tasks

- Apply the merge only when finalization uses fold-supplied equity facts and
  the current invocation does not cover the complete achieved prefix.
- Read the committed prior rows, combine on `(run_id, ts_utc)`, require
  calendar membership, collapse identical duplicates, and fail closed on
  conflicting duplicates, missing, extra, or non-monotone pulses before
  terminal status changes.
- Require the merged rows to equal the exact calendar prefix through
  `achieved_end_utc`; keep deletion, append, and status in one transaction.
- Keep the full achieved-prefix validator; never weaken it.
- Keep dense runs on their full recomputation path.
- Add the Section 4.3 matrix, including the dense interrupted-then-resumed
  case and ordinary reopen after every valid terminal case.

### Acceptance Criteria

- Resumed `DONE` and `INCOMPLETE` availability runs reopen and extract results.
- Every invalid merge fails before terminal status changes and leaves the
  prior committed rows recoverable.
- No equity formula, event replay, completion schema, stop reason, or run
  identity changes.
- Independent correctness review accepts the repair.

### Verification

- Finalization matrix tests
- Reopen and result extraction tests
- Independent correctness review stop

### Source Reference

- Spec Sections 3.4, 4.3, 6 stage E; synthesis Section 10

### Classification

```yaml
type: correctness
surface: run-finalization
scope: equity-prefix-merge
```

## LDG-2728 - Validator Equivalence Harness And Membership/Lifetime Sweeps

Priority: P0
Effort: L
Dependencies: LDG-2721
Status: Pending

### Description

Build the equivalence harness against the retained pairwise references and
replace the membership and lifetime pairwise validators with grouped
state-aware sweeps.

### Tasks

- Generate at least 2,000 deterministic randomized row sets plus the explicit
  Section 4.2 adversarial cases, shuffled input order included.
- Implement the membership sweep grouped by `(instrument_id, universe_id)` with
  a running maximum end per state, and the lifetime sweep grouped by
  `instrument_id` with a running maximum per assertion value.
- Preserve half-open intervals, touching endpoints, nested and equal
  intervals, open ends, condition classes, and messages.
- Switch both construction and seal call sites.

### Acceptance Criteria

- Sweep and pairwise references agree on every random and adversarial set.
- Existing fact and seal tests pass unchanged.

### Verification

- Equivalence harness
- `test-availability-facts.R` and seal tests

### Source Reference

- Spec Sections 3.5, 4.2, 6 stage F

### Classification

```yaml
type: correctness
surface: availability-facts
scope: membership-lifetime-sweeps
```

## LDG-2729 - Status Supersession-Exact Hybrid Validator

Priority: P0
Effort: M
Dependencies: LDG-2728
Status: Pending

### Description

Replace the status pairwise validator with the hybrid that keeps the direct
supersession exemption pairwise-exact.

### Tasks

- Group by `(instrument_id, source, precedence)`; classify every row that
  names a direct predecessor or is named as one as involved.
- Validate uninvolved rows with the per-status running-maximum sweep.
- Compare every unordered pair containing an involved row under the current
  predicate, exempting only a pair in which one row directly names the other.
- Add the X/Y/J false-positive guard and the Y/Z false-negative guard to the
  adversarial cases.
- Leave the supersession-reference and acyclicity checks unchanged.

### Acceptance Criteria

- The hybrid equals the retained pairwise reference on every row set.
- Both mixed shapes produce the expected outcome.

### Verification

- Equivalence harness with status cases
- `test-availability-facts.R`

### Source Reference

- Spec Sections 3.5, 4.2; re-review H2 closure

### Classification

```yaml
type: correctness
surface: availability-facts
scope: status-hybrid-sweep
```

## LDG-2730 - Complete-Set Setwise Validation And Sweep Bypass

Priority: P0
Effort: M
Dependencies: LDG-2728
Status: Pending

### Description

Let set-backed membership rows bypass the opposing-state sweep only after a
setwise validation proves they cannot conflict.

### Tasks

- Prove every persisted set row has `member = TRUE`, references a valid header
  in its universe, satisfies header and row scope, set identity, interval, and
  snapshot invariants, and that no interval-assertion family is mixed into the
  bypass.
- Route any malformed set row to failure or into the general validator.
- Add mutation tests for each invariant independently and in combination.
- Add a structural check that production seal and construction paths no
  longer call the pairwise validators; the registered full-scale seal is
  measured once, in LDG-2733.

### Acceptance Criteria

- No malformed set row is silently exempted.
- Targeted seal fixtures pass and the structural check proves the pairwise
  validators are absent from production execution.
- Independent review accepts Batch 6 before closeout records.

### Verification

- Setwise mutation tests
- Targeted seal fixtures and the structural pairwise-absence check
- Independent review stop

### Source Reference

- Spec Sections 3.5, 4.2

### Classification

```yaml
type: correctness
surface: snapshot-seal
scope: setwise-bypass
```

## LDG-2731 - Peer Benchmark Phase Split

Priority: P1
Effort: M
Dependencies: LDG-2726, LDG-2727, LDG-2729, LDG-2730
Status: Pending

### Description

Split the peer harness's ingestion phase so cold and warm clocks can be
reported per engine without changing the standard workload.

### Tasks

- Split ingestion into `snapshot_prepare_sec` and `experiment_setup_sec` beside
  `engine_sec` and `results_sec`; define the boundary per engine and report
  unavailable fields rather than estimates.
- Report `cold_end_to_end` and `warm_research_iteration` and reconcile phase
  totals with the full row wall.
- Place provider construction in warm experiment setup and reusable ingest or
  bundle construction in cold snapshot preparation.
- Leave the `record` preset defaults unchanged; the release command pins every
  parameter explicitly.
- Run the smoke preset.

### Acceptance Criteria

- Every engine row carries the four phase fields or explicit unavailability.
- Phase totals reconcile with the full row wall.

### Verification

- Peer benchmark smoke run
- Phase reconciliation check

### Source Reference

- Spec Sections 3.7, 7.3; benchmark methodology manual

### Classification

```yaml
type: benchmark
surface: peer-benchmark
scope: phase-split
```

## LDG-2732 - Manual And Report Updates

Priority: P1
Effort: M
Dependencies: LDG-2726, LDG-2727, LDG-2729, LDG-2730, LDG-2731
Status: Pending

### Description

Refresh the internal manuals and the tracked benchmark report after the
production source settles.

### Tasks

- Update `optimization_coding_style.qmd` and its rendering: completed block
  result in the evidence table, valuation as the next measured lane, the
  per-pulse block as the fold-side replacement for one-row frames, and every
  source anchor resolving to production code.
- Update `benchmark_methodology.qmd` and its rendering for the four peer phase
  fields and the final warm and cold interpretation.
- Keep the style article internal; preserve RFC and spike artifacts and their
  recorded clocks.
- Leave the record-specific peer README and tracked-report update to
  LDG-2734, which owns it once the record exists.

### Acceptance Criteria

- Rendered Markdown siblings reproduce.
- Every cited source anchor resolves.
- No forecast or peer ranking appears as a claim.
- No record prefix, environment, or parity status is asserted before the peer
  record exists.

### Verification

- Quarto renders
- Anchor resolution check
- `tests/testthat/test-documentation-contracts.R`

### Source Reference

- Spec Sections 7.4, 8

### Classification

```yaml
type: documentation
surface: maintainer-manuals
scope: post-productionization-refresh
```

## LDG-2733 - Availability Warm And Cold Closeout Records

Priority: P0
Effort: M
Dependencies: LDG-2726, LDG-2727, LDG-2729, LDG-2730, LDG-2732
Status: Pending

### Description

Record the stage H availability warm record and the cold seal record on the
registered fixture.

### Tasks

- Warm record: one warm-up and at least three quiet-host measured runs of the
  production path; median and spread of wall around the warm experiment and
  externally sampled peak working set; a host comparable to the reviewed block
  spike or the gate stays open.
- Cite the LDG-2725 pre-retirement pair by prefix as comparison context; do
  not restore the retired path.
- Cold record: the registered full seal once without the profiler, plus a
  separate profiled or sampled run only if attribution is needed; phase times
  and peak working set.
- Report fixture shape, source commit, versions, host metadata, warm-up count,
  repetitions, parity status, and the largest profiled lane.

### Acceptance Criteria

- Production median at most 60 seconds and every measured peak at most
  1,024 MiB on a comparable host.
- The seal completes with the pairwise validator absent; the 60-to-90-second
  estimate stays a forecast.
- Both records are cited by exact local prefix.

### Verification

- Availability warm record
- Cold seal record

### Source Reference

- Spec Sections 7.1, 7.2

### Classification

```yaml
type: benchmark
surface: availability-closeout
scope: warm-and-cold-records
```

## LDG-2734 - Peer Benchmark Record

Priority: P1
Effort: M
Dependencies: LDG-2726, LDG-2727, LDG-2731, LDG-2732
Status: Pending

### Description

Run the explicit standard peer workload after the package code, phase split,
and manuals are final, record it without a ranking claim, and carry the record
into the peer README and tracked report.

### Tasks

- Run `--preset record --release v0.2.0.1 --engine-set all --n-inst 500
  --n-days 1260 --fast 5 --slow 10 --seed 20260530`.
- Record status and environment per engine; reconcile phase totals with the
  full row wall; compare canonical equity, fills, and trades to durable ledgr
  before interpreting timing; classify the first divergence where full parity
  is impossible; keep unavailable peers unavailable.
- Update the peer README and tracked report with all five required fields: the
  exact closeout command, the exact record prefix, the environment, the parity
  status, and explicit non-ranking language.
- Cite the exact record prefix in the release closeout; keep raw records
  local.

### Acceptance Criteria

- Required rows are present or explicitly `UNAVAILABLE` with reasons.
- Parity precedes timing interpretation.
- The peer README and tracked report carry the five required fields for this
  record and no ranking language.
- No hosted LEAN service.

### Verification

- Peer benchmark record run
- Parity and divergence review
- Peer README and tracked-report field check

### Source Reference

- Spec Sections 3.7, 7.3, 7.4, 8

### Classification

```yaml
type: benchmark
surface: peer-benchmark
scope: release-record
```

## LDG-2735 - v0.2.0.1 Release Gate

Priority: P0
Effort: L
Dependencies: LDG-2719, LDG-2720, LDG-2721, LDG-2722, LDG-2723, LDG-2724, LDG-2725, LDG-2726, LDG-2727, LDG-2728, LDG-2729, LDG-2730, LDG-2731, LDG-2732, LDG-2733, LDG-2734
Status: Pending

### Description

Follow the release playbook, prove the ten Section 9 gates, and close the
packet without conflating local, branch, main, and tag evidence.

### Tasks

- Read `inst/design/release_ci_playbook.md` before execution.
- Run the complete suite, source build, and
  `R CMD check --no-manual --no-build-vignettes`.
- Run the relevant suite under collapse 2.1.7 and 2.1.8 without changing the
  dependency floor.
- Confirm schemas, identity formats, and v0.2.0.0 fixture reopen are unchanged.
- Confirm persisted and public telemetry names are unchanged and that no
  schema column, hash input, public telemetry API, or durable lane name was
  added for this cycle.
- Confirm every Section 4 matrix is represented by durable tests or a named
  closeout artifact and every correctness or parity stop was independently
  reviewed.
- Render documentation, confirm anchors resolve, and remove generated
  artifacts, temporary stores, `Rplots.pdf`, tarballs, and check directories.
- Update NEWS, version surfaces, AGENTS, design index, roadmap, and horizon
  to their release state; write the release closeout citing the three record
  prefixes.

### Acceptance Criteria

- Release gates 1 through 10 hold; no benchmark number waives gates 1 to 6.
- Telemetry names are unchanged and none of the four prohibited additions
  exists.
- Ticket Markdown, YAML, batch plan, spec, indexes, and closeout agree.
- Branch is ready for remote branch CI; main and tag CI remain later evidence.

### Verification

- Release CI playbook
- Full local suite, build, and check
- Dual collapse-version suite
- Telemetry-name and prohibited-addition check
- Documentation renders and anchor check
- Git status and generated-artifact review

### Source Reference

- Spec Sections 8, 9

### Classification

```yaml
type: release
surface: release-gate
scope: v0.2.0.1-closeout
```
