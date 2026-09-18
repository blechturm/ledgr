# RFC Seed v1: Availability Hot-Path Representation

**Status:** Seed v1; non-binding.

**Window:** v0.2.0.x, exact release unassigned.

**Author:** Codex.

**Next RFC stage:** adversarial response by a different author.

**Prerequisite probe:**
`../../../dev/spikes/availability-hot-path-representation/probe_findings.md`.

## 1. Question

How should ledgr preserve its complete point-in-time availability semantics and
durable decision evidence without reintroducing the scale-growing R
representation costs removed during the v0.1.8.7-v0.1.8.10 optimization arc?

This Seed proposes a representation correction, not an availability-policy
change. Every accepted decision, restriction, fill, no-fill, stop, completion,
reopen, and explanation result remains semantically binding.

This RFC uses "first correction" for the first implementation of this
representation change. It does not mean ledgr v1.0.0 and does not assign a
release number.

## 2. Why The Cycle Is Open

The v0.1.8.9 packet made three rules explicit:

1. scale-growing hot-path state uses primitive typed columns;
2. per-row writes use safe by-reference or vectorized operations rather than
   complex base-R replacement;
3. data frames are materialized at a boundary, not once per row inside a loop.

The availability implementation added by `765b34e` violates the third rule
directly and the first two in effect:

- `R/availability-economics.R:386-432` constructs one 22-column data frame per
  diagnostic row;
- `R/fold-engine.R:318-327` retains those frames in a scale-growing list;
- `R/fold-engine.R:611-654` appends one row for every pulse-axis cell;
- `R/fold-engine.R:1082-1094` combines the complete list with
  `do.call(rbind, diagnostic_rows)` before persistence.

The prerequisite probe called that production constructor and final binder.
At 20,000 rows the retained list occupied 108.34 MiB and took 11.61 seconds to
construct plus 20.04 seconds to bind. A single column-oriented construction
occupied 3.16 MiB, completed below the timer's hundredth-second resolution,
and was exactly identical. These are mechanism measurements on a synthetic
ladder, not a public performance ranking or a production runtime projection.

An external Sharadar integration then encountered the production consequence:
a 563-instrument, 757-pulse availability-aware flat control with 413,532 bars
and a 505-ID pulse axis remained `RUNNING` after a lower bound of 1,804 seconds
and 4,245.6 MiB. The corresponding static peer benchmark is larger in bars and
pulses but completes. The external observation contains no licensed rows here;
it is motivation, not the spike's evidence source.

## 3. Reconciliation With Existing Decisions

The accepted availability synthesis and v0.2.0.0 packet remain authoritative
for semantics. In active mode the durable run records one decision trace row
per axis ID per invoked pulse plus risk, fill, no-fill, stop, and error rows.
Reopen and `ledgr_run_explain()` consume that evidence without re-executing the
strategy. This Seed does not weaken those rules.

The v0.2.0.0 spec selected normalized sparse fact tables in DuckDB and bounded
aligned arrays behind one internal provider. It explicitly made representation
optimization and performance claims non-scope. That protected a
correctness-first release from an unmeasured representation choice, but it did
not authorize a hot path already known to scale badly.

The correction follows the existing single-core direction:

- one shared fold core;
- primitive/matrix execution state;
- chunked and typed buffers;
- data-frame/tibble conversion at public or persistence boundaries;
- exact parity before interpreting timing;
- production-path measurement after a small mechanism probe.

## 4. Proposed Direction

### 4.1 Retain the evidence contract

Keep the current diagnostic schema, deterministic sequence, row order, reason
vocabulary, nullable fields, transaction behavior, interruption/resume
behavior, and fresh-connection read-back. Do not suppress ordinary
`decision_recorded` rows to obtain speed.

### 4.2 Replace row objects with a bounded columnar writer

The first correction should build diagnostic columns from aligned vectors and
flush bounded chunks through the existing output-handler boundary. It should
never retain a list containing one data frame per diagnostic row and should
never call `do.call(rbind, ...)` over that shape.

The likely implementation shape is:

- typed atomic columns with explicit prototypes;
- vectorized construction for a complete pulse axis where values already
  exist as aligned vectors;
- bounded chunk growth and one data-frame manifestation per flush;
- `collapse::setv()` for safe by-reference scalar writes that remain;
- vector or block assignment where it is clearer than scalar mutation;
- `DBI::dbAppendTable()` at the existing transaction-owned persistence seam.

No particular chunk size or helper name is bound by this Seed.

### 4.3 Reconsider the old character/list restriction

ledgr retained base assignment for character and list buffer columns after
collapse 2.1.7 produced memory corruption under long-running allocation. The
prerequisite probe compiled collapse 2.1.8 from source under R 4.5.2 and passed
70,000 dynamic character and list writes with repeated garbage collection and
exact base-R parity. collapse 2.1.8 documents issue 876 as fixed.

The next spike may therefore test an all-atomic/all-supported `setv()` buffer.
It must retain a base/vectorized alternative and must not infer production
safety from the prerequisite alone. The probe did not reproduce a defect, so
this cycle should not open a new collapse issue unless the production-path
spike yields a minimal package-independent reproducer.

### 4.4 Keep public frames at the boundary

Public diagnostics remain tibbles/data frames. DuckDB rows remain unchanged.
The optimization doctrine is not "ban data frames"; it is "do not manufacture
one frame per scale-growing cell in the fold."

## 5. Proposed Subsequent Spike

This Seed proposes but does not charter a spike. Per `spike_protocol.md`, a
different stage writes the charter after the response and any Seed v2.

Exactly one question:

> Can one bounded columnar/chunked diagnostic writer replace the current
> list-of-one-row-data-frames path while preserving exact direct-run,
> interrupted/resumed, persisted, reopened, and explained evidence on the
> shared availability fold?

Cheaper prerequisite: the collapse 2.1.8 character/list `setv()` regression
probe passed and is recorded beside this Seed.

The charter should compare only:

1. the current production implementation; and
2. one columnar/chunked alternative.

It should begin with the smallest runnable fork, derive no more than ten cases
from real failures, and use a public synthetic fixture shaped like the observed
563-instrument, 757-pulse, approximately 505-active-ID workload. The current
path receives a wall/memory kill condition rather than an obligation to finish.

Required parity surfaces should be limited to five reviewable claims:

1. diagnostic columns, values, ordering, and row count;
2. completion/status and interruption/resume append semantics;
3. ledger events, fills, equity, and strategy-state equality;
4. fresh-connection diagnostics and `ledgr_run_explain()` equality;
5. bounded wall and peak memory on the unchanged public scale fixture.

Kill and recharter condition: if the alternative removes diagnostic
construction/materialization as the dominant lane but the unchanged run still
breaches its envelope, close this spike without adding a second alternative.
Use the resulting profile to charter a separate provider-resolution question.

## 6. Deferred Provider Work

Current provider resolution also rebuilds membership state from data frames at
every cutoff, repeatedly filters membership rows by set, loops IDs for status
and lifetime, and scans historical closes for valuation. External read-only
measurements put decision-view resolution in the minutes rather than the
thirty-minute class, so those paths are not the first spike question.

If the diagnostic correction exposes provider resolution as material, a later
cycle or rechartered spike may test one compiled fold-local alternative:

- keep sparse facts as the canonical DuckDB evidence;
- compile pulse-indexed membership/status/lifetime state once at run entry;
- use integer instrument indices and bounded aligned vectors/matrices;
- advance or index by fact change point rather than replaying history;
- update last-valid valuation state incrementally.

Expanded planes remain transient runtime state, not a second persisted truth.

## 7. Determinism And Safety

`collapse::setv()` is value-neutral mutation and does not require the
deterministic reduction wrapper. Any use of value-bearing grouped or cumulative
collapse functions remains subject to `ledgr_with_collapse_deterministic()` and
byte/economic parity gates.

The correction must preserve transaction ownership. A chunk flush may not
make a failed current pulse partially durable, relabel a `RUNNING` or
`INCOMPLETE` result, duplicate rows on resume, or move diagnostics outside the
existing fold/finalization failure boundaries.

Performance acceptance comes after equality. A faster result with missing,
coalesced, reordered, or reconstructed decision evidence fails.

## 8. Proposed Engineering Rule

Future fold-path work should inherit this rule even when a release makes no
performance claim:

> Performance non-scope does not permit reintroducing an already-proven
> scale-growing hot-path anti-pattern. New fold-owned collections use primitive
> or matrix state, bounded columnar buffers, vectorized operations, and
> boundary-only frame manifestation unless a production-shaped probe supports
> an explicit exception.

This is a proposed rule until synthesis and maintainer acceptance. It does not
retroactively turn every cold-path `data.frame()` or `rbind()` into debt.

## 9. Non-Goals

- No change to availability, membership, lifetime, status, valuation,
  affordability, no-fill, terminal-event, or held-former-member policy.
- No diagnostic retention tiers or deletion of ordinary decision rows.
- No snapshot, experiment, run, hash, schema, or public API version change
  unless the spike proves one unavoidable.
- No second engine, compiled fold, durable compiled integration, parallel
  pulse execution, or provider plug-in system.
- No Sharadar-specific implementation or licensed-data fixture.
- No simultaneous diagnostic, provider, valuation, and context rewrite.
- No broad package-wide collapse adoption.
- No public speed claim from the probe or spike.

## 10. Open Questions For The Response

1. Is the first spike narrow enough, or does transaction-safe chunk flushing
   require a smaller prerequisite seam test?
2. Is exact diagnostics equality the right gate, or are any row attributes
   presentation-only while values/order/schema remain binding?
3. Should the correction require collapse 2.1.8, or retain a vectorized base-R
   path and treat `setv()` as an internal optional mechanism?
4. Does chunk flushing belong inside the fold transaction, in the output
   handler, or in a fold-owned buffer passed to the existing handler?
5. What wall/memory envelope is strict enough to falsify the alternative
   without turning a local machine result into a product promise?

## 11. Evidence And Authority

- `../rfc_cycle.md`
- `../spike_protocol.md`
- `../manual/performance_arc_v0_1_8_x.qmd`
- `../collapse_optimization_map.md`
- `../audits/fold_path_hotpath_audit.md`
- `../ledgr_v0_1_8_9_spec_packet/v0_1_8_9_spec.md`
- `../ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md`
- `rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md`
- `../ledgr_v0_2_0_0_spec_packet/v0_2_0_0_spec.md`
- `../../../dev/spikes/availability-hot-path-representation/probe.R`
- `../../../dev/spikes/availability-hot-path-representation/probe_findings.md`
- collapse 2.1.8 changelog:
  <https://fastverse.org/collapse/news/index.html#collapse-218>

## Revision History

- 2026-09-14 -- Seed v1 written after the required public probe. No package,
  schema, contract, or implementation change. Awaiting response-stage review.
