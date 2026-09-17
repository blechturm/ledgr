# v0.2.0.1 Hot-Path Complexity Audit

**Status:** Corrected after independent peer review; ready for focused
verification. Analysis and bounded probes only; no production code,
dependency, spec, ticket, benchmark report, or governance artifact was
changed.

**Source:** `6b09a1b57ff42293091130d2dca565f224a29aea` on `v0.2.0.1`.
**Run:** 2026-09-17 on Windows, R 4.6.1, duckdb 1.5.2, testthat 3.3.2,
collapse 2.1.7, 24 logical cores. The probe was serial and no other R process
was observed before launch.

## Question and scope

Is the confirmed event-buffer copy defect the only asymptotically avoidable,
material release blocker exercised by the registered v0.2.0.1 workloads, or
does another nonlinear cost belong in the same narrow amendment before
closeout? The audit covers snapshot/seal, preparation/provider, the fold and
diagnostics, accounting/events/valuation, finalization, and results. It
classifies existing code and runs bounded current-path probes; it neither
implements nor accepts a repair.

## Executive disposition

**Event-buffer remediation alone is not the smallest complete nonlinear-cost
amendment for v0.2.0.1.** Two findings pass the maintainer's three-part release
test:

1. the memory and durable event buffers perform repeated full-vector copies,
   making event insertion `O(E^2)` rather than the necessary `O(E)`; and
2. availability valuation rescans every instrument's entire price prefix and
   linearly rematches every axis member against the complete instrument vector
   on every pulse, making a full run `O(N*P^2 + N^2*P)` rather than
   `O(N*P)`.

Both are asymptotically avoidable, both are exercised by a registered release
workload, and both are material now. At 200 instruments, the event write
function alone held 38.18% of sampled self time in the profiled memory harness
and 23.7% in the durable harness. Valuation held 67.7% of captured in-loop
samples in the registered zero-fill availability record.

No third finding passes all three tests. FIFO lot growth, strict-window feature
hydration, terminal recovery, availability result reconstruction, and parts of
finalization do have avoidable nonlinear shapes. They are not material on a
registered v0.2.0.1 workload, are not exercised there at their problematic
dimension, or belong to an excluded compiled/recovery/reader path. They should
be routed to the roadmap rather than reopening this release further.

| stage | present cost | lower bound | evidence at release shape | disposition |
| --- | --- | --- | --- | --- |
| memory event buffer | `O(E^2)` | `O(E)` | 38.18% self at 200 instruments; per-fill wall doubles by 350 | amend |
| durable event buffer | `O(E^2)` | `O(E)` | 23.7% self at 200 instruments | amend |
| availability valuation | `O(N*P^2 + N^2*P)` | `O(N*P)` | 67.7% of zero-fill in-loop samples | amend |
| provider | `O(A log A + N*P)` | `O(A + N*P)` | 0.26% in reviewed prepared-provider profile | already corrected |
| diagnostics | `O(D)` | `O(D)` | block writer completes the 757-pulse record | already corrected |
| dense finalization | `O(N*E + N*P + E*L)` worst case | `O(E + N*P)` | 1.53 s, 4.6% of 200-instrument durable engine | later |
| R FIFO lots | `O(E*L)`; repeated opens `O(L^2)` | `O(E + consumed lots)` | problematic `L` not present in release fixtures | later |
| strict features | `O(B*F*W)` | `O(B*F)` | availability record has no features | later |
| availability/read recovery | `O(T*E + T*N*P)` or worse | `O(E + T*N)` | not in registered timed surface | later |

Here `N` is instruments, `P` pulses/sessions, `B` bars, `E` ledger events or
fills, `D` diagnostic rows, `F` features, `L` open lots, and `A` availability
facts. `T` is the number of requested result/recovery times. The full inventory
is in `complexity_inventory.csv`.

## Method and release rule

The audit traced one lifecycle:

```text
snapshot/seal -> preparation -> fold -> valuation/accounting/events
              -> finalization -> results
```

Static inspection established the operation that grows with each scale
variable. Bounded execution then tested whether that mechanism is visible at
release-relevant shapes. Timing alone was never used to assign Big-O.

A finding enters the proposed v0.2.0.1 amendment only when all are true:

1. the excess complexity is avoidable;
2. a registered release workload exercises the path; and
3. it is about 20% or more of current runtime, or produces a clear cliff before
   a two-times-larger workload.

The eventful probe reused the peer harness's SMA 5/10 strategy, 1,260 sessions,
seed 20260530, zero costs, and no risk chain. It varied instruments while
holding sessions fixed. One run was made per point because these are diagnostic
scaling observations, not publication-quality benchmark estimates. Memory and
durable runs at 200 instruments were sampled with `Rprof()` at 10 ms. The
valuation probe varied one dimension at a time and called the production
function across every pulse. The open-lot probe exists only to classify a
later-path hypothesis.

Parity preceded interpretation: at each shared instrument count, memory and
durable runs produced the same fill count and final equity within floating
tolerance. No candidate implementation was run or compared.

## Verified finding 1: both event buffers are quadratic

The memory handler stores sixteen typed columns in an environment
(`R/sweep.R:1516-1546`). For each event it extracts a column to a local
variable, changes one element, and assigns the column back
(`R/sweep.R:1574-1595`). Six columns are character and one is a list. Those
seven columns use base replacement; the extra live reference causes the whole
current-capacity vector to be copied for a scalar write. Numeric, integer, and
POSIXct columns already use `collapse::setv()`.

The durable handler has the same shape for six character columns
(`R/backtest-runner.R:328-343`, `:379-395`). The buffer starts at 1,024 rows
and doubles as required (`R/fold-event-buffer.R:1-36`). Geometric resizing
alone is amortized `O(E)`, but copying six or seven current-capacity columns on
every event is not. Summed across growing capacity, it is `O(E^2)`.

The memory full-fold observations reproduce the growing per-fill cost:

| engine | N | fills | engine s | microseconds/fill |
| --- | ---: | ---: | ---: | ---: |
| memory | 50 | 6,957 | 5.13 | 737 |
| memory | 100 | 13,684 | 9.86 | 721 |
| memory | 200 | 27,396 | 26.29 | 960 |
| memory | 350 | 47,838 | 69.64 | 1,456 |
| durable | 50 | 6,957 | 9.48 | 1,363 |
| durable | 100 | 13,684 | 14.57 | 1,065 |
| durable | 200 | 27,396 | 33.29 | 1,215 |

For the memory engine, 7 times the instruments produces 6.88 times the fills
but 13.58 times the engine wall. Cost per fill is flat through 100 instruments,
then doubles by 350 as buffer capacity grows. At 200 instruments,
`set_event_value` has 38.18% of sampled self time and 50.8% total time; garbage
collection adds 13.7%. The durable equivalents are 23.7% self, 34.2% total,
and 15.1% garbage collection. These are sampled shares of the complete harness
call, not a wall partition. The three durable scaling points do not themselves
show a rising normalized curve. The durable classification rests on its
identical extract/mutate/reassign mechanism across six character columns plus
the independently material 23.7% writer profile share; its post-repair scaling
curve remains an acceptance gate.

The registered 500 by 1,260 record and the maintainer-supplied investigation
report about 68,201 fills and 124-127 seconds for the memory engine, consistent
with the curve. Its scratch candidate reported about 25 seconds, but this audit
does not treat that candidate as production evidence: it did not prove exact
persisted equality and did not cover the durable handler.

The release correction should raise the floor to `collapse >= 2.1.8` and use
the fixed character/list write barrier for in-place writes in both handlers.
The temporary unbind/mutate/rebind mechanism remains a credible alternative:
it avoids a dependency-floor change and produced the earlier 5.1-times memory
speedup. It is not the preferred shipping design because it temporarily removes
a required buffer binding, needs explicit restoration across errors and user
interrupts, and has not been measured on the durable handler. Collapse 2.1.8
provides the intended by-reference operation with the corrected R write barrier.
Both routes still require measured comparison before the implementation choice
is accepted. Exact event order, IDs, metadata, fills, trades, equity, strategy
state, telemetry, rollback, interruption, resume, and durable/memory parity
remain gates.

## Verified finding 2: valuation repeatedly rescans price history

`ledgr_availability_valuation_marks()` loops over every current axis member and
runs these operations at pulse `i` (`R/availability-economics.R:16-19`):

```r
row <- match(id, instrument_ids)
which(is.finite(bars_mat$close[row, seq_len(pulse_idx)]))
```

Across all pulses, the prefix operation inspects exactly
`N * P * (P + 1) / 2` close cells to emit `N*P` current marks. The fresh
linear `match()` adds `O(N^2*P)` work when the axis and source-instrument
vectors grow together. The combined cost is therefore
`O(N*P^2 + N^2*P)`, or `O(N*P*(N+P))`, for a result whose lower bound is
`O(N*P)`. At the registered 505-member axis, 563-instrument source, and 757
pulses, the match term performs about 215.2 million comparisons and the prefix
term inspects about 144.9 million close cells. The path runs at every
availability-aware fold pulse (`R/fold-engine.R:388-403`).

The direct probe records the exact prefix work count but does not isolate the
lookup term:

| N | P | scanned cells | seconds | microseconds/output cell |
| ---: | ---: | ---: | ---: | ---: |
| 200 | 252 | 6,375,600 | 1.27 | 25.2 |
| 200 | 504 | 25,452,000 | 2.62 | 26.0 |
| 200 | 756 | 57,229,200 | 3.95 | 26.1 |
| 200 | 1,260 | 158,886,000 | 6.91 | 27.4 |
| 50 | 504 | 6,363,000 | 0.67 | 26.6 |
| 500 | 504 | 63,630,000 | 7.70 | 30.6 |

At fixed 504 pulses, nanoseconds per scanned prefix cell rise from 98.2 at 100
instruments to 121.0 at 500 instruments, consistent with additional work not
represented by the prefix-cell denominator. Across pulse counts, elapsed time
still looks nearly linear in output cells rather than quadratic in scanned
cells because R-loop and per-result allocation costs dominate the short vector
scans at these sizes. The Big-O classification therefore comes from the exact
source operations, not curve fitting. Materiality comes independently from the
registered 563-instrument, 505-axis, 757-pulse zero-fill record: median warm
wall 25.42 seconds, with valuation at 67.7% of captured in-loop samples. That
record exercises no event-buffer work.

The smallest correction is transient valuation state prepared once per run:
an instrument-to-row index prepared once, plus last finite close, source
index/time, and age advanced once per pulse for the axis. It may be a primitive
plane or monotone cursor, but it must remove both repeated matching and prefix
rescanning, reduce the full fold to `O(N*P)`, preserve gaps and staleness
exactly, and remain outside snapshot/config/run identity. Exact parity cases
must include never observed, current, stale, expired, re-entering members, held
former members, terminal events, and the stop boundary.

## Verified non-findings on current release workloads

### Provider, diagnostics, and seal

The production provider has one prepared path
(`R/availability-provider.R:245-246`) backed by primitive membership state and
CSR segment cursors (`R/availability-provider-prepared.R:165-323`). Its
queries are output-bound at `O(N*P)` after `O(A log A)` preparation. The
reviewed provider profile put it at 0.26% of the fold.

Ordinary diagnostics are built once per pulse and written through bounded
typed chunks (`R/availability-diagnostic-writer.R:42-175`). Their work is
`O(D)`, which matches the persisted-output lower bound. The old row-list and
final-bind discontinuity is absent.

The seal validators are grouped sweeps rather than pair loops. The Stage H
record measured the availability seal-validation phase at 1.18 seconds and
cold end to end at 93.06 seconds. Remaining timestamp, JSON, hash, and write
work is linear in `B` or `A`. It may have reducible constants, but no remaining
release-scale nonlinear seal blocker was established.

### Dense feature preparation

The peer fixture supplies series functions. The preparation path computes each
feature series once per instrument (`R/precompute-features.R:538-555`), so its
fundamental work is `O(B*F)`. The eventful probe's experiment-setup observations
were 0.11-0.50 seconds and did not grow materially. That does not generalize to
strict availability hydration, discussed below.

### Routine finalization and results

Dense durable finalization still has avoidable structure. It scans the entire
event instrument column once per instrument to construct positions
(`R/run-finalize.R:527-541`) and replays every event through R lot accounting
(`:552-589`), for worst-case `O(N*E + E*L + N*P)`. At 200 instruments it took
1.53 seconds, 4.6% of the durable engine wall. Memory result construction was
0.89, 1.67, 3.33, and 6.19 seconds at 50, 100, 200, and 350 instruments,
respectively. Those observations are broadly output-linear and below the
release threshold.

Availability finalization also parses and reconstructs positions/lots before
discarding them when fold-supplied equity is used (`R/run-finalize.R:503-589`).
That is real avoidable work, but the registered availability fixture has zero
events. It is not a third v0.2.0.1 amendment item under the agreed rule.

## Roadmap items: verified later nonlinear work

These are real code shapes, not authorized release work.

- **Open lots.** `ledgr_lot_set()` recalculates basis over all open lots after
  every fill (`R/lot-accounting.R:21-25`, `:54-67`). Repeated same-side opens
  therefore approach `O(L^2)`: 100, 500, 1,000, and 2,000 accumulated lots
  took 0.02, 0.20, 0.87, and 3.34 seconds. The peer strategy only toggles each
  instrument between targets 0 and 1 (`peer_benchmark.R:139-178`), bounding
  open lots per instrument; the availability fixture has no fills.
- **Strict features.** The strict path creates a frame for every trailing
  window, checks columns, calls the scalar function, then calls the series
  function again for parity (`R/features-engine.R:286-343`). Its shape is
  `O(B*F*W)` plus frame allocation. The release availability record has no
  features, while the peer record uses the vectorized series path.
- **Compiled lot packing.** Every compiled batch packs and unpacks all open
  lots (`R/compiled-spot-fifo.R:93-141`, `:144-190`), an `O(Q*L)` boundary.
  Compiled availability expansion is expressly outside v0.2.0.1 and no
  compiled row exists in the closeout record.
- **Terminal recovery.** Recovery calls `ledgr_state_asof()` for every achieved
  pulse and invokes prefix-scanning valuation for held names
  (`R/run-finalize.R:149-199`). That implies repeated database queries and
  event replay, roughly `O(P*E + N*P^2)`. It is a recovery/correctness path,
  not routine completion in either registered record.
- **Availability results.** Each requested time queries and replays events to
  that cutoff, calls one history read per axis member, rebuilds a prefix matrix,
  and binds one frame per time (`R/availability-results.R:243-358`). The
  registered availability closeout retrieves diagnostics after the timed run;
  it does not invoke the availability result view.
- **Execution-time evidence matching.** The availability convention searches
  all diagnostics and sessions for every fill (`R/execution-timing.R:131-190`),
  giving an avoidable `O(E*(D+P))` join. Dense peer fills take the early direct
  timestamp branch, so this shape is not exercised there.

These should become profile-triggered roadmap entries, not a package-wide loop
cleanup. The next governance/test-suite review can establish common standards
for their future probes.

## Caveats and hypotheses not established

- The maintainer-supplied old peer record attribution names source
  `f115bfab386746ad8b8728d22786b52e388abba3` under R 4.5.2, while the
  provisional current record is source `6b09a1b...` under R 4.6.1. The complete
  old raw bundle is present locally, including its 79.39-second memory-engine
  row. A matched source/runtime experiment was possible but outside this
  bounded audit and was not run, so the audit does not attribute the
  cross-record 79-to-124-second difference to either source or R.
- The prior scratch event-buffer candidate's roughly 25-second result is
  promising, not acceptance evidence. Exact persisted parity, the durable
  handler, failure safety, interruption/resume, and collapse 2.1.8 remain to
  be tested.
- The direct valuation curve did not empirically become quadratic by 1,260
  pulses even though its exact work count does. A production alternative's
  wall benefit must be measured rather than forecast from Big-O alone.
- No peak-working-set comparison was made in this audit. The release rerun must
  retain the existing external memory sampling.

## Recommended smallest amendment

Amend v0.2.0.1 once, then rerun closeout once:

1. raise the declared floor to `collapse (>= 2.1.8)`;
2. linearize character and list writes in both the memory and durable event
   handlers, with no option seam or old shipping path;
3. replace fold-time availability prefix rescans and repeated instrument-row
   matching with prepared primitive valuation state whose total run cost is
   `O(N*P)`;
4. add no FIFO, feature, finalization, result-reader, compiled, schema, public
   API, hash, identity, or broader loop work; and
5. move the current Batch 8 records to provisional evidence and rerun them from
   the accepted final source.

The two implementation topics should have separate correctness/performance
gates even if they share one packet amendment. Event-buffer acceptance needs
the 50/100/200/350/500 curve for both handlers, a flat normalized event cost,
external peak memory, and exact durable outputs. Valuation acceptance needs
full view/equity/diagnostic parity across gap and stale-mark cases, a pulse and
instrument scaling curve, and the registered 757-pulse record. A bounded
eventful availability case should then exercise both corrections together.

After independent review and implementation review, rerun the availability
cold/warm record, the pinned peer record, the full test/check/documentation
gates, and the final profiler. Results remain internal and non-ranking.

## Reproduction and evidence

Exact probe command from the repository root:

```powershell
$env:TEMP='C:\tmp'
$env:TMP='C:\tmp'
& 'C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe' `
  'dev/spikes/v0_2_0_1_hot_path_complexity_audit/probe.R'
```

Evidence files:

- `environment.csv`: source/runtime provenance and concurrency statement;
- `eventful_scaling.csv`: memory and durable phase clocks, fills, normalized
  costs, finalization, and final equity;
- `eventful_profile_top.csv`: top 30 sampled functions for each 200-instrument
  eventful run;
- `valuation_scaling.csv`: exact scanned/output cell counts and timings;
- `lot_scaling.csv`: later-path open-lot stress observations;
- `availability_record_extract.csv`: concise extraction from the existing
  ignored Stage H raw record; and
- `complexity_inventory.csv`: lifecycle complexity classification.

`checker.R` validates required files, grids, cross-handler fill/equity parity,
the writer materiality thresholds, exact valuation work arithmetic, the
registered valuation share, lot stress shape, and release classifications.

The probe ran once per eventful and valuation scale point. Windows `Rprof()`
does not sample every wall interval, and profiling covered each complete peer
harness call rather than only the engine phase. Absolute timings are therefore
diagnostic, not release benchmarks. The eventful fixture used 350 instruments
generated once and stable subsets for smaller points, so its values differ
slightly from separately generated peer rows while preserving the workload
shape. Expected final-bar no-fill warnings were retained. No peer engine, full
peer suite, full test suite, seal, package check, or candidate implementation
was run.

Temporary bars, databases, and profiles were created under `C:\tmp` and
removed by the probe. The measured probe completed on its first resumed
attempt in 268 seconds. It retained the expected final-bar no-fill warnings
and had no failed cell or rerun. The checker completed in under one second and
reported `COMPLEXITY_AUDIT_CHECKS_OK: 14 checks`.

## Containment

The audit owns only
`dev/spikes/v0_2_0_1_hot_path_complexity_audit/`: `probe.R`, `checker.R`,
`findings.md`, `environment.csv`, `complexity_inventory.csv`, and the five raw
measurement/extract CSVs listed above. Two coverage `.gcda` files emitted in
`src/` when the source package loaded were removed after their paths were
verified inside the repository. No audit scratch directory remains under
`C:\tmp`.

The pre-existing tracked changes under `dev/bench/` and `docs/pkgdown.yml`
were preserved byte-for-byte; the tracked peer report was read only as
provisional context and does not substitute for an audit raw CSV. The
unrelated untracked `dev/spikes/asset_availability_pit/` directory was not
enumerated, read, edited, staged, or removed. The audit made no
production, dependency, spec, ticket, benchmark-report, closeout, governance,
or index change and staged or committed nothing. It is ready for independent
peer review; its author does not approve its own classifications.
