# Cut 16 causal-history architecture audit

Revision: `36d77574c0573ba87a78118b2467c37dcb8e1cc0`; scope: the Cut 16 diff
from `0b2dd644` and its surrounding execution code. Independent review,
2026-10-20. No product code changed. Sizes are MiB (2^20 bytes).

## 1. Verdict

**Near-converged in core architecture; not converged in implementation cost.**
Keep the shared substrate, sparse two-clock facts, dense numerical panels and one fold.
A replacement SQL engine, fully dense fact cube or new execution backend is not justified.
H1 feature preparation fell from **14.57 to 10.00 seconds (31.4%)** by omitting discarded carry evidence, with identical values and retained evidence.
The five-field treatment cache contains **132.8 MiB of repeated barrier matrices**.
A fresh two-feature sweep also keeps **131.3 MiB of unread payload** alive after building its projection.
Fix these narrow ownership/projection issues before freezing the proof's memory baseline; start the real-data fact census now.
Finish the already-planned execution-core consolidation before CRAN; do not make proof contingent on a wholesale rewrite.

## 2. Essential model and floor

### Minimum information

I = 1,166 instruments; T = 7,213 sessions; N = IT = 8,410,358 cells.
The executed fixture has 8,295,060 bars, 580 complete membership headers,
347,508 member rows, 20 permanent delistings, 40 late-known inactive intervals
and five dividends. Trading-status facts are absent. This is the repository's
vendor-neutral `public_history_snapshot(..., seed = 1)`, not Sharadar data.

The system must retain:

- Stable instrument identity, ordered venue opens/closes and civil-time
  interpretation, snapshot/policy identity. Observation and knowledge are
  distinct clocks: one diagonal state plane cannot answer arbitrary two-clock
  questions after late facts revise historical masks.
- Original OHLCV and row presence. Membership must not erase nonmember bars;
  history carry must not become a valuation mark or execution price.
- Membership headers, completeness and member indexes; interval assertions;
  status precedence/correction lineage; lifetime intervals, knowledge times,
  selecting evidence and terminal labels. The durable snapshot remains the
  authority for public fact inspection; its full rows need not live in workers.
- Policy plus derived carry source/barrier indexes. Bar history uses the request
  cutoff; feature values are prepared for their own historical pulses
  (`contracts.md:1717`, `:1994`). Do not substitute final-truth features.
- One numerical series per distinct feature and non-derivable sparse
  readiness/reason/carry records. Cash, positions, FIFO lots, pending
  entitlements and mark state belong to the fold, not historical fact storage.

These are fixed-width, lossless storage floors, not claims about the
information-theoretic compressibility of this particular synthetic fixture:

| Component | Floor / compact layout at H1 | Consequence |
| --- | ---: | --- |
| Five dense double bar planes | 40N = **320.830 MiB** | Appropriate at 98.63% occupancy. |
| Values on stored bar rows only | 40B = **316.431 MiB**, plus indexing | Sparse packing saves little here; a 32-bit cell index per row alone costs 31.64 MiB. |
| Row-presence bitmap | N/8 = **1.003 MiB** | Current R logical plane costs **32.083 MiB**. Do not infer presence from nullable-field finiteness. |
| Calendar opens/closes | 16T = **0.110 MiB**, plus dates/zones/labels | Formatted axes and lookup maps are derived accelerators. |
| Membership member indexes | 4 x 347,508 = **1.326 MiB**, plus headers/offsets | Two clocks per header add about 9 KiB; full provenance rows are unnecessary for the cursor. |
| Lifetime/status | O(facts + intervals + dictionaries) | H1's two retained lifetime families actually occupy **0.155 MiB**. |
| Each double feature | 8N = **64.166 MiB**, plus sparse evidence | Two features require 128.332 MiB of numeric cells. Float32 does not preserve arbitrary exact doubles. |
| Five-field carry indexes | Five sources + one shared barrier = **192.498 MiB**, before masks/overlays | Current cache retains ten index planes instead of six. This is derived cache, not irreducible input. |
| Numeric 252-session history result | 8 x I x 252 = **2.242 MiB** | Eager evidence is a separate public-result cost. |
| Numeric full-history result | 8N = **64.166 MiB** | Eager output work cannot be sublinear in returned cells. |

A practical cold R substrate can be about **356 MiB** with current logical
presence, compact membership indexes and existing small metadata; packed
presence suggests about **325 MiB**. These are **estimates, not measured complete
implementations**. They exclude features, caches, result frames, R/DuckDB,
fetch/validation temporaries and ledger output; they are not process peak-memory
promises. Retaining arbitrary membership winner strings raises the floor, but
the normal execution provider does not expose those strings (F03).

### Measured actuals

Two-feature rows use returns(20) and returns(60). Sizes were remeasured on the
audited revision.

| Representation | `object.size()` | Serialized length |
| --- | ---: | ---: |
| Cold substrate, no features | 413.483 | 428.839 |
| Five bar planes plus logical `observed` | 352.914 | 352.913 |
| Fetched bar frame, transient (R1) | 443.068 | 482.558 |
| Provider plan | 58.828 | 74.095 |
| Calendar session frame | 0.698 | 1.364 |
| Lifetime + terminal segments | 0.155 | 0.143 |
| Two-feature vector payload | 131.317 | 130.978 |
| Two-feature runtime projection | 134.273 | 132.414 |
| Public two-feature precompute object | 265.837 | 263.719 |
| Two-feature staged worker invariant | 548.050 | 561.402 |
| Invariant after tested membership-column trim | 528.089 | 507.979 |
| Close read, lookback 252, all I instruments | 20.513 | 19.613 |
| Close read, lookback Inf, all I instruments | 553.985 | 551.097 |
| Close memo after late-cutoff reads near axis end | 96.318 | 96.263 |
| Five-field memo, end and first cutoff, 40 late overlays | 365.290 | 365.070 |
| Same memo layout, one barrier per mask/epoch | 232.510 | 232.327 |

`object.size(substrate)` does not descend into its memo environment: cache rows
measure `as.list(memo)` explicitly. Object size can count shared components
repeatedly. Serialization is uncompressed R serialization, not RDS disk size or
measured IPC traffic. Neither is private commit. Binding a projection into the
substrate does not copy numerical values just because two variables refer to it.

Sampled peak private commit, GiB: medians of three per-process maxima. Tree
columns sum parent plus discovered descendants at each sample before taking
the peak; they are not sums of independently occurring process peaks. These
cover the full R process lifetime, including setup and result extraction.

| Workflow | Current parent | Current tree | Trimmed parent | Trimmed tree |
| --- | ---: | ---: | ---: | ---: |
| Run + history reads | 2.285 | 2.286 | 2.282 | 2.287 |
| Two-worker sweep | 2.864 | 4.173 | 2.615 | 4.077 |
| Carried walk-forward | 2.243 | 2.245 | 2.231 | 2.233 |

Sweep tree peaks ranged **4.172-4.548 GiB** current and
**4.034-4.129 GiB** trimmed. GC/serialization/runtime
lifetimes affect these peaks; the difference is not all attributable to retained
object bytes. Sweep/walk-forward have no features in these timings. The separate
two-feature staging and live-payload probes above establish object sizes, not
feature-heavy workflow peak bounds. The proof must measure its actual feature mix.

### Computation and lower bounds

Wall clocks below are medians of three under Method's conditions. Profiler
percentages are sample shares, not elapsed seconds; nested shares do not add.

| Workload | Current seconds | Column-trim seconds |
| --- | ---: | ---: |
| Substrate build | 2.41 | 2.38 |
| Two-feature payload preparation | 15.15 | 15.03 |
| Payload to runtime projection | 0.22 | 0.25 |
| First 252-session close read (cold memo) | 0.66 | 0.65 |
| 100 warm 252-session close reads (batch) | 5.03 | 5.07 |
| Full-history close read | 2.09 | 2.12 |
| Public two-feature precompute | 16.91 | 17.11 |
| 7,213-pulse run with history reads | 142.97 | 144.76 |
| Two-worker, two-candidate sweep | 97.49 | 96.52 |
| Two-fold carried walk-forward | 113.14 | 111.41 |

The column-trim candidate changes only membership retention (F03); these clocks
do not demonstrate a speed improvement. The separate F02 **feature-series**
comparison excludes payload splitting and is **14.57 versus 10.00 s**, with the
same retained numerical/evidence outputs. Raw ranges and all repetitions are in
`timing-summary.json` and `times.csv`; do not add nested preparation clocks.

Here S is the header count, K_i the facts for instrument i, J the requested
instruments, L the requested sessions, D the definitions and w the window width.

| Operation | Current cost / source | Lower bound or implication |
| --- | --- | --- |
| Build substrate | Bar matching/filling O(B + N), SQL ordered fetch up to O(B log B), plus family compilation; `history-substrate.R:266`, `:1370`. H1 **2.41 s** median. | Inspect input and initialize the chosen dense output at least once. Not the main H1 run bottleneck. |
| Count membership | `history-substrate.R:859`: complete-header loop scans all headers, O(S^2), shared across instruments; incomplete sets add O(sum own_sets x relevant_sets), intervals add coverage work. | Preserve today's exact-count contract. Existing **M-8** is the route. Current complete-only counting is also quadratic in S, despite the earlier linear description. |
| Compile lifetime/status | `history-substrate.R:691`: epochs x observation breaks x resolver scans; O(sum K_i^3) with a linear resolver (lifetime; status lineage can add work). Diagonal compilation at `availability-provider-prepared.R:270` is O(sum K_i^2) under the same linear-resolution assumption. | Output-sensitive sweeps should visit affected boundaries. Output segment limits do not bound preparation work (F05). |
| Read bar history | First field use builds whole-axis indexes; later gathers O(JL) plus late overlays, then materializes/transposes evidence; `history-frame.R:91`, `:171`, `:602`, `:816`. | O(JL) eager output is unavoidable. Full history every pulse returns O(IT^2) cells even with perfect indexing; existing lazy-evidence/finite-lookback routes apply. |
| Compute features | Instrument x knowledge-range x definition loops, `history-features.R:472`; late ranges replay prefixes. Normally O(DIT), plus segment/callback cost and affected prefix lengths. | Arbitrary scalar `fn` may require every ready window; certified series do not require per-cell R callbacks. F02 removes discarded work. Late-prefix replay stays with LDG-3070. |
| Exact SMA | `features-engine.R:426`: R `mean(window)` per eligible cell, O(DITw). | A rolling sum is not automatically bit-identical to the normative R mean. Compilation must preserve arithmetic or declare a semantic change. |
| Sweep | Parent preparation, one invariant per worker, one fold per candidate; `sweep.R:308`, `:403`, `:428`. | Independent R workers each need resident inputs. Removing per-task transfer is not physical shared memory. |
| Walk-forward | One raw substrate; calculation bounded per window; chronological economic chain; `walk-forward.R:126`, `:167`, `:1190`. | Ordered transitions are essential. Prior lot/settlement/mark reconstruction is extra work; existing **Corporate-action settlement state as data** route owns it. |

Profile attribution (median sample shares of the three current-arm profiles;
sweep worker figures are medians over six worker profiles):

- Substrate: bar matching/allocation **44.3%**, SQL bar fetch
  **17.1%**, membership count **10.4%**,
  fact loading **9.1%**, provider preparation **7.6%**.
- Feature payload: input preparation **56.6%** (including canonical carry
  **40.5%**); calculation **35.6%**;
  frame construction **8.9%** and sparse exceptions **5.5%** are nested work.
- Run: decide **35.3%**, plan **16.5%**, apply
  **21.0%**, commit **16.6%**, observe/settle
  **6.0%**. History reads take **22.8%** inside decide;
  bar evidence **11.5%**, carry evidence **6.0%** and wide output
  **4.2%** are nested. The lower bound is output manifestation, not another fact resolver.
- Sweep: parent spends about **96%** waiting/collecting worker results; that is
  not CPU attribution. Workers spend **26.3%** in apply,
  **25.9%** plan, **20.0%** decide,
  **16.8%** commit and **9.6%** observe/settle.
- Walk-forward: committed test run/open **59.9%**, training sweeps
  **11.2%**, carried-opening construction **14.9%**, frozen-end
  state **7.3%**. Accounting replay takes **17.6%** across these paths.
  This is evidence for the existing settlement-state route, not a causal-history
  engine replacement. These nested shares must not be summed.

Scale-growing R loops remain in fact instrument/epoch/break scans; membership
header/interval work; feature instrument/range/definition/segment loops and
scalar callbacks; instrument-wise payload splitting/reconstruction
(`history-substrate.R:243`, `runtime-projection.R:167`); history overlay/block
loops; chronological fold/windows; and carried-lot extraction
(`walk-forward.R:1233`). Some necessarily orchestrate state or user code.
Repeated scans, frames and discarded outputs inside them are the problem, not
`for` itself. Civil-time, lineage and JSON ingest costs remain **WS45/LDG-3073**.

### Remaining representations and moving parts

This inventory excludes already-removed planes; existing routes are referenced
rather than presented as new findings.

| Representation / paths | Disposition |
| --- | --- |
| Full fetched bar frame (R1) versus dense bar planes | **443.068 MiB** transient frame during construction; released on return. Its rows and clocks are needed at the database boundary, but retaining the whole frame is a bulk-fetch choice. Chunked fill might lower preparation peak (estimate, not measured); H1 build time is already small. |
| Full membership rows/headers/intervals versus primitive execution vectors | Unused columns retained, F03. Detailed membership winner/knowledge output has only test callers via the attached resolver; the normal provider returns IDs. |
| `header_from`; segment `effective_start`, `knowledge_start`, `n_key`; provider-plan `universe_rule` | Stored but no downstream field reader found in R. Small at H1; remove with the owning constructor. |
| Lifetime and terminal segments plus diagonal lifetime codes | Same selecting facts in three projections. Cutoff history, sticky carry barrier and non-sticky execution terminal state are distinct questions. A joint compiler can emit them; H1 retained bytes are tiny. |
| `count`/`segment_count`, offsets/instrument indexes, repeated keys, axis maps and UTC strings | Derivable, mostly useful indexes. Small relative to planes. Read time names are formatted again at `history-frame.R:812` despite prepared ISO indexes. |
| Field-specific copies of `last_barrier` | Exact duplication, including late overlays; F04. |
| Feature-input carry timestamps/reasons/readiness/validity | Transient outputs immediately discarded; F02. |
| Fresh sweep/inspection payload after projection construction | Internal lifetime issue, F01; distinct from public **R27**. |
| Public payload + projection; matrix-to-vectors-to-matrix conversion | Existing **R27/R24/R25**. One carrier at consolidation. Reconstruction is only about 0.22 s for two features; retained memory matters more. |
| Eager result source times, ages, reasons and validity planes | Derivable but required by the present public contract. Bar `calculated`, `ready`, `calculation_valid` share `available` before separate transposes. Existing **Lazy evidence in history reads** route. |
| Read service and cutoff view | References, not another bar panel; cutoff binding is essential. Exposure through private context is already **LDG-3072**. |
| Provider closures capturing a substrate promise | Existing WS46 observation; never staged/serialized in production. Closure serialization is not actual worker traffic. |
| Dense matrices/by-ID frames/static views and feature path | Existing **Execution-core consolidation**. |
| Dense feature-evidence oracle | Existing **R29b**, test-only, not a production allocation. |

Counts by semantic job, not by helper names:

- Membership has **three paths**: canonical public resolution, prepared cursor,
  and mandatory two-clock counter. Status has one canonical rule and **three
  preparation shapes**: diagonal, generic bitemporal and one-fact sparse;
  the last two currently count by compiling and discarding. Lifetime has those
  three shapes plus a separate terminal pass. Sparse/generic dispatch is an
  internal fast path, not another engine. The map already gives S-4/L-3 a
  merge exit (retain only with differential and measurement), S-3 a conditional
  permanent diagonal role, and L-6/C-3 a revisit trigger at lazy evidence or
  material late-fact density. No newly discovered fast path needs a separate
  permanent exemption; keep those exits explicit during consolidation.
- Carry has **two numerical implementations**, vector C-1 and matrix C-2, plus
  cached C-3. Output carry delegates to the vector rule. Epoch discovery has
  **two implementations**, L-8. These existing routes should converge on one
  primitive with output-specific projections, not permanent extra fast paths.
- Feature execution has **four dispatch arms**: exact SMA, cached TTR call,
  supplied series function, scalar-window function. These represent different
  callback/arithmetic contracts; common admission and frame work can be shared.
- Historical reading is **one reader with two source adapters**, bar/feature;
  matrix conversion is not another reader. Providers have **two construction
  entrances**, snapshot/substrate, into one prepared implementation. Value
  carriers are substrate, runtime projection, vector payload and public
  precompute wrapper; only the first two are necessary during execution.
  Service/view are two small reference carriers. Live/result valuation has two
  implementations (V-1/V-2); valuation is intentionally distinct from history carry.
- The committed census contains **213 switch sites: 158 branches, 55 flows**,
  in 55 functions/29 files. They are not 213 engines. This confirms existing
  consolidation scope without presenting it as a new finding.

## 3. Findings

### F01 - Fresh sweep retains a now-unread feature payload

**Category:** memory, simplicity. **Locations:** `R/sweep.R:311`, `:321`, `:401`;
inspection analogue `R/pulse-snapshot.R:455`; owner `R/history-substrate.R:220`.

A dispatch-boundary probe found both `payload` and `runtime_projection` alive
in `ledgr_sweep_impl()` after conversion. It measured **131.317 / 130.978 MiB**
of payload alongside **134.273 / 132.414 MiB** of projection, and compared all
payload series exactly with the projection rows. The payload is not in the
staged invariant, but remains in the parent call frame. This corrects map
**R30**'s statement that it is dropped after projection construction. It is
new evidence about internal retention, not a repeat of public **R27**.
Inspection has the same un-released local by source inspection; that boundary
was not separately captured.

Smallest change: release the local payload immediately after projection creation
in fresh sweep and inspection. Later, build the existing projection directly
from matrices already produced. Do not add a feature engine or compatibility
fallback. Reclaimable retained bytes are measured; the reduction in end-to-end
process peak is **not measured** and depends on other live allocations and GC.

**Contract/identity:** preserves `contract-context-strict-features`,
`contract-context-feature-path` and v12 Section 7 ownership. Dropping a binding
changes no semantic identity. Direct preparation must preserve fingerprints and
evidence; editing hashed calculation helpers legitimately changes engine identity.
**Confidence:** high on retention/release; no peak-memory promise.

### F02 - Feature treatment constructs evidence its caller discards

**Category:** time, memory, simplicity. **Locations:**
`R/history-features.R:168`, `:196`, `:204`; `R/history-treatment.R:11`, `:58`;
identity binding `R/features-engine.R:65`.

Each OHLC treatment constructs source timestamps, reasons, barrier reasons and
readiness/validity vectors; the caller retains only `value` and `input_carried`.
The scratch candidate stops the **same canonical vector function** after those
two outputs exist. It substitutes neither arithmetic nor causality checks.

Full H1, returns(20)/returns(60): **14.57 -> 10.00 s median (31.4% less)** profiled
wall time. R heap maxima from `gc()` were **1497.4 -> 1277.0 MiB** (three paired
runs), not private commit. All six results (both full feature matrices **and sparse evidence**)
have identical digests. Gutting carry disclosure is detected: returns never use
carried prices but need the would-have-carried flag for `carried_input_excluded`.
This is a gain for this feature mix, not an end-to-end or arbitrary-indicator claim.

Smallest change: separate common carry calculation from evidence manifestation;
use a narrow feature-input projection and retain the full public-read projection.
Eventually merge existing C-1/C-2 through that primitive instead of maintaining
a third optimized formula.

**Contract/identity:** no numerical/evidence change to
`contract-context-strict-features` or `contract-context-indicator-computation`.
Production edits to hashed helpers change availability feature-engine identity:
record that honestly; do not evade hashes or add old-payload compatibility.
**Confidence:** high for the bounded change; other feature mixes unmeasured.

### F03 - Execution membership still retains full fact rows

**Category:** memory, simplicity. **Locations:** `R/availability-provider.R:223`;
`R/availability-provider-prepared.R:34`, `:54`, `:87`, `:177`, `:216`, `:257`, `:449`.

The current cursor reads only instrument/fact IDs from its retained set rows.
It also carries provenance/civil JSON, universe/set IDs and repeated clocks/state.
The executed candidate retains only `instrument_id`/`fact_id` in set rows and
`set_id`/`fact_id` in headers/intervals. It removes **19.96 MiB object / 53.42 MiB
serialized** from substrate and staged invariant. Two workers avoid **106.85 MiB
of serialized invariant content** (arithmetic, not measured IPC traffic).
All three paired preparation/full-read digests, full run equity and economic-event
sequences, sweep economic results and carried walk-forward outputs match exactly
after excluding wall-clock/locator fields. This H1 evidence covers complete sets;
it is not a differential over every incomplete/interval membership shape.

A further endpoint is precompiled integer member indexes. The constructed,
**size-only, non-executed** index-plan sketch is **1.439 / 1.354 MiB**, against
current membership's **58.640 / 74.027 MiB**. That extra saving is not a validated
replacement. Normal production calls `members_at()`, not its attached detailed
resolver; repository callers of that resolver are tests. Public fact inspection
resolves durable rows separately. Preserve that evidence without carrying
347,508 winner strings to each worker solely for an attached test operation.
Integer winner ranks can support differential checking against source dictionaries.

Smallest change: trim proven-unread columns now; finish preindexing and separate
execution state from diagnostic dictionaries at consolidation. Preserve complete,
incomplete, interval and rewind semantics.

**Contract/identity:** preserve `contract-availability-provider-and-timing`,
selecting evidence and exact segment-limit refusal. No public semantic or
snapshot/config identity change. Any private staging-layout version change must
be explicit. **Confidence:** high for tested trim; medium for the larger layout
until implemented/compared on non-H1 shapes.

### F04 - Every field stores the same last-barrier plane

**Category:** memory, time. **Locations:** `R/history-frame.R:91`, `:138`, `:158`,
`:171`; `R/history-treatment.R:194`.

`last_barrier` depends on expected/terminal masks, not OHLCV observations. Each
`base_<field>` and field overlay nevertheless stores a full copy. The H1 probe
checked **205 field/epoch position objects**: every barrier equals its mask's.
Moving each barrier to its mask reduces the measured cache layout from
**365.290 / 365.070 MiB** to **232.510 / 232.327 MiB**, saving
**132.780 / 132.743 MiB**. Four redundant base planes account for **128.332 MiB**.

Smallest change: one barrier in each base/overlay mask, only sources in
field-specific caches; compute the shared barrier once. This is a measured
layout/equality transformation, not an integrated reader benchmark. Speed and
process-peak effects are **unmeasured**. It requires no lazy public-result decision.

**Contract/identity:** preserve values, reasons, ages, sticky terminals and
arbitrary read order under `contract-context-pulse-data` and v12 Sections 3/5/7.
Private cache shape only; no snapshot/config identity change.
**Confidence:** high.

### F05 - Segment limits do not bound generic compilation work

**Category:** time, correctness-risk (resource exhaustion, no observed wrong answer).
**Locations:** `R/history-substrate.R:691`, `:730`, `:743`, `:778`, `:998`, `:1115`;
`R/availability-provider-prepared.R:270`.

Generic compilation iterates knowledge epochs and subsequent observation breaks;
each resolver scans the instrument's facts. The limit is checked after output
construction/binding. Status counting builds and discards segments; lifetime and
terminal repeat the generic pass. The lifetime path can do O(K^3) work yet yield a
small, accepted output. Disjoint-interval probes produced **41/81/161 segments**
for 40/80/160 facts, all within default limits. H1 has at most one lifetime fact
per affected instrument and no status facts; its sparse shortcut does not
exercise this risk.

Smallest change: use the already-required **LDG-3070** multi-row fact census to
bound actual K. If material, use an output-sensitive ordered interval sweep,
emitting lifetime/terminal projections together. Keep canonical precedence and
selecting evidence; do not add another special-case path or raise the limit.

**Impact:** worst-case mechanism established from source; H1 benefit of replacing
it is **unmeasured and likely small** (inference from fact shape). Small diagnostic
clocks are not H1 optimization evidence. **Contract/identity:** preserve
`contract-availability-provider-and-timing` counts, refusal and tie rules.
A separate work/byte budget would change contract/identity, not just internals.
**Confidence:** high on mechanism, medium on priority outside H1.

## 4. Alternative architectures

| Alternative | Concrete shape and cost/benefit | Contracts/identity and choice |
| --- | --- | --- |
| (a) Current design after planned consolidation | One substrate/fold; remove dense arms and old carriers; apply F01-F04. Bars already use columnar doubles, facts sparse indexes, feature evidence sparse runs. | **Choose this with (b)'s compact indexing.** F01/F03/F04 need no public semantic change; F02 changes implementation identity honestly. |
| (b) Columnar, index-first | Dense OHLCV/features; CSR membership headers/indexes; joint lifetime/terminal representation; shared masks/barriers; per-field source indexes. Cursors remain worker/candidate-local. | Do not make all facts dense: each integer IT plane is **32.083 MiB**; state+winner+reason cost **96.249 MiB per family**, before knowledge epochs. A diagonal cannot replace two-clock evidence. The **1.439 MiB membership sketch** is a proportionate target. Private layout needs no durable format change. |
| (c) Lazy/on-demand evidence | Values/selection/cutoff plus immutable compact evidence recipe; materialize named evidence on request. Earlier results must remain immutable and independently meaningful. | Existing **Lazy evidence in history reads** route. Much of the **553.985 MiB** eager full-read object could be avoided for numeric-only consumers; savings/speed are **estimates, not measured**. Change current explicit wide evidence matrices/long columns (`contracts.md:1738`, v12 Section 3) and version the public/identity boundary where bound. Do not accidentally retain a full substrate in every saved result. Decide before CRAN, without blocking narrow fixes. |
| (d) DuckDB/SQL preparation | Bulk-select typed columns/IDs; compile ordered intervals or carry source/barrier indexes with window queries; export planes to R. User callbacks and chronological fold stay in R. | H1 substrate build is **2.41 s**; even deleting that entire phase saves no more than its measured cost per preparation. SQL could also shift feature-input work; that benefit is **unmeasured**. Exporting N-cell index planes, collation/tie rules and two-clock/correction parity add work, and an R runtime representation is still needed. Reject wholesale migration; consider only profiled fetch/index pushdown. No callback SQL/history rereads. |
| (e) Compiled preparation kernels | Column-wise pass keeps last source/barrier per instrument and writes typed buffers; output-sensitive interval kernel replaces nested scans. Same public fold. | Fewer transposes/allocations/R callbacks are an **estimate, not measured**. First take F02's measured gain, then compile a remaining dominant kernel. Preserve canonical R as oracle; flow native implementation-version changes through existing engine identity. Do not substitute rolling sums for exact SMA or add another execution engine. |

Recommended ownership:

```text
verified sealed snapshot
 -> indexed bars/calendar/sparse two-clock facts (one owner)
 -> common masks + one barrier per instrument/knowledge epoch
 -> field source indexes -> narrow feature inputs -> one feature projection
 -> worker-local cursors -> existing fold
 -> cutoff/selection slice -> public values and requested evidence
```

Keep instrument-by-session storage for pulse reads unless paired workloads show
otherwise. A permanent transpose doubles numerical storage; gather/transpose at
the boundary instead. At H1 occupancy, universal sparse bars offer little space
advantage. Native bit/string packing could reduce R overhead, but needs its own
measurement, not an architectural dependency before proof. Estimated effort:
compact internals **days** (ranked below); wholesale SQL preparation **2-4 weeks**
with uncertain return; a bounded native carry kernel **3-5 days** after profiling;
a public lazy-evidence design **1-2 weeks** plus its contract decision. These are
engineering estimates, not measured delivery commitments.

## 5. Ranked change list

Ranking weighs demonstrated benefit x confidence against effort. Effects are not
assumed additive; effort includes differential validation.

| Rank | Change | When | Benefit / confidence / estimated effort |
| --- | --- | --- | --- |
| 1 | **F01: release fresh sweep/inspection payload at last read.** | Before proof memory baseline. | **131.3 MiB** live payload for two features; peak reduction unmeasured. High confidence; **0.5-1 day**. No public R27 redesign required. |
| 2 | **F02: narrow feature-input carry projection from one common rule.** | Before proof preparation baseline. | **31.4%** less H1 two-return preparation wall time, identical retained outputs. High confidence; **1-3 days**. Record engine-identity change. |
| 3 | **F03: trim unused execution-plan columns.** | Before two-worker proof baseline. | **19.96 MiB object / 53.42 MiB serialized** per invariant; no demonstrated speed win. High confidence; **0.5-1 day**. Finish index-only membership at consolidation (**2-4 additional days**, broader replacement not validated). |
| 4 | **F04: one barrier per mask/epoch.** | Before proof if the bound covers multiple bar fields; otherwise consolidation, with that scope limit explicit. | **132.8 MiB** less measured five-field cache layout. High confidence on equality; **1-2 days** for reader integration and reordered-read comparisons. |
| 5 | **Execute existing execution-core consolidation**, consuming R27, C-1/C-2, L-8 and dense representation/branch removal. | Before CRAN, after bounded proof fixes. | Structural simplification already routed; no new timing promise. **1-3 weeks**, depending on public R27 scope. Decide lazy evidence separately; do not turn this into a SQL/native engine rewrite. |

**Conditional:** F05's output-sensitive compiler follows the LDG-3070 fact-density
result; estimate **3-7 days** if needed. Many facts on a few instruments should
trigger it before general resource claims. Start that census immediately, without
waiting for optimizations. Existing M-8, WS45, LDG-3072 and settlement-state routes
retain their owners; this audit does not duplicate their work lists.

**Never as a response to these findings:** another execution engine, all-dense
bitemporal fact cube, process-global feature caches, a second history reader,
silent segment truncation, float32/rounded values under exact contracts, or
compiled accounting to fix preparation allocations. Reopen shared-memory workers
only under the existing measured private-commit trigger, not serialized size.

## 6. Method

Verified by source inspection and execution on the detached audited revision.
The Cut 16 R/src diff contains 53 R files, 8,015 additions and 1,152 deletions;
there are no src changes in that diff. Conclusions are about code and contracts,
not process quality. Essential-model floors and engineering effort are estimates;
object/serialization numbers and paired clocks above were executed here.

All **23** checks in `parity.csv` passed. Comparisons cover complete projection
and full-history digests; all returned run equity columns; ledger economic
columns/sequence; sweep metric/score/status/config outputs; all carried test
equity and fold fields except selection wall time. Sweeps exclude timings,
provenance/warnings and run/sweep locators; run event comparison excludes IDs
and metadata JSON. Exact means `identical()` after explicit POSIX/attribute
normalization in the checker, not a tolerance or visual inspection. The
carry-disclosure gut mutation changes the output/evidence digest. These are
bounded audit comparisons, not a claim of proof over all inputs.

Every script, raw output, profile, database and source copy is under:
`C:/Users/maxth/ledgr-wt/audit16-scratch/`. Product paths and file:line references
in Findings are relative to `C:/Users/maxth/ledgr-wt/audit16/`.

Source isolation (tracked files only):

```bash
mkdir -p /c/Users/maxth/ledgr-wt/audit16-scratch/source
cd /c/Users/maxth/ledgr-wt/audit16
git ls-files -z | tar --null -T - -cf - | tar -xf - -C /c/Users/maxth/ledgr-wt/audit16-scratch/source
```

The tracked `src` inventory contains no compiled objects. `pkgload::load_all()`
compiled this one copy during fixture creation, before workers. Candidates modify
private bindings only inside their own R process. Product source/tests/contracts
were untouched; no other worktree/branch was inspected or modified.

Every R launch used `C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe` after:

```powershell
[System.Diagnostics.Process]::GetCurrentProcess().ProcessorAffinity = [IntPtr]0xFFFF
powercfg /getactivescheme
```

The active plan was **High performance** (GUID
`8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c`); recorded parent affinity is 65535.
Host: Windows 11 Pro 10.0.26200, i9-12900K (16 physical/24 logical cores), about
64 GiB RAM. One audit R workload ran at a time, except the requested two workers
inside a sweep. No unrelated process was stopped. Host exclusivity was not
asserted; paired runs control some variability, not every background effect.

All probes/raw output live under **`C:/Users/maxth/ledgr-wt/audit16-scratch/`**:

| Files | Purpose |
| --- | --- |
| `source/`, `h1.duckdb` | Tracked source copy and synthetic sealed snapshot. |
| `source-head.txt`, `tracked-src.txt`, `cut-diff-numstat.txt`, `hardware.txt`, `conditions.txt`, `processes.txt` | Revision, source inventory, hardware and launch conditions. |
| `audit_probe.R`, `audit_workflow_probe.R`, `run_probe.ps1` | Measurement runners. `base` means audited **36d77574**; `compact` retains fewer membership columns. It is not a comparison with pre-cut `0b2dd644`, whose history API/semantics differ. |
| `extra_probe.R`, `extra-times.csv`, `extra-sizes.csv`, `extra.log`, `extra.err` | Full-H1 carry-output comparison, cache-layout/index-plan sizes and exploratory lifetime shapes. Small diagnostic clocks remain raw, not reported optimization timings. |
| `lean-parity.txt`, `barrier-parity.txt`, `gut.txt`, `bar-count.csv` | Exact matrices/evidence, barrier equality, erased-disclosure gut detection, stored bar count. |
| `transient_probe.R`, `transient.log`, `transient.err`, `live-payload.csv`, `fresh-sweep-live-bindings.txt` | Live payload capture at fresh-sweep dispatch. |
| `bar_frame_probe.R`, `bar-frame.log`, `bar-frame.err`, `bar-frame-size.csv` | Full fetched bar-frame size only, outside timed workloads. |
| `times.csv`, `prep-{base,compact}-{1,2,3}-sizes.csv`, per-workload `.log`/`.err`, `*-checks.rds`, `*-equity.rds`, `*-result.rds` | Raw timings, sizes and comparison inputs. |
| `*.Rprof`, `*-profile-total.csv`, `*-profile-self.csv`; `worker-<PID>*` | Parent and sweep-worker profiles; worker PIDs map through the process-tree record. |
| `peak-memory.csv`, `*-memory.csv` | Sampled private-memory peaks, not RSS. Descendants discovered every 2 s; sampling every 250 ms can miss brief spikes. Includes owned R/DuckDB/runtime/transport processes only. |
| `summarize.py`, `timing-summary.json`, `analyze.py`, `attribution-summary.json`, `check_audit.R`, `check-audit.log`, `parity.csv`, `session-info.txt` | Summaries, profile attribution, diff-based output checker and R environment. |
| `finalize.py`, `audit_draft.md`, `audit_final.md`, `harness-notes.txt` | Report derivation and recorded harness corrections. |

Run sequentially in scratch, using fresh output names for new repetitions:

```powershell
& 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe' source/dev/bench/v0_2_2_public_history/run_workload.R C:/Users/maxth/ledgr-wt/audit16-scratch/source C:/Users/maxth/ledgr-wt/audit16-scratch/h1.duckdb build build.csv --label=36d77574
& ./run_probe.ps1 -Mode prep -Reps 3
& 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe' ./extra_probe.R
& ./run_probe.ps1 -Mode run -Reps 3
& ./run_probe.ps1 -Mode sweep -Reps 3
& ./run_probe.ps1 -Mode wf -Reps 3
& 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe' ./check_audit.R
& 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe' ./bar_frame_probe.R
python ./summarize.py
python ./analyze.py
python ./finalize.py
```

Apply affinity before direct R calls too and verify High performance. Do not
rebuild the existing evidence database in place when preserving this run; create
a new scratch root and update the scripts' root literal. The fixture build was
setup, not a three-pair clock; its single raw timing is deliberately not quoted.
The sweep runner also executes the transient size probe before its timed batch.

Both timed arms use `Rprof(interval = 0.01)`: these are **profiled wall clocks**,
not uninstrumented release benchmarks. Windows samples cover only part of wall
time, so percentages are sample attribution. Load/compile, snapshot-open
verification and experiment construction precede timing; entry-point preparation
inside each API call is included. Post-run `ledgr_results()` extraction is outside
the run clock. These are API-call clocks over a prepared fixture, not cold
end-to-end ingestion claims. Prep size probes serialize large objects and must
not be used as production peak-memory bounds.

The standalone reader requests all 1,166 IDs, wide close, `na_action = keep`.
Its warm clock is 100 backward reads near axis end with lookback 252, not 100
fresh processes. The full run uses monthly equal weighting, a 21-session read
every pulse and a 252-session read at monthly rebalance. Sweep uses two candidates
(0.9/0.95), two workers, no features or history-read callback. Walk-forward uses
two contiguous carried test folds over about the final 60% of the axis,
250-session training windows and the same candidates, one worker, no features.
Separate feature clocks cover returns(20)/returns(60) over full H1. No timing
claim extends to arbitrary callbacks, fourteen-feature catalogues or many late facts.

Every walk-forward arm receives a fresh database copy before timing; the public
API otherwise reuses completed test runs by deterministic identity. Failed
harness startups are documented in `harness-notes.txt`: UTF-8 BOM parsing and
passing `features = NULL` instead of an empty list failed before measured
execution. The NULL-feature logs are preserved; the BOM launch survives in the
process record/tool transcript, and its per-tag log was overwritten. Failed
launches are excluded from all summaries. Locale warnings and
the source-copy git lookup warning remain in raw logs. None caused a product,
fixture or oracle change.
