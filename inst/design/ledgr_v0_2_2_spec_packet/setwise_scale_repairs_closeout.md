# Cut 18 Workstream 52 closeout: set-wise scale repairs

Implementation commits: `3208c99e`, `3d6b3322` and detector correction
`f96bfaa2`, based on accepted Workstream 51 commit `0fd89a23`.

Role: non-binding implementation record. `tickets.yml` owns status and
`contracts.md` owns behavior. Status: awaiting the Workstream 52 Type 1 close
review.

## Necessity and boundary

The workstream removes five measured amplifications on existing public paths.
It adds no public argument, result kind, schema, identity input, index or
condition. The public full diagnostics and availability readers are unchanged.

The rejected alternative was a generic cache or reader framework. Each repair
instead moves one existing operation to the smallest boundary where all of its
inputs are already available.

## LDG-3093: four set-wise repairs

### Candidate-feature rows

`ledgr_sweep_storage_candidate_rows()` prepares candidate-feature row groups
once through `ledgr_sweep_storage_candidate_feature_rows()`. Named candidate
rows use one `split()`; positional fallback remains positional. Output order,
duplicate candidate rows and the empty shape are unchanged.

LTB-0484 compares the groups with the former literal subset rule at 1, 7 and
31 candidates and pins one preparation call in the persisted-candidate
projection. Restoring the full-table subset fails that call assertion.

### Run equity statistics

`ledgr_run_store_fetch()` groups the one fetched equity table once. The helper
fills three preallocated vectors and constructs one result frame, retaining
the old first/final equity, maximum-drawdown arithmetic, run ordering and
typed missing values for a run without equity.

LTB-0485 compares the result with the former literal per-run calculation at
1, 7 and 31 runs. Restoring the per-run table scan fails its preparation
assertion.

### Latest pulse bars

`ledgr_fetch_latest_bars()` issues one set query for unique requested IDs and
uses `match()` to restore the caller's order and duplicates. It still returns
`NULL` for an empty universe and names the first missing requested ID in the
same classed condition.

LTB-0486 counts one query at 1, 7 and 31 requested instruments, then checks a
reordered duplicate request and two missing IDs. Restoring the query-per-ID
loop fails three query-count assertions.

### Composition timestamps

`ledgr_corporate_action_composition_report()` combines bar and effective
instants and formats them in one vector call. The helper emits exactly the
same canonical UTC bytes as the former scalar normalizer and retains its
invalid-POSIXct class and message.

LTB-0487 compares pre-epoch and DST-adjacent values at 1, 7 and 31 rows, plus
empty and invalid inputs. Restoring scalar formatting fails the formatter
boundary assertion.

The source-derived work counts are committed at
`dev/bench/v0_2_2_residual_performance/evidence/ws52_h1/operation_counts.csv`.
They show linear input preparation plus requested groups for candidate and
equity rows, and one database or formatter call independent of width for the
other two repairs.

## LDG-3094: filtered explanations

`ledgr_run_explain()` now holds one run connection, verifies its snapshot on
that connection, reads only the requested instrument's decision and execution
diagnostics, and reconstructs availability only at matching decision times.
The availability-active path restricts materialized axes to the requested ID;
the dense path restricts both IDs and times. The terminal reader reuses the
same run connection. Public full readers retain their old implementation.

LCL-0478/LTB-0063 count one filtered diagnostics read and one filtered
availability read. A scalar explanation materializes one availability row,
less than either full source, and is identical to the established public
explanation. The existing block also owns ordered history, absent-ID shape,
scalar/history equivalence, reopen equivalence and read-only behavior.

Independent mutations restoring only the full diagnostics reader or only the
full availability reader fail LTB-0063. The established availability suites
also cover active, stale, frozen, stopped and reopened evidence.

## H1 timing and memory

The record under
`dev/bench/v0_2_2_residual_performance/evidence/ws52_h1/` uses the maintained
`reader_check.R` workload: 800 instruments, 1,260 sessions and rotating
300-member sets. Six fresh processes alternate accepted WS51 `0fd89a23` and
candidate product `3d6b3322`, under R 4.6.1, High priority and affinity
`0xFFFF`. Each process performs one untimed warm read after a full-GC counter
reset, reports maximum used R heap, and times three warm reads.

| Measure | Base median | Candidate median | Ratio | Gate |
| --- | ---: | ---: | ---: | --- |
| explanation elapsed | 1.3090 s | 0.2391 s | 0.1827 | PASS |
| explanation peak R heap | 514.1 MB | 252.9 MB | 0.4919 | PASS |

Both required ratios are below 0.95. Dense availability is a non-gated
control in the same process and moves by 1.019 elapsed and 1.027 heap. Heap is
R's maximum used heap, not whole-process RSS.

## Exactness and verification

The following focused files pass on the candidate:

- `test-setwise-scale-repairs.R`;
- `test-sweep-persistence-schema.R`;
- `test-run-store.R`;
- `test-corporate-action-composition.R`;
- `test-availability-parity.R`;
- `test-availability-provider-production.R`;
- `test-availability-features.R`;
- `test-sim-pit-inputs.R`;
- `test-feature-inspection.R`;
- `test-test-control-plane.R`; and
- `test-long-window-regression-control.R`.

The accepted long-window record self-test prints `LWREG_CHECK_OK`. The
codebase census regenerates and checks at 74 connections, 159 versions, 80
run configs, 1,848 helpers, 2,402 condition references, 72 findings, 159
mode-branch sites and 56 mode-flow sites. The fold-phase checker passes. Both
YAML files parse and `git diff --check` is clean.

The maintained full scale recorder was attempted against the pre-ticket tree,
but its unchanged `run_families()` projection stopped while converting a list
whose elements had lengths 1, 0 and 3. No partial output is retained and no
fixture-lane claim is made. Each changed output instead has an independent
pre-rule oracle above, and the existing focused suites cover the complete
public and persisted shapes.

## Seven-shape walk

1. **One-row frame per element, bound at the end.** Removed from the changed
   run-equity path: the helper accumulates typed vectors and constructs one
   result frame. None of the other changed helpers constructs row frames.
2. **Full-table subset inside a loop over ids.** Removed from candidate
   features and equity. The explanation filters diagnostics in SQL and
   availability before reconstructing rows; latest bars uses one set query.
3. **Per-element parsing or formatting where a vectorised call exists.**
   Removed from composition timestamps. One vector call formats the combined
   bar and effective-time vector.
4. **Per-row JSON on repetitive strings.** The changed paths add no JSON
   parsing, formatting or hashing. Existing explanation output is preserved.
5. **Work computed and discarded, or recomputed on every call.** The filtered
   availability helper does not repeat snapshot verification, and the four
   grouped/set-wise helpers prepare each shared input once per call.
6. **Quadratic validators.** No validator changes here. None of the six
   changed paths introduces pairwise row comparisons or nested validation.
7. **Scalar writes into an environment-held vector.** None added. The equity
   accumulator vectors are local to the helper, not reached through an
   environment; the other changes do not write scale-growing buffers.

## Mutation ledger

| Mutation | Result |
| --- | --- |
| restore candidate full-table subset | LTB-0484 fails once |
| restore per-run equity scan | LTB-0485 fails once |
| restore latest-bar query-per-ID loop | LTB-0486 fails three times |
| restore scalar composition formatter | LTB-0487 fails once |
| restore full diagnostics in explain | LTB-0063 filtered-call count fails |
| restore full availability in explain | LTB-0063 call and row counts fail |

The mutations ran only in disposable worktree `C:/tmp/ws52-mut`. Its unrelated
parallel-worker error under `pkgload` is not claimed as a detector result.
