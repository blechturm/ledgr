# Workstream 7 Closeout: Feature-Accessor Scaling

**Status:** Agent-provisional; awaiting Type 1 close review.
**Date:** 2026-10-03
**Implementation range:** `9064743..eb5d2a9`
**Tickets:** LDG-2938 through LDG-2940

## Outcome

Both candidates cleared their preregistered current-tree five-percent gates
and shipped. Commit `726d87e` prepares scalar feature lookup state once per
run-local context factory. Commit `eb5d2a9` removes duplicate explicit-map
validation and gives each bundled accessor an exact last-successful-map memo.

There is no package-global cache. Prepared state is owned by one run and one
sweep candidate. Public context fields, feature-map identity, values, errors,
workers and vector accessors are unchanged.

## LDG-2938: Prepared Accessors

The baseline was `9064743`, after accepted Workstream 6. The existing
`dev/spikes/feature-accessor-lookup/spike_runner.R` loaded that current tree
and applied its prepared-accessor seam only in memory. One R 4.6.1 process
alternated production and candidate arms for three repetitions on one sealed
500-instrument, 1,260-pulse fixture. Every kept release-shape row recorded no
other R process and less than one other busy CPU core.

| Public path | Production median | Candidate median | Saving |
| --- | ---: | ---: | ---: |
| `ledgr_run()` | 56.291 s | 49.605 s | 11.9% |
| canonical `ledgr_sweep()` | 32.822 s | 25.837 s | 21.3% |
| compiled spot-FIFO sweep | 27.086 s | 20.107 s | 25.8% |

All 48 public parity comparisons and all 33 call-shape comparisons were
exact. Public surfaces included fills, equity, trades, sweep columns and
retained results. Call shapes covered active aliases, explicit maps, scalar
features, unknown instruments and feature IDs, defaults and uneven
availability input.

At 500 instruments, the current-tree allocation probe measured:

| Operation | Production | Prepared |
| --- | ---: | ---: |
| bundled active-map read | 17.53 us and 4,048 heap bytes/call | 7.41 us and 0 recorded heap bytes/call |
| scalar feature read | 2.85 us and 0 recorded heap bytes/call | 1.58 us and 0 recorded heap bytes/call |

`Rprofmem` records R-heap allocation, not peak working set. Preparation itself
rose from 280 bytes to 41,744 bytes at width 500, once per run-local factory;
the repeated read savings dominate at the registered 630,000-call shape.

Production now creates one prepared object in
`ledgr_fast_context_state()`. It contains hashed instrument, universe and
feature-ID lookup environments and one normalized active alias map. The same
object serves `ctx$feature()` and `ctx$features()` for that run.

## LDG-2939: Explicit Maps

The paired gate used post-LDG-2938 baseline `726d87e` and
`dev/bench/v0_2_2_workstream7/explicit_map_benchmark.R`. Its only candidate
binding was the planned run-local bundled accessor. It alternated three arms
per workflow on the same 500 by 1,260 shape and recorded no other R process.

| Public path | Production median | Candidate median | Saving |
| --- | ---: | ---: | ---: |
| `ledgr_run()` | 136.567 s | 45.956 s | 66.3% |
| one-candidate `ledgr_sweep()` | 117.511 s | 25.440 s | 78.4% |

All twelve timed semantic comparisons were exact. The gate evidence is under
`ws7_explicit_map_evidence/`.

The separate baseline micro probe measured 5,000 calls:

| Arm | Time/call | Recorded heap bytes/call |
| --- | ---: | ---: |
| duplicate production validation | 137.53 us | 0 |
| one full validation | 74.76 us | 0 |
| exact last-map memo | 8.07 us | 0 |

Its four single-run clocks are orientation only; they were not interleaved and
are not an effect estimate. The paired table above is the registered public
gate.

`ledgr_feature_lookup_map()` now performs the existing full object validation
once, checks unresolved declarations and reads the validated concrete IDs.
The bundled accessor caches only a successful concrete feature map and its
lookup. Reuse requires `identical()` on the next object. Before any
non-identical attempt the memo is cleared, so failed inputs cannot leave a
reusable prior or failed entry. Character maps are normalized but not cached.

An independently rebuilt equal-looking map is not necessarily identical in R
because its indicator closures differ. The detector therefore requires fresh
validation for that case. This is the conservative behavior bound by the
ticket.

## Detectors And Mutations

| Claim | Detector | Failure probe |
| --- | --- | --- |
| values, defaults and errors remain exact; preparation happens once | LTB-0139 / LCL-0139 | shifting every instrument row produced more than 38 failures; repeated-read counters require one preparation and one alias normalization |
| prepared state stays candidate-local | LTB-0140 / LCL-0140 | a two-candidate sweep must observe separate environments and `signal = sma_2` then `signal = sma_3`; hoisting the first object fails those observations |
| explicit maps validate once and memoize only exact success | LTB-0141 / LCL-0141 | set-insensitive reuse fails ordered output and changes nine validations to seven; retaining state across a failed map changes nine to eight |

LTB-0141 covers repeated, rebuilt-equal, reordered, parameterized and
unresolved, tampered, swapped-alias, unknown-feature, character and non-map
inputs. Literal values or condition classes and messages are pinned where the
input reaches them. The pre-implementation micro probe's fifteen-step sequence
also matched production in every validate-once and memo arm.

## Seven-Shape Walk

1. Repeated lookup: instrument, universe and feature membership are indexed
   once; repeated named-vector membership and subsetting are gone.
2. Growing scans: no accessor scans pulse history or prior calls. `identical()`
   compares only the caller-supplied map, whose size is the requested bundle.
3. Per-element work with a batch replacement: no collection-level batch can
   replace path-dependent strategy reads; the fix removes setup from each read.
4. Scale-growing collections: lookup environments are bounded by the fixed run
   universe and registered feature set. The memo contains one map only.
5. Recomputed discarded work: active alias normalization and full map
   validation are no longer recomputed and discarded on every read.
6. Frame construction: no data frame is created by preparation or lookup.
7. Mutation and copy shape: prepared environments and closure memo state are
   run-local. No cumulative result or caller-owned map is mutated.

The remaining accessor work is proportional to requested feature count, not
universe width or call history.

## Evidence Incidents

The first broad accessor launch left an R child alive when its five-second
wrapper timed out. A second launch then saw that process, and both runners
replayed every pair under the load rule. Both exact PIDs were stopped; the
contaminated timing files were overwritten by the clean run reported here.

The first explicit-map benchmark completed the run arms but failed while
normalizing sweep attributes after removing timing columns. No result was
accepted. The normalizer was replaced with the established sweep comparison
shape and the whole gate was rerun from scratch into the recorded evidence.

## Boundaries And Verification

There is no public API, schema, run or snapshot identity, hash, tolerance,
default, persistence, worker or failure-semantics change. The Context Contract
now records only the internal run-local ownership and exact reuse rule. Vector
accessors, availability semantics, `db_live` and accounting engines are
unchanged.

The focused accessor, feature-map, pulse-context and prior exact-parity suites
pass. The post-LDG-2939 ordinary fast profile executed 500 of 500 blocks with
zero failures or skips in 82.920 seconds. The gate checker returned
`LEDGR_TEST_GATE_OK` against the 112-second bound. Its record is at
`C:/tmp/ledgr-ws7-2939-fast`.

Cut 2 has three completed review invocations before this request: its combined
cut review and the two Workstream 6 review rounds. The requested Workstream 7
close review is invocation four over eleven tickets, 0.364 against the 0.5
gate.
