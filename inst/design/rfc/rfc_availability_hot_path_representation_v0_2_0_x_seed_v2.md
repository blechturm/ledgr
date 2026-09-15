# RFC Seed v2: Availability Hot-Path Representation

**Status:** Seed v2; non-binding. Supersedes Seed v1 for further deliberation.

**Release destination:** Unassigned. The historical filename does not select a patch or minor release.

**Author:** Codex, returning after independent Response, Response Review, and lane profiling.

**Next step:** a different author may write the one-question spike charter; this Seed does not.

## 1. Question

How should ledgr preserve complete point-in-time availability semantics and
durable decision evidence without retaining a list containing one data frame
per scale-growing diagnostic cell?

This is a representation question, not an availability-policy change. Every accepted
decision, restriction, fill, no-fill, stop, completion, reopen, and explanation remains binding.

This RFC uses "first correction" for the first implementation of this
representation change. It does not mean ledgr v1.0.0 or assign a release.

## 2. What The Cycle Has Established

### 2.1 The current mechanism

The current availability fold:

- constructs one 22-column data frame per diagnostic row
  (`R/availability-economics.R:386-432`);
- retains those frames in a scale-growing list
  (`R/fold-engine.R:318-327`);
- appends one decision row per pulse-axis cell
  (`R/fold-engine.R:611-654`);
- also appends one portfolio reconciliation row per pulse; and
- binds the complete list with `do.call(rbind, diagnostic_rows)` before its
  single persistence call (`R/fold-engine.R:1082-1108`).

This repeats a representation shape already identified in ledgr's optimization
arc: primitive internal buffers, then one frame at a persistence or public
boundary, are preferred to per-row frames plus a final bind. The relevant
authority is the primitive-internals synthesis at lines 197-220 and the fold
hot-path audit at lines 53-61 and 232-247. The v0.1.8.9 packet separately binds
typed scale-growing buffers and safe per-row mutation at lines 72-88 and
129-143.

### 2.2 The mechanism probe

The first public probe called the production row constructor and final binder.
At 20,000 rows, the retained row list occupied 108.34 MiB and took 11.61 seconds
to construct plus 20.04 seconds to bind. One complete column-oriented frame was
3.16 MiB and exactly value-, type-, order-, and attribute-identical.

That alternative was a one-shot construction from already known vectors. It is
an attainable-bound clue, not a measurement of a live buffered writer. It did
not include scalar or block writes, live named-vector lookups, chunk flushing,
varying JSON payloads, transaction-buffer memory, or DuckDB append work.

### 2.3 The lane-profile prerequisite

The Response Review required one cheaper attribution question before Seed v2:

> Which lane dominates wall time and allocation pressure in the current
> availability-aware flat fold on a shortened, public, production-shaped
> synthetic fixture?

The executed fixture contained 563 instruments, a 505-member decision axis, 40
pulses, four complete membership lists, declared status and lifetime facts,
complete bars, zero holdings, and a flat strategy. Every measured run reached
`DONE` with 20,200 decision rows plus 40 reconciliation rows, zero execution
rows, zero fills, and zero actionable targets.

Its pre-registered result was `DIAGNOSTICS_DOMINANT`:

| Group | Median share of in-loop samples |
| --- | ---: |
| Diagnostics | 67.0% |
| Provider | 31.2% |
| Valuation | 1.0% |
| Residual fold | 0.8% |

Diagnostics led in all three runs by a median 35.8 percentage points. Final
`rbind` was the largest individual lane at 41.9%; row construction was 24.7%.
The deterministic replay of all 20,240 persisted rows took a median 12.05
seconds to construct and 20.29 seconds to bind, retaining 110.0 MiB for a
3.2 MiB result. An unprofiled reference `t_loop` was 49.47 seconds.

Windows `Rprof()` sampled only about 64% of `t_loop`. The separate replay agrees
with the lane ordering, but it is a cross-check rather than an exact partition
of production wall time. Positive Vcell-growth totals are allocation evidence,
not retained memory or process peak memory.

### 2.4 What is not established

The 40-pulse ordering must not be extrapolated to the external 757-pulse run.
The final bind grows faster than row count on the measured ladders, while
provider cost grows as applicable fact headers accumulate. The external run
remained `RUNNING` beyond its resource ceiling, but had no durable stage marker;
it does not prove whether the process was in the pulse loop, final bind, or
another phase when stopped.

The Response's proposed 5,960-second provider floor is invalid. Its 7.876-second
input combined one decision view with 505 per-target execution views, whereas
the flat control performs only one decision view per pulse and no per-target
execution views. Provider resolution remains material and second in the public
profile, but it is not established as the leading wall lane.

## 3. Existing Semantic Authority

The accepted availability synthesis, `contracts.md`, and v0.2.0.0 packet remain
authoritative. Active runs retain one decision trace per invoked axis ID plus
ordered risk, execution, reconciliation, stop, and error evidence. Deliberate
interruption appends on resume. Unexpected fold exceptions roll back the fold
transaction and write their error diagnostic only afterward. Reopen and
`ledgr_run_explain()` consume durable evidence without rerunning strategy code.

The correction may change internal construction and flush representation. It
may not change diagnostic schema, reason vocabulary, nullable meaning,
deterministic pulse/stage/axis order, accepted-prefix economics, terminal
status, or explanation results. Ordinary `decision_recorded` rows may not be
sampled, coalesced, reconstructed, or dropped for speed.

## 4. Proposed Direction

### 4.1 Replace row objects with bounded typed columns

The first correction should build diagnostics in typed atomic columns, use
vector or block assignment where the pulse already provides aligned values,
and manifest a data frame only at a bounded flush or public-result boundary.
It should never retain one data frame per diagnostic cell or call
`do.call(rbind, ...)` over that shape.

One plausible implementation family is a fold-owned or handler-owned columnar
buffer with explicit prototypes and bounded flushes through the existing output
handler. This is a direction for measurement, not a selected class, helper,
owner, chunk size, or growth policy.

Public diagnostics remain tibbles/data frames. DuckDB schemas remain unchanged.
The principle is boundary-only frame manifestation, not a package-wide ban on
data frames.

### 4.2 Preserve the transaction seam

The independent DuckDB primitive passed: two appends inside one transaction
observed starting sequences 1 and 4; a forced rollback left five committed rows
and next sequence 6. Current source also confirms `MAX + 1` renumbering at the
handler and exception evidence after fold rollback.

That primitive does not prove a ledgr writer. Any fork must expose whether
multiple in-transaction flushes preserve clean-versus-resumed equality,
continuous `diagnostic_seq`, exception ordering, and exactly-once final evidence
without a second write through `write_run_evidence()`.

### 4.3 Keep collapse optional at this stage

The first probe reran 70,000 dynamic character and list writes under exact
collapse 2.1.8 with repeated garbage collection and exact base-R parity. The
official 2.1.8 changelog records the missing generational write barrier in
`setv()` and `copyv()` as fixed. No new upstream issue is warranted.

This establishes eligibility to test `setv()`; it does not require it. A fork
may use vectorized base R, safe `collapse::setv()`, or both within its one
alternative. If the measured alternative depends on character or list `setv`,
the synthesis must decide whether to raise the package's unversioned collapse
dependency or keep those columns on another safe write path.

## 5. Proposed Subsequent Spike

This Seed proposes but does not charter the spike. A different author owns the
charter and must pass `spike_protocol.md` Sections 2, 4, and 8.

Exactly one question:

> Can one bounded columnar/chunked diagnostic writer replace the current
> list-of-one-row-data-frames path while preserving exact direct-run,
> interrupted/resumed, persisted, reopened, and explained evidence on the
> shared availability fold?

Cheaper prerequisite: the public lane profile above answered
`DIAGNOSTICS_DOMINANT` at its registered 40-pulse shape. The spike may therefore
test the diagnostic representation first without claiming full-scale dominance.

The comparison has only two arms:

1. current production code; and
2. one bounded columnar/chunked alternative.

The following are candidate review concerns, not frozen witnesses, expected
answers, a checker, or a charter written by this Seed author:

- exact diagnostic schema, values, row count, and authoritative order;
- continuous, exactly-once append behavior across interruption and resume;
- unchanged ledger events, fills, equity, strategy state, and completion;
- fresh-connection diagnostics and `ledgr_run_explain()` equality; and
- same-host wall and process peak-memory evidence with explicit boundaries.

The charter author starts with the smallest runnable fork. Failures generate no
more than ten initial cases under the protocol; this Seed does not pre-author
them. Structural fixture numbers never become a public ranking.

Kill and recharter condition: if the alternative removes diagnostic
construction and binding as the largest measured lane but an unchanged
production-shaped run still breaches its registered envelope, close the spike
without adding a third alternative. Use the new profile to open a separate
provider-resolution question.

## 6. Provider Work Remains Separate

The lane profile makes provider work visible rather than dismissing it. At the
measured shape it was 31.2% of in-loop samples. Status, lifetime, and terminal
resolution dominated that group; membership was only 1.7% with four identical
complete lists. Non-flat `execution_view()` work was deliberately absent.

The first writer spike must not redesign membership, status, lifetime,
valuation, or provider state. Once diagnostic row objects are removed, the
resulting profile decides whether a separate cycle should consider compiling
sparse facts into transient pulse-indexed primitive state. Sparse DuckDB facts
remain canonical; any expanded runtime planes would remain ephemeral.

## 7. Determinism And Safety

By-reference scalar writes are value-neutral mutation and do not invoke the
deterministic reduction wrapper. Value-bearing grouped or cumulative collapse
operations remain subject to `ledgr_with_collapse_deterministic()` and existing
byte/economic parity gates.

A flush may not make a failed pulse partially durable, move diagnostics outside
the fold/finalization failure boundary, relabel `RUNNING` or `INCOMPLETE`, or
duplicate rows on resume. Faster but missing, reordered, coalesced, or
reconstructed decision evidence fails.

## 8. Proposed Engineering Rule

Future fold-path work should inherit this rule after synthesis and maintainer
acceptance:

> Performance non-scope does not permit reintroducing an already-demonstrated
> scale-growing hot-path anti-pattern. New fold-owned collections use primitive
> or matrix state, bounded columnar buffers, vectorized operations, and
> boundary-only frame manifestation unless a production-shaped probe supports
> an explicit exception.

This proposed rule is supported by the primitive-internals synthesis, fold
hot-path audit, and v0.1.8.9-v0.1.8.10 implementation record. It does not turn
ordinary cold-path or public-boundary data frames into debt.

## 9. Non-Goals

- No availability, membership, lifetime, status, valuation, affordability,
  no-fill, terminal-event, or held-former-member policy change.
- No diagnostic retention tiers or deletion of ordinary evidence.
- No schema, public API, run identity, snapshot, experiment, or hash change
  unless the spike proves one unavoidable.
- No provider rewrite in the diagnostic-writer spike.
- No second engine, compiled fold, parallel pulse execution, or durable
  compiled integration.
- No Sharadar-specific implementation or licensed-data fixture.
- No broad package-wide collapse adoption or public speed claim.

## 10. Open Decisions

1. **Release destination.** Patch or later minor remains a maintainer decision
   no later than synthesis acceptance.
2. **Buffer ownership.** Fold-owned versus handler-owned belongs to the
   separately authored charter and measured fork, not this Seed.
3. **Collapse floor.** Decide only if the winning path needs character/list
   `setv()`; otherwise retain the current dependency contract.
4. **Resource envelope.** The charter must bind a same-host comparison and stop
   condition without turning it into a product performance promise.
5. **Provider follow-up.** Open only if the corrected-path profile or full-scale
   kill condition makes it the next measured lane.

## 11. Evidence And Authority

- `../rfc_cycle.md`
- `../spike_protocol.md`
- `rfc_availability_hot_path_representation_v0_2_0_x_seed.md`
- `rfc_availability_hot_path_representation_v0_2_0_x_response.md`
- `rfc_availability_hot_path_representation_v0_2_0_x_response_review.md`
- `../../../dev/spikes/availability-hot-path-representation/probe.R`
- `../../../dev/spikes/availability-hot-path-representation/probe_findings.md`
- `../../../dev/spikes/availability-hot-path-representation/lane_profile_probe.R`
- `../../../dev/spikes/availability-hot-path-representation/lane_profile_findings.md`
- `../manual/performance_arc_v0_1_8_x.qmd`
- `../collapse_optimization_map.md`
- `../audits/fold_path_hotpath_audit.md`
- `rfc_collapse_primitive_internals_v0_1_9_synthesis.md`
- `rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md`
- `../ledgr_v0_2_0_0_spec_packet/v0_2_0_0_spec.md`
- collapse 2.1.8 changelog:
  <https://fastverse.org/collapse/news/index.html#collapse-218>

## Revision History

- 2026-09-14 - Seed v2 consumes Response v1, Response Review v1, the passing
  DuckDB seam check, and the `DIAGNOSTICS_DOMINANT` prerequisite lane profile.
  It corrects provider attribution, probe-arm framing, charter ownership,
  optimization-rule citations, collapse optionality, and release placement.
  No implementation, schema, contract, or release is authorized.
