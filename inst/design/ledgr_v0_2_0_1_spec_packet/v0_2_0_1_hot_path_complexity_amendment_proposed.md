# Proposed amendment: remaining release hot paths

**Target:** accepted ledgr v0.2.0.1 spec.
**Status:** Accepted by the maintainer 2026-09-17 after independent review and
focused re-review. Cut as LDG-2736 through LDG-2740 in Batches 8 and 9, with
final measurements in Batch 10 and the release gate in Batch 11; binding
alongside the accepted v0.2.0.1 spec.
**Date:** 2026-09-17.
**Baseline:** `6b09a1b57ff42293091130d2dca565f224a29aea`, the source used by
the accepted bounded complexity audit and the provisional Batch 8 records.
**Evidence:**
`dev/spikes/v0_2_0_1_hot_path_complexity_audit/findings.md`, its raw CSVs,
inventory, probe, checker, and the independent inline acceptance review.

The accepted v0.2.0.1 implementation removed the provider, diagnostic, and
seal-validation discontinuities it set out to remove. Its first release-scale
records then exposed two remaining costs that make the current closeout
unacceptable: quadratic event-buffer writes on the eventful peer workload and
repeated price-history scans in availability valuation. Both mechanisms are
inside the already registered release workloads and both are material there.

This amendment binds the smallest correction. It does not turn the bounded
audit into a package-wide optimization mandate. The current Batch 8 records
are provisional diagnostic evidence, not release evidence. Release closeout
resumes only after the two corrections pass their own review stops and all
records have been regenerated from accepted final source.

## 1. Authority and narrow supersession

The accepted v0.2.0.1 spec remains binding except where this amendment says
otherwise. On acceptance, this document supersedes only these clauses:

| Existing clause | Amendment |
| --- | --- |
| Section 2.2 scope | add the memory and durable event-buffer write paths and fold-time availability valuation |
| Section 2.3 first bullet | valuation remains out of scope except for the exact fold-time correction in Section 4 |
| Section 2.3 third bullet | event-buffer work remains out of scope except for the exact memory and durable corrections in Section 3 |
| Section 3.6 and Section 4.4 collapse rule | replace dual 2.1.7/2.1.8 support with the 2.1.8 minimum in Section 2 |
| Section 6 sequencing | insert the two reviewed implementation stages in Section 7 before release closeout |
| Sections 7.1, 7.3, and 9.7 records | make the current Batch 8 records provisional and require final-source reruns |
| Section 8 optimization-manual wording | replace "valuation is the next measured lane" with the evidence rule in Section 8 |
| Section 9.6 release gate | require resolution and testing under collapse 2.1.8 or later; remove the 2.1.7 gate |

All public and durable compatibility rules in the accepted spec continue to
apply. In particular, this amendment changes no public function, schema,
canonical JSON, snapshot hash, config hash, run identity, event identity,
availability policy, accounting policy, transaction owner, or execution
engine.

## 2. Dependency floor and implementation choice

The package dependency becomes `collapse (>= 2.1.8)`. Collapse 2.1.8 fixes
the generational write-barrier behavior for character and list writes through
`setv()` and `copyv()`. Supporting 2.1.7 would retain the exact constraint that
caused the character and list columns to use scale-growing base replacement.
The old floor is therefore retired rather than carried as a compatibility
goal.

The shipping event-buffer implementation uses the corrected by-reference
write operation for character and list columns as well as the already
by-reference numeric, integer, and timestamp columns. It must operate on
buffer-owned storage and preserve the current geometric capacity growth.

Before production retirement, one bounded implementation-choice check compares
this route with a temporary unbind/mutate/rebind control on both event
handlers. The control exists only to test the accepted audit's alternative; it
is never installed, exposed, selected by an option, or retained in package
source. The direct route does not remove and restore buffer bindings; the
source guard in Section 6 enforces that property. It may ship only when it:

1. passes exact semantic and persisted-output parity;
2. passes repeated allocation, garbage-collection, and forced-GC stress;
3. has median eventful wall no more than 1.20 times the temporary control on
   each handler at the registered 500 by 1,260 shape.

If the direct route fails any condition, implementation stops and this
amendment returns for revision. The implementer may not silently ship the
control, retain a dual path, weaken parity, or restore collapse 2.1.7 support.

Older installed ledgr artifacts and persisted stores remain valid data. An
environment with collapse below 2.1.8 fails normal package dependency
resolution; ledgr adds no runtime fallback or bespoke version branch.

## 3. Linear memory and durable event buffers

The correction covers both ordinary event handlers:

- the memory handler's sixteen typed columns, including its six character and
  one list column; and
- the durable handler's event buffer, including its six character columns.

Appending one event must mutate owned, preallocated typed storage by index.
Capacity may grow geometrically, but no append may extract, scalar-replace,
and reassign a column whose current capacity grows with event count. Total
buffer construction must be amortized `O(E)` for `E` events, excluding the
semantically required downstream accounting work.

The production path is singular. No option, environment variable, arm stamp,
second output handler, or retained old writer may select the quadratic path.
The memory and durable handlers may share a private primitive, but they retain
their existing transaction, flush, rollback, and ownership boundaries.

### 3.1 Event semantic and failure matrix

Before the old writes are removed, current and candidate arms run under the
same deterministic inputs. Required comparisons include:

- the complete ordered event surface, including IDs, sequence, timestamps,
  event type, instrument, side, quantity, price, fee, cash delta, position
  delta, realized value, cost basis, `meta_json`, and parsed list metadata;
- fills, trades, final cash, positions, equity, strategy state, completion,
  diagnostics, and existing telemetry;
- opens, closes, reversals, repeated same-side targets, no-op targets, the
  final-bar no-fill boundary, non-zero fees, and non-zero slippage;
- capacity boundaries immediately before, at, and after growth, including at
  least two growth events and a deliberately small injected private capacity;
- ordinary completion, controlled stop, unexpected error, output append
  failure, deliberate interruption, resume to `DONE`, and resume then error;
- memory and durable result parity at their existing common surfaces; and
- durable close, reopen, and result extraction.

Compared values are exact unless an existing contract already specifies a
numeric tolerance. Row order and identity-bearing values are never normalized
away. Error-path checks prove no partial active event is visible and the prior
committed prefix remains recoverable.

### 3.2 Event scaling gate

Use the registered peer workload shape: SMA 5/10, 1,260 sessions, seed
20260530, zero costs for the scaling curve, and stable subsets at 50, 100,
200, 350, and 500 instruments. Record both memory and durable handlers.

The pre-retirement comparison runs on one quiet host and in one measurement
session. It records one warm-up and at least three measured runs for each arm
at 500 instruments, plus at least one diagnostic run at every smaller point.
The candidate passes only when, for each handler:

- its 500-instrument median engine wall is at most 0.60 times the current
  arm's same-session median;
- microseconds per fill at 500 instruments is no more than 1.35 times the
  minimum at 100, 200, 350, and 500 instruments;
- fill count and final equity reconcile at every point; and
- externally sampled peak working set is recorded and does not exceed the
  current arm's same-session maximum by more than 15 percent.

The earlier 25.05-second memory and 49.37-second durable scratch observations
are feasibility evidence only. They are not acceptance results and are not
substituted for this paired record.

## 4. Prepared fold-time availability valuation

The fold currently resolves each mark by matching an instrument to its source
row and rescanning that row's complete price prefix at every pulse. Across
`N` instruments and `P` pulses this performs
`O(N*P^2 + N^2*P)` work for `N*P` outputs.

The production correction prepares transient primitive valuation state once
per run:

- one instrument-to-source-row index;
- the last finite close for each source row;
- its source pulse or timestamp; and
- the age used by the existing staleness policy.

The state advances monotonically once per fold pulse and emits marks for the
current availability axis by indexed lookup. It performs no per-instrument
`match()` against the full source vector and no `seq_len(pulse_idx)` prefix
scan. Total fold-time valuation work is `O(N*P)` after bounded preparation.

This state belongs to one run invocation. It is not persisted, cached between
runs, hashed, exposed publicly, transferred as a new worker contract, or used
to change snapshot or run identity. It changes neither the bars matrix nor the
prepared availability provider. Dense runs remain on their existing path.

The normal fold supplies nondecreasing pulses. If an internal call violates
that invariant, the valuation state fails closed rather than returning a value
from the wrong cursor position. This amendment does not create a public random
access valuation cursor.

### 4.1 Valuation semantic matrix

The current function remains as a temporary test oracle until the following
arm-to-arm cases pass, then is removed from the installed path:

- never-observed and currently observed instruments;
- leading, interior, and trailing price gaps;
- the exact fresh/stale boundary and one pulse on each side;
- expired and re-entering members;
- held former members and names outside the current strategy axis that remain
  necessary for portfolio valuation;
- terminal events before, at, and after the current pulse;
- a complete-list membership change and an interval-assertion change;
- ordinary completion and the controlled-stop boundary; and
- direct, memory-backed, durable, interrupted/resumed, and reopened results at
  every existing common surface.

The comparison includes full valuation views, diagnostic reason and stage
tokens, equity, completion, events, strategy state, and terminal evidence.
Expected gaps remain missing; they are never imputed to zero or to a future
observation.

### 4.2 Valuation scaling gate

The gate has both structural and measured parts.

The structural test instruments the implementation and proves that increasing
pulse count does not increase work per emitted instrument-pulse through a
hidden prefix scan, and increasing source-instrument count does not reintroduce
linear matching per axis member. It exercises at least three pulse counts and
three source-instrument counts, including the registered 563-source,
505-member, 757-pulse shape.

The measured comparison uses the registered zero-fill availability fixture on
one quiet host, with the already accepted provider and diagnostic paths held
constant. Run one warm-up and at least three measured runs per arm. The
candidate passes only when:

- the median of its recorded `wall_seconds` is at most 0.80 times the current
  arm's same-session median `wall_seconds`;
- the improvement exceeds the current arm's full measured spread;
- every measured peak working set is no more than 1,024 MiB and no more than
  15 percent above the current arm's same-session maximum; and
- the full semantic matrix remains exact.

The provisional 25.42-second warm record and its 67.7-percent sampled
valuation share explain why the work entered scope. They are not a forecast of
the corrected result and do not satisfy this gate. The 0.80 ratio is based on
the measured lane budget: removing all 7.12 attributed valuation seconds from
the 25.42-second wall would yield about 18.30 seconds, or 0.72 of the current
wall. The gate therefore permits bounded residual valuation cost while still
rejecting an unchanged path.

## 5. Combined correction case

A deterministic eventful availability case exercises both corrections in the
same shared fold. It must produce non-zero fills, cross at least one event
buffer capacity boundary, include non-zero transaction cost, change complete
membership, hold at least one former member, include a price gap that reaches
the stale boundary, and include one terminal event.

The current and candidate paths must agree on every surface named in Sections
3.1 and 4.1. This is a correctness fixture, not a new peer benchmark. It may be
bounded to the smallest shape that exercises every required transition.

## 6. Compatibility and source guards

Durable tests and a source guard must jointly prove:

- the DESCRIPTION floor is collapse 2.1.8 or later;
- no 2.1.7 compatibility branch or event-write fallback exists;
- no temporary unbind control, implementation option, arm stamp, or old
  extract/mutate/reassign writer remains in installed source;
- fold-time availability valuation contains neither repeated full-vector
  instrument matching nor growing price-prefix scans;
- the prepared valuation state is transient and absent from schemas, hashes,
  identities, serialized configs, and public return values;
- old v0.2.0.0 snapshots and experiment stores reopen without migration; and
- canonical R execution remains the default and availability-aware compiled
  spot-FIFO remains rejected as before.

The full package suite and source-package check run only after the focused
matrices pass. Required tests may not be skipped because a package or optional
peer is missing. Optional peer unavailability remains reported, not converted
to success.

## 7. Sequencing and review stops

After maintainer acceptance, ticket cut inserts these stages before the
existing release closeout. This document does not allocate ticket IDs or edit
the current ticket and batch artifacts.

| Stage | Work | Exit evidence |
| --- | --- | --- |
| H | Freeze current-arm oracles; raise the collapse floor; linearize both event handlers | Section 3 matrix, implementation-choice check, paired scaling record, source guard, independent code review |
| I | Prepare fold-time valuation state | Section 4 matrix, structural scaling proof, paired 757-pulse record, independent code review |
| J | Measure accepted final source and stop for a benchmark decision | Final availability and peer records, final profiler, independent evidence review, explicit maintainer go-ahead |
| K | Run the release gate and close the packet | Full suite/check, documentation and governance reconciliation, release closeout |

Current tail tickets remain incomplete. Ticket cut must move their release
evidence behind Stages H and I and give every new matrix and performance gate
one accountable owner. Event-buffer and valuation work have separate review
stops; success in one cannot waive failure in the other. Stage J is a distinct
measurement checkpoint. Stage K remains unauthorized until the Stage J records
are independently reviewed and the maintainer explicitly elects to proceed.

The old implementations may exist only long enough to capture their paired
oracles. They are removed before Stage J. The implementation commit that
removes each oracle must be later than, and cite, the exact accepted evidence
prefix that used it.

## 8. Closeout, documentation, and claims

The provisional Batch 8 availability and peer records at baseline `6b09a1b`
must not be promoted as v0.2.0.1 closeout evidence. They may be retained as
diagnostic history. Stage J creates new record prefixes from accepted final
source and reruns:

1. the availability cold and warm record;
2. the exact 500 by 1,260 peer command;
3. the final profiler.

Stage J then stops. Its records are independently reviewed and presented to
the maintainer as the empirical result of the release work. Stage K may begin
only after explicit maintainer approval and then runs:

4. the full package suite and source-package check; and
5. documentation rendering and record reconciliation.

The closeout must distinguish the zero-fill availability clock from the
eventful peer clock. It reports phase boundaries, repetitions, spread, peak
working set, environment, source commit, parity status, and optional-peer
availability. A peer's weak-tolerance match, divergence, or unavailable state
is reported literally. Zero divergence does not become a percentage claim
whose denominator is zero. No record is presented as a general ranking.

The optimization manual is corrected to say that the next material lane is
workload-dependent: valuation dominated the zero-fill availability record,
while event writes dominated the eventful peer regression. After the fixes it
records achieved results rather than leaving either lane named as future work.
Source anchors are refreshed only after production code settles.

Permitted additional release claim:

> v0.2.0.1 removes the two additional scale-growing mechanisms established by
> the accepted closeout complexity audit, with exact output parity and paired
> release-shape measurements.

This claim is permitted only if every gate in this amendment passes. It does
not authorize a universal runtime, a peer-speed ranking, or a claim about
compiled execution.

## 9. Explicit non-goals and later work

This amendment does not authorize:

- general loop or data-frame cleanup;
- FIFO lot-accounting or compiled lot-packing changes;
- strict feature-window hydration changes;
- dense finalization or discarded availability-finalization work;
- terminal recovery, result-reader, or execution-time evidence-join changes;
- provider, diagnostic, seal-validator, or resumed-equity redesign;
- a new cache, schema, hash, identity field, public option, or telemetry name;
- compiled availability execution, crypto work, parallel architecture work,
  or the Docker benchmark laboratory; or
- changes to peer workload defaults or public performance rankings.

The accepted audit's later findings are recorded in the roadmap or horizon at
Stage J as profile-triggered candidates. They do not become tickets merely
because their asymptotic shapes are known.

## 10. Amendment acceptance and release gates

Independent amendment review must answer:

1. Does the document add exactly the two accepted release-material findings
   without importing the audit's later work?
2. Is collapse 2.1.8 a real minimum with no 2.1.7 fallback, and is the direct
   event-write choice falsifiable before it ships?
3. Do the event matrices cover identity, metadata, failures, transaction
   boundaries, resume, reopen, both handlers, and capacity growth?
4. Does valuation preparation remove both repeated matching and prefix
   rescanning while preserving every gap, stale, membership, holding, and
   terminal boundary?
5. Are all performance comparisons paired, quiet-host, same-session, and
   incapable of being passed by an unchanged or merely faster wrong path?
6. Are the existing Batch 8 records unambiguously provisional and all final
   claims deferred to fresh accepted-source records?
7. Do compatibility, non-goal, sequencing, and ticket-cut boundaries remain
   consistent with the accepted v0.2.0.1 packet?

The reviewer returns either `READY_FOR_MAINTAINER_ACCEPTANCE` or
`REVISE_AMENDMENT_FIRST`, with findings ordered by severity. Review alone does
not change the accepted spec. Only explicit maintainer acceptance authorizes a
ticket and batch-plan amendment.

Release requires all accepted-spec gates plus all of the following:

1. the dependency floor, event path, and valuation path satisfy Sections 2-6;
2. both independent implementation reviews pass;
3. the combined eventful availability case passes;
4. no superseded implementation or test-only selection mechanism ships;
5. final-source availability and peer records replace the provisional closeout
   references; and
6. the benchmark checkpoint is independently accepted and the maintainer has
   explicitly authorized the release gate; and
7. spec, amendment, tickets, YAML, batch plan, manuals, governance documents,
   NEWS, and release closeout agree.

No numeric improvement waives semantic, persistence, identity, rollback,
resume, reopen, dependency, or source-removal gates.

## 11. Source basis and revision record

Source basis:

- accepted ledgr v0.2.0.1 spec and completed Batches 0 through 7;
- provisional Batch 8 records at `6b09a1b`;
- accepted bounded audit under
  `dev/spikes/v0_2_0_1_hot_path_complexity_audit/`;
- collapse 2.1.8 dependency evidence and the audit's measured temporary
  unbind-control observations; and
- `inst/design/contracts.md`, `inst/design/spike_protocol.md`,
  `inst/design/manual/optimization_coding_style.qmd`, and
  `inst/design/manual/benchmark_methodology.qmd`.

Revision record:

- **2026-09-17:** initial proposed amendment. No implementation, ticket,
  packet-status, benchmark-report, roadmap, horizon, NEWS, or index change is
  authorized or claimed.
- **2026-09-17:** focused review correction. Bound the valuation comparison to
  `wall_seconds`, changed its impossible 0.70 ratio to 0.80 using the measured
  lane budget, moved the no-unbind property to the source guard, and removed a
  redundant event-spread condition.
- **2026-09-17:** accepted by the maintainer after the focused re-review
  returned `READY_FOR_MAINTAINER_ACCEPTANCE`; cut as LDG-2736 through LDG-2740
  without starting implementation.
- **2026-09-17:** maintainer sequencing clarification. Split final-source
  measurements into Stage J with an independent review and explicit go-ahead;
  moved release-gate and closeout work into Stage K.
