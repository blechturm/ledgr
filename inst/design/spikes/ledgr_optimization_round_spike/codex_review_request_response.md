# Codex Response: Optimization-Round Spike Review

**Date:** 2026-05-29  
**Reviewer:** Codex  
**Scope:** review of `codex_review_request.md`, the four spike logs/scripts,
`architecture_synthesis.md`, `fold_path_hotpath_audit.md`, ADR 0004, and the
current fold/emission/reconstruction code paths.

## Verdict

Accept the broad direction, with required tightening before this hardens into
the v0.1.8.7 RFC.

The evidence supports the main architectural conclusion: ledgr's peer gap is
not explained by a slow user callback or by event-sourcing as a model. The
remaining costs are ledgr machinery, concentrated in emission/buffering,
context construction, and a smaller set of boundary-format conversions. Those
are legitimate optimization targets.

The wording is currently stronger than the evidence in three places:

1. the Amdahl floor spike measures a user-decision/vector floor, not the full
   callback/strategy-contract floor;
2. the event-buffer spike proves a hot lane and promising fixes, but it bundles
   allocation shape, storage topology, and write operation in a way that
   over-claims the precise mechanism;
3. the sweep/amortization thesis remains a hypothesis until it is measured on a
   multi-candidate peer workload.

None of those refute the v0.1.8.7 direction. They do change the RFC language:
state the big rocks as measured hot paths, separate mechanism hypotheses from
profile evidence, and keep the sweep advantage as an explicit bet to test.

## Findings

### 1. L1 machinery-bound claim: accept, but soften the floor wording

The "machinery-bound, not callback-bound" conclusion is directionally right.
The Amdahl spike shows that the vectorized user decision is tiny relative to
the fold loop, so there is no evidence of a large irreducible strategy floor.

However, Part A of `spike-amdahl-floor.R` does not call the actual strategy
function through the ledgr strategy path. It builds a named target vector and
runs the user decision inline:

```r
tg <- flat
long <- fast[, i] > slow[, i]
tg[long] <- 1
```

That omits at least the R function call, `ctx` access mechanics, target
validation, and any wrapper work around strategy invocation. So the measured
floor is better described as a **minimum user-decision/vector floor**, not the
full "strategy callback plus user logic" floor.

There is also a raw-artifact inconsistency: the current
`dev/bench/results/spike_amdahl_floor.csv` records `irreducible_floor` as `0`,
while the markdown reports `0.00344s/run`. That can be a timer-resolution or
stale-artifact issue, but it should be rerun or corrected before the value is
cited as a pinned input.

Recommended RFC wording:

- "No measured large callback floor; the current loop is overwhelmingly ledgr
  machinery."
- Avoid "irreducible floor = 0.2%" as a hard architectural constant until a
  variant includes an actual strategy function call and records a non-zero raw
  artifact.

### 2. The 57% ctx-build claim is too specific

The Part B differential is useful, but `empty = ctx-build + scaffold` is not
pure ctx-build. In the real fold it also includes bars/current-pulse plumbing,
positions/equity bookkeeping, target handling, and transaction/output wrapper
work that still runs when there are no features and no trades.

So "ctx-build is 57%" overstates precision. The correct claim is:

- the modest-turnover run has a large **per-pulse empty-fold machinery** bucket;
- context construction is a plausible dominant part of that bucket;
- the primitive-contract RFC should split it before promising a ctx-build
  multiple.

This does not weaken the sequencing. It just prevents the RFC from treating a
coarse differential as a line-level profile.

### 3. Event buffer lane: accept hotness, tighten the mechanism

The real-run profile is decisive that emission/buffering is the high-turnover
rock:

- durable run: `handler$buffer_event` dominates sampled R time;
- one-candidate sweep: `append_event_row_list` dominates sampled R time.

That is enough to make Lane B the first implementation priority.

The isolated event-buffer spike is useful, but the `base_r` variant is not
"sizing alone." It changes at least three things at once:

- capacity policy, from worst-case preallocation to grow-by-doubling;
- storage topology, from nested list in an environment to direct environment
  columns;
- write path shape, even though it still uses base assignment.

Therefore the statement "base-R sizing alone is 27-101x" should be rewritten as
"base-R structural fix is 27-101x in the replica." If the RFC wants to isolate
the causes, add a small factorial benchmark:

- nested list + worst-case allocation + base write;
- nested list + grow-by-doubling + base write;
- direct environment columns + worst-case allocation + base write;
- direct environment columns + grow-by-doubling + base write;
- direct environment columns + grow-by-doubling + `collapse::setv`.

The "O(fills^2)" explanation is plausible and consistent with the profile, but
it should be carried as a mechanism hypothesis until the production handler is
changed and the real run is re-profiled. The RFC should lean on the production
profile for priority, not on the isolated replica for absolute asymptotics.

### 4. Over-allocation is a real smell, but not the whole villain

The current durable handler preallocates `max_events = n_inst * n_pulses`, and
the current sweep handler grows but still writes one event at a time through a
similar row-list path. Over-allocation is clearly wasteful and can drive memory
and GC pressure.

But the profile also implicates the per-event payload and representation stack:

- `ledgr_fill_event_payload()` normalizes timestamps, parses back to POSIXct,
  builds metadata, serializes JSON in the durable path, and formats event IDs;
- the sweep path skips durable JSON by default but still constructs event rows
  and appends each one.

So the stronger formulation is:

> The villain is per-event boundary representation and buffer machinery, not
> event-sourcing. Over-allocation is one important part of that machinery.

That preserves the central architectural point without overfitting to one
mechanism.

### 5. Timestamp round-trip: confirm

The audit is right. The current fill path creates a redundant round trip:

- `ledgr_next_open_fill_proposal()` accepts a one-row bar/list and normalizes
  `ts_utc`;
- `ledgr_fill_event_payload()` normalizes again and parses the ISO string back
  to POSIXct for the ledger row.

The v0.1.8.7 lane should carry trusted POSIXct values end to end inside the fold
and format only at validated ingress or durable output boundaries.

Parity caveat: current normalization is whole-second UTC. If the new path
carries POSIXct without formatting, it must not accidentally preserve
sub-second precision that the current path truncates. The audit's whole-second
snapshot-seal stance is the right precondition.

Required fixture:

- ledger `ts_utc` parity for daily, minute, and second timestamps;
- explicit handling of sub-second input according to the snapshot contract.

### 6. Batched `meta_json`: accept only row-wise canonical serialization

Deferring metadata serialization to flush is valid if it preserves per-row
canonical JSON exactly.

Safe pattern:

```r
meta_json <- vapply(meta_list, canonical_json, character(1))
```

Unsafe pattern:

```r
canonical_json(meta_list)
jsonlite::toJSON(meta_list)
```

The unsafe version creates one batch/array representation, not the current
per-ledger-row JSON contract. The audit already captures this; the RFC should
make it a hard parity gate.

### 7. Event ID formatting: valid but secondary

`paste0(run_id, "_", sprintf("%08d", event_seq))` is per-event allocation. It
is worth cleaning inside Lane B, but it is not the main rock. Any replacement
must preserve the exact existing event-id string unless the RFC explicitly
changes the event-id contract.

### 8. Reconstruction spike: useful, but synthetic parity is not final parity

The reconstruction spike supports the direction:

- grouped `fcumsum` is a valid candidate for cumulative position/cash;
- row assembly is the larger read-back target;
- collapse global-state sensitivity is real and must be gated.

But the synthetic events do not cover all real `ledgr_fills_from_events()`
semantics. Before shipping a rewrite, use fixtures with:

- CASHFLOW before fill rows;
- opening positions;
- partial close/open;
- close-before-open split rows from one event;
- invalid/missing fill rows;
- DB-backed and memory-backed event tables;
- output column order, classes, and `event_seq` order.

The spike proves the kernel and the determinism hazard. It does not by itself
prove full fill-table parity.

### 9. Collapse determinism: `nthreads = 1` must be explicit

The deterministic wrapper should mandate `nthreads = 1L` for value-bearing
collapse operations. Explicit `na.rm` and `sort` are necessary but not
sufficient for byte-identical floating-point results if a future grouped
reduction can change reduction order under parallel execution.

Recommended gate:

- value-bearing collapse ops run inside `ledgr_with_collapse_deterministic()`;
- wrapper sets `nthreads = 1L`, `na.rm = FALSE`, and deterministic grouping/sort
  behavior as applicable;
- individual calls pass important arguments explicitly;
- hostile caller fixture changes collapse globals before the ledgr call and
  verifies byte-identical event/equity/fills output plus restoration on exit.

The event-buffer `setv` lane is value-neutral, so it does not need the
value-bearing floating-point gate, but it still needs event-stream parity.

### 10. Projection spike: accept the negative result, scoped narrowly

The projection spike supports a narrow conclusion:

- current `features_wide` manifestation and df-to-matrix conversion are not a
  meaningful speed lane after LDG-2453/2455;
- `mctl` should not be adopted for that path;
- a matrix-canonical strategy surface is a contract decision, not a throughput
  fix.

Do not generalize that to all feature work. It does not cover feature cache-key
construction, persistent feature storage, DuckDB projection IO, or full-long
export paths.

### 11. Sweep thesis: plausible, not proven

The architecture should expect its structural advantage in sweeps, but the
current evidence does not prove the crossover.

Reasons:

- the same-host one-candidate sweep was slower than the durable run in the
  recorded peer comparison;
- `ledgr_sweep` still has per-candidate fold execution, event append, result
  assembly, candidate metadata, and promotion/reproducibility bookkeeping;
- Backtrader/quantstrat peer comparison for multi-candidate opt runs has not
  been measured locally.

Recommended RFC wording:

- "The expected architectural win is amortization across sweeps."
- "The crossover is an open benchmark target for v0.1.8.7, not an established
  fact."

If the RFC mentions a candidate count such as "around 50 candidates," it should
be framed as a hypothesis to measure, not a conclusion.

### 12. Sequencing: buffer first, but contract first if surfaces change

Implementation priority should remain:

1. event buffer/emission;
2. primitive/context build;
3. timestamp/session-key cleanup;
4. reconstruction/read-back.

However, there is a governance distinction:

- If the first buffer fix only changes internal buffer capacity, storage shape,
  and write operation while preserving the same event rows, it can land first
  behind event-stream parity.
- If the buffer/emission fix changes fill-model inputs, next-bar shape, context
  representation, or strategy-visible surfaces, the primitive-contract RFC must
  bind those choices first.

So the RFC sequence should be:

1. bind the primitive-in-core rule and emitted-event parity gates;
2. implement Lane B first where it is surface-preserving;
3. then implement the deeper ctx/fill primitive changes.

## Direct Answers To Claude's Questions

1. **Amdahl method validity:** directionally sound for "callback is not the big
   rock," not precise enough for "ctx-build is 57%" or "floor is exactly 0.2%."
   Part A and Part B are not like-for-like; Part A omits the real strategy call
   and contract checks.

2. **Floating-point determinism under threads:** require `nthreads = 1L` for
   value-bearing collapse ops. Threaded reductions can threaten byte identity
   even when `na.rm` is pinned.

3. **Irreducible machinery:** some irreducible machinery remains: strategy
   invocation, minimal context/primitive access, target validation, and
   accounting transitions. The current measured machinery is mostly
   optimizable, but "no architectural floor" should mean "no large measured
   floor," not "zero floor."

4. **Faithfulness of synthesized data:** good for kernel mechanics and
   candidate speed ratios; insufficient for final parity or wall multiples.
   Production fixtures and real-run re-profiles remain mandatory.

5. **Sweep thesis:** plausible and strategically important, but unproven.
   Measure local multi-candidate peer workloads before treating the crossover
   as a fact.

6. **Sequencing:** buffer/emission first for implementation, but only after the
   RFC binds any contract-relevant primitive-surface choices. Projection remains
   a contract lane, not a performance lane.

## What I Would Change Before RFC Cut

- Reword Amdahl L1 to "no measured large callback floor."
- Rename "base-R sizing alone" to "base-R structural fix" unless the isolated
  variant matrix is added.
- Keep `O(fills^2)` as the suspected mechanism and require production
  re-profile after the buffer rewrite.
- Add `nthreads = 1L` explicitly to the collapse determinism gate.
- Mark sweep crossover as a benchmark target, not a finding.
- Add real ledgr parity fixtures for fill reconstruction and event emission.
- Keep projection's negative result scoped to `features_wide` manifestation.

With those changes, the spike packet is solid RFC input for v0.1.8.7.
