# Ephemeral Xlarge Wall Attribution Spike — Specification (Round 2)

**Status:** Round 2 draft, incorporating Codex Round-1 review verdict
(reject pending Round 2). Awaits Codex Round-2 review.
**Target window:** v0.1.9. Cannot run until v0.1.8.10 ships (depends on
substrate-decision shape).
**Repository:** ledgr (the spike runs in-tree).

## Mission

Decompose ledgr's `density_high_xlarge_ephemeral` workload-grid cell
into its constituent per-pulse and per-fill sub-frames. Produce a
Pareto attribution on **grouped rollups** of those sub-frames:
**which architectural surface accounts for the dominant share of
xlarge ephemeral wall, both as a percent and in absolute seconds?**
The output directly gates ledgr's v0.1.9 optimization direction
(Architecture A via `ledgrcore`; Architecture B2 via cpp11 hot
frames inside ledgr; or neither, in favor of a different optimization
target) per the 2026-06-01 horizon entry that scopes this spike.

This is an attribution exercise, not an optimization exercise. The
spike does not write any production code patches. Its single output
is a verdict document mapping wall share to grouped architectural
surfaces with explicit absolute-and-relative thresholds.

## Authority

This spec operationalizes the 2026-06-01 horizon entry
**"Ephemeral-mode xlarge wall attribution as gate for ledgrcore /
Architecture B2 commit"**. The authoritative scope source is that
entry. The K1 measurement-spike verdict (2026-06-01,
`ledgrcore-spike` repo `inst/design/spikes/k1_measurement_spike/verdict.md`)
established that the K1 spike addresses only ~15% of xlarge ephemeral
wall (the fold-loop slice). This spike attributes the remaining ~85%
across grouped architectural surfaces.

Related horizon entries (referenced throughout):

- **2026-06-01 [architecture] K1 measurement-spike verdict**
- **2026-06-01 [architecture] Architecture B: in-place hot-frame
  compilation as alternative to ledgrcore**
- **2026-06-01 [optimization] Ephemeral-mode xlarge wall attribution
  as gate** (scope-binding)
- **2026-05-30 [architecture] Compiled fold core as `ledgrcore`
  sister package** (with 2026-06-01 substrate-and-measurement
  updates)

v0.1.8.10 Round-3 architecture synthesis is the post-substrate R
baseline this spike measures against (fold-owned FIFO accounting per
L7 Ticket 2; `ctx$vec` namespace per L7 Ticket 3).

## Round-2 Revision Notes

Codex's Round-1 review (`spec_codex_review.md`) identified five
blocking methodology issues and three caveat-worthy findings.
Round 2 changes:

1. **New "Attribution Semantics" section** (closes Codex Findings 2
   and 5) — defines inclusive vs exclusive time, declares the
   parent/child hierarchy explicitly, names GC/allocation as a
   first-class bucket.
2. **Rewritten "Methodology" section** (closes Findings 1, 3, 8) —
   splits sub-frames into function-boundary (Method A via
   `assignInNamespace()`) and statement-range (Method A via
   instrumented copy of the enclosing function) categories;
   downgrades Method B to discovery-only (no top-3 agreement gate);
   adds timer-overhead calibration loop; clarifies rep count.
3. **Rewritten "Decision Rule" section** (closes Finding 4) — adds
   absolute-wall thresholds alongside percent; introduces grouped
   architectural rollups; classifies E12 (default cost resolver) as
   fold-adjacent for LDG-2479; the "< 15%" pivot branch now requires
   BOTH relative AND absolute thresholds.
4. **Sub-frame table revised** — adds hierarchy column,
   instrumentation-method column, GC bucket as a new top-level
   bucket, target validation (E13) and strategy preflight (O4) added
   as distinct sub-frames per Codex's suggested additions, O1/O2
   citations corrected, E2 and E5 hypotheses re-labeled per Finding
   7.
5. **Pre-run citation refresh** added as an explicit gate before
   measurement starts (per Codex's suggested addition + Finding 6
   becoming blocking if not addressed).

Confirmed-correct claims from Round 1 (Codex Round-1 review):
post-v0.1.8.10 dependency, K1 verdict representation, metric kernel
derivation from equity + fills, ephemeral handler's lack of hidden
DBI work, telemetry env scoping, treatment of the 372.55s anchor.
All carried into Round 2 unchanged.

## The Question

What grouped architectural surface accounts for the dominant share of
ledgr's `density_high_xlarge_ephemeral` cell wall, measured both as
percent of total and as absolute seconds? Specifically:

1. **Is the fold-core slice meaningful?** K1 addressed the
   compilable fold work (FIFO lots + position/cash updates + event
   emission + per-pulse equity, plus the default internal cost
   resolver per Round-2 classification below). The attribution must
   report this rollup's wall share AND absolute seconds.

2. **Where does the bulk of wall live across grouped surfaces?** The
   eight architectural rollups defined in the Attribution Semantics
   section below cover all measured sub-frames plus GC and
   unattributed remainder. The attribution ranks them.

3. **What's the highest-leverage v0.1.9.x ticket?** Per the
   decision-rule mapping, the top group by share AND by absolute
   recoverable wall becomes the v0.1.9 optimization-direction
   commitment. The output names the recommended ticket scope.

## Authoritative Baseline

The baseline is the post-v0.1.8.10 ledgr installed package running
the LDG-2479 `density_high_xlarge_ephemeral` workload-grid cell:

- 1000 instruments × 1260 pulses × ~130,000 fills
- Memory output handler path (ephemeral, not durable)
- Post-v0.1.8.10 substrate shape: fold-owned FIFO accounting in the
  fold engine; `ctx$vec` namespace; `state$positions` as bare
  `numeric()` with `id_to_idx` map
- Post-v0.1.8.10 yyjsonr helper options-hoist applied (per Round-3
  Ticket 4)
- Workload-grid telemetry enabled at the subphase level per Spike 11
  (Round-3 Ticket 1)

Reference baseline wall for this cell, per Codex's correction in the
v0.1.8.10 Round-2 review citing `v0_1_8_9_release_closeout.md`:
**372.55s pre-v0.1.8.10**. The attribution measurement must include
its own re-measured baseline after v0.1.8.10 lands; the 372.55s
number is anchored only for pre-Ticket-2 comparison and is referenced
in this spec only to bound the absolute-wall thresholds below.

## Attribution Semantics

This section closes Codex Round-1 Findings 2 (nested double-counting)
and 5 (GC bucket missing). All later sections — sub-frame table,
methodology, decision rule, Pareto requirement — use the semantics
defined here.

### Inclusive vs exclusive time

For any sub-frame `F` that contains children `C1, C2, ...`:

- **Inclusive time** of `F` = the wall measured from `F`'s start
  boundary to `F`'s end boundary. Includes all children's wall.
- **Exclusive time** (also: self-time) of `F` = inclusive time of
  `F` minus the sum of inclusive times of `F`'s direct children.

Method A wrappers always measure inclusive time. Exclusive time is
derived during synthesis.

**Decision-rule and Pareto inputs always use exclusive time at the
leaf level OR inclusive time at the rollup level. Mixed timings are
not permitted.** The grouped rollups defined below operate on
inclusive time at the rollup boundary (i.e. sum of exclusive times of
all leaves in the rollup).

### Parent / child hierarchy

The hierarchy below covers every sub-frame measured by this spike.
Leaf entries (no children) use exclusive time directly. Parent
entries use the sum of their children's exclusive times.

```
TOTAL_WALL
├── O — Out-of-loop one-time costs
│   ├── O1: snapshot read + bars fetch
│   ├── O2: bars matrix + pulse views construction
│   ├── O3: feature precompute + projection setup
│   ├── O4: candidate execution setup
│   └── O5: ctx helper cache initialization
├── ENGINE_PHASE (Spike 11's engine_sec)
│   ├── E_PER_PULSE (summed across n_pulses)
│   │   ├── E1: pulse-context list allocation
│   │   ├── E2: helper attachment
│   │   ├── E3: feature engine + runtime projection lookup
│   │   ├── E4: strategy callback invocation machinery
│   │   ├── E5: active alias map normalization
│   │   ├── E6: per-pulse position valuation
│   │   ├── E10: pulse-seed RNG derivation
│   │   ├── E11: telemetry collection overhead
│   │   └── E13: target validation + target-risk noop
│   └── E_FILL_LOOP (the fill-loop body at R/fold-engine.R:288-365)
│       ├── E7r: fill-loop residual (delta resolve, side code, cash/positions update — exclusive of children below)
│       ├── E8: lot machinery (FIFO accounting; post-Ticket-2 fold-owned)
│       ├── E9: event emission to memory output handler
│       └── E12: cost resolver (default internal: cost_spread_commission_internal)
├── RESULTS_PHASE (Spike 11's results_sec)
│   ├── R1: reconstruction-pass lot replay (likely empty post-Ticket-2)
│   ├── R2: reconstruction cash cumsum + equity from positions matrix
│   │   └── R3: per-instrument bucket loop (child of R2; exclusive timing required)
│   ├── R4: fills tibble materialization
│   ├── R5: metrics computation
│   └── R6: meta list column overhead
├── GC: garbage collection + allocation pressure (measured per Method
│   A reps via gc(verbose=FALSE) deltas)
└── UNATTRIBUTED: TOTAL_WALL minus sum(all exclusive leaves) minus GC
```

Note: `E7r` (fill-loop residual) is what remains of E_FILL_LOOP after
the three nested children (E8, E9, E12) are subtracted. The Round-1
spec called this "E7"; in Round 2 the parent E_FILL_LOOP retains
inclusive timing, and E7r is the exclusive leaf.

### Grouped architectural rollups

The decision rule operates on these rollups, not on individual
sub-frames. Each rollup's wall is the inclusive time of its members
(i.e. the sum of exclusive times of all named leaves in the rollup).

| Rollup | Members | Compilable under A | Compilable under B2 (cpp11) |
|:-------|:--------|:-------------------|:----------------------------|
| **FOLD_CORE** | E6 + E7r + E8 + E9 + E12 | Yes | Yes (per-pulse batch) |
| **CTX_HELPERS** | E1 + E2 + E4 + E13 | Yes (E4 wrapper only; user strategy stays R) | Yes |
| **FEATURE_ALIAS** | E3 + E5 | Yes (lookup path); user features stay declarative | Yes |
| **STATE_ENGINE_OTHER** | E10 + E11 | Mostly yes (RNG is compilable; telemetry hooks stay R) | Yes |
| **RECONSTRUCTION** | R1 + R2 + R3 + R4 + R5 + R6 | Conditional — R1 likely empty post-Ticket-2; remainder is mostly aggregation/materialization | Conditional |
| **SETUP** | O1 + O2 + O3 + O4 + O5 | No (one-time R orchestration, off the hot path) | No |
| **GC_ALLOCATION** | GC bucket | Indirect (compiled code reduces allocation pressure but cannot eliminate R-side allocator behavior on R objects) | Indirect |
| **UNATTRIBUTED** | UNATTRIBUTED bucket | Investigate | Investigate |

**E12 classification rationale (per Codex Round-1 Finding 4):** the
LDG-2479 workload-grid cell uses the default
`cost_spread_commission_internal` (`R/fill-model.R:148-195`), which is
ledgr-internal code. Both Architecture A and Architecture B2 can
compile this default resolver. Therefore E12 is classified as
FOLD_CORE for this spike. A future user-supplied cost resolver would
be an R-callback boundary cost — separately measured if scoped, but
out of scope for this spike. The attribution synthesis must note this
classification explicitly in its caveats section.

### GC and allocation pressure as a first-class bucket

Closes Codex Round-1 Finding 5.

GC is measured by capturing `gc(verbose = FALSE)` output before and
after each measurement rep. The delta gives:
- **Number of Ncells / Vcells freed** (allocation pressure proxy).
- **Elapsed GC time** (via `Rprof.gc(start, end)` if used; else
  difference of `proc.time()` system time before/after gc trigger).

The GC bucket's wall is reported as:
- **GC_total**: total elapsed time R spent in garbage collection
  during the measured rep.
- **GC_allocation_rate**: cells freed per second of wall.

GC time is **excluded from sub-frame exclusive timings** (i.e.
sub-frame wrappers measure proc.time elapsed including any GC that
fires during the wrapped frame; we do not attempt to attribute GC to
sub-frames). The GC bucket holds the total GC elapsed; the
attribution synthesis reports it as a standalone rollup. If a
sub-frame's median wall is inflated by GC noise, the per-rep
stability check (max/min ratio ≤ 1.5x) will surface that, and the
synthesis flags the frame for re-measurement.

This semantics keeps GC honestly accounted without forcing
per-sub-frame GC attribution, which Rprof can't do reliably anyway.

## Sub-Frames to Measure

Citations are post-v0.1.8.10 hypotheses. **Pre-run citation refresh
gate**: before measurement starts, every cited line range must be
verified against the actual post-v0.1.8.10 production code at the
specific ledgr commit being measured. Citation drift is a blocking
failure mode — see Sequencing Constraints below.

### Engine-phase sub-frames

| ID | Sub-frame | Production code path (post-v0.1.8.10) | Instrumentation method | Hierarchy parent |
|:---|:----------|:--------------------------------------|:-----------------------|:------------------|
| E1 | Pulse-context list allocation | `R/fold-engine.R:181-194` | Statement-range (instrumented copy of `ledgr_execute_fold`) | E_PER_PULSE |
| E2 | Helper attachment | `R/fold-engine.R:196-221` (`ledgr_update_fast_pulse_context_helpers` call) | Function-boundary (`assignInNamespace`) | E_PER_PULSE |
| E3 | Feature engine + runtime projection lookup | Multiple call sites inside helper attachment plus per-accessor calls; wrap `ledgr_projection_pulse_views`, `ledgr_projection_feature_value` | Function-boundary (multiple) | E_PER_PULSE |
| E4 | Strategy callback invocation machinery | `R/fold-engine.R:228-247` (the `tryCatch`-wrapped invocation surrounding `strategy_fn(ctx)`) | Statement-range (instrumented copy) | E_PER_PULSE |
| E5 | Active alias map normalization | `R/feature-alias-map.R:90-104` (`ledgr_feature_lookup_map` calls into `ledgr_alias_map_storage`) | Function-boundary | E_PER_PULSE |
| E6 | Per-pulse position valuation | `R/fold-engine.R:164-170` (post-v0.1.8.9 vectorized; verify post-v0.1.8.10 still inline at this range) | Statement-range (instrumented copy) | E_PER_PULSE |
| E7r | Fill loop residual (exclusive of E8/E9/E12 children) | `R/fold-engine.R:288-365` minus children's frames | Statement-range (instrumented copy) | E_FILL_LOOP |
| E8 | Lot machinery (FIFO accounting) | `R/lot-accounting.R` (specifically `ledgr_lot_apply_fill` plus child calls); post-Ticket-2 fold-owned per v0.1.8.10 Round-3 L7 | Function-boundary (`ledgr_lot_apply_event` entry; subtract any non-fill dispatches) | E_FILL_LOOP |
| E9 | Event emission to memory output handler | `R/sweep.R:957-1190` (handler `buffer_event` / `append_event_row_list`); v0.1.8.9 setv path; bounded by meta list column per L8 | Function-boundary (`handler$buffer_event`) | E_FILL_LOOP |
| E10 | Pulse-seed RNG derivation | `R/rng.R:33-57` (`ledgr_derive_pulse_seed`: SHA-256 + canonical_json) | Function-boundary | E_PER_PULSE |
| E11 | Telemetry collection overhead | per-pulse `proc.time` snapshots when telemetry_stride > 0 | Statement-range (instrumented copy) | E_PER_PULSE |
| E12 | Cost resolver (default internal) | `R/fill-model.R:148-195` (`cost_spread_commission_internal`) called via `R/fold-engine.R:306` | Function-boundary | E_FILL_LOOP |
| E13 | Target validation + target-risk noop | `R/fold-engine.R:248-268` (target validation; target-risk noop adapter chain) | Statement-range (instrumented copy) | E_PER_PULSE |

### Results-phase sub-frames

| ID | Sub-frame | Production code path (post-v0.1.8.10) | Instrumentation method | Hierarchy parent |
|:---|:----------|:--------------------------------------|:-----------------------|:------------------|
| R1 | Reconstruction-pass lot replay | `R/fold-reconstruction.R:454-504` — post-Ticket-2 likely empty on the ephemeral path; verify at citation-refresh gate | Function-boundary | RECONSTRUCTION |
| R2 | Reconstruction cash cumsum + equity from positions matrix | `R/fold-reconstruction.R:506-527` | Statement-range (instrumented copy of `ledgr_sweep_summary_from_ordered_events`); inclusive of R3 | RECONSTRUCTION |
| R3 | Per-instrument bucket loop | `R/fold-reconstruction.R:514-526` (the `which` loop) | Statement-range (child of R2) | R2 |
| R4 | Fills tibble materialization | `R/fold-reconstruction.R:546-560` | Statement-range (instrumented copy) | RECONSTRUCTION |
| R5 | Metrics computation | `R/fold-metrics.R:9-50` (`ledgr_metrics_from_equity_fills`) | Function-boundary | RECONSTRUCTION |
| R6 | Meta list column overhead | per-event meta list materialization in `R/sweep.R:1077-1099` | Function-boundary (wrap `materialize_events`) | RECONSTRUCTION |

### Out-of-loop sub-frames (one-time costs)

Citations corrected per Codex Round-1 Finding 6. Pre-run citation
refresh gate applies.

| ID | Sub-frame | Production code path (current ledgr) | Instrumentation method | Hierarchy parent |
|:---|:----------|:--------------------------------------|:-----------------------|:------------------|
| O1 | Snapshot read + bars fetch | `R/sweep.R:119-128` | Statement-range (instrumented copy) | SETUP |
| O2 | Bars matrix + pulse views construction | `R/sweep.R:129-136` plus `R/sweep.R:1402-1426` | Statement-range (instrumented copy) | SETUP |
| O3 | Feature precompute + projection setup | `R/sweep.R:140-164` | Statement-range (instrumented copy) | SETUP |
| O4 | Candidate execution setup | `R/sweep.R:841-919` | Statement-range (instrumented copy) | SETUP |
| O5 | Ctx helper cache initialization | `R/pulse-context.R:312-340` (`ledgr_fast_context_state`) | Function-boundary | SETUP |

### Hypothesis labels (revised per Codex Round-1 Finding 7)

- **E2's "~1.8s" reference** is an upper-bound hypothesis for *broad
  ctx construction* attributed by v0.1.8.8 Batch 2 telemetry. It is
  NOT a measured helper-attachment slice. The attribution synthesis
  must reconcile measured E2 with this upper bound and explicitly
  state whether the prior attribution covered helper attachment
  alone or also included surrounding ctx-construction machinery.
- **E5 hypothesis**: alias map normalization only fires when the
  strategy calls `ctx$features(instrument_id)` without an explicit
  feature map. If the LDG-2479 strategy uses the v0.1.8.10
  `ctx$vec$feature(feature_id)` bulk-read path, E5 may be
  legitimately near-zero. The attribution synthesis must report E5's
  invocation count alongside its wall; a near-zero E5 result is
  reported as "not exercised by this fixture", not as proof alias
  normalization is globally irrelevant.

## Methodology

Closes Codex Round-1 Findings 1, 3, 8.

### Method A: targeted instrumentation (ground truth)

Two distinct instrumentation techniques are used depending on
sub-frame shape:

**A.1 Function-boundary wrappers (via `assignInNamespace()`).**
Used for sub-frames that align with a function entry/exit. The spike
script monkey-patches the production function with a timed wrapper
that records `(start_time, end_time, invocation_count)` into a
global attribution env, then calls the original function. After the
measurement rep completes, the patched functions are restored.

Function-boundary sub-frames: E2, E3 (multiple wrap sites), E5, E8
(via `ledgr_lot_apply_event` entry; non-FILL dispatches subtracted),
E9 (via `handler$buffer_event`), E10, E12, R1, R5, R6, O5.

**A.2 Instrumented-copy method (for statement-range sub-frames).**
For sub-frames that are statement ranges inside larger functions
(E1, E4, E6, E7r, E11, E13 inside `ledgr_execute_fold`; R2, R3, R4
inside `ledgr_sweep_summary_from_ordered_events`; O1-O4 inside the
sweep-setup path), the spike script maintains an **instrumented
copy** of the enclosing function. The instrumented copy is identical
to the production function except for inline `proc.time()` snapshots
at sub-frame boundaries that accumulate into the attribution env.

The instrumented copy is registered via `assignInNamespace()` for
the duration of the rep, then restored. **Parity gate**: the
instrumented copy's behavior must produce byte-identical event
streams, equity curves, and final state vectors against the
uninstrumented installed package on the same fixture. The parity
gate is run as a smaller cell (LDG-2479 `large` rather than xlarge)
before the xlarge timing run. Any parity failure blocks the timing
run until the instrumented copy is corrected.

Maintenance discipline: each instrumented copy carries a header
comment naming the production function it mirrors, the post-v0.1.8.10
commit hash it was copied from, and the list of sub-frame boundaries
it captures. Citation refresh applies — see Sequencing Constraints.

**Statement-range sub-frames**: E1, E4, E6, E7r, E11, E13, R2, R3,
R4, O1, O2, O3, O4.

### Method A: timer-overhead calibration

Closes Codex Finding 8. Each measurement session begins with a
**timer-overhead calibration loop**:

```r
n_calibration <- 100000L
t0 <- proc.time()[["elapsed"]]
for (i in seq_len(n_calibration)) {
  t1 <- proc.time()[["elapsed"]]
  t2 <- proc.time()[["elapsed"]]
}
t3 <- proc.time()[["elapsed"]]
per_call_overhead_sec <- (t3 - t0) / (2 * n_calibration)
```

The measured per-call overhead is then subtracted per sub-frame
based on invocation count:

```text
exclusive_corrected = exclusive_measured - (invocation_count * per_call_overhead_sec)
```

The calibration loop is recorded in the session log alongside the
attribution table. If per-call overhead exceeds 5 μs on the
measurement host, the attribution synthesis flags this as a
confidence concern (per-pulse sub-frames at 1260 invocations would
have ≥ 6 ms of overhead, comparable to the Amdahl-floor
user-decision floor).

### Method B: Rprof (discovery only)

Per Codex Finding 3, Method B is downgraded to discovery and
sanity-check. **Top-3 agreement is NOT required.** Method B's role:

- Identify sub-frames Method A missed (Rprof attributes time to
  functions Method A doesn't have wrappers for; if Rprof shows
  significant time in a function not in Method A's hierarchy, the
  attribution is incomplete and the function should be added as a
  new wrapper).
- Sanity-check Method A's coverage. If Method A coverage is 95%
  and Rprof at 10ms reports a function with significant total.time
  that's not in Method A's hierarchy, that's an attribution gap.

Rprof runs ONCE per session at 10ms sampling interval (default). A
second run at 1ms is optional and only if the 10ms run flags a
sub-millisecond hot frame for finer attribution.

Rprof attribution **does not feed the decision rule directly**.
Method A produces the verdict; Method B refines Method A's
sub-frame inventory between iterations.

### Cross-validation (Method A self-consistency)

Closes Codex Finding 3.

Method A's attribution is internally cross-validated via the
hierarchy:

- **Sum of exclusive leaves + GC bucket ≤ total_wall**. If exceeds,
  instrumentation overhead is biasing; recompute per-call overhead
  and re-subtract.
- **UNATTRIBUTED = total_wall - sum(exclusive leaves) - GC**. The
  attribution is considered acceptable if `UNATTRIBUTED / total_wall
  ≤ 0.15` (the "85% coverage" target from Round 1, now operating on
  consistent exclusive-time semantics).
- **If UNATTRIBUTED > 15%**, the attribution is incomplete. The
  recovery path is:
  1. Run Method B Rprof to identify which function(s) account for
     the unattributed mass.
  2. Add wrappers for those functions to Method A's hierarchy.
  3. Re-run Method A.

The recovery path is **broader coarse timers or repaired Method A**
— never Method B's sampled output used as final attribution.

### Inclusive-vs-exclusive enforcement

Closes Codex Finding 2.

The decision rule and Pareto rankings consume ONLY:
- Exclusive time of leaves, OR
- Inclusive time at the grouped-rollup boundary (i.e. sum of
  exclusive times of all leaves in the rollup).

Mixed consumption (e.g. "inclusive E_FILL_LOOP + exclusive E8") is
prohibited. The synthesis output flags any mixed-timing computation
as an error.

## Measurement Protocol

Per attribution-measurement cell:

- **Workload**: LDG-2479 `density_high_xlarge_ephemeral`
  (1000 inst × 1260 pulses × ~130k fills).
- **Reps**: see rep count below.
- **Warm-cache**: discard one warm rep before each batch of measured
  reps in each session role.
- **GC**: `gc(FALSE)` between reps; `gc(verbose = FALSE)` capture
  for GC bucket attribution.
- **Sub-frame accumulator reset between reps**: each rep produces an
  independent attribution table.
- **Median attribution per sub-frame across reps**: reported wall is
  the cross-rep median per sub-frame; min/max also reported.

### Rep count and session arithmetic

Closes Codex Finding 8.

| Role | Measured reps | Warm reps | Purpose |
|:-----|--------------:|----------:|:--------|
| Uninstrumented baseline | 5 | 1 | Establish post-v0.1.8.10 baseline wall |
| Method A instrumented | 5 | 1 | Sub-frame attribution |
| Method B Rprof (10ms) | 1 | 1 | Discovery / sanity check |
| Method B Rprof (1ms) | 0 or 1 | 1 if used | Optional finer attribution |
| Timer-overhead calibration | 1 (100k loop iter) | 0 | Per-call overhead measurement |

Plus: 1 parity-gate run at LDG-2479 `large` to validate instrumented
copies before xlarge timing begins.

**Total measured + warm**: 11 reps + 1-2 conditional Rprof rep + 1
parity rep = 13-15 sessions per full measurement.

At an expected post-v0.1.8.10 xlarge ephemeral wall of ~200-370s per
rep (range bounded by Round-3 L10 projection vs current 372.55s
anchor), the timing-rep budget is roughly 2-3 hours for the 5+5+1+1
core reps, plus parity (~1 hour at large) and calibration (seconds),
plus session overhead (instrumented-copy install/restore, GC
captures, warm-rep buffer). **Realistic full-session length: 4-6
hours.** The Round-1 spec's "70-80 minutes" estimate was wrong; the
revised arithmetic is in this section.

### Two-session split

Because the full measurement is ~4-6 hours, the spec recommends two
sessions:

1. **Session 1**: timer calibration + uninstrumented baseline (5
   reps) + Method A xlarge attribution (5 reps) + Method B Rprof
   10ms (1 rep).
2. **Session 2** (only if Session 1 surfaces issues): parity-gate
   re-run + recovery iteration + Method B Rprof 1ms if a
   sub-millisecond frame needs finer attribution.

If Session 1 produces a Pareto attribution meeting coverage and
stability requirements, Session 2 is not needed.

## Parity Gates

- **Engine output parity**: the instrumented run's emitted event
  stream, equity curve, and final-state vectors must be
  byte-identical to the uninstrumented run's (modulo timing fields
  and telemetry collection metadata). The instrumentation must not
  change any value-bearing computation. **Parity validated at
  LDG-2479 `large` scale before xlarge timing starts.** A parity
  failure blocks the xlarge timing run.
- **Per-rep attribution stability**: cross-rep median wall per
  sub-frame is reported alongside cross-rep min/max. If the
  max/min ratio for any sub-frame exceeds 1.5x, the sub-frame's
  number is flagged as unstable in the attribution synthesis. An
  unstable sub-frame does not block the verdict but reduces
  confidence on that frame's specific share.

## Pareto Requirement

The attribution output must answer four questions, all operating on
**grouped rollups** plus the fold-core slice explicitly:

1. **Grouped rollup ranking** by inclusive wall (sum of exclusive
   leaves in the rollup): all eight rollups ranked, with absolute
   wall in seconds, percent of TOTAL_WALL, and the dominant
   contributing leaves.
2. **Top-3 rollups' cumulative share**: should account for ≥ 80%
   of TOTAL_WALL. If less, the attribution is too diffuse; the
   synthesis must call out which rollups are individually small but
   collectively large.
3. **FOLD_CORE rollup**: explicit wall (absolute + percent) so the
   decision-rule mapping can be applied. The fold-core rollup
   members are E6, E7r, E8, E9, E12 (per the E12 classification
   above).
4. **For each top-3 rollup**: a one-paragraph characterization of
   which leaves contribute most, what kind of v0.1.9.x ticket would
   attack the rollup, and what the expected wall recovery would be.

## Decision Rule

Closes Codex Round-1 Finding 4.

The decision rule uses **both percent and absolute seconds**. Either
threshold met triggers the corresponding branch. Absolute thresholds
are anchored against the post-v0.1.8.10 measured baseline (call it
`TW`).

### Branch 1 — Pivot away from compiled cores

Both conditions must hold:

- FOLD_CORE share < 15% of TW
- FOLD_CORE absolute wall < 30s

Outcome: pivot away from compiled cores entirely. Architecture A and
B2 both defer indefinitely. The v0.1.9 optimization-direction
commitment goes to the largest non-FOLD_CORE rollup.

### Branch 2 — Run Architecture B2 spike

Either condition triggers this branch:

- FOLD_CORE share ≥ 30% of TW
- FOLD_CORE absolute wall ≥ 60s

Outcome: Architecture B2 spike is the next ledgr work item. The K1
+ B2 + attribution outputs combine into the A-vs-B2 decision per the
2026-06-01 Architecture B horizon entry. The largest non-FOLD_CORE
rollup becomes a parallel v0.1.9.x ticket.

### Branch 3 — Ambiguous middle (15-30% relative; 30-60s absolute)

Either-or conditions:

- FOLD_CORE share between 15% and 30%
- FOLD_CORE absolute wall between 30s and 60s

Outcome: maintainer judgment based on the specific rollups
surfaced. Three sub-cases the synthesis must address explicitly:

- **Diffuse non-fold work**: no single non-FOLD_CORE rollup
  dominates. B2 may still be worth running because the FOLD_CORE
  recovery is meaningful even at moderate share.
- **Single dominant non-fold rollup**: one rollup exceeds FOLD_CORE
  on both percent and absolute. That rollup takes v0.1.9.x
  precedence; B2 defers.
- **Grouped non-fold rollups exceed FOLD_CORE**: sum of top-3
  non-FOLD_CORE rollups > FOLD_CORE share AND absolute. Recommend
  attacking those three in parallel rather than committing to
  compiled-core; B2 defers.

### Override branch — Non-FOLD_CORE rollup dominates

This applies regardless of the FOLD_CORE share/absolute branch:

- IF any single non-FOLD_CORE rollup share ≥ FOLD_CORE share
- AND that rollup's absolute wall ≥ 20s

That rollup becomes the highest-leverage v0.1.9 target; B2 and
ledgrcore both defer until the override target ships.

### Threshold rationale

- **30s absolute / 15% relative for the Branch-1 pivot**: 30s of
  recoverable wall is a meaningful v0.1.9 release-note number; below
  that, the engineering cost of B2 or ledgrcore (parity gates,
  ongoing maintenance) exceeds the wall recovery.
- **60s absolute / 30% relative for Branch 2**: 60s is the K1
  verdict's implied minimum compiled-recovery range; below that,
  the compiled-core ticket's wall justification is marginal.
- **20s absolute / share-equal for override**: a non-fold rollup
  worth attacking ahead of compiled-core needs to be at least
  competitive with B2's expected wall recovery.

These thresholds are calibrated to the pre-v0.1.8.10 372.55s
baseline. If the post-v0.1.8.10 baseline is materially different
(e.g. < 200s), the synthesis recomputes thresholds proportionally
and documents the change.

## Out of Scope

- **Implementing optimizations on surfaced sub-frames.** This spec
  produces an attribution and a sequencing recommendation. The
  follow-on optimization tickets are scoped in their own RFCs / spec
  packets.
- **Cross-platform measurement.** Windows-only for this spike,
  matching K1's platform. Linux / macOS re-runs are out of scope.
- **Production strategy workloads.** The spec uses LDG-2479 grid
  cell only. Real-world strategies with different feature sets, fill
  densities, or rebalance patterns may shift the attribution. The
  synthesis's confidence section must name this caveat.
- **Durable-path attribution.** Ephemeral only for this spike. The
  durable path (DuckDB writes, transaction boundaries) is a separate
  attribution question if the maintainer scopes it.
- **Comparison against the K1 spike's compiled timings.** The K1
  spike measured a minimum-viable fold loop, not the full ephemeral
  path. The attribution does not extrapolate K1's compiled numbers
  to ledgr's production wall.
- **User-supplied cost resolvers.** The E12 classification as
  FOLD_CORE applies only to the default internal
  `cost_spread_commission_internal`. User-supplied cost resolvers
  are an R-callback boundary and require separate measurement if
  scoped.

## Output Deliverable

`inst/design/spikes/ephemeral_wall_attribution_spike/attribution_synthesis.md`

Structure (mirrors v0.1.8.10's `architecture_synthesis.md` shape):

- **Header**: date, host, ledgr commit / tag (must be post-v0.1.8.10);
  citation refresh completion confirmation.
- **Headline**: top-3 grouped rollups by share; cumulative top-3
  share (≥ 80% target); FOLD_CORE rollup explicit (share + absolute).
- **Method**: brief recap of Method A function-boundary +
  instrumented-copy approach; Method B's discovery-only role;
  timer-overhead calibration result; cross-validation outcome.
- **Per-rollup attribution table**: all eight rollups with absolute
  wall (median + min/max across reps), share of TOTAL_WALL,
  contributing leaves ranked.
- **Per-leaf attribution table**: every sub-frame with exclusive
  wall, invocation count, μs/invocation, stability flag (max/min
  ratio).
- **GC bucket**: total GC wall, allocation rate, treatment in
  sub-frame timings.
- **UNATTRIBUTED**: bucket size, recovery iteration history if any.
- **Decision rule applied**: which branch (1 / 2 / 3 / override);
  what's recommended.
- **Confidence and caveats**: instrumentation-overhead bound;
  Method-A-vs-Method-B agreement on top-3 (informational); stability
  across reps; Windows-only execution; LDG-2479 specificity;
  default-cost-resolver classification; post-v0.1.8.10 substrate
  shape dependence.
- **v0.1.9 sequencing recommendation**: the top rollup(s) as
  candidate v0.1.9.x tickets in priority order, with one-line scope
  per ticket and expected wall recovery range.
- **Cross-link to ledgr horizon**: which horizon entries this
  attribution answers; pointer to the recommended ledgr-side
  horizon update.

Raw data accompanying the synthesis:
`dev/bench/results/ephemeral_wall_attribution_<YYYYMMDD>.csv` with
columns:
`run_date, ledgr_commit, rep, role, sub_frame_id, sub_frame_name,
inclusive_wall_sec, exclusive_wall_sec, invocation_count,
us_per_invocation, gc_wall_sec, total_wall_sec, notes`.

## Sequencing Constraints

Closes Codex Round-1 Findings 6 and 7 (citation refresh) plus
Round-1 sequencing concerns.

- **Cannot run until v0.1.8.10 ships.** The substrate-decision shape
  (fold-owned accounting; `ctx$vec` namespace) changes which
  sub-frames exist and how they decompose.
- **Spec drafting and Codex review can happen NOW** (this document).
- **Pre-run citation refresh gate (mandatory before any measurement
  rep starts):**
  - Verify every cited line range in the sub-frame table against the
    actual post-v0.1.8.10 commit being measured.
  - Note the ledgr commit hash used for the refresh.
  - Any citation that does not match (function refactored, line
    range shifted, function renamed/removed) is reported and the
    sub-frame is re-classified or removed.
  - The refresh confirmation is recorded in the
    `attribution_synthesis.md` header.
  - **Citation drift is a blocking failure mode**: if more than 3
    sub-frames need re-classification, the spec returns to Round 3
    review before measurement proceeds.
- **Measurement runs**: after v0.1.8.10 release-gate closes and
  citation refresh completes.
- **Attribution synthesis authoring**: ≤1 week after measurement.
- **Ledgr horizon update** with attribution result: same commit as
  the synthesis.

If v0.1.8.10's substrate-decision implementation is delayed, this
spike's run is delayed by the same amount. The spike does NOT block
v0.1.8.10's own closeout.

## Risk and Failure Modes

- **Pre-run citation refresh fails for > 3 sub-frames**: the
  post-v0.1.8.10 fold engine refactored more aggressively than this
  spec anticipated. Recovery: Round 3 spec revision before any
  measurement runs.
- **Parity gate fails at large**: instrumented copy produces
  non-byte-identical output. Most likely cause: a statement-range
  wrapper accidentally captures state mutation in a way that changes
  ordering. Recovery: audit instrumented copy line-by-line against
  production; common fix is moving the start_time / end_time
  proc.time calls outside the state mutation lines.
- **Method A coverage requirement fails (UNATTRIBUTED > 15%) on
  first pass**: means a sub-frame is missing from the hierarchy.
  Recovery path is explicit: run Method B Rprof discovery; identify
  the function(s) accounting for the unattributed mass; add wrappers
  for those functions; re-run Method A. Method B's output is the
  discovery tool, never the final attribution.
- **Method A and Method B systematically disagree on top-3
  rollups**: Method A is ground truth (per v0.1.8.9 L11). The
  disagreement is informational only; the synthesis reports the
  disagreement and characterizes which Method B frames had Rprof
  attribution artifacts (over-counting due to sampling-vs-stack
  interactions).
- **Per-rep variance exceeds 1.5x for any top-3 rollup**: that
  rollup's number is flagged as unstable; the synthesis reports a
  range, not a point. The decision rule still applies but the
  confidence section is sharpened.
- **Timer-overhead calibration shows per-call overhead > 5 μs**:
  per-pulse sub-frames at 1260 invocations have ≥ 6 ms of overhead.
  Reduce sub-frame granularity (fewer wrappers per pulse) or
  document the overhead as a confidence band on per-pulse-frame
  attributions.
- **GC bucket exceeds 20% of TOTAL_WALL**: garbage collection is a
  first-class lane in itself. The synthesis surfaces this as a
  finding; the recommended v0.1.9.x work shifts toward allocation
  reduction (which may benefit ledgrcore / B2 indirectly but is its
  own attack vector).
- **Total wall drift between uninstrumented and instrumented runs >
  10%**: instrumentation is contaminating the measurement. Reduce
  instrumentation granularity or use coarser wrappers; sub-frame
  attribution becomes wider buckets rather than fine attributions.

## Why This Spike Is Worth Running

Per the 2026-06-01 horizon entries: ledgr's compiled-core direction
(A or B2) addresses approximately 15% of xlarge ephemeral wall. The
remaining ~85% is unmeasured. Without this attribution, ledgr cannot
justify which optimization direction is the highest-leverage v0.1.9
target.

The K1 spike answered "are compiled fold cores fast?" — yes,
definitively. This spike answers "is the fold loop where the wall
lives?" — and the answer determines whether the K1 verdict's
authorization is actionable or merely informative.

The attribution is also the natural input to v0.1.9 spec-packet
authoring. Once the top rollup(s) are surfaced, each becomes a
candidate v0.1.9.x ticket and the spec packet can be cut from a
priority-ordered list rather than from speculation.

The Round-2 revisions to this spec (per Codex Round-1 review) make
the measurement methodology technically sound for the question it
needs to answer. The decision rule's absolute-and-relative
thresholds plus grouped rollups make the verdict architecturally
actionable rather than mechanically threshold-bound.
