# ledgr v0.2.0.1 Tickets

Version: v0.2.0.1
Date: 2026-09-18
Total Tickets: 26

## Ticket Organization

v0.2.0.1 productionizes the three reviewed availability hot-path
representations, corrects the quadratic seal-time conflict validators, repairs
resumed-run equity finalization, and closes with separated cold, warm, and peer
benchmark records. The maintainer accepted the spec on 2026-09-16 after the
first independent review, the focused re-review, and the in-place N1 patch.
On 2026-09-17 the maintainer accepted the reviewed hot-path complexity
amendment. It adds exactly two release-blocking corrections before closeout:
linear event-buffer writes and prepared fold-time availability valuation.
The amendment ticket cut was independently accepted. LDG-2736 through
LDG-2740 are Complete After Review.

On 2026-09-18 the maintainer accepted the reviewed trusted-timestamp and
benchmark-boundary amendment. Its required pre-cut probe selected `NEITHER`:
all ten semantic comparisons were exact, but the session-close candidate's
0.763561 median ratio missed the preregistered 0.20 ceiling. Consequently no
availability-ingestion source change is ticketed. LDG-2741 through LDG-2744
cover only the corrected public benchmark boundary, dense validation,
byte-identical snapshot-hash deduplication, and proof-template finalization.

Ticket IDs begin at LDG-2719 after the v0.2.0.0 packet. LDG-2733 through
LDG-2735 retain their existing tail identities; amendment tickets continue at
LDG-2736 through LDG-2744 and become prerequisites of those tail IDs.

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
  -> LDG-2736..2738 linear event buffers (amendment stage H)
  -> LDG-2739..2740 prepared valuation and combined proof (amendment stage I)
  -> LDG-2741 corrected boundaries and frozen oracles (stage L)
  -> LDG-2742 dense timestamp validation (stage M)
  -> LDG-2743 snapshot-hash timestamp deduplication (stage N; NEITHER branch)
  -> LDG-2744 proof-template finalization (stage O)
  -> LDG-2733..2734 final accepted-source records (stage O)
  -> LDG-2735 release gate (stage P)
```

Ticket dependencies are the hard readiness gate. Batch order is the default
review sequence. Stages E and F are independent of the warm seams and may run
beside Batches 2 to 4; Stage G follows the production and correctness stages
and amendment Stages H and I follow Stage G. The provisional Stage J record is
diagnostic history. Stages L through O follow it in order, and the hard edges
below enforce that sequence. Stage P follows the independently reviewed Stage
O records and an explicit maintainer go-ahead.
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
2732 -> 2736 -> 2737 -> 2738 -> 2739 -> 2740
2740 -> 2741 -> 2742 -> 2743 -> 2744
2744 -> {2733, 2734}
{2719..2734, 2736..2744} -> 2735
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
| 3.6 dependency and telemetry posture (collapse rule superseded by the amendment; unchanged telemetry names; no new schema column, hash input, public telemetry API, or durable lane name) | LDG-2736 (floor), LDG-2735 (telemetry) |
| 3.7 benchmark clocks and peer workload | LDG-2731, LDG-2734 |
| 4.1 provider-only views | LDG-2720, LDG-2722 |
| 4.1 fold scenarios | LDG-2720, LDG-2723, LDG-2724 |
| 4.1 full 757-pulse fold | LDG-2725 |
| 4.1 writer | LDG-2724 |
| 4.1 rollback and resume | LDG-2724 |
| 4.1 mechanism and source guard | LDG-2726 |
| 4.2 seal-validator matrix | LDG-2728, LDG-2729, LDG-2730 |
| 4.3 finalization matrix | LDG-2727 |
| 4.4 identity and compatibility matrix | LDG-2723, LDG-2724, LDG-2726, LDG-2736, LDG-2739, LDG-2735 |
| 7.1 availability warm record | LDG-2725 (historical pre-retirement pair), LDG-2740 (valuation pair), LDG-2733 (stage J) |
| 7.2 cold seal record | LDG-2733 |
| 7.3 peer record | LDG-2734 |
| 7.4 permitted release claims | LDG-2732, LDG-2734, LDG-2735 |
| 8 documentation and governance closeout | LDG-2732 (manuals and methodology), LDG-2734 (peer README and tracked report after the record), LDG-2735 |
| 9 release gates 1-10 | LDG-2735 (gate 2 evidence from LDG-2726, LDG-2738, and LDG-2740; superseded gate 6 from LDG-2736 and LDG-2735; gate 7 from LDG-2733 and LDG-2734) |
| Re-review N1 (status default keyed on row presence) | LDG-2719 (spec patch), LDG-2720 (test) |
| Amendment 1 authority and narrow supersession | LDG-2735 (final cross-artifact reconciliation) |
| Amendment 2 dependency floor and implementation-choice gate | LDG-2736 |
| Amendment 3.1 event semantic and failure matrix | LDG-2737 |
| Amendment 3.2 event scaling and old-writer retirement | LDG-2738 |
| Amendment 4.1 prepared valuation and semantic matrix | LDG-2739 |
| Amendment 4.2 valuation scaling gate | LDG-2740 |
| Amendment 5 combined eventful availability case | LDG-2740 |
| Amendment 6 compatibility and source guards | LDG-2736, LDG-2738, LDG-2739, LDG-2740 |
| Amendment 7 sequencing and review stops | LDG-2738, LDG-2740, LDG-2733, LDG-2734, LDG-2735 |
| Amendment 8 final-source reruns and documentation claims | LDG-2733, LDG-2734, LDG-2735 |
| Amendment 9 explicit non-goals and later-work routing | LDG-2735 |
| Amendment 10 release gates | LDG-2735 (evidence from LDG-2736 through LDG-2740, LDG-2733, and LDG-2734) |
| Amendment 11 source basis and revision record | LDG-2735 |
| Timestamp amendment 1 authority and narrow supersession | LDG-2741 (method boundary), LDG-2735 (final reconciliation) |
| Timestamp amendment 2 exact scope | LDG-2741, LDG-2742, LDG-2743, LDG-2744 |
| Timestamp amendment 3 public benchmark boundary and parity authority | LDG-2741, LDG-2734 |
| Timestamp amendment 4 dense static-coverage timestamp validation | LDG-2742 |
| Timestamp amendment 5.1 prerequisite and selected `NEITHER` branch | prerequisite commit `9686229`, LDG-2741, LDG-2743 |
| Timestamp amendment 5.2-5.3 availability semantics and gates | LDG-2743 (prove no source change under `NEITHER`) |
| Timestamp amendment 5.4 snapshot-hash timestamp deduplication | LDG-2743, LDG-2733 (final-source paired record) |
| Timestamp amendment 6 exact-parity proof template | LDG-2744 |
| Timestamp amendment 7 sequencing and review stops | LDG-2741, LDG-2742, LDG-2743, LDG-2744, LDG-2733, LDG-2734, LDG-2735 |
| Timestamp amendment 8 final records and permitted claims | LDG-2733, LDG-2734, LDG-2735 |
| Timestamp amendment 9 non-goals | LDG-2735 |
| Timestamp amendment 10 compatibility and source guards | LDG-2741, LDG-2742, LDG-2743, LDG-2734, LDG-2735 |
| Timestamp amendment 11 review and release requirements | LDG-2742, LDG-2743, LDG-2733, LDG-2734, LDG-2735 |
| Timestamp amendment 12 source basis and revision record | LDG-2735 |

## LDG-2719 - Packet Alignment And Ticket Cut

Priority: P0
Effort: M
Dependencies: None
Status: Complete After Review

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
- Record the historical ticket-cut baseline:
  `f0b847d02c2cf66a9871fdda119f55e0ccfd7e42`, package `0.2.0.1`,
  R 4.5.2 ucrt on `x86_64-w64-mingw32`, duckdb 1.4.3, testthat 3.3.1, collapse
  2.1.7 default and 2.1.8 isolated. This record does not change the `DESCRIPTION`
  support floor or constrain later implementation verification.
- Align design index, roadmap, horizon, AGENTS, NEWS, and the
  documentation-contract assertions.
- Make no runtime, public-API, schema, or test-result change.

### Acceptance Criteria

- Every spec section, Section 4 matrix row, Section 9 release gate, and the
  N1 patch has a ticket owner.
- Markdown and YAML IDs, statuses, dependencies, and batch mappings agree.
- Active governance points to v0.2.0.1 and v0.2.0.0 is historical.
- No implementation or gate is claimed complete.

Maintainer closeout: accepted 2026-09-16 after the independent ticket-cut
review corrections landed in `e1ae717`. An additional Claude review was
explicitly waived because this batch changes planning artifacts only.

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
Status: Complete After Review

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
Status: Complete After Review

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
Status: Complete After Review

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
Status: Complete After Review

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
Status: Complete After Review

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
Status: Complete After Review

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
Status: Complete After Review

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
Status: Complete After Review

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
Status: Complete After Review

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
Status: Complete After Review

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
Status: Complete After Review

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
- Independent review accepts Batch 6 before final benchmark records.

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
Status: Complete After Review

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
Status: Complete After Review

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

## LDG-2733 - Final Availability, Cold, Hash, And Profile Records

Priority: P0
Effort: M
Dependencies: LDG-2744
Status: Pending

### Description

Regenerate the Stage O availability warm, cold seal, snapshot-hash, and final
profile records from one exact accepted-source commit. Records produced at
`6b09a1b`, `400a3e5`, or from the corrected working tree are diagnostic
history and cannot satisfy this ticket. This is a measurement ticket, not
release closeout.

### Tasks

- Warm record: one warm-up and at least three quiet-host measured public
  production runs; median and spread of wall around the warm experiment and
  externally sampled peak working set; a host comparable to the reviewed
  block spike or the gate stays open.
- Use new record prefixes from one accepted post-LDG-2744 source commit. Do
  not relabel, overwrite, or promote any earlier record.
- Cite the LDG-2725 pre-retirement pair by prefix as comparison context; do
  not restore the retired path.
- Cold record: the registered full seal once without the profiler, plus a
  separate profiled or sampled run only if attribution is needed; phase times
  and peak working set.
- Rerun the Section 5.4 paired snapshot-hash record at the 630,000-bar dense
  shape with one warm-up and three measured hashes per arm. Require byte and
  hash identity, the formatter-count gate, the 0.80 wall gate, and the
  15-percent peak-memory gate.
- Run the final profiler and report its largest lane without turning a sample
  share into a wall-time partition.
- Report fixture shape, source commit, versions, host metadata, warm-up count,
  repetitions, parity status, and the largest profiled lane.
- Stop after the record is written. Review it with the LDG-2734 result and
  summarize every registered pass or miss for an explicit maintainer decision.

### Acceptance Criteria

- Production median at most 60 seconds and every measured peak at most
  1,024 MiB on a comparable host.
- The seal completes with the pairwise validator absent; the historical
  60-to-90-second estimate is not promoted over the measurement.
- Every snapshot-hash byte and stored hash is exact, and all Section 5.4
  structural, wall, and peak-memory gates pass.
- The availability-ingestion sources remain unchanged under the recorded
  `NEITHER` branch.
- Both records are cited by exact local prefix.
- The reviewed record is available to the maintainer before any release-gate
  work starts; this ticket does not itself authorize closeout.

### Verification

- Availability warm record
- Cold seal record
- Snapshot-hash paired record
- Final profile

### Source Reference

- Spec Sections 7.1, 7.2; timestamp amendment Sections 5.4, 7 stage O, 8

### Classification

```yaml
type: benchmark
surface: final-performance-evidence
scope: availability-cold-hash-profile-records
```

## LDG-2734 - Peer Benchmark Record

Priority: P1
Effort: M
Dependencies: LDG-2744
Status: Pending

### Description

Run the explicit standard peer workload after package code, benchmark method,
and manuals are final. The two memory rows must use public one-candidate
`ledgr_sweep()` calls under method
`public_one_candidate_ledgr_sweep_v002`. Earlier private-fold and corrected
working-tree rows remain diagnostic history. This is a measurement ticket,
not release closeout.

### Tasks

- Run `--preset record --release v0.2.0.1 --engine-set all --n-inst 500
  --n-days 1260 --fast 5 --slow 10 --seed 20260530
  --compiled-accounting-model spot_fifo`.
- Use a new record prefix from the same exact post-LDG-2744 source commit used
  by LDG-2733; do not overwrite or silently promote an earlier record.
- Provision quantstrat in a dedicated isolated R 4.6.1 benchmark library. Pin
  quantstrat 0.25 at `1114e4a1a8a3b68d2fb7a62b52d743cbc5e4b39f`, blotter
  0.17.0 at `dddb448f7a5d6eb63dfbe421ba80779e820a3601`, and
  FinancialInstrument 1.3.0 at
  `98bcf09fc80e25611897404dcd59321ef67850ac`; use xts 0.14.2 and TTR
  0.24.4. Record the resolved versions, GitHub SHAs, and library root. This is
  benchmark-only provisioning and must not add a package dependency.
- Record `ledgr_ttr_canonical_sweep` and
  `ledgr_ttr_compiled_spot_fifo_sweep` as public one-candidate workflows.
  Keep the complete public-call wall, including sweep orchestration and
  inline summary, inside each reported clock.
- Use compensated production-inline equity as the memory reference. Compare
  fills and trades exactly and floating equity with the existing relative
  `all.equal()` tolerance of `1e-8`; record maximum absolute and relative
  residuals, affected columns, and affected rows.
- Run any private reconstruction only as an untimed oracle. Do not publish it
  as a peer result or rename an historical private row as a public workflow.
- Record status and environment per engine; reconcile phase totals with the
  full row wall; compare canonical equity, fills, and trades to durable ledgr
  before interpreting timing; classify the first divergence where full parity
  is impossible. Quantstrat must finish as `DONE`; Backtrader, Zipline, and
  local LEAN may remain explicitly `UNAVAILABLE` with reasons.
- Update the peer README and tracked report with all five required fields: the
  exact closeout command, the exact record prefix, the environment, the parity
  status, and explicit non-ranking language.
- State that earlier peer parity CSVs used reconstructed equity while this
  record uses compensated production-inline equity.
- Render phase order explicitly as snapshot preparation, experiment setup,
  engine, and results. Unavailable times remain missing; in particular LEAN
  may not render or sort as zero.
- Build report status from the named `Status` column and keep `Reason`
  separate; make B2 prose conditional on the row actually being present.
- Report zero divergence as a count without a zero-denominator percentage, and
  report Zipline's weak-tolerance result literally rather than as full parity.
- Cite the exact record prefix in the release closeout; keep raw records
  local.
- Stop after the record and report are written. Review them with the LDG-2733
  result and summarize every registered pass, miss, or unavailable peer for an
  explicit maintainer decision.

### Acceptance Criteria

- The durable, public canonical sweep, public compiled sweep, built-in SMA,
  and quantstrat rows are present with status `DONE`.
- The compiled row has exact non-floating parity and tolerance-qualified
  equity parity against the compensated production reference before timing is
  interpreted.
- The isolated quantstrat environment records the required versions and SHAs;
  an unavailable or failed quantstrat row blocks this measurement checkpoint.
- Backtrader, Zipline, and local LEAN are present or explicitly `UNAVAILABLE`
  with reasons.
- Parity precedes timing interpretation.
- The peer README and tracked report carry the five required fields for this
  record and no ranking language.
- Plot data, row status, totals, explicit phase order, and missing unavailable
  times agree with the rendered report.
- Status/reason, conditional-row, zero-denominator, and weak-tolerance report
  cases render honestly from the fresh record.
- No hosted LEAN service.
- The reviewed record is available to the maintainer before any release-gate
  work starts; this ticket does not itself authorize closeout.

### Verification

- Peer benchmark record run
- Parity and divergence review
- Peer README and tracked-report field check

### Source Reference

- Spec Sections 3.7, 7.3, 7.4, 8; timestamp amendment Sections 3, 7 stage O, 8

### Classification

```yaml
type: benchmark
surface: peer-benchmark
scope: release-record
```

## LDG-2735 - v0.2.0.1 Release Gate

Priority: P0
Effort: L
Dependencies: LDG-2719, LDG-2720, LDG-2721, LDG-2722, LDG-2723, LDG-2724, LDG-2725, LDG-2726, LDG-2727, LDG-2728, LDG-2729, LDG-2730, LDG-2731, LDG-2732, LDG-2733, LDG-2734, LDG-2736, LDG-2737, LDG-2738, LDG-2739, LDG-2740, LDG-2741, LDG-2742, LDG-2743, LDG-2744
Status: Pending

### Description

After the Stage O evidence checkpoint has been independently reviewed and the
maintainer has explicitly elected to proceed, follow the release playbook,
prove the ten Section 9 gates, and close the packet without conflating local,
branch, main, and tag evidence.

### Tasks

- Confirm the accepted LDG-2733 and LDG-2734 review and explicit maintainer
  go-ahead before execution; otherwise stop with this ticket Pending.
- Read `inst/design/release_ci_playbook.md` before execution.
- Run the complete suite, source build, and
  `R CMD check --no-manual --no-build-vignettes`.
- Confirm `collapse (>= 2.1.8)` is declared and run the relevant suite under
  collapse 2.1.8 or later; no 2.1.7 fallback or compatibility branch exists.
- Confirm schemas, identity formats, and v0.2.0.0 fixture reopen are unchanged.
- Confirm persisted and public telemetry names are unchanged and that no
  schema column, hash input, public telemetry API, or durable lane name was
  added for this cycle.
- Confirm every Section 4 matrix is represented by durable tests or a named
  closeout artifact and every correctness or parity stop was independently
  reviewed.
- Confirm every amendment matrix and performance gate is represented by
  durable tests or an accepted evidence artifact, the combined eventful
  availability case passes, and no superseded implementation or test-only
  selector ships.
- Confirm the timestamp amendment's `NEITHER` branch changed no availability
  source, dense validation and hash deduplication passed their own gates, and
  the proof template is indexed and locked without becoming implementation
  authority.
- Render documentation, confirm anchors resolve, and remove generated
  artifacts, temporary stores, `Rplots.pdf`, tarballs, and check directories.
- Update NEWS, version surfaces, AGENTS, design index, roadmap, and horizon
  to their release state; write the release closeout citing the three record
  prefixes.

### Acceptance Criteria

- Base-spec gates 1 through 10 and amendment gates 1 through 6 hold; no
  benchmark number waives a semantic, persistence, identity, rollback, resume,
  reopen, dependency, or source-removal gate.
- The Stage O evidence checkpoint was independently reviewed and explicitly
  accepted by the maintainer before Stage K began.
- Telemetry names are unchanged and none of the four prohibited additions
  exists.
- Ticket Markdown, YAML, batch plan, spec, indexes, and closeout agree.
- Branch is ready for remote branch CI; main and tag CI remain later evidence.

### Verification

- Release CI playbook
- Full local suite, build, and check
- Collapse minimum-version and no-fallback checks
- Telemetry-name and prohibited-addition check
- Documentation renders and anchor check
- Git status and generated-artifact review

### Source Reference

- Spec Sections 8, 9; hot-path amendment Sections 7 stage K, 8, 10;
  timestamp amendment Sections 7 stage P, 8, 10, 11

### Classification

```yaml
type: release
surface: release-gate
scope: v0.2.0.1-closeout
```

## LDG-2736 - Collapse 2.1.8 Event-Write Route Gate

Priority: P0
Effort: M
Dependencies: LDG-2732
Status: Complete After Review

### Description

Freeze the current memory and durable event writers as test-only oracles,
prove the corrected collapse 2.1.8 by-reference route against the temporary
unbind control, and raise the package dependency floor only after that route
passes.

### Tasks

- Preserve the current extract/mutate/reassign behavior outside installed
  source as the exact pre-retirement oracle for both handlers.
- Add one private direct-write candidate using collapse 2.1.8 character and
  list `setv()` on buffer-owned storage; expose no public argument, option,
  environment variable, or durable arm stamp.
- Implement the unbind/mutate/rebind route only in the bounded comparison
  harness. It may not enter installed package source.
- On the registered 500 by 1,260 eventful shape, compare the direct route with
  the control for both handlers using one warm-up and at least three measured
  runs, exact output parity, repeated allocation, ordinary GC, and forced-GC
  stress.
- Require each direct-route median eventful wall to be no more than 1.20 times
  its control. If any gate fails, stop and return to the amendment; do not
  promote the control or retain a dual shipping path.
- After the route passes, declare `collapse (>= 2.1.8)` in `DESCRIPTION` and
  prove an under-floor environment fails dependency resolution rather than
  selecting a runtime fallback.

### Acceptance Criteria

- Direct and control outputs are exact on every compared semantic and
  persisted field, and the direct route passes the two handler wall gates.
- Forced-GC stress produces no corruption, invalid character/list reference,
  warning, or crash.
- `DESCRIPTION` declares collapse 2.1.8 as the minimum and no 2.1.7 behavior
  branch exists.
- The temporary control is test-only and no caller-selectable seam exists.

### Verification

- Two-handler implementation-choice record
- Exact event and persisted-output diff
- Allocation, ordinary-GC, and forced-GC stress
- Dependency-floor and under-floor resolution checks

### Source Reference

- Accepted amendment Sections 2, 6, 7 stage H

### Classification

```yaml
type: performance
surface: event-buffer
scope: collapse-route-gate
```

## LDG-2737 - Linear Memory And Durable Event Buffers

Priority: P0
Effort: L
Dependencies: LDG-2736
Status: Complete After Review

### Description

Make indexed writes into owned typed storage the single production path in
both event handlers and prove the amendment's complete semantic and failure
matrix before the old oracle is retired.

### Tasks

- Replace scale-growing extract/scalar-replace/reassign writes for the memory
  handler's six character and one list columns and the durable handler's six
  character columns with the accepted direct route.
- Preserve geometric capacity growth and existing memory/durable transaction,
  flush, rollback, and ownership boundaries; keep total buffer construction
  amortized `O(E)` apart from required accounting work.
- Compare the full ordered event schema, including IDs, sequence, timestamps,
  all economic fields, `meta_json`, and parsed list metadata, against the
  frozen oracle.
- Cover fills, trades, cash, positions, equity, strategy state, completion,
  diagnostics, telemetry, opens, closes, reversals, repeated same-side and
  no-op targets, final-bar no-fill, non-zero fees, and non-zero slippage.
- Inject a small private capacity and exercise immediately before, at, and
  after at least two growth boundaries.
- Cover completion, controlled stop, unexpected error, append failure,
  interruption, resume to `DONE`, resume then error, memory/durable common
  surfaces, and durable close/reopen/result extraction.

### Acceptance Criteria

- Compared values are exact unless an existing contract names a numeric
  tolerance; identity and row order are exact.
- Failure paths expose no partial active event and leave the committed prefix
  recoverable.
- No production append extracts and reassigns a capacity-growing column.
- One production writer path serves each existing handler without changing
  public API, schemas, hashes, identities, or accounting policy.

### Verification

- Event semantic and persisted-output matrix
- Capacity-boundary tests
- Error, rollback, interruption, resume, and reopen tests
- Memory/durable parity checks

### Source Reference

- Accepted amendment Sections 3.1, 6, 7 stage H

### Classification

```yaml
type: performance
surface: event-buffer
scope: linear-production-writes
```

## LDG-2738 - Event Scaling And Old-Writer Retirement

Priority: P0
Effort: M
Dependencies: LDG-2737
Status: Complete After Review

### Description

Prove the repaired event writers scale materially and linearly, then retire
the oracle, comparison control, and every selection mechanism before the
independent Batch 8 review.

### Tasks

- Run the registered SMA 5/10, 1,260-session, seed-20260530 zero-cost curve at
  50, 100, 200, 350, and 500 stable-subset instruments for both handlers.
- In one quiet-host session, record one warm-up and at least three measured
  current and candidate runs at 500 instruments plus one diagnostic run at
  every smaller point.
- Require each 500-instrument candidate median engine wall to be at most 0.60
  times its current oracle median and its microseconds per fill to be no more
  than 1.35 times the minimum over 100, 200, 350, and 500 instruments.
- Reconcile fill count and final equity at every point; record externally
  sampled peak working set and require no more than 15 percent above the
  current arm's same-session maximum.
- Persist the exact accepted evidence prefix before deleting the oracle. The
  deletion commit must be later than and cite that prefix.
- Remove the old writer, unbind control, comparison seam, and arm markers;
  extend the installed-source guard to reject them and the retired
  extract/mutate/reassign shape.
- Write the Batch 8 evidence record and stop for independent review.

### Acceptance Criteria

- Both handlers pass the wall, normalized-cost, reconciliation, and memory
  gates; a merely lower-constant quadratic writer cannot pass.
- The evidence prefix is immutable and precedes oracle retirement.
- Installed source contains only the direct linear path and no old writer,
  control, fallback, option, stamp, or 2.1.7 compatibility branch.
- Independent review accepts the Batch 8 implementation and evidence.

### Verification

- Five-point scaling curve for both handlers
- Quiet-host paired 500-instrument record
- Source and namespace-body guard
- Focused regression net and independent review

### Source Reference

- Accepted amendment Sections 3.2, 6, 7 stage H, 10

### Classification

```yaml
type: performance
surface: event-buffer
scope: scaling-and-retirement
```

## LDG-2739 - Prepared Fold-Time Availability Valuation

Priority: P0
Effort: L
Dependencies: LDG-2738
Status: Complete After Review

### Description

Replace repeated instrument matching and price-prefix rescanning with
run-local primitive valuation state whose fold-time work is `O(N*P)`, while
keeping the current function as a test-only oracle until measurement closes.

### Tasks

- Freeze the current valuation function outside installed execution as the
  pre-retirement oracle.
- Prepare once per run an instrument-to-source-row index and primitive state
  for last finite close, source pulse or timestamp, and staleness age.
- Advance state once per nondecreasing fold pulse and emit current-axis marks
  by indexed lookup; fail closed on an out-of-order internal pulse.
- Prohibit per-axis full-vector `match()` and growing `seq_len(pulse_idx)`
  close-prefix scans in production valuation.
- Cover never-observed and current names; leading, interior, and trailing
  gaps; exact fresh/stale boundaries; expiry and re-entry; held former members
  and held names outside the strategy axis; terminal events around the pulse;
  complete-list and interval membership changes; completion and controlled
  stop.
- Compare direct, memory, durable, interrupted/resumed, and reopened outputs:
  full valuation views, diagnostic stages and reasons, equity, completion,
  events, strategy state, and terminal evidence.
- Keep the state transient and absent from persistence, caches, hashes,
  identities, configs, worker contracts, public returns, and dense runs.

### Acceptance Criteria

- The semantic matrix is exact and expected gaps are never imputed to zero or
  to future observations.
- Instrument lookup is prepared once and no price prefix is rescanned.
- Instrumented work remains proportional to emitted instrument-pulses over at
  least three pulse counts and three source-instrument counts, including the
  563-source, 505-member, 757-pulse shape.
- Public and durable compatibility surfaces remain unchanged.

### Verification

- Valuation semantic matrix
- Structural pulse and source-instrument scaling proof
- Resume, reopen, and dense-path exclusion tests
- Identity, persistence, and public-surface guards

### Source Reference

- Accepted amendment Sections 4.1, 4.2 structural gate, 6, 7 stage I

### Classification

```yaml
type: performance
surface: availability-valuation
scope: prepared-fold-state
```

## LDG-2740 - Valuation Scaling And Combined Correction Evidence

Priority: P0
Effort: M
Dependencies: LDG-2739
Status: Complete After Review

### Description

Prove the prepared valuation path at the registered population, exercise both
amendment corrections together, retire the test oracle, and close Batch 9 at
an independent review stop.

### Tasks

- On one quiet host, run one warm-up and at least three measured current and
  candidate arms over the zero-fill 563-source, 505-member, 757-pulse fixture
  with provider and diagnostic paths held constant.
- Require candidate median `wall_seconds` at most 0.80 times the current arm's
  same-session median, an improvement exceeding the current arm's full spread,
  every peak at most 1,024 MiB, and no peak more than 15 percent above the
  current arm's same-session maximum.
- Record full semantic parity and the structural scaling proof beside the
  paired measurement; the provisional 25.42-second record cannot satisfy this
  ticket.
- Add the bounded combined case with non-zero fills, at least one event-buffer
  capacity crossing, non-zero transaction cost, complete-membership change, a
  held former member, a gap reaching the stale boundary, and one terminal
  event. Compare every event and valuation surface required by the amendment.
- Persist the accepted paired prefix before removing the valuation oracle; the
  deletion commit must be later than and cite that prefix.
- Remove the oracle and any test-only selector, extend the source guard, write
  the Batch 9 evidence record, and stop for independent review.

### Acceptance Criteria

- The candidate passes the 0.80 wall, spread, peak-memory, structural, and
  semantic gates.
- The combined case proves the two corrections coexist without changing
  accounting, availability, diagnostic, persistence, or identity semantics.
- No prefix-scanning oracle or selector remains in installed source or ships
  into Stage J.
- Independent review accepts the Batch 9 implementation and evidence.

### Verification

- Paired 757-pulse quiet-host record
- Combined eventful availability case
- Source and identity guards
- Focused regression net and independent review

### Source Reference

- Accepted amendment Sections 4.2 measured gate, 5, 6, 7 stage I, 10

### Classification

```yaml
type: performance
surface: availability-valuation
scope: scaling-integration-and-retirement
```

## LDG-2741 - Freeze Public Benchmark Boundary And Optimization Oracles

Priority: P0
Effort: M
Dependencies: LDG-2740
Status: Review Pending

### Description

Freeze the corrected public peer boundary, compensated memory-equity
authority, report-integrity rules, and current dense/hash oracles before any
new production optimization begins. Record the prerequisite's `NEITHER`
branch without reinterpreting its exact but under-threshold candidates.

### Tasks

- Replace the two private-fold peer rows with public one-candidate
  `ledgr_sweep()` method tests under
  `public_one_candidate_ledgr_sweep_v002`; retain historical private rows only
  under their original internal-diagnostic identities.
- Freeze compensated production-inline memory equity as authoritative. Keep
  exact fills/trades checks and the existing relative `all.equal()` tolerance
  of `1e-8` for floating equity, with residual reporting.
- Lock explicit phase order, completed-versus-unavailable plotting, missing
  peer times, and source-data/chart agreement in tests.
- Preserve current dense timestamp validation and snapshot hashing outside the
  candidate source as test-only oracles. Write proof plans against the
  exact-parity template; record that dense validation is `RECLASSIFY` while
  hash deduplication remains eligible.
- Bind prerequisite commit `9686229` and outcome `NEITHER`. Add a guard that
  prevents any availability-ingestion source change in this amendment.
- Capture current-arm semantic and timing prefixes before changing dense or
  hash production source. Stop for independent review of Stage L.

### Acceptance Criteria

- Both peer memory rows invoke public one-candidate `ledgr_sweep()` and no
  private-fold row is peer-comparable.
- The parity reference, exact/tolerance distinctions, and report missingness
  rules are detecting tests rather than narrative only.
- Dense and hash current-arm oracles and prefixes are immutable inputs to the
  next stages.
- `NEITHER` is recorded before implementation and no availability-ingestion
  source change is authorized or present.

### Verification

- Public-method and reported-clock boundary tests
- Memory parity-reference and residual tests
- Phase-order and unavailable-time render tests
- Oracle and current-prefix checks
- Availability-source no-change guard
- Independent Stage L review

### Source Reference

- Timestamp amendment Sections 1 through 3, 5.1, 6, 7 stage L, 10

### Classification

```yaml
type: benchmark-correctness
surface: benchmark-boundary
scope: public-method-and-oracle-freeze
```

## LDG-2742 - Dense Static-Coverage Timestamp Validation

Priority: P0
Effort: L
Dependencies: LDG-2741
Status: Pending

### Description

Replace per-bar timestamp formatting in dense static-coverage validation with
one primitive conversion per instrument axis while retaining the complete
rectangle proof and deliberately tightening unsupported sub-second direct
input as specified.

### Tasks

- Implement one primitive POSIXct or numeric conversion per instrument axis;
  prohibit per-bar normalizers, text formatters, and a DuckDB round trip after
  vectors are materialized.
- Fail missing, non-finite, and sub-second axes with
  `ledgr_invalid_pulse_context`; retain the existing coverage error class and
  message for missing, empty, and misaligned instruments.
- Compare the full Section 4.3 matrix against the retained oracle, including
  direct, public sweep, precompute, and walk-forward consumers and the
  availability bypass.
- Add a structural counter and source guard proving one vector conversion per
  axis and zero per-bar formatting. Gut the optimized path with a scalar or
  repeated-work mutant and prove the gate fails.
- Run the paired 500-by-1,260 public canonical and compiled sweep record with
  one warm-up and three measurements per arm. Enforce the 0.10 validator
  ratio, both 10-second public-row improvements, spread, semantics, and
  15-percent peak-memory gates.
- Remove the production old path only after the paired record passes. Retain
  no option, arm stamp, fallback, or alternate public method. Stop for an
  independent Stage M code review.

### Acceptance Criteria

- Every supported semantic case agrees exactly and every specified invalid
  direct case raises its bound class.
- The mutation-sensitive structural gate proves zero per-bar formatting.
- All paired timing, spread, and peak-memory thresholds pass on one quiet
  host; timing does not substitute for the structural proof.
- Production source is singular and public APIs, schemas, identities, and
  availability behavior are unchanged.

### Verification

- Dense semantic and failure matrix
- Structural counter, source guard, and deliberate mutant
- Paired public canonical/compiled sweep record
- Consumer and availability-bypass regression tests
- Independent Stage M code review

### Source Reference

- Timestamp amendment Sections 4, 6, 7 stage M, 10, 11

### Classification

```yaml
type: performance-correctness
surface: dense-static-validation
scope: primitive-timestamp-axis
```

## LDG-2743 - Byte-Identical Snapshot-Hash Timestamp Deduplication

Priority: P0
Effort: L
Dependencies: LDG-2742
Status: Pending

### Description

Format each distinct timestamp once within each existing snapshot-hash chunk,
map canonical tokens back in original row order, and remove the candidate if
any byte, hash, reopen, tamper, or bounded-memory proof fails. The selected
`NEITHER` branch makes no availability-ingestion source change.

### Tasks

- Deduplicate timestamp formatting within each existing chunk only, preserving
  first-occurrence order for distinct values and original emitted row order.
- Keep chunk size, query order, numeric formatting, separators, missing
  tokens, newlines, encoding, algorithm, hash-rule version, stored hashes,
  verification, and ownership unchanged. Ship no cross-chunk cache.
- Compare bytes and hashes over dense rule 1, availability rule 2, repeated
  and unique timestamps, every canonical bar column, registered chunk sizes
  and boundaries, fresh and old snapshots, reopen, run guard, and timestamp,
  price, and stored-hash tampering.
- Use the exact-parity proof template and remove OPT-L01 from the release on
  any identity difference; do not bump a version or expected hash.
- At 630,000 bars run one warm-up and three measured hashes per arm. Enforce
  the 0.20 formatter-count, 0.80 median-wall, exact-hash, and 15-percent
  peak-memory gates.
- Prove the availability-ingestion files remain unchanged from the Stage L
  source. Retire only the hash oracle/selector after passing, then stop for an
  independent Stage N code review.

### Acceptance Criteria

- Every compared byte and hash is identical and all reopen, run-guard, and
  tamper checks retain their current behavior.
- All structural, timing, and peak-memory gates pass at the registered shape.
- Production hashing has one bounded path with no cross-chunk cache, fallback,
  option, arm stamp, hash-rule change, or old production path.
- The prerequisite remains `NEITHER` and availability-ingestion production
  source is unchanged.

### Verification

- Byte/hash matrix across rules, chunks, boundaries, and old snapshots
- Reopen, run-guard, and tamper tests
- Formatter-count, wall, and peak-memory record
- Availability-source no-change guard
- Exact-parity proof and independent Stage N code review

### Source Reference

- Timestamp amendment Sections 5 through 7 stage N, 8, 10, 11

### Classification

```yaml
type: performance-identity
surface: snapshot-hashing
scope: within-chunk-timestamp-deduplication
```

## LDG-2744 - Finalize And Index Exact-Parity Proof Template

Priority: P1
Effort: M
Dependencies: LDG-2743
Status: Pending

### Description

Independently verify, finalize, index, and contract-lock the exact-parity
internal optimization proof template as evidence infrastructure. It does not
become independent authority to implement work or bypass RFC, spec, ticket,
spike, or review requirements.

### Tasks

- Review the template against the timestamp amendment, spike protocol, RFC
  cycle, and accepted optimization-manual principles.
- Retain its eligibility gate, byte/exact/tolerance distinction,
  preregistered threshold, structural mutation, public-workflow check, and
  stop/reclassification conditions.
- State explicitly that the template is evidence infrastructure and not
  implementation authority; preserve OPT-C01's `RECLASSIFY` result.
- Confirm the accepted OPT-L01 proof artifact satisfies the template and cite
  it without turning the template into retrospective permission.
- Index the final template from the design index and packet README. Add
  documentation-contract tests for title, status, core stops, and authority
  relationship.
- Stop with Stage O source frozen for LDG-2733 and LDG-2734.

### Acceptance Criteria

- Independent review accepts the template and its authority boundary.
- The design and packet indexes resolve it and documentation contracts detect
  removal or weakening of its core stops.
- No standing no-ticket or no-RFC lane is created.
- The exact source commit for final evidence is recorded after template and
  production work are accepted.

### Verification

- Independent proof-template review
- Index and anchor checks
- Documentation-contract tests
- Stage O source-freeze record

### Source Reference

- Timestamp amendment Sections 6, 7 stage O, 10, 11

### Classification

```yaml
type: documentation-governance
surface: optimization-proof-template
scope: finalization-index-and-contract
```
