# Feature-keeping spike charter

**Date:** 2026-10-14  
**Authority:** v0.2.2 macro plan, WS5 feature-keeping probe  
**Status:** closed RED; binds nothing

## One question

Should v0.2.2 retain either current computed-feature retention mechanism - the
process-local feature cache or default writes to the durable `features`
table - before the WS3/WS4 history wave?

Deletion is the default. A mechanism survives only if the evidence below meets
every applicable condition already set by the macro plan.

## Cheaper prerequisite

The executed public-API probe in `probe.R` and `probe_findings.md` establishes
that there is something concrete to decide:

- a repeated run can hit the cache, but capture-blind fingerprints can return
  stale values and change fills; and
- feature rows are written, but the public result API has no reader for them.

## Registered evidence

The runner uses public snapshot, experiment, run, sweep/walk-forward and result
surfaces. One internal binding is replaced only in the cache-off measurement
arm so the production run path executes without cache keys; package files are
not changed.

1. **Cold run:** cache on versus off, `persist_features = FALSE`, alternating
   fresh processes. Report end-to-end time and exact economic outputs.
2. **Repeated-run best case:** two identical expensive-feature runs in one
   process, cache on versus off. Retention requires at least a 10 percent
   end-to-end saving on the second run and exact outputs.
3. **Correctness:** captured-variable change, feature-engine-version key
   change, and two equal-content snapshots with different IDs. Every case must
   return current values and preserve the intended reuse boundary.
4. **Persistence:** `persist_features = TRUE` versus `FALSE`, with cache off.
   Report end-to-end and finalization time, exact economics, row count and store
   bytes. Retention also requires a named public consumer of those rows.
5. **Walk-forward:** repeat one fixed session and report cache hits, misses,
   registry entries and payload bytes. The second pass may add no entry for an
   already-seen exact key.
6. **Sharadar shape:** one synthetic 1,166-instrument by 7,213-session run with
   one feature and persistence off. Report retained registry entries, numeric
   values, object bytes and process RSS. If the full run exceeds the stop
   condition, report the largest completed public run and the exact linear
   projection to the recorded 8,410,358-value Sharadar feature population.

Raw clocks are descriptive. Decisions use alternating-pair medians, current
public outputs and the predeclared 10 percent threshold.

## Terminal rule

- **GREEN:** at least one mechanism clears every applicable condition; keep
  only that mechanism and route its identity design to WS5-B.
- **RED:** neither mechanism clears every condition; route a pure-deletion
  ticket into the pre-history cut.
- **INCONCLUSIVE:** a mechanism clears correctness and necessity but the
  registered public workload cannot settle its benefit or memory cost.

## Stop and recharter

Stop if answering the question requires a new public feature reader, new
feature identity semantics, a production-code change, private vendor rows, or
more than ten minutes or 8 GiB RSS for one child. Those are design or
implementation questions, not evidence for keeping the current mechanisms.

## Deliverables

- `runner.R` and evidence CSVs;
- `spike_checker.R`, which reruns into scratch, checks scope, compares deterministic
  evidence and recomputes the terminal rule;
- `spike_inventory.md`, including one gutted cache path; and
- one-page `closeout.md`.
