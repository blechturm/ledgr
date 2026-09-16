# ledgr v0.2.0.1 Spec

**Status:** Accepted 2026-09-16; tickets cut for implementation. No
implementation or release gate is claimed complete.
**Date:** 2026-09-15. **Revised:** 2026-09-16. **Accepted:** 2026-09-16, after
the first review (`v0_2_0_1_spec_review.md`), the focused re-review
(`v0_2_0_1_spec_re_review.md`), and the in-place N1 patch to Sections 3.2 and 4.1.
**Target release:** v0.2.0.1.
**Draft baseline:** `f0b847d02c2cf66a9871fdda119f55e0ccfd7e42` on branch
`v0.2.0.1`.
**Scope:** Productionize the reviewed availability hot-path representations,
correct the quadratic seal-time availability validators, repair resumed-run
equity finalization, and close the release with phase-separated availability
and peer benchmark evidence.
**Authority:** The accepted availability hot-path synthesis and its maintainer
decisions. This spec may narrow implementation choices but must not weaken
their semantic, persistence, identity, or evidence gates.

This packet is an internal implementation and correctness release. It changes
no public API, snapshot or experiment schema, hash, run identity, accounting
policy, availability policy, or default research workflow.

## 0. Source Inputs And Authority Order

### 0.1 Binding design inputs

Read in this order:

1. `inst/design/rfc/rfc_availability_hot_path_representation_v0_2_0_x_synthesis.md`
   (accepted 2026-09-15);
2. `inst/design/rfc/rfc_availability_hot_path_representation_v0_2_0_x_maintainer_decisions.md`;
3. `inst/design/rfc/rfc_availability_hot_path_representation_v0_2_0_x_final_review.md`;
4. `inst/design/contracts.md`, especially the availability, fold, persistence,
   resume, and identity contracts; and
5. the completed v0.2.0.0 packet, which remains authoritative for the public
   asset-availability surface.

If this draft conflicts with the accepted synthesis or maintainer decisions,
the accepted RFC artifacts win until the spec is corrected and accepted.

### 0.2 Reviewed execution evidence

The packet consumes three GREEN spike cycles and one attributed cold-path
probe. Their code is evidence and a productionization starting point, not an
automatic implementation merge:

- writer spike:
  `dev/spikes/availability-hot-path-representation/spike_inventory.md` and its
  reviewed evidence;
- provider spike:
  `dev/spikes/availability-provider-preparation/spike_inventory.md`, checker,
  runner, and evidence;
- diagnostic-block spike:
  `dev/spikes/availability-diagnostic-block-write/spike_inventory.md`, checker,
  runner, and evidence; and
- seal attribution:
  `dev/spikes/snapshot-sealing/probe_findings.md` and `loop_audit.md`.

The reviewed prototype seams at the draft baseline are deliberately not the
shipping shape. They are selected by internal spike options, default to the old
paths, and stamp the chosen arm. Productionization removes those options,
stamps, and dual runtime paths after the parity gates have run.

### 0.3 Operational inputs

- `inst/design/spike_protocol.md`, especially section 10 on cold and warm
  clocks;
- `inst/design/manual/benchmark_methodology.qmd`;
- `inst/design/manual/optimization_coding_style.qmd`;
- `dev/bench/peer_benchmark/peer_benchmark.R` and its tracked report; and
- `inst/design/release_ci_playbook.md`.

The broad loop audit is a discovery map. Only work explicitly named in this
spec enters v0.2.0.1.

## 1. Thesis And Release Outcome

ledgr's research workflow pays snapshot construction when data or
snapshot-defining inputs change, then runs many experiments against the same
sealed snapshot. The release therefore treats these as different clocks:

```text
cold_snapshot_construction = ingest + validate + seal
warm_research_iteration = experiment_setup + run + required_results
```

The v0.2.0.0 availability implementation is semantically sound, but its first
full-population use exposed representation defects:

- the provider repeatedly filters fact data frames for every instrument and
  pulse;
- diagnostic handling constructs one-row data frames and binds them after the
  fold;
- seal validation compares availability rows pairwise; and
- finalization rewrites the equity curve from only the final invocation after
  an interrupted run resumes.

v0.2.0.1 replaces those shapes without changing their meaning. The intended
release outcome is:

1. facts are compiled once per experiment into primitive indexed state and
   queried by cursors during the shared fold;
2. ordinary diagnostic evidence is constructed once per pulse and written
   through bounded typed column chunks;
3. availability conflict validation uses state-aware grouped sweeps rather
   than quadratic row pairs;
4. resumed `DONE` and `INCOMPLETE` runs retain the exact achieved equity
   prefix and reopen successfully; and
5. the release records honest cold, warm, and peer-comparison clocks without
   converting internal evidence into a public speed ranking.

No speed result can compensate for a semantic, persisted-output, identity,
rollback, or resume mismatch.

## 2. Scope Boundaries And Compatibility

### 2.1 Public and durable compatibility

The release preserves:

- all exported functions, arguments, return classes, names, types, ordering,
  conditions, and classed errors;
- the shared `ledgr_run()` / `ledgr_sweep()` fold core and one transaction
  owner;
- snapshot and experiment schema versions;
- canonical JSON, snapshot hashes, config hashes, strategy identity, run
  identity, fact IDs, diagnostic IDs, and event identity;
- availability decision and execution timing, membership, status, lifetime,
  terminal-event, gap, valuation, affordability, and controlled-stop policy;
- complete ordinary diagnostic evidence, sequence order, failure rows,
  rollback, resume, and reopen semantics;
- the public `ledgr_facts_resolve()` contract as an independent direct
  reference; and
- canonical R execution as the default. Availability-aware compiled spot-FIFO
  remains unsupported exactly as in v0.2.0.0.

No schema migration is authorized or needed. Old v0.2.0.0 snapshots and
experiment stores must open and execute under v0.2.0.1 without rewriting
identity-bearing data.

### 2.2 In scope

- production prepared provider and all true provider-build consumers;
- production typed diagnostic writer and per-pulse diagnostic block;
- durable regression coverage ported from the three spike harnesses;
- grouped state-aware membership, status, and lifetime conflict validators;
- complete-set membership setwise validation before any sweep bypass;
- resumed-run equity-prefix merge and terminal-evidence regression tests;
- benchmark phase-boundary correction and the two release closeouts;
- focused updates to the optimization and benchmark manuals after code lands;
- ordinary version, NEWS, design-index, and release-closeout housekeeping.

### 2.3 Explicit non-goals

- no valuation or mark-history optimization;
- no general removal of loops or data frames;
- no per-bar timestamp, provenance JSON, fact-hash, reader, hydration,
  strategy-state, event-buffer, or finalization optimization beyond the named
  equity-prefix correctness repair;
- no new cache, persisted prepared-provider artifact, schema table, hash, or
  identity field;
- no public tuning option for provider representation, chunk capacity, or
  diagnostic construction;
- no spot-crypto probe or implementation;
- no compiled availability execution or broader B2 work;
- no parallel architecture change;
- no LEAN cloud purchase or hosted benchmark service;
- no Docker benchmark repository; and
- no public peer ranking or claim of LEAN, Nautilus, Zipline, Backtrader,
  quantstrat, or other engine parity in speed or total semantics.

## 3. Spec-Cut Decisions

### 3.1 Production switch and oracle retirement

The reviewed alternative becomes the only package runtime path. Before the
old runtime paths are removed, the implementation must run the final two-arm
checker against the production candidate.

After that gate:

- remove `ledgr.internal.spike_diagnostic_writer`,
  `ledgr.internal.spike_diagnostic_chunk_rows`,
  `ledgr.internal.spike_diagnostic_block`, and
  `ledgr.internal.spike_availability_provider` selection;
- remove `spike_arm` and every arm-observation field from package runtime
  objects;
- remove the old row-list writer and scalar per-row diagnostic construction;
- remove `ledgr_availability_provider_build_current()`, its per-pulse view
  assembly, `ledgr_availability_members_at()`, and the old status, lifetime,
  and terminal-event resolver functions that have no caller after that
  provider is retired; and
- retain the old full provider and writer references only in `dev/spikes/` or
  test helpers where installed package execution cannot source them.

`ledgr_membership_resolve_at()`, `ledgr_membership_evidence()`, and the helpers
they require remain installed as the unchanged engine of the public
`ledgr_facts_resolve()` and `ledgr_facts_history()` inspection contracts. They
are direct public-reference logic, not a provider fallback: no fold, result,
or reopen provider consumer may call them. The source guard therefore proves
the exact retired builder, per-pulse view assembly, and unused family
resolvers are absent; it does not demand the removal of these retained public
inspection helpers. Frozen expected outputs and the public resolver remain
durable regression references. v0.2.0.1 must not ship a hidden fallback to the
old provider or writer.

### 3.2 Prepared availability provider

The production provider is built once after snapshot verification and before
the fold. It compiles the canonical sparse fact tables without changing their
stored form.

Membership uses the two measured shapes:

- complete and partial set headers remain in processing order
  `(effective_from, knowledge_time, set_id)`;
- a separate eligibility order over
  `max(effective_from, knowledge_time)` drives one cursor for non-decreasing
  cutoffs, with deterministic re-seek when a cutoff moves backwards;
- among eligible headers, the last complete header in processing order resets
  membership state, and that header plus every eligible complete or partial
  header after it contributes its per-header member index set; when no
  complete header is eligible, all eligible partial headers contribute; and
- interval assertions, which have no `set_id`, remain flat start, end, member,
  and instrument-index vectors in
  `(effective_from, knowledge_time, fact_id)` order. Applicable interval rows
  override header state with the last applicable assertion per instrument.

No unmeasured CSR membership representation is introduced.

Status, lifetime, and terminal events use flat CSR-style segment tables:

- boundaries and resolved integer codes are compiled per instrument using the
  current applicability and interval rules;
- offset and count vectors locate each instrument's segments;
- mutable cursors advance for monotone cutoffs and re-seek for out-of-order
  cutoffs; and
- cursor state is owned by one provider instance and never shared between
  concurrent runs or sweep candidates.

At every status segment, facts superseded by an applicable fact are removed,
the highest remaining precedence wins, and distinct status values tied at
that precedence resolve to `conflicting`. When the status family has persisted
rows but none applies at the cutoff, the instrument resolves to `unknown`;
when the snapshot holds no status rows at all, every instrument resolves to
`active`. Both current providers key this default on row presence, not on
family declaration, and the productionized build must match that behavior.
Lifetime and terminal event resolve from the last applicable row in
`(effective_from, knowledge_time, original read order)` order. With no
applicable lifetime row, lifetime is `unknown` and terminal event is empty.

The provider must preserve:

- configured order for fixed universes and stable-ID ordering for
  membership-rule universes;
- held former members after current members;
- inclusive effective and knowledge boundaries and exclusive `effective_to`;
- all decision and execution view columns, values, types, ordering, reasons,
  evidence references, and metadata; and
- repeat and shuffled query order independence.

True provider-build consumers use the prepared build:

- fold decision and execution views build once per experiment;
- the `availability` result view builds once per public result call from
  verified persisted canonical facts and reuses that build for every cutoff;
- `ledgr_run_open()` builds once when validating an `INCOMPLETE` availability
  run and uses the prepared provider's session calendar; `ledgr_run_explain()`
  consumes the result view and does not perform another provider build; and
- parallel workers that execute an availability fold build their own provider
  through the same production constructor, without relying on process options.

`ledgr_facts_resolve()` remains unchanged. It directly resolves public fact
rows and sessions and stays the independent membership reference.

### 3.3 Diagnostic writer and per-pulse block

The diagnostic writer owns bounded typed column chunks with a production
capacity of 4,096 rows. Its unexported constructor accepts an internal
test-only capacity argument that defaults to 4,096; ordinary fold calls omit
that argument. Tests may invoke the constructor directly or mock the internal
binding to exercise smaller chunks. No option, public argument, config field,
or durable identity input may tune the capacity.

Within each pulse the fold constructs at most one ordinary diagnostic block
from primitive vectors. That block preserves exact row order and is appended
to the writer in one operation. Numeric, integer, and POSIXct columns may use
`collapse::setv()` where supported. Character columns use base block
replacement so collapse 2.1.7 and 2.1.8 have identical behavior.

The writer must:

- retain the existing column names, storage types, missing-value forms, row
  order, diagnostic sequence, reason tokens, stages, outcomes, evidence, and
  metadata JSON;
- flush full chunks without `do.call(rbind, ...)` over scale-growing row
  lists;
- release a chunk only after its append succeeds;
- preserve committed prefixes across deliberate interruption and resume;
- roll back the active transaction and retain the existing single error row
  when an unexpected fold error occurs; and
- construct and write the post-rollback one-row error outside the ordinary
  block-writer path.

No sampling, coalescing, delayed reconstruction, or deletion of ordinary
decision evidence is authorized.

### 3.4 Resumed-run equity finalization

Finalization keeps the existing full achieved-prefix validator. Weakening that
validator to the final invocation is forbidden.

This repair applies only to availability-aware runs for which finalization
uses fold-supplied equity facts and the current invocation does not itself
cover the complete achieved prefix. Before replacing `equity_curve`, that
path reads the run's committed prior equity rows and combines them with the
current invocation's `eq_df` using `(run_id, ts_utc)` as the key:

1. timestamps must belong to the intended pulse calendar;
2. duplicate keys are permitted only when every non-key value is identical;
3. identical duplicates collapse to one row;
4. conflicting duplicates, missing pulses, extra pulses, or non-monotone
   ordering fail closed before terminal status changes;
5. the merged rows must equal the exact calendar prefix through
   `achieved_end_utc`; and
6. deletion, merged append, and terminal status update occur in one DuckDB
   transaction so failure restores the prior committed prefix.

The resulting `DONE` and `INCOMPLETE` runs must reopen through the ordinary
terminal-evidence validator. Dense runs continue to recompute their complete
curve from events and the full pulse calendar and do not enter this merge or
its new conflict rule. This repair changes no equity formula, event replay,
completion schema, stop reason, or run identity.

### 3.5 Seal-time conflict validation

Production membership, status, and lifetime conflict validation replaces the
full nested pair loops with grouped state-aware sweeps. Status uses a
pairwise-exact exception for rows involved in supersession links.

For membership:

- group by `(instrument_id, universe_id)`;
- sort deterministically by `effective_from`, `effective_to`, state, and stable
  fact identity;
- maintain a running maximum end separately for `member = TRUE` and
  `member = FALSE`; and
- report a conflict when a row begins before the opposing state's running
  maximum end.

For status:

- group by `(instrument_id, source, precedence)`;
- classify as supersession-involved every row that either names a direct
  predecessor or is named as one;
- validate uninvolved rows with the ordinary per-status running-maximum sweep;
- compare every unordered pair with at least one involved row under the
  current pair predicate; and
- exempt only a pair in which one row directly names the other. Any other
  overlapping pair with opposing statuses at the same source and precedence
  remains a conflict.

For lifetime:

- group by `instrument_id`;
- maintain a running maximum end per assertion value; and
- report overlap with an opposing assertion.

Membership and lifetime have no supersession exemption and therefore use the
plain running maximum per state. The status hybrid must return exactly the
same result as the retained pairwise reference for every row set; it may be
replaced by another subquadratic construction only if that equivalence remains
explicit and tested.

All three preserve half-open intervals, touching endpoints as non-overlap,
nested and equal intervals, open ends as infinity, stable tie behavior, current
condition classes, and current error messages unless a test demonstrates that
only nondeterministic row order differs.

Set-backed membership rows may bypass the opposing-state sweep only after one
setwise validation proves all of the following:

- every persisted set row has `member = TRUE`;
- every row references a valid header in its universe;
- header and row scope, set identity, interval, and snapshot invariants hold;
  and
- no interval-assertion family is silently mixed into the bypass.

The database does not enforce these implications, so `set_id` alone is never
sufficient. The existing supersession-reference and acyclicity checks remain
in force and are not broadened into this optimization.

### 3.6 Dependency and telemetry posture

The package declares no new collapse version floor. The production path must
pass its parity suite under both collapse 2.1.7 and 2.1.8. No package behavior
may depend on caller options that alter collapse execution.

Existing persisted and public telemetry names remain unchanged. Profiling may
group provider, diagnostic construction, diagnostic append, valuation, and
residual work in internal closeout reports, but v0.2.0.1 adds no schema column,
hash input, public telemetry API, or durable lane name solely for this cycle.

### 3.7 Benchmark clocks and standard peer workload

The availability closeout and peer closeout answer different questions and
must remain separate.

The availability fixture is the reviewed 563-instrument, 505-member-axis,
757-pulse population with 60 complete membership lists, complete bars, flat
targets, zero holdings, and no fills. Its warm clock surrounds the reusable
snapshot's experiment setup, `ledgr_run()`, and required result surface. Its
cold clock surrounds source preparation through sealing and is recorded once.

The peer record uses the existing daily SMA crossover workflow at explicit
standard dimensions:

```text
500 instruments x 1,260 sessions
fast SMA 5, slow SMA 10, seed 20260530
```

The release command pins every workload parameter and engine set explicitly;
changing the `record` preset defaults is outside this packet:

```powershell
Rscript dev/bench/peer_benchmark/peer_benchmark.R `
  --preset record --release v0.2.0.1 --engine-set all `
  --n-inst 500 --n-days 1260 --fast 5 --slow 10 --seed 20260530
```

Before that run, the harness splits its current ingestion phase into at least:

```text
snapshot_prepare_sec
experiment_setup_sec
engine_sec
results_sec
```

and reports:

```text
cold_end_to_end = snapshot_prepare + experiment_setup + engine + results
warm_research_iteration = experiment_setup + engine + results
```

The split is defined per engine. When an engine cannot expose a phase, its
field is unavailable rather than estimated. Provider construction belongs to
warm experiment setup because it is rebuilt per experiment. Reusable data
ingest or bundle construction belongs to cold snapshot preparation.

The required peer rows are canonical durable ledgr, canonical memory-backed
ledgr, ledgr built-in SMA, quantstrat, Backtrader, zipline-reloaded, and local
LEAN when installed. A missing optional peer remains `UNAVAILABLE` with its
reason. No hosted LEAN service is purchased. The existing B2 row may be run as
an explicitly labelled sidecar but is not required and cannot stand in for
canonical R ledgr.

## 4. Acceptance Matrices

### 4.1 Hot-path semantic and persistence matrix

| Surface | Required evidence before old path removal | Durable release evidence |
| --- | --- | --- |
| Provider-only views | 3,676 shuffled and repeated semantic/interval cutoffs identical arm to arm; 602 membership cutoffs agree with `ledgr_facts_resolve()` | focused package tests over changing lists, status, lifetime, terminal events, backward re-seek, repeated cutoffs, and a declared status family with zero persisted rows |
| Fold scenarios | all seven reviewed scenarios identical for diagnostics, events, equity, strategy state, completion, and status | ported deterministic scenario tests with frozen expected rows |
| Full 757-pulse fold | all six persisted tables equal by DuckDB multiset difference under one shared run ID | one production closeout pair before the reference arm is retired |
| Writer | byte-exact deterministic fixture, case, and diagnostic files; direct and chunk-boundary cases | tests at 7-row and 4,096-row chunks plus multi-chunk flush |
| Rollback and resume | committed prefix plus exactly one error row, continuous sequence, no partial active block | injected append failure, fold failure, deliberate interrupt/resume, and resume-then-error tests |
| Mechanism | prepared provider and block writer observed on every relevant call; no fallback | source guard proving no spike option, arm stamp, row-list bind, `ledgr_availability_provider_build_current()`, its per-pulse view assembly, or unused status/lifetime/terminal resolver remains; retained public inspection helpers are not called by provider consumers |

The full persisted comparison covers diagnostics, events, equity, strategy
state, completion, and the runs identity row. It excludes exactly:

- top-level `created_at_utc`;
- `config_json.db_path`; and
- `config_json.data.snapshot_db_path`.

Run IDs at both levels, `archived_at_utc`, `config_hash`, and every other field
are compared.

### 4.2 Seal-validator matrix

The production sweep and retained test-only pairwise references must agree on
at least 2,000 deterministic randomized row sets plus explicit adversarial
cases for:

- no rows and one row;
- same-state overlap;
- opposing-state overlap;
- touching half-open endpoints;
- nested and equal intervals;
- finite and open ends;
- multiple instruments and universes;
- status source and precedence separation;
- direct supersession exemptions and non-exempt conflicts;
- `X(A,[0,10))`, `Y(A,[0,20))`, and `J(B,[15,...))`, where `J`
  directly supersedes `Y` and `X` is unlinked: no conflict, because the only
  overlap with `J` is the exempt pair;
- `Y(A,[0,20))` and unlinked `Z(B,[5,...))`, where `Y` also participates in a
  direct supersession link with another row: conflict, because involvement in
  one exempt pair does not exempt `Y` from `Z`;
- lifetime's three assertion states; and
- shuffled input order and stable error classification.

Set-backed bypass tests mutate each required invariant independently and in
combination. Any malformed set row must fail or enter the general validator;
it must never be silently exempted.

### 4.3 Finalization matrix

Required cases:

- uninterrupted `DONE`;
- interrupted then resumed to `DONE`;
- interrupted then resumed to a controlled `INCOMPLETE` terminal outcome;
- a dense interrupted-then-resumed run that preserves the existing full-curve
  recomputation path and never enters the availability prefix merge;
- resume then unexpected error with the prior prefix still committed;
- identical overlap at the resume boundary;
- conflicting overlap, missing pulse, duplicate pulse, extra pulse, and
  out-of-calendar pulse; and
- successful ordinary reopen and result extraction after each valid terminal
  case.

Every invalid merge fails before terminal status changes and leaves the prior
committed equity rows recoverable.

### 4.4 Identity and compatibility matrix

- no schema version change in fresh or reopened stores;
- v0.2.0.0 snapshot and experiment fixtures reopen under v0.2.0.1;
- unchanged configs retain their existing hashes;
- direct, durable, memory-backed, resumed, and sequential sweep paths preserve
  semantic parity where v0.2.0.0 claims it;
- optional mirai coverage, when installed, observes the production provider
  without option propagation;
- collapse 2.1.7 and 2.1.8 produce identical compared outputs; and
- compiled availability combinations keep their current classed rejection.

## 5. Module Boundaries

| Area | Primary implementation home | Constraint |
| --- | --- | --- |
| Provider compilation and queries | `R/availability-provider.R`, `R/availability-provider-prepared.R` or a renamed production successor | one build per consumer boundary; no per-pulse fact-frame scan |
| Diagnostic columns and blocks | `R/availability-diagnostic-writer.R`, `R/fold-engine.R` | ordinary block path only; error-row path stays distinct |
| Durable output transaction | existing output-handler and fold ownership | no second transaction owner or execution engine |
| Seal validators | `R/availability-facts.R`, `R/availability-persistence.R` | exact pairwise semantics, grouped sweep implementation |
| Finalization repair | `R/run-finalize.R` | atomic complete-prefix merge; validator stays strict |
| Public fact reference | `R/availability-inspection.R` plus retained membership resolver/evidence helpers | `ledgr_facts_resolve()` and `ledgr_facts_history()` unchanged; no provider consumer calls this path |
| Result/reopen provider consumers | availability result view and `ledgr_run_open()` INCOMPLETE validation | one prepared build per call, no persisted cache; explanation reuses the result view |
| Benchmark phases | `dev/bench/peer_benchmark/` | explicit cold/warm components and canonical outputs |
| Documentation | maintainer manuals, dev benchmark report, design indexes | internal claims only; source anchors refreshed after code settles |

Files may be split for bounded ownership, but behavior may not move to a
second fold, output, validation, or persistence pipeline.

## 6. Dependency Order And Review Stops

Ticket cut may subdivide these workstreams but must preserve the order and
independent review stops. This table is sequencing, not a ticket list.

| Stage | Work | Exit evidence before the next dependent stage |
| --- | --- | --- |
| A | Packet acceptance and baseline inventory | reviewed spec, exact baseline, no fabricated test pass |
| B | Port spike witnesses and retain test-only references | deterministic fixtures and checkers run against baseline |
| C | Productionize prepared provider | provider-only parity, fold scenario parity, result/reopen parity; independent review |
| D | Productionize diagnostic writer and block | chunk, rollback, resume, full-table parity, collapse-version coverage; independent review |
| E | Repair resumed-run finalization | complete-prefix matrix and reopen tests; independent correctness review |
| F | Replace the three conflict validators | randomized/adversarial equivalence and setwise-bypass mutation tests; independent review |
| G | Update benchmark phases and internal manuals | clock reconciliation, rendered manuals, refreshed source anchors |
| H | Release closeout | full suite/check, availability warm/cold records, peer record, final audit and release evidence |

Stages C and D may be implemented in either order after B, but both must close
before the full 757-pulse production parity record. E and F are logically
independent of the warm seams but both are release prerequisites. Benchmark
numbers cannot unlock a failed correctness stage.

## 7. Measurement And Closeout Rules

### 7.1 Availability warm record

Before retiring the old paths, run the final two-arm comparison on one quiet
host and in one measurement session: one warm-up and at least three measured
runs per arm over the registered 757-pulse fixture. Record its exact evidence
prefix. The production candidate must be faster than that same-session
reference by more than the reference's run-to-run spread. If the host is not
comparable to the reviewed block spike, this paired local record remains the
relative criterion; unrelated clocks are never compared.

At release closeout, after reference retirement, run one warm-up and at least
three quiet-host measured runs of the production path. Record median and
spread for wall around the warm experiment and externally sampled peak working
set. Stage H must use a host comparable to the reviewed block spike; otherwise
the gate remains open. The production median must be at most 60 seconds and
every measured peak at most 1,024 MiB. Cite the pre-retirement pair by exact
prefix as comparison context; do not restore or rerun the retired installed
path merely to manufacture a stage-H reference.

The closeout reports fixture shape, source commit, R and dependency versions,
host metadata, warm-up count, repetitions, median, spread, peak, parity status,
and the largest profiled lane. The reviewed 24.93-second result is context, not
a promised release number.

### 7.2 Cold seal record

Run the registered full seal once without the profiler and, if attribution is
needed, a separate profiled or sampled run. Record phase times and peak working
set. The seal must complete and the pairwise conflict validator must be absent
from production execution.

The earlier 60-to-90-second estimate is a forecast, not a release threshold.
The closeout may report the measured result but may not claim an unmeasured
factor or hide source preparation, validation, hashing, or persistence time.

### 7.3 Peer record

Run the explicit 500 by 1,260 command from Section 3.7 after the package code,
phase split, and semantic checks are final. For every engine:

- record status and environment;
- reconcile phase totals with full row wall;
- compare canonical equity, fills, and trades to durable ledgr before timing is
  interpreted;
- classify the first divergence when full parity is impossible; and
- retain unavailable peers as unavailable.

Generated raw records remain under ignored `dev/bench/results/`. The tracked
closeout cites the exact record prefix and summarizes only the evidence needed
for release review. It does not silently overwrite historical rows or present
the record as a general-purpose ranking.

### 7.4 Permitted release claims

Permitted:

- v0.2.0.1 removes measured scale-growing R work from the named availability
  paths while preserving reviewed outputs;
- snapshot construction is a separately reported cost paid when data changes;
  and
- repeated experiments over one unchanged sealed snapshot use the warm clock.

Not permitted without a later reviewed claim packet:

- a universal ledgr runtime;
- peer superiority;
- LEAN, Nautilus, Zipline, Backtrader, or quantstrat equivalence beyond the
  exact canonical surfaces checked here;
- the warm flat-fixture result as an eventful strategy result; or
- the seal forecast as achieved performance.

## 8. Documentation And Governance Closeout

After production source settles:

- update `optimization_coding_style.qmd` and its rendered Markdown so the
  evidence table contains the completed block result, valuation is the next
  measured lane, the per-pulse block is the fold-side replacement for one-row
  frames, and every source anchor resolves to production code;
- update `benchmark_methodology.qmd` and its rendering for the four peer phase
  fields and the final warm/cold interpretation;
- update the peer README and tracked report with the exact closeout command,
  record prefix, environment, parity status, and explicit non-ranking language;
- update `AGENTS.md`, the design index, roadmap, horizon promotion state, NEWS,
  and package version only when the packet reaches their corresponding stage;
  and
- preserve the RFC and spike artifacts as historical evidence. Do not rewrite
  their recorded clocks after productionization.

The optimization style article remains internal maintainer documentation, not
a public contract or pkgdown article.

## 9. Release Gate

Release requires all of the following:

1. every Section 4 matrix is represented by durable tests or a named closeout
   artifact, with no skipped required case;
2. the old full provider, row-list diagnostic writer, scalar per-row
   diagnostic construction, and all spike-selection options are absent from
   installed package code, while the public inspection resolver remains;
3. snapshot and experiment schemas and identity formats are unchanged;
4. the complete package test suite passes with zero failures and warnings, and
   any skip is named and justified;
5. source build and `R CMD check --no-manual --no-build-vignettes` report
   `Status: OK`;
6. the relevant suite passes under collapse 2.1.7 and 2.1.8 without changing
   the package dependency floor;
7. the availability warm record, cold seal record, and peer record exist and
   are cited by exact local record prefix in the release closeout;
8. documentation is rendered, source anchors resolve, and generated benchmark
   results, temporary stores, `Rplots.pdf`, tarballs, and check directories are
   absent from the commit;
9. an independent reviewer has reviewed each named correctness or parity stop;
   and
10. ticket Markdown, YAML, batch plan, spec, indexes, and release closeout agree
    once those later packet artifacts exist.

No numeric benchmark improvement can waive gates 1 through 6.

## 10. Spec Review And Ticket-Cut Rule

Independent spec review must answer:

1. Does the draft implement every accepted synthesis and maintainer decision
   without importing valuation, crypto, compiled, or broad audit work?
2. Are the provider, diagnostic, seal, and finalization mechanisms described
   accurately enough that two implementers would build compatible behavior?
3. Are all semantic and persistence gates capable of failing, including
   fallback detection, setwise-bypass mutations, and resumed-run corruption?
4. Are the three exact persisted-field exclusions sufficient and no broader
   identity exception implied?
5. Do cold, warm, and peer clocks form an honest apples-to-apples record, with
   the peer benchmark explicitly unable to prove availability performance?
6. Are dependency, migration, backward-compatibility, and public-claim
   boundaries complete?

The reviewer returns either `READY_TO_CUT_TICKETS` or `REVISE_SPEC_FIRST` with
findings ordered by severity. Only maintainer acceptance after that review may
create:

- `v0_2_0_1_tickets.md`;
- `tickets.yml`;
- `batch_plan.md`; or
- implementation status claims.

This draft creates none of them.
