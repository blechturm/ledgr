# v0.1.8.9 Optimization-Round Architecture Synthesis

**Date:** 2026-05-31 (Round 2 revision) - **Host:** local development host
- R 4.5.2, collapse 2.x, duckdb 1.x, jsonlite 2.0.0, yyjsonr 0.1.22 -
**Status:** v0.1.8.9 spec input (pre-RFC).

**Synthesizes:** the fourteen spikes in this directory's `README.md` and
`spike_tickets.md` (Spikes 1-14 across Rounds 1 and 2), the LDG-2476
three-phase peer benchmark, the LDG-2479 self-profiling workload grid,
the prior cycle's v0.1.8.7 optimization-round synthesis
(`inst/design/spikes/ledgr_optimization_round_spike/architecture_synthesis.md`),
and the Codex peer review (Round 1) that triggered the Round 2 corrections.

**Why this exists:** ledgr's apparent peer-benchmark regression
(LDG-2476: ~3x Backtrader on the durable xlarge cell) decomposed into a
per-fill scaling problem on the workload grid (LDG-2479: 931 us/fill at
100 inst -> 3107 us/fill at 1000 inst, same density). The v0.1.8.9 round
asks where that scaling lives and whether it is architectural or
removable. The fourteen spikes answer both. These are the lessons.

## Revision History

**Round 1 synthesis (Spikes 1-10):** Original synthesis written
2026-05-31. Submitted to Codex for peer review.

**Codex peer review (Round 1):** identified three blocking findings:
1. Spike 4 not faithful to default durable path (per-row DBI INSERT
   measurement applies to live mode, not buffered mode used by the
   workload grid). `R/backtest-runner.R:425-435` already batches via
   `pending_cols`.
2. Spike 7's writeup describes the buffer as a list of vectors; it is
   actually an environment with vector slots
   (`R/fold-reconstruction.R:155-170`). Mechanism unchanged.
3. Spike 7's wall translation is too direct - production durable goes
   through a chunked extractor (`R/backtest.R:1021`,
   `stream_threshold = 100000L`).

**Round 2 spikes (Spikes 11-14):** four follow-up spikes closed these
gaps with measured numbers:
- **Spike 11 (LDG-2490):** persistent durable handler `pending_cols`
  buffer measurement. **140x speedup; 167s isolated; ~50-80s production
  recovery on xlarge.** Replaces Spike 4 for the default durable path.
- **Spike 12 (LDG-2491):** chunked extractor real-path wall recovery.
  **4.6x speedup; 186s isolated recovery at 133k events; ~150s
  production recovery on xlarge.** Confirms Spike 7's lane with the
  actual production path measurement.
- **Spike 13 (LDG-2493):** yyjsonr read-path parity. **100% parity;
  4.17x speedup; only 1s recovery at 133k events (PARKED).** Spike 12's
  Rprof attribution was ~40x over-count; direct measurement settles it.
- **Spike 14 (LDG-2494):** yyjsonr canonical_json write byte-identity
  test. **72% byte-identical (7 numeric formatting differences); 6.65x
  speedup; ~13-15s production recovery on xlarge. PROCEED-WITH-BUMP** —
  pre-CRAN byte-format version bump is hours of work, not weeks.

This Round 2 revision incorporates the measured numbers from Spikes
11-14, the Codex corrections, and three new architectural sub-lessons
(L8, L9, L11) the original synthesis did not have evidence for.

**Codex peer review (Round 2):** approved with caveats. The Round 2
revisions addressed Codex's three Round 1 findings cleanly. Codex's
Round 2 caveats led to three additional corrections in this revision:

1. **L10 audit was incomplete.** Codex found a hard-coded config hash
   literal at `tests/testthat/test-sweep-parity.R:513`
   (`"948146c214583b5bf2e200113d0bc5c065d834624b0701b1d099157b15833b3f"`)
   and that `inst/design/contracts.md:217` explicitly names
   `jsonlite::toJSON(...)` as the canonical serializer. L10 now
   acknowledges both surfaces in the migration scope.
2. **L6 mixed durable and ephemeral lanes in one total.** The
   ephemeral-only lane (Spike 6 memory output handler) should not be
   counted toward durable xlarge recovery. L6 now has two tables:
   durable xlarge (445s baseline) and ephemeral xlarge (~624s
   baseline) with shared vs path-specific lanes called out.
3. **L2 mechanism wording was too specific.** The R-internal cause is
   replacement-function materialization; the original "refcount
   bumping to >= 2" claim implies a specific refcount behavior that
   should only be asserted with `tracemem` evidence per site. L2 now
   uses the more general "materialization/copy at evaluation time"
   framing.

**Maintainer directive (2026-05-31, post-Codex Round 2):** Max
directed dropping jsonlite entirely from ledgr's Imports because
ledgr is pre-CRAN with zero users. This subsumes Spike 13 (read path
PARK) and Spike 14 (write path PROCEED-WITH-BUMP) into a single
package-wide migration lane. The synthesis L10 now reflects this
broader scope.

---

## L1. ledgr's slowness is implementation debt, not architecture

**There is no architectural barrier.** Event-sourced backtesters should
have O(1) per-fill cost and O(n_bars) per-pulse cost; ledgr's
*architecture* does. ledgr's *implementation* has three classes of R-idiom
debt that produce O(n_inst) per-pulse and O(N) per-fill cost growth, all
empirically removable:

- **Per-pulse R-interpreted loops** that should be vectorized (Spikes 1,
  2): O(n_inst) interpreted iterations per pulse with no fill
  dependency.
- **Per-row writes into column buffers with transient-binding refcount
  bumps** (Spikes 6, 7, 11; also v0.1.8.7 B0): triggers O(N)
  copy-on-modify per write, totaling O(N^2) per run.
- **Per-row data.frame subsets in hot loops** (Spike 5): O(1) memcpy
  becomes class-dispatch + allocation per access.

All three classes are mechanical to fix. None require rethinking
event-sourcing, snapshots, or the function-strategy contract. The
architecture is sound; the implementation accumulated R-idiom debt.

This continues the v0.1.8.7 L1 finding ("ledgr is machinery-bound, not
callback-bound") two cycles later. Same direction: the user-decision
cost is small; the engine machinery is what's removable.

## L2. The per-row-write-into-shared-buffer trap is now empirically demonstrated FOUR times

Four of the round's confirmed O(N^2) sites share the SAME mechanism:

| Site | First documented | Round | Buffer type |
| --- | --- | --- | --- |
| Event buffer (`R/fold-event-buffer.R` / `R/sweep.R`) | v0.1.8.7 buffer-rewrite spike | v0.1.8.7 B0 | list-in-env |
| Memory output handler (`R/sweep.R:1016-1029`) | Spike 6 of this round | v0.1.8.9 Round 1 | list-in-env |
| Fills reconstruction buffer (`R/fold-reconstruction.R:219-227`) | Spike 7 of this round | v0.1.8.9 Round 1 | env with vector slots |
| **Persistent durable handler (`R/backtest-runner.R:425-435`)** | **Spike 11 of this round** | **v0.1.8.9 Round 2** | **list-in-env** |

Mechanism in all four (refined per Codex's Round 1 and Round 2 reviews):

> **Per-row writes via base-R `[[<-` into a preallocated column buffer
> trigger O(N) materialization/copy of the column during evaluation of
> `env$col[[i]] <- value` or its nested variants (e.g.
> `state$pending_cols$<col>[[i]] <- value`). The replacement-function
> mechanics force R to materialize a fresh column vector at write
> time, totaling O(N^2) per run.** The exact R-internal cause is
> evaluation of complex replacement under R's value semantics — for
> a given site, the production refcount/copy behavior can be confirmed
> with `tracemem()` in a spike, which Spikes 3 and 6 did
> independently.

The buffer's outer shape (named list, env with slots, list inside env)
does not change the mechanism. What matters is that the column vector
is reached through a chain of `$` and `[[<-` accesses that creates
transient bindings.

Fix in all four:

> **`collapse::setv(buffer$<col>, i, value, vind1 = TRUE)`** writes by C
> reference, bypasses R's copy-on-modify, restores true O(N) total work.
> `setv` is value-neutral; no determinism wrapper needed; tracemem-confirmed
> in-place.

The v0.1.8.7 Batch 6 Lane C rewrite correctly removed the
`list-of-data.frames + rbind` anti-pattern in the fills reconstruction
path, but the REPLACEMENT (a primitive-column buffer with per-row
writes) recreated the same O(N^2) class in a different form. That is
the lesson worth carrying forward: **when removing one anti-pattern,
the replacement must be audited for the SAME class of anti-pattern,
not just the named one.**

For v0.1.8.9 and beyond:

> **Coding rule.** Any per-row write into a preallocated column buffer
> goes through `collapse::setv`, not base-R `[[<-`. Applies wherever
> `buffer$<col>[[i]] <- value` (or nested variants like
> `state$pending_cols$<col>[[i]] <- value`) appears inside a per-row
> append loop. Scale-dependent: applies to buffers that grow with fill
> count / event count / history length; does NOT apply to small
> fixed-size vectors (Spike 3 confirms). Compounds when all buffer
> columns are atomic (L8 below).

This rule should land in the v0.1.8.9 spec packet as a coding standard.
It is the highest-leverage architectural finding of the round.

## L3. setv is scale-dependent and the threshold is empirically located

Two-plus spikes in this round tested `collapse::setv` as the fix for
copy-on-modify. They returned DIFFERENT magnitudes by scale:

- **Spike 3** (`state$positions` at 1000-element scale): setv 1.9x
  vs current — tied with `intvec_id_map` (1.9x) which is
  semantic-preserving. **Recommended against.**
- **Spike 6** (memory output handler at 130k-element columns): setv
  6.45x vs current. Bounded by a list-column residual (see L8).
- **Spike 7** (fills reconstruction buffer at 260k-slot columns): same
  mechanism. ~580s isolated recovery from setv via Spike 12's measurement.
- **Spike 11** (persistent durable handler, all-atomic columns):
  **setv 140x; 167s isolated recovery; flat per-event cost.** No
  residual list-column. **Recommended for as the lead lane.**
- **Spike 12** (chunked extractor + setv prototype): 4.6x speedup;
  ~150s production recovery. Chunking bounds N but setv eliminates
  the per-write copy within that bound (L9 below).

The scale-dependence: at small vector sizes (~1k elements) base-R copies
are cheap because there is no memory bandwidth pressure; setv's
function-call overhead washes out the no-copy win. At large vector
sizes (~100k+ elements) copies become bandwidth-bound; setv's
in-place advantage compounds. **Threshold sits between 1000 and ~100k
elements**, but the maximum win also depends on the column shape (L8).

For v0.1.8.9: the coding rule above MUST include the scale caveat. Apply
to growing column buffers; leave small fixed-size state vectors alone.

## L4. The Kahan-vs-cumsum precision discovery generalizes a discipline rule

LDG-2476's three-phase parity gate documented an 8e-9 per-bar
durable-vs-ephemeral noise as "DuckDB float round-trip noise" and
relaxed the gate from byte-identical to `tolerance = 1e-8`.

Spike 10 shows that documented attribution is technically incorrect:
DuckDB DBI round-trip is byte-identical at all tests
(direct, cumsum, SUM OVER). The actual mechanism is **Kahan compensated
summation in `ledgr_lot_add_realized` (`R/lot-accounting.R:49-55`) vs
naive `cumsum()` in `ledgr_equity_from_events`
(`R/fold-reconstruction.R:87`)**. Both are valid; neither is wrong; the
8e-9 noise matches Kahan compensation residual exactly.

The broader lesson:

> **When a parity gate gets relaxed, the attribution should name the
> exact mechanism, not the easy external-library shrug.** "Kahan vs
> cumsum" tells future agents where to look. "DuckDB float noise"
> sends them on a phantom chase.

This rule applies wherever ledgr has tolerance-relaxed gates: name the
internal mechanism that caused the relaxation, not the external library
the values flowed through. The v0.1.8.9 spec should add this as a
gate-discipline rule alongside the existing determinism gate language.

## L5. Spike discipline rejects hypothesized lanes before they get ticketed

Three of the fourteen spikes returned clean **negative results** that
explicitly REJECTED hypotheses the inventory or the round's own
midpoint expectations had flagged as v0.1.8.9 candidates:

- **Spike 8** (D3, in-memory event-stream reconstruction): hypothesized
  to be O(N^2). Spike measured it as O(N) flat per-fill (~58 us/fill
  at all scales). **D3 lane parked.** The +40.9s ephemeral results
  delta is absorbed by Spike 7's fix (since `ledgr_fills_from_events`
  is called by both paths).
- **Spike 10** (D5, DuckDB equity noise): hypothesized to be DuckDB
  precision. Spike measured byte-identical round-trips at all tests.
  **Real mechanism is Kahan vs cumsum, documented separately.**
- **Spike 13** (LDG-2493, yyjsonr read path): hypothesized to recover
  ~8-15s based on Spike 12's Rprof attribution. **Direct measurement
  shows ~1s recovery at 133k events.** Spike 12's Rprof
  over-attributed jsonlite::fromJSON by ~40x. **PARKED.** See L11 for
  the methodology rule.

All three negative results saved v0.1.8.9 implementation tickets that
would have been wrong. This mirrors v0.1.8.7's spike-projection-collapse
negative result, which parked the matrix-canonical projection as a
perf lane (it became a contract lane instead).

The discipline rule: **a hypothesized lane is not a confirmed lane.
Run the spike before scoping the ticket.** v0.1.8.9 should adopt this
explicitly in its spec methodology.

## L6. Lane concentration is now empirically confirmed (Round 2 measured numbers)

The projected wall recovery splits cleanly between durable and
ephemeral paths. Some lanes apply to both (shared hot functions); some
are path-specific (different handler files). Codex's Round 2 review
correctly flagged that the Round 1 table mixed durable and ephemeral
lanes in one total; this revision separates them explicitly.

### Durable xlarge cell (`density_high_xlarge_durable`, 445s baseline)

| Rank | Lane | Spike | Recovery | Path | Notes |
| --- | --- | --- | --- | --- | --- |
| 1 | Fills reconstruction setv on `R/fold-reconstruction.R:219-227` | 7, 12 | **~150s** | shared (durable + ephemeral) | Spike 12 via real chunked extractor; replaces Spike 7's ~170s estimate. Same hot function `ledgr_fill_row_buffer_add` is on both paths. |
| 2 | Persistent durable handler setv on `R/backtest-runner.R:425-435` | 11 | **~50-80s** | durable-only | New lane (Round 2); replaces Spike 4 for default durable path. All-atomic columns get 140x setv speedup. |
| 3 | yyjsonr full migration (drop jsonlite) | 13, 14 | **~14-16s** | shared | Combined read + write recovery; pre-CRAN dependency consolidation per L10. |
| 4 | Per-target delta vectorize | 2 | ~12s + scaling flatten | shared | 102.7x scaling fix at 1000 inst |
| 5 | Per-pulse position valuation vectorize | 1 | ~9s | shared | Architectural scaling flatten |
| 6 | Per-fill next-bar matrix lookup | 5 | ~5s | shared | De-prioritized; v0.1.8.10 cleanup |
| 7 | state$positions representation | 3 | ~1s | shared | Audit-gated; intvec_id_map preserves snapshot semantics |

**Durable projected recovery: ~241-273s.** Post-v0.1.8.9 durable xlarge
wall: ~172-204s. Backtrader at xlarge: ~160s. **Projected ratio:
~1.1-1.3x slower** — much closer than today's 4x but still not
beating Backtrader at this density without compiled-core acceleration.

### Ephemeral xlarge cell (~624s baseline per LDG-2479)

| Rank | Lane | Spike | Recovery | Path | Notes |
| --- | --- | --- | --- | --- | --- |
| 1 | Fills reconstruction setv on `R/fold-reconstruction.R:219-227` | 7, 12 | larger than durable (full ~580s monolithic) | shared | Ephemeral calls `ledgr_fills_from_events()` monolithically; setv recovery is correspondingly larger |
| 2 | Memory output handler setv on `R/sweep.R:1016-1029` | 6 | **~75s** | ephemeral-only | Bounded by `meta` list column residual (L8). Different file than persistent handler. |
| 3 | yyjsonr full migration (drop jsonlite) | 13, 14 | ~14-16s | shared | Same as durable |
| 4-7 | Per-pulse and cleanup lanes | 1, 2, 3, 5 | ~25-30s combined | shared | Same as durable |

**Ephemeral projected recovery: ~250-300s+.** Post-v0.1.8.9 ephemeral
xlarge wall: ~325-375s. Ephemeral remains slower than durable post-fix
because the memory output handler's `meta` list column bounds setv's
win (L8). The architectural follow-up to convert `meta` to
`meta_json` character column (proposed in L8) would close that gap
but is out of v0.1.8.9 scope.

### Reclassified and parked lanes

| Lane | Spike | Status | Reason |
| --- | --- | --- | --- |
| Per-row DBI INSERT batching | 4 | RECLASSIFIED | Live mode only; default durable already batches via persistent handler. Codex Finding 1. |
| Per-pulse pulse_seed cheap mixer | A4 | Inventory only | Not spiked; ~0.25s estimated, below v0.1.8.9 threshold |

### Lane concentration summary

The v0.1.8.7 L2 finding ("the cost is localized, not diffuse — two
shape-dependent rocks") holds in v0.1.8.9 form. The cost is localized in
column-buffer writes (setv) and the chunked extractor's hot function
(setv on the shared `ledgr_fill_row_buffer_add`). For the durable
xlarge cell, two lanes (Spike 12 + Spike 11) account for ~200-230s,
~83% of projected recovery. For the ephemeral cell, three lanes
(Spike 12 + Spike 6 + per-pulse) account for the bulk.

**v0.1.8.9 spec headline targets: Spikes 11 and 12 for durable, plus
Spike 6 for ephemeral if the ephemeral path's perf matters to a v0.1.8.9
release goal. Spikes 13+14 (yyjsonr migration) and per-pulse lanes are
useful additions that compound if implemented.**

## L7. Architecture is sound; the v0.1.8.9 work is mechanical

None of the fourteen spikes identified an architectural problem. Every
confirmed lane is a small mechanical fix:

- Spike 1: 1-line vectorization
- Spike 2: 4-line vectorization
- Spike 3: representation refactor (medium blast radius, audit-gated)
- Spike 4: reclassified per Codex Finding 1 (live mode only)
- Spike 5: signature change for fill proposal (small contract change)
- Spike 6: 13-line `collapse::setv` replacement
- Spike 7: 9-line `collapse::setv` replacement (validated against the
  real chunked extractor in Spike 12)
- Spike 8: parked (negative result)
- Spike 9: robustness investigation, narrowed (DuckDB exonerated;
  stream_threshold path remains the suspect)
- Spike 10: documentation-only fix (rename gate attribution from
  "DuckDB noise" to "Kahan vs cumsum")
- Spike 11: 11-line `collapse::setv` replacement (the new headline
  durable lane)
- Spike 12: validated Spike 7's lane against the real production path
- Spike 13+14: yyjsonr full migration per L10 (drop jsonlite,
  consolidate to yyjsonr). Scope per Codex Round 2 review: ~25 call
  sites in `R/`, `inst/design/contracts.md:217` updated to name
  yyjsonr, `tests/testthat/test-sweep-parity.R:513` hash literal
  regenerated, DESCRIPTION updated, NEWS entry. Estimated ~half-day
  to full day of work. Still mechanical, but the surface is larger
  than the original "switch one call" framing.

**The v0.1.8.9 round is mechanical execution, not architectural
redesign.** This is the right shape for a single-core single-cycle
optimization round.

The compiled-core question (K1 in the inventory) is not implicated by
any of these findings. Whether `ledgrcore` becomes a real conversation
in v0.2.x depends on what the engine gap to Backtrader looks like
AFTER Spikes 11, 12, 14 land and we re-measure. Projected post-v0.1.8.9
xlarge wall: ~180-215s. Backtrader at xlarge: ~160s. **Post-v0.1.8.9
ratio: ~1.1-1.3x slower than Backtrader on the stress workload** — a
much closer race than today's 4x, but still not beating Backtrader at
this density without compiled-core acceleration. K1 remains the
v0.2.x conversation for closing the residual gap (L7 from the
horizon's compiled-core entry now includes the canonical_json encoder
per the 2026-05-31 update).

## L8. Atomic-only columns compound the setv win

Spike 6 vs Spike 11 produced very different setv recovery magnitudes
on the same underlying mechanism:

| Spike | Buffer | Columns | setv speedup at 130k events |
| --- | --- | --- | --- |
| Spike 6 | Memory output handler | 14, of which 1 (`meta`) is a LIST column | 6.45x |
| Spike 11 | Persistent durable handler | 11, all ATOMIC (character, POSIXct, numeric, integer) | **140x** |

The difference is the `meta` list column. `collapse::setv` operates on
atomic vectors, not lists. Spike 6's `meta` writes
(`state$event_cols$meta[i] <- list(meta)`) still pay base-R
copy-on-modify; that residual list-column cost bounds setv's overall
recovery to 6.45x. Spike 11's all-atomic buffer has no such residual,
so setv delivers true O(N) total work and 140x measured speedup.

For the v0.1.8.9 round this gives a clean architectural sub-rule:

> **`collapse::setv` delivers true O(N) total work only when all
> buffer columns are atomic. Mixed atomic + list buffers see partial
> wins bounded by the slowest writable column.**

Future buffer designs should prefer atomic columns where the data
permits. For `meta`, the natural fix is to serialize to canonical_json
once (a string) and store the character column rather than the list.
This is consistent with how the persistent durable handler already
stores meta_json as character and decodes only at extraction time.

Combined with the v0.1.8.9 yyjsonr canonical_json switch (Spike 14, L10),
the natural follow-up is: convert the memory output handler's `meta`
list column to a `meta_json` character column. That removes the
list-column residual AND inherits the yyjsonr write speedup. Out of
v0.1.8.9 scope as a structural refactor, but recorded as the obvious
v0.1.8.10 polish lane.

## L9. Chunking and setv are complementary, not substitutable

The Spike 7 vs Spike 12 comparison at 130k events:

| Path | Buffer per write | Wall at 130k |
| --- | --- | --- |
| Spike 7: monolithic, base-R `[[<-` | 260k slots | 618s |
| Spike 12: chunked, base-R `[[<-` | 100k slots | 238s |
| Spike 12: chunked + setv | 100k slots, no copy | 52s |

Chunking gave 2.6x speedup (618 -> 238). Setv on top gave another
4.6x (238 -> 52). **Compounded: 12x speedup from monolithic base-R to
chunked + setv.** Both techniques target the same anti-pattern at
different layers:

- **Chunking bounds N per write** by ensuring the buffer doesn't grow
  beyond a fetch-size limit. The per-write copy cost is bounded but
  not eliminated.
- **setv eliminates the per-write copy** within whatever N the
  architecture provides. Independent of chunking.

The v0.1.8.9 round adopts both. The synthesis sub-rule:

> **Architectural mitigation (chunking) and implementation mitigation
> (setv) are complementary fixes for per-row column-buffer anti-patterns,
> not alternatives. Apply both where the patterns appear.**

Combined with L8, the asymptotically clean combination is: **chunking
+ setv + atomic-only columns**. Spike 11's persistent durable handler
already has the atomic-only columns property; Spike 12's setv prototype
on the chunked extractor brings the chunked + setv combination to
production. Both buffers reach the architecturally clean state after
v0.1.8.9.

## L10. Pre-CRAN dependency consolidation: drop jsonlite entirely, adopt yyjsonr

Spike 14 was originally scoped as "switch canonical_json's serializer."
The Codex Round 2 review correctly flagged that the assumed audit was
incomplete: there is at least one hard-coded config hash literal at
`tests/testthat/test-sweep-parity.R:513`
(`"948146c214583b5bf2e200113d0bc5c065d834624b0701b1d099157b15833b3f"`),
and `inst/design/contracts.md:217` explicitly names
`jsonlite::toJSON(...)` as the canonical serializer in the contracts
document. Both must be updated for any canonical_json byte format
change.

**Maintainer directive (2026-05-31, post-Codex Round 2):** ledgr has
zero users (pre-CRAN). The cleanest move is to drop jsonlite entirely
across the package and adopt yyjsonr as the single JSON library, not
to maintain both. This subsumes Spikes 13 (read path PARK) and 14
(write path PROCEED-WITH-BUMP) into a single package-wide migration
lane.

The dependency consolidation surface:

- **~25 jsonlite call sites** across 10+ R files
  (`R/backtest.R:1127`, `R/backtest-runner.R:568, 1336, 1546, 1766,
  1824`, `R/derived-state.R:29, 70`, `R/config-canonical-json.R:38,
  115`, plus other Class A reads). All move to yyjsonr equivalents.
- **`inst/design/contracts.md:217`** updated: name yyjsonr as the
  canonical serializer; document the exact `opts_write_json` configuration
  (`pretty = FALSE, auto_unbox = TRUE, digits = -1L, null = "null",
  num_specials = "null"`).
- **`tests/testthat/test-sweep-parity.R:513`** regenerated: the
  hard-coded config hash literal is replaced by the new yyjsonr-format
  hash. A comment notes the regeneration history.
- **DESCRIPTION**: jsonlite drops from Imports; yyjsonr is added
  with a pinned version (`yyjsonr (>= 0.1.22)`).
- **Gitignored parity_history files** reset.
- **NEWS / release notes** explicit entry: "canonical_json byte format
  v2: now uses yyjsonr. Hash values from prior runs do not match."

Estimated implementation cost: **~half-day to full day** including
the test-fixture regeneration and contracts.md update. This is the
larger surface the Codex review flagged, but it is still bounded.

The combined wall recovery on `density_high_xlarge_durable`:
- Read path (Spike 13's yyjsonr fromJSON): ~1s
- Write path (Spike 14's yyjsonr canonical_json): ~13-15s
- **Combined: ~14-16s of measured recovery**

The recovery is similar to before but the framing is cleaner.
Rather than "switch one call and ship a versioned bump," it is
"consolidate to yyjsonr because pre-CRAN allows it."

The broader lessons:

> **Pre-CRAN means dependency consolidation is essentially free.
> Carrying two JSON libraries is post-CRAN compatibility hedging that
> we do not owe to anyone yet. v0.1.8.9 is the right window for any
> such consolidation across ledgr's Imports.**

> **Durable identity surfaces have a finite window in pre-release
> where they can be reshaped freely. That window closes at CRAN.
> Spending the window deliberately is better than burning it on
> accidental format choices.**

> **Audit claims about "no hard-coded hash literals" must be verified
> by direct grep, not by reading test patterns.** The Round 1
> assertion was wrong; the Round 2 grep found one literal. The
> implementation ticket includes the audit-and-regenerate step.

v0.1.8.9 is the last clean window before CRAN for changes to:
canonical_json byte format, snapshot_hash composition, event_seq
encoding, run_id format, config_hash inputs, and JSON-library choice.
If any of those need changing, v0.1.8.9 is the right ticket. After
v0.1.8.9, the cost rises sharply.

The K1 / `ledgrcore` work in v0.2.x will absorb canonical_json into
the compiled byte-identity gate (per the horizon's 2026-05-31
update). v0.1.8.9 picking yyjsonr is the bridge: the v0.1.8.9 byte format
becomes what `ledgrcore` matches when it lands.

## L11. Direct measurement settles Rprof attribution disputes

Spike 13 (yyjsonr read path) was scoped from Spike 12's Rprof showing
`jsonlite::fromJSON` at ~20.59% total.time (= ~46s of 223s). Direct
isolated measurement: jsonlite parses 133k events in **1.25 seconds**.
Rprof over-attributed by ~40x.

Rprof samples at 200Hz (default 5ms intervals). At that sampling rate
the attribution percentages can be biased by:

- Functions whose callees re-enter through the stack (Rprof can
  count the same time toward multiple stack levels via the
  total.time vs self.time split, and self.time can leak into
  attributions of functions called in tight loops where stack
  unwinding is incomplete at sample points).
- Functions wrapped in `tryCatch` or `withCallingHandlers` (these
  add stack frames Rprof samples differently than direct calls).
- Functions whose actual work is in C-level callees but whose R
  frame is on the stack at the sampling moment.

For ledgr's purposes:

> **Before scoping a v0.1.8.9 lane from an Rprof percentage, run a
> direct system.time() measurement of the function in isolation. The
> direct measurement is the ground truth; the Rprof percentage is a
> hint.**

This is the inverse of the v0.1.8.7 round's "isolated benchmarks lie"
discipline. Both lies are real:

- **Isolated benchmarks** over-estimate production cost (no
  surrounding R machinery, ideal cache, no refcount-elevation
  interactions). v0.1.8.7 buffer spike: ~3x overestimate.
- **Rprof attributions** can over-count by orders of magnitude under
  certain sampling-vs-call-stack interactions. Spike 13: ~40x
  over-attribution.

The discipline: confirm with direct measurement at production
frequency. Then triangulate against production workload-grid
measurements. Then ship.

---

## Constraints carried into v0.1.8.9

These are the gates v0.1.8.9 implementation must respect:

1. **Determinism gate** still mandatory for value-bearing collapse ops.
   None of the recommended fixes (setv, vectorized ops in fold-engine)
   are value-bearing; they don't reorder floating-point reductions and
   don't need the `ledgr_with_collapse_deterministic()` wrapper. If a
   future fix DOES reach for `collapse::fcumsum`, `collapse::fsum`, etc.,
   the wrapper is mandatory.
2. **Byte-identical event-stream parity** required for any fix touching
   the event log. Setv fixes preserve byte-identical column values
   (verified in Spikes 6, 7, 11, 12 with explicit parity checks).
3. **Tier 1 equity / cash / positions parity** within tolerance for the
   workload-grid re-measurement gate. The 1e-8 tolerance from LDG-2476
   stays, with the attribution renamed from "DuckDB float round-trip"
   to "Kahan compensated summation vs naive cumsum" per L4.
4. **Spike-confirmed mechanism + direct measurement + real-run re-profile**
   before any production code merge. Three-step discipline per L5 and
   L11: hypothesis -> isolated spike -> direct timing -> real-run
   verification.
5. **canonical_json byte format change requires explicit version-bump
   documentation** (NEWS entry, release notes, parity_history reset)
   per L10. The change itself is bounded; the documentation is the
   gate.

## v0.1.8.9 spec inputs

The v0.1.8.9 spec packet, when cut, should pull from:

- This synthesis (architectural lessons L1-L11).
- The per-spike `.md` logs in `dev/spikes/` (mechanism evidence and
  fix sketches per lane):
  - Round 1: spikes 1-10
  - Round 2: spike-persistent-handler-buffer.md (Spike 11),
    spike-chunked-extractor-wall-recovery.md (Spike 12),
    spike-yyjsonr-readpath-parity.md (Spike 13),
    spike-yyjsonr-write-byte-identity.md (Spike 14)
- The round `README.md` (lane ordering, scale-dependence rule).
- `dev/bench/notes/single_core_optimization_inventory.md` (the inventory
  this round was scoped from).
- `dev/bench/notes/workload_grid_baseline_closeout.md` (the LDG-2479
  grid baseline that becomes the before/after gate).
- The horizon's 2026-05-31 update to the `ledgrcore` entry (recording
  that ledgrcore should own canonical_json encoding/decoding when K1
  lands, per L7).

The spec packet should NOT pull from the spike-ticket markdown
(`spike_tickets.md`) for implementation scope — those tickets were
pre-RFC investigation, not implementation work. v0.1.8.9 implementation
tickets are separately cut from the synthesis findings.

---

## Closing

The v0.1.8.9 round's architectural read is: **ledgr's slowness at scale
is an R-idiom debt problem in four classes (per-pulse interpreted
loops, per-row column-buffer writes, per-row data.frame subsets, and
the canonical_json byte format historical choice), all empirically
removable with mechanical fixes and one documented byte-format
version bump.**

The lane projection (Round 2 measured): **Spikes 11 + 12 + 14 land
~215-245s of recovery on the 445s xlarge wall.** Per-pulse and cleanup
lanes add another ~25s. Total: **~240-270s recovery, ~54-61% wall
reduction**. After landing, ledgr is projected at ~180-215s on the
xlarge cell vs Backtrader's ~160s — much closer than today's 4x gap
but still ~1.1-1.3x slower at the stress workload. K1 / `ledgrcore`
remains the v0.2.x conversation for closing the residual gap (and
absorbing canonical_json into the compiled identity contract).

The cross-cutting coding rule — **"per-row column-buffer writes go
through `collapse::setv`, not base-R `[[<-`"** — is the highest-leverage
finding of the round, now empirically demonstrated at FOUR sites. It
should land in the v0.1.8.9 spec packet as a coding standard, with the
scale caveat (apply to growing buffers, leave small fixed-size
vectors alone) AND the column-shape caveat (atomic-only buffers
compound the win; list columns bound it).

Three new architectural sub-rules emerged from Round 2:

- L8: atomic-only columns compound the setv win (Spike 11 vs Spike 6)
- L9: chunking and setv are complementary, not substitutable (Spike 12)
- L10: canonical_json byte format is a versioned contract;
  pre-CRAN is the right window for bumps
- L11: direct measurement settles Rprof attribution disputes

The discipline that produced these findings — spike to confirm
mechanism, direct timing measurement, Amdahl-bounded wall translation,
real-run re-profile as verdict, negative results park hypothesized
lanes, peer review catches misreads, Round 2 closes the gaps — is the
v0.1.8.7 methodology applied a second time and refined through Codex
peer review. It continues to work.
