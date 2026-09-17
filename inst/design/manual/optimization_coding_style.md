# Optimization Coding Style


**Status:** Maintainer coding-style article updated after v0.2.0.1
productionization (LDG-2732).

**Authority:** Synthesis plus implementation trace. Binding rules remain
in the v0.1.8.9 spec (column-buffer write rule), `../contracts.md`, the
accepted RFC syntheses, and `../spike_protocol.md`. This article
collects the teachings of the optimization arc from v0.1.8.7 through the
2026-09 availability spikes into one coding style so that new fold,
ingest, and reader code does not reintroduce a shape the arc has already
measured and removed.

**Anchor scope:** `R/...:line` references resolve against branch
`v0.2.0.1` at commit `0f618fd`, after the three warm seams, finalization
repair, and grouped seal validators reached production code.

You are about to write or review code that touches bars, facts, pulses,
instruments, events, or diagnostics, and you need to know which shapes
the arc has shown to be expensive in R and what to write instead. By the
end you should be able to recognise the six recurring anti-patterns on
sight, name the replacement for each, and know which measurement a claim
of “faster” needs before it is believed.

> [!WARNING]
>
> **Style, not a benchmark page**
>
> This article is internal maintainer prose. It creates no contract, no
> public API, and no speed claim. Where it cites numbers, they are the
> arc’s recorded measurements on registered public fixtures, quoted to
> show orders of magnitude, never as rankings.

## The Lesson In One Sentence

Every discontinuity the arc found was the same thing: R-level iteration
over a collection whose size grows with the data, doing per-element work
that R can do once for the whole vector. Architecture was never the
problem; the event-sourced fold, the sealed snapshot, and the sparse
fact tables survived every spike. What changed was representation and
the placement of loops.

## Evidence The Rules Rest On

| finding | before | after | record |
|----|---:|---:|----|
| per-row `[[<-` into scale-growing column buffers | scale-growing write cost per fill | `collapse::setv` in place | v0.1.8.9 workstream A |
| per-iteration `format.POSIXlt` in the fold | common root of the v0.1.8.7 hot paths | vectorised timestamp handling | fold hot-path audit |
| diagnostics as one data frame per row, bound once at the end | 51.6 s and 786.5 MiB at 40 pulses; did not finish 757 pulses in 1,800 s | production typed blocks; reviewed spike median 24.93 s at 757 pulses | diagnostic-block spike and LDG-2724 |
| provider re-resolving facts from data frames per instrument and pulse | 396 s for 757 identical decision views; 82.7% of loop samples | production primitive planes and cursors; provider-only pass 0.2 s and 0.26% of profiled loop samples | provider spike and LDG-2722/2723 |
| O(n^2) membership conflict validator run at seal | 95.1% of the traced seal at 30,300 rows (about 1,200 s extrapolated from slices) | production grouped sweeps; 6,000 randomized equivalence comparisons passed; full-scale seal timing remains a Batch 8 measurement | sealing probe and LDG-2728/2729/2730 |
| per-bar timestamp loop in the ingest dry run | 17 s for 426,191 bars | vectorised call already exists: 0.02 s | sealing probe |

After the production diagnostic block, the profiled 757-pulse spike
attributed 67.6% of captured in-loop samples to valuation, 20.7% to
residual fold work, and the remainder to diagnostics and persistence.
Valuation is therefore the next measured lane, not work authorized by
v0.2.0.1 and not a forecast of a future runtime.

The loop audit of 2026-09-15
(`../../../dev/spikes/snapshot-sealing/loop_audit.md`) recorded roughly
68 further HIGH and 90 MEDIUM sites of the same shapes across `R/`.
Those figures are a discovery estimate from a non-reconstructive read of
the source, useful for direction, not a census and not a claim an RFC
may cite as one.

## The Seven Shapes And Their Replacements

1.  **One-row frame per element, bound at the end.** A `data.frame()`
    per diagnostic, event, state row, or score, collected in a list and
    joined with `do.call(rbind, ...)`. Cost is quadratic-ish in rows and
    dominated by attribute handling, not values. Replace with typed
    column buffers written by index and manifested as one frame per
    chunk or at the persistence boundary, or with columns built by
    `rep()` and one constructor call.
2.  **Full-table subset inside a loop over ids.**
    `rows[rows$instrument_id == id, , drop = FALSE]` for every id, every
    pulse: O(instruments x rows) per pulse and, in the old provider,
    repeated once more per actionable target. Replace with one `split()`
    or `match()` at build time into instrument-indexed planes, and read
    by index at query time.
3.  **Per-element parsing or formatting where a vectorised call
    exists.** `vapply(x, ledgr_normalize_ts_utc, character(1))`,
    per-element `ledgr_fact_time()`, `ledgr_iso_utc()` in a loop. Every
    one of these functions is already vectorised; call it once on the
    column and mask the failures afterwards.
4.  **Per-row JSON on repetitive strings.** Provenance and metadata
    columns usually hold a handful of distinct strings. Validate, parse,
    or hash `unique(x)` and `match()` the result back; persist the two
    or three numeric fields that hot paths read as typed columns.
5.  **Work computed and discarded, or recomputed on every call.**
    Finalisation replaying every ledger event for values the fold
    already supplied; every `ledgr_facts_assert()` rehashing every
    family; validators that cannot fire on the rows they scan. Guard the
    computation on whether its result is read, and cache what identity
    already certifies.
6.  **Quadratic validators.** Nested pair loops over rows to find
    overlapping opposing assertions. Replace with a grouped, state-aware
    sweep: within each group (instrument and universe for membership;
    instrument, source, and precedence for status), sort by
    `effective_from`, keep a running maximum end per state, and flag a
    row whose start lies before the running maximum of any other state.
    Half-open intervals, open ends (`NA` as infinity), and the
    supersession exemption for status pairs are part of the semantics
    and must survive the rewrite. Set-backed membership rows may be
    excluded from the comparison only after a setwise check has
    confirmed that every persisted set row has `member = TRUE`, a valid
    header, and the snapshot invariants; the database does not enforce
    `set_id` implying `member = TRUE`.
7.  **Scalar writes into an environment-held vector.** A vector reached
    through an environment is copied in full by every base
    subassignment, whatever the syntax: `env$v[i] <- x`,
    `env[["v"]][i] <- x`, and the extract/mutate/reassign triple all
    cost the same. When the vector is a buffer sized by events or
    instruments times pulses, per-element writes make buffer
    construction quadratic in the rows written. Measured at 630,000
    elements, each base write costs about 1,620 microseconds against
    about 20 for `setv()`. Replace with a by-reference write through
    `collapse::setv()`, or move the buffer out of the environment. The
    discriminator is the environment, not the temporary name: a locally
    owned list mutates in place, so `bars_mat$close[j, ] <- v` over a
    local list is a different shape and carries no penalty.

## Rules

- **Prepare before the loop; read primitives inside it.** Anything that
  can be resolved from canonical inputs once per run (facts into segment
  tables, bars into matrices, ids into an index) is compiled before the
  fold. The pulse loop reads by index and advances cursors; it does not
  filter, sort, split, or subset a data frame. Canonical sparse tables
  remain the durable input; compiled planes are transient.
- **Frames manifest at boundaries only.** Public results, persistence
  chunks, and inspection surfaces are data frames or tibbles. Inside the
  fold and inside compile steps, state lives in typed atomic vectors,
  matrices, or CSR-style flat segment vectors with offsets.
- **Write by index into preallocated typed buffers.** Every typed
  column, character and list included, through
  `collapse::setv(col, i, value, vind1 = TRUE)`. The declared floor is
  `collapse (>= 2.1.8)` because 2.1.8 fixed the generational write
  barrier that made character and list `setv()` unsafe under 2.1.7; that
  bug is why earlier guidance sent character writes through base
  replacement, and that detour is what shape 7 describes. Never grow a
  vector or list by appending.
- **Advance, do not recompute.** Point-in-time state changes at known
  boundaries. Keep a cursor per instrument or per header over sorted
  boundary times; advance it for non-decreasing cutoffs and re-seek with
  `findInterval()` when a cutoff goes backwards, so answers never depend
  on query order.
- **Preserve the production rule, move the loop to compile time.** When
  a resolver is replaced, resolve each segment once at build time with
  the exact production predicate (applicability, supersession,
  precedence, stable tie order), and prove parity by comparing full
  views arm-to-arm at shuffled cutoffs rather than by re-deriving the
  rule.
- **Make the identity boundary explicit.** Anything that participates in
  `config_hash`, snapshot hash, or run identity is off limits to an
  optimization; anything that is a local locator (run ID, store path,
  creation time) is excluded from parity comparisons, and the exclusion
  is written down.
- **Measure before and after with the arc’s clocks.** Wall around the
  measured call in a fresh process, externally sampled peak working set,
  profiler shares as a decomposition only (Windows `Rprof()` samples
  about 64% of loop time), and cold versus warm clocks kept separate
  (`../spike_protocol.md` section 10). Small-fixture numbers never
  appear in a ranking, and no manual article, vignette, or release note
  turns them into a public claim.
- **Probe before prose.** A performance claim about package behaviour
  that no probe executed is returned. The order is smallest runnable
  fork, run it, let failures generate at most ten cases, then freeze
  expected answers.

## Scope Guards

This style does not license a package-wide collapse rewrite, a second
execution engine, parallel pulse execution, durable expanded matrices,
or a change to availability policy, schema, or public API. It does not
turn cold-path data frames (configuration, printing, one-off readers
over small tables) into debt. It applies to code whose iteration count
grows with bars, fact rows, instruments x pulses, events, diagnostics,
or candidates, on ingest and seal, the fold, hydration, finalisation,
and result readers.

## Implementation Trace

### Data Structures

- **Typed column chunk (production).** An environment holding 22
  preallocated vectors of `chunk_rows` (default 4,096): character for
  ids, stages, reasons, and JSON; integer for sequences and ages;
  numeric for targets, quantities, and prices; POSIXct for timestamps. A
  fill index `n` and the closures `append`, `flush`, `drain`
  (`R/availability-diagnostic-writer.R:100-175`). `flush()` manifests
  one `data.frame` and hands it to `write_run_diagnostics()`, which
  still owns the transaction and the write-time
  `MAX(diagnostic_seq) + 1` renumbering.
- **Instrument key.** A stable-sorted character vector of every id any
  fact or the configured universe names, built with
  `ledgr_availability_stable_ids()` (`R/availability-provider.R:9-13`);
  all planes are indexed by position in it
  (`R/availability-provider-prepared.R:172-181`, uncommitted).
- **Membership plane (production).** Headers in the resolver’s
  processing order with eligibility times
  `max(effective_from, knowledge_time)`, per-header member index sets,
  an eligibility order and its sorted times for the advance-only cursor,
  and interval assertions as flat `start`, `end`, `member`,
  `instrument index` vectors
  (`R/availability-provider-prepared.R:23-96`).
- **Segment table (production).** For status and lifetime: per
  instrument, boundary times and resolved integer codes laid out as flat
  vectors with `off` and `cnt` per instrument (CSR), values resolved at
  compile time by the production rule; one cursor vector `cur` over all
  instruments (`R/availability-provider-prepared.R:98-165`).
- **Event buffer (production).** Preallocated typed columns in the
  durable handler with `collapse::setv` for numeric, integer, and
  POSIXct fields and base replacement for character fields
  (`R/backtest-runner.R:379-394`); the sweep memory handler’s character
  and list columns still copy on write (`R/sweep.R:1576-1584`, an open
  audit item).

### Code Anchors

| boundary | anchor |
|----|----|
| column-buffer write rule | `../ledgr_v0_1_8_9_spec_packet/v0_1_8_9_spec.md` section 3.1 |
| diagnostic block constructor and typed writer | `R/availability-diagnostic-writer.R:42-175` |
| fold writer construction, per-pulse append, and final drain | `R/fold-engine.R:318-337`, `:1019` |
| production provider build boundary | `R/availability-provider.R:208-246` |
| retained public membership inspection resolver | `R/availability-provider.R:51-176` |
| prepared membership, segments, cursors, and provider | `R/availability-provider-prepared.R:23-323` |
| execution view per actionable target | `R/availability-economics.R:225-251` |
| valuation marks per instrument | `R/availability-economics.R:16-31` |
| grouped conflict sweeps and status hybrid | `R/availability-facts.R:1297-1476`; called at seal from `R/availability-persistence.R:432-450` |
| complete-set validation before membership bypass | `R/availability-persistence.R:193-303` |
| per-bar timestamp loop | `R/availability-ingest.R:200-206` |
| fact payload per row, repeated per assert | `R/availability-facts.R:775-800`, `:931-966` |
| availability equity-prefix merge and atomic commit | `R/run-finalize.R:236-422`, invoked at `:654` |

### Lookup And Dispatch Mechanisms

- **Cursor advance.** For a cutoff no earlier than the last one, each
  instrument’s `cur` moves forward while the next boundary is at or
  below the cutoff; the loop is vectorised over instruments and usually
  runs zero or one iteration per pulse
  (`R/availability-provider-prepared.R:132-148`).
- **Re-seek.** For a cutoff earlier than the last one, a single
  vectorised count of boundaries at or below the cutoff per CSR block (a
  cumulative sum over the flat vector and a difference at block edges)
  resets every cursor at once; headers use `findInterval()` over their
  sorted eligibility times.
- **Membership from the eligible set.** The last eligible complete
  header resets state; every eligible header at or after it contributes
  its set; interval assertions override per id with the last applicable
  one winning (`!duplicated(fromLast = TRUE)`), which is the production
  precedence.
- **Production dispatch.** `ledgr_availability_provider_build()` has one
  path: the prepared provider. The spike option, arm stamps, full
  data-frame provider, scalar diagnostic construction, and row-list
  writer do not ship.
- **Identity.** The production parity comparison excluded exactly the
  top-level creation time and the two embedded store locators. Run IDs,
  `archived_at_utc`, `config_hash`, and every other persisted field were
  compared. The optimized representations remain outside identity.

### Edge Cases

- `collapse::setv()` on character vectors under collapse 2.1.7 can skip
  the generational write barrier; the arc kept character writes on base
  replacement until the floor moves. Numeric, integer, and POSIXct
  writes are safe in both versions.
- `col[[i]] <- v; assign(name, col, envir)` on a character column copies
  the whole buffer when the vector is shared; hold buffers in an
  environment, avoid extra references, and prefer block writes per
  pulse.
- Stable sort ties: the production lifetime resolver takes the last
  applicable row after `order(effective_from, knowledge_time)`, whose
  ties follow input row order, and the DuckDB read orders rows by
  `effective_from, knowledge_time, fact_id`. A compile step must rank
  rows by the same key plus original row index, or parity fails only on
  ties.
- A cutoff exactly at a boundary: effective and knowledge times are
  inclusive, `effective_to` is exclusive; segments start at
  `max(effective_from,   knowledge_time)` and end at `effective_to`.
- Fixed-universe configs (`universe_rule` NULL) return the configured
  ids in configured order, not stable order; membership-rule universes
  return stable-sorted members.
- Interrupted-then-resumed availability-aware runs merge the prior and
  current fold-supplied equity into one exact achieved prefix before the
  terminal status changes (`R/run-finalize.R:236-422`, `:654`). Dense
  runs retain full recomputation. Missing, duplicate, foreign, or
  conflicting rows fail before destructive replacement.
- `ledgr_facts()` refuses two membership families on one universe, so
  snapshot lists and interval assertions for the same universe cannot be
  mixed in one bundle.
- Parallel workers receive the source path and `.libPaths()` only; an
  option-selected seam is not propagated to `mirai` workers
  (`R/parallel-workers.R:289-308`).

### Hot And Cold Paths

| runs | shape to avoid | shape to use |
|----|----|----|
| once per snapshot (ingest, seal) | per-bar loops; per-row JSON; O(n^2) validators; per-assert rehash | vectorised column calls; `unique()` then `match()`; sort-and-sweep; cached family hashes |
| once per run (provider build, hydration) | per-instrument data-frame subsets and window frames | one `split()` or `match()` into planes; series functions on whole vectors |
| per pulse (fold) | per-instrument resolver calls; one-row frames; list appends; `execution_view()` per target | cursor reads; block writes into typed chunks; one `execution_view()` per pulse |
| per fill | character or list column copy | in-place typed writes; batch fills |
| per reopen (results, explain) | per-timestamp DB queries; per-event JSON replay | one query, `cumsum` and `findInterval` |
| per candidate or fold (sweep, walk-forward) | per-row tibbles and full-table filters | column-wise construction; `split()` once |

### Concrete Examples

Per-element timestamp handling versus the vectorised call it already
had:

``` r
# before: 426,191 iterations, about 17 s
for (i in seq_along(x)) out[[i]] <- tryCatch(ledgr_fact_time(x[i], "ts_utc", allow_missing = TRUE)[[1L]], error = function(e) NA)
# after: 0.02 s, then mask failures
out <- ledgr_fact_time(x, "ts_utc", allow_missing = TRUE)
```

A quadratic validator versus a grouped, state-aware sweep (membership
shown; the same shape applies to status with one running maximum per
status value, grouped by instrument, source, and precedence, and with
superseded pairs exempted before the sweep):

``` r
# before: 459 million pair checks at 30,300 rows
for (i in seq_len(n - 1L)) for (j in seq.int(i + 1L, n)) if (same_scope(i, j) && opposing_state(i, j) && overlap(i, j)) abort()
# after: O(n log n); half-open [from, to), NA end = open; only opposing states conflict
o <- order(instrument_id, universe_id, effective_from)
from <- as.numeric(effective_from)[o]
end <- ifelse(is.na(effective_to), Inf, as.numeric(effective_to))[o]
state <- member[o]
scope_start <- c(TRUE,
  instrument_id[o][-1L] != instrument_id[o][-length(o)] |
    universe_id[o][-1L] != universe_id[o][-length(o)])
group <- cumsum(scope_start)
conflict <- unlist(lapply(split(seq_along(o), group), function(g) {
  prev_true <- c(-Inf, head(cummax(ifelse(state[g], end[g], -Inf)), -1L))
  prev_false <- c(-Inf, head(cummax(ifelse(!state[g], end[g], -Inf)), -1L))
  from[g] < ifelse(state[g], prev_false, prev_true)
}), use.names = FALSE)
if (any(conflict)) abort("Membership facts cannot assert incompatible overlapping states.")
```

Because rows are visited in start order, a row overlaps an earlier
opposing row exactly when its start lies before that row’s end, which is
the same half-open test the pairwise loop applied; equal starts and
nested intervals fall out of the running maximum. Set-backed rows enter
this sweep unless a prior setwise validation has confirmed their
persisted shape.

One diagnostic block per pulse versus one frame per instrument:

``` r
# before: for (id in context_ids) append_diagnostic(diag_row(...))   # 505 one-row frames per pulse
# after: writer$append_block(ts, context_ids, reason, reasons, target, ...)  # 22 vectors of length 505, one setv per column
```

## Maintainer Checklist

- Does any loop’s iteration count grow with bars, fact rows, instruments
  x pulses, events, diagnostics, or candidates? If so, what does one
  iteration do, and does a vectorised form exist?
- Is state inside the fold held in typed vectors, matrices, or segment
  tables with cursors, and do frames appear only at boundaries?
- Are per-row writes by index into preallocated buffers, with no append?
- Is any value computed on a hot path never read on the common branch?
- Does the change keep identity, schema, view shape, and reason
  vocabulary unchanged, and does the parity harness compare full outputs
  arm-to-arm with locators excluded explicitly?
- Which clock is the number: cold end to end, or warm iteration over a
  reused snapshot? Is the profiler share labelled as a decomposition?

## Source Links

- `../ledgr_v0_1_8_9_spec_packet/v0_1_8_9_spec.md` (column-buffer write
  rule)
- `../audits/fold_path_hotpath_audit.md`
- `../collapse_optimization_map.md`
- `../rfc/rfc_collapse_primitive_internals_v0_1_9_synthesis.md`
- `../rfc/rfc_availability_hot_path_representation_v0_2_0_x_seed_v2.md`
  (section 8, proposed engineering rule)
- `../rfc/rfc_availability_hot_path_representation_v0_2_0_x_spike_charter_v2.md`
  and its evidence reviews
- `../rfc/rfc_availability_hot_path_representation_v0_2_0_x_provider_spike_charter_v2.md`
  and its evidence review
- `../../../dev/spikes/availability-hot-path-representation/spike_inventory.md`
- `../../../dev/spikes/availability-provider-preparation/spike_inventory.md`
- `../../../dev/spikes/snapshot-sealing/loop_audit.md`
- `../spike_protocol.md` (sections 1, 3, 4, 10)
- `performance_arc_v0_1_8_x.qmd`, `benchmark_methodology.qmd`,
  `execution_fold_core.qmd`

## Where Next

Read `performance_arc_v0_1_8_x.qmd` for the release-by-release record
and `benchmark_methodology.qmd` for what a benchmark row may claim. The
provider, diagnostic block, and conflict sweeps are now production code.
The next measured warm lane is valuation; the remaining ingest
observations and any broader loop cleanup stay profile-triggered rather
than becoming a census rewrite.
