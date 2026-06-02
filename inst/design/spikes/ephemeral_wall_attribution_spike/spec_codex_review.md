# Codex Review: Ephemeral Wall Attribution Spike Spec

Verdict: Reject pending Round-2 spec.

The spike's mission is correct and the post-v0.1.8.10 sequencing is
right, but the current spec would not produce a verdict I would act on.
Two measurement-design issues are blocking: Method A cannot isolate several
named line-range sub-frames through `assignInNamespace()` wrappers, and the
coverage / Pareto math double-counts nested frames unless the spec defines
exclusive timing. The decision rule also needs absolute-wall and grouped-frame
guards before it can gate Architecture A / B2.

## Findings

1. **Method A cannot isolate several named sub-frames with function wrappers**

   Claim challenged: `spec.md:136-140` says the script uses
   `assignInNamespace()` to monkey-patch production functions with timed
   wrappers, while `spec.md:149-152` says E1 wraps `ctx <- list(...)` and
   then uses "one wrapper per sub-frame."

   Evidence: several sub-frames are statement ranges inside larger functions,
   not function boundaries. E1, E6, E7, strategy invocation, target
   validation, and fill state updates are all inline in `ledgr_execute_fold`:
   `R/fold-engine.R:164-221`, `R/fold-engine.R:228-280`, and
   `R/fold-engine.R:289-365`. R2, R3, and R4 are inline in
   `ledgr_sweep_summary_from_ordered_events` at
   `R/fold-reconstruction.R:506-560`. `assignInNamespace()` can replace
   functions such as `ledgr_update_fast_pulse_context_helpers`, but it cannot
   wrap `ctx <- list(...)` or a `for`-loop body without replacing the whole
   enclosing function with an instrumented copy.

   What the spec should say instead: Method A must explicitly distinguish
   function-boundary wrappers from statement-boundary instrumentation. For the
   latter, use a copied instrumented fold/reconstruction function in the spike
   script, or add temporary dev-only hooks in an instrumented build. The parity
   gate then compares that instrumented function against the uninstrumented
   installed package.

   Severity: blocking. This changes the measurement implementation.

2. **Nested sub-frames will double-count wall unless the spec defines exclusive time**

   Claim challenged: `spec.md:143-145` says wrappers accumulate cumulative wall
   per sub-frame; `spec.md:179-186` requires total sub-frame wall to land in
   the 0.85-1.05 coverage band; `spec.md:245-248` defines fold-loop share as
   `E6 + E7 + E8 + E9`.

   Evidence: the proposed sub-frames are nested. E7's fill loop at
   `R/fold-engine.R:289-365` contains the cost resolver call at line 306, the
   output-handler write at lines 342-346, and the cash / position mutation at
   lines 354-361. Post-v0.1.8.10 E8 lot machinery would also run inside this
   same fill loop. In reconstruction, R2 (`R/fold-reconstruction.R:506-527`)
   contains R3 (`R/fold-reconstruction.R:514-526`). If E7 is timed inclusively
   and E8/E9/E12 are also timed, `sum(sub_frame_wall)` is mathematically
   guaranteed to over-count. If R2 and R3 are both included, the same problem
   appears in the results phase.

   What the spec should say instead: define a hierarchy and report both
   inclusive and exclusive-self time. The decision rule should consume either
   inclusive parent groups or exclusive leaf sums, never a mixture. For example,
   fold-loop share can be "inclusive E7 plus E6" or "exclusive E7 + E8 + E9 +
   E12 + E6" after child subtraction.

   Severity: blocking. The current coverage and Pareto requirements are not
   meaningful without this.

3. **Method B top-3 agreement is an invalid gate**

   Claim challenged: `spec.md:169-175` correctly says Method A is ground truth
   and Rprof is a sanity check, but `spec.md:188-190` requires Method A and
   Method B to agree on the top three sub-frames. `spec.md:347-350` also says
   to use Method B only if Method A contaminates total wall by more than 10%.

   Evidence: the v0.1.8.9 doctrine says direct timing is the ground truth and
   Rprof is a hint: `architecture_synthesis.md:514-539` records a ~40x Rprof
   over-attribution, and `dev/spikes/spike-yyjsonr-readpath-parity.md:89-100`
   shows the direct timing was the Amdahl-bounded answer. Rprof samples
   function stacks, not arbitrary statement ranges, and cannot align cleanly to
   E1, E6, R2/R3, or an exclusive-time hierarchy. At 10ms or 1ms intervals it
   will also be too coarse for sub-millisecond pulse frames.

   What the spec should say instead: Method B is discovery and sanity only. It
   should flag uninstrumented functions or suspicious missing mass, but exact
   top-3 agreement should not be required. If Method A coverage/stability and
   parity pass, Method A can produce the verdict even when Rprof ranks differ.
   If Method A contaminates wall, the recovery path is broader coarse timers or
   a repaired instrumented function, not Method-B-only fine attribution.

   Severity: blocking. The current cross-validation rule can reject a valid
   attribution or accept a misleading sampled profile.

4. **The decision rule can choose the wrong architecture target**

   Claim challenged: `spec.md:254-259` uses fold-loop share bands and a
   single-sub-frame override: below 15% means pivot away from compiled cores
   entirely; 30-50%+ means run B2; any single non-fold-loop frame larger than
   fold-loop share wins.

   Evidence: a relative threshold alone is not enough. On the pre-v0.1.8.10
   372.55s anchor (`spec.md:86-90`), even 14% is about 52s of wall. That is a
   material absolute target even if it falls below the 15% band. The rule also
   misses grouped dominance: three non-fold frames at 14%, 13%, and 12% could
   dominate the optimization direction even though no single frame exceeds the
   fold-loop slice. Finally, E12 is per-fill fold work. It is called from
   `R/fold-engine.R:306` through `ledgr_resolve_fill_proposal` at
   `R/fill-model.R:148-159`, but it is excluded from the fold-loop slice
   definition at `spec.md:245-248`. If B2 can compile the default cost resolver,
   E12 belongs in a fold-adjacent rollup; if cost resolution stays an R
   callback, it is a boundary cost that must be reported separately.

   What the spec should say instead: the verdict must report both percent and
   absolute seconds, plus grouped rollups: fold core, fold plus default cost,
   ctx/helper/feature machinery, output/materialization, results/reconstruction,
   setup, and GC/allocation. The "<15%" branch should only pivot away when both
   relative share and absolute recoverable wall are below a named threshold.
   The override should apply to grouped non-fold surfaces, not only a single
   sub-frame.

   Severity: blocking. This is the spec's product decision rule.

5. **GC and allocation pressure are missing as a first-class attribution bucket**

   Claim challenged: `spec.md:96-128` lists 21 sub-frames, but none captures
   R garbage collection or allocation pressure; `spec.md:201` only says
   `gc(FALSE)` runs between reps.

   Evidence: this workload creates many short-lived R objects: pulse contexts
   at `R/fold-engine.R:181-194`, helper closures / lookup state through
   `R/pulse-context.R:337-412`, event buffers and materialized tibbles in
   `R/sweep.R:957-1190`, and reconstruction frames at
   `R/fold-reconstruction.R:536-560`. GC may be charged to whichever wrapper is
   active when it fires, or may appear as unexplained dark matter. Either way,
   it can move the Pareto ranking and the 85% coverage calculation.

   What the spec should say instead: add a GC/allocation bucket. At minimum,
   record GC counts and elapsed GC time before/after each rep, include an
   "unattributed GC/allocation" line in the output, and state whether GC time
   is included in exclusive sub-frame timings or separated out.

   Severity: blocking for methodology; caveat-worthy if the first instrumented
   dry run proves GC is negligible.

6. **O1/O2 code citations are wrong in current source**

   Claim challenged: `spec.md:126-127` cites `R/sweep.R:282-340` for snapshot
   read, bars matrix construction, feature precompute, and runtime projection
   setup.

   Evidence: current `R/sweep.R:282-340` is candidate object /
   reproduction-key code, not sweep setup. The current setup surface is:
   snapshot metadata and bars fetch at `R/sweep.R:119-128`, bars matrix and
   pulse views at `R/sweep.R:129-136`, feature precompute / projection at
   `R/sweep.R:140-164`, bars matrix construction at
   `R/sweep.R:1402-1426`, and candidate execution setup at
   `R/sweep.R:841-919`.

   What the spec should say instead: replace the O1/O2 citations with the
   current ranges above, and require a citation refresh after v0.1.8.10 lands.

   Severity: caveat-worthy. It will become blocking if the measurement script
   is written from the current citations.

7. **E2 and E5 hypotheses overstate what prior evidence actually measured**

   Claim challenged: `spec.md:99` treats the ~1.8s attribution as helper
   attachment, and `spec.md:102` frames alias-map normalization as a measured
   candidate for this workload.

   Evidence: the horizon entry itself is more cautious: `horizon.md:840-847`
   says Spike 4 measured bare list allocation as invisible and v0.1.8.8
   telemetry attributed broad ctx construction at ~1.8s, so helper attachment
   is the suspected surface requiring direct profiling. That is not yet a
   measured E2 slice. For E5, `R/feature-alias-map.R:90-104` only runs when
   the strategy path calls `ctx$features(instrument_id)` without an explicit
   feature map. If the LDG-2479 strategy consumes `ctx$vec$feature(feature_id)`
   after v0.1.8.10, E5 can legitimately be near zero on this fixture.

   What the spec should say instead: label E2's 1.8s as an upper-bound
   hypothesis for broad ctx construction, not a helper-attachment measurement.
   For E5, require invocation counts and a strategy-path audit; a near-zero E5
   result should be reported as "not exercised by this fixture", not as proof
   alias normalization is globally irrelevant.

   Severity: caveat-worthy.

8. **Session arithmetic and instrumentation overhead calibration are under-specified**

   Claim challenged: `spec.md:154-160` hard-codes roughly 4 us per wrapper, and
   `spec.md:210-219` says "Two runs per session" while listing three runs and
   treating the 10ms + 1ms Rprof pass as one rep.

   Evidence: the Amdahl-floor spike measured a 6.84 us/pulse user-decision
   floor (`dev/spikes/spike-amdahl-floor.md:24-31`), so host-specific timer
   overhead matters at the same scale as some target frames. The Rprof protocol
   is also ambiguous: 10ms and 1ms intervals imply two profiler runs, not one,
   unless the spec defines a single combined procedure. With warm reps for both
   uninstrumented and instrumented runs, the session may be longer than the
   stated 11 reps / 70-80 minutes.

   What the spec should say instead: include a same-session timer-overhead
   calibration loop and subtract measured overhead by sub-frame invocation
   count. Clarify the rep count as uninstrumented, Method A, Rprof-10ms, and
   Rprof-1ms, including warm reps.

   Severity: nitpick for session planning; caveat-worthy for attribution
   accuracy.

## Confirmed claims

- The post-v0.1.8.10 dependency is real. The spec correctly waits for
  fold-owned accounting and `ctx$vec` because those changes alter the sub-frame
  boundaries (`spec.md:46-49`, `spec.md:315-328`).
- The K1 verdict is represented correctly. The external verdict authorizes
  compiled-core work only for inline event accumulation and explicitly says
  production extrapolation depends on where ledgr's wall actually lives
  (`ledgrcore-spike/.../verdict.md:7-27`, `151-160`).
- Current standard metrics are derivable from equity plus fills. The metric
  kernel uses equity and closed fill rows only (`R/fold-metrics.R:9-57`), and
  the public metric path reads equity and fills before computing the same
  standard metrics (`R/backtest.R:1476-1530`).
- The ephemeral memory output handler does not hide DBI work in current source:
  `handler$run_transaction <- function(fn) fn()` at `R/sweep.R:1104`.
- The current telemetry env does not yet expose `t_engine`, `t_results`, or
  `t_fills_extract` (`R/sweep.R:1364-1384`), and Spike 11 correctly scopes
  those fields as v0.1.8.10 infrastructure.
- The spec correctly treats the 372.55s xlarge ephemeral number as a pre-
  v0.1.8.10 anchor only, not the measured baseline for this spike
  (`spec.md:86-90`).

## Suggested additions

- Add an "Attribution Semantics" section defining inclusive vs exclusive
  timing, the parent/child hierarchy, and which rollups feed the decision rule.
- Add missing buckets or explicit rollups:
  - GC/allocation pressure.
  - Target validation and target-risk noop as a distinct child of E4 or E7
    (`R/fold-engine.R:248-268`).
  - Fold-adjacent cost resolver as either part of the compiled-eligible fold
    rollup or as a separate R-callback boundary (`R/fill-model.R:148-195`).
  - Tibble/data.frame materialization and classing for event and fill outputs
    (`R/sweep.R:1077-1100`, `R/fold-reconstruction.R:546-560`).
  - Strategy preflight / one-time setup if it is non-trivial after corrected
    O1/O2 setup citations.
- Add grouped decision outputs: fold core, fold plus default cost, ctx/helpers,
  feature/projection/alias, output/materialization, results/reconstruction,
  setup, GC/allocation, and unattributed remainder.
- Add a fallback discovery method for coverage failures: use Rprof or another
  profiler to find missing functions, then add a direct/instrumented timer for
  that frame. Do not use sampled-profiler ranking as the final verdict.
- Add a pre-run citation refresh checklist that must be completed after
  v0.1.8.10 ships. The spec already names this risk at `spec.md:351-354`; make
  it an explicit gate before measurement starts.
