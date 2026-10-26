# Workstream 62 close review

**Mode:** Type 1 close review  
**Range:** `59fcce83..3d3918db`  
**Reviewer:** fresh-context Claude Opus, high effort  
**Verdict:** `CHANGES_REQUIRED`

## Result

The five current-format bumps, their basic writers and readers, unscheduled
field omission, worker-local compilation and economic parity were sound. The
review found three product defects, one incomplete refusal message, and several
failure-sensitivity gaps. None changes the accepted scheduler design or needs a
Type 2 round.

## Findings

1. **High - schedule presence was not compared during promotion.** A scheduled
   candidate promoted into an unscheduled experiment, or the reverse, produced
   no `schedule_hash` mismatch. The comparison used only fields present on the
   promoting side and treated current-format absence as historical missing
   evidence rather than the meaningful unscheduled state.
2. **Medium - walk-forward candidates could not produce reproduction keys.**
   The new provenance gate accepted only `ledgr_provenance_v2` and rejected the
   equally current `ledgr_walk_forward_candidate_v2` format.
3. **Medium - invalid parameter-menu values escaped the candidate failure
   boundary.** Resolving the schedule in the parent task builder made one bad
   candidate abort a sweep or walk-forward session even with candidate-level
   failure handling enabled. Saved failed rows also needed an honest
   authored-only schedule record when no resolved rule exists.
4. **Low-medium - the sweep-provenance refusal omitted the received value.**
   It named only the required `ledgr_provenance_v2` value.
5. **Medium - LCL-0499 overclaimed its detector.** Mutations dropping
   walk-forward train/test schedule identity, either promotion-side schedule
   hash, parent or candidate read validation, and a mask renamed to
   `schedule_verdicts` survived. The target also equaled the opening position,
   so its economics were insensitive to due pulses, and its column check was
   tautological.
6. **Low - two records were stale.** LCL-0233 still said its test rewrote v1
   rather than v2, and the promotion contract understated walk-forward
   identity.
7. **Low - a new condition child lacked a public condition entry.** Reusing the
   existing current-artifact incompatibility class is sufficient.
8. **Low - the seven-shape record overstated JSON absence.** Candidate identity
   performs bounded canonicalization and hashing; the cost is outside the
   pulse loop but must be stated honestly and belongs to WS63 measurement.

## Mutations and checks

The reviewer caught removal of resolved identity, the worker compile, all five
version gates and both unscheduled-null omissions. Seven schedule-field or
reader-validation mutations survived and motivated finding 5. Focused
scheduler, promotion, walk-forward, parallel, sweep-persistence,
documentation-contract and current-only suites passed in a disposable
worktree. The codebase checker passed with its output redirected to scratch.

The main checkout was not edited by the reviewer. Two deregistered disposable
directories left under `C:/tmp` were removed by the implementer after review.
